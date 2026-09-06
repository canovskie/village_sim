import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/core/resources.dart';
import 'package:village_sim/systems/events/event_system.dart';

bool _needsFiveVillagers(EventContext context) => context.population >= 5;

EventContext _context(int population) => EventContext(
  population: population,
  stockpile: ResourceBundle(),
  buildings: const [],
);

const _guarded = EventOutcome(
  id: 'guarded',
  title: 'Koşullu olay',
  icon: '!',
  message: 'Yalnız kalabalık köyde görünür.',
  category: EventCategory.neutral,
  canFire: _needsFiveVillagers,
);

const _open = EventOutcome(
  id: 'open',
  title: 'Koşulsuz olay',
  icon: '!',
  message: 'Her köyde görünür.',
  category: EventCategory.neutral,
);

void main() {
  group('EventSystem seçimi', () {
    test('olayın kendi canFire kapısını uygular', () {
      expect(
        EventSystem.rollFrom(const [_guarded], Random(1), _context(4)),
        isNull,
      );
      expect(
        EventSystem.rollFrom(const [_guarded], Random(1), _context(5))?.id,
        'guarded',
      );
    });

    test('koşulsuz olay açık kalır', () {
      expect(
        EventSystem.rollFrom(const [_open], Random(1), _context(0))?.id,
        'open',
      );
    });

    test('pozitif olmayan ağırlık seçim havuzuna girmez', () {
      const disabled = EventOutcome(
        id: 'disabled',
        title: 'Kapalı',
        icon: '!',
        message: 'Seçilmemeli.',
        category: EventCategory.neutral,
        weight: 0,
      );
      expect(
        EventSystem.rollFrom(
          const [disabled, _open],
          Random(1),
          _context(10),
        )?.id,
        'open',
      );
    });

    test('mesaj materyalizasyonu koşul ve seçim sözleşmesini korur', () {
      final shown = _guarded.withMessage('Gösterilen varyant.');
      expect(shown.message, 'Gösterilen varyant.');
      expect(shown.canFire, same(_guarded.canFire));
      expect(shown.weight, _guarded.weight);
    });
  });
}
