part of 'character_renderer.dart';

/// İŞÇİ ÇİZİMLERİ (eski kalem) — çiftçi/tüccar/demirci/muhafız/madenci/balıkçı idle + inşaatçı.

// ─── 1. ÇIFTÇI ────────────────────────────────────────────────────────────
void _farmer(
  Canvas c,
  _Anim anim, {
  bool carryingWater = false,
  NpcVisual? v,
  double time = 0,
}) {
  final tunic = v != null ? _cloth(_linen, v.clothingShift) : _linen;
  final hose = v != null
      ? _cloth(_woolBrown, v.clothingShift * 0.5)
      : _woolBrown;
  final hat = v != null ? _cloth(_straw, v.clothingShift * 0.4) : _straw;
  final skin = v?.skin ?? _skin1;
  _shadow(c, anim);
  _shadedLeg(c, -6, anim.legL, hose, _leatherDk, legLift: anim.legLiftL);
  _shadedLeg(c, 6, anim.legR, hose, _leatherDk, legLift: anim.legLiftR);
  c.save();
  _applyTorsoTransform(c, anim);
  _shadedTunic(c, tunic);
  _shadedArm(c, -15, anim.armL, tunic, skin);
  // Sulama turunda sağ elde su kovası; değilse boş el (idle/hasat).
  _shadedArm(
    c,
    15,
    anim.armR,
    tunic,
    skin,
    carryingWater ? ToolRenderer.drawWaterbucket : null,
  );
  if (v != null) {
    _shadedHead(c, v, time);
  } else {
    _head(c, skin);
  }
  // Hasır şapka (yassı brim + kule)
  _shadedRect(c, const Rect.fromLTWH(-17, -98, 34, 8), hat);
  _shadedRect(c, const Rect.fromLTWH(-7, -114, 14, 16), hat);
  c.restore();
}

// ─── 2. TÜCCAR ────────────────────────────────────────────────────────────
void _merchant(Canvas c, _Anim anim) {
  _shadow(c, anim);
  _leg(c, -6, anim.legL, _woolDark, _leatherDk);
  _leg(c, 6, anim.legR, _woolDark, _leatherDk);
  c.save();
  _applyTorsoTransform(c, anim);
  // Pelerin
  c.drawRect(
    const Rect.fromLTWH(-14, -68, 28, 32),
    _f(const Color(0xFF4A5030)),
  );
  c.drawRect(
    const Rect.fromLTWH(-14, -68, 28, 32),
    _s(const Color(0xFF2A3018)),
  );
  c.drawRect(const Rect.fromLTWH(-8, -42, 16, 6), _f(_linen));
  // Broş
  c.drawRect(const Rect.fromLTWH(-3, -66, 6, 6), _f(const Color(0xFFB0900A)));
  _arm(c, -16, anim.armL, const Color(0xFF4A5030));
  _arm(c, 16, anim.armR, const Color(0xFF4A5030));
  // Çanta
  c.drawRect(const Rect.fromLTWH(14, -50, 12, 14), _f(_leather));
  c.drawRect(const Rect.fromLTWH(14, -50, 12, 14), _s(_leatherDk));
  c.drawRect(const Rect.fromLTWH(14, -50, 12, 3), _f(_leatherDk));
  c.drawLine(
    const Offset(14, -52),
    const Offset(8, -62),
    _s(_leatherDk, 1.2),
  );
  _head(c, _skin1);
  // Capüşon
  c.drawRect(
    const Rect.fromLTWH(-11, -98, 22, 18),
    _f(const Color(0xFF4A5030)),
  );
  c.drawRect(
    const Rect.fromLTWH(-11, -98, 22, 18),
    _s(const Color(0xFF2A3018)),
  );
  c.drawRect(
    const Rect.fromLTWH(-10, -92, 20, 12),
    _f(const Color(0xFF3A4028)),
  );
  c.restore();
}

