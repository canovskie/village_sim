part of 'character_renderer.dart';

/// ROL ÇİZİMLERİ — meslek başına shaded + kişisel görsel: köylü, çiftçi, tüccar, demirci, muhafız, imparatorluk askeri, rahip, çoban, avcı, değirmenci, hancı, madenci, balıkçı.

// ─── KÖYLÜ (mesleksiz — çocuk/genç evresi) ────────────────────────────────
// Tipten bağımsız standart keten tunik + yün pantolon, alet/şapka yok.
// [child] true ise kafa büyük çizilir (çocuk oranı).
void _primitiveNpc(
  Canvas c,
  _Anim anim,
  NpcVisual v,
  double time, {
  bool child = false,
  void Function(Canvas)? rightItem,
}) {
  final hide = _cloth(const Color(0xFF8A6945), v.clothingShift * 0.35);
  final hideDark = darker(hide, 0.24);
  final legWrap = _cloth(const Color(0xFF5C4932), v.clothingShift * 0.20);

  _shadow(c, anim);
  _shadedLeg(c, -6, anim.legL, legWrap, _leatherDk, legLift: anim.legLiftL);
  _shadedLeg(c, 6, anim.legR, legWrap, _leatherDk, legLift: anim.legLiftR);

  c.save();
  _applyTorsoTransform(c, anim);
  final tunic = Path()
    ..moveTo(-14, -68)
    ..lineTo(13, -68)
    ..lineTo(12, -38)
    ..lineTo(5, -35)
    ..lineTo(-1, -39)
    ..lineTo(-7, -35)
    ..lineTo(-13, -38)
    ..close();
  c.drawPath(tunic, _f(hide));
  c.drawPath(tunic, _s(_outline));
  c.drawRect(const Rect.fromLTWH(-13, -51, 25, 5), _f(_leatherDk));
  c.drawLine(
    const Offset(-10, -68),
    const Offset(9, -43),
    _s(const Color(0xFFB49364), 2.0),
  );
  // Ayrı tonlu yamalar kaba, elde birleştirilmiş silueti okunur kılar.
  c.drawRect(const Rect.fromLTWH(-10, -61, 7, 6), _f(hideDark));
  c.drawRect(const Rect.fromLTWH(4, -45, 6, 5), _f(lighter(hide, 0.12)));
  _shadedArm(c, -16, anim.armL, hide, v.skin);
  _shadedArm(c, 16, anim.armR, hide, v.skin, rightItem);
  if (child) {
    c.save();
    c.translate(0, -80);
    c.scale(1.28, 1.28);
    _shadedHead(c, v, time, y: 0);
    c.restore();
  } else {
    _shadedHead(c, v, time);
  }
  c.restore();
}

void _peasantNpc(
  Canvas c,
  _Anim anim,
  NpcVisual v,
  double time, {
  bool child = false,
}) {
  final tunicBase = _cloth(_linen, v.clothingShift);
  final hoseBase = _cloth(_woolBrown, v.clothingShift * 0.6);

  _shadow(c, anim);
  _shadedLeg(c, -6, anim.legL, hoseBase, _leatherDk, legLift: anim.legLiftL);
  _shadedLeg(c, 6, anim.legR, hoseBase, _leatherDk, legLift: anim.legLiftR);

  c.save();
  _applyTorsoTransform(c, anim);
  _shadedTunic(c, tunicBase);
  _shadedArm(c, -15, anim.armL, tunicBase, v.skin);
  _shadedArm(c, 15, anim.armR, tunicBase, v.skin);
  if (child) {
    // Çocuk: kafayı büyüt → "küçük yetişkin" hissini kırar.
    c.save();
    c.translate(0, -80);
    c.scale(1.28, 1.28);
    _shadedHead(c, v, time, y: 0);
    c.restore();
  } else {
    _shadedHead(c, v, time);
  }
  c.restore();
}

/// Karar sonrasında sahnede kalan kişisel kıyafet. İki sonuç aynı gövdenin
/// renk varyantı değildir: uzaktan bile farklı siluet verir. `flowing`
/// aşağı doğru açılan serbest bir giysi; `traditional` köyün dayattığı düz,
/// kuşaklı uzun kaftandır.
void _personalWardrobeNpc(
  Canvas c,
  _Anim anim,
  NpcVisual v,
  double time,
  NpcWardrobe wardrobe,
) {
  final flowing = wardrobe == NpcWardrobe.flowing;
  final cloth = _cloth(
    flowing ? const Color(0xFF416E78) : const Color(0xFF8A6945),
    v.clothingShift,
  );
  final lower = darker(cloth, flowing ? 0.12 : 0.20);
  _shadow(c, anim);
  _shadedLeg(c, -6, anim.legL, lower, _leatherDk, legLift: anim.legLiftL);
  _shadedLeg(c, 6, anim.legR, lower, _leatherDk, legLift: anim.legLiftR);

  c.save();
  _applyTorsoTransform(c, anim);
  if (flowing) {
    _shadedTorso(c, const Rect.fromLTWH(-12, -68, 24, 24), cloth);
    final skirt = Path()
      ..moveTo(-11, -46)
      ..lineTo(11, -46)
      ..lineTo(18, -12)
      ..lineTo(-18, -12)
      ..close();
    c.drawPath(skirt, _f(cloth));
    c.drawPath(skirt, _s(_outline));
    c.drawRect(
      const Rect.fromLTWH(-13, -45, 26, 4),
      _f(lighter(cloth, 0.14)),
    );
    c.drawLine(
      const Offset(0, -40),
      const Offset(0, -15),
      _s(darker(cloth, 0.18), 1.2),
    );
  } else {
    final coat = Path()
      ..moveTo(-13, -68)
      ..lineTo(13, -68)
      ..lineTo(15, -18)
      ..lineTo(1, -14)
      ..lineTo(-15, -18)
      ..close();
    c.drawPath(coat, _f(cloth));
    c.drawPath(coat, _s(_outline));
    c.drawRect(const Rect.fromLTWH(-14, -50, 28, 6), _f(_leatherDk));
    c.drawLine(
      const Offset(-9, -66),
      const Offset(8, -22),
      _s(const Color(0xFFC29A42), 3.0),
    );
  }
  _shadedArm(c, -16, anim.armL, cloth, v.skin);
  _shadedArm(c, 16, anim.armR, cloth, v.skin);
  _shadedHead(c, v, time);
  c.restore();
}

