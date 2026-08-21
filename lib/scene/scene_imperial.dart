part of '../main.dart';

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

  /// DEV TEST — gerçek imparatorluk darbesindeki ölüm bildirimi yolunu
  /// askerleri beklemeden sahneler. İki isim seçilir, çöküş animasyonu,
  /// toast ve kronik aynı anda doğrulanabilir.
  void _devStageImperialDeathNotice() {
    if (_imperialPhase != ImperialVisitPhase.idle || _imperialDemand != null) {
      _showNotification('Önce aktif imparatorluk sahnesini bitir.');
      return;
    }
    final candidates = _villagers
        .where((v) => !v.isDying && !v.isFavorite)
        .toList();
    if (candidates.length < 2) {
      _showNotification('Test için en az iki uygun köylü gerekiyor.');
      return;
    }
    _imperialRaidVictims
      ..clear()
      ..addAll(candidates.take(2));
    _strikeRaidVictims();
  }

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
    final (px, py) = _nearestLand(
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

  /// Yağma dalışı — askerler köy merkezine koşar; varışta (veya sayaç dolunca)
  /// DARBE: kurbanlar çöker + sarsıntı + kızıl tint. Kısa bekleyişten sonra
  /// ayrılışa geçer. [dt] sim-sn (sayaç), [npcDt] fx-ölçekli (hareket).
  void _tickImperialRaid(double dt, double npcDt) {
    final reached =
        _stepAnchor(npcDt, _impRaidCol, _impRaidRow, _kRaidSpeed) < 0.6;
    _chargeSoldiers(npcDt, _impRaidCol, _impRaidRow);
    if (!_impStruck) {
      _impRaidTimer -= dt;
      if (reached || _impRaidTimer <= 0) {
        _strikeRaidVictims();
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

  /// Eşik muharebesi — sonuçtan bağımsız oynar. Saflar kurulur, ilk imparatorluk
  /// darbesi gelir, köy karşılık verir, son itiş sonucu dünyada görünür kılar.
  /// Kaybedildiyse bu evre meydan yağmasına KESİNTİSİZ akar.
  static const double _kClashTotal = 12.0;

  double get _imperialBattleProgress =>
      (1.0 - _imperialClashTimer / _kClashTotal).clamp(0.0, 1.0);

  void _tickImperialClash(double dt) {
    final previousBeat = imperialBattleBeat(_imperialClashTimer);
    _imperialClashTimer -= dt;
    final beat = imperialBattleBeat(_imperialClashTimer);
    final defenders = _imperialDefenderPosts.keys.toList(growable: false);

    // Safları temas mesafesine getir. Eski sahnede iki taraf üç karo arayla
    // yerinde mızrak sallıyordu; ilk darbede kolon ilerler, köy karşılığında
    // söktürür, son itiş de sonucu mekânda gösterir.
    final (cx, cy) = _villageCenter();
    final dx = cx - _impParleyCol, dy = cy - _impParleyRow;
    final len = sqrt(dx * dx + dy * dy);
    final ux = len < 0.001 ? 0.0 : dx / len;
    final uy = len < 0.001 ? 1.0 : dy / len;
    _impDirX = ux;
    _impDirY = uy;
    _tickImperialEngagements(dt * _fxNpcSpeedMul);
    if (beat != previousBeat && beat != ImperialBattleBeat.mustering) {
      final hard = beat == ImperialBattleBeat.finalPush;
      addCameraShake(hard ? 12.0 : 8.0, dur: hard ? 0.85 : 0.55);
      _activeFx.add(
        ActiveFx(
          EventEffect(
            screenTint: hard && !_imperialBattleWon
                ? const Color(0x44A81818)
                : const Color(0x2D71849B),
            duration: hard ? 1.1 : 0.65,
          ),
          hard ? 1.1 : 0.65,
        ),
      );
      if (beat == ImperialBattleBeat.result && _imperialBattleWon) {
        // Zaferi karar anında değil, dünyadaki son itişten sonra kutla.
        _activeFx.add(
          ActiveFx(const EventEffect(fx: EventFx.festival, duration: 8), 8),
        );
      }
      if (beat == ImperialBattleBeat.result &&
          !_imperialBattleOutcomeAnnounced) {
        _imperialBattleOutcomeAnnounced = true;
        if (_imperialBattleChronicle.isNotEmpty) {
          _chronicle(
            _imperialBattleChronicle,
            icon: _imperialBattleWon ? '🛡️' : '⚔️',
            milestone: true,
            kind: _imperialBattleWon
                ? ChronicleKind.decision
                : ChronicleKind.crisis,
          );
        }
        if (_imperialBattleNotice.isNotEmpty) {
          _showNotification(_imperialBattleNotice);
        }
      }
    }
    if (_imperialClashTimer > 0) return;
    for (final s in _soldiers) {
      s.imperialAttacking = false;
      s.imperialHit = false;
    }
    for (final v in defenders) {
      v.imperialAttacking = false;
      v.imperialHit = false;
    }
    if (_imperialRaid) {
      _imperialRaid = false;
      _beginImperialRaid();
      return;
    }
    _imperialPhase = ImperialVisitPhase.leaving;
    _clearImperialEngagements();
    _setMarchDir(_impExitCol - _impAnchorCol, _impExitRow - _impAnchorRow);
  }

  /// Ön saftaki askerleri eşikteki yetişkin savunucularla şerit sırasına göre
  /// bire bir eşler. Arka saflar yedek kalır; aynı savunucunun üstüne üç asker
  /// yığılmaz. Mevziler bir kez kaydedilir ki her hamle bir önceki karenin
  /// kaymış konumundan değil, gerçek çatışma hattından hesaplansın.
  void _prepareImperialEngagements() {
    _clearImperialEngagements();
    kProbeImperialCombatPairs = 0;
    kProbeImperialCombatContactSeen = false;
    final vg = _vignette;
    if (vg == null || vg.eventId != kThresholdVignetteId) return;
    final defenders = vg.cast
        .where((v) => !v.isDying && v.lifeStage != LifeStage.child)
        .toList();
    if (defenders.isEmpty || _soldiers.isEmpty) return;

    final perpX = -_impDirY, perpY = _impDirX;
    double lateral(VillagerEntity v) =>
        (v.gridX - _impAnchorCol) * perpX + (v.gridY - _impAnchorRow) * perpY;
    defenders.sort((a, b) => lateral(a).compareTo(lateral(b)));
    final attackers = [..._soldiers]
      ..sort((a, b) {
        final row = a.backOffset.compareTo(b.backOffset);
        return row != 0 ? row : a.sideOffset.compareTo(b.sideOffset);
      });
    final count = min(defenders.length, attackers.length);
    for (var i = 0; i < count; i++) {
      final s = attackers[i];
      final v = defenders[i];
      _imperialCombatPairs[s] = v;
      _imperialSoldierPosts[s] = (s.gridX, s.gridY);
      _imperialDefenderPosts[v] = (v.gridX, v.gridY);
      s.lookToward(v.gridX, v.gridY);
      v.lookToward(s.gridX, s.gridY);
    }
    kProbeImperialCombatPairs = _imperialCombatPairs.length;
  }

  /// Her eşleşmeyi kendi gecikmeli hamlesiyle yürütür. Bu, global bir saldırı
  /// bayrağı değildir: temas eden kişi vurur, karşısındaki kişi o anda tepki
  /// verir ve son itişte yalnız kaybeden taraf geri sürülür.
  void _tickImperialEngagements(double dt) {
    var lane = 0;
    for (final entry in _imperialCombatPairs.entries) {
      final s = entry.key;
      final v = entry.value;
      final soldierPost = _imperialSoldierPosts[s];
      final defenderPost = _imperialDefenderPosts[v];
      if (soldierPost == null ||
          defenderPost == null ||
          !_soldiers.contains(s) ||
          !_villagers.contains(v) ||
          v.isDying) {
        lane++;
        continue;
      }
      final motion = imperialCombatMotion(
        remaining: _imperialClashTimer,
        lane: lane,
        villageWon: _imperialBattleWon,
      );
      final stx = soldierPost.$1 + _impDirX * motion.attackerAdvance;
      final sty = soldierPost.$2 + _impDirY * motion.attackerAdvance;
      s.stepTo(
        dt,
        stx,
        sty,
        dayLight: _cycle.dayLight,
        rainIntensity: _cycle.rainIntensity,
        speedMul: 3.4,
        arriveD: 0.025,
      );
      final vtx = defenderPost.$1 + _impDirX * motion.defenderAdvance;
      final vty = defenderPost.$2 + _impDirY * motion.defenderAdvance;
      v.isWalking = true;
      final arrived = v.moveTowards(
        vtx,
        vty,
        dt,
        arriveD: 0.025,
        speedScale: 3.0,
      );
      if (arrived) v.isWalking = false;
      v.smoothMotion(dt);
      s.lookToward(v.gridX, v.gridY);
      v.lookToward(s.gridX, s.gridY);
      s.imperialAttacking = motion.attackerStriking;
      v.imperialAttacking = motion.defenderStriking;
      s.imperialHit = motion.attackerHit;
      v.imperialHit = motion.defenderHit;
      if (motion.attackerStriking ||
          motion.defenderStriking ||
          motion.attackerHit ||
          motion.defenderHit) {
        kProbeImperialCombatContactSeen = true;
      }
      lane++;
    }

    // Eşleşmeyen arka saf yerini korur; boşluğa mızrak sallamaz.
    final perpX = -_impDirY, perpY = _impDirX;
    for (final s in _soldiers) {
      if (_imperialCombatPairs.containsKey(s)) continue;
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
      s.imperialAttacking = false;
      s.imperialHit = false;
    }
  }

  void _clearImperialEngagements() {
    for (final s in _imperialCombatPairs.keys) {
      s.imperialAttacking = false;
      s.imperialHit = false;
    }
    for (final v in _imperialDefenderPosts.keys) {
      v.imperialAttacking = false;
      v.imperialHit = false;
    }
    _imperialCombatPairs.clear();
    _imperialSoldierPosts.clear();
    _imperialDefenderPosts.clear();
  }

  /// Darbe anı — seçili kurbanları çökertir (aile bağını kopararak), görünür
  /// şiddet FX'i basar. `_imperialRaidVictims` karar anında seçilmiştir.
  void _strikeRaidVictims() {
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
    final fallen = <String>[];
    for (final v in _imperialRaidVictims) {
      if (v.isDying || !_villagers.contains(v)) continue;
      final house = v.surname.trim().isEmpty ? '' : ' (${v.surname} Hanesi)';
      fallen.add('${v.name}$house');
      for (final p in v.parents) {
        p.children.remove(v);
      }
      for (final c in v.children) {
        c.parents.remove(v);
      }
      _markDeathHouse(v);
      v.startDying(funeral: true);
    }
    if (fallen.isNotEmpty) {
      final names = fallen.join(', ');
      _showNotification(
        '⚔️ İmparatorluk baskınında hayatını kaybedenler: $names.',
      );
      _chronicle(
        '${_imperialRaidScenario?.title ?? 'İmparatorluk baskını'} sırasında '
        '${fallen.join(', ')} hayatını kaybetti.',
        icon: '⚔️',
        milestone: true,
        kind: ChronicleKind.crisis,
      );
    }
    _imperialRaidVictims.clear();
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
  /// Gövde saf fonksiyona taşındı (systems/imperial.dart) ki animasyon odası da
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
    // yıldaki rakamı ödüyordu (bkz. systems/village_year.dart).
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
        // Rakam saf fonksiyonda (bkz. systems/imperial.dart) — bir denge
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
    _imperialBattleOutcomeAnnounced = false;
    _imperialBattleChronicle = '';
    _imperialBattleNotice = '';
    _stockpile.wood = (_stockpile.wood - planPreview.woodCost).clamp(
      0,
      1 << 30,
    );
    _stockpile.weapons = (_stockpile.weapons - planPreview.weaponCost).clamp(
      0,
      1 << 30,
    );
    final raid = _imperialRaidScenario;
    final planBonus = raid == null
        ? 0.0
        : switch (plan) {
            ImperialDefensePlan.holdLine => raid.holdBonus,
            ImperialDefensePlan.barricade => raid.barricadeBonus,
            ImperialDefensePlan.counterCharge => raid.chargeBonus,
          };
    final chance = (planPreview.chance + planBonus - (raid?.attackDelta ?? 0))
        .clamp(0.02, 0.95);
    AudioManager.instance.playSfx(Sfx.thunderClap);
    addCameraShake(9.0, dur: 0.8);
    // Sonuç ne olursa olsun eşikte kan/gurur kaldı — bir daha geldiklerinde
    // usul bozulmuş olur, o dönüş sahnelenir (bkz. _startImperialParley).
    _impGrudge = true;
    // Hür rejim: meclis ödeme/pazarlık isterken sen köyü kumara sürdüysen
    // (meclis direnmek istemiyordu) meşruiyet bedeli — sonuç ne olursa olsun.
    if (_defiesCouncil(ImperialVerdict.resist)) {
      _payCouncilOverride(violent: false);
    }
    var defenseWon = false;
    if (kProbeForceResistWin || _rng.nextDouble() < chance) {
      defenseWon = true;
      // BAŞARI — heyet kovuldu. Ölüm yok; köy gururla doğrulur. İtibar düşer
      // (imparatorluk aşağılandı) ama bir muhafız yara alabilir (bedelsiz değil).
      _imperialFavor = (_imperialFavor - 0.15).clamp(0.0, 1.0);
      _feelVillage(NpcEmotion.joy, 12, 0.14); // zafer gururu
      pushPolicyMorale(0.08, 4.0);
      _nudgeHousesByEstate(Estate.hearth, moodDelta: 0.06, swayGain: 0.05);
      _nudgeHousesByEstate(Estate.laborers, moodDelta: 0.04, swayGain: 0.03);
      // Başarılı direniş huzursuzluğu YATIŞTIRIR: köy dışa karşı kenetlendi,
      // içerideki homurtu bir süre unutuldu (gurur = meşruiyet).
      _unrest = (_unrest - 0.14).clamp(0.0, 1.0);
      _unrestStirShown = false;
      final capturedWeapon = _rng.nextDouble() < 0.45 ? 1 : 0;
      if (capturedWeapon > 0) _stockpile.weapons += capturedWeapon;
      // Bir muhafız yaralanabilir — direniş bedavaya gelmez.
      final guards = _villagers
          .where((v) => !v.isDying && v.type == VillagerType.guard)
          .toList();
      if (guards.isNotEmpty && _rng.nextDouble() < 0.5) {
        final g = guards[_rng.nextInt(guards.length)];
        g.injuryDays = 2.0 + _rng.nextDouble() * 2.0;
        g.feel(NpcEmotion.grief, 4.0, moodDelta: -0.08);
      }
      // SAHNE — bilançodan SONRA kurulur ve sıra önemlidir: `_feelVillage(joy)`
      // köyün tamamına sevinç yazar, eşik kadrosunun duygusu ise rolle birlikte
      // gelir (öfke/korku). Sahne önce kurulsaydı sevinç onu ezerdi ve hat,
      // mızrakların önünde dururken gülümserdi. Zafer ancak heyet dönünce
      // sevinç olur; hat kurulurken değil.
      _imperialBattleChronicle =
          '$_villageName ${plan.title.toLowerCase()} kurdu; tırpanla, baltayla '
          'eşiği tuttu. Heyet geri döndü.';
      _imperialBattleNotice =
          '🛡️ ${Voice.say(const ['Heyet geri çekildi. {köy} bu akşam kimseyi gömmüyor.', 'Mızraklar geri döndü. Kimse bağırmadı; herkes yerinde durdu, yetti.'], _impVoice(24))}${capturedWeapon > 0 ? ' Bir silah ele geçirildi.' : ''}';
    } else {
      // BAŞARISIZ — direniş ezildi. Reddetmekten beter: savunucular (muhafızlar)
      // ön safta düşer. Kurbanlar SEÇİLİR ama ölüm, askerlerin merkeze dalışıyla
      // (raiding) senkron gerçekleşir (bkz. _strikeRaidVictims). Favoriler korunur.
      final victimCount =
          (2 +
                  (1.0 - _imperialFavor).floor() +
                  planPreview.casualtyDelta +
                  (raid?.casualtyDelta ?? 0))
              .clamp(1, 6);
      final pool = _villagers
          .where((v) => !v.isDying && !v.isFavorite)
          .toList();
      pool.sort((a, b) {
        final ga = a.type == VillagerType.guard ? 0 : 1;
        final gb = b.type == VillagerType.guard ? 0 : 1;
        return ga.compareTo(gb);
      });
      _imperialRaidVictims
        ..clear()
        ..addAll(pool.take(victimCount));
      _imperialRaid = true;
      final killed = _imperialRaidVictims.length;
      if (!d.isConscript) {
        _spendResource(
          d.kind,
          (d.amount * 0.6 * (raid?.lootMultiplier ?? 1)).round(),
        );
      }
      _imperialFavor = (_imperialFavor - 0.25).clamp(0.0, 1.0);
      _feelVillage(NpcEmotion.fear, 16, -0.22);
      pushPolicyMorale(-0.15, 6.0);
      _imperialInternalToll(
        d,
        1.0,
        raid: true,
      ); // ezilen direniş: huzursuzluk sıçrar
      _imperialBattleChronicle =
          '${raid?.title ?? 'İmparatorluk baskını'} sırasında direniş kırıldı. '
          '$killed köylü yerde kaldı; hedef ${raid?.target.label ?? 'meydan'} oldu.';
      _imperialBattleNotice =
          '⚔️ ${Voice.say(const ['Sıra bozuldu. Askerler meydana giriyor.', 'Baltalar yetmedi. Atlılar {köy-in} içinde.'], _impVoice(25))}';
    }
    _imperialBattleWon = defenseWon;
    _stageThresholdStand(won: defenseWon, plan: plan);
    _endImperialVisit(_prosperity(), clash: true);
  }

  void _imperialRefuse() {
    final d = _imperialDemand;
    if (d == null) return;
    // Şiddet — talebin sertliğine göre 1–3 kurban (favoriler DAHİL). Kurbanlar
    // SEÇİLİR ama ölüm askerlerin merkeze dalışıyla (raiding) senkron gerçekleşir
    // (bkz. _strikeRaidVictims). Üstüne yağma (kaynağın bir kısmı zorla alınır).
    final severity = 1.0 + (1.0 - _imperialFavor);
    final raid = _imperialRaidScenario;
    final victimCount = (1 + severity.floor() + (raid?.casualtyDelta ?? 0))
        .clamp(1, 6);
    final pool = _villagers.where((v) => !v.isDying).toList()..shuffle(_rng);
    _imperialRaidVictims
      ..clear()
      ..addAll(pool.take(victimCount));
    _imperialRaid = true;
    _impGrudge = true; // kinli dönüş sahnelenir
    final killed = _imperialRaidVictims.length;
    if (!d.isConscript) {
      _spendResource(
        d.kind,
        (d.amount * 0.5 * (raid?.lootMultiplier ?? 1)).round(),
      );
    }
    _imperialFavor = (_imperialFavor - 0.25).clamp(0.0, 1.0);
    _feelVillage(NpcEmotion.fear, 16, -0.22);
    pushPolicyMorale(-0.15, 6.0);
    _imperialInternalToll(d, 1.0, raid: true); // yağma: huzursuzluk sıçrar
    // Hür rejim: meclis hangi duruşu önermiş olursa olsun, "reddet" (bilinçli
    // kıyım) meclisin önerisi değildir → her zaman en ağır meşruiyet çelişkisi.
    if (_imperialCouncilVerdict != null) _payCouncilOverride(violent: true);
    AudioManager.instance.playSfx(Sfx.thunderClap); // reddetme gümbürtüsü
    _chronicle(
      '$_villageName ödemedi. ${raid?.title ?? 'Baskın'} başladı; komutan '
      '$killed kişiyi bedel olarak aldı.',
      icon: '⚔️',
      milestone: true,
      kind: ChronicleKind.crisis,
    );
    _showNotification(
      '⚔️ ${Voice.say(const ['Komutan sessizce başını salladı. Mızraklar indi, atlar {köy-e} sürüldü.', 'Cevabı aldı. Şimdi bedelini kendi eliyle topluyor.'], _impVoice(26))}',
    );
    _endImperialVisit(_prosperity());
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
      // Fiziksel heyet yok (yüklemeden/eski yol) — dalış oynayamaz: bekleyen
      // kurban varsa hemen uygula, doğrudan sayaca dön.
      if (_imperialRaid) {
        _strikeRaidVictims();
        _imperialRaid = false;
      }
      _imperialPhase = ImperialVisitPhase.idle;
      _imperialTimer = _rollImperialInterval(prosp);
      return;
    }
    if (clash) {
      _imperialClashTimer = _kClashTotal;
      _imperialPhase = ImperialVisitPhase.clashing;
      for (final s in _soldiers) {
        s.imperialAttacking = false;
      }
      _prepareImperialEngagements();
      return;
    }
    if (_imperialRaid) {
      _imperialRaid = false;
      _beginImperialRaid();
      return;
    }
    _imperialPhase = ImperialVisitPhase.leaving;
    _setMarchDir(_impExitCol - _impAnchorCol, _impExitRow - _impAnchorRow);
  }

  void _beginImperialRaid() {
    _clearImperialEngagements();
    _impStruck = false;
    _impRaidTimer = 3.2;
    final raid = _imperialRaidScenario;
    _imperialRaidTargetBuilding = _raidTargetBuilding(raid?.target);
    final (cx, cy) = _raidTargetPoint(raid?.target);
    final (rx, ry) = _nearestLand(cx, cy);
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
      return (_impParleyCol, _impParleyRow);
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
