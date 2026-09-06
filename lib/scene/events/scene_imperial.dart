part of '../../main.dart';

/// İmparatorluk (dış tehdit) — vergici askerî heyet KOŞULLU olarak gelir
/// (köy zenginleştikçe/büyüdükçe dikkat çeker; fakir köy genelde es geçilir).
/// Talep: altın vergisi / yiyecek / kereste / genç devşirme. Pazarlık veya
/// fidye ile anlaşmak HER ZAMAN daha avantajlı; reddedersen kan dökülür
/// (favoriler dahil köylüler öldürülebilir). [_imperialFavor] (İmparatorlukla
/// ilişki) pazarlık şansını + talebin sertliğini + ziyaret sıklığını belirler.
///
/// Tam döngü: harita kenarından formasyonla YAKLAŞMA (sim akar, oyuncu kolonu
/// görür) → eşikte PARLEY (talep modalı, sim durur; geliş sinematiği yalnız
/// ton değiştiren ziyaretlerde — bkz. _startImperialParley merdiveni) → karara
/// göre RAIDING (merkeze dalış + görünür darbe) ya da doğrudan LEAVING. Fiziksel
/// asker NPC'leri ([ImperialSoldier]) + geliş sinematiği + zümre nabzındaki
/// dış-güç madalyonu bağlı. Dev panelden [_devSummonImperial] ile anında tetiklenir.
extension _SceneImperial on _VillageSceneState {
  static const int _kMinPop = 8; // bu nüfusun altında ilgilenmez
  static const double _kProsperityGate =
      55.0; // bunun altı "fakir köy" → es geç

  /// Köyün refah skoru — İmparatorluğun iştahını belirler.
  double _prosperity() =>
      _stockpile.gold * 1.0 +
      _stockpile.food * 0.35 +
      _stockpile.wood * 0.2 +
      _villagers.length * 4.0 +
      _buildings.length * 2.5;

  void _tickImperial(double dt) {
    if (kProbeNoImperial) return; // prova: heyet yok (bkz. kProbeNoEvents)
    // Fiziksel heyet sahnedeyse formasyonu yürüt (yaklaşma/ayrılış). Pazarlıkta
    // sim zaten duraklı olduğundan buraya dt gelmez.
    if (_imperialPhase != ImperialVisitPhase.idle) {
      _tickImperialColumn(dt);
      return;
    }
    if (_imperialDemand != null) return; // güvenlik (parley dışında olmamalı)
    if (!_hasFire || _villagers.length < _kMinPop) return;
    // Rejim köyün GÖRÜNÜRLÜĞÜNÜ büker: mülkçü köy iştah kabartır, ortakçı köy
    // gözden ırak kalır (bkz. scene_regime._imperialAttentionMul).
    final prosp = _prosperity() * _imperialAttentionMul;
    if (prosp < _kProsperityGate) {
      // Fakir/küçük köy — gözden uzak. Sayaç yavaş işler, baskı yok.
      _imperialTimer -= dt * 0.3;
      if (_imperialTimer < 0) _imperialTimer = 0.5 * kGameDaySeconds;
      return;
    }
    _imperialTimer -= dt;
    if (_imperialTimer > 0) return;
    _beginImperialApproach(prosp);
  }

  /// DEV: İmparatorluk heyetini anında sahneye çağır (refah/nüfus/sayaç geçitlerini
  /// atlar). Zaten bir ziyaret sürüyorsa yok sayar; boş köye gelmez (yürüyüş için
  /// köy merkezi/kara gerekli). Refahı en az geçit seviyesine yuvarlar ki talep
  /// üretilebilsin.
  void _devSummonImperial() {
    if (_imperialPhase != ImperialVisitPhase.idle || _imperialDemand != null) {
      _showNotification('İmparatorluk heyeti zaten yolda.');
      return;
    }
    if (_villagers.isEmpty || !_hasFire) {
      _showNotification('Önce köylü + ateş gerek (heyet boş köye gelmez).');
      return;
    }
    _beginImperialApproach(max(_prosperity(), _kProsperityGate));
  }

  // ── Formasyon / yürüyüş ─────────────────────────────────────────────────────

  /// Çapanın hareket hızı (tile/sim-sn) — köylü yürüyüş tempisine yakın, ağır
  /// heyet hissi için biraz ağırbaşlı.
  static const double _kMarchSpeed = 1.3;

  /// Yağma dalışı hızı (tile/sim-sn) — yürüyüşten belirgin hızlı (saldırı).
  static const double _kRaidSpeed = 2.4;

  /// Grup boyu köyün büyüklüğüne göre — küçük köye ufak müfreze, büyük/zengin
  /// köye kalabalık heyet. Komutan + askerler.
  int _imperialGroupSize() =>
      (3 +
              _villagers.length ~/ 6 +
              _buildings.length ~/ 8 +
              (_imperialRaidScenario?.groupBonus ?? 0))
          .clamp(3, 14);

  ImperialRaidContext _imperialRaidContext() => ImperialRaidContext(
    year: yearOf(_dayCount),
    population: _villagers.length,
    favor: _imperialFavor,
    isNight: _cycle.dayLight < .35,
    raining: _cycle.rainIntensity > .35,
    season: _season,
    hasWarehouse: _buildings.any((b) => b.type == BuildingType.warehouse),
    hasMarket: _buildings.any((b) => b.type == BuildingType.market),
    hasTownHall: _buildings.any((b) => b.type == BuildingType.townhall),
    hasChurch: _buildings.any((b) => b.type == BuildingType.church),
    hasManor: _buildings.any((b) => b.type == BuildingType.manor),
    hasStable: _buildings.any((b) => b.type == BuildingType.stable),
    hasLumberCamp: _buildings.any((b) => b.type == BuildingType.lumberCamp),
  );

  /// i. askerin formasyondaki ofseti: (geri, yan) tile. Komutan (0) en önde-orta;
  /// gerisi 3'erli saflar halinde dizilir.
  (double, double) _formationOffset(int i) {
    if (i == 0) return (0.0, 0.0);
    final row = (i - 1) ~/ 3;
    final col = (i - 1) % 3;
    final side = (col - 1) * 0.9; // -0.9 / 0 / +0.9
    final back = 1.1 + row * 1.0; // ilk saf 1.1 geride
    return (back, side);
  }

  void _setMarchDir(double dx, double dy) {
    final len = sqrt(dx * dx + dy * dy);
    if (len > 1e-4) {
      _impDirX = dx / len;
      _impDirY = dy / len;
    }
  }

