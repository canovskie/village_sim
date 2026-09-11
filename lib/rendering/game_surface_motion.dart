part of 'game_painter.dart';

/// Yüzeye basan ayağın izi dünya koordinatında kalır; kamera/NPC ile kaymaz.
extension _SurfaceMotion on VillageGamePainter {
  static final Paint _dust = Paint()..isAntiAlias = true;
  static final Paint _wetRing = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.75;

  void _drawFootsteps(Canvas canvas, Size size) {
    if (zoom < 0.4) return;
    final (minX, maxX, minY, maxY) = _visBounds(size);
    for (final villager in villagers) {
      for (final step in villager.footstepTrail.steps) {
        final p = gridToScreen(step.x, step.y, size, camera);
        if (p.dx < minX - 12 ||
            p.dx > maxX + 12 ||
            p.dy < minY - 12 ||
            p.dy > maxY + 12) {
          continue;
        }
        final t = (step.age / step.lifetime).clamp(0.0, 1.0);
        final fade = (1 - t) * (1 - t);
        final sx = (step.dx - step.dy) * kTileW * 0.5;
        final sy = (step.dx + step.dy) * kTileH * 0.5;
        switch (step.surface) {
          case FootstepSurface.dust:
            if (perfMode || rainIntensity > 0.28 || season == Season.winter) {
              continue;
            }
            final wind = Wind.gust(time - step.age);
            for (int i = 0; i < 3; i++) {
              final drift = (i - 1) * 2.2 * t + wind * 5 * t;
              final point = p.translate(
                drift - sx * t * 0.07,
                -sy * t * 0.07 - 4 * t - i * 0.6,
              );
              final radius = 0.6 + t * (2 + i * 0.45);
              _dust.color = const Color(
                0xFFD9C59E,
              ).withValues(alpha: fade * min(1.0, t * 10) * 0.32);
              canvas.drawOval(
                Rect.fromCenter(
                  center: point,
                  width: radius * 2.5,
                  height: radius * 1.5,
                ),
                _dust,
              );
            }
          case FootstepSurface.wet:
            if (season == Season.winter) continue;
            _wetRing.color = const Color(
              0xFFD7EBEB,
            ).withValues(alpha: fade * 0.6);
            canvas.drawOval(
              Rect.fromCenter(center: p, width: 2 + t * 15, height: 1 + t * 6),
              _wetRing,
            );
            if (!perfMode) {
              _dust.color = const Color(
                0xFFE2F2F5,
              ).withValues(alpha: fade * 0.85);
              for (final side in [-1.0, 1.0]) {
                canvas.drawCircle(
                  p.translate(side * t * 7, -12 * t * (1 - t)),
                  0.8 * (1 - t * 0.5),
                  _dust,
                );
              }
            }
          case FootstepSurface.snow:
            if (season != Season.winter) continue;
            canvas.save();
            canvas.translate(p.dx, p.dy);
            canvas.rotate(atan2(sy, sx));
            final sole = Rect.fromCenter(
              center: Offset.zero,
              width: 4.8,
              height: 2.2,
            );
            _dust.color = const Color(
              0xFF637E96,
            ).withValues(alpha: fade * 0.48);
            canvas.drawOval(sole, _dust);
            _dust.color = const Color(0xFFF6FCFF).withValues(alpha: fade * 0.7);
            canvas.drawArc(
              sole.shift(const Offset(0, 0.7)),
              0,
              pi,
              false,
              _wetRing..color = _dust.color,
            );
            canvas.restore();
        }
      }
    }
  }

  /// Dünya üzerinde sabit hücreler; kamera yalnız görünür aralığı seçer.
  /// Haritanın tamamı yerine kadraja giren hücreler dolaşılır.
  Iterable<(double, double, int)> _ambientSites(
    Size size, {
    int spacing = 3,
  }) sync* {
    final (minX, maxX, minY, maxY) = _visBounds(size);
    final ox = size.width * 0.5 + camera.dx;
    final oy = size.height * 0.28 + camera.dy;
    double col(double x, double y) => (x - ox) / kTileW + (y - oy) / kTileH;
    double row(double x, double y) => (y - oy) / kTileH - (x - ox) / kTileW;
    final c0 = max(0, (col(minX - 48, minY - 48) / spacing).floor());
    final c1 = min(
      (kCols - 1) ~/ spacing,
      (col(maxX + 48, maxY + 48) / spacing).ceil(),
    );
    final r0 = max(0, (row(maxX + 48, minY - 48) / spacing).floor());
    final r1 = min(
      (kRows - 1) ~/ spacing,
      (row(minX - 48, maxY + 48) / spacing).ceil(),
    );
    for (int c = c0; c <= c1; c++) {
      for (int r = r0; r <= r1; r++) {
        final hash = ((c * 73856093) ^ (r * 19349663)) & 0x7fffffff;
        final gx = c * spacing + 0.25 + (hash % 997) / 997 * (spacing - 0.5);
        final gy =
            r * spacing + 0.25 + ((hash >> 10) % 991) / 991 * (spacing - 0.5);
        if (gx >= kCols || gy >= kRows) continue;
        final p = gridToScreen(gx, gy, size, camera);
        if (p.dx < minX - 40 ||
            p.dx > maxX + 40 ||
            p.dy < minY - 40 ||
            p.dy > maxY + 40) {
          continue;
        }
        yield (gx, gy, hash);
      }
    }
  }

  static final Paint _mist = Paint()..isAntiAlias = true;

  /// Su üstünde alçak, parçalı sis. Öğlen çekilir; şafakta ağır ağır süzülür.
  /// Lokal gradient yeterli: tam ekran offscreen katman veya blur açılmaz.
  void _drawRiverMist(Canvas canvas, Size size) {
    final twilight = (1 - (dayLight - 0.42).abs() / 0.42).clamp(0.0, 1.0);
    final strength = twilight * (1 - rainIntensity * 0.75);
    if (strength < 0.03 || zoom < 0.4) return;
    final tone = Color.lerp(
      const Color(0xFFB8CDD6),
      const Color(0xFFF1E8D4),
      dayLight,
    )!;
    for (final (gx, gy, seed) in _ambientSites(size, spacing: 4)) {
      if (!waterTiles.contains((gx.floor(), gy.floor()))) continue;
      final phase = time * 0.15 + seed % 73;
      final breath = 0.65 + sin(phase * 0.7) * 0.25;
      final p = gridToScreen(gx, gy, size, camera);
      canvas.save();
      canvas.translate(p.dx + sin(phase) * 19, p.dy - 6 + cos(phase) * 3);
      canvas.scale(48 + (seed % 23).toDouble(), 9 + breath * 5);
      _mist.shader = ui.Gradient.radial(
        Offset.zero,
        1,
        [
          tone.withValues(alpha: strength * breath * 0.23),
          tone.withValues(alpha: strength * breath * 0.10),
          tone.withValues(alpha: 0),
        ],
        const [0, 0.45, 1],
      );
      canvas.drawCircle(Offset.zero, 1, _mist);
      canvas.restore();
    }
    _mist.shader = null;
  }
}
