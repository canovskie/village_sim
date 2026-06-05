import 'dart:math';
import 'package:flutter/material.dart';
import '../core/constants.dart';

class DayNightCycle {
  static const double dayDuration = 240.0; // 4 dakika = tam gün

  /// 0.0 = gece yarısı  0.25 = şafak  0.5 = öğle  0.75 = gün batımı
  double timeOfDay;

  double rainIntensity = 0.0;
  bool   _raining      = false;
  double _phaseTimer   = 0.0;
  double _phaseDuration;
  final  Random _rng;

  /// dayLight bir önceki tick'te gece eşiğinin altındaydı mı?
  /// Edge-trigger için saklanır — onNightFall yalnız geçiş anında çağrılır.
  bool _wasNight = false;

  /// Gece başladığında bir kez tetiklenir.
  /// Kullanım: oyun loop'unda uyku hedefi atama gibi tek seferlik aksiyonlar.
  VoidCallback? onNightFall;

  /// Şafak başladığında bir kez tetiklenir (uyanma akışı için).
  VoidCallback? onMorning;

  DayNightCycle({this.timeOfDay = 0.45, int seed = 42})
      : _rng          = Random(seed),
        _phaseDuration = 55 + Random(seed).nextDouble() * 80;

  void update(double dt) {
    timeOfDay = (timeOfDay + dt / dayDuration) % 1.0;
    _updateRain(dt);
    _emitDayNightEdges();
  }

  void _emitDayNightEdges() {
    final light = dayLight;
    if (!_wasNight && light < kNightThreshold) {
      _wasNight = true;
      onNightFall?.call();
    } else if (_wasNight && light >= kDawnThreshold) {
      _wasNight = false;
      onMorning?.call();
    }
  }

  void _updateRain(double dt) {
    _phaseTimer += dt;
    const fade = 6.0;
    if (_raining) {
      if (_phaseTimer < fade) {
        rainIntensity = _phaseTimer / fade;
      } else if (_phaseTimer > _phaseDuration - fade) {
        rainIntensity = (_phaseDuration - _phaseTimer) / fade;
      } else {
        rainIntensity = 1.0;
      }
      rainIntensity = rainIntensity.clamp(0.0, 1.0);
      if (_phaseTimer >= _phaseDuration) {
        _raining       = false;
        _phaseTimer    = 0;
        _phaseDuration = 50 + _rng.nextDouble() * 90;
      }
    } else {
      rainIntensity = 0.0;
      if (_phaseTimer >= _phaseDuration) {
        _raining       = true;
        _phaseTimer    = 0;
        _phaseDuration = 22 + _rng.nextDouble() * 38;
      }
    }
  }

  // ── Sky bands ─────────────────────────────────────────────────────────────

  /// Gökyüzü üst band
  Color get skyTop => _lerp([
    (0.00, 0x06, 0x08, 0x22), // gece — derin lacivert
    (0.20, 0x12, 0x08, 0x35), // gece öncesi mor
    (0.25, 0xCC, 0x55, 0x18), // şafak — yanık turuncu
    (0.32, 0x56, 0x8A, 0xCC), // sabah — kornflower mavi
    (0.50, 0x3A, 0x72, 0xBE), // öğle — berrak mavi
    (0.68, 0x56, 0x8A, 0xCC), // öğleden sonra
    (0.75, 0xB8, 0x40, 0x20), // gün batımı — derin kırmızı-turuncu
    (0.82, 0x14, 0x08, 0x38), // akşam mor
    (1.00, 0x06, 0x08, 0x22), // gece
  ]);

  /// Gökyüzü ufuk bandı
  Color get skyMid => _lerp([
    (0.00, 0x08, 0x0C, 0x20),
    (0.20, 0x10, 0x08, 0x28),
    (0.25, 0xFF, 0xBB, 0x55), // şafak — sıcak sarı ufuk
    (0.32, 0xA8, 0xD0, 0xF8), // sabah — açık buz mavisi
    (0.50, 0xC8, 0xE8, 0xFF), // öğle — soluk beyaz-mavi ufuk
    (0.68, 0xA8, 0xD0, 0xF8), // öğleden sonra
    (0.75, 0xFF, 0x70, 0x18), // gün batımı — ateş turuncu
    (0.82, 0x10, 0x08, 0x28),
    (1.00, 0x08, 0x0C, 0x20),
  ]);

