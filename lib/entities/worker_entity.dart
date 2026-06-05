import 'dart:math';
import '../core/constants.dart';
import '../systems/path_context.dart';
import '../systems/pathfinder.dart';
import '../systems/road_system.dart';

/// Tüm çalışan NPC'lerin paylaştığı hareket ve dolaşma mantığı.
///
/// Alt sınıflar (Woodcutter, Miner, Fisher, LumberCamp ...) yalnızca kendi
/// state machine'lerini ve görev hedefi seçimini yazar.  Yürüme, dolaşma,
/// su-pushback ve hedefe gitme akışı burada şablonlanır.
///
/// Override noktaları:
///   - [speed]            : zorunlu — tile/sn cinsinden ana hız
///   - [wanderOriginX/Y]  : dolaşma merkezi (varsayılan: spawn noktası)
///   - [wanderRadius]     : dolaşma yarıçapı (tile)
///   - [idleSpeedFactor]  : idle hareket hızı (normal hızın çarpanı)
///   - [idleIntervalRange]: idle hedef yenileme aralığı (saniye)
abstract class WorkerEntity {
  /// Tek otorite — main.dart init'inde set edilir. moveTo/moveTowards üstünde
  /// yürünen tile road ise hızı çarpar (taş +%30, toprak/köprü +%15).
  /// null ise (henüz set edilmemiş test ortamı) etkisiz.
  static RoadSystem? roadSystem;

  /// A* path-aware hareket için ortak otorite. main.dart bir kez set eder.
  /// null ise pathing devre dışı — moveTo/moveTowards eski (düz çizgi)
  /// davranışına döner. World version değişimi cached path'leri invalidate
  /// eder; pathing kısa hop'larda (< 3 tile) atlanır (idle wander vb.).
  static PathContext? pathContext;

  // ── Per-entity path cache ──────────────────────────────────────────────────
  // _path: tile waypoint sırası (start dahil değil, goal dahil).
  // _pathIdx: işlenen sonraki waypoint indeksi.
  // _pathGoalC/R: en son hedef tile — değişirse path recompute.
  // _pathVersion: hesaplandığında pathContext.version değeri — eskirse recompute.
  List<(int, int)>? _path;
  int _pathIdx     = 0;
  int _pathGoalC   = -999;
  int _pathGoalR   = -999;
  int _pathVersion = -1;

  double gridX;
  double gridY;
  bool   facingRight = true;
  double walkPhase   = 0.0;
  bool   isWalking   = false;

  /// AI gridX/Y'yi takip eden yumuşatılmış render pozisyonu.
  /// AI hassas tile-snap yaparken render lerp ile akıcı kalır.
  double renderX;
  double renderY;

  /// 0..1 — isWalking'e doğru exp-lerp olan sürekli hareket yoğunluğu.
  /// Walking ↔ idle animasyonu arasında smooth blend için kullanılır.
  double moveIntensity = 0.0;

  /// İlk doğum koordinatı — varsayılan dolaşma merkezi.
  final double spawnCol;
  final double spawnRow;

  // ── Idle wander state (idleWander tarafından yönetilir) ────────────────────
  double _idleTargetX = -1;
  double _idleTargetY = -1;
  double _idleTimer   = 0;

  // ── İş arama throttle ──────────────────────────────────────────────────────
  double _workSearchCd = 0.0;

  /// Boştaki işçinin her frame tüm hedef listesini taramasını engeller.
  /// ~[kWorkSearchInterval]'de bir true döner; aradaki frame'lerde işçi
  /// yalnızca dolaşır. İş anında lazım değilse bu gecikme görünmez.
  bool readyToSearchWork(double dt) {
    _workSearchCd -= dt;
    if (_workSearchCd > 0) return false;
    _workSearchCd = kWorkSearchInterval;
    return true;
  }

  WorkerEntity({required double startCol, required double startRow})
      : gridX    = startCol,
        gridY    = startRow,
        renderX  = startCol,
        renderY  = startRow,
        spawnCol = startCol,
        spawnRow = startRow;

