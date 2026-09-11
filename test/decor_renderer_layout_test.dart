import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/rendering/decor_renderer.dart';
import 'package:village_sim/world/decor_entity.dart';

void main() {
  group('DecorRenderer zemin ankraji', () {
    test('fallen log varyantlarinin saydam alt boslugunu telafi eder', () {
      expect(
        DecorRenderer.groundingShiftFor(DecorKind.fallenLog, 0, 40),
        closeTo(5.9375, 0.0001),
      );
      expect(
        DecorRenderer.groundingShiftFor(DecorKind.fallenLog, 1, 40),
        closeTo(4.375, 0.0001),
      );
    });

    test('bush varyantlarini kendi gorunur tabanindan zemine oturtur', () {
      expect(
        DecorRenderer.groundingShiftFor(DecorKind.bushSmall, 0, 30),
        closeTo(5.390625, 0.0001),
      );
      expect(
        DecorRenderer.groundingShiftFor(DecorKind.bushSmall, 1, 30),
        closeTo(6.328125, 0.0001),
      );
      expect(
        DecorRenderer.groundingShiftFor(DecorKind.bushSmall, 2, 30),
        closeTo(6.5625, 0.0001),
      );
    });

    test('ankraj gerektirmeyen dekorlari degistirmez', () {
      expect(DecorRenderer.groundingShiftFor(DecorKind.stump, 0, 32), 0);
      expect(DecorRenderer.groundingShiftFor(DecorKind.daisy, 2, 20), 0);
    });

    test('gecersiz varyanti en yakin gecerli ankraja sinirlar', () {
      expect(
        DecorRenderer.groundingShiftFor(DecorKind.fallenLog, 99, 40),
        closeTo(4.375, 0.0001),
      );
    });
  });
}
