part of '../main.dart';

/// DÜNYA DEKORU — tek yerleşim, nüfus ve topoloji kapısı.
///
/// Çiçekler eskiden dünya üretimi, görev ödülü, bina politikası ve
/// kişisel hikâyelerden birbirinden habersiz ekleniyordu. Sonradan gelen yol,
/// tarla ya da şantiye de aynı tile'daki dekoru sahiplenmiyordu. Sonuç hem
/// nüfus şişmesi hem de animasyonların üstünde kalan "hayalet" çiçeklerdi.
///
/// Saf sayı/mesafe kararları [decor_population.dart]'ta yaşar; bu part yalnız
/// o kuralları mevcut sahne varlıklarına bağlar.
extension _SceneDecor on _VillageSceneState {
  int get _developedTileCount {
    var total = _farmTiles.length + _roadSystem.count;
    for (final b in _buildings) {
      total += b.cols * b.rows;
    }
    for (final o in _orders) {
      if (o.completed) continue;
      final meta = kBuildingMeta[o.type]!;
      total += meta.cols * meta.rows;
    }
    return total;
  }

  int get _flowerPopulationLimit => flowerPopulationBudget(
    kCols * kRows,
    developedTiles: _developedTileCount,
  );

  Iterable<(int, int)> get _liveFlowerTiles sync* {
    for (final d in _decor) {
      if (!d.crushed && isFlowerDecorKind(d.kind)) yield (d.col, d.row);
    }
  }

  int get _liveFlowerCount {
    var count = 0;
    for (final d in _decor) {
      if (!d.crushed && isFlowerDecorKind(d.kind)) count++;
    }
    return count;
  }

  /// Bir tile kalıcı dekor barındırabilir mi? Dekorun kendisi burada
  /// kontrol edilmez; aynı-tile/flower-spacing kontrolü [_canPlantDecor]'da.
  bool _decorSurfaceBlocked(int c, int r) {
    if (c < 0 || c >= kCols || r < 0 || r >= kRows) return true;
    if (_waterTiles.contains((c, r)) || _wilderness.contains((c, r))) {
      return true;
    }
    if (_farmTiles.any((f) => f.col == c && f.row == r)) return true;
    if (_roadSystem.has(c, r)) return true;
    if (_roadOrders.any((o) => !o.completed && o.col == c && o.row == r)) {
      return true;
    }
    if (_isOccupiedByBuilding(c, r)) return true;
    for (final o in _orders) {
      if (o.completed) continue;
      final meta = kBuildingMeta[o.type]!;
      if (c >= o.col &&
          c < o.col + meta.cols &&
          r >= o.row &&
          r < o.row + meta.rows) {
        return true;
      }
    }
    if (_trees.any((t) => t.col == c && t.row == r)) return true;
    if (_mineNodes.any((n) => !n.isDepleted && n.col == c && n.row == r)) {
      return true;
    }
    if (_reeds.any(
      (reed) =>
          (reed.col == c && reed.row == r) ||
          (reed.col2 == c && reed.row2 == r),
    )) {
      return true;
    }
    if (_landmarks.any((site) => site.col == c && site.row == r)) return true;
    if (_berryBushes.any((b) => b.col == c && b.row == r)) return true;
    if (_graves.any((g) => g.col.floor() == c && g.row.floor() == r)) {
      return true;
    }
    if (_reedBeds.any((b) => b.gridX.floor() == c && b.gridY.floor() == r)) {
      return true;
    }
    return false;
  }

  /// Yerde duran yükler dekor topolojisinin sahibi değildir: canlı dünyada
  /// kutu/saman/yumurta/zula doğduğunda mevcut flora yerinde kalır ve kayıt
  /// açmak görünümü değiştirmemelidir. Yine de nesne oradayken yeni dekor
  /// dikilmesini engellerler.
  bool _decorTileTemporarilyOccupied(int c, int r) {
    if (_resourceBoxes.any(
      (box) =>
          !box.isDelivered && box.gridX.floor() == c && box.gridY.floor() == r,
    )) {
      return true;
    }
    if (_hayEntities.any(
      (hay) =>
          !hay.isDelivered && hay.gridX.floor() == c && hay.gridY.floor() == r,
    )) {
      return true;
    }
    if (_eggs.any((egg) => egg.gridX.floor() == c && egg.gridY.floor() == r)) {
      return true;
    }
    if (_lootCaches.any(
      (loot) => loot.gridX.floor() == c && loot.gridY.floor() == r,
    )) {
      return true;
    }
    return false;
  }

