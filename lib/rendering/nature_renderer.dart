import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'asset_style.dart';
import 'wind.dart';

class NatureRenderer {
  static ui.Image? _lotus0;
  static ui.Image? _lotus1;
  static ui.Image? _reeds;

  static final Paint _pSprite = AssetStyle.paint();
  // Biçilmiş sazın anızı — kısa, soluk kesik saplar.
  static final Paint _pStubble = Paint()
    ..color = const Color(0xFF7E8A4E)
    ..strokeWidth = 1.6
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;

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
    double col = 0,
    double row = 0,
    double growth = 1.0, // 0 = yeni biçilmiş (anız), 1 = olgun
  }) {
    final img = _reeds;
    if (img == null) return;

    // Biçilmiş / yeni filiz — kısa anız sapları çiz, sprite yok.
    if (growth < 0.18) {
      final rnd = Random(seed);
      final n = 4 + rnd.nextInt(3);
      for (int i = 0; i < n; i++) {
        final dx = (rnd.nextDouble() - 0.5) * 26;
        final h  = 4.0 + rnd.nextDouble() * 4.0;
        final lean = (rnd.nextDouble() - 0.5) * 3;
        canvas.drawLine(
          Offset(cx + dx, cy), Offset(cx + dx + lean, cy - h), _pStubble);
      }
      return;
    }

    // Büyürken kısadan tam boya uzar (taban sabit).
    final drawH = 86.0 * (0.4 + 0.6 * growth.clamp(0.0, 1.0));
    final drawW = drawH * img.width / img.height;

    final dst = Rect.fromLTWH(cx - drawW / 2, cy - drawH, drawW, drawH);
    final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());

    // Rüzgar sallantısı — ortak rüzgâr alanı (ağaçlarla aynı dalga). Saz ince,
    // genliği biraz büyük; tabanı sabit, tepe sallanır.
    final sway = Wind.swayAt(col, row, time, amp: 0.045, jitter: seed * 1.7);

    canvas.save();
    // Skew pivot tabanda (cx, cy)
    canvas.translate(cx, cy);
    canvas.skew(sway, 0);
    canvas.translate(-cx, -cy);
    canvas.drawImageRect(img, src, dst, _pSprite);
    canvas.restore();
  }
}
