import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/systems/house_stance.dart';
import 'package:village_sim/systems/house_system.dart';

/// Hane motorunun karşılık tarafı: saklanan yiyecek yok olmaz, geri döner,
/// kayıttan sağ çıkar; esirgeyen hane panelde başa gelir.

/// [surname] hanesini verilen hâl/nüfuzla kurar (üye sayısı [members]).
HouseSystem _village({
  required Map<String, ({double mood, double sway, int members})> houses,
}) {
  final h = HouseSystem();
  final counts = <String, int>{};
  final moraleSum = <String, double>{};
  for (final e in houses.entries) {
    counts[e.key] = e.value.members;
    moraleSum[e.key] = 0.55 * e.value.members;
  }
  h.rebuild(counts, moraleSum);
  for (final e in houses.entries) {
    // Taban 0.55 / 1.0 → istenen değere taşı.
    h.nudge(e.key, moodDelta: e.value.mood - 0.55);
    if (e.value.sway > 1.0) h.nudge(e.key, swayGain: e.value.sway - 1.0);
  }
  return h;
}

void main() {
  group('saklama', () {
    test('küskün + kozlu hane ambarını kapatır, razı hane kapatmaz', () {
      final h = _village(houses: {
        'Karahan': (mood: 0.18, sway: 4.0, members: 6),
        'Demirhan': (mood: 0.60, sway: 1.0, members: 6),
      });
      expect(h.withholdingOf('Karahan').hoard, greaterThan(0));
      expect(h.withholdingOf('Demirhan').hoard, 0);
    });

    test('saklama üye başına sınırlı — ambar kalıcı kurumaz', () {
      final h = _village(houses: {
        'Karahan': (mood: 0.10, sway: 4.0, members: 3),
      });
      var stored = 0.0;
      for (var i = 0; i < 200; i++) {
        stored += h.hoard('Karahan', 5);
      }
      expect(stored, kStashPerMember * 3);
      expect(h.hoard('Karahan', 5), 0, reason: 'dolu ambar daha fazla almaz');
    });

    test('bilinmeyen haneye saklama yapılmaz', () {
      final h = _village(houses: {'Karahan': (mood: 0.5, sway: 1.0, members: 2)});
      expect(h.hoard('Yokoğlu', 10), 0);
    });
  });

  group('geri akış', () {
    test('hâlâ esirgeyen hane ambarını AÇMAZ', () {
      final h = _village(houses: {
        'Karahan': (mood: 0.10, sway: 4.0, members: 6),
      });
      h.hoard('Karahan', 20);
      expect(h.releaseStashes(1.0), isEmpty);
      expect(h.stashOf('Karahan'), 20);
    });

    test('razı olan hane sakladığını kademeli geri verir', () {
      final h = _village(houses: {
        'Karahan': (mood: 0.10, sway: 4.0, members: 6),
      });
      h.hoard('Karahan', 24);
      // Gönlü alındı → esirgeme çözülür.
      h.nudge('Karahan', moodDelta: 0.50);
      expect(h.withholdingOf('Karahan').hoard, 0);

      final first = h.releaseStashes(1.0);
      expect(first['Karahan'], greaterThan(0));
      expect(first['Karahan'], lessThan(24),
          reason: 'bir çırpıda değil, birkaç güne yayılmalı');

      var guard = 0;
      while (h.stashOf('Karahan') > 0 && guard++ < 50) {
        h.releaseStashes(1.0);
      }
      expect(h.stashOf('Karahan'), 0, reason: 'ambar sonunda tümüyle boşalmalı');
    });

    test('panelde okunan sayı ile ambara giren sayı ayrışmaz', () {
      final h = _village(houses: {
        'Karahan': (mood: 0.10, sway: 4.0, members: 6),
      });
      h.hoard('Karahan', 30);
      var returned = 0;
      var guard = 0;
      while (h.stashOf('Karahan') > 0 && guard++ < 80) {
        h.nudge('Karahan', moodDelta: 1.0); // razı tut
        returned += h.releaseStashes(1.0)['Karahan'] ?? 0;
      }
      // Kuyruk süpürme <1 birim kaybettirebilir; ötesi kaçak demektir.
      expect(returned, closeTo(30, 1.0));
    });

    test('el koyma ambarı boşaltır ve miktarı verir', () {
      final h = _village(houses: {
        'Karahan': (mood: 0.10, sway: 4.0, members: 6),
      });
      h.hoard('Karahan', 17.6);
      expect(h.drainStash('Karahan'), 17);
      expect(h.stashOf('Karahan'), 0);
    });
  });

  group('sönen soy', () {
    test('tükenen hane ambarı boşalana kadar silinmez', () {
      final h = _village(houses: {
        'Karahan': (mood: 0.10, sway: 1.0, members: 4),
      });
      h.hoard('Karahan', 12);
      h.rebuild(const {}, const {}); // son üye de öldü
      expect(h.surnames, contains('Karahan'),
          reason: 'sakladığı buğday sessizce yok olmamalı');
      expect(h.withholdingOf('Karahan').hoard, 0,
          reason: 'üyesiz hane esirgeyemez → ambarı akmaya başlar');

      var guard = 0;
      while (h.stashOf('Karahan') > 0 && guard++ < 50) {
        h.releaseStashes(1.0);
      }
      h.rebuild(const {}, const {});
      expect(h.surnames, isNot(contains('Karahan')),
          reason: 'ambar boşalınca soy kapanır');
    });
  });

  group('panel', () {
    test('esirgeyen hane listenin başına gelir', () {
      final h = _village(houses: {
        'Demirhan': (mood: 0.62, sway: 1.0, members: 8),
        'Karahan': (mood: 0.12, sway: 3.0, members: 3),
      });
      final snap = h.snapshot();
      expect(snap.first.surname, 'Karahan');
      expect(snap.first.stance.withholds, isTrue);
    });

    test('snapshot duruşu + saklananı taşır (tek doğruluk kaynağı)', () {
      final h = _village(houses: {
        'Karahan': (mood: 0.12, sway: 3.0, members: 4),
      });
      h.hoard('Karahan', 9);
      final s = h.snapshot().first;
      expect(s.stash, 9);
      expect(s.stance, h.stanceOf('Karahan'));
      expect(s.withholding.labor, h.withholdingOf('Karahan').labor);
    });
  });

  group('kayıt', () {
    test('saklanan yiyecek kayıttan sağ çıkar', () {
      final a = _village(houses: {
        'Karahan': (mood: 0.12, sway: 3.0, members: 4),
      });
      a.hoard('Karahan', 11);
      final json = a.toJson();

      final b = HouseSystem()..loadJson(json);
      b.rebuild({'Karahan': 4}, {'Karahan': 0.5 * 4});
      expect(b.stashOf('Karahan'), 11);
      expect(b.stanceOf('Karahan'), a.stanceOf('Karahan'));
    });
  });
}
