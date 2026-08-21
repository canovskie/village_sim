import '../systems/hearth_warmth.dart';
import 'building_type.dart';

/// ─── Binanın Künyesi ────────────────────────────────────────────────────────
///
/// İnşa ederken oyuncunun görmesi gereken üçüncü bilgi katmanı. İlk ikisi
/// zaten vardı:
///   1. [kBuildingMeta]      → ne kadara mal olur, kaç tile yer kaplar
///   2. [kBuildingFunctions] → ne işe yarar (summary)
/// Eksik olan üçüncüsü buydu: **NEREYE kurulmalı ve neden**. Oyuncu bir çadırı
/// ocağın dibine mi yoksa tepenin ardına mı koyacağını, oduncunun neden ormanın
/// içinde durması gerektiğini bilmiyordu; oyun bunu ancak "kurulamaz" diye
/// reddederek öğretiyordu — yani yalnızca KURALLARI, hiç AVANTAJLARI değil.
///
/// ALTIN KURAL (bkz. building_function): burada yazan her avantajın simülasyonda
/// bir karşılığı VARDIR. Karşılığı olmayan yer için "menzil aranmaz" denir,
/// süslü bir yalan yazılmaz. Ölçülebilen ipucu yerleştirme sırasında CANLI
/// doğrulanır (bkz. [SiteFacts] / [tipState]) — künyedeki söz ile hayaletin
/// altındaki zemin aynı şeyi söyler.
///
/// Tatlı not ([BuildingLore.notes]): binanın kendi ağzından bir cümle. Sayı
/// değil, koku/ses/alışkanlık. Havuzdur — aynı binayı ikinci kez seçtiğinde
/// başka bir not çıkar (bkz. voice.dart'ın varyant kuralı).

// ─── İpucu türleri ───────────────────────────────────────────────────────────

/// Bir yerleşim ipucunun neye baktığı. Her tür ya ölçülebilir bir dünya
/// gerçeğine ([SiteFacts]) bakar ya da [anywhere] gibi saf bilgidir.
enum SiteTipKind {
  /// Ocağın sıcaklık menzilinde mi (çadır moralinin gerçek kaynağı).
  hearth,

  /// Çevresinde ayakta ağaç var mı (oduncu bölgesi).
  forest,

  /// Footprint bir maden damarının üstünde mi.
  oreVein,

  /// Su kıyısına yakın mı (balıkçının her sefer yürüdüğü mesafe).
  shore,

  /// Menzilinde çiçek var mı (bal hızının çarpanı).
  flowers,

  /// Çevresinde boş/ekilebilir zemin var mı (çiçek serpilmesi, hayvan otlağı).
  openGround,

  /// Yakınında üretim yapan bina var mı (ambarın teslim trafiği).
  workNear,

  /// Yakınında teslim noktası (ambar/ocak) var mı — taşıyıcı yükünü EN YAKIN
  /// ambara götürür, yoksa ocağa.
  storeNear,

  /// Yakınında konut var mı (işine/ocağına yürüyen köylünün yolu).
  homesNear,

  /// Ölçülecek bir şey yok — bu binanın menzili yoktur, bilgi olarak durur.
  anywhere,
}

/// Tek bir yerleşim ipucu. [rule] true ise bu bir KURAL'dır (sağlanmazsa bina
/// dikilemez, bkz. `_placementReason`); false ise AVANTAJ'dır (kurulur ama
/// karşılığı azalır).
class SiteTip {
  final SiteTipKind kind;

  /// Tam metin — masaüstü künyesinde okunur (en fazla iki satır tutmalı).
  final String text;

  /// Telefon şeridinde okunan KISA hâl. Alçak ekranda satır başına ~35 karakter
  /// yer var; uzun metni oraya sıkıştırmak "Menzilde…" gibi yarım cümleler
  /// üretiyordu — ipucu yarım okunacaksa hiç okunmasın, kısası yazılsın.
  final String short;

  final bool rule;
  const SiteTip(this.kind, this.text, {required this.short, this.rule = false});
}

/// Canlı doğrulama sonucu — künyedeki ipucu şu anki hayalet konumunda tutuyor mu.
enum SiteTipState {
  /// Sağlanıyor (avantaj kazanılıyor / kural karşılanıyor).
  met,

  /// Sağlanmıyor (avantaj kaçıyor / kural ihlal — o zaman zaten kurulamaz).
  unmet,

  /// Ölçülemez ya da ölçülecek bir şey yok (bilgi satırı).
  neutral,
}

/// Bir binanın künyesi: nereye kurulacağı + tatlı notları.
class BuildingLore {
  /// Yerleşim ipuçları — önce kurallar, sonra avantajlar.
  final List<SiteTip> tips;

