import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/world/day_night_cycle.dart';

void main() {
  test('night is shorter while a full day remains four minutes', () {
    final cycle = DayNightCycle(timeOfDay: 0.75);

    for (int i = 0; i < 960; i++) {
      cycle.update(0.1);
    }
    expect(cycle.timeOfDay, closeTo(0.25, 0.001));

    for (int i = 0; i < 1440; i++) {
      cycle.update(0.1);
    }
    expect(cycle.timeOfDay, closeTo(0.75, 0.001));
  });

  test('kuruluş gecesi şafağa bir kez sıçrar, sonraki çevrim normal akar', () {
    final cycle = DayNightCycle(timeOfDay: 0.75);
    var mornings = 0;
    cycle.onMorning = () => mornings++;

    // Önce gece kenarını kur; gerçek sahnede uyku hedefleri burada atanır.
    cycle.update(0.1);
    cycle.skipNightToMorning();
    expect(cycle.timeOfDay, 0.32);
    expect(mornings, 1);

    // Atlamanın sonraki tam gün/gece çevrimini kısaltmadığını doğrula.
    for (int i = 0; i < 2400; i++) {
      cycle.update(0.1);
    }
    expect(cycle.timeOfDay, closeTo(0.32, 0.001));
    expect(mornings, 2);
  });
}
