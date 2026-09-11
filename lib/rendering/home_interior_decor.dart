part of 'home_interior_painter.dart';

extension _InteriorDecor on HomeInteriorPainter {
  void _leaf(Canvas c, Offset root, Offset tip, double width, Color color) {
    final delta = tip - root;
    final normal = Offset(-delta.dy, delta.dx) / max(1, delta.distance) * width;
    final middle = Offset.lerp(root, tip, .5)!;
    final path = Path()
      ..moveTo(root.dx, root.dy)
      ..quadraticBezierTo(
        middle.dx + normal.dx,
        middle.dy + normal.dy,
        tip.dx,
        tip.dy,
      )
      ..quadraticBezierTo(
        middle.dx - normal.dx * .5,
        middle.dy - normal.dy * .5,
        root.dx,
        root.dy,
      );
    c.drawPath(
      path,
      _p
        ..shader = null
        ..color = color,
    );
    line(c, root, tip, Color.lerp(color, const Color(0xFFD2D19B), .25)!, .45);
  }

  void _plant(
    Canvas c,
    double x,
    double y,
    double z,
    double scale, {
    bool flowering = false,
    bool trailing = false,
  }) {
    final p = HomeInteriorPainter.project(x, y, z);
    c.save();
    c.translate(p.dx, p.dy);
    c.scale(scale);
    c.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 29, height: 11),
      _p..color = const Color(0x3316221D),
    );
    final pot = _palette.ceramic;
    polygon(c, [
      const Offset(-14, -20),
      const Offset(14, -20),
      const Offset(10, 0),
      const Offset(-9, 0),
    ], pot);
    polygon(c, [
      const Offset(6, -20),
      const Offset(14, -20),
      const Offset(10, 0),
      const Offset(4, 0),
    ], Color.lerp(pot, Colors.black, .2)!);
    c.drawOval(
      const Rect.fromLTWH(-15, -25, 30, 10),
      _p..color = Color.lerp(pot, Colors.white, .23)!,
    );
    c.drawOval(
      const Rect.fromLTWH(-12, -23, 24, 6),
      _p..color = const Color(0xFF4C4230),
    );
    line(c, const Offset(-10, -8), const Offset(10, -8), _palette.linen, 1.2);
    for (int i = 0; i < 9; i++) {
      final sway = sin(simulation.time * 1.15 + x + i * .6) * 1.4;
      final tip = Offset(
        (i - 4) * 6.0 + sway,
        trailing && i.isEven ? -8 + (i % 3) * 8 : -36 - (i % 3) * 10,
      );
      const root = Offset(0, -22);
      line(c, root, tip, const Color(0xFF59623A), 1.2);
      for (int j = 1; j <= 3; j++) {
        final node = Offset.lerp(root, tip, j / 4)!;
        _leaf(
          c,
          node,
          node.translate((i.isEven ? -1 : 1) * (8 + j * 1.4), -7),
          5,
          i.isEven ? const Color(0xFF657E49) : const Color(0xFF8D9C59),
        );
      }
      if (flowering && i.isEven) {
        for (int petal = 0; petal < 5; petal++) {
          final angle = petal * pi * 2 / 5;
          c.drawOval(
            Rect.fromCenter(
              center: tip + Offset(cos(angle), sin(angle)) * 2.8,
              width: 4.5,
              height: 4.5,
            ),
            _p
              ..color = style == InteriorStyle.woven
                  ? const Color(0xFFB9808B)
                  : const Color(0xFFE0C681),
          );
        }
        c.drawCircle(tip, 1.5, _p..color = const Color(0xFF99703C));
      } else {
        _leaf(
          c,
          tip.translate(0, 6),
          tip.translate(sway, -7),
          4,
          const Color(0xFF768C4D),
        );
      }
    }
    c.restore();
  }

  void _basket(Canvas c, InteriorFurniture f) {
    final x = f.x, y = f.y, w = f.width, d = f.depth;
    box(c, x + .04, y + .04, w - .08, d - .08, 15, const Color(0xFFAF8C57));
    for (int i = 0; i < 6; i++) {
      final z = 2.0 + i * 2.3;
      line(
        c,
        HomeInteriorPainter.project(x, y + d, z),
        HomeInteriorPainter.project(x + w, y + d, z),
        const Color(0xFFDFC087),
        1.2,
      );
      line(
        c,
        HomeInteriorPainter.project(x + w, y, z),
        HomeInteriorPainter.project(x + w, y + d, z),
        const Color(0xFF80603D),
        1.2,
      );
    }
    for (int i = 0; i < 8; i++) {
      line(
        c,
        HomeInteriorPainter.project(x + w * i / 8, y + d, 0),
        HomeInteriorPainter.project(x + w * i / 8, y + d, 16),
        const Color(0x6682693F),
        .8,
      );
    }
    polygon(
      c,
      [
        HomeInteriorPainter.project(x, y, 16),
        HomeInteriorPainter.project(x + w, y, 16),
        HomeInteriorPainter.project(x + w, y + d, 16),
        HomeInteriorPainter.project(x, y + d, 16),
      ],
      const Color(0xFF65513B),
      outline: const Color(0xFFD6B77D),
    );
    for (int i = 0; i < 5; i++) {
      final p = HomeInteriorPainter.project(
        x + .15 + (i % 2) * .25,
        y + .12 + (i ~/ 2) * .13,
        19,
      );
      final color = style == InteriorStyle.woven
          ? [_palette.textile, _palette.accent, _palette.linen][i % 3]
          : (i.isEven ? const Color(0xFFAE7351) : const Color(0xFF92A166));
      c.drawCircle(p, 4.6, _p..color = color);
      if (style == InteriorStyle.woven) {
        for (int j = 0; j < 3; j++) {
          line(
            c,
            p.translate(-3, j * 2.0 - 3),
            p.translate(3, j * 2.0 - 1),
            Color.lerp(color, Colors.white, .3)!,
            .6,
          );
        }
      } else {
        line(
          c,
          p.translate(0, -3),
          p.translate(1, -6),
          const Color(0xFF59673B),
          1,
        );
      }
    }
    final a = HomeInteriorPainter.project(x + .08, y + d * .5, 14);
    final b = HomeInteriorPainter.project(x + w - .08, y + d * .5, 14);
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..cubicTo(a.dx, a.dy - 20, b.dx, b.dy - 20, b.dx, b.dy);
    c.drawPath(
      path,
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFFC4A572),
    );
    _p.style = PaintingStyle.fill;
  }

  void _firewood(Canvas c, InteriorFurniture f) {
    for (int row = 0; row < 3; row++) {
      for (int i = 0; i < 3 - row; i++) {
        final x = f.x + .12 + row * .09 + i * .18;
        final a = HomeInteriorPainter.project(x, f.y + .1, 4 + row * 5.0);
        final b = HomeInteriorPainter.project(x, f.y + f.depth, 4 + row * 5.0);
        line(c, a, b, const Color(0xFF70523A), 6);
        line(
          c,
          a.translate(-1, -1),
          b.translate(-1, -1),
          const Color(0xFF91714D),
          .8,
        );
        c.drawCircle(b, 3, _p..color = const Color(0xFFC8A674));
        c.drawCircle(
          b,
          1.6,
          _p
            ..style = PaintingStyle.stroke
            ..strokeWidth = .6
            ..color = const Color(0xFF8E6B46),
        );
        _p.style = PaintingStyle.fill;
      }
    }
  }

  void _herbBundle(Canvas c, double y, double z, int variant) {
    final anchor = HomeInteriorPainter.project(.08, y, z);
    line(c, anchor, anchor.translate(0, 9), const Color(0xFFB5A078), 1);
    final root = anchor.translate(0, 10);
    for (int i = 0; i < 6; i++) {
      final tip = root.translate(
        (i - 2.5) * 2.8 + sin(simulation.time * .8 + y) * .6,
        17 + (i % 3) * 4,
      );
      line(c, root, tip, const Color(0xFF626244), 1);
      for (int j = 1; j < 4; j++) {
        final node = Offset.lerp(root, tip, j / 4)!;
        _leaf(
          c,
          node,
          node.translate((i.isEven ? -1 : 1) * 4.5, 4),
          2.3,
          variant.isEven ? const Color(0xFF6A7C49) : const Color(0xFF9F9860),
        );
      }
      if (variant == 1) {
        for (int j = 0; j < 3; j++) {
          c.drawOval(
            Rect.fromCenter(
              center: tip.translate(j.isEven ? -1 : 1, -j * 3.0),
              width: 3,
              height: 4,
            ),
            _p..color = const Color(0xFF9D899C),
          );
        }
      }
    }
    line(c, root.translate(-3, 2), root.translate(3, 2), _palette.linen, 2);
  }

  void _wallDecor(Canvas c) {
    // Askılık: kurutulmuş lavanta, adaçayı ve başaklar.
    line(
      c,
      HomeInteriorPainter.project(.07, 2.7, 103),
      HomeInteriorPainter.project(.07, 4.0, 103),
      _palette.darkWood,
      4,
    );
    for (int i = 0; i < 4; i++) {
      _herbBundle(c, 2.78 + i * .37, 102, i % 3);
    }
    // Yatak üstünde duvara oturan oval dal çelengi.
    const centerY = 1.35;
    final wreath = <Offset>[
      for (int i = 0; i <= 32; i++)
        HomeInteriorPainter.project(
          .07,
          centerY + cos(i * pi / 16) * .48,
          82 + sin(i * pi / 16) * 19,
        ),
    ];
    for (int i = 0; i < 32; i++) {
      line(c, wreath[i], wreath[i + 1], const Color(0xFF7C6943), 2);
      _leaf(
        c,
        wreath[i],
        wreath[(i + 2) % 32].translate(i.isEven ? -3 : 3, -3),
        3,
        i.isEven ? const Color(0xFF74814C) : const Color(0xFF9A9D61),
      );
    }
    // Duvar dokuması: eksenler ekran değil, gerçek duvar düzlemi.
    const y = 6.8, width = .78, z = 88.0, height = 40.0;
    line(
      c,
      HomeInteriorPainter.project(.08, y - .1, z + 3),
      HomeInteriorPainter.project(.08, y + width + .1, z + 3),
      _palette.darkWood,
      2.5,
    );
    polygon(c, [
      HomeInteriorPainter.project(.09, y, z),
      HomeInteriorPainter.project(.09, y + width, z),
      HomeInteriorPainter.project(.09, y + width, z - height),
      HomeInteriorPainter.project(.09, y, z - height),
    ], _palette.linen);
    for (int i = 0; i < 3; i++) {
      final cz = z - 8 - i * 12;
      polygon(c, [
        HomeInteriorPainter.project(.1, y + width / 2, cz + 6),
        HomeInteriorPainter.project(.1, y + width - .1, cz),
        HomeInteriorPainter.project(.1, y + width / 2, cz - 6),
        HomeInteriorPainter.project(.1, y + .1, cz),
      ], i.isEven ? _palette.textile : _palette.accent);
    }
    for (int i = 0; i < 9; i++) {
      line(
        c,
        HomeInteriorPainter.project(.1, y + i * width / 8, z - height),
        HomeInteriorPainter.project(.1, y + i * width / 8, z - height - 5),
        _palette.linen,
        .9,
      );
    }
    // Bir çerçeve: küçük kır manzarası, cam parlaması ve ahşap çerçeve.
    box(c, 8.45, .04, .8, .08, 27, _palette.darkWood, base: 68);
    polygon(c, [
      HomeInteriorPainter.project(8.52, .14, 71),
      HomeInteriorPainter.project(9.18, .14, 71),
      HomeInteriorPainter.project(9.18, .14, 92),
      HomeInteriorPainter.project(8.52, .14, 92),
    ], const Color(0xFFB5C2B1));
    polygon(c, [
      HomeInteriorPainter.project(8.52, .15, 71),
      HomeInteriorPainter.project(9.18, .15, 71),
      HomeInteriorPainter.project(9.18, .15, 80),
      HomeInteriorPainter.project(8.9, .15, 86),
      HomeInteriorPainter.project(8.68, .15, 78),
      HomeInteriorPainter.project(8.52, .15, 81),
    ], const Color(0xFF70805C));
    if (style == InteriorStyle.botanical) {
      // Askılı saksı duvara yakın: yerde yeni görünmez engel yaratmaz.
      final hook = HomeInteriorPainter.project(.15, 7.7, 114);
      final bottom = HomeInteriorPainter.project(.38, 7.5, 76);
      for (final dx in [-8.0, 8.0]) {
        line(c, hook, bottom.translate(dx, -9), const Color(0xFFD7C29C), 1);
      }
      _plant(c, .38, 7.5, 76, .65, trailing: true);
    }
  }
}
