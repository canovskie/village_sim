part of '../main.dart';

/// Bina yerleştirme + alan-seçim (maden/oduncu/tarla) commit + yol tile paint.
/// part of main.dart — State'in tüm private alanlarına erişim.
extension _ScenePlacement on _VillageSceneState {
  bool _isValidPlacement(int col, int row, BuildingType type) {
    final meta = kBuildingMeta[type]!;
    if (col + meta.cols > kCols || row + meta.rows > kRows) return false;
    bool overlaps(int c1, int r1, int w1, int h1,
                  int c2, int r2, int w2, int h2) =>
        c1 < c2 + w2 && c1 + w1 > c2 && r1 < r2 + h2 && r1 + h1 > r2;

    final farmSet = {for (final t in _farmTiles) (t.col, t.row)};
    final mineSet = {
      for (final n in _mineNodes)
        if (!n.isDepleted) (n.col, n.row),
    };
    final treeSet = {
      for (final t in _trees)
        if (!t.isFelled) (t.col, t.row),
    };
    final reedSet = <(int, int)>{
      for (final r in _reeds) ...[
        (r.col, r.row),
        (r.col2, r.row2),
      ],
    };

    // ── Maden Ocağı: maden tile'ı üzerine kurulmalı ──────────────────────────
    if (type == BuildingType.mineBuilding) {
      bool hasMine = false;
      for (int c = col; c < col + meta.cols; c++) {
        for (int r = row; r < row + meta.rows; r++) {
          if (_waterTiles.contains((c, r))) return false;
          if (farmSet.contains((c, r))) return false;
          if (treeSet.contains((c, r))) return false;
          if (reedSet.contains((c, r))) return false;
          if (mineSet.contains((c, r))) hasMine = true;
        }
      }
      if (!hasMine) return false;
    }
    // ── Oduncu Kulübesi: yakında ağaç olmalı (ama üstüne kurulamaz) ─────────
    else if (type == BuildingType.lumberCamp) {
      final cx = col + meta.cols / 2.0;
      final cy = row + meta.rows / 2.0;
      const radius = LumberCampEntity.kTerritoryRadius;
      bool hasTree = false;
      for (final t in _trees) {
        if (t.isFelled) continue;
        final dx = t.col + 0.5 - cx;
        final dy = t.row + 0.5 - cy;
        if (dx * dx + dy * dy <= radius * radius) {
          hasTree = true;
          break;
        }
      }
      if (!hasTree) return false;
      for (int c = col; c < col + meta.cols; c++) {
        for (int r = row; r < row + meta.rows; r++) {
          if (_waterTiles.contains((c, r))) return false;
          if (farmSet.contains((c, r))) return false;
          if (treeSet.contains((c, r))) return false;
          if (reedSet.contains((c, r))) return false;
          if (mineSet.contains((c, r))) return false;
        }
      }
    }
    // ── Normal binalar ──────────────────────────────────────────────────────
    else {
      for (int c = col; c < col + meta.cols; c++) {
        for (int r = row; r < row + meta.rows; r++) {
          if (_waterTiles.contains((c, r))) return false;
          if (farmSet.contains((c, r))) return false;
          if (treeSet.contains((c, r))) return false;
          if (reedSet.contains((c, r))) return false;
          if (mineSet.contains((c, r))) return false;
        }
      }
    }

    for (final b in _buildings) {
      if (overlaps(col, row, meta.cols, meta.rows,
                   b.col, b.row, b.cols, b.rows)) {
        return false;
      }
    }
    for (final o in _orders) {
      final om = kBuildingMeta[o.type]!;
      if (overlaps(col, row, meta.cols, meta.rows,
                   o.col, o.row, om.cols, om.rows)) {
        return false;
      }
    }
    return true;
  }

  void _commitMine((int, int) start, (int, int) end) {
    final c1 = start.$1 < end.$1 ? start.$1 : end.$1;
    final c2 = start.$1 < end.$1 ? end.$1 : start.$1;
    final r1 = start.$2 < end.$2 ? start.$2 : end.$2;
    final r2 = start.$2 < end.$2 ? end.$2 : start.$2;
    int marked = 0;
    setStateHere(() {
      for (final n in _mineNodes) {
        if (n.col >= c1 && n.col <= c2 && n.row >= r1 && n.row <= r2) {
          if (!n.isMarkedForMining && !n.isDepleted) {
            n.isMarkedForMining = true;
            marked++;
          }
        }
      }
      _mineMode = false;
      _mineStart = null;
      _mineEnd = null;
    });
    if (marked > 0) {
      _showNotification('$marked maden işaretlendi!');
    } else {
      _showNotification('Seçilen alanda maden yok.');
    }
  }

