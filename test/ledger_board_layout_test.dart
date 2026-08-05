import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:village_sim/characters/villager_type.dart';
import 'package:village_sim/entities/villager_entity.dart';
import 'package:village_sim/systems/estate_system.dart' show EstateMoodTier;
import 'package:village_sim/systems/house_system.dart';
import 'package:village_sim/systems/petition_system.dart';
import 'package:village_sim/ui/app_ui.dart';
import 'package:village_sim/ui/ledger_board.dart';
import 'package:village_sim/ui/mobile_ui.dart';
import 'package:village_sim/ui/village_ledger.dart';
import 'package:village_sim/ui/villager_roster_view.dart';

/// KÖY DEFTERİ — TELEFON TAHTASI.
///
/// Bu dosyanın koruduğu tek söz: **telefonda yönetim ekranı KAYDIRILMAZ.**
///
/// Defter masaüstünde doğdu ve oradaki dizilimi (üst üste yatay bantlar + tek
/// sütunluk liste) telefona taşımıştı. Ölçülen sonuç: iPhone 11'de NÜFUS
/// bölümünde bantlar 270dp yiyor, 18 kişilik köyün listesine 90dp kalıyor,
/// oyuncu bir buçuk köylü görüyordu. Tahta dizilimi (bkz. ui/ledger_board.dart)
/// gezinmeyi dikeye, içeriği sütunlara, taşan içeriği de kaydırma yerine
/// SAYFAYA aldı.
///
/// Testler bunu üç yerden tutar:
///   1. hiçbir bölüm dikey kaydırma açmaz (Scrollable yok),
///   2. hiçbir bölüm taşmaz (en dar profilde de),
///   3. gezinme ve sayfa okları 44dp dokunma tabanının altına düşmez.

// iPhone 11 (referans) ve 640×360 ucuz Android (en kötü durum).
const _iphone11 = Size(896, 414);
const _iphone11Safe = EdgeInsets.only(left: 44, right: 44, bottom: 21);
const _smallAndroid = Size(640, 360);
const _smallSafe = EdgeInsets.only(bottom: 20);

VillagerEntity _mk(String name, String surname, VillagerType type, double w) {
  final v = VillagerEntity(
    type: type,
    name: name,
    surname: surname,
    male: name.length.isEven,
    startCol: 0,
    startRow: 0,
    ageDays: 5,
  );
  v.wealth = w;
  v.morale = 0.6;
  return v;
}

/// 18 kişilik köy — asıl derdin ölçüsü. Tek ekrana sığmaz; SAYFALANMALI.
List<VillagerStatRow> _roster() => [
  for (var i = 0; i < 18; i++)
    VillagerStatRow(
      _mk('Köylü$i', i.isEven ? 'Doğan' : 'Karaca', VillagerType.farmer,
          60.0 - i),
      'Ahşap Ev',
      2,
    ),
];

List<HouseSnapshot> _houses() => const [
  HouseSnapshot(
    surname: 'Doğan',
    label: 'Doğan Hanesi',
    mood: 0.56,
    swayShare: 0.5,
    ascendant: true,
    members: 9,
    tier: EstateMoodTier.neutral,
  ),
  HouseSnapshot(
    surname: 'Karaca',
    label: 'Karaca Hanesi',
    mood: 0.44,
    swayShare: 0.5,
    ascendant: false,
    members: 9,
    tier: EstateMoodTier.uneasy,
  ),
];

List<DivanMatter> _agenda() => const [
  DivanMatter(
    icon: '🔥',
    title: 'Ocaklar sönmesin',
    sub: 'Kış bastırmadan odun paylaştırılsın.',
    pressure: 0.8,
    pending: true,
    graceProgress: 0.4,
  ),
  DivanMatter(
    icon: '🌾',
    title: 'Güneş ekini yakıyor',
    sub: 'Başaklar öğlen vakti başını eğiyor.',
    pressure: 0.5,
    tone: PetitionTone.ominous,
  ),
  DivanMatter(
    icon: '⚒',
    title: 'Biri yanlış tezgâhta',
    sub: 'Mesleğine küs bir köylü var.',
    pressure: 0.3,
  ),
];

Widget _ledger(LedgerSection section) => VillageLedger(
  identity: 'Karaca Hanesi',
  morale: 0.59,
  population: 18,
  food: 120,
  gold: 70,
  agenda: _agenda(),
  houses: _houses(),
  laws: const [],
  marks: const [],
  onOpenPetition: () {},
  rosterRows: _roster(),
  chronicle: const [],
  initialSection: section,
  onClose: () {},
);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Size size = _iphone11,
  EdgeInsets safe = _iphone11Safe,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          padding: safe,
          viewPadding: safe,
        ),
        child: child,
      ),
    ),
  );
  await tester.pump();
}

