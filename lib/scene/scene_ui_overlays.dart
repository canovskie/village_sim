part of '../main.dart';

/// SAHNE ARAYÜZÜ — bildirim, dev günlüğü, imparatorluk uyarısı, ipucu şeridi.
///
/// scene_ui.dart 2245 satırdı; tek uzantı üç parçaya bölündü. Uzantı adı
/// farklı ama hedef aynı ([_VillageSceneState]) — çağıranlar için hiçbir
/// şey değişmez, metotlar aynen taşındı.
extension _SceneUiOverlays on _VillageSceneState {
  String get _foundingTesterPhase {
    if (_foundingCouncilPending) return '1 · Kurucular halka oluyor';
    if (identical(_activeCutscene, kOpeningCutscene)) {
      return '2 · Kuruluş meclisi ve seçimler';
    }
    if (!_hasFire) return '3 · Ocağın yeri bekleniyor';
    if (!_completedQuests.contains('firstNight')) {
      if (_foundingBedTargets.isNotEmpty) {
        return '4 · Saz yataklar doğal olarak seriliyor';
      }
      return '4 · İlk gece ve uyku düzeni';
    }
    if (!_completedQuests.contains('tent')) {
      return '5 · Kuruculara çadır kuruluyor';
    }
    if (!_completedQuests.contains('lumber')) {
      return '6 · İlk odun zinciri kuruluyor';
    }
    return '✓ Doğal kuruluş tamamlandı';
  }

