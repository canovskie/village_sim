import 'dart:math';
import 'package:flutter/material.dart';
import '../core/constants.dart';

class DayNightCycle {
  static const double dayDuration = 240.0; // 4 dakika = tam gün

  /// Gün ışığı artık çevrimin %60'ını, gece %40'ını kaplar. Tam oyun günü yine
  /// 4 dakikadır; yalnız karanlık yarı 120 sn'den 96 sn'ye kısalır.
  static const double nightDuration = 96.0;
  static const double daylightDuration = dayDuration - nightDuration;

  /// 0.0 = gece yarısı  0.25 = şafak  0.5 = öğle  0.75 = gün batımı
  double timeOfDay;

  double rainIntensity = 0.0;
  bool _raining = false;
  double _phaseTimer = 0.0;
  double _phaseDuration;
  final Random _rng;

  /// dayLight bir önceki tick'te gece eşiğinin altındaydı mı?
  /// Edge-trigger için saklanır — onNightFall yalnız geçiş anında çağrılır.
  bool _wasNight = false;

  /// "Berrak gece" katsayısı — 0 (default puslu/sisli) → 1 (temiz/berrak).
  /// Her gece başında rastgele rolled (~%30 olasılıkla 1.0), gün ağarınca 0'a
  /// reset. Smooth lerp ile yumuşatılır → ani değişim olmaz. Consumer'lar:
  ///  • Overlay alpha (top/bottom): berrakta hafifler → sahne daha okunur.
  ///  • Ambient strength: berrakta hafifler → mavi mehtap modulate'ı çekilir.
  ///  • Star opacity: berrakta yıldızlar parlar.
  ///  • Kıyı sisi (game_painter): berrakta belirgin azalır.
  double _nightClarity = 0.0;

  /// Bu gecenin hedef berraklığı — _emitDayNightEdges'in night ledge'inde
  /// rng'den yazılır. Day ledge'inde 0'a düşer.
  double _nightClarityTarget = 0.0;

  /// Public: anlık berraklık (renderer'a geçer).
  double get nightClarity => _nightClarity;

  /// Public: bu gece random ile berrak mı seçildi (notif/HUD için).
  bool get isClearNight => _nightClarityTarget > 0.5;

  /// Gece başladığında bir kez tetiklenir.
  /// Kullanım: oyun loop'unda uyku hedefi atama gibi tek seferlik aksiyonlar.
  VoidCallback? onNightFall;

  /// Şafak başladığında bir kez tetiklenir (uyanma akışı için).
  VoidCallback? onMorning;

  DayNightCycle({this.timeOfDay = 0.45, int seed = 42})
    : _rng = Random(seed),
      _phaseDuration = 55 + Random(seed).nextDouble() * 80;

  void update(double dt) {
    // timeOfDay'ın iki yarısı eşit uzunlukta değildir: 0.25→0.75 gündüz,
    // 0.75→0.25 gece. Yarı çevrimi kendi gerçek süresine bölen çarpan 2'dir.
    final inNightHalf = timeOfDay < 0.25 || timeOfDay >= 0.75;
    final phaseDuration = inNightHalf
        ? nightDuration * 2
        : daylightDuration * 2;
    timeOfDay = (timeOfDay + dt / phaseDuration) % 1.0;
    _updateRain(dt);
    _emitDayNightEdges();
    // Berraklık yumuşak yaklaşır — gece başında ~25 sn'de stabilize, gündüze
    // dönerken erkenden 0'a iner. dt'ye dayalı lerp → fps bağımsız.
    final rate = (1.0 - 1.0 / (1.0 + 1.4 * dt)).clamp(0.0, 1.0);
    _nightClarity += (_nightClarityTarget - _nightClarity) * rate;
  }

  /// Kuruluş öğreticisinin tek gecelik kısa geçişi. Normal çevrim sürelerine
  /// dokunmaz; yalnız çağrıldığı geceden şafağa sıçrar ve sabah kenarını bir
  /// kez üretir. Sonraki bütün geceler [update] ile normal uzunlukta akar.
  void skipNightToMorning() {
    // 0.25 henüz loş şafak (dayLight 0.15); 0.32 gerçek sabah ışığıdır ve
    // köylülerin kademeli uyanma eşiğini de geçmiş olur.
    timeOfDay = 0.32;
    final wasNight = _wasNight;
    _wasNight = false;
    _nightClarityTarget = 0.0;
    if (wasNight) onMorning?.call();
  }

