import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Adayı çevreleyen deniz + üstte atmosferik gökyüzü şeridi — ekranı dolduran,
/// zaman-duyarlı backdrop. Üst ~%20 GÖKYÜZÜ (zenit→ufuk gradyanı + güneş/ay
/// diski + süzülen yumuşak bulutlar), altında DENİZ; ikisi yumuşak ufuk
/// hazesiyle birleşir (sert çizgi yok). Tamamen EKRAN-UZAYINDA çizilir
/// (zoom/camera bağımsız uçsuz backdrop); ada elması denizin üstüne oturur,
/// kıyı şeridi ikisini birleştirir.
///
/// Tasarım hedefi "resimsel/suluboya": sert kenar/blok yok; her şey gradyan
/// stop'larıyla yumuşatılır, MaskFilter.blur kullanılmaz (CPU ucuz kalsın —
/// bulutlar bile blur yerine çok-katmanlı radyal puff ile yumuşar). Paylaşımlı
/// statik Paint; gece/gündüz tonu skyMid + dayLight + sun/moon'dan akar.
class OceanRenderer {
  static final Paint _p = Paint()..isAntiAlias = true;

  static Color _scale(Color c, double f) => Color.fromARGB(
    255,
    (c.r * 255 * f).round().clamp(0, 255),
    (c.g * 255 * f).round().clamp(0, 255),
    (c.b * 255 * f).round().clamp(0, 255),
  );

  static void draw(
    Canvas canvas,
    Size size, {
    double time = 0,
    double dayLight = 1.0,
    Color skyMid = const Color(0xFFA0C0E0),
    Color sunColor = const Color(0xFFFFF1C0),
    double sunOpacity = 0.0,
    double moonOpacity = 0.0,
    double timeOfDay = 0.5,
    bool reducedEffects = false,
  }) {
    final w = size.width, h = size.height;
    // Tam-gün → gece parlaklık katsayısı; tüm katmanlar bununla karartılır.
    final lit = 0.28 + dayLight * 0.72;
    // Ufuk yüksekliği — görünür "deniz yüzeyi başlangıcı". Gökyüzü üstte kalır.
    final horizonY = h * 0.22;

    // Katman sırası: deniz (taban) → sky şeridi (üste feather) → ufuk hazesi →
    // gök cismi diski → bulutlar (diskin önünden geçer) → denize yansıma.
    _sea(canvas, w, h, lit, skyMid);
    if (!reducedEffects) _seaBands(canvas, w, h, time, lit);
    _sky(canvas, w, horizonY, lit, skyMid, sunColor);
    _horizonHaze(canvas, w, horizonY, lit, sunColor);
    _celestialDisc(
      canvas,
      size,
      horizonY,
      timeOfDay,
      sunColor,
      sunOpacity,
      moonOpacity,
    );
    if (!reducedEffects) {
      _clouds(canvas, w, horizonY, time, dayLight, sunColor);
      _reflection(
        canvas,
        size,
        horizonY,
        time,
        timeOfDay,
        sunColor,
        sunOpacity,
        moonOpacity,
      );
    }
  }

  // ── Deniz tabanı ───────────────────────────────────────────────────────────
  // 3-stop dikey gradyan: ufukta açık/hazeli → doygun teal orta → derin lacivert
  // dip. Orta stop'taki canlı teal "grimsi yıkama" hissini keser. Tam ekranı
  // kaplar; üstteki gökyüzü şeridi bunun üstüne feather eder.
  static void _sea(Canvas c, double w, double h, double lit, Color skyMid) {
    final seaTop = _scale(
      Color.lerp(const Color(0xFF4E93B4), skyMid, 0.24)!,
      lit,
    );
    final seaMid = _scale(const Color(0xFF2C739A), lit); // doygun teal-mavi
    final seaBot = _scale(const Color(0xFF143A57), lit * 0.9);
    _p.shader = ui.Gradient.linear(
      Offset(w / 2, 0),
      Offset(w / 2, h),
      [seaTop, seaMid, seaBot],
      const [0.0, 0.45, 1.0],
    );
    c.drawRect(Rect.fromLTWH(0, 0, w, h), _p);
    _p.shader = null;
  }

  // ── Suluboya yıkama bantları (deniz akışı) ─────────────────────────────────
  // Yumuşak açık-teal yatay bantlar; yavaş süzülür, denize derinlik verir.
  static void _seaBands(Canvas c, double w, double h, double time, double lit) {
    for (int i = 0; i < 3; i++) {
      final cy = h * (0.34 + i * 0.24) + sin(time * 0.05 + i * 2.1) * h * 0.04;
      final band = h * (0.13 + i * 0.03);
      final a = ((10 + i * 4) * lit).round().clamp(0, 255);
      _p.shader = ui.Gradient.linear(
        Offset(0, cy - band),
        Offset(0, cy + band),
        [
          const Color(0x00000000),
          Color.fromARGB(a, 188, 224, 230),
          const Color(0x00000000),
        ],
        const [0.0, 0.5, 1.0],
      );
      c.drawRect(Rect.fromLTWH(0, cy - band, w, band * 2), _p);
      _p.shader = null;
    }
  }