// ─── ÇIFTÇI (yeni — per-NPC görsel + akıcı hareket) ───────────────────────
void _farmerNpc(Canvas c, _Anim anim, NpcVisual v, double time) {
  // Kıyafet renkleri — baz + tint shift per-NPC
  final tunicBase = _cloth(_linen, v.clothingShift);
  final hoseBase = _cloth(_woolBrown, v.clothingShift * 0.6);
  final hatStraw = _cloth(_straw, v.clothingShift * 0.5);

  _shadow(c, anim);
  // Bacaklar gövde lean/sway'ından bağımsız — ayak yerde sabit
  _shadedLeg(c, -6, anim.legL, hoseBase, _leatherDk, legLift: anim.legLiftL);
  _shadedLeg(c, 6, anim.legR, hoseBase, _leatherDk, legLift: anim.legLiftR);

  // Gövde transform — bob + sway + lean (ortak helper)
  c.save();
  _applyTorsoTransform(c, anim);

  _shadedTunic(c, tunicBase);
  _shadedArm(c, -15, anim.armL, tunicBase, v.skin);
  _shadedArm(c, 15, anim.armR, tunicBase, v.skin);
  _shadedHead(c, v, time);

  // Hasır şapka — saç görünür kalsın diye üstten çiz (kafayı kapatmaz tam)
  _shadedRect(c, const Rect.fromLTWH(-17, -98, 34, 8), hatStraw);
  _shadedRect(c, const Rect.fromLTWH(-7, -110, 14, 12), hatStraw);
  c.drawRect(
    const Rect.fromLTWH(-7, -100, 14, 2),
    _f(const Color(0xFF6A4830)),
  );
  c.restore();
}

// ─── TÜCCAR (yeni — shaded + per-NPC görsel) ──────────────────────────────
void _merchantNpc(Canvas c, _Anim anim, NpcVisual v, double time) {
  final cloakBase = _cloth(const Color(0xFF4A5030), v.clothingShift);
  final hoseBase = _cloth(_woolDark, v.clothingShift * 0.6);
  final hoodBase = darker(cloakBase, 0.06);

  _shadow(c, anim);
  _shadedLeg(c, -6, anim.legL, hoseBase, _leatherDk, legLift: anim.legLiftL);
  _shadedLeg(c, 6, anim.legR, hoseBase, _leatherDk, legLift: anim.legLiftR);

  c.save();
  _applyTorsoTransform(c, anim);

  // Pelerin (gövde)
  _shadedTorso(c, const Rect.fromLTWH(-14, -68, 28, 32), cloakBase);
  // Yaka linen
  _shadedRect(c, const Rect.fromLTWH(-8, -42, 16, 6), _linen);
  // Broş
  _shadedRect(c, const Rect.fromLTWH(-3, -66, 6, 6), const Color(0xFFB0900A));

  _shadedArm(c, -16, anim.armL, cloakBase, v.skin);
  _shadedArm(c, 16, anim.armR, cloakBase, v.skin);

  // Çanta
  _shadedRect(c, const Rect.fromLTWH(14, -50, 12, 14), _leather);
  c.drawRect(const Rect.fromLTWH(14, -50, 12, 3), _f(_leatherDk));
  c.drawLine(
    const Offset(14, -52),
    const Offset(8, -62),
    _s(_leatherDk, 1.2),
  );

  _shadedHead(c, v, time);

  // Kapüşon — saç görünür kalsın diye arka katman
  _shadedRect(c, const Rect.fromLTWH(-11, -98, 22, 14), hoodBase);
  c.drawRect(
    const Rect.fromLTWH(-10, -92, 20, 8),
    _f(darker(hoodBase, 0.14)),
  );
  c.restore();
}

