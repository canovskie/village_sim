import 'dart:math';

import 'package:flutter/material.dart';

import '../characters/life_stage.dart';
import '../characters/npc_visual.dart';
import '../characters/villager_type.dart';
import '../systems/npc/npc_gait.dart';
import 'tool_renderer.dart';

part 'character_paints.dart';
part 'character_body.dart';
part 'character_workers.dart';
part 'character_shaded.dart';
part 'character_roles.dart';
part 'character_interior.dart';

/// İki elle yük taşırken kolların omuz-pivot açıları. Canvas'ta +açı aşağı
/// doğru uzanan kolu SOLA, -açı SAĞA yatırır; dolayısıyla sol kol negatif,
/// sağ kol pozitif olmalıdır. İşaretler ters dönerse iki el yükten dışarı açılır.
@visibleForTesting
({double armL, double armR}) twoHandCarryArmAngles(
  double phase,
  double moveIntensity,
) {
  final m = moveIntensity.clamp(0.0, 1.0);
  final gripBreath = sin(phase) * (0.015 + m * 0.035);
  return (armL: -0.52 + gripBreath, armR: 0.52 - gripBreath);
}

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
  const _Anim(
    this.legL,
    this.legR,
    this.armL,
    this.armR,
    this.bob, {
    this.sway = 0,
    this.lean = 0,
    this.legLiftL = 0,
    this.legLiftR = 0,
    this.torsoTwist = 0,
  });

  /// Tek parametre değiştirip kopya — meşale taşıyan sol kolu yukarı sabit
  /// tutmak gibi durumlar için. Diğer alanlar korunur.
  _Anim copyWith({double? armL, double? armR}) => _Anim(
    legL,
    legR,
    armL ?? this.armL,
    armR ?? this.armR,
    bob,
    sway: sway,
    lean: lean,
    legLiftL: legLiftL,
    legLiftR: legLiftR,
    torsoTwist: torsoTwist,
  );

  /// Karakter idle/walking/carrying için kol-bacak-bob salınımı.
  ///
  /// [moveIntensity] 0..1 sürekli — walking ↔ idle smooth blend.
  /// 0=tam idle, 1=tam walking.  Aradaki değerler doğrusal karıştırılır →
  /// donuk anlık geçiş yerine akıcı.
  static _Anim compute(
    double phase,
    double moveIntensity, {
    bool carrying = false,
  }) {
    final m = moveIntensity.clamp(0.0, 1.0);

    if (carrying) {
      final grip = twoHandCarryArmAngles(phase, m);
      final bobWalk = (cos(phase * 2) - 1) * 2.0;
      final liftL = max(0.0, sin(phase)) * 1.4 * m;
      final liftR = max(0.0, -sin(phase)) * 1.4 * m;
      return _Anim(
        sin(phase) * (0.04 + m * 0.34),
        -sin(phase) * (0.04 + m * 0.34),
        grip.armL,
        grip.armR,
        bobWalk * m,
        lean: m * 0.06,
        legLiftL: liftL,
        legLiftR: liftR,
      );
    }

    // ── Idle parametreleri ────────────────────────────────────────────────
    final sIdle = sin(phase) * 0.10;
    // Daha yavaş, daha doğal nefes alma (0.4 Hz → 0.32 Hz). Genlik +0.2 px.
    final breathIdle = -sin(phase * 0.35).abs() * 0.8;
    // Yavaş yan ağırlık değişimi — idle "yaşıyor" hissi, vurgulu.
    final idleSway = sin(phase * 0.26) * 2.2;

    // ── Walking parametreleri ─────────────────────────────────────────────
    final sWalk = sin(phase);
    // Bob: 2× frequency cosine — her adımda iniş/çıkış. Daha belirgin.
    final bobWalk = (cos(phase * 2) - 1) * 2.6;
    // Walking lean — gövde öne eğilir (radyan).
    const leanWalk = 0.10;
    // Foot lift Y — sin'in pozitif yarısında sol ayak kalkar, ters yarıda sağ.
    final liftL = max(0.0, sWalk) * 1.6 * m;
    final liftR = max(0.0, -sWalk) * 1.6 * m;
    // Üst gövde twist — yürürken omuzlar hafif tersine döner (counter-leg).
    final twist = sWalk * 0.04 * m;

    // ── Blend ──────────────────────────────────────────────────────────────
    return _Anim(
      sIdle + (sWalk * 0.55 - sIdle) * m, // legL (daha geniş adım)
      -sIdle + (-sWalk * 0.55 + sIdle) * m, // legR
      -sIdle * 0.5 + (-sWalk * 0.40 + sIdle * 0.5) * m, // armL (counter-leg)
      sIdle * 0.5 + (sWalk * 0.40 - sIdle * 0.5) * m, // armR
      breathIdle + (bobWalk - breathIdle) * m, // bob
      sway: idleSway * (1.0 - m),
      lean: leanWalk * m,
      legLiftL: liftL,
      legLiftR: liftR,
      torsoTwist: twist,
    );
  }
}

