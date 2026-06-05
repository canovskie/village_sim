import 'dart:math';
import '../world/tree_entity.dart';
import '../core/constants.dart';
import 'worker_entity.dart';

enum LumberCampState { idle, walkingToTree, chopping }

/// Oduncu kulübesiyle bağlantılı akıllı oduncu.
/// Belirlenen bölgede ağaç keser, ağaç azaldığında fidan diker.
class LumberCampEntity extends WorkerEntity {
  final int buildingCol;
  final int buildingRow;

  /// main.dart bu sabiti placement validation için okur.
  /// Asıl değer core/constants.dart içinde tanımlı.
  static const double kTerritoryRadius = kLumberTerritoryRadius;

  LumberCampState state        = LumberCampState.idle;
  double          chopPhase    = 0.0;
  bool            harvestReady = false;
  /// Son kesilen ağacın dünya konumu — kutu buraya spawn edilir
  double          lastHarvestX = 0;
  double          lastHarvestY = 0;
  bool            get isChopping => state == LumberCampState.chopping;

  TreeEntity? _target;
  double      _chopTimer   = 0.0;
  double      _manageTimer = 0.0;

  // Bina 2×2; spawn = footprint'in hemen güneyinde (iso'da ön).
  // Bina artık engel sayıldığı için içinde başlanmamalı.
  LumberCampEntity({required this.buildingCol, required this.buildingRow})
      : super(
          startCol: buildingCol + 1.0,
          startRow: buildingRow + 2.3,
        );

  @override
  double get speed => kLumberCampSpeed;

  /// Dolaşma merkezi: bina merkezi (spawn değil).
  @override
  double get wanderOriginX => buildingCol + 1.0;
  @override
  double get wanderOriginY => buildingRow + 1.0;

  /// Bölgeyi terk etmesin — territory'nin %60'ı.
  @override
  double get wanderRadius => kTerritoryRadius * 0.6;

  bool _inTerritory(TreeEntity t) {
    final cx = buildingCol + 1.0;
    final cy = buildingRow + 1.0;
    final dx = t.col + 0.5 - cx;
    final dy = t.row + 0.5 - cy;
    return dx * dx + dy * dy <= kTerritoryRadius * kTerritoryRadius;
  }

  void update(
    double dt,
    List<TreeEntity> trees,
    Random rng, {
    Set<(int, int)> waterTiles     = const {},
    Set<(int, int)> softObstacles  = const {},
    Set<(int, int)> forbiddenTiles = const {},
  }) {
    harvestReady = false;

    // ── Bölge yönetimi (periyodik) ──────────────────────────────────────────
    _manageTimer -= dt;
    if (_manageTimer <= 0) {
      _manageTrees(trees, rng, waterTiles, forbiddenTiles: forbiddenTiles);
      _manageTimer = kLumberManageMinInterval +
          rng.nextDouble() * (kLumberManageMaxInterval - kLumberManageMinInterval);
    }

    // ── Oduncu davranışı ────────────────────────────────────────────────────
    switch (state) {
      case LumberCampState.idle:
        _findWork(trees);
        if (state == LumberCampState.idle) {
          idleWander(dt, rng, waterTiles, softObstacles);
        }

      case LumberCampState.walkingToTree:
        if (_target == null || _target!.isFelled) {
          _target = null;
          state   = LumberCampState.idle;
          break;
        }
        if (moveTowards(_target!.col + 0.5, _target!.row + 0.5, dt, arriveD: 0.9)) {
          state      = LumberCampState.chopping;
          _chopTimer = 0;
        }

      case LumberCampState.chopping:
        if (_target == null || _target!.isFelled) {
          _target?.chopPhase      = -1;
          _target?.isBeingChopped = false;
          _target   = null;
          state     = LumberCampState.idle;
          chopPhase = 0;
          break;
        }
        _chopTimer += dt;
        chopPhase = (chopPhase + dt * 2 * pi * 1.1) % (2 * pi);
        _target!.chopPhase = chopPhase;

        if (_chopTimer >= kChopDuration) {
          lastHarvestX            = _target!.col.toDouble();
          lastHarvestY            = _target!.row.toDouble();
          _target!.isFelled       = true;
          _target!.isBeingChopped = false;
          _target!.chopPhase      = -1;
          _target      = null;
          state        = LumberCampState.idle;
          harvestReady = true;
          chopPhase    = 0;
        }
    }

    isWalking  = state == LumberCampState.walkingToTree;
    walkPhase += dt * (isWalking ? speed * 5.5 : 1.2);
    walkPhase %= pi * 2;
  }

  // ── Bölge ağaç yönetimi ──────────────────────────────────────────────────

  void _manageTrees(
      List<TreeEntity> trees, Random rng, Set<(int, int)> waterTiles,
      {Set<(int, int)> forbiddenTiles = const {}}) {
    final inZone = trees
        .where((t) => !t.isFelled && _inTerritory(t))
        .toList();

    final grown = inZone.where((t) => !t.isGrowing).toList();

    // İşaretlenebilecek ağaçları işaretle (büyümüş ve sahipsiz)
    int markedCount = grown.where((t) => t.isMarkedForCutting).length;
    for (final t in grown) {
      if (markedCount >= kLumberMaxMarked) break;
      if (!t.isMarkedForCutting && !t.isBeingChopped) {
        t.isMarkedForCutting = true;
        markedCount++;
      }
    }

    // Bölgede (büyüyen dahil) yeterli ağaç yoksa fidan dik
    final totalAlive = inZone.length;
    if (totalAlive < kLumberTargetTrees) {
      _tryPlant(trees, rng, waterTiles, forbiddenTiles: forbiddenTiles);
    }
  }

  void _tryPlant(
      List<TreeEntity> trees, Random rng, Set<(int, int)> waterTiles,
      {Set<(int, int)> forbiddenTiles = const {}}) {
    final cx       = buildingCol + 1.0;
    final cy       = buildingRow + 1.0;
    final occupied = {for (final t in trees) if (!t.isFelled) (t.col, t.row)};

    for (int attempt = 0; attempt < 25; attempt++) {
      final angle = rng.nextDouble() * 2 * pi;
      final dist  = 1.5 + rng.nextDouble() * (kTerritoryRadius - 1.0);
      final col   = (cx + cos(angle) * dist).round();
      final row   = (cy + sin(angle) * dist).round();

      if (col < 1 || row < 1 || col >= kCols - 1 || row >= kRows - 1) continue;
      if (occupied.contains((col, row))) continue;
      if (waterTiles.contains((col, row))) continue;
      if (forbiddenTiles.contains((col, row))) continue;

      trees.add(TreeEntity(col: col, row: row, type: TreeType.pine, isGrowing: true));
      return;
    }
  }

  // ── Hedef bul ────────────────────────────────────────────────────────────

  void _findWork(List<TreeEntity> trees) {
    TreeEntity? nearest;
    double bestDist = double.infinity;
    for (final t in trees) {
      if (!t.isMarkedForCutting || t.isBeingChopped || t.isFelled || t.isGrowing) continue;
      if (!_inTerritory(t)) continue;
      final dx = t.col + 0.5 - gridX;
      final dy = t.row + 0.5 - gridY;
      final d  = dx * dx + dy * dy;
      if (d < bestDist) { bestDist = d; nearest = t; }
    }
    if (nearest == null) return;
    _target               = nearest;
    nearest.isBeingChopped = true;
    state                  = LumberCampState.walkingToTree;
  }
}
