part of '../main.dart';

/// KARARIN SOKAKTAKİ İZİ — dilekçe, olay ve kanunların ortak dünya katmanı.
///
/// Bir karar burada ya gerçek bir dış varlığa bağlanır, ya zaman alan bir işe
/// dönüşür, ya da günler boyunca tekrarlanan bir NPC davranışı bırakır. Böylece
/// bildirim kaybolduğunda hüküm de görünmez olmaz.
extension _SceneGovernanceAction on _VillageSceneState {
  bool get _hasCaravanInWorld => _merchants.any(
    (m) => m.visitorKind == VisitorKind.caravan && !m.finished,
  );

  bool get _hasActiveCaravan => _merchants.any(
    (m) =>
        m.visitorKind == VisitorKind.caravan &&
        !m.finished &&
        (m.phase == MerchantPhase.greeting ||
            m.phase == MerchantPhase.browsing),
  );

  String? _petitionOptionBlockReason(PetitionOption option) {
    return switch (option.presence) {
      DecisionPresence.none => null,
      DecisionPresence.activeCaravan =>
        _hasActiveCaravan ? null : 'Köyde kervan yok — bu yük satın alınamaz',
    };
  }

  void _startDecisionProcess(
    Petition petition,
    PetitionOption option,
    VillagerEntity? preferred,
  ) {
    final spec = option.process;
    if (spec == null) return;
    final actor = _governanceActor(preferred: preferred);
    final actorName = actor?.name ?? 'Köyün ulağı';
    final due = _time + spec.durationDays * kGameDaySeconds;
    final id = '${petition.id}.${spec.kind.name}.${_time.toStringAsFixed(3)}';
    _decisionProcesses.add(
      DecisionProcess(
        id: id,
        kind: spec.kind,
        title: spec.title,
        actorName: actorName,
        startedSim: _time,
        dueSim: due,
        completionText: spec.completionText,
        completionAnnal: spec.completionAnnal,
        foodOnComplete: spec.foodOnComplete,
        woodOnComplete: spec.woodOnComplete,
        stoneOnComplete: spec.stoneOnComplete,
        ironOnComplete: spec.ironOnComplete,
        goldOnComplete: spec.goldOnComplete,
      ),
    );
    if (actor != null) {
      _prepForScene(actor);
      final (ex, ey) = _villageEdgePoint();
      actor.mind.impose(
        IntentKind.errand,
        '${spec.title}: ${spec.departureText}',
        priority: IntentPriority.need,
      );
      actor.act = Act('${spec.title}: yola çıkıyor', [
        ActStep.goTo(ex, ey),
        ActStep.face(ex, ey),
        const ActStep.take(PropKind.sack),
        ActStep.work(
          max(5.0, spec.durationDays * kGameDaySeconds * 0.72),
          pose: ActPose.stand,
        ),
      ]);
    }
    _showNotification('🛤 $actorName — ${spec.departureText}.');
  }

  void _stageCaravanDelivery(String source) {
    if (!_hasActiveCaravan) return;
    MerchantEntity? leader;
    for (final m in _merchants) {
      if (m.canTrade && m.phase != MerchantPhase.leaving && !m.finished) {
        leader = m;
        break;
      }
    }
    final actor = _governanceActor();
    if (actor == null || leader == null) return;
    final warehouse = _firstBuildingOf(BuildingType.warehouse);
    final (tx, ty) = warehouse != null
        ? (_standSpotFor(warehouse, actor) ?? _centerOf(warehouse))
        : _villageCenterD();
    _prepForScene(actor);
    actor.mind.impose(
      IntentKind.errand,
      '$source gereği kervan yükünü indiriyor',
      priority: IntentPriority.need,
    );
    actor.act = Act('$source: kervan kerestesini indiriyor', [
      ActStep.goTo(leader.gridX, leader.gridY),
      const ActStep.work(1.8, pose: ActPose.stoop),
      const ActStep.take(PropKind.firewood),
      ActStep.goTo(tx, ty),
      const ActStep.work(1.5, pose: ActPose.stoop),
      const ActStep.put(),
    ]);
  }

  void _startEventAftermath(EventOutcome event, EventChoice choice) {
    final spec = aftermathForChoice(event.id, choice.id);
    if (spec == null) return;
    _governanceAftermath.removeWhere((a) => a.id == event.id);
    _governanceAftermath.add(
      GovernanceAftermath(
        id: event.id,
        kind: spec.kind,
        source: spec.source,
        untilSim: _time + spec.durationDays * kGameDaySeconds,
        nextBeatSim: _time + 4.0,
      ),
    );
  }

  void _tickGovernanceActions(double dt) {
    _completeDecisionProcesses();
    _tickEventAftermath();
    _tickLawSignatures();
  }

