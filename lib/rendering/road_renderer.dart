import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../world/road_surface.dart';
import 'asset_style.dart';

/// Asset tabanlı, bağlantı maskeli yol render'ı.
///
/// - PNG varyantları yalnızca malzeme dokusudur; 4-bit komşu maskesinden
///   üretilen dar yol silüetine kırpılır. Böylece yol tüm tile'ı kaplamaz.
/// - Ortadaki göbek ve N/E/S/W kollar UV uzayında kurulur; komşu tile'ların
///   ortak kenarında aynı genişlikle buluşur.
/// - Dokunun altında yüzeye özel koyu bir banket/gölge vardır. Bu hem zeminden
///   ayrımı güçlendirir hem de küçük asset dikişlerini gizler.
///
/// LOD:
///   zoom < 0.5   → sadece base diamond fill (uzaktan görsel fark yok)
///   zoom >= 0.5  → doku + edge rim
///
/// [px, py] tile'ın top corner'ı; tile dikey merkezi (px, py + hh).
/// Aynı konvansiyon TileRenderer ile birebir aynı.
class RoadRenderer {
  // ── Paletler ───────────────────────────────────────────────────────────
  // Toprak — sıcak kahve, ekseriyetle açıktan koyuya gradyan içinde
  static const _dirtBase = Color(0xFF7A5235);
  static const _dirtDark = Color(0xFF5A3B22);
  static const _dirtLight = Color(0xFF8E6845);
  static const _dirtPebble = Color(0xFF3C2A18);

  // Taş — soğuk gri, blok hissi için açık üst / koyu alt kontrastı
  static const _stoneBase = Color(0xFF8E8780);
  static const _stoneDark = Color(0xFF5C564F);
  static const _stoneLight = Color(0xFFB5AFA6);
  static const _stoneMortar = Color(0xFF4A453E);

  // Tahta — sıcak ten, planks koyu çizgiyle ayrılır
  static const _woodBase = Color(0xFF9D7B4C);
  static const _woodDark = Color(0xFF6B4E2A);
  static const _woodLight = Color(0xFFB89466);
  static const _woodPlank = Color(0xFF402A15);

  // Pre-built paint havuzları — tile başına alloc yok
  static final Map<RoadSurface, Paint> _basePaints = {
    RoadSurface.dirt: Paint()
      ..color = _dirtBase
      ..isAntiAlias = false,
    RoadSurface.stone: Paint()
      ..color = _stoneBase
      ..isAntiAlias = false,
    RoadSurface.woodBridge: Paint()
      ..color = _woodBase
      ..isAntiAlias = false,
  };
  static final _pDirtDark = Paint()
    ..color = _dirtDark
    ..isAntiAlias = false;
  static final _pDirtLight = Paint()
    ..color = _dirtLight
    ..isAntiAlias = false;
  static final _pDirtPebble = Paint()
    ..color = _dirtPebble
    ..isAntiAlias = false;
  static final _pStoneDark = Paint()
    ..color = _stoneDark
    ..isAntiAlias = false;
  static final _pStoneLight = Paint()
    ..color = _stoneLight
    ..isAntiAlias = false;
  static final _pStoneMortar = Paint()
    ..color = _stoneMortar
    ..isAntiAlias = false;
  static final _pWoodDark = Paint()
    ..color = _woodDark
    ..isAntiAlias = false;
  static final _pWoodLight = Paint()
    ..color = _woodLight
    ..isAntiAlias = false;
  static final _pWoodPlank = Paint()
    ..color = _woodPlank
    ..isAntiAlias = false;

  // Reusable paths — tile başına Path allocation yok.
  static final Path _roadShape = Path();
  static final Path _roadBorderShape = Path();
  static final Paint _borderPaint = Paint()..isAntiAlias = true;

  static const Map<RoadSurface, Color> _borderColors = {
    RoadSurface.dirt: Color(0xA04B321E),
    RoadSurface.stone: Color(0xB83F3B36),
    RoadSurface.woodBridge: Color(0xCC3B2818),
  };

  // ── PNG asset varyantları (yüzey başına 4) ────────────────────────────────
  // loadAll() ile cache'lenir. Tile hash'inden deterministik varyant seçilir
  // → komşu tile'lar benzer ama özdeş olmayan görünür (uniform "halı" yok).
  // Yüklenmeden önce procedural base fill fallback'i çizilir.
  static final Map<RoadSurface, List<ui.Image?>> _variants = {
    RoadSurface.dirt: List<ui.Image?>.filled(4, null),
    RoadSurface.stone: List<ui.Image?>.filled(4, null),
    RoadSurface.woodBridge: List<ui.Image?>.filled(4, null),
  };

  // Asset blit için varsayılan paint (AssetStyle ile yumuşatılmış).
  static final Paint _assetPaint = AssetStyle.paint();

  static Future<void> loadAll() async {
    await Future.wait([
      for (final s in RoadSurface.values)
        for (int i = 0; i < 4; i++) _loadVariant(s, i),
    ]);
  }

