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

  // ÇAPA (çiftçi) çizimi hiç çağrılmıyordu → kaldırıldı. Çiftçi tarlada
  // `stoop` duruşuyla anlatılıyor, elinde alet yok. Geri istenirse assets/
  // tools/hoe.png duruyor.

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
  /// [alpha] 0..1 — Entity.torchLevel ile fade in/out (sabah söndürüp sokağa
  /// çıkma hissi, ani snap yok). Asset paint'inden ayrı bir alpha-tinted
  /// paint kullanılır ki shared static paint'in alpha'sı bozulmasın.
  static void drawTorch(Canvas canvas, {double alpha = 1.0}) {
    final img = _imgs[_Tool.torch];
    if (img == null) return;
    const w = 14.0;
    final h = w * img.height / img.width;
    canvas.save();
    canvas.translate(3, 14);   // arm-local: elin pozisyonu (kol y=0..20)
    canvas.rotate(-0.15);      // sapı hafif geriye eğ
    final paint = (alpha >= 0.99)
        ? _pTool
        : (_pTorchSprite..color = Color.fromRGBO(255, 255, 255,
            alpha.clamp(0.0, 1.0)));
    canvas.drawImageRect(img, _src(img),
        Rect.fromLTWH(-w * 0.50, -h * 0.85, w, h), paint);
    canvas.restore();
  }
  // Alpha-modülasyonlu torch paint — shared _pTool'un alpha'sını kirletmez.
  static final Paint _pTorchSprite = AssetStyle.paint();

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

  /// Meşalenin gerçek ucunda lokal glow + animasyonlu alev. Karakter
  /// sprite'ından ÖNCE çağrılır (alt katman). [cx,cy] meşale ucu pozisyonu
  /// (karakter merkezi değil — game_painter sağ omuz + baş üstü hesaplar).
  ///
  /// [intensity] 0..1 — Entity.torchLevel ile birebir, fade in/out yapar.
  /// [phase] per-NPC sabit flicker fazı: tüm meşaleler aynı anda titremesin.
  ///
  /// Lighting pass büyük halo'yu zaten veriyor; bu yalnız alev/ısı odağı için
  /// 3 katmanlı concentric glow + alev sprite.
  static void drawTorchGlow(Canvas canvas, double cx, double cy,
      double time, double phase, {double intensity = 1.0}) {
    if (intensity <= 0.02) return;
    final flicker = sin(time * 3.7 + phase);
    final f = intensity.clamp(0.0, 1.0);

    _pTorchGlow1.color = Color.fromARGB(
        ((12 + flicker * 5) * f).round().clamp(0, 28), 255, 160, 40);
    _pTorchGlow2.color = Color.fromARGB(
        ((22 + flicker * 8) * f).round().clamp(0, 50), 255, 140, 20);
    _pTorchGlow3.color = Color.fromARGB(
        ((36 + flicker * 12) * f).round().clamp(0, 72), 255, 120, 0);

    canvas.drawCircle(Offset(cx, cy), 32 * f.clamp(0.4, 1.0), _pTorchGlow1);
    canvas.drawCircle(Offset(cx, cy), 20 * f.clamp(0.4, 1.0), _pTorchGlow2);
    canvas.drawCircle(Offset(cx, cy), 10 * f.clamp(0.4, 1.0), _pTorchGlow3);

    // Alev — meşale ucunda, hafif yukarıda. FlameRenderer intensity de scaled.
    FlameRenderer.draw(canvas, cx, cy - 3, 0.85 * f.clamp(0.6, 1.0),
        time, (phase * 1000).toInt(), intensity: 0.95 * f, sparks: f > 0.7);
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

enum _Tool { axe, hammer, pickaxe, rod, torch, waterbucket }
