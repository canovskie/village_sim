import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/cutscene/cutscene_player.dart';
import 'package:village_sim/main.dart';
import 'package:village_sim/ui/command_bar.dart';

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
    kCaptureMode = true;
    kCaptureFoundingCouncil = true;
    kProbeOn = false;
    kDevSpeedBoostOverride = 0;
    kCaptureSceneReady = false;
  });

  tearDown(() {
    kCaptureFoundingCouncil = false;
    kCaptureMode = false;
  });

  testWidgets('kurucular halka olmadan başlangıç soruları açılmaz', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.runAsync(() async {
      await tester.pumpWidget(
        const MaterialApp(home: VillageScene(slotId: 'foundingCouncilTest')),
      );
      for (var i = 0; i < 1200 && !kCaptureSceneReady; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
    });
    await tester.pump();
    expect(kCaptureSceneReady, isTrue, reason: 'sahne varlıkları yüklenemedi');

    // İlk kare canlı dünyadır: sorular ve oyun komutları halka kurulana kadar
    // kapalıdır.
    expect(find.byType(CutscenePlayer), findsNothing);
    expect(find.byType(CommandBar), findsNothing);

    for (
      var i = 0;
      i < 1200 && find.byType(CutscenePlayer).evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(
      find.byType(CutscenePlayer),
      findsOneWidget,
      reason: 'kafile merkeze varıp halka olduğunda sorular açılmalı',
    );
    expect(tester.takeException(), isNull);
  });
}
