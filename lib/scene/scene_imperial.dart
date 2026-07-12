part of '../main.dart';

/// İmparatorluk (dış tehdit) — vergici askerî heyet KOŞULLU olarak gelir
/// (köy zenginleştikçe/büyüdükçe dikkat çeker; fakir köy genelde es geçilir).
/// Talep: altın vergisi / yiyecek / kereste / genç devşirme. Pazarlık veya
/// fidye ile anlaşmak HER ZAMAN daha avantajlı; reddedersen kan dökülür
/// (favoriler dahil köylüler öldürülebilir). [_imperialFavor] (İmparatorlukla
/// ilişki) pazarlık şansını + talebin sertliğini + ziyaret sıklığını belirler.
///
/// Tam döngü: harita kenarından formasyonla YAKLAŞMA (sim akar, oyuncu kolonu
/// görür) → eşikte PARLEY (geliş sinematiği + talep modalı, sim durur) → karara
/// göre RAIDING (merkeze dalış + görünür darbe) ya da doğrudan LEAVING. Fiziksel
/// asker NPC'leri ([ImperialSoldier]) + geliş sinematiği + zümre nabzındaki
/// dış-güç madalyonu bağlı. Dev panelden [_devSummonImperial] ile anında tetiklenir.
extension _SceneImperial on _VillageSceneState {
  static const int _kMinPop = 8;               // bu nüfusun altında ilgilenmez
  static const double _kProsperityGate = 55.0; // bunun altı "fakir köy" → es geç

  /// Köyün refah skoru — İmparatorluğun iştahını belirler.
  double _prosperity() =>
      _stockpile.gold * 1.0 +
      _stockpile.food * 0.35 +
      _stockpile.wood * 0.2 +
      _villagers.length * 4.0 +
      _buildings.length * 2.5;

  void _tickImperial(double dt) {
    // Fiziksel heyet sahnedeyse formasyonu yürüt (yaklaşma/ayrılış). Pazarlıkta
    // sim zaten duraklı olduğundan buraya dt gelmez.
    if (_imperialPhase != ImperialVisitPhase.idle) {
      _tickImperialColumn(dt);
      return;
    }
    if (_imperialDemand != null) return; // güvenlik (parley dışında olmamalı)
    if (!_hasFire || _villagers.length < _kMinPop) return;
    final prosp = _prosperity();
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
      (3 + _villagers.length ~/ 6 + _buildings.length ~/ 8).clamp(3, 9);

  /// i. askerin formasyondaki ofseti: (geri, yan) tile. Komutan (0) en önde-orta;
  /// gerisi 3'erli saflar halinde dizilir.
  (double, double) _formationOffset(int i) {
    if (i == 0) return (0.0, 0.0);
    final row = (i - 1) ~/ 3;
    final col = (i - 1) % 3;
    final side = (col - 1) * 0.9;     // -0.9 / 0 / +0.9
    final back = 1.1 + row * 1.0;     // ilk saf 1.1 geride
    return (back, side);
  }

  void _setMarchDir(double dx, double dy) {
    final len = sqrt(dx * dx + dy * dy);
    if (len > 1e-4) {
      _impDirX = dx / len;
      _impDirY = dy / len;
    }
  }

  /// Heyet ziyaretini başlatır: askerleri harita kenarında formasyonda spawn
  /// edip köy eşiğine (pazarlık noktası) doğru yürütür. Sim DURMAZ — oyuncu
  /// yaklaşan kolonu görür; eşiğe varınca pazarlık (modal) açılır.
  void _beginImperialApproach(double prosp) {
    _impProsperity = prosp;
    final groupSize = _imperialGroupSize();

    // Giriş köşesi — sol-üst (tüccar sağ-alttan gelir, çakışmasın).
    final (ex, ey) = _nearestLand(2.0, 2.0);
    _impExitCol = ex;
    _impExitRow = ey;

    // Pazarlık noktası — merkez ile giriş köşesi arasının yarısı (köyün kıyısı).
    final (cx, cy) = _villageCenter();
    final (px, py) =
        _nearestLand(cx + (ex - cx) * 0.5, cy + (ey - cy) * 0.5);
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
      _soldiers.add(ImperialSoldier(
        startCol: sx,
        startRow: sy,
        commander: i == 0,
        backOffset: back,
        sideOffset: side,
        seed: 9001 + i * 137,
      ));
    }

    _imperialPhase = ImperialVisitPhase.approaching;
    AudioManager.instance.playSfx(Sfx.thunderClap);
    _showNotification('⚔️ İmparatorluk heyeti köye doğru ilerliyor…');
  }

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

