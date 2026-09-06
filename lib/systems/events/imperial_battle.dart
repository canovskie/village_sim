import 'dart:math';

import '../npc/npc_body.dart';
import 'imperial.dart';

enum BattleSide { village, empire }

enum BattleAction {
  advancing,
  windingUp,
  striking,
  recovering,
  recoiling,
  fleeing,
  down,
}

enum BattleResult { held, overrun, withdrawn }

/// One real person on the map. No winner, choreography lane or timeline is
/// supplied: strikes are resolved only after a wind-up and a range check.
class BattleFighter {
  final int id;
  final BattleSide side;
  final String name;
  final double maxHealth, power, armor, reach, speed;
  final bool commander;
  final double postX, postY;
  final NpcBody body;
  double get x => body.x;
  set x(double value) => body.x = value;
  double get y => body.y;
  set y(double value) => body.y = value;
  double health, resolve, stamina = 1;
  double windupDuration = .4, downTime = 0;
  bool strikeLanded = false;
  double get swing => switch (action) {
    BattleAction.windingUp => -.18 * (1 - timer / windupDuration).clamp(0, 1),
    BattleAction.striking => sin(pi * (1 - timer / .22).clamp(0, 1)),
    _ => 0,
  };
  double timer = 0;
  int? target;
  int swings = 0;
  BattleAction action = BattleAction.advancing;

  BattleFighter({
    required this.id,
    required this.side,
    required this.name,
    required double x,
    required double y,
    double? mass,
    required this.postX,
    required this.postY,
    this.maxHealth = 100,
    this.power = 18,
    this.armor = 0.1,
    this.reach = 1.05,
    this.speed = 1.5,
    this.resolve = 0.8,
    this.commander = false,
  }) : body = NpcBody(
         id: id,
         x: x,
         y: y,
         mass: mass ?? 70 + armor * 100 + (commander ? 15 : 0),
       ),
       health = maxHealth;

  Map<String, dynamic> toJson() => {
    'id': id,
    'side': side.name,
    'name': name,
    'x': x,
    'y': y,
    'postX': postX,
    'postY': postY,
    'maxHealth': maxHealth,
    'health': health,
    'power': power,
    'armor': armor,
    'reach': reach,
    'speed': speed,
    'resolve': resolve,
    'stamina': stamina,
    'commander': commander,
    'timer': timer,
    'target': target,
    'swings': swings,
    'action': action.name,
    'mass': body.mass,
    'vx': body.vx,
    'vy': body.vy,
    'windupDuration': windupDuration,
    'strikeLanded': strikeLanded,
    'downTime': downTime,
  };

  factory BattleFighter.fromJson(Map<String, dynamic> j) =>
      BattleFighter(
          id: j['id'] as int,
          side: BattleSide.values.byName(j['side'] as String),
          name: j['name'] as String,
          x: (j['x'] as num).toDouble(),
          y: (j['y'] as num).toDouble(),
          postX: (j['postX'] as num).toDouble(),
          postY: (j['postY'] as num).toDouble(),
          maxHealth: (j['maxHealth'] as num).toDouble(),
          power: (j['power'] as num).toDouble(),
          armor: (j['armor'] as num).toDouble(),
          reach: (j['reach'] as num).toDouble(),
          speed: (j['speed'] as num).toDouble(),
          resolve: (j['resolve'] as num).toDouble(),
          commander: j['commander'] as bool,
          mass: (j['mass'] as num?)?.toDouble(),
        )
        ..health = (j['health'] as num).toDouble()
        ..stamina = (j['stamina'] as num).toDouble()
        ..timer = (j['timer'] as num).toDouble()
        ..target = j['target'] as int?
        ..swings = j['swings'] as int
        ..action = BattleAction.values.byName(j['action'] as String)
        ..windupDuration = (j['windupDuration'] as num?)?.toDouble() ?? .4
        ..strikeLanded = j['strikeLanded'] as bool? ?? false
        ..downTime = (j['downTime'] as num?)?.toDouble() ?? 0
        ..body.vx = (j['vx'] as num?)?.toDouble() ?? 0
        ..body.vy = (j['vy'] as num?)?.toDouble() ?? 0;

  bool get active => health > 0 && action != BattleAction.fleeing;
  double distanceTo(BattleFighter b) => distance(b.x, b.y);
  double distance(double tx, double ty) =>
      sqrt(pow(x - tx, 2) + pow(y - ty, 2));
}

class BattleImpact {
  final BattleFighter attacker, defender;
  final double damage;
  final bool blocked;
  const BattleImpact(this.attacker, this.defender, this.damage, this.blocked);
}

