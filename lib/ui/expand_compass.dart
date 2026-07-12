import 'dart:math';
import 'package:flutter/material.dart';
import 'app_ui.dart';

/// Kompakt açılım pusulası — otonom orman kesiminin YÖNÜNÜ belirler. Bir yöne
/// tıkla → köy o yöne doğru açılır; merkeze tıkla → otomatik (köy kütlesine).
/// Düşük mikro: sadece genel niyet; frontier'ı köy kendi yer.
class ExpandCompass extends StatelessWidget {
  final (double, double)? dir; // null = otomatik
  final ValueChanged<(double, double)?> onSet;
  const ExpandCompass({super.key, required this.dir, required this.onSet});

  static const double _sz = 62.0;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Açılım yönü — merkez: otomatik',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTapDown: (d) {
            const c = Offset(_sz / 2, _sz / 2);
            final v = d.localPosition - c;
            if (v.distance < 13) {
              onSet(null); // merkez → otomatik
              return;
            }
            final oct = (atan2(v.dy, v.dx) / (pi / 4)).round();
            final a = oct * (pi / 4);
            onSet((cos(a), sin(a)));
          },
          child: DecoratedBox(
            decoration: BoxDecoration(
                shape: BoxShape.circle, boxShadow: AppUi.softShadow),
            child: CustomPaint(
              size: const Size(_sz, _sz),
              painter: _CompassPainter(dir),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompassPainter extends CustomPainter {
  final (double, double)? dir;
  _CompassPainter(this.dir);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;

    canvas.drawCircle(c, r - 1, Paint()..color = AppUi.surface2);
    canvas.drawCircle(
        c,
        r - 1,
        Paint()
          ..color = AppUi.line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);

    // 8 yön tırnağı
    final tick = Paint()
      ..color = AppUi.textLo
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    for (int i = 0; i < 8; i++) {
      final a = i * pi / 4;
      final o = Offset(cos(a), sin(a));
      canvas.drawLine(c + o * (r - 9), c + o * (r - 5), tick);
    }

    // aktif yön oku (ember)
    final d = dir;
    if (d != null) {
      final a = atan2(d.$2, d.$1);
      final o = Offset(cos(a), sin(a));
      final ap = Paint()
        ..color = AppUi.accent
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true;
      canvas.drawLine(c, c + o * (r - 7), ap);
      canvas.drawCircle(c + o * (r - 7), 3.2, Paint()..color = AppUi.accent);
    }

    // merkez (otomatik ise ember, yön seçiliyse nötr)
    canvas.drawCircle(
        c, 4.5, Paint()..color = d == null ? AppUi.accent : AppUi.surface3);
    canvas.drawCircle(
        c,
        4.5,
        Paint()
          ..color = AppUi.line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
  }

  @override
  bool shouldRepaint(_CompassPainter old) => old.dir != dir;
}
