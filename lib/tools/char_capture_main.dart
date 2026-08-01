// Karakter render karşılaştırma harness'ı — NPC'leri İKİ ölçekte yan yana
// çizer:  üst sıra gerçek oyun ölçeği (kCharScale, zoom 1), alt sıra yakın
// zoom.  Asıl soru "yakında güzel mi" değil, "OYNANAN ölçekte okunuyor mu";
// harness bu yüzden ikisini birden gösteriyor.
//
// Çalıştır:  flutter run -d macos -t lib/tools/char_capture_main.dart
// Çıktı:     /tmp/chars.png
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../characters/npc_visual.dart';
import '../characters/villager_type.dart';
import '../core/constants.dart';
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
        backgroundColor: Color(0xFF6B5A3E),
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
    return CustomPaint(size: const Size(1560, 780), painter: _CharPainter());
  }
}

const _types = [
  VillagerType.farmer,
  VillagerType.merchant,
  VillagerType.blacksmith,
  VillagerType.guard,
  VillagerType.priest,
  VillagerType.shepherd,
  VillagerType.hunter,
  VillagerType.miller,
];
const _labels = [
  'ÇİFTÇİ', 'TÜCCAR', 'DEMİRCİ', 'MUHAFIZ',
  'RAHİP', 'ÇOBAN', 'AVCI', 'DEĞİRMENCİ',
];
// Farklı haneler — kuşak renginin gerçekten ayrıştığını görmek için.
const _houses = [
  'Karaoğlu', 'Demirci', 'Yıldız', 'Akbaş',
  'Çelebi', 'Toprak', 'Ergin', 'Sarıkaya',
];

class _CharPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Zemin şeridi — NPC'ler boşlukta değil, oyun zemininin değerine yakın bir
    // fonda değerlendirilmeli (kontrast testi).
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, 190),
        Paint()..color = const Color(0xFF7A6846));

    _row(canvas, y: 150, scale: kCharScale, label: 'OYNANAN ÖLÇEK (kCharScale)',
        labelY: 30);
    _row(canvas, y: 740, scale: 3.0, label: 'YAKIN ZOOM (3×)', labelY: 380);
  }

  void _row(Canvas canvas,
      {required double y,
      required double scale,
      required String label,
      required double labelY}) {
    for (int i = 0; i < _types.length; i++) {
      final cx = 100.0 + i * 185.0;
      final v = NpcVisual.fromSeed(7 + i * 5, forceMale: i.isEven);
      canvas.save();
      canvas.translate(cx, y);
      canvas.scale(scale);
      CharacterRenderer.draw(canvas, _types[i],
          visual: v, houseAccent: houseAccentColor(_houses[i]));
      canvas.restore();
      _text(canvas, _labels[i], cx, y + 8, 11);
      _text(canvas, _houses[i], cx, y + 22, 9, const Color(0xB0FFFFFF));
    }
    _text(canvas, label, 780, labelY, 13);
  }

  void _text(Canvas canvas, String s, double cx, double y, double size,
      [Color color = Colors.white]) {
    final tp = TextPainter(
      text: TextSpan(
          text: s,
          style: TextStyle(
              color: color,
              fontSize: size,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, y));
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
