part of '../main.dart';

/// ─── KANUNNAME: MÜHÜR VE İDAME ──────────────────────────────────────────────
///
/// Yasanın SİMÜLASYON tarafı. Eskiden bu mantık `scene_ui.dart` içinde,
/// widget'ların arasında yaşıyordu: "yasa nerede işliyor?" sorusunun cevabı
/// bir UI dosyasıydı. Ayrıldı — burada tek bir sorumluluk var:
///
///   • Kapılar   — [_lawContext] / [_computeLawContext] / [_tickLawGates]:
///     bir hükmün deftere düşebilmesi için dünyanın hangi şartta olması
///     gerektiği (yasa şartı DEĞİL, dünya şartı).
///   • Mühür     — [_sealLaw]: kararın kendisi. Dilekçe karar motorunu
///     ([_applyDecisionEffects]) devralır, mirası işler, mürekkebi ıslatır ve
///     köye duyurur ([_announceLawInVillage]).
///   • İdame     — [_applyLawUpkeep]: bir yasa imzalandığı gün bitmez; her
///     sabah köyün sırtındadır (vergi/öşür/kese + görünür taşıma sahnesi).
///   • Yan kanal — [_applyPolicySideChannels]: global ölçek değişkenleri.
///
/// UI tarafı (Kanunname paneli, mühür ritüeli çizimi) `scene_ui.dart`'ta kalır;
/// burası ondan hiçbir widget bilmez.
extension _SceneLaw on _VillageSceneState {
  // ── KANUNNAME — mühür ──────────────────────────────────────────────────────
  // Eski toggle/cooldown ikilisi öldü. Yerine tek bir eylem var: MÜHÜR. Geri
  // alınmaz, bir günde bir tane basılır, ve basılmadan önce meclis toplanır.

  /// Mürekkebin kuruması için kalan sim saniyesi (0 = defter açık, mühür basılır).
  double _inkDryRemaining() =>
      (_policies.inkDryUntilSim - _time).clamp(0.0, double.infinity);

  /// İlk Belediye tamamlanmadan köyün yazılı hüküm çıkaracak bir makamı yoktur.
  /// Tek tek yasa kapıları bunun SONRASINDA köyün gerçek ihtiyaçlarına göre
  /// açılır; böylece kuruluş kampı ilk günden bir devlet ekranına dönüşmez.
  bool get _lawmakingUnlocked => LawBook.governanceReady(_lawContext);

  /// Fermanı meclisin önüne koy. Meclis burada toplanır — ayrı bir "topla"
  /// düğmesi yok, çünkü meclis bir aksiyon değil, imzanın kendisidir.
  void _openLawRitual(LawDef l) {
    if (!_lawmakingUnlocked) return;
    setStateHere(() => _lawRitual = l);
  }

  void _closeLawRitual() => setStateHere(() => _lawRitual = null);

  /// MÜHRÜ BAS — geri dönüşü yok. Ferman deftere girer, etkileri köye bağlanır,
  /// mürekkep ıslanır (bir sonraki hüküm müzakere bitene dek yazılmaz).
  ///
  /// Bir mühür = bir KARAR. Dilekçe karar motoru ([_applyDecisionEffects])
  /// olduğu gibi devralınır: kaynak deltası, süreli moral, zümre morali+nüfuzu,
  /// köy hafızası bayrağı, zincir dilekçesi. Yasa da bir karardır.
  /// Köyün hâli — ağır yasa kapıları buradan okunur (yasa şartı değil, dünya
  /// şartı). Küçük/genç köy sert hükümleri kaldıramaz.
  /// Köyün hâli — hüküm kapıları buradan okunur (yasa şartı DEĞİL, dünya şartı).
  /// Bir hüküm, DERDİ köyde doğmadan deftere düşmez: tarla açılmadan su yolu,
  /// ilk suç işlenmeden bekçi, ilk beşik sallanmadan beşik fermanı görünmez.
  ///
  /// PERF: set/sayım kurar → her frame değil, saniyede bir tazelenir
  /// ([_lawCtxAge], bkz. _tickLawGates). Mühür anında bir saniyelik bayatlık
  /// zararsız; kapılar zaten yavaş değişen dünya şartları.
  LawContext get _lawContext => _lawCtxCache ??= _computeLawContext();

  LawContext _computeLawContext() {
    var children = 0, elders = 0;
    final houses = <String>{};
    for (final v in _villagers) {
      switch (v.lifeStage) {
        case LifeStage.child:
          children++;
        case LifeStage.elder:
          elders++;
        case LifeStage.youth:
        case LifeStage.adult:
          break;
      }
      if (v.surname.isNotEmpty) houses.add(v.surname);
    }
    return LawContext(
      population: _villagers.length,
      dayCount: _dayCount,
      villageMorale: _morale,
      households: houses.length,
      children: children,
      elders: elders,
      farmTiles: _farmTiles.length,
      animals: _cows.length,
      deaths: _graves.length,
      crimesSeen: _crimesSeen,
      illnessSeen: _illnessSeen,
      feudsSeen: _feudsSeen,
      knownCrafts: _knownCrafts,
      buildings: {for (final b in _buildings) b.type},
      memory: _villageMemory,
    );
  }