/// Alet işlerinin ortak, ağırlıklı vuruş eğrisi. Sürekli sinüs kolu ileri geri
/// sallandırır ama temas üretmez; bu eğri hazırlık → hızlanma → kısa temas →
/// toparlanma şeklinde dört ayrı zaman bölgesi verir ve bütün gövdeyi taşır.
class _WorkBeat {
  final double toolArm;
  final double supportArm;
  final double lean;
  final double bob;
  final double legBrace;

  const _WorkBeat(
    this.toolArm,
    this.supportArm,
    this.lean,
    this.bob,
    this.legBrace,
  );
}

const double kWorkContactPhase = 0.42;

double _easeInOut(double t) => t * t * (3 - 2 * t);

_WorkBeat _workBeat(double phase, {double reach = 1.0}) {
  final t = (phase % (2 * pi)) / (2 * pi);
  double arm, lean, bob, brace;
  if (t < 0.28) {
    // Hazırlık: alet arkaya kalkar, ağırlık arka ayağa geçer.
    final u = _easeInOut(t / 0.28);
    arm = 0.10 + 1.06 * u;
    lean = -0.05 * u;
    bob = -1.0 * u;
    brace = -0.10 * u;
  } else if (t < kWorkContactPhase) {
    // Darbe: hazırlıktan temasa kısa ve hızlı iniş.
    final u = (t - 0.28) / (kWorkContactPhase - 0.28);
    final fast = u * u;
    arm = 1.16 + (-1.46 * reach - 1.16) * fast;
    lean = -0.05 + 0.25 * fast;
    bob = -1.0 + 4.2 * fast;
    brace = -0.10 + 0.30 * fast;
  } else if (t < 0.47) {
    // Temas tutuşu: iki-üç kare alet hedefte kalır; "lastik kol" hissi gider.
    final u = (t - kWorkContactPhase) / 0.05;
    arm = -1.46 * reach + 0.05 * u;
    lean = 0.20 - 0.03 * u;
    bob = 3.2 - 0.4 * u;
    brace = 0.20;
  } else {
    // Toparlanma: gövde önce, alet ardından nötre döner.
    final u = _easeInOut((t - 0.47) / 0.53);
    arm = -1.41 * reach + (0.10 + 1.41 * reach) * u;
    lean = 0.17 * (1 - u);
    bob = 2.8 * (1 - u);
    brace = 0.20 * (1 - u);
  }
  return _WorkBeat(arm, -arm * 0.24, lean, bob, brace);
}

/// Temastan sonra hedefte görünen sönümlü tepkinin fazı. -1, bu karede hedef
/// tepkisi yok demektir. Karakter, parçacık ve hedef aynı temas anını okur.
double workImpactPhase(double phase) {
  final t = (phase % (2 * pi)) / (2 * pi);
  final since = (t - kWorkContactPhase + 1.0) % 1.0;
  if (since > 0.24) return -1;
  return since / 0.24 * 2 * pi;
}

double workContactAmount(double phase) {
  final t = (phase % (2 * pi)) / (2 * pi);
  final d = (t - kWorkContactPhase).abs();
  if (d >= 0.055) return 0;
  return 1 - d / 0.055;
}

// ─── POZ ──────────────────────────────────────────────────────────────────────
/// Karakterin tüm gövde duruşunu değiştiren özel pozlar — ayakta/yürür dışı.
/// Uzuvları (bacak/kol/lean) gerçekten yeniden konumlandırır; emoji/kestirme
/// DEĞİL. Ateş başı oturma, ayin diz çökme, yas eğilmesi için.
enum CharPose {
  normal, // ayakta / yürür (varsayılan _Anim)
  sit, // bağdaş kurmuş — bacaklar öne katlı, eller kucakta, hafif öne
  kneel, // ayin: dizüstü, gövde dik, kollar yukarı yakarış
  mourn, // yas: çömelmiş, derin öne eğilme, kollar önde sarkık
}

