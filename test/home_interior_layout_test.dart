import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/systems/npc/home_interior.dart';

String signature(HomeInteriorLayout layout) => layout.furniture
    .map((f) => '${f.kind}:${f.x},${f.y},${f.width},${f.depth},${f.transposed}')
    .join('|');

void main() {
  test('ev konumları tekil tohum alır, aynı evin planı yeniden üretilir', () {
    final seeds = <int>{}, designs = <String>{}, plans = <int>{};
    for (int col = -5; col < 15; col++) {
      for (int row = -5; row < 15; row++) {
        final seed = HomeInteriorLayout.seedForHome(col, row);
        expect(seeds.add(seed), isTrue);
        final first = HomeInteriorLayout.fromSeed(seed);
        final restored = HomeInteriorLayout.fromSeed(seed);
        expect(signature(first), signature(restored));
        expect(first.planIndex, restored.planIndex);
        designs.add(signature(first));
        plans.add(first.planIndex);
      }
    }
    expect(plans.length, HomeInteriorLayout.planCount);
    expect(
      designs.length,
      seeds.length,
      reason: 'örnek köyde kopya iç düzen olmamalı',
    );
  });

  test('tüm planlarda eşya sınırları ve fiziksel çakışmalar güvenlidir', () {
    for (int seed = 0; seed < 100; seed++) {
      for (int plan = 0; plan < HomeInteriorLayout.planCount; plan++) {
        final layout = HomeInteriorLayout.fromSeed(seed, plan: plan);
        for (final f in layout.furniture) {
          final context = 'seed=$seed plan=$plan ${f.kind}';
          expect(f.x, greaterThanOrEqualTo(0), reason: context);
          expect(f.y, greaterThanOrEqualTo(0), reason: context);
          expect(
            f.x + f.width,
            lessThanOrEqualTo(HomeInteriorLayout.width),
            reason: context,
          );
          expect(
            f.y + f.depth,
            lessThanOrEqualTo(HomeInteriorLayout.depth),
            reason: context,
          );
          if (!f.blocksWalking) continue;
          for (final other in layout.furniture.where(
            (o) => o.blocksWalking && !identical(o, f),
          )) {
            final overlapX =
                min(f.x + f.width, other.x + other.width) - max(f.x, other.x);
            final overlapY =
                min(f.y + f.depth, other.y + other.depth) - max(f.y, other.y);
            expect(
              overlapX > .001 && overlapY > .001,
              isFalse,
              reason: '$context / ${other.kind} çakışması',
            );
          }
        }
      }
    }
  });

  test(
    'bütün ev planlarında her eylem hedefi ulaşılabilir, yollar köşe kesmez',
    () {
      for (int seed = 0; seed < 12; seed++) {
        for (int plan = 0; plan < HomeInteriorLayout.planCount; plan++) {
          final layout = HomeInteriorLayout.fromSeed(seed, plan: plan);
          for (int slot = 0; slot < 2; slot++) {
            var from = layout.target(slot, InteriorActivity.walking);
            for (final activity in [
              ...InteriorActivity.values,
              ...InteriorActivity.values.reversed,
            ]) {
              final target = layout.target(slot, activity);
              final route = layout.route(from, target);
              final context = 'seed=$seed plan=$plan slot=$slot $activity';
              expect(route, isNotEmpty, reason: context);
              for (final point in route) {
                for (int i = 0; i <= 25; i++) {
                  expect(
                    layout.walkable(
                      from.x + (point.x - from.x) * i / 25,
                      from.y + (point.y - from.y) * i / 25,
                    ),
                    isTrue,
                    reason: context,
                  );
                }
                from = point;
              }
              expect(from, target);
            }
          }
        }
      }
    },
  );

  test('altı planda simülasyon yeni masasına ve kendi yatağına varır', () {
    for (int plan = 0; plan < HomeInteriorLayout.planCount; plan++) {
      final layout = HomeInteriorLayout.fromSeed(73, plan: plan);
      final simulation = HomeInteriorSimulation(layout: layout);
      for (final scenario in [
        InteriorScenario.supper,
        InteriorScenario.sleep,
        InteriorScenario.hearth,
      ]) {
        simulation.setScenario(scenario);
        for (int tick = 0; tick < 700; tick++) {
          simulation.update(.05);
          for (final a in simulation.actors) {
            expect(
              layout.walkable(a.x, a.y),
              isTrue,
              reason: 'plan=$plan $scenario',
            );
          }
        }
        expect(
          simulation.actors.every(
            (a) => a.path.isEmpty && a.activity == a.destination,
          ),
          isTrue,
        );
        for (final a in simulation.actors) {
          expect(a.position, layout.target(a.slot, a.activity));
        }
      }
    }
  });
}
