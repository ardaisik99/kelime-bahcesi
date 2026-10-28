# Gereksinimler ve izlenebilirlik

**Kelime Bahçesi / Word Garden · Godot 4.5.2 · 2026-10-28**

## Ürün kapsamı

Dikey, pastel bir mobil kelime zinciri oyunu. Her dilin içerikleri ve ilerlemesi ayrıdır. Mutfak, Doğa ve Günlük Yaşam kategorilerinde altışar bölüm vardır: 18 Türkçe + 18 İngilizce. Her zincir 4–5 kelimeden oluşur.

Türkçede cevap köktür; tamlama ek almış biçimiyle gösterilir: `KAŞIK` → “çay kaşığı”. İngilizcede doğal bileşikler/kalıplaşmış çiftler kullanılır; içerik incelemesi [CONTENT_REVIEW.md](CONTENT_REVIEW.md) içindedir.

## İşlevsel gereksinimler

“Masaüstünde geçti” cihazda test edildiği anlamına gelmez. Komutlar ve gerçek sonuçlar [TESTING.md](TESTING.md) dosyasındadır.

| ID | Gereksinim | Uygulama | Doğrulama / durum |
|---|---|---|---|
| FR-01 | 480×900 portre, pastel/yuvarlak kartlar, güvenli alan | `project.godot`, `ui/theme.gd`, `ui/paint.gd`, `ui/main.gd` | Gerçek pencere görüntüleri ve portre UI testi geçti; mobil çentik testi bekliyor |
| FR-02 | Tek dokunuşla TR/EN arayüz/içerik | `core/i18n.gd`, `ui/loc.gd`, üst çubuk | UI ve sözlük eşleşme testleri geçti; aktif solo/maçta dili değiştirmeden önce çıkmak gerekir |
| FR-03 | Çevrimdışı kategoriler ve aşamalı bölümler | `core/content.gd`, `ui/screens/category.gd` | UI kategori/açılış akışı geçti; her kategorinin ilk bölümü açıktır, devamı sırayla açılır |
| FR-04 | Parti: tüm cevaplar açık, dokunarak yeni rastgele zincir | `ui/screens/play.gd`, `ui/chain_view.gd` | Açık cevaplar, klavyesiz mod, kart/düğme ile ilerleme, tekrar önleme ve ödül üretmeme geçti |
| FR-05 | Yerel kayıt: altın, tamamlanan/son oynanan bölüm, ayarlar | `core/save_store.gd`, `ui/api.gd` | Kaydet/yükle ve dil bazlı ayrım geçti; yarım kelime/jokerler oturumluk |
| FR-06 | Başlangıç 100; ipucu 10; tek rastgele harf 15; ilk tamamlama 25 | `GameSession`, `SaveStore` | Çekirdek ve gerçek klavye akışı geçti |
| FR-07 | Aynı bölümden ikinci kez ödül kazanılmaması | `SaveStore.mark_level_completed` | Çekirdek ve arayüz tekrar oynama testleri geçti |
| FR-08 | Bozuk kayıt/yedekten kurtarma ve yazma hatasında geri alma | `core/save_store.gd` | Bozuk/missing kayıt, yedek ve yazılamayan yol testleri geçti |
| FR-09 | Oda koduyla iki oyuncu, 3–2–1, aynı zincirler, 90 sn maç | `core/network_client.gd`, `ui/screens/online.gd`, `backend/` | Gerçek sunucuda oda açma ve farklı dilde odaya katılma geçti |
| FR-10 | Canlı skor ve kısa mesajlar | `online.gd`, `backend/room-engine.mjs` | Sunucu doğrulamalı 100 puan/kelime, rakip skoru ve dört hazır mesaj geçti |
| FR-11 | Ayrılma/kopmada anlaşılır maç sonu | istemci ve backend | Bağımsız soket testi ve backend birim testleri geçti; fiziksel mobil ağ değişimi bekliyor |
| FR-12 | 36 benzersiz, geçerli zincir; doğru alfabe/ipucu/tamlama şeması | `data/levels_*.json` | 1.255 içerik kontrolü ve elle dil incelemesi |
| FR-13 | Android/iOS presetleri, veri ve lisansların pakete alınması | `export_presets.cfg`, `assets/legal/` | Kaynak paket denetimi; gerçek APK/IPA ve imzalama ayrı cihaz adımı |
| FR-14 | Yerel veya ücretsiz katman sunucusu; URL yapılandırması | `config/network.example.json`, `NetworkClient`, `backend/worker.mjs` | Yerel `/ws` ve kök alias testleri, gerçek veriyle Worker dry-run geçti |
| FR-15 | Üretimde WSS; depoda sır olmaması | presetler, backend ve mobil rehber | Ücretli plan/hesap açılmadı; canlı WSS dağıtımı kullanıcı hesabını bekliyor |
| FR-16 | TR 29 harf (I/İ dahil), EN 26 harf, sanal/fiziksel klavye | `ui/keyboard.gd`, `GameSession` | Alfabe ve İngilizce fiziksel `i→I` testi geçti |
| FR-17 | İlk kelime açık; yalnızca sıradaki kelimenin ilk harfi açık | `core/game_session.gd` | Eksik/yanlış gönderim ilerlemez, önceki kelime silinmez; son doğrulamadan sonra ödül/konfeti |
| FR-18 | Sevimli sesler ve animasyonlar, ses/azaltılmış hareket ayarları | `AudioManager`, `GardenPaint`, ayarlar | Üretilmiş sesler, geçiş ve konfeti; gerçek cihaz ses/dokunma incelemesi bekliyor |