  // ── Gökyüzü şeridi (üst) ───────────────────────────────────────────────────
  // Zenit (koyu/doygun) → ufuk hazesi (açık, güneşe doğru ılık) → şeffaf:
  // alt kenar alpha 0'a düşer → denize feather eder, sert ufuk çizgisi olmaz.
  static void _sky(
    Canvas c,
    double w,
    double horizonY,
    double lit,
    Color skyMid,
    Color sunColor,
  ) {
    final skyBottom = horizonY * 1.7;
    // Zenit belirgin mavi (washed-out olmasın), ufuk ılık-açık ama beyaza tam
    // dönmesin → gökyüzü "renkli" kalır.
    final zenith = _scale(
      Color.lerp(skyMid, const Color(0xFF3360A0), 0.62)!,
      lit * 1.02,
    );
    final hazeBase = Color.lerp(skyMid, Colors.white, 0.26)!;
    final haze = _scale(Color.lerp(hazeBase, sunColor, 0.20)!, lit * 1.06);
    _p.shader = ui.Gradient.linear(
      Offset(w / 2, 0),
      Offset(w / 2, skyBottom),
      [zenith, haze, haze.withValues(alpha: 0.0)],
      const [0.0, 0.72, 1.0],
    );
    c.drawRect(Rect.fromLTWH(0, 0, w, skyBottom), _p);
    _p.shader = null;
  }

  // ── Ufuk hazesi ────────────────────────────────────────────────────────────
  // Ufuk hizasında ince luminous bant (additive) → atmosferik parlama, sky↔sea
  // birleşim noktasını kaynatır.
  static void _horizonHaze(
    Canvas c,
    double w,
    double horizonY,
    double lit,
    Color sunColor,
  ) {
    final hy = horizonY * 1.12;
    final band = horizonY * 0.55;
    final glow = Color.lerp(Colors.white, sunColor, 0.5)!;
    final a = (0.18 * lit).clamp(0.0, 0.24);
    _p.blendMode = BlendMode.plus;
    _p.shader = ui.Gradient.linear(
      Offset(0, hy - band),
      Offset(0, hy + band),
      [
        glow.withValues(alpha: 0.0),
        glow.withValues(alpha: a),
        glow.withValues(alpha: 0.0),
      ],
      const [0.0, 0.5, 1.0],
    );
    c.drawRect(Rect.fromLTWH(0, hy - band, w, band * 2), _p);
    _p.shader = null;
    _p.blendMode = BlendMode.srcOver;
  }

  // ── Güneş / ay diski (gökte) ───────────────────────────────────────────────
  // Konum gökyüzü arkından (timeOfDay) türetilir: doğu→batı yatay + öğlen tepe
  // yükseklik. Yumuşak hâle (additive) + parlak çekirdek disk.
  static void _celestialDisc(
    Canvas c,
    Size size,
    double horizonY,
    double timeOfDay,
    Color sunColor,
    double sunOpacity,
    double moonOpacity,
  ) {
    final w = size.width;

    void disc(double norm, Color core, Color glow, double op, double r) {
      if (op <= 0.01) return;
      final cx = w / 2 + w * 0.40 * cos(pi * norm);
      final elev = sin(pi * norm).clamp(0.0, 1.0); // 0 ufuk, 1 tepe
      final cy = horizonY * 1.02 - elev * horizonY * 0.72; // sky şeridi içinde
      // Hâle — gökyüzünü yıkamayacak ölçüde ölçülü (radius/alpha kısık).
      _p.blendMode = BlendMode.plus;
      _p.shader = ui.Gradient.radial(
        Offset(cx, cy),
        r * 3.6,
        [glow.withValues(alpha: 0.30 * op), glow.withValues(alpha: 0.0)],
        const [0.0, 1.0],
      );
      c.drawCircle(Offset(cx, cy), r * 3.6, _p);
      _p.shader = null;
      _p.blendMode = BlendMode.srcOver;
      // Çekirdek disk
      _p.shader = ui.Gradient.radial(
        Offset(cx, cy),
        r,
        [
          core.withValues(alpha: op),
          core.withValues(alpha: 0.9 * op),
          glow.withValues(alpha: 0.0),
        ],
        const [0.0, 0.74, 1.0],
      );
      c.drawCircle(Offset(cx, cy), r, _p);
      _p.shader = null;
    }

    if (sunOpacity > 0.01) {
      final norm = ((timeOfDay - 0.25) / 0.50).clamp(0.0, 1.0);
      disc(norm, _scale(sunColor, 1.05), sunColor, sunOpacity, 26);
    }
    if (moonOpacity > 0.01) {
      final mt = (timeOfDay + 0.5) % 1.0;
      final norm = ((mt - 0.25) / 0.50).clamp(0.0, 1.0);
      disc(
        norm,
        const Color(0xFFF2F4FF),
        const Color(0xFFCFE0FF),
        moonOpacity * 0.9,
        20,
      );
    }
  }