  /// KAPI NÖBETİ — köyün hâli değiştikçe deftere yeni hüküm düşer. Sessizce
  /// belirmesin: gündeme gelen her hüküm bir kez duyurulur (bildirim + kronik).
  /// Yeni oyunda ilk tarama sessizdir ([_lawSeen] o an doldurulur) — yoksa köy
  /// kurulur kurulmaz on bildirim üst üste yağar.
  void _tickLawGates(double dt) {
    _lawCtxAge += dt;
    if (_lawCtxAge < 1.0) return;
    _lawCtxAge = 0;
    _lawCtxCache = null; // bir sonraki okumada tazelenir

    // Belediye yokken Kanunname yalnız gizli değildir; arka planda gündem ve
    // "yeni hüküm" bildirimleri de üretmez. Kuruluş akışı önce köyü kurar.
    if (!_lawmakingUnlocked) return;

    final open = LawBook.openAgenda(_policies.sealed, _lawContext);
    final fresh = [
      for (final l in open)
        if (!_lawSeen.contains(l.id)) l,
    ];
    if (fresh.isEmpty) return;
    for (final l in fresh) {
      _lawSeen.add(l.id);
    }
    if (!_lawSeeded) {
      _lawSeeded = true; // ilk tarama: köyün başlangıç gündemi, duyuru yok
      return;
    }
    // Aynı saniyede birden fazla açıldıysa tek satırda topla — üst üste toast
    // yağdırmak yerine "defter kabardı" hissi.
    final title = fresh.length == 1
        ? '${fresh.first.icon} Kanunname\'ye yeni hüküm düştü: ${fresh.first.title}'
        : '📜 Kanunname kabardı — ${fresh.length} yeni hüküm gündemde.';
    _showNotification(title);
    _chronicle(
      fresh.length == 1
          ? '${fresh.first.title} Meclis gündemine girdi.'
          : 'Köyün hâli değişti; deftere ${fresh.length} yeni hüküm düştü.',
      icon: '📜',
    );
  }

  /// KÖYÜN SESİ — o an en çok ihtiyaç duyulan (çıkarılabilir) yasa. Serbest
  /// kataloğun içinden köyün gündemini öne çıkarır: önce geçim, ucuz/hızlı ve
  /// ağır olmayan hüküm. Path DEĞİL, bir tavsiye — istersen başkasını çıkarırsın.
  String? get _lawSpotlightId {
    if (!_lawmakingUnlocked) return null;
    final ctx = _lawContext;
    LawDef? best;
    var bestScore = 1 << 30;
    for (final l in kLawBook) {
      if (!LawBook.available(l, _policies.sealed, ctx)) continue;
      final customary = OralTradition.supports(l, _villageMemory);
      final score =
          (customary ? -2000 : 0) +
          (l.branch == LawBranch.gecim ? 0 : 1000) +
          (l.isGrave ? 500 : 0) +
          (l.deliberationDays * 10).round() +
          l.seal.goldDelta.abs();
      if (score < bestScore) {
        bestScore = score;
        best = l;
      }
    }
    return best?.id;
  }

