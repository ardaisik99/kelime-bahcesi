# 0.2 yerel profil güncellemesi

Oyuncu adı, seçilen dil, öğretici durumu ve erişilebilirlik tercihleri yalnızca cihazdaki `garden_ui.json` dosyasında saklanır. Bölüm ilerlemesi ve altın `save.json` dosyasındadır. Ad ve dil Ayarlar üzerinden düzenlenebilir. Şu anda Online girişi bağlantı açmaz; oyuncu adı herhangi bir sunucuya gönderilmez. Aşağıdaki önceki online veri açıklamaları gelecekte yeniden etkinleştirilecek backend için referanstır.

# Gizlilik Politikası / Privacy Policy — Kelime Bahçesi / Word Garden

**Belge durumu:** Taslak — mağaza başvurusundan önce yayıncı tarafından doldurulması zorunlu alanlar vardır (bkz. bölüm 8).
**Son güncelleme:** 2026-10-28
**Ürün:** Kelime Bahçesi / Word Garden (Godot 4.5.2, Android/iOS hedefi)
**Kapsam:** Bu politika, oyunun kendisi ve isteğe bağlı çevrimiçi oda özelliği için geçerlidir.

> Bu belge hukuki danışmanlık değildir. Yayıncı; kendi ülkesindeki tüketici, veri koruma ve mağaza politikalarına uygunluğu mağaza başvurusundan önce doğrulamalıdır.

## 1. Özet

- Oyun **hesap oluşturmaz**, e-posta/telefon istemez, bulut kayıt kullanmaz.
- **Reklam, uygulama içi satın alma, analitik veya üçüncü taraf izleme SDK'sı yoktur.**
- Altın ve ilerleme **cihazda** saklanır.
- Çevrimiçi oda **isteğe bağlıdır**. Açıldığında takma ad, oda kodu, cevaplar, skor ve hazır tepkiler WebSocket üzerinden sunucuya gönderilir; rakipler yalnızca takma adları, skorları ve hazır tepkileri görür.
- Takma ad ve oda durumu **sunucu belleğinde geçicidir**; sunucu yeniden başlarsa kaybolur. Kalıcı hesap/profil oluşturulmaz.
- Sunucu sağlayıcısı veya işletmecisi; **IP adresi ve erişim/bağlantı kayıtlarını** kendi yapılandırmasına göre işleyebilir. Bu belge "hiç kişisel veri işlenmez" iddiasında bulunmaz.

## 2. Cihazda saklanan veriler

Oyun, ilerlemeyi uygulamanın kendi özel depolama alanında (`user://`; kayıt ve yedek dosyaları) tutar:

- altın bakiyesi,
- tamamlanan bölümler ve ilk tamamlama durumu,
- dil bazlı ilerleme ve yerel ayarlar.
- son girilen takma ad ve arayüz tercihleri (`user://garden_ui.json`); takma ad yalnızca çevrimiçi modda sunucuya gönderilir.

Bu veriler oyun sunucusuna gönderilmez ve hesaba bağlanmaz. Uygulama kaldırıldığında veya işletim sistemi üzerinden uygulama verileri temizlendiğinde yerel kayıt silinir. Cihaz/işletim sistemi yedekleme ayarlarına bağlı olarak işletim sistemi uygulama verisini buluta yedekleyebilir; bu işlem oyunun kontrolünde değildir.

## 3. İsteğe bağlı çevrimiçi oyun

Çevrimiçi oda yalnızca kullanıcı açtığında çalışır. Bağlantı sırasında istemciden sunucuya şunlar gönderilir:

- seçilen takma ad (yalnızca oda içinde görünür; hesap değildir),
- oda kodu ve oda katılım bilgileri,
- verilen cevaplar ve skor,
- seçilen hazır (canned) tepkiler.

Cevaplar istemciden sunucuya gönderilir; sunucu bunları rakip oyunculara birebir cevap olarak iletmez. Oda katılımcıları takma adları, skorları ve seçilen hazır tepkileri görür. **Serbest metin sohbeti, medya/dosya yükleme, sesli/görüntülü iletişim veya herkese açık gönderi paylaşımı yoktur.** Paylaşılabilen kullanıcı girdisi yalnızca takma ad ve önceden tanımlı tepkilerle sınırlıdır. Takma adlar benzersiz değildir; aynı adı kullanan oyuncular ayrı oturum kimlikleriyle ayırt edilir. Takma ad ve oda durumu sunucu belleğinde tutulur; sunucu yeniden başladığında kaybolur ve kalıcı hesap verisi olarak saklanmaz.

