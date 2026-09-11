import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/core/resources.dart';
import 'package:village_sim/systems/events/event_system.dart';
import 'package:village_sim/systems/events/governance_event.dart';
import 'package:village_sim/systems/governance/petition_system.dart';
import 'package:village_sim/text/voice.dart';
import 'package:village_sim/ui/core/app_ui.dart';
import 'package:village_sim/ui/events/event_choice_modal.dart';

void main() {
  for (final size in [const Size(896, 414), const Size(760, 360)]) {
    testWidgets(
      'köy kararları ${size.width}x${size.height} ekranda erişilebilir',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        AppUi.captureStatic = true;
        addTearDown(() {
          tester.view.reset();
          AppUi.captureStatic = false;
        });
        final events = [
          ...EventSystem.events,
          for (final p in PetitionSystem.all.where((p) => isVillageIssue(p.id)))
            governanceEvent(p.spoken(const VoiceCtx(name: 'Ali', seed: 3))),
        ];
        for (final event in events) {
          EventChoice? chosen;
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: EventChoiceModal(
                  event: event,
                  stockpile: ResourceBundle(food: 100, gold: 100, wood: 100),
                  onChoose: (c) => chosen = c,
                ),
              ),
            ),
          );
          await tester.pump();
          expect(tester.takeException(), isNull, reason: event.id);
          final last = event.choices!.last;
          final label = last.label
              .replaceAll('i', 'İ')
              .replaceAll('ı', 'I')
              .toUpperCase();
          final button = find.text(label);
          expect(button, findsOneWidget, reason: event.id);
          await tester.tap(button);
          expect(chosen, same(last), reason: event.id);
        }
      },
    );
  }
}
