# Mobil Export Kılavuzu — Android ve iOS

**Ürün:** Kelime Bahçesi / Word Garden
**Hedef Godot:** 4.5.2
**Belge durumu:** Kurulum ve doğrulama kılavuzu. Bu depoda **imzalı APK/IPA üretilmemiştir, mağaza yayını yoktur** ve aşağıdaki adımların tamamı bu ortamda çalıştırılıp doğrulanmamıştır.

> **Kısa durum:** `export_presets.cfg` içinde Android ve iOS için sır içermeyen presetler tanımlıdır. Android debug APK'sı Windows'ta üretilebilir (JDK/SDK/template kuruluysa). iOS derlemesi **yalnızca macOS + Xcode + Apple imzalama** ile mümkündür; Windows'ta imzalı iOS çıktısı alınamaz. Mağaza hesapları ve ücretleri bu deponun dışındadır.

## 1. Sürüm ve export template eşleşmesi

- Godot editörü **4.5.2** olmalıdır. Proje `config/features=PackedStringArray("4.5", "GL Compatibility")` kullanır.
- Export template'leri editör sürümüyle **birebir** eşleşmelidir. 4.5.2 editörü ile 4.5.1 template'leri karıştırmayın; "export template not found" veya garip çalışma zamanı hataları alırsınız.
- Windows'ta template konumu tipik olarak:

  ```text
  %APPDATA%\Godot\export_templates\4.5.2.stable\
  ```

- Kurulum: **Editor > Manage Export Templates > Download and Install**. Çevrimdışıysanız Godot 4.5.2 sürümüne ait `Godot_v4.5.2-stable_export_templates.tpz` paketini indirip aynı sürüm klasörüne kurun.
- Android ve iOS template'leri aynı `.tpz` paketinin içindedir; ayrı sürüm indirmeyin.

Doğrulama:

```powershell
& "C:\Tools\Godot_v4.5.2-stable_win64.exe" --version
```

Çıktı `4.5.2.stable` (veya benzeri) olmalıdır.

## 2. Preset özeti

`export_presets.cfg` iki preset içerir:

| | Android | iOS |
| --- | --- | --- |
| Preset adı | `Android` | `iOS` |
| Platform | Android | iOS |
| Çıktı hedefi | `builds/kelime-bahcesi.apk` | `builds/ios/kelime_bahcesi.xcodeproj` (project-only; bkz. not) |
| Paket kimliği | `com.example.kelimebahcesi` (yer tutucu) | `com.example.kelimebahcesi` (yer tutucu) |
| Mimari | `arm64-v8a` | `arm64` |
| Kaynak filtresi | `all_resources` | `all_resources` |
| Eklenen dosyalar | `data/*.json`, `config/network.json`, `assets/legal/*.txt` | `data/*.json`, `config/network.json`, `assets/legal/*.txt` |
| Hariç tutulanlar | `backend/*`, `docs/*`, `tests/*`, `tools/*`, `.opencode/*`, `opencode.json`, `README.md`, `LICENSE`, `builds/*` | aynı |
| İmzalama | Boş keystore alanları; sır yok | Boş Team ID / sertifika / profil alanları; sır yok |
| INTERNET | Açık (`permissions/internet=true`) | Ağ erişimi için ek izin anahtarı yok; üretimde `wss://` |

> **iOS çıktı notu (resmî kaynakla doğrulandı):** Godot 4.5.2'de `EditorExportPlatformAppleEmbedded::get_binary_extensions` yalnızca iki uzantı döndürür: `application/export_project_only=true` ise **`xcodeproj`**, değilse **`ipa`**. `.zip` geçerli bir iOS çıktı uzantısı değildir. Bu nedenle preset, sertifika/profil gerektirmeyen **project-only** moda ayarlanmıştır: macOS'ta `builds/ios/kelime_bahcesi/` klasörü ve `builds/ios/kelime_bahcesi.xcodeproj` üretilir; imzalama/arşivleme Xcode'da yapılır. Project-only modda bile Godot `application/app_store_team_id` alanının dolu olmasını ister (kaynak: `editor/export/editor_export_platform_apple_embedded.cpp`); Team ID depoya yazılmaz, yerel/CI ortamında girilir.

