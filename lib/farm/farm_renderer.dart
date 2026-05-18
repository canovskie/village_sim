import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../rendering/asset_style.dart';

class FarmRenderer {
  static final List<ui.Image?> _stages = List.filled(5, null);

  // ── Static Paint havuzu ────────────────────────────────────────────────────
  // Asset paint AssetStyle'dan — yumuşatma merkezi
  static final _pImg = AssetStyle.paint();
  static final _pBorder = Paint()
    ..color       = const Color(0xFF7A5218)
    ..style       = PaintingStyle.stroke
    ..strokeWidth = 1
    ..isAntiAlias = false;

  static final Path _diamond = Path();

  static Future<void> loadAll() async {
    for (int i = 0; i < 5; i++) {
      try {
        final bytes = await rootBundle.load('assets/tiles/farm_$i.png');
        final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
        final frame = await codec.getNextFrame();
        _stages[i] = await AssetStyle.softenAtLoad(frame.image);
      } catch (e) {
        debugPrint('FarmRenderer: farm_$i.png yüklenemedi — $e');
      }
    }
  }

  static void drawTile(Canvas canvas,
      double px, double py, double hw, double hh,
      int stage, double progress) {

    _diamond
      ..reset()
      ..moveTo(px,      py)
      ..lineTo(px + hw, py + hh)
      ..lineTo(px,      py + hh * 2)
      ..lineTo(px - hw, py + hh)
      ..close();

    final dst = Rect.fromLTWH(px - hw, py, hw * 2, hh * 2);
    final s   = stage.clamp(0, 4);

    canvas.save();
    canvas.clipPath(_diamond);

    _blit(canvas, s, dst, 1.0);

    if (progress > 0.65 && s < 4) {
      final t = ((progress - 0.65) / 0.35).clamp(0.0, 1.0);
      _blit(canvas, s + 1, dst, t.toDouble());
    }

    canvas.restore();

    canvas.drawPath(_diamond, _pBorder);
  }

  static void _blit(Canvas canvas, int stage, Rect dst, double alpha) {
    final img = _stages[stage.clamp(0, 4)];
    if (img == null) return;
    final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
    if (alpha < 1.0) {
      _pImg.color = Color.fromRGBO(255, 255, 255, alpha);
    } else {
      _pImg.color = const Color(0xFFFFFFFF);
    }
    canvas.drawImageRect(img, src, dst, _pImg);
  }
}
