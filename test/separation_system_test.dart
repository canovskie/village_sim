import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/characters/villager_type.dart';
import 'package:village_sim/core/constants.dart';
import 'package:village_sim/entities/villager_entity.dart';
import 'package:village_sim/systems/separation_system.dart';
import 'package:village_sim/world/animal_entity.dart';

double _dist(double x1, double y1, double x2, double y2) {
  final dx = x1 - x2;
  final dy = y1 - y2;
  return dx * dx + dy * dy;
}

void main() {
  group('applySeparation', () {
    test('two close villagers get pushed apart', () {
      final a = VillagerEntity(type: VillagerType.farmer, name: 'A', male: true, startCol: 5, startRow: 5);
      final b = VillagerEntity(type: VillagerType.guard, name: 'B', male: false, startCol: 5.3, startRow: 5);

      final before = _dist(a.gridX, a.gridY, b.gridX, b.gridY);
      applySeparation(
        dt: 0.016,
        villagers:   [a, b],
        waterTiles:  const {},
      );
      final after = _dist(a.gridX, a.gridY, b.gridX, b.gridY);

      expect(after, greaterThan(before),
          reason: 'kSeparationRadius=$kSeparationRadius içindeki entity\'ler itilmeli');
    });

    test('far entities are not pushed', () {
      final a = VillagerEntity(type: VillagerType.guard, name: 'A', male: true, startCol: 5, startRow: 5);
      final b = VillagerEntity(type: VillagerType.guard, name: 'B', male: false, startCol: 12, startRow: 12);
      final ax0 = a.gridX, ay0 = a.gridY;

      applySeparation(
        dt: 0.016,
        villagers:   [a, b],
        waterTiles:  const {},
      );

      expect(a.gridX, ax0);
      expect(a.gridY, ay0);
    });

    test('mixed entity types — separation still applies across kinds', () {
      final v = VillagerEntity(type: VillagerType.farmer, name: 'V', male: true,
                               startCol: 5, startRow: 5);
      final cow = AnimalEntity(
          kind: AnimalKind.cow, barnCol: 0, barnRow: 0,
          startCol: 5.3, startRow: 5);

      final before = _dist(v.gridX, v.gridY, cow.gridX, cow.gridY);
      applySeparation(
        dt: 0.016,
        villagers:   [v],
        cows:        [cow],
        waterTiles:  const {},
      );
      final after = _dist(v.gridX, v.gridY, cow.gridX, cow.gridY);

      expect(after, greaterThan(before));
    });

    test('water blocks the push — entity stays put if pushed onto water', () {
      // İki farmer çok yakın; biri suya doğru itilecek ama su bloklar.
      final a = VillagerEntity(type: VillagerType.guard, name: 'A', male: true, startCol: 5.0, startRow: 5);
      final b = VillagerEntity(type: VillagerType.guard, name: 'B', male: false, startCol: 5.3, startRow: 5);
      // a'nın itileceği yön: (-x, 0). x=4 tile'ını su yap.
      final water = {(4, 5)};

      final ax0 = a.gridX;
      applySeparation(
        dt: 0.5,
        villagers:   [a, b],
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
      // Ateş başına oturmuş köylü (sitClaimed) "çalışıyor" sayılır → itilmez.
      final seated = VillagerEntity(type: VillagerType.farmer, name: 'S', male: true,
                                    startCol: 5, startRow: 5)
        ..sitClaimed = true;
      final passerby = VillagerEntity(type: VillagerType.guard, name: 'V', male: true,
                                      startCol: 5.2, startRow: 5);

      final sx0 = seated.gridX, sy0 = seated.gridY;
      applySeparation(
        dt: 0.016,
        villagers:   [seated, passerby],
        waterTiles:  const {},
      );

      expect(seated.gridX, sx0, reason: 'oturan köylü yerinden oynamamalı');
      expect(seated.gridY, sy0);
    });

    test('empty entity lists do not crash', () {
      applySeparation(
        dt: 0.016,
        villagers:   [],
        waterTiles:  const {},
      );
    });

  });
}
