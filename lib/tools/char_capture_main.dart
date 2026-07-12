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
    return CustomPaint(size: const Size(1000, 380), painter: _CharPainter());
  }
}

class _CharPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Deterministik ama farklı görünümler
    final visuals = [
      NpcVisual.fromSeed(7, forceMale: true),
      NpcVisual.fromSeed(12, forceMale: true),
      NpcVisual.fromSeed(3, forceMale: true),
      NpcVisual.fromSeed(21, forceMale: true),
    ];
    final labels = ['İNŞAATÇI', 'İNŞAATÇI(iş)', 'DEMİRCİ', 'MADENCİ'];
    // Diğerleri gerçek oyun yolunu (draw dispatch → _xNpc shaded varyant) kullanır.
    final draws = <void Function(Canvas, NpcVisual)>[
      (c, v) => CharacterRenderer.drawBuilder(c, visual: v, working: false),
      (c, v) => CharacterRenderer.drawBuilder(c,
          visual: v, working: true, walkPhase: 1.2),
      (c, v) => CharacterRenderer.draw(c, VillagerType.blacksmith, visual: v),
      (c, v) => CharacterRenderer.draw(c, VillagerType.miner, visual: v),
    ];
    const scale = 2.2;
    for (int i = 0; i < draws.length; i++) {
      final cx = 130.0 + i * 250.0;
      canvas.save();
      canvas.translate(cx, 300);
      canvas.scale(scale);
      draws[i](canvas, visuals[i]);
      canvas.restore();
      final tp = TextPainter(
        text: TextSpan(
            text: labels[i],
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 2)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, 330));
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
