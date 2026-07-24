import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/core/constants.dart';
import 'package:village_sim/entities/farm_farmer.dart';
import 'package:village_sim/farm/farm_tile.dart';
import 'package:village_sim/world/season.dart';

/// Çiftçiyi belirli bir duruma varana dek (ya da süre dolana dek) sür.
void _run(FarmFarmer f, List<FarmTile> tiles, {required double seconds}) {
  const dt = 0.05;
  final steps = (seconds / dt).round();
  for (int i = 0; i < steps; i++) {
    f.update(dt, tiles, Random(1));
    for (final t in tiles) {
      t.update(dt, Season.spring);
    }
  }
}

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

  group('FarmFarmer ekim döngüsü', () {
    test('boşta çiftçi ekilmemiş tarlaya gider ve eker', () {
      final tiles = [FarmTile(5, 5)];
      final f = FarmFarmer(startCol: 5.5, startRow: 5.5);

      f.update(0.05, tiles, Random(1));
      expect(f.state, FarmerState.walkingToSow);
      expect(tiles.first.beingSown, isTrue);

      _run(f, tiles, seconds: kFarmSowDuration + 2.0);
      expect(tiles.first.needsSowing, isFalse);
      expect(tiles.first.isGrowing, isTrue);
      expect(f.state, FarmerState.idle);
    });

    test('nadastaki tarla ekim hedefi olmaz', () {
      final tiles = [FarmTile(5, 5)..harvest(fallowSeconds: 30.0)];
      final f = FarmFarmer(startCol: 5.5, startRow: 5.5);

      f.update(0.05, tiles, Random(1));
      expect(f.state, FarmerState.idle);
      expect(tiles.first.beingSown, isFalse);
    });

    test('olgun ekin ekimden önce gelir (hasat önceliği)', () {
      final ready = FarmTile(5, 5)..sow();
      ready.stage = 4;
      final bare = FarmTile(6, 5); // ekim bekliyor
      final tiles = [bare, ready]; // sırayı kasten ters ver

      final f = FarmFarmer(startCol: 5.5, startRow: 5.5);
      f.update(0.05, tiles, Random(1));

      expect(f.state, FarmerState.walkingToFarm);
      expect(ready.beingHarvested, isTrue);
      expect(bare.beingSown, isFalse);
    });

    test('hasat → saman düşer, tarla yeniden ekim ister', () {
      final t = FarmTile(5, 5)..sow();
      t.stage = 4;
      final tiles = [t];
      final f = FarmFarmer(startCol: 5.5, startRow: 5.5);

      (int, int)? hay;
      const dt = 0.05;
      for (int i = 0; i < 400 && hay == null; i++) {
        f.update(dt, tiles, Random(1));
        hay ??= f.harvestHayPos;
      }
      expect(hay, isNotNull, reason: 'hasat samanı düşmeli');
      expect(t.needsSowing, isTrue);
    });

    test('releaseClaim tarlanın biçiliyor/ekiliyor bayrağını bırakır', () {
      final harvest = FarmTile(5, 5)..sow();
      harvest.stage = 4;
      final sow = FarmTile(6, 5);
      final f1 = FarmFarmer(startCol: 5.5, startRow: 5.5);
      final f2 = FarmFarmer(startCol: 6.5, startRow: 5.5);

      f1.update(0.05, [harvest], Random(1));
      f2.update(0.05, [sow], Random(1));
      expect(harvest.beingHarvested, isTrue);
      expect(sow.beingSown, isTrue);

      f1.releaseClaim();
      f2.releaseClaim();
      expect(harvest.beingHarvested, isFalse);
      expect(sow.beingSown, isFalse);
      // Bırakılan tile yeniden hedeflenebilir olmalı.
      expect(harvest.readyToHarvest, isTrue);
      expect(sow.readyToSow, isTrue);
    });

    test('irrigate:false → çiftçi su turuna çıkmaz, ekimle ilgilenir', () {
      final tiles = [FarmTile(5, 5)];
      final f = FarmFarmer(startCol: 5.5, startRow: 5.5);
      // Kuyu/anchor verilmese de irrigate:false yolu güvenli olmalı.
      for (int i = 0; i < 60; i++) {
        f.update(0.05, tiles, Random(1), irrigate: false);
      }
      expect(f.state, isNot(FarmerState.walkingToWell));
      expect(f.state, isNot(FarmerState.fetchingWater));
      expect(tiles.first.needsSowing, isFalse); // yine de ekti
    });

    test('kışta çiftçi ne eker ne biçer', () {
      final tiles = [FarmTile(5, 5)];
      final f = FarmFarmer(startCol: 5.5, startRow: 5.5);
      for (int i = 0; i < 40; i++) {
        f.update(0.05, tiles, Random(1), farmingActive: false);
      }
      expect(f.state, FarmerState.idle);
      expect(tiles.first.needsSowing, isTrue);
    });
  });
}
