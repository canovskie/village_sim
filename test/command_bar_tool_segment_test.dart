import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/ui/core/mode_button.dart';
import 'package:village_sim/ui/hud/command_bar.dart';

void main() {
  Widget tools(VoidCallback onFarm) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      ModeButton(
        icon: '🌾',
        label: 'Tarla',
        active: false,
        accentColor: Colors.green,
        onTap: onFarm,
      ),
      ModeButton(
        icon: '🪓',
        label: 'Kes',
        active: false,
        accentColor: Colors.orange,
        onTap: () {},
      ),
      ModeButton(
        icon: '⛏',
        label: 'Kaz',
        active: false,
        accentColor: Colors.indigo,
        onTap: () {},
      ),
    ],
  );

  testWidgets('arazi araçları masaüstünde inşa kapısının yanında kalır', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var farmTaps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: CommandBar(
              buildSegment: const SizedBox.shrink(),
              toolSegment: tools(() => farmTaps++),
              showCivicGates: false,
              onDefter: () {},
              onDivan: () {},
              onRoster: () {},
            ),
          ),
        ),
      ),
    );

    final buildRect = tester.getRect(
      find.byKey(const ValueKey('desktop_build_button')),
    );
    final farmRect = tester.getRect(find.text('TARLA'));
    expect(farmRect.left, greaterThan(buildRect.right));

    await tester.tap(find.text('TARLA'));
    expect(farmTaps, 1);
  });

  testWidgets('arazi araçları kompakt komuta hattına taşmadan sığar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(760, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: CommandBar(
              buildSegment: const SizedBox.shrink(),
              toolSegment: tools(() {}),
              onDefter: () {},
              onDivan: () {},
              onRoster: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('TARLA'), findsOneWidget);
    expect(find.text('KES'), findsOneWidget);
    expect(find.text('KAZ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
