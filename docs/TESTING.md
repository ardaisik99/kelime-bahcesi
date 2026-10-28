# Test sonuçları ve kabul planı

**Tarih:** 2026-10-28 · **Ortam:** Windows, Godot 4.5.2 standard, Node.js 24.12.0 / npm 11.6.2.

## Gerçekten çalıştırılan kontroller

| Kontrol | Sonuç |
|---|---|
| Başsız proje importu | Geçti; script/parse hatası yok |
| `tests/test_core.gd` | **689 kontrol geçti** |
| `tests/test_content.gd` | **1.255 kontrol geçti**; 18 TR + 18 EN |
| `tests/test_ui.gd` | **73 kontrol geçti**; gerçek 480×900 portre düzen |
| `tests/test_network.gd` | **21 kontrol geçti**; iki bağımsız gerçek WebSocket istemcisi |
| `tests/test_online_ui.gd` | **35 kontrol geçti**; oyunun kendi ekranı/NetworkClient'ı ile iki tam maç |
| `backend` → `npm test` | **39 test geçti**, 0 hata |
| Tam koşum `run_tests.ps1 -IncludeUI -IncludeNetwork -Strict` | **6 test paketi, 0 hata, 0 atlama** |
| Gerçek pencere UI testi | Geçti; `home/party/play/en/play_win` PNG'leri alındı ve incelendi |
| Gerçek pencere online testi | 35 kontrol geçti; TR/EN geri sayım, maç ve sonuç PNG'leri incelendi |
| `wrangler deploy --dry-run` | Geçti; gerçek iki JSON dosyasıyla Worker paketi, hesap girişi yapılmadı |
| `npm audit --omit=dev` | 0 bilinen açık |
| Android preset ile `--export-pack` ZIP | Geçti; 52 paket girdisi; iki içerik JSON'u + iki Godot lisans metni mevcut |
| Paket hariç tutma denetimi | `backend/docs/tests/tools/.opencode`, `opencode.json`, örnek ağ yapılandırması ve geçici test scriptleri **yok** |
| Paketlenmiş oyunun `--main-pack …zip --quit-after 15` açılışı | Geçti; kaynak klasöründeki scriptlere ihtiyaç duymadan açıldı |

UI kontrol sayısı, rastgele parti zinciri 4 yerine 5 kelimeli olduğunda bir artabilir. Bu bir atlama veya başarısızlık değildir.

**Önemli:** Yukarıdaki ZIP, imzalı Android uygulaması değildir; Godot kaynak/veri paketi kontrolüdür. APK/IPA ve gerçek mobil cihaz testleri yapılmadı. Export/import sırasında “Unable to open Android build-tools directory” uyarısı bu makinede Android SDK'nın kurulu olmamasındandır; ZIP üretimi ve paket açılışı geçti.

## Yeniden çalıştırma

Önce ayrı terminalde yerel sunucu:

```powershell
cd backend
npm ci
npm start
```

Proje kökünde:

```powershell
.\tools\run_tests.ps1 `
  -GodotPath "C:\Tools\Godot_v4.5.2-stable_win64_console.exe" `
  -IncludeUI -IncludeNetwork -NetworkUrl "ws://127.0.0.1:8787/ws" -Strict
```

Bu çalışmada varsayılan porta müdahale etmemek için yönetici test sunucusu **8791** portunda başlatıldı; aynı komut `-NetworkUrl "ws://127.0.0.1:8791/ws"` ile çalıştırıldı.

Test aracı Godot yolunu `-GodotPath` → `GODOT_BIN` → PATH sırasıyla bulur. Açıkça verilen yanlış yolu sessizce başka bir motorla değiştirmez. Sadece çıkış koduna değil `SCRIPT ERROR`, parse hatası, `ERROR:` ve sızıntı uyarılarına da bakar. Eksik/atlanmış adımlar `-Strict` ile başarı sayılamaz. `-IncludeNetwork`, bağımsız protokol ve gerçek online ekran testlerini birlikte çalıştırır.

## Otomatik kapsamın ayrıntıları