  /// Kolonun köyün GÖRÜNÜR sınırından inmesi için giriş + pazarlık noktalarını
  /// üretir. Reveal modelinde kamera reach dışını (harita köşeleri) HİÇ göstermez;
  /// eski "harita köşesinden yürü" yolu kolonu sisde görünmez bırakıyordu. Kolon
  /// artık merkeze göre seçili bir yönde, reach kenarına yakın bir eşiğe iner:
  ///  - giriş (entry)  : görünür sınırın hemen dibinde (kolon buradan kadraja girer)
  ///  - parley         : köyle sınır arasında, net görünür bir eşik
  /// Yön seede bağlı (ziyaretler hep aynı köşeden gelmesin). Dönüş:
  /// (entryCol, entryRow, parleyCol, parleyRow).
  (double, double, double, double) _imperialFrontierPoints() {
    final (cx, cy) = _villageCenter();
    final cxd = cx.toDouble(), cyd = cy.toDouble();
    // Tile-uzayı birim yönler — köyün üst yarısından (kuzey/kuzeybatı/kuzeydoğu/batı)
    // iner (alt-sağdan gezgin tüccar geldiğinden çakışmasın).
    const dirs = <(double, double)>[
      (0.0, -1.0), // kuzey (ekranda yukarı)
      (-0.7, -0.7), // kuzeybatı
      (0.7, -0.7), // kuzeydoğu
      (-1.0, 0.0), // batı
    ];
    var (dc, dr) = dirs[_impSeed(5) % dirs.length];
    final dl = sqrt(dc * dc + dr * dr);
    dc /= dl;
    dr /= dl;
    // Bu yönde reach kenarına kadarki tile mesafesi (görünür sınır). Reach ekran
    // eksenlerinde (u=c-r, v=c+r) tanımlı → yönün (du,dv) izdüşümüyle sınır bulunur.
    double tMax;
    final sz = _viewSize;
    if (sz.width > 0 && sz.height > 0) {
      final (hu, hv) = _reachHalfExtents(sz);
      final du = (dc - dr).abs();
      final dv = (dc + dr).abs();
      final tu = du > 1e-4 ? hu / du : 1e9;
      final tv = dv > 1e-4 ? hv / dv : 1e9;
      tMax = min(tu, tv);
    } else {
      tMax = 22.0; // görünüm henüz hazır değil — makul sabit
    }
    tMax = tMax.clamp(10.0, 34.0);
    final (px, py) = _battleGround(
      cxd + dc * tMax * 0.45,
      cyd + dr * tMax * 0.45,
    );
    final (ex, ey) = _nearestLand(
      cxd + dc * tMax * 0.92,
      cyd + dr * tMax * 0.92,
    );
    return (ex, ey, px, py);
  }

  /// Heyet ziyaretini başlatır: askerleri harita kenarında formasyonda spawn
  /// edip köy eşiğine (pazarlık noktası) doğru yürütür. Sim DURMAZ — oyuncu
  /// yaklaşan kolonu görür; eşiğe varınca pazarlık (modal) açılır.
  void _beginImperialApproach(double prosp) {
    _impProsperity = prosp;
    _imperialRaidScenario = selectImperialRaidScenario(
      _imperialRaidContext(),
      _impSeed(81) + _imperialVisits * 37,
    );
    final groupSize = _imperialGroupSize();

    // Giriş + pazarlık noktaları köyün GÖRÜNÜR sınırından (reach kenarı) türer —
    // harita köşesi (2,2) reveal modelinde kadraja hiç girmediğinden oradan
    // yürütmek "hiçbir şey olmadı" hissi veriyordu (kolon ~40 tile boyunca sisde
    // görünmez yürüyordu). Artık kolon görünür frontier'dan iner.
    final (ex, ey, px, py) = _imperialFrontierPoints();
    _impExitCol = ex;
    _impExitRow = ey;
    _impParleyCol = px;
    _impParleyRow = py;

    // Çapa girişte; yürüyüş yönü parley'e doğru.
    _impAnchorCol = ex;
    _impAnchorRow = ey;
    _setMarchDir(px - ex, py - ey);
    final perpX = -_impDirY, perpY = _impDirX;

    _soldiers.clear();
    for (int i = 0; i < groupSize; i++) {
      final (back, side) = _formationOffset(i);
      final sx = ex - _impDirX * back + perpX * side;
      final sy = ey - _impDirY * back + perpY * side;
      _soldiers.add(
        ImperialSoldier(
          startCol: sx,
          startRow: sy,
          commander: i == 0,
          backOffset: back,
          sideOffset: side,
          seed: 9001 + i * 137,
        ),
      );
    }

    _imperialPhase = ImperialVisitPhase.approaching;
    // Kalabalık ordu yürüyüşü + sert kamera sarsıntısı → gerginlik.
    AudioManager.instance.playSfx(Sfx.imperialMarch);
    addCameraShake(11.0, dur: 0.7);
    // Küçük toast yerine tam-ekran gergin anons. Voice metni alt satır olur.
    final raid = _imperialRaidScenario!;
    _imperialAlertRaid = raid.title.toUpperCase();
    _imperialAlertSub = '${raid.omen} Hedef: ${raid.target.label}.';
    _imperialAlertLeft = _VillageSceneState._kImperialAlertDur;
  }

  /// İmparatorluk metinleri için kararlı tohum — gün + tuz. Aynı gün aynı
  /// cümle çıkar (kayıt/yükleme ya da yeniden çizim metni değiştirmez).
  int _impSeed(int salt) => _stableSeed('imperial$salt', _dayCount);

  /// Heyetin ağzının bağlamı. Komutan için burası "köy" değil, deftere yazılı
  /// bir YER ADIDIR — bu yüzden imparatorluk metinleri `{köy}` yer tutucusunu
  /// kullanır ve ad ekranda vergiciyle birlikte geçer (bkz. scene_voice).
  VoiceCtx _impVoice(int salt) => _voice(null, seed: _impSeed(salt));

  /// Aktif heyet evre makinesi — her tick (approaching/leaving) çağrılır.
  void _tickImperialColumn(double dt) {
    final npcDt = dt * _fxNpcSpeedMul;
    switch (_imperialPhase) {
      case ImperialVisitPhase.approaching:
        _advanceColumn(npcDt, _impParleyCol, _impParleyRow);
        final dx = _impParleyCol - _impAnchorCol;
        final dy = _impParleyRow - _impAnchorRow;
        if (sqrt(dx * dx + dy * dy) < 0.4) _startImperialParley();
      case ImperialVisitPhase.raiding:
        _tickImperialRaid(dt, npcDt);
      case ImperialVisitPhase.clashing:
        _tickImperialClash(dt);
      case ImperialVisitPhase.leaving:
        _advanceColumn(npcDt, _impExitCol, _impExitRow);
        final dx = _impExitCol - _impAnchorCol;
        final dy = _impExitRow - _impAnchorRow;
        if (sqrt(dx * dx + dy * dy) < 0.5) {
          for (final s in _soldiers) {
            s.finished = true;
          }
          _soldiers.clear();
          _imperialPhase = ImperialVisitPhase.idle;
          _imperialTimer = _rollImperialInterval(_impProsperity);
        }
      case ImperialVisitPhase.parley:
        _holdFormation(npcDt); // modal açık (sim duraklı) — güvenlik amaçlı
      case ImperialVisitPhase.idle:
        break;
    }
  }

  /// The routed front opens a path to the actual raid target. No contact, no building damage.
  void _tickImperialRaid(double dt, double npcDt) {
    _stepAnchor(npcDt, _impRaidCol, _impRaidRow, _kRaidSpeed);
    _chargeSoldiers(npcDt, _impRaidCol, _impRaidRow);
    final reached = _soldiers.any(
      (s) =>
          _wdist(s.gridX, s.gridY, _impRaidCol, _impRaidRow) < 1.4 &&
          _battleClearLine(s.gridX, s.gridY, _impRaidCol, _impRaidRow),
    );
    if (!_impStruck) {
      _impRaidTimer -= dt;
      if (_impRaidTimer <= 0 && !reached) {
        for (final s in _soldiers) {
          s.imperialAttacking = false;
        }
        _imperialPhase = ImperialVisitPhase.leaving;
        _setMarchDir(_impExitCol - _impAnchorCol, _impExitRow - _impAnchorRow);
        return;
      }
      if (reached) {
        _strikeRaidTarget();
        _impStruck = true;
        _impRaidTimer = 0.9; // darbe sonrası kısa bekleyiş
      }
    } else {
      _impRaidTimer -= dt;
      if (_impRaidTimer <= 0) {
        // Saldırı bitti — çekilirken normal yürüyüş pozu (mızrak dik).
        for (final s in _soldiers) {
          s.imperialAttacking = false;
        }
        _imperialPhase = ImperialVisitPhase.leaving;
        _setMarchDir(_impExitCol - _impAnchorCol, _impExitRow - _impAnchorRow);
      }
    }
  }

