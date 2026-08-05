// EKRAN GÖRÜNTÜSÜ SETİ — oyunun canlı sahnesinden (HUD dahil) 6 kare.
//
// Referans köy (sabit tohum, oturmuş yerleşim) kurulur, sonra günün vakti
// sırayla dondurulup her vakitte bir kare çekilir. Aralarda sim akmaya devam
// eder → köylüler/hayvanlar yer değiştirir, kareler birbirinin kopyası olmaz.
//
// Pencere 800×600 olsa bile çıktı 1600×900 mantıksal ölçüde: MediaQuery
// override + SizedBox ile o ölçüde layout edilir, FittedBox yalnız EKRANDA
// küçültür — toImage boundary'nin KENDİ katmanını çizdiği için çıktı tam boy.
//
// Çalıştır:  flutter run -d macos -t lib/tools/shots_capture_main.dart
// Çıktı:     ~/Desktop/village_shots/*.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../main.dart';

final GlobalKey _boundaryKey = GlobalKey();

const double _w = 1600, _h = 900;

/// (dosya adı, günün vakti) — 0.25 şafak, 0.5 öğle, 0.75 gün batımı.
const _shots = <(String, double)>[
  ('1_safak', 0.27),
  ('2_sabah', 0.40),
  ('3_ogle', 0.52),
  ('4_altin_saat', 0.71),
  ('5_gun_batimi', 0.77),
  ('6_gece', 0.93),
];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  kCaptureMode = true; // sinematik + ateş yerleştirme + ses motoru atlanır

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: FittedBox(
      fit: BoxFit.contain,
      child: MediaQuery(
        data: const MediaQueryData(
          size: Size(_w, _h),
          devicePixelRatio: 2.0,
          textScaler: TextScaler.linear(1.0),
        ),
        child: SizedBox(
          width: _w,
          height: _h,
          child: RepaintBoundary(
            key: _boundaryKey,
            // slotId boş → _saveNow erken döner, kullanıcının kayıt listesi
            // kirlenmez (referans köy yine sabit tohumla kurulur).
            child: const VillageScene(referenceVillage: true),
          ),
        ),
      ),
    ),
  ));

  var waited = 0;
  while (!kCaptureSceneReady && waited < 400) {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    waited++;
  }
  if (!kCaptureSceneReady) {
    stdout.writeln('CAPTURE_FAIL: sahne hazır olmadı');
    exit(1);
  }
  // Köy otursun: NPC'ler işlerine dağılsın, duman/ateş dönsün.
  await Future<void>.delayed(const Duration(seconds: 6));

  final dir = Directory('${Platform.environment['HOME']}/Desktop/village_shots');
  await dir.create(recursive: true);

  String? prevHash;
  for (final (name, tod) in _shots) {
    kCaptureTimeOfDay = tod;
    // Vakit tick'te sabitlenir + ışık/gökyüzü yeniden çizilir; sim de aksın.
    await Future<void>.delayed(const Duration(seconds: 3));
    final hash = await _capture('${dir.path}/$name.png');
    // Pencere arka plandaysa macOS kare üretmez → aynı görüntü tekrar yazılır.
    if (hash != null && hash == prevHash) {
      stdout.writeln('STALE: $name önceki kareyle AYNI (pencere önde mi?)');
    }
    prevHash = hash;
  }
  stdout.writeln('SHOTS_DONE: ${dir.path}');
  exit(0);
}

Future<String?> _capture(String path) async {
  final ctx = _boundaryKey.currentContext;
  if (ctx == null) {
    stdout.writeln('CAPTURE_FAIL: no context');
    return null;
  }
  final boundary = ctx.findRenderObject() as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1.5);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  if (bytes == null) {
    stdout.writeln('CAPTURE_FAIL: no bytes');
    return null;
  }
  final data = bytes.buffer.asUint8List();
  await File(path).writeAsBytes(data);
  stdout.writeln('CAPTURED: $path (${data.length ~/ 1024} KB)');
  // Ucuz imza — bayat kare tespiti için yeterli.
  var h = 0;
  for (int i = 0; i < data.length; i += 997) {
    h = (h * 31 + data[i]) & 0x7FFFFFFF;
  }
  return '$h:${data.length}';
}
