/// HANE KARŞILIĞI — hanenin sana ne KADAR verdiği, ne kadarını GERİ ÇEKTİĞİ.
///
/// Hane katmanı bugüne dek tek yönlüydü: [HouseSystem] hâli (mood) ve nüfuzu
/// (sway) tutar, bunlar bireysel morale ve köy kimliğine akardı. Yani hane
/// oyuncuya bir SAYI bildiriyordu; hiçbir şeyi geri almıyordu. Küskün hane
/// somurtuyor ama tarlaya yine çıkıyor, ambara yine koyuyor, kızını yine
/// veriyordu. Bu katman o eksik yarıyı kurar: **hane elini çeker.**
///
/// Merdiven TEK basamakta TEK yeni görünür şey ekler — oyuncu neyin
/// değiştiğini okumadan, köye bakarak anlasın:
///
///   🤝 sadık      → fazladan verir (hanenin ikramı)
///   🙂 razı       → normal
///   😒 serzenişte → söylenir; henüz hiçbir şey esirgemez (UYARI basamağı)
///   ✋ el çekti   → ÜYELERİ İŞE ÇIKMAZ
///   🔒 ambar kapalı → + ürettiği yiyeceği kendi ambarına saklar
///   ⚔ kopuş      → + masaya oturmaz, kız/oğul vermez
///
/// İKİ ÇARPAN: kızgınlık (grievance) TEK BAŞINA yetmez, hanenin bir de
/// KOZU (leverage = köy içi nüfuz payı) olmalı. Nüfuzsuz hane ancak somurtur;
/// köyün yarısını tutan hane ambarı kapatır. "Kaybedecek bir şey" tam olarak
/// buradan doğar: güçlü haneyi küstürmek bedel ödetir, güçsüzü küstürmek
/// yalnız vicdan meselesidir.
///
/// COZY SINIRI: hiçbir basamak oyunu BİTİRMEZ. Hane köyü yavaşlatır, ambarı
/// zayıflatır, masayı boşaltır — hepsi GERİ DÖNDÜRÜLEBİLİR. Sakladığı yiyecek
/// yok olmaz; hane razı olunca ambarını kendi açar (bkz. [HouseState.stash]
/// kullanıcısı `scene_house_stance`). Yani bu bir ceza değil, bir PAZARLIK.
///
/// Bu dosya SAF: sahne state'i tutmaz, rastgelelik/metin içermez → test
/// edilebilir (bkz. test/house_stance_test.dart). Oyuncuya görünen tüm cümleler
/// voice havuzlarındadır (bkz. project_voice_system), burada değil.
library;

/// Hanenin sana karşı duruşu — sertlik sırasına göre (index = merdiven basamağı).
enum HouseStance {
  /// 🤝 Sadık — sana borçlu, fazladan verir.
  loyal,

  /// 🙂 Razı — normal karşılık.
  content,

  /// 😒 Serzenişte — söylenir ama esirgemez. Oyuncunun UYARI penceresi.
  murmuring,

  /// ✋ El çekti — üyeleri işe çıkmaz.
  withdrawn,

  /// 🔒 Ambar kapalı — el çekmenin üstüne ürünü saklar.
  hoarding,

  /// ⚔ Kopuş — üstüne masayı boykot eder, nikâh vermez.
  defiant,
}

extension HouseStanceX on HouseStance {
  String get icon => switch (this) {
        HouseStance.loyal => '🤝',
        HouseStance.content => '🙂',
        HouseStance.murmuring => '😒',
        HouseStance.withdrawn => '✋',
        HouseStance.hoarding => '🔒',
        HouseStance.defiant => '⚔',
      };

  String get label => switch (this) {
        HouseStance.loyal => 'Sadık',
        HouseStance.content => 'Razı',
        HouseStance.murmuring => 'Serzenişte',
        HouseStance.withdrawn => 'Elini çekti',
        HouseStance.hoarding => 'Ambarı kapalı',
        HouseStance.defiant => 'Kopuş',
      };

  /// Hane bir şey esirgiyor mu — UI'da "bu hane sana ne yapıyor" rozetinin kapısı.
  bool get withholds => index >= HouseStance.withdrawn.index;

