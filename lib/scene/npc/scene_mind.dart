part of '../main.dart';

/// KÖYLÜNÜN AKLI — sahne tarafı: dürtüleri dünyadan besler, teklifleri toplar,
/// hakemi çalıştırır.
///
/// **Faz 1'in tek cümlesi:** sistemler köylüyü artık KAPMIYOR.
///
/// Eskiden `scene_tick` içindeki ~15 sistem sırayla köylülere uzanıp
/// `if (v.activity == none) { onu al }` diyordu. Kazanan, o karede tick
/// sırasında önce gelendi — yani köylünün ne yaptığının sebebi kendisi değil,
/// dosya sırasıydı. Karikatür hissinin kökü buydu.
///
/// Şimdi her sistem bir TEKLİF verir ([Bid]); hakem ([VillagerMind.deliberate])
/// dürtü + dünya basıncı + kişilikten doğan puana göre kazananı seçer ve YALNIZ
/// onu çalıştırır. Kaybeden sistem köylüye dokunmaz.
///
/// İş bölümü: **akıl karar verir, sistemler yürütür.** Bir sistemin köylüye
/// dokunmadan önce sorması gereken tek soru `v.mind.owns(...)`.
extension _SceneMind on _VillageSceneState {
  /// Bir köylünün iki müzakeresi arasındaki taban süre (sn). Her karede
  /// düşünmek hem pahalı hem de "her an fikir değiştiren" köylü üretir.
  static const double _kDeliberate = 1.4;

  /// Dürtü tazeleme aralığı (sn) — müzakereden ayrı ve daha sık, çünkü
  /// dürtülerin sönmesi (ateş başında ısınmak, sofrada doymak) sürekli olmalı.
  static const double _kDriveScan = 0.5;

  /// Ateş başında oturma süresi (sn) — scene_firepit_gather'daki toplu
  /// toplanmayla aynı aralık; iki yol da aynı süreyi versin diye burada
  /// tekrarlanır (extension private statiklerine dışarıdan erişilemez).
  static const double _kMindSitMin = 22.0;
  static const double _kMindSitMax = 40.0;

  void _tickMind(double dt) {
    _driveScan += dt;
    final driveStep = _driveScan >= _kDriveScan;
    if (driveStep) _driveScan = 0;

    for (final v in _villagers) {
      v.mind.tick(dt);
      if (driveStep) _tickDrives(v, _kDriveScan);
    }

    // Suç iklimi köy GENELİNE aittir — köylü başına değil, tur başına bir kez
    // hesaplanır. (`_crimePressure` muhafız listesi ayırdığı için her köylüde
    // çağırmak tur başına onlarca gereksiz alloc demekti.)
    _crimeClimate = _activeCrime == null ? _crimePressure() : 0;

    for (final v in _villagers) {
      if (v.mind.deliberateIn > 0) continue;
      // Serpintili aralık — köy tek ağızdan karar vermesin.
      v.mind.deliberateIn = _kDeliberate * (0.7 + _rng.nextDouble() * 0.7);
      _expireIntent(v);
      if (!_canDeliberate(v)) continue;
      final beforeKind = v.mind.intent.kind;
      final beforeAct = v.act;
      final bids = _collectBids(v);
      if (v.mind.deliberate(bids) && v.mind.intent.kind != beforeKind) {
        // Niyet değişti → yürüyen mikro-sahne düşer ve ELDEKİ NESNE BIRAKILIR.
        // Aksi hâlde köylü ömür boyu dolu kovayla dolaşırdı (bkz. scene_act).
        //
        // Dikkat: kazanan teklifin `begin`'i bu noktada YENİ bir eylem kurmuş
        // olabilir; iptal edilecek olan ESKİSİDİR. Yeni eylemi silmemek için
        // kimlik karşılaştırması şart.
        if (beforeAct != null && identical(v.act, beforeAct)) {
          _cancelAct(v);
        } else if (beforeAct != null) {
          // Yeni bir eylem kuruldu; eski eylemin elde bıraktığı yükü temizle.
          v.actPose = null;
          if (v.act == null) v.prop = PropKind.none;
        } else {
          // Eski niyet act'siz bir İŞ DURUŞU bırakmış olabilir (scene_work/
          // scene_jobs; bkz. _setWorkPose): niyet değişti, o duruşu ve aletini
          // temizle — aksi hâlde değirmenden ayrılan köylü elde nesneyle/eğik
          // yürürdü. Yeni niyet errand'sa scene_act ilk iş adımında yeniden
          // set eder; başka bir iş niyetiyse iş döngüsü bir sonraki taramada.
          v.actPose = null;
          v.prop = PropKind.none;
        }
      }
    }

    if (kMindTelemetryOn) _reportMind(dt);
  }

