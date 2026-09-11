@Tags(['probe'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/main.dart';
import 'package:village_sim/ui/hud/hud.dart';
import 'package:village_sim/ui/hud/lesson_card.dart';
import 'package:village_sim/ui/hud/notification_plaque.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in const [
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
    messenger.setMockStreamHandler(
      const EventChannel('xyz.luan/audioplayers.global/events'),
      null,
    );
    kCaptureMode = true;
    kCaptureSceneReady = false;
    kProbeNoEvents = true;
    kProbeNoImperial = true;
    kProbeLessonsArmed = false;
    kProbeLessonsShown = 0;
    kProbeNewsArmed = false;
    kProbeNewsReset = false;
    kProbeNewsMessages.clear();
  });
  tearDown(() {
    kCaptureMode = false;
    kProbeNoEvents = false;
    kProbeNoImperial = false;
    kProbeNewsArmed = false;
    kProbeNewsReset = false;
    kProbeNewsMessages.clear();
    kProbeLessonsArmed = false;
    kDevSpeedBoostOverride = 0;
  });
  Future<void> run(WidgetTester tester, double seconds) async {
    for (var i = 0; i < (seconds * 1000 / 16).ceil(); i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  testWidgets(
    'gerçek yayın: işlem fişi, görünür süre, dört acil haber ve ders önceliği',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.runAsync(() async {
        await tester.pumpWidget(
          const MaterialApp(
            home: VillageScene(referenceVillage: true, slotId: 'newsProbe'),
          ),
        );
        for (var i = 0; i < 1200 && !kCaptureSceneReady; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 25));
        }
      });
      await tester.pump();
      expect(kCaptureSceneReady, isTrue);
      // Sim duraklıyken bile haberin gerçek okuma saati ilerlemeli.
      for (
        var i = 0;
        i < 5 && tester.widget<GameHUD>(find.byType(GameHUD)).timeScale != 0;
        i++
      ) {
        tester.widget<GameHUD>(find.byType(GameHUD)).onCycleSpeed();
        await tester.pump();
      }
      expect(tester.widget<GameHUD>(find.byType(GameHUD)).timeScale, 0);
      kProbeNewsArmed = true;
      kProbeNewsReset = true;
      kProbeNewsMessages.addAll(['👶 Ayşe doğdu.', 'Eksik malzeme: 10 🪵']);
      await run(tester, .2);
      NotificationPlaque plaque() =>
          tester.widget<NotificationPlaque>(find.byType(NotificationPlaque));
      expect(plaque().news.rawMessage, '👶 Ayşe doğdu.');
      expect(find.text('Eksik malzeme: 10 🪵'), findsOneWidget);
      await run(tester, 1);
      final beforePanel = plaque().remainingFraction!;
      expect(beforePanel, lessThan(1));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await run(tester, 2);
      expect(find.byType(NotificationPlaque), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await run(tester, .12);
      expect(plaque().remainingFraction!, closeTo(beforePanel, .04));
      // Arka plana gidip dönüş de haberin bütçesini tüketmemeli.
      final beforeBackground = plaque().remainingFraction!;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await run(tester, 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await run(tester, .12);
      expect(plaque().remainingFraction!, closeTo(beforeBackground, .05));

      kProbeNewsReset = true;
      kProbeNewsMessages.addAll(
        List.generate(4, (i) => 'Yangında $i numaralı köylü öldü.'),
      );
      await run(tester, .2);
      for (var i = 0; i < 4; i++) {
        expect(plaque().news.rawMessage, 'Yangında $i numaralı köylü öldü.');
        final duration = plaque().news.readDuration.inMilliseconds / 1000;
        final remaining = plaque().remainingFraction!;
        await run(tester, duration * remaining + .15);
      }
      expect(find.byType(NotificationPlaque), findsNothing);

      // Gerçek ders tetiği: öğreticiye haber bindirilmez, haber okuma saati bekler.
      tester.widget<GameHUD>(find.byType(GameHUD)).onCycleSpeed();
      await tester.pump();
      kProbeLessonsArmed = true;
      kDevSpeedBoostOverride = 24;
      for (
        var i = 0;
        i < 80 && find.byType(LessonCard).evaluate().isEmpty;
        i++
      ) {
        await run(tester, 1);
      }
      expect(find.byType(LessonCard), findsOneWidget);
      kProbeNewsReset = true;
      kProbeNewsMessages.add('🚪 Kaya Hanesi gitmeye hazırlanıyor.');
      await run(tester, 8);
      expect(find.byType(NotificationPlaque), findsNothing);
      tester.widget<LessonCard>(find.byType(LessonCard)).onClose();
      kProbeLessonsArmed = false;
      await run(tester, .2);
      expect(plaque().news.rawMessage, '🚪 Kaya Hanesi gitmeye hazırlanıyor.');
      expect(plaque().remainingFraction!, greaterThan(.95));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