  /// Darbe anı — seçili kurbanları çökertir (aile bağını kopararak), görünür
  /// şiddet FX'i basar. `_imperialRaidVictims` karar anında seçilmiştir.
  void _strikeRaidVictims() {
    addCameraShake(13.0, dur: 1.0);
    AudioManager.instance.playSfx(Sfx.thunderClap);
    _activeFx.add(ActiveFx(
        const EventEffect(screenTint: Color(0x66AA1414), duration: 1.8), 1.8));
    for (final v in _imperialRaidVictims) {
      if (v.isDying || !_villagers.contains(v)) continue;
      for (final p in v.parents) {
        p.children.remove(v);
      }
      for (final c in v.children) {
        c.parents.remove(v);
      }
      v.startDying(funeral: true);
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
      final tx = cx - _impDirX * (s.backOffset * 0.5) + perpX * (s.sideOffset * 1.4);
      final ty = cy - _impDirY * (s.backOffset * 0.5) + perpY * (s.sideOffset * 1.4);
      s.stepTo(dt, tx, ty,
          dayLight: _cycle.dayLight,
          rainIntensity: _cycle.rainIntensity,
          speedMul: 1.9,
          arriveD: 0.2);
    }
  }

  /// Her askeri çapaya göre formasyon slotuna yürütür (biraz hızlı → kolon sıkı).
  void _moveSoldiersToSlots(double dt) {
    final perpX = -_impDirY, perpY = _impDirX;
    for (final s in _soldiers) {
      final tx = _impAnchorCol - _impDirX * s.backOffset + perpX * s.sideOffset;
      final ty = _impAnchorRow - _impDirY * s.backOffset + perpY * s.sideOffset;
      s.stepTo(dt, tx, ty,
          dayLight: _cycle.dayLight,
          rainIntensity: _cycle.rainIntensity,
          speedMul: 1.25,
          arriveD: 0.12);
    }
  }

  /// Eşikte dizilip beklerler — slotta durup köy merkezine bakarlar.
  void _holdFormation(double dt) {
    final (cx, cy) = _villageCenter();
    final perpX = -_impDirY, perpY = _impDirX;
    for (final s in _soldiers) {
      final tx = _impAnchorCol - _impDirX * s.backOffset + perpX * s.sideOffset;
      final ty = _impAnchorRow - _impDirY * s.backOffset + perpY * s.sideOffset;
      final arrived = s.stepTo(dt, tx, ty,
          dayLight: _cycle.dayLight,
          rainIntensity: _cycle.rainIntensity,
          arriveD: 0.12);
      if (arrived) s.lookToward(cx.toDouble(), cy.toDouble());
    }
  }

  /// Bir sonraki ziyarete kadar süre — refah arttıkça kısalır, itibar arttıkça
  /// uzar (iyi ilişki = daha seyrek/yumuşak baskı).
  double _rollImperialInterval(double prosp) {
    final wealthRush = (prosp / 240.0).clamp(0.0, 1.0); // 0 sakin → 1 iştahlı
    final base = 5.5 - wealthRush * 2.5 + _imperialFavor * 2.5; // ~3.0–8.0 gün
    return (base + _rng.nextDouble() * 1.5) * kGameDaySeconds;
  }

  /// Heyet köy eşiğine vardı — pazarlığı açar. Talep + sinematik + modal kurulur
  /// (sim DURUR). Fiziksel askerler eşikte dizili bekler (parley).
  void _startImperialParley() {
    final demand = _buildImperialDemand(_impProsperity);
    if (demand == null) {
      // Alacak uygun bir şey yok — heyet boş döner (nadir). Doğrudan ayrılışa geç.
      _showNotification('İmparatorluk heyeti alacak bir şey bulamadan döndü.');
      _imperialPhase = ImperialVisitPhase.leaving;
      _setMarchDir(_impExitCol - _impAnchorCol, _impExitRow - _impAnchorRow);
      return;
    }
    _imperialPhase = ImperialVisitPhase.parley;
    AudioManager.instance.playSfx(Sfx.thunderClap); // gümbürtülü giriş
    addCameraShake(6.0, dur: 0.6);
    // Talep modalı arkada hazır; önce GELİŞ sinematiği oynar (bitince modal
    // görünür — ikisi de sim'i duraklatır, sinematik üstte). Sinematik TALEBE +
    // İLİŞKİYE göre dinamik kurulur (#3): komutanın tonu itibara, sözü talebe göre.
    setStateHere(() => _imperialDemand = demand);
    _playCutscene(_buildImperialCutscene(demand));
    _showNotification('⚔️ İmparatorluk vergi heyeti köye geldi');
  }

