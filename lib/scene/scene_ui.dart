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

  // Cevher (demir/kömür) HUD hücreleri — maden dikilene dek ikisi de hep 0
  // olur, boş sayaç göstermenin anlamı yok. Maden varsa ya da elde/yolda cevher
  // varsa açılır (kayıt/senaryo stoklu başlarsa da doğru davranır).
  bool get _showOreInHud =>
      _stockpile.iron > 0 ||
      _stockpile.coal > 0 ||
      _ironInTransit > 0 ||
      _coalInTransit > 0 ||
      _buildings.any((b) => b.type == BuildingType.mineBuilding);

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
              // PERF: setState DEĞİL — künye _frame'e bağlı, bir sonraki karede
              // kendiliğinden söner (imleç her çıkışında tam ağaç rebuild etme).
              onExit: (_) => _clearHover(),
              child: RepaintBoundary(
                child: ListenableBuilder(
                  listenable: _frame,
                  builder: (_, _) => CustomPaint(
                    painter: VillageGamePainter(
                      villagers: _villagers,
                      merchants: _merchants,
                      soldiers: _soldiers,
                      buildings: _buildings,
                      pendingOrders: _orders,
                      roadSystem: _roadSystem,
                      pendingRoadOrders: _roadOrders,
                      camera: _camera + _shakeOffset,
                      ghostType: _placing,
                      ghostTile: _ghost,
                      ghostValid: _ghost != null && _placing != null
                          ? _isValidPlacement(_ghost!.$1, _ghost!.$2, _placing!)
                          : false,
                      roadPreview: _roadPreview,
                      roadPreviewSurface: _placingRoad,
                      roadPreviewVersion: _roadPreviewV,
                      revealTiles: _revealTiles(),
                      time: _time,
                      overlayTop: _cycle.overlayTop,
                      overlayBottom: _cycle.overlayBottom,
                      rainIntensity: _cycle.rainIntensity,
                      nightClarity: _cycle.nightClarity,
                      // Adımın dünyadaki hedefi — yönlendirmenin görsel ayağı.
                      stepBeacon: _stepBeacon,
                      farmTiles: _farmTiles,
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
                      berryBushes: _berryBushes,
                      decor: _decor,
                      graves: _graves,
                      reedBeds: _reedBeds,
                      cows: _cows,
                      zoom: _zoom,
                      resourceBoxes: _resourceBoxes,
                      hayEntities: _hayEntities,
                      eggs: _eggs,
                      lootCaches: _lootCaches,
                      lootFade: _SceneCrime._kLootFade,
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
          // Kadro sayaçları ÜSTLENİLMİŞ İŞTEN okunur — eski anonim işçi
          // listeleri kaldırıldı (hepsi ömrü boyunca boştu, sayaçlar hep 0'dı).
          farmerCount: _jobCount(JobRole.farmer),
          woodcutterCount: _jobCount(JobRole.woodcutter),
          minerCount: _jobCount(JobRole.miner),
          fisherCount: _jobCount(JobRole.fisher),
          builderCount: _jobCount(JobRole.builder),
          shepherdCount: _jobCount(JobRole.shepherd),
          floristCount: _jobCount(JobRole.florist),
          homelessCount: _villagers.where((v) => v.homeBuilding == null).length,
          busyBuilders: _villagers
              .where((v) => v.job?.role == JobRole.builder && v.job!.working)
              .length,
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
          starving: !_godMode && _stockpile.food < _starveRamp,
          eventLabel: _eventLabel,
          stockCapacity: _godMode ? (1 << 30) : _stats.stockCapacity,
          showOre: _showOreInHud,
          fullPulse: sin(_time * 3.2) * 0.5 + 0.5,
          moraleBreakdown: _moraleBreakdown(),
          onHighlightHomeless: _highlightHomeless,
          effectTimeLeft: _eventMoraleLeft,
          effectDuration: _activeEvent?.duration ?? 1,
          effectPositive: (_eventMorale >= 0),
          onToggleDev: () => setStateHere(() => _devPanelOpen = !_devPanelOpen),
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
          // ŞU ANKİ ADIM — Köy Defteri'ni açmadan görünür tek satır.
          stepText: _currentStep?.quest.label,
          stepIcon: _currentStep == null
              ? null
              : questGlyph(_currentStep!.quest.id),
          stepWho: _currentStep?.speakerName,
          // Oyun dışı işler telefonda ray'ın araçlar menüsünde (masaüstünde
          // sol-üst "⚙ Menü" kümesi olarak kalır).
          onSaveNow: () => _saveNow(manual: true),
          onExitToMenu: () => setStateHere(() => _exitConfirmOpen = true),
          sheetOpen:
              _detailExpanded &&
              (_selectedVillager != null || _selectedBuilding != null),
        ),
      ),
    );
  }

  // ── KOMUTA ÇUBUĞU (konsept 04) — tek alt hat: inşa · bağlam · menü ─────────

  /// Oyunun tek alt komuta çubuğu. Eski buildBottomToolbar + ObjectivePanel +
  /// LedgerSeal + sağ-dock seçim panellerini tek hatta toplar.
  Widget buildCommandBar() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: RepaintBoundary(
        child: ListenableBuilder(
          listenable: _frame,
          builder: (_, _) => CommandBar(
            agenda: _divanAgendaCount(),
            onDefter: () => _openLedger(LedgerSection.tuzuk),
            onDivan: () => _openLedger(LedgerSection.divan),
            onRoster: () => _openLedger(LedgerSection.nufus),
            buildSegment: _commandBuildSegment(),
            context: _commandContext(),
          ),
        ),
      ),
    );
  }

  /// Sol segment — inşa paleti (ateş yoksa yalnız ateş kartı; sonra kategori
  /// sekmesi + kartlar). Eski alt çubuğun içeriğini yeniden kullanır.
  Widget _commandBuildSegment() {
    if (kBuildingMeta.isEmpty) return const SizedBox.shrink();
    if (!_hasFire) {
      return BuildingPanel(
        stockpile: _stockpile,
        selected: _placing,
        hasFirepit: false,
        // Adımın istediği kart — ateş yokken katalogda zaten tek kart var ama
        // işaret yine de konur: oyuncunun ilk hamlesi budur.
        hintType: _stepBuildTarget,
        onSelect: _onSelectBuilding,
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildCategoryTabs(),
        const SizedBox(height: 4),
        _buildCategoryContent(),
      ],
    );
  }

  /// Orta segment — seçili bina/köylünün kompakt bağlamı + birincil eylemler.
  /// Tam ayrıntı "Detay" ile açılır (_detailExpanded). Seçim yoksa null → ipucu.
  CommandContext? _commandContext() {
    // İNŞA — palette'ten bir bina seçildiyse (yerleştirme modu) o binanın NE
    // İŞE YARADIĞINI göster (açıklama). "Bir bina seç" ipucunun yerini alır.
    final p = _placing;
    if (p != null) {
      return CommandContext(
        title: kBuildingMeta[p]?.label ?? '—',
        description:
            kBuildingFunctions[p]?.summary ??
            'Boş bir yere tıklayarak yerleştir.',
        actions: [
          CommandAction(
            'Vazgeç',
            GameIconData.close,
            onTap: () => setStateHere(() {
              _placing = null;
              _ghost = null;
            }),
          ),
        ],
      );
    }
    final b = _selectedBuilding;
    if (b != null) {
      final res = _villagers.where((v) => v.homeBuilding == b).toList();
      final cap = kBuildingFunctions[b.type]?.housingCapacity ?? 0;
      final sub = res.isNotEmpty && res.first.surname.isNotEmpty
          ? '${res.first.surname} Hanesi'
          : null;
      final isFirepit = b.type == BuildingType.firepit;
      return CommandContext(
        title: kBuildingMeta[b.type]?.label ?? '—',
        subtitle: sub,
        stats: [if (cap > 0) ('Sakinler', '${res.length}/$cap', AppUi.sage)],
        actions: [
          CommandAction(
            'Detay',
            GameIconData.scroll,
            onTap: () => setStateHere(() => _detailExpanded = true),
          ),
          CommandAction(
            'Şenlik',
            GameIconData.festival,
            onTap: () => _hostFestival(b),
          ),
          if (!isFirepit)
            CommandAction(
              'Taşı',
              GameIconData.hammer,
              onTap: () => _demolishBuilding(b, refund: 1.0, reselect: true),
            ),
          if (!isFirepit)
            CommandAction(
              'Yık',
              GameIconData.demolish,
              danger: true,
              onTap: () => _demolishBuilding(b, refund: 0.5),
            ),
        ],
      );
    }
    final v = _selectedVillager;
    if (v != null) {
      return CommandContext(
        title: v.name,
        subtitle: v.hasProfession ? v.type.displayName : 'köylü',
        actions: [
          CommandAction(
            'Detay',
            GameIconData.scroll,
            onTap: () => setStateHere(() => _detailExpanded = true),
          ),
        ],
      );
    }
    return null;
  }

  /// Görev takipçisi — sağ üst. Eski sürekli-açık ObjectivePanel'in yerini alır;
  /// yalnız aktif görev + kademe ilerlemesi, tam liste Defter'de.
  Widget buildQuestTracker() {
    final compact = useCompactGameUi(context);
    return Positioned(
      // MOBİL: üst şeridin TAM ALTINDA, sabit [MobileUi.railW] genişliğinde —
      // böylece sağ kenar tek bir hat olur. Eskiden serbest genişlikteydi ve
      // şeritle arasında birkaç piksellik kayma vardı; ekranda "hizasız
      // kutular" hissi buradan geliyordu.
      right: compact ? MobileUi.edgeRight(context) : 14,
      top: compact ? MobileUi.top(context) + MobileUi.barH + MobileUi.gap : 92,
      width: compact ? MobileUi.railW : null,
      child: RepaintBoundary(
        child: ListenableBuilder(
          listenable: _frame,
          builder: (_, _) {
            final ctx = _questContext();
            final quests = QuestBook.activeQuests(ctx, _completedQuests);
            final tier = QuestBook.tierOf(_charterTier);
            final active =
                quests.where((q) => q.active).firstOrNull ?? quests.firstOrNull;
            if (active == null) return const SizedBox.shrink();
            return QuestTracker(
              icon: questGlyph(active.quest.id),
              activeLabel: active.quest.label,
              tierName: tier.name,
              done: _completedQuests.length,
              total: QuestBook.all.length,
              onOpen: () => _openLedger(LedgerSection.tuzuk),
            );
          },
        ),
      ),
    );
  }

  /// Seçili kategorinin içeriği — bina kategorisinde palet, Arazi/Yol'da
  /// yol döşeme + Tarla/Kes/Kaz modları.
  Widget _buildCategoryContent() {
    if (_buildCategory == BuildCategory.araziYol) {
      final tools = _buildLandRoadTools();
      if (!useCompactGameUi(context)) return tools;
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: tools,
      );
    }
    return BuildingPanel(
      stockpile: _stockpile,
      selected: _placing,
      hasFirepit: _hasFire,
      category: _buildCategory,
      isUnlocked: _isCraftKnown,
      hintType: _stepBuildTarget,
      onSelect: _onSelectBuilding,
    );
  }

  /// Kategori sekmeleri — alt çubuğun kalabalık tek sırasını gruplara böler.
  Widget _buildCategoryTabs() {
    final tabs = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final cat in BuildCategory.values) ...[
          if (cat != BuildCategory.values.first) const SizedBox(width: 4),
          _categoryTab(cat),
        ],
      ],
    );
    if (useCompactGameUi(context)) {
      return SizedBox(
        height: 46,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: tabs,
        ),
      );
    }
    return AppPanel(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: tabs,
    );
  }

  Widget _categoryTab(BuildCategory cat) {
    final sel = _buildCategory == cat;
    final compact = useCompactGameUi(context);
    // ADIM İŞARETİ — aranan kart BAŞKA bir sekmedeyse önce oraya geçmek gerek.
    // Kartın etrafındaki halka, kart görünmüyorken hiçbir işe yaramaz; zincirin
    // ilk halkası bu sekmedir. Zaten açık olan sekme işaretlenmez (oyuncuyu
    // bulunduğu yere yönlendirmenin anlamı yok).
    final target = _stepBuildTarget;
    final hinted =
        !sel && target != null && kBuildingCategory[target] == cat;
    return GestureDetector(
      onTap: () => setStateHere(() => _buildCategory = cat),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        // 44 = Apple HIG dokunma eşiği. 40'a indirmeyi denedim, harness altı
        // kategori sekmesini de "tap<44" diye işaretledi — 4dp uğruna doğru
        // takas değil.
        constraints: compact
            ? const BoxConstraints(minHeight: 44)
            : const BoxConstraints(),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: sel
              ? Color.alphaBlend(
                  AppUi.accent.withValues(alpha: 0.22),
                  AppUi.surface2,
                )
              : AppUi.surface0,
          borderRadius: BorderRadius.circular(AppUi.radiusSm),
          border: Border.all(
            // İşaretli sekme seçili gibi DURMAZ: seçili kenar dolu ember,
            // işaret ise yarı ember. İki durum karışırsa oyuncu sekmenin açık
            // olduğunu sanır ve boş kataloğa bakar.
            color: sel
                ? AppUi.accent
                : hinted
                ? AppUi.accent.withValues(alpha: 0.55)
                : AppUi.line,
            width: sel ? 1.4 : (hinted ? 1.4 : 1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(cat.icon, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 5),
            Text(
              cat.label.toUpperCase(),
              style: AppUi.button.copyWith(
                fontSize: compact ? 11 : 9.5,
                letterSpacing: 0.8,
                color: sel ? AppUi.accentSoft : AppUi.textMid,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ŞEFFAFLIK HEDEFLERİ — "şu an burada bir şey kuruluyor/planlanıyor" diyen
  /// tile'lar. Bunları ÖRTEN binaları painter yarı saydam çizer.
  ///
  /// İzometride önde duran bir bina arkasındaki şantiyeyi ve yolu tamamen
  /// yutuyordu; oyuncu nereye ne kurduğunu göremiyordu. Kapsam:
  ///   • hayalet bina (yerleştirme anı)      • süren şantiyeler
  ///   • bekleyen yol emirleri               • sürüklenen yol önizlemesi
  /// Hiçbiri yoksa boş set döner → painter pass'i hiç çalıştırmaz.
  Set<(int, int)> _revealTiles() {
    if (_placing == null &&
        _orders.isEmpty &&
        _roadOrders.isEmpty &&
        _roadPreview.isEmpty) {
      return const {};
    }
    final out = <(int, int)>{};
    void addFootprint(int col, int row, BuildingType type) {
      final m = kBuildingMeta[type];
      if (m == null) return;
      for (int c = col; c < col + m.cols; c++) {
        for (int r = row; r < row + m.rows; r++) {
          out.add((c, r));
        }
      }
    }

    if (_placing != null && _ghost != null) {
      addFootprint(_ghost!.$1, _ghost!.$2, _placing!);
    }
    for (final o in _orders) {
      if (o.completed) continue;
      addFootprint(o.col, o.row, o.type);
    }
    for (final o in _roadOrders) {
      if (o.completed) continue;
      out.add((o.col, o.row));
    }
    for (final (tile, _) in _roadPreview) {
      out.add(tile);
    }
    return out;
  }

  /// Bina seçimi — modları temizle, aynı binaya basınca bırak (toggle).
  void _onSelectBuilding(BuildingType type) => setStateHere(() {
    _farmMode = false;
    _lumberMode = false;
    _mineMode = false;
    _placingRoad = null;
    _roadErase = false;
    _clearRoadDrag();
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
            _roadErase = false;
            _placingRoad = _placingRoad == s ? null : s;
            _clearRoadDrag();
          }),
          eraseSelected: _roadErase,
          onSelectErase: () => setStateHere(() {
            _placing = null;
            _ghost = null;
            _farmMode = false;
            _lumberMode = false;
            _mineMode = false;
            _placingRoad = null;
            _roadErase = !_roadErase;
            _clearRoadDrag();
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
            _roadErase = false;
            _clearRoadDrag();
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
            _roadErase = false;
            _clearRoadDrag();
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
            _roadErase = false;
            _clearRoadDrag();
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
            child: Text(
              '🚫 $_placeReason',
              style: AppUi.bodyHi.copyWith(fontSize: 12, color: AppUi.rust),
            ),
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
              // Detay'ı kapat → komuta çubuğunda kompakt bağlama dön (seçim durur).
              onTap: () => setStateHere(() => _detailExpanded = false),
              child: Container(color: const Color(0x2D000000)),
            ),
          ),
          // Sağ-dock: tüm seçim panelleri tutarlı biçimde sağ kenarda açılır.
          // Mobilde köylü paneliyle AYNI yuva (bkz. buildSelectedVillagerPanel).
          Positioned(
            top: useCompactGameUi(context) ? MobileUi.top(context) : 64,
            right: useCompactGameUi(context) ? MobileUi.right(context) : 14,
            bottom: useCompactGameUi(context)
                ? MobileUi.bottom(context) + MobileUi.actionH + MobileUi.gap
                : 96,
            child: _detailFrame(
              compact: useCompactGameUi(context),
              child: BuildingInfoPanel(
                building: selected,
                residents: _villagers
                    .where((v) => v.homeBuilding == selected)
                    .toList(),
                barnCows:
                    (selected.type == BuildingType.barn ||
                        selected.type == BuildingType.chickenCoop)
                    ? _cows
                          .where(
                            (c) =>
                                c.barnCol == selected.col &&
                                c.barnRow == selected.row,
                          )
                          .toList()
                    : const [],
                onBuyAnimal:
                    (selected.type == BuildingType.barn ||
                        selected.type == BuildingType.chickenCoop)
                    ? (kind) => _buyAnimal(selected, kind)
                    : null,
                stockpile: _stockpile,
                stats: _stats,
                population: _villagers.length,
                populationCap: _populationCap(),
                onClose: () => setStateHere(() => _detailExpanded = false),
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
                    : () => _demolishBuilding(
                        selected,
                        refund: 1.0,
                        reselect: true,
                      ),
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
        ],
      ),
    );
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
    final mouths = _villagers.length - exemptElders;
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
      _eventMorale = moraleBoost;
      _eventMoraleLeft = durationSec;
      _eventLabel = '🎉 Şenlik';
      b.lastSaleTime = _time; // küçük görsel parıltı
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
    _showNotification(
      touched > 0 ? '💧 $touched ev dolduruldu' : '💧 Bütün evler zaten dolu',
    );
  }

  // ── Köylü bilgi paneli — bina paneliyle aynı pozisyon ─────────────────────

  Widget buildSelectedVillagerPanel() {
    final v = _selectedVillager!;
    // Sağ-dock: bina paneliyle tutarlı, hep sağ kenarda. Backdrop YOK — oyun
    // etkileşimli kalır (haritada başka köylüye tıklayıp panele geçilebilir).
    //
    // MOBİL: yuva ızgaradan gelir (üst gutter → alt gutter) ve panel onu
    // DOLDURUR; kaydırma panelin İÇİNDE olur. Dıştaki SingleChildScrollView
    // telefonda yanlıştı — paneli sınırsız yükseklikte bırakıp altını
    // kırptırıyordu ("yarısı kesik kutu" görüntüsü).
    final compact = useCompactGameUi(context);
    return Positioned(
      top: compact ? MobileUi.top(context) : 64,
      right: compact ? MobileUi.right(context) : 14,
      bottom: compact
          ? MobileUi.bottom(context) + MobileUi.actionH + MobileUi.gap
          : 96,
      child: _detailFrame(
        compact: compact,
        child: VillagerInfoPanel(
          villager: v,
          homeLabel: v.homeBuilding == null
              ? null
              : kBuildingMeta[(v.homeBuilding as BuildingEntity).type]?.label,
          isFollowed: _followedVillager == v,
          onClose: () => setStateHere(() => _detailExpanded = false),
          onSelect: (next) => setStateHere(() => _selectedVillager = next),
          onToggleFollow: () => _toggleFollowVillager(v),
          onToggleFavorite: () =>
              setStateHere(() => v.isFavorite = !v.isFavorite),
          onRename: (newName) {
            final cleaned = newName.trim();
            if (cleaned.isEmpty || cleaned.length > 20) return;
            setStateHere(() => v.name = cleaned);
          },
          // ELLE İŞ VERME — köyün işleri artık kendiliğinden dağılmak zorunda
          // değil; oyuncu bir köylüyü bir işe kilitleyebilir.
          assignableRoles: _assignableJobRoles(),
          // Adımın istediği rol — zincirin son halkası (dünyadaki halka doğru
          // köylüyü, bu da doğru düğmeyi gösterir).
          hintRole: _stepJobTarget,
          onAssignJob: (role) => setStateHere(() => _assignVillagerJob(v, role)),
          // Kan davası yargısı — geri alınamaz, onay ister.
          onExile: () => setStateHere(() => _pendingJudgment = (v, false)),
          onExecute: () => setStateHere(() => _pendingJudgment = (v, true)),
        ),
      ),
    );
  }

  /// Detay panelinin ÇERÇEVESİ — telefonda ve masaüstünde farklı iş yapar.
  ///
  /// Masaüstü: panel doğal boyunda, taşarsa dıştan kayar (eski davranış).
  /// Mobil: panel yuvayı doldurur, kaydırma İÇERİDE olur — böylece başlık ve
  /// eylem kuşağı yerinde kalır, panelin altı ekranın altında kesilmez.
  Widget _detailFrame({required bool compact, required Widget child}) {
    if (compact) return child;
    return SafeArea(child: SingleChildScrollView(child: child));
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
                  Text(
                    lethal ? '⚖️ İdam kararı' : '🚷 Sürgün kararı',
                    style: AppUi.title,
                  ),
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
                          onTap: () =>
                              setStateHere(() => _pendingJudgment = null),
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
        // "İzle" kilidi varsa düşür — iki kamera kanalı aynı kareyi
        // çekiştirirse ikisi de titrer (bkz. _tickWatchCamera).
        _watchLeft = 0;
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
          onSetDawn: () => setStateHere(() => _cycle.timeOfDay = 0.22),
          onSetNoon: () => setStateHere(() => _cycle.timeOfDay = 0.50),
          onSetDusk: () => setStateHere(() => _cycle.timeOfDay = 0.78),
          onSetNight: () => setStateHere(() => _cycle.timeOfDay = 0.92),
          onToggleRain: () => setStateHere(() {
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
              _showNotification('👵 ${sage.name} köyün bilgesi yapıldı (test)');
            }
          }),
          onSpawnMigrant: () => setStateHere(_spawnMigrant),
          onSummonImperial: () {
            setStateHere(
              () => _devPanelOpen = false,
            ); // yaklaşan kolon görünsün
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
              _showNotification(
                _activeCrime != null
                    ? 'Zaten bir suç işleniyor'
                    : 'Uygun fail/hedef bulunamadı',
              );
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
              // "İzle" yalnız BU olayın vinyeti hâlâ sahnedeyse çıkar —
              // bittiyse (ya da kadro bulunamadıysa) düğme de yok: oyuncuyu
              // boş bir tarlaya götürmek, hiç göndermemekten kötüdür.
              final vg = _vignette;
              final canWatch = vg != null && vg.eventId == e.id;
              return EventBanner(
                event: e,
                timeLeft: _activeEventLeft,
                duration: kEventBannerDuration,
                watchLabel: canWatch ? vg.title : null,
                onWatch: canWatch ? _watchVignette : null,
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

  // ── Geçici bildirim balonu ─────────────────────────────────────────────────

  // Hover künyesi — DÜNYA-uzayı: imleci değil hedefi takip eder, köylü
  // yürüdükçe onunla gider. _frame'e bağlı (60fps) olduğu için hover olayının
  // kendisi hiçbir şey tetiklemez; input yalnız _hoverVillager/_hoverBuilding
  // alanlarını yazar. IgnorePointer: hover olaylarını yemez.
  Widget buildHoverLabel() {
    return Positioned.fill(
      child: IgnorePointer(
        child: ListenableBuilder(
          listenable: _frame,
          builder: (_, _) {
            // Sürükleme/seçim sırasında künye susar (iki bilgi katmanı çakışır).
            if (_draggedVillager != null) return const SizedBox.shrink();
            final v = _hoverVillager;
            final b = _hoverBuilding;
            final g = _hoverGrave;
            if (v == null && b == null && g == null) {
              return const SizedBox.shrink();
            }
            // 140ms beliriş — anlık pat diye çıkmasın, gecikmeli de hissetmesin.
            final fade = ((_time - _hoverSince) / 0.14).clamp(0.0, 1.0);
            final center = Offset(_viewSize.width / 2, _viewSize.height / 2);
            Offset toScreen(double gx, double gy) {
              final world = gridToScreen(gx, gy, _viewSize, _camera);
              return (world - center) * _zoom + center;
            }

            if (v != null) {
              final sc = kCharScale * v.lifeStage.renderScale * _zoom;
              final feet = toScreen(v.renderX, v.renderY);
              // Fare sabitken köylü yürüyüp gidebilir. O zaman künye onun
              // peşine takılıp ekranda gezmesin: gövde kutusundan çıktıysa
              // sadece ÇİZME (state'i temizleme — geri gelirse yine belirir).
              // Kutu geometrisi hit-test ile birebir (scene_world).
              final probe = _hoverProbe;
              if (probe != null) {
                final dx = (probe.dx - feet.dx).abs();
                final dy = (probe.dy - (feet.dy - 36 * sc)).abs();
                if (dx > (16.0 * sc).clamp(15.0, 60.0) ||
                    dy > (42.0 * sc).clamp(20.0, 90.0)) {
                  return const SizedBox.shrink();
                }
              }
              // Sprite tepesi ayak noktasından ~126 birim yukarıda (şapka
              // dahil; ui_gallery world_tag karesinden ölçüldü). DİKKAT:
              // _villagerAtScreen'deki 36/42 değerleri hit-test KUTUSUdur,
              // sprite boyu değil — künyeyi ondan türetmek şapkanın içine
              // yazar (ilk sürümün hatası).
              final top = feet.dy - 126 * sc;
              return Stack(
                children: [
                  WorldTagRing(
                    feet: feet,
                    radius: (14.0 * sc).clamp(11.0, 40.0),
                    opacity: fade,
                  ),
                  WorldTag(
                    anchor: Offset(
                      _tagX(feet.dx),
                      (top - 8).clamp(46.0, _viewSize.height),
                    ),
                    title: v.name,
                    line2: _tagIdentity(v),
                    line3: '${_tagDoing(v)} · ${_tagMood(v)}',
                    opacity: fade,
                  ),
                ],
              );
            }
            if (b != null) {
              final feet = toScreen(
                b.col + (b.cols - 1) / 2.0,
                b.row + (b.rows - 1) / 2.0,
              );
              // Çatı yüksekliği kabaca satır sayısından türer (bina sprite'ları
              // taban derinliğiyle birlikte uzar).
              final top = feet.dy - (44 + 20 * b.rows) * _zoom;
              return Stack(
                children: [
                  WorldTag(
                    anchor: Offset(
                      _tagX(feet.dx),
                      (top - 6).clamp(46.0, _viewSize.height),
                    ),
                    title: kBuildingMeta[b.type]?.label ?? '—',
                    line2: _buildingHoverSub(b),
                    line3: '',
                    opacity: fade,
                  ),
                ],
              );
            }
            final feet = toScreen(g!.col, g.row);
            return Stack(
              children: [
                WorldTag(
                  anchor: Offset(
                    _tagX(feet.dx),
                    (feet.dy - 34 * _zoom).clamp(46.0, _viewSize.height),
                  ),
                  title: g.name,
                  line2: 'huzur içinde yatıyor',
                  line3: '',
                  opacity: fade,
                  accent: const Color(0xFF7E86A0),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Künye ekran kenarından taşmasın — genişliği bilinmediği için kaba pay.
  double _tagX(double x) =>
      _viewSize.width < 220 ? x : x.clamp(96.0, _viewSize.width - 96.0);

  /// Künye 2. satırı: kim. Meslek + hangi hane (haneler sistemi ön planda —
  /// "kim kimin adamı" bir bakışta okunmalı).
  String _tagIdentity(VillagerEntity v) {
    final craft = v.hasProfession ? v.type.displayName : 'köylü';
    if (v.surname.isNotEmpty) return '$craft · ${v.surname} Hanesi';
    return v.homeBuilding == null ? '$craft · evsiz' : craft;
  }

  /// Künye 3. satırı, ilk yarısı: şu an ne yapıyor. Durum bozucular (hasta/
  /// yaralı/ceza) her şeyin önünde — oyuncunun görmesi gereken ilk şey o.
  String _tagDoing(VillagerEntity v) {
    if (v.activity == VillagerActivity.abducted) return 'kaçırıldı';
    if (v.laborDays > 0) return 'kürek çekiyor';
    if (v.sickDays > 0) return 'hasta';
    if (v.injuryDays > 0) return 'yaralı';
    switch (v.activity) {
      case VillagerActivity.chat:
        return 'sohbet ediyor';
      case VillagerActivity.music:
        return 'çalıyor';
      case VillagerActivity.dance:
        return 'oynuyor';
      case VillagerActivity.warm:
        return 'ısınıyor';
      case VillagerActivity.storytelling:
        return 'hikâye anlatıyor';
      case VillagerActivity.listening:
        return 'dinliyor';
      case VillagerActivity.arguing:
        return 'atışıyor';
      case VillagerActivity.brawling:
        return 'kavgada';
      case VillagerActivity.prowling:
        return 'sinsice dolaşıyor';
      case VillagerActivity.committing:
        return 'suçüstü';
      case VillagerActivity.fleeing:
        return 'kaçıyor';
      case VillagerActivity.chasing:
        return 'peşinde';
      case VillagerActivity.playing:
        return 'oyunda';
      case VillagerActivity.none:
      case VillagerActivity.abducted:
        break;
    }
    if (v.isSleeping) return 'uyuyor';
    if (v.isSeatedAtFire) return 'ateş başında';
    if (v.isCarrying) return 'yük taşıyor';
    switch (v.job?.role) {
      case JobRole.builder:
        return 'inşaatta';
      case JobRole.farmer:
        return 'tarlada';
      case JobRole.miner:
        return 'ocakta';
      case JobRole.fisher:
        return 'balıkta';
      case JobRole.florist:
        return 'çiçek topluyor';
      case JobRole.shepherd:
        return 'sürünün başında';
      case JobRole.woodcutter:
        return 'odun kesiyor';
      case JobRole.forager:
        return 'böğürtlen topluyor';
      case JobRole.cook:
        return 'yemek pişiriyor';
      case JobRole.none:
      case null:
        break;
    }
    return v.isWalking ? 'yolda' : 'boşta';
  }

  /// Künye 3. satırı, ikinci yarısı: ruh hâli. Sayı/yüzde YOK, tek kelime öbeği
  /// (baş üstü sayısal refleksiyon oyunun dilini bozar).
  String _tagMood(VillagerEntity v) {
    final m = v.morale;
    if (m >= 0.82) return 'neşesi yerinde';
    if (m >= 0.62) return 'keyfi iyi';
    if (m >= 0.45) return 'idare eder';
    if (m >= 0.30) return 'keyifsiz';
    if (m >= 0.16) return 'kırgın';
    return 'bezgin';
  }

  Widget buildNotificationToast() {
    // Sabit `top: 70` masaüstü varsayımıydı. iPhone 11'de (414dp yükseklik) o
    // hat tam olarak Köy Defteri'nin SEKME şeridine denk geliyor ve bildirim
    // TÜZÜK sekmesinin üstüne oturuyordu — geçici bir bildirim, kalıcı bir
    // gezinme öğesini örtmemeli. Telefonda toast alta iner (komuta çubuğunun
    // üstüne): orada yalnız içeriğin üstünden geçer, hiçbir kontrolü kapatmaz.
    final compact = useCompactGameUi(context);
    final toast = Center(
      child: AppReveal(
        child: AppChip(
          label: _notification!,
          color: AppUi.accent,
          solid: true,
        ),
      ),
    );
    if (!compact) {
      return Positioned(top: 70, left: 0, right: 0, child: toast);
    }
    return Positioned(
      left: 0,
      right: 0,
      bottom: MobileUi.bottom(context) + MobileUi.actionH + MobileUi.gap,
      child: toast,
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
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
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
                            TextSpan(
                              children: [
                                if (_devLog[i].tag.isNotEmpty)
                                  TextSpan(
                                    text: '${_devLog[i].tag} ',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                TextSpan(text: _devLog[i].text),
                              ],
                            ),
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
                                color: blood.withValues(
                                  alpha: 0.35 + 0.35 * pulse,
                                ),
                                blurRadius: 38,
                              ),
                              const Shadow(
                                color: Colors.black54,
                                blurRadius: 12,
                              ),
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
                                gradient: LinearGradient(
                                  colors: [
                                    blood.withValues(alpha: 0),
                                    blood.withValues(alpha: 0.85),
                                    blood.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                            ),
                            Transform.rotate(
                              angle: 0.7853981634,
                              child: Container(
                                width: 7,
                                height: 7,
                                color: blood,
                              ),
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
              : _roadMode
              ? const Color(0xEE2A1808)
              : const Color(0xEE1A3A1A),
          child: Text(
            _mineMode
                ? 'Madenci — sürükle seç, madenleri işaretle'
                : _lumberMode
                ? 'Oduncu — sürükle seç, bırak ağaçları işaretle'
                : _farmMode
                ? 'Tarla — sürükle seç, bırak onayla'
                : _roadMode
                ? _roadHint()
                : '${kBuildingMeta[_placing!]!.label} — tıkla (basılı tut: çoklu)',
            style: TextStyle(
              color: _mineMode
                  ? const Color(0xFFAABBFF)
                  : _lumberMode
                  ? const Color(0xFFFFAA44)
                  : _roadMode
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

  /// Yol modu ipucu — sürükleme sırasında CANLI bilanço: kaç tile döşenecek,
  /// neye mal olacak. Oyuncu bırakmadan önce ne alacağını bilir; "yanlışlıkla
  /// yol döşedim" için yer kalmaz.
  String _roadHint() {
    if (_roadPreview.isEmpty) {
      return _roadErase
          ? 'Yol Silgisi — sürükle, bırak kaldır'
          : '${_placingRoad!.label} — sürükle, bırak döşe (dik güzergâh)';
    }
    final ok = _roadPreview.where((e) => e.$2).length;
    if (_roadErase) {
      return ok == 0
          ? 'Yol Silgisi — güzergâhta yol yok'
          : 'Yol Silgisi — $ok tile kaldırılacak (bırak onayla)';
    }
    if (ok == 0) return '${_placingRoad!.label} — güzergâh uygun değil';
    final bill = [
      for (final (kind, amt) in _placingRoad!.cost.entries)
        '${amt * ok} ${kind.icon}',
    ].join(' ');
    return '${_placingRoad!.label} — $ok tile · '
        '${bill.isEmpty ? 'bedava' : bill} (bırak onayla)';
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
