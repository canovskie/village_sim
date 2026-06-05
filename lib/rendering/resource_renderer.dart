import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../world/resource_box.dart';
import '../world/hay_entity.dart';
import '../world/resource_placement.dart';
import 'asset_style.dart';

class ResourceRenderer {
  static final Map<String, ui.Image> _imgs = {};

  // Sprite paint AssetStyle'dan — merkezi yumuşatma
  static final Paint _pImg = AssetStyle.paint();
  // Yere düşen kaynak altında küçük eliptik gölge.
  static final Paint _pShadow = Paint()
    ..color = const Color(0x55000000)
    ..isAntiAlias = true;

  static Future<void> loadAll() async {
    await _load('woodchunk',   'assets/tools/woodchunk.png');
    await _load('stonebox',    'assets/tools/stonebox.png');
    await _load('ironbox',     'assets/tools/ironbox.png');
    await _load('coalbox',     'assets/tools/coalbox.png');
    await _load('hay',         'assets/tools/hay.png');
    await _load('baleofstraw', 'assets/tools/baleofstraw.png');
    await _load('torch',       'assets/tools/torch.png');
    await _load('waterbucket', 'assets/tools/waterbucket.png');
  }

  static Future<void> _load(String key, String path) async {
    try {
      final bytes = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      _imgs[key] = await AssetStyle.softenAtLoad(frame.image);
    } catch (e) {
      debugPrint('ResourceRenderer: $path could not be loaded — $e');
    }
  }

  /// Drop animasyonu için parabolic offset (0 = taban, yukarıdan iner +
  /// hafif bounce). `t` 0..1 arası progress.
  static double _dropOffset(double t) {
    if (t <= 0) return 30.0;       // başlangıç: 30 px yukarıda
    if (t >= 1) return 0.0;
    // Inverted-cubic + bounce — düşerken hızlanır, sonunda 1-2 küçük zıplama
    if (t < 0.85) {
      // Cubic fall — 30 → 0
      final f = t / 0.85;
      return 30.0 * (1 - f * f);
    }
    // Bounce phase 0.85..1.0 — küçük zıplama
    final b = (t - 0.85) / 0.15;
    return -3.0 * sin(b * pi) * (1 - b);
  }

  /// Drop sırasındaki alpha rampu — çok kısa fade-in (0..0.15 phase).
  static int _dropAlpha(double t) {
    if (t <= 0) return 0;
    if (t > 0.15) return 255;
    return ((t / 0.15) * 255).round().clamp(0, 255);
  }

