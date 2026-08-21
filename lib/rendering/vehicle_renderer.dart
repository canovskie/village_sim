import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'asset_style.dart';

/// Dış dünya taşıtlarının sprite çizimi. At + koşum + araba tek sprite'tır;
/// küçük ölçekte parçaları ayrı kemiklere bölmek yerine bütün gövdeye ağırlık,
/// tekerlere dönme izi ve yola toz verilir.
class VehicleRenderer {
  VehicleRenderer._();

  static ui.Image? _horseCart;
  static final Paint _spritePaint = AssetStyle.paint();
  static final Paint _shadowPaint = Paint()
    ..color = const Color(0x520E0905)
    ..isAntiAlias = true;
  static final Paint _dustPaint = Paint()..isAntiAlias = true;
  static final Paint _spokePaint = Paint()
    ..color = const Color(0x77513A22)
    ..strokeWidth = 1.15
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;

  static Future<void> loadAll() async {
    try {
      final bytes = await rootBundle.load('assets/vehicles/horse_cart_e.png');
      final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      _horseCart = await AssetStyle.softenAtLoad(frame.image);
    } catch (e) {
      debugPrint('VehicleRenderer: at arabası yüklenemedi — $e');
    }
  }

  /// [ground] atın ayakları ve tekerlerin yol çizgisi. Sprite doğuya bakar;
  /// batı yönü aynı asset'in güvenli yatay çevrimidir.
  static void drawHorseCart(
    Canvas canvas,
    Offset ground, {
    required bool facingRight,
    required double walkPhase,
    required bool isMoving,
    required double time,
    double scale = 1.0,
  }) {
    final image = _horseCart;
    if (image == null) return;

    final stride = isMoving ? sin(walkPhase * 2.0) : sin(time * 1.35) * 0.22;
    final bob = isMoving ? stride.abs() * 1.25 : stride;
    final roll = isMoving ? walkPhase * 0.72 : 0.0;
    final drawH = 74.0 * scale;
    final drawW = drawH * image.width / image.height;
    final baseline = ground.dy + 5.0 * scale;

    // Büyük taşıtın zemine oturduğunu NPC gölgesinden daha uzun tek parça gölge
    // anlatır. Dururken nefesle büyüyüp küçülmez; yalnız hareket bob'u değişir.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(ground.dx, baseline - 3.0 * scale),
        width: drawW * 0.82,
        height: 11.0 * scale,
      ),
      _shadowPaint,
    );

    if (isMoving) {
      final rear = facingRight ? -1.0 : 1.0;
      for (int i = 0; i < 3; i++) {
        final p = (time * (0.65 + i * 0.13) + i * 0.31) % 1.0;
        _dustPaint.color = const Color(
          0xFFB99A68,
        ).withValues(alpha: (1.0 - p) * 0.18);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(
              ground.dx + rear * (drawW * 0.27 + p * 15.0),
              baseline - 2.0 - p * 5.0,
            ),
            width: 6.0 + p * 8.0,
            height: 2.5 + p * 3.0,
          ),
          _dustPaint,
        );
      }
    }

    canvas.save();
    canvas.translate(ground.dx, baseline - bob);
    if (!facingRight) canvas.scale(-1, 1);
    final dst = Rect.fromLTWH(-drawW / 2, -drawH, drawW, drawH);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      dst,
      _spritePaint,
    );

    // Raster teker donuk görünmesin: düşük kontrastlı dört döner parmak izi
    // mevcut boyalı tekerin üstünde neredeyse erir, ama hareketi ele verir.
    if (isMoving) {
      _drawWheelSpokes(
        canvas,
        Offset(-drawW * 0.285, -drawH * 0.245),
        9.0,
        roll,
      );
      _drawWheelSpokes(
        canvas,
        Offset(-drawW * 0.105, -drawH * 0.245),
        8.0,
        roll,
      );
    }
    canvas.restore();
  }

  static void _drawWheelSpokes(
    Canvas canvas,
    Offset center,
    double radius,
    double angle,
  ) {
    for (int i = 0; i < 4; i++) {
      final a = angle + i * pi / 4;
      final d = Offset(cos(a) * radius, sin(a) * radius);
      canvas.drawLine(center - d, center + d, _spokePaint);
    }
  }
}
