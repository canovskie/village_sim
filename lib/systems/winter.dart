/// ─── KIŞ ─────────────────────────────────────────────────────────────────────
///
/// Kışın MATEMATİĞİ. Saf ve yan etkisiz: kimin üşüdüğünü, köyün hazır olup
/// olmadığını, ihmalin ne zaman ölümcül hâle geldiğini burada hesaplarız;
/// kimin ne yapacağı sahnenin işi.
///
/// Neden ayrı bir dosya: kışın bedeli beş ayrı yere dağılmıştı (moral, üşüme
/// dürtüsü, ocak yakıtı, hastalık, zümre morali) ve hiçbiri diğerini bilmiyordu.
/// Oyuncu "kışa hazır mıyım" sorusunu soramıyordu çünkü cevabı tek bir yerde
/// duran bir sayı yoktu. Bu dosya o sayıyı üretir.
///
/// Tasarım kuralı — KIŞ CEZALANDIRMAZ, HAZIRLIĞI ÖDÜLLENDİRİR:
/// hazırlıklı köyde kış sakin ve güzeldir (ateş başı, dokuma, uzun akşamlar);
/// hazırlıksız köyde ağırdır. Ölüm yalnız İHMALİN ÜST ÜSTE binmesiyle gelir
/// (bkz. [coldNeglect]) — tek bir kötü gün kimseyi öldürmez.
library;

import '../world/season.dart';

// ── Hazırlık ────────────────────────────────────────────────────────────────
//
// Köyün kışa girerken elinde olması gereken şey dört kalemdir. Hepsi GÜN
// BAŞINA ihtiyaçtan türetilir; sabit bir sayı ("100 odun") köy büyüdükçe
// yalan söylerdi.

/// Bir kışın kaç gün sürdüğü (bkz. [kDaysPerSeason]).
int get kWinterDays => kDaysPerSeason;

/// Ocak + ev ocakları için ağız başına GÜNLÜK yakacak (odun eşdeğeri).
///
/// Kömür odundan uzun yanar: bir kömür [kCoalFuelValue] odun sayılır. Köy
/// kömür yakarak aynı kışı daha az yükle çıkarabilir — madenin kışlık anlamı
/// budur.
const double kFuelPerMouthPerDay = 1.15;
const double kCoalFuelValue = 2.4;

/// Ağız başına günlük yiyecek — kışın tarla durduğu için tamamı ambardan gider.
const double kFoodPerMouthPerDay = 1.05;

/// Hayvan başına günlük yem (saman/saz eşdeğeri). Ahırdaki hayvan kışın
/// otlayamaz; yemi sonbahardan biriktirilmiş olmalı.
const double kFodderPerAnimalPerDay = 0.55;

/// Kışlık giysinin hedefi: köyün HERKESİ. Eksik kalırsa öncelik kararı devreye
/// girer (bkz. CoatPriority) — bu yüzden "yeterli" değil "kaç kişilik" ölçülür.
const double kCoatPerPerson = 1.0;

/// Tek bir kalemin hazırlık payı — 0..1 arası, 1 = bu kalem kışı çıkarır.
class WinterItem {
  const WinterItem(this.label, this.have, this.need);

  final String label;

  /// Elde olan (yakacakta odun eşdeğeri, giyside kişi sayısı).
  final double have;

  /// Kışı çıkarmak için gereken.
  final double need;

  /// 0..1. Gerek sıfırsa (hayvan yoksa yem gerekmez) kalem hazır sayılır.
  double get ratio => need <= 0 ? 1.0 : (have / need).clamp(0.0, 1.0);

  /// Kaç birim eksik — oyuncuya "ne kadar daha" demek için.
  double get missing => (need - have).clamp(0.0, double.infinity);

  bool get ready => ratio >= 0.999;
}

/// Köyün kışa hazırlık tablosu.
class WinterReadiness {
  const WinterReadiness({
    required this.fuel,
    required this.food,
    required this.fodder,
    required this.coats,
    required this.days,
  });

  final WinterItem fuel;
  final WinterItem food;
  final WinterItem fodder;
  final WinterItem coats;

