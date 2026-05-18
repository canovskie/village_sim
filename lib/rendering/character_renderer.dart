import 'dart:math';
import 'package:flutter/material.dart';
import '../characters/villager_type.dart';
import '../characters/npc_visual.dart';
import 'tool_renderer.dart';

// ─── ANİMASYON ────────────────────────────────────────────────────────────────

class _Anim {
  final double legL, legR, armL, armR, bob;
  /// Gövde yatay ağırlık değişimi (idle slow sway).
  final double sway;
  /// Gövde + kafa lean (öne eğilme, walking).  Radyan.
  final double lean;
  const _Anim(this.legL, this.legR, this.armL, this.armR, this.bob,
              {this.sway = 0, this.lean = 0});

  /// Karakter idle/walking/carrying için kol-bacak-bob salınımı.
  ///
  /// [moveIntensity] 0..1 sürekli — walking ↔ idle smooth blend.
  /// 0=tam idle, 1=tam walking.  Aradaki değerler doğrusal karıştırılır →
  /// donuk anlık geçiş yerine akıcı.
  static _Anim compute(double phase, double moveIntensity,
      {bool carrying = false}) {
    final m = moveIntensity.clamp(0.0, 1.0);

    if (carrying) {
      final wobble = sin(phase) * (0.02 + m * 0.04);
      final bobWalk = (cos(phase * 2) - 1) * 1.6;
      return _Anim(
        sin(phase) * (0.04 + m * 0.30),
        -sin(phase) * (0.04 + m * 0.30),
        0.65 + wobble,
        -0.65 - wobble,
        bobWalk * m,
        lean: m * 0.05,
      );
    }

    // ── Idle parametreleri ────────────────────────────────────────────────
    final sIdle      = sin(phase) * 0.10;
    final breathIdle = -sin(phase * 0.5).abs() * 0.6;
    // Yavaş yan ağırlık değişimi — 0.045 Hz, ±1.6 px (idle "yaşıyor" hissi)
    final idleSway   = sin(phase * 0.28) * 1.6;

    // ── Walking parametreleri ─────────────────────────────────────────────
    final sWalk    = sin(phase);
    // Bob: cosine eğrisi — sharp V-peak yerine yumuşak dalga
    final bobWalk  = (cos(phase * 2) - 1) * 1.8;
    // Walking lean: gövde öne eğilir.  flipX scale(-1,1) ile aynalanır;
    // her iki yönde de görsel olarak hareket yönüne lean verir.
    const leanWalk = 0.07;

    // ── Blend ──────────────────────────────────────────────────────────────
    return _Anim(
      sIdle        + (sWalk * 0.42 - sIdle) * m,           // legL
      -sIdle       + (-sWalk * 0.42 + sIdle) * m,          // legR
      -sIdle * 0.5 + (-sWalk * 0.30 + sIdle * 0.5) * m,    // armL
       sIdle * 0.5 + ( sWalk * 0.30 - sIdle * 0.5) * m,    // armR
      breathIdle   + (bobWalk - breathIdle) * m,            // bob
      sway: idleSway * (1.0 - m),                            // idle only
      lean: leanWalk * m,                                    // walking only
    );
  }
}

// ─── RENDERER ─────────────────────────────────────────────────────────────────
// Pixel-art tarzı karakterler: yalnızca dikdörtgenler, isAntiAlias=false.
// Ayaklar canvas orijininde (y=0). Çağıran save/translate/scale/restore yapar.

class CharacterRenderer {
  static void draw(Canvas canvas, VillagerType type, {
    bool flipX = false,
    double walkPhase = 0,
    double moveIntensity = 0.0,
    bool carrying = false,
    bool torch = false,
    NpcVisual? visual,
    double time = 0,
  }) {
    canvas.save();
    if (flipX) canvas.scale(-1, 1);
    final anim = _Anim.compute(walkPhase, moveIntensity, carrying: carrying);
    switch (type) {
      case VillagerType.farmer:
        visual != null ? _farmerNpc(canvas, anim, visual, time)
                       : _farmer(canvas, anim);
      case VillagerType.merchant:   _merchant(canvas, anim);
      case VillagerType.blacksmith: _blacksmith(canvas, anim);
      case VillagerType.guard:      _guard(canvas, anim);
      case VillagerType.mage:       _mage(canvas, anim);
      case VillagerType.miner:      _miner(canvas, anim);
      case VillagerType.fisher:     _fisherIdle(canvas, anim);
    }

    // Gece yürüyüşünde torch — sağ kola yapıştırılır, kol açısıyla sallanır.
    // shoulderX 15: ortalama (farmer/merchant/miner/fisher 15-16; daha büyük
    // tipler 18-20 ama küçük sapma kabul edilebilir).
    if (torch) {
      canvas.save();
      canvas.translate(15, -68);  // sağ omuz pivotu
      canvas.rotate(anim.armR);   // kol açısı
      ToolRenderer.drawTorch(canvas);
      canvas.restore();
    }
    canvas.restore();
  }

