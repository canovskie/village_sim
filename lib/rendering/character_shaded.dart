part of 'character_renderer.dart';

/// SHADED YARDIMCILAR — her yeni rol BUNLARLA çizilir (_shadedRect/_shadedArm/…). Yüz, saç, sakal burada.

// ════════════════════════════════════════════════════════════════════════════
// YENİ NPC RENDER SİSTEMİ — per-NPC görsel varyasyon + 3-ton shading
// ════════════════════════════════════════════════════════════════════════════

/// Shaded rect — baz renk + BLOK ayrımlı ton (üst aydınlık / alt gölge) +
/// sağ kenar ışık düşüşü + outline.
///
/// Neden 1px şerit değil: karakterler kCharScale=0.34 ile çiziliyor, yani
/// 1px'lik highlight ekranda 0.34px'e düşüyor — kaybolur ya da gri bulanıklık
/// bırakır. Downscale'den sağ çıkan tek şey BLOK değer kontrastı; hacim onunla
/// okunuyor. Yakın zoom'da da pixel-art dili bozulmuyor (kenarlar hâlâ sert).
void _shadedRect(Canvas c, Rect r, Color base) {
  c.drawRect(r, _f(base));
  if (r.width >= 10) {
    // GENİŞ yüzey (gövde, şapka, çanta) → yatay blok ayrımı: üstten gelen
    // ışık, alt yarı gölgede.
    c.drawRect(
      Rect.fromLTRB(r.left, r.top + r.height * 0.55, r.right, r.bottom),
      _f(darker(base, 0.20)),
    );
    c.drawRect(
      Rect.fromLTRB(r.left, r.top, r.right, r.top + r.height * 0.22),
      _f(lighter(base, 0.13)),
    );
    // Sağ kenar ışık düşüşü — alpha ki alt/üst blok tonları korunsun.
    c.drawRect(
      Rect.fromLTRB(r.right - r.width * 0.20, r.top, r.right, r.bottom),
      _f(const Color(0x24000000)),
    );
  } else {
    // DAR uzuv (kol, bacak, el) → DİKEY ayrım: silindir shading. Yatay blok
    // burada hacim değil, "çizme üstü / manşet" gibi sahte bir detay çizgisi
    // okunuyordu — uzuv boyunca ton sabit, yanları koyu olmalı.
    c.drawRect(
      Rect.fromLTRB(r.left, r.top, r.left + r.width * 0.34, r.bottom),
      _f(lighter(base, 0.10)),
    );
    c.drawRect(
      Rect.fromLTRB(r.right - r.width * 0.30, r.top, r.right, r.bottom),
      _f(darker(base, 0.18)),
    );
  }
  c.drawRect(r, _s(_outline));
}

/// Gövde — omuzdan bele daralan yamuk + hane kuşağı.
///
/// Düz dikdörtgen gövde tüm meslekleri aynı dikey çubuğa çeviriyordu; oynanan
/// zoom'da NPC'yi ayırt eden ilk şey siluet, taper onu geri veriyor. Dış hat
/// AA'lı (yumuşak siluet), iç bloklar sert (pixel-art dili) — "yuvarlaklık
/// dış hatta, içeride değil".
void _shadedTorso(
  Canvas c,
  Rect r,
  Color base, {
  double waist = 0.72,
}) {
  final cx = r.center.dx;
  // Omuz, gövde kutusundan biraz TAŞAR — dikdörtgen siluetin en tepesinde
  // gerçek bir omuz hattı oluşur. Alt uçta bele daralır (cüppede tersine
  // açılır, bkz. waist > 1).
  final flare = waist > 1.0 ? 1.0 : 1.07;
  final ht = r.width / 2 * flare;
  final hb = r.width / 2 * waist;
  final p = Path()
    ..moveTo(cx - ht, r.top + 2)
    ..lineTo(cx - ht * 0.86, r.top)
    ..lineTo(cx + ht * 0.86, r.top)
    ..lineTo(cx + ht, r.top + 2)
    ..lineTo(cx + hb, r.bottom)
    ..lineTo(cx - hb, r.bottom)
    ..close();

  c.save();
  c.clipPath(p);
  c.drawRect(r, _f(base));
  c.drawRect(
    Rect.fromLTRB(r.left, r.top + r.height * 0.55, r.right, r.bottom),
    _f(darker(base, 0.20)),
  );
  c.drawRect(
    Rect.fromLTRB(r.left, r.top, r.right, r.top + r.height * 0.22),
    _f(lighter(base, 0.13)),
  );
  c.drawRect(
    Rect.fromLTRB(r.right - r.width * 0.20, r.top, r.right, r.bottom),
    _f(const Color(0x24000000)),
  );
  _houseSash(c, r, cx, ht, hb);
  c.restore();

  c.drawPath(p, _sa(_outline, 1.0));
}

