import '../../buildings/building_entity.dart';
import '../../buildings/building_type.dart';
import '../../core/constants.dart';
import '../world/road_system.dart';
import 'pathfinder.dart';

/// Köy binalarını merkez çevresinde birleştiren görünmez yaya ağı.
///
/// Bu tile'lar dünyada çizilmez ve save'e yazılmaz; bina/engel topolojisinden
/// yeniden türetilir. [PathContext] bunlara hafif maliyet indirimi vererek
/// gündelik trafiği rastgele çaprazlardan okunaklı sokak damarlarına toplar.
Set<(int, int)> buildPedestrianNetwork({
  required List<BuildingEntity> buildings,
  required Set<(int, int)> blockedTiles,
  required Set<(int, int)> softTiles,
  required Set<(int, int)> squeezeTiles,
  required RoadSystem roadSystem,
}) {
  final out = <(int, int)>{};
  if (buildings.isEmpty) return out;

  final hub = _findHub(buildings, blockedTiles);
  if (hub == null) return out;
  out.add(hub);

  final portals = <(int, int)>[];
  for (final building in buildings) {
    final portal = _portalToward(building, hub, blockedTiles, softTiles);
    if (portal != null && !portals.contains(portal)) portals.add(portal);
  }

  // Yakındaki yapılar önce bağlanır. Sonraki yollar mevcut omurgaya düşük
  // maliyetle tutunur; her bina meydana ayrı paralel çizgi açmaz.
  portals.sort((a, b) {
    final da = (a.$1 - hub.$1).abs() + (a.$2 - hub.$2).abs();
    final db = (b.$1 - hub.$1).abs() + (b.$2 - hub.$2).abs();
    return da.compareTo(db);
  });

  for (final portal in portals) {
    final path = Pathfinder.findPath(portal.$1, portal.$2, hub.$1, hub.$2, (
      c,
      r,
    ) {
      if (roadSystem.has(c, r)) return 0.52;
      if (out.contains((c, r))) return 0.62;
      if (squeezeTiles.contains((c, r))) return 4.0;
      if (softTiles.contains((c, r))) return 2.8;
      return 1.0;
    }, (c, r) => blockedTiles.contains((c, r)));
    if (path == null) continue;
    out
      ..add(portal)
      ..addAll(path);
  }
  return out;
}

(int, int)? _findHub(List<BuildingEntity> buildings, Set<(int, int)> blocked) {
  for (final b in buildings) {
    if (b.type != BuildingType.firepit) continue;
    final meta = kBuildingMeta[b.type]!;
    final tile = (b.col + meta.cols ~/ 2, b.row + meta.rows ~/ 2);
    if (!blocked.contains(tile)) return tile;
  }

  final centers = <(int, int)>[
    for (final b in buildings)
      (
        b.col + kBuildingMeta[b.type]!.cols ~/ 2,
        b.row + kBuildingMeta[b.type]!.rows ~/ 2,
      ),
  ];
  final meanC =
      centers.map((p) => p.$1).reduce((a, b) => a + b) ~/ centers.length;
  final meanR =
      centers.map((p) => p.$2).reduce((a, b) => a + b) ~/ centers.length;
  return _nearestFree(meanC, meanR, blocked);
}

(int, int)? _portalToward(
  BuildingEntity building,
  (int, int) hub,
  Set<(int, int)> blocked,
  Set<(int, int)> soft,
) {
  final meta = kBuildingMeta[building.type]!;
  final candidates = <(int, int)>[];
  final minC = building.col - 1;
  final maxC = building.col + meta.cols;
  final minR = building.row - 1;
  final maxR = building.row + meta.rows;

  for (int c = minC; c <= maxC; c++) {
    candidates
      ..add((c, minR))
      ..add((c, maxR));
  }
  for (int r = building.row; r < building.row + meta.rows; r++) {
    candidates
      ..add((minC, r))
      ..add((maxC, r));
  }

  candidates.removeWhere(
    (p) =>
        p.$1 < 1 ||
        p.$1 >= kCols - 1 ||
        p.$2 < 1 ||
        p.$2 >= kRows - 1 ||
        blocked.contains(p) ||
        soft.contains(p),
  );
  if (candidates.isEmpty) return null;
  candidates.sort((a, b) {
    final da = (a.$1 - hub.$1).abs() + (a.$2 - hub.$2).abs();
    final db = (b.$1 - hub.$1).abs() + (b.$2 - hub.$2).abs();
    return da.compareTo(db);
  });
  return candidates.first;
}

(int, int)? _nearestFree(int col, int row, Set<(int, int)> blocked) {
  for (int radius = 0; radius <= 8; radius++) {
    for (int dc = -radius; dc <= radius; dc++) {
      for (int dr = -radius; dr <= radius; dr++) {
        if (dc.abs() != radius && dr.abs() != radius) continue;
        final c = col + dc;
        final r = row + dr;
        if (c < 1 || c >= kCols - 1 || r < 1 || r >= kRows - 1) continue;
        if (!blocked.contains((c, r))) return (c, r);
      }
    }
  }
  return null;
}
