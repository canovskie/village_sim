import 'dart:math';

import '../core/constants.dart';
import '../farm/farm_tile.dart';
import '../world/harman_site.dart';
import '../world/hay_entity.dart';

/// İlk tarlaya en yakın, tarlanın DIŞINDA kalan boş 2×2 harman yerini bulur.
/// [blocked] suyu, yapıları, yolları, ağaçları ve tarla tile'larını içermelidir.
HarmanSite? findHarmanSite(
  List<FarmTile> farmTiles,
  Set<(int, int)> blocked, {
  int cols = kCols,
  int rows = kRows,
}) {
  if (farmTiles.isEmpty || cols < HarmanSite.size || rows < HarmanSite.size) {
    return null;
  }

  final farmSet = {for (final tile in farmTiles) (tile.col, tile.row)};
  double farmCenterX = 0;
  double farmCenterY = 0;
  for (final tile in farmTiles) {
    farmCenterX += tile.col + 0.5;
    farmCenterY += tile.row + 0.5;
  }
  farmCenterX /= farmTiles.length;
  farmCenterY /= farmTiles.length;

  HarmanSite? best;
  var bestScore = double.infinity;
  for (int col = 0; col <= cols - HarmanSite.size; col++) {
    for (int row = 0; row <= rows - HarmanSite.size; row++) {
      var free = true;
      for (int c = col; c < col + HarmanSite.size && free; c++) {
        for (int r = row; r < row + HarmanSite.size; r++) {
          if (blocked.contains((c, r)) || farmSet.contains((c, r))) {
            free = false;
            break;
          }
        }
      }
      if (!free) continue;

      // Önce tarlaya bitişiklik, eşitlikte tarla merkezine yakınlık kazanır.
      var nearestFarmSq = double.infinity;
      for (final tile in farmTiles) {
        final dx = max(col - tile.col, tile.col - (col + 1)).toDouble();
        final dy = max(row - tile.row, tile.row - (row + 1)).toDouble();
        nearestFarmSq = min(nearestFarmSq, dx * dx + dy * dy);
      }
      final centerDx = col + 1.0 - farmCenterX;
      final centerDy = row + 1.0 - farmCenterY;
      final score =
          nearestFarmSq * 10000 + centerDx * centerDx + centerDy * centerDy;
      if (score < bestScore) {
        bestScore = score;
        best = HarmanSite(col: col, row: row);
      }
    }
  }
  return best;
}

bool hayTargetsHarman(HayEntity hay, HarmanSite site) =>
    hay.targetHarmanCol == site.col && hay.targetHarmanRow == site.row;

/// Harmandaki mevcut ve yolda olan samanın demet karşılığı.
int harmanSheafLoad(HarmanSite site, List<HayEntity> all) {
  var load = 0;
  for (final hay in all) {
    if (hay.isDelivered) continue;
    final belongs =
        site.containsPoint(hay.gridX, hay.gridY) || hayTargetsHarman(hay, site);
    if (!belongs) continue;
    // Harmandan ambara çıkmış balya artık kapasite tutmaz. Tarladan harmana
    // gelen pile ise taşıma sırasında rezervasyon olarak sayılmaya devam eder.
    if (hay.isBale && hay.isBeingCarried) continue;
    load += hay.isBale ? kHayPilesPerBale : 1;
  }
  return load;
}

bool harmanCanAccept(HarmanSite site, List<HayEntity> all) =>
    harmanSheafLoad(site, all) < HarmanSite.maxSheafEquivalents;

