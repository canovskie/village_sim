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

  DecorEntity({
    required this.col,
    required this.row,
    required this.kind,
    required this.variant,
    required this.jitterX,
    required this.jitterY,
    required this.swaySeed,
  });

  // ── Ezilme (crush) animasyonu ──────────────────────────────────────────────
  // Bir köylü çiçeğin üstüne basınca anlık silinmez: görünür biçimde ezilip
  // solar (yassılaşma + fade), animasyon bitince sahne listeden çıkarır. Köylü/
  // hayvan ölüm animasyonuyla simetrik "no pop-out" ilkesi.
  static const double kCrushDuration = 0.85;

  /// Ezilme başladı mı — true ise animasyonda, sim onu artık "canlı" saymaz.
  bool crushed = false;
  double _crushT = 0.0;

  /// Ezilmeyi tetikle (idempotent — zaten eziliyorsa yok sayar).
  void startCrush() {
    if (crushed) return;
    crushed = true;
    _crushT = 0.0;
  }

  /// Animasyonu ilerlet; bitti mi döner (sahne removeWhere için).
  bool tickCrush(double dt) {
    if (!crushed) return false;
    _crushT += dt;
    return _crushT >= kCrushDuration;
  }

  /// 0 (sağlam) → 1 (tamamen ezilmiş/solmuş).
  double get crushProgress =>
      crushed ? (_crushT / kCrushDuration).clamp(0.0, 1.0) : 0.0;

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
