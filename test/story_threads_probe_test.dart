@Tags(['probe'])
library;

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/main.dart';
import 'package:village_sim/systems/events/story_threads.dart';
import 'package:village_sim/systems/run/village_year.dart';
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
    kDevSpeedBoostOverride = 12;
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

  testWidgets(
    'üç hikâye gerçek sıradan gelir, aynı yüzle yüklenir, geç yılda kapanır',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.runAsync(() async {
        await tester.pumpWidget(
          const MaterialApp(
            home: VillageScene(referenceVillage: true, slotId: ''),
          ),
        );
        for (var i = 0; i < 1200 && !kCaptureSceneReady; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 25));
        }
      });
      await tester.pump();
      expect(kCaptureSceneReady, isTrue);
      var base = await snapshot(tester);
      final people = base['villagers'] as List;
      // Gerçek köy, yalnız hikâyenin gerektirdiği kontrollü kadro: aynı haneden
      // iki yetişkin, farklı haneden bir komşu, bilgiyi taşıyan bir yapı ustası.
      people[0]['surname'] = 'Kaya';
      people[1]['surname'] = 'Kaya';
      people[2]['surname'] = 'Demir';
      people[0]['mastery'] = {'carpentry': 24.0};
      people[1]['mastery'] = <String, double>{};
      people[0]['isFavorite'] = true;
      people[1]['isFavorite'] = true;
      base['dayCount'] = 5;
      base['petitionTimer'] = 100000.0;
      await restore(tester, base);
      base = await snapshot(tester);

      for (final thread in StoryThread.values) {
        await restore(
          tester,
          jsonDecode(jsonEncode(base)) as Map<String, dynamic>,
        );
        final prefix = 'story.${thread.name}';
        kProbeRequestPetition = '$prefix.start';
        await until(tester, () => kProbePendingPetition == '$prefix.start');
        var world = await snapshot(tester);
        final cast = Map<String, dynamic>.from(
          (world['storyCasts'] as Map)[thread.name] as Map,
        );
        final author = world['petitionAuthor'];
        expect(cast['lead'], isNonNegative);
        expect(cast['partner'], isNonNegative);
        expect(cast['lead'], isNot(cast['partner']));
        // Açık mobil yüzey de gerçek metni, yer tutucusuz ve taşmadan göstermeli.
        world['petitionModalOpen'] = true;
        await restore(tester, world);
        expect(find.byType(PetitionModal), findsOneWidget);
        expect(tester.takeException(), isNull);
        // Ret dalını da sahnede yaşat; diğer ikisi kabul kolundan ilerler.
        await decide(tester, thread == StoryThread.accord ? 1 : 0);
        world = await snapshot(tester);
        if (thread == StoryThread.family) {
          expect(world['villageMemory'], contains('$prefix.planted'));
          expect(
            (world['decor'] as List).length,
            greaterThan((base['decor'] as List).length),
          );
        }
        if (thread == StoryThread.apprenticeship) {
          final meeting = jsonDecode(jsonEncode(world)) as Map<String, dynamic>;
          final pair = meeting['storyCasts'][thread.name];
          final live = meeting['villagers'] as List;
          final lead = live[pair['lead']];
          final student = live[pair['partner']];
          // Kalabalıktaki üçüncü kişilerin sohbeti çalması bu provanın konusu
          // değil. Çifti doğal niyet hakemine bırak, diğerlerini uzakta tut.
          for (final person in live) {
            if (identical(person, lead) || identical(person, student)) continue;
            person['x'] = 110.0;
            person['y'] = 110.0;
            person['targetCol'] = 110.0;
            person['targetRow'] = 110.0;
          }

          final oldMastery =
              (student['mastery']?[pair['craft']] as num?)?.toDouble() ?? 0;
          pair['lastMeetingDay'] = 0;
          meeting['timeOfDay'] = 0.5;
          meeting['lastTimeOfDay'] = 0.5;
          meeting['petitionTimer'] = 100000.0;
          for (final person in [lead, student]) {
            person['type'] = 'merchant';
            person['assignedRole'] = 'none';
            person.remove('jobRole');
            person['state'] = 'idle';
            person['opinion'] = [];
            person['targetCol'] = person['x'];
            person['targetRow'] = person['y'];
            person['sickDays'] = 0;
            person['injuryDays'] = 0;
            person['drives'] = {
              'company': 1.0,
              'hunger': 0.0,
              'fatigue': 0.0,
              'chill': 0.0,
              'unease': 0.0,
              'purpose': 0.0,
            };
          }
          student['x'] = (lead['x'] as num) + 1.0;
          student['y'] = lead['y'];
          kDevSpeedBoostOverride = 1;
          await restore(tester, meeting);
          await until(tester, () => kProbeStoryMeetingVisible, steps: 1500);
          final learned = await snapshot(tester);
          final learnedCast = learned['storyCasts'][thread.name];
          expect(learnedCast['lessons'], greaterThan(pair['lessons'] as int));
          final learnedPerson = learned['villagers'][learnedCast['partner']];
          expect(
            learnedPerson['mastery'][learnedCast['craft']],
            greaterThan(oldMastery),
          );
          // Aynı gün yeniden yüklemek ikinci ders vermez.
          final lessonCount = learnedCast['lessons'];
          for (var i = 0; i < 90; i++) {
            await tester.pump(const Duration(milliseconds: 16));
          }
          final again = await snapshot(tester);
          expect(again['storyCasts'][thread.name]['lessons'], lessonCount);
          kDevSpeedBoostOverride = 12;
          world = again;
        }
        final follow = (world['petitionFollowUps'] as List).singleWhere(
          (f) => f['id'].startsWith(prefix),
        );
        expect(follow['actor'], author);
        follow['fireAtSim'] = 0.0;
        world['petitionTimer'] = 100000.0;
        await restore(tester, world);
        final second =
            '$prefix.${thread == StoryThread.accord ? 'declined' : 'helped'}';
        await until(tester, () => kProbePendingPetition == second);
        world = await snapshot(tester);
        expect(world['petitionAuthor'], cast['lead']);
        expect(world['petitionExtra']['storyPartner'], cast['partnerName']);
        await decide(tester);
        world = await snapshot(tester);
        final finalLink = (world['petitionFollowUps'] as List).singleWhere(
          (f) => f['id'] == '$prefix.shared',
        );
        finalLink['fireAtSim'] = 0.0;
        world['dayCount'] = 6;
        world['petitionTimer'] = 100000.0;
        await restore(tester, world);
        for (var i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(kProbePendingPetition, isNot('$prefix.shared'));
        world = await snapshot(tester);
        expect(
          (world['petitionFollowUps'] as List).any(
            (f) => f['id'] == '$prefix.shared',
          ),
          isTrue,
        );
        world['dayCount'] =
            ((thread == StoryThread.accord ? kReckoningHeraldYear : 3) - 1) *
                kDaysPerYear +
            1;
        world['petitionTimer'] = 100000.0;
        await restore(tester, world);
        await until(tester, () => kProbePendingPetition == '$prefix.shared');
        await decide(tester);
        world = await snapshot(tester);
        expect(world['villageMemory'], contains('$prefix.done'));
        expect(
          (world['petitionFollowUps'] as List).where(
            (f) => f['id'].startsWith(prefix),
          ),
          isEmpty,
        );
      }

      // Aktör modal açıkken ayrılır: eski karar bedeli alınmaz ve yerine
      // rastgele birine aynı geçmiş giydirilmez.
      await restore(
        tester,
        jsonDecode(jsonEncode(base)) as Map<String, dynamic>,
      );
      kProbeRequestPetition = 'story.accord.start';
      await until(tester, () => kProbePendingPetition == 'story.accord.start');
      var lossWorld = await snapshot(tester);
      final originalLead = lossWorld['storyCasts']['accord']['leadName'];
      kProbeStoryDepartLead = 'story.accord.start';
      await until(tester, () => kProbeStoryDepartLead.isEmpty);
      await decide(tester);
      await until(tester, () => kProbePendingPetition == 'story.accord.loss');
      lossWorld = await snapshot(tester);
      expect(
        lossWorld['petitionExtra']['storyMissing'],
        contains(originalLead),
      );
      expect(find.byType(PetitionModal), findsOneWidget);
      await decide(tester, 1);
      lossWorld = await snapshot(tester);
      expect(lossWorld['villageMemory'], contains('story.accord.done'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
