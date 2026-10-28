"""GitHub Linux runner setup/export checks. No Android tools are installed locally.

Run `setup`, `configure`, or `verify` from the repository root on GitHub Actions.
Downloads are official Godot release assets checked against SHA512-SUMS.txt.
Only Android templates are extracted, not other platforms.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import urllib.parse
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parent.parent
APK_NAME = "Kelime-Bahcesi-Android.apk"


def checked_download(url: str, target: Path, sha512: str | None = None) -> Path:
    temporary = target.with_suffix(target.suffix + ".download")
    digest = hashlib.sha512()
    with urllib.request.urlopen(url, timeout=120) as response, temporary.open("wb") as file:
        while chunk := response.read(8 * 1024 * 1024):
            digest.update(chunk)
            file.write(chunk)
    if sha512 and digest.hexdigest() != sha512.lower():
        temporary.unlink(missing_ok=True)
        raise RuntimeError(f"Checksum mismatch for {target.name}")
    temporary.replace(target)
    return target


def setup() -> None:
    if os.environ.get("GITHUB_ACTIONS") != "true" or os.name != "posix":
        raise SystemExit("setup is for the GitHub Linux runner, not a local Android installation.")
    version = os.environ.get("GODOT_VERSION", "4.5.2")
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        raise ValueError("Invalid Godot version")
    base = f"https://github.com/godotengine/godot/releases/download/{version}-stable"
    with urllib.request.urlopen(f"{base}/SHA512-SUMS.txt", timeout=60) as response:
        checksums = dict((line.split()[1].lstrip("*"), line.split()[0]) for line in response.read().decode().splitlines() if len(line.split()) == 2)
    temporary = Path(os.environ["RUNNER_TEMP"]) / "word-garden-godot"
    temporary.mkdir(parents=True, exist_ok=True)
    executable_zip = f"Godot_v{version}-stable_linux.x86_64.zip"
    templates_zip = f"Godot_v{version}-stable_export_templates.tpz"
    for name in (executable_zip, templates_zip):
        print(f"Downloading and verifying {name} on GitHub runner", flush=True)
        checked_download(f"{base}/{name}", temporary / name, checksums[name])
    bin_dir = temporary / "bin"
    bin_dir.mkdir(exist_ok=True)
    binary = bin_dir / "godot"
    with zipfile.ZipFile(temporary / executable_zip) as archive:
        matches = [name for name in archive.namelist() if name.endswith("linux.x86_64")]
        if len(matches) != 1:
            raise RuntimeError("Unexpected Godot executable archive")
        binary.write_bytes(archive.read(matches[0]))
    binary.chmod(0o755)
    data_home = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
    destination = data_home / "godot/export_templates" / f"{version}.stable"
    destination.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(temporary / templates_zip) as archive:
        for filename in ("android_debug.apk", "android_release.apk", "version.txt", "web_debug.zip", "web_release.zip", "web_nothreads_debug.zip", "web_nothreads_release.zip"):
            try:
                (destination / filename).write_bytes(archive.read("templates/" + filename))
            except KeyError:
                pass
    with open(os.environ["GITHUB_PATH"], "a", encoding="utf-8") as file:
        file.write(str(bin_dir) + "\n")
    print(f"Godot {version}: Android templates verified and ready.")


def replace_option(text: str, name: str, value: str) -> str:
    pattern = rf"(?m)^{re.escape(name)}=.*$"
    updated, count = re.subn(pattern, lambda _: f"{name}={value}", text)
    if not count:
        raise ValueError(f"Missing setting: {name}")
    return updated


def release_identity(owner_id: str, run_number: str, attempt: str) -> tuple[str, int, str]:
    if not all(value.isdigit() and int(value) > 0 for value in (owner_id, run_number, attempt)):
        raise ValueError("Invalid repository/build identity")
    code = int(run_number) * 100 + int(attempt)
    if code > 2100000000 or int(attempt) >= 100:
        raise ValueError("Android versionCode out of range")
    return f"io.github.wordgarden.u{owner_id}", code, f"0.1.{run_number}.{attempt}"


def validated_server_url(value: str) -> str:
    value = value.strip()
    if not value:
        return ""
    parsed = urllib.parse.urlsplit(value)
    if parsed.scheme != "wss" or not parsed.hostname or parsed.username or parsed.password or any(ch.isspace() for ch in value) or len(value) > 2048:
        raise ValueError("The published server URL must be a valid wss:// address without credentials.")
    return value


def configure() -> None:
    package, code, version = release_identity(os.environ["GITHUB_REPOSITORY_OWNER_ID"], os.environ["GITHUB_RUN_NUMBER"], os.environ["GITHUB_RUN_ATTEMPT"])
    preset = ROOT / "export_presets.cfg"
    text = preset.read_text(encoding="utf-8")
    for name, value in {
        "package/unique_name": json.dumps(package),
        "version/code": str(code),
        "version/name": json.dumps(version),
        "architectures/armeabi-v7a": "true",
        "architectures/arm64-v8a": "true",
    }.items():
        text = replace_option(text, name, value)
    preset.write_text(text, encoding="utf-8")
    project = ROOT / "project.godot"
    project.write_text(replace_option(project.read_text(encoding="utf-8"), "config/version", json.dumps(version)), encoding="utf-8")
    server = validated_server_url(os.environ.get("WORD_GARDEN_SERVER_URL", ""))
    network = ROOT / "config/network.json"
    if server:
        network.write_text(json.dumps({"url": server}) + "\n", encoding="utf-8")
    elif network.exists():
        raise RuntimeError("A local network.json must not be committed to a cloud build.")
    config_home = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "godot"
    config_home.mkdir(parents=True, exist_ok=True)
    # Fresh, isolated GitHub runner settings only; no user's desktop settings.
    settings = '\n'.join([
        '[gd_resource type="EditorSettings" format=3]', '[resource]',
        'export/android/android_sdk_path = ' + json.dumps(os.environ["WORD_GARDEN_ANDROID_SDK"]),
        'export/android/java_sdk_path = ' + json.dumps(os.environ["JAVA_HOME"]), '',
    ])
    (config_home / "editor_settings-4.5.tres").write_text(settings, encoding="utf-8")
    print(f"Package: {package}; versionCode: {code}; ARM32 + ARM64; online configured: {bool(server)}")


def verify() -> None:
    sdk = Path(os.environ["WORD_GARDEN_ANDROID_SDK"])
    tools = sdk / "build-tools" / os.environ.get("ANDROID_BUILD_TOOLS", "35.0.0")
    apk = ROOT / "builds" / APK_NAME
    if not apk.is_file() or apk.stat().st_size < 1000000:
        raise RuntimeError("No usable APK was produced")
    subprocess.run([str(tools / "apksigner"), "verify", "--verbose", "--print-certs", str(apk)], check=True)
    badging = subprocess.check_output([str(tools / "aapt"), "dump", "badging", str(apk)], text=True)
    package, code, version = release_identity(os.environ["GITHUB_REPOSITORY_OWNER_ID"], os.environ["GITHUB_RUN_NUMBER"], os.environ["GITHUB_RUN_ATTEMPT"])
    if f"name='{package}'" not in badging or f"versionCode='{code}'" not in badging or "arm64-v8a" not in badging or "armeabi-v7a" not in badging:
        raise RuntimeError("APK package, version or architectures do not match the intended build")
    permissions = subprocess.check_output([str(tools / "aapt"), "dump", "permissions", str(apk)], text=True)
    if "android.permission.INTERNET" not in permissions:
        raise RuntimeError("APK is missing INTERNET permission")
    if any(permission in permissions for permission in ("android.permission.CAMERA", "android.permission.RECORD_AUDIO", "android.permission.ACCESS_FINE_LOCATION", "android.permission.READ_CONTACTS")):
        raise RuntimeError("Unexpected sensitive Android permission")
    digest = hashlib.sha256(apk.read_bytes()).hexdigest()
    apk.with_suffix(".apk.sha256").write_text(f"{digest}  {apk.name}\n", encoding="utf-8")
    configured = bool(validated_server_url(os.environ.get("WORD_GARDEN_SERVER_URL", "")))
    notes = (
        f"# Kelime Bahçesi — Android {version}\n\n"
        f"- Doğrudan kurulabilen, sabit anahtarla imzalı APK: **{apk.stat().st_size / 1048576:.1f} MiB**.\n"
        "- ARM32 + ARM64; 18 Türkçe + 18 İngilizce bölüm, çevrimdışı oyun ve parti.\n"
        f"- İnternetten yarışma sunucusu: **{'yapılandırıldı' if configured else 'henüz yapılandırılmadı; tek kişilik/parti oynanabilir'}**.\n"
        "- APK dosyasını WhatsApp/Drive ile paylaşabilirsiniz. Arkadaşların GitHub hesabına ihtiyaç duymaz.\n"
        "- Gizli repo/release bağlantısını paylaşmak erişim vermez; indirilen APK dosyasını gönderin.\n"
        "- Telefonda dosyayı açıp yalnızca bu kurulum için kaynağa izin verin; Play Protect'i kapatmayın.\n"
        "- Android/iOS gerçek cihaz testinin yerine geçmez. Telefon testi yapıp hataları bildirin.\n"
        f"\nSHA-256: `{digest}`\n"
    )
    (ROOT / "builds/release-notes.md").write_text(notes, encoding="utf-8")
    print(notes)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("setup", "configure", "verify"))
    command = parser.parse_args().command
    {"setup": setup, "configure": configure, "verify": verify}[command]()
