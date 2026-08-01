import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/systems/road_route.dart';

/// Yol güzergâhının sözleşmesi.
///
/// Şikâyet: "sürekli yanlış yerlere yol yapılıyor." Sebebi serbest-el
/// döşemeydi — elin geçtiği HER tile yol oluyordu. Güzergâh artık yalnız iki
/// uçtan türer; aşağıdaki testler o belirlenimciliği kilitler.
void main() {
  group('roadRoute', () {
    test('tek tile — başlangıç ile bitiş aynıysa tek eleman', () {
      expect(roadRoute((5, 5), (5, 5)), [(5, 5)]);
    });

    test('yatay çizgi — ara tile\'lar eksiksiz, uçlar dahil', () {
      expect(roadRoute((3, 7), (6, 7)), [(3, 7), (4, 7), (5, 7), (6, 7)]);
    });

    test('dikey çizgi', () {
      expect(roadRoute((4, 2), (4, 5)), [(4, 2), (4, 3), (4, 4), (4, 5)]);
    });

    test('ters yön (sağdan sola) da tam sayılır', () {
      expect(roadRoute((6, 7), (3, 7)), [(6, 7), (5, 7), (4, 7), (3, 7)]);
    });

    test('yatay baskın → önce sütun, sonra köşe', () {
      // dc=3, dr=1 → önce yatay git (r=0), sonra c=3'te aşağı in.
      expect(roadRoute((0, 0), (3, 1)),
          [(0, 0), (1, 0), (2, 0), (3, 0), (3, 1)]);
    });

    test('dikey baskın → önce satır, sonra köşe', () {
      // dc=1, dr=3 → önce dikey git (c=0), sonra r=3'te sağa.
      expect(roadRoute((0, 0), (1, 3)),
          [(0, 0), (0, 1), (0, 2), (0, 3), (1, 3)]);
    });

    test('köşe tile\'ı iki kez sayılmaz', () {
      final r = roadRoute((0, 0), (4, 4));
      expect(r.toSet().length, r.length, reason: 'tekrar eden tile olmamalı');
    });

    test('güzergâh SÜREKLİ — ardışık tile\'lar hep komşu', () {
      final r = roadRoute((2, 9), (11, 3));
      for (int i = 1; i < r.length; i++) {
        final d = (r[i].$1 - r[i - 1].$1).abs() + (r[i].$2 - r[i - 1].$2).abs();
        expect(d, 1, reason: '$i. adımda kopukluk var: ${r[i - 1]} → ${r[i]}');
      }
    });

    test('uzunluk Manhattan mesafesi + 1 (fazladan tile yok)', () {
      final r = roadRoute((2, 9), (11, 3));
      expect(r.length, (11 - 2).abs() + (3 - 9).abs() + 1);
      expect(r.first, (2, 9));
      expect(r.last, (11, 3));
    });

    test('AYNI uçlar HER ZAMAN aynı güzergâh — ara hareket etkisiz', () {
      // Kontrolün özü bu: oyuncunun eli nereden dolaşırsa dolaşsın, bırakınca
      // gördüğü şey yalnız iki uca bağlıdır.
      expect(roadRoute((7, 2), (2, 8)), roadRoute((7, 2), (2, 8)));
    });
  });
}
