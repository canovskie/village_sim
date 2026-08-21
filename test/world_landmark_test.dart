import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/core/resources.dart';
import 'package:village_sim/world/world_generator.dart';
import 'package:village_sim/world/world_landmark.dart';

void main() {
  group('harita ilgi noktaları', () {
    test('her dünya hem küçük bonus hem küçük bela üretir', () {
      for (var seed = 1; seed <= 30; seed++) {
        final sites = WorldGenerator(seed).generate().landmarks;
        expect(sites.length, 5, reason: 'seed=$seed');
        final effects = sites.map((s) => landmarkEffect(s.outcome));
        expect(effects.any((e) => e.isBoon), isTrue, reason: 'seed=$seed');
        expect(effects.any((e) => !e.isBoon), isTrue, reason: 'seed=$seed');
      }
    });

    test('yerler başlangıç alanının dışında, açılım boyunca sıralıdır', () {
      double spanNeeded(int c, int r) {
        const cols = 128, rows = 128;
        final du = ((c - r) - (cols - rows) / 2).abs();
        final dv = ((c + r) - (cols + rows - 2) / 2).abs();
        final su = du * 1.86, sv = dv * 1.65;
        return su > sv ? su : sv;
      }

      for (var seed = 1; seed <= 30; seed++) {
        final spans =
            WorldGenerator(seed)
                .generate()
                .landmarks
                .map((s) => spanNeeded(s.col, s.row))
                .toList()
              ..sort();
        expect(spans.first, greaterThanOrEqualTo(54), reason: 'seed=$seed');
        expect(spans.last, greaterThanOrEqualTo(94), reason: 'seed=$seed');
        expect(spans.last, lessThanOrEqualTo(110), reason: 'seed=$seed');
      }
    });

    test('etkiler omurga ekonomisini sarsmayacak kadar küçüktür', () {
      for (final outcome in LandmarkOutcome.values) {
        final e = landmarkEffect(outcome);
        expect(e.resourceDelta.abs(), lessThanOrEqualTo(7));
        expect(e.moraleDelta.abs(), lessThanOrEqualTo(0.03));
      }
      expect(
        landmarkEffect(LandmarkOutcome.oldCoin).resource,
        ResourceKind.gold,
      );
    });

    test('keşif bayrağı varsayılan olarak kapalıdır', () {
      final site = WorldLandmark(
        col: 4,
        row: 7,
        kind: WorldLandmarkKind.sunkenCellar,
        outcome: LandmarkOutcome.oldCoin,
      );
      expect(site.discovered, isFalse);
      site.discovered = true;
      expect(site.discovered, isTrue);
      expect(site.depth, 11.7);
    });
  });
}