// ─── DEMIRCI (yeni — shaded + per-NPC görsel) ──────────────────────────────
void _blacksmithNpc(
  Canvas c,
  _Anim anim,
  NpcVisual v,
  double time, {
  bool hammering = false,
}) {
  final shirtBase = _cloth(const Color(0xFF5A3818), v.clothingShift);
  final hoseBase = _cloth(const Color(0xFF3A3028), v.clothingShift * 0.5);
  const apronBase = _leather;

  _shadow(c, anim);
  _shadedLeg(c, -6, anim.legL, hoseBase, _leatherDk, legLift: anim.legLiftL);
  _shadedLeg(c, 6, anim.legR, hoseBase, _leatherDk, legLift: anim.legLiftR);

  c.save();
  _applyTorsoTransform(c, anim);

  // Tunik
  _shadedTorso(c, const Rect.fromLTWH(-14, -68, 28, 32), shirtBase);
  // Önlük (deri)
  _shadedRect(c, const Rect.fromLTWH(-9, -66, 18, 30), apronBase);
  // Askılar
  c.drawLine(const Offset(-7, -66), const Offset(0, -76), _s(_leather, 2.5));
  c.drawLine(const Offset(7, -66), const Offset(0, -76), _s(_leather, 2.5));

  _shadedArm(c, -18, anim.armL, shirtBase, v.skin);
  _shadedArm(
    c,
    18,
    anim.armR,
    shirtBase,
    v.skin,
    hammering ? (arm) => ToolRenderer.drawHammer(arm, scale: 1.15) : null,
  );

  _shadedHead(c, v, time, y: -82);

  // Deri kukuleta
  _shadedRect(c, const Rect.fromLTWH(-10, -100, 20, 14), _leather);
  c.restore();
}

// ─── MUHAFIZ (yeni — shaded + per-NPC görsel) ──────────────────────────────
void _guardNpc(
  Canvas c,
  _Anim anim,
  NpcVisual v,
  double time, {
  bool handsBusy = false,
}) {
  final gambBase = _cloth(const Color(0xFFB8A878), v.clothingShift);
  final hoseBase = _cloth(const Color(0xFF504838), v.clothingShift * 0.4);
  final gambStripe = darker(gambBase, 0.20);

  _shadow(c, anim);
  _shadedLeg(
    c,
    -6,
    anim.legL,
    hoseBase,
    const Color(0xFF303028),
    legLift: anim.legLiftL,
  );
  _shadedLeg(
    c,
    6,
    anim.legR,
    hoseBase,
    const Color(0xFF303028),
    legLift: anim.legLiftR,
  );

  c.save();
  _applyTorsoTransform(c, anim);

  // Gambeson
  _shadedTorso(c, const Rect.fromLTWH(-13, -68, 26, 32), gambBase);
  // Yatay dikiş çizgileri
  for (final y in [-62.0, -55.0, -48.0, -41.0]) {
    c.drawRect(Rect.fromLTWH(-12, y, 24, 1), _f(gambStripe));
  }
  // Omuz plakaları
  _shadedRect(c, const Rect.fromLTWH(-28, -74, 16, 10), _leather);
  _shadedRect(c, const Rect.fromLTWH(12, -74, 16, 10), _leather);

  if (handsBusy) {
    _shadedArm(c, -20, anim.armL, gambBase, v.skin);
    _shadedArm(c, 20, anim.armR, gambBase, v.skin);
  } else {
    // Sol kol + kalkan
    _shadedArmWithShield(c, -20, anim.armL, gambBase, v.skin);
    // Sağ kol + mızrak
    _shadedArm(c, 20, anim.armR, gambBase, v.skin, (arm) {
      _shadedRect(arm, const Rect.fromLTWH(3, -40, 3, 80), _woodBrown);
      _shadedRect(arm, const Rect.fromLTWH(1, -52, 7, 12), _ironGrey);
    });
  }

  _shadedHead(c, v, time);

  // Demir miğfer — başı kaplar (saçın üstüne)
  _shadedRect(c, const Rect.fromLTWH(-11, -100, 22, 18), _ironGrey);
  c.drawRect(const Rect.fromLTWH(-13, -92, 26, 4), _f(_ironGrey));
  c.drawRect(const Rect.fromLTWH(-2, -92, 4, 10), _f(_ironDk));
  c.restore();
}

void _shadedArmWithShield(
  Canvas c,
  double shoulderX,
  double angle,
  Color sleeve,
  Color skin,
) {
  c.save();
  c.translate(shoulderX, -68);
  c.rotate(angle);
  _shadedRect(c, const Rect.fromLTWH(-4, 0, 8, 16), sleeve);
  _shadedRect(c, const Rect.fromLTWH(-4, 16, 8, 6), skin);
  // Kalkan
  _shadedRect(
    c,
    const Rect.fromLTWH(-16, 4, 22, 22),
    const Color(0xFF8B4513),
  );
  // Merkez kabara
  _shadedRect(c, const Rect.fromLTWH(-8, 10, 8, 8), _ironGrey);
  c.restore();
}

// ─── İMPARATORLUK ASKERİ (dış güç — kostüm override) ──────────────────────
// Köyün muhafızından kasıtlı AYRIK: soğuk çelik kürişit + kızıl tabard +
// tam miğfer. Komutan uzun kızıl sorguç + pelerin taşır → heyetin lideri
// gözle ayrışır. Köylü paletinin sıcak ahşap/keten tonlarından uzak.
const _impSteel = Color(0xFF6A707C); // soğuk çelik plaka
const _impSteelDk = Color(0xFF3A3E47); // çelik gölge
const _impCrimson = Color(0xFF8E1B1B); // imparatorluk kızılı
const _impCrimDk = Color(0xFF5A0F0F); // kızıl gölge
const _impGold = Color(0xFFC8A042); // amblem altını

