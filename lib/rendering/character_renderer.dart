import 'dart:math';

import 'package:flutter/material.dart';

import '../characters/life_stage.dart';
import '../characters/npc_visual.dart';
import '../characters/villager_type.dart';
import 'tool_renderer.dart';

// ─── ANİMASYON ────────────────────────────────────────────────────────────────

class _Anim {
  final double legL, legR, armL, armR, bob;
  /// Adım atan ayağın yerden yükselmesi (negatif Y, sadece walking).
  /// Yürürken bir ayak yukarı kalkar, diğeri yere basar → "yürüyor" hissi.
  final double legLiftL, legLiftR;
  /// Gövde yatay ağırlık değişimi (idle slow sway).
  final double sway;
  /// Gövde + kafa lean (öne eğilme, walking).  Radyan.
  final double lean;
  /// Üst gövdenin yan twist'i (walking — yürüyenin omuzu hafif döner).
  final double torsoTwist;
  const _Anim(this.legL, this.legR, this.armL, this.armR, this.bob,
              {this.sway = 0, this.lean = 0,
               this.legLiftL = 0, this.legLiftR = 0,
               this.torsoTwist = 0});

  /// Tek parametre değiştirip kopya — meşale taşıyan sol kolu yukarı sabit
  /// tutmak gibi durumlar için. Diğer alanlar korunur.
  _Anim copyWith({double? armL}) => _Anim(
      legL, legR, armL ?? this.armL, armR, bob,
      sway: sway, lean: lean,
      legLiftL: legLiftL, legLiftR: legLiftR,
      torsoTwist: torsoTwist);

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
      final bobWalk = (cos(phase * 2) - 1) * 2.0;
      final liftL = max(0.0, sin(phase)) * 1.4 * m;
      final liftR = max(0.0, -sin(phase)) * 1.4 * m;
      return _Anim(
        sin(phase) * (0.04 + m * 0.34),
        -sin(phase) * (0.04 + m * 0.34),
        0.65 + wobble,
        -0.65 - wobble,
        bobWalk * m,
        lean: m * 0.06,
        legLiftL: liftL,
        legLiftR: liftR,
      );
    }

    // ── Idle parametreleri ────────────────────────────────────────────────
    final sIdle      = sin(phase) * 0.10;
    // Daha yavaş, daha doğal nefes alma (0.4 Hz → 0.32 Hz). Genlik +0.2 px.
    final breathIdle = -sin(phase * 0.35).abs() * 0.8;
    // Yavaş yan ağırlık değişimi — idle "yaşıyor" hissi, vurgulu.
    final idleSway   = sin(phase * 0.26) * 2.2;

    // ── Walking parametreleri ─────────────────────────────────────────────
    final sWalk    = sin(phase);
    // Bob: 2× frequency cosine — her adımda iniş/çıkış. Daha belirgin.
    final bobWalk  = (cos(phase * 2) - 1) * 2.6;
    // Walking lean — gövde öne eğilir (radyan).
    const leanWalk = 0.10;
    // Foot lift Y — sin'in pozitif yarısında sol ayak kalkar, ters yarıda sağ.
    final liftL    = max(0.0, sWalk)  * 1.6 * m;
    final liftR    = max(0.0, -sWalk) * 1.6 * m;
    // Üst gövde twist — yürürken omuzlar hafif tersine döner (counter-leg).
    final twist    = sWalk * 0.04 * m;

    // ── Blend ──────────────────────────────────────────────────────────────
    return _Anim(
      sIdle        + (sWalk * 0.55 - sIdle) * m,           // legL (daha geniş adım)
      -sIdle       + (-sWalk * 0.55 + sIdle) * m,          // legR
      -sIdle * 0.5 + (-sWalk * 0.40 + sIdle * 0.5) * m,    // armL (counter-leg)
       sIdle * 0.5 + ( sWalk * 0.40 - sIdle * 0.5) * m,    // armR
      breathIdle   + (bobWalk - breathIdle) * m,            // bob
      sway: idleSway * (1.0 - m),
      lean: leanWalk * m,
      legLiftL: liftL,
      legLiftR: liftR,
      torsoTwist: twist,
    );
  }
}

// ─── POZ ──────────────────────────────────────────────────────────────────────
/// Karakterin tüm gövde duruşunu değiştiren özel pozlar — ayakta/yürür dışı.
/// Uzuvları (bacak/kol/lean) gerçekten yeniden konumlandırır; emoji/kestirme
/// DEĞİL. Ateş başı oturma, ayin diz çökme, yas eğilmesi için.
enum CharPose {
  normal, // ayakta / yürür (varsayılan _Anim)
  sit,    // bağdaş kurmuş — bacaklar öne katlı, eller kucakta, hafif öne
  kneel,  // ayin: dizüstü, gövde dik, kollar yukarı yakarış
  mourn,  // yas: çömelmiş, derin öne eğilme, kollar önde sarkık
}

// ─── RENDERER ─────────────────────────────────────────────────────────────────
// Pixel-art tarzı karakterler: yalnızca dikdörtgenler, isAntiAlias=false.
// Ayaklar canvas orijininde (y=0). Çağıran save/translate/scale/restore yapar.

class CharacterRenderer {
  // ── KÖYÜN HÂLİ (Faz 5) ─────────────────────────────────────────────────────
  //
  // Basınç tablosunun çizime inen iki değeri. Parametre olarak 15 ayrı meslek
  // fonksiyonuna taşımak yerine [_accent] ile aynı kalıpta statik: çizim tek
  // iş parçacığında, tek karakter için, baştan sona sürer. ÇAĞIRAN SORUMLU —
  // her NPC'den önce [beginNpc] çağrılmalı, yoksa bir önceki karakterin hâli
  // sızar (aynı tuzak [_accent]'te de var, o yüzden aynı yerde yazılıyorlar).

  /// Köyün ambar hâli: -1 yoksunluk … +1 refah. Giysi renkleri buradan solar
  /// ya da doyar (bkz. [_cloth]).
  static double _provision = 0;

  /// Örtünme 0..1 — tedirginliğin siluete inmiş hâli (omuzda şal, başta
  /// kapüşon). Köylünün `bearingTense` değerinden gelir.
  static double _shroud = 0;

  /// Terzi kurulmadan önce bütün yerleşiklerin giydiği kaba post/bez kılığı.
  static bool _primitiveClothing = false;

  /// Bir NPC çizmeden ÖNCE köyün hâlini yaz. Yabancı (imparatorluk) için
  /// sıfır geçilir: köyün ambarı onun kumaşını soldurmaz.
  ///
  /// SÖZLEŞME (aynen [_accent] gibi): **her giriş noktası kendi hâlini yazar.**
  /// Argümansız çağrı nötre döner ve oyun-dışı çağıranlar (künye portresi,
  /// animasyon odası, yakalama harness'ları) hiçbir şey bilmeden doğru sonucu
  /// alır — yazmayan çağıran son çizilen köylünün kıtlığını miras alırdı.
  static void beginNpc({double provision = 0, double shroud = 0,
      bool primitiveClothing = false}) {
    _provision = provision.clamp(-1.0, 1.0);
    _shroud = shroud.clamp(0.0, 1.0);
    _primitiveClothing = primitiveClothing;
  }

  /// GİYSİ RENGİ — tek kapı. Kişisel ton ([NpcVisual.clothingShift]) üstüne
  /// köyün hâli biner. Dosyadaki bütün kumaş renkleri buradan geçer; yeni bir
  /// meslek eklerken doğrudan `tintCloth` çağırma, yoksa o meslek köyün
  /// kıtlığından etkilenmeyen tek kişi olur.
  ///
  /// Ölçek bilinçli ölçülü: en kötü günde bile kumaş TANINIR kalır — amaç
  /// "kostüm değişti" değil, "bu köy bugün yorgun" hissi.
  static Color _cloth(Color base, double shift) {
    if (_primitiveClothing) base = const Color(0xFF8A6945);
    final c = tintCloth(base, shift);
    final p = _provision;
    if (p.abs() < 0.02) return c;

    final r = c.r * 255, g = c.g * 255, b = c.b * 255;
    // Algısal gri — yeşil ağırlıklı (göz yeşile duyarlı).
    final grey = r * 0.30 + g * 0.59 + b * 0.11;

    if (p < 0) {
      // YOKSUNLUK — doygunluk griye çekilir + tozlu bir gri-kahve karışır +
      // hafif koyulaşma. Üç etki birlikte "yıkanmış, yamalı, güneş yemiş"
      // okunur; yalnız alpha/koyuluk oynatmak kirli değil KARANLIK gösterirdi.
      final t = (-p).clamp(0.0, 1.0);
      final desat = 0.45 * t;
      var nr = r + (grey - r) * desat;
      var ng = g + (grey - g) * desat;
      var nb = b + (grey - b) * desat;
      const dustR = 110.0, dustG = 103.0, dustB = 92.0;
      final mix = 0.16 * t;
      nr += (dustR - nr) * mix;
      ng += (dustG - ng) * mix;
      nb += (dustB - nb) * mix;
      final dim = 1.0 - 0.10 * t;
      return Color.fromARGB(
        (c.a * 255).round(),
        (nr * dim).clamp(0, 255).round(),
        (ng * dim).clamp(0, 255).round(),
        (nb * dim).clamp(0, 255).round(),
      );
    }

    // REFAH — doygunluk artar (kanallar griden UZAKLAŞIR) + çok hafif
    // aydınlanma. Boya parası olan köyün kumaşı canlıdır.
    final t = p.clamp(0.0, 1.0);
    final sat = 0.28 * t;
    final lift = 1.0 + 0.06 * t;
    return Color.fromARGB(
      (c.a * 255).round(),
      ((r + (r - grey) * sat) * lift).clamp(0, 255).round(),
      ((g + (g - grey) * sat) * lift).clamp(0, 255).round(),
      ((b + (b - grey) * sat) * lift).clamp(0, 255).round(),
    );
  }

