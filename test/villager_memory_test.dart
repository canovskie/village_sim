// KÖYLÜNÜN HAFIZASI — Faz 2 sözleşmesi.
//
// Kilitlenen tasarım kararları:
//   • GÖZÜYLE GÖREN ile KULAKTAN DUYAN aynı değil — yalnız birincisi ihbar
//     edebilir. Bu ayrım olmadan tek bir söylenti köyde yakalanma zincirine
//     dönerdi.
//   • Anılar SÖNER, kanaat KALIR. "Ne yaptığını hatırlamıyorum ama ondan
//     hoşlanmıyorum" — insani ve ucuz.
//   • Aynı olay hafızayı kopyalarla doldurmaz (tek kavga = tek anı).
//   • Hafıza sonsuz değil; taştığında EN ZAYIF anı düşer, en eski değil —
//     dün görülen cinayet, bugünkü atışmadan kalıcıdır.

import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/systems/villager_memory.dart';

/// Özne yerine geçen sahte kimlik (gerçek köylüye bağımlı olmadan test).
class _Who {
  final String name;
  _Who(this.name);
}

Recollection _rec(
  Notion kind, {
  Object? subject,
  String name = 'Biri',
  double at = 0,
  bool firsthand = true,
  double strength = 1.0,
}) =>
    Recollection(
      kind: kind,
      subject: subject,
      subjectName: name,
      x: 0,
      y: 0,
      at: at,
      firsthand: firsthand,
      strength: strength,
    );

