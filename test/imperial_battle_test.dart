import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/systems/events/imperial.dart';
import 'package:village_sim/systems/events/imperial_battle.dart';

BattleFighter fighter(
  int id,
  BattleSide side,
  double x, {
  double power = 18,
  double armor = .1,
  double health = 100,
}) => BattleFighter(
  id: id,
  side: side,
  name: 'Kişi $id',
  x: x,
  y: 0,
  postX: x,
  postY: 0,
  power: power,
  armor: armor,
  maxHealth: health,
);
ImperialBattle battle(
  List<BattleFighter> fighters, {
  ImperialDefensePlan plan = ImperialDefensePlan.counterCharge,
}) => ImperialBattle(
  fighters: fighters,
  plan: plan,
  objectiveX: 8,
  objectiveY: 0,
  exitX: -8,
  exitY: 0,
  seed: 17,
);
void finish(ImperialBattle b, {double dt = .05}) {
  for (var i = 0; i < 10000 && b.result == null; i++) {
    b.tick(dt);
  }
}

void main() {
  test(
    'distant combatants cause no remote damage and have no preselected winner',
    () {
      final b = battle([
        fighter(0, BattleSide.village, 0),
        fighter(1, BattleSide.empire, 20),
      ]);
      b.tick(1);
      expect(b.result, isNull);
      expect(b.hits, 0);
      expect(b.fighters.every((f) => f.health == f.maxHealth), isTrue);
    },
  );
  test('moving out of reach during windup evades the strike', () {
    final a = fighter(0, BattleSide.village, 0),
        d = fighter(1, BattleSide.empire, .9);
    final b = battle([a, d]);
    b.tick(.04);
    expect(a.action, BattleAction.windingUp);
    d.x = 10;
    b.tick(.7, move: (_, _, _, _, _) {});
    expect(d.health, d.maxHealth);
    expect(b.hits, 0);
  });
  test('walls prevent damage even inside weapon range', () {
    final b = battle([
      fighter(0, BattleSide.village, 0),
      fighter(1, BattleSide.empire, .8),
    ]);
    b.tick(5, move: (_, _, _, _, _) {}, clearLine: (_, _, _, _) => false);
    expect(b.hits, 0);
  });
  test('actual equipment and health change who wins', () {
    final strong = battle([
      fighter(0, BattleSide.village, 0, power: 38, armor: .4),
      fighter(1, BattleSide.empire, 1),
    ]);
    final weak = battle([
      fighter(0, BattleSide.village, 0, power: 8, health: 45),
      fighter(1, BattleSide.empire, 1),
    ]);
    finish(strong);
    finish(weak);
    expect(strong.result, BattleResult.held);
    expect(weak.result, BattleResult.overrun);
    expect(strong.hits, greaterThan(0));
    expect(weak.hits, greaterThan(0));
  });
  test('fixed step outcome is independent of render frame rate', () {
    ImperialBattle make() => battle([
      fighter(0, BattleSide.village, 0),
      fighter(1, BattleSide.empire, 1),
    ]);
    final a = make(), b = make();
    finish(a, dt: 1 / 60);
    finish(b, dt: .2);
    expect(a.result, b.result);
    expect(a.hits, b.hits);
    expect(a.fighters[0].health, closeTo(b.fighters[0].health, .00001));
  });
  test('survivors acquire a new opponent after a fighter falls', () {
    final a = fighter(0, BattleSide.village, 0, power: 100);
    final b = battle([
      a,
      fighter(1, BattleSide.empire, 1, health: 20),
      fighter(2, BattleSide.empire, 2),
    ]);
    for (var i = 0; i < 300 && b.fighters[1].active; i++) {
      b.tick(.05);
    }
    for (var i = 0; i < 30; i++) {
      b.tick(.05);
    }
    expect(a.target, 2);
  });
  test('an unopposed objective can fall while defenders still live', () {
    final b = battle([
      fighter(0, BattleSide.village, -20),
      fighter(1, BattleSide.empire, 8),
    ]);
    b.tick(7, move: (_, _, _, _, _) {});
    expect(b.result, BattleResult.overrun);
    expect(b.hits, 0);
    expect(b.activeCount(BattleSide.village), 1);
  });
  test(
    'saving mid-strike preserves damage, initiative and the eventual outcome',
    () {
      final original = battle([
        fighter(0, BattleSide.village, 0),
        fighter(1, BattleSide.empire, 1),
      ], plan: ImperialDefensePlan.barricade);
      original.tick(2.37);
      original.plan = ImperialDefensePlan.counterCharge;
      final restored = ImperialBattle.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );
      expect(restored.toJson(), original.toJson());
      finish(original);
      finish(restored);
      expect(restored.toJson(), original.toJson());
      expect(restored.hasBarricade, isTrue);
    },
  );

  test('withdrawal stops new attacks immediately', () {
    final b = battle([
      fighter(0, BattleSide.village, 0),
      fighter(1, BattleSide.empire, 1),
    ]);
    b.tick(.1);
    b.withdraw();
    b.tick(20);
    expect(b.result, BattleResult.withdrawn);
    expect(b.hits, 0);
  });
  test(
    'a landed strike displaces the victim and survives a mid-recoil save',
    () {
      final original = battle([
        fighter(0, BattleSide.village, 0),
        fighter(1, BattleSide.empire, .9),
      ]);
      for (var i = 0; i < 120 && original.impacts.isEmpty; i++) {
        original.tick(1 / 30);
      }
      expect(original.impacts, isNotEmpty);
      final hit = original.impacts.first;
      final victim = hit.defender;
      final dx = victim.x - hit.attacker.x;
      final dy = victim.y - hit.attacker.y;
      expect(victim.body.vx * dx + victim.body.vy * dy, greaterThan(0));
      final x = victim.x, y = victim.y;
      final restored = ImperialBattle.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );
      original.tick(1 / 30);
      restored.tick(1 / 30);
      expect((victim.x - x) * dx + (victim.y - y) * dy, greaterThan(0));
      expect(restored.toJson(), original.toJson());
    },
  );
  test('unreachable fronts terminate without fabricated injuries', () {
    final b = battle([
      fighter(0, BattleSide.village, 0),
      fighter(1, BattleSide.empire, 20),
    ]);
    b.tick(91, move: (_, _, _, _, _) {});
    expect(b.result, BattleResult.held);
    expect(b.hits, 0);
  });
}
