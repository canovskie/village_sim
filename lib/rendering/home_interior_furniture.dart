part of 'home_interior_painter.dart';

extension _InteriorFurnishings on HomeInteriorPainter {
  void _furniture(Canvas c, InteriorFurniture f) {
    if (f.transposed) {
      // x/y değişimi izometrik ekranda yatay aynadır, yükseklik korunur.
      // Rafın duvar yönü değişir; ayak izi/yol hesabı gerçek planda kalır.
      c.save();
      c.translate(HomeInteriorPainter.project(0, 0).dx * 2, 0);
      c.scale(-1, 1);
      _furniture(
        c,
        InteriorFurniture(f.kind, f.y, f.x, f.depth, f.width, f.variant),
      );
      c.restore();
      return;
    }
    switch (f.kind) {
      case InteriorFurnitureKind.rug:
        _rug(c, f);
      case InteriorFurnitureKind.bed:
        _bed(c, f);
      case InteriorFurnitureKind.table:
        _table(c, f);
      case InteriorFurnitureKind.stool:
        for (final dx in [0.05, 0.35]) {
          for (final dy in [0.05, 0.35]) {
            box(c, f.x + dx, f.y + dy, 0.08, 0.08, 17, _palette.darkWood);
          }
        }
        box(c, f.x - 0.04, f.y - 0.04, 0.58, 0.58, 3, _palette.wood, base: 15);
        if (style != InteriorStyle.cottage) {
          _ovalSlab(c, f.x, f.y, .5, .5, 20, 2, _palette.textile);
        }
        if (style == InteriorStyle.woven) {
          // İki taburenin dış yanında alçak sırtlık, oturma yüksekliği aynı.
          final x = f.variant == 0 ? f.x : f.x + .46;
          for (final y in [f.y, f.y + .43]) {
            box(c, x, y, .06, .07, 35, _palette.darkWood);
          }
          box(c, x, f.y, .06, .5, 8, _palette.wood, base: 27);
        }
      case InteriorFurnitureKind.hearth:
        _hearth(c, f);
      case InteriorFurnitureKind.shelf:
        _shelf(c, f);
      case InteriorFurnitureKind.chest:
        box(c, f.x, f.y, f.width, f.depth, 25, _palette.darkWood);
        box(
          c,
          f.x - 0.03,
          f.y - 0.03,
          f.width + 0.06,
          f.depth + 0.06,
          5,
          _palette.wood,
          base: 25,
        );
        for (final dx in [0.18, 0.86]) {
          line(
            c,
            HomeInteriorPainter.project(f.x + dx, f.y, 30),
            HomeInteriorPainter.project(f.x + dx, f.y + f.depth, 30),
            const Color(0xFF4C5050),
            3,
          );
          line(
            c,
            HomeInteriorPainter.project(f.x + dx, f.y + f.depth, 30),
            HomeInteriorPainter.project(f.x + dx, f.y + f.depth, 3),
            const Color(0xFF414644),
            3,
          );
        }
        final lock = HomeInteriorPainter.project(f.x + 0.56, f.y + f.depth, 21);
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: lock, width: 6, height: 8),
            const Radius.circular(1),
          ),
          _p..color = const Color(0xFFD1AE63),
        );
        _chestDetails(c, f);
      case InteriorFurnitureKind.planter:
        _plant(
          c,
          f.x + f.width / 2,
          f.y + f.depth / 2,
          1,
          f.variant == 0 ? 1 : .8,
          flowering: style != InteriorStyle.cottage || f.variant == 1,
        );
      case InteriorFurnitureKind.basket:
        _basket(c, f);
      case InteriorFurnitureKind.firewood:
        _firewood(c, f);
    }
  }

  void _rug(Canvas c, InteriorFurniture f) {
    if (style == InteriorStyle.botanical) {
      _ovalSlab(
        c,
        f.x,
        f.y,
        f.width,
        f.depth,
        1.4,
        1.1,
        const Color(0xFFB39865),
      );
      for (int i = 0; i < 15; i++) {
        final inset = i * .08;
        final path = Path()
          ..addPolygon(
            _ovalPlane(
              f.x + inset,
              f.y + inset,
              f.width - inset * 2,
              f.depth - inset * 2,
              1.6,
            ),
            true,
          );
        c.drawPath(
          path,
          _p
            ..style = PaintingStyle.stroke
            ..strokeWidth = .7
            ..color = i.isEven
                ? const Color(0xFFDBBE8C)
                : const Color(0xFF8E794F),
        );
      }
      _p.style = PaintingStyle.fill;
      return;
    }
    box(c, f.x, f.y, f.width, f.depth, 1.2, _palette.accent);
    box(
      c,
      f.x + 0.15,
      f.y + 0.15,
      f.width - 0.3,
      f.depth - 0.3,
      0.2,
      _palette.linen,
      base: 1.2,
    );
    box(
      c,
      f.x + 0.25,
      f.y + 0.25,
      f.width - 0.5,
      f.depth - 0.5,
      0.2,
      _palette.textile,
      base: 1.4,
    );
    for (int i = 0; i < 5; i++) {
      final x = f.x + 0.65 + i * 0.85, y = f.y + f.depth / 2;
      polygon(c, [
        HomeInteriorPainter.project(x, y - 0.7, 2),
        HomeInteriorPainter.project(x + 0.38, y, 2),
        HomeInteriorPainter.project(x, y + 0.7, 2),
        HomeInteriorPainter.project(x - 0.38, y, 2),
      ], const Color(0xFFCFAE76));
      polygon(c, [
        HomeInteriorPainter.project(x, y - 0.35, 2),
        HomeInteriorPainter.project(x + 0.2, y, 2),
        HomeInteriorPainter.project(x, y + 0.35, 2),
        HomeInteriorPainter.project(x - 0.2, y, 2),
      ], _palette.accent);
      if (style == InteriorStyle.woven) {
        for (final offset in [-.92, .92]) {
          polygon(c, [
            HomeInteriorPainter.project(x - .28, y + offset, 2),
            HomeInteriorPainter.project(x, y + offset - .2, 2),
            HomeInteriorPainter.project(x + .28, y + offset, 2),
            HomeInteriorPainter.project(x, y + offset + .2, 2),
          ], _palette.linen);
        }
      }
    }
    for (int i = 0; i < 25; i++) {
      final x = f.x + i * f.width / 25;
      for (final y in [f.y, f.y + f.depth]) {
        line(
          c,
          HomeInteriorPainter.project(x, y, 1),
          HomeInteriorPainter.project(x, y + (y == f.y ? -0.1 : 0.1), 1),
          const Color(0xFFC8B58D),
        );
      }
    }
    for (int i = 0; i < 45; i++) {
      final y = f.y + i * f.depth / 45;
      line(
        c,
        HomeInteriorPainter.project(f.x + .1, y, 2.1),
        HomeInteriorPainter.project(f.x + f.width - .1, y, 2.1),
        const Color(0x187F644F),
        .5,
      );
    }
  }

  void _bed(Canvas c, InteriorFurniture f) {
    for (final dx in [0.04, f.width - 0.15]) {
      for (final dy in [0.05, f.depth - 0.18]) {
        box(
          c,
          f.x + dx,
          f.y + dy,
          0.13,
          0.13,
          dy < 1 ? 42 : 25,
          _palette.darkWood,
        );
      }
    }
    _headboard(c, f);
    box(c, f.x, f.y, f.width, f.depth, 6, _palette.darkWood, base: 9);
    box(
      c,
      f.x + 0.1,
      f.y + 0.14,
      f.width - 0.2,
      f.depth - 0.24,
      5,
      const Color(0xFFE2D4B0),
      base: 15,
    );
    box(
      c,
      f.x + 0.27,
      f.y + 0.25,
      f.width - 0.54,
      0.48,
      5,
      const Color(0xFFF1E8D4),
      base: 20,
    );
    final occupant = simulation.actors
        .where(
          (a) =>
              a.slot == f.variant &&
              a.present &&
              a.slot < residents.length &&
              a.activity == InteriorActivity.sleeping,
        )
        .firstOrNull;
    final breath = occupant == null
        ? 0.0
        : sin(simulation.time * 1.7 + f.variant) * 0.5;
    final quilt = f.variant == 0 ? _palette.textile : _palette.accent;
    box(
      c,
      f.x + 0.08,
      f.y + 0.85,
      f.width - 0.16,
      f.depth - 0.95,
      4 + breath,
      quilt,
      base: 19,
    );
    for (int i = 0; i < 4; i++) {
      final y = f.y + 1.0 + i * 0.43;
      line(
        c,
        HomeInteriorPainter.project(f.x + 0.12, y, 24 + breath),
        HomeInteriorPainter.project(f.x + f.width - 0.12, y, 24 + breath),
        const Color(0x88DECCA4),
        2,
      );
    }
    line(
      c,
      HomeInteriorPainter.project(f.x + f.width / 2, f.y + 0.9, 24 + breath),
      HomeInteriorPainter.project(
        f.x + f.width / 2,
        f.y + f.depth - 0.12,
        24 + breath,
      ),
      const Color(0x667B5747),
      1,
    );
    if (style == InteriorStyle.woven) {
      for (int x = 0; x < 3; x++) {
        for (int y = 0; y < 4; y++) {
          final px = f.x + .15 + x * .44, py = f.y + .96 + y * .43;
          box(
            c,
            px,
            py,
            .39,
            .38,
            .15,
            (x + y).isEven ? _palette.linen : _palette.accent,
            base: 24 + breath,
          );
          line(
            c,
            HomeInteriorPainter.project(px + .03, py + .03, 24.3 + breath),
            HomeInteriorPainter.project(px + .36, py + .35, 24.3 + breath),
            quilt,
            .6,
          );
        }
      }
    } else if (style == InteriorStyle.botanical) {
      for (int i = 0; i < 6; i++) {
        final p = HomeInteriorPainter.project(
          f.x + .4 + i % 2 * .7,
          f.y + 1.15 + (i ~/ 2) * .55,
          24.4 + breath,
        );
        _leaf(c, p.translate(-3, 2), p.translate(4, -3), 3, _palette.linen);
      }
    }
    if (occupant != null) {
      final v = residents[occupant.slot];
      final p = HomeInteriorPainter.project(f.x + f.width / 2, f.y + 0.52, 28);
      c.save();
      c.translate(p.dx, p.dy);
      c.rotate(1.107);
      c.scale(0.58);
      c.saveLayer(
        const Rect.fromLTRB(-30, -30, 30, 35),
        Paint()..color = Color.fromRGBO(255, 255, 255, occupant.poseAmount),
      );
      InteriorCharacterRenderer.sleepingHead(c, v.visual);
      c.restore();
      c.restore();
    }
    // Yatak ucundaki ahşap kayıt, battaniyenin önüne gelir.
    box(
      c,
      f.x,
      f.y + f.depth - 0.14,
      f.width,
      0.14,
      13,
      _palette.wood,
      base: 8,
    );
  }

  void _table(Canvas c, InteriorFurniture f) {
    final inset = style == InteriorStyle.botanical ? .38 : .13;
    for (final dx in [inset, f.width - inset - .13]) {
      for (final dy in [inset, f.depth - inset - .13]) {
        box(c, f.x + dx, f.y + dy, 0.13, 0.13, 31, _palette.darkWood);
      }
    }
    if (style == InteriorStyle.botanical) {
      _ovalSlab(
        c,
        f.x - .12,
        f.y - .12,
        f.width + .24,
        f.depth + .24,
        34,
        5,
        _palette.wood,
      );
    } else {
      box(c, f.x, f.y, f.width, f.depth, 5, _palette.wood, base: 29);
    }
    if (style != InteriorStyle.botanical) {
      for (int i = 1; i < 5; i++) {
        line(
          c,
          HomeInteriorPainter.project(f.x + i * 0.5, f.y, 34.2),
          HomeInteriorPainter.project(f.x + i * 0.5, f.y + f.depth, 34.2),
          const Color(0xFF946B42),
          0.8,
        );
      }
    }
    box(
      c,
      f.x + 0.88,
      f.y + 0.02,
      0.65,
      f.depth - 0.04,
      0.3,
      _palette.linen,
      base: 34,
    );
    // Kenardan sarkan dokuma ve püskül.
    if (style == InteriorStyle.woven) {
      polygon(c, [
        HomeInteriorPainter.project(f.x + .88, f.y + f.depth, 34.4),
        HomeInteriorPainter.project(f.x + 1.53, f.y + f.depth, 34.4),
        HomeInteriorPainter.project(f.x + 1.53, f.y + f.depth, 19),
        HomeInteriorPainter.project(f.x + .88, f.y + f.depth, 19),
      ], _palette.linen);
      for (int i = 0; i < 7; i++) {
        final x = f.x + .91 + i * .095;
        line(
          c,
          HomeInteriorPainter.project(x, f.y + f.depth, 23),
          HomeInteriorPainter.project(x, f.y + f.depth, 16),
          _palette.textile,
          1.1,
        );
      }
      line(
        c,
        HomeInteriorPainter.project(f.x + .9, f.y + f.depth, 27),
        HomeInteriorPainter.project(f.x + 1.5, f.y + f.depth, 27),
        _palette.accent,
        2,
      );
    }
    for (final x in [f.x + 0.45, f.x + f.width - 0.45]) {
      final p = HomeInteriorPainter.project(x, f.y + 0.7, 35);
      c.drawOval(
        Rect.fromCenter(center: p, width: 21, height: 10),
        _p..color = const Color(0xFFE4D2AB),
      );
      c.drawOval(
        Rect.fromCenter(center: p, width: 15, height: 6),
        _p..color = const Color(0xFF8D724F),
      );
      c.drawOval(
        Rect.fromCenter(center: p, width: 12, height: 4),
        _p..color = const Color(0xFFBC8A49),
      );
      _pot(c, x, f.y + 0.17, 35, 0.6, const Color(0xFF89634A));
    }
    if (style == InteriorStyle.botanical) {
      _plant(c, f.x + 1.22, f.y + .38, 35, .4, flowering: true);
    } else {
      _pot(c, f.x + 1.22, f.y + 0.38, 35, 1, _palette.ceramic);
    }
    final bread = HomeInteriorPainter.project(f.x + 1.3, f.y + 1.1, 37);
    c.drawOval(
      Rect.fromCenter(center: bread, width: 17, height: 10),
      _p..color = const Color(0xFFD8A05D),
    );
    for (int i = 0; i < 3; i++) {
      line(
        c,
        bread.translate(-4 + i * 4, -3),
        bread.translate(-6 + i * 4, 1),
        const Color(0xFFF3CE8B),
        1.2,
      );
    }
  }

  void _pot(Canvas c, double x, double y, double z, double scale, Color color) {
    final p = HomeInteriorPainter.project(x, y, z);
    c.drawOval(
      Rect.fromCenter(
        center: p.translate(0, -6 * scale),
        width: 13 * scale,
        height: 17 * scale,
      ),
      _p..color = color,
    );
    c.drawOval(
      Rect.fromCenter(
        center: p.translate(0, -14 * scale),
        width: 8 * scale,
        height: 4 * scale,
      ),
      _p..color = const Color(0xFF4E4637),
    );
    line(
      c,
      p.translate(-3 * scale, -10 * scale),
      p.translate(-4 * scale, -3 * scale),
      const Color(0x66FFF0C7),
      scale,
    );
  }

  void _headboard(Canvas c, InteriorFurniture f) {
    if (style == InteriorStyle.cottage) {
      for (int i = 0; i < 6; i++) {
        box(c, f.x + .1 + i * .25, f.y, .17, .12, 30, _palette.wood, base: 9);
      }
      box(c, f.x, f.y, f.width, .14, 4, _palette.wood, base: 38);
      box(c, f.x, f.y, f.width, .14, 4, _palette.darkWood, base: 12);
      return;
    }
    // Bombeli başlık: yay biçimi ahşap kütlenin gerçek siluetidir.
    final top = <Offset>[
      for (int i = 0; i <= 12; i++)
        HomeInteriorPainter.project(
          f.x + f.width * i / 12,
          f.y + .13,
          34 + sin(i * pi / 12) * (style == InteriorStyle.botanical ? 12 : 7),
        ),
    ];
    polygon(c, [
      HomeInteriorPainter.project(f.x, f.y + .13, 10),
      ...top,
      HomeInteriorPainter.project(f.x + f.width, f.y + .13, 10),
    ], _palette.wood);
    for (int i = 0; i < top.length - 1; i++) {
      line(c, top[i], top[i + 1], _palette.darkWood, 2.8);
    }
    for (int i = 0; i < 3; i++) {
      final x = f.x + .35 + i * .47;
      if (style == InteriorStyle.botanical) {
        line(
          c,
          HomeInteriorPainter.project(x, f.y + .14, 18),
          HomeInteriorPainter.project(x, f.y + .14, 33),
          _palette.darkWood,
          1.2,
        );
      } else {
        polygon(c, [
          HomeInteriorPainter.project(x - .14, f.y + .14, 28),
          HomeInteriorPainter.project(x, f.y + .14, 34),
          HomeInteriorPainter.project(x + .14, f.y + .14, 28),
          HomeInteriorPainter.project(x, f.y + .14, 22),
        ], _palette.linen);
        line(
          c,
          HomeInteriorPainter.project(x, f.y + .15, 25),
          HomeInteriorPainter.project(x, f.y + .15, 31),
          _palette.accent,
          1.5,
        );
      }
    }
  }

  void _chestDetails(Canvas c, InteriorFurniture f) {
    if (style == InteriorStyle.botanical) {
      // Facetli bombeli kapak ve üzerinde iki demir kuşak.
      for (int i = 0; i < 10; i++) {
        final y0 = f.y + f.depth * i / 10, y1 = f.y + f.depth * (i + 1) / 10;
        final z0 = 30 + sin(i * pi / 10) * 9,
            z1 = 30 + sin((i + 1) * pi / 10) * 9;
        polygon(c, [
          HomeInteriorPainter.project(f.x, y0, z0),
          HomeInteriorPainter.project(f.x + f.width, y0, z0),
          HomeInteriorPainter.project(f.x + f.width, y1, z1),
          HomeInteriorPainter.project(f.x, y1, z1),
        ], Color.lerp(_palette.wood, _palette.darkWood, i / 22)!);
        polygon(c, [
          HomeInteriorPainter.project(f.x + f.width, y0, 30),
          HomeInteriorPainter.project(f.x + f.width, y0, z0),
          HomeInteriorPainter.project(f.x + f.width, y1, z1),
          HomeInteriorPainter.project(f.x + f.width, y1, 30),
        ], _palette.darkWood);
        for (final x in [.18, .86]) {
          line(
            c,
            HomeInteriorPainter.project(f.x + x, y0, z0 + .2),
            HomeInteriorPainter.project(f.x + x, y1, z1 + .2),
            const Color(0xFF4C5750),
            2.5,
          );
        }
      }
    } else if (style == InteriorStyle.woven) {
      // Boyalı çeyiz sandığı: ön yüzde gömme panolar ve yıldız kakma.
      for (int i = 0; i < 2; i++) {
        final x = f.x + .1 + i * .55;
        polygon(
          c,
          [
            HomeInteriorPainter.project(x, f.y + f.depth + .01, 5),
            HomeInteriorPainter.project(x + .43, f.y + f.depth + .01, 5),
            HomeInteriorPainter.project(x + .43, f.y + f.depth + .01, 22),
            HomeInteriorPainter.project(x, f.y + f.depth + .01, 22),
          ],
          _palette.textile,
          outline: _palette.linen,
        );
        polygon(c, [
          HomeInteriorPainter.project(x + .22, f.y + f.depth + .02, 19),
          HomeInteriorPainter.project(x + .36, f.y + f.depth + .02, 13),
          HomeInteriorPainter.project(x + .22, f.y + f.depth + .02, 7),
          HomeInteriorPainter.project(x + .07, f.y + f.depth + .02, 13),
        ], _palette.linen);
      }
      box(c, f.x + .3, f.y + .15, .55, .58, 2, _palette.textile, base: 30);
      box(c, f.x + .32, f.y + .16, .52, .55, 2, _palette.linen, base: 32);
    }
  }

  void _shelf(Canvas c, InteriorFurniture f) {
    box(c, f.x, f.y, 0.1, f.depth, 82, _palette.darkWood);
    for (final y in [f.y, f.y + f.depth - 0.1]) {
      box(c, f.x, y, f.width, 0.1, 84, _palette.darkWood);
    }
    for (final z in [8.0, 35.0, 62.0, 84.0]) {
      box(c, f.x, f.y, f.width, f.depth, 3, _palette.wood, base: z);
      if (z < 80) {
        for (int i = 0; i < 3; i++) {
          if (style == InteriorStyle.woven && (i == 1 || z == 8)) {
            for (int layer = 0; layer < 3; layer++) {
              box(
                c,
                f.x + .17,
                f.y + .17 + i * .58,
                .45,
                .4,
                3,
                [_palette.textile, _palette.linen, _palette.accent][layer],
                base: z + 3 + layer * 3,
              );
            }
            continue;
          }
          _pot(
            c,
            f.x + 0.42,
            f.y + 0.3 + i * 0.58,
            z + 3,
            0.75 + (i % 2) * 0.2,
            i.isEven ? _palette.ceramic : _palette.linen,
          );
          // Kavanoz etiketi, raftaki farklı boyları birbirine bağlar.
          final p = HomeInteriorPainter.project(
            f.x + .42,
            f.y + .3 + i * .58,
            z + 10,
          );
          line(c, p.translate(-2, 0), p.translate(2, 0), _palette.textile, 2);
        }
      }
    }
    _plant(c, f.x + .4, f.y + .3, 87, .58, trailing: true);
    if (style == InteriorStyle.botanical) {
      _plant(c, f.x + .38, f.y + 1.45, 87, .48, flowering: true);
      _plant(c, f.x + .5, f.y + 1.1, 38, .38);
    } else {
      // Raf üstünde üst üste seramik tabaklar.
      for (int i = 0; i < 4; i++) {
        _ovalSlab(
          c,
          f.x + .14,
          f.y + 1.2,
          .5,
          .5,
          89 + i * 2.0,
          1.5,
          _palette.linen,
        );
      }
    }
  }

  void _hearth(Canvas c, InteriorFurniture f) {
    box(
      c,
      f.x - 0.2,
      f.y,
      f.width + 0.4,
      f.depth + 0.5,
      5,
      const Color(0xFF79766C),
    );
    box(c, f.x, f.y, f.width, 0.45, 104, const Color(0xFF9A9887));
    for (int i = 0; i < 7; i++) {
      final z = i * 14.0 + 10;
      line(
        c,
        HomeInteriorPainter.project(f.x, f.y + 0.46, z),
        HomeInteriorPainter.project(f.x + f.width, f.y + 0.46, z),
        const Color(0xFF777B71),
        1.2,
      );
      for (int j = 0; j < 3; j++) {
        final x = f.x + .15 + j * .58 + (i.isEven ? 0 : .24);
        if (x >= f.x + f.width) continue;
        line(
          c,
          HomeInteriorPainter.project(x, f.y + .46, z),
          HomeInteriorPainter.project(x, f.y + .46, z + 13),
          const Color(0xFF777B71),
          .9,
        );
      }
    }
    box(c, f.x, f.y + 0.4, 0.28, 0.85, 42, const Color(0xFF8B897C));
    box(
      c,
      f.x + f.width - 0.28,
      f.y + 0.4,
      0.28,
      0.85,
      42,
      const Color(0xFF969383),
    );
    box(
      c,
      f.x - 0.08,
      f.y + 0.32,
      f.width + 0.16,
      1.02,
      9,
      const Color(0xFFB1AA93),
      base: 42,
    );
    final fire = HomeInteriorPainter.project(f.x + f.width / 2, f.y + 1.0, 8);
    _p.color = Colors.white;
    _p.shader = ui.Gradient.radial(fire.translate(0, -8), 45, [
      const Color(0x88F2A743),
      const Color(0x00F2A743),
    ]);
    c.drawCircle(fire.translate(0, -8), 45, _p);
    _p.shader = null;
    for (int i = 0; i < 4; i++) {
      final dx = (i - 1.5) * 5;
      line(
        c,
        fire.translate(dx - 5, 0),
        fire.translate(dx + 7, 3),
        const Color(0xFF604334),
        4,
      );
      final wave = sin(simulation.time * (5 + i) + i);
      final tip = fire.translate(dx + wave * 3, -15 - (wave + 1) * 5);
      final path = Path()
        ..moveTo(fire.dx + dx - 4, fire.dy)
        ..quadraticBezierTo(fire.dx + dx - 7, fire.dy - 11, tip.dx, tip.dy)
        ..quadraticBezierTo(
          fire.dx + dx + 6,
          fire.dy - 8,
          fire.dx + dx + 3,
          fire.dy,
        )
        ..close();
      c.drawPath(
        path,
        _p
          ..color = i.isEven
              ? const Color(0xFFF6C269)
              : const Color(0xFFE98B3F),
      );
    }
    _pot(c, f.x + 0.87, f.y + 1.12, 22, 1.3, const Color(0xFF454E48));
    for (int i = 0; i < 3; i++) {
      final t = (simulation.time * 0.4 + i / 3) % 1;
      final p = HomeInteriorPainter.project(f.x + 0.87, f.y + 1.12, 45);
      c.drawOval(
        Rect.fromCenter(
          center: p.translate(sin(t * 6 + i) * 3, -t * 23),
          width: 4 + t * 8,
          height: 3 + t * 5,
        ),
        _p..color = Color.fromRGBO(237, 222, 195, sin(t * pi) * 0.25),
      );
    }
    _pot(c, f.x + 0.23, f.y + 0.6, 52, 0.7, const Color(0xFFAD805C));
    _candle(c, f.x + 1.4, f.y + .6, 52);
    // Maşa ve ateş küreği ocağın yanına dayanır.
    final hook = HomeInteriorPainter.project(f.x + 1.7, f.y + .6, 36);
    line(c, hook, hook.translate(5, 25), const Color(0xFF434941), 1.5);
    line(
      c,
      hook.translate(5, 25),
      hook.translate(8, 29),
      const Color(0xFF434941),
      3,
    );
  }

  void _candle(Canvas c, double x, double y, double z) {
    final p = HomeInteriorPainter.project(x, y, z);
    c.drawOval(
      Rect.fromCenter(center: p, width: 12, height: 5),
      _p..color = const Color(0xFF776343),
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(p.dx - 2.5, p.dy - 12, 5, 12),
        const Radius.circular(1),
      ),
      _p..color = _palette.linen,
    );
    final sway = sin(simulation.time * 5) * .7;
    _leaf(
      c,
      p.translate(0, -12),
      p.translate(sway, -20),
      3,
      const Color(0xFFF2BE69),
    );
    line(
      c,
      p.translate(0, -11),
      p.translate(0, -14),
      const Color(0xFF6D5439),
      .7,
    );
  }
}
