# Village Sim — Geliştirici Kılavuzu

Flutter ile yazılmış izometrik köy simülasyonu. Bu döküman, projeye yeni başlayan bir AI veya geliştirici için tüm teknik püf noktalarını içerir.

---

## Proje Yapısı

```
lib/
  main.dart                        — Ana state (_VillageSceneState), oyun döngüsü, input
  bale_test.dart                   — Hay → bale dönüşümü için test sahnesi
  core/
    constants.dart                 — kTileW=64, kTileH=32, kCols=96, kRows=64
                                     gridToScreen, screenToGrid
    resources.dart                 — ResourceKind, ResourceBundle, ResourceCost
  rendering/
    game_painter.dart              — VillageGamePainter (CustomPainter, derinlik sıralaması)
    tile_renderer.dart             — Çim tile renderer
    water_renderer.dart            — Animasyonlu su (LUT sin, LOD, sparkle, balık, yağmur halkası)
    tree_renderer.dart             — Ağaç çizimi (sallantı dahil)
    character_renderer.dart        — Köylü, inşaatçı, oduncu, madenci, balıkçı, çiftçi sprite'ları
    mine_renderer.dart             — Maden düğümü çizimi
    nature_renderer.dart           — Lotus, saz çizimi
    resource_renderer.dart         — Kaynak kutuları (odun/taş/demir/kömür) çizimi
    tool_renderer.dart             — Gece torch glow + el aletleri
    axe_renderer.dart              — Balta sprite (oduncu için)
  buildings/
    building_type.dart             — BuildingType enum (12 tip), BuildingMeta, kBuildingLights
    building_renderer.dart         — Bina sprite çizimi + inşaat animasyonu + gece ışıkları
    building_entity.dart           — Bina veri sınıfı
  entities/
    worker_entity.dart             — Soyut WorkerEntity (moveTo, pickWanderTarget)
    villager_entity.dart           — Köylü AI
    builder_entity.dart            — İnşaatçı AI
    woodcutter_entity.dart         — Oduncu AI (genel — manuel işaretli ağaç)
    lumber_camp_entity.dart        — Oduncu kulübesi AI (bölge yönetimi + fidan dikme)
    miner_entity.dart              — Madenci AI
    fisher_entity.dart             — Balıkçı AI
    farm_farmer.dart               — Çiftçi AI
    build_order.dart               — İnşaat siparişi
  world/
    world_generator.dart           — Harita üretimi (göller, ormanlar, doğa)
    day_night_cycle.dart           — DayNightCycle: gökyüzü, güneş/ay, yağmur döngüsü
    tree_entity.dart               — Ağaç veri sınıfı
    mine_node.dart                 — Maden düğümü veri sınıfı
    nature_entity.dart             — Lotus, saz veri sınıfları
    resource_box.dart              — Yere düşen kaynak kutusu (carry hedefi)
    hay_entity.dart                — Saman yığını / balya (pile → bale)
  farm/
    farm_tile.dart                 — Tarla tile (stage 0-4)
    farm_renderer.dart             — Tarla çizimi (cross-fade)
  characters/
    villager_type.dart             — VillagerType enum (farmer/merchant/blacksmith/guard/mage/miner/fisher)
    villager_painter.dart          — Karakter sprite render (yürüme, yön)
    villager_card.dart             — Karakter detay kartı UI
  ui/
    hud.dart                       — GameHUD, PixelChip
    building_panel.dart            — Bina seçim paneli
    building_info_panel.dart       — Seçili bina detay paneli
    sky_widgets.dart               — PixelSky, PixelSun, PixelMoon, PixelCloud, StarField
    main_menu_screen.dart          — Açılış menüsü (Yeni Oyun / Ayarlar / Hakkında)
    settings_screen.dart           — Ses, görüntü, kontrol ayarları
    settings_model.dart            — SettingsModel singleton
    about_screen.dart              — Krediler, sürüm, kontrol rehberi
    game_theme.dart                — MedievalTheme: renkler, button/panel decoration factory
  tools/
    light_editor_main.dart         — Bina ışık noktası editörü (aşağıya bak)
assets/
  buildings/                       — Bina PNG'leri (RGBA, trimlenmiş)
  tiles/                           — grass.png, farm_0..4.png
  trees/                           — birch.png, oak.png, pine.png (RGBA, trimlenmiş)
  nature/                          — lotus, saz PNG'leri
  tools/                           — Balta vb. el aleti sprite'ları
tools/
  trim_asset.py                    — Asset arka plan temizleme scripti
```