void _imperialSoldierNpc(
  Canvas c,
  _Anim anim,
  NpcVisual v,
  double time, {
  bool commander = false,
  bool attacking = false,
  double? combatSwing,
  bool handsBusy = false,
}) {
  final hose = _cloth(_impSteelDk, v.clothingShift * 0.3);

  // Saldırı modunda mızrak ileri DÜRTÜLÜR (jab) + gövde öne saldırgan eğilir.
  // ~1.5 rad mızrağı yatay-ileri çevirir; jab salınımı içeri/dışarı dürtme.
  final jab = combatSwing ?? sin(time * 8.0);
  final effectiveAttack = attacking && !handsBusy;
  final spearArm = effectiveAttack ? 1.1 + jab * 0.65 : anim.armR;
  final atkLean = effectiveAttack ? 0.18 + jab.clamp(0.0, 1.0) * 0.07 : 0.0;

  _shadow(c, anim);

  // Komutan pelerini — gövdenin ARKASINA (bacaklardan önce) düşer.
  if (commander) {
    c.save();
    _applyTorsoTransform(c, anim);
    final cape = Path()
      ..moveTo(-12, -70)
      ..lineTo(12, -70)
      ..lineTo(16, -14)
      ..lineTo(-16, -14)
      ..close();
    c.drawPath(cape, _f(_impCrimson));
    c.drawPath(cape, _s(_impCrimDk));
    // Orta katlanma gölgesi (kumaş hacmi).
    c.drawRect(const Rect.fromLTWH(-2, -68, 4, 54), _f(_impCrimDk));
    c.restore();
  }

  _shadedLeg(
    c,
    -6,
    anim.legL,
    hose,
    const Color(0xFF26282E),
    legLift: anim.legLiftL,
  );
  _shadedLeg(
    c,
    6,
    anim.legR,
    hose,
    const Color(0xFF26282E),
    legLift: anim.legLiftR,
  );

  c.save();
  _applyTorsoTransform(c, anim);
  // Saldırgan öne atılma — gövde + kafa + miğfer hep birlikte eğilir.
  if (atkLean != 0) {
    c.translate(0, -40);
    c.rotate(atkLean);
    c.translate(0, 40);
  }

  // Çelik kürişit (göğüs plakası).
  _shadedTorso(c, const Rect.fromLTWH(-13, -68, 26, 32), _impSteel);
  // Plaka katman çizgileri (lamel).
  for (final y in [-60.0, -52.0, -44.0]) {
    c.drawRect(Rect.fromLTWH(-12, y, 24, 1.4), _f(_impSteelDk));
  }
  // Kızıl tabard — göğüs ortasından bele inen şerit.
  _shadedRect(c, const Rect.fromLTWH(-5, -68, 10, 34), _impCrimson);
  // Tabard üstünde altın amblem (çift bant).
  c.drawRect(const Rect.fromLTWH(-5, -58, 10, 2), _f(_impGold));
  c.drawRect(const Rect.fromLTWH(-3, -52, 6, 2), _f(_impGold));

  // Çelik omuzluk (pauldron) plakaları.
  _shadedRect(c, const Rect.fromLTWH(-29, -75, 17, 11), _impSteel);
  _shadedRect(c, const Rect.fromLTWH(12, -75, 17, 11), _impSteel);

  if (handsBusy) {
    _shadedArm(c, -20, anim.armL, _impSteel, v.skin);
    _shadedArm(c, 20, anim.armR, _impSteel, v.skin);
  } else {
    // Sol kol + imparatorluk kalkanı.
    _shadedArm(c, -20, anim.armL, _impSteel, v.skin, (arm) {
      _shadedRect(arm, const Rect.fromLTWH(-17, 2, 23, 24), _impCrimson);
      _shadedRect(arm, const Rect.fromLTWH(-15, 4, 19, 20), _impCrimDk);
      // Altın hat + merkez çelik kabara.
      arm.drawRect(const Rect.fromLTWH(-15, 12, 19, 2), _f(_impGold));
      arm.drawRect(const Rect.fromLTWH(-9, 8, 4, 12), _f(_impGold));
      _shadedRect(arm, const Rect.fromLTWH(-8, 11, 6, 6), _impSteel);
    });
    // Sağ kol + mızrak (uzun çelik uçlu). Saldırıda [spearArm] ileri dürter.
    _shadedArm(c, 20, spearArm, _impSteel, v.skin, (arm) {
      _shadedRect(arm, const Rect.fromLTWH(3, -46, 3, 88), _woodBrown);
      _shadedRect(arm, const Rect.fromLTWH(0, -62, 9, 18), _impSteel);
      arm.drawRect(
        const Rect.fromLTWH(2, -64, 5, 4),
        _f(lighter(_impSteel, 0.18)),
      );
    });
  }

  _shadedHead(c, v, time);

  // ── Tam miğfer (çelik) — başı kaplar ────────────────────────────────────
  _shadedRect(c, const Rect.fromLTWH(-11, -101, 22, 19), _impSteel);
  // Alın bandı + burun koruyucu.
  c.drawRect(const Rect.fromLTWH(-13, -92, 26, 4), _f(_impSteelDk));
  c.drawRect(const Rect.fromLTWH(-2, -93, 4, 12), _f(_impSteelDk));
  // Yanak plakaları (yüzü çerçeveler).
  c.drawRect(const Rect.fromLTWH(-12, -90, 3, 9), _f(_impSteel));
  c.drawRect(const Rect.fromLTWH(9, -90, 3, 9), _f(_impSteel));

  if (commander) {
    // Komutan — uzun kızıl at-kılı sorguç (miğfer tepesinden yukarı).
    _shadedRect(c, const Rect.fromLTWH(-3, -118, 6, 18), _impCrimson);
    c.drawRect(
      const Rect.fromLTWH(-1, -118, 2, 18),
      _f(lighter(_impCrimson, 0.12)),
    );
    // Sorguç tabanı (altın taç).
    c.drawRect(const Rect.fromLTWH(-5, -102, 10, 3), _f(_impGold));
  } else {
    // Asker — kısa enine çelik ibik (front-to-back ridge).
    _shadedRect(c, const Rect.fromLTWH(-2, -108, 4, 8), _impSteelDk);
    c.drawRect(const Rect.fromLTWH(-1, -107, 2, 7), _f(_impCrimDk));
  }
  c.restore();
}

