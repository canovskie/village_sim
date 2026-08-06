import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants.dart';
import '../world/season.dart';
import '../world/tree_entity.dart';
import 'asset_style.dart';
import 'wind.dart';

class TreeRenderer {
  static final Map<TreeType, ui.Image> _cache = {};
  static final Map<Season, ui.Image> _seasonalPines = {};

  /// Yüklü çam sprite'ı — vahşi orman kütlesi (game_painter._drawWilderness)
  /// aynı görseli sık paketleyerek iç ormanı sınır ağaçlarıyla dikişsiz kaplar.
  static ui.Image? get pineImage => _cache[TreeType.pine];

  // Sprite paint AssetStyle'dan — soft texture
  static final Paint _pSprite = AssetStyle.paint();

  static Future<void> loadAll() async {
    final summer = await _loadImage('assets/trees/pine.png');
    if (summer != null) {
      _cache[TreeType.pine] = summer;
      _seasonalPines[Season.spring] = summer;
      _seasonalPines[Season.summer] = summer;
    }
    // Mevsim varyantları zaten yumuşak/anti-aliased üretilmiş sprite'lar;
    // açılışta ikinci bir blur-toImage pass'i yapma (save açılışını ağırlaştırır).
    final autumn = await _loadImage(
      'assets/trees/pine_autumn.png',
      soften: false,
    );
    if (autumn != null) _seasonalPines[Season.autumn] = autumn;
    final winter = await _loadImage(
      'assets/trees/pine_winter.png',
      soften: false,
    );
    if (winter != null) _seasonalPines[Season.winter] = winter;
  }

  static Future<ui.Image?> _loadImage(String path, {bool soften = true}) async {
    try {
      final bytes = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      return soften ? await AssetStyle.softenAtLoad(frame.image) : frame.image;
    } catch (e) {
      debugPrint('TreeRenderer: $path yüklenemedi — $e');
      return null;
    }
  }

  /// Sprite'ı tile merkezine çizer.
  ///
  /// [center]    = gridToScreen(col+0.5, row+0.5)
  /// [seed]      = ağaca özgü faz (col*17+row*31)
  /// [chopPhase] = −1: kesim yok.  0..2π: darbe anından bu yana geçen faz.
  ///               0 = darbe tam isabet — titreşim başlar, azalır, 2π'de söner.
  static void draw(
    Canvas canvas,
    TreeType type,
    Offset center, {
    double time = 0,
    int seed = 0,
    double chopPhase = -1,
    double growthScale = 1.0,
    double col = 0,
    double row = 0,
    Season season = Season.spring,
    double fellProgress = -1,
    int fallDirection = 1,
  }) {
    final img = _seasonalPines[season] ?? _cache[type];
    if (img == null) return;

    final spriteW = kTileW * 1.3 * growthScale;
    final spriteH = spriteW * img.height / img.width;
    final left = (center.dx - spriteW / 2).roundToDouble();
    // Fidan tabandan büyür — taban sabit, tepe yükselir
    final top = center.dy - spriteH;

    // ── Rüzgar sallantısı — ortak rüzgâr alanı (tarlada dalga gibi gezer) ──
    final amp = 0.028 + (seed % 5) * 0.004; // ağaçtan ağaca hafif genlik farkı
    final windSway = Wind.swayAt(
      col,
      row,
      time,
      amp: amp,
      jitter: (seed * 1.618) % (2 * pi),
    );

    // ── Darbe titreşimi (damlı harmonik) ──────────────────────────────────
    // chopPhase=0 → darbe isabet etti → ağaç sarsılır → sönümler → 2π'ye kadar durulur
    // Formül: e^(−λ·t) · sin(ω·t)   (t = darbe sonrası geçen süre, saniye cinsinden)
    //   λ = sönüm katsayısı (kaç saniyede durulduğunu belirler)
    //   ω = titreşim açısal frekansı (Hz * 2π)
    double impactSway = 0;
    if (chopPhase >= 0) {
      // chopPhase 0..2π = darbe sonrası bir döngü (1/1.1 ≈ 0.91 sn)
      const cycleTime = 1.0 / 1.1;
      final t =
          (chopPhase / (2 * pi)) *
          cycleTime; // saniye cinsinden darbe sonrası süre
      const lambda = 10.0; // sönüm: ~0.3 sn sonra <%5
      const omega = 40.0; // ~6.4 Hz titreşim
      impactSway = exp(-lambda * t) * sin(omega * t) * 0.14;
    }

    final sway = windSway + impactSway;
    final baseY = top + spriteH;

    // Devrilme: önce aksi yöne çok hafif yüklenir, sonra yerçekimiyle hızlanıp
    // taç yere değince minicik sekerek yatar. Ağaç artık saydamlaşmaz; final
    // kare birkaç an tutulur, ardından sahne onu kütük dibiyle değiştirir.
    final falling = fellProgress >= 0;

    final src = Rect.fromLTWH(
      0,
      0,
      img.width.toDouble(),
      img.height.toDouble(),
    );
    final dst = Rect.fromLTWH(left, top, spriteW, spriteH);

    canvas.save();
    canvas.translate(center.dx, baseY);
    if (falling) {
      final dir = fallDirection >= 0 ? 1.0 : -1.0;
      double angle;
      if (fellProgress < 0.14) {
        final anticipation = fellProgress / 0.14;
        angle = -dir * sin(anticipation * pi) * 0.045;
      } else {
        final u = ((fellProgress - 0.14) / 0.68).clamp(0.0, 1.0);
        final gravity = u * u * (3 - 2 * u);
        angle = dir * gravity * 1.535;
        if (fellProgress > 0.82) {
          final land = ((fellProgress - 0.82) / 0.18).clamp(0.0, 1.0);
          angle -= dir * sin(land * pi) * (1 - land) * 0.035;
        }
      }
      canvas.rotate(angle);
    } else {
      canvas.skew(sway, 0);
    }
    canvas.translate(-center.dx, -baseY);
    canvas.drawImageRect(img, src, dst, _pSprite);
    canvas.restore();
  }
}
