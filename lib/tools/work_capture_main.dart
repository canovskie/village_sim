// Meslek İŞ DÖNGÜSÜ doğrulama harness'ı — showcase köyünü kurar (kilise +
// değirmen + taverna + sürü + her yeni meslekten bir köylü), simülasyonu
// çalıştırır ve iş döngülerinin GERÇEKTEN döndüğünü telemetriyle ölçer:
//   • avcı ava çıkıyor mu   → food artıyor mu
//   • çoban sürüyü besliyor mu → herdHunger düşüyor / dizginleniyor mu
//   • değirmenci/hancı/rahip işyerine gidiyor mu → d (uzaklık) düşüyor mu
//
// Çalıştır:  flutter run -d macos -t lib/tools/work_capture_main.dart
// Çıktı:     /tmp/work.png + stdout'a WORK@<sn> satırları
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../main.dart';

final GlobalKey _boundaryKey = GlobalKey();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  kCaptureMode = true;      // açılış sinematiğini atla
  kCaptureShowcase = true;  // showcase köyü (iş döngüsü test yatağı)
  kCaptureZoom = 0.85;

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: RepaintBoundary(
      key: _boundaryKey,
      child: const VillageScene(),
    ),
  ));

  // Sahne + asset hazır olsun.
  while (!kCaptureSceneReady) {
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }

  // Simülasyonu izle — iş döngüleri dönerken telemetriyi periyodik bas.
  for (int s = 5; s <= 60; s += 5) {
    await Future<void>.delayed(const Duration(seconds: 5));
    stdout.writeln('WORK@${s}s  $kCaptureWorkReport');
  }

  await _capture('/tmp/work.png');
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
