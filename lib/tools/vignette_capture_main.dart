// OLAY VİNYETİ harness'ı — 9 sahnenin GÖRSEL doğrulaması.
//
// Test (test/event_vignette_test.dart) sahnenin kurulduğunu ve kadronun
// salıverildiğini kanıtlar; ama koreografinin OKUNUP okunmadığını yalnız göz
// söyler: kova gerçekten boş mu duruyor, çöken adam yerde mi, kova zinciri
// kuyuyla ev arasında mı akıyor.
//
// Her olay için sahnenin ortasından bir kare alır. Kamera "İzle"ye basılmış
// gibi odağa kilitlenir (kCaptureAutoWatch).
//
// Çalıştır:  flutter run -d macos -t lib/tools/vignette_capture_main.dart
// Çıktı:     preview/vignette_<olay>.png
//
// TUZAK (bu projede defalarca vakit yedi): pencere arka plandaysa macOS kare
// üretmez — koşarken pencereyi ÖNDE tut.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../main.dart';
import '../systems/event_system.dart';

final GlobalKey _boundaryKey = GlobalKey();

/// Sırayla sahnelenecek olaylar. Tek bir olayı incelemek için `ONLY=id` ver.
const _order = [
  EventIds.drought,
  EventIds.plague,
  EventIds.houseFire,
  EventIds.beastRaid,
  EventIds.storm,
  EventIds.bounty,
  EventIds.caravan,
  EventIds.bard,
  EventIds.accord,
];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  kCaptureMode = true;      // açılış sinematiğini atla
  kCaptureShowcase = true;  // oturmuş köy: kuyu/pazar/ambar/ağıl hepsi var
  kCaptureAutoWatch = true; // kamera sahneye kilitlensin
  kCaptureZoom = 1.35;      // gövde dili 37 px'te okunmaz — yakınlaş

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: RepaintBoundary(key: _boundaryKey, child: const VillageScene()),
  ));

  while (!kCaptureSceneReady) {
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  await Future<void>.delayed(const Duration(seconds: 3));

  final only = Platform.environment['ONLY'] ?? '';
  await Directory('preview').create(recursive: true);

  for (final id in _order) {
    if (only.isNotEmpty && only != id) continue;
    kForcedEventId = id;
    kProbeTriggerEvent = true;
    // Omen 4-7 sn + vurma. Karar gerektiren olayda modal açılır ve sim DURUR;
    // harness tıklayamaz, o yüzden zaman aşımıyla geçilir (o üç olayın sahnesi
    // karardan sonra oynar — oyunda modaldan seçince görünür).
    var waited = 0;
    while (kProbeVignetteId != id && waited < 20) {
      await Future<void>.delayed(const Duration(seconds: 1));
      waited++;
    }
    if (kProbeVignetteId != id) {
      stdout.writeln('SKIP $id (karar modalı bekliyor — elle seç)');
      continue;
    }
    // Koreografinin ortası: yürüyüşler bitmiş, iş duruşları başlamış olur.
    await Future<void>.delayed(const Duration(seconds: 9));
    await _capture('preview/vignette_$id.png', id);
    // Sahne kapansın (ömür 30 sn) — sıradaki olay temiz kadro bulsun.
    while (kProbeVignetteId.isNotEmpty) {
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    await Future<void>.delayed(const Duration(seconds: 2));
  }
  exit(0);
}

Future<void> _capture(String path, String id) async {
  final ctx = _boundaryKey.currentContext;
  if (ctx == null) {
    stdout.writeln('CAPTURE_FAIL $id: no context');
    return;
  }
  final boundary = ctx.findRenderObject() as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1.5);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  if (bytes == null) {
    stdout.writeln('CAPTURE_FAIL $id: no bytes');
    return;
  }
  await File(path).writeAsBytes(bytes.buffer.asUint8List());
  stdout.writeln('CAPTURED $path (kadro=$kProbeVignetteCast)');
}