  /// Yatay yatmış uyku pozu — yastıkta kafa, vücut battaniyenin üstünde,
  /// hafif breath salınımı.  Origin: karakterin ayak konumu (canvas zaten
  /// translate edilmiş olmalı).  Karakter sola doğru uzanır (kafa solda).
  static void drawSleeping(Canvas c, VillagerType type, {
    double walkPhase = 0,
    bool flipX = false,
  }) {
    c.save();
    if (flipX) c.scale(-1, 1);

    final breath = sin(walkPhase * 0.6) * 0.6;
    final tunicCol = _sleepTunicColor(type);
    final skinCol  = _sleepSkinColor(type);

    // Battaniye / minder
    c.drawRect(const Rect.fromLTWH(-26, -3, 38, 5),
        _f(const Color(0xFF3A2818)));
    c.drawRect(const Rect.fromLTWH(-26, -3, 38, 5),
        _s(const Color(0xFF1A0E08)));

    // Yastık (sol tarafta, kafanın altında)
    c.drawRect(const Rect.fromLTWH(-32, -10, 14, 6), _f(_linen));
    c.drawRect(const Rect.fromLTWH(-32, -10, 14, 6), _s(_outline));

    // Vücut (yatay tunic — gövde + üst bacaklar tek blok)
    c.drawRect(Rect.fromLTWH(-20, -9 + breath, 32, 8), _f(tunicCol));
    c.drawRect(Rect.fromLTWH(-20, -9 + breath, 32, 8), _s(_outline));

    // Battaniye üzerine çekilmiş kısım (tunic alt kısmı koyulaşır)
    c.drawRect(Rect.fromLTWH(-2, -9 + breath, 14, 8),
        _f(Color.alphaBlend(_outline.withValues(alpha: 0.3), tunicCol)));

    // Göğüsteki kollar — küçük şerit
    c.drawRect(Rect.fromLTWH(-10, -8 + breath, 14, 3), _f(tunicCol));
    c.drawRect(Rect.fromLTWH(-10, -8 + breath, 14, 3), _s(_outline));

    // Kafa (yastıkta — breath kafayı az hareket ettirir)
    final headDy = breath * 0.5;
    c.drawRect(Rect.fromLTWH(-32, -16 + headDy, 14, 12), _f(skinCol));
    c.drawRect(Rect.fromLTWH(-32, -16 + headDy, 14, 12), _s(_outline));

    // Kapalı göz (yatay çizgi)
    c.drawLine(
      Offset(-27, -11 + headDy),
      Offset(-23, -11 + headDy),
      _s(_outline, 1.2),
    );

    c.restore();
  }

  /// drawSleeping için type-bazlı tunic rengi.
  static Color _sleepTunicColor(VillagerType type) => switch (type) {
        VillagerType.farmer     => _linen,
        VillagerType.merchant   => const Color(0xFF4A5030),
        VillagerType.blacksmith => const Color(0xFF5A3818),
        VillagerType.guard      => const Color(0xFFB8A878),
        VillagerType.mage       => const Color(0xFF2A3040),
        VillagerType.miner      => const Color(0xFF4A4840),
        VillagerType.fisher     => const Color(0xFF5A7888),
      };

  static Color _sleepSkinColor(VillagerType type) =>
      (type == VillagerType.blacksmith || type == VillagerType.miner)
          ? _skin2
          : _skin1;

  static void drawFarmer(Canvas canvas, {
    bool   flipX         = false,
    double walkPhase     = 0,
    double moveIntensity = 0.0,
    bool   harvesting    = false,
    double harvestPhase  = 0,
  }) {
    canvas.save();
    if (flipX) canvas.scale(-1, 1);

    final _Anim anim;
    if (harvesting) {
      final t = harvestPhase / (2 * pi);
      final double swing;
      if (t < 0.45) {
        swing = sin(t / 0.45 * pi * 0.5) * 1.05;
      } else {
        swing = 1.05 - ((t - 0.45) / 0.55) * 1.25;
      }
      final s = flipX ? -swing : swing;
      final bob = (swing / 1.05).clamp(0.0, 1.0) * 3.5;
      anim = _Anim(-s * 0.15, s * 0.08, -s * 0.20, s, -bob);
    } else {
      anim = _Anim.compute(walkPhase, moveIntensity);
    }

    _farmer(canvas, anim);
    canvas.restore();
  }

  static void drawBuilder(Canvas canvas, {
    bool flipX = false,
    double walkPhase = 0,
    double moveIntensity = 0.0,
    bool working = false,
  }) {
    canvas.save();
    if (flipX) canvas.scale(-1, 1);
    final _Anim anim;
    if (working) {
      final s = sin(walkPhase);
      anim = _Anim(0, 0, s * 0.10, s * 0.52, 0);
    } else {
      anim = _Anim.compute(walkPhase, moveIntensity);
    }
    _builder(canvas, anim, working: working);
    canvas.restore();
  }

  // ─── RENK PALETİ ──────────────────────────────────────────────────────────
  static const _skin1     = Color(0xFFFFCB9A);
  static const _skin2     = Color(0xFFD4956A);
  static const _linen     = Color(0xFFD4C090);
  static const _woolBrown = Color(0xFF6A4A28);
  static const _woolDark  = Color(0xFF3E2A10);
  static const _leather   = Color(0xFF8A6040);
  static const _leatherDk = Color(0xFF4A2A10);
  static const _straw     = Color(0xFFC8A042);
  static const _ironGrey  = Color(0xFF8A8880);
  static const _ironDk    = Color(0xFF484440);
  static const _woodBrown = Color(0xFF7A5030);
  static const _outline   = Color(0xFF2A1A08);

  // ─── PAINT YARDIMCILARI ───────────────────────────────────────────────────
  static Paint _f(Color c) =>
      Paint()..color = c..style = PaintingStyle.fill..isAntiAlias = false;
  static Paint _s(Color c, [double w = 1.0]) =>
      Paint()..color = c..style = PaintingStyle.stroke..strokeWidth = w
             ..strokeJoin = StrokeJoin.miter..strokeCap = StrokeCap.square
             ..isAntiAlias = false;

  // ─── ORTAK PARÇALAR ───────────────────────────────────────────────────────

  static void _shadow(Canvas c) {
    c.drawRect(const Rect.fromLTWH(-11, -3, 22, 5),
        Paint()..color = const Color(0x30000000)..isAntiAlias = false);
  }

  /// Gövde transform — bacaklar ve gölge yere sabit kalır, üst gövde
  /// (torso + kol + kafa) sway (yan), lean (öne eğilme), bob (dikey) uygular.
  /// Çağırılan kod c.save() yapmış olmalı; restore yine kendi sorumluluğunda.
  static void _applyTorsoTransform(Canvas c, _Anim anim) {
    if (anim.sway != 0) c.translate(anim.sway, 0);
    if (anim.lean != 0) {
      c.translate(0, -36);
      c.rotate(anim.lean);
      c.translate(0, 36);
    }
    if (anim.bob != 0) c.translate(0, anim.bob);
  }

