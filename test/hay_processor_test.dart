import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/farm/farm_tile.dart';
import 'package:village_sim/systems/hay_processor.dart';
import 'package:village_sim/world/harman_site.dart';
import 'package:village_sim/world/hay_entity.dart';

void main() {
  group('harman placement', () {
    test('finds a 2x2 site outside and adjacent to the farm', () {
      final farm = [
        for (int c = 4; c <= 6; c++)
          for (int r = 4; r <= 6; r++) FarmTile(c, r),
      ];
      final farmTiles = {for (final tile in farm) (tile.col, tile.row)};

      final site = findHarmanSite(farm, farmTiles, cols: 12, rows: 12);

      expect(site, isNotNull);
      expect(site!.tiles.any(farmTiles.contains), isFalse);
      final isAdjacent = site.tiles.any(
        (yard) => farmTiles.any(
          (field) =>
              (yard.$1 - field.$1).abs() + (yard.$2 - field.$2).abs() == 1,
        ),
      );
      expect(isAdjacent, isTrue);
    });

    test('respects blocked tiles for the full footprint', () {
      final farm = [FarmTile(3, 3)];
      final blocked = <(int, int)>{
        (3, 3),
        for (int c = 0; c < 7; c++)
          for (int r = 0; r < 7; r++)
            if (!(c == 4 && r == 4) &&
                !(c == 5 && r == 4) &&
                !(c == 4 && r == 5) &&
                !(c == 5 && r == 5))
              (c, r),
      };

      final site = findHarmanSite(farm, blocked, cols: 7, rows: 7);

      expect((site!.col, site.row), (4, 4));
    });
  });

  group('processHayPiles', () {
    const site = HarmanSite(col: 10, row: 10);

    List<HayEntity> piles(int count, {bool inside = true}) => [
      for (int i = 0; i < count; i++)
        HayEntity(
          type: HayType.pile,
          gridX: inside ? 10.5 + (i % 2) : i.toDouble(),
          gridY: inside ? 10.5 + ((i ~/ 2) % 2) : 0,
        )..spawnTime = i.toDouble(),
    ];

    test('5 sheaves stay as sheaves', () {
      final hay = piles(5);

      processHayPiles(hay, [site]);

      expect(hay.where((h) => h.isBale), isEmpty);
      expect(hay, hasLength(5));
    });

    test('6 sheaves become one bale inside the yard', () {
      final hay = piles(6);

      processHayPiles(hay, [site], time: 42.5);

      expect(hay, hasLength(1));
      expect(hay.single.isBale, isTrue);
      expect(site.containsPoint(hay.single.gridX, hay.single.gridY), isTrue);
      expect(hay.single.spawnTime, 42.5);
    });

    test('loose sheaves outside the yard are never combined', () {
      final hay = piles(6, inside: false);

      processHayPiles(hay, [site]);

      expect(hay.where((h) => h.isBale), isEmpty);
      expect(hay, hasLength(6));
    });

    test('a reserved sheaf resumes its interrupted trip after load', () {
      final hay = piles(5)
        ..add(
          HayEntity(type: HayType.pile, gridX: 2.5, gridY: 2.5)
            ..spawnTime = 5
            ..targetHarmanCol = site.col
            ..targetHarmanRow = site.row,
        );

      processHayPiles(hay, [site]);

      expect(hay, hasLength(1));
      expect(hay.single.isBale, isTrue);
    });

    test('12 sheaves produce at most one bale per pass', () {
      final hay = piles(12);

      processHayPiles(hay, [site]);
      expect(hay.where((h) => h.isBale), hasLength(1));
      expect(hay.where((h) => !h.isBale), hasLength(6));

      processHayPiles(hay, [site]);
      expect(hay.where((h) => h.isBale), hasLength(2));
      expect(hay.where((h) => !h.isBale), isEmpty);
    });

    test('capacity includes incoming sheaves but frees outgoing bales', () {
      final hay = <HayEntity>[
        HayEntity(type: HayType.bale, gridX: 10.25, gridY: 10.25),
        HayEntity(type: HayType.bale, gridX: 10.75, gridY: 10.25),
      ];
      expect(harmanCanAccept(site, hay), isFalse);

      hay.first.isBeingCarried = true;
      expect(harmanCanAccept(site, hay), isTrue);

      hay.add(
        HayEntity(type: HayType.pile, gridX: 1, gridY: 1)
          ..isBeingCarried = true
          ..targetHarmanCol = site.col
          ..targetHarmanRow = site.row,
      );
      expect(harmanSheafLoad(site, hay), 7);
    });

    test('different yards never consume each other sheaves', () {
      const second = HarmanSite(col: 20, row: 20);
      final hay = piles(5)
        ..addAll([
          for (int i = 0; i < 5; i++)
            HayEntity(
              type: HayType.pile,
              gridX: 20.5 + (i % 2),
              gridY: 20.5 + ((i ~/ 2) % 2),
            ),
        ]);

      processHayPiles(hay, [site, second]);

      expect(hay.where((h) => h.isBale), isEmpty);
      expect(hay, hasLength(10));
    });

    test('FIFO consumes the oldest six sheaves', () {
      final hay = piles(8);

      processHayPiles(hay, [site]);

      final remaining = hay
          .where((h) => !h.isBale)
          .map((h) => h.spawnTime)
          .toList();
      expect(remaining, [6.0, 7.0]);
    });
  });
}
