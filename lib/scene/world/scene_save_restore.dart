part of '../../main.dart';

/// KAYIT — restore yarısı (JSON → state). Eski kayıt toleransı burada; capture ile birebir simetrik olmalı.
extension _SceneSaveRestore on _VillageSceneState {
  // ── Restore (JSON → state) ──────────────────────────────────────────────────

  /// Kaydedilmiş dünyayı geri kurar. initState'ten (asset yüklemeden önce)
  /// `_generateWorld` yerine çağrılır → setState KULLANMAZ.
  void restoreWorld(Map<String, dynamic> w) {
    // Mekanik sonuç kayıttadır; yarım kalmış transient koreografi değildir.
    _releaseVignette();
    _clearImperialEngagements(applyLosses: false);
    _soldiers.clear();
    _imperialPhase = ImperialVisitPhase.idle;
    _foundingHearthCameraSecured = false;
    // 1) Her şeyi temizle (generator'ın yaptığı scaffolding ama generator yok).
    _waterTiles.clear();
    _lotuses.clear();
    _reeds.clear();
    _reedBeds.clear();
    _foundingBedTargets.clear();
    _berryBushes.clear();
    _cookedMeals = 0;
    _berriesPicked = 0;
    _replaceDecor(const []);
    _trees.clear();
    _cleared.clear();
    _wilderness.clear();
    _wildTreeTiles.clear();
    _mineNodes.clear();
    _landmarks.clear();
    _farmTiles.clear();
    _harmanSites.clear();
    _buildings.clear();
    _orders.clear();
    _roadOrders.clear();
    _roadSystem.clear();
    _placingRoad = null;
    _roadErase = false;
    _clearRoadDrag();
    _cows.clear();
    _villagers.clear();
    _merchants.clear();
    _foundingCouncilPending = false;
    _foundingCouncilFormed = false;
    _foundingCouncilHold = 0.0;
    _foundingCouncilTargets.clear();
    _resourceBoxes.clear();
    _eggs.clear();
    _lootCaches.clear();
    _hayEntities.clear();
    _birdFlocks.clear();
    _beeSwarms.clear();
    _graves.clear();
    _petitionFollowUps.clear();
    _petitionCooldowns.clear();
    _decisionPacing = DecisionPacing();
    _pacedPetitions.clear();
    _pacedChoices.clear();
    _pacedImperialDemand = null;
    _pacedImperialRequestId = null;
    _villageMemory.clear();
    _storyCasts.clear();
    _villagePulse = null;
    _villagePulseOpen = false;
    _villagePulseLastKind = null;
    _villagePulseLastActor = null;
    _villagePulseEchoes.clear();
    _knownCrafts.clear();
    _specialistOffersClaimed = 0;
    _completedQuests.clear();
    _guideShown.clear();
    _coatsMade = 0;
    _coatPriority = CoatPriority.frail;
    _coldHouses.clear();
    _firstShearShown = false;
    _firstCoatShown = false;
    _winterDay = -1;
    _shearYear = -1;
    _winterEveDay = -1;
    _winterMurmurDay = -1;
    _guideOpen = false;
    _guideWanted = false;
    _guideStepId = '';
    _questVoiceWho = null;
    _questVoiceLine = '';
    _questVoiceLeft = 0;
    _npcVoiceWho = null;
    _npcVoiceLine = '';
    _npcVoiceLeft = 0;
    _storyLog.clear();
    _achievedMilestones.clear();
    _activeCutscene = null; // yüklenen oyunda sinematik oynamaz
    // İmparatorluk sinematik merdiveni — restore aşağıda okur; okunmazsa
    // (yeni oyun) sıfırdan başlar: ilk ziyaret yine tam film.
    _housePressure.clear();
    _betrothalForced = false;
    _imperialVisits = 0;
    _impGrudge = false;
    _impFilmsShown.clear();
    _policyMoraleEffects.clear();
    _decisionProcesses.clear();
    _governanceAftermath.clear();
    _lawBehaviorNextSim = 0;
    _lawBehaviorCursor = 0;
    // Düğün kur state'i geçici — önceki oyundan sızmasın (çift _villagers
    // yeniden kurulduğunda eski ref'ler geçersiz). _weddingCouple aşağıda
    // pending'e göre yeniden bağlanır.
    _brideElect = null;
    _groomElect = null;
    _courtshipTimer = 0;
    _weddingScan = 0;
    // Omen (olay mayalanması) geçici — yüklemede sıfırla (yeni olay zamanla gelir).
    _omenEvent = null;
    _omenLeft = 0;
    _activeFx.clear();
    _stockpile.clear();
    _selectedBuilding = null;
    _selectedVillager = null;
    _followedVillager = null;
    // Karar kuyruğu — restore aşağıda kayıttan geri kurar (varsa).
    _pendingChoice = null;
    _choiceModalOpen = false;
    _choiceDeadline = 0;
    _choiceGrace = 1;
    _choiceUrgentWarned = false;
    _petitionOverdue = false;
    _petitionOverdueTimer = 0;
    _activeEvent = null;

    // 2) Skaler state.
    _time = _d(w['time']);
    _decisionPacing = DecisionPacing.fromJson(w['decisionPacing']);
    _decisionCustoms = DecisionCustoms.fromJson(w['decisionCustoms']);
    _worldSeed = _i(w['worldSeed']);
    _dayCount = _i(w['dayCount'], 1);
    _lastTimeOfDay = _d(w['lastTimeOfDay']);
    _cycle.timeOfDay = _d(w['timeOfDay'], 0.45);
    final cam = w['camera'];
    if (cam is List && cam.length == 2) {
      _camera = Offset(_d(cam[0]), _d(cam[1]));
    }
    _zoom = _d(w['zoom'], 1.0);
    _cameraGuideSeen = _b(w['cameraGuideSeen']);
    final savedScale = w['timeScale'];
    if (savedScale is num) {
      final scale = savedScale.toDouble();
      _speedIdx = scale <= 0
          ? 3
          : scale >= 3.0
          ? 2
          : scale >= 1.5
          ? 1
          : 0;
    } else {
      // Eski ve yeni indeks düzeni aynıdır: 0=1×, 1=2×, 2=4×, 3=duraklat.
      final old = _i(w['speedIdx']);
      _speedIdx = old.clamp(0, 3);
    }
    _timeScale = _VillageSceneState._speedSteps[_speedIdx];
    _morale = _d(w['morale'], 0.5);
    _avgIndividualMorale = _d(w['avgIndividualMorale'], 0.6);
    _foodHunger = _d(w['foodHunger']);
    _hasFire = _b(w['hasFire']);
    _charterTier = _i(w['charterTier']);
    _governanceLegacy = _d(w['governanceLegacy']);
    _merchantTimer = _d(w['merchantTimer'], 0.7 * kGameDaySeconds);
    _merchantTradeCd = _d(w['merchantTradeCd']);
    for (final raw in (w['decisionProcesses'] as List? ?? const [])) {
      final process = DecisionProcess.fromJson(raw);
      if (process != null && process.dueSim > 0) {
        _decisionProcesses.add(process);
      }
    }
    for (final raw in (w['governanceAftermath'] as List? ?? const [])) {
      final aftermath = GovernanceAftermath.fromJson(raw);
      if (aftermath != null && aftermath.untilSim > _time) {
        _governanceAftermath.add(aftermath);
      }
    }
    _lawBehaviorNextSim = _d(w['lawBehaviorNextSim']);
    _lawBehaviorCursor = _i(w['lawBehaviorCursor']);
    _lastPopMilestone = _i(w['lastPopMilestone']);
    _firstReedBedShown = _b(w['firstReedBedShown']);
    final hasFirstNightFastForward = w.containsKey(
      'foundingFirstNightFastForwarded',
    );
    _foundingFirstNightFastForwarded = _b(w['foundingFirstNightFastForwarded']);
    _foundingFirstNightSleepGlimpse = 0.0;
    _foundingBedWorkElapsed = _d(w['foundingBedWorkElapsed']);
    _foundingFirstNightWaitReal = _d(w['foundingFirstNightWaitReal']);
    final hasFoundingShelterFlow = w.containsKey('foundingTentsReadyDay');
    _foundingTentsReadyDay = _i(w['foundingTentsReadyDay']);
    _foundingTentIllnessTriggered = _b(w['foundingTentIllnessTriggered']);

    // 3) Harita / kaynaklar / sistemler.
    for (final t in (w['water'] as List? ?? const [])) {
      if (t is List && t.length == 2) _waterTiles.add((_i(t[0]), _i(t[1])));
    }
    _restoreStockpile(w['stockpile']);
    _restorePolicies(w['policies']);
    if (w['houses'] is Map) {
      _houses.loadJson(Map<String, dynamic>.from(w['houses'] as Map));
    }
    _peakAdults = (w['peakAdults'] as num?)?.toInt() ?? 0;
    _collapseCountdown = (w['collapseCountdown'] as num?)?.toDouble() ?? 0;
    for (final id in (w['lessonsSeen'] as List? ?? const [])) {
      _lessonsSeen.add(id as String);
    }
    _reckoningHeralded = w['reckoningHeralded'] == true;
    _karneYear = _i(w['karneYear'], 0);
    _reckoningVerdict = switch (w['reckoningVerdict'] as String?) {
      'sancak' => ReckoningVerdict.sancak,
      'berat' => ReckoningVerdict.berat,
      'ilhak' => ReckoningVerdict.ilhak,
      _ => null,
    };
    for (final q in (w['completedQuests'] as List? ?? const [])) {
      _completedQuests.add(q as String);
    }
    // Eski akışta çadır saz gecesinden ÖNCE kurulabiliyordu. O kaydı geri
    // açınca insanları evlerinden çıkarıp geçmiş bir geceyi yeniden oynatamayız.
    if (!hasFoundingShelterFlow && _completedQuests.contains('tent')) {
      _completedQuests.add('firstNight');
    }
    if (!hasFirstNightFastForward &&
        (_dayCount > 1 || _completedQuests.contains('firstNight'))) {
      _foundingFirstNightFastForwarded = true;
    }
    // Eski kayıt alanı korunur; kontrollü kuruluş hastalığı artık görev veya
    // akış kapısı değildir. Evi olan eski köyü yalnız uyumluluk için geçmiş
    // sayarız, görev sayacına bu işaret zaten girmez.
    if (_completedQuests.contains('house')) {
      _foundingTentIllnessTriggered = true;
    }
    for (final g in (w['guideShown'] as List? ?? const [])) {
      _guideShown.add(g as String);
    }
    _coatsMade = _i(w['coatsMade']);
    _coatPriority = CoatPriority.values.firstWhere(
      (c) => c.name == w['coatPriority'],
      orElse: () => CoatPriority.frail,
    );
    _firstShearShown = w['firstShearShown'] == true;
    _firstCoatShown = w['firstCoatShown'] == true;
    for (final s in (w['storyLog'] as List? ?? const [])) {
      // Yeni format = map; eski kayıt = düz string (gün bilinmez → 0).
      if (s is Map) {
        _storyLog.add(ChronicleEntry.fromJson(Map<String, dynamic>.from(s)));
      } else if (s is String) {
        _storyLog.add(ChronicleEntry(day: 0, icon: '📜', text: s));
      }
    }
    for (final m in (w['achievedMilestones'] as List? ?? const [])) {
      _achievedMilestones.add(m as String);
    }
    _oreDiscovered.clear();
    final ore = w['oreDiscovered'] as List?;
    if (ore == null) {
      // Eski kayıt: madenler bandsız (rastgele) üretilmişti → hepsi bilinir
      // say, yükleme sonrası sahte "damar bulundu" yağmasını önle.
      _oreDiscovered.addAll([for (final t in OreType.values) t.name]);
    } else {
      for (final t in ore) {
        _oreDiscovered.add(t as String);
      }
    }
    _villageName = (w['villageName'] as String?) ?? 'Köy';
    _imperialFavor = _d(w['imperialFavor'], 0.5);
    _imperialTimer = _d(w['imperialTimer'], 6.0 * kGameDaySeconds);
    _imperialDemand = null; // yüklemede aktif ziyaret yok
    final hp = w['housePressure'];
    if (hp is Map) {
      for (final e in hp.entries) {
        _housePressure[e.key as String] = _d(e.value);
      }
    }
    _imperialVisits = _i(w['imperialVisits']);
    _impGrudge = _b(w['impGrudge']);
    for (final f in (w['impFilmsShown'] as List? ?? const [])) {
      _impFilmsShown.add(f as String);
    }
    // NOT: eski kayıtlarda 'tierCutscenesShown' alanı var; kademe sinematiği
    // kaldırıldığı için okunmaz (bilinmeyen alanlar sessizce yok sayılır).
    _famineShown = _b(w['famineShown']);
    for (final f in (w['villageMemory'] as List? ?? const [])) {
      _villageMemory.add(f as String);
    }
    for (final c in (w['knownCrafts'] as List? ?? const [])) {
      _knownCrafts.add(c as String);
    }
    _specialistOffersClaimed = _i(w['specialistOffersClaimed']);

    // 4) Binalar (önce — referans hedefi).
    for (final raw in (w['buildings'] as List? ?? const [])) {
      _buildings.add(_buildingFromJson(Map<String, dynamic>.from(raw as Map)));
    }

    // 5) Köylüler — iki geçiş (önce yarat, sonra aile/ev bağla).
    final vJsons = <Map<String, dynamic>>[
      for (final raw in (w['villagers'] as List? ?? const []))
        Map<String, dynamic>.from(raw as Map),
    ];
    for (final vj in vJsons) {
      _villagers.add(_villagerFromJson(vj));
    }
    for (var i = 0; i < vJsons.length; i++) {
      final vj = vJsons[i];
      final v = _villagers[i];
      final homeIdx = _i(vj['home'], -1);
      if (homeIdx >= 0 && homeIdx < _buildings.length) {
        v.homeBuilding = _buildings[homeIdx];
      }
      for (final p in (vj['parents'] as List? ?? const [])) {
        final pi = _i(p, -1);
        if (pi >= 0 && pi < _villagers.length) v.parents.add(_villagers[pi]);
      }
      for (final c in (vj['children'] as List? ?? const [])) {
        final ci = _i(c, -1);
        if (ci >= 0 && ci < _villagers.length) v.children.add(_villagers[ci]);
      }
      for (final g in (vj['grudges'] as List? ?? const [])) {
        final gm = g as Map;
        final gi = _i(gm['v'], -1);
        if (gi >= 0 && gi < _villagers.length) {
          v.grudges[_villagers[gi]] = _d(gm['until']);
        }
      }
      // KANAAT — kime ne kadar güvendiği (bkz. villager_memory). Anıların
      // kendisi kaydedilmez (zaten söner); kalıcı olan bu iz.
      for (final o in (vj['opinion'] as List? ?? const [])) {
        final om = o as Map;
        final oi = _i(om['v'], -1);
        if (oi >= 0 && oi < _villagers.length) {
          v.memory.opinion[_villagers[oi]] = _d(om['o']);
        }
      }
      for (final e in (vj['bloodEnemies'] as List? ?? const [])) {
        final ei = _i(e, -1);
        if (ei >= 0 && ei < _villagers.length) {
          v.bloodEnemies.add(_villagers[ei]);
        }
      }
    }

    // 5b) Dış dünya ziyaretçileri — sakine bağlanmazlar, kendi grup/evreleri
    // ile dönerler. Eski kayıtta alan yoksa liste boş kalır ve doğal timer yeni
    // ziyaret üretir.
    for (final raw in (w['merchants'] as List? ?? const [])) {
      final j = Map<String, dynamic>.from(raw as Map);
      final m = MerchantEntity(
        startCol: _d(j['x']),
        startRow: _d(j['y']),
        browseX: _d(j['browseX']),
        browseY: _d(j['browseY']),
        exitX: _d(j['exitX']),
        exitY: _d(j['exitY']),
        groupId: _i(j['groupId']),
        visitorKind: _enumByName(
          VisitorKind.values,
          j['visitorKind'],
          VisitorKind.caravan,
        ),
        isGroupLeader: _b(j['leader']),
        hasCart: _b(j['cart']),
        // Eski kayıtlarda 800 sn'ye kadar çıkan kervan sayaçlarını yeni kısa
        // ziyaret ritmine çek; yüklenen köyün meydanında ziyaretçi kalmasın.
        browseLeft: _d(j['browseLeft'], 30).clamp(0.0, 60.0),
        greetingLeft: _d(j['greetingLeft'], 3).clamp(0.0, 3.0),
        visualType: _enumByName(
          VillagerType.values,
          j['type'],
          VillagerType.merchant,
        ),
        male: j['male'] as bool? ?? true,
        name: j['name'] as String? ?? 'Yolcu',
      );
      m.phase = _enumByName(
        MerchantPhase.values,
        j['phase'],
        MerchantPhase.entering,
      );
      m.gridX = _d(j['x']);
      m.gridY = _d(j['y']);
      m.renderX = m.gridX;
      m.renderY = m.gridY;
      m.travelHeadingX = _d(j['headingX'], m.travelHeadingX);
      m.travelHeadingY = _d(j['headingY'], m.travelHeadingY);
      _merchants.add(m);
    }

    // 5a) Köy Nabzı — aktör referansları ancak köylüler kurulduktan sonra
    // çözülebilir. Geçersiz/ölmüş indeks sessizce düşer; yeni hikâye zamanla gelir.
    _villagePulseNextReal = _d(
      w['villagePulseNextReal'],
      GameplayPacing.firstPulseRealSeconds,
    );
    final pulseRaw = w['villagePulse'];
    if (pulseRaw is Map) {
      final j = Map<String, dynamic>.from(pulseRaw);
      final ai = _i(j['actor'], -1), oi = _i(j['other'], -1);
      if (ai >= 0 && ai < _villagers.length) {
        final kind = _enumByName(
          _VillagePulseKind.values,
          j['kind'],
          _VillagePulseKind.sharedMeal,
        );
        _villagePulse = _VillagePulse(
          kind: kind,
          actor: _villagers[ai],
          other: oi >= 0 && oi < _villagers.length ? _villagers[oi] : null,
          totalReal: _d(
            j['totalReal'],
            GameplayPacing.pulseDecisionRealSeconds,
          ),
          remainingReal: _d(
            j['remainingReal'],
            GameplayPacing.pulseDecisionRealSeconds,
          ),
        );
      }
    }
    for (final raw in (w['villagePulseEchoes'] as List? ?? const [])) {
      final j = Map<String, dynamic>.from(raw as Map);
      final ai = _i(j['actor'], -1);
      _villagePulseEchoes.add(
        _VillagePulseEcho(
          dueSim: _d(j['dueSim']),
          icon: '${j['icon'] ?? '•'}',
          text: '${j['text'] ?? ''}',
          actor: ai >= 0 && ai < _villagers.length ? _villagers[ai] : null,
        ),
      );
    }

    // 5b) ESKİ KAYIT GÖÇÜ — soyadsız köylüleri hanelere bağla.
    _migrateHouseholdSurnames();

    // 6) Referans wiring (firepit / firekeeper).
    final fpIdx = _i(w['firepit'], -1);
    _firepitBuilding = (fpIdx >= 0 && fpIdx < _buildings.length)
        ? _buildings[fpIdx]
        : null;
    final fkIdx = _i(w['firekeeper'], -1);
    _firekeeper = (fkIdx >= 0 && fkIdx < _villagers.length)
        ? _villagers[fkIdx]
        : null;

    // 7) Hayvanlar. (Eski işçi dizileri — builders/farmers/miners/fishers/
    // florists/shepherds/woodcutters/lumberCamps — artık YOK SAYILIR: işçiler
    // gerçek köylü işine dönüştü [scene_jobs]. İş kaynakları [_orders/_farmTiles/
    // _mineNodes...] bağımsız kalıcı; açılışta _syncJobWorkforce köylüleri atar.
    // Eski kayıt hatasız yüklenir, yetim/donmuş avatar kalmaz.)
    for (final raw in (w['animals'] as List? ?? const [])) {
      _cows.add(_animalFromJson(Map<String, dynamic>.from(raw as Map)));
    }

    // 8) Dünya nesneleri.
    for (final raw in (w['orders'] as List? ?? const [])) {
      _orders.add(_orderFromJson(Map<String, dynamic>.from(raw as Map)));
    }
    for (final raw in (w['roadOrders'] as List? ?? const [])) {
      _roadOrders.add(
        _roadOrderFromJson(Map<String, dynamic>.from(raw as Map)),
      );
    }
    for (final raw in (w['roads'] as List? ?? const [])) {
      final j = Map<String, dynamic>.from(raw as Map);
      _roadSystem.add(
        RoadTile(
          col: _i(j['col']),
          row: _i(j['row']),
          surface: _enumByName(
            RoadSurface.values,
            j['surface'],
            RoadSurface.dirt,
          ),
        ),
      );
    }
    for (final raw in (w['farmTiles'] as List? ?? const [])) {
      _farmTiles.add(_farmTileFromJson(Map<String, dynamic>.from(raw as Map)));
    }
    for (final raw in (w['harmanSites'] as List? ?? const [])) {
      final j = Map<String, dynamic>.from(raw as Map);
      _harmanSites.add(HarmanSite(col: _i(j['col']), row: _i(j['row'])));
    }
    for (final raw in (w['trees'] as List? ?? const [])) {
      _trees.add(_treeFromJson(Map<String, dynamic>.from(raw as Map)));
    }
    for (final raw in (w['mineNodes'] as List? ?? const [])) {
      _mineNodes.add(_mineNodeFromJson(Map<String, dynamic>.from(raw as Map)));
    }
    for (final raw in (w['landmarks'] as List? ?? const [])) {
      final j = Map<String, dynamic>.from(raw as Map);
      _landmarks.add(
        WorldLandmark(
          col: _i(j['col']),
          row: _i(j['row']),
          kind: _enumByName(
            WorldLandmarkKind.values,
            j['kind'],
            WorldLandmarkKind.ruinedWatchtower,
          ),
          outcome: _enumByName(
            LandmarkOutcome.values,
            j['outcome'],
            LandmarkOutcome.salvage,
          ),
          discovered: _b(j['discovered']),
        ),
      );
    }
    // Reveal artık KAMERA KISITI (zoom) — arazi örtüsü yok. Eski kayıtlardaki
    // 'cleared' alanı yok sayılır; land setleri boş kalır (scene_land).
    for (final raw in (w['lotuses'] as List? ?? const [])) {
      final j = Map<String, dynamic>.from(raw as Map);
      _lotuses.add(
        LotusEntity(
          col: _i(j['col']),
          row: _i(j['row']),
          variant: _i(j['variant']),
        ),
      );
    }
    for (final raw in (w['reeds'] as List? ?? const [])) {
      final j = Map<String, dynamic>.from(raw as Map);
      _reeds.add(
        ReedClump(
          col: _i(j['col']),
          row: _i(j['row']),
          col2: _i(j['col2']),
          row2: _i(j['row2']),
          growth: _d(j['growth'], 1.0),
        ),
      );
    }
    for (final raw in (w['berryBushes'] as List? ?? const [])) {
      final j = Map<String, dynamic>.from(raw as Map);
      _berryBushes.add(
        BerryBush(
          col: _i(j['col']),
          row: _i(j['row']),
          variant: _i(j['variant']),
          ripeness: _d(j['ripe'], 1.0),
        ),
      );
    }
    _cookedMeals = _i(w['cookedMeals']);
    _berriesPicked = _i(w['berriesPicked']);
    _woodHarvested = _i(w['woodHarvested']);
    _firstMealShown = _b(w['firstMealShown']);
    _replaceDecor([
      for (final raw in (w['decor'] as List? ?? const []))
        _decorFromJson(Map<String, dynamic>.from(raw as Map)),
    ]);
    if (!w.containsKey('landmarks')) {
      _seedLandmarksForLegacySave();
    }
    for (final raw in (w['graves'] as List? ?? const [])) {
      _graves.add(_graveFromJson(Map<String, dynamic>.from(raw as Map)));
    }
    for (final raw in (w['reedBeds'] as List? ?? const [])) {
      final j = Map<String, dynamic>.from(raw as Map);
      final bed = ReedBed(gridX: _d(j['x']), gridY: _d(j['y']));
      final oi = _i(j['owner'], -1);
      if (oi >= 0 && oi < _villagers.length) bed.owner = _villagers[oi];
      _reedBeds.add(bed);
    }
    for (final raw in (w['resourceBoxes'] as List? ?? const [])) {
      final j = Map<String, dynamic>.from(raw as Map);
      _resourceBoxes.add(
        ResourceBox(
          type: _enumByName(
            ResourceBoxType.values,
            j['type'],
            ResourceBoxType.woodChunk,
          ),
          gridX: _d(j['x']),
          gridY: _d(j['y']),
          amount: _i(j['amount'], 1),
        )..slotIndex = _i(j['slotIndex']),
      );
    }
    for (final raw in (w['hay'] as List? ?? const [])) {
      final j = Map<String, dynamic>.from(raw as Map);
      _hayEntities.add(
        HayEntity(
            type: _enumByName(HayType.values, j['type'], HayType.pile),
            gridX: _d(j['x']),
            gridY: _d(j['y']),
          )
          ..slotIndex = _i(j['slotIndex'])
          ..pileSize = _i(j['pileSize'], 1)
          ..spawnTime = _d(j['spawnTime'])
          ..targetHarmanCol = j.containsKey('harmanCol')
              ? _i(j['harmanCol'])
              : null
          ..targetHarmanRow = j.containsKey('harmanRow')
              ? _i(j['harmanRow'])
              : null,
      );
    }
    // Gömülü zulalar — mal toprakta durmaya devam eder. Fail indeksi
    // çözülemezse (ölmüş/sürülmüş) zula SAHİPSİZ döner: mal hâlâ bulunabilir
    // ama kimseyi suçlamaz (bkz. `_forgetLootOwner` ile aynı sözleşme).
    for (final raw in (w['lootCaches'] as List? ?? const [])) {
      final j = Map<String, dynamic>.from(raw as Map);
      final ci = _i(j['culprit'], -1);
      _lootCaches.add(
        LootCache(
            gridX: _d(j['x']),
            gridY: _d(j['y']),
            kind: _enumByName(
              ResourceKind.values,
              j['kind'],
              ResourceKind.food,
            ),
            amount: _i(j['amount']),
            weaponAmount: _i(j['weaponAmount']),
            culpritName: '${j['culpritName'] ?? ''}',
            culprit: (ci >= 0 && ci < _villagers.length)
                ? _villagers[ci]
                : null,
          )
          ..age = _d(j['age'])
          ..witnessed = _b(j['witnessed']),
      );
    }

    // 9) Dilekçe / meclis.
    final pid = w['pendingPetition'];
    _pendingPetition = pid == PetitionIds.crimeVerdict
        ? crimeVerdictFor(_policies.sealed)
        : pid is String
        ? PetitionSystem.byId(pid)
        : null;
    final qid = w['queuedPetition'];
    _queuedPetition = qid is String ? PetitionSystem.byId(qid) : null;
    _queuedPresentDelay = _d(w['queuedPresentDelay']);
    final paIdx = _i(w['petitionAuthor'], -1);
    _petitionAuthor = (paIdx >= 0 && paIdx < _villagers.length)
        ? _villagers[paIdx]
        : null;

    // 9b) Suç durumu. Yürüyen suç + rehin kaydedilmez (anlık sahne) → yalnız
    // kalıcı olan geri gelir: şüphe defteri, af sayacı, hüküm bekleyen fail.
    _activeCrime = null;
    _ransomVictim = null;
    _crimePollSec = 0;
    _chaseRefresh = 0;
    _unrest = _d(w['unrest']).clamp(0.0, 1.0);
    _regimeRot = _d(w['regimeRot']).clamp(0.0, 1.0);
    _chronicShown = w['chronicShown'] == true;
    _crisisCooldown = _d(w['crisisCooldown']);
    _unrestStirShown = w['unrestStirShown'] == true;
    _regimeScan = 0;
    _crimeSuspicion = _i(w['crimeSuspicion']);
    _crimePardons = _i(w['crimePardons']);
    // Eski kayıtta yok — o köyün suç geçmişi bilinmiyor. Affedilen/şüphe kadarı
    // en azından bir şey olduğunu söylüyor; sıfırdan iyi bir alt sınır.
    _crimesSeen = _i(w['crimesSeen'], _crimeSuspicion + _crimePardons);
    // Eski kayıtta yok — mezar/husumet varsa köy bunları görmüş demektir; hüküm
    // gündemi sıfırdan başlamasın diye dünyadan bir alt sınır türetilir.
    _illnessSeen = _i(w['illnessSeen'], _graves.length);
    _feudsSeen = _i(w['feudsSeen'], _villagers.any((v) => v.inFeud) ? 1 : 0);
    final acIdx = _i(w['accusedCriminal'], -1);
    _accusedCriminal = (acIdx >= 0 && acIdx < _villagers.length)
        ? _villagers[acIdx]
        : null;
    // Dayanağı kalmayan dilekçeyi at: rehin kaydedilmediği için fidye kararı
    // anlamsız; sanığı bulunamayan yargı dilekçesi de öyle.
    if (_pendingPetition?.id == PetitionIds.ransom ||
        (_pendingPetition?.id == PetitionIds.crimeVerdict &&
            _accusedCriminal == null)) {
      final active = _decisionPacing.active;
      if (active != null &&
          (active.kind == HeavyDecisionKind.petition ||
              active.kind == HeavyDecisionKind.crimeVerdict)) {
        _decisionPacing.cancel(active.id);
      }
      _pendingPetition = null;
      _queuedPetition = null;
      _queuedPresentDelay = 0;
      _accusedCriminal = null;
    }
    // Kayıttaki dilekçe HAM hâliyle döner (havuz + yer tutucu). Modal'a ham
    // `{ad}` göstermemek için yeniden konuştur — tohum gün+id olduğundan
    // kayıttan önce okunan cümlenin AYNISI çıkar.
    _petitionExtra = {
      for (final e in (w['petitionExtra'] as Map? ?? const {}).entries)
        '${e.key}': '${e.value}',
    };
    final restored = _pendingPetition;
    if (restored != null) {
      _pendingPetition = restored.spoken(
        _voice(
          _petitionAuthor,
          seed: _petitionSeed(restored),
          extra: _petitionExtra,
        ),
      );
    } else {
      _petitionExtra = const {};
    }

    _petitionTimer = _d(
      w['petitionTimer'],
      GameplayPacing.firstPetitionSimSeconds,
    );
    _petitionDeadline = _d(w['petitionDeadline']);
    _petitionModalOpen = _b(w['petitionModalOpen']) && _pendingPetition != null;
    if (_pendingPetition != null &&
        petitionRequiresPlayerVerdict(_pendingPetition!.id, _charterTier)) {
      _petitionModalOpen = true;
    }
    // Eski kayıtlarda alanın adı 'petitionForced' (zorunlu huzur) — donma
    // kaldırıldı, bayrak kapıda bekleyen huzura göçer: aynı an, yeni bedeni.
    _petitionOverdue =
        (_b(w['petitionOverdue']) || _b(w['petitionForced'])) &&
        _pendingPetition != null;
    _petitionOverdueTimer = _d(w['petitionOverdueTimer']);
    // Kuyrukta bekleyen karar olayı — id'den geri kur (bilinmeyen id = eski
    // sürümden kalkmış olay → sessizce düşer; kalanı aynen kaldığı yerden).
    final choiceId = w['pendingChoice'];
    if (choiceId is String && choiceId.isNotEmpty) {
      final specialist = choiceId == EventIds.specialistCaravan
          ? _specialistCaravanEvent()
          : null;
      for (final ev in [?specialist, ...EventSystem.events]) {
        if (ev.id == choiceId && ev.needsChoice) {
          // Metin varyantı gün+id tohumuyla yeniden dokunur — kayıttan dönen
          // oyuncu mühre tıklayınca aynı cümleyi okur.
          _pendingChoice = ev.withMessage(ev.messageFor(_eventSeed(ev)));
          _choiceGrace = _d(w['choiceGrace'], kGameDaySeconds * 0.25);
          _choiceDeadline = _d(w['choiceDeadline'], _choiceGrace);
          kProbeChoiceWaiting = ev.id;
          break;
        }
      }
    }
    // Merkezi kuyruk payload'ları, varlık referansları kurulduktan sonra geri
    // bağlanır. Bilinmeyen katalog id'si eski sürüm içeriğidir ve atlanır.
    for (final raw in (w['pacedPetitions'] as List? ?? const [])) {
      if (raw is! Map) continue;
      final requestId = raw['requestId'];
      final petitionId = raw['petitionId'];
      if (requestId is! String || petitionId is! String) continue;
      // Rehin anlık sahne nesnesidir ve bilerek kaydedilmez. Dayanağı olmayan
      // fidye (ve sanığı olmayan hüküm) yüklemede görünür bir karara dönüşemez.
      if (petitionId == PetitionIds.ransom ||
          (petitionId == PetitionIds.crimeVerdict &&
              _accusedCriminal == null)) {
        _decisionPacing.cancel(requestId);
        continue;
      }
      final petition = PetitionSystem.byId(petitionId);
      if (petition == null) {
        _decisionPacing.cancel(requestId);
        continue;
      }
      final ai = _i(raw['author'], -1);
      _pacedPetitions.add(
        _PacedPetition(
          requestId: requestId,
          petition: petition,
          author: ai >= 0 && ai < _villagers.length ? _villagers[ai] : null,
          extra: {
            for (final entry in (raw['extra'] as Map? ?? const {}).entries)
              '${entry.key}': '${entry.value}',
          },
        ),
      );
    }
    for (final raw in (w['pacedChoices'] as List? ?? const [])) {
      if (raw is! Map) continue;
      final requestId = raw['requestId'];
      final eventId = raw['eventId'];
      if (requestId is! String || eventId is! String) continue;
      final specialist = eventId == EventIds.specialistCaravan
          ? _specialistCaravanEvent()
          : null;
      for (final event in [?specialist, ...EventSystem.events]) {
        if (event.id == eventId && event.needsChoice) {
          _pacedChoices.add(_PacedChoice(requestId: requestId, event: event));
          break;
        }
      }
      if (!_pacedChoices.any((choice) => choice.requestId == requestId)) {
        _decisionPacing.cancel(requestId);
      }
    }
    final pacedDemand = w['pacedImperialDemand'];
    final pacedRequestId = w['pacedImperialRequestId'];
    if (pacedDemand is Map && pacedRequestId is String) {
      final kindName = pacedDemand['kind'];
      for (final kind in ImperialDemandKind.values) {
        if (kind.name == kindName) {
          _pacedImperialDemand = ImperialDemand(
            kind,
            _i(pacedDemand['amount'], 1),
          );
          _pacedImperialRequestId = pacedRequestId;
          break;
        }
      }
    }
    // Eski kayıtta merkezi state yoksa görünür ağır kararı otoriteye devral.
    // İki eski yüzey birden açıksa dilekçe aktif kalır, olay payload olarak
    // sıraya alınır; böylece yükleme anında da tek-ağır-karar sözleşmesi başlar.
    if (w['decisionPacing'] is! Map) {
      if (_pendingPetition != null) {
        _decisionPacing.request(
          _pendingPetition!.id == PetitionIds.crimeVerdict
              ? HeavyDecisionKind.crimeVerdict
              : HeavyDecisionKind.petition,
          atDay: _decisionDay,
          urgency: _pendingPetition!.id == PetitionIds.crimeVerdict
              ? DecisionUrgency.urgent
              : DecisionUrgency.normal,
        );
      }
      final oldChoice = _pendingChoice;
      if (oldChoice != null) {
        final admission = _decisionPacing.request(
          HeavyDecisionKind.majorEvent,
          atDay: _decisionDay,
        );
        if (!admission.activated) {
          _pacedChoices.add(
            _PacedChoice(requestId: admission.request.id, event: oldChoice),
          );
          _pendingChoice = null;
          _choiceModalOpen = false;
        }
      }
    }
    // Bekleyen düğünün çifti — kayıttaki İKİ İNDEKSTEN geri bağlanır, yeniden
    // seçilmez. Biri artık yoksa (eski kayıt / bozuk indeks) çift kurulmaz ve
    // dilekçe konusuz kalır → `_tickWedding` onu masadan kaldırır. Uydurma bir
    // çift bağlamak, oyuncunun okuduğundan başkasını evlendirmek demekti.
    _weddingCouple = null;
    if (_pendingPetition?.id == PetitionIds.villageWedding ||
        _pacedPetitions.any(
          (p) => p.petition.id == PetitionIds.villageWedding,
        )) {
      final wc = w['weddingCouple'];
      if (wc is List && wc.length == 2) {
        final bi = _i(wc[0], -1), gi = _i(wc[1], -1);
        if (bi >= 0 &&
            bi < _villagers.length &&
            gi >= 0 &&
            gi < _villagers.length) {
          _weddingCouple = (_villagers[bi], _villagers[gi]);
        }
      }
    }
    final storyJson = w['storyCasts'] as Map? ?? const {};
    for (final thread in StoryThread.values) {
      final raw = storyJson[thread.name];
      if (raw is! Map) continue;
      _storyCasts[thread] = StoryCast.fromJson<VillagerEntity>(
        Map<String, dynamic>.from(raw),
        (i) => i >= 0 && i < _villagers.length ? _villagers[i] : null,
      );
    }
    for (final raw in (w['petitionFollowUps'] as List? ?? const [])) {
      final j = Map<String, dynamic>.from(raw as Map);
      if (j['id'] == PetitionIds.ransom) continue;
      final ai = _i(j['actor'], -1);
      _petitionFollowUps.add((
        id: j['id'] as String,
        fireAtSim: _d(j['fireAtSim']),
        actor: (ai >= 0 && ai < _villagers.length) ? _villagers[ai] : null,
        actorName: (j['actorName'] as String?) ?? '',
      ));
    }
    final cds = w['petitionCooldowns'];
    if (cds is Map) {
      cds.forEach((k, v) => _petitionCooldowns[k as String] = _d(v));
    }

    // 10) Olay / politika moral / ambient.
    _eventTimer = _d(w['eventTimer'], GameplayPacing.firstEventSimSeconds);
    _eventMorale = _d(w['eventMorale']);
    _eventMoraleLeft = _d(w['eventMoraleLeft']);
    _eventLabel = w['eventLabel'] as String?;
    for (final raw in (w['policyMoraleEffects'] as List? ?? const [])) {
      final j = Map<String, dynamic>.from(raw as Map);
      _policyMoraleEffects.add((
        untilSim: _d(j['untilSim']),
        amount: _d(j['amount']),
      ));
    }
    _migrationTimerSec = _d(w['migrationTimerSec']);

    // 11) Türetilmiş yapıları yeniden kur.
    // Dekor kayıtta yüzeylerden bağımsızdır. Bina, şantiye, yol, tarla ve
    // diğer kalıcı dünya nesnelerinin tamamı geri geldikten sonra eski
    // kayıtları bugünkü sahiplik/bütçe/spacing sözleşmesine taşı.
    _sanitizeDecorPopulation();
    // Reach kayda GİRMEZ — bina/görevden türer. Snap'lemezsek `_kSpanStart`ten
    // başlayıp 1.2/sn tırmanır: oturmuş bir köyü açınca kamera dakikalarca
    // kendiliğinden geri çekilir. Hedefe doğrudan otur (referans köy de aynısını
    // yapar; hesap tek yerde: `_landExpansionTarget`).
    _reachSpan = _landExpansionTarget;
    _applyPolicySideChannels();
    _pathContext.bumpVersion();
    _anchorSystem.rebuild(_buildings);
    _rebuildSpatialCaches();
    _rebuildBeeSwarms();
    // İş yerleri türetilmiş yapılara (bina/tarla/sipariş) dayandığı için mühür
    // devri BURADA, hepsi kurulduktan sonra olur. Yer bilmeyen eski kayıtlar
    // bugünkü iş yerlerine bağlanır.
    _adoptLegacyAssignments();
    _restoreImperialBattle(w['imperialBattle']);
    _groundVersion++;
    _spatialTimer = 0.0;
  }

