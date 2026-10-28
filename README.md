# Kelime Bahçesi / Word Garden

İki dilli (**Türkçe / English**), dikey mobil öncelikli bir kelime zinciri oyunu. Godot **4.5.2** ve GDScript: 36 bölüm, pastel arayüz, çevrimdışı oyun, parti modu ve gerçek WebSocket yarışması.

> **Durum: oynanabilir kaynak proje.** Çekirdek, içerik, 480×900 arayüz ve gerçek sunucuyla TR/EN yarışma akışları test edildi. Cloudflare deneme derlemesi geçti; canlı dağıtım yapılmadı. **İmzalı APK/IPA, Android/iOS cihaz testi ve mağaza yayını henüz yoktur.** Kanıtlar ve sınırlar: [docs/TESTING.md](docs/TESTING.md).

## Özellikler

Görseller: [Ana ekran](docs/screenshots/home.png) · [Oyun](docs/screenshots/play.png) · [Parti](docs/screenshots/party.png) · [Çevrimiçi yarışma](docs/screenshots/online_tr_match.png)

- **480 × 900 dikey** oyun alanı, pastel renk paleti, dokunmatik öncelikli arayüz.
- **Türkçe ve İngilizce** içerik; dil bazlı ilerleme ve altın.
- **Çevrimdışı kategoriler** ve rahat **Parti** modu: cevaplar açık görülebilir, yeni rastgele zincir için dokunulur; sıra/puan/tur yoktur.
- **Kalıcı kayıt:** `user://save.json` ve yedek dosyası; hesap gerekmez.
- **Ekonomi:** başlangıç **100 altın**, **Harf Al** **15 altın**, ipucu **10 altın**, bölümü ilk kez tamamlama ödülü **25 altın**.
- **Çevrimiçi odalar:** yerel Node.js sunucusu veya ücretsiz Cloudflare Workers + Durable Objects hedefi; oda kodu ile katılım. İkinci oyuncu katıldığında oda **3 saniyelik geri sayımla otomatik** başlar; hazır/ready butonu yoktur.
- **Sınırlı sosyal etkileşim:** yalnızca hazır (canned) tepkiler; serbest metin sohbeti yok.
- **İçerik:** her dilde **18 tamlama** (TR + EN toplam **36**); sayılar içerik testleriyle doğrulanır.

## Gereksinimler

| Araç | Sürüm / not |
| --- | --- |
| Godot Engine | **4.5.2** (standart sürüm; .NET/Mono gerekmez). Export için aynı sürümün export template'leri gerekir. |
| Node.js | Yerel çevrimiçi sunucu ve backend testleri için. `npm` ile birlikte gelir. |
| İşletim sistemi | Masaüstü geliştirme Windows'ta yapılabilir. iOS derlemesi için macOS + Xcode + Apple imzalama gerekir. |
| Android export | JDK 17 + Android SDK 35 bileşenleri. Ayrıntılar: [docs/MOBILE_EXPORT.md](docs/MOBILE_EXPORT.md). |

## Hızlı başlangıç

1. Godot **4.5.2**'yi kurun veya taşınabilir sürümünü indirin.
2. Godot Project Manager'da **Import** seçip depo kökündeki `project.godot` dosyasını açın. Proje kökü doğrudan bu depodur; alt klasörden ayrı bir proje açmayın.
3. Editörde **F5** ile tüm projeyi çalıştırın. **F6** yalnızca o anda açık olan sahneyi çalıştırır; ana akışı denemek için F5 kullanın.
4. Masaüstü penceresi 480 × 900 olarak ayarlanmıştır. Pencereyi büyütmek oyun mantığını değiştirmez; mobil yerleşimi test etmek için dikey oranı koruyun.

Komut satırından çalıştırmak isterseniz (Godot yolu kendi kurulumunuza göre değişir):

```powershell
& "C:\Tools\Godot_v4.5.2-stable_win64.exe" --path .
```

İlk açılışta Godot'un `.godot/` içe aktarma önbelleğini oluşturması normaldir.