---

## Geliştirici Araçları

### Bina Işık Noktası Editörü

Yeni bir bina eklendiğinde pencere/fener konumlarını sprite üzerinde elle belirlemek için kullanılır.

```bash
flutter run -t lib/tools/light_editor_main.dart
```

**Kullanım:**
- Sol panelden binayı seç
- Sprite üzerine **sol tık** → ışık noktası ekle
- **Sağ tık** → en yakın noktayı pencere/fener olarak değiştir
- Sağ paneldeki **L/W butonu** → tek noktanın tipini değiştir
- **"Kodu Kopyala"** → Dart kodunu panoya alır

**Çıktıyı nereye yapıştır:**
`lib/buildings/building_type.dart` içindeki `kBuildingLights` map'ini komple değiştir.

**Yeni bina eklerken iş akışı:**
1. `BuildingType` enum'una yeni tip ekle
2. `kBuildingMeta`'ya `BuildingMeta` ekle
3. `BuildingRenderer.loadAll()`'a asset yolunu ekle
4. Editörü çalıştır, ışık noktalarını yerleştir, kodu kopyala
5. `kBuildingLights`'a yapıştır

---

## İzometrik Koordinat Sistemi

- **Tile boyutu**: `kTileW = 64px`, `kTileH = 32px` (2:1 oran)
- **gridToScreen(col, row)**: Grid koordinatını ekran pikselne çevirir, tile'ın **üst köşesini** döner
- **screenToGrid(pos)**: Tersine çevirme

```dart
// Tile köşeleri (col, row) için:
// Üst (back):  gridToScreen(col, row)
// Sol (left):  gridToScreen(col, row+1)
// Sağ (right): gridToScreen(col+1, row)
// Ön (front):  gridToScreen(col+1, row+1)
//
// Tile MERKEZİ: gridToScreen(col+0.5, row+0.5)
```

---

## Bina Sistemi

### BuildingMeta parametreleri

```dart
BuildingMeta({
  cols, rows,          // Kaplanan tile sayısı
  label,               // UI etiketi (Türkçe)
  cost,                // ResourceCost — wood/stone/iron/coal/food/gold
  groundXCenter,       // Sprite genişliğinin kaçta birinde ön köşe (default 0.5)
  groundY,             // Sprite yüksekliğinin kaçta birinde zemin (default 1.0)
  spriteScale,         // Sprite genişliği = footprint_width * spriteScale (default 1.0)
})
```

### Hizalama mantığı

- **groundXCenter = 0.5**: Sprite yatay olarak tam ortalanmış
- **groundXCenter > 0.5**: Sprite sola kayar (sol ağır bina için)
- **groundXCenter < 0.5**: Sprite sağa kayar
- **spriteScale > 1.0**: Sprite'ı footprint'ten daha geniş çiz (mill gibi taşra yapıları için)

### Mevcut binalar (12 tip)

| Bina | Cols×Rows | groundXCenter | spriteScale | Maliyet |
|------|-----------|---------------|-------------|---------|
| firepit | 1×1 | 0.50 | 0.62 | ücretsiz (başlangıç) |
| well | 1×1 | 0.50 | 1.0 | 4🪵 8🪨 |
| lumberCamp | 2×2 | 0.50 | 1.0 | 12🪵 |
| fisherCabin | 2×2 | 0.50 | 1.0 | 14🪵 |
| woodenHouse | 2×2 | 0.50 | 1.0 | 18🪵 4🪨 |
| mineBuilding | 2×2 | 0.50 | 1.0 | 16🪵 8🪨 |
| tavern | 2×2 | 0.51 | 1.0 | 22🪵 10🪨 6🌾 |
| mill | 2×2 | 0.49 | 1.551 | 24🪵 12🪨 |
| warehouse | 2×2 | 0.50 | 1.0 | 28🪵 16🪨 |
| stable | 3×2 | 0.60 | 1.0 | 32🪵 10🪨 |
| market | 3×2 | 0.514 | 1.15 | 30🪵 22🪨 4⚙ |
| townhall | 4×3 | 0.575 | 1.096 | 45🪵 40🪨 12⚙ 25★ |

