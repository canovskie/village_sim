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

  /// KUŞBAKIŞI — izometrik yüksek açı. Bu oyunda "yukarıdan bakmak" yeni bir
  /// çizim tekniği değil, oyunun kendi dili: game_painter da aynı dik figürleri
  /// gridToScreen ile küçük küçük yerleştiriyor. Ölçek anlatan çekimler için
  /// (köy büyüdü / kolon iniyor / tarlalar boş). Yoğunluk [CutsceneShot.aerialGrowth].
  aerial,
}

/// Sahnedeki bir aktör — bir çekim boyunca [fromX]→[toX] (normalize 0..1)
/// kayar; [walk] true ise yürüyüş animasyonu oynar. [y] taban çizgisi (0..1).
class CutsceneActor {
  final VillagerType type;
  /// Aktörün adı — [CutsceneLine.speaker] ile eşleşirse o replik boyunca ışık
  /// bu aktörün üstünde kalır, sahnedeki diğerleri karartılır (kimin konuştuğu
  /// belli olsun; ör. üç aynı muhafız arasında komutan).
  final String? name;
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
    this.name,
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

/// Çekimin ölçeği — kamerayı özneye göre konumlandırır. Diyalog kutusu +
/// letterbox ekranın altını yediği için ÖZNENİN NEREYE OTURACAĞI kadraja bağlı.
enum CutsceneFraming {
  /// Geniş plan — mekân başrolde, özne küçük. Kamera özneyi kollamaz.
  wide,

  /// Orta plan (varsayılan) — özne tam boy. Ayak basma noktası her zaman
  /// diyalog kutusunun ÜSTÜNDE tutulur; figür havada asılı kalmaz.
  mid,

  /// Yakın plan — özne büyük, bel altı kasıtlı olarak kadraj dışında. Kamera
  /// gövdenin üst yarısını görünür banda oturtur + biraz yaklaşır.
  close,
}

/// Bir çekim: arka plan + aktörler + replikler + hafif kamera pan/zoom.
class CutsceneShot {
  final CutsceneBg bg;
  final List<CutsceneActor> actors;
  final List<CutsceneLine> lines;
  /// Kamera parallax pan (normalize, sahne süresince fromX→toX) + zoom.
  final double panFrom;
  final double panTo;
  /// Dikey pan (tilt) — ekran yüksekliğinin oranı. Pozitif = kamera YUKARI
  /// bakar (gökten aşağı inmek için tiltFrom negatif verilir).
  final double tiltFrom;
  final double tiltTo;
  /// Zoom artık tek parça büyütme değil DOLLY: katmanlar derinliğine göre
  /// farklı oranda büyür (yakın katman hızlı) → sahneye girme hissi.
  final double zoomFrom;
  final double zoomTo;
  /// Çekimin ölçeği — kameranın özneyi nasıl kadrajlayacağı.
  final CutsceneFraming framing;

  /// ÖZNEL KAMERA — kamera artık sahneyi seyreden bir göz değil, KÖYÜN ORTAK
  /// GÖZÜ: halkanın içinden bakan isimsiz biri. Kadrajda özne yoktur; kenarlarda
  /// komşuların omuzları durur, kamera nefesle salınır ve çekim göz kapağı
  /// açılışıyla başlar. Anlatı da ona göre yazılır (birinci çoğul: "halka olduk").
  final bool pov;

