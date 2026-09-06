import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/systems/npc/npc_body.dart';
import 'package:village_sim/systems/npc/npc_gait.dart';

void main() {
  test('bodies accelerate and brake instead of changing speed instantly', () {
    final b = NpcBody(id: 0, x: 0, y: 0);
    b.advance(1 / 60, 10, 0, 2);
    expect(b.speed, inExclusiveRange(0, .2));
    for (var i = 0; i < 60; i++) {
      b.advance(1 / 60, 10, 0, 2);
    }
    expect(b.speed, closeTo(2, .01));
    final before = b.x;
    b.advance(1 / 60, b.x, b.y, 0);
    expect(b.x, greaterThan(before), reason: 'braking retains momentum');
    for (var i = 0; i < 60; i++) {
      b.advance(1 / 60, b.x, b.y, 0);
    }
    expect(b.speed, closeTo(0, .001));
  });
  test('the same impulse moves a heavier NPC less', () {
    final light = NpcBody(id: 0, x: 0, y: 0, mass: 60);
    final heavy = NpcBody(id: 1, x: 0, y: 0, mass: 120);
    light.impulse(120, 0);
    heavy.impulse(120, 0);
    expect(light.vx, heavy.vx * 2);
    for (var i = 0; i < 12; i++) {
      light.advance(1 / 60, light.x, light.y, 0);
      heavy.advance(1 / 60, heavy.x, heavy.y, 0);
    }
    expect(light.x, greaterThan(heavy.x));
  });
  test('footprint sweep stops a large impulse at a thin wall', () {
    final b = NpcBody(id: 0, x: 0, y: 0)..impulse(6000, 0);
    bool clear(double ax, double ay, double bx, double by) => max(ax, bx) < 1;
    b.advance(.1, b.x, b.y, 0, clearPath: clear);
    expect(b.x + b.radius, lessThan(1));
    expect(b.vx, 0);
  });
  test('a glancing collision slides along the free wall tangent', () {
    final b = NpcBody(id: 0, x: 0, y: 0);
    bool clear(double ax, double ay, double bx, double by) => max(ax, bx) < 1;
    for (var i = 0; i < 120; i++) {
      b.advance(1 / 60, 5, 5, 2, clearPath: clear);
    }
    expect(b.x + b.radius, lessThan(1));
    expect(b.y, greaterThan(1));
  });
  test(
    'inelastic contacts conserve momentum without adding kinetic energy',
    () {
      final a = NpcBody(id: 0, x: 0, y: 0, mass: 60)..vx = 2;
      final b = NpcBody(id: 1, x: .4, y: 0, mass: 120)..vx = -1;
      final momentum = a.mass * a.vx + b.mass * b.vx;
      final energy = a.mass * pow(a.speed, 2) + b.mass * pow(b.speed, 2);
      NpcBody.solveContacts([a, b], 1 / 30);
      expect(a.mass * a.vx + b.mass * b.vx, closeTo(momentum, .001));
      expect(
        a.mass * pow(a.speed, 2) + b.mass * pow(b.speed, 2),
        lessThan(energy),
      );
      expect(b.x - a.x, greaterThan(.4));
    },
  );
  test('coincident bodies unstick with bounded displacement', () {
    final bodies = [for (var i = 0; i < 10; i++) NpcBody(id: i, x: 5, y: 5)];
    NpcBody.solveContacts(bodies, 1 / 30);
    for (final b in bodies) {
      expect(
        sqrt(pow(b.x - 5, 2) + pow(b.y - 5, 2)),
        lessThanOrEqualTo(.100001),
      );
    }
    expect(bodies.any((b) => b.x != 5 || b.y != 5), isTrue);
  });
  test('separation cannot push an actor through a wall', () {
    final a = NpcBody(id: 0, x: .31, y: 0);
    final b = NpcBody(id: 1, x: .4, y: 0);
    for (var i = 0; i < 20; i++) {
      NpcBody.solveContacts(
        [a, b],
        1 / 30,
        clearPath: (ax, ay, bx, by) => ax >= 0 && bx >= 0,
      );
    }
    expect(a.x - a.radius, greaterThanOrEqualTo(0));
  });
  test('stance foot remains on the floor while the swing foot lifts', () {
    for (var i = -16; i <= 16; i++) {
      final stance = npcLegPose(-6, i / 10, 0);
      final swing = npcLegPose(6, i / 10, 1.6);
      expect(stance.ankle.$2, -5);
      expect(swing.ankle.$2, lessThan(stance.ankle.$2));
      for (final p in [stance, swing]) {
        expect(
          sqrt(pow(p.hip.$1 - p.knee.$1, 2) + pow(p.hip.$2 - p.knee.$2, 2)),
          closeTo(17, .001),
        );
        expect(
          sqrt(pow(p.ankle.$1 - p.knee.$1, 2) + pow(p.ankle.$2 - p.knee.$2, 2)),
          closeTo(17, .001),
        );
      }
    }
  });
}
