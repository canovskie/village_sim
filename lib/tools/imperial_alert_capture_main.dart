// İmparatorluk varış anonsu (buildImperialAlert) yakalama harness'ı — dolu bir
// köy üstünde anonsu tetikler, giriş animasyonu otursun diye bekler, tam-ekran
// "İMPARATORLUK GELİYOR" tasarımını PNG'ye çeker. Görsel doğrulama için.
//
// Çalıştır:  flutter run -d macos -t lib/tools/imperial_alert_capture_main.dart
// Çıktı:     /tmp/imperial_alert.png
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../main.dart';

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
  const path = '/tmp/imperial_alert.png';
  await File(path).writeAsBytes(bytes.buffer.asUint8List());
  stdout.writeln('CAPTURED: $path');
}
