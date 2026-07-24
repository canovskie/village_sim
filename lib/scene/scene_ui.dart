part of '../main.dart';

/// build() içeriğini konsept başına alt-metotlara böler: gökyüzü, oyun canvas'ı,
/// HUD, alt araç çubuğu, seçim panelleri, overlay'ler, ipuçları.
/// part of main.dart — State'in tüm private alanlarına erişim.
extension _SceneUi on _VillageSceneState {
  // HUD 'evsiz' sayısına tıklanınca — evsiz köylüleri ~3 sn vurgula (painter
  // ayak altına nabız halka çizer). Kim nerede uyuyor/dolaşıyor görülür.
  void _highlightHomeless() {
    for (final v in _villagers) {
      if (v.homeBuilding == null) v.highlightTimer = 3.0;
    }
    setStateHere(() {});
  }

  // Moral katkı kırılımı — HUD moral barı hover tooltip'i. _tickBuildingSystems
  // moraleTarget formülünün AYNISI; oradan koptuysa burayı da güncelle.
  List<(String, double)> _moraleBreakdown() {
    final list = <(String, double)>[('Taban', 0.5)];
    if (_eventMorale.abs() > 0.005) {
      list.add((_eventLabel ?? 'Olay etkisi', _eventMorale));
    }
    if (_villagers.any((v) => v.isSage)) list.add(('Bilge', 0.08));
    final perm = _policyMoralePermanent();
    if (perm.abs() > 0.005) list.add(('Politikalar (kalıcı)', perm));
    final temp = _policyMoraleTemporary();
    if (temp.abs() > 0.005) list.add(('Politikalar (geçici)', temp));
    if (_governanceLegacy.abs() > 0.005) {
      list.add(('Kararların mirası', _governanceLegacy));
    }
    final indiv = (_avgIndividualMorale - 0.62) * 0.5;
    if (indiv.abs() > 0.005) list.add(('Halkın hâli', indiv));
    return list;
  }

  // ── Kamera sarsıntısı (juice) ──────────────────────────────────────────────

  /// Sarsıcı bir olayda kamerayı kısa süre titret. Ayar kapalıysa no-op.
  /// [mag] piksel genliği (~6 hafif, ~14 sert), [dur] saniye.
  void addCameraShake(double mag, {double dur = 0.5}) {
    if (!SettingsModel.instance.shakeOnEvents) return;
    if (_shakeTime <= 0 || mag > _shakeMag) {
      _shakeMag = mag;
      _shakeDur = dur;
      _shakeTime = dur;
    }
  }

