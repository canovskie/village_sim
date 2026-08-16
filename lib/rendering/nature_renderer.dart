import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'asset_style.dart';
import 'wind.dart';

class NatureRenderer {
  static ui.Image? _lotus0;
  static ui.Image? _lotus1;
  static ui.Image? _reeds;
  static final List<ui.Image?> _berryBushes = [null, null, null];

  static final Paint _pSprite = AssetStyle.paint();
  // Biçilmiş sazın anızı — kısa, soluk kesik saplar.
  static final Paint _pStubble = Paint()
    ..color = const Color(0xFF7E8A4E)
    ..strokeWidth = 1.6
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;

  static Future<void> loadAll() async {
    final loaded = await Future.wait([
      _load('assets/nature/lotus_0.png'),
      _load('assets/nature/lotus_1.png'),
      _load('assets/nature/reeds.png'),
      _load('assets/nature/berry_bush_0.png'),
      _load('assets/nature/berry_bush_1.png'),
      _load('assets/nature/berry_bush_2.png'),
    ]);
    _lotus0 = loaded[0];
    _lotus1 = loaded[1];
    _reeds = loaded[2];
    for (var i = 0; i < _berryBushes.length; i++) {
      _berryBushes[i] = loaded[i + 3];
    }
  }

  static Future<ui.Image?> _load(String path) async {
    try {
      final bytes = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      return await AssetStyle.softenAtLoad(frame.image);
    } catch (e) {
      debugPrint('NatureRenderer: $path yüklenemedi — $e');
      return null;
    }
  }

  // ── Lotus ────────────────────────────────────────────────────────────────────
  /// [center] = gridToScreen(col+0.5, row+0.5) — tile merkezi (güney noktası değil, orta)
  static void drawLotus(
    Canvas canvas,
    Offset center, {
    required int variant,
    double time = 0,
    int seed = 0,
  }) {
    final img = variant == 0 ? _lotus0 : _lotus1;
    if (img == null) return;

    // Hafif sallanma — suyun dalgasıyla senkron
    final bob = sin(time * 0.75 + seed * 0.9) * 1.8;

    // Tile genişliğine göre boyutlandır (2 tile genişliği ~= 64*2 px)
    const drawW = 40.0; // px
    final drawH = drawW * img.height / img.width;

    final dst = Rect.fromCenter(
      center: Offset(center.dx, center.dy + bob),
      width: drawW,
      height: drawH,
    );
    final src = Rect.fromLTWH(
      0,
      0,
      img.width.toDouble(),
      img.height.toDouble(),
    );

    canvas.drawImageRect(img, src, dst, _pSprite);
  }

  // ── Reeds ────────────────────────────────────────────────────────────────────
  /// [cx, cy] = ekran merkezi (iki tile ortası, üst nokta seviyesi).
  /// Sazlar yukarıya doğru uzanır; hafif rüzgar sallantısı uygulanır.
  static void drawReeds(
    Canvas canvas,
    double cx,
    double cy, {
    double time = 0,
    int seed = 0,
    double col = 0,
    double row = 0,
    double growth = 1.0, // 0 = yeni biçilmiş (anız), 1 = olgun
  }) {
    final img = _reeds;
    if (img == null) return;

    // Biçilmiş / yeni filiz — kısa anız sapları çiz, sprite yok.
    if (growth < 0.18) {
      final rnd = Random(seed);
      final n = 4 + rnd.nextInt(3);
      for (int i = 0; i < n; i++) {
        final dx = (rnd.nextDouble() - 0.5) * 26;
        final h = 4.0 + rnd.nextDouble() * 4.0;
        final lean = (rnd.nextDouble() - 0.5) * 3;
        canvas.drawLine(
          Offset(cx + dx, cy),
          Offset(cx + dx + lean, cy - h),
          _pStubble,
        );
      }
      return;
    }

    // Büyürken kısadan tam boya uzar (taban sabit).
    final drawH = 86.0 * (0.4 + 0.6 * growth.clamp(0.0, 1.0));
    final drawW = drawH * img.width / img.height;

    final dst = Rect.fromLTWH(cx - drawW / 2, cy - drawH, drawW, drawH);
    final src = Rect.fromLTWH(
      0,
      0,
      img.width.toDouble(),
      img.height.toDouble(),
    );

    // Rüzgar sallantısı — ortak rüzgâr alanı (ağaçlarla aynı dalga). Saz ince,
    // genliği biraz büyük; tabanı sabit, tepe sallanır.
    final sway = Wind.swayAt(col, row, time, amp: 0.045, jitter: seed * 1.7);

    canvas.save();
    // Skew pivot tabanda (cx, cy)
    canvas.translate(cx, cy);
    canvas.skew(sway, 0);
    canvas.translate(-cx, -cy);
    canvas.drawImageRect(img, src, dst, _pSprite);
    canvas.restore();
  }

  // ── Böğürtlen çalısı ────────────────────────────────────────────────────────

