part of 'home_interior.dart';

/// Değişmez ev planı: çizim, dokunma ve NPC yollarının ortak tek kaynağı.
/// Rastgele/oturumluk state yok; mevcut kaydın bina koordinatları yeterlidir.
class HomeInteriorLayout {
  static const width = 10.0, depth = 8.0, planCount = 6;
  static final standard = HomeInteriorLayout.fromSeed(0, plan: 0);
  final int seed, planIndex;
  final List<InteriorFurniture> furniture;
  final List<double> windows;
  HomeInteriorLayout._(
    this.seed,
    this.planIndex,
    List<InteriorFurniture> items,
    List<double> windows,
  ) : furniture = List.unmodifiable(items),
      windows = List.unmodifiable(windows);

  /// Cantor eşlemesi: eski col*31+row*17 gibi farklı evler aynı tohumu almaz.
  static int seedForHome(int col, int row) {
    int positive(int n) => n >= 0 ? 2 * n : -2 * n - 1;
    final a = positive(col), b = positive(row), sum = a + b;
    return sum * (sum + 1) ~/ 2 + b;
  }

  static int _mix(int seed) {
    var n = seed & 0x7fffffff;
    n = ((n ^ (n >> 16)) * 0x45d9) & 0x7fffffff;
    n = ((n ^ (n >> 16)) * 0x45d9) & 0x7fffffff;
    return (n ^ (n >> 16)) & 0x7fffffff;
  }

  factory HomeInteriorLayout.fromSeed(int seed, {int? plan}) {
    final code = _mix(seed);
    final index = plan == null ? code % planCount : plan % planCount;
    // Modüller birbirinden bağımsız, küçük kaymalar güvenli boşluklar içinde.
    double shift(int bits, double span) =>
        (((code >> bits) & 15) / 15 - .5) * span;
    final (
      bed0,
      bed1,
      hearthX,
      table,
      shelf,
      chest,
      plants,
      basket,
    ) = switch (index) {
      1 => (
        (x: .65, y: .65),
        (x: 3.4, y: .65),
        7.8,
        (x: 4.6, y: 4.65),
        (x: .15, y: 4.3),
        (x: 1.2, y: 6.7),
        [(x: .2, y: 6.95), (x: 9.25, y: 4.15)],
        (x: 8.9, y: 7.1),
      ),
      2 => (
        (x: 4.8, y: .65),
        (x: 7.7, y: .65),
        .4,
        (x: 2.6, y: 4.65),
        (x: .15, y: 4.3),
        (x: 8.35, y: 5.9),
        [(x: .2, y: 6.95), (x: 9.25, y: 4.15)],
        (x: 8.9, y: 7.1),
      ),
      3 => (
        (x: .65, y: .65),
        (x: 7.7, y: 3.9),
        4.15,
        (x: 3.25, y: 4.4),
        (x: .15, y: 4.3),
        (x: 8.45, y: 1.7),
        [(x: .2, y: 6.95), (x: 9.25, y: 7.1)],
        (x: 8.35, y: 7.1),
      ),
      4 => (
        (x: .65, y: 3.8),
        (x: 7.7, y: .65),
        4.15,
        (x: 3.75, y: 4.3),
        (x: .15, y: .35),
        (x: .9, y: 6.85),
        [(x: 2.6, y: .35), (x: 9.25, y: 4.15)],
        (x: 8.9, y: 7.1),
      ),
      5 => (
        (x: .65, y: .65),
        (x: .65, y: 4.1),
        7.8,
        (x: 4.25, y: 4.65),
        (x: 3.35, y: .15),
        (x: 8.35, y: 5.9),
        [(x: 2.6, y: .3), (x: 9.25, y: 4.15)],
        (x: 8.9, y: 7.1),
      ),
      _ => (
        (x: .65, y: .65),
        (x: 7.7, y: .65),
        4.15,
        (x: 3.75, y: 4.25),
        (x: .15, y: 4.3),
        (x: 8.35, y: 5.9),
        [(x: .2, y: 6.95), (x: 9.25, y: 4.15)],
        (x: 8.9, y: 7.1),
      ),
    };
    final tx = table.x + shift(3, .24), ty = table.y + shift(7, .2);
    final items = <InteriorFurniture>[
      InteriorFurniture(
        InteriorFurnitureKind.rug,
        tx - 1.05,
        ty - .65,
        4.8,
        3.1,
      ),
      for (final (i, bed) in [bed0, bed1].indexed)
        InteriorFurniture(
          InteriorFurnitureKind.bed,
          bed.x,
          bed.y + shift(11 + i * 4, .12),
          1.65,
          2.85,
          i,
        ),
      InteriorFurniture(InteriorFurnitureKind.hearth, hearthX, .15, 1.7, 1.25),
      InteriorFurniture.placed(
        InteriorFurnitureKind.shelf,
        shelf.x + (index == 5 ? shift(3, .14) : 0),
        shelf.y + (index == 5 ? 0 : shift(5, .14)),
        index == 5 ? 2 : .7,
        index == 5 ? .7 : 2,
        transposed: index == 5,
      ),
      InteriorFurniture(
        InteriorFurnitureKind.chest,
        chest.x + shift(9, .16),
        chest.y + shift(13, .16),
        1.15,
        1,
      ),
      InteriorFurniture(InteriorFurnitureKind.table, tx, ty, 2.5, 1.5),
      InteriorFurniture(
        InteriorFurnitureKind.stool,
        tx - .95,
        ty + .55,
        .5,
        .5,
      ),
      InteriorFurniture(
        InteriorFurnitureKind.stool,
        tx + 2.9,
        ty + .55,
        .5,
        .5,
        1,
      ),
      for (final (i, p) in plants.indexed)
        InteriorFurniture(
          InteriorFurnitureKind.planter,
          p.x + shift(15 + i * 4, .08),
          p.y + shift(18 + i * 4, .08),
          .55,
          .65,
          i,
        ),
      InteriorFurniture(
        InteriorFurnitureKind.basket,
        basket.x + shift(22, .1),
        basket.y,
        .65,
        .55,
      ),
      InteriorFurniture(
        InteriorFurnitureKind.firewood,
        hearthX > 7 ? hearthX - .85 : hearthX + 1.8,
        .25,
        .65,
        .85,
      ),
    ];
    return HomeInteriorLayout._(
      seed,
      index,
      items,
      index == 5
          ? [1.2, 5.85]
          : hearthX > 7
          ? [3.35, 5.85]
          : hearthX < 1
          ? [2.8, 6.55]
          : [2.6, 6.55],
    );
  }

