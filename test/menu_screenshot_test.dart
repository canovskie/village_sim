import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/core/resources.dart';
import 'package:village_sim/ui/app_ui.dart';
import 'package:village_sim/ui/hud.dart';
import 'package:village_sim/ui/main_menu_screen.dart';

// Gerçek fontlarla ekranları PNG'ye basar — görsel doğrulama için.
// toImage + FontLoader runAsync içinde olmalı, yoksa test asılır.
// Çalıştır: flutter test test/menu_screenshot_test.dart
void main() {
  Future<void> shoot(WidgetTester tester, Widget child, String name,
      Size size) async {
    await tester.runAsync(() async {
      for (final entry in {
        'Cinzel': ['assets/fonts/Cinzel-VF.ttf'],
        'Spectral': [
          'assets/fonts/Spectral-Regular.ttf',
          'assets/fonts/Spectral-Medium.ttf',
          'assets/fonts/Spectral-SemiBold.ttf',
          'assets/fonts/Spectral-Bold.ttf',
        ],
      }.entries) {
        final loader = FontLoader(entry.key);
        for (final path in entry.value) {
          loader.addFont(rootBundle.load(path));
        }
        await loader.load();
      }
    });

    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(debugShowCheckedModeBanner: false, home: child),
    ));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 350));

    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('test/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    });
    // ignore: avoid_print
    print('WROTE test/$name.png');
  }

  testWidgets('main menu', (tester) async {
    await shoot(tester, MainMenuScreen(onNewGame: () {}), 'shot_menu',
        const Size(900, 1400));
  });

  testWidgets('ui kit showcase', (tester) async {
    await shoot(tester, const _Showcase(), 'shot_kit', const Size(820, 1200));
  });

  testWidgets('hud', (tester) async {
    final hud = Container(
      color: const Color(0xFF3A5A3A), // oyun zemini taklidi
      child: GameHUD(
        stockpile: ResourceBundle(
            wood: 124, stone: 56, iron: 12, coal: 8, food: 230, gold: 47, honey: 6),
        woodInTransit: 8, stoneInTransit: 0, ironInTransit: 2,
        coalInTransit: 0, foodInTransit: 12,
        villagerCount: 6, farmerCount: 4, woodcutterCount: 3,
        minerCount: 2, fisherCount: 1, builderCount: 2, busyBuilders: 1,
        timeOfDay: 0.78, rainIntensity: 0, dayLight: 0.45, dayCount: 14,
        buildingCount: 9, pendingOrderCount: 1,
        morale: 0.72, lowWater: false, starving: false,
        eventLabel: 'bereket', godMode: false,
        onNewMap: () {}, onToggleGod: () {}, onTriggerEvent: () {},
        timeScale: 2.0, onCycleSpeed: () {}, onToggleDev: () {},
        effectTimeLeft: 18, effectDuration: 30, effectPositive: true,
      ),
    );
    await shoot(tester, hud, 'shot_hud', const Size(1100, 700));
  });
}

/// app_ui bileşenlerini tek ekranda gösterir — panel, buton, ikon, stat bar.
class _Showcase extends StatelessWidget {
  const _Showcase();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF120D08),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: AppPanel(
          width: 360,
          accent: AppUi.accent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('DEĞİRMEN', style: AppUi.title),
              const SizedBox(height: 4),
              const AppChip(label: 'ÜRETİM', color: AppUi.accent),
              const SizedBox(height: 14),
              const AppStatBar(
                  label: 'İŞÇİ', value: 0.75, trailing: '3/4', color: AppUi.sage),
              const SizedBox(height: 8),
              const AppStatBar(
                  label: 'STOK', value: 0.4, trailing: '40%', color: AppUi.accent),
              const AppDivider(),
              const AppSectionLabel('İKONLAR'),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final i in GameIconData.values)
                    GameIcon(i, size: 22, color: AppUi.textMid),
                ],
              ),
              const SizedBox(height: 16),
              const AppSectionLabel('AKSİYONLAR'),
              Wrap(spacing: 8, runSpacing: 8, children: const [
                AppButton(
                    label: 'Şenlik',
                    icon: GameIconData.festival,
                    kind: AppButtonKind.filled,
                    sub: '8 yem · 5 altın'),
                AppButton(
                    label: 'Durdur', icon: GameIconData.pause),
                AppButton(
                    label: 'Yık',
                    icon: GameIconData.demolish,
                    kind: AppButtonKind.danger),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
