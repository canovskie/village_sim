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
        if (kCaptureVisitors && !kCaptureVisitorsFocused) {
          _focusVisitorCapture();
        }
        final effectivePerfMode =
            _perfMode ||
            useReducedEffectsForViewport(
              _viewSize,
              MediaQuery.devicePixelRatioOf(ctx),
            );
        return Listener(
          onPointerSignal: _onCanvasPointerSignal,
          child: GestureDetector(
            key: const ValueKey('game_canvas_gesture'),
            onScaleStart: _onCanvasScaleStart,
            onScaleUpdate: _onCanvasScaleUpdate,
            onScaleEnd: _onCanvasScaleEnd,
            onTapUp: _onCanvasTapUp,
            // Aktif araçlarda çift-dokunma zaten anlamsız. Recognizer'ı yalnız
            // handler içinde reddetmek yetmiyor: ilk dokunuşu ~300ms bekletip
            // yol/tarla iki-nokta akışının ikinci dokunuşuyla yarışıyordu.
            // Araç açıkken recognizer'ı tamamen kaldır → dokunuş anında düşer.
            onDoubleTapDown:
                (_roadMode ||
                    _mineMode ||
                    _lumberMode ||
                    _farmMode ||
                    _placing != null)
                ? null
                : _onCanvasDoubleTapDown,
            onDoubleTap:
                (_roadMode ||
                    _mineMode ||
                    _lumberMode ||
                    _farmMode ||
                    _placing != null)
                ? null
                : _onCanvasDoubleTap,
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
                      landmarks: _landmarks,
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
                      perfMode: effectivePerfMode,
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
          onboarding:
              _charterTier == 0 && (_guideActive || _guideWanted || _guideOpen),
          moraleBreakdown: _moraleBreakdown(),
          onHighlightHomeless: _highlightHomeless,
          effectTimeLeft: _eventMoraleLeft,
          effectDuration: _activeEvent?.duration ?? 1,
          effectPositive: _eventMorale >= 0,
          onToggleDev: () => setStateHere(() => _devPanelOpen = !_devPanelOpen),
          muted: SettingsModel.instance.muted,
          onToggleMute: () => setStateHere(SettingsModel.instance.toggleMute),
          godMode: _godMode,
          onNewMap: () => setStateHere(_generateWorld),
          onOpenRoster: () => _openLedger(LedgerSection.nufus),
          onToggleGod: () => setStateHere(() => _godMode = !_godMode),
          onTriggerEvent: _triggerRandomEvent,
          timeScale: _timeScale,
          onCycleSpeed: _cycleSpeed,
          // Aktif adımın tek evi sağdaki QuestTracker. Aynı başlığı HUD'ın
          // solunda ikinci kez çizmek kuruluşu iki ayrı görev sistemiymiş gibi
          // gösteriyordu; Hud'un opsiyonel adım şeridi bu yüzden boş bırakılır.
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
            village: _villageName,
            showCivicGates: !_foundingModeActive,
            catalogOpen: _mobileBuildCatalogOpen,
            onCatalogOpenChanged: (open) =>
                setStateHere(() => _mobileBuildCatalogOpen = open),
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
    if (_foundingModeActive) {
      final target = _stepBuildTarget;
      if (target == null) return _foundingWorkStatus();
      return BuildingPanel(
        stockpile: _stockpile,
        selected: _placing,
        hasFirepit: _hasFire,
        onlyType: target,
        hintType: target,
        onSelect: _onSelectBuilding,
      );
    }
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

  /// Kuruluş kararları arasındaki kısa otomatik emek anı. Alakasız bina
  /// kartları açmak yerine köyün ne yaptığını tek satırda söyler.
  Widget _foundingWorkStatus() {
    final lumberReady = _buildings.any(
      (b) => b.type == BuildingType.lumberCamp,
    );
    final worker = _villagers.where((v) => v.hasActiveJob).firstOrNull;
    final feedback = worker == null ? null : feedbackFor(worker);
    final text = worker != null && feedback != null
        ? '${worker.name}: ${feedback.state}'
        : lumberReady && _woodHarvested == 0
        ? 'Oduncu ilk ağaca gidiyor…'
        : 'Kuruluş ekibi sıradaki işi hazırlıyor…';
    final eta = feedback?.etaLabel ?? '';
    return AppPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const GameIcon(GameIconData.hammer, size: 14, color: AppUi.accent),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  eta.isEmpty ? text : '$text · $eta',
                  style: AppUi.body.copyWith(color: AppUi.textMid),
                  overflow: TextOverflow.ellipsis,
                ),
                if (feedback?.result.isNotEmpty == true)
                  Text(
                    feedback!.result,
                    style: AppUi.body.copyWith(
                      fontSize: 10.5,
                      color: AppUi.textLo,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
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
    // BİNASIZ İŞ YERİ — tarla, böğürtlenlik, şantiye. Bunlar da tıklanır
    // olduğu için buradan da okunmalı: "Detay" kapısı olmasaydı seçilen
    // böğürtlenliğin kadro kartı hiçbir yerden açılamazdı.
    final siteId = _selectedSiteId;
    if (siteId != null) {
      final site = _siteById(siteId);
      if (site != null) {
        return CommandContext(
          title: site.label,
          subtitle: _siteSubtitle(site),
          stats: [
            (
              'Kadro',
              site.wanted == 0
                  ? '${site.crew.length} el'
                  : '${site.crew.length}/${site.wanted}',
              site.starving ? AppUi.rust : AppUi.sage,
            ),
          ],
          actions: [
            CommandAction(
              'Detay',
              GameIconData.scroll,
              onTap: () => setStateHere(() => _detailExpanded = true),
            ),
          ],
        );
      }
    }
    return null;
  }

  /// Görev takipçisi — sağ üst. Eski sürekli-açık ObjectivePanel'in yerini alır;
  /// yalnız aktif görev + kademe ilerlemesi, tam liste Defter'de.
  Widget buildVillageNamePrompt() {
    final compact = useCompactGameUi(context);
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0x66000000),
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: compact ? 520 : 470,
                maxHeight: compact ? 340 : 380,
              ),
              child: MobileSurface(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'ŞİMDİ BU YERE BİR AD VER',
                      style: AppUi.title.copyWith(
                        fontSize: 14,
                        letterSpacing: 1.2,
                        color: AppUi.accent,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'İlk çadır kuruldu; artık burası senin köyün.',
                      style: AppUi.body.copyWith(color: AppUi.textMid),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _villageNamePromptCtrl,
                      textCapitalization: TextCapitalization.words,
                      style: AppUi.bodyHi,
                      decoration: const InputDecoration(
                        labelText: 'Köy adı',
                        hintText: 'Örn. Pınarbaşı',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _houseNamePromptCtrl,
                      textCapitalization: TextCapitalization.words,
                      style: AppUi.bodyHi,
                      decoration: const InputDecoration(
                        labelText: 'Kurucu hanesi (isteğe bağlı)',
                        hintText: 'Örn. Kaya',
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppButton(
                      label: 'Adı mühürle',
                      icon: GameIconData.star,
                      expand: true,
                      onTap: () => _onVillageNamed(
                        _villageNamePromptCtrl.text,
                        _houseNamePromptCtrl.text,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

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
            // Kart kuruluşta AÇIK gelir (oyuncunun "nasıl"ı okuması gereken tek
            // yer burası); köy kurulunca ince banda döner. Oyuncu elle
            // dokunduysa karar onun, otomatiğe geri dönmez.
            // KAPSAM `_guideActive` DEĞİL KURULUŞ. Öğretici dörde inince bu
            // satır bir süre `_guideActive`e bakıyordu ve kart beşinci adımda
            // aniden ince banda düşüyordu: parmak kalktığı yerde "nasıl"ı
            // anlatan tek yüzey de kapanıyor, oyuncu tam serbest kaldığı anda
            // yalnız kalıyordu. Spot dört adım, kart bütün kuruluş boyunca.
            // Yerleştirme modu açıkken yeşil sahne komutu zaten sıradaki
            // hareketi söylüyor. Görev kartı başlığa kapanır; oyuncu isterse
            // elle yeniden açabilir. Şantiye konunca mod biter ve kart bu kez
            // "Beklemeyi geç" eylemiyle kendiliğinden geri açılır.
            final placingActive = _placing == active.quest.buildTarget;
            final expanded =
                _questCardOverride ?? (_charterTier == 0 && !placingActive);
            final waitOrder = _foundingWaitOrder;
            return QuestTracker(
              icon: questGlyph(active.quest.id),
              activeLabel: active.quest.label,
              tierName: tier.name,
              done: _completedQuests.length,
              total: QuestBook.all.length,
              onOpen: () => _openLedger(LedgerSection.tuzuk),
              hint: active.quest.hint,
              speakerName: active.speakerName,
              expanded: expanded,
              onToggleExpand: () =>
                  setStateHere(() => _questCardOverride = !expanded),
              // Yer seçildiyse oyuncu öğreticinin istediği eylemi yaptı:
              // aynı yeri tekrar göstermek yerine inşaat bekleyişini geçir.
              // Bekleyen şantiye yokken "Göster" kuruluş boyunca kullanılır.
              onShow: _charterTier == 0 && waitOrder == null
                  ? () => setStateHere(_guideShow)
                  : null,
              onSkipWait: waitOrder == null ? null : _skipFoundingBuildWait,
            );
          },
        ),
      ),
    );
  }

  /// KIŞ TABLOSU BU BİNADA GÖRÜNÜR MÜ — tezgâh nerede duruyorsa orada
  /// (ambar; ambar yoksa ocak başı, bkz. `_loomSpot`), yalnız sonbahar/kışta.
  ///
  /// Kış göstergesi eskiden HUD'ın sağ üstünde sürekli duran bir karttı;
  /// mevsim boyunca ekranda bekleyen bir tehdit, oyunu olduğundan sert
  /// gösteriyordu. Artık kışı köy söyler (bkz. scene_winter) ve sayıyı merak
  /// eden tezgâhın başına gelir — bakmak isteyenin işi, mecburiyet değil.
  WinterReadiness? _winterPanelFor(BuildingEntity b) {
    if (_season != Season.autumn && _season != Season.winter) return null;
    if (_loomSpot != b) return null;
    return _winterReadiness;
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
    final hinted = !sel && target != null && kBuildingCategory[target] == cat;
    return GuideTarget(
      id: GuideAnchors.buildTab(cat.name),
      child: GestureDetector(
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
  void _onSelectBuilding(BuildingType type) {
    final meta = kBuildingMeta[type];
    if (meta != null && !_godMode && !_stockpile.canAfford(meta.cost)) {
      _showNotification(
        '🚫 ${meta.label} için eksik: ${_stockpile.formatMissing(meta.cost)}',
      );
      return;
    }
    setStateHere(() {
      _farmMode = false;
      _farmStart = null;
      _farmEnd = null;
      _farmTapAnchor = null;
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
        // Yeni bir künye açılıyor → tatlı not havuzdan bir sonrakine geçsin.
        _loreNoteSeed++;
      }
      // Künyenin canlı alanları hayalet yokken boş: ipuçları nötr okunur.
      _placeReason = null;
      _placeFacts = null;
    });
  }

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
            _mobileBuildCatalogOpen = false;
            _placing = null;
            _ghost = null;
            _farmMode = false;
            _farmStart = null;
            _farmEnd = null;
            _farmTapAnchor = null;
            _lumberMode = false;
            _mineMode = false;
            _roadErase = false;
            _placingRoad = _placingRoad == s ? null : s;
            _clearRoadDrag();
          }),
          eraseSelected: _roadErase,
          onSelectErase: () => setStateHere(() {
            _mobileBuildCatalogOpen = false;
            _placing = null;
            _ghost = null;
            _farmMode = false;
            _farmStart = null;
            _farmEnd = null;
            _farmTapAnchor = null;
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
            _mobileBuildCatalogOpen = false;
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
            _farmTapAnchor = null;
          }),
        ),
        const SizedBox(width: 4),
        ModeButton(
          icon: '🪓',
          label: 'Kes',
          active: _lumberMode,
          accentColor: const Color(0xFFCC6600),
          onTap: () => setStateHere(() {
            _mobileBuildCatalogOpen = false;
            _placing = null;
            _ghost = null;
            _placingRoad = null;
            _roadErase = false;
            _clearRoadDrag();
            _farmMode = false;
            _farmStart = null;
            _farmEnd = null;
            _farmTapAnchor = null;
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
            _mobileBuildCatalogOpen = false;
            _placing = null;
            _ghost = null;
            _placingRoad = null;
            _roadErase = false;
            _clearRoadDrag();
            _farmMode = false;
            _farmStart = null;
            _farmEnd = null;
            _farmTapAnchor = null;
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

  /// İNŞA KÜNYESİ — elinde bir bina varken açılan bilgi kartı: ne işe yarar,
  /// NEREYE kurulmalı (hayaletin durduğu yere göre canlı ✓/○), tatlı bir not ve
  /// —geçersizse— neden kurulamadığı.
  ///
  /// Eski "🚫 sebep" çubuğunun yerini alır: o çubuk yalnız KURALLARI, yalnız
  /// hata anında söylüyordu; avantajları (çadır–ocak, oduncu–orman, balıkçı–göl)
  /// oyuncu hiç öğrenemiyordu. Kart hep açıktır, kırmızı satır onun bir parçası.
  ///
  /// Ekranı yutmasın diye SOL ALTTA, inşa çubuğunun üstünde durur ve tıklamayı
  /// geçirir — oyuncu okurken yerini de seçebilir.
  Widget buildBuildBrief() {
    final compact = useCompactGameUi(context);
    return Positioned(
      left: compact ? MobileUi.gutter : 14,
      bottom: compact
          ? MobileUi.bottom(context) + MobileUi.actionH + MobileUi.gap * 2
          : 132,
      child: IgnorePointer(
        child: RepaintBoundary(
          child: ListenableBuilder(
            listenable: _frame,
            builder: (_, _) {
              final type = _placing;
              if (type == null) return const SizedBox.shrink();
              return BuildingBrief(
                type: type,
                facts: _placeFacts,
                reason: _placeReason,
                noteSeed: _loreNoteSeed,
              );
            },
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
            bottom: useCompactGameUi(context) ? MobileUi.bottom(context) : 96,
            child: _detailFrame(
              compact: useCompactGameUi(context),
              child: BuildingInfoPanel(
                building: selected,
                residents: _villagers
                    .where((v) => v.homeBuilding == selected)
                    .toList(),
                // KADRO — bu binanın doğurduğu işler. Ev/kuyu/pazar için boş
                // liste döner ve bölüm hiç çizilmez.
                workSites: _sitesOfBuilding(selected),
                onAddHand: (site) => setStateHere(() => _fillSlot(site)),
                onRemoveHand: (_, v) => setStateHere(() => _emptySlot(v)),
                onSelectVillager: (v) => setStateHere(() {
                  _selectedVillager = v;
                  _selectedBuilding = null;
                  _selectedSiteId = null;
                }),
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
                // Çadırın ocaktan aldığı sıcaklık — panelde görünen sayı,
                // moralin ve üşüme dürtüsünün okuduğu sayının ta kendisi.
                hearthWarmth: selected.type == BuildingType.tent
                    ? _shelterWarmthOf(selected)
                    : null,
                winter: _season == Season.winter,
                // KIŞ — yalnız tezgâhın durduğu binada, yalnız sonbahar/kışta.
                winterReadiness: _winterPanelFor(selected),
                coatPriority: _coatPriority,
                undistributedCoats: _coatsMade,
                onCoatPriority: (p) => setStateHere(() {
                  _coatPriority = p;
                  // Karar ANINDA görünsün: elde bekleyen giysi varsa yeni
                  // önceliğe göre dağıtılır, oyuncu bir sonraki taramayı
                  // beklemesin.
                  _distributeCoats();
                }),
                onClose: () => setStateHere(() => _detailExpanded = false),
                onSell: (kind) => setStateHere(() {
                  if (sellAtMarket(_stockpile, kind)) {
                    // Satış oldu → seçili market binasına son satış zamanı
                    // mühürlenir; _BuildingDrawable 1sn altın parıltısı çizer.
                    _selectedBuilding?.lastSaleTime = _time;
                  }
                }),
                onFestival: () => _hostFestival(selected),
                onTogglePaused:
                    selected.fn?.role == BuildingRole.gathering ||
                        selected.fn?.role == BuildingRole.processing
                    ? () => _toggleBuildingPaused(selected)
                    : null,
                repairCost: _repairCostFor(selected),
                repairAffordable: _stockpile.canAfford(
                  _repairCostFor(selected),
                ),
                repairBlockedByFire: _burningBuildings.contains(selected),
                onRepair: selected.damage > 0.02
                    ? () => setStateHere(() => _repairBuilding(selected))
                    : null,
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

  /// Hasar büyüdükçe malzeme de büyür; en hafif vandalizm bile bir tahta,
  /// ağır yangınsa çatı ve cepheyi ister. Bu tek maliyet fonksiyonu hem panel
  /// önizlemesinin hem gerçek harcamanın doğruluğudur.
  ResourceCost _repairCostFor(BuildingEntity b) {
    final severity = b.damage.clamp(0.0, 1.0);
    return ResourceCost(
      wood: 2 + (severity * 10).ceil(),
      stone: b.fn?.role == BuildingRole.housing && severity >= 0.55 ? 2 : 0,
    );
  }

  void _repairBuilding(BuildingEntity b) {
    if (_burningBuildings.contains(b)) {
      _showNotification('🔥 Önce alevler dinsin.');
      return;
    }
    final cost = _repairCostFor(b);
    if (!_stockpile.canAfford(cost)) {
      _showNotification(
        '🪵 Tamir için eksik: ${_stockpile.formatMissing(cost)}',
      );
      return;
    }
    _stockpile.spend(cost);
    b.damage = 0;
    b.spawnTime = _time; // onarım biterken küçük toz/yerleşme geri bildirimi.
    _showNotification('🔨 ${kBuildingMeta[b.type]!.label} onarıldı.');
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

  /// Üretim binasını gerçekten aç/kapat. Bayrak yalnız panel metni değildir:
  /// iş yeri talebi, atanmış işçinin tick'i ve pasif üretim döngüleri aynı
  /// [BuildingEntity.userPaused] değerini okur.
  void _toggleBuildingPaused(BuildingEntity building) {
    setStateHere(() {
      building.userPaused = !building.userPaused;
      if (building.userPaused) building.isActive = false;
      // Otomatik kadro iki saniyelik normal taramayı beklemeden yeni talebi
      // görsün. Elle mühürlenmiş el yerini korur, bina açılınca geri döner.
      _jobSyncCd = 0;
    });
    final label = kBuildingMeta[building.type]?.label ?? 'Yapı';
    _showNotification(
      building.userPaused
          ? '$label durduruldu — üretim ve işçi talebi kesildi.'
          : '$label yeniden çalışmaya açıldı.',
    );
  }

  // ── Köylü bilgi paneli — bina paneliyle aynı pozisyon ─────────────────────

  Widget buildSelectedVillagerPanel() {
    final v = _selectedVillager!;
    // Sağ-dock: bina paneliyle tutarlı, hep sağ kenarda. Detay açıkken dünya
    // kroması zaten susturulur; hafif tap-out perde de sahneyi ikinci bir bilgi
    // katmanı gibi bağırmaktan çıkarır.
    //
    // MOBİL: yuva ızgaradan gelir (üst gutter → alt gutter) ve panel onu
    // DOLDURUR; kaydırma panelin İÇİNDE olur. Dıştaki SingleChildScrollView
    // telefonda yanlıştı — paneli sınırsız yükseklikte bırakıp altını
    // kırptırıyordu ("yarısı kesik kutu" görüntüsü).
    final compact = useCompactGameUi(context);
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setStateHere(() => _detailExpanded = false),
              child: Container(color: const Color(0x2D000000)),
            ),
          ),
          Positioned(
            top: compact ? MobileUi.top(context) : 64,
            right: compact ? MobileUi.right(context) : 14,
            bottom: compact ? MobileUi.bottom(context) : 96,
            child: _detailFrame(
              compact: compact,
              child: VillagerInfoPanel(
                villager: v,
                homeLabel: v.homeBuilding == null
                    ? null
                    : kBuildingMeta[(v.homeBuilding as BuildingEntity).type]
                          ?.label,
                isFollowed: _followedVillager == v,
                onClose: () => setStateHere(() => _detailExpanded = false),
                onSelect: (next) =>
                    setStateHere(() => _selectedVillager = next),
                onToggleFollow: () => _toggleFollowVillager(v),
                onToggleFavorite: () =>
                    setStateHere(() => v.isFavorite = !v.isFavorite),
                onRename: (newName) {
                  final cleaned = newName.trim();
                  if (cleaned.isEmpty || cleaned.length > 20) return;
                  setStateHere(() => v.name = cleaned);
                },
                // İŞİN OKUNUŞU — panel iş VERMEZ, iş OKUR. Karar iş yerinin
                // kendi kartında verilir; buradaki tek kapı oraya götürür.
                workplaceLabel: _siteOfVillager(v)?.label,
                onOpenWorkplace: v.hasActiveJob
                    ? () => setStateHere(() => _openWorkplaceOf(v))
                    : null,
                onReleaseJob: v.hasActiveJob
                    ? () => setStateHere(() => _emptySlot(v))
                    : null,
                // Kan davası yargısı — geri alınamaz, oyuncu onaylar.
                onExile: () =>
                    setStateHere(() => _pendingJudgment = (v, false)),
                onExecute: () =>
                    setStateHere(() => _pendingJudgment = (v, true)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Binasız iş yeri paneli — tarla / böğürtlenlik / şantiye ───────────────

  /// Yapısı olmayan iş yerinin kartı. Bina paneliyle AYNI yuvada açılır:
  /// oyuncu için ikisi de "bir yere baktım, kadrosunu gördüm"dür.
  Widget buildSelectedWorkSitePanel() {
    final site = _siteById(_selectedSiteId!);
    // İş yeri buharlaştıysa (sipariş tamamlandı, son çalı toplandı) panel de
    // gitsin — ölü bir şantiyenin kadrosunu göstermek yalan olurdu.
    if (site == null) return const SizedBox.shrink();
    final compact = useCompactGameUi(context);
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setStateHere(() => _detailExpanded = false),
              child: Container(color: const Color(0x2D000000)),
            ),
          ),
          Positioned(
            top: compact ? MobileUi.top(context) : 64,
            right: compact ? MobileUi.right(context) : 14,
            bottom: compact ? MobileUi.bottom(context) : 96,
            child: _detailFrame(
              compact: compact,
              child: WorkSitePanel(
                site: site,
                subtitle: _siteSubtitle(site),
                onClose: () => setStateHere(() => _detailExpanded = false),
                onAddHand: (s) => setStateHere(() => _fillSlot(s)),
                onRemoveHand: (_, v) => setStateHere(() => _emptySlot(v)),
                onSelectVillager: (v) => setStateHere(() {
                  _selectedVillager = v;
                  _selectedSiteId = null;
                  _selectedBuilding = null;
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// İş yerinin bir cümlelik hâli — kadro sayısının söylemediği şey.
  String? _siteSubtitle(WorkSite site) => switch (site.kind) {
    WorkSiteKind.field => () {
      final ready = _farmTiles.where((t) => t.stage >= 4).length;
      return '${_farmTiles.length} parsel'
          '${ready > 0 ? ' · $ready tanesi hasat vaktinde' : ''}';
    }(),
    WorkSiteKind.patch => () {
      final ripe = _berryBushes.where((b) => b.harvestable).length;
      return '${_berryBushes.length} çalı · $ripe tanesi olgun';
    }(),
    WorkSiteKind.construction => () {
      final source = site.source;
      if (source is! BuildOrder) {
        return '${_roadOrders.where((o) => !o.completed).length} karo bekliyor';
      }
      final here = source.workersAtSite;
      if (source.progress > 0) {
        return '$here/${source.requiredWorkers} usta çalışıyor · '
            '%${(source.progress * 100).round()} tamam';
      }
      if (here == 0) {
        return '${source.crew}/${source.requiredWorkers} usta yolda · şantiye bekliyor';
      }
      if (!source.crewReady) {
        return '$here/${source.requiredWorkers} usta şantiyede · ekip bekleniyor';
      }
      return '$here/${source.requiredWorkers} usta işe başlıyor';
    }(),
    WorkSiteKind.building => null,
  };

  /// Bu köylünün çalıştığı yeri aç — kamerayı oraya taşı, kartını göster.
  /// Köylü panelindeki "İşyerine git" buradan geçer: kararın verildiği yer
  /// iş yerinin kartıdır, oyuncu oraya bir dokunuşla ulaşmalı.
  void _openWorkplaceOf(VillagerEntity v) {
    final site = _siteOfVillager(v);
    if (site == null) return;
    _focusWorkSite(site);
  }

  /// Kamerayı iş yerine götür + kartını aç.
  void _focusWorkSite(WorkSite site) {
    // Görünüm ölçüsü sahnenin kendi kaydından okunur (`context.size` panelin
    // ölçüsünü verir, kameranınkini değil — kamera oraya değil ekranın
    // ortasına oturmalı).
    final size = _viewSize;
    if (size.width > 0 && size.height > 0) {
      final readable = size.shortestSide < 500 ? 1.18 : 1.12;
      if (_zoom < readable) _zoom = readable;
      _centerCameraOnUV(site.cx - site.cy, site.cx + site.cy, size);
      _clampCamera(size);
    }
    _followedVillager = null;
    _selectedVillager = null;
    final src = site.source;
    if (src is BuildingEntity) {
      _selectedBuilding = src;
      _selectedSiteId = null;
    } else {
      _selectedSiteId = site.id;
      _selectedBuilding = null;
    }
    _detailExpanded = true;
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
