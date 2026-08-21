import 'package:flutter/material.dart';

import '../world/world_landmark.dart';

/// İlgi noktalarını mevcut suluboya/piksel dünyaya uyan küçük, assetsiz
/// siluetlerle çizer. Yeni sprite yükleme maliyeti yoktur.
class WorldLandmarkRenderer {
  static final Paint _shadow = Paint()
    ..color = const Color(0x450F1720)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
  static final Paint _stone = Paint()..color = const Color(0xFF777468);
  static final Paint _stoneDark = Paint()..color = const Color(0xFF4F514B);
  static final Paint _moss = Paint()..color = const Color(0xFF65764A);
  static final Paint _wood = Paint()..color = const Color(0xFF6B4930);
  static final Paint _cloth = Paint()..color = const Color(0xFF8D684C);
  static final Paint _earth = Paint()..color = const Color(0xFF342E28);

  static void draw(Canvas canvas, Offset center, WorldLandmark site) {
    canvas.drawOval(
      Rect.fromCenter(center: center.translate(0, 7), width: 47, height: 13),
      _shadow,
    );
    switch (site.kind) {
      case WorldLandmarkKind.ruinedWatchtower:
        _tower(canvas, center);
      case WorldLandmarkKind.forgottenShrine:
        _shrine(canvas, center);
      case WorldLandmarkKind.abandonedCamp:
        _camp(canvas, center);
      case WorldLandmarkKind.sunkenCellar:
        _cellar(canvas, center);
      case WorldLandmarkKind.plagueStone:
        _plagueStone(canvas, center);
    }
  }

  static void _tower(Canvas c, Offset p) {
    c.drawRect(Rect.fromLTWH(p.dx - 17, p.dy - 28, 12, 34), _stoneDark);
    c.drawRect(Rect.fromLTWH(p.dx + 2, p.dy - 21, 13, 28), _stone);
    c.drawRect(Rect.fromLTWH(p.dx - 18, p.dy - 31, 15, 7), _stone);
    c.drawRect(Rect.fromLTWH(p.dx + 1, p.dy - 24, 17, 6), _stoneDark);
    c.drawRect(Rect.fromLTWH(p.dx - 11, p.dy - 7, 6, 13), _earth);
    c.drawRect(Rect.fromLTWH(p.dx - 17, p.dy - 16, 6, 3), _moss);
    c.drawCircle(p.translate(17, 4), 5, _stoneDark);
  }

  static void _shrine(Canvas c, Offset p) {
    c.drawRect(Rect.fromLTWH(p.dx - 12, p.dy - 27, 24, 33), _stone);
    final roof = Path()
      ..moveTo(p.dx - 16, p.dy - 25)
      ..lineTo(p.dx, p.dy - 38)
      ..lineTo(p.dx + 16, p.dy - 25)
      ..close();
    c.drawPath(roof, _stoneDark);
    c.drawRect(Rect.fromLTWH(p.dx - 5, p.dy - 16, 10, 22), _earth);
    c.drawCircle(p.translate(-13, 5), 4, _moss);
  }

  static void _camp(Canvas c, Offset p) {
    final tent = Path()
      ..moveTo(p.dx - 21, p.dy + 6)
      ..lineTo(p.dx - 3, p.dy - 24)
      ..lineTo(p.dx + 17, p.dy + 6)
      ..close();
    c.drawPath(tent, _cloth);
    c.drawLine(
      p.translate(-3, -25),
      p.translate(20, 8),
      _wood..strokeWidth = 3,
    );
    c.drawLine(p.translate(-3, -25), p.translate(-23, 8), _wood);
    c.drawCircle(p.translate(21, 5), 5, _earth);
  }

  static void _cellar(Canvas c, Offset p) {
    c.drawOval(
      Rect.fromCenter(center: p.translate(0, 3), width: 43, height: 18),
      _earth,
    );
    c.drawRect(Rect.fromLTWH(p.dx - 19, p.dy - 10, 38, 8), _stoneDark);
    c.drawRect(Rect.fromLTWH(p.dx - 16, p.dy - 18, 32, 8), _wood);
    c.drawLine(
      p.translate(-13, -17),
      p.translate(13, -11),
      _stone..strokeWidth = 2,
    );
    c.drawCircle(p.translate(-18, 4), 4, _moss);
  }

  static void _plagueStone(Canvas c, Offset p) {
    final slab = Path()
      ..moveTo(p.dx - 11, p.dy + 6)
      ..lineTo(p.dx - 9, p.dy - 28)
      ..lineTo(p.dx - 2, p.dy - 36)
      ..lineTo(p.dx + 10, p.dy - 29)
      ..lineTo(p.dx + 12, p.dy + 6)
      ..close();
    c.drawPath(slab, _stoneDark);
    c.drawLine(
      p.translate(-5, -20),
      p.translate(6, -10),
      _stone..strokeWidth = 2,
    );
    c.drawLine(p.translate(5, -22), p.translate(-5, -10), _stone);
    c.drawCircle(p.translate(12, 5), 5, _moss);
  }
}