void main() {
  group('gözüyle gören / kulaktan duyan', () {
    test('gözüyle görülen taze suç ihbar edilebilir', () {
      final m = VillagerMemory();
      final who = _Who('Fail');
      m.remember(_rec(Notion.crime, subject: who));
      expect(m.strongestReportable, isNotNull);
    });

    test('KULAKTAN DUYULAN suç ihbar edilemez — söylenti tutuklatmaz', () {
      final m = VillagerMemory();
      m.remember(_rec(Notion.crime, subject: _Who('Fail'), firsthand: false));
      expect(m.strongestReportable, isNull);
    });

    test('öznesi olmayan suç ihbar edilemez — meçhul fail', () {
      final m = VillagerMemory();
      m.remember(_rec(Notion.crime));
      expect(m.strongestReportable, isNull);
    });

    test('sönmüş anı ihbar edilemez — kimse eski bir gölgeyi ihbar etmez', () {
      final m = VillagerMemory();
      m.remember(_rec(Notion.crime, subject: _Who('Fail'), strength: 0.2));
      expect(m.strongestReportable, isNull);
    });

    test('kulaktan duyulan anı yine de anlatılabilir — dedikodu yayılır', () {
      final m = VillagerMemory();
      m.remember(_rec(Notion.crime, subject: _Who('Fail'), firsthand: false));
      expect(m.strongestTellable, isNotNull);
    });
  });

  group('kanaat', () {
    test('suç görmek özneye dair kanaati düşürür', () {
      final m = VillagerMemory();
      final who = _Who('Fail');
      m.remember(_rec(Notion.crime, subject: who));
      expect(m.opinionOf(who), lessThan(-0.2));
    });

    test('iyilik görmek kanaati yükseltir', () {
      final m = VillagerMemory();
      final who = _Who('Cömert');
      m.remember(_rec(Notion.kindness, subject: who));
      expect(m.opinionOf(who), greaterThan(0.2));
    });

    test('kulaktan duymak kanaati DAHA AZ oynatır', () {
      final seen = VillagerMemory();
      final heard = VillagerMemory();
      final a = _Who('Fail');
      final b = _Who('Fail');
      seen.remember(_rec(Notion.crime, subject: a));
      heard.remember(_rec(Notion.crime, subject: b, firsthand: false));
      expect(heard.opinionOf(b).abs(), lessThan(seen.opinionOf(a).abs()));
    });

    test('kanaat sınırların dışına taşmaz', () {
      final m = VillagerMemory();
      final who = _Who('Fail');
      for (var i = 0; i < 20; i++) {
        m.nudgeOpinion(who, -0.5);
      }
      expect(m.opinionOf(who), -1.0);
    });
  });

  group('sönme', () {
    test('anı söner ve sonunda düşer, KANAAT kalır', () {
      final m = VillagerMemory();
      final who = _Who('Fail');
      m.remember(_rec(Notion.crime, subject: who));
      final opinionBefore = m.opinionOf(who);

      m.fade(3.0); // üç gün
      expect(m.recollections, isEmpty, reason: 'anı sönmeliydi');
      // Kanaat çok daha yavaş soğur — hâlâ belirgin biçimde negatif.
      expect(m.opinionOf(who), lessThan(0));
      expect(m.opinionOf(who).abs(), lessThan(opinionBefore.abs()));
    });

    test('kanaat yeterince uzun sürede nötre döner', () {
      final m = VillagerMemory();
      final who = _Who('Fail');
      m.nudgeOpinion(who, -0.4);
      m.fade(60.0);
      expect(m.opinionOf(who), 0);
    });

    test('sıfır süre hiçbir şeyi değiştirmez', () {
      final m = VillagerMemory();
      m.remember(_rec(Notion.crime, subject: _Who('Fail')));
      m.fade(0);
      expect(m.recollections.length, 1);
    });
  });

  group('kapasite ve tekrar', () {
    test('aynı olayı tekrar görmek yeni anı YARATMAZ, tazeler', () {
      final m = VillagerMemory();
      final who = _Who('Fail');
      final first = m.remember(_rec(Notion.crime, subject: who, at: 0));
      final second =
          m.remember(_rec(Notion.crime, subject: who, at: 5, strength: 1.0));
      expect(first, isTrue, reason: 'ilki yeni anıdır');
      expect(second, isFalse, reason: 'aynı olay ikinci kez kaydedilmemeli');
      expect(m.recollections.length, 1);
    });

    test('pencere dışındaki aynı tür olay AYRI anıdır', () {
      final m = VillagerMemory();
      final who = _Who('Fail');
      m.remember(_rec(Notion.crime, subject: who, at: 0));
      m.remember(_rec(Notion.crime, subject: who, at: 500));
      expect(m.recollections.length, 2);
    });

    test('hafıza taşınca EN ZAYIF anı düşer (en eski değil)', () {
      final m = VillagerMemory();
      // Güçlü ve eski bir anı.
      m.remember(_rec(Notion.death, subject: _Who('Merhum'), at: 0));
      // Kapasiteyi zayıf anılarla doldur.
      for (var i = 0; i < VillagerMemory.kCapacity + 3; i++) {
        m.remember(_rec(Notion.brawl,
            subject: _Who('Kavgacı$i'), at: 100.0 * (i + 1), strength: 0.3));
      }
      expect(m.recollections.length, VillagerMemory.kCapacity);
      expect(m.recollections.any((r) => r.kind == Notion.death), isTrue,
          reason: 'güçlü eski anı zayıflar uğruna düşmemeliydi');
    });
  });

  group('sorgular', () {
    test('suçlu olarak hatırlanan kişi şüpheli sayılır', () {
      final m = VillagerMemory();
      final fail = _Who('Fail');
      final masum = _Who('Masum');
      m.remember(_rec(Notion.crime, subject: fail));
      expect(m.suspects(fail), isTrue);
      expect(m.suspects(masum), isFalse);
    });

    test('bilinen anı tekrar anlatılmaz', () {
      final m = VillagerMemory();
      final who = _Who('Fail');
      expect(m.knows(Notion.crime, who), isFalse);
      m.remember(_rec(Notion.crime, subject: who));
      expect(m.knows(Notion.crime, who), isTrue);
    });

    test('okunur özet kulaktan duyulanı açıkça işaretler', () {
      final m = VillagerMemory();
      m.remember(_rec(Notion.crime,
          subject: _Who('Fail'), name: 'Fail', firsthand: false));
      expect(m.readout().first, contains('kulaktan'));
    });
  });

  test('her anı türünün etiketi ve etkisi tanımlı', () {
    for (final n in Notion.values) {
      expect(notionLabel(n).isNotEmpty, isTrue);
      expect(notionUnease(n), greaterThanOrEqualTo(0));
    }
  });

  group('görüş kuralları (Sight)', () {
    test('karanlıkta menzil daralır — suç bu yüzden geceleyin işlenir', () {
      final day = Sight.rangeFor(dayLight: 1.0);
      final night = Sight.rangeFor(dayLight: 0.0);
      expect(night, lessThan(day * 0.5));
    });

    test('meşale karanlıkta biraz daha uzağı gösterir', () {
      expect(Sight.rangeFor(dayLight: 0.0, hasTorch: true),
          greaterThan(Sight.rangeFor(dayLight: 0.0)));
    });

    test('ARKADAN yaklaşan zor görülür — sinsiliği gerçek kılan kural', () {
      const range = 10.0;
      // Tam önünde 8 tile: görülür.
      expect(
          Sight.visible(dx: 8, dy: 0, facingRight: true, range: range), isTrue);
      // Aynı mesafe ARKADA: görülmez.
      expect(Sight.visible(dx: -8, dy: 0, facingRight: true, range: range),
          isFalse);
      // Arkada ama çok yakın: yine de fark edilir (kör değil).
      expect(Sight.visible(dx: -3, dy: 0, facingRight: true, range: range),
          isTrue);
    });

    test('yön çevrilince kural simetrik çalışır', () {
      const range = 10.0;
      expect(Sight.visible(dx: -8, dy: 0, facingRight: false, range: range),
          isTrue);
      expect(Sight.visible(dx: 8, dy: 0, facingRight: false, range: range),
          isFalse);
    });

    test('gürültü yönden bağımsız duyulur ama menzili kısadır', () {
      expect(Sight.audible(dx: -5, dy: 0), isTrue);
      expect(Sight.audible(dx: 5, dy: 0), isTrue);
      expect(Sight.audible(dx: Sight.earshot + 1, dy: 0), isFalse);
    });
  });
}
