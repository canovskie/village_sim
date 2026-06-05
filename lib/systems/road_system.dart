import '../world/road_tile.dart';
import '../world/road_surface.dart';

/// Köydeki tüm yerleştirilmiş yolları tutan tek otorite.
///
/// - Tamamlanan road'lar koordinat tabanlı haritada saklanır
/// - autotile bitmask (4 yön: N/E/S/W) komşu yol kontrolü için
/// - NPC hız çarpanı lookup'ı
/// - Yerleştirme validasyonu (kara/su, çakışma, sınır)
/// - Köprü olan su tile'ı için "üzerinden geçilebilir" sorgusu
///   (main.dart obstacle/waterTiles set'ini buna göre filtreler)
class RoadSystem {
  final Map<(int, int), RoadTile> _tiles = {};

  Iterable<RoadTile> get all => _tiles.values;
  int get count => _tiles.length;

  RoadTile? at(int col, int row) => _tiles[(col, row)];
  bool has(int col, int row)     => _tiles.containsKey((col, row));

  /// Köprü olan su tile'ı NPC pathing'inde su sayılmamalı.
  bool hasBridgeAt(int col, int row) {
    final t = _tiles[(col, row)];
    return t != null && t.surface == RoadSurface.woodBridge;
  }

  /// Üzerinde yürüyen NPC için hız çarpanı. Yol yoksa 1.0.
  /// Float koordinat → en yakın tile'ı sorgular.
  double speedMultiplierAt(double gx, double gy) {
    final c = gx.round();
    final r = gy.round();
    final t = _tiles[(c, r)];
    return t?.surface.speedMultiplier ?? 1.0;
  }

  /// 4-bit komşu maskesi: bit0=N(r-1), bit1=E(c+1), bit2=S(r+1), bit3=W(c-1).
  /// Farklı yüzeyler birbirine bağlanır (kullanıcı karma yol döşeyebilsin).
  int neighborMask(int col, int row) {
    int m = 0;
    if (_tiles.containsKey((col,     row - 1))) m |= 1;
    if (_tiles.containsKey((col + 1, row    ))) m |= 2;
    if (_tiles.containsKey((col,     row + 1))) m |= 4;
    if (_tiles.containsKey((col - 1, row    ))) m |= 8;
    return m;
  }

  /// Yerleştirme geçerli mi?
  /// - Sınır içinde olmalı
  /// - Aynı yere ikinci yol konmaz
  /// - Bina tile'ı engeller
  /// - Köprü SADECE suya, diğer yollar SADECE karaya
  bool canPlace({
    required int col,
    required int row,
    required RoadSurface surface,
    required int maxCol,
    required int maxRow,
    required Set<(int, int)> waterTiles,
    required Set<(int, int)> buildingTiles,
  }) {
    if (col < 0 || row < 0 || col >= maxCol || row >= maxRow) return false;
    if (_tiles.containsKey((col, row))) return false;
    if (buildingTiles.contains((col, row))) return false;

    final isWater = waterTiles.contains((col, row));
    if (surface.requiresWater && !isWater) return false;
    if (surface.requiresLand  &&  isWater) return false;
    return true;
  }

  void add(RoadTile t) {
    _tiles[(t.col, t.row)] = t;
  }

  void remove(int col, int row) {
    _tiles.remove((col, row));
  }

  void clear() => _tiles.clear();
}
