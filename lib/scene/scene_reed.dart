part of '../main.dart';

/// Saz yatağı sistemi — evsizlerin "self-service" barınma döngüsü.
///
/// Akış: ev bulamayan (homeBuilding==null) bir yetişkin köylü gündüz en yakın
/// OLGUN sazlığa gider, biçer (→ saz stoğa, küçük anız + regrow), depoda saz
/// birikince ateş etrafındaki boş bir ring slotuna saz yatağı kurar (saz
/// harcar) ve onu sahiplenir. Harcanmayan saz depoda birikir = "fazlası
/// depoya". Geceleri sahibi yatağında uyur (bkz. _assignSleepTargets).
///
/// Tek sahip ilkesi: bir evsiz yatak peşindeyse ve gerçekten yapacak iş varsa
/// (_reedTaskAvailable) genel rutin ona dokunmaz — bu sistem sürer.
///
/// Bağımlı: _firepitBuilding, _reeds (ReedClump), _stockpile, _obstacles/
/// _waterTiles, _freeSpotNear (scene_npc_routine).
extension _SceneReed on _VillageSceneState {
  static const double _kReedScan   = 0.5;
  static const int    _kMaxReedBeds = 8;
  static const double _kBedRing     = 2.0; // ateş merkezinden yatak uzaklığı

  /// Evsiz + yetişkin + henüz yatağı yok mu?
  bool _homelessSeekingBed(VillagerEntity v) =>
      v.homeBuilding == null && v.canRunErrands && !_villagerHasBed(v);

  bool _villagerHasBed(VillagerEntity v) =>
      _reedBeds.any((b) => identical(b.owner, v));

  ReedBed? _bedOf(VillagerEntity v) {
    for (final b in _reedBeds) {
      if (identical(b.owner, v)) return b;
    }
    return null;
  }

  /// Şu an saz işi var mı? (sahipsiz yatak / kurulabilir yatak / biçilebilir
  /// sazlık). Yoksa evsiz normal hayatına devam etsin (rutin devralır).
  bool _reedTaskAvailable() {
    if (_firepitBuilding == null) return false;
    if (_firstOwnerlessBed() != null) return true;
    if (_stockpile.reed >= kReedBedCost &&
        _reedBeds.length < _kMaxReedBeds &&
        _freeBedSlot() != null) {
      return true;
    }
    return _reeds.any((c) => c.harvestable);
  }

  void _tickReed(double dt) {
    if (_firepitBuilding == null) return;

    // Sahipsiz kalan yatakları serbest bırak (ölen ya da eve kavuşan köylü).
    for (final b in _reedBeds) {
      final o = b.owner;
      if (o is VillagerEntity &&
          (!_villagers.contains(o) || o.homeBuilding != null)) {
        b.owner = null;
      }
    }

    _reedScan += dt;
    if (_reedScan < _kReedScan) return;
    _reedScan = 0;

    // Gece uyku sistemi devralır; biçme/kurma yalnız gündüz.
    if (_cycle.dayLight <= 0.35) return;

    for (final v in _villagers) {
      if (!_homelessSeekingBed(v)) continue;
      if (v.isInsideBuilding ||
          v.isSleeping ||
          v.isCarrying ||
          v.sitClaimed ||
          v.activity != VillagerActivity.none) {
        continue;
      }
      // Hareket halindeyse hedefe varmasını bekle (her tarama yeni emir verme).
      if (v.state == VillagerState.moving) continue;

      // 1) Hazır sahipsiz yatak varsa onu sahiplen — yeni kurmaya gerek yok.
      final free = _firstOwnerlessBed();
      if (free != null) {
        free.owner = v;
        v.feel(NpcEmotion.content, 4, moodDelta: 0.05);
        continue;
      }

      // 2) Yeterli saz + boş slot → yatak kur. Yoksa biçmeye geç (saz birikir).
      if (_stockpile.reed >= kReedBedCost && _reedBeds.length < _kMaxReedBeds) {
        final slot = _freeBedSlot();
        if (slot != null) {
          if (_dist(v.gridX, v.gridY, slot.$1, slot.$2) < 1.4) {
            final firstBed = _reedBeds.isEmpty && !_firstReedBedShown;
            _stockpile.reed -= kReedBedCost;
            _reedBeds.add(ReedBed(gridX: slot.$1, gridY: slot.$2, owner: v));
            v.feel(NpcEmotion.content, 5, moodDelta: 0.08);
            if (firstBed) {
              _firstReedBedShown = true;
              _showNotification(
                  '🛏 İlk saz yatağı kuruldu — evsizler artık ateş başında uyuyor');
            }
          } else {
            v.goTo(slot.$1, slot.$2, 1.0);
          }
          continue;
        }
      }

      // 3) Saz biç — en yakın olgun sazlık.
      final clump = _nearestHarvestableReed(v.gridX, v.gridY);
      if (clump == null) continue; // olgun sazlık yok → bekle (regrow)
      final rx = (clump.col + clump.col2) / 2.0;
      final ry = (clump.row + clump.row2) / 2.0;
      if (_dist(v.gridX, v.gridY, rx, ry) < 1.6) {
        clump.harvest();
        _stockpile.reed += kReedYieldPerHarvest;
        v.feel(NpcEmotion.content, 3, moodDelta: 0.03);
        v.glanceAround(duration: kReedCutDuration); // kısa biçme molası
      } else {
        final spot = _freeSpotNear(rx, ry, 1.4);
        v.goTo(spot?.$1 ?? rx, spot?.$2 ?? ry, 1.0);
      }
    }
  }

  ReedBed? _firstOwnerlessBed() {
    for (final b in _reedBeds) {
      if (b.owner == null) return b;
    }
    return null;
  }

  /// Ateş etrafı ring slotlarından yatak olmayan ilk boş, geçilebilir noktayı
  /// döner.
  (double, double)? _freeBedSlot() {
    final fp = _firepitBuilding;
    if (fp == null) return null;
    final cx = fp.col + fp.cols / 2.0;
    final cy = fp.row + fp.rows / 2.0;
    for (int i = 0; i < _kMaxReedBeds; i++) {
      final ang = i * (2 * pi / _kMaxReedBeds);
      final sx = cx + cos(ang) * _kBedRing;
      final sy = cy + sin(ang) * _kBedRing;
      final c = sx.round(), r = sy.round();
      if (c < 1 || c >= kCols - 1 || r < 1 || r >= kRows - 1) continue;
      if (_obstacles.contains((c, r))) continue;
      if (_waterTiles.contains((c, r))) continue;
      final taken = _reedBeds.any((b) => _dist(b.gridX, b.gridY, sx, sy) < 0.8);
      if (taken) continue;
      return (sx, sy);
    }
    return null;
  }

  ReedClump? _nearestHarvestableReed(double x, double y) {
    ReedClump? best;
    double bestD = 1e9;
    for (final c in _reeds) {
      if (!c.harvestable) continue;
      final rx = (c.col + c.col2) / 2.0;
      final ry = (c.row + c.row2) / 2.0;
      final d = (rx - x) * (rx - x) + (ry - y) * (ry - y);
      if (d < bestD) {
        bestD = d;
        best = c;
      }
    }
    return best;
  }

  double _dist(double ax, double ay, double bx, double by) {
    final dx = ax - bx, dy = ay - by;
    return sqrt(dx * dx + dy * dy);
  }
}
