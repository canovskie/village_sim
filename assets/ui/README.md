# UI İkon Seti

Pixel-art HUD ikonları. `UiIcon('<ad>', fallback: '<emoji>')` her ikonu
`assets/ui/icon_<ad>.png` olarak yükler; **dosya yoksa emoji'ye düşer** → ikonlar
tek tek üretildikçe otomatik devreye girer, üretilmeyenler emoji kalır (kırılma yok).

## Üretim kuralları (stil)
- **Canvas:** 48×48 px, şeffaf arka plan (PNG). Görünüm boyutu 12–16px → silüet
  net, detay az, **1–2px koyu dış çizgi** (outline) şart.
- **Zemin:** ikonlar KOYU ahşap HUD üstünde durur → dolgular **açık/canlı**,
  koyu-üstüne-koyu olmasın. Sıcak cozy paleti (ahşap kahve, ember turuncu,
  parşömen krem, sage yeşil).
- **Tutarlılık:** tek ışık yönü (sol-üst), aynı outline kalınlığı, aynı doygunluk.
  Mevcut `assets/tools/*.png` (balta/kazma/çekiç) diliyle uyumlu.
- İsim kalıbı: `icon_<ad>.png` (aşağıdaki adlar birebir kullanılır).

## Gerekli ikonlar (bu turda bağlandı — 17)

### Kaynaklar (7)
| dosya | emoji | konu |
|---|---|---|
| icon_wood.png   | 🪵 | bir-iki kütük/odun parçası |
| icon_stone.png  | 🪨 | yığılmış taş bloklar |
| icon_iron.png   | ⚙  | demir külçe / dişli |
| icon_coal.png   | ♦  | parlak kömür parçaları |
| icon_food.png   | 🌾 | buğday demeti / ekmek |
| icon_honey.png  | 🍯 | bal kavanozu / petek |
| icon_gold.png   | ★  | altın sikke yığını |

### Nüfus & işçiler (5)
| dosya | emoji | konu |
|---|---|---|
| icon_pop.png        | 👥 | iki köylü silüeti |
| icon_farmer.png     | ⚘  | çiftçi (hasır şapka / orak) |
| icon_woodcutter.png | ⚒  | oduncu (balta) |
| icon_miner.png      | ⛏  | madenci (kazma / kask) |
| icon_fisher.png     | ⚓  | balıkçı (olta / balık) |

### Hava (5)
| dosya | emoji | konu |
|---|---|---|
| icon_sun.png   | ☀  | güneş |
| icon_dawn.png  | 🌅 | şafak / alçak güneş |
| icon_rain.png  | 🌧 | yağmur bulutu |
| icon_storm.png | ☔  | şiddetli yağmur/şimşek |
| icon_night.png | 🌙 | ay + yıldız |

## Faz 2 (henüz bağlanmadı — istenirse)
- HUD butonları: `icon_event.png` 🎲, `icon_god.png` ⚡, `icon_map.png` 🗺,
  `icon_dev.png` 🐞 (LeatherButton'ı widget-label alacak şekilde genişletmek gerek)
- Moral yüz seti: `icon_morale_0..4.png` (😣🙁😐🙂😄) — değere göre kademeli
- Rozetler: `icon_starving.png` 🍞, `icon_water.png` 💧
- Dilekçe mührü: `icon_petition.png` 📜

## Akış
GPT prompt → desktop → `assets/ui/icon_<ad>.png` → (gerekirse tools/sprite_process.py
ile temizlik) → oyunda otomatik görünür.
