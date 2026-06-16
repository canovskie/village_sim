/// Kilise yanında biriken mezar — bir köylü hayata veda ettiğinde
/// `_spawnGrave` ile dünyaya eklenir. Pure visual (gameplay engeli değil,
/// üstünden geçilir); painter prosedürel baş taşı + toprak höyük çizer.
/// Köyün "hafızası": ölenlerin adı taşta yaşar.
class Grave {
  /// Tile konumu (tam sayı tile merkezine + küçük jitter ile yerleşir).
  final double col;
  final double row;

  /// Baş taşı şekli varyantı: 0 = yuvarlak şahide, 1 = haç, 2 = küçük levha.
  final int variant;

  /// Burada yatan köylünün adı (ileride tıklama/anma için).
  final String name;

  /// Tile içi küçük rastgele kayma — sıra dışı doğal görünüm.
  final double jitterX;
  final double jitterY;

  const Grave({
    required this.col,
    required this.row,
    required this.variant,
    required this.name,
    this.jitterX = 0.0,
    this.jitterY = 0.0,
  });

  /// Isometric depth — decor seviyesinde (çimene oturur, binadan önce çizilir).
  double get depth => col + row + 0.45;
}
