import 'dart:math';
import 'nature_entity.dart';
import 'tree_entity.dart';
import 'mine_node.dart';
import 'decor_entity.dart';
import '../core/constants.dart';

// ── Result ────────────────────────────────────────────────────────────────────

class WorldGeneratorResult {
  final Set<(int, int)> waterTiles;
  final List<LotusEntity> lotuses;
  final List<ReedClump> reeds;
  final List<TreeEntity> trees;
  final List<MineNode> mineNodes;
  final List<DecorEntity> decor;

  const WorldGeneratorResult({
    required this.waterTiles,
    required this.lotuses,
    required this.reeds,
    required this.trees,
    required this.mineNodes,
    required this.decor,
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

  /// Haritanın baz alana (48×36) göre alan oranı — entity sayıları bununla
  /// ölçeklenir. Büyük haritada daha çok orman/maden, küçük haritada daha az.
  /// min 1.0 — küçük haritada bile orijinal yoğunluk korunur.
  double get _areaScale {
    const baseArea = 48.0 * 36.0;
    final s = (kCols * kRows) / baseArea;
    return s < 1.0 ? 1.0 : s;
  }

  /// [lo..hi] aralığında int çek, sonra alan oranıyla ölçekle (min 1).
  int _scaledRange(int lo, int hi) {
    final base = lo + _rng.nextInt(hi - lo + 1);
    final v = (base * _areaScale).round();
    return v < 1 ? 1 : v;
  }

  WorldGeneratorResult generate() {
    final water = _generateWater();
    final lotuses = _generateLotuses(water);
    final reeds = _generateReeds(water);
    // Reed clump tile'larını topla — ağaç bunlara spawn etmesin (çakışma).
    final reedTiles = <(int, int)>{};
    for (final r in reeds) {
      reedTiles.add((r.col, r.row));
      reedTiles.add((r.col2, r.row2));
    }
    final trees = _generateTrees(water, reedTiles);
    final treeTiles = {for (final t in trees) (t.col, t.row)};
    final mines = _generateMines(water, treeTiles);
    final mineTiles = {for (final m in mines) (m.col, m.row)};
    final decor = _generateDecor(water, treeTiles, mineTiles, reedTiles);
    return WorldGeneratorResult(
      waterTiles: water,
      lotuses: lotuses,
      reeds: reeds,
      trees: trees,
      mineNodes: mines,
      decor: decor,
    );
  }

  // ── Su ──────────────────────────────────────────────────────────────────────

  Set<(int, int)> _generateWater() {
    final tiles = <(int, int)>{};
    final lakeCount = _scaledRange(2, 5); // alan ile ölçekli

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
          final dx = (c - cx) / rx;
          final dy = (r - cy) / ry;
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
      if (!water.contains((c - 1, r)) ||
          !water.contains((c + 1, r)) ||
          !water.contains((c, r - 1)) ||
          !water.contains((c, r + 1))) {
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
            nc >= 0 &&
            nc < kCols &&
            nr >= 0 &&
            nr < kRows) {
          shore.add((nc, nr));
        }
      }
    }

    final used = <(int, int)>{};
    final shoreList = shore.toList()..shuffle(_rng);
    final result = <ReedClump>[];

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

  List<TreeEntity> _generateTrees(
    Set<(int, int)> water,
    Set<(int, int)> reedTiles,
  ) {
    final trees = <TreeEntity>[];
    final occupied = <(int, int)>{};

    // ── 1. Büyük orman bölgeleri (her biri birden fazla alt küme içerir) ──────
    final forestCount = _scaledRange(4, 6); // 4-6 baz, alan ile ölçekli

    for (int f = 0; f < forestCount; f++) {
      // Orman merkezi
      final fx = 4 + _rng.nextInt(kCols - 8);
      final fy = 4 + _rng.nextInt(kRows - 8);

      // Tek tür: çam
      const dominant = TreeType.pine;

      // Orman içinde 2-3 alt küme
      final subCount = 2 + _rng.nextInt(2);
      for (int s = 0; s < subCount; s++) {
        // Alt küme merkezi, orman merkezine yakın
        final spread = 4.0 + _rng.nextDouble() * 5.0;
        final angle = _rng.nextDouble() * 2 * pi;
        final cx = (fx + cos(angle) * spread).round().clamp(2, kCols - 3);
        final cy = (fy + sin(angle) * spread).round().clamp(2, kRows - 3);

        final rad = 2.0 + _rng.nextDouble() * 2.5; // 2.0–4.5 tile yarıçap
        final cnt = 5 + _rng.nextInt(6); // 5–10 ağaç

        const type = dominant;

        int placed = 0, tries = 0;
        while (placed < cnt && tries < 80) {
          tries++;
          final a = _rng.nextDouble() * 2 * pi;
          final d = _rng.nextDouble() * rad;
          final c = (cx + cos(a) * d).round().clamp(0, kCols - 1);
          final r = (cy + sin(a) * d).round().clamp(0, kRows - 1);
          if (occupied.contains((c, r)) ||
              water.contains((c, r)) ||
              reedTiles.contains((c, r))) {
            continue;
          }
          occupied.add((c, r));
          trees.add(TreeEntity(col: c, row: r, type: type));
          placed++;
        }
      }
    }

    // ── 2. Dağınık münferit ağaç kümeleri (harita geneline serpili) ───────────
    final scatterCount = _scaledRange(8, 12); // 8-12 baz, alan ile ölçekli
    for (int i = 0; i < scatterCount; i++) {
      final cx = 1 + _rng.nextInt(kCols - 2);
      final cy = 1 + _rng.nextInt(kRows - 2);
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
        if (occupied.contains((c, r)) ||
            water.contains((c, r)) ||
            reedTiles.contains((c, r))) {
          continue;
        }
        occupied.add((c, r));
        trees.add(TreeEntity(col: c, row: r, type: type));
        placed++;
      }
    }

    return trees;
  }

