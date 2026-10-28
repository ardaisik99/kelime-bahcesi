# Kelime Zinciri

Türkçe ve İngilizce, mobil öncelikli bir kelime zinciri oyunu. Mevcut Godot **4.5.2** projesinin **0.2** sürümü: mor/beyaz arayüz, yerel profil, uygulamalı öğretici ve doğal tamlama cevapları.

**[Webde oyna](https://ardaisik99.github.io/kelime-bahcesi/)**

## Nasıl oynanır?

İlk kelime verilir. Önceki kelimeyle anlamlı bir tamlama kuran cevabı telefonunun klavyesiyle tam yazıp Gönder'e dokunursun. Örneğin **SU → BARDAĞI**. Doğru cevap yumuşak bir animasyonla **BARDAK** olur; sonraki cevap **ALTLIĞI**, sonraki kök **ALTLIK** olur. Yanlış veya eksik cevap ilerletmez. Son kelime doğrulanınca bölüm tamamlanır.

İlk açılışta oyuncu adı ve dil seçilir. Öğreticide gerçek bir zinciri tamamlayarak oyun öğrenilir. Ayarlar'da ad, dil, ses ve hareket tercihi değiştirilebilir. Öğretici menüden yeniden açılabilir; gerçek altın ve ilerlemeyi etkilemez.

- Her dilde 18 bölüm; toplam 36, üç kategori. Genel yolculuk ve kategoriler kolaydan zora sıralanır.
- Dil başına 100 başlangıç altını; ipucu 10, bir rastgele harf 15, ilk bölüm tamamlama ödülü 25. Tekrarda ödül yoktur.
- Parti modu yüz yüze birlikte düşünmek içindir. Zincirler ve tamlamalar açık görünür; dokunarak yeni zincire geçilir.
- **Online şu anda Yakında ekranıdır. Ağ bağlantısı yapılmaz.** Önceki backend ve protokol kaynakları korunmuştur.
- Profil, tercihler ve ilerleme cihazda saklanır. Hesap, reklam veya gerçek para yoktur.
- Oyun içi sanal klavye, emoji, çiçek, maskot ve konfeti kullanılmaz. Statik SVG atlası ve iki küçük yerel font kullanılır.

## Çalıştırma

Godot 4.5.2 standard sürümünde kökteki `project.godot` dosyasını açıp F5'e basın. Ana sahne `scenes/boot.tscn` oyun yüklenirken markalı introyu gösterir. Webde WASM/veri indirmesi `web/shell.html` üzerinden gerçek ilerleme çubuğuyla gösterilir; Godot açılış logosu kapalıdır.

```powershell
& "C:\Tools\Godot_v4.5.2-stable_win64_console.exe" --path .
.\tools\run_tests.ps1 -GodotPath "C:\Tools\Godot_v4.5.2-stable_win64_console.exe" -IncludeUI -Strict
```

Varsayılan testler çekirdek, içerik, ekli cevaplar ve backend'i kapsar. `-IncludeUI` profil, öğretici, gerçek metin alanı, iki dil, ekonomi, azaltılmış hareket ve dar ekranları ekler. Testler üretim kaydını değiştirmez.

## Web yayını

`main` dalına gönderilen kaynaklar `.github/workflows/web.yml` ile doğrulanır, export edilir ve GitHub Pages'e dağıtılır. Yerel export için Godot 4.5.2 web şablonları gerekir:

```powershell
& "C:\Tools\Godot_v4.5.2-stable_win64_console.exe" --headless --path . --export-release Web builds/web/index.html
python -m http.server 8765 --bind 127.0.0.1 --directory builds/web
```

Web girişinde gerçek HTML input ile telefon klavyesi/IME kullanılır; masaüstü/mobil uygulamada native LineEdit kullanılır. Gerçek telefon testleri masaüstü ve tarayıcı testlerinden ayrıdır.

## Kaynaklar

- [Yeni tasarım ve davranış kararları](docs/REDESIGN.md)
- [Mimari ve kayıt sözleşmeleri](docs/ARCHITECTURE.md)
- [Test sonuçları ve sınırlar](docs/TESTING.md), [test komutları](tests/README.md)
- [İçerik incelemesi](docs/CONTENT_REVIEW.md)
- [Mobil export](docs/MOBILE_EXPORT.md), [gizlilik](docs/PRIVACY.md)
- [Korunan, şu anda ürün arayüzüne bağlı olmayan backend](backend/README.md)

Kod ve proje için oluşturulan SVG varlıkları MIT lisanslıdır. Nunito Sans fontları SIL OFL 1.1 lisansıyla, Godot motor bildirimleri `assets/legal/` altında dağıtılır. Lisanslar Ayarlar içinden okunabilir.
