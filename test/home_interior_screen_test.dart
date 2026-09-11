import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/characters/life_stage.dart';
import 'package:village_sim/characters/villager_type.dart';
import 'package:village_sim/entities/villager_entity.dart';
import 'package:village_sim/rendering/home_interior_painter.dart';
import 'package:village_sim/systems/npc/home_interior.dart';
import 'package:village_sim/text/voice.dart';
import 'package:village_sim/tools/home_interior_main.dart';
import 'package:village_sim/ui/screens/home_interior_screen.dart';

List<VillagerEntity> residents() => [
  VillagerEntity(
    type: VillagerType.farmer,
    name: 'Elif',
    male: false,
    startCol: 1,
    startRow: 1,
    visualSeed: 23,
    ageDays: kAdultStartDay + 2,
  ),
  VillagerEntity(
    type: VillagerType.miller,
    name: 'Yusuf',
    male: true,
    startCol: 1,
    startRow: 1,
    visualSeed: 51,
    ageDays: kAdultStartDay + 2,
  ),
];

HomeInteriorPainter painter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.byKey(const ValueKey('home-interior-canvas')),
            )
            .painter!
        as HomeInteriorPainter;

void main() {
  testWidgets(
    'yerleşim düğmesi altı planı telefonda açar; tarz ve senaryo korunur',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final size in [const Size(896, 414), const Size(390, 844)]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          MaterialApp(
            home: HomeInteriorScreen(residents: residents(), demo: true),
          ),
        );
        await tester.tap(find.byKey(const ValueKey('interior-style')));
        await tester.pump();
        painter(tester).simulation.setScenario(InteriorScenario.sleep);
        final people = painter(tester).residents;
        for (int i = 1; i <= HomeInteriorLayout.planCount; i++) {
          final before = painter(tester).simulation.time;
          await tester.tap(find.byKey(const ValueKey('interior-layout')));
          await tester.pump();
          final p = painter(tester);
          expect(
            p.simulation.layout.planIndex,
            i % HomeInteriorLayout.planCount,
          );
          expect(p.style, InteriorStyle.botanical);
          expect(p.simulation.scenario, InteriorScenario.sleep);
          expect(p.simulation.time, before);
          expect(identical(p.residents, people), isTrue);
          expect(
            find.text(
              HomeInteriorVoice.layout(i % HomeInteriorLayout.planCount),
            ),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  test(
    'altı yerleşimin görsel karşılaştırması ve yeni konumdan eşya seçimi',
    () async {
      final recorder = ui.PictureRecorder(), people = residents();
      final canvas = Canvas(recorder);
      for (int plan = 0; plan < HomeInteriorLayout.planCount; plan++) {
        final layout = HomeInteriorLayout.fromSeed(73, plan: plan);
        final simulation = HomeInteriorSimulation(layout: layout)
          ..setScenario(InteriorScenario.supper);
        for (int i = 0; i < 35; i++) {
          simulation.update(1);
        }
        final frameRecorder = ui.PictureRecorder();
        HomeInteriorPainter(
          simulation: simulation,
          residents: people,
          style: InteriorStyle.values[plan % 3],
        ).paint(Canvas(frameRecorder), const Size(820, 540));
        final picture = frameRecorder.endRecording();
        final image = await picture.toImage(820, 540);
        picture.dispose();
        canvas.drawImage(
          image,
          Offset((plan % 3) * 820.0, (plan ~/ 3) * 540.0),
          Paint(),
        );
        image.dispose();
        final table = layout.item(InteriorFurnitureKind.table);
        expect(
          HomeInteriorPainter.hitFurniture(
            HomeInteriorPainter.project(
              table.x + table.width / 2,
              table.y + table.depth / 2,
              34,
            ),
            HomeInteriorPainter.logicalSize,
            layout: layout,
          ),
          same(table),
        );
      }
      final picture = recorder.endRecording();
      final image = await picture.toImage(2460, 1080);
      picture.dispose();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      await File(
        '/tmp/home_interior_layouts.png',
      ).writeAsBytes(data!.buffer.asUint8List());
    },
  );

  testWidgets('döşemeler mobilde değiştirilir, NPC ve zaman sıfırlanmaz', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(896, 414);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: HomeInteriorScreen(residents: residents(), demo: true)),
    );
    final simulation = painter(tester).simulation;
    await tester.pump(const Duration(milliseconds: 100));
    final before = simulation.actors.first.position;
    for (final style in [
      InteriorStyle.botanical,
      InteriorStyle.woven,
      InteriorStyle.cottage,
    ]) {
      await tester.tap(find.byKey(const ValueKey('interior-style')));
      await tester.pump();
      expect(painter(tester).style, style);
      expect(identical(painter(tester).simulation, simulation), isTrue);
      expect(simulation.actors.first.position, before);
      expect(find.text(HomeInteriorVoice.style(style.index)), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('oyundaki döşeme ev tohumundan aynı kalır', (tester) async {
    for (int i = 0; i < 2; i++) {
      await tester.pumpWidget(
        MaterialApp(
          home: HomeInteriorScreen(residents: residents(), decorSeed: 77),
        ),
      );
      expect(painter(tester).style, InteriorStyle.fromSeed(77));
      expect(painter(tester).simulation.layout.seed, 77);
      expect(
        painter(tester).simulation.layout.planIndex,
        HomeInteriorLayout.fromSeed(77).planIndex,
      );
      expect(find.byKey(const ValueKey('interior-style')), findsNothing);
      await tester.pumpWidget(const SizedBox());
    }
  });

  test('üç döşemenin gündüz ve gece görsel karşılaştırması', () async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final people = residents();
    final frames = <List<int>>[];
    for (final style in InteriorStyle.values) {
      for (int night = 0; night < 2; night++) {
        final simulation = HomeInteriorSimulation()
          ..setScenario(
            night == 0 ? InteriorScenario.supper : InteriorScenario.sleep,
          );
        for (int i = 0; i < 30; i++) {
          simulation.update(1);
        }
        final frameRecorder = ui.PictureRecorder();
        HomeInteriorPainter(
          simulation: simulation,
          residents: people,
          style: style,
          daylight: night == 0 ? 1 : .12,
        ).paint(Canvas(frameRecorder), const Size(820, 540));
        final picture = frameRecorder.endRecording();
        final image = await picture.toImage(820, 540);
        picture.dispose();
        if (night == 0) {
          final data = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          frames.add(data!.buffer.asUint8List());
        }
        canvas.drawImage(
          image,
          Offset(style.index * 820.0, night * 540.0),
          Paint(),
        );
        image.dispose();
      }
    }
    for (int i = 0; i < frames.length; i++) {
      for (int j = i + 1; j < frames.length; j++) {
        expect(frames[i], isNot(orderedEquals(frames[j])));
      }
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(2460, 1080);
    picture.dispose();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    await File(
      '/tmp/home_interior_styles.png',
    ).writeAsBytes(data!.buffer.asUint8List());
  });

  test('yeni zemin eşyaları dokunarak seçilir', () {
    for (final f in HomeInteriorLayout.standard.furniture.where(
      (f) => [
        InteriorFurnitureKind.planter,
        InteriorFurnitureKind.basket,
        InteriorFurnitureKind.firewood,
      ].contains(f.kind),
    )) {
      final p = HomeInteriorPainter.project(
        f.x + f.width / 2,
        f.y + f.depth / 2,
        6,
      );
      expect(
        HomeInteriorPainter.hitFurniture(p, HomeInteriorPainter.logicalSize),
        same(f),
      );
    }
  });

  testWidgets(
    'bağımsız giriş doğrudan hazır eve açılır ve çıkıp tekrar girilir',
    (tester) async {
      await tester.pumpWidget(const HomeInteriorDemoApp());
      expect(find.byType(HomeInteriorScreen), findsOneWidget);
      expect(painter(tester).residents.length, 2);
      await tester.tap(find.byTooltip(HomeInteriorVoice.outside));
      await tester.pump();
      expect(find.byType(HomeInteriorScreen), findsNothing);
      await tester.tap(find.byKey(const ValueKey('interior-enter')));
      await tester.pump();
      expect(find.byType(HomeInteriorScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'hazır oda senaryoları çalışır, durur, sıfırlanır; mobilde taşmaz',
    (tester) async {
      tester.view.physicalSize = const Size(896, 414);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: HomeInteriorScreen(residents: residents(), demo: true),
        ),
      );
      expect(
        find.byKey(const ValueKey('home-interior-canvas')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('interior-sleep')));
      for (int i = 0; i < 220; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        painter(tester).simulation.actors.every(
          (a) => a.activity == InteriorActivity.sleeping,
        ),
        isTrue,
      );
      final pause = find.byKey(const ValueKey('interior-pause'));
      await tester.scrollUntilVisible(
        pause,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(pause);
      await tester.pump();
      await tester.tap(pause);
      await tester.pump();
      final time = painter(tester).simulation.time;
      await tester.pump(const Duration(milliseconds: 500));
      expect(painter(tester).simulation.time, time);
      final reset = find.byKey(const ValueKey('interior-reset'));
      await tester.scrollUntilVisible(
        reset,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(reset);
      await tester.pump();
      await tester.tap(reset);
      await tester.pump();
      expect(painter(tester).simulation.scenario, InteriorScenario.daily);
      expect(painter(tester).simulation.time, lessThan(1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'canlı ev aynı NPC kimliğini kullanır ve dışarıdaki kişiyi çizmez',
    (tester) async {
      final people = residents();
      people.first
        ..isInsideBuilding = true
        ..sleepIsHome = true
        ..state = VillagerState.sleeping;
      final outsideBefore = (
        people.last.gridX,
        people.last.gridY,
        people.last.state,
      );
      await tester.pumpWidget(
        MaterialApp(home: HomeInteriorScreen(residents: people)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(identical(painter(tester).residents.first, people.first), isTrue);
      expect(
        painter(tester).simulation.actors.first.activity,
        InteriorActivity.sleeping,
      );
      expect(painter(tester).simulation.actors.last.present, isFalse);
      expect((
        people.last.gridX,
        people.last.gridY,
        people.last.state,
      ), outsideBefore);
      people.first.isInsideBuilding = false;
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        painter(tester).simulation.actors.every((a) => !a.present),
        isTrue,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  test('sofra, uyku ve gece aynı oda painterında farklı görünür', () async {
    final people = residents();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final frames = <List<int>>[];
    for (final (index, scenario) in [
      InteriorScenario.supper,
      InteriorScenario.sleep,
    ].indexed) {
      final room = HomeInteriorSimulation()..setScenario(scenario);
      for (int i = 0; i < 25; i++) {
        room.update(1);
      }
      final frameRecorder = ui.PictureRecorder();
      HomeInteriorPainter(
        simulation: room,
        residents: people,
        daylight: index == 0 ? 1 : 0.12,
      ).paint(Canvas(frameRecorder), const Size(820, 540));
      final picture = frameRecorder.endRecording();
      final image = await picture.toImage(820, 540);
      picture.dispose();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      frames.add(bytes!.buffer.asUint8List());
      canvas.drawImage(image, Offset(0, index * 540), Paint());
      image.dispose();
    }
    expect(frames.first, isNot(orderedEquals(frames.last)));
    final sheet = recorder.endRecording();
    final image = await sheet.toImage(820, 1080);
    sheet.dispose();
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    await File(
      '/tmp/home_interior_poses.png',
    ).writeAsBytes(png!.buffer.asUint8List());
  });
}
