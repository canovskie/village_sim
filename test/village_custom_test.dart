import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/entities/villager_job.dart';
import 'package:village_sim/systems/village_custom.dart';

/// KÖYÜN ÂDETİ — kural değil huy.
///
/// Bu testlerin asıl işi bir sayıyı doğrulamak değil, TASARIM KARARINI
/// kilitlemek: âdet hiçbir zaman bir işi imkânsız kılmaz. Biri gelip
/// `speedMul`'ü 0'a çekerse ya da bir rolü "yapılamaz" hâline getirirse burası
/// kırılır — çünkü o an oyun sessizce "âdet"ten "kural"a geçmiş olur.
void main() {
  group('âdet yargısı', () {
    test('balta/kazma/ağ erkeğe, sepet/ocak/çiçek kadına yakışır', () {
      expect(VillageCustom.judge(JobRole.woodcutter, male: true).stance,
          CustomStance.fitting);
      expect(VillageCustom.judge(JobRole.miner, male: true).stance,
          CustomStance.fitting);
      expect(VillageCustom.judge(JobRole.fisher, male: true).stance,
          CustomStance.fitting);
      expect(VillageCustom.judge(JobRole.forager, male: false).stance,
          CustomStance.fitting);
      expect(VillageCustom.judge(JobRole.cook, male: false).stance,
          CustomStance.fitting);
      expect(VillageCustom.judge(JobRole.florist, male: false).stance,
          CustomStance.fitting);
    });

    test('ters cinsiyet aykırıdır ama YASAK DEĞİLDİR', () {
      for (final r in [JobRole.woodcutter, JobRole.miner, JobRole.fisher]) {
        final j = VillageCustom.judge(r, male: false);
        expect(j.stance, CustomStance.against, reason: '$r kadına aykırı');
        // Kritik: iş yine YAPILIR. Sıfır hız = engel demektir.
        expect(j.speedMul, greaterThan(0.0), reason: '$r yine de yapılabilmeli');
      }
      for (final r in [JobRole.forager, JobRole.cook, JobRole.florist]) {
        final j = VillageCustom.judge(r, male: true);
        expect(j.stance, CustomStance.against, reason: '$r erkeğe aykırı');
        expect(j.speedMul, greaterThan(0.0));
      }
    });

    test('ortak emek işlerine âdet karışmaz — iki cinsiyette de nötr ve tam hız',
        () {
      for (final r in [JobRole.farmer, JobRole.shepherd, JobRole.builder]) {
        for (final male in [true, false]) {
          final j = VillageCustom.judge(r, male: male);
          expect(j.stance, CustomStance.neutral, reason: '$r male=$male');
          expect(j.speedMul, 1.0);
          expect(j.isAgainst, isFalse);
        }
      }
    });

    test('uygun atama BONUS vermez — âdete uymak normaldir, ödül değil', () {
      expect(VillageCustom.speedMul(JobRole.woodcutter, male: true), 1.0);
      expect(VillageCustom.speedMul(JobRole.forager, male: false), 1.0);
    });

    test('aykırılık hissedilir ama caydırıcı değil (0.5 < mul < 1)', () {
      final mul = VillageCustom.speedMul(JobRole.woodcutter, male: false);
      expect(mul, lessThan(1.0), reason: 'bedeli görünmeli');
      expect(mul, greaterThan(0.5),
          reason: 'oyuncunun kararı boşa çıkmamalı — bu bir engel değil');
    });

    test('boş rol her zaman nötr — "işsiz" bir âdet ihlali değildir', () {
      expect(VillageCustom.judge(JobRole.none, male: true).stance,
          CustomStance.neutral);
      expect(VillageCustom.judge(JobRole.none, male: false).stance,
          CustomStance.neutral);
    });

    test('her JobRole bir hüküm döndürür — yeni rol eklenince burası çöker',
        () {
      for (final r in JobRole.values) {
        for (final male in [true, false]) {
          final j = VillageCustom.judge(r, male: male);
          expect(j.speedMul, greaterThan(0.0), reason: '$r male=$male');
          expect(j.speedMul, lessThanOrEqualTo(1.0), reason: '$r male=$male');
        }
      }
    });
  });
}
