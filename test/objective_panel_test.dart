import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/systems/quest_book.dart';
import 'package:village_sim/ui/objective_panel.dart';

void main() {
  testWidgets('aktif ana mesele hesaplaşma kefesini doğal biçimde gösterir', (
    tester,
  ) async {
    final quest = QuestBook.all.firstWhere((q) => q.id == 'roads');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: ObjectivePanel(
              quests: [QuestState(quest, false, true)],
              tierIndex: 3,
              tierName: QuestBook.tierOf(3).name,
              tierIcon: QuestBook.tierOf(3).icon,
              completedCount: 18,
              totalCount: QuestBook.all.length,
              next: QuestBook.nextTier(3),
              collapsed: false,
              onToggleCollapse: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('ANA MESELE · Köy ağırlığı'), findsOneWidget);
    expect(find.text(quest.hint), findsOneWidget);
  });
}
