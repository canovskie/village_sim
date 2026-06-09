/// Çimene serpiştirilen statik dekor objeleri (çiçek, mantar, çalı, kütük, taş).
/// Pure visual — gameplay etkisi yok. World generator scatter eder, painter çizer.
enum DecorKind {
  daisy,
  poppy,
  lavender,
  buttercup,
  mushroomRed,
  mushroomBrown,
  clover,
  bushSmall,
  fallenLog,
  stump,
  pebble,
}

class DecorEntity {
  final int col, row;
  final DecorKind kind;
  final int variant;
  /// Tile içindeki küçük rastgele kayma (0..1).
  final double jitterX;
  final double jitterY;
  /// Görsel hafif sallanma faseni — wind ile senkron.
  final int swaySeed;

  const DecorEntity({
    required this.col,
    required this.row,
    required this.kind,
    required this.variant,
    required this.jitterX,
    required this.jitterY,
    required this.swaySeed,
  });

  /// Isometric depth — büyük kütük/çalı biraz arkada kalsın diye küçük offset.
  double get depth {
    final base = (col + row).toDouble() + jitterY * 0.3 + jitterX * 0.2;
    switch (kind) {
      case DecorKind.fallenLog:
      case DecorKind.stump:
      case DecorKind.bushSmall:
        return base + 0.15;
      default:
        return base + 0.05;
    }
  }
}
