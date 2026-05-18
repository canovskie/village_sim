import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/systems/hay_processor.dart';
import 'package:village_sim/world/hay_entity.dart';

void main() {
  group('processHayPiles', () {
    test('3 pile → no bale produced', () {
      final hay = [
        HayEntity(type: HayType.pile, gridX: 5, gridY: 5),
        HayEntity(type: HayType.pile, gridX: 5.2, gridY: 5),
        HayEntity(type: HayType.pile, gridX: 5, gridY: 5.4),
      ];
      processHayPiles(hay);
      expect(hay.where((h) => h.isBale).length, 0);
      expect(hay.length, 3);
    });

    test('4 pile within 1.5 tile → 1 bale', () {
      final hay = [
        HayEntity(type: HayType.pile, gridX: 5, gridY: 5),
        HayEntity(type: HayType.pile, gridX: 5.5, gridY: 5),
        HayEntity(type: HayType.pile, gridX: 5, gridY: 5.5),
        HayEntity(type: HayType.pile, gridX: 5.5, gridY: 5.5),
      ];
      processHayPiles(hay);
      final bales = hay.where((h) => h.isBale).toList();
      expect(bales.length, 1);
    });

    test('4 distant piles do not cluster', () {
      final hay = [
        HayEntity(type: HayType.pile, gridX: 0, gridY: 0),
        HayEntity(type: HayType.pile, gridX: 5, gridY: 0),
        HayEntity(type: HayType.pile, gridX: 0, gridY: 5),
        HayEntity(type: HayType.pile, gridX: 5, gridY: 5),
      ];
      processHayPiles(hay);
      expect(hay.where((h) => h.isBale).length, 0);
    });

    test('piles consumed are removed', () {
      final hay = [
        for (int i = 0; i < 4; i++)
          HayEntity(type: HayType.pile, gridX: 5 + i * 0.2, gridY: 5),
      ];
      processHayPiles(hay);
      // 4 pile gitti, 1 bale geldi → toplam 1 entity.
      expect(hay.length, 1);
      expect(hay.first.isBale, isTrue);
    });

    test('8 piles → only 1 bale per call (rate-limited)', () {
      final hay = [
        for (int i = 0; i < 8; i++)
          HayEntity(type: HayType.pile, gridX: 5 + (i % 4) * 0.3,
                    gridY: 5 + (i ~/ 4) * 0.3),
      ];
      processHayPiles(hay);
      // Tek tick'te bir cluster işler.
      expect(hay.where((h) => h.isBale).length, 1);
      // İkinci çağrı kalan 4 pile'ı işler.
      processHayPiles(hay);
      expect(hay.where((h) => h.isBale).length, 2);
    });
  });
}