## Nasıl oynanır

- Zincirin **ilk kelimesi açık** verilir.
- Sıradaki kelimenin yalnızca **ilk harfi** gösterilir; kalan harfler boş bırakılır.
- Aynı anda **tek kelime** yazıp gönderirsiniz. Doğruysa kelime açılır ve bir sonraki kelimeye geçilir; **yanlış veya eksik kelime** kabul edilmez, zincir ilerlemez.
- **Harf Al (15 altın)** mevcut kelimedeki gizli harflerden **rastgele birini** açar; birden fazla harf ya da sonraki kelimelerin ilk harfleri topluca açılmaz.
- **İpucu (10 altın)** o kelime için ipucunu gösterir.
- **Parti** modu rahat oynanış içindir: cevaplar açık görülebilir ve yeni rastgele zincir için dokunulur. Yerel iki oyunculu sıra/puan/tur akışı yoktur.

## Çevrimiçi mod (yerel)

Çevrimiçi mod isteğe bağlıdır; çevrimdışı oyunun çalışması için sunucu gerekmez.

1. İsteğe bağlı: `config/network.example.json` dosyasını `config/network.json` olarak kopyalayın. Dosya yoksa oyun zaten `ws://127.0.0.1:8787/ws` kullanır.
2. Yerel geliştirme için `url` alanını `ws://127.0.0.1:8787/ws` olarak ayarlayın (`/ws` kanonik yoldur). Backend kök adresi de (`ws://127.0.0.1:8787`) kabul eder; ancak yeni yapılandırmalarda `/ws` kullanın.
3. Backend dizinine gidin ve sunucuyu başlatın:

   ```powershell
   cd backend
   npm install
   npm start
   ```

   Backend içeriği doğrudan `data/levels_tr.json` ve `data/levels_en.json` dosyalarından okur; oyunla aynı veriyi kullanır, ayrı bir birleştirilmiş `levels.json` gerekmez. `LEVELS_FILE` yalnızca özel bir içerik dosyası denemek isterseniz gerekir. Telefonla aynı Wi-Fi'dan bağlanacaksanız sunucunun yalnızca `127.0.0.1`'e değil, LAN arayüzünde dinlemesi gerekir; PowerShell'de `$env:HOST="0.0.0.0"; npm start` kullanın. Yalnızca localhost'a bağlanan bir sunucuya telefon erişemez.

4. Aynı ağdaki bir telefondan bağlanacaksanız `127.0.0.1` veya `localhost` **kullanmayın**; telefonun kendisine bağlanmaya çalışır. Bilgisayarın yerel IPv4 adresini (`ipconfig`) kullanın, örneğin `ws://192.168.1.42:8787/ws`.
5. Windows Güvenlik Duvarı ilk çalıştırmada sorarsa yalnızca **Özel ağlar** için izin verin. Güvenlik duvarını kapatmayın ve güvenlik duvarı kurallarını otomatik değiştiren scriptler çalıştırmayın.

İkinci oyuncu odaya katıldığında oda **3 saniyelik geri sayımla otomatik** başlar; ayrı bir "hazır" mesajı veya butonu yoktur. Takma adlar aynı olabilir; sunucu oyuncuları oturum kimlikleriyle ayırır.

Üretimde `wss://` kullanılmalıdır. Yerel `ws://` yalnızca geliştirme içindir; Android/iOS'ta cleartext davranışı cihaz ve işletim sistemi sürümüne göre değişebilir. Ayrıntılı kontrol listesi: [docs/MOBILE_EXPORT.md](docs/MOBILE_EXPORT.md).

### Cloudflare Workers hedefi

Backend, yerel Node.js sunucusu ile aynı protokolü kullanacak şekilde ücretsiz Cloudflare Workers + Durable Objects üzerinde de çalışacak şekilde tasarlanmıştır. İstemci her iki durumda da tek bir WebSocket adresine bağlanır; Worker adresi de `/ws` ile bitmelidir (ör. `wss://<worker>.workers.dev/ws`). Ücretsiz katmanın günlük istek, CPU süresi ve Durable Objects depolama/süre sınırları **sert sınırlardır**; sınırlar Cloudflare tarafından değiştirilebilir. Bu proje için ücretli plan zorunlu değildir, ancak ücretsiz katmanın sınırsız olduğu iddia edilemez. Güncel kota ve plan koşullarını Cloudflare panelinden doğrulayın.