  /// Kare kafa, piksel göz ve ağız.
  static void _head(Canvas c, Color skin, {double y = -80}) {
    c.drawRect(Rect.fromLTWH(-9, y - 10, 18, 20), _f(skin));
    c.drawRect(Rect.fromLTWH(-9, y - 10, 18, 20), _s(_outline));
    // Gözler
    c.drawRect(Rect.fromLTWH(-6, y - 4,  3, 3), _f(_outline));
    c.drawRect(Rect.fromLTWH( 3, y - 4,  3, 3), _f(_outline));
    // Ağız
    c.drawRect(Rect.fromLTWH(-4, y + 4,  8, 2), _f(_outline));
  }

  /// Animasyonlu bacak: hip pivot (hipX, −36).
  static void _leg(Canvas c, double hipX, double angle, Color hose, Color boot) {
    c.save();
    c.translate(hipX, -36);
    c.rotate(angle);
    c.drawRect(const Rect.fromLTWH(-4, 0, 8, 22), _f(hose));
    c.drawRect(const Rect.fromLTWH(-5, 19, 10, 7), _f(boot));
    c.restore();
  }

  /// Animasyonlu kol: shoulder pivot (shoulderX, −68).
  static void _arm(Canvas c, double shoulderX, double angle, Color col,
      [void Function(Canvas)? item]) {
    c.save();
    c.translate(shoulderX, -68);
    c.rotate(angle);
    c.drawRect(const Rect.fromLTWH(-4, 0, 8, 20), _f(col));
    item?.call(c);
    c.restore();
  }

  /// Tunik gövde + kemer.
  static void _tunic(Canvas c, Color col, Color shade) {
    c.drawRect(const Rect.fromLTWH(-12, -68, 24, 32), _f(col));
    c.drawRect(const Rect.fromLTWH(-12, -68, 24, 32), _s(shade));
    // Kemer
    c.drawRect(const Rect.fromLTWH(-12, -50, 24, 5), _f(_leather));
    c.drawRect(const Rect.fromLTWH(-12, -50, 24, 5), _s(_leatherDk));
    // Kemer tokası
    c.drawRect(const Rect.fromLTWH(-3, -50, 6, 5), _f(_leatherDk));
  }

  // ─── 1. ÇIFTÇI ────────────────────────────────────────────────────────────
  static void _farmer(Canvas c, _Anim anim) {
    _shadow(c);
    _leg(c, -6, anim.legL, _woolBrown, _leatherDk);
    _leg(c,  6, anim.legR, _woolBrown, _leatherDk);
    c.save();
    _applyTorsoTransform(c, anim);
    _tunic(c, _linen, _woolBrown);
    _arm(c, -15, anim.armL, _linen);
    // İdle pozda alet elinde değil — aktif çiftçi ayrı (drawFarmer).
    _arm(c, 15, anim.armR, _linen);
    _head(c, _skin1);
    // Hasır şapka (yassı brim + kule)
    c.drawRect(const Rect.fromLTWH(-17, -98, 34, 8), _f(_straw));
    c.drawRect(const Rect.fromLTWH(-17, -98, 34, 8), _s(const Color(0xFF8A6820)));
    c.drawRect(const Rect.fromLTWH(-7,  -114, 14, 16), _f(_straw));
    c.drawRect(const Rect.fromLTWH(-7,  -114, 14, 16), _s(const Color(0xFF8A6820)));
    c.restore();
  }

  // ─── 2. TÜCCAR ────────────────────────────────────────────────────────────
  static void _merchant(Canvas c, _Anim anim) {
    _shadow(c);
    _leg(c, -6, anim.legL, _woolDark, _leatherDk);
    _leg(c,  6, anim.legR, _woolDark, _leatherDk);
    c.save();
    _applyTorsoTransform(c, anim);
    // Pelerin
    c.drawRect(const Rect.fromLTWH(-14, -68, 28, 32), _f(const Color(0xFF4A5030)));
    c.drawRect(const Rect.fromLTWH(-14, -68, 28, 32), _s(const Color(0xFF2A3018)));
    c.drawRect(const Rect.fromLTWH(-8, -42, 16, 6),   _f(_linen));
    // Broş
    c.drawRect(const Rect.fromLTWH(-3, -66, 6, 6), _f(const Color(0xFFB0900A)));
    _arm(c, -16, anim.armL, const Color(0xFF4A5030));
    _arm(c,  16, anim.armR, const Color(0xFF4A5030));
    // Çanta
    c.drawRect(const Rect.fromLTWH(14, -50, 12, 14), _f(_leather));
    c.drawRect(const Rect.fromLTWH(14, -50, 12, 14), _s(_leatherDk));
    c.drawRect(const Rect.fromLTWH(14, -50, 12, 3),  _f(_leatherDk));
    c.drawLine(const Offset(14, -52), const Offset(8,  -62), _s(_leatherDk, 1.2));
    _head(c, _skin1);
    // Capüşon
    c.drawRect(const Rect.fromLTWH(-11, -98, 22, 18), _f(const Color(0xFF4A5030)));
    c.drawRect(const Rect.fromLTWH(-11, -98, 22, 18), _s(const Color(0xFF2A3018)));
    c.drawRect(const Rect.fromLTWH(-10, -92, 20, 12), _f(const Color(0xFF3A4028)));
    c.restore();
  }

  // ─── 3. DEMİRCİ ───────────────────────────────────────────────────────────
  static void _blacksmith(Canvas c, _Anim anim) {
    _shadow(c);
    _leg(c, -6, anim.legL, const Color(0xFF3A3028), _leatherDk);
    _leg(c,  6, anim.legR, const Color(0xFF3A3028), _leatherDk);
    c.save();
    _applyTorsoTransform(c, anim);
    // Geniş tunik
    c.drawRect(const Rect.fromLTWH(-14, -68, 28, 32), _f(const Color(0xFF5A3818)));
    c.drawRect(const Rect.fromLTWH(-14, -68, 28, 32), _s(_outline));
    // Önlük
    c.drawRect(const Rect.fromLTWH(-9, -66, 18, 30), _f(_leather));
    c.drawRect(const Rect.fromLTWH(-9, -66, 18, 30), _s(_leatherDk));
    // Askı
    c.drawLine(const Offset(-7, -66), const Offset(0, -76), _s(_leather, 2.5));
    c.drawLine(const Offset( 7, -66), const Offset(0, -76), _s(_leather, 2.5));
    // Kollar (sıvanmış)
    _arm(c, -18, anim.armL, const Color(0xFF5A3818));
    // Sağ kol + çekiç (PNG, biraz büyük)
    _arm(c,  18, anim.armR, const Color(0xFF5A3818),
        (arm) => ToolRenderer.drawHammer(arm, scale: 1.15));
    _head(c, _skin2, y: -82);
    // Deri kukuleta
    c.drawRect(const Rect.fromLTWH(-10, -100, 20, 18), _f(_leather));
    c.drawRect(const Rect.fromLTWH(-10, -100, 20, 18), _s(_leatherDk));
    c.restore();
  }

