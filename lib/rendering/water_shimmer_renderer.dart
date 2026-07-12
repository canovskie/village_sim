import 'dart:math' show sin, pi;
import 'package:flutter/material.dart';

/// Sprite üzerindeki su bölgelerine (şadırvan havuzu, hamam su kanalı) animasyonlu
/// ışıltı ekler: nazik sheen + dikey kayan kostik şeritler + twinkle eden sparkle.
/// Eklemeli (BlendMode.plus) ama yumuşak değerlerle — abartısız (lighting restraint).
/// Bölge bir iso 2:1 ellipse ile maskelenir, ışıltı dışarı taşmaz.
class WaterShimmerRenderer {
  static final _p = Paint()..isAntiAlias = true;

  /// [cx],[cy] su bölgesi ekran merkezi; [hw],[hh] yarı eksenler (ekran px).
  /// [dayLight] gündüz güçlü ışıltı; gece tabanı korunur (fener yansıması).
  static void draw(Canvas canvas, double cx, double cy, double hw, double hh,
      double time, int seed,
      {double dayLight = 1.0, double intensity = 1.0}) {
    if (hw <= 1 || hh <= 1) return;
    final lit = (0.35 + dayLight * 0.65) * intensity;
    if (lit <= 0.02) return;
    final phase = (seed * 1373 % 1000) / 1000.0 * 2 * pi;

    final oval = Rect.fromCenter(
        center: Offset(cx, cy), width: hw * 2, height: hh * 2);
    canvas.save();
    canvas.clipPath(Path()..addOval(oval));
    _p.blendMode = BlendMode.plus;

    // 1) Merkezde nefes alan yumuşak sheen.
    final breath = sin(time * 0.9 + phase) * 0.5 + 0.5;
    _p.color = Color.fromARGB(
        (24 * lit * (0.55 + breath * 0.45)).round().clamp(0, 60), 200, 235, 255);
    canvas.drawOval(oval.deflate(hw * 0.10), _p);

    // 2) Kostik şeritler — yatay dalgalı parlak çizgiler, dikey kayar.
    for (int i = 0; i < 3; i++) {
      final t = (time * (0.16 + i * 0.05) + i * 0.37 + phase * 0.3) % 1.0;
      final ly = cy - hh + t * hh * 2;
      final wob = sin(time * 1.3 + i * 2.0 + phase) * hh * 0.16;
      final a = (sin(t * pi) * 42 * lit).round().clamp(0, 64); // uçlarda solar
      _p.color = Color.fromARGB(a, 215, 245, 255);
      canvas.drawRect(Rect.fromLTWH(cx - hw, ly + wob, hw * 2, 1.2), _p);
    }

    // 3) Twinkle eden sparkle noktaları.
    for (int i = 0; i < 6; i++) {
      final sx = ((seed * (17 + i * 11) + 7) % 97) / 97.0;
      final sy = ((seed * (23 + i * 13) + 13) % 89) / 89.0;
      final spX = cx + (sx - 0.5) * hw * 1.7;
      final spY = cy + (sy - 0.5) * hh * 1.7;
      final tw = sin(time * (1.4 + i * 0.5) + phase + i * 2.1) * 0.5 + 0.5;
      if (tw > 0.62) {
        final a = ((tw - 0.62) / 0.38 * 200 * lit).round().clamp(0, 220);
        _p.color = Color.fromARGB(a, 230, 250, 255);
        final s = 1.0 + tw * 1.3;
        canvas.drawRect(
            Rect.fromCenter(center: Offset(spX, spY), width: s, height: s), _p);
      }
    }

    _p.blendMode = BlendMode.srcOver;
    canvas.restore();
  }
}
