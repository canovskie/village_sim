// EYLEM — Faz 3 sözleşmesi.
//
// Faz 3 öncesi bir varış noktası tek bir sayıydı (`dwell`): köylü yürüyor,
// varıyor, 8 saniye HİÇBİR ŞEY yapmadan bekliyor, gidiyordu. Oyuncunun gördüğü
// "bir yere yürüyüp orada duran adam"dı.
//
// Kilitlenen kararlar:
//   • Eylem bir ADIM DİZİSİdir; sırayla ilerler ve biter.
//   • Taşınan nesne yürüyüşü YAVAŞLATIR — yüklü köylü yakalanabilir olmalı.
//   • Her nesnenin oyuncu-yüzü adı vardır (elinde ne olduğu söylenebilmeli).

import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/characters/life_stage.dart';
import 'package:village_sim/characters/villager_type.dart';
import 'package:village_sim/entities/villager_entity.dart';
import 'package:village_sim/systems/villager_act.dart';

void main() {
  group('adım dizisi', () {
    test('eylem sırayla ilerler ve biter', () {
      final act = Act('kuyudan su', [
        const ActStep.goTo(5, 5),
        const ActStep.work(3),
        const ActStep.take(PropKind.bucketFull),
        const ActStep.goTo(9, 9),
        const ActStep.put(),
      ]);

      expect(act.done, isFalse);
      expect(act.current!.verb, ActVerb.goTo);
      act.advance();
      expect(act.current!.verb, ActVerb.work);
      act.advance();
      expect(act.current!.verb, ActVerb.take);
      act.advance();
      act.advance();
      expect(act.current!.verb, ActVerb.put);
      act.advance();
      expect(act.done, isTrue);
      expect(act.current, isNull);
    });

    test('ilerleyiş adım sayacını sıfırlar', () {
      final act = Act('x', [const ActStep.work(3), const ActStep.work(2)]);
      act.timer = 2.4;
      act.advance();
      expect(act.timer, 0);
    });

    test('reset eylemi başa alır', () {
      final act = Act('x', [const ActStep.work(1), const ActStep.put()]);
      act.advance();
      act.advance();
      expect(act.done, isTrue);
      act.reset();
      expect(act.done, isFalse);
      expect(act.cursor, 0);
    });

    test('boş eylem doğrudan bitmiştir — sonsuz askıda kalmaz', () {
      expect(Act('boş', const []).done, isTrue);
    });
  });

  group('nesneler', () {
    test('YÜK yürüyüşü yavaşlatır — yüklü hırsız yakalanabilir olmalı', () {
      expect(propSpeedFactor(PropKind.sack), lessThan(0.8));
      expect(propSpeedFactor(PropKind.bucketFull), lessThan(0.85));
      expect(propSpeedFactor(PropKind.none), 1.0);
    });

    test('boş kova ağır değildir, dolu kova ağırdır', () {
      expect(propSpeedFactor(PropKind.bucketEmpty), 1.0);
      expect(propSpeedFactor(PropKind.bucketFull),
          lessThan(propSpeedFactor(PropKind.bucketEmpty)));
    });

    test('hafif nesneler tek elle, yük iki elle taşınır', () {
      expect(propTwoHanded(PropKind.mug), isFalse);
      expect(propTwoHanded(PropKind.bread), isFalse);
      expect(propTwoHanded(PropKind.sack), isTrue);
      expect(propTwoHanded(PropKind.basket), isTrue);
    });

    test('her nesnenin oyuncu-yüzü adı vardır (none hariç)', () {
      for (final p in PropKind.values) {
        if (p == PropKind.none) continue;
        expect(propLabel(p).isNotEmpty, isTrue, reason: '$p adsız');
      }
    });

    test('eylemin en ağır nesnesi doğru bulunur', () {
      final act = Act('ambar', [
        const ActStep.take(PropKind.bread),
        const ActStep.take(PropKind.sack),
        const ActStep.take(PropKind.mug),
      ]);
      expect(act.heaviestProp, PropKind.sack);
    });

    test('nesne almayan eylemin ağır yükü yoktur', () {
      final act = Act('sohbet', [const ActStep.work(4)]);
      expect(act.heaviestProp, PropKind.none);
    });
  });

  group('yük gerçekten yavaşlatır (köylü üstünde)', () {
    VillagerEntity mk() => VillagerEntity(
          type: VillagerType.farmer,
          name: 'Deneme',
          male: true,
          startCol: 10,
          startRow: 10,
          ageDays: kAdultStartDay + 5,
          visualSeed: 3,
          personalitySeed: 3,
        );

    test('çuval taşıyan köylü boş elliden YAVAŞ yürür', () {
      final empty = mk();
      final laden = mk()..prop = PropKind.sack;
      expect(laden.speed, lessThan(empty.speed));
    });

    test('dolu kova boş kovadan yavaşlatır, boş kova yavaşlatmaz', () {
      final none = mk();
      final emptyBucket = mk()..prop = PropKind.bucketEmpty;
      final fullBucket = mk()..prop = PropKind.bucketFull;
      expect(emptyBucket.speed, none.speed);
      expect(fullBucket.speed, lessThan(emptyBucket.speed));
    });

    test('nesne bırakılınca hız geri gelir — kalıcı ceza değil', () {
      final v = mk();
      final base = v.speed;
      v.prop = PropKind.sack;
      expect(v.speed, lessThan(base));
      v.prop = PropKind.none;
      expect(v.speed, base);
    });
  });
}