  static void draw(Canvas canvas, VillagerType type, {
    bool flipX = false,
    double walkPhase = 0,
    double moveIntensity = 0.0,
    bool carrying = false,
    /// Özel gövde duruşu — oturma/ayin/yas. normal dışı tüm uzuv açılarını
    /// override eder (meşale kolu kilidi ve elde meşale devre dışı).
    CharPose pose = CharPose.normal,
    /// 0..1 — Entity.torchLevel ile birebir. Sprite alpha ve hafif scale
    /// flicker bu değere bağlı; eski `bool torch` parametresinin yerine geçer.
    double torchLevel = 0.0,
    /// Per-NPC sabit flicker fazı (ToolRenderer.drawTorch sapın titreşmesi için).
    double torchPhase = 0.0,
    NpcVisual? visual,
    double time = 0,
    LifeStage stage = LifeStage.adult,
    /// Mesleğden bağımsız özel kostüm — `imperial` ise tip/meslek görünümü
    /// yerine imparatorluk askeri çizilir (bkz. [NpcCostume]).
    NpcCostume costume = NpcCostume.none,
    /// İmparatorluk kostümünde komutan mı (uzun kızıl sorguç + pelerin).
    bool commander = false,
    /// İmparatorluk askeri saldırı modunda mı — mızrak ileri dürtme (jab) pozu.
    bool attacking = false,
    /// Hane aksan rengi (bkz. [houseAccentColor]) — göğüsteki çapraz kuşak.
    /// null → hanesiz/yabancı, kuşak çizilmez.
    Color? houseAccent,
    /// Köyün ambar hâli -1..1 ve köylünün örtünmesi 0..1 (bkz. [beginNpc]).
    /// Oyun-dışı çağıranlar geçmez → nötr görünüm.
    double provision = 0,
    double shroud = 0,
    bool primitiveClothing = false,
  }) {
    // İmparatorluk askeri köyün YABANCISI — hane kuşağı takmaz. Aksi halde
    // dışarıdan gelen vergici bir köy hanesinin rengiyle görünürdü.
    _accent = costume == NpcCostume.imperial ? null : houseAccent;
    final foreign = costume == NpcCostume.imperial;
    beginNpc(
      provision: foreign ? 0 : provision,
      shroud: foreign ? 0 : shroud,
      primitiveClothing: foreign ? false : primitiveClothing,
    );
    canvas.save();
    if (flipX) canvas.scale(-1, 1);
    // Beden farkı — ayaklar orijinde (y=0) olduğu için dikey ölçek tabanı
    // kaydırmaz, köylü yerde basılı kalır. Genişlik boydan daha az oynatılır:
    // uzun köylü orantısal olarak hafif ince görünsün.
    final b = visual?.build ?? 1.0;
    if (b != 1.0) canvas.scale(1 + (b - 1) * 0.55, b);
    var anim = _Anim.compute(walkPhase, moveIntensity, carrying: carrying);
    if (pose != CharPose.normal) {
      // Poz tüm duruşu ele alır — yürüyüş/taşıma/meşale açıları geçersiz.
      anim = _poseAnim(pose, time);
    } else if (torchLevel > 0.02) {
      // Meşale taşıyorsa sol kol yukarı kilitlenir → el ve meşale tek birim.
      anim = anim.copyWith(armL: _kTorchArmAngle);
    }

    // Özel kostüm (imparatorluk askeri) tip/meslek/evreyi önceler — köyün
    // yabancısı her zaman tam zırhlı görünür.
    if (costume == NpcCostume.imperial && visual != null) {
      final v = stage == LifeStage.elder ? visual.elderly() : visual;
      _imperialSoldierNpc(canvas, anim, v, time,
          commander: commander, attacking: attacking);
    }
    else if (primitiveClothing) {
      final baseVisual = visual ?? _fallbackVisual;
      final v = stage == LifeStage.elder
          ? baseVisual.elderly()
          : baseVisual;
      _primitiveNpc(canvas, anim, v, time,
          child: stage == LifeStage.child);
    }
    // Çocuk/genç henüz meslek edinmemiş → standart köylü görünümü, tipten
    // bağımsız. Yetişkin/yaşlı meslek görünür; yaşlıda saç kıra döner.
    else if (visual != null && !stage.hasProfession) {
      _peasantNpc(canvas, anim, visual, time, child: stage == LifeStage.child);
    } else {
      final v = (visual != null && stage == LifeStage.elder)
          ? visual.elderly()
          : visual;
      switch (type) {
        case VillagerType.farmer:
          v != null ? _farmerNpc(canvas, anim, v, time)
                    : _farmer(canvas, anim);
        case VillagerType.merchant:
          v != null ? _merchantNpc(canvas, anim, v, time)
                    : _merchant(canvas, anim);
        case VillagerType.blacksmith:
          v != null ? _blacksmithNpc(canvas, anim, v, time)
                    : _blacksmith(canvas, anim);
        case VillagerType.guard:
          v != null ? _guardNpc(canvas, anim, v, time)
                    : _guard(canvas, anim);
        case VillagerType.miner:
          v != null ? _minerNpc(canvas, anim, v, time)
                    : _miner(canvas, anim);
        case VillagerType.fisher:
          v != null ? _fisherNpc(canvas, anim, v, time)
                    : _fisherIdle(canvas, anim);
        // Yeni meslekler: tek (shaded) yol — visual yoksa nötr fallback görsel
        // kullanılır, ayrı ilkel varyant yazmaya gerek yok.
        case VillagerType.priest:
          _priestNpc(canvas, anim, v ?? _fallbackVisual, time);
        case VillagerType.shepherd:
          _shepherdNpc(canvas, anim, v ?? _fallbackVisual, time);
        case VillagerType.hunter:
          _hunterNpc(canvas, anim, v ?? _fallbackVisual, time);
        case VillagerType.miller:
          _millerNpc(canvas, anim, v ?? _fallbackVisual, time);
        case VillagerType.innkeeper:
          _innkeeperNpc(canvas, anim, v ?? _fallbackVisual, time);
      }
    }

    // ÖRTÜNME — köylünün tedirginliği siluete iner (Faz 5). Gövdenin ÜSTÜNE,
    // meşaleden önce: şal bir dış giysidir, kolun altında kalmaz.
    // (Yabancı için _shroud girişte zaten sıfırlandı.)
    if (_shroud > 0.30) {
      canvas.save();
      _applyTorsoTransform(canvas, anim);
      _shroudOverlay(canvas, visual, stage);
      canvas.restore();
    }

    // Gece dışarıda meşale — sol omuz (off-hand), tüm character render
    // yolları aynı helper'ı kullanır → civilian + worker pattern tutarlı.
    // Oturma/ayin/yas pozunda eller serbest → meşale taşınmaz.
    if (pose == CharPose.normal) {
      _torchInLeftHand(canvas, torchLevel,
          time: time, torchPhase: torchPhase);
    }
    canvas.restore();
    _accent = null;
  }

  /// ŞAL + KAPÜŞON — tedirginliğin görünür hâli.
  ///
  /// İki kademe, çünkü tek kademe ya hiç okunmuyor ya da herkesi keşişe
  /// çeviriyordu:
  ///   • 0.30–0.62 → omuzlarda şal (siluetin omuz hattı kalınlaşır, uzaktan
  ///     "büzülmüş" okunur; yüz tamamen açık kalır).
  ///   • 0.62 üstü → şalın üstüne kapüşon (saç/alın örtülür).
  ///
  /// TUZAK (bkz. char-shaded-system): başlık GÖZÜ YUTMAMALI. Yüz -90..-70
  /// arasında, kaşlar -85 hizasında; kapüşon tepesi -99..-87 ile SINIRLI —
  /// avcı kukuletasının denenmiş geometrisi birebir buradan alındı.
  static void _shroudOverlay(Canvas c, NpcVisual? visual, LifeStage stage) {
    // Yoğunluk 0..1'e normalize: eşikte 0'dan başlasın ki şal aniden BELİRMESİN,
    // birkaç saniye içinde koyulaşarak gelsin.
    final t = ((_shroud - 0.30) / 0.70).clamp(0.0, 1.0);
    // Örtü rengi kumaşın kendi ailesinden — kişisel ton korunur, köyün hâli
    // (_cloth üzerinden) buna da işler. Nötr yün: köyde herkesin sandığında var.
    //
    // TON DERSİ (ilk sürüm harness'ta yakalandı): koyu yün (0xFF5A5348) bu
    // ölçekte kumaş değil DERİ ZIRH okunuyordu — omuzda siyaha yakın bir bar,
    // hane kuşağıyla yarışıyor. Açık, sıcak, düşük kontrastlı yün hem şal gibi
    // duruyor hem de siluetin okunmasını bozmuyor.
    final wool = _cloth(const Color(0xFF8C8071), (visual?.clothingShift ?? 0) * 0.6);
    // Çocuk gövdesi küçük — örtü de daralır, yoksa omuzları yutar.
    final k = stage == LifeStage.child ? 0.78 : 1.0;

    // FADE YOK, BÜYÜME VAR: şal eşikte ince bir atkı olarak başlar, tedirginlik
    // arttıkça omuzu sarar. Saydamlıkla soldurmak per-NPC saveLayer isterdi —
    // bu projede gece ışıklandırması zaten saveLayer'a boğulmuş durumda
    // (bkz. juice-comfort FPS denetimi), karakter başına bir tane daha eklemek
    // görünmez bir maliyet olurdu. Kalınlık değişimi bedava ve daha okunur.
    final band = 4.0 + 3.0 * t;

    // Omuz örtüsü — omuz hattından göğse inen bant. Kolların pivotu -68'de;
    // bant onun üstünden başlar ki kol dönerken şalın altından çıksın.
    // Genişlik omuzdan taşmaz (-13..13): taşan bant gövdeyi genişletip
    // siluetin kendi okunuşunu (zayıf/iri) bozuyordu.
    _shadedRect(c, Rect.fromLTWH(-13 * k, -71, 26 * k, band), wool);
    // Sırttan öne dolanan uçlar (asimetrik — düz bant yassı durur).
    _shadedRect(c, Rect.fromLTWH(-12 * k, -71 + band, 7 * k, 2 + 3 * t), wool);
    _shadedRect(c, Rect.fromLTWH(6 * k, -71 + band, 6 * k, 2 + 2 * t), wool);
    // Boyun altı gölgesi — örtünün altına giren gövde. Yumuşak: sert siyah
    // çizgi bu ölçekte kumaşı ikiye bölünmüş gösteriyor.
    c.drawRect(Rect.fromLTWH(-9 * k, -71, 18 * k, 1.5),
        _f(darker(wool, 0.12)));

    // KAPÜŞON — yalnız üst kademede. Avcı kukuletası geometrisi: tepe +
    // yüzü çerçeveleyen iki yanak. Yüz bandına (-90..-70) girmez.
    if (_shroud > 0.62) {
      // Başlık DAR ve YÜKSEK: köylülerin çoğunda zaten bir şapka var (hasır,
      // bez, kask). Geniş bir kapüşon onu yutup "iki başlık üst üste" gibi
      // duruyordu; dar hâli şapkanın kenarını açıkta bırakıyor ve başa çekilmiş
      // bir örtü olarak okunuyor. Yüz bandına (-90..-70) yine girmez.
      _shadedRect(c, Rect.fromLTWH(-10 * k, -100, 20 * k, 11), wool);
      _shadedRect(c, Rect.fromLTWH(-11 * k, -95, 3.5 * k, 9), wool);
      _shadedRect(c, Rect.fromLTWH(7.5 * k, -95, 3.5 * k, 9), wool);
      // Kapüşonun iç gölgesi — alın hizasında ince koyu şerit (derinlik).
      c.drawRect(Rect.fromLTWH(-9 * k, -90, 18 * k, 1.5),
          _f(darker(wool, 0.22)));
    }
    // NOT: burada `c.restore()` YOK ve olmamalı. Bu fonksiyon hiç `save()`
    // çağırmıyor — gövde dönüşümünü ve save/restore çiftini ÇAĞIRAN kuruyor
    // (bkz. [draw], `_shroud > 0.30` dalı). Buradaki fazladan bir restore
    // çağıranın save'ini de yer ve canvas'ı eksiye düşürür; Flutter bunu
    // "custom painter called canvas.restore() 1 more time" diye yakalar ve
    // O KAREDE SAHNENİN TAMAMI ÇİZİLMEZ. Sessiz kalmasının sebebi şuydu:
    // yalnız TEDİRGİN köylüde (shroud > 0.30) tetikleniyor, oturmuş bir köyde
    // kimse o eşiğe çıkmıyordu.
  }

