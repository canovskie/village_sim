import '../characters/npc_visual.dart';
import '../characters/villager_type.dart';

/// 2B sinematik ara-sahne veri modeli — storyline'ı tam ekran "film" olarak
/// anlatır. Oyun motorundan (izometrik) ayrı; prosedürel arka plan + mevcut
/// karakter sprite'ları aktör olarak. Player (cutscene_player.dart) yorumlar.

/// Bir çekimin arka plan atmosferi — prosedürel boyanır (ekstra resim yok).
enum CutsceneBg {
  valleyDawn, // şafak vakti vadi — şeftali→soluk mavi, uzak tepeler
  road, // yol — gündüz, ufak patika
  valleyDusk, // akşam — turuncu/mor, tepeler koyu
  fireNight, // gece + ateş közü — lacivert, yıldız, sıcak hâle
  titleCard, // koyu vinyet — kapanış/başlık
}

/// Sahnedeki bir aktör — bir çekim boyunca [fromX]→[toX] (normalize 0..1)
/// kayar; [walk] true ise yürüyüş animasyonu oynar. [y] taban çizgisi (0..1).
class CutsceneActor {
  final VillagerType type;

  /// Aktörün adı — [CutsceneLine.speaker] ile eşleşirse o replik boyunca ışık
  /// bu aktörün üstünde kalır, sahnedeki diğerleri karartılır (kimin konuştuğu
  /// belli olsun; ör. üç aynı muhafız arasında komutan).
  final String? name;
  final int seed; // NpcVisual.fromSeed — yüz/saç/kıyafet çeşidi
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
  none, // serbest akış (dokun = ilerle)
  tapToIgnite, // ateşi yakmak için dokun (yanana dek bekler)
  nameVillage, // köye + haneye ad ver (iki alan onaylanana dek bekler)
  /// Kafilenin yükünü seç — üç kart, biri seçilene dek bekler. Sinematiğin
  /// içine gömülü İLK gerçek karar; kadroyu ve stoğu değiştirir
  /// (bkz. [FoundingChoice]).
  chooseCaravan,
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
///
/// ÜÇ ÇEKİM (eskiden altıydı, on bir replikle). Açılış "izlenen" bir film
/// olmaktan çıkıp KARAR VERİLEN bir eşik oldu: kısalan her çekimin sonunda
/// oyuncunun eli var — kafilenin yükü (kadro + stok) ve köyün/hanenin adı.
/// Üçüncü çekim biter bitmez oyuncu gerçek haritada ateşin yerini seçer.
const Cutscene kOpeningCutscene = Cutscene([
  // 1) NEDEN yola düştük + YOL — tek çekim. Eskiden bu ikisi ayrı iki çekimdi
  //    (dört replik); anlattıkları tek şeydi: vergi eli sıkınca yürüdük.
  //    Kafile bu çekimde ekrana girer, gruplanır ve DURUR.
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
      CutsceneActor(
        type: VillagerType.guard,
        seed: 21,
        fromX: -0.85,
        toX: 0.18,
        y: 0.86,
        scale: 1.2,
        walk: true,
      ),
      CutsceneActor(
        type: VillagerType.merchant,
        seed: 3,
        fromX: -0.62,
        toX: 0.34,
        y: 0.80,
        scale: 1.05,
        walk: true,
      ),
      CutsceneActor(
        type: VillagerType.farmer,
        seed: 12,
        fromX: -0.42,
        toX: 0.50,
        y: 0.82,
        scale: 1.1,
        walk: true,
      ),
      CutsceneActor(
        type: VillagerType.priest,
        seed: 7,
        fromX: -0.22,
        toX: 0.68,
        y: 0.78,
        scale: 1.0,
        walk: true,
      ),
    ],
    lines: [
      CutsceneLine(
        'Vergiciler her harmanda geldi. Son gelişlerinde ambarda ölçecek bir şey yoktu; yine de deftere bir şey yazdılar.',
      ),
      CutsceneLine(
        'O gece birkaç hane kapısını kilitlemedi bile. Kimse nereye gittiğini bilmiyordu; herkes neden gittiğini biliyordu.',
      ),
    ],
  ),

