import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/systems/village_year.dart';
import 'package:village_sim/world/season.dart';

/// YIL OMURGASI — eskalasyonun tek kaynağı.
///
/// Buradaki testlerin çoğu "matematik doğru mu"dan çok TASARIM SÖZLEŞMESİNİ
/// tutuyor: birinci yıl bugünkü dengeyle birebir aynı kalmalı (çarpanlar 1.0),
/// baskı monoton artmalı ve tavanda durmalı. Bu üçü bozulursa eskalasyon ya
/// hissedilmez ya da sonsuza tırmanır.
void main() {
  group('yıl sayacı', () {
    test('gün 1 birinci yıldır', () {
      expect(yearOf(1), 1);
      expect(dayInYear(1), 1);
    });

    test('yıl tam olarak dört mevsim sürer', () {
      expect(kDaysPerYear, kDaysPerSeason * 4);
      expect(yearOf(kDaysPerYear), 1, reason: 'yılın son günü hâlâ o yıl');
      expect(yearOf(kDaysPerYear + 1), 2);
      expect(dayInYear(kDaysPerYear + 1), 1);
    });

    test('yıl sınırında mevsim de başa döner', () {
      // Yıl = 4 mevsim olduğuna göre her yılın ilk günü ilkbahar olmalı.
      for (var y = 1; y <= 8; y++) {
        final firstDay = (y - 1) * kDaysPerYear + 1;
        expect(seasonForDay(firstDay), Season.spring,
            reason: '$y. yıl ilkbaharla başlamalı');
      }
    });
  });

  group('hesaplaşma takvimi', () {
    test('ilan yılı hesaplaşmadan tam bir yıl önce', () {
      expect(kReckoningHeraldYear, kReckoningYear - 1);
    });

    test('geri sayım hesaplaşma yılının ilk gününde sıfırlanır', () {
      const firstReckoningDay = (kReckoningYear - 1) * kDaysPerYear + 1;
      expect(daysUntilReckoning(firstReckoningDay), 0);
      expect(daysUntilReckoning(firstReckoningDay - 1), 1);
      expect(daysUntilReckoning(firstReckoningDay + 40), 0,
          reason: 'geçmiş tarih negatife düşmemeli');
    });

    test('ilan günü ile hesaplaşma arasında tam bir yıl vardır', () {
      const heraldDay = (kReckoningHeraldYear - 1) * kDaysPerYear + 1;
      expect(daysUntilReckoning(heraldDay), kDaysPerYear);
    });
  });

  group('baskı eğrisi', () {
    test('birinci yıl bugünkü dengeyle birebir aynıdır', () {
      final p = pressureForYear(1);
      expect(p.imperialAppetite, 1.0);
      expect(p.imperialTempo, 1.0);
      expect(p.eventTempo, 1.0);
      expect(p.petitionTempo, 1.0);
      expect(p.winterBite, 1.0);
      // Kese payı 1.0 olamaz (bir oran) — ilk yılda da ısırır ama azdır.
      expect(p.treasuryShare, closeTo(0.20, 0.001));
    });

    test('vergici keseyi boşaltmaz, ısırır', () {
      // Tamamını alan bir vergi altın biriktirmeyi anlamsız kılar: oyuncu
      // keseyi hiç doldurmamayı öğrenir ve kaynağı öldürmüş oluruz.
      for (var y = 1; y <= 999; y++) {
        expect(pressureForYear(y).treasuryShare, lessThan(0.5));
        expect(pressureForYear(y).treasuryShare, greaterThan(0.0));
      }
    });

    test('kış vergiden yumuşak sertleşir', () {
      // Kış hazırlığı ödüllendiren bir mevsim; vergiyle aynı hızda ağırlaşırsa
      // geç oyun bir odun toplama angaryasına döner.
      final last = pressureForYear(kReckoningYear);
      expect(last.winterBite, greaterThan(1.0));
      expect(last.winterBite, lessThan(last.imperialAppetite));
      expect(last.winterBite, lessThan(1.5));
    });

    test('iştah artar, tempolar kısalır (monoton)', () {
      for (var y = 1; y < kReckoningYear; y++) {
        final a = pressureForYear(y), b = pressureForYear(y + 1);
        expect(b.imperialAppetite, greaterThan(a.imperialAppetite));
        expect(b.imperialTempo, lessThan(a.imperialTempo));
        expect(b.eventTempo, lessThan(a.eventTempo));
        expect(b.petitionTempo, lessThan(a.petitionTempo));
        expect(b.winterBite, greaterThan(a.winterBite));
        expect(b.treasuryShare, greaterThan(a.treasuryShare));
      }
    });

    test('dilekçe temposu altıncı yılda 0.70, sonrasında tavanda kal', () {
      expect(pressureForYear(kReckoningYear).petitionTempo, closeTo(0.70, 0.001));
      expect(pressureForYear(kReckoningYear + 20).petitionTempo, 0.70);
    });

    test('hesaplaşma yılında vergi iştahı iki katına çıkar', () {
      expect(pressureForYear(kReckoningYear).imperialAppetite,
          closeTo(2.0, 0.001));
    });

    test('tavan sonrası tırmanmaz', () {
      final atCap = pressureForYear(kReckoningYear);
      for (final y in [kReckoningYear + 1, kReckoningYear + 20, 999]) {
        final p = pressureForYear(y);
        expect(p.imperialAppetite, atCap.imperialAppetite);
        expect(p.imperialTempo, atCap.imperialTempo);
        expect(p.eventTempo, atCap.eventTempo);
        expect(p.winterBite, atCap.winterBite);
        expect(p.treasuryShare, atCap.treasuryShare);
      }
    });

    test('tempo çarpanları hiçbir zaman sıfıra/negatife düşmez', () {
      // Aralık çarpanı sıfırlanırsa heyet ve olaylar her karede tetiklenir.
      for (var y = 1; y <= 999; y++) {
        final p = pressureForYear(y);
        expect(p.imperialTempo, greaterThan(0.2));
        expect(p.eventTempo, greaterThan(0.2));
      }
    });

    test('bozuk yıl (0/negatif) çökmez, tabana düşer', () {
      expect(pressureForYear(0).imperialAppetite, 1.0);
      expect(pressureForYear(-5).year, 1);
    });

    test('pressureForDay ile pressureForYear aynı şeyi söyler', () {
      for (final day in [1, 17, 33, 80, 130]) {
        expect(pressureForDay(day).imperialAppetite,
            pressureForYear(yearOf(day)).imperialAppetite);
      }
    });
  });
}