  /// Tablonun kaç günlük kışa göre kurulduğu — [daysLeftOf] bunu böler.
  final int days;

  List<WinterItem> get items => [fuel, food, fodder, coats];

  /// GEÇİM kalemleri — bunlar biterse köy kışı çıkaramaz.
  List<WinterItem> get survival => [fuel, food, fodder];

  /// Kışlık giysi RAHATLIK kalemidir, geçim değil.
  ///
  /// Bu ayrım bir hatadan doğdu: giysi de "en zayıf halka"ya dahilken ambarı
  /// tıka basa dolu bir köy %0 hazır görünüyordu — üstelik kışın ortasında yün
  /// üretilemediği (kırkım sonbaharda) için oyuncunun yapabileceği bir şey de
  /// yoktu. Çıkmaz bir sinyal, uyarı değil sitemdir.
  ///
  /// Artık giysi göstergeyi 0.70'in altına indiremez: giysisiz köy kışı
  /// çıkarır ama titreyerek çıkarır.
  double get coatFactor => 0.70 + 0.30 * coats.ratio;

  /// Genel hazırlık 0..1 — geçimde EN ZAYIF HALKA, ortalama DEĞİL.
  ///
  /// Ortalama alsaydık ambarı odunla dolu ama yiyeceği bitmiş bir köy "%75
  /// hazır" görünürdü; oysa o köy kışın aç kalır. Kış zincirin en zayıf
  /// halkasından kırılır, bu yüzden gösterge de oradan okunur.
  double get overall {
    var m = 1.0;
    for (final i in survival) {
      if (i.ratio < m) m = i.ratio;
    }
    return m * coatFactor;
  }

  /// Hazır sayılan eşik — %90. Giysi tam değilse bu eşik geçilemez; kart
  /// "hazır" demeden önce köyün sırtı da giyinik olmalı.
  /// Tam 1.0 istemek oyuncuyu son kırıntıyı
  /// kovalamaya iter; kış zaten yumuşak bir bant.
  bool get ready => overall >= 0.90;

  /// En zayıf kalem — uyarı cümlesi bunun adını söyler ("yakacak yetmez").
  WinterItem get weakest {
    var w = items.first;
    for (final i in items) {
      if (i.ratio < w.ratio) w = i;
    }
    return w;
  }

  /// Bu kalem KAÇ GÜN daha yeter.
  ///
  /// Köyün ağzına yakışan ölçü budur: "%40" bir puandır, "odun iki güne biter"
  /// bir cümledir. Kış artık ekranda duran bir barla değil köylünün sözüyle
  /// anlatıldığı için (bkz. scene_winter), uyarının birimi de gün oldu.
  ///
  /// Yalnız GEÇİM kalemleri için anlamlı: kışlık giysi gün başına tükenmez,
  /// bir kez dokunur ve sırtta kalır.
  double daysLeftOf(WinterItem i) {
    if (i.need <= 0) return double.infinity;
    final perDay = i.need / days;
    return perDay <= 0 ? double.infinity : i.have / perDay;
  }

  /// İlk tükenecek geçim kalemi. Kışın ortasındaki tek uyarı cümlesi bunu
  /// söyler — köy aynı anda dört şeyden birden şikâyet etmez.
  WinterItem get tightest {
    var t = survival.first;
    for (final i in survival) {
      if (daysLeftOf(i) < daysLeftOf(t)) t = i;
    }
    return t;
  }
}

/// Köyün elindekine bakıp hazırlık tablosunu kurar.
///
/// [days] kaç günlük kış hesaplanacağı — kışın ORTASINDA da çağrılır (kalan
/// gün üzerinden), o zaman gösterge "daha ne kadar dayanırım"a döner.
WinterReadiness winterReadiness({
  required int mouths,
  required int animals,
  required double wood,
  required double coal,
  required double food,
  required double fodder,
  required int coats,
  int? days,
}) {
  final d = (days ?? kWinterDays).clamp(1, 999);
  return WinterReadiness(
    fuel: WinterItem(
      'Yakacak',
      wood + coal * kCoalFuelValue,
      mouths * kFuelPerMouthPerDay * d,
    ),
    food: WinterItem('Erzak', food, mouths * kFoodPerMouthPerDay * d),
    fodder: WinterItem(
      'Yem',
      fodder,
      animals * kFodderPerAnimalPerDay * d,
    ),
    coats: WinterItem('Kışlık', coats.toDouble(), mouths * kCoatPerPerson),
    days: d,
  );
}

