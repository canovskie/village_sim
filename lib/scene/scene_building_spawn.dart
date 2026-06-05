part of '../main.dart';

/// Bina tamamlandığında ne olur + NPC spawn (başlangıç + yetişkin doğum) +
/// uyku hedefi atama + spawn pozisyon temizleme + tek-tıkla canlı köy.
/// part of main.dart — State'in tüm private alanlarına erişim.
extension _SceneBuildingSpawn on _VillageSceneState {
  void _spawnStartingNPCs(BuildingEntity firepit) {
    final cx = firepit.col + 0.5;
    final cy = firepit.row + 0.5;

    final types = [
      VillagerType.farmer,
      VillagerType.merchant,
      VillagerType.blacksmith,
      VillagerType.guard,
      VillagerType.mage,
    ];
    for (int i = 0; i < types.length; i++) {
      final angle = i * (2 * pi / types.length);
      final dist = 1.2 + _rng.nextDouble() * 0.6;
      // Kurucular yetişkin/yaşlı yaşıyla doğar — köy ilk günden işlevsel.
      final founderAge =
          kAdultStartDay + _rng.nextDouble() * (kElderStartDay - kAdultStartDay + 5);
      final male = _rng.nextBool();
      _villagers.add(
        VillagerEntity(
          type: types[i],
          name: randomVillagerName(_rng, male: male),
          male: male,
          startCol: cx + cos(angle) * dist,
          startRow: cy + sin(angle) * dist,
          ageDays: founderAge,
          lifespanDays: _rollLifespan(),
        ),
      );
    }

    // 2 inşaatçı
    for (int i = 0; i < 2; i++) {
      final angle = pi / 4 + i * pi;
      _builders.add(
        BuilderEntity(
          startCol: cx + cos(angle) * 1.8,
          startRow: cy + sin(angle) * 1.8,
        ),
      );
    }

    _fixNpcSpawns();
  }

  /// Gece: uyku hedeflerini ata. Ev varsa ev merkezi, yoksa ateş etrafı.
  void _assignSleepTargets() {
    int idx = 0;
    for (final v in _villagers) {
      if (v.homeBuilding case final home?) {
        final b = home as BuildingEntity;
        final meta = kBuildingMeta[b.type]!;
        v.sleepTarget = (b.col + meta.cols / 2.0, b.row + meta.rows / 2.0);
        v.sleepIsHome = true;
      } else if (_firepitBuilding != null) {
        final fp = _firepitBuilding!;
        final angle = idx * (2 * pi / _villagers.length);
        final dist = 1.4 + (_rng.nextDouble() * 0.7);
        v.sleepTarget = (
          fp.col + 0.5 + cos(angle) * dist,
          fp.row + 0.5 + sin(angle) * dist,
        );
        v.sleepIsHome = false;
      }
      idx++;
    }
  }

  /// Belediyenin büyüme döngüsü dolunca yeni köylü doğurur, boş eve yerleştirir.
  /// Atandığı evdeki yetişkin sakinler (max 2) ebeveyn olur, aile bağı kurulur.
  void _spawnGrownVillager(BuildingEntity townhall) {
    BuildingEntity? house;
    for (final b in _buildings) {
      final f = b.fn;
      if (f == null || f.role != BuildingRole.housing) continue;
      final occ = _villagers.where((v) => v.homeBuilding == b).length;
      if (occ < f.housingCapacity) {
        house = b;
        break;
      }
    }

    const civilianTypes = [
      VillagerType.farmer,
      VillagerType.merchant,
      VillagerType.blacksmith,
      VillagerType.guard,
      VillagerType.mage,
    ];
    final type = civilianTypes[_rng.nextInt(civilianTypes.length)];
    final (sx, sy) = _nearestLand(
      townhall.col + townhall.cols / 2.0,
      townhall.row + townhall.rows.toDouble(),
    );
    final male = _rng.nextBool();
    final v = VillagerEntity(
      type: type,
      name: randomVillagerName(_rng, male: male),
      male: male,
      startCol: sx,
      startRow: sy,
      lifespanDays: _rollLifespan(),
    );
    if (house != null) {
      v.homeBuilding = house;
      final adults = _villagers
          .where((p) =>
              p.homeBuilding == house && p.lifeStage.hasProfession)
          .toList()
        ..shuffle(_rng);
      for (final p in adults.take(2)) {
        v.parents.add(p);
        p.children.add(v);
      }
    }
    _villagers.add(v);

    final msg = v.parents.isEmpty
        ? '👶 ${v.name} doğdu!'
        : '👶 ${v.parents.map((p) => p.name).join(' & ')} ailesine ${v.name} katıldı';
    _showNotification(msg);
  }

