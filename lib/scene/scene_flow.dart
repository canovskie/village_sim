part of '../main.dart';

/// Köy Akışı — görev tamamlanmasını izler, GÖRSEL ödül dağıtır, politika-türevli
/// Tüzük kademesini ilerletir. No-fail: yalnızca pozitif. Kaynak ödülü YOK;
/// ödüller kutlama FX + köy sevinci (gövde dili) + kalıcı çiçeklenme.
extension _SceneFlow on _VillageSceneState {
  static const double _kFlowScan = 0.5;

  /// QuestContext'i mevcut state'ten kurar.
  QuestContext _questContext() => QuestContext(
        buildings: _buildings,
        farmTiles: _farmTiles,
        population: _villagers.length,
        stock: _stockpile,
        policies: _policies,
        decorCount: _decor.length,
        charterTier: _charterTier,
      );

  void _tickFlow(double dt) {
    _flowScan += dt;
    if (_flowScan < _kFlowScan) return;
    _flowScan = 0;

    final ctx = _questContext();

    // Yeni tamamlanan TEK görev — akışı sakin pacele, ödül burst'ünü önle
    // (showcase köyünde aynı anda çok görev sağlanmış olabilir).
    for (final q in QuestBook.all) {
      if (q.tier > _charterTier) continue;
      if (_completedQuests.contains(q.id)) continue;
      if (!q.check(ctx)) continue;
      _completedQuests.add(q.id);
      _grantVisualReward(q.reward);
      _showNotification('✓ ${q.label}');
      break; // bir scan'de bir ödül → sürekli, sakin akış
    }

    // Kademe atlama — politika-odaklı Tüzük ilerlemesi (büyük kutlama).
    final newTier =
        QuestBook.charterTier(_completedQuests.length, _policies.enactedCount);
    if (newTier > _charterTier) {
      _charterTier = newTier;
      final tier = QuestBook.tierOf(newTier);
      _grantVisualReward(VisualReward.landmark);
      _reactFestival(); // ateşe toplanma + dans (scene_petitions şablonu)
      _showNotification('${tier.icon} Köyünüz "${tier.name}" oldu!');
    }
  }

  /// Görsel ödül — KAYNAK VERMEZ. Yoğunluğa göre kutlama FX + köy sevinci +
  /// köy merkezine kalıcı çiçek serpme (ilerledikçe köy gözle görülür güzelleşir).
  void _grantVisualReward(VisualReward kind) {
    final (cc, cr) = _villageCenter();
    switch (kind) {
      case VisualReward.sparkle:
        _feelVillage(NpcEmotion.joy, 3, 0.04);
        _scatterRewardDecor(cc, cr, 3, 2);
      case VisualReward.bloom:
        _feelVillage(NpcEmotion.joy, 4, 0.06);
        _scatterRewardDecor(cc, cr, 4, 4);
      case VisualReward.festival:
        _activeFx.add(ActiveFx(
            const EventEffect(fx: EventFx.festival, duration: 14), 14));
        _feelVillage(NpcEmotion.joy, 8, 0.10);
        _scatterRewardDecor(cc, cr, 5, 6);
      case VisualReward.landmark:
        _activeFx.add(ActiveFx(
            const EventEffect(fx: EventFx.festival, duration: 20), 20));
        _feelVillage(NpcEmotion.joy, 12, 0.14);
        _scatterRewardDecor(cc, cr, 7, 12);
    }
  }

  /// Köy merkezi — ateş yeri varsa orası, yoksa harita ortası (tile).
  (int, int) _villageCenter() {
    final f = _firepitBuilding;
    if (f != null) {
      return ((f.col + f.cols / 2).round(), (f.row + f.rows / 2).round());
    }
    return (kCols ~/ 2, kRows ~/ 2);
  }

  /// Merkez çevresine kalıcı çiçek/çalı serpme — su/bina/ağaç/dekor çakışmasız
  /// (`_sprinkleGreenAround` deseni).
  void _scatterRewardDecor(int cc, int cr, int radius, int count,
      {List<DecorKind>? kinds}) {
    kinds ??= const [
      DecorKind.daisy, DecorKind.poppy, DecorKind.lavender,
      DecorKind.buttercup, DecorKind.clover, DecorKind.bushSmall,
    ];
    final cands = <(int, int)>[];
    for (int dr = -radius; dr <= radius; dr++) {
      for (int dc = -radius; dc <= radius; dc++) {
        final c = cc + dc, r = cr + dr;
        if (c < 1 || c >= kCols - 1 || r < 1 || r >= kRows - 1) continue;
        if (_waterTiles.contains((c, r))) continue;
        if (_isOccupiedByBuilding(c, r)) continue;
        if (_trees.any((t) => t.col == c && t.row == r)) continue;
        if (_decor.any((d) => d.col == c && d.row == r)) continue;
        cands.add((c, r));
      }
    }
    if (cands.isEmpty) return;
    cands.shuffle(_rng);
    for (int i = 0; i < count && i < cands.length; i++) {
      final (c, r) = cands[i];
      _decor.add(DecorEntity(
        col: c, row: r,
        kind: kinds[_rng.nextInt(kinds.length)],
        variant: _rng.nextInt(3),
        jitterX: (_rng.nextDouble() - 0.5) * 0.5,
        jitterY: (_rng.nextDouble() - 0.5) * 0.5,
        swaySeed: _rng.nextInt(1000),
      ));
    }
  }
}