- **Oynanış:** ilk kelime açık/sabit, aktif kelimenin ilk harfi sabit, gelecek kartlar gizli; yanlış/eksik cevap ilerlemez; doğru kelime tek adım ilerletir; son doğrulamada zafer.
- **Joker/ödül:** ipucu bir kelimede bir kez; harf jokeri yalnızca aktif kelimede tek rastgele yeni harf; yetersiz bakiye/inapplicable işlem ücretsiz; ilk tamamlama +25, tekrarda 0.
- **Kayıt:** kalıcılık, bağımsız dil cüzdanları, bozuk/eksik ana dosyadan yedek kurtarma, iki dosya bozuksa varsayılanlar, yazma hatasında harcama/ödül geri alma.
- **Arayüz:** iki dil ve doğru klavyeler, fiziksel İngilizce `i`, kategori metinleri/genişlikleri, portre yatay taşma, ipucu balonu, konfeti/sonuç, uygulama içi lisans metinleri.
- **Parti:** tüm cevaplar açık, tahmin klavyesi yok, kart ve yeni zincir düğmesi, anlık tekrar yok, altın/ilerleme üretilmez.
- **Çevrimiçi:** TR oda açma; TR menüden EN odaya katılıp dili eşitleme; aynı üç zincir; geri sayımda girişin kapalı olması; rakip puanının ve hazır mesajının ulaşması; yanlış harfin gerçekten yazıldığı gibi gösterilmesi; sunucu reddi; iki tarafın üç zinciri bitirmesi; final puanı; çıkışta soketin kapanması.
- **Backend:** sahte puan, erken/eski/yanlış cevap, son zaman sınırı, iki oyuncu bitişi, ayrılma/kopma, oda ömrü/kapasitesi, mesaj ve tepki sınırlaması, gerçek içerikle `/ws` ve kök yol.

Çekirdek kurtarma testlerindeki “recovered progress from backup / defaults restored” uyarıları kasıtlı fixture sonucudur. UI test sonunda ses havuzu durdurulur; Dummy ses sürücüsünün test kapanışında aktif playback referansı bırakması önlenir.

## Kayıt güvenliği

Testler gerçek oyuncu bakiyesine dokunmaz. Ayrı `user://test_*` kayıtları kullanılır. `garden_ui.json` yedeklenip geri yüklenir; bu yüzden UI/online UI testlerini aynı anda çalıştırmayın. Test dosyaları ve koşumlar paket filtrelerinden dışlanır.

## Kanıt dosyaları

Bu Windows çalışma ortamında:

```text
C:\Users\ArdHP\AppData\Local\Temp\opencode\word-garden-full-tests.log
C:\Users\ArdHP\AppData\Local\Temp\opencode\word-garden-ui-verbose.log
C:\Users\ArdHP\AppData\Local\Temp\opencode\word-garden-pack.log
C:\Users\ArdHP\AppData\Local\Temp\opencode\word-garden-review.zip
C:\Users\ArdHP\AppData\Local\Temp\opencode\word-garden-shots\
```

Bunlar yeniden üretilebilir geliştirme çıktılarıdır; geçici dizin temizlenirse aynı komutlarla tekrar üretin. Ekran görüntüsü komutları [tests/README.md](../tests/README.md) içindedir.

Kalıcı seçilmiş görsel kanıtlar: [`screenshots/`](screenshots/) — ana ekran, oyun, parti, zafer ve çevrimiçi ekranlar. Bunlar masaüstündeki portre test görüntüleridir; mağaza/gerçek cihaz ekran görüntüsü değildir.

## Düzeltme geçmişi

İlk incelemede tüm zinciri doldurtan hatalı çekirdek, jokerin toplu ilk harf açması, parti rotası, mobil kategori kartlarının sıkışması ve online tip çözümlemesi bulundu. Çekirdek doğru ürün kurallarına göre yeniden yazıldı. Son entegrasyonda parti reveal-all akışı, İngilizce fiziksel harf dönüşümü, yanlış online harfin cevapmış gibi çizilmesi, saat senkronizasyonu ve çıkışta soket temizliği düzeltildi. Arayüz testi de eski tüm-zincir akışı yerine güncel kelime-kelime kurallarla yenilendi. Önceki başarısız testler nihai başarı kanıtı olarak kullanılmadı.

## Hâlâ yapılması gereken manuel/yayın kontrolleri

- [ ] Gerçek Android cihaz: APK kurulumu, portre, çentik/güvenli alan, sanal klavye, ses/titreşim, uygulama duraklatma/dönme.
- [ ] Android release imzası, AAB, güncel Play hedef API ve manifest izinleri.
- [ ] macOS/Xcode ile iOS export/imzalama; iPhone/iPad güvenli alan ve klavye testi.
- [ ] Kullanıcı hesabında canlı Cloudflare WSS dağıtımı; farklı ağlardan iki telefonla maç.
- [ ] Uçak modu ve gerçek Wi-Fi/mobil ağ kopması/arka plana geçiş senaryoları.
- [ ] Büyük trafik/yük testi, sağlayıcı kota takibi; ücretsiz kota sınırsız değildir.
- [ ] Mağaza görselleri, iletişim bilgileri, herkese açık gizlilik politikası URL'si ve mağaza formları.

Bu kontroller tamamlanmadan **mağazaya hazır / tüm cihazlarda test edildi** denmez. Kurulum: [MOBILE_EXPORT.md](MOBILE_EXPORT.md).