Çevrimiçi altyapı, geliştiricinin kendi barındırdığı Node.js WebSocket sunucusu veya Cloudflare Workers + Durable Objects olabilir. Cloudflare hesabı ve dağıtımı geliştiriciye aittir; bu depo tarafından sağlanmaz. Hangi sağlayıcının kullanıldığı ve yapılandırması yayın öncesi bu belgeye işlenmelidir (bölüm 8).

## 4. Ağ ve barındırma kayıtları

Çevrimiçi özellik kullanıldığında, bağlantıyı sağlayan taraf (kendi sunucu işletmecisi veya Cloudflare gibi sağlayıcı) aşağıdaki verileri kendi gizlilik politikası ve yapılandırması kapsamında işleyebilir:

- IP adresi ve bağlantı zamanı,
- istek/erişim ve hata kayıtları,
- aktarım hacmi ve teknik bağlantı meta verileri.

Bu kayıtlar oyun tarafından reklam veya profilleme amacıyla kullanılmaz. Saklama süresi ve hukuki dayanak sağlayıcının/sunucu işletmecisinin yapılandırmasına bağlıdır ve yayın öncesi doğrulanmalıdır. Üretimde `wss://` (şifreli WebSocket) kullanılması hedeflenir; yerel geliştirmede `ws://` kullanılabilir.

## 5. Toplanmayan veriler

Oyun; ad-soyad, e-posta, telefon numarası, adres, konum, kişiler, fotoğraf, kamera/mikrofon erişimi, ödeme bilgisi veya hassas veri **istemez**. Hesap, abonelik, reklam kimliği, analitik/çökme raporlama SDK'sı ve üçüncü taraf izleme yoktur. Veriler satılmaz.

Mağaza platformu (Google Play / App Store) kendi politikası kapsamında kurulum veya tanılama kayıtlarını işleyebilir; bu, oyunun kendi veri işlemesinden ayrıdır.

## 6. Saklama ve silme

- **Yerel veriler:** cihazda, kullanıcı silene veya uygulamayı kaldırana kadar.
- **Çevrimiçi oda verileri:** sunucu belleğinde, oturum/oda sona erene veya sunucu yeniden başlayana kadar; kalıcı hesap kaydı oluşturulmaz.
- **Sağlayıcı kayıtları:** sağlayıcının saklama politikasına tabidir.

Yerel ilerlemeyi silmek için işletim sisteminin uygulama verilerini temizleme veya uygulamayı kaldırma adımları kullanılabilir. Sunucu tarafındaki kayıtlar için yayıncı ile iletişime geçin.

## 7. Üçüncü taraf bileşenler ve lisanslar

Oyun motoru **Godot Engine 4.5.2** MIT lisansıyla kullanılır. Godot, üçüncü taraf kütüphaneler içerir; telif ve lisans bildirimleri için:

- `assets/legal/GODOT_LICENSE.txt` — Godot Engine MIT lisansı
- `assets/legal/GODOT_COPYRIGHT.txt` — Godot kaynak ağacındaki dosya bazlı telif/lisans bildirimleri (üçüncü taraf bileşenler dahil)

Bu dosyalar, Godot 4.5.2 resmi kaynağından (`godotengine/godot`, `4.5.2-stable`) alınmıştır. Bildirimler proje içindeki `assets/legal/GODOT_LICENSE.txt` ve `assets/legal/GODOT_COPYRIGHT.txt` dosyalarındadır; oyun paketinde yer almalı ve uygulama içi lisans ekranı eklendiğinde bu bildirimler erişilebilir olmalıdır. Oyun paketinde, oyunun kendi kod/varlıkları ve Godot Engine dışında üçüncü taraf bir varlık veya bağımlılık yoktur. Çevrimiçi sunucu tarafı Node.js veya Cloudflare platformu üzerinde çalışır; bunlar oyun paketine dahil edilmez ve kendi lisans/koşullarına tabidir.

