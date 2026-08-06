// UYKU ÇİZİMİ ORAN HARNESS'I — ayakta gövde ↔ uyku pozu yan yana.
//
// NEDEN VAR (2026-08-06): "yatma/kalkma snap, geçiş ekleyelim" işi burada
// çürüdü. İki yol denendi, ikisi de kareye bakılınca elendi:
//   1. Ayakta gövdeyi ayak ucundan devirmek → gövde yatay hâle gelirken
//      YERDEN HAVADA kalıyor (pivot ayakta, gövde pivotun etrafında savruluyor).
//   2. Erken takas + squash/stretch → takas anında tam boy gövdeden minik bir
//      yığına düşüyor; aradaki ezilme o ölçekte gözle görülmüyor bile.
//
// Kök sebep ikisinde de aynı ve bu harness tam olarak onu gösterir:
// [CharacterRenderer.drawSleeping] ayakta çizimden ÇOK daha küçük ve bambaşka
// bir kompozisyon. Aralarında harmanlanacak ortak iskelet yok.
//
// GEÇİŞ İSTENİYORSA ÖNCE BU KARE DÜZELMELİ: uyku çizimi, yatmış hâldeyken
// ayakta gövdenin gövde/kafa/uzuv oranlarını koruyacak biçimde yeniden
// çizilmeli (yatay boy ≈ dikey boy, kafa aynı büyüklükte). O olduktan sonra
// basit bir devrilme zaten yeter.
//
// Çalıştır:  flutter run -d macos -t lib/tools/sleep_capture_main.dart
// Çıktı:     /tmp/sleep_blend.png
//
// TUZAK: pencere arka plandaysa macOS kare üretmez — koşarken pencereyi ÖNDE tut.
import 'dart:io';

import 'package:flutter/material.dart';

import '../characters/life_stage.dart';
import '../characters/npc_visual.dart';
import '../characters/villager_type.dart';
import '../core/constants.dart';
import '../rendering/character_renderer.dart';
import '../rendering/tool_renderer.dart';
import 'capture_support.dart';

final GlobalKey _boundaryKey = GlobalKey();

/// Karşılaştırılan meslekler — uyku çizimi türe göre tunik rengi değiştiriyor,
/// oran kusuru hepsinde aynı mı görülsün.
const _types = [
  VillagerType.farmer,
  VillagerType.blacksmith,
  VillagerType.guard,
];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ToolRenderer.loadAll(); // alet PNG'leri — yoksa eller boş çizilir

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: RepaintBoundary(
      key: _boundaryKey,
      child: const ColoredBox(
        color: Color(0xFF12161C),
        child: CustomPaint(painter: _StripPainter(), child: SizedBox.expand()),
      ),
    ),
  ));

  await settleFrames(1200);
  await captureBoundary(_boundaryKey, '/tmp/sleep_blend.png', pixelRatio: 2.0);
  exit(0);
}

class _StripPainter extends CustomPainter {
  const _StripPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Oyunda gövde ~37px; oran kusuru o ölçekte durunca fark edilmez ama
    // GEÇİŞ sırasında fark edilir. Bu yüzden yakın bakış.
    const cs = kCharScale * 2.6;
    final slot = size.width / (_types.length * 2);
    final baseY = size.height * 0.60;
    final label = TextPainter(textDirection: TextDirection.ltr);
    final rule = Paint()..color = const Color(0x33FFFFFF);

    void caption(double cx, String text, Color color) {
      label
        ..text =
            TextSpan(text: text, style: TextStyle(color: color, fontSize: 13))
        ..layout()
        ..paint(canvas, Offset(cx - label.width / 2, size.height - 46));
    }

    for (int i = 0; i < _types.length; i++) {
      final type = _types[i];
      final standX = slot * (i * 2 + 0.5);
      final sleepX = slot * (i * 2 + 1.5);

      // Ortak zemin çizgisi — iki çizim aynı yere oturuyor mu görülsün.
      canvas.drawLine(
        Offset(standX - slot * 0.45, baseY),
        Offset(sleepX + slot * 0.45, baseY),
        rule,
      );

      canvas.save();
      canvas.translate(standX, baseY);
      canvas.scale(cs, cs);
      CharacterRenderer.draw(
        canvas,
        type,
        walkPhase: 0,
        moveIntensity: 0,
        visual: NpcVisual.fromSeed(11 + i),
        stage: LifeStage.adult,
      );
      canvas.restore();

      canvas.save();
      canvas.translate(sleepX, baseY);
      canvas.scale(cs, cs);
      CharacterRenderer.drawSleeping(canvas, type);
      canvas.restore();

      caption(standX, 'ayakta', Colors.white70);
      caption(sleepX, 'uyku pozu', const Color(0xFFFFC868));
    }

    label
      ..text = const TextSpan(
        text: 'Aynı ölçek, aynı zemin. Geçiş yazılabilmesi için bu iki '
            'çizimin oranları birbirini tutmalı.',
        style: TextStyle(color: Colors.white38, fontSize: 12),
      )
      ..layout()
      ..paint(canvas, Offset(size.width / 2 - label.width / 2, 28));
  }

  @override
  bool shouldRepaint(covariant _StripPainter oldDelegate) => false;
}
