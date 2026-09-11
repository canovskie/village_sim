part of '../../main.dart';

extension _SceneDecisionCustoms on _VillageSceneState {
  double _hearthPriority(VillagerEntity v) => DecisionCustoms.hearthPriority(
    _villageMemory,
    elder: v.lifeStage == LifeStage.elder,
    chill: v.mind.drive(Drive.chill),
  );

  bool _hasCookingTurn(VillagerEntity v) {
    if (!_villageMemory.contains('oven.rotation') &&
        !_villageMemory.contains('oven.early')) {
      return true;
    }
    final fire = _firepitBuilding;
    if (fire == null) return true;
    final center = _centerOf(fire);
    final cooks =
        _villagers
            .where(
              (c) =>
                  c.job?.role == JobRole.cook &&
                  c.canRunErrands &&
                  !c.isDying &&
                  !c.isLeaving &&
                  !c.isSleeping &&
                  !c.isInsideBuilding,
            )
            .toList()
          ..sort(
            (a, b) => _wdist(
              a.gridX,
              a.gridY,
              center.$1,
              center.$2,
            ).compareTo(_wdist(b.gridX, b.gridY, center.$1, center.$2)),
          );
    // Devam eden pişirim kesilmez; yeni gelen mevcut sırayı gasp edemez.
    if (cooks.any((c) => !identical(c, v) && c.job!.phase > 0)) return false;
    final house = _decisionCustoms.cookingHouse(
      _villageMemory,
      _dayCount,
      cooks.map((c) => c.surname).toList(),
    );
    return house == null || house == v.surname;
  }

  void _tickDecisionCustoms(double dt) {
    final tod = _cycle.timeOfDay;
    final music = DecisionCustoms.musicAllowed(_villageMemory, tod);
    if (!music) {
      for (final v in _villagers) {
        if ((v.activity == VillagerActivity.music ||
                v.activity == VillagerActivity.dance) &&
            v.mind.intent.priority < IntentPriority.ceremony) {
          v.activity = VillagerActivity.none;
          v.chatBubbleTime = 0;
          v.chatBubbleIcon = '';
          v.mind.clear();
        }
      }
    }
    final bell = DecisionCustoms.bellWorn(_villageMemory, tod);
    final barns = <(int, int)>{};
    for (final animal in _cows) {
      animal.wearsBell =
          bell &&
          animal.kind != AnimalKind.chicken &&
          !animal.isDying &&
          barns.add((animal.barnCol, animal.barnRow));
    }
    // Gece çanı yakındaki uykunun verimini düşürür; gündüz çıkarılan çan
    // aynı sürü görünürlüğünü gece yorgunluğu olmadan korur.
    if (bell && (tod < 0.25 || tod >= 0.75)) {
      for (final v in _villagers) {
        if (v.isSleeping &&
            _cows.any(
              (a) =>
                  a.wearsBell &&
                  a.isWalking &&
                  _wdist(a.gridX, a.gridY, v.gridX, v.gridY) < 5,
            )) {
          v.energy = (v.energy - dt / kGameDaySeconds * 0.25).clamp(0.0, 1.0);
        }
      }
    }
    if (_time < _decisionCustoms.nextPatrolSim) return;
    final paid = _villageMemory.contains('crime.patrol');
    final watch = _villageMemory.contains('crime.watch');
    if (!paid && !watch) return;
    if (!paid && tod >= 0.25 && tod < 0.75) return;
    _decisionCustoms.nextPatrolSim =
        _time + kGameDaySeconds * (paid ? 0.15 : 0.25);
    final actor = paid
        ? _awakeGuards()
              .where(
                (v) =>
                    v.act == null &&
                    !v.isLeaving &&
                    !v.isCarrying &&
                    v.activity == VillagerActivity.none &&
                    v.canRunErrands &&
                    v.mind.intent.priority < IntentPriority.committed,
              )
              .firstOrNull
        : _governanceActor();
    if (actor == null) return;
    if (_stageGovernanceBeat(
          GovernanceBeatKind.watchDuty,
          paid ? 'Takviyeli devriye' : 'Gece nöbeti',
          actorOverride: actor,
        ) &&
        !paid) {
      actor.energy = (actor.energy - 0.03).clamp(0.0, 1.0);
    }
  }
}