/// KIŞLIK GİYSİ KİME? — kışın tek gerçek dağıtım kararı.
///
/// Üçü de savunulabilir, hiçbiri "doğru" değil: kırılganı giydiren köy insanca
/// davranır ama üretimi düşer; çalışanı giydiren köy ayakta kalır ama çocuk
/// üşür. Karar oyuncunun, sonucu kışın görünür.
enum CoatPriority {
  /// Çocuk ve yaşlı önce.
  frail('Kırılgan önce', 'Çocuk ve yaşlı ilk giyinir'),

  /// İşi olan önce — köyün üretimi düşmesin.
  workers('Çalışan önce', 'Sahadaki eller ilk giyinir'),

  /// Hane hane sırayla — kimse ayrıcalıklı değil.
  households('Hane hane', 'Her haneye sırayla, eşit');

  const CoatPriority(this.label, this.hint);

  final String label;
  final String hint;
}

// ── Bireyin üşümesi ─────────────────────────────────────────────────────────

/// Kışlık giysi üşümeyi bu oranda yavaşlatır (0.55 = %45 daha yavaş üşür).
///
/// Giysi ÜŞÜMEYİ BİTİRMEZ, geciktirir: bitirseydi bir kez dokunan köy kışı
/// tamamen çözerdi ve ocağın, evin, hazırlığın anlamı kalmazdı. Giysi bir
/// tampon; sıcaklık hâlâ ateşten ve damdan gelir.
const double kCoatChillRelief = 0.55;

/// Yaşa göre kırılganlık — çocuk ve yaşlı daha hızlı üşür.
///
/// Yetişkin 1.0 taban. Rakamlar bilinçli ölçülü: 1.35 "bir gece fazladan
/// dikkat" demek, "çocuk kışın ölür" değil.
const double kChildChillFrailty = 1.35;
const double kElderChillFrailty = 1.45;

/// Bir köylünün üşüme hızı çarpanı.
///
/// [coat] kışlık giysisi var mı · [child]/[elder] yaşam evresi ·
/// [shelterWarmth] barınağın ocaktan aldığı sıcaklık 0..1 (evde 1 sayılır).
double chillMultiplier({
  required bool coat,
  required bool child,
  required bool elder,
  required double shelterWarmth,
}) {
  var m = 1.0;
  if (coat) m *= kCoatChillRelief;
  if (child) m *= kChildChillFrailty;
  if (elder) m *= kElderChillFrailty;
  // Barınağın sıcağı üşümeyi tamamen kesmez ama yarıya kadar indirir.
  m *= 1.0 - 0.5 * shelterWarmth.clamp(0.0, 1.0);
  return m;
}

/// Üşümenin İŞ HIZINA yansıması — titreyen el iş görmez.
///
/// Doğrusal değil eşikli: hafif üşüme kimseyi yavaşlatmaz (kışın herkes biraz
/// üşür), asıl düşüş dürtü dolmaya yaklaşınca gelir.
double chillWorkPenalty(double chillDrive) {
  final c = chillDrive.clamp(0.0, 1.0);
  if (c < 0.45) return 1.0;
  return 1.0 - 0.45 * ((c - 0.45) / 0.55);
}

// ── İhmal ───────────────────────────────────────────────────────────────────

