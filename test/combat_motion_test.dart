import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/systems/combat_motion.dart';

void main() {
  test('NPC düellosu yaklaşır, temas eder ve ayrılır', () {
    final approach = npcCombatMotion(
      elapsed: .2,
      duration: 5,
      feud: false,
      aStarts: true,
    );
    final exchange = npcCombatMotion(
      elapsed: 1.25,
      duration: 5,
      feud: false,
      aStarts: true,
    );
    final ending = npcCombatMotion(
      elapsed: 4.8,
      duration: 5,
      feud: false,
      aStarts: true,
    );

    expect(approach.aStriking, isFalse);
    expect(exchange.aStriking || exchange.bStriking, isTrue);
    expect(ending.aAdvance, isNegative);
    expect(ending.bAdvance, isNegative);
  });

  test('temasta yalnız saldıranın karşısındaki sendeleyebilir', () {
    NpcCombatMotion? contact;
    for (var i = 0; i <= 200; i++) {
      final motion = npcCombatMotion(
        elapsed: i / 200 * 5,
        duration: 5,
        feud: false,
        aStarts: true,
      );
      if (motion.impact) {
        contact = motion;
        break;
      }
    }

    expect(contact, isNotNull);
    expect(contact!.aHit == contact.bHit, isFalse);
    expect(contact.aStriking == contact.bStriking, isFalse);
  });

  test('kan davası sıradan kavgadan daha derin hamle üretir', () {
    double peak(bool feud) {
      var result = 0.0;
      for (var i = 0; i <= 200; i++) {
        final motion = npcCombatMotion(
          elapsed: i / 200 * 5,
          duration: 5,
          feud: feud,
          aStarts: true,
        );
        if (motion.aAdvance > result) result = motion.aAdvance;
        if (motion.bAdvance > result) result = motion.bAdvance;
      }
      return result;
    }

    expect(peak(true), greaterThan(peak(false)));
  });
}
