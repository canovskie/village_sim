part of '../main.dart';

/// Dünya kurulumu + uzamsal sorgular + nüfus/ev sayım helper'ları.
/// part of main.dart — State'in tüm private alanlarına erişim.
extension _SceneWorld on _VillageSceneState {
  // ── Coordinate / hit testing ────────────────────────────────────────────────

  (int, int)? _toTile(Offset pos) {
    // Ekran koordinatını zoom'suz dünya koordinatına dönüştür
    final center = Offset(_viewSize.width / 2, _viewSize.height / 2);
    final adjusted = (pos - center) / _zoom + center;
    final (fc, fr) = screenToGrid(adjusted, _viewSize, _camera);
    final c = fc.floor();
    final r = fr.floor();
    if (c >= 0 && c < kCols && r >= 0 && r < kRows) return (c, r);
    return null;
  }

  /// Ekran koordinatını SÜREKLİ (snap'siz) dünya grid koordinatına çevirir —
  /// köylü tutup-bırak sürüklemesi için (akıcı takip). Harita içindeyse (fc,fr),
  /// dışındaysa null.
  (double, double)? _toWorld(Offset pos) {
    final center = Offset(_viewSize.width / 2, _viewSize.height / 2);
    final adjusted = (pos - center) / _zoom + center;
    final (fc, fr) = screenToGrid(adjusted, _viewSize, _camera);
    if (fc >= 0 && fc < kCols && fr >= 0 && fr < kRows) return (fc, fr);
    return null;
  }

  BuildingEntity? _buildingAt(int col, int row) {
    for (final b in _buildings) {
      if (col >= b.col &&
          col < b.col + b.cols &&
          row >= b.row &&
          row < b.row + b.rows) {
        return b;
      }
    }
    return null;
  }

  /// Tile merkezine en yakın görünür köylüyü döndür (mesafe < 0.7 tile).
  /// Bina içindeyse veya çok uzaksa null. Tıklama hedefi olarak kullanılır.
  VillagerEntity? _villagerAt(int col, int row) {
    final cx = col + 0.5;
    final cy = row + 0.5;
    VillagerEntity? best;
    double bestD2 = 0.49; // 0.7² eşik
    for (final v in _villagers) {
      if (v.isInsideBuilding) continue;
      final dx = v.gridX - cx;
      final dy = v.gridY - cy;
      final d2 = dx * dx + dy * dy;
      if (d2 < bestD2) {
        bestD2 = d2;
        best = v;
      }
    }
    return best;
  }

  /// Su üzerindeki tüm entity'leri en yakın kuru tile'a taşır.
  /// Verilen pozisyona en yakın su-olmayan tile'ı spiral aramayla bulur.
  (double, double) _nearestLand(double gx, double gy) {
    bool blocked(int c, int r) =>
        _waterTiles.contains((c, r)) || _wilderness.contains((c, r));
    final c0 = gx.round();
    final r0 = gy.round();
    if (!blocked(c0, r0)) return (gx, gy);
    for (int radius = 1; radius < 16; radius++) {
      for (int dc = -radius; dc <= radius; dc++) {
        for (int dr = -radius; dr <= radius; dr++) {
          if (dc.abs() != radius && dr.abs() != radius) {
            continue; // sadece dış halka
          }
          final nc = (c0 + dc).clamp(0, kCols - 1);
          final nr = (r0 + dr).clamp(0, kRows - 1);
          if (!blocked(nc, nr)) {
            return (nc.toDouble(), nr.toDouble());
          }
        }
      }
    }
    return (gx, gy); // fallback (olmamalı)
  }

  // ── Nüfus & ev kapasitesi ──────────────────────────────────────────────────

  /// Ev binalarındaki boş sakin kapasitesinin toplamı.
  int _freeHousingSlots() {
    int free = 0;
    for (final b in _buildings) {
      final f = b.fn;
      if (f == null || f.role != BuildingRole.housing) continue;
      // PERF: occupants her tick başında _tickPopulationAndHunger'da tazelenir
      // → her ev için _villagers'ı yeniden taramak yerine onu kullan (O(n×m)→O(n)).
      final slots = f.housingCapacity - b.occupants;
      if (slots > 0) free += slots;
    }
    return free;
  }

