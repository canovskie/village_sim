import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../entities/villager_entity.dart';
import '../systems/npc/home_interior.dart';
import 'character_renderer.dart';

part 'home_interior_furniture.dart';
part 'home_interior_decor.dart';
part 'home_interior_style.dart';

/// Mobilyalar ayrı çizilir; aktörlerle aynı izometrik derinlik sırasına girer.
class HomeInteriorPainter extends CustomPainter {
  final HomeInteriorSimulation simulation;
  final List<VillagerEntity> residents;
  final double daylight;
  final InteriorStyle style;
  final InteriorFurniture? selected;
  HomeInteriorPainter({
    required this.simulation,
    required this.residents,
    this.daylight = 1,
    this.style = InteriorStyle.cottage,
    this.selected,
    super.repaint,
  });

  static const logicalSize = Size(820, 540);
  static Offset project(double x, double y, [double z = 0]) =>
      Offset(380 + (x - y) * 34, 166 + (x + y) * 17 - z);
  static double scaleFor(Size size) =>
      min(size.width / logicalSize.width, size.height / logicalSize.height);
  static Offset offsetFor(Size size) => Offset(
    (size.width - logicalSize.width * scaleFor(size)) / 2,
    (size.height - logicalSize.height * scaleFor(size)) / 2,
  );

  static InteriorFurniture? hitFurniture(
    Offset screen,
    Size size, {
    HomeInteriorLayout? layout,
  }) {
    final scale = scaleFor(size);
    if (scale <= 0) return null;
    final p = (screen - offsetFor(size)) / scale;
    final furniture =
        (layout ?? HomeInteriorLayout.standard).furniture
            .where((f) => f.kind != InteriorFurnitureKind.rug)
            .toList()
          ..sort((a, b) => b.sortDepth.compareTo(a.sortDepth));
    for (final f in furniture) {
      final h = switch (f.kind) {
        InteriorFurnitureKind.bed => 46.0,
        InteriorFurnitureKind.table => 34.0,
        InteriorFurnitureKind.stool => 18.0,
        InteriorFurnitureKind.hearth => 104.0,
        InteriorFurnitureKind.shelf => 87.0,
        InteriorFurnitureKind.chest => 39.0,
        InteriorFurnitureKind.rug => 0.0,
        InteriorFurnitureKind.planter => 52.0,
        InteriorFurnitureKind.basket => 20.0,
        InteriorFurnitureKind.firewood => 19.0,
      };
      final a = project(f.x, f.y, h), b = project(f.x + f.width, f.y, h);
      final d = project(f.x + f.width, f.y + f.depth, h),
          e = project(f.x, f.y + f.depth, h);
      for (final points in [
        [a, b, d, e],
        [
          b,
          project(f.x + f.width, f.y),
          project(f.x + f.width, f.y + f.depth),
          d,
        ],
        [
          e,
          d,
          project(f.x + f.width, f.y + f.depth),
          project(f.x, f.y + f.depth),
        ],
      ]) {
        if ((Path()..addPolygon(points, true)).contains(p)) return f;
      }
    }
    return null;
  }

  final Paint _p = Paint()..isAntiAlias = true;

  void polygon(Canvas c, List<Offset> points, Color color, {Color? outline}) {
    final path = Path()..addPolygon(points, true);
    c.drawPath(
      path,
      _p
        ..shader = null
        ..style = PaintingStyle.fill
        ..color = color,
    );
    if (outline != null) {
      c.drawPath(
        path,
        _p
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.75
          ..color = outline,
      );
      _p.style = PaintingStyle.fill;
    }
  }