  void _tickImperialClash(double dt) {
    final battle = _imperialBattle;
    if (battle == null) return;
    final previous = {for (final f in battle.fighters) f.id: (f.x, f.y)};
    if (battle.result != null) {
      _battleAftermath -= dt;
      for (final f in battle.fighters) {
        if (f.health <= 0) f.downTime += dt;
        final retreating =
            f.action == BattleAction.fleeing ||
            (f.side == BattleSide.empire && _imperialBattleWon);
        if (retreating && f.health > 0) f.action = BattleAction.fleeing;
        f.body.planted = !retreating || f.health <= 0;
        final target = retreating
            ? (
                f.side == BattleSide.empire ? _impExitCol : battle.objectiveX,
                f.side == BattleSide.empire ? _impExitRow : battle.objectiveY,
              )
            : (f.x, f.y);
        final goal = _battleWaypoint(f, target.$1, target.$2);
        f.body.advance(
          dt,
          goal.$1,
          goal.$2,
          retreating && f.health > 0 ? f.speed : 0,
          clearPath: _battleClearLine,
        );
      }
      NpcBody.solveContacts(
        battle.fighters.map((f) => f.body).toList(),
        dt,
        clearPath: _battleClearLine,
      );
      _syncBattleActors(dt, previous);
      if (_battleAftermath > 0) return;
      _clearImperialEngagements();
      if (!_imperialBattleWon) {
        _beginImperialRaid();
      } else {
        _imperialPhase = ImperialVisitPhase.leaving;
        _setMarchDir(_impExitCol - _impAnchorCol, _impExitRow - _impAnchorRow);
      }
      setStateHere(() {});
      return;
    }
    _battleSoundLeft = max(0, _battleSoundLeft - dt);
    battle.tick(dt, waypoint: _battleWaypoint, clearLine: _battleClearLine);
    kProbeImperialBattleHits = battle.hits;
    _syncBattleActors(dt, previous);
    for (final hit in battle.impacts) {
      kProbeImperialCombatContactSeen = true;
      if (!hit.blocked) {
        final v = _battleActors[hit.defender.id]!;
        v.injuryDays = max(
          v.injuryDays,
          (1 - hit.defender.health / hit.defender.maxHealth) * 4,
        );
      }
    }
    if (battle.impacts.isNotEmpty) {
      addCameraShake(2.2, dur: .12);
      if (_battleSoundLeft <= 0) {
        AudioManager.instance.playSfx(Sfx.fightScuffle);
        _battleSoundLeft = .4;
      }
    }
    // Civilians flee from nearby soldiers using the same world pathfinding.
    final (cx, cy) = _villageCenterD();
    for (final v in _battleCivilians) {
      final threatened = battle.fighters.any(
        (f) =>
            f.side == BattleSide.empire &&
            f.active &&
            f.distance(v.gridX, v.gridY) < 6,
      );
      if (!threatened) {
        v.animateExternalMotion(dt, v.gridX, v.gridY);
        continue;
      }
      final (tx, ty) = _nearestLand(cx - _impDirX * 4, cy - _impDirY * 4);
      final fromX = v.gridX, fromY = v.gridY;
      v.moveTowards(tx, ty, dt, speedScale: 1.4);
      v.animateExternalMotion(dt, fromX, fromY);
    }
    final engaged = battle.fighters
        .where(
          (f) =>
              f.active &&
              f.target != null &&
              f.distanceTo(
                    battle.fighters.firstWhere((b) => b.id == f.target),
                  ) <
                  2.5,
        )
        .toList();
    if (engaged.isNotEmpty) {
      _watchX = engaged.fold(0.0, (n, f) => n + f.x) / engaged.length;
      _watchY = engaged.fold(0.0, (n, f) => n + f.y) / engaged.length;
    }
    _watchLeft = 2;
    if (battle.result != null) _settleImperialBattle();
  }

  bool _battleClearLine(double ax, double ay, double bx, double by) {
    final steps = max(1, (sqrt(pow(bx - ax, 2) + pow(by - ay, 2)) * 5).ceil());
    for (var i = 1; i <= steps; i++) {
      final x = ax + (bx - ax) * i / steps;
      final y = ay + (by - ay) * i / steps;
      if (x < 0 || y < 0 || x >= kCols || y >= kRows) return false;
      if (_pathContext.blocked(x.floor(), y.floor())) return false;
    }
    return true;
  }

  (double, double) _battleWaypoint(BattleFighter f, double x, double y) {
    final v = _battleActors[f.id]!;
    v.gridX = f.x;
    v.gridY = f.y;
    return v.navigationWaypoint(
      x,
      y,
      forcePath: !_battleClearLine(f.x, f.y, x, y),
    );
  }

  void _syncBattleActors(double dt, Map<int, (double, double)> previous) {
    final battle = _imperialBattle!;
    for (final f in battle.fighters) {
      final v = _battleActors[f.id]!;
      v.gridX = f.x;
      v.gridY = f.y;
      v.imperialAttacking =
          f.action == BattleAction.windingUp ||
          f.action == BattleAction.striking;
      v.imperialHit = f.action == BattleAction.recoiling;
      v.battleSwing = f.swing;
      v.battleFall = (f.downTime / .65).clamp(0, 1);
      v.battleHealth = (f.health / f.maxHealth).clamp(0, 1);
      v.battleResolve = f.resolve;
      v.actPose = null;
      final target = _battleActors[f.target];
      final stepping =
          f.action == BattleAction.advancing ||
          f.action == BattleAction.fleeing;
      if (!stepping && target != null) {
        v.lookToward(target.gridX, target.gridY);
      } else if (f.body.speed > .02) {
        v.lookToward(f.x + f.body.vx, f.y + f.body.vy);
      }
      final from = previous[f.id]!;
      v.animateExternalMotion(
        dt,
        from.$1,
        from.$2,
        stepping: stepping,
        watchTarget: true,
        actualSpeed: f.body.speed,
      );
      v.tickTorch(dt, _cycle.dayLight, _cycle.rainIntensity);
    }
  }

  (double, double) _battleGround(double x, double y) {
    final c = x.floor(), r = y.floor();
    for (var radius = 0; radius < 16; radius++) {
      (double, double)? best;
      var distance = double.infinity;
      for (var dx = -radius; dx <= radius; dx++) {
        for (var dy = -radius; dy <= radius; dy++) {
          final col = c + dx, row = r + dy;
          if (col < 0 ||
              row < 0 ||
              col >= kCols ||
              row >= kRows ||
              _pathContext.blocked(col, row) ||
              _wilderness.contains((col, row))) {
            continue;
          }
          final d = pow(col + .5 - x, 2) + pow(row + .5 - y, 2);
          if (d < distance) {
            distance = d.toDouble();
            best = (col + .5, row + .5);
          }
        }
      }
      if (best != null) return best;
    }
    return _nearestLand(x, y);
  }

