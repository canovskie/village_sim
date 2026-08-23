import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/buildings/building_type.dart';
import 'package:village_sim/core/constants.dart';
import 'package:village_sim/main.dart' as game;
import 'package:village_sim/rendering/game_painter.dart';
import 'package:village_sim/rendering/tile_renderer.dart';
import 'package:village_sim/systems/decor_population.dart';
import 'package:village_sim/world/decor_entity.dart';
import 'package:village_sim/world/world_generator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in const [
      'xyz.luan/audioplayers',
      'xyz.luan/audioplayers.global',
      'plugins.flutter.io/shared_preferences',
      'plugins.flutter.io/path_provider',
    ]) {
      messenger.setMockMethodCallHandler(MethodChannel(channel), (call) async {
        if (call.method == 'getAll') return <String, Object>{};
        return null;
      });
    }
    messenger.setMockStreamHandler(
      const EventChannel('xyz.luan/audioplayers.global/events'),
      null,
    );

    game.kCaptureMode = true;
    game.kCaptureShowcase = false;
    game.kCaptureSceneReady = false;
    game.kProbeOn = false;
    game.kProbeNoEvents = true;
    game.kProbeNoImperial = true;
    game.kDevSpeedBoostOverride = 0;
  });

  tearDown(() {
    game.kCaptureMode = false;
    game.kCaptureSceneReady = false;
    game.kProbeNoEvents = false;
    game.kProbeNoImperial = false;
  });

  group('decor sınıflaması', () {
    test('çiçek ve yere yakın flora tek merkezden sınıflanır', () {
      const flowers = {
        DecorKind.daisy,
        DecorKind.poppy,
        DecorKind.lavender,
        DecorKind.buttercup,
        DecorKind.clover,
      };
      expect(DecorKind.values.where(isFlowerDecorKind).toSet(), flowers);
      expect(DecorKind.values.where(isGroundFloraDecorKind).toSet(), flowers);

      expect(isGroundFloraDecorKind(DecorKind.mushroomRed), isFalse);
      expect(isGroundFloraDecorKind(DecorKind.mushroomBrown), isFalse);
      expect(isGroundFloraDecorKind(DecorKind.bushSmall), isFalse);
      expect(isGroundFloraDecorKind(DecorKind.fallenLog), isFalse);
      expect(isGroundFloraDecorKind(DecorKind.stump), isFalse);
      expect(isGroundFloraDecorKind(DecorKind.pebble), isFalse);
    });
  });

  group('çiçek nüfus politikası', () {
    test('ambient sayı alan yerine alanın kareköküyle büyür', () {
      expect(ambientFlowerCount(10, kAmbientFlowerBaseArea), 10);
      expect(ambientFlowerCount(10, kAmbientFlowerBaseArea * 4), 20);
      expect(ambientFlowerCount(10, kAmbientFlowerBaseArea * 16), 40);
      expect(ambientFlowerCount(0, kAmbientFlowerBaseArea), 0);
    });

    test('köy payı kontrollü alt ve üst sınıra sahiptir', () {
      final ambient = ambientFlowerCount(
        kAmbientFlowerBaseCount,
        kAmbientFlowerBaseArea,
      );
      expect(
        flowerPopulationBudget(kAmbientFlowerBaseArea),
        ambient + kVillageFlowerBudgetMin,
      );
      expect(
        flowerPopulationBudget(kAmbientFlowerBaseArea, developedTiles: 100000),
        ambient + kVillageFlowerBudgetMax,
      );
      expect(
        remainingFlowerCapacity(
          currentFlowerCount: ambient + kVillageFlowerBudgetMax + 1,
          worldArea: kAmbientFlowerBaseArea,
          developedTiles: 100000,
        ),
        0,
      );
    });

    test('Chebyshev yarıçapı çapraz komşuyu da reddeder', () {
      const occupied = {(5, 5)};
      expect(hasGroundFloraBreathingRoom((5, 5), occupied), isFalse);
      expect(hasGroundFloraBreathingRoom((6, 5), occupied), isFalse);
      expect(hasGroundFloraBreathingRoom((6, 6), occupied), isFalse);
      expect(hasGroundFloraBreathingRoom((7, 5), occupied), isTrue);
      expect(hasGroundFloraBreathingRoom((6, 6), occupied, radius: 0), isTrue);
    });
  });

  group('dünya ambient çiçekleri', () {
    const seeds = [1, 7, 42, 1337, 90210];

    test('üst sınır içinde kalır ama tamamen kaybolmaz', () {
      final upperBound = ambientFlowerCount(
        kAmbientFlowerBaseCount,
        kCols * kRows,
      );
      for (final seed in seeds) {
        final flowers = WorldGenerator(
          seed,
        ).generate().decor.where((d) => isFlowerDecorKind(d.kind)).toList();
        expect(flowers, isNotEmpty, reason: 'tohum $seed çiçeksiz kaldı');
        expect(
          flowers.length,
          lessThanOrEqualTo(upperBound),
          reason: 'tohum $seed ambient çiçek bütçesini aştı',
        );
      }
    });

    test('çiçekler aynı veya komşu karelere yığılmaz', () {
      for (final seed in seeds) {
        final flowers = WorldGenerator(
          seed,
        ).generate().decor.where((d) => isFlowerDecorKind(d.kind)).toList();
        final seen = <(int, int)>{};
        for (final flower in flowers) {
          final tile = (flower.col, flower.row);
          expect(
            hasGroundFloraBreathingRoom(tile, seen),
            isTrue,
            reason: 'tohum $seed: $tile komşu çiçeğin üstüne yığıldı',
          );
          seen.add(tile);
        }
      }
    });

    test('aynı seed aynı dekor topolojisini üretir', () {
      for (final seed in seeds) {
        List<(int, int, DecorKind, int, double, double, int)> snapshot(
          WorldGeneratorResult world,
        ) => [
          for (final d in world.decor)
            (d.col, d.row, d.kind, d.variant, d.jitterX, d.jitterY, d.swaySeed),
        ];

        expect(
          snapshot(WorldGenerator(seed).generate()),
          snapshot(WorldGenerator(seed).generate()),
          reason: 'tohum $seed dekor topolojisi deterministik kalmalı',
        );
      }
    });

    test('üretilen dekor başka dünya yüzeyleriyle çakışmaz', () {
      for (final seed in seeds) {
        final world = WorldGenerator(seed).generate();
        final blocked = <(int, int)>{
          ...world.waterTiles,
          for (final tree in world.trees) (tree.col, tree.row),
          for (final mine in world.mineNodes) (mine.col, mine.row),
          for (final reed in world.reeds) ...[
            (reed.col, reed.row),
            (reed.col2, reed.row2),
          ],
          for (final site in world.landmarks) (site.col, site.row),
          for (final bush in world.berryBushes) (bush.col, bush.row),
        };
        final tiles = <(int, int)>{};
        for (final decor in world.decor) {
          final tile = (decor.col, decor.row);
          expect(
            blocked,
            isNot(contains(tile)),
            reason: 'tohum $seed: $tile başka bir yüzey tarafından sahipli',
          );
          expect(
            tiles.add(tile),
            isTrue,
            reason: 'tohum $seed: $tile iki ambient dekor taşıyor',
          );
        }
      }
    });
  });

  group('sahne dekor entegrasyonu', () {
    testWidgets('yeni dünya son yüzeylerden sonra sanitize edilir', (
      tester,
    ) async {
      final painter = await _bootVillage(tester);
      final flowers = painter.decor.where((d) => isFlowerDecorKind(d.kind));
      final blocked = <(int, int)>{
        ...painter.waterTiles,
        ...painter.wilderness,
        for (final tree in painter.trees) (tree.col, tree.row),
        for (final mine in painter.mineNodes)
          if (!mine.isDepleted) (mine.col, mine.row),
        for (final reed in painter.reeds) ...[
          (reed.col, reed.row),
          (reed.col2, reed.row2),
        ],
        for (final site in painter.landmarks) (site.col, site.row),
        for (final bush in painter.berryBushes) (bush.col, bush.row),
      };
      final seen = <(int, int)>{};
      for (final flower in flowers) {
        final tile = (flower.col, flower.row);
        expect(blocked, isNot(contains(tile)));
        expect(hasGroundFloraBreathingRoom(tile, seen), isTrue);
        seen.add(tile);
      }
      expect(seen, isNotEmpty);
      expect(
        seen.length,
        lessThanOrEqualTo(flowerPopulationBudget(kCols * kRows)),
      );
      expect(painter.decorVersion, greaterThan(0));
    });

    testWidgets(
      'eski kayıt sahipli yüzey, spacing ve bütçe sözleşmesine taşınır',
      (tester) async {
        final rawDecor = <Map<String, Object>>[];
        var seed = 0;
        for (var col = 2; col < kCols && rawDecor.length < 220; col += 2) {
          for (var row = 2; row < kRows && rawDecor.length < 220; row += 2) {
            rawDecor.add(_decorJson(col, row, DecorKind.daisy, seed++));
          }
        }

        const blockedFlowerTiles = [
          (11, 11), // bina
          (21, 21), // yol
          (31, 31), // tarla
          (41, 41), // şantiye
          (51, 51), // yol şantiyesi
          (61, 61), // ağaç
          (63, 63), // mezar
          (65, 65), // saz yatağı
        ];
        for (final tile in blockedFlowerTiles) {
          rawDecor.add(_decorJson(tile.$1, tile.$2, DecorKind.poppy, seed++));
        }
        // Bozuk eski kayıt: hacimli dekorla çiçek aynı tile'da. Hacimli olan
        // kalmalı, zemin florası düşmeli.
        rawDecor.add(_decorJson(71, 71, DecorKind.pebble, seed++));
        rawDecor.add(_decorJson(71, 71, DecorKind.buttercup, seed++));
        // Bilinçli kompozisyon: ikisi de aynı tile'da ve aynı sırada kalmalı.
        rawDecor.add(_decorJson(73, 73, DecorKind.stump, seed++));
        rawDecor.add(_decorJson(73, 73, DecorKind.fallenLog, seed++));

        final painter = await _bootVillage(
          tester,
          initialWorld: {
            'worldSeed': 42,
            'timeScale': 0,
            'landmarks': <Object>[],
            'buildings': [
              {'type': 'firepit', 'col': 11, 'row': 11},
            ],
            'orders': [
              {'type': 'woodenHouse', 'col': 41, 'row': 41, 'completed': false},
            ],
            'roads': [
              {'col': 21, 'row': 21, 'surface': 'dirt'},
            ],
            'roadOrders': [
              {'col': 51, 'row': 51, 'surface': 'dirt', 'completed': false},
            ],
            'farmTiles': [
              {'col': 31, 'row': 31},
            ],
            'trees': [
              {'col': 61, 'row': 61, 'type': 'pine'},
            ],
            'graves': [
              {'col': 63.0, 'row': 63.0, 'name': 'Eski mezar'},
            ],
            'reedBeds': [
              {'x': 65.2, 'y': 65.2, 'owner': -1},
            ],
            'resourceBoxes': [
              {'type': 'woodChunk', 'x': 67.2, 'y': 67.2, 'amount': 1},
            ],
            'hay': [
              {'type': 'pile', 'x': 69.2, 'y': 69.2},
            ],
            'lootCaches': [
              {'x': 75.2, 'y': 75.2, 'kind': 'food', 'amount': 1},
            ],
            'decor': rawDecor,
          },
        );

        for (final tile in blockedFlowerTiles) {
          expect(
            painter.decor.any(
              (d) =>
                  d.col == tile.$1 &&
                  d.row == tile.$2 &&
                  isFlowerDecorKind(d.kind),
            ),
            isFalse,
            reason: '$tile sahipli yüzeyde çiçek kalmamalı',
          );
        }
        expect(
          painter.decor
              .where((d) => d.col == 71 && d.row == 71)
              .map((d) => d.kind),
          orderedEquals([DecorKind.pebble]),
        );
        expect(
          painter.decor
              .where((d) => d.col == 73 && d.row == 73)
              .map((d) => d.kind),
          orderedEquals([DecorKind.stump, DecorKind.fallenLog]),
        );

        final flowers = painter.decor
            .where((d) => isFlowerDecorKind(d.kind))
            .toList();
        final seen = <(int, int)>{};
        for (final flower in flowers) {
          final tile = (flower.col, flower.row);
          expect(hasGroundFloraBreathingRoom(tile, seen), isTrue);
          seen.add(tile);
        }
        var developedTiles =
            painter.farmTiles.length + painter.roadSystem.count;
        for (final building in painter.buildings) {
          developedTiles += building.cols * building.rows;
        }
        for (final order in painter.pendingOrders) {
          if (order.completed) continue;
          final meta = kBuildingMeta[order.type]!;
          developedTiles += meta.cols * meta.rows;
        }
        expect(
          flowers.length,
          flowerPopulationBudget(kCols * kRows, developedTiles: developedTiles),
        );
        expect(painter.decorVersion, greaterThan(0));
      },
    );

    testWidgets(
      'geçici yükler kayıt açılışında dekor topolojisini değiştirmez',
      (tester) async {
        final painter = await _bootVillage(
          tester,
          initialWorld: {
            'worldSeed': 42,
            'timeScale': 0,
            'landmarks': <Object>[],
            'buildings': [
              {'type': 'firepit', 'col': 11, 'row': 11},
            ],
            'roads': [
              {'col': 21, 'row': 21, 'surface': 'dirt'},
            ],
            'resourceBoxes': [
              {'type': 'woodChunk', 'x': 67.2, 'y': 67.2, 'amount': 1},
              {'type': 'woodChunk', 'x': 73.2, 'y': 73.2, 'amount': 1},
            ],
            'hay': [
              {'type': 'pile', 'x': 69.2, 'y': 69.2},
            ],
            'lootCaches': [
              {'x': 75.2, 'y': 75.2, 'kind': 'food', 'amount': 1},
            ],
            'decor': [
              _decorJson(11, 11, DecorKind.daisy, 1),
              _decorJson(21, 21, DecorKind.poppy, 2),
              _decorJson(67, 67, DecorKind.lavender, 3),
              _decorJson(69, 69, DecorKind.buttercup, 4),
              _decorJson(75, 75, DecorKind.clover, 5),
              _decorJson(73, 73, DecorKind.stump, 6),
              _decorJson(73, 73, DecorKind.fallenLog, 7),
            ],
          },
        );

        for (final tile in const [(11, 11), (21, 21)]) {
          expect(
            painter.decor.any((d) => d.col == tile.$1 && d.row == tile.$2),
            isFalse,
            reason: '$tile kalıcı yüzey tarafından temizlenmeli',
          );
        }
        for (final tile in const [(67, 67), (69, 69), (75, 75)]) {
          expect(
            painter.decor.any(
              (d) =>
                  d.col == tile.$1 &&
                  d.row == tile.$2 &&
                  isGroundFloraDecorKind(d.kind),
            ),
            isTrue,
            reason: '$tile geçici yük yüzünden kayıt açılışında değişmemeli',
          );
        }
        expect(
          painter.decor
              .where((d) => d.col == 73 && d.row == 73)
              .map((d) => d.kind),
          orderedEquals([DecorKind.stump, DecorKind.fallenLog]),
        );
      },
    );
  });

  test('prosedürel mikro detay ve çiçek payı seyrektir', () {
    expect(kMicroDetailChancePercent, 14);
    expect(kMicroDetailKindCount, 8);
    expect(kMicroDetailFlowerKindCount, 1);
    expect(
      kMicroDetailFlowerKindCount / kMicroDetailKindCount,
      lessThanOrEqualTo(1 / 8),
    );
  });
}

Map<String, Object> _decorJson(int col, int row, DecorKind kind, int seed) => {
  'col': col,
  'row': row,
  'kind': kind.name,
  'variant': seed % 2,
  'jitterX': 0.0,
  'jitterY': 0.0,
  'swaySeed': seed,
};

Future<VillageGamePainter> _bootVillage(
  WidgetTester tester, {
  Map<String, dynamic>? initialWorld,
}) async {
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.runAsync(() async {
    await tester.pumpWidget(
      MaterialApp(
        home: game.VillageScene(
          initialWorld: initialWorld,
          slotId: 'decor-integration',
        ),
      ),
    );
    for (var i = 0; i < 1200 && !game.kCaptureSceneReady; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  });
  await tester.pump();
  expect(
    game.kCaptureSceneReady,
    isTrue,
    reason: 'sahne assetleri yüklenemedi',
  );

  final finder = find.byWidgetPredicate(
    (widget) => widget is CustomPaint && widget.painter is VillageGamePainter,
  );
  expect(finder, findsOneWidget);
  return tester.widget<CustomPaint>(finder).painter! as VillageGamePainter;
}