  /// İmparatorluk geliş sinematiğini TALEBE + İTİBARA göre dinamik kurar (#3).
  /// Süvariler ufuktan gelir; komutanın sözü talebin türünü, tonu da ilişkiyi
  /// (düşman/tarafsız/dostane) yansıtır. Devşirmede ek bir tehdit çekimi.
  /// Mevcut guard sprite'ları asker olarak kullanılır (yeni resim gerekmez).
  Cutscene _buildImperialCutscene(ImperialDemand d) {
    final f = _imperialFavor;
    // İlişki tonuna göre giriş anlatımı.
    final arrival = f < 0.3
        ? 'Ufukta kara bir toz bulutu — bu sefer öfkeyle geliyorlar.'
        : f >= 0.7
            ? 'Ufukta tanıdık sancak — heyet yine kapıya dayandı.'
            : 'Ufukta toz bulutu — toynak sesleri yaklaştı.';
    // Komutanın talebe özel buyruğu.
    final order = switch (d.kind) {
      ImperialDemandKind.goldTax =>
        '${d.amount} altın vergi — kese hemen dolacak.',
      ImperialDemandKind.foodLevy =>
        '${d.amount} ölçek tahıl — ambarınız İmparatorluğa borçlu.',
      ImperialDemandKind.woodLevy =>
        '${d.amount} kütük kereste — ordumuzun kalesi sizin ormanınızdan yükselecek.',
      ImperialDemandKind.conscript =>
        'Köyünüzün en gencini orduya vereceksiniz.',
    };
    // İtibara göre komutanın tehdit tonu.
    final threat = f < 0.3
        ? 'Sabrım kalmadı. Bu kez direnirseniz, geriye kül kalır.'
        : f >= 0.7
            ? 'Hep anlaştık, köylü. Bu seferki de kolay olsun.'
            : 'Borçlar ödenir — şu ya da bu şekilde.';

    return Cutscene([
      CutsceneShot(
        bg: CutsceneBg.valleyDusk,
        panFrom: 0.04,
        panTo: 0.0,
        zoomFrom: 1.02,
        zoomTo: 1.08,
        actors: const [
          CutsceneActor(type: VillagerType.guard, seed: 31, fromX: 1.25, toX: 0.66, y: 0.84, scale: 1.2, flip: true, walk: true),
          CutsceneActor(type: VillagerType.guard, seed: 44, fromX: 1.5, toX: 0.50, y: 0.80, scale: 1.1, flip: true, walk: true),
          CutsceneActor(type: VillagerType.guard, seed: 52, fromX: 1.75, toX: 0.36, y: 0.86, scale: 1.25, flip: true, walk: true),
        ],
        lines: [
          CutsceneLine(arrival),
          const CutsceneLine('İmparatorluğun süvarileri köyün kapısına dayandı.'),
        ],
      ),
      CutsceneShot(
        bg: CutsceneBg.valleyDusk,
        zoomFrom: 1.1,
        zoomTo: 1.0,
        actors: const [
          CutsceneActor(type: VillagerType.guard, seed: 31, fromX: 0.5, y: 0.80, scale: 1.6, flip: true),
        ],
        lines: [
          const CutsceneLine('İmparatorluk vergisini toplamaya geldik.', speaker: 'Komutan'),
          CutsceneLine(order, speaker: 'Komutan'),
          CutsceneLine(threat, speaker: 'Komutan'),
        ],
      ),
      // Devşirme — ek bir ürkütücü çekim: köy gencinin alınması ayrı bir an.
      if (d.isConscript)
        const CutsceneShot(
          bg: CutsceneBg.valleyDusk,
          zoomFrom: 1.0,
          zoomTo: 1.06,
          actors: [
            CutsceneActor(type: VillagerType.guard, seed: 52, fromX: 0.30, y: 0.82, scale: 1.3, flip: true),
            // Küçük ölçekli köylü → genç hissi (ayrı "genç" sprite'ı yok).
            CutsceneActor(type: VillagerType.farmer, seed: 9, fromX: 0.62, y: 0.84, scale: 0.85),
          ],
          lines: [
            CutsceneLine('Komutanın gözü köyün gençlerinde — biri bu ocaktan kopacak.'),
          ],
        ),
    ]);
  }

