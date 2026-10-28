# 0.2.1 etkileşim düzeltmeleri

- Profil kaydı doğrudan ana menüye gider. Oyna doğrudan bölümü açar; öğretici menüden isteğe bağlı başlatılır.
- Webde HTML input görünmezdir; ad ve yer tutucu Godot tarafından tek katmanda çizilir. Girişin dokunma alanı çizim öncesinde güncellenir ve kaydırma alanına kırpılır; bağımsız kayan metin katmanı yoktur.
- Oyunda ayrı cevap alanı yoktur. Görünmez native giriş aktif harf kutularının üstüne yerleşir; kullanıcı kutulara dokunur. Verilen ilk harfi tekrar yazmadan kalan harflerle veya tam kelimeyle cevap verebilir. Doğru cevap tamamlanınca otomatik doğrulanır.
- Ekli kelime, aynı aktif kartın aynı harf satırında animasyonla köke dönüşür; dönüşüm tamamlanınca zincir ilerler. Web klavyesinin odağı cevaplar arasında korunur.
- Bütün kaydırma çubukları gizlidir; dokunarak veya tekerlekle kaydırma devam eder.
- Web oyun paketi sürümlü URL ile yüklenir; eski tarayıcı önbelleği yeni giriş köprüsüyle karışmaz.

Aşağıdaki 0.2 tasarımının bu maddelerle değiştirilmeyen kararları korunur.

# Kelime Zinciri — 0.2 tasarım ve davranış kararları

28 Ekim 2026. Mevcut Godot 4.5.2 projesi üzerine uygulanır. Eski OpenCode ajanları veya görev sahipliği kuralları kullanılmaz.

## Korunan sistemler

Godot/GDScript, Compatibility renderer, 480×900 portre referansı; içerik ve arayüz ayrımı; 18 TR + 18 EN zincirinin kimlikleri; dil bazlı kayıt, 100 başlangıç altını, 10 altın ipucu, 15 altın tek harf, 25 altın ilk tamamlama; rahat parti modu; backend kaynakları. Masaüstünde eski `Godot/app_userdata/Kelime Bahçesi` kayıt dizini kullanılır. Mobil uygulama kimlikleri korunur.

## Yeni ürün akışı

Markalı indirme ekranı → gerçek sahne yükleme introsu → ilk açılışta yerel oyuncu adı ve dil → uygulamalı öğretici → ana menü. Ad ve dil Ayarlar üzerinden değişir. Her dilin öğretici tamamlanması ayrı saklanır. Öğretici gerçek altını ve bölüm ilerlemesini değiştirmez. Menüde Oyna, Parti, Online (Yakında), kategoriler ve tekrar açılabilen öğretici bulunur. Online giriş hiçbir bağlantı açmaz; mevcut backend ileride kullanılmak üzere korunmuştur.

## Cevaplar

JSON içeriği kökleri ve doğru tamlamaları korur. `GardenApi.normalize_level()` tek kişilik Türkçe oturuma `inflected_answers` ekler. `GameSession.roots` sabit kökleri, `words` o oturumda istenen cevapları tutar. Cevap doğru tamlamanın ikinci kelimesidir: SU → BARDAĞI, ardından BARDAK → ALTLIĞI. Tam cevaplar verideki bağlantılardan alınır; rastgele ek çıkarma veya Türkçe dil bilgisi tahmini yapılmaz. `bardak` veya `altlık` bu adımlarda doğru cevap sayılmaz. Doğrulanan cevap kısa bir bekleme ve yumuşak sönüp belirme ile köke dönüşür. Hareket azaltma açıksa kök anında görünür. Dönüşüm sırasında çift gönderim engellenir.

Eski kök tabanlı `GameSession` sözleşmesi ham veriyle çalışan mevcut testler ve ileride yeniden ele alınacak backend için korunur. Kullanıcıya açık tek kişilik akış ekli cevapları kullanır.

## Görsel ve performans

Mor `#7541DC`, beyaz yüzeyler, koyu mor yazı, açık nötr zemin. Emoji, çiçek, maskot, parçacık, konfeti, sürekli arka plan animasyonu ve `_draw()` dekorasyonları kullanılmaz. Simge atlası `assets/ui/icons.svg`, marka `assets/ui/brand.svg`; proje için oluşturulmuş vektörlerdir. Godot bunları içe aktarırken bir kez rasterleştirir. Nunito Sans Regular/ExtraBold dosyaları yereldir; OFL lisansı pakete dahildir. Harf girişleri mevcut kartları ve harf kutularını günceller; bütün zinciri yeniden oluşturmaz. Ağ istemcisi bağlantı kullanılmıyorsa işlem döngüsü çalıştırmaz.

`DeviceLineEdit` mobil/masaüstünde işletim sistemi klavyesini kullanan LineEdit'tir. Webde gerçek HTML input, aynı alanın üzerine konumlanır ve tamamlanmış Unicode metnini `JavaScriptBridge` üzerinden iletir. Bu yöntem Godot 4.5 deneysel contenteditable girişinin Türkçe/IME hatalarını önler. HTML alanı bölüm geçişlerinde kaldırılır. Web indirme ilerlemesi gerçek WASM/PCK aktarımından, oyun introsu gerçek ResourceLoader sahne durumundan gelir.

## Zorluk

Bölümler `sequence` ve `difficulty` alanlarıyla elle sıralanır: 6 kolay, 6 orta, 6 zor. Oyna genel sırayı izler; kategori seçimi aynı sıranın kategori içindeki bölümlerini gösterir. Kimlikler değişmediği için eski tamamlamalar ve ödüller korunur. Tamamlanmış bölümler sırası değişse de yeniden oynanabilir.

## Yayın ve doğrulama

GitHub Pages aynı `kelime-bahcesi` adresinde kalır; ürün adı Kelime Zinciri'dir. Web özel HTML kabuğu ve tek iş parçacıklı Godot çıktısını kullanır. Godot motor WASM dosyası oyun paketinden ayrıdır; küçük oyun paketi tüm indirme boyutunun küçük olduğu anlamına gelmez. Gerçek Android/iOS klavyesi, çentik ve cihaz performansı ayrıca fiziksel cihazlarda doğrulanmalıdır.
