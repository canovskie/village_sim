// İmparatorluk (dış tehdit) — vergici askerî heyetin talebi. Köy zenginleştikçe
// dikkat çeker (koşullu ritim). Pazarlık/anlaşma sağlanmazsa şiddet yaşanır;
// anlaşmak her zaman daha avantajlı. İmparatorlukla ilişki (_imperialFavor)
// pazarlık şansını ve talebin sertliğini belirler.

enum ImperialDemandKind { goldTax, foodLevy, woodLevy, conscript }

/// Fiziksel asker heyetinin ziyaret evresi (bkz. scene_imperial `_tickImperial`).
///   - [idle]        : heyet yok; sayaç sıradaki ziyareti bekler.
///   - [approaching] : harita kenarından köy eşiğine formasyonla yürüyorlar
///                     (sim AKAR; oyuncu yaklaşan kolonu görür). Varınca pazarlık.
///   - [parley]      : eşikte dizilip beklerler; talep modalı/sinematiği açık
///                     (sim DURUR). Oyuncu karar verince ayrılışa geçer.
///   - [raiding]     : reddedildi/direniş ezildi → askerler köy MERKEZİNE dalar;
///                     varışta "darbe" (kurbanlar çöker + sarsıntı + kızıl tint),
///                     kısa bekleyiş, sonra ayrılışa geçer. Şiddetin görünür anı.
///   - [leaving]     : geldikleri köşeye geri yürürler; varınca despawn → idle.
enum ImperialVisitPhase { idle, approaching, parley, raiding, leaving }

class ImperialDemand {
  final ImperialDemandKind kind;
  /// goldTax/foodLevy/woodLevy → miktar; conscript → 1 (bir genç).
  final int amount;
  const ImperialDemand(this.kind, this.amount);

  bool get isConscript => kind == ImperialDemandKind.conscript;

  String get icon => switch (kind) {
        ImperialDemandKind.goldTax => '★',
        ImperialDemandKind.foodLevy => '🌾',
        ImperialDemandKind.woodLevy => '🪵',
        ImperialDemandKind.conscript => '🧑',
      };

  /// Talebin tam karşılığının okunur özeti.
  String get label => switch (kind) {
        ImperialDemandKind.goldTax => '$amount altın vergi',
        ImperialDemandKind.foodLevy => '$amount yiyecek',
        ImperialDemandKind.woodLevy => '$amount kereste',
        ImperialDemandKind.conscript => 'bir genç (askere devşirme)',
      };
}

/// İmparatorluğun zümre nabzındaki salt-okunur özeti — köyün İÇ zümrelerinin
/// (bkz. [HouseSnapshot]) yanına eklenen DIŞ güç madalyonu. İç hizip değil:
/// köye dışarıdan bakan bir göz. [favor] ilişki (0 düşman ↔ 1 dost), [watching]
/// köy İmparatorluğun iştahını çekecek kadar zengin/kalabalık mı (değilse heyet
/// gözden ırak/uykuda), [imminence] sıradaki ziyaretin yakınlığı (0 uzak ↔ 1
/// kapıda), [active] şu an aktif bir talep var mı.
class ImperialSnapshot {
  final double favor;
  final bool watching;
  final double imminence;
  final bool active;
  const ImperialSnapshot({
    required this.favor,
    required this.watching,
    required this.imminence,
    required this.active,
  });

  /// İlişkinin okunur kısa etiketi (madalyon altı durum sözcüğü).
  String get favorLabel {
    if (favor < 0.30) return 'düşman';
    if (favor < 0.50) return 'gergin';
    if (favor < 0.72) return 'temkinli';
    return 'dost';
  }
}