  // ─── 4. MUHAFIZ ───────────────────────────────────────────────────────────
  static void _guard(Canvas c, _Anim anim) {
    _shadow(c);
    _leg(c, -6, anim.legL, const Color(0xFF504838), const Color(0xFF303028));
    _leg(c,  6, anim.legR, const Color(0xFF504838), const Color(0xFF303028));
    c.save();
    _applyTorsoTransform(c, anim);
    // Gambeson
    c.drawRect(const Rect.fromLTWH(-13, -68, 26, 32), _f(const Color(0xFFB8A878)));
    c.drawRect(const Rect.fromLTWH(-13, -68, 26, 32), _s(const Color(0xFF706040)));
    // Yatay gambeson çizgileri
    for (final v in [-64.0, -57.0, -50.0, -43.0]) {
      c.drawRect(Rect.fromLTWH(-12, v, 24, 1), _f(const Color(0xFF908060)));
    }
    // Omuz plakaları
    c.drawRect(const Rect.fromLTWH(-28, -74, 16, 10), _f(_leather));
    c.drawRect(const Rect.fromLTWH(-28, -74, 16, 10), _s(_leatherDk));
    c.drawRect(const Rect.fromLTWH( 12, -74, 16, 10), _f(_leather));
    c.drawRect(const Rect.fromLTWH( 12, -74, 16, 10), _s(_leatherDk));
    // Sol kol + kalkan
    _armWithShield(c, -20, anim.armL);
    // Sağ kol + mızrak
    _arm(c, 20, anim.armR, const Color(0xFFB8A878), (arm) {
      arm.drawRect(const Rect.fromLTWH(3, -40, 3, 80), _f(_woodBrown));
      // Mızrak ucu
      arm.drawRect(const Rect.fromLTWH(1, -52, 7, 12), _f(_ironGrey));
      arm.drawRect(const Rect.fromLTWH(1, -52, 7, 12), _s(_ironDk));
    });
    _head(c, _skin1);
    // Demir miğfer
    c.drawRect(const Rect.fromLTWH(-11, -100, 22, 20), _f(_ironGrey));
    c.drawRect(const Rect.fromLTWH(-11, -100, 22, 20), _s(_ironDk));
    c.drawRect(const Rect.fromLTWH(-13,  -92, 26,  4), _f(_ironGrey)); // ağız bandı
    c.drawRect(const Rect.fromLTWH( -2,  -92,  4, 10), _f(_ironDk));   // burun parçası
    c.restore();
  }

  static void _armWithShield(Canvas c, double shoulderX, double angle) {
    c.save();
    c.translate(shoulderX, -68);
    c.rotate(angle);
    c.drawRect(const Rect.fromLTWH(-4, 0, 8, 20), _f(const Color(0xFFB8A878)));
    // Kalkan (kare, yuvarlak değil)
    c.drawRect(const Rect.fromLTWH(-16, 4, 22, 22), _f(const Color(0xFF8B4513)));
    c.drawRect(const Rect.fromLTWH(-16, 4, 22, 22), _s(const Color(0xFF4A2508), 1.5));
    // Kalkan merkez
    c.drawRect(const Rect.fromLTWH(-8, 10, 8, 8),  _f(_ironGrey));
    c.drawRect(const Rect.fromLTWH(-8, 10, 8, 8),  _s(_ironDk));
    // Kalkan kenar çerçeve
    c.drawRect(const Rect.fromLTWH(-16, 4, 22, 22), _s(_ironGrey, 1.5));
    c.restore();
  }

  // ─── 5. BÜYÜCÜ ────────────────────────────────────────────────────────────
  static void _mage(Canvas c, _Anim anim) {
    _shadow(c);
    _leg(c, -5, anim.legL * 0.5, const Color(0xFF2A3040), _leatherDk);
    _leg(c,  5, anim.legR * 0.5, const Color(0xFF2A3040), _leatherDk);
    c.save();
    _applyTorsoTransform(c, anim);
    // Uzun kaftan
    c.drawRect(const Rect.fromLTWH(-12, -68, 24, 62), _f(const Color(0xFF2A3040)));
    c.drawRect(const Rect.fromLTWH(-12, -68, 24, 62), _s(const Color(0xFF1A2030)));
    // Altın bordür
    c.drawRect(const Rect.fromLTWH(-11, -52, 22, 3), _f(const Color(0xFFC8A042)));
    // Ayak uçları
    c.drawRect(const Rect.fromLTWH(-8, -8, 5, 6), _f(_leatherDk));
    c.drawRect(const Rect.fromLTWH( 3, -8, 5, 6), _f(_leatherDk));
    // Geniş kollar
    _arm(c, -18, anim.armL, const Color(0xFF2A3040));
    // Sağ kol + asa
    _arm(c, 18, anim.armR, const Color(0xFF2A3040), (arm) {
      arm.drawRect(const Rect.fromLTWH(4, -44, 3, 82), _f(_woodBrown));
      arm.drawRect(const Rect.fromLTWH(2, -48, 7, 6),  _f(_woodBrown));
      // Rün işaretleri
      for (final y in [-32.0, -20.0, -8.0]) {
        arm.drawRect(Rect.fromLTWH(3, y, 8, 2), _f(const Color(0xFFC8A042)));
      }
    });
    // Tomar
    c.drawRect(const Rect.fromLTWH(-20, -50, 9, 12), _f(_linen));
    c.drawRect(const Rect.fromLTWH(-20, -50, 9,  3), _f(_leatherDk));
    _head(c, const Color(0xFFE8C9A0));
    // Kapüşon + sivri şapka
    c.drawRect(const Rect.fromLTWH(-12, -96, 24, 16), _f(const Color(0xFF2A3040)));
    c.drawRect(const Rect.fromLTWH(-12, -96, 24, 16), _s(const Color(0xFF1A2030)));
    // Sivri tepeli şapka (üçgen → iki rect ile temsil)
    c.drawRect(const Rect.fromLTWH(-8, -112, 16, 16), _f(const Color(0xFF2A3040)));
    c.drawRect(const Rect.fromLTWH(-4, -124,  8, 12), _f(const Color(0xFF2A3040)));
    // Beyaz sakal
    c.drawRect(const Rect.fromLTWH(-6, -76, 12, 14), _f(Colors.white));
    c.restore();
  }

