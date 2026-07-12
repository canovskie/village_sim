// Dilekçe/Meclis modalı doğrulama harness'ı — PetitionModal gerçekten çiziliyor
// mu? (Divan'da AppReveal'in opacity 0'da takıldığı görüldü; petition_modal aynı
// ağacı kullanıyor → aynı bug var mı diye kontrol.)
//
// Çalıştır:  flutter run -d macos -t lib/tools/petition_capture_main.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../systems/petition_system.dart';
import '../ui/petition_modal.dart';

final GlobalKey _key = GlobalKey();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (d) => stdout.writeln('FLUTTER_ERROR: ${d.exceptionAsString()}');

  // Gerçek sistemden bir dilekçe al (ilk tanımlı olan).
  final p = PetitionSystem.all.first;
  stdout.writeln('PETITION: ${p.id} · ${p.title} · opts=${p.options.length}');

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: RepaintBoundary(
      key: _key,
      child: Scaffold(
        backgroundColor: const Color(0xFF1A2A20),
        body: Stack(
          fit: StackFit.expand,
          children: [
            PetitionModal(
              petition: p,
              state: (morale: 0.63, population: 24, food: 41, gold: 18),
              onChoose: (_) {},
              onDismiss: () {},
            ),
          ],
        ),
      ),
    ),
  ));

  await Future<void>.delayed(const Duration(milliseconds: 1600));
  await _capture('/tmp/petition.png');
  exit(0);
}

Future<void> _capture(String path) async {
  final ctx = _key.currentContext;
  if (ctx == null) {
    stdout.writeln('CAPTURE_FAIL');
    return;
  }
  final b = ctx.findRenderObject() as RenderRepaintBoundary;
  final img = await b.toImage(pixelRatio: 1.6);
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  if (bytes == null) return;
  await File(path).writeAsBytes(bytes.buffer.asUint8List());
  stdout.writeln('CAPTURED: $path');
}
