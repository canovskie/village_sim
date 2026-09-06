part of '../../main.dart';

/// SUÇUN İCRASI — başla → evreler (eve gir/çuvalla çık/göm/kaçır) → tamamla/kaç/vazgeç, sonuç etkileri.
extension _SceneCrimeAct on _VillageSceneState {

  // ══════════════════════════════════════════════════════════════════════════
  // EVRELER — sokul → yap → kaç
  // ══════════════════════════════════════════════════════════════════════════

  /// Suçu başlat: fail hedefe SİNSİCE yollanır. Köy yalnız bir kıpırtı sezer —
  /// ipucu YER söyler, İSİM söylemez (faili bulmak oyuncunun işi).
  void _beginCrime(_ActiveCrime c) {
    final v = c.culprit;
    v.activity = VillagerActivity.prowling;
    v.hasteFactor = 1.15;
    v.chatBubbleIcon = ''; // sinsi: eylem başlayana kadar baloncuk YOK
    v.chatBubbleTime = 0;
    v.goTo(c.tx, c.ty, c.def.actSeconds);
    _activeCrime = c;
    _chaseRefresh = 0;
    _crimeNoticed = 0;
    _crimesSeen++; // köyün hafızası — NİZAM hükümlerinin kapısı bunu okur

    // Ağır suçta köy hafiften ürperir (sezgi) — hafif suçta sarsıntı yok.
    if (c.def.isGrave) addCameraShake(1.6, dur: 0.3);
    _showNotification(
      Voice.say(
        c.def.hintPool,
        _voice(
          null,
          seed: _stableSeed('ipucu${c.kind.name}${v.name}', _dayCount),
          extra: {'yer': c.place},
        ),
      ),
    );
  }

