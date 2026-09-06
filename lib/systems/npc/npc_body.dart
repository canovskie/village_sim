import 'dart:math';

typedef NpcClearPath =
    bool Function(double ax, double ay, double bx, double by);

/// Ground-plane body in tiles, seconds and relative kilograms. Animation is
/// deliberately separate: locomotion produces displacement, contacts exchange
/// momentum, and the renderer observes the resulting motion.
class NpcBody {
  final int id;
  final double mass, radius;
  double x, y, vx = 0, vy = 0;
  bool planted = false;

  NpcBody({
    required this.id,
    required this.x,
    required this.y,
    this.mass = 75,
    this.radius = .29,
  });

  double get speed => sqrt(vx * vx + vy * vy);
  void impulse(double ix, double iy) {
    vx += ix / mass;
    vy += iy / mass;
  }

  void advance(
    double dt,
    double tx,
    double ty,
    double desiredSpeed, {
    double traction = 1,
    NpcClearPath? clearPath,
  }) {
    if (dt <= 0 || !dt.isFinite) return;
    final dx = tx - x, dy = ty - y;
    final distance = sqrt(dx * dx + dy * dy);
    final braking = (planted ? 12.0 : 8.0) * traction;
    final targetSpeed = distance < .03
        ? 0.0
        : min(desiredSpeed, sqrt(2 * braking * distance));
    final wantX = distance > .001 ? dx / distance * targetSpeed : 0.0;
    final wantY = distance > .001 ? dy / distance * targetSpeed : 0.0;
    final changeX = wantX - vx, changeY = wantY - vy;
    final change = sqrt(changeX * changeX + changeY * changeY);
    final acceleration = targetSpeed < speed ? braking : 420 / mass * traction;
    final fraction = change > .00001
        ? min(1.0, acceleration * dt / change)
        : 0.0;
    vx += changeX * fraction;
    vy += changeY * fraction;
    translate(vx * dt, vy * dt, clearPath: clearPath, stopAtWall: true);
  }

  /// Swept footprint, including edges; a fast impulse cannot tunnel through a
  /// wall, and the free tangent is retained when glancing along its surface.
  void translate(
    double dx,
    double dy, {
    NpcClearPath? clearPath,
    bool stopAtWall = false,
  }) {
    bool free(double nx, double ny) {
      if (clearPath == null) return true;
      for (final offset in [
        (0.0, 0.0),
        (radius, 0.0),
        (-radius, 0.0),
        (0.0, radius),
        (0.0, -radius),
      ]) {
        if (!clearPath(
          x + offset.$1,
          y + offset.$2,
          nx + offset.$1,
          ny + offset.$2,
        )) {
          return false;
        }
      }
      return true;
    }

    final steps = max(1, (sqrt(dx * dx + dy * dy) / .1).ceil());
    final sx = dx / steps, sy = dy / steps;
    for (var i = 0; i < steps; i++) {
      if (free(x + sx, y + sy)) {
        x += sx;
        y += sy;
        continue;
      }
      final moveX = sx != 0 && free(x + sx, y);
      if (moveX) {
        x += sx;
      } else if (stopAtWall) {
        vx = 0;
      }
      if (sy != 0 && free(x, y + sy)) {
        y += sy;
      } else if (stopAtWall) {
        vy = 0;
      }
    }
  }

  /// Inelastic contacts: inverse-mass correction plus cancellation of closing
  /// normal velocity. Tangential velocity survives. Exact overlap has a stable
  /// separation axis, so identical spawn positions cannot remain glued.
  static void solveContacts(
    List<NpcBody> bodies,
    double dt, {
    NpcClearPath? clearPath,
  }) {
    if (dt <= 0) return;
    final starts = [for (final b in bodies) (b.x, b.y)];
    final budget = min(.12, dt * 3);
    for (var iteration = 0; iteration < 3; iteration++) {
      for (var i = 0; i < bodies.length; i++) {
        final a = bodies[i];
        for (var j = i + 1; j < bodies.length; j++) {
          final b = bodies[j];
          final dx = b.x - a.x, dy = b.y - a.y;
          final distance = sqrt(dx * dx + dy * dy);
          final overlap = a.radius + b.radius - distance;
          if (overlap <= .0005) continue;
          final angle = ((a.id * 31 + b.id * 17) % 360) * pi / 180;
          final nx = distance > .0001 ? dx / distance : cos(angle);
          final ny = distance > .0001 ? dy / distance : sin(angle);
          final invA = 1 / (a.mass * (a.planted ? 2 : 1));
          final invB = 1 / (b.mass * (b.planted ? 2 : 1));
          final sum = invA + invB;
          final correction = min(overlap, budget);
          void shift(NpcBody body, int index, double amount) {
            final moved = sqrt(
              pow(body.x - starts[index].$1, 2) +
                  pow(body.y - starts[index].$2, 2),
            );
            final allowed = max(0.0, budget - moved);
            final limited = amount.clamp(-allowed, allowed);
            body.translate(nx * limited, ny * limited, clearPath: clearPath);
          }

          shift(a, i, -correction * invA / sum);
          shift(b, j, correction * invB / sum);
          final closing = (b.vx - a.vx) * nx + (b.vy - a.vy) * ny;
          if (closing < 0) {
            final impulse = -closing / sum;
            a.vx -= impulse * invA * nx;
            a.vy -= impulse * invA * ny;
            b.vx += impulse * invB * nx;
            b.vy += impulse * invB * ny;
          }
        }
      }
    }
  }
}
