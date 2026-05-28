import 'dart:math';

/// Köy çapında ortak rüzgâr alanı. Her bitkinin bağımsız jitter'ı yerine,
/// tarlanın üzerinden dalga gibi ilerleyen ve esinti zarfıyla güçlenip
/// zayıflayan tutarlı bir rüzgâr üretir. Tüm bitki render'ları (ağaç, saz)
/// bunu kullanır → rüzgâr dalgaları sahnede gözle görülür biçimde gezer.
class Wind {
  // Rüzgâr yönü (col, row düzleminde) — dalga bu yön boyunca ilerler.
  static const double _dirCol = 1.0;
  static const double _dirRow = 0.45;
  static const double _speed  = 1.8;  // dalganın zamanda ilerleme hızı (rad/sn)
  static const double _len    = 0.22; // mekânsal frekans (büyük = sık dalga)

  /// Esinti zarfı ~0.45..1.0 — rüzgâr uzun salınımlarla güçlenip zayıflar.
  static double gust(double time) => (0.45 +
          0.35 * (sin(time * 0.21) * 0.5 + 0.5) +
          0.20 * (sin(time * 0.07 + 2.0) * 0.5 + 0.5))
      .clamp(0.0, 1.0);

  /// Dünya konumu ([col],[row]) ve [time] için skew (eğme) miktarı.
  /// [amp] bitkinin esneme genliği (ağaç büyük, saz ince), [jitter] tür-içi
  /// faz dağıtımı — komşu bitkilerin tam kilit adımda olmasını önler.
  static double swayAt(double col, double row, double time,
      {double amp = 0.04, double jitter = 0.0}) {
    final travel = (col * _dirCol + row * _dirRow) * _len;
    // Ana dalga + hafif ikinci harmonik → saf sinüsten daha doğal tepe profili.
    final wave = sin(time * _speed - travel + jitter) +
        0.25 * sin(time * _speed * 1.7 - travel * 1.3 + jitter);
    return amp * gust(time) * wave;
  }
}