  void line(Canvas c, Offset a, Offset b, Color color, [double width = 1]) {
    c.drawLine(
      a,
      b,
      _p
        ..shader = null
        ..color = color
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
  }

  void box(
    Canvas c,
    double x,
    double y,
    double w,
    double d,
    double h,
    Color top, {
    double base = 0,
  }) {
    final a = project(x, y, base + h), b = project(x + w, y, base + h);
    final e = project(x + w, y + d, base + h), f = project(x, y + d, base + h);
    polygon(c, [
      f,
      e,
      project(x + w, y + d, base),
      project(x, y + d, base),
    ], Color.lerp(top, const Color(0xFF251E21), 0.32)!);
    polygon(c, [
      b,
      project(x + w, y, base),
      project(x + w, y + d, base),
      e,
    ], Color.lerp(top, const Color(0xFF171E24), 0.46)!);
    polygon(c, [a, b, e, f], top, outline: Color.lerp(top, Colors.white, 0.15));
  }

  void _room(Canvas c) {
    // Kalın taban, temas gölgesi ve tek tek döşenmiş ahşap tahtalar.
    final shadow = project(5, 4).translate(0, 20);
    _p.shader = ui.Gradient.radial(shadow, 360, [
      const Color(0x80000000),
      Colors.transparent,
    ]);
    c.drawOval(Rect.fromCenter(center: shadow, width: 720, height: 350), _p);
    _p.shader = null;
    box(c, 0, 0, 10, 8, 14, const Color(0xFF6E4B34), base: -14);
    for (int x = 0; x < 20; x++) {
      for (int y = 0; y < 8; y++) {
        final hash = (x * 47 + y * 31) % 11;
        final tone = Color.lerp(
          const Color(0xFF987045),
          const Color(0xFFC39862),
          hash / 11,
        )!;
        box(c, x * 0.5 + 0.015, y + 0.015, 0.47, 0.97, 1, tone);
        for (int g = 0; g < 2; g++) {
          final gx = x * 0.5 + 0.12 + g * 0.19;
          line(
            c,
            project(gx, y + 0.15, 1.1),
            project(gx + 0.03, y + 0.82, 1.1),
            const Color(0x22553724),
            0.7,
          );
        }
      }
    }
    // İki arka duvar açık kesit oluşturur; ön duvar izlemeyi kapatmaz.
    polygon(c, [
      project(0, 8),
      project(0, 0),
      project(0, 0, 124),
      project(0, 8, 124),
    ], Color.lerp(_palette.wall, const Color(0xFF38453E), 0.2)!);
    polygon(c, [
      project(0, 0),
      project(10, 0),
      project(10, 0, 124),
      project(0, 0, 124),
    ], _palette.wall);
    for (int i = 0; i <= 8; i += 2) {
      line(
        c,
        project(0, i.toDouble()),
        project(0, i.toDouble(), 124),
        const Color(0xFF574431),
        7,
      );
    }
    for (int i = 0; i <= 10; i += 2) {
      line(
        c,
        project(i.toDouble(), 0),
        project(i.toDouble(), 0, 124),
        const Color(0xFF6A5137),
        7,
      );
    }
    for (final z in [5.0, 124.0]) {
      line(c, project(0, 8, z), project(0, 0, z), const Color(0xFF755337), 8);
      line(c, project(0, 0, z), project(10, 0, z), const Color(0xFF836040), 8);
    }
    for (final x in simulation.layout.windows) {
      _window(c, x);
    }
    // Eşik ve kesilmiş ön duvar uçları.
    box(c, 3.95, 7.8, 2, 0.5, 3, const Color(0xFFB89668));
    box(c, 0, 7.84, 3.85, 0.16, 6, const Color(0xFF73543B));
    box(c, 6.1, 7.84, 3.9, 0.16, 6, const Color(0xFF73543B));
    _wallDecor(c);
  }

  void _window(Canvas c, double x) {
    final sky = Color.lerp(
      const Color(0xFF243F63),
      const Color(0xFFADD4CD),
      daylight,
    )!;
    polygon(c, [
      project(x, 0.02, 42),
      project(x + 1.15, 0.02, 42),
      project(x + 1.15, 0.02, 100),
      project(x, 0.02, 100),
    ], const Color(0xFF4A3A2D));
    polygon(c, [
      project(x + 0.1, 0.03, 47),
      project(x + 1.05, 0.03, 47),
      project(x + 1.05, 0.03, 95),
      project(x + 0.1, 0.03, 95),
    ], sky);
    line(
      c,
      project(x + 0.58, 0.05, 45),
      project(x + 0.58, 0.05, 98),
      const Color(0xFF7C6546),
      3,
    );
    line(
      c,
      project(x, 0.05, 70),
      project(x + 1.15, 0.05, 70),
      const Color(0xFF7C6546),
      3,
    );
    box(c, x - 0.08, 0.03, 1.3, 0.2, 4, const Color(0xFFAA8555), base: 40);
    final flutter = sin(simulation.time * 1.6 + x) * 1.5;
    for (final side in [0.0, 0.96]) {
      final a = project(x + side, 0.09, 101);
      polygon(c, [
        a,
        a.translate(8, 4),
        a.translate(7 + flutter, 52),
        a.translate(-1 + flutter, 47),
      ], _palette.linen);
      line(
        c,
        a.translate(3, 3),
        a.translate(3 + flutter, 47),
        const Color(0xFFB4AA8D),
      );
    }
    _plant(c, x + 0.85, 0.22, 44, 0.46, flowering: true);
    if (daylight > 0.1) {
      polygon(c, [
        project(x, 0.6, 2),
        project(x + 1.15, 0.6, 2),
        project(x + 2.9, 3.7, 2),
        project(x + 1.1, 3.7, 2),
      ], Color.fromRGBO(255, 232, 169, daylight * 0.17));
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.save();
    canvas.translate(offsetFor(size).dx, offsetFor(size).dy);
    canvas.scale(scaleFor(size));
    _p.color = Colors.white;
    canvas.saveLayer(
      Offset.zero & logicalSize,
      Paint()
        ..colorFilter = ColorFilter.mode(
          Color.lerp(const Color(0xFF8C9CAF), Colors.white, daylight)!,
          BlendMode.modulate,
        ),
    );
    _room(canvas);
    final rug = simulation.layout.item(InteriorFurnitureKind.rug);
    _furniture(canvas, rug);
    final drawables =
        <({double depth, InteriorFurniture? furniture, InteriorActor? actor})>[
          for (final f in simulation.layout.furniture.where(
            (f) => f.kind != InteriorFurnitureKind.rug,
          ))
            (depth: f.sortDepth, furniture: f, actor: null),
          for (final a in simulation.actors)
            if (a.present &&
                a.slot < residents.length &&
                (a.activity != InteriorActivity.sleeping || a.poseAmount < 1))
              (depth: a.x + a.y, furniture: null, actor: a),
        ]..sort((a, b) => a.depth.compareTo(b.depth));
    for (final d in drawables) {
      if (d.furniture != null) {
        _furniture(canvas, d.furniture!);
      } else {
        _actor(canvas, d.actor!);
      }
    }
    if (selected != null) {
      final f = selected!;
      final points = [
        project(f.x, f.y, 2),
        project(f.x + f.width, f.y, 2),
        project(f.x + f.width, f.y + f.depth, 2),
        project(f.x, f.y + f.depth, 2),
      ];
      canvas.drawPath(
        Path()..addPolygon(points, true),
        _p
          ..shader = null
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..color = const Color(0xFFF1C783),
      );
      _p.style = PaintingStyle.fill;
    }
    canvas.restore();
    // Lokal sıcaklık zeminden yükselir; gecede mobilya değerleri okunur kalır.
    canvas.save();
    canvas.clipPath(
      Path()..addPolygon([
        project(0, 0, 124),
        project(10, 0, 124),
        project(10, 0),
        project(10, 8),
        project(0, 8),
        project(0, 8, 124),
      ], true),
    );
    final hearth = simulation.layout.item(InteriorFurnitureKind.hearth);
    final fire = project(hearth.x + hearth.width / 2, hearth.y + 1, 18);
    _p.color = Colors.white;
    _p.shader = ui.Gradient.radial(fire, 190, [
      Color.fromRGBO(255, 163, 67, (1 - daylight) * 0.18),
      Colors.transparent,
    ]);
    canvas.drawCircle(fire, 190, _p);
    _p.shader = null;
    canvas.restore();
    canvas.restore();
  }

  void _actor(Canvas c, InteriorActor a) {
    final v = residents[a.slot];
    final point = project(a.x, a.y);
    c.drawOval(
      Rect.fromCenter(center: point, width: 22, height: 9),
      _p
        ..shader = null
        ..color = const Color(0x440E171A),
    );
    final sitting = a.activity == InteriorActivity.table;
    final blend = a.poseAmount;
    c.save();
    c.translate(point.dx, point.dy);
    if (a.activity == InteriorActivity.sleeping) {
      c.saveLayer(
        const Rect.fromLTRB(-40, -110, 40, 20),
        Paint()..color = Color.fromRGBO(255, 255, 255, 1 - blend),
      );
    }
    if (sitting) c.translate(0, -18 * blend);
    c.scale(0.66 * v.displayScale);
    InteriorCharacterRenderer.draw(
      c,
      v.visual,
      time: simulation.time,
      phase: a.walkPhase + (a.path.isEmpty ? simulation.time * 0.4 : 0),
      moving: a.moveAmount,
      seated: sitting ? blend : 0,
      cooking: a.activity == InteriorActivity.hearth,
      flipX: !a.facingRight,
    );
    if (a.activity == InteriorActivity.sleeping) c.restore();
    c.restore();
  }

  @override
  bool shouldRepaint(HomeInteriorPainter oldDelegate) => true;
}
