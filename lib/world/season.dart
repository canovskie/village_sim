/// Mevsim sistemi — tarımın omurgası.
///
/// Mevsim global gün sayacından (`_dayCount`) türetilir; ayrı bir state
/// tutulmaz, dolayısıyla save/load otomatik çalışır (dayCount zaten kayıtlı).
/// Bir yıl = 4 mevsim × [kDaysPerSeason] gün. Tempo: 4 gün/mevsim ≈ 16 dk
/// (oyun günü 240 sn), yıl ≈ 64 dk — fark edilir ama sıkmaz.
library;

/// Mevsim başına oyun günü sayısı.
const int kDaysPerSeason = 4;

enum Season {
  spring('İlkbahar', '🌱'),
  summer('Yaz',      '☀️'),
  autumn('Sonbahar', '🍂'),
  winter('Kış',      '❄️');

  const Season(this.label, this.icon);

  final String label;
  final String icon;

  /// Ekin büyüme hızı çarpanı. Kış = 0 → tarla donar, büyüme durur.
  /// Yaz hızlı yeşertir ama susuzluk cezası ağırdır ([unwateredPenalty]).
  double get growthMultiplier => switch (this) {
        Season.spring => 1.0,
        Season.summer => 1.35,
        Season.autumn => 1.0,
        Season.winter => 0.0,
      };

  /// Sulanmamış ekin bu çarpanla yavaşlar. Yazın kuraklık kritik (0.45);
  /// ilkbahar/sonbaharda yağış bol, ceza yok.
  double get unwateredPenalty => switch (this) {
        Season.spring => 1.0,
        Season.summer => 0.45,
        Season.autumn => 0.9,
        Season.winter => 1.0, // büyüme zaten 0
      };

  /// Hasat verimi bonusu — sonbahar bereketi. Balya→yiyecek dönüşümünde
  /// (carrier_system) bu çarpan uygulanır.
  double get yieldMultiplier => switch (this) {
        Season.spring => 1.0,
        Season.summer => 1.0,
        Season.autumn => 1.4,
        Season.winter => 1.0,
      };

  bool get isFrozen => growthMultiplier <= 0;

  Season get next => Season.values[(index + 1) % Season.values.length];
}

/// Gün sayacından mevsim. `dayCount` 1'den başlar → gün 1 ilkbahar.
Season seasonForDay(int dayCount) =>
    Season.values[((dayCount - 1) ~/ kDaysPerSeason) % Season.values.length];

/// Mevsim ilerleyişi 0..1 (mevsim içinde kaçıncı gündeyiz). HUD göstergesi için.
double seasonProgress(int dayCount, double timeOfDay) {
  final dayInSeason = (dayCount - 1) % kDaysPerSeason;
  return (dayInSeason + timeOfDay.clamp(0.0, 1.0)) / kDaysPerSeason;
}
