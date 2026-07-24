// REJİM — kimliğin oyuncuya dokunan yarısı.
//
// Pusula köyün nereye yattığını zaten hesaplıyordu ([law_compass_test]); bu
// test o yatışın SONUÇLARINI kilitler: yetki kuralları, huzursuzluk dengesi,
// meclis oyu/kararı ve yemin eşiği.
//
// Kilitlenen tasarım kararları:
//   • Merkez CEZASIZ — ılımlı köy huzursuzluk biriktirmez.
//   • Tiran köy yaşayabilir ama ancak yüksek moralle (0.028 ↔ 0.030 denge).
//   • Kapı/meclis kararları YASAYA değil dünyaya bakar.

import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/systems/estate_system.dart';
import 'package:village_sim/systems/law_book.dart';
import 'package:village_sim/systems/law_compass.dart';
import 'package:village_sim/systems/petition_system.dart';
import 'package:village_sim/systems/regime.dart';

const happy = {
  Estate.laborers: 0.75,
  Estate.artisans: 0.75,
  Estate.faithful: 0.75,
  Estate.hearth: 0.75,
};
const sullen = {
  Estate.laborers: 0.25,
  Estate.artisans: 0.25,
  Estate.faithful: 0.25,
  Estate.hearth: 0.25,
};

