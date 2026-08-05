import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import '../world/season.dart';
import 'asset_style.dart';

class SeasonalDetailRenderer {
  static ui.Image? _sheet;
  static final _paint = AssetStyle.paint();

  static Future<void> loadAll() async {
    try {
      final data = await rootBundle.load('assets/buildings/seasonal_details_sheet.png');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      _sheet = await AssetStyle.softenAtLoad(frame.image);
    } catch (e) {
      debugPrint('SeasonalDetailRenderer: sheet yüklenemedi — $e');
    }
  }

  static void draw(Canvas canvas, Offset anchor, Season season, int seed, double scale) {
    final sheet = _sheet;
    if (sheet == null || season == Season.winter) return;
    final variant = switch (season) {
      Season.autumn => 0,
      Season.spring => 1,
      Season.summer => 2,
      Season.winter => 0,
    };
    final cellW = sheet.width / 3.0;
    final src = Rect.fromLTWH(cellW * variant, 0, cellW, sheet.height.toDouble());
    final dx = ((seed % 7) - 3) * scale;
    canvas.drawImageRect(
      sheet,
      src,
      Rect.fromCenter(center: anchor.translate(dx, -7 * scale), width: 22 * scale, height: 16 * scale),
      _paint,
    );
  }
}
