// REJİM YÜZEYLERİ — çizim dumanı testi.
//
// Hafızadaki ders: panel "çalışmıyor" derken çoğu kez GERÇEK bir render bug'ı
// var (non-uniform Border+borderRadius assert'i, Positioned-only Stack çökmesi,
// sonsuz-yükseklikte stretch). Rejim bu oturumda üç yüzeye dokundu — kadran
// (çürüme çubuğu + iman notu + yemin kartı), Kanunname (fesih çipi) ve
// imparatorluk modalı (rejim bandı + meşruiyet rozetleri). Hepsinin GERÇEKTEN
// çizildiğini burada kilitliyoruz; exception atarsa test kırılır.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/systems/imperial.dart';
import 'package:village_sim/systems/law_compass.dart';
import 'package:village_sim/systems/regime.dart';
import 'package:village_sim/ui/imperial_modal.dart';
import 'package:village_sim/ui/law_compass_view.dart';

/// Widget'ı gerçek bir ekranda pompalar; layout/paint hatası varsa fırlatır.
Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.binding.setSurfaceSize(const Size(900, 1100));
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(child: child),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 350));
  expect(tester.takeException(), isNull);
}

void main() {
  group('pusula kadranı', () {
    testWidgets('rejim bağlanmamış hâlde (harness/preview) çizilir',
        (tester) async {
      await _pump(tester,
          const LawCompassCard(sealed: {'neighborliness'}, totalLaws: 34));
    });

    testWidgets('yetki + sabır + çürüme + iman + yemin hepsi birden çizilir',
        (tester) async {
      var sworn = false;
      await _pump(
        tester,
        LawCompassCard(
          sealed: const {
            'nizam.sole',
            'nizam.registry',
            'nizam.exile',
            'dergah.lodge',
            'dergah.holyDay',
          },
          totalLaws: 34,
          rule: Regime.ruleOf(VillageRegime.sealedHand, oath: true),
          unrest: 0.92,
          rot: 0.88, // çözülüyor — kronik hâl adı yazılmalı
          faith: Regime.faithEffectOf(0.8),
          sworn: VillageRegime.sealedHand,
          onSwearOath: () => sworn = true,
        ),
      );
      // Kronik hâl adı gerçekten ekranda mı (sadece "kırılmadı" yetmez).
      final (chronicTitle, _) = Regime.chronicText(RegimeCrisis.revolt);
      expect(find.text(chronicTitle), findsOneWidget);
      expect(find.textContaining('YEMİNLİ'), findsOneWidget);
      expect(sworn, isFalse); // dokunulmadı
    });

    testWidgets('ılımlı köyde bedel yok cümlesi çizilir', (tester) async {
      await _pump(
        tester,
        LawCompassCard(
          sealed: const {},
          totalLaws: 34,
          rule: Regime.ruleOf(VillageRegime.moderate),
          unrest: 0,
          rot: 0,
        ),
      );
      expect(find.textContaining('bedeli yok'), findsOneWidget);
    });
  });

  group('imparatorluk modalı', () {
    testWidgets('rejimsiz (baskı/ılımlı) hâlde meclis bandı çizilmez',
        (tester) async {
      await _pump(
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
      expect(find.textContaining('meşruiyet bedeli'), findsNothing);
    });

    testWidgets('hür rejimde meclis önerisi + meşruiyet rozetleri çizilir',
        (tester) async {
      await _pump(
        tester,
        ImperialModal(
          demand: const ImperialDemand(ImperialDemandKind.goldTax, 45),
          favor: 0.4,
          ransomCost: 30,
          canAcceptFull: true,
          canRansom: true,
          resistChance: 0.3,
          haggleEase: 0.16,
          postureNote: 'Ortak Ocak: bütün köy eşikte.',
          councilVerdict: ImperialVerdict.haggle,
          councilLine: Regime.verdictLine(ImperialVerdict.haggle,
              conscript: false),
          onAccept: () {},
          onRefuse: () {},
          onRansom: () {},
          onHaggle: (_) {},
          onResist: () {},
        ),
      );
      // Meclis pazarlık istiyor → "tam öde", "diren" ve "reddet" bedel taşır,
      // "pazarlık et" taşımaz: yani rozet sayısı 3 olmalı.
      expect(find.textContaining('meşruiyet bedeli'), findsNWidgets(3));
      expect(find.textContaining('Meclis pazarlıktan yana'), findsOneWidget);
    });

    testWidgets('devşirme talebinde fidye yolu da çizilir', (tester) async {
      await _pump(
        tester,
        ImperialModal(
          demand: const ImperialDemand(ImperialDemandKind.conscript, 1),
          favor: 0.2,
          ransomCost: 30,
          canAcceptFull: true,
          canRansom: true,
          resistChance: 0.5,
          postureNote: 'Mühürlü El: köy tek yumruk.',
          councilVerdict: ImperialVerdict.resist,
          councilLine:
              Regime.verdictLine(ImperialVerdict.resist, conscript: true),
          onAccept: () {},
          onRefuse: () {},
          onRansom: () {},
          onHaggle: (_) {},
          onResist: () {},
        ),
      );
      expect(find.textContaining('Altınla kurtar'), findsOneWidget);
    });
  });
}
