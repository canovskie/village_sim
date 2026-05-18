import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/core/resources.dart';

void main() {
  group('ResourceBundle', () {
    test('add accumulates by kind', () {
      final b = ResourceBundle();
      b.add(ResourceKind.wood, 5);
      b.add(ResourceKind.wood, 3);
      b.add(ResourceKind.iron, 2);
      expect(b.wood, 8);
      expect(b.iron, 2);
      expect(b.stone, 0);
    });

    test('canAfford true when stock >= cost', () {
      final b = ResourceBundle(wood: 10, stone: 5);
      expect(b.canAfford(const ResourceCost(wood: 8, stone: 4)), isTrue);
      expect(b.canAfford(const ResourceCost(wood: 10, stone: 5)), isTrue);
    });

    test('canAfford false when any field short', () {
      final b = ResourceBundle(wood: 10, stone: 5);
      expect(b.canAfford(const ResourceCost(wood: 8, iron: 1)), isFalse);
      expect(b.canAfford(const ResourceCost(wood: 11)), isFalse);
    });

    test('spend deducts each kind exactly', () {
      final b = ResourceBundle(wood: 10, stone: 5, iron: 3);
      b.spend(const ResourceCost(wood: 4, stone: 2));
      expect(b.wood, 6);
      expect(b.stone, 3);
      expect(b.iron, 3);
    });

    test('formatMissing reports only deficits', () {
      final b = ResourceBundle(wood: 5);
      final missing = b.formatMissing(const ResourceCost(wood: 8, stone: 3));
      expect(missing, contains('3 🪵'));
      expect(missing, contains('3 🪨'));
    });

    test('formatMissing empty when affordable', () {
      final b = ResourceBundle(wood: 10, stone: 5);
      expect(b.formatMissing(const ResourceCost(wood: 4)), isEmpty);
    });

    test('clear zeros every kind', () {
      final b = ResourceBundle(wood: 5, stone: 3, gold: 99);
      b.clear();
      for (final k in ResourceKind.values) {
        expect(b.get(k), 0, reason: '$k must be 0 after clear');
      }
    });
  });

  group('ResourceCost.entries', () {
    test('skips zero fields', () {
      const c = ResourceCost(wood: 4, iron: 2);
      final entries = c.entries;
      expect(entries.length, 2);
      expect(entries.any((e) => e.$1 == ResourceKind.wood && e.$2 == 4), isTrue);
      expect(entries.any((e) => e.$1 == ResourceKind.iron && e.$2 == 2), isTrue);
    });

    test('isFree true for empty', () {
      expect(ResourceCost.empty.isFree, isTrue);
      expect(const ResourceCost(wood: 1).isFree, isFalse);
    });
  });
}
