import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../world/grave.dart';
import 'asset_style.dart';

/// Prosedürel mezar çizimi — toprak höyük + baş taşı (3 varyant) + yumuşak
/// gölge + küçük bir anma çiçeği. Sprite gerektirmez; cozy/sakin bir mezarlık
/// hissi verir. Painter her mezar için tile merkezinden çağırır.
class GraveRenderer {
  static final List<ui.Image?> _sprites = [null, null, null];
  static final Paint _pSprite = AssetStyle.paint();

  static final Paint _fill = Paint()..isAntiAlias = true;
  static final Paint _shadow = Paint()
    ..color = const Color(0x4D000000)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2);

  static const _stone = Color(0xFFB8B2A6); // şahide taşı
  static const _stoneDark = Color(0xFF8C8678); // taş gölge/kenar
  static const _soil = Color(0xFF5E4A34); // toprak höyük
  static const _soilDark = Color(0xFF4A3826);
  static const _grass = Color(0xFF6E8A4A); // höyük üstü ot
  static const _flower = Color(0xFFE8DCC0); // anma çiçeği

  static Future<void> loadAll() async {
    const paths = [
      'assets/nature/grave_round.png',
      'assets/nature/grave_cross.png',
      'assets/nature/grave_slab.png',
    ];
    await Future.wait([
      _load(0, paths[0]),
      _load(1, paths[1]),
      _load(2, paths[2]),
    ]);
  }

  static Future<void> _load(int variant, String path) async {
    try {
      final bytes = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      _sprites[variant] = await AssetStyle.softenAtLoad(frame.image);
    } catch (e) {
      debugPrint('GraveRenderer: $path yüklenemedi — prosedürel fallback: $e');
    }
  }

  /// [center] = tile merkezinin ekran konumu (gridToScreen).
  static void draw(Canvas canvas, Offset center, Grave g) {
    final sprite = _sprites[g.variant.clamp(0, 2)];
    if (sprite != null) {
      const width = 30.0;
      final height = width * sprite.height / sprite.width;
      final baseY = center.dy + 5;
      canvas.drawImageRect(
        sprite,
        Rect.fromLTWH(0, 0, sprite.width.toDouble(), sprite.height.toDouble()),
        Rect.fromLTWH(center.dx - width / 2, baseY - height, width, height),
        _pSprite,
      );
      return;
    }

    // Tile 64×32 iso → mezar yaklaşık yarım tile.
    const s = 1.0; // ölçek sabiti (zoom painter transform'unda)
    final baseY = center.dy + 4 * s;

    // 1) Yer gölgesi
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, baseY - 1 * s),
        width: 22 * s,
        height: 8 * s,
      ),
      _shadow,
    );

    // 2) Toprak höyük (iso oval + koyu alt kenar)
    _fill.color = _soilDark;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, baseY + 0.5 * s),
        width: 20 * s,
        height: 9 * s,
      ),
      _fill,
    );
    _fill.color = _soil;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, baseY - 0.5 * s),
        width: 19 * s,
        height: 8 * s,
      ),
      _fill,
    );
    // höyük üstü ince ot
    _fill.color = _grass;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, baseY - 1.5 * s),
        width: 14 * s,
        height: 5 * s,
      ),
      _fill,
    );

    // 3) Baş taşı (höyüğün arka-üst kenarında)
    final hx = center.dx;
    final hy = baseY - 5 * s; // taş tabanı (höyük arkası)
    switch (g.variant) {
      case 1:
        _drawCross(canvas, hx, hy, s);
        break;
      case 2:
        _drawSlab(canvas, hx, hy, s, small: true);
        break;
      default:
        _drawRoundStone(canvas, hx, hy, s);
    }

    // 4) Küçük anma çiçeği (höyük önünde)
    _fill.color = _flower;
    canvas.drawCircle(
      Offset(center.dx + 5 * s, baseY - 0.5 * s),
      1.6 * s,
      _fill,
    );
    _fill.color = const Color(0xFF6E8A4A);
    canvas.drawCircle(
      Offset(center.dx + 5 * s, baseY + 1.0 * s),
      1.0 * s,
      _fill,
    );
  }

  /// Yuvarlak tepeli klasik şahide.
  static void _drawRoundStone(
    Canvas canvas,
    double cx,
    double baseY,
    double s,
  ) {
    final w = 10.0 * s, h = 14.0 * s;
    final rect = Rect.fromLTWH(cx - w / 2, baseY - h, w, h);
    _fill.color = _stoneDark;
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        rect.translate(0.6 * s, 0),
        topLeft: Radius.circular(w / 2),
        topRight: Radius.circular(w / 2),
      ),
      _fill,
    );
    _fill.color = _stone;
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        rect,
        topLeft: Radius.circular(w / 2),
        topRight: Radius.circular(w / 2),
      ),
      _fill,
    );
    // küçük oyma çizgi
    _fill.color = _stoneDark;
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(cx, baseY - h * 0.5),
        width: 4 * s,
        height: 0.9 * s,
      ),
      _fill,
    );
  }

  /// Haç biçimli mezar taşı.
  static void _drawCross(Canvas canvas, double cx, double baseY, double s) {
    final h = 16.0 * s;
    _fill.color = _stoneDark;
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(cx + 0.6 * s, baseY - h / 2),
        width: 3 * s,
        height: h,
      ),
      _fill,
    );
    _fill.color = _stone;
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(cx, baseY - h / 2),
        width: 2.6 * s,
        height: h,
      ),
      _fill,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(cx, baseY - h * 0.72),
        width: 9 * s,
        height: 2.6 * s,
      ),
      _fill,
    );
  }

  /// Düz dikdörtgen levha (küçük/sade).
  static void _drawSlab(
    Canvas canvas,
    double cx,
    double baseY,
    double s, {
    bool small = false,
  }) {
    final w = (small ? 8.0 : 10.0) * s;
    final h = (small ? 10.0 : 13.0) * s;
    final rect = Rect.fromLTWH(cx - w / 2, baseY - h, w, h);
    _fill.color = _stoneDark;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.translate(0.6 * s, 0),
        Radius.circular(1.5 * s),
      ),
      _fill,
    );
    _fill.color = _stone;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(1.5 * s)),
      _fill,
    );
  }
}
