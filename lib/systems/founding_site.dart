import '../core/constants.dart';

/// İlk ocağın kurulacağı kuru kuruluş açıklığı. Dünya üreticisinin su/maden
/// sokmadığı güvenli kutudan biraz daha küçüktür; oyuncu kıyıdaki bir manzarayı
/// yanlışlıkla köy merkezi yapıp erken kamera reach'inin dışında kalamaz.
const int kFoundingHearthHalfCols = 8;
const int kFoundingHearthHalfRows = 6;

(double, double) foundingHearthCenter() => (kCols / 2, kRows / 2);

bool isFoundingHearthTile(int col, int row) {
  final (cx, cy) = foundingHearthCenter();
  return (col + .5 - cx).abs() <= kFoundingHearthHalfCols &&
      (row + .5 - cy).abs() <= kFoundingHearthHalfRows;
}
