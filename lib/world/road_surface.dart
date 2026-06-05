import '../core/resources.dart';

/// Yerleştirilebilir yol yüzeyleri. Her surface'in maliyeti, yapım süresi,
/// üzerinde yürüyen NPC için hız çarpanı ve hangi zemine konabileceği var.
///
/// dirt: hızlı, ucuz, erken oyun. Sadece kara üstüne.
/// stone: kalıcı, hızlı yürüyüş, taş ister. Sadece kara üstüne.
/// woodBridge: SADECE su üstüne — kara üstüne döşenmez (köprü değil yol olur).
enum RoadSurface {
  dirt,
  stone,
  woodBridge;

  String get label => switch (this) {
        RoadSurface.dirt       => 'Toprak Yol',
        RoadSurface.stone      => 'Taş Yol',
        RoadSurface.woodBridge => 'Tahta Köprü',
      };

  String get icon => switch (this) {
        RoadSurface.dirt       => '🟫',
        RoadSurface.stone      => '🪨',
        RoadSurface.woodBridge => '🌉',
      };

  /// Tile başına maliyet — yerleştirme anında stoktan düşer.
  ResourceCost get cost => switch (this) {
        RoadSurface.dirt       => const ResourceCost(),                  // bedava
        RoadSurface.stone      => const ResourceCost(stone: 1),
        RoadSurface.woodBridge => const ResourceCost(wood: 2),
      };

  /// Builder bu kadar saniye çekiçler. Toprak hızlı, taş orta, köprü ağır.
  double get buildDuration => switch (this) {
        RoadSurface.dirt       => 1.0,
        RoadSurface.stone      => 1.8,
        RoadSurface.woodBridge => 3.0,
      };

  /// Üzerinde yürüyen NPC bu çarpanla hızlanır (1.0 = etkisiz).
  double get speedMultiplier => switch (this) {
        RoadSurface.dirt       => 1.15,
        RoadSurface.stone      => 1.30,
        RoadSurface.woodBridge => 1.15,
      };

  /// Bu yüzey su tile'ına döşenebilir mi?
  bool get requiresWater => this == RoadSurface.woodBridge;

  /// Bu yüzey kara tile'ına döşenebilir mi?
  bool get requiresLand => this != RoadSurface.woodBridge;
}
