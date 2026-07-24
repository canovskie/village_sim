part of '../main.dart';

/// REJİM — pusulanın oyuncuya dokunan yarısının SAHNE tarafı.
///
/// [Regime] saf kuralları tutar; burası onları köye uygular:
///   • huzursuzluk birikir, eşiği aşınca rejime özgü KRİZ doğar (gerçek dünya
///     etkisi + karar bekleyen bir dilekçe — game-over değil, yeni uğraş),
///   • KÖYÜN YEMİNİ ile köy kendini ilan eder (rejim fermanları açılır),
///   • hür rejimde MECLİS bekleyen dilekçeyi sensiz çözer, baskı rejiminde
///     dilekçe hiç açılmadan çöpe gider,
///   • bir hüküm bedelle FESHEDİLEBİLİR (kimliği yazan hükümler hariç).
extension _SceneRegime on _VillageSceneState {
  // ── Okuma yüzeyi ───────────────────────────────────────────────────────────

  CompassPosition get _compassPos => LawCompass.positionOf(_policies.sealed);

  RegimeIdentity get _regimeIdentity => LawCompass.identify(_compassPos);

  /// Köyün yemin ettiği rejim (yoksa null) — hafıza bayrağından okunur, ayrı
  /// bir doğruluk kaynağı tutulmaz.
  VillageRegime? get _oathRegime {
    for (final r in VillageRegime.values) {
      if (_villageMemory.contains(Regime.oathFlag(r))) return r;
    }
    return null;
  }

  /// Yürürlükteki yetki kuralı — rejim + yemin.
  RegimeRule get _regimeRule =>
      Regime.ruleOf(_regimeIdentity.regime, oath: _oathRegime != null);

  /// Köy kendini ilan edebilir mi (Divan'daki yemin kartı bunu okur).
  bool get _oathAvailable =>
      Regime.oathAvailable(_compassPos, alreadySworn: _oathRegime != null);

  /// Zümre hâlleri — meclis oyu ve köyün kendi kararı buradan okur. Hane
  /// modlarının zümre-yaslanma ağırlıklı ortalaması (politik birim HANE, ama
  /// meclis kürsüsünde zümreler konuşur).
  Map<Estate, double> _estateMoodMap() {
    final sum = <Estate, double>{};
    final n = <Estate, int>{};
    for (final v in _villagers) {
      if (v.isDying || v.surname.isEmpty) continue;
      final e = estateOfVillager(v.type, v.lifeStage);
      sum[e] = (sum[e] ?? 0) + _houses.moodOf(v.surname);
      n[e] = (n[e] ?? 0) + 1;
    }
    return {
      for (final e in Estate.values) e: n[e] == null ? 0.55 : sum[e]! / n[e]!,
    };
  }

  /// Tembellik krizinin üretime yansıması — Demir Sofra huzursuzken tezgâh
  /// soğur. Tarla büyümesi ve balya verimi bu çarpanı yer.
  double get _regimeWorkMul =>
      (_regimeRule.crisis == RegimeCrisis.idleness && _unrest >= Regime.kStir)
          ? 0.82
          : 1.0;

  // ── HUZURSUZLUK DÖNGÜSÜ ────────────────────────────────────────────────────

  /// Her tick huzursuzluğu işletir. Merkez (Ilımlı Köy) hiç birikmez — ılımlı
  /// olmanın cezası yok, ödülü de yok.
  void _tickRegime(double dt) {
    _regimeScan += dt;
    if (_regimeScan < 2.0) return;
    final elapsed = _regimeScan;
    _regimeScan = 0;

    final rule = _regimeRule;
    final days = elapsed / kGameDaySeconds;
    final before = _unrest;
    _unrest = (_unrest +
            Regime.unrestStep(rule,
                morale: _stats.morale, days: days))
        .clamp(0.0, 1.0);

    if (_crisisCooldown > 0) _crisisCooldown -= elapsed;

    // Kıpırdanma eşiği — bir kez, sessiz bir uyarı. Kriz değil, önsezi.
    if (before < Regime.kStir && _unrest >= Regime.kStir && !_unrestStirShown) {
      _unrestStirShown = true;
      final (title, _) = Regime.crisisText(rule.crisis);
      _showNotification('⚠ Köy huzursuz — ${_regimeIdentity.title} '
          'altında sabır azalıyor.${title.isEmpty ? '' : ' ($title yaklaşıyor)'}');
      _chronicle('${_regimeIdentity.title} altında köy homurdanmaya başladı.',
          icon: '⚠');
    }
    if (_unrest < Regime.kStir * 0.7) _unrestStirShown = false;

    // Kriz köyün sırtına biner — sırt yoksa binmez. Avuç içi bir köyde
    // "isyan" hem anlamsız hem yıkıcı (kaçan tek köylü köyü bitirebilir).
    if (_unrest >= Regime.kCrisis &&
        _crisisCooldown <= 0 &&
        rule.crisis != RegimeCrisis.none &&
        _villagers.length >= 6 &&
        _pendingPetition == null &&
        _activeCutscene == null &&
        _imperialDemand == null) {
      _fireRegimeCrisis(rule.crisis);
    }
  }

