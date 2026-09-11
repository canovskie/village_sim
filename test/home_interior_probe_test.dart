@Tags(['probe'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/buildings/building_type.dart';
import 'package:village_sim/core/constants.dart';
import 'package:village_sim/main.dart';
import 'package:village_sim/rendering/game_painter.dart';
import 'package:village_sim/rendering/home_interior_painter.dart';
import 'package:village_sim/systems/npc/home_interior.dart';
import 'package:village_sim/text/voice.dart';
import 'package:village_sim/ui/hud/building_info_panel.dart';
import 'package:village_sim/ui/screens/home_interior_screen.dart';

void main() {
  testWidgets(
    'oyundaki ahşap eve tıklama içeri açılır, ev bilgileri ve geri dönüş çalışır',
    (tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      for (final channel in [
        'xyz.luan/audioplayers',
        'xyz.luan/audioplayers.global',
        'plugins.flutter.io/shared_preferences',
        'plugins.flutter.io/path_provider',
      ]) {
        messenger.setMockMethodCallHandler(
          MethodChannel(channel),
          (call) async => call.method == 'getAll' ? <String, Object>{} : null,
        );
      }
      const size = Size(1400, 900);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      kCaptureMode = true;
      kProbeOn = true;
      kCaptureSceneReady = false;
      kCaptureTimeOfDay = 0.45;
      kCaptureZoom = 0.8;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        kCaptureMode = false;
        kProbeOn = false;
        kCaptureTimeOfDay = -1;
        kCaptureZoom = 1;
      });
      await tester.runAsync(() async {
        await tester.pumpWidget(
          const MaterialApp(home: VillageScene(referenceVillage: true)),
        );
        for (int i = 0; i < 200 && !kCaptureSceneReady; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      });
      expect(kCaptureSceneReady, isTrue);
      await tester.pump(const Duration(milliseconds: 100));
      VillageGamePainter currentPainter() => tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<VillageGamePainter>()
          .single;
      var painter = currentPainter();
      final viewCenter = Offset(size.width / 2, size.height / 2);
      final house = painter.buildings.firstWhere(
        (b) => b.type == BuildingType.woodenHouse,
      );
      final initial = gridToScreen(
        house.col + 0.5,
        house.row + 0.5,
        size,
        painter.camera,
      );
      final screen = viewCenter + (initial - viewCenter) * painter.zoom;
      await tester.dragFrom(
        const Offset(800, 500),
        const Offset(600, 400) - screen,
      );
      await tester.pump();
      painter = currentPainter();
      final position = gridToScreen(
        house.col + 0.5,
        house.row + 0.5,
        size,
        painter.camera,
      );
      await tester.tapAt(viewCenter + (position - viewCenter) * painter.zoom);
      // Oyun kanvası tek/çift dokunuşu ayırır; tek dokunuş süresi dolsun.
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(HomeInteriorScreen), findsOneWidget);
      final interior = tester.widget<HomeInteriorScreen>(
        find.byType(HomeInteriorScreen),
      );
      expect(interior.demo, isFalse);
      final expectedSeed = HomeInteriorLayout.seedForHome(house.col, house.row);
      expect(interior.decorSeed, expectedSeed);
      HomeInteriorPainter roomPainter() =>
          tester
                  .widget<CustomPaint>(
                    find.byKey(const ValueKey('home-interior-canvas')),
                  )
                  .painter!
              as HomeInteriorPainter;
      final firstLayout = roomPainter().simulation.layout;
      expect(firstLayout.seed, expectedSeed);
      expect(
        interior.residents.every((v) => identical(v.homeBuilding, house)),
        isTrue,
      );
      await tester.tap(find.text(HomeInteriorVoice.manage));
      await tester.pump();
      expect(find.byType(BuildingInfoPanel), findsOneWidget);
      await tester.tap(find.text(HomeInteriorVoice.enter));
      await tester.pump();
      expect(find.byType(HomeInteriorScreen), findsOneWidget);
      expect(roomPainter().simulation.layout.seed, firstLayout.seed);
      expect(roomPainter().simulation.layout.planIndex, firstLayout.planIndex);
      expect(
        roomPainter().simulation.layout.item(InteriorFurnitureKind.table).x,
        firstLayout.item(InteriorFurnitureKind.table).x,
      );
      await tester.tap(find.byTooltip(HomeInteriorVoice.close));
      await tester.pump();
      expect(find.byType(HomeInteriorScreen), findsNothing);
      // Aynı gerçek köyde ikinci eve gir: ilk evin planı sızmamalı.
      painter = currentPainter();
      final other = painter.buildings.firstWhere(
        (b) => b.type == BuildingType.woodenHouse && !identical(b, house),
      );
      final otherInitial = gridToScreen(
        other.col + .5,
        other.row + .5,
        size,
        painter.camera,
      );
      final otherScreen =
          viewCenter + (otherInitial - viewCenter) * painter.zoom;
      await tester.dragFrom(
        const Offset(800, 500),
        const Offset(600, 400) - otherScreen,
      );
      await tester.pump();
      painter = currentPainter();
      final otherPosition = gridToScreen(
        other.col + .5,
        other.row + .5,
        size,
        painter.camera,
      );
      await tester.tapAt(
        viewCenter + (otherPosition - viewCenter) * painter.zoom,
      );
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(HomeInteriorScreen), findsOneWidget);
      final secondLayout = roomPainter().simulation.layout;
      expect(
        secondLayout.seed,
        HomeInteriorLayout.seedForHome(other.col, other.row),
      );
      expect(secondLayout.seed, isNot(firstLayout.seed));
      expect(
        secondLayout.furniture.map((f) => (f.x, f.y)).toList(),
        isNot(orderedEquals(firstLayout.furniture.map((f) => (f.x, f.y)))),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
