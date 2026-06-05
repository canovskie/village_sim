import 'dart:math';
import 'package:flutter/material.dart';

class WaterRenderer {
  // ── Sin/Cos Lookup Table ────────────────────────────────────────────────────
  static const int    _kLutN    = 2048;
  static const int    _kLutMask = _kLutN - 1;
  static const double _kLutInv  = _kLutN / (2 * pi);

  static final List<double> _sinLut = _buildLut();

  static List<double> _buildLut() {
    final lut = List<double>.filled(_kLutN, 0.0);
    for (int i = 0; i < _kLutN; i++) {
      lut[i] = sin(i * 2 * pi / _kLutN);
    }
    return lut;
  }

  static double _sin(double x) {
    final idx = (x * _kLutInv).toInt() & _kLutMask;
    return _sinLut[idx < 0 ? idx + _kLutN : idx];
  }

  static double _cos(double x) => _sin(x + pi / 2);

  // ── Zoom LOD eşikleri ──────────────────────────────────────────────────────
  static const double _kLodFull   = 0.55;
  static const double _kLodMedium = 0.30;

  // ── Static Paint havuzu ────────────────────────────────────────────────────
  static final _pFill    = Paint()..isAntiAlias = false;
  static final _pBorderLod = Paint()
    ..color       = const Color(0xFF082848)
    ..style       = PaintingStyle.stroke
    ..strokeWidth = 1.0
    ..isAntiAlias = false;
  static final _pWave1   = Paint()..isAntiAlias = false;
  static final _pWave2   = Paint()..isAntiAlias = false;
  static final _pSparkle = Paint()..isAntiAlias = false;
  static final _pFishBody= Paint()..isAntiAlias = false;
  static final _pFishEye = Paint()..isAntiAlias = false;
  static final _pRain    = Paint()
    ..style       = PaintingStyle.stroke
    ..strokeWidth = 1.0
    ..isAntiAlias = true;
  static final _pBorder  = Paint()
    ..color       = const Color(0xFF082848)
    ..style       = PaintingStyle.stroke
    ..strokeWidth = 1.0
    ..isAntiAlias = false;
  static final _pFoam    = Paint()
    ..strokeWidth = 1.5
    ..isAntiAlias = false;

  // Diamond Path havuzu — her tile için yeni Path() yerine reset+yeniden inşa.
  static final Path _diamond = Path();

  // ───────────────────────────────────────────────────────────────────────────

