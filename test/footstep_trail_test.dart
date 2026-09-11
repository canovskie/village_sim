import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/characters/villager_type.dart';
import 'package:village_sim/entities/villager_entity.dart';
import 'package:village_sim/rendering/game_painter.dart';
import 'package:village_sim/systems/npc/footstep_trail.dart';
import 'package:village_sim/systems/world/road_system.dart';
import 'package:village_sim/world/season.dart';

void move(
  FootstepTrail trail,
  double x, {
  double dt = 0.1,
  bool moving = true,
  FootstepSurface? surface = FootstepSurface.dust,
}) => trail.update(dt, x: x, y: 3, moving: moving, surface: surface);

Future<Uint8List> render(VillagerEntity v, Season season) async {
  final recorder = ui.PictureRecorder();
  VillageGamePainter(
    villagers: [v],
    buildings: const [],
    pendingOrders: const [],
    roadSystem: RoadSystem(),
    camera: ui.Offset.zero,
    time: 1.5,
    season: season,
  ).paint(ui.Canvas(recorder), const ui.Size(480, 320));
  final picture = recorder.endRecording();
  final image = await picture.toImage(480, 320);
  picture.dispose();
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return bytes!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('basış mesafeyle doğar ve karakter ilerlerken dünyada sabit kalır', () {
    final trail = FootstepTrail();
    move(trail, 3);
    move(trail, 3.1);
    expect(trail.steps, isEmpty);
    move(trail, 3.6);
    final first = trail.steps.single;
    final position = (first.x, first.y);
    move(trail, 4.2);
    expect(trail.steps.length, 2);
    expect(trail.steps.last.left, !first.left);
    expect((first.x, first.y), position);
  });

  test('durma, sert yüzey, pause ve ışınlanma sahte basış üretmez', () {
    final trail = FootstepTrail();
    move(trail, 3);
    move(trail, 3.7, moving: false);
    move(trail, 4.4, surface: null);
    move(trail, 5, dt: 0);
    move(trail, 20);
    expect(trail.steps, isEmpty);
    move(trail, 20.6);
    expect(trail.steps.length, 1);
  });

  test('iz doğduğu malzemeyi korur, sayı sınırlıdır ve hepsi söner', () {
    final trail = FootstepTrail();
    move(trail, 3);
    move(trail, 3.6, surface: FootstepSurface.snow);
    move(trail, 4.2, surface: FootstepSurface.wet);
    expect(trail.steps.first.surface, FootstepSurface.snow);
    for (var i = 0; i < 60; i++) {
      move(trail, 4.8 + i * 0.6, dt: 0.01, surface: FootstepSurface.snow);
    }
    expect(trail.steps.length, lessThanOrEqualTo(12));
    move(trail, 50, dt: 4, moving: false);
    expect(trail.steps, isEmpty);
  });

  for (final surface in FootstepSurface.values) {
    test(
      '$surface izi gerçek dünya çiziminde görünür ve ömrü bitince silinir',
      () async {
        final v = VillagerEntity(
          type: VillagerType.farmer,
          name: 'İzci',
          male: true,
          startCol: 3,
          startRow: 3,
          visualSeed: 41,
        );
        final season = surface == FootstepSurface.snow
            ? Season.winter
            : Season.spring;
        final plain = await render(v, season);
        move(v.footstepTrail, 3, surface: surface);
        move(v.footstepTrail, 3.6, surface: surface);
        move(v.footstepTrail, 3.6, dt: 0.15, moving: false);
        final active = await render(v, season);
        expect(active, isNot(orderedEquals(plain)));
        move(v.footstepTrail, 3.6, dt: 4, moving: false);
        expect(await render(v, season), orderedEquals(plain));
      },
    );
  }
}
