import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/systems/events/crime_system.dart';
import 'package:village_sim/text/voice.dart';

void main() {
  const context = VoiceCtx(
    seed: 7,
    name: 'İlyas',
    other: 'Ayşe',
    extra: {'yer': 'Ambar'},
  );

  test('suç metni havuzları dolu ve dokunmuş metin üretir', () {
    for (final crime in CrimeSystem.all) {
      final pools = [
        crime.hintPool,
        crime.deedPool,
        crime.annalPool,
        crime.caughtAnnalPool,
      ];
      for (final pool in pools) {
        expect(pool, isNotEmpty, reason: crime.kind.name);
        for (var seed = 0; seed < 12; seed++) {
          final text = Voice.say(pool, context.copyWith(seed: seed));
          expect(text.trim(), isNotEmpty, reason: crime.kind.name);
          expect(text.contains(RegExp(r'[{}]')), isFalse);
        }
      }
    }
  });
}
