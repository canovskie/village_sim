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

    test('rutin köy cümlesi elenir, kayda değer haber kısa sırada korunur', () {
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
        isTrue,
      );
      expect(queue.pending, hasLength(1));
    });

    test('dolu sırada önemli haberler okunmadan atılmaz', () {
      final queue = VillageNewsQueue(maxPending: 2);
      queue.add(item('Aktif kriz.', VillageNewsPriority.urgent));
      final importantA = item('Önemli bir.', VillageNewsPriority.important);
      final importantB = item('Önemli iki.', VillageNewsPriority.important);
      final importantC = item('Önemli üç.', VillageNewsPriority.important);
      queue.add(importantA);
      queue.add(importantB);

      expect(queue.add(importantC).accepted, isTrue);
      expect(queue.pending.map((news) => news.rawMessage), [
        'Önemli bir.',
        'Önemli iki.',
        'Önemli üç.',
      ]);
    });
  });
  test('doğum, aile ve son hane uyarısı boş ekranda kaybolmaz', () {
    for (final message in [
      '👶 Ayşe doğdu. Fatma sabaha kadar uyumadı, Ali kapıda bekledi.',
      '👶 Fatma ile Ali’nin çocuğu oldu. Adını Ayşe koydular.',
      '💞 Ayşe & Ali aile kurdu.',
      '🚪 Kaya Hanesi arabalarını yükledi. Yarın öbür gün yola çıkarlar.',
      '💔 Kaya Hanesi çekip gitti. Bir daha dönmeyecekler.',
    ]) {
      final news = VillageNews.fromMessage(message);
      expect(news.topic, VillageNewsTopic.people);
      expect(
        news.priority.index,
        greaterThanOrEqualTo(VillageNewsPriority.important.index),
      );
      expect(VillageNewsQueue().add(news).accepted, isTrue, reason: message);
    }
  });

  test('eksik malzeme sistem cevabıdır; Kara adı hava konusu üretmez', () {
    final error = VillageNews.fromMessage('Eksik malzeme: 10 🪵');
    expect(error.topic, VillageNewsTopic.system);
    expect(error.tone, VillageNewsTone.caution);
    expect(VillageNewsQueue().add(error).accepted, isTrue);
    expect(
      VillageNews.fromMessage('Kara Hanesi barıştı.').topic,
      VillageNewsTopic.people,
    );
    expect(
      VillageNews.fromMessage('Kar yağmaya başladı.').topic,
      VillageNewsTopic.weather,
    );
  });

  test('arka arkaya gelen dört acil haberin hepsi okunur', () {
    final queue = VillageNewsQueue(maxPending: 2);
    final items = List.generate(
      4,
      (i) => VillageNews.fromMessage('Yangında $i numaralı köylü öldü.'),
    );
    for (final item in items) {
      expect(queue.add(item).accepted, isTrue);
    }
    for (final item in items) {
      expect(queue.active, same(item));
      queue.completeActive();
    }
    expect(queue.active, isNull);
  });

  test('gizlenen süre bütçeden düşmez, sıradaki haber tam süre alır', () {
    final queue = VillageNewsQueue();
    final first = VillageNews.fromMessage('Divan karar bekliyor.');
    final next = VillageNews.fromMessage('Bir başka dilekçe var.');
    queue.add(first);
    queue.add(next);
    queue.advance(2, visible: true);
    final remaining = queue.remainingFraction;
    queue.advance(60, visible: false);
    expect(queue.active, same(first));
    expect(queue.remainingFraction, remaining);
    queue.advance(
      first.readDuration.inMilliseconds / 1000 - 2 + .01,
      visible: true,
    );
    expect(queue.active, same(next));
    expect(queue.remainingFraction, 1);
  });

  test('acil haberin kestiği önemli haber kalan süresiyle döner', () {
    final queue = VillageNewsQueue();
    final first = VillageNews.fromMessage('Divan karar bekliyor.');
    queue.add(first);
    queue.advance(2, visible: true);
    final remaining = queue.remainingFraction;
    queue.add(VillageNews.fromMessage('Köyde yangın çıktı.'));
    queue.completeActive();
    expect(queue.active, same(first));
    expect(queue.remainingFraction, remaining);
  });

  test(
    'olay kimliği varyantı ve yeni gösterimi bekletir, başka kişiyi engellemez',
    () {
      final queue = VillageNewsQueue(repeatDelay: const Duration(seconds: 30));
      VillageNews item(String body, String key) => VillageNews.fromMessage(
        body,
        eventKey: key,
        priority: VillageNewsPriority.important,
      );
      queue.add(item('Ayşe doğdu.', 'birth.1'));
      expect(
        queue.add(item('Evde bir ses daha var.', 'birth.1')).accepted,
        isFalse,
      );
      queue.completeActive();
      expect(
        queue.add(item('Ayşe bugün dünyaya geldi.', 'birth.1')).accepted,
        isFalse,
      );
      expect(queue.add(item('Ayşe doğdu.', 'birth.2')).accepted, isTrue);
      queue.completeActive();
      queue.advance(30, visible: false);
      expect(
        queue.add(item('Ayşe bugün dünyaya geldi.', 'birth.1')).accepted,
        isTrue,
      );
    },
  );

  test(
    'aynı olay ağırlaşırsa tekrar bekleme süresi acil uyarıyı engellemez',
    () {
      final queue = VillageNewsQueue();
      queue.add(
        VillageNews.fromMessage(
          'Meydan gergin.',
          eventKey: 'unrest',
          priority: VillageNewsPriority.important,
        ),
      );
      queue.completeActive();
      expect(
        queue
            .add(
              VillageNews.fromMessage(
                'Köy dağılıyor.',
                eventKey: 'unrest',
                priority: VillageNewsPriority.urgent,
              ),
            )
            .accepted,
        isTrue,
      );
    },
  );

  test('gündelik tampon sınırlıdır ve acil haberin yerini alamaz', () {
    final queue = VillageNewsQueue(maxPending: 2);
    queue.add(VillageNews.fromMessage('Köyde yangın çıktı.'));
    for (var i = 0; i < 10; i++) {
      queue.add(VillageNews.fromMessage('Yolcu $i geldi.'));
    }
    expect(queue.pending, hasLength(2));
    expect(queue.active!.priority, VillageNewsPriority.urgent);
  });
}