  /// Kriz: önce DÜNYADA bir şey olur (kaçan köylü, donan divan, soğuyan
  /// tezgâh, açılan makas), sonra köy kapına gelip karar ister. Kriz kendi
  /// başına oyunu bitirmez — çözülünce huzursuzluk düşer, çözülmezse kaynar.
  void _fireRegimeCrisis(RegimeCrisis c) {
    _crisisCooldown = 6.0 * kGameDaySeconds;
    final (title, body) = Regime.crisisText(c);
    addCameraShake(2.2, dur: 0.5);
    _chronicle(title, icon: '🔥', milestone: true);

    final options = <PetitionOption>[];
    final unrestByLabel = <String, double>{};

    switch (c) {
      case RegimeCrisis.revolt:
        // Dünyada olan: en küskün köylü çekip gider.
        final quitter = _mostAggrieved();
        if (quitter != null) _emigrateVillager(quitter);
        pushPolicyMorale(-0.07, 5.0);
        options.addAll([
          const PetitionOption(
            label: 'Meydana in, taviz ver',
            detail: 'Kese açılır, öfke iner.',
            resolutionPool: [
              '👑 Meydanda konuştun. Kese hafifledi, omuzlar gevşedi.'
            ],
            goldDelta: -15,
            moraleAmount: 0.06,
            moraleDays: 5,
            estateMood: [(Estate.laborers, 0.10), (Estate.hearth, 0.08)],
          ),
          const PetitionOption(
            label: 'Elebaşını bul, sürgün et',
            detail: 'Korku susturur — bir süreliğine.',
            resolutionPool: [
              '👑 Elebaşı köyden sürüldü. Meydan sustu; bakışlar susmadı.'
            ],
            moraleAmount: -0.05,
            moraleDays: 4,
            estateMood: [
              (Estate.hearth, -0.10),
              (Estate.faithful, -0.08),
              (Estate.artisans, 0.04),
            ],
          ),
          const PetitionOption(
            label: 'Aldırma',
            detail: 'Duymazdan gel; kaynayan kaynasın.',
            resolutionPool: ['👑 Aldırmadın. Ambar arkasındaki halka büyüdü.'],
            moraleAmount: -0.04,
            moraleDays: 4,
          ),
        ]);
        unrestByLabel['Meydana in, taviz ver'] = -0.50;
        unrestByLabel['Elebaşını bul, sürgün et'] = -0.28;
        unrestByLabel['Aldırma'] = 0.06;

      case RegimeCrisis.deadlock:
        // Dünyada olan: divan donar — mürekkep bir buçuk gün ıslak kalır.
        _policies.inkDryUntilSim = _time + 1.5 * kGameDaySeconds;
        _inkDryTotal = 1.5 * kGameDaySeconds;
        options.addAll([
          const PetitionOption(
            label: 'Arabulucu ata',
            detail: 'Dışarıdan bir söz, düğümü çözer (10 akçe).',
            resolutionPool: [
              '🤝 Arabulucu masaya oturdu. Divan üç gün sonra ilk kez dağıldı.'
            ],
            goldDelta: -10,
            moraleAmount: 0.05,
            moraleDays: 4,
            estateMood: [(Estate.hearth, 0.06), (Estate.laborers, 0.05)],
          ),
          const PetitionOption(
            label: 'Meclisi dağıt, kararı sen ver',
            detail: 'Düğüm çözülür — meşruiyet çözülmez.',
            resolutionPool: [
              '🤝 Meclisi dağıttın. Karar çıktı; kimse alkışlamadı.'
            ],
            moraleAmount: -0.05,
            moraleDays: 4,
            estateMood: [(Estate.laborers, -0.10), (Estate.hearth, -0.06)],
          ),
          const PetitionOption(
            label: 'Bekle, konuşsunlar',
            detail: 'Meşru ama yavaş; divan bir gün daha kilitli.',
            resolutionPool: [
              '🤝 Bekledin. Meclis hâlâ konuşuyor, defter hâlâ kapalı.'
            ],
            estateMood: [(Estate.laborers, 0.04)],
          ),
        ]);
        unrestByLabel['Arabulucu ata'] = -0.45;
        unrestByLabel['Meclisi dağıt, kararı sen ver'] = -0.30;
        unrestByLabel['Bekle, konuşsunlar'] = -0.12;

      case RegimeCrisis.idleness:
        // Dünyada olan: tezgâh soğur (_regimeWorkMul zaten kısıyor) + ambar
        // eriyor; köy bunu sofrada hissetsin.
        _stockpile.food = (_stockpile.food - 12).clamp(0, 1 << 30);
        options.addAll([
          const PetitionOption(
            label: 'Denetçi koy',
            detail: 'Kim ne yaptı yazılır (12 akçe).',
            resolutionPool: [
              '⚖ Denetçi tezgâh tezgâh geziyor. İş yürüdü; keyif kaçtı.'
            ],
            goldDelta: -12,
            estateMood: [(Estate.laborers, -0.08), (Estate.artisans, 0.05)],
          ),
          const PetitionOption(
            label: 'Çok çalışana fazla pay',
            detail: 'Eşitlikten bir tutam ödün.',
            resolutionPool: [
              '⚖ Fazla çalışana fazla pay. Tezgâh ısındı, sofrada mırıltı var.'
            ],
            moraleAmount: 0.04,
            moraleDays: 5,
            estateMood: [(Estate.artisans, 0.12), (Estate.laborers, -0.08)],
          ),
          const PetitionOption(
            label: 'Bir şey yapma',
            detail: 'Pay eşit kalsın, heves nasılsa döner.',
            resolutionPool: ['⚖ Bir şey yapmadın. Tezgâh soğumaya devam etti.'],
            moraleAmount: -0.03,
            moraleDays: 4,
          ),
        ]);
        unrestByLabel['Denetçi koy'] = -0.40;
        unrestByLabel['Çok çalışana fazla pay'] = -0.50;
        unrestByLabel['Bir şey yapma'] = 0.05;

      case RegimeCrisis.inequality:
        // Dünyada olan: en yoksul hane çöker (mood) — makas görünür olsun.
        final poor = _poorestHouse();
        if (poor != null) _houses.nudge(poor, moodDelta: -0.10);
        options.addAll([
          const PetitionOption(
            label: 'Zenginden al, muhtaca ver',
            detail: 'Kese 20 akçe hafifler, sofra dolar.',
            resolutionPool: [
              '🏪 Pay dağıtıldı. Sazlıktaki yatak bu gece boş kaldı.'
            ],
            goldDelta: -20,
            moraleAmount: 0.06,
            moraleDays: 5,
            estateMood: [(Estate.laborers, 0.12), (Estate.artisans, -0.08)],
          ),
          const PetitionOption(
            label: 'Hayrat kur',
            detail: 'Veren el görünsün; makas kapanmaz ama acı diner.',
            resolutionPool: [
              '🏪 Hayrat kuruldu. Kapıda sıra var ama kimse aç dönmüyor.'
            ],
            goldDelta: -8,
            moraleAmount: 0.04,
            moraleDays: 5,
            estateMood: [(Estate.faithful, 0.12), (Estate.hearth, 0.06)],
          ),
          const PetitionOption(
            label: 'Pazar kendi dengesini bulur',
            detail: 'Karışma; kese dolsun.',
            resolutionPool: [
              '🏪 Karışmadın. Kese doldu, sazlıktaki yatak sayısı da arttı.'
            ],
            goldDelta: 15,
            moraleAmount: -0.05,
            moraleDays: 5,
            estateMood: [(Estate.artisans, 0.10), (Estate.laborers, -0.10)],
          ),
        ]);
        unrestByLabel['Zenginden al, muhtaca ver'] = -0.50;
        unrestByLabel['Hayrat kur'] = -0.35;
        unrestByLabel['Pazar kendi dengesini bulur'] = 0.08;

      case RegimeCrisis.none:
        return;
    }

    _regimeCrisisUnrest = unrestByLabel;
    _presentPetition(Petition(
      id: 'regime.crisis.${c.name}',
      petitioner: 'Köyün hâli',
      icon: _regimeIdentity.icon,
      title: title,
      bodyPool: [body],
      stakes: 'Rejimin bedeli — kararsız kalırsan huzursuzluk kaynamaya devam eder.',
      tone: PetitionTone.ominous,
      options: options,
    ));
  }

