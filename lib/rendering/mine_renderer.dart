import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants.dart';
import '../world/mine_node.dart';
import 'asset_style.dart';

/// İzometrik maden/kaya bloğu çizer.
/// Taş madenleri için PNG asset, demir/kömür için programatik.
class MineRenderer {
  static final List<ui.Image?> _rocks = [null, null, null, null];
  static ui.Image? _iron;
  static ui.Image? _coal;

  // Sprite paint AssetStyle'dan — yumuşatma merkezi
  static final Paint _pSprite = AssetStyle.paint();

  static Future<void> loadAll() async {
    for (int i = 0; i < 4; i++) {
      try {
        final bytes = await rootBundle.load('assets/nature/rock_$i.png');
        final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
        _rocks[i] = await AssetStyle.softenAtLoad((await codec.getNextFrame()).image);
      } catch (e) {
        debugPrint('MineRenderer: rock_$i yüklenemedi — $e');
      }
    }
    _iron = await _loadImg('assets/nature/iron.png');
    _coal = await _loadImg('assets/nature/coal.png');
  }

  static Future<ui.Image?> _loadImg(String path) async {
    try {
      final bytes = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
      return await AssetStyle.softenAtLoad((await codec.getNextFrame()).image);
    } catch (e) {
      debugPrint('MineRenderer: $path yüklenemedi — $e');
      return null;
    }
  }

