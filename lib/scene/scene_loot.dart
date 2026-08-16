part of '../main.dart';

/// GÖMÜLÜ ZULA — çalınan malın dünyadaki hâli (Faz 4).
///
/// Hırsızlık eskiden bir sayı düşüşüydü: ambardan 9 yiyecek eksilir, fail
/// kaçar, bitti. Oyuncunun elinde hiçbir şey kalmazdı. Artık mal **köyün
/// toprağında** duruyor: hırsız onu bir yere gömdü, o yer bulunabilir ve mal
/// geri alınabilir.
///
/// Sözleşme (bkz. [LootCache]): gömmek bir jest değil, bir YER. Bulunmayan bir
/// zula da cezasız değildir — taze toprak izi zamanla kapanır, yani hırsızın
/// ne kadar hızlı kaçtığı gerçekten önemlidir.
extension _SceneLoot on _VillageSceneState {
  /// Zula taraması (sn) — her frame tüm köylüleri tüm zulalara karşı ölçmek
  /// israf; iz zaten yavaş kapanır.
  static const double _kLootScan = 1.5;

  void _tickLoot(double dt) {
    if (_lootCaches.isEmpty) return;

    for (final l in _lootCaches) {
      l.age += dt;
    }

    _lootScanSec -= dt;
    if (_lootScanSec > 0) return;
    _lootScanSec = _kLootScan;

    // Bulan var mı? Muhafız daha tetiktedir (görevi bu), ama zulanın üstüne
    // basan HERKES bulur — köylü tarlaya giderken toprakta bir tuhaflık görür.
    LootCache? found;
    VillagerEntity? finder;
    for (final l in _lootCaches) {
      final trace = lootTrace(
        l.age,
        _SceneCrime._kLootFade,
        witnessed: l.witnessed,
      );
      for (final v in _villagers) {
        if (v.isDying || v.isSleeping || v.isInsideBuilding) continue;
        // Gömen kendi zulasını "bulmaz" — üstünü örtmeye gider.
        if (identical(v, l.culprit)) continue;
        final alert = v.type == VillagerType.guard && v.hasProfession
            ? 1.5
            : 1.0;
        final r = lootFindRadius(trace, alert: alert);
        if (_wdist(v.gridX, v.gridY, l.gridX, l.gridY) <= r) {
          found = l;
          finder = v;
          break;
        }
      }
      if (found != null) break;
    }
    if (found == null || finder == null) return;
    _uncoverLoot(found, finder);
  }

  /// Zula bulundu — mal ambara döner, fail (biliniyorsa) ele verilir.
  void _uncoverLoot(LootCache l, VillagerEntity finder) {
    _lootCaches.remove(l);
    _stockpile.add(l.kind, l.amount);
    if (l.weaponAmount > 0) _stockpile.weapons += l.weaponAmount;
    kProbeLootRecovered += l.amount + l.weaponAmount;

    finder.feel(NpcEmotion.wonder, 4.0, moodDelta: 0.04);
    finder.lookToward(l.gridX, l.gridY);

    // Zulayı bulmak FAİLİ de ele verir: toprakta ad yazmaz ama köy kimin
    // kaybolduğunu, kimin o gece nerede olduğunu konuşur. Bulanın kanaati
    // sertleşir ve bu kanaat dedikoduyla yayılır (bkz. scene_perception).
    final culprit = l.culprit;
    if (culprit is VillagerEntity && _villagers.contains(culprit)) {
      _witnessEvent(
        Notion.crime,
        x: l.gridX,
        y: l.gridY,
        subject: culprit,
        subjectName: culprit.name,
      );
      finder.memory.nudgeOpinion(culprit, -0.35);
    }

    final weaponText = l.weaponAmount > 0 ? ' ve ${l.weaponAmount} silah' : '';
    _showNotification(
      '🪏 Zula bulundu — ${l.amount} ${l.kind.label.toLowerCase()}$weaponText ambara döndü.',
    );
    _chronicle(
      Voice.say(
        const [
          '🪏 Toprakta bir çuval çıktı. Kayıp mal köye döndü.',
          '🪏 Eşelenmiş toprak ele verdi: gömülü zula bulundu.',
          '🪏 Kaybolan mal bulundu — birileri onu gömmeyi denemişti.',
        ],
        _voice(
          finder,
          seed: _stableSeed('zula${l.gridX}${l.gridY}', _dayCount),
        ),
      ),
      icon: '🪏',
      kind: ChronicleKind.crisis,
    );
  }

  /// DEV/TEST — köy meydanına görülmüş bir zula göm.
  ///
  /// Bulunma+iade yolunun ([_tickLoot] → [_uncoverLoot]) gerçekten koştuğunu
  /// görmenin tek pratik yolu. Organik oyunda hırsız zulayı köyün eteğine ve
  /// çoğu kez GÖRÜLMEDEN gömer — bu doğru davranıştır (görülmeden gömen kazanır)
  /// ama kurtarma yolunun aylarca hiç çalışmaması demektir.
  void _devPlantLoot() {
    final (cc, cr) = _villageCenter();
    _lootCaches.add(
      LootCache(
        gridX: cc.toDouble(),
        gridY: cr.toDouble(),
        kind: ResourceKind.food,
        amount: 10,
        culpritName: 'bilinmeyen',
      )..witnessed = true,
    );
    _showNotification('🪏 Meydana görülmüş bir zula gömüldü (dev).');
  }

  /// Köyden çıkan köylünün zulalarındaki referansı kopar — mal toprakta kalır
  /// ama artık kimseyi suçlamaz (bkz. [_forgetVillager]).
  void _forgetLootOwner(VillagerEntity v) {
    for (final l in _lootCaches) {
      if (identical(l.culprit, v)) l.culprit = null;
    }
  }
}
