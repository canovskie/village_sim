import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/buildings/building_entity.dart';
import 'package:village_sim/buildings/building_type.dart';
import 'package:village_sim/characters/villager_type.dart';
import 'package:village_sim/entities/villager_entity.dart';
import 'package:village_sim/entities/worker_entity.dart';
import 'package:village_sim/systems/npc/path_context.dart';
import 'package:village_sim/systems/npc/pedestrian_network.dart';
import 'package:village_sim/systems/world/road_system.dart';

void main() {
  test('binaları görünmez ve kesintisiz bir yaya omurgasına bağlar', () {
    final buildings = [
      BuildingEntity(type: BuildingType.firepit, col: 10, row: 10),
      BuildingEntity(type: BuildingType.warehouse, col: 16, row: 10),
      BuildingEntity(type: BuildingType.woodenHouse, col: 9, row: 16),
    ];
    final blocked = <(int, int)>{
      for (int c = 16; c < 18; c++)
        for (int r = 10; r < 12; r++) (c, r),
    };

    final lanes = buildPedestrianNetwork(
      buildings: buildings,
      blockedTiles: blocked,
      softTiles: const {},
      squeezeTiles: const {},
      roadSystem: RoadSystem(),
    );

    expect(lanes, contains((10, 10)));
    expect(
      lanes.any((p) => (p.$1 - 16).abs() <= 1 && (p.$2 - 10).abs() <= 2),
      isTrue,
    );
    expect(lanes.any(blocked.contains), isFalse);

    final seen = <(int, int)>{(10, 10)};
    final queue = <(int, int)>[(10, 10)];
    while (queue.isNotEmpty) {
      final p = queue.removeLast();
      for (final n in [
        (p.$1 + 1, p.$2),
        (p.$1 - 1, p.$2),
        (p.$1, p.$2 + 1),
        (p.$1, p.$2 - 1),
      ]) {
        if (lanes.contains(n) && seen.add(n)) queue.add(n);
      }
    }
    expect(seen, lanes, reason: 'görünmez ağ tek parça olmalı');
  });

  test('karşı yönlü yayalar görünmez koridorun zıt yanlarını tutar', () {
    final roadSystem = RoadSystem();
    WorkerEntity.roadSystem = roadSystem;
    WorkerEntity.pathContext = PathContext(
      roadSystem: roadSystem,
      pedestrianTiles: {for (int col = 2; col <= 9; col++) (col, 5)},
    );
    addTearDown(() {
      WorkerEntity.roadSystem = null;
      WorkerEntity.pathContext = null;
    });

    final eastbound = VillagerEntity(
      type: VillagerType.farmer,
      name: 'Doğu',
      male: true,
      startCol: 2.2,
      startRow: 5.4,
    );
    final westbound = VillagerEntity(
      type: VillagerType.farmer,
      name: 'Batı',
      male: false,
      startCol: 8.2,
      startRow: 5.4,
    );

    for (var i = 0; i < 30; i++) {
      eastbound.moveTowards(8.2, 5.4, 0.05);
      westbound.moveTowards(2.2, 5.4, 0.05);
    }

    expect(eastbound.gridY, greaterThan(westbound.gridY));
    expect(eastbound.gridY - westbound.gridY, greaterThan(0.12));
  });
}
