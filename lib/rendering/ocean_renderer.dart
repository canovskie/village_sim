import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Adayı çevreleyen, ekranı tamamen kaplayan deniz yüzeyi.
///
/// Kamera izometrik ve tepeden baktığı için burada ufuk/gökyüzü çizilmez.
/// Önceki sürüm ekranın üstünde gökyüzü, bulut ve güneş katmanı oluşturuyordu;
/// özellikle boş başlayan yeni köyde bu, adanın denizde değil gökte yüzdüğü
/// izlenimini veriyordu. Derinlik artık yalnız su tonu, akıntı ve parıltıyla
/// anlatılır; bütün ekran aynı yüzey düzleminde kalır.
class OceanRenderer {
  static final Paint _p = Paint()..isAntiAlias = true;

  static Color _scale(Color color, double factor) => Color.fromARGB(
    255,
    (color.r * 255 * factor).round().clamp(0, 255),
    (color.g * 255 * factor).round().clamp(0, 255),
    (color.b * 255 * factor).round().clamp(0, 255),
  );

  static void draw(
    Canvas canvas,
    Size size, {
    double time = 0,
    double dayLight = 1.0,
    Color skyMid = const Color(0xFFA0C0E0),
    Color sunColor = const Color(0xFFFFF1C0),
    double sunOpacity = 0.0,
    double moonOpacity = 0.0,
    double timeOfDay = 0.5,
    bool reducedEffects = false,
  }) {
    final lit = 0.28 + dayLight * 0.72;
    _sea(canvas, size, lit, skyMid);
    if (!reducedEffects) {
      _currentBands(canvas, size, time, lit);
      _wavelets(canvas, size, time, lit);
      _surfaceGlint(
        canvas,
        size,
        time,
        timeOfDay,
        sunColor,
        sunOpacity,
        moonOpacity,
      );
    }
  }

  /// Ufuk çizgisi olmayan hafif çapraz gradyan. Gökyüzü tonu yalnız ortam
  /// yansıması olarak az miktarda karışır; hiçbir bölgede ana renk olmaz.
  static void _sea(Canvas canvas, Size size, double lit, Color skyMid) {
    final surface = _scale(
      Color.lerp(const Color(0xFF438CAA), skyMid, 0.08)!,
      lit,
    );
    final middle = _scale(const Color(0xFF276F94), lit);
    final deep = _scale(const Color(0xFF143E5D), lit * 0.92);
    _p
      ..style = PaintingStyle.fill
      // Dalga/parıltı pass'inin alpha'sı sonraki karede denizi soldurmasın.
      ..color = const Color(0xFFFFFFFF)
      ..blendMode = BlendMode.srcOver
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(size.width * 0.38, size.height),
        [surface, middle, deep],
        const [0.0, 0.48, 1.0],
      );
    canvas.drawRect(Offset.zero & size, _p);
    _p.shader = null;
  }

  /// Geniş ama ince akıntı damarları. Yatay atmosfer bantları yerine hafif
  /// çapraz akarlar; böylece görüntü bir gök gradyanı değil su yüzeyi okur.
  static void _currentBands(Canvas canvas, Size size, double time, double lit) {
    _p
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.2;
    for (var band = 0; band < 6; band++) {
      final path = Path();
      final baseY = size.height * (0.08 + band * 0.18);
      for (double x = -40; x <= size.width + 40; x += 24) {
        final y =
            baseY + x * 0.035 + sin(x * 0.012 + time * 0.16 + band * 1.7) * 8;
        if (x == -40) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      _p.color = Color.fromRGBO(
        174,
        221,
        226,
        (0.055 + (band.isEven ? 0.018 : 0.0)) * lit,
      );
      canvas.drawPath(path, _p);
    }
  }

  /// Ekranın tamamına dağılan kısa dalga çizgileri. Üst bölümde de görünmeleri
  /// yeni köyün boş kıyılarında yüzeyin deniz olarak okunmasını sağlar.
  static void _wavelets(Canvas canvas, Size size, double time, double lit) {
    _p
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.25;
    final columns = max(5, (size.width / 150).ceil());
    final rows = max(4, (size.height / 125).ceil());
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < columns; col++) {
        final hash = (col * 92821 + row * 68917) & 0x7FFFFFFF;
        final cellW = size.width / columns;
        final cellH = size.height / rows;
        final x =
            (col + 0.18 + ((hash >> 3) & 31) / 50) * cellW +
            sin(time * 0.22 + hash * 0.001) * 5;
        final y =
            (row + 0.22 + ((hash >> 8) & 15) / 28) * cellH +
            cos(time * 0.18 + hash * 0.002) * 3;
        final halfWidth = 10.0 + (hash & 15);
        final lift = 2.0 + ((hash >> 5) & 3);
        final path = Path()
          ..moveTo(x - halfWidth, y + 1)
          ..quadraticBezierTo(x, y - lift, x + halfWidth, y + 1);
        _p.color = Color.fromRGBO(
          205,
          237,
          235,
          (0.10 + ((hash >> 11) & 3) * 0.018) * lit,
        );
        canvas.drawPath(path, _p);
      }
    }
  }

  /// Güneş/ay su üstünde kısa, kırık parıltılar bırakır. Gökte disk veya
  /// ufuktan başlayan kesintisiz ışık sütunu yoktur.
  static void _surfaceGlint(
    Canvas canvas,
    Size size,
    double time,
    double timeOfDay,
    Color sunColor,
    double sunOpacity,
    double moonOpacity,
  ) {
    final isMoon = moonOpacity > sunOpacity;
    final strength = max(sunOpacity, moonOpacity * 0.8);
    if (strength <= 0.01) return;

    final phase = isMoon ? (timeOfDay + 0.5) % 1.0 : timeOfDay;
    final normalized = ((phase - 0.25) / 0.50).clamp(0.0, 1.0);
    final centerX = size.width / 2 + size.width * 0.30 * cos(pi * normalized);
    final tint = isMoon ? const Color(0xFFCFE0FF) : sunColor;

    _p
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..blendMode = BlendMode.plus;
    for (var i = 0; i < 11; i++) {
      final y = size.height * (0.08 + i * 0.085);
      final pulse = sin(time * (1.1 + i * 0.07) + i * 1.9) * 0.5 + 0.5;
      if (pulse < 0.24) continue;
      final spread = size.width * (0.018 + i * 0.006);
      final x = centerX + sin(i * 2.3 + time * 0.15) * spread;
      final halfWidth = 6.0 + pulse * (10 + i * 0.7);
      _p
        ..strokeWidth = 1.0 + pulse * 1.4
        ..color = tint.withValues(alpha: 0.12 * pulse * strength);
      canvas.drawLine(Offset(x - halfWidth, y), Offset(x + halfWidth, y), _p);
    }
    _p.blendMode = BlendMode.srcOver;
  }
}
