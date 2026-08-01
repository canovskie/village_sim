/// YOL GÜZERGÂHI — iki tile arasında dik "L".
///
/// Yol döşeme eskiden SERBEST ELdi: sürüklerken parmağın/farenin geçtiği her
/// tile anında yola dönüşüyordu. En ufak titreme istenmeyen tile'lara yol
/// döşüyor, geri alma da olmadığı için hata kalıcı oluyordu.
///
/// Bu fonksiyon güzergâhı elin çizdiği eğriden değil, İKİ UÇTAN türetir:
/// baskın eksende ilerle, sonra köşeyi dön. Aynı iki uç her zaman aynı
/// güzergâhı verir; ara hareketlerin hiçbir etkisi yoktur.
///
/// Uçlar dahildir, tekrar eden tile yoktur, sıra başlangıçtan bitişe doğrudur.
List<(int, int)> roadRoute((int, int) from, (int, int) to) {
  final (c1, r1) = from;
  final (c2, r2) = to;

  final out = <(int, int)>[];
  final seen = <(int, int)>{};
  void add(int c, int r) {
    if (seen.add((c, r))) out.add((c, r));
  }

  final dc = (c2 - c1).abs();
  final dr = (r2 - r1).abs();
  final stepC = c2 >= c1 ? 1 : -1;
  final stepR = r2 >= r1 ? 1 : -1;

  if (dc >= dr) {
    // Yatay baskın: önce sütun boyunca git, sonra satır boyunca in/çık.
    for (int c = c1; c != c2 + stepC; c += stepC) {
      add(c, r1);
    }
    for (int r = r1; r != r2 + stepR; r += stepR) {
      add(c2, r);
    }
  } else {
    for (int r = r1; r != r2 + stepR; r += stepR) {
      add(c1, r);
    }
    for (int c = c1; c != c2 + stepC; c += stepC) {
      add(c, r2);
    }
  }
  return out;
}
