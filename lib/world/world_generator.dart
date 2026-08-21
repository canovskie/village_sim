import 'dart:math';

import '../core/constants.dart';
import 'decor_entity.dart';
import 'mine_node.dart';
import 'nature_entity.dart';
import 'tree_entity.dart';
import 'world_landmark.dart';

// ── Result ────────────────────────────────────────────────────────────────────

class WorldGeneratorResult {
  final Set<(int, int)> waterTiles;
  final List<LotusEntity> lotuses;
  final List<ReedClump> reeds;
  final List<TreeEntity> trees;
  final List<MineNode> mineNodes;
  final List<DecorEntity> decor;
  final List<BerryBush> berryBushes;
  final List<WorldLandmark> landmarks;

  const WorldGeneratorResult({
    required this.waterTiles,
    required this.lotuses,
    required this.reeds,
    required this.trees,
    required this.mineNodes,
    required this.decor,
    this.berryBushes = const [],
    this.landmarks = const [],
  });
}

// ── Generator ────────────────────────────────────────────────────────────────

class WorldGenerator {
  final int seed;
  late final Random _rng;

  /// Başlangıç bölgesi — su ve maden bu alana girmez. Kamera "reach"i köyü hep
  /// haritanın İÇİNDE tuttuğu için (gerçek kenar asla kadraja girmez) bu bölge
  /// artık haritanın ORTASINDA, merkez etrafında bir kutu.
  static const _safeCenterC = kCols ~/ 2;
  static const _safeCenterR = kRows ~/ 2;
  static const _safeHalfC = 11;
  static const _safeHalfR = 9;

  WorldGenerator(this.seed) {
    _rng = Random(seed);
  }

  /// Haritanın baz alana (48×36) göre alan oranı — entity sayıları bununla
  /// ölçeklenir. Büyük haritada daha çok orman/maden, küçük haritada daha az.
  /// min 1.0 — küçük haritada bile orijinal yoğunluk korunur.
  double get _areaScale {
    const baseArea = 48.0 * 36.0;
    // Cap: entity sayısı çok büyük haritada sınırsız şişmesin (ağaç/maden/dekor
    // tick döngüleri + spatial rebuild entity sayısıyla ölçekleniyor).
    //
    // AMA cap'i FAZLA kısarsan yoğunluk (entity/tile) düşer ve harita boşalır —
    // 128×128'e geçince cap 4.0 yoğunluğu yarıya indirip çayırı çölleştirdi.
    // 7.5 = kullanıcının onayladığı lush yoğunluğu birebir korur.
    // Perf: bu kalemler STATİK ve item başına ucuz (t.update(dt)); asıl per-frame
    // yük villager AI'sı ve o NÜFUSLA ölçekleniyor, harita/entity ile değil.
    const s = (kCols * kRows) / baseArea;
    return s.clamp(1.0, 7.5);
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
    final landmarks = _generateLandmarks(
      water,
      treeTiles,
      mineTiles,
      reedTiles,
    );
    final landmarkTiles = {for (final l in landmarks) (l.col, l.row)};
    final decor = _generateDecor(
      water,
      treeTiles,
      mineTiles,
      reedTiles,
      landmarkTiles,
    );
    final decorTiles = {for (final d in decor) (d.col, d.row)};
    final berries = _generateBerryBushes(
      water,
      treeTiles,
      mineTiles,
      reedTiles,
      {...decorTiles, ...landmarkTiles},
    );
    return WorldGeneratorResult(
      waterTiles: water,
      lotuses: lotuses,
      reeds: reeds,
      trees: trees,
      mineNodes: mines,
      decor: decor,
      berryBushes: berries,
      landmarks: landmarks,
    );
  }

  // ── Böğürtlen çalıları ──────────────────────────────────────────────────────

