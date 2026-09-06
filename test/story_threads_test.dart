import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/systems/events/story_threads.dart';
import 'package:village_sim/systems/governance/petition_system.dart';
import 'package:village_sim/systems/run/village_year.dart';

void main() {
  test('her seçim yolu üçüncü karşılaşmada biter; ret farklı devam açar', () {
    for (final thread in StoryThread.values) {
      final opening = PetitionSystem.requireById(
        StoryThreads.id(thread, 'start'),
      );
      expect(
        opening.options[0].followUpId,
        isNot(opening.options[1].followUpId),
      );
      for (final first in opening.options) {
        final second = PetitionSystem.requireById(first.followUpId!);
        expect(
          second.options[0].followUpId,
          isNot(second.options[1].followUpId),
        );
        for (final choice in second.options) {
          final last = PetitionSystem.requireById(choice.followUpId!);
          for (final ending in last.options) {
            expect(ending.followUpId, isNull);
            expect(ending.setsFlags, contains(StoryThreads.id(thread, 'done')));
          }
        }
      }
    }
  });

  test('kadro olmadan başlangıç yok, başladıktan sonra tekrar yok', () {
    for (final thread in StoryThread.values) {
      expect(StoryThreads.canStart(thread, {}, {}), isFalse);
      expect(StoryThreads.canStart(thread, {}, {thread}), isTrue);
      expect(
        StoryThreads.canStart(
          thread,
          {StoryThreads.id(thread, 'started')},
          {thread},
        ),
        isFalse,
      );
    }
  });

  test('rastgele havuz yalnız açılışları seçebilir', () {
    const context = PetitionContext(
      population: 20,
      adults: 15,
      food: 100,
      gold: 100,
      morale: 0.5,
      hasChurch: true,
      storyCasts: {
        StoryThread.family,
        StoryThread.apprenticeship,
        StoryThread.accord,
      },
    );
    final seen = <StoryThread>{};
    for (var seed = 0; seed < 500; seed++) {
      final p = PetitionSystem.roll(context, Random(seed));
      final thread = StoryThreads.threadOf(p?.id ?? '');
      if (thread == null) continue;
      seen.add(thread);
      expect(StoryThreads.isOpening(p!.id), isTrue);
    }
    expect(seen, containsAll(StoryThread.values));
  });

  test('geç karşılaşma yıl kapısını bekler; kayıp kapıyı beklemez', () {
    for (final thread in StoryThread.values) {
      final id = StoryThreads.id(thread, 'shared');
      final year = thread == StoryThread.accord ? kReckoningHeraldYear : 3;
      expect(StoryThreads.ready(id, (year - 1) * kDaysPerYear), isFalse);
      expect(StoryThreads.ready(id, (year - 1) * kDaysPerYear + 1), isTrue);
      final lossId = StoryThreads.chapterForCast(id, intact: false);
      expect(StoryThreads.ready(lossId, 1), isTrue);
      final loss = PetitionSystem.requireById(lossId);
      for (final option in loss.options) {
        expect(option.followUpId, isNull);
        expect([
          option.foodDelta,
          option.woodDelta,
          option.goldDelta,
          option.stoneDelta,
          option.ironDelta,
        ], everyElement(0));
        expect(option.setsFlags, contains(StoryThreads.id(thread, 'done')));
      }
    }
  });

  test(
    'kayıt aynı nesnelere bağlanır; eksilen kişi aynı adlı birine dönüşmez',
    () {
      final people = [Object(), Object(), Object()];
      final cast = StoryCast(
        lead: people[0],
        partner: people[1],
        leadName: 'Ali',
        partnerName: 'Ali',
        craft: 'carpentry',
        lastMeetingDay: 9,
        lessons: 3,
      );
      final json =
          jsonDecode(
                jsonEncode(
                  cast.toJson(
                    (person) => person == null ? -1 : people.indexOf(person),
                  ),
                ),
              )
              as Map<String, dynamic>;
      final restored = StoryCast.fromJson(
        json,
        (i) => i >= 0 ? people[i] : null,
      );
      expect(restored.lead, same(people[0]));
      expect(restored.partner, same(people[1]));
      expect(restored.lastMeetingDay, 9);
      expect(restored.lessons, 3);
      json['lead'] = -1;
      final missing = StoryCast.fromJson(
        json,
        (i) => i >= 0 ? people[i] : null,
      );
      expect(missing.lead, isNull);
      expect(missing.leadName, 'Ali');
      expect(missing.partner, same(people[1]));
    },
  );
}