/// Visual verilmeyen çağrı yolları (bazı sinematik/önizleme) için nötr görsel —
/// yeni meslekler ayrı "ilkel" varyant taşımaz, hep shaded yoldan çizilir.
final NpcVisual _fallbackVisual = NpcVisual.fromSeed(0);

// ─── RAHİP (eski büyücünün yerine — asa/sivri şapka YOK) ──────────────────
/// Silüet imzası: uzun çivit cüppe + krem omuz atkısı (stola) + kukuleta +
/// belde tespih. Büyü değil, inanç: ölçülü ve ağır.
void _priestNpc(Canvas c, _Anim anim, NpcVisual v, double time) {
  final robeBase = _cloth(_kPriestRobe, v.clothingShift);
  const stole = Color(0xFFDCD2BA); // krem atkı

  _shadow(c, anim);
  // Uzun cüppe → bacak salınımı bastırılmış (ağır kumaş)
  _shadedLeg(
    c,
    -5,
    anim.legL * 0.5,
    robeBase,
    _leatherDk,
    legLift: anim.legLiftL * 0.5,
  );
  _shadedLeg(
    c,
    5,
    anim.legR * 0.5,
    robeBase,
    _leatherDk,
    legLift: anim.legLiftR * 0.5,
  );

  c.save();
  _applyTorsoTransform(c, anim);

  // Uzun cüppe (yere kadar)
  // Cüppe eteğe doğru AÇILIR (waist > 1) — diğer meslekler bele daralırken
  // rahibin silueti tersine genişler, uzaktan bile ayrışır.
  _shadedTorso(
    c,
    const Rect.fromLTWH(-12, -68, 24, 62),
    robeBase,
    waist: 1.22,
  );
  // Krem stola — iki omuzdan aşağı inen atkı (rahibin imzası)
  _shadedRect(c, const Rect.fromLTWH(-7, -68, 4, 40), stole);
  _shadedRect(c, const Rect.fromLTWH(3, -68, 4, 40), stole);
  // Bel kuşağı (kendir halat)
  _shadedRect(
    c,
    const Rect.fromLTWH(-12, -46, 24, 4),
    const Color(0xFF9A8A62),
  );
  // Ayak ucu botları
  _shadedRect(c, const Rect.fromLTWH(-8, -8, 5, 6), _leatherDk);
  _shadedRect(c, const Rect.fromLTWH(3, -8, 5, 6), _leatherDk);

  _shadedArm(c, -17, anim.armL, robeBase, v.skin);
  _shadedArm(c, 17, anim.armR, robeBase, v.skin);

  // Belde asılı tespih — küçük boncuk dizisi (sağ kalça)
  for (int i = 0; i < 4; i++) {
    c.drawRect(
      Rect.fromLTWH(10, -42 + i * 3.0, 2, 2),
      _f(const Color(0xFFC8A042)),
    );
  }

  _shadedHead(c, v, time);

  // Kukuleta (cowl) — tepeyi örter + iki yandan yüzü çerçeveler (düz kutu DEĞİL)
  _shadedRect(c, const Rect.fromLTWH(-11, -98, 22, 11), robeBase); // tepe
  _shadedRect(c, const Rect.fromLTWH(-12, -92, 4, 15), robeBase); // sol yanak
  _shadedRect(c, const Rect.fromLTWH(8, -92, 4, 15), robeBase); // sağ yanak
  c.restore();
}