  /// Kriz dilekçesinin seçilen şıkkının huzursuzluğa etkisi. [_resolvePetition]
  /// içinden çağrılır — kaynak/moral/zümre etkileri zaten genel motora akar,
  /// buradan yalnız rejime özel sayaç oynar.
  void _applyRegimeChoice(Petition p, PetitionOption o) {
    if (!p.id.startsWith('regime.')) return;
    final d = _regimeCrisisUnrest[o.label];
    _regimeCrisisUnrest = const {};
    if (d == null) return;
    _unrest = (_unrest + d).clamp(0.0, 1.0);
    if (d < 0) _unrestStirShown = false;
  }

  /// Köyün en küskün (hane hâli en düşük) yetişkini — isyanda çekip giden o.
  VillagerEntity? _mostAggrieved() {
    VillagerEntity? worst;
    var worstMood = 2.0;
    for (final v in _villagers) {
      if (v.isDying || v.isChild || v.surname.isEmpty) continue;
      final m = _houses.moodOf(v.surname);
      if (m < worstMood) {
        worstMood = m;
        worst = v;
      }
    }
    return worst;
  }

  /// En yoksul hane (üye başına servet en düşük) — makas krizinde çöken o.
  String? _poorestHouse() {
    final wealth = <String, double>{};
    final n = <String, int>{};
    for (final v in _villagers) {
      if (v.isDying || v.surname.isEmpty) continue;
      wealth[v.surname] = (wealth[v.surname] ?? 0) + v.wealth;
      n[v.surname] = (n[v.surname] ?? 0) + 1;
    }
    String? poor;
    var low = double.infinity;
    for (final e in wealth.entries) {
      final per = e.value / n[e.key]!;
      if (per < low) {
        low = per;
        poor = e.key;
      }
    }
    return poor;
  }

