/// Tarladan ayrı, sıkıştırılmış toprak üstünde çalışan 2×2 harman alanı.
///
/// Bir yapı değildir; yolu kapatmaz ve işçi yuvası istemez. Yalnız samanın
/// tarlada birikmemesi için hasat teslim noktası ve balya üretim alanıdır.
class HarmanSite {
  static const int size = 2;

  /// İki balyalık ara stok. Ambar yoksa üretim burada düzenli biçimde durur.
  static const int maxSheafEquivalents = 12;

  final int col;
  final int row;

  const HarmanSite({required this.col, required this.row});

  double get centerX => col + size / 2.0;
  double get centerY => row + size / 2.0;

  bool containsPoint(double x, double y) =>
      x >= col && x < col + size && y >= row && y < row + size;

  bool containsTile(int tileCol, int tileRow) =>
      tileCol >= col &&
      tileCol < col + size &&
      tileRow >= row &&
      tileRow < row + size;

  Iterable<(int, int)> get tiles sync* {
    for (int c = col; c < col + size; c++) {
      for (int r = row; r < row + size; r++) {
        yield (c, r);
      }
    }
  }
}
