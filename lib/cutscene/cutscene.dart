import '../characters/villager_type.dart';

/// 2B sinematik ara-sahne veri modeli — storyline'ı tam ekran "film" olarak
/// anlatır. Oyun motorundan (izometrik) ayrı; prosedürel arka plan + mevcut
/// karakter sprite'ları aktör olarak. Player (cutscene_player.dart) yorumlar.

/// Bir çekimin arka plan atmosferi — prosedürel boyanır (ekstra resim yok).
enum CutsceneBg {
  valleyDawn,  // şafak vakti vadi — şeftali→soluk mavi, uzak tepeler
  road,        // yol — gündüz, ufak patika
  valleyDusk,  // akşam — turuncu/mor, tepeler koyu
  fireNight,   // gece + ateş közü — lacivert, yıldız, sıcak hâle
  titleCard,   // koyu vinyet — kapanış/başlık
}

/// Sahnedeki bir aktör — bir çekim boyunca [fromX]→[toX] (normalize 0..1)
/// kayar; [walk] true ise yürüyüş animasyonu oynar. [y] taban çizgisi (0..1).
class CutsceneActor {
  final VillagerType type;
  final int seed;       // NpcVisual.fromSeed — yüz/saç/kıyafet çeşidi
  final double fromX;
  final double toX;
  final double y;
  final double scale;
  final bool flip;
  final bool walk;
  const CutsceneActor({
    required this.type,
    this.seed = 0,
    required this.fromX,
    double? toX,
    this.y = 0.74,
    this.scale = 1.0,
    this.flip = false,
    this.walk = false,
  }) : toX = toX ?? fromX;
}

/// Tek bir diyalog/anlatı satırı. [speaker] null → anlatıcı sesi (kursif).
class CutsceneLine {
  final String? speaker;
  final String text;
  const CutsceneLine(this.text, {this.speaker});
}

/// Bir çekim: arka plan + aktörler + replikler + hafif kamera pan/zoom.
class CutsceneShot {
  final CutsceneBg bg;
  final List<CutsceneActor> actors;
  final List<CutsceneLine> lines;
  /// Kamera parallax pan (normalize, sahne süresince fromX→toX) + zoom.
  final double panFrom;
  final double panTo;
  final double zoomFrom;
  final double zoomTo;
  const CutsceneShot({
    required this.bg,
    this.actors = const [],
    this.lines = const [],
    this.panFrom = 0.0,
    this.panTo = 0.0,
    this.zoomFrom = 1.0,
    this.zoomTo = 1.0,
  });
}

class Cutscene {
  final List<CutsceneShot> shots;
  const Cutscene(this.shots);
}

/// Köyün kuruluş hikâyesi — açılış sinematiği (yeni oyun).
const Cutscene kOpeningCutscene = Cutscene([
  // 1) Geniş vadi, şafak — anlatı açılışı.
  CutsceneShot(
    bg: CutsceneBg.valleyDawn,
    panFrom: 0.0,
    panTo: 0.06,
    zoomFrom: 1.0,
    zoomTo: 1.08,
    lines: [
      CutsceneLine(
          'Eski yurtlarından çok uzakta, küçük bir topluluk yeni bir yuva arıyordu.'),
    ],
  ),

  // 2) Yolda yürüyen kafile — aktörler ekranı geçer.
  CutsceneShot(
    bg: CutsceneBg.road,
    panFrom: 0.0,
    panTo: 0.10,
    actors: [
      CutsceneActor(type: VillagerType.mage, seed: 7, fromX: -0.15, toX: 0.40, y: 0.78, scale: 1.05, walk: true),
      CutsceneActor(type: VillagerType.farmer, seed: 12, fromX: -0.35, toX: 0.22, y: 0.82, scale: 1.15, walk: true),
      CutsceneActor(type: VillagerType.merchant, seed: 3, fromX: -0.55, toX: 0.05, y: 0.86, scale: 1.25, walk: true),
      CutsceneActor(type: VillagerType.guard, seed: 21, fromX: -0.75, toX: -0.12, y: 0.90, scale: 1.35, walk: true),
    ],
    lines: [
      CutsceneLine(
          'Günlerce yürüdüler. Ardlarında bıraktıklarını, önlerinde umudu taşıyarak.'),
    ],
  ),

  // 3) Durup vadiyi süzerler — yaşlı konuşur.
  CutsceneShot(
    bg: CutsceneBg.valleyDusk,
    zoomFrom: 1.0,
    zoomTo: 1.06,
    actors: [
      CutsceneActor(type: VillagerType.mage, seed: 7, fromX: 0.40, y: 0.80, scale: 1.5, flip: false),
      CutsceneActor(type: VillagerType.farmer, seed: 12, fromX: 0.60, y: 0.82, scale: 1.5, flip: true),
    ],
    lines: [
      CutsceneLine('İşte burası. Bu vadi bizi çağırıyor.', speaker: 'Yaşlı'),
      CutsceneLine('Suyu tatlı, toprağı cömert. Burada kalalım.', speaker: 'Yaşlı'),
    ],
  ),

  // 4) İlk ateş — gece, sıcak köz.
  CutsceneShot(
    bg: CutsceneBg.fireNight,
    zoomFrom: 1.12,
    zoomTo: 1.0,
    actors: [
      CutsceneActor(type: VillagerType.farmer, seed: 12, fromX: 0.34, y: 0.80, scale: 1.4, flip: true),
      CutsceneActor(type: VillagerType.merchant, seed: 3, fromX: 0.66, y: 0.80, scale: 1.4, flip: false),
    ],
    lines: [
      CutsceneLine(
          'İlk ateşi yaktıklarında, karanlık vadi bir yuvaya dönüştü.'),
    ],
  ),

  // 5) Kapanış kartı.
  CutsceneShot(
    bg: CutsceneBg.titleCard,
    zoomFrom: 1.0,
    zoomTo: 1.05,
    lines: [
      CutsceneLine('Ve böylece, senin köyünün hikâyesi başladı.'),
    ],
  ),
]);

