part of '../main.dart';

/// NPC günlük rutini — köylülerin amaçsız volta atması yerine **amaçlı hedef
/// akışı**. Bir köylü boşalıp [VillagerEntity.needsErrand] verince bu sistem
/// ona zamana (timeOfDay) ve ihtiyaca (energy/mood) göre bir varış noktası
/// (POI) atar: pazar, taverna, kuyu, ateş, kilise, meclis, kendi evi, bir
/// komşu ya da kısa bir gezinti. Köylü oraya yürür, bir süre oyalanır
/// (orada "bir şey yapıyormuş" gibi), sonra yenisini ister. Rastgele dolaşma
/// yalnız fallback (POI yoksa / çocuk).
///
/// Bağımlı: _spotsOf (scene_npc_activity), _obstacles/_waterTiles, _cycle.
extension _SceneNpcRoutine on _VillageSceneState {
  static const double _kRoutineScan = 0.6;

  void _tickRoutine(double dt) {
    if (_villagers.length < 2) return;
    _routineScan += dt;
    if (_routineScan < _kRoutineScan) return;
    _routineScan = 0;

    for (final v in _villagers) {
      if (!v.needsErrand) continue;
      // Yatak peşindeki evsizi saz sistemi sürer (yapacak iş varsa) — rutin
      // ona dokunmaz, yoksa errand sinyalini tüketip karışır.
      if (_homelessSeekingBed(v) && _reedTaskAvailable()) {
        v.needsErrand = false;
        continue;
      }
      // Mesleğinin işi başındaysa (çoban/avcı/değirmenci/hancı/rahip) onu iş
      // döngüsü sürer — rutin errand sinyalini tüketip işine karışmasın.
      // İşi YOKSA rutin devralır → işyerinde boş boş çakılı kalmaz.
      if (_hasJobLoop(v) && _workTaskAvailable(v)) {
        v.needsErrand = false;
        continue;
      }
      // Meşgul/uygun değilse sinyali temizle (errand yürütemez).
      if (!v.canRunErrands ||
          v.isInsideBuilding ||
          v.isSleeping ||
          v.isCarrying ||
          v.sitClaimed ||
          v.activity != VillagerActivity.none) {
        v.needsErrand = false;
        continue;
      }
      final dest = _pickErrand(v);
      if (dest != null) v.goTo(dest.$1, dest.$2, dest.$3);
      // dest == null → POI yok; villager fallback (kişisel dolaşma) devralır.
    }
  }

