import 'dart:math';

import '../buildings/building_entity.dart';
import '../buildings/building_type.dart';

/// Sosyal destination'ların etrafındaki N adet **rezerve edilebilir slot**.
///
/// Sorun: birden çok NPC tek bir (x,y) koordinatına yöneldiğinde aynı tile'a
/// yığılır — separation force iter ama görsel olarak yine sıkışık görünür.
///
/// Çözüm: her "sosyal nokta" (kuyu, ileride ateş/pazar/depo girişi) için
/// ayrılmış birkaç slot tut. NPC yola çıkmadan önce [claim] çağırır; eli boş
/// dönerse başka noktaya gider ya da bekler. İş bitince [release].
///
/// Bu sayede:
///   • Aynı kuyu başında 4 çiftçi → her biri farklı yönden yaklaşır
///   • Slot dolu olunca 5. çiftçi başka kuyu arar (ya da bekler)
///   • Yığılma stochastic separation'a değil, deterministic kuralcı slot
///     dağılımına döner — "devrim" olan kısım bu.

class AnchorSlot {
  final double col;
  final double row;
  bool _taken = false;
  Object? _owner; // debug + zincirleme release güvenliği

  AnchorSlot(this.col, this.row);

  bool get isFree => !_taken;
}

class AnchorPoint {
  /// Bu noktanın kaynak binası — UI / debug için faydalı.
  final BuildingEntity building;
  final List<AnchorSlot> slots;

  AnchorPoint({required this.building, required this.slots});

  /// İlk boş slot'u sahiplenir, [owner] sahip referansı. Hepsi dolu → null.
  AnchorSlot? claim(Object owner) {
    for (final s in slots) {
      if (!s._taken) {
        s._taken = true;
        s._owner = owner;
        return s;
      }
    }
    return null;
  }

  /// Slot'u serbest bırakır. [owner] sahibi değilse no-op (savunmacı).
  void release(AnchorSlot s, Object owner) {
    if (s._owner == owner) {
      s._taken = false;
      s._owner = null;
    }
  }

  /// Tüm slot'ları zorla boşalt — bina silinince / harita reset.
  void clearAll() {
    for (final s in slots) {
      s._taken = false;
      s._owner = null;
    }
  }
}

/// Tüm anchor noktalarını binalardan türeten merkezi otorite.
/// main.dart bir instance tutar; topology değişince [rebuild] çağırır
/// (her tick DEĞİL — aktif rezervasyonlar reset olur aksi halde).
class AnchorSystem {
  /// Kuyular — çiftçi su alımı.
  final List<AnchorPoint> wellPoints = [];
  /// Depo (warehouse) — taşıyıcı teslim noktası.
  final List<AnchorPoint> warehousePoints = [];
  /// Ateş yeri — taşıyıcı teslim fallback'i (depo yoksa) + gece toplanma.
  final List<AnchorPoint> firepitPoints = [];

  /// Tüm noktaları siler ve binalardan yeniden üretir.
  /// Eski slot rezervasyonları kaybolur — NPC bir sonraki claim'inde
  /// yeni slot alır (otomatik recovery).
  void rebuild(List<BuildingEntity> buildings) {
    wellPoints.clear();
    warehousePoints.clear();
    firepitPoints.clear();
    for (final b in buildings) {
      switch (b.type) {
        case BuildingType.well:
          // 1×1 kuyu; 4 yönden yaklaşım slotu (kuzey, güney, doğu, batı).
          final cx = b.col + 0.5;
          final cy = b.row + 0.5;
          wellPoints.add(AnchorPoint(
            building: b,
            slots: [
              AnchorSlot(cx,       cy - 0.7),
              AnchorSlot(cx,       cy + 0.7),
              AnchorSlot(cx - 0.7, cy      ),
              AnchorSlot(cx + 0.7, cy      ),
            ],
          ));
        case BuildingType.warehouse:
          // 3×2 depo. 5 teslim slotu: güney yarım halka + 1 doğu girişi.
          // Tile (col..col+2, row..row+1).
          warehousePoints.add(AnchorPoint(
            building: b,
            slots: [
              AnchorSlot(b.col + 0.5, b.row + 2.3), // güney-sol
              AnchorSlot(b.col + 1.5, b.row + 2.6), // güney-orta
              AnchorSlot(b.col + 2.5, b.row + 2.3), // güney-sağ
              AnchorSlot(b.col + 3.3, b.row + 1.0), // doğu
              AnchorSlot(b.col + 3.3, b.row + 0.0), // kuzey-doğu
            ],
          ));
        case BuildingType.firepit:
          // 1×1 ateş yeri. 6 slot çevresinde — gündüz teslim fallback'i,
          // gece de toplanma (sleep target dağıtımı ayrı sistem).
          final cx = b.col + 0.5;
          final cy = b.row + 0.5;
          firepitPoints.add(AnchorPoint(
            building: b,
            slots: [
              for (int i = 0; i < 6; i++)
                _ringSlot(cx, cy, 1.4, i, 6),
            ],
          ));
        default:
          break;
      }
    }
  }

  static AnchorSlot _ringSlot(double cx, double cy, double r, int i, int n) {
    final a = i * (2 * pi / n);
    return AnchorSlot(cx + r * cos(a), cy + r * sin(a));
  }

  /// Verilen NPC'ye en yakın boş kuyu slot'u — claim'i yapar.
  (AnchorPoint, AnchorSlot)? claimNearestWell(
      double npcCol, double npcRow, Object owner) =>
      _claimNearestFrom(wellPoints, npcCol, npcRow, owner);

  /// Carrier teslim slot'u — önce warehouse'tan, yoksa firepit'ten.
  /// Tek API: assignCarriers bunu çağırır, fallback chain burada.
  (AnchorPoint, AnchorSlot)? claimDeliverySlot(
      double npcCol, double npcRow, Object owner) {
    final fromWh = _claimNearestFrom(warehousePoints, npcCol, npcRow, owner);
    if (fromWh != null) return fromWh;
    return _claimNearestFrom(firepitPoints, npcCol, npcRow, owner);
  }

  /// Liste içinden NPC'ye en yakın boş slot'u claim eder. Boş yoksa null.
  (AnchorPoint, AnchorSlot)? _claimNearestFrom(
      List<AnchorPoint> points, double npcCol, double npcRow, Object owner) {
    AnchorPoint? bestPoint;
    AnchorSlot? bestSlot;
    double bestD2 = double.infinity;
    for (final p in points) {
      for (final s in p.slots) {
        if (s._taken) continue;
        final dx = s.col - npcCol;
        final dy = s.row - npcRow;
        final d2 = dx * dx + dy * dy;
        if (d2 < bestD2) {
          bestD2   = d2;
          bestPoint = p;
          bestSlot  = s;
        }
      }
    }
    if (bestPoint == null || bestSlot == null) return null;
    bestSlot._taken = true;
    bestSlot._owner = owner;
    return (bestPoint, bestSlot);
  }
}