  /// Serzeniş ve üstü — köy bunu duyuyor (herald/bildirim kapısı).
  bool get audible => index >= HouseStance.murmuring.index;

  /// Basamağın KISA bedel künyesi — [nextRung] önizlemesiyle birlikte "bir
  /// adım ötede ne olur" satırını kurar (hane kartı + defter). Cümle değil
  /// künye: dar satıra sığmalı, rakamsız okunmalı.
  String get costHint => switch (this) {
        HouseStance.loyal => 'fazladan verir',
        HouseStance.content => 'normal karşılık',
        HouseStance.murmuring => 'söylenir, henüz esirgemez',
        HouseStance.withdrawn => 'eller işten çekilir',
        HouseStance.hoarding => 'ürün kendi ambarına gider',
        HouseStance.defiant => 'masayı ve nikâhı kapatır',
      };
}

/// Bir hanenin o an ne kadarını geri çektiği. Tüm oranlar 0..1.
class HouseWithholding {
  /// Üyelerin kaçta kaçı işe çıkmıyor. Otomatik kadro bu oranda üyeyi
  /// havuz dışı sayar (elle atama ayrı kapıdan geçer — bkz. scene_jobs).
  final double labor;

  /// Ürettiği yiyeceğin kaçta kaçı köy ambarı yerine hanenin kendi ambarına
  /// gider. Yiyecek YOK OLMAZ; hanenin stash'ine yazılır.
  final double hoard;

  /// Hanenin İKRAMI — sadık hane ürettiğinin üstüne bu oranda fazla verir.
  /// Merdivenin pozitif ucu: karşılık iki yönlüdür.
  final double bounty;

  /// Nikâh vermiyor mu — kur bu haneye takılır (kur başlamaz).
  final bool betrothal;

  /// Meclis masasını boykot ediyor mu — reis divanda sandalyesini boş bırakır.
  final bool council;

  const HouseWithholding({
    this.labor = 0,
    this.hoard = 0,
    this.bounty = 0,
    this.betrothal = false,
    this.council = false,
  });

  /// Hiçbir şey esirgemiyor + ikram da yok.
  bool get isNeutral =>
      labor == 0 && hoard == 0 && bounty == 0 && !betrothal && !council;

  static const none = HouseWithholding();
}

// ── Eşikler ───────────────────────────────────────────────────────────────────
// Hane mood tabanı 0.55 ([HouseSystem] `_moodBaseline`). Kızgınlık o tabandan
// aşağı düşüşün normalize edilmiş hâlidir: taban = 0 kızgınlık, mood 0 = 1.0.

/// Kızgınlığın ölçüldüğü taban — hane mood'unun boşluktaki dinlenme noktası.
const double kSettledMood = 0.55;

/// Bunun üstünde hane SADIK — sana borçlu, fazladan verir.
const double kLoyalMood = 0.78;

/// Serzeniş eşiği — bu kızgınlıktan sonra hane söylenmeye başlar.
const double kMurmurGrievance = 0.10;

/// El çekme eşiği — bu kızgınlıktan sonra üyeler işe çıkmaz.
const double kWithdrawGrievance = 0.27;

/// Ambar kapatma eşiği — kızgınlık VE koz birlikte gerekir.
const double kHoardGrievance = 0.45;
const double kHoardLeverage = 0.85;

/// Kopuş eşiği — en kızgın + en kozlu hane.
const double kDefiantGrievance = 0.62;
const double kDefiantLeverage = 1.15;

/// Hanenin kızgınlığı 0..1 — [kSettledMood] tabanından aşağı düşüşün payı.
/// Taban ve üstü = 0 (razı bir hane kızgın değildir, fazladan razıdır).
double grievanceOf(double mood) =>
    ((kSettledMood - mood) / kSettledMood).clamp(0.0, 1.0);