  // ── KÖYÜN YEMİNİ ───────────────────────────────────────────────────────────

  /// Köy kendini ilan eder. Sinsi kayma seni ele verir, yemin seni mühürler:
  /// rejim fermanları açılır, yetki keskinleşir — ama huzursuzluk daha hızlı
  /// birikir ve bu kimlikten çıkış artık gerçekten pahalıdır.
  void _swearOath() {
    if (!_oathAvailable) return;
    final id = _regimeIdentity;
    final (title, decree) = Regime.oathText(id);
    if (title.isEmpty) return;

    AudioManager.instance.playSfx(Sfx.bellChime);
    setStateHere(() {
      _villageMemory.add(Regime.oathFlag(id.regime));
      // Yemin köyü toplar: kısa ve gerçek bir moral sıçraması.
      pushPolicyMorale(0.08, 6.0);
      _governanceLegacy = (_governanceLegacy + 0.03).clamp(-0.12, 0.12);
      // Tabanı sevinir, muhalefeti diş sıkar.
      if (id.base != null) {
        _nudgeHousesByEstate(id.base!, moodDelta: 0.12, swayGain: 0.06);
      }
      if (id.dissent != null) {
        _nudgeHousesByEstate(id.dissent!, moodDelta: -0.07);
      }
      _ledgerSection = null; // ilan edildi; defter kapansın, köy meydanda
    });
    _showNotification('${id.icon} $title — köy kendini ilan etti.');
    _chronicle('$title  $decree', icon: id.icon, milestone: true);
    _award('oath.${id.regime.name}', '${id.title}: köy yeminini etti', id.icon);
  }

  // ── MECLİS (hür rejim) ─────────────────────────────────────────────────────

  /// Mühlet doldu ve rejim hür: köy KENDİ kararını verir. Oyuncunun onayı
  /// alınmaz — sistemin vaadi buydu. Karar uygulandıktan sonra oyuncuya bir
  /// veto penceresi açılmaz; itiraz etmek istiyorsa mühlet dolmadan
  /// karar vermeliydi. (Veto = mühlet İÇİNDE [_vetoPetition].)
  void _councilResolvePetition() {
    final p = _pendingPetition;
    if (p == null || p.options.isEmpty) return;
    final i = Regime.pickCouncilOption(p.options,
        mood: _estateMoodMap(), villageMorale: _stats.morale);
    final o = p.options[i];
    _showNotification('🏛 Meclis sen olmadan karar verdi: ${o.label}');
    _chronicle('Meclis "${p.title}" için kendi kararını verdi: ${o.label}.',
        icon: '🏛');
    _resolvePetition(p, o);
    // Köy kendi işini gördü — bu bir başarısızlık değil, rejimin doğası.
    // Yine de senin sesin duyulmadı: küçük bir meşruiyet aşınması.
    _unrest = (_unrest + 0.03).clamp(0.0, 1.0);
  }