  // ── Scene overlay (vertical gradient) ────────────────────────────────────
  // İki bant: üst (gökyüzü yakın) + alt (yer/ufuk yakın). Tek tonlu eski
  // overlay yerine iki banttan gradient ile sahneye yatay derinlik verir:
  // - Gece: üst koyu lacivert, alt biraz açık tonda → yer atmosfer hissi.
  // - Şafak/günbatımı: üst mor-pembe, alt sıcak turuncu → tipik gökyüzü palet.
  // - Gündüz: her iki bant şeffaf.
  // - Yağmurda mavi-gri tonu eklenir.

  Color get overlayTop => _composeOverlay(_overlayTopRgb(), _overlayTopAlpha());
  Color get overlayBottom =>
      _composeOverlay(_overlayBottomRgb(), _overlayBottomAlpha());

  /// Geriye dönük uyumluluk — eski tek-renk overlay'i isteyen kod için
  /// gradient'in ortalamasını verir. Yeni kod overlayTop/overlayBottom'a
  /// geçmelidir.
  Color get sceneOverlay {
    final top = overlayTop;
    final bot = overlayBottom;
    int avg(num a, num b) => ((a + b) / 2).round().clamp(0, 255);
    return Color.fromARGB(
      avg(top.a * 255, bot.a * 255),
      avg(top.r * 255, bot.r * 255),
      avg(top.g * 255, bot.g * 255),
      avg(top.b * 255, bot.b * 255),
    );
  }

  Color _composeOverlay(Color rgb, double a) {
    final base = Color.fromARGB(
      (a * 255).round().clamp(0, 255),
      (rgb.r * 255).round(),
      (rgb.g * 255).round(),
      (rgb.b * 255).round(),
    );
    if (rainIntensity <= 0) return base;
    final rainA = (rainIntensity * 0.22 * 255).round().clamp(0, 255);
    return Color.alphaBlend(Color.fromARGB(rainA, 15, 30, 60), base);
  }

  Color _overlayTopRgb() => _lerp([
        (0.00, 0x05, 0x08, 0x20), // gece — derin lacivert
        (0.20, 0x10, 0x10, 0x38),
        (0.25, 0x70, 0x40, 0x60), // şafak — mor-pembe üst bant
        (0.32, 0x40, 0x40, 0x68),
        (0.38, 0x00, 0x00, 0x00), // gündüz — şeffaf yapacağız
        (0.62, 0x00, 0x00, 0x00),
        (0.70, 0x40, 0x30, 0x60),
        (0.75, 0x80, 0x28, 0x40), // gün batımı — koyu kırmızı-mor üst
        (0.82, 0x18, 0x10, 0x40),
        (1.00, 0x05, 0x08, 0x20),
      ]);

  Color _overlayBottomRgb() => _lerp([
        (0.00, 0x0A, 0x14, 0x30), // gece alt — biraz daha açık
        (0.20, 0x18, 0x18, 0x38),
        (0.25, 0xC8, 0x68, 0x18), // şafak ufuk — yanık turuncu
        (0.32, 0xE0, 0xA8, 0x60),
        (0.38, 0x00, 0x00, 0x00),
        (0.62, 0x00, 0x00, 0x00),
        (0.70, 0xE0, 0x80, 0x30),
        (0.75, 0xE8, 0x48, 0x18), // gün batımı ufuk — ateş turuncu
        (0.82, 0x20, 0x14, 0x48),
        (1.00, 0x0A, 0x14, 0x30),
      ]);

