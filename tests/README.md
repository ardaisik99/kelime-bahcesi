# Testler

Godot **4.5.2** kullanılır; ilk çalıştırmada proje içe aktarılmalıdır:

```powershell
$GODOT = "C:\Tools\Godot_v4.5.2-stable_win64_console.exe"
& $GODOT --headless --path . --import
& $GODOT --headless --path . --script tests/test_core.gd
& $GODOT --headless --path . --script tests/test_content.gd
& $GODOT --headless --path . --script tests/test_ui.gd
```

## Kapsam

| Dosya | Kapsam |
|---|---|
| `test_core.gd` | Çekirdek kurallar, Türkçe dönüşüm, kayıt, ekonomi, kurtarma ve yazma hatası |
| `test_content.gd` | İki dilde 36 zincirin şeması, alfabe, benzersizlik, kategori ve bağlantı yapısı |
| `test_ui.gd` | Gerçek ana sahne, **480×900** portre, kategoriler, açık cevaplı parti, dil/klavyeler, ipucu/harf, zafer, tekrar ödülü, lisanslar |
| `test_network.gd` | İki bağımsız `WebSocketPeer`: oda, geri sayım, cevap, canlı skor, mesaj, ayrılma |
| `test_online_ui.gd` | Gerçek online ekran + üretim `NetworkClient` + ayrı gerçek rakip soketi; TR oda açma ve EN odaya katılma, üç zincir bitirme, sonuç ve temiz çıkış |

Eksik sahne/bağımlılık veya başarısız senaryo **exit 1** üretir; sessizce başarı sayılmaz. Godot bazen script hatasında 0 döndürdüğü için `tools/run_tests.ps1` hata çıktısını da denetler.

## Ağ testleri

Önce ayrı terminalde sunucuyu başlatın (varsayılan 8787):

```powershell
cd backend
npm ci
npm start
```

Sunucu iki gerçek kaynak dosyasını (`data/levels_tr.json` / `levels_en.json`) yükler. Ayrı birleşik dosya hazırlamayın. Sağlık kontrolü: `http://127.0.0.1:8787/health`.

```powershell
& $GODOT --headless --path . --script tests/test_network.gd -- --url=ws://127.0.0.1:8787/ws
& $GODOT --headless --path . --script tests/test_online_ui.gd -- --url=ws://127.0.0.1:8787/ws
```

Her bekleme sınırlıdır. UI testi 120 sn, bağımsız ağ testi 55 sn bütçe kullanır. Tüm maçlar doğru cevaplarla bitirildiği için online UI testi 90 sn dolmasını beklemez.

## Kayıt izolasyonu

Çekirdek/UI testleri `SaveStore.set_storage_path()` ile benzersiz `user://test_*` dosyasına geçer. UI testleri iki dilin test ilerlemesini sıfırlar; gerçek `save.json` korunur. `user://garden_ui.json` yedeklenip geri yüklenir. UI testlerini aynı anda çalıştırmayın: bu tercih yedeği paylaşılan bir dosyadır.

## Ekran görüntüleri

Gerçek pencere/grafik ortamı gerekir; headless görüntü üretmez:

```powershell
& $GODOT --path . --script tests/test_ui.gd -- --screenshots="C:\Temp\garden-shots"
& $GODOT --path . --script tests/test_online_ui.gd -- --url=ws://127.0.0.1:8787/ws --screenshots="C:\Temp\garden-shots"
```

`home`, `play`, `party`, `en`, `play_win` ve TR/EN online geri sayım/maç/sonuç PNG'leri üretilir. Pencere dışındaki masaüstü yakalanmaz; yalnızca Godot viewport'u kaydedilir.

## Tek komutlu koşum

Sunucu ayrı terminalde açıkken:

```powershell
.\tools\run_tests.ps1 -GodotPath $GODOT -IncludeUI -IncludeNetwork -NetworkUrl "ws://127.0.0.1:8787/ws" -Strict
```

Gerçek sonuçlar ve test edilmemiş mobil/yayın adımları: [docs/TESTING.md](../docs/TESTING.md).
