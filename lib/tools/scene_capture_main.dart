// Sahne yakalama harness'ı — menüyü atlar, taze bir köy (VillageScene) render
// eder ve RepaintBoundary.toImage ile PNG'ye çeker. Pencere-capture DEĞİL
// (render-tree capture) → macOS accessibility izni gerekmez.
//
// Çalıştır:  flutter run -d macos -t lib/tools/scene_capture_main.dart
// Çıktı:     /tmp/village_canopy.png  (birkaç sn sonra otomatik yazar + çıkar)
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../main.dart';

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
  await _capture();
  exit(0);
}

Future<void> _capture() async {
  final ctx = _boundaryKey.currentContext;
  if (ctx == null) {
    stdout.writeln('CAPTURE_FAIL: no context');
    return;
  }
  final boundary = ctx.findRenderObject() as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1.5);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  if (bytes == null) {
    stdout.writeln('CAPTURE_FAIL: no bytes');
    return;
  }
  const path = '/tmp/village_canopy.png';
  await File(path).writeAsBytes(bytes.buffer.asUint8List());
  stdout.writeln('CAPTURED: $path');
}
