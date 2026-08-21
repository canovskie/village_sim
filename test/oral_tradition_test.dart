import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/systems/law_book.dart';
import 'package:village_sim/systems/oral_tradition.dart';

void main() {
  LawDef law(String id) => LawBook.byId(id)!;

  test('Belediye öncesi kararlar seçenekleriyle ayrı ocak sözü olur', () {
    final memory = {
      OralTradition.decisionFlag('crimeWave', 0),
      OralTradition.decisionFlag('crimeWave', 2),
      OralTradition.decisionFlag('dissent', 1),
      'crime.watch',
    };
    expect(OralTradition.decisionCount(memory), 3);
  });

  test('yaşanmış gece nöbeti ilgili fermanı töreye bağlar', () {
    const memory = {'crime.watch'};
    expect(OralTradition.supports(law('nizam.watch'), memory), isTrue);
    expect(OralTradition.supports(law('neighborliness'), memory), isFalse);
    expect(
      OralTradition.supportLine(law('nizam.watch'), memory),
      contains('gece nöbeti'),
    );
  });

  test('her hafıza izi rastgele bir kanuna dayanak olmaz', () {
    const memory = {'fields.neglected', 'road.closed'};
    for (final l in kLawBook) {
      expect(OralTradition.supports(l, memory), isFalse, reason: l.id);
    }
  });
}