  /// Anlık sarsıntı offset'i — sona doğru hızla söner (quadratic). 60fps
  /// (_frame) ile yeniden hesaplanır.
  Offset get _shakeOffset {
    if (_shakeTime <= 0 || _shakeDur <= 0) return Offset.zero;
    final ratio = (_shakeTime / _shakeDur).clamp(0.0, 1.0);
    final amp = _shakeMag * ratio * ratio;
    return Offset(sin(_time * 92.0) * amp, cos(_time * 71.0) * amp);
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
            // Çoklu dikim: yerleştirme modunda basılı tut + sürükle.
            onLongPressStart: _onCanvasLongPressStart,
            onLongPressMoveUpdate: _onCanvasLongPressMoveUpdate,
            onLongPressEnd: _onCanvasLongPressEnd,
            child: MouseRegion(
              onHover: _onCanvasHover,
              onExit: (_) => setStateHere(_clearHover),
              child: RepaintBoundary(
                child: ListenableBuilder(
                  listenable: _frame,
                  builder: (_, _) => CustomPaint(
                    painter: VillageGamePainter(
                      villagers: _villagers,
                      merchants: _merchants,
                      soldiers: _soldiers,
                      buildings: _buildings,
                      builders: _builders,
                      pendingOrders: _orders,
                      roadSystem: _roadSystem,
                      pendingRoadOrders: _roadOrders,
                      camera: _camera + _shakeOffset,
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
                      cleared: _cleared,
                      wilderness: _wilderness,
                      wildTreeTiles: _wildTreeTiles,
                      forestVersion: _forestVersion,
                      leafBursts: _leafBursts,
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
                      reedBeds: _reedBeds,
                      fishers: _fishers,
                      florists: _florists,
                      shepherds: _shepherds,
                      cows: _cows,
                      zoom: _zoom,
                      resourceBoxes: _resourceBoxes,
                      hayEntities: _hayEntities,
                      eggs: _eggs,
                      skyReflection: _cycle.skyMid,
                      timeOfDay: _cycle.timeOfDay,
                      season: _season,
                      sunColor: _cycle.sunColor,
                      sunOpacity: _cycle.sunOpacity,
                      moonOpacity: _cycle.moonOpacity,
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
        listenable: _hudFrame, // PERF: ~10Hz (her frame değil)
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
          shepherdCount: _shepherds.length,
          floristCount: _florists.length,
          homelessCount: _villagers.where((v) => v.homeBuilding == null).length,
          busyBuilders:
              _builders.where((b) => b.state != BuilderState.idle).length,
          timeOfDay: _cycle.timeOfDay,
          rainIntensity: _cycle.rainIntensity,
          dayLight: _cycle.dayLight,
          dayCount: _dayCount,
          season: _season,
          seasonProgress: seasonProgress(_dayCount, _cycle.timeOfDay),
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
          stockCapacity: _godMode ? (1 << 30) : _stats.stockCapacity,
          fullPulse: sin(_time * 3.2) * 0.5 + 0.5,
          moraleBreakdown: _moraleBreakdown(),
          onHighlightHomeless: _highlightHomeless,
          effectTimeLeft: _eventMoraleLeft,
          effectDuration: _activeEvent?.duration ?? 1,
          effectPositive: (_eventMorale >= 0),
          onToggleDev: () =>
              setStateHere(() => _devPanelOpen = !_devPanelOpen),
          muted: SettingsModel.instance.muted,
          onToggleMute: () =>
              setStateHere(() => SettingsModel.instance.toggleMute()),
          godMode: _godMode,
          onNewMap: () => setStateHere(() => _generateWorld()),
          onOpenRoster: () => _openLedger(LedgerSection.nufus),
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
        // Ateş yokken kategori yok — yalnız ateş yeri kartı. Sonra: kategori
        // sekmeleri (üstte) + seçili kategorinin içeriği (altta). Tek sıralık
        // kalabalık yerine derli toplu, ölçeklenebilir palet.
        child: !_hasFire
            ? BuildingPanel(
                stockpile: _stockpile,
                selected: _placing,
                hasFirepit: false,
                onSelect: _onSelectBuilding,
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildCategoryContent(),
                  const SizedBox(height: 6),
                  _buildCategoryTabs(),
                ],
              ),
      ),
    );
  }

  /// Seçili kategorinin içeriği — bina kategorisinde palet, Arazi/Yol'da
  /// yol döşeme + Tarla/Kes/Kaz modları.
  Widget _buildCategoryContent() {
    if (_buildCategory == BuildCategory.araziYol) return _buildLandRoadTools();
    return BuildingPanel(
      stockpile: _stockpile,
      selected: _placing,
      hasFirepit: _hasFire,
      category: _buildCategory,
      isUnlocked: _isCraftKnown,
      onSelect: _onSelectBuilding,
    );
  }

  /// Kategori sekmeleri — alt çubuğun kalabalık tek sırasını gruplara böler.
  Widget _buildCategoryTabs() {
    return AppPanel(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final cat in BuildCategory.values) ...[
            if (cat != BuildCategory.values.first) const SizedBox(width: 4),
            _categoryTab(cat),
          ],
        ],
      ),
    );
  }

  Widget _categoryTab(BuildCategory cat) {
    final sel = _buildCategory == cat;
    return GestureDetector(
      onTap: () => setStateHere(() => _buildCategory = cat),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: sel
              ? Color.alphaBlend(
                  AppUi.accent.withValues(alpha: 0.22), AppUi.surface2)
              : AppUi.surface0,
          borderRadius: BorderRadius.circular(AppUi.radiusSm),
          border: Border.all(
              color: sel ? AppUi.accent : AppUi.line, width: sel ? 1.4 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(cat.icon, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 5),
            Text(cat.label.toUpperCase(),
                style: AppUi.button.copyWith(
                    fontSize: 9.5,
                    letterSpacing: 0.8,
                    color: sel ? AppUi.accentSoft : AppUi.textMid)),
          ],
        ),
      ),
    );
  }

  /// Bina seçimi — modları temizle, aynı binaya basınca bırak (toggle).
  void _onSelectBuilding(BuildingType type) => setStateHere(() {
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
      });

  /// Arazi/Yol sekmesi içeriği — yol döşeme + Tarla/Kes/Kaz modları.
  Widget _buildLandRoadTools() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
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
    );
  }

  /// Akıllı yerleştirme ipucu — hayalet geçersiz tile üstündeyken NEDEN
  /// kurulamadığını inşa çubuğunun hemen üstünde gösterir (öğretici).
  Widget buildPlaceReason() {
    return Positioned(
      bottom: 132,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xF21A0E04),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppUi.rust, width: 1),
            ),
            child: Text('🚫 $_placeReason',
                style: AppUi.bodyHi.copyWith(fontSize: 12, color: AppUi.rust)),
          ),
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
          // Sağ-dock: tüm seçim panelleri tutarlı biçimde sağ kenarda açılır.
          Positioned(
            top: 64,
            right: 14,
            bottom: 96,
            child: SafeArea(
              child: SingleChildScrollView(
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
        barnCows: (selected.type == BuildingType.barn ||
                selected.type == BuildingType.chickenCoop)
            ? _cows
                .where((c) => c.barnCol == selected.col && c.barnRow == selected.row)
                .toList()
            : const [],
        onBuyAnimal: (selected.type == BuildingType.barn ||
                selected.type == BuildingType.chickenCoop)
            ? (kind) => _buyAnimal(selected, kind)
            : null,
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
        // Yık (kısmi iade) + Taşı (tam iade + yeniden yerleştir). Ateş yeri
        // korunur (panelde gösterme).
        onDemolish: selected.type == BuildingType.firepit
            ? null
            : () => _demolishBuilding(selected, refund: 0.5),
        onMove: selected.type == BuildingType.firepit
            ? null
            : () => _demolishBuilding(selected, refund: 1.0, reselect: true),
        onRefillWater: selected.type == BuildingType.well
            ? () => _runWaterService(selected)
            : null,
        planning: selected.type == BuildingType.townhall
            ? _computePopulationPlanning()
            : null,
        // Yönetişim (Karar Defteri + hane nabzı) Köy Defteri'ne taşındı —
        // belediye panelinde yalnız oraya açılan kapı kalır.
        onOpenDivan: selected.type == BuildingType.townhall
            ? () => setStateHere(() {
                  _selectedBuilding = null;
                  _ledgerSection = LedgerSection.divan;
                })
            : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── KANUNNAME — mühür ──────────────────────────────────────────────────────
  // Eski toggle/cooldown ikilisi öldü. Yerine tek bir eylem var: MÜHÜR. Geri
  // alınmaz, bir günde bir tane basılır, ve basılmadan önce meclis toplanır.

  /// Mürekkebin kuruması için kalan sim saniyesi (0 = defter açık, mühür basılır).
  double _inkDryRemaining() =>
      (_policies.inkDryUntilSim - _time).clamp(0.0, double.infinity);

  /// Fermanı meclisin önüne koy. Meclis burada toplanır — ayrı bir "topla"
  /// düğmesi yok, çünkü meclis bir aksiyon değil, imzanın kendisidir.
  void _openLawRitual(LawDef l) => setStateHere(() => _lawRitual = l);
  void _closeLawRitual() => setStateHere(() => _lawRitual = null);

  /// MÜHRÜ BAS — geri dönüşü yok. Ferman deftere girer, etkileri köye bağlanır,
  /// mürekkep ıslanır (bir sonraki hüküm müzakere bitene dek yazılmaz).
  ///
  /// Bir mühür = bir KARAR. Dilekçe karar motoru ([_applyDecisionEffects])
  /// olduğu gibi devralınır: kaynak deltası, süreli moral, zümre morali+nüfuzu,
  /// köy hafızası bayrağı, zincir dilekçesi. Yasa da bir karardır.
  /// Köyün hâli — ağır yasa kapıları buradan okunur (yasa şartı değil, dünya
  /// şartı). Küçük/genç köy sert hükümleri kaldıramaz.
  /// Köyün hâli — hüküm kapıları buradan okunur (yasa şartı DEĞİL, dünya şartı).
  /// Bir hüküm, DERDİ köyde doğmadan deftere düşmez: tarla açılmadan su yolu,
  /// ilk suç işlenmeden bekçi, ilk beşik sallanmadan beşik fermanı görünmez.
  ///
  /// PERF: set/sayım kurar → her frame değil, saniyede bir tazelenir
  /// ([_lawCtxAge], bkz. _tickLawGates). Mühür anında bir saniyelik bayatlık
  /// zararsız; kapılar zaten yavaş değişen dünya şartları.
  LawContext get _lawContext => _lawCtxCache ??= _computeLawContext();

  LawContext _computeLawContext() {
    var children = 0, elders = 0;
    final houses = <String>{};
    for (final v in _villagers) {
      switch (v.lifeStage) {
        case LifeStage.child:
          children++;
        case LifeStage.elder:
          elders++;
        case LifeStage.youth:
        case LifeStage.adult:
          break;
      }
      if (v.surname.isNotEmpty) houses.add(v.surname);
    }
    return LawContext(
      population: _villagers.length,
      dayCount: _dayCount,
      villageMorale: _morale,
      households: houses.length,
      children: children,
      elders: elders,
      farmTiles: _farmTiles.length,
      animals: _cows.length,
      deaths: _graves.length,
      crimesSeen: _crimesSeen,
      knownCrafts: _knownCrafts,
      buildings: {for (final b in _buildings) b.type},
      memory: _villageMemory,
    );
  }

  /// KAPI NÖBETİ — köyün hâli değiştikçe deftere yeni hüküm düşer. Sessizce
  /// belirmesin: gündeme gelen her hüküm bir kez duyurulur (bildirim + kronik).
  /// Yeni oyunda ilk tarama sessizdir ([_lawSeen] o an doldurulur) — yoksa köy
  /// kurulur kurulmaz on bildirim üst üste yağar.
  void _tickLawGates(double dt) {
    _lawCtxAge += dt;
    if (_lawCtxAge < 1.0) return;
    _lawCtxAge = 0;
    _lawCtxCache = null; // bir sonraki okumada tazelenir

    final open = LawBook.openAgenda(_policies.sealed, _lawContext);
    final fresh = [for (final l in open) if (!_lawSeen.contains(l.id)) l];
    if (fresh.isEmpty) return;
    for (final l in fresh) {
      _lawSeen.add(l.id);
    }
    if (!_lawSeeded) {
      _lawSeeded = true; // ilk tarama: köyün başlangıç gündemi, duyuru yok
      return;
    }
    // Aynı saniyede birden fazla açıldıysa tek satırda topla — üst üste toast
    // yağdırmak yerine "defter kabardı" hissi.
    final title = fresh.length == 1
        ? '${fresh.first.icon} Kanunname\'ye yeni hüküm düştü: ${fresh.first.title}'
        : '📜 Kanunname kabardı — ${fresh.length} yeni hüküm gündemde.';
    _showNotification(title);
    _chronicle(
        fresh.length == 1
            ? '${fresh.first.title} Meclis gündemine girdi.'
            : 'Köyün hâli değişti; deftere ${fresh.length} yeni hüküm düştü.',
        icon: '📜');
  }

  /// KÖYÜN SESİ — o an en çok ihtiyaç duyulan (çıkarılabilir) yasa. Serbest
  /// kataloğun içinden köyün gündemini öne çıkarır: önce geçim, ucuz/hızlı ve
  /// ağır olmayan hüküm. Path DEĞİL, bir tavsiye — istersen başkasını çıkarırsın.
  String? get _lawSpotlightId {
    final ctx = _lawContext;
    LawDef? best;
    var bestScore = 1 << 30;
    for (final l in kLawBook) {
      if (!LawBook.available(l, _policies.sealed, ctx)) continue;
      final score = (l.branch == LawBranch.gecim ? 0 : 1000) +
          (l.isGrave ? 500 : 0) +
          (l.deliberationDays * 10).round() +
          l.seal.goldDelta.abs();
      if (score < bestScore) {
        bestScore = score;
        best = l;
      }
    }
    return best?.id;
  }

  void _sealLaw(LawDef l) {
    if (_inkDryRemaining() > 0) return;
    if (!LawBook.available(l, _policies.sealed, _lawContext)) return;

    final rule = _regimeRule;
    // MECLİS OYU — hür ve köklü bir rejimde ferman senin imzanla değil, köyün
    // rızasıyla geçer. Oy düşerse mühür basılmaz; meclis dağılır ve mürekkep
    // kısa bir süre ıslak kalır (aynı fermanı hemen tekrar dayatamazsın).
    if (_lawNeedsVote(l)) {
      final vote = _voteOnLaw(l);
      if (!vote.passed) {
        AudioManager.instance.playSfx(Sfx.bellChime);
        setStateHere(() {
          _inkDryTotal = 0.6 * kGameDaySeconds;
          _policies.inkDryUntilSim = _time + _inkDryTotal;
          _lawRitual = null;
        });
        final no = vote.voices.where((v) => !v.yes).map((v) => v.line).take(2);
        _showNotification('🏛 Meclis fermanı geçirmedi '
            '(${(vote.support * 100).round()}% destek). ${no.join(' ')}');
        _chronicle('${l.title} meclisten döndü.', icon: '🏛');
        // Reddedilen ferman meşruiyeti aşındırır: ısrar edersen köy gerilir.
        _unrest = (_unrest + 0.04).clamp(0.0, 1.0);
        return;
      }
    }

    AudioManager.instance.playSfx(Sfx.bellChime);
    setStateHere(() {
      _policies.seal(l);
      _applyDecisionEffects(_lawAsDecision(l), l.seal, null);
      // Büyük fermanlar geçici moralle kalmaz — köy ruhunda sönmeyen bir iz.
      if (l.legacy != 0) {
        _governanceLegacy = (_governanceLegacy + l.legacy).clamp(-0.12, 0.12);
      }
      // Müzakere temposu rejimin: baskıda mürekkep çabuk kurur, hür rejimde
      // meclis uzun konuşur.
      _inkDryTotal = l.deliberationDays * kGameDaySeconds * rule.inkDryMul;
      _policies.inkDryUntilSim = _time + _inkDryTotal;
      _applyPolicySideChannels();
      _lawCtxCache = null; // yeni mühür kapıları da oynatabilir
      _lawRitual = null;
    });
    _chronicle('${l.title} deftere girdi.',
        icon: l.icon, milestone: l.isGrave);
    if (l.seal.resolution.isNotEmpty) _showNotification(l.seal.resolution);
  }

  /// Mühürü karar motoruna geçirmek için ince sarmalayıcı. `estate` bilerek
  /// null: bir yasa bir haneye değil, bütün köye yazılır — kimse "bizim
  /// dilekçemiz kabul edildi" nüfuzunu ceplemez.
  Petition _lawAsDecision(LawDef l) => Petition(
        id: 'law.${l.id}',
        petitioner: 'Kanunname',
        icon: l.icon,
        title: l.title,
        tone: PetitionTone.solemn,
        bodyPool: [l.decree],
        options: [l.seal],
      );

  /// Mühürlü fermanların GÜNLÜK idamesi — gece bekçisi keseden yer, hane sicili
  /// vergi toplar, öşür ambardan alır. Bir yasa imzalandığı gün bitmez; her
  /// sabah köyün sırtındadır. [_advanceWorldClock] gün dönümünde çağırır.
  void _applyLawUpkeep() {
    final (gold, food) = LawBook.dailyUpkeep(_policies.sealed);
    if (gold != 0) {
      _stockpile.gold = (_stockpile.gold + gold).clamp(0, 1 << 30);
    }
    if (food != 0) {
      _stockpile.food = (_stockpile.food + food).clamp(0, 1 << 30);
    }
    // TEK SÖZ FERMANI — sessizliğin bedeli. Köy sesini yitirdi; her gün küçük
    // bir moral sızıntısı (dilekçe kanalı kapalı, kimse dinlenmiyor). İlk şok
    // fermanın moraleAmount'unda, bu ise sönmeyen tortu: baskının kronik yükü.
    if (_policies.sealed.contains('nizam.sole')) {
      pushPolicyMorale(-0.015, 1.5);
    }
  }

  /// Policy → global side channel'lar (life_stage, animal). Mühür anında ve
  /// init/yükleme'de çağrılır.
  void _applyPolicySideChannels() {
    kMaturityScale = _policies.slowMaturity ? 1.0 / 1.6 : 1.0;
    AnimalEntity.kWanderScale = _policies.freeRange ? 1.5 : 1.0;
    AnimalEntity.kHungerScale = _policies.winterFodder ? 0.55 : 1.0;
    WoodcutterEntity.kChopSpeedScale = _policies.treePlanting ? 0.85 : 1.0;
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
    // Sağ-dock: bina paneliyle tutarlı, hep sağ kenarda. Backdrop YOK — oyun
    // etkileşimli kalır (haritada başka köylüye tıklayıp panele geçilebilir).
    // Yüksekse scroll eder (yaşam öyküsü uzun olabilir).
    return Positioned(
      top: 64,
      right: 14,
      bottom: 96,
      child: SafeArea(
        child: SingleChildScrollView(
          child: VillagerInfoPanel(
        villager: v,
        homeLabel: v.homeBuilding == null
            ? null
            : kBuildingMeta[(v.homeBuilding as BuildingEntity).type]?.label,
        isFollowed: _followedVillager == v,
        onClose: () => setStateHere(() => _selectedVillager = null),
        onSelect: (next) => setStateHere(() => _selectedVillager = next),
        onToggleFollow: () => _toggleFollowVillager(v),
        onToggleFavorite: () => setStateHere(() => v.isFavorite = !v.isFavorite),
        onRename: (newName) {
          final cleaned = newName.trim();
          if (cleaned.isEmpty || cleaned.length > 20) return;
          setStateHere(() => v.name = cleaned);
        },
        // Kan davası yargısı — geri alınamaz, onay ister.
        onExile: () => setStateHere(() => _pendingJudgment = (v, false)),
        onExecute: () => setStateHere(() => _pendingJudgment = (v, true)),
          ),
        ),
      ),
    );
  }

  /// Kan davası yargısı onay modalı — sürgün/idam geri alınamaz, oyuncu onaylar.
  /// `_pendingJudgment` = (hedef, idam mı). Mirror: buildExitConfirm pattern.
  Widget buildJudgmentConfirm() {
    final (v, lethal) = _pendingJudgment!;
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setStateHere(() => _pendingJudgment = null),
              child: Container(color: const Color(0x99000000)),
            ),
          ),
          Center(
            child: AppPanel(
              width: 340,
              accent: AppUi.rust,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lethal ? '⚖️ İdam kararı' : '🚷 Sürgün kararı',
                      style: AppUi.title),
                  const SizedBox(height: 8),
                  Text(
                    lethal
                        ? '${v.name} halkın önünde idam edilecek. Kan davası kanla '
                            'kapanır ama köyü dehşet sarar. Bu karar geri alınamaz.'
                        : '${v.name} köyden sürülecek. Kan davası uzaklaştırmayla '
                            'diner. Bu karar geri alınamaz.',
                    style: AppUi.body.copyWith(color: AppUi.textMid),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: 'Vazgeç',
                          kind: AppButtonKind.ghost,
                          onTap: () => setStateHere(() => _pendingJudgment = null),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppButton(
                          label: lethal ? 'İdam et' : 'Sürgün et',
                          kind: AppButtonKind.filled,
                          tint: AppUi.rust,
                          onTap: () {
                            setStateHere(() {
                              _pendingJudgment = null;
                              _selectedVillager = null;
                              if (lethal) {
                                _executeVillager(v);
                              } else {
                                _exileVillager(v);
                              }
                            });
                          },
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

  // ── NPC etkileşim eylemleri (Takip et) ────────────────────────────────────

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
          onOpenConsole: () => setStateHere(() {
            _devPanelOpen = false;
            _devConsoleOpen = true;
          }),
          onToggleGod: () => setStateHere(() => _godMode = !_godMode),
          onSetRain: (v) => setStateHere(() => _cycle.rainIntensity = v),
          onSetTimeOfDay: (v) => setStateHere(() => _cycle.timeOfDay = v),
          onTriggerEvent: (e) {
            setStateHere(() {
              if (e.needsChoice) {
                _pendingChoice = e;
                _showNotification('${e.icon} ${e.title}. Köy karar bekliyor.');
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
          onUnlockAllCrafts: () => setStateHere(() {
            _knownCrafts.addAll(Craft.all);
            _showNotification('⚒ Tüm zanaatlar açıldı');
          }),
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
          // DEV: defteri tek hamlede doldur (GEÇİM kolu) / defteri yak.
          // Mühür geri alınmaz — ama dev paneli oyunun kuralına tabi değil.
          onAllPolicies: () => setStateHere(() {
            for (final l in LawBook.ofBranch(LawBranch.gecim)) {
              if (LawBook.available(l, _policies.sealed, _lawContext)) {
                _policies.seal(l);
              }
            }
            _policies.inkDryUntilSim = 0;
            _applyPolicySideChannels();
          }),
          onClearPolicies: () => setStateHere(() {
            _policies.restoreSealed(const []);
            _policies.inkDryUntilSim = 0;
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
          onSummonImperial: () {
            setStateHere(() => _devPanelOpen = false); // yaklaşan kolon görünsün
            _devSummonImperial();
          },
          onForcePetition: _forcePetition,
          onForcePetitionShortFuse: () {
            setStateHere(() => _devPanelOpen = false); // mühür/modal görünsün
            _forcePetitionShortFuse();
          },
          onForcePetitionAudience: () {
            setStateHere(() => _devPanelOpen = false); // zorla modal görünsün
            _forcePetitionAudienceNow();
          },
          petitions: [
            for (final p in PetitionSystem.all) (p.id, '${p.icon} ${p.title}'),
          ],
          onForcePetitionId: _forcePetitionById,
          perfMode: _perfMode,
          onTogglePerf: () => setStateHere(() => _perfMode = !_perfMode),
          devLogOn: _devLogOn,
          onToggleDevLog: () => setStateHere(() {
            _devLogOn = !_devLogOn;
            if (!_devLogOn) _devLog.clear();
          }),
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
          onStartConflict: () {
            if (!_devStartConflict()) {
              _showNotification('Yan yana iki uygun yetişkin NPC bulunamadı');
            }
          },
          onIgniteFeud: () => setStateHere(() {
            if (!_devIgniteFeud()) {
              _showNotification('Kan davası için 2 uygun köylü bulunamadı');
            }
          }),
          onStartCrime: () => setStateHere(() {
            if (!_devRandomCrime()) {
              _showNotification(_activeCrime != null
                  ? 'Zaten bir suç işleniyor'
                  : 'Uygun fail/hedef bulunamadı');
            }
          }),
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
              onOpenLedger: () => _openLedger(LedgerSection.tuzuk),
            );
          },
        ),
      ),
    );
  }

  // ── Zümre nabzı tabelası (sağ kenar, daima görünür) ─────────────────────────

  /// Ekranın sağ kenarında sabit, canlı zümre moral göstergesi. Belediye
  /// panelindeki nabzın ambient kardeşi — her kararın zümreleri nasıl oynattığı
  /// her an görünür. [[EstateBanner]] kendi nefes animasyonunu yürütür.
  Widget buildEstateBanner() {
    return Positioned(
      // Görevler paneliyle simetrik: aynı kenar boşluğu (14) + aynı top (190).
      right: 14,
      top: 190,
      child: RepaintBoundary(
        child: ListenableBuilder(
          listenable: _frame,
          builder: (_, _) => HouseBanner(
            houses: _houses.snapshot(),
            imperial: _imperialSnapshot(),
            identity: _houses.identityName,
            collapsed: _estateCollapsed,
            onToggleCollapse: () =>
                setStateHere(() => _estateCollapsed = !_estateCollapsed),
            onOpenDivan: () => _openLedger(LedgerSection.divan),
            agendaCount: _divanAgendaCount(),
          ),
        ),
      ),
    );
  }

  // ── Geçici bildirim balonu ─────────────────────────────────────────────────

  // Bina/NPC hover etiketi — imleç yanında küçük kart. _frame'e bağlı (üst
  // Stack tick'te rebuild olmaz). IgnorePointer: hover olaylarını yemez.
  Widget buildHoverLabel() {
    return Positioned.fill(
      child: IgnorePointer(
        child: ListenableBuilder(
          listenable: _frame,
          builder: (_, _) {
            final title = _hoverTitle;
            final pos = _hoverPos;
            if (title == null || pos == null) return const SizedBox.shrink();
            final w = _viewSize.width;
            // İmlecin sağ-üstüne yerleştir; sağ kenara taşarsa sola al.
            final left = (pos.dx + 16).clamp(0.0, (w - 180).clamp(0.0, w));
            final top = (pos.dy + 16).clamp(0.0, double.infinity);
            return Stack(children: [
              Positioned(
                left: left,
                top: top,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xF21A1B22),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0x33FFFFFF)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: AppUi.body.copyWith(
                              fontSize: 12.5,
                              color: AppUi.textHi,
                              fontWeight: FontWeight.w700)),
                      if (_hoverSub != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(_hoverSub!,
                              style: AppUi.body.copyWith(
                                  fontSize: 10.5, color: AppUi.textMid)),
                        ),
                    ],
                  ),
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }

  Widget buildNotificationToast() {
    return Positioned(
      top: 70,
      left: 0,
      right: 0,
      child: Center(
        child: AppReveal(
          child: AppChip(
            label: _notification!,
            color: AppUi.accent,
            solid: true,
          ),
        ),
      ),
    );
  }

  // ── Dev olay günlüğü konsolu ────────────────────────────────────────────────
  // Sol-altta yarı saydam, salt-okunur konsol: en yeni satır üstte ve parlak,
  // eskiler kademeli soluk. IgnorePointer → dokunuşları geçirir (oyun altında
  // tıklanabilir). Yalnız _devLogOn açıkken ve satır varken Stack'e eklenir.
  Widget buildDevLogConsole() {
    return Positioned(
      left: 12,
      bottom: 92,
      child: IgnorePointer(
        child: Container(
          width: 276,
          padding: const EdgeInsets.fromLTRB(11, 8, 11, 9),
          decoration: BoxDecoration(
            color: const Color(0xE60C1014),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('🎲', style: TextStyle(fontSize: 11)),
                  const SizedBox(width: 6),
                  Text(
                    'OLAY GÜNLÜĞÜ',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: Colors.white.withValues(alpha: 0.42),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_devLog.length}',
                    style: TextStyle(
                      fontSize: 9.5,
                      color: Colors.white.withValues(alpha: 0.30),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              for (int i = 0; i < _devLog.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Opacity(
                    opacity: (1.0 - i * 0.055).clamp(0.32, 1.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 4, right: 7),
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: _devLog[i].color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Text.rich(
                            TextSpan(children: [
                              if (_devLog[i].tag.isNotEmpty)
                                TextSpan(
                                  text: '${_devLog[i].tag} ',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              TextSpan(text: _devLog[i].text),
                            ]),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.25,
                              color: Colors.white.withValues(alpha: 0.88),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── İmparatorluk varış anonsu ───────────────────────────────────────────────
  // Kolon yaklaşırken birkaç saniyelik gergin, tam-ekran "İMPARATORLUK GELİYOR".
  // Sim'i DURDURMAZ (IgnorePointer → oyuncu kolonu görür, pan yapabilir). Giriş:
  // letterbox açılır + başlık slam-in (easeOut); çıkış: solar. Kırmızı vignette +
  // nabızlı kızıl glow = tehdit tonu. Cinzel oyma-kapital başlık.
  // TUZAK: bu anons dış widget ağacında duruyor ama o ağaç her frame rebuild
  // OLMUYOR (perf: sadece _frame/_hudFrame'e bağlı leaf'ler repaint eder).
  // ListenableBuilder olmadan intro fade/slam-in tek bir yarı-saydam karede
  // donuyordu ve ancak oyuncu tıklayınca (setState) "netleşiyordu".
  Widget buildImperialAlert() => ListenableBuilder(
        listenable: _frame,
        builder: (_, _) => _imperialAlertBody(),
      );

  Widget _imperialAlertBody() {
    const total = _VillageSceneState._kImperialAlertDur;
    if (_imperialAlertLeft <= 0) return const SizedBox.shrink();
    final left = _imperialAlertLeft.clamp(0.0, total);
    final elapsed = total - left;
    final introT = (elapsed / 0.5).clamp(0.0, 1.0);
    final outT = (left / 1.15).clamp(0.0, 1.0);
    final alpha = introT * outT;
    if (alpha <= 0.004) return const SizedBox.shrink();

    final ease = Curves.easeOutCubic.transform(introT);
    final scale = 1.0 + (1.0 - ease) * 0.13; // 1.13 → 1.0 slam-in
    final pulse = 0.5 + 0.5 * sin(_time * 3.4);
    final barH = 76.0 * ease;
    final w = _viewSize.width <= 0 ? 900.0 : _viewSize.width;
    final big = (w * 0.088).clamp(40.0, 96.0);
    final topSize = big * 0.60;

    const bone = Color(0xFFF0EEE9);
    const blood = Color(0xFFC9351F);

    Widget bar(bool isTop) => Container(
          height: barH,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: isTop ? Alignment.topCenter : Alignment.bottomCenter,
              end: isTop ? Alignment.bottomCenter : Alignment.topCenter,
              colors: const [Color(0xF2090607), Color(0x00090607)],
            ),
            border: Border(
              top: isTop
                  ? BorderSide.none
                  : BorderSide(color: blood.withValues(alpha: 0.45), width: 1.2),
              bottom: isTop
                  ? BorderSide(color: blood.withValues(alpha: 0.45), width: 1.2)
                  : BorderSide.none,
            ),
          ),
        );

    return Positioned.fill(
      child: IgnorePointer(
        child: Opacity(
          opacity: alpha.clamp(0.0, 1.0),
          child: Stack(
            children: [
              // Kanlı vignette — TÜM ekranı bastır (HUD panelleri de dahil geri
              // çekilsin), kenarlara doğru neredeyse siyaha git.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.18,
                    colors: [
                      Color(0x9E0B0605),
                      Color(0xCC240808),
                      Color(0xF5120402),
                    ],
                    stops: [0.0, 0.68, 1.0],
                  ),
                ),
                child: SizedBox.expand(),
              ),
              // Sinematik letterbox — üst/alt.
              Positioned(top: 0, left: 0, right: 0, child: bar(true)),
              Positioned(bottom: 0, left: 0, right: 0, child: bar(false)),
              // Okunabilirlik perdesi — radial vignette merkezi ŞEFFAF; parlak
              // gündüz köyü üstünde başlık kaybolmasın diye yalnız merkez metin
              // bloğunun arkasını yumuşakça karartır (kenarlarda tamamen erir).
              const Center(
                child: FractionallySizedBox(
                  widthFactor: 0.92,
                  heightFactor: 0.62,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        radius: 0.72,
                        colors: [
                          Color(0xCF0B0605),
                          Color(0x780B0605),
                          Color(0x000B0605),
                        ],
                        stops: [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
              // Merkez başlık bloğu.
              Center(
                child: Transform.scale(
                  scale: scale,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 5),
                        child: Text(
                          '⚔   D I Ş   G Ü Ç',
                          style: AppUi.label.copyWith(
                            color: blood.withValues(alpha: 0.75 + 0.25 * pulse),
                            letterSpacing: 5,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // letterSpacing son harfin SAĞINA da boşluk koyar →
                      // ortalama sola kayar; eşit padding ile telafi et.
                      Padding(
                        padding: EdgeInsets.only(left: topSize * 0.05),
                        child: Text(
                          'İMPARATORLUK',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Cinzel',
                            fontWeight: FontWeight.w700,
                            fontSize: topSize,
                            height: 1.0,
                            letterSpacing: topSize * 0.05,
                            color: bone,
                            shadows: const [
                              Shadow(color: Colors.black, blurRadius: 16),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(left: big * 0.08),
                        child: Text(
                          'GELİYOR',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Cinzel',
                            fontWeight: FontWeight.w900,
                            fontSize: big,
                            height: 1.06,
                            letterSpacing: big * 0.08,
                            color: blood,
                            shadows: [
                              Shadow(
                                  color:
                                      blood.withValues(alpha: 0.35 + 0.35 * pulse),
                                  blurRadius: 38),
                              const Shadow(color: Colors.black54, blurRadius: 12),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Kan-kırmızı hat + elmas.
                      SizedBox(
                        width: 244,
                        height: 10,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              height: 1.5,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [
                                  blood.withValues(alpha: 0),
                                  blood.withValues(alpha: 0.85),
                                  blood.withValues(alpha: 0),
                                ]),
                              ),
                            ),
                            Transform.rotate(
                              angle: 0.7853981634,
                              child: Container(width: 7, height: 7, color: blood),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 470),
                        child: Text(
                          _imperialAlertSub,
                          textAlign: TextAlign.center,
                          style: AppUi.body.copyWith(
                            color: bone.withValues(alpha: 0.86),
                            fontSize: 13.5,
                            height: 1.5,
                            shadows: const [
                              Shadow(color: Colors.black, blurRadius: 8),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
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
                : '${kBuildingMeta[_placing!]!.label} — tıkla (basılı tut: çoklu)',
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

  /// Bir köylünün ev kademesi → Nüfus Defteri etiketi + sıralama katı.
  /// tier: 0 evsiz · 1 çadır · 2 ahşap · 3 taş · 4 konak.
  (String, int) _housingInfo(VillagerEntity v) {
    final home = v.homeBuilding;
    if (home == null) return ('Evsiz', 0);
    switch ((home as BuildingEntity).type) {
      case BuildingType.manor:
        return ('Konak', 4);
      case BuildingType.stoneHouseBlue:
      case BuildingType.stoneHouseGreen:
        return ('Taş Ev', 3);
      case BuildingType.woodenHouse:
        return ('Ahşap Ev', 2);
      case BuildingType.tent:
        return ('Çadır', 1);
      default:
        return ('Barınak', 2);
    }
  }
}

/// Dev olay günlüğü satırı. [seq] artan sıra no (debug), [tag] kısa kategori
/// işareti, [text] gösterilecek metin, [color] kanal noktası rengi.
class DevLogEntry {
  final int seq;
  final String tag;
  final String text;
  final Color color;
  const DevLogEntry(this.seq, this.tag, this.text, this.color);
}
