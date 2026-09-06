import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/buildings/building_entity.dart';
import 'package:village_sim/buildings/building_type.dart';
import 'package:village_sim/characters/life_stage.dart';
import 'package:village_sim/characters/villager_type.dart';
import 'package:village_sim/core/resources.dart';
import 'package:village_sim/entities/road_order.dart';
import 'package:village_sim/entities/villager_entity.dart';
import 'package:village_sim/rendering/game_painter.dart';
import 'package:village_sim/systems/labor/carrier_system.dart';
import 'package:village_sim/systems/npc/anchor_system.dart';
import 'package:village_sim/systems/world/road_system.dart';
import 'package:village_sim/world/resource_box.dart';
import 'package:village_sim/world/road_surface.dart';
import 'package:village_sim/world/road_tile.dart';

VillagerEntity _villager({VillagerType type = VillagerType.merchant}) =>
    VillagerEntity(
      type: type,
      name: 'Tepki Testi',
      male: true,
      startCol: 3,
      startRow: 3,
      ageDays: kAdultStartDay + 2,
      visualSeed: 23,
      personalitySeed: 23,
    );

Future<Uint8List> _render({
  List<VillagerEntity> villagers = const [],
  List<BuildingEntity> buildings = const [],
  List<RoadOrder> roads = const [],
  RoadSystem? roadSystem,
  double time = 0.5,
}) async {
  const size = ui.Size(480, 320);
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  VillageGamePainter(
    villagers: villagers,
    buildings: buildings,
    pendingOrders: const [],
    pendingRoadOrders: roads,
    roadSystem: roadSystem ?? RoadSystem(),
    camera: ui.Offset.zero,
    time: time,
    dayLight: 1,
    perfMode: true,
  ).paint(canvas, size);
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.toInt(), size.height.toInt());
  picture.dispose();
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return bytes!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('duraklatılan bina hareket yoğunluğunu tek karede kaybetmez', () {
    final building = BuildingEntity(
      type: BuildingType.mineBuilding,
      col: 3,
      row: 4,
    );
    building.updateActivityLevel(0.1, operational: true);
    final active = building.activityLevel;

    building.updateActivityLevel(0.1, operational: false);

    expect(active, greaterThan(0));
    expect(building.activityLevel, greaterThan(0));
    expect(building.activityLevel, lessThan(active));
    building.updateActivityLevel(1, operational: false);
    expect(building.activityLevel, 0);
  });

  test('kaynak teslimi gerçek depo üzerinde dünya geri bildirimi üretir', () {
    final warehouse = BuildingEntity(
      type: BuildingType.warehouse,
      col: 4,
      row: 4,
    );
    final anchors = AnchorSystem()..rebuild([warehouse]);
    final carrier = _villager();
    final box = ResourceBox(
      type: ResourceBoxType.woodChunk,
      gridX: 3,
      gridY: 3,
    );
    final boxes = [box];
    final stock = ResourceBundle();
    var now = 10.0;
    assignCarriers(
      villagers: [carrier],
      buildings: [warehouse],
      resourceBoxes: boxes,
      hayEntities: const [],
      stockpile: stock,
      anchorSystem: anchors,
      timeNow: () => now,
    );

    final rng = Random(2);
    for (var i = 0; i < 180 && boxes.isNotEmpty; i++) {
      now += 0.1;
      carrier.update(0.1, 30, 30, rng, dayLight: 1);
      carrier.smoothMotion(0.1);
    }

    expect(boxes, isEmpty);
    expect(stock.wood, 1);
    expect(warehouse.deliveryFeedback, '+1 odun');
    expect(warehouse.deliveryFeedbackUntil, greaterThan(now));
  });

  test('iş ataması baş onayı üretir ve hedefe döndürür', () {
    final villager = _villager();
    villager.acknowledgeAssignment(9, 3);

    expect(villager.assignmentNodCue, greaterThan(0));
    expect(villager.facingRight, isTrue);

    villager.update(1, 30, 30, Random(1), dayLight: 1);
    expect(villager.assignmentNodCue, 0);
  });

  test('tamamlanan yol son taş animasyonu boyunca emri korur', () async {
    final roadSystem = RoadSystem()
      ..add(RoadTile(col: 4, row: 4, surface: RoadSurface.stone));
    final order = RoadOrder(col: 4, row: 4, surface: RoadSurface.stone)
      ..markCompleted();
    final withLastStone = await _render(
      roads: [order],
      roadSystem: roadSystem,
      time: 0.2,
    );

    order.completionCue = 0;
    final settled = await _render(
      roads: [order],
      roadSystem: roadSystem,
      time: 0.2,
    );

    expect(withLastStone, isNot(orderedEquals(settled)));
  });

  test('teslim yazısı ve demirci vuruşu dünya çizimini değiştirir', () async {
    final warehouse = BuildingEntity(
      type: BuildingType.warehouse,
      col: 4,
      row: 4,
    );
    final quietWarehouse = await _render(buildings: [warehouse], time: 0.5);
    warehouse.showDeliveryFeedback(0, '+1 odun');
    expect(
      await _render(buildings: [warehouse], time: 0.5),
      isNot(orderedEquals(quietWarehouse)),
    );

    final smith = _villager(type: VillagerType.blacksmith);
    final idleSmith = await _render(villagers: [smith], time: 0.1);
    smith.strikeAtForge();
    expect(
      await _render(villagers: [smith], time: 0.1),
      isNot(orderedEquals(idleSmith)),
    );
  });
}
