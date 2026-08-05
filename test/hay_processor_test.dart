import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/farm/farm_tile.dart';
import 'package:village_sim/systems/hay_processor.dart';
import 'package:village_sim/world/hay_entity.dart';

void main() {
  group('processHayPiles', () {
    final farm = [
      for (int c = 14; c <= 18; c++)
        for (int r = 2; r <= 5; r++) FarmTile(c, r),
    ];
    // Demo tarla: c=14..18, r=2..5. Centroid (16, 3.5) → harman (16, 3) veya (16, 4).
    bool isHarmanArea(double x, double y) =>
        x >= 14 && x <= 19 && y >= 1 && y <= 6;

    test('5 pile → no bale yet', () {
      final hay = [
        for (int i = 0; i < 5; i++)
          HayEntity(type: HayType.pile, gridX: 16.0, gridY: 3.0)
            ..spawnTime = i.toDouble(),
      ];
      processHayPiles(hay, farm);
      expect(hay.where((h) => h.isBale).length, 0);
      expect(hay.length, 5);
    });

    test('6 pile → 1 bale at harman, piles removed', () {
      final hay = [
        for (int i = 0; i < 6; i++)
          HayEntity(type: HayType.pile, gridX: 16.0 + i * 0.1, gridY: 3.0)
            ..spawnTime = i.toDouble(),
      ];
      processHayPiles(hay, farm);
      final bales = hay.where((h) => h.isBale).toList();
      expect(bales.length, 1);
      expect(hay.where((h) => !h.isBale).length, 0);
      expect(isHarmanArea(bales.first.gridX, bales.first.gridY), isTrue);
    });

    test('new bale inherits scene time for its settle animation', () {
      final hay = [
        for (int i = 0; i < 6; i++)
          HayEntity(type: HayType.pile, gridX: 16.0, gridY: 3.0)
            ..spawnTime = i.toDouble(),
      ];
      processHayPiles(hay, farm, time: 42.5);
      expect(hay.single.spawnTime, 42.5);
    });

    test('distant piles still combine (no cluster requirement)', () {
      final hay = [
        HayEntity(type: HayType.pile, gridX: 0, gridY: 0)..spawnTime = 0,
        HayEntity(type: HayType.pile, gridX: 30, gridY: 0)..spawnTime = 1,
        HayEntity(type: HayType.pile, gridX: 0, gridY: 30)..spawnTime = 2,
        HayEntity(type: HayType.pile, gridX: 30, gridY: 30)..spawnTime = 3,
        HayEntity(type: HayType.pile, gridX: 15, gridY: 15)..spawnTime = 4,
        HayEntity(type: HayType.pile, gridX: 20, gridY: 5)..spawnTime = 5,
      ];
      processHayPiles(hay, farm);
      expect(hay.where((h) => h.isBale).length, 1);
    });

    test('12 pile → 1 bale per call (rate-limited)', () {
      final hay = [
        for (int i = 0; i < 12; i++)
          HayEntity(type: HayType.pile, gridX: 16.0, gridY: 3.0)
            ..spawnTime = i.toDouble(),
      ];
      processHayPiles(hay, farm);
      expect(hay.where((h) => h.isBale).length, 1);
      expect(hay.where((h) => !h.isBale).length, 6);
      processHayPiles(hay, farm);
      expect(hay.where((h) => h.isBale).length, 2);
      expect(hay.where((h) => !h.isBale).length, 0);
    });

    test('multiple bales do not overlap', () {
      final hay = <HayEntity>[];
      for (int round = 0; round < 4; round++) {
        for (int i = 0; i < 6; i++) {
          hay.add(
            HayEntity(type: HayType.pile, gridX: 16.0, gridY: 3.0)
              ..spawnTime = (round * 6 + i).toDouble(),
          );
        }
        processHayPiles(hay, farm);
      }
      final bales = hay.where((h) => h.isBale).toList();
      expect(bales.length, 4);
      // Hiçbir çift balya 0.45 birimden yakın olamaz (overlap eşiği).
      for (int i = 0; i < bales.length; i++) {
        for (int j = i + 1; j < bales.length; j++) {
          final dx = bales[i].gridX - bales[j].gridX;
          final dy = bales[i].gridY - bales[j].gridY;
          expect(
            dx * dx + dy * dy,
            greaterThanOrEqualTo(0.45 * 0.45),
            reason: 'bale $i and $j overlap',
          );
        }
      }
    });

    test('empty farmTiles → no conversion', () {
      final hay = [
        for (int i = 0; i < 10; i++)
          HayEntity(type: HayType.pile, gridX: 5, gridY: 5)
            ..spawnTime = i.toDouble(),
      ];
      processHayPiles(hay, []);
      expect(hay.where((h) => h.isBale).length, 0);
      expect(hay.length, 10);
    });

    test('FIFO: oldest 6 piles convert first', () {
      final hay = [
        for (int i = 0; i < 8; i++)
          HayEntity(type: HayType.pile, gridX: 16.0, gridY: 3.0)
            ..spawnTime = i.toDouble(),
      ];
      processHayPiles(hay, farm);
      final remaining = hay
          .where((h) => !h.isBale)
          .map((h) => h.spawnTime)
          .toList();
      expect(remaining, [6.0, 7.0]);
    });
  });
}
