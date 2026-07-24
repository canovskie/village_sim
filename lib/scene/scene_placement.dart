part of '../main.dart';

/// Bina yerleştirme + alan-seçim (maden/oduncu/tarla) commit + yol tile paint.
/// part of main.dart — State'in tüm private alanlarına erişim.
extension _ScenePlacement on _VillageSceneState {
  /// Geçerli mi — `_placementReason` null dönerse evet (tek doğruluk kaynağı).
  bool _isValidPlacement(int col, int row, BuildingType type) =>
      _placementReason(col, row, type) == null;

  /// Köy bu binanın zanaatını biliyor mu? Ortak bilgi (craft == null) hep açık;
  /// godMode her şeyi açar (dev/showcase). Menü filtresi + kilit mesajı bunu okur.
  bool _isCraftKnown(BuildingType type) {
    if (_godMode) return true;
    final craft = kBuildingCraft[type];
    return craft == null || _knownCrafts.contains(craft);
  }

  /// Yerleştirme neden GEÇERSİZ — geçerliyse null, değilse oyuncuya gösterilecek
  /// Türkçe sebep (akıllı yerleştirme ipucu). `_isValidPlacement` bunu kullanır,
  /// böylece doğrulama mantığı ile mesaj asla ayrışmaz.
  String? _placementReason(int col, int row, BuildingType type) {
    final meta = kBuildingMeta[type]!;
    // Zanaat kilidi (tek doğruluk kaynağı → hem menü hem commit hem ipucu):
    // köy bu yapının zanaatını bilmiyorsa dikilemez.
    if (!_isCraftKnown(type)) {
      final craft = kBuildingCraft[type];
      return craft != null
          ? '${Craft.displayName(craft)} köyde henüz bilinmiyor'
          : 'Bu zanaat köyde henüz bilinmiyor';
    }
    if (col < 0 ||
        row < 0 ||
        col + meta.cols > kCols ||
        row + meta.rows > kRows) {
      return 'Harita sınırının dışında';
    }
    bool overlaps(int c1, int r1, int w1, int h1, int c2, int r2, int w2,
            int h2) =>
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

    // Footprint engel taraması — ilk çakışmanın sebebini döner (null = temiz).
    String? footObstacle() {
      for (int c = col; c < col + meta.cols; c++) {
        for (int r = row; r < row + meta.rows; r++) {
          if (_waterTiles.contains((c, r))) return 'Suyun üzerine kurulamaz';
          if (_wilderness.contains((c, r))) {
            return 'Vahşi orman — önce ağaçları temizleyin';
          }
          if (farmSet.contains((c, r))) return 'Tarlanın üzerine kurulamaz';
          if (treeSet.contains((c, r))) return 'Ağacın üzerine kurulamaz';
          if (reedSet.contains((c, r))) return 'Sazlığın üzerine kurulamaz';
          if (mineSet.contains((c, r))) {
            return 'Maden damarının üzerine kurulamaz';
          }
        }
      }
      return null;
    }

    // ── Maden Ocağı: maden damarı ÜZERİNE kurulmalı ──────────────────────────
    if (type == BuildingType.mineBuilding) {
      bool hasMine = false;
      for (int c = col; c < col + meta.cols; c++) {
        for (int r = row; r < row + meta.rows; r++) {
          if (_waterTiles.contains((c, r))) return 'Suyun üzerine kurulamaz';
          if (farmSet.contains((c, r))) return 'Tarlanın üzerine kurulamaz';
          if (treeSet.contains((c, r))) return 'Ağacın üzerine kurulamaz';
          if (reedSet.contains((c, r))) return 'Sazlığın üzerine kurulamaz';
          if (mineSet.contains((c, r))) hasMine = true;
        }
      }
      if (!hasMine) return 'Maden ocağı bir maden damarının üzerine kurulmalı';
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
      if (!hasTree) return 'Yakında ağaç yok — ormana yakın kur';
      final obs = footObstacle();
      if (obs != null) return obs;
    }
    // ── Normal binalar ──────────────────────────────────────────────────────
    else {
      final obs = footObstacle();
      if (obs != null) return obs;
    }

    for (final b in _buildings) {
      if (overlaps(col, row, meta.cols, meta.rows, b.col, b.row, b.cols,
          b.rows)) {
        return 'Başka bir binanın üzerine gelemez';
      }
    }
    for (final o in _orders) {
      final om = kBuildingMeta[o.type]!;
      if (overlaps(col, row, meta.cols, meta.rows, o.col, o.row, om.cols,
          om.rows)) {
        return 'Süren bir inşaatın üzerine gelemez';
      }
    }
    return null;
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
          if (!existing.contains((c, r)) &&
              !_waterTiles.contains((c, r)) &&
              !_isWilderness(c, r)) {
            _farmTiles.add(FarmTile(c, r));
          }
        }
      }
      _farmMode = false;
      _farmStart = null;
      _farmEnd = null;
    });
    // Tarla çizmek ARTIK çiftçi doğurmaz — saha eli sayısı köyün çiftçi
    // kadrosundan + işgücü politikasından türer (_syncFarmerWorkforce, tick).
  }

  /// Tek tık yerleştirme: bir bina kur, ardından seçimi BIRAK. Çoklu dikim
  /// yalnız basılı-tut (long-press) ile yapılır → _onCanvasLongPress* akışı.
  void _tryPlace(Offset pos) {
    if (_placing == null) return;
    // Sinematik sonrası kısa kilit: "ilerle" için atılan artçı dokunuş ateşi
    // kazara kurmasın (oyuncu yeri bilinçli seçsin).
    if (_time < _placeGuardUntil) return;
    final tile = _toTile(pos);
    if (tile == null) return;
    final placed = _doPlace(tile.$1, tile.$2, silent: false);
    // Başarılı tek tık → kartı bırak (palete dön). Ateş zaten _doPlace içinde
    // seçimi bırakır; başarısız denemede seçili kalır (oyuncu tekrar denesin).
    if (placed && _placing != null) {
      setStateHere(() {
        _placing = null;
        _ghost = null;
        _placeReason = null;
      });
    }
  }

  /// Yerleştirme çekirdeği — validasyon + cost + bina/order. Başarıyı döner.
  /// [silent] true ise bildirim basmaz (çoklu dikim stroke'unda spam önler).
  /// Seçimi (_placing) BIRAKMAZ — onu çağıran (tek tık / long-press bitişi)
  /// yönetir; tek istisna ateş yeri (tekil → kurulunca burada bırakılır).
  bool _doPlace(int c, int r, {required bool silent}) {
    if (_placing == null) return false;
    // Ateş yeri köyün kalbi → TEKİLDİR; bir tane varken ikincisi kurulamaz.
    // Bu aynı zamanda olası çift-tetik (tek dokunuşun hem tap hem long-press
    // olarak çözülmesi) durumunda ikinci yerleştirme + ikinci "ateş yakma"
    // sinematiğine karşı sigortadır.
    if (_placing == BuildingType.firepit && _hasFire) return false;
    // Akıllı yerleştirme: geçersizse JENERİK değil SOMUT sebep göster.
    final reason = _placementReason(c, r, _placing!);
    if (reason != null) {
      if (!silent) _showNotification('🚫 $reason');
      return false;
    }
    final cost = kBuildingMeta[_placing!]!.cost;
    if (!_stockpile.canAfford(cost)) {
      if (!silent) {
        _showNotification('Eksik malzeme: ${_stockpile.formatMissing(cost)}');
      }
      return false;
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

      // Ateş tekildir → kurulunca seçim hemen bırakılır.
      if (isFirepit) _placing = null;
      _ghost = null;
      _placeReason = null;
    });
    if (!silent) {
      _showNotification(
        isFirepit
            ? 'Ateş yakıldı!'
            : (_godMode
                ? 'Bina anında kuruldu (godmode)'
                : 'İnşaatçı yola çıkıyor...'),
      );
    }
    return true;
  }

  /// Binayı söker — [refund] oranında kaynak iade eder, bağlı işçi/sakin/
  /// hayvanları temizler, global sistemleri (anchor/arı/pathfinding) yeniden
  /// kurar. [reselect] true ise (Taşı) aynı türü yeniden yerleştirmeye sokar
  /// (tam iade + tekrar koy = bedava taşıma). Ateş yeri köyün kalbi → yıkılamaz.
  void _demolishBuilding(BuildingEntity b, {double refund = 0.5, bool reselect = false}) {
    if (b.type == BuildingType.firepit) {
      _showNotification('🔥 Ateş yeri köyün kalbidir. Sökülmez.');
      return;
    }
    final meta = kBuildingMeta[b.type];
    setStateHere(() {
      // Kaynak iadesi (aşağı yuvarla).
      if (meta != null && refund > 0) {
        for (final (kind, amt) in meta.cost.entries) {
          final back = (amt * refund).floor();
          if (back > 0) _stockpile.add(kind, back);
        }
      }
      // Sakinleri evsiz bırak (homeBuilding bu bina ise).
      for (final v in _villagers) {
        if (identical(v.homeBuilding, b)) v.homeBuilding = null;
      }
      // Binaya bağlı işçi/varlıklar — pozisyon referanslarıyla eşleştir.
      _lumberCamps
          .removeWhere((lc) => lc.buildingCol == b.col && lc.buildingRow == b.row);
      _florists
          .removeWhere((f) => f.cottageCol == b.col && f.cottageRow == b.row);
      _shepherds.removeWhere((s) => s.barnCol == b.col && s.barnRow == b.row);
      _cows.removeWhere((c) => c.barnCol == b.col && c.barnRow == b.row);
      // Maden/balıkçı işçileri bina ref tutmaz → footprint yakınından temizle.
      bool nearFoot(double x, double y) =>
          x >= b.col - 1 &&
          x < b.col + b.cols + 1 &&
          y >= b.row - 1 &&
          y < b.row + b.rows + 2;
      if (b.type == BuildingType.mineBuilding) {
        _miners.removeWhere((m) => nearFoot(m.gridX, m.gridY));
        for (final n in _mineNodes) {
          if (n.col >= b.col &&
              n.col < b.col + b.cols &&
              n.row >= b.row &&
              n.row < b.row + b.rows) {
            n.isMarkedForMining = false;
          }
        }
      } else if (b.type == BuildingType.fisherCabin) {
        _removeNearestFisher(b);
      }
      // Binayı kaldır + seçimi temizle.
      _buildings.remove(b);
      if (identical(_firepitBuilding, b)) _firepitBuilding = null;
      _selectedBuilding = null;
      // Global yeniden kurma — yerleştirmedeki gibi (anchor/arı/pathfinding).
      _pathContext.bumpVersion();
      _anchorSystem.rebuild(_buildings);
      _rebuildBeeSwarms();
      // Taşı: aynı türü yeniden seçili getir + o kategoriyi aç.
      if (reselect) {
        _placing = b.type;
        _ghost = null;
        _placeReason = null;
        _buildCategory = kBuildingCategory[b.type] ?? _buildCategory;
      }
    });
    _showNotification(reselect
        ? '✋ ${meta?.label ?? 'Bina'} taşınıyor — yeni yerini seç (malzeme iade edildi).'
        : '🔨 ${meta?.label ?? 'Bina'} yıkıldı — malzemenin %${(refund * 100).round()}\'i geri alındı.');
  }

  /// Bir binaya en yakın balıkçıyı kaldırır (balıkçı bina ref tutmaz; kabin o
  /// binadan doğmuştu). Birden çok kabin varsa yanlış birini alabilir — kabul
  /// edilebilir kenar durum.
  void _removeNearestFisher(BuildingEntity b) {
    if (_fishers.isEmpty) return;
    final cx = b.col + b.cols / 2.0;
    final cy = b.row + b.rows / 2.0;
    FisherEntity? best;
    double bestD = double.infinity;
    for (final f in _fishers) {
      final dx = f.gridX - cx;
      final dy = f.gridY - cy;
      final d = dx * dx + dy * dy;
      if (d < bestD) {
        bestD = d;
        best = f;
      }
    }
    if (best != null) _fishers.remove(best);
  }

  /// Drag-paint döşeme: tek bir tile için validasyon + cost + order.
  /// Sessiz fail (sürükleme akışı bozulmasın) — sadece geçerli + ödenebilen
  /// tile'lara order eklenir.
  void _paintRoadTile(int c, int r) {
    if (_placingRoad == null) return;
    if (_isWilderness(c, r)) return; // vahşi ormana yol döşenmez
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