**Tasarım kademeleri:**
- **Başlangıç**: firepit (ücretsiz) — kurulduğunda NPC spawn olur, uyku noktası tanımlar.
- **Erken**: lumberCamp, fisherCabin, woodenHouse — ağırlıklı odun.
- **Orta**: mineBuilding, tavern, mill, warehouse, stable — odun + taş.
- **İleri**: market, townhall — demir + altın gerekli.

### Gece ışıkları

Her bina için `kBuildingLights` map'inde pencere/fener konumları tanımlı.
`LightKind.window` = sarı puls, `LightKind.lantern` = turuncu titreşim.
`dayLight = 0.0` (gece) → tam parlaklık, `dayLight = 1.0` (gündüz) → ışık yok.
Koordinatlar 0..1 normalize sprite koordinatı — editörle belirlenir.

### İnşaat animasyonu

`drawConstruction()`: Sprite tabandan yukarı açılır, `clipRect` ile gizlenir.
Progress 0→1 = altta başlar, tepede biter.

---

## Ağaç Hizalama Püf Noktaları

Binalar tile **köşesine** yerleşir, ağaçlar tile **MERKEZİne** yerleşir.

```dart
// Ağaç anchor noktası = tile merkezi
final center = gridToScreen(col + 0.5, row + 0.5, size, camera);
// Sprite alt-ortası bu noktaya hizalanır
final left = center.dx - spriteW / 2;
final top  = center.dy - spriteH;
```

### Derinlik sıralaması

