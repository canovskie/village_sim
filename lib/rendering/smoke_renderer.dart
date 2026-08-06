import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Sprite-sheet tabanlı duman — `assets/effects/smoke.png` (16 frame, yatay
/// strip). PNG'nin alpha kanalı **yok** (ChatGPT export RGB), ama runtime'da
/// `ColorFilter.matrix` ile beyaz arka planı transparant'a çeviriyoruz +
/// istenen tinte boyuyoruz → kullanıcı asset'i yeniden export etmek zorunda
/// kalmıyor.
///
/// Color matrix mantığı:
///   A_out = 255 − ortalama(R+G+B)/3  → beyaz=0, siyah=255 (inverse luma)
///   RGB_out = tint (sabit; gri kanalları yok edip rengi tint'le değiştirir)
///
/// Sonuç: PNG'nin koyu pikselleri opak tint olur, açık beyaz/checker zemin
/// görünmez. Baca için warm-gray, yangın için koyu, vb runtime'da değişir.
class SmokeRenderer {
  static ui.Image? _sheet;
  static const int kFrames    = 16;
  // PNG 4096×384 → her frame 256×384 px (16 frame yatay).
  static const double kFrameW = 256;
  static const double kFrameH = 384;
  static const double kFps    = 8.0; // ~2 sn loop

  /// Asset'i yükle — initState'te bir kez.
  static Future<void> loadAll() async {
    try {
      final data  = await rootBundle.load('assets/effects/smoke.png');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      _sheet = frame.image;
    } catch (e) {
      debugPrint('SmokeRenderer: smoke.png yüklenemedi — $e');
    }
  }

  // Sprite paint havuzu — `tint` değiştikçe colorFilter yeniden bind edilir.
  static final _pSprite = Paint()
    ..isAntiAlias = false
    ..filterQuality = FilterQuality.none;

  /// Beyaz → transparent + tint uygulayan 4×5 ColorMatrix oluşturur.
  /// Bu matrix sahnedeki dst pixel'ini: alpha = 255-luma, color = tint.
  static ColorFilter _filterFor(Color tint, double intensity) {
    final r = tint.r * 255;
    final g = tint.g * 255;
    final b = tint.b * 255;
    final iA = intensity.clamp(0.0, 1.0);
    // Alpha hesabı: A = (255 - (R+G+B)/3) × intensity
    // Bu 5-stop matrix: [A_R, A_G, A_B, A_A, A_offset] son satır
    return ColorFilter.matrix([
      0, 0, 0, 0, r,                     // R_out = tint.r
      0, 0, 0, 0, g,                     // G_out = tint.g
      0, 0, 0, 0, b,                     // B_out = tint.b
      -iA/3, -iA/3, -iA/3, 0, 255 * iA,  // A_out = (255 - luma) × intensity
    ]);
  }

  /// (cx, cy) duman çıkış noktası (anchor: frame'in alt-orta).
  /// [scale] 1.0 ≈ 30 px görsel yükseklik. firepit baca ~1.2, ev ~0.7,
  /// yangın ~2.0.
  /// [tint] rengi ile boyanır (default warm-gray bej). [intensity] 0..1
  /// alpha çarpanı (yağmurda boost, kuraklıkta normal vb).
  static void draw(Canvas canvas, double cx, double cy, double scale,
      double time, int seed,
      {Color tint = const Color(0xFFC8B8A0),
       double intensity = 1.0}) {
    if (intensity <= 0.0) return;
    final img = _sheet;
    if (img == null) return;

    // Frame: seed ile asenkron (her duman kaynağı farklı fazda).
    final f = ((time * kFps + seed * 0.43).floor()) % kFrames;
    final src = Rect.fromLTWH(f * kFrameW, 0, kFrameW, kFrameH);

    // Display: scale 1.0 = 30 px yükseklik. Aspect oranı sheet'inkinden korunur.
    final h = 30.0 * scale;
    final w = h * kFrameW / kFrameH; // = h × 0.667
    final dst = Rect.fromLTWH(cx - w / 2, cy - h, w, h);

    _pSprite.colorFilter = _filterFor(tint, intensity);
    canvas.drawImageRect(img, src, dst, _pSprite);
    _pSprite.colorFilter = null;
  }
}
