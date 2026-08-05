import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:village_sim/systems/event_system.dart';
import 'package:village_sim/systems/imperial.dart';
import 'package:village_sim/systems/petition_system.dart';
import 'package:village_sim/ui/about_screen.dart';
import 'package:village_sim/ui/app_ui.dart';
import 'package:village_sim/ui/event_choice_modal.dart';
import 'package:village_sim/ui/imperial_modal.dart';
import 'package:village_sim/ui/mobile_ui.dart';
import 'package:village_sim/ui/petition_modal.dart';
import 'package:village_sim/ui/save_slots_screen.dart';
import 'package:village_sim/ui/settings_screen.dart';

const _iphone11 = Size(896, 414);
const _iphone11Safe = EdgeInsets.only(left: 44, right: 44, bottom: 21);

const _event = EventOutcome(
  title: 'Kış Kapıda',
  icon: '❄️',
  message: 'Ambarı ve ocağı aynı anda koruyacak bir karar gerekiyor.',
  category: EventCategory.negative,
  choices: [
    EventChoice(
      id: 'share',
      label: 'Paylaştır',
      detail: 'Köy birlikte hazırlanır.',
      resolutionMessage: 'Erzak paylaştırıldı.',
    ),
    EventChoice(
      id: 'store',
      label: 'Ambara kaldır',
      detail: 'Stok korunur, bazı haneler bekler.',
      resolutionMessage: 'Stok ambara kaldırıldı.',
    ),
  ],
);

const _petition = Petition(
  id: 'winter_help',
  petitioner: 'Köyün haneleri',
  icon: '🔥',
  title: 'Ocaklar sönmesin',
  bodyPool: ['Kış bastırmadan odunu hanelere paylaştırmanı isteriz.'],
  stakes: 'Stok mu, sıcak haneler mi?',
  options: [
    PetitionOption(
      label: 'Paylaştır',
      detail: 'Odun hanelere gider.',
      resolutionPool: ['Ocaklar yeniden yandı.'],
      woodDelta: -12,
    ),
    PetitionOption(
      label: 'Ambarda tut',
      detail: 'Köy ortak stokla yetinir.',
      resolutionPool: ['Odun ambarda kaldı.'],
    ),
  ],
);

Future<void> _pumpPhone(WidgetTester tester, Widget child) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = _iphone11;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(
          size: _iphone11,
          padding: _iphone11Safe,
          viewPadding: _iphone11Safe,
        ),
        child: child,
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() => AppUi.captureStatic = true);
  tearDown(() => AppUi.captureStatic = false);

  testWidgets('iPhone 11 ana pencere bütçesi 760x360 ve güvenli alanda', (
    tester,
  ) async {
    Size? measured;
    await _pumpPhone(
      tester,
      Builder(
        builder: (context) {
          measured = MobileUi.windowSize(context);
          return const SizedBox.shrink();
        },
      ),
    );
    expect(measured, const Size(760, 360));
  });

  testWidgets('olay penceresi kompakt bütçeyi aşmıyor', (tester) async {
    await _pumpPhone(
      tester,
      EventChoiceModal(event: _event, onChoose: (_) {}),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(AppPanel).first), const Size(760, 360));
  });

  testWidgets('imparatorluk penceresi seçenekleriyle birlikte taşmıyor', (
    tester,
  ) async {
    await _pumpPhone(
      tester,
      ImperialModal(
        demand: const ImperialDemand(ImperialDemandKind.goldTax, 45),
        favor: 0.4,
        ransomCost: 30,
        canAcceptFull: true,
        canRansom: true,
        resistChance: 0.3,
        onAccept: () {},
        onRefuse: () {},
        onRansom: () {},
        onHaggle: (_) {},
        onResist: () {},
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(AppPanel).first), const Size(760, 360));
  });

  testWidgets('dilekçe anlatısı ve kararları aynı kompakt pencerede', (
    tester,
  ) async {
    await _pumpPhone(
      tester,
      PetitionModal(
        petition: _petition,
        state: (morale: 0.5, population: 12, food: 30, gold: 8),
        onChoose: (_) {},
        onDismiss: () {},
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Paylaştır'), findsOneWidget);
    expect(find.text('Ambarda tut'), findsOneWidget);
  });

  testWidgets('ayarlar iPhone 11 üzerinde kaydırılabilir kompakt pencere', (
    tester,
  ) async {
    await _pumpPhone(tester, const SettingsScreen());
    expect(tester.takeException(), isNull);
    final panel = tester.getSize(find.byType(AppPanel).first);
    expect(panel.width, lessThanOrEqualTo(720));
    expect(panel.height, 360);
    expect(tester.getSize(find.byType(AppIconButton).first), const Size(44, 44));
    expect(find.byType(Scrollable), findsWidgets);
  });

  testWidgets('hakkında ekranı yatay iki sütunda taşmıyor', (tester) async {
    await _pumpPhone(tester, const AboutScreen());
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(AppPanel).first), const Size(720, 360));
    expect(tester.getSize(find.byType(AppIconButton).first), const Size(44, 44));
    expect(find.text('Kontroller'), findsOneWidget);
    expect(find.text('Krediler'), findsOneWidget);
  });

  testWidgets('kayıt penceresi sabit başlık ve kayan gövde kullanıyor', (
    tester,
  ) async {
    await _pumpPhone(
      tester,
      Stack(
        children: [
          SaveSlotsPanel(
            onContinue: (_) {},
            onClose: () {},
            loader: () async => [],
          ),
        ],
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(AppGildedFrame).first),
      const Size(720, 360),
    );
    expect(find.byType(Scrollable), findsOneWidget);
  });
}