  void _completeDecisionProcesses() {
    for (final process in List<DecisionProcess>.of(_decisionProcesses)) {
      if (process.dueSim > _time) continue;
      _stockpile.food = (_stockpile.food + process.foodOnComplete).clamp(
        0,
        1 << 30,
      );
      _stockpile.wood = (_stockpile.wood + process.woodOnComplete).clamp(
        0,
        1 << 30,
      );
      _stockpile.stone = (_stockpile.stone + process.stoneOnComplete).clamp(
        0,
        1 << 30,
      );
      _stockpile.iron = (_stockpile.iron + process.ironOnComplete).clamp(
        0,
        1 << 30,
      );
      _stockpile.gold = (_stockpile.gold + process.goldOnComplete).clamp(
        0,
        1 << 30,
      );
      _stageProcessReturn(process);
      _showNotification(process.completionText);
      _chronicle(
        process.completionAnnal,
        icon: '🛤',
        kind: ChronicleKind.decision,
      );
      _decisionProcesses.remove(process);
    }
  }

  void _stageProcessReturn(DecisionProcess process) {
    final actor = _governanceActor(name: process.actorName);
    if (actor == null) return;
    final (ex, ey) = _villageEdgePoint();
    final warehouse = _firstBuildingOf(BuildingType.warehouse);
    final (tx, ty) = warehouse != null
        ? (_standSpotFor(warehouse, actor) ?? _centerOf(warehouse))
        : _villageCenterD();
    _prepForScene(actor);
    actor.mind.impose(
      IntentKind.errand,
      '${process.title}: yükle köye dönüyor',
      priority: IntentPriority.need,
    );
    actor.act = Act('${process.title}: keresteyi ambara getiriyor', [
      ActStep.goTo(ex, ey),
      const ActStep.take(PropKind.firewood),
      ActStep.goTo(tx, ty),
      const ActStep.work(1.6, pose: ActPose.stoop),
      const ActStep.put(),
    ]);
  }

  void _tickEventAftermath() {
    _governanceAftermath.removeWhere((a) => a.untilSim <= _time);
    for (final aftermath in _governanceAftermath) {
      if (aftermath.nextBeatSim > _time) continue;
      if (_stageGovernanceBeat(aftermath.kind, aftermath.source)) {
        aftermath.nextBeatSim =
            _time + (0.28 + _rng.nextDouble() * 0.16) * kGameDaySeconds;
      } else {
        aftermath.nextBeatSim = _time + 8.0;
      }
    }
  }

  void _tickLawSignatures() {
    if (_policies.sealed.isEmpty || _time < _lawBehaviorNextSim) return;
    final ids = _policies.sealed.toList()..sort();
    _lawBehaviorCursor %= ids.length;
    LawSignature? signature;
    for (var i = 0; i < ids.length; i++) {
      final id = ids[(_lawBehaviorCursor + i) % ids.length];
      signature = lawSignatures[id];
      if (signature != null) {
        _lawBehaviorCursor = (_lawBehaviorCursor + i + 1) % ids.length;
        break;
      }
    }
    if (signature == null) {
      _lawBehaviorNextSim = _time + 0.4 * kGameDaySeconds;
      return;
    }
    final staged = _stageGovernanceBeat(signature.kind, signature.source);
    _lawBehaviorNextSim = _time + (staged ? 0.30 : 0.08) * kGameDaySeconds;
  }