  // ─── 7. MADENCİ ───────────────────────────────────────────────────────────
  static void _miner(Canvas c, _Anim anim) {
    _shadow(c);
    _leg(c, -6, anim.legL, const Color(0xFF3A3028), _leatherDk);
    _leg(c,  6, anim.legR, const Color(0xFF3A3028), _leatherDk);
    c.save();
    _applyTorsoTransform(c, anim);

    // Koyu gri iş gömleği
    const shirtCol  = Color(0xFF4A4840);
    const shirtDark = Color(0xFF2A2820);
    c.drawRect(const Rect.fromLTWH(-13, -68, 26, 32), _f(shirtCol));
    c.drawRect(const Rect.fromLTWH(-13, -68, 26, 32), _s(shirtDark));

    // Deri yelek
    c.drawRect(const Rect.fromLTWH(-10, -67, 20, 30), _f(const Color(0xFF6A4A28)));
    c.drawRect(const Rect.fromLTWH(-10, -67, 20, 30), _s(_leatherDk));
    // Yelek tokası
    c.drawRect(const Rect.fromLTWH(-2, -58, 4, 14), _f(_leatherDk));

    // İdle pozda kazma elinde değil — aktif madenci ayrı (drawMiner).
    _arm(c, -16, anim.armL, shirtCol);
    _arm(c,  16, anim.armR, shirtCol);

    _head(c, _skin2);

    // Madenci başlığı (flat brim + kısa kubbe)
    c.drawRect(const Rect.fromLTWH(-12, -96, 24,  6), _f(const Color(0xFF2A2010)));
    c.drawRect(const Rect.fromLTWH(-12, -96, 24,  6), _s(const Color(0xFF1A1008)));
    c.drawRect(const Rect.fromLTWH( -8, -108, 16, 12), _f(const Color(0xFF2A2010)));
    c.drawRect(const Rect.fromLTWH( -8, -108, 16, 12), _s(const Color(0xFF1A1008)));
    // Kask lambası
    c.drawRect(const Rect.fromLTWH( -3, -108,  6,  4), _f(const Color(0xFFFFDD44)));

    c.restore();
  }

  // ─── 8. MADENCİ (aktif, kazma animasyonlu) ────────────────────────────────

  static void drawMiner(Canvas canvas, {
    bool flipX = false,
    double walkPhase = 0,
    double moveIntensity = 0.0,
    bool mining = false,
    double chopPhase = 0,
  }) {
    canvas.save();
    if (flipX) canvas.scale(-1, 1);

    final _Anim anim;
    if (mining) {
      final t = chopPhase / (2 * pi);
      final double swing;
      if (t < 0.40) {
        swing = sin(t / 0.40 * pi * 0.5) * 0.90;
      } else {
        final t2 = (t - 0.40) / 0.60;
        swing = 0.90 - t2 * 1.05;
      }
      final s = flipX ? -swing : swing;
      anim = _Anim(0, 0, -s * 0.20, s, 0);
    } else {
      anim = _Anim.compute(walkPhase, moveIntensity);
    }
    final armRAngle = anim.armR;
    final armLAngle = anim.armL;

    const shirtCol  = Color(0xFF4A4840);
    const shirtDark = Color(0xFF2A2820);

    _shadow(canvas);
    _leg(canvas, -6, anim.legL, const Color(0xFF3A3028), _leatherDk);
    _leg(canvas,  6, anim.legR, const Color(0xFF3A3028), _leatherDk);
    canvas.save();
    _applyTorsoTransform(canvas, anim);
    canvas.drawRect(const Rect.fromLTWH(-13, -68, 26, 32), _f(shirtCol));
    canvas.drawRect(const Rect.fromLTWH(-13, -68, 26, 32), _s(shirtDark));
    // Deri yelek
    canvas.drawRect(const Rect.fromLTWH(-10, -67, 20, 30), _f(const Color(0xFF6A4A28)));
    canvas.drawRect(const Rect.fromLTWH(-10, -67, 20, 30), _s(_leatherDk));
    canvas.drawRect(const Rect.fromLTWH(-2, -58, 4, 14),   _f(_leatherDk));

    _arm(canvas, -16, armLAngle, shirtCol);
    _arm(canvas,  16, armRAngle, shirtCol,
        (arm) => ToolRenderer.drawPickaxe(arm));

    _head(canvas, _skin2);
    // Kask
    canvas.drawRect(const Rect.fromLTWH(-12, -96, 24,  6), _f(const Color(0xFF2A2010)));
    canvas.drawRect(const Rect.fromLTWH(-12, -96, 24,  6), _s(const Color(0xFF1A1008)));
    canvas.drawRect(const Rect.fromLTWH( -8,-108, 16, 12), _f(const Color(0xFF2A2010)));
    canvas.drawRect(const Rect.fromLTWH( -8,-108, 16, 12), _s(const Color(0xFF1A1008)));
    canvas.drawRect(const Rect.fromLTWH( -3,-108,  6,  4), _f(const Color(0xFFFFDD44)));
    canvas.restore();

    canvas.restore();
  }

