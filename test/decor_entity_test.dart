import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/world/decor_entity.dart';

void main() {
  DecorEntity decor() => DecorEntity(
    col: 4,
    row: 7,
    kind: DecorKind.daisy,
    variant: 0,
    jitterX: 0.5,
    jitterY: 0.5,
    swaySeed: 11,
  );

  group('DecorEntity crush lifecycle', () {
    test('ezilmemis dekor ilerlemez', () {
      final entity = decor();

      expect(entity.crushed, isFalse);
      expect(entity.crushProgress, 0);
      expect(entity.tickCrush(DecorEntity.kCrushDuration), isFalse);
      expect(entity.crushProgress, 0);
    });

    test('startCrush idempotenttir ve devam eden animasyonu sifirlamaz', () {
      final entity = decor()..startCrush();

      expect(entity.crushed, isTrue);
      expect(entity.tickCrush(DecorEntity.kCrushDuration * 0.4), isFalse);
      expect(entity.crushProgress, closeTo(0.4, 1e-9));

      entity.startCrush();

      expect(entity.crushProgress, closeTo(0.4, 1e-9));
      expect(entity.tickCrush(DecorEntity.kCrushDuration * 0.6), isTrue);
      expect(entity.crushProgress, 1);
    });

    test('tam 0.85 saniyelik sinirda tamamlanir', () {
      final entity = decor()..startCrush();

      expect(DecorEntity.kCrushDuration, 0.85);
      expect(entity.tickCrush(DecorEntity.kCrushDuration - 0.001), isFalse);
      expect(entity.crushProgress, lessThan(1));
      expect(entity.tickCrush(0.001), isTrue);
      expect(entity.crushProgress, 1);
    });

    test('ilerleme animasyon araliginin iki ucunda clamp edilir', () {
      final entity = decor()..startCrush();

      expect(entity.tickCrush(-DecorEntity.kCrushDuration), isFalse);
      expect(entity.crushProgress, 0);

      expect(entity.tickCrush(DecorEntity.kCrushDuration * 3), isTrue);
      expect(entity.crushProgress, 1);

      expect(entity.tickCrush(DecorEntity.kCrushDuration), isTrue);
      expect(entity.crushProgress, 1);
    });
  });
}