  // 2) VARIŞ + İLK KARAR — kafilenin yükü. Maple sorar, oyuncu SEÇER.
  //    Bu kapı gerçek bir karardır: kurucu meslekler, nüfus ve başlangıç stoğu
  //    buradan çıkar (bkz. systems/founding_choice.dart).
  CutsceneShot(
    bg: CutsceneBg.valleyDawn,
    panFrom: 0.0,
    panTo: 0.03,
    tiltFrom: 0.06,
    tiltTo: -0.02,
    zoomFrom: 1.05,
    zoomTo: 1.0,
    gate: CutsceneGate.chooseCaravan,
    actors: [
      CutsceneActor(
        type: VillagerType.priest,
        name: 'Maple',
        seed: 7,
        fromX: 0.46,
        y: 0.80,
        scale: 1.45,
      ),
    ],
    lines: [
      CutsceneLine(
        'Ben Maple. Bu kafileyi yıllardır ben yürütüyorum; bu vadiyi ben de ilk kez görüyorum.',
        speaker: 'Maple',
      ),
      CutsceneLine(
        'Yola çıkarken arabaya her şey sığmadı. Söyle bakalım — biz neyi yükledik?',
        speaker: 'Maple',
      ),
    ],
  ),

  // 3) VARIŞ — gerçek oyunda isim kapısı bastırılır; oyuncu önce gerçek
  // haritada ateşi kurar. Bağımsız galeri/test kullanımı için kapı korunur.
  CutsceneShot(
    bg: CutsceneBg.valleyDusk,
    zoomFrom: 1.0,
    zoomTo: 1.04,
    gate: CutsceneGate.nameVillage,
    actors: [
      // Maple SAĞDA durur: ad panosu iki alanlı olduğu için ekranın ortasını
      // kaplıyor ve merkezdeki aktörün yüzünü yutuyordu (soruyu soran kişi
      // sorusu ekranda dururken görünmeli).
      CutsceneActor(
        type: VillagerType.priest,
        name: 'Maple',
        seed: 7,
        fromX: 0.72,
        y: 0.80,
        scale: 1.5,
      ),
    ],
    lines: [
      CutsceneLine(
        'İmparatorluk buraya uzak. Şimdilik. Burada yakacağın ateşin dumanını kimse saymayacak.',
        speaker: 'Maple',
      ),
      CutsceneLine(
        'Önce ateşi kurup şu vadiyi bizim yerimiz yapalım. Adını sonra birlikte koyarsın.',
        speaker: 'Maple',
      ),
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
      CutsceneActor(
        type: VillagerType.farmer,
        seed: 12,
        fromX: 0.30,
        y: 0.80,
        scale: 1.2,
        flip: true,
      ),
      CutsceneActor(
        type: VillagerType.priest,
        name: 'Maple',
        seed: 7,
        fromX: 0.70,
        y: 0.80,
        scale: 1.25,
      ),
    ],
    lines: [
      CutsceneLine(
        'Çıra tutuştu. İlk kez halka olduk; eller ateşe uzandı, kimse ilk sözü söylemedi.',
      ),
      CutsceneLine(
        'Yüzler karşıdan aydınlandı. Hiçbir deftere geçmeyen bir ısıydı bu.',
      ),
      CutsceneLine(
        'Oturun, ısının. Yarından sonrası size kalmış.',
        speaker: 'Maple',
      ),
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
  4 => _kTier4Cutscene,
  5 => _kTier5Cutscene,
  _ => null,
};

// Kademe 1 — Konuksever Köy.
const Cutscene _kTier1Cutscene = Cutscene([
  CutsceneShot(
    bg: CutsceneBg.valleyDawn,
    zoomFrom: 1.0,
    zoomTo: 1.05,
    actors: [
      CutsceneActor(
        type: VillagerType.merchant,
        seed: 3,
        fromX: -0.2,
        toX: 0.40,
        y: 0.80,
        scale: 1.2,
        walk: true,
      ),
      CutsceneActor(
        type: VillagerType.priest,
        name: 'Maple',
        seed: 7,
        fromX: 0.68,
        y: 0.82,
        scale: 1.3,
        flip: true,
      ),
    ],
    lines: [
      CutsceneLine('Ocaklar çoğaldı. Patika, gide gele yola dönüştü.'),
      CutsceneLine(
        'Artık yabancı da geliyor. Kapıyı açık tutalım; bir zamanlar yabancı bizdik.',
        speaker: 'Maple',
      ),
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
      CutsceneActor(
        type: VillagerType.farmer,
        seed: 12,
        fromX: 0.30,
        y: 0.82,
        scale: 1.25,
        flip: true,
      ),
      CutsceneActor(
        type: VillagerType.priest,
        seed: 7,
        fromX: 0.50,
        y: 0.80,
        scale: 1.3,
      ),
      CutsceneActor(
        type: VillagerType.guard,
        seed: 21,
        fromX: 0.70,
        y: 0.82,
        scale: 1.25,
      ),
    ],
    lines: [
      CutsceneLine(
        'Pazar kuruldu. Tezgâhta üç çeşit peynir var, biri komşu vadiden.',
      ),
      CutsceneLine(
        'Akşamları meydandan kaval sesi geliyor. Buraya artık köy demiyorlar.',
      ),
    ],
  ),
]);

// Kademe 3 — Bereketli Kasaba. (Merdiven burada BİTMİYOR: 4 ve 5 geç oyun
// kademeleri sonradan eklendi, asıl kapanış artık _kTier5Cutscene. Buradaki
// "hikâye bitmedi" repliği tam da bu yüzden yerinde kaldı.)
const Cutscene _kTier3Cutscene = Cutscene([
  CutsceneShot(
    bg: CutsceneBg.valleyDawn,
    zoomFrom: 1.0,
    zoomTo: 1.10,
    actors: [
      CutsceneActor(
        type: VillagerType.merchant,
        seed: 3,
        fromX: 0.24,
        y: 0.84,
        scale: 1.2,
        flip: true,
      ),
      CutsceneActor(
        type: VillagerType.farmer,
        seed: 12,
        fromX: 0.44,
        y: 0.82,
        scale: 1.3,
      ),
      CutsceneActor(
        type: VillagerType.priest,
        seed: 7,
        fromX: 0.62,
        y: 0.80,
        scale: 1.3,
        flip: true,
      ),
      CutsceneActor(
        type: VillagerType.guard,
        seed: 21,
        fromX: 0.78,
        y: 0.84,
        scale: 1.2,
      ),
    ],
    lines: [
      CutsceneLine(
        'Ambarlar kışa hazır. İlk gelen çocuklar şimdi kendi çocuklarını taşıyor.',
      ),
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
        'Hikâye bitmedi; sadece anlatacak insan çoğaldı.',
      ),
    ],
  ),
]);

// Kademe 4 — Adı Duyulan Kaza.
//
// Kademe filmlerinin çevirdiği eksen: 0-3 "köy kuruluyor", 4-5 "köyün bir ADI
// ve bir DURUŞU oluyor". Bu yüzden 4'te ilk kez sahnede köyün DIŞINDAN biri
// var ve köyü adıyla arıyor. Yeni bir arka plan yazmadım: yol (road) tam da
// bu sahnenin mekânı.
const Cutscene _kTier4Cutscene = Cutscene([
  CutsceneShot(
    bg: CutsceneBg.road,
    zoomFrom: 1.06,
    zoomTo: 1.0,
    actors: [
      CutsceneActor(
        type: VillagerType.merchant,
        seed: 31,
        fromX: -0.15,
        toX: 0.34,
        y: 0.83,
        scale: 1.2,
        walk: true,
      ),
      CutsceneActor(
        type: VillagerType.guard,
        name: 'Nöbetçi',
        seed: 21,
        fromX: 0.66,
        y: 0.82,
        scale: 1.25,
        flip: true,
      ),
    ],
    lines: [
      CutsceneLine('Yolcu yolu sormadı. Doğru sapağı biliyordu.'),
      CutsceneLine(
        'Bu sefer tarif eden benim değil, adımız olmuş.',
        speaker: 'Nöbetçi',
      ),
    ],
  ),
  CutsceneShot(
    bg: CutsceneBg.valleyDusk,
    zoomFrom: 1.0,
    zoomTo: 1.08,
    actors: [
      CutsceneActor(
        type: VillagerType.priest,
        seed: 7,
        fromX: 0.30,
        y: 0.82,
        scale: 1.3,
      ),
      CutsceneActor(
        type: VillagerType.miller,
        seed: 44,
        fromX: 0.52,
        y: 0.83,
        scale: 1.25,
        flip: true,
      ),
      CutsceneActor(
        type: VillagerType.blacksmith,
        seed: 9,
        fromX: 0.72,
        y: 0.82,
        scale: 1.3,
        flip: true,
      ),
    ],
    lines: [
      CutsceneLine(
        'Kütüphanede defter tutuluyor, şadırvanda su akıyor, yollar taş.',
      ),
      CutsceneLine('Burayı kuranlar bugün gelseydi kapıyı bulamazdı.'),
    ],
  ),
]);

// Kademe 5 — Sancağı Olan Şehir. (MERDİVENİN SONU: asıl kapanış kartı burada.)
//
// Sözleşme: kapanış "kazandın" demez. Bu oyunun no-fail omurgası ödülü değil
// SÜREKLİLİĞİ vaat ediyor; son kart da mirasa bakar, zafere değil.
const Cutscene _kTier5Cutscene = Cutscene([
  CutsceneShot(
    bg: CutsceneBg.valleyDawn,
    zoomFrom: 1.0,
    zoomTo: 1.12,
    actors: [
      CutsceneActor(
        type: VillagerType.farmer,
        seed: 12,
        fromX: 0.22,
        y: 0.84,
        scale: 1.2,
      ),
      CutsceneActor(
        type: VillagerType.priest,
        name: 'Yaşlı',
        seed: 7,
        fromX: 0.42,
        y: 0.82,
        scale: 1.3,
        flip: true,
      ),
      CutsceneActor(
        type: VillagerType.merchant,
        seed: 3,
        fromX: 0.62,
        y: 0.83,
        scale: 1.2,
      ),
      CutsceneActor(
        type: VillagerType.guard,
        seed: 21,
        fromX: 0.80,
        y: 0.84,
        scale: 1.25,
        flip: true,
      ),
    ],
    lines: [
      CutsceneLine(
        'Çan sabah çaldı. Anıtın gölgesi meydanın yarısını örtüyor.',
      ),
      CutsceneLine(
        'Ben ilk kışı hatırlıyorum. Ateşin başında altı kişiydik.',
        speaker: 'Yaşlı',
      ),
      CutsceneLine(
        'Şimdi ateşi yakanı kimse tanımıyor. İyi ki de öyle.',
        speaker: 'Yaşlı',
      ),
    ],
  ),
  CutsceneShot(
    bg: CutsceneBg.titleCard,
    zoomFrom: 1.0,
    zoomTo: 1.06,
    lines: [
      CutsceneLine(
        'Bir sancak dikildi. Altında doğanlar burayı hep böyle bilecek: kurulmuş, '
        'oturmuş, kendinden emin. Onu kuranların kaç kere yanlış karar verdiğini '
        'yalnız defterler bilir.',
      ),
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
      CutsceneActor(
        type: VillagerType.farmer,
        seed: 12,
        fromX: 0.42,
        y: 0.82,
        scale: 1.3,
      ),
      CutsceneActor(
        type: VillagerType.priest,
        name: 'Maple',
        seed: 7,
        fromX: 0.62,
        y: 0.80,
        scale: 1.25,
        flip: true,
      ),
    ],
    lines: [
      CutsceneLine(
        'Tarlalar boş. Yağmur gelmedi; ambarın dibi göründü, kimse yüksek sesle söylemedi.',
      ),
      CutsceneLine(
        'Kış uzun olacak. Kaşığı bölüşenler açlığı da bölüşür.',
        speaker: 'Maple',
      ),
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
          type: brideType,
          name: brideName,
          visual: brideVisual,
          fromX: 0.40,
          y: 0.80,
          scale: 1.4,
        ),
        CutsceneActor(
          type: groomType,
          name: groomName,
          visual: groomVisual,
          fromX: 0.60,
          y: 0.80,
          scale: 1.4,
          flip: true,
        ),
      ],
      lines: [
        const CutsceneLine(
          'Ateşe fazladan odun attılar. Köy halka oldu, ortada iki kişi kaldı.',
        ),
      ],
    ),
    // 2) Yeminler — gelin & damat karşılıklı (yüz yüze, hafif zoom).
    CutsceneShot(
      bg: CutsceneBg.fireNight,
      zoomFrom: 1.0,
      zoomTo: 1.06,
      actors: [
        CutsceneActor(
          type: brideType,
          name: brideName,
          visual: brideVisual,
          fromX: 0.42,
          y: 0.80,
          scale: 1.5,
        ),
        CutsceneActor(
          type: groomType,
          name: groomName,
          visual: groomVisual,
          fromX: 0.62,
          y: 0.80,
          scale: 1.5,
          flip: true,
        ),
      ],
      lines: [
        CutsceneLine(
          'Ben ekmeğimi bölmeye geldim. Yarısı senin.',
          speaker: groomName,
        ),
        CutsceneLine(
          'Bölmene gerek yok. Bundan sonra aynı sofradan yiyoruz.',
          speaker: brideName,
        ),
      ],
    ),
    // 3) Kutlama — köy halaya durur (anlatı, sıcak kapanış).
    CutsceneShot(
      bg: CutsceneBg.fireNight,
      zoomFrom: 1.04,
      zoomTo: 1.0,
      actors: [
        CutsceneActor(
          type: brideType,
          name: brideName,
          visual: brideVisual,
          fromX: 0.46,
          y: 0.82,
          scale: 1.35,
        ),
        CutsceneActor(
          type: groomType,
          name: groomName,
          visual: groomVisual,
          fromX: 0.58,
          y: 0.82,
          scale: 1.35,
          flip: true,
        ),
      ],
      lines: [
        CutsceneLine(
          '$brideName ile $groomName evlendi. Halay gün ağarana kadar sürdü; ertesi gün kimse tarlaya erken çıkmadı.',
        ),
      ],
    ),
  ]);
}
