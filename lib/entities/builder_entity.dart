import 'dart:math';
import '../buildings/building_entity.dart';
import '../buildings/building_type.dart';
import '../core/constants.dart';
import 'build_order.dart';
import 'worker_entity.dart';

enum BuilderState { idle, walkingToSite, building }

class BuilderEntity extends WorkerEntity {
  BuilderState state = BuilderState.idle;
  BuildOrder? currentOrder;
  double buildTimer = 0;

  // Wandering when idle
  int _wanderTargetCol;
  int _wanderTargetRow;
  double _wanderIdleTimer = 0;

  @override
  double get speed => kBuilderSpeed;
  static const double wanderSpeed = kBuilderWanderSpeed;

  BuilderEntity({required double startCol, required double startRow})
      : _wanderTargetCol = startCol.round(),
        _wanderTargetRow = startRow.round(),
        super(startCol: startCol, startRow: startRow);

  void update(double dt, List<BuildOrder> orders, List<BuildingEntity> buildings, Random rng,
      {Set<(int, int)> waterTiles    = const {},
       Set<(int, int)> softObstacles = const {}}) {
    switch (state) {
      case BuilderState.idle:
        // Try to claim an unassigned order
        BuildOrder? unassigned;
        for (final o in orders) {
          if (!o.assigned && !o.completed) { unassigned = o; break; }
        }
        if (unassigned != null) {
          unassigned.assigned = true;
          currentOrder = unassigned;
          state = BuilderState.walkingToSite;
        } else {
          _wander(dt, rng, waterTiles, softObstacles);
        }
        break;

      case BuilderState.walkingToSite:
        final o = currentOrder!;
        final meta = kBuildingMeta[o.type]!;
        // Walk to the front corner of the building footprint
        final tx = (o.col + meta.cols).toDouble();
        final ty = (o.row + meta.rows).toDouble();
        moveTo(tx, ty, speed * dt);

        if ((gridX - tx).abs() < 0.15 && (gridY - ty).abs() < 0.15) {
          gridX = tx;
          gridY = ty;
          state = BuilderState.building;
          buildTimer = 0;
        }
        break;

      case BuilderState.building:
        final o = currentOrder!;
        final duration = _durationFor(o.type);
        buildTimer += dt;
        o.progress = (buildTimer / duration).clamp(0.0, 1.0);

        if (buildTimer >= duration) {
          o.completed = true;
          buildings.add(BuildingEntity(type: o.type, col: o.col, row: o.row));
          currentOrder = null;
          state = BuilderState.idle;
          _wanderIdleTimer = 1.0;
        }
        break;
    }

    // Advance walk phase
    final phaseRate = switch (state) {
      BuilderState.walkingToSite => speed * 5.5,
      BuilderState.building      => 4.0,   // hammering cadence
      BuilderState.idle          => isWalking ? wanderSpeed * 5.5 : 1.2,
    };
    walkPhase = (walkPhase + dt * phaseRate) % (pi * 2);
  }

  void _wander(double dt, Random rng,
      Set<(int, int)> waterTiles, Set<(int, int)> softObstacles) {
    _wanderIdleTimer -= dt;

    final dx = _wanderTargetCol - gridX;
    final dy = _wanderTargetRow - gridY;
    final dist = sqrt(dx * dx + dy * dy);

    if (dist < 0.1) {
      isWalking = false;
      if (_wanderIdleTimer <= 0) {
        final result = pickWanderTarget(
          gridX, gridY, 2.5, rng,
          waterTiles: waterTiles,
          softObstacles: softObstacles,
        );
        if (result != null) {
          _wanderTargetCol = result.$1.round();
          _wanderTargetRow = result.$2.round();
        }
        _wanderIdleTimer = 0.5 + rng.nextDouble() * 1.5;
      }
    } else {
      isWalking = true;
      final prevX = gridX;
      moveTo(_wanderTargetCol.toDouble(), _wanderTargetRow.toDouble(), wanderSpeed * dt);
      if (waterTiles.contains((gridX.round(), gridY.round()))) {
        gridX = prevX;
        _wanderIdleTimer = 0.1;
        isWalking = false;
      }
    }
  }

  static double _durationFor(BuildingType t) {
    final meta = kBuildingMeta[t]!;
    final tiles = meta.cols * meta.rows;
    return 1.0 + tiles * 0.5; // 1x1=1.5s, 2x2=3s  (hızlı test modu)
  }
}
