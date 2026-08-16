import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'asset_style.dart';

/// Saz yatağının prosedürel çizimi — örülü saz hasır + baş ucu yastık rulosu.
/// Sprite yok (mezar pattern'i gibi); izometrik oval hasır + dokuma şeritleri.
class ReedBedRenderer {
  static final List<ui.Image?> _sprites = [null, null];
  static final Paint _pSprite = AssetStyle.paint();
  static final Paint _spriteShadow = Paint()
    ..color = const Color(0x3D000000)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
  static final Paint _p = Paint()..isAntiAlias = true;
  static final Paint _stroke = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  static Future<void> loadAll() async {
    await Future.wait([
      _load(0, 'assets/nature/reed_bed_left.png'),
      _load(1, 'assets/nature/reed_bed_right.png'),
    ]);
  }

  static Future<void> _load(int variant, String path) async {
    try {
      final bytes = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      _sprites[variant] = await AssetStyle.softenAtLoad(frame.image);
    } catch (e) {
      debugPrint(
        'ReedBedRenderer: $path yüklenemedi — prosedürel fallback: $e',
      );
    }
  }

  static void draw(Canvas canvas, Offset c, {int seed = 0}) {
    final sprite = _sprites[seed.abs() % 2];
    if (sprite != null) {
      const width = 38.0;
      final height = width * sprite.height / sprite.width;
      // Sprite'ın alt kenarı zeminin temas noktasıdır. Merkezden çizmek,
      // perspektifli yatağın altını birkaç piksel yukarıda bırakıyordu.
      final baseY = c.dy + 5.0;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(c.dx, baseY - 1.0),
          width: width - 2.0,
          height: 6.0,
        ),
        _spriteShadow,
      );
      canvas.drawImageRect(
        sprite,
        Rect.fromLTWH(0, 0, sprite.width.toDouble(), sprite.height.toDouble()),
        Rect.fromLTWH(c.dx - width / 2, baseY - height, width, height),
        _pSprite,
      );
      return;
    }

    const w = 34.0; // hasır genişliği (px, ekran)
    const h = 18.0; // izometrik derinlik

    // Yumuşak taban gölgesi — yataktan biraz geniş, yere oturtur.
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0x33000000);
    canvas.drawOval(
      Rect.fromCenter(center: c.translate(1, 2), width: w + 6, height: h + 4),
      _p,
    );

    // Hasır gövdesi — sıcak saz beji.
    _p.color = const Color(0xFFC9B070);
    final mat = Rect.fromCenter(center: c, width: w, height: h);
    canvas.drawOval(mat, _p);

    // Kenar örgüsü — koyu hat.
    _stroke
      ..color = const Color(0xFF8E7642)
      ..strokeWidth = 2.0;
    canvas.drawOval(mat, _stroke);

    // Dokuma şeritleri — birkaç hafif eğri çizgi (örülü saz hissi).
    _stroke
      ..color = const Color(0x559C8448)
      ..strokeWidth = 1.0;
    for (int i = -2; i <= 2; i++) {
      final dy = i * (h / 6);
      final ww = w * sqrt(1 - (2 * dy / h) * (2 * dy / h)).clamp(0.0, 1.0);
      canvas.drawLine(
        Offset(c.dx - ww / 2 + 2, c.dy + dy),
        Offset(c.dx + ww / 2 - 2, c.dy + dy),
        _stroke,
      );
    }

    // Baş ucu yastık rulosu — bir uçta daha koyu saz demeti.
    final rnd = Random(seed);
    final headLeft = rnd.nextBool();
    final px = c.dx + (headLeft ? -w * 0.30 : w * 0.30);
    _p.color = const Color(0xFFB89A56);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(px, c.dy - 1),
        width: w * 0.34,
        height: h * 0.55,
      ),
      _p,
    );
    _stroke
      ..color = const Color(0xFF8E7642)
      ..strokeWidth = 1.2;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(px, c.dy - 1),
        width: w * 0.34,
        height: h * 0.55,
      ),
      _stroke,
    );
  }
}