  // ─── 10. ODUNCU ────────────────────────────────────────────────────────────

  static void drawWoodcutter(Canvas canvas, {
    bool flipX = false,
    double walkPhase = 0,
    double moveIntensity = 0.0,
    bool chopping = false,
    double chopPhase = 0,
  }) {
    canvas.save();
    if (flipX) canvas.scale(-1, 1);

    // Walking/idle iken standart _Anim (lean/sway/bob dahil).
    // Chopping iken sadece kol açıları custom; lean/sway/bob = 0.
    final _Anim anim;
    if (chopping) {
      final t = chopPhase / (2 * pi);
      final double swing;
      if (t < 0.38) {
        swing = sin(t / 0.38 * pi * 0.5) * 1.15;
      } else {
        final t2 = (t - 0.38) / 0.62;
        swing = 1.15 - t2 * 1.45;
      }
      final s = flipX ? -swing : swing;
      anim = _Anim(0, 0, -s * 0.22, s, 0);
    } else {
      anim = _Anim.compute(walkPhase, moveIntensity);
    }
    final armRAngle = anim.armR;
    final armLAngle = anim.armL;

    _shadow(canvas);
    _leg(canvas, -6, anim.legL, _woolDark, _leatherDk);
    _leg(canvas,  6, anim.legR, _woolDark, _leatherDk);

    canvas.save();
    _applyTorsoTransform(canvas, anim);
    // Gömlek: kırmızı-kahverengi ekose
    const shirtColor = Color(0xFF8B2020);
    const shirtDark  = Color(0xFF5A1010);
    canvas.drawRect(const Rect.fromLTWH(-13, -68, 26, 32), _f(shirtColor));
    canvas.drawRect(const Rect.fromLTWH(-13, -68, 26, 32), _s(shirtDark));
    for (final v in [-62.0, -54.0, -46.0]) {
      canvas.drawRect(Rect.fromLTWH(-12, v, 24, 2), _f(const Color(0xFF6A1010)));
    }
    canvas.drawRect(const Rect.fromLTWH(-1, -68, 2, 32), _f(shirtDark));
    canvas.drawRect(const Rect.fromLTWH(-9, -50, 18, 4), _f(_leather));

    // Sol kol
    _arm(canvas, -16, armLAngle, shirtColor);
    // Sağ kol + balta PNG
    _arm(canvas, 16, armRAngle, shirtColor, (arm) => ToolRenderer.drawAxe(arm));

    _head(canvas, _skin1);
    // Basit bere / bandana
    canvas.drawRect(const Rect.fromLTWH(-10, -98, 20, 18), _f(const Color(0xFF4A3010)));
    canvas.drawRect(const Rect.fromLTWH(-10, -98, 20, 18), _s(const Color(0xFF2A1A08)));
    canvas.restore();

    canvas.restore();
  }

  // ─── 9. BALIKÇI (idle draw — VillagerType.fisher için) ────────────────────
  static void _fisherIdle(Canvas c, _Anim anim) {
    _shadow(c);
    _leg(c, -6, anim.legL, const Color(0xFF3A5060), _leatherDk);
    _leg(c,  6, anim.legR, const Color(0xFF3A5060), _leatherDk);
    c.save();
    _applyTorsoTransform(c, anim);
    // Açık mavi balıkçı gömleği
    c.drawRect(const Rect.fromLTWH(-12, -68, 24, 32), _f(const Color(0xFF5A7888)));
    c.drawRect(const Rect.fromLTWH(-12, -68, 24, 32), _s(const Color(0xFF3A5060)));
    // Yelek (koyu)
    c.drawRect(const Rect.fromLTWH(-9, -67, 18, 30), _f(const Color(0xFF2A3840)));
    c.drawRect(const Rect.fromLTWH(-9, -67, 18, 30), _s(const Color(0xFF1A2830)));
    // İdle pozda olta elinde değil — aktif balıkçı ayrı (drawFisher).
    _arm(c, -15, anim.armL, const Color(0xFF5A7888));
    _arm(c,  15, anim.armR, const Color(0xFF5A7888));
    _head(c, _skin1);
    // Balıkçı şapkası (geniş kenarlı, düz)
    c.drawRect(const Rect.fromLTWH(-14, -98, 28, 6),  _f(const Color(0xFF4A3A20)));
    c.drawRect(const Rect.fromLTWH(-14, -98, 28, 6),  _s(const Color(0xFF2A1A08)));
    c.drawRect(const Rect.fromLTWH( -8, -110, 16, 12), _f(const Color(0xFF5A4A28)));
    c.drawRect(const Rect.fromLTWH( -8, -110, 16, 12), _s(const Color(0xFF2A1A08)));
    c.restore();
  }

