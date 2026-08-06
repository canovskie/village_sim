// İmparatorluk varış anonsu (buildImperialAlert) yakalama harness'ı — dolu bir
// köy üstünde anonsu tetikler, giriş animasyonu otursun diye bekler, tam-ekran
// "İMPARATORLUK GELİYOR" tasarımını PNG'ye çeker. Görsel doğrulama için.
//
// Çalıştır:  flutter run -d macos -t lib/tools/imperial_alert_capture_main.dart
// Çıktı:     /tmp/imperial_alert.png
import 'dart:io';
import 'package:flutter/material.dart';
import '../main.dart';
import 'capture_support.dart';

final GlobalKey _boundaryKey = GlobalKey();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  kCaptureMode = true;
  kCaptureShowcase = true;       // dolu köy arka planı
  kCaptureImperialAlert = true;  // anonsu sahne hazır olunca tetikle
  kCaptureZoom = 0.85;
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: RepaintBoundary(
      key: _boundaryKey,
      child: const VillageScene(),
    ),
  ));

  var waited = 0;
  while (!kCaptureSceneReady && waited < 400) {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    waited++;
  }
  // Anons tetiklendikten sonra giriş animasyonu (letterbox + slam-in) otursun,
  // held-state'te (tam alpha) yakala.
  await Future<void>.delayed(const Duration(milliseconds: 1500));
  await captureBoundary(_boundaryKey, '/tmp/imperial_alert.png', pixelRatio: 1.5);
  exit(0);
}

