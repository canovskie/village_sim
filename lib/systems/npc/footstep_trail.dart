import 'dart:math';

/// Geçici görsel izler; dünya/kayıt durumunu değiştirmez.
enum FootstepSurface { dust, wet, snow }

class Footstep {
  final double x, y, dx, dy;
  final bool left;
  final FootstepSurface surface;
  double age = 0;

  Footstep(this.x, this.y, this.dx, this.dy, this.left, this.surface);

  double get lifetime => switch (surface) {
    FootstepSurface.dust => 0.7,
    FootstepSurface.wet => 0.5,
    FootstepSurface.snow => 3.2,
  };
}

class FootstepTrail {
  final List<Footstep> steps = [];
  double? _x, _y;
  bool _left = false;

  void update(
    double dt, {
    required double x,
    required double y,
    required bool moving,
    required FootstepSurface? surface,
  }) {
    if (!dt.isFinite || dt <= 0) return;
    for (final step in steps) {
      step.age += dt;
    }
    steps.removeWhere((step) => step.age >= step.lifetime);
    if (!x.isFinite || !y.isFinite) {
      _x = _y = null;
      return;
    }
    final dx = x - (_x ?? x), dy = y - (_y ?? y);
    final distance = sqrt(dx * dx + dy * dy);
    // Işınlanma/yükleme, kapıdan çıkış ve itişme adım üretmez.
    if (_x == null || !moving || surface == null || distance > 1.5) {
      _x = x;
      _y = y;
      return;
    }
    // Yürüyüş fazı tile başına 5.5 rad ilerler: yarım döngü = bir basış.
    if (distance < pi / 5.5) return;
    final nx = dx / distance, ny = dy / distance;
    final side = _left ? -0.065 : 0.065;
    steps.add(Footstep(x - ny * side, y + nx * side, nx, ny, _left, surface));
    if (steps.length > 12) steps.removeAt(0);
    _left = !_left;
    _x = x;
    _y = y;
  }
}