// ─── 3. DEMİRCİ ───────────────────────────────────────────────────────────
void _blacksmith(Canvas c, _Anim anim, {bool handsBusy = false}) {
  _shadow(c, anim);
  _leg(c, -6, anim.legL, const Color(0xFF3A3028), _leatherDk);
  _leg(c, 6, anim.legR, const Color(0xFF3A3028), _leatherDk);
  c.save();
  _applyTorsoTransform(c, anim);
  // Geniş tunik
  c.drawRect(
    const Rect.fromLTWH(-14, -68, 28, 32),
    _f(const Color(0xFF5A3818)),
  );
  c.drawRect(const Rect.fromLTWH(-14, -68, 28, 32), _s(_outline));
  // Önlük
  c.drawRect(const Rect.fromLTWH(-9, -66, 18, 30), _f(_leather));
  c.drawRect(const Rect.fromLTWH(-9, -66, 18, 30), _s(_leatherDk));
  // Askı
  c.drawLine(const Offset(-7, -66), const Offset(0, -76), _s(_leather, 2.5));
  c.drawLine(const Offset(7, -66), const Offset(0, -76), _s(_leather, 2.5));
  // Kollar (sıvanmış)
  _arm(c, -18, anim.armL, const Color(0xFF5A3818));
  // Sağ kol + çekiç (PNG, biraz büyük)
  _arm(
    c,
    18,
    anim.armR,
    const Color(0xFF5A3818),
    handsBusy ? null : (arm) => ToolRenderer.drawHammer(arm, scale: 1.15),
  );
  _head(c, _skin2, y: -82);
  // Deri kukuleta
  c.drawRect(const Rect.fromLTWH(-10, -100, 20, 18), _f(_leather));
  c.drawRect(const Rect.fromLTWH(-10, -100, 20, 18), _s(_leatherDk));
  c.restore();
}

// ─── 4. MUHAFIZ ───────────────────────────────────────────────────────────
void _guard(Canvas c, _Anim anim, {bool handsBusy = false}) {
  _shadow(c, anim);
  _leg(c, -6, anim.legL, const Color(0xFF504838), const Color(0xFF303028));
  _leg(c, 6, anim.legR, const Color(0xFF504838), const Color(0xFF303028));
  c.save();
  _applyTorsoTransform(c, anim);
  // Gambeson
  c.drawRect(
    const Rect.fromLTWH(-13, -68, 26, 32),
    _f(const Color(0xFFB8A878)),
  );
  c.drawRect(
    const Rect.fromLTWH(-13, -68, 26, 32),
    _s(const Color(0xFF706040)),
  );
  // Yatay gambeson çizgileri
  for (final v in [-64.0, -57.0, -50.0, -43.0]) {
    c.drawRect(Rect.fromLTWH(-12, v, 24, 1), _f(const Color(0xFF908060)));
  }
  // Omuz plakaları
  c.drawRect(const Rect.fromLTWH(-28, -74, 16, 10), _f(_leather));
  c.drawRect(const Rect.fromLTWH(-28, -74, 16, 10), _s(_leatherDk));
  c.drawRect(const Rect.fromLTWH(12, -74, 16, 10), _f(_leather));
  c.drawRect(const Rect.fromLTWH(12, -74, 16, 10), _s(_leatherDk));
  if (handsBusy) {
    _arm(c, -20, anim.armL, const Color(0xFFB8A878));
    _arm(c, 20, anim.armR, const Color(0xFFB8A878));
  } else {
    // Sol kol + kalkan
    _armWithShield(c, -20, anim.armL);
    // Sağ kol + mızrak
    _arm(c, 20, anim.armR, const Color(0xFFB8A878), (arm) {
      arm.drawRect(const Rect.fromLTWH(3, -40, 3, 80), _f(_woodBrown));
      // Mızrak ucu
      arm.drawRect(const Rect.fromLTWH(1, -52, 7, 12), _f(_ironGrey));
      arm.drawRect(const Rect.fromLTWH(1, -52, 7, 12), _s(_ironDk));
    });
  }
  _head(c, _skin1);
  // Demir miğfer
  c.drawRect(const Rect.fromLTWH(-11, -100, 22, 20), _f(_ironGrey));
  c.drawRect(const Rect.fromLTWH(-11, -100, 22, 20), _s(_ironDk));
  c.drawRect(
    const Rect.fromLTWH(-13, -92, 26, 4),
    _f(_ironGrey),
  ); // ağız bandı
  c.drawRect(
    const Rect.fromLTWH(-2, -92, 4, 10),
    _f(_ironDk),
  ); // burun parçası
  c.restore();
}