  static void draw(
    Canvas canvas,
    double px,
    double py, {
    required OreType type,
    double chopPhase = -1,
    int seed = 0,
  }) {
    const hw = kTileW / 2;
    const hh = kTileH / 2;

    // ── Darbe sarsıntısı (damlı harmonik — tree ile aynı formül) ──────────
    double shakeX = 0, shakeY = 0;
    if (chopPhase >= 0) {
      const cycleTime = 1.0 / 1.0; // madenci 1 darbe/sn
      final t  = (chopPhase / (2 * pi)) * cycleTime;
      final jolt = exp(-12 * t) * sin(45 * t);
      shakeX = jolt * 2.5;
      shakeY = -jolt.abs() * 1.5;
    }

    // ── Taş madeni: PNG asset ─────────────────────────────────────────────
    if (type == OreType.stone) {
      final img = _rocks[seed % 4];
      if (img != null) {
        canvas.save();
        canvas.translate(shakeX, shakeY);
        // Genişliği tile'ın %80'i ile sınırla, yüksekliği 2 tile ile sınırla
        const maxW = kTileW * 0.80;
        const maxH = kTileH * 2.0;
        final rawH = maxW * img.height / img.width;
        final drawH = rawH > maxH ? maxH : rawH;
        final drawW = rawH > maxH ? maxH * img.width / img.height : maxW;
        final dst = Rect.fromLTWH(
          px - drawW / 2,
          py + hh - drawH + hh * 0.4,
          drawW,
          drawH,
        );
        canvas.drawImageRect(
          img,
          Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
          dst,
          _pSprite,
        );
        canvas.restore();
      }
      return;
    }

    // ── Iron / Coal: PNG asset ────────────────────────────────────────────
    final oreImg = type == OreType.iron ? _iron : type == OreType.coal ? _coal : null;
    if (oreImg != null) {
      canvas.save();
      canvas.translate(shakeX, shakeY);
      const maxW = kTileW * 0.80;
      const maxH = kTileH * 2.0;
      final rawH = maxW * oreImg.height / oreImg.width;
      final drawH = rawH > maxH ? maxH : rawH;
      final drawW = rawH > maxH ? maxH * oreImg.width / oreImg.height : maxW;
      final dst = Rect.fromLTWH(
        px - drawW / 2,
        py + hh - drawH + hh * 0.4,
        drawW,
        drawH,
      );
      canvas.drawImageRect(
        oreImg,
        Rect.fromLTWH(0, 0, oreImg.width.toDouble(), oreImg.height.toDouble()),
        dst,
        _pSprite,
      );
      canvas.restore();
      return;
    }

    canvas.save();
    canvas.translate(shakeX, shakeY);

    // ── Renk paleti (ore tipine göre) ─────────────────────────────────────
    final Color topCol, leftCol, rightCol, veinCol;
    switch (type) {
      case OreType.stone:
        topCol   = const Color(0xFF9E9C9A);
        leftCol  = const Color(0xFF6A6866);
        rightCol = const Color(0xFF7E7C7A);
        veinCol  = const Color(0xFF555352);
      case OreType.iron:
        topCol   = const Color(0xFFB08060);
        leftCol  = const Color(0xFF7A5038);
        rightCol = const Color(0xFF9A7050);
        veinCol  = const Color(0xFFDD8844);
      case OreType.coal:
        topCol   = const Color(0xFF484644);
        leftCol  = const Color(0xFF282624);
        rightCol = const Color(0xFF383634);
        veinCol  = const Color(0xFF1A1816);
    }

    // ── Kaya bloğu yüksekliği (tile yüksekliğinin %65'i) ──────────────────
    const bh = hh * 1.3; // blok yüksekliği (piksel)

    // Blok köşe noktaları (izometrik):
    // Üst yüz (top face) — tile'ın tam merkezi
    final topBack  = Offset(px,       py  - bh);
    final topLeft  = Offset(px - hw,  py  - bh + hh);
    final topRight = Offset(px + hw,  py  - bh + hh);
    final topFront = Offset(px,       py  - bh + hh * 2);

    // Alt yüz (sadece görünür kenarlar)
    final botLeft  = Offset(px - hw,  py  + hh);
    final botRight = Offset(px + hw,  py  + hh);
    final botFront = Offset(px,       py  + hh * 2);

    Paint fill(Color c) => Paint()..color = c..isAntiAlias = false;
    Paint stroke(Color c) => Paint()
      ..color = c..style = PaintingStyle.stroke
      ..strokeWidth = 1..isAntiAlias = false;

    // Sol yüz
    final leftFace = Path()
      ..moveTo(topBack.dx,  topBack.dy)
      ..lineTo(topLeft.dx,  topLeft.dy)
      ..lineTo(botLeft.dx,  botLeft.dy)
      ..lineTo(px,          py)
      ..close();
    canvas.drawPath(leftFace, fill(leftCol));
    canvas.drawPath(leftFace, stroke(const Color(0xFF1A1A1A)));

    // Sağ yüz
    final rightFace = Path()
      ..moveTo(topBack.dx,  topBack.dy)
      ..lineTo(topRight.dx, topRight.dy)
      ..lineTo(botRight.dx, botRight.dy)
      ..lineTo(px,          py)
      ..close();
    canvas.drawPath(rightFace, fill(rightCol));
    canvas.drawPath(rightFace, stroke(const Color(0xFF1A1A1A)));

    // Ön yüz (sol-alt)
    final frontFace = Path()
      ..moveTo(topLeft.dx,  topLeft.dy)
      ..lineTo(topFront.dx, topFront.dy)
      ..lineTo(botFront.dx, botFront.dy)
      ..lineTo(botLeft.dx,  botLeft.dy)
      ..close();
    canvas.drawPath(frontFace, fill(leftCol));

    // Ön yüz (sağ-alt)
    final frontFaceR = Path()
      ..moveTo(topRight.dx, topRight.dy)
      ..lineTo(topFront.dx, topFront.dy)
      ..lineTo(botFront.dx, botFront.dy)
      ..lineTo(botRight.dx, botRight.dy)
      ..close();
    canvas.drawPath(frontFaceR, fill(rightCol));

    // Üst yüz
    final topFace = Path()
      ..moveTo(topBack.dx,  topBack.dy)
      ..lineTo(topRight.dx, topRight.dy)
      ..lineTo(topFront.dx, topFront.dy)
      ..lineTo(topLeft.dx,  topLeft.dy)
      ..close();
    canvas.drawPath(topFace, fill(topCol));
    canvas.drawPath(topFace, stroke(const Color(0xFF2A2A2A)));

    // ── Damar/maden işareti (üst yüzde) ───────────────────────────────────
    // Her düğümün seed'ine göre 2-3 rastgele damar çizgisi
    final veinPaint = Paint()
      ..color = veinCol..strokeWidth = 1.5..isAntiAlias = false;
    final rng = Random(seed);
    for (int i = 0; i < 3; i++) {
      final t1 = rng.nextDouble();
      final t2 = rng.nextDouble();
      // İzometrik top face üzerinde interpolasyon
      final x1 = topBack.dx + (topRight.dx - topBack.dx) * t1 * 0.8 + (topLeft.dx - topBack.dx) * t2 * 0.8;
      final y1 = topBack.dy + (topRight.dy - topBack.dy) * t1 * 0.8 + (topLeft.dy - topBack.dy) * t2 * 0.8;
      final x2 = x1 + (rng.nextDouble() - 0.5) * hw * 0.6;
      final y2 = y1 + (rng.nextDouble() - 0.5) * hh * 0.6;
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), veinPaint);
    }

    // ── İşaretli maden göstergesi ─────────────────────────────────────────
    canvas.restore();
  }

  // Selection overlay statik kaynakları
  static final _pSelFill   = Paint()
    ..color       = const Color(0x44888888)
    ..isAntiAlias = false;
  static final _pSelBorder = Paint()
    ..color       = const Color(0xCCBBBBBB)
    ..style       = PaintingStyle.stroke
    ..strokeWidth = 1.5
    ..isAntiAlias = false;
  static final Path _selDiamond = Path();

  /// Seçim önizleme overlay — tarla/lumber ile aynı mantık, gri ton
  static void drawSelectionTile(Canvas canvas, double px, double py, double hw, double hh) {
    _selDiamond
      ..reset()
      ..moveTo(px,      py)
      ..lineTo(px + hw, py + hh)
      ..lineTo(px,      py + hh * 2)
      ..lineTo(px - hw, py + hh)
      ..close();
    canvas.drawPath(_selDiamond, _pSelFill);
    canvas.drawPath(_selDiamond, _pSelBorder);
  }
}