  static final Paint _pBerryFill = Paint()..isAntiAlias = true;
  static final Paint _pBerryShadow = Paint()
    ..color = const Color(0x33000000)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.8);

  /// Çalı gövdesi — olgunlukla koyulaşan yeşil yapraklar + kırmızı meyveler.
  ///
  /// Prosedürel (PNG yok): erken oyunun ilk üretim kaynağı olduğu için
  /// oyuncunun onu UZAKTAN tanıması gerekiyor — meyve varken belirgin kırmızı
  /// noktalar, toplandıktan sonra çıplak/soluk bir öbek. Yani şekil değil RENK
  /// okunur; 37px'te ayrıntı kaybolduğu için (bkz. char-shaded-system dersi)
  /// silüet yerine kontrasta yaslanıyor.
  ///
  /// [cx, cy] = tile merkezi ekran koordinatı, [ripeness] 0..1.
  static void drawBerryBush(
    Canvas canvas,
    double cx,
    double cy, {
    required double ripeness,
    int variant = 0,
    int seed = 0,
    double time = 0,
    double col = 0,
    double row = 0,
  }) {
    final rnd = Random(seed);
    final r = ripeness.clamp(0.0, 1.0);
    // Üç görsel evre: toplanmış (yalın), dolmakta (az meyve), olgun (bol
    // meyve). Eski daire çalının tersine silüet gerçek bir çalı gibi okunur;
    // ripeness yine oyun state'inden geldiği için save/load davranışı değişmez.
    final spriteIndex = r < 0.18
        ? 0
        : r < 0.70
        ? 1
        : 2;
    final sprite = _berryBushes[spriteIndex];
    if (sprite != null) {
      final src = switch (spriteIndex) {
        0 => const Rect.fromLTWH(120, 270, 1015, 680),
        1 => const Rect.fromLTWH(180, 340, 900, 600),
        _ => const Rect.fromLTWH(105, 215, 1050, 760),
      };
      final width = 29.0 + variant * 1.8;
      final height = width * src.height / src.width;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, cy - 1),
          width: width * 1.08,
          height: 5.5,
        ),
        _pBerryShadow,
      );
      final sway = Wind.swayAt(col, row, time, amp: 0.022, jitter: seed * 1.3);
      canvas.save();
      canvas.translate(cx, cy);
      canvas.skew(sway, 0);
      canvas.translate(-cx, -cy);
      canvas.drawImageRect(
        sprite,
        src,
        Rect.fromLTWH(cx - width / 2, cy - height, width, height),
        _pSprite,
      );
      canvas.restore();
      return;
    }

    // Asset yüklenemezse açılış/arayüzü bozmayan prosedürel geri dönüş.
    // Rüzgâr — ağaç/sazla aynı alan, genlik küçük (çalı alçak ve sıkı).
    final sway = Wind.swayAt(col, row, time, amp: 0.022, jitter: seed * 1.3);

    canvas.save();
    canvas.translate(cx, cy);
    canvas.skew(sway, 0);
    canvas.translate(-cx, -cy);

    // Gövde öbekleri — 3 daire, varyanta göre hafif farklı diziliş.
    // 20px taban: ilk capture'da 15'ti ve çalı mantar/dekorla aynı ağırlıkta
    // okunuyordu. Bu köyün ilk yiyecek kaynağı; kalabalık bir çayırda gözle
    // BULUNABİLİR olmak zorunda.
    final baseW = 20.0 + variant * 1.8;
    // Meyveliyken yapraklar daha koyu/dolgun; toplanınca soluklaşır.
    final leaf = Color.lerp(
      const Color(0xFF5C7A46),
      const Color(0xFF3F6234),
      r,
    )!;
    final leafHi = Color.lerp(
      const Color(0xFF74915B),
      const Color(0xFF547B45),
      r,
    )!;
    final lumps = <(double, double, double)>[
      (-baseW * 0.32, -4.0, baseW * 0.46),
      (baseW * 0.30, -3.0, baseW * 0.42),
      (0.0, -8.5, baseW * 0.50),
    ];
    // Taban gölgesi — çalıyı zemine oturtur (elips, karakter gölgesi diliyle).
    _pBerryFill.color = const Color(0x33000000);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy),
        width: baseW * 1.25,
        height: baseW * 0.42,
      ),
      _pBerryFill,
    );
    for (final (dx, dy, rad) in lumps) {
      _pBerryFill.color = leaf;
      canvas.drawCircle(Offset(cx + dx, cy + dy), rad, _pBerryFill);
      // Üst-sol highlight — shaded dil (ışık yukarıdan).
      _pBerryFill.color = leafHi;
      canvas.drawCircle(
        Offset(cx + dx - rad * 0.28, cy + dy - rad * 0.30),
        rad * 0.42,
        _pBerryFill,
      );
    }

    // MEYVE — yalnız olgunlaşırken belirir; sayısı ripeness ile artar, böylece
    // yeniden dolan çalı "yavaşça geri geliyor" diye okunur.
    final berries = (r * 7).round();
    for (int i = 0; i < berries; i++) {
      final bx = cx + (rnd.nextDouble() - 0.5) * baseW * 1.05;
      final by = cy - 2.0 - rnd.nextDouble() * 10.0;
      _pBerryFill.color = const Color(0xFF8E2740);
      canvas.drawCircle(Offset(bx, by), 2.4, _pBerryFill);
      _pBerryFill.color = const Color(0xFFC2415E);
      canvas.drawCircle(Offset(bx - 0.6, by - 0.6), 1.2, _pBerryFill);
    }
    canvas.restore();
  }
}