## Ekonomi ve kayıt

| Kural | Değer |
| --- | --- |
| Başlangıç altını | 100 |
| Harf Al (rastgele bir gizli harf) | 15 altın |
| İpucu | 10 altın |
| İlk tamamlama ödülü | 25 altın |

Altın ve ilerleme dil bazında tutulur. Kayıt yereldir (`user://save.json`, yedek: `user://save.json.bak`); bulut kayıt veya hesap sistemi yoktur. Kayıt bozulursa uygulama yedek dosyasına dönmeyi dener; yine de kritik testlerde temiz kurulum ve yeniden başlatma denenmelidir.

## Proje yapısı

```text
project.godot          Godot proje ayarları (kök)
core/                  Çekirdek GDScript: içerik, kayıt, i18n, oturum, ağ istemcisi
ui/                    Ekranlar, tema, yerelleştirme ve arayüz bileşenleri
data/                  levels_tr.json / levels_en.json içerik dosyaları
assets/legal/          Godot lisans ve telif bildirimleri (pakete dahil edilir)
backend/               Yerel Node.js sunucusu ve Cloudflare Workers dağıtımı
config/                Yerel ağ yapılandırması (network.example.json -> network.json)
tests/                 test_core.gd / test_content.gd (varsayılan) + isteğe bağlı UI/ağ testleri
tools/                 Geliştirici araçları (run_tests.ps1)
docs/                  Gereksinimler, mobil export ve test planı
export_presets.cfg     Android ve iOS export presetleri (sır içermez)
```

Mimari ve API sözleşmeleri: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). Geliştirme planı ve kalan yayın adımları: [docs/PLAN.md](docs/PLAN.md). Tamlama içerik incelemesi: [docs/CONTENT_REVIEW.md](docs/CONTENT_REVIEW.md).

## Testler

Godot ve Node.js kuruluysa:

```powershell
.\tools\run_tests.ps1
```

Araç, Godot'yu `godot`/`godot4` komutlarından veya `-GodotPath` parametresinden bulur; başsız (headless) içe aktarma yapar, `tests/test_core.gd` ve `tests/test_content.gd` dosyalarını çalıştırır, ardından `backend/package.json` varsa `npm test` çalıştırır. Godot bazı hatalarda **0 çıkış kodu** döndürebildiği için çıktı ayrıca denetlenir: `SCRIPT ERROR`, `Parse Error` veya `Failed to load script` görülürse adım başarısız sayılır. Dosya veya çalışma zamanı yoksa test **atlanır**; bu, testin geçtiği anlamına gelmez.

```powershell
.\tools\run_tests.ps1 -GodotPath "C:\Tools\Godot_v4.5.2-stable_win64.exe"
.\tools\run_tests.ps1 -SkipBackend
.\tools\run_tests.ps1 -IncludeUI       # tests/test_ui.gd varsa çalıştırır (arayüz değişirken kırılgan)
.\tools\run_tests.ps1 -IncludeNetwork  # çalışan bir WebSocket sunucusu gerektirir
.\tools\run_tests.ps1 -IncludeUI -IncludeNetwork -NetworkUrl "ws://127.0.0.1:8787/ws" -Strict
.\tools\run_tests.ps1 -Strict          # eksik test dosyalarını da hata sayar
```

`-IncludeNetwork` hem bağımsız iki soketli protokol testini hem oyunun kendi çevrimiçi ekranını çalıştırır. Test kapsamı ve gerçek sonuçlar: [docs/TESTING.md](docs/TESTING.md). Cihaz/mağaza testleri masaüstü testlerinden ayrıdır.

## Mobil export