  /// Her tick ana loop çağırır.  Render pozisyonu ve hareket yoğunluğunu
  /// günceller.
  /// - Render exp-smoothing: ~0.15 sn'de gridX/Y'ye yetişir
  /// - moveIntensity: 0.20 sn'de isWalking'e yetişir
  void smoothMotion(double dt) {
    final kPos  = 1 - exp(-dt * 14.0);
    renderX += (gridX - renderX) * kPos;
    renderY += (gridY - renderY) * kPos;

    final targetIntensity = isWalking ? 1.0 : 0.0;
    final kInt = 1 - exp(-dt * 8.0);
    moveIntensity += (targetIntensity - moveIntensity) * kInt;
  }

  double get depth => gridX + gridY;

  /// Tile/sn cinsinden ana hareket hızı. Alt sınıf override eder.
  double get speed;

  /// Dolaşma bölgesi merkezi — varsayılan spawn noktası.
  /// LumberCamp gibi sabit bölgeli işçiler bina merkezini döner.
  double get wanderOriginX => spawnCol;
  double get wanderOriginY => spawnRow;

  /// Dolaşma yarıçapı (tile).
  double get wanderRadius => 3.0;

  /// Idle modunda hız çarpanı — normal hızın yüzdesi.
  /// 0.4 = sakin yürüme; balıkçı/çiftçi 0.5 kullanır.
  double get idleSpeedFactor => 0.4;

  /// Idle hedef yenileme aralığı (min, max) saniye.
  (double, double) get idleIntervalRange => (3.0, 7.0);

  /// Hedefe `step` kadar ilerle (saniyeden bağımsız mutlak adım).
  /// Path-aware: uzak hedef (≥ 3 tile) için A* waypoint dizisi izlenir;
  /// kısa hedefler ve pathContext yokken doğrudan vektör adımı.
  void moveTo(double tx, double ty, double step) {
    final dx   = tx - gridX;
    final dy   = ty - gridY;
    final dist = sqrt(dx * dx + dy * dy);
    if (dist < 0.01) return;
    final next = _nextWaypoint(tx, ty, dist);
    _stepFixed(next.$1, next.$2, step);
  }

  /// Hedefe `speed * dt` adımla ilerle. arriveD altına düşünce true döner —
  /// alt sınıf state geçişi için kullanır. Path-aware (bkz. moveTo).
  bool moveTowards(double tx, double ty, double dt, {double arriveD = 0.08}) {
    final dx   = tx - gridX;
    final dy   = ty - gridY;
    final dist = sqrt(dx * dx + dy * dy);
    if (dist <= arriveD) return true;
    final next = _nextWaypoint(tx, ty, dist);
    _stepDt(next.$1, next.$2, dt);
    return false;
  }

  /// (tx, ty) gerçek hedef; dönüş: bir SONRAKİ adımın hedefi (waypoint ya
  /// da true goal). Kısa mesafe / no-context → doğrudan true goal.
  (double, double) _nextWaypoint(double tx, double ty, double dist) {
    final ctx = pathContext;
    if (ctx == null || dist < 3.0) return (tx, ty);

    _ensurePath(tx, ty, ctx);
    final path = _path;
    if (path == null || path.isEmpty) return (tx, ty);

    // Yaklaşılmış waypoint'leri atla (NPC drift'inde geri dönme yok).
    while (_pathIdx < path.length) {
      final wp  = path[_pathIdx];
      final wpx = wp.$1 + 0.5;
      final wpy = wp.$2 + 0.5;
      final wd  = sqrt((wpx - gridX) * (wpx - gridX) +
                       (wpy - gridY) * (wpy - gridY));
      if (wd < 0.30) {
        _pathIdx++;
        continue;
      }
      return (wpx, wpy);
    }
    // Path tükendi — sub-tile presizyon için true goal'a yönel.
    return (tx, ty);
  }