  // ─── BALIKÇI (aktif, olta animasyonlu) ────────────────────────────────────
  static void drawFisher(Canvas canvas, {
    bool   flipX         = false,
    double walkPhase     = 0,
    double moveIntensity = 0.0,
    bool   fishing       = false,
    double fishPhase     = 0,
  }) {
    canvas.save();
    if (flipX) canvas.scale(-1, 1);

    final _Anim anim;
    final double armRAngle;
    final double castAngle;
    final double leftSwing;
    if (fishing) {
      final t = fishPhase / (2 * pi);
      final double swing;
      if (t < 0.3) {
        swing = sin(t / 0.3 * pi * 0.5) * 0.60;
      } else if (t < 0.7) {
        swing = 0.60;
      } else {
        swing = 0.60 - ((t - 0.7) / 0.3) * 0.70;
      }
      final s = flipX ? -swing : swing;
      armRAngle = s;
      castAngle = swing * 0.5;
      // Sol kol orijinaldeki gibi flipX-agnostic counterbalance.
      leftSwing = -swing * 0.15;
      anim = _Anim(0, 0, leftSwing, s, 0);
    } else {
      anim = _Anim.compute(walkPhase, moveIntensity);
      armRAngle = anim.armR;
      castAngle = 0;
      leftSwing = anim.armL;
    }

    _shadow(canvas);
    _leg(canvas, -6, anim.legL, const Color(0xFF3A5060), _leatherDk);
    _leg(canvas,  6, anim.legR, const Color(0xFF3A5060), _leatherDk);

    canvas.save();
    _applyTorsoTransform(canvas, anim);
    canvas.drawRect(const Rect.fromLTWH(-12, -68, 24, 32), _f(const Color(0xFF5A7888)));
    canvas.drawRect(const Rect.fromLTWH(-12, -68, 24, 32), _s(const Color(0xFF3A5060)));
    canvas.drawRect(const Rect.fromLTWH(-9, -67, 18, 30), _f(const Color(0xFF2A3840)));
    canvas.drawRect(const Rect.fromLTWH(-9, -67, 18, 30), _s(const Color(0xFF1A2830)));

    _arm(canvas, -15, leftSwing, const Color(0xFF5A7888));
    // Sağ kol + olta
    _arm(canvas,  15, armRAngle, const Color(0xFF5A7888),
        (arm) => ToolRenderer.drawRod(arm, castAngle: castAngle));

    // Olta ipi (fishing sırasında)
    if (fishing) {
      final lineLen = 22.0 + sin(fishPhase * 2) * 4;
      final angle   = 0.25 + castAngle + (flipX ? 0 : 0);
      final tipX    = 15 + sin(angle + (flipX ? pi : 0)) * 2;
      final tipY    = -68 + armRAngle * 15 + 14;
      // Ucundan aşağıya ip
      canvas.drawLine(
        Offset(tipX, tipY),
        Offset(tipX + (flipX ? -8 : 8), tipY + lineLen),
        Paint()..color = const Color(0xFFBBBB88)..strokeWidth = 1.0..isAntiAlias = false,
      );
    }

    _head(canvas, _skin1);
    // Şapka
    canvas.drawRect(const Rect.fromLTWH(-14, -98, 28, 6),   _f(const Color(0xFF4A3A20)));
    canvas.drawRect(const Rect.fromLTWH(-14, -98, 28, 6),   _s(const Color(0xFF2A1A08)));
    canvas.drawRect(const Rect.fromLTWH( -8, -110, 16, 12), _f(const Color(0xFF5A4A28)));
    canvas.drawRect(const Rect.fromLTWH( -8, -110, 16, 12), _s(const Color(0xFF2A1A08)));
    canvas.restore();

    canvas.restore();
  }

  // ════════════════════════════════════════════════════════════════════════════
  // YENİ NPC RENDER SİSTEMİ — per-NPC görsel varyasyon + 3-ton shading
  // ════════════════════════════════════════════════════════════════════════════

  /// Shaded rect — base color + top-left highlight + bottom-right shadow + outline.
  /// Pixel-art görünüm korunur, 3 ton hacim hissi katar.
  static void _shadedRect(Canvas c, Rect r, Color base) {
    final hl = lighter(base, 0.18);
    final sh = darker(base, 0.22);

    // Ana doluş
    c.drawRect(r, _f(base));
    // Üst highlight stripe (1px)
    c.drawRect(Rect.fromLTWH(r.left + 1, r.top + 1, r.width - 2, 1), _f(hl));
    // Sol highlight stripe (1px)
    c.drawRect(Rect.fromLTWH(r.left + 1, r.top + 1, 1, r.height - 2), _f(hl));
    // Sağ shadow stripe (1px)
    c.drawRect(Rect.fromLTWH(r.right - 2, r.top + 1, 1, r.height - 2), _f(sh));
    // Alt shadow stripe (1px)
    c.drawRect(Rect.fromLTWH(r.left + 1, r.bottom - 2, r.width - 2, 1), _f(sh));
    // Outline (siyahımsı)
    c.drawRect(r, _s(_outline));
  }

  /// Shaded leg — hip pivot rotation + 3-tone hose + boot.
  static void _shadedLeg(Canvas c, double hipX, double angle,
      Color hose, Color boot) {
    c.save();
    c.translate(hipX, -36);
    c.rotate(angle);
    _shadedRect(c, const Rect.fromLTWH(-4, 0, 8, 22), hose);
    _shadedRect(c, const Rect.fromLTWH(-5, 19, 10, 7), boot);
    c.restore();
  }