// ── Tüzük kademe sinematikleri (nadir, büyük anlar) ──────────────────────────

/// Tüzük kademesine ulaşıldığında oynar (tier 1/2/3). tier 3 = final/zafer.
/// Yoksa null (kademe 0 sinematiksiz).
Cutscene? cutsceneForTier(int tier) => switch (tier) {
      1 => _kTier1Cutscene,
      2 => _kTier2Cutscene,
      3 => _kTier3Cutscene,
      _ => null,
    };

// Kademe 1 — Konuksever Köy.
const Cutscene _kTier1Cutscene = Cutscene([
  CutsceneShot(
    bg: CutsceneBg.valleyDawn,
    zoomFrom: 1.0,
    zoomTo: 1.06,
    actors: [
      CutsceneActor(type: VillagerType.merchant, seed: 3, fromX: -0.2, toX: 0.40, y: 0.80, scale: 1.2, walk: true),
      CutsceneActor(type: VillagerType.farmer, seed: 12, fromX: 0.66, y: 0.82, scale: 1.3, flip: true),
    ],
    lines: [
      CutsceneLine('İlk ocaklar çoğaldı, yollar aşındı.'),
      CutsceneLine('Köyün kapısı artık yorgun yolculara da açık.', speaker: 'Yaşlı'),
    ],
  ),
]);

// Kademe 2 — Şenlikli Kasaba.
const Cutscene _kTier2Cutscene = Cutscene([
  CutsceneShot(
    bg: CutsceneBg.valleyDusk,
    zoomFrom: 1.08,
    zoomTo: 1.0,
    actors: [
      CutsceneActor(type: VillagerType.farmer, seed: 12, fromX: 0.30, y: 0.82, scale: 1.25, flip: true),
      CutsceneActor(type: VillagerType.mage, seed: 7, fromX: 0.50, y: 0.80, scale: 1.3),
      CutsceneActor(type: VillagerType.guard, seed: 21, fromX: 0.70, y: 0.82, scale: 1.25),
    ],
    lines: [
      CutsceneLine('Pazar kuruldu, tezgâhlar doldu, akşamlar şenlendi.'),
      CutsceneLine('Küçük köy, artık bir kasaba.'),
    ],
  ),
]);

// Kademe 3 — Bereketli Kasaba (final / zafer).
const Cutscene _kTier3Cutscene = Cutscene([
  CutsceneShot(
    bg: CutsceneBg.valleyDawn,
    zoomFrom: 1.0,
    zoomTo: 1.10,
    actors: [
      CutsceneActor(type: VillagerType.merchant, seed: 3, fromX: 0.24, y: 0.84, scale: 1.2, flip: true),
      CutsceneActor(type: VillagerType.farmer, seed: 12, fromX: 0.44, y: 0.82, scale: 1.3),
      CutsceneActor(type: VillagerType.mage, seed: 7, fromX: 0.62, y: 0.80, scale: 1.3, flip: true),
      CutsceneActor(type: VillagerType.guard, seed: 21, fromX: 0.78, y: 0.84, scale: 1.2),
    ],
    lines: [
      CutsceneLine('Ambarlar doldu, çocuklar büyüdü, vadi bereketle örtüldü.'),
    ],
  ),
  CutsceneShot(
    bg: CutsceneBg.titleCard,
    zoomFrom: 1.0,
    zoomTo: 1.05,
    lines: [
      CutsceneLine(
          'Bir zamanlar yalnız bir ateş olan yer, artık müreffeh bir kasaba. '
          'Hikâyen burada bitmiyor — daha nice bahar gelecek.'),
    ],
  ),
]);

/// Nadir büyük kriz — kıtlık. event/tick tarafından bir kez tetiklenir.
const Cutscene kFamineCutscene = Cutscene([
  CutsceneShot(
    bg: CutsceneBg.valleyDusk,
    zoomFrom: 1.06,
    zoomTo: 1.0,
    actors: [
      CutsceneActor(type: VillagerType.farmer, seed: 12, fromX: 0.42, y: 0.82, scale: 1.3),
      CutsceneActor(type: VillagerType.mage, seed: 7, fromX: 0.62, y: 0.80, scale: 1.25, flip: true),
    ],
    lines: [
      CutsceneLine('Yağmurlar geç kaldı, ambarlar boşaldı.'),
      CutsceneLine('Zor günler geliyor. Dayanışmaya her zamankinden çok muhtacız.', speaker: 'Yaşlı'),
    ],
  ),
]);
