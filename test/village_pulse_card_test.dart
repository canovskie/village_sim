import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/ui/village_pulse_card.dart';

void main() {
  testWidgets(
    'Köy Nabzı kartı iki kısa karar ve kendi karar süresini gösterir',
    (tester) async {
      var primary = 0;
      var secondary = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: VillagePulseCard(
                icon: '🍲',
                actor: 'Ayşe',
                title: 'Ateş başında bir tas daha',
                body: 'Ayşe bu akşam yemeği köy halkıyla paylaşmak istiyor.',
                primaryLabel: 'Sofrayı büyüt',
                primarySub: '3 yiyecek',
                primaryEnabled: true,
                secondaryLabel: 'Kendi aralarında paylaşsınlar',
                secondarySub: 'Küçük bir sofra',
                remainingFraction: 0.5,
                secondsLeft: 11,
                onPrimary: () => primary++,
                onSecondary: () => secondary++,
                onClose: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('KÖY NABZI · AYŞE'), findsOneWidget);
      expect(find.text('Sofrayı büyüt'), findsOneWidget);
      expect(find.text('Kendi aralarında paylaşsınlar'), findsOneWidget);
      expect(
        find.text('Karar vermezsen Ayşe 11s sonra kendi yolunu seçer.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Sofrayı büyüt'));
      await tester.tap(find.text('Kendi aralarında paylaşsınlar'));
      expect(primary, 1);
      expect(secondary, 1);
    },
  );

  testWidgets('kaynak yetmeyen birincil karar devre dışı kalır', (
    tester,
  ) async {
    var primary = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: VillagePulseCard(
              icon: '🍯',
              actor: 'Hasan',
              title: 'Hastaya bir el',
              body: 'Hasan hastalığı ağır geçiriyor.',
              primaryLabel: 'Bir kaşık bal ver',
              primarySub: '1 bal',
              primaryEnabled: false,
              secondaryLabel: 'Köy halkı baksın',
              remainingFraction: 1,
              secondsLeft: 22,
              onPrimary: () => primary++,
              onSecondary: () {},
              onClose: () {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Bir kaşık bal ver'));
    expect(primary, 0);
  });

  testWidgets('dünya işareti tek dokunuşla hikâyeyi açar', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: VillagePulseMarker(
              icon: '🌼',
              urgent: false,
              onTap: () => taps++,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(VillagePulseMarker));
    expect(taps, 1);
  });
}
