import 'dart:math';
import '../buildings/building_entity.dart';
import '../buildings/building_type.dart';
import '../core/constants.dart';
import '../systems/road_system.dart';
import '../world/road_surface.dart';
import '../world/road_tile.dart';
import 'build_order.dart';
import 'road_order.dart';
import 'worker_entity.dart';

enum BuilderState { idle, walkingToSite, building }

class BuilderEntity extends WorkerEntity {
  BuilderState state = BuilderState.idle;

  // Aynı anda yalnız biri set; idle'dan iki kuyruktan birinden iş çekilir.
  BuildOrder? currentBuildOrder;
  RoadOrder?  currentRoadOrder;

  double buildTimer = 0;

  // Order claim'de hesaplanıp walkingToSite boyunca kullanılır
  double _targetX = 0;
  double _targetY = 0;

  // Wandering when idle
  int _wanderTargetCol;
  int _wanderTargetRow;
  double _wanderIdleTimer = 0;

  @override
  double get speed => kBuilderSpeed;
  static const double wanderSpeed = kBuilderWanderSpeed;

  BuilderEntity({required super.startCol, required super.startRow})
      : _wanderTargetCol = startCol.round(),
        _wanderTargetRow = startRow.round();

  void update(double dt,
      List<BuildOrder> orders,
      List<RoadOrder> roadOrders,
      List<BuildingEntity> buildings,
      RoadSystem roadSystem,
      Random rng,
      {Set<(int, int)> waterTiles    = const {},
       Set<(int, int)> softObstacles = const {}}) {
    switch (state) {
      case BuilderState.idle:
        // Binalar önce — büyük yatırım, kullanıcı bekliyordur
        for (final o in orders) {
          if (!o.assigned && !o.completed) {
            o.assigned = true;
            currentBuildOrder = o;
            final meta = kBuildingMeta[o.type]!;
            _targetX = (o.col + meta.cols).toDouble();
            _targetY = (o.row + meta.rows).toDouble();
            state = BuilderState.walkingToSite;
            break;
          }
        }
        // Sonra yollar
        if (state == BuilderState.idle) {
          for (final o in roadOrders) {
            if (!o.assigned && !o.completed) {
              o.assigned = true;
              currentRoadOrder = o;
              if (o.surface == RoadSurface.woodBridge) {
                final (tx, ty) = _adjacentLand(o.col, o.row, waterTiles);
                _targetX = tx;
                _targetY = ty;
              } else {
                _targetX = o.col + 0.5;
                _targetY = o.row + 0.5;
              }
              state = BuilderState.walkingToSite;
              break;
            }
          }
        }
        if (state == BuilderState.idle) {
          _wander(dt, rng, waterTiles, softObstacles);
        }
        break;

      case BuilderState.walkingToSite:
        moveTo(_targetX, _targetY, speed * dt);
        if ((gridX - _targetX).abs() < 0.15 && (gridY - _targetY).abs() < 0.15) {
          gridX = _targetX;
          gridY = _targetY;
          state = BuilderState.building;
          buildTimer = 0;
        }
        break;

      case BuilderState.building:
        buildTimer += dt;
        if (currentBuildOrder != null) {
          final o = currentBuildOrder!;
          final duration = _durationFor(o.type);
          o.progress = (buildTimer / duration).clamp(0.0, 1.0);
          if (buildTimer >= duration) {
            o.completed = true;
            buildings.add(BuildingEntity(type: o.type, col: o.col, row: o.row));
            currentBuildOrder = null;
            state = BuilderState.idle;
            _wanderIdleTimer = 1.0;
          }
        } else if (currentRoadOrder != null) {
          final r = currentRoadOrder!;
          final duration = r.surface.buildDuration;
          r.progress = (buildTimer / duration).clamp(0.0, 1.0);
          if (buildTimer >= duration) {
            r.completed = true;
            roadSystem.add(RoadTile(col: r.col, row: r.row, surface: r.surface));
            currentRoadOrder = null;
            state = BuilderState.idle;
            _wanderIdleTimer = 0.5;
          }
        } else {
          // Safety: bir şekilde order yokken building state'e düştüysek geri dön
          state = BuilderState.idle;
        }
        break;
    }

    final phaseRate = switch (state) {
      BuilderState.walkingToSite => speed * 5.5,
      BuilderState.building      => 4.0,
      BuilderState.idle          => isWalking ? wanderSpeed * 5.5 : 1.2,
    };
    walkPhase = (walkPhase + dt * phaseRate) % (pi * 2);
  }

  /// Köprü inşa ederken builder kara üstünde durmalı. (col, row)'un 4
  /// komşusundan ilk kara olanın merkezini döner. canPlace bridge'i kara
  /// komşusuz suya koymayı önleyici değil — bulamazsa kendi center'ı.
  (double, double) _adjacentLand(int col, int row, Set<(int, int)> waterTiles) {
    const dirs = [(0, -1), (1, 0), (0, 1), (-1, 0)];
    for (final (dc, dr) in dirs) {
      final nc = col + dc;
      final nr = row + dr;
      if (!waterTiles.contains((nc, nr))) {
        return (nc + 0.5, nr + 0.5);
      }
    }
    return (col + 0.5, row + 0.5);
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
    return 1.0 + tiles * 0.5;
  }
}