  void _advanceCrime(double dt) {
    final c = _activeCrime!;
    final v = c.culprit;

    // Fail bir şekilde sahneden düştüyse (öldü/uyudu/taşındı) suç düşer.
    //
    // `isInsideBuilding` ARTIK tek başına "sahneden düştü" demek değil: Faz 4'te
    // hırsız soyduğu binaya BİLEREK girer ve o sırada görünmez olur (`c.inside`).
    // Bu ayrım olmadan fail kapıdan girdiği karede suç iptal ediliyordu — sahne
    // "içeri girdi" ânında sessizce ölüyordu.
    if (v.isDying || v.isSleeping || (v.isInsideBuilding && !c.inside)) {
      _abortCrime();
      return;
    }

    c.phaseLeft -= dt;

    // Suç yürürken aktörlerin SAHİBİ burasıdır: gövde dilini her tick yeniden
    // dayat. Aksi hâlde başka sistemler aktiviteyi elinden alır — baloncuk
    // süresi dolunca scene_tick activity'yi none'a çekiyor ve fail eylemin
    // ortasında sinsi/telaşlı duruşunu kaybediyordu (telemetride görüldü:
    // act=committing → act=none). Aktivite = suçun evresi, tek doğruluk.
    v.activity = switch (c.phase) {
      _CrimePhase.prowl => VillagerActivity.prowling,
      _CrimePhase.act => VillagerActivity.committing,
      _CrimePhase.flee => VillagerActivity.fleeing,
    };
    // ÇUVAL da aynı sözleşmeye tabi: mal alındıysa ve henüz gömülmediyse yük
    // failin elindedir. Başka sistemler (scene_work/scene_jobs) prop'u
    // temizlemeye çalışır; tek doğruluk burasıdır.
    if (c.kind == CrimeKind.theft &&
        (c.lootAmount > 0 || c.weaponAmount > 0) &&
        !c.buried) {
      v.prop = PropKind.sack;
    }
    final vic = c.victim;
    if (c.kind == CrimeKind.abduction &&
        !c.done &&
        c.phase == _CrimePhase.act &&
        vic != null &&
        !vic.isDying) {
      vic.activity = VillagerActivity.abducted;
    }

    switch (c.phase) {
      case _CrimePhase.prowl:
        // Kurban kımıldıyorsa peşinden git (hedef canlıysa taze konum).
        if (vic != null && !vic.isDying) {
          c.tx = vic.gridX;
          c.ty = vic.gridY;
          if (!_enRouteTo(v, c.tx, c.ty)) v.goTo(c.tx, c.ty, c.def.actSeconds);
        }
        if (_wdist(v.gridX, v.gridY, c.tx, c.ty) <= 1.4) {
          _enterActPhase(c);
        } else if (c.phaseLeft <= 0) {
          _abortCrime(); // varamadı — vazgeçti (takılma güvenliği)
        }

      case _CrimePhase.act:
        if (c.kind == CrimeKind.abduction) {
          // Kaçırma "eylemi" = kurbanı köyün dışına SÜRÜKLEME. Kurban peşinde.
          if (vic == null || vic.isDying) {
            _abortCrime();
            return;
          }
          // Kurbanı failin yanına LERP'le (hard-set değil) — fail yön değiştirince
          // ±0.55 işareti dönüp kurban bir yandan öbürüne ışınlanıyordu.
          final tvx = v.gridX + (v.facingRight ? -0.55 : 0.55);
          final tvy = v.gridY + 0.25;
          final k = (dt * 6.0).clamp(0.0, 1.0);
          vic.gridX += (tvx - vic.gridX) * k;
          vic.gridY += (tvy - vic.gridY) * k;
          vic.targetCol = vic.gridX;
          vic.targetRow = vic.gridY;
          vic.state = VillagerState.idle;
          vic.idleTimer = 1.0;
          if (_wdist(v.gridX, v.gridY, c.tx, c.ty) <= 1.2 || c.phaseLeft <= 0) {
            _completeCrime(c);
          }
        } else if (c.inside) {
          // İÇERİDE — köy kapıyı izliyor. Süre dolunca çuvalla çıkar.
          c.insideLeft -= dt;
          v.isInsideBuilding = true; // sahip BURASI: uyanma/rutin geri açmasın
          if (c.insideLeft <= 0 || c.phaseLeft <= 0) _emergeWithLoot(c);
        } else if (c.phaseLeft <= 0) {
          _completeCrime(c);
        }

      case _CrimePhase.flee:
        // HIRSIZLIK — kaçış bir yere doğrudur: zulanın gömüleceği nokta.
        // Varınca eğilip gömer; mal buharlaşmaz, toprağa geçer.
        if (c.kind == CrimeKind.theft &&
            !c.buried &&
            (c.lootAmount > 0 || c.weaponAmount > 0)) {
          if (_wdist(v.gridX, v.gridY, c.bx, c.by) <= 1.2) {
            v.state = VillagerState.idle;
            v.targetCol = v.gridX;
            v.targetRow = v.gridY;
            v.actPose = ActPose.stoop;
            c.buryProgress += dt;
            v.idleTimer = _SceneCrime._kBurySeconds - c.buryProgress + 0.2;
            if (c.buryProgress >= _SceneCrime._kBurySeconds) _buryLoot(c);
          } else if (!_enRouteTo(v, c.bx, c.by)) {
            v.goTo(c.bx, c.by, 0.5);
          }
        }
        if (c.phaseLeft <= 0) {
          // Gömmeye yetişemediyse çuval elinde kalır — `_escapeCrime` onu
          // zulaya çevirir (mal ortada kalmaz).
          _escapeCrime(c); // kaçtı — fail meçhul
        }
    }
  }

