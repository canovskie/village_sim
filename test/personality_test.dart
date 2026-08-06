import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/characters/personality.dart';

void main() {
  test('Personality.fromSeed deterministik — aynı seed aynı kişilik', () {
    final a = Personality.fromSeed(12345);
    final b = Personality.fromSeed(12345);
    expect(a.traits, b.traits);
    expect(a.likes, b.likes);
    expect(a.backstory, b.backstory);
  });

  test('Farklı seed genelde farklı kişilik üretir', () {
    final seen = <String>{};
    for (var s = 0; s < 50; s++) {
      final p = Personality.fromSeed(s * 7919 + 1);
      seen.add('${p.traits.map((t) => t.name).join(",")}|${p.likes.name}');
    }
    // 50 seed'den makul çeşitlilik beklenir (en az 10 farklı kombinasyon).
    expect(seen.length, greaterThan(10));
  });

  test('Üretilen kişilik geçerli — 1-2 mizaç, dolu künye', () {
    for (var s = 0; s < 200; s++) {
      final p = Personality.fromSeed(s);
      expect(p.traits.length, inInclusiveRange(1, 2));
      expect(p.traits.toSet().length, p.traits.length); // mizaçlar farklı
      expect(p.backstory.trim(), isNotEmpty);
      expect(Likes.values, contains(p.likes));
    }
  });
}
