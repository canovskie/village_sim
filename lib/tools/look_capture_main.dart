// KÖYÜN HÂLİ — GÖRÜNEN KANAL harness'ı (Faz 5).
//
// Basınç tablosunun çizime inen iki değerini (kılık = WorldPressure.provision,
// örtünme = köylünün bearingTense'i) yan yana ızgarada gösterir. Soru şu değil:
// "yakından güzel mi". Soru şu: **oynanan ölçekte köyün hâli okunuyor mu, ve
// abartıya kaçmadan mı?** Bu yüzden her sıra iki ölçekte çizilir.
//
// Aynı köylü (aynı seed) her hücrede tekrar edilir — değişen tek şey köyün
// hâli olsun ki fark kişiden değil basınçtan geldiği kesin görülsün.
//
// Çalıştır:  flutter run -d macos -t lib/tools/look_capture_main.dart
// Çıktı:     /tmp/village_look.png
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
  await ToolRenderer.loadAll();
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: RepaintBoundary(
      key: _boundaryKey,
      child: const Scaffold(
        backgroundColor: Color(0xFF6B5A3E),
        body: Center(child: _LookGrid()),
      ),
    ),
  ));
  await Future<void>.delayed(const Duration(milliseconds: 600));
  await _capture('/tmp/village_look.png');
  exit(0);
}

class _LookGrid extends StatelessWidget {
  const _LookGrid();
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size(1500, 1180), painter: _LookPainter());
}

/// Kılık ekseni — ambarın hâli. -1 kıtlık … +1 harman.
const _provisions = [-1.0, -0.55, 0.0, 0.55, 1.0];
const _provLabels = ['KITLIK', 'DARLIK', 'TABAN', 'BEREKET', 'HARMAN'];

/// Örtünme — köylünün tedirginliği. 0.30 altı görünmez, 0.62 üstü kapüşon.
const _shrouds = [0.0, 0.45, 0.75, 1.0];
const _shroudLabels = ['açık', 'şal', 'şal+kapüşon', 'tam örtünme'];

/// Meslek çeşidi: kılık kanalı TÜM giysi yollarından geçmeli — biri
/// `tintCloth`'u doğrudan çağırıyorsa o sütun kıtlıkta değişmez ve burada
/// gözle yakalanır.
const _types = [
  VillagerType.farmer,
  VillagerType.guard,
  VillagerType.miller,
  VillagerType.priest,
];

class _LookPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0xFF7A6846));

    _text(canvas, 'KILIK — ambarın hâli   (küçük: oynanan ölçek · büyük: 2×)',
        750, 12, 15);

    // ── 1. KILIK EKSENİ — dört meslek × beş ambar hâli ────────────────────
    // Satır aralığı karakterin GERÇEK boyuna göre: 2× çizimde bir NPC ~110px
    // yer kaplıyor, daha dar aralık figürleri üst üste bindiriyordu.
    for (int c = 0; c < _provisions.length; c++) {
      final x = 170.0 + c * 275.0;
      _text(canvas, _provLabels[c], x, 40, 12);
      for (int r = 0; r < _types.length; r++) {
        final y = 190.0 + r * 145;
        final v = NpcVisual.fromSeed(11 + r * 7, forceMale: r.isEven);
        // OYNANAN ÖLÇEK — asıl soru: köyün hâli BURADA okunuyor mu.
        canvas.save();
        canvas.translate(x - 78, y);
        canvas.scale(kCharScale);
        CharacterRenderer.draw(canvas, _types[r],
            visual: v,
            houseAccent: houseAccentColor('Karaoğlu'),
            provision: _provisions[c]);
        canvas.restore();
        // YAKIN — ton kaymasının renk mi karartma mı olduğu ancak burada belli.
        canvas.save();
        canvas.translate(x + 20, y);
        canvas.scale(2.0);
        CharacterRenderer.draw(canvas, _types[r],
            visual: v,
            houseAccent: houseAccentColor('Karaoğlu'),
            provision: _provisions[c]);
        canvas.restore();
      }
    }

    // ── 2. ÖRTÜNME EKSENİ — tedirginlik siluete iner ──────────────────────
    _text(canvas, 'ÖRTÜNME — tedirginlik (şal → kapüşon) · YÜZ AÇIK KALMALI',
        750, 790, 15);
    for (int c = 0; c < _shrouds.length; c++) {
      final x = 230.0 + c * 320.0;
      _text(canvas, _shroudLabels[c], x, 818, 12);
      final v = NpcVisual.fromSeed(23);
      canvas.save();
      canvas.translate(x - 85, 980);
      canvas.scale(kCharScale);
      CharacterRenderer.draw(canvas, VillagerType.farmer,
          visual: v,
          houseAccent: houseAccentColor('Yıldız'),
          shroud: _shrouds[c]);
      canvas.restore();
      canvas.save();
      canvas.translate(x + 15, 980);
      canvas.scale(2.6);
      CharacterRenderer.draw(canvas, VillagerType.farmer,
          visual: v,
          houseAccent: houseAccentColor('Yıldız'),
          shroud: _shrouds[c]);
      canvas.restore();
    }

    // ── 3. İKİSİ BİRDEN — köyün en kötü ve en iyi günü ────────────────────
    final v = NpcVisual.fromSeed(23);
    _text(canvas, 'KITLIK + TEDİRGİNLİK', 1290, 818, 12);
    canvas.save();
    canvas.translate(1290, 980);
    canvas.scale(2.6);
    CharacterRenderer.draw(canvas, VillagerType.farmer,
        visual: v,
        houseAccent: houseAccentColor('Yıldız'),
        provision: -1.0,
        shroud: 0.95);
    canvas.restore();

    _text(canvas, 'HARMAN + HUZUR', 1420, 818, 12);
    canvas.save();
    canvas.translate(1420, 980);
    canvas.scale(2.6);
    CharacterRenderer.draw(canvas, VillagerType.farmer,
        visual: v,
        houseAccent: houseAccentColor('Yıldız'),
        provision: 1.0);
    canvas.restore();
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
              letterSpacing: 1.1)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, y));
  }

  @override
  bool shouldRepaint(_LookPainter old) => false;
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
