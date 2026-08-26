import '../core/constants.dart';

/// İlk ocağın kurulacağı kuru kuruluş açıklığı. Dünya üreticisinin su/maden
/// sokmadığı güvenli kutudan biraz daha küçüktür; oyuncu kıyıdaki bir manzarayı
/// yanlışlıkla köy merkezi yapıp erken kamera reach'inin dışında kalamaz.
const int kFoundingHearthHalfCols = 8;
const int kFoundingHearthHalfRows = 6;

/// Ocağın ve ilk birkaç yapının okunaklı kalacağı doğal açıklık. Kuruluş
/// seçme alanından bilinçli olarak daha küçüktür; doğa yakında görünür ama
/// çadırın, kuyunun ve ilk tarlanın içine doğmaz.
const int kFoundingCoreHalfCols = 6;
const int kFoundingCoreHalfRows = 4;

(double, double) foundingHearthCenter() => (kCols / 2, kRows / 2);

bool isFoundingHearthTile(int col, int row) {
  final (cx, cy) = foundingHearthCenter();
  return (col + .5 - cx).abs() <= kFoundingHearthHalfCols &&
      (row + .5 - cy).abs() <= kFoundingHearthHalfRows;
}

bool isFoundingCoreTile(int col, int row) {
  final (cx, cy) = foundingHearthCenter();
  return (col + .5 - cx).abs() <= kFoundingCoreHalfCols &&
      (row + .5 - cy).abs() <= kFoundingCoreHalfRows;
}
