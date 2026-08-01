// KURULUŞUN İLK DAKİKASI — yönlendirme gerçekten yol gösteriyor mu?
//
// Taze bir köy kurar (kurucu kadro + hiçbir bina yok), birkaç saniye sim
// akıtır ve kareyi PNG'ye çeker. Bakılacak şey: oyuncu ekrana ilk baktığında
// NE YAPACAĞINI anlıyor mu — HUD şeridindeki cümle ile dünyadaki işaret aynı
// şeyi mi gösteriyor.
//
// Çalıştır:  OUT=/tmp/onboard.png flutter run -d macos -t lib/tools/onboarding_capture_main.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../main.dart';

final GlobalKey _boundaryKey = GlobalKey();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  kCaptureMode = true; // açılış sinematiğini atla
  // Sabah: ilk adım gündüz okunmalı (gece işareti ayrı bir sınav).
  kCaptureTimeOfDay = 0.35;
  kCaptureZoom = 0.95; // kurucular ve çevresi kadraja girsin

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: RepaintBoundary(
      key: _boundaryKey,
      child: const VillageScene(), // taze köy — kuruluş baştan
    ),
  ));

  var waited = 0;
  while (!kCaptureSceneReady && waited < 400) {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    waited++;
  }
  // Akış taraması (0.5 sn) birkaç kez dönsün ki adım + işaret otursun.
  await Future<void>.delayed(const Duration(seconds: 4));
  // TEŞHİS: kare çekilmeden önce akışın nabzını bas. "Şerit bazen yok"
  // şikâyetinde tek soru bu — tarama koştu mu, koştuysa ne buldu?
  stdout.writeln('FLOW: $kFlowDebug');
  await _capture(Platform.environment['OUT'] ?? '/tmp/onboard.png');
  exit(0);
}

Future<void> _capture(String path) async {
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
  await File(path).writeAsBytes(bytes.buffer.asUint8List());
  stdout.writeln('CAPTURED: $path');
}
