import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/core/constants.dart';
import 'package:village_sim/farm/farm_tile.dart';
import 'package:village_sim/world/season.dart';

void main() {
  group('FarmTile ekim → büyüme → hasat → nadas', () {
    test('yeni tarla ekilmeyi bekler; ekilmeden büyümez', () {
      final t = FarmTile(3, 3);
      expect(t.needsSowing, isTrue);
      expect(t.isGrowing, isFalse);

      for (int i = 0; i < 200; i++) {
        t.update(0.5, Season.spring); // 100 sn = tam bir hasat döngüsü
      }
      expect(t.stage, 0);
      expect(t.growthProgress, 0.0);
    });

    test('ekilen tarla büyür', () {
      final t = FarmTile(3, 3)..sow();
      expect(t.isGrowing, isTrue);

      for (int i = 0; i < 100; i++) {
        t.update(0.5, Season.spring); // 50 sn → 2 aşama (25 sn/aşama)
      }
      expect(t.stage, 2);
    });

    test('hasat tarlayı çıplak bırakır → yeniden ekim ister', () {
      final t = FarmTile(3, 3)..sow();
      t.stage = 4;
      expect(t.readyToHarvest, isTrue);

      t.harvest();
      expect(t.stage, 0);
      expect(t.needsSowing, isTrue);
      expect(t.readyToSow, isTrue);
      expect(t.isGrowing, isFalse);
    });

    test('nadas: süre dolmadan ekilemez, dolunca ekilebilir', () {
      final t = FarmTile(3, 3)..sow();
      t.stage = 4;
      t.harvest(fallowSeconds: kFarmFallowDuration);

      expect(t.readyToSow, isFalse, reason: 'toprak dinleniyor');
      t.update(kFarmFallowDuration - 1.0, Season.spring);
      expect(t.readyToSow, isFalse);
      t.update(2.0, Season.spring);
      expect(t.readyToSow, isTrue);
    });

    test('nadas kışın da işler (donmuş toprak da dinlenmiş sayılır)', () {
      final t = FarmTile(3, 3)..harvest(fallowSeconds: 10.0);
      t.update(11.0, Season.winter);
      expect(t.readyToSow, isTrue);
    });

    test('kış: ekili tarla donar, büyüme durur', () {
      final t = FarmTile(3, 3)..sow();
      for (int i = 0; i < 100; i++) {
        t.update(0.5, Season.winter);
      }
      expect(t.stage, 0);
      expect(t.growthProgress, 0.0);
    });

    test('sulama kuraklığı iptal eder — yazın sulu ekin susuzdan hızlı', () {
      final dry = FarmTile(1, 1)..sow();
      final wet = FarmTile(2, 2)..sow();
      wet.boostGrowth(30.0);
      expect(wet.isWatered, isTrue);

      for (int i = 0; i < 40; i++) {
        dry.update(0.5, Season.summer);
        wet.update(0.5, Season.summer);
      }
      expect(wet.growthProgress, greaterThan(dry.growthProgress));
    });

    test('nudgeGrowth su sayacını tüketmez (müşterek harman tuzağı)', () {
      final t = FarmTile(1, 1)..sow();
      t.boostGrowth(9.0);
      for (int i = 0; i < 50; i++) {
        t.nudgeGrowth(0.001);
      }
      expect(t.isWatered, isTrue, reason: 'nudge dt tüketmemeli');
    });

    test('nudgeGrowth ekilmemiş tarlayı büyütmez', () {
      final t = FarmTile(1, 1); // needsSowing
      t.nudgeGrowth(0.5);
      expect(t.growthProgress, 0.0);
    });
  });
}
