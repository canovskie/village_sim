import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/world/land_expansion.dart';

/// Dünyanın açılma eğrisi. Buradaki asıl sözleşme tek cümle: **hedef harita
/// sınırına ULAŞMAZ** — köy ne kadar büyürse büyüsün "dünya durdu" duvarı yok.
void main() {
  // 128×128 haritanın gerçek değerleri (scene_input._maxSpan, _kSpanStart).
  const start = 50.0;
  const maxSpan = 117.0;
  const ceil = maxSpan - kSpanCeilMargin; // 113

  double at(double progress) =>
      landExpansionTarget(start: start, ceil: ceil, progress: progress);

  group('landExpansionTarget', () {
    test('ilerleme yokken tam olarak başlangıç span’i', () {
      expect(at(0), closeTo(start, 1e-9));
    });

    test('tavana ASLA ulaşmaz — uç ilerlemelerde bile', () {
      for (final p in [1.0, 67.0, 200.0, 1e3, 1e6, 1e12]) {
        final v = at(p);
        expect(v, lessThan(ceil), reason: 'ilerleme $p tavanı deldi');
        expect(v, lessThan(maxSpan),
            reason: 'ilerleme $p harita sınırını deldi');
      }
    });

    test('monoton artar (dünya hiç geri kapanmaz)', () {
      var prev = at(0);
      for (double p = 0.5; p < 500; p += 0.5) {
        final v = at(p);
        expect(v, greaterThanOrEqualTo(prev), reason: 'ilerleme $p’de geriledi');
        prev = v;
      }
    });

    test('erken oyun eski LİNEER eğriyle örtüşür (açılış hissi korunur)', () {
      // Eski model: start + progress. Eğri ilk ~17 birimde lineerin bir tık
      // ÖNÜNDE gider (tepe ~+1.5), orada kesişir, sonra geriye düşer. İlk
      // ~40 binada (ilerleme 20) sapma her iki yönde de 2 span’in altında.
      for (final p in [5.0, 10.0, 20.0]) {
        expect((at(p) - (start + p)).abs(), lessThan(2.0),
            reason: 'ilerleme $p lineerden koptu');
      }
    });

    test('lineerle kesişme ~17’de: öncesinde önde, sonrasında geride', () {
      expect(at(10), greaterThan(start + 10));
      expect(at(30), lessThan(start + 30));
    });

    test('eski duvarın olduğu yerde hâlâ bol boşluk bırakır', () {
      // 134 bina → ilerleme 67; eskiden burada tavana çarpılıyordu.
      final v = at(67);
      expect(v, greaterThan(80));
      // Köyün ayak izi √N ile büyür: 134 bina ≈ 2.1·√134 ≈ 24 span ister.
      expect(v, greaterThan(24 * 3), reason: 'köye 3× boşluk kalmalı');
    });

    test('dar haritada güvenli — tavan başlangıcın altındaysa başlangıcı verir',
        () {
      expect(landExpansionTarget(start: 50, ceil: 40, progress: 999), 50);
    });

    test('negatif ilerleme başlangıcın altına düşürmez', () {
      expect(at(-10), closeTo(start, 1e-9));
    });
  });
}
