// flutter test test/atmosphere_preview_dump.dart → /tmp/village_atmosphere.png
// Gerçek painter/asset'lerle aynı kadrajı altı hava ve hareket anında çizer.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/buildings/building_entity.dart';
import 'package:village_sim/buildings/building_renderer.dart';
import 'package:village_sim/buildings/building_type.dart';
import 'package:village_sim/characters/villager_type.dart';
import 'package:village_sim/entities/villager_entity.dart';
import 'package:village_sim/rendering/game_painter.dart';
import 'package:village_sim/rendering/nature_renderer.dart';
import 'package:village_sim/rendering/snow_ground_renderer.dart';
import 'package:village_sim/rendering/tile_renderer.dart';
import 'package:village_sim/rendering/tree_renderer.dart';
import 'package:village_sim/systems/npc/footstep_trail.dart';
import 'package:village_sim/systems/world/road_system.dart';
import 'package:village_sim/world/day_night_cycle.dart';
import 'package:village_sim/world/nature_entity.dart';
import 'package:village_sim/world/season.dart';
import 'package:village_sim/world/tree_entity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('atmosfer temas sayfası', () async {
    final font = FontLoader('PreviewSpectral')
      ..addFont(rootBundle.load('assets/fonts/Spectral-Regular.ttf'));
    await font.load();
    await Future.wait([
      TileRenderer.loadAll(),
      TreeRenderer.loadAll(),
      BuildingRenderer.loadAll(),
      NatureRenderer.loadAll(),
      SnowGroundRenderer.loadAll(),
    ]);
    const size = Size(560, 360);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final views = [
      ('Gündüz · toz / kelebek', 0.45, 0.0, Season.spring, 0.15),
      ('Şafak · su üstü sis', 0.27, 0.0, Season.spring, 0.15),
      ('Gece · ateşböcekleri', 0.92, 0.0, Season.spring, 0.15),
      ('Yağmur · yüzeye temas', 0.45, 0.8, Season.spring, 0.15),
      ('Kış · basılan kar', 0.45, 0.0, Season.winter, 0.15),
      ('Kış · izlerin sönümü', 0.45, 0.0, Season.winter, 2.1),
    ];
    for (int i = 0; i < views.length; i++) {
      final (label, tod, rain, season, age) = views[i];
      final cycle = DayNightCycle(timeOfDay: tod);
      final v = VillagerEntity(
        type: VillagerType.farmer,
        name: 'İzci',
        male: true,
        startCol: 11,
        startRow: 14,
        visualSeed: 41,
      );
      final surface = season == Season.winter
          ? FootstepSurface.snow
          : rain > 0
          ? FootstepSurface.wet
          : FootstepSurface.dust;
      for (int j = 0; j < 5; j++) {
        v.footstepTrail.steps.add(
          Footstep(8.6 + j * 0.6, 14, 1, 0, j.isEven, surface)
            ..age = age + (4 - j) * 0.1,
        );
      }
      canvas.save();
      canvas.translate((i % 2) * size.width, (i ~/ 2) * size.height);
      canvas.clipRect(Offset.zero & size);
      VillageGamePainter(
        villagers: [v],
        buildings: [
          BuildingEntity(type: BuildingType.woodenHouse, col: 8, row: 9),
        ],
        pendingOrders: const [],
        roadSystem: RoadSystem(),
        camera: const Offset(15, -250),
        trees: [
          TreeEntity(col: 7, row: 12, type: TreeType.pine),
          TreeEntity(col: 14, row: 7, type: TreeType.pine),
        ],
        berryBushes: [BerryBush(col: 13, row: 7), BerryBush(col: 10, row: 16)],
        waterTiles: {
          for (int c = 16; c < 19; c++)
            for (int r = 0; r < 26; r++) (c, r),
        },
        groundVersion: i + 700,
        season: season,
        time: 8.4,
        timeOfDay: tod,
        dayLight: cycle.dayLight,
        overlayTop: cycle.overlayTop,
        overlayBottom: cycle.overlayBottom,
        ambientTint: cycle.ambientTint,
        ambientStrength: cycle.ambientStrength,
        rainIntensity: rain,
      ).paint(canvas, size);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 560, 27),
        Paint()..color = const Color(0xDD161C22),
      );
      final text = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontFamily: 'PreviewSpectral',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, const Offset(12, 6));
      text.dispose();
      canvas.restore();
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(1120, 1080);
    picture.dispose();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    await File(
      '/tmp/village_atmosphere.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
  });
}