  double _overlayTopAlpha() => _lerpScalar([
        (0.00, 0.68), // gece üst — koyu ama abartısız
        (0.22, 0.54),
        (0.25, 0.40),
        (0.30, 0.18),
        (0.38, 0.00),
        (0.62, 0.00),
        (0.70, 0.20),
        (0.75, 0.40),
        (0.80, 0.54),
        (0.92, 0.62),
        (1.00, 0.68),
      ]);

  double _overlayBottomAlpha() => _lerpScalar([
        (0.00, 0.54), // gece alt
        (0.22, 0.42),
        (0.25, 0.32),
        (0.30, 0.10),
        (0.38, 0.00),
        (0.62, 0.00),
        (0.70, 0.10),
        (0.75, 0.34),
        (0.80, 0.44),
        (0.92, 0.50),
        (1.00, 0.54),
      ]);

  // ── Sun / Moon ────────────────────────────────────────────────────────────

  double get sunOpacity {
    if (timeOfDay < 0.23 || timeOfDay > 0.77) return 0.0;
    if (timeOfDay < 0.29) return ((timeOfDay - 0.23) / 0.06).clamp(0, 1);
    if (timeOfDay > 0.71) return ((0.77 - timeOfDay) / 0.06).clamp(0, 1);
    return 1.0;
  }

  Color get sunColor {
    if (timeOfDay < 0.30 || timeOfDay > 0.70) return const Color(0xFFFF9922); // şafak/gün batımı
    if (timeOfDay < 0.38 || timeOfDay > 0.62) return const Color(0xFFFFD044); // sabah/öğleden sonra
    return const Color(0xFFFFEE55); // öğle
  }

  double get moonOpacity {
    if (timeOfDay > 0.22 && timeOfDay < 0.78) return 0.0;
    if (timeOfDay <= 0.10 || timeOfDay >= 0.92) return 1.0;
    if (timeOfDay < 0.22) return ((0.22 - timeOfDay) / 0.12).clamp(0, 1);
    return ((timeOfDay - 0.78) / 0.12).clamp(0, 1);
  }

  /// Yıldızlar — ay ile aynı görünürlük (gece)
  double get starOpacity => moonOpacity;

  /// 0.0 = gece (su koyu), 1.0 = tam gündüz (su parlak)
  double get dayLight => _lerpScalar([
    (0.00, 0.0),
    (0.22, 0.0),
    (0.25, 0.15),
    (0.32, 0.75),
    (0.38, 1.0),
    (0.62, 1.0),
    (0.70, 0.75),
    (0.75, 0.15),
    (0.82, 0.0),
    (1.00, 0.0),
  ]);

  double get cloudOpacity {
    double base;
    if (timeOfDay < 0.22 || timeOfDay > 0.80) {
      base = 0.20;
    } else if (timeOfDay < 0.30 || timeOfDay > 0.72) {
      base = 0.65;
    } else {
      base = 0.85;
    }
    return (base + rainIntensity * 0.15).clamp(0.0, 1.0);
  }

  // ── Yardımcı ─────────────────────────────────────────────────────────────

  Color _lerp(List<(double, int, int, int)> frames) {
    final t = timeOfDay;
    for (int i = 0; i < frames.length - 1; i++) {
      final (t0, r0, g0, b0) = frames[i];
      final (t1, r1, g1, b1) = frames[i + 1];
      if (t >= t0 && t <= t1) {
        final f = (t - t0) / (t1 - t0);
        return Color.fromARGB(255,
          (r0 + (r1 - r0) * f).round().clamp(0, 255),
          (g0 + (g1 - g0) * f).round().clamp(0, 255),
          (b0 + (b1 - b0) * f).round().clamp(0, 255),
        );
      }
    }
    return Colors.black;
  }

  double _lerpScalar(List<(double, double)> frames) {
    final t = timeOfDay;
    for (int i = 0; i < frames.length - 1; i++) {
      final (t0, v0) = frames[i];
      final (t1, v1) = frames[i + 1];
      if (t >= t0 && t <= t1) {
        return v0 + (v1 - v0) * (t - t0) / (t1 - t0);
      }
    }
    return 0;
  }
}
