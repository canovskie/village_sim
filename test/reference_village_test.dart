import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/buildings/building_function.dart';
import 'package:village_sim/buildings/building_type.dart';
import 'package:village_sim/core/constants.dart';
import 'package:village_sim/systems/law_compass.dart';
import 'package:village_sim/world/reference_village_plan.dart';
import 'package:village_sim/world/season.dart';
import 'package:village_sim/world/world_generator.dart';

/// REFERANS KÖY — planın regresyon testi.
///
/// Kurulum kodu main.dart'ın part'ı olduğu için (UI'a bağlı) burada SAHNE
/// çalıştırılmaz; onun yerine planın kendisi doğrulanır: sabit tohumla üretilen
/// dünyada bu plan gerçekten kurulabilir mi, çakışma var mı, yatak nüfusa
/// eşit mi, köy politik olarak MERKEZ'de mi. Plan bozulursa (biri bir binayı
/// kaydırırsa) sessizce düşen bina yerine kırmızı test görünür.
void main() {
  int gc(int local) => kRefOx + local;
  int gr(int local) => kRefOy + local;

  ({int cols, int rows}) size(BuildingType t) {
    final m = kBuildingMeta[t]!;
    return (cols: m.cols, rows: m.rows);
  }

  group('referans köy planı', () {
    test('her yapı başlangıç bölgesinin (plan kutusu) içinde kalır', () {
      for (final (type, lc, lr) in kRefLayout) {
        final s = size(type);
        expect(lc, greaterThanOrEqualTo(0), reason: '${type.name} sola taştı');
        expect(lr, greaterThanOrEqualTo(0), reason: '${type.name} yukarı taştı');
        expect(lc + s.cols, lessThanOrEqualTo(kRefW),
            reason: '${type.name} sağa taştı');
        expect(lr + s.rows, lessThanOrEqualTo(kRefH),
            reason: '${type.name} aşağı taştı');
      }
    });

    test('hiçbir yapı bir diğerinin üstüne gelmez', () {
      final claimed = <(int, int), String>{};
      for (final (type, lc, lr) in kRefLayout) {
        final s = size(type);
        for (int c = lc; c < lc + s.cols; c++) {
          for (int r = lr; r < lr + s.rows; r++) {
            final prev = claimed[(c, r)];
            expect(prev, isNull,
                reason: '($c,$r): ${type.name} ile $prev çakışıyor');
            claimed[(c, r)] = type.name;
          }
        }
      }
    });

    test('tarlalar yapıların üstüne gelmez ve kutu içinde kalır', () {
      final claimed = <(int, int)>{};
      for (final (type, lc, lr) in kRefLayout) {
        final s = size(type);
        for (int c = lc; c < lc + s.cols; c++) {
          for (int r = lr; r < lr + s.rows; r++) {
            claimed.add((c, r));
          }
        }
      }
      int tiles = 0;
      for (final (c1, r1, c2, r2) in kRefFarms) {
        for (int c = c1; c <= c2; c++) {
          for (int r = r1; r <= r2; r++) {
            expect(claimed.contains((c, r)), isFalse,
                reason: 'tarla ($c,$r) bir yapının üstünde');
            expect(c, inInclusiveRange(0, kRefW - 1));
            expect(r, inInclusiveRange(0, kRefH - 1));
            tiles++;
          }
        }
      }
      // Değirmen + fırın döngüsünü besleyecek kadar tarla olmalı.
      expect(tiles, greaterThanOrEqualTo(30));
    });

    test('yatak sayısı hedef nüfusa eşit — ne evsiz ne boş ev', () {
      int beds = 0;
      for (final (type, _, _) in kRefLayout) {
        beds += kBuildingFunctions[type]?.housingCapacity ?? 0;
      }
      expect(beds, kRefPopulation);
    });

    test('köyün kilit sistemleri temsil edilir', () {
      final types = {for (final (t, _, _) in kRefLayout) t};
      for (final need in const [
        BuildingType.firepit, // ısı + toplanma
        BuildingType.well, // su çapası
        BuildingType.townhall, // yönetişim
        BuildingType.warehouse, // depo/taşıyıcı
        BuildingType.market, // ticaret
        BuildingType.tavern, // sosyal
        BuildingType.church, // inanç + cenaze
        BuildingType.barn, // sürü
        BuildingType.chickenCoop, // küçük hayvan
        BuildingType.mill, // un döngüsü
        BuildingType.lumberCamp, // odun
        BuildingType.fisherCabin, // balık
        BuildingType.floristCottage, // çiçek
        BuildingType.tailor, // kıyafet geçişi
        BuildingType.beehive, // bal
      ]) {
        expect(types, contains(need), reason: '${need.name} planda yok');
      }
    });
  });

  group('referans köy dünyası', () {
    test('sabit tohum: plan kutusuna su ya da maden düşmez', () {
      final w = WorldGenerator(kReferenceSeed).generate();
      for (final (type, lc, lr) in kRefLayout) {
        final s = size(type);
        for (int c = gc(lc); c < gc(lc) + s.cols; c++) {
          for (int r = gr(lr); r < gr(lr) + s.rows; r++) {
            expect(w.waterTiles.contains((c, r)), isFalse,
                reason: '${type.name} suyun üstünde ($c,$r)');
          }
        }
      }
      for (final n in w.mineNodes) {
        final inBox = n.col >= kRefOx &&
            n.col < kRefOx + kRefW &&
            n.row >= kRefOy &&
            n.row < kRefOy + kRefH;
        expect(inBox, isFalse, reason: 'maden plan kutusunda (${n.col},${n.row})');
      }
    });

    test('oduncu korusu kulübenin menzilinde ve su üstünde değil', () {
      final w = WorldGenerator(kReferenceSeed).generate();
      final camp = kRefLayout.firstWhere((e) => e.$1 == BuildingType.lumberCamp);
      final m = kBuildingMeta[BuildingType.lumberCamp]!;
      final cx = gc(camp.$2) + m.cols / 2.0;
      final cy = gr(camp.$3) + m.rows / 2.0;

      final (gc1, gr1, gc2, gr2) = kRefGrove;
      int planted = 0, inRange = 0;
      for (int dc = gc1; dc <= gc2; dc++) {
        for (int dr = gr1; dr <= gr2; dr++) {
          if ((dc + dr).isOdd) continue; // kurulumdaki satranç deseni
          final c = gc(dc), r = gr(dr);
          if (c < 1 || c >= kCols - 1 || r < 1 || r >= kRows - 1) continue;
          if (w.waterTiles.contains((c, r))) continue;
          planted++;
          final dx = c + 0.5 - cx, dy = r + 0.5 - cy;
          if (dx * dx + dy * dy <=
              kLumberTerritoryRadius * kLumberTerritoryRadius) {
            inRange++;
          }
        }
      }
      expect(planted, greaterThanOrEqualTo(12), reason: 'koru fazla seyrek');
      expect(inRange, greaterThan(0),
          reason: 'oduncu kulübesinin menzilinde ağaç yok — kurulamaz');
    });

    test('koru plan kutusunun dışında kalır (köyün içine ağaç dikmez)', () {
      final (gc1, gr1, gc2, gr2) = kRefGrove;
      expect(gc2, lessThan(0), reason: 'koru kutunun içine taşıyor');
      expect(gr1, greaterThanOrEqualTo(0));
      expect(gr2, lessThan(kRefH));
    });
  });

  group('referans köy kimliği', () {
    test('pusula MERKEZ — köy ılımlı başlar, testler istediği yöne iter', () {
      final pos = LawCompass.positionOf(kRefLaws.toSet());
      expect(pos.authority.abs(), lessThan(LawCompass.kBand),
          reason: 'otorite ekseni ölü bandın dışında (${pos.authority})');
      expect(pos.economy.abs(), lessThan(LawCompass.kBand),
          reason: 'iktisat ekseni ölü bandın dışında (${pos.economy})');
      expect(pos.faith, lessThan(LawCompass.kFaithBand),
          reason: 'iman boyası binmiş (${pos.faith})');
      expect(LawCompass.identify(pos).regime, VillageRegime.moderate);
    });

    test('kanunlar gerçekten var + her biri pusulada tanımlı', () {
      for (final id in kRefLaws) {
        expect(kLawVectors.containsKey(id), isTrue,
            reason: '$id pusula haritasında yok (yasa silinmiş olabilir)');
      }
      expect(kRefLaws.toSet().length, kRefLaws.length, reason: 'tekrar eden yasa');
    });
  });

  // ── Mevsimlik varyantlar ──────────────────────────────────────────────────
  // Godmode dört referans köy kurar (bkz. dev_panel). Mevsim gün sayacından
  // TÜREDİĞİ için varyantın doğruluğu tamamen takvim aritmetiğine bakar;
  // yanlış gün, sessizce "kış" diye yaz köyü kurar.
  group('mevsimlik referans varyantları', () {
    test('her varyantın günü GERÇEKTEN istenen mevsime düşer', () {
      for (final s in Season.values) {
        expect(seasonForDay(kReferenceDayFor(s)), s,
            reason: '${s.label} varyantı yanlış mevsime düşüyor');
      }
    });

    test('takvim hiç GERİ sarmaz — kronik geleceğe düşmesin', () {
      for (final s in Season.values) {
        expect(kReferenceDayFor(s), greaterThanOrEqualTo(kReferenceDay),
            reason: '${s.label} varyantı köyün geçmişinden öncesine gidiyor');
      }
    });

    test('dördü de mevsim içinde AYNI güne denk gelir (tek fark mevsim)', () {
      final pos = Season.values
          .map((s) => (kReferenceDayFor(s) - 1) % kDaysPerSeason)
          .toSet();
      expect(pos.length, 1, reason: 'varyantlar mevsim içinde farklı günlerde');
    });

    test('temel mevsim kanonik slotu kullanır, diğerleri ayrı slot', () {
      expect(kReferenceSlotIdFor(kReferenceBaseSeason), kReferenceSlotId);
      final ids = Season.values.map(kReferenceSlotIdFor).toSet();
      expect(ids.length, Season.values.length, reason: 'slotlar çakışıyor');
    });
  });
}