// ─── ÇOBAN ────────────────────────────────────────────────────────────────
/// Silüet imzası: ham yün tunik + kahve POST yelek (omuzları kabartır) +
/// uzun kıvrık DEĞNEK (crook) + kenarlı hasır şapka.
void _shepherdNpc(
  Canvas c,
  _Anim anim,
  NpcVisual v,
  double time, {
  bool handsBusy = false,
}) {
  final woolBase = _cloth(_kShepherdWool, v.clothingShift);
  final peltBase = _cloth(const Color(0xFF6E5236), v.clothingShift * 0.5);
  final hoseBase = _cloth(_woolBrown, v.clothingShift * 0.4);

  _shadow(c, anim);
  _shadedLeg(c, -6, anim.legL, hoseBase, _leatherDk, legLift: anim.legLiftL);
  _shadedLeg(c, 6, anim.legR, hoseBase, _leatherDk, legLift: anim.legLiftR);

  c.save();
  _applyTorsoTransform(c, anim);

  // Ham yün tunik
  _shadedTorso(c, const Rect.fromLTWH(-12, -68, 24, 32), woolBase);
  // Post yelek — omuzdan aşağı, kenarları tırtıklı (kürk hissi)
  _shadedRect(c, const Rect.fromLTWH(-13, -70, 26, 18), peltBase);
  for (double x = -13; x < 13; x += 4) {
    c.drawRect(Rect.fromLTWH(x, -52, 2, 3), _f(darker(peltBase, 0.18)));
  }
  // Kemer
  _shadedRect(c, const Rect.fromLTWH(-12, -48, 24, 4), _leatherDk);

  _shadedArm(c, -15, anim.armL, woolBase, v.skin);
  // Sağ el + çoban değneği — ELİN İÇİNDEN geçer (x≈0, kol ekseni), gövdeden
  // kopuk havada durmaz.
  _shadedArm(c, 15, anim.armR, woolBase, v.skin, (arm) {
    if (handsBusy) return;
    _shadedRect(arm, const Rect.fromLTWH(-1, -42, 3, 80), _woodBrown);
    // Kıvrık uç — iki blokla "crook"
    _shadedRect(arm, const Rect.fromLTWH(-1, -46, 8, 3), _woodBrown);
    _shadedRect(arm, const Rect.fromLTWH(4, -43, 3, 5), _woodBrown);
  });

  _shadedHead(c, v, time);

  // Geniş kenarlı hasır şapka (çiftçininkinden alçak/yayvan)
  _shadedRect(c, const Rect.fromLTWH(-16, -96, 32, 5), _straw);
  _shadedRect(c, const Rect.fromLTWH(-8, -104, 16, 8), _straw);
  c.restore();
}

// ─── AVCI ─────────────────────────────────────────────────────────────────
/// Silüet imzası: koyu orman yeşili KUKULETA (sivri uçlu) + çapraz sadak
/// (oklar omzundan çıkar) + elde YAY. Kalabalıkta anında okunur.
void _hunterNpc(
  Canvas c,
  _Anim anim,
  NpcVisual v,
  double time, {
  bool handsBusy = false,
}) {
  final cloakBase = _cloth(_kHunterGreen, v.clothingShift);
  final hoseBase = _cloth(const Color(0xFF3E3628), v.clothingShift * 0.4);

  _shadow(c, anim);
  _shadedLeg(c, -6, anim.legL, hoseBase, _leatherDk, legLift: anim.legLiftL);
  _shadedLeg(c, 6, anim.legR, hoseBase, _leatherDk, legLift: anim.legLiftR);

  c.save();
  _applyTorsoTransform(c, anim);

  // Yeşil tunik/pelerin
  _shadedTorso(c, const Rect.fromLTWH(-12, -68, 24, 32), cloakBase);
  // Çapraz deri kayış (sadak askısı)
  c.drawLine(
    const Offset(-11, -64),
    const Offset(11, -44),
    _s(_leather, 3.0),
  );
  // Kemer
  _shadedRect(c, const Rect.fromLTWH(-12, -46, 24, 4), _leatherDk);

  // Sırttaki sadak + oklar — gövdeye YASLI (kopuk durmasın), koldan önce çizilir
  _shadedRect(c, const Rect.fromLTWH(-19, -68, 9, 20), _leather);
  for (int i = 0; i < 3; i++) {
    final ax = -18 + i * 3.0;
    c.drawRect(Rect.fromLTWH(ax, -80, 2, 14), _f(_woodBrown)); // ok gövdesi
    c.drawRect(
      Rect.fromLTWH(ax - 0.5, -83, 3, 4),
      _f(const Color(0xFFE2DCCA)),
    ); // tüy
  }

  _shadedArm(c, -15, anim.armL, cloakBase, v.skin);
  // Sağ el + yay — kavis ELDEN çıkar (kol ekseninde), havada durmaz
  _shadedArm(c, 15, anim.armR, cloakBase, v.skin, (arm) {
    if (handsBusy) return;
    final bow = Path()
      ..moveTo(1, -30)
      ..quadraticBezierTo(13, 0, 1, 30);
    arm.drawPath(bow, _s(_woodBrown, 3.0));
    arm.drawLine(
      const Offset(1, -30),
      const Offset(1, 30),
      _s(const Color(0xFFCFC3A8), 1.0),
    ); // kiriş
  });

  _shadedHead(c, v, time);

  // Kukuleta (cowl) — tepe + yüzü çerçeveleyen yanaklar + arkaya doğru kısa
  // sivri uç. Eski hâli üst üste kutulardan bir "baca" gibiydi.
  _shadedRect(c, const Rect.fromLTWH(-11, -99, 22, 12), cloakBase); // tepe
  _shadedRect(
    c,
    const Rect.fromLTWH(-12, -93, 4, 13),
    cloakBase,
  ); // sol yanak
  _shadedRect(c, const Rect.fromLTWH(8, -93, 4, 13), cloakBase); // sağ yanak
  _shadedRect(
    c,
    const Rect.fromLTWH(-14, -97, 4, 7),
    cloakBase,
  ); // arka sivri uç
  c.restore();
}

