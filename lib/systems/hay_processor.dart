import '../core/constants.dart';
import '../farm/farm_tile.dart';
import '../world/hay_entity.dart';

/// Tarladan toplanan saman yığınları (pile) belirli bir **harman** noktasında
/// balyaya (bale) dönüşür. Her [kHayPilesPerBale] yığın → 1 balya. Balyalar
/// harman ve etrafında 2×2 grid'de düzenli dizilir, harman dolarsa komşu
/// tile'lara taşar.
///
/// Harman = tüm farm tile'larının centroid'ine en yakın farm tile.
/// Birden çok kopuk tarla olsa bile şimdilik tek harman paylaşılır (basit).
///
/// Yığın seçimi FIFO: en eski yığınlar dönüştürülür → tahmin edilebilir akış.
void processHayPiles(List<HayEntity> hayEntities, List<FarmTile> farmTiles) {
  if (farmTiles.isEmpty) return;

  final piles = hayEntities
      .where((h) => !h.isBale && !h.isBeingCarried && !h.isDelivered)
      .toList();
  if (piles.length < kHayPilesPerBale) return;

  piles.sort((a, b) => a.spawnTime.compareTo(b.spawnTime));
  final consumed = piles.take(kHayPilesPerBale).toList();

  final (hc, hr) = _harmanPos(farmTiles);
  final (bx, by) = _findFreeBaleSpot(hayEntities, hc, hr);
  hayEntities.add(HayEntity(type: HayType.bale, gridX: bx, gridY: by));

  // Sadece tükettiğimiz yığınları sil — geniş `removeWhere(isDelivered)`
  // aynı karede taşıyıcının teslim ettiği BALYAYI da süpürebiliyordu.
  hayEntities.removeWhere(consumed.contains);
}

(int, int) _harmanPos(List<FarmTile> tiles) {
  double sc = 0, sr = 0;
  for (final t in tiles) {
    sc += t.col;
    sr += t.row;
  }
  final cx = sc / tiles.length;
  final cy = sr / tiles.length;
  var best = tiles.first;
  var bestD = double.infinity;
  for (final t in tiles) {
    final dx = t.col - cx;
    final dy = t.row - cy;
    final d = dx * dx + dy * dy;
    if (d < bestD) {
      bestD = d;
      best = t;
    }
  }
  return (best.col, best.row);
}

// Harman tile'ı içinde 2×2 yerleşim (balya ~0.5×0.5 birim).
// İzometride sağa+aşağı = ön; back-row (slot 0,1) önce çizilir.
const _baleSlots = <(double, double)>[
  (0.05, 0.05), // back-left
  (0.55, 0.05), // back-right
  (0.05, 0.55), // front-left
  (0.55, 0.55), // front-right
];

// Harman tile'ı önce, sonra çevresi.
const _harmanTileOffsets = <(int, int)>[
  (0, 0),
  (1, 0), (0, 1), (1, 1),
  (-1, 0), (0, -1), (-1, 1), (1, -1), (-1, -1),
];

(double, double) _findFreeBaleSpot(
    List<HayEntity> all, int hc, int hr) {
  for (final (dc, dr) in _harmanTileOffsets) {
    final tc = hc + dc;
    final tr = hr + dr;
    for (final slot in _baleSlots) {
      final bx = tc + slot.$1;
      final by = tr + slot.$2;
      if (_isFree(all, bx, by)) return (bx, by);
    }
  }
  return (hc + 0.25, hr + 0.25); // her şey dolu — overlap fallback (çok nadir)
}

bool _isFree(List<HayEntity> all, double x, double y) {
  // Balya 0.5×0.5 birim; merkezler 0.45+ uzaksa görsel overlap olmaz.
  const minDistSq = 0.45 * 0.45;
  for (final h in all) {
    if (!h.isBale || h.isDelivered || h.isBeingCarried) continue;
    final dx = h.gridX - x;
    final dy = h.gridY - y;
    if (dx * dx + dy * dy < minDistSq) return false;
  }
  return true;
}
