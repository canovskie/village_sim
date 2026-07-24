import '../core/constants.dart';
import '../world/season.dart';

class FarmTile {
  final int col, row;

  int    stage          = 0;   // 0=toprak … 4=hasat hazır
  double growthProgress = 0.0; // 0.0–1.0, mevcut aşama içinde

  bool beingHarvested = false;

  /// Tarla ekilmeyi bekliyor — çiftçi gelip tohum atmadan ekin büyümez.
  /// Yeni açılan tarla ve hasat edilmiş tarla bu durumda başlar; döngü
  /// **ekim → büyüme → hasat → (nadas) → ekim** şeklinde kapanır.
  bool needsSowing = true;
  bool beingSown   = false;

  /// Nadas: hasat sonrası toprağın dinlendiği süre (saniye). Yalnız Dönemli
  /// Ekim Beratı yürürlükteyse dolu gelir — tarla bir süre çıplak durur,
  /// karşılığında balya verimi artar (bkz. scene_tick baleYieldMultiplier).
  double fallowRemaining = 0.0;

  /// Aşama başına büyüme süresi (saniye). 4 aşama × 25 sn = 100 sn/hasat.
  /// Bilinçli YAVAŞ tempo — eski 40 sn fazla hızlı yiyecek seli yapıyordu;
  /// cozy hasat için 2.5× yavaşlatıldı (sulu ~67 sn, yaz susuz ~165 sn). Saman
  /// yığınları harmanda [kHayPilesPerBale]'li dönüşür: 6 hasat = 1 balya.
  static const double growthTimePerStage = 25.0;

  FarmTile(this.col, this.row);

  bool get readyToHarvest => stage >= 4;
  bool get isGrowing =>
      !needsSowing && stage < 4 && !beingHarvested;

  /// Çiftçi bu tarlayı ekebilir mi — ekim bekliyor, kimse üstünde değil ve
  /// nadas süresi dolmuş.
  bool get readyToSow =>
      needsSowing && !beingSown && fallowRemaining <= 0;

  void update(double dt, Season season) {
    if (_waterBoostRemaining > 0) _waterBoostRemaining -= dt;
    // Nadas kışın da işler — toprak donmuş olsa da dinlenmiş sayılır.
    if (fallowRemaining > 0) fallowRemaining -= dt;
    if (!isGrowing) return;
    // Kış: tarla donar, ekin uykuda — büyüme yok (sulama da boost vermez).
    final seasonMult = season.growthMultiplier;
    if (seasonMult <= 0) return;
    final watered = _waterBoostRemaining > 0;
    // Sulama kuraklığı iptal eder ve üstüne hız katar; susuz ekin yazın
    // kuraklık cezası yer. (Çarpanlar için bkz. kFarmWaterGrowthRate.)
    final double rate =
        watered ? kFarmWaterGrowthRate : season.unwateredPenalty;
    growthProgress += dt * rate * seasonMult / growthTimePerStage;
    if (growthProgress >= 1.0) {
      growthProgress = 0.0;
      stage = (stage + 1).clamp(0, 4);
    }
  }

  /// Politika kancası (müşterek harman): büyümeyi doğrudan itele/geri çek.
  /// [update] yerine bunu kullan — su sayacını ve nadası tüketmez.
  void nudgeGrowth(double delta) {
    if (!isGrowing) return;
    growthProgress += delta;
    if (growthProgress >= 1.0) {
      growthProgress = 0.0;
      stage = (stage + 1).clamp(0, 4);
    } else if (growthProgress < 0.0) {
      growthProgress = 0.0;
    }
  }

  /// Çiftçi tohumu attığında çağrılır → ekin büyümeye başlar.
  void sow() {
    needsSowing     = false;
    beingSown       = false;
    stage           = 0;
    growthProgress  = 0.0;
    fallowRemaining = 0.0;
  }

  /// Çiftçi hasadı tamamladığında çağrılır → tile çıplak toprağa döner ve
  /// yeniden ekilmeyi bekler. [fallowSeconds] > 0 ise önce toprak dinlenir.
  void harvest({double fallowSeconds = 0.0}) {
    stage           = 0;
    growthProgress  = 0.0;
    beingHarvested  = false;
    needsSowing     = true;
    beingSown       = false;
    fallowRemaining = fallowSeconds;
  }

  /// Sulama ile büyüme hızını artır ([seconds] saniyelik bonus).
  /// Üst üste binen sulamalar süreyi uzatır (kısaltmaz).
  double _waterBoostRemaining = 0.0;

  void boostGrowth([double seconds = 5.0]) {
    if (seconds > _waterBoostRemaining) _waterBoostRemaining = seconds;
  }

  bool get isWatered => _waterBoostRemaining > 0;
}