typedef BattleMove =
    void Function(
      BattleFighter fighter,
      double x,
      double y,
      double dt,
      double speed,
    );

typedef BattleWaypoint =
    (double, double) Function(BattleFighter f, double x, double y);

/// Fixed-step, local combat. The scene supplies pathfinding; tests can use the
/// same simulation on open ground. Weather changes footing, formations change
/// pursuit and protection, and nearby allies sustain morale.
class ImperialBattle {
  final List<BattleFighter> fighters;
  final double objectiveX, objectiveY, exitX, exitY;
  final double rain, darkness;
  final int seed;
  final bool hasBarricade;
  ImperialDefensePlan plan;
  BattleResult? result;
  double elapsed = 0, occupation = 0, _accumulator = 0;
  int hits = 0;
  String report = 'Savunucular bulundukları yerden hatta koşuyor.';
  final List<BattleImpact> impacts = [];

  ImperialBattle({
    required this.fighters,
    required this.plan,
    required this.objectiveX,
    required this.objectiveY,
    required this.exitX,
    required this.exitY,
    this.rain = 0,
    this.darkness = 0,
    this.seed = 1,
  }) : hasBarricade = plan == ImperialDefensePlan.barricade;

  Map<String, dynamic> toJson() => {
    'fighters': fighters.map((f) => f.toJson()).toList(),
    'plan': plan.name,
    'hasBarricade': hasBarricade,
    'objectiveX': objectiveX,
    'objectiveY': objectiveY,
    'exitX': exitX,
    'exitY': exitY,
    'rain': rain,
    'darkness': darkness,
    'seed': seed,
    'result': result?.name,
    'elapsed': elapsed,
    'occupation': occupation,
    'accumulator': _accumulator,
    'hits': hits,
    'report': report,
  };

  factory ImperialBattle.fromJson(Map<String, dynamic> j) =>
      ImperialBattle(
          fighters: (j['fighters'] as List)
              .map(
                (f) =>
                    BattleFighter.fromJson(Map<String, dynamic>.from(f as Map)),
              )
              .toList(),
          plan: j['hasBarricade'] == true
              ? ImperialDefensePlan.barricade
              : ImperialDefensePlan.values.byName(j['plan'] as String),
          objectiveX: (j['objectiveX'] as num).toDouble(),
          objectiveY: (j['objectiveY'] as num).toDouble(),
          exitX: (j['exitX'] as num).toDouble(),
          exitY: (j['exitY'] as num).toDouble(),
          rain: (j['rain'] as num).toDouble(),
          darkness: (j['darkness'] as num).toDouble(),
          seed: j['seed'] as int,
        )
        ..plan = ImperialDefensePlan.values.byName(j['plan'] as String)
        ..result = j['result'] == null
            ? null
            : BattleResult.values.byName(j['result'] as String)
        ..elapsed = (j['elapsed'] as num).toDouble()
        ..occupation = (j['occupation'] as num).toDouble()
        .._accumulator = (j['accumulator'] as num).toDouble()
        ..hits = j['hits'] as int
        ..report = j['report'] as String;

  int activeCount(BattleSide side) =>
      fighters.where((f) => f.side == side && f.active).length;
  double strength(BattleSide side) => fighters
      .where((f) => f.side == side && f.active)
      .fold(0.0, (sum, f) => sum + f.health / f.maxHealth * (.4 + f.resolve));
  double get balance {
    final a = strength(BattleSide.village), b = strength(BattleSide.empire);
    return a + b == 0 ? .5 : a / (a + b);
  }

  void withdraw() {
    if (result != null) return;
    for (final f in fighters.where(
      (f) => f.side == BattleSide.village && f.active,
    )) {
      f.action = BattleAction.fleeing;
    }
    result = BattleResult.withdrawn;
    report = 'Geri çekilme emri verildi; köy hattı bırakıyor.';
  }

  void tick(
    double dt, {
    BattleMove? move,
    BattleWaypoint? waypoint,
    bool Function(double, double, double, double)? clearLine,
  }) {
    impacts.clear();
    if (result != null || dt <= 0 || !dt.isFinite) return;
    _accumulator += dt;
    while (_accumulator + 1e-9 >= 1 / 30 && result == null) {
      _accumulator -= 1 / 30;
      final clear = clearLine ?? (_, _, _, _) => true;
      void physicalMove(
        BattleFighter f,
        double x,
        double y,
        double dt,
        double speed,
      ) {
        final goal = speed > 0 && waypoint != null ? waypoint(f, x, y) : (x, y);
        f.body.advance(
          dt,
          goal.$1,
          goal.$2,
          speed,
          traction: 1 - rain * .3,
          clearPath: clear,
        );
      }

      _step(1 / 30, move ?? physicalMove, clear);
      if (move == null) {
        NpcBody.solveContacts(
          fighters.map((f) => f.body).toList(),
          1 / 30,
          clearPath: clear,
        );
      }
    }
  }

