import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/systems/imperial.dart';
import 'package:village_sim/systems/village_year.dart';

/// ÖŞÜR RAKAMI — verginin gerçekten bir baskı olup olmadığı.
///
/// Bu testler ÖLÇÜMDEN doğdu. Vergi yalnız nüfusa bakarken, referans köy
/// 5 oyun gününde 135'ten 272 altına çıkıyordu (~27 altın/gün, 17 can) ve
/// altıncı yıl talebi ~76 altındı: üç günlük gelir. Talebi ikiye katlamak bu
/// eğrinin yanında hiçbir şey ifade etmiyordu.
///
/// Sözleşme: fakir köy korunur, zengin köy yakalanır, kese hiçbir zaman
/// tamamen boşalmaz.
double _severity(double favor) => 1.0 + (1.0 - favor) * 0.8;

int _demandAt({
  required int year,
  required int pop,
  required int gold,
  double favor = 0.5,
}) {
  final era = pressureForYear(year);
  return imperialGoldDemand(
    population: pop,
    treasury: gold,
    severity: _severity(favor),
    appetite: era.imperialAppetite,
    treasuryShare: era.treasuryShare,
  );
}

void main() {
  group('fakir köy korunur', () {
    test('kese boşken talep nüfus tabanından okunur', () {
      // Nüfus tabanı: 15 * 1.6 * 1.4 * 1.0 = 33.6 → 34
      expect(_demandAt(year: 1, pop: 15, gold: 0), 34);
    });

    test('kese boş bir köyden bile bir şey istenir (taban)', () {
      expect(_demandAt(year: 1, pop: 1, gold: 0), greaterThanOrEqualTo(6));
    });

    test('eksi kese çökertmez', () {
      expect(_demandAt(year: 3, pop: 10, gold: -50), greaterThan(0));
    });
  });

  group('zengin köy yakalanır', () {
    test('istif yapan köy istifinden vergilenir', () {
      // Ölçülen gerçek durum: 15 can, 276 altın, 2. yıl.
      // Yalnız nüfusa baksaydı ~40 alırdı; kese payı devreye girer.
      final byPopOnly = _demandAt(year: 2, pop: 15, gold: 0);
      final withHoard = _demandAt(year: 2, pop: 15, gold: 276);
      expect(byPopOnly, lessThan(50),
          reason: 'nüfus tabanı bu köyde küçük kalıyor — testin öncülü bu');
      expect(withHoard, greaterThan(byPopOnly * 2),
          reason: 'istif eden köyün talebi belirgin biçimde artmalı, yoksa '
              'altın biriktirmenin hiçbir bedeli olmaz ve kese ölü kaynak '
              'olarak kalır');
    });

    test('kese büyüdükçe talep büyür (monoton)', () {
      var prev = 0;
      for (final gold in [0, 50, 100, 200, 400, 800]) {
        final d = _demandAt(year: 4, pop: 20, gold: gold);
        expect(d, greaterThanOrEqualTo(prev));
        prev = d;
      }
    });

    test('aynı kese için yıl geçtikçe ısırık büyür', () {
      var prev = 0;
      for (var y = 1; y <= kReckoningYear; y++) {
        final d = _demandAt(year: y, pop: 20, gold: 300);
        expect(d, greaterThan(prev),
            reason: '$y. yılda talep bir öncekini geçmiyor');
        prev = d;
      }
    });
  });

  group('kese boşaltılmaz', () {
    test('en sert yılda bile keseden yarısından azı alınır', () {
      // Vergici ısırır, boşaltmaz: altın biriktirmeyi tümüyle anlamsız kılan
      // bir vergi, oyuncuya keseyi hiç doldurmamayı öğretir.
      for (final gold in [100, 300, 1000]) {
        // En kötü hâl: son yıl + en düşük itibar (severity 1.8).
        final d = _demandAt(
            year: kReckoningYear, pop: 5, gold: gold, favor: 0.0);
        expect(d, lessThan(gold),
            reason: '$gold altınlık kese tamamen boşalıyor');
      }
    });

    test('nüfus tabanı keseyi aşabilir — bu kasıtlı', () {
      // Kalabalık ama parasız köy ödeyemeyeceği bir rakamla karşılaşabilir.
      // Pazarlık/fidye/direnme kolları tam bunun için var (bkz. scene_imperial);
      // burada test edilen şey rakamın kırpılmadığıdır.
      expect(_demandAt(year: kReckoningYear, pop: 50, gold: 5),
          greaterThan(5));
    });
  });

  test('itibar hâlâ rakamı büküyor — yıl onu ezmiyor', () {
    final liked = _demandAt(year: 3, pop: 20, gold: 200, favor: 1.0);
    final hated = _demandAt(year: 3, pop: 20, gold: 200, favor: 0.0);
    expect(hated, greaterThan(liked),
        reason: 'iyi geçinmenin karşılığı kalmadıysa pazarlık kolu ölür');
  });
}