  // ── Madenler ────────────────────────────────────────────────────────────────

  List<MineNode> _generateMines(
    Set<(int, int)> water,
    Set<(int, int)> treeTiles,
  ) {
    final mines = <MineNode>[];
    final occupied = <(int, int)>{};

    // Taş: 3-4 grup baz, alan ile ölçekli
    final stoneGroups = _scaledRange(3, 4);
    for (int i = 0; i < stoneGroups; i++) {
      _placeGroup(OreType.stone, water, treeTiles, occupied, mines);
    }

    // Demir: 2-3 grup baz, alan ile ölçekli
    final ironGroups = _scaledRange(2, 3);
    for (int i = 0; i < ironGroups; i++) {
      _placeGroup(OreType.iron, water, treeTiles, occupied, mines);
    }

    // Kömür: 1-2 grup baz, alan ile ölçekli
    final coalGroups = _scaledRange(1, 2);
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
    List<MineNode> out,
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

  // ── Decor ───────────────────────────────────────────────────────────────────
  /// Çimene serpiştirilen pure-visual dekor. Hedef: "doğal landmark" hissi —
  /// her yere serpilmiş gereksiz kalabalık DEĞİL. Tile yoğunluğu düşük tutulur
  /// ve dekor öncelikli olarak landmark komşu tile'larına yerleştirilir
  /// (ağaç çevresine mantar/kütük, su kıyısına yonca/çalı/çiçek), bu da daha
  /// "yaşayan doğa" hissi verir. Su / ağaç / maden / saz tile'larına spawn
  /// etmez. Her tile en fazla 1 dekor.
  List<DecorEntity> _generateDecor(
    Set<(int, int)> water,
    Set<(int, int)> treeTiles,
    Set<(int, int)> mineTiles,
    Set<(int, int)> reedTiles,
  ) {
    final decor = <DecorEntity>[];
    final occupied = <(int, int)>{};

    bool tileFree(int c, int r) =>
        c >= 0 && c < kCols && r >= 0 && r < kRows &&
        !water.contains((c, r)) &&
        !treeTiles.contains((c, r)) &&
        !mineTiles.contains((c, r)) &&
        !reedTiles.contains((c, r)) &&
        !occupied.contains((c, r));

    // Landmark adjacency helpers — tile'ın 8-komşusunda ağaç/su var mı?
    bool nearLandmark(int c, int r, Set<(int, int)> landmark) {
      for (int dc = -1; dc <= 1; dc++) {
        for (int dr = -1; dr <= 1; dr++) {
          if (dc == 0 && dr == 0) continue;
          if (landmark.contains((c + dc, r + dr))) return true;
        }
      }
      return false;
    }

    DecorEntity makeDecor(int c, int r, DecorKind kind, int variantCount) =>
        DecorEntity(
          col: c,
          row: r,
          kind: kind,
          variant: _rng.nextInt(variantCount),
          jitterX: (_rng.nextDouble() - 0.5) * 0.5,
          jitterY: (_rng.nextDouble() - 0.5) * 0.5,
          swaySeed: _rng.nextInt(1000),
        );

    // Bias: probability  ağaç/su komşusu olan tile'larda yüksek; uzakta düşük.
    // Iki kez sample edip max alıyoruz → bias'lı reservoir-style accept/reject.
    void scatterBiased(
      DecorKind kind,
      int count,
      int variantCount, {
      double treeBias = 0.0,
      double waterBias = 0.0,
    }) {
      int tries = 0;
      int placed = 0;
      while (placed < count && tries < count * 12) {
        tries++;
        final c = _rng.nextInt(kCols);
        final r = _rng.nextInt(kRows);
        if (!tileFree(c, r)) continue;
        // Bias kabul olasılığı: landmark yakınsa daha yüksek
        double acceptP = 0.35; // base — uzak alanlarda nadir
        if (treeBias > 0 && nearLandmark(c, r, treeTiles)) {
          acceptP += treeBias;
        }
        if (waterBias > 0 && nearLandmark(c, r, water)) {
          acceptP += waterBias;
        }
        if (_rng.nextDouble() > acceptP.clamp(0.0, 1.0)) continue;
        occupied.add((c, r));
        decor.add(makeDecor(c, r, kind, variantCount));
        placed++;
      }
    }

    // Hedef sayılar baz 48×36 için; alan ölçeği ile büyür. Eskisine göre
    // ~%75 azaltıldı — "düzenlenmiş köy" hissi için sparse landmark dağılım.
    int n(int v) => (v * _areaScale).round();

    // Çiçekler — wildflower patch'leri, mostly su kıyısına meyilli (sulak meadow)
    scatterBiased(DecorKind.daisy,     n(10), 3, waterBias: 0.45, treeBias: 0.10);
    scatterBiased(DecorKind.poppy,     n(8),  3, waterBias: 0.35, treeBias: 0.10);
    scatterBiased(DecorKind.lavender,  n(7),  3, treeBias: 0.30);
    scatterBiased(DecorKind.buttercup, n(9),  3, waterBias: 0.40, treeBias: 0.15);
    // Yonca — düşük yoğunluk, açık alana
    scatterBiased(DecorKind.clover,    n(10), 2);
    // Mantarlar — ağaç dibine kuvvetli bias (orman atmosferi)
    scatterBiased(DecorKind.mushroomRed,   n(4), 2, treeBias: 0.60);
    scatterBiased(DecorKind.mushroomBrown, n(6), 2, treeBias: 0.55);
    // Çalı — ağaç çevresine bias (orman edge'i)
    scatterBiased(DecorKind.bushSmall, n(5), 3, treeBias: 0.45);
    // Kütükler — nadir landmark, ağaç komşusu (kesilmiş ağaç hissi)
    scatterBiased(DecorKind.fallenLog, n(2), 2, treeBias: 0.55);
    scatterBiased(DecorKind.stump,     n(3), 2, treeBias: 0.55);
    // Taş kümeleri — su kenarı (river-smoothed pebble) ya da random
    scatterBiased(DecorKind.pebble,    n(7), 3, waterBias: 0.45);

    return decor;
  }
}
