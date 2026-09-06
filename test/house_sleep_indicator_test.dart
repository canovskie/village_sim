import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/buildings/building_entity.dart';
import 'package:village_sim/buildings/building_renderer.dart';
import 'package:village_sim/buildings/building_type.dart';
import 'package:village_sim/rendering/game_painter.dart';
import 'package:village_sim/rendering/smoke_renderer.dart';
import 'package:village_sim/systems/world/road_system.dart';

Future<Uint8List> _renderHouse(BuildingEntity house) async {
  const size = ui.Size(480, 320);
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  VillageGamePainter(
    villagers: const [],
    buildings: [house],
    pendingOrders: const [],
    roadSystem: RoadSystem(),
    camera: ui.Offset.zero,
    time: 1.25,
    dayLight: 1,
    perfMode: true,
  ).paint(canvas, size);
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.toInt(), size.height.toInt());
  picture.dispose();
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ev uyku işareti', () {
    test('yalnız gerçekten uyuyan sakinleri sayar', () {
      final house =
          BuildingEntity(type: BuildingType.woodenHouse, col: 3, row: 4)
            ..occupants = 3
            ..awakeOccupants = 2;

      expect(house.sleepingOccupants, 1);

      house.awakeOccupants = 0;
      expect(house.sleepingOccupants, 3);
    });

    test('boş ve bütünüyle uyanık ev uyuyan üretmez', () {
      final house = BuildingEntity(
        type: BuildingType.woodenHouse,
        col: 3,
        row: 4,
      );

      expect(house.sleepingOccupants, 0);

      house
        ..occupants = 2
        ..awakeOccupants = 2;
      expect(house.sleepingOccupants, 0);
    });

    test('geçişte tutarsız sayaç negatif değer üretmez', () {
      final house =
          BuildingEntity(type: BuildingType.woodenHouse, col: 3, row: 4)
            ..occupants = 1
            ..awakeOccupants = 2;

      expect(house.sleepingOccupants, 0);
    });

    test('uyku durumu ev çizimine görünür Z animasyonu ekler', () async {
      final house =
          BuildingEntity(type: BuildingType.woodenHouse, col: 3, row: 4)
            ..occupants = 2
            ..awakeOccupants = 2;
      final awakeFrame = await _renderHouse(house);

      house.awakeOccupants = 1;
      final sleepingFrame = await _renderHouse(house);

      expect(sleepingFrame, isNot(orderedEquals(awakeFrame)));
    });

    test('şafakta ilk uyanan sakin tek baca pufu başlatır', () {
      final house =
          BuildingEntity(type: BuildingType.woodenHouse, col: 3, row: 4)
            ..occupants = 2
            ..awakeOccupants = 0;
      house.updateHouseholdSleepCue(now: 10, isMorning: false);
      expect(house.householdAsleep, isTrue);
      expect(house.wakePuffUntil, 0);

      house.awakeOccupants = 1;
      house.updateHouseholdSleepCue(now: 20, isMorning: true);

      expect(house.householdAsleep, isFalse);
      expect(
        house.wakePuffUntil,
        closeTo(20 + BuildingEntity.wakePuffDuration, 0.001),
      );
    });

    test('gece huzursuz kalkış sabah pufunu tetiklemez', () {
      final house =
          BuildingEntity(type: BuildingType.woodenHouse, col: 3, row: 4)
            ..occupants = 2
            ..awakeOccupants = 0;
      house.updateHouseholdSleepCue(now: 10, isMorning: false);

      house.awakeOccupants = 1;
      house.updateHouseholdSleepCue(now: 12, isMorning: false);

      expect(house.wakePuffUntil, 0);
    });

    test('uyanma pufu ev çizimine görünür duman ekler', () async {
      await SmokeRenderer.loadAll();
      final house =
          BuildingEntity(type: BuildingType.woodenHouse, col: 3, row: 4)
            ..occupants = 2
            ..awakeOccupants = 2;
      final quietFrame = await _renderHouse(house);

      house.wakePuffUntil = 2.25;
      final wakeFrame = await _renderHouse(house);

      expect(wakeFrame, isNot(orderedEquals(quietFrame)));
    });

    test('dolu evin eşiğinde görünür yaşam izi oluşur', () async {
      await BuildingRenderer.loadAll();
      final house = BuildingEntity(
        type: BuildingType.woodenHouse,
        col: 3,
        row: 4,
      );
      final emptyFrame = await _renderHouse(house);

      house
        ..occupants = 2
        ..awakeOccupants = 2;
      final livedInFrame = await _renderHouse(house);

      expect(livedInFrame, isNot(orderedEquals(emptyFrame)));
    });
  });
}
