@Tags(['probe'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/main.dart';
import 'package:village_sim/systems/governance/petition_system.dart';

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
    kCaptureSceneReady = false;
    kProbeOn = true;
    kProbeNoEvents = true;
    kProbeNoImperial = true;
    kProbePetitionQueueArmed = true;
    kProbeRequestPetition = '';
    kProbeQueuedPetitions = '';
    kProbePendingPetition = '';
    kProbeAutoSlowed = false;
    kProbeDecideNow = false;
    kDevSpeedBoostOverride = 30;
  });

  tearDown(() {
    kCaptureMode = false;
    kProbeOn = false;
    kProbeNoEvents = false;
    kProbeNoImperial = false;
    kProbePetitionQueueArmed = false;
    kProbeRequestPetition = '';
    kProbeQueuedPetitions = '';
    kProbeDecideNow = false;
    kDevSpeedBoostOverride = 0;
  });

  Future<void> pumpUntil(
    WidgetTester tester,
    bool Function() condition, {
    int maxSteps = 300,
  }) async {
    for (var i = 0; i < maxSteps && !condition(); i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(condition(), isTrue);
  }

  testWidgets('sistem dilekçeleri aktif kararı ezmeden sıraya girer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.runAsync(() async {
      await tester.pumpWidget(
        const MaterialApp(
          home: VillageScene(referenceVillage: true, slotId: 'decisionQueue'),
        ),
      );
      for (var i = 0; i < 1200 && !kCaptureSceneReady; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
    });
    await tester.pump();
    expect(kCaptureSceneReady, isTrue);

    await tester.tap(find.text('1×'));
    await tester.pump();
    expect(find.text('2×'), findsWidgets);

    kProbeRequestPetition = PetitionIds.crimeWave;
    await pumpUntil(
      tester,
      () => kProbePendingPetition == PetitionIds.crimeWave,
    );
    expect(kProbeAutoSlowed, isTrue);
    expect(find.text('1×'), findsWidgets);
    expect(kProbePause, isEmpty);

    kProbeRequestPetition = PetitionIds.fireDied;
    await pumpUntil(
      tester,
      () => kProbeQueuedPetitions.contains(PetitionIds.fireDied),
    );
    expect(kProbePendingPetition, PetitionIds.crimeWave);

    kProbeDecideNow = true;
    await pumpUntil(
      tester,
      () => kProbePendingPetition == PetitionIds.fireDied,
      maxSteps: 600,
    );
    expect(kProbeQueuedPetitions, isEmpty);
    expect(kProbePause, isEmpty);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