  void _prepareImperialEngagements() {
    _releaseVignette();
    _clearImperialEngagements();
    final raid = _imperialRaidScenario;
    _imperialRaidTargetBuilding = _raidTargetBuilding(raid?.target);
    final (ox, oy) = _raidTargetPoint(raid?.target);
    final (tx, ty) = _battleGround(ox, oy);
    final (cx, cy) = _villageCenterD();
    _setMarchDir(cx - _impAnchorCol, cy - _impAnchorRow);
    final available =
        _villagers
            .where(
              (v) =>
                  !v.isDying &&
                  !v.isLeaving &&
                  v.lifeStage != LifeStage.child &&
                  !v.isInsideBuilding &&
                  !v.isSleeping &&
                  v.sickDays <= 0 &&
                  v.injuryDays < 3,
            )
            .toList()
          ..sort((a, b) {
            final guard = (a.type == VillagerType.guard ? 0 : 1).compareTo(
              b.type == VillagerType.guard ? 0 : 1,
            );
            return guard != 0
                ? guard
                : _wdist(
                    a.gridX,
                    a.gridY,
                    tx,
                    ty,
                  ).compareTo(_wdist(b.gridX, b.gridY, tx, ty));
          });
    final defenders = available
        .take(min(18, max(3, _soldiers.length + _guardCount())))
        .toList();
    final fighters = <BattleFighter>[];
    var weapons = _stockpile.weapons;
    for (final v in defenders) {
      final i = fighters.length;
      final guard = v.type == VillagerType.guard;
      final armed = guard || weapons > 0;
      if (!guard && armed) weapons--;
      _prepForScene(v);
      v.state = VillagerState.idle;
      v.prop = guard
          ? PropKind.none
          : (v.type == VillagerType.farmer ? PropKind.scythe : PropKind.axe);
      v.feel(NpcEmotion.anger, 8);
      // Positions are destinations, never teleports. Late defenders must run
      // from their actual workplace before they can contribute a strike.
      final lateral = ((i % 5) - 2) * 1.1;
      final (px, py) = _battleGround(
        _impAnchorCol + _impDirX * (3.5 + i ~/ 5) - _impDirY * lateral,
        _impAnchorRow + _impDirY * (3.5 + i ~/ 5) + _impDirX * lateral,
      );
      if (_imperialDefensePlan == ImperialDefensePlan.barricade && i < 5) {
        v.battlePost = (px - _impDirX * .6, py - _impDirY * .6);
      }
      _battleActors[i] = v;
      fighters.add(
        BattleFighter(
          id: i,
          side: BattleSide.village,
          name: v.name,
          x: v.gridX,
          y: v.gridY,
          postX: px,
          postY: py,
          maxHealth: (guard ? 115 : 85) * (1 - v.injuryDays * .15).clamp(.4, 1),
          power:
              (armed ? 23 : 14) *
              (1 + _imperialPosture.resistBonus + _faithEffect.resistBonus),
          armor: guard ? .24 : (armed ? .12 : .04),
          reach: armed ? 1.15 : .95,
          resolve: (.4 + v.morale * .5).clamp(.2, .95),
          speed: v.disabled ? 1.0 : 1.5,
        ),
      );
    }
    for (final s in _soldiers) {
      final i = fighters.length;
      _battleActors[i] = s;
      fighters.add(
        BattleFighter(
          id: i,
          side: BattleSide.empire,
          name: s.name,
          x: s.gridX,
          y: s.gridY,
          postX: s.gridX,
          postY: s.gridY,
          maxHealth: s.commander ? 125 : 100,
          power: (s.commander ? 24 : 19) * (1 + (raid?.attackDelta ?? 0)),
          armor: .22,
          reach: 1.2,
          resolve: s.commander ? .95 : .8,
          commander: s.commander,
        ),
      );
    }
    _battleCivilians.addAll(
      _villagers.where(
        (v) =>
            !defenders.contains(v) &&
            !v.isDying &&
            !v.isInsideBuilding &&
            !v.isSleeping,
      ),
    );
    for (final v in _battleCivilians) {
      _prepForScene(v);
    }
    _imperialBattle = ImperialBattle(
      fighters: fighters,
      plan: _imperialDefensePlan,
      objectiveX: tx,
      objectiveY: ty,
      exitX: _impExitCol,
      exitY: _impExitRow,
      rain: _cycle.rainIntensity,
      darkness: 1 - _cycle.dayLight,
      seed: _impSeed(91),
    );
    _followedVillager = null;
    _watchX = _impAnchorCol + _impDirX * 2;
    _watchY = _impAnchorRow + _impDirY * 2;
    _watchLeft = 90;
    _battlePreviousZoom = _zoom;
    _zoom = max(_zoom, _viewSize.shortestSide < 500 ? 2.0 : 2.35);
    kProbeImperialBattleActive = true;
    kProbeImperialBattleActorsReleased = false;
    kProbeImperialBattleHits = 0;
    kProbeImperialBattleResult = '';
    kProbeImperialCombatPairs = defenders.length;
    kProbeImperialCombatContactSeen = false;
  }

  void _settleImperialBattle() {
    final battle = _imperialBattle!;
    final d = _battleDemand!;
    _imperialBattleWon = battle.result == BattleResult.held;
    _battleAftermath = 2.5;
    kProbeImperialBattleResult = battle.result!.name;
    var wounded = 0;
    var fallen = 0;
    for (final f in battle.fighters) {
      final v = _battleActors[f.id]!;
      if (f.side == BattleSide.village && f.health < f.maxHealth) {
        if (f.health <= 0 && !v.isFavorite) {
          fallen++;
        } else {
          wounded++;
        }
      }
      v.imperialAttacking = false;
      v.imperialHit = false;
    }
    // Losses belong to the people who actually took blows. No off-screen
    // victim lottery; surviving civilians are never killed by this result.
    _imperialFavor = (_imperialFavor - (_imperialBattleWon ? .15 : .25)).clamp(
      0,
      1,
    );
    if (_imperialBattleWon) {
      _feelVillage(NpcEmotion.joy, 12, .14);
      pushPolicyMorale(.08, 4);
      _unrest = (_unrest - .14).clamp(0, 1);
      _stockpile.weapons += battle.fighters
          .where((f) => f.side == BattleSide.empire && f.health <= 0)
          .length;
    } else {
      if (!d.isConscript) {
        _spendResource(
          d.kind,
          (d.amount * .6 * (_imperialRaidScenario?.lootMultiplier ?? 1))
              .round(),
        );
      }
      _feelVillage(NpcEmotion.fear, 16, -.22);
      pushPolicyMorale(-.15, 6);
      _imperialInternalToll(d, 1, raid: true);
    }
    final message =
        '${battle.report} $wounded savunucu yaralandı.${fallen > 0 ? ' $fallen savunucu hayatını kaybetti.' : ''}';
    _chronicle(
      message,
      icon: _imperialBattleWon ? '🛡️' : '⚔️',
      milestone: true,
      kind: _imperialBattleWon ? ChronicleKind.decision : ChronicleKind.crisis,
    );
    _showNotification(message);
  }