`config/network.json` yalnızca mevcutsa paketlenir. `config/network.example.json` oluşturulsa bile oyunun kullanacağı dosya `config/network.json`'dır.

### 2.1 Hariç tutma filtreleri hakkında

Godot'un export filtrelerinde `*` joker karakteri **`/` dahil** her karakter dizisiyle eşleşir. Bu nedenle `backend/*` yalnızca üst klasörü değil, `backend/` altındaki tüm alt klasörleri de kapsar. `backend/**` Godot'un `String.match` uygulamasında özel bir anlam taşımaz; `backend/*` yeterlidir. Yine de export öncesi **Project > Export > Resources** sekmesindeki dosya listesinden doğrulayın.

Nokta ile başlayan klasörler (`.opencode`, `.git` vb.) Godot tarafından zaten atlanır; yine de açıkça dışarıda bırakılmıştır. `backend/` altındaki `node_modules`, test dosyaları ve sunucu bağımlılıkları oyun paketine girmemelidir.

`README.md`, `LICENSE` ve `docs/` normalde oyun kaynağı değildir; yine de yanlışlıkla paketlenmemeleri için listede tutulur. `.json` dosyaları Godot'ta otomatik "resource" sayılmadığı için `data/*.json` ve varsa `config/network.json` `include_filter` ile eklenir. Aynı şekilde `assets/legal/*.txt` lisans/telif dosyaları da `all_resources` kapsamına girmediğinden `include_filter` ile açıkça eklenir; bu dosyalar dağıtılan oyunda bulunmalıdır.

### 2.2 Preset dosyasının sürüm kontrolü

Bu dosya keystore, şifre, Team ID veya provisioning profili içermez; paylaşılabilir. `.gitignore` presetleri hariç tutmaz; imzalama sırlarını ve `builds/` çıktılarını hariç tutar. Gerçek sırları `.godot/export_credentials.cfg` veya CI ortamında saklayın.

## 3. Android

### 3.1 Gereksinimler

Godot 4.5'in Android export gereksinimleri:

> Bunlar motorun geliştirme gereksinimleridir, güncel Google Play hedef API politikasının garantisi değildir. Mağazaya göndermeden önce o tarihte istenen target SDK düzeyini ve gerekirse güncel Godot/export template sürümünü doğrulayın.