  /// Poz → uzuv açıları. Bacakları katlar, kolları konumlar, gövdeyi eğip
  /// indirir (bob). Gerçek duruş; squash/kestirme değil. Dikey yere oturtma
  /// (sprite'ı aşağı kaydırma) çağıran tarafta (game_painter) yapılır.
  static _Anim _poseAnim(CharPose pose, double time) {
    switch (pose) {
      case CharPose.sit:
        // Bağdaş: iki bacak öne katlı (hafif asimetrik), gövde öne+aşağı,
        // eller kucakta. Nefesle çok hafif salınım.
        final breath = sin(time * 0.8) * 0.4;
        return _Anim(1.32, 1.48, 0.62, -0.62, 15.0 + breath, lean: 0.12);
      case CharPose.kneel:
        // Ayin: dizler geri katlı (dizüstü), gövde dik, kollar yukarı yakarış
        // — yavaş ritmik yükseliş (ibadet ritmi).
        final lift = sin(time * 1.4) * 0.06;
        return _Anim(-0.34, -0.34, -2.40 + lift, -2.40 - lift, 13.0);
      case CharPose.mourn:
        // Yas: çömelmiş + derin öne eğilme (baş öne düşer), kollar önde sarkık.
        final sway = sin(time * 0.9) * 0.015;
        return _Anim(1.18, 1.34, 0.34, -0.34, 16.0, lean: 0.36 + sway);
      case CharPose.normal:
        return _Anim.compute(time, 0);
    }
  }

  /// Yatay yatmış uyku pozu — yastıkta kafa, vücut battaniyenin üstünde,
  /// hafif breath salınımı.  Origin: karakterin ayak konumu (canvas zaten
  /// translate edilmiş olmalı).  Karakter sola doğru uzanır (kafa solda).
  static void drawSleeping(Canvas c, VillagerType type, {
    double walkPhase = 0,
    bool flipX = false,
    bool primitiveClothing = false,
  }) {
    // Uyuyan gövde battaniye altında — kuşak görünmez, ama bir önceki NPC'nin
    // rengi sızmasın diye invariant burada da uygulanır. Köyün hâli de nötre
    // döner: battaniye altındaki gövdede kılık okunmaz.
    _accent = null;
    beginNpc(primitiveClothing: primitiveClothing);
    c.save();
    if (flipX) c.scale(-1, 1);

    final breath = sin(walkPhase * 0.6) * 0.6;
    final tunicCol = primitiveClothing
        ? const Color(0xFF80603E)
        : _sleepTunicColor(type);
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
        VillagerType.priest     => _kPriestRobe,
        VillagerType.miner      => const Color(0xFF4A4840),
        VillagerType.fisher     => const Color(0xFF5A7888),
        VillagerType.shepherd   => _kShepherdWool,
        VillagerType.hunter     => _kHunterGreen,
        VillagerType.miller     => _kMillerCloth,
        VillagerType.innkeeper  => _kInnkeeperWine,
      };

  static Color _sleepSkinColor(VillagerType type) =>
      (type == VillagerType.blacksmith ||
              type == VillagerType.miner ||
              type == VillagerType.hunter)
          ? _skin2
          : _skin1;

  /// Meşale taşıyan sol kolun sabit açısı — yukarı kaldırılmış, baş hizasında.
  /// Gerçek meşale duruşu: kol aşağı sallanmaz, alev yukarıda durur.
  /// Hem helper rotate hem body sol kol bu açıya kilitlenir → kol + meşale
  /// tek birim olarak hareket eder.
  static const double _kTorchArmAngle = -2.55;

  /// Tek meşale helper — civilian + tüm worker tipleri buradan geçer.
  /// Sol omuz pivotu (off-hand); sağ kolda alet olabilir (balta/kazma/...).
  /// Kol açısı sabit `_kTorchArmAngle` (drawX'ler armL'yi de bu değere
  /// kilitler → el meşaleden ayrı görünmez). flicker scale tek varyasyon.
  static void _torchInLeftHand(Canvas c, double torchLevel,
      {double shoulderX = -15,
       double shoulderY = -68,
       double time = 0,
       double torchPhase = 0}) {
    if (torchLevel <= 0.02) return;
    c.save();
    c.translate(shoulderX, shoulderY);
    c.rotate(_kTorchArmAngle);
    final flick = 1.0 + sin(time * 5.2 + torchPhase) * 0.04;
    c.scale(flick, flick);
    ToolRenderer.drawTorch(c, alpha: torchLevel);
    c.restore();
  }

  static void drawFarmer(Canvas canvas, {
    bool   flipX         = false,
    double walkPhase     = 0,
    double moveIntensity = 0.0,
    bool   harvesting    = false,
    double harvestPhase  = 0,
    bool   carryingWater = false,
    NpcVisual? visual,
    double time = 0,
    double torchLevel = 0,
    double torchPhase = 0,
    /// Hane aksan rengi — göğüsteki çapraz kuşak (bkz. [houseAccentColor]).
    Color? houseAccent,
    bool primitiveClothing = false,
  }) {
    _accent = houseAccent;
    _primitiveClothing = primitiveClothing;
    canvas.save();
    if (flipX) canvas.scale(-1, 1);

    _Anim anim;
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
    // Meşale yanıyorsa sol kol yukarı sabit kilitlenir (kol + meşale tek birim).
    final showTorch = torchLevel > 0.02 && !carryingWater && !harvesting;
    if (showTorch) anim = anim.copyWith(armL: _kTorchArmAngle);

    if (primitiveClothing) {
      _primitiveNpc(canvas, anim, visual ?? _fallbackVisual, time,
          rightItem: carryingWater
              ? ToolRenderer.drawWaterbucket
              : null);
      if (showTorch) {
        _torchInLeftHand(canvas, torchLevel,
            time: time, torchPhase: torchPhase);
      }
      canvas.restore();
      return;
    }

    _farmer(canvas, anim, carryingWater: carryingWater, v: visual, time: time);
    if (showTorch) {
      _torchInLeftHand(canvas, torchLevel,
          time: time, torchPhase: torchPhase);
    }
    canvas.restore();
  }