// ─── DEĞİRMENCİ / FIRINCI ─────────────────────────────────────────────────
/// Silüet imzası: UNLU BEYAZ önlük (köyde tek beyaz kütle) + omuzda un çuvalı
/// + bez başlık. Uzaktan bile "beyaz" olan tek meslek.
void _millerNpc(
  Canvas c,
  _Anim anim,
  NpcVisual v,
  double time, {
  bool handsBusy = false,
}) {
  final clothBase = _cloth(_kMillerCloth, v.clothingShift);
  final hoseBase = _cloth(const Color(0xFF5E584C), v.clothingShift * 0.4);
  const sack = Color(0xFFBFAE86);

  _shadow(c, anim);
  _shadedLeg(c, -6, anim.legL, hoseBase, _leatherDk, legLift: anim.legLiftL);
  _shadedLeg(c, 6, anim.legR, hoseBase, _leatherDk, legLift: anim.legLiftR);

  c.save();
  _applyTorsoTransform(c, anim);

  // İş gömleği
  _shadedTorso(c, const Rect.fromLTWH(-13, -68, 26, 32), clothBase);
  // UNLU BEYAZ önlük — göğüsten aşağı, imza kütle
  _shadedRect(c, const Rect.fromLTWH(-9, -62, 18, 26), _kFlourWhite);
  // Önlük askıları
  c.drawLine(
    const Offset(-7, -62),
    const Offset(-3, -68),
    _s(_kFlourWhite, 2.0),
  );
  c.drawLine(
    const Offset(7, -62),
    const Offset(3, -68),
    _s(_kFlourWhite, 2.0),
  );
  // Un lekeleri (önlükte + omuzda birkaç açık benek)
  for (final p in const [Offset(-5, -50), Offset(4, -44), Offset(-11, -64)]) {
    c.drawRect(Rect.fromLTWH(p.dx, p.dy, 2, 2), _f(const Color(0xFFF2EEE2)));
  }

  if (!handsBusy) {
    // Sol OMUZDA un çuvalı — gövdeye BİNDİRİLMİŞ (eski hâli 1px boşlukla
    // havada duruyordu) + omuz üstünden geçen kayış. Porter yükü varken bu
    // meslek prop'u gizlenir; iki ayrı çuval aynı gövdede belirmez.
    _shadedRect(c, const Rect.fromLTWH(-23, -80, 14, 17), sack);
    c.drawRect(
      const Rect.fromLTWH(-20, -82, 7, 3),
      _f(_leatherDk),
    ); // ağzı bağlı
    c.drawLine(
      const Offset(-12, -78),
      const Offset(-2, -70),
      _s(_leatherDk, 2.0),
    );
  }

  _shadedArm(c, -16, anim.armL, clothBase, v.skin);
  _shadedArm(c, 16, anim.armR, clothBase, v.skin);

  _shadedHead(c, v, time);

  // Bez başlık — yayvan, kaş üstünde (kutu değil)
  _shadedRect(c, const Rect.fromLTWH(-11, -95, 22, 5), _kFlourWhite);
  _shadedRect(c, const Rect.fromLTWH(-9, -102, 18, 7), _kFlourWhite);
  c.restore();
}

