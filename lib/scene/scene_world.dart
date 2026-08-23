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

  /// EKRAN-uzayı köylü hit testi: tıklamayı köylünün ayak tile'ıyla değil,
  /// ÇİZİLEN sprite gövdesiyle karşılaştırır. İzometride sprite ayak
  /// noktasından ekranda YUKARI uzar — eski tile-bazlı test gövdeye/kafaya
  /// tıklamayı hep kaçırıyordu (ekranda yukarı = grid'de çapraz komşu tile).
  ///
  /// Kritik UX kuralı: sprite ne kadar küçük/uzak olursa olsun her köylünün
  /// EKRANDA garanti bir dokunma yarıçapı olur (min ~26px) → parmak/imleç
  /// hedefi asla iğne deliğine düşmez (eski hata: gerçek gövde ~9px'e
  /// büzülüyordu). Sprite büyükse kutu büyür, küçükse taban yarıçap devreye
  /// girer. En yakın görsel-merkez kazanır; üst üste binenlerde önde çizilen
  /// (depth büyük) öncelikli. `pos` doğrudan ekran (post-zoom) koordinatı —
  /// d.localPosition ile aynı uzay, dönüşüm gerekmez.
  VillagerEntity? _villagerAtScreen(Offset pos) {
    final center = Offset(_viewSize.width / 2, _viewSize.height / 2);
    VillagerEntity? best;
    double bestScore = double.infinity; // küçük = daha iyi (merkeze yakınlık)
    double bestDepth = double.negativeInfinity;
    for (final v in _villagers) {
      if (v.isInsideBuilding) continue;
      // Köylünün EKRANDAKI (zoom uygulanmış) ayak konumu.
      final world = gridToScreen(v.renderX, v.renderY, _viewSize, _camera);
      final feet = (world - center) * _zoom + center;
      final sc = kCharScale * v.lifeStage.renderScale * _zoom;
      // Sprite görsel merkezi: ayaktan ~36 birim yukarı (gövde ortası).
      final cy = feet.dy - 36 * sc;
      // Ekran yarı-uzanımları (sprite büyüdükçe büyür) + garanti taban.
      final halfW = (16.0 * sc).clamp(15.0, 60.0);
      final halfH = (42.0 * sc).clamp(20.0, 90.0);
      final dx = (pos.dx - feet.dx).abs();
      final dy = (pos.dy - cy).abs();
      if (dx > halfW || dy > halfH) continue; // gövde kutusu dışında
      // Skor: normalize edilmiş merkeze uzaklık (en isabetli tık kazanır).
      final score = (dx / halfW) * (dx / halfW) + (dy / halfH) * (dy / halfH);
      // Üst üste binen sprite'larda önde çizilen (depth büyük) öncelikli;
      // aynı depth'te merkeze en yakın.
      if (v.depth > bestDepth + 0.001 ||
          (v.depth > bestDepth - 0.001 && score < bestScore)) {
        best = v;
        bestScore = score;
        bestDepth = v.depth;
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

  // ── Sahneden çıkan köylü ───────────────────────────────────────────────────

  /// Köyden ÇIKAN bir köylüye kalan tüm sahne referanslarını koparır.
  ///
  /// Köyden çıkışın dört kapısı var (ölüm/sürgün → `_tickPopulation`, kaçırılma
  /// → `_takeCaptive`, devşirme → `_takeConscript`) ve her biri temizliği kendi
  /// bildiğince yapıyordu: ölüm yalnız küslük/kan davasını siliyor, devşirme
  /// hiçbirini. Kalan referans "hayalet köylü" üretiyordu — açık kalan panelden
  /// olmayan birini idam etmek, hayalet bir kan düşmanı yüzünden sonsuz süren
  /// husumet, ölüye koşan muhafız. Tek kapı: çıkışın SEBEBİ ne olursa olsun buradan geç.
  ///
  /// Ailevi bağlar burada KOPARILMAZ — geri dönüşü olan çıkışlar (fidye) onları
  /// tek yönlü koparıp geri kurar, ölüm ise yasın kaynağı olarak korur.
  void _forgetVillager(VillagerEntity v) {
    // Bazı çıkışlar (kaçırılma/devşirme) startDying/startLeaving kullanmadan
    // varlığı listeden doğrudan çıkarır. Porter, iş hedefi ve ateş oturma slotu
    // aynı merkezî çıkış kapısında kapanmalı; aksi halde dünyada hayalet claim
    // kalır. _releaseJob porter görevini de güvenle iptal eder.
    v.cancelSit();
    if (v.job != null) {
      _releaseJob(v);
    } else {
      v.cancelCarryTask();
    }
    if (identical(_selectedVillager, v)) _selectedVillager = null;
    if (identical(_followedVillager, v)) _followedVillager = null;
    if (identical(_draggedVillager, v)) _draggedVillager = null;
    if (identical(_hoverVillager, v)) _hoverVillager = null;
    if (identical(_petitionAuthor, v)) _petitionAuthor = null;
    if (identical(_accusedCriminal, v)) _accusedCriminal = null;
    if (identical(_firekeeper, v)) _firekeeper = null;
    if (identical(_brideElect, v)) _brideElect = null;
    if (identical(_groomElect, v)) _groomElect = null;
    if (identical(_ransomVictim, v)) _ransomVictim = null;
    final couple = _weddingCouple;
    if (couple != null &&
        (identical(couple.$1, v) || identical(couple.$2, v))) {
      _weddingCouple = null;
    }

    for (final o in _villagers) {
      if (identical(o, v)) continue;
      o.grudges.remove(v);
      o.bloodEnemies.remove(v);
      if (identical(o.convoPartner, v)) o.convoPartner = null;
      // Kanaat + anı: gitmiş birine dair kanaat yalnız sızıntı, ama ANI aktif
      // zarar — `strongestReportable` hâlâ onu seçebilir ve tanık, sahnede
      // olmayan biri için muhafıza koşar (`_deliverReport` canlılık sormuyor).
      o.memory.opinion.remove(v);
      o.memory.recollections.removeWhere((r) => identical(r.subject, v));
    }
    // Gömdüğü zulalar toprakta KALIR (mal buharlaşmaz) ama artık kimseyi
    // suçlamaz — sahneden çıkmış birine dangling referans tutulmaz.
    _forgetLootOwner(v);
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
    for (final site in _landmarks) {
      _obstacles.add((site.col, site.row));
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
    _berryBushes.clear();
    _cookedMeals = 0;
    _replaceDecor(const []);
    _trees.clear();
    _mineNodes.clear();
    _landmarks.clear();
    _farmTiles.clear();
    _graves.clear();
    _buildings.clear();
    _orders.clear();
    _roadOrders.clear();
    _roadSystem.clear();
    _placingRoad = null;
    _roadErase = false;
    _clearRoadDrag();
    _pathContext.bumpVersion(); // yeni harita → tüm cached path'ler iptal
    _anchorSystem.rebuild(const []); // tüm slot rezervasyonlarını sil
    _cows.clear();
    _villagers.clear();
    // Yeni harita → kafile yeni bir yandan girsin (giriş noktası bu üretimde
    // bir kez seçilir; kuruluş kararı kadroyu değiştirirse AYNI nokta kullanılır).
    _caravanEntrySet = false;
    _resourceBoxes.clear();
    _eggs.clear();
    _lootCaches.clear();
    _hayEntities.clear();
    _birdFlocks.clear();
    _beeSwarms.clear();
    _pendingPetition = null;
    _decisionPacing = DecisionPacing();
    _pacedPetitions.clear();
    _pacedChoices.clear();
    _pacedImperialDemand = null;
    _pacedImperialRequestId = null;
    _petitionModalOpen = false;
    _petitionOverdue = false;
    _petitionOverdueTimer = 0;
    _petitionTimer = 1.0 * kGameDaySeconds;
    _petitionDeadline = 0;
    _petitionFollowUps.clear();
    _petitionCooldowns.clear();
    _villageMemory.clear();
    // Yeni köy hiçbir zanaat bilmez — yalnız ortak survival kiti açık. Gerisi
    // köyün insanlarından organik doğar (çağrı/birikim/dışarıdan).
    _knownCrafts.clear();
    _ledgerSection = null;
    _mobileBuildCatalogOpen = false;
    _lawRitual = null;
    _policies.restoreSealed(const []); // defter boş: yeni köy, yeni hüküm
    _policies.inkDryUntilSim = 0;
    _inkDryTotal = 0;
    _governanceLegacy = 0;

    _stockpile.clear();
    // Başlangıç kaynak paketi — oyuncunun erken oyun sıkışmaması için.
    // Ateş yeri ücretsiz; sonrasında oduncu kulübesi (12 odun) veya bir ev
    // (18 odun + 4 taş) ya da kuyu (4 odun + 8 taş) kurabilir.
    // 25/15/25: ilk 1-2 binayı kurmak + ilk günü atlatmak için yeterli.
    // YENİ OYUNDA bunu kuruluş kararı EZER (bkz. FoundingChoice / açılış
    // sinematiğinin ilk kapısı); burada duran değer showcase/referans/dev
    // haritalarının tabanı ve sinematik atlanırsa gelen varsayılanla aynıdır.
    _stockpile.wood = 25;
    _stockpile.stone = 15;
    _stockpile.food = 25;
    _hasFire = false;
    _firepitBuilding = null;
    _foundingHearthCameraSecured = false;
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
    _stepCache = null; // ilk _tickFlow taramasında yeniden kurulur
    // Yeni köy âdeti yeniden öğrenir — dersler sıfırlanır.
    _customLessons.clear();
    _firstMealShown = false;
    _berriesPicked = 0;
    _woodHarvested = 0;
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
    _replaceDecor(result.decor);
    _trees.addAll(result.trees);
    _mineNodes.addAll(result.mineNodes);
    _landmarks.addAll(result.landmarks);
    _berryBushes.addAll(result.berryBushes);

    // Arazi: merkezde açıklık aç, gen ormanını yoğun vahşi ormanla değiştir,
    // sınır halkasına kesilebilir ağaçları diz. _trees'i yeniden kurar.
    _initLand();
    // _initLand dünya üreticisinin ağaç listesinden sonra vahşi orman/sınır
    // yüzeylerini kurar. Dekoru ancak bütün doğal yüzeyler son hâlini aldıktan
    // sonra bugünkü spacing, bütçe ve sahiplik sözleşmesine taşı.
    _sanitizeDecorPopulation();

    // Yeni map → ground picture cache invalid.
    _groundVersion++;

    // KURULUŞ — kafile ilk saniyeden sahnede. Ateş yeri henüz yok; kurucular
    // haritanın bir kenarından girip merkeze doğru yürürler (bkz.
    // _spawnFoundingCaravan). Eski açılışta ekran boştu ve ilk insan ancak
    // ateş yakılınca beliriyordu.
    _spawnFoundingCaravan();

    _fixNpcSpawns();
  }
}
