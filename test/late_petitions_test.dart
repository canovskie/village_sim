import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/systems/law_compass.dart';
import 'package:village_sim/systems/petition_system.dart';
import 'package:village_sim/world/season.dart';

/// GEÇ OYUN DİLEKÇELERİ — köyün OLGUNLAŞTIĞINI gören kapılar.
///
/// Bu testler eklenmeden önce katalogdaki en yüksek kapı `nüfus >= 8` idi: köy
/// sekiz cana ulaştığı an oyunun sorabileceği her şey havuzdaydı ve onuncu
/// saatte de aynı sorular dönüyordu. Buradaki iddia tek cümle: **genç köy geç
/// oyun sorularını duymaz, olgun köy duyar.**

/// Kuruluşun ilk günleri: küçük, genç, kurucular hayatta, defter boş.
PetitionContext young() => const PetitionContext(
      population: 6,
      adults: 4,
      food: 60,
      gold: 20,
      morale: 0.6,
      hasChurch: false,
      dayCount: 3,
      foundersAlive: true,
      houseCount: 1,
      sealedLaws: 0,
    );

/// Yaşlanmış köy: kalabalık, üç yıllık, kurucular gitmiş, defter kalın,
/// bir zanaat unutulmuş, tek hane güçlenmiş, rejim sertleşmiş, imparatorluk
/// iki kez uğramış, geçmiş kararların izi ağır.
PetitionContext mature() => const PetitionContext(
      population: 20,
      adults: 12,
      food: 200,
      gold: 90,
      morale: 0.55,
      hasChurch: true,
      season: Season.autumn,
      dayCount: 52, // 4 mevsim × 4 gün = 16 gün/yıl → 3+ yıl
      foundersAlive: false,
      houseCount: 3,
      dominantSway: 0.52,
      sealedLaws: 7,
      regime: VillageRegime.ironTable,
      unrest: 0.45,
      craftLost: true,
      imperialVisits: 2,
      governanceLegacy: 0.09,
    );

/// [ctx] için üretilebilen dilekçe id'leri (ağırlıklı çekiliş, çok tur).
Set<String> reachable(PetitionContext ctx, {int rolls = 600}) {
  final rng = Random(7);
  final out = <String>{};
  for (var i = 0; i < rolls; i++) {
    final p = PetitionSystem.roll(ctx, rng);
    if (p != null) out.add(p.id);
  }
  return out;
}

const lateIds = <String>[
  'lateFounders',
  'lateLostCraft',
  'lateHouseShadow',
  'lateThickCharter',
  'lateDissent',
  'lateAmbition',
  'lateImperialShadow',
  'lateLegacy',
];

