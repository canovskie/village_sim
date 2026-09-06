import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/systems/events/village_news.dart';

void main() {
  group('haber metni', () {
    test('başlığı, gövdeyi ve konuyu eski bildirimden çıkarır', () {
      final news = VillageNews.fromMessage(
        '❄️ İlk don — Çatılar kırağı tuttu.',
      );

      expect(news.headline, 'İlk don');
      expect(news.body, 'Çatılar kırağı tuttu.');
      expect(news.topic, VillageNewsTopic.weather);
    });

    test('ağır kayıp acil asayiş haberi olur', () {
      final news = VillageNews.fromMessage('☠ Yangında bir köylü öldü.');

      expect(news.topic, VillageNewsTopic.safety);
      expect(news.tone, VillageNewsTone.critical);
      expect(news.priority, VillageNewsPriority.urgent);
      expect(
        news.readDuration,
        greaterThanOrEqualTo(const Duration(seconds: 6)),
      );
    });

    test('yeni içerik otomatik yorumu açık alanlarla geçersiz kılabilir', () {
      final news = VillageNews.fromMessage(
        'Köy kararı bekliyor.',
        headline: 'Ocağın Payı',
        topic: VillageNewsTopic.council,
        tone: VillageNewsTone.caution,
        priority: VillageNewsPriority.important,
        stamp: 'KIŞ · GÜN 14',
      );

      expect(news.headline, 'Ocağın Payı');
      expect(news.topic, VillageNewsTopic.council);
      expect(news.stamp, 'KIŞ · GÜN 14');
    });

    test('yeni katalog haberi başlık ve gövdeyi doğrudan kurabilir', () {
      final news = VillageNews.compose(
        headline: 'Değirmenin İlk Unu',
        body: 'Taşlar döndü, ilk çuval ambara indi.',
        topic: VillageNewsTopic.work,
        tone: VillageNewsTone.favorable,
        priority: VillageNewsPriority.noteworthy,
      );

      expect(news.headline, 'Değirmenin İlk Unu');
      expect(news.body, 'Taşlar döndü, ilk çuval ambara indi.');
      expect(news.dedupeKey, isNotEmpty);
    });
  });

  group('haber sırası', () {
    VillageNews item(String text, VillageNewsPriority priority) =>
        VillageNews.fromMessage(text, priority: priority);

    test('aynı haberi aktifken veya sıradayken çoğaltmaz', () {
      final queue = VillageNewsQueue();
      final first = item(
        'Divan karar bekliyor.',
        VillageNewsPriority.important,
      );

      expect(queue.add(first).accepted, isTrue);
      expect(queue.add(first).accepted, isFalse);
      expect(queue.pending, isEmpty);
    });

    test('rutin köy cümlesini basmaz, doğrudan oyun cevabını korur', () {
      final queue = VillageNewsQueue();
      final ambient = item('Tarla sürülüyor.', VillageNewsPriority.routine);
      final feedback = VillageNews.fromMessage(
        'Hız: 2×',
        topic: VillageNewsTopic.system,
        priority: VillageNewsPriority.routine,
      );

      expect(queue.add(ambient).accepted, isFalse);
      expect(queue.add(feedback).accepted, isTrue);
      expect(queue.active, same(feedback));
    });

    test('acil haber sıradan haberi keser ve eski satırı geri getirmez', () {
      final queue = VillageNewsQueue();
      final routine = item('Bir yolcu göründü.', VillageNewsPriority.routine);
      final urgent = item('Köyde yangın çıktı.', VillageNewsPriority.urgent);

      queue.add(routine);
      final update = queue.add(urgent);

      expect(update.activeChanged, isTrue);
      expect(queue.active, same(urgent));
      expect(queue.pending, isEmpty);
      expect(queue.completeActive(), isNull);
    });

    test('önemli haber kesilirse acil haberden sonra sürer', () {
      final queue = VillageNewsQueue();
      final important = item(
        'Divan karar bekliyor.',
        VillageNewsPriority.important,
      );
      final urgent = item('Köyde yangın çıktı.', VillageNewsPriority.urgent);

      queue.add(important);
      queue.add(urgent);

      expect(queue.active, same(urgent));
      expect(queue.pending, [important]);
      expect(queue.completeActive(), same(important));
    });

    test('rutin ve kayda değer haberler ekran doluyken sıra oluşturmaz', () {
      final queue = VillageNewsQueue();
      queue.add(item('Aktif haber.', VillageNewsPriority.noteworthy));

      expect(
        queue.add(item('Sıradan.', VillageNewsPriority.routine)).accepted,
        isFalse,
      );
      expect(
        queue
            .add(item('Bir gelişme.', VillageNewsPriority.noteworthy))
            .accepted,
        isFalse,
      );
      expect(queue.pending, isEmpty);
    });

    test('dolu sırada en düşük önemi dışarıda bırakır', () {
      final queue = VillageNewsQueue(maxPending: 2);
      queue.add(item('Aktif kriz.', VillageNewsPriority.urgent));
      final importantA = item('Önemli bir.', VillageNewsPriority.important);
      final importantB = item('Önemli iki.', VillageNewsPriority.important);
      final importantC = item('Önemli üç.', VillageNewsPriority.important);
      queue.add(importantA);
      queue.add(importantB);

      expect(queue.add(importantC).accepted, isFalse);
      expect(queue.pending.map((news) => news.rawMessage), [
        'Önemli bir.',
        'Önemli iki.',
      ]);
    });
  });
}
