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
      expect(
        kinds.length,
        VillageRegime.values.length,
        reason: 'her rejim farklı bir kriz üretmeli: $kinds',
      );
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

    test('ocak töresi küskün mecliste bile yazılı hükme dayanak olur', () {
      final uncertain = {for (final e in Estate.values) e: 0.47};
      final rootless = Regime.voteOnLaw(
        effects: const [],
        mood: uncertain,
        villageMorale: 0.45,
      );
      final rooted = Regime.voteOnLaw(
        effects: const [],
        mood: uncertain,
        villageMorale: 0.45,
        traditionSupport: 0.12,
      );
      expect(rootless.passed, isFalse);
      expect(rooted.passed, isTrue);
      expect(rooted.voices.first.line, contains('tuttuğumuz yol'));
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
          foodDelta: 40,
        ),
        PetitionOption(
          label: 'moral konuşması',
          detail: '',
          resolutionPool: ['x'],
          moraleAmount: 0.05,
        ),
      ];
      final i = Regime.pickCouncilOption(
        hungry,
        mood: happy,
        villageMorale: 0.35,
      );
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
      final p = LawCompass.positionOf({
        'nizam.sole',
        'nizam.registry',
        'nizam.exile',
        'nizam.watch',
      });
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
          LawCompass.identify(
            CompassPosition(
              authority:
                  r == VillageRegime.sealedHand || r == VillageRegime.ironTable
                  ? 0.8
                  : -0.8,
              economy:
                  r == VillageRegime.sealedHand || r == VillageRegime.market
                  ? 0.8
                  : -0.8,
              faith: 0,
              lawCount: 5,
            ),
          ),
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

  imperialTests();
  rotTests();
  faithTests();
}