  /// İnşaat tamamlandığında çalışır — bina tipine özel aksiyonlar.
  void _onBuildingCompleted(BuildOrder o) {
    final building = _buildings.firstWhere(
      (b) => b.col == o.col && b.row == o.row && b.type == o.type,
      orElse: () => BuildingEntity(type: o.type, col: o.col, row: o.row),
    );
    // _BuildingDrawable spawn-pop animasyonu (ilk ~0.6s scale + toz) için.
    building.spawnTime = _time;

    switch (o.type) {
      case BuildingType.firepit:
        _hasFire = true;
        _firepitBuilding = building;
        _spawnStartingNPCs(building);
        _showNotification('Ateş yakıldı! Köy kurulmaya başlıyor...');

      case BuildingType.woodenHouse:
        int assigned = 0;
        for (final v in _villagers) {
          if (assigned >= 2) break;
          if (v.homeBuilding == null) {
            v.homeBuilding = building;
            assigned++;
          }
        }
        if (assigned > 0) {
          _showNotification('$assigned köylü eve taşındı.');
        }

      case BuildingType.lumberCamp:
        _lumberCamps.add(
          LumberCampEntity(buildingCol: o.col, buildingRow: o.row),
        );

      case BuildingType.mineBuilding:
        final meta = kBuildingMeta[o.type]!;
        for (final n in _mineNodes) {
          if (n.col >= o.col &&
              n.col < o.col + meta.cols &&
              n.row >= o.row &&
              n.row < o.row + meta.rows) {
            n.isMarkedForMining = true;
          }
        }
        // Bina engel sayıldığı için spawn footprint güney kenarı dışında.
        _miners.add(
          MinerEntity(
            startCol: o.col + meta.cols / 2.0,
            startRow: o.row + meta.rows + 0.3,
          ),
        );

      case BuildingType.fisherCabin:
        // Balıkçı kulübesi (2x2): spawn footprint güneyi dışında.
        _fishers.add(
          FisherEntity(startCol: o.col + 1.0, startRow: o.row + 2.3),
        );

      case BuildingType.barn:
        // Ağıl tamamlanınca bir çoban + 3 inek spawn et. Her inek farklı,
        // footprint dışı bir slot'a — yığılma yok, bina blok'unda spawn yok.
        _shepherds.add(
          ShepherdEntity(barnCol: o.col, barnRow: o.row),
        );
        const cowOffsets = [
          (-0.6, 2.4),
          ( 1.5, 2.9),
          ( 3.6, 1.6),
        ];
        for (final (dc, dr) in cowOffsets) {
          final jx = (_rng.nextDouble() - 0.5) * 0.4;
          final jy = (_rng.nextDouble() - 0.5) * 0.4;
          _cows.add(AnimalEntity(
            kind: AnimalKind.cow,
            barnCol: o.col,
            barnRow: o.row,
            startCol: o.col + dc + jx,
            startRow: o.row + dr + jy,
          ));
        }

      default:
        break;
    }
  }

  /// NPC'leri su tile'larından kara üzerine taşı (spawn safety).
  void _fixNpcSpawns() {
    void fix(double gx, double gy, void Function(double, double) set) {
      final (nx, ny) = _nearestLand(gx, gy);
      if (nx != gx || ny != gy) set(nx, ny);
    }

    for (final v in _villagers) {
      fix(v.gridX, v.gridY, (x, y) { v.gridX = x; v.gridY = y; });
    }
    for (final f in _farmers) {
      fix(f.gridX, f.gridY, (x, y) { f.gridX = x; f.gridY = y; });
    }
    for (final w in _woodcutters) {
      fix(w.gridX, w.gridY, (x, y) { w.gridX = x; w.gridY = y; });
    }
    for (final m in _miners) {
      fix(m.gridX, m.gridY, (x, y) { m.gridX = x; m.gridY = y; });
    }
    for (final b in _builders) {
      fix(b.gridX, b.gridY, (x, y) { b.gridX = x; b.gridY = y; });
    }
    for (final f in _fishers) {
      fix(f.gridX, f.gridY, (x, y) { f.gridX = x; f.gridY = y; });
    }
  }

  /// Test: tek tıkla yaşayan köy. Yeni harita üretir, başlangıç bölgesine
  /// belirli pattern'le binaları kurar, bol kaynak verir, küçük bir tarla
  /// + çiftçi ekler. Firepit'ten 5 başlangıç NPC zaten otomatik doğar.
  void _buildLivingVillage() {
    setStateHere(() {
      _generateWorld();
      _stockpile.wood  = 200;
      _stockpile.stone = 150;
      _stockpile.iron  = 50;
      _stockpile.coal  = 30;
      _stockpile.food  = 100;
      _stockpile.gold  = 80;

      // Layout — safe area (col 0..20, row 0..16) içinde. (type, col, row).
      const layout = <(BuildingType, int, int)>[
        (BuildingType.firepit,     10, 8),
        (BuildingType.townhall,    12, 4),
        (BuildingType.woodenHouse,  4, 4),
        (BuildingType.woodenHouse,  4, 7),
        (BuildingType.woodenHouse,  4, 10),
        (BuildingType.woodenHouse,  7, 10),
        (BuildingType.tavern,       7, 4),
        (BuildingType.well,         9, 7),
        (BuildingType.warehouse,   16, 9),
        (BuildingType.lamppost,    10, 6),
        (BuildingType.lamppost,    10, 10),
      ];
      for (final (type, col, row) in layout) {
        if (!_isValidPlacement(col, row, type)) continue;
        final b = BuildingEntity(type: type, col: col, row: row);
        _buildings.add(b);
        _onBuildingCompleted(
          BuildOrder(type: type, col: col, row: row)..completed = true,
        );
      }

      // Küçük tarla + çiftçi spawn — pazarın yanına (safe area kuzeyinde).
      const farmC1 = 14, farmR1 = 2, farmC2 = 18, farmR2 = 5;
      for (int c = farmC1; c <= farmC2; c++) {
        for (int r = farmR1; r <= farmR2; r++) {
          if (_waterTiles.contains((c, r))) continue;
          bool overlap = false;
          for (final b in _buildings) {
            if (c >= b.col && c < b.col + b.cols &&
                r >= b.row && r < b.row + b.rows) {
              overlap = true; break;
            }
          }
          if (!overlap) _farmTiles.add(FarmTile(c, r));
        }
      }
      final needed = (_farmTiles.length / 6).ceil().clamp(1, 4);
      while (_farmers.length < needed) {
        final angle = _rng.nextDouble() * 2 * pi;
        _farmers.add(FarmFarmer(
          startCol: 16 + cos(angle) * 1.5,
          startRow: 3.5 + sin(angle) * 1.5,
        ));
      }
      _fixNpcSpawns();
    });
    _showNotification('🏡 Yaşayan köy kuruldu!');
  }
}