## 8. Yayın öncesi doldurulması zorunlu alanlar

Aşağıdaki alanlar **bilerek boş bırakılmıştır**; uydurulmamıştır. Mağaza başvurusundan önce yayıncı tarafından gerçek bilgilerle doldurulmalı, aksi halde bu belge mağazaya gönderilmemelidir.

| Alan | Durum |
| --- | --- |
| Yayıncı/geliştirici yasal adı | **GELİŞTİRİCİ TARAFINDAN DOLDURULACAK** |
| Yayıncı posta adresi (mağaza/mevzuat gerektiriyorsa) | **GELİŞTİRİCİ TARAFINDAN DOLDURULACAK** |
| Veri sorumlusu (data controller) | **GELİŞTİRİCİ TARAFINDAN DOLDURULACAK** (yayıncı) |
| AB/BK temsilcisi (gerekiyorsa) | **GELİŞTİRİCİ TARAFINDAN DOLDURULACAK** |
| Gizlilik iletişim e-postası | **GELİŞTİRİCİ TARAFINDAN DOLDURULACAK** |
| Genel destek iletişimi | **GELİŞTİRİCİ TARAFINDAN DOLDURULACAK** |
| Herkese açık gizlilik politikası URL'si | **GELİŞTİRİCİ TARAFINDAN DOLDURULACAK** |
| Çevrimiçi barındırma sağlayıcısı ve bölgesi | **GELİŞTİRİCİ TARAFINDAN DOLDURULACAK** (yerel Node.js / Cloudflare Workers + Durable Objects) |
| Kullanılan çevrimiçi uç nokta (endpoint) ve dağıtım sahibi | **GELİŞTİRİCİ TARAFINDAN DOLDURULACAK** |
| Sağlayıcı gizlilik politikası bağlantısı | **GELİŞTİRİCİ TARAFINDAN DOLDURULACAK** |
| Sağlayıcı log saklama süresi ve kapatma ayarı | **GELİŞTİRİCİ TARAFINDAN DOLDURULACAK** |
| Yürürlük tarihi ve sürüm numarası | **GELİŞTİRİCİ TARAFINDAN DOLDURULACAK** |

## 9. Değişiklikler

Bu politika, veri uygulamaları veya çevrimiçi altyapı değiştiğinde güncellenir. Önemli değişiklikler mağaza sayfasında ve/veya uygulama içinde duyurulmalıdır. Yürürlük tarihi yayın öncesi doldurulacaktır.

---

# Privacy Policy — Word Garden / Kelime Bahçesi (English)

**Status:** Draft — publisher must fill in the mandatory fields in section 8 before store submission.
**Last updated:** 2026-10-28
**Product:** Word Garden / Kelime Bahçesi (Godot 4.5.2, targeting Android/iOS)

> This document is not legal advice. The publisher must verify compliance with applicable consumer, data-protection, and store policies before submission.

## 1. Summary

- The game **does not create accounts**, request email/phone numbers, or use cloud saves.
- There are **no ads, in-app purchases, analytics, or third-party tracking SDKs**.
- Coins and progress are stored **on the device**.
- Online play is **optional**. When used, the chosen nickname, room code, answers, score, and canned emotes are sent to the server over WebSocket; opponents see only nicknames, scores, and canned emotes.
- Nicknames and room state are **ephemeral in server memory** and are lost when the server restarts. No persistent account or profile is created.
- The hosting provider or server operator **may process IP addresses and access/connection logs** under its own configuration and policy. This policy does **not** claim that no personal data is processed.

## 2. Data stored on the device

Progress is kept in the app's private storage (`user://`; save and backup files):

- coin balance,
- completed levels and first-completion status,
- per-language progress and local settings.
- the last entered nickname and UI preferences (`user://garden_ui.json`); the nickname is sent to the server only in online mode.

This data is not sent to the game server and is not linked to an account. Uninstalling the app or clearing app data in the operating system deletes the local save. Depending on device/OS backup settings, the operating system may back up app data to the cloud; this is outside the game's control.

## 3. Optional online play

Online rooms run only when the user opens them. The client sends the following to the server:

- the chosen nickname (visible only within the room; not an account),
- room code and join information,
- submitted answers and score,
- selected canned emotes.