  void _sealLaw(LawDef l) {
    if (!_lawmakingUnlocked) return;
    if (_inkDryRemaining() > 0) return;
    if (!LawBook.available(l, _policies.sealed, _lawContext)) return;

    final rule = _regimeRule;
    // MECLİS OYU — hür ve köklü bir rejimde ferman senin imzanla değil, köyün
    // rızasıyla geçer. Oy düşerse mühür basılmaz; meclis dağılır ve mürekkep
    // kısa bir süre ıslak kalır (aynı fermanı hemen tekrar dayatamazsın).
    if (_lawNeedsVote(l)) {
      final vote = _voteOnLaw(l);
      if (!vote.passed) {
        AudioManager.instance.playSfx(Sfx.bellChime);
        setStateHere(() {
          _inkDryTotal = 0.6 * kGameDaySeconds;
          _policies.inkDryUntilSim = _time + _inkDryTotal;
          _lawRitual = null;
        });
        final no = vote.voices.where((v) => !v.yes).map((v) => v.line).take(2);
        _showNotification(
          '🏛 Meclis fermanı geçirmedi '
          '(${(vote.support * 100).round()}% destek). ${no.join(' ')}',
        );
        _chronicle(
          '${l.title} meclisten döndü.',
          icon: '🏛',
          kind: ChronicleKind.decision,
        );
        // Reddedilen ferman meşruiyeti aşındırır: ısrar edersen köy gerilir.
        _unrest = (_unrest + 0.04).clamp(0.0, 1.0);
        return;
      }
    }

    // MÜHÜR — Kanunname'nin kendi sesi. Görev/dilekçe/rejim hepsi aynı çanla
    // duyuluyordu; kararın en ağır ânı ayrı bir ses hak ediyor.
    AudioManager.instance.playSfx(Sfx.sealStamp);
    setStateHere(() {
      _policies.seal(l, day: _dayCount); // defterde hükmün yanında duran gün
      _applyDecisionEffects(_lawAsDecision(l), l.seal, null);
      // Büyük fermanlar geçici moralle kalmaz — köy ruhunda sönmeyen bir iz.
      if (l.legacy != 0) {
        _governanceLegacy = (_governanceLegacy + l.legacy).clamp(-0.12, 0.12);
      }
      // Müzakere temposu rejimin: baskıda mürekkep çabuk kurur, hür rejimde
      // meclis uzun konuşur.
      // Rejim temposu × kronik divan felci (Faz 3: iz kalıcı olunca meclis
      // bir türlü toparlanamaz — bkz. scene_regime._chronicInkMul).
      _inkDryTotal =
          l.deliberationDays *
          kGameDaySeconds *
          rule.inkDryMul *
          _chronicInkMul *
          _daimiInkMul;
      _policies.inkDryUntilSim = _time + _inkDryTotal;
      _applyPolicySideChannels();
      _lawCtxCache = null; // yeni mühür kapıları da oynatabilir
      _lawRitual = null;
      // Köy kararı DUYSUN — mühür anının gövde karşılığı (bkz. scene_reactions).
      _announceLawInVillage(l);
      // İlk imza davranışı bildirim sönmeden sokağa insin; sonra ortak motor
      // hükmü günler boyunca aralıklı olarak yeniden oynatır.
      _lawBehaviorNextSim = _time + 2.0;
    });
    _chronicle(
      '${l.title} deftere girdi.',
      icon: l.icon,
      milestone: l.isGrave,
      kind: ChronicleKind.decision,
    );
    if (l.seal.resolution.isNotEmpty) _showNotification(l.seal.resolution);
  }

  /// Mühürü karar motoruna geçirmek için ince sarmalayıcı. `estate` bilerek
  /// null: bir yasa bir haneye değil, bütün köye yazılır — kimse "bizim
  /// dilekçemiz kabul edildi" nüfuzunu ceplemez.
  Petition _lawAsDecision(LawDef l) => Petition(
    id: 'law.${l.id}',
    petitioner: 'Kanunname',
    icon: l.icon,
    title: l.title,
    tone: PetitionTone.solemn,
    bodyPool: [l.decree],
    options: [l.seal],
  );

  /// Mühürlü fermanların GÜNLÜK idamesi — gece bekçisi keseden yer, hane sicili
  /// vergi toplar, öşür ambardan alır. Bir yasa imzalandığı gün bitmez; her
  /// sabah köyün sırtındadır. [_advanceWorldClock] gün dönümünde çağırır.
  void _applyLawUpkeep() {
    final (gold, food) = LawBook.dailyUpkeep(_policies.sealed);
    if (gold != 0) {
      _stockpile.gold = (_stockpile.gold + gold).clamp(0, 1 << 30);
    }
    if (food != 0) {
      _stockpile.food = (_stockpile.food + food).clamp(0, 1 << 30);
    }
    // Sayı değişti — köy de görsün: biri çuvalı sırtlayıp yola çıkar
    // (bkz. scene_reactions._stageLawUpkeep). Yön hesabın işaretinden.
    if (gold != 0 || food != 0) {
      _stageLawUpkeep(collecting: (gold + food) > 0);
    }
    // TEK SÖZ FERMANI — sessizliğin bedeli. Köy sesini yitirdi; her gün küçük
    // bir moral sızıntısı (dilekçe kanalı kapalı, kimse dinlenmiyor). İlk şok
    // fermanın moraleAmount'unda, bu ise sönmeyen tortu: baskının kronik yükü.
    if (_policies.sealed.contains('nizam.sole')) {
      pushPolicyMorale(-0.015, 1.5);
    }
  }

  /// Policy → global side channel'lar (life_stage, animal). Mühür anında ve
  /// init/yükleme'de çağrılır.
  void _applyPolicySideChannels() {
    kMaturityScale = _policies.slowMaturity ? 1.0 / 1.6 : 1.0;
    AnimalEntity.kWanderScale = _policies.freeRange ? 1.5 : 1.0;
    AnimalEntity.kHungerScale = _policies.winterFodder ? 0.55 : 1.0;
    // Ağaç Dikme Fermanı'nın balta yavaşlatması artık GERÇEK oduncuya işler
    // (bkz. _SceneJobs._chopDuration) — eski statik yalnız ölü sınıfça
    // okunuyordu, yani fermanın bu etkisi hiç çalışmıyordu.
  }
}
