import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/systems/events/event_system.dart';
import 'package:village_sim/ui/core/app_ui.dart';
import 'package:village_sim/ui/core/mobile_ui.dart';
import 'package:village_sim/ui/events/event_choice_modal.dart';
import 'package:village_sim/ui/events/event_scene_card.dart';
import 'package:village_sim/ui/hud/notification_plaque.dart';

const _winterEvent = EventOutcome(
  id: 'first_frost',
  title: 'Kış Kapıda',
  icon: '❄️',
  message: 'İlk don düştü. Haneler odun bekliyor.',
  category: EventCategory.negative,
  severity: EventSeverity.major,
  choices: [
    EventChoice(
      id: 'share_wood',
      label: 'Odunu paylaştır',
      detail: 'Hanelerin ocakları bu gece yanar.',
      resolutionMessage: 'Odun hanelere pay edildi.',
      woodDelta: -10,
      moraleModifier: .05,
      duration: 20,
    ),
    EventChoice(
      id: 'store_wood',
      label: 'Ambarda tut',
      detail: 'Stok korunur, haneler soğuğa dayanır.',
      resolutionMessage: 'Odun ambarda tutuldu.',
      moraleModifier: -.03,
      duration: 20,
    ),
  ],
);

Future<void> _pumpDesktop(WidgetTester tester, Widget child) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1440, 900);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: child));
  await tester.pump();
}

void main() {
  setUp(() => AppUi.captureStatic = true);
  tearDown(() => AppUi.captureStatic = false);

  testWidgets('olay ikilemi geniş mekân sahnesi ve resimli kararlar kullanır', (
    tester,
  ) async {
    EventChoice? chosen;
    await _pumpDesktop(
      tester,
      EventChoiceModal(
        event: _winterEvent,
        onChoose: (choice) => chosen = choice,
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('KÖY OLAYI · TEHLİKE'), findsOneWidget);
    expect(find.text('KIŞ KAPIDA'), findsOneWidget);
    expect(find.byType(EventSceneCard), findsOneWidget);
    expect(find.byType(EventChoiceSceneCard), findsNWidgets(2));
    expect(find.byType(Scrollable), findsNothing);
    expect(tester.getSize(find.byType(AppGildedFrame)), const Size(1180, 680));

    await tester.tap(find.text('ODUNU PAYLAŞTIR'));
    expect(chosen, _winterEvent.choices!.first);
  });

  testWidgets(
    'haber plaketi diğer kararlardan ayrı tipografik şerit kullanır',
    (tester) async {
      await _pumpDesktop(
        tester,
        const Center(
          child: NotificationPlaque(
            message: '❄️ İlk don — Çatılar kırağı tuttu.',
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('İLK DON'), findsOneWidget);
      expect(find.text('Çatılar kırağı tuttu.'), findsOneWidget);
      expect(find.text('ŞİMDİ'), findsOneWidget);
      expect(find.byType(GameIcon), findsOneWidget);
      expect(
        tester.getSize(find.byType(NotificationPlaque)),
        const Size(430, 74),
      );
      expect(
        NotificationPlaque.readDuration('Kısa haber').inMilliseconds,
        5080,
      );
      expect(NotificationPlaque.readDuration('x' * 200).inMilliseconds, 10400);
    },
  );

  testWidgets('uzun haber plaketi metni kesmeden yüksekliğini büyütür', (
    tester,
  ) async {
    const detail =
        'Köyün kuzeyindeki eski patikada bir kervan görüldü; yükçüler gece '
        'çökmeden meydana varmak için yardım istiyor ve köylüler verilecek '
        'kararı ateşin başında bekliyor.';
    await _pumpDesktop(
      tester,
      const Center(
        child: NotificationPlaque(message: 'Kervan haberi — $detail'),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text(detail), findsOneWidget);
    final detailText = tester.widget<Text>(find.text(detail));
    expect(detailText.maxLines, isNull);
    expect(
      tester.getSize(find.byType(NotificationPlaque)).height,
      greaterThan(74),
    );
  });
  for (final screen in [const Size(760, 360), const Size(896, 414)]) {
    testWidgets('haber ve işlem fişi mobil alana sığar: $screen', (
      tester,
    ) async {
      tester.view.physicalSize = screen;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: screen,
              textScaler: const TextScaler.linear(1.5),
            ),
            child: const Scaffold(
              body: MobileTextFloor(
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: MobileUi.actionH + MobileUi.gap,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          NotificationPlaque(
                            compact: true,
                            pendingCount: 4,
                            remainingFraction: .5,
                            message:
                                'Hane ayrılıyor: Kaya Hanesi arabalarını yükledi. Yarın öbür gün yola çıkarlar.',
                          ),
                          AppChip(
                            label: 'Eksik malzeme: 10 odun, 4 taş, 2 demir',
                            color: AppUi.rust,
                            solid: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      final plaque = tester.getRect(find.byType(NotificationPlaque));
      final chip = tester.getRect(find.byType(AppChip));
      expect(plaque.top, greaterThanOrEqualTo(0));
      expect(plaque.overlaps(chip), isFalse);
      expect(chip.bottom, lessThanOrEqualTo(screen.height - MobileUi.actionH));
    });
  }
}
