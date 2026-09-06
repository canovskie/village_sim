import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/core/resources.dart';
import 'package:village_sim/ui/dev/village_tester_panel.dart';
import 'package:village_sim/world/season.dart';

void main() {
  testWidgets(
    'tester hazır köy sunmadan canlı teşhis ve üç kısa sekme gösterir',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_testApp());

      expect(find.text('CANLI KÖY TESTER'), findsOneWidget);
      expect(find.text('Doğal koşu · hazır köy yok'), findsOneWidget);
      expect(find.text('İzle'), findsOneWidget);
      expect(find.text('Dünya'), findsOneWidget);
      expect(find.text('Eylem'), findsOneWidget);
      expect(find.text('Yiyecek kritik: 3 / 10'), findsOneWidget);
      expect(find.text('2 köylünün kalıcı evi yok'), findsOneWidget);
      expect(find.textContaining('Showcase'), findsNothing);
      expect(find.textContaining('Referans Köy'), findsNothing);
    },
  );

  testWidgets('dünya ve eylem kontrolleri doğrudan callback üretir', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    double? speed;
    VillageTesterWeather? weather;
    (ResourceKind, int)? resource;
    var chatCount = 0;
    var caravanCount = 0;
    var freshRuns = 0;

    await tester.pumpWidget(
      _testApp(
        onSetSpeed: (value) => speed = value,
        onSetWeather: (value) => weather = value,
        onAddResource: (kind, amount) => resource = (kind, amount),
        onStartChat: () => chatCount++,
        onSpawnCaravan: () => caravanCount++,
        onFreshRun: () => freshRuns++,
      ),
    );

    await tester.tap(find.text('Dünya'));
    await tester.pump();
    expect(find.byKey(const ValueKey('village-tester-world')), findsOneWidget);

    await tester.tap(find.text('12×'));
    expect(speed, 12);
    await tester.tap(find.text('Fırtına'));
    expect(weather, VillageTesterWeather.storm);
    await tester.tap(find.text('+10'));
    expect(resource, (ResourceKind.wood, 10));

    await tester.tap(find.text('Eylem'));
    await tester.pump();
    await tester.tap(find.text('Sohbet'));
    expect(chatCount, 1);
    await tester.tap(find.text('Kervan'));
    expect(caravanCount, 1);

    await tester.ensureVisible(
      find.byKey(const ValueKey('village-tester-fresh-run')),
    );
    await tester.tap(find.byKey(const ValueKey('village-tester-fresh-run')));
    await tester.pumpAndSettle();
    expect(find.text('Yeni doğal koşu'), findsOneWidget);
    await tester.tap(find.text('YENİDEN BAŞLAT'));
    await tester.pumpAndSettle();
    expect(freshRuns, 1);
  });
}

Widget _testApp({
  ValueChanged<double>? onSetSpeed,
  ValueChanged<VillageTesterWeather>? onSetWeather,
  void Function(ResourceKind, int)? onAddResource,
  VoidCallback? onStartChat,
  VoidCallback? onSpawnCaravan,
  VoidCallback? onFreshRun,
}) {
  void noop() {}

  return MaterialApp(
    home: Scaffold(
      backgroundColor: Colors.blueGrey,
      body: Align(
        alignment: Alignment.topRight,
        child: VillageTesterPanel(
          snapshot: const VillageTesterSnapshot(
            day: 4,
            villagers: 6,
            buildings: 3,
            pendingOrders: 1,
            homeless: 2,
            food: 3,
            wood: 24,
            stone: 9,
            iron: 0,
            timeOfDay: 0.5,
            speed: 1,
            rainIntensity: 0,
            snowing: false,
            godMode: false,
            season: Season.spring,
            warnings: ['Yiyecek kritik: 3 / 10', '2 köylünün kalıcı evi yok'],
          ),
          onHide: noop,
          onSetSpeed: onSetSpeed ?? (_) {},
          onSetTime: (_) {},
          onSetWeather: onSetWeather ?? (_) {},
          onAddResource: onAddResource ?? (_, _) {},
          onToggleGod: noop,
          onSpawnVillager: noop,
          onWakeAll: noop,
          onStartChat: onStartChat ?? noop,
          onStartDance: noop,
          onStartConflict: noop,
          onStartCrime: noop,
          onSpawnCaravan: onSpawnCaravan ?? noop,
          onSpawnTraveler: noop,
          onSpawnStranger: noop,
          onClearActivities: noop,
          onClearEffects: noop,
          onFreshRun: onFreshRun,
        ),
      ),
    ),
  );
}
