import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../world/animal_entity.dart';
import 'asset_style.dart';

/// Sprite tabanlı hayvan çizimi (cow, sheep, chicken).
/// 4 yön × 4 walk-cycle frame. Sheep ve cow için batı yönü doğunun flipped'i
/// kullanılır (cow_w/sheep_w üretilmedi); chicken için 4 yön de mevcut.
class AnimalRenderer {
  // facing → frame index → image (kind bazlı ayrı map)
  static final Map<AnimalFacing, List<ui.Image?>> _cow = {};
  static final Map<AnimalFacing, List<ui.Image?>> _sheep = {};
  static final Map<AnimalFacing, List<ui.Image?>> _chicken = {};

  static final Paint _pSprite = AssetStyle.paint();

  static Future<void> loadAll() async {
    // Cow — 3 yön (n/e/s), batı = doğu flip
    for (final dir in [AnimalFacing.n, AnimalFacing.e, AnimalFacing.s]) {
      final letter = _letter(dir);
      final list = <ui.Image?>[];
      for (int f = 0; f < 4; f++) {
        list.add(await _load('assets/animals/cow_${letter}_$f.png'));
      }
      _cow[dir] = list;
    }
    _cow[AnimalFacing.w] = _cow[AnimalFacing.e]!;

    // Sheep — 3 yön (n/e/s), batı = doğu flip
    for (final dir in [AnimalFacing.n, AnimalFacing.e, AnimalFacing.s]) {
      final letter = _letter(dir);
      final list = <ui.Image?>[];
      for (int f = 0; f < 4; f++) {
        list.add(await _load('assets/animals/sheep_${letter}_$f.png'));
      }
      _sheep[dir] = list;
    }
    _sheep[AnimalFacing.w] = _sheep[AnimalFacing.e]!;

    // Chicken — 4 yön (n/e/s/w hepsi mevcut)
    for (final dir in AnimalFacing.values) {
      final letter = _letter(dir);
      final list = <ui.Image?>[];
      for (int f = 0; f < 4; f++) {
        list.add(await _load('assets/animals/chicken_${letter}_$f.png'));
      }
      _chicken[dir] = list;
    }
  }

  static String _letter(AnimalFacing f) {
    switch (f) {
      case AnimalFacing.n: return 'n';
      case AnimalFacing.e: return 'e';
      case AnimalFacing.s: return 's';
      case AnimalFacing.w: return 'w';
    }
  }

  static Future<ui.Image?> _load(String path) async {
    try {
      final bytes = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      return await AssetStyle.softenAtLoad(frame.image);
    } catch (e) {
      debugPrint('AnimalRenderer: $path yüklenemedi — $e');
      return null;
    }
  }

  /// Cow çizimi — sheep gibi 3 yön sprite + batı doğunun flip'i. Boyut
  /// sheep'in ~1.28×'i (gerçek oran; orijinal procedural 72 px referansı).
  static void drawCow(
    Canvas canvas,
    Offset center, {
    required AnimalFacing facing,
    required double walkPhase,
    required bool isWalking,
  }) {
    _drawSpriteAnimal(_cow, canvas, center,
        facing: facing, walkPhase: walkPhase, isWalking: isWalking,
        drawH: 36.0, flipForWest: true);
  }

  /// Sheep çizimi. [center] = ekran üzerinde hayvanın taban (hoof) noktası.
  /// walk-cycle frame'i isWalking ise walkPhase'den, değilse frame 0 (idle).
  static void drawSheep(
    Canvas canvas,
    Offset center, {
    required AnimalFacing facing,
    required double walkPhase,
    required bool isWalking,
  }) {
    _drawSpriteAnimal(_sheep, canvas, center,
        facing: facing, walkPhase: walkPhase, isWalking: isWalking,
        drawH: 28.0, flipForWest: true);
  }

  /// Chicken çizimi — sheep gibi 4 yön × 4 frame; tüm yönler ayrı sprite,
  /// flip yok. Boyut koyunun ~yarısı kadar (gerçek oran).
  static void drawChicken(
    Canvas canvas,
    Offset center, {
    required AnimalFacing facing,
    required double walkPhase,
    required bool isWalking,
  }) {
    _drawSpriteAnimal(_chicken, canvas, center,
        facing: facing, walkPhase: walkPhase, isWalking: isWalking,
        drawH: 13.0, flipForWest: false);
  }

  /// Ortak sprite çizim — kind'a göre source map değişir.
  static void _drawSpriteAnimal(
    Map<AnimalFacing, List<ui.Image?>> source,
    Canvas canvas,
    Offset center, {
    required AnimalFacing facing,
    required double walkPhase,
    required bool isWalking,
    required double drawH,
    required bool flipForWest,
  }) {
    final list = source[facing];
    if (list == null || list.isEmpty) return;
    final int frameIdx = isWalking
        ? ((walkPhase / (2 * 3.14159265) * 4) % 4).floor()
        : 0;
    final img = list[frameIdx.clamp(0, list.length - 1)];
    if (img == null) return;
    final drawW = drawH * img.width / img.height;

    canvas.save();
    if (flipForWest && facing == AnimalFacing.w) {
      canvas.translate(center.dx, center.dy);
      canvas.scale(-1, 1);
      canvas.translate(-center.dx, -center.dy);
    }
    final dst = Rect.fromLTWH(
      center.dx - drawW / 2,
      center.dy - drawH + 4,
      drawW,
      drawH,
    );
    final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
    canvas.drawImageRect(img, src, dst, _pSprite);
    canvas.restore();
  }
}
