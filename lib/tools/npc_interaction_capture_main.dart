// NPC ETKİLEŞİM KARESİ — tek tık konuşmasının gerçek sahne katmanını çeker.
//
// Çalıştır: flutter run -d macos -t lib/tools/npc_interaction_capture_main.dart
// Çıktı:    /tmp/npc_single_tap.png
import 'dart:io';

import 'package:flutter/material.dart';

import '../main.dart';
import 'capture_support.dart';

final GlobalKey _boundaryKey = GlobalKey();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final card = (Platform.environment['CARD'] ?? '0') == '1';
  kCaptureMode = true;
  kCaptureNpcInteraction = true;
  kCaptureNpcCard = card;
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RepaintBoundary(
        key: _boundaryKey,
        child: const VillageScene(referenceVillage: true),
      ),
    ),
  );

  var waited = 0;
  while (!kCaptureSceneReady && waited < 400) {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    waited++;
  }
  if (!kCaptureSceneReady) exit(1);
  await Future<void>.delayed(const Duration(milliseconds: 900));
  await captureBoundary(
    _boundaryKey,
    card ? '/tmp/npc_double_tap.png' : '/tmp/npc_single_tap.png',
    pixelRatio: 1.5,
  );
  exit(0);
}
