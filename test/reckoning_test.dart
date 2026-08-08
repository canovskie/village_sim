import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/systems/law_compass.dart';
import 'package:village_sim/systems/reckoning.dart';

/// HESAPLAŞMA — kapanış kararının sözleşmesi.
///
/// Bu testler sayıları değil TASARIM İDDİALARINI koruyor:
///   • Karar binaya değil yönetişime bakar (unity/charter ağır basar).
///   • İki ayrı hayatta kalma yolu vardır: dayanmak ve eğilmek.
///   • Boş bir kabuğu hiçbir uysallık kurtarmaz.
/// Biri sessizce bozulursa oyunun sonu bir çekilişe döner.
ReckoningInput _mk({
  double unity = 0.5,
  double charter = 0.5,
  double grit = 0.5,
  double legacy = 0.5,
  double favor = 0.5,
}) =>
    ReckoningInput(
        unity: unity,
        charter: charter,
        grit: grit,
        legacy: legacy,
        favor: favor);

void main() {
  group('güç ölçüsü', () {
    test('imparatorluk itibarı GÜCE girmez', () {
      // "Sensiz de yaşarım" ölçüsü, imparatorluğun seni sevmesinden bağımsız.
      final low = _mk(favor: 0.0).standing;
      final high = _mk(favor: 1.0).standing;
      expect(low, high);
    });

    test('hanelerin rızası en ağır sütundur', () {
      final base = _mk(unity: 0, charter: 0, grit: 0, legacy: 0);
      final withUnity = _mk(unity: 1, charter: 0, grit: 0, legacy: 0).standing;
      final withCharter = _mk(unity: 0, charter: 1, grit: 0, legacy: 0).standing;
      final withGrit = _mk(unity: 0, charter: 0, grit: 1, legacy: 0).standing;
      final withLegacy = _mk(unity: 0, charter: 0, grit: 0, legacy: 1).standing;
      expect(base.standing, 0);
      expect(withUnity, greaterThan(withCharter));
      expect(withCharter, greaterThan(withGrit));
      expect(withGrit, greaterThan(withLegacy));
    });

    test('her sütun dolu → tam güç', () {
      expect(_mk(unity: 1, charter: 1, grit: 1, legacy: 1).standing,
          closeTo(1.0, 0.001));
    });
  });

  group('karar', () {
    test('kendi ayakları üstünde duran köy sancağını diker', () {
      final v = judge(_mk(unity: 0.9, charter: 0.85, grit: 0.7, legacy: 0.7,
          // İmparatorluk bu köyü sevmiyor; yine de sancak.
          favor: 0.05));
      expect(v, ReckoningVerdict.sancak);
    });

    test('orta hâlli köy beratını alır', () {
      expect(judge(_mk(unity: 0.55, charter: 0.5, grit: 0.4, legacy: 0.5)),
          ReckoningVerdict.berat);
    });

    test('zayıf ama uysal köy ilhaktan kurtulur', () {
      // Tek başına güç yetmiyor; itibar taşıyor. İkinci hayatta kalma yolu.
      final weak = _mk(unity: 0.3, charter: 0.3, grit: 0.3, legacy: 0.3);
      expect(weak.standing, lessThan(kBeratThreshold));
      expect(judge(weak), ReckoningVerdict.ilhak,
          reason: 'itibar 0.5 iken kurtulmamalı');

      final weakButLiked = _mk(
          unity: 0.3, charter: 0.3, grit: 0.3, legacy: 0.3, favor: 0.85);
      expect(judge(weakButLiked), ReckoningVerdict.berat);
    });

    test('boş kabuğu hiçbir uysallık kurtarmaz', () {
      final hollow = _mk(unity: 0.05, charter: 0.0, grit: 0.05, legacy: 0.2,
          favor: 1.0);
      expect(hollow.standing, lessThan(kFavorRescueFloor));
      expect(judge(hollow), ReckoningVerdict.ilhak);
    });

    test('eşikler sıralı ve tutarlı', () {
      expect(kFavorRescueFloor, lessThan(kBeratThreshold));
      expect(kBeratThreshold, lessThan(kSancakThreshold));
    });

    test('güç arttıkça karar hiçbir yerde geri gitmez (monoton)', () {
      var worst = 3;
      for (var i = 0; i <= 20; i++) {
        final t = i / 20.0;
        final v = judge(_mk(unity: t, charter: t, grit: t, legacy: t, favor: 0));
        // sancak(0) < berat(1) < ilhak(2): index düşerek ilerlemeli.
        expect(v.index, lessThanOrEqualTo(worst));
        worst = v.index;
      }
      expect(worst, ReckoningVerdict.sancak.index,
          reason: 'tam güçte sancak çıkmalı');
    });
  });

  group('karne', () {
    test('beş sütun da yazılır', () {
      expect(reckoningLedger(_mk()).length, 5);
    });

    test('her satırın değeri girdisiyle aynı', () {
      final i = _mk(unity: 0.1, charter: 0.2, grit: 0.3, legacy: 0.4, favor: 0.9);
      final rows = reckoningLedger(i);
      expect(rows.map((r) => r.value).toList(),
          [i.unity, i.charter, i.grit, i.legacy, i.favor]);
    });

    test('not değere göre değişir (üç bant)', () {
      final low = reckoningLedger(_mk(unity: 0.0)).first.note;
      final mid = reckoningLedger(_mk(unity: 0.5)).first.note;
      final high = reckoningLedger(_mk(unity: 1.0)).first.note;
      expect({low, mid, high}.length, 3);
    });
  });

  group('kapanış metni', () {
    test('her karar × her rejim için bir cümle vardır', () {
      for (final v in ReckoningVerdict.values) {
        for (final r in VillageRegime.values) {
          expect(verdictEpilogue(v, r).trim(), isNotEmpty);
        }
      }
    });

    test('aynı karar farklı rejimde farklı okunur', () {
      final texts = {
        for (final r in VillageRegime.values)
          verdictEpilogue(ReckoningVerdict.sancak, r)
      };
      expect(texts.length, VillageRegime.values.length);
    });

    test('mühür gerekçesi her karar için doludur', () {
      for (final v in ReckoningVerdict.values) {
        expect(v.sealReason.trim(), isNotEmpty);
        expect(v.title.trim(), isNotEmpty);
        expect(v.icon.trim(), isNotEmpty);
      }
    });

    test('yalnız ilhak kötü sonuçtur', () {
      expect(ReckoningVerdict.sancak.favorable, isTrue);
      expect(ReckoningVerdict.berat.favorable, isTrue);
      expect(ReckoningVerdict.ilhak.favorable, isFalse);
    });
  });

  group('kapanış sinematiği', () {
    test('her karar için üç çekimlik bir sahne kurulur', () {
      for (final v in ReckoningVerdict.values) {
        final cs = reckoningCutscene(v,
            village: 'Pınarbaşı', favor: 0.5, seed: 7);
        expect(cs.shots.length, 3);
        expect(cs.shots.every((s) => s.lines.isNotEmpty), isTrue);
      }
    });

    test('köyün adı komutanın ağzına girer', () {
      final cs = reckoningCutscene(ReckoningVerdict.berat,
          village: 'Pınarbaşı', favor: 0.5, seed: 3);
      final all = cs.shots.expand((s) => s.lines).map((l) => l.text).join(' ');
      expect(all, contains('Pınarbaşı'));
    });

    test('adsız köyde de cümle kurulur (capture/animasyon odası)', () {
      final cs = reckoningCutscene(ReckoningVerdict.ilhak,
          village: '', favor: 0.5, seed: 3);
      final all = cs.shots.expand((s) => s.lines).map((l) => l.text).join(' ');
      expect(all, contains('bu köy'));
      expect(all, isNot(contains('  ')));
    });
  });
}