  void _restoreStockpile(Object? j) {
    if (j is! Map) return;
    _stockpile.wood = _i(j['wood']);
    _stockpile.stone = _i(j['stone']);
    _stockpile.iron = _i(j['iron']);
    _stockpile.coal = _i(j['coal']);
    _stockpile.food = _i(j['food']);
    _stockpile.honey = _i(j['honey']);
    _stockpile.reed = _i(j['reed']);
    _stockpile.wool = _i(j['wool']);
    _stockpile.gold = _i(j['gold']);
    _stockpile.weapons = _i(j['weapons']);
  }

  void _restorePolicies(Object? j) {
    if (j is! Map) return;
    final ids = (j['sealed'] as List?)?.whereType<String>() ?? const <String>[];
    // 'path' eski kayıtlarda vardı (dava kolu) — artık yok, sessizce yok sayılır.
    // Mühür günleri eski kayıtta yoktur: damgasız dönerler (defter "gün"
    // yazmaz, hüküm yine yerinde durur).
    final raw = j['sealedOn'];
    final days = <String, int>{
      if (raw is Map)
        for (final e in raw.entries)
          if (e.key is String && e.value is num)
            e.key as String: (e.value as num).toInt(),
    };
    _policies.restoreSealed(ids, days: days);
    _policies.inkDryUntilSim = _d(j['inkDryUntilSim']);
    _lawSeen
      ..clear()
      ..addAll(
        (j['lawSeen'] as List?)?.whereType<String>() ?? const <String>[],
      );
    // Eski kayıtta liste yok → ilk tarama sessiz geçsin (o köyün gündemi zaten
    // oluşmuş, hepsini "yeni" diye duyurmak yanlış olur).
    _lawSeeded = false;
    _lawCtxCache = null;
    _lawCtxAge = 0;
  }

