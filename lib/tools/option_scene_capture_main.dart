// Karar-eylem sahnelerinin (OptionScene) grid önizlemesi — 8 sahnenin hepsini
// gerçek painter'la render edip PNG'ye çeker (motif/atmosfer iterasyonu).
//
// Çalıştır:  flutter run -d macos -t lib/tools/option_scene_capture_main.dart
// Çıktı:     /tmp/option_scenes.png
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../ui/option_scene_card.dart';

final GlobalKey _key = GlobalKey();

const _labels = {
  OptionScene.pardon: 'Bağışla',
  OptionScene.punish: 'Meydanda cezalandır',
  OptionScene.exile: 'Köyden sür',
  OptionScene.execute: 'İdam et',
  OptionScene.labor: 'Kürek cezası',
  OptionScene.accept: 'Kabul / ver',
  OptionScene.refuse: 'Reddet / geçiştir',
  OptionScene.generic: 'Genel',
};

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: RepaintBoundary(
      key: _key,
      child: Scaffold(
        backgroundColor: const Color(0xFF14171C),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: GridView.count(
            crossAxisCount: 4,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 1.35,
            children: [
              for (final s in OptionScene.values)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: OptionSceneCard(scene: s, height: 200),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(_labels[s]!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12)),
                  ],
                ),
            ],
          ),
        ),
      ),
    ),
  ));
  await Future<void>.delayed(const Duration(milliseconds: 1400));
  final b = _key.currentContext!.findRenderObject() as RenderRepaintBoundary;
  final img = await b.toImage(pixelRatio: 1.6);
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  await File('/tmp/option_scenes.png').writeAsBytes(bytes!.buffer.asUint8List());
  stdout.writeln('saved /tmp/option_scenes.png');
  exit(0);
}
