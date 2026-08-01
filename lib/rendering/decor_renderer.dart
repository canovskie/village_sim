import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../world/decor_entity.dart';
import 'asset_style.dart';
import 'wind.dart';

/// Çimen üstü dekor sprite'larını yükler ve çizer.
/// Her kind için 2-3 varyant; world generator önceden seçtiği variant'ı kullanırız.
class DecorRenderer {
  // kind → variant index → image
  static final Map<DecorKind, List<ui.Image?>> _imgs = {};

  static final Paint _pSprite = AssetStyle.paint();

  // Hacimli decor (log/stump/bush) için yumuşak yer gölgesi — "havada" hissini önler.
  static final Paint _pShadow = Paint()
    ..color = const Color(0x55000000)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.6);

  static Future<void> loadAll() async {
    await _loadKind(DecorKind.daisy,         'daisy_cluster',     3);
    await _loadKind(DecorKind.poppy,         'poppy_cluster',     3);
    await _loadKind(DecorKind.lavender,      'lavender_cluster',  3);
    await _loadKind(DecorKind.buttercup,     'buttercup_cluster', 3);
    await _loadKind(DecorKind.mushroomRed,   'mushroom_red',      2);
    await _loadKind(DecorKind.mushroomBrown, 'mushroom_brown',    2);
    await _loadKind(DecorKind.clover,        'clover_patch',      2);
    await _loadKind(DecorKind.bushSmall,     'bush_small',        3);
    await _loadKind(DecorKind.fallenLog,     'fallen_log',        2);
    await _loadKind(DecorKind.stump,         'stump',             2);
    await _loadKind(DecorKind.pebble,        'pebble_cluster',    3);
  }

  static Future<void> _loadKind(DecorKind kind, String base, int count) async {
    final list = <ui.Image?>[];
    for (int i = 0; i < count; i++) {
      list.add(await _load('assets/nature/${base}_$i.png'));
    }
    _imgs[kind] = list;
  }

  static Future<ui.Image?> _load(String path) async {
    try {
      final bytes = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      return await AssetStyle.softenAtLoad(frame.image);
    } catch (e) {
      debugPrint('DecorRenderer: $path yüklenemedi — $e');
      return null;
    }
  }

  /// Bitki türünün rüzgârda esneme genliği — düz/ağır objeler (yosun, çakıl,
  /// kütük, kütük) sallanmaz; çiçekler en çok, çalı/mantar daha az.
  static double _swayAmp(DecorKind k) {
    switch (k) {
      case DecorKind.daisy:
      case DecorKind.poppy:
      case DecorKind.lavender:
      case DecorKind.buttercup:
        return 0.055;
      case DecorKind.bushSmall:
        return 0.032;
      case DecorKind.mushroomRed:
      case DecorKind.mushroomBrown:
        return 0.018;
      case DecorKind.clover:
      case DecorKind.pebble:
      case DecorKind.fallenLog:
      case DecorKind.stump:
        return 0.0; // yere yatık / ağır → rüzgâr etkilemez
    }
  }

  /// Tile merkezinden çizim. [center] = gridToScreen(col+0.5, row+0.5).
  /// Kütük gibi geniş objeler için draw boyutu kind'a göre ayarlanır.
  /// [time] verilirse esnek bitkiler ortak rüzgâr alanıyla (Wind) sallanır.
  static void draw(Canvas canvas, Offset center, DecorEntity d, {double time = 0}) {
    final list = _imgs[d.kind];
    if (list == null || list.isEmpty) return;
    final variant = d.variant.clamp(0, list.length - 1);
    final img = list[variant];
    if (img == null) return;

    // Boyutlar: tile = 64×32 px iso. Decor çoğu < 1 tile.
    // baseOffset: sprite tabanının tile merkezinden ne kadar aşağıda olacağı
    //   (tile yarı yüksekliği 16 px → hacimli objelerde tile zeminine yakın oturur).
    // shadowW: 0 ise gölge yok (düz çiçek/yosun/çakıl için gerekmez).
    final double drawH;
    double baseOffset = 4.0;
    double shadowScale = 0.0;
    double shadowH = 0.0;
    switch (d.kind) {
      case DecorKind.fallenLog:
        drawH = 40.0; // yatay, yaklaşık 1 tile geniş
        baseOffset = 11.0;
        shadowScale = 0.82;
        shadowH = 8.0;
        break;
      case DecorKind.stump:
        drawH = 32.0;
        baseOffset = 9.0;
        shadowScale = 0.78;
        shadowH = 7.0;
        break;
      case DecorKind.bushSmall:
        drawH = 30.0;
        baseOffset = 8.0;
        shadowScale = 0.70;
        shadowH = 6.5;
        break;
      case DecorKind.mushroomRed:
      case DecorKind.mushroomBrown:
      case DecorKind.daisy:
      case DecorKind.poppy:
      case DecorKind.lavender:
      case DecorKind.buttercup:
        drawH = 20.0;
        break;
      case DecorKind.clover:
      case DecorKind.pebble:
        drawH = 16.0;
        break;
    }
    final drawW = drawH * img.width / img.height;

    final baseY = center.dy + baseOffset;

    // Önce yer gölgesi (sprite'ın hemen altında, hafif yukarı kayık elips).
    if (shadowScale > 0) {
      final shadowCenter = Offset(center.dx, baseY - 1.5);
      canvas.drawOval(
        Rect.fromCenter(
          center: shadowCenter,
          width: drawW * shadowScale,
          height: shadowH,
        ),
        _pShadow,
      );
    }

    final dst = Rect.fromLTWH(
      center.dx - drawW / 2,
      baseY - drawH,
      drawW,
      drawH,
    );
    final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());

    // Ezilme animasyonu — köylü basınca yere doğru yassılaşıp solar. Taban
    // (baseY) sabit; sprite dikeyde ezilir, yatayda hafif yayılır, alpha söner.
    // Sway kapatılır (ezilirken sallanma tuhaf durur).
    final crush = d.crushProgress;
    if (crush > 0) {
      final sink = 1.0 - 0.82 * crush;      // dikey ezilme (yere yatar)
      final spread = 1.0 + 0.22 * crush;    // yatay hafif yayılma
      canvas.saveLayer(
        null,
        Paint()..color = Color.fromARGB(((1.0 - crush) * 255).round(), 0, 0, 0),
      );
      canvas.translate(center.dx, baseY);
      canvas.scale(spread, sink);
      canvas.translate(-center.dx, -baseY);
      canvas.drawImageRect(img, src, dst, _pSprite);
      canvas.restore();
      return;
    }

    // Rüzgâr sallantısı — ortak rüzgâr alanı (ağaç/sazla aynı dalga). Taban
    // sabit (baseY), tepe sallanır; düz/ağır objelerde amp=0 → skew yok.
    final amp = _swayAmp(d.kind);
    if (amp > 0) {
      final sway = Wind.swayAt(d.col.toDouble(), d.row.toDouble(), time,
          amp: amp, jitter: (d.swaySeed * 1.618) % (2 * pi));
      canvas.save();
      canvas.translate(center.dx, baseY);
      canvas.skew(sway, 0);
      canvas.translate(-center.dx, -baseY);
      canvas.drawImageRect(img, src, dst, _pSprite);
      canvas.restore();
    } else {
      canvas.drawImageRect(img, src, dst, _pSprite);
    }
  }
}