  /// Ada göre enum — eşleşmezse null (dava seçilmemiş kayıtlar için).
  BuildingEntity _buildingFromJson(Map<String, dynamic> j) {
    final b = BuildingEntity(
      type: _enumByName(BuildingType.values, j['type'], BuildingType.firepit),
      col: _i(j['col']),
      row: _i(j['row']),
      design: _enumByName(
        BuildingDesign.values,
        j['design'],
        BuildingDesign.original,
      ),
    );
    b.isActive = _b(j['isActive']);
    b.userPaused = _b(j['userPaused']);
    b.incomeTimer = _d(j['incomeTimer']);
    b.serviceTimer = _d(j['serviceTimer']);
    b.inscription = (j['inscription'] as String?) ?? '';
    b.waterLevel = _d(j['waterLevel'], 1.0);
    b.occupants = _i(j['occupants']);
    b.damage = _d(j['damage']).clamp(0.0, 1.0).toDouble();
    b.ownerSurname = (j['ownerSurname'] as String?) ?? '';
    b.eggTimer = _d(j['eggTimer']);
    b.honeyTimer = _d(j['honeyTimer']);
    b.fireFuel = _d(j['fireFuel'], 1.0);
    b.millRotorAngle = _d(j['millRotorAngle']);
    return b;
  }