Ağaç depth = `col + row + 1.0` (tile'ın ön köşesi gibi davranır, karakterlerle doğru sıralanır)

### Sallantı animasyonu

`canvas.skew(sway, 0)` ile taban sabit, tepe sallanır:
```dart
canvas.translate(center.dx, baseY);  // tabana git
canvas.skew(sin(time * freq + phase) * amp, 0);  // eğ
canvas.translate(-center.dx, -baseY); // geri gel
```
Her ağaç `seed = col*17 + row*31` ile kendi frekansını alır.

---

## Zoom & Kamera

- Zoom aralığı: 0.20 – 4.0
- `canvas.scale(zoom, zoom)` ekran merkezine uygulanır
- Zoom-to-focal-point: `camera_new = camera_old + (focal - center) * (1/zoom_new - 1/zoom_old)`
- Tile culling: 4 ekran köşesini `screenToGrid`'e çevir, bounding rect iterate et

### Viewport sınırları (zoom'a göre)

```dart
(double, double, double, double) _visBounds(Size size) {
  final inv = 1.0 / zoom;
  final hw  = size.width  / 2;
  final hh  = size.height / 2;
  return (
    hw * (1.0 - inv) - kTileW,      // minX
    hw * (1.0 + inv) + kTileW,      // maxX
    hh * (1.0 - inv) - kTileH * 2,  // minY
    hh * (1.0 + inv) + kTileH * 2,  // maxY
  );
}
```

---

## Su Renderer

`WaterRenderer.drawTile()` tamamen programatik, asset gerektirmez.

- **Sin LUT**: 2048 girişli önceden hesaplanmış tablo, `sin()` çağrısından ~10x hızlı
- **LOD eşikleri**:
  - `zoom < 0.30`: Sadece renk + dalga bandı
  - `0.30 ≤ zoom < 0.55`: + sparkle + balık animasyonu
  - `zoom ≥ 0.55`: + yağmur halkaları
- **dayLight**: Su rengi gece/gündüze göre karışır

---

## Gece/Gündüz Döngüsü

`timeOfDay`: 0.0 = gece yarısı, 0.25 = şafak, 0.50 = öğle, 0.75 = gün batımı

- **dayDuration**: Saniye cinsinden tam döngü süresi (test için 30, üretim için 240)
- **sceneOverlay**: Gecede koyu lacivert, şafak/batımda hafif koyu turuncu, gündüz şeffaf
- Overlay alpha **kademeli** düşmeli — ani düşüş şafakta flaş efekti yapar

### Güneş/Ay ark hareketi

`timeOfDay 0.25 → 0.75` arası yarım daire:
```dart
final sunAngle = pi * ((timeOfDay - 0.25) / 0.50).clamp(0, 1);
final sunX = arcCx + arcR * cos(sunAngle);
final sunY = arcBy - arcR * sin(sunAngle);
// Ay: aynı formül, timeOfDay + 0.5
```

---

## Tarla Sistemi

- **FarmTile**: stage 0-4, `growthTimePerStage = 4.0` saniye/aşama
- **FarmFarmer**: idle → walkingToFarm → harvesting, hasat = +8 altın
- **Seçim**: AoE sürükle-bırak, rectangle seçim
- **Cross-fade**: `growthProgress > 0.65` olunca bir sonraki stage `((progress-0.65)/0.35)` alpha ile blend

---

## Yağmur

Deterministic, state gerektirmez:
```dart
final x      = ((i * 1731 + 97) % 1000) / 1000.0 * size.width;  // sabit X
final yPhase = ((i * 617  + 53) % 1000) / 1000.0;               // bağımsız faz
final y      = ((yPhase + time * speedY) % 1.0) * size.height;
```
Golden ratio kullanma — 2D'de diyagonal şerit oluşturur.

---

## Asset Trim / Arka Plan Temizleme

Tüm assetler beyaz arka planlı RGB PNG olarak geliyor. `tools/trim_asset.py` scripti:

1. **Flood-fill** ile kesin arka planı bulur (eşik > 210)
2. **binary_dilation** ile arka planı genişletir → kenar beyazlıklarını öldürür
3. **distance_transform_edt** ile şeffaf piksellere en yakın opak komşunun rengini yazar (Flutter bilinear scaling'de beyaz kanama önlemi)

### Dilation değerleri (denenerek bulundu)

| Asset | Dilation |
|-------|----------|
| birch | 18px |
| pine | 30px |
| oak | 100px |
| binalar | 0px (flood-fill yeterli) |

**Önemli**: Oak'ın dış yaprakları çok açık renkli olduğundan çok fazla dilation gerekiyor.
Birch'in beyaz kabuğu GERÇEK rengi — halo değil.

---

## Kaynak / Ekonomi Sistemi

`core/resources.dart` — tüm ekonomik akışın tek kaynağı.

### ResourceKind (6 tip)

| Kind | Icon | Etiket |
|------|------|--------|
| wood  | 🪵 | Odun |
| stone | 🪨 | Taş |
| iron  | ⚙ | Demir |
| coal  | ♦ | Kömür |
| food  | 🌾 | Yiyecek |
| gold  | ★ | Altın |

### ResourceBundle vs ResourceCost

- **`ResourceBundle`** — köy stoğu, mutable. `add(kind, n)`, `spend(cost)`, `canAfford(cost)`, `formatMissing(cost)` ("12 🪵 + 3 🪨" döner).
- **`ResourceCost`** — değişmez maliyet. `entries` getter sıfır olmayan `(kind, amount)` listesi döner — UI'da chip render için ideal.

### Akış

1. **Üretim**: Worker AI'lar (woodcutter, miner, fisher, farmer) kaynak kutusu / yiyecek üretir.
2. **Taşıma**: Idle köylüler `_assignCarriers()` ile ResourceBox / HayEntity'e atanır.
3. **Stok**: Teslim → `_stockpile.add()`.
4. **Tüketim**: `_tryPlace()` → `canAfford` → `spend(cost)` → BuildOrder oluştur.

---

## Hay / Tarım Zinciri

`world/hay_entity.dart` + `farm/`:

- **FarmTile** stage 4'e ulaştığında çiftçi hasat eder → tarla içinde **HayType.pile** (saman yığını) bırakır.
- Aynı tile'da **4 pile** birikince → **HayType.bale** (balya) olur (1.5 tile yarıçapında cluster algılaması).
- Köylüler balyayı taşır → stockpile'a `food` olarak girer.
- `HayEntity.depth = gridX + gridY` (pile) veya `+1.0` (bale, ön köşeye hizalı).

> Pile detection: 1.5 tile radius, 2 slot/tile.
> `bale_test.dart` bu zinciri izole test etmek için ayrı bir `flutter run -t` hedefi.

---

## Oduncu Kulübesi (Lumber Camp)

`entities/lumber_camp_entity.dart` — manuel ağaç işaretlemenin otonom alternatifi.

### Bölge mekaniği

- **Territory radius**: `kTerritoryRadius = 6.0` tile (binanın merkezinden, dairesel).
- **Hedef ağaç sayısı**: `kTargetTrees = 5` — bölgede bu kadar canlı ağaç tutmaya çalışır.
- **Eşzamanlı işaret**: `kMaxMarked = 2` — aynı anda en fazla 2 ağaç kesim için işaretli.
- **Periyodik yönetim**: 3-5 saniyede bir `_manageTrees()` — eksik ağaç varsa fidan diker, fazla varsa yeni işaretler.

### Fidan dikme

- Bölge içinde 25 deneme: rastgele açı + `1.5 .. radius` mesafe.
- Su, harita kenarı, mevcut ağaç, forbidden tile (binalar) hariç.
- Random `TreeType` (birch/oak/pine), `isGrowing = true` ile başlar.

### Kesme

- `kChopDuration = 10.0` saniye — manuel `WoodcutterEntity`'ye göre yavaş, çünkü otonom.
- Kesme bitince `harvestReady = true` flag'i → ana loop kaynak kutusu spawn eder (`lastHarvestX/Y` koordinatına).

---

## Yağmur Döngüsü

`DayNightCycle` içinde state machine:

```
KURU FAZ:  50-90 saniye → rainIntensity = 0
YAĞIŞLI:   22-38 saniye → rainIntensity 0→1→0 (6sn fade in/out)
```

- Random faz süresi `_rng` ile seed'lenebilir.
- `cloudOpacity` yağmurda +0.15 boost.
- `sceneOverlay`'e `(15, 30, 60)` hafif mavimsi blend ekler.
- `WaterRenderer` yağmur halkalarını `rainIntensity > 0` ve `zoom ≥ 0.55` koşulunda çizer.

---

## Gökyüzü Renk Bandları

`DayNightCycle.skyTop` ve `skyMid` — `timeOfDay`'a göre 9 keyframe arası lerp.

| timeOfDay | Faz | skyTop | skyMid |
|-----------|-----|--------|--------|
| 0.00 | Gece | derin lacivert | siyah-mavi |
| 0.25 | Şafak | yanık turuncu | sıcak sarı |
| 0.32 | Sabah | kornflower | buz mavisi |
| 0.50 | Öğle | berrak mavi | beyaz-mavi |
| 0.75 | Gün batımı | derin kırmızı | ateş turuncu |
| 0.82 | Akşam | mor | mor |

`sceneOverlay` alpha ayrı bir LUT — şafakta 0.32'den 0.00'a kademeli açılır (ani flaş yok). Şafak/batım rengi `0xFF882808`, gece `0xFF060A20`.

---

## Karakter Türleri

`characters/villager_type.dart` — 7 varyant:

```
farmer, merchant, blacksmith, guard, mage, miner, fisher
```

`displayName` getter Türkçe etiket döner (Çiftçi, Tüccar, Demirci, Muhafız, Büyücü, Madenci, Balıkçı). `villager_painter.dart` her tür için ayrı sprite render eder.

---

## Uygulama Akışı / Menü

`_AppRoot` (main.dart) iki ekran arası geçiş yönetir:

```
MainMenuScreen
  ├─ YENİ OYUN     → onNewGame() → _VillageScene
  ├─ AYARLAR       → SettingsScreen (Navigator.push)
  └─ HAKKINDA      → AboutScreen   (Navigator.push)
```

- **MainMenuScreen**: PixelSky + StarField + sürüklenen bulutlar + ufuk silüeti (`_HorizonPainter` — birkaç piksel-ev + kule + ateş ışığı). Atmosferik, oyun başlamadan tema kurar.
- **MedievalTheme** (`ui/game_theme.dart`): renkler (`textAccent = 0xFFFFD944`, `panelBg = 0xF01A0E06`), `buttonDecoration()`, `chipDecoration()`, `panelDecoration()` factory fonksiyonları.
- **SettingsModel**: singleton — ses/görüntü/dil seçenekleri.
- Sürüm: `v0.1.0` (alpha).

---

## Performans Notları

- `shouldRepaint`: Tüm state değişkenlerini karşılaştırır, gereksiz repaint olmaz
- `isAntiAlias = false`: Pixel art için tüm primitive'lerde kapalı
- Yıldızlar: Pseudo-random hash dağılımı `(i*1731+97) % 1000`, golden ratio değil
- Bulutlar: `(_time * 5.0) % wrap` ile sola kayar, wrap-around
- Tile culling: Zoom'a göre viewport dışı tile'lar iterate edilmez
