import 'dart:math';
import 'nature_entity.dart';
import 'tree_entity.dart';
import 'mine_node.dart';
import '../core/constants.dart';

// ── Result ────────────────────────────────────────────────────────────────────

class WorldGeneratorResult {
  final Set<(int, int)>  waterTiles;
  final List<LotusEntity> lotuses;
  final List<ReedClump>   reeds;
  final List<TreeEntity>  trees;
  final List<MineNode>    mineNodes;

  const WorldGeneratorResult({
    required this.waterTiles,
    required this.lotuses,
    required this.reeds,
    required this.trees,
    required this.mineNodes,
  });
}

// ── Generator ────────────────────────────────────────────────────────────────

class WorldGenerator {
  final int seed;
  late final Random _rng;

  /// Sol-üst başlangıç bölgesi — su ve maden bu alana girmez.
  static const _safeC = 20;
  static const _safeR = 16;

  WorldGenerator(this.seed) {
    _rng = Random(seed);
  }

  WorldGeneratorResult generate() {
    final water    = _generateWater();
    final lotuses  = _generateLotuses(water);
    final reeds    = _generateReeds(water);
    final trees    = _generateTrees(water);
    final treeTiles = {for (final t in trees) (t.col, t.row)};
    final mines    = _generateMines(water, treeTiles);
    return WorldGeneratorResult(
      waterTiles: water,
      lotuses:    lotuses,
      reeds:      reeds,
      trees:      trees,
      mineNodes:  mines,
    );
  }

  // ── Su ──────────────────────────────────────────────────────────────────────

  Set<(int, int)> _generateWater() {
    final tiles = <(int, int)>{};
    final lakeCount = 2 + _rng.nextInt(4); // 2–5 göl

    for (int l = 0; l < lakeCount; l++) {
      // Merkez — başlangıç bölgesinin dışında, kenara çok yakın değil
      int cx, cy;
      int tries = 0;
      do {
        cx = 4 + _rng.nextInt(kCols - 8);
        cy = 3 + _rng.nextInt(kRows - 6);
        tries++;
      } while (tries < 30 && _inSafe(cx, cy, margin: 4));

      if (_inSafe(cx, cy, margin: 4)) continue; // yerleştirilemedi, atla

      final rx = 3.5 + _rng.nextDouble() * 4.0; // 3.5–7.5
      final ry = 2.5 + _rng.nextDouble() * 3.0; // 2.5–5.5

      for (int c = (cx - rx).floor() - 1; c <= (cx + rx).ceil() + 1; c++) {
        for (int r = (cy - ry).floor() - 1; r <= (cy + ry).ceil() + 1; r++) {
          if (c < 1 || c >= kCols - 1 || r < 1 || r >= kRows - 1) continue;
          if (_inSafe(c, r, margin: 2)) continue; // başlangıç bölgesini koru
          final dx    = (c - cx) / rx;
          final dy    = (r - cy) / ry;
          final noise = (_rng.nextDouble() - 0.5) * 0.45;
          if (dx * dx + dy * dy < 1.0 + noise) {
            tiles.add((c, r));
          }
        }
      }
    }
    return tiles;
  }

  bool _inSafe(int c, int r, {int margin = 0}) =>
      c < _safeC - margin && r < _safeR - margin;

  // ── Lotus ───────────────────────────────────────────────────────────────────

  List<LotusEntity> _generateLotuses(Set<(int, int)> water) {
    final result = <LotusEntity>[];
    for (final (c, r) in water) {
      if (!water.contains((c - 1, r)) || !water.contains((c + 1, r)) ||
          !water.contains((c, r - 1)) || !water.contains((c, r + 1))) {
        continue;
      }
      if (_rng.nextDouble() < 0.12) {
        result.add(LotusEntity(col: c, row: r, variant: _rng.nextInt(2)));
      }
    }
    return result;
  }

  // ── Kamışlar ─────────────────────────────────────────────────────────────────

  List<ReedClump> _generateReeds(Set<(int, int)> water) {
    final shore = <(int, int)>{};
    for (final (c, r) in water) {
      for (final (nc, nr) in [(c - 1, r), (c + 1, r), (c, r - 1), (c, r + 1)]) {
        if (!water.contains((nc, nr)) &&
            nc >= 0 && nc < kCols && nr >= 0 && nr < kRows) {
          shore.add((nc, nr));
        }
      }
    }

    final used      = <(int, int)>{};
    final shoreList = shore.toList()..shuffle(_rng);
    final result    = <ReedClump>[];

    for (final (c, r) in shoreList) {
      if (used.contains((c, r))) continue;
      (int, int)? partner;
      if (shore.contains((c + 1, r)) && !used.contains((c + 1, r))) {
        partner = (c + 1, r);
      } else if (shore.contains((c, r + 1)) && !used.contains((c, r + 1))) {
        partner = (c, r + 1);
      }
      if (partner == null) continue;
      final (c2, r2) = partner;
      result.add(ReedClump(col: c, row: r, col2: c2, row2: r2));
      used.add((c, r));
      used.add(partner);
    }
    return result;
  }

  // ── Ağaçlar ──────────────────────────────────────────────────────────────────

