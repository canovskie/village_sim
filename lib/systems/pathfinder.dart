import '../core/constants.dart';

typedef CostFn    = double Function(int col, int row);
typedef BlockedFn = bool   Function(int col, int row);

/// 4-yönlü A* pathfinder. Tek-thread, statik buffer reuse — her çağrı için
/// ~kCols×kRows fillRange yapar (3888 op, GC yok). Heap binary min-heap.
///
/// Cost konvansiyonu: costAt(c,r) o tile'a GİRMENİN maliyeti. Heuristic
/// minimum step cost'tan ≤ değer kullanır (admissible). Min step = 0.55
/// (taş yol); heuristic 0.5 ile tutuyoruz (tight admissible).
///
/// Performans notu: 50 NPC × ~5 sn'de bir replan = ~10 path/sn. Per-path
/// worst case 5000 iter × tek node O(log n) heap op = mikrosaniyeler. Frame
/// içinde toplam ms altı kalır. NPC tarafı stagger ile bunu spread eder.
class Pathfinder {
  static const int _cols = kCols;
  static const int _rows = kRows;
  static const int _n    = _cols * _rows;

  // Statik buffer — her bulma çağrısında fillRange ile sıfırlanır.
  static final List<double> _gScore   = List.filled(_n, double.infinity);
  static final List<int>    _cameFrom = List.filled(_n, -1);
  static final List<bool>   _closed   = List.filled(_n, false);

  // Binary min-heap. _heapF f-score, _heapI tile index. Parallel arrays —
  // tek tek pair allocation yapmamak için.
  static final List<double> _heapF = [];
  static final List<int>    _heapI = [];

  /// (sc,sr) → (gc,gr) en kısa yolu döner. Sonuç başlangıcı İÇERMEZ, hedefi
  /// içerir. Yol yoksa null. (sc,sr)==(gc,gr) → boş liste.
  /// [blocked] true → tile geçilemez (su, bina, maden). Hedef blocked → null.
  /// [maxIters] worst-case güvenliği; aşılırsa null.
  static List<(int, int)>? findPath(
    int sc, int sr, int gc, int gr,
    CostFn costAt,
    BlockedFn blocked, {
    int maxIters = 5000,
  }) {
    if (sc < 0 || sr < 0 || sc >= _cols || sr >= _rows) return null;
    if (gc < 0 || gr < 0 || gc >= _cols || gr >= _rows) return null;
    if (sc == gc && sr == gr) return const [];
    if (blocked(gc, gr)) return null;

    _gScore.fillRange(0, _n, double.infinity);
    _cameFrom.fillRange(0, _n, -1);
    _closed.fillRange(0, _n, false);
    _heapF.clear();
    _heapI.clear();

    final startIdx = sr * _cols + sc;
    final goalIdx  = gr * _cols + gc;
    _gScore[startIdx] = 0;
    _heapPush(_heuristic(sc, sr, gc, gr), startIdx);

    int iters = 0;
    while (_heapI.isNotEmpty && iters++ < maxIters) {
      final cur = _heapPop();
      if (cur == goalIdx) return _reconstruct(cur);
      if (_closed[cur]) continue;
      _closed[cur] = true;

      final cc = cur % _cols;
      final cr = cur ~/ _cols;
      final curG = _gScore[cur];

      _relax(cc,     cr - 1, cur, curG, costAt, blocked, gc, gr);
      _relax(cc + 1, cr,     cur, curG, costAt, blocked, gc, gr);
      _relax(cc,     cr + 1, cur, curG, costAt, blocked, gc, gr);
      _relax(cc - 1, cr,     cur, curG, costAt, blocked, gc, gr);
    }
    return null;
  }

  static double _heuristic(int c, int r, int gc, int gr) {
    // 4-neighbor + min-step 0.55 → Manhattan × 0.5 admissible. Optimal.
    final dx = (c - gc).abs();
    final dy = (r - gr).abs();
    return (dx + dy) * 0.5;
  }

  static void _relax(
    int nc, int nr, int from, double curG,
    CostFn costAt, BlockedFn blocked,
    int gc, int gr,
  ) {
    if (nc < 0 || nr < 0 || nc >= _cols || nr >= _rows) return;
    if (blocked(nc, nr)) return;
    final ni = nr * _cols + nc;
    if (_closed[ni]) return;
    final tentG = curG + costAt(nc, nr);
    if (tentG < _gScore[ni]) {
      _gScore[ni]   = tentG;
      _cameFrom[ni] = from;
      _heapPush(tentG + _heuristic(nc, nr, gc, gr), ni);
    }
  }

  static List<(int, int)> _reconstruct(int goalIdx) {
    final out = <(int, int)>[];
    int cur = goalIdx;
    while (_cameFrom[cur] != -1) {
      out.add((cur % _cols, cur ~/ _cols));
      cur = _cameFrom[cur];
    }
    return out.reversed.toList();
  }

  // ── Binary min-heap ────────────────────────────────────────────────────────
  static void _heapPush(double f, int idx) {
    _heapF.add(f);
    _heapI.add(idx);
    int n = _heapF.length - 1;
    while (n > 0) {
      final p = (n - 1) >> 1;
      if (_heapF[p] <= _heapF[n]) break;
      _swap(p, n);
      n = p;
    }
  }

  static int _heapPop() {
    final top  = _heapI[0];
    final last = _heapF.length - 1;
    if (last == 0) {
      _heapF.removeLast();
      _heapI.removeLast();
      return top;
    }
    _heapF[0] = _heapF[last];
    _heapI[0] = _heapI[last];
    _heapF.removeLast();
    _heapI.removeLast();
    int n = 0;
    final len = _heapF.length;
    while (true) {
      final l = (n << 1) + 1;
      if (l >= len) break;
      final r = l + 1;
      final smaller = (r < len && _heapF[r] < _heapF[l]) ? r : l;
      if (_heapF[smaller] >= _heapF[n]) break;
      _swap(n, smaller);
      n = smaller;
    }
    return top;
  }

  static void _swap(int a, int b) {
    final f = _heapF[a]; _heapF[a] = _heapF[b]; _heapF[b] = f;
    final i = _heapI[a]; _heapI[a] = _heapI[b]; _heapI[b] = i;
  }
}
