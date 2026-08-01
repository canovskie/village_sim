// KÖYLÜNÜN AKLI — hakem sözleşmesi.
//
// Faz 1'in kalbi: sistemler köylüyü artık KAPMIYOR, teklif veriyor. Bu testin
// kilitlediği tasarım kararları:
//   • Tick sırası kaderi belirlemez — kazanan puan/önceliktir.
//   • Yüksek öncelik her zaman böler; aynı öncelikte BELİRGİN üstünlük gerekir
//     (yoksa köylü iki eşdeğer hedef arasında titrer).
//   • Tören dayatması hiçbir dürtüyle bölünmez (düğün alayı açlıktan dağılmaz).
//   • Kazanan teklifin begin()'i çalışır, KAYBEDENLERİNKİ ÇALIŞMAZ — bu kural
//     bozulursa iki sistem aynı köylüyü aynı anda sürer (eski çift-goTo bug'ı).
//   • Her davranışın oyuncuya gösterilebilir bir SEBEBİ vardır.

import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/systems/villager_mind.dart';

Bid _bid(
  IntentKind kind, {
  double score = 1.0,
  int priority = IntentPriority.routine,
  String reason = 'sebep',
  void Function()? begin,
}) =>
    Bid(
      kind: kind,
      score: score,
      reason: reason,
      priority: priority,
      begin: begin ?? () {},
    );

