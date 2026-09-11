import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/systems/chronicle.dart';
import 'package:village_sim/systems/estate_system.dart';
import 'package:village_sim/systems/petition_system.dart';
import 'package:village_sim/systems/reckoning.dart';

void main() {
  group('karar izi save migrasyonu', () {
    test('yeni yapısal iz JSON turunda eksiksiz korunur', () {
      const entry = ChronicleEntry(
        day: 19,
        icon: '⚖',
        text: 'Müşterek Harman mühürlendi.',
        kind: ChronicleKind.decision,
        trace: DecisionTrace(
          sourceDecision: 'Müşterek Harman: Mühürle',
          firstOutcome: 'Harman müşterek sayıldı.',
          affected: 'Demirhan Hanesi',
          laterOutcome: 'emek azalacak, birlik zayıflayacak',
          reckoningAxis: 'Hane rızası',
          weight: 3,
        ),
      );

      final restored = ChronicleEntry.fromJson(entry.toJson());

      expect(restored.trace, isNotNull);
      expect(restored.trace!.sourceDecision, contains('Müşterek Harman'));
      expect(restored.trace!.affected, 'Demirhan Hanesi');
      expect(restored.trace!.laterOutcome, contains('birlik'));
      expect(restored.trace!.reckoningAxis, 'Hane rızası');
      expect(restored.trace!.weight, 3);
    });

    test('eski map ve düz-string günce makul varsayılanla açılır', () {
      final oldMap = ChronicleEntry.fromJson(const {
        'day': 4,
        'icon': '📜',
        'text': 'Kuyu açıldı.',
      });
      const oldString = ChronicleEntry(
        day: 0,
        icon: '📜',
        text: 'Eski defter satırı',
      );

      expect(oldMap.kind, ChronicleKind.life);
      expect(oldMap.trace, isNull);
      expect(oldString.day, 0);
      expect(oldString.trace, isNull);
    });
  });

  test('Defter yalnız son beş anlamlı izi yeni önce verir', () {
    final entries = <ChronicleEntry>[
      for (var day = 1; day <= 7; day++)
        ChronicleEntry(
          day: day,
          icon: '⚖',
          text: 'Karar $day',
          kind: ChronicleKind.decision,
          trace: DecisionTrace(
            sourceDecision: 'Karar $day',
            firstOutcome: 'İlk sonuç',
            affected: 'köy düzeni',
            laterOutcome: 'uzun sonuç',
            reckoningAxis: 'Karar mirası',
          ),
        ),
      const ChronicleEntry(day: 8, icon: '🌱', text: 'Bahar geldi.'),
    ];

    final recent = recentDecisionTraces(entries);
    expect(recent.map((e) => e.day), [7, 6, 5, 4, 3]);
  });

  test('final üç farklı koşu izi seçer; son genel satırlara teslim olmaz', () {
    const entries = <ChronicleEntry>[
      ChronicleEntry(
        day: 2,
        icon: '🛒',
        text: 'Kimseyi bırakmadık.',
        kind: ChronicleKind.decision,
        trace: DecisionTrace(
          sourceDecision: 'Kuruluş yükü: Kimseyi bırakmadık',
          firstOutcome: 'Altı kurucu geldi.',
          affected: 'Kurucu kafile',
          laterOutcome: 'ocakların sözü ağır bastı',
          reckoningAxis: 'Hane rızası',
          weight: 2,
        ),
      ),
      ChronicleEntry(
        day: 20,
        icon: '⚖',
        text: 'Sürgün hükmü verildi.',
        kind: ChronicleKind.decision,
        trace: DecisionTrace(
          sourceDecision: 'Hüküm: Sürgün',
          firstOutcome: 'Fail köyden çıkarıldı.',
          affected: 'Kaya Hanesi',
          laterOutcome: 'birlik soğudu',
          reckoningAxis: 'Karar mirası',
          weight: 3,
        ),
      ),
      ChronicleEntry(
        day: 31,
        icon: '❄️',
        text: 'Büyük kışta ambar boş kaldı.',
        milestone: true,
        kind: ChronicleKind.crisis,
      ),
      ChronicleEntry(day: 32, icon: '🌱', text: 'Bahar geldi.'),
      ChronicleEntry(day: 33, icon: '🗓', text: 'Yıl doldu.'),
    ];

    final lines = selectReckoningHighlights(entries);
    expect(lines, hasLength(3));
    expect(lines.join(' '), contains('Sürgün'));
    expect(lines.join(' '), contains('Kuruluş'));
    expect(lines.join(' '), contains('Büyük kış'));
    expect(lines.join(' '), isNot(contains('Bahar geldi')));
  });

  test('kuruluş yükü dilekçe zümresine küçük ve farklı yankı verir', () {
    expect(foundingPetitionEstate('seed'), Estate.laborers);
    expect(foundingPetitionEstate('tools'), Estate.artisans);
    expect(foundingPetitionEstate('people'), Estate.hearth);
    expect(foundingPetitionEstate('balanced'), isNull);
  });
}