  static void drawTile(
    Canvas canvas,
    double px,
    double py,
    double hw,
    double hh, {
    double time          = 0,
    int    seed          = 0,
    double dayLight      = 1.0,
    double rainIntensity = 0.0,
    double zoom          = 1.0,
    Color  skyTint       = const Color(0xFFA0C0E0),
  }) {
    final phase = (seed * 1373 % 1000) / 1000.0 * 2 * pi;

    final w1 = _sin(time * 0.85 + phase)       * 0.5 + 0.5;
    final w2 = _sin(time * 1.50 + phase + 1.9) * 0.5 + 0.5;
    final w3 = _sin(time * 0.40 + phase + 3.3) * 0.5 + 0.5;

    final baseR = (14  + w3 * 12  + dayLight * 8 );
    final baseG = (62  + w1 * 28  + dayLight * 20);
    final baseB = (138 + w2 * 55  + dayLight * 30);

    // Gökyüzü yansıması — base renge skyTint'i 0.22 ağırlıkla karıştır.
    // dayLight=0 gecede yansıma daha az hissedilir (sky zaten karanlık).
    const mix    = 0.22;
    final skyR   = skyTint.r * 255;
    final skyG   = skyTint.g * 255;
    final skyB   = skyTint.b * 255;
    final dr = (baseR * (1 - mix) + skyR * mix).toInt().clamp(0, 255);
    final dg = (baseG * (1 - mix) + skyG * mix).toInt().clamp(0, 255);
    final db = (baseB * (1 - mix) + skyB * mix).toInt().clamp(0, 255);

    // Bleed: zoom transform sonrası komşu tile'larla 1px overlap → arka plan
    // sızıntısı yok (bkz. TileRenderer.drawGrassTile).
    const b = 1.0;
    _diamond
      ..reset()
      ..moveTo(px,          py - b)
      ..lineTo(px + hw + b, py + hh)
      ..lineTo(px,          py + hh * 2 + b)
      ..lineTo(px - hw - b, py + hh)
      ..close();

    _pFill.color = Color.fromARGB(255, dr, dg, db);
    canvas.drawPath(_diamond, _pFill);

    if (zoom < _kLodMedium) {
      canvas.drawPath(_diamond, _pBorderLod);
      return;
    }

    canvas.save();
    canvas.clipPath(_diamond);

    // Dalga bandı 1
    final b1y = py + hh * (0.25 + w1 * 0.65);
    _pWave1.color = Color.fromARGB(
        (w1 * 45 + dayLight * 15).toInt().clamp(0, 255), 110, 210, 255);
    canvas.drawRect(Rect.fromLTWH(px - hw, b1y, hw * 2, 2), _pWave1);

    // Dalga bandı 2
    final b2y = py + hh * (0.05 + w2 * 0.90);
    _pWave2.color = Color.fromARGB(
        (w2 * 60 + dayLight * 20).toInt().clamp(0, 255), 190, 235, 255);
    canvas.drawRect(Rect.fromLTWH(px - hw, b2y, hw * 2, 1), _pWave2);

    // Sparkle noktaları
    for (int i = 0; i < 4; i++) {
      final sx     = ((seed * (17 + i * 11) + 7)  % 87) / 87.0;
      final sy     = ((seed * (23 + i * 13) + 13) % 73) / 73.0;
      final spX    = px + (sx - 0.5) * hw * 1.3;
      final spY    = py + hh + (sy - 0.5) * hh * 1.1;
      final sPhase = time * (1.1 + i * 0.4) + phase + i * 2.1;
      final sparkA = (_sin(sPhase) * 0.5 + 0.5);
      if (sparkA > 0.55) {
        final alpha = ((sparkA - 0.55) / 0.45 * 210 * dayLight).toInt().clamp(0, 210);
        _pSparkle.color = Color.fromARGB(alpha, 215, 245, 255);
        canvas.drawRect(
            Rect.fromLTWH(spX.roundToDouble(), spY.roundToDouble(), 1, 1),
            _pSparkle);
      }
    }

    // Balık animasyonu
    {
      final fSeed  = seed * 1997 + 7;
      final fPhase = (fSeed % 1000) / 1000.0 * 2 * pi;
      final fSpeed = 0.45 + (fSeed % 5) * 0.09;
      final visT   = _sin(time * 0.22 + fPhase);
      final alpha  = ((visT * 0.5 + 0.5) * 170 * dayLight).toInt().clamp(0, 170);

      if (alpha > 20) {
        final xOff = _sin(time * fSpeed + fPhase) * hw * 0.50;
        final yOff = ((fSeed % 60) - 30) / 30.0 * hh * 0.35;
        final fx   = (px + xOff).roundToDouble();
        final fy   = (py + hh + yOff).roundToDouble();

        final facingRight = _cos(time * fSpeed + fPhase) > 0;
        _pFishBody.color = Color.fromARGB(alpha, 200, 140, 55);
        _pFishEye .color = Color.fromARGB((alpha * 0.6).toInt(), 100, 60, 20);

        canvas.drawRect(Rect.fromLTWH(fx, fy - 1, 5, 2), _pFishBody);
        if (facingRight) {
          canvas.drawRect(Rect.fromLTWH(fx - 2, fy - 2, 2, 3), _pFishBody);
        } else {
          canvas.drawRect(Rect.fromLTWH(fx + 5, fy - 2, 2, 3), _pFishBody);
        }
        final eyeX = facingRight ? fx + 3 : fx + 1;
        canvas.drawRect(Rect.fromLTWH(eyeX, fy - 1, 1, 1), _pFishEye);
      }
    }

    // Yağmur halkaları
    if (zoom >= _kLodFull && rainIntensity > 0.01) {
      for (int i = 0; i < 4; i++) {
        final rx    = ((seed * (31 + i * 17) + 11) % 79) / 79.0;
        final ry    = ((seed * (37 + i * 23) +  7) % 67) / 67.0;
        final rpX   = px + (rx - 0.5) * hw * 1.1;
        final rpY   = py + hh + (ry - 0.5) * hh * 0.85;
        final speed = 1.2 + i * 0.35;
        final t     = (time * speed + phase + i * 0.61) % 1.0;
        final radius = t * hw * 0.55;
        final alpha  = ((1.0 - t) * (1.0 - t) * rainIntensity * 200)
            .toInt().clamp(0, 200);
        if (alpha > 4) {
          _pRain.color = Color.fromARGB(alpha, 160, 220, 255);
          canvas.drawCircle(Offset(rpX, rpY), radius, _pRain);
        }
      }
    }

    canvas.restore();

    canvas.drawPath(_diamond, _pBorder);
  }

  static void drawFoam(Canvas canvas, double px, double py, double hw, double hh,
      double time, int seed) {
    final phase = (seed * 937 % 1000) / 1000.0 * 2 * pi;
    final alpha = ((_sin(time * 1.2 + phase) * 0.3 + 0.7) * 120).toInt().clamp(0, 120);
    _pFoam.color = Color.fromARGB(alpha, 200, 235, 255);
    canvas.drawLine(
      Offset(px - hw * 0.6, py + hh * 0.4),
      Offset(px + hw * 0.6, py + hh * 0.4),
      _pFoam,
    );
  }
}