  /// Çalılar ORMAN KENARINA yaslanır: ağaç komşusu olan açık tile'lar tercih
  /// edilir. Sebep oyun tasarımı — toplayıcı ilk günden ormanın dibine gider,
  /// yani oduncunun gideceği yerle aynı yöne; köyün ilk iki işi birbirine
  /// yakın durur ve harita "iki ayrı uca koşturma" hissi vermez.
  ///
  /// Başlangıç bölgesinden DIŞLANMAZ (su/maden gibi): oyuncunun ilk dakikada
  /// elinin altında birkaç çalı olmalı, yoksa "yapacak bir şey yok" boşluğu
  /// aynen sürer.
  List<BerryBush> _generateBerryBushes(
    Set<(int, int)> water,
    Set<(int, int)> treeTiles,
    Set<(int, int)> mineTiles,
    Set<(int, int)> reedTiles,
    Set<(int, int)> decorTiles,
  ) {
    final bushes = <BerryBush>[];
    final taken = <(int, int)>{};

    bool free(int c, int r) =>
        c >= 1 && c < kCols - 1 && r >= 1 && r < kRows - 1 &&
        !water.contains((c, r)) &&
        !treeTiles.contains((c, r)) &&
        !mineTiles.contains((c, r)) &&
        !reedTiles.contains((c, r)) &&
        !decorTiles.contains((c, r)) &&
        !taken.contains((c, r));

    bool nearTree(int c, int r) {
      for (int dc = -1; dc <= 1; dc++) {
        for (int dr = -1; dr <= 1; dr++) {
          if (dc == 0 && dr == 0) continue;
          if (treeTiles.contains((c + dc, r + dr))) return true;
        }
      }
      return false;
    }

    // Çalılar ÖBEK hâlinde büyür (tek tek serpilmiş çalı doğal durmuyor ve
    // toplayıcıyı harita boyunca koşturuyor). Her öbek 2-4 çalı.
    final clusters = _scaledRange(5, 8);
    int guard = 0;
    while (bushes.length < clusters * 3 && guard < clusters * 60) {
      guard++;
      final c0 = 1 + _rng.nextInt(kCols - 2);
      final r0 = 1 + _rng.nextInt(kRows - 2);
      if (!free(c0, r0)) continue;
      // Orman kenarı tercihli: değilse çoğu denemeyi reddet.
      if (!nearTree(c0, r0) && _rng.nextDouble() > 0.22) continue;

      final n = 2 + _rng.nextInt(3);
      for (int i = 0; i < n; i++) {
        final c = c0 + _rng.nextInt(3) - 1;
        final r = r0 + _rng.nextInt(3) - 1;
        if (!free(c, r)) continue;
        taken.add((c, r));
        bushes.add(BerryBush(
          col: c,
          row: r,
          variant: _rng.nextInt(3),
          // Olgunluk dağınık başlar — hepsi aynı anda dolup aynı anda boşalırsa
          // toplayıcı sırayla değil dalga dalga çalışır, iş düzensiz görünür.
          ripeness: 0.35 + _rng.nextDouble() * 0.65,
        ));
      }
    }
    return bushes;
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

      // KIYI GÜRÜLTÜSÜ AÇISAL VE SÜREKLİ — kare kare zar DEĞİL.
      //
      // Eskiden sınır testi her tile için ayrı `_rng.nextDouble()` çekiyordu.
      // Sonuç tırtıklı bir kıyıydı: göle sokulan TEK KARE kara dilleri (ve
      // üstlerinde duran çamlar, ki uzaktan "denizin ortasında ağaç" gibi
      // görünüyor) + suyun içinde kalan tek kare kum elmasları. Kullanıcının
      // "yüzeyi bozmuş" dediği şeyin yarısı buydu.
      //
      // Şimdi sapma açının fonksiyonu: iki harmonik → göl elips değil ORGANİK
      // loblu bir şekil alır, ama sınır KOMŞUDAN KOMŞUYA yavaş değişir, yani
      // tek kare girinti/çıkıntı üretmez.
      final p1 = _rng.nextDouble() * 2 * pi;
      final p2 = _rng.nextDouble() * 2 * pi;

      for (int c = (cx - rx).floor() - 2; c <= (cx + rx).ceil() + 2; c++) {
        for (int r = (cy - ry).floor() - 2; r <= (cy + ry).ceil() + 2; r++) {
          if (c < 1 || c >= kCols - 1 || r < 1 || r >= kRows - 1) continue;
          if (_inSafe(c, r, margin: 2)) continue; // başlangıç bölgesini koru
          final dx = (c - cx) / rx;
          final dy = (r - cy) / ry;
          final ang = atan2(dy, dx);
          final wobble = sin(ang * 3 + p1) * 0.13 + sin(ang * 5 + p2) * 0.07;
          if (dx * dx + dy * dy < 1.0 + wobble) {
            tiles.add((c, r));
          }
        }
      }
    }