  static Future<void> _loadVariant(RoadSurface s, int idx) async {
    final prefix = switch (s) {
      RoadSurface.dirt => 'road_dirt',
      RoadSurface.stone => 'road_stone',
      RoadSurface.woodBridge => 'road_wood',
    };
    final path = 'assets/tiles/${prefix}_$idx.png';
    try {
      final bytes = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      _variants[s]![idx] = await AssetStyle.softenAtLoad(frame.image);
    } catch (e) {
      debugPrint('RoadRenderer: $path yüklenemedi — $e');
    }
  }

  /// Hash'ten varyant seç. Seçilen yüklü değilse sıradakine bak; hiçbiri
  /// yüklü değilse null → caller procedural fallback'e düşer.
  static ui.Image? _pickVariant(RoadSurface s, int hash) {
    final list = _variants[s]!;
    final start = (hash >> 6) & 0x3;
    for (int i = 0; i < 4; i++) {
      final img = list[(start + i) & 0x3];
      if (img != null) return img;
    }
    return null;
  }

  /// Yerleştirilmiş yol tile çizer.
  /// [mask] = 4-bit komşu (RoadSystem.neighborMask): 1=N, 2=E, 4=S, 8=W.
  /// [hash] = deterministik noise tohumu (RoadTile.hash).
  /// [opacity] = in-progress preview için < 1.0.
  ///
  /// Render katmanları:
  ///  1. Maskeden üretilen koyu dış banket/gölge
  ///  2. PNG varyant — dar iç yol şekline clip edilir
  ///  3. Asset yoksa aynı şekil içinde prosedürel fallback
  static void drawRoadTile(
    Canvas canvas,
    double px,
    double py,
    double hw,
    double hh,
    RoadSurface surface,
    int mask,
    int hash, {
    double zoom = 1.0,
    double opacity = 1.0,
  }) {
    final width = switch (surface) {
      RoadSurface.dirt => 0.50,
      RoadSurface.stone => 0.54,
      RoadSurface.woodBridge => 0.62,
    };
    _buildRoadShape(_roadBorderShape, px, py, hw, hh, mask, width + 0.08);
    _buildRoadShape(_roadShape, px, py, hw, hh, mask, width);

    final borderColor = _borderColors[surface]!;
    _borderPaint.color = borderColor.withValues(alpha: borderColor.a * opacity);
    canvas.drawPath(_roadBorderShape, _borderPaint);

    final img = _pickVariant(surface, hash);

    if (img != null) {
      // Asset modu — PNG'yi bağlantılı yol şekline clip et.
      canvas.save();
      canvas.clipPath(_roadShape);
      final dst = Rect.fromLTWH(px - hw, py, hw * 2, hh * 2);
      final src = Rect.fromLTWH(
        0,
        0,
        img.width.toDouble(),
        img.height.toDouble(),
      );
      if (opacity < 1.0) {
        // colorFilter modulate ile RGBA'yı (1,1,1,opacity) ile çarp → renk
        // bozulmadan alpha düşer; preview yarı saydam.
        final p = Paint()
          ..isAntiAlias = false
          ..colorFilter = ColorFilter.mode(
            const Color(0xFFFFFFFF).withValues(alpha: opacity),
            BlendMode.modulate,
          );
        canvas.drawImageRect(img, src, dst, p);
      } else {
        canvas.drawImageRect(img, src, dst, _assetPaint);
      }
      canvas.restore();
    } else {
      // Fallback: procedural — asset yüklenene kadar geçici görünür
      if (opacity < 1.0) {
        final p = Paint()
          ..color = _basePaints[surface]!.color.withValues(alpha: opacity)
          ..isAntiAlias = false;
        canvas.drawPath(_roadShape, p);
      } else {
        canvas.drawPath(_roadShape, _basePaints[surface]!);
      }
      if (zoom >= 0.5 && opacity >= 1.0) {
        canvas.save();
        canvas.clipPath(_roadShape);
        switch (surface) {
          case RoadSurface.dirt:
            _drawDirt(canvas, px, py, hw, hh, hash);
          case RoadSurface.stone:
            _drawStone(canvas, px, py, hw, hh, hash);
          case RoadSurface.woodBridge:
            _drawWood(canvas, px, py, hw, hh, hash);
        }
        canvas.restore();
      }
    }
  }

  /// Tile UV karesindeki merkez göbek + bağlantı kollarını isometrik ekrana
  /// dönüştürür. UV köşeleri sırasıyla top/right/bottom/left diamond
  /// köşelerine karşılık gelir. Kollar ortak kenarı az miktar aşar; zoom ve
  /// sub-pixel yerleşiminde iki yol arasında saç teli boşluk kalmaz.
  static void _buildRoadShape(
    Path path,
    double px,
    double py,
    double hw,
    double hh,
    int mask,
    double width,
  ) {
    path.reset();
    final lo = (1.0 - width) / 2.0;
    final hi = 1.0 - lo;
    const bleed = 0.025;

    _addUvRect(path, px, py, hw, hh, lo, lo, hi, hi);
    if ((mask & 1) != 0) {
      _addUvRect(path, px, py, hw, hh, lo, -bleed, hi, 0.5);
    }
    if ((mask & 2) != 0) {
      _addUvRect(path, px, py, hw, hh, 0.5, lo, 1.0 + bleed, hi);
    }
    if ((mask & 4) != 0) {
      _addUvRect(path, px, py, hw, hh, lo, 0.5, hi, 1.0 + bleed);
    }
    if ((mask & 8) != 0) {
      _addUvRect(path, px, py, hw, hh, -bleed, lo, 0.5, hi);
    }
  }