// ─── HANCI / MEYHANECİ ────────────────────────────────────────────────────
/// Silüet imzası: şarap kırmızısı yelek + beyaz önlük + elde KÖPÜKLÜ MAŞRAPA.
/// Köyün tek kırmızısı — hanın sıcaklığını taşır.
void _innkeeperNpc(
  Canvas c,
  _Anim anim,
  NpcVisual v,
  double time, {
  bool handsBusy = false,
}) {
  final shirtBase = _cloth(const Color(0xFFC8B9A0), v.clothingShift * 0.6);
  final vestBase = _cloth(_kInnkeeperWine, v.clothingShift);
  final hoseBase = _cloth(const Color(0xFF4A3A32), v.clothingShift * 0.4);

  _shadow(c, anim);
  _shadedLeg(c, -6, anim.legL, hoseBase, _leatherDk, legLift: anim.legLiftL);
  _shadedLeg(c, 6, anim.legR, hoseBase, _leatherDk, legLift: anim.legLiftR);

  c.save();
  _applyTorsoTransform(c, anim);

  // Krem gömlek (kollar sıvalı → geniş omuz)
  _shadedTorso(c, const Rect.fromLTWH(-13, -68, 26, 32), shirtBase);
  // Şarap kırmızısı yelek — ortada, iki yandan gömlek görünür
  _shadedRect(c, const Rect.fromLTWH(-9, -68, 18, 24), vestBase);
  // Yelek düğmeleri
  for (int i = 0; i < 3; i++) {
    c.drawRect(
      Rect.fromLTWH(-1, -64 + i * 6.0, 2, 2),
      _f(const Color(0xFFC8A042)),
    );
  }
  // Beyaz önlük (belden aşağı)
  _shadedRect(
    c,
    const Rect.fromLTWH(-11, -46, 22, 14),
    const Color(0xFFDDD6C4),
  );

  _shadedArm(c, -16, anim.armL, shirtBase, v.skin);
  // Sağ el + köpüklü maşrapa (tahta bardak + krem köpük)
  _shadedArm(c, 16, anim.armR, shirtBase, v.skin, (arm) {
    if (handsBusy) return;
    _shadedRect(
      arm,
      const Rect.fromLTWH(1, 14, 9, 11),
      const Color(0xFF7A5030),
    );
    // Kulp
    arm.drawRect(
      const Rect.fromLTWH(10, 17, 3, 5),
      _f(const Color(0xFF5A3A20)),
    );
    // Köpük
    _shadedRect(
      arm,
      const Rect.fromLTWH(1, 11, 9, 4),
      const Color(0xFFF0EAD8),
    );
  });

  _shadedHead(c, v, time);

  // Saç açık — başlık yok (hancı başı açık çalışır); yerine kulak arkası kalem
  // yerine küçük bir bez bandana: alnı saran ince şerit.
  _shadedRect(c, const Rect.fromLTWH(-10, -92, 20, 4), vestBase);
  c.restore();
}

// ─── MADENCI (idle, yeni — shaded + per-NPC görsel) ────────────────────────
void _minerNpc(Canvas c, _Anim anim, NpcVisual v, double time) {
  final shirtBase = _cloth(const Color(0xFF4A4840), v.clothingShift);
  final vestBase = _cloth(const Color(0xFF6A4A28), v.clothingShift * 0.6);
  final hoseBase = _cloth(const Color(0xFF3A3028), v.clothingShift * 0.4);

  _shadow(c, anim);
  _shadedLeg(c, -6, anim.legL, hoseBase, _leatherDk, legLift: anim.legLiftL);
  _shadedLeg(c, 6, anim.legR, hoseBase, _leatherDk, legLift: anim.legLiftR);

  c.save();
  _applyTorsoTransform(c, anim);

  // Gömlek
  _shadedTorso(c, const Rect.fromLTWH(-13, -68, 26, 32), shirtBase);
  // Deri yelek (gömleğin üstüne)
  _shadedRect(c, const Rect.fromLTWH(-10, -67, 20, 30), vestBase);
  // Yelek tokası
  c.drawRect(const Rect.fromLTWH(-2, -58, 4, 14), _f(_leatherDk));

  _shadedArm(c, -16, anim.armL, shirtBase, v.skin);
  _shadedArm(c, 16, anim.armR, shirtBase, v.skin);

  _shadedHead(c, v, time);

  // Madenci başlığı (kafayı kaplar)
  _shadedRect(
    c,
    const Rect.fromLTWH(-12, -96, 24, 6),
    const Color(0xFF2A2010),
  );
  _shadedRect(
    c,
    const Rect.fromLTWH(-8, -108, 16, 12),
    const Color(0xFF2A2010),
  );
  // Kask lambası
  c.drawRect(
    const Rect.fromLTWH(-3, -108, 6, 4),
    _f(const Color(0xFFFFDD44)),
  );
  c.drawRect(
    const Rect.fromLTWH(-3, -108, 6, 1),
    _f(const Color(0xFFFFEE88)),
  );
  c.restore();
}

// ─── BALIKÇI (idle, yeni — shaded + per-NPC görsel) ────────────────────────
void _fisherNpc(Canvas c, _Anim anim, NpcVisual v, double time) {
  final shirtBase = _cloth(const Color(0xFF5A7888), v.clothingShift);
  final vestBase = _cloth(const Color(0xFF2A3840), v.clothingShift * 0.5);
  final hoseBase = _cloth(const Color(0xFF3A5060), v.clothingShift * 0.4);
  const hatBrim = Color(0xFF4A3A20);
  const hatDome = Color(0xFF5A4A28);

  _shadow(c, anim);
  _shadedLeg(c, -6, anim.legL, hoseBase, _leatherDk, legLift: anim.legLiftL);
  _shadedLeg(c, 6, anim.legR, hoseBase, _leatherDk, legLift: anim.legLiftR);

  c.save();
  _applyTorsoTransform(c, anim);

  // Gömlek
  _shadedTorso(c, const Rect.fromLTWH(-12, -68, 24, 32), shirtBase);
  // Yelek
  _shadedRect(c, const Rect.fromLTWH(-9, -67, 18, 30), vestBase);

  _shadedArm(c, -15, anim.armL, shirtBase, v.skin);
  _shadedArm(c, 15, anim.armR, shirtBase, v.skin);

  _shadedHead(c, v, time);

  // Balıkçı şapkası — geniş brim + düz kubbe
  _shadedRect(c, const Rect.fromLTWH(-14, -98, 28, 6), hatBrim);
  _shadedRect(c, const Rect.fromLTWH(-8, -110, 16, 12), hatDome);
  c.restore();
}