  void _commitLumber((int, int) start, (int, int) end) {
    final c1 = start.$1 < end.$1 ? start.$1 : end.$1;
    final c2 = start.$1 < end.$1 ? end.$1 : start.$1;
    final r1 = start.$2 < end.$2 ? start.$2 : end.$2;
    final r2 = start.$2 < end.$2 ? end.$2 : start.$2;
    int marked = 0;
    int reedsCut = 0;
    int reedHay  = 0;
    setStateHere(() {
      for (final t in _trees) {
        if (t.col >= c1 && t.col <= c2 && t.row >= r1 && t.row <= r2) {
          if (!t.isMarkedForCutting && !t.isFelled) {
            t.isMarkedForCutting = true;
            marked++;
          }
        }
      }
      final newReeds = <ReedClump>[];
      for (final rd in _reeds) {
        final inA = rd.col  >= c1 && rd.col  <= c2 && rd.row  >= r1 && rd.row  <= r2;
        final inB = rd.col2 >= c1 && rd.col2 <= c2 && rd.row2 >= r1 && rd.row2 <= r2;
        if (inA || inB) {
          reedsCut++;
          for (final (rc, rr) in [(rd.col, rd.row), (rd.col2, rd.row2)]) {
            final hay = HayEntity(
              type: HayType.pile,
              gridX: rc.toDouble(),
              gridY: rr.toDouble(),
            );
            ResourcePlacement.placeHay(
                hay, rc.toDouble(), rr.toDouble(), _hayEntities, _time);
            _hayEntities.add(hay);
            reedHay++;
          }
        } else {
          newReeds.add(rd);
        }
      }
      if (reedsCut > 0) {
        _reeds
          ..clear()
          ..addAll(newReeds);
      }
      _lumberMode = false;
      _lumberStart = null;
      _lumberEnd = null;
    });
    final msgs = <String>[];
    if (marked   > 0) msgs.add('$marked ağaç işaretlendi');
    if (reedsCut > 0) msgs.add('$reedsCut sazlık biçildi (+$reedHay 🌾)');
    _showNotification(msgs.isEmpty
        ? 'Seçilen alanda iş yok.'
        : msgs.join(' · '));
  }

  void _commitFarm((int, int) start, (int, int) end) {
    final c1 = start.$1 < end.$1 ? start.$1 : end.$1;
    final c2 = start.$1 < end.$1 ? end.$1 : start.$1;
    final r1 = start.$2 < end.$2 ? start.$2 : end.$2;
    final r2 = start.$2 < end.$2 ? end.$2 : start.$2;
    final existing = {for (final t in _farmTiles) (t.col, t.row)};
    setStateHere(() {
      for (int c = c1; c <= c2; c++) {
        for (int r = r1; r <= r2; r++) {
          if (!existing.contains((c, r)) && !_waterTiles.contains((c, r))) {
            _farmTiles.add(FarmTile(c, r));
          }
        }
      }
      final needed = (_farmTiles.length / 6).ceil().clamp(1, 4);
      final centerC = (c1 + c2) / 2.0;
      final centerR = (r1 + r2) / 2.0;
      while (_farmers.length < needed) {
        final angle = _rng.nextDouble() * 2 * pi;
        _farmers.add(
          FarmFarmer(
            startCol: centerC + cos(angle) * 1.5,
            startRow: centerR + sin(angle) * 1.5,
          ),
        );
      }
      _farmMode = false;
      _farmStart = null;
      _farmEnd = null;
    });
  }

  void _tryPlace(Offset pos) {
    if (_placing == null) return;
    final tile = _toTile(pos);
    if (tile == null) return;
    final (c, r) = tile;
    if (!_isValidPlacement(c, r, _placing!)) {
      _showNotification('Bu alana inşa edilemiyor!');
      return;
    }
    final cost = kBuildingMeta[_placing!]!.cost;
    if (!_stockpile.canAfford(cost)) {
      _showNotification('Eksik malzeme: ${_stockpile.formatMissing(cost)}');
      return;
    }
    final isFirepit = _placing == BuildingType.firepit;
    // Godmode'da tüm binalar inşaatçısız anında kurulur.
    final instant = isFirepit || _godMode;
    setStateHere(() {
      _stockpile.spend(cost);

      if (instant) {
        final b = BuildingEntity(type: _placing!, col: c, row: r);
        _buildings.add(b);
        _onBuildingCompleted(
          BuildOrder(type: _placing!, col: c, row: r)..completed = true,
        );
        _pathContext.bumpVersion();
        // Anlık kurulum order completion loop'unu atlar → anchor slot'larını
        // (kuyu/ateş oturma) + arı sürülerini elle yenile.
        _anchorSystem.rebuild(_buildings);
        _rebuildBeeSwarms();
      } else {
        _orders.add(BuildOrder(type: _placing!, col: c, row: r));
      }

      _placing = null;
      _ghost = null;
    });
    _showNotification(
      isFirepit
          ? 'Ateş yakıldı!'
          : (_godMode ? 'Bina anında kuruldu (godmode)' : 'İnşaatçı yola çıkıyor...'),
    );
  }

  /// Drag-paint döşeme: tek bir tile için validasyon + cost + order.
  /// Sessiz fail (sürükleme akışı bozulmasın) — sadece geçerli + ödenebilen
  /// tile'lara order eklenir.
  void _paintRoadTile(int c, int r) {
    if (_placingRoad == null) return;
    _roadStrokeTiles.add((c, r));

    final surface = _placingRoad!;
    final bldTiles = <(int, int)>{};
    for (final b in _buildings) {
      for (int bc = b.col; bc < b.col + b.cols; bc++) {
        for (int br = b.row; br < b.row + b.rows; br++) {
          bldTiles.add((bc, br));
        }
      }
    }
    for (final o in _orders) {
      if (o.completed) continue;
      final m = kBuildingMeta[o.type]!;
      for (int bc = o.col; bc < o.col + m.cols; bc++) {
        for (int br = o.row; br < o.row + m.rows; br++) {
          bldTiles.add((bc, br));
        }
      }
    }

    if (!_roadSystem.canPlace(
      col: c, row: r,
      surface: surface,
      maxCol: kCols, maxRow: kRows,
      waterTiles: _waterTiles,
      buildingTiles: bldTiles,
    )) {
      return;
    }

    for (final o in _roadOrders) {
      if (o.col == c && o.row == r && !o.completed) return;
    }

    final cost = surface.cost;
    if (!_stockpile.canAfford(cost)) {
      _showNotification('Eksik malzeme: ${_stockpile.formatMissing(cost)}');
      return;
    }
    setStateHere(() {
      _stockpile.spend(cost);
      _roadOrders.add(RoadOrder(col: c, row: r, surface: surface));
    });
    _frame.value = _frame.value + 1;
  }
}