  /// Köyün ev tavanı — tüm evlerin sakin kapasitesi toplamı.
  int _populationCap() {
    int cap = 0;
    for (final b in _buildings) {
      final f = b.fn;
      if (f != null && f.role == BuildingRole.housing) cap += f.housingCapacity;
    }
    return cap;
  }

  /// Rastgele doğal ömür (oyun günü) — yaşlı evresinden sonra biraz daha yaşar.
  double _rollLifespan() =>
      kElderStartDay +
      kElderLifeMin +
      _rng.nextDouble() * (kElderLifeMax - kElderLifeMin);

  // ── Spatial cache ──────────────────────────────────────────────────────────

  /// Yavaş değişen engel/kuyu/yasak set'lerini yeniden doldurur. Container'lar
  /// yeniden tahsis edilmez (clear + refill) — frame başına GC baskısını keser.
  void _rebuildSpatialCaches() {
    _obstacles.clear();
    // Su tile engel sayılır ama üstünde köprü varsa NPC geçebilir.
    for (final t in _waterTiles) {
      if (!_roadSystem.hasBridgeAt(t.$1, t.$2)) _obstacles.add(t);
    }
    // Vahşi orman: yoğun ağaç duvarı — NPC giremez, oraya inşa edilemez.
    // (Sınır ağacı tile'ları da _wilderness içinde olduğundan otomatik engel.)
    _obstacles.addAll(_wilderness);
    for (final n in _mineNodes) {
      if (!n.isDepleted) _obstacles.add((n.col, n.row));
    }
    // Solid binalar — BuildingMeta.walkable=false olanlar NPC engel sayar.
    // (walkable: firepit, well, lamppost, woodenHouse — etrafında/içinde
    // dolaşılanlar). Pending order'lar engel SAYILMAZ — builder içine girmeli.
    for (final b in _buildings) {
      final meta = kBuildingMeta[b.type];
      if (meta == null || meta.walkable) continue;
      for (int c = b.col; c < b.col + meta.cols; c++) {
        for (int r = b.row; r < b.row + meta.rows; r++) {
          _obstacles.add((c, r));
        }
      }
    }

    _softObs.clear();
    for (final r in _reeds) {
      _softObs.add((r.col, r.row));
      _softObs.add((r.col2, r.row2));
    }

    _forbiddenForTrees.clear();
    for (final t in _farmTiles) {
      _forbiddenForTrees.add((t.col, t.row));
    }
    for (final b in _buildings) {
      for (int c = b.col; c < b.col + b.cols; c++) {
        for (int r = b.row; r < b.row + b.rows; r++) {
          _forbiddenForTrees.add((c, r));
        }
      }
    }
    // Yollar — oduncu yol tile'ına ağaç dikmesin. Lamba zaten bina footprint
    // içinde (1×1 bina), ek kontrol gerek değil.
    for (final t in _roadSystem.all) {
      _forbiddenForTrees.add((t.col, t.row));
    }
    // Pending inşaat orderları — yere bir bina düşecek, oraya ağaç dikme.
    for (final o in _orders) {
      if (o.completed) continue;
      final m = kBuildingMeta[o.type]!;
      for (int c = o.col; c < o.col + m.cols; c++) {
        for (int r = o.row; r < o.row + m.rows; r++) {
          _forbiddenForTrees.add((c, r));
        }
      }
    }
    // Sazlıklar — kıyı bitkisi, ağaç dikilmesin (görsel çakışma).
    for (final r in _reeds) {
      _forbiddenForTrees.add((r.col, r.row));
      _forbiddenForTrees.add((r.col2, r.row2));
    }

    // Squeeze tile'ları: walkable ama karşılıklı (N+S ya da E+W) komşuları
    // engelli → 1-tile genişlikte koridor. Bina kümesinin arasında kalan
    // dar geçitlere NPC sıkışmasın diye pathfinder'a yüksek cost olarak verilir.
    // Sadece bina engelleri etrafında oluşan koridorlar hedef; su komşuluğu
    // doğal kıyıda fazla penaltı yaratmasın diye dahil edilse de etkisi az
    // (NPC zaten kıyıdan kaçınır separation + idleWander su check).
    _squeezeTiles.clear();
    for (int c = 0; c < kCols; c++) {
      for (int r = 0; r < kRows; r++) {
        if (_obstacles.contains((c, r))) continue; // zaten bloke
        final n = _obstacles.contains((c, r - 1));
        final s = _obstacles.contains((c, r + 1));
        final e = _obstacles.contains((c + 1, r));
        final w = _obstacles.contains((c - 1, r));
        if ((n && s) || (e && w)) {
          _squeezeTiles.add((c, r));
        }
      }
    }
  }

