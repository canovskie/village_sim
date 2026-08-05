part of '../main.dart';

/// Bina yerleştirme + alan-seçim (maden/oduncu/tarla) commit + yol tile paint.
/// part of main.dart — State'in tüm private alanlarına erişim.
extension _ScenePlacement on _VillageSceneState {
  /// Geçerli mi — `_placementReason` null dönerse evet (tek doğruluk kaynağı).
  ///
  /// [ignoreCraft]: yalnız FERMANLA dikilen yapı için. Bir hüküm "kurula"
  /// diyorsa köy onu diker; zanaat bilgisi oyuncu menüsünün kapısıdır, buyruğun
  /// değil. Geometri/arazi kuralları yine de tam işler.
  bool _isValidPlacement(int col, int row, BuildingType type,
          {bool ignoreCraft = false}) =>
      _placementReason(col, row, type, ignoreCraft: ignoreCraft) == null;

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
  String? _placementReason(int col, int row, BuildingType type,
      {bool ignoreCraft = false}) {
    final meta = kBuildingMeta[type]!;
    // Zanaat kilidi (tek doğruluk kaynağı → hem menü hem commit hem ipucu):
    // köy bu yapının zanaatını bilmiyorsa dikilemez.
    if (!ignoreCraft && !_isCraftKnown(type)) {
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
      const radius = kLumberTerritoryRadius;
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

  // ── İNŞA KÜNYESİ: yerin ölçümü ─────────────────────────────────────────────

  /// Hayalet yeni bir tile'a geçti — künyenin iki canlı alanını birden tazeler:
  /// geçersizlik SEBEBİ (kırmızı satır) ve yerin ÖLÇÜMÜ (ipucu tikleri). İkisi
  /// tek kapıdan geçsin ki biri güncellenip öbürü bayat kalmasın.
  void _refreshPlaceHints((int, int)? tile) {
    final type = _placing;
    if (tile == null || type == null) {
      _placeReason = null;
      _placeFacts = null;
      return;
    }
    _placeReason = _placementReason(tile.$1, tile.$2, type);
    _placeFacts = _siteFactsAt(tile.$1, tile.$2, type);
  }

  /// Hayaletin durduğu yeri ÖLÇER — künyedeki yerleşim ipuçları bu gerçeklerle
  /// canlı doğrulanır (bkz. building_lore.tipState). Burada yalnız sayım var,
  /// yorum yok: "yakın mı" kararını saf taraf verir.
  ///
  /// Yalnız hayalet TILE DEĞİŞTİRDİĞİNDE çağrılır (her karede değil) — tarama
  /// ağaç/dekor listelerini dolaştığı için ucuz ama bedava değil.
  SiteFacts _siteFactsAt(int col, int row, BuildingType type) {
    final meta = kBuildingMeta[type]!;
    final cx = col + meta.cols * 0.5;
    final cy = row + meta.rows * 0.5;
    double d2(num c, num r) {
      final dx = c + 0.5 - cx, dy = r + 0.5 - cy;
      return dx * dx + dy * dy;
    }

    // Ocağın sıcağı — çadırın kış kaderi (tek kaynak: hearth_warmth).
    final fire = _firepitBuilding;
    final warmth = _hearthWarmthAt(cx, cy);

    // Orman: oduncu bölgesi yarıçapında ayakta ağaç.
    const treeR2 = kLumberTerritoryRadius * kLumberTerritoryRadius;
    int trees = 0;
    for (final t in _trees) {
      if (t.isFelled) continue;
      if (d2(t.col, t.row) <= treeR2) trees++;
    }

    // Damar: footprint bir maden damarına oturuyor mu.
    bool onVein = false;
    for (final n in _mineNodes) {
      if (n.isDepleted) continue;
      if (n.col >= col &&
          n.col < col + meta.cols &&
          n.row >= row &&
          n.row < row + meta.rows) {
        onVein = true;
        break;
      }
    }

    // Kıyı: en yakın su tile'ı (balıkçının her sefer yürüdüğü yol).
    double? shore;
    for (final (wc, wr) in _waterTiles) {
      final dd = d2(wc, wr);
      if (shore == null || dd < shore) shore = dd;
    }
    if (shore != null) shore = sqrt(shore);

    // Çiçek: kovanın menzilindeki çiçek (bal hızının çarpanı).
    final flowerR = kBuildingMeta[BuildingType.beehive]!.effectRadius;
    final flowerR2 = flowerR * flowerR;
    int flowers = 0;
    for (final d in _decor) {
      if (d.crushed || !_isFlowerDecor(d.kind)) continue;
      if (d2(d.col, d.row) <= flowerR2) flowers++;
    }

    // Açık zemin: etki menzilinde (yoksa varsayılan 4 tile) serpilecek boşluk.
    // Ağaç/tarla ÖNCE kümeye alınır: tile başına listeyi taramak (169 tile ×
    // yüzlerce ağaç) hover'da hissedilir bir maliyet olurdu.
    final treeSet = {
      for (final t in _trees)
        if (!t.isFelled) (t.col, t.row),
    };
    final farmSet = {for (final t in _farmTiles) (t.col, t.row)};
    final openR = meta.effectRadius > 0 ? meta.effectRadius : 4.0;
    final openR2 = openR * openR;
    final rTiles = openR.ceil();
    int open = 0;
    for (int dc = -rTiles; dc <= rTiles; dc++) {
      for (int dr = -rTiles; dr <= rTiles; dr++) {
        final c = col + dc, r = row + dr;
        if (c < 0 || r < 0 || c >= kCols || r >= kRows) continue;
        // Kendi footprint'i "boşluk" sayılmaz.
        if (c >= col && c < col + meta.cols && r >= row && r < row + meta.rows) {
          continue;
        }
        if (d2(c, r) > openR2) continue;
        if (_waterTiles.contains((c, r))) continue;
        if (_isWilderness(c, r)) continue;
        if (_isOccupiedByBuilding(c, r)) continue;
        if (treeSet.contains((c, r))) continue;
        if (farmSet.contains((c, r))) continue;
        open++;
      }
    }

    // Komşuluk: üretim binaları, teslim noktaları, konutlar.
    const workR2 = kWorkNearTiles * kWorkNearTiles;
    const homeR2 = kHomesNearTiles * kHomesNearTiles;
    int work = 0, stores = 0, homes = 0;
    for (final b in _buildings) {
      final bd = d2(b.col + b.cols * 0.5 - 0.5, b.row + b.rows * 0.5 - 0.5);
      final role = b.fn?.role;
      if (bd <= workR2 &&
          (role == BuildingRole.gathering ||
              role == BuildingRole.processing)) {
        work++;
      }
      // Teslim noktası = ambar, yoksa ocak (bkz. anchor_system).
      if (bd <= workR2 &&
          (b.type == BuildingType.warehouse ||
              b.type == BuildingType.firepit)) {
        stores++;
      }
      if (bd <= homeR2 && role == BuildingRole.housing) homes++;
    }

    return SiteFacts(
      hearthWarmth: warmth,
      hasHearth: fire != null,
      hearthLit: _fireBurning,
      treesNear: trees,
      onVein: onVein,
      shoreDist: shore,
      flowersNear: flowers,
      openTilesNear: open,
      workNear: work,
      storesNear: stores,
      homesNear: homes,
    );
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
        _placeFacts = null;
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
        // Şantiye kuruldu — aletler çıkar. Bitiş sesinin (buildDone) karşılığı:
        // inşaatın başı da duyulsun, yoksa iş yalnız biterken var oluyor.
        AudioManager.instance.playSfx(Sfx.buildStart);
      }

      // Ateş tekildir → kurulunca seçim hemen bırakılır.
      if (isFirepit) _placing = null;
      _ghost = null;
      _placeReason = null;
      _placeFacts = null;
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
      // Binaya bağlı varlıklar. (İşçi avatarları kaldırıldı: işi köylüler
      // üstleniyor, bina yıkılınca _syncJobWorkforce kadroyu kendi çözer.)
      _cows.removeWhere((c) => c.barnCol == b.col && c.barnRow == b.row);
      if (b.type == BuildingType.mineBuilding) {
        for (final n in _mineNodes) {
          if (n.col >= b.col &&
              n.col < b.col + b.cols &&
              n.row >= b.row &&
              n.row < b.row + b.rows) {
            n.isMarkedForMining = false;
          }
        }
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
        _placeFacts = null;
        _buildCategory = kBuildingCategory[b.type] ?? _buildCategory;
      }
    });
    _showNotification(reselect
        ? '✋ ${meta?.label ?? 'Bina'} taşınıyor — yeni yerini seç (malzeme iade edildi).'
        : '🔨 ${meta?.label ?? 'Bina'} yıkıldı — malzemenin %${(refund * 100).round()}\'i geri alındı.');
  }

  // ── YOL: planla → önizle → döşe ────────────────────────────────────────────
  // Eski akış sürükleme sırasında her tile'ı ANINDA commit ediyordu: serbest
  // el + geri alınamaz + hiçbir önizleme. Parmağın/farenin en ufak titremesi
  // istenmeyen tile'lara yol döşüyordu ("sürekli yanlış yerlere yol yapılıyor").
  //
  // Yeni akış üç kuralla kontrolü geri veriyor:
  //   1. Sürüklerken hiçbir şey harcanmaz — yalnız önizleme çizilir.
  //   2. Güzergâh serbest el DEĞİL, dik "L": baskın eksende git, sonra köşe.
  //   3. Silgi modu var — yanlış döşenmiş yol geri alınabilir.

  /// Bina/şantiye kaplı tile'lar — yol bunların üstüne konamaz.
  Set<(int, int)> _buildingFootprintTiles() {
    final tiles = <(int, int)>{};
    for (final b in _buildings) {
      for (int bc = b.col; bc < b.col + b.cols; bc++) {
        for (int br = b.row; br < b.row + b.rows; br++) {
          tiles.add((bc, br));
        }
      }
    }
    for (final o in _orders) {
      if (o.completed) continue;
      final m = kBuildingMeta[o.type]!;
      for (int bc = o.col; bc < o.col + m.cols; bc++) {
        for (int br = o.row; br < o.row + m.rows; br++) {
          tiles.add((bc, br));
        }
      }
    }
    return tiles;
  }

  /// Sürükleme uçlarından önizlemeyi kurar — her tile için "uygulanabilir mi"
  /// bilgisiyle. Hiçbir kaynak harcanmaz; painter yeşil/kırmızı çizer.
  void _rebuildRoadPreview() {
    _roadPreview.clear();
    _roadPreviewV++;
    final a = _roadDragStart, b = _roadDragEnd;
    if (a == null || b == null) return;
    final bld = _roadErase ? const <(int, int)>{} : _buildingFootprintTiles();
    for (final (c, r) in roadRoute(a, b)) {
      _roadPreview.add(((c, r), _roadTileActionable(c, r, bld)));
    }
  }

  /// Bu tile'da seçili yol eylemi bir şey yapar mı (döşenebilir / silinebilir).
  bool _roadTileActionable(int c, int r, Set<(int, int)> bld) {
    if (c < 0 || r < 0 || c >= kCols || r >= kRows) return false;
    if (_roadErase) {
      if (_roadSystem.has(c, r)) return true;
      return _roadOrders.any((o) => o.col == c && o.row == r && !o.completed);
    }
    if (_isWilderness(c, r)) return false; // vahşi ormana yol döşenmez
    if (!_roadSystem.canPlace(
      col: c, row: r,
      surface: _placingRoad!,
      maxCol: kCols, maxRow: kRows,
      waterTiles: _waterTiles,
      buildingTiles: bld,
    )) {
      return false;
    }
    // Aynı tile'a ikinci emir düşmesin.
    return !_roadOrders.any((o) => o.col == c && o.row == r && !o.completed);
  }

  /// Önizlenen güzergâhı uygular (sürükleme bırakılınca). Kaynak İLK KEZ
  /// burada harcanır; bütçe yetmezse güzergâh yettiği yere kadar döşenir ve
  /// oyuncuya kaç tile'ın atlandığı söylenir (sessizce yarım kalmaz).
  void _commitRoadPreview() {
    if (_roadPreview.isEmpty) {
      setStateHere(_clearRoadDrag);
      return;
    }
    if (_roadErase) {
      _commitRoadErase();
      return;
    }
    final surface = _placingRoad!;
    final cost = surface.cost;
    int laid = 0, skipped = 0, broke = 0;
    setStateHere(() {
      for (final (tile, ok) in _roadPreview) {
        if (!ok) {
          skipped++;
          continue;
        }
        if (!_stockpile.canAfford(cost)) {
          broke++;
          continue;
        }
        _stockpile.spend(cost);
        _roadOrders.add(RoadOrder(col: tile.$1, row: tile.$2, surface: surface));
        laid++;
      }
      _clearRoadDrag();
    });
    final parts = <String>[];
    if (laid > 0) parts.add('$laid tile yol emri verildi');
    if (broke > 0) parts.add('$broke tile malzeme yetmedi');
    if (skipped > 0 && laid == 0 && broke == 0) {
      parts.add('güzergâh uygun değil');
    }
    if (parts.isNotEmpty) _showNotification('🛤 ${parts.join(' · ')}');
    _frame.value = _frame.value + 1;
  }

  /// Silgi — güzergâhtaki bekleyen emirleri ve döşenmiş yolları kaldırır.
  /// Bekleyen emir tam iade (henüz kimse çalışmadı), döşenmiş yol yarı iade
  /// (bina yıkımıyla aynı ilke).
  void _commitRoadErase() {
    int removed = 0;
    setStateHere(() {
      for (final (tile, ok) in _roadPreview) {
        if (!ok) continue;
        final (c, r) = tile;
        final pending = _roadOrders
            .where((o) => o.col == c && o.row == r && !o.completed)
            .toList();
        if (pending.isNotEmpty) {
          for (final o in pending) {
            for (final (kind, amt) in o.surface.cost.entries) {
              _stockpile.add(kind, amt);
            }
            _roadOrders.remove(o);
            removed++;
          }
          continue;
        }
        final t = _roadSystem.at(c, r);
        if (t != null) {
          for (final (kind, amt) in t.surface.cost.entries) {
            final back = (amt * 0.5).floor();
            if (back > 0) _stockpile.add(kind, back);
          }
          _roadSystem.remove(c, r);
          removed++;
        }
      }
      _clearRoadDrag();
    });
    if (removed > 0) {
      // Yol topolojisi değişti → NPC path cache'leri tazelensin.
      _pathContext.bumpVersion();
      _showNotification('🧹 $removed tile yol kaldırıldı');
    } else {
      _showNotification('Seçilen güzergâhta yol yok.');
    }
    _frame.value = _frame.value + 1;
  }

  void _clearRoadDrag() {
    _roadDragStart = null;
    _roadDragEnd = null;
    _roadPreview.clear();
    _roadPreviewV++;
  }
}