  List<TreeEntity> _generateTrees(Set<(int, int)> water) {
    final trees    = <TreeEntity>[];
    final occupied = <(int, int)>{};

    // ── 1. Büyük orman bölgeleri (her biri birden fazla alt küme içerir) ──────
    final forestCount = 4 + _rng.nextInt(3); // 4-6 orman merkezi

    for (int f = 0; f < forestCount; f++) {
      // Orman merkezi
      final fx  = 4 + _rng.nextInt(kCols - 8);
      final fy  = 4 + _rng.nextInt(kRows - 8);

      // Tek tür: çam
      const dominant = TreeType.pine;

      // Orman içinde 2-3 alt küme
      final subCount = 2 + _rng.nextInt(2);
      for (int s = 0; s < subCount; s++) {
        // Alt küme merkezi, orman merkezine yakın
        final spread = 4.0 + _rng.nextDouble() * 5.0;
        final angle  = _rng.nextDouble() * 2 * pi;
        final cx     = (fx + cos(angle) * spread).round().clamp(2, kCols - 3);
        final cy     = (fy + sin(angle) * spread).round().clamp(2, kRows - 3);

        final rad = 2.0 + _rng.nextDouble() * 2.5; // 2.0–4.5 tile yarıçap
        final cnt = 5 + _rng.nextInt(6);            // 5–10 ağaç

        const type = dominant;

        int placed = 0, tries = 0;
        while (placed < cnt && tries < 80) {
          tries++;
          final a = _rng.nextDouble() * 2 * pi;
          final d = _rng.nextDouble() * rad;
          final c = (cx + cos(a) * d).round().clamp(0, kCols - 1);
          final r = (cy + sin(a) * d).round().clamp(0, kRows - 1);
          if (occupied.contains((c, r)) || water.contains((c, r))) continue;
          occupied.add((c, r));
          trees.add(TreeEntity(col: c, row: r, type: type));
          placed++;
        }
      }
    }

    // ── 2. Dağınık münferit ağaç kümeleri (harita geneline serpili) ───────────
    final scatterCount = 8 + _rng.nextInt(5); // 8-12 küçük küme
    for (int i = 0; i < scatterCount; i++) {
      final cx  = 1 + _rng.nextInt(kCols - 2);
      final cy  = 1 + _rng.nextInt(kRows - 2);
      final rad = 1.0 + _rng.nextDouble() * 1.5;
      final cnt = 2 + _rng.nextInt(3); // 2-4 ağaç

      const type = TreeType.pine;

      int placed = 0, tries = 0;
      while (placed < cnt && tries < 40) {
        tries++;
        final a = _rng.nextDouble() * 2 * pi;
        final d = _rng.nextDouble() * rad;
        final c = (cx + cos(a) * d).round().clamp(0, kCols - 1);
        final r = (cy + sin(a) * d).round().clamp(0, kRows - 1);
        if (occupied.contains((c, r)) || water.contains((c, r))) continue;
        occupied.add((c, r));
        trees.add(TreeEntity(col: c, row: r, type: type));
        placed++;
      }
    }

    return trees;
  }

  // ── Madenler ────────────────────────────────────────────────────────────────

  List<MineNode> _generateMines(
      Set<(int, int)> water, Set<(int, int)> treeTiles) {
    final mines    = <MineNode>[];
    final occupied = <(int, int)>{};

    // Taş: 3-4 grup
    final stoneGroups = 3 + _rng.nextInt(2);
    for (int i = 0; i < stoneGroups; i++) {
      _placeGroup(OreType.stone, water, treeTiles, occupied, mines);
    }

    // Demir: 2 grup
    for (int i = 0; i < 2; i++) {
      _placeGroup(OreType.iron, water, treeTiles, occupied, mines);
    }

    // Kömür: 1-2 grup
    final coalGroups = 1 + _rng.nextInt(2);
    for (int i = 0; i < coalGroups; i++) {
      _placeGroup(OreType.coal, water, treeTiles, occupied, mines);
    }

    return mines;
  }

  /// 2×2 kare mine grubu yerleştirir. Her grup tam 4 node içerir,
  /// maden binası (2×2) üstüne tam oturur.
  void _placeGroup(
    OreType type,
    Set<(int, int)> water,
    Set<(int, int)> treeTiles,
    Set<(int, int)> occupied,
    List<MineNode>  out,
  ) {
    for (int attempt = 0; attempt < 60; attempt++) {
      final col = 3 + _rng.nextInt(kCols - 6); // sol-üst köşe
      final row = 3 + _rng.nextInt(kRows - 6);

      // 2×2 bloğun tamamı boş, su yok, ağaç yok, safe zone dışı olmalı
      bool ok = true;
      for (int dc = 0; dc < 2 && ok; dc++) {
        for (int dr = 0; dr < 2 && ok; dr++) {
          final c = col + dc;
          final r = row + dr;
          if (occupied.contains((c, r)) ||
              water.contains((c, r)) ||
              treeTiles.contains((c, r)) ||
              _inSafe(c, r, margin: 2)) {
            ok = false;
          }
        }
      }
      if (!ok) continue;

      // 2×2 bloğa 4 node ekle
      for (int dc = 0; dc < 2; dc++) {
        for (int dr = 0; dr < 2; dr++) {
          final c = col + dc;
          final r = row + dr;
          occupied.add((c, r));
          out.add(MineNode(col: c, row: r, type: type));
        }
      }
      return;
    }
  }
}