/// Bir demeti harmanın dört tile'ına dengeli ve okunaklı biçimde bırakır.
void placeHayAtHarman(
  HayEntity hay,
  HarmanSite site,
  List<HayEntity> all, {
  double time = 0,
}) {
  final piles = all
      .where(
        (other) =>
            !identical(other, hay) &&
            !other.isBale &&
            !other.isDelivered &&
            site.containsPoint(other.gridX, other.gridY),
      )
      .length;
  final tileIndex = piles % 4;
  final localSlot = piles ~/ 4;
  final tileCol = site.col + tileIndex % 2;
  final tileRow = site.row + tileIndex ~/ 2;
  hay
    ..gridX = tileCol + 0.5
    ..gridY = tileRow + 0.5
    ..slotIndex = localSlot
    ..spawnTime = time
    ..isBeingCarried = false
    ..isDelivered = false
    ..targetHarmanCol = site.col
    ..targetHarmanRow = site.row;
}

/// Eski kayıttan tarla üstünde dönen bir balyayı harmandaki boş slota alır.
void placeBaleAtHarman(
  HayEntity hay,
  HarmanSite site,
  List<HayEntity> all, {
  double time = 0,
}) {
  final spot = _findFreeBaleSpot(all, site, exclude: hay);
  hay
    ..gridX = spot.$1
    ..gridY = spot.$2
    ..spawnTime = time
    ..isBeingCarried = false
    ..isDelivered = false
    ..targetHarmanCol = site.col
    ..targetHarmanRow = site.row;
}

/// Yalnız kendi 2×2 harmanında duran demetleri FIFO biçiminde balyalar.
/// Her harman kare başına en fazla bir balya üretir.
void processHayPiles(
  List<HayEntity> hayEntities,
  List<HarmanSite> sites, {
  double time = 0,
}) {
  for (final site in sites) {
    // Taşıma ortasında alınmış kayıttan dönen demet artık bir köylünün elinde
    // değildir. Ayrılmış olduğu harmana güvenle tamamla.
    for (final hay in hayEntities) {
      if (hay.isBale || hay.isDelivered || hay.isBeingCarried) continue;
      if (hayTargetsHarman(hay, site) &&
          !site.containsPoint(hay.gridX, hay.gridY)) {
        placeHayAtHarman(hay, site, hayEntities, time: time);
      }
    }

    final piles =
        hayEntities
            .where(
              (hay) =>
                  !hay.isBale &&
                  !hay.isBeingCarried &&
                  !hay.isDelivered &&
                  site.containsPoint(hay.gridX, hay.gridY),
            )
            .toList()
          ..sort((a, b) => a.spawnTime.compareTo(b.spawnTime));
    if (piles.length < kHayPilesPerBale) continue;

    final consumed = piles.take(kHayPilesPerBale).toList();
    final bale = HayEntity(type: HayType.bale, gridX: 0, gridY: 0);
    placeBaleAtHarman(bale, site, hayEntities, time: time);
    hayEntities.add(bale);
    hayEntities.removeWhere(consumed.contains);
  }
}

const _baleSlots = <(double, double)>[
  (0.25, 0.25),
  (0.75, 0.25),
  (1.25, 0.25),
  (1.75, 0.25),
  (0.25, 0.75),
  (0.75, 0.75),
  (1.25, 0.75),
  (1.75, 0.75),
  (0.25, 1.25),
  (0.75, 1.25),
  (1.25, 1.25),
  (1.75, 1.25),
];

(double, double) _findFreeBaleSpot(
  List<HayEntity> all,
  HarmanSite site, {
  HayEntity? exclude,
}) {
  for (final slot in _baleSlots) {
    final x = site.col + slot.$1;
    final y = site.row + slot.$2;
    if (_baleSpotFree(all, x, y, exclude: exclude)) return (x, y);
  }
  return (site.col + 0.25, site.row + 1.75);
}

bool _baleSpotFree(
  List<HayEntity> all,
  double x,
  double y, {
  HayEntity? exclude,
}) {
  const minDistSq = 0.45 * 0.45;
  for (final hay in all) {
    if (identical(hay, exclude)) continue;
    if (!hay.isBale || hay.isDelivered || hay.isBeingCarried) continue;
    final dx = hay.gridX - x;
    final dy = hay.gridY - y;
    if (dx * dx + dy * dy < minDistSq) return false;
  }
  return true;
}