  static void drawBuilder(Canvas canvas, {
    bool flipX = false,
    double walkPhase = 0,
    double moveIntensity = 0.0,
    bool working = false,
    NpcVisual? visual,
    double time = 0,
    double torchLevel = 0,
    double torchPhase = 0,
    /// Hane aksan rengi — göğüsteki çapraz kuşak (bkz. [houseAccentColor]).
    Color? houseAccent,
    bool primitiveClothing = false,
  }) {
    _accent = houseAccent;
    _primitiveClothing = primitiveClothing;
    canvas.save();
    if (flipX) canvas.scale(-1, 1);
    _Anim anim;
    if (working) {
      final s = sin(walkPhase);
      anim = _Anim(0, 0, s * 0.10, s * 0.52, 0);
    } else {
      anim = _Anim.compute(walkPhase, moveIntensity);
    }
    final showTorch = torchLevel > 0.02 && !working;
    if (showTorch) anim = anim.copyWith(armL: _kTorchArmAngle);
    if (primitiveClothing) {
      _primitiveNpc(canvas, anim, visual ?? _fallbackVisual, time,
          rightItem: working
              ? (arm) => ToolRenderer.drawHammer(arm, scale: 1.15)
              : null);
      if (showTorch) {
        _torchInLeftHand(canvas, torchLevel,
            time: time, torchPhase: torchPhase);
      }
      canvas.restore();
      return;
    }
    _builder(canvas, anim, working: working, v: visual, time: time);
    if (showTorch) {
      _torchInLeftHand(canvas, torchLevel,
          time: time, torchPhase: torchPhase);
    }
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

  // ── Yeni meslek renk imzaları — hiçbiri mevcut meslekle çakışmaz ──────────
  /// Rahip: çivit-arduvaz cüppe (eski büyücünün lacivert kaftanının yerine).
  static const _kPriestRobe    = Color(0xFF3E4560);
  /// Çoban: boyanmamış ham yün (üstüne kahve post yelek).
  static const _kShepherdWool  = Color(0xFFCFC3A8);
  /// Avcı: koyu orman yeşili kukuleta/pelerin.
  static const _kHunterGreen   = Color(0xFF2E4632);
  /// Değirmenci: kül-bej iş kumaşı (üstüne UNLU beyaz önlük — imza).
  static const _kMillerCloth   = Color(0xFF8A8577);
  static const _kFlourWhite    = Color(0xFFE4DECC);
  /// Hancı: şarap kırmızısı yelek (üstüne beyaz önlük).
  static const _kInnkeeperWine = Color(0xFF6A3A3A);

  // ─── PAINT YARDIMCILARI ───────────────────────────────────────────────────
  // PERF: Her çağrıda yeni Paint yerine 4 önbellekli statik instance — yalnız
  // color/strokeWidth mutate edilir (style/AA/join/cap bir kez set). Tüm
  // kullanımlar inline `drawX(..., _f(color))` formunda ve paint çizimde
  // anında tüketilir → tek paylaşımlı instance güvenli (iki sonuç asla aynı
  // anda yaşamaz). ~230 alloc/NPC/frame GC baskısını ortadan kaldırır.
  static final Paint _fPaint = Paint()
    ..style = PaintingStyle.fill
    ..isAntiAlias = false;
  static Paint _f(Color c) => _fPaint..color = c;

  static final Paint _sPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.miter
    ..strokeCap = StrokeCap.square
    ..isAntiAlias = false;
  static Paint _s(Color c, [double w = 1.0]) =>
      _sPaint..color = c..strokeWidth = w;

  // ── Yumuşak (anti-aliased) paint'ler — yalnızca yüz/ifade için ───────────
  // Gövde pixel-art kalır (sert kenar); yüz tatlı/yuvarlak olsun diye AA.
  static final Paint _faPaint = Paint()
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;
  static Paint _fa(Color c) => _faPaint..color = c;

  static final Paint _saPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;
  static Paint _sa(Color c, [double w = 1.0]) =>
      _saPaint..color = c..strokeWidth = w;

  // ─── ORTAK PARÇALAR ───────────────────────────────────────────────────────

  /// Çizilmekte olan NPC'nin hane aksan rengi — null ise kuşak çizilmez.
  ///
  /// INVARIANT: her public giriş noktası ([draw], [drawSleeping] ve iş sprite'ı
  /// çizicileri) İLK satırında bunu set eder. Böylece bir önceki NPC'nin rengi
  /// sızamaz; ayrı bir "temizle" adımına güvenilmez. Renderer zaten tümüyle
  /// static ve tek karede tek NPC çiziliyor — rengi 15 helper'a parametre
  /// olarak threadlemek yerine tek alan.
  static Color? _accent;

  /// Temas gölgesi — yumuşak elips, ışık vektörüne göre hafif sağa-aşağı
  /// kaydırılmış (binaların drop shadow yönüyle aynı).
  ///
  /// Eski hali sert bir dikdörtgendi ve [anim] ile hiç değişmiyordu; figür
  /// zıplarken gölge sabit kaldığı için karakterler yerde durmuyor, "yüzüyor"
  /// gibi görünüyordu. Artık bob/sway ile küçülüp soluklaşır → temas hissi.
  static final Paint _shadowPaint = Paint()..isAntiAlias = true;

  static void _shadow(Canvas c, [_Anim? anim]) {
    // bob negatif = gövde yukarıda. Yükseldikçe gölge küçülür + soluklaşır.
    final lift = anim == null ? 0.0 : (-anim.bob).clamp(0.0, 6.0);
    final k = 1.0 - lift * 0.055; // 1.0 → ~0.67
    final cx = 2.0 + (anim?.sway ?? 0.0) * 0.35;
    final outer = Rect.fromCenter(
        center: Offset(cx, -0.5), width: 27 * k, height: 9.5 * k);
    c.drawOval(outer,
        _shadowPaint..color = Color.fromARGB((0x30 * k).round(), 0, 0, 0));
    // Çekirdek — ayak dibinde koyu küçük leke; temas noktasını çiviler.
    c.drawOval(
        Rect.fromCenter(
            center: outer.center,
            width: outer.width * 0.50,
            height: outer.height * 0.50),
        _shadowPaint..color = Color.fromARGB((0x2A * k).round(), 0, 0, 0));
  }

  /// Gövde transform — bacaklar ve gölge yere sabit kalır, üst gövde
  /// (torso + kol + kafa) sway (yan), lean (öne eğilme), bob (dikey),
  /// torsoTwist (yan twist) uygular.
  /// Çağırılan kod c.save() yapmış olmalı; restore yine kendi sorumluluğunda.
  static void _applyTorsoTransform(Canvas c, _Anim anim) {
    if (anim.sway != 0) c.translate(anim.sway, 0);
    if (anim.lean != 0) {
      c.translate(0, -36);
      c.rotate(anim.lean);
      c.translate(0, 36);
    }
    // Twist: omuz hizasında pivot, walking iken hafif yan rotation.
    if (anim.torsoTwist != 0) {
      c.translate(0, -28);
      c.rotate(anim.torsoTwist);
      c.translate(0, 28);
    }
    if (anim.bob != 0) c.translate(0, anim.bob);
  }

  /// Yumuşak yuvarlak kafa, tatlı parlayan göz ve gülümseme (visual'sız fallback).
  static void _head(Canvas c, Color skin, {double y = -80}) {
    final faceR = RRect.fromRectAndCorners(
      Rect.fromLTWH(-9, y - 10, 18, 20),
      topLeft: const Radius.circular(3),
      topRight: const Radius.circular(3),
      bottomLeft: const Radius.circular(6),
      bottomRight: const Radius.circular(6),
    );
    c.drawRRect(faceR, _fa(skin));
    c.drawRRect(faceR, _sa(_outline));
    _cuteEye(c, -6.4, y, const Color(0xFF6A4A30));
    _cuteEye(c,  2.4, y, const Color(0xFF6A4A30));
    _smile(c, y);
  }

  /// Animasyonlu bacak: hip pivot (hipX, −36).
  /// Bacak + bot tam olarak yere (origin y=0) ulaşır; gölge orada çizilir.
  static void _leg(Canvas c, double hipX, double angle, Color hose, Color boot) {
    c.save();
    c.translate(hipX, -36);
    c.rotate(angle);
    c.drawRect(const Rect.fromLTWH(-4, 0, 8, 32), _f(hose));
    c.drawRect(const Rect.fromLTWH(-5, 29, 10, 7), _f(boot));
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

  // ─── 1. ÇIFTÇI ────────────────────────────────────────────────────────────
  static void _farmer(Canvas c, _Anim anim,
      {bool carryingWater = false, NpcVisual? v, double time = 0}) {
    final tunic = v != null ? _cloth(_linen, v.clothingShift) : _linen;
    final hose  = v != null ? _cloth(_woolBrown, v.clothingShift * 0.5) : _woolBrown;
    final hat   = v != null ? _cloth(_straw, v.clothingShift * 0.4) : _straw;
    final skin  = v?.skin ?? _skin1;
    _shadow(c, anim);
    _shadedLeg(c, -6, anim.legL, hose, _leatherDk, legLift: anim.legLiftL);
    _shadedLeg(c,  6, anim.legR, hose, _leatherDk, legLift: anim.legLiftR);
    c.save();
    _applyTorsoTransform(c, anim);
    _shadedTunic(c, tunic);
    _shadedArm(c, -15, anim.armL, tunic, skin);
    // Sulama turunda sağ elde su kovası; değilse boş el (idle/hasat).
    _shadedArm(c, 15, anim.armR, tunic, skin,
        carryingWater ? ToolRenderer.drawWaterbucket : null);
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
  static void _merchant(Canvas c, _Anim anim) {
    _shadow(c, anim);
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
    _shadow(c, anim);
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
    _shadow(c, anim);
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

  // ─── 7. MADENCİ ───────────────────────────────────────────────────────────
  static void _miner(Canvas c, _Anim anim) {
    _shadow(c, anim);
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
    NpcVisual? visual,
    double time = 0,
    double torchLevel = 0,
    double torchPhase = 0,
    /// Hane aksan rengi — göğüsteki çapraz kuşak (bkz. [houseAccentColor]).
    Color? houseAccent,
    bool primitiveClothing = false,
  }) {
    _accent = houseAccent;
    _primitiveClothing = primitiveClothing;
    canvas.save();
    if (flipX) canvas.scale(-1, 1);

    _Anim anim;
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
    final showTorch = torchLevel > 0.02 && !mining;
    if (showTorch) anim = anim.copyWith(armL: _kTorchArmAngle);
    final armRAngle = anim.armR;
    final armLAngle = anim.armL;

    if (primitiveClothing) {
      _primitiveNpc(canvas, anim, visual ?? _fallbackVisual, time,
          rightItem: ToolRenderer.drawPickaxe);
      if (showTorch) {
        _torchInLeftHand(canvas, torchLevel,
            shoulderX: -16, time: time, torchPhase: torchPhase);
      }
      canvas.restore();
      return;
    }

    final shirtCol  = visual != null
        ? _cloth(const Color(0xFF4A4840), visual.clothingShift)
        : const Color(0xFF4A4840);
    final vestCol = visual != null
        ? _cloth(const Color(0xFF6A4A28), visual.clothingShift * 0.5)
        : const Color(0xFF6A4A28);
    final hoseCol = visual != null
        ? _cloth(const Color(0xFF3A3028), visual.clothingShift * 0.4)
        : const Color(0xFF3A3028);
    final skin = visual?.skin ?? _skin2;

    _shadow(canvas, anim);
    _shadedLeg(canvas, -6, anim.legL, hoseCol, _leatherDk, legLift: anim.legLiftL);
    _shadedLeg(canvas,  6, anim.legR, hoseCol, _leatherDk, legLift: anim.legLiftR);
    canvas.save();
    _applyTorsoTransform(canvas, anim);
    _shadedTorso(canvas, const Rect.fromLTWH(-13, -68, 26, 32), shirtCol);
    // Deri yelek
    _shadedRect(canvas, const Rect.fromLTWH(-10, -67, 20, 30), vestCol);
    canvas.drawRect(const Rect.fromLTWH(-2, -58, 4, 14), _f(_leatherDk));

    _shadedArm(canvas, -16, armLAngle, shirtCol, skin);
    _shadedArm(canvas,  16, armRAngle, shirtCol, skin,
        ToolRenderer.drawPickaxe);

    if (visual != null) {
      _shadedHead(canvas, visual, time);
    } else {
      _head(canvas, skin);
    }
    // Kask
    _shadedRect(canvas, const Rect.fromLTWH(-12, -96, 24,  6), const Color(0xFF2A2010));
    _shadedRect(canvas, const Rect.fromLTWH( -8, -108, 16, 12), const Color(0xFF2A2010));
    canvas.drawRect(const Rect.fromLTWH( -3, -108, 6, 4), _f(const Color(0xFFFFDD44)));
    canvas.restore();

    if (showTorch) {
      _torchInLeftHand(canvas, torchLevel,
          shoulderX: -16, time: time, torchPhase: torchPhase);
    }
    canvas.restore();
  }

  // ─── 10. ODUNCU ────────────────────────────────────────────────────────────

  static void drawWoodcutter(Canvas canvas, {
    bool flipX = false,
    double walkPhase = 0,
    double moveIntensity = 0.0,
    bool chopping = false,
    double chopPhase = 0,
    NpcVisual? visual,
    double time = 0,
    double torchLevel = 0,
    double torchPhase = 0,
    /// Hane aksan rengi — göğüsteki çapraz kuşak (bkz. [houseAccentColor]).
    Color? houseAccent,
    bool primitiveClothing = false,
  }) {
    _accent = houseAccent;
    _primitiveClothing = primitiveClothing;
    canvas.save();
    if (flipX) canvas.scale(-1, 1);

    // Walking/idle iken standart _Anim (lean/sway/bob dahil).
    // Chopping iken sadece kol açıları custom; lean/sway/bob = 0.
    _Anim anim;
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
    final showTorch = torchLevel > 0.02 && !chopping;
    if (showTorch) anim = anim.copyWith(armL: _kTorchArmAngle);
    final armRAngle = anim.armR;
    final armLAngle = anim.armL;

    if (primitiveClothing) {
      _primitiveNpc(canvas, anim, visual ?? _fallbackVisual, time,
          rightItem: ToolRenderer.drawAxe);
      if (showTorch) {
        _torchInLeftHand(canvas, torchLevel,
            shoulderX: -16, time: time, torchPhase: torchPhase);
      }
      canvas.restore();
      return;
    }

    final hoseCol = visual != null
        ? _cloth(_woolDark, visual.clothingShift * 0.5) : _woolDark;
    final shirtColor = visual != null
        ? _cloth(const Color(0xFF8B2020), visual.clothingShift) : const Color(0xFF8B2020);
    const shirtDark  = Color(0xFF5A1010);
    final skin = visual?.skin ?? _skin1;

    _shadow(canvas, anim);
    _shadedLeg(canvas, -6, anim.legL, hoseCol, _leatherDk, legLift: anim.legLiftL);
    _shadedLeg(canvas,  6, anim.legR, hoseCol, _leatherDk, legLift: anim.legLiftR);

    canvas.save();
    _applyTorsoTransform(canvas, anim);
    _shadedTorso(canvas, const Rect.fromLTWH(-13, -68, 26, 32), shirtColor);
    for (final v in [-62.0, -54.0, -46.0]) {
      canvas.drawRect(Rect.fromLTWH(-12, v, 24, 2), _f(const Color(0xFF6A1010)));
    }
    canvas.drawRect(const Rect.fromLTWH(-1, -68, 2, 32), _f(shirtDark));
    _shadedRect(canvas, const Rect.fromLTWH(-9, -50, 18, 4), _leather);

    // Sol kol
    _shadedArm(canvas, -16, armLAngle, shirtColor, skin);
    // Sağ kol + balta PNG
    _shadedArm(canvas, 16, armRAngle, shirtColor, skin, ToolRenderer.drawAxe);

    if (visual != null) {
      _shadedHead(canvas, visual, time);
    } else {
      _head(canvas, skin);
    }
    // Basit bere / bandana
    _shadedRect(canvas, const Rect.fromLTWH(-10, -98, 20, 18), const Color(0xFF4A3010));
    canvas.restore();

    if (showTorch) {
      _torchInLeftHand(canvas, torchLevel,
          shoulderX: -16, time: time, torchPhase: torchPhase);
    }
    canvas.restore();
  }

  // ─── 9. BALIKÇI (idle draw — VillagerType.fisher için) ────────────────────
  static void _fisherIdle(Canvas c, _Anim anim) {
    _shadow(c, anim);
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
    NpcVisual? visual,
    double time = 0,
    double torchLevel = 0,
    double torchPhase = 0,
    /// Hane aksan rengi — göğüsteki çapraz kuşak (bkz. [houseAccentColor]).
    Color? houseAccent,
    bool primitiveClothing = false,
  }) {
    _accent = houseAccent;
    _primitiveClothing = primitiveClothing;
    canvas.save();
    if (flipX) canvas.scale(-1, 1);
    final shirtCol = visual != null
        ? _cloth(const Color(0xFF5A7888), visual.clothingShift) : const Color(0xFF5A7888);
    final vestCol  = visual != null
        ? _cloth(const Color(0xFF2A3840), visual.clothingShift * 0.5) : const Color(0xFF2A3840);
    final hoseCol  = visual != null
        ? _cloth(const Color(0xFF3A5060), visual.clothingShift * 0.4) : const Color(0xFF3A5060);
    final skin = visual?.skin ?? _skin1;

    _Anim anim;
    final double armRAngle;
    final double castAngle;
    double leftSwing;
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
    final showTorch = torchLevel > 0.02 && !fishing;
    if (showTorch) {
      anim = anim.copyWith(armL: _kTorchArmAngle);
      leftSwing = _kTorchArmAngle;
    }

    if (primitiveClothing) {
      _primitiveNpc(canvas, anim, visual ?? _fallbackVisual, time,
          rightItem: (arm) => ToolRenderer.drawRod(arm,
              castAngle: castAngle));
      if (showTorch) {
        _torchInLeftHand(canvas, torchLevel,
            shoulderX: -15, time: time, torchPhase: torchPhase);
      }
      canvas.restore();
      return;
    }

    _shadow(canvas, anim);
    _shadedLeg(canvas, -6, anim.legL, hoseCol, _leatherDk, legLift: anim.legLiftL);
    _shadedLeg(canvas,  6, anim.legR, hoseCol, _leatherDk, legLift: anim.legLiftR);

    canvas.save();
    _applyTorsoTransform(canvas, anim);
    _shadedTorso(canvas, const Rect.fromLTWH(-12, -68, 24, 32), shirtCol);
    _shadedRect(canvas, const Rect.fromLTWH(-9, -67, 18, 30), vestCol);

    _shadedArm(canvas, -15, leftSwing, shirtCol, skin);
    // Sağ kol + olta
    _shadedArm(canvas,  15, armRAngle, shirtCol, skin,
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

    if (visual != null) {
      _shadedHead(canvas, visual, time);
    } else {
      _head(canvas, skin);
    }
    // Şapka
    _shadedRect(canvas, const Rect.fromLTWH(-14, -98, 28, 6), const Color(0xFF4A3A20));
    _shadedRect(canvas, const Rect.fromLTWH( -8, -110, 16, 12), const Color(0xFF5A4A28));
    canvas.restore();

    if (showTorch) {
      _torchInLeftHand(canvas, torchLevel,
          shoulderX: -15, time: time, torchPhase: torchPhase);
    }
    canvas.restore();
  }

  // ─── ÇOBAN ────────────────────────────────────────────────────────────────
  // drawWoodcutter pattern'ı; balta yerine değnek, kıyafet yeşil yelek + bej
  // gömlek. milking iken kollar inek yönünde aşağı eğilir, gövde hafif öne.
  static void drawShepherd(Canvas canvas, {
    bool   flipX         = false,
    double walkPhase     = 0,
    double moveIntensity = 0.0,
    bool   milking       = false,
    double milkPhase     = 0,
    NpcVisual? visual,
    double time = 0,
    double torchLevel = 0,
    double torchPhase = 0,
    /// Hane aksan rengi — göğüsteki çapraz kuşak (bkz. [houseAccentColor]).
    Color? houseAccent,
    bool primitiveClothing = false,
  }) {
    _accent = houseAccent;
    _primitiveClothing = primitiveClothing;
    canvas.save();
    if (flipX) canvas.scale(-1, 1);

    _Anim anim;
    final double armRAngle;
    double armLAngle;
    if (milking) {
      // Eller aşağı sabit, hafif ritmik salınım (sağım hareketi)
      final wobble = sin(milkPhase * 2) * 0.12;
      anim = const _Anim(0, 0, 0, 0, 1.5, lean: 0.18);
      armRAngle = 1.10 + wobble;
      armLAngle = 1.10 - wobble;
    } else {
      anim = _Anim.compute(walkPhase, moveIntensity);
      armRAngle = anim.armR;
      armLAngle = anim.armL;
    }
    final showTorch = torchLevel > 0.02 && !milking;
    if (showTorch) {
      anim = anim.copyWith(armL: _kTorchArmAngle);
      armLAngle = _kTorchArmAngle;
    }

    if (primitiveClothing) {
      _primitiveNpc(canvas, anim, visual ?? _fallbackVisual, time,
          rightItem: milking ? null : (arm) {
            arm.drawRect(const Rect.fromLTWH(-1, -32, 3, 56),
                _f(const Color(0xFF6A4A20)));
            arm.drawRect(const Rect.fromLTWH(-3, -34, 6, 6),
                _f(const Color(0xFF6A4A20)));
          });
      if (showTorch) {
        _torchInLeftHand(canvas, torchLevel,
            shoulderX: -16, time: time, torchPhase: torchPhase);
      }
      canvas.restore();
      return;
    }

    final hoseCol = visual != null
        ? _cloth(const Color(0xFF4A3818), visual.clothingShift * 0.4) : const Color(0xFF4A3818);
    final shirtColor = visual != null
        ? _cloth(const Color(0xFFC8B080), visual.clothingShift) : const Color(0xFFC8B080);
    final vestColor = visual != null
        ? _cloth(const Color(0xFF3A6A40), visual.clothingShift * 0.6) : const Color(0xFF3A6A40);
    final skin = visual?.skin ?? _skin1;

    _shadow(canvas, anim);
    _shadedLeg(canvas, -6, anim.legL, hoseCol, _leatherDk, legLift: anim.legLiftL);
    _shadedLeg(canvas,  6, anim.legR, hoseCol, _leatherDk, legLift: anim.legLiftR);

    canvas.save();
    _applyTorsoTransform(canvas, anim);
    _shadedTorso(canvas, const Rect.fromLTWH(-13, -68, 26, 32), shirtColor);
    _shadedRect(canvas, const Rect.fromLTWH(-10, -67, 20, 28), vestColor);
    // Kemer
    _shadedRect(canvas, const Rect.fromLTWH(-11, -42, 22, 4), _leatherDk);

    _shadedArm(canvas, -16, armLAngle, shirtColor, skin);
    // Sağ elde çoban değneği (basit kavisli sopa). Milking'de çizmiyoruz —
    // değnek yere bırakılmış sayılır.
    if (!milking) {
      _shadedArm(canvas, 16, armRAngle, shirtColor, skin, (arm) {
        arm.drawRect(const Rect.fromLTWH(-1, -32, 3, 56), _f(const Color(0xFF6A4A20)));
        arm.drawRect(const Rect.fromLTWH(-3, -34, 6, 6),  _f(const Color(0xFF6A4A20)));
      });
    } else {
      _shadedArm(canvas, 16, armRAngle, shirtColor, skin);
    }

    if (visual != null) {
      _shadedHead(canvas, visual, time);
    } else {
      _head(canvas, skin);
    }
    // Hasır şapka (geniş kenar + üst)
    _shadedRect(canvas, const Rect.fromLTWH(-14, -94, 28, 4), _straw);
    _shadedRect(canvas, const Rect.fromLTWH(-9, -104, 18, 10), _straw);
    canvas.restore();

    if (showTorch) {
      _torchInLeftHand(canvas, torchLevel,
          shoulderX: -16, time: time, torchPhase: torchPhase);
    }
    canvas.restore();
  }

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
  static void _shadedRect(Canvas c, Rect r, Color base) {
    c.drawRect(r, _f(base));
    if (r.width >= 10) {
      // GENİŞ yüzey (gövde, şapka, çanta) → yatay blok ayrımı: üstten gelen
      // ışık, alt yarı gölgede.
      c.drawRect(
          Rect.fromLTRB(r.left, r.top + r.height * 0.55, r.right, r.bottom),
          _f(darker(base, 0.20)));
      c.drawRect(Rect.fromLTRB(r.left, r.top, r.right, r.top + r.height * 0.22),
          _f(lighter(base, 0.13)));
      // Sağ kenar ışık düşüşü — alpha ki alt/üst blok tonları korunsun.
      c.drawRect(
          Rect.fromLTRB(r.right - r.width * 0.20, r.top, r.right, r.bottom),
          _f(const Color(0x24000000)));
    } else {
      // DAR uzuv (kol, bacak, el) → DİKEY ayrım: silindir shading. Yatay blok
      // burada hacim değil, "çizme üstü / manşet" gibi sahte bir detay çizgisi
      // okunuyordu — uzuv boyunca ton sabit, yanları koyu olmalı.
      c.drawRect(Rect.fromLTRB(r.left, r.top, r.left + r.width * 0.34, r.bottom),
          _f(lighter(base, 0.10)));
      c.drawRect(
          Rect.fromLTRB(r.right - r.width * 0.30, r.top, r.right, r.bottom),
          _f(darker(base, 0.18)));
    }
    c.drawRect(r, _s(_outline));
  }

  /// Gövde — omuzdan bele daralan yamuk + hane kuşağı.
  ///
  /// Düz dikdörtgen gövde tüm meslekleri aynı dikey çubuğa çeviriyordu; oynanan
  /// zoom'da NPC'yi ayırt eden ilk şey siluet, taper onu geri veriyor. Dış hat
  /// AA'lı (yumuşak siluet), iç bloklar sert (pixel-art dili) — "yuvarlaklık
  /// dış hatta, içeride değil".
  static void _shadedTorso(Canvas c, Rect r, Color base, {double waist = 0.72}) {
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
    c.drawRect(Rect.fromLTRB(r.left, r.top + r.height * 0.55, r.right, r.bottom),
        _f(darker(base, 0.20)));
    c.drawRect(Rect.fromLTRB(r.left, r.top, r.right, r.top + r.height * 0.22),
        _f(lighter(base, 0.13)));
    c.drawRect(Rect.fromLTRB(r.right - r.width * 0.20, r.top, r.right, r.bottom),
        _f(const Color(0x24000000)));
    _houseSash(c, r, cx, ht, hb);
    c.restore();

    c.drawPath(p, _sa(_outline, 1.0));
  }

  /// Hane kuşağı — sol omuzdan sağ kalçaya doğygun renkli bant.
  /// Yatay kemer yerine ÇAPRAZ: siluette kırılma yapar, uzaktan da okunur.
  /// Renk soyaddan geliyor (bkz. [houseAccentColor]) → "şu adam Karaoğulları'ndan"
  /// bilgisi kozmetik değil, gözle okunan oyun bilgisi.
  static void _houseSash(
      Canvas c, Rect r, double cx, double ht, double hb) {
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
    c.drawLine(a.translate(0, 2.6), b.translate(0, 2.6),
        _sa(darker(acc, 0.24), 1.4));
  }

  /// Shaded leg — hip pivot rotation + 3-tone hose + boot.
  /// [legLift] adım atan ayağın yerden yükselmesi (negatif Y; walking iken
  /// adım atan bacak hafifçe kalkar, diğeri yerde basılı kalır).
  /// Bacak + bot tam olarak yere (origin y=0) ulaşır; gölge orada çizilir.
  static void _shadedLeg(Canvas c, double hipX, double angle,
      Color hose, Color boot, {double legLift = 0}) {
    c.save();
    c.translate(hipX, -36 - legLift);
    c.rotate(angle);
    _shadedRect(c, const Rect.fromLTWH(-4, 0, 8, 32), hose);
    _shadedRect(c, const Rect.fromLTWH(-5, 29, 10, 7), boot);
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
    _shadedTorso(c, const Rect.fromLTWH(-12, -68, 24, 32), cloth);
    // Kemer
    _shadedRect(c, const Rect.fromLTWH(-12, -50, 24, 5), _leather);
    // Toka — sabit küçük detay
    c.drawRect(const Rect.fromLTWH(-3, -50, 6, 5), _f(_leatherDk));
  }

  /// Per-NPC kafa: ten + saç (stil) + sakal (stil) + göz (renk) + blink.
  /// [time] blink animasyonu için zaman parametresi.
  /// [y] kafanın merkez Y koordinatı (default -80).
  static void _shadedHead(Canvas c, NpcVisual v, double time, {double y = -80}) {
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
    c.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(-7.5, y + 1, 3.5, 2.4), const Radius.circular(1.2)), _fa(blush));
    c.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(4, y + 1, 3.5, 2.4), const Radius.circular(1.2)), _fa(blush));