void _armWithShield(Canvas c, double shoulderX, double angle) {
  c.save();
  c.translate(shoulderX, -68);
  c.rotate(angle);
  c.drawRect(const Rect.fromLTWH(-4, 0, 8, 20), _f(const Color(0xFFB8A878)));
  // Kalkan (kare, yuvarlak değil)
  c.drawRect(
    const Rect.fromLTWH(-16, 4, 22, 22),
    _f(const Color(0xFF8B4513)),
  );
  c.drawRect(
    const Rect.fromLTWH(-16, 4, 22, 22),
    _s(const Color(0xFF4A2508), 1.5),
  );
  // Kalkan merkez
  c.drawRect(const Rect.fromLTWH(-8, 10, 8, 8), _f(_ironGrey));
  c.drawRect(const Rect.fromLTWH(-8, 10, 8, 8), _s(_ironDk));
  // Kalkan kenar çerçeve
  c.drawRect(const Rect.fromLTWH(-16, 4, 22, 22), _s(_ironGrey, 1.5));
  c.restore();
}

// ─── 7. MADENCİ ───────────────────────────────────────────────────────────
void _miner(Canvas c, _Anim anim) {
  _shadow(c, anim);
  _leg(c, -6, anim.legL, const Color(0xFF3A3028), _leatherDk);
  _leg(c, 6, anim.legR, const Color(0xFF3A3028), _leatherDk);
  c.save();
  _applyTorsoTransform(c, anim);

  // Koyu gri iş gömleği
  const shirtCol = Color(0xFF4A4840);
  const shirtDark = Color(0xFF2A2820);
  c.drawRect(const Rect.fromLTWH(-13, -68, 26, 32), _f(shirtCol));
  c.drawRect(const Rect.fromLTWH(-13, -68, 26, 32), _s(shirtDark));

  // Deri yelek
  c.drawRect(
    const Rect.fromLTWH(-10, -67, 20, 30),
    _f(const Color(0xFF6A4A28)),
  );
  c.drawRect(const Rect.fromLTWH(-10, -67, 20, 30), _s(_leatherDk));
  // Yelek tokası
  c.drawRect(const Rect.fromLTWH(-2, -58, 4, 14), _f(_leatherDk));

  // İdle pozda kazma elinde değil — aktif madenci ayrı (drawMiner).
  _arm(c, -16, anim.armL, shirtCol);
  _arm(c, 16, anim.armR, shirtCol);

  _head(c, _skin2);

  // Madenci başlığı (flat brim + kısa kubbe)
  c.drawRect(
    const Rect.fromLTWH(-12, -96, 24, 6),
    _f(const Color(0xFF2A2010)),
  );
  c.drawRect(
    const Rect.fromLTWH(-12, -96, 24, 6),
    _s(const Color(0xFF1A1008)),
  );
  c.drawRect(
    const Rect.fromLTWH(-8, -108, 16, 12),
    _f(const Color(0xFF2A2010)),
  );
  c.drawRect(
    const Rect.fromLTWH(-8, -108, 16, 12),
    _s(const Color(0xFF1A1008)),
  );
  // Kask lambası
  c.drawRect(
    const Rect.fromLTWH(-3, -108, 6, 4),
    _f(const Color(0xFFFFDD44)),
  );

  c.restore();
}

// ─── 9. BALIKÇI (idle draw — VillagerType.fisher için) ────────────────────
void _fisherIdle(Canvas c, _Anim anim) {
  _shadow(c, anim);
  _leg(c, -6, anim.legL, const Color(0xFF3A5060), _leatherDk);
  _leg(c, 6, anim.legR, const Color(0xFF3A5060), _leatherDk);
  c.save();
  _applyTorsoTransform(c, anim);
  // Açık mavi balıkçı gömleği
  c.drawRect(
    const Rect.fromLTWH(-12, -68, 24, 32),
    _f(const Color(0xFF5A7888)),
  );
  c.drawRect(
    const Rect.fromLTWH(-12, -68, 24, 32),
    _s(const Color(0xFF3A5060)),
  );
  // Yelek (koyu)
  c.drawRect(
    const Rect.fromLTWH(-9, -67, 18, 30),
    _f(const Color(0xFF2A3840)),
  );
  c.drawRect(
    const Rect.fromLTWH(-9, -67, 18, 30),
    _s(const Color(0xFF1A2830)),
  );
  // İdle pozda olta elinde değil — aktif balıkçı ayrı (drawFisher).
  _arm(c, -15, anim.armL, const Color(0xFF5A7888));
  _arm(c, 15, anim.armR, const Color(0xFF5A7888));
  _head(c, _skin1);
  // Balıkçı şapkası (geniş kenarlı, düz)
  c.drawRect(
    const Rect.fromLTWH(-14, -98, 28, 6),
    _f(const Color(0xFF4A3A20)),
  );
  c.drawRect(
    const Rect.fromLTWH(-14, -98, 28, 6),
    _s(const Color(0xFF2A1A08)),
  );
  c.drawRect(
    const Rect.fromLTWH(-8, -110, 16, 12),
    _f(const Color(0xFF5A4A28)),
  );
  c.drawRect(
    const Rect.fromLTWH(-8, -110, 16, 12),
    _s(const Color(0xFF2A1A08)),
  );
  c.restore();
}

