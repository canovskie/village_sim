import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/core/resources.dart';
import 'package:village_sim/ui/dev/dev_panel.dart';
import 'package:village_sim/world/season.dart';

void main() {
  testWidgets('içerik kataloğu Divan taleplerini ve boş olay durumunu gösterir', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? openedId;
    String? openedEventId;
    var caravanCalls = 0;
    late StateSetter rebuild;
    final eventPreviews = <DevEventPreview>[];
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return Scaffold(
              body: DevPanel(
                godMode: true,
                rainIntensity: 0,
                timeOfDay: 0.5,
                villagerCount: 6,
                buildingCount: 3,
                onClose: () {},
                onToggleGod: () {},
                onSetRain: (_) {},
                onSetTimeOfDay: (_) {},
                onAddResource: (ResourceKind _, int _) {},
                onSpawnVillager: () {},
                onKillRandomVillager: () {},
                onClearEffects: () {},
                onNewMap: () {},
                onWakeAll: () {},
                onSeedLivingVillage: () {},
                petitionPreviews: const [
                  (
                    id: 'personalStyle',
                    label: '🧵 Kendi Yolum',
                    condition: 'Normal: uygun yetişkin erkek',
                  ),
                  (
                    id: 'ovenTurn',
                    label: '🥖 Fırın Sırası',
                    condition: 'Normal: nüfus 4+',
                  ),
                  (
                    id: 'hearthSeat',
                    label: '🔥 Ateşin Yanındaki Yer',
                    condition: 'Normal: nüfus 3+',
                  ),
                  (
                    id: 'wellBucket',
                    label: '🪣 Ortak Kova',
                    condition: 'Normal: nüfus 4+',
                  ),
                  (
                    id: 'animalBell',
                    label: '🔔 Çanın Sesi',
                    condition: 'Normal: hayvan 1+',
                  ),
                  (
                    id: 'quietEvening',
                    label: '🎶 Akşam Türküsü',
                    condition: 'Normal: nüfus 5+',
                  ),
                ],
                onPreviewPetition: (id) => openedId = id,
                eventPreviews: eventPreviews,
                onPreviewEvent: (id) => openedEventId = id,
                simSpeedBoost: 1,
                simHistory: const [],
                onSetSimSpeed: (_) {},
                onClearSimHistory: () {},
                onScenarioBaseline: () {},
                onPlayMusic: () {},
                onStartDance: () {},
                onStartChat: () {},
                onStartConflict: () {},
                onIgniteFeud: () {},
                onStartCrime: () {},
                onClearActivities: () {},
                onSpawnCaravan: () => caravanCalls++,
                onSeedShowcase: () {},
                onSetDawn: () {},
                onSetNoon: () {},
                onSetDusk: () {},
                onSetNight: () {},
                onToggleRain: () {},
                snowOn: false,
                onToggleSnow: () {},
                season: Season.spring,
                onSeedReference: (_) {},
                onJumpSeason: (_) {},
                onAllPolicies: () {},
                onClearPolicies: () {},
                onUnlockAllCrafts: () {},
                onMakeSage: () {},
                onSpawnMigrant: () {},
                onSummonImperial: () {},
                perfMode: false,
                onTogglePerf: () {},
                devLogOn: false,
                onToggleDevLog: () {},
              ),
            );
          },
        ),
      ),
    );

    expect(find.text('İÇERİK KATALOĞU · 6'), findsOneWidget);
    expect(find.text('DİVAN TALEPLERİ'), findsOneWidget);
    expect(find.text('KÖY OLAYLARI'), findsOneWidget);
    expect(
      find.text(
        'Köy olayı kataloğu boş. Yeni olaylar eklendiğinde burada otomatik görünecek.',
      ),
      findsOneWidget,
    );
    for (final title in const [
      '🧵 Kendi Yolum',
      '🥖 Fırın Sırası',
      '🔥 Ateşin Yanındaki Yer',
      '🪣 Ortak Kova',
      '🔔 Çanın Sesi',
      '🎶 Akşam Türküsü',
    ]) {
      expect(find.text(title), findsOneWidget);
    }
    expect(find.textContaining('Komut Konsolu'), findsNothing);

    await tester.tap(find.text('🧵 Kendi Yolum'));
    expect(openedId, 'personalStyle');

    rebuild(
      () => eventPreviews.add((
        id: 'stormTest',
        label: '⛈️ Fırtına',
        condition: 'Şu an uygun · olumsuz · 2 seçenek',
      )),
    );
    await tester.pump();

    expect(find.text('İÇERİK KATALOĞU · 7'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('dev-content-empty-events')),
      findsNothing,
    );
    expect(find.text('⛈️ Fırtına'), findsOneWidget);
    await tester.ensureVisible(find.text('⛈️ Fırtına'));
    await tester.tap(find.text('⛈️ Fırtına'));
    expect(openedEventId, 'stormTest');

    await tester.ensureVisible(find.text('Kervan Çağır'));
    await tester.tap(find.text('Kervan Çağır'));
    expect(caravanCalls, 1);
  });
}