  void _clearImperialEngagements({bool applyLosses = true}) {
    for (final v in [..._battleActors.values, ..._battleCivilians]) {
      v.imperialAttacking = false;
      v.imperialHit = false;
      v.battleHealth = null;
      v.battleSwing = null;
      v.battleFall = 0;
      v.battleResolve = null;
      v.battlePost = null;
      v.actPose = null;
      v.prop = PropKind.none;
      v.isWalking = false;
      v.state = VillagerState.idle;
      v.targetCol = v.gridX;
      v.targetRow = v.gridY;
    }
    // Incapacitated soldiers do not stand up and rejoin the marching column.
    final battle = _imperialBattle;
    if (battle != null) {
      for (final f in battle.fighters.where(
        (f) => f.side == BattleSide.empire && f.health <= 0,
      )) {
        _soldiers.remove(_battleActors[f.id]);
      }
    }
    if (battle != null && applyLosses) {
      for (final f in battle.fighters.where(
        (f) => f.side == BattleSide.village && f.health <= 0,
      )) {
        final v = _battleActors[f.id]!;
        if (v.isFavorite || v.isDying) continue;
        for (final p in v.parents) {
          p.children.remove(v);
        }
        for (final c in v.children) {
          c.parents.remove(v);
        }
        _markDeathHouse(v);
        v.startDying(funeral: true);
      }
    }
    kProbeImperialBattleActorsReleased = _battleActors.values.every(
      (v) =>
          v.battleHealth == null &&
          v.battleResolve == null &&
          !v.imperialAttacking &&
          !v.imperialHit,
    );
    _battleActors.clear();
    _battleCivilians.clear();
    _imperialBattle = null;
    if (_battlePreviousZoom != null) _zoom = _battlePreviousZoom!;
    _battlePreviousZoom = null;
    kProbeImperialBattleActive = false;
    _watchLeft = 0;
  }

  /// Surviving raiders damage the objective only after reaching it.
  void _strikeRaidTarget() {
    addCameraShake(13.0, dur: 1.0);
    AudioManager.instance.playSfx(Sfx.thunderClap);
    _activeFx.add(
      ActiveFx(
        const EventEffect(screenTint: Color(0x66AA1414), duration: 1.8),
        1.8,
      ),
    );
    final damaged = _imperialRaidTargetBuilding;
    if (damaged != null && _buildings.contains(damaged)) {
      final raid = _imperialRaidScenario;
      final blow = (.18 + (raid?.attackDelta ?? 0) * .7).clamp(.12, .42);
      damaged.damage = (damaged.damage + blow).clamp(0.0, 1.0);
      damaged.deathMarkerUntil = max(damaged.deathMarkerUntil, _time + 18.0);
    }
  }

  /// Çapayı [tx],[ty]'ye [speed] (tile/sim-sn) ile yürütür; başlangıç mesafesini
  /// döndürür (varış tespiti için). Yürüyüş yönünü de günceller.
  double _stepAnchor(double dt, double tx, double ty, double speed) {
    final dx = tx - _impAnchorCol, dy = ty - _impAnchorRow;
    final d = sqrt(dx * dx + dy * dy);
    if (d > 1e-4) {
      _setMarchDir(dx, dy);
      final stepLen = d < speed * dt ? d : speed * dt;
      _impAnchorCol += _impDirX * stepLen;
      _impAnchorRow += _impDirY * stepLen;
    }
    return d;
  }

  /// Çapayı yürütür + askerleri slotlarına çeker (formasyon yürüyüşü).
  void _advanceColumn(double dt, double tx, double ty) {
    _stepAnchor(dt, tx, ty, _kMarchSpeed);
    _moveSoldiersToSlots(dt);
  }

  /// Yağma dalışı — askerler merkez çevresine HIZLA dağılır (kuşatma hissi;
  /// formasyon gevşer, yan açılır). Saldırgan tempo.
  void _chargeSoldiers(double dt, double cx, double cy) {
    final perpX = -_impDirY, perpY = _impDirX;
    for (final s in _soldiers) {
      final tx =
          cx - _impDirX * (s.backOffset * 0.5) + perpX * (s.sideOffset * 1.4);
      final ty =
          cy - _impDirY * (s.backOffset * 0.5) + perpY * (s.sideOffset * 1.4);
      s.stepTo(
        dt,
        tx,
        ty,
        dayLight: _cycle.dayLight,
        rainIntensity: _cycle.rainIntensity,
        speedMul: 1.9,
        arriveD: 0.2,
      );
    }
  }

  /// Her askeri çapaya göre formasyon slotuna yürütür (biraz hızlı → kolon sıkı).
  void _moveSoldiersToSlots(double dt) {
    final perpX = -_impDirY, perpY = _impDirX;
    for (final s in _soldiers) {
      final tx = _impAnchorCol - _impDirX * s.backOffset + perpX * s.sideOffset;
      final ty = _impAnchorRow - _impDirY * s.backOffset + perpY * s.sideOffset;
      s.stepTo(
        dt,
        tx,
        ty,
        dayLight: _cycle.dayLight,
        rainIntensity: _cycle.rainIntensity,
        speedMul: 1.25,
        arriveD: 0.12,
      );
    }
  }

  /// Eşikte dizilip beklerler — slotta durup köy merkezine bakarlar.
  void _holdFormation(double dt) {
    final (cx, cy) = _villageCenter();
    final perpX = -_impDirY, perpY = _impDirX;
    for (final s in _soldiers) {
      final tx = _impAnchorCol - _impDirX * s.backOffset + perpX * s.sideOffset;
      final ty = _impAnchorRow - _impDirY * s.backOffset + perpY * s.sideOffset;
      final arrived = s.stepTo(
        dt,
        tx,
        ty,
        dayLight: _cycle.dayLight,
        rainIntensity: _cycle.rainIntensity,
        arriveD: 0.12,
      );
      if (arrived) s.lookToward(cx.toDouble(), cy.toDouble());
    }
  }

  /// Bir sonraki ziyarete kadar süre — refah arttıkça kısalır, itibar arttıkça
  /// uzar (iyi ilişki = daha seyrek/yumuşak baskı), YIL geçtikçe kısalır.
  ///
  /// Sertleşen tek şey rakam değil nefes payıdır: son yılda heyet neredeyse
  /// iki katı sıklıkta gelir. Rakamı büyütüp aralığı sabit bırakmak, köyün
  /// "bir ziyareti atlatınca uzun süre rahat" ritmini bozmazdı.
  double _rollImperialInterval(double prosp) {
    final wealthRush = (prosp / 240.0).clamp(0.0, 1.0); // 0 sakin → 1 iştahlı
    final base = 5.5 - wealthRush * 2.5 + _imperialFavor * 2.5; // ~3.0–8.0 gün
    final tempo = pressureForDay(_dayCount).imperialTempo; // 1.0 → 0.55
    return (base + _rng.nextDouble() * 1.5) * tempo * kGameDaySeconds;
  }

  /// Heyet köy eşiğine vardı — pazarlığı açar. Talep + sinematik + modal kurulur
  /// (sim DURUR). Fiziksel askerler eşikte dizili bekler (parley).
  void _startImperialParley() {
    final demand = _buildImperialDemand(_impProsperity);
    if (demand == null) {
      // Alacak uygun bir şey yok — heyet boş döner (nadir). Doğrudan ayrılışa geç.
      _showNotification(
        Voice.say(const [
          'Komutan ambara baktı, deftere baktı, atını çevirdi. {köy-de} alacak bir şey yok.',
          'Heyet {köy-i} şöyle bir süzdü. Kalem oynamadı; kolon geri döndü.',
        ], _impVoice(2)),
      );
      _imperialPhase = ImperialVisitPhase.leaving;
      _setMarchDir(_impExitCol - _impAnchorCol, _impExitRow - _impAnchorRow);
      return;
    }
    _imperialPhase = ImperialVisitPhase.parley;
    _requestPacedImperial(demand);
  }

