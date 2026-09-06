import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/buildings/building_entity.dart';
import 'package:village_sim/buildings/building_type.dart';
import 'package:village_sim/characters/life_stage.dart';
import 'package:village_sim/characters/villager_type.dart';
import 'package:village_sim/entities/villager_entity.dart';
import 'package:village_sim/rendering/game_painter.dart';
import 'package:village_sim/systems/npc/villager_mind.dart';
import 'package:village_sim/systems/world/road_system.dart';
import 'package:village_sim/world/season.dart';

VillagerEntity _villager() => VillagerEntity(
  type: VillagerType.merchant,
  name: 'Durum Testi',
  male: true,
  startCol: 3,
  startRow: 3,
  ageDays: kAdultStartDay + 2,
  visualSeed: 17,
  personalitySeed: 17,
);

Future<Uint8List> _render({
  List<VillagerEntity> villagers = const [],
  List<BuildingEntity> buildings = const [],
  Season season = Season.spring,
}) async {
  const size = ui.Size(480, 320);
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  VillageGamePainter(
    villagers: villagers,
    buildings: buildings,
    pendingOrders: const [],
    roadSystem: RoadSystem(),
    camera: ui.Offset.zero,
    time: 1.25,
    dayLight: 1,
    rainIntensity: 0.8,
    season: season,
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

  test(
    'açlık, üşüme, silkelenme ve efor beden dilini görünür değiştirir',
    () async {
      final neutral = _villager();
      final neutralFrame = await _render(villagers: [neutral]);

      final hungry = _villager()..mind.setDrive(Drive.hunger, 1);
      expect(
        await _render(villagers: [hungry]),
        isNot(orderedEquals(neutralFrame)),
      );

      final cold = _villager()..mind.setDrive(Drive.chill, 1);
      expect(
        await _render(villagers: [cold], season: Season.winter),
        isNot(orderedEquals(neutralFrame)),
      );

      final wet = _villager()..wetShakeCue = 0.8;
      expect(
        await _render(villagers: [wet]),
        isNot(orderedEquals(neutralFrame)),
      );

      final tired = _villager()..markWorkFinished();
      expect(
        await _render(villagers: [tired]),
        isNot(orderedEquals(neutralFrame)),
      );
    },
  );

  test('ıslak köylü evin eşiğinde silkelenmeden içeri girmez', () {
    final v = _villager()
      ..sleepTarget = (3, 3)
      ..sleepIsHome = true;
    final rng = Random(4);

    v.update(0.1, 20, 20, rng, dayLight: 0, rainIntensity: 0.8);

    expect(v.wetShakeCue, greaterThan(0));
    expect(v.isInsideBuilding, isFalse);
    expect(v.state, VillagerState.walkingToSleep);

    for (var i = 0; i < 12; i++) {
      v.update(0.1, 20, 20, rng, dayLight: 0);
    }
    expect(v.isInsideBuilding, isTrue);
    expect(v.state, VillagerState.sleeping);
  });

  test('yük teslimi efor sonrası soluklanmayı başlatır', () {
    final v = _villager();
    final rng = Random(7);
    expect(v.assignCarryTask(Object(), 3, 3, 3, 3), isTrue);

    v.update(0.1, 20, 20, rng, dayLight: 1); // yükü alır
    v.update(0.1, 20, 20, rng, dayLight: 1); // aynı noktaya bırakır

    expect(v.state, VillagerState.idle);
    expect(v.exertionCue, greaterThan(0));
  });

  test('eve giriş kapıda kısa açılıp kapanma izi üretir', () async {
    final house = BuildingEntity(
      type: BuildingType.woodenHouse,
      col: 3,
      row: 4,
    );
    final closed = await _render(buildings: [house]);

    house.triggerDoorPulse(0.8);
    final open = await _render(buildings: [house]);

    expect(open, isNot(orderedEquals(closed)));
  });
}