  /// Canlılık telemetrisi — "köy donmuş mu" sorusunun tek dürüst cevabı.
  ///
  /// Ekran görüntüsü ya da widget sayısı bu soruyu yanıtlayamaz: donmuş bir köy
  /// de pırıl pırıl çizilir. Ölçülen üç şey gerçekten hareket kanıtıdır —
  /// kat edilen mesafe, niyet çeşitliliği ve en eski niyetin yaşı.
  void _reportMind(double dt) {
    final kinds = <IntentKind>{};
    double oldest = 0;
    double moved = 0;
    var locked = 0;
    for (final v in _villagers) {
      kinds.add(v.mind.intent.kind);
      if (v.mind.intentAge > oldest) oldest = v.mind.intentAge;
      if (v.isWalking) moved += v.speed * dt;
      // Ceremony niyeti hakemin hiçbir güvenlik ağıyla düşmez — salıvermeyi
      // unutan bir sistem köylüyü ömür boyu kilitler. Sayacı burada tutmak
      // o kilidi testte görünür kılar (bkz. scene_vignette).
      if (v.mind.intent.priority >= IntentPriority.ceremony) locked++;
    }
    kProbeCeremonyLocked = locked;
    kMindDistance += moved;
    kMindDistinctIntents = kinds.length;
    kMindOldestIntent = oldest;
  }

  /// NİYET GEÇERLİLİK DENETİMİ — bitmiş niyeti düşür.
  ///
  /// Bu adım olmadan sistem KİLİTLENİR ve bu, mimarinin en sinsi tuzağıdır:
  /// [IntentPriority.routine] üstündeki bir niyet (iş/dinlenme/ateş/geçim)
  /// gündelik tekliflerle bölünemez. Yani işi biten bir köylü sonsuza kadar
  /// "işinde" sayılır, hiçbir teklif onu kurtaramaz, köylü olduğu yerde donar.
  ///
  /// Kural: niyeti veren koşul ortadan kalktıysa niyet de biter. Sahibi olan
  /// sistem ayrıca kendi bitişinde [VillagerMind.clear] çağırabilir; burası
  /// güvenlik ağıdır — hiçbir niyet sessizce ölümsüz kalmasın.
  void _expireIntent(VillagerEntity v) {
    final m = v.mind;
    if (m.intent.isIdle) return;

    switch (m.intent.kind) {
      case IntentKind.work:
        if (!_hasJobLoop(v) || !_workTaskAvailable(v)) m.clear();

      case IntentKind.inform:
        // Anlatacak bir şeyi kalmadıysa ya da köyde muhafız yoksa vazgeçer.
        if (v.memory.strongestReportable == null || _nearestGuardFor(v) == null) {
          m.clear();
        }

      case IntentKind.forage:
        if (!_homelessSeekingBed(v) || !_reedTaskAvailable()) m.clear();

      case IntentKind.hearth:
        // Oturma bitti (ya da hiç başlayamadı) → niyet düştü.
        if (!v.sitClaimed && !v.isSeatedAtFire) m.clear();

      case IntentKind.rest:
      case IntentKind.errand:
        // Mikro-sahne sürüyorsa niyet de sürer — eylemin bitişi niyetin
        // bitişidir ([_finishAct]). Sahnesi yoksa eski kural geçerli.
        if (v.act != null) break;
        if (v.state != VillagerState.moving && v.idleTimer <= 0) m.clear();

      case IntentKind.social:
        if (v.activity == VillagerActivity.none) m.clear();

      case IntentKind.crime:
        if (_activeCrime == null || !identical(_activeCrime!.culprit, v)) {
          m.clear();
        }

      case IntentKind.quarrel:
      case IntentKind.flee:
        if (v.activity == VillagerActivity.none) m.clear();

      case IntentKind.ceremony:
      case IntentKind.worship:
      case IntentKind.idle:
        break;
    }

    // SON GÜVENLİK AĞI — yukarıdaki kapıların hiçbiri tutmadıysa bile hiçbir
    // niyet bir oyun gününün çeyreğinden uzun yaşamaz. Bu, gelecekte eklenecek
    // niyetlerin de köylüyü dondurmasını engeller.
    if (m.intent.priority < IntentPriority.ceremony &&
        m.intentAge > kGameDaySeconds * 0.25) {
      m.clear();
    }
  }