  /// Talep üret — tür ağırlıklı (refah + itibar talebin sertliğini ölçekler).
  ImperialDemand? _buildImperialDemand(double prosp) {
    final severity = 1.0 + (1.0 - _imperialFavor) * 0.8; // 1.0–1.8
    final pop = _villagers.length;
    final youths = _conscriptCandidates();

    // Tür seçimi: en bol kaynağı tercih eder (oradan koparmak ister); genç
    // devşirme nadir ve yalnız uygun genç varsa.
    final pool = <ImperialDemandKind>[];
    if (_stockpile.gold >= 8) pool.addAll([ImperialDemandKind.goldTax, ImperialDemandKind.goldTax]);
    if (_stockpile.food >= 12) pool.add(ImperialDemandKind.foodLevy);
    if (_stockpile.wood >= 12) pool.add(ImperialDemandKind.woodLevy);
    if (youths.isNotEmpty && pop >= 12) pool.add(ImperialDemandKind.conscript);
    if (pool.isEmpty) pool.add(ImperialDemandKind.goldTax); // hep bir talep çıkar

    final kind = pool[_rng.nextInt(pool.length)];
    int amount;
    switch (kind) {
      case ImperialDemandKind.goldTax:
        amount = (pop * 1.6 * severity).round().clamp(6, 9999);
      case ImperialDemandKind.foodLevy:
        amount = (pop * 2.2 * severity).round().clamp(8, 9999);
      case ImperialDemandKind.woodLevy:
        amount = (pop * 2.0 * severity).round().clamp(8, 9999);
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
      .where((v) =>
          !v.isDying &&
          (v.lifeStage == LifeStage.youth || v.lifeStage == LifeStage.child))
      .toList();

  /// Devşirme fidyesi (altın) — itibar yükseldikçe ucuzlar.
  int _imperialRansomCost() =>
      (_villagers.length * 1.5 + (1.0 - _imperialFavor) * 20).round().clamp(6, 9999);

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
    _chronicle('İmparatorluğun talebi karşılandı: ${d.label}.', icon: '⚔️');
    _showNotification('⚔️ Talep ödendi — köy bu sefer huzurlu kaldı');
    _endImperialVisit(_prosperity());
  }

  void _imperialRansom() {
    final d = _imperialDemand;
    if (d == null || !d.isConscript) return;
    final cost = _imperialRansomCost();
    if (_stockpile.gold < cost) return;
    _stockpile.gold -= cost;
    _imperialFavor = (_imperialFavor + 0.03).clamp(0.0, 1.0);
    _chronicle('Bir genç fidyeyle ($cost★) askere alınmaktan kurtarıldı.',
        icon: '★');
    _showNotification('★ Fidye ödendi — genç köyde kaldı (-$cost★)');
    _endImperialVisit(_prosperity());
  }

  void _imperialHaggle(double frac) {
    final d = _imperialDemand;
    if (d == null || d.isConscript) return;
    // Eşik itibara bağlı: itibar yüksekse düşük teklif bile tutar.
    final threshold = 0.85 - _imperialFavor * 0.45; // favor 1→0.40, 0→0.85
    if (frac >= threshold) {
      final pay = (d.amount * frac).round();
      _spendResource(d.kind, pay);
      _imperialFavor = (_imperialFavor + 0.04).clamp(0.0, 1.0);
      _chronicle('Pazarlık tuttu — ${d.icon} talebi $pay\'a indirildi.',
          icon: '🤝');
      _showNotification('🤝 Pazarlık tuttu — $pay${d.icon} ödendi');
    } else {
      // Tutmadı → komutan öfkelendi: tam öder + itibar düşer.
      _spendResource(d.kind, d.amount);
      _imperialFavor = (_imperialFavor - 0.12).clamp(0.0, 1.0);
      _feelVillage(NpcEmotion.fear, 6, -0.06);
      _chronicle('Pazarlık tutmadı — komutan öfkelendi, tam ödendi.',
          icon: '⚔️');
      _showNotification('⚔️ Pazarlık tutmadı — tam ödemek zorunda kaldın');
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
    final guards = _guardCount();
    final pop = _villagers.length;
    if (guards < 1 && pop < 14) return 0.0; // savunacak güç yok
    final base = 0.12 +
        guards * 0.20 +
        (pop - 10).clamp(0, 20) * 0.015 +
        (_imperialFavor - 0.5) * 0.10; // dostluk pazarlık gücü de verir
    return base.clamp(0.0, 0.85);
  }

  void _imperialResist() {
    final d = _imperialDemand;
    if (d == null) return;
    final chance = _resistChance();
    AudioManager.instance.playSfx(Sfx.thunderClap);
    addCameraShake(9.0, dur: 0.8);
    if (_rng.nextDouble() < chance) {
      // BAŞARI — heyet kovuldu. Ölüm yok; köy gururla doğrulur. İtibar düşer
      // (imparatorluk aşağılandı) ama bir muhafız yara alabilir (bedelsiz değil).
      _imperialFavor = (_imperialFavor - 0.15).clamp(0.0, 1.0);
      _feelVillage(NpcEmotion.joy, 12, 0.14); // zafer gururu
      pushPolicyMorale(0.08, 4.0);
      _nudgeHousesByEstate(Estate.hearth, moodDelta: 0.06, swayGain: 0.05);
      _nudgeHousesByEstate(Estate.laborers, moodDelta: 0.04, swayGain: 0.03);
      // Bir muhafız yaralanabilir — direniş bedavaya gelmez.
      final guards = _villagers
          .where((v) => !v.isDying && v.type == VillagerType.guard)
          .toList();
      if (guards.isNotEmpty && _rng.nextDouble() < 0.5) {
        final g = guards[_rng.nextInt(guards.length)];
        g.injuryDays = 2.0 + _rng.nextDouble() * 2.0;
        g.feel(NpcEmotion.grief, 4.0, moodDelta: -0.08);
      }
      _activeFx.add(ActiveFx(
          const EventEffect(fx: EventFx.festival, duration: 8), 8));
      _chronicle('⚔️ Köy imparatorluk heyetini geri püskürttü — onur kazanıldı.',
          icon: '🛡️', milestone: true);
      _showNotification('🛡️ Direniş tuttu — heyet kovuldu, köy başını dik tuttu!');
    } else {
      // BAŞARISIZ — direniş ezildi. Reddetmekten beter: savunucular (muhafızlar)
      // ön safta düşer. Kurbanlar SEÇİLİR ama ölüm, askerlerin merkeze dalışıyla
      // (raiding) senkron gerçekleşir (bkz. _strikeRaidVictims). Favoriler korunur.
      final victimCount =
          (1 + (1.0 - _imperialFavor).floor() + 1).clamp(1, 3);
      final pool = _villagers.where((v) => !v.isDying && !v.isFavorite).toList();
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
      if (!d.isConscript) _spendResource(d.kind, (d.amount * 0.6).round());
      _imperialFavor = (_imperialFavor - 0.25).clamp(0.0, 1.0);
      _feelVillage(NpcEmotion.fear, 16, -0.22);
      pushPolicyMorale(-0.15, 6.0);
      _chronicle(
          '⚔️ Direniş ezildi — $killed köylü kılıçtan geçti, köy yağmalandı.',
          icon: '⚔️', milestone: true);
      _showNotification('⚔️ Direniş tutmadı — heyet köyü basıyor!');
    }
    _endImperialVisit(_prosperity());
  }

  void _imperialRefuse() {
    final d = _imperialDemand;
    if (d == null) return;
    // Şiddet — talebin sertliğine göre 1–3 kurban (favoriler DAHİL). Kurbanlar
    // SEÇİLİR ama ölüm askerlerin merkeze dalışıyla (raiding) senkron gerçekleşir
    // (bkz. _strikeRaidVictims). Üstüne yağma (kaynağın bir kısmı zorla alınır).
    final severity = 1.0 + (1.0 - _imperialFavor);
    final victimCount = (1 + (severity).floor()).clamp(1, 3);
    final pool = _villagers.where((v) => !v.isDying).toList()..shuffle(_rng);
    _imperialRaidVictims
      ..clear()
      ..addAll(pool.take(victimCount));
    _imperialRaid = true;
    final killed = _imperialRaidVictims.length;
    if (!d.isConscript) _spendResource(d.kind, (d.amount * 0.5).round());
    _imperialFavor = (_imperialFavor - 0.25).clamp(0.0, 1.0);
    _feelVillage(NpcEmotion.fear, 16, -0.22);
    pushPolicyMorale(-0.15, 6.0);
    AudioManager.instance.playSfx(Sfx.thunderClap); // reddetme gümbürtüsü
    _chronicle(
        '⚔️ İmparatorluğa kafa tutuldu — $killed köylü kılıçtan geçirildi.',
        icon: '⚔️', milestone: true);
    _showNotification('⚔️ Reddettin — askerler köye saldırıyor!');
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
    _feelVillage(NpcEmotion.grief, 8, -0.08);
    _chronicle('${v.name} askere alındı — ardından gözyaşları kaldı.',
        icon: '🧑');
  }

  void _endImperialVisit(double prosp) {
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
    // Şiddetle bittiyse önce köy MERKEZİNE yağma dalışı (darbe orada); değilse
    // doğrudan geldikleri köşeye çekilirler.
    if (_imperialRaid) {
      _imperialRaid = false;
      _impStruck = false;
      _impRaidTimer = 3.0; // dalış için üst süre (sim-sn); varınca darbe
      final (cx, cy) = _villageCenter();
      final (rx, ry) = _nearestLand(cx.toDouble(), cy.toDouble());
      _impRaidCol = rx;
      _impRaidRow = ry;
      // Askerler saldırı pozuna geçer — mızrak ileri dürtme + öne atılma.
      for (final s in _soldiers) {
        s.imperialAttacking = true;
      }
      _imperialPhase = ImperialVisitPhase.raiding;
      return;
    }
    _imperialPhase = ImperialVisitPhase.leaving;
    _setMarchDir(_impExitCol - _impAnchorCol, _impExitRow - _impAnchorRow);
  }

  /// Zümre nabzı tabelası için İmparatorluk özeti — köyün İÇ zümrelerinin yanına
  /// eklenen DIŞ güç madalyonunu besler (bkz. [EstateBanner]). Köy iştah çekecek
  /// kadar zengin/kalabalık değilse heyet "uykuda" (watching=false); öyleyse
  /// sayaç tükendikçe ziyaretin yakınlığı (imminence) dolar.
  ImperialSnapshot _imperialSnapshot() {
    final visiting = _imperialPhase != ImperialVisitPhase.idle;
    final watching = _hasFire &&
        _villagers.length >= _kMinPop &&
        _prosperity() >= _kProsperityGate;
    // Yakınlık: ziyaret sürerken dolu; yoksa sayaç ne kadar tükendi (≈8 gün ref).
    const refDays = 8.0;
    final days = _imperialTimer / kGameDaySeconds;
    final imminence = visiting
        ? 1.0
        : (watching ? (1.0 - days / refDays).clamp(0.0, 1.0) : 0.0);
    return ImperialSnapshot(
      favor: _imperialFavor,
      watching: watching || visiting,
      imminence: imminence,
      // Kızıl alarm: heyet yaklaşırken, yağma dalışında veya talep masada.
      active: _imperialPhase == ImperialVisitPhase.approaching ||
          _imperialPhase == ImperialVisitPhase.raiding ||
          _imperialDemand != null,
    );
  }

  /// Pazarlık modal'ı — build Stack'ten çağrılır (_imperialDemand != null iken).
  Widget buildImperialModal() {
    final d = _imperialDemand!;
    final ransom = _imperialRansomCost();
    final canFull = d.isConscript ? true : _resourceOf(d.kind) >= d.amount;
    return ImperialModal(
      demand: d,
      favor: _imperialFavor,
      ransomCost: ransom,
      canAcceptFull: canFull,
      canRansom: _stockpile.gold >= ransom,
      resistChance: _resistChance(),
      onAccept: _imperialAccept,
      onRefuse: _imperialRefuse,
      onRansom: _imperialRansom,
      onHaggle: _imperialHaggle,
      onResist: _imperialResist,
    );
  }
}
