part of '../main.dart';

/// Tam dünya kayıt/yükleme — köyün TÜM kalıcı state'ini JSON'a çevirir ve
/// kaldığı yerden geri kurar. Köylüler (isim/yaş/aile/moral/görsel kimlik),
/// binalar, kaynaklar, zümreler, dilekçe hafızası, harita, gün/saat dahil.
///
/// Tasarım:
///  - Kimlik yok → referanslar İNDEKS ile çözülür (köylü/bina liste sırası).
///    Yükleme aynı sırada kurar, sonra parents/children/homeBuilding bağlanır.
///  - Geçici state (görev hedefi, path cache, render lerp, anlık duygu/oturma)
///    KAYDEDİLMEZ → yükleme sonrası işçiler hedefi yeniden bulur, cache yeniden
///    türetilir. Görünür sonuç birebir aynı köy, içeride taze AI.
///  - Su tile'ları doğrudan kaydedilir → generator determinizmine bağımlı değil.
extension _SceneSave on _VillageSceneState {
  // ── Yardımcılar ────────────────────────────────────────────────────────────

  int _colInt(Color c) => c.toARGB32();
  Color _colFromInt(int v) => Color(v);

  T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
    if (name is String) {
      for (final v in values) {
        if (v.name == name) return v;
      }
    }
    return fallback;
  }

  double _d(Object? v, [double fb = 0]) => (v as num?)?.toDouble() ?? fb;
  int _i(Object? v, [int fb = 0]) => (v as num?)?.toInt() ?? fb;
  bool _b(Object? v, [bool fb = false]) => (v as bool?) ?? fb;

  // ── NpcVisual ──────────────────────────────────────────────────────────────

  Map<String, dynamic> _visualToJson(NpcVisual v) => {
        'skin': _colInt(v.skin),
        'hair': _colInt(v.hair),
        'hairStyle': v.hairStyle.name,
        'eyes': _colInt(v.eyes),
        'hasBeard': v.hasBeard,
        'beardStyle': v.beardStyle.name,
        'clothingShift': v.clothingShift,
        'blinkPhase': v.blinkPhase,
        'isMale': v.isMale,
      };

  NpcVisual _visualFromJson(Map<String, dynamic> j) => NpcVisual(
        skin: _colFromInt(_i(j['skin'], 0xFFFFCB9A)),
        hair: _colFromInt(_i(j['hair'], 0xFF3E2A14)),
        hairStyle: _enumByName(HairStyle.values, j['hairStyle'], HairStyle.short),
        eyes: _colFromInt(_i(j['eyes'], 0xFF4A381E)),
        hasBeard: _b(j['hasBeard']),
        beardStyle:
            _enumByName(BeardStyle.values, j['beardStyle'], BeardStyle.none),
        clothingShift: _d(j['clothingShift']),
        blinkPhase: _d(j['blinkPhase']),
        isMale: _b(j['isMale'], true),
      );

  // ── Kayıt tetikleyiciler ────────────────────────────────────────────────────

  /// Gerçek-zaman birikimiyle periyodik otomatik kayıt. _onTick her frame çağırır.
  void _maybeAutoSave(double realDt) {
    _autoSaveAccum += realDt;
    if (_autoSaveAccum >= _VillageSceneState._kAutoSaveInterval) {
      _autoSaveAccum = 0;
      _saveNow();
    }
  }

  /// Mevcut köyü slota yazar (async, fire-and-forget). [manual] true ise
  /// kullanıcıya kısa "Kaydedildi" geri bildirimi gösterir.
  Future<void> _saveNow({bool manual = false}) async {
    if (_saving || _slotId.isEmpty) return;
    _saving = true;
    try {
      final data = <String, dynamic>{
        'version': SaveManager.schemaVersion,
        'meta': SaveSlotMeta(
          id: _slotId,
          name: _slotName,
          savedAt: DateTime.now(),
          day: _dayCount,
          population: _villagers.length,
          identity: _houses.identityName,
        ).toJson(),
        'world': captureWorld(),
      };
      await SaveManager.instance.writeSlot(_slotId, data);
      if (manual && mounted) {
        _showNotification('💾 Köy kaydedildi');
      }
    } catch (_) {
      if (manual && mounted) _showNotification('⚠ Kayıt başarısız');
    } finally {
      _saving = false;
    }
  }

  /// Sol-alttaki menü kümesi — tek "⚙" tutamağı altında menü/kaydet/📖 toplanır
  /// (dağınık chip'ler yerine derli toplu). Açılınca öğeler gear'ın ÜSTÜNDE
  /// belirir (alttaki inşa çubuğundan uzakta). Varsayılan kapalı (sade ekran).
  Widget buildSaveButton() {
    return Positioned(
      left: 14,
      bottom: 78,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_menuClusterOpen) ...[
              // Ana menüye dönüş — onay ister, onaylanınca kaydedip çıkar.
              MenuButton(
                onTap: () => setStateHere(() => _exitConfirmOpen = true),
              ),
              const SizedBox(height: 10),
              SaveButton(onTap: () => _saveNow(manual: true)),
              const SizedBox(height: 10),
              // Hikâye güncesi — büyük anların kaydı (sinematik özetleri).
              GestureDetector(
                onTap: () => setStateHere(() => _storyPanelOpen = true),
                child: AppChip(label: '📖 Hikâye', color: AppUi.accent),
              ),
              const SizedBox(height: 10),
            ],
            // Gear tutamağı — her zaman görünür; kümeyi aç/kapa.
            GestureDetector(
              onTap: () =>
                  setStateHere(() => _menuClusterOpen = !_menuClusterOpen),
              child: AppChip(
                label: _menuClusterOpen ? '⚙ Kapat' : '⚙ Menü',
                color: AppUi.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Ana menüye dönüş onay modal'ı — yanlışlıkla çıkışı önler. Çıkış
  /// otomatik kaydeder, böylece oyuncu hiçbir ilerleme kaybetmez.
  Widget buildExitConfirm() {
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setStateHere(() => _exitConfirmOpen = false),
              child: Container(color: const Color(0x99000000)),
            ),
          ),
          Center(
            child: AppPanel(
              width: 320,
              accent: AppUi.accent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ana menüye dön', style: AppUi.title),
                  const SizedBox(height: 8),
                  Text(
                    'Köy otomatik kaydedilecek ve ana menüye döneceksin. '
                    'Kaldığın yerden devam edebilirsin.',
                    style: AppUi.body.copyWith(color: AppUi.textMid),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: 'Vazgeç',
                          kind: AppButtonKind.ghost,
                          onTap: () =>
                              setStateHere(() => _exitConfirmOpen = false),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppButton(
                          label: 'Kaydet ve Çık',
                          kind: AppButtonKind.filled,
                          onTap: _exitToMenu,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Kaydeder ve ana menüye döner.
  Future<void> _exitToMenu() async {
    setStateHere(() => _exitConfirmOpen = false);
    await _saveNow();
    widget.onExitToMenu?.call();
  }

  // ── Capture (state → JSON) ──────────────────────────────────────────────────

  /// Tüm dünyayı JSON-uyumlu bir map'e çevirir.
  Map<String, dynamic> captureWorld() {
    // Referans çözümü için indeks tabloları.
    final bIndex = <BuildingEntity, int>{};
    for (var i = 0; i < _buildings.length; i++) {
      bIndex[_buildings[i]] = i;
    }
    final vIndex = <VillagerEntity, int>{};
    for (var i = 0; i < _villagers.length; i++) {
      vIndex[_villagers[i]] = i;
    }
    int bRef(Object? b) => b is BuildingEntity ? (bIndex[b] ?? -1) : -1;
    int vRef(Object? v) => v is VillagerEntity ? (vIndex[v] ?? -1) : -1;

    return {
      // ── Skaler sim state ──
      'time': _time,
      'worldSeed': _worldSeed,
      'dayCount': _dayCount,
      'lastTimeOfDay': _lastTimeOfDay,
      'timeOfDay': _cycle.timeOfDay,
      'camera': [_camera.dx, _camera.dy],
      'zoom': _zoom,
      'speedIdx': _speedIdx,
      'morale': _morale,
      'avgIndividualMorale': _avgIndividualMorale,
      'foodHunger': _foodHunger,
      'hasFire': _hasFire,
      'charterTier': _charterTier,
      'governanceLegacy': _governanceLegacy,
      'lastPopMilestone': _lastPopMilestone,
      'firstReedBedShown': _firstReedBedShown,
      'firepit': bRef(_firepitBuilding),
      'firekeeper': vRef(_firekeeper),

      // ── Harita + kaynaklar + sistemler ──
      'water': [for (final t in _waterTiles) [t.$1, t.$2]],
      'stockpile': _stockpileToJson(),
      'policies': _policiesToJson(),
      'houses': _houses.toJson(),
      'completedQuests': _completedQuests.toList(),
      'villageMemory': _villageMemory.toList(),
      // Hikâye güncesi (yapısal) + başarımlar + sinematik durumu (anılar kalıcı).
      'storyLog': [for (final e in _storyLog) e.toJson()],
      'achievedMilestones': _achievedMilestones.toList(),
      'villageName': _villageName,
      'famineShown': _famineShown,
      'tierCutscenesShown': _tierCutscenesShown.toList(),
      'imperialFavor': _imperialFavor,
      'imperialTimer': _imperialTimer,

      // ── Varlıklar ──
      'buildings': [for (final b in _buildings) _buildingToJson(b)],
      'villagers': [for (final v in _villagers) _villagerToJson(v, bRef, vRef)],
      'builders': [for (final b in _builders) _workerBaseToJson(b)],
      'orders': [for (final o in _orders) _orderToJson(o)],
      'roadOrders': [for (final o in _roadOrders) _roadOrderToJson(o)],
      'roads': [for (final t in _roadSystem.all) _roadTileToJson(t)],
      'farmTiles': [for (final t in _farmTiles) _farmTileToJson(t)],
      'farmers': [for (final f in _farmers) _workerBaseToJson(f)],
      'trees': [for (final t in _trees) _treeToJson(t)],
      // Açılmış kara — vahşi orman/sınır türetildiği tek kaynak (scene_land).
      'cleared': [for (final (c, r) in _cleared) [c, r]],
      'woodcutters': [for (final w in _woodcutters) _workerBaseToJson(w)],
      'lumberCamps': [for (final c in _lumberCamps) _lumberCampToJson(c)],
      'mineNodes': [for (final n in _mineNodes) _mineNodeToJson(n)],
      'miners': [for (final m in _miners) _workerBaseToJson(m)],
      'fishers': [for (final f in _fishers) _workerBaseToJson(f)],
      'florists': [for (final f in _florists) _floristToJson(f)],
      'shepherds': [for (final s in _shepherds) _shepherdToJson(s)],
      'animals': [for (final a in _cows) _animalToJson(a)],
      'lotuses': [for (final l in _lotuses) {'col': l.col, 'row': l.row, 'variant': l.variant}],
      'reeds': [for (final r in _reeds) _reedClumpToJson(r)],
      'decor': [for (final d in _decor) _decorToJson(d)],
      'graves': [for (final g in _graves) _graveToJson(g)],
      'reedBeds': [for (final b in _reedBeds) {'x': b.gridX, 'y': b.gridY, 'owner': vRef(b.owner)}],
      'resourceBoxes': [for (final r in _resourceBoxes) _resourceBoxToJson(r)],
      'hay': [for (final h in _hayEntities) _hayToJson(h)],

      // ── Dilekçe / meclis ──
      'pendingPetition': _pendingPetition?.id,
      'petitionAuthor': vRef(_petitionAuthor),
      'petitionTimer': _petitionTimer,
      'petitionDeadline': _petitionDeadline,
      'petitionModalOpen': _petitionModalOpen,
      'petitionForced': _petitionForced,
      'petitionFollowUps':
          [for (final f in _petitionFollowUps) {'id': f.id, 'fireAtSim': f.fireAtSim}],
      'petitionCooldowns': _petitionCooldowns,

      // ── Olay / politika moral / ambient timer ──
      'eventTimer': _eventTimer,
      'eventMorale': _eventMorale,
      'eventMoraleLeft': _eventMoraleLeft,
      'eventLabel': _eventLabel,
      'policyMoraleEffects':
          [for (final e in _policyMoraleEffects) {'untilSim': e.untilSim, 'amount': e.amount}],
      'migrationTimerSec': _migrationTimerSec,
      'meteorShowerTimer': _meteorShowerTimer,
    };
  }

  Map<String, dynamic> _stockpileToJson() => {
        'wood': _stockpile.wood,
        'stone': _stockpile.stone,
        'iron': _stockpile.iron,
        'coal': _stockpile.coal,
        'food': _stockpile.food,
        'honey': _stockpile.honey,
        'reed': _stockpile.reed,
        'gold': _stockpile.gold,
      };

  Map<String, dynamic> _policiesToJson() => {
        'family': _policies.family.name,
        'familyEncouragement': _policies.familyEncouragement,
        'peacefulEnd': _policies.peacefulEnd,
        'eldersExemptFromFood': _policies.eldersExemptFromFood,
        'hospitality': _policies.hospitality,
        'apprenticeship': _policies.apprenticeship,
        'tradeGuidance': _policies.tradeGuidance,
        'slowMaturity': _policies.slowMaturity,
        'neighborliness': _policies.neighborliness,
        'familyReunion': _policies.familyReunion,
        'treePlanting': _policies.treePlanting,
        'sharedHarvest': _policies.sharedHarvest,
        'cropRotation': _policies.cropRotation,
        'greenVillage': _policies.greenVillage,
        'freeRange': _policies.freeRange,
        'herdGrowth': _policies.herdGrowth,
        'winterFodder': _policies.winterFodder,
        'cooldownUntilSim': _policies.cooldownUntilSim,
      };

  Map<String, dynamic> _buildingToJson(BuildingEntity b) => {
        'type': b.type.name,
        'col': b.col,
        'row': b.row,
        'isActive': b.isActive,
        'userPaused': b.userPaused,
        'growthProgress': b.growthProgress,
        'incomeTimer': b.incomeTimer,
        'waterLevel': b.waterLevel,
        'occupants': b.occupants,
        'eggTimer': b.eggTimer,
        'honeyTimer': b.honeyTimer,
        'fireFuel': b.fireFuel,
      };

  Map<String, dynamic> _villagerToJson(
      VillagerEntity v, int Function(Object?) bRef, int Function(Object?) vRef) {
    return {
      'type': v.type.name,
      'name': v.name,
      'visual': _visualToJson(v.visual),
      'personalitySeed': v.personalitySeed,
      'annivCount': v.annivCount,
      'callingFound': v.callingFound,
      'spawnCol': v.spawnCol,
      'spawnRow': v.spawnRow,
      'x': v.gridX,
      'y': v.gridY,
      'facingRight': v.facingRight,
      'ageDays': v.ageDays,
      'lifespanDays': v.lifespanDays.isFinite ? v.lifespanDays : null,
      'state': v.state.name,
      'targetCol': v.targetCol,
      'targetRow': v.targetRow,
      'isFavorite': v.isFavorite,
      'wed': v.wed,
      if (v.surname.isNotEmpty) 'surname': v.surname,
      if (v.injuryDays > 0) 'injuryDays': v.injuryDays,
      if (v.disabled) 'disabled': true,
      'life': [for (final e in v.life) e.toJson()],
      'fertilityDays': v.fertilityDays.isNaN ? null : v.fertilityDays,
      'birthCount': v.birthCount,
      'isSage': v.isSage,
      'mood': v.mood,
      'energy': v.energy,
      'morale': v.morale,
      'lowMoraleTime': v.lowMoraleTime,
      'moraleReason': v.moraleReason,
      'wealth': v.wealth,
      'home': bRef(v.homeBuilding),
      'parents': [for (final p in v.parents) vRef(p)],
      'children': [for (final c in v.children) vRef(c)],
      'grudges': [
        for (final e in v.grudges.entries)
          {'v': vRef(e.key), 'until': e.value}
      ],
      'bloodEnemies': [for (final e in v.bloodEnemies) vRef(e)],
      'feudKills': v.feudKills,
    };
  }

  /// İşçi base — pozisyon + dolaşma merkezi (spawn). Görev/path state taşınmaz.
  Map<String, dynamic> _workerBaseToJson(WorkerEntity w) => {
        'spawnCol': w.spawnCol,
        'spawnRow': w.spawnRow,
        'x': w.gridX,
        'y': w.gridY,
        'facingRight': w.facingRight,
      };

  Map<String, dynamic> _lumberCampToJson(LumberCampEntity c) => {
        'buildingCol': c.buildingCol,
        'buildingRow': c.buildingRow,
        'x': c.gridX,
        'y': c.gridY,
        'facingRight': c.facingRight,
      };

  Map<String, dynamic> _shepherdToJson(ShepherdEntity s) => {
        'barnCol': s.barnCol,
        'barnRow': s.barnRow,
        'x': s.gridX,
        'y': s.gridY,
        'facingRight': s.facingRight,
      };

  Map<String, dynamic> _floristToJson(FloristEntity f) => {
        'cottageCol': f.cottageCol,
        'cottageRow': f.cottageRow,
        'effectRadius': f.effectRadius,
        'spawnCol': f.spawnCol,
        'spawnRow': f.spawnRow,
        'x': f.gridX,
        'y': f.gridY,
        'facingRight': f.facingRight,
      };

  Map<String, dynamic> _animalToJson(AnimalEntity a) => {
        'kind': a.kind.name,
        'barnCol': a.barnCol,
        'barnRow': a.barnRow,
        'x': a.gridX,
        'y': a.gridY,
        'facingRight': a.facingRight,
        'facing4': a.facing4.name,
        'hunger': a.hunger,
        'milkProgress': a.milkProgress,
        'isMale': a.isMale,
        'ageDays': a.ageDays,
        'lifespanDays': a.lifespanDays,
        'fertilityDays':
            a.fertilityDays.isNaN ? null : a.fertilityDays,
      };

  Map<String, dynamic> _orderToJson(BuildOrder o) => {
        'type': o.type.name,
        'col': o.col,
        'row': o.row,
        'assigned': o.assigned,
        'completed': o.completed,
        'progress': o.progress,
      };

  Map<String, dynamic> _roadOrderToJson(RoadOrder o) => {
        'col': o.col,
        'row': o.row,
        'surface': o.surface.name,
        'assigned': o.assigned,
        'completed': o.completed,
        'progress': o.progress,
      };

  Map<String, dynamic> _roadTileToJson(RoadTile t) =>
      {'col': t.col, 'row': t.row, 'surface': t.surface.name};

  Map<String, dynamic> _farmTileToJson(FarmTile t) => {
        'col': t.col,
        'row': t.row,
        'stage': t.stage,
        'growthProgress': t.growthProgress,
      };

  Map<String, dynamic> _treeToJson(TreeEntity t) => {
        'col': t.col,
        'row': t.row,
        'type': t.type.name,
        'marked': t.isMarkedForCutting,
        'felled': t.isFelled,
        'growing': t.isGrowing,
        'wild': t.isWild,
      };

  Map<String, dynamic> _mineNodeToJson(MineNode n) => {
        'col': n.col,
        'row': n.row,
        'type': n.type.name,
        'marked': n.isMarkedForMining,
        'depleted': n.isDepleted,
      };

  Map<String, dynamic> _reedClumpToJson(ReedClump r) => {
        'col': r.col,
        'row': r.row,
        'col2': r.col2,
        'row2': r.row2,
        'growth': r.growth,
      };

  Map<String, dynamic> _decorToJson(DecorEntity d) => {
        'col': d.col,
        'row': d.row,
        'kind': d.kind.name,
        'variant': d.variant,
        'jitterX': d.jitterX,
        'jitterY': d.jitterY,
        'swaySeed': d.swaySeed,
      };

  Map<String, dynamic> _graveToJson(Grave g) => {
        'col': g.col,
        'row': g.row,
        'variant': g.variant,
        'name': g.name,
        'jitterX': g.jitterX,
        'jitterY': g.jitterY,
      };

  Map<String, dynamic> _resourceBoxToJson(ResourceBox r) => {
        'type': r.type.name,
        'x': r.gridX,
        'y': r.gridY,
        'slotIndex': r.slotIndex,
      };

  Map<String, dynamic> _hayToJson(HayEntity h) => {
        'type': h.type.name,
        'x': h.gridX,
        'y': h.gridY,
        'slotIndex': h.slotIndex,
        'pileSize': h.pileSize,
      };

  // ── Restore (JSON → state) ──────────────────────────────────────────────────

  /// Kaydedilmiş dünyayı geri kurar. initState'ten (asset yüklemeden önce)
  /// `_generateWorld` yerine çağrılır → setState KULLANMAZ.
  void restoreWorld(Map<String, dynamic> w) {
    // 1) Her şeyi temizle (generator'ın yaptığı scaffolding ama generator yok).
    _waterTiles.clear();
    _lotuses.clear();
    _reeds.clear();
    _reedBeds.clear();
    _decor.clear();
    _trees.clear();
    _cleared.clear();
    _wilderness.clear();
    _wildTreeTiles.clear();
    _mineNodes.clear();
    _buildings.clear();
    _orders.clear();
    _roadOrders.clear();
    _roadSystem.clear();
    _placingRoad = null;
    _roadStrokeTiles.clear();
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
    _graves.clear();
    _petitionFollowUps.clear();
    _petitionCooldowns.clear();
    _villageMemory.clear();
    _completedQuests.clear();
    _storyLog.clear();
    _achievedMilestones.clear();
    _tierCutscenesShown.clear();
    _activeCutscene = null; // yüklenen oyunda sinematik oynamaz
    _policyMoraleEffects.clear();
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
    _pendingChoice = null;
    _activeEvent = null;

    // 2) Skaler state.
    _time = _d(w['time']);
    _worldSeed = _i(w['worldSeed']);
    _dayCount = _i(w['dayCount'], 1);
    _lastTimeOfDay = _d(w['lastTimeOfDay']);
    _cycle.timeOfDay = _d(w['timeOfDay'], 0.45);
    final cam = w['camera'];
    if (cam is List && cam.length == 2) {
      _camera = Offset(_d(cam[0]), _d(cam[1]));
    }
    _zoom = _d(w['zoom'], 1.0);
    _speedIdx =
        _i(w['speedIdx']).clamp(0, _VillageSceneState._speedSteps.length - 1);
    _timeScale = _VillageSceneState._speedSteps[_speedIdx];
    _morale = _d(w['morale'], 0.5);
    _avgIndividualMorale = _d(w['avgIndividualMorale'], 0.6);
    _foodHunger = _d(w['foodHunger']);
    _hasFire = _b(w['hasFire']);
    _charterTier = _i(w['charterTier']);
    _governanceLegacy = _d(w['governanceLegacy']);
    _lastPopMilestone = _i(w['lastPopMilestone']);
    _firstReedBedShown = _b(w['firstReedBedShown']);

    // 3) Harita / kaynaklar / sistemler.
    for (final t in (w['water'] as List? ?? const [])) {
      if (t is List && t.length == 2) _waterTiles.add((_i(t[0]), _i(t[1])));
    }
    _restoreStockpile(w['stockpile']);
    _restorePolicies(w['policies']);
    if (w['houses'] is Map) {
      _houses.loadJson(Map<String, dynamic>.from(w['houses'] as Map));
    }
    for (final q in (w['completedQuests'] as List? ?? const [])) {
      _completedQuests.add(q as String);
    }
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
    _villageName = (w['villageName'] as String?) ?? 'Köy';
    _imperialFavor = _d(w['imperialFavor'], 0.5);
    _imperialTimer = _d(w['imperialTimer'], 6.0 * kGameDaySeconds);
    _imperialDemand = null; // yüklemede aktif ziyaret yok
    _famineShown = _b(w['famineShown']);
    for (final t in (w['tierCutscenesShown'] as List? ?? const [])) {
      _tierCutscenesShown.add(_i(t));
    }
    for (final f in (w['villageMemory'] as List? ?? const [])) {
      _villageMemory.add(f as String);
    }

    // 4) Binalar (önce — referans hedefi).
    for (final raw in (w['buildings'] as List? ?? const [])) {
      _buildings.add(_buildingFromJson(Map<String, dynamic>.from(raw as Map)));
    }

    // 5) Köylüler — iki geçiş (önce yarat, sonra aile/ev bağla).
    final vJsons = <Map<String, dynamic>>[
      for (final raw in (w['villagers'] as List? ?? const []))
        Map<String, dynamic>.from(raw as Map)
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
      for (final e in (vj['bloodEnemies'] as List? ?? const [])) {
        final ei = _i(e, -1);
        if (ei >= 0 && ei < _villagers.length) {
          v.bloodEnemies.add(_villagers[ei]);
        }
      }
    }

    // 6) Referans wiring (firepit / firekeeper).
    final fpIdx = _i(w['firepit'], -1);
    _firepitBuilding =
        (fpIdx >= 0 && fpIdx < _buildings.length) ? _buildings[fpIdx] : null;
    final fkIdx = _i(w['firekeeper'], -1);
    _firekeeper =
        (fkIdx >= 0 && fkIdx < _villagers.length) ? _villagers[fkIdx] : null;

    // 7) İşçiler + hayvanlar.
    for (final raw in (w['builders'] as List? ?? const [])) {
      final j = Map<String, dynamic>.from(raw as Map);
      _builders.add(_applyWorkerBase(
          BuilderEntity(startCol: _d(j['spawnCol']), startRow: _d(j['spawnRow'])),
          j));
    }
    for (final raw in (w['farmers'] as List? ?? const [])) {
      final j = Map<String, dynamic>.from(raw as Map);
      _farmers.add(_applyWorkerBase(
          FarmFarmer(startCol: _d(j['spawnCol']), startRow: _d(j['spawnRow'])),
          j));
    }
    for (final raw in (w['woodcutters'] as List? ?? const [])) {
      final j = Map<String, dynamic>.from(raw as Map);
      _woodcutters.add(_applyWorkerBase(
          WoodcutterEntity(
              startCol: _d(j['spawnCol']), startRow: _d(j['spawnRow'])),
          j));
    }
    for (final raw in (w['miners'] as List? ?? const [])) {
      final j = Map<String, dynamic>.from(raw as Map);
      _miners.add(_applyWorkerBase(
          MinerEntity(startCol: _d(j['spawnCol']), startRow: _d(j['spawnRow'])),
          j));
    }
    for (final raw in (w['fishers'] as List? ?? const [])) {
      final j = Map<String, dynamic>.from(raw as Map);
      _fishers.add(_applyWorkerBase(
          FisherEntity(startCol: _d(j['spawnCol']), startRow: _d(j['spawnRow'])),
          j));
    }
    for (final raw in (w['lumberCamps'] as List? ?? const [])) {
      final j = Map<String, dynamic>.from(raw as Map);
      _lumberCamps.add(_applyWorkerBase(
          LumberCampEntity(
              buildingCol: _i(j['buildingCol']),
              buildingRow: _i(j['buildingRow'])),
          j));
    }
    for (final raw in (w['shepherds'] as List? ?? const [])) {
      final j = Map<String, dynamic>.from(raw as Map);
      _shepherds.add(_applyWorkerBase(
          ShepherdEntity(barnCol: _i(j['barnCol']), barnRow: _i(j['barnRow'])),
          j));
    }
    for (final raw in (w['florists'] as List? ?? const [])) {
      final j = Map<String, dynamic>.from(raw as Map);
      _florists.add(_applyWorkerBase(
          FloristEntity(
              startCol: _d(j['spawnCol']),
              startRow: _d(j['spawnRow']),
              cottageCol: _i(j['cottageCol']),
              cottageRow: _i(j['cottageRow']),
              effectRadius: _d(j['effectRadius'])),
          j));
    }
    for (final raw in (w['animals'] as List? ?? const [])) {
      _cows.add(_animalFromJson(Map<String, dynamic>.from(raw as Map)));
    }

    // 8) Dünya nesneleri.
    for (final raw in (w['orders'] as List? ?? const [])) {
      _orders.add(_orderFromJson(Map<String, dynamic>.from(raw as Map)));
    }
    for (final raw in (w['roadOrders'] as List? ?? const [])) {
      _roadOrders.add(_roadOrderFromJson(Map<String, dynamic>.from(raw as Map)));
    }
    for (final raw in (w['roads'] as List? ?? const [])) {
      final j = Map<String, dynamic>.from(raw as Map);
      _roadSystem.add(RoadTile(
          col: _i(j['col']),
          row: _i(j['row']),
          surface:
              _enumByName(RoadSurface.values, j['surface'], RoadSurface.dirt)));
    }
    for (final raw in (w['farmTiles'] as List? ?? const [])) {
      _farmTiles.add(_farmTileFromJson(Map<String, dynamic>.from(raw as Map)));
    }
    for (final raw in (w['trees'] as List? ?? const [])) {
      _trees.add(_treeFromJson(Map<String, dynamic>.from(raw as Map)));
    }
    for (final raw in (w['mineNodes'] as List? ?? const [])) {
      _mineNodes.add(_mineNodeFromJson(Map<String, dynamic>.from(raw as Map)));
    }
    // Açılmış kara → vahşi orman/sınır türet (trees + mineNodes yüklendikten
    // SONRA). Eski kayıtta 'cleared' yoksa boş kalır; _initLand çağrılmaz, bu
    // yüzden eski kayıtlar tüm haritayı açık (wilderness boş) görür — sorunsuz.
    for (final raw in (w['cleared'] as List? ?? const [])) {
      final p = raw as List;
      _cleared.add((_i(p[0]), _i(p[1])));
    }
    if (_cleared.isNotEmpty) _rebuildLandDerived();
    for (final raw in (w['lotuses'] as List? ?? const [])) {
      final j = Map<String, dynamic>.from(raw as Map);
      _lotuses.add(LotusEntity(
          col: _i(j['col']), row: _i(j['row']), variant: _i(j['variant'])));
    }
    for (final raw in (w['reeds'] as List? ?? const [])) {
      final j = Map<String, dynamic>.from(raw as Map);
      _reeds.add(ReedClump(
          col: _i(j['col']),
          row: _i(j['row']),
          col2: _i(j['col2']),
          row2: _i(j['row2']),
          growth: _d(j['growth'], 1.0)));
    }
    for (final raw in (w['decor'] as List? ?? const [])) {
      _decor.add(_decorFromJson(Map<String, dynamic>.from(raw as Map)));
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
      _resourceBoxes.add(ResourceBox(
          type: _enumByName(
              ResourceBoxType.values, j['type'], ResourceBoxType.woodChunk),
          gridX: _d(j['x']),
          gridY: _d(j['y']))
        ..slotIndex = _i(j['slotIndex']));
    }
    for (final raw in (w['hay'] as List? ?? const [])) {
      final j = Map<String, dynamic>.from(raw as Map);
      _hayEntities.add(HayEntity(
          type: _enumByName(HayType.values, j['type'], HayType.pile),
          gridX: _d(j['x']),
          gridY: _d(j['y']))
        ..slotIndex = _i(j['slotIndex'])
        ..pileSize = _i(j['pileSize'], 1));
    }

    // 9) Dilekçe / meclis.
    final pid = w['pendingPetition'];
    _pendingPetition = pid is String ? PetitionSystem.byId(pid) : null;
    final paIdx = _i(w['petitionAuthor'], -1);
    _petitionAuthor =
        (paIdx >= 0 && paIdx < _villagers.length) ? _villagers[paIdx] : null;
    _petitionTimer = _d(w['petitionTimer'], 1.0 * kGameDaySeconds);
    _petitionDeadline = _d(w['petitionDeadline']);
    _petitionModalOpen = _b(w['petitionModalOpen']) && _pendingPetition != null;
    _petitionForced = _b(w['petitionForced']) && _pendingPetition != null;
    // Bekleyen düğün çifte bağlıdır (kaydedilmez) — yüklemede uygun bir çift
    // yeniden bağla ki sahne/sinematik tam deneyimle çözülsün (yoksa jenerik).
    _weddingCouple =
        _pendingPetition?.id == 'villageWedding' ? _findCourtship() : null;
    for (final raw in (w['petitionFollowUps'] as List? ?? const [])) {
      final j = Map<String, dynamic>.from(raw as Map);
      _petitionFollowUps
          .add((id: j['id'] as String, fireAtSim: _d(j['fireAtSim'])));
    }
    final cds = w['petitionCooldowns'];
    if (cds is Map) {
      cds.forEach((k, v) => _petitionCooldowns[k as String] = _d(v));
    }

    // 10) Olay / politika moral / ambient.
    _eventTimer = _d(w['eventTimer'], kEventFirstDelay);
    _eventMorale = _d(w['eventMorale']);
    _eventMoraleLeft = _d(w['eventMoraleLeft']);
    _eventLabel = w['eventLabel'] as String?;
    for (final raw in (w['policyMoraleEffects'] as List? ?? const [])) {
      final j = Map<String, dynamic>.from(raw as Map);
      _policyMoraleEffects
          .add((untilSim: _d(j['untilSim']), amount: _d(j['amount'])));
    }
    _migrationTimerSec = _d(w['migrationTimerSec']);
    _meteorShowerTimer = _d(w['meteorShowerTimer'], 4.0 * kGameDaySeconds);

    // 11) Türetilmiş yapıları yeniden kur.
    _applyPolicySideChannels();
    _pathContext.bumpVersion();
    _anchorSystem.rebuild(_buildings);
    _rebuildSpatialCaches();
    _rebuildBeeSwarms();
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
    _stockpile.gold = _i(j['gold']);
  }

  void _restorePolicies(Object? j) {
    if (j is! Map) return;
    _policies.family =
        _enumByName(FamilyPolicy.values, j['family'], FamilyPolicy.open);
    _policies.familyEncouragement = _b(j['familyEncouragement']);
    _policies.peacefulEnd = _b(j['peacefulEnd']);
    _policies.eldersExemptFromFood = _b(j['eldersExemptFromFood']);
    _policies.hospitality = _b(j['hospitality']);
    _policies.apprenticeship = _b(j['apprenticeship']);
    _policies.tradeGuidance = _b(j['tradeGuidance']);
    _policies.slowMaturity = _b(j['slowMaturity']);
    _policies.neighborliness = _b(j['neighborliness']);
    _policies.familyReunion = _b(j['familyReunion']);
    _policies.treePlanting = _b(j['treePlanting']);
    _policies.sharedHarvest = _b(j['sharedHarvest']);
    _policies.cropRotation = _b(j['cropRotation']);
    _policies.greenVillage = _b(j['greenVillage']);
    _policies.freeRange = _b(j['freeRange']);
    _policies.herdGrowth = _b(j['herdGrowth']);
    _policies.winterFodder = _b(j['winterFodder']);
    _policies.cooldownUntilSim = _d(j['cooldownUntilSim']);
  }

  BuildingEntity _buildingFromJson(Map<String, dynamic> j) {
    final b = BuildingEntity(
      type: _enumByName(BuildingType.values, j['type'], BuildingType.firepit),
      col: _i(j['col']),
      row: _i(j['row']),
    );
    b.isActive = _b(j['isActive']);
    b.userPaused = _b(j['userPaused']);
    b.growthProgress = _d(j['growthProgress']);
    b.incomeTimer = _d(j['incomeTimer']);
    b.waterLevel = _d(j['waterLevel'], 1.0);
    b.occupants = _i(j['occupants']);
    b.eggTimer = _d(j['eggTimer']);
    b.honeyTimer = _d(j['honeyTimer']);
    b.fireFuel = _d(j['fireFuel'], 1.0);
    return b;
  }

  VillagerEntity _villagerFromJson(Map<String, dynamic> j) {
    final visual =
        _visualFromJson(Map<String, dynamic>.from(j['visual'] as Map));
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
    // Eski kayıtta yoksa: yetişkin/yaşlı zaten çağrısını bulmuş say (an tekrar
    // tetiklenmesin); çocuk/genç ise büyürken keşfedecek.
    v.callingFound =
        _b(j['callingFound'], v.ageDays >= kAdultStartDay);
    v.gridX = _d(j['x']);
    v.gridY = _d(j['y']);
    v.renderX = v.gridX;
    v.renderY = v.gridY;
    v.facingRight = _b(j['facingRight'], true);
    v.state = _enumByName(VillagerState.values, j['state'], VillagerState.idle);
    v.targetCol = _d(j['targetCol'], v.gridX);
    v.targetRow = _d(j['targetRow'], v.gridY);
    v.isFavorite = _b(j['isFavorite']);
    v.wed = _b(j['wed']);
    v.surname = (j['surname'] as String?) ?? '';
    v.injuryDays = _d(j['injuryDays']);
    v.disabled = _b(j['disabled']);
    v.feudKills = _i(j['feudKills']);
    for (final e in (j['life'] as List? ?? const [])) {
      if (e is Map) {
        v.life.add(ChronicleEntry.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    v.fertilityDays =
        j['fertilityDays'] == null ? double.nan : _d(j['fertilityDays']);
    v.birthCount = _i(j['birthCount']);
    v.isSage = _b(j['isSage']);
    v.mood = _d(j['mood']);
    v.energy = _d(j['energy'], 1.0);
    v.morale = _d(j['morale'], 0.6);
    v.lowMoraleTime = _d(j['lowMoraleTime']);
    v.moraleReason = (j['moraleReason'] as String?) ?? 'huzurlu';
    // Eski kayıtta servet yok → yetişkinlere makul bir taban ver (0'da kalmasın).
    v.wealth = _d(j['wealth'], v.ageDays >= kAdultStartDay ? 30 : 0);
    return v;
  }

  /// İşçi base alanlarını uygula + döner (zincir için generic).
  T _applyWorkerBase<T extends WorkerEntity>(T w, Map<String, dynamic> j) {
    w.gridX = _d(j['x'], w.gridX);
    w.gridY = _d(j['y'], w.gridY);
    w.renderX = w.gridX;
    w.renderY = w.gridY;
    w.facingRight = _b(j['facingRight'], true);
    return w;
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
      lifespanDays: j['lifespanDays'] == null
          ? null
          : _d(j['lifespanDays']),
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
    );
    o.assigned = false; // builder yeniden talep eder
    o.completed = _b(j['completed']);
    o.progress = _d(j['progress']);
    return o;
  }

  RoadOrder _roadOrderFromJson(Map<String, dynamic> j) {
    final o = RoadOrder(
      col: _i(j['col']),
      row: _i(j['row']),
      surface:
          _enumByName(RoadSurface.values, j['surface'], RoadSurface.dirt),
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

  Grave _graveFromJson(Map<String, dynamic> j) => Grave(
        col: _d(j['col']),
        row: _d(j['row']),
        variant: _i(j['variant']),
        name: (j['name'] as String?) ?? '',
        jitterX: _d(j['jitterX']),
        jitterY: _d(j['jitterY']),
      );
}
