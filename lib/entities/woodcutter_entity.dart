import 'dart:math';
import '../core/constants.dart';
import '../world/tree_entity.dart';
import 'worker_entity.dart';

enum WoodcutterState { idle, walkingToTree, chopping }

class WoodcutterEntity extends WorkerEntity {
  WoodcutterState state = WoodcutterState.idle;
  double chopPhase  = 0.0; // 0..2π, balta sallanma için

  TreeEntity? _target;
  double      _chopTimer = 0.0;

  /// Hasat tamamlandığında bir kare true kalır (parent kutuyu spawn eder).
  bool   harvestReady = false;
  double lastHarvestX = 0;
  double lastHarvestY = 0;

  WoodcutterEntity({required super.startCol, required super.startRow});

  @override
  double get speed => kWoodcutterSpeed;

  bool get isChopping => state == WoodcutterState.chopping;

  void update(double dt, List<TreeEntity> trees, Random rng,
      {Set<(int, int)> waterTiles    = const {},
       Set<(int, int)> softObstacles = const {}}) {
    harvestReady = false;

    switch (state) {
      case WoodcutterState.idle:
        if (readyToSearchWork(dt)) _findWork(trees);
        if (state == WoodcutterState.idle) {
          idleWander(dt, rng, waterTiles, softObstacles);
        }

      case WoodcutterState.walkingToTree:
        if (_target == null || _target!.isFelled) {
          _target = null;
          state   = WoodcutterState.idle;
          break;
        }
        // Ağacın hemen yanına git (0.9 tile).
        if (moveTowards(_target!.col + 0.5, _target!.row + 0.5, dt, arriveD: 0.9)) {
          state      = WoodcutterState.chopping;
          _chopTimer = 0;
        }

      case WoodcutterState.chopping:
        if (_target == null || _target!.isFelled) {
          if (_target != null) {
            _target!.chopPhase      = -1;
            _target!.isBeingChopped = false;
          }
          _target   = null;
          state     = WoodcutterState.idle;
          chopPhase = 0;
          break;
        }
        _chopTimer += dt;
        // Bağımsız döngü: 1.1 darbe/sn — renderer chopPhase'i okur.
        chopPhase = (chopPhase + dt * 2 * pi * 1.1) % (2 * pi);
        _target!.chopPhase = chopPhase;
        if (_chopTimer >= kChopDuration) {
          lastHarvestX            = _target!.col.toDouble();
          lastHarvestY            = _target!.row.toDouble();
          _target!.isFelled       = true;
          _target!.isBeingChopped = false;
          _target!.chopPhase      = -1;
          _target                 = null;
          state                   = WoodcutterState.idle;
          harvestReady            = true;
          chopPhase               = 0;
        }
    }

    // isWalking → moveIntensity (smoothMotion) → idle↔yürüyüş animasyon karışımı.
    isWalking = state == WoodcutterState.walkingToTree;
    walkPhase += dt * (isWalking ? speed * 5.5 : 1.2);
    walkPhase %= pi * 2;
  }

  void _findWork(List<TreeEntity> trees) {
    TreeEntity? nearest;
    double bestDist = double.infinity;
    for (final t in trees) {
      if (!t.isMarkedForCutting || t.isBeingChopped || t.isFelled) continue;
      final dx = t.col + 0.5 - gridX;
      final dy = t.row + 0.5 - gridY;
      final d  = dx * dx + dy * dy;
      if (d < bestDist) { bestDist = d; nearest = t; }
    }
    if (nearest == null) return;
    _target               = nearest;
    nearest.isBeingChopped = true;
    state                  = WoodcutterState.walkingToTree;
  }
}