    // ── Gözler (büyük, parlak, glint'li) + blink ──────────────────────────
    // Blink: nadir, kısa.  sin > 0.96 → kapalı (≈0.6 sn / 8 sn döngü)
    final blinkRaw = sin(time * 0.78 + v.blinkPhase);
    if (blinkRaw > 0.96) {
      // Mutlu kapalı göz — yukarı kıvrık küçük yay ( ^ ^ )
      _happyClosedEye(c, -6.4, y);
      _happyClosedEye(c,  2.4, y);
    } else {
      _cuteEye(c, -6.4, y, v.eyes);
      _cuteEye(c,  2.4, y, v.eyes);
    }

    // ── Kaş — ince, hafif kalkık (masum/yumuşak ifade) ────────────────────
    final brow = darker(v.hair, 0.05);
    c.drawRect(Rect.fromLTWH(-6.4, y - 5, 3, 1), _fa(brow));
    c.drawRect(Rect.fromLTWH( 3.4, y - 5, 3, 1), _fa(brow));

    // ── Ağız — küçük gülümseme (tam sakal yoksa görünür) ──────────────────
    if (v.beardStyle != BeardStyle.full) {
      _smile(c, y);
    }
  }

  /// Tatlı göz: koyu yuvarlak çerçeve + renkli iris + beyaz glint (parlama).
  /// Glint, "canlı/sevimli" hissinin ana sinyali.
  static void _cuteEye(Canvas c, double ex, double y, Color iris) {
    c.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(ex, y - 3.5, 4, 5), const Radius.circular(1.8)), _fa(_outline));
    c.drawRect(Rect.fromLTWH(ex + 0.8, y - 2.4, 2.4, 3), _fa(iris));
    c.drawRect(Rect.fromLTWH(ex + 0.8, y - 2.8, 1.4, 1.4), _fa(const Color(0xFFFFFFFF)));
  }

  /// Mutlu kapalı göz — yukarı kıvrık küçük yay (blink anı).
  static void _happyClosedEye(Canvas c, double ex, double y) {
    c.drawPath(
      Path()
        ..moveTo(ex, y - 1)
        ..quadraticBezierTo(ex + 2, y - 3.4, ex + 4, y - 1),
      _sa(_outline, 1.2),
    );
  }

  /// Küçük yukarı kıvrık gülümseme.
  static void _smile(Canvas c, double y) {
    c.drawPath(
      Path()
        ..moveTo(-3, y + 4.6)
        ..quadraticBezierTo(0, y + 7, 3, y + 4.6),
      _sa(_outline, 1.2),
    );
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

  // ─── KÖYLÜ (mesleksiz — çocuk/genç evresi) ────────────────────────────────
  // Tipten bağımsız standart keten tunik + yün pantolon, alet/şapka yok.
  // [child] true ise kafa büyük çizilir (çocuk oranı).
  static void _primitiveNpc(Canvas c, _Anim anim, NpcVisual v, double time,
      {bool child = false, void Function(Canvas)? rightItem}) {
    final hide = _cloth(const Color(0xFF8A6945), v.clothingShift * 0.35);
    final hideDark = darker(hide, 0.24);
    final legWrap = _cloth(const Color(0xFF5C4932), v.clothingShift * 0.20);

    _shadow(c, anim);
    _shadedLeg(c, -6, anim.legL, legWrap, _leatherDk,
        legLift: anim.legLiftL);
    _shadedLeg(c, 6, anim.legR, legWrap, _leatherDk,
        legLift: anim.legLiftR);

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
    c.drawLine(const Offset(-10, -68), const Offset(9, -43),
        _s(const Color(0xFFB49364), 2.0));
    // Ayrı tonlu yamalar kaba, elde birleştirilmiş silueti okunur kılar.
    c.drawRect(const Rect.fromLTWH(-10, -61, 7, 6), _f(hideDark));
    c.drawRect(const Rect.fromLTWH(4, -45, 6, 5),
        _f(lighter(hide, 0.12)));
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

  static void _peasantNpc(Canvas c, _Anim anim, NpcVisual v, double time,
      {bool child = false}) {
    final tunicBase = _cloth(_linen,     v.clothingShift);
    final hoseBase  = _cloth(_woolBrown, v.clothingShift * 0.6);

    _shadow(c, anim);
    _shadedLeg(c, -6, anim.legL, hoseBase, _leatherDk, legLift: anim.legLiftL);
    _shadedLeg(c,  6, anim.legR, hoseBase, _leatherDk, legLift: anim.legLiftR);

    c.save();
    _applyTorsoTransform(c, anim);
    _shadedTunic(c, tunicBase);
    _shadedArm(c, -15, anim.armL, tunicBase, v.skin);
    _shadedArm(c,  15, anim.armR, tunicBase, v.skin);
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

  // ─── ÇIFTÇI (yeni — per-NPC görsel + akıcı hareket) ───────────────────────
  static void _farmerNpc(Canvas c, _Anim anim, NpcVisual v, double time) {
    // Kıyafet renkleri — baz + tint shift per-NPC
    final tunicBase = _cloth(_linen,     v.clothingShift);
    final hoseBase  = _cloth(_woolBrown, v.clothingShift * 0.6);
    final hatStraw  = _cloth(_straw,     v.clothingShift * 0.5);

    _shadow(c, anim);
    // Bacaklar gövde lean/sway'ından bağımsız — ayak yerde sabit
    _shadedLeg(c, -6, anim.legL, hoseBase, _leatherDk, legLift: anim.legLiftL);
    _shadedLeg(c,  6, anim.legR, hoseBase, _leatherDk, legLift: anim.legLiftR);

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

  // ─── TÜCCAR (yeni — shaded + per-NPC görsel) ──────────────────────────────
  static void _merchantNpc(Canvas c, _Anim anim, NpcVisual v, double time) {
    final cloakBase = _cloth(const Color(0xFF4A5030), v.clothingShift);
    final hoseBase  = _cloth(_woolDark, v.clothingShift * 0.6);
    final hoodBase  = darker(cloakBase, 0.06);

    _shadow(c, anim);
    _shadedLeg(c, -6, anim.legL, hoseBase, _leatherDk, legLift: anim.legLiftL);
    _shadedLeg(c,  6, anim.legR, hoseBase, _leatherDk, legLift: anim.legLiftR);

    c.save();
    _applyTorsoTransform(c, anim);

    // Pelerin (gövde)
    _shadedTorso(c, const Rect.fromLTWH(-14, -68, 28, 32), cloakBase);
    // Yaka linen
    _shadedRect(c, const Rect.fromLTWH(-8, -42, 16, 6), _linen);
    // Broş
    _shadedRect(c, const Rect.fromLTWH(-3, -66, 6, 6), const Color(0xFFB0900A));

    _shadedArm(c, -16, anim.armL, cloakBase, v.skin);
    _shadedArm(c,  16, anim.armR, cloakBase, v.skin);

    // Çanta
    _shadedRect(c, const Rect.fromLTWH(14, -50, 12, 14), _leather);
    c.drawRect(const Rect.fromLTWH(14, -50, 12, 3), _f(_leatherDk));
    c.drawLine(const Offset(14, -52), const Offset(8, -62), _s(_leatherDk, 1.2));

    _shadedHead(c, v, time);

    // Kapüşon — saç görünür kalsın diye arka katman
    _shadedRect(c, const Rect.fromLTWH(-11, -98, 22, 14), hoodBase);
    c.drawRect(const Rect.fromLTWH(-10, -92, 20, 8), _f(darker(hoodBase, 0.14)));
    c.restore();
  }

  // ─── DEMIRCI (yeni — shaded + per-NPC görsel) ──────────────────────────────
  static void _blacksmithNpc(Canvas c, _Anim anim, NpcVisual v, double time) {
    final shirtBase = _cloth(const Color(0xFF5A3818), v.clothingShift);
    final hoseBase  = _cloth(const Color(0xFF3A3028), v.clothingShift * 0.5);
    const apronBase = _leather;

    _shadow(c, anim);
    _shadedLeg(c, -6, anim.legL, hoseBase, _leatherDk, legLift: anim.legLiftL);
    _shadedLeg(c,  6, anim.legR, hoseBase, _leatherDk, legLift: anim.legLiftR);

    c.save();
    _applyTorsoTransform(c, anim);

    // Tunik
    _shadedTorso(c, const Rect.fromLTWH(-14, -68, 28, 32), shirtBase);
    // Önlük (deri)
    _shadedRect(c, const Rect.fromLTWH(-9, -66, 18, 30), apronBase);
    // Askılar
    c.drawLine(const Offset(-7, -66), const Offset(0, -76), _s(_leather, 2.5));
    c.drawLine(const Offset( 7, -66), const Offset(0, -76), _s(_leather, 2.5));

    _shadedArm(c, -18, anim.armL, shirtBase, v.skin);
    _shadedArm(c,  18, anim.armR, shirtBase, v.skin);

    _shadedHead(c, v, time, y: -82);

    // Deri kukuleta
    _shadedRect(c, const Rect.fromLTWH(-10, -100, 20, 14), _leather);
    c.restore();
  }

  // ─── MUHAFIZ (yeni — shaded + per-NPC görsel) ──────────────────────────────
  static void _guardNpc(Canvas c, _Anim anim, NpcVisual v, double time) {
    final gambBase  = _cloth(const Color(0xFFB8A878), v.clothingShift);
    final hoseBase  = _cloth(const Color(0xFF504838), v.clothingShift * 0.4);
    final gambStripe = darker(gambBase, 0.20);

    _shadow(c, anim);
    _shadedLeg(c, -6, anim.legL, hoseBase, const Color(0xFF303028), legLift: anim.legLiftL);
    _shadedLeg(c,  6, anim.legR, hoseBase, const Color(0xFF303028), legLift: anim.legLiftR);

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
    _shadedRect(c, const Rect.fromLTWH( 12, -74, 16, 10), _leather);

    // Sol kol + kalkan
    _shadedArmWithShield(c, -20, anim.armL, gambBase, v.skin);
    // Sağ kol + mızrak
    _shadedArm(c, 20, anim.armR, gambBase, v.skin, (arm) {
      _shadedRect(arm, const Rect.fromLTWH(3, -40, 3, 80), _woodBrown);
      _shadedRect(arm, const Rect.fromLTWH(1, -52, 7, 12), _ironGrey);
    });

    _shadedHead(c, v, time);

    // Demir miğfer — başı kaplar (saçın üstüne)
    _shadedRect(c, const Rect.fromLTWH(-11, -100, 22, 18), _ironGrey);
    c.drawRect(const Rect.fromLTWH(-13, -92, 26, 4), _f(_ironGrey));
    c.drawRect(const Rect.fromLTWH( -2, -92,  4, 10), _f(_ironDk));
    c.restore();
  }

  static void _shadedArmWithShield(Canvas c, double shoulderX, double angle,
      Color sleeve, Color skin) {
    c.save();
    c.translate(shoulderX, -68);
    c.rotate(angle);
    _shadedRect(c, const Rect.fromLTWH(-4, 0, 8, 16), sleeve);
    _shadedRect(c, const Rect.fromLTWH(-4, 16, 8, 6), skin);
    // Kalkan
    _shadedRect(c, const Rect.fromLTWH(-16, 4, 22, 22), const Color(0xFF8B4513));
    // Merkez kabara
    _shadedRect(c, const Rect.fromLTWH(-8, 10, 8, 8), _ironGrey);
    c.restore();
  }

  // ─── İMPARATORLUK ASKERİ (dış güç — kostüm override) ──────────────────────
  // Köyün muhafızından kasıtlı AYRIK: soğuk çelik kürişit + kızıl tabard +
  // tam miğfer. Komutan uzun kızıl sorguç + pelerin taşır → heyetin lideri
  // gözle ayrışır. Köylü paletinin sıcak ahşap/keten tonlarından uzak.
  static const _impSteel   = Color(0xFF6A707C); // soğuk çelik plaka
  static const _impSteelDk = Color(0xFF3A3E47); // çelik gölge
  static const _impCrimson = Color(0xFF8E1B1B); // imparatorluk kızılı
  static const _impCrimDk  = Color(0xFF5A0F0F); // kızıl gölge
  static const _impGold    = Color(0xFFC8A042); // amblem altını

  static void _imperialSoldierNpc(Canvas c, _Anim anim, NpcVisual v, double time,
      {bool commander = false, bool attacking = false}) {
    final hose = _cloth(_impSteelDk, v.clothingShift * 0.3);

    // Saldırı modunda mızrak ileri DÜRTÜLÜR (jab) + gövde öne saldırgan eğilir.
    // ~1.5 rad mızrağı yatay-ileri çevirir; jab salınımı içeri/dışarı dürtme.
    final jab = sin(time * 8.0);
    final spearArm = attacking ? 1.5 + jab * 0.30 : anim.armR;
    final atkLean = attacking ? 0.18 + jab.clamp(0.0, 1.0) * 0.07 : 0.0;

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

    _shadedLeg(c, -6, anim.legL, hose, const Color(0xFF26282E), legLift: anim.legLiftL);
    _shadedLeg(c,  6, anim.legR, hose, const Color(0xFF26282E), legLift: anim.legLiftR);

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
    _shadedRect(c, const Rect.fromLTWH( 12, -75, 17, 11), _impSteel);

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
      arm.drawRect(const Rect.fromLTWH(2, -64, 5, 4), _f(lighter(_impSteel, 0.18)));
    });

    _shadedHead(c, v, time);

    // ── Tam miğfer (çelik) — başı kaplar ────────────────────────────────────
    _shadedRect(c, const Rect.fromLTWH(-11, -101, 22, 19), _impSteel);
    // Alın bandı + burun koruyucu.
    c.drawRect(const Rect.fromLTWH(-13, -92, 26, 4), _f(_impSteelDk));
    c.drawRect(const Rect.fromLTWH( -2, -93,  4, 12), _f(_impSteelDk));
    // Yanak plakaları (yüzü çerçeveler).
    c.drawRect(const Rect.fromLTWH(-12, -90, 3, 9), _f(_impSteel));
    c.drawRect(const Rect.fromLTWH(  9, -90, 3, 9), _f(_impSteel));

    if (commander) {
      // Komutan — uzun kızıl at-kılı sorguç (miğfer tepesinden yukarı).
      _shadedRect(c, const Rect.fromLTWH(-3, -118, 6, 18), _impCrimson);
      c.drawRect(const Rect.fromLTWH(-1, -118, 2, 18), _f(lighter(_impCrimson, 0.12)));
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
  static final NpcVisual _fallbackVisual = NpcVisual.fromSeed(0);

  // ─── RAHİP (eski büyücünün yerine — asa/sivri şapka YOK) ──────────────────
  /// Silüet imzası: uzun çivit cüppe + krem omuz atkısı (stola) + kukuleta +
  /// belde tespih. Büyü değil, inanç: ölçülü ve ağır.
  static void _priestNpc(Canvas c, _Anim anim, NpcVisual v, double time) {
    final robeBase = _cloth(_kPriestRobe, v.clothingShift);
    const stole = Color(0xFFDCD2BA); // krem atkı

    _shadow(c, anim);
    // Uzun cüppe → bacak salınımı bastırılmış (ağır kumaş)
    _shadedLeg(c, -5, anim.legL * 0.5, robeBase, _leatherDk, legLift: anim.legLiftL * 0.5);
    _shadedLeg(c,  5, anim.legR * 0.5, robeBase, _leatherDk, legLift: anim.legLiftR * 0.5);

    c.save();
    _applyTorsoTransform(c, anim);

    // Uzun cüppe (yere kadar)
    // Cüppe eteğe doğru AÇILIR (waist > 1) — diğer meslekler bele daralırken
    // rahibin silueti tersine genişler, uzaktan bile ayrışır.
    _shadedTorso(c, const Rect.fromLTWH(-12, -68, 24, 62), robeBase,
        waist: 1.22);
    // Krem stola — iki omuzdan aşağı inen atkı (rahibin imzası)
    _shadedRect(c, const Rect.fromLTWH(-7, -68, 4, 40), stole);
    _shadedRect(c, const Rect.fromLTWH( 3, -68, 4, 40), stole);
    // Bel kuşağı (kendir halat)
    _shadedRect(c, const Rect.fromLTWH(-12, -46, 24, 4), const Color(0xFF9A8A62));
    // Ayak ucu botları
    _shadedRect(c, const Rect.fromLTWH(-8, -8, 5, 6), _leatherDk);
    _shadedRect(c, const Rect.fromLTWH( 3, -8, 5, 6), _leatherDk);

    _shadedArm(c, -17, anim.armL, robeBase, v.skin);
    _shadedArm(c,  17, anim.armR, robeBase, v.skin);

    // Belde asılı tespih — küçük boncuk dizisi (sağ kalça)
    for (int i = 0; i < 4; i++) {
      c.drawRect(Rect.fromLTWH(10, -42 + i * 3.0, 2, 2),
          _f(const Color(0xFFC8A042)));
    }

    _shadedHead(c, v, time);

    // Kukuleta (cowl) — tepeyi örter + iki yandan yüzü çerçeveler (düz kutu DEĞİL)
    _shadedRect(c, const Rect.fromLTWH(-11, -98, 22, 11), robeBase); // tepe
    _shadedRect(c, const Rect.fromLTWH(-12, -92, 4, 15), robeBase);  // sol yanak
    _shadedRect(c, const Rect.fromLTWH(  8, -92, 4, 15), robeBase);  // sağ yanak
    c.restore();
  }

  // ─── ÇOBAN ────────────────────────────────────────────────────────────────
  /// Silüet imzası: ham yün tunik + kahve POST yelek (omuzları kabartır) +
  /// uzun kıvrık DEĞNEK (crook) + kenarlı hasır şapka.
  static void _shepherdNpc(Canvas c, _Anim anim, NpcVisual v, double time) {
    final woolBase = _cloth(_kShepherdWool, v.clothingShift);
    final peltBase = _cloth(const Color(0xFF6E5236), v.clothingShift * 0.5);
    final hoseBase = _cloth(_woolBrown, v.clothingShift * 0.4);

    _shadow(c, anim);
    _shadedLeg(c, -6, anim.legL, hoseBase, _leatherDk, legLift: anim.legLiftL);
    _shadedLeg(c,  6, anim.legR, hoseBase, _leatherDk, legLift: anim.legLiftR);

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
      _shadedRect(arm, const Rect.fromLTWH(-1, -42, 3, 80), _woodBrown);
      // Kıvrık uç — iki blokla "crook"
      _shadedRect(arm, const Rect.fromLTWH(-1, -46, 8, 3), _woodBrown);
      _shadedRect(arm, const Rect.fromLTWH( 4, -43, 3, 5), _woodBrown);
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
  static void _hunterNpc(Canvas c, _Anim anim, NpcVisual v, double time) {
    final cloakBase = _cloth(_kHunterGreen, v.clothingShift);
    final hoseBase  = _cloth(const Color(0xFF3E3628), v.clothingShift * 0.4);

    _shadow(c, anim);
    _shadedLeg(c, -6, anim.legL, hoseBase, _leatherDk, legLift: anim.legLiftL);
    _shadedLeg(c,  6, anim.legR, hoseBase, _leatherDk, legLift: anim.legLiftR);

    c.save();
    _applyTorsoTransform(c, anim);

    // Yeşil tunik/pelerin
    _shadedTorso(c, const Rect.fromLTWH(-12, -68, 24, 32), cloakBase);
    // Çapraz deri kayış (sadak askısı)
    c.drawLine(const Offset(-11, -64), const Offset(11, -44), _s(_leather, 3.0));
    // Kemer
    _shadedRect(c, const Rect.fromLTWH(-12, -46, 24, 4), _leatherDk);

    // Sırttaki sadak + oklar — gövdeye YASLI (kopuk durmasın), koldan önce çizilir
    _shadedRect(c, const Rect.fromLTWH(-19, -68, 9, 20), _leather);
    for (int i = 0; i < 3; i++) {
      final ax = -18 + i * 3.0;
      c.drawRect(Rect.fromLTWH(ax, -80, 2, 14), _f(_woodBrown)); // ok gövdesi
      c.drawRect(Rect.fromLTWH(ax - 0.5, -83, 3, 4),
          _f(const Color(0xFFE2DCCA))); // tüy
    }

    _shadedArm(c, -15, anim.armL, cloakBase, v.skin);
    // Sağ el + yay — kavis ELDEN çıkar (kol ekseninde), havada durmaz
    _shadedArm(c, 15, anim.armR, cloakBase, v.skin, (arm) {
      final bow = Path()
        ..moveTo(1, -30)
        ..quadraticBezierTo(13, 0, 1, 30);
      arm.drawPath(bow, _s(_woodBrown, 3.0));
      arm.drawLine(const Offset(1, -30), const Offset(1, 30),
          _s(const Color(0xFFCFC3A8), 1.0)); // kiriş
    });

    _shadedHead(c, v, time);

    // Kukuleta (cowl) — tepe + yüzü çerçeveleyen yanaklar + arkaya doğru kısa
    // sivri uç. Eski hâli üst üste kutulardan bir "baca" gibiydi.
    _shadedRect(c, const Rect.fromLTWH(-11, -99, 22, 12), cloakBase); // tepe
    _shadedRect(c, const Rect.fromLTWH(-12, -93, 4, 13), cloakBase);  // sol yanak
    _shadedRect(c, const Rect.fromLTWH(  8, -93, 4, 13), cloakBase);  // sağ yanak
    _shadedRect(c, const Rect.fromLTWH(-14, -97, 4, 7), cloakBase);   // arka sivri uç
    c.restore();
  }

  // ─── DEĞİRMENCİ / FIRINCI ─────────────────────────────────────────────────
  /// Silüet imzası: UNLU BEYAZ önlük (köyde tek beyaz kütle) + omuzda un çuvalı
  /// + bez başlık. Uzaktan bile "beyaz" olan tek meslek.
  static void _millerNpc(Canvas c, _Anim anim, NpcVisual v, double time) {
    final clothBase = _cloth(_kMillerCloth, v.clothingShift);
    final hoseBase  = _cloth(const Color(0xFF5E584C), v.clothingShift * 0.4);
    const sack      = Color(0xFFBFAE86);

    _shadow(c, anim);
    _shadedLeg(c, -6, anim.legL, hoseBase, _leatherDk, legLift: anim.legLiftL);
    _shadedLeg(c,  6, anim.legR, hoseBase, _leatherDk, legLift: anim.legLiftR);

    c.save();
    _applyTorsoTransform(c, anim);

    // İş gömleği
    _shadedTorso(c, const Rect.fromLTWH(-13, -68, 26, 32), clothBase);
    // UNLU BEYAZ önlük — göğüsten aşağı, imza kütle
    _shadedRect(c, const Rect.fromLTWH(-9, -62, 18, 26), _kFlourWhite);
    // Önlük askıları
    c.drawLine(const Offset(-7, -62), const Offset(-3, -68), _s(_kFlourWhite, 2.0));
    c.drawLine(const Offset( 7, -62), const Offset( 3, -68), _s(_kFlourWhite, 2.0));
    // Un lekeleri (önlükte + omuzda birkaç açık benek)
    for (final p in const [Offset(-5, -50), Offset(4, -44), Offset(-11, -64)]) {
      c.drawRect(Rect.fromLTWH(p.dx, p.dy, 2, 2), _f(const Color(0xFFF2EEE2)));
    }

    // Sol OMUZDA un çuvalı — gövdeye BİNDİRİLMİŞ (eski hâli 1px boşlukla havada
    // duruyordu, tabela gibi okunuyordu) + omuz üstünden geçen kayış.
    _shadedRect(c, const Rect.fromLTWH(-23, -80, 14, 17), sack);
    c.drawRect(const Rect.fromLTWH(-20, -82, 7, 3), _f(_leatherDk)); // ağzı bağlı
    c.drawLine(const Offset(-12, -78), const Offset(-2, -70), _s(_leatherDk, 2.0));

    _shadedArm(c, -16, anim.armL, clothBase, v.skin);
    _shadedArm(c,  16, anim.armR, clothBase, v.skin);

    _shadedHead(c, v, time);

    // Bez başlık — yayvan, kaş üstünde (kutu değil)
    _shadedRect(c, const Rect.fromLTWH(-11, -95, 22, 5), _kFlourWhite);
    _shadedRect(c, const Rect.fromLTWH(-9, -102, 18, 7), _kFlourWhite);
    c.restore();
  }

  // ─── HANCI / MEYHANECİ ────────────────────────────────────────────────────
  /// Silüet imzası: şarap kırmızısı yelek + beyaz önlük + elde KÖPÜKLÜ MAŞRAPA.
  /// Köyün tek kırmızısı — hanın sıcaklığını taşır.
  static void _innkeeperNpc(Canvas c, _Anim anim, NpcVisual v, double time) {
    final shirtBase = _cloth(const Color(0xFFC8B9A0), v.clothingShift * 0.6);
    final vestBase  = _cloth(_kInnkeeperWine, v.clothingShift);
    final hoseBase  = _cloth(const Color(0xFF4A3A32), v.clothingShift * 0.4);

    _shadow(c, anim);
    _shadedLeg(c, -6, anim.legL, hoseBase, _leatherDk, legLift: anim.legLiftL);
    _shadedLeg(c,  6, anim.legR, hoseBase, _leatherDk, legLift: anim.legLiftR);

    c.save();
    _applyTorsoTransform(c, anim);

    // Krem gömlek (kollar sıvalı → geniş omuz)
    _shadedTorso(c, const Rect.fromLTWH(-13, -68, 26, 32), shirtBase);
    // Şarap kırmızısı yelek — ortada, iki yandan gömlek görünür
    _shadedRect(c, const Rect.fromLTWH(-9, -68, 18, 24), vestBase);
    // Yelek düğmeleri
    for (int i = 0; i < 3; i++) {
      c.drawRect(Rect.fromLTWH(-1, -64 + i * 6.0, 2, 2),
          _f(const Color(0xFFC8A042)));
    }
    // Beyaz önlük (belden aşağı)
    _shadedRect(c, const Rect.fromLTWH(-11, -46, 22, 14), const Color(0xFFDDD6C4));

    _shadedArm(c, -16, anim.armL, shirtBase, v.skin);
    // Sağ el + köpüklü maşrapa (tahta bardak + krem köpük)
    _shadedArm(c, 16, anim.armR, shirtBase, v.skin, (arm) {
      _shadedRect(arm, const Rect.fromLTWH(1, 14, 9, 11), const Color(0xFF7A5030));
      // Kulp
      arm.drawRect(const Rect.fromLTWH(10, 17, 3, 5), _f(const Color(0xFF5A3A20)));
      // Köpük
      _shadedRect(arm, const Rect.fromLTWH(1, 11, 9, 4), const Color(0xFFF0EAD8));
    });

    _shadedHead(c, v, time);

    // Saç açık — başlık yok (hancı başı açık çalışır); yerine kulak arkası kalem
    // yerine küçük bir bez bandana: alnı saran ince şerit.
    _shadedRect(c, const Rect.fromLTWH(-10, -92, 20, 4), vestBase);
    c.restore();
  }

  // ─── MADENCI (idle, yeni — shaded + per-NPC görsel) ────────────────────────
  static void _minerNpc(Canvas c, _Anim anim, NpcVisual v, double time) {
    final shirtBase = _cloth(const Color(0xFF4A4840), v.clothingShift);
    final vestBase  = _cloth(const Color(0xFF6A4A28), v.clothingShift * 0.6);
    final hoseBase  = _cloth(const Color(0xFF3A3028), v.clothingShift * 0.4);

    _shadow(c, anim);
    _shadedLeg(c, -6, anim.legL, hoseBase, _leatherDk, legLift: anim.legLiftL);
    _shadedLeg(c,  6, anim.legR, hoseBase, _leatherDk, legLift: anim.legLiftR);

    c.save();
    _applyTorsoTransform(c, anim);

    // Gömlek
    _shadedTorso(c, const Rect.fromLTWH(-13, -68, 26, 32), shirtBase);
    // Deri yelek (gömleğin üstüne)
    _shadedRect(c, const Rect.fromLTWH(-10, -67, 20, 30), vestBase);
    // Yelek tokası
    c.drawRect(const Rect.fromLTWH(-2, -58, 4, 14), _f(_leatherDk));

    _shadedArm(c, -16, anim.armL, shirtBase, v.skin);
    _shadedArm(c,  16, anim.armR, shirtBase, v.skin);

    _shadedHead(c, v, time);

    // Madenci başlığı (kafayı kaplar)
    _shadedRect(c, const Rect.fromLTWH(-12, -96, 24,  6), const Color(0xFF2A2010));
    _shadedRect(c, const Rect.fromLTWH( -8, -108, 16, 12), const Color(0xFF2A2010));
    // Kask lambası
    c.drawRect(const Rect.fromLTWH(-3, -108, 6, 4), _f(const Color(0xFFFFDD44)));
    c.drawRect(const Rect.fromLTWH(-3, -108, 6, 1), _f(const Color(0xFFFFEE88)));
    c.restore();
  }

  // ─── BALIKÇI (idle, yeni — shaded + per-NPC görsel) ────────────────────────
  static void _fisherNpc(Canvas c, _Anim anim, NpcVisual v, double time) {
    final shirtBase = _cloth(const Color(0xFF5A7888), v.clothingShift);
    final vestBase  = _cloth(const Color(0xFF2A3840), v.clothingShift * 0.5);
    final hoseBase  = _cloth(const Color(0xFF3A5060), v.clothingShift * 0.4);
    const hatBrim   = Color(0xFF4A3A20);
    const hatDome   = Color(0xFF5A4A28);

    _shadow(c, anim);
    _shadedLeg(c, -6, anim.legL, hoseBase, _leatherDk, legLift: anim.legLiftL);
    _shadedLeg(c,  6, anim.legR, hoseBase, _leatherDk, legLift: anim.legLiftR);

    c.save();
    _applyTorsoTransform(c, anim);

    // Gömlek
    _shadedTorso(c, const Rect.fromLTWH(-12, -68, 24, 32), shirtBase);
    // Yelek
    _shadedRect(c, const Rect.fromLTWH(-9, -67, 18, 30), vestBase);

    _shadedArm(c, -15, anim.armL, shirtBase, v.skin);
    _shadedArm(c,  15, anim.armR, shirtBase, v.skin);

    _shadedHead(c, v, time);

    // Balıkçı şapkası — geniş brim + düz kubbe
    _shadedRect(c, const Rect.fromLTWH(-14, -98, 28, 6), hatBrim);
    _shadedRect(c, const Rect.fromLTWH( -8, -110, 16, 12), hatDome);
    c.restore();
  }

  // ─── 11. İNŞAATÇI ──────────────────────────────────────────────────────────
  /// İnşaatçı — usta marangoz/duvarcı. Diğer meslekler gibi SHADED sistemde
  /// (_shadedRect/_shadedArm/_shadedLeg): hacimli kumaş, görünür eller, adım
  /// kaldırma. Silüet imzası: siperlikli bez kasket + çapraz askılı deri iş
  /// önlüğü + alet kemeri (asılı keski) + elde çekiç.
  static void _builder(Canvas c, _Anim anim,
      {bool working = false, NpcVisual? v, double time = 0}) {
    final tunicBase = v != null
        ? _cloth(const Color(0xFF9A7840), v.clothingShift)
        : const Color(0xFF9A7840);
    final hoseBase = v != null
        ? _cloth(_woolBrown, v.clothingShift * 0.5) : _woolBrown;
    // Terracotta kasket — bej tunikte kaybolan eski bereden farklı, siluet imzası.
    final capBase = v != null
        ? _cloth(const Color(0xFF9A4A30), v.clothingShift * 0.5)
        : const Color(0xFF9A4A30);
    final skin = v?.skin ?? _skin1;

    _shadow(c, anim);
    _shadedLeg(c, -6, anim.legL, hoseBase, _leatherDk, legLift: anim.legLiftL);
    _shadedLeg(c,  6, anim.legR, hoseBase, _leatherDk, legLift: anim.legLiftR);

    c.save();
    _applyTorsoTransform(c, anim);

    // Çalışma tuniği
    _shadedTorso(c, const Rect.fromLTWH(-13, -68, 26, 32), tunicBase);
    // Deri iş önlüğü (göğüsten aşağı)
    _shadedRect(c, const Rect.fromLTWH(-9, -64, 18, 28), _leather);
    // Çapraz askılar — önlüğü omuza bağlar (demircinin V'sinden ayrışır)
    c.drawLine(const Offset(-7, -64), const Offset( 2, -76), _s(_leatherDk, 2.2));
    c.drawLine(const Offset( 7, -64), const Offset(-2, -76), _s(_leatherDk, 2.2));
    // Alet kemeri + demir toka
    _shadedRect(c, const Rect.fromLTWH(-13, -46, 26, 5), _leatherDk);
    c.drawRect(const Rect.fromLTWH(-2, -46, 4, 5), _f(_ironGrey));
    // Kemerde asılı keski (sap + ağız) — "alet taşıyan usta" detayı
    c.drawRect(const Rect.fromLTWH(8, -44, 3, 6), _f(_woodBrown));
    c.drawRect(const Rect.fromLTWH(8, -38, 3, 4), _f(_ironGrey));

    _shadedArm(c, -16, anim.armL, tunicBase, skin);
    // Sağ kol + çekiç (PNG) — artık el de görünür
    _shadedArm(c, 16, anim.armR, tunicBase, skin,
        ToolRenderer.drawHammer);

    if (v != null) {
      _shadedHead(c, v, time);
    } else {
      _head(c, skin);
    }

    // Bez kasket — kısa deri siperlik + yumuşak kubbe. Eski hata: 18px'lik düz
    // kutu −98..−80 arası kafayı yutup gözleri kapatıyordu; artık kaş üstünde.
    _shadedRect(c, const Rect.fromLTWH(-13, -96, 26, 5), _leatherDk); // siperlik
    _shadedRect(c, const Rect.fromLTWH(-10, -106, 20, 11), capBase);  // kubbe
    c.restore();
  }
}
