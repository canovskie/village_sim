import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'asset_style.dart';

/// Tüm el aletlerini yükler ve arm-local koordinat uzayında çizer.
///
/// Arm-local uzay referansı:
///   (0,0) = omuz pivot, y+ = kolun uzandığı yön (kol y=0..20, el ≈ y=14)
///   Tüm draw*() metodları bu uzayda çizim yapar.
///   Çağıran: canvas zaten arm pivot'una translate + rotate edilmiş olmalı.
class ToolRenderer {
  static final Map<_Tool, ui.Image> _imgs = {};

  // Static Paints for torch glow — never allocate inside draw loops
  static final Paint _pTorchGlow1 = Paint()..isAntiAlias = true;
  static final Paint _pTorchGlow2 = Paint()..isAntiAlias = true;
  static final Paint _pTorchGlow3 = Paint()..isAntiAlias = true;

  static Future<void> loadAll() async {
    await _load(_Tool.axe,         'assets/tools/axe.png');
    await _load(_Tool.hammer,      'assets/tools/hammer.png');
    await _load(_Tool.hoe,         'assets/tools/hoe.png');
    await _load(_Tool.pickaxe,     'assets/tools/pickaxe.png');
    await _load(_Tool.rod,         'assets/tools/rod.png');
    await _load(_Tool.torch,       'assets/tools/torch.png');
    await _load(_Tool.waterbucket, 'assets/tools/waterbucket.png');
  }

  static Future<void> _load(_Tool t, String path) async {
    try {
      final bytes = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      _imgs[t]   = await AssetStyle.softenAtLoad(frame.image);
    } catch (e) {
      debugPrint('ToolRenderer: $path yüklenemedi — $e');
    }
  }

  // ── BALTA (oduncu) ────────────────────────────────────────────────────────
  // PNG: 638 × 795 — sap dikey, baş üstte.
  // Tutuş: PNG %68'inde. Balta başını hedefe 0.50 rad öne eğ.
  static void drawAxe(Canvas canvas) {
    final img = _imgs[_Tool.axe];
    if (img == null) return;
    const w = 26.0;
    final h = w * img.height / img.width;
    canvas.save();
    canvas.translate(3, 14);
    canvas.rotate(0.50);
    canvas.drawImageRect(img, _src(img),
        Rect.fromLTWH(-w * 0.50, -h * 0.68, w, h), _paint());
    canvas.restore();
  }

  // ── ÇEKIÇ (inşaatçı) ─────────────────────────────────────────────────────
  // PNG: 662 × 973 — baş üstte, sap dikey.
  // Tutuş: PNG %70'inde. Hafif öne eğim.
  static void drawHammer(Canvas canvas, {double scale = 1.0}) {
    final img = _imgs[_Tool.hammer];
    if (img == null) return;
    final w = 20.0 * scale;
    final h = w * img.height / img.width;
    canvas.save();
    canvas.translate(3, 13);
    canvas.rotate(0.30);
    canvas.drawImageRect(img, _src(img),
        Rect.fromLTWH(-w * 0.50, -h * 0.70, w, h), _paint());
    canvas.restore();
  }

  // ── ÇAPA (çiftçi) ─────────────────────────────────────────────────────────
  // PNG: 629 × 840 — baş üstte, sap dikey.
  // Tutuş: PNG %72'sinde. Çok az eğim.
  static void drawHoe(Canvas canvas) {
    final img = _imgs[_Tool.hoe];
    if (img == null) return;
    const w = 20.0;
    final h = w * img.height / img.width;
    canvas.save();
    canvas.translate(3, 14);
    canvas.rotate(0.18);
    canvas.drawImageRect(img, _src(img),
        Rect.fromLTWH(-w * 0.50, -h * 0.72, w, h), _paint());
    canvas.restore();
  }

