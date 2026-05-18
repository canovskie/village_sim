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

  @override
  void paint(Canvas canvas, Size size) {
    const kStars = 90;
    for (int i = 0; i < kStars; i++) {
      // Pseudo-random dağılım — şerit oluşturmaz
      final x = ((i * 1731 + 97) % 1000) / 1000.0 * size.width;
      final y = ((i * 617  + 53) % 1000) / 1000.0 * size.height * 0.70;

      // Her yıldız farklı frekansta titreşir
      final twinkle = (sin(time * (0.8 + (i % 7) * 0.35) + i * 2.3) * 0.25 + 0.75)
          .clamp(0.0, 1.0);
      final a = (opacity * twinkle * 255).round().clamp(0, 255);

      // Büyüklük: her 7'de bir büyük, her 3'te bir orta, geri kalan küçük
      final isBig    = i % 7 == 0;
      final isMedium = i % 3 == 0;
      final sz       = isBig ? 4.0 : isMedium ? 2.0 : 1.5;

      // Çoğu sıcak beyaz, bazıları mavimsi
      final isCool = i % 11 == 0;
      final color  = isCool
          ? Color.fromARGB(a, 200, 220, 255)
          : Color.fromARGB(a, 255, 255, 230);

      // Hâle (blur ile ışıma) — büyük yıldızlarda daha belirgin
      if (isBig || isMedium) {
        final glowR  = isBig ? 8.0 : 4.0;
        final glowA  = (a * 0.35).round().clamp(0, 255);
        final glowC  = isCool
            ? Color.fromARGB(glowA, 180, 210, 255)
            : Color.fromARGB(glowA, 255, 250, 200);
        canvas.drawCircle(
          Offset(x + sz / 2, y + sz / 2),
          glowR,
          Paint()
            ..color      = glowC
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowR * 0.8)
            ..isAntiAlias = true,
        );
      }

      // Yıldız kendisi
      canvas.drawRect(
        Rect.fromLTWH(x, y, sz, sz),
        Paint()..color = color..isAntiAlias = false,
      );
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

class PixelCloud extends StatelessWidget {
  final bool dark;
  const PixelCloud({super.key, this.dark = false});
  @override
  Widget build(BuildContext context) {
    final c1 = dark ? const Color(0xCC888888) : const Color(0xCCEEEEEE);
    final c2 = dark ? const Color(0xCCAAAAAA) : const Color(0xCCFFFFFF);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(width: 16, height: 8,  color: c1),
        Container(width: 24, height: 12, color: c2),
        Container(width: 16, height: 8,  color: c1),
      ],
    );
  }
}