// ─── REJİM × İMPARATORLUK ────────────────────────────────────────────────────
// İç yönetişim ile dış tehdidin kesişimi: rejim, vergici heyet karşısında
// köyün duruşunu büker (görünürlük, direniş eli, pazarlık kolaylığı, meclis).
void imperialTests() {
  group('rejim × imparatorluk duruşu', () {
    test('mülkçü köy göz doldurur, ortakçı köy gözden ırak', () {
      final market = Regime.imperialPostureOf(
        VillageRegime.market,
        committed: true,
      );
      final commune = Regime.imperialPostureOf(
        VillageRegime.commune,
        committed: true,
      );
      expect(market.attentionMul, greaterThan(1.0));
      expect(commune.attentionMul, lessThan(1.0));
      // Tüccar köy pazarlıkta usta, kavgada zayıf.
      expect(market.haggleEase, greaterThan(0));
      expect(market.resistBonus, lessThan(0));
    });

    test('militan köy direniş elini güçlendirir', () {
      final tyrant = Regime.imperialPostureOf(
        VillageRegime.sealedHand,
        committed: true,
      );
      expect(tyrant.resistBonus, greaterThan(0.15));
    });

    test('yemin duruşu keskinleştirir', () {
      final plain = Regime.imperialPostureOf(
        VillageRegime.sealedHand,
        committed: true,
      );
      final sworn = Regime.imperialPostureOf(
        VillageRegime.sealedHand,
        committed: true,
        oath: true,
      );
      expect(sworn.resistBonus, greaterThan(plain.resistBonus));
      expect(sworn.attentionMul, greaterThan(plain.attentionMul));
    });

    test('merkez rejim imparatorluğu hiç bükmez', () {
      final m = Regime.imperialPostureOf(
        VillageRegime.moderate,
        committed: false,
      );
      expect(m.resistBonus, 0);
      expect(m.haggleEase, 0);
      expect(m.attentionMul, 1.0);
      expect(m.note, isEmpty);
    });
  });

  group('meclis imparatorluk kararı', () {
    test('rahat karşılanan talebi memnun köy öder', () {
      final v = Regime.councilImperialVerdict(
        affordability: 2.0,
        conscript: false,
        resistChance: 0.1,
        mood: happy,
        villageMorale: 0.7,
      );
      expect(v, ImperialVerdict.comply);
    });

    test('güçlü ve gururlu köy direnmek ister', () {
      final v = Regime.councilImperialVerdict(
        affordability: 1.5,
        conscript: false,
        resistChance: 0.6,
        mood: happy,
        villageMorale: 0.7,
      );
      expect(v, ImperialVerdict.resist);
    });

    test('ödeyemeyen ama zayıf köy pazarlığa yönelir', () {
      final v = Regime.councilImperialVerdict(
        affordability: 0.5,
        conscript: false,
        resistChance: 0.1,
        mood: {
          Estate.laborers: 0.5,
          Estate.artisans: 0.5,
          Estate.faithful: 0.5,
          Estate.hearth: 0.5,
        },
        villageMorale: 0.5,
      );
      expect(v, ImperialVerdict.haggle);
    });

    test('meclis bir evladı kolay teslim etmez', () {
      final strong = Regime.councilImperialVerdict(
        affordability: 1.0,
        conscript: true,
        resistChance: 0.5,
        mood: happy,
        villageMorale: 0.6,
      );
      expect(strong, ImperialVerdict.resist);
      final weak = Regime.councilImperialVerdict(
        affordability: 1.0,
        conscript: true,
        resistChance: 0.1,
        mood: happy,
        villageMorale: 0.6,
      );
      // Direnemiyorsa fidye/uzlaşma (comply) — ama asla "reddet".
      expect(weak, ImperialVerdict.comply);
    });

    test('meclis asla reddet (bilinçli kıyım) önermez', () {
      // Enum'da zaten yok; ama her kombinasyonda dönen değer 3 duruştan biri.
      for (final aff in [0.2, 0.6, 1.0, 2.0]) {
        for (final rc in [0.0, 0.3, 0.6, 0.85]) {
          final v = Regime.councilImperialVerdict(
            affordability: aff,
            conscript: false,
            resistChance: rc,
            mood: sullen,
            villageMorale: 0.3,
          );
          expect(ImperialVerdict.values, contains(v));
        }
      }
    });

    test('her duruşun okunur bir meclis cümlesi var', () {
      for (final v in ImperialVerdict.values) {
        expect(Regime.verdictLine(v, conscript: false), isNotEmpty);
        expect(Regime.verdictLine(v, conscript: true), isNotEmpty);
      }
    });
  });
}

// ─── FAZ 3: ÇÜRÜME + KRONİK HÂL ──────────────────────────────────────────────
// Huzursuzluk hızlı bir nabız; çürüme onun bıraktığı KALICI iz. Kronikleşmek
// oyun-sonu DEĞİL — çıkışı açık kalmalı (cozy çizgi).
void rotTests() {
  group('rejim çürümesi', () {
    test('kaynayan köy iz biriktirir, sakin köy siler', () {
      expect(Regime.rotStep(unrest: 0.95, days: 1), greaterThan(0));
      expect(Regime.rotStep(unrest: 0.10, days: 1), lessThan(0));
    });

    test('çürütmek iyileştirmekten hızlıdır', () {
      final harm = Regime.rotStep(unrest: 1.0, days: 1);
      final heal = -Regime.rotStep(unrest: 0.0, days: 1);
      expect(harm, greaterThan(heal));
    });

    test('kStir eşiğinin tam altında birikim yok', () {
      expect(
        Regime.rotStep(unrest: Regime.kStir - 0.01, days: 1),
        lessThanOrEqualTo(0),
      );
      expect(Regime.rotStep(unrest: Regime.kStir, days: 1), greaterThan(0));
    });

    test('kronik hâlden ÇIKIŞ var — iz silinebilir', () {
      var rot = 0.75; // kronikleşmiş köy
      expect(rot, greaterThanOrEqualTo(Regime.kChronic));
      // Uzun süre tam sakin kalırsa eşiğin altına iner (oyun-sonu değil).
      for (var i = 0; i < 400 && rot > 0; i++) {
        rot = (rot + Regime.rotStep(unrest: 0.0, days: 1)).clamp(0.0, 1.0);
      }
      expect(rot, lessThan(Regime.kChronic));
    });

    test('her krizin kalıcı bir bedeli var', () {
      expect(Regime.kRotPerCrisis, greaterThan(0));
    });

    test('her rejimin kendi kronik hâli ve adı var', () {
      final titles = <String>{};
      for (final r in VillageRegime.values) {
        final crisis = Regime.ruleOf(r).crisis;
        final (title, body) = Regime.chronicText(crisis);
        if (crisis == RegimeCrisis.none) {
          expect(title, isEmpty);
          continue;
        }
        expect(title, isNotEmpty);
        expect(body, isNotEmpty);
        titles.add(title);
      }
      // Merkez hariç 4 rejim → 4 ayrı kronik hâl.
      expect(titles.length, 4);
    });

    test('etiketler eşiklerle uyumlu', () {
      expect(Regime.rotLabel(0.05), 'sağlam');
      expect(Regime.rotLabel(Regime.kChronic), 'kronikleşti');
      expect(Regime.rotLabel(Regime.kFailing), 'çözülüyor');
    });
  });
}

