import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'asset_style.dart';

enum CartDirection { southEast, southWest, northEast, northWest }

/// Dış dünya taşıtlarının sprite çizimi. At + koşum + araba tek sprite'tır.
/// Kaynak görsel yandan bir katalog kesiti değil, köy binalarıyla aynı 3/4
/// izometrik açıdadır; böylece at ve arabanın zemindeki hacmi okunur.
class VehicleRenderer {
  VehicleRenderer._();

  static const int horseCartWalkFrames = 4;
  static ui.Image? _horseCartToward;
  static ui.Image? _horseCartAway;
  static final Paint _spritePaint = AssetStyle.paint();
  static final Paint _shadowPaint = Paint()
    ..color = const Color(0x3D0E0905)
    ..isAntiAlias = true;

  static Future<void> loadAll() async {
    try {
      final towardBytes = await rootBundle.load(
        'assets/vehicles/horse_cart_isometric.png',
      );
      final towardCodec = await ui.instantiateImageCodec(
        towardBytes.buffer.asUint8List(),
      );
      final towardFrame = await towardCodec.getNextFrame();
      _horseCartToward = await AssetStyle.softenAtLoad(towardFrame.image);

      final awayBytes = await rootBundle.load(
        'assets/vehicles/horse_cart_isometric_away.png',
      );
      final awayCodec = await ui.instantiateImageCodec(
        awayBytes.buffer.asUint8List(),
      );
      final awayFrame = await awayCodec.getNextFrame();
      _horseCartAway = await AssetStyle.softenAtLoad(awayFrame.image);
    } catch (e) {
      debugPrint('VehicleRenderer: at arabası yüklenemedi — $e');
    }
  }

  /// [ground] atın ayakları ve tekerlerin yol çizgisi. Sprite doğuya bakar;
  /// batı yönü aynı asset'in güvenli yatay çevrimidir.
  static void drawHorseCart(
    Canvas canvas,
    Offset ground, {
    required CartDirection direction,
    required double walkPhase,
    required bool isMoving,
    double scale = 1.0,
  }) {
    final pointsAway = switch (direction) {
      CartDirection.northEast || CartDirection.northWest => true,
      _ => false,
    };
    final facesRight = switch (direction) {
      CartDirection.southEast || CartDirection.northEast => true,
      _ => false,
    };
    final image = pointsAway ? _horseCartAway : _horseCartToward;
    if (image == null) return;

    // Kervan NPC'den iri ama bina kadar değil. 84 px'lik eski boy sahnede
    // pazar tezgâhını kapatıyordu; 58 px karakterlerle aynı dünyaya oturur.
    final drawH = 58.0 * scale;
    final drawW = drawH * image.width / image.height;
    final baseline = ground.dy;

    // Tek gölge entity ankrajında kalıp arkadaki tekeri havada gösteriyordu.
    // At ve araba temasları iki ayrı zeminsel gölgeyle bağlanır. Ofsetler
    // kaynak sprite'ın temas noktalarına normalize edilmiştir.
    final horseContact = pointsAway
        ? Offset(drawW * 0.30, -drawH * 0.36)
        : Offset(drawW * 0.27, -drawH * 0.02);
    final wheelContact = pointsAway
        ? Offset(-drawW * 0.20, -drawH * 0.03)
        : Offset(-drawW * 0.36, -drawH * 0.25);
    final flip = facesRight ? 1.0 : -1.0;
    final hoofBeat = isMoving ? horseCartWalkFrame(walkPhase) : 0;
    final horseShadowW = (hoofBeat.isEven ? 22.0 : 21.0) * scale;
    _drawContactShadow(
      canvas,
      ground + Offset(horseContact.dx * flip, horseContact.dy),
      horseShadowW,
      5.0 * scale,
    );
    _drawContactShadow(
      canvas,
      ground + Offset(wheelContact.dx * flip, wheelContact.dy),
      26.0 * scale,
      6.0 * scale,
    );

    canvas.save();
    canvas.translate(ground.dx, baseline);
    if (!facesRight) canvas.scale(-1, 1);
    final dst = Rect.fromLTWH(-drawW / 2, -drawH, drawW, drawH);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      dst,
      _spritePaint,
    );
    canvas.restore();
  }

  static void _drawContactShadow(
    Canvas canvas,
    Offset center,
    double width,
    double height,
  ) {
    canvas.drawOval(
      Rect.fromCenter(center: center, width: width, height: height),
      _shadowPaint,
    );
  }

  /// Grid hızını ekran uzayına projekte edip gerçek dört yönlü taşıt
  /// sprite'ını seçer. `facingRight` tek başına kuzey/güney ayrımını
  /// kaybettiğinden araba yolun tersine bakıyordu.
  static CartDirection directionForGridVelocity(double vx, double vy) {
    final screenX = vx - vy;
    final screenY = vx + vy;
    if (screenY >= 0) {
      return screenX >= 0 ? CartDirection.southEast : CartDirection.southWest;
    }
    return screenX >= 0 ? CartDirection.northEast : CartDirection.northWest;
  }

  /// Lokomosyon fazını dört vuruşlu nal ritmine çevirir. Dışarı açık
  /// tutulması ritmin ileri/geri ve negatif fazda sarımını test ettirir.
  static int horseCartWalkFrame(double phase) {
    final raw = (phase / (pi / 2)).floor();
    return ((raw % horseCartWalkFrames) + horseCartWalkFrames) %
        horseCartWalkFrames;
  }
}