  static void _drawSprite(Canvas canvas, ui.Image img,
      double cx, double cy, double targetW, {int alpha = 255}) {
    final scale = targetW / img.width;
    final w = img.width  * scale;
    final h = img.height * scale;
    if (alpha < 255) {
      _pImg.color = Color.fromARGB(alpha, 255, 255, 255);
    } else {
      _pImg.color = const Color(0xFFFFFFFF);
    }
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Rect.fromLTWH(cx - w / 2, cy - h, w, h),
      _pImg,
    );
  }

  /// Tabandaki gölge — sprite ne kadar yukarıdaysa o kadar küçük (ışık altında).
  static void _drawShadow(Canvas canvas, double cx, double cy,
      double width, double dropOff) {
    // Yere yakınken büyük + koyu, yüksekken küçük + soluk.
    final t = (dropOff / 30.0).clamp(0.0, 1.0);
    final w = width * (1.0 - t * 0.5);
    final h = w * 0.32;
    final a = ((1.0 - t * 0.7) * 85).round().clamp(0, 100);
    _pShadow.color = Color.fromARGB(a, 0, 0, 0);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy + 1), width: w, height: h),
        _pShadow);
  }

  /// Yerde duran kaynak kutusu. [time] gerekli — drop animasyonu spawnTime
  /// üzerinden hesaplanır.
  static void drawBox(Canvas canvas, ResourceBox box,
      double screenX, double screenY, double time) {
    final img = _imgs[box.spriteName];
    if (img == null) return;
    final phase = ((time - box.spawnTime) / kDropDuration).clamp(0.0, 1.0);
    final drop  = _dropOffset(phase);
    final alpha = _dropAlpha(phase);
    // Gölge yere oturmuş gibi — drop sırasında küçük + soluk.
    _drawShadow(canvas, screenX, screenY, 28, drop);
    // Sprite yukarıdan iner.
    _drawSprite(canvas, img, screenX, screenY - drop, 32.0, alpha: alpha);
  }

  /// Yerde duran hay pile — pileSize 1..N için katmanlı yığın. 1 saman = tek
  /// tutam, 3+ saman = küçük yığın, 5+ = balya'ya yakın.
  static void drawHay(Canvas canvas, HayEntity hay,
      double screenX, double screenY, double time) {
    final img = _imgs['hay'];
    if (img == null) return;
    final phase = ((time - hay.spawnTime) / kDropDuration).clamp(0.0, 1.0);
    final drop  = _dropOffset(phase);
    final alpha = _dropAlpha(phase);
    // Pile boyutu: tek tutam küçük, çok tutam üst üste katman.
    final layers = hay.pileSize.clamp(1, 5);
    _drawShadow(canvas, screenX, screenY, 18.0 + layers * 1.5, drop);
    // Katmanlı çizim — taban büyük, üst katmanlar küçük + biraz kayık.
    for (int i = 0; i < layers; i++) {
      final layerScale = 1.0 - i * 0.12;     // her katman %12 küçük
      final layerYOff  = i * 3.0;            // her katman 3 px yukarı
      final layerXOff  = sin(i * 1.3) * 1.5; // hafif kayma → düzensiz yığın
      _drawSprite(canvas, img,
          screenX + layerXOff,
          screenY - drop - layerYOff,
          18.0 * layerScale, alpha: alpha);
    }
  }

  /// Balya — bina gibi front-corner'a hizalanmış. Drop animation + gölge.
  static void drawBale(Canvas canvas, double frontX, double frontY,
      double spriteW, double time, HayEntity hay) {
    final img = _imgs['baleofstraw'];
    if (img == null) return;
    final spriteH = spriteW * img.height / img.width;
    const groundXCenter = 0.397;
    const groundY       = 0.739;
    final phase = ((time - hay.spawnTime) / kDropDuration).clamp(0.0, 1.0);
    final drop  = _dropOffset(phase);
    final alpha = _dropAlpha(phase);
    // Gölge: balyanın tabanında, sprite genişliğine göre büyük.
    _drawShadow(canvas, frontX - spriteW * 0.10, frontY,
        spriteW * 0.7, drop);
    final dst = Rect.fromLTWH(
      (frontX - spriteW * groundXCenter).roundToDouble(),
      (frontY - spriteH * groundY - drop).roundToDouble(),
      spriteW.roundToDouble(),
      spriteH.roundToDouble(),
    );
    if (alpha < 255) {
      _pImg.color = Color.fromARGB(alpha, 255, 255, 255);
    } else {
      _pImg.color = const Color(0xFFFFFFFF);
    }
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      dst,
      _pImg,
    );
  }

  /// Taşınan kutu — kollar arasında, gövdenin önünde göğüs hizasında.
  static void drawCarriedBox(Canvas canvas, ResourceBox box,
      double screenX, double screenY) {
    final img = _imgs[box.spriteName];
    if (img == null) return;
    _drawSprite(canvas, img, screenX, screenY - 22, 20.0);
  }

  /// Taşınan saman/balya — kollar arasında, göğüs hizasında.
  /// Balya büyük → omuza yakın (-26 px), saman küçük → göğüs hizasında.
  static void drawCarriedHay(Canvas canvas, HayEntity hay,
      double screenX, double screenY) {
    final img = _imgs[hay.isBale ? 'baleofstraw' : 'hay'];
    if (img == null) return;
    final yOff = hay.isBale ? -26.0 : -22.0;
    _drawSprite(canvas, img, screenX, screenY + yOff,
        hay.isBale ? 26.0 : 16.0);
  }
}
