import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'asset_style.dart';

class NatureRenderer {
  static ui.Image? _lotus0;
  static ui.Image? _lotus1;
  static ui.Image? _reeds;

  static final Paint _pSprite = AssetStyle.paint();

  static Future<void> loadAll() async {
    _lotus0 = await _load('assets/nature/lotus_0.png');
    _lotus1 = await _load('assets/nature/lotus_1.png');
    _reeds  = await _load('assets/nature/reeds.png');
  }

  static Future<ui.Image?> _load(String path) async {
    try {
      final bytes = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      return await AssetStyle.softenAtLoad(frame.image);
    } catch (e) {
      debugPrint('NatureRenderer: $path yüklenemedi — $e');
      return null;
    }
  }

  // ── Lotus ────────────────────────────────────────────────────────────────────
  /// [center] = gridToScreen(col+0.5, row+0.5) — tile merkezi (güney noktası değil, orta)
  static void drawLotus(
    Canvas canvas,
    Offset center, {
    required int variant,
    double time = 0,
    int seed = 0,
  }) {
    final img = variant == 0 ? _lotus0 : _lotus1;
    if (img == null) return;

    // Hafif sallanma — suyun dalgasıyla senkron
    final bob = sin(time * 0.75 + seed * 0.9) * 1.8;

    // Tile genişliğine göre boyutlandır (2 tile genişliği ~= 64*2 px)
    const drawW = 40.0; // px
    final drawH = drawW * img.height / img.width;

    final dst = Rect.fromCenter(
      center: Offset(center.dx, center.dy + bob),
      width: drawW,
      height: drawH,
    );
    final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());

    canvas.drawImageRect(img, src, dst, _pSprite);
  }

  // ── Reeds ────────────────────────────────────────────────────────────────────
  /// [cx, cy] = ekran merkezi (iki tile ortası, üst nokta seviyesi).
  /// Sazlar yukarıya doğru uzanır; hafif rüzgar sallantısı uygulanır.
  static void drawReeds(
    Canvas canvas,
    double cx,
    double cy, {
    double time = 0,
    int seed = 0,
  }) {
    final img = _reeds;
    if (img == null) return;

    const drawH = 86.0; // px yükseklik
    final drawW = drawH * img.width / img.height;

    final dst = Rect.fromLTWH(cx - drawW / 2, cy - drawH, drawW, drawH);
    final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());

    // Rüzgar sallantısı — tabanı sabit, tepe sallanır
    final sway = sin(time * 1.1 + seed * 1.7) * 0.025;

    canvas.save();
    // Skew pivot tabanda (cx, cy)
    canvas.translate(cx, cy);
    canvas.skew(sway, 0);
    canvas.translate(-cx, -cy);
    canvas.drawImageRect(img, src, dst, _pSprite);
    canvas.restore();
  }
}
