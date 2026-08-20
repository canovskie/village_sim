part of '../main.dart';

/// Gezgin tüccar — köye arada bir uğrayıp giden ambiyans varlığı. Haritanın
/// sağ-alt köşesinden gelir, pazarın/meydanın çevresinde bir süre oyalanır,
/// sonra geldiği köşeden çekip gider. Köyün sakini DEĞİL (nüfusa, eve, dilekçeye
/// karışmaz); kuş sürüleri gibi geçici. Kayda yazılmaz.
///
/// part of main.dart — State'in tüm private alanlarına erişim.
extension _SceneMerchant on _VillageSceneState {
  /// İki ziyaret arası boşluk aralığı (sim-saniye). ~1.5–3 oyun günü.
  static const double _kGapMin = 1.5 * kGameDaySeconds;
  static const double _kGapMax = 3.0 * kGameDaySeconds;

  /// Tüccarın köyde oyalanma süresi (sim-saniye) ~ yarım oyun günü.
  static const double _kVisitDuration = 0.45 * kGameDaySeconds;

  /// Tüccar köye varıp tezgâhı kurunca ilk alıma kadar geçen süre (sn).
  static const double _kFirstTradeDelay = 5.0;

  /// İki alım arası (sn) — ziyaret boyunca birkaç kez el değiştirir.
  static const double _kTradeInterval = 16.0;

  /// Sahne ana döngüsünden her tick. Spawn zamanlayıcısı + tüccar hareketi.
  void _tickMerchants(double dt) {
    // Zamanlayıcı yalnız tüccar yokken işler — aynı anda en fazla bir tüccar.
    if (_merchants.isEmpty) {
      _merchantTimer -= dt;
      if (_merchantTimer <= 0) {
        // Yalnız gündüz gelsin (yoldan görünür, sıcak karşılama). Gece beklesin.
        if (_cycle.dayLight > 0.45) {
          _spawnMerchant();
        } else {
          _merchantTimer = 20.0; // gece → kısa süre sonra tekrar dene
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
      // TİCARET — tüccar tezgâh başında oyalanırken köyün fazlasını satın alır
      // (dış altın kanalı). Yalnız browsing evresinde; giriş/çıkış sırasında
      // pazarlık olmaz.
      if (m.phase == MerchantPhase.browsing) {
        _merchantTradeCd -= dt;
        if (_merchantTradeCd <= 0) {
          _merchantTradeCd = _kTradeInterval;
          _merchantTrade();
        }
      }
    }
    if (_merchants.any((m) => m.finished)) {
      _merchants.removeWhere((m) => m.finished);
      if (_merchants.isEmpty) {
        final base = _kGapMin + _rng.nextDouble() * (_kGapMax - _kGapMin);
        _merchantTimer = merchantVisitGap(
          base,
          hasCaravanserai: _buildings.any(
            (b) => b.type == BuildingType.caravanserai,
          ),
        );
      }
    }
  }

  /// Haritanın sağ-alt köşesinden bir tüccar getirir. Zaten varsa no-op
  /// (Gezgin Tüccar olayı + zamanlayıcı çakışmasın). Köy içi gezinme merkezi
  /// han varsa onun avlusu; yoksa pazar, o da yoksa meydan.
  void _spawnMerchant() {
    if (_merchants.isNotEmpty) return;

    // Sağ-alt köşe (yüksek sütun + yüksek satır) → ekranda sağ-alt diyagonal.
    final (ex, ey) = _nearestLand(kCols - 2.0, kRows - 2.0);

    final caravanserai = _firstBuildingOf(BuildingType.caravanserai);
    final market = _firstBuildingOf(BuildingType.market);
    final double rawX, rawY;
    if (caravanserai != null) {
      (rawX, rawY) = (
        caravanserai.col + caravanserai.cols / 2.0,
        caravanserai.row + caravanserai.rows + 0.6,
      );
    } else if (market != null) {
      (rawX, rawY) = (
        market.col + market.cols / 2.0,
        market.row + market.rows + 0.6,
      );
    } else {
      final (cx, cy) = _villageCenter();
      (rawX, rawY) = (cx.toDouble(), cy.toDouble());
    }
    // Gezinme merkezini karaya sabitle — tüccar su/bina üstünde takılmasın.
    final (bx, by) = _nearestLand(rawX, rawY);

    _merchants.add(
      MerchantEntity(
        startCol: ex,
        startRow: ey,
        browseX: bx,
        browseY: by,
        exitX: ex,
        exitY: ey,
        browseLeft: merchantVisitDuration(
          _kVisitDuration,
          hasCaravanserai: caravanserai != null,
        ),
      ),
    );
    _merchantTradeCd = _kFirstTradeDelay; // varınca tezgâhı kurar, sonra alır
    // Köyün adını DIŞARIDAN gelen söyler: tüccar için burası "köy" değil,
    // güzergâhındaki bir yer adıdır (bkz. scene_voice `_villageWith` kuralı).
    _showNotification(
      Voice.say(
        caravanserai != null
            ? const [
                '🛒 Gezgin tüccar {köy-e} uğradı; Han avlusunda denklerini çözüyor.',
                '🛒 Bir kervan {köy-in} Hanına girdi; yabancı terazi avluda.',
              ]
            : const [
                '🛒 Gezgin tüccar {köy-e} uğradı; tezgâhını meydana kurdu.',
                '🛒 Bir kervan {köy-in} yolunu bulmuş; tüccar meydanda.',
                '🛒 Tüccar atını {köy-de} bağladı, denklerini çözüyor.',
                '🛒 Yabancı bir terazi kuruldu meydana: tüccar {köy-e} geldi.',
              ],
        _voice(null, seed: _stableSeed('tüccarGeldi', _dayCount)),
      ),
    );
  }

  /// Tüccar köyün FAZLASINI alır → altın. Her alımda taban stoğunun en çok
  /// üstünde olan kaynağı seçer (köyün en çok "elinde patlayan" malını) ve bir
  /// parti satın alır; taban altına inecekse dokunmaz. Cozy/no-fail: köyün
  /// zorunlusu satılmaz, kimse zarar etmez — yalnız birikmiş fazla paraya döner.
  /// Fazla yoksa sessizce geçer (tüccar tezgâhta bakınır, spam bildirim yok).
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
    if (best == null) return; // satacak fazla yok — tüccar yalnız gezinir
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
        '🛒 Tüccar {miktar} {mal} aldı; {köy} {altın} altın kazandı.',
        '🛒 Gezgin tüccar {miktar} {mal} karşılığı {altın} altın bıraktı.',
        '🛒 Tezgâhta pazarlık: {miktar} {mal} gitti, {altın} altın geldi.',
      ], ctx),
    );
    _chronicle(
      Voice.say(const [
        'Gezgin tüccar {miktar} {mal} aldı; kasaya {altın} altın girdi.',
        'Tüccarla ticaret: {mal} fazlası {altın} altına döndü.',
      ], ctx),
      icon: '🛒',
    );
  }
}
