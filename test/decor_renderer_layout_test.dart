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

    test('diger dekorlarin mevcut ankrajini degistirmez', () {
      expect(DecorRenderer.groundingShiftFor(DecorKind.stump, 0, 32), 0);
      expect(DecorRenderer.groundingShiftFor(DecorKind.bushSmall, 2, 30), 0);
    });

    test('gecersiz varyanti en yakin gecerli ankraja sinirlar', () {
      expect(
        DecorRenderer.groundingShiftFor(DecorKind.fallenLog, 99, 40),
        closeTo(4.375, 0.0001),
      );
    });
  });
}
