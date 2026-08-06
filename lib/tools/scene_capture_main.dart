// Sahne yakalama harness'ı — menüyü atlar, taze bir köy (VillageScene) render
// eder ve RepaintBoundary.toImage ile PNG'ye çeker. Pencere-capture DEĞİL
// (render-tree capture) → macOS accessibility izni gerekmez.
//
// Çalıştır:  flutter run -d macos -t lib/tools/scene_capture_main.dart
// Çıktı:     /tmp/village_canopy.png  (birkaç sn sonra otomatik yazar + çıkar)
import 'dart:io';
import 'package:flutter/material.dart';
import '../main.dart';
import 'capture_support.dart';

final GlobalKey _boundaryKey = GlobalKey();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  kCaptureMode = true; // açılış sinematiğini atla → sahne doğrudan aksın
  kCaptureZoom = 0.75; // sınır detayı (undergrowth geçişi) + biraz derinlik
  kCaptureCarve = 4;   // 4 halka oy → recede + kütük izleri görünsün
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: RepaintBoundary(
      key: _boundaryKey,
      child: const VillageScene(), // initialWorld null → taze köy üretir
    ),
  ));

  // Asset yüklenene kadar bekle (değişken süre), sonra birkaç tick otursun.
  var waited = 0;
  while (!kCaptureSceneReady && waited < 400) { // ~120sn tolerans (cold build)
    await Future<void>.delayed(const Duration(milliseconds: 300));
    waited++;
  }
  await Future<void>.delayed(const Duration(seconds: 2)); // tick + frame otursun
  await captureBoundary(_boundaryKey, '/tmp/village_canopy.png', pixelRatio: 1.5);
  exit(0);
}