  /// Tatlı not havuzu. Tek string YAZILMAZ (voice.dart kuralı): aynı binaya
  /// ikinci kez bakan oyuncu başka bir cümle görsün.
  final List<String> notes;

  const BuildingLore({required this.tips, required this.notes});
}

// ─── Ölçüm eşikleri ──────────────────────────────────────────────────────────
// Künyedeki "yakın" sözcüğünün sayısal karşılığı. İpucu metni ile canlı kontrol
// aynı eşiği okur — biri değişirse ikisi birden değişir.

/// Balıkçı kulübesinin "kıyıda" sayıldığı mesafe (tile). Balıkçı her seferinde
/// kendi konumundan en yakın kıyıya yürür (bkz. `_runFisher`); kulübe sudan
/// uzaklaştıkça bu yürüyüş uzar.
const double kShoreNearTiles = 4.0;

/// Taşıyıcının teslim yolu için "yakın üretim" mesafesi (tile). Taşıyıcı kutuyu
/// EN YAKIN ambar slot'una götürür (bkz. anchor_system.claimDeliverySlot).
const double kWorkNearTiles = 12.0;

/// İşine/ocağına yürüyen köylü için "yakın konut" mesafesi (tile).
const double kHomesNearTiles = 8.0;

/// Çevresi "açık" sayılması için gereken boş tile sayısı (çiçek/otlak alanı).
const int kOpenGroundMinTiles = 6;

// ─── Dünyadan ölçülen gerçekler ──────────────────────────────────────────────

/// Hayaletin durduğu yerin ölçülmüş hâli. Sahne doldurur (bkz.
/// `_siteFactsAt`), bu dosya yalnız yorumlar → saf + testlenebilir.
class SiteFacts {
  /// Bu noktanın ocaktan aldığı sıcaklık (0..1). TEK KAYNAK: hearth_warmth —
  /// çadırın kış morali ve gece titremesi de aynı sayıyı okur. Ocak yoksa ya da
  /// sönükse 0.
  final double hearthWarmth;

  /// Köyde kurulu bir ocak var mı (0 sıcaklığın sebebi "ocak yok" mu, "uzak" mı).
  final bool hasHearth;

  /// Ocak şu an yanıyor mu (sönük ocak ısıtmaz).
  final bool hearthLit;

  /// Oduncu bölgesi yarıçapında ayakta ağaç sayısı.
  final int treesNear;

  /// Footprint bir maden damarına oturuyor mu.
  final bool onVein;

  /// En yakın su tile'ına mesafe (tile); null = haritada su yok.
  final double? shoreDist;

  /// Kovanın menzilindeki çiçek sayısı.
  final int flowersNear;

  /// Etki menzilindeki boş (bina/su/ağaç/tarla olmayan) tile sayısı.
  final int openTilesNear;

  /// [kWorkNearTiles] içindeki üretim/işleme binası sayısı.
  final int workNear;

  /// [kWorkNearTiles] içindeki teslim noktası (ambar / ocak) sayısı.
  final int storesNear;

  /// [kHomesNearTiles] içindeki konut sayısı.
  final int homesNear;

  const SiteFacts({
    this.hearthWarmth = 0.0,
    this.hasHearth = false,
    this.hearthLit = false,
    this.treesNear = 0,
    this.onVein = false,
    this.shoreDist,
    this.flowersNear = 0,
    this.openTilesNear = 0,
    this.workNear = 0,
    this.storesNear = 0,
    this.homesNear = 0,
  });
}

/// İpucu şu anki konumda tutuyor mu.
SiteTipState tipState(SiteTip tip, SiteFacts f) {
  switch (tip.kind) {
    case SiteTipKind.hearth:
      return f.hearthWarmth >= kColdShelterThreshold
          ? SiteTipState.met
          : SiteTipState.unmet;
    case SiteTipKind.forest:
      return f.treesNear > 0 ? SiteTipState.met : SiteTipState.unmet;
    case SiteTipKind.oreVein:
      return f.onVein ? SiteTipState.met : SiteTipState.unmet;
    case SiteTipKind.shore:
      final d = f.shoreDist;
      if (d == null) return SiteTipState.unmet;
      return d <= kShoreNearTiles ? SiteTipState.met : SiteTipState.unmet;
    case SiteTipKind.flowers:
      return f.flowersNear > 0 ? SiteTipState.met : SiteTipState.unmet;
    case SiteTipKind.openGround:
      return f.openTilesNear >= kOpenGroundMinTiles
          ? SiteTipState.met
          : SiteTipState.unmet;
    case SiteTipKind.workNear:
      return f.workNear > 0 ? SiteTipState.met : SiteTipState.unmet;
    case SiteTipKind.storeNear:
      return f.storesNear > 0 ? SiteTipState.met : SiteTipState.unmet;
    case SiteTipKind.homesNear:
      return f.homesNear > 0 ? SiteTipState.met : SiteTipState.unmet;
    case SiteTipKind.anywhere:
      return SiteTipState.neutral;
  }
}

