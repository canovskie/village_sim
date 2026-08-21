part of '../main.dart';

/// DIŞ DÜNYA TRAFİĞİ — kervan, yolcu ve yabancılar haritanın bir kenarından
/// girer, köyde amaçlarına göre oyalanır ve karşı kenardan yoluna devam eder.
/// Sakin değillerdir; nüfusa/eve/dilekçeye karışmaz ve kayda yazılmazlar.
extension _SceneMerchant on _VillageSceneState {
  /// Ziyaretler arası temel boşluk. Yol ve han bu aralığı aşağı çeker.
  static const double _kGapMin = 1.0 * kGameDaySeconds;
  static const double _kGapMax = 2.25 * kGameDaySeconds;

  static const double _kFirstTradeDelay = 5.0;

  /// İki alım arası (sn) — ziyaret boyunca birkaç kez el değiştirir.
  static const double _kTradeInterval = 16.0;

  /// Sahne ana döngüsünden her tick. Spawn zamanlayıcısı + bütün ziyaretçilerin
  /// evreleri. Aynı anda tek yolculuk grubu vardır; grup kendi içinde kalabalık.
  void _tickMerchants(double dt) {
    if (kCaptureVisitors && !kCaptureVisitorsSpawned) _prepareVisitorCapture();
    if (kCaptureVisitors && !kCaptureVisitorsFocused) _focusVisitorCapture();
    if (kCaptureVisitors) _writeVisitorCaptureReport();
    if (_merchants.isEmpty) {
      _merchantTimer -= dt;
      if (_merchantTimer <= 0) {
        // Kervan/yolcu gündüz ve alacakaranlıkta görünsün; tam gecede kısa süre
        // bekletilir. Gece yolda kalanlar meşale yakarak ziyaretini sürdürebilir.
        if (_cycle.dayLight > 0.30) {
          _spawnMerchant();
        } else {
          _merchantTimer = 14.0;
        }
      }
    }

    if (_merchants.isEmpty) return;
    final npcDt = dt * _fxNpcSpeedMul;
    for (final m in _merchants) {
      m.step(
        npcDt,
        _rng,
        waterTiles: _obstacles,
        softObstacles: _softObs,
        dayLight: _cycle.dayLight,
        rainIntensity: _cycle.rainIntensity,
      );
      // Yalnız kervanın insan lideri pazarlık yapar. Araba ve yükçüler aynı
      // tick'te ticaret sayacını üç kez eksiltmez.
      if (m.canTrade && m.phase == MerchantPhase.browsing) {
        _merchantTradeCd -= dt;
        if (_merchantTradeCd <= 0) {
          _merchantTradeCd = _kTradeInterval;
          _merchantTrade();
        }
      }
    }
    if (_merchants.any((m) => m.finished)) {
      _merchants.removeWhere((m) => m.finished);
      if (_merchants.isEmpty) _merchantTimer = _nextVisitorGap();
    }
  }

  /// Asset'ler yüklenir yüklenmez çalışan görsel prova hazırlığı. Ticker'ın ilk
  /// karesini beklemez; arka plandaki macOS capture penceresinde de güvenilir.
  void _prepareVisitorCapture() {
    if (kCaptureVisitorsSpawned) return;
    kCaptureVisitorsSpawned = true;
    _spawnMerchant(VisitorKind.caravan);
    for (final m in _merchants) {
      m.gridX = m.browseX;
      m.gridY = m.browseY;
      m.renderX = m.browseX;
      m.renderY = m.browseY;
      m.step(
        0.01,
        _rng,
        dayLight: _cycle.dayLight,
        rainIntensity: _cycle.rainIntensity,
      );
    }
    _focusVisitorCapture();
  }

