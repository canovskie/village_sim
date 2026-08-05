import 'dart:math';
import 'dart:ui' show Size;

/// ─── KAR ALANI (saf kural) ──────────────────────────────────────────────────
///
/// Bir karenin kar tanelerini ekran-uzayında çözer. Çizimden AYRI durur çünkü
/// karın "dandik" görünmesi neredeyse hiç boyadan gelmez, hep matematikten
/// gelir ve painter'ın içine gömülü bir döngü yalnız kare çekerek sınanabilir:
///
///   • `i * 1733 % 997` gibi doğrusal diziler tane yerleşimini ızgaraya
///     oturtur → gözün seçtiği düşey bantlar (kar "duvar kâğıdı" gibi akar).
///   • Katmandaki her tane aynı frekansla salınırsa bütün katman TEK parça
///     gibi sağa sola yalpalar — kar değil, perde hissi.
///   • Katman içinde tek bir düşüş hızı = yürüyen bant. Gerçek karda ağır tane
///     hızlı, tüy gibi olan asılı kalır.
///   • Alfa'nın sinüsle yanıp sönmesi ateş böceğinin dili; kar parıldamaz,
///     yaklaşıp uzaklaşır.
///
/// Bu yüzden taneler burada üretilir, `snow_test.dart` de tam bu dört şeyi
/// (dağılım, salınım desenkronu, hız yayılımı, kenarda pop yok) sınar.
///
/// Sözleşme: SAF. Ekran boyu + zaman + zoom girer, tane çıkar; hiçbir oyun
/// durumu okunmaz/yazılmaz.

/// Tek bir derinlik katmanı — uzak taneler küçük/yavaş/soluk ve rüzgâra az
/// kapılır (paralaks: uzaktaki hareket ekranda daha az yer değiştirir), yakın
/// taneler büyük/hızlı/parlak ve rüzgârda savrulur.
class SnowLayerSpec {
  const SnowLayerSpec({
    required this.count,
    required this.speed,
    required this.rMin,
    required this.rMax,
    required this.alpha,
    required this.sway,
    required this.wind,
    required this.halo,
    required this.tone,
    required this.seed,
  });

  /// zoom 1.0 / perf kapalı iken tane sayısı.
  final int count;

  /// Ekran yüksekliğinin saniyedeki oranı (0.16 ≈ 6 sn'de yukarıdan aşağı).
  final double speed;
  final double rMin;
  final double rMax;
  final double alpha;

  /// Tane başına yatay salınım genliği (px).
  final double sway;

  /// Rüzgâra kapılma çarpanı.
  final double wind;

  /// Çekirdeğin çevresine çizilecek soluk hale yarıçapı (0 = hale yok).
  /// Blur yerine iç içe iki daire — ateş böceklerindeki ucuz yumuşatma.
  final double halo;

  /// Çekirdeğin BEYAZLIĞI (0 = soğuk gri-mavi, 1 = kar beyazı).
  ///
  /// Kışın zemin de neredeyse beyaz (kar tile ortalaması ~#DBE6F2), yani saf
  /// beyaz tane yalnız gökyüzünde okunuyordu. Uzak katman bu yüzden ARA TONDA
  /// çizilir: koyu gökten açık, parlak kardan koyu — tek daireyle iki zeminde
  /// de görünür. Yakın katmanlar beyaz kalır, kenarı haleden gelir.
  final double tone;
  final int seed;
}

/// [kSnowLayers] sayılarının geçerli olduğu ekran alanı (1280×800).
/// Sayılar SABİT olsaydı kar masaüstünde seyrelir, telefonda tıkanırdı —
/// eski kod tam olarak bunu yapıyordu (her boyda 65 tane).
const double kSnowRefArea = 1280.0 * 800.0;

/// Üç derinlik, referans alanda toplam ~300 tane.
///
/// Eski değer 65'ti ve asıl "dandik" buydu: 1280×800'de tane başına ~10.000
/// piksel düşüyor, yani kar yağmıyor — havada birkaç zerre asılı duruyor.
/// Tanelerin çoğu en uzak/en ucuz katmanda (halesiz tek daire), yani yoğunluk
/// 4-5 katına çıkarken kare maliyeti aynı sırada kalır.
const List<SnowLayerSpec> kSnowLayers = [
  // Uzak toz karı — yoğunluk hissi buradan gelir. Kalabalık olduğu için TEK
  // daire: hale yerine ara ton taşır (bkz. [SnowLayerSpec.tone]).
  SnowLayerSpec(
    count: 200,
    speed: 0.055,
    rMin: 0.75,
    rMax: 1.35,
    alpha: 0.46,
    sway: 5.0,
    wind: 0.55,
    halo: 0.0,
    tone: 0.30,
    seed: 211,
  ),
  // Orta katman — sahnenin "kar yağıyor" okuması esas burada.
  SnowLayerSpec(
    count: 92,
    speed: 0.095,
    rMin: 1.5,
    rMax: 2.4,
    alpha: 0.62,
    sway: 9.0,
    wind: 0.85,
    halo: 1.85,
    tone: 0.85,
    seed: 877,
  ),
  // Yakın, iri lapa — az sayıda, kameraya yapışık, en çok savrulan.
  SnowLayerSpec(
    count: 46,
    speed: 0.155,
    rMin: 2.7,
    rMax: 4.3,
    alpha: 0.80,
    sway: 15.0,
    wind: 1.15,
    halo: 2.0,
    tone: 1.0,
    seed: 1559,
  ),
];

/// Ekranın dışında tutulan güvenlik payı — haleli iri tane kenardan
/// "belirmeden" girip çıksın diye.
const double kSnowMargin = 26.0;

