import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/buildings/building_lore.dart';
import 'package:village_sim/buildings/building_type.dart';
import 'package:village_sim/systems/hearth_warmth.dart';

/// İNŞA KÜNYESİ bekçisi.
///
/// Künye oyuncuya "nereye kurmalıyım"ı öğreten tek yüzey; iki şekilde bozulur:
///  1. Yeni bir bina eklenir, künyesi yazılmaz → oyuncu o binada bilgisiz kalır.
///  2. İpucu metni ile canlı doğrulama ayrışır → künye "✓" derken sim başka
///     şey yapar (bkz. ALTIN KURAL, building_function).
/// Bu testler ikisini de yakalar.
void main() {
  group('künye kapsamı', () {
    test('dikilebilen her binanın künyesi var', () {
      final missing = <BuildingType>[];
      for (final type in kBuildingMeta.keys) {
        if (loreOf(type) == null) missing.add(type);
      }
      expect(missing, isEmpty,
          reason: 'künyesiz bina: ${missing.map((t) => t.name).join(', ')}');
    });

    test('her künyede en az bir ipucu ve iki tatlı not var', () {
      for (final entry in kBuildingLore.entries) {
        expect(entry.value.tips, isNotEmpty,
            reason: '${entry.key.name}: ipucu yok');
        // Tek not = "tek string yazma" kuralının ihlali (voice.dart): aynı
        // binaya ikinci kez bakan aynı cümleyi görürdü.
        expect(entry.value.notes.length, greaterThanOrEqualTo(2),
            reason: '${entry.key.name}: not havuzu tek cümlelik');
      }
    });

    test('künye yalnız dikilebilen binaları anlatır', () {
      for (final type in kBuildingLore.keys) {
        expect(kBuildingMeta.containsKey(type), isTrue,
            reason: '${type.name} inşa edilemez ama künyesi var');
      }
    });
  });

  group('tatlı not', () {
    test('aynı tohum aynı notu verir (kare kare titremez)', () {
      final a = sweetNote(BuildingType.tent, 3);
      final b = sweetNote(BuildingType.tent, 3);
      expect(a, isNotNull);
      expect(a, b);
    });

    test('tohum ilerleyince havuz döner', () {
      final seen = <String>{};
      for (var i = 0; i < 6; i++) {
        final n = sweetNote(BuildingType.tent, i);
        if (n != null) seen.add(n);
      }
      expect(seen.length, greaterThan(1));
    });
  });

  group('canlı doğrulama', () {
    test('çadır: ocağın sıcağı ipucunu açar, uzaklık kapatır', () {
      final tips = loreOf(BuildingType.tent)!.tips;
      final hearth = tips.firstWhere((t) => t.kind == SiteTipKind.hearth);

      // Ocağın dibi: sıcaklık 1.0 (bkz. hearth_warmth).
      expect(
        tipState(hearth, const SiteFacts(hearthWarmth: 1.0, hasHearth: true,
            hearthLit: true)),
        SiteTipState.met,
      );
      // Köyün ucu: ocağın faydası bitmiş.
      expect(
        tipState(hearth, const SiteFacts(hearthWarmth: 0.0, hasHearth: true,
            hearthLit: true)),
        SiteTipState.unmet,
      );
      // Eşik: moral/uyku sistemiyle AYNI sınırı kullanır.
      expect(
        tipState(
            hearth,
            const SiteFacts(
                hearthWarmth: kColdShelterThreshold,
                hasHearth: true,
                hearthLit: true)),
        SiteTipState.met,
      );
    });

    test('ocak yok / sönük ise künye sebebini yazar', () {
      final hearth = loreOf(BuildingType.tent)!
          .tips
          .firstWhere((t) => t.kind == SiteTipKind.hearth);
      expect(tipValue(hearth, const SiteFacts()), 'ocak yok');
      expect(tipValue(hearth, const SiteFacts(hasHearth: true)), 'ocak sönük');
    });

    test('oduncu ve maden ipuçları KURAL olarak işaretli', () {
      final forest = loreOf(BuildingType.lumberCamp)!
          .tips
          .firstWhere((t) => t.kind == SiteTipKind.forest);
      final vein = loreOf(BuildingType.mineBuilding)!
          .tips
          .firstWhere((t) => t.kind == SiteTipKind.oreVein);
      expect(forest.rule, isTrue);
      expect(vein.rule, isTrue);
      // Sağlanmadığında künye "!" (kurulamaz) der, sakin "○" değil.
      expect(tipState(forest, const SiteFacts()), SiteTipState.unmet);
      expect(tipState(forest, const SiteFacts(treesNear: 1)), SiteTipState.met);
      expect(tipState(vein, const SiteFacts(onVein: true)), SiteTipState.met);
    });

    test('balıkçı: kıyı eşiği', () {
      final shore = loreOf(BuildingType.fisherCabin)!
          .tips
          .firstWhere((t) => t.kind == SiteTipKind.shore);
      expect(tipState(shore, const SiteFacts(shoreDist: kShoreNearTiles)),
          SiteTipState.met);
      expect(tipState(shore, const SiteFacts(shoreDist: kShoreNearTiles + 1)),
          SiteTipState.unmet);
      expect(tipState(shore, const SiteFacts()), SiteTipState.unmet);
    });

    test('menzilsiz bina ipucu nötr kalır (yanlış ✓ göstermez)', () {
      final anywhere = loreOf(BuildingType.stable)!
          .tips
          .firstWhere((t) => t.kind == SiteTipKind.anywhere);
      expect(tipState(anywhere, const SiteFacts()), SiteTipState.neutral);
      expect(tipValue(anywhere, const SiteFacts()), isNull);
    });
  });

  group('geç dönem künyeleri', () {
    String joined(BuildingType type) =>
        loreOf(type)!.tips.map((t) => t.text).join(' ');

    test('seçilen binalar gerçek yeni işlevlerini söyler', () {
      expect(joined(BuildingType.bathhouse), contains('günde 1 odun'));
      expect(joined(BuildingType.monument), contains('Vakanüvis kroniğine'));
      expect(joined(BuildingType.belltower), contains('12 tile'));
      expect(joined(BuildingType.caravanserai), contains('%35 daha sık'));
    });

    test('taş konutlar kozmetik eş olduklarını açıkça söyler', () {
      expect(joined(BuildingType.stoneHouseBlue), contains('kozmetik varyant'));
      expect(joined(BuildingType.stoneHouseGreen), contains('kozmetik varyant'));
    });
  });

  group('bal hızı — tek kaynak', () {
    test('çiçeksiz kovan 1.0, her çiçek arttırır, tavan var', () {
      expect(honeySpeedFromFlowers(0), 1.0);
      expect(honeySpeedFromFlowers(1), closeTo(1.0 + kHoneyFlowerSpeedStep, 1e-9));
      expect(honeySpeedFromFlowers(1000), kHoneySpeedMax);
    });

    test('kovan künyesi ölçülen çarpanı gösterir', () {
      final flowers = loreOf(BuildingType.beehive)!
          .tips
          .firstWhere((t) => t.kind == SiteTipKind.flowers);
      final label = tipValue(flowers, const SiteFacts(flowersNear: 5));
      expect(label, contains('5 çiçek'));
      expect(label,
          contains('×${honeySpeedFromFlowers(5).toStringAsFixed(1)}'));
    });
  });
}
