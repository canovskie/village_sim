class FarmTile {
  final int col, row;

  int    stage          = 0;   // 0=toprak … 4=hasat hazır
  double growthProgress = 0.0; // 0.0–1.0, mevcut aşama içinde

  bool beingHarvested = false;

  /// Aşama başına büyüme süresi (saniye). 4 aşama × 10 sn = 40 sn/hasat.
  /// Huzurlu tempo — ekin yavaş yeşerir, çiftçi koşturmaz. Saman yığınları
  /// harmanda 6'lı dönüşür: 6 hasat = 1 balya = 6 yiyecek (hay_processor).
  static const double growthTimePerStage = 10.0;

  FarmTile(this.col, this.row);

  bool get readyToHarvest => stage >= 4;
  bool get isGrowing      => stage < 4 && !beingHarvested;

  void update(double dt) {
    if (_waterBoostRemaining > 0) _waterBoostRemaining -= dt;
    if (!isGrowing) return;
    final rate = _waterBoostRemaining > 0 ? 2.0 : 1.0;
    growthProgress += dt * rate / growthTimePerStage;
    if (growthProgress >= 1.0) {
      growthProgress = 0.0;
      stage = (stage + 1).clamp(0, 4);
    }
  }

  /// Çiftçi hasadı tamamladığında çağrılır → tile sıfırlanır.
  void harvest() {
    stage          = 0;
    growthProgress = 0.0;
    beingHarvested = false;
  }

  /// Sulama ile büyüme hızını artır ([seconds] saniyelik 2x bonus).
  /// Üst üste binen sulamalar süreyi uzatır (kısaltmaz).
  double _waterBoostRemaining = 0.0;

  void boostGrowth([double seconds = 5.0]) {
    if (seconds > _waterBoostRemaining) _waterBoostRemaining = seconds;
  }

  bool get isWatered => _waterBoostRemaining > 0;

  double get depth => (col + row).toDouble();
}