  Widget buildFoundingTesterOverlay() => ListenableBuilder(
    listenable: _hudFrame,
    builder: (_, _) {
      final restart = widget.onRestartRun;
      final current = _stepCache?.quest;
      final homeless = _villagers.where((v) => v.homeBuilding == null).length;
      final progress = <(String, bool)>[
        ('Halka', _foundingChoiceMade),
        ('Ocak', _hasFire),
        ('Gece', _completedQuests.contains('firstNight')),
        ('Çadır', _completedQuests.contains('tent')),
        ('Odun', _completedQuests.contains('lumber')),
      ];

      Future<void> restartFresh() async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: AppUi.surface1,
            title: const Text('Taze doğal koşu', style: AppUi.title),
            content: const Text(
              'Bu tester oturumu kapanıp yeni rastgele dünyada kuruluş en '
              'baştan başlayacak.',
              style: AppUi.body,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('VAZGEÇ'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('BAŞTAN BAŞLAT'),
              ),
            ],
          ),
        );
        if (confirmed == true) restart?.call();
      }

      final compact = useCompactGameUi(context);
      return Positioned.fill(
        child: SafeArea(
          minimum: EdgeInsets.only(
            left: compact ? 8 : 12,
            top: compact ? 8 : 12,
          ),
          child: Align(
            alignment: Alignment.topLeft,
            child: _foundingTesterPanelOpen
                ? Material(
                    color: Colors.transparent,
                    child: Container(
                      width: compact ? 250 : 280,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xE614181D),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppUi.accent.withValues(alpha: 0.72),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x66000000),
                            blurRadius: 16,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'DOĞAL KURULUŞ TESTER',
                                  style: AppUi.label.copyWith(
                                    color: AppUi.accentSoft,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Gözlem panelini gizle',
                                visualDensity: VisualDensity.compact,
                                onPressed: () => setStateHere(
                                  () => _foundingTesterPanelOpen = false,
                                ),
                                icon: const Icon(
                                  Icons.visibility_off_outlined,
                                  size: 18,
                                  color: AppUi.textMid,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            _foundingTesterPhase,
                            style: AppUi.body.copyWith(
                              color: AppUi.textHi,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Wrap(
                            spacing: 5,
                            runSpacing: 5,
                            children: [
                              for (final (label, done) in progress)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: done
                                        ? AppUi.sage.withValues(alpha: 0.20)
                                        : AppUi.surface0,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: done ? AppUi.sage : AppUi.line,
                                    ),
                                  ),
                                  child: Text(
                                    '${done ? '✓' : '○'} $label',
                                    style: AppUi.label.copyWith(
                                      color: done ? AppUi.sage : AppUi.textLo,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Aktif adım: ${current?.label ?? 'hazırlanıyor'}\n'
                            'Nüfus ${_villagers.length} · evsiz $homeless · '
                            'yatak ${_reedBeds.length} + ${_foundingBedTargets.length} serimde\n'
                            'Yapı ${_buildings.length} · şantiye '
                            '${_orders.where((o) => !o.completed).length}\n'
                            'Erzak ${_stockpile.food} · odun ${_stockpile.wood} · '
                            'gün $_dayCount · hız ${_timeScale.toStringAsFixed(0)}×',
                            style: AppUi.body.copyWith(
                              color: AppUi.textMid,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            'Sabit tohum yok · otomasyon yok · ekonomi/AI doğal',
                            style: AppUi.label.copyWith(color: AppUi.sage),
                          ),
                          if (restart != null) ...[
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: restartFresh,
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('TAZE KOŞU'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                : Material(
                    color: Colors.transparent,
                    child: IconButton.filled(
                      tooltip: 'Gözlem panelini aç',
                      onPressed: () =>
                          setStateHere(() => _foundingTesterPanelOpen = true),
                      icon: const Icon(Icons.visibility_outlined),
                    ),
                  ),
          ),
        ),
      );
    },
  );

  /// Oyuncu kamerayı ilk kez gerçekten hareket ettirene dek kalan, kayıt başına
  /// tek seferlik kontrol notu. Modlar kendi canlı şeritlerine sahip olduğu için
  /// yalnız boş elde görünür.
  Widget buildCameraGuide() => ListenableBuilder(
    listenable: _frame,
    builder: (_, _) {
      if (_cameraGuideSeen ||
          _activeCutscene != null ||
          _mobileBuildCatalogOpen ||
          _villageNamePromptOpen ||
          _placing != null ||
          _farmMode ||
          _lumberMode ||
          _mineMode ||
          _roadMode ||
          _ledgerSection != null ||
          _petitionModalOpen ||
          _choiceModalOpen ||
          _imperialDemand != null) {
        return const SizedBox.shrink();
      }
      final compact = useCompactGameUi(context);
      return Positioned(
        left: 0,
        right: 0,
        bottom: compact
            ? MobileUi.bottom(context) + MobileUi.actionH + MobileUi.gap
            : 82,
        child: IgnorePointer(
          child: Center(
            child: AppReveal(
              child: AppChip(
                label: cameraInteractionGuide(mobile: PlatformAdapt.isMobile),
                color: AppUi.accentSoft,
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget buildImperialClashOverlay() => ListenableBuilder(
    listenable: _frame,
    builder: (_, _) {
      final raiding = _imperialPhase == ImperialVisitPhase.raiding;
      final beat = imperialBattleBeat(_imperialClashTimer);
      final line = raiding
          ? (_impStruck
                ? '${(_imperialRaidScenario?.target.label ?? 'MEYDAN').toUpperCase()} VURULDU · KOLON ÇEKİLİYOR'
                : 'HAT KIRILDI · ${(_imperialRaidScenario?.target.label ?? 'MEYDAN').toUpperCase()} HEDEFTE')
          : switch (beat) {
              ImperialBattleBeat.mustering =>
                '${_imperialDefensePlan.title.toUpperCase()} · SAFLAR KURULUYOR',
              ImperialBattleBeat.firstImpact => 'İLK DARBE · MIZRAKLAR İNDİ',
              ImperialBattleBeat.counterstrike => 'KÖY KARŞILIK VERİYOR',
              ImperialBattleBeat.finalPush =>
                _imperialBattleWon
                    ? 'SON İTİŞ · HEYET GERİLİYOR'
                    : 'SON İTİŞ · HAT ÇÖZÜLÜYOR',
              ImperialBattleBeat.result =>
                _imperialBattleWon ? 'EŞİK TUTULDU' : 'EŞİK DÜŞTÜ',
            };
      final progress = raiding ? 1.0 : _imperialBattleProgress;
      return Positioned(
        top: useCompactGameUi(context) ? 54 : 126,
        left: 0,
        right: 0,
        child: IgnorePointer(
          child: Center(
            child: AppReveal(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xE6121820),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppUi.accent.withValues(alpha: 0.7),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 14,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/combat/combat_badge.png',
                          width: 30,
                          height: 30,
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (_imperialRaidScenario?.title ??
                                      'Eşik Muharebesi')
                                  .toUpperCase(),
                              style: AppUi.label.copyWith(
                                color: AppUi.rust,
                                fontSize: 8,
                              ),
                            ),
                            Text(
                              line,
                              style: AppUi.label.copyWith(
                                color: AppUi.accent,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 230,
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 3,
                        backgroundColor: AppUi.surface0,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          raiding || (!_imperialBattleWon && progress > 0.62)
                              ? AppUi.rust
                              : AppUi.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget buildNotificationToast() {
    // Sabit `top: 70` masaüstü varsayımıydı. iPhone 11'de (414dp yükseklik) o
    // hat tam olarak Köy Defteri'nin SEKME şeridine denk geliyor ve bildirim
    // TÜZÜK sekmesinin üstüne oturuyordu — geçici bir bildirim, kalıcı bir
    // gezinme öğesini örtmemeli. Telefonda toast alta iner (komuta çubuğunun
    // üstüne): orada yalnız içeriğin üstünden geçer, hiçbir kontrolü kapatmaz.
    final compact = useCompactGameUi(context);
    final toast = Center(
      child: AppReveal(
        child: AppChip(label: _notification!, color: AppUi.accent, solid: true),
      ),
    );
    if (!compact) {
      return Positioned(top: 70, left: 0, right: 0, child: toast);
    }
    return Positioned(
      left: 0,
      right: 0,
      bottom: MobileUi.bottom(context) + MobileUi.actionH + MobileUi.gap,
      // Katalog açıldığında bu hat araç kartlarının üstünden geçebilir.
      // Bildirim yalnız bilgi taşır; görünürken alttaki Tarla/Yol düğmesini
      // kilitlememeli. Dokunuşu palete geçir.
      child: IgnorePointer(child: toast),
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
                      if (_imperialAlertRaid.isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Text(
                          _imperialAlertRaid,
                          textAlign: TextAlign.center,
                          style: AppUi.label.copyWith(
                            color: bone.withValues(alpha: .92),
                            fontSize: 13,
                            letterSpacing: 2.2,
                          ),
                        ),
                      ],
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
                ? useTouchUi(context)
                      ? (_farmTapAnchor == null
                            ? 'Tarla — iki köşeye dokun veya sürükle'
                            : 'Tarla — ikinci köşeye dokun (ya da sürükle)')
                      : 'Tarla — sürükle seç, bırak onayla'
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
    if (useTouchUi(context) && _roadTapAnchor != null) {
      return _roadErase
          ? 'Başlangıç seçildi — yolun diğer ucuna dokun'
          : '${_placingRoad!.label} — bitiş noktasına dokun (ya da sürükle)';
    }
    if (_roadPreview.isEmpty) {
      return _roadErase
          ? useTouchUi(context)
                ? 'Yol Silgisi — iki uca dokun veya sürükle'
                : 'Yol Silgisi — sürükle, bırak kaldır'
          : useTouchUi(context)
          ? '${_placingRoad!.label} — iki uca dokun veya sürükle'
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
