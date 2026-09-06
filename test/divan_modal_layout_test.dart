import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/characters/villager_type.dart';
import 'package:village_sim/entities/villager_entity.dart';
import 'package:village_sim/rendering/portrait_renderer.dart';
import 'package:village_sim/systems/governance/petition_system.dart';
import 'package:village_sim/ui/core/app_ui.dart';
import 'package:village_sim/ui/events/petition_modal.dart';

const _personalStyle = Petition(
  id: 'personalStyle',
  petitioner: '{ad} · {meslek}',
  icon: '🧵',
  title: 'Kendi Yolum',
  bodyPool: [
    'Evlenmek istemiyorum. Köyde kendi yolumu çizmek ve dilediğim kıyafeti giymek istiyorum.',
  ],
  stakes: 'Bir insanın kendi hayatı ile köyün alışkanlığı karşı karşıya.',
  tone: PetitionTone.solemn,
  options: [
    PetitionOption(
      label: 'Kendi kararını versin',
      detail: 'Hayatını ve kıyafetini özgürce seçsin.',
      resolutionPool: ['Kendi yolunu seçti.'],
      moraleAmount: .02,
      actorEffect: PetitionActorEffect.flowingOutfit,
    ),
    PetitionOption(
      label: 'Köy geleneği sürsün',
      detail: 'Köyün beklentilerine uyması istensin.',
      resolutionPool: ['Gelenek sürdü.'],
      actorEffect: PetitionActorEffect.traditionalOutfit,
    ),
  ],
);

const _sixChoices = Petition(
  id: 'sixChoices',
  petitioner: 'Köy divanı',
  icon: '⚖️',
  title: 'Altı Hüküm',
  bodyPool: ['Divan önüne gelen ağır mesele için altı ayrı hüküm konuşuluyor.'],
  options: [
    PetitionOption(label: 'Bir', detail: 'İlk hüküm.', resolutionPool: ['1']),
    PetitionOption(
      label: 'İki',
      detail: 'İkinci hüküm.',
      resolutionPool: ['2'],
    ),
    PetitionOption(label: 'Üç', detail: 'Üçüncü hüküm.', resolutionPool: ['3']),
    PetitionOption(
      label: 'Dört',
      detail: 'Dördüncü hüküm.',
      resolutionPool: ['4'],
    ),
    PetitionOption(
      label: 'Beş',
      detail: 'Beşinci hüküm.',
      resolutionPool: ['5'],
    ),
    PetitionOption(
      label: 'Altı',
      detail: 'Altıncı hüküm.',
      resolutionPool: ['6'],
    ),
  ],
);

VillagerEntity _author() => VillagerEntity(
  type: VillagerType.merchant,
  name: 'Yusuf',
  surname: 'Karaca',
  male: true,
  startCol: 0,
  startRow: 0,
  ageDays: 300,
);

Future<void> _pumpDesktop(WidgetTester tester, Widget child) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1440, 900);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: child));
  await tester.pump();
}

String _trUpper(String text) =>
    text.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();

PortraitPainter _divanPortrait(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.byKey(const ValueKey('divan-portrait-paint')),
  );
  return paint.painter! as PortraitPainter;
}

void main() {
  setUp(() => AppUi.captureStatic = true);
  tearDown(() => AppUi.captureStatic = false);

  testWidgets(
    'Divan taslağı masaüstünde geniş iki sütunlu pano olarak açılır',
    (tester) async {
      PetitionOption? chosen;
      await _pumpDesktop(
        tester,
        PetitionModal(
          petition: _personalStyle,
          author: _author(),
          state: (morale: .6, population: 24, food: 72, gold: 10),
          onChoose: (option) => chosen = option,
          onDismiss: () {},
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('DİVAN İKİLEMİ'), findsOneWidget);
      expect(find.text('KENDİ YOLUM'), findsOneWidget);
      expect(find.textContaining('Yusuf'), findsOneWidget);
      expect(find.text('KENDİ KARARINI VERSİN'), findsOneWidget);
      expect(find.text('KÖY GELENEĞİ SÜRSÜN'), findsOneWidget);
      expect(
        tester.getSize(find.byType(AppGildedFrame)),
        const Size(1180, 680),
      );
      expect(find.byType(Scrollable), findsNothing);

      await tester.tap(find.text('KENDİ KARARINI VERSİN'));
      await tester.pump();
      expect(_divanPortrait(tester).expression, PortraitExpression.happy);
      expect(chosen, isNull);
      await tester.pump(const Duration(milliseconds: 899));
      expect(chosen, isNull);
      await tester.pump(const Duration(milliseconds: 1));
      expect(chosen, _personalStyle.options.first);
    },
  );

  testWidgets('Divan portresi fareyi izler ve kartta sonucu ele vermez', (
    tester,
  ) async {
    await _pumpDesktop(
      tester,
      PetitionModal(
        petition: _personalStyle,
        author: _author(),
        onChoose: (_) {},
        onDismiss: () {},
      ),
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(
      location: tester.getCenter(find.text('KENDİ YOLUM')),
    );
    await mouse.moveTo(tester.getCenter(find.text('KENDİ KARARINI VERSİN')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    final portrait = _divanPortrait(tester);
    expect(portrait.lookOffset.dx, greaterThan(0));
    expect(portrait.expression, PortraitExpression.curious);
    await mouse.removePointer();
  });

  testWidgets('uzun kararsızlık portrede esnemeyi başlatır', (tester) async {
    final author = _author();
    await _pumpDesktop(
      tester,
      PetitionModal(
        petition: _personalStyle,
        author: author,
        onChoose: (_) {},
        onDismiss: () {},
      ),
    );

    final seed = _personalStyle.id.codeUnits.fold<int>(
      author.name.codeUnits.fold<int>(0, (a, b) => a + b),
      (a, b) => a + b,
    );
    await tester.pump(Duration(milliseconds: 12000 + (seed % 6001)));
    await tester.pump();
    expect(_divanPortrait(tester).expression, PortraitExpression.yawn);
  });

  testWidgets('sert ve beklenmedik hükümler seçimden sonra yüzde okunur', (
    tester,
  ) async {
    await _pumpDesktop(
      tester,
      PetitionModal(
        petition: _personalStyle,
        author: _author(),
        onChoose: (_) {},
        onDismiss: () {},
      ),
    );

    await tester.tap(find.text('KÖY GELENEĞİ SÜRSÜN'));
    await tester.pump();
    expect(_divanPortrait(tester).expression, PortraitExpression.angry);
    await tester.pump(const Duration(milliseconds: 900));

    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpDesktop(
      tester,
      PetitionModal(
        petition: _sixChoices,
        author: _author(),
        onChoose: (_) {},
        onDismiss: () {},
      ),
    );
    await tester.tap(find.text('BİR'));
    await tester.pump();
    expect(_divanPortrait(tester).expression, PortraitExpression.surprised);
    await tester.pump(const Duration(milliseconds: 900));
  });

  testWidgets('altı hüküm masaüstünde taşmadan Divan ızgarasına sığar', (
    tester,
  ) async {
    await _pumpDesktop(
      tester,
      PetitionModal(petition: _sixChoices, onChoose: (_) {}, onDismiss: () {}),
    );

    expect(tester.takeException(), isNull);
    for (final option in _sixChoices.options) {
      expect(find.text(_trUpper(option.label)), findsOneWidget);
    }
    expect(find.byType(Scrollable), findsNothing);
  });
}
