part of 'character_renderer.dart';

/// ORTAK GÖVDE PARÇALARI — poz/jest, uyku renkleri, meşale, gövde dönüşümü, baş/bacak/kol.

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
void _shroudOverlay(Canvas c, NpcVisual? visual, LifeStage stage) {
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
  final wool = _cloth(
    const Color(0xFF8C8071),
    (visual?.clothingShift ?? 0) * 0.6,
  );
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
  c.drawRect(Rect.fromLTWH(-9 * k, -71, 18 * k, 1.5), _f(darker(wool, 0.12)));

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
    c.drawRect(
      Rect.fromLTWH(-9 * k, -90, 18 * k, 1.5),
      _f(darker(wool, 0.22)),
    );
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
_Anim _poseAnim(CharPose pose, double time) {
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

/// drawSleeping için type-bazlı tunic rengi.
Color _sleepTunicColor(VillagerType type) => switch (type) {
  VillagerType.farmer => _linen,
  VillagerType.merchant => const Color(0xFF4A5030),
  VillagerType.blacksmith => const Color(0xFF5A3818),
  VillagerType.guard => const Color(0xFFB8A878),
  VillagerType.priest => _kPriestRobe,
  VillagerType.miner => const Color(0xFF4A4840),
  VillagerType.fisher => const Color(0xFF5A7888),
  VillagerType.shepherd => _kShepherdWool,
  VillagerType.hunter => _kHunterGreen,
  VillagerType.miller => _kMillerCloth,
  VillagerType.innkeeper => _kInnkeeperWine,
};

Color _sleepSkinColor(VillagerType type) =>
    (type == VillagerType.blacksmith ||
        type == VillagerType.miner ||
        type == VillagerType.hunter)
    ? _skin2
    : _skin1;

/// Meşale taşıyan sol kolun sabit açısı — yukarı kaldırılmış, baş hizasında.
/// Gerçek meşale duruşu: kol aşağı sallanmaz, alev yukarıda durur.
/// Hem helper rotate hem body sol kol bu açıya kilitlenir → kol + meşale
/// tek birim olarak hareket eder.
const double _kTorchArmAngle = -2.55;

/// Jestin sağ kol açısı. Kol yerel uzayda AŞAĞI doğru çizilir (açı 0 = yana
/// sarkık), negatif dönüş kolu öne-yukarı kaldırır — meşale kolunun (-2.55)
/// aynı ekseni.
///
/// [amount] zarfı hem yükselişi hem sönüşü taşır: kol dinlenme açısından
/// hedefe doğru İNTERPOLE edilir, böylece jest başladığı yerden çıkar ve
/// bittiğinde kola geri döner (sıçrama yok).
double _gestureArm(
  CharGesture g,
  double amount,
  double time,
  double rest,
) {
  final k = amount.clamp(0.0, 1.0);
  final (target, freq, swing) = switch (g) {
    // Selam: omuz üstü, hızlı ve dar bilek salınımı.
    CharGesture.wave => (-2.30, 11.0, 0.30),
    // Anlatım: yarı yukarı, yavaş ve geniş — oturanda da okunsun diye
    // salınım büyük, açı alçak (kalkık el hikâyeyi anlatır, selamı değil).
    CharGesture.tell => (-1.25, 2.2, 0.38),
    CharGesture.holdStomach => (0.82, 2.0, 0.05),
    CharGesture.wipeBrow => (-1.82, 2.4, 0.12),
    CharGesture.hammerStrike => (-1.05, 9.5, 1.05),
    CharGesture.none => (0.0, 0.0, 0.0),
  };
  final swung = target + sin(time * freq) * swing * k;
  return rest + (swung - rest) * k;
}

/// Tek meşale helper — civilian + tüm worker tipleri buradan geçer.
/// Sol omuz pivotu (off-hand); sağ kolda alet olabilir (balta/kazma/...).
/// Kol açısı sabit `_kTorchArmAngle` (drawX'ler armL'yi de bu değere
/// kilitler → el meşaleden ayrı görünmez). flicker scale tek varyasyon.
void _torchInLeftHand(
  Canvas c,
  double torchLevel, {
  double shoulderX = -15,
  double shoulderY = -68,
  double time = 0,
  double torchPhase = 0,
}) {
  if (torchLevel <= 0.02) return;
  c.save();
  c.translate(shoulderX, shoulderY);
  c.rotate(_kTorchArmAngle);
  final flick = 1.0 + sin(time * 5.2 + torchPhase) * 0.04;
  c.scale(flick, flick);
  ToolRenderer.drawTorch(c, alpha: torchLevel);
  c.restore();
}

/// Gövde transform — bacaklar ve gölge yere sabit kalır, üst gövde
/// (torso + kol + kafa) sway (yan), lean (öne eğilme), bob (dikey),
/// torsoTwist (yan twist) uygular.
/// Çağırılan kod c.save() yapmış olmalı; restore yine kendi sorumluluğunda.
void _applyTorsoTransform(Canvas c, _Anim anim) {
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

/// Ön yük sprite'ı kolların üstüne çizilir; kavrama temasını geri getirmek
/// için iki elin son 5 px'ini aynı omuz dönüşüyle bir kez daha üste basarız.
/// Bu yalnız iki-elli yükte çalışır; tek elli aletlerin kendi arm callback'i
/// ve silueti korunur.
void _drawCarryGripHands(
  Canvas c,
  _Anim anim,
  Color skin, {
  required double shoulderX,
}) {
  void grip(double shoulderX, double angle) {
    c.save();
    c.translate(shoulderX, -68);
    c.rotate(angle);
    _shadedRect(c, const Rect.fromLTWH(-3.5, 16.5, 7, 5.5), skin);
    c.restore();
  }

  grip(-shoulderX, anim.armL);
  grip(shoulderX, anim.armR);
}

/// Meslek gövdelerinin omuz pivotları küçük farklar taşır. Kavrama elini
/// sabit ±16'ya basmak özellikle muhafızda bileği yükten 4 px ayırıyordu.
double _carryShoulderX(
  VillagerType type, {
  required NpcCostume costume,
  required LifeStage stage,
  required bool primitiveClothing,
}) {
  if (costume == NpcCostume.imperial) return 20;
  if (primitiveClothing) return 16;
  if (!stage.hasProfession) return 15;
  return switch (type) {
    VillagerType.farmer => 15,
    VillagerType.merchant => 16,
    VillagerType.blacksmith => 18,
    VillagerType.guard => 20,
    VillagerType.miner => 16,
    VillagerType.fisher => 15,
    VillagerType.priest => 17,
    VillagerType.shepherd || VillagerType.hunter => 15,
    VillagerType.miller || VillagerType.innkeeper => 16,
  };
}

Color _skinFor(VillagerType type) =>
    (type == VillagerType.blacksmith ||
        type == VillagerType.miner ||
        type == VillagerType.hunter)
    ? _skin2
    : _skin1;

/// Yumuşak yuvarlak kafa, tatlı parlayan göz ve gülümseme (visual'sız fallback).
void _head(Canvas c, Color skin, {double y = -80}) {
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
  _cuteEye(c, 2.4, y, const Color(0xFF6A4A30));
  _smile(c, y);
}

/// Eski meslek çizimlerinin bacak giriş noktası. Geometriyi ayrı bir rijit
/// çubukla tekrar etmek yerine yeni eklemli/shaded bacakla paylaşır.
void _leg(
  Canvas c,
  double hipX,
  double angle,
  Color hose,
  Color boot, {
  double legLift = 0,
}) {
  _shadedLeg(c, hipX, angle, hose, boot, legLift: legLift);
}

/// Animasyonlu kol: shoulder pivot (shoulderX, −68).
void _arm(
  Canvas c,
  double shoulderX,
  double angle,
  Color col, [
  void Function(Canvas)? item,
]) {
  c.save();
  c.translate(shoulderX, -68);
  c.rotate(angle);
  c.drawRect(const Rect.fromLTWH(-4, 0, 8, 20), _f(col));
  item?.call(c);
  c.restore();
}
