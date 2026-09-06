import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../systems/imperial.dart';
import 'app_ui.dart';

/// Metin ağırlıklı karar/panel yüzeylerini küçük, veriyle değişen oyun
/// sahnelerine çeviren ortak görsel dil. Bunlar dekor değil: yığın, ışık,
/// çalışan ve yol düğümleri doğrudan ekrandaki sayılardan türetilir.

class ImperialDemandDiorama extends StatelessWidget {
  final ImperialDemand demand;
  final double fraction;
  final double favor;
  final int guards;
  final double height;

  const ImperialDemandDiorama({
    super.key,
    required this.demand,
    this.fraction = 1,
    required this.favor,
    this.guards = 0,
    this.height = 154,
  });

  @override
  Widget build(BuildContext context) {
    final offered = demand.isConscript
        ? 1
        : math.max(1, (demand.amount * fraction).round());
    return Semantics(
      label: 'İmparatorluk talebi: ${demand.label}',
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFF111116),
          borderRadius: BorderRadius.circular(AppUi.radiusSm),
          border: Border.all(color: AppUi.rust.withValues(alpha: 0.42)),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _ImperialDemandPainter(
                  kind: demand.kind,
                  units: offered,
                  favor: favor,
                  guards: guards,
                ),
              ),
            ),
            Positioned(
              left: 12,
              top: 10,
              child: Text(
                demand.isConscript ? 'BİR OCAK EKSİLECEK' : 'MASADAKİ TALEP',
                style: AppUi.label.copyWith(
                  fontSize: 8.5,
                  color: AppUi.rust,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            Positioned(
              right: 12,
              top: 8,
              child: Text(
                demand.isConscript ? '1 CAN' : '$offered',
                style: AppUi.number.copyWith(fontSize: 20, color: AppUi.textHi),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImperialDemandPainter extends CustomPainter {
  final ImperialDemandKind kind;
  final int units;
  final double favor;
  final int guards;

  const _ImperialDemandPainter({
    required this.kind,
    required this.units,
    required this.favor,
    required this.guards,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final floor = Rect.fromLTWH(0, h * .58, w, h * .42);
    canvas.drawRect(floor, Paint()..color = const Color(0xFF18171A));
    canvas.drawLine(
      Offset(0, h * .58),
      Offset(w, h * .58),
      Paint()..color = AppUi.rust.withValues(alpha: .28),
    );

    // İmparatorluk tarafı: sancak + iki sabit nöbetçi.
    final pole = Paint()
      ..color = const Color(0xFF5A463A)
      ..strokeWidth = 3;
    canvas.drawLine(Offset(w * .83, 31), Offset(w * .83, h * .78), pole);
    final flag = Path()
      ..moveTo(w * .83, 34)
      ..lineTo(w * .67, 40)
      ..lineTo(w * .83, 60)
      ..close();
    canvas.drawPath(flag, Paint()..color = const Color(0xFF7B2F2E));
    _guard(canvas, Offset(w * .75, h * .72), 1 + guards.clamp(0, 5) * .025);
    _guard(canvas, Offset(w * .91, h * .72), 1);

    // Köy tarafı ile imparatorluk arasındaki pazarlık masası.
    final table = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(w * .43, h * .72),
        width: w * .48,
        height: 22,
      ),
      const Radius.circular(4),
    );
    canvas.drawRRect(table, Paint()..color = const Color(0xFF4A3325));
    canvas.drawLine(
      Offset(w * .27, h * .78),
      Offset(w * .24, h * .98),
      Paint()
        ..color = const Color(0xFF2A211C)
        ..strokeWidth = 5,
    );
    canvas.drawLine(
      Offset(w * .58, h * .78),
      Offset(w * .62, h * .98),
      Paint()
        ..color = const Color(0xFF2A211C)
        ..strokeWidth = 5,
    );

    final count = math.min(9, math.max(1, (math.sqrt(units) * 1.7).round()));
    switch (kind) {
      case ImperialDemandKind.goldTax:
        for (var i = 0; i < count; i++) {
          final x = w * .29 + (i % 5) * 13.0;
          final y = h * .60 - (i ~/ 5) * 8.0;
          canvas.drawOval(
            Rect.fromCenter(center: Offset(x, y), width: 12, height: 6),
            Paint()..color = i.isEven ? AppUi.gold : const Color(0xFFB97A35),
          );
        }
      case ImperialDemandKind.foodLevy:
        for (var i = 0; i < count.clamp(2, 6); i++) {
          _sack(canvas, Offset(w * .28 + i * 18, h * .61));
        }
      case ImperialDemandKind.woodLevy:
        for (var i = 0; i < count.clamp(3, 8); i++) {
          final y = h * .58 - (i ~/ 4) * 8.0;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(w * .25 + (i % 4) * 22, y, 28, 7),
              const Radius.circular(4),
            ),
            Paint()
              ..color = i.isEven
                  ? const Color(0xFF8A5A37)
                  : const Color(0xFF69422D),
          );
        }
      case ImperialDemandKind.conscript:
        _person(canvas, Offset(w * .40, h * .59), AppUi.accentSoft, 1.14);
        canvas.drawCircle(
          Offset(w * .40, h * .69),
          19,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = AppUi.rust.withValues(alpha: .65),
        );
    }

    // Köyün itibarı, masanın altındaki mühürlerin kaçının aydınlık olduğudur.
    for (var i = 0; i < 5; i++) {
      final lit = i < (favor.clamp(0.0, 1.0) * 5).round();
      canvas.drawCircle(
        Offset(w * .31 + i * 20, h * .90),
        4,
        Paint()..color = lit ? AppUi.sage : AppUi.line,
      );
    }
  }

  void _guard(Canvas c, Offset p, double s) {
    _person(c, p.translate(0, -25 * s), const Color(0xFF69636D), s);
    c.drawRect(
      Rect.fromCenter(
        center: p.translate(10 * s, -16 * s),
        width: 7 * s,
        height: 25 * s,
      ),
      Paint()..color = const Color(0xFF7B2F2E),
    );
  }

  void _person(Canvas c, Offset p, Color color, double scale) {
    c.drawCircle(p, 7 * scale, Paint()..color = const Color(0xFFC08B64));
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: p.translate(0, 17 * scale),
          width: 18 * scale,
          height: 28 * scale,
        ),
        Radius.circular(4 * scale),
      ),
      Paint()..color = color,
    );
  }

  void _sack(Canvas c, Offset p) {
    final path = Path()
      ..moveTo(p.dx - 7, p.dy)
      ..quadraticBezierTo(p.dx - 11, p.dy + 16, p.dx, p.dy + 17)
      ..quadraticBezierTo(p.dx + 11, p.dy + 16, p.dx + 7, p.dy)
      ..close();
    c.drawPath(path, Paint()..color = const Color(0xFFB4925E));
    c.drawLine(
      p.translate(-5, 3),
      p.translate(5, 3),
      Paint()..color = const Color(0xFF725639),
    );
  }

  @override
  bool shouldRepaint(covariant _ImperialDemandPainter old) =>
      old.kind != kind ||
      old.units != units ||
      old.favor != favor ||
      old.guards != guards;
}

