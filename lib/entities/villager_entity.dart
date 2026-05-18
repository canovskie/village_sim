import 'dart:math';
import '../characters/villager_type.dart';
import '../characters/npc_visual.dart';
import '../core/constants.dart';
import 'worker_entity.dart';

enum VillagerState { moving, idle, sleeping, walkingToSleep, walkingToPickup, carrying }

class VillagerEntity extends WorkerEntity {
  final VillagerType type;

  /// Her NPC için kalıcı görsel kimlik — ten/saç/göz/sakal/kıyafet tonu.
  /// Aynı tipten NPC'lerin tıpatıp aynı görünmesini önler.
  final NpcVisual visual;

  int targetCol;
  int targetRow;

  VillagerState state = VillagerState.idle;
  double idleTimer = 0;

  final double speed;

  // Uyku sistemi
  bool _wasSleeping = false;
  /// Nereye gidip uyuyacak (main.dart tarafından her gece atanır)
  (double, double)? sleepTarget;
  /// true → eve girmiş sayılır (render edilmez)
  bool sleepIsHome = false;
  /// Şu an bina içinde mi (gizlenir)
  bool isInsideBuilding = false;
  /// Atanan ev binası (null = evsiz)
  Object? homeBuilding; // BuildingEntity türü, döngüsel import önlemek için Object

  // Porter/carry sistemi
  Object? _pickupItem;           // ResourceBox veya HayEntity
  Object? carriedItem;           // aktif taşıma sırasında görünür
  double _pickupX = 0, _pickupY = 0;
  double _deliverX = 0, _deliverY = 0;
  void Function()? _onDelivered;

  VillagerEntity({
    required this.type,
    required double startCol,
    required double startRow,
    int? visualSeed,
  })  : targetCol = startCol.round(),
        targetRow = startRow.round(),
        speed     = _speedFor(type),
        visual    = NpcVisual.fromSeed(
            visualSeed ?? _autoSeed(type, startCol, startRow)),
        super(startCol: startCol, startRow: startRow);

  /// Otomatik visual seed — type + spawn pozisyonu hash'i.  Aynı pozisyondan
  /// aynı tipte spawn olan iki NPC olmaz pratikte, ama görsel seed verilebilir.
  static int _autoSeed(VillagerType t, double c, double r) =>
      t.index * 7919
      ^ (c * 1009).toInt() * 13
      ^ (r * 1031).toInt() * 31
      ^ DateTime.now().microsecondsSinceEpoch & 0xFFFF;

  bool get isSleeping => state == VillagerState.sleeping;
  bool get isCarrying => state == VillagerState.carrying || state == VillagerState.walkingToPickup;

  void assignCarryTask(Object item, double pickX, double pickY,
      double destX, double destY, {void Function()? onDelivered}) {
    _pickupItem  = item;
    _pickupX     = pickX;
    _pickupY     = pickY;
    _deliverX    = destX;
    _deliverY    = destY;
    _onDelivered = onDelivered;
    state        = VillagerState.walkingToPickup;
    isWalking    = true;
  }

  static double _speedFor(VillagerType t) {
    switch (t) {
      case VillagerType.farmer:     return 1.2;
      case VillagerType.merchant:   return 0.9;
      case VillagerType.blacksmith: return 0.8;
      case VillagerType.guard:      return 1.6;
      case VillagerType.mage:       return 0.7;
      case VillagerType.miner:      return 0.85;
      case VillagerType.fisher:     return 1.1;
    }
  }