  bool _canPlantDecor(int c, int r, DecorKind kind) {
    if (_decorSurfaceBlocked(c, r) || _decorTileTemporarilyOccupied(c, r)) {
      return false;
    }
    if (_decor.any((d) => d.col == c && d.row == r)) return false;
    if (!isFlowerDecorKind(kind)) return true;
    if (_liveFlowerCount >= _flowerPopulationLimit) return false;
    return hasGroundFloraBreathingRoom((c, r), _liveFlowerTiles);
  }

  /// Dinamik dekor kaynaklarının ortak kapısı. Uygun olmayan istek bir
  /// başka tile deneyebilsin diye bool döner; sessizce üst üste bindirmez.
  bool _tryPlantDecor(
    int c,
    int r,
    DecorKind kind, {
    int variantCount = 3,
    double jitter = 0.5,
  }) {
    if (!_canPlantDecor(c, r, kind)) return false;
    _appendDecor(
      DecorEntity(
        col: c,
        row: r,
        kind: kind,
        variant: _rng.nextInt(variantCount),
        jitterX: (_rng.nextDouble() - 0.5) * jitter,
        jitterY: (_rng.nextDouble() - 0.5) * jitter,
        swaySeed: _rng.nextInt(1000),
      ),
    );
    return true;
  }

  /// Stump+fallen-log gibi bilinçli aynı-tile kompozisyonlarının düşük
  /// seviye kapısı. Topoloji sayacını atlamamak için doğrudan `_decor.add`
  /// kullanılmaz.
  void _appendDecor(DecorEntity decor) {
    _decor.add(decor);
    _decorVersion++;
    if (isBlockingDecorKind(decor.kind)) _invalidateDecorTopology();
  }

  void _replaceDecor(Iterable<DecorEntity> decor) {
    final replacement = decor.toList(growable: false);
    if (replacement.length == _decor.length) {
      var sameTopology = true;
      for (var i = 0; i < replacement.length; i++) {
        if (!identical(replacement[i], _decor[i])) {
          sameTopology = false;
          break;
        }
      }
      if (sameTopology) return;
    }
    final beforeBlocking = <(int, int)>{
      for (final d in _decor)
        if (!d.crushed && isBlockingDecorKind(d.kind)) (d.col, d.row),
    };
    final afterBlocking = <(int, int)>{
      for (final d in replacement)
        if (!d.crushed && isBlockingDecorKind(d.kind)) (d.col, d.row),
    };
    _decor
      ..clear()
      ..addAll(replacement);
    _decorVersion++;
    if (beforeBlocking.length != afterBlocking.length ||
        beforeBlocking.any((tile) => !afterBlocking.contains(tile))) {
      _invalidateDecorTopology();
    }
  }

  int _removeDecorWhere(bool Function(DecorEntity) remove) {
    var removedBlocking = false;
    for (final d in _decor) {
      if (remove(d) && isBlockingDecorKind(d.kind)) removedBlocking = true;
    }
    final before = _decor.length;
    _decor.removeWhere(remove);
    final removed = before - _decor.length;
    if (removed > 0) {
      _decorVersion++;
      if (removedBlocking) _invalidateDecorTopology();
    }
    return removed;
  }

  void _invalidateDecorTopology() {
    _spatialTimer = 0;
    _pathContext.bumpVersion();
  }

  void _clearDecorTile(int c, int r) {
    _removeDecorWhere((d) => d.col == c && d.row == r);
  }

  void _clearDecorFootprint(int col, int row, int cols, int rows) {
    _removeDecorWhere(
      (d) =>
          d.col >= col &&
          d.col < col + cols &&
          d.row >= row &&
          d.row < row + rows,
    );
  }

  /// Yol, tarla veya yapı bir zemini sahiplendiğinde düşük dekorun yanında
  /// geçici saz yatağını ve henüz serilmemiş kuruluş rezervini de kaldırır.
  /// Sahibi hedef referansını bırakır; evsizse reed sistemi sonraki taramada
  /// uygun başka bir slot bulur.
  void _claimGroundFootprint(int col, int row, int cols, int rows) {
    bool inside(int c, int r) =>
        c >= col && c < col + cols && r >= row && r < row + rows;

    _clearDecorFootprint(col, row, cols, rows);
    final displaced = <VillagerEntity>{};
    final beforeBeds = _reedBeds.length;
    _reedBeds.removeWhere((bed) {
      if (!inside(bed.gridX.floor(), bed.gridY.floor())) return false;
      final owner = bed.owner;
      if (owner is VillagerEntity) displaced.add(owner);
      return true;
    });
    _foundingBedTargets.removeWhere((villager, target) {
      if (!inside(target.$1.floor(), target.$2.floor())) return false;
      displaced.add(villager);
      return true;
    });
    for (final villager in displaced) {
      if (!villager.sleepIsHome) {
        villager.sleepTarget = null;
        if (villager.isSleeping) villager.state = VillagerState.idle;
      }
    }
    if (_reedBeds.length != beforeBeds || displaced.isNotEmpty) {
      _spatialTimer = 0;
      _pathContext.bumpVersion();
    }
  }