  void _focusVisitorCapture() {
    if (_viewSize.isEmpty) {
      kCaptureVisitorReport = 'odak bekliyor: view=$_viewSize';
      return;
    }
    MerchantEntity? cart;
    for (final m in _merchants) {
      if (m.hasCart) {
        cart = m;
        break;
      }
    }
    if (cart != null) {
      _zoom = 1.35;
      _cameraCentered = true;
      _centerCameraOnUV(
        cart.gridX - cart.gridY,
        cart.gridX + cart.gridY,
        _viewSize,
      );
      kCaptureVisitorsFocused = true;
      _writeVisitorCaptureReport();
    }
  }

  void _writeVisitorCaptureReport() {
    MerchantEntity? cart;
    for (final m in _merchants) {
      if (m.hasCart) cart = m;
    }
    final market = _firstBuildingOf(BuildingType.market);
    kCaptureVisitorReport =
        'view=$_viewSize zoom=$_zoom camera=$_camera '
        'uv=${_viewSize.isEmpty ? '-' : _cameraUV(_viewSize)} '
        'cart=${cart == null ? '-' : '(${cart.gridX},${cart.gridY})'} '
        'market=${market == null ? '-' : '(${market.col},${market.row})'} '
        'bina=${_buildings.length}';
  }

  double _nextVisitorGap() {
    var gap = _kGapMin + _rng.nextDouble() * (_kGapMax - _kGapMin);
    // Yol ağı dış dünyayı köye bağlar; han geceleme kapasitesi verir. İkisi de
    // ziyaret üretir ama sıfıra indirmez — dünya lunapark kuyruğuna dönüşmesin.
    if (_roadSystem.count >= 8) gap *= 0.82;
    gap = merchantVisitGap(
      gap,
      hasCaravanserai: _firstBuildingOf(BuildingType.caravanserai) != null,
    );
    return gap.clamp(0.65 * kGameDaySeconds, _kGapMax);
  }

  /// Geriye dönük isim korunuyor: artık tek tüccar değil, seçilen profile göre
  /// bütün bir dış dünya grubu doğurur.
  void _spawnMerchant([VisitorKind? forcedKind]) {
    if (_merchants.isNotEmpty) return;

    final hasRoad = _roadSystem.count >= 8;
    final hasHan = _firstBuildingOf(BuildingType.caravanserai) != null;
    final caravanChance = 0.34 + (hasRoad ? 0.14 : 0.0) + (hasHan ? 0.14 : 0.0);
    final roll = _rng.nextDouble();
    final kind =
        forcedKind ??
        (roll < caravanChance
            ? VisitorKind.caravan
            : roll < caravanChance + 0.34
            ? VisitorKind.traveler
            : VisitorKind.stranger);

    final (rawSx, rawSy, rawEx, rawEy) = _visitorRoute();
    final (sx, sy) = _nearestLand(rawSx, rawSy);
    final (ex, ey) = _nearestLand(rawEx, rawEy);
    final (bx, by) = _visitorStop(kind);
    final groupId = (_dayCount << 11) ^ _rng.nextInt(1 << 11);

    final baseVisit = switch (kind) {
      VisitorKind.caravan => 0.56 * kGameDaySeconds,
      VisitorKind.traveler => 0.34 * kGameDaySeconds,
      VisitorKind.stranger => 0.22 * kGameDaySeconds,
    };
    final visitDuration = merchantVisitDuration(
      baseVisit,
      hasCaravanserai: kind == VisitorKind.caravan && hasHan,
    );

    if (kind == VisitorKind.caravan) {
      _addVisitor(
        kind: kind,
        groupId: groupId,
        sx: sx,
        sy: sy,
        bx: bx,
        by: by,
        ex: ex,
        ey: ey,
        visit: visitDuration,
        hasCart: true,
        offset: 0,
        name: 'Kervan Arabası',
      );
      _addVisitor(
        kind: kind,
        groupId: groupId,
        sx: sx,
        sy: sy,
        bx: bx,
        by: by,
        ex: ex,
        ey: ey,
        visit: visitDuration,
        leader: true,
        offset: 1,
        name: 'Kervan Başı',
      );
      _addVisitor(
        kind: kind,
        groupId: groupId,
        sx: sx,
        sy: sy,
        bx: bx,
        by: by,
        ex: ex,
        ey: ey,
        visit: visitDuration,
        offset: 2,
        name: 'Kervan Yükçüsü',
      );
      _addVisitor(
        kind: kind,
        groupId: groupId,
        sx: sx,
        sy: sy,
        bx: bx,
        by: by,
        ex: ex,
        ey: ey,
        visit: visitDuration,
        offset: 3,
        name: 'Kervan Yolcusu',
      );
      _merchantTradeCd = _kFirstTradeDelay;
    } else {
      final count = kind == VisitorKind.traveler && _rng.nextBool() ? 2 : 1;
      for (int i = 0; i < count; i++) {
        _addVisitor(
          kind: kind,
          groupId: groupId,
          sx: sx,
          sy: sy,
          bx: bx,
          by: by,
          ex: ex,
          ey: ey,
          visit: visitDuration,
          leader: i == 0,
          offset: i,
          visualType: kind == VisitorKind.traveler
              ? VillagerType.shepherd
              : VillagerType.hunter,
          name: kind == VisitorKind.traveler ? 'Uzak Yolcu' : 'Adsız Yabancı',
        );
      }
    }

    _announceVisitor(kind, groupId);
  }