- **OpenJDK 17** (önerilen; daha yeni JDK'ler desteklenir ancak 17 en güvenli seçimdir).
- Android SDK bileşenleri:
  - Android SDK Platform 35
  - Android SDK Build-Tools 35.0.0 (veya üstü)
  - Android SDK Platform-Tools 35.0.0 (veya üstü)
  - Android SDK Command-line Tools (latest)
  - Gradle/özel derleme kullanacaksanız: NDK r28b (`28.1.13356709`) ve CMake `3.10.2.4988404`
- Godot 4.5.2 export template'leri.
- Standart APK export'u için Gradle zorunlu değildir; Godot'un hazır Android template'i kullanılır. Gradle build yalnızca AAB, özel manifest veya eklenti entegrasyonu için gerekir.

`sdkmanager` ile örnek kurulum (yol sizde farklı olabilir):

```powershell
sdkmanager --sdk_root="$env:LOCALAPPDATA\Android\Sdk" `
  "platform-tools" "build-tools;35.0.0" "platforms;android-35" `
  "cmdline-tools;latest" "cmake;3.10.2.4988404" "ndk;28.1.13356709"
```

### 3.2 Godot editör ayarları

**Editor > Editor Settings > Export > Android** bölümünde:

- **Java SDK Path:** JDK 17 kök klasörü (ör. `C:\Program Files\Eclipse Adoptium\jdk-17...`).
- **Android Sdk Path:** Android SDK kökü (ör. `%LOCALAPPDATA%\Android\Sdk`).
- Debug keystore: Godot geliştirme için kendi debug keystore'unu kullanır/oluşturur. Bu dosya ve parolası depoya eklenmemelidir.
- Release keystore: Yalnızca mağaza/dağıtım için, yerel makinede veya CI sırrı olarak yapılandırılır. `export_presets.cfg` içinde boş bırakılmıştır.

### 3.3 Dikey yönlendirme, boyut ve INTERNET

- `project.godot` içinde `display/window/handheld/orientation=1` (portrait) ve `display/window/size/viewport_width=480`, `viewport_height=900` ayarlıdır. Android manifest yönlendirmesi bu proje ayarından üretilir; export preset'inde ayrı bir "orientation" seçeneği yoktur.
- Android preset'inde `permissions/internet=true` olduğu için release manifest'ine `android.permission.INTERNET` eklenmelidir. Debug export'ta Godot ayrıca INTERNET ekleyebilir; bu, release için izin olduğu anlamına gelmez.
- `screen/immersive_mode=true` ve `screen/edge_to_edge=false`: oyun alanı sistem çubuklarının altına taşmaz. Yine de çentik/kamera deliği için güvenli alan testi yapın.
- Preset'te başka hassas izin yoktur. Konum, kamera, mikrofon, kişiler vb. istenmez.

APK içindeki izni doğrulama (build-tools yolunu kendinize göre ayarlayın):

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\build-tools\35.0.0\aapt.exe" dump permissions "builds\kelime-bahcesi.apk"
```

Çıktıda `android.permission.INTERNET` görünmelidir. Cihazda yönlendirmeyi test etmek için uygulamayı açıp telefonu döndürün; oyun dikey kalmalıdır.

### 3.4 APK export

Önce çıktı klasörünü oluşturun; Godot hedef klasör yoksa export'u reddeder:

```powershell
New-Item -ItemType Directory -Force builds | Out-Null
```

Editörden: **Project > Export > Android > Export Project**; hedef `builds/kelime-bahcesi.apk`.

Komut satırından debug APK:

```powershell
& "C:\Tools\Godot_v4.5.2-stable_win64.exe" --headless --path . `
  --export-debug "Android" "builds/kelime-bahcesi.apk"
```

Release APK, geçerli bir release keystore yapılandırılmadan üretilmemelidir:

```powershell
& "C:\Tools\Godot_v4.5.2-stable_win64.exe" --headless --path . `
  --export-release "Android" "builds/kelime-bahcesi.apk"
```

Bu komut, keystore/alias/parola alanları boşken hata verirse bu beklenen bir durumdur; önce imzalamayı yapılandırın. Release keystore'u kaybetmek, mağazadaki uygulamayı güncelleyememek anlamına gelir; güvenli bir yerde yedekleyin.

### 3.5 Google Play için AAB

Google Play yeni uygulamalarda AAB ister. APK preset'i geliştirme/yan yükleme içindir. AAB için:

1. **Project > Install Android Build Template** ile Gradle şablonunu kurun.
2. Preset'te **Gradle Build > Use Gradle Build** seçeneğini açın.
3. **Export Format**'ı `Export AAB` yapın (preset'te `gradle_build/export_format=1`).
4. Release keystore ve imzalamayı yapılandırın; `--export-release "Android" "builds/kelime-bahcesi.aab"` ile üretin.

Bu adımlar bu depoda çalıştırılmamıştır; mağaza öncesi ayrıca doğrulanmalıdır.

### 3.6 Yerel ağda telefonla test (aynı Wi-Fi)

1. Bilgisayarda backend'i başlatın (`backend` dizininde `npm install` ve `npm start`). Backend içeriği doğrudan `data/levels_tr.json` ve `data/levels_en.json` dosyalarından okur; oyunla aynı veriyi kullanır, ayrı bir birleştirilmiş dosya gerekmez (`LEVELS_FILE` yalnızca özel içerik denemek içindir). Telefonla aynı ağdan erişilecekse yalnızca localhost'a bağlanmayın; LAN arayüzünü seçin (ör. PowerShell: `$env:HOST="0.0.0.0"; npm start`).
2. Sunucunun yalnızca `127.0.0.1`'e değil, LAN arayüzünde (`0.0.0.0`) dinlediğini doğrulayın. Yalnızca localhost'a bağlanan bir sunucuya telefon erişemez.
3. Bilgisayarın IPv4 adresini alın:

   ```powershell
   ipconfig
   ```

   Örnek: `192.168.1.42`.
4. `config/network.json` içindeki `url` değerini telefonun erişebileceği adrese çevirin. Kanonik yol **`/ws`**'tir; backend kök adresi de kabul eder, ancak yeni yapılandırmalarda `/ws` kullanın:

   ```json
   { "url": "ws://192.168.1.42:8787/ws" }
   ```

   Telefonda `127.0.0.1` veya `localhost` **kullanmayın**; bu, telefonun kendisini gösterir.
5. Telefon ve bilgisayar aynı Wi-Fi ağında olmalı; misafir ağı/izolasyon (AP isolation) kapalı olmalıdır.
6. Windows Güvenlik Duvarı ilk bağlantıda sorarsa yalnızca **Özel ağlar** için izin verin. Soru gelmezse kullanıcı olarak **Windows Defender Firewall > Gelişmiş Ayarlar > Gelen Kuralları** üzerinden 8787/TCP için bilinçli bir kural eklenebilir. **Güvenlik duvarını kapatmayın** ve güvenlik duvarını otomatik değiştiren scriptler çalıştırmayın; bu proje bunu yapmaz.
7. USB ile test ediyorsanız güvenlik duvarına dokunmadan port yönlendirme kullanabilirsiniz:

   ```powershell
   adb reverse tcp:8787 tcp:8787
   ```

   Bu durumda telefonda `ws://127.0.0.1:8787/ws` çalışabilir; `adb reverse` yalnızca bağlı cihaz için geçicidir.

### 3.7 Android'de cleartext / `ws://`

Preset'te `usesCleartextTraffic` veya geniş bir ağ güvenliği istisnası **yoktur**. Godot'un `WebSocketPeer` uygulaması ham TCP soketi kullanır; bu nedenle Android'in cleartext politikası her durumda aynı şekilde uygulanmayabilir. Buna rağmen yerel `ws://` bazı cihaz/OS sürümlerinde veya OEM güvenlik politikalarında engellenebilir.

- Önce sunucunun LAN'da dinlediğini, doğru IP/port kullanıldığını ve güvenlik duvarının izin verdiğini kontrol edin.
- Gerekirse **yalnızca debug** için özel Gradle build kullanın: **Project > Install Android Build Template**, ardından `res://android/build` altındaki Android manifestini/network security config'i düzenleyin ve `gradle_build/use_gradle_build=true` yapın. Godot 4.5.2 export preset'inde doğrudan bir `custom_manifest` seçeneği yoktur; manifest özelleştirmesi Gradle şablonu üzerinden yapılır.
- Cleartext istisnasını release paketine **taşımayın**. Üretimde Cloudflare Worker veya TLS sonlandıran bir sunucu üzerinden `wss://` kullanın.

### 3.8 Android güvenli alan ve klavye

- Cihazda çentik, delikli ekran ve home indicator varsa HUD/butonların kesilmediğini kontrol edin.
- Godot'ta `DisplayServer.get_display_safe_area()` ve `DisplayServer.get_display_cutouts()` ile güvenli alanı sorgulayın; sabit 480 × 900 varsayımıyla kritik butonları en üst/alt kenara yapıştırmayın.
- Takma ad alanı açıkken sanal klavye oyun alanını kapatmamalı; `adjustResize` davranışı ve kaydırma test edilmelidir.
- `screen/immersive_mode=true` sistem çubuklarını gizler; klavye açıldığında geri gelme davranışını cihazda doğrulayın.

## 4. iOS

### 4.1 Kesin sınır: macOS gerekir

- iOS export **yalnızca macOS + Xcode** ortamında yapılabilir. Windows'ta Godot iOS projesi üretmeye çalışsanız bile imzalı cihaz/mağaza çıktısı alamazsınız; WSL bir çözüm değildir.
- Cihazda test ve App Store dağıtımı için Apple Developer hesabı, sertifika ve provisioning profili gerekir.
- Bu depo Windows'ta geliştirildiği için iOS export'u burada **doğrulanmamıştır**.

### 4.2 Preset ayarları

- `application/bundle_identifier="com.example.kelimebahcesi"` yer tutucudur; kendi ters alan adınızla değiştirin.
- `application/app_store_team_id`, sertifika kimliği ve provisioning profili alanları **boştur**; bunlar depoya yazılmamalıdır. macOS'ta editor/CI ortamında doldurulur.
- `application/export_project_only=true`: yalnızca Xcode projesi üretilir; imzalama/arşivleme `.ipa` üretimi Xcode'da yapılır. Bu modda bile Godot Team ID ister; sertifika/profil zorunlu değildir.
- `application/min_ios_version="14.0"` (Godot 4.5'in minimum hedefi).
- `application/export_method_debug=1` (Development), `application/export_method_release=0` (App Store).
- `application/targeted_device_family=2` (iPhone + iPad). Yalnızca iPhone hedefliyorsanız `0` yapın.
- `architectures/arm64=true`; Apple Silicon Mac ve modern cihazlar için standarttır.
- Team ID boşken Godot export'un başarısız olması normaldir; iOS exporter Team ID olmadan projeyi yapılandırmaz.

macOS'ta project-only export (hedef klasör önceden oluşturulmalı; Godot olmayan klasöre export etmez):

```bash
mkdir -p builds/ios
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path . \
  --export-release "iOS" "builds/ios/kelime_bahcesi.xcodeproj"
```

Çıktı: `builds/ios/kelime_bahcesi/` (proje dosyaları) ve `builds/ios/kelime_bahcesi.xcodeproj`. Xcode'da açıp Team ID/imzalama seçin, cihazda çalıştırın veya arşivleyip App Store Connect'e yükleyin. İmzalı `.ipa` üretmek isterseniz `application/export_project_only=false` yapıp `--export-release "iOS" "builds/ios/kelime_bahcesi.ipa"` kullanın; bu mod macOS + geçerli imzalama gerektirir.

### 4.3 ATS, ağ ve yerel ağ izni

- Üretimde **`wss://`** kullanın ve Worker adresine `/ws` yolunu ekleyin (`wss://<worker>.workers.dev/ws`). Preset'te `NSAllowsArbitraryLoads` veya geniş bir ATS istisnası **yoktur**; eklenmemelidir.
- Godot'un WebSocket istemcisi ham TCP kullanır; ATS'nin tüm WebSocket trafiğine otomatik uygulanacağını varsaymayın. Yine de mağaza incelemesi ve güvenli üretim için TLS zorunlu kabul edilmelidir.
- iOS 14+ yerel ağa bağlanırken "Local Network" izni isteyebilir. Yerel geliştirme testi için `Info.plist`'e `NSLocalNetworkUsageDescription` eklemek gerekebilir. Bunu yalnızca geliştirme için `application/additional_plist_content` alanına ekleyin ve **release preset'ine taşımayın**:

  ```xml
  <key>NSLocalNetworkUsageDescription</key>
  <string>Yerel ağdaki oyun sunucusuna bağlanmak için kullanılır.</string>
  ```

  Bu anahtar, üretimde Cloudflare `wss://` kullanılıyorsa gerekli değildir. Eklerken geçerli bir plist parçası olduğundan emin olun; hatalı içerik export'u durdurur.
- iOS'ta da telefonda `localhost` kullanmayın; aynı Wi-Fi'daysanız bilgisayarın LAN IP'sini kullanın.

### 4.4 Güvenli alan ve klavye

- Çentik/Dynamic Island ve home indicator için `DisplayServer.get_display_safe_area()` kullanın; kenardaki butonlar ve alt menü kesilmemeli.
- iPad'de farklı en-boy oranı ve split view/rotation davranışını test edin; oyun dikey kalmalı.
- Takma ad alanı ve klavye açıkken odaklanan alan görünür kalmalı; klavye kapatma ve geri dönme akışı test edilmelidir.
- iOS simülatörü Godot 4.5.2 tarafından desteklenmez; gerçek cihaz veya Apple Silicon Mac üzerinde çalıştırma gerekir.

## 5. Mağaza, ücretsiz katman ve maliyet gerçekleri

- **Google Play** ve **Apple Developer** başvuruları ücretlidir; ücretler ve politikalar zamanla değişebilir. "Tamamen ücretsiz yayınlama" garanti edilemez. Mağaza hesapları, vergi/ödeme bilgileri ve inceleme süreçleri bu deponun dışındadır.
- **Cloudflare Workers Free** planı bu projenin gündelik oda trafiği için yeterli hedeflenir; ancak ücretsiz plan **sınırsız değildir**. Günlük istek sayısı, CPU süresi, Durable Objects süresi/depolaması ve bağlantı sayısı gibi sert sınırlar vardır. Sınırlar Cloudflare tarafından değiştirilebilir; güncel değerleri panelden doğrulayın.
- Bu kapsam için ücretli Cloudflare planı zorunlu değildir; ancak trafik/oda ömrü ücretsiz kotayı aşarsa hizmet reddedilebilir. Ücretsiz katmanın "sınırsız" olduğu iddia edilmemelidir.
- Oda durumu bellekte tutulur ve kalıcı değildir; sunucu/Worker yeniden başlarsa odalar kaybolur. Bu, gündelik oyun için kabul edilen bir sınırdır.
- İçerik istemci paketinde olduğu için backend anti-cheat garantisi vermez. Sıralama/para ödülü gibi rekabetçi sistemler bu sürümün kapsamında değildir.

## 6. Mağaza öncesi kontrol listesi

Aşağıdakiler bu depoda **işaretlenmemiştir**; her madde gerçek bir cihaz/ortamda doğrulanmalı ve kanıtı saklanmalıdır.

- [ ] Godot 4.5.2 ve export template sürümü birebir eşleşiyor.
- [ ] Android: JDK 17, SDK 35, build-tools/platform-tools kurulu; editör yolları doğru.
- [ ] Android debug APK `builds/kelime-bahcesi.apk` üretildi ve cihaza kuruldu.
- [ ] APK'da `android.permission.INTERNET` var; başka hassas izin yok.
- [ ] Uygulama dikey açılıyor; 480 × 900 yerleşim çentik/home indicator'da taşmıyor.
- [ ] `data/levels_tr.json` ve `data/levels_en.json` pakette; `assets/legal/GODOT_LICENSE.txt` ve `GODOT_COPYRIGHT.txt` pakette; `backend/`, `docs/`, `tests/`, `tools/`, `.opencode/`, `opencode.json`, `README.md` pakette yok.
- [ ] `config/network.json` yalnızca yapılandırıldıysa pakette; örnek dosya yanlışlıkla üretim adresi olarak kullanılmıyor.
- [ ] Yerel `ws://` testi aynı Wi-Fi'da çalışıyor; güvenlik duvarı kullanıcı tarafından bilinçli yapılandırıldı.
- [ ] Üretim adresi `wss://…/ws`; cleartext/ATS geniş istisnası yok.
- [ ] Release keystore yapılandırıldı ve yedeklendi; depoda sır yok.
- [ ] Google Play için AAB üretildi ve imzalandı (gerekiyorsa).
- [ ] iOS: macOS/Xcode'da `builds/ios/kelime_bahcesi.xcodeproj` üretildi; Team ID/bundle ID doğru; Xcode'da imzalanıp cihazda veya App Store Connect'te doğrulandı.
- [ ] iOS güvenli alan, klavye ve yerel ağ izni gerçek cihazda test edildi.
- [ ] Mağaza gizlilik formu: hesap yok, yerel kayıt, geçici takma ad, sohbet yok, hazır tepkiler, geçici odalar.
- [ ] Mağaza ücretleri/hesapları ve yayın politikaları ayrıca onaylandı.
- [ ] Sürüm kodu/numarası artırıldı; mağaza paket kimliği değiştirilmedi.

## 7. Sık karşılaşılan sorunlar

| Belirti | Olası neden / çözüm |
| --- | --- |
| "Export template not found" | Template sürümü editörle eşleşmiyor veya Android/iOS template kurulu değil. 4.5.2 template'lerini yeniden kurun. |
| Android export "SDK path not set" | Editor Settings > Export > Android yolları boş. JDK 17 ve SDK 35 yolunu ayarlayın. |
| APK telefonda açılmıyor | Aynı paket adı farklı anahtarla kurulu olabilir; eski uygulamayı kaldırın. Release/debug imza uyuşmazlığını kontrol edin. |
| Telefon sunucuya bağlanamıyor | `localhost` kullanılıyor, sunucu sadece 127.0.0.1'de dinliyor, yanlış IP/port veya güvenlik duvarı. LAN IP + 0.0.0.0 + özel ağ izni. |
| WebSocket bağlantısı hemen kapanıyor / upgrade reddediliyor | Eski backend `/ws` dışındaki yolları reddediyordu; güncel backend kök adresi de kabul eder. Yine de `ws://<host>:8787/ws` kullanın ve sunucunun güncel sürümde olduğunu doğrulayın. |
| iOS export `.zip` hedefini reddediyor | Godot 4.5.2 iOS çıktısı `.zip` değildir; project-only modda `.xcodeproj`, aksi halde `.ipa` kullanın. |
| `npm start` "Cannot read levels file" hatası veriyor | Güncel backend `data/levels_tr.json` + `data/levels_en.json` dosyalarını birleştirir; hata devam ediyorsa dosyaların yerinde olduğunu ve gerekirse `LEVELS_FILE` ayarını kontrol edin. |
| iOS export "App Store Team ID not specified" | Team ID zorunludur; macOS'ta editor/CI ortamında girin, depoya yazmayın. |
| iOS "can only be built on macOS" | Windows'ta imzalı iOS çıktısı alınamaz; macOS + Xcode gerekir. |
| Pakette backend dosyaları var | `exclude_filter` doğru mu, Export > Resources listesini kontrol edin; `backend/*` kullanın. |
| `config/network.json` pakette yok | Dosya mevcut değil veya `include_filter` güncel değil. Dosyayı oluşturun; `data/*.json,config/network.json,assets/legal/*.txt` filtresini doğrulayın. |
| Lisans dosyaları pakette yok | `assets/legal/*.txt` `all_resources` kapsamına girmez; `include_filter` içinde olduğundan emin olun ve Export > Resources listesini kontrol edin. |

## 8. İlgili belgeler

- [Gereksinimler ve izlenebilirlik](REQUIREMENTS.md)
- [Test planı](TESTING.md)
- [Gizlilik politikası taslağı](PRIVACY.md)
- [README](../README.md)