// ─── JEST ─────────────────────────────────────────────────────────────────────
/// Tek kolun üstlendiği kısa anlatım — [CharPose]'un aksine gövdenin geri
/// kalanını ELE ALMAZ, yalnız sağ kolu (ön taraftaki kol) devralır. Bu yüzden
/// yürürken de, otururken de, meşale taşırken de (o sol kol) oynayabilir.
///
/// Var oluş sebebi bir borç: selam başın üstünde bir 👋 baloncuğuydu, hikâye
/// anlatımı bir 📖. Baş üstü emoji projede YASAK ve sebebi tam olarak bu:
/// baloncuk olayın kendisini değil, olayın ADINI gösterir. El sallayan adam
/// selam verir; başında 👋 duran adam "selam" yazısı taşır.
enum CharGesture {
  none,

  /// Selam — kol omuz üstüne kalkar, bilek hızlı salınır.
  wave,

  /// Anlatım — el yarı yukarıda, yavaş ve geniş; oturarak da okunur.
  tell,

  /// Açlık — ön kol gövdeye kapanır, el karın hizasında kalır.
  holdStomach,

  /// Efor sonrası — ön kol kısa süre alın hizasına çıkar.
  wipeBrow,

  /// Demirci vuruşu — çekiç kolu yukarıdan örse iner.
  hammerStrike,
}

// ─── RENDERER ─────────────────────────────────────────────────────────────────
// Pixel-art tarzı karakterler: yalnızca dikdörtgenler, isAntiAlias=false.
// Ayaklar canvas orijininde (y=0). Çağıran save/translate/scale/restore yapar.

class CharacterRenderer {
  /// Bir NPC çizmeden ÖNCE köyün hâlini yaz. Yabancı (imparatorluk) için
  /// sıfır geçilir: köyün ambarı onun kumaşını soldurmaz.
  ///
  /// SÖZLEŞME (aynen [_accent] gibi): **her giriş noktası kendi hâlini yazar.**
  /// Argümansız çağrı nötre döner ve oyun-dışı çağıranlar (künye portresi,
  /// animasyon odası, yakalama harness'ları) hiçbir şey bilmeden doğru sonucu
  /// alır — yazmayan çağıran son çizilen köylünün kıtlığını miras alırdı.
  static void beginNpc({
    double provision = 0,
    double shroud = 0,
    bool primitiveClothing = false,
  }) {
    _provision = provision.clamp(-1.0, 1.0);
    _shroud = shroud.clamp(0.0, 1.0);
    _primitiveClothing = primitiveClothing;
  }