  /// Merkezi ritim kapısı heyete sıra verdiğinde pazarlık yüzeyini açar.
  /// Kuyrukta beklerken askerler eşikte durur, simülasyon akmaya devam eder.
  void _activateImperialParley(ImperialDemand demand) {
    _imperialPhase = ImperialVisitPhase.parley;
    AudioManager.instance.playSfx(Sfx.thunderClap); // gümbürtülü giriş
    addCameraShake(6.0, dur: 0.6);
    setStateHere(() => _imperialDemand = demand);

    if (kCaptureImperialBattle) {
      _imperialAlertLeft = 0;
      _imperialResist(ImperialDefensePlan.counterCharge);
      return;
    }

    // ── Sinematik merdiveni ────────────────────────────────────────────────
    // Tam ekran film NADİR bir ayrıcalıktır. Her ziyarette oynarsa iki bedeli
    // birden ödetir: (1) kompozisyon hep aynı olduğu için 3. gelişte "Atla"
    // tuşuna dönüşür, (2) hemen ardından talep modalı geldiğinden oyuncuyu üst
    // üste İKİ kez duraklatır. Rutin ziyaret zaten dünyada anlatılıyor — kolon
    // harita kenarından formasyonla yürüyor, tam ekran anons düşüyor, heyet
    // eşikte diziliyor — ve komutanın sözü (d.bite + itibar tonu) modalda
    // duruyor. O yüzden film yalnız İLK KEZ OLAN üç ana saklanır:
    //   • ilk ziyaret (imparatorluğun oyuna girişi)
    //   • ilk devşirme (kan bedeli — mal değil, insan isteniyor)
    //   • ret/direniş sonrası ilk dönüş (kinli gelirler)
    //
    // Her tür KOŞUDA BİR KEZ oynar (`_impFilmsShown`). Eskiden bunlar tekrar
    // tekrar tetiklenebiliyordu ve bir de "itibar dibe indi" kolu vardı; toplamda
    // aynı kompozisyon bir koşuda 4-5 kez oynuyordu. İtibar kolu kaldırıldı:
    // ilişkinin bozulduğu zaten heyetin duruşunda ve komutanın sözünde okunuyor,
    // ayrı bir film istemiyor.
    final firstEver = _imperialVisits == 0;
    final conscriptFilm = demand.isConscript && _impFilmsShown.add('conscript');
    final grudgeFilm = _impGrudge && _impFilmsShown.add('grudge');
    final cinematic = firstEver || conscriptFilm || grudgeFilm;
    _imperialVisits++;
    _impGrudge = false;
    if (cinematic) _playCutscene(_buildImperialCutscene(demand));

    _showNotification(
      '⚔️ ${Voice.say(const ['Heyet meydanda. Komutan defterini açtı, {köy-in} adını okudu.', 'Mızraklar {köy-in} eşiğinde durdu. Vergi vakti.', 'Kolon durdu, atlar susturuldu. Sıra {köy-in} cevabında.'], _impVoice(3))}',
    );
  }

  /// İmparatorluk geliş sinematiği — TALEBE + İTİBARA göre dinamik kurulur.
  /// Gövde saf fonksiyona taşındı (systems/events/imperial.dart) ki animasyon odası da
  /// birebir AYNI sahneyi oynatabilsin; odanın kendi kopyasını tutması sahne
  /// düzeltmelerinin oraya yansımamasına yol açıyordu.
  Cutscene _buildImperialCutscene(ImperialDemand d) => imperialArrivalCutscene(
    d,
    favor: _imperialFavor,
    seed: _impSeed(10),
    village: _villageName,
  );

  /// Talep üret — tür ağırlıklı (refah + itibar talebin sertliğini ölçekler).
  ImperialDemand? _buildImperialDemand(double prosp) {
    // İki katman çarpılır ve ikisi ayrı şeyi ölçer: İTİBAR "seninle nasıl
    // geçiniyoruz", YIL "imparatorluğun bu yılki iştahı". Eskiden yalnız
    // birincisi vardı, dolayısıyla iyi geçinen bir köy altıncı yılda birinci
    // yıldaki rakamı ödüyordu (bkz. systems/run/village_year.dart).
    final severity = 1.0 + (1.0 - _imperialFavor) * 0.8; // 1.0–1.8
    final era = pressureForDay(_dayCount);
    final appetite = era.imperialAppetite; // 1.0–2.0
    final pop = _villagers.length;
    final youths = _conscriptCandidates();

    // Tür seçimi: en bol kaynağı tercih eder (oradan koparmak ister); genç
    // devşirme nadir ve yalnız uygun genç varsa.
    final pool = <ImperialDemandKind>[];
    if (_stockpile.gold >= 8) {
      pool.addAll([ImperialDemandKind.goldTax, ImperialDemandKind.goldTax]);
    }
    if (_stockpile.food >= 12) pool.add(ImperialDemandKind.foodLevy);
    if (_stockpile.wood >= 12) pool.add(ImperialDemandKind.woodLevy);
    if (youths.isNotEmpty && pop >= 12) pool.add(ImperialDemandKind.conscript);
    if (pool.isEmpty) {
      pool.add(ImperialDemandKind.goldTax); // hep bir talep çıkar
    }

    final kind = pool[_rng.nextInt(pool.length)];
    int amount;
    switch (kind) {
      case ImperialDemandKind.goldTax:
        // Rakam saf fonksiyonda (bkz. systems/events/imperial.dart) — bir denge
        // kararı sahnede gömülü kalmasın, ölçülebilir bir yerde dursun.
        amount = imperialGoldDemand(
          population: pop,
          treasury: _stockpile.gold,
          severity: severity,
          appetite: appetite,
          treasuryShare: era.treasuryShare,
        );
      case ImperialDemandKind.foodLevy:
        amount = (pop * 2.2 * severity * appetite).round().clamp(8, 9999);
      case ImperialDemandKind.woodLevy:
        amount = (pop * 2.0 * severity * appetite).round().clamp(8, 9999);
      case ImperialDemandKind.conscript:
        amount = 1;
    }
    return ImperialDemand(kind, amount);
  }

  // ── Kaynak yardımcıları ─────────────────────────────────────────────────────
  int _resourceOf(ImperialDemandKind k) => switch (k) {
    ImperialDemandKind.goldTax => _stockpile.gold,
    ImperialDemandKind.foodLevy => _stockpile.food,
    ImperialDemandKind.woodLevy => _stockpile.wood,
    ImperialDemandKind.conscript => 0,
  };
  void _spendResource(ImperialDemandKind k, int n) {
    switch (k) {
      case ImperialDemandKind.goldTax:
        _stockpile.gold = (_stockpile.gold - n).clamp(0, 1 << 30);
      case ImperialDemandKind.foodLevy:
        _stockpile.food = (_stockpile.food - n).clamp(0, 1 << 30);
      case ImperialDemandKind.woodLevy:
        _stockpile.wood = (_stockpile.wood - n).clamp(0, 1 << 30);
      case ImperialDemandKind.conscript:
        break;
    }
  }

