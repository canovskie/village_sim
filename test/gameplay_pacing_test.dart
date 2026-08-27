import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/core/resources.dart';
import 'package:village_sim/systems/event_system.dart';
import 'package:village_sim/systems/gameplay_pacing.dart';

void main() {
  group('boş bekleme sözleşmesi', () {
    test('ilk ve tekrarlanan küçük gündem 15 saniyeyi aşmaz', () {
      expect(
        GameplayPacing.firstPulseRealSeconds,
        lessThanOrEqualTo(GameplayPacing.maxEmptyRealSeconds),
      );
      expect(
        GameplayPacing.pulseNextMaxRealSeconds,
        lessThanOrEqualTo(GameplayPacing.maxEmptyRealSeconds),
      );
    });

    test('kuruluş koreografisi tek NPC yüzünden 15 saniyeyi aşmaz', () {
      expect(
        GameplayPacing.foundingBedTravelSimSeconds,
        lessThan(GameplayPacing.maxEmptyRealSeconds),
      );
      expect(
        GameplayPacing.foundingFirstNightSettleRealSeconds,
        lessThan(GameplayPacing.maxEmptyRealSeconds),
      );
    });

    test('bekleme kaçışı 4x hızı korur', () {
      expect(GameplayPacing.speedSteps, const [1.0, 2.0, 4.0, 0.0]);
    });
  });

  group('olaylar oyuncu kararıdır', () {
    test('dokuz temel olayın tamamı iki sonuç taşır', () {
      expect(EventSystem.events, hasLength(9));
      expect(EventSystem.events.every((event) => event.needsChoice), isTrue);
      expect(
        EventSystem.events.every((event) => event.choices!.length == 2),
        isTrue,
      );
    });

    test(
      'müdahale kaynak ister, sessizlik seçeneği her zaman uygulanabilir',
      () {
        final empty = ResourceBundle();
        final rich = ResourceBundle(
          food: 999,
          gold: 999,
          wood: 999,
          stone: 999,
          iron: 999,
          coal: 999,
        );
        for (final event in EventSystem.events) {
          final intervention = event.choices!.first;
          final passive = event.timeoutChoice!;
          expect(intervention.requiresResources, isTrue, reason: event.id);
          expect(intervention.canAfford(empty), isFalse, reason: event.id);
          expect(intervention.canAfford(rich), isTrue, reason: event.id);
          expect(passive.requiresResources, isFalse, reason: event.id);
          expect(passive.canAfford(empty), isTrue, reason: event.id);
        }
      },
    );
  });
}