  void update(double dt, int gridCols, int gridRows, Random rng,
      {Set<(int, int)> waterTiles  = const {},
       Set<(int, int)> softObstacles = const {},
       double dayLight = 1.0}) {

    // ── Gece/gündüz geçişi ────────────────────────────────────────────────
    final isNight = dayLight < kNightThreshold;
    final isDawn  = dayLight >= kDawnThreshold;

    // ── Porter: finish delivery first even at night ──────────────────────────
    if (state == VillagerState.walkingToPickup) {
      final dx   = _pickupX - gridX;
      final dy   = _pickupY - gridY;
      final dist = sqrt(dx * dx + dy * dy);
      if (dist < 0.25) {
        gridX       = _pickupX;
        gridY       = _pickupY;
        carriedItem = _pickupItem;
        _pickupItem = null;
        state       = VillagerState.carrying;
        isWalking   = false;
      } else {
        final step = speed * dt;
        gridX += (dx / dist) * min(step, dist);
        gridY += (dy / dist) * min(step, dist);
        facingRight = dx > 0;
        isWalking = true;
      }
      walkPhase += dt * (isWalking ? speed * 5.5 : 1.2);
      walkPhase %= pi * 2;
      return;
    }

    if (state == VillagerState.carrying) {
      final dx   = _deliverX - gridX;
      final dy   = _deliverY - gridY;
      final dist = sqrt(dx * dx + dy * dy);
      if (dist < 0.25) {
        gridX = _deliverX;
        gridY = _deliverY;
        _onDelivered?.call();
        _onDelivered = null;
        carriedItem  = null;
        state        = VillagerState.idle;
        idleTimer    = 0.4 + rng.nextDouble() * 1.5;
        isWalking    = false;
      } else {
        final step = speed * dt;
        gridX += (dx / dist) * min(step, dist);
        gridY += (dy / dist) * min(step, dist);
        facingRight = dx > 0;
        isWalking = true;
      }
      walkPhase += dt * (isWalking ? speed * 5.5 : 1.2);
      walkPhase %= pi * 2;
      return;
    }

    if (isNight && !_wasSleeping) {
      _wasSleeping = true;
      if (sleepTarget != null) {
        state     = VillagerState.walkingToSleep;
        isWalking = true;
      } else {
        state     = VillagerState.sleeping;
        isWalking = false;
      }
    } else if (isDawn && _wasSleeping) {
      state               = VillagerState.idle;
      idleTimer           = 1.0 + rng.nextDouble() * 2.0;
      _wasSleeping        = false;
      isInsideBuilding    = false;
    }

    if (state == VillagerState.walkingToSleep) {
      final (tx, ty) = sleepTarget!;
      final dx   = tx - gridX;
      final dy   = ty - gridY;
      final dist = sqrt(dx * dx + dy * dy);
      if (dist < 0.55) {
        gridX = tx; gridY = ty;
        state = VillagerState.sleeping;
        isWalking = false;
        if (sleepIsHome) isInsideBuilding = true;
      } else {
        final step = speed * dt;
        gridX += (dx / dist) * min(step, dist);
        gridY += (dy / dist) * min(step, dist);
        facingRight = dx > 0;
        isWalking   = true;
      }
      walkPhase += dt * (isWalking ? speed * 5.5 : 0.4);
      walkPhase %= pi * 2;
      return;
    }

    if (state == VillagerState.sleeping) {
      walkPhase += dt * 0.4;
      walkPhase %= pi * 2;
      return;
    }

    // ── Normal gündüz davranışı ───────────────────────────────────────────
    switch (state) {
      case VillagerState.idle:
        idleTimer -= dt;
        if (idleTimer <= 0) {
          _pickNewTarget(gridCols, gridRows, rng, waterTiles, softObstacles);
        }

      case VillagerState.moving:
        final dx   = targetCol - gridX;
        final dy   = targetRow - gridY;
        final dist = sqrt(dx * dx + dy * dy);

        if (dist < 0.05) {
          gridX      = targetCol.toDouble();
          gridY      = targetRow.toDouble();
          state      = VillagerState.idle;
          idleTimer  = 0.4 + rng.nextDouble() * 2.1;
        } else {
          final step  = speed * dt;
          final ratio = min(step / dist, 1.0);
          final prevX = gridX;
          gridX += dx * ratio;
          gridY += dy * ratio;
          if (waterTiles.contains((gridX.round(), gridY.round()))) {
            gridX     = prevX;
            gridY    -= (dy / dist) * step * ratio;
            state     = VillagerState.idle;
            idleTimer = 0.1;
            break;
          }
          if (gridX - prevX > 0.001)       facingRight = true;
          else if (gridX - prevX < -0.001) facingRight = false;
        }

      case VillagerState.sleeping:
      case VillagerState.walkingToSleep:
      case VillagerState.walkingToPickup:
      case VillagerState.carrying:
        break; // yukarıda ele alındı
    }

    isWalking  = state == VillagerState.moving;
    walkPhase += dt * (isWalking ? speed * 5.5 : 1.2);
    walkPhase %= pi * 2;
  }

  void _pickNewTarget(int cols, int rows, Random rng,
      Set<(int, int)> waterTiles, Set<(int, int)> softObstacles) {
    const pad    = 1;
    final maxDist = 2 + rng.nextInt(3);

    final result = pickWanderTarget(
      gridX, gridY, maxDist.toDouble(), rng,
      waterTiles:    waterTiles,
      softObstacles: softObstacles,
      minC: pad.toDouble(), minR: pad.toDouble(),
      maxC: (cols - 1 - pad).toDouble(),
      maxR: (rows - 1 - pad).toDouble(),
    );

    if (result != null) {
      targetCol = result.$1.round();
      targetRow = result.$2.round();
      state     = VillagerState.moving;
    } else {
      idleTimer = 0.3 + rng.nextDouble();
    }
  }
}