// ─── DİNÎ OVERLAY MEKANİĞİ ───────────────────────────────────────────────────
// İman pusulada bir BOYA; ama boya yalnız ismi değiştiriyorsa oyuncu için
// yoktur. Bu testler imanın gerçek mekanik karşılığını kilitler.
void faithTests() {
  group('iman overlay mekaniği', () {
    test('imansız köyde etki neredeyse yok', () {
      final f = Regime.faithEffectOf(0.0);
      expect(f.unrestRelief, 0);
      expect(f.resistBonus, 0);
      expect(f.crimeDamp, 1.0);
      expect(f.moraleFloor, 0);
      expect(f.conscriptSting, 1.0);
      expect(f.note, isEmpty);
    });

    test('bandın üstünde iman gerçek sonuç doğurur', () {
      final f = Regime.faithEffectOf(1.0);
      expect(f.unrestRelief, greaterThan(0)); // sabır
      expect(f.resistBonus, greaterThan(0)); // inanç için direnmek
      expect(f.crimeDamp, lessThan(1.0)); // cemaat gözü
      expect(f.moraleFloor, greaterThan(0)); // teselli
      expect(f.conscriptSting, greaterThan(1)); // devşirme daha ağır
      expect(f.note, isNotEmpty);
    });

    test('etkiler imanla birlikte tek yönlü büyür', () {
      final lo = Regime.faithEffectOf(0.2);
      final mid = Regime.faithEffectOf(0.6);
      final hi = Regime.faithEffectOf(0.95);
      expect(mid.unrestRelief, greaterThan(lo.unrestRelief));
      expect(hi.unrestRelief, greaterThan(mid.unrestRelief));
      expect(hi.crimeDamp, lessThan(mid.crimeDamp));
      expect(hi.conscriptSting, greaterThan(mid.conscriptSting));
    });

    test('not yalnız dinî bandın üstünde görünür', () {
      expect(Regime.faithEffectOf(LawCompass.kFaithBand - 0.01).note, isEmpty);
      expect(
        Regime.faithEffectOf(LawCompass.kFaithBand + 0.01).note,
        isNotEmpty,
      );
    });

    test('iman dinî tiranı ayakta tutar ama kurtarmaz', () {
      // Mühürlü El mutsuzken kaynar; iman bunu yavaşlatır, sıfırlamaz.
      final r = Regime.ruleOf(VillageRegime.sealedHand);
      final raw = Regime.unrestStep(r, morale: 0.35, days: 1);
      final withFaith = raw - Regime.faithEffectOf(1.0).unrestRelief;
      expect(withFaith, lessThan(raw));
      expect(withFaith, greaterThan(0), reason: 'iman zulmü tamamen aklamaz');
    });
  });
}