  // ── KAZMA (madenci) ───────────────────────────────────────────────────────
  // PNG: 814 × 1028 — pick baş üstte, sap köşegen.
  // Tutuş: PNG %66'sında. Daha belirgin açı.
  static void drawPickaxe(Canvas canvas) {
    final img = _imgs[_Tool.pickaxe];
    if (img == null) return;
    const w = 24.0;
    final h = w * img.height / img.width;
    canvas.save();
    canvas.translate(3, 13);
    canvas.rotate(0.40);
    canvas.drawImageRect(img, _src(img),
        Rect.fromLTWH(-w * 0.50, -h * 0.66, w, h), _paint());
    canvas.restore();
  }

  // ── OLU (balıkçı) ────────────────────────────────────────────────────────
  // PNG: 592 × 1015 — sap dikey, uç üstte.
  // Tutuş: PNG %75'inde. Hafif öne eğim.
  static void drawRod(Canvas canvas, {double castAngle = 0.0}) {
    final img = _imgs[_Tool.rod];
    if (img == null) return;
    const w = 18.0;
    final h = w * img.height / img.width;
    canvas.save();
    canvas.translate(3, 14);
    canvas.rotate(0.25 + castAngle);
    canvas.drawImageRect(img, _src(img),
        Rect.fromLTWH(-w * 0.50, -h * 0.75, w, h), _paint());
    canvas.restore();
  }

  // ── TORCH (gece yürüyüşü) ─────────────────────────────────────────────────
  // PNG: 1254×1254 — torch.png, kare.
  // Çağrı: arm-local uzayda; CharacterRenderer.draw torch:true durumunda
  // sağ omuz pivotuna translate + arm rotate uygulayıp çağırır.
  static void drawTorch(Canvas canvas) {
    final img = _imgs[_Tool.torch];
    if (img == null) return;
    const w = 14.0;
    final h = w * img.height / img.width;
    canvas.save();
    canvas.translate(3, 14);   // arm-local: elin pozisyonu (kol y=0..20)
    canvas.rotate(-0.15);      // sapı hafif geriye eğ
    canvas.drawImageRect(img, _src(img),
        Rect.fromLTWH(-w * 0.50, -h * 0.85, w, h), _paint());
    canvas.restore();
  }

  /// Draw ambient torch glow in WORLD space at (cx, cy).
  /// Call this BEFORE drawing the character (lower depth layer).
  static void drawTorchGlow(Canvas canvas, double cx, double cy,
      double time, int seed) {
    final flicker = sin(time * 3.7 + seed * 0.731);

    _pTorchGlow1.color = Color.fromARGB(
        ((18 + flicker * 8).round()).clamp(0, 40), 255, 160, 40);
    _pTorchGlow2.color = Color.fromARGB(
        ((30 + flicker * 12).round()).clamp(0, 60), 255, 140, 20);
    _pTorchGlow3.color = Color.fromARGB(
        ((55 + flicker * 20).round()).clamp(0, 100), 255, 120, 0);

    canvas.drawCircle(Offset(cx, cy - 10), 45, _pTorchGlow1);
    canvas.drawCircle(Offset(cx, cy - 10), 28, _pTorchGlow2);
    canvas.drawCircle(Offset(cx, cy - 10), 14, _pTorchGlow3);
  }

  // ── WATERBUCKET (çiftçi sulama) ───────────────────────────────────────────
  static void drawWaterbucket(Canvas canvas) {
    final img = _imgs[_Tool.waterbucket];
    if (img == null) return;
    const w = 16.0;
    final h = w * img.height / img.width;
    canvas.save();
    canvas.translate(4, 12);
    canvas.rotate(0.15);
    canvas.drawImageRect(img, _src(img),
        Rect.fromLTWH(-w * 0.50, -h * 0.60, w, h), _paint());
    canvas.restore();
  }

  static Rect   _src(ui.Image img) =>
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
  // Tool sprite paint — AssetStyle ortak konfigürasyondan.
  // Statik tek instance — her draw çağrısında yeni Paint allocate edilmez.
  static final Paint _pTool = AssetStyle.paint();
  static Paint  _paint() => _pTool;
}

enum _Tool { axe, hammer, hoe, pickaxe, rod, torch, waterbucket }
