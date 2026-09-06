import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../buildings/building_design.dart';
import '../buildings/building_type.dart';
import '../world/season.dart';
import 'asset_style.dart';

/// Small garden accents anchored to each house's artwork, away from its door.
/// Already furnished garden/artisan houses and manors need no extra clutter.
class HouseholdDecorRenderer {
  static final Map<bool, ui.Image> _images = {};
  static final Paint _paint = AssetStyle.paint();

  static Future<void> loadAll() async {
    if (_images.length == 2) return;
    for (final stone in [false, true]) {
      if (_images.containsKey(stone)) continue;
      final path = stone
          ? 'assets/decor/stone_lavender_trough.png'
          : 'assets/decor/cottage_herb_planter.png';
      try {
        final data = await rootBundle.load(path);
        // Tiny world accents do not need full-size textures in GPU memory.
        final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(),
          targetWidth: 384,
        );
        final frame = await codec.getNextFrame();
        codec.dispose();
        _images[stone] = await AssetStyle.softenAtLoad(frame.image);
      } catch (error) {
        debugPrint('HouseholdDecorRenderer: $path yüklenemedi — $error');
      }
    }
  }

  static void draw(
    Canvas canvas,
    BuildingType type,
    BuildingDesign design,
    Rect houseBounds,
    Season season,
  ) {
    // The snow artwork has different foundations and its own winter dressing.
    if (season == Season.winter) return;
    final (stone, centerX, bottomY, relativeWidth) = switch ((type, design)) {
      (BuildingType.woodenHouse, BuildingDesign.original) => (
        false,
        0.72,
        0.94,
        0.18,
      ),
      (BuildingType.woodenHouse, BuildingDesign.terracotta) => (
        false,
        0.73,
        0.94,
        0.18,
      ),
      (BuildingType.stoneHouseBlue, _) => (true, 0.665, 0.94, 0.15),
      _ => (false, 0.0, 0.0, 0.0),
    };
    if (relativeWidth == 0) return;
    final image = _images[stone];
    if (image == null) return;

    // Measured alpha bounds; retain the PNG's original transparency, excluding
    // only empty canvas so padding cannot change scale or ground contact.
    final source = stone
        ? const Rect.fromLTRB(285 / 1536, 101 / 1024, 1280 / 1536, 924 / 1024)
        : const Rect.fromLTRB(198 / 1470, 70 / 1070, 1339 / 1470, 950 / 1070);
    final src = Rect.fromLTRB(
      source.left * image.width,
      source.top * image.height,
      source.right * image.width,
      source.bottom * image.height,
    );
    final width = houseBounds.width * relativeWidth;
    final height = width * src.height / src.width;
    canvas.drawImageRect(
      image,
      src,
      Rect.fromLTWH(
        houseBounds.left + houseBounds.width * centerX - width / 2,
        houseBounds.top + houseBounds.height * bottomY - height,
        width,
        height,
      ),
      _paint,
    );
  }
}
