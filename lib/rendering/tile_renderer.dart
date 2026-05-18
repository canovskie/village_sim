import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'asset_style.dart';

class TileRenderer {
  static ui.Image? _grass;

  // ── Sprite tint varyantları (modulate) ─────────────────────────────────────
  // 8 ton paleti — açık warm sarımsı → doygun yeşil → kuru bej arası geniş
  // spread. Patch system ile komşu tile'lar benzer variant'a düşer → organik
  // renk lekeleri (uniform "halı" görüntüsü değil, çayır gibi).
  static final List<Paint> _imgVariants = [
    AssetStyle.apply(Paint()..colorFilter = const ColorFilter.mode(Color(0xFFFFFFFF), BlendMode.modulate)), // 0: parlak (base)
    AssetStyle.apply(Paint()..colorFilter = const ColorFilter.mode(Color(0xFFEAE5C0), BlendMode.modulate)), // 1: sun-bleached warm
    AssetStyle.apply(Paint()..colorFilter = const ColorFilter.mode(Color(0xFFD2E2B0), BlendMode.modulate)), // 2: açık yeşil
    AssetStyle.apply(Paint()..colorFilter = const ColorFilter.mode(Color(0xFFB8D094), BlendMode.modulate)), // 3: orta yeşil
    AssetStyle.apply(Paint()..colorFilter = const ColorFilter.mode(Color(0xFF98B874), BlendMode.modulate)), // 4: koyu doygun yeşil
    AssetStyle.apply(Paint()..colorFilter = const ColorFilter.mode(Color(0xFFB4BC88), BlendMode.modulate)), // 5: kuru yeşil
    AssetStyle.apply(Paint()..colorFilter = const ColorFilter.mode(Color(0xFFCAD8B8), BlendMode.modulate)), // 6: soft turkuaz-yeşil
    AssetStyle.apply(Paint()..colorFilter = const ColorFilter.mode(Color(0xFFD8C8A0), BlendMode.modulate)), // 7: kuru bej (toprak yakın)
  ];

  // ── Fallback (asset yüklenmediyse) renkli fill ────────────────────────────
  // Variant index'leri _imgVariants ile aynı sırada.
  static final List<Paint> _fillVariants = [
    Paint()..color = const Color(0xFF58B45E)..isAntiAlias = false, // 0
    Paint()..color = const Color(0xFF7AB050)..isAntiAlias = false, // 1
    Paint()..color = const Color(0xFF6CAA55)..isAntiAlias = false, // 2
    Paint()..color = const Color(0xFF509644)..isAntiAlias = false, // 3
    Paint()..color = const Color(0xFF3D7E36)..isAntiAlias = false, // 4
    Paint()..color = const Color(0xFF6A803E)..isAntiAlias = false, // 5
    Paint()..color = const Color(0xFF6FA470)..isAntiAlias = false, // 6
    Paint()..color = const Color(0xFF9A8B5C)..isAntiAlias = false, // 7
  ];

  // Tile kenar çizgisi — düşük alpha, "grid" hissini azaltır ama tile
  // sınırını hâlâ görünür tutar.
  static final _border = Paint()
    ..color       = const Color(0x22000000)
    ..style       = PaintingStyle.stroke
    ..strokeWidth = 1
    ..isAntiAlias = false;

  // Dekor paint havuzu — sabit renkler
  static final _pFlowerYellow = Paint()..color = const Color(0xFFEED854)..isAntiAlias = false;
  static final _pFlowerRed    = Paint()..color = const Color(0xFFE0432E)..isAntiAlias = false;
  static final _pFlowerWhite  = Paint()..color = const Color(0xFFEEEEEE)..isAntiAlias = false;
  static final _pFlowerPurple = Paint()..color = const Color(0xFFB870D8)..isAntiAlias = false;
  static final _pPebble       = Paint()..color = const Color(0xFFA0998A)..isAntiAlias = false;
  static final _pPebbleDark   = Paint()..color = const Color(0xFF807868)..isAntiAlias = false;
  static final _pTuftDark     = Paint()..color = const Color(0xFF386838)..isAntiAlias = false;
  static final _pBlade        = Paint()..color = const Color(0xFF82C268)..isAntiAlias = false;

  // Diamond Path havuzu — her tile için yeniden allocate edilmez.
  static final Path _diamond = Path();

  // Kum overlay — su komşu sayısına göre 3 yoğunluk
  static final List<Paint> _pSand = [
    Paint()..color = const Color(0x55E6D49A)..isAntiAlias = false, // 1 yan
    Paint()..color = const Color(0x88E6D49A)..isAntiAlias = false, // 2 yan
    Paint()..color = const Color(0xAAE6D49A)..isAntiAlias = false, // 3+ yan
  ];

  static Future<void> loadAll() async {
    _grass = await _load('assets/tiles/grass.png');
  }

  static Future<ui.Image?> _load(String path) async {
    try {
      final bytes = await rootBundle.load(path);
      final codec  = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
      final frame  = await codec.getNextFrame();
      return await AssetStyle.softenAtLoad(frame.image);
    } catch (e) {
      debugPrint('TileRenderer: $path yüklenemedi — $e');
      return null;
    }
  }

