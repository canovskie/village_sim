import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/characters/villager_type.dart';
import 'package:village_sim/core/constants.dart';
import 'package:village_sim/entities/builder_entity.dart';
import 'package:village_sim/entities/farm_farmer.dart';
import 'package:village_sim/entities/fisher_entity.dart';
import 'package:village_sim/entities/miner_entity.dart';
import 'package:village_sim/entities/villager_entity.dart';
import 'package:village_sim/entities/woodcutter_entity.dart';
import 'package:village_sim/systems/separation_system.dart';

double _dist(double x1, double y1, double x2, double y2) {
  final dx = x1 - x2;
  final dy = y1 - y2;
  return (dx * dx + dy * dy);
}

void main() {
  group('applySeparation', () {
    test('two close villagers get pushed apart', () {
      final a = VillagerEntity(type: VillagerType.farmer, startCol: 5, startRow: 5);
      final b = VillagerEntity(type: VillagerType.guard,  startCol: 5.3, startRow: 5);

      final before = _dist(a.gridX, a.gridY, b.gridX, b.gridY);
      applySeparation(
        dt: 0.016,
        villagers:   [a, b],
        farmers:     [],
        woodcutters: [],
        miners:      [],
        fishers:     [],
        builders:    [],
        waterTiles:  const {},
      );
      final after = _dist(a.gridX, a.gridY, b.gridX, b.gridY);

      expect(after, greaterThan(before),
          reason: 'kSeparationRadius=$kSeparationRadius içindeki entity\'ler itilmeli');
    });

    test('far entities are not pushed', () {
      final a = VillagerEntity(type: VillagerType.guard, startCol: 5, startRow: 5);
      final b = VillagerEntity(type: VillagerType.guard, startCol: 12, startRow: 12);
      final ax0 = a.gridX, ay0 = a.gridY;

      applySeparation(
        dt: 0.016,
        villagers:   [a, b],
        farmers:     [],
        woodcutters: [],
        miners:      [],
        fishers:     [],
        builders:    [],
        waterTiles:  const {},
      );

      expect(a.gridX, ax0);
      expect(a.gridY, ay0);
    });

    test('mixed entity types — separation still applies across kinds', () {
      final v = VillagerEntity(type: VillagerType.farmer,
                               startCol: 5, startRow: 5);
      final w = WoodcutterEntity(startCol: 5.3, startRow: 5);

      final before = _dist(v.gridX, v.gridY, w.gridX, w.gridY);
      applySeparation(
        dt: 0.016,
        villagers:   [v],
        farmers:     [],
        woodcutters: [w],
        miners:      [],
        fishers:     [],
        builders:    [],
        waterTiles:  const {},
      );
      final after = _dist(v.gridX, v.gridY, w.gridX, w.gridY);

      expect(after, greaterThan(before));
    });

    test('water blocks the push — entity stays put if pushed onto water', () {
      // İki farmer çok yakın; biri suya doğru itilecek ama su bloklar.
      final a = VillagerEntity(type: VillagerType.guard, startCol: 5.0, startRow: 5);
      final b = VillagerEntity(type: VillagerType.guard, startCol: 5.3, startRow: 5);
      // a'nın itileceği yön: (-x, 0). x=4 tile'ını su yap.
      final water = {(4, 5)};

      final ax0 = a.gridX;
      applySeparation(
        dt: 0.5,
        villagers:   [a, b],
        farmers:     [],
        woodcutters: [],
        miners:      [],
        fishers:     [],
        builders:    [],
        waterTiles:  water,
      );

      // Hedef tile (4, 5) ise a'nın gridX değişmemeli (round → 5 → güvenli, round → 4 → block).
      // Push küçük olduğu için a hâlâ tile 5'te kalacak veya su engellediği için 5'te tutulacak.
      // Kritik: a hâla geçerli karada — gridX.round() != 4 ya da == 4 ama water tile ise eski konum.
      final newTile = a.gridX.round();
      if (newTile == 4) {
        // Water yüzünden geri çekildiyse gridX değişmemiş olmalı.
        expect(a.gridX, ax0, reason: 'su bloklarsa konum eskidekiyle aynı');
      } else {
        // Karadaysa gridX değişebilir — ama tile su olmamalı.
        expect(water.contains((newTile, a.gridY.round())), isFalse);
      }
    });

    test('working entity is not displaced', () {
      // Builder building durumunda → workingI=true → push uygulanmaz.
      final builder = BuilderEntity(startCol: 5, startRow: 5)
        ..state = BuilderState.building;
      final villager = VillagerEntity(type: VillagerType.guard,
                                      startCol: 5.2, startRow: 5);

      final bx0 = builder.gridX, by0 = builder.gridY;
      applySeparation(
        dt: 0.016,
        villagers:   [villager],
        farmers:     [],
        woodcutters: [],
        miners:      [],
        fishers:     [],
        builders:    [builder],
        waterTiles:  const {},
      );

      expect(builder.gridX, bx0,
          reason: 'aktif inşaatçı yerinden oynamamalı');
      expect(builder.gridY, by0);
    });

    test('empty entity lists do not crash', () {
      applySeparation(
        dt: 0.016,
        villagers:   [],
        farmers:     [],
        woodcutters: [],
        miners:      [],
        fishers:     [],
        builders:    [],
        waterTiles:  const {},
      );
    });

    // Compiler memnuniyeti için kullanılmamış importları referansla.
    test('placeholder for unused imports', () {
      expect(MinerEntity, isNotNull);
      expect(FisherEntity, isNotNull);
      expect(FarmFarmer, isNotNull);
    });
  });
}
