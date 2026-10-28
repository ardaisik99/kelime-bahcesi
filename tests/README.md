# Güncel testler

Godot 4.5.2 standard sürümünü kullanın. Üretim kaydı test dosyalarıyla ayrıdır; UI tercihlerinin kopyası test sonunda geri yüklenir. UI testlerini aynı anda çalıştırmayın.

```powershell
.\tools\run_tests.ps1 -GodotPath "C:\Tools\Godot_v4.5.2-stable_win64_console.exe" -IncludeUI -Strict
```

Bu komut import, çekirdek, içerik, ekli cevaplar, güncel UI ve backend kontrollerini yürütür. Hata çıktısı ve kaynak sızıntıları çıkış kodundan bağımsız olarak denetlenir.

| Dosya | Kapsam |
|---|---|
| `test_core.gd` | Korunan çekirdek kuralları, ekonomi, kayıt kurtarma ve yazma hataları |
| `test_content.gd` | 18 TR + 18 EN zincirin veri bütünlüğü |
| `test_compounds.gd` | Her gerçek zincirde doğal tamlama cevabı, doğru maske, değişmez kökler, Unicode/native giriş doğrulaması, zorluk sırası |
| `test_ui.gd` | Profil, uygulamalı öğretici, kök animasyonu, gerçek LineEdit, iki dil, ekonomi, parti, ayarlar, 480/360/320 genişlik, kısa klavye ekranı |

Gerçek pencere ve ekran görüntüsü:

```powershell
& "C:\Tools\Godot_v4.5.2-stable_win64_console.exe" --path . --script tests/test_ui.gd -- --screenshots="C:/Temp/kelime-zinciri-shots"
```

`home`, `profile`, `tutorial`, `morph`, `tutorial_complete`, `play`, `party`, `category`, `victory`, `home_en`, `settings`, `home_320`, `home_360`, `play_320`, `play_360`, `keyboard_height` görüntüleri oluşur. Headless koşum PNG üretmez.

`test_network.gd` ve `test_online_ui.gd` önceki online akışın kaynaklarıdır. Online ürün girişi 0.2 sürümünde kapalı olduğundan varsayılan kabul testlerine dahil değildir. Yeniden etkinleştirirken ekli cevap ve native giriş sözleşmeleriyle birlikte güncellenmelidir. Backend `npm test` regresyonları korunur.

Sonuçlar ve fiziksel cihaz testi sınırları: [docs/TESTING.md](../docs/TESTING.md).