  /// Devşirilebilecek gençler/çocuklar (ölmekte olan hariç).
  List<VillagerEntity> _conscriptCandidates() => _villagers
      .where(
        (v) =>
            !v.isDying &&
            (v.lifeStage == LifeStage.youth || v.lifeStage == LifeStage.child),
      )
      .toList();

  /// Devşirme fidyesi (altın) — itibar yükseldikçe ucuzlar.
  int _imperialRansomCost() =>
      (_villagers.length * 1.5 + (1.0 - _imperialFavor) * 20).round().clamp(
        6,
        9999,
      );

  // ── Modal callback'leri (sim duraklı) ───────────────────────────────────────

  void _imperialAccept() {
    final d = _imperialDemand;
    if (d == null) return;
    if (d.isConscript) {
      final c = _conscriptCandidates();
      if (c.isNotEmpty) {
        final v = c[_rng.nextInt(c.length)];
        _takeConscript(v);
      }
    } else {
      _spendResource(d.kind, d.amount); // elinde yetmezse clamp → ne varsa
    }
    _imperialFavor = (_imperialFavor + 0.05).clamp(0.0, 1.0);
    _feelVillage(NpcEmotion.grief, 4, -0.04);
    // İç politik dalga + huzursuzluk: tam ödeme köyün sabrını yer, kesenin/
    // harmanın/ocağın sahibi zümre daha çok hisseder.
    _imperialInternalToll(d, d.isConscript ? 0.7 : 0.55);
    // Hür rejim: meclis pazarlık/direniş isterken sen ödediysen meşruiyet bedeli.
    if (_defiesCouncil(ImperialVerdict.comply)) {
      _payCouncilOverride(violent: false);
    }
    _chronicle(
      'Öşür ödendi: ${d.label}. Komutan satırın yanına bir çentik attı.',
      icon: '⚔️',
      kind: ChronicleKind.decision,
    );
    _showNotification(
      '⚔️ ${Voice.say(const ['Yük arabalara bindi. {köy} bu akşam sağ, yalnız daha fakir.', 'Defter kapandı, kolon yola çıktı. Kimse arkalarından bakmadı.', 'Ödendi. Meydanda kalan tek şey tekerlek izleri.'], _impVoice(20))}',
    );
    _endImperialVisit(_prosperity());
  }

  void _imperialRansom() {
    final d = _imperialDemand;
    if (d == null || !d.isConscript) return;
    final cost = _imperialRansomCost();
    if (_stockpile.gold < cost) return;
    _stockpile.gold -= cost;
    _imperialFavor = (_imperialFavor + 0.03).clamp(0.0, 1.0);
    _imperialInternalToll(d, 0.4); // fidye hafif fatura (evlat kaldı)
    if (_defiesCouncil(ImperialVerdict.comply)) {
      _payCouncilOverride(violent: false);
    }
    _chronicle(
      'Bir gencin yerine kese verildi ($cost★); çocuk ocağında kaldı.',
      icon: '★',
      kind: ChronicleKind.decision,
    );
    _showNotification(
      '★ ${Voice.say(['Altın sayıldı, çocuğun kolu bırakıldı. {köy-de} kalıyor. (-$cost★)', 'Komutan keseyi tarttı, gence bir daha bakmadı. Kaldı. (-$cost★)'], _impVoice(21))}',
    );
    _endImperialVisit(_prosperity());
  }

  void _imperialHaggle(double frac) {
    final d = _imperialDemand;
    if (d == null || d.isConscript) return;
    // Eşik itibara + REJİME bağlı: tüccar köy daha ucuza anlaşır (haggleEase).
    final threshold =
        (0.85 - _imperialFavor * 0.45 - _imperialPosture.haggleEase).clamp(
          0.0,
          1.0,
        );
    if (frac >= threshold) {
      final pay = (d.amount * frac).round();
      _spendResource(d.kind, pay);
      _imperialFavor = (_imperialFavor + 0.04).clamp(0.0, 1.0);
      _imperialInternalToll(d, 0.35 * frac); // pazarlık: hafifletilmiş fatura
      if (_defiesCouncil(ImperialVerdict.haggle)) {
        _payCouncilOverride(violent: false);
      }
      _chronicle(
        'Komutan rakamı çizip $pay yazdı; köy o kadarını ödedi.',
        icon: '🤝',
        kind: ChronicleKind.decision,
      );
      _showNotification(
        '🤝 ${Voice.say(['Komutan sayıyı çizdi, altına $pay${d.icon} yazdı. Fark {köy-de} kaldı.', 'Kalem oynadı. $pay${d.icon} ile kapandı bu iş.'], _impVoice(22))}',
      );
    } else {
      // Tutmadı → komutan öfkelendi: tam öder + itibar düşer.
      _spendResource(d.kind, d.amount);
      _imperialFavor = (_imperialFavor - 0.12).clamp(0.0, 1.0);
      _feelVillage(NpcEmotion.fear, 6, -0.06);
      _imperialInternalToll(d, 0.7); // ağır fatura: hem ödedi hem küçük düştü
      _chronicle(
        'Teklif komutanı güldürmedi. Rakam olduğu gibi tahsil edildi.',
        icon: '⚔️',
        kind: ChronicleKind.decision,
      );
      _showNotification(
        '⚔️ ${Voice.say(const ['Komutan defteri kapatmadı bile. Rakamın tamamı alındı.', 'Teklif havada kaldı. Askerler ambara kendileri girdi; tam ödendi.'], _impVoice(23))}',
      );
    }
    _endImperialVisit(_prosperity());
  }

  // ── DİRENİŞ (#4) ────────────────────────────────────────────────────────────
  // Reddetmek her zaman intihar olmasın: yeterince GÜÇLÜ köy (muhafız + kalabalık)
  // heyeti KOVABİLİR. Gerçek bir kumar — başarı şansı açıkça gösterilir; tutarsa
  // köy gururla direnir (ölüm yok, itibar düşer), tutmazsa bedeli ağır olur.

  /// Köyün silahlı gücü — muhafız sayısı + kalabalık. Direniş şansının temeli.
  int _guardCount() => _villagers
      .where((v) => !v.isDying && v.type == VillagerType.guard)
      .length;

  /// Heyeti kovma başarı şansı (0 = denenemez). Muhafızlar belkemiği; kalabalık
  /// köy de sayıca direnebilir. Düşük itibar komutanı acımasızlaştırır (şans ↓).
  double _resistChance() {
    final p = _defensePreview();
    if (p.guards < 1 &&
        p.tools == 0 &&
        p.weapons == 0 &&
        _villagers.length < 14) {
      return 0.0;
    }
    final raid = _imperialRaidScenario;
    return (p.chance + (raid?.holdBonus ?? 0) - (raid?.attackDelta ?? 0)).clamp(
      0.02,
      0.95,
    );
  }

  ImperialDefensePreview _defensePreview() => imperialDefensePreview(
    guards: _guardCount(),
    population: _villagers.length,
    weapons: _stockpile.weapons,
    iron: _stockpile.iron,
    wood: _stockpile.wood,
    stone: _stockpile.stone,
    favor: _imperialFavor,
    regimeBonus: _imperialPosture.resistBonus + _faithEffect.resistBonus,
  );

