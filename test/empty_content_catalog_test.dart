import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/core/resources.dart';
import 'package:village_sim/systems/events/event_system.dart';
import 'package:village_sim/systems/governance/petition_system.dart';

void main() {
  test('olay kataloğu bilinçli olarak boş kalır', () {
    expect(EventSystem.events, isEmpty);
  });

  test('boş katalog seçicileri güvenle null döndürür', () {
    final event = EventSystem.roll(
      Random(1),
      EventContext(
        population: 0,
        stockpile: ResourceBundle(),
        buildings: const [],
      ),
    );
    final petition = PetitionSystem.roll(
      const PetitionContext(
        population: 0,
        adults: 0,
        food: 0,
        gold: 0,
        morale: 0.5,
        hasChurch: false,
      ),
      Random(1),
    );

    expect(event, isNull);
    expect(petition, isNull);
    expect(PetitionSystem.debugRandom(Random(1)), isNotNull);
  });
}