  static void draw(
    Canvas canvas,
    VillagerType type, {
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

    /// Köylünün kalıcı kişisel kıyafet tercihi. `standard` meslek görünümünü
    /// korur; diğerleri meslek gövdesinin yerini alır ama yüz/saç değişmez.
    NpcWardrobe wardrobe = NpcWardrobe.standard,

    /// İmparatorluk kostümünde komutan mı (uzun kızıl sorguç + pelerin).
    bool commander = false,

    /// Eşik muharebesinde saldırı modunda mı. Yabancıda mızrak dürtüsü, köy
    /// muhafızında karşı hamle üretir.
    bool attacking = false,
    double? combatSwing,

    /// Hane aksan rengi (bkz. [houseAccentColor]) — göğüsteki çapraz kuşak.
    /// null → hanesiz/yabancı, kuşak çizilmez.
    Color? houseAccent,

    /// Köyün ambar hâli -1..1 ve köylünün örtünmesi 0..1 (bkz. [beginNpc]).
    /// Oyun-dışı çağıranlar geçmez → nötr görünüm.
    double provision = 0,
    double shroud = 0,
    bool primitiveClothing = false,

    /// Sağ kolun üstlendiği kısa jest (selam / anlatım) — bkz. [CharGesture].
    CharGesture gesture = CharGesture.none,

    /// Jestin gücü 0..1. Sıfırdan başlayıp sıfıra dönen bir ZARF beklenir:
    /// kol aniden kalkarsa jest değil seğirme olur.
    double gestureAmount = 0,

    /// Elde/sırtta taşınan sahne nesnesi. Callback, karakterin yön aynalaması
    /// ve beden ölçeği uygulanmış yerel uzayında; torso bob/lean/twist ile aynı
    /// transform altında çağrılır. Böylece nesne ayrı screen-space'te yüzmez.
    void Function(Canvas)? heldItem,

    /// Çuval gibi sırt yükleri gövdeden önce çizilir; ön yükler (sepet/kutu)
    /// gövde üstünde kalır. İki durumda da kavrayan eller en son çizilir.
    bool heldItemBehindBody = false,
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
    // Ayrı iki sahiplik var:
    // - [heldItem] mesleğin kendi sabit prop'unu ve sağ-el jestini bastırır;
    // - [carrying] iki eli birden kilitler, dolayısıyla sol-el meşalesi ve
    //   saldırı kolu da ancak bu durumda devre dışı kalır.
    // Tek-elli balta/kova için ikisini aynı saymak görünmez gece ışığı ve
    // koldan kopuk saldırı aleti üretiyordu.
    final handsBusy = carrying || heldItem != null;
    final twoHandsBusy = carrying;
    var anim = _Anim.compute(walkPhase, moveIntensity, carrying: carrying);
    if (pose != CharPose.normal) {
      // Poz tüm duruşu ele alır — yürüyüş/taşıma/meşale açıları geçersiz.
      anim = _poseAnim(pose, time);
    } else if (!twoHandsBusy && torchLevel > 0.02) {
      // Meşale taşıyorsa sol kol yukarı kilitlenir → el ve meşale tek birim.
      anim = anim.copyWith(armL: _kTorchArmAngle);
    }
    // JEST — pozdan SONRA ve yalnız SAĞ kola. Sırası önemli: oturan hikâye
    // anlatıcısının eli de kalkabilsin diye pozu ezmiyor, üstüne biniyor;
    // sol kola dokunmadığı için meşale taşıyan da selam verebilir.
    if (!handsBusy && gesture != CharGesture.none && gestureAmount > 0.02) {
      anim = anim.copyWith(
        armR: _gestureArm(gesture, gestureAmount, time, anim.armR),
      );
    }
    if (!twoHandsBusy && attacking && costume != NpcCostume.imperial) {
      // Muhafız mızrağı ve milisin aleti aynı vuruş ritminde öne gelir.
      // Gece meşalesi sol eldeyse saldırı yalnız sağ kolu devralsın;
      // aksi halde aşağıda sabit torch pivotu çizilirken sol kol ondan kopar.
      final jab = combatSwing ?? sin(time * 8.6 + (visual?.blinkPhase ?? 0));
      anim = anim.copyWith(
        armL: torchLevel > 0.02 ? anim.armL : -0.55,
        armR: 1.34 + jab * 0.38,
      );
    }

    // Sırt yükü karakterin arkasında kalır. Callback zaten flip/build scale
    // içinde; yalnız üst gövdenin kendi hareket dönüşümünü paylaşması gerekir.
    if (heldItem != null && heldItemBehindBody) {
      canvas.save();
      _applyTorsoTransform(canvas, anim);
      heldItem(canvas);
      canvas.restore();
    }

    // Özel kostüm (imparatorluk askeri) tip/meslek/evreyi önceler — köyün
    // yabancısı her zaman tam zırhlı görünür.
    if (costume == NpcCostume.imperial && visual != null) {
      final v = stage == LifeStage.elder ? visual.elderly() : visual;
      _imperialSoldierNpc(
        canvas,
        anim,
        v,
        time,
        commander: commander,
        attacking: attacking,
        combatSwing: combatSwing,
        handsBusy: handsBusy,
      );
    } else if (wardrobe != NpcWardrobe.standard && visual != null) {
      final v = stage == LifeStage.elder ? visual.elderly() : visual;
      _personalWardrobeNpc(canvas, anim, v, time, wardrobe);
    } else if (primitiveClothing) {
      final baseVisual = visual ?? _fallbackVisual;
      final v = stage == LifeStage.elder ? baseVisual.elderly() : baseVisual;
      _primitiveNpc(canvas, anim, v, time, child: stage == LifeStage.child);
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
          v != null ? _farmerNpc(canvas, anim, v, time) : _farmer(canvas, anim);
        case VillagerType.merchant:
          v != null
              ? _merchantNpc(canvas, anim, v, time)
              : _merchant(canvas, anim);
        case VillagerType.blacksmith:
          v != null
              ? _blacksmithNpc(
                  canvas,
                  anim,
                  v,
                  time,
                  hammering: gesture == CharGesture.hammerStrike,
                )
              : _blacksmith(canvas, anim, handsBusy: handsBusy);
        case VillagerType.guard:
          v != null
              ? _guardNpc(canvas, anim, v, time, handsBusy: handsBusy)
              : _guard(canvas, anim, handsBusy: handsBusy);
        case VillagerType.miner:
          v != null ? _minerNpc(canvas, anim, v, time) : _miner(canvas, anim);
        case VillagerType.fisher:
          v != null
              ? _fisherNpc(canvas, anim, v, time)
              : _fisherIdle(canvas, anim);
        // Yeni meslekler: tek (shaded) yol — visual yoksa nötr fallback görsel
        // kullanılır, ayrı ilkel varyant yazmaya gerek yok.
        case VillagerType.priest:
          _priestNpc(canvas, anim, v ?? _fallbackVisual, time);
        case VillagerType.shepherd:
          _shepherdNpc(
            canvas,
            anim,
            v ?? _fallbackVisual,
            time,
            handsBusy: handsBusy,
          );
        case VillagerType.hunter:
          _hunterNpc(
            canvas,
            anim,
            v ?? _fallbackVisual,
            time,
            handsBusy: handsBusy,
          );
        case VillagerType.miller:
          _millerNpc(
            canvas,
            anim,
            v ?? _fallbackVisual,
            time,
            handsBusy: handsBusy,
          );
        case VillagerType.innkeeper:
          _innkeeperNpc(
            canvas,
            anim,
            v ?? _fallbackVisual,
            time,
            handsBusy: handsBusy,
          );
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

    if (heldItem != null && !heldItemBehindBody) {
      canvas.save();
      _applyTorsoTransform(canvas, anim);
      heldItem(canvas);
      canvas.restore();
    }
    if (heldItem != null && carrying) {
      canvas.save();
      _applyTorsoTransform(canvas, anim);
      _drawCarryGripHands(
        canvas,
        anim,
        visual?.skin ?? _skinFor(type),
        shoulderX: _carryShoulderX(
          type,
          costume: costume,
          stage: stage,
          primitiveClothing: primitiveClothing,
        ),
      );
      canvas.restore();
    }

    // Gece dışarıda meşale — sol omuz (off-hand), tüm character render
    // yolları aynı helper'ı kullanır → civilian + worker pattern tutarlı.
    // Oturma/ayin/yas pozunda eller serbest → meşale taşınmaz.
    if (pose == CharPose.normal && !twoHandsBusy) {
      _torchInLeftHand(canvas, torchLevel, time: time, torchPhase: torchPhase);
    }
    canvas.restore();
    _accent = null;
  }

  /// Yatay yatmış uyku pozu — yastıkta kafa, vücut battaniyenin üstünde,
  /// hafif breath salınımı.  Origin: karakterin ayak konumu (canvas zaten
  /// translate edilmiş olmalı).  Karakter sola doğru uzanır (kafa solda).
  static void drawSleeping(
    Canvas c,
    VillagerType type, {
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
    final skinCol = _sleepSkinColor(type);

    // Battaniye / minder
    c.drawRect(
      const Rect.fromLTWH(-26, -3, 38, 5),
      _f(const Color(0xFF3A2818)),
    );
    c.drawRect(
      const Rect.fromLTWH(-26, -3, 38, 5),
      _s(const Color(0xFF1A0E08)),
    );

    // Yastık (sol tarafta, kafanın altında)
    c.drawRect(const Rect.fromLTWH(-32, -10, 14, 6), _f(_linen));
    c.drawRect(const Rect.fromLTWH(-32, -10, 14, 6), _s(_outline));

    // Vücut (yatay tunic — gövde + üst bacaklar tek blok)
    c.drawRect(Rect.fromLTWH(-20, -9 + breath, 32, 8), _f(tunicCol));
    c.drawRect(Rect.fromLTWH(-20, -9 + breath, 32, 8), _s(_outline));

    // Battaniye üzerine çekilmiş kısım (tunic alt kısmı koyulaşır)
    c.drawRect(
      Rect.fromLTWH(-2, -9 + breath, 14, 8),
      _f(Color.alphaBlend(_outline.withValues(alpha: 0.3), tunicCol)),
    );

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

  static void drawFarmer(
    Canvas canvas, {
    bool flipX = false,
    double walkPhase = 0,
    double moveIntensity = 0.0,
    bool harvesting = false,
    double harvestPhase = 0,
    bool carryingWater = false,
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
      final beat = _workBeat(harvestPhase, reach: 0.78);
      final s = flipX ? -beat.toolArm : beat.toolArm;
      anim = _Anim(
        -beat.legBrace,
        beat.legBrace * 0.55,
        flipX ? -beat.supportArm : beat.supportArm,
        s,
        beat.bob,
        lean: beat.lean,
      );
    } else {
      anim = _Anim.compute(walkPhase, moveIntensity);
    }
    // Meşale yanıyorsa sol kol yukarı sabit kilitlenir (kol + meşale tek birim).
    final showTorch = torchLevel > 0.02 && !carryingWater && !harvesting;
    if (showTorch) anim = anim.copyWith(armL: _kTorchArmAngle);

    if (primitiveClothing) {
      _primitiveNpc(
        canvas,
        anim,
        visual ?? _fallbackVisual,
        time,
        rightItem: carryingWater ? ToolRenderer.drawWaterbucket : null,
      );
      if (showTorch) {
        _torchInLeftHand(
          canvas,
          torchLevel,
          time: time,
          torchPhase: torchPhase,
        );
      }
      canvas.restore();
      return;
    }

    _farmer(canvas, anim, carryingWater: carryingWater, v: visual, time: time);
    if (showTorch) {
      _torchInLeftHand(canvas, torchLevel, time: time, torchPhase: torchPhase);
    }
    canvas.restore();
  }

  static void drawBuilder(
    Canvas canvas, {
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
      final beat = _workBeat(walkPhase, reach: 0.74);
      final s = flipX ? -beat.toolArm : beat.toolArm;
      anim = _Anim(
        -beat.legBrace,
        beat.legBrace,
        flipX ? -beat.supportArm : beat.supportArm,
        s,
        beat.bob,
        lean: beat.lean,
      );
    } else {
      anim = _Anim.compute(walkPhase, moveIntensity);
    }
    final showTorch = torchLevel > 0.02 && !working;
    if (showTorch) anim = anim.copyWith(armL: _kTorchArmAngle);
    if (primitiveClothing) {
      _primitiveNpc(
        canvas,
        anim,
        visual ?? _fallbackVisual,
        time,
        rightItem: working
            ? (arm) => ToolRenderer.drawHammer(arm, scale: 1.15)
            : null,
      );
      if (showTorch) {
        _torchInLeftHand(
          canvas,
          torchLevel,
          time: time,
          torchPhase: torchPhase,
        );
      }
      canvas.restore();
      return;
    }
    _builder(canvas, anim, working: working, v: visual, time: time);
    if (showTorch) {
      _torchInLeftHand(canvas, torchLevel, time: time, torchPhase: torchPhase);
    }
    canvas.restore();
  }

  // ─── 8. MADENCİ (aktif, kazma animasyonlu) ────────────────────────────────

  static void drawMiner(
    Canvas canvas, {
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
      final beat = _workBeat(chopPhase, reach: 0.92);
      final s = flipX ? -beat.toolArm : beat.toolArm;
      anim = _Anim(
        -beat.legBrace,
        beat.legBrace,
        flipX ? -beat.supportArm : beat.supportArm,
        s,
        beat.bob,
        lean: beat.lean,
      );
    } else {
      anim = _Anim.compute(walkPhase, moveIntensity);
    }
    final showTorch = torchLevel > 0.02 && !mining;
    if (showTorch) anim = anim.copyWith(armL: _kTorchArmAngle);
    final armRAngle = anim.armR;
    final armLAngle = anim.armL;

    if (primitiveClothing) {
      _primitiveNpc(
        canvas,
        anim,
        visual ?? _fallbackVisual,
        time,
        rightItem: ToolRenderer.drawPickaxe,
      );
      if (showTorch) {
        _torchInLeftHand(
          canvas,
          torchLevel,
          shoulderX: -16,
          time: time,
          torchPhase: torchPhase,
        );
      }
      canvas.restore();
      return;
    }

    final shirtCol = visual != null
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
    _shadedLeg(
      canvas,
      -6,
      anim.legL,
      hoseCol,
      _leatherDk,
      legLift: anim.legLiftL,
    );
    _shadedLeg(
      canvas,
      6,
      anim.legR,
      hoseCol,
      _leatherDk,
      legLift: anim.legLiftR,
    );
    canvas.save();
    _applyTorsoTransform(canvas, anim);
    _shadedTorso(canvas, const Rect.fromLTWH(-13, -68, 26, 32), shirtCol);
    // Deri yelek
    _shadedRect(canvas, const Rect.fromLTWH(-10, -67, 20, 30), vestCol);
    canvas.drawRect(const Rect.fromLTWH(-2, -58, 4, 14), _f(_leatherDk));

    _shadedArm(canvas, -16, armLAngle, shirtCol, skin);
    _shadedArm(canvas, 16, armRAngle, shirtCol, skin, ToolRenderer.drawPickaxe);

    if (visual != null) {
      _shadedHead(canvas, visual, time);
    } else {
      _head(canvas, skin);
    }
    // Kask
    _shadedRect(
      canvas,
      const Rect.fromLTWH(-12, -96, 24, 6),
      const Color(0xFF2A2010),
    );
    _shadedRect(
      canvas,
      const Rect.fromLTWH(-8, -108, 16, 12),
      const Color(0xFF2A2010),
    );
    canvas.drawRect(
      const Rect.fromLTWH(-3, -108, 6, 4),
      _f(const Color(0xFFFFDD44)),
    );
    canvas.restore();

    if (showTorch) {
      _torchInLeftHand(
        canvas,
        torchLevel,
        shoulderX: -16,
        time: time,
        torchPhase: torchPhase,
      );
    }
    canvas.restore();
  }

  // ─── 10. ODUNCU ────────────────────────────────────────────────────────────

  static void drawWoodcutter(
    Canvas canvas, {
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
      final beat = _workBeat(chopPhase, reach: 1.0);
      final s = flipX ? -beat.toolArm : beat.toolArm;
      anim = _Anim(
        -beat.legBrace,
        beat.legBrace,
        flipX ? -beat.supportArm : beat.supportArm,
        s,
        beat.bob,
        lean: beat.lean,
      );
    } else {
      anim = _Anim.compute(walkPhase, moveIntensity);
    }
    final showTorch = torchLevel > 0.02 && !chopping;
    if (showTorch) anim = anim.copyWith(armL: _kTorchArmAngle);
    final armRAngle = anim.armR;
    final armLAngle = anim.armL;

    if (primitiveClothing) {
      _primitiveNpc(
        canvas,
        anim,
        visual ?? _fallbackVisual,
        time,
        rightItem: ToolRenderer.drawAxe,
      );
      if (showTorch) {
        _torchInLeftHand(
          canvas,
          torchLevel,
          shoulderX: -16,
          time: time,
          torchPhase: torchPhase,
        );
      }
      canvas.restore();
      return;
    }

    final hoseCol = visual != null
        ? _cloth(_woolDark, visual.clothingShift * 0.5)
        : _woolDark;
    final shirtColor = visual != null
        ? _cloth(const Color(0xFF8B2020), visual.clothingShift)
        : const Color(0xFF8B2020);
    const shirtDark = Color(0xFF5A1010);
    final skin = visual?.skin ?? _skin1;

    _shadow(canvas, anim);
    _shadedLeg(
      canvas,
      -6,
      anim.legL,
      hoseCol,
      _leatherDk,
      legLift: anim.legLiftL,
    );
    _shadedLeg(
      canvas,
      6,
      anim.legR,
      hoseCol,
      _leatherDk,
      legLift: anim.legLiftR,
    );

    canvas.save();
    _applyTorsoTransform(canvas, anim);
    _shadedTorso(canvas, const Rect.fromLTWH(-13, -68, 26, 32), shirtColor);
    for (final v in [-62.0, -54.0, -46.0]) {
      canvas.drawRect(
        Rect.fromLTWH(-12, v, 24, 2),
        _f(const Color(0xFF6A1010)),
      );
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
    _shadedRect(
      canvas,
      const Rect.fromLTWH(-10, -98, 20, 18),
      const Color(0xFF4A3010),
    );
    canvas.restore();

    if (showTorch) {
      _torchInLeftHand(
        canvas,
        torchLevel,
        shoulderX: -16,
        time: time,
        torchPhase: torchPhase,
      );
    }
    canvas.restore();
  }

  // ─── BALIKÇI (aktif, olta animasyonlu) ────────────────────────────────────
  static void drawFisher(
    Canvas canvas, {
    bool flipX = false,
    double walkPhase = 0,
    double moveIntensity = 0.0,
    bool fishing = false,
    double fishPhase = 0,
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
        ? _cloth(const Color(0xFF5A7888), visual.clothingShift)
        : const Color(0xFF5A7888);
    final vestCol = visual != null
        ? _cloth(const Color(0xFF2A3840), visual.clothingShift * 0.5)
        : const Color(0xFF2A3840);
    final hoseCol = visual != null
        ? _cloth(const Color(0xFF3A5060), visual.clothingShift * 0.4)
        : const Color(0xFF3A5060);
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
      _primitiveNpc(
        canvas,
        anim,
        visual ?? _fallbackVisual,
        time,
        rightItem: (arm) => ToolRenderer.drawRod(arm, castAngle: castAngle),
      );
      if (showTorch) {
        _torchInLeftHand(
          canvas,
          torchLevel,
          shoulderX: -15,
          time: time,
          torchPhase: torchPhase,
        );
      }
      canvas.restore();
      return;
    }

    _shadow(canvas, anim);
    _shadedLeg(
      canvas,
      -6,
      anim.legL,
      hoseCol,
      _leatherDk,
      legLift: anim.legLiftL,
    );
    _shadedLeg(
      canvas,
      6,
      anim.legR,
      hoseCol,
      _leatherDk,
      legLift: anim.legLiftR,
    );

    canvas.save();
    _applyTorsoTransform(canvas, anim);
    _shadedTorso(canvas, const Rect.fromLTWH(-12, -68, 24, 32), shirtCol);
    _shadedRect(canvas, const Rect.fromLTWH(-9, -67, 18, 30), vestCol);

    _shadedArm(canvas, -15, leftSwing, shirtCol, skin);
    // Sağ kol + olta
    _shadedArm(
      canvas,
      15,
      armRAngle,
      shirtCol,
      skin,
      (arm) => ToolRenderer.drawRod(arm, castAngle: castAngle),
    );

    // Olta ipi (fishing sırasında)
    if (fishing) {
      final lineLen = 22.0 + sin(fishPhase * 2) * 4;
      final angle = 0.25 + castAngle + (flipX ? 0 : 0);
      final tipX = 15 + sin(angle + (flipX ? pi : 0)) * 2;
      final tipY = -68 + armRAngle * 15 + 14;
      // Ucundan aşağıya ip
      canvas.drawLine(
        Offset(tipX, tipY),
        Offset(tipX + (flipX ? -8 : 8), tipY + lineLen),
        Paint()
          ..color = const Color(0xFFBBBB88)
          ..strokeWidth = 1.0
          ..isAntiAlias = false,
      );
    }

    if (visual != null) {
      _shadedHead(canvas, visual, time);
    } else {
      _head(canvas, skin);
    }
    // Şapka
    _shadedRect(
      canvas,
      const Rect.fromLTWH(-14, -98, 28, 6),
      const Color(0xFF4A3A20),
    );
    _shadedRect(
      canvas,
      const Rect.fromLTWH(-8, -110, 16, 12),
      const Color(0xFF5A4A28),
    );
    canvas.restore();

    if (showTorch) {
      _torchInLeftHand(
        canvas,
        torchLevel,
        shoulderX: -15,
        time: time,
        torchPhase: torchPhase,
      );
    }
    canvas.restore();
  }

  // ─── ÇOBAN ────────────────────────────────────────────────────────────────
  // drawWoodcutter pattern'ı; balta yerine değnek, kıyafet yeşil yelek + bej
  // gömlek. milking iken kollar inek yönünde aşağı eğilir, gövde hafif öne.
  static void drawShepherd(
    Canvas canvas, {
    bool flipX = false,
    double walkPhase = 0,
    double moveIntensity = 0.0,
    bool milking = false,
    double milkPhase = 0,
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
      _primitiveNpc(
        canvas,
        anim,
        visual ?? _fallbackVisual,
        time,
        rightItem: milking
            ? null
            : (arm) {
                arm.drawRect(
                  const Rect.fromLTWH(-1, -32, 3, 56),
                  _f(const Color(0xFF6A4A20)),
                );
                arm.drawRect(
                  const Rect.fromLTWH(-3, -34, 6, 6),
                  _f(const Color(0xFF6A4A20)),
                );
              },
      );
      if (showTorch) {
        _torchInLeftHand(
          canvas,
          torchLevel,
          shoulderX: -16,
          time: time,
          torchPhase: torchPhase,
        );
      }
      canvas.restore();
      return;
    }

    final hoseCol = visual != null
        ? _cloth(const Color(0xFF4A3818), visual.clothingShift * 0.4)
        : const Color(0xFF4A3818);
    final shirtColor = visual != null
        ? _cloth(const Color(0xFFC8B080), visual.clothingShift)
        : const Color(0xFFC8B080);
    final vestColor = visual != null
        ? _cloth(const Color(0xFF3A6A40), visual.clothingShift * 0.6)
        : const Color(0xFF3A6A40);
    final skin = visual?.skin ?? _skin1;

    _shadow(canvas, anim);
    _shadedLeg(
      canvas,
      -6,
      anim.legL,
      hoseCol,
      _leatherDk,
      legLift: anim.legLiftL,
    );
    _shadedLeg(
      canvas,
      6,
      anim.legR,
      hoseCol,
      _leatherDk,
      legLift: anim.legLiftR,
    );

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
        arm.drawRect(
          const Rect.fromLTWH(-1, -32, 3, 56),
          _f(const Color(0xFF6A4A20)),
        );
        arm.drawRect(
          const Rect.fromLTWH(-3, -34, 6, 6),
          _f(const Color(0xFF6A4A20)),
        );
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
      _torchInLeftHand(
        canvas,
        torchLevel,
        shoulderX: -16,
        time: time,
        torchPhase: torchPhase,
      );
    }
    canvas.restore();
  }
}