  /// Shaded arm — shoulder pivot rotation + 3-tone sleeve + skin-tone hand.
  static void _shadedArm(Canvas c, double shoulderX, double angle,
      Color sleeve, Color skin, [void Function(Canvas)? item]) {
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
  static void _shadedTunic(Canvas c, Color cloth) {
    _shadedRect(c, const Rect.fromLTWH(-12, -68, 24, 32), cloth);
    // Kemer
    _shadedRect(c, const Rect.fromLTWH(-12, -50, 24, 5), _leather);
    // Toka — sabit küçük detay
    c.drawRect(const Rect.fromLTWH(-3, -50, 6, 5), _f(_leatherDk));
  }

  /// Per-NPC kafa: ten + saç (stil) + sakal (stil) + göz (renk) + blink.
  /// [time] blink animasyonu için zaman parametresi.
  /// [y] kafanın merkez Y koordinatı (default -80).
  static void _shadedHead(Canvas c, NpcVisual v, double time, {double y = -80}) {
    // ── Yüz / ten ─────────────────────────────────────────────────────────
    _shadedRect(c, Rect.fromLTWH(-9, y - 10, 18, 20), v.skin);

    // ── Saç (stile göre) ──────────────────────────────────────────────────
    _drawHair(c, v, y);

    // ── Sakal (varsa, saçtan ÖNCE çiz ki üstte kalmasın) ──────────────────
    if (v.hasBeard) _drawBeard(c, v, y);

    // ── Gözler (renkli + blink) ───────────────────────────────────────────
    // Blink: nadir, kısa.  sin > 0.96 → kapalı (≈0.6 sn / 8 sn döngü)
    final blinkRaw = sin(time * 0.78 + v.blinkPhase);
    final closed   = blinkRaw > 0.96;
    if (closed) {
      // Kapalı göz — yatay çizgi
      c.drawRect(Rect.fromLTWH(-6, y - 3, 3, 1), _f(_outline));
      c.drawRect(Rect.fromLTWH( 3, y - 3, 3, 1), _f(_outline));
    } else {
      // Açık göz — küçük renk + outline
      c.drawRect(Rect.fromLTWH(-6, y - 4, 3, 3), _f(_outline));
      c.drawRect(Rect.fromLTWH( 3, y - 4, 3, 3), _f(_outline));
      // İris renk - 2x2 iç kısım
      c.drawRect(Rect.fromLTWH(-5, y - 3, 2, 2), _f(v.eyes));
      c.drawRect(Rect.fromLTWH( 4, y - 3, 2, 2), _f(v.eyes));
    }

    // ── Kaş (saç renginin koyu tonu) ──────────────────────────────────────
    final brow = darker(v.hair, 0.10);
    c.drawRect(Rect.fromLTWH(-7, y - 6, 4, 1), _f(brow));
    c.drawRect(Rect.fromLTWH( 3, y - 6, 4, 1), _f(brow));

    // ── Ağız (sakal yoksa görünür) ────────────────────────────────────────
    if (v.beardStyle != BeardStyle.full) {
      c.drawRect(Rect.fromLTWH(-3, y + 5, 6, 1), _f(_outline));
    }
  }

  /// Hair rendering — stile göre farklı şekil.
  static void _drawHair(Canvas c, NpcVisual v, double y) {
    if (v.hairStyle == HairStyle.bald) return;
    final hair  = v.hair;
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
        c.drawRect(Rect.fromLTWH(-10, y - 8, 2, 6),  _f(hair));
        c.drawRect(Rect.fromLTWH(  8, y - 8, 2, 6),  _f(hair));
        c.drawRect(Rect.fromLTWH(-9, y - 11, 18, 1), _f(hairS));
      case HairStyle.long:
        // Uzun: üst + yan saç çene altına kadar
        c.drawRect(Rect.fromLTWH(-9, y - 11, 18, 6),  _f(hair));
        c.drawRect(Rect.fromLTWH(-11, y - 8, 3, 18), _f(hair));
        c.drawRect(Rect.fromLTWH( 8, y - 8, 3, 18),  _f(hair));
        c.drawRect(Rect.fromLTWH(-11, y + 8, 3, 1),  _f(hairS));
        c.drawRect(Rect.fromLTWH( 8, y + 8, 3, 1),   _f(hairS));
      case HairStyle.messy:
        // Tepe + dağınık peakler
        c.drawRect(Rect.fromLTWH(-9, y - 11, 18, 4), _f(hair));
        c.drawRect(Rect.fromLTWH(-7, y - 14, 4, 4),  _f(hair));
        c.drawRect(Rect.fromLTWH( 0, y - 14, 3, 4),  _f(hair));
        c.drawRect(Rect.fromLTWH( 4, y - 13, 3, 3),  _f(hair));
    }
  }

  /// Beard rendering — stile göre.
  static void _drawBeard(Canvas c, NpcVisual v, double y) {
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

  // ─── ÇIFTÇI (yeni — per-NPC görsel + akıcı hareket) ───────────────────────
  static void _farmerNpc(Canvas c, _Anim anim, NpcVisual v, double time) {
    // Kıyafet renkleri — baz + tint shift per-NPC
    final tunicBase = tintCloth(_linen,     v.clothingShift);
    final hoseBase  = tintCloth(_woolBrown, v.clothingShift * 0.6);
    final hatStraw  = tintCloth(_straw,     v.clothingShift * 0.5);

    _shadow(c);
    // Bacaklar gövde lean/sway'ından bağımsız — ayak yerde sabit
    _shadedLeg(c, -6, anim.legL, hoseBase, _leatherDk);
    _shadedLeg(c,  6, anim.legR, hoseBase, _leatherDk);

    // Gövde transform — bob + sway + lean (ortak helper)
    c.save();
    _applyTorsoTransform(c, anim);

    _shadedTunic(c, tunicBase);
    _shadedArm(c, -15, anim.armL, tunicBase, v.skin);
    _shadedArm(c,  15, anim.armR, tunicBase, v.skin);
    _shadedHead(c, v, time);

    // Hasır şapka — saç görünür kalsın diye üstten çiz (kafayı kapatmaz tam)
    _shadedRect(c, const Rect.fromLTWH(-17, -98, 34, 8), hatStraw);
    _shadedRect(c, const Rect.fromLTWH( -7, -110, 14, 12), hatStraw);
    c.drawRect(const Rect.fromLTWH(-7, -100, 14, 2),
        _f(const Color(0xFF6A4830)));
    c.restore();
  }

  // ─── 11. İNŞAATÇI ──────────────────────────────────────────────────────────
  static void _builder(Canvas c, _Anim anim, {bool working = false}) {
    _shadow(c);
    _leg(c, -6, anim.legL, _woolBrown, _leatherDk);
    _leg(c,  6, anim.legR, _woolBrown, _leatherDk);
    c.save();
    _applyTorsoTransform(c, anim);
    // Çalışma tulumu
    c.drawRect(const Rect.fromLTWH(-12, -68, 24, 32), _f(const Color(0xFF9A7840)));
    c.drawRect(const Rect.fromLTWH(-12, -68, 24, 32), _s(_outline));
    // Önlük
    c.drawRect(const Rect.fromLTWH(-8, -66, 16, 28), _f(_leather));
    c.drawRect(const Rect.fromLTWH(-8, -66, 16, 28), _s(_leatherDk));
    // Omuz askısı
    c.drawRect(const Rect.fromLTWH(-13, -50, 26, 4), _f(_leatherDk));
    _arm(c, -15, anim.armL, const Color(0xFF9A7840));
    // Sağ kol + çekiç (PNG)
    _arm(c, 15, anim.armR, const Color(0xFF9A7840),
        (arm) => ToolRenderer.drawHammer(arm));
    _head(c, _skin1);
    // Bere
    c.drawRect(const Rect.fromLTWH(-10, -98, 20, 18), _f(const Color(0xFFBEA870)));
    c.drawRect(const Rect.fromLTWH(-10, -98, 20, 18), _s(const Color(0xFF8A7040)));
    c.restore();
  }
}
