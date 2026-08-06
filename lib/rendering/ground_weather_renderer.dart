import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'asset_style.dart';

class GroundWeatherRenderer {
  static ui.Image? _sheet;
  static final _paint = AssetStyle.paint();
  static bool get isReady => _sheet != null;

  static Future<void> loadAll() async {
    try {
      final data = await rootBundle.load('assets/effects/ground_weather_sheet.png');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      _sheet = await AssetStyle.softenAtLoad(frame.image);
    } catch (e) {
      debugPrint('GroundWeatherRenderer: sheet yüklenemedi — $e');
    }
  }

  static void draw(Canvas canvas, Offset center, int variant, double scale) {
    final sheet = _sheet;
    if (sheet == null) return;
    final cellW = sheet.width / 3.0;
    final src = Rect.fromLTWH(cellW * (variant % 3), 0, cellW, sheet.height.toDouble());
    canvas.drawImageRect(
      sheet,
      src,
      Rect.fromCenter(center: center, width: 28 * scale, height: 18 * scale),
      _paint,
    );
  }
}
