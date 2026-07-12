// Karakter render karşılaştırma harness'ı — meslek NPC'lerini büyütülmüş,
// yan yana çizer (İnşaatçı'yı diğerleriyle kıyaslamak için). PNG'ye çeker.
//
// Çalıştır:  flutter run -d macos -t lib/tools/char_capture_main.dart
// Çıktı:     /tmp/chars.png
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../characters/npc_visual.dart';
import '../characters/villager_type.dart';
import '../rendering/character_renderer.dart';
import '../rendering/tool_renderer.dart';

final GlobalKey _boundaryKey = GlobalKey();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ToolRenderer.loadAll(); // çekiç/kazma PNG'leri — yoksa araçlar çizilmez
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: RepaintBoundary(
      key: _boundaryKey,
      child: const Scaffold(
        backgroundColor: Color(0xFF3A5A70),
        body: Center(child: _CharRow()),
      ),
    ),
  ));
  await Future<void>.delayed(const Duration(milliseconds: 600));
  await _capture('/tmp/chars.png');
  exit(0);
}

class _CharRow extends StatelessWidget {
  const _CharRow();
  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(1600, 400), painter: _CharPainter());
  }
}

class _CharPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Yeni meslekler + kıyas için birkaç mevcut meslek (gerçek oyun yolu:
    // draw dispatch → shaded varyant).
    const types = [
      VillagerType.priest,
      VillagerType.shepherd,
      VillagerType.hunter,
      VillagerType.miller,
      VillagerType.innkeeper,
    ];
    const labels = [
      'RAHİP', 'ÇOBAN', 'AVCI', 'DEĞİRMENCİ', 'HANCI'
    ];
    const scale = 3.4;
    for (int i = 0; i < types.length; i++) {
      final cx = 150.0 + i * 300.0;
      final v = NpcVisual.fromSeed(7 + i * 5, forceMale: true);
      canvas.save();
      canvas.translate(cx, 330);
      canvas.scale(scale);
      CharacterRenderer.draw(canvas, types[i], visual: v);
      canvas.restore();
      final tp = TextPainter(
        text: TextSpan(
            text: labels[i],
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.4)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, 345));
    }
  }

  @override
  bool shouldRepaint(_CharPainter old) => false;
}

Future<void> _capture(String path) async {
  final ctx = _boundaryKey.currentContext;
  if (ctx == null) {
    stdout.writeln('CAPTURE_FAIL: no context');
    return;
  }
  final boundary = ctx.findRenderObject() as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 2.0);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  if (bytes == null) {
    stdout.writeln('CAPTURE_FAIL: no bytes');
    return;
  }
  await File(path).writeAsBytes(bytes.buffer.asUint8List());
  stdout.writeln('CAPTURED: $path');
}
