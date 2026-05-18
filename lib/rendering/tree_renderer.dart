import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../world/tree_entity.dart';
import '../core/constants.dart';
import 'asset_style.dart';

class TreeRenderer {
  static final Map<TreeType, ui.Image> _cache = {};

  // Sprite paint AssetStyle'dan — soft texture
  static final Paint _pSprite = AssetStyle.paint();

  static Future<void> loadAll() async {
    await _load(TreeType.pine, 'assets/trees/pine.png');
  }

  static Future<void> _load(TreeType type, String path) async {
    try {
      final bytes = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      _cache[type] = await AssetStyle.softenAtLoad(frame.image);
    } catch (e) {
      debugPrint('TreeRenderer: $path yüklenemedi — $e');
    }
  }

  /// Sprite'ı tile merkezine çizer.
  ///
  /// [center]    = gridToScreen(col+0.5, row+0.5)
  /// [seed]      = ağaca özgü faz (col*17+row*31)
  /// [chopPhase] = −1: kesim yok.  0..2π: darbe anından bu yana geçen faz.
  ///               0 = darbe tam isabet — titreşim başlar, azalır, 2π'de söner.
  static void draw(Canvas canvas, TreeType type, Offset center,
      {double time = 0, int seed = 0, double chopPhase = -1,
       double growthScale = 1.0}) {
    final img = _cache[type];
    if (img == null) return;

    final spriteW = kTileW * 1.3 * growthScale;
    final spriteH = spriteW * img.height / img.width;
    final left    = (center.dx - spriteW / 2).roundToDouble();
    // Fidan tabandan büyür — taban sabit, tepe yükselir
    final top     = center.dy - spriteH;

    // ── Rüzgar sallantısı ─────────────────────────────────────────────────
    final freq     = 0.7 + (seed % 7) * 0.08;
    final phase    = (seed * 1.618) % (2 * pi);
    final amp      = 0.028 + (seed % 5) * 0.004;
    final windSway = sin(time * freq + phase) * amp;

    // ── Darbe titreşimi (damlı harmonik) ──────────────────────────────────
    // chopPhase=0 → darbe isabet etti → ağaç sarsılır → sönümler → 2π'ye kadar durulur
    // Formül: e^(−λ·t) · sin(ω·t)   (t = darbe sonrası geçen süre, saniye cinsinden)
    //   λ = sönüm katsayısı (kaç saniyede durulduğunu belirler)
    //   ω = titreşim açısal frekansı (Hz * 2π)
    double impactSway = 0;
    if (chopPhase >= 0) {
      // chopPhase 0..2π = darbe sonrası bir döngü (1/1.1 ≈ 0.91 sn)
      const cycleTime = 1.0 / 1.1;
      final t = (chopPhase / (2 * pi)) * cycleTime; // saniye cinsinden darbe sonrası süre
      const lambda = 10.0; // sönüm: ~0.3 sn sonra <%5
      const omega  = 40.0; // ~6.4 Hz titreşim
      impactSway = exp(-lambda * t) * sin(omega * t) * 0.14;
    }

    final sway  = windSway + impactSway;
    final baseY = top + spriteH;

    canvas.save();
    canvas.translate(center.dx, baseY);
    canvas.skew(sway, 0);
    canvas.translate(-center.dx, -baseY);

    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Rect.fromLTWH(left, top, spriteW, spriteH),
      _pSprite,
    );
    canvas.restore();
  }
}
