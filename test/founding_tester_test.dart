import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/main.dart' as game;

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
      messenger.setMockMethodCallHandler(MethodChannel(channel), (call) async {
        if (call.method == 'getAll') return <String, Object>{};
        return null;
      });
    }
    messenger.setMockStreamHandler(
      const EventChannel('xyz.luan/audioplayers.global/events'),
      null,
    );

    game.kCaptureMode = true;
    game.kFoundingTesterMode = true;
    game.kCaptureSceneReady = false;
    game.kCaptureShowcase = false;
  });

  tearDown(() {
    game.kCaptureMode = false;
    game.kFoundingTesterMode = false;
    game.kCaptureSceneReady = false;
  });

  testWidgets(
    'gözlem paneli state gösterir, gizlenir ve taze koşuyu doğrular',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: game.VillageScene(onRestartRun: () {}, slotId: ''),
          ),
        );
        for (var i = 0; i < 1200 && !game.kCaptureSceneReady; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      });
      await tester.pump();

      expect(game.kCaptureSceneReady, isTrue);
      expect(find.text('DOĞAL KURULUŞ TESTER'), findsOneWidget);
      expect(
        find.text('Sabit tohum yok · otomasyon yok · ekonomi/AI doğal'),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Gözlem panelini gizle'));
      await tester.pump();
      expect(find.text('DOĞAL KURULUŞ TESTER'), findsNothing);

      await tester.tap(find.byTooltip('Gözlem panelini aç'));
      await tester.pump();
      await tester.tap(find.text('TAZE KOŞU'));
      // Sahnenin ticker'ı doğal olarak sürekli frame üretir; settle beklemek
      // tester'ın tam da canlı olma sözleşmesi yüzünden hiç bitmez.
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Taze doğal koşu'), findsOneWidget);
      expect(find.text('BAŞTAN BAŞLAT'), findsOneWidget);
    },
  );
}
