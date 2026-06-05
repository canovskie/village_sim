import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Sprite-sheet tabanlı alev — `assets/effects/flame.png` (12 frame, 32×48 px,
/// horizontal strip). Asset el ile çizildiği için doğal/kaotik akış garanti.
/// Üstüne procedural smoke wisp + spark katmanı eklenir (asset'in dışında).
///
/// firepit ~3.0, lamppost ~1.2, torch ~1.6 önerilen scale.
/// [intensity] 0..1 — alpha modülasyonu (gündüz lamppost zayıf, gece güçlü).
class FlameRenderer {
  static ui.Image? _sheet;
  static const int kFrames    = 12;
  static const double kFrameW = 32;
  static const double kFrameH = 48;
  static const double kFps    = 11; // ~1.1 sn loop

  /// Asset yükleme — initState'te bir kez çağrılmalı (mevcut diğer
  /// renderer'ların loadAll'larıyla aynı pattern).
  static Future<void> loadAll() async {
    try {
      final data  = await rootBundle.load('assets/effects/flame.png');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      _sheet = frame.image;
    } catch (e) {
      debugPrint('FlameRenderer: flame.png yüklenemedi — $e');
    }
  }

  static final _pSprite = Paint()
    ..isAntiAlias = false                       // pixel-art keskin
    ..filterQuality = FilterQuality.none;
  static final _pSpark  = Paint()..isAntiAlias = false;
  static final _pSmoke  = Paint()..isAntiAlias = true;

  /// (cx, cy) alev tabanı (anchor: frame'in alt-orta). [scale] 1.0 ≈ orijinal
  /// 32×48 frame boyutu.
  static void draw(Canvas canvas, double cx, double cy, double scale,
      double time, int seed, {double intensity = 1.0, bool sparks = true}) {
    if (intensity <= 0.0) return;
    final img = _sheet;
    final phase = (seed & 0xFF) * 0.0245;

    if (img != null) {
      // Faz: her alev seed'iyle frame ofseti farklı → eş zamanlı 10 firepit
      // hep aynı frame'de durmasın, asenkron yansın.
      final f = ((time * kFps + seed * 0.37).floor()) % kFrames;
      final src = Rect.fromLTWH(f * kFrameW, 0, kFrameW, kFrameH);
      // scale 1.0 ≈ eski prosedürel alev (18 px yükseklik) — çağırıcılar
      // değişmeden çalışır. Aspect ratio sheet'inkiyle korunur.
      final h = 18.0 * scale;
      final w = h * kFrameW / kFrameH;
      // Anchor: alt-orta → dst rect tabanı (cx, cy)'ye otursun.
      final dst = Rect.fromLTWH(cx - w / 2, cy - h, w, h);
      // Intensity alpha modülasyonu (zayıf alev için gündüz)
      _pSprite.color = Color.fromARGB(
          (255 * intensity).round().clamp(0, 255), 255, 255, 255);
      canvas.drawImageRect(img, src, dst, _pSprite);
    }

    // ── Smoke wisps — alev tepesinin üstünden yükselen ince koyu duman.
    final topY = cy - 18.0 * scale * 0.9;
    _drawSmokeWisps(canvas, cx, topY, scale, time, phase, intensity);

    if (sparks) _drawSparks(canvas, cx, cy, scale, time, phase, intensity, seed);
  }

  /// Üç incommensurate frekanslı sin — periyodik görünmeyen pseudo-random.
  static double _wave(double t, double phase) {
    return sin(t * 1.0 + phase) * 0.50
         + sin(t * 1.73 + phase * 1.4 + 1.3) * 0.30
         + sin(t * 2.41 + phase * 0.7 + 2.7) * 0.20;
  }

  static void _drawSmokeWisps(Canvas canvas, double cx, double topY,
      double scale, double time, double phase, double intensity) {
    const int kWisps = 3;
    for (int i = 0; i < kWisps; i++) {
      final lifecycle = (time * 0.32 + i * 0.33 + phase * 0.4) % 1.0;
      if (lifecycle > 0.95) continue;
      final rise  = lifecycle * 14 * scale;
      final drift = _wave(time * 0.5, phase + i * 0.8) * 2.4 * scale * lifecycle;
      final r = (1.5 + lifecycle * 4.2) * scale;
      final a = lifecycle < 0.18
          ? lifecycle / 0.18
          : 1.0 - (lifecycle - 0.18) / 0.82;
      final alpha = (a * 80 * intensity).round().clamp(0, 100);
      if (alpha < 6) continue;
      _pSmoke.color = Color.fromARGB(alpha, 70, 55, 50);
      canvas.drawCircle(Offset(cx + drift, topY - rise), r, _pSmoke);
    }
  }

  static void _drawSparks(Canvas canvas, double cx, double cy, double scale,
      double time, double phase, double intensity, int seed) {
    const int kSparks = 5;
    final px = scale.clamp(1.0, 4.0);
    final flameH = 18.0 * scale;
    for (int i = 0; i < kSparks; i++) {
      final sPhase = (time * 0.85 + i * 0.27 + phase) % 1.0;
      if (sPhase < 0.05 || sPhase > 0.97) continue;
      final hOffset = _wave(sPhase * 3.5, (seed + i * 11) * 0.21) * scale * 2.4;
      final sx = cx + hOffset;
      final sy = cy - sPhase * flameH * 1.4;
      final colorT = sPhase;
      final r = (255 - colorT * 25).round();
      final g = (180 - colorT * 90).round().clamp(0, 255);
      final b = (60  - colorT * 40).round().clamp(0, 255);
      final sAlpha = ((1 - sPhase) * 180 * intensity).round().clamp(0, 200);
      if (sAlpha < 14) continue;
      _pSpark.color = Color.fromARGB(sAlpha, r, g, b);
      canvas.drawRect(Rect.fromLTWH(sx, sy, px, px), _pSpark);
    }
  }
}
