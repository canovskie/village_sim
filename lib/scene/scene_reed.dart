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
  static const double _kReedScan = 0.5;
  static const int _kMaxReedBeds = 8;
  static const double _kBedRing = 3.0; // ateş merkezinden yatak uzaklığı

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

  /// İlk ateş yakılınca yatakları dünyaya eklemez; her kurucuya ateş çevresinde
  /// ayrı bir serim noktası ayırıp onu oraya yürütür. Yatak ancak sahibi hedefe
  /// vardığında [_tickFoundingReedBedWork] tarafından görünür olur.
  void _beginFoundingReedBedWork() {
    if (_firepitBuilding == null || _foundingBedTargets.isNotEmpty) return;
    for (final v in _villagers) {
      if (v.isDying || v.homeBuilding != null || _villagerHasBed(v)) continue;
      if (_reedBeds.length + _foundingBedTargets.length >= _kMaxReedBeds) {
        break;
      }
      final slot = _freeBedSlot();
      if (slot == null) break;
      _foundingBedTargets[v] = slot;
      v.cancelSit();
      v.goTo(slot.$1, slot.$2, 3.0);
    }
    if (_foundingBedTargets.isEmpty) return;
    _showNotification(
      '🛏 Kurucular saz yataklarını ateşin çevresine sermeye başladı.',
    );
  }

  void _tickFoundingReedBedWork() {
    if (_foundingBedTargets.isEmpty) return;
    final completed = <VillagerEntity>[];
    var bedsAdded = false;
    for (final entry in _foundingBedTargets.entries) {
      final v = entry.key;
      final slot = entry.value;
      if (!_villagers.contains(v) || v.isDying || v.homeBuilding != null) {
        completed.add(v);
        continue;
      }
      if (_dist(v.gridX, v.gridY, slot.$1, slot.$2) < 0.8) {
        // Çiçek/çakıl serime engel değildir; yatağın zemini sahiplenmesiyle
        // alçak dekor temizlenir. Fiziksel dekor slot seçiminde zaten elenir.
        _clearDecorTile(slot.$1.floor(), slot.$2.floor());
        _reedBeds.add(ReedBed(gridX: slot.$1, gridY: slot.$2, owner: v));
        bedsAdded = true;
        v.feel(NpcEmotion.content, 4.0, moodDelta: 0.05);
        v.glanceAround(duration: 1.2);
        completed.add(v);
      } else if (v.state != VillagerState.moving) {
        v.goTo(slot.$1, slot.$2, 3.0);
      }
    }
    for (final v in completed) {
      _foundingBedTargets.remove(v);
    }
    if (bedsAdded) {
      _spatialTimer = 0;
      _pathContext.bumpVersion();
    }
    if (_foundingBedTargets.isNotEmpty || _reedBeds.isEmpty) return;
    final stillWithoutBed = _villagers.any(
      (v) => !v.isDying && v.homeBuilding == null && !_villagerHasBed(v),
    );
    if (stillWithoutBed) return;
    _firstReedBedShown = true;
    _showNotification(
      '🛏 Saz yataklar hazır — ilk gece herkes kendi serdiği yatakta uyuyacak.',
    );
    _chronicle(
      'Kurucular ilk gece için saz yataklarını kendi elleriyle serdi.',
      icon: '🛏',
    );
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

    // Eve kavuşanın geçici yatağı dünyada kalmaz. Eski davranış yalnız sahibi
    // null yapıyor, her evden sonra ateş çevresinde kalıcı hasır yığını
    // bırakıyordu. Ölen sahibin yatağı ise başka bir evsize devredilebilir.
    final beforeBeds = _reedBeds.length;
    for (final b in _reedBeds) {
      final o = b.owner;
      if (o is VillagerEntity && !_villagers.contains(o)) {
        b.owner = null;
      }
    }
    final hasHomeless = _villagers.any(
      (v) => !v.isDying && v.homeBuilding == null,
    );
    _reedBeds.removeWhere((bed) {
      final owner = bed.owner;
      // Eski kayıtlarda eve geçenlerin sahibi daha önce null'a çevrilmişti;
      // ortada evsiz kalmadıysa bu sahipsiz kalıntıları da temizle.
      if (owner == null) return !hasHomeless;
      if (owner is! VillagerEntity || owner.homeBuilding == null) return false;
      if (!owner.sleepIsHome) owner.sleepTarget = null;
      return true;
    });
    if (_reedBeds.length != beforeBeds) {
      _spatialTimer = 0;
      _pathContext.bumpVersion();
    }

    // Yarım kalan kuruluş serimi (kayıttan dönüş dahil) kendini yeniden kurar.
    if (_dayCount == 1 &&
        !_completedQuests.contains('firstNight') &&
        _reedBeds.length < _villagers.where((v) => !v.isDying).length &&
        _foundingBedTargets.isEmpty) {
      _beginFoundingReedBedWork();
    }
    _tickFoundingReedBedWork();
    if (_foundingBedTargets.isNotEmpty) return;

    _reedScan += dt;
    if (_reedScan < _kReedScan) return;
    _reedScan = 0;

    // Gece uyku sistemi devralır; biçme/kurma yalnız gündüz.
    if (_cycle.dayLight <= 0.35) return;

    for (final v in _villagers) {
      // SAHİPLİK — akıl bu köylüyü geçim uğraşına verdi mi (bkz. scene_mind).
      if (!v.mind.owns(IntentKind.forage)) continue;
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
            _clearDecorTile(slot.$1.floor(), slot.$2.floor());
            _reedBeds.add(ReedBed(gridX: slot.$1, gridY: slot.$2, owner: v));
            _spatialTimer = 0;
            _pathContext.bumpVersion();
            v.feel(NpcEmotion.content, 5, moodDelta: 0.08);
            if (firstBed) {
              _firstReedBedShown = true;
              _showNotification(
                '🛏 İlk saz yatağı kuruldu — evsizler artık ateş başında uyuyor',
              );
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

  /// Yalnız kuruluşun ilk gecesi: bütün kurucular kendi saz yatağına gerçekten
  /// uzanınca uyku görüntüsünü kısa bir an göster ve şafağa sar. Gün sayacı
  /// burada bilinçli ilerletilir; çevrimin 1.0 → 0.0 sarmasını atladığımız için
  /// [_advanceWorldClock] bunu kendiliğinden göremez.
  void _tickFoundingFirstNight(double realDt) {
    if (_foundingFirstNightFastForwarded) return;

    // Eski/ilerlemiş bir köy asla sonraki gecelerden birini "ilk gece" sanmaz.
    if (_dayCount != 1 || _completedQuests.contains('firstNight')) {
      _foundingFirstNightFastForwarded = true;
      _foundingFirstNightSleepGlimpse = 0.0;
      return;
    }
    if (!_completedQuests.contains('firepit') || _villagers.isEmpty) return;

    final sleepers = _villagers.where((v) => !v.isDying).toList();
    final everyoneOnOwnReedBed =
        sleepers.isNotEmpty &&
        sleepers.every((v) {
          final bed = _bedOf(v);
          if (bed == null || v.sleepIsHome || !v.isSleeping) return false;
          return _dist(v.gridX, v.gridY, bed.gridX, bed.gridY) < 0.7;
        });
    if (!everyoneOnOwnReedBed) {
      _foundingFirstNightSleepGlimpse = 0.0;
      return;
    }

    // Yüksek oyun hızında bile en azından kısa, gerçek-zamanlı bir uyku karesi
    // görülsün. Arka plandan dönülen dev bir frame tek başına geceyi atlamasın.
    _foundingFirstNightSleepGlimpse += realDt.clamp(0.0, 0.1);
    if (_foundingFirstNightSleepGlimpse < 1.0) return;

    _foundingFirstNightFastForwarded = true;
    _foundingFirstNightSleepGlimpse = 0.0;
    _dayCount++;
    _applyLawUpkeep();
    _cycle.skipNightToMorning();
    _lastTimeOfDay = _cycle.timeOfDay;
    AudioManager.instance.playSfx(Sfx.roosterCrow);
    _easeToBaseSpeed();
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
    // Oyuncu ateşi sık bir noktaya koymuş olabilir. Yakın halka doluysa bir
    // dış halkaya geç; altı kurucunun yatağı tek bir ağaca takılıp eksilmesin.
    for (final radius in [_kBedRing, _kBedRing + 1.25]) {
      for (int i = 0; i < _kMaxReedBeds; i++) {
        final ang = i * (2 * pi / _kMaxReedBeds);
        final sx = cx + cos(ang) * radius;
        final sy = cy + sin(ang) * radius;
        final c = sx.round(), r = sy.round();
        final decorC = sx.floor(), decorR = sy.floor();
        if (c < 1 || c >= kCols - 1 || r < 1 || r >= kRows - 1) continue;
        if (_obstacles.contains((c, r))) continue;
        if (_waterTiles.contains((c, r))) continue;
        // Çiçek/mantar/çakıl slotu bloke etmez; yatak serilirken temizlenir.
        // Yalnız gerçekten hacimli doğal obje başka bir yer aratır.
        if (_decor.any(
          (d) =>
              d.col == decorC && d.row == decorR && isBlockingDecorKind(d.kind),
        )) {
          continue;
        }
        if (_trees.any((t) => t.col == c && t.row == r && !t.isFelled)) {
          continue;
        }
        if (_mineNodes.any((m) => m.col == c && m.row == r && !m.isDepleted)) {
          continue;
        }
        if (_farmTiles.any((f) => f.col == c && f.row == r)) continue;
        if (_resourceBoxes.any(
          (b) => b.gridX.round() == c && b.gridY.round() == r && !b.isDelivered,
        )) {
          continue;
        }
        if (_hayEntities.any(
          (h) => h.gridX.round() == c && h.gridY.round() == r && !h.isDelivered,
        )) {
          continue;
        }
        final taken =
            _reedBeds.any((b) => _dist(b.gridX, b.gridY, sx, sy) < 0.8) ||
            _foundingBedTargets.values.any(
              (target) => _dist(target.$1, target.$2, sx, sy) < 0.8,
            );
        if (taken) continue;
        return (sx, sy);
      }
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
