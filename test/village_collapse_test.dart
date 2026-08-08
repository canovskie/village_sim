import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/systems/village_collapse.dart';

/// Kaybetme eşiğinin üç sözü kilitlenir:
///  (1) kayıp HABER VERİLMİŞ olur — dağılma ani değil, evreli ve geri sayımlı,
///  (2) ancak KURDUĞUNU kaybedersin — kuruluş kadrosu uyarı üretmez,
///  (3) geri sayım bir KAPAN değil bir SÜRE — toparlayınca sıfırlanır.

CollapseState _state(
  int adults, {
  int population = 10,
  int peak = 12,
  double countdown = 0,
}) =>
    evaluateCollapse(
      adults: adults,
      population: population,
      peakAdults: peak,
      countdown: countdown,
    );

void main() {
  group('kurulmamış köy uyumaz değil, UYUR', () {
    test('kuruluş kadrosu (peak < eşik) hiçbir uyarı üretmez', () {
      for (final adults in [0, 1, 2, 3, 5]) {
        final s = _state(adults, population: 5, peak: kFoundedAdults - 1);
        expect(s.vitality, VillageVitality.healthy,
            reason: 'köy daha ayağa kalkmadan ölüm uyarısı vermemeli '
                '(yetişkin $adults)');
        expect(s.collapsed, isFalse);
      }
    });

    test('köy bir kez ayağa kalkınca sistem uyanır', () {
      final s = _state(1, peak: kFoundedAdults);
      expect(s.vitality, VillageVitality.failing);
    });
  });

  group('evreler — kayıp haber verilir', () {
    test('sağlıklı köy hiçbir şey göstermez', () {
      final s = _state(9);
      expect(s.vitality, VillageVitality.healthy);
      expect(s.vitality.visible, isFalse);
    });

    test('eller azalınca GERGİN — görünür ama geri sayım yok', () {
      final s = _state(kStrainedAdults);
      expect(s.vitality, VillageVitality.strained);
      expect(s.vitality.visible, isTrue);
      expect(s.vitality.counting, isFalse);
      expect(s.daysLeft, double.infinity);
    });

    test('kritik eşikte ÇÖKÜYOR — geri sayım görünür', () {
      final s = _state(kFailingAdults);
      expect(s.vitality, VillageVitality.failing);
      expect(s.vitality.counting, isTrue);
      expect(s.daysLeft, kCollapseGraceDays);
      expect(s.spent, 0.0);
    });

    test('evreler sertlik sırasına göre tırmanır', () {
      expect(
        [_state(9).vitality, _state(4).vitality, _state(2).vitality],
        [
          VillageVitality.healthy,
          VillageVitality.strained,
          VillageVitality.failing,
        ],
      );
    });
  });

  group('geri sayım — kapan değil, süre', () {
    test('süre dolmadan köy dağılmaz', () {
      final s = _state(1, countdown: kCollapseGraceDays - 0.5);
      expect(s.collapsed, isFalse);
      expect(s.daysLeft, closeTo(0.5, 0.001));
      expect(s.spent, greaterThan(0.9));
    });

    test('süre dolunca dağılır', () {
      final s = _state(1, countdown: kCollapseGraceDays);
      expect(s.collapsed, isTrue);
      expect(s.cause, CollapseCause.noHands);
    });

    test('TOPARLAYINCA sayaç sıfırlanır — geri dönülebilir', () {
      var c = 4.0;
      // Hâlâ çöküyor → ilerler.
      c = advanceCountdown(
          countdown: c, vitality: VillageVitality.failing, dayFrac: 1.0);
      expect(c, 5.0);
      // Köy toparlandı (göçmen geldi / hane barıştı) → sıfır.
      c = advanceCountdown(
          countdown: c, vitality: VillageVitality.strained, dayFrac: 1.0);
      expect(c, 0.0, reason: 'eşik bir kapan olmamalı');
    });

    test('sağlıklıya dönünce de sıfırlanır', () {
      final c = advanceCountdown(
          countdown: 5.9, vitality: VillageVitality.healthy, dayFrac: 1.0);
      expect(c, 0.0);
    });
  });

  group('dağılma nedenleri', () {
    test('kimse kalmadıysa neden: boşaldı', () {
      final s = _state(0, population: 0);
      expect(s.collapsed, isTrue);
      expect(s.cause, CollapseCause.emptied);
    });

    test('insan var ama yetişkin yoksa neden: el kalmadı', () {
      final s = _state(0, population: 3);
      expect(s.collapsed, isTrue);
      expect(s.cause, CollapseCause.noHands);
    });
  });

  group('ayrılık (hane göçü)', () {
    test('kopuş sayacı ilerledikçe ayrılık yaklaşır', () {
      expect(schismProgress(0), 0.0);
      expect(schismProgress(kSchismDays / 2), closeTo(0.5, 0.001));
      expect(schismProgress(kSchismDays), 1.0);
      expect(schismProgress(kSchismDays * 3), 1.0, reason: 'taşmamalı');
    });

    test('son uyarı ayrılıktan ÖNCE düşer — sessiz ayrılık yok', () {
      expect(kSchismFinalWarn, lessThan(1.0));
      expect(kSchismFinalWarn, greaterThan(0.5),
          reason: 'son uyarı gerçekten SON olmalı, baştan değil');
    });

    test('geri sayım oyuncuya iş yapacak kadar süre tanır', () {
      expect(kSchismDays, greaterThanOrEqualTo(4.0));
      expect(kCollapseGraceDays, greaterThanOrEqualTo(4.0));
    });
  });
}
