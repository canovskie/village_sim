import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/systems/governance/petition_system.dart';
import 'package:village_sim/systems/run/quest_book.dart';
import 'package:village_sim/text/voice.dart';
import 'package:village_sim/ui/core/app_ui.dart';
import 'package:village_sim/ui/events/petition_modal.dart';
import 'package:village_sim/ui/hud/objective_panel.dart';

void main() {
  setUp(() => AppUi.captureStatic = true);
  tearDown(() => AppUi.captureStatic = false);
  for (final size in [const Size(896, 414), const Size(760, 360)]) {
    testWidgets('hikâyelerin iki kararı da telefonda erişilir $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      for (final raw in PetitionSystem.all.where(
        (p) => p.id.startsWith('story.'),
      )) {
        final p = raw.spoken(
          const VoiceCtx(
            seed: 3,
            name: 'Abdurrahman',
            house: 'Karacaoğulları',
            extra: {
              'storyLead': 'Abdurrahman',
              'storyPartner': 'Şerife Hatice',
              'storyCraft': 'Marangozluk',
              'storyMissing': 'Abdurrahman',
            },
          ),
        );
        PetitionOption? chosen;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PetitionModal(
                key: ValueKey(p.id),
                petition: p,
                onChoose: (o) => chosen = o,
                onDismiss: () {},
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: p.id);
        for (final option in p.options) {
          final label = find.text(option.label).last;
          await tester.ensureVisible(label);
          await tester.tap(label);
          await tester.pump();
          expect(chosen, same(option), reason: '${p.id}/${option.label}');
          expect(tester.takeException(), isNull, reason: p.id);
        }
      }
    });
  }

  testWidgets('geç hedef aynı kişilerin geçmişini mevcut panelde gösterir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(760, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final quest = QuestBook.all.singleWhere((q) => q.id == 'roads');
    const note =
        'Ali ve Hatice ile başlayan mesele, köy büyüdüğünde yeniden açılacak.';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topRight,
            child: SizedBox(
              width: 285,
              child: ObjectivePanel(
                quests: [QuestState(quest, false, true, storyNote: note)],
                tierIndex: 3,
                tierName: 'Kasaba',
                tierIcon: '🏡',
                completedCount: 10,
                totalCount: 20,
                next: null,
                collapsed: false,
                onToggleCollapse: () {},
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.textContaining(note), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