void main() {
  group('yetki kuralları', () {
    test('merkez cezasız — huzursuzluk hiç birikmez', () {
      final r = Regime.ruleOf(VillageRegime.moderate);
      expect(r.unrestPerDay, 0);
      expect(r.crisis, RegimeCrisis.none);
      // Moral dipte bile birikmemeli (yalnız erime tarafı çalışır).
      expect(Regime.unrestStep(r, morale: 0.1, days: 10), lessThanOrEqualTo(0));
    });

    test('baskı hızlı mühür + susturulmuş dilekçe, hür yavaş + meclis', () {
      final tyrant = Regime.ruleOf(VillageRegime.sealedHand);
      final commune = Regime.ruleOf(VillageRegime.commune);
      expect(tyrant.inkDryMul, lessThan(1.0));
      expect(tyrant.ignoresPetitions, isTrue);
      expect(tyrant.councilDecides, isFalse);
      expect(commune.inkDryMul, greaterThan(1.0));
      expect(commune.ignoresPetitions, isFalse);
      expect(commune.councilDecides, isTrue);
      expect(commune.councilVotesLaws, isTrue);
    });

    test('her rejimin kendi çürümesi var, ikisi aynı değil', () {
      final kinds = {
        for (final r in VillageRegime.values) Regime.ruleOf(r).crisis,
      };
      expect(kinds.length, VillageRegime.values.length,
          reason: 'her rejim farklı bir kriz üretmeli: $kinds');
    });

    test('yemin ayrıcalığı da bedeli de derinleştirir', () {
      final plain = Regime.ruleOf(VillageRegime.sealedHand);
      final sworn = Regime.ruleOf(VillageRegime.sealedHand, oath: true);
      expect(sworn.inkDryMul, lessThan(plain.inkDryMul)); // daha da hızlı
      expect(sworn.unrestPerDay, greaterThan(plain.unrestPerDay)); // daha ağır
    });
  });

  group('huzursuzluk dengesi', () {
    test('mutsuz tiran köyü kaynar, mutlu tiran köyü zar zor ayakta durur', () {
      final r = Regime.ruleOf(VillageRegime.sealedHand);
      expect(Regime.unrestStep(r, morale: 0.35, days: 1), greaterThan(0.02));
      // Tam moralde birikim neredeyse durur (ama sıfırlanmaz — bıçak sırtı).
      final calm = Regime.unrestStep(r, morale: 1.0, days: 1);
      expect(calm, lessThan(0.001));
      expect(calm, greaterThan(-0.01));
    });

    test('mutlu bir komün huzursuzluğu geriye sürer', () {
      final r = Regime.ruleOf(VillageRegime.commune);
      expect(Regime.unrestStep(r, morale: 0.9, days: 1), lessThan(0));
    });

    test('etiketler eşiklerle uyumlu', () {
      expect(Regime.unrestLabel(0.05), 'sakin');
      expect(Regime.unrestLabel(Regime.kStir), 'kıpırdanıyor');
      expect(Regime.unrestLabel(Regime.kCrisis), 'kaynıyor');
    });
  });

  group('meclis oyu', () {
    LawDef law(String id) => LawBook.byId(id)!;

    test('memnun köy sözünün arkasında durur', () {
      final v = Regime.voteOnLaw(
        effects: law('neighborliness').seal.estateMood,
        mood: happy,
        villageMorale: 0.75,
      );
      expect(v.passed, isTrue);
      expect(v.voices.length, Estate.values.length);
    });

    test('küskün köy dokunmayan fermana bile hayır der', () {
      final v = Regime.voteOnLaw(
        effects: law('neighborliness').seal.estateMood,
        mood: sullen,
        villageMorale: 0.3,
      );
      expect(v.passed, isFalse);
      expect(v.support, lessThan(0.5));
    });

    test('zümreyi vuran ferman o zümrenin oyunu kaybeder', () {
      final v = Regime.voteOnLaw(
        effects: const [(Estate.laborers, -0.14), (Estate.artisans, 0.10)],
        mood: happy,
        villageMorale: 0.6,
      );
      final laborers = v.voices.firstWhere((x) => x.estate == Estate.laborers);
      final artisans = v.voices.firstWhere((x) => x.estate == Estate.artisans);
      expect(laborers.yes, isFalse);
      expect(artisans.yes, isTrue);
      expect(laborers.line, isNotEmpty);
    });
  });

  group('köyün kendi kararı', () {
    const opts = [
      PetitionOption(
        label: 'emekçiye ver',
        detail: '',
        resolutionPool: ['x'],
        estateMood: [(Estate.laborers, 0.12)],
      ),
      PetitionOption(
        label: 'zanaatkâra ver',
        detail: '',
        resolutionPool: ['x'],
        estateMood: [(Estate.artisans, 0.12)],
      ),
    ];

    test('meclis küskün zümreyi kayıran şıkkı seçer', () {
      final i = Regime.pickCouncilOption(
        opts,
        mood: const {
          Estate.laborers: 0.20, // küskün olan bu
          Estate.artisans: 0.80,
          Estate.faithful: 0.55,
          Estate.hearth: 0.55,
        },
        villageMorale: 0.5,
      );
      expect(opts[i].label, 'emekçiye ver');
    });

    test('aç köy yiyecek getiren şıkkı öne alır', () {
      const hungry = [
        PetitionOption(
            label: 'kile getir',
            detail: '',
            resolutionPool: ['x'],
            foodDelta: 40),
        PetitionOption(
            label: 'moral konuşması',
            detail: '',
            resolutionPool: ['x'],
            moraleAmount: 0.05),
      ];
      final i = Regime.pickCouncilOption(hungry,
          mood: happy, villageMorale: 0.35);
      expect(hungry[i].label, 'kile getir');
    });
  });

  group('köyün yemini', () {
    test('ılımlı köy kendini ilan edemez', () {
      final p = LawCompass.positionOf({'neighborliness'});
      expect(Regime.oathAvailable(p, alreadySworn: false), isFalse);
    });

    test('kökleşen köy yemin edebilir, iki kez edemez', () {
      // Aynı yöne birkaç ağır mühür — kararlılık eşiğini geçsin.
      final p = LawCompass.positionOf(
          {'nizam.sole', 'nizam.registry', 'nizam.exile', 'nizam.watch'});
      expect(p.intensity, greaterThanOrEqualTo(Regime.kOathConviction));
      expect(Regime.oathAvailable(p, alreadySworn: false), isTrue);
      expect(Regime.oathAvailable(p, alreadySworn: true), isFalse);
    });

    test('yemin bayrağı rejim fermanının dünya kapısını açar', () {
      final law = LawBook.byId('rejim.muhassil')!;
      expect(law.binding, isTrue, reason: 'rejim fermanı feshedilemez');
      expect(LawBook.repealable(law), isFalse);
      const before = LawContext(population: 20, dayCount: 30);
      final after = LawContext(
        population: 20,
        dayCount: 30,
        memory: {Regime.oathFlag(VillageRegime.sealedHand)},
      );
      expect(LawBook.available(law, const {}, before), isFalse);
      expect(LawBook.available(law, const {}, after), isTrue);
    });

    test('her rejimin okunur bir yemin metni var', () {
      for (final r in VillageRegime.values) {
        final (title, decree) = Regime.oathText(
          LawCompass.identify(CompassPosition(
            authority: r == VillageRegime.sealedHand ||
                    r == VillageRegime.ironTable
                ? 0.8
                : -0.8,
            economy: r == VillageRegime.sealedHand || r == VillageRegime.market
                ? 0.8
                : -0.8,
            faith: 0,
            lawCount: 5,
          )),
        );
        if (r == VillageRegime.moderate) continue;
        expect(title, isNotEmpty);
        expect(decree, contains('Buyuruldu'));
      }
    });
  });

  group('fesih kuralı', () {
    test('günlük geçim hükmü bozulur, kimliği yazan hüküm bozulmaz', () {
      expect(LawBook.repealable(LawBook.byId('neighborliness')!), isTrue);
      expect(LawBook.repealable(LawBook.byId('nizam.sole')!), isFalse);
      expect(LawBook.repealable(LawBook.byId('dergah.lodge')!), isFalse);
      expect(LawBook.repealable(LawBook.byId('rejim.ortakAmbar')!), isFalse);
    });
  });
}