  // ── World generation ───────────────────────────────────────────────────────

  void _generateWorld({int? forceSeed}) {
    _worldSeed = forceSeed ?? Random().nextInt(0x7FFFFFFF);
    final result = WorldGenerator(_worldSeed).generate();

    _waterTiles.clear();
    _lotuses.clear();
    _reeds.clear();
    _reedBeds.clear();
    _decor.clear();
    _trees.clear();
    _mineNodes.clear();
    _buildings.clear();
    _orders.clear();
    _roadOrders.clear();
    _roadSystem.clear();
    _placingRoad = null;
    _roadStrokeTiles.clear();
    _pathContext.bumpVersion(); // yeni harita → tüm cached path'ler iptal
    _anchorSystem.rebuild(const []); // tüm slot rezervasyonlarını sil
    _lumberCamps.clear();
    _miners.clear();
    _fishers.clear();
    _florists.clear();
    _shepherds.clear();
    _cows.clear();
    _farmers.clear();
    _woodcutters.clear();
    _builders.clear();
    _villagers.clear();
    _resourceBoxes.clear();
    _eggs.clear();
    _hayEntities.clear();
    _birdFlocks.clear();
    _beeSwarms.clear();
    _pendingPetition = null;
    _petitionModalOpen = false;
    _petitionForced = false;
    _petitionTimer = 1.0 * kGameDaySeconds;
    _petitionDeadline = 0;
    _petitionFollowUps.clear();
    _petitionCooldowns.clear();
    _villageMemory.clear();
    _divanOpen = false;
    _councilSession = null;
    _councilSpeaker = null;
    _councilCooldownUntil = 0;
    _governanceLegacy = 0;

    _stockpile.clear();
    // Başlangıç kaynak paketi — oyuncunun erken oyun sıkışmaması için.
    // Ateş yeri ücretsiz; sonrasında oduncu kulübesi (12 odun) veya bir ev
    // (18 odun + 4 taş) ya da kuyu (4 odun + 8 taş) kurabilir.
    // 25/15/25: ilk 1-2 binayı kurmak + ilk günü atlatmak için yeterli.
    _stockpile.wood = 25;
    _stockpile.stone = 15;
    _stockpile.food = 25;
    _hasFire = false;
    _firepitBuilding = null;
    _selectedBuilding = null;

    // Kilometre taşı bayrakları
    _lastPopMilestone = 0;
    _firstReedBedShown = false;
    // Olay & gün durumunu sıfırla
    _eventTimer = kEventFirstDelay;
    _eventMorale = 0.0;
    _eventMoraleLeft = 0.0;
    _eventLabel = null;
    _activeEvent = null;
    _activeEventLeft = 0.0;
    _pendingChoice = null;
    _activeFx.clear();
    _completedQuests.clear();
    _charterTier = 0;
    _flowScan = 0;
    _foodHunger = 0.0;
    _dayCount = 1;
    _lastTimeOfDay = _cycle.timeOfDay;
    _spatialTimer =
        0.0; // yeni harita → spatial cache'i ilk tick'te yeniden kur

    // Köylülerin ev/uyku atamalarını sıfırla
    for (final v in _villagers) {
      v.homeBuilding = null;
      v.sleepTarget = null;
      v.sleepIsHome = false;
      v.isInsideBuilding = false;
    }

    _waterTiles.addAll(result.waterTiles);
    _lotuses.addAll(result.lotuses);
    _reeds.addAll(result.reeds);
    _decor.addAll(result.decor);
    _trees.addAll(result.trees);
    _mineNodes.addAll(result.mineNodes);

    // Arazi: merkezde açıklık aç, gen ormanını yoğun vahşi ormanla değiştir,
    // sınır halkasına kesilebilir ağaçları diz. _trees'i yeniden kurar.
    _initLand();

    // Yeni map → ground picture cache invalid.
    _groundVersion++;

    _fixNpcSpawns();
  }
}
