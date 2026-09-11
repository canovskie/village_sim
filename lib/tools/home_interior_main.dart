import 'dart:io';

import 'package:flutter/material.dart';

import '../characters/life_stage.dart';
import '../characters/villager_type.dart';
import '../entities/villager_entity.dart';
import '../text/voice.dart';
import '../ui/core/app_ui.dart';
import '../ui/screens/home_interior_screen.dart';
import 'capture_support.dart';

/// Menü/köy kurulumu olmadan: flutter run -d macos -t lib/tools/home_interior_main.dart
/// INTERIOR_CAPTURE=/tmp/home.png ile sabit yatay kare alıp kapanır.
final _captureKey = GlobalKey();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final capture = Platform.environment['INTERIOR_CAPTURE'];
  runApp(HomeInteriorDemoApp(capture: capture != null));
  if (capture != null) {
    await settleFrames(8500);
    final ok = await captureBoundary(_captureKey, capture, pixelRatio: 1.5);
    exit(ok ? 0 : 1);
  }
}

class HomeInteriorDemoApp extends StatelessWidget {
  final bool capture;
  const HomeInteriorDemoApp({super.key, this.capture = false});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(
      useMaterial3: true,
    ).copyWith(scaffoldBackgroundColor: AppUi.surface0),
    home: capture
        ? FittedBox(
            child: MediaQuery(
              data: const MediaQueryData(
                size: Size(1100, 760),
                devicePixelRatio: 1,
              ),
              child: SizedBox(
                width: 1100,
                height: 760,
                child: RepaintBoundary(
                  key: _captureKey,
                  child: const _HomeDemo(),
                ),
              ),
            ),
          )
        : RepaintBoundary(key: _captureKey, child: const _HomeDemo()),
  );
}

class _HomeDemo extends StatefulWidget {
  const _HomeDemo();
  @override
  State<_HomeDemo> createState() => _HomeDemoState();
}

class _HomeDemoState extends State<_HomeDemo> {
  bool _inside = true;
  final residents = [
    VillagerEntity(
      type: VillagerType.farmer,
      name: 'Elif',
      surname: 'Çınar',
      male: false,
      startCol: 0,
      startRow: 0,
      visualSeed: 23,
      ageDays: kAdultStartDay + 12,
    ),
    VillagerEntity(
      type: VillagerType.miller,
      name: 'Yusuf',
      surname: 'Çınar',
      male: true,
      startCol: 0,
      startRow: 0,
      visualSeed: 51,
      ageDays: kAdultStartDay + 18,
    ),
  ];

  @override
  Widget build(BuildContext context) => _inside
      ? HomeInteriorScreen(
          residents: residents,
          demo: true,
          // Yeni açılışta önceki simetrik odadan farklı hazır kombinasyon.
          decorSeed: 5,
          onClose: () => setState(() => _inside = false),
        )
      : Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(HomeInteriorVoice.title, style: AppUi.title),
                const SizedBox(height: 18),
                GestureDetector(
                  onTap: () => setState(() => _inside = true),
                  child: Image.asset(
                    'assets/buildings/minihouse.png',
                    width: 280,
                    height: 260,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 14),
                Text(HomeInteriorVoice.exteriorHint, style: AppUi.body),
                const SizedBox(height: 14),
                FilledButton.icon(
                  key: const ValueKey('interior-enter'),
                  onPressed: () => setState(() => _inside = true),
                  icon: const Icon(Icons.door_front_door_outlined),
                  label: Text(HomeInteriorVoice.enter),
                ),
              ],
            ),
          ),
        );
}
