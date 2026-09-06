import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/systems/events/imperial.dart';

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

  test('savunma doktrinleri oranı ve can riskini farklılaştırır', () {
    final defense = imperialDefensePreview(
      guards: 1,
      population: 12,
      weapons: 0,
      iron: 2,
      wood: 12,
      stone: 0,
      favor: 0.5,
    );
    final line = imperialPlanPreview(
      plan: ImperialDefensePlan.holdLine,
      defense: defense,
      wood: 12,
    );
    final barricade = imperialPlanPreview(
      plan: ImperialDefensePlan.barricade,
      defense: defense,
      wood: 12,
    );
    final charge = imperialPlanPreview(
      plan: ImperialDefensePlan.counterCharge,
      defense: defense,
      wood: 12,
    );

    expect(barricade.chance, greaterThan(line.chance));
    expect(barricade.casualtyDelta, lessThan(line.casualtyDelta));
    expect(charge.chance, greaterThan(barricade.chance));
    expect(charge.casualtyDelta, greaterThan(line.casualtyDelta));
  });

  test('kerestesiz köy dar geçit kuramaz', () {
    final defense = imperialDefensePreview(
      guards: 1,
      population: 12,
      weapons: 0,
      iron: 0,
      wood: 0,
      stone: 0,
      favor: 0.5,
    );
    final plan = imperialPlanPreview(
      plan: ImperialDefensePlan.barricade,
      defense: defense,
      wood: 7,
    );
    expect(plan.available, isFalse);
    expect(plan.woodCost, 8);
  });
}
