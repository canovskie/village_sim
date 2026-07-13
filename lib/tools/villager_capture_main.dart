// Köylü paneli önizleme harness'ı — sekmeli (GENEL/KİŞİLİK/ÖYKÜ) yeni yapıyı
// aile + yaşam öyküsü dolu bir köylüyle render edip PNG'ye çeker.
//
// Çalıştır:  flutter run -d macos -t lib/tools/villager_capture_main.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../characters/villager_type.dart';
import '../entities/villager_entity.dart';
import '../systems/chronicle.dart';
import '../ui/villager_info_panel.dart';

final GlobalKey _key = GlobalKey();

VillagerEntity _mk(String name, String surname, VillagerType t, double age,
    {int seed = 7}) {
  return VillagerEntity(
    type: t,
    name: name,
    surname: surname,
    male: seed.isEven,
    startCol: 0,
    startRow: 0,
    ageDays: age,
    personalitySeed: seed,
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError =
      (d) => stdout.writeln('FLUTTER_ERROR: ${d.exceptionAsString()}');

  final v = _mk('Ayşe', 'Demirhan', VillagerType.merchant, 6.5, seed: 11);
  v.morale = 0.72;
  v.mood = 0.3;
  v.isFavorite = true;
  v.wed = true;

  // Aile — eş (ortak çocuk üzerinden), ebeveyn, kardeş, çocuk.
  final esi = _mk('Kemal', 'Demirhan', VillagerType.blacksmith, 7.0, seed: 4);
  final anne = _mk('Nur', 'Demirhan', VillagerType.farmer, 14.0, seed: 6);
  final kardes = _mk('Elif', 'Demirhan', VillagerType.priest, 5.0, seed: 9);
  final cocuk = _mk('Deniz', 'Demirhan', VillagerType.farmer, 0.6, seed: 3);

  v.parents.add(anne);
  anne.children.addAll([v, kardes]);
  kardes.parents.add(anne);
  v.children.add(cocuk);
  cocuk.parents.addAll([v, esi]);
  esi.children.add(cocuk);

  v.life.addAll(const [
    ChronicleEntry(day: 1, icon: '👶', text: 'Demirhan Hanesi\'nde doğdu.'),
    ChronicleEntry(day: 3, icon: '✨', text: 'Çağrısını buldu — tüccar oldu.', milestone: true),
    ChronicleEntry(day: 5, icon: '💍', text: 'Kemal ile evlendi.', milestone: true),
    ChronicleEntry(day: 6, icon: '👶', text: 'Deniz doğdu.'),
    ChronicleEntry(day: 6, icon: '🎉', text: 'Köy şenliğinde ozanı ağırladı.'),
  ]);

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: RepaintBoundary(
      key: _key,
      child: Scaffold(
        backgroundColor: const Color(0xFF1A2A20),
        body: Stack(
          fit: StackFit.expand,
          children: [
            // SOL: scroll view YOK (bounded)     SAĞ: scroll view VAR (oyundaki gibi)
            Positioned(
              top: 30,
              left: 20,
              child: VillagerInfoPanel(
                villager: v,
                homeLabel: 'Konak',
                isFollowed: false,
                onClose: () {},
                onSelect: (_) {},
                onToggleFollow: () {},
                onToggleFavorite: () {},
                onRename: (_) {},
              ),
            ),
            Positioned(
              top: 30,
              right: 20,
              bottom: 30,
              child: SingleChildScrollView(
                child: VillagerInfoPanel(
                  villager: v,
                  homeLabel: 'Konak',
                  isFollowed: false,
                  onClose: () {},
                  onSelect: (_) {},
                  onToggleFollow: () {},
                  onToggleFavorite: () {},
                  onRename: (_) {},
                  initialTab: int.tryParse(Platform.environment['VTAB'] ?? '0') ?? 0,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ));

  await Future<void>.delayed(const Duration(milliseconds: 1700));
  await _capture('/tmp/villager.png');
  exit(0);
}

Future<void> _capture(String path) async {
  final ctx = _key.currentContext;
  if (ctx == null) {
    stdout.writeln('CAPTURE_FAIL');
    return;
  }
  final b = ctx.findRenderObject() as RenderRepaintBoundary;
  final img = await b.toImage(pixelRatio: 2.0);
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  if (bytes == null) return;
  await File(path).writeAsBytes(bytes.buffer.asUint8List());
  stdout.writeln('CAPTURED: $path');
}
