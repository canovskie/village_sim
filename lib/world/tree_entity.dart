enum TreeType { pine }

class TreeEntity {
  final int col;
  final int row;
  final TreeType type;

  bool isMarkedForCutting = false;
  bool isBeingChopped = false;
  bool isFelled = false;

  /// Ekran uzayında devrilme yönü: -1 sol, +1 sağ. Kesimi yapan köylünün
  /// karşı tarafına seçilir; yüklenmiş eski kayıtlarda varsayılan sağdır.
  int fallDirection = 1;

  /// Taç yere değdiğinde yaprak/toz darbesi yalnız bir kez üretilsin.
  bool fallImpactEmitted = false;

  /// isFelled olduktan sonra geçen süre — devrilme animasyonu (tabandan yana
  /// dönerek yatar). scene_tick ilerletir; [kFallDuration] dolunca ağaç kalkar
  /// (wild ise tile açılır). Renderer [fellProgress]'i okur.
  double fellAge = 0.0;
  static const double kFallDuration = 1.15;
  static const double kImpactProgress = 0.82;
  static const double kImpactAge = kFallDuration * kImpactProgress;

  /// −1 = ayakta; 0..1 = devriliyor.
  double get fellProgress =>
      isFelled ? (fellAge / kFallDuration).clamp(0.0, 1.0) : -1.0;

  /// Kesim tamamlandığında ağacı görünür devrilme durumuna geçirir.
  void beginFall({required double awayFromScreenDelta}) {
    isFelled = true;
    isBeingChopped = false;
    isMarkedForCutting = false;
    chopPhase = -1;
    fellAge = 0;
    fallImpactEmitted = false;
    if (awayFromScreenDelta.abs() > 0.01) {
      fallDirection = awayFromScreenDelta < 0 ? -1 : 1;
    } else {
      fallDirection = ((col * 17 + row * 31) & 1) == 0 ? 1 : -1;
    }
  }

  /// Vahşi sınır ağacı mı? Harita başta yoğun ormanla kaplıdır; köy küçük bir
  /// açıklıkta başlar. Sınır halkasındaki ağaçlar [isWild]=true — kesilince o
  /// tile "açılır" (yerleşilebilir kara olur) ve orman içeri doğru çekilir.
  /// İç orman entity'siz kanopi olarak çizilir; yalnız sınır gerçek ağaç tutar.
  /// Oduncu kulübesinin diktiği fidanlar [isWild]=false (sürdürülebilir koru).
  bool isWild;

  double chopPhase = -1.0;

  // ── Fidan büyümesi ────────────────────────────────────────────────────────
  // Oduncu kulübesi tarafından dikilen fidanlar 0..kGrowDuration saniyede
  // tam boyuta ulaşır.  Büyüme bitmeden kesilemezler.
  static const double kGrowDuration = 50.0;

  double _growthTimer;

  TreeEntity({
    required this.col,
    required this.row,
    required this.type,
    bool isGrowing = false,
    this.isWild = false,
  }) : _growthTimer = isGrowing ? 0.0 : kGrowDuration;

  bool get isGrowing => _growthTimer < kGrowDuration;

  /// 0.25 = yeni fidan, 1.0 = tam gelişmiş
  double get growthScale => (_growthTimer / kGrowDuration).clamp(0.25, 1.0);

  void update(double dt) {
    if (isGrowing) _growthTimer += dt;
  }

  double get depth => (col + row + 1).toDouble();
}
