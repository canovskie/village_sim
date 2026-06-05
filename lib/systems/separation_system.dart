import 'dart:math';
import '../core/constants.dart';
import '../entities/builder_entity.dart';
import '../entities/farm_farmer.dart';
import '../entities/fisher_entity.dart';
import '../entities/miner_entity.dart';
import '../entities/shepherd_entity.dart';
import '../entities/villager_entity.dart';
import '../entities/woodcutter_entity.dart';
import '../world/animal_entity.dart';

/// NPC'lere hafif ayrışma kuvveti uygular — iç içe geçmeyi önler.
/// Aktif çalışan entity'ler (hasat, kazma, balık tutma, inşa) sabit kalır;
/// hareketli olanlar onlardan itilir.
///
/// Spatial hash (1 tile bucket): O(n²) yerine O(n).
/// kSeparationRadius < 1 olduğu için 3×3 komşu bucket araması yeterli.
void applySeparation({
  required double dt,
  required List<VillagerEntity> villagers,
  required List<FarmFarmer> farmers,
  required List<WoodcutterEntity> woodcutters,
  required List<MinerEntity> miners,
  required List<FisherEntity> fishers,
  required List<BuilderEntity> builders,
  required Set<(int, int)> waterTiles,
  List<ShepherdEntity> shepherds = const [],
  List<AnimalEntity>   cows      = const [],
}) {
  // (gridX, gridY, setter, isWorking) — tüm hareketli entity'ler
  final entities = <(double, double, void Function(double, double), bool)>[
    for (final v in villagers)
      (v.gridX, v.gridY, (x, y) { v.gridX = x; v.gridY = y; }, false),
    for (final f in farmers)
      (f.gridX, f.gridY, (x, y) { f.gridX = x; f.gridY = y; },
          f.state == FarmerState.harvesting),
    for (final w in woodcutters)
      (w.gridX, w.gridY, (x, y) { w.gridX = x; w.gridY = y; },
          w.state == WoodcutterState.chopping),
    for (final m in miners)
      (m.gridX, m.gridY, (x, y) { m.gridX = x; m.gridY = y; },
          m.state == MinerState.mining),
    for (final fi in fishers)
      (fi.gridX, fi.gridY, (x, y) { fi.gridX = x; fi.gridY = y; },
          fi.state == FisherState.fishing),
    for (final b in builders)
      (b.gridX, b.gridY, (x, y) { b.gridX = x; b.gridY = y; },
          b.state == BuilderState.building),
    for (final sh in shepherds)
      (sh.gridX, sh.gridY, (x, y) { sh.gridX = x; sh.gridY = y; },
          sh.state == ShepherdState.milking),
    for (final c in cows)
      (c.gridX, c.gridY, (x, y) { c.gridX = x; c.gridY = y; },
          c.isBeingMilked),
  ];

  if (entities.length < 2) return;

  // Bucket grid: tile-bazlı (1×1 tile bucket).
  final buckets = <(int, int), List<int>>{};
  for (int i = 0; i < entities.length; i++) {
    final (x, y, _, _) = entities[i];
    final key = (x.floor(), y.floor());
    (buckets[key] ??= []).add(i);
  }

  for (int i = 0; i < entities.length; i++) {
    final (xi, yi, seti, workingI) = entities[i];
    if (workingI) continue; // çalışırken dokunma

    final bx = xi.floor();
    final by = yi.floor();
    double nx = xi, ny = yi;

    // 3×3 komşu bucket — sadece yakın entity'ler.
    for (int dc = -1; dc <= 1; dc++) {
      for (int dr = -1; dr <= 1; dr++) {
        final neighbors = buckets[(bx + dc, by + dr)];
        if (neighbors == null) continue;
        for (final j in neighbors) {
          if (i == j) continue;
          final (xj, yj, _, _) = entities[j];
          final dx   = xi - xj;
          final dy   = yi - yj;
          final dist = sqrt(dx * dx + dy * dy);
          if (dist < kSeparationRadius && dist > 0.001) {
            final push = (kSeparationRadius - dist) /
                kSeparationRadius * kSeparationStrength * dt;
            nx += (dx / dist) * push;
            ny += (dy / dist) * push;
          }
        }
      }
    }

    // Engel tile'ına itme — waterTiles set'i pratikte _obstacles (su + maden
    // + solid bina). NPC bu tile'lara separation force ile sokulamaz.
    final cx = nx.clamp(0.0, kCols - 1.0);
    final cy = ny.clamp(0.0, kRows - 1.0);
    if (!waterTiles.contains((cx.round(), cy.round()))) {
      seti(cx, cy);
    }
  }
}