/// İpucunun ölçülen değeri — künyede sağdaki küçük rozet ("3 ağaç", "×1.7").
/// null = gösterilecek sayı yok.
String? tipValue(SiteTip tip, SiteFacts f) {
  switch (tip.kind) {
    case SiteTipKind.hearth:
      if (!f.hasHearth) return 'ocak yok';
      if (!f.hearthLit) return 'ocak sönük';
      if (f.hearthWarmth >= 1.0) return 'sıcak';
      if (f.hearthWarmth >= kColdShelterThreshold) return 'ısınır';
      return f.hearthWarmth <= 0 ? 'ocaktan uzak' : 'sınırda soğuk';
    case SiteTipKind.forest:
      return '${f.treesNear} ağaç';
    case SiteTipKind.oreVein:
      return f.onVein ? 'damar üstünde' : 'damar yok';
    case SiteTipKind.shore:
      final d = f.shoreDist;
      if (d == null) return 'su yok';
      return '${d.round()} tile';
    case SiteTipKind.flowers:
      final speed = honeySpeedFromFlowers(f.flowersNear);
      return '${f.flowersNear} çiçek · ×${speed.toStringAsFixed(1)}';
    case SiteTipKind.openGround:
      return '${f.openTilesNear} boş tile';
    case SiteTipKind.workNear:
      return f.workNear > 0 ? '${f.workNear} işlik' : 'uzak';
    case SiteTipKind.storeNear:
      return f.storesNear > 0 ? '${f.storesNear} teslim yeri' : 'uzak';
    case SiteTipKind.homesNear:
      return f.homesNear > 0 ? '${f.homesNear} ev' : 'uzak';
    case SiteTipKind.anywhere:
      return null;
  }
}

/// Menzildeki çiçek sayısının bal üretimine çarpanı. TEK KAYNAK: hem kovanı
/// çeviren tick (scene_tick) hem künyedeki "×2.1" rozeti bunu okur.
double honeySpeedFromFlowers(int flowers) {
  final s = 1.0 + flowers * kHoneyFlowerSpeedStep;
  return s > kHoneySpeedMax ? kHoneySpeedMax : s;
}

/// Her çiçeğin bal hızına katkısı.
const double kHoneyFlowerSpeedStep = 0.22;

/// Bal hızının tavanı — çiçek denizi bile kovanı üçe katlamaktan öteye gitmez.
const double kHoneySpeedMax = 3.0;

// ─── Künye tablosu ───────────────────────────────────────────────────────────

