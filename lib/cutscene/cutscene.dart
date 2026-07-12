import '../characters/villager_type.dart';
import '../characters/npc_visual.dart';

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
  /// Verilirse [seed] yerine bu görsel kimlik kullanılır — sahnedeki aktörün
  /// oyundaki GERÇEK köylüye birebir benzemesi için (ör. düğün çifti).
  final NpcVisual? visual;
  final double fromX;
  final double toX;
  final double y;
  final double scale;
  final bool flip;
  final bool walk;
  const CutsceneActor({
    required this.type,
    this.seed = 0,
    this.visual,
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

/// Çekimi ilerlemeden önce oyuncudan bir EYLEM bekleyen "kapı". Etkileşimli
/// açılışın çekirdeği — gelecekte 2B ekran etkileşimi de buradan genişler.
enum CutsceneGate {
  none,         // serbest akış (dokun = ilerle)
  tapToIgnite,  // ateşi yakmak için dokun (yanana dek bekler)
  nameVillage,  // köye ad ver (metin girişi onaylanana dek bekler)
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
  /// Çekim ilerlemeden önce beklenen oyuncu eylemi (mini aksiyon).
  final CutsceneGate gate;
  const CutsceneShot({
    required this.bg,
    this.actors = const [],
    this.lines = const [],
    this.panFrom = 0.0,
    this.panTo = 0.0,
    this.zoomFrom = 1.0,
    this.zoomTo = 1.0,
    this.gate = CutsceneGate.none,
  });
}

class Cutscene {
  final List<CutsceneShot> shots;
  const Cutscene(this.shots);
}

/// Köyün kuruluş hikâyesi — açılış sinematiği (yeni oyun). Sakin tempolu,
/// kamera nazikçe oturur; kafile ekranda yürüyüp DURUR (amaçsız kayma yok).
const Cutscene kOpeningCutscene = Cutscene([
  // 1) Geniş vadi, şafak — bağlamı kuran açılış (aktörsüz, nazik zoom).
  CutsceneShot(
    bg: CutsceneBg.valleyDawn,
    panFrom: 0.0,
    panTo: 0.03,
    zoomFrom: 1.0,
    zoomTo: 1.06,
    lines: [
      CutsceneLine(
          'Eski yurtları artık bir anıydı — kıtlık ve yorgunluk onları yollara düşürmüştü.'),
      CutsceneLine(
          'Günlerce yürüdüler: çocuklar, yaşlılar, birkaç hayvan… ve sönmeyen bir umut.'),
    ],
  ),

  // 2) Kafile vadiye varır — soldan girer, ekranda gruplanıp DURUR.
  CutsceneShot(
    bg: CutsceneBg.road,
    panFrom: 0.0,
    panTo: 0.02,
    actors: [
      CutsceneActor(type: VillagerType.guard, seed: 21, fromX: -0.85, toX: 0.66, y: 0.86, scale: 1.2, walk: true),
      CutsceneActor(type: VillagerType.merchant, seed: 3, fromX: -0.62, toX: 0.52, y: 0.80, scale: 1.05, walk: true),
      CutsceneActor(type: VillagerType.farmer, seed: 12, fromX: -0.42, toX: 0.36, y: 0.82, scale: 1.1, walk: true),
      CutsceneActor(type: VillagerType.mage, seed: 7, fromX: -0.22, toX: 0.20, y: 0.78, scale: 1.0, walk: true),
    ],
    lines: [
      CutsceneLine(
          'Sonunda bir vadiye vardılar. Su sesi, çayır kokusu… içleri ilk kez ısındı.'),
    ],
  ),

  // 3) MAPLE TANIŞMA — rehber söz alır, oyuncuya kendini tanıtır (yüz yüze).
  CutsceneShot(
    bg: CutsceneBg.valleyDusk,
    zoomFrom: 1.0,
    zoomTo: 1.05,
    actors: [
      CutsceneActor(type: VillagerType.mage, seed: 7, fromX: 0.42, y: 0.80, scale: 1.6),
    ],
    lines: [
      CutsceneLine('Merhaba, yolcu. Ben Maple — bu kafileye yıllardır yol gösteririm.',
          speaker: 'Maple'),
      CutsceneLine('İşte burası. Bu toprak bizi bekliyormuş gibi… yeni yuvamız olacak.',
          speaker: 'Maple'),
    ],
  ),

  // 4) ADLANDIRMA — ETKİLEŞİM: Maple sorar, oyuncu köye ad verir (kimlik/günce).
  CutsceneShot(
    bg: CutsceneBg.valleyDawn,
    zoomFrom: 1.0,
    zoomTo: 1.04,
    gate: CutsceneGate.nameVillage,
    actors: [
      CutsceneActor(type: VillagerType.mage, seed: 7, fromX: 0.5, y: 0.80, scale: 1.5),
    ],
    lines: [
      CutsceneLine('Söyle bakalım — bu yuvaya ne ad verelim?', speaker: 'Maple'),
    ],
  ),

  // 5) Kapanış — Maple oyuncuyu ateş yerini SEÇMEYE yönlendirir (haritaya geçiş).
  CutsceneShot(
    bg: CutsceneBg.valleyDawn,
    zoomFrom: 1.0,
    zoomTo: 1.04,
    actors: [
      CutsceneActor(type: VillagerType.mage, seed: 7, fromX: 0.5, y: 0.80, scale: 1.5),
    ],
    lines: [
      CutsceneLine('Güzel isim. Bir köy, tek bir kıvılcımla başlar.', speaker: 'Maple'),
      CutsceneLine('Şimdi ilk ateşimizi nereye kuracağımızı sen seç.', speaker: 'Maple'),
    ],
  ),
]);

// İmparatorluk geliş sinematiği artık TALEBE + İTİBARA göre dinamik kurulur
// (scene_imperial._buildImperialCutscene) — sabit metin yerine reaktif bir an.

/// İlk ateş HARİTADA kurulduktan sonra oynayan kısa "ateş yakma" sinematiği.
/// Otomatik yanma animasyonu (gate yok) + Maple'ın hoş geldin sözü.
const Cutscene kFireLightingCutscene = Cutscene([
  CutsceneShot(
    bg: CutsceneBg.fireNight,
    zoomFrom: 1.14,
    zoomTo: 1.0,
    actors: [
      CutsceneActor(type: VillagerType.farmer, seed: 12, fromX: 0.34, y: 0.80, scale: 1.4, flip: true),
      CutsceneActor(type: VillagerType.mage, seed: 7, fromX: 0.66, y: 0.80, scale: 1.45),
    ],
    lines: [
      CutsceneLine('İlk ateş tutuştu — karanlık vadi bir anda bir yuvaya dönüştü.'),
      CutsceneLine('Hoş geldin, kurucu. Gerisi senin elinde.', speaker: 'Maple'),
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
      CutsceneLine('Köyün kapısı artık yorgun yolculara da açık.', speaker: 'Maple'),
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
      CutsceneLine('Zor günler geliyor. Dayanışmaya her zamankinden çok muhtacız.', speaker: 'Maple'),
    ],
  ),
]);

/// Coşkulu düğün sinematiği — GERÇEK çifte göre dinamik kurulur (aktörler
/// oyundaki gelin/damadın görsel kimliğini taşır). Ateş közü gecesinde nikâh +
/// yeminler. "Coşkulu düğün" seçilince oynar (sade düğün sinematiksiz, yalnız
/// dünya-içi alay). scene_wedding bu sahneyi çift olgunlaşınca üretir.
Cutscene weddingCutscene({
  required VillagerType brideType,
  required NpcVisual brideVisual,
  required String brideName,
  required VillagerType groomType,
  required NpcVisual groomVisual,
  required String groomName,
}) {
  return Cutscene([
    // 1) Çift ateş közü gecesinde yan yana — köy onları çevreler (anlatı).
    CutsceneShot(
      bg: CutsceneBg.fireNight,
      zoomFrom: 1.10,
      zoomTo: 1.0,
      actors: [
        CutsceneActor(
            type: brideType, visual: brideVisual,
            fromX: 0.40, y: 0.80, scale: 1.4),
        CutsceneActor(
            type: groomType, visual: groomVisual,
            fromX: 0.60, y: 0.80, scale: 1.4, flip: true),
      ],
      lines: [
        CutsceneLine(
            'Ateş yükseldi, köy çepeçevre toplandı — bu gece bir yuva kuruluyor.'),
      ],
    ),
    // 2) Yeminler — gelin & damat karşılıklı (yüz yüze, hafif zoom).
    CutsceneShot(
      bg: CutsceneBg.fireNight,
      zoomFrom: 1.0,
      zoomTo: 1.06,
      actors: [
        CutsceneActor(
            type: brideType, visual: brideVisual,
            fromX: 0.42, y: 0.80, scale: 1.5),
        CutsceneActor(
            type: groomType, visual: groomVisual,
            fromX: 0.62, y: 0.80, scale: 1.5, flip: true),
      ],
      lines: [
        CutsceneLine('Bu ocağı seninle paylaşmaya geldim.', speaker: groomName),
        CutsceneLine('Ve ben seninle — bu vadi artık ikimizin yurdu.',
            speaker: brideName),
      ],
    ),
    // 3) Kutlama — köy halaya durur (anlatı, sıcak kapanış).
    CutsceneShot(
      bg: CutsceneBg.fireNight,
      zoomFrom: 1.04,
      zoomTo: 1.0,
      actors: [
        CutsceneActor(
            type: brideType, visual: brideVisual,
            fromX: 0.46, y: 0.82, scale: 1.35),
        CutsceneActor(
            type: groomType, visual: groomVisual,
            fromX: 0.58, y: 0.82, scale: 1.35, flip: true),
      ],
      lines: [
        CutsceneLine(
            '$brideName ile $groomName evlendi — ateş başında halaylar gece boyu sürdü.'),
      ],
    ),
  ]);
}