// ─── 11. İNŞAATÇI ──────────────────────────────────────────────────────────
/// İnşaatçı — usta marangoz/duvarcı. Diğer meslekler gibi SHADED sistemde
/// (_shadedRect/_shadedArm/_shadedLeg): hacimli kumaş, görünür eller, adım
/// kaldırma. Silüet imzası: siperlikli bez kasket + çapraz askılı deri iş
/// önlüğü + alet kemeri (asılı keski) + elde çekiç.
void _builder(
  Canvas c,
  _Anim anim, {
  bool working = false,
  NpcVisual? v,
  double time = 0,
}) {
  final tunicBase = v != null
      ? _cloth(const Color(0xFF9A7840), v.clothingShift)
      : const Color(0xFF9A7840);
  final hoseBase = v != null
      ? _cloth(_woolBrown, v.clothingShift * 0.5)
      : _woolBrown;
  // Terracotta kasket — bej tunikte kaybolan eski bereden farklı, siluet imzası.
  final capBase = v != null
      ? _cloth(const Color(0xFF9A4A30), v.clothingShift * 0.5)
      : const Color(0xFF9A4A30);
  final skin = v?.skin ?? _skin1;

  _shadow(c, anim);
  _shadedLeg(c, -6, anim.legL, hoseBase, _leatherDk, legLift: anim.legLiftL);
  _shadedLeg(c, 6, anim.legR, hoseBase, _leatherDk, legLift: anim.legLiftR);

  c.save();
  _applyTorsoTransform(c, anim);

  // Çalışma tuniği
  _shadedTorso(c, const Rect.fromLTWH(-13, -68, 26, 32), tunicBase);
  // Deri iş önlüğü (göğüsten aşağı)
  _shadedRect(c, const Rect.fromLTWH(-9, -64, 18, 28), _leather);
  // Çapraz askılar — önlüğü omuza bağlar (demircinin V'sinden ayrışır)
  c.drawLine(
    const Offset(-7, -64),
    const Offset(2, -76),
    _s(_leatherDk, 2.2),
  );
  c.drawLine(
    const Offset(7, -64),
    const Offset(-2, -76),
    _s(_leatherDk, 2.2),
  );
  // Alet kemeri + demir toka
  _shadedRect(c, const Rect.fromLTWH(-13, -46, 26, 5), _leatherDk);
  c.drawRect(const Rect.fromLTWH(-2, -46, 4, 5), _f(_ironGrey));
  // Kemerde asılı keski (sap + ağız) — "alet taşıyan usta" detayı
  c.drawRect(const Rect.fromLTWH(8, -44, 3, 6), _f(_woodBrown));
  c.drawRect(const Rect.fromLTWH(8, -38, 3, 4), _f(_ironGrey));

  _shadedArm(c, -16, anim.armL, tunicBase, skin);
  // Sağ kol + çekiç (PNG) — artık el de görünür
  _shadedArm(c, 16, anim.armR, tunicBase, skin, ToolRenderer.drawHammer);

  if (v != null) {
    _shadedHead(c, v, time);
  } else {
    _head(c, skin);
  }

  // Bez kasket — kısa deri siperlik + yumuşak kubbe. Eski hata: 18px'lik düz
  // kutu −98..−80 arası kafayı yutup gözleri kapatıyordu; artık kaş üstünde.
  _shadedRect(
    c,
    const Rect.fromLTWH(-13, -96, 26, 5),
    _leatherDk,
  ); // siperlik
  _shadedRect(c, const Rect.fromLTWH(-10, -106, 20, 11), capBase); // kubbe
  c.restore();
}