/// Tane emitter'ı: (x, y, yarıçap, alfa, hale yarıçapı, çekirdek beyazlığı).
/// Alfa ve ton 0..1; hale 0 ise hale çizilmez.
typedef SnowEmit =
    void Function(
      double x,
      double y,
      double r,
      double a,
      double halo,
      double tone,
    );

class SnowField {
  SnowField._();

  /// RÜZGÂR — ekran-uzayı yatay ötelemesi (px), zamanın saf fonksiyonu.
  ///
  /// İki YAVAŞ ve ortak katı olmayan sinüs: kar hep aynı yöne eğik akmaz,
  /// ~1 dakikalık ölçekte yön değiştirir. Türevi (≈ 12.6 + 10.9 px/sn) yakın
  /// katmanda ~15-20°'lik bir eğim verir — fark edilir ama fırtına değil.
  static double wind(double time) =>
      sin(time * 0.037) * 340.0 + sin(time * 0.091 + 2.1) * 120.0;

  /// TİPİ NEFESİ — kar sabit yoğunlukta yağmaz, dalga dalga gelir.
  /// Tane SAYISI değil ALFA dalgalanır; sayı oynatılsaydı taneler yok olup
  /// belirirdi (pop).
  static double flurry(double time) =>
      0.80 + sin(time * 0.047) * 0.14 + sin(time * 0.131 + 2.1) * 0.06;

  /// Bu karenin tanelerini üretir. Liste döndürmez — kare başına ~105 nesne
  /// ayırmamak için emit callback'i ile akıtır (test kendi listesine toplar).
  static void forEach(
    SnowEmit emit, {
    required Size size,
    required double time,
    required double zoom,
    bool perfMode = false,
  }) {
    if (size.width <= 0 || size.height <= 0) return;

    // Yoğunluk ALANLA ölçeklenir: kar bir alan olayıdır, sabit tane sayısı
    // geniş pencerede boşluk, telefonda tıkanıklık demek. Uçlarda kilitli
    // (4K'da 1200 tane çizmenin görsel karşılığı yok).
    final areaScale = (size.width * size.height / kSnowRefArea).clamp(
      0.40,
      1.9,
    );
    // Uzak zoom'da tane hem küçülür hem gürültüye döner → seyrelt.
    final density = areaScale * (perfMode ? 0.52 : (zoom < 0.6 ? 0.72 : 1.0));
    // Tane boyu zoom'la HAFİF ölçeklenir (yaprakta olduğu gibi): kar ekran
    // uzayında yaşasa da sahneden tamamen kopuk durmasın.
    final rScale = (0.60 + 0.40 * zoom).clamp(0.70, 1.45);

    final spanW = size.width + kSnowMargin * 2;
    final spanH = size.height + kSnowMargin * 2;
    final w = wind(time);
    final f = flurry(time);

    for (final L in kSnowLayers) {
      final n = (L.count * density).round();
      final windX = w * L.wind;
      for (int i = 0; i < n; i++) {
        // Beş İLİNTİSİZ rastgele öznitelik. Doğrusal (i * sabit % asal) dizi
        // yerine hash: yerleşim ızgaraya oturmaz, düşey bant oluşmaz.
        final u = _h(i, L.seed); // yatay yuva
        final v = _h(i, L.seed + 17); // düşüş fazı
        final g = _h(i, L.seed + 31); // boy (gramaj)
        final q = _h(i, L.seed + 53); // hız sapması
        final s = _h(i, L.seed + 71); // salınım fazı/frekansı

        // Ağır tane hızlı düşer, tüy gibi olan asılı kalır — katman içinde
        // ±%25 sapma + boya bağlı eğilim. Yürüyen bant hissini kıran şey bu.
        final fall = L.speed * (0.75 + 0.50 * q) * (0.88 + 0.24 * g);
        final p = (v + time * fall) % 1.0;
        final y = p * spanH - kSnowMargin;

        // Her tane KENDİ frekansı ve fazıyla salınır → katman tek parça
        // yalpalamaz. Küçük taneler daha az sallanır (hava direnci sezgisi
        // değil, okunurluk: küçük tanenin salınımı gürültü gibi görünüyor).
        final swayX =
            sin(time * (0.42 + s * 0.55) + s * 6.2832) *
            L.sway *
            (0.55 + 0.45 * g);

        final x = (u * spanW + windX + swayX) % spanW - kSnowMargin;

        // Görünmeyecek kadar sönük taneyi BURADA elemiyoruz: alan her karede
        // tam olarak aynı sayıda tane yayar, "kaybolan tane" diye bir şey
        // olamaz. Kırpma çizim tarafının işi (bkz. `_drawSnow`).
        final a = L.alpha * f * _edgeFade(p);
        final r = (L.rMin + (L.rMax - L.rMin) * g) * rScale;
        emit(x, y, r, a, L.halo * r, L.tone);
      }
    }
  }

  /// Kenarda POP yok: tane üstte belirirken açılır, altta kaybolurken söner.
  /// İri yakın taneler için tek başına gözle görülür bir kazanç.
  static double _edgeFade(double p) {
    const inEnd = 0.07;
    const outStart = 0.90;
    if (p < inEnd) return p / inEnd;
    if (p > outStart) return (1.0 - p) / (1.0 - outStart);
    return 1.0;
  }

  /// Ucuz, platformdan bağımsız hash → [0,1). Tamsayı taşması yok (web'de
  /// int 32-bit bitwise semantiği başka türlü davranırdı).
  static double _h(int i, int seed) {
    final v = sin(i * 12.9898 + seed * 78.233) * 43758.5453;
    return v - v.floorToDouble();
  }
}
