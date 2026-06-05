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
  static List<LightSource> collect({
    required List<BuildingEntity> buildings,
    required List<VillagerEntity> villagers,
    required double dayLight,
  }) {
    final result = <LightSource>[];
    final darkness = (1.0 - dayLight).clamp(0.0, 1.0);
    if (darkness < 0.05) return result;

    for (final b in buildings) {
      final cx = b.col + b.cols / 2.0;
      final cy = b.row + b.rows / 2.0;

      if (b.type == BuildingType.firepit) {
        // Ateş yeri — sıcak ama göz almasın. Core alpha = intensity × 190
        // (painter); intensity 0.55'e çekildi → peak ~105 alpha, yumuşak.
        // Radius da kısaldı: dış halo bina ölçeğinde kalır, "dev güneş" değil.
        result.add(LightSource(
          gx: cx, gy: cy,
          radius: 3.8 + darkness * 0.8, // 3.8–4.6 tile (önceden 5.5–7.0)
          intensity: 0.55,              // önceden 1.0
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

    // Meşaleli yürüyen NPC — yalnız gece, sınırlı alan.
    if (darkness > 0.40) {
      for (final v in villagers) {
        if (v.isInsideBuilding || v.isSleeping || !v.isWalking) continue;
        result.add(LightSource(
          gx: v.renderX, gy: v.renderY,
          radius: 1.6 + darkness * 0.4,
          intensity: darkness * 0.85,
          warm: const Color(0xFFFF8A30),
        ));
      }
    }

    return result;
  }

  /// Verilen dünya koordinatı herhangi bir ışık kaynağının "çekirdek" alanına
  /// giriyor mu? "Meşalesiz gece yürüyen NPC" gibi oyun mekanikleri için
  /// hazır helper.
  ///
  /// [coreRatio] ışık çemberinin yüzde kaçını "tam aydınlık" sayacağı (kenar
  /// gradient'i hariç tutulur — 0.85 varsayılan: dış %15 fade alanı gri).
  static bool isInLight(
    double gx, double gy,
    List<LightSource> sources, {
    double coreRatio = 0.85,
  }) {
    for (final l in sources) {
      final dx = gx - l.gx;
      final dy = gy - l.gy;
      final r  = l.radius * coreRatio;
      if (dx * dx + dy * dy <= r * r) return true;
    }
    return false;
  }
}
