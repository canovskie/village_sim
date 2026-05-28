import 'dart:math';

/// Bir rastgele köy olayının sonucu. Anlık etkiler ([foodDelta]/[goldDelta])
/// hemen stoğa uygulanır; [moraleModifier] varsa [duration] saniye boyunca
/// köy moraline (ve büyüme hızına) eklenir (+ iyi, − kötü).
class EventOutcome {
  final String title;          // kısa ad (HUD etiketi)
  final String icon;           // emoji
  final String message;        // bildirim metni
  final int    foodDelta;      // anlık yiyecek değişimi
  final int    goldDelta;      // anlık altın değişimi
  final double moraleModifier; // geçici moral etkisi (+/−)
  final double duration;       // moraleModifier kaç sn sürer (0 = anlık)

  const EventOutcome({
    required this.title,
    required this.icon,
    required this.message,
    this.foodDelta = 0,
    this.goldDelta = 0,
    this.moraleModifier = 0,
    this.duration = 0,
  });

  bool get isTemporary => duration > 0 && moraleModifier != 0;
}

/// Periyodik köy olayları. Mevcut yiyecek / altın / moral sistemlerine bağlanır.
class EventSystem {
  static const events = <EventOutcome>[
    EventOutcome(
      title: 'Bereketli Hasat', icon: '🌾',
      message: '🌾 Bereketli hasat! Ambarlara bol yiyecek geldi.',
      foodDelta: 28,
    ),
    EventOutcome(
      title: 'Gezgin Tüccar', icon: '🪙',
      message: '🪙 Gezgin tüccar uğradı — fazla mallar altına çevrildi.',
      goldDelta: 30,
    ),
    EventOutcome(
      title: 'Şenlik', icon: '🎉',
      message: '🎉 Köyde şenlik var! Moral yükseldi.',
      moraleModifier: 0.20, duration: 45,
    ),
    EventOutcome(
      title: 'Kuraklık', icon: '☀',
      message: '☀ Kuraklık bastı — ekinler soldu, moral düştü.',
      foodDelta: -15, moraleModifier: -0.20, duration: 45,
    ),
  ];

  /// Rastgele bir olay seçer.
  static EventOutcome roll(Random rng) => events[rng.nextInt(events.length)];
}
