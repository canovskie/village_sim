import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'asset_style.dart';
import 'flame_renderer.dart';

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

  // ── SAZ / BAĞLAMA (procedurel — asset yok) ─────────────────────────────────
  // Ortam: NPC eli hizasında save/translate ile çağrılır; gövde alt-orta
  // (0,0) origin. Anadolu temalı uzun saplı saz görseli.
  static final Paint _pSazBody  = Paint()
    ..color = const Color(0xFF8A5A28)..isAntiAlias = false;
  static final Paint _pSazDark  = Paint()
    ..color = const Color(0xFF3A1A08)..isAntiAlias = false;
  static final Paint _pSazNeck  = Paint()
    ..color = const Color(0xFF6A4220)..isAntiAlias = false;
  static final Paint _pSazStr   = Paint()
    ..color = const Color(0xFFE8C880)..isAntiAlias = false;
  static final Paint _pSazHole  = Paint()
    ..color = const Color(0xFF1A0C04)..isAntiAlias = false;
  static final Paint _pSazOutline = Paint()
    ..color = const Color(0xFF1A0C04)..style = PaintingStyle.stroke
    ..strokeWidth = 1..isAntiAlias = false;

  /// Saz/bağlama çizer. Origin: gövde alt-orta. Çağıran save/translate yapar.
  static void drawSaz(Canvas canvas) {
    // Gövde — armudu, damla şekilli (oval)
    canvas.drawOval(const Rect.fromLTWH(-4, -6, 8, 8), _pSazBody);
    canvas.drawOval(const Rect.fromLTWH(-4, -6, 8, 8), _pSazOutline);
    // Gövde gölge (alt yarı)
    canvas.drawRect(const Rect.fromLTWH(-3, -1, 6, 3), _pSazDark);
    // Sap — uzun ince çubuk (yukarı uzanır)
    canvas.drawRect(const Rect.fromLTWH(-1, -16, 2, 11), _pSazNeck);
    canvas.drawRect(const Rect.fromLTWH(-1, -16, 2, 11), _pSazOutline);
    // Sap kafa (tuner block)
    canvas.drawRect(const Rect.fromLTWH(-2, -18, 4, 3), _pSazNeck);
    canvas.drawRect(const Rect.fromLTWH(-2, -18, 4, 3), _pSazOutline);
    // Teller (3 ince çizgi)
    canvas.drawLine(const Offset(-0.5, -16), const Offset(-0.5, -2), _pSazStr);
    canvas.drawLine(const Offset(0.5, -16),  const Offset(0.5, -2),  _pSazStr);
    // Ses deliği
    canvas.drawRect(const Rect.fromLTWH(-1, -3, 2, 2), _pSazHole);
  }

  /// Draw ambient torch glow in WORLD space at (cx, cy).
  /// Call this BEFORE drawing the character (lower depth layer).
  ///
  /// Yumuşak halo (3 katman concentric) + üstünde küçük animasyonlu alev
  /// (FlameRenderer). Lighting pass büyük halo'yu zaten veriyor; bu sadece
  /// yerel parlama ile torch'un ucunda gerçek alev hissi.
  static void drawTorchGlow(Canvas canvas, double cx, double cy,
      double time, int seed) {
    final flicker = sin(time * 3.7 + seed * 0.731);

    _pTorchGlow1.color = Color.fromARGB(
        ((12 + flicker * 5).round()).clamp(0, 28), 255, 160, 40);
    _pTorchGlow2.color = Color.fromARGB(
        ((22 + flicker * 8).round()).clamp(0, 50), 255, 140, 20);
    _pTorchGlow3.color = Color.fromARGB(
        ((36 + flicker * 12).round()).clamp(0, 72), 255, 120, 0);

    canvas.drawCircle(Offset(cx, cy - 10), 36, _pTorchGlow1);
    canvas.drawCircle(Offset(cx, cy - 10), 22, _pTorchGlow2);
    canvas.drawCircle(Offset(cx, cy - 10), 11, _pTorchGlow3);

    // Karakterin elindeki torch ucunda animasyonlu alev — küçük scale.
    FlameRenderer.draw(canvas, cx + 4, cy - 6, 0.9, time, seed,
        intensity: 0.95, sparks: true);
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
