part of '../main.dart';

/// Tarladan ayrı harmanın dünya bağlantısı ve çiftçinin demet teslim zinciri.
extension _SceneHarman on _VillageSceneState {
  void _ensureHarmanSite() {
    if (_farmTiles.isEmpty || _harmanSites.isNotEmpty) return;

    final blocked = <(int, int)>{
      ..._waterTiles,
      ..._wilderness,
      for (final tile in _farmTiles) (tile.col, tile.row),
      for (final road in _roadSystem.all) (road.col, road.row),
      for (final mine in _mineNodes)
        if (!mine.isDepleted) (mine.col, mine.row),
      for (final tree in _trees)
        if (!tree.isFelled) (tree.col, tree.row),
      for (final landmark in _landmarks) (landmark.col, landmark.row),
      for (final reed in _reeds) ...[
        (reed.col, reed.row),
        (reed.col2, reed.row2),
      ],
      for (final bed in _reedBeds) (bed.gridX.floor(), bed.gridY.floor()),
    };
    for (final building in _buildings) {
      for (int c = building.col; c < building.col + building.cols; c++) {
        for (int r = building.row; r < building.row + building.rows; r++) {
          blocked.add((c, r));
        }
      }
    }
    for (final order in _orders) {
      final meta = kBuildingMeta[order.type]!;
      for (int c = order.col; c < order.col + meta.cols; c++) {
        for (int r = order.row; r < order.row + meta.rows; r++) {
          blocked.add((c, r));
        }
      }
    }
    if (_cleared.isNotEmpty) {
      for (int c = 0; c < kCols; c++) {
        for (int r = 0; r < kRows; r++) {
          if (!_cleared.contains((c, r))) blocked.add((c, r));
        }
      }
    }

    final site = findHarmanSite(_farmTiles, blocked);
    if (site == null) return;
    _harmanSites.add(site);
    for (final tile in site.tiles) {
      _claimGroundTile(tile.$1, tile.$2);
    }
    _spatialTimer = 0;
    _pathContext.bumpVersion();

    // Eski kayıtlarda tarlaya bırakılmış demetleri yeni harmana bir kez taşı.
    for (final hay in _hayEntities) {
      if (hay.isDelivered || hay.isBeingCarried) continue;
      if (hay.isBale) {
        placeBaleAtHarman(hay, site, _hayEntities, time: _time);
      } else {
        placeHayAtHarman(hay, site, _hayEntities, time: _time);
      }
    }
  }

  HarmanSite? _nearestHarman(double x, double y) {
    HarmanSite? best;
    var bestDistance = double.infinity;
    for (final site in _harmanSites) {
      final dx = site.centerX - x;
      final dy = site.centerY - y;
      final distance = dx * dx + dy * dy;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = site;
      }
    }
    return best;
  }

  bool _harmanHasRoomNear(double x, double y) {
    final site = _nearestHarman(x, y);
    return site != null && harmanCanAccept(site, _hayEntities);
  }

  void _sendHarvestToHarman(VillagerEntity villager, HarmanSite site) {
    final hay =
        HayEntity(
            type: HayType.pile,
            gridX: villager.gridX,
            gridY: villager.gridY,
          )
          ..spawnTime = _time
          ..targetHarmanCol = site.col
          ..targetHarmanRow = site.row;
    _hayEntities.add(hay);

    final job = villager.job;
    if (job != null) {
      job
        ..working = false
        ..harvesting = false
        ..carryingWater = false;
    }
    _setWorkPose(villager, null);
    final accepted = villager.assignCarryTask(
      hay,
      villager.gridX,
      villager.gridY,
      site.centerX,
      site.centerY,
      onDelivered: () {
        placeHayAtHarman(hay, site, _hayEntities, time: _time);
      },
      onCancelled: (_) {
        // İşten alınma/ölüm gibi kesintilerde demet yeniden tarlaya saçılmaz.
        placeHayAtHarman(hay, site, _hayEntities, time: _time);
      },
    );
    if (accepted) {
      hay.isBeingCarried = true;
    } else {
      placeHayAtHarman(hay, site, _hayEntities, time: _time);
    }
  }
}
