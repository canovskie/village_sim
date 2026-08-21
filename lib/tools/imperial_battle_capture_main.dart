// Eşik muharebesi görsel doğrulama harness'ı. Heyeti çağırır, pazarlığı karşı
// hücum doktriniyle otomatik kapatır ve ilk temas + köy karşılığı karelerini alır.
//
// Çalıştır: flutter run -d macos -t lib/tools/imperial_battle_capture_main.dart
// Çıktı: /tmp/imperial_battle.png
import 'dart:io';

import 'package:flutter/material.dart';

import '../main.dart';
import '../systems/imperial.dart';
import 'capture_support.dart';

final GlobalKey _boundaryKey = GlobalKey();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  kCaptureMode = true;
  kCaptureShowcase = true;
  kCaptureAutoWatch = true;
  kCaptureZoom = 1.35;
  kCaptureImperialBattle = true;
  kProbeOn = true;
  kProbeImperialArmed = true;
  kProbeForceResistWin = true;

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RepaintBoundary(key: _boundaryKey, child: const VillageScene()),
    ),
  );

  while (!kCaptureSceneReady) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  kDevSpeedBoostOverride = 8;
  kProbeSummonImperial = true;
  while (kProbeVignetteId != kThresholdVignetteId) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  kDevSpeedBoostOverride = 0;

  // Pencere öndeyken motorun doğal saatini kullan. Elle kare pompalamak burada
  // AnimationController saatleriyle yarışır ve muharebeyi ileri sarar.
  await Future<void>.delayed(const Duration(milliseconds: 15500));
  await captureBoundary(
    _boundaryKey,
    '/tmp/imperial_battle.png',
    pixelRatio: 1.5,
  );
  exit(0);
}
