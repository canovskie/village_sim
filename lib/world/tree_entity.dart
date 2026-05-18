enum TreeType { pine }

class TreeEntity {
  final int      col;
  final int      row;
  final TreeType type;

  bool isMarkedForCutting = false;
  bool isBeingChopped     = false;
  bool isFelled           = false;

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
  }) : _growthTimer = isGrowing ? 0.0 : kGrowDuration;

  bool   get isGrowing    => _growthTimer < kGrowDuration;
  /// 0.25 = yeni fidan, 1.0 = tam gelişmiş
  double get growthScale  => (_growthTimer / kGrowDuration).clamp(0.25, 1.0);

  void update(double dt) {
    if (isGrowing) _growthTimer += dt;
  }

  double get depth => (col + row + 1).toDouble();
}
