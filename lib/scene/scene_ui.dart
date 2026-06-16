part of '../main.dart';

/// build() içeriğini konsept başına alt-metotlara böler: gökyüzü, oyun canvas'ı,
/// HUD, alt araç çubuğu, seçim panelleri, overlay'ler, ipuçları.
/// part of main.dart — State'in tüm private alanlarına erişim.
extension _SceneUi on _VillageSceneState {
  // ── Sky / sun / moon / clouds (time-driven) ────────────────────────────────

  Widget buildSkyLayer(Size screen) {
    // Güneş / Ay ark sabitleri — ekran boyutuna bağlı (frame'den bağımsız).
    const kSunSize = 32.0;
    const kMoonSize = 24.0;
    final arcCx = screen.width / 2;
    final arcBy = screen.height * 0.50;
    final arcR = screen.width * 0.42;

    // Time-driven katmanlar — ListenableBuilder ile her tick yalnızca
    // bu blok rebuild olur (RepaintBoundary ile diğer katmanları
    // etkilemeden). Outer Scaffold/PopScope ağacı tick'te rebuild OLMAZ.
    return RepaintBoundary(
      child: ListenableBuilder(
        listenable: _frame,
        builder: (context, _) {
          final sunNorm = ((_cycle.timeOfDay - 0.25) / 0.50).clamp(0.0, 1.0);
          final sunAngle = pi * sunNorm;
          final sunX = arcCx + arcR * cos(sunAngle) - kSunSize / 2;
          final sunY = arcBy - arcR * sin(sunAngle) - kSunSize / 2;
          final moonT = (_cycle.timeOfDay + 0.5) % 1.0;
          final moonNorm = ((moonT - 0.25) / 0.50).clamp(0.0, 1.0);
          final moonAngle = pi * moonNorm;
          final moonX = arcCx + arcR * cos(moonAngle) - kMoonSize / 2;
          final moonY = arcBy - arcR * sin(moonAngle) - kMoonSize / 2;
          final w = screen.width;
          final wrap = w + 240.0;
          const clouds = <(double, double, double, double, double, double)>[
            (0.08, 22.0, 0.55, 2.5, 0.30, 0.50),
            (0.40, 14.0, 0.60, 2.8, 0.35, 0.40),
            (0.76, 32.0, 0.50, 2.2, 0.28, 0.50),
            (0.18, 58.0, 0.85, 5.0, 0.65, 0.35),
            (0.55, 48.0, 0.95, 5.5, 0.70, 0.30),
            (0.88, 68.0, 0.75, 4.5, 0.60, 0.45),
            (0.04, 96.0, 1.30, 9.0, 1.00, 0.25),
            (0.38, 116.0, 1.45, 9.5, 1.00, 0.20),
            (0.72, 88.0, 1.20, 8.5, 1.00, 0.30),
          ];
          return Stack(
            children: [
              PixelSky(topColor: _cycle.skyTop, midColor: _cycle.skyMid),
              Positioned.fill(
                child: StarField(opacity: _cycle.starOpacity, time: _time),
              ),
              Positioned(
                left: sunX,
                top: sunY,
                child: Opacity(
                  opacity: _cycle.sunOpacity,
                  child: PixelSun(color: _cycle.sunColor),
                ),
              ),
              Positioned(
                left: moonX - 58,
                top: moonY - 58,
                child: Opacity(
                  opacity: _cycle.moonOpacity,
                  child: SizedBox(
                    width: 140,
                    height: 140,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 140,
                          height: 140,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Color(0x30C8E8FF),
                                Color(0x00C8E8FF),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          width: 60,
                          height: 60,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Color(0x55DDEEFF),
                                Color(0x00DDEEFF),
                              ],
                            ),
                          ),
                        ),
                        const PixelMoon(),
                      ],
                    ),
                  ),
                ),
              ),
              for (final cfg in clouds)
                Positioned(
                  left: ((cfg.$1 * w) + (_time * cfg.$4)) % wrap - 120,
                  top: cfg.$2,
                  child: Opacity(
                    opacity: _cycle.cloudOpacity,
                    child: PixelCloud(
                      dark: _cycle.rainIntensity > cfg.$6,
                      scale: cfg.$3,
                      parallax: cfg.$5,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // ── Oyun canvas'ı (input + painter) ────────────────────────────────────────

  Widget buildGameCanvas() {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        _viewSize = constraints.biggest;
        return Listener(
          onPointerSignal: _onCanvasPointerSignal,
          child: GestureDetector(
            onScaleStart: _onCanvasScaleStart,
            onScaleUpdate: _onCanvasScaleUpdate,
            onScaleEnd: _onCanvasScaleEnd,
            onTapUp: _onCanvasTapUp,
            child: MouseRegion(
              onHover: _onCanvasHover,
              child: RepaintBoundary(
                child: ListenableBuilder(
                  listenable: _frame,
                  builder: (_, _) => CustomPaint(
                    painter: VillageGamePainter(
                      villagers: _villagers,
                      buildings: _buildings,
                      builders: _builders,
                      pendingOrders: _orders,
                      roadSystem: _roadSystem,
                      pendingRoadOrders: _roadOrders,
                      camera: _camera,
                      ghostType: _placing,
                      ghostTile: _ghost,
                      ghostValid: _ghost != null && _placing != null
                          ? _isValidPlacement(
                              _ghost!.$1,
                              _ghost!.$2,
                              _placing!,
                            )
                          : false,
                      time: _time,
                      overlayTop: _cycle.overlayTop,
                      overlayBottom: _cycle.overlayBottom,
                      rainIntensity: _cycle.rainIntensity,
                      nightClarity: _cycle.nightClarity,
                      farmTiles: _farmTiles,
                      farmers: _farmers,
                      farmSelection:
                          (_farmMode && _farmStart != null && _farmEnd != null)
                          ? (
                              _farmStart!.$1,
                              _farmStart!.$2,
                              _farmEnd!.$1,
                              _farmEnd!.$2,
                            )
                          : null,
                      trees: _trees,
                      woodcutters: _woodcutters,
                      lumberSelection:
                          (_lumberMode &&
                              _lumberStart != null &&
                              _lumberEnd != null)
                          ? (
                              _lumberStart!.$1,
                              _lumberStart!.$2,
                              _lumberEnd!.$1,
                              _lumberEnd!.$2,
                            )
                          : null,
                      mineNodes: _mineNodes,
                      miners: _miners,
                      mineSelection:
                          (_mineMode && _mineStart != null && _mineEnd != null)
                          ? (
                              _mineStart!.$1,
                              _mineStart!.$2,
                              _mineEnd!.$1,
                              _mineEnd!.$2,
                            )
                          : null,
                      waterTiles: _waterTiles,
                      dayLight: _cycle.dayLight,
                      lotuses: _lotuses,
                      reeds: _reeds,
                      decor: _decor,
                      graves: _graves,
                      fishers: _fishers,
                      florists: _florists,
                      shepherds: _shepherds,
                      cows: _cows,
                      zoom: _zoom,
                      resourceBoxes: _resourceBoxes,
                      hayEntities: _hayEntities,
                      skyReflection: _cycle.skyMid,
                      groundVersion: _groundVersion,
                      lightSources: _lightSources,
                      ambientTint: _cycle.ambientTint,
                      ambientStrength: _cycle.ambientStrength,
                      eventTint: _fxTint,
                      activeFx: _fxActiveIds,
                      burningBuildings: _burningBuildings,
                      birdFlocks: _birdFlocks,
                      beeSwarms: _beeSwarms,
                      perfMode: _perfMode,
                      lumberCamps: _lumberCamps,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── HUD (frame-bound, üst durum çubuğu) ────────────────────────────────────

  Widget buildHudLayer() {
    return RepaintBoundary(
      child: ListenableBuilder(
        listenable: _frame,
        builder: (_, _) => GameHUD(
          stockpile: _stockpile,
          woodInTransit: _woodInTransit,
          stoneInTransit: _stoneInTransit,
          ironInTransit: _ironInTransit,
          coalInTransit: _coalInTransit,
          foodInTransit: _foodInTransit,
          villagerCount: _villagers.length,
          farmerCount: _farmers.length,
          woodcutterCount: _woodcutters.length,
          minerCount: _miners.length,
          fisherCount: _fishers.length,
          builderCount: _builders.length,
          busyBuilders:
              _builders.where((b) => b.state != BuilderState.idle).length,
          timeOfDay: _cycle.timeOfDay,
          rainIntensity: _cycle.rainIntensity,
          dayLight: _cycle.dayLight,
          dayCount: _dayCount,
          buildingCount: _buildings.length,
          pendingOrderCount: _orders.where((o) => !o.completed).length,
          morale: _stats.morale,
          lowWater: _buildings.any(
            (b) =>
                b.fn?.role == BuildingRole.housing &&
                b.occupants > 0 &&
                b.waterLevel < 0.3,
          ),
          starving: !_godMode && _stockpile.food < kStarveRampFood,
          eventLabel: _eventLabel,
          effectTimeLeft: _eventMoraleLeft,
          effectDuration: _activeEvent?.duration ?? 1,
          effectPositive: (_eventMorale >= 0),
          onToggleDev: () =>
              setStateHere(() => _devPanelOpen = !_devPanelOpen),
          godMode: _godMode,
          onNewMap: () => setStateHere(() => _generateWorld()),
          onToggleGod: () => setStateHere(() => _godMode = !_godMode),
          onTriggerEvent: _triggerRandomEvent,
          timeScale: _timeScale,
          onCycleSpeed: _cycleSpeed,
        ),
      ),
    );
  }

  // ── Alt araç çubuğu: bina/yol panel + Tarla/Kes/Kaz mode butonları ────────

  Widget buildBottomToolbar() {
    if (kBuildingMeta.isEmpty) return const SizedBox.shrink();
    return Positioned(
      bottom: 14,
      left: 0,
      right: 0,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            BuildingPanel(
              stockpile: _stockpile,
              selected: _placing,
              hasFirepit: _hasFire,
              onSelect: (type) => setStateHere(() {
                _farmMode = false;
                _lumberMode = false;
                _mineMode = false;
                _placingRoad = null;
                if (_placing == type) {
                  _placing = null;
                  _ghost = null;
                } else {
                  _placing = type;
                  _ghost = null;
                }
              }),
            ),
            const SizedBox(width: 6),
            RoadPanel(
              stockpile: _stockpile,
              selected: _placingRoad,
              onSelect: (s) => setStateHere(() {
                _placing = null;
                _ghost = null;
                _farmMode = false;
                _lumberMode = false;
                _mineMode = false;
                _placingRoad = _placingRoad == s ? null : s;
                _roadStrokeTiles.clear();
              }),
            ),
            const SizedBox(width: 6),
            ModeButton(
              icon: '🌾',
              label: 'Tarla',
              active: _farmMode,
              accentColor: const Color(0xFF88CC22),
              onTap: () => setStateHere(() {
                _placing = null;
                _ghost = null;
                _placingRoad = null;
                _lumberMode = false;
                _lumberStart = null;
                _lumberEnd = null;
                _mineMode = false;
                _mineStart = null;
                _mineEnd = null;
                _farmMode = !_farmMode;
                _farmStart = null;
                _farmEnd = null;
              }),
            ),
            const SizedBox(width: 4),
            ModeButton(
              icon: '🪓',
              label: 'Kes',
              active: _lumberMode,
              accentColor: const Color(0xFFCC6600),
              onTap: () => setStateHere(() {
                _placing = null;
                _ghost = null;
                _placingRoad = null;
                _farmMode = false;
                _farmStart = null;
                _farmEnd = null;
                _mineMode = false;
                _mineStart = null;
                _mineEnd = null;
                _lumberMode = !_lumberMode;
                _lumberStart = null;
                _lumberEnd = null;
              }),
            ),
            const SizedBox(width: 4),
            ModeButton(
              icon: '⛏',
              label: 'Kaz',
              active: _mineMode,
              accentColor: const Color(0xFF8888CC),
              onTap: () => setStateHere(() {
                _placing = null;
                _ghost = null;
                _placingRoad = null;
                _farmMode = false;
                _farmStart = null;
                _farmEnd = null;
                _lumberMode = false;
                _lumberStart = null;
                _lumberEnd = null;
                _mineMode = !_mineMode;
                _mineStart = null;
                _mineEnd = null;
              }),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bina bilgi paneli ──────────────────────────────────────────────────────

  Widget buildSelectedBuildingPanel() {
    final selected = _selectedBuilding!;
    // Panel artık ekranın üst-ortasında — oyun alanı yanlarda/altta açık kalır,
    // ama panel görsel odak noktası olur. Soft tap-out backdrop ile arka plan
    // hafif kararır ve panel dışına tıklayınca kapanır.
    return Positioned.fill(
      child: Stack(
        children: [
          // Tap-out backdrop — paneli dışında bir yere tıklayınca kapatır.
          // Tam siyah değil; oyun seyredilebilir kalsın (~%18 karartı).
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setStateHere(() => _selectedBuilding = null),
              child: Container(color: const Color(0x2D000000)),
            ),
          ),
          Align(
            alignment: const Alignment(0, -0.55),
            child: BuildingInfoPanel(
        building: selected,
        residents:
            _villagers.where((v) => v.homeBuilding == selected).toList(),
        activeMiners: _miners.where((m) {
          return m.isMining &&
              m.gridX >= selected.col - 0.5 &&
              m.gridX < selected.col + selected.cols + 0.5 &&
              m.gridY >= selected.row - 0.5 &&
              m.gridY < selected.row + selected.rows + 0.5;
        }).toList(),
        barnCows: selected.type == BuildingType.barn
            ? _cows
                .where((c) => c.barnCol == selected.col && c.barnRow == selected.row)
                .toList()
            : const [],
        barnShepherd: selected.type == BuildingType.barn
            ? _shepherds
                .where((sh) => sh.barnCol == selected.col && sh.barnRow == selected.row)
                .firstOrNull
            : null,
        stockpile: _stockpile,
        stats: _stats,
        population: _villagers.length,
        populationCap: _populationCap(),
        onClose: () => setStateHere(() => _selectedBuilding = null),
        onSell: (kind) => setStateHere(() {
          if (sellAtMarket(_stockpile, kind)) {
            // Satış oldu → seçili market binasına son satış zamanı
            // mühürlenir; _BuildingDrawable 1sn altın parıltısı çizer.
            _selectedBuilding?.lastSaleTime = _time;
          }
        }),
        onFestival: () => _hostFestival(selected),
        onRefillWater: selected.type == BuildingType.well
            ? () => _runWaterService(selected)
            : null,
        planning: selected.type == BuildingType.townhall
            ? _computePopulationPlanning()
            : null,
        policies: selected.type == BuildingType.townhall ? _policies : null,
        onTogglePolicy: selected.type == BuildingType.townhall
            ? _togglePolicy
            : null,
        onSetFamilyPolicy: selected.type == BuildingType.townhall
            ? _setFamilyPolicy
            : null,
        policyCooldownSec: selected.type == BuildingType.townhall
            ? _policyCooldownRemaining()
            : 0,
            ),
          ),
        ],
      ),
    );
  }

  /// Politika cooldown — bir karar değiştirildikten sonra geçmesi gereken
  /// sim time (sn). 1 oyun günü = decree ağırlığı.
  static const double _kPolicyCooldownSec = 1.0 * kGameDaySeconds;

  /// Cooldown'da kalan saniye (0 = serbest).
  double _policyCooldownRemaining() =>
      (_policies.cooldownUntilSim - _time).clamp(0.0, double.infinity);

  /// Toggle politikalarını flip eder + cooldown başlatır + bildirim.
  /// Cooldown bitmediyse no-op (UI zaten disable gösterir, ama safety).
  void _togglePolicy(String key) {
    if (_policyCooldownRemaining() > 0) return;
    String? msg;
    setStateHere(() {
      switch (key) {
        case 'familyEncouragement':
          _policies.familyEncouragement = !_policies.familyEncouragement;
          msg = _policies.familyEncouragement
              ? '📜 Aile teşviki yürürlükte.'
              : '📜 Aile teşviki kaldırıldı.';
        case 'peacefulEnd':
          _policies.peacefulEnd = !_policies.peacefulEnd;
          msg = _policies.peacefulEnd
              ? '📜 Yaşlıya huzur yürürlükte.'
              : '📜 Yaşlıya huzur kaldırıldı.';
        case 'eldersExemptFromFood':
          _policies.eldersExemptFromFood = !_policies.eldersExemptFromFood;
          msg = _policies.eldersExemptFromFood
              ? '📜 Yaşlıya saygı yürürlükte.'
              : '📜 Yaşlıya saygı kaldırıldı.';
        case 'hospitality':
          _policies.hospitality = !_policies.hospitality;
          msg = _policies.hospitality
              ? '📜 Misafirperverlik yürürlükte — gezginler köye buyur.'
              : '📜 Misafirperverlik kaldırıldı.';
        case 'apprenticeship':
          _policies.apprenticeship = !_policies.apprenticeship;
          msg = _policies.apprenticeship
              ? '📜 Çıraklık yürürlükte — meslek babadan geçer.'
              : '📜 Çıraklık kaldırıldı.';
        case 'slowMaturity':
          _policies.slowMaturity = !_policies.slowMaturity;
          msg = _policies.slowMaturity
              ? '📜 Geç olgunlaşma — çocukluk uzun sürer.'
              : '📜 Geç olgunlaşma kaldırıldı.';
        case 'neighborliness':
          _policies.neighborliness = !_policies.neighborliness;
          msg = _policies.neighborliness
              ? '📜 Komşuluk — köylüler selam verir.'
              : '📜 Komşuluk kaldırıldı.';
        case 'familyReunion':
          _policies.familyReunion = !_policies.familyReunion;
          msg = _policies.familyReunion
              ? '📜 Aile birleşimi — bekarlar bir araya gelir.'
              : '📜 Aile birleşimi kaldırıldı.';
        case 'treePlanting':
          _policies.treePlanting = !_policies.treePlanting;
          msg = _policies.treePlanting
              ? '📜 Doğa dostu — kesilen ağacın yanına fidan dikilir.'
              : '📜 Doğa dostu kaldırıldı.';
        case 'sharedHarvest':
          _policies.sharedHarvest = !_policies.sharedHarvest;
          msg = _policies.sharedHarvest
              ? '📜 Müşterek hasat — geri kalan tarla hızlanır.'
              : '📜 Müşterek hasat kaldırıldı.';
        case 'greenVillage':
          _policies.greenVillage = !_policies.greenVillage;
          msg = _policies.greenVillage
              ? '📜 Yeşil köy — binalar çiçekle taçlanır.'
              : '📜 Yeşil köy kaldırıldı.';
        case 'freeRange':
          _policies.freeRange = !_policies.freeRange;
          msg = _policies.freeRange
              ? '📜 Otlama serbest — hayvanlar geniş dolaşır.'
              : '📜 Otlama serbest kaldırıldı.';
      }
      _policies.cooldownUntilSim = _time + _kPolicyCooldownSec;
      _applyPolicySideChannels();
    });
    if (msg != null) _showNotification(msg!);
  }

  /// Policy → global side channel'lar (life_stage, animal). Toggle anında ve
  /// init'te çağrılır.
  void _applyPolicySideChannels() {
    kMaturityScale = _policies.slowMaturity ? 1.0 / 1.6 : 1.0;
    AnimalEntity.kWanderScale = _policies.freeRange ? 1.5 : 1.0;
    WoodcutterEntity.kChopSpeedScale = _policies.treePlanting ? 0.85 : 1.0;
  }

  /// Aile planlaması mutex set — radio select. Aynı değer seçilirse no-op.
  void _setFamilyPolicy(FamilyPolicy fp) {
    if (_policyCooldownRemaining() > 0) return;
    if (_policies.family == fp) return;
    setStateHere(() {
      _policies.family = fp;
      _policies.cooldownUntilSim = _time + _kPolicyCooldownSec;
      _applyPolicySideChannels();
    });
    _showNotification('📜 Aile planlaması: ${fp.label}.');
  }

  /// Belediye seçildiğinde panele geçen aggregat — yaş dağılımı, çiftler,
  /// hamile, konut, günlük yiyecek tüketimi. Pure read-only snapshot.
  PopulationPlanning _computePopulationPlanning() {
    int children = 0, adults = 0, elders = 0;
    for (final v in _villagers) {
      switch (v.lifeStage) {
        case LifeStage.child:
        case LifeStage.youth:
          children++;
        case LifeStage.adult:
          adults++;
        case LifeStage.elder:
          elders++;
      }
    }

    // Çift sayısı = aynı evde yetişkin kadın+erkek bulunan ev sayısı,
    // kan bağı filtresi tickReproduction ile aynı.
    int couples = 0;
    int pregnantSoon = 0;
    final seenHomes = <Object>{};
    for (final m in _villagers) {
      if (m.isMale || m.lifeStage != LifeStage.adult) continue;
      if (!m.fertilityDays.isNaN && m.fertilityDays <= 1.0) pregnantSoon++;
      final home = m.homeBuilding;
      if (home == null || seenHomes.contains(home)) continue;
      // Aynı evde non-kan-bağı erkek partner var mı?
      final hasMate = _villagers.any((c) {
        if (c == m || !c.isMale || c.lifeStage != LifeStage.adult) return false;
        if (c.homeBuilding != home) return false;
        if (m.parents.contains(c) || m.children.contains(c)) return false;
        final shareParent = c.parents.any(m.parents.toSet().contains);
        return !shareParent;
      });
      if (hasMate) {
        couples++;
        seenHomes.add(home);
      }
    }

    int housedSlots = 0;
    int totalHousing = 0;
    for (final b in _buildings) {
      final f = b.fn;
      if (f == null || f.role != BuildingRole.housing) continue;
      totalHousing += f.housingCapacity;
      housedSlots += _villagers.where((v) => v.homeBuilding == b).length;
    }

    final exemptElders = _policies.eldersExemptFromFood ? elders : 0;
    final mouths = _villagers.length - exemptElders +
        _farmers.length +
        _woodcutters.length +
        _miners.length +
        _fishers.length +
        _builders.length;
    final foodPerDay = mouths * kFoodPerVillagerPerDay;

    return PopulationPlanning(
      children: children,
      adults: adults,
      elders: elders,
      couples: couples,
      pregnantSoon: pregnantSoon,
      housedSlots: housedSlots,
      totalHousing: totalHousing,
      foodPerDay: foodPerDay,
      foodStock: _stockpile.food,
    );
  }

  /// Şenlik — sabit maliyet (yiyecek+altın) karşılığı geçici moral boost.
  /// Aktif geçici etki varsa üst üste binmesin: yenisi eskinin yerini alır.
  void _hostFestival(BuildingEntity b) {
    const foodCost = 8;
    const goldCost = 5;
    const moraleBoost = 0.25;
    const durationSec = 50.0;
    if (_stockpile.food < foodCost || _stockpile.gold < goldCost) {
      _showNotification('Yiyecek veya altın yetersiz');
      return;
    }
    setStateHere(() {
      _stockpile.food -= foodCost;
      _stockpile.gold -= goldCost;
      _eventMorale     = moraleBoost;
      _eventMoraleLeft = durationSec;
      _eventLabel      = '🎉 Şenlik';
      b.lastSaleTime   = _time; // küçük görsel parıltı
    });
    _showNotification('🎉 Köyde şenlik başladı');
  }

  /// Kuyudan acil su servisi — tüm boşalmaya yakın evleri anında doldurur.
  /// Ücret yok; oyuncu kuyuyu kullanmak için bu butonu tetikler.
  void _runWaterService(BuildingEntity well) {
    int touched = 0;
    setStateHere(() {
      for (final b in _buildings) {
        if (b.fn?.role == BuildingRole.housing && b.waterLevel < 0.95) {
          b.waterLevel = 1.0;
          touched++;
        }
      }
      well.lastSaleTime = _time;
    });
    _showNotification(touched > 0
        ? '💧 $touched ev dolduruldu'
        : '💧 Bütün evler zaten dolu');
  }

  // ── Köylü bilgi paneli — bina paneliyle aynı pozisyon ─────────────────────

  Widget buildSelectedVillagerPanel() {
    final v = _selectedVillager!;
    return Positioned(
      bottom: 120,
      left: 14,
      child: VillagerInfoPanel(
        villager: v,
        homeLabel: v.homeBuilding == null
            ? null
            : kBuildingMeta[(v.homeBuilding as BuildingEntity).type]?.label,
        isFollowed: _followedVillager == v,
        canGift: _stockpile.food > 0,
        onClose: () => setStateHere(() => _selectedVillager = null),
        onSelect: (next) => setStateHere(() => _selectedVillager = next),
        onGreet: () => _greetVillager(v),
        onGift: () => _giftVillager(v),
        onToggleFollow: () => _toggleFollowVillager(v),
        onToggleFavorite: () => setStateHere(() => v.isFavorite = !v.isFavorite),
        onRename: (newName) {
          final cleaned = newName.trim();
          if (cleaned.isEmpty || cleaned.length > 20) return;
          setStateHere(() => v.name = cleaned);
        },
      ),
    );
  }

  // ── NPC etkileşim eylemleri (Selam / Hediye / Takip et) ───────────────────
  // Sade ve "cozy": her aksiyon görsel bir reaksiyon (chat bubble) + küçük
  // bir niyet ifade eder. Hediye ufak bir köy morali bonusu doğurur, selam
  // sadece sıcaklık katar (kaynak tüketmez).

  void _greetVillager(VillagerEntity v) {
    setStateHere(() {
      v.chatBubbleIcon = '👋';
      v.chatBubbleTime = 4.5;
      v.greetCount++;
      // Selam alan NPC mutlu olur (gövde dili — huzurlu salınış).
      v.feel(NpcEmotion.content, 3.0, moodDelta: 0.05);
      // Boş ise küçük "selam aldım" iç sosyal cooldown azalt → kısa süre içinde
      // başka selamlaşma/chat'e geç olasılığı düşmesin.
      if (v.socialCooldown > 6) v.socialCooldown = 6;
      // Komşular dönüp bakar (yerel canlılık dalgası).
      _reactNearby(v.gridX, v.gridY, 4.0, NpcEmotion.wonder, 2.0);
    });
  }

  void _giftVillager(VillagerEntity v) {
    if (_stockpile.food <= 0) {
      _showNotification('🍞 Sepet boş — önce yiyecek topla');
      return;
    }
    setStateHere(() {
      _stockpile.food -= 1;
      v.chatBubbleIcon = '❤️';
      v.chatBubbleTime = 5.5;
      v.giftCount++;
      // Hediye alan NPC sevinçle karşılık verir (gövde dili — sıçrama).
      v.feel(NpcEmotion.joy, 3.5, moodDelta: 0.10);
      // Köy çapında küçük, 1 oyun günü süren moral bonusu — chill ölçekte.
      _policyMoraleEffects
          .add((untilSim: _time + kGameDaySeconds, amount: 0.02));
      // Komşular sevinen köylüye dönüp bakar.
      _reactNearby(v.gridX, v.gridY, 4.0, NpcEmotion.joy, 2.2);
    });
  }

  void _toggleFollowVillager(VillagerEntity v) {
    setStateHere(() {
      if (_followedVillager == v) {
        _followedVillager = null;
        _showNotification('🎥 Takip bırakıldı');
      } else {
        _followedVillager = v;
        _showNotification('🎥 ${v.name} takip ediliyor');
      }
    });
  }

  // ── Event modal (karar bekleyen olay) ──────────────────────────────────────

  Widget buildEventChoiceModal() {
    return Positioned.fill(
      child: EventChoiceModal(
        event: _pendingChoice!,
        onChoose: (c) => _applyEventChoice(_pendingChoice!, c),
      ),
    );
  }

  // ── Dev panel — sağdan slide-in ────────────────────────────────────────────

  Widget buildDevPanel() {
    return Positioned.fill(
      child: ListenableBuilder(
        listenable: _frame,
        builder: (_, _) => DevPanel(
          godMode: _godMode,
          rainIntensity: _cycle.rainIntensity,
          timeOfDay: _cycle.timeOfDay,
          villagerCount: _villagers.length,
          buildingCount: _buildings.length,
          onClose: () => setStateHere(() => _devPanelOpen = false),
          onToggleGod: () => setStateHere(() => _godMode = !_godMode),
          onSetRain: (v) => setStateHere(() => _cycle.rainIntensity = v),
          onSetTimeOfDay: (v) => setStateHere(() => _cycle.timeOfDay = v),
          onTriggerEvent: (e) {
            setStateHere(() {
              if (e.needsChoice) {
                _pendingChoice = e;
                _showNotification('${e.icon} ${e.title} — karar bekliyor');
              } else {
                _applyEventAutomatic(e);
              }
              _devPanelOpen = false;
            });
          },
          onAddResource: (k, n) => setStateHere(() {
            _stockpile.add(k, n);
            final cur = _stockpile.get(k);
            if (cur < 0) _stockpile.add(k, -cur);
          }),
          onSpawnVillager: () {
            final fp = _firepitBuilding;
            if (fp != null) setStateHere(() => _spawnGrownVillager(fp));
          },
          onKillRandomVillager: () {
            if (_villagers.isEmpty) return;
            setStateHere(() {
              final v = _villagers[_rng.nextInt(_villagers.length)];
              v.ageDays = v.lifespanDays + 1; // bir sonraki tick ölür
            });
          },
          onClearEffects: () => setStateHere(() {
            _activeFx.clear();
            _eventMorale = 0;
            _eventMoraleLeft = 0;
            _eventLabel = null;
            _activeEvent = null;
            _activeEventLeft = 0;
          }),
          onNewMap: () => setStateHere(() => _generateWorld()),
          onWakeAll: () => setStateHere(() {
            for (final v in _villagers) {
              v.isInsideBuilding = false;
              v.sleepTarget = null;
              v.sleepIsHome = false;
            }
          }),
          onSeedLivingVillage: () {
            _buildLivingVillage();
            setStateHere(() => _devPanelOpen = false);
          },
          onSeedShowcase: () {
            _buildShowcaseVillage();
            setStateHere(() {
              _godMode = true;
              _devPanelOpen = false;
            });
          },
          // ── Görsel test hızlı aksiyonlar ───────────────────────────────
          onSetDawn:     () => setStateHere(() => _cycle.timeOfDay = 0.22),
          onSetNoon:     () => setStateHere(() => _cycle.timeOfDay = 0.50),
          onSetDusk:     () => setStateHere(() => _cycle.timeOfDay = 0.78),
          onSetNight:    () => setStateHere(() => _cycle.timeOfDay = 0.92),
          onToggleRain:  () => setStateHere(() {
            _cycle.rainIntensity = _cycle.rainIntensity > 0.05 ? 0.0 : 0.7;
          }),
          onAllPolicies: () => setStateHere(() {
            _policies.familyEncouragement = true;
            _policies.peacefulEnd = true;
            _policies.eldersExemptFromFood = true;
            _policies.hospitality = true;
            _policies.apprenticeship = true;
            _policies.slowMaturity = true;
            _policies.neighborliness = true;
            _policies.familyReunion = true;
            _policies.treePlanting = true;
            _policies.sharedHarvest = true;
            _policies.greenVillage = true;
            _policies.freeRange = true;
            _policies.cooldownUntilSim = 0;
            _applyPolicySideChannels();
          }),
          onClearPolicies: () => setStateHere(() {
            _policies.family = FamilyPolicy.open;
            _policies.familyEncouragement = false;
            _policies.peacefulEnd = false;
            _policies.eldersExemptFromFood = false;
            _policies.hospitality = false;
            _policies.apprenticeship = false;
            _policies.slowMaturity = false;
            _policies.neighborliness = false;
            _policies.familyReunion = false;
            _policies.treePlanting = false;
            _policies.sharedHarvest = false;
            _policies.greenVillage = false;
            _policies.freeRange = false;
            _policies.cooldownUntilSim = 0;
            _applyPolicySideChannels();
          }),
          onMakeSage: () => setStateHere(() {
            // Zaten varsa flag'i temizle ki yeni biri olabilsin
            for (final v in _villagers) {
              v.isSage = false;
            }
            var elders = _villagers
                .where((v) => v.lifeStage == LifeStage.elder)
                .toList();
            if (elders.isEmpty) {
              // Yaşlı yok → bir yaşlı doğur
              final fp = _firepitBuilding;
              if (fp != null) {
                _spawnGrownVillager(fp);
                _villagers.last.ageDays = kElderStartDay + 1.0;
                elders = [_villagers.last];
              }
            }
            if (elders.isNotEmpty) {
              final sage = elders[_rng.nextInt(elders.length)];
              sage.isSage = true;
              _showNotification(
                  '👵 ${sage.name} köyün bilgesi yapıldı (test)');
            }
          }),
          onSpawnMigrant: () => setStateHere(_spawnMigrant),
          onForcePetition: _forcePetition,
          petitions: [
            for (final p in PetitionSystem.all) (p.id, '${p.icon} ${p.title}'),
          ],
          onForcePetitionId: _forcePetitionById,
          perfMode: _perfMode,
          onTogglePerf: () => setStateHere(() => _perfMode = !_perfMode),
          simSpeedBoost: _devSpeedBoost,
          simHistory: [
            for (final s in _simHistory)
              SimSnapshot(
                simTime: s.simTime,
                day: s.day,
                population: s.population,
                buildings: s.buildings,
                wood: s.wood,
                stone: s.stone,
                iron: s.iron,
                coal: s.coal,
                food: s.food,
                gold: s.gold,
              ),
          ],
          onSetSimSpeed: (v) => setStateHere(() => _devSpeedBoost = v),
          onClearSimHistory: () => setStateHere(() => _simHistory.clear()),
          activeScenario: _scenarioName,
          scenarioProgress: _scenarioProgress,
          lastReport: _lastReport == null
              ? null
              : ScenarioReport(
                  name: _lastReport!.name,
                  durationSec: _lastReport!.durationSec,
                  popStart: _lastReport!.popStart,
                  popEnd: _lastReport!.popEnd,
                  resources: _lastReport!.resources,
                  verdict: _lastReport!.verdict,
                  warnings: _lastReport!.warnings,
                ),
          onScenarioBaseline: _scenarioBaseline,
          onScenarioPlague: _scenarioPlague,
          onScenarioDrought: _scenarioDrought,
          onScenarioFire: _scenarioFire,
          onPlayMusic: () {
            if (!_devStartMusic()) {
              _showNotification('Uygun NPC yok');
            }
          },
          onStartDance: () {
            if (!_devStartDance()) {
              _showNotification('Yan yana iki yetişkin NPC bulunamadı');
            }
          },
          onStartChat: () {
            if (!_devStartChat()) {
              _showNotification('Yan yana iki yetişkin NPC bulunamadı');
            }
          },
          onClearActivities: () => setStateHere(_devClearActivities),
          onMeteorShower: () => setStateHere(_startMeteorShower),
        ),
      ),
    );
  }

  // ── Event banner ───────────────────────────────────────────────────────────

  Widget buildEventBanner() {
    return Positioned(
      top: 90,
      left: 0,
      right: 0,
      child: Center(
        child: RepaintBoundary(
          child: ListenableBuilder(
            listenable: _frame,
            builder: (_, _) {
              final e = _activeEvent;
              if (e == null) return const SizedBox.shrink();
              return EventBanner(
                event: e,
                timeLeft: _activeEventLeft,
                duration: kEventBannerDuration,
                onClose: () => setStateHere(() {
                  _activeEvent = null;
                  _activeEventLeft = 0;
                }),
              );
            },
          ),
        ),
      ),
    );
  }

  // ── Hedef listesi (sol kolon) ──────────────────────────────────────────────

  Widget buildObjectivesPanel() {
    return Positioned(
      left: 14,
      top: 190,
      child: RepaintBoundary(
        child: ListenableBuilder(
          listenable: _frame,
          builder: (_, _) {
            final ctx = _questContext();
            final quests = QuestBook.activeQuests(ctx, _completedQuests);
            final tier = QuestBook.tierOf(_charterTier);
            return ObjectivePanel(
              quests: quests,
              tierIndex: _charterTier,
              tierName: tier.name,
              tierIcon: tier.icon,
              completedCount: _completedQuests.length,
              totalCount: QuestBook.all.length,
              next: QuestBook.nextTier(_charterTier),
              collapsed: _objectivesCollapsed,
              onToggleCollapse: () => setStateHere(
                () => _objectivesCollapsed = !_objectivesCollapsed,
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Geçici bildirim balonu ─────────────────────────────────────────────────

  Widget buildNotificationToast() {
    return Positioned(
      top: 70,
      left: 0,
      right: 0,
      child: Center(
        child: WaxBadge(
          label: _notification!,
          color: CozyUi.ember,
        ),
      ),
    );
  }

  // ── Yerleştirme/seçim modu ipucu ────────────────────────────────────────────

  Widget buildHintRibbon() {
    return Positioned(
      top: 52,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          color: _mineMode
              ? const Color(0xEE0A0A2A)
              : _lumberMode
              ? const Color(0xEE2A1A00)
              : _placingRoad != null
              ? const Color(0xEE2A1808)
              : const Color(0xEE1A3A1A),
          child: Text(
            _mineMode
                ? 'Madenci — sürükle seç, madenleri işaretle'
                : _lumberMode
                ? 'Oduncu — sürükle seç, bırak ağaçları işaretle'
                : _farmMode
                ? 'Tarla — sürükle seç, bırak onayla'
                : _placingRoad != null
                ? '${_placingRoad!.label} — sürükle döşe'
                : '${kBuildingMeta[_placing!]!.label} — haritaya tıkla',
            style: TextStyle(
              color: _mineMode
                  ? const Color(0xFFAABBFF)
                  : _lumberMode
                  ? const Color(0xFFFFAA44)
                  : _placingRoad != null
                  ? const Color(0xFFDDB880)
                  : const Color(0xFF88FF88),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