## İşlevsel olmayan gereksinimler

- **Çevrimdışı öncelik:** ana ekran/solo/parti sunucu bağlantısı açmaz. Ağ yalnızca çevrimiçi ekranda kullanılır.
- **Kayıt güvenliği:** geçici dosya, muhafazakâr yedek ve başarısız ödül/harcama geri alma; tek kişilik JSON şifrelenmez.
- **Sunucu otoritesi:** istemci puanı belirleyemez; yanlış/erken/eski sıradaki cevap puan üretmez. Paketlenmiş cevaplar okunabildiği için anti-cheat garantisi yoktur.
- **Gizlilik:** hesap/reklam/analitik/serbest sohbet yok. Takma ad cihazda hatırlanır; sunucuda oda ömrüyle sınırlıdır. Sağlayıcı IP/bağlantı kayıtları işleyebilir.
- **Lisans:** Godot MIT ve motorun üçüncü taraf telif bildirimleri `assets/legal/` içinde ve Ayarlar → Lisanslar ekranındadır.
- **Mobil güvenlik:** INTERNET izni; konum/kamera/mikrofon izni yok. Güvenlik duvarı otomatik değiştirilmez; üretimde geniş cleartext/ATS istisnası kullanılmaz.
- **Test izolasyonu:** testler gerçek oyuncu kaydına harcama/ödül yazmaz; ayrı kayıt ve arayüz tercihi yedeği kullanır.

## Kapsam dışında / yayın öncesi

Hesap sistemi, bulut kayıt, reklam/IAP, sıralamalı lig, güçlü anti-cheat, büyük ölçek yük testi ve sunucu yeniden başladıktan sonra maçı sürdürme bu sürümde yoktur.

Yayıncıya ait işlemler:

- [x] Ürün adı: **Kelime Bahçesi / Word Garden**; başlangıç içeriği 18+18; presetler paylaşılabilir, imzalama sırları ve çıktılar gitignore içinde.
- [ ] Gerçek Cloudflare hesabı ve canlı WSS adresi.
- [ ] Android araç zinciri, eşleşen export template ve gerçek cihaz testi.
- [ ] Benzersiz mağaza paket kimliği, release keystore ve imzalama.
- [ ] macOS/Xcode/Apple Team ID ve iOS cihaz testi.
- [ ] Mağaza hesapları/ücretleri, güncel hedef API politikası, mağaza görselleri.
- [ ] Gerçek yayıncı iletişim bilgileri ve herkese açık gizlilik URL'si; [PRIVACY.md](PRIVACY.md) taslağı doldurulmalı.

Ayrıntılı mimari: [ARCHITECTURE.md](ARCHITECTURE.md). Plan ve sınırlar: [PLAN.md](PLAN.md). Mobil rehber: [MOBILE_EXPORT.md](MOBILE_EXPORT.md).
