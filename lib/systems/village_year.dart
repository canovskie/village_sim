// YILLAR — köyün ömrünü bir KOŞUYA çeviren zaman omurgası.
//
// Oyunun uzun süre "düz" hissettirmesinin sebebi tam olarak burada eksik olan
// şeydi: hiçbir baskı ZAMANLA ARTMIYORDU. Olay aralığı sabit bir banttı, vergi
// talebi yalnız o günkü nüfusa bakıyordu. Yüzüncü gündeki köy, onuncu gündeki
// köyle aynı basıncı yiyordu — ama beş katı kaynağı ve on katı eli vardı.
// Zorluk sabit kalınca oyun bir noktadan sonra kendini oynuyordu.
//
// Bu dosya tek bir iş yapar: gün sayacından bir YIL çıkarır ve o yıla ait
// baskı katsayılarını verir. Eskalasyonun TEK KAYNAĞI burasıdır. Sistemler
// kendi içlerinde "kırkıncı günden sonra şöyle olsun" demez; buradan okur.
// İkinci bir eskalasyon merdiveni açılırsa denge iki yerden birden bükülür ve
// hangisinin ne yaptığı bir daha anlaşılmaz.
//
// Yılın ikinci işi: koşuya bir SON vermek. [kReckoningYear] hesaplaşma yılıdır;
// o yıla girildiğinde imparatorluk vergi için değil KARAR için gelir
// (bkz. systems/reckoning.dart). Bir yıl önceden ilan edilir — habersiz biten
// koşu, habersiz ölen köyle aynı hatadır.
//
// Saf: Flutter yok, sahne yok, rastgelelik yok (bkz. test/village_year_test).
library;

import '../world/season.dart';

/// Bir yıl kaç mevsim. Dört; ama sayı kodda çıplak dolaşmasın.
const int kSeasonsPerYear = 4;

/// Bir oyun yılı kaç gün. Mevsim 4 gün → yıl 16 gün ≈ 64 dakika (1× hızda).
const int kDaysPerYear = kDaysPerSeason * kSeasonsPerYear;

/// HESAPLAŞMA YILI — koşunun bittiği yıl.
///
/// Neden altı: kuruluş ilk yılı yer, tüzük ikinci-üçüncü yılda kalınlaşır,
/// haneler dördüncü yıla kadar huyunu belli eder. Altıncı yıl, oyuncunun
/// kurduğu şeyin bir CEVABI olacak kadar geç; koşunun sarkmayacağı kadar
/// erken. 1× hızda ~5,5 saat, hızlandırmalı ~2 saatlik bir kampanya.
const int kReckoningYear = 6;

/// İlan yılı — imparatorluk beratı bir yıl önceden duyurur. Bu tampon
/// pazarlık değil HAZIRLIK penceresidir: son yılın her kararı tartılır.
const int kReckoningHeraldYear = kReckoningYear - 1;

/// Gün sayacından yıl. `dayCount` 1'den başlar → gün 1 birinci yıldır.
int yearOf(int dayCount) => ((dayCount - 1) ~/ kDaysPerYear) + 1;

/// Yılın kaçıncı günündeyiz (1..[kDaysPerYear]).
int dayInYear(int dayCount) => ((dayCount - 1) % kDaysPerYear) + 1;

/// Hesaplaşmaya kalan gün. Hesaplaşma yılına girildiyse 0.
int daysUntilReckoning(int dayCount) {
  const first = (kReckoningYear - 1) * kDaysPerYear + 1;
  final left = first - dayCount;
  return left <= 0 ? 0 : left;
}

/// Yılın oyuncuya görünen adı. Köy kendi yaşını böyle sayar.
String yearLabel(int year) => '$year. yıl';

/// BİR YILIN BASKISI — o yıl dünyanın köye ne kadar yüklendiği.
///
/// Üç katsayı, üçü de tek bir yıl indeksinden türer. Hepsi ÇARPANDIR: taban
/// dengeyi sistemler kendi içinde tutar, bu sınıf yalnız onu büker. Böylece
/// "birinci yıl" her zaman bugünkü oyunla birebir aynı kalır (1.0), eskalasyon
/// mevcut dengeyi yeniden yazmak zorunda kalmaz.
class EraPressure {
  /// Kaçıncı yıl (1 tabanlı).
  final int year;

  /// Vergi talebinin sertlik çarpanı. 1. yıl 1.0 → hesaplaşma yılı 2.0.
  /// İmparatorluk her yıl defterdeki rakamı büyütür.
  final double imperialAppetite;