  /// Köylüye amaçlı bir hedef seçer: (x, y, dwell). Yalnızca zaman dilimi +
  /// çeşitlilik + yakınlık ağırlıkları. null = uygun POI yok.
  /// NOT: mood/energy artık rutini YÖNETMEZ — sayılar davranışın nedeni değil
  /// (bkz. plan: sayıları davranıştan ayır). Köy her ruh halinde aynı canlı.
  (double, double, double)? _pickErrand(VillagerEntity v) {
    final tod = _cycle.timeOfDay;
    final morning   = tod >= 0.25 && tod < 0.45;
    final midday    = tod >= 0.45 && tod < 0.62;
    final afternoon = tod >= 0.62 && tod < 0.78;
    final evening   = tod >= 0.78 && tod < 0.92;

    // (x, y, dwell, weight)
    final cands = <(double, double, double, double)>[];

    // Verilen türün EN YAKIN binasını seçip yanında boş bir nokta ekler.
    void addBuilding(BuildingType t, double w, double dwellLo, double dwellHi) {
      if (w <= 0) return;
      BuildingEntity? best;
      double bestD = 1e9;
      for (final b in _buildings) {
        if (b.type != t) continue;
        final dx = b.col + b.cols / 2.0 - v.gridX;
        final dy = b.row + b.rows / 2.0 - v.gridY;
        final d = dx * dx + dy * dy;
        if (d < bestD) {
          bestD = d;
          best = b;
        }
      }
      if (best == null) return;
      final cx = best.col + best.cols / 2.0;
      final cy = best.row + best.rows / 2.0;
      final spread = (best.cols > best.rows ? best.cols : best.rows) / 2.0 + 1.6;
      final spot = _freeSpotNear(cx, cy, spread);
      if (spot == null) return;
      cands.add((spot.$1, spot.$2, dwellLo + _rng.nextDouble() * (dwellHi - dwellLo), w));
    }

    // Pazar — sabah/öğle alışveriş.
    addBuilding(BuildingType.market,
        (morning ? 2.2 : 0) + (midday ? 2.0 : 0) + (afternoon ? 1.0 : 0), 5, 10);
    // Taverna — öğleden sonra/akşam.
    addBuilding(BuildingType.tavern,
        (afternoon ? 2.2 : 0) + (evening ? 2.4 : 0) + (midday ? 0.8 : 0), 6, 12);
    // Kuyu — su, gün boyu az.
    addBuilding(BuildingType.well, 0.8, 3, 5);
    // Ateş başı — akşam yüksek.
    addBuilding(BuildingType.firepit, evening ? 2.0 : 0.4, 6, 10);
    // Kilise — ara sıra.
    addBuilding(BuildingType.church, 0.7, 6, 10);
    // Meclis/meydan — gündüz.
    addBuilding(BuildingType.townhall, (morning || midday) ? 0.8 : 0.3, 4, 7);

    // Ev — akşam dinlenme çekimi.
    final home = v.homeBuilding;
    if (home is BuildingEntity) {
      final w = 0.5 + (evening ? 1.2 : 0);
      final cx = home.col + home.cols / 2.0;
      final cy = home.row + home.rows / 2.0;
      final spread = (home.cols > home.rows ? home.cols : home.rows) / 2.0 + 1.4;
      final spot = _freeSpotNear(cx, cy, spread);
      if (spot != null) {
        cands.add((spot.$1, spot.$2, 8 + _rng.nextDouble() * 8, w));
      }
    }

    // Komşu ziyareti — sosyal; her zaman düşük taban, öğleden sonra daha çok.
    // (Sürekli canlılık: ziyaret stat'a değil, her köylüye her an açık.)
    final visit = _randomVisitSpot(v);
    if (visit != null) {
      cands.add((visit.$1, visit.$2, 4 + _rng.nextDouble() * 4,
          1.2 + (afternoon ? 0.8 : 0)));
    }

    // Gezinti — organik çeşitlilik, her zaman düşük taban.
    final stroll = _freeSpotNear(v.spawnCol, v.spawnRow, 3.0);
    if (stroll != null) {
      cands.add((stroll.$1, stroll.$2, 3 + _rng.nextDouble() * 3, 1.0));
    }

    if (cands.isEmpty) return null;
    double total = 0;
    for (final c in cands) {
      total += c.$4;
    }
    var pick = _rng.nextDouble() * total;
    for (final c in cands) {
      pick -= c.$4;
      if (pick <= 0) return (c.$1, c.$2, c.$3);
    }
    final last = cands.last;
    return (last.$1, last.$2, last.$3);
  }

  /// Uzakta olmayan rastgele başka bir uyanık köylünün yanında boş bir nokta.
  (double, double)? _randomVisitSpot(VillagerEntity v) {
    final others = _villagers
        .where((o) =>
            !identical(o, v) &&
            !o.isInsideBuilding &&
            !o.isSleeping &&
            o.canRunErrands)
        .toList();
    if (others.isEmpty) return null;
    final o = others[_rng.nextInt(others.length)];
    return _freeSpotNear(o.gridX, o.gridY, 1.6);
  }

  /// (cx,cy) çevresinde harita içi, engelsiz, susuz boş bir tile bulur (12 deneme).
  (double, double)? _freeSpotNear(double cx, double cy, double spread) {
    for (int i = 0; i < 12; i++) {
      final tx = cx + (_rng.nextDouble() * 2 - 1) * spread;
      final ty = cy + (_rng.nextDouble() * 2 - 1) * spread;
      final c = tx.round(), r = ty.round();
      if (c < 1 || c >= kCols - 1 || r < 1 || r >= kRows - 1) continue;
      if (_obstacles.contains((c, r))) continue;
      if (_waterTiles.contains((c, r))) continue;
      return (tx, ty);
    }
    return null;
  }
}
