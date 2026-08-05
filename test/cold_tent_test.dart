import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/systems/hearth_warmth.dart';
import 'package:village_sim/systems/villager_morale.dart';

/// ÇADIR ↔ OCAK — kışın ateşten uzak çadırın bedeli.
///
/// Bekçi olduğu şey: kuralın YÖNÜ ve SIRASI. Sayılar ayarlanabilir, ama
/// "uzaktaki çadır yakındakinden kötü, ikisi de evsizlikten iyi" sıralaması
/// bozulursa mekanik anlamını kaybeder (çadır kurmak cezaya dönerdi).
void main() {
  group('ocağın sıcağı', () {
    double at(double d) => hearthWarmth(dx: d, dy: 0, burning: true);

    test('ocağın dibinde ve yakın bantta tam ısıtır', () {
      expect(at(0), 1.0);
      expect(at(kHearthWarmRadius), 1.0);
    });

    test('soğuk yarıçapından sonra hiçbir faydası kalmaz', () {
      expect(at(kHearthColdRadius), 0.0);
      expect(at(kHearthColdRadius + 5), 0.0);
    });

    test('arada yumuşak bant var — keskin çizgi değil', () {
      final mid = at((kHearthWarmRadius + kHearthColdRadius) / 2);
      expect(mid, greaterThan(0.0));
      expect(mid, lessThan(1.0));
      // Monoton azalır: her adım bir öncekinden soğuk.
      var prev = 1.0;
      for (var d = kHearthWarmRadius; d <= kHearthColdRadius; d += 0.5) {
        final w = at(d);
        expect(w, lessThanOrEqualTo(prev + 1e-9));
        prev = w;
      }
    });

    test('mesafe iki eksenden birlikte ölçülür', () {
      // Köşegen: 3-4-5 üçgeni → 5 tile, hâlâ sıcak bant içinde.
      expect(hearthWarmth(dx: 3, dy: 4, burning: true), 1.0);
      // 6-8 → 10 tile, soğuk sınırın ötesi.
      expect(hearthWarmth(dx: 6, dy: 8, burning: true), 0.0);
    });

    test('ocak sönükse hiçbir yer sıcak değil', () {
      expect(hearthWarmth(dx: 0, dy: 0, burning: false), 0.0);
    });
  });

  group('soğuk barınak koşulu', () {
    test('yalnız çadır + kış + uzaklık birlikte üşütür', () {
      expect(shelterIsCold(tent: true, winter: true, warmth: 0.0), isTrue);
      // Evin kendi ocağı var — mesafenin önemi yok.
      expect(shelterIsCold(tent: false, winter: true, warmth: 0.0), isFalse);
      // Yazın çadır sorun değil.
      expect(shelterIsCold(tent: true, winter: false, warmth: 0.0), isFalse);
      // Ocağın çevresine kurulmuş çadır kışı atlatır.
      expect(shelterIsCold(tent: true, winter: true, warmth: 1.0), isFalse);
    });

    test('ödül ve ceza aynı yarıçaptan türer, aralarında nötr bant var', () {
      // Ocağın dibi: ödül bandı. Uzağı: kış cezası. İkisi asla çakışmaz.
      expect(shelterAtHearth(hearthWarmth(dx: 0, dy: 0, burning: true)), isTrue);
      expect(shelterAtHearth(hearthWarmth(dx: kHearthWarmRadius, dy: 0, burning: true)),
          isTrue);
      final between = hearthWarmth(
          dx: (kHearthWarmRadius + kHearthColdRadius) / 2, dy: 0, burning: true);
      expect(shelterAtHearth(between), isFalse);
      expect(shelterIsCold(tent: true, winter: true, warmth: between), isFalse);
      // Sönük ocak ödülü de siler.
      expect(shelterAtHearth(hearthWarmth(dx: 0, dy: 0, burning: false)), isFalse);
    });

    test('üşüme dürtüsü uzaklıkla hızlanır, yakında normale döner', () {
      expect(coldShelterDriveMultiplier(1.0), closeTo(1.0, 1e-9));
      expect(coldShelterDriveMultiplier(0.0), greaterThan(1.5));
      expect(coldShelterDriveMultiplier(0.3),
          greaterThan(coldShelterDriveMultiplier(0.8)));
    });
  });

  group('moral', () {
    MoraleEval eval({bool poor = false, bool cold = false, bool homeless = false}) =>
        evaluateVillagerMorale(
          homeless: homeless,
          poorHousing: poor,
          coldShelter: cold,
          starving: false,
          lowWater: false,
          cold: false,
          houseMood: 0.55,
          elderRespected: false,
        );

    test('ateşten uzak çadır, ocağın dibindeki çadırdan kötü', () {
      expect(eval(poor: true, cold: true).target,
          lessThan(eval(poor: true).target));
    });

    test('kötü de olsa bir dam, evsizlikten iyidir', () {
      expect(eval(poor: true, cold: true).target,
          greaterThan(eval(homeless: true).target));
    });

    test('çadırın kaderi ocakla olan mesafesine göre sıralanır', () {
      // ocağın yakını > kışın uzakta > evsiz
      final warm = eval(poor: true).target;
      final far = eval(poor: true, cold: true).target;
      final none = eval(homeless: true).target;
      expect(warm, greaterThan(far));
      expect(far, greaterThan(none));
    });

    test('baskın sebep panelde okunur', () {
      expect(eval(poor: true, cold: true).reason, 'çadırı ateşten uzak');
      // Çadır ocağa yakınsa eski sebep geri gelir.
      expect(eval(poor: true).reason, 'çadırda');
    });

    test('evi olanda hiçbir etkisi yok', () {
      expect(eval().target, evaluateVillagerMorale(
        homeless: false,
        starving: false,
        lowWater: false,
        cold: false,
        houseMood: 0.55,
        elderRespected: false,
      ).target);
    });
  });
}