  /// Hedefe vardı — eylem başlıyor. Baloncuk ANCAK burada çıkar (kısa aksan).
  void _enterActPhase(_ActiveCrime c) {
    final v = c.culprit;
    c.phase = _CrimePhase.act;
    v.activity = VillagerActivity.committing;
    v.hasteFactor = 1.0;

    // HIRSIZLIK — kapıdan İÇERİ girer (Faz 4). Tanıklık burada TETİKLENMEZ:
    // içeride görülecek bir şey yok, görülen an çuvalla çıkıştır
    // (bkz. [_emergeWithLoot]). Eskiden fail kapının önünde dikilip bekliyordu
    // ve "hırsızlık komik görünüyor" şikâyetinin kaynağı buydu.
    if (c.kind == CrimeKind.theft && c.building != null) {
      _enterBuildingToSteal(c);
      return;
    }

    // TANIKLIK — eylem anı, suçun görülebildiği tek an. Kim o yöne bakıyorsa
    // GERÇEKTEN görür (bkz. scene_perception); gören hatırlar, hatırlayan
    // devriyeye koşabilir. Öncesinde suçun tek "görüleni" muhafızdı.
    final witnesses = _witnessEvent(
      Notion.crime,
      x: c.tx,
      y: c.ty,
      subject: v,
      subjectName: v.name,
      exclude: c.victim == null ? const [] : [c.victim!],
    );
    _stageCrimeWitnesses(witnesses, c.tx, c.ty);

    if (c.kind == CrimeKind.abduction) {
      // Kurbanı kavra, köyün dışına yönel — uzun, görünür bir sürükleme.
      final vic = c.victim!;
      // Kurban prowl sırasında porter olmuş olabilir. Sürükleme doğrudan
      // state/konum sahibi olmadan önce yükü grab noktasına güvenle bırak.
      vic.cancelCarryTask();
      vic.activity = VillagerActivity.abducted;
      vic.feel(NpcEmotion.fear, 12.0, moodDelta: -0.25);
      final (ex, ey) = _abductionExit(v);
      c.tx = ex;
      c.ty = ey;
      c.phaseLeft = 30.0; // sürükleme penceresi (yakalama şansı uzun)
      v.hasteFactor = 0.8; // yüklü: yavaş — bu yüzden yakalanabilir
      v.goTo(ex, ey, 1.0);
      _reactNearby(
        v.gridX,
        v.gridY,
        6.0,
        NpcEmotion.fear,
        3.0,
        moodDelta: -0.03,
        alarm: 0.30,
      );
      addCameraShake(3.0, dur: 0.4);
      return;
    }

    c.phaseLeft = c.def.actSeconds;
    v.lookToward(c.tx, c.ty);
    // Fail yalnız "telaşlanan NPC" olmasın: suçun nesnesi ve işi gövdede
    // görünür. Temizliği bütün suç çıkışlarında [_clearCrimeState] yapar.
    v.prop = switch (c.kind) {
      CrimeKind.arson => PropKind.torch,
      CrimeKind.vandalism || CrimeKind.poaching => PropKind.axe,
      _ => PropKind.none,
    };
    v.actPose = switch (c.kind) {
      CrimeKind.vandalism || CrimeKind.poaching => ActPose.labor,
      CrimeKind.pickpocket || CrimeKind.fraud => ActPose.stoop,
      _ => ActPose.stand,
    };
    // Eylem yerinde dursun (wander eylemin ortasında kaçırmasın).
    v.state = VillagerState.idle;
    v.targetCol = v.gridX;
    v.targetRow = v.gridY;
    v.idleTimer = c.def.actSeconds;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HIRSIZLIK SAHNESİ (Faz 4) — eve gir → çuvalla çık → göm
  // ══════════════════════════════════════════════════════════════════════════


  /// Fail kapıdan içeri girer — sprite kaybolur, köy kapıyı izler.
  void _enterBuildingToSteal(_ActiveCrime c) {
    final v = c.culprit;
    c.inside = true;
    c.insideLeft = _SceneCrime._kInsideSeconds;
    c.phaseLeft = _SceneCrime._kInsideSeconds + 2.0; // güvenlik payı (takılma koruması)
    // Görünmez ol + yerinde çakıl: dışarıda bir yerde "yürüyor" gibi kalmasın.
    v.isInsideBuilding = true;
    v.state = VillagerState.idle;
    v.targetCol = v.gridX;
    v.targetRow = v.gridY;
    v.idleTimer = c.phaseLeft;
    // Kapının kapanışı — girişi GÖREN olabilir (kapıda bir kıpırtı), ama bu
    // zayıf bir izlenim: suçu değil, "birinin girdiğini" hatırlatır.
    _reactNearby(
      v.gridX,
      v.gridY,
      3.5,
      NpcEmotion.wonder,
      2.0,
      moodDelta: -0.01,
    );
  }

  /// Fail çuvalla dışarı çıkar — sahnenin GÖRÜLEN anı.
  ///
  /// Tanıklık burada tetiklenir: kapıdan çuvalla çıkan adam, suçun tek
  /// tartışmasız görüntüsüdür. Mal da burada köyün stoğundan eksilir — yani
  /// "çuval" boş bir görsel değil, elindeki şey gerçekten o mal.
  void _emergeWithLoot(_ActiveCrime c) {
    final v = c.culprit;
    c.inside = false;
    c.insideLeft = 0;
    v.isInsideBuilding = false;

    // Mal eksilir (lootKind/lootAmount burada dolar) → çuval gerçek yük olur.
    _completeCrime(c);

    // Yük ELDE görünür + yürüyüş yavaşlar (`VillagerEntity.speed` propFactor'ü
    // zaten okur). "Çuvalla kaçan hırsız yakalanabilir olmalı" sözleşmesi.
    v.prop = PropKind.sack;
    v.actPose = ActPose.stoop;

    // TANIKLIK — asıl an. Kim o yöne bakıyorsa gerçekten görür.
    final witnesses = _witnessEvent(
      Notion.crime,
      x: v.gridX,
      y: v.gridY,
      subject: v,
      subjectName: v.name,
    );
    _stageCrimeWitnesses(witnesses, v.gridX, v.gridY);
    _reactNearby(
      v.gridX,
      v.gridY,
      5.0,
      NpcEmotion.wonder,
      3.0,
      moodDelta: -0.02,
      alarm: 0.20,
    );
  }

  /// Zulayı topraga göm — mal dünyada KALIR, yeri değişir.
  void _buryLoot(_ActiveCrime c) {
    final v = c.culprit;
    c.buried = true;
    final kind = c.lootKind;
    final amount = c.lootAmount;
    v.prop = PropKind.none;
    v.actPose = null;
    if (kind == null || (amount <= 0 && c.weaponAmount <= 0)) return;

    final cache = LootCache(
      gridX: v.gridX,
      gridY: v.gridY,
      kind: kind,
      amount: amount,
      culprit: v,
      culpritName: v.name,
      weaponAmount: c.weaponAmount,
    );
    _lootCaches.add(cache);

    // Gömme anı da görülebilir — toprağı eşeleyen adam şüphe uyandırır. GÖREN
    // OLDUYSA zula fiilen ele geçmiştir: köy yeri kabaca bilir ve iz kapansa da
    // oraya bakar. Hırsızın asıl hatası "nereye gömdüğü" değil, görülmesidir.
    final seen = _witnessEvent(
      Notion.crime,
      x: v.gridX,
      y: v.gridY,
      subject: v,
      subjectName: v.name,
    );
    _stageCrimeWitnesses(seen, v.gridX, v.gridY);
    cache.witnessed = seen.isNotEmpty;
  }

  /// Zulanın gömüleceği nokta — köy merkezinden UZAK, failin kaçış yönünde.
  /// Meydanın ortasına gömen hırsız komik olurdu; kenar mahalle/ağaç dibi arar.
  (double, double) _buryTarget(VillagerEntity v) {
    final (cc, cr) = _villageCenter();
    var dx = v.gridX - cc, dy = v.gridY - cr;
    final len = sqrt(dx * dx + dy * dy);
    if (len < 0.5) {
      dx = 1;
      dy = 0;
    } else {
      dx /= len;
      dy /= len;
    }
    // Köyün ETEĞİ — meydanın ortası komik olurdu, vahşi doğa ise ölü nokta:
    // 9-15 tile'da kimse geçmiyordu ve zula fiilen hiç bulunmuyordu (10 günlük
    // provada sıfır). Eşik, "gizli ama köyün ayak izine değen" mesafe.
    final dist = 5.5 + _rng.nextDouble() * 4.0;
    // Yönü hafifçe savur — her hırsız aynı hatta gömmesin.
    final jitter = (_rng.nextDouble() - 0.5) * 0.8;
    final ang = atan2(dy, dx) + jitter;
    final tx = (v.gridX + cos(ang) * dist).clamp(2.0, kCols - 3.0);
    final ty = (v.gridY + sin(ang) * dist).clamp(2.0, kRows - 3.0);
    return _nearestLand(tx, ty);
  }

  /// Köyün dışına açılan bir kaçırma çıkışı — merkezden ters yöne, karaya.
  (double, double) _abductionExit(VillagerEntity v) {
    final (cc, cr) = _villageCenter();
    var dx = v.gridX - cc, dy = v.gridY - cr;
    final len = sqrt(dx * dx + dy * dy);
    if (len < 0.5) {
      dx = 1;
      dy = 0;
    } else {
      dx /= len;
      dy /= len;
    }
    final tx = (v.gridX + dx * 14).clamp(2.0, kCols - 3.0);
    final ty = (v.gridY + dy * 14).clamp(2.0, kRows - 3.0);
    return _nearestLand(tx, ty);
  }

  /// Suç TAMAMLANDI — etkiler uygulanır, fail kaçışa geçer (hâlâ yakalanabilir).
  void _completeCrime(_ActiveCrime c) {
    c.done = true;
    _applyCrimeEffects(c);

    final v = c.culprit;
    // Kaçış: korku postürü + hızlanma + köyden uzağa koş.
    c.phase = _CrimePhase.flee;
    c.phaseLeft = _SceneCrime._kFleeSeconds;
    v.activity = VillagerActivity.fleeing;
    v.hasteFactor = 1.35;
    v.feel(NpcEmotion.fear, _SceneCrime._kFleeSeconds, moodDelta: -0.05);
    if (c.kind != CrimeKind.theft) {
      v.prop = PropKind.none;
      v.actPose = null;
    }

    // HIRSIZLIK — kaçış rastgele "uzağa" değil, ZULAYA doğrudur. Yükü olan
    // hırsızın gidecek bir yeri vardır; kaçış penceresi de bu yüzden uzun
    // (yüklü ve yavaş: yakalanabilir olmalı).
    if (c.kind == CrimeKind.theft && (c.lootAmount > 0 || c.weaponAmount > 0)) {
      final (bx, by) = _buryTarget(v);
      c.bx = bx;
      c.by = by;
      c.phaseLeft = _SceneCrime._kFleeSeconds * 2.2;
      v.goTo(bx, by, 0.5);
      return;
    }

    final (fx, fy) = _fleeTarget(v);
    v.goTo(fx, fy, 2.0);
  }

  /// Failin kaçacağı nokta — olay yerinden ters yöne, evine doğru.
  (double, double) _fleeTarget(VillagerEntity v) {
    final home = v.homeBuilding;
    if (home is BuildingEntity) {
      final spot = _ringSpot(home.col, home.row, home.cols, home.rows, v);
      if (spot != null) return spot;
    }
    final (cc, cr) = _villageCenter();
    return _nearestLand(
      (v.gridX + (v.gridX - cc).sign * 6).clamp(2.0, kCols - 3.0),
      (v.gridY + (v.gridY - cr).sign * 6).clamp(2.0, kRows - 3.0),
    );
  }

  /// Suçun somut sonuçları — mal eksilir, bina yanar, kurban zarar görür.
  void _applyCrimeEffects(_ActiveCrime c) {
    final v = c.culprit;
    final vic = c.victim;

    switch (c.kind) {
      case CrimeKind.theft:
        // Depodan mal aşırır — köyün elinde ne varsa oradan. HANGİ mal ve NE
        // KADAR olduğu artık kayda geçer (`lootKind`/`lootAmount`): çuvalın
        // içi gerçek olmalı ki gömülünce zulaya, yakalanınca köye dönebilsin.
        final want = 6 + _rng.nextInt(9);
        final kind = (_stockpile.food >= want && _rng.nextBool())
            ? ResourceKind.food
            : (_stockpile.wood >= want
                  ? ResourceKind.wood
                  : ResourceKind.stone);
        // Olmayan malı çalamaz — çuval stokta GERÇEKTEN olan kadarını taşır.
        final amount = want.clamp(0, _stockpile.get(kind));
        if (amount > 0) _stockpile.add(kind, -amount);
        c.lootKind = kind;
        c.lootAmount = amount;
        if (amount > 0 && _stockpile.weapons > 0 && _rng.nextDouble() < 0.18) {
          c.weaponAmount = 1;
          _stockpile.weapons--;
        }
        // Silah ayrı stok alanında olsa da aynı çuvalın parçasıdır. Prova
        // topraktaki ve geri alınan toplamla aynı birimi saymalı.
        kProbeTheftTaken += amount + c.weaponAmount;
        v.wealth += amount * 1.5;

      case CrimeKind.pickpocket:
        final amt = vic == null ? 0.0 : (vic.wealth * 0.35).clamp(4.0, 40.0);
        if (vic != null) {
          vic.wealth = (vic.wealth - amt).clamp(0.0, 1e9);
          vic.feel(NpcEmotion.anger, 4.0, moodDelta: -0.08);
        }
        v.wealth += amt;

      case CrimeKind.vandalism:
        // Tamir köyün sırtına biner.
        _stockpile.wood = (_stockpile.wood - 8).clamp(0, 1 << 30);
        if (c.building case final b?) {
          b.damage = b.damage < 0.28 ? 0.28 : b.damage;
        }
        _feelVillage(NpcEmotion.anger, 6, -0.04);

      case CrimeKind.poaching:
        final a = c.animal;
        if (a != null && !a.isDying) a.isDying = true;
        v.wealth += 14;

      case CrimeKind.fraud:
        final amt = 6 + _rng.nextInt(10);
        _stockpile.gold = (_stockpile.gold - amt).clamp(0, 1 << 30);
        v.wealth += amt.toDouble();

      case CrimeKind.slander:
        if (vic != null) {
          vic.feel(NpcEmotion.grief, 6.0, moodDelta: -0.14);
          _formGrudge(v, vic); // iftira karşılıklı küslük doğurur
          if (vic.surname.isNotEmpty) {
            _houses.nudge(vic.surname, moodDelta: -0.05);
          }
        }

      case CrimeKind.arson:
        final b = c.building;
        if (b != null) {
          b.damage = b.damage < 0.82 ? 0.82 : b.damage;
          _burningBuildings.add(b);
          const dur = 14.0;
          _activeFx.add(
            ActiveFx(
              const EventEffect(
                fx: EventFx.fireOutbreak,
                screenTint: Color(0x18FF6020),
                duration: dur,
              ),
              dur,
            ),
          );
        }
        _stockpile.wood = (_stockpile.wood - 14).clamp(0, 1 << 30);
        _feelVillage(NpcEmotion.fear, 10, -0.12);
        addCameraShake(6.0, dur: 0.6);

      case CrimeKind.assault:
        if (vic != null) {
          _injureVillager(vic, feud: false, intensity: 1.0);
          _reactNearby(
            vic.gridX,
            vic.gridY,
            6.0,
            NpcEmotion.fear,
            3.0,
            moodDelta: -0.04,
            alarm: 0.45,
          );
        }
        _feelVillage(NpcEmotion.fear, 8, -0.08);
        addCameraShake(5.0, dur: 0.5);

      case CrimeKind.abduction:
        if (vic != null) _takeCaptive(vic);

      case CrimeKind.assassination:
        if (vic != null) _assassinate(v, vic);
    }

    // Köy zararı fark eder — ama faili GÖRMEZ (isim geçmez).
    final ctx = _voice(
      null,
      other: vic,
      seed: _stableSeed('suç${c.kind.name}${v.name}', _dayCount),
      extra: {'yer': c.place},
    );
    _showNotification(Voice.say(c.def.deedPool, ctx));
  }

  /// Kaçırılan kurban sahneden çekilir (ÖLÜM DEĞİL — çöküş animasyonu yok) ve
  /// fidye dilekçesi gelir.
  ///
  /// Aile bağları TEK YÖNLÜ koparılır: sahnedeki akrabaların listelerinden
  /// çıkarılır (sahne dışı bir varlığa dangling referans kalmasın), ama rehinin
  /// KENDİ parents/children listeleri korunur — fidye ödenirse bağlar buradan
  /// birebir geri kurulur ([_payRansom]). Aksi hâlde köylü ailesiz dönerdi.
  ///
  /// Kayıt sözleşmesi: rehin kaydedilmez; kayıttan dönüldüğünde fidye dilekçesi
  /// düşer ve köylü kaybolmuş sayılır (bkz. scene_save).
  void _takeCaptive(VillagerEntity v) {
    v.activity = VillagerActivity.none;
    v.chatBubbleIcon = '';
    v.chatBubbleTime = 0;
    for (final p in v.parents) {
      p.children.remove(v);
    }
    for (final c in v.children) {
      c.parents.remove(v);
    }
    _villagers.remove(v);
    _forgetVillager(v);
    _ransomVictim = v; // _forgetVillager SONRASI — o da bu işaretçiyi temizler
    _feelVillage(NpcEmotion.fear, 12, -0.14);
    if (v.surname.isNotEmpty) _houses.nudge(v.surname, moodDelta: -0.08);

    // Fidye haberi köye ulaşır. Masada başka karar varsa onu ezmeden merkezi
    // sıraya girer; ayrı bir takip kuyruğunda aynı işi ikinci kez modellemez.
    _requestSystemPetition(PetitionIds.ransom);
  }

  /// Suikast — kurban ölür. Fail MEÇHUL kaldığı için kan davası doğmaz (aileler
  /// kimden hesap soracağını bilmez); yakalanırsa Meclis'te hesap görülür.
  void _assassinate(VillagerEntity killer, VillagerEntity victim) {
    for (final p in victim.parents) {
      p.children.remove(victim);
    }
    for (final c in victim.children) {
      c.parents.remove(victim);
    }
    _markDeathHouse(victim);
    victim.startDying(funeral: true);
    killer.feel(NpcEmotion.fear, 6.0, moodDelta: -0.10);
    _feelVillage(NpcEmotion.grief, 14, -0.20);
    pushPolicyMorale(-0.10, 5.0);
    addCameraShake(8.0, dur: 0.8);
    _activeFx.add(
      ActiveFx(
        const EventEffect(screenTint: Color(0x40AA1414), duration: 1.6),
        1.6,
      ),
    );
  }

  /// Suç kaçtı — fail meçhul. Sicile YAZILMAZ (köy failini bilmiyor); yalnız
  /// şüphe birikir. Eşik aşılınca asayiş dilekçesi gelir.
  void _escapeCrime(_ActiveCrime c) {
    final v = c.culprit;

    // Çuval elinde kaçtıysa (gömmeye yetişemedi) mal ORTADA KALMAZ: bulunduğu
    // yere gömülmüş sayılır. Aksi hâlde `_clearCrimeState` çuvalı silerdi ve
    // çalınan mal sessizce buharlaşırdı — geri alınabilirlik sözleşmesi kırılır.
    if (c.kind == CrimeKind.theft &&
        !c.buried &&
        (c.lootAmount > 0 || c.weaponAmount > 0)) {
      _buryLoot(c);
    }

    // TANIK VAR MI? Kaçan fail "meçhul" sayılır ama köyün onu GERÇEKTEN
    // görmemiş olması gerekir. Gözüyle gören biri varsa fail artık meçhul
    // değildir: tanığın hafızasında adı vardır, dedikoduyla yayılır ve o kişi
    // devriyeye koşabilir (bkz. scene_perception). Şüphe sayacı da bu yüzden
    // yalnız GERÇEKTEN kimsenin görmediği suçlarda artar — eskiden her kaçan
    // suç, köyde kimse yokken bile paniğe dönüşüyordu.
    var witnessed = false;
    for (final o in _villagers) {
      if (identical(o, v)) continue;
      if (o.memory.suspects(v)) {
        witnessed = true;
        break;
      }
    }

    _clearCrimeState(v);
    v.crimeCooldown = _SceneCrime._kCrimeCooldown;
    _activeCrime = null;

    // HANE SİCİLİ (NİZAM) — meçhul suç diye bir şey kalmaz. Her hane deftere
    // yazılı olduğundan kaçan fail sicilden teşhis edilir ve doğrudan yargıya
    // çıkar; köy paniğe kapılmaz (şüphe birikmez). Bedeli defterdeydi: sayılan
    // köy, sayıldığını bilir.
    if (_policies.sealed.contains('nizam.registry') && !v.isDying) {
      _chronicle(
        Voice.say(const [
          '📖 Fail kaçtı ama sicil onu ele verdi: {ad}. Kayıtlı köyde iz kalır.',
          '📖 Sabaha kalmadan sicile bakıldı; {ad-in} adı çıktı. Meçhul suç yok artık.',
        ], _voice(v, seed: _stableSeed('sicil${v.name}', _dayCount))),
        icon: '📖',
        milestone: c.def.isGrave,
        kind: ChronicleKind.crisis,
      );
      _openVerdict(v, c, prevented: false, guard: null);
      return;
    }

    // Kimse görmediyse köy karanlıkta kalır → şüphe birikir. Gören varsa köy
    // "kim olduğunu biliyor", panik değil kanaat oluşur.
    if (!witnessed) {
      _crimeSuspicion++;
    } else {
      _showNotification(
        '👁️ Fail kaçtı ama gören oldu — köy adını fısıldıyor.',
      );
    }
    _chronicle(
      Voice.say(
        c.def.annalPool,
        _voice(
          null,
          seed: _stableSeed('meçhul${c.kind.name}$_dayCount', _dayCount),
        ),
      ),
      icon: c.def.icon,
      milestone: c.def.isGrave,
      kind: ChronicleKind.crisis,
    );
    _showNotification(
      Voice.say(
        _SceneCrime._kEscapedPool,
        _voice(null, seed: _stableSeed('kaçtı${v.name}', _dayCount)),
      ),
    );

    if (_crimeSuspicion >= _SceneCrime._kSuspicionThreshold) {
      _feelVillage(NpcEmotion.fear, 10, -0.05);
      _showNotification(
        Voice.say(
          _SceneCrime._kSuspicionPool,
          _voice(null, seed: _stableSeed('şüphe$_crimeSuspicion', _dayCount)),
        ),
      );
      _requestSystemPetition(PetitionIds.crimeWave);
    }
  }

  /// Suç, hedefe varılamadığı için düştü (kimse görmedi, kimse zarar görmedi).
  void _abortCrime() {
    final c = _activeCrime;
    if (c == null) return;
    // MAL BUHARLAŞMAZ. İptal, suçun en sessiz çıkışıdır (fail uyudu, öldü,
    // hedefe varamadı) ve çuval elindeyken buradan geçilirse `_clearCrimeState`
    // onu siler: stoktan düşmüş ama dünyada hiçbir yerde olmayan bir mal kalır.
    // Gece bastırıp kaçan hırsız uykuya daldığında tam olarak bu oluyordu.
    if (c.kind == CrimeKind.theft &&
        !c.buried &&
        (c.lootAmount > 0 || c.weaponAmount > 0)) {
      _buryLoot(c); // bulunduğu yere gömülmüş sayılır — geri alınabilir kalır
    }
    _clearCrimeState(c.culprit);
    c.culprit.crimeCooldown = _SceneCrime._kCrimeCooldown * 0.5;
    final vic = c.victim;
    if (vic != null && vic.activity == VillagerActivity.abducted) {
      vic.activity = VillagerActivity.none;
    }
    _activeCrime = null;
  }

  /// Failin/muhafızın suç durum alanlarını temizler (aktivite + telaş + baloncuk).
  void _clearCrimeState(VillagerEntity v) {
    v.activity = VillagerActivity.none;
    v.hasteFactor = 1.0;
    v.chatBubbleIcon = '';
    v.chatBubbleTime = 0;
    // Faz 4'ün YAPIŞKAN alanları. Suç hangi kapıdan biterse bitsin (kaçtı,
    // yakalandı, iptal) bunlar sıfırlanmalı: temizlenmeyen `isInsideBuilding`
    // köylüyü kalıcı GÖRÜNMEZ yapar (sprite hiç çizilmez), temizlenmeyen çuval
    // ise onu ömür boyu yavaş yürütür.
    v.isInsideBuilding = false;
    v.prop = PropKind.none;
    v.actPose = null;
    for (final g in _villagers) {
      if (g.activity == VillagerActivity.chasing) {
        g.activity = VillagerActivity.none;
        g.hasteFactor = 1.0;
        g.chatBubbleIcon = '';
        g.chatBubbleTime = 0;
      }
    }
  }
}
