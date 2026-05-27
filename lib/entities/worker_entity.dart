import 'dart:math';
import '../core/constants.dart';

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
  /// Eski API — BuilderEntity ve VillagerEntity hâlâ kullanır.
  void moveTo(double tx, double ty, double step) {
    final dx   = tx - gridX;
    final dy   = ty - gridY;
    final dist = sqrt(dx * dx + dy * dy);
    if (dist < 0.01) return;
    final ratio = min(step / dist, 1.0);
    final prevX = gridX;
    gridX += dx * ratio;
    gridY += dy * ratio;
    facingRight = gridX >= prevX;
  }

  /// Hedefe `speed * dt` adımla ilerle. arriveD altına düşünce true döner —
  /// alt sınıf state geçişi için kullanır.
  bool moveTowards(double tx, double ty, double dt, {double arriveD = 0.08}) {
    final dx   = tx - gridX;
    final dy   = ty - gridY;
    final dist = sqrt(dx * dx + dy * dy);
    if (dist <= arriveD) return true;
    final step = (speed * dt).clamp(0.0, dist);
    gridX += (dx / dist) * step;
    gridY += (dy / dist) * step;
    facingRight = dx > 0;
    return false;
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