void main() {
  group('olgunluk kapıları', () {
    test('genç köy geç oyun dilekçelerinin HİÇBİRİNİ duymaz', () {
      final ids = reachable(young());
      expect(ids, isNotEmpty, reason: 'genç köyün kendi dilekçeleri gelmeli');
      for (final id in lateIds) {
        expect(ids.contains(id), isFalse,
            reason: '$id kuruluşun ilk günlerinde sorulmamalı');
      }
    });

    test('olgun köy geç oyun dilekçelerini duyar', () {
      final ids = reachable(mature());
      final seen = lateIds.where(ids.contains).toList();
      expect(seen.length, greaterThanOrEqualTo(6),
          reason: 'olgun köyde geç oyun havuzu açılmalı — görülen: $seen');
    });

    test('olgun köyün gündemi gençten FARKLI', () {
      final y = reachable(young());
      final m = reachable(mature());
      final fresh = m.difference(y);
      expect(fresh.length, greaterThanOrEqualTo(6),
          reason: 'köy yaşlandıkça yeni sorular gelmeli, aynılar dönmemeli');
    });
  });

  group('tekil kapılar', () {
    test('kurucular hayattayken "İlk Ocağı Yakanlar" gelmez', () {
      final ctx = PetitionContext(
        population: mature().population,
        adults: mature().adults,
        food: 200, gold: 90, morale: 0.55, hasChurch: true,
        dayCount: 52,
        foundersAlive: true, // tek fark
        houseCount: 3, sealedLaws: 7,
      );
      expect(reachable(ctx).contains('lateFounders'), isFalse);
    });

    test('zanaat kaybedilmemişse "Kimsenin Bilmediği İş" gelmez', () {
      final ctx = PetitionContext(
        population: 20, adults: 12, food: 200, gold: 90, morale: 0.55,
        hasChurch: true, dayCount: 52, foundersAlive: false,
        houseCount: 3, sealedLaws: 7,
        craftLost: false, // tek fark
      );
      expect(reachable(ctx).contains('lateLostCraft'), isFalse);
    });

    test('hür ve huzurlu rejimde "Konuşmayı Göze Alan" gelmez', () {
      final ctx = PetitionContext(
        population: 20, adults: 12, food: 200, gold: 90, morale: 0.7,
        hasChurch: true, dayCount: 52, foundersAlive: false,
        houseCount: 3, sealedLaws: 7,
        regime: VillageRegime.commune,
        unrest: 0.05,
      );
      final ids = reachable(ctx);
      expect(ids.contains('lateDissent'), isFalse);
      // ...ama aynı köy "Elimiz Boş Durmasın"ı duyar.
      expect(ids.contains('lateAmbition'), isTrue);
    });
  });

  group('olgunluk ölçüsü', () {
    test('üç işaretten ikisi olgunluk sayılır', () {
      const onlyYears = PetitionContext(
        population: 5, adults: 3, food: 50, gold: 10, morale: .5,
        hasChurch: false, dayCount: 40, sealedLaws: 0,
      );
      expect(onlyYears.mature, isFalse, reason: 'tek işaret yetmez');

      const yearsAndLaws = PetitionContext(
        population: 5, adults: 3, food: 50, gold: 10, morale: .5,
        hasChurch: false, dayCount: 40, sealedLaws: 4,
      );
      expect(yearsAndLaws.mature, isTrue, reason: 'yaş + yazılı düzen yeter');

      const bigAndLawful = PetitionContext(
        population: 18, adults: 10, food: 50, gold: 10, morale: .5,
        hasChurch: false, dayCount: 6, sealedLaws: 3,
      );
      expect(bigAndLawful.mature, isTrue,
          reason: 'hızlı büyüyen köy de kendi yolundan olgunlaşır');
    });

    test('yıl ölçüsü mevsim uzunluğundan türer', () {
      const c = PetitionContext(
        population: 5, adults: 3, food: 0, gold: 0, morale: .5,
        hasChurch: false, dayCount: 33,
      );
      expect(c.years, 2); // 16 gün/yıl → 33 gün = 2 yıl
    });
  });

  group('olay ağaçları', () {
    /// Bir dilekçenin seçeneklerinin işaret ettiği devam id'leri.
    List<String?> branchesOf(String id) {
      final p = PetitionSystem.byId(id);
      expect(p, isNotNull, reason: '$id katalogda yok');
      return p!.options.map((o) => o.followUpId).toList();
    }

    test('zincir halkaları rastgele ÇIKMAZ, yalnız çağrılır', () {
      final ids = reachable(mature());
      for (final node in [
        'craftReturn', 'craftSchool', 'craftHoard',
        'dissentEcho', 'dissentSilence',
      ]) {
        expect(PetitionSystem.byId(node), isNotNull,
            reason: '$node id ile çağrılabilmeli');
        expect(ids.contains(node), isFalse,
            reason: '$node rastgele havuza girmemeli (canFire=false)');
      }
    });

    test('zanaat ağacı: gönder → dön → atölye/kapalı kapı', () {
      // 1. halka: yollamak zinciri açar, kese kapamak açmaz.
      expect(branchesOf('lateLostCraft'), ['craftReturn', null]);
      // 2. halka İKİ AYRI dala çıkar — kararın yönü ağacı değiştirir.
      expect(branchesOf('craftReturn'), ['craftSchool', 'craftHoard']);
      // 3. halkalar yaprak: zincir sonsuza gitmez.
      expect(branchesOf('craftSchool'), [null, null]);
      expect(branchesOf('craftHoard'), [null, null]);
    });

    test('itiraz ağacı: her iki cevap da bir ardıl doğurur', () {
      expect(branchesOf('lateDissent'), ['dissentEcho', 'dissentSilence']);
      expect(branchesOf('dissentEcho'), [null, null]);
      expect(branchesOf('dissentSilence'), [null, null]);
    });

    test('zincir kararları köy hafızasına iz bırakır', () {
      final school = PetitionSystem.byId('craftReturn')!.options[0];
      expect(school.setsFlags, contains('craft.school'));
      expect(school.clearsFlags, contains('craft.lost'),
          reason: 'zanaat geri geldiyse "unutuldu" izi silinmeli');

      final hoard = PetitionSystem.byId('craftReturn')!.options[1];
      expect(hoard.setsFlags, contains('craft.hoarded'));

      final hush = PetitionSystem.byId('dissentSilence')!.options[1];
      expect(hush.setsFlags, contains('village.hushed'));
    });

    test('her düğümün iki gerçek seçeneği ve bedeli var', () {
      for (final id in [
        'craftReturn', 'craftSchool', 'craftHoard',
        'dissentEcho', 'dissentSilence',
      ]) {
        final p = PetitionSystem.byId(id)!;
        expect(p.options.length, 2, reason: '$id iki yol sunmalı');
        final costly = p.options.any((o) =>
            o.moraleAmount != 0 ||
            o.goldDelta != 0 ||
            o.woodDelta != 0 ||
            o.estateMood.isNotEmpty);
        expect(costly, isTrue, reason: '$id bedelsiz olmamalı');
      }
    });
  });
}