/// Hane kuşağı — sol omuzdan sağ kalçaya doğygun renkli bant.
/// Yatay kemer yerine ÇAPRAZ: siluette kırılma yapar, uzaktan da okunur.
/// Renk soyaddan geliyor (bkz. [houseAccentColor]) → "şu adam Karaoğulları'ndan"
/// bilgisi kozmetik değil, gözle okunan oyun bilgisi.
void _houseSash(Canvas c, Rect r, double cx, double ht, double hb) {
  if (_primitiveClothing) return;
  final acc = _accent;
  if (acc == null) return;
  // Kuşak GÖĞÜSTE durur: uzun gövdelerde (rahip cüppesi 62px) bitişe kadar
  // uzatılırsa dev bir çapraz banda dönüşüyor. Bant boyu göğüsle sınırlı.
  final bottom = min(r.bottom - 6.0, r.top + 26.0);
  final a = Offset(cx - ht - 1, r.top + 3.5);
  final b = Offset(cx + hb + 1, bottom);
  c.drawLine(a, b, _sa(acc, 5.0));
  // Alt kenarına koyu ton — kuşağın kendi hacmi (düz renk bant yassı durur).
  c.drawLine(
    a.translate(0, 2.6),
    b.translate(0, 2.6),
    _sa(darker(acc, 0.24), 1.4),
  );
}

/// Shaded leg — hip pivot rotation + 3-tone hose + boot.
/// [legLift] adım atan ayağın yerden yükselmesi (negatif Y; walking iken
/// adım atan bacak hafifçe kalkar, diğeri yerde basılı kalır).
/// Bacak + bot tam olarak yere (origin y=0) ulaşır; gölge orada çizilir.
void _shadedLeg(
  Canvas c,
  double hipX,
  double angle,
  Color hose,
  Color boot, {
  double legLift = 0,
}) {
  final joints = npcLegPose(hipX, angle, legLift);
  void bone((double, double) from, (double, double) to, double width) {
    final dx = to.$1 - from.$1, dy = to.$2 - from.$2;
    c.save();
    c.translate(from.$1, from.$2);
    c.rotate(atan2(dy, dx) - pi / 2);
    _shadedRect(
      c,
      Rect.fromLTWH(-width / 2, 0, width, sqrt(dx * dx + dy * dy)),
      hose,
    );
    c.restore();
  }

  bone(joints.hip, joints.knee, 8);
  bone(joints.knee, joints.ankle, 7);
  _shadedRect(
    c,
    Rect.fromLTWH(joints.knee.$1 - 4, joints.knee.$2 - 3, 8, 6),
    hose,
  );
  _shadedRect(
    c,
    Rect.fromLTWH(joints.ankle.$1 - 5, joints.ankle.$2 - 2, 12, 7),
    boot,
  );
}

/// Shaded arm — shoulder pivot rotation + 3-tone sleeve + skin-tone hand.
void _shadedArm(
  Canvas c,
  double shoulderX,
  double angle,
  Color sleeve,
  Color skin, [
  void Function(Canvas)? item,
]) {
  c.save();
  c.translate(shoulderX, -68);
  c.rotate(angle);
  _shadedRect(c, const Rect.fromLTWH(-4, 0, 8, 16), sleeve);
  // El — ten renginde küçük blok
  _shadedRect(c, const Rect.fromLTWH(-4, 16, 8, 6), skin);
  item?.call(c);
  c.restore();
}