  /// Köylü şu an karar verebilir mi? Ölü/uyuyan/taşınan/tören altındaki köylü
  /// düşünmez. Buradaki liste kasten dar: "meşgul" kavramı hakemin işi değil,
  /// önceliklerin işi — meşguliyet [IntentPriority] ile ifade edilir.
  bool _canDeliberate(VillagerEntity v) {
    if (v.isDying || v.isLeaving || v.isSleeping || v.isInsideBuilding) return false;
    if (v.isCarrying) return false; // yük taşırken bırakıp gitmez
    if (v.injuryDays > 0) return false; // yaralı dinleniyor
    if (v.sickDays > 0) return false; // hasta dinleniyor (iyileşir/atlatır)
    if (v.laborDays > 0) return false; // kürek cezasında — hareketi _tickConvictLabor sürer
    // Tören/dayatma altındaysa teklif toplanmaz (hakem zaten bölemez ama
    // boşuna puan hesaplamayalım).
    if (v.mind.intent.priority >= IntentPriority.ceremony) return false;
    // BAŞLAMIŞ EYLEM KİLİDİ — Faz 1'in en kritik regresyon koruması.
    //
    // Eskiden her sistem `activity != none` diye bakıp meşgul köylüye
    // dokunmuyordu. O koruma dağınıktı ama GERÇEKTİ: oturmuş, sohbet eden,
    // dans eden, kaçan köylüyü yerinden kaldırmak sahneyi bozar (yarım kalan
    // sohbet, ayağa fırlayan hikâye dinleyicisi, kovalamacayı bırakan fail).
    // Hakem tek otorite olduğu için o koruma da tek yere taşındı.
    if (v.sitClaimed || v.isSeatedAtFire) return false;
    switch (v.activity) {
      case VillagerActivity.none:
        return true;
      default:
        return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DÜRTÜLER — dünyadan beslenir, DURUMDAN söner
  // ══════════════════════════════════════════════════════════════════════════

  /// Dürtüler "doğru yerde bulunarak" giderilir: sofradaki doyar, ateş
  /// başındaki ısınır, sohbet edenin yalnızlığı geçer. Bu sayede varış
  /// noktalarına ayrı ayrı "geldi mi?" kancası takmaya gerek kalmaz —
  /// niyet köylüyü yere götürür, yer dürtüyü söndürür.
  void _tickDrives(VillagerEntity v, double dt) {
    final m = v.mind;
    const r = DriveRates(kGameDaySeconds);
    final p = _pressure;

    // ── AÇLIK ──────────────────────────────────────────────────────────────
    if (_atFoodSpot(v) && _stockpile.food > 0) {
      m.satisfy(Drive.hunger, 0.35 * dt); // sofrada/tezgâhta karnını doyuruyor
    } else {
      // Ambar boşken açlık daha hızlı büyür — kıtlık gerçek bir sebep olsun.
      m.pushDrive(Drive.hunger, r.hunger * (1.0 + _scarcity * 0.8), dt);
    }

    // ── YORGUNLUK ──────────────────────────────────────────────────────────
    if (v.isSleeping) {
      m.satisfy(Drive.fatigue, 0.5 * dt);
    } else {
      final toil = v.hasActiveJob ? 1.45 : (v.mind.owns(IntentKind.work) ? 1.2 : 1.0);
      m.pushDrive(Drive.fatigue, r.fatigue * toil, dt);
    }

    // ── ÜŞÜME ──────────────────────────────────────────────────────────────
    // Soğuk koşula bağlı: gece + kış + yağmur. Sıcak koşulda kendiliğinden söner.
    double cold = 0;
    if (_cycle.dayLight < 0.35) cold += 0.6;
    if (_season == Season.winter) cold += 0.7;
    if (_cycle.rainIntensity > 0.3) cold += 0.4;
    if (v.isSeatedAtFire && _fireBurning) {
      m.satisfy(Drive.chill, 0.45 * dt);
    } else if (v.isSleeping && _sleepsWarm(v)) {
      // BARINAĞIN İŞİ BU: duvarlı ev (kendi ocağı var) ya da ateşin dibindeki
      // çadır uykuda ısıtır. Önceden barınağın üşümeye hiçbir etkisi yoktu —
      // herkes sabaha aynı üşümüş çıkıyordu, yani "damın altı" bir şey ifade
      // etmiyordu. Çadır ↔ ocak mesafesinin anlamlı olduğu yer burası.
      m.satisfy(Drive.chill, 0.22 * dt);
    } else if (cold > 0) {
      // Ocaktan uzak çadırda üşüme daha hızlı birikir (bkz. scene_shelter):
      // uykuda bile dinmez, doldukça köylüyü gecenin ortasında kaldırır.
      m.pushDrive(Drive.chill, r.perDay(2.2) * cold * _chillDriveMultiplierOf(v), dt);
    } else {
      m.satisfy(Drive.chill, r.decay * dt);
    }

    // ── YALNIZLIK ──────────────────────────────────────────────────────────
    if (_inCompany(v)) {
      m.satisfy(Drive.company, 0.30 * dt);
    } else {
      m.pushDrive(Drive.company, r.company * v.personality.sociability, dt);
    }

    // ── TEDİRGİNLİK ────────────────────────────────────────────────────────
    // İki kaynak, iki hız:
    //   • Köyün havası (dünya basıncı) tedirginliği HIZLA yukarı çeker —
    //     baskı rejimi bir günde hissedilir.
    //   • Yatışma YAVAŞTIR. Gördüğü bir suçun ya da cinayetin ardından
    //     ([_witnessEvent] dürtüyü sıçratır) köylü on saniyede sakinleşmez;
    //     tedirginlik anının kendisiyle birlikte, günler içinde iner.
    //     Simetrik bir sürüklenme bu sıçramayı saniyeler içinde silerdi ve
    //     "gördükleri sonraki kararlarını etkiler" sözü boş kalırdı.
    final target = p.wariness;
    final cur = m.drive(Drive.unease);
    if (cur < target) {
      m.pushDrive(Drive.unease, (target - cur) * 0.25, dt);
    } else {
      m.satisfy(Drive.unease, (cur - target) * r.perDay(0.9) * dt);
    }

    // ── İŞSİZLİK ───────────────────────────────────────────────────────────
    if (!v.hasProfession) {
      m.setDrive(Drive.purpose, 0); // çocuğun işsizlik derdi olmaz
    } else if (v.hasActiveJob || m.owns(IntentKind.work)) {
      m.satisfy(Drive.purpose, 0.40 * dt);
    } else if (_cycle.dayLight > 0.35) {
      m.pushDrive(Drive.purpose, r.purpose * p.workDrive, dt);
    }
  }

  /// Yiyeceğe eli uzanan bir yerde mi (pazar/meyhane/ambar/kendi evi).
  bool _atFoodSpot(VillagerEntity v) {
    if (v.isWalking) return false;
    for (final b in _buildings) {
      final ok = b.type == BuildingType.market ||
          b.type == BuildingType.tavern ||
          b.type == BuildingType.warehouse ||
          identical(b, v.homeBuilding);
      if (!ok) continue;
      final (bx, by) = _centerOf(b);
      if (_wdist(v.gridX, v.gridY, bx, by) < 3.0) return true;
    }
    return false;
  }

  /// Şu an insan içinde mi — sohbet/müzik/dans/hikâye ya da yakınında biri.
  bool _inCompany(VillagerEntity v) {
    switch (v.activity) {
      case VillagerActivity.chat:
      case VillagerActivity.music:
      case VillagerActivity.dance:
      case VillagerActivity.storytelling:
      case VillagerActivity.listening:
      case VillagerActivity.warm:
        return true;
      default:
        break;
    }
    if (v.isSeatedAtFire) return true;
    return false;
  }

  /// Suç/kavga/ölüm gibi bir olay köyü ürkütür — tedirginlik dürtüsünü
  /// yarıçaptaki köylülerde SIÇRATIR (dünya basıncının yavaş sürüklenmesinden
  /// farklı: bu ani ve kişiseldir).
  void _alarmVillage(double x, double y, double radius, double amount) {
    final r2 = radius * radius;
    for (final v in _villagers) {
      if (v.isDying || v.isSleeping) continue;
      final dx = v.gridX - x, dy = v.gridY - y;
      final d2 = dx * dx + dy * dy;
      if (d2 > r2) continue;
      final k = 1.0 - (d2 / r2);
      v.mind.pushDrive(Drive.unease, amount * k, 1.0);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TEKLİFLER — her sistem kendi derdini puanlar
  // ══════════════════════════════════════════════════════════════════════════

  List<Bid> _collectBids(VillagerEntity v) {
    final bids = <Bid>[];
    void add(Bid? b) {
      if (b != null && b.score > 0) bids.add(b);
    }

    add(_bidInform(v));
    add(_bidWork(v));
    add(_bidRest(v));
    add(_bidHearth(v));
    add(_bidSocial(v));
    add(_bidForage(v));
    add(_bidErrand(v));
    add(_bidCrime(v));
    return bids;
  }

  // ── İHBAR ───────────────────────────────────────────────────────────────
  // Gözüyle suç gören köylü devriyeye koşar. Köyde suçun cezalandırıldığı
  // İKİNCİ kanal budur; öncesinde tek yol muhafızın olayı kendi görmesiydi
  // (yani muhafızın 7 tile'ı dışındaki her suç görünmezdi).
  //
  // Kimin koşacağını köyün hâli belirler: ihbar eğilimi ([informUrge]) yüksek
  // köyde herkes koşar, kaynayan köyde kimse kimseyi ele vermez.
  Bid? _bidInform(VillagerEntity v) {
    if (v.type == VillagerType.guard) return null; // muhafız kendine koşmaz
    if (!v.hasProfession) return null;
    final r = v.memory.strongestReportable;
    if (r == null) return null;
    final guard = _nearestGuardFor(v);
    if (guard == null) return null;

    // Korku ihbarı zorlar, kayıtsızlık engeller. Faile duyduğu kin de iter.
    final grudge = (-v.memory.opinionOf(r.subject!)).clamp(0.0, 1.0);
    final urge = _pressure.informUrge + grudge * 0.35;
    if (urge < 0.20) return null; // bu köyde kimse konuşmaz
    return Bid(
      kind: IntentKind.inform,
      score: (0.8 + urge * 1.4) * r.strength *
          jitterFor(v.personalitySeed, IntentKind.inform),
      reason: 'gördüğünü devriyeye anlatmaya koşuyor',
      priority: IntentPriority.need,
      begin: () => v.goTo(guard.gridX, guard.gridY, 0.5),
    );
  }

  // ── İŞ ──────────────────────────────────────────────────────────────────
  // Akıl yalnız "işine dönsün mü" kararını verir; işin kendisi scene_work /
  // scene_jobs'ta yürür. Böylece iş döngülerine dokunmadan sahiplik değişti.
  Bid? _bidWork(VillagerEntity v) {
    if (!_hasJobLoop(v) || !_workTaskAvailable(v)) return null;
    // Üstlenilmiş bina-işi (inşaat/tarla/maden) yarıda bırakılmaz — en yüksek
    // sıradan öncelik. Yoksa köylü tuğla taşırken sohbete dalar.
    final committed = v.hasActiveJob;
    final purpose = v.mind.drive(Drive.purpose);
    final score = (committed ? 1.8 : 0.55 + urgency(purpose, threshold: 0.20) * 1.4) *
        _pressure.workDrive *
        jitterFor(v.personalitySeed, IntentKind.work);
    return Bid(
      kind: IntentKind.work,
      score: score,
      reason: committed ? 'başladığı işi bitiriyor' : 'işinin başına dönüyor',
      priority: IntentPriority.work,
      begin: () {}, // yürütme scene_work/scene_jobs'ta; akıl yalnız sahiplendi
    );
  }

  // ── DİNLENME ────────────────────────────────────────────────────────────
  // Yorgunluk eşiği aşınca köylü akşamı beklemeden evine çekilir. Uyku hâlâ
  // gece/ışık eşiğinde (villager_entity); bu yalnız "eve doğru" davranışı.
  Bid? _bidRest(VillagerEntity v) {
    final home = v.homeBuilding;
    if (home is! BuildingEntity) return null;
    final u = urgency(v.mind.drive(Drive.fatigue), threshold: 0.62);
    if (u <= 0) return null;
    final (hx, hy) = _centerOf(home);
    final spot = _freeSpotNear(hx, hy, 1.8);
    if (spot == null) return null;
    return Bid(
      kind: IntentKind.rest,
      score: u * 1.5 * _pressure.homePull *
          jitterFor(v.personalitySeed, IntentKind.rest),
      reason: 'yorgun, evine çekiliyor',
      priority: IntentPriority.need,
      begin: () => v.goTo(spot.$1, spot.$2, 10 + _rng.nextDouble() * 8),
    );
  }

  // ── ATEŞ BAŞI ───────────────────────────────────────────────────────────
  Bid? _bidHearth(VillagerEntity v) {
    if (!_fireBurning || v.isChild || v.sitClaimed) return null;
    if (_cycle.rainIntensity > 0.4) return null;
    final u = urgency(v.mind.drive(Drive.chill), threshold: 0.30);
    if (u <= 0) return null;
    // Ateş sevenler daha erken kalkar — kişilik davranışı renklendirir.
    final like = v.personality.likes.atFireAffinity ? 1.35 : 1.0;
    return Bid(
      kind: IntentKind.hearth,
      score: u * 1.4 * like * _pressure.firePull *
          jitterFor(v.personalitySeed, IntentKind.hearth),
      reason: 'üşümüş, ateş başına gidiyor',
      priority: IntentPriority.need,
      begin: () => _seatAtFire(v),
    );
  }

  // ── SOHBET ──────────────────────────────────────────────────────────────
  // İki itki: YALNIZLIK (biriyle olma ihtiyacı) ve HABER (anlatacak taze bir
  // şeyin olması). İkincisi olmadan dedikodu köyde HİÇ yayılmıyordu — köylüler
  // sürekli mikro-sahne yürüttüğü için "boşta ve yan yana" nadir oluşuyor,
  // sohbet başlamıyor, 50 anı birikse de kimse anlatmıyordu (prova testi
  // yakaladı: dedikodu sayacı sürekli 0). Haberi olan konuşmaya isteklidir.
  Bid? _bidSocial(VillagerEntity v) {
    if (!v.hasProfession || v.socialCooldown > 0) return null;
    if (_cycle.rainIntensity > 0.30) return null;
    final partner = _findNearbyIdle(v);
    if (partner == null) return null; // konuşacak kimse yok

    final lonely = urgency(v.mind.drive(Drive.company), threshold: 0.30);
    // Karşısındakinin bilmediği taze bir haberim var mı? (dedikodu yakıtı)
    final news = v.memory.strongestTellable;
    final hasNews = news != null && !partner.memory.knows(news.kind, news.subject);
    // GÜNDÜZ MEYDAN MUHABBETİ — köy yalnız gece ateş başında sosyalleşiyordu;
    // gündüz meydan/kuyu/pazar çevresinde boşta yan yana gelen iki köylü, yalnız
    // ya da anlatacak haberi olmasa bile iki laf eder. Errand sistemi zaten
    // insanları buralara çekiyor; eksik olan "varınca birlikte oyalanma"ydı.
    final atSquare = _cycle.dayLight > 0.5 &&
        (_nearAny(v.gridX, v.gridY, _spotsOf(BuildingType.townhall), 4.5) ||
         _nearAny(v.gridX, v.gridY, _spotsOf(BuildingType.well), 4.0) ||
         _nearAny(v.gridX, v.gridY, _spotsOf(BuildingType.market), 4.5));
    final smalltalk = atSquare ? 0.35 : 0.0;
    if (lonely <= 0 && !hasNews && smalltalk <= 0) return null;

    final base = lonely + (hasNews ? 0.7 : 0.0) + smalltalk;
    return Bid(
      kind: IntentKind.social,
      score: base * 1.1 * (0.6 + _pressure.outspoken * 1.3) *
          jitterFor(v.personalitySeed, IntentKind.social),
      reason: hasNews ? 'duyduğunu anlatmak istiyor' : 'birine iki laf etmek istiyor',
      priority: IntentPriority.routine,
      begin: () => _startSocialFor(v),
    );
  }

  // ── GEÇİM (saz/yatak) ───────────────────────────────────────────────────
  Bid? _bidForage(VillagerEntity v) {
    if (!_homelessSeekingBed(v) || !_reedTaskAvailable()) return null;
    if (_cycle.dayLight <= 0.35) return null;
    return Bid(
      kind: IntentKind.forage,
      score: 1.2 * jitterFor(v.personalitySeed, IntentKind.forage),
      reason: 'başını sokacak bir yer kuruyor',
      priority: IntentPriority.need,
      begin: () {}, // yürütme scene_reed'de
    );
  }

  // ── GİDİŞ GELİŞ ─────────────────────────────────────────────────────────
  // Taban akış: köy hiçbir dürtüsü olmasa da durmaz. Açlık varsa hedef
  // sofraya kayar — yani "acıktı" davranışı ayrı bir sistem değil, aynı
  // gidişin yön değiştirmesi.
  Bid? _bidErrand(VillagerEntity v) {
    if (!v.canRunErrands) return null;
    if (v.state == VillagerState.moving) return null;
    final hunger = v.mind.drive(Drive.hunger);
    final hungry = urgency(hunger, threshold: 0.45);
    final dest = _pickErrand(v, foodBias: 1.0 + hungry * 3.0);
    if (dest == null) return null;
    // Gidişin kendisi artık bir MİKRO-SAHNE (bkz. scene_act): kuyuda kova
    // doldurulur, pazardan sepetle dönülür. Sebep metnini de sahne verir —
    // "köyde bir işi var" yerine "kuyudan su taşıyor".
    final act = _errandAct(v, dest);
    return Bid(
      kind: IntentKind.errand,
      score: (0.45 + hungry * 1.3) *
          jitterFor(v.personalitySeed, IntentKind.errand),
      reason: hungry > 0 && dest.kind == BuildingType.market
          ? 'karnını doyurmaya gidiyor'
          : act.label,
      priority: IntentPriority.routine,
      begin: () => v.act = act,
    );
  }

  // ── SUÇ ─────────────────────────────────────────────────────────────────
  // Suç artık zamanlayıcıdan doğan bir zar atışı DEĞİL: köylünün dürtülerinden
  // doğan bir teklif. Aç ve mutsuz biri çalmayı gerçekten "daha çok ister";
  // tok ve huzurlu köyde bu teklif hiç oluşmaz.
  Bid? _bidCrime(VillagerEntity v) {
    if (_activeCrime != null) return null; // aynı anda tek suç (sözleşme)
    if (!_crimeEligible(v)) return null;
    if (_crimeClimate <= 0) return null;
    final desperation = urgency(v.mind.drive(Drive.hunger), threshold: 0.55) * 1.6 +
        _criminality(v) * 0.9;
    if (desperation <= 0) return null;
    final score = desperation * _crimeClimate * 0.42 *
        jitterFor(v.personalitySeed, IntentKind.crime);
    // Suç NADİR olmalı: en yüksek teklif bile eşiği aşmadıkça yeltenilmez.
    // Bu eşik, "köy suç çukuru değil" sözleşmesinin akıl tarafındaki karşılığı.
    if (score < _kCrimeBidFloor) return null;
    final plan = _planCrime(v);
    if (plan == null) return null;
    return Bid(
      kind: IntentKind.crime,
      score: score,
      reason: 'gözü dönmüş, bir işin peşinde',
      priority: IntentPriority.committed,
      begin: () => _beginCrime(plan),
    );
  }

  /// Suça yeltenme eşiği — altındaki her teklif elenir.
  static const double _kCrimeBidFloor = 0.85;

  // ══════════════════════════════════════════════════════════════════════════
  // YÜRÜTME YARDIMCILARI
  // ══════════════════════════════════════════════════════════════════════════

  /// Tek köylüyü ateş başına oturt (eski toplu [_scanGather]'ın tek kişilik
  /// hâli). Slot bulunamazsa niyet boşa düşer, hakem bir sonraki turda başka
  /// bir teklif seçer.
  void _seatAtFire(VillagerEntity v) {
    final claim = _anchorSystem.claimNearestFirepitSit(v.gridX, v.gridY, v);
    if (claim == null) {
      v.mind.clear();
      return;
    }
    final (point, slot) = claim;
    final cx = point.building.col + point.building.cols / 2.0;
    final cy = point.building.row + point.building.rows / 2.0;
    final dur = _kMindSitMin + _rng.nextDouble() * (_kMindSitMax - _kMindSitMin);
    v.assignSit(slot.col, slot.row, cx, cy, dur, () => point.release(slot, v));
  }

  /// Sohbet/müzik/dans başlat — bağlam hangisini uygun kılıyorsa.
  void _startSocialFor(VillagerEntity v) {
    final night = _cycle.dayLight < 0.45;
    final atTavern = _nearAny(v.gridX, v.gridY, _spotsOf(BuildingType.tavern), 3.5);
    final atFire = _nearAny(v.gridX, v.gridY, _spotsOf(BuildingType.firepit), 4.0);
    final festive = atTavern || (atFire && night);
    final r = _rng.nextDouble();
    bool started = false;
    if (festive && r < 0.25) {
      started = _tryStartDanceFor(v);
    } else if (festive && r < 0.50) {
      started = _tryStartMusicFor(v);
    } else {
      started = _tryStartChatFor(v);
    }
    if (started) {
      v.socialCooldown = 40 + _rng.nextDouble() * 80;
      v.mind.satisfy(Drive.company, 0.45);
    } else {
      v.mind.clear(); // olmadı — hakem yeniden seçsin
    }
  }
}