- Android ve iOS presetleri `export_presets.cfg` içinde tanımlıdır; **imzalama anahtarları, şifreler ve takım kimlikleri boş bırakılmıştır**. Her iki preset de `assets/legal/*.txt` lisans/telif dosyalarını pakete ekler.
- Android çıktısı `builds/kelime-bahcesi.apk`, iOS çıktısı **Xcode projesi** `builds/ios/kelime_bahcesi.xcodeproj` olarak hedeflenir (`application/export_project_only=true`). Godot 4.5.2'de `.zip` geçerli bir iOS çıktı uzantısı değildir; geçerli biçimler yalnızca `.xcodeproj` (project-only) ve `.ipa`'dır.
- iOS projesini imzalayıp cihaza/mağazaya hazırlamak için macOS + Xcode + Apple imzalama gerekir; Team ID depoda tutulmaz, export sırasında yerel/CI ortamında girilir. Windows'ta yalnızca preset yapılandırılabilir, imzalı iOS çıktısı alınamaz.
- Export template sürümü editör sürümüyle **tam olarak 4.5.2** eşleşmelidir.
- Android'de `INTERNET` izni ve dikey yönlendirme vardır; başka hassas izin istenmez.
- Mağaza başvuru ücretleri (Google Play ve Apple Developer) proje dışındadır; ücretsiz yayınlama garanti edilemez.

Tam adımlar, sürüm gereksinimleri, yerel ağ/güvenlik duvarı notları ve mağaza öncesi kontrol listesi: [docs/MOBILE_EXPORT.md](docs/MOBILE_EXPORT.md).

## Gizlilik ve güvenlik

- Hesap, e-posta, reklam veya serbest metin sohbeti yoktur.
- Takma ad yalnızca WebSocket oturumu boyunca taşınır; kalıcı profil oluşturulmaz. Aynı takma adı kullanan oyuncular olabilir; sunucu onları ayrı oturum kimlikleriyle ayırır ve takma ad benzersizliği garanti edilmez.
- Çevrimiçi odalar sunucu belleğinde tutulur; sunucu yeniden başlarsa odalar kaybolur.
- İçerik istemci paketinde bulunduğu için backend **anti-cheat garantisi vermez**; bu oyun gündelik (casual) rekabet için tasarlanmıştır.
- Kayıt cihazda yereldir; hesapla cihazlar arası senkronizasyon yoktur.
- Üretimde TLS (`wss://`) kullanılmalı; geniş ATS/cleartext istisnaları eklenmemelidir.
- Ayrıntılı gizlilik metni: [docs/PRIVACY.md](docs/PRIVACY.md).

## Lisans ve varlıklar

Kod MIT lisansıyla sunulur; ayrıntılar [LICENSE](LICENSE) dosyasındadır. Proje için üretilen grafik ve ses varlıkları kendi çalışmamızdır; üçüncü taraf görsel/ses paketi kullanılmamaktadır. Daha sonra üçüncü taraf bir varlık eklenirse lisansı ve atıf bilgisi ayrıca belgelenmelidir.

Oyun motoru **Godot Engine 4.5.2** MIT lisansıyla kullanılır; motorun ve içerdiği üçüncü taraf bileşenlerin bildirimleri şu dosyalardadır:

- [`assets/legal/GODOT_LICENSE.txt`](assets/legal/GODOT_LICENSE.txt) — Godot Engine MIT lisansı
- [`assets/legal/GODOT_COPYRIGHT.txt`](assets/legal/GODOT_COPYRIGHT.txt) — Godot kaynak ağacındaki dosya bazlı telif/lisans bildirimleri

Bu dosyalar her iki export presetinde pakete eklenir; **Ayarlar → Lisanslar** ekranından okunabilir. Sunucu tarafı (Node.js / Cloudflare) oyun paketine dahil değildir ve kendi lisans/koşullarına tabidir. Mağaza başvurusundan önce [docs/PRIVACY.md](docs/PRIVACY.md) içindeki zorunlu yayıncı alanları doldurulmalıdır.
