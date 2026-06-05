import 'dart:math';
import '../core/constants.dart';
import '../farm/farm_tile.dart';
import '../systems/anchor_system.dart';
import 'worker_entity.dart';

enum FarmerState {
  idle,
  walkingToFarm,
  harvesting,
  walkingToWell,
  fetchingWater,
  walkingToWater,
  watering,
}

class FarmFarmer extends WorkerEntity {
  FarmerState state       = FarmerState.idle;
  double      harvestPhase = 0.0;

  bool harvestReady = false;

  /// Set when a harvest completes — main.dart reads and spawns a HayEntity.
  (int, int)? harvestHayPos;

  @override
  double get speed => kFarmerSpeed;

  static const double harvestTime     = kFarmHarvestDuration;
  static const double _waterFetchTime = kFarmWaterFetchTime;
  static const double _waterTime      = kFarmWaterTime;

  FarmTile? _target;
  double    _harvestTimer = 0.0;

  bool   hasWater       = false;
  double _waterTimer    = 0.0;

  /// Render katmanı için _waterTimer'a public erişim (splash animasyonu).
  double get waterTimerForSplash => _waterTimer;
  double _waterCooldown = 0.0; // seconds until next water run

  double _wellX = -1, _wellY = -1;
  AnchorPoint? _wellPoint;
  AnchorSlot?  _wellSlot;
  FarmTile? _waterTarget;

  double _idleTimer    = 0.0;
  double _idleTargetX = -1;
  double _idleTargetY = -1;
  final double _homeCol;
  final double _homeRow;

  FarmFarmer({required super.startCol, required super.startRow})
      : _homeCol = startCol,
        _homeRow = startRow;

  bool get isMoving => state == FarmerState.walkingToFarm ||
      state == FarmerState.walkingToWell ||
      state == FarmerState.walkingToWater;
  bool get isCarryingWater => hasWater;

  /// Su işiyle meşgul mü — kuyuya gidiyor / su alıyor / sulamaya gidiyor /
  /// suluyor. Render bu sürede çiftçinin eline su kovası çizer.
  bool get isHandlingWater =>
      state == FarmerState.walkingToWell ||
      state == FarmerState.fetchingWater ||
      state == FarmerState.walkingToWater ||
      state == FarmerState.watering;