  static void _addUvRect(
    Path path,
    double px,
    double py,
    double hw,
    double hh,
    double u0,
    double v0,
    double u1,
    double v1,
  ) {
    final x0 = px + (u0 - v0) * hw;
    final y0 = py + (u0 + v0) * hh;
    final x1 = px + (u1 - v0) * hw;
    final y1 = py + (u1 + v0) * hh;
    final x2 = px + (u1 - v1) * hw;
    final y2 = py + (u1 + v1) * hh;
    final x3 = px + (u0 - v1) * hw;
    final y3 = py + (u0 + v1) * hh;
    path
      ..moveTo(x0, y0)
      ..lineTo(x1, y1)
      ..lineTo(x2, y2)
      ..lineTo(x3, y3)
      ..close();
  }

  // ── Toprak: 3-4 küçük leke + 1 çakıl ─────────────────────────────────────
  static void _drawDirt(
    Canvas canvas,
    double px,
    double py,
    double hw,
    double hh,
    int hash,
  ) {
    final cx = px;
    final cy = py + hh;

    for (int i = 0; i < 5; i++) {
      final h = hash >> (i * 4);
      final ox = ((h & 0xFF) / 255.0 - 0.5) * hw * 0.95;
      final oy = (((h >> 8) & 0xFF) / 255.0 - 0.5) * hh * 0.95;
      final w = 2.0 + ((h >> 16) & 0x3);
      final paint = (h & 1) == 0 ? _pDirtDark : _pDirtLight;
      canvas.drawRect(
        Rect.fromLTWH(
          (cx + ox).roundToDouble(),
          (cy + oy).roundToDouble(),
          w,
          1,
        ),
        paint,
      );
    }
    final h2 = hash >> 24;
    canvas.drawRect(
      Rect.fromLTWH(
        (cx + ((h2 & 0xFF) / 255.0 - 0.5) * hw * 0.7).roundToDouble(),
        (cy + (((h2 >> 8) & 0xFF) / 255.0 - 0.5) * hh * 0.7).roundToDouble(),
        1,
        1,
      ),
      _pDirtPebble,
    );
  }

  // ── Taş: 2-3 küçük blok (koyu kenar + açık üst) + harç çizgisi ───────────
  static void _drawStone(
    Canvas canvas,
    double px,
    double py,
    double hw,
    double hh,
    int hash,
  ) {
    final cx = px;
    final cy = py + hh;

    for (int i = 0; i < 3; i++) {
      final h = hash >> (i * 5);
      final ox = ((h & 0xFF) / 255.0 - 0.5) * hw * 0.75;
      final oy = (((h >> 8) & 0xFF) / 255.0 - 0.5) * hh * 0.75;
      final w = 3.0 + ((h >> 16) & 0x3);
      final rx = (cx + ox).roundToDouble();
      final ry = (cy + oy).roundToDouble();
      // Koyu taban (2 px yükseklik) + üstte 1 px açık highlight → blok hissi
      canvas.drawRect(Rect.fromLTWH(rx, ry, w, 2), _pStoneDark);
      canvas.drawRect(Rect.fromLTWH(rx, ry, w, 1), _pStoneLight);
    }
    // Harç — kısa diagonal çizgi
    canvas.drawRect(
      Rect.fromLTWH((cx - 1).roundToDouble(), cy.roundToDouble() - 1, 3, 1),
      _pStoneMortar,
    );
  }

  // ── Tahta köprü: 3 plank çizgisi + 2 damar ───────────────────────────────
  static void _drawWood(
    Canvas canvas,
    double px,
    double py,
    double hw,
    double hh,
    int hash,
  ) {
    final cx = px;
    final cy = py + hh;

    // Diamond enine 3 yatay plank ayırıcı — tahta süreklilik hissi
    for (int i = -1; i <= 1; i++) {
      final y = (cy + i * 5).roundToDouble();
      canvas.drawRect(
        Rect.fromLTWH((cx - hw + 3).roundToDouble(), y, hw * 2 - 6, 1),
        _pWoodPlank,
      );
    }
    // 2 kısa damar/leke
    for (int i = 0; i < 2; i++) {
      final h = hash >> (i * 6);
      final ox = ((h & 0xFF) / 255.0 - 0.5) * hw * 0.7;
      final oy = (((h >> 8) & 0xFF) / 255.0 - 0.5) * hh * 0.5;
      final paint = (h & 2) == 0 ? _pWoodDark : _pWoodLight;
      canvas.drawRect(
        Rect.fromLTWH(
          (cx + ox).roundToDouble(),
          (cy + oy).roundToDouble(),
          3,
          1,
        ),
        paint,
      );
    }
  }
}
