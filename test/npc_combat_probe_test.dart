import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/main.dart';

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
    kProbeOn = false;
    kProbeNoImperial = true;
    kProbeStartNpcBrawl = false;
    kProbeNpcCombatPairs = 0;
    kProbeNpcCombatContactSeen = false;
    kCaptureMode = false;
    kDevSpeedBoostOverride = 0;
  });

  testWidgets('NPC kavgası gerçek sahnede eşleşir ve temas eder', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    kCaptureMode = true;
    kProbeOn = true;
    kCaptureSceneReady = false;
    await tester.runAsync(() async {
      await tester.pumpWidget(
        const MaterialApp(
          home: VillageScene(referenceVillage: true, slotId: 'npc-combat'),
        ),
      );
      for (var i = 0; i < 400 && !kCaptureSceneReady; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });
    expect(kCaptureSceneReady, isTrue);

    kProbeStartNpcBrawl = true;
    for (var i = 0; i < 300 && kProbeNpcCombatPairs == 0; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(kProbeNpcCombatPairs, 1, reason: 'dövüşçüler sahnede eşleşmedi');

    for (var i = 0; i < 300 && !kProbeNpcCombatContactSeen; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(
      kProbeNpcCombatContactSeen,
      isTrue,
      reason: 'eşleşen NPC’ler hiçbir fiziksel temas karesine girmedi',
    );

    kProbeOn = false;
    await tester.pumpWidget(const SizedBox());
  });
}
