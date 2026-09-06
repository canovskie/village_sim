part of '../../main.dart';

/// SUÇA KARŞILIK — tanıklar, muhafız tepkisi, yakalama, yargı dilekçesi, cezalar, fidye ve dev kısayolları.
extension _SceneCrimeJustice on _VillageSceneState {

  /// Suçu gören köylü gündelik rotasında yürümeye devam etmez: kısa süre
  /// durur, bedenini olay yerine çevirir; sonra hafızası/aklı uygunsa devriyeye
  /// ihbar teklifi doğal olarak kazanır. Bu kısa [Act] ceremony değildir;
  /// bitince eski işi güvenle sürebilir.
  void _stageCrimeWitnesses(
    List<VillagerEntity> witnesses,
    double x,
    double y, {
    bool arrest = false,
  }) {
    final eligible =
        witnesses
            .where(
              (w) =>
                  !w.isDying &&
                  !w.isSleeping &&
                  !w.isInsideBuilding &&
                  !w.isCarrying &&
                  w.mind.intent.priority < IntentPriority.committed,
            )
            .toList()
          ..sort(
            (a, b) => _wdist(
              a.gridX,
              a.gridY,
              x,
              y,
            ).compareTo(_wdist(b.gridX, b.gridY, x, y)),
          );
    final maxWitnesses = arrest ? 5 : 3;
    for (final w in eligible.take(maxWitnesses)) {
      _prepForScene(w);
      w.act = Act(arrest ? 'yakalanan faile bakıyor' : 'suça tanık oldu', [
        ActStep.face(x, y),
        ActStep.work(arrest ? 5.0 : 2.8, pose: ActPose.stand),
      ]);
      w.feel(arrest ? NpcEmotion.wonder : NpcEmotion.fear, arrest ? 5.0 : 3.2);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MUHAFIZ — devriyeden koşar, suçüstü yakalar
  // ══════════════════════════════════════════════════════════════════════════

  /// Yürüyen suça en yakın muhafızı üstüne sürer; yaklaşırsa yakalar. Muhafız
  /// hem oyuncunun gözü hem eli: sen kaçırsan da o yetişebilir.
  ///
  /// Ama muhafız HER ŞEYİ GÖRMEZ (yoksa muhafızlı köyde hiçbir suç işlenemezdi
  /// ve sistem görünmez olurdu — telemetride tam olarak bu çıktı):
  ///  - Suç işlenirken (sinsi yaklaşma/eylem) yalnız GÖRÜŞ alanındaysa fark eder.
  ///  - Suç işlendikten sonra (kaçış) gürültü köyü ayağa kaldırır → daha geniş
  ///    menzilden peşine düşer.
  /// Böylece köyün ucundaki suç muhafızın kör noktasında kalabilir: yakalamak
  /// oyuncunun gözüne kalır.
  void _guardResponse(double dt) {
    if (kCaptureNoGuard) return; // test yatağı: muhafızsız köy (kaçış zinciri)
    final c = _activeCrime;
    if (c == null) return;
    final v = c.culprit;

    _chaseRefresh -= dt;
    final refresh = _chaseRefresh <= 0;
    if (refresh) _chaseRefresh = _SceneCrime._kChaseRefresh;

    // Fark etme süresi — muhafız suça anında ışınlanmaz.
    _crimeNoticed += dt;
    if (_crimeNoticed < _SceneCrime._kGuardNotice) return;

    // Menzil: suç işlenmeden GÖRÜŞ, işlendikten sonra GÜRÜLTÜ.
    //
    // KÖYÜN HÂLİ iki ayrı kanaldan büker: uyanık bir devriye daha uzağı GÖRÜR
    // (patrolVigilance), haber veren bir köy suçu daha uzaktan DUYURUR
    // (informUrge — gürültü tek başına değil, ağızdan ağza taşınır).
    final p = _pressure;
    final bellCovered =
        c.done &&
        _buildings.any(
          (b) =>
              b.type == BuildingType.belltower &&
              withinBuildingEffect(
                type: b.type,
                col: b.col,
                row: b.row,
                targetX: c.tx,
                targetY: c.ty,
              ),
        );
    if (bellCovered && !c.bellRung) {
      c.bellRung = true;
      AudioManager.instance.playSfx(Sfx.bellChime);
      _showNotification('🔔 Alarm çanı çaldı — devriye suç yerine çağrılıyor.');
    }
    final range = c.done
        ? bellGuardResponseRange(
            _SceneCrime._kGuardResponse * (0.75 + p.informUrge * 0.9),
            covered: bellCovered,
          )
        : _SceneCrime._kGuardSight * p.patrolVigilance;

    VillagerEntity? best;
    double bestD = range;
    for (final g in _awakeGuards()) {
      if (g.injuryDays > 0) continue;
      final d = _wdist(g.gridX, g.gridY, v.gridX, v.gridY);
      if (d < bestD) {
        bestD = d;
        best = g;
      }
    }
    // Menzil dışına çıktıysa kovalamayı bırak (izini kaybetti).
    if (best == null) {
      for (final g in _villagers) {
        if (g.activity != VillagerActivity.chasing) continue;
        g.activity = VillagerActivity.none;
        g.hasteFactor = 1.0;
        g.chatBubbleIcon = '';
        g.chatBubbleTime = 0;
      }
      return;
    }

    // Yakaladı! — ama fail BİNANIN İÇİNDEYSE yakalanamaz: sprite yok, kapı
    // kapalı. Muhafız kapıya dayanır ve bekler; hesaplaşma fail çuvalla
    // çıktığında olur. (Bu kapı olmadan devriye duvarın ardındaki adamı
    // görünmez hâldeyken tutukluyordu.)
    if (bestD <= _SceneCrime._kCatchDist && !c.inside) {
      _catchCriminal(v, guard: best);
      return;
    }

    // Kovalıyor — öne yüklenmiş koşu, hedef taze tutulur. Ateş başında
    // oturuyorsa slotu USULÜNCE bırakır (doğrudan sitClaimed=false yazmak
    // anchor rezervasyonunu sızdırır — o slota bir daha kimse oturamazdı).
    if (best.sitClaimed) best.cancelSit();
    best.activity = VillagerActivity.chasing;
    best.hasteFactor = 1.35;
    if (refresh) best.goTo(v.gridX, v.gridY, 0.5);
  }

  /// İHBAR ÜZERİNE devriyeyi failin üstüne yolla (bkz. scene_perception).
  ///
  /// Muhafızın suçu KENDİ görmesinden bağımsız ikinci kanal: bir tanık
  /// koşup haber verdiyse devriye tarifle harekete geçer. Kovalama durumu
  /// [_guardResponse] ile birebir aynı kurulur ki iki kanal aynı sahneyi
  /// üretsin (ayrı kod = ayrı davranış = tutarsız görüntü).
  void _sendGuardAfter(VillagerEntity guard, _ActiveCrime c) {
    if (guard.sitClaimed) guard.cancelSit();
    guard.activity = VillagerActivity.chasing;
    guard.hasteFactor = 1.35;
    guard.goTo(c.culprit.gridX, c.culprit.gridY, 0.5);
  }

  /// Oyuncu bu köylüye dokununca suçüstü yakalanabilir mi (input kapısı).
  bool _isCriminalInAct(VillagerEntity v) =>
      _activeCrime != null && identical(_activeCrime!.culprit, v);

  /// SUÇÜSTÜ — fail yakalandı. [guard] verilirse devriye yakaladı, yoksa oyuncu.
  /// Suç henüz tamamlanmadıysa ÖNLENİR (kurban kurtulur, mal yerinde kalır).
  /// Tamamlandıysa fail yine de hesap verir. Her iki hâlde de Meclis'e çıkar.
  void _catchCriminal(VillagerEntity v, {VillagerEntity? guard}) {
    final c = _activeCrime;
    if (c == null || !identical(c.culprit, v)) return;

    final prevented = !c.done;
    final vic = c.victim;

    // Yakalanma köyün gözü önünde olur — gören hatırlar (asayişin görünür
    // yüzü) ve failin sicili köylülerin kanaatine kazınır.
    final arrestWitnesses = _witnessEvent(
      Notion.arrest,
      x: v.gridX,
      y: v.gridY,
      subject: v,
      subjectName: v.name,
      loud: true,
      exclude: guard == null ? const [] : [guard],
    );

    // ÇUVALLA YAKALANDI — mal doğrudan köye döner. Yakalamanın somut ödülü
    // budur: yalnız fail değil, MAL da elde edilir. (Gömdükten sonra
    // yakalanırsa çuval elinde değildir; o mal zulada kalır ve ayrıca
    // bulunması gerekir — kaçış hızının gerçek bir bedeli olsun.)
    final loot = c.lootKind;
    if (loot != null && !c.buried && (c.lootAmount > 0 || c.weaponAmount > 0)) {
      if (c.lootAmount > 0) _stockpile.add(loot, c.lootAmount);
      if (c.weaponAmount > 0) _stockpile.weapons += c.weaponAmount;
      final recovered = c.lootAmount + c.weaponAmount;
      kProbeLootRecovered += recovered;
      final returned = <String>[
        if (c.lootAmount > 0) '${c.lootAmount} ${loot.label.toLowerCase()}',
        if (c.weaponAmount > 0) '${c.weaponAmount} silah',
      ].join(' ve ');
      _showNotification(
        Voice.say(
          const [
            '🧺 Çuval geri alındı. {mal} ambara döndü.',
            '🧺 Yakalanan çuval açıldı; {mal} yeniden ambarda.',
          ],
          _voice(
            v,
            seed: _stableSeed('çalınanGeri${v.name}', _dayCount),
            extra: {'mal': returned},
          ),
        ),
      );
      c.lootAmount = 0;
      c.weaponAmount = 0;
    }

    _clearCrimeState(v);
    v.feel(NpcEmotion.fear, 6.0, moodDelta: -0.15);
    v.state = VillagerState.idle;
    v.targetCol = v.gridX;
    v.targetRow = v.gridY;
    v.idleTimer = 6.0;
    v.crimeCooldown = _SceneCrime._kCrimeCooldown;
    v.crimeCount++;
    _activeCrime = null;
    _crimeSuspicion = (_crimeSuspicion - 1).clamp(0, 99);

    // Yakalama bir anda buharlaşmaz: fail çöker, muhafız başında durur,
    // çevredekiler yüzünü olaydan çevirmez. Yargı kartının dünyadaki karşılığı.
    final focus = _villageCenterD();
    final faceX = guard?.gridX ?? focus.$1;
    final faceY = guard?.gridY ?? focus.$2;
    v.act = Act('hüküm bekliyor', [
      ActStep.face(faceX, faceY),
      const ActStep.work(8.0, pose: ActPose.kneel),
    ]);
    if (guard != null) {
      _prepForScene(guard);
      guard.act = Act('failin başında nöbet tutuyor', [
        ActStep.face(v.gridX, v.gridY),
        const ActStep.work(8.0, pose: ActPose.stand),
      ]);
      guard.feel(NpcEmotion.anger, 8.0);
    }
    _stageCrimeWitnesses(arrestWitnesses, v.gridX, v.gridY, arrest: true);

    // Önlendiyse kurban kurtulur (kaçırılan serbest, hedef sağ).
    if (prevented && vic != null && !vic.isDying) {
      if (vic.activity == VillagerActivity.abducted) {
        vic.activity = VillagerActivity.none;
        vic.chatBubbleIcon = '';
        vic.chatBubbleTime = 0;
      }
      vic.feel(NpcEmotion.content, 4.0, moodDelta: 0.10);
      _showNotification(
        Voice.say(
          _SceneCrime._kRescuedPool,
          _voice(
            v,
            other: vic,
            seed: _stableSeed('kurtar${vic.name}', _dayCount),
          ),
        ),
      );
    }

    _reactNearby(v.gridX, v.gridY, 6.0, NpcEmotion.wonder, 3.0);
    addCameraShake(3.0, dur: 0.35);

    final ctx = _voice(
      v,
      other: vic,
      seed: _stableSeed('yakala${v.name}', _dayCount),
      extra: {'muhafız': guard?.name ?? ''},
    );
    _showNotification(
      Voice.say(guard != null ? _SceneCrime._kCaughtGuardPool : _SceneCrime._kCaughtPlayerPool, ctx),
    );
    _chronicle(
      Voice.say(c.def.caughtAnnalPool, ctx),
      icon: c.def.icon,
      milestone: c.def.isGrave,
      kind: ChronicleKind.crisis,
    );
    _lifeEvent(
      v,
      Voice.say(c.def.caughtAnnalPool, ctx),
      icon: c.def.icon,
      milestone: true,
    );

    // Meclis'e çıkar — hüküm senin.
    _openVerdict(v, c, prevented: prevented, guard: guard);
  }

  /// Yakalanan faili yargı dilekçesiyle önüne getirir. Dilekçeyi getiren
  /// (author) KURBAN ya da yakalayan muhafızdır — suçlu değil; "gündeme geldik"
  /// jesti mağdurun hanesine gitsin.
  void _openVerdict(
    VillagerEntity culprit,
    _ActiveCrime c, {
    required bool prevented,
    VillagerEntity? guard,
  }) {
    var p = PetitionSystem.requireById(PetitionIds.crimeVerdict);
    // KÜREK CEZASI (NİZAM) — yürürlükteyse yargıya beşinci bir hüküm açılır:
    // mahkûm sürülmez ya da idam edilmez, taş ocağına koşulur (köy taş kazanır,
    // bir el eksilmez). Emek ekseninin sert ama üretken hükmü.
    if (_policies.sealed.contains('nizam.labor')) {
      p = p.withExtraOption(
        const PetitionOption(
          label: 'Kürek cezasına yolla',
          detail:
              '{suçlu} zindana atılır, taş ocağında çalıştırılır. Köy taş '
              'kazanır; bir el de eksilmez.',
          resolutionPool: [
            '⛓ {suçlu} taş ocağına koşuldu. Kürek sesi meydana kadar geliyor.',
            '⛓ Hüküm: kürek. {suçlu} borcunu taşla ödeyecek.',
            '⛓ {suçlu} zindanı boyladı; sabah ilk taş ocağa indi.',
          ],
          moraleAmount: 0.02,
          moraleDays: 3,
          fx: PetitionFx.crimeLabor,
          estateMood: [(Estate.laborers, 0.06), (Estate.faithful, -0.08)],
        ),
      );
    }
    // TÖVBE MEYDANI (DERGÂH) — kılıcın karşılığı. Fail ne sürülür ne dövülür:
    // günahını meydanda söyler. Affın mekanik bedeli olan bağış sayacını
    // ARTIRMAZ (bkz. [_sentenceToPenance]); caydırıcılığı utançtan gelir.
    if (_policies.sealed.contains('dergah.penance')) {
      p = p.withExtraOption(
        const PetitionOption(
          label: 'Tövbeye çağır',
          detail:
              '{suçlu} günahını meydanda, köyün önünde söyler. Ceza kesilmez; '
              'bedel utançtır. Af gibi düzeni gevşetmez.',
          resolutionPool: [
            '🙏 {suçlu} meydana çıkarıldı. Günahını kendi ağzıyla söyleyecek.',
            '🙏 Hüküm: tövbe. {suçlu} bedelini köyün gözü önünde ödeyecek.',
            '🙏 {suçlu} tövbeye çağrıldı; meydan sessizce doldu.',
          ],
          moraleAmount: 0.03,
          moraleDays: 3,
          fx: PetitionFx.crimePenance,
          estateMood: [
            (Estate.faithful, 0.10),
            (Estate.hearth, -0.06),
            (Estate.artisans, -0.04),
          ],
        ),
      );
    }
    // SÜRGÜN FERMANI (NİZAM) — mühürlü değilse köy kimseyi yola vuramaz.
    // Hane sürgünü zaten bu fermanı şart koşuyordu (bkz. house_action.gateFor);
    // yargı da aynı kapıdan geçsin, yoksa aynı hüküm bir kapıda yasak bir
    // kapıda serbest olurdu.
    if (!_policies.sealed.contains('nizam.exile')) {
      p = p.without(const {PetitionFx.crimeExile});
    }
    _accusedCriminal = culprit;
    final author = (c.victim != null && !c.victim!.isDying)
        ? c.victim
        : (guard ?? _nearestWitness(culprit));
    _presentPetition(
      p,
      author: author,
      extra: {
        'suçlu': culprit.name,
        'suç': c.def.label,
        'hal': prevented ? 'son anda önlendi' : 'iş işten geçmişti',
        'sabıka': culprit.crimeCount > 1 ? 'Sabıkalı.' : 'İlk kez.',
      },
    );
  }

  /// Faile en yakın, sahnedeki tanık (dilekçeyi o getirir) — yoksa null.
  VillagerEntity? _nearestWitness(VillagerEntity v) {
    VillagerEntity? best;
    double bestD = 1e9;
    for (final o in _villagers) {
      if (identical(o, v) || o.isDying || !o.hasProfession) continue;
      final d = _wdist(o.gridX, o.gridY, v.gridX, v.gridY);
      if (d < bestD) {
        bestD = d;
        best = o;
      }
    }
    return best;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HÜKÜM — affet / cezalandır / sürgün / idam (PetitionFx üzerinden)
  // ══════════════════════════════════════════════════════════════════════════

  /// AF — merhamet. Suçlunun içi rahatlar (yeniden suça yeltenmesi zorlaşır),
  /// ama köy adaletsizlik hisseder ve BAĞIŞ SAYACI suç baskısını artırır
  /// (merhametin politik bedeli: sık affeden köyde suç çoğalır).
  void _pardonCriminal() {
    final v = _accusedCriminal;
    _accusedCriminal = null;
    if (v == null || v.isDying) return;
    _crimePardons++;
    v.feel(NpcEmotion.content, 5.0, moodDelta: 0.20);
    v.crimeCooldown = _SceneCrime._kCrimeCooldown * 2;
    _feelVillage(NpcEmotion.wonder, 6, -0.02);
    final ctx = _voice(v, seed: _stableSeed('af${v.name}', _dayCount));
    _chronicle(
      Voice.say(_SceneCrime._kPardonAnnalPool, ctx),
      icon: '🕊️',
      kind: ChronicleKind.decision,
    );
    _showNotification(Voice.say(_SceneCrime._kPardonPool, ctx));
  }

  /// CEZA — meydanda teşhir. Suçlu kırılır (moral dibe iner, birkaç gün iş
  /// göremez), köy düzeni görür (asayiş morali +). Ne af kadar yumuşak, ne
  /// sürgün kadar sert: en sık verilecek hüküm.
  void _punishCriminal() {
    final v = _accusedCriminal;
    _accusedCriminal = null;
    if (v == null || v.isDying) return;
    v.feel(NpcEmotion.grief, 6.0, moodDelta: -0.22);
    v.injuryDays = v.injuryDays < 1.2 ? 1.2 : v.injuryDays;
    v.crimeCooldown = _SceneCrime._kCrimeCooldown * 3;
    if (v.surname.isNotEmpty) _houses.nudge(v.surname, moodDelta: -0.06);
    _gatherAtFire(kGameDaySeconds * 0.35, max: 6);
    _feelVillage(NpcEmotion.wonder, 8, 0.03); // düzen görüldü
    addCameraShake(4.0, dur: 0.4);
    final ctx = _voice(v, seed: _stableSeed('ceza${v.name}', _dayCount));
    _chronicle(
      Voice.say(_SceneCrime._kPunishAnnalPool, ctx),
      icon: '⛓️',
      kind: ChronicleKind.decision,
    );
    _showNotification(Voice.say(_SceneCrime._kPunishPool, ctx));
  }

  /// SÜRGÜN — suçlu köyden atılır (mevcut sürgün mekanizması).
  void _exileCriminal() {
    final v = _accusedCriminal;
    _accusedCriminal = null;
    if (v == null || v.isDying) return;
    _exileVillager(v);
  }

  /// KÜREK CEZASI (NİZAM) — mahkûm köyde kalır ama taş ocağına koşulur. Köy
  /// anlık bir taş kazanır (mahkûm emeğinin ilk hasadı), suçlu uzun süre iş
  /// göremez + kırılır. Sürgünden farkı: bir el eksilmez, kaynak artı.
  ///
  /// Not: şimdilik anlık taş + ceza (mevcut _punishCriminal deseni). İleride
  /// villager'a bir `laborDays` durumu eklenip günlük taş üretimine (zindan
  /// emeği akışı) genişletilebilir — kanca burası.
  void _sentenceToLabor() {
    final v = _accusedCriminal;
    _accusedCriminal = null;
    if (v == null || v.isDying) return;
    // Kürek hükmü ANLIK bir ödül değil, SÜREGELEN bir emek: mahkûm günlerce
    // ocakta kalır ([_tickConvictLabor] günlük taş üretir + ocağa koşar).
    // Peşin taş yalnız "ilk hasat" jesti; asıl kazanım gün gün birikir.
    v.laborDays = _SceneCrime._kLaborSentenceDays;
    // Suç/kaçış durumundan temiz çıkış — bundan sonra hareketi yalnız
    // _tickConvictLabor sürer (çakışan sürücü kalmasın).
    v.activity = VillagerActivity.none;
    v.act = null;
    v.prop = PropKind.none;
    _stockpile.stone = (_stockpile.stone + _SceneCrime._kLaborUpfrontStone).clamp(
      0,
      1 << 30,
    );
    _captureLaborCount++; // telemetri: kürek cezası kaç kez uygulandı
    v.feel(NpcEmotion.grief, 6.0, moodDelta: -0.20);
    v.crimeCooldown = _SceneCrime._kCrimeCooldown * 3;
    if (v.surname.isNotEmpty) _houses.nudge(v.surname, moodDelta: -0.05);
    _feelVillage(NpcEmotion.wonder, 8, 0.02); // düzen görüldü, üretken sertlik
    addCameraShake(3.0, dur: 0.35);
    final ctx = _voice(
      v,
      seed: _stableSeed('kürek${v.name}', _dayCount),
      extra: {'süre': _SceneCrime._kLaborSentenceDays.round().toString()},
    );
    _chronicle(
      Voice.say(const [
        '⛓ {ad} taş ocağına koşuldu. Borcunu gün gün taşla ödeyecek.',
        '⛓ Kürek hükmü: {ad} zindanda, gündüzleri ocakta.',
      ], ctx),
      icon: '⛓️',
      kind: ChronicleKind.decision,
    );
    _showNotification(
      Voice.say(const [
        '⛓ {ad} kürek cezasına çarptırıldı — {süre} gün ocakta.',
        '⛓ {ad} taş ocağında. Sert ama üretken bir hüküm.',
      ], ctx),
    );
  }

  /// TÖVBE (DERGÂH) — kılıç yolunun karşılığı. Fail ne sürülür ne dövülür:
  /// günahını meydanda, köyün gözü önünde söyler.
  ///
  /// Aftan ayıran şey mekaniktir, metin değil: [_pardonCriminal] BAĞIŞ SAYACINI
  /// ([_crimePardons]) artırır ve o sayaç suç baskısını yükseltir — "sık affeden
  /// köyde suç çoğalır". Tövbe o sayaca dokunmaz; bedel ödenmiş sayılır.
  /// Caydırıcılığı demirden değil utançtan gelir: fail kırılır, köy toplanır,
  /// suça yeltenme uzun süre kapanır. Dergâh yolunun adalet cevabı budur.
  void _sentenceToPenance() {
    final v = _accusedCriminal;
    _accusedCriminal = null;
    if (v == null || v.isDying) return;
    // Suç/kaçış durumundan temiz çıkış — elindeki çalıntı da düşer.
    v.activity = VillagerActivity.none;
    v.act = null;
    v.prop = PropKind.none;
    // Aleni ikrar: köy ateş başına toplanır ve dinler (görünür olan bu).
    _gatherAtFire(kGameDaySeconds * 0.4, max: 8);
    v.feel(NpcEmotion.grief, 8.0, moodDelta: -0.18);
    // Utanç yara değil: iş göremezlik yok ([_punishCriminal]'in injuryDays'i
    // burada YOK) ama suça yeltenme cezadan da uzun süre kapalı.
    v.crimeCooldown = _SceneCrime._kCrimeCooldown * 4;
    if (v.surname.isNotEmpty) _houses.nudge(v.surname, moodDelta: -0.04);
    _feelVillage(NpcEmotion.wonder, 8, 0.02);
    final ctx = _voice(v, seed: _stableSeed('tövbe${v.name}', _dayCount));
    _chronicle(
      Voice.say(_SceneCrime._kPenanceAnnalPool, ctx),
      icon: '🙏',
      kind: ChronicleKind.decision,
    );
    _lifeEvent(v, Voice.say(_SceneCrime._kPenanceAnnalPool, ctx), icon: '🙏');
    _showNotification(Voice.say(_SceneCrime._kPenancePool, ctx));
  }

  /// KÜREK CEZASI YÜRÜTÜCÜSÜ — mahkûmu gündüzleri taş ocağına koşar, günlük taş
  /// ürettirir, süre dolunca salıverir. Her tick çağrılır ([scene_tick]).
  ///
  /// Mahkûm `laborDays > 0` iken akıl karar vermez ([_canDeliberate]) ve kadroya
  /// alınmaz ([canRunErrands] → [_freeForJob]); hareketini yalnız bu yürütücü
  /// sürer. Görünürlük: ocağın başında `labor` gövde dili (bkz. [_setWorkPose]),
  /// böylece hüküm ekranda da okunur — "taşı gerçekten kıran mahkûm".
  void _tickConvictLabor(double dt) {
    final dayFrac = dt / kGameDaySeconds;
    for (final v in _villagers) {
      if (v.laborDays <= 0 || v.isDying) continue;

      // Gece/uyku: emek durur (zindanda dinlenir) ama süre yine akar.
      final resting =
          v.isSleeping || v.isInsideBuilding || _cycle.dayLight <= 0.35;
      if (!resting) {
        // Ocağa koş (maden yoksa depoya — köyün taş yığını). Yoksa yerinde kır.
        final quarry =
            _nearestOf(BuildingType.mineBuilding, v) ??
            _nearestOf(BuildingType.warehouse, v);
        if (quarry != null) {
          final (qx, qy) = _centerOf(quarry);
          if (_wdist(v.gridX, v.gridY, qx, qy) > _SceneCrime._kLaborAtQuarry) {
            if (v.state != VillagerState.moving) v.goTo(qx, qy, 0.5);
            _setWorkPose(v, null); // yürürken dik
          } else {
            v.state = VillagerState.idle;
            v.idleTimer = 0.5;
            v.lookToward(qx, qy);
            _setWorkPose(v, ActPose.labor); // taş kırar
          }
        } else {
          _setWorkPose(v, ActPose.labor);
        }
        // Emek yalnız çalışırken taş üretir.
        _convictStoneAcc += _SceneCrime._kLaborStonePerDay * dayFrac;
      } else {
        _setWorkPose(v, null);
      }

      v.laborDays -= dayFrac;
      if (v.laborDays <= 0) {
        v.laborDays = 0;
        _setWorkPose(v, null);
        v.crimeCooldown =
            _SceneCrime._kCrimeCooldown; // taze salıverme, hemen suça dönmesin
        v.feel(NpcEmotion.content, 5.0, moodDelta: 0.10);
        final ctx = _voice(v, seed: _stableSeed('salıver${v.name}', _dayCount));
        _chronicle(
          Voice.say(const [
            '🕊 {ad} borcunu ödedi, ocaktan salıverildi.',
            '🕊 {ad-in} kürek hükmü doldu; köye geri karıştı.',
          ], ctx),
          icon: '🕊️',
        );
        _showNotification(
          Voice.say(const [
            '🕊 {ad} kürek cezasını tamamladı — köye döndü.',
          ], ctx),
        );
      }
    }
    // Biriken kesirli emeği tam sayı taşa çevir.
    while (_convictStoneAcc >= 1.0) {
      _stockpile.stone = (_stockpile.stone + 1).clamp(0, 1 << 30);
      _convictStoneAcc -= 1.0;
    }
  }

  /// İDAM — suçlu halkın önünde infaz edilir (mevcut idam mekanizması).
  void _executeCriminal() {
    final v = _accusedCriminal;
    _accusedCriminal = null;
    if (v == null || v.isDying) return;
    _executeVillager(v);
  }

  /// Asayiş dilekçesi çözüldü — şüphe sıfırlanır (köy nefes alır).
  void _resetSuspicion() => _crimeSuspicion = 0;

  // ── FİDYE — kaçırılan köylünün dönüşü ──────────────────────────────────────

  /// Fidye ödendi — rehin köye döner (kaçırıldığı kenardan yürüyerek).
  void _payRansom() {
    final v = _ransomVictim;
    _ransomVictim = null;
    if (v == null) return;
    v.isInsideBuilding = false;
    v.state = VillagerState.idle;
    v.idleTimer = 1.0;
    v.activity = VillagerActivity.none;
    v.hasteFactor = 1.0;
    v.chatBubbleIcon = '';
    v.chatBubbleTime = 0;
    v.feel(NpcEmotion.content, 8.0, moodDelta: 0.18);
    // Sahneye geri al + aile bağlarını karşı taraftan yeniden ör (kaçırılırken
    // yalnız akrabaların listelerinden çıkarılmıştı; kendi listeleri duruyor).
    _villagers.add(v);
    for (final p in v.parents) {
      if (!p.children.contains(v)) p.children.add(v);
    }
    for (final c in v.children) {
      if (!c.parents.contains(v)) c.parents.add(v);
    }
    // Bırakıldığı yerden köyün meydanına yürür.
    final (cc, cr) = _villageCenter();
    v.goTo(cc.toDouble(), cr.toDouble(), 3.0);
    _feelVillage(NpcEmotion.joy, 10, 0.10);
    if (v.surname.isNotEmpty) _houses.nudge(v.surname, moodDelta: 0.10);
    final ctx = _voice(v, seed: _stableSeed('fidye${v.name}', _dayCount));
    _chronicle(
      Voice.say(const [
        '{ad} fidye karşılığı köye döndü.',
        'Kese boşaldı; {ad} evine kavuştu.',
        '{ad-in} bedeli ödendi, köye geri geldi.',
      ], ctx),
      icon: '🕊️',
      milestone: true,
      kind: ChronicleKind.decision,
    );
    _showNotification(Voice.say(_SceneCrime._kRansomReturnPool, ctx));
  }

  /// Fidye reddedildi — rehin bir daha dönmez.
  void _refuseRansom() {
    final v = _ransomVictim;
    _ransomVictim = null;
    if (v == null) return;
    _feelVillage(NpcEmotion.grief, 14, -0.18);
    pushPolicyMorale(-0.08, 5.0);
    final ctx = _voice(v, seed: _stableSeed('fidyeret${v.name}', _dayCount));
    _chronicle(
      Voice.say(_SceneCrime._kRansomLostAnnalPool, ctx),
      icon: '🕯️',
      milestone: true,
      kind: ChronicleKind.crisis,
    );
    _showNotification(Voice.say(_SceneCrime._kRansomLostPool, ctx));
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DEBUG (DevPanel)
  // ══════════════════════════════════════════════════════════════════════════

  /// Belirli bir suçu hemen tetikle — koşul/olasılık atlanır (test).
  bool _devStartCrime(CrimeKind kind) {
    if (_activeCrime != null) return false;
    final pool = _villagers.where(_crimeEligible).toList()..shuffle(_rng);
    for (final v in pool) {
      final c = _targetFor(v, kind);
      if (c != null) {
        _beginCrime(c);
        return true;
      }
    }
    return false;
  }

  /// Rastgele bir suç tetikle (test).
  bool _devRandomCrime() {
    final kinds = CrimeKind.values.toList()..shuffle(_rng);
    for (final k in kinds) {
      if (_devStartCrime(k)) return true;
    }
    return false;
  }
}