  void _addVisitor({
    required VisitorKind kind,
    required int groupId,
    required double sx,
    required double sy,
    required double bx,
    required double by,
    required double ex,
    required double ey,
    required double visit,
    required int offset,
    required String name,
    bool leader = false,
    bool hasCart = false,
    VillagerType visualType = VillagerType.merchant,
  }) {
    // Girişte üst üste doğmasın, durakta da tek piksele yığılmasın. Küçük
    // diyagonal ofset izometrik yolda doğal bir takip kolu üretir.
    final spread = offset * 0.36;
    final (mx, my) = _nearestLand(sx - spread, sy + spread);
    final (tx, ty) = _nearestLand(
      bx + (offset.isEven ? spread : -spread),
      by + (offset.isEven ? -spread * 0.45 : spread * 0.45),
    );
    _merchants.add(
      MerchantEntity(
        startCol: mx,
        startRow: my,
        browseX: tx,
        browseY: ty,
        exitX: ex,
        exitY: ey,
        groupId: groupId,
        visitorKind: kind,
        isGroupLeader: leader,
        hasCart: hasCart,
        browseLeft: visit,
        greetingLeft: hasCart ? 2.0 : 2.8 + offset * 0.25,
        visualType: visualType,
        male: offset.isEven,
        name: name,
      ),
    );
  }

  /// Dört çapraz geçişten biri. Çıkışın girişten farklı olması kritik: ziyaretçi
  /// sahneden silinmek için geri dönmez, köyü gerçek bir güzergâh gibi kullanır.
  (double, double, double, double) _visitorRoute() => switch (_rng.nextInt(4)) {
    0 => (1.5, 1.5, kCols - 2.0, kRows - 2.0),
    1 => (kCols - 2.0, kRows - 2.0, 1.5, 1.5),
    2 => (kCols - 2.0, 1.5, 1.5, kRows - 2.0),
    _ => (1.5, kRows - 2.0, kCols - 2.0, 1.5),
  };

  /// Kervan hana/pazara, yolcu hana/meyhaneye, yabancı pazar/kuyuya çekilir.
  (double, double) _visitorStop(VisitorKind kind) {
    final BuildingEntity? stop = switch (kind) {
      VisitorKind.caravan =>
        _firstBuildingOf(BuildingType.caravanserai) ??
            _firstBuildingOf(BuildingType.market),
      VisitorKind.traveler =>
        _firstBuildingOf(BuildingType.tavern) ??
            _firstBuildingOf(BuildingType.caravanserai) ??
            _firstBuildingOf(BuildingType.firepit),
      VisitorKind.stranger =>
        _firstBuildingOf(BuildingType.market) ??
            _firstBuildingOf(BuildingType.well),
    };
    if (stop != null) {
      return _nearestLand(
        stop.col + stop.cols / 2.0,
        stop.row + stop.rows + 0.75,
      );
    }
    final (cx, cy) = _villageCenter();
    return _nearestLand(cx.toDouble(), cy.toDouble());
  }

