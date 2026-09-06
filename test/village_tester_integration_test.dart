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
    game.kCaptureShowcase = false;
    game.kFoundingTesterMode = false;
    game.kVillageTesterMode = true;
    game.kCaptureSceneReady = false;
    game.kCaptureVisitorReport = '';
  });

  tearDown(() {
    game.kCaptureMode = false;
    game.kVillageTesterMode = false;
    game.kCaptureSceneReady = false;
    game.kCaptureVisitorReport = '';
  });

  testWidgets('canlı tester gerçek VillageScene üzerinde açılır ve gizlenir', (
    tester,
  ) async {
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
    expect(find.text('CANLI KÖY TESTER'), findsOneWidget);
    expect(find.text('Doğal koşu · hazır köy yok'), findsOneWidget);
    expect(find.textContaining('Showcase Köyü'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('village-tester-hide')));
    await tester.pump();
    expect(find.text('CANLI KÖY TESTER'), findsNothing);
    expect(find.byKey(const ValueKey('village-tester-open')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('village-tester-open')));
    await tester.pump();
    await tester.tap(find.text('Dünya'));
    await tester.pump();
    await tester.tap(find.text('12×'));
    await tester.pump();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('village-tester-speed')),
        matching: find.text('12×'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Eylem'));
    await tester.pump();
    await tester.tap(find.text('Kervan'));
    await tester.pump();

    expect(find.text('CANLI KÖY TESTER'), findsNothing);
    expect(game.kCaptureVisitorReport, contains('cart=('));
    expect(game.kCaptureVisitorReport, isNot(contains('cart=-')));
  });
}
