import '../world/season.dart';

class FarmTile {
  final int col, row;

  int    stage          = 0;   // 0=toprak … 4=hasat hazır
  double growthProgress = 0.0; // 0.0–1.0, mevcut aşama içinde

  bool beingHarvested = false;

  /// Aşama başına büyüme süresi (saniye). 4 aşama × 25 sn = 100 sn/hasat.
  /// Bilinçli YAVAŞ tempo — eski 40 sn fazla hızlı yiyecek seli yapıyordu;
  /// cozy hasat için 2.5× yavaşlatıldı (sulu 50 sn, yaz ~74 sn). Saman
  /// yığınları harmanda 6'lı dönüşür: 6 hasat = 1 balya = 6 yiyecek
  /// (hay_processor).
  static const double growthTimePerStage = 25.0;

  FarmTile(this.col, this.row);

  bool get readyToHarvest => stage >= 4;
  bool get isGrowing      => stage < 4 && !beingHarvested;

  void update(double dt, Season season) {
    if (_waterBoostRemaining > 0) _waterBoostRemaining -= dt;
    if (!isGrowing) return;
    // Kış: tarla donar, ekin uykuda — büyüme yok (sulama da boost vermez).
    final seasonMult = season.growthMultiplier;
    if (seasonMult <= 0) return;
    final watered = _waterBoostRemaining > 0;
    // Sulama 2x; susuz ekin yazın kuraklık cezası yer.
    double rate = watered ? 2.0 : season.unwateredPenalty;
    growthProgress += dt * rate * seasonMult / growthTimePerStage;
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
