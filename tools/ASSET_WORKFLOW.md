# Asset Entegrasyon Workflow

## Kaynak Klasör
`/Users/cankaynar/Desktop/medieval assets/`

Yeni bir PNG buraya eklendiğinde aşağıdaki adımları sırayla uygula.

---

## 1. Trim & Analiz

```bash
python3 tools/trim_asset.py "/Users/cankaynar/Desktop/medieval assets/yeni_asset.png" --dry
```

Çıktıdan şunları not et:
- **Trimmed** boyut (gerçek içerik px)
- **BBox** sol/üst/sağ/alt değerleri

Trim sonrası görsel kırpıldığı için taban her zaman alt kenarda → `groundY = 1.0` (sabit).

`groundXCenter` için analiz script'i çalıştır (aşağıda).

## 2. Asset'i Oyuna Kopyala

```bash
python3 tools/trim_asset.py "/Users/cankaynar/Desktop/medieval assets/yeni_asset.png" \
    --out assets/buildings
```

Trimlenmiş (şeffaf arkaplan + sıkı bounding box) PNG `assets/buildings/` altına düşer.

## 2b. groundXCenter Ölç

```bash
python3 - << 'EOF'
from PIL import Image
import numpy as np

img = Image.open("assets/buildings/DOSYA.png").convert("RGBA")
arr = np.array(img)
mask = arr[:,:,3] > 10
rows = np.any(mask, axis=1)
h = img.height
bottom = int(h - np.argmax(rows[::-1]))

# Son içerik satırı = taban
row_mask = mask[bottom-1,:]
gl = int(np.argmax(row_mask))
gr = int(img.width - np.argmax(row_mask[::-1]))
print(f"groundXCenter = {(gl+gr)/2/img.width:.4f}")
EOF
```

## 3. BuildingType Ekle

`lib/buildings/building_type.dart` içine:

```dart
enum BuildingType {
  placeholder,
  woodenHouse,
  yeniBina,       // ← ekle
}

const Map<BuildingType, BuildingMeta> kBuildingMeta = {
  // ...
  BuildingType.yeniBina: BuildingMeta(
    cols: 2,          // kaç tile genişlik
    rows: 2,          // kaç tile derinlik
    label: 'Etiket',
    goldCost: 100,
    groundY: 1.0,           // trimlanmış sprite → taban = alt kenar (sabit)
    groundXCenter: 0.466,   // 2b adımından ölçülen değer
  ),
};
```

## 4. Sprite'ı Yükle

`lib/buildings/building_renderer.dart` → `loadAll()` içine:

```dart
await _loadSprite(BuildingType.yeniBina, 'assets/buildings/yeni_asset.png');
```

## 5. pubspec.yaml

`assets/buildings/` wildcard zaten tanımlı — yeni dosya için ek satır gerekmez.

## 6. Test

```
flutter run
```

Bina panelinde görünmeli, tile üzerine ghost + yerleştirme çalışmalı.
`groundY` yanlışsa bina yukarıda/aşağıda duruyor demektir — değeri ±0.05 adımlarla ayarla.

---

## Mevcut Asset Tablosu

| Dosya | Orijinal | Trimmed | groundY | BuildingType |
|-------|----------|---------|---------|--------------|
| minihouse.png | 1254×1254 | 1077×1044 | groundY=1.0, centerX=0.466 | woodenHouse (2×2, 80g) |
| mill.png      | 1254×1254 | 1055×1200 | groundY=1.0, centerX=0.561 | mill (2×2, 120g)       |
| stable.png    | 1254×1254 | 1200×1057 | groundY=1.0, centerX=0.624 | stable (3×2, 150g)     |

---

## groundY ve groundXCenter

- `groundY = 1.0` — trim_asset.py ile kırpılmış her sprite için sabittir. Taban = alt kenar.
- `groundXCenter` — 2b adımındaki script ile ölçülür. Asimetrik binalar için 0.5'ten farklı olabilir.

Bina havada görünüyorsa → görüntü tam kırpılmamış, tekrar `trim_asset.py --inplace` çalıştır.
Sağa/sola kayıksa → `groundXCenter` değerini ±0.02 adımlarla ayarla.