  void _announceVisitor(VisitorKind kind, int groupId) {
    final ctx = _voice(null, seed: _stableSeed('ziyaret${kind.name}', groupId));
    final lines = switch (kind) {
      VisitorKind.caravan => const [
        '🛒 Uzak yolun tozu göründü; bir kervan {köy-e} giriyor.',
        '🛒 At arabası {köy-in} yoluna döndü; han avlusu hareketlendi.',
        '🛒 Kervan {köy-de} mola verdi; denkler çözülüyor.',
      ],
      VisitorKind.traveler => const [
        '🧳 Uzak yoldan iki ayak sesi; bir yolcu {köy-e} uğradı.',
        '🧳 Bir yolcu {köy-de} soluklanıyor; heybesinde uzak yerlerin haberi var.',
        '🧳 Yol üstünden gelen bir yüz {köy-in} ateşini buldu.',
      ],
      VisitorKind.stranger => const [
        '◌ Tanınmayan bir yüz {köy-in} kıyısında durup etrafı süzüyor.',
        '◌ Bir yabancı {köy-e} girdi; ne aradığını henüz kimse bilmiyor.',
        '◌ Yol, {köy-e} adsız bir yabancı bıraktı.',
      ],
    };
    _showNotification(Voice.say(lines, ctx));
  }

  /// Kervan köyün FAZLASINI alır → altın. Taban stoğunun en çok üstünde olan
  /// kaynağı seçer; zorunlu stok satılmaz.
  void _merchantTrade() {
    ResourceKind? best;
    int bestSurplus = 0;
    (int, int, int)? bestRate;
    kMerchantBuyRates.forEach((kind, rate) {
      final (batch, _, keepFloor) = rate;
      final surplus = _stockpile.get(kind) - keepFloor;
      if (surplus >= batch && surplus > bestSurplus) {
        bestSurplus = surplus;
        best = kind;
        bestRate = rate;
      }
    });
    if (best == null) return;
    final kind = best!;
    final (batch, gold, _) = bestRate!;
    _stockpile.add(kind, -batch);
    _stockpile.gold = (_stockpile.gold + gold).clamp(0, 1 << 30);

    final ctx = _voice(
      null,
      seed: _stableSeed('tüccar${kind.asset}', _dayCount),
      extra: {
        'mal': kind.label.toLowerCase(),
        'miktar': '$batch',
        'altın': '$gold',
      },
    );
    _showNotification(
      Voice.say(const [
        '🛒 Kervan {miktar} {mal} aldı; {köy} {altın} altın kazandı.',
        '🛒 Kervan {miktar} {mal} karşılığı {altın} altın bıraktı.',
        '🛒 Tüccar {miktar} {mal} aldı; {köy} {altın} altın kazandı.',
        '🛒 Gezgin tüccar {miktar} {mal} karşılığı {altın} altın bıraktı.',
        '🛒 Tezgâhta pazarlık: {miktar} {mal} gitti, {altın} altın geldi.',
      ], ctx),
    );
    _chronicle(
      Voice.say(const [
        'Kervan {miktar} {mal} aldı; kasaya {altın} altın girdi.',
        'Kervanla ticaret: {mal} fazlası {altın} altına döndü.',
        'Gezgin tüccar {miktar} {mal} aldı; kasaya {altın} altın girdi.',
        'Tüccarla ticaret: {mal} fazlası {altın} altına döndü.',
      ], ctx),
      icon: '🛒',
    );
  }
}