  /// Bekleyen dilekçeyi VETO et — hür rejimde oyuncunun kaba kuvveti. Dilekçe
  /// düşer, ama meşruiyet bedeli ödenir (moral + haneler + huzursuzluk).
  void _vetoPetition() {
    final p = _pendingPetition;
    if (p == null) return;
    final rule = _regimeRule;
    setStateHere(() {
      pushPolicyMorale(-rule.vetoMoraleCost, 4.0);
      final e = p.estate;
      if (e != null) _nudgeHousesByEstate(e, moodDelta: -0.10);
      _unrest = (_unrest + 0.10).clamp(0.0, 1.0);
      _petitionCooldowns[p.id] = _time + 3.0 * kGameDaySeconds;
      _pendingPetition = null;
      _petitionAuthor = null;
      _petitionExtra = const {};
      _petitionModalOpen = false;
      _petitionForced = false;
      _petitionTimer = _petitionInterval();
    });
    _showNotification('✋ Dilekçeyi reddettin. Meydan sessiz — ama boş değil.');
    _chronicle('"${p.title}" dilekçesi meclise varmadan reddedildi.', icon: '✋');
  }

  /// Baskı rejimi: mühlet dolan dilekçe zorunlu huzura ÇIKMAZ, sessizce düşer.
  /// Köyün istek kanalı kapalıdır — bedeli huzursuzluk olarak birikir.
  void _silencePetition() {
    final p = _pendingPetition;
    if (p == null) return;
    setStateHere(() {
      _unrest = (_unrest + 0.08).clamp(0.0, 1.0);
      final e = p.estate;
      if (e != null) _nudgeHousesByEstate(e, moodDelta: -0.08);
      _petitionCooldowns[p.id] = _time + 2.0 * kGameDaySeconds;
      _pendingPetition = null;
      _petitionAuthor = null;
      _petitionExtra = const {};
      _petitionModalOpen = false;
      _petitionForced = false;
      _petitionTimer = _petitionInterval();
    });
    _showNotification('⚑ Dilekçe kapıda kaldı. Kimse bir daha sormadı.');
  }

  // ── MECLİS OYU (ferman) ────────────────────────────────────────────────────

  /// Bir ferman meclis oyuna sunulmalı mı — hür + KÖKLÜ rejimde evet.
  /// Ilımlı/eğilimli köyde senin sözün yeter; meşruiyet ancak kimlik
  /// keskinleştikçe bir bedel hâline gelir.
  bool _lawNeedsVote(LawDef l) =>
      _regimeRule.councilVotesLaws && _regimeIdentity.committed;

  CouncilVote _voteOnLaw(LawDef l) => Regime.voteOnLaw(
        effects: l.seal.estateMood,
        mood: _estateMoodMap(),
        villageMorale: _stats.morale,
      );

  // ── FESİH ──────────────────────────────────────────────────────────────────

  /// Bir hükmü bedelle bozar. Bedava toggle DEĞİL: müzakere süresi yanar, köy
  /// moralinde iz kalır, yönetişim mirası zedelenir ve kronik bunu yazar.
  /// Yemin edilmişse bedel ağırlaşır — atalet yeminle derinleşir.
  void _repealLaw(LawDef l) {
    if (!LawBook.repealable(l) || !_policies.sealed.contains(l.id)) return;
    if (_inkDryRemaining() > 0) return;
    final heavy = _oathRegime != null ? 1.6 : 1.0;

    setStateHere(() {
      _policies.restoreSealed(
          [for (final id in _policies.sealed) if (id != l.id) id]);
      // Fermanın yazdığı hafıza bayrakları da kalkar (kapılar tazelensin).
      _villageMemory.removeAll(l.seal.setsFlags);
      _lawCtxCache = null;
      pushPolicyMorale(-0.05 * heavy, 4.0);
      _governanceLegacy =
          (_governanceLegacy - 0.02 * heavy).clamp(-0.12, 0.12);
      _inkDryTotal = l.deliberationDays * kGameDaySeconds * 1.5 * heavy;
      _policies.inkDryUntilSim = _time + _inkDryTotal;
      _applyPolicySideChannels();
      _unrest = (_unrest + 0.06 * heavy).clamp(0.0, 1.0);
      // Fermandan fayda görenler bozulmasına küser.
      for (final (e, d) in l.seal.estateMood) {
        if (d > 0) _nudgeHousesByEstate(e, moodDelta: -d * 0.8);
      }
      _lawRitual = null;
    });
    _showNotification('🕯 ${l.title} defterden silindi. Mürekkep uzun kuruyacak.');
    _chronicle('${l.title} feshedildi.', icon: '🕯', milestone: true);
  }
}
