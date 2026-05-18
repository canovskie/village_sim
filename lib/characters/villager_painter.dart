import 'dart:math';
import 'package:flutter/material.dart';
import 'villager_type.dart';

class VillagerPainter extends CustomPainter {
  final VillagerType type;
  final double scale;

  VillagerPainter({required this.type, this.scale = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height * 0.85);
    canvas.scale(scale, scale);

    switch (type) {
      case VillagerType.farmer:
        _drawFarmer(canvas);
        break;
      case VillagerType.merchant:
        _drawMerchant(canvas);
        break;
      case VillagerType.blacksmith:
        _drawBlacksmith(canvas);
        break;
      case VillagerType.guard:
        _drawGuard(canvas);
        break;
      case VillagerType.mage:
        _drawMage(canvas);
        break;
      case VillagerType.miner:
        _drawMiner(canvas);
        break;
      case VillagerType.fisher:
        _drawFisher(canvas);
        break;
    }

    canvas.restore();
  }

  // ─── SHARED HELPERS ────────────────────────────────────────────────────────

  Paint _fill(Color c) => Paint()
    ..color = c
    ..style = PaintingStyle.fill;

  Paint _stroke(Color c, [double w = 1.5]) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;

  // Draws an isometric shadow ellipse under the character
  void _drawShadow(Canvas canvas) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    canvas.drawOval(const Rect.fromLTWH(-16, -6, 32, 10), paint);
  }

  // Draws skin-colored head with simple face
  void _drawHead(Canvas canvas, Color skinColor, Color outlineColor,
      {double y = -82}) {
    // Head
    canvas.drawOval(
      Rect.fromCenter(center: Offset(0, y), width: 22, height: 24),
      _fill(skinColor),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(0, y), width: 22, height: 24),
      _stroke(outlineColor, 1.2),
    );
    // Eyes
    canvas.drawCircle(Offset(-5, y - 1), 2.5, _fill(Colors.white));
    canvas.drawCircle(Offset(5, y - 1), 2.5, _fill(Colors.white));
    canvas.drawCircle(Offset(-4.5, y - 1), 1.2, _fill(Colors.brown.shade900));
    canvas.drawCircle(Offset(5.5, y - 1), 1.2, _fill(Colors.brown.shade900));
    // Smile
    final smilePath = Path()
      ..moveTo(-4, y + 5)
      ..quadraticBezierTo(0, y + 9, 4, y + 5);
    canvas.drawPath(smilePath, _stroke(outlineColor, 1.2));
  }

  // Draws legs with shoes
  void _drawLegs(Canvas canvas, Color pantsColor, Color shoeColor) {
    // Left leg
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(-11, -38, 10, 28), const Radius.circular(3)),
      _fill(pantsColor),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(-11, -38, 10, 28), const Radius.circular(3)),
      _stroke(pantsColor.withValues(alpha: 0.6), 1),
    );
    // Right leg
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(1, -38, 10, 28), const Radius.circular(3)),
      _fill(pantsColor),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(1, -38, 10, 28), const Radius.circular(3)),
      _stroke(pantsColor.withValues(alpha: 0.6), 1),
    );
    // Left shoe
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(-13, -12, 13, 7), const Radius.circular(4)),
      _fill(shoeColor),
    );
    // Right shoe
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(0, -12, 13, 7), const Radius.circular(4)),
      _fill(shoeColor),
    );
  }

  // ─── FARMER ────────────────────────────────────────────────────────────────

  void _drawFarmer(Canvas canvas) {
    _drawShadow(canvas);
    _drawLegs(canvas, Colors.blue.shade800, Colors.brown.shade700);

    // Body (shirt)
    final bodyPath = Path()
      ..moveTo(-13, -70)
      ..lineTo(13, -70)
      ..lineTo(15, -38)
      ..lineTo(-15, -38)
      ..close();
    canvas.drawPath(bodyPath, _fill(Colors.green.shade600));
    canvas.drawPath(bodyPath, _stroke(Colors.green.shade900, 1.2));

    // Overalls straps
    canvas.drawRect(
        const Rect.fromLTWH(-8, -68, 5, 30),
        _fill(Colors.blue.shade600));
    canvas.drawRect(
        const Rect.fromLTWH(3, -68, 5, 30),
        _fill(Colors.blue.shade600));

    // Arms
    // Left arm
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(-22, -72, 10, 26), const Radius.circular(5)),
      _fill(Colors.green.shade600),
    );
    // Right arm (holding a hoe)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(12, -72, 10, 26), const Radius.circular(5)),
      _fill(Colors.green.shade600),
    );

    // Hoe (tool)
    final hoePaint = _fill(Colors.brown.shade600);
    canvas.drawRect(const Rect.fromLTWH(21, -90, 4, 60), hoePaint);
    canvas.drawRect(const Rect.fromLTWH(14, -92, 18, 6), _fill(Colors.grey.shade600));

    // Head
    _drawHead(canvas, const Color(0xFFFFCB9A), Colors.brown.shade900);

    // Straw hat
    canvas.drawOval(
      const Rect.fromLTWH(-18, -100, 36, 10),
      _fill(Colors.yellow.shade700),
    );
    final hatPath = Path()
      ..moveTo(-10, -100)
      ..lineTo(10, -100)
      ..lineTo(7, -116)
      ..lineTo(-7, -116)
      ..close();
    canvas.drawPath(hatPath, _fill(Colors.yellow.shade700));
    canvas.drawPath(hatPath, _stroke(Colors.yellow.shade900, 1));
    canvas.drawOval(
      const Rect.fromLTWH(-18, -100, 36, 10),
      _stroke(Colors.yellow.shade900, 1),
    );
  }

  // ─── MERCHANT ──────────────────────────────────────────────────────────────

  void _drawMerchant(Canvas canvas) {
    _drawShadow(canvas);
    _drawLegs(canvas, Colors.brown.shade800, Colors.grey.shade800);

    // Coat body
    final coatPath = Path()
      ..moveTo(-14, -72)
      ..lineTo(14, -72)
      ..lineTo(17, -38)
      ..lineTo(-17, -38)
      ..close();
    canvas.drawPath(coatPath, _fill(Colors.purple.shade900));
    canvas.drawPath(coatPath, _stroke(Colors.purple.shade200, 1));

    // Coat lapels
    canvas.drawPath(
      Path()
        ..moveTo(-4, -72)
        ..lineTo(-14, -55)
        ..lineTo(-2, -55)
        ..close(),
      _fill(Colors.purple.shade700),
    );
    canvas.drawPath(
      Path()
        ..moveTo(4, -72)
        ..lineTo(14, -55)
        ..lineTo(2, -55)
        ..close(),
      _fill(Colors.purple.shade700),
    );

    // Shirt / vest
    canvas.drawRect(
        const Rect.fromLTWH(-4, -72, 8, 34),
        _fill(Colors.white));

    // Gold buttons
    for (int i = 0; i < 3; i++) {
      canvas.drawCircle(
          Offset(0, -66 + i * 9.0), 2, _fill(Colors.yellow.shade600));
    }

    // Arms
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(-25, -72, 11, 28), const Radius.circular(5)),
      _fill(Colors.purple.shade900),
    );
    // Right arm – holding money bag
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(14, -72, 11, 28), const Radius.circular(5)),
      _fill(Colors.purple.shade900),
    );

    // Money bag
    canvas.drawCircle(const Offset(26, -48), 10, _fill(Colors.yellow.shade600));
    canvas.drawLine(const Offset(26, -58), const Offset(26, -50),
        _stroke(Colors.brown.shade700, 2));
    canvas.drawCircle(const Offset(26, -48), 10,
        _stroke(Colors.yellow.shade800, 1));
    _drawText(canvas, '₺', const Offset(26, -47), 9, Colors.yellow.shade900);

    // Head
    _drawHead(canvas, const Color(0xFFFFCB9A), Colors.brown.shade900);

    // Top hat
    canvas.drawOval(
        const Rect.fromLTWH(-15, -99, 30, 8),
        _fill(Colors.grey.shade900));
    canvas.drawRect(
        const Rect.fromLTWH(-9, -120, 18, 22),
        _fill(Colors.grey.shade900));
    canvas.drawLine(const Offset(-9, -120), const Offset(9, -120),
        _stroke(Colors.purple.shade400, 2));
  }

  // ─── BLACKSMITH ────────────────────────────────────────────────────────────

  void _drawBlacksmith(Canvas canvas) {
    _drawShadow(canvas);
    _drawLegs(canvas, Colors.grey.shade800, Colors.brown.shade900);

    // Wider body (muscular)
    final bodyPath = Path()
      ..moveTo(-16, -72)
      ..lineTo(16, -72)
      ..lineTo(18, -38)
      ..lineTo(-18, -38)
      ..close();
    canvas.drawPath(bodyPath, _fill(Colors.red.shade900));
    canvas.drawPath(bodyPath, _stroke(Colors.red.shade900.withValues(alpha: 0.5), 1));

    // Leather apron
    final apronPath = Path()
      ..moveTo(-10, -70)
      ..lineTo(10, -70)
      ..lineTo(12, -38)
      ..lineTo(-12, -38)
      ..close();
    canvas.drawPath(apronPath, _fill(Colors.brown.shade700));
    canvas.drawPath(apronPath, _stroke(Colors.brown.shade900, 1));

    // Apron straps
    canvas.drawLine(const Offset(-8, -70), const Offset(0, -80),
        _stroke(Colors.brown.shade700, 3));
    canvas.drawLine(const Offset(8, -70), const Offset(0, -80),
        _stroke(Colors.brown.shade700, 3));

    // Big arms
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(-28, -72, 13, 30), const Radius.circular(6)),
      _fill(Colors.red.shade900),
    );
    // Right arm – holding hammer
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(15, -72, 13, 30), const Radius.circular(6)),
      _fill(Colors.red.shade900),
    );

    // Hammer
    canvas.drawRect(
        const Rect.fromLTWH(26, -80, 5, 40), _fill(Colors.brown.shade600));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(20, -92, 16, 12), const Radius.circular(2)),
      _fill(Colors.grey.shade700),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(20, -92, 16, 12), const Radius.circular(2)),
      _stroke(Colors.grey.shade400, 1),
    );

    // Head (bigger)
    _drawHead(canvas, const Color(0xFFD4956A), Colors.brown.shade900,
        y: -84);

    // Bandana
    canvas.drawRect(
        const Rect.fromLTWH(-11, -92, 22, 8),
        _fill(Colors.red.shade700));
    // Knot
    canvas.drawCircle(const Offset(11, -88), 4, _fill(Colors.red.shade700));
  }

  // ─── GUARD ─────────────────────────────────────────────────────────────────

  void _drawGuard(Canvas canvas) {
    _drawShadow(canvas);
    _drawLegs(canvas, Colors.blueGrey.shade800, Colors.blueGrey.shade900);

    // Armor chest plate
    final armorPath = Path()
      ..moveTo(-15, -72)
      ..lineTo(15, -72)
      ..lineTo(17, -38)
      ..lineTo(-17, -38)
      ..close();
    canvas.drawPath(armorPath, _fill(Colors.blueGrey.shade600));
    canvas.drawPath(armorPath, _stroke(Colors.blueGrey.shade300, 1.5));

    // Armor details
    final linePaint = _stroke(Colors.blueGrey.shade400, 1);
    canvas.drawLine(const Offset(-15, -60), const Offset(15, -60), linePaint);
    canvas.drawLine(const Offset(-15, -50), const Offset(15, -50), linePaint);
    canvas.drawLine(const Offset(0, -72), const Offset(0, -38), linePaint);

    // Pauldrons (shoulder plates)
    canvas.drawOval(
        const Rect.fromLTWH(-30, -76, 18, 14),
        _fill(Colors.blueGrey.shade500));
    canvas.drawOval(
        const Rect.fromLTWH(-30, -76, 18, 14),
        _stroke(Colors.blueGrey.shade300, 1));
    canvas.drawOval(
        const Rect.fromLTWH(12, -76, 18, 14),
        _fill(Colors.blueGrey.shade500));
    canvas.drawOval(
        const Rect.fromLTWH(12, -76, 18, 14),
        _stroke(Colors.blueGrey.shade300, 1));

    // Arms
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(-28, -70, 11, 28), const Radius.circular(5)),
      _fill(Colors.blueGrey.shade600),
    );
    // Right arm – holding spear
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(17, -70, 11, 28), const Radius.circular(5)),
      _fill(Colors.blueGrey.shade600),
    );

    // Spear shaft
    canvas.drawRect(
        const Rect.fromLTWH(27, -110, 3, 80), _fill(Colors.brown.shade600));
    // Spear tip
    final spearTip = Path()
      ..moveTo(28.5, -110)
      ..lineTo(22, -95)
      ..lineTo(35, -95)
      ..close();
    canvas.drawPath(spearTip, _fill(Colors.grey.shade400));
    canvas.drawPath(spearTip, _stroke(Colors.grey.shade300, 1));

    // Head
    _drawHead(canvas, const Color(0xFFFFCB9A), Colors.brown.shade900);

    // Helmet
    final helmetPath = Path()
      ..moveTo(-13, -94)
      ..quadraticBezierTo(-14, -112, 0, -114)
      ..quadraticBezierTo(14, -112, 13, -94)
      ..close();
    canvas.drawPath(helmetPath, _fill(Colors.blueGrey.shade500));
    canvas.drawPath(helmetPath, _stroke(Colors.blueGrey.shade300, 1.5));
    // Visor slit
    canvas.drawRect(
        const Rect.fromLTWH(-8, -101, 16, 4),
        _fill(Colors.blueGrey.shade900));
    // Plume
    final plumePath = Path()
      ..moveTo(0, -114)
      ..quadraticBezierTo(-5, -130, -2, -140)
      ..quadraticBezierTo(0, -132, 2, -140)
      ..quadraticBezierTo(5, -130, 0, -114);
    canvas.drawPath(plumePath, _fill(Colors.red.shade600));
  }

  // ─── MAGE ──────────────────────────────────────────────────────────────────

  void _drawMage(Canvas canvas) {
    _drawShadow(canvas);

    // Long robe (from neck to ground)
    final robePath = Path()
      ..moveTo(-12, -70)
      ..lineTo(12, -70)
      ..lineTo(16, -10)
      ..lineTo(-16, -10)
      ..close();
    canvas.drawPath(robePath, _fill(Colors.indigo.shade900));
    canvas.drawPath(robePath, _stroke(Colors.purple.shade300, 1));

    // Robe star decorations
    _drawStar(canvas, const Offset(-6, -55), 4, Colors.yellow.shade300);
    _drawStar(canvas, const Offset(6, -45), 3, Colors.purple.shade300);
    _drawStar(canvas, const Offset(0, -60), 3.5, Colors.cyan.shade300);

    // Robe hem
    canvas.drawPath(
      Path()
        ..moveTo(-16, -10)
        ..lineTo(16, -10)
        ..lineTo(18, 0)
        ..lineTo(-18, 0)
        ..close(),
      _fill(Colors.indigo.shade800),
    );

    // Legs (barely visible under robe)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(-8, -8, 6, 8), const Radius.circular(2)),
      _fill(Colors.brown.shade700),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(2, -8, 6, 8), const Radius.circular(2)),
      _fill(Colors.brown.shade700),
    );

    // Arms with sleeves
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(-26, -72, 14, 30), const Radius.circular(7)),
      _fill(Colors.indigo.shade900),
    );
    // Right arm – holding staff
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(12, -72, 14, 30), const Radius.circular(7)),
      _fill(Colors.indigo.shade900),
    );

    // Staff
    canvas.drawRect(
        const Rect.fromLTWH(24, -115, 4, 80), _fill(Colors.brown.shade400));
    // Orb glow
    final orbGlowPaint = Paint()
      ..color = Colors.cyan.shade200.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(const Offset(26, -120), 12, orbGlowPaint);
    canvas.drawCircle(
        const Offset(26, -120), 9, _fill(Colors.cyan.shade400));
    canvas.drawCircle(
        const Offset(26, -120), 9, _stroke(Colors.white, 1.5));
    canvas.drawCircle(const Offset(23, -122), 3, _fill(Colors.white.withValues(alpha: 0.7)));

    // Head
    _drawHead(canvas, const Color(0xFFE8C9A0), Colors.brown.shade900);

    // Wizard hat
    canvas.drawOval(
        const Rect.fromLTWH(-17, -98, 34, 10),
        _fill(Colors.indigo.shade800));
    canvas.drawOval(
        const Rect.fromLTWH(-17, -98, 34, 10),
        _stroke(Colors.purple.shade300, 1));
    final wizHatPath = Path()
      ..moveTo(-10, -98)
      ..lineTo(10, -98)
      ..lineTo(4, -140)
      ..lineTo(-4, -140)
      ..close();
    canvas.drawPath(wizHatPath, _fill(Colors.indigo.shade800));
    canvas.drawPath(wizHatPath, _stroke(Colors.purple.shade300, 1));

    // Stars on hat
    _drawStar(canvas, const Offset(-3, -118), 3.5, Colors.yellow.shade300);
    _drawStar(canvas, const Offset(2, -130), 2.5, Colors.cyan.shade300);

    // White beard
    final beardPath = Path()
      ..moveTo(-8, -78)
      ..quadraticBezierTo(-9, -65, -5, -55)
      ..quadraticBezierTo(0, -52, 5, -55)
      ..quadraticBezierTo(9, -65, 8, -78)
      ..close();
    canvas.drawPath(beardPath, _fill(Colors.white));
    canvas.drawPath(beardPath, _stroke(Colors.grey.shade300, 1));
  }

  // ─── MINER ─────────────────────────────────────────────────────────────────

  void _drawMiner(Canvas canvas) {
    _drawShadow(canvas);
    _drawLegs(canvas, Colors.brown.shade800, Colors.grey.shade800);

    // Body — koyu gri iş gömleği
    final bodyPath = Path()
      ..moveTo(-13, -70)
      ..lineTo(13, -70)
      ..lineTo(15, -38)
      ..lineTo(-15, -38)
      ..close();
    canvas.drawPath(bodyPath, _fill(const Color(0xFF4A4A4A)));
    canvas.drawPath(bodyPath, _stroke(const Color(0xFF222222), 1.2));

    // Deri yelek
    final vestPath = Path()
      ..moveTo(-10, -70)
      ..lineTo(10, -70)
      ..lineTo(11, -38)
      ..lineTo(-11, -38)
      ..close();
    canvas.drawPath(vestPath, _fill(Colors.brown.shade700));
    canvas.drawPath(vestPath, _stroke(Colors.brown.shade900, 1));

    // Kollar
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(-22, -72, 10, 26), const Radius.circular(5)),
      _fill(const Color(0xFF4A4A4A)),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(12, -72, 10, 26), const Radius.circular(5)),
      _fill(const Color(0xFF4A4A4A)),
    );

    // Head
    _drawHead(canvas, const Color(0xFFD4956A), Colors.brown.shade900);

    // Baret (sarı lambası olan madenci kaskı)
    canvas.drawOval(
        const Rect.fromLTWH(-13, -98, 26, 9),
        _fill(const Color(0xFFDD9900)));
    final hatPath = Path()
      ..moveTo(-11, -98)
      ..lineTo(11, -98)
      ..lineTo(9, -112)
      ..lineTo(-9, -112)
      ..close();
    canvas.drawPath(hatPath, _fill(const Color(0xFFDD9900)));
    canvas.drawPath(hatPath, _stroke(const Color(0xFF886600), 1));
    canvas.drawOval(
        const Rect.fromLTWH(-13, -98, 26, 9),
        _stroke(const Color(0xFF886600), 1));
    // Lamba
    canvas.drawRect(
        const Rect.fromLTWH(-4, -113, 8, 5),
        _fill(const Color(0xFFFFEE88)));
    canvas.drawRect(
        const Rect.fromLTWH(-4, -113, 8, 5),
        _stroke(const Color(0xFF886600), 1));
  }

  // ─── FISHER ────────────────────────────────────────────────────────────────

  void _drawFisher(Canvas canvas) {
    _drawShadow(canvas);
    _drawLegs(canvas, const Color(0xFF3A5060), Colors.brown.shade900);

    // Açık mavi gömlek
    final bodyPath = Path()
      ..moveTo(-13, -70)
      ..lineTo(13, -70)
      ..lineTo(15, -38)
      ..lineTo(-15, -38)
      ..close();
    canvas.drawPath(bodyPath, _fill(const Color(0xFF5A7888)));
    canvas.drawPath(bodyPath, _stroke(const Color(0xFF3A5060), 1.2));

    // Koyu yelek
    final vestPath = Path()
      ..moveTo(-9, -70)
      ..lineTo(9, -70)
      ..lineTo(10, -38)
      ..lineTo(-10, -38)
      ..close();
    canvas.drawPath(vestPath, _fill(const Color(0xFF2A3840)));
    canvas.drawPath(vestPath, _stroke(const Color(0xFF1A2830), 1));

    // Kollar
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(-22, -72, 10, 26), const Radius.circular(5)),
      _fill(const Color(0xFF5A7888)),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(12, -72, 10, 26), const Radius.circular(5)),
      _fill(const Color(0xFF5A7888)),
    );

    // Head
    _drawHead(canvas, const Color(0xFFFFCB9A), Colors.brown.shade900);

    // Balıkçı şapkası (geniş kenarlı)
    canvas.drawOval(
        const Rect.fromLTWH(-16, -97, 32, 7),
        _fill(const Color(0xFF4A3A20)));
    canvas.drawOval(
        const Rect.fromLTWH(-16, -97, 32, 7),
        _stroke(const Color(0xFF2A1A08), 1));
    final hatPath = Path()
      ..moveTo(-10, -97)
      ..lineTo(10, -97)
      ..lineTo(8, -112)
      ..lineTo(-8, -112)
      ..close();
    canvas.drawPath(hatPath, _fill(const Color(0xFF5A4A28)));
    canvas.drawPath(hatPath, _stroke(const Color(0xFF2A1A08), 1));
  }

  // ─── UTILITY ───────────────────────────────────────────────────────────────

  void _drawStar(Canvas canvas, Offset center, double r, Color color) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final outer = Offset(
        center.dx + r * cos((pi * 2 * i / 5) - pi / 2),
        center.dy + r * sin((pi * 2 * i / 5) - pi / 2),
      );
      final inner = Offset(
        center.dx + (r * 0.4) * cos((pi * 2 * i / 5 + pi / 5) - pi / 2),
        center.dy + (r * 0.4) * sin((pi * 2 * i / 5 + pi / 5) - pi / 2),
      );
      if (i == 0) {
        path.moveTo(outer.dx, outer.dy);
      } else {
        path.lineTo(outer.dx, outer.dy);
      }
      path.lineTo(inner.dx, inner.dy);
    }
    path.close();
    canvas.drawPath(path, _fill(color));
  }

  void _drawText(Canvas canvas, String text, Offset offset, double fontSize,
      Color color) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(offset.dx - tp.width / 2, offset.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(VillagerPainter oldDelegate) =>
      oldDelegate.type != type || oldDelegate.scale != scale;
}