  void _ensurePath(double tx, double ty, PathContext ctx) {
    final goalC = tx.round();
    final goalR = ty.round();
    final myC   = gridX.round();
    final myR   = gridY.round();

    final goalChanged  = goalC != _pathGoalC || goalR != _pathGoalR;
    final versionStale = _pathVersion != ctx.version;
    final pathExhausted = _path == null || _pathIdx >= (_path?.length ?? 0);

    if (!goalChanged && !versionStale && !pathExhausted) return;

    _pathGoalC   = goalC;
    _pathGoalR   = goalR;
    _pathVersion = ctx.version;
    // findPath başlangıcı içermez, hedef tile'ı içerir.
    _path = Pathfinder.findPath(myC, myR, goalC, goalR, ctx.costAt, ctx.blocked);
    _pathIdx = 0;
  }

  void _stepFixed(double tx, double ty, double step) {
    final dx   = tx - gridX;
    final dy   = ty - gridY;
    final dist = sqrt(dx * dx + dy * dy);
    if (dist < 0.01) return;
    final boost = roadSystem?.speedMultiplierAt(gridX, gridY) ?? 1.0;
    final ratio = min(step * boost / dist, 1.0);
    final prevX = gridX;
    gridX += dx * ratio;
    gridY += dy * ratio;
    facingRight = gridX >= prevX;
  }

  void _stepDt(double tx, double ty, double dt) {
    final dx   = tx - gridX;
    final dy   = ty - gridY;
    final dist = sqrt(dx * dx + dy * dy);
    if (dist < 0.001) return;
    final boost = roadSystem?.speedMultiplierAt(gridX, gridY) ?? 1.0;
    final step = (speed * boost * dt).clamp(0.0, dist);
    gridX += (dx / dist) * step;
    gridY += (dy / dist) * step;
    facingRight = dx > 0;
  }

  /// Boştayken rasgele bir hedefe doğru yavaşça yürür.
  /// Su/soft engele girilirse geri çekilir.  Yeni hedef [idleIntervalRange]
  /// aralığında bir süre sonra seçilir.
  void idleWander(double dt, Random rng,
      Set<(int, int)> waterTiles,
      Set<(int, int)> softObstacles) {
    _idleTimer -= dt;
    if (_idleTimer <= 0) {
      final result = pickWanderTarget(
        wanderOriginX, wanderOriginY, wanderRadius, rng,
        waterTiles:    waterTiles,
        softObstacles: softObstacles,
      );
      if (result != null) {
        _idleTargetX = result.$1;
        _idleTargetY = result.$2;
      }
      final (lo, hi) = idleIntervalRange;
      _idleTimer = lo + rng.nextDouble() * (hi - lo);
    }
    final prevX = gridX;
    moveTowards(_idleTargetX, _idleTargetY, dt * idleSpeedFactor);
    if (waterTiles.contains((gridX.round(), gridY.round()))) {
      gridX      = prevX;
      _idleTimer = 0.1;
    }
  }

  /// İki geçişli wander hedefi seçimi:
  ///  1. Önce soft engelsiz tile dene.
  ///  2. Bulunamazsa sadece su'dan kaçın (fallback).
  (double, double)? pickWanderTarget(
    double homeCol,
    double homeRow,
    double radius,
    Random rng, {
    required Set<(int, int)> waterTiles,
    Set<(int, int)> softObstacles = const {},
    double minC = 1.0,
    double minR = 1.0,
    double maxC = -1,
    double maxR = -1,
  }) {
    final mC = maxC < 0 ? (kCols - 2).toDouble() : maxC;
    final mR = maxR < 0 ? (kRows - 2).toDouble() : maxR;

    for (int i = 0; i < 8; i++) {
      final tx = (homeCol + rng.nextDouble() * radius * 2 - radius).clamp(minC, mC);
      final ty = (homeRow + rng.nextDouble() * radius * 2 - radius).clamp(minR, mR);
      if (waterTiles.contains((tx.round(), ty.round()))) continue;
      if (softObstacles.contains((tx.round(), ty.round()))) continue;
      return (tx, ty);
    }
    for (int i = 0; i < 8; i++) {
      final tx = (homeCol + rng.nextDouble() * radius * 2 - radius).clamp(minC, mC);
      final ty = (homeRow + rng.nextDouble() * radius * 2 - radius).clamp(minR, mR);
      if (waterTiles.contains((tx.round(), ty.round()))) continue;
      return (tx, ty);
    }
    return null;
  }
}
