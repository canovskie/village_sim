import 'dart:math';
import '../world/animal_entity.dart';
import 'worker_entity.dart';

enum ShepherdState { idle, walkingToCow, milking }

/// Ağıla bağlı çoban: hazır bir ineği bulup sağar.
/// Sağım bitince harvestReady=true ve lastHarvestX/Y inek konumuna düşer —
/// main.dart bunu okuyup yiyecek kutusu spawn eder (taşıyıcı sonra depoya getirir).
class ShepherdEntity extends WorkerEntity {
  final int barnCol;
  final int barnRow;

  ShepherdState state = ShepherdState.idle;
  double milkPhase    = 0.0;

  AnimalEntity? _target;
  double        _milkTimer = 0.0;

  bool   harvestReady = false;
  double lastHarvestX = 0;
  double lastHarvestY = 0;

  // Ağıl 3×2; spawn = footprint'in hemen güneyinde (iso'da ön).
  // Bina engel sayıldığı için içeride başlanmamalı.
  ShepherdEntity({required this.barnCol, required this.barnRow})
      : super(
          startCol: barnCol + 1.5,
          startRow: barnRow + 2.3,
        );

  @override
  double get speed => 2.3;

  @override
  double get wanderOriginX => barnCol + 1.5;
  @override
  double get wanderOriginY => barnRow + 1.0;

  @override
  double get wanderRadius => 3.0;

  static const double _milkDuration = 6.0;

  bool get isMilking => state == ShepherdState.milking;

  void update(double dt, List<AnimalEntity> animals, Random rng,
      {Set<(int, int)> waterTiles    = const {},
       Set<(int, int)> softObstacles = const {}}) {
    harvestReady = false;

    switch (state) {
      case ShepherdState.idle:
        if (readyToSearchWork(dt)) _findWork(animals);
        if (state == ShepherdState.idle) {
          idleWander(dt, rng, waterTiles, softObstacles);
        }

      case ShepherdState.walkingToCow:
        if (_target == null || !_target!.isBeingMilked) {
          _target = null;
          state = ShepherdState.idle;
          break;
        }
        if (moveTowards(_target!.gridX, _target!.gridY, dt, arriveD: 0.6)) {
          state = ShepherdState.milking;
          _milkTimer = 0.0;
          milkPhase  = 0.0;
        }

      case ShepherdState.milking:
        if (_target == null) {
          state = ShepherdState.idle;
          break;
        }
        _milkTimer += dt;
        milkPhase = (milkPhase + dt * 2 * pi * 1.0) % (2 * pi);

        if (_milkTimer >= _milkDuration) {
          lastHarvestX = _target!.gridX;
          lastHarvestY = _target!.gridY;
          _target!.onMilked();
          _target = null;
          state = ShepherdState.idle;
          harvestReady = true;
          milkPhase = 0.0;
        }
    }

    isWalking = state == ShepherdState.walkingToCow;
    walkPhase += dt * (isWalking ? speed * 5.5 : 1.2);
    walkPhase %= 2 * pi;
  }

  void _findWork(List<AnimalEntity> animals) {
    AnimalEntity? nearest;
    double bestDist = double.infinity;
    for (final a in animals) {
      if (!a.readyToMilk) continue;
      // Yalnız bu çobanın ağılındaki ineklerle ilgilen.
      if (a.barnCol != barnCol || a.barnRow != barnRow) continue;
      final dx = a.gridX - gridX;
      final dy = a.gridY - gridY;
      final d  = dx * dx + dy * dy;
      if (d < bestDist) { bestDist = d; nearest = a; }
    }
    if (nearest == null) return;
    _target = nearest;
    nearest.isBeingMilked = true;
    state = ShepherdState.walkingToCow;
  }
}