  void update(double dt, List<FarmTile> tiles, Random rng,
      {Set<(int, int)> waterTiles    = const {},
       Set<(int, int)> softObstacles = const {},
       AnchorSystem? anchorSystem}) {
    harvestReady  = false;
    harvestHayPos = null;

    _waterCooldown -= dt;

    switch (state) {
      case FarmerState.idle:
        _idleWander(dt, rng, waterTiles, softObstacles);

        // Sulama turu: cooldown bitti, erişilebilir kuyu slot'u var ve
        // sulanacak (büyüyen) ekin var. Anchor sistemi en yakın BOŞ slot'u
        // verir — birden çok çiftçi aynı kuyuda farklı yönlerden yaklaşır.
        if (_waterCooldown <= 0 &&
            anchorSystem != null &&
            anchorSystem.wellPoints.isNotEmpty &&
            tiles.any((t) => t.isGrowing)) {
          final claim = anchorSystem.claimNearestWell(gridX, gridY, this);
          if (claim != null) {
            final dx = claim.$2.col - gridX;
            final dy = claim.$2.row - gridY;
            if (dx * dx + dy * dy <=
                kFarmWellMaxDistance * kFarmWellMaxDistance) {
              _waterCooldown = kFarmWaterCooldown;
              _wellPoint = claim.$1;
              _wellSlot  = claim.$2;
              _wellX = claim.$2.col;
              _wellY = claim.$2.row;
              state  = FarmerState.walkingToWell;
              _idleTimer = 0;
              break;
            } else {
              // Slot uzakta; iade et, bir sonraki idle'da tekrar dene.
              claim.$1.release(claim.$2, this);
            }
          }
        }

        // Harvest search
        FarmTile? best;
        double bestD = double.infinity;
        for (final t in tiles) {
          if (!t.readyToHarvest || t.beingHarvested) continue;
          final dx = t.col + 0.5 - gridX;
          final dy = t.row + 0.5 - gridY;
          final d  = dx * dx + dy * dy;
          if (d < bestD) { bestD = d; best = t; }
        }
        if (best != null) {
          _target             = best;
          best.beingHarvested = true;
          state               = FarmerState.walkingToFarm;
          _idleTimer          = 0;
        }

      case FarmerState.walkingToFarm:
        if (_target == null) { state = FarmerState.idle; break; }
        if (_moveTowards(_target!.col + 0.5, _target!.row + 0.5, dt)) {
          state         = FarmerState.harvesting;
          _harvestTimer = 0.0;
        }

      case FarmerState.harvesting:
        _harvestTimer += dt;
        harvestPhase = (harvestPhase + dt * 2 * pi * 1.4) % (2 * pi);
        if (_harvestTimer >= harvestTime) {
          final hCol = _target?.col ?? gridX.round();
          final hRow = _target?.row ?? gridY.round();
          _target?.harvest();
          _target      = null;
          state        = FarmerState.idle;
          harvestReady = true;
          harvestPhase = 0;
          harvestHayPos = (hCol, hRow);
        }

      case FarmerState.walkingToWell:
        if (_moveTowards(_wellX, _wellY, dt)) {
          state       = FarmerState.fetchingWater;
          _waterTimer = 0.0;
        }

      case FarmerState.fetchingWater:
        _waterTimer += dt;
        if (_waterTimer >= _waterFetchTime) {
          hasWater    = true;
          state       = FarmerState.idle; // will find a crop to water next idle
          _waterTimer = 0.0;
          // Slot serbest — başka çiftçi gelebilir.
          if (_wellSlot != null && _wellPoint != null) {
            _wellPoint!.release(_wellSlot!, this);
            _wellSlot  = null;
            _wellPoint = null;
          }
          // Hemen sulanacak (büyüyen) en yakın ekini bul
          FarmTile? waterTarget;
          double    wBestD = double.infinity;
          for (final t in tiles) {
            if (!t.isGrowing) continue; // hasada hazır / hasat edilen ekini atla
            final dx = t.col + 0.5 - gridX;
            final dy = t.row + 0.5 - gridY;
            final d  = dx * dx + dy * dy;
            if (d < wBestD) { wBestD = d; waterTarget = t; }
          }
          if (waterTarget != null && hasWater) {
            _waterTarget = waterTarget;
            state        = FarmerState.walkingToWater;
          }
        }

      case FarmerState.walkingToWater:
        if (_waterTarget == null) { state = FarmerState.idle; break; }
        if (_moveTowards(_waterTarget!.col + 0.5, _waterTarget!.row + 0.5, dt)) {
          state       = FarmerState.watering;
          _waterTimer = 0.0;
        }

      case FarmerState.watering:
        _waterTimer += dt;
        if (_waterTimer >= _waterTime) {
          // Kova bir yamayı sular: hedef + yakın büyüyen ekinler 2x hızlanır.
          if (_waterTarget != null) {
            final cx = _waterTarget!.col + 0.5;
            final cy = _waterTarget!.row + 0.5;
            const r2 = kFarmWaterSplashRadius * kFarmWaterSplashRadius;
            for (final t in tiles) {
              if (!t.isGrowing) continue;
              final dx = t.col + 0.5 - cx;
              final dy = t.row + 0.5 - cy;
              if (dx * dx + dy * dy <= r2) {
                t.boostGrowth(kFarmWaterBoostDuration);
              }
            }
          }
          _waterTarget = null;
          hasWater     = false;
          state        = FarmerState.idle;
          _waterTimer  = 0.0;
        }
    }

    // isWalking → moveIntensity (smoothMotion) → idle↔yürüyüş karışımı.
    // walkPhase tam 2π döngüsünde sarılır (önceden %1.0 idi → sin() döngüyü
    // hiç tamamlamıyordu, çiftçi yürürken bacaksız kayıyordu).
    isWalking = isMoving;
    walkPhase += dt * (isWalking ? speed * 5.5 : 1.2);
    walkPhase %= 2 * pi;
  }

  void _idleWander(double dt, Random rng,
      Set<(int, int)> waterTiles, Set<(int, int)> softObstacles) {
    _idleTimer -= dt;
    if (_idleTimer <= 0) {
      final result = pickWanderTarget(
        _homeCol, _homeRow, 3.0, rng,
        waterTiles: waterTiles,
        softObstacles: softObstacles,
        minC: 0.0,
        minR: 0.0,
      );
      if (result != null) {
        _idleTargetX = result.$1;
        _idleTargetY = result.$2;
      }
      _idleTimer = 3 + rng.nextDouble() * 4;
    }
    final prevX = gridX;
    _moveTowards(_idleTargetX, _idleTargetY, dt * 0.5);
    if (waterTiles.contains((gridX.round(), gridY.round()))) {
      gridX = prevX;
      _idleTimer = 0.1;
    }
    // walkPhase güncellemesi artık update() sonunda tek yerde (tam 2π döngüsü).
  }

  /// [true] döner = hedefe ulaştı. Path-aware: base moveTowards uzak hedefte
  /// A* waypoint'lerini izler, kısa hop'larda doğrudan adım. Varışta snap.
  bool _moveTowards(double tx, double ty, double dt) {
    if (moveTowards(tx, ty, dt, arriveD: 0.08)) {
      gridX = tx;
      gridY = ty;
      return true;
    }
    return false;
  }
}