Answers are sent from the client to the server; the server does not forward individual answer payloads to opponents. Room participants see nicknames, scores, and selected canned emotes. There is **no free-text chat, media/file upload, voice/video communication, or public posting**; user-provided content is limited to the nickname and preset emotes. Nicknames are not unique; players with the same name are distinguished by separate session IDs. Nicknames and room state are held in server memory, disappear when the server restarts, and are not stored as persistent account data.

Online infrastructure may be a self-hosted Node.js WebSocket server or Cloudflare Workers + Durable Objects. The Cloudflare account and deployment belong to the developer and are not provisioned by this repository. The provider used and its configuration must be recorded here before release (section 8).

## 4. Network and hosting logs

When online features are used, the party providing the connection (the self-hosted server operator or a provider such as Cloudflare) may process the following under its own privacy policy and configuration:

- IP address and connection time,
- request/access and error logs,
- transfer volume and technical connection metadata.

The game does not use these logs for advertising or profiling. Retention periods and legal bases depend on the provider/operator configuration and must be verified before release. Production is intended to use `wss://` (encrypted WebSocket); `ws://` may be used for local development.

## 5. Data not collected

The game does **not** request name, email, phone number, address, location, contacts, photos, camera/microphone access, payment details, or sensitive data. There are no accounts, subscriptions, advertising IDs, analytics/crash-reporting SDKs, or third-party tracking. Data is not sold.

The store platform (Google Play / App Store) may process install or diagnostic records under its own policies; that is separate from the game's own processing.

## 6. Retention and deletion

- **Local data:** on the device until the user deletes it or uninstalls the app.
- **Online room data:** in server memory until the session/room ends or the server restarts; no persistent account record is created.
- **Provider logs:** subject to the provider's retention policy.

To delete local progress, clear the app's data through the operating system or uninstall the app. For server-side records, contact the publisher.

## 7. Third-party components and licenses

The game uses **Godot Engine 4.5.2** under the MIT license. Godot includes third-party libraries; see:

- `assets/legal/GODOT_LICENSE.txt` — Godot Engine MIT license
- `assets/legal/GODOT_COPYRIGHT.txt` — per-file copyright/license notices from the Godot source tree, including third-party components

These files were taken from the official Godot 4.5.2 source (`godotengine/godot`, `4.5.2-stable`). The notices are located in the project's `assets/legal/GODOT_LICENSE.txt` and `assets/legal/GODOT_COPYRIGHT.txt`; they must be included in the game package and accessible from an in-app licenses screen when implemented. Beyond the game's own code/assets and Godot Engine, the game package contains no third-party assets or dependencies. The online server side runs on Node.js or the Cloudflare platform; these are not bundled in the game package and are subject to their own licenses/terms.

## 8. Mandatory fields before release

The following are **intentionally blank** and were not invented. The publisher must fill them with real information before store submission; otherwise this document must not be submitted to a store.

| Field | Status |
| --- | --- |
| Publisher/developer legal name | **TO BE SUPPLIED BY DEVELOPER** |
| Publisher postal address (if required by store/law) | **TO BE SUPPLIED BY DEVELOPER** |
| Data controller | **TO BE SUPPLIED BY DEVELOPER** (the publisher) |
| EU/UK representative (if required) | **TO BE SUPPLIED BY DEVELOPER** |
| Privacy contact email | **TO BE SUPPLIED BY DEVELOPER** |
| General support contact | **TO BE SUPPLIED BY DEVELOPER** |
| Public privacy policy URL | **TO BE SUPPLIED BY DEVELOPER** |
| Online hosting provider and region | **TO BE SUPPLIED BY DEVELOPER** (self-hosted Node.js / Cloudflare Workers + Durable Objects) |
| Online endpoint used and deployment owner | **TO BE SUPPLIED BY DEVELOPER** |
| Provider privacy policy link | **TO BE SUPPLIED BY DEVELOPER** |
| Provider log retention and opt-out configuration | **TO BE SUPPLIED BY DEVELOPER** |
| Effective date and version number | **TO BE SUPPLIED BY DEVELOPER** |

## 9. Changes

This policy is updated when data practices or online infrastructure change. Material changes should be announced on the store listing and/or in the app. The effective date will be filled in before release.