  void _imperialResist(ImperialDefensePlan plan) {
    final d = _imperialDemand;
    if (d == null) return;
    final defense = _defensePreview();
    final planPreview = imperialPlanPreview(
      plan: plan,
      defense: defense,
      wood: _stockpile.wood,
    );
    if (!planPreview.available) return;
    _imperialDefensePlan = plan;
    _imperialAlertLeft = 0;
    _stockpile.wood = max(0, _stockpile.wood - planPreview.woodCost);
    _battleDemand = d;
    _impGrudge = true;
    if (_defiesCouncil(ImperialVerdict.resist)) {
      _payCouncilOverride(violent: false);
    }
    _endImperialVisit(_prosperity(), clash: true);
    _stockpile.weapons = max(0, _stockpile.weapons - planPreview.weaponCost);
  }

  void _imperialRefuse() {
    // Refusal starts the same physical confrontation. Even an unprepared
    // village gets to fight or withdraw; no civilians die by a remote roll.
    _imperialResist(ImperialDefensePlan.holdLine);
  }

  /// Bir genci askere ver — köyden ayrılır (ölüm değil; yas + moral).
  void _takeConscript(VillagerEntity v) {
    for (final p in v.parents) {
      p.children.remove(v);
    }
    for (final c in v.children) {
      c.parents.remove(v);
    }
    _villagers.remove(v);
    // Devşirilen köylü `startDying`/`startLeaving`'den geçmez → merkezî
    // temizleme turuna hiç düşmez; referansları burada elle koparılmalı.
    _forgetVillager(v);
    _feelVillage(NpcEmotion.grief, 8, -0.08);
    // Adın eki elle yapıştırılmaz: {ad-i}/{ad-in} ünlü uyumunu Voice çözer.
    _chronicle(
      Voice.say(const [
        '{ad} kolona katıldı. Anası yolun ucuna kadar yürüdü, sonra durdu.',
        'Askerler {ad-i} aldı. {hane} ocağında bir yastık boş kaldı.',
        '{ad-in} adı deftere yazıldı. Köy kapısı ardından uzun süre kapanmadı.',
      ], _voice(v, seed: _impSeed(27))),
      icon: '🧑',
      kind: ChronicleKind.crisis,
    );
  }

  void _endImperialVisit(double prosp, {bool clash = false}) {
    setStateHere(() => _imperialDemand = null);
    _impProsperity = prosp;
    if (_soldiers.isEmpty) {
      _imperialPhase = ImperialVisitPhase.idle;
      _imperialTimer = _rollImperialInterval(prosp);
      return;
    }
    if (clash) {
      _imperialPhase = ImperialVisitPhase.clashing;
      for (final s in _soldiers) {
        s.imperialAttacking = false;
      }
      _prepareImperialEngagements();
      return;
    }
    _imperialPhase = ImperialVisitPhase.leaving;
    _setMarchDir(_impExitCol - _impAnchorCol, _impExitRow - _impAnchorRow);
  }

  void _beginImperialRaid() {
    _clearImperialEngagements();
    _impStruck = false;
    _impRaidTimer = 15;
    final raid = _imperialRaidScenario;
    _imperialRaidTargetBuilding = _raidTargetBuilding(raid?.target);
    final (cx, cy) = _raidTargetPoint(raid?.target);
    final (rx, ry) = _battleGround(cx, cy);
    _impRaidCol = rx;
    _impRaidRow = ry;
    _followedVillager = null;
    _watchX = rx;
    _watchY = ry;
    _watchLeft = 4.8;
    for (final s in _soldiers) {
      s.imperialAttacking = true;
    }
    _imperialPhase = ImperialVisitPhase.raiding;
  }

  BuildingEntity? _raidTargetBuilding(ImperialRaidTarget? target) {
    final types = switch (target) {
      ImperialRaidTarget.warehouse => const [BuildingType.warehouse],
      ImperialRaidTarget.market => const [BuildingType.market],
      ImperialRaidTarget.townHall => const [BuildingType.townhall],
      ImperialRaidTarget.church => const [BuildingType.church],
      ImperialRaidTarget.lumberCamp => const [BuildingType.lumberCamp],
      ImperialRaidTarget.stable => const [BuildingType.stable],
      ImperialRaidTarget.manor => const [BuildingType.manor],
      ImperialRaidTarget.homes => const [
        BuildingType.tent,
        BuildingType.woodenHouse,
        BuildingType.stoneHouseBlue,
        BuildingType.stoneHouseGreen,
        BuildingType.manor,
      ],
      _ => const <BuildingType>[],
    };
    final candidates = _buildings.where((b) => types.contains(b.type)).toList();
    if (candidates.isEmpty) return null;
    return candidates[_impSeed(82).abs() % candidates.length];
  }

  (double, double) _raidTargetPoint(ImperialRaidTarget? target) {
    final building = _imperialRaidTargetBuilding;
    if (building != null) {
      return (
        building.col + building.cols / 2,
        building.row + building.rows / 2,
      );
    }
    if (target == ImperialRaidTarget.threshold) {
      final (cx, cy) = _villageCenterD();
      final dx = cx - _impParleyCol, dy = cy - _impParleyRow;
      final length = max(.01, sqrt(dx * dx + dy * dy));
      // The objective is behind the defenders, never the ground on which
      // the arriving expedition already stands.
      return (_impParleyCol + dx / length * 5, _impParleyRow + dy / length * 5);
    }
    final (cx, cy) = _villageCenter();
    if (target == ImperialRaidTarget.fields) {
      // Tarla varlıkları bina listesinde değildir; hasat baskını köyün dış
      // çeperinde oynar ve merkez baskınından belirgin biçimde ayrılır.
      final dx = _impParleyCol - cx;
      final dy = _impParleyRow - cy;
      return (cx + dx * .62, cy + dy * .62);
    }
    return (cx.toDouble(), cy.toDouble());
  }

  /// Pazarlık modal'ı — build Stack'ten çağrılır (_imperialDemand != null iken).
  Widget buildImperialModal() {
    final d = _imperialDemand!;
    final ransom = _imperialRansomCost();
    final canFull = d.isConscript ? true : _resourceOf(d.kind) >= d.amount;
    final verdict = _imperialCouncilVerdict;
    return ImperialModal(
      demand: d,
      raidTitle: _imperialRaidScenario?.title ?? 'Sınır Baskısı',
      raidIntel: _imperialRaidScenario == null
          ? ''
          : '${_imperialRaidScenario!.objective}. '
                'Çatışma noktası: ${_imperialRaidScenario!.target.label}.',
      raidScenario: _imperialRaidScenario,
      favor: _imperialFavor,
      ransomCost: ransom,
      canAcceptFull: canFull,
      canRansom: _stockpile.gold >= ransom,
      resistChance: _resistChance(),
      defensePreview: _defensePreview(),
      // REJİM: köyün dış-güç duruşu + hür rejimde meclisin önerisi. Meclis
      // öneriyse, dışına çıkan seçenek "meşruiyet bedeli" etiketiyle işaretlenir.
      haggleEase: _imperialPosture.haggleEase,
      postureNote: _imperialPosture.note,
      councilVerdict: verdict,
      councilLine: verdict == null
          ? ''
          : Regime.verdictLine(verdict, conscript: d.isConscript),
      onAccept: _imperialAccept,
      onRefuse: _imperialRefuse,
      onRansom: _imperialRansom,
      onHaggle: _imperialHaggle,
      wood: _stockpile.wood,
      onDefensePlan: _imperialResist,
      onResist: () => _imperialResist(ImperialDefensePlan.holdLine),
    );
  }
}