  /// Çim tile çizer. (col, row) → deterministik tint varyantı + dekor.
  static void drawGrassTile(Canvas canvas, double px, double py,
      double hw, double hh, int col, int row) {
    final img = _grass;

    _diamond
      ..reset()
      ..moveTo(px,      py)
      ..lineTo(px + hw, py + hh)
      ..lineTo(px,      py + hh * 2)
      ..lineTo(px - hw, py + hh)
      ..close();

    // ── Variant seçimi: patch (macro) + jitter (micro) hibrid ────────────
    // Macro hash: 4x4 tile bloklarında sabit → komşu tile'lar benzer
    // baseTone paylaşır → organik renk lekeleri (uniform halı değil).
    // Micro hash: tile-spesifik küçük varyasyon (±1 variant kaydır).
    final macro = ((col >> 2) * 7919) ^ ((row >> 2) * 2729);
    final micro = (col * 73856093) ^ (row * 19349663);
    final baseTone = (macro & 0x7FFFFFFF) % _imgVariants.length;
    // Mikro jitter: %60 ihtimalle aynı, %40 ihtimalle komşu variant
    final jitter = (micro >> 3) & 0xF;
    final variant = jitter < 10
        ? baseTone
        : ((baseTone + (jitter < 13 ? 1 : -1)) % _imgVariants.length + _imgVariants.length) % _imgVariants.length;
    final hash = micro; // decor için aşağıda kullanılır

    if (img == null) {
      canvas.drawPath(_diamond, _fillVariants[variant]);
    } else {
      canvas.save();
      canvas.clipPath(_diamond);
      final dst = Rect.fromLTWH(px - hw, py, hw * 2, hh * 2);
      final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
      canvas.drawImageRect(img, src, dst, _imgVariants[variant]);
      canvas.restore();
    }

    canvas.drawPath(_diamond, _border);

    // ~%24 tile'da dekor (çiçek / çakıl / ot tutamı / ot bıçağı)
    final decorRoll = ((hash >> 5) & 0xFFFF) % 100;
    if (decorRoll < 24) {
      _drawDecor(canvas, px, py, hw, hh, hash);
    }
  }

  /// Çim tile'ın üzerine kum tonlamalı diamond overlay. [sides] = su komşu sayısı.
  /// _diamond hâlâ son drawGrassTile çağrısının köşeleriyle dolu — yine de
  /// güvenlik için yeniden inşa edilir.
  static void drawSandOverlay(Canvas canvas, double px, double py,
      double hw, double hh, int sides) {
    if (sides <= 0) return;
    _diamond
      ..reset()
      ..moveTo(px,      py)
      ..lineTo(px + hw, py + hh)
      ..lineTo(px,      py + hh * 2)
      ..lineTo(px - hw, py + hh)
      ..close();
    final idx = sides >= 3 ? 2 : sides - 1;
    canvas.drawPath(_diamond, _pSand[idx]);
  }

  // Tile içine küçük dekor — çiçek, çakıl, ot tutamı.
  // (px, py) tile top corner; tile vertical center = py + hh.
  static void _drawDecor(Canvas canvas, double px, double py,
      double hw, double hh, int hash) {
    final kind = (hash >> 8) & 0x7;
    // Tile içinde dağılım — kenarlara çok yaklaşma
    final ox = (((hash >> 16) & 0xFF) / 255.0 - 0.5) * hw * 0.6;
    final oy = (((hash >> 24) & 0xFF) / 255.0 - 0.5) * hh * 0.6;
    final cx = (px + ox).roundToDouble();
    final cy = (py + hh + oy).roundToDouble();

    switch (kind) {
      case 0:
      case 1:
        // Çiçek + sap
        final petal = switch ((hash >> 12) & 0x3) {
          0 => _pFlowerYellow,
          1 => _pFlowerRed,
          2 => _pFlowerWhite,
          _ => _pFlowerPurple,
        };
        canvas.drawRect(Rect.fromLTWH(cx,     cy + 1, 1, 2), _pTuftDark);
        canvas.drawRect(Rect.fromLTWH(cx - 1, cy,     3, 1), petal);
        canvas.drawRect(Rect.fromLTWH(cx,     cy - 1, 1, 1), petal);
      case 2:
      case 3:
        // Çakıl — 1-2 küçük taş
        canvas.drawRect(Rect.fromLTWH(cx,     cy,     2, 1), _pPebble);
        canvas.drawRect(Rect.fromLTWH(cx + 2, cy,     1, 1), _pPebbleDark);
      case 4:
      case 5:
        // Koyu ot tutamı
        canvas.drawRect(Rect.fromLTWH(cx,     cy,     1, 2), _pTuftDark);
        canvas.drawRect(Rect.fromLTWH(cx + 1, cy + 1, 1, 1), _pTuftDark);
        canvas.drawRect(Rect.fromLTWH(cx + 2, cy,     1, 2), _pTuftDark);
      default:
        // Açık ot bıçağı
        canvas.drawRect(Rect.fromLTWH(cx,     cy,     1, 1), _pBlade);
        canvas.drawRect(Rect.fromLTWH(cx - 1, cy + 1, 1, 1), _pBlade);
        canvas.drawRect(Rect.fromLTWH(cx + 1, cy + 1, 1, 1), _pBlade);
    }
  }
}