    _smoothShoreline(tiles);
    return tiles;
  }

  /// KIYI TEMİZLİĞİ — tek kare girinti/çıkıntıları yut.
  ///
  /// Açısal gürültü sınırı zaten yumuşattı, ama iki göl kesiştiğinde ya da
  /// güvenli bölge bir gölü kestiğinde hâlâ yalnız kare kalabiliyor. İzometride
  /// tek kare kara, etrafı suyla çevrili bir "ada" gibi değil, suyun içine
  /// düşmüş bir hata gibi okunur (üstünde bir ağaç varsa daha da beter).
  ///
  /// Morfolojik açma/kapama: üç ya da dört komşusu su olan kara suya döner;
  /// üç ya da dört komşusu kara olan su karaya döner. İki geçiş yeter —
  /// üçüncüsü gölleri gereksiz yuvarlaklaştırıyor.
  void _smoothShoreline(Set<(int, int)> tiles) {
    for (int pass = 0; pass < 2; pass++) {
      final add = <(int, int)>[];
      final remove = <(int, int)>[];

      int waterNeighbors(int c, int r) {
        var n = 0;
        if (tiles.contains((c - 1, r))) n++;
        if (tiles.contains((c + 1, r))) n++;
        if (tiles.contains((c, r - 1))) n++;
        if (tiles.contains((c, r + 1))) n++;
        return n;
      }

      // Suyun içinde kalan kara kareleri (girinti) — suya kat.
      for (final (c, r) in tiles) {
        for (final (nc, nr) in [(c - 1, r), (c + 1, r), (c, r - 1), (c, r + 1)]) {
          if (nc < 1 || nc >= kCols - 1 || nr < 1 || nr >= kRows - 1) continue;
          if (tiles.contains((nc, nr))) continue;
          // Başlangıç bölgesi korunur: köyün ortasına göl taşırmayalım.
          if (_inSafe(nc, nr, margin: 2)) continue;
          if (waterNeighbors(nc, nr) >= 3) add.add((nc, nr));
        }
      }
      // Karaya sarkan tek su kareleri (çıkıntı) — karaya döndür.
      for (final (c, r) in tiles) {
        if (waterNeighbors(c, r) <= 1) remove.add((c, r));
      }

      if (add.isEmpty && remove.isEmpty) break;
      tiles.addAll(add);
      tiles.removeAll(remove);
    }
  }

  bool _inSafe(int c, int r, {int margin = 0}) =>
      (c - _safeCenterC).abs() < _safeHalfC - margin &&
      (r - _safeCenterR).abs() < _safeHalfR - margin;

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
  //
  // KONTROLLÜ AÇILIM: kamera reveal'ı bir "reach" kutusudur (ekran-ekseni u,v;
  // span=hu+hv, başlangıç 50 → görev/bina ile ~117; bkz. scene_land +
  // scene_input._clampCamera). Madenler spawn'da bu metrikte MESAFE bandlarına
  // konur → ilk yerleşimde HİÇ maden görünmez; dünya açıldıkça önce taş, sonra
  // kömür, en derinde demir kadraja girer.

  /// Band eşikleri (span cinsinden). Başlangıç 50'nin üstünde marj bırakılır.
  static const double _kSpanStone = 56;
  static const double _kSpanCoal = 72;
  static const double _kSpanIron = 88;

  /// Bunun ötesi (maxSpan ~117'ye tampanlı) pratikte hiç kadraja girmez —
  /// oraya maden koymak israftır.
  static const double _kSpanCap = 112;

  /// (c,r)'nin kamera reach'ine girebilmesi için gereken en küçük span (hu+hv).
  /// Kesin değer viewport oranına bağlı (reach kutusu ekran oranıyla bölünür);
  /// burada MAKUL EN KÖTÜ durum alınır: u ekseni için en geniş (~21:9), v için
  /// en dar (~4:3) viewport → band eşiği hiçbir ekranda erken delinmez.
  static double _spanNeeded(num c, num r) {
    final du = ((c - r) - (kCols - kRows) / 2).abs();
    final dv = ((c + r) - (kCols + kRows - 2) / 2).abs();
    return max(du * 1.86, dv * 1.65);
  }

  List<MineNode> _generateMines(
    Set<(int, int)> water,
    Set<(int, int)> treeTiles,
  ) {
    final mines = <MineNode>[];
    final occupied = <(int, int)>{};

    // Her tür için İLK grup dar banda zorlanır → açılan reach o türü KESİN ve
    // sırayla karşılar; kalan gruplar band mininden cap'e serbest dağılır.
    void groups(OreType type, int count, double minSpan) {
      _placeGroup(type, water, treeTiles, occupied, mines,
          minSpan: minSpan, maxSpan: minSpan + 16);
      for (int i = 1; i < count; i++) {
        _placeGroup(type, water, treeTiles, occupied, mines,
            minSpan: minSpan, maxSpan: _kSpanCap);
      }
    }

    groups(OreType.stone, _scaledRange(1, 2), _kSpanStone); // ilk genişleme
    groups(OreType.coal, _scaledRange(1, 1), _kSpanCoal); // orta
    groups(OreType.iron, _scaledRange(1, 1), _kSpanIron); // en derin

    return mines;
  }

  /// 2×2 kare mine grubu yerleştirir. Her grup tam 4 node içerir,
  /// maden binası (2×2) üstüne tam oturur. [minSpan]/[maxSpan]: grubun tüm
  /// tile'ları bu reach bandında kalmalı (kontrollü açılım).
  void _placeGroup(
    OreType type,
    Set<(int, int)> water,
    Set<(int, int)> treeTiles,
    Set<(int, int)> occupied,
    List<MineNode> out, {
    required double minSpan,
    required double maxSpan,
  }) {
    // Bandlar haritanın küçük bir dilimi — rejection sampling'e bol deneme.
    for (int attempt = 0; attempt < 160; attempt++) {
      final col = 3 + _rng.nextInt(kCols - 6); // sol-üst köşe
      final row = 3 + _rng.nextInt(kRows - 6);

      // 2×2 bloğun tamamı boş, su yok, ağaç yok, reach bandının içinde olmalı
      bool ok = true;
      for (int dc = 0; dc < 2 && ok; dc++) {
        for (int dr = 0; dr < 2 && ok; dr++) {
          final c = col + dc;
          final r = row + dr;
          final span = _spanNeeded(c, r);
          if (occupied.contains((c, r)) ||
              water.contains((c, r)) ||
              treeTiles.contains((c, r)) ||
              span < minSpan ||
              span > maxSpan) {
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

  // ── Harita ilgi noktaları ──────────────────────────────────────────────────

  /// Beş küçük yer, kamera erişiminin ardışık bantlarına dağıtılır. Sonuç
  /// torbasında üç bonus ve iki bela vardır; sıra seed'le karışır ama bir dünya
  /// yalnız ödül ya da yalnız ceza üretemez.
  List<WorldLandmark> _generateLandmarks(
    Set<(int, int)> water,
    Set<(int, int)> treeTiles,
    Set<(int, int)> mineTiles,
    Set<(int, int)> reedTiles,
  ) {
    final result = <WorldLandmark>[];
    final occupied = <(int, int)>{};
    final kinds = WorldLandmarkKind.values.toList()..shuffle(_rng);
    final outcomes = <LandmarkOutcome>[
      LandmarkOutcome.salvage,
      LandmarkOutcome.provisions,
      LandmarkOutcome.oldCoin,
      LandmarkOutcome.spoiledStores,
      LandmarkOutcome.illOmen,
    ]..shuffle(_rng);
    const bands = <(double, double)>[
      (54, 64),
      (64, 74),
      (74, 84),
      (84, 94),
      (94, 110),
    ];

    for (var i = 0; i < bands.length; i++) {
      final (lo, hi) = bands[i];
      for (var attempt = 0; attempt < 500; attempt++) {
        final c = 2 + _rng.nextInt(kCols - 4);
        final r = 2 + _rng.nextInt(kRows - 4);
        final tile = (c, r);
        final span = _spanNeeded(c, r);
        if (span < lo ||
            span > hi ||
            water.contains(tile) ||
            treeTiles.contains(tile) ||
            mineTiles.contains(tile) ||
            reedTiles.contains(tile)) {
          continue;
        }
        // Ayrı siluetler olarak okunsun; iki keşif aynı kadrajda üst üste
        // binmesin. Kare mesafe bu küçük sabit listede yeterli.
        if (occupied.any((p) => (p.$1 - c).abs() < 7 && (p.$2 - r).abs() < 7)) {
          continue;
        }
        occupied.add(tile);
        result.add(
          WorldLandmark(col: c, row: r, kind: kinds[i], outcome: outcomes[i]),
        );
        break;
      }
    }
    return result;
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
    Set<(int, int)> landmarkTiles,
  ) {
    final decor = <DecorEntity>[];
    final occupied = <(int, int)>{};

    bool tileFree(int c, int r) =>
        c >= 0 && c < kCols && r >= 0 && r < kRows &&
        !water.contains((c, r)) &&
        !treeTiles.contains((c, r)) &&
        !mineTiles.contains((c, r)) &&
        !reedTiles.contains((c, r)) &&
        !landmarkTiles.contains((c, r)) &&
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