  bool _stageGovernanceBeat(GovernanceBeatKind kind, String source) {
    final actor = _governanceActor();
    if (actor == null) return false;
    final center = _villageCenterD();
    var target = center;
    var prop = PropKind.none;
    var pose = ActPose.stand;
    var label = '$source gereği görev yapıyor';

    BuildingEntity? firstOf(List<BuildingType> types) {
      for (final type in types) {
        final b = _firstBuildingOf(type);
        if (b != null) return b;
      }
      return null;
    }

    void useBuilding(List<BuildingType> types) {
      final b = firstOf(types);
      if (b != null) target = _standSpotFor(b, actor) ?? _centerOf(b);
    }

    switch (kind) {
      case GovernanceBeatKind.neighborVisit:
        final other = _governanceActor(excluding: actor);
        if (other != null) target = (other.gridX, other.gridY);
        prop = PropKind.bread;
        pose = ActPose.stand;
        label = '$source gereği komşusunu yokluyor';
      case GovernanceBeatKind.waterDuty:
        useBuilding([BuildingType.well, BuildingType.fountain]);
        prop = PropKind.bucketFull;
        pose = ActPose.stoop;
        label = '$source gereği su taşıyor';
      case GovernanceBeatKind.fieldDuty:
        if (_farmTiles.isNotEmpty) {
          final f = _farmTiles[_rng.nextInt(_farmTiles.length)];
          target = (f.col.toDouble(), f.row.toDouble());
        }
        prop = PropKind.scythe;
        pose = ActPose.labor;
        label = '$source gereği tarlayı denetliyor';
      case GovernanceBeatKind.marketDuty:
        useBuilding([BuildingType.market, BuildingType.caravanserai]);
        prop = PropKind.basket;
        label = '$source gereği pazarda hesap görüyor';
      case GovernanceBeatKind.homeDuty:
        final home = actor.homeBuilding;
        if (home is BuildingEntity) {
          target = _standSpotFor(home, actor) ?? _centerOf(home);
        }
        prop = PropKind.bread;
        label = '$source gereği hanesine dönüyor';
      case GovernanceBeatKind.worshipDuty:
        useBuilding([BuildingType.church, BuildingType.shrine]);
        pose = ActPose.kneel;
        label = '$source gereği ibadet ediyor';
      case GovernanceBeatKind.watchDuty:
        target = _villageEdgePoint();
        prop = PropKind.torch;
        label = '$source gereği sınır nöbeti tutuyor';
      case GovernanceBeatKind.fireDuty:
        if (_firepitBuilding != null) target = _centerOf(_firepitBuilding!);
        prop = PropKind.firewood;
        pose = ActPose.stoop;
        label = '$source gereği ocağı besliyor';
      case GovernanceBeatKind.herdDuty:
        useBuilding([BuildingType.barn, BuildingType.stable]);
        prop = PropKind.scythe;
        label = '$source gereği sürüyü sayıyor';
      case GovernanceBeatKind.treeDuty:
        if (_trees.isNotEmpty) {
          final tree = _trees[_rng.nextInt(_trees.length)];
          target =
              _ringSpot(tree.col, tree.row, 1, 1, actor) ??
              (tree.col.toDouble(), tree.row.toDouble());
        } else {
          target = _villageEdgePoint();
        }
        prop = PropKind.axe;
        pose = ActPose.labor;
        label = '$source gereği fidan yerini hazırlıyor';
      case GovernanceBeatKind.councilDuty:
        useBuilding([BuildingType.townhall, BuildingType.firepit]);
        prop = PropKind.sack;
        label = '$source gereği meclise kayıt götürüyor';
      case GovernanceBeatKind.warehouseDuty:
        useBuilding([BuildingType.warehouse, BuildingType.market]);
        prop = PropKind.sack;
        pose = ActPose.stoop;
        label = '$source gereği ambar payını taşıyor';
      case GovernanceBeatKind.apprenticeDuty:
        useBuilding([
          BuildingType.tailor,
          BuildingType.lumberCamp,
          BuildingType.mill,
        ]);
        prop = PropKind.axe;
        pose = ActPose.labor;
        label = '$source gereği çıraklık ediyor';
      case GovernanceBeatKind.shelterDuty:
        final home = actor.homeBuilding;
        if (home is BuildingEntity) {
          target = _standSpotFor(home, actor) ?? _centerOf(home);
        }
        pose = ActPose.slump;
        label = '$source yüzünden hanesine çekiliyor';
      case GovernanceBeatKind.careDuty:
        VillagerEntity? cared;
        for (final v in _villagers) {
          if (v.isDying || identical(v, actor)) continue;
          if (v.sickDays > 0 ||
              v.injuryDays > 0 ||
              v.lifeStage == LifeStage.elder) {
            cared = v;
            break;
          }
        }
        if (cared != null) target = (cared.gridX, cared.gridY);
        prop = PropKind.bread;
        pose = ActPose.kneel;
        label = '$source gereği düşkünü gözetiyor';
      case GovernanceBeatKind.repairDuty:
        useBuilding([
          BuildingType.woodenHouse,
          BuildingType.tent,
          BuildingType.warehouse,
        ]);
        prop = PropKind.axe;
        pose = ActPose.labor;
        label = '$source gereği hasarı onarıyor';
      case GovernanceBeatKind.celebration:
        if (_firepitBuilding != null) target = _centerOf(_firepitBuilding!);
        prop = PropKind.mug;
        pose = ActPose.sip;
        label = '$source için kutlama yapıyor';
    }

    final spot = _freeSpotNear(target.$1, target.$2, 1.7) ?? target;
    _prepForScene(actor);
    actor.mind.impose(
      IntentKind.errand,
      '$source gereği: ${label.split(':').last}',
      priority: IntentPriority.need,
    );
    actor.act = Act(label, [
      ActStep.goTo(spot.$1, spot.$2),
      ActStep.face(target.$1, target.$2),
      ActStep.take(prop),
      ActStep.work(4.0 + _rng.nextDouble() * 3.0, pose: pose),
      const ActStep.put(),
    ]);
    actor.feel(
      kind == GovernanceBeatKind.shelterDuty
          ? NpcEmotion.fear
          : NpcEmotion.wonder,
      3.0,
    );
    return true;
  }

  VillagerEntity? _governanceActor({
    VillagerEntity? preferred,
    String? name,
    VillagerEntity? excluding,
  }) {
    bool suitable(VillagerEntity v) =>
        !identical(v, excluding) &&
        !v.isDying &&
        !v.isLeaving &&
        !v.isSleeping &&
        !v.isInsideBuilding &&
        v.canRunErrands &&
        v.act == null &&
        !v.isCarrying &&
        v.mind.intent.priority < IntentPriority.committed;

    if (preferred != null && suitable(preferred)) return preferred;
    if (name != null) {
      for (final v in _villagers) {
        if (v.name == name && suitable(v)) return v;
      }
    }
    final pool = _villagers.where(suitable).toList();
    if (pool.isEmpty) return null;
    return pool[_rng.nextInt(pool.length)];
  }
}
