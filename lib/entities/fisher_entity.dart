import 'dart:math';
import '../core/constants.dart';
import 'worker_entity.dart';

enum FisherState { idle, walkingToShore, fishing }

class FisherEntity extends WorkerEntity {
  FisherState state     = FisherState.idle;
  double      fishPhase = 0.0; // 0..2π, olta salınımı

  bool harvestReady = false;

  static const int goldPerCatch = 15;

  double _shoreCol  = -1;
  double _shoreRow  = -1;
  double _fishTimer = 0.0;

  FisherEntity({required double startCol, required double startRow})
      : super(startCol: startCol, startRow: startRow);

  @override
  double get speed => kFisherSpeed;

  /// Balıkçı diğerlerinden biraz daha hızlı dolaşır.
  @override
  double get idleSpeedFactor => 0.5;

  /// Daha sık hedef yenile — kıyıyı arıyor.
  @override
  (double, double) get idleIntervalRange => (2.0, 5.0);

  bool get isFishing => state == FisherState.fishing;

  void update(double dt, Random rng,
      {required Set<(int, int)> waterTiles,
       Set<(int, int)> softObstacles = const {}}) {
    harvestReady = false;

    switch (state) {
      case FisherState.idle:
        idleWander(dt, rng, waterTiles, softObstacles);
        // Yakın kıyı tile'ı ara (su'ya komşu kara tile)
        final shore = _findNearestShore(waterTiles);
        if (shore != null) {
          _shoreCol = shore.$1.toDouble();
          _shoreRow = shore.$2.toDouble();
          state     = FisherState.walkingToShore;
        }

      case FisherState.walkingToShore:
        if (moveTowards(_shoreCol, _shoreRow, dt, arriveD: 0.1)) {
          // Kesin konuma snap — animasyon stabil olsun.
          gridX      = _shoreCol;
          gridY      = _shoreRow;
          state      = FisherState.fishing;
          _fishTimer = 0;
          fishPhase  = 0;
          // Suya bak — yüzü su tarafına çevir
          facingRight = _shoreCol < gridX + 1;
        }

      case FisherState.fishing:
        _fishTimer += dt;
        fishPhase = (fishPhase + dt * 2 * pi * 0.8) % (2 * pi);
        if (_fishTimer >= kFishDuration) {
          state        = FisherState.idle;
          harvestReady = true;
          fishPhase    = 0;
        }
    }

    final moving = state == FisherState.walkingToShore;
    walkPhase = (walkPhase + dt * (moving ? 6.5 : 1.5)) % (2 * pi);
  }

  /// Su'ya komşu, su olmayan en yakın tile'ı bul.
  (int, int)? _findNearestShore(Set<(int, int)> waterTiles) {
    if (waterTiles.isEmpty) return null;
    (int, int)? best;
    double bestDist = double.infinity;
    for (final (wc, wr) in waterTiles) {
      for (final (nc, nr) in [(wc-1,wr),(wc+1,wr),(wc,wr-1),(wc,wr+1)]) {
        if (waterTiles.contains((nc, nr))) continue; // su değil, kıyı
        final dx = nc - gridX;
        final dy = nr - gridY;
        final d  = dx * dx + dy * dy;
        if (d < bestDist) { bestDist = d; best = (nc, nr); }
      }
    }
    return best;
  }
}
