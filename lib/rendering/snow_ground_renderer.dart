import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants.dart';
import 'asset_style.dart';

class SnowGroundRenderer {
  static ui.Image? _sheet;
  static final _paint = AssetStyle.paint();
  static bool get isReady => _sheet != null;

  static Future<void> loadAll() async {
    try {
      final data = await rootBundle.load('assets/tiles/snow_ground_sheet.png');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      _sheet = await AssetStyle.softenAtLoad(frame.image);
    } catch (e) {
      debugPrint('SnowGroundRenderer: sprite sheet yüklenemedi — $e');
    }
  }

  static void draw(Canvas canvas, double px, double py, int variant, double zoom) {
    final sheet = _sheet;
    if (sheet == null) return;
    final cellW = sheet.width / 2.0;
    // Görsel sheet'in kare hücresinde geniş transparan padding var. Hücrenin
    // tamamını sıkıştırmak yerine gerçek kar elmasını crop ediyoruz; aksi halde
    // zoom'da tile küçük görünür, komşu çim ve kenar dikişleri ortaya çıkar.
    final src = Rect.fromLTWH(
      cellW * (variant % 2) + 34,
      126,
      cellW - 68,
      620,
    );
    final hw = kTileW * zoom / 2 + 2.0 * zoom;
    final hh = kTileH * zoom / 2 + 2.0 * zoom;
    final diamond = Path()
      ..moveTo(px, py - 1.0 * zoom)
      ..lineTo(px + hw, py + hh)
      ..lineTo(px, py + 2 * hh + 1.0 * zoom)
      ..lineTo(px - hw, py + hh)
      ..close();
    canvas.save();
    canvas.clipPath(diamond);
    canvas.drawImageRect(sheet, src,
        Rect.fromLTWH(px - hw, py - 1.0 * zoom, hw * 2, hh * 2), _paint);
    canvas.restore();
  }
}
