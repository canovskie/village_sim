// SUÇ doğrulama harness'ı — showcase köyünü kurar (depo/pazar/ağıl/sürü +
// muhafız) ve suç döngüsünün GERÇEKTEN döndüğünü telemetriyle ölçer:
//   • fail hedefe sokuluyor mu       → evre=prowl, dHedef düşüyor mu
//   • eylem gerçekleşiyor mu         → evre=act → done=1 + kaynak eksiliyor mu
//   • kaçış + yakalanma çalışıyor mu → evre=flee / muhafız act=chasing → sicilli↑
//   • meçhul kalan suç şüphe biriktiriyor mu → şüphe↑ → asayiş dilekçesi
//
// kCaptureCrime olasılık kapısını atlar: suç biter bitmez yenisi kurulur, yani
// 60 sn'de bütün evreler defalarca gözlenir (normal oyunda suç NADİRDİR).
//
// Çalıştır:  flutter run -d macos -t lib/tools/crime_capture_main.dart
// Çıktı:     /tmp/crime.png + stdout'a CRIME@<sn> satırları
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../main.dart';
// Hedefli tek-suç testi açılacaksa gerekir (aşağıdaki kCaptureCrimeKind satırı):
// import '../systems/crime_system.dart';

final GlobalKey _boundaryKey = GlobalKey();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  kCaptureMode = true;     // açılış sinematiğini atla
  kCaptureShowcase = true; // showcase köyü (depo + ağıl + sürü + muhafız)
  kCaptureCrime = true;    // suç test yatağı: olasılık kapısını atla
  // NİZAM_SEAL=1 → kılıç kolu baştan mühürlü (Kürek Cezası + Hane Sicili testi).
  kCaptureSealNizam = (Platform.environment['NIZAM_SEAL'] ?? '0') == '1';
  // NO_GUARD=1 → muhafızsız köy: suç tamamlanıp KAÇAR. Registry yoksa şüphe
  // birikir (asayiş); registry varsa sicil kaçan faili yargıya çıkarır.
  kCaptureNoGuard = (Platform.environment['NO_GUARD'] ?? '0') == '1';
  // LABOR_ONLY=1 → her yargıda kürek cezasını seç (taş kazanımını gözle).
  kCaptureLaborOnly = (Platform.environment['LABOR_ONLY'] ?? '0') == '1';
  // Hedefli test için (varsayılan: kapalı — rastgele suç + muhafızlı köy):
  //   kCaptureCrimeKind = CrimeKind.abduction; // tek bir suçu zorla
  //   kCaptureNoGuard = true;  // muhafızsız köy → suç tamamlanır, kaçar,
  //                            // şüphe birikir, asayiş dilekçesi gelir
  kCaptureZoom = 0.85;

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: RepaintBoundary(
      key: _boundaryKey,
      child: const VillageScene(),
    ),
  ));

  while (!kCaptureSceneReady) {
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }

  // Suç döngüsünü izle — evreler dönerken telemetriyi sık bas (evre geçişleri
  // birkaç saniye sürer; 3 sn'lik örnekleme hepsini yakalar).
  for (int s = 3; s <= 75; s += 3) {
    await Future<void>.delayed(const Duration(seconds: 3));
    stdout.writeln('CRIME@${s}s  $kCaptureCrimeReport');
  }
  stdout.writeln('NIZAM_SEAL=${kCaptureSealNizam ? 1 : 0}');

  await _capture('/tmp/crime.png');
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
