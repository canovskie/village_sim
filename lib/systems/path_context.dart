import '../world/road_surface.dart';
import 'road_system.dart';

/// Pathfinder'a tek noktadan world cost/block bilgisi sağlar.
///
/// - costAt: tile'a girmenin maliyeti — yol varsa indirimli, squeeze
///   (1-tile koridor binalar arasında) yüksek penaltı, yoksa baz 1.0
/// - blocked: geçilemez tile (su [köprüsüz] + aktif maden + solid binalar).
///   walkable binalar (firepit, well, lamppost, ev) engel sayılmaz — etrafında
///   veya içine girilen yapılar.
/// - version: world topology değişince bump (yeni bina/yol completion, maden
///   tükenme). NPC bu sayıyı yakalayıp eski path cache'ini invalidate eder.
class PathContext {
  final RoadSystem roadSystem;

  /// main.dart _obstacles set'inin referansı — her spatial cache rebuild'da
  /// içerik güncellenir, reference sabit kalır.
  Set<(int, int)> blockedTiles;

  /// 1-tile genişlikte bina koridorları — yüksek cost ile A*'ı etrafından
  /// dolaştırır. main.dart'ın _squeezeTiles set'inin referansı.
  Set<(int, int)> squeezeTiles;

  int version = 0;

  PathContext({
    required this.roadSystem,
    Set<(int, int)>? blockedTiles,
    Set<(int, int)>? squeezeTiles,
  })  : blockedTiles  = blockedTiles  ?? const {},
        squeezeTiles  = squeezeTiles  ?? const {};

  static const double _kSqueezePenalty = 4.0;

  double costAt(int col, int row) {
    final road = roadSystem.at(col, row);
    if (road != null) {
      return switch (road.surface) {
        RoadSurface.dirt       => 0.70,
        RoadSurface.stone      => 0.55,
        RoadSurface.woodBridge => 0.70,
      };
    }
    if (squeezeTiles.contains((col, row))) return _kSqueezePenalty;
    return 1.0;
  }

  bool blocked(int col, int row) {
    // Köprü olan su tile'ı, spatial cache rebuild gecikse bile pathfinder'a
    // açık görünmeli — yeni yapılan köprü hemen kullanılsın diye direct sorgu.
    if (roadSystem.hasBridgeAt(col, row)) return false;
    return blockedTiles.contains((col, row));
  }

  /// World topology değişti (yeni yol/bina completed, maden tükendi, vs.).
  /// NPC'lerin cached path'i bir sonraki sorgu'da invalidate olur.
  void bumpVersion() {
    version++;
  }
}
