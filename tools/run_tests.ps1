[CmdletBinding()]
param(
    [string]$GodotPath = "",
    [switch]$SkipImport,
    [switch]$SkipBackend,
    [switch]$IncludeUI,
    [switch]$IncludeNetwork,
    [string]$NetworkUrl = "ws://127.0.0.1:8787/ws",
    [switch]$Strict
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$Failures = @()
$Skips = @()
$Executed = 0

# Godot can exit 0 while a script failed to parse or a test script crashed.
# These patterns are treated as failures regardless of the process exit code.
$FatalPattern = "(?i)(SCRIPT ERROR|Parse Error|Parser Error|Failed to load script|Failed to open script|Can't open script|^ERROR:|ObjectDB instances leaked)"

function Write-Step {
    param([string]$Text)
    Write-Host ""
    Write-Host "== $Text =="
}

function Resolve-Executable {
    param([string]$Candidate)
    if ([string]::IsNullOrWhiteSpace($Candidate)) { return $null }
    if (Test-Path -LiteralPath $Candidate -PathType Leaf) {
        return (Resolve-Path -LiteralPath $Candidate).Path
    }
    $command = Get-Command $Candidate -ErrorAction SilentlyContinue
    if ($null -ne $command -and $command.CommandType -eq "Application") {
        return $command.Source
    }
    return $null
}

function Invoke-Captured {
    param(
        [string]$Exe,
        [string[]]$Arguments,
        [string]$WorkingDirectory = ""
    )
    $stdout = [System.IO.Path]::GetTempFileName()
    $stderr = [System.IO.Path]::GetTempFileName()
    $lines = New-Object System.Collections.Generic.List[string]
    $ansi = New-Object System.Text.RegularExpressions.Regex("$([char]27)\[[0-9;?]*[A-Za-z]")
    $code = -1
    try {
        $quoted = @()
        foreach ($arg in $Arguments) {
            if ($arg -match '[\s"]') {
                $quoted += '"' + ($arg -replace '"', '\"') + '"'
            } else {
                $quoted += $arg
            }
        }
        $startArgs = @{
            FilePath               = $Exe
            ArgumentList           = $quoted
            NoNewWindow            = $true
            Wait                   = $true
            PassThru               = $true
            RedirectStandardOutput = $stdout
            RedirectStandardError  = $stderr
        }
        if (-not [string]::IsNullOrWhiteSpace($WorkingDirectory)) {
            $startArgs["WorkingDirectory"] = $WorkingDirectory
        }
        $process = Start-Process @startArgs
        $code = $process.ExitCode
    } catch {
        $lines.Add("Failed to start ${Exe}: $($_.Exception.Message)")
    } finally {
        foreach ($file in @($stdout, $stderr)) {
            if (Test-Path -LiteralPath $file) {
                foreach ($line in [System.IO.File]::ReadAllLines($file, [System.Text.Encoding]::UTF8)) {
                    $clean = $ansi.Replace($line, "").Replace("`r", "").TrimEnd()
                    if ($clean.Length -gt 0) { $lines.Add($clean) }
                }
                Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue
            }
        }
    }
    return [pscustomobject]@{
        Code  = $code
        Lines = $lines.ToArray()
        Text  = ($lines -join "`n")
    }
}

function Write-Captured {
    param([string[]]$Lines)
    foreach ($line in $Lines) {
        Write-Host "  $line"
    }
}

function Get-FatalLines {
    param([string]$Text)
    $matchesList = @()
    foreach ($line in ($Text -split "`n")) {
        if ($line -match $FatalPattern) { $matchesList += $line.Trim() }
    }
    return $matchesList
}

function Test-RunResult {
    param(
        [string]$Label,
        $Result
    )
    $fatal = Get-FatalLines $Result.Text
    $ok = ($Result.Code -eq 0) -and ($fatal.Count -eq 0)
    if (-not $ok) {
        $reason = if ($Result.Code -ne 0) { "exit code $($Result.Code)" } else { "error output despite exit code 0" }
        $script:Failures += "$Label ($reason)"
        Write-Host "FAILED: $Label ($reason)" -ForegroundColor Red
        if ($fatal.Count -gt 0) {
            Write-Host "  Detected fatal output:" -ForegroundColor Red
            foreach ($line in $fatal) { Write-Host "    $line" -ForegroundColor Red }
        }
    } else {
        Write-Host "PASSED: $Label" -ForegroundColor Green
    }
    return $ok
}

Write-Step "Kelime Bahcesi / Word Garden test runner"
Write-Host "Project root: $Root"

$godot = $null
$explicitGodot = $false

if (-not [string]::IsNullOrWhiteSpace($GodotPath)) {
    $explicitGodot = $true
    $godot = Resolve-Executable $GodotPath
} elseif (-not [string]::IsNullOrWhiteSpace($env:GODOT_BIN)) {
    $explicitGodot = $true
    $godot = Resolve-Executable $env:GODOT_BIN
}

if ($null -eq $godot -and $explicitGodot) {
    Write-Host ""
    Write-Host "ERROR: The Godot path given via -GodotPath or GODOT_BIN could not be resolved." -ForegroundColor Red
    Write-Host "Fix the path or remove the parameter to search PATH automatically."
    Write-Host "No test was executed. This is not a success result."
    exit 2
}

if ($null -eq $godot) {
    foreach ($candidate in @("godot", "godot4", "godot.exe", "godot4.exe")) {
        $godot = Resolve-Executable $candidate
        if ($null -ne $godot) { break }
    }
}

if ($null -eq $godot) {
    Write-Host ""
    Write-Host "ERROR: Godot executable was not found." -ForegroundColor Red
    Write-Host "Install Godot 4.5.2 or pass its path explicitly:"
    Write-Host '  .\tools\run_tests.ps1 -GodotPath "C:\Tools\Godot_v4.5.2-stable_win64.exe"'
    Write-Host "No test was executed. This is not a success result."
    exit 2
}

Write-Host "Godot: $godot"

$version = Invoke-Captured -Exe $godot -Arguments @("--version")
if ($version.Code -ne 0) {
    Write-Host "ERROR: Godot failed to report its version (exit $($version.Code))." -ForegroundColor Red
    Write-Captured $version.Lines
    Write-Host "No test was executed. This is not a success result."
    exit 2
}
Write-Captured $version.Lines

$versionText = ($version.Lines -join " ").Trim()
if ($versionText -notmatch "4\.5\.2") {
    Write-Host "WARNING: this project targets Godot 4.5.2; the detected version may produce false failures." -ForegroundColor Yellow
}

if (-not $SkipImport) {
    Write-Step "Headless import"
    $import = Invoke-Captured -Exe $godot -Arguments @("--headless", "--path", $Root, "--import")
    Write-Captured $import.Lines
    $importFatal = Get-FatalLines $import.Text
    if ($import.Code -ne 0 -or $importFatal.Count -gt 0) {
        $reason = if ($import.Code -ne 0) { "exit code $($import.Code)" } else { "error output despite exit code 0" }
        $Failures += "headless import ($reason)"
        Write-Host "Import failed ($reason)." -ForegroundColor Red
        foreach ($line in $importFatal) { Write-Host "  $line" -ForegroundColor Red }
    } else {
        Write-Host "Import completed."
    }
} else {
    $Skips += "headless import (explicitly skipped)"
    Write-Host "Skipping headless import."
}

$testFiles = @(
    @{ Label = "core tests"; Relative = "tests/test_core.gd"; Mandatory = $true },
    @{ Label = "content tests"; Relative = "tests/test_content.gd"; Mandatory = $true },
    @{ Label = "compound tests"; Relative = "tests/test_compounds.gd"; Mandatory = $true }
)

if ($IncludeUI) {
    $testFiles += @{ Label = "UI tests"; Relative = "tests/test_ui.gd"; Mandatory = $false }
}

if ($IncludeNetwork) {
    $testFiles += @{ Label = "network tests"; Relative = "tests/test_network.gd"; Mandatory = $false }
    $testFiles += @{ Label = "online UI tests"; Relative = "tests/test_online_ui.gd"; Mandatory = $false }
}

foreach ($test in $testFiles) {
    Write-Step $test.Label
    $fullPath = Join-Path $Root $test.Relative
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        $Skips += "$($test.Relative) (file not found)"
        Write-Host "SKIP: $($test.Relative) does not exist." -ForegroundColor Yellow
        continue
    }

    $resourcePath = "res://" + $test.Relative.Replace("\", "/")
    $Executed++
    Write-Host "Running $resourcePath"
    $arguments = @("--headless", "--path", $Root, "--script", $resourcePath)
    if ($test.Relative -in @("tests/test_network.gd", "tests/test_online_ui.gd")) {
        $arguments += @("--", "--url=$NetworkUrl")
    }
    $result = Invoke-Captured -Exe $godot -Arguments $arguments
    Write-Captured $result.Lines
    [void](Test-RunResult -Label $test.Relative -Result $result)
}

if (-not $SkipBackend) {
    Write-Step "Backend tests"
    $backendDir = Join-Path $Root "backend"
    $backendPackage = Join-Path $backendDir "package.json"
    if (-not (Test-Path -LiteralPath $backendPackage -PathType Leaf)) {
        $Skips += "backend npm test (backend/package.json not found)"
        Write-Host "SKIP: backend/package.json does not exist." -ForegroundColor Yellow
    } else {
        $npm = Get-Command npm.cmd -ErrorAction SilentlyContinue
        if ($null -eq $npm) {
            $npm = Get-Command npm -ErrorAction SilentlyContinue
        }
        if ($null -eq $npm) {
            $Skips += "backend npm test (npm not found)"
            Write-Host "SKIP: npm was not found." -ForegroundColor Yellow
        } else {
            $Executed++
            $comspec = $env:ComSpec
            if ([string]::IsNullOrWhiteSpace($comspec)) { $comspec = "cmd.exe" }
            $result = Invoke-Captured -Exe $comspec -Arguments @("/c", "npm", "test") -WorkingDirectory $backendDir
            Write-Captured $result.Lines
            [void](Test-RunResult -Label "backend npm test" -Result $result)
        }
    }
} else {
    $Skips += "backend npm test (explicitly skipped)"
    Write-Host "Skipping backend tests."
}

if ($IncludeNetwork) {
    Write-Host ""
    Write-Host "Note: -IncludeNetwork requires a reachable WebSocket server (see docs/TESTING.md)." -ForegroundColor Yellow
}

Write-Step "Summary"
Write-Host "Executed test suites: $Executed"
Write-Host "Failures: $($Failures.Count)"
Write-Host "Skipped steps: $($Skips.Count)"

if ($Failures.Count -gt 0) {
    Write-Host ""
    Write-Host "Failed:" -ForegroundColor Red
    $Failures | ForEach-Object { Write-Host "  - $_" }
}

if ($Skips.Count -gt 0) {
    Write-Host ""
    Write-Host "Skipped:" -ForegroundColor Yellow
    $Skips | ForEach-Object { Write-Host "  - $_" }
}

if ($Failures.Count -gt 0) {
    Write-Host ""
    Write-Host "RESULT: FAILED" -ForegroundColor Red
    exit 1
}

if ($Executed -eq 0) {
    Write-Host ""
    Write-Host "RESULT: NO TESTS EXECUTED" -ForegroundColor Yellow
    Write-Host "Missing files and runtimes were skipped; this is not a passing test result."
    exit 2
}

if ($Strict -and $Skips.Count -gt 0) {
    Write-Host ""
    Write-Host "RESULT: INCOMPLETE (Strict mode)" -ForegroundColor Yellow
    exit 2
}

Write-Host ""
Write-Host "RESULT: PASSED (executed suites only; review skipped steps)" -ForegroundColor Green
exit 0