class VillageOutcomeDiorama extends StatelessWidget {
  final bool thriving;
  final Color accent;
  final int population;
  final List<double> pillars;

  const VillageOutcomeDiorama({
    super.key,
    required this.thriving,
    required this.accent,
    required this.population,
    this.pillars = const [],
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 176,
    child: CustomPaint(
      painter: _VillageOutcomePainter(
        thriving: thriving,
        accent: accent,
        population: population,
        pillars: pillars,
      ),
    ),
  );
}

class _VillageOutcomePainter extends CustomPainter {
  final bool thriving;
  final Color accent;
  final int population;
  final List<double> pillars;

  const _VillageOutcomePainter({
    required this.thriving,
    required this.accent,
    required this.population,
    required this.pillars,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final sky = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: thriving
            ? const [Color(0xFF18202B), Color(0xFF4B3A35)]
            : const [Color(0xFF090C11), Color(0xFF1D2027)],
      ).createShader(Offset.zero & size);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
      sky,
    );
    final groundY = size.height * .72;
    final hill = Path()
      ..moveTo(0, groundY)
      ..quadraticBezierTo(
        size.width * .24,
        groundY - 28,
        size.width * .48,
        groundY,
      )
      ..quadraticBezierTo(
        size.width * .76,
        groundY - 34,
        size.width,
        groundY - 5,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(hill, Paint()..color = const Color(0xFF12161B));

    final houseCount = math.min(7, math.max(2, (population / 3).ceil()));
    for (var i = 0; i < houseCount; i++) {
      final x = 28.0 + i * (size.width - 56) / math.max(1, houseCount - 1);
      final y = groundY - (i.isOdd ? 8 : 0);
      _house(canvas, Offset(x, y), i, thriving);
    }
    _hearth(canvas, Offset(size.width * .5, groundY + 16), thriving);

    if (pillars.isNotEmpty) {
      final n = pillars.length;
      for (var i = 0; i < n; i++) {
        final x = size.width * .19 + i * size.width * .62 / math.max(1, n - 1);
        final value = pillars[i].clamp(0.0, 1.0);
        canvas.drawLine(
          Offset(x, 27),
          Offset(x, 70),
          Paint()
            ..color = AppUi.line
            ..strokeWidth = 2,
        );
        canvas.drawCircle(
          Offset(x, 68 - value * 34),
          5 + value * 2,
          Paint()..color = Color.lerp(AppUi.rust, accent, value)!,
        );
      }
    }
  }

