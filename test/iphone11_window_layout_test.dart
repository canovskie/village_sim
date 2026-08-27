import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:village_sim/systems/event_system.dart';
import 'package:village_sim/systems/imperial.dart';
import 'package:village_sim/systems/law_compass.dart';
import 'package:village_sim/systems/petition_system.dart';
import 'package:village_sim/systems/reckoning.dart';
import 'package:village_sim/systems/village_lessons.dart';
import 'package:village_sim/ui/about_screen.dart';
import 'package:village_sim/ui/app_ui.dart';
import 'package:village_sim/ui/event_choice_modal.dart';
import 'package:village_sim/ui/imperial_modal.dart';
import 'package:village_sim/ui/lesson_card.dart';
import 'package:village_sim/ui/mobile_ui.dart';
import 'package:village_sim/ui/petition_modal.dart';
import 'package:village_sim/ui/reckoning_screen.dart';
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

const _judgmentPetition = Petition(
  id: 'crime_verdict_test',
  petitioner: 'Köy divanı',
  icon: '⚖️',
  title: 'Hırsızlık hükmü',
  bodyPool: [
    'Sanık, ambar kilidini kırıp kışlık erzağı aldığı suçlamasıyla huzurunda.',
  ],
  stakes: 'Merhamet mi, ibret mi; köy senden açık bir hüküm bekliyor.',
  options: [
    PetitionOption(
      label: 'Affet',
      detail: 'Bir daha yapmaması için son bir fırsat ver.',
      resolutionPool: ['Sanık bağışlandı.'],
      moraleAmount: 0.02,
    ),
    PetitionOption(
      label: 'Zararını ödet',
      detail: 'Aldığını çalışarak yerine koysun.',
      resolutionPool: ['Zarar çalışmayla ödendi.'],
      foodDelta: 4,
    ),
    PetitionOption(
      label: 'Köy önünde cezalandır',
      detail: 'Herkes hükmü ve bedelini görsün.',
      resolutionPool: ['Ceza meydanda uygulandı.'],
      moraleAmount: -0.02,
    ),
    PetitionOption(
      label: 'Sürgün et',
      detail: 'Köy sınırından bir daha dönmemek üzere çıkar.',
      resolutionPool: ['Sanık sürgüne gönderildi.'],
    ),
    PetitionOption(
      label: 'Kürek cezası',
      detail: 'Ağır işte köye olan borcunu ödesin.',
      resolutionPool: ['Sanık ağır işe gönderildi.'],
      woodDelta: 3,
    ),
    PetitionOption(
      label: 'Tövbeye çağır',
      detail: 'Cemaat önünde söz versin ve gözetilsin.',
      resolutionPool: ['Sanık tövbe etti.'],
      moraleAmount: 0.01,
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
    await _pumpPhone(tester, EventChoiceModal(event: _event, onChoose: (_) {}));
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(AppPanel).first), const Size(760, 360));
    expect(find.byType(Scrollable), findsNothing);
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
    expect(find.byType(Scrollable), findsNothing);

    await tester.tap(find.text('Pazarlık et'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('öner'), findsNWidgets(3));
    expect(find.byType(Scrollable), findsNothing);
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
    expect(find.byType(Scrollable), findsNothing);
  });

  testWidgets('dünyada karşılığı olmayan dilekçe seçeneği nedenini gösterir', (
    tester,
  ) async {
    var chosen = false;
    await _pumpPhone(
      tester,
      PetitionModal(
        petition: _petition,
        onChoose: (_) => chosen = true,
        blockedReason: (option) => option == _petition.options.first
            ? 'Köyde kervan yok — bu yük satın alınamaz'
            : null,
        onDismiss: () {},
      ),
    );

    expect(
      find.text('Köyde kervan yok — bu yük satın alınamaz'),
      findsOneWidget,
    );
    await tester.tap(find.text('Paylaştır'));
    await tester.pump();
    expect(chosen, isFalse);

    await tester.tap(find.text('Ambarda tut'));
    await tester.pump();
    expect(chosen, isTrue);
  });

  testWidgets('altı seçenekli yargı telefonda kaydırmadan tek ekrana sığıyor', (
    tester,
  ) async {
    await _pumpPhone(
      tester,
      PetitionModal(
        petition: _judgmentPetition,
        state: (morale: 0.5, population: 42, food: 68, gold: 19),
        onChoose: (_) {},
        onDismiss: () {},
      ),
    );

    expect(tester.takeException(), isNull);
    for (final option in _judgmentPetition.options) {
      expect(find.text(option.label), findsOneWidget);
    }
    expect(find.byType(Scrollable), findsNothing);
  });

  testWidgets('ayarlar iPhone 11 üzerinde kaydırılabilir kompakt pencere', (
    tester,
  ) async {
    await _pumpPhone(tester, const SettingsScreen());
    expect(tester.takeException(), isNull);
    final panel = tester.getSize(find.byType(AppPanel).first);
    expect(panel.width, lessThanOrEqualTo(720));
    expect(panel.height, 360);
    expect(
      tester.getSize(find.byType(AppIconButton).first),
      const Size(44, 44),
    );
    expect(find.byType(Scrollable), findsWidgets);
  });

  testWidgets('hakkında ekranı sade yatay düzende taşmıyor', (tester) async {
    await _pumpPhone(tester, const AboutScreen());
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(AppPanel).first), const Size(720, 360));
    expect(
      tester.getSize(find.byType(AppIconButton).first),
      const Size(44, 44),
    );
    expect(find.text('Kontroller'), findsNothing);
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

  // ── Koşunun kapanışı + orta oyun dersleri (yeni yüzeyler) ────────────────
  //
  // İkisi de masaüstünde yazıldı. Telefon 414 piksel yüksekliğinde ve
  // güvenli alandan sonra elde 360 kalıyor: masaüstünde rahat duran uzun bir
  // kolon burada sessizce taşar (sarı-siyah şerit) ya da düğmeyi ekran
  // dışında bırakır. Kapanış ekranının "Ana Menü" düğmesine ulaşılamazsa
  // oyuncu koşusunu bitiremez.

  testWidgets('hesaplaşma ekranı telefonda taşmıyor ve kayabiliyor', (
    tester,
  ) async {
    for (final v in ReckoningVerdict.values) {
      await _pumpPhone(
        tester,
        ReckoningScreen(
          village: 'Pınarbaşı',
          verdict: v,
          epilogue: verdictEpilogue(v, VillageRegime.commune),
          identity: 'Ortak Ocak',
          years: 6,
          days: 81,
          population: 34,
          rows: reckoningLedger(
            const ReckoningInput(
              unity: 0.7,
              charter: 0.5,
              grit: 0.4,
              legacy: 0.5,
              favor: 0.6,
            ),
          ),
          milestones: const ['📜 Berat yılı ilan edildi.'],
          onExit: () {},
        ),
      );
      expect(tester.takeException(), isNull, reason: v.name);
      expect(find.text(v.title), findsOneWidget, reason: v.name);
      // Uzun içerik kaydırılabilir olmalı; yoksa alttaki çıkış düğmesi
      // telefonda erişilemez kalır.
      expect(find.byType(Scrollable), findsWidgets, reason: v.name);
    }
  });

  testWidgets(
    'hesaplaşma ekranındaki çıkış düğmesine telefonda ulaşılabiliyor',
    (tester) async {
      var exited = false;
      await _pumpPhone(
        tester,
        ReckoningScreen(
          village: 'Pınarbaşı',
          verdict: ReckoningVerdict.berat,
          epilogue: verdictEpilogue(
            ReckoningVerdict.berat,
            VillageRegime.market,
          ),
          identity: 'Açık Pazar',
          years: 6,
          days: 81,
          population: 34,
          rows: reckoningLedger(
            const ReckoningInput(
              unity: 0.7,
              charter: 0.5,
              grit: 0.4,
              legacy: 0.5,
              favor: 0.6,
            ),
          ),
          milestones: const [],
          onExit: () => exited = true,
        ),
      );
      await tester.scrollUntilVisible(find.text('Ana Menü'), 120);
      await tester.tap(find.text('Ana Menü'));
      expect(
        exited,
        isTrue,
        reason: 'kapanış ekranından çıkılamıyor — oyuncu koşusunu bitiremez',
      );
    },
  );

  testWidgets('ders kartı telefon penceresine sığıyor', (tester) async {
    await _pumpPhone(
      tester,
      Stack(
        children: [
          LessonCard(lesson: VillageLessons.all.first, onClose: () {}),
        ],
      ),
    );
    expect(tester.takeException(), isNull);
    final card = tester.getSize(find.byType(AppPanel).first);
    // 760x360'lık telefon bütçesini aşmamalı (bkz. MobileUi.windowSize).
    expect(card.width, lessThanOrEqualTo(760));
    expect(card.height, lessThanOrEqualTo(360));
    expect(find.text('NE YAPABİLİRSİN'), findsOneWidget);
  });

  testWidgets('en uzun ders kartı da telefonda taşmıyor', (tester) async {
    // Katalogdaki en uzun metin: kart bir dersle çalışıp ötekiyle taşarsa
    // hata ancak o ders tetiklendiğinde görülür — yani oyunun ortasında.
    var longest = VillageLessons.all.first;
    for (final l in VillageLessons.all) {
      if ((l.body.length + l.action.length) >
          (longest.body.length + longest.action.length)) {
        longest = l;
      }
    }
    await _pumpPhone(
      tester,
      Stack(
        children: [LessonCard(lesson: longest, onClose: () {})],
      ),
    );
    expect(
      tester.takeException(),
      isNull,
      reason: 'en uzun ders ("${longest.id}") telefonda taşıyor',
    );
    expect(
      tester.getSize(find.byType(AppPanel).first).height,
      lessThanOrEqualTo(360),
      reason: 'en uzun ders ("${longest.id}") telefon penceresini aşıyor',
    );
  });
}
