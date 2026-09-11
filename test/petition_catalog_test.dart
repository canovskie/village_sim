import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/systems/governance/petition_system.dart';
import 'package:village_sim/text/voice.dart';
import 'package:village_sim/world/season.dart';

const _smallVillage = PetitionContext(
  population: 6,
  adults: 4,
  food: 24,
  gold: 12,
  morale: 0.55,
  hasChurch: false,
  unwedAdultMen: 1,
);

String _optionFingerprint(PetitionOption option) {
  final process = option.process;
  return [
    option.foodDelta,
    option.woodDelta,
    option.stoneDelta,
    option.ironDelta,
    option.goldDelta,
    option.moraleAmount,
    option.moraleDays,
    option.fx,
    option.actorEffect,
    option.action,
    option.unrestDelta,
    option.presence,
    option.followUpId,
    option.setsFlags.join(','),
    option.clearsFlags.join(','),
    [
      for (final (estate, delta) in option.estateMood) '$estate:$delta',
    ].join(','),
    process?.kind,
    process?.durationDays,
    process?.foodOnComplete,
    process?.woodOnComplete,
    process?.stoneOnComplete,
    process?.ironOnComplete,
    process?.goldOnComplete,
  ].join('|');
}

void main() {
  final petitions = PetitionSystem.all;
  final gates = PetitionSystem.gatesForTest;

  group('dilekçe kataloğu sözleşmesi', () {
    test('kimlikler tekil ve sistem bağımlılıkları eksiksiz', () {
      final ids = petitions.map((petition) => petition.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
      expect(ids.toSet(), containsAll(PetitionIds.systemDriven));

      for (final id in PetitionIds.systemDriven) {
        expect(PetitionSystem.requireById(id).id, id);
      }
      expect(
        () => PetitionSystem.requireById('missing.petition'),
        throwsStateError,
      );
    });

    test('yalnız sahnenin çağırdığı kararlar rastgele havuza girmez', () {
      for (final id in PetitionIds.directOnly) {
        final gate = gates.singleWhere((entry) => entry.petition.id == id);
        expect(gate.weight, 0, reason: '$id rastgele ağırlık taşıyor');
        expect(gate.canFire(_smallVillage), isFalse);
      }

      for (var seed = 0; seed < 250; seed++) {
        final rolled = PetitionSystem.roll(_smallVillage, Random(seed));
        expect(PetitionIds.directOnly.contains(rolled?.id), isFalse);
      }
    });

    test('metin, şık ve takip bağları yapısal olarak tamam', () {
      final ids = petitions.map((petition) => petition.id).toSet();
      for (final petition in petitions) {
        expect(petition.id.trim(), isNotEmpty);
        expect(petition.title.trim(), isNotEmpty, reason: petition.id);
        expect(petition.petitioner.trim(), isNotEmpty, reason: petition.id);
        expect(petition.bodyPool, isNotEmpty, reason: petition.id);
        expect(petition.options.length, greaterThanOrEqualTo(2));

        for (final option in petition.options) {
          expect(option.label.trim(), isNotEmpty, reason: petition.id);
          expect(option.detail.trim(), isNotEmpty, reason: petition.id);
          expect(option.resolutionPool, isNotEmpty, reason: petition.id);
          if (option.followUpId case final followUp?) {
            expect(ids, contains(followUp));
            expect(option.followUpDelayDays, greaterThan(0));
          }
          if (option.process case final process?) {
            expect(process.durationDays, greaterThan(0));
            expect(process.title.trim(), isNotEmpty);
            expect(process.departureText.trim(), isNotEmpty);
            expect(process.completionText.trim(), isNotEmpty);
            expect(process.completionAnnal.trim(), isNotEmpty);
          }
        }
      }
    });

    test('aynı dilekçedeki iki şık aynı mekanik sonucu vermez', () {
      for (final petition in petitions) {
        final fingerprints = <String>{};
        for (final option in petition.options) {
          expect(
            fingerprints.add(_optionFingerprint(option)),
            isTrue,
            reason: '${petition.id}/${option.label}: yinelenen karar sonucu',
          );
        }
      }
    });

    test('oyuncu metinlerinde em dash bulunmaz', () {
      for (final petition in petitions) {
        final texts = <String>[
          petition.petitioner,
          petition.title,
          ...petition.bodyPool,
          ?petition.note,
          ?petition.stakes,
          for (final option in petition.options) ...[
            option.label,
            option.detail,
            ...option.resolutionPool,
            ...option.annalPool,
          ],
        ];
        expect(
          texts.where((text) => text.contains('—')),
          isEmpty,
          reason: petition.id,
        );
      }
    });
  });

  test('kuruluş odun kararı yalnız ilk kademede oyuncu hükmü ister', () {
    expect(petitionRequiresPlayerVerdict(PetitionIds.woodLow, 0), isTrue);
    expect(petitionRequiresPlayerVerdict(PetitionIds.woodLow, 1), isFalse);
    expect(petitionRequiresPlayerVerdict(PetitionIds.fireDied, 0), isFalse);
  });

  test('her metin varyantı konuşma bağlamıyla tamamen dokunur', () {
    for (final raw in petitions) {
      for (var seed = 0; seed < 12; seed++) {
        final spoken = raw.spoken(
          VoiceCtx(
            seed: seed,
            name: 'İlyas',
            other: 'Ayşe',
            profession: 'Demirci',
            house: 'Karaoğlan',
            estate: 'Emekçiler',
            village: 'Bahçeköy',
            season: Season.winter,
            day: 41,
            extra: const {
              'suçlu': 'Mehmet',
              'suç': 'hırsızlık',
              'hal': 'önlendi',
              'sabıka': 'İlk kez.',
              'storyLead': 'İlyas',
              'storyPartner': 'Ayşe',
              'storyCraft': 'Marangozluk',
              'storyMissing': 'İlyas',
            },
          ),
        );
        final texts = <String>[
          spoken.petitioner,
          spoken.title,
          spoken.body,
          ?spoken.note,
          ?spoken.stakes,
          for (final option in spoken.options) ...[
            option.label,
            option.detail,
            option.resolution,
            option.annal,
          ],
        ];
        for (final text in texts) {
          expect(text.contains(RegExp(r'[{}]')), isFalse, reason: raw.id);
        }
      }
    }
  });
}
