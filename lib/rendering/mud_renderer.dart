import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'asset_style.dart';

/// Yağmur sonrası çamur izleri için gerçek pixel-art sprite sheet'i.
class MudRenderer {
  static ui.Image? _sheet;
  static final _paint = AssetStyle.paint();

  static Future<void> loadAll() async {
    try {
      final data = await rootBundle.load('assets/nature/mud/mud_sheet.png');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      _sheet = await AssetStyle.softenAtLoad(frame.image);
    } catch (e) {
      debugPrint('MudRenderer: sprite sheet yüklenemedi — $e');
    }
  }

  static void draw(Canvas canvas, Offset center, int variant, double zoom) {
    final sheet = _sheet;
    if (sheet == null) return;
    final cellW = sheet.width / 3.0;
    final src = Rect.fromLTWH(cellW * (variant % 3), 0, cellW, sheet.height.toDouble());
    final w = 34.0 * zoom;
    final h = 16.0 * zoom;
    canvas.drawImageRect(
      sheet,
      src,
      Rect.fromCenter(center: center.translate(0, 4.0 * zoom), width: w, height: h),
      _paint,
    );
  }
}
