import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../world/animal_entity.dart';
import 'asset_style.dart';

/// Yürümeyen hayvan için prosedürel idle gövde dili çeşidi. Sprite frame'i
/// donmuş (frame 0) olsa bile hayvana yumuşak bir nefes/otlama/gagalama verir.
enum _IdleMotion {
  /// İnek/koyun: yavaş nefes + ara ara otlamaya eğilme (belly squash).
  graze,
  /// Tavuk: küçük tempolu nefes + keskin, kısa gagalama dip'leri.
  peck,
}

/// Sprite tabanlı hayvan çizimi (cow, sheep, chicken).
/// 4 yön × 4 walk-cycle frame. Sheep ve cow için batı yönü doğunun flipped'i
/// kullanılır (cow_w/sheep_w üretilmedi); chicken için 4 yön de mevcut.
class AnimalRenderer {
  // facing → frame index → image (kind bazlı ayrı map)
  static final Map<AnimalFacing, List<ui.Image?>> _cow = {};
  static final Map<AnimalFacing, List<ui.Image?>> _sheep = {};
  static final Map<AnimalFacing, List<ui.Image?>> _chicken = {};

  static final Paint _pSprite = AssetStyle.paint();

  /// Idle canlılık için sürekli, kameradan bağımsız saat (sn). walkPhase
  /// yürümeyince güvenilir bir hız vermediğinden osilasyon frekansı buradan
  /// gelir; walkPhase yalnızca hayvana özgü faz ofseti olarak eklenir.
  static final Stopwatch _sw = Stopwatch()..start();
  static double get _clock => _sw.elapsedMicroseconds / 1e6;

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
    double scale = 1.0,
    double alpha = 1.0,
  }) {
    _drawSpriteAnimal(_cow, canvas, center,
        facing: facing, walkPhase: walkPhase, isWalking: isWalking,
        drawH: 36.0 * scale, flipForWest: true, alpha: alpha,
        idle: _IdleMotion.graze);
  }

  /// Sheep çizimi. [center] = ekran üzerinde hayvanın taban (hoof) noktası.
  /// walk-cycle frame'i isWalking ise walkPhase'den, değilse frame 0 (idle).
  static void drawSheep(
    Canvas canvas,
    Offset center, {
    required AnimalFacing facing,
    required double walkPhase,
    required bool isWalking,
    double scale = 1.0,
    double alpha = 1.0,
  }) {
    _drawSpriteAnimal(_sheep, canvas, center,
        facing: facing, walkPhase: walkPhase, isWalking: isWalking,
        drawH: 28.0 * scale, flipForWest: true, alpha: alpha,
        idle: _IdleMotion.graze);
  }

  /// Chicken çizimi — sheep gibi 4 yön × 4 frame; tüm yönler ayrı sprite,
  /// flip yok. Boyut koyunun ~yarısı kadar (gerçek oran).
  static void drawChicken(
    Canvas canvas,
    Offset center, {
    required AnimalFacing facing,
    required double walkPhase,
    required bool isWalking,
    double scale = 1.0,
    double alpha = 1.0,
  }) {
    _drawSpriteAnimal(_chicken, canvas, center,
        facing: facing, walkPhase: walkPhase, isWalking: isWalking,
        drawH: 13.0 * scale, flipForWest: false, alpha: alpha,
        idle: _IdleMotion.peck);
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
    double alpha = 1.0,
    _IdleMotion idle = _IdleMotion.graze,
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

    // Yürümeyen hayvan → prosedürel idle gövde dili. Toynak/ayak yere basılı
    // kalsın diye taban noktası (center + alt kayıklık) etrafında ölçekle/döndür.
    // Değerler kasıtlı ufak: kukla zıplaması değil, sakin bir soluk/otlama.
    if (!isWalking) {
      final t = _clock;
      final off = walkPhase; // hayvana özgü faz → sürü senkron soluk almasın
      double vScale, hScale, rot;
      if (idle == _IdleMotion.peck) {
        // Tavuk: küçük tempolu soluk + keskin, kısa gagalama dip'leri.
        final breath = math.sin(t * 3.0 + off);
        final p = math.max(0.0, math.sin(t * 2.3 + off));
        final peck = p * p * p * p; // sivri, ani iniş
        vScale = 1 + 0.035 * breath - 0.11 * peck;
        rot = 0.020 * math.sin(t * 1.5 + off);
      } else {
        // İnek/koyun: yavaş nefes + ara ara otlamaya hafif eğilme (squash).
        final breath = math.sin(t * 1.7 + off);
        final lean = math.max(0.0, math.sin(t * 0.85 + off * 1.3));
        vScale = 1 + 0.028 * breath - 0.022 * lean;
        rot = 0.013 * math.sin(t * 0.9 + off);
      }
      // Hacim korunumu hissi: dikey squash → hafif yatay genişleme.
      hScale = 1 - 0.45 * (vScale - 1);
      final pivotY = center.dy + 4; // dst tabanı ≈ hooves
      canvas.translate(center.dx, pivotY);
      canvas.rotate(rot);
      canvas.scale(hScale, vScale);
      canvas.translate(-center.dx, -pivotY);
    }

    final dst = Rect.fromLTWH(
      center.dx - drawW / 2,
      center.dy - drawH + 4,
      drawW,
      drawH,
    );
    final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
    final paint = alpha >= 1.0
        ? _pSprite
        : (Paint()
          ..isAntiAlias = _pSprite.isAntiAlias
          ..filterQuality = _pSprite.filterQuality
          ..color = _pSprite.color.withValues(alpha: alpha.clamp(0.0, 1.0)));
    canvas.drawImageRect(img, src, dst, paint);
    canvas.restore();
  }
}