void main() {
  group('teklif yarışı', () {
    test('boştaki köylü en yüksek puanlı teklifi alır', () {
      final m = VillagerMind();
      m.deliberate([
        _bid(IntentKind.errand, score: 0.4),
        _bid(IntentKind.social, score: 0.9),
        _bid(IntentKind.hearth, score: 0.6),
      ]);
      expect(m.intent.kind, IntentKind.social);
    });

    test('yalnız KAZANANIN begin\'i çalışır', () {
      final m = VillagerMind();
      final ran = <IntentKind>[];
      m.deliberate([
        _bid(IntentKind.errand, score: 0.4, begin: () => ran.add(IntentKind.errand)),
        _bid(IntentKind.social, score: 0.9, begin: () => ran.add(IntentKind.social)),
      ]);
      expect(ran, [IntentKind.social]);
    });

    test('teklif listesi boşsa niyet değişmez', () {
      final m = VillagerMind();
      expect(m.deliberate([]), isFalse);
      expect(m.intent.kind, IntentKind.idle);
    });

    test('sıfır/negatif puanlı teklif kazanamaz', () {
      final m = VillagerMind();
      expect(m.deliberate([_bid(IntentKind.social, score: 0)]), isFalse);
      expect(m.intent.kind, IntentKind.idle);
    });

    test('düşük puanlı ama YÜKSEK öncelikli teklif kazanır', () {
      final m = VillagerMind();
      m.deliberate([
        _bid(IntentKind.social, score: 5.0, priority: IntentPriority.routine),
        _bid(IntentKind.flee, score: 0.2, priority: IntentPriority.danger),
      ]);
      expect(m.intent.kind, IntentKind.flee);
    });
  });

  group('bölünme kuralları', () {
    test('aynı öncelikte hafif üstünlük BÖLMEZ — titreme koruması', () {
      final m = VillagerMind();
      m.deliberate([_bid(IntentKind.errand, score: 1.0)]);
      // %10 daha iyi bir teklif yeterli olmamalı (marj %25).
      final changed = m.deliberate([_bid(IntentKind.social, score: 1.1)]);
      expect(changed, isFalse);
      expect(m.intent.kind, IntentKind.errand);
    });

    test('aynı öncelikte BELİRGİN üstünlük böler', () {
      final m = VillagerMind();
      m.deliberate([_bid(IntentKind.errand, score: 1.0)]);
      final changed = m.deliberate([_bid(IntentKind.social, score: 1.6)]);
      expect(changed, isTrue);
      expect(m.intent.kind, IntentKind.social);
    });

    test('yüksek öncelik puanı düşük olsa da böler', () {
      final m = VillagerMind();
      m.deliberate([_bid(IntentKind.errand, score: 2.0)]);
      m.deliberate([
        _bid(IntentKind.crime, score: 0.1, priority: IntentPriority.committed)
      ]);
      expect(m.intent.kind, IntentKind.crime);
    });

    test('düşük öncelik yüksek olanı ASLA bölmez', () {
      final m = VillagerMind();
      m.deliberate([
        _bid(IntentKind.work, score: 0.1, priority: IntentPriority.work)
      ]);
      m.deliberate([
        _bid(IntentKind.social, score: 99.0, priority: IntentPriority.routine)
      ]);
      expect(m.intent.kind, IntentKind.work);
    });
  });

  group('tören dayatması', () {
    test('dayatılan niyet hiçbir dürtüyle bölünmez', () {
      final m = VillagerMind();
      m.impose(IntentKind.ceremony, 'düğün alayında');
      final changed = m.deliberate([
        _bid(IntentKind.crime, score: 99.0, priority: IntentPriority.committed),
        _bid(IntentKind.flee, score: 99.0, priority: IntentPriority.danger),
      ]);
      expect(changed, isFalse);
      expect(m.intent.kind, IntentKind.ceremony);
    });

    test('tören bitince köylü yeniden karar verebilir', () {
      final m = VillagerMind();
      m.impose(IntentKind.ceremony, 'düğün alayında');
      m.clear();
      expect(m.intent.kind, IntentKind.idle);
      m.deliberate([_bid(IntentKind.errand, score: 0.5)]);
      expect(m.intent.kind, IntentKind.errand);
    });
  });

  group('dürtüler', () {
    test('dürtü birikir ve tavanı aşmaz', () {
      final m = VillagerMind();
      m.pushDrive(Drive.hunger, 0.5, 10.0);
      expect(m.drive(Drive.hunger), 1.0);
    });

    test('eylem dürtüyü giderir, taban 0\'ın altına inmez', () {
      final m = VillagerMind();
      m.setDrive(Drive.hunger, 0.4);
      m.satisfy(Drive.hunger, 0.9);
      expect(m.drive(Drive.hunger), 0.0);
    });

    test('en baskın dürtü doğru okunur — panelin "derdi ne" satırı', () {
      final m = VillagerMind();
      m.setDrive(Drive.hunger, 0.3);
      m.setDrive(Drive.chill, 0.7);
      m.setDrive(Drive.company, 0.5);
      expect(m.dominant, Drive.chill);
    });

    test('okunur özet önemsiz dürtüleri yazmaz', () {
      final m = VillagerMind();
      m.setDrive(Drive.hunger, 0.05);
      m.setDrive(Drive.fatigue, 0.60);
      final r = m.readout;
      expect(r.any((s) => s.contains('yorgunluk')), isTrue);
      expect(r.any((s) => s.contains('açlık')), isFalse);
    });

    test('dürtüler kayda yazılıp geri yüklenir', () {
      final m = VillagerMind();
      m.setDrive(Drive.hunger, 0.42);
      m.setDrive(Drive.unease, 0.13);
      final restored = VillagerMind()..restore(m.toJson());
      expect(restored.drive(Drive.hunger), closeTo(0.42, 1e-9));
      expect(restored.drive(Drive.unease), closeTo(0.13, 1e-9));
    });
  });

  group('aciliyet eğrisi', () {
    test('eşiğin altındaki dürtü teklif üretmez', () {
      expect(urgency(0.20), 0);
      expect(urgency(0.35), 0);
    });

    test('eşiğin üstünde hızla ağırlaşır — "biraz aç" ile "açlıktan ölüyor"'
        ' aynı değildir', () {
      final mild = urgency(0.50);
      final severe = urgency(0.95);
      expect(mild, greaterThan(0));
      expect(severe, greaterThan(mild * 4));
    });
  });

  group('serpinti', () {
    test('aynı köylü aynı niyette hep aynı eğilimi gösterir (deterministik)',
        () {
      expect(jitterFor(1234, IntentKind.errand),
          jitterFor(1234, IntentKind.errand));
    });

    test('farklı köylüler farklı eğilim gösterir — sürü hâlinde davranmazlar',
        () {
      final a = jitterFor(1, IntentKind.errand);
      final b = jitterFor(2, IntentKind.errand);
      final c = jitterFor(3, IntentKind.errand);
      expect({a, b, c}.length, greaterThan(1));
    });

    test('serpinti kararı ezmeyecek kadar küçük kalır', () {
      for (var seed = 0; seed < 200; seed++) {
        final j = jitterFor(seed, IntentKind.social);
        expect(j, inInclusiveRange(0.90, 1.10));
      }
    });
  });

  test('her niyetin ve dürtünün oyuncu-yüzü adı vardır', () {
    for (final k in IntentKind.values) {
      expect(intentLabel(k).isNotEmpty, isTrue);
    }
    for (final d in Drive.values) {
      expect(driveLabel(d).isNotEmpty, isTrue);
    }
  });

  test('sebepsiz teklif kurulamaz — her davranış açıklanabilir olmalı', () {
    expect(
      () => Bid(
        kind: IntentKind.errand,
        score: 1,
        reason: '',
        priority: IntentPriority.routine,
        begin: () {},
      ),
      throwsAssertionError,
    );
  });
}
