import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/buildings/building_entity.dart';
import 'package:village_sim/buildings/building_function.dart';
import 'package:village_sim/buildings/building_type.dart';
import 'package:village_sim/core/resources.dart';
import 'package:village_sim/systems/building_specialization.dart';
import 'package:village_sim/systems/building_system.dart';
import 'package:village_sim/systems/villager_morale.dart';

/// Bina işlevlerinin GERÇEKTEN bağlı olduğunu doğrular. Buradaki regresyon
/// koruması iki yönlü:
///  1. Panelde gösterilen sayı ile simülasyonun okuduğu sayı aynı yerden gelir
///     (civicValue → amenityMorale → köylü moral hedefi).
///  2. Pazar geliri koşulsuz basılmaz — fazla yoksa kasa dolmaz.
void main() {
  BuildingEntity b(BuildingType t, [int c = 0, int r = 0]) =>
      BuildingEntity(type: t, col: c, row: r);

  group('amenite morali', () {
    test('bina yoksa katkı da yok', () {
      expect(amenityMoraleFrom(const {}), 0.0);
      expect(computeVillageStats(const []).amenityMorale, 0.0);
    });

    test('moral binası OLMAYAN tür ağırlık taşımaz', () {
      expect(moraleWeightOf(BuildingType.warehouse), 0.0);
      expect(moraleWeightOf(BuildingType.stable), 0.0); // civic ama lojistik
      expect(moraleWeightOf(BuildingType.townhall), 0.0); // civic ama etkisiz
      for (final t in [
        BuildingType.bathhouse,
        BuildingType.monument,
        BuildingType.caravanserai,
        BuildingType.belltower,
      ]) {
        expect(moraleWeightOf(t), 0.0,
            reason: '$t artık moral yığını değil özgün işlevini taşır');
      }
      expect(amenityMoraleFrom({BuildingType.warehouse: 3}), 0.0);
    });

    test('taverna/kilise/çiçekçi artık gerçekten sayılır', () {
      // Regresyon: bunlar eskiden panelde +18/+12/+10% gösterip sime HİÇ
      // girmiyordu (sabit "kültür binası" listesinde yoklardı).
      for (final t in [
        BuildingType.tavern,
        BuildingType.church,
        BuildingType.floristCottage,
        BuildingType.well,
      ]) {
        expect(amenityMoraleFrom({t: 1}), greaterThan(0.0), reason: '$t');
      }
    });

    test('ağırlık sırası korunur: taverna > kütüphane > türbe', () {
      final tavern = amenityMoraleFrom({BuildingType.tavern: 1});
      final library = amenityMoraleFrom({BuildingType.library: 1});
      final shrine = amenityMoraleFrom({BuildingType.shrine: 1});
      expect(tavern, greaterThan(library));
      expect(library, closeTo(shrine, 1e-9));
    });

    test('tek bina hissedilir, tavan aşılmaz', () {
      final one = amenityMoraleFrom({BuildingType.tavern: 1});
      expect(one, greaterThan(0.05)); // ilk taverna kayda değer
      final all = amenityMoraleFrom({
        for (final t in BuildingType.values)
          if (moraleWeightOf(t) > 0) t: 4,
      });
      expect(all, lessThanOrEqualTo(kAmenityMoraleCap));
      expect(all, greaterThan(kAmenityMoraleCap * 0.9)); // doyuma yaklaşır
    });

    test('aynı türün ikincisi çeşitlilikten az katar', () {
      final twoSame = amenityMoraleFrom({BuildingType.library: 2});
      final twoDiff =
          amenityMoraleFrom({BuildingType.library: 1, BuildingType.shrine: 1});
      expect(twoDiff, greaterThan(twoSame));
      // …ama ikincisi yine de bir şey katar (sıfır değil).
      expect(twoSame, greaterThan(amenityMoraleFrom({BuildingType.library: 1})));
    });

    test('computeVillageStats sayımı bina listesinden yapar', () {
      final stats = computeVillageStats([
        b(BuildingType.tavern),
        b(BuildingType.tavern, 4),
        b(BuildingType.library, 8),
        b(BuildingType.warehouse, 12), // amenite değil
      ]);
      expect(
        stats.amenityMorale,
        closeTo(
          amenityMoraleFrom(
              {BuildingType.tavern: 2, BuildingType.library: 1}),
          1e-9,
        ),
      );
    });

    test('moral formülüne birebir eklenir', () {
      MoraleEval eval(double amenity) => evaluateVillagerMorale(
            homeless: false,
            starving: false,
            lowWater: false,
            cold: false,
            houseMood: 0.55,
            elderRespected: false,
            amenityMorale: amenity,
          );
      expect(eval(0.12).target - eval(0.0).target, closeTo(0.12, 1e-9));
    });
  });

  group('kuyu/şadırvan', () {
    test('ikisi de su kaynağı sayılır', () {
      final stats = computeVillageStats(
          [b(BuildingType.well), b(BuildingType.fountain, 4)]);
      expect(stats.wellCount, 2);
    });
  });

  group('pazar geliri', () {
    ResourceBundle stock({int food = 0, int wood = 0, int gold = 0}) =>
        ResourceBundle(food: food, wood: wood, gold: gold);

    test('fazla yoksa gelir yok', () {
      expect(marketBaseIncome(stock()), 0);
      expect(marketBaseIncome(stock(food: kMarketSurplusFloor)), 0);
    });

    test('taban üstü fazla gelir üretir, tavanla sınırlı', () {
      expect(marketBaseIncome(stock(food: kMarketSurplusFloor + 1)), 1);
      expect(marketBaseIncome(stock(food: 100000)), kMarketMaxIncome);
    });

    test('fazla arttıkça gelir monoton artar', () {
      var prev = 0;
      for (var extra = 0; extra <= 400; extra += 40) {
        final v = marketBaseIncome(stock(food: kMarketSurplusFloor + extra));
        expect(v, greaterThanOrEqualTo(prev));
        prev = v;
      }
    });

    test('altın ve saz fazlaya sayılmaz', () {
      expect(marketBaseIncome(stock(gold: 5000)), 0);
      expect(marketBaseIncome(ResourceBundle(reed: 5000)), 0);
    });

    test('boş ambarda tick altın basmaz, tezgâh boş görünür', () {
      final s = stock(gold: 10);
      final market = b(BuildingType.market);
      updateBuildings(
          dt: kMarketIncomeInterval + 1, buildings: [market], stockpile: s);
      expect(s.gold, 10);
      expect(market.isActive, isFalse);
    });

    test('fazla varken tick altın basar', () {
      final s = stock(food: kMarketSurplusFloor + 200, gold: 0);
      final market = b(BuildingType.market);
      updateBuildings(
          dt: kMarketIncomeInterval + 1, buildings: [market], stockpile: s);
      expect(s.gold, greaterThan(0));
      expect(market.isActive, isTrue);
    });

    test('ikinci pazar aynı fazlayı ikinci kez tam satamaz', () {
      // Tek pazar
      final s1 = stock(food: kMarketSurplusFloor + 200);
      updateBuildings(
          dt: kMarketIncomeInterval + 1,
          buildings: [b(BuildingType.market)],
          stockpile: s1);
      // İki pazar
      final s2 = stock(food: kMarketSurplusFloor + 200);
      updateBuildings(
          dt: kMarketIncomeInterval + 1,
          buildings: [b(BuildingType.market), b(BuildingType.market, 6)],
          stockpile: s2);
      expect(s2.gold, greaterThan(s1.gold)); // ikinci pazar işe yarar
      expect(s2.gold, lessThan(s1.gold * 2)); // ama iki katı değil
      expect(marketShare(1), lessThan(marketShare(0)));
    });
  });

  group('taşıyıcı hızı', () {
    test('ahır lojistik verir; han artık aynı etkiyi kopyalamaz', () {
      final one = computeVillageStats([b(BuildingType.stable)]);
      expect(one.carrierSpeedMultiplier, closeTo(1.15, 1e-9));
      final withInn = computeVillageStats(
          [b(BuildingType.stable), b(BuildingType.caravanserai, 4)]);
      expect(withInn.carrierSpeedMultiplier, closeTo(1.15, 1e-9));
    });
  });

  group('geç dönem uzmanlaşmaları', () {
    test('seçilen dört bina farklı etki türü taşır', () {
      expect(kBuildingFunctions[BuildingType.bathhouse]!.civicEffect,
          CivicEffect.recovery);
      expect(kBuildingFunctions[BuildingType.monument]!.civicEffect,
          CivicEffect.legacy);
      expect(kBuildingFunctions[BuildingType.caravanserai]!.civicEffect,
          CivicEffect.visitorTrade);
      expect(kBuildingFunctions[BuildingType.belltower]!.civicEffect,
          CivicEffect.alarm);
    });

    test('hamam yalnız hasta varken ve odun varsa külhan yakar', () {
      final idle = stepBathhouseFuel(
          secondsLeft: 0, dt: 1, woodAvailable: 10, hasPatient: false);
      expect(idle.active, isFalse);
      expect(idle.woodUsed, 0);

      final lit = stepBathhouseFuel(
          secondsLeft: 0, dt: 1, woodAvailable: 1, hasPatient: true);
      expect(lit.active, isTrue);
      expect(lit.woodUsed, kBathhouseFuelWood);
      expect(lit.secondsLeft, kBathhouseFuelSeconds);

      final cold = stepBathhouseFuel(
          secondsLeft: 0, dt: 1, woodAvailable: 0, hasPatient: true);
      expect(cold.active, isFalse);
      expect(bathhouseRecoveryRate(cold.active), 1.0);
      expect(bathhouseRecoveryRate(lit.active), 2.0);
      expect(bathhouseIllnessRisk(lit.active), lessThan(1.0));
    });

    test('anıt dikildiği günün iki kimliğini tek yazıda saklar', () {
      expect(
        monumentInscription(
          regimeTitle: 'Açık Pazar',
          houseIdentity: 'Demirhan Hanesi',
          day: 42,
        ),
        'Açık Pazar · Demirhan Hanesi · 42. gün',
      );
    });

    test('çan yalnız kapsadığı suçta muhafız menzilini genişletir', () {
      expect(
        withinBuildingEffect(
          type: BuildingType.belltower,
          col: 10,
          row: 10,
          targetX: 18,
          targetY: 10,
        ),
        isTrue,
      );
      expect(bellGuardResponseRange(16, covered: false), 16);
      expect(bellGuardResponseRange(16, covered: true), closeTo(25.6, 1e-9));
    });

    test('han ziyaret aralığını kısaltır, konaklamayı uzatır', () {
      expect(merchantVisitGap(100, hasCaravanserai: true), 65);
      expect(merchantVisitDuration(100, hasCaravanserai: true), 155);
      expect(merchantVisitGap(100, hasCaravanserai: false), 100);
    });

    test('iki taş konut stratejik değil kozmetik varyanttır', () {
      final blueMeta = kBuildingMeta[BuildingType.stoneHouseBlue]!;
      final greenMeta = kBuildingMeta[BuildingType.stoneHouseGreen]!;
      final blueFn = kBuildingFunctions[BuildingType.stoneHouseBlue]!;
      final greenFn = kBuildingFunctions[BuildingType.stoneHouseGreen]!;
      expect(blueMeta.cost.entries, greenMeta.cost.entries);
      expect(blueFn.housingCapacity, greenFn.housingCapacity);
      expect(blueFn.role, greenFn.role);
      expect(blueFn.summary, contains('kozmetik varyant'));
      expect(greenFn.summary, contains('kozmetik varyant'));
    });
  });

  group('depo kapasitesi', () {
    test('ambar tavanı yükseltir, stok kırpılır', () {
      final s = ResourceBundle(wood: 100000);
      final stats = updateBuildings(
          dt: 0.1, buildings: [b(BuildingType.warehouse)], stockpile: s);
      expect(stats.stockCapacity, kBaseStockCapacity + 180);
      expect(s.wood, stats.stockCapacity);
    });
  });
}