  void _emitDayNightEdges() {
    final light = dayLight;
    if (!_wasNight && light < kNightThreshold) {
      _wasNight = true;
      // %30 berrak gece, %70 normal (puslu) — özel hissi koru, sıradanlaştırma.
      _nightClarityTarget = _rng.nextDouble() < 0.30 ? 1.0 : 0.0;
      onNightFall?.call();
    } else if (_wasNight && light >= kDawnThreshold) {
      _wasNight = false;
      // Gündüze geçişte berraklık reset → bir sonraki gece taze roll.
      _nightClarityTarget = 0.0;
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
        _raining = false;
        _phaseTimer = 0;
        _phaseDuration = 50 + _rng.nextDouble() * 90;
      }
    } else {
      rainIntensity = 0.0;
      if (_phaseTimer >= _phaseDuration) {
        _raining = true;
        _phaseTimer = 0;
        _phaseDuration = 22 + _rng.nextDouble() * 38;
      }
    }
  }

  // ── Sky bands ─────────────────────────────────────────────────────────────

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

  // NOT: ambientTint (modulate) sahneye kendi başına gece tonunu zaten
  // çekiyor → buradaki alpha'lar daha önce "tek darkening kaynağı" olduğunda
  // ayarlanmıştı. Modulate eklendiğinde double-darkening olmasın diye gece
  // ve gün batımı tepelerinde ~%20 düşürüldü. Geçiş kuşaklarında (alaca-
  // karanlık) modulate strength düşük olduğundan overlay'in payı korunur.
  double _overlayTopAlpha() {
    final base = _lerpScalar([
      (0.00, 0.52), // gece üst — modulate ile birleşince doğru koyuluk
      (0.22, 0.42),
      (0.25, 0.36),
      (0.30, 0.18),
      (0.38, 0.00),
      (0.62, 0.00),
      (0.70, 0.20),
      (0.75, 0.36),
      (0.80, 0.44),
      (0.92, 0.50),
      (1.00, 0.52),
    ]);
    // Berrak gecede üst overlay hafifler → gökyüzü/sahne daha okunur.
    // dayLight düşükken (gece tarafında) tam etki; gündüze sızmasın diye
    // dayLight ile maskelenir.
    final nightWeight = (1.0 - dayLight.clamp(0.0, 1.0)).clamp(0.0, 1.0);
    return (base - _nightClarity * nightWeight * 0.18).clamp(0.0, 1.0);
  }

  double _overlayBottomAlpha() {
    final base = _lerpScalar([
      (0.00, 0.40), // gece alt
      (0.22, 0.32),
      (0.25, 0.28),
      (0.30, 0.10),
      (0.38, 0.00),
      (0.62, 0.00),
      (0.70, 0.10),
      (0.75, 0.28),
      (0.80, 0.36),
      (0.92, 0.40),
      (1.00, 0.40),
    ]);
    final nightWeight = (1.0 - dayLight.clamp(0.0, 1.0)).clamp(0.0, 1.0);
    return (base - _nightClarity * nightWeight * 0.14).clamp(0.0, 1.0);
  }

  // ── Ambient color grade ──────────────────────────────────────────────────
  // Sahnenin "içinde bulunduğu ışık tonu". game_painter bunu fullscreen
  // BlendMode.modulate ile sprite katmanına uygular — her sprite zamanın
  // rengini içer. Modulate fiziksel: az ışık = koyu + tinted, beyaz = nötr.
  //
  // Gece: soğuk mavi mehtap (kanalları 0.6×0.7×0.8 oranında düşürür).
  // Şafak/akşam: amber/şeftali (mavi kanalı düşür, kırmızıyı koru).
  // Öğle: neredeyse beyaz — sahneye dokunmaz.
  //
  // [ambientStrength] 0..1 — game_painter strength=0'da identity'e (beyaz)
  // lerp eder. Önceden hesaplanmış efektif renk = lerp(white, tint, strength).
  Color get ambientTint => _lerp([
    (0.00, 0x76, 0x8C, 0xB8), // gece — soğuk mavi mehtap
    (0.18, 0x82, 0x80, 0xAC), // gece sonu — mor-mavi
    (0.25, 0xE8, 0xA8, 0x80), // şafak — şeftali
    (0.32, 0xFF, 0xE4, 0xC8), // sabah — soluk sıcak
    (0.42, 0xFF, 0xF6, 0xE8), // öğleye yakın — nötre yakın
    (0.50, 0xFF, 0xFA, 0xEE), // öğle — nötr-sıcak
    (0.58, 0xFF, 0xF4, 0xE2), // öğleden sonra
    (0.68, 0xFF, 0xDC, 0xA8), // altın saat öncesi — amber
    (0.75, 0xFF, 0x96, 0x4C), // altın saat — sıcak amber
    (0.82, 0x6C, 0x5C, 0xA0), // alacakaranlık — mor
    (0.92, 0x68, 0x78, 0xAC), // gece başı
    (1.00, 0x76, 0x8C, 0xB8),
  ]);

  /// Ambient tint'in sahneye ne kadar baskın uygulanacağı (0 = identity).
  /// Modulate tek başına çok güçlü olabilir → gece/altın saatte güçlü, öğle
  /// neredeyse 0. Berrak gecede modulate hafifler → mavi mehtap perdesi
  /// çekilir, sprite'lar daha temiz okunur.
  double get ambientStrength {
    final base = _lerpScalar([
      (0.00, 0.62),
      (0.20, 0.50),
      (0.25, 0.55),
      (0.32, 0.30),
      (0.40, 0.10),
      (0.50, 0.05), // öğle — neredeyse identity
      (0.60, 0.12),
      (0.68, 0.36),
      (0.75, 0.58), // altın saat — güçlü
      (0.82, 0.50),
      (0.92, 0.56),
      (1.00, 0.62),
    ]);
    final nightWeight = (1.0 - dayLight.clamp(0.0, 1.0)).clamp(0.0, 1.0);
    return (base - _nightClarity * nightWeight * 0.16).clamp(0.0, 1.0);
  }

  // ── Sun / Moon ────────────────────────────────────────────────────────────

  double get sunOpacity {
    if (timeOfDay < 0.23 || timeOfDay > 0.77) return 0.0;
    if (timeOfDay < 0.29) return ((timeOfDay - 0.23) / 0.06).clamp(0, 1);
    if (timeOfDay > 0.71) return ((0.77 - timeOfDay) / 0.06).clamp(0, 1);
    return 1.0;
  }

  Color get sunColor {
    if (timeOfDay < 0.30 || timeOfDay > 0.70) {
      return const Color(0xFFFF9922); // şafak/gün batımı
    }
    if (timeOfDay < 0.38 || timeOfDay > 0.62) {
      return const Color(0xFFFFD044); // sabah/öğleden sonra
    }
    return const Color(0xFFFFEE55); // öğle
  }

  double get moonOpacity {
    if (timeOfDay > 0.22 && timeOfDay < 0.78) return 0.0;
    if (timeOfDay <= 0.10 || timeOfDay >= 0.92) return 1.0;
    if (timeOfDay < 0.22) return ((0.22 - timeOfDay) / 0.12).clamp(0, 1);
    return ((timeOfDay - 0.78) / 0.12).clamp(0, 1);
  }

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

  // ── Yardımcı ─────────────────────────────────────────────────────────────

  Color _lerp(List<(double, int, int, int)> frames) {
    final t = timeOfDay;
    for (int i = 0; i < frames.length - 1; i++) {
      final (t0, r0, g0, b0) = frames[i];
      final (t1, r1, g1, b1) = frames[i + 1];
      if (t >= t0 && t <= t1) {
        final f = (t - t0) / (t1 - t0);
        return Color.fromARGB(
          255,
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