/// Shaded tunic — kıyafet rengi, kemer kuşağı.
void _shadedTunic(Canvas c, Color cloth) {
  _shadedTorso(c, const Rect.fromLTWH(-12, -68, 24, 32), cloth);
  // Kemer
  _shadedRect(c, const Rect.fromLTWH(-12, -50, 24, 5), _leather);
  // Toka — sabit küçük detay
  c.drawRect(const Rect.fromLTWH(-3, -50, 6, 5), _f(_leatherDk));
}

/// Per-NPC kafa: ten + saç (stil) + sakal (stil) + göz (renk) + blink.
/// [time] blink animasyonu için zaman parametresi.
/// [y] kafanın merkez Y koordinatı (default -80).
void _shadedHead(
  Canvas c,
  NpcVisual v,
  double time, {
  double y = -80,
}) {
  // ── Yüz / ten — yuvarlatılmış çene (yumuşak, tatlı silüet) ─────────────
  // Üst köşeler hafif, alt köşeler (çene) belirgin yuvarlak → bebeksi oran.
  final faceR = RRect.fromRectAndCorners(
    Rect.fromLTWH(-9, y - 10, 18, 20),
    topLeft: const Radius.circular(3),
    topRight: const Radius.circular(3),
    bottomLeft: const Radius.circular(6),
    bottomRight: const Radius.circular(6),
  );
  c.drawRRect(faceR, _fa(v.skin));
  // Hacim: alın aydınlık, çene yumuşak gölge.
  c.drawRect(Rect.fromLTWH(-7, y - 9, 14, 2), _fa(lighter(v.skin, 0.10)));
  c.drawRect(Rect.fromLTWH(-6, y + 6, 12, 2), _fa(darker(v.skin, 0.10)));
  c.drawRRect(faceR, _sa(_outline));

  // ── Saç (stile göre) ──────────────────────────────────────────────────
  _drawHair(c, v, y);

  // ── Sakal (varsa, saçtan ÖNCE çiz ki üstte kalmasın) ──────────────────
  if (v.hasBeard) _drawBeard(c, v, y);

  // ── Yanak allığı — tatlı pembe, yumuşak ───────────────────────────────
  const blush = Color(0x3AE08484);
  c.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(-7.5, y + 1, 3.5, 2.4),
      const Radius.circular(1.2),
    ),
    _fa(blush),
  );
  c.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(4, y + 1, 3.5, 2.4),
      const Radius.circular(1.2),
    ),
    _fa(blush),
  );

  // ── Gözler (büyük, parlak, glint'li) + blink ──────────────────────────
  // Blink: nadir, kısa.  sin > 0.96 → kapalı (≈0.6 sn / 8 sn döngü)
  final blinkRaw = sin(time * 0.78 + v.blinkPhase);
  if (blinkRaw > 0.96) {
    // Mutlu kapalı göz — yukarı kıvrık küçük yay ( ^ ^ )
    _happyClosedEye(c, -6.4, y);
    _happyClosedEye(c, 2.4, y);
  } else {
    _cuteEye(c, -6.4, y, v.eyes);
    _cuteEye(c, 2.4, y, v.eyes);
  }

  // ── Kaş — ince, hafif kalkık (masum/yumuşak ifade) ────────────────────
  final brow = darker(v.hair, 0.05);
  c.drawRect(Rect.fromLTWH(-6.4, y - 5, 3, 1), _fa(brow));
  c.drawRect(Rect.fromLTWH(3.4, y - 5, 3, 1), _fa(brow));

  // ── Ağız — küçük gülümseme (tam sakal yoksa görünür) ──────────────────
  if (v.beardStyle != BeardStyle.full) {
    _smile(c, y);
  }
}

/// Tatlı göz: koyu yuvarlak çerçeve + renkli iris + beyaz glint (parlama).
/// Glint, "canlı/sevimli" hissinin ana sinyali.
void _cuteEye(Canvas c, double ex, double y, Color iris) {
  c.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(ex, y - 3.5, 4, 5),
      const Radius.circular(1.8),
    ),
    _fa(_outline),
  );
  c.drawRect(Rect.fromLTWH(ex + 0.8, y - 2.4, 2.4, 3), _fa(iris));
  c.drawRect(
    Rect.fromLTWH(ex + 0.8, y - 2.8, 1.4, 1.4),
    _fa(const Color(0xFFFFFFFF)),
  );
}

