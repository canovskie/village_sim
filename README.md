# Village Sim

Flutter ile yazılmış izometrik köy simülasyonu. Oyuncu bir köy kurar,
yönetir ve altı yıl sonra imparatorluğa hesap verir. Türkçe.

```bash
flutter pub get
flutter run              # oyun
flutter test             # 659 test
flutter analyze
```

Oyun içi: **Tab** → Köy Defteri · **`** (backtick) → geliştirici konsolu

---

## Nereye bakmalı

Bu dosya kısa tutulur. Gerçek belgeler şunlar:

| Soru | Dosya |
|---|---|
| **Bu projede nasıl çalışılır?** Tasarım kuralları, tuzaklar, doğrulama | [CLAUDE.md](CLAUDE.md) |
| **Şu an ne bitti, ne eksik, ne fazla?** | [DURUM.md](DURUM.md) |
| **Bu iş nerede yaşıyor?** | `lib/main.dart` başındaki HARİTA yorumu |

> Bu README bir kez 452 satırlık, artık var olmayan bir mimariyi anlatır hâle
> geldi ve okuyanı yanlış yöne gönderdi. O yüzden burada yalnız **eskimeyen**
> şeyler durur; değişen her şey yukarıdaki üç yere yazılır.

---

## Mimarinin tek cümlesi

Saf mantık `lib/systems/` altında (Flutter yok, test edilebilir), sahneye
`lib/scene/` altındaki `main.dart` part'ları bağlar, `lib/ui/` yalnız çizer.
Yeni mantık sahneye gömülmez.

---

## Eskimeyen teknik notlar

### İzometrik koordinat

`kTileW = 64`, `kTileH = 32` (2:1). `gridToScreen(col, row)` tile'ın **üst
köşesini** döner — merkez değil.

```dart
// Bir tile'ın köşeleri:
//   üst   gridToScreen(col,     row)
//   sol   gridToScreen(col,     row + 1)
//   sağ   gridToScreen(col + 1, row)
//   ön    gridToScreen(col + 1, row + 1)
// MERKEZ: gridToScreen(col + 0.5, row + 0.5)
```

### Varlık işleme

Sprite'lar `tools/sprite_process.py` ile hazırlanır (checker arka plan
otomatik algılanır, halo temizlenir; **tolerance = 14 kritik**).

Eski beyaz-arka-planlı varlıklar için `tools/trim_asset.py`. Dilation
değerleri denenerek bulundu:

| Varlık | Dilation |
|---|---|
| birch | 18 px |
| pine | 30 px |
| oak | 100 px |
| binalar | 0 px (flood-fill yeterli) |

Oak'ın dış yaprakları çok açık olduğu için yüksek dilation ister. Birch'in
beyaz kabuğu **gerçek rengidir** — halo değil, temizleme.