  /// Heyetin ham geliş aralığı çarpanı. KÜÇÜLDÜKÇE SIK aday üretir; oyuncuya
  /// açılan ağır yüzeylerin gerçek alt sınırı DecisionPacing'dedir.
  final double imperialTempo;

  /// Rastgele olay aday aralığı çarpanı. Seçimsiz hafif olaylar aynen akar;
  /// seçimli ağır olaylar ortak ritim kuyruğundan geçer.
  final double eventTempo;

  /// Dilekçe aday aralığı çarpanı; köy yaşlandıkça kapı sıklaşır ama ağır karar
  /// sunum sıklığı merkezi ritim otoritesince sınırlanır.
  final double petitionTempo;

  /// Kışın sertlik çarpanı — yakacak ihtiyacına biner (bkz. `winterReadiness`).
  /// Sertleşen şey İHTİYAÇ, ceza değil: hazırlıklı köyde altıncı kış da
  /// sakindir, yalnız daha çok odun ister.
  final double winterBite;

  /// Vergicinin KESEDEN isteyeceği pay (0..1).
  ///
  /// ÖLÇÜMDEN DOĞDU: vergi yalnız nüfusa bakıyordu ve altın nüfustan çok daha
  /// hızlı birikiyordu (ölçüm: 17 canlık köyde ~27 altın/gün, altıncı yıl
  /// talebi ise ~76 altın — üç günlük gelir). Talebi ikiye katlamak bu
  /// eğrinin yanında hiçbir şey ifade etmiyordu; kese doluyor, hiçbir karar
  /// zorlaşmıyordu.
  ///
  /// Bu pay o boşluğu kapatır ve karakterle de tutarlıdır: imparatorluk
  /// "kayıtlı olan öder" der ve köy zenginleştikçe dikkat çeker. Artık istif
  /// yapan köy istifinden vergilenir, fakir köy nüfus tabanından. Oyuncunun
  /// önüne gerçek bir soru koyar: keseyi köye mi yatırırsın (bağış, nikâh,
  /// bina), yoksa vergicinin alması için mi bekletirsin?
  final double treasuryShare;

  const EraPressure({
    required this.year,
    required this.imperialAppetite,
    required this.imperialTempo,
    required this.eventTempo,
    required this.petitionTempo,
    required this.winterBite,
    required this.treasuryShare,
  });

  /// İlan yılına girildi mi — berat duyurusu bu yıl düşer.
  bool get heralded => year >= kReckoningHeraldYear;

  /// Hesaplaşma yılı geldi mi.
  bool get reckoning => year >= kReckoningYear;
}

/// Yılın baskısı. Hesaplaşma yılından sonrası (kayıt kurcalanmış ya da ileride
/// serbest oyun eklenmişse) tavanda sabitlenir — sonsuza kadar tırmanmaz.
EraPressure pressureForYear(int year) {
  // 0 tabanlı basamak: 1. yıl = 0 (taban denge, bugünkü oyun).
  final step = (year - 1).clamp(0, kReckoningYear - 1);
  return EraPressure(
    year: year < 1 ? 1 : year,
    // 1.0 → 2.0 (beş basamakta iki katı). Nüfus zaten talebi büyütüyor;
    // bu çarpan onun ÜSTÜNE biner, yoksa büyüyen köy rahatlıyordu.
    imperialAppetite: 1.0 + 0.20 * step,
    // 1.0 → 0.55. Taban aralık ~3-8 gün; son yılda ~1,7-4,4 güne iner.
    imperialTempo: 1.0 - 0.09 * step,
    // 1.0 → 0.65. Taban 80-120 sn → son yılda yaklaşık 52-78 sn.
    eventTempo: 1.0 - 0.07 * step,
    petitionTempo: 1.0 - 0.06 * step,
    // 1.0 → 1.35. Vergiden (2.0×) bilerek DAHA YUMUŞAK: kış zaten hazırlık
    // isteyen bir mevsim, üstüne iki katı yük binerse geç oyun bir odun
    // toplama angaryasına döner. Çeyrek fazlası fark edilir, boğmaz.
    winterBite: 1.0 + 0.07 * step,
    // 0.20 → 0.45. Yarıdan azı bilerek: vergici keseyi boşaltmaz, ısırır.
    // Tamamını alan bir vergi, altın biriktirmeyi tümüyle anlamsız kılar ve
    // oyuncu keseyi hiç doldurmamayı öğrenir (kaynağı öldürmüş oluruz).
    treasuryShare: 0.20 + 0.05 * step,
  );
}

/// Gün sayacından doğrudan baskı — çağrı yerlerinde iki adım olmasın.
EraPressure pressureForDay(int dayCount) => pressureForYear(yearOf(dayCount));
