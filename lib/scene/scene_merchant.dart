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
    }
    if (_merchants.any((m) => m.finished)) {
      _merchants.removeWhere((m) => m.finished);
      if (_merchants.isEmpty) {
        _merchantTimer = _kGapMin + _rng.nextDouble() * (_kGapMax - _kGapMin);
      }
    }
  }

  /// Haritanın sağ-alt köşesinden bir tüccar getirir. Zaten varsa no-op
  /// (Gezgin Tüccar olayı + zamanlayıcı çakışmasın). Köy içi gezinme merkezi
  /// pazar varsa onun çevresi, yoksa meydan.
  void _spawnMerchant() {
    if (_merchants.isNotEmpty) return;

    // Sağ-alt köşe (yüksek sütun + yüksek satır) → ekranda sağ-alt diyagonal.
    final (ex, ey) = _nearestLand(kCols - 2.0, kRows - 2.0);

    final market = _firstBuildingOf(BuildingType.market);
    final double rawX, rawY;
    if (market != null) {
      (rawX, rawY) =
          (market.col + market.cols / 2.0, market.row + market.rows + 0.6);
    } else {
      final (cx, cy) = _villageCenter();
      (rawX, rawY) = (cx.toDouble(), cy.toDouble());
    }
    // Gezinme merkezini karaya sabitle — tüccar su/bina üstünde takılmasın.
    final (bx, by) = _nearestLand(rawX, rawY);

    _merchants.add(MerchantEntity(
      startCol: ex,
      startRow: ey,
      browseX: bx,
      browseY: by,
      exitX: ex,
      exitY: ey,
      browseLeft: _kVisitDuration,
    ));
    _showNotification('🛒 Bir gezgin tüccar köye uğradı.');
  }
}
