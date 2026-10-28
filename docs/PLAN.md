# Kelime Bahçesi — Geliştirme planı ve teslim durumu

Godot 4.5.2 · Android/iOS hedefli · TR/EN · Son inceleme: 2026-10-28

## 1. Gereksinim değerlendirmesi

- Türkçe içerik kök kelimelerle yazılır; gösterilen bağlantılar eklerini alır: `ÇAY → KAŞIK → OYUN → HAVA`, “çay kaşığı / kaşık oyunu / oyun havası”.
- İngilizce içerik ayrı bir veri kümesidir; doğal bileşikler ve kelime çiftleri kullanılır. Dil değişimi, bulmacayı sözcüğü sözcüğüne çevirmek değildir.
- Her zincir 4–5 kelimedir. İlk kelime açık, sıradaki kelimenin ilk harfi sabittir. Doğru kelime gönderilmeden sonraki kart açılmaz.
- Altın gerçek para değildir. Her dilde 100 başlangıç altını; ipucu 10, tek rastgele harf 15, ilk bölüm tamamlama 25 altın. Tekrarda ödül yoktur.
- Parti modu yüz yüze sohbet içindir: cevaplar ve tamlamalar açık, dokunarak rastgele yeni zincir. Yarışma veya tahmin klavyesi yoktur.
- 1'e 1 yarışma farklıdır: oda kodu, aynı üç zincir, 3 saniye geri sayım, 90 saniye maç, doğru kelime başına 100 puan. Puanı sunucu belirler.

## 2. Mimari kararlar

1. **Godot/GDScript, Compatibility renderer:** mobilde hafif 2B arayüz; 480×900 referans portre düzen.
2. **Katmanlar:** `core/` oyun mantığı, `ui/` sunum, `data/` içerik, `backend/` bağımsız sunucu. Ana sahne `scenes/main.tscn`; ekranlar kodla oluşturulur.
3. **Autoload sırası:** SaveStore → I18n → Content → AudioManager → NetworkClient.
4. **Tek kural kaynağı:** tek kişilik oynanış `GameSession` kullanır. Arayüz ayrıca altın/ödül üretmez.
5. **Yerel kayıt:** `user://save.json`, geçici dosya ve muhafazakâr yedek dönüşümü; başarısız harcama/tamamlama bellekte de geri alınır.
6. **Dil bazlı yolculuk:** TR/EN altınları ve tamamlanan bölümleri bağımsızdır. Menüden devam, son oynanan veya sonraki tamamlanmamış bölümü seçer.
7. **Doğru Türkçe harfler:** `i→İ`, `ı→I`; İngilizcede `i→I`. Sanal klavyeler 29 ve 26 harflidir.
8. **Ücretsiz varlıklar:** vektör/prosedürel çizimler, çalışma anında üretilen sesler; harici görsel/ses paketi veya ücretli API yoktur.
9. **İsteğe bağlı ağ:** çevrimdışı modlar sunucu istemez. Yerel Node sunucusu veya Cloudflare Workers Free + SQLite Durable Object aynı protokolü kullanır.
10. **Güven sınırı:** sunucu cevapları/sırayı/puanı doğrular. İçerik istemcide de bulunduğundan sıralamalı, hileye dayanıklı bir e-spor altyapısı değildir.
11. **Sade sosyal alan:** serbest sohbet yerine iki dile çevrilen dört hazır mesaj; hesap ve kalıcı çevrimiçi profil yoktur.
12. **Saat senkronizasyonu:** geri sayım/maç saati sunucu zamanına ve monoton istemci saatine dayanır; telefon saati farklı olsa da aynı başlangıç hedeflenir.
13. **Yayın güvenliği:** anahtarlar/şifreler depoda yoktur. Üretimde WSS; ücretsiz kota aşılırsa hizmet durabilir, sınırsız ücretsiz vaat edilmez.

Ayrıntılı veri şeması ve API: [ARCHITECTURE.md](ARCHITECTURE.md).

## 3. Tamamlanan aşamalar

| Aşama | Durum / kanıt |
|---|---|
| Godot proje ayarları, sahne, klasörler | Oluşturuldu; başsız ve gerçek pencere açılışı kontrol edildi |
| İçerik ve yerelleştirme | 18 TR + 18 EN, üç kategoride altışar zincir; 1.255 içerik kontrolü |
| Oyun çekirdeği ve kayıt | 689 kontrol: kelime kelime ilerleme, jokerler, tek ödül, kayıt kurtarma ve hata geri alma |
| Mobil arayüz | Pastel kartlar/mascot, kategori, klavyeler, parti, ayarlar, lisanslar, konfeti; gerçek 480×900 testi |
| Yerel yarışma sunucusu | 39 test; gerçek WebSocket oda ve cevap testleri dahil |
| Oyunun çevrimiçi ekranı | TR oda açma / EN odaya katılma, üç zinciri bitirme, skor, mesaj, sonuç ve bağlantı temizliği doğrulandı |
| Cloudflare paketleme | Gerçek split JSON içeriğiyle dry-run geçti; canlı dağıtım yapılmadı |
| Dışa aktarma hazırlığı | Sırsız Android/iOS presetleri, lisans dosyaları ve mobil kurulum rehberi |

Son komutlar ve kanıtlar: [TESTING.md](TESTING.md).

## 4. Kullanıcı gerektiren yayın adımları

- **İnternetten yarışma:** sana ait Cloudflare Free hesabında `npx wrangler login` ve `npm run deploy`; verilen `wss://…/ws` adresini `config/network.json` içine koyma. Hesabına giriş senin işlemin; ücretli plan açılmadı.
- **Android:** eşleşen Godot export template, JDK 17 ve Android SDK kurulumu; gerçek cihaz testi. Yayın için benzersiz paket adı ve sana ait release keystore.
- **iOS:** macOS, Xcode, Team ID ve imzalama; gerçek iPhone/iPad testi. Windows'ta tamamlanamaz.
- **Mağazalar:** geliştirici hesapları/ücretleri, mağaza görselleri, güncel hedef API ve gizlilik formları. `PRIVACY.md` içindeki gerçek yayıncı iletişim bilgileri doldurulmalı.

## 5. Bilinen sınırlar

- İmzalı APK/IPA, Android/iOS cihaz testi ve canlı Cloudflare dağıtımı henüz yoktur; kaynak projenin çalışması mağazaya hazır olduğu anlamına gelmez.
- Devam edilen **bölüm** saklanır; yarım kelime, açılmış ipucu ve jokerler oturumluk olduğundan bölümden çıkınca yeniden başlar.
- Kayıt cihazdadır; cihazlar arası senkronizasyon yoktur. Yerel dosya düzenlenerek altın değiştirilebilir; çevrimiçi puan buna bağlı değildir.
- Odalar sunucu belleğindedir; yeniden başlatma/kopma maçın bitmesine yol açar. Otomatik maç devam ettirme yoktur.
- Tek Durable Object hub küçük/gündelik kullanım içindir. Büyük trafik için yük testi ve ölçekleme ayrı bir aşamadır.

## 6. İçerik genişletme

`data/levels_<dil>.json` içine benzersiz kimlikli, 4–5 kelimeli bir zincir ekle. Her kelimeye ipucu, her komşu çifte doğru tamlama yaz. İki dil aynı anda güncellenmek zorunda değildir. `test_content.gd` ve backend testlerini çalıştır; içerik güncellenince istemci ve sunucuyu birlikte yayımla. Mevcut dil/kategori sayısı kontrollerini yeni ürün kapsamına göre güncelle.
