import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Sprite-sheet su parıltısı — `assets/effects/water_shimmer.png` (8 frame
/// horizontal strip). Frame boyutu **runtime'da** `img.width / kFrames`
/// olarak hesaplanır → asset hangi piksel boyutunda gelirse gelsin çalışır.
///
/// Anchor: frame merkezi (cx, cy üstüne ortalanır). Tipik scale 0.4-0.6 →
/// ekranda 8-14 px parıltı (tile boyutuyla uyumlu, abartısız).
///
/// Birden çok shimmer instance'i için her birine farklı [seed] verilir,
/// frame fazı asenkron yansır — eş zamanlılık olmaz.
class WaterShimmerRenderer {
  static ui.Image? _sheet;
  static const int kFrames = 8;
  static const double kFps = 8; // 1 sn loop
  /// Display: scale 1.0 = ~20 px görsel yükseklik. Aspect ratio sheet'ten
  /// gelir (yatay strip frame'inin oranı).
  static const double kBaseSize = 20.0;

  static Future<void> loadAll() async {
    try {
      final data  = await rootBundle.load('assets/effects/water_shimmer.png');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      _sheet = frame.image;
    } catch (e) {
      debugPrint('WaterShimmerRenderer: water_shimmer.png yüklenemedi — $e');
    }
  }

  static final _pSprite = Paint()
    ..isAntiAlias = false
    ..filterQuality = FilterQuality.none;

  /// (cx, cy) shimmer merkez konumu (su tile'ı civarı).
  /// [scale] 1.0 ≈ 20 px görsel boy. [intensity] 0..1 alpha çarpanı.
  static void draw(Canvas canvas, double cx, double cy, double scale,
      double time, int seed, {double intensity = 1.0}) {
    if (intensity <= 0.0) return;
    final img = _sheet;
    if (img == null) return;

    // Runtime frame size — AI'ın ürettiği herhangi bir boyut için.
    final frameW = img.width / kFrames;
    final frameH = img.height.toDouble();

    // Frame fazı seed'le asenkron — 20 shimmer hep aynı frame'de durmasın.
    final f = ((time * kFps + seed * 0.31).floor()) % kFrames;
    final src = Rect.fromLTWH(f * frameW, 0, frameW, frameH);

    // Display: kBaseSize üzerinden aspect ratio'yu sheet'ten devral.
    final dh = kBaseSize * scale;
    final dw = dh * frameW / frameH;
    final dst = Rect.fromLTWH(cx - dw / 2, cy - dh / 2, dw, dh);

    _pSprite.color = Color.fromARGB(
        (255 * intensity).round().clamp(0, 255), 255, 255, 255);
    canvas.drawImageRect(img, src, dst, _pSprite);
  }
}