/// KIŞ TEK BAŞINA ÖLDÜRMEZ — İHMAL ÖLDÜRÜR.
///
/// Kullanıcı kararı: doğrudan donarak ölüm yok. Kış ancak birkaç ihmal ÜST
/// ÜSTE bindiğinde can alır ve o zaman bile hastalık yoluyla, yaşlıdan
/// başlayarak. Her ihmalin ayrı ayrı bir bedeli zaten var (moral, uyku,
/// iş hızı); burada ölçülen şey onların BİRİKMESİ.
///
/// 0 = ihmal yok · 3 = üç ihmal birden. Sahne bu sayıyı hastalık riskine
/// çevirir ve köy bunu SÖYLER (sessizce ölen köylü öğretmez).
int coldNeglect({
  required bool fireDead,
  required bool coldShelter,
  required bool noCoat,
  required bool larderEmpty,
}) {
  var n = 0;
  if (fireDead) n++;
  if (coldShelter) n++;
  if (noCoat) n++;
  if (larderEmpty) n++;
  return n;
}

/// İhmalin hastalık riskine çarpanı. İki ihmale kadar YOK sayılır: kışın
/// ocağın bir gece sönmesi ya da giysisiz kalmak tek başına ölüm sebebi
/// değildir. Üçten sonra köy gerçekten tehlikededir.
double neglectIllnessMultiplier(int neglect) => switch (neglect) {
  <= 1 => 1.0,
  2 => 1.35,
  3 => 2.1,
  _ => 3.0,
};

// ── Dünyanın kışı ───────────────────────────────────────────────────────────

/// Karda yürüme çarpanı — kışın her şey biraz ağır ilerler.
///
/// %12: hissedilir ama sinir bozmaz. Daha fazlası köyü ağır çekim yapıyor,
/// daha azı hiç fark edilmiyordu.
const double kSnowSpeedMultiplier = 0.88;

/// Mevsimin zemin çarpanı — köylünün [groundFactor] alanına yazılan değer.
///
/// Kural burada SAF durur çünkü sahnede kalsaydı yalnız canlı köy koşturarak
/// sınanabilirdi; kışın yavaşlaması gibi mekanikler tam da böyle sessizce
/// kopar (sabit tanımlıdır, kimse yazmaz, kimse fark etmez).
double groundFactorFor(Season s) =>
    s == Season.winter ? kSnowSpeedMultiplier : 1.0;

/// KAR YAĞIŞI görünür mü — ambiyans kar katmanının kapısı.
///
/// Kar yalnız kışın yağar; ama kışın da her zaman DEĞİL:
///   • Şenlik/göktaşı efektleri kendi partikül dilini kullanır — üstüne kar
///     bindirmek hem okunurluğu hem kare maliyetini boşuna artırır.
///   • Fırtına KENDİ yoğun/rüzgârlı kar katmanını çizer; ikisi üst üste
///     binerse kar iki kat yoğun görünür (aynı hava iki kez çizilmiş olur).
///   • Çok uzak zoom'da tek piksellik taneler gürültüye dönüşür.
/// DEV: kar yağışını mevsimden BAĞIMSIZ aç (godmode paneli).
///
/// Yağmur toggle'ının kar karşılığı: karı görmek için takvimi kışa sarmak
/// gerekiyordu. Yalnız GÖRSEL katmanı zorlar — mevsim, yürüme hızı, tarla,
/// yakacak hiçbiri değişmez (onlar için Kış düğmesi var).
bool kDevForceSnowfall = false;

bool snowfallVisible({
  required Season season,
  required double zoom,
  bool festival = false,
  bool meteorShower = false,
  bool storm = false,
  double minZoom = 0.35,
}) {
  if (kDevForceSnowfall) return zoom >= minZoom;
  if (season != Season.winter) return false;
  if (festival || meteorShower || storm) return false;
  return zoom >= minZoom;
}

/// Göl kışın donar: balıkçılık kesilir, buz üstü yürünmez (su hâlâ engel).
bool waterFrozen(Season s) => s == Season.winter;

/// Evin kendi ocağı günde bu kadar yakacak yer (odun eşdeğeri, hane başına).
///
/// Meydan ateşi köyün ortak sıcaklığıdır; evin içindeki ocak ayrı yanar.
/// Önceden yalnız meydan ateşi yakıt istiyordu — yani taş ev diken köy kışı
/// bedelsiz çıkarıyordu, oysa asıl yakacak tüketimi hanelerdedir.
const double kHouseHearthFuelPerDay = 0.6;
