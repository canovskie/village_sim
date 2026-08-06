import 'dart:math';
import 'package:flutter/material.dart';
import '../buildings/building_entity.dart';
import '../buildings/building_function.dart';
import '../buildings/building_type.dart';
import '../entities/villager_entity.dart';

/// Dünya-uzayında bir ışık kaynağı.
///
/// Birim: [gx],[gy] grid tile, [radius] tile yarıçapı. Renderer'a verildiğinde
/// screen-pixel'e çevirir (`radius * kPixelsPerTile * zoom`); oyun mantığında
/// (örn. "şu NPC ışıkta mı?") doğrudan tile mesafesiyle karşılaştırılır.
///
/// Tek bir kaynaktan hem görseli hem gameplay sorgusu beslenir → render ile
/// mekanik tutarlı kalır.
class LightSource {
  final double gx;
  final double gy;
  /// Tile cinsinden etki yarıçapı.
  final double radius;
  /// 0..1 — alpha + halo gücü çarpanı.
  final double intensity;
  /// Halo tonu.
  final Color warm;

  const LightSource({
    required this.gx,
    required this.gy,
    required this.radius,
    required this.intensity,
    required this.warm,
  });
}

/// Bir grid (tile) biriminin ekrandaki yaklaşık piksel karşılığı.
/// Izometrik tile 64×32 — yatay ve düşey ortalaması.
const double kPixelsPerTile = 48.0;

class LightingSystem {
  /// Mevcut bina + NPC listesinden ışık kaynaklarını üretir.
  ///
  /// Gündüz (dayLight ≈ 1) liste neredeyse boş döner; karardıkça önce ateş
  /// yeri, sonra fenerler, sonra ev pencereleri ve aktif işyerleri devreye
  /// girer. Meşaleli yürüyen NPC'ler tam karanlıkta eklenir.
  /// [rainIntensity] — ateş yeri ışığı yağmurla sönen alevle aynı eğride
  /// kısılır (alev `building_renderer` 0..0.30 → 1..0 fade).
  static List<LightSource> collect({
    required List<BuildingEntity> buildings,
    required List<VillagerEntity> villagers,
    required double dayLight,
    double rainIntensity = 0.0,
    double time = 0.0,
  }) {
    final result = <LightSource>[];
    final darkness = (1.0 - dayLight).clamp(0.0, 1.0);
    if (darkness < 0.05) return result;

    // Ateş alevi rainIntensity 0..0.30 arasında 1→0 sönüyor (building_renderer).
    // Işık da aynı eğride sönsün — alev yoksa halo da yok.
    final fireRainFade = (1.0 - rainIntensity / 0.30).clamp(0.0, 1.0);

    for (final b in buildings) {
      final cx = b.col + b.cols / 2.0;
      final cy = b.row + b.rows / 2.0;

      if (b.type == BuildingType.firepit) {
        // Yağmur alevi söndürdüyse VEYA yakıt bittiyse halo da atlanır.
        final fuelFade = (b.fireFuel * 3.0).clamp(0.0, 1.0);
        final fireFade = fireRainFade < fuelFade ? fireRainFade : fuelFade;
        if (fireFade < 0.02) continue;
        // Ateş yeri — sıcak ama göz almasın. Core alpha = intensity × 190
        // (painter); intensity 0.55'e çekildi → peak ~105 alpha, yumuşak.
        // Radius da kısaldı: dış halo bina ölçeğinde kalır, "dev güneş" değil.
        result.add(LightSource(
          gx: cx, gy: cy,
          radius: (3.8 + darkness * 0.8) * fireFade,
          intensity: 0.55 * fireFade,
          warm: const Color(0xFFFF9540),
        ));
      } else if (b.type == BuildingType.lamppost) {
        // Sokak feneri — yol kenarına yerleştirilirse aydınlık koridor.
        if (darkness < 0.20) continue;
        result.add(LightSource(
          gx: cx, gy: cy,
          radius: 2.5 + darkness * 0.8, // 2.66–3.3 tile
          intensity: darkness,
          warm: const Color(0xFFFFCE60),
        ));
      } else if (b.fn?.role == BuildingRole.housing &&
                 b.occupants > 0 && darkness > 0.30) {
        // Ev — sakini varsa gece pencere ışığı.
        result.add(LightSource(
          gx: cx, gy: cy,
          radius: 2.2 + darkness * 0.6,
          intensity: darkness,
          warm: const Color(0xFFFFC868),
        ));
      } else if (b.isActive && darkness > 0.30) {
        // Aktif işyeri (smithy, market, vs) — daha zayıf.
        result.add(LightSource(
          gx: cx, gy: cy,
          radius: 1.8 + darkness * 0.5,
          intensity: darkness * 0.75,
          warm: const Color(0xFFFFB078),
        ));
      }
    }

    // Meşaleli NPC — yalnız `torchLevel > epsilon` olanlar (entity update'te
    // hesaplanmış smooth değer; eligibility + dayLight + rain hep oradan).
    // Pozisyon: NPC merkezinden hafif yukarı (torch ucu sprite'ın baş üstü;
    // grid uzayında ~0.45 tile yukarı). Per-NPC flicker fazıyla intensity
    // hafifçe nabız atar — tek tip parıltı yerine canlı topluluk hissi.
    for (final v in villagers) {
      if (v.torchLevel < 0.05) continue;
      // Flicker: ±%8 intensity wobble, per-NPC sabit fazda.
      final flicker = 1.0 + sin(time * 4.3 + v.torchPhase) * 0.08;
      final lv = v.torchLevel * flicker;
      result.add(LightSource(
        gx: v.renderX,
        gy: v.renderY - 0.45,             // torch head ~yarım tile yukarı
        radius: (1.7 + darkness * 0.5) * v.torchLevel,
        intensity: (0.85 * lv).clamp(0.0, 1.0),
        warm: const Color(0xFFFF8A30),
      ));
    }

    return result;
  }

  // isInLight() "ileride lazım olur" diye yazılmış hazır helper'dı, hiçbir
  // mekanik onu sormadı → kaldırıldı. Karanlıkta yürüme mekaniği gerekirse
  // ışık kaynağı listesi zaten burada, sorgu o zaman yazılır.
}
