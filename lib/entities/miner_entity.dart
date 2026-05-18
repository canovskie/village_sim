import 'dart:math';
import '../core/constants.dart';
import '../world/mine_node.dart';
import 'worker_entity.dart';

enum MinerState { idle, walkingToMine, mining }

class MinerEntity extends WorkerEntity {
  MinerState state     = MinerState.idle;
  double     chopPhase = 0.0; // 0..2π, darbe animasyonu

  MineNode? _target;
  double    _mineTimer = 0.0;

  bool     harvestReady = false;
  OreType? lastOreType;
  double   lastHarvestX = 0;
  double   lastHarvestY = 0;

  MinerEntity({required double startCol, required double startRow})
      : super(startCol: startCol, startRow: startRow);

  @override
  double get speed => kMinerSpeed;

  bool get isMining => state == MinerState.mining;

  void update(double dt, List<MineNode> nodes, Random rng,
      {Set<(int, int)> waterTiles    = const {},
       Set<(int, int)> softObstacles = const {}}) {
    harvestReady = false;

    switch (state) {
      case MinerState.idle:
        _findWork(nodes);
        if (state == MinerState.idle) {
          idleWander(dt, rng, waterTiles, softObstacles);
        }

      case MinerState.walkingToMine:
        if (_target == null || _target!.isDepleted) {
          _clearTarget();
          state = MinerState.idle;
          break;
        }
        if (moveTowards(_target!.col + 0.5, _target!.row + 0.5, dt, arriveD: 0.8)) {
          state      = MinerState.mining;
          _mineTimer = 0;
          chopPhase  = 0;
        }

      case MinerState.mining:
        if (_target == null || _target!.isDepleted) {
          _clearTarget();
          state = MinerState.idle;
          break;
        }
        _mineTimer += dt;
        chopPhase = (chopPhase + dt * 2 * pi * 1.0) % (2 * pi);
        _target!.chopPhase = chopPhase;

        if (_mineTimer >= _target!.type.mineTime) {
          lastOreType            = _target!.type;
          lastHarvestX           = _target!.col.toDouble();
          lastHarvestY           = _target!.row.toDouble();
          _target!.isDepleted    = true;
          _target!.isBeingMined  = false;
          _target!.chopPhase     = -1;
          _target                = null;
          state                  = MinerState.idle;
          harvestReady           = true;
          chopPhase              = 0;
        }
    }

    final moving = state == MinerState.walkingToMine;
    walkPhase += dt * (moving ? speed * 5.5 : 1.2);
    walkPhase %= pi * 2;
  }

  void _findWork(List<MineNode> nodes) {
    MineNode? nearest;
    double bestDist = double.infinity;
    for (final n in nodes) {
      if (!n.isMarkedForMining || n.isBeingMined || n.isDepleted) continue;
      final dx = n.col + 0.5 - gridX;
      final dy = n.row + 0.5 - gridY;
      final d  = dx * dx + dy * dy;
      if (d < bestDist) { bestDist = d; nearest = n; }
    }
    if (nearest == null) return;
    _target              = nearest;
    nearest.isBeingMined = true;
    state                = MinerState.walkingToMine;
  }

  void _clearTarget() {
    if (_target != null) {
      _target!.chopPhase    = -1;
      _target!.isBeingMined = false;
    }
    _target   = null;
    chopPhase = 0;
  }
}
