import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../world/resource_box.dart';
import '../world/hay_entity.dart';
import 'asset_style.dart';

class ResourceRenderer {
  static final Map<String, ui.Image> _imgs = {};

  // Sprite paint AssetStyle'dan — merkezi yumuşatma
  static final Paint _pImg = AssetStyle.paint();

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

  static void _drawSprite(Canvas canvas, ui.Image img,
      double cx, double cy, double targetW) {
    final scale = targetW / img.width;
    final w = img.width  * scale;
    final h = img.height * scale;
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Rect.fromLTWH(cx - w / 2, cy - h, w, h), // tabana hizala
      _pImg,
    );
  }

  /// Yerde duran kaynak kutusu — tile merkezine hizalanır (~32 px genişlik)
  static void drawBox(Canvas canvas, ResourceBox box, double screenX, double screenY) {
    final img = _imgs[box.spriteName];
    if (img == null) return;
    _drawSprite(canvas, img, screenX, screenY, 32.0);
  }

  /// Yerde duran hay pile (küçük, float konumda)
  static void drawHay(Canvas canvas, HayEntity hay, double screenX, double screenY) {
    final img = _imgs['hay'];
    if (img == null) return;
    _drawSprite(canvas, img, screenX, screenY, 18.0);
  }

  /// Balya — bina gibi front-corner'a hizalanmış
  /// Sprite anchor: izometrik tabanın front köşesi (ölçülen değerler).
  static void drawBale(Canvas canvas, double frontX, double frontY, double spriteW) {
    final img = _imgs['baleofstraw'];
    if (img == null) return;
    final spriteH = spriteW * img.height / img.width;
    // Sprite'taki front köşe: X=%39.7, Y=%73.9 (sprite piksellerinden ölçüldü)
    const groundXCenter = 0.397;
    const groundY       = 0.739;
    final dst = Rect.fromLTWH(
      (frontX - spriteW * groundXCenter).roundToDouble(),
      (frontY - spriteH * groundY).roundToDouble(),
      spriteW.roundToDouble(),
      spriteH.roundToDouble(),
    );
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      dst,
      _pImg,
    );
  }

  /// Taşınan kutu — kollar arasında, gövdenin önünde göğüs hizasında.
  /// Carrying pozunda iki kol birleşir; kutu o noktada görünür (~22 px üzeri).
  static void drawCarriedBox(Canvas canvas, ResourceBox box,
      double screenX, double screenY) {
    final img = _imgs[box.spriteName];
    if (img == null) return;
    _drawSprite(canvas, img, screenX, screenY - 22, 20.0);
  }

  /// Taşınan saman/balya — kollar arasında, göğüs hizasında.
  static void drawCarriedHay(Canvas canvas, HayEntity hay,
      double screenX, double screenY) {
    final img = _imgs[hay.isBale ? 'baleofstraw' : 'hay'];
    if (img == null) return;
    _drawSprite(canvas, img, screenX, screenY - 22, hay.isBale ? 26.0 : 16.0);
  }
}