/// Mutlu kapalı göz — yukarı kıvrık küçük yay (blink anı).
void _happyClosedEye(Canvas c, double ex, double y) {
  c.drawPath(
    Path()
      ..moveTo(ex, y - 1)
      ..quadraticBezierTo(ex + 2, y - 3.4, ex + 4, y - 1),
    _sa(_outline, 1.2),
  );
}

/// Küçük yukarı kıvrık gülümseme.
void _smile(Canvas c, double y) {
  c.drawPath(
    Path()
      ..moveTo(-3, y + 4.6)
      ..quadraticBezierTo(0, y + 7, 3, y + 4.6),
    _sa(_outline, 1.2),
  );
}

/// Hair rendering — stile göre farklı şekil.
void _drawHair(Canvas c, NpcVisual v, double y) {
  if (v.hairStyle == HairStyle.bald) return;
  final hair = v.hair;
  final hairS = darker(v.hair, 0.18);

  switch (v.hairStyle) {
    case HairStyle.bald:
      return;
    case HairStyle.short:
      // Üst saç bandı (alın çizgisi)
      c.drawRect(Rect.fromLTWH(-9, y - 11, 18, 5), _f(hair));
      c.drawRect(Rect.fromLTWH(-9, y - 11, 18, 1), _f(hairS));
    case HairStyle.medium:
      // Üst + yan kısa bangs
      c.drawRect(Rect.fromLTWH(-9, y - 11, 18, 6), _f(hair));
      c.drawRect(Rect.fromLTWH(-10, y - 8, 2, 6), _f(hair));
      c.drawRect(Rect.fromLTWH(8, y - 8, 2, 6), _f(hair));
      c.drawRect(Rect.fromLTWH(-9, y - 11, 18, 1), _f(hairS));
    case HairStyle.long:
      // Uzun: üst + yan saç çene altına kadar
      c.drawRect(Rect.fromLTWH(-9, y - 11, 18, 6), _f(hair));
      c.drawRect(Rect.fromLTWH(-11, y - 8, 3, 18), _f(hair));
      c.drawRect(Rect.fromLTWH(8, y - 8, 3, 18), _f(hair));
      c.drawRect(Rect.fromLTWH(-11, y + 8, 3, 1), _f(hairS));
      c.drawRect(Rect.fromLTWH(8, y + 8, 3, 1), _f(hairS));
    case HairStyle.messy:
      // Tepe + dağınık peakler
      c.drawRect(Rect.fromLTWH(-9, y - 11, 18, 4), _f(hair));
      c.drawRect(Rect.fromLTWH(-7, y - 14, 4, 4), _f(hair));
      c.drawRect(Rect.fromLTWH(0, y - 14, 3, 4), _f(hair));
      c.drawRect(Rect.fromLTWH(4, y - 13, 3, 3), _f(hair));
  }
}

/// Beard rendering — stile göre.
void _drawBeard(Canvas c, NpcVisual v, double y) {
  final hair = v.hair;
  switch (v.beardStyle) {
    case BeardStyle.none:
      return;
    case BeardStyle.stubble:
      // Hafif sakal — ten ile karışmış nokta deseni
      final stub = Color.alphaBlend(hair.withValues(alpha: 0.35), v.skin);
      c.drawRect(Rect.fromLTWH(-7, y + 3, 14, 4), _f(stub));
    case BeardStyle.full:
      // Tam sakal — alt yüzü kaplar
      c.drawRect(Rect.fromLTWH(-9, y + 2, 18, 9), _f(hair));
      c.drawRect(Rect.fromLTWH(-9, y + 2, 18, 1), _f(darker(hair, 0.15)));
    case BeardStyle.goatee:
      // Sadece çene ucu
      c.drawRect(Rect.fromLTWH(-3, y + 4, 6, 5), _f(hair));
      c.drawRect(Rect.fromLTWH(-3, y + 4, 6, 1), _f(darker(hair, 0.15)));
  }
}