  // ── Süzülen bulutlar ───────────────────────────────────────────────────────
  // Gökyüzü şeridinde yatayda yavaşça kayan (wrap) yumuşak puff'lar. Her bulut
  // 3 bindirme ezik radyal blob → blur'suz pofuduk kenar.
  static void _clouds(
    Canvas c,
    double w,
    double horizonY,
    double time,
    double dayLight,
    Color sunColor,
  ) {
    final cloudA = (0.30 * (0.42 + dayLight * 0.58)).clamp(0.0, 0.40);
    if (cloudA < 0.03) return;
    final base = Color.lerp(
      const Color(0xFFB8C6D2),
      Colors.white,
      dayLight * 0.7,
    )!;
    final tint = Color.lerp(base, sunColor, 0.18)!;
    final span = w + 520;
    for (int i = 0; i < 5; i++) {
      final speed = 3.5 + i * 1.6;
      final cx = ((i * 0.27 + 0.04) * span + time * speed) % span - 260;
      final cy = horizonY * (0.26 + (i % 3) * 0.20);
      final scale = 0.78 + (i % 4) * 0.20;
      _puff(c, cx, cy, 80 * scale, tint, cloudA);
    }
  }

  static const List<(double, double, double)> _puffOffsets = [
    (-0.70, 0.12, 0.70),
    (0.0, -0.18, 1.0),
    (0.72, 0.14, 0.66),
  ];

  static void _puff(
    Canvas c,
    double cx,
    double cy,
    double r,
    Color tint,
    double a,
  ) {
    for (final (ox, oy, s) in _puffOffsets) {
      final bx = cx + r * ox, by = cy + r * oy;
      final br = r * s;
      _p.shader = ui.Gradient.radial(
        Offset(bx, by),
        br,
        [tint.withValues(alpha: a), tint.withValues(alpha: 0.0)],
        const [0.0, 1.0],
      );
      c.save();
      c.translate(bx, by);
      c.scale(1.0, 0.48); // ezik → yatay bulut
      c.translate(-bx, -by);
      c.drawCircle(Offset(bx, by), br, _p);
      c.restore();
      _p.shader = null;
    }
  }

  // ── Denize yansıma sütunu ──────────────────────────────────────────────────
  // Güneş/ay'ın su üstündeki parıltı şeridi — ufuktan aşağı uzanır + şimmer
  // çentikleri. Diskle aynı yatay konumdan (timeOfDay) hizalanır.
  static void _reflection(
    Canvas c,
    Size size,
    double horizonY,
    double time,
    double timeOfDay,
    Color sunColor,
    double sunOpacity,
    double moonOpacity,
  ) {
    final w = size.width, h = size.height;

    void column(double norm, Color tint, double strength) {
      if (strength <= 0.01) return;
      final cx = w / 2 + w * 0.40 * cos(pi * norm);
      final cw = w * 0.07;
      _p.blendMode = BlendMode.plus;
      // Dikey ışık şeridi (ufuktan denizin dibine)
      _p.shader = ui.Gradient.linear(
        Offset(cx - cw, 0),
        Offset(cx + cw, 0),
        [
          tint.withValues(alpha: 0.0),
          tint.withValues(alpha: 0.14 * strength),
          tint.withValues(alpha: 0.0),
        ],
        const [0.0, 0.5, 1.0],
      );
      c.drawRect(Rect.fromLTWH(cx - cw, horizonY, cw * 2, h - horizonY), _p);
      _p.shader = null;
      // Şimmer çentikleri — şerit boyunca parlayan kısa yatay dilimler
      for (int i = 0; i < 7; i++) {
        final ny = horizonY + (h - horizonY) * (0.05 + i * 0.13);
        final tw = sin(time * (1.4 + i * 0.3) + i * 1.7) * 0.5 + 0.5;
        final a = (tw * tw * 70 * strength).round().clamp(0, 80);
        if (a < 6) continue;
        final hw = cw * (0.5 + tw * 0.5);
        _p.shader = ui.Gradient.linear(
          Offset(cx - hw, 0),
          Offset(cx + hw, 0),
          [
            tint.withValues(alpha: 0.0),
            tint.withValues(alpha: a / 255),
            tint.withValues(alpha: 0.0),
          ],
          const [0.0, 0.5, 1.0],
        );
        c.drawRect(Rect.fromLTWH(cx - hw, ny, hw * 2, 2.5), _p);
        _p.shader = null;
      }
      _p.blendMode = BlendMode.srcOver;
    }

    if (sunOpacity > 0.01) {
      final norm = ((timeOfDay - 0.25) / 0.50).clamp(0.0, 1.0);
      column(norm, sunColor, sunOpacity);
    }
    if (moonOpacity > 0.01) {
      final mt = (timeOfDay + 0.5) % 1.0;
      final norm = ((mt - 0.25) / 0.50).clamp(0.0, 1.0);
      column(norm, const Color(0xFFCFE0FF), moonOpacity * 0.8);
    }
  }
}
