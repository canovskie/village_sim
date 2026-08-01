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

  /// Köylü boşa düştüğünü bildirdiğinde ([VillagerEntity.needsErrand]) AKLA
  /// haber verir: "yeni karar zamanı".
  ///
  /// Faz 1 öncesi burası köylüyü doğrudan kapıp bir POI'ye yollardı ve aynı
  /// köylüyü aynı karede iş/ateş/saz sistemleri de kapmaya çalışırdı. Artık
  /// hedef seçimi bir TEKLİF ([_bidErrand]); bu döngü yalnız hakemi uyandırır.
  void _tickRoutine(double dt) {
    if (_villagers.length < 2) return;
    _routineScan += dt;
    if (_routineScan < _kRoutineScan) return;
    _routineScan = 0;

    for (final v in _villagers) {
      if (!v.needsErrand) continue;
      v.needsErrand = false;
      // Yürüyen bir mikro-sahne varsa niyeti DÜŞÜRME — eylem kendi bitişinde
      // niyeti temizler ([_finishAct]). Yoksa kuyunun başında eğilmiş köylü
      // yarıda kaldırılırdı.
      if (v.act != null && !v.act!.done) continue;
      // Niyeti tükendi — hakem yeniden seçsin (bekletmeden).
      if (v.mind.intent.priority <= IntentPriority.routine) {
        v.mind.clear();
        v.mind.deliberateIn = 0;
      }
    }
  }

  /// Köylüye amaçlı bir hedef seçer: (x, y, dwell). Yalnızca zaman dilimi +
  /// çeşitlilik + yakınlık ağırlıkları. null = uygun POI yok.
  /// NOT: mood/energy artık rutini YÖNETMEZ — sayılar davranışın nedeni değil
  /// (bkz. plan: sayıları davranıştan ayır). Köy her ruh halinde aynı canlı.
  /// [foodBias] 1.0 = normal; açlık dürtüsü büyüdükçe hakem ([scene_mind])
  /// bunu yükseltir ve sofraya açılan hedefler (pazar/meyhane/ev) öne çıkar.
  /// Böylece "acıkma" ayrı bir davranış sistemi olmaz — aynı gidişin yönü değişir.
  ///
  /// Dönüş artık yalnız KOORDİNAT değil, HEDEFİN NE OLDUĞU: mikro-sahne
  /// ([scene_act]) buna göre kurulur — kuyuda kova doldurulur, pazarda sepet
  /// alınır, meyhanede maşrapa kalkar. [ErrandTarget.kind] null ise sahnesiz
  /// bir gidiştir (gezinti/komşu).
  _ErrandTarget? _pickErrand(VillagerEntity v, {double foodBias = 1.0}) {
    final tod = _cycle.timeOfDay;
    final morning   = tod >= 0.25 && tod < 0.45;
    final midday    = tod >= 0.45 && tod < 0.62;
    final afternoon = tod >= 0.62 && tod < 0.78;
    final evening   = tod >= 0.78 && tod < 0.92;

    // (x, y, dwell, weight, hedef türü)
    final cands = <(double, double, double, double, BuildingType?)>[];

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
      cands.add((spot.$1, spot.$2,
          dwellLo + _rng.nextDouble() * (dwellHi - dwellLo), w, t));
    }

    // KÖYÜN HÂLİ — zaman ağırlıklarının üstüne dünya basıncı biner. Aynı köylü,
    // aynı saatte, mühürlenen hükme göre başka bir yere yürür: Meclis-i Daimi
    // meydanı doldurur, Tek Söz boşaltır, Kutsal Gün herkesi mabede çeker.
    final p = _pressure;

    // Pazar — sabah/öğle alışveriş. Aç köylü saat gözetmez: taban ağırlık
    // eklenir, yoksa öğle dışında acıkan biri pazarı hiç düşünmezdi.
    addBuilding(BuildingType.market,
        ((morning ? 2.2 : 0) + (midday ? 2.0 : 0) + (afternoon ? 1.0 : 0) +
                (foodBias - 1.0) * 1.2) *
            p.marketPull * foodBias, 5, 10);
    // Taverna — öğleden sonra/akşam.
    addBuilding(BuildingType.tavern,
        ((afternoon ? 2.2 : 0) + (evening ? 2.4 : 0) + (midday ? 0.8 : 0) +
                (foodBias - 1.0) * 0.9) *
            p.tavernPull * foodBias, 6, 12);
    // Kuyu — su, gün boyu az. Su Yolu fermanı kuyu–tarla trafiğini canlandırır.
    addBuilding(BuildingType.well, 0.8 * p.wellPull, 3, 5);
    // Ateş başı — akşam yüksek.
    addBuilding(BuildingType.firepit, (evening ? 2.0 : 0.4) * p.firePull, 6, 10);
    // Kilise — ara sıra; inanç hükümleri burayı köyün merkezi yapabilir.
    addBuilding(BuildingType.church, 0.7 * p.churchPull, 6, 10);
    // Meclis/meydan — gündüz. Rejimin en okunur silueti bu ağırlıkta.
    addBuilding(BuildingType.townhall,
        ((morning || midday) ? 0.8 : 0.3) * p.squarePull, 4, 7);

    // Ev — akşam dinlenme çekimi. Mülk Tapusu/Tek Söz herkesi kendi kapısına
    // çeker; Ortak Ambar ve komün tersine iter.
    final home = v.homeBuilding;
    if (home is BuildingEntity) {
      final w = (0.5 + (evening ? 1.2 : 0)) * p.homePull * foodBias;
      final cx = home.col + home.cols / 2.0;
      final cy = home.row + home.rows / 2.0;
      final spread = (home.cols > home.rows ? home.cols : home.rows) / 2.0 + 1.4;
      final spot = _freeSpotNear(cx, cy, spread);
      if (spot != null) {
        cands.add((spot.$1, spot.$2, 8 + _rng.nextDouble() * 8, w, home.type));
      }
    }

    // Komşu ziyareti — sosyal; her zaman düşük taban, öğleden sonra daha çok.
    // (Sürekli canlılık: ziyaret stat'a değil, her köylüye her an açık.)
    //
    // ÖBEKLENME payı (Faz 5): aynı ziyaret çekimi, köyün hâline göre başka bir
    // sokak üretir. Tabanda (huddle 0.35) çarpan 1.0 — eski davranış birebir
    // korunur; hür/şen köyde insan insana yaklaşır, baskı altında dağılır.
    final visit = _randomVisitSpot(v);
    if (visit != null) {
      cands.add((visit.$1, visit.$2, 4 + _rng.nextDouble() * 4,
          (1.2 + (afternoon ? 0.8 : 0)) *
              p.visitPull *
              (0.55 + 1.3 * p.huddle),
          null));
    }

    // ÖBEĞE KATIL — kalabalık kanalının asıl işi. Yukarıdaki ziyaret rastgele
    // BİR kişinin yanına gider; bu aday kalabalığın EN KESİF olduğu yere gider.
    // Fark görsel olarak büyük: birincisi köye eşit dağılmış ikililer üretir,
    // ikincisi büyüyen halkalar (biri durunca yanına biri daha gelir). Baskıda
    // ağırlık sıfıra iner — sokak dağınık ve seyrek okunur.
    if (p.huddle > 0.22) {
      final knot = _huddleSpot(v);
      if (knot != null) {
        cands.add((knot.$1, knot.$2, 5 + _rng.nextDouble() * 5,
            2.4 * (p.huddle - 0.22), null));
      }
    }

    // Gezinti — organik çeşitlilik, her zaman düşük taban.
    final stroll = _freeSpotNear(v.spawnCol, v.spawnRow, 3.0);
    if (stroll != null) {
      cands.add((stroll.$1, stroll.$2, 3 + _rng.nextDouble() * 3,
          1.0 * p.strollPull, null));
    }

    if (cands.isEmpty) return null;
    double total = 0;
    for (final c in cands) {
      total += c.$4;
    }
    // Oyalanma süresi köyün hâline göre uzar/kısalır: seferberlikte kimse
    // oyalanmaz, kutsal günde herkes oyalanır. Aynı hedef, başka tempo.
    final rest = p.restDrive;
    var pick = _rng.nextDouble() * total;
    for (final c in cands) {
      pick -= c.$4;
      if (pick <= 0) {
        return _ErrandTarget(c.$1, c.$2, c.$3 * rest, c.$5);
      }
    }
    final last = cands.last;
    return _ErrandTarget(last.$1, last.$2, last.$3 * rest, last.$5);
  }

  /// KALABALIĞIN MERKEZİ — en çok komşusu olan köylünün yanında boş bir nokta.
  ///
  /// "Rastgele birinin yanı" ([_randomVisitSpot]) ile farkı, öbeklerin BÜYÜMESİ:
  /// iki kişinin durduğu yere üçüncü, sonra dördüncü gelir. Kalabalık böyle
  /// kendiliğinden doğar; yoksa köy hep eşit dağılmış ikililer üretir.
  ///
  /// Komşu sayımı O(n²) ama seyrek çağrılır (yalnız yeni errand seçiminde) ve
  /// köy nüfusu birkaç düzine — ölçüm yapılacak bir yük değil.
  (double, double)? _huddleSpot(VillagerEntity v) {
    VillagerEntity? best;
    var bestCount = 0;
    for (final o in _villagers) {
      if (identical(o, v) || o.isInsideBuilding || o.isSleeping) continue;
      if (!o.canRunErrands) continue;
      var count = 0;
      for (final n in _villagers) {
        if (identical(n, o) || n.isInsideBuilding || n.isSleeping) continue;
        final dx = n.gridX - o.gridX, dy = n.gridY - o.gridY;
        if (dx * dx + dy * dy <= 9.0) count++; // 3 tile yarıçap
      }
      if (count > bestCount) {
        bestCount = count;
        best = o;
      }
    }
    // Tek başına duran birinin "yanı" öbek değildir — o zaten ziyaret adayı.
    if (best == null || bestCount < 1) return null;
    return _freeSpotNear(best.gridX, best.gridY, 1.8);
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

  /// (cx,cy) çevresinde harita içi, engelsiz, susuz boş bir tile bulur.
  ///
  /// YOL TERCİHİ: ilk uygun noktayı döndürmek yerine 12 aday arasından yol
  /// üstünde olanı seçer (varsa). Köylüler binaların yol tarafında bekler,
  /// gidiş gelişler kendiliğinden damarlara oturur — yol ağı yalnız A*
  /// maliyetinde değil, VARIŞ NOKTALARINDA da görünür olur.
  (double, double)? _freeSpotNear(double cx, double cy, double spread) {
    (double, double)? fallback;
    for (int i = 0; i < 12; i++) {
      final tx = cx + (_rng.nextDouble() * 2 - 1) * spread;
      final ty = cy + (_rng.nextDouble() * 2 - 1) * spread;
      final c = tx.round(), r = ty.round();
      if (c < 1 || c >= kCols - 1 || r < 1 || r >= kRows - 1) continue;
      if (_obstacles.contains((c, r))) continue;
      if (_waterTiles.contains((c, r))) continue;
      if (_roadSystem.has(c, r)) return (tx, ty);
      fallback ??= (tx, ty);
    }
    return fallback;
  }
}

/// Bir errand hedefi — nokta + oyalanma + HEDEFİN NE OLDUĞU.
///
/// [kind] mikro-sahnenin anahtarıdır: kuyu mu, pazar mı, meyhane mi. null ise
/// sahnesiz gidiş (gezinti/komşu ziyareti) — orada yapacak somut bir iş yok.
class _ErrandTarget {
  final double x, y;
  final double dwell;
  final BuildingType? kind;
  const _ErrandTarget(this.x, this.y, this.dwell, this.kind);
}
