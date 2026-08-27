import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/main.dart';
import 'package:village_sim/systems/gameplay_pacing.dart';

/// İlk geceyi saf sabitlerle değil gerçek VillageScene tick zinciriyle ölçer.
/// Dünya referans köyden alınır, yalnız kuruluş anına geri sarılır; yatak serimi,
/// gece kenarı, NPC uykusu ve görev taraması üretim kodunun kendisidir.
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
    kCaptureTimeOfDay = -1;
    kCaptureSceneReady = false;
    kProbeOn = true;
    kProbeNoEvents = true;
    kProbeNoImperial = true;
    kProbeSaveError = '';
    kProbeWorldJson = '';
    kDevSpeedBoostOverride = 0;
  });

  tearDown(() {
    kCaptureMode = false;
    kCaptureTimeOfDay = -1;
    kProbeOn = false;
    kProbeNoEvents = false;
    kProbeNoImperial = false;
  });

  Future<void> boot(WidgetTester tester, Widget scene) async {
    kCaptureSceneReady = false;
    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(home: scene));
      for (var i = 0; i < 1200 && !kCaptureSceneReady; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
    });
    await tester.pump();
    expect(kCaptureSceneReady, isTrue, reason: 'sahne varlıkları yüklenemedi');
  }

  Future<Map<String, dynamic>> capture(WidgetTester tester) async {
    kProbeSaveRoundtrip = true;
    for (var i = 0; i < 60 && kProbeSaveRoundtrip; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(kProbeSaveError, '');
    return Map<String, dynamic>.from(
      jsonDecode(kProbeWorldJson) as Map<String, dynamic>,
    );
  }

  testWidgets('ilk gece gerçek sahnede 15 saniyeden önce sabaha bağlanır', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await boot(tester, const VillageScene(referenceVillage: true, slotId: ''));
    final source = await capture(tester);

    final buildings = (source['buildings'] as List).cast<Map>();
    final firepit = Map<String, dynamic>.from(
      buildings.firstWhere((b) => b['type'] == 'firepit'),
    );
    final founders = (source['villagers'] as List)
        .take(5)
        .map((raw) => Map<String, dynamic>.from(raw as Map))
        .toList();
    for (final v in founders) {
      v['home'] = -1;
      v['state'] = 'idle';
      v['targetCol'] = v['x'];
      v['targetRow'] = v['y'];
      v.remove('jobRole');
      v.remove('assignedRole');
      v.remove('assignedSite');
    }

    source
      ..['dayCount'] = 1
      ..['lastTimeOfDay'] = 0.45
      ..['timeOfDay'] = 0.45
      ..['timeScale'] = 1.0
      ..['speedIdx'] = 0
      ..['hasFire'] = true
      ..['firepit'] = 0
      ..['buildings'] = [firepit]
      ..['villagers'] = founders
      ..['orders'] = <Object>[]
      ..['reedBeds'] = <Object>[]
      ..['completedQuests'] = ['firepit']
      ..['charterTier'] = 0
      ..['firstReedBedShown'] = false
      ..['foundingFirstNightFastForwarded'] = false
      ..['foundingBedWorkElapsed'] = 0.0
      ..['foundingFirstNightWaitReal'] = 0.0
      ..['foundingTentsReadyDay'] = 0
      ..['foundingTentIllnessTriggered'] = false;

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await boot(tester, VillageScene(initialWorld: source, slotId: ''));

    final maxSteps = (GameplayPacing.maxEmptyRealSeconds / 0.05).ceil();
    for (var i = 0; i < maxSteps; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    final result = await capture(tester);
    final completed = (result['completedQuests'] as List).cast<String>();
    expect(
      completed,
      contains('firstNight'),
      reason: 'ilk gece 1× hızda 15 saniye içinde tamamlanmadı',
    );
    expect(result['dayCount'], greaterThanOrEqualTo(2));
    expect((result['reedBeds'] as List).length, founders.length);
    expect(tester.takeException(), isNull);
  });
}