/// Bütün binalar için "nereye + tatlı not". Tabloda olmayan bina künye
/// göstermez (bkz. [loreOf]).
///
/// METİN ÖLÇÜSÜ: [SiteTip.text] en fazla iki satır (~120 karakter), [short] tek
/// satır (~32 karakter). Uzun yazılan ipucu kartta "…" ile kesilir — kesilen
/// ipucu öğretmez.
const Map<BuildingType, BuildingLore> kBuildingLore = {
  // ── Civic / ocak ──────────────────────────────────────────────────────────
  BuildingType.firepit: BuildingLore(
    tips: [
      // İlk bina genelde budur; köyde ölçülecek başka bir şey yokken "uzak"
      // yazan bir ipucu yeni oyuncuyu boşuna telaşlandırırdı. Konum tavsiyesi
      // bilgi olarak durur, ölçülen tek şey çevresindeki boşluktur.
      SiteTip(
        SiteTipKind.anywhere,
        'Köyün ORTASINA kur: evler ve çadırlar bunun etrafına dizilir. '
        'Ateşi kenara koyarsan mahalleyi de kenara kurmuş olursun.',
        short: 'Köyün ortasına kur',
      ),
      SiteTip(
        SiteTipKind.openGround,
        'Çevresi açık olsun — akşam ateş başına oturulur, yer kalmazsa '
        'sohbet de kurulmaz.',
        short: 'Çevresi açık olsun',
      ),
    ],
    notes: [
      'İlk kıvılcımı kim çaktıysa adı unutulur, ateşi unutulmaz.',
      'Kışın herkes bir adım daha yaklaşır; yaz gelince kimse fark etmez.',
      'Küller sabaha kadar sıcak kalır — köpekler bunu insanlardan önce öğrendi.',
    ],
  ),

  // ── Konut ────────────────────────────────────────────────────────────────
  BuildingType.tent: BuildingLore(
    tips: [
      SiteTip(
        SiteTipKind.hearth,
        'OCAĞIN YANINA KUR. Çadırın kendi ocağı yoktur: uzağa kurulan çadır '
        'kış boyu moral kaybeder, içindeki gece titreyerek uyanır.',
        short: 'Ocağın yanına kur',
      ),
      SiteTip(
        SiteTipKind.homesNear,
        'Diğer damların yanına sokul — dağılan çadır köyü değil kampı andırır.',
        short: 'Damların yanına sokul',
      ),
    ],
    notes: [
      'Rüzgâr bezi gece boyu döver; içerideki alışır, misafir alışamaz.',
      'İçinde uyuyan herkes aynı şeyi söyler: "Bir dam yapana kadar."',
      'Direği bir kez düzgün çakan, ertesi sabah gururla anlatır.',
    ],
  ),

  BuildingType.woodenHouse: BuildingLore(
    tips: [
      SiteTip(
        SiteTipKind.homesNear,
        'Evler birbirini görsün: yakında başka hane varsa akşam kapılar çalınır.',
        short: 'Diğer hanelerin yanına',
      ),
      SiteTip(
        SiteTipKind.anywhere,
        'Duvarı ve kendi ocağı var — çadırın aksine ateşe yakınlık aramaz, '
        'kışı her yerde atlatır.',
        short: 'Ateşe yakınlık aramaz',
      ),
    ],
    notes: [
      'Bacadan ilk duman çıktığı akşam, bütün köy o damın önünden geçer.',
      'Kapı eşiği bir yılda aşınır; onu aşındıran ayaklar hanenin kendisidir.',
      'İki yatak, bir ocak, bir de kapıya asılmış kurumuş çiçek.',
    ],
  ),

  BuildingType.stoneHouseBlue: BuildingLore(
    tips: [
      SiteTip(
        SiteTipKind.homesNear,
        'Mahallenin içinde dursun — taş konut çevresindeki hanelere de itibar katar.',
        short: 'Mahallenin içinde',
      ),
    ],
    notes: [
      'Duvarı kalın: kışın soğuğu, yazın gürültüyü dışarıda bırakır.',
      'Mavi çatı yağmurda koyulaşır; köyün en uzaktan tanınan damıdır.',
      'Taşları taşıyanın adını, içinde oturan bilmez.',
    ],
  ),

  BuildingType.stoneHouseGreen: BuildingLore(
    tips: [
      SiteTip(
        SiteTipKind.homesNear,
        'Mahallenin içinde dursun — taş konut çevresindeki hanelere de itibar katar.',
        short: 'Mahallenin içinde',
      ),
    ],
    notes: [
      'Yeşil çatı yaz ortasında ağaçlara karışır, kışın tek başına kalır.',
      'Aynı ustanın elinden çıktı; yalnız kiremidin rengi tartışıldı.',
      'İçeride üç kişi rahat eder, dördüncüsü de bir yolunu bulur.',
    ],
  ),

  BuildingType.manor: BuildingLore(
    tips: [
      SiteTip(
        SiteTipKind.homesNear,
        'Köye sırtını dönmesin: konak, görülmek için dikilir.',
        short: 'Köyün göreceği yerde',
      ),
      SiteTip(
        SiteTipKind.openGround,
        'Önünde boşluk bırak — kapısına varan yol darsa görkemi kaybolur.',
        short: 'Önünde boşluk bırak',
      ),
    ],
    notes: [
      'Kapısı ağır açılır; bu, kapının değil kapıyı yaptıranın tercihidir.',
      'Merdiveninde kimin oturabileceği köyde ayrı bir mesele olmuştur.',
      'Camlarında akşam güneşi köyün geri kalanından uzun kalır.',
    ],
  ),

  // ── Üretim ───────────────────────────────────────────────────────────────
  BuildingType.lumberCamp: BuildingLore(
    tips: [
      SiteTip(
        SiteTipKind.forest,
        'ORMANIN İÇİNE KUR — çevresindeki ağaçları keser, yerine fidan diker. '
        'Menzilinde ağaç yoksa hiç kurulamaz.',
        short: 'Ormanın içine kur',
        rule: true,
      ),
      SiteTip(
        SiteTipKind.storeNear,
        'Ambara yakın dursun: taşıyıcı kütüğü EN YAKIN ambara götürür.',
        short: 'Ambara yakın dursun',
      ),
    ],
    notes: [
      'Balta sesi köyün saatidir: durunca herkes başını kaldırır.',
      'Oduncu kestiği her ağacın yerine bir fidan diker — ormanı o besler.',
      'Kapının yanındaki kütük hem tabure hem kesme masasıdır.',
    ],
  ),

  BuildingType.mineBuilding: BuildingLore(
    tips: [
      SiteTip(
        SiteTipKind.oreVein,
        'DAMARIN ÜSTÜNE kurulur — footprint bir maden damarına oturmadan '
        'ocak açılmaz.',
        short: 'Damarın üstüne kur',
        rule: true,
      ),
      SiteTip(
        SiteTipKind.storeNear,
        'Ambar yakınsa taş, demir ve kömür kısa yoldan içeri girer.',
        short: 'Ambara yakın olsun',
      ),
    ],
    notes: [
      'İçeride kimse yüksek sesle konuşmaz; taş kendi sesini geri verir.',
      'Kömür kışın altından değerlidir — bunu ocağı sönen köy öğrenir.',
      'Girişteki fener sabaha kadar yanar, kimse söndürmeye kıyamaz.',
    ],
  ),

  BuildingType.fisherCabin: BuildingLore(
    tips: [
      SiteTip(
        SiteTipKind.shore,
        'SUYUN KIYISINA kur. Balıkçı her seferinde en yakın kıyıya yürür; '
        'sudan uzak kulübede sepet geç dolar.',
        short: 'Suyun kıyısına kur',
      ),
      SiteTip(
        SiteTipKind.storeNear,
        'Ambar yakınsa balık bozulmadan içeri girer.',
        short: 'Ambara yakın olsun',
      ),
    ],
    notes: [
      'Ağ her akşam kapının yanına asılır; sabah çiy tutmuş olur.',
      'Balıkçı suyun rengine bakıp havayı söyler, çoğu zaman da tutturur.',
      'Kulübenin içi hep biraz rutubetlidir — kimse şikâyet etmez.',
    ],
  ),

  BuildingType.mill: BuildingLore(
    tips: [
      SiteTip(
        SiteTipKind.anywhere,
        'Değirmenin menzili yoktur: balya nereden gelirse gelsin aynı un olur. '
        'Yeri estetik bir tercihtir.',
        short: 'Menzili yok — yeri sana kalmış',
      ),
      SiteTip(
        SiteTipKind.homesNear,
        'Değirmenci her sabah evinden buraya yürür; köye yakın değirmen boş '
        'kalmaz.',
        short: 'Köye yakın dursun',
      ),
    ],
    notes: [
      'Kanatlar dönerken içerisi un kokar; duran değirmen ise sadece tozludur.',
      'Değirmencinin omzundaki beyaz iz yıkanmakla çıkmaz.',
      'Rüzgâr kesildiğinde köyün en sabırsız adamı odur.',
    ],
  ),

  BuildingType.barn: BuildingLore(
    tips: [
      SiteTip(
        SiteTipKind.openGround,
        'ÇEVRESİ AÇIK OLSUN — sürü ağılın etrafında otlar, sıkışık yerde '
        'döner durur.',
        short: 'Çevresi açık olsun',
      ),
      SiteTip(
        SiteTipKind.homesNear,
        'Çoban sabah sağıma yürür; köye yakın ağıl erken sağılır.',
        short: 'Köye yakın dursun',
      ),
    ],
    notes: [
      'Saman kokusu duvara siner, yağmurda daha da belli eder kendini.',
      'İnekler akşam kendiliğinden döner — kapıyı açık bırakmak yeter.',
      'Ağılın kedisi vardır; kimse getirmemiştir, hep oradaydı.',
    ],
  ),

  BuildingType.chickenCoop: BuildingLore(
    tips: [
      SiteTip(
        SiteTipKind.openGround,
        'Tavuklar kümesin çevresinde eşinir — biraz açık avlu bırak.',
        short: 'Açık avlu bırak',
      ),
      SiteTip(
        SiteTipKind.homesNear,
        'Evlerin arasında dursun: yumurtayı toplayan çocuk uzağa gitmesin.',
        short: 'Evlerin arasında',
      ),
    ],
    notes: [
      'Horoz sabahı köyden önce ilan eder, kimse teşekkür etmez.',
      'Yumurta bulmak çocukların işidir; sayısını hep fazla söylerler.',
      'Kümesin kapısı bir kez unutulur, o hikâye yıllarca anlatılır.',
    ],
  ),

  BuildingType.beehive: BuildingLore(
    tips: [
      SiteTip(
        SiteTipKind.flowers,
        'ÇİÇEĞİN ARASINA KOY. Menzildeki her çiçek balı hızlandırır; '
        'çiçekçinin yanındaki kovan iki-üç katı çalışır.',
        short: 'Çiçeğin arasına koy',
      ),
    ],
    notes: [
      'Vızıltı yazın köyün arka sesidir; kışın sustuğunda kulak onu arar.',
      'Bal kavanozu ambarda değil, misafir gelince ortaya çıkar.',
      'Arıcı sokulmadığını söyler; kimse tam olarak inanmaz.',
    ],
  ),

  BuildingType.floristCottage: BuildingLore(
    tips: [
      SiteTip(
        SiteTipKind.openGround,
        'BOŞ ÇİMİN ORTASINA KUR — çevresine çiçek serpilir; taş ve bina dolu '
        'yerde serpilecek yer kalmaz.',
        short: 'Boş çimin ortasına',
      ),
      SiteTip(
        SiteTipKind.homesNear,
        'Evlerin göreceği yerde dursun: güzel köy morali ayakta tutar.',
        short: 'Evlerin göreceği yerde',
      ),
    ],
    notes: [
      'Çiçekçi sabah ilk, akşam son çıkan kişidir; kimse nedenini sormaz.',
      'Su kovası hep yarım taşınır — dolusu ağır, boşu anlamsız.',
      'Kapıya asılan kuru demet geçen yazdan kalmadır.',
    ],
  ),

  BuildingType.tailor: BuildingLore(
    tips: [
      SiteTip(
        SiteTipKind.homesNear,
        'Mahallenin içinde olsun: köylü ölçü verip geri dönebilmeli.',
        short: 'Mahallenin içinde',
      ),
      SiteTip(
        SiteTipKind.anywhere,
        'Terzinin menzili yoktur — atölye bitince köyün giysileri nerede '
        'olursa olsun dikilir.',
        short: 'Menzili yok',
      ),
    ],
    notes: [
      'İğne deliğine iplik geçirmek, terzinin günde kırk kez yendiği savaştır.',
      'Kumaş artıkları çocukların bez bebeği olur.',
      'İlk dikilen giysi hep en yaşlıya gider; bu yazılı bir kural değildir.',
    ],
  ),

  // ── Ticaret / lojistik ───────────────────────────────────────────────────
  BuildingType.warehouse: BuildingLore(
    tips: [
      SiteTip(
        SiteTipKind.workNear,
        'ÜRETİMİN ORTASINA KUR. Taşıyıcı yükünü EN YAKIN ambara götürür — '
        'işliklerin ortasındaki ambar köyün yolunu kısaltır.',
        short: 'Üretimin ortasına kur',
      ),
      SiteTip(
        SiteTipKind.homesNear,
        'Ocağa ve evlere yakın ambar, yakacak taşıyanı da yormaz.',
        short: 'Ocağa/eve yakın olsun',
      ),
    ],
    notes: [
      'İçerisi serin ve karanlıktır; yazın en çok orada oyalanan olur.',
      'Ambarcı her şeyin yerini bilir, kimseye de söylemez.',
      'Dolu ambarın kapısı ağır kapanır — köy bu sesi sever.',
    ],
  ),

  BuildingType.market: BuildingLore(
    tips: [
      SiteTip(
        SiteTipKind.homesNear,
        'Meydana, evlerin arasına kur — pazarın kalabalığı köyden gelir.',
        short: 'Meydana kur',
      ),
      SiteTip(
        SiteTipKind.anywhere,
        'Gelirin menzili yoktur: tezgâh köyün ambar FAZLASINDAN döner, '
        'yakınındaki tezgahtan değil.',
        short: 'Gelir fazladan gelir',
      ),
    ],
    notes: [
      'Terazi hep bir parça eğridir; hangi yöne olduğu tartışılır.',
      'Pazar günü çocuklar sabah erken kalkar, sebebi alışveriş değildir.',
      'Bağıra bağıra satan, sessiz duran tezgahtan iyi kazanır.',
    ],
  ),

  BuildingType.stable: BuildingLore(
    tips: [
      SiteTip(
        SiteTipKind.anywhere,
        'Ahırın etkisi KÖY ÇAPINDADIR: bütün taşıyıcılar hızlanır, mesafeye '
        'bakılmaz.',
        short: 'Etkisi köy çapında',
      ),
      SiteTip(
        SiteTipKind.openGround,
        'Yine de önünde dönecek yer bırak — yük hayvanı dar avluda huysuzlanır.',
        short: 'Önünde yer bırak',
      ),
    ],
    notes: [
      'Saman ve at kokusu; köyün en sıcak duvarı burasıdır.',
      'Yük hayvanı kendi ahırını insandan iyi bulur.',
      'Nal sesi köye kimin geldiğini kapıdan önce söyler.',
    ],
  ),

  BuildingType.caravanserai: BuildingLore(
    tips: [
      SiteTip(
        SiteTipKind.anywhere,
        'Hanın taşıyıcı katkısı KÖY ÇAPINDADIR — menzil aranmaz.',
        short: 'Etkisi köy çapında',
      ),
      SiteTip(
        SiteTipKind.openGround,
        'Avlusu geniş dursun: kervan sığmazsa han han olmaz.',
        short: 'Avlusu geniş dursun',
      ),
    ],
    notes: [
      'Avlu geceyi yabancı dillerle geçirir; sabah hepsi yola çıkar.',
      'Hancı her misafirin adını sorar, hiçbirini yazmaz.',
      'Kapısının üstündeki fener hiç söndürülmez — bu bir davettir.',
    ],
  ),

  // ── Civic ────────────────────────────────────────────────────────────────
  BuildingType.well: BuildingLore(
    tips: [
      SiteTip(
        SiteTipKind.anywhere,
        'Kuyunun menzili yoktur: bir kuyu köyün BÜTÜN evlerinin küpünü '
        'doldurur. İkincisi daha hızlı doldurur, daha uzağa değil.',
        short: 'Menzili yok — hepsine yeter',
      ),
      SiteTip(
        SiteTipKind.homesNear,
        'Yine de evlerin ortasında dursun — kova taşıyanın yolu kısalsın.',
        short: 'Evlerin ortasında',
      ),
    ],
    notes: [
      'Kuyu başı köyün ilk dedikodu meydanıdır; ikincisi tavernadır.',
      'Kovanın ipi her yıl bir kez kopar, hep aynı yerinden.',
      'Suyun serinliği yazın herkesi bir bahaneyle oraya çeker.',
    ],
  ),

  BuildingType.fountain: BuildingLore(
    tips: [
      SiteTip(
        SiteTipKind.homesNear,
        'MEYDANA kur — şadırvanın işi gündüz toplanmaktır; evlerden uzakta '
        'kimse başına gelmez.',
        short: 'Meydana kur',
      ),
      SiteTip(
        SiteTipKind.openGround,
        'Çevresi açık olsun: dört yanı duvarla çevrili çeşme sadece bir taştır.',
        short: 'Çevresi açık olsun',
      ),
    ],
    notes: [
      'Suyun şıpırtısı meydanın gündüz sesidir.',
      'Sıcakta ilk buluşma yeri; kimse sözleşmez, herkes gelir.',
      'Mermerine oturmak yasaktır, herkes oturur.',
    ],
  ),

  BuildingType.tavern: BuildingLore(
    tips: [
      SiteTip(
        SiteTipKind.anywhere,
        'Tavernanın morali KÖY ÇAPINDADIR — uzakta kurulsa da kadeh aynı '
        'kaldırılır.',
        short: 'Morali köy çapında',
      ),
      SiteTip(
        SiteTipKind.homesNear,
        'Yine de evlerin arasında iyi durur: akşam işten çıkan buradan geçsin.',
        short: 'Evlerin arasında',
      ),
    ],
    notes: [
      'Kahkaha, dedikodu, bir kadeh; köyün morali en çok buradan beslenir.',
      'En iyi masa ocağın yanındaki değil, kapıyı gören masadır.',
      'Hancı kimin ne kadar borcu olduğunu ezbere bilir.',
    ],
  ),

  BuildingType.church: BuildingLore(
    tips: [
      SiteTip(
        SiteTipKind.openGround,
        'YANINA YER BIRAK — kilisenin yanında mezarlık sessizce büyür.',
        short: 'Yanına yer bırak',
      ),
      SiteTip(
        SiteTipKind.homesNear,
        'Köyün görebileceği yerde dursun: çan da uğurlama da oradan duyulur.',
        short: 'Köyün göreceği yerde',
      ),
    ],
    notes: [
      'Serin taş, mum kokusu, alçak sesler.',
      'Kapısı hiç kilitlenmez; kilidi olmadığı için.',
      'İçeride en çok konuşan, dışarıda en az konuşandır.',
    ],
  ),

  BuildingType.library: BuildingLore(
    tips: [
      SiteTip(
        SiteTipKind.anywhere,
        'Kütüphanenin katkısı KÖY ÇAPINDADIR: yazıya geçen zanaat usta göçse '
        'de kaybolmaz.',
        short: 'Katkısı köy çapında',
      ),
      SiteTip(
        SiteTipKind.homesNear,
        'Meydana yakın olsun — uğraması kolay olan raf okunur.',
        short: 'Meydana yakın olsun',
      ),
    ],
    notes: [
      'Rafta ne varsa okuyan bulunur; okumayan da geldiğini söyler.',
      'Vakanüvisin kalemi köyün belleğinden hızlı işler.',
      'Kâğıt kokusu rutubete karışır, kimse camı açmaya kıyamaz.',
    ],
  ),

  BuildingType.bathhouse: BuildingLore(
    tips: [
      SiteTip(
        SiteTipKind.anywhere,
        'Hamamın morali KÖY ÇAPINDADIR — nereye kurulursa kurulsun köy '
        'temizlenir.',
        short: 'Morali köy çapında',
      ),
      SiteTip(
        SiteTipKind.homesNear,
        'Evlere yakınsa kimse "üşenirim" diyemez.',
        short: 'Evlere yakın olsun',
      ),
    ],
    notes: [
      'Buhar, mermer, uzun sohbetler.',
      'İçeride herkesin sesi aynı çıkar; rütbe kapıda kalır.',
      'Külhanı besleyen odun, köyün en az konuşulan emeğidir.',
    ],
  ),

  BuildingType.monument: BuildingLore(
    tips: [
      SiteTip(
        SiteTipKind.openGround,
        'AÇIK BİR YERE DİK — iki damın arasına sıkışan taş anıt olmaz.',
        short: 'Açık bir yere dik',
      ),
      SiteTip(
        SiteTipKind.homesNear,
        'Yolu köyden geçsin: bakılmayan anıt yalnızca ağır bir taştır.',
        short: 'Yolu köyden geçsin',
      ),
    ],
    notes: [
      'Taşa kazınmış bir hatıra; hatırlayanlar gidince taş kalır.',
      'Dibine her bahar birileri çiçek bırakır, kimse görülmez.',
      'Gölgesi öğlen en kısa, akşam köyün yarısına uzanır.',
    ],
  ),

  BuildingType.shrine: BuildingLore(
    tips: [
      SiteTip(
        SiteTipKind.anywhere,
        'Türbenin tesellisi KÖY ÇAPINDADIR — uzağa kurulsa da derdi olan '
        'yolunu bulur.',
        short: 'Tesellisi köy çapında',
      ),
      SiteTip(
        SiteTipKind.openGround,
        'Etrafı sakin olsun; gürültünün ortasındaki ziyaretgâha kimse oturmaz.',
        short: 'Etrafı sakin olsun',
      ),
    ],
    notes: [
      'Bez bağlanmış bir dal; her bezin ardında bir dilek var.',
      'Kimse yüksek sesle konuşmaz, kimse de sebebini sormaz.',
      'Uğrayan biraz hafiflemiş çıkar — nedeni tartışılmaz.',
    ],
  ),

  BuildingType.belltower: BuildingLore(
    tips: [
      SiteTip(
        SiteTipKind.homesNear,
        'Köyün ortasına dik — duyulmayan çan susmuş sayılır.',
        short: 'Köyün ortasına dik',
      ),
      SiteTip(
        SiteTipKind.openGround,
        'Yüksek ve açık dursun: dört yanı bina olan kule yalnızca merdivendir.',
        short: 'Açık bir yere dik',
      ),
    ],
    notes: [
      'Çan vakti söyler: iş başını, töreni, tehlikeyi.',
      'İpini çekmek çocuklara yasaktır; en az biri denemiştir.',
      'Rüzgârlı gecede kendi kendine bir kez çalar, herkes duymazdan gelir.',
    ],
  ),

  BuildingType.townhall: BuildingLore(
    tips: [
      SiteTip(
        SiteTipKind.homesNear,
        'MEYDANA kur — divanın toplandığı kapı köyün ortasında durmalı.',
        short: 'Meydana kur',
      ),
      SiteTip(
        SiteTipKind.anywhere,
        'Yönetişimin menzili yoktur: mühür nerede dursun bütün köyü bağlar.',
        short: 'Menzili yok',
      ),
    ],
    notes: [
      'Mühür burada durur, defter burada tutulur.',
      'Masanın en iyi yeri kapıya bakan yerdir; oraya oturan çabuk değişir.',
      'Deftere geçen hüner bir daha kaybolmaz — köyün hafızası kâğıttır.',
    ],
  ),

  BuildingType.lamppost: BuildingLore(
    tips: [
      SiteTip(
        SiteTipKind.homesNear,
        'Yol kenarına, evlerin arasına diz — feneri olan sokakta gece yürünür.',
        short: 'Yol kenarına diz',
      ),
    ],
    notes: [
      'Akşam olunca kendiliğinden yanar; kimse kibrit taşımaz.',
      'Dibinde her yaz aynı pervaneler döner.',
      'Yol kenarına dizilenler köyü gece bir kolye gibi gösterir.',
    ],
  ),
};

/// Bir binanın künyesi — tanımsızsa null (künye satırı gösterilmez).
BuildingLore? loreOf(BuildingType type) => kBuildingLore[type];

/// Tatlı not seçimi — [seed] her yeni seçimde artan bir sayaçtır, böylece aynı
/// binaya ikinci kez bakan başka bir cümle görür (tek string yazma kuralı).
/// Not havuzu boşsa null.
String? sweetNote(BuildingType type, int seed) {
  final notes = kBuildingLore[type]?.notes;
  if (notes == null || notes.isEmpty) return null;
  return notes[seed.abs() % notes.length];
}
