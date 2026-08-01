import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/core/resources.dart';
import 'package:village_sim/world/loot_cache.dart';

void main() {
  group('lootTrace — taze toprak ele verir, zamanla kapanır', () {
    test('gömüldüğü an iz tam', () {
      expect(lootTrace(0, 100), 1.0);
    });

    test('süre dolunca iz kapanır', () {
      expect(lootTrace(100, 100), 0.0);
      expect(lootTrace(500, 100), 0.0, reason: 'negatife düşmemeli');
    });

    test('arada doğrusal iner', () {
      expect(lootTrace(25, 100), closeTo(0.75, 1e-9));
      expect(lootTrace(50, 100), closeTo(0.50, 1e-9));
    });

    test('fade 0 ise iz yok (sıfıra bölme yok)', () {
      expect(lootTrace(0, 0), 0.0);
    });

    // Hırsızın asıl hatası nereye gömdüğü değil, GÖRÜLMESİ.
    test('görülerek gömülen zulanın izi hiç tam kapanmaz', () {
      expect(lootTrace(500, 100, witnessed: true), kWitnessedTraceFloor);
      expect(lootTrace(500, 100, witnessed: false), 0.0);
    });

    test('görülmüş olmak TAZE izi düşürmez (taban, tavan değil)', () {
      expect(lootTrace(0, 100, witnessed: true), 1.0);
    });
  });

  group('lootFindRadius', () {
    test('taze iz geniş, kapanmış iz dar', () {
      final fresh = lootFindRadius(1.0);
      final cold = lootFindRadius(0.0);
      expect(fresh, greaterThan(cold));
      expect(fresh, closeTo(3.6, 1e-9));
    });

    test('kapanmış izde bile sıfır DEĞİL — üstüne basan bulur', () {
      expect(lootFindRadius(0.0), greaterThan(0.0));
    });

    test('tetikte muhafız izi büyütür', () {
      expect(lootFindRadius(0.5, alert: 1.5),
          greaterThan(lootFindRadius(0.5)));
    });
  });

  group('LootCache', () {
    test('derinlik izo sıralaması için x+y', () {
      final c = LootCache(
        gridX: 3,
        gridY: 4,
        kind: ResourceKind.food,
        amount: 9,
        culpritName: 'Hüseyin',
      );
      expect(c.depth, 7);
    });

    test('fail referansı koparılabilir ama mal durur', () {
      final c = LootCache(
        gridX: 1,
        gridY: 1,
        kind: ResourceKind.wood,
        amount: 12,
        culpritName: 'Mehmet',
        culprit: Object(),
      );
      c.culprit = null;
      expect(c.amount, 12, reason: 'fail gitse de mal toprakta kalmalı');
      expect(c.culpritName, 'Mehmet', reason: 'vakanüvis bir ad yazabilmeli');
    });
  });
}
