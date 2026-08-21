import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/ui/app_ui.dart';
import 'package:village_sim/ui/command_bar.dart';

void main() {
  testWidgets('kuruluş şantiyesi beklerken beklemeyi geç eylemi görünür', (
    tester,
  ) async {
    var skipped = false;
    var showed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: QuestTracker(
              icon: GameIconData.home,
              activeLabel: 'İlk çadırı kur',
              tierName: 'Yeni Ocak',
              done: 1,
              total: 8,
              onOpen: () {},
              hint: 'Usta şantiyeye gidiyor.',
              expanded: true,
              onShow: () => showed = true,
              onSkipWait: () => skipped = true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Beklemeyi geç'), findsOneWidget);
    expect(find.text('Göster'), findsNothing);
    await tester.tap(find.text('Beklemeyi geç'));
    expect(skipped, isTrue);
    expect(showed, isFalse);
  });
}