  VillagerEntity _villagerFromJson(Map<String, dynamic> j) {
    final visual = _visualFromJson(
      Map<String, dynamic>.from(j['visual'] as Map),
    );
    final v = VillagerEntity(
      type: _enumByName(VillagerType.values, j['type'], VillagerType.farmer),
      name: (j['name'] as String?) ?? 'Köylü',
      male: visual.isMale,
      startCol: _d(j['spawnCol']),
      startRow: _d(j['spawnRow']),
      visual: visual,
      personalitySeed: (j['personalitySeed'] as num?)?.toInt(),
      ageDays: _d(j['ageDays']),
      lifespanDays: j['lifespanDays'] == null
          ? double.infinity
          : _d(j['lifespanDays']),
    );
    v.annivCount = _i(j['annivCount']);
    v.hasCoat = j['hasCoat'] == true;
    v.wardrobe = _enumByName(
      NpcWardrobe.values,
      j['wardrobe'],
      NpcWardrobe.standard,
    );
    // Eski kayıtta yoksa: yetişkin/yaşlı zaten çağrısını bulmuş say (an tekrar
    // tetiklenmesin); çocuk/genç ise büyürken keşfedecek.
    v.callingFound = _b(j['callingFound'], v.ageDays >= kAdultStartDay);
    // Eski kayıtta yoksa: genç+ zaten büyümüş say (an tekrar tetiklenmesin).
    v.grewUpMoment = _b(j['grewUpMoment'], v.ageDays >= kYouthStartDay);
    v.gridX = _d(j['x']);
    v.gridY = _d(j['y']);
    v.renderX = v.gridX;
    v.renderY = v.gridY;
    // Kayıttan dönen köylü "zaten öyle duruyordu" — dönüş animasyonu oynamasın
    // (yoksa yükleme anında köyün yarısı yerinde takla atar).
    v.loco.snapFacing(_b(j['facingRight'], true));
    final savedState = _enumByName(
      VillagerState.values,
      j['state'],
      VillagerState.idle,
    );
    // Eski kayıtlar callback/item/hedef taşımadan porter enum'unu yazabiliyor.
    // Böyle bir state'i canlandırmak boş elle (0,0)'a giden yetim görev üretir.
    final orphanedCarry =
        savedState == VillagerState.walkingToPickup ||
        savedState == VillagerState.carrying;
    v.state = orphanedCarry ? VillagerState.idle : savedState;
    v.targetCol = orphanedCarry ? v.gridX : _d(j['targetCol'], v.gridX);
    v.targetRow = orphanedCarry ? v.gridY : _d(j['targetRow'], v.gridY);
    v.isFavorite = _b(j['isFavorite']);
    v.wed = _b(j['wed']);
    v.avoidsMarriage = j.containsKey('avoidsMarriage')
        ? _b(j['avoidsMarriage'])
        : v.wardrobe == NpcWardrobe.flowing;
    // Üstlenilmiş iş rolü — atama detayı (claim/faz) _syncJobWorkforce'la kurulur.
    final jobRole = j['jobRole'] as String?;
    if (jobRole != null) {
      final role = _enumByName(JobRole.values, jobRole, JobRole.none);
      if (role != JobRole.none) v.job = VillagerJob(role);
    }
    // Oyuncunun elle kilitlediği iş. Anahtar YOKSA null kalır (otomatik havuz);
    // `none` yazılıysa bilinçli "boş dursun" kararıdır ve korunur — bu yüzden
    // burada `jobRole`'daki gibi none'ı eleyen bir kapı YOK.
    final assigned = j['assignedRole'] as String?;
    if (assigned != null) {
      v.assignedRole = _enumByName(JobRole.values, assigned, JobRole.none);
    }
    // İş yeri mührü. ESKİ KAYITTA YOK: rol var, yer yok. O köylüler
    // `_adoptLegacyAssignments` ile yükleme sonunda rolüne uyan en yakın yere
    // yazılır — kadro sessizce dağılmasın.
    v.assignedSiteId = j['assignedSite'] as String?;
    v.surname = (j['surname'] as String?) ?? '';
    v.injuryDays = _d(j['injuryDays']);
    v.sickDays = _d(j['sickDays']);
    v.tutorialIllness = _b(j['tutorialIllness']);
    v.laborDays = _d(j['laborDays']);
    v.disabled = _b(j['disabled']);
    v.feudKills = _i(j['feudKills']);
    v.crimeCount = _i(j['crimeCount']);
    for (final e in (j['life'] as List? ?? const [])) {
      if (e is Map) {
        v.life.add(ChronicleEntry.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    v.fertilityDays = j['fertilityDays'] == null
        ? double.nan
        : _d(j['fertilityDays']);
    v.birthCount = _i(j['birthCount']);
    v.isSage = _b(j['isSage']);
    v.mood = _d(j['mood']);
    v.energy = _d(j['energy'], 1.0);
    v.morale = _d(j['morale'], 0.6);
    if (j['drives'] case final Map<String, dynamic> d) v.mind.restore(d);
    v.lowMoraleTime = _d(j['lowMoraleTime']);
    v.moraleReason = (j['moraleReason'] as String?) ?? 'huzurlu';
    // Eski kayıtta servet yok → yetişkinlere makul bir taban ver (0'da kalmasın).
    v.wealth = _d(j['wealth'], v.ageDays >= kAdultStartDay ? 30 : 0);
    final rawMastery = j['mastery'];
    if (rawMastery is Map) {
      rawMastery.forEach((k, val) => v.mastery[k as String] = _d(val));
    }
    final leaving = j['leavingTo'];
    if (leaving is List && leaving.length == 2) {
      v.job = null;
      v.startLeaving(_d(leaving[0]), _d(leaving[1]));
    }
    return v;
  }

  AnimalEntity _animalFromJson(Map<String, dynamic> j) {
    final a = AnimalEntity(
      kind: _enumByName(AnimalKind.values, j['kind'], AnimalKind.cow),
      barnCol: _i(j['barnCol']),
      barnRow: _i(j['barnRow']),
      startCol: _d(j['x']),
      startRow: _d(j['y']),
      isMale: _b(j['isMale'], false),
      // Eski kayıtlarda yaş yok → yetişkin varsay (default ctor değeri).
      ageDays: j['ageDays'] == null
          ? AnimalEntity.kAnimalAdultDay
          : _d(j['ageDays']),
      lifespanDays: j['lifespanDays'] == null ? null : _d(j['lifespanDays']),
    );
    a.hunger = _d(j['hunger']);
    a.milkProgress = _d(j['milkProgress']);
    a.facingRight = _b(j['facingRight'], true);
    a.facing4 = _enumByName(AnimalFacing.values, j['facing4'], AnimalFacing.s);
    final fert = j['fertilityDays'];
    if (fert != null) a.fertilityDays = _d(fert);
    return a;
  }

  BuildOrder _orderFromJson(Map<String, dynamic> j) {
    final o = BuildOrder(
      type: _enumByName(BuildingType.values, j['type'], BuildingType.firepit),
      col: _i(j['col']),
      row: _i(j['row']),
      design: _enumByName(
        BuildingDesign.values,
        j['design'],
        BuildingDesign.original,
      ),
    );
    o.crew = 0; // geçici — builder yeniden talep eder
    o.completed = _b(j['completed']);
    o.progress = _d(j['progress']);
    return o;
  }

  RoadOrder _roadOrderFromJson(Map<String, dynamic> j) {
    final o = RoadOrder(
      col: _i(j['col']),
      row: _i(j['row']),
      surface: _enumByName(RoadSurface.values, j['surface'], RoadSurface.dirt),
    );
    o.assigned = false;
    o.completed = _b(j['completed']);
    o.progress = _d(j['progress']);
    return o;
  }

  FarmTile _farmTileFromJson(Map<String, dynamic> j) {
    final t = FarmTile(_i(j['col']), _i(j['row']));
    t.stage = _i(j['stage']);
    t.growthProgress = _d(j['growthProgress']);
    // Eski kayıtlarda ekim yoktu — tarlalar ekili sayılır (yükleyince köy
    // birden çıplak toprağa dönmesin).
    t.needsSowing = j['needsSowing'] as bool? ?? false;
    t.fallowRemaining = _d(j['fallow']);
    return t;
  }

  TreeEntity _treeFromJson(Map<String, dynamic> j) {
    final t = TreeEntity(
      col: _i(j['col']),
      row: _i(j['row']),
      type: _enumByName(TreeType.values, j['type'], TreeType.pine),
      isGrowing: _b(j['growing']),
      isWild: _b(j['wild']),
    );
    t.isMarkedForCutting = _b(j['marked']);
    t.isFelled = _b(j['felled']);
    t.fellAge = _d(j['fellAge']);
    t.fallDirection = _i(j['fallDirection'], 1) < 0 ? -1 : 1;
    t.fallImpactEmitted = _b(j['fallImpactEmitted']);
    return t;
  }

  MineNode _mineNodeFromJson(Map<String, dynamic> j) {
    final n = MineNode(
      col: _i(j['col']),
      row: _i(j['row']),
      type: _enumByName(OreType.values, j['type'], OreType.stone),
    );
    n.isMarkedForMining = _b(j['marked']);
    n.isDepleted = _b(j['depleted']);
    return n;
  }

  DecorEntity _decorFromJson(Map<String, dynamic> j) => DecorEntity(
    col: _i(j['col']),
    row: _i(j['row']),
    kind: _enumByName(DecorKind.values, j['kind'], DecorKind.daisy),
    variant: _i(j['variant']),
    jitterX: _d(j['jitterX']),
    jitterY: _d(j['jitterY']),
    swaySeed: _i(j['swaySeed']),
  );

  /// Eski kayıtlarda ilgi noktası alanı yoktur. Aynı dünya seed'inden bugünkü
  /// adayları türet, fakat köyün yıllar içinde kapladığı hiçbir tile'ın üstüne
  /// düşürme. Uygun olmayan aday sessizce atlanır; oyuncunun yapısı korunur.
  void _seedLandmarksForLegacySave() {
    final occupied = <(int, int)>{
      ..._waterTiles,
      for (final t in _trees) (t.col, t.row),
      for (final n in _mineNodes) (n.col, n.row),
      for (final f in _farmTiles) (f.col, f.row),
      for (final r in _roadSystem.all) (r.col, r.row),
      for (final d in _decor) (d.col, d.row),
      for (final r in _reeds) ...[(r.col, r.row), (r.col2, r.row2)],
    };
    for (final b in _buildings) {
      for (var c = b.col; c < b.col + b.cols; c++) {
        for (var r = b.row; r < b.row + b.rows; r++) {
          occupied.add((c, r));
        }
      }
    }
    for (final o in _orders) {
      final meta = kBuildingMeta[o.type]!;
      for (var c = o.col; c < o.col + meta.cols; c++) {
        for (var r = o.row; r < o.row + meta.rows; r++) {
          occupied.add((c, r));
        }
      }
    }
    for (final site in WorldGenerator(_worldSeed).generate().landmarks) {
      if (!occupied.contains((site.col, site.row))) {
        _landmarks.add(site);
      }
    }
  }

  Grave _graveFromJson(Map<String, dynamic> j) => Grave(
    col: _d(j['col']),
    row: _d(j['row']),
    variant: _i(j['variant']),
    name: (j['name'] as String?) ?? '',
    jitterX: _d(j['jitterX']),
    jitterY: _d(j['jitterY']),
  );
}