  double _roll(BattleFighter f, int salt) =>
      ((seed * 31 + f.id * 7919 + f.swings * 104729 + salt * 1543) & 0xffff) /
      65535;

  void _step(
    double dt,
    BattleMove move,
    bool Function(double, double, double, double) clearLine,
  ) {
    elapsed += dt;
    // Alternate initiative each step; list order never gives one side every
    // first strike. Every target is revalidated at the moment of contact.
    final order = (elapsed * 30).round().isEven ? fighters : fighters.reversed;
    for (final f in order) {
      f.body.planted =
          f.action != BattleAction.advancing &&
          f.action != BattleAction.fleeing;
      if (f.health <= 0) {
        f.action = BattleAction.down;
        f.downTime += dt;
        move(f, f.x, f.y, dt, 0);
        continue;
      }
      f.timer = max(0, f.timer - dt);
      f.stamina = min(1, f.stamina + dt * .1);
      if (f.action == BattleAction.fleeing) {
        move(
          f,
          f.side == BattleSide.empire ? exitX : objectiveX,
          f.side == BattleSide.empire ? exitY : objectiveY,
          dt,
          f.speed * 1.25,
        );
        continue;
      }
      if (f.action == BattleAction.recoiling ||
          f.action == BattleAction.recovering) {
        if (f.timer > 0) {
          move(f, f.x, f.y, dt, 0);
          continue;
        }
        f.action = BattleAction.advancing;
      }
      BattleFighter? target;
      for (final other in fighters) {
        if (other.id == f.target && other.active) {
          target = other;
          break;
        }
      }
      if (f.action == BattleAction.windingUp) {
        move(f, f.x, f.y, dt, 0);
        if (f.timer > 0) continue;
        f.action = BattleAction.striking;
        f.timer = .22;
        f.strikeLanded = false;
        continue;
      }
      if (f.action == BattleAction.striking) {
        move(f, f.x, f.y, dt, 0);
        if (!f.strikeLanded && f.timer <= .11) {
          f.strikeLanded = true;
          f.swings++;
          if (target != null &&
              f.distanceTo(target) <= f.reach + .12 &&
              clearLine(f.x, f.y, target.x, target.y)) {
            _strike(f, target);
          }
        }
        if (f.timer <= 0) {
          f.action = BattleAction.recovering;
          f.timer = .55 + (1 - f.stamina) * .55;
        }
        continue;
      }
      // Select nearby enemies and spread pressure across the front. Surviving
      // reserves naturally replace a fallen opponent instead of waiting.
      final previousTarget = target;
      double best = double.infinity;
      target = null;
      for (final other in fighters) {
        if (other.side == f.side || !other.active) continue;
        final crowd = fighters
            .where((a) => a.active && a.target == other.id)
            .length;
        final score = f.distanceTo(other) + crowd * .65;
        if (score < best) {
          best = score;
          target = other;
        }
      }
      if (previousTarget != null &&
          target != null &&
          f.distanceTo(previousTarget) < f.distanceTo(target) + 1.1) {
        target = previousTarget;
      }
      f.target = target?.id;
      if (target == null) continue;
      final d = f.distanceTo(target);
      if (d <= f.reach && clearLine(f.x, f.y, target.x, target.y)) {
        f.action = BattleAction.windingUp;
        f.timer =
            .32 + darkness * .1 + (1 - f.stamina) * .16 + _roll(f, 1) * .16;
        f.windupDuration = f.timer;
        move(f, f.x, f.y, dt, 0);
        continue;
      }
      final defensive =
          f.side == BattleSide.village &&
          plan != ImperialDefensePlan.counterCharge;
      double tx = target.x, ty = target.y;
      if (defensive && target.distance(f.postX, f.postY) > 3.2) {
        tx = f.postX;
        ty = f.postY;
      } else if (f.side == BattleSide.empire && d > 4) {
        tx = objectiveX;
        ty = objectiveY;
      } else {
        // A small side approach produces flanks when another fighter already
        // occupies the direct route, without scripted pair slots.
        final allies = fighters.where(
          (a) =>
              a != f && a.active && a.side == f.side && a.distanceTo(f) < .65,
        );
        for (final ally in allies) {
          tx += (f.y - ally.y) * .7;
          ty -= (f.x - ally.x) * .7;
        }
      }
      final charging =
          f.side == BattleSide.village &&
          plan == ImperialDefensePlan.counterCharge;
      // Leave room for the weapon, so approach decelerates into a fighting
      // stance instead of running straight into the opponent's centre.
      if (tx == target.x && ty == target.y && d > .01) {
        tx -= (target.x - f.x) / d * f.reach * .8;
        ty -= (target.y - f.y) / d * f.reach * .8;
      }
      move(f, tx, ty, dt, f.speed * (1 - rain * .2) * (charging ? 1.22 : 1));
    }
    final village = activeCount(BattleSide.village),
        empire = activeCount(BattleSide.empire);
    if (empire == 0) {
      result = BattleResult.held;
      report = 'İmparatorluk birliği dağıldı; köy hattı tuttu.';
    } else if (village == 0) {
      result = BattleResult.overrun;
      report = 'Savunma hattında savaşabilecek kimse kalmadı.';
    } else {
      final occupying = fighters.any(
        (f) =>
            f.side == BattleSide.empire &&
            f.active &&
            f.distance(objectiveX, objectiveY) < 1.5,
      );
      final contested = fighters.any(
        (f) =>
            f.side == BattleSide.village &&
            f.active &&
            f.distance(objectiveX, objectiveY) < 3,
      );
      occupation = (occupation + (occupying && !contested ? dt : -dt * .5))
          .clamp(0, 6);
      if (occupation >= 6) {
        result = BattleResult.overrun;
        report = 'Askerler savunmayı aşıp hedefi ele geçirdi.';
      } else if (elapsed >= 90) {
        // A blocked route or stalemate cannot hold the game forever. Failure
        // to take the objective forces the expedition to abandon its attack.
        result = BattleResult.held;
        report = 'Birlik hedefe ulaşamadı; saldırıyı kesip geri çekiliyor.';
      }
    }
  }

