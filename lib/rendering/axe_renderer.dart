import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'asset_style.dart';

/// Balta PNG'sini yükler ve karakter renderer'ın arm callback'i içinde çizer.
/// Çizim koordinatları: arm-local uzay
///   (0,0) = omuz pivot, y+ = aşağı, kol y=0..20 boyunca uzanır.
class AxeRenderer {
  static ui.Image? _axe;
  static final Paint _pSprite = AssetStyle.paint();

  static Future<void> loadAll() async {
    try {
      final bytes = await rootBundle.load('assets/tools/axe.png');
      final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      _axe = await AssetStyle.softenAtLoad(frame.image);
    } catch (e) {
      debugPrint('AxeRenderer: axe.png yüklenemedi — $e');
    }
  }

  /// Arm callback içinden çağır.
  /// Arm-local uzay: omuz = (0,0), kol y=0..20, el ≈ y=14.
  ///
  /// Tutuş mantığı:
  ///   • El (0,14)'e translate et
  ///   • Balta başını hedefe döndürmek için −0.45 rad eğ
  ///   • PNG'nin %68'i yukarıda (baş+sap üstü), %32'si aşağıda (sap kuyruğu)
  static void drawAtHand(Canvas canvas) {
    final img = _axe;
    if (img == null) return;

    // PNG: 638 × 795 — portrait (sap dikey, baş üstte)
    const w = 26.0;
    final h = w * 795.0 / 638.0; // ≈ 32.4

    canvas.save();
    // 1. El konumuna git
    canvas.translate(3, 14);
    // 2. Balta başını öne eğ (+θ = CW = baş sağa/aşağı = hedefe doğru)
    canvas.rotate(0.50);
    // 3. Tutuş noktası PNG'nin %68'inde → baş yukarıda, kuyruk aşağıda
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Rect.fromLTWH(-w * 0.50, -h * 0.68, w, h),
      _pSprite,
    );
    canvas.restore();
  }
}