  void _claimGroundTile(int col, int row) =>
      _claimGroundFootprint(col, row, 1, 1);

  /// Eski kayıtları ve doğrudan kurulan test köylerini bugünün
  /// sözleşmesine taşır: sahipli yüzeydeki dekoru atar, bitkilerin arasına
  /// nefes koyar ve toplam çiçek bütçesini aşan uzak yamaları seyreltir.
  void _sanitizeDecorPopulation() {
    final surfaceSafe = <DecorEntity>[
      for (final d in _decor)
        if (!_decorSurfaceBlocked(d.col, d.row)) d,
    ];
    // Eski kesim sistemi her ağaçta aynı kareye hem dip hem dev gövde koyup
    // köyü kalıcı kütük tarlasına çeviriyordu. Bu ikili kesin kesim izidir;
    // kaynak taşındığı için yalnız küçük dip kalır. Tek başına doğmuş doğal
    // devrik kütük korunur ve fiziksel engel olur.
    final stumpTiles = <(int, int)>{
      for (final d in surfaceSafe)
        if (d.kind == DecorKind.stump) (d.col, d.row),
    };
    final unblocked = <DecorEntity>[
      for (final d in surfaceSafe)
        if (!(d.kind == DecorKind.fallenLog &&
            stumpTiles.contains((d.col, d.row))))
          d,
    ];
    // Eski kayıt aynı kareye hem çiçek hem hacimli dekor yazmış olabilir.
    // Hacimli dekoru koru; zemin florasını o karenin ikinci sahibi yapma.
    final volumetricTiles = <(int, int)>{
      for (final d in unblocked)
        if (!isGroundFloraDecorKind(d.kind)) (d.col, d.row),
    };

    final flowers =
        unblocked
            .where(
              (d) =>
                  !d.crushed &&
                  isFlowerDecorKind(d.kind) &&
                  !volumetricTiles.contains((d.col, d.row)),
            )
            .toList()
          ..sort((a, b) {
            final band = _flowerKeepBand(a).compareTo(_flowerKeepBand(b));
            if (band != 0) return band;
            return _flowerStableRank(a).compareTo(_flowerStableRank(b));
          });

    final keepFlowers = <DecorEntity>{};
    final keptTiles = <(int, int)>[];
    for (final flower in flowers) {
      if (keepFlowers.length >= _flowerPopulationLimit) break;
      final tile = (flower.col, flower.row);
      if (!hasGroundFloraBreathingRoom(tile, keptTiles)) continue;
      keepFlowers.add(flower);
      keptTiles.add(tile);
    }

    final sanitized = <DecorEntity>[
      for (final d in unblocked)
        if (!isFlowerDecorKind(d.kind) ||
            (d.crushed && !volumetricTiles.contains((d.col, d.row))) ||
            keepFlowers.contains(d))
          d,
    ];
    if (sanitized.length == _decor.length) {
      var identicalContents = true;
      for (var i = 0; i < sanitized.length; i++) {
        if (!identical(sanitized[i], _decor[i])) {
          identicalContents = false;
          break;
        }
      }
      if (identicalContents) return;
    }
    _replaceDecor(sanitized);
  }

  /// Bilinçli çiçekleri koru: önce kovan/çiçekçi menzili, sonra genel
  /// köy çevresi, en son vahşi yamalar. Eşitlikte koordinat hash'i sayesinde
  /// kayıt her açıldığında aynı demetler kalır.
  int _flowerKeepBand(DecorEntity d) {
    for (final b in _buildings) {
      if (b.type != BuildingType.floristCottage &&
          b.type != BuildingType.beehive) {
        continue;
      }
      final meta = kBuildingMeta[b.type]!;
      final cx = b.col + meta.cols / 2.0;
      final cy = b.row + meta.rows / 2.0;
      final dx = d.col + 0.5 - cx;
      final dy = d.row + 0.5 - cy;
      final reach = meta.effectRadius + 1.0;
      if (dx * dx + dy * dy <= reach * reach) return 0;
    }
    for (final b in _buildings) {
      final dx = (d.col - (b.col + b.cols ~/ 2)).abs();
      final dy = (d.row - (b.row + b.rows ~/ 2)).abs();
      if (dx <= 4 && dy <= 4) return 1;
    }
    return 2;
  }

  int _flowerStableRank(DecorEntity d) =>
      (d.col * 73856093) ^
      (d.row * 19349663) ^
      (d.kind.index * 83492791) ^
      (d.variant * 2654435761);
}