  void _strike(BattleFighter a, BattleFighter b) {
    final localAllies = fighters
        .where(
          (f) =>
              f != b && f.side == b.side && f.active && f.distanceTo(b) < 2.5,
        )
        .length;
    final atPost = b.distance(b.postX, b.postY) < 2;
    final cover = b.side == BattleSide.village && hasBarricade && atPost
        ? .25
        : 0.0;
    final holding =
        b.side == BattleSide.village &&
        plan != ImperialDefensePlan.counterCharge &&
        atPost;
    final blockChance =
        (b.armor + cover + (holding ? .12 : 0)) * (.5 + b.stamina * .5);
    final blocked =
        b.action != BattleAction.windingUp && _roll(a, 7) < blockChance;
    final charge =
        a.side == BattleSide.village &&
            plan == ImperialDefensePlan.counterCharge &&
            a.swings == 1
        ? 1.3
        : 1.0;
    final damage =
        a.power *
        (.85 + _roll(a, 13) * .3) *
        (.6 + a.stamina * .4) *
        (1 - b.armor - cover).clamp(.25, 1) *
        (blocked ? .25 : 1) *
        charge;
    a.stamina = max(.1, a.stamina - .18);
    b.health -= damage;
    b.resolve = max(
      0,
      b.resolve - damage / b.maxHealth * (.65 / (1 + localAllies * .2)),
    );
    final distance = max(.001, a.distanceTo(b));
    final nx = (b.x - a.x) / distance, ny = (b.y - a.y) / distance;
    final force = (55 + damage * 3) * (blocked ? .25 : 1) * (holding ? .65 : 1);
    b.body.impulse(nx * force, ny * force);
    a.body.impulse(-nx * force * .16, -ny * force * .16);
    b.action = BattleAction.recoiling;
    b.timer = blocked ? .14 : .3 + damage / b.maxHealth * .3;
    hits++;
    impacts.add(BattleImpact(a, b, damage, blocked));
    report = blocked
        ? '${b.name} darbeyi karşıladı.'
        : '${a.name} vurdu; ${b.name} yaralandı.';
    if (b.health <= 0 || b.resolve < .14 || b.health < b.maxHealth * .15) {
      b.action = b.health <= 0 ? BattleAction.down : BattleAction.fleeing;
      report = b.health <= 0
          ? '${b.name} yere düştü.'
          : '${b.name} hattan çekiliyor.';
      for (final ally in fighters.where(
        (f) => f.side == b.side && f.active && f != b,
      )) {
        ally.resolve = max(0, ally.resolve - (b.commander ? .23 : .05));
        if (ally.resolve < .14) ally.action = BattleAction.fleeing;
      }
    }
  }
}