  /// [CutsceneBg.aerial] için köyün büyüklüğü (0..1) — kademe filmlerinde köyün
  /// gözle görülür biçimde büyümesi buradan.
  final double aerialGrowth;
  /// Çekim ilerlemeden önce beklenen oyuncu eylemi (mini aksiyon).
  final CutsceneGate gate;
  const CutsceneShot({
    required this.bg,
    this.actors = const [],
    this.lines = const [],
    this.panFrom = 0.0,
    this.panTo = 0.0,
    this.tiltFrom = 0.0,
    this.tiltTo = 0.0,
    this.zoomFrom = 1.0,
    this.zoomTo = 1.0,
    this.framing = CutsceneFraming.mid,
    this.pov = false,
    this.aerialGrowth = 0.5,
    this.gate = CutsceneGate.none,
  });
}

class Cutscene {
  final List<CutsceneShot> shots;
  const Cutscene(this.shots);
}

/// Köyün kuruluş hikâyesi — açılış sinematiği (yeni oyun).
///
/// Ton: **imparatorluğun vergi elinden kaçış**. Bu, oyunun sonraki İmparatorluk
/// tehdidine (scene_imperial) tohum bırakır: gölge bir gün geri gelecek.
/// Hikâye YALNIZ açılışta yüklüdür; sonra pasifleşir (dünya sessizce açılır).
/// Sakin tempolu; kafile ekranda yürüyüp DURUR (amaçsız kayma yok).
const Cutscene kOpeningCutscene = Cutscene([
  // 1) NEDEN yola düştüler — vergi eli. Bağlamı kuran açılış (aktörsüz).
  CutsceneShot(
    bg: CutsceneBg.valleyDusk,
    framing: CutsceneFraming.wide,
    panFrom: 0.0,
    panTo: 0.03,
    zoomFrom: 1.0,
    zoomTo: 1.06,
    lines: [
      CutsceneLine(
          'Vergiciler her harmanda gelirdi. İlk yıl tahılın üçte birini aldılar. Sonra yarısını.'),
      CutsceneLine(
          'Son gelişlerinde ambarda ölçecek bir şey kalmamıştı. Yine de deftere bir şey yazdılar.'),
    ],
  ),

  // 2) Kaçış / yol — kafile soldan girer, ekranda gruplanıp DURUR.
  CutsceneShot(
    bg: CutsceneBg.road,
    panFrom: 0.0,
    panTo: 0.02,
    // Kamera gökten aşağı iner ve kafileyi bulur (tilt) + hafifçe yaklaşır.
    tiltFrom: -0.10,
    tiltTo: 0.0,
    zoomFrom: 1.0,
    zoomTo: 1.05,
    actors: [
      // Varış sırası GİRİŞ sırasıyla aynı olmalı: en önde giren en sağda durur.
      // Ters verilirse öndeki kafile üyesi durur, arkadaki onun İÇİNDEN geçip
      // öne gider — kafile değil, hayalet geçişi olur.
      CutsceneActor(type: VillagerType.guard, seed: 21, fromX: -0.85, toX: 0.18, y: 0.86, scale: 1.2, walk: true),
      CutsceneActor(type: VillagerType.merchant, seed: 3, fromX: -0.62, toX: 0.34, y: 0.80, scale: 1.05, walk: true),
      CutsceneActor(type: VillagerType.farmer, seed: 12, fromX: -0.42, toX: 0.50, y: 0.82, scale: 1.1, walk: true),
      CutsceneActor(type: VillagerType.priest, seed: 7, fromX: -0.22, toX: 0.68, y: 0.78, scale: 1.0, walk: true),
    ],
    lines: [
      CutsceneLine(
          'Bir gece, birkaç hane kapısını çekip kilitlemedi bile. Kilitlenecek ne kalmıştı ki.'),
      CutsceneLine(
          'Günlerce yürüdüler. Yaşlılar arabada, çocuklar arkada, bir de topal keçi. Kimse nereye gittiğini bilmiyordu; herkes neden gittiğini biliyordu.'),
    ],
  ),

  // 3) Varış — şafakta vadi görünür. İlk kez nefes.
  CutsceneShot(
    bg: CutsceneBg.valleyDawn,
    framing: CutsceneFraming.wide,
    panFrom: 0.0,
    panTo: 0.04,
    // Sis çekilirken kamera yerden ufka doğru kalkar.
    tiltFrom: 0.08,
    tiltTo: -0.03,
    zoomFrom: 1.06,
    zoomTo: 1.0,
    lines: [
      CutsceneLine(
          'Şafakta sis çekildi ve vadi göründü. Önce suyun sesi geldi, sonra çayırın kokusu.'),
      CutsceneLine(
          'Ne bir sınır taşı vardı burada, ne bir vergi defteri. Kimsenin adı yazılı değildi bu toprağa.'),
    ],
  ),

  // 4) MAPLE TANIŞMA — rehber söz alır; imparatorluğun gölgesini anar (yay tohumu).
  CutsceneShot(
    bg: CutsceneBg.valleyDusk,
    zoomFrom: 1.0,
    zoomTo: 1.05,
    actors: [
      CutsceneActor(type: VillagerType.priest, name: 'Maple', seed: 7, fromX: 0.42, y: 0.80, scale: 1.6),
    ],
    lines: [
      CutsceneLine('Ben Maple. Bu kafileyi yıllardır ben yürütüyorum. Bu vadiyi ben de ilk kez görüyorum.',
          speaker: 'Maple'),
      CutsceneLine('İmparatorluk buraya uzak. Şimdilik. Burada yakacağın ateşin dumanını kimse saymayacak.',
          speaker: 'Maple'),
    ],
  ),

  // 5) ADLANDIRMA — ETKİLEŞİM: Maple sorar, oyuncu köye ad verir (kimlik/günce).
  CutsceneShot(
    bg: CutsceneBg.valleyDawn,
    zoomFrom: 1.0,
    zoomTo: 1.04,
    gate: CutsceneGate.nameVillage,
    actors: [
      CutsceneActor(type: VillagerType.priest, name: 'Maple', seed: 7, fromX: 0.5, y: 0.80, scale: 1.5),
    ],
    lines: [
      CutsceneLine('Adı olmayan yere kimse dönmez. Söyle, buraya ne diyeceğiz?',
          speaker: 'Maple'),
    ],
  ),

  // 6) Kapanış — ateş yerini SEÇMEYE yönlendirir. Son satır, dünyanın ateşin
  // ışığından büyüyeceğini söyler → zoom-reveal'ın (kamera reach'i) anlatısı.
  CutsceneShot(
    bg: CutsceneBg.valleyDawn,
    zoomFrom: 1.0,
    zoomTo: 1.04,
    actors: [
      CutsceneActor(type: VillagerType.priest, name: 'Maple', seed: 7, fromX: 0.5, y: 0.80, scale: 1.5),
    ],
    lines: [
      CutsceneLine('Güzel ad. Şimdi geriye tek iş kaldı: ısınmak.', speaker: 'Maple'),
      CutsceneLine('İlk ateşi nereye kuracağımızı sen seç. Işığı nereye düşerse, vadi oradan açılır.',
          speaker: 'Maple'),
    ],
  ),
]);

// İmparatorluk geliş sinematiği artık TALEBE + İTİBARA göre dinamik kurulur
// (scene_imperial._buildImperialCutscene) — sabit metin yerine reaktif bir an.

/// İlk ateş HARİTADA kurulduktan sonra oynayan kısa "ateş yakma" sinematiği.
/// Otomatik yanma animasyonu (gate yok) + Maple'ın hoş geldin sözü.
/// POV: kamera KÖYÜN ORTAK GÖZÜ — halkanın içinden bakan isimsiz biri. Kadrajda
/// özne yok; iki yanda komşuların omuzları duruyor, çekim göz kapağıyla açılıyor.
/// Anlatı da ona göre birinci çoğul.
const Cutscene kFireLightingCutscene = Cutscene([
  CutsceneShot(
    bg: CutsceneBg.fireNight,
    pov: true,
    tiltFrom: 0.06,
    tiltTo: -0.02,
    zoomFrom: 1.14,
    zoomTo: 1.0,
    actors: [
      CutsceneActor(type: VillagerType.farmer, seed: 12, fromX: 0.30, y: 0.80, scale: 1.2, flip: true),
      CutsceneActor(type: VillagerType.priest, name: 'Maple', seed: 7, fromX: 0.70, y: 0.80, scale: 1.25),
    ],
    lines: [
      CutsceneLine(
          'Çıra tutuştu. İlk kez halka olduk; eller ateşe uzandı, kimse ilk sözü söylemedi.'),
      CutsceneLine(
          'Yüzler karşıdan aydınlandı. Hiçbir deftere geçmeyen bir ısıydı bu.'),
      CutsceneLine('Oturun, ısının. Yarından sonrası size kalmış.', speaker: 'Maple'),
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
  // Kuşbakışı: "ocaklar çoğaldı" cümlesini KADRAJ söyler, metin değil.
  CutsceneShot(
    bg: CutsceneBg.aerial,
    aerialGrowth: 0.30,
    framing: CutsceneFraming.wide,
    zoomFrom: 1.0,
    zoomTo: 1.08,
    lines: [
      CutsceneLine('Ocaklar çoğaldı. Patika, gide gele yola dönüştü.'),
    ],
  ),
  CutsceneShot(
    bg: CutsceneBg.valleyDawn,
    zoomFrom: 1.0,
    zoomTo: 1.05,
    actors: [
      CutsceneActor(type: VillagerType.merchant, seed: 3, fromX: -0.2, toX: 0.40, y: 0.80, scale: 1.2, walk: true),
      CutsceneActor(type: VillagerType.priest, name: 'Maple', seed: 7, fromX: 0.68, y: 0.82, scale: 1.3, flip: true),
    ],
    lines: [
      CutsceneLine('Artık yabancı da geliyor. Kapıyı açık tutalım; bir zamanlar yabancı bizdik.',
          speaker: 'Maple'),
    ],
  ),
]);

// Kademe 2 — Şenlikli Kasaba.
const Cutscene _kTier2Cutscene = Cutscene([
  CutsceneShot(
    bg: CutsceneBg.aerial,
    aerialGrowth: 0.65,
    framing: CutsceneFraming.wide,
    zoomFrom: 1.10,
    zoomTo: 1.0,
    lines: [
      CutsceneLine('Pazar kuruldu. Tezgâhta üç çeşit peynir var, biri komşu vadiden.'),
    ],
  ),
  CutsceneShot(
    bg: CutsceneBg.valleyDusk,
    zoomFrom: 1.08,
    zoomTo: 1.0,
    actors: [
      CutsceneActor(type: VillagerType.farmer, seed: 12, fromX: 0.30, y: 0.82, scale: 1.25, flip: true),
      CutsceneActor(type: VillagerType.priest, seed: 7, fromX: 0.50, y: 0.80, scale: 1.3),
      CutsceneActor(type: VillagerType.guard, seed: 21, fromX: 0.70, y: 0.82, scale: 1.25),
    ],
    lines: [
      CutsceneLine('Akşamları meydandan kaval sesi geliyor. Buraya artık köy demiyorlar.'),
    ],
  ),
]);

// Kademe 3 — Bereketli Kasaba (final / zafer).
const Cutscene _kTier3Cutscene = Cutscene([
  CutsceneShot(
    bg: CutsceneBg.aerial,
    aerialGrowth: 1.0,
    framing: CutsceneFraming.wide,
    zoomFrom: 1.0,
    zoomTo: 1.12,
    lines: [
      CutsceneLine('Ambarlar kışa hazır. İlk gelen çocuklar şimdi kendi çocuklarını taşıyor.'),
    ],
  ),
  CutsceneShot(
    bg: CutsceneBg.valleyDawn,
    zoomFrom: 1.0,
    zoomTo: 1.10,
    actors: [
      CutsceneActor(type: VillagerType.merchant, seed: 3, fromX: 0.24, y: 0.84, scale: 1.2, flip: true),
      CutsceneActor(type: VillagerType.farmer, seed: 12, fromX: 0.44, y: 0.82, scale: 1.3),
      CutsceneActor(type: VillagerType.priest, seed: 7, fromX: 0.62, y: 0.80, scale: 1.3, flip: true),
      CutsceneActor(type: VillagerType.guard, seed: 21, fromX: 0.78, y: 0.84, scale: 1.2),
    ],
    lines: [
      CutsceneLine('Kimse kimseye nereden geldiğini sormuyor artık.'),
    ],
  ),
  CutsceneShot(
    bg: CutsceneBg.titleCard,
    zoomFrom: 1.0,
    zoomTo: 1.05,
    lines: [
      CutsceneLine(
          'Burası bir zamanlar bir avuç köz idi. Şimdi kimse buraya nereden geldiğini sormuyor. '
          'Hikâye bitmedi; sadece anlatacak insan çoğaldı.'),
    ],
  ),
]);

/// Nadir büyük kriz — kıtlık. event/tick tarafından bir kez tetiklenir.
const Cutscene kFamineCutscene = Cutscene([
  CutsceneShot(
    bg: CutsceneBg.aerial,
    aerialGrowth: 0.55,
    framing: CutsceneFraming.wide,
    zoomFrom: 1.06,
    zoomTo: 1.0,
    lines: [
      CutsceneLine('Tarlalar boş. Yukarıdan bakınca köy hâlâ yerinde duruyor; eksik olan görünmüyor.'),
    ],
  ),
  CutsceneShot(
    bg: CutsceneBg.valleyDusk,
    zoomFrom: 1.06,
    zoomTo: 1.0,
    actors: [
      CutsceneActor(type: VillagerType.farmer, seed: 12, fromX: 0.42, y: 0.82, scale: 1.3),
      CutsceneActor(type: VillagerType.priest, name: 'Maple', seed: 7, fromX: 0.62, y: 0.80, scale: 1.25, flip: true),
    ],
    lines: [
      CutsceneLine('Yağmur gelmedi. Ambarın dibi göründü, kimse yüksek sesle söylemedi.'),
      CutsceneLine('Kış uzun olacak. Kaşığı bölüşenler açlığı da bölüşür.', speaker: 'Maple'),
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
            type: brideType, name: brideName, visual: brideVisual,
            fromX: 0.40, y: 0.80, scale: 1.4),
        CutsceneActor(
            type: groomType, name: groomName, visual: groomVisual,
            fromX: 0.60, y: 0.80, scale: 1.4, flip: true),
      ],
      lines: [
        CutsceneLine(
            'Ateşe fazladan odun attılar. Köy halka oldu, ortada iki kişi kaldı.'),
      ],
    ),
    // 2) Yeminler — gelin & damat karşılıklı (yüz yüze, hafif zoom).
    CutsceneShot(
      bg: CutsceneBg.fireNight,
      zoomFrom: 1.0,
      zoomTo: 1.06,
      actors: [
        CutsceneActor(
            type: brideType, name: brideName, visual: brideVisual,
            fromX: 0.42, y: 0.80, scale: 1.5),
        CutsceneActor(
            type: groomType, name: groomName, visual: groomVisual,
            fromX: 0.62, y: 0.80, scale: 1.5, flip: true),
      ],
      lines: [
        CutsceneLine('Ben ekmeğimi bölmeye geldim. Yarısı senin.', speaker: groomName),
        CutsceneLine('Bölmene gerek yok. Bundan sonra aynı sofradan yiyoruz.',
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
            type: brideType, name: brideName, visual: brideVisual,
            fromX: 0.46, y: 0.82, scale: 1.35),
        CutsceneActor(
            type: groomType, name: groomName, visual: groomVisual,
            fromX: 0.58, y: 0.82, scale: 1.35, flip: true),
      ],
      lines: [
        CutsceneLine(
            '$brideName ile $groomName evlendi. Halay gün ağarana kadar sürdü; ertesi gün kimse tarlaya erken çıkmadı.'),
      ],
    ),
  ]);
}