  InteriorFurniture item(InteriorFurnitureKind kind, [int variant = 0]) =>
      furniture.firstWhere((f) => f.kind == kind && f.variant == variant);

  bool walkable(double x, double y) =>
      x >= .25 &&
      y >= .25 &&
      x <= width - .25 &&
      y <= depth - .25 &&
      !furniture.any((f) => f.blocksWalking && f.contains(x, y, padding: .12));

  RoomPoint target(int slot, InteriorActivity action) {
    final bed = item(InteriorFurnitureKind.bed, slot);
    final stool = item(InteriorFurnitureKind.stool, slot);
    final hearth = item(InteriorFurnitureKind.hearth);
    final desired = switch (action) {
      InteriorActivity.table => (x: stool.x + .25, y: stool.y + .25),
      InteriorActivity.hearth => (
        x: hearth.x + hearth.width / 2,
        y: hearth.y + hearth.depth + .6,
      ),
      InteriorActivity.window => (x: windows[slot] + .58, y: 2.6),
      InteriorActivity.sleeping => (
        x: bed.x < 4.5 ? bed.x + bed.width + .5 : bed.x - .55,
        y: bed.y + 1.85,
      ),
      InteriorActivity.walking => (x: 4.25 + slot * 1.5, y: 7.25),
    };
    // Pencerenin altında yatak varsa, en yakın boş gözlem noktası kullanılır.
    if (walkable(desired.x, desired.y)) return desired;
    final candidates = [
      for (int x = 0; x < 20; x++)
        for (int y = 0; y < 16; y++)
          if (walkable(x * .5 + .25, y * .5 + .25))
            (x: x * .5 + .25, y: y * .5 + .25),
    ];
    double distance(RoomPoint p) =>
        pow(p.x - desired.x, 2).toDouble() + pow(p.y - desired.y, 2).toDouble();
    candidates.sort((a, b) => distance(a).compareTo(distance(b)));
    return candidates.first;
  }

  bool _clear(RoomPoint a, RoomPoint b) {
    final steps = (sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2)) / .06).ceil();
    for (int i = 0; i <= steps; i++) {
      final t = steps == 0 ? 0.0 : i / steps;
      if (!walkable(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t)) return false;
    }
    return true;
  }

  /// Yarım-tile yol ağı; ilk/son bağlantı da denetlenir, kaydırılan eşyaların
  /// köşesini kesen off-grid son adımlar üretilmez.
  List<RoomPoint> route(RoomPoint from, RoomPoint to) {
    if (!walkable(from.x, from.y) || !walkable(to.x, to.y)) return [];
    if ((from.x - to.x).abs() < .75 &&
        (from.y - to.y).abs() < .75 &&
        _clear(from, to)) {
      return [to];
    }
    RoomPoint center((int, int) cell) =>
        (x: cell.$1 * .5 + .25, y: cell.$2 * .5 + .25);
    final queue = Queue<(int, int)>();
    final previous = <(int, int), (int, int)?>{};
    final cx = (from.x * 2).floor(), cy = (from.y * 2).floor();
    for (int dx = -1; dx <= 1; dx++) {
      for (int dy = -1; dy <= 1; dy++) {
        final cell = (cx + dx, cy + dy);
        if (_clear(from, center(cell))) {
          queue.add(cell);
          previous[cell] = null;
        }
      }
    }
    (int, int)? goal;
    while (queue.isNotEmpty) {
      final current = queue.removeFirst(), p = center(current);
      if ((p.x - to.x).abs() <= .75 &&
          (p.y - to.y).abs() <= .75 &&
          _clear(p, to)) {
        goal = current;
        break;
      }
      for (final d in const [(1, 0), (0, 1), (-1, 0), (0, -1)]) {
        final next = (current.$1 + d.$1, current.$2 + d.$2);
        if (previous.containsKey(next) || !_clear(p, center(next))) continue;
        previous[next] = current;
        queue.add(next);
      }
    }
    if (goal == null) return [];
    final path = <RoomPoint>[to];
    for ((int, int)? cursor = goal; cursor != null; cursor = previous[cursor]) {
      path.add(center(cursor));
    }
    return path.reversed.toList();
  }
}
