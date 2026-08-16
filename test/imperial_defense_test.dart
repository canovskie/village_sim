import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/systems/imperial.dart';

void main() {
  test('silah savunmayı araç gereçten daha fazla güçlendirir', () {
    final armed = imperialDefensePreview(
      guards: 2,
      population: 18,
      weapons: 3,
      iron: 0,
      wood: 0,
      stone: 0,
      favor: 0.5,
    );
    final tools = imperialDefensePreview(
      guards: 2,
      population: 18,
      weapons: 0,
      iron: 4,
      wood: 6,
      stone: 5,
      favor: 0.5,
    );
    expect(armed.chance, greaterThan(tools.chance));
    expect(tools.tools, greaterThan(0));
  });

  test('savunma gücü üst sınırı aşmaz', () {
    final result = imperialDefensePreview(
      guards: 100,
      population: 100,
      weapons: 100,
      iron: 100,
      wood: 100,
      stone: 100,
      favor: 1,
      regimeBonus: 1,
    );
    expect(result.chance, lessThanOrEqualTo(0.92));
  });
}
