import 'dart:math';
import 'package:flutter/material.dart';

class StarField extends StatelessWidget {
  final double opacity;
  final double time;
  const StarField({super.key, required this.opacity, required this.time});
  @override
  Widget build(BuildContext context) {
    if (opacity <= 0.01) return const SizedBox.shrink();
    return CustomPaint(painter: StarPainter(opacity: opacity, time: time));
  }
}

class StarPainter extends CustomPainter {
  final double opacity;
  final double time;
  const StarPainter({required this.opacity, required this.time});

  // Statik Paint havuzu — frame başına 90+ Paint allocation'ı keser.
  // MaskFilter.blur yerine 2 katmanlı concentric circle ile ışıma → CPU yolu
  // çok daha ucuz.
  static final Paint _pGlow = Paint()..isAntiAlias = true;
  static final Paint _pStar = Paint()..isAntiAlias = false;

  @override
  void paint(Canvas canvas, Size size) {
    const kStars = 90;
    for (int i = 0; i < kStars; i++) {
      final x = ((i * 1731 + 97) % 1000) / 1000.0 * size.width;
      final y = ((i * 617  + 53) % 1000) / 1000.0 * size.height * 0.70;

      final twinkle = (sin(time * (0.8 + (i % 7) * 0.35) + i * 2.3) * 0.25 + 0.75)
          .clamp(0.0, 1.0);
      final a = (opacity * twinkle * 255).round().clamp(0, 255);

      final isBig    = i % 7 == 0;
      final isMedium = i % 3 == 0;
      final sz       = isBig ? 4.0 : isMedium ? 2.0 : 1.5;
      final isCool   = i % 11 == 0;

      // Hâle: 2 katman concentric circle (geniş soluk + dar yarı-parlak)
      if (isBig || isMedium) {
        final glowR = isBig ? 8.0 : 4.0;
        final cx = x + sz / 2;
        final cy = y + sz / 2;
        final glowA1 = (a * 0.12).round().clamp(0, 255);
        final glowA2 = (a * 0.28).round().clamp(0, 255);
        _pGlow.color = isCool
            ? Color.fromARGB(glowA1, 180, 210, 255)
            : Color.fromARGB(glowA1, 255, 250, 200);
        canvas.drawCircle(Offset(cx, cy), glowR, _pGlow);
        _pGlow.color = isCool
            ? Color.fromARGB(glowA2, 180, 210, 255)
            : Color.fromARGB(glowA2, 255, 250, 200);
        canvas.drawCircle(Offset(cx, cy), glowR * 0.55, _pGlow);
      }

      _pStar.color = isCool
          ? Color.fromARGB(a, 200, 220, 255)
          : Color.fromARGB(a, 255, 255, 230);
      canvas.drawRect(Rect.fromLTWH(x, y, sz, sz), _pStar);
    }
  }

  @override
  bool shouldRepaint(StarPainter old) =>
      old.opacity != opacity || old.time != time;
}

class PixelSky extends StatelessWidget {
  final Color topColor;
  final Color midColor;
  const PixelSky({super.key, required this.topColor, required this.midColor});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            topColor,
            topColor,
            midColor,
            midColor,
          ],
          stops: const [0.0, 0.30, 0.72, 1.0],
        ),
      ),
    );
  }
}

class PixelSun extends StatelessWidget {
  final Color color;
  const PixelSun({super.key, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(width: 32, height: 32, color: color);
  }
}

class PixelMoon extends StatelessWidget {
  const PixelMoon({super.key});
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(width: 24, height: 24, color: const Color(0xFFDDDDAA)),
        Positioned(top: 0, right: 0,
          child: Container(width: 10, height: 24, color: Colors.transparent)),
        // Ay hilali efekti
        Positioned(top: 2, left: 8,
          child: Container(width: 18, height: 20,
              decoration: BoxDecoration(
                color: const Color(0xFF060C1C),
                borderRadius: BorderRadius.circular(12),
              ))),
      ],
    );
  }
}

/// Pixel-art bulut. [scale] boyut çarpanı (0.5 küçük, 1.0 normal, 1.6 büyük).
/// [dark] yağmurlu gri ton.  [parallax] uzaklık (0.0 çok uzak/soluk,
/// 1.0 yakın/net) — alpha ve renk doygunluğunu etkiler.
class PixelCloud extends StatelessWidget {
  final bool   dark;
  final double scale;
  final double parallax;
  const PixelCloud({
    super.key,
    this.dark     = false,
    this.scale    = 1.0,
    this.parallax = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    // Uzak bulutlar soluk + biraz daha mavi (atmosferik perspektif)
    final baseDk = dark ? const Color(0xFF888888) : const Color(0xFFEEEEEE);
    final baseLt = dark ? const Color(0xFFAAAAAA) : const Color(0xFFFFFFFF);
    // Alpha parallax ile — uzak: %50, yakın: %85
    final alpha = (0.50 + parallax * 0.35).clamp(0.0, 1.0);
    final c1 = baseDk.withValues(alpha: alpha * 0.80);
    final c2 = baseLt.withValues(alpha: alpha);
    // Daha derinlikli silüet: 5 dikdörtgen, alt-üst basamaklı
    final h1 = 6.0  * scale;
    final h2 = 10.0 * scale;
    final h3 = 14.0 * scale;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(width: 10.0 * scale, height: h1, color: c1),
        Container(width: 14.0 * scale, height: h2, color: c2),
        Container(width: 20.0 * scale, height: h3, color: c2),
        Container(width: 14.0 * scale, height: h2, color: c2),
        Container(width: 10.0 * scale, height: h1, color: c1),
      ],
    );
  }
}
