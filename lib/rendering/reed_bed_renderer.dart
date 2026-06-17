import 'dart:math';
import 'package:flutter/material.dart';

/// Saz yatağının prosedürel çizimi — örülü saz hasır + baş ucu yastık rulosu.
/// Sprite yok (mezar pattern'i gibi); izometrik oval hasır + dokuma şeritleri.
class ReedBedRenderer {
  static final Paint _p = Paint()..isAntiAlias = true;
  static final Paint _stroke = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  static void draw(Canvas canvas, Offset c, {int seed = 0}) {
    const w = 34.0; // hasır genişliği (px, ekran)
    const h = 18.0; // izometrik derinlik

    // Yumuşak taban gölgesi — yataktan biraz geniş, yere oturtur.
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0x33000000);
    canvas.drawOval(
        Rect.fromCenter(center: c.translate(1, 2), width: w + 6, height: h + 4),
        _p);

    // Hasır gövdesi — sıcak saz beji.
    _p.color = const Color(0xFFC9B070);
    final mat = Rect.fromCenter(center: c, width: w, height: h);
    canvas.drawOval(mat, _p);

    // Kenar örgüsü — koyu hat.
    _stroke
      ..color = const Color(0xFF8E7642)
      ..strokeWidth = 2.0;
    canvas.drawOval(mat, _stroke);

    // Dokuma şeritleri — birkaç hafif eğri çizgi (örülü saz hissi).
    _stroke
      ..color = const Color(0x559C8448)
      ..strokeWidth = 1.0;
    for (int i = -2; i <= 2; i++) {
      final dy = i * (h / 6);
      final ww = w * sqrt(1 - (2 * dy / h) * (2 * dy / h)).clamp(0.0, 1.0);
      canvas.drawLine(
        Offset(c.dx - ww / 2 + 2, c.dy + dy),
        Offset(c.dx + ww / 2 - 2, c.dy + dy),
        _stroke,
      );
    }

    // Baş ucu yastık rulosu — bir uçta daha koyu saz demeti.
    final rnd = Random(seed);
    final headLeft = rnd.nextBool();
    final px = c.dx + (headLeft ? -w * 0.30 : w * 0.30);
    _p.color = const Color(0xFFB89A56);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(px, c.dy - 1), width: w * 0.34, height: h * 0.55),
        _p);
    _stroke
      ..color = const Color(0xFF8E7642)
      ..strokeWidth = 1.2;
    canvas.drawOval(
        Rect.fromCenter(center: Offset(px, c.dy - 1), width: w * 0.34, height: h * 0.55),
        _stroke);
  }
}