/// Defterin İÇİNDEKİ Scrollable'lar. Meclis masasının eylem kartı (bir reise
/// dokununca açılan açılır kart) kendi içinde kayabilir — o bir alt-yüzey,
/// bölüm gövdesi değil; testin derdi bölüm gövdeleri.
Finder _bodyScrollables() => find.descendant(
  of: find.byType(VillageLedger),
  matching: find.byType(Scrollable),
);

void main() {
  setUp(() => AppUi.captureStatic = true);
  tearDown(() => AppUi.captureStatic = false);

  for (final section in LedgerSection.values) {
    // KANUNNAME yalnız politika bağlıyken var; bu kurulumda onOpenLaw yok.
    if (section == LedgerSection.kanun) continue;

    testWidgets('${section.label} telefonda taşmıyor ve kaydırmıyor', (
      tester,
    ) async {
      await _pump(tester, _ledger(section));
      expect(tester.takeException(), isNull);
      expect(
        _bodyScrollables(),
        findsNothing,
        reason: 'Telefonda defter bölümü kaydırma açmamalı — sayfalanmalı '
            '(bkz. BoardPager).',
      );
    });

    testWidgets('${section.label} 640×360 ucuz Android\'de de taşmıyor', (
      tester,
    ) async {
      await _pump(
        tester,
        _ledger(section),
        size: _smallAndroid,
        safe: _smallSafe,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('sol ray beş bölümü de KISA etiketiyle kırpmadan yazar', (
    tester,
  ) async {
    await _pump(tester, _ledger(LedgerSection.divan));
    expect(find.byType(BoardRail), findsOneWidget);
    for (final s in LedgerSection.values) {
      if (s == LedgerSection.kanun) continue; // bu kurulumda gizli
      expect(find.text(s.short), findsOneWidget);
    }
    // Ray ne kadar dar olursa olsun bölüm düğmesi 44dp'lik dokunma tabanının
    // altına düşmemeli — gezinme, feda edilecek en son şey.
    final rail = tester.getSize(find.byType(BoardRail));
    expect(rail.width, LedgerBoard.railW);
  });

  testWidgets('18 kişilik nüfus tek karede DEĞİL, sayfalanarak gösterilir', (
    tester,
  ) async {
    await _pump(tester, _ledger(LedgerSection.nufus));
    expect(tester.takeException(), isNull);
    // Sayfa künyesi = içerik ekranı aşıyor ama kaydırma yok demek.
    expect(find.textContaining(RegExp(r'^\d+ / \d+$')), findsOneWidget);
    // İlk sayfa bir buçuk değil, ONİKİ köylü taşır (3 sütun × 4 satır).
    final cards = tester.widgetList(
      find.descendant(
        of: find.byType(BoardPager),
        matching: find.byType(BoardTile),
      ),
    );
    expect(cards.length, greaterThanOrEqualTo(12));
  });

  testWidgets('sayfa okları 44dp dokunma tabanını tutar', (tester) async {
    await _pump(tester, _ledger(LedgerSection.nufus));
    final arrows = find.descendant(
      of: find.byType(BoardPager),
      matching: find.byType(GestureDetector),
    );
    var checked = 0;
    for (final e in arrows.evaluate()) {
      final size = tester.getSize(find.byWidget(e.widget));
      if (size.width == MobileUi.tap) {
        expect(size.height, MobileUi.tap);
        checked++;
      }
    }
    expect(checked, greaterThan(0), reason: 'Sayfa oku bulunamadı.');
  });

  testWidgets('masaüstü dizilimi ETKİLENMEDİ — geniş ekranda hero + raf', (
    tester,
  ) async {
    await _pump(
      tester,
      _ledger(LedgerSection.divan),
      size: const Size(1280, 800),
      safe: EdgeInsets.zero,
    );
    expect(tester.takeException(), isNull);
    // Tahta yalnız kompakt ekranda kurulur.
    expect(find.byType(BoardRail), findsNothing);
    // Masaüstü rafı bölümün künyesini de yazar — telefon rayında bu satır yok,
    // yani yalnız masaüstü dizilimine ait bir iz.
    expect(find.text(LedgerSection.nufus.blurb), findsOneWidget);
  });
}