/// Hanenin KOZU — köy içi nüfuz payının "adil pay"a oranı. 1.0 = tam adil pay
/// (N hane varsa 1/N), 2.0 = adil payın iki katı. Tek hane varsa koz 1.0.
///
/// Neden pay değil de ORAN: 8 haneli köyde %20 pay büyük bir kozdur, 2 haneli
/// köyde aynı %20 zayıftır. Ham pay kullanılsaydı kalabalık köyde hiçbir hane
/// merdiveni tırmanamaz, sistem sessizce ölürdü.
double leverageOf(double swayShare, int houseCount) {
  if (houseCount <= 1) return 1.0;
  return (swayShare * houseCount).clamp(0.0, 4.0);
}

/// Hanenin duruşu. [members] canlı üye sayısı — üyesiz hane (sönmüş soy)
/// hiçbir şey esirgeyemez, nüfuzu kağıt üstünde dursa bile.
HouseStance stanceFor({
  required double mood,
  required double swayShare,
  required int houseCount,
  required int members,
}) {
  if (members <= 0) return HouseStance.content;
  if (mood >= kLoyalMood) return HouseStance.loyal;

  final g = grievanceOf(mood);
  if (g < kMurmurGrievance) return HouseStance.content;
  if (g < kWithdrawGrievance) return HouseStance.murmuring;

  final lev = leverageOf(swayShare, houseCount);
  if (g >= kDefiantGrievance && lev >= kDefiantLeverage) {
    return HouseStance.defiant;
  }
  if (g >= kHoardGrievance && lev >= kHoardLeverage) {
    return HouseStance.hoarding;
  }
  return HouseStance.withdrawn;
}

/// Duruşun somut karşılığı. Basamak İÇİNDE ince ayar kızgınlıkla yapılır:
/// yeni el çekmiş hane birkaç kişiyi tutar, iyice kızmış hane herkesi.
HouseWithholding withholdingFor(HouseStance s, {required double grievance}) {
  /// [lo]..[hi] kızgınlık aralığını 0..1'e serer — basamak içi rampa.
  double ramp(double lo, double hi) =>
      ((grievance - lo) / (hi - lo)).clamp(0.0, 1.0);

  return switch (s) {
    // Sadık hane fazladan verir — merdivenin ödül ucu.
    HouseStance.loyal => const HouseWithholding(bounty: 0.15),
    HouseStance.content => HouseWithholding.none,
    // Serzeniş HİÇBİR ŞEY esirgemez: oyuncunun ücretsiz uyarı penceresi.
    HouseStance.murmuring => HouseWithholding.none,
    HouseStance.withdrawn => HouseWithholding(
        labor: 0.35 + 0.30 * ramp(kWithdrawGrievance, kHoardGrievance),
      ),
    HouseStance.hoarding => HouseWithholding(
        labor: 0.70,
        hoard: 0.35 + 0.25 * ramp(kHoardGrievance, kDefiantGrievance),
      ),
    HouseStance.defiant => const HouseWithholding(
        labor: 0.95,
        hoard: 0.75,
        betrothal: true,
        council: true,
      ),
  };
}

/// Hanenin sakladığı yiyeceğin ÜST SINIRI — üye başına. Sınırsız stash bir
/// haneyi köyün ambarından büyük yapardı; sınır dolunca hane saklamayı bırakır
/// (ürün yine köye akar), yani ambar kalıcı olarak kurumaz.
const int kStashPerMember = 6;

/// Bu hane daha ne kadar saklayabilir. Dolduysa 0 → saklama durur.
int stashRoom(int stash, int members) =>
    (members.clamp(0, 40) * kStashPerMember - stash).clamp(0, 1 << 20);

/// Hane razı olunca ambarını AÇAR: sakladığının bu oranı her gün köye döner.
/// Bir çırpıda değil — geri dönüş de görünür bir süreç olsun (ambar birkaç gün
/// boyunca kendi kendine şişer, oyuncu barışın karşılığını hisseder).
const double kStashReturnPerDay = 0.34;

/// Merdivende bir üst basamak — "bu hane bir adım daha giderse ne olur"
/// önizlemesi için (hane kartı oyuncuya bedeli ÖNCEDEN göstersin).
HouseStance? nextRung(HouseStance s) =>
    s.index >= HouseStance.defiant.index || s == HouseStance.loyal
        ? null
        : HouseStance.values[s.index + 1];
