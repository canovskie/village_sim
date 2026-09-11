@Tags(['probe'])
library;

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/main.dart';
import 'package:village_sim/systems/events/event_system.dart';
import 'package:village_sim/systems/governance/petition_system.dart';
import 'package:village_sim/ui/events/event_choice_modal.dart';
import 'package:village_sim/ui/events/petition_modal.dart';

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
    kProbeOn = true;
    kProbeNoEvents = true;
    kProbeNoImperial = true;
    kProbePetitionQueueArmed = true;
    kProbeRequestPetition = '';
    kProbePendingPetition = '';
    kProbeDecideNow = false;
    kProbeDecisionOption = 0;
    kProbeSaveRoundtrip = false;
    kProbeRestoreJson = '';
    kProbeStoryDepartLead = '';
    kProbeStoryMeetingVisible = false;
    kDevSpeedBoostOverride = 1;
    kProbeChoiceQueueArmed = true;
  });
  tearDown(() {
    kCaptureMode = false;
    kProbeOn = false;
    kProbeNoEvents = false;
    kProbeNoImperial = false;
    kProbePetitionQueueArmed = false;
    kProbeRequestPetition = '';
    kProbeDecideNow = false;
    kProbeDecisionOption = 0;
    kProbeSaveRoundtrip = false;
    kProbeRestoreJson = '';
    kProbeStoryDepartLead = '';
    kDevSpeedBoostOverride = 0;
    kProbeChoiceQueueArmed = false;
    kProbeTriggerEvent = false;
    kForcedEventId = '';
  });

  Future<void> until(
    WidgetTester tester,
    bool Function() check, {
    int steps = 900,
  }) async {
    for (var i = 0; i < steps && !check(); i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(
      check(),
      isTrue,
      reason:
          'pending=$kProbePendingPetition pause=$kProbePause error=$kProbeSaveError story=$kProbeStoryReport',
    );
  }

  Future<Map<String, dynamic>> snapshot(WidgetTester tester) async {
    kProbeSaveRoundtrip = true;
    await until(tester, () => !kProbeSaveRoundtrip);
    expect(kProbeSaveError, isEmpty);
    return jsonDecode(kProbeWorldJson) as Map<String, dynamic>;
  }

  Future<void> restore(WidgetTester tester, Map<String, dynamic> world) async {
    kProbeRestoreJson = jsonEncode(world);
    await until(tester, () => kProbeRestoreJson.isEmpty);
    expect(kProbeSaveError, isEmpty);
    await tester.pump(const Duration(milliseconds: 16));
  }

  Future<void> decide(WidgetTester tester, [int option = 0]) async {
    kProbeDecisionOption = option;
    kProbeDecideNow = true;
    await until(tester, () => !kProbeDecideNow);
    await tester.pump(const Duration(milliseconds: 16));
  }

  Future<Map<String, dynamic>> boot(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await tester.pumpWidget(
        const MaterialApp(
          home: VillageScene(
            referenceVillage: true,
            slotId: 'decisionIntegrity',
          ),
        ),
      );
      for (var i = 0; i < 1200 && !kCaptureSceneReady; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
    });
    await tester.pump();
    expect(kCaptureSceneReady, isTrue);
    final base = await snapshot(tester);
    base['petitionTimer'] = 100000.0;
    base['crisisCooldown'] = 100000.0;
    base['timeOfDay'] = .5;
    base['timeScale'] = 1.0;
    base['pendingPetition'] = null;
    base['pendingChoice'] = null;
    base['queuedPetition'] = null;
    base['pacedPetitions'] = [];
    base['pacedChoices'] = [];
    base.remove('decisionPacing');
    return base;
  }

  Map<String, dynamic> copy(Map<String, dynamic> base) =>
      jsonDecode(jsonEncode(base)) as Map<String, dynamic>;
  Map<String, dynamic> pending(Map<String, dynamic> base, String id) {
    final w = copy(base);
    w['pendingPetition'] = id;
    w['petitionAuthor'] = 0;
    w['petitionModalOpen'] = true;
    w['petitionDeadline'] = 480.0;
    w['petitionOverdue'] = false;
    return w;
  }

  testWidgets(
    'kaynak sınırı, kanunlar, kriz ve kişisel tercih gerçek sahnede korunur',
    (tester) async {
      final base = await boot(tester);
      final empty = pending(base, PetitionIds.crimeWave);
      (empty['stockpile'] as Map)['gold'] = 0;
      (empty['villageMemory'] as List).remove('crime.watch');
      (empty['policies'] as Map)['sealed'] = [];
      empty['crimeSuspicion'] = 3;
      await restore(tester, empty);
      expect(find.byType(EventChoiceModal), findsOneWidget);
      final modal = tester.widget<EventChoiceModal>(
        find.byType(EventChoiceModal),
      );
      expect(modal.blockedReason!(modal.event.choices!.first), isNotNull);
      // Bypass the disabled button to verify the engine itself refuses the cost.
      modal.onChoose(modal.event.choices!.first);
      var saved = await snapshot(tester);
      expect(saved['pendingPetition'], PetitionIds.crimeWave);
      expect(saved['villageMemory'], isNot(contains('crime.watch')));
      expect((saved['stockpile'] as Map)['gold'], 0);

      (empty['stockpile'] as Map)['gold'] = 8;
      await restore(tester, empty);
      await decide(tester);
      saved = await snapshot(tester);
      expect(saved['pendingPetition'], isNull);
      expect(saved['villageMemory'], contains('crime.watch'));
      expect((saved['stockpile'] as Map)['gold'], 0);

      // An autonomous council also has to live within the same budget.
      (empty['stockpile'] as Map)['gold'] = 0;
      (empty['policies'] as Map)['sealed'] = ['rejim.meclisDaimi'];
      empty['petitionDeadline'] = 0.01;
      await restore(tester, empty);
      await tester.pump(const Duration(milliseconds: 32));
      saved = await snapshot(tester);
      expect(saved['pendingPetition'], isNull);
      expect(saved['villageMemory'], isNot(contains('crime.watch')));
      expect(saved['villageMemory'], isNot(contains('crime.patrol')));
      expect(saved['crimeSuspicion'], 3);

      for (final laws in [
        <String>[],
        ['nizam.exile', 'nizam.labor', 'dergah.penance'],
      ]) {
        final w = pending(base, PetitionIds.crimeVerdict);
        (w['policies'] as Map)['sealed'] = laws;
        w['accusedCriminal'] = 0;
        await restore(tester, w);
        await snapshot(tester); // the actual capture -> JSON -> restore path
        await tester.pump();
        final p = tester
            .widget<PetitionModal>(find.byType(PetitionModal))
            .petition;
        expect(
          p.options.any((o) => o.fx == PetitionFx.crimeExile),
          laws.isNotEmpty,
        );
        expect(
          p.options.any((o) => o.fx == PetitionFx.crimeLabor),
          laws.isNotEmpty,
        );
        expect(
          p.options.any((o) => o.fx == PetitionFx.crimePenance),
          laws.isNotEmpty,
        );
      }

      for (final crisis in ['revolt', 'deadlock', 'idleness', 'inequality']) {
        final id = 'regime.crisis.$crisis';
        final w = pending(base, id);
        w['unrest'] = .8;
        (w['stockpile'] as Map)['gold'] = 100;
        await restore(tester, w);
        saved = await snapshot(tester);
        expect(saved['pendingPetition'], id);
        expect((await snapshot(tester))['pendingPetition'], id);
        await tester.pump();
        expect(find.byType(EventChoiceModal), findsOneWidget);
        await decide(tester);
        saved = await snapshot(tester);
        expect(saved['pendingPetition'], isNull);
        expect(saved['unrest'] as num, lessThan(.5));
      }

      final exile = pending(base, 'regime.crisis.revolt');
      (exile['policies'] as Map)['sealed'] = ['nizam.exile'];
      await restore(tester, exile);
      await decide(tester, 1);
      saved = await snapshot(tester);
      final leaving = (saved['villagers'] as List)
          .where((v) => (v as Map).containsKey('leavingTo'))
          .toList();
      expect(leaving, hasLength(1));
      final afterLoad = await snapshot(tester);
      expect(
        (afterLoad['villagers'] as List).where(
          (v) => (v as Map).containsKey('leavingTo'),
        ),
        hasLength(1),
      );

      final style = pending(base, PetitionIds.personalStyle);
      (style['villagers'] as List)[0]['wed'] = false;
      await restore(tester, style);
      expect(find.byType(PetitionModal), findsOneWidget);
      await decide(tester);
      saved = await snapshot(tester);
      expect((saved['villagers'] as List)[0]['avoidsMarriage'], isTrue);
      saved = await snapshot(tester);
      expect((saved['villagers'] as List)[0]['avoidsMarriage'], isTrue);
      saved.remove('decisionPacing');
      saved['pendingPetition'] = PetitionIds.villageWedding;
      saved['weddingCouple'] = [0, 1];
      saved['petitionDeadline'] = 480.0;
      await restore(tester, saved);
      expect(
        (await snapshot(tester))['pendingPetition'],
        isNull,
        reason: 'evlenmeme tercihi tanınmış kişi düğüne zorlanamaz',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'yeni köy olayları görünür, seçim kaydedilir ve zaman aşımı işler',
    (tester) async {
      final base = await boot(tester);
      kProbeNoEvents = false;
      kDevSpeedBoostOverride = 16;
      for (final event in EventSystem.events) {
        await restore(tester, copy(base));
        kForcedEventId = event.id;
        kProbeTriggerEvent = true;
        await until(tester, () => kProbeChoiceWaiting == event.id);
        expect(kProbeVignetteId, event.id);
        expect(kProbeVignetteCast, greaterThan(0));
        var saved = await snapshot(tester);
        expect(saved['pendingChoice'], event.id);
        expect((await snapshot(tester))['pendingChoice'], event.id);
        // Choosing the first intervention goes through the real UI callback.
        // Open the decision seal, whose callback is the normal player route.
        final seal = find.byWidgetPredicate((w) => w is PetitionSeal);
        expect(seal, findsWidgets);
        await tester.tap(seal.first);
        await tester.pump();
        final modal = tester.widget<EventChoiceModal>(
          find.byType(EventChoiceModal),
        );
        modal.onChoose(modal.event.choices!.first);
        saved = await snapshot(tester);
        expect(saved['pendingChoice'], isNull);
        expect(saved['governanceAftermath'], isNotEmpty);
        final stored = saved['governanceAftermath'] as List;
        expect((await snapshot(tester))['governanceAftermath'], stored);

        // Same event, no answer: only the passive branch may be applied.
        final timeout = copy(base);
        timeout['pendingChoice'] = event.id;
        timeout['choiceDeadline'] = .01;
        timeout['choiceGrace'] = 24.0;
        final oldTimeouts = kProbeChoiceTimeouts;
        await restore(tester, timeout);
        await until(tester, () => kProbeChoiceTimeouts > oldTimeouts);
        saved = await snapshot(tester);
        expect(saved['pendingChoice'], isNull);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
