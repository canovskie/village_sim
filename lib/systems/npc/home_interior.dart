import 'dart:collection';
import 'dart:math';

part 'home_interior_layout.dart';

typedef RoomPoint = ({double x, double y});

enum InteriorActivity { walking, table, hearth, window, sleeping }

enum InteriorScenario { daily, supper, hearth, sleep }

/// Ev konumundan türetilir; yeniden açma/yüklemede döşeme değişmez.
/// Meslek veya zenginlik göstergesi değildir, yalnız görsel çeşitliliktir.
enum InteriorStyle {
  cottage,
  botanical,
  woven;

  static InteriorStyle fromSeed(int seed) => values[seed % values.length];
}

enum InteriorFurnitureKind {
  bed,
  table,
  stool,
  hearth,
  shelf,
  chest,
  rug,
  planter,
  basket,
  firewood,
}

class InteriorFurniture {
  final InteriorFurnitureKind kind;
  final double x, y, width, depth;
  final int variant;
  final bool transposed;
  const InteriorFurniture(
    this.kind,
    this.x,
    this.y,
    this.width,
    this.depth, [
    this.variant = 0,
  ]) : transposed = false;

  const InteriorFurniture.placed(
    this.kind,
    this.x,
    this.y,
    this.width,
    this.depth, {
    this.variant = 0,
    this.transposed = false,
  });

  bool get blocksWalking =>
      kind != InteriorFurnitureKind.rug && kind != InteriorFurnitureKind.stool;
  bool contains(double px, double py, {double padding = 0}) =>
      px > x - padding &&
      px < x + width + padding &&
      py > y - padding &&
      py < y + depth + padding;
  double get sortDepth => x + y + (width + depth) * 0.5;
}

class InteriorActor {
  final int slot;
  final HomeInteriorLayout layout;
  double x, y;
  double walkPhase = 0;
  double moveAmount = 0;
  double poseAmount = 0;
  double dwell = 0;
  bool facingRight = true;
  bool present = true;
  int routineIndex = 0;
  InteriorActivity activity = InteriorActivity.walking;
  InteriorActivity destination = InteriorActivity.table;
  final List<RoomPoint> path = [];
  InteriorActor(this.slot, this.layout) : x = 4.25 + slot * 1.5, y = 7.25;
  RoomPoint get position => (x: x, y: y);

  RoomPoint target(InteriorActivity action) => layout.target(slot, action);
}

/// Sadece iç mekân sunumu. Gerçek köylülerin grid/iş/açlık state'ini yazmaz.
class HomeInteriorSimulation {
  final List<InteriorActor> actors;
  final HomeInteriorLayout layout;
  InteriorScenario scenario = InteriorScenario.daily;
  double time = 0;
  factory HomeInteriorSimulation({
    int residents = 2,
    HomeInteriorLayout? layout,
  }) => HomeInteriorSimulation._(
    residents,
    layout ?? HomeInteriorLayout.standard,
  );
  HomeInteriorSimulation._(int residents, this.layout)
    : actors = List.generate(
        residents.clamp(0, 2),
        (slot) => InteriorActor(slot, layout),
      ) {
    setScenario(InteriorScenario.daily);
  }

  void setScenario(InteriorScenario value) {
    scenario = value;
    for (final actor in actors) {
      actor.routineIndex = actor.slot;
      _assign(actor, switch (value) {
        InteriorScenario.daily =>
          actor.slot == 0 ? InteriorActivity.hearth : InteriorActivity.table,
        InteriorScenario.supper => InteriorActivity.table,
        InteriorScenario.hearth =>
          actor.slot == 0 ? InteriorActivity.hearth : InteriorActivity.window,
        InteriorScenario.sleep => InteriorActivity.sleeping,
      });
    }
  }

  void _assign(InteriorActor actor, InteriorActivity action) {
    final path = layout.route(actor.position, actor.target(action));
    if (path.isEmpty) return;
    actor.destination = action;
    actor.path
      ..clear()
      ..addAll(path);
    actor.dwell = 0;
    // Ayağa kalkma bitmeden yürüyüş başlamaz.
  }

  /// Oyun görünümü gerçek evde uyuyanları kendi yatağında gösterir.
  /// Dışarıdaki sakinler içeride hayalet kopya üretmez.
  void syncResident(int slot, {required bool present, required bool sleeping}) {
    if (slot >= actors.length) return;
    final a = actors[slot];
    final arrived = !a.present && present;
    a.present = present;
    if (!present) return;
    if (sleeping) {
      a.path.clear();
      a.destination = a.activity = InteriorActivity.sleeping;
      final p = a.target(a.activity);
      a.x = p.x;
      a.y = p.y;
      a.poseAmount = 1;
      a.moveAmount = 0;
    } else if (arrived ||
        a.activity == InteriorActivity.sleeping && a.path.isEmpty) {
      _assign(a, InteriorActivity.table);
    }
  }

  void update(double dt, {bool automatic = true}) {
    if (!dt.isFinite || dt <= 0) return;
    // Test hızında da köşe atlama/tünelleme olmasın.
    double remaining = min(dt, 1);
    while (remaining > 0.00001) {
      final step = min(remaining, 0.05);
      time += step;
      for (final a in actors) {
        if (!a.present) continue;
        if (a.path.isNotEmpty && a.poseAmount > 0) {
          a.poseAmount = max(0, a.poseAmount - step * 2.5);
          continue;
        }
        if (a.path.isNotEmpty) {
          a.activity = InteriorActivity.walking;
          final next = a.path.first;
          final dx = next.x - a.x, dy = next.y - a.y;
          final distance = sqrt(dx * dx + dy * dy);
          final travel = min(distance, step * 1.1);
          if (distance > 0.0001) {
            a.x += dx / distance * travel;
            a.y += dy / distance * travel;
            if ((dx - dy).abs() > 0.01) a.facingRight = dx - dy > 0;
          }
          a.walkPhase += travel * 5.5;
          a.moveAmount += (1 - a.moveAmount) * min(1, step * 8);
          if (distance <= travel + 0.0001) a.path.removeAt(0);
          if (a.path.isEmpty) {
            a.activity = a.destination;
            a.facingRight = a.activity == InteriorActivity.table
                ? a.slot == 0
                : true;
          }
        } else {
          a.moveAmount = max(0, a.moveAmount - step * 5);
          a.poseAmount = min(1, a.poseAmount + step * 2.5);
          a.dwell += step;
          if (automatic &&
              scenario == InteriorScenario.daily &&
              a.dwell > 7 + a.slot * 2) {
            const routine = [
              InteriorActivity.hearth,
              InteriorActivity.table,
              InteriorActivity.window,
              InteriorActivity.sleeping,
              InteriorActivity.table,
            ];
            a.routineIndex = (a.routineIndex + 1) % routine.length;
            var next = routine[a.routineIndex];
            if (next == InteriorActivity.hearth &&
                actors.any(
                  (other) =>
                      other != a && other.present && other.destination == next,
                )) {
              next = InteriorActivity.window;
            }
            _assign(a, next);
          }
        }
      }
      remaining -= step;
    }
  }
}