  void _house(Canvas c, Offset foot, int seed, bool lit) {
    final body = Rect.fromLTWH(foot.dx - 12, foot.dy - 24, 24, 24);
    c.drawRect(body, Paint()..color = const Color(0xFF4D4037));
    final roof = Path()
      ..moveTo(foot.dx - 16, foot.dy - 24)
      ..lineTo(foot.dx, foot.dy - 38 - (seed % 3))
      ..lineTo(foot.dx + 16, foot.dy - 24)
      ..close();
    c.drawPath(roof, Paint()..color = const Color(0xFF29272A));
    c.drawRect(
      Rect.fromLTWH(foot.dx - 4, foot.dy - 15, 8, 15),
      Paint()..color = const Color(0xFF211D1B),
    );
    c.drawRect(
      Rect.fromLTWH(foot.dx + 5, foot.dy - 17, 5, 5),
      Paint()
        ..color = lit ? accent.withValues(alpha: .85) : const Color(0xFF24272B),
    );
  }

  void _hearth(Canvas c, Offset p, bool lit) {
    c.drawOval(
      Rect.fromCenter(center: p.translate(0, 5), width: 42, height: 12),
      Paint()..color = const Color(0xFF080A0D),
    );
    if (!lit) {
      c.drawCircle(p, 4, Paint()..color = const Color(0xFF5A3728));
      return;
    }
    c.drawCircle(p, 20, Paint()..color = accent.withValues(alpha: .10));
    final flame = Path()
      ..moveTo(p.dx, p.dy - 19)
      ..quadraticBezierTo(p.dx + 13, p.dy - 3, p.dx, p.dy + 7)
      ..quadraticBezierTo(p.dx - 11, p.dy - 2, p.dx, p.dy - 19)
      ..close();
    c.drawPath(flame, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(covariant _VillageOutcomePainter old) =>
      old.thriving != thriving ||
      old.accent != accent ||
      old.population != population ||
      old.pillars != pillars;
}

class QuestTrailDiorama extends StatelessWidget {
  final int completed;
  final int total;
  final int activeIndex;

  const QuestTrailDiorama({
    super.key,
    required this.completed,
    required this.total,
    required this.activeIndex,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$completed görev tamamlandı, toplam $total',
    child: SizedBox(
      height: 58,
      width: double.infinity,
      child: CustomPaint(
        painter: _QuestTrailPainter(
          completed: completed,
          total: total,
          activeIndex: activeIndex,
        ),
      ),
    ),
  );
}

class _QuestTrailPainter extends CustomPainter {
  final int completed;
  final int total;
  final int activeIndex;

  const _QuestTrailPainter({
    required this.completed,
    required this.total,
    required this.activeIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final nodes = total.clamp(2, 8);
    final points = <Offset>[];
    for (var i = 0; i < nodes; i++) {
      points.add(
        Offset(12 + i * (size.width - 24) / (nodes - 1), i.isEven ? 35 : 23),
      );
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      path.cubicTo(
        (a.dx + b.dx) / 2,
        a.dy,
        (a.dx + b.dx) / 2,
        b.dy,
        b.dx,
        b.dy,
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = AppUi.line,
    );
    for (var i = 0; i < points.length; i++) {
      final done = i < completed;
      final active = i == completed || i == activeIndex;
      if (active) {
        canvas.drawCircle(
          points[i],
          11,
          Paint()..color = AppUi.accent.withValues(alpha: .14),
        );
      }
      canvas.drawCircle(
        points[i],
        active ? 6 : 4.5,
        Paint()
          ..color = done
              ? AppUi.sage
              : active
              ? AppUi.accent
              : AppUi.surface2,
      );
      if (done) {
        canvas.drawCircle(points[i], 2, Paint()..color = AppUi.textHi);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QuestTrailPainter old) =>
      old.completed != completed ||
      old.total != total ||
      old.activeIndex != activeIndex;
}

class BuildingCutawayDiorama extends StatelessWidget {
  final bool active;
  final double damage;
  final int hands;
  final int wantedHands;
  final double fullness;
  final Color accent;

  const BuildingCutawayDiorama({
    super.key,
    required this.active,
    required this.damage,
    required this.hands,
    required this.wantedHands,
    required this.fullness,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    label:
        '$hands/$wantedHands çalışan, depo doluluğu yüzde ${(fullness * 100).round()}',
    child: Container(
      height: 112,
      decoration: BoxDecoration(
        color: AppUi.surface0,
        borderRadius: BorderRadius.circular(AppUi.radiusSm),
        border: Border.all(color: accent.withValues(alpha: .28)),
      ),
      child: CustomPaint(
        painter: _BuildingCutawayPainter(
          active: active,
          damage: damage,
          hands: hands,
          wantedHands: wantedHands,
          fullness: fullness,
          accent: accent,
        ),
      ),
    ),
  );
}

class _BuildingCutawayPainter extends CustomPainter {
  final bool active;
  final double damage;
  final int hands;
  final int wantedHands;
  final double fullness;
  final Color accent;

  const _BuildingCutawayPainter({
    required this.active,
    required this.damage,
    required this.hands,
    required this.wantedHands,
    required this.fullness,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final floor = size.height - 18;
    final shell = Rect.fromLTWH(18, 27, size.width - 36, floor - 27);
    canvas.drawRect(shell, Paint()..color = const Color(0xFF292522));
    final roof = Path()
      ..moveTo(10, 29)
      ..lineTo(size.width * .5, 7)
      ..lineTo(size.width - 10, 29)
      ..close();
    canvas.drawPath(roof, Paint()..color = const Color(0xFF4A3A31));
    canvas.drawLine(
      Offset(size.width * .61, 31),
      Offset(size.width * .61, floor),
      Paint()
        ..color = AppUi.line
        ..strokeWidth = 1.5,
    );

    final slots = math.max(1, math.max(hands, wantedHands));
    for (var i = 0; i < math.min(4, slots); i++) {
      final filled = i < hands;
      final x = 34.0 + i * 27;
      canvas.drawCircle(
        Offset(x, 57),
        6,
        Paint()..color = filled ? const Color(0xFFC08B64) : AppUi.line,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - 7, 64, 14, 21),
          const Radius.circular(3),
        ),
        Paint()
          ..color = filled ? accent.withValues(alpha: .75) : AppUi.surface2,
      );
    }

    final crates = (fullness.clamp(0.0, 1.0) * 8).round();
    for (var i = 0; i < 8; i++) {
      final x = size.width * .66 + (i % 4) * 17;
      final y = 76.0 - (i ~/ 4) * 17;
      canvas.drawRect(
        Rect.fromLTWH(x, y, 14, 14),
        Paint()..color = i < crates ? const Color(0xFF7B5838) : AppUi.surface1,
      );
      canvas.drawRect(
        Rect.fromLTWH(x, y, 14, 14),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = i < crates ? const Color(0xFFB2814C) : AppUi.line,
      );
    }

    if (active) {
      for (var i = 0; i < 3; i++) {
        canvas.drawCircle(
          Offset(size.width * .78 + i * 6, 18 - i * 4),
          4 + i.toDouble(),
          Paint()..color = accent.withValues(alpha: .10 + i * .04),
        );
      }
    }
    if (damage > .15) {
      final crack = Path()
        ..moveTo(size.width * .47, 29)
        ..lineTo(size.width * .44, 43)
        ..lineTo(size.width * .50, 51)
        ..lineTo(size.width * .46, 67);
      canvas.drawPath(
        crack,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1 + damage * 2
          ..color = AppUi.rust,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BuildingCutawayPainter old) =>
      old.active != active ||
      old.damage != damage ||
      old.hands != hands ||
      old.wantedHands != wantedHands ||
      old.fullness != fullness ||
      old.accent != accent;
}
