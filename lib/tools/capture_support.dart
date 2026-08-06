/// ÇEKİM HARNESS'LARININ ORTAK ZEMİNİ.
///
/// `lib/tools/*_capture_main.dart` dosyalarının hepsi aynı iki şeyi yapıyordu:
/// kareyi elde pompala, sonra RepaintBoundary'yi PNG'ye yaz. Yirmi iki dosyada
/// yirmi iki kopya vardı ve kopyalar birbirinden AYRIŞMIŞTI — kimi `Stopwatch`
/// ile, kimi biriken damgayla pompalıyordu; birinde öğrenilen ders (macOS'ta
/// pencere arkadayken kare üretilmemesi) öbürüne geçmiyordu. Tek kapı olunca
/// ders de tek yerde durur.
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

// ── Kare pompalama ──────────────────────────────────────────────────────────

/// Elle ilerleyen kare damgası. Motorun kendi saatiyle YARIŞMASIN diye ayrı
/// tutulur ve yalnız artar: `handleBeginFrame` geriye giden bir damga görürse
/// `elapsedInSeconds >= 0.0` assert'i öter.
Duration _stamp = Duration.zero;

/// [ms] kadar süre boyunca kareyi ELDE zorlar.
///
/// Neden gerekli: macOS'ta pencere ön planda değilken motor kendiliğinden kare
/// üretmez. O sırada çözülen bir asset (font, PNG) bir daha boyanmaz ve karede
/// EKSİK çıkar — logosuz menü, boş panel. Gerçek zamanın da geçmesi şart:
/// asset/font yüklemesi yalnız kare pompalayarak tamamlanmaz, bu yüzden her
/// adımda hem bekliyoruz hem pompalıyoruz.
Future<void> settleFrames(int ms) async {
  final b = WidgetsBinding.instance;
  final steps = (ms / 16).ceil();
  for (int i = 0; i < steps; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 16));
    if (b.schedulerPhase != SchedulerPhase.idle) continue;
    _stamp += const Duration(milliseconds: 16);
    b.handleBeginFrame(_stamp);
    b.handleDrawFrame();
  }
}

/// Motor saati ↔ elle pompalama çakışması mı — gerçek layout hatası değil.
/// Hata sayan harness'lar (galeri, defter) bunu toplamdan düşer.
bool isClockClash(String s) => s.contains('elapsedInSeconds >= 0.0');

// ── PNG'ye yazma ────────────────────────────────────────────────────────────

/// [key]'in gösterdiği [RenderRepaintBoundary]'yi [path]'e PNG yazar.
///
/// Başarıda `CAPTURED: <path>`, başarısızlıkta `CAPTURE_FAIL: <sebep>` basar —
/// harness'ı terminalden koşturan kişi kareye bakmadan sonucu görsün diye.
/// Dönüş değeri, çok kareli harness'ların eksik kareyi sayabilmesi için.
///
/// [pixelRatio] 2.0 = arayüz karesi (yazı keskin okunur), 1.5 = sahne karesi
/// (dünya çekimlerinde 2.0 gereksiz büyük dosya üretiyor).
Future<bool> captureBoundary(
  GlobalKey key,
  String path, {
  double pixelRatio = 2.0,
}) async {
  final ctx = key.currentContext;
  if (ctx == null) {
    stdout.writeln('CAPTURE_FAIL: no context — $path');
    return false;
  }
  final obj = ctx.findRenderObject();
  if (obj is! RenderRepaintBoundary) {
    stdout.writeln('CAPTURE_FAIL: no boundary — $path');
    return false;
  }
  final image = await obj.toImage(pixelRatio: pixelRatio);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  if (bytes == null) {
    stdout.writeln('CAPTURE_FAIL: no bytes — $path');
    return false;
  }
  await File(path).writeAsBytes(bytes.buffer.asUint8List());
  stdout.writeln('CAPTURED: $path');
  return true;
}
