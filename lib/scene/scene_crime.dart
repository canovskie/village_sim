part of '../main.dart';

/// Suçun evreleri — her biri farklı bir gövde dili.
enum _CrimePhase {
  /// Hedefe sinsice sokulma (çömelmiş, tetikte). Henüz suç işlenmedi.
  prowl,
  /// Eylemin kendisi — oyuncunun suçüstü yakalama penceresi.
  act,
  /// Olay yerinden kaçış. Suç işlendi ama fail hâlâ yakalanabilir.
  flee,
}

/// Sahnede o an işlenmekte olan TEK suç. Aynı anda iki suç yürümez — köy bir
/// suç çukuru değil; nadir, tekil, izlenebilir bir an olsun.
class _ActiveCrime {
  final VillagerEntity culprit;
  final CrimeKind kind;
  /// Kurban (kişiye karşı suçlar) — mala karşı suçlarda null.
  final VillagerEntity? victim;
  /// Hedef bina (hırsızlık/kundak/vandalizm/dolandırıcılık) — yoksa null.
  final BuildingEntity? building;
  /// Hedef hayvan (kaçak av) — yoksa null.
  final AnimalEntity? animal;
  /// Olay yerinin adı — ipucu metninde geçen `{yer}` (isim vermez, yer verir).
  final String place;
  /// Olay yeri (tile).
  double tx, ty;

  _CrimePhase phase = _CrimePhase.prowl;
  /// Bulunulan evrenin kalan süresi (sn).
  double phaseLeft;
  /// Suç TAMAMLANDI mı (etkiler uygulandı mı). Kaçış evresinde true olur;
  /// yakalanma bundan önce olursa suç ÖNLENMİŞ sayılır.
  bool done = false;

  _ActiveCrime({
    required this.culprit,
    required this.kind,
    required this.place,
    required this.tx,
    required this.ty,
    required this.phaseLeft,
    this.victim,
    this.building,
    this.animal,
  });

  CrimeDef get def => CrimeSystem.def(kind);
}

/// SUÇ — köyde nadiren işlenen, faile bağlı, gözle görülür yasadışı eylemler.
///
/// Döngü: köylü bir sebeple suça yeltenir → hedefe SİNSİCE sokulur (prowl) →
/// eylemi yapar (act) → kaçar (flee). Bu süre boyunca oyuncu faile DOKUNARAK
/// suçüstü yakalayabilir; muhafızlar da kendi başlarına koşup yakalayabilir.
/// Yakalanan fail Meclis'e çıkar (yargı dilekçesi: affet / cezalandır / sürgün /
/// idam). Yakalanmayan suç MEÇHUL kalır — sicile yazılmaz, köyde yalnız şüphe
/// biriktirir; şüphe eşiği aşılınca asayiş dilekçesi gelir.
///
/// Sözleşme: köy suç çukuru DEĞİL. Aynı anda tek suç, uzun cooldown, muhafız
/// caydırıcılığı, ağır suçlar SEBEP olmadan doğmaz.
extension _SceneCrime on _VillageSceneState {
  /// Suç taraması (sn) — sık taranır ama çıkış olasılığı düşük → nadir.
  static const double _kCrimePoll = 5.0;
  /// Taban suç olasılığı (poll başına, tek aday için).
  static const double _kCrimeBase = 0.045;
  /// Hedefe sokulma için azami süre — bu kadarda varamazsa vazgeçer (takılma
  /// güvenliği: ulaşılamayan hedefte suç sonsuza kadar askıda kalmasın).
  static const double _kProwlTimeout = 40.0;
  /// Kaçış evresi (sn) — bu pencerede hâlâ yakalanabilir.
  static const double _kFleeSeconds = 9.0;
  /// Suçüstü yakalama mesafesi (tile) — muhafız bu kadar yaklaşırsa yakalar.
  static const double _kCatchDist = 1.3;
  /// Muhafızın GÖRÜŞ alanı (tile) — suç HENÜZ İŞLENİRKEN (sinsi yaklaşma/eylem)
  /// muhafız ancak bu kadar yakındaysa fark eder. Sinsi suç sessizdir: uzaktaki
  /// muhafız göremediği şeye koşamaz.
  static const double _kGuardSight = 7.0;
  /// Suç İŞLENDİKTEN sonra (kaçış) muhafızın duyabileceği azami uzaklık (tile) —
  /// gürültü/telaş köyü ayağa kaldırır, devriye bu menzilde peşine düşer.
  static const double _kGuardResponse = 16.0;
  /// Muhafızın suçu fark etmesi için geçen süre (sn) — anında ışınlanmaz;
  /// önce bir tuhaflık sezer, sonra üstüne yürür.
  static const double _kGuardNotice = 1.5;
  /// Muhafız kovalama hedefini kaç sn'de bir tazeler (fail kaçarken).
  static const double _kChaseRefresh = 0.5;
  /// Suç sonrası failin bekleme süresi (sn) — ~2 oyun günü.
  static const double _kCrimeCooldown = 2.0 * kGameDaySeconds;
  /// Bu kadar MEÇHUL suç birikince asayiş dilekçesi gelir.
  static const int _kSuspicionThreshold = 3;
  /// Ağır suç için gereken asgari sebep yükü — altındaysa yalnız hafif suç.
  static const double _kGraveMotive = 0.6;

  // ── Köyün sesi ([[lib/text/voice.dart]]) — suç metin havuzları ─────────────
  // Suç ANINDA fail İSİMLE ifşa edilmez; köy yalnız bir kıpırtı sezer. İsim
  // ancak yakalanınca geçer.

  static const _kCaughtPlayerPool = [
    '✋ {ad-i} suçüstü yakaladın. Elini indirdi, kaçacak yeri yok.',
    '✋ Üstüne yürüdün, {ad} donakaldı. Suçüstü.',
    '✋ {ad} yakalandı. Köy başına toplanıyor.',
  ];
  static const _kCaughtGuardPool = [
    '🛡️ {muhafız} yetişti: {ad} suçüstü yakalandı.',
    '🛡️ {muhafız} kolundan tuttu. {ad} kıpırdayamıyor.',
    '🛡️ Devriye işini gördü — {ad} suçüstü tutuldu.',
  ];
  static const _kEscapedPool = [
    '🌫️ Gölge kayboldu. Fail meçhul kaldı.',
    '🌫️ Kimse bir yüz göremedi. Suç defterde açık kaldı.',
    '🌫️ İz sürecek kimse yok. Köy sustu.',
  ];
  static const _kSuspicionPool = [
    '👁️ Köy tedirgin. Kapılar erken kilitleniyor.',
    '👁️ Kimse kimseye bakmıyor. Şüphe köye çöktü.',
    '👁️ Üst üste hesap tutmadı. Köy güvenini yitiriyor.',
  ];
  static const _kPardonPool = [
    '🕊️ {ad-i} bağışladın. Başını kaldıramadı.',
    '🕊️ {ad} affedildi. Köyün yarısı sustu, yarısı homurdandı.',
    '🕊️ Elini salladın, {ad} serbest. Bu merhamet hatırlanacak.',
  ];
  static const _kPardonAnnalPool = [
    '{ad} affedildi; ceza kesilmedi.',
    'Köy {ad-i} bağışladı.',
    '{ad-in} suçu bağışlandı; defter kapandı.',
  ];
  static const _kPunishPool = [
    '⛓️ {ad} meydanda teşhir edildi. Kimse yüzüne bakmadı.',
    '⛓️ {ad} cezasını halkın önünde çekti.',
    '⛓️ Hüküm indi: {ad} meydanda cezalandırıldı.',
  ];
  static const _kPunishAnnalPool = [
    '{ad} meydanda cezalandırıldı.',
    'Köy {ad-i} teşhir etti; asayiş sağlandı.',
    '{ad-in} cezası halkın önünde kesildi.',
  ];
  static const _kRescuedPool = [
    '🕊️ {öteki} kurtarıldı. Titriyor ama ayakta.',
    '🕊️ {öteki-i} elinden aldılar. Sağ salim.',
    '🕊️ {öteki} kurtuldu — bir adım geç kalınsa gitmişti.',
  ];
  static const _kRansomReturnPool = [
    '🕊️ Fidye ödendi. {ad} yolun başında göründü.',
    '🕊️ {ad} köye döndü. Kimse bir şey sormadı.',
    '🕊️ Kese boşaldı ama {ad} evinde.',
  ];
  static const _kRansomLostPool = [
    '🕯️ Fidye ödenmedi. {ad} bir daha görülmedi.',
    '🕯️ {ad-i} bekleyen kapı açık kaldı. Dönmedi.',
    '🕯️ Köy {ad-i} yitirdi. Kese doldu, yatak boş.',
  ];
  static const _kRansomLostAnnalPool = [
    '{ad} fidye ödenmediği için bir daha dönmedi.',
    'Köy {ad-i} yitirdi; fidye reddedildi.',
    '{ad-in} yeri boş kaldı.',
  ];

  // ══════════════════════════════════════════════════════════════════════════
  // TİK — suç yürüt + yenisini yokla + muhafız tepkisi
  // ══════════════════════════════════════════════════════════════════════════

  void _tickCrime(double dt) {
    // Test yatağında OYUNCUYU da simüle et: açık kalan her modal sim'i durdurur
    // ve harness'ta tıklayan kimse yoktur → suç dondu sanılır. Otomatik karar
    // ver ki döngü aksın (ve dört hükmün hepsi sırayla denensin).
    if (kCaptureCrime) _captureAutoDecide();

    for (final v in _villagers) {
      if (v.crimeCooldown > 0) v.crimeCooldown -= dt;
    }

    // Yürüyen bir suç varsa: evrelerini ilerlet + muhafızları üstüne sür.
    if (_activeCrime != null) {
      _advanceCrime(dt);
      _guardResponse(dt);
      if (kCaptureCrime) _reportCrime();
      return; // aynı anda tek suç
    }

    _crimePollSec -= dt;
    if (_crimePollSec > 0) return;
    _crimePollSec = _kCrimePoll;
    if (!_hasFire || _villagers.length < 5) return;

    // Test yatağı: olasılık kapısını atla, hemen yeni bir suç kur (bütün
    // evreler + muhafız tepkisi gözlenebilsin). Normal oyunda ASLA çalışmaz.
    if (kCaptureCrime) {
      for (final v in _villagers) {
        v.crimeCooldown = 0;
      }
      final forced = kCaptureCrimeKind;
      if (forced != null) {
        _devStartCrime(forced);
      } else {
        _devRandomCrime();
      }
      _reportCrime();
      return;
    }

    _maybeStartCrime();
  }

  /// Test yatağı: bekleyen modal'ları oyuncu yerine karara bağlar. Yargı
  /// dilekçesinde seçenekleri SIRAYLA dener (af → ceza → sürgün → idam), böylece
  /// tek koşuda dört hükmün de sahne etkileri gözlenir.
  void _captureAutoDecide() {
    if (_activeCutscene != null) {
      setStateHere(() => _activeCutscene = null);
      return;
    }
    final choice = _pendingChoice;
    final opts = choice?.choices;
    if (choice != null && opts != null && opts.isNotEmpty) {
      _applyEventChoice(choice, opts.first);
      return;
    }
    final p = _pendingPetition;
    if (p != null && p.options.isNotEmpty) {
      // LABOR_ONLY test yatağı: yargıda kürek cezası (crimeLabor) varsa hep onu
      // seç → taş kazanımını her mahkûmda gözle. Aksi halde seçenekleri sırayla
      // dene (af→ceza→sürgün→idam→kürek), her hükmün etkisi bir koşuda görülür.
      PetitionOption? o;
      if (kCaptureLaborOnly) {
        for (final opt in p.options) {
          if (opt.fx == PetitionFx.crimeLabor) {
            o = opt;
            break;
          }
        }
      }
      o ??= p.options[_captureVerdictTurn % p.options.length];
      _captureVerdictTurn++;
      _resolvePetition(p, o);
    }
  }

  /// Capture telemetrisi — suçun GERÇEKTEN yürüdüğünü buradan doğrularız
  /// (ekran görüntüsü tek başına "evreler dönüyor mu" sorusunu yanıtlamaz).
  void _reportCrime() {
    final sb = StringBuffer();
    final c = _activeCrime;
    if (c == null) {
      sb.write('suç=yok');
    } else {
      final v = c.culprit;
      final dTarget = _wdist(v.gridX, v.gridY, c.tx, c.ty);
      double dGuard = -1;
      for (final g in _awakeGuards()) {
        final d = _wdist(g.gridX, g.gridY, v.gridX, v.gridY);
        if (dGuard < 0 || d < dGuard) dGuard = d;
      }
      sb.write('${c.kind.name} fail=${v.name}(${v.type.name})'
          ' evre=${c.phase.name} kalan=${c.phaseLeft.toStringAsFixed(1)}'
          ' act=${v.activity.name} st=${v.state.name}'
          ' dHedef=${dTarget.toStringAsFixed(1)}'
          ' dMuhafız=${dGuard < 0 ? 'yok' : dGuard.toStringAsFixed(1)}'
          ' yer=${c.place} done=${c.done ? 1 : 0}'
          ' menzil=${c.done ? _kGuardResponse : _kGuardSight}');
      if (c.victim != null) sb.write(' kurban=${c.victim!.name}');
    }
    final guards = _awakeGuards();
    sb.write(' | muhafız=${guards.length}');
    for (final g in guards) {
      sb.write(' [${g.name} act=${g.activity.name}]');
    }
    sb.write(' şüphe=$_crimeSuspicion sicilli='
        '${_villagers.where((v) => v.crimeCount > 0).length}'
        ' nüfus=${_villagers.length}'
        ' dilekçe=${_pendingPetition?.id ?? '-'}'
        ' rehin=${_ransomVictim?.name ?? '-'}'
        ' yiyecek=${_stockpile.food} altın=${_stockpile.gold}'
        ' taş=${_stockpile.stone}'
        ' nizam=${_policies.sealed.where((f) => f.startsWith('nizam.')).length}'
        ' kürek=$_captureLaborCount');
    // Sim'i durduran modal'lar — harness'ta kimse tıklamadığı için "suç dondu"
    // gibi görünen her şeyin gerçek sebebi burada okunur.
    sb.write(' | durdu: seçim=${_pendingChoice != null ? 1 : 0}'
        ' sinematik=${_activeCutscene != null ? 1 : 0}'
        ' imparator=${_imperialDemand != null ? 1 : 0}'
        ' zorunlu=${_petitionForced ? 1 : 0}');
    kCaptureCrimeReport = sb.toString();
  }

  /// Köyün "çaresizlik" çarpanı — suçu besleyen köy-geneli koşullar.
  double _crimePressure() {
    double g = 1.0;
    if (_wasStarving) g += 0.8;                 // açlık en büyük itki
    if (_stats.morale < 0.4) g += 0.5;          // köy morali dipte
    if (_cycle.dayLight < 0.5) g += 0.4;        // alacakaranlık cesaret verir
    // Bağışlanan suçlular cesaret verir — merhametin politik bedeli.
    g += (_crimePardons * 0.12).clamp(0.0, 0.5);
    // Rejim huzursuzluğu suçu besler: Açık Pazar'da açılan makas, Mühürlü
    // El'de biriken öfke sokağa böyle iner (bkz. scene_regime).
    g += (_unrest * 0.7).clamp(0.0, 0.7);

    // CAYDIRICILIK — devriyedeki her muhafız suçu belirgin biçimde kısar.
    final guards = _awakeGuards().length;
    g /= 1.0 + guards * 0.45;
    // Gece nöbeti yasası yürürlükteyse köy daha zor suç kaldırır.
    if (_villageMemory.contains('crime.watch')) g *= 0.55;
    return g.clamp(0.1, 3.0);
  }

  /// Suça yeltenebilir mi — uyanık, dışarıda, yetişkin, boşta, cooldown'suz.
  /// Muhafız suç işlemez (kanunun kendisi) — sadelik ve okunabilirlik için.
  bool _crimeEligible(VillagerEntity v) =>
      !v.isDying &&
      !v.isSleeping &&
      !v.isInsideBuilding &&
      v.hasProfession &&
      v.type != VillagerType.guard &&
      !v.isCarrying &&
      !v.sitClaimed &&
      v.injuryDays <= 0 &&
      v.activity == VillagerActivity.none &&
      v.chatBubbleTime <= 0 &&
      v.crimeCooldown <= 0 &&
      v.conflictCooldown <= 0;

  /// Köylünün suça yatkınlığı (0..~1.5) — yoksunluk + kırgınlık + mizaç.
  /// Kişilik tek başına suçlu yapmaz; SEFALET yapar (huysuz ama mutlu bir
  /// köylü suça yeltenmez, mutsuz bir yumuşak yeltenebilir).
  double _criminality(VillagerEntity v) {
    double s = 0;
    s += (0.55 - v.morale).clamp(0.0, 1.0) * 1.1; // mutsuzluk baskın etken
    s += (-v.mood).clamp(0.0, 1.0) * 0.25;
    // Yoksulluk — köyün en dibindekiler çalar.
    if (v.wealth < 10) s += 0.35;
    // Küskün hane / çağrı kırgınlığı — köye küsmüş insan kural tanımaz.
    if (v.surname.isNotEmpty && _houses.moodOf(v.surname) < 0.4) s += 0.25;
    if (v.callingFound && v.type != v.calling) s += 0.15;
    // Sabıka — bir kez yakalanmış olan tekrar yeltenmeye daha yatkın.
    s += (v.crimeCount * 0.12).clamp(0.0, 0.35);
    // Mizaç yalnız RENK katar (küçük ağırlık): huysuz/kıpır cesaretlenir,
    // yumuşak/çekingen/gayretli geri durur.
    final traits = v.personality.traits;
    for (int i = 0; i < traits.length; i++) {
      final w = i == 0 ? 1.0 : 0.5;
      s += switch (traits[i]) {
        Trait.grumpy => 0.12 * w,
        Trait.restless => 0.10 * w,
        Trait.brave => 0.06 * w,
        Trait.gentle => -0.18 * w,
        Trait.diligent => -0.14 * w,
        Trait.shy => -0.08 * w,
        _ => 0.0,
      };
    }
    return s.clamp(0.0, 1.5);
  }

  /// AĞIR suçun SEBEP yükü — 0 ise ağır suç doğmaz (rastgele suikast yok).
  /// Kan davası / kin / sefalet / dip moral / küskün hane besler.
  double _graveMotive(VillagerEntity v) {
    double m = 0;
    if (v.inFeud) m += 1.0;                          // kan davası: en güçlü sebep
    if (v.grudges.values.any((t) => t > _time)) m += 0.6; // taze kin
    if (v.morale < 0.22) {
      m += 0.8;                                      // sefalet
    } else if (v.morale < 0.35) {
      m += 0.4;
    }
    if (_wasStarving) m += 0.5;                      // aç insan gözü dönmüş
    if (v.surname.isNotEmpty && _houses.moodOf(v.surname) < 0.3) m += 0.4;
    if (v.crimeCount > 0) m += 0.2;                  // eşiği bir kez geçmiş
    return m;
  }

  /// Uyanık, sahnedeki muhafızlar (caydırıcılık + müdahale).
  List<VillagerEntity> _awakeGuards() => _villagers
      .where((v) =>
          v.type == VillagerType.guard &&
          !v.isDying &&
          !v.isSleeping &&
          !v.isInsideBuilding &&
          v.hasProfession)
      .toList();

  // ══════════════════════════════════════════════════════════════════════════
  // SUÇ SEÇİMİ — kim, neyi, nerede
  // ══════════════════════════════════════════════════════════════════════════

  void _maybeStartCrime() {
    final glob = _crimePressure();

    final eligible = <VillagerEntity>[];
    final crim = <VillagerEntity, double>{};
    for (final v in _villagers) {
      if (!_crimeEligible(v)) continue;
      eligible.add(v);
      crim[v] = _criminality(v);
    }
    if (eligible.isEmpty) return;

    final culprit = _weightedPick(eligible, crim);
    if (culprit == null) return;

    final p = crim[culprit]! * glob * _kCrimeBase;
    if (_rng.nextDouble() >= p.clamp(0.0, 0.5)) return;

    final plan = _planCrime(culprit);
    if (plan == null) return; // uygun hedef yok — bu turda suç yok
    _beginCrime(plan);
  }

  /// Faile uygun bir suç + hedef seçer. Ağır suçlar yalnız SEBEP varsa havuza
  /// girer; her suç kendi hedefini (bina/kurban/hayvan) bulamazsa elenir.
  _ActiveCrime? _planCrime(VillagerEntity v) {
    final motive = _graveMotive(v);
    final graveOk = motive >= _kGraveMotive;

    final cands = <(_ActiveCrime, double)>[];
    void add(_ActiveCrime? c, double w) {
      if (c != null && w > 0) cands.add((c, w));
    }

    for (final def in CrimeSystem.all) {
      if (def.isGrave && !graveOk) continue;
      // Ağır suçun ağırlığı sebep yüküyle ölçeklenir — sebep ne kadar ağırsa
      // o kadar olası (ama hafif suç her zaman daha yaygın).
      final w = def.isGrave ? def.weight * motive * 0.5 : def.weight;
      add(_targetFor(v, def.kind), w);
    }
    if (cands.isEmpty) return null;

    final total = cands.fold<double>(0, (s, c) => s + c.$2);
    var pick = _rng.nextDouble() * total;
    for (final (c, w) in cands) {
      pick -= w;
      if (pick <= 0) return c;
    }
    return cands.last.$1;
  }

  /// Bir suç türü için somut hedef kurar — yoksa null (o suç bu köyde olmaz).
  _ActiveCrime? _targetFor(VillagerEntity v, CrimeKind kind) {
    _ActiveCrime? atBuilding(BuildingEntity? b) {
      if (b == null) return null;
      final spot = _ringSpot(b.col, b.row, b.cols, b.rows, v);
      if (spot == null) return null; // yanına varılamıyor
      return _ActiveCrime(
        culprit: v,
        kind: kind,
        building: b,
        place: kBuildingMeta[b.type]?.label ?? 'köy',
        tx: spot.$1,
        ty: spot.$2,
        phaseLeft: _kProwlTimeout,
      );
    }

    _ActiveCrime? atVictim(VillagerEntity? victim) {
      if (victim == null) return null;
      return _ActiveCrime(
        culprit: v,
        kind: kind,
        victim: victim,
        place: _placeNear(victim.gridX, victim.gridY),
        tx: victim.gridX,
        ty: victim.gridY,
        phaseLeft: _kProwlTimeout,
      );
    }

    switch (kind) {
      case CrimeKind.theft:
        return atBuilding(_lootableBuilding(v));

      case CrimeKind.vandalism:
        return atBuilding(_damageableBuilding(v));

      case CrimeKind.arson:
        return atBuilding(_damageableBuilding(v));

      case CrimeKind.fraud:
        if (_stockpile.gold < 8) return null;
        return atBuilding(_nearestOf(BuildingType.market, v) ??
            _nearestOf(BuildingType.mill, v) ??
            _nearestOf(BuildingType.warehouse, v));

      case CrimeKind.poaching:
        final a = _nearestAnimal(v);
        if (a == null || a.isDying) return null;
        return _ActiveCrime(
          culprit: v,
          kind: kind,
          animal: a,
          place: 'ağıl',
          tx: a.gridX,
          ty: a.gridY,
          phaseLeft: _kProwlTimeout,
        );

      case CrimeKind.pickpocket:
        // Kesesi dolu biri — kendinden zengin olmalı (motive görünür olsun).
        return atVictim(_richVictim(v));

      case CrimeKind.slander:
        return atVictim(_anyVictim(v, protectFavorite: false));

      case CrimeKind.assault:
        // Kin/husumet varsa onu hedefler; yoksa rastgele biri (sebep zaten
        // _graveMotive kapısında kanıtlandı).
        return atVictim(_enemyVictim(v) ?? _anyVictim(v));

      case CrimeKind.assassination:
        // Suikast SEBEPSİZ olmaz: yalnız kan düşmanı ya da kin duyulan biri.
        return atVictim(_enemyVictim(v));

      case CrimeKind.abduction:
        return atVictim(_anyVictim(v));
    }
  }

  /// Soyulabilir bina — depo/pazar/ambar/değirmen. Yoksa null.
  BuildingEntity? _lootableBuilding(VillagerEntity v) =>
      _nearestOf(BuildingType.warehouse, v) ??
      _nearestOf(BuildingType.market, v) ??
      _nearestOf(BuildingType.barn, v) ??
      _nearestOf(BuildingType.mill, v);

  /// Zarar verilebilir/yakılabilir bina — ateş çukuru, fener ve kuyu hariç
  /// (bunlar köyün canı; kundak/vandalizm hedefi olmaz).
  BuildingEntity? _damageableBuilding(VillagerEntity v) {
    final cands = _buildings
        .where((b) =>
            b.type != BuildingType.firepit &&
            b.type != BuildingType.lamppost &&
            b.type != BuildingType.well)
        .toList();
    if (cands.isEmpty) return null;
    return cands[_rng.nextInt(cands.length)];
  }

  /// Failden belirgin biçimde zengin bir kurban (yankesicilik).
  VillagerEntity? _richVictim(VillagerEntity v) {
    final cands = _villagers
        .where((o) =>
            !identical(o, v) &&
            !o.isDying &&
            !o.isSleeping &&
            !o.isInsideBuilding &&
            o.hasProfession &&
            o.wealth > v.wealth + 25)
        .toList();
    if (cands.isEmpty) return null;
    return cands[_rng.nextInt(cands.length)];
  }

  /// Failin kan düşmanı ya da kin duyduğu, sahnedeki biri (ağır suç hedefi).
  /// Favoriler korunur (cozy sözleşmesi: oyuncunun sevdiği köylü maktul olmaz).
  VillagerEntity? _enemyVictim(VillagerEntity v) {
    final cands = _villagers
        .where((o) =>
            !identical(o, v) &&
            !o.isDying &&
            !o.isSleeping &&
            !o.isInsideBuilding &&
            !o.isFavorite &&
            o.hasProfession &&
            (v.isBloodEnemy(o) || v.hasGrudgeWith(o, _time)))
        .toList();
    if (cands.isEmpty) return null;
    return cands[_rng.nextInt(cands.length)];
  }

  /// Sahnedeki herhangi bir uygun kurban. [protectFavorite] true iken favoriler
  /// hedef olmaz (canına kastedilen suçlarda hep true).
  VillagerEntity? _anyVictim(VillagerEntity v, {bool protectFavorite = true}) {
    final cands = _villagers
        .where((o) =>
            !identical(o, v) &&
            !o.isDying &&
            !o.isSleeping &&
            !o.isInsideBuilding &&
            o.hasProfession &&
            o.type != VillagerType.guard && // muhafıza pusu kurulmaz
            (!protectFavorite || !o.isFavorite))
        .toList();
    if (cands.isEmpty) return null;
    return cands[_rng.nextInt(cands.length)];
  }

  /// Bir noktanın "adı" — ipucu metnindeki `{yer}`. En yakın binanın etiketi;
  /// bina yoksa "meydan".
  String _placeNear(double x, double y) {
    BuildingEntity? best;
    double bestD = 6.0;
    for (final b in _buildings) {
      final (bx, by) = _centerOf(b);
      final d = _wdist(x, y, bx, by);
      if (d < bestD) {
        bestD = d;
        best = b;
      }
    }
    if (best == null) return 'meydan';
    return kBuildingMeta[best.type]?.label ?? 'meydan';
  }

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
    _showNotification(Voice.say(
        c.def.hintPool,
        _voice(null,
            seed: _stableSeed('ipucu${c.kind.name}${v.name}', _dayCount),
            extra: {'yer': c.place})));
  }

  void _advanceCrime(double dt) {
    final c = _activeCrime!;
    final v = c.culprit;

    // Fail bir şekilde sahneden düştüyse (öldü/uyudu/taşındı) suç düşer.
    if (v.isDying || v.isSleeping || v.isInsideBuilding) {
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
          vic.gridX = v.gridX + (v.facingRight ? -0.55 : 0.55);
          vic.gridY = v.gridY + 0.25;
          vic.targetCol = vic.gridX;
          vic.targetRow = vic.gridY;
          vic.state = VillagerState.idle;
          vic.idleTimer = 1.0;
          if (_wdist(v.gridX, v.gridY, c.tx, c.ty) <= 1.2 || c.phaseLeft <= 0) {
            _completeCrime(c);
          }
        } else if (c.phaseLeft <= 0) {
          _completeCrime(c);
        }

      case _CrimePhase.flee:
        if (c.phaseLeft <= 0) {
          _escapeCrime(c); // kaçtı — fail meçhul
        }
    }
  }

  /// Hedefe vardı — eylem başlıyor. Baloncuk ANCAK burada çıkar (kısa aksan).
  void _enterActPhase(_ActiveCrime c) {
    final v = c.culprit;
    c.phase = _CrimePhase.act;
    v.activity = VillagerActivity.committing;
    v.chatBubbleIcon = c.def.icon;
    v.hasteFactor = 1.0;

    if (c.kind == CrimeKind.abduction) {
      // Kurbanı kavra, köyün dışına yönel — uzun, görünür bir sürükleme.
      final vic = c.victim!;
      vic.activity = VillagerActivity.abducted;
      vic.feel(NpcEmotion.fear, 12.0, moodDelta: -0.25);
      vic.chatBubbleIcon = '❗';
      vic.chatBubbleTime = 12.0;
      final (ex, ey) = _abductionExit(v);
      c.tx = ex;
      c.ty = ey;
      c.phaseLeft = 30.0; // sürükleme penceresi (yakalama şansı uzun)
      v.hasteFactor = 0.8; // yüklü: yavaş — bu yüzden yakalanabilir
      v.chatBubbleTime = 30.0;
      v.goTo(ex, ey, 1.0);
      _reactNearby(v.gridX, v.gridY, 6.0, NpcEmotion.fear, 3.0, moodDelta: -0.03);
      addCameraShake(3.0, dur: 0.4);
      return;
    }

    c.phaseLeft = c.def.actSeconds;
    v.chatBubbleTime = c.def.actSeconds;
    v.lookToward(c.tx, c.ty);
    // Eylem yerinde dursun (wander eylemin ortasında kaçırmasın).
    v.state = VillagerState.idle;
    v.targetCol = v.gridX;
    v.targetRow = v.gridY;
    v.idleTimer = c.def.actSeconds;
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
    c.phaseLeft = _kFleeSeconds;
    v.activity = VillagerActivity.fleeing;
    v.hasteFactor = 1.35;
    v.chatBubbleIcon = '💨';
    v.chatBubbleTime = _kFleeSeconds;
    v.feel(NpcEmotion.fear, _kFleeSeconds, moodDelta: -0.05);
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
        // Depodan mal aşırır — köyün elinde ne varsa oradan.
        final amount = 6 + _rng.nextInt(9);
        if (_stockpile.food >= amount && _rng.nextBool()) {
          _stockpile.food = (_stockpile.food - amount).clamp(0, 1 << 30);
        } else if (_stockpile.wood >= amount) {
          _stockpile.wood = (_stockpile.wood - amount).clamp(0, 1 << 30);
        } else {
          _stockpile.stone = (_stockpile.stone - amount).clamp(0, 1 << 30);
        }
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
          _burningBuildings.add(b);
          const dur = 14.0;
          _activeFx.add(ActiveFx(
              const EventEffect(
                  fx: EventFx.fireOutbreak,
                  screenTint: Color(0x18FF6020),
                  duration: dur),
              dur));
        }
        _stockpile.wood = (_stockpile.wood - 14).clamp(0, 1 << 30);
        _feelVillage(NpcEmotion.fear, 10, -0.12);
        addCameraShake(6.0, dur: 0.6);

      case CrimeKind.assault:
        if (vic != null) {
          _injureVillager(vic, feud: false, intensity: 1.0);
          _reactNearby(vic.gridX, vic.gridY, 6.0, NpcEmotion.fear, 3.0,
              moodDelta: -0.04);
        }
        _feelVillage(NpcEmotion.fear, 8, -0.08);
        addCameraShake(5.0, dur: 0.5);

      case CrimeKind.abduction:
        if (vic != null) _takeCaptive(vic);

      case CrimeKind.assassination:
        if (vic != null) _assassinate(v, vic);
    }

    // Köy zararı fark eder — ama faili GÖRMEZ (isim geçmez).
    final ctx = _voice(null,
        other: vic,
        seed: _stableSeed('suç${c.kind.name}${v.name}', _dayCount),
        extra: {'yer': c.place});
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
    for (final o in _villagers) {
      o.grudges.remove(v);
      o.bloodEnemies.remove(v);
    }
    _villagers.remove(v);
    if (identical(_selectedVillager, v)) _selectedVillager = null;
    if (identical(_followedVillager, v)) _followedVillager = null;
    if (identical(_petitionAuthor, v)) _petitionAuthor = null;
    _ransomVictim = v;
    _feelVillage(NpcEmotion.fear, 12, -0.14);
    if (v.surname.isNotEmpty) _houses.nudge(v.surname, moodDelta: -0.08);

    // Fidye haberi köye ulaşır. Masada başka bir dilekçe varsa sıraya girer
    // (üstüne binip onu ezmesin) — köy zaten yarım gün içinde haberi alır.
    final p = PetitionSystem.byId('ransom');
    if (p == null) return;
    if (_pendingPetition == null) {
      _presentPetition(p);
    } else {
      _petitionFollowUps
          .add((id: 'ransom', fireAtSim: _time + 0.4 * kGameDaySeconds));
    }
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
    victim.startDying(funeral: true);
    killer.feel(NpcEmotion.fear, 6.0, moodDelta: -0.10);
    _feelVillage(NpcEmotion.grief, 14, -0.20);
    pushPolicyMorale(-0.10, 5.0);
    addCameraShake(8.0, dur: 0.8);
    _activeFx.add(ActiveFx(
        const EventEffect(screenTint: Color(0x40AA1414), duration: 1.6), 1.6));
  }

  /// Suç kaçtı — fail meçhul. Sicile YAZILMAZ (köy failini bilmiyor); yalnız
  /// şüphe birikir. Eşik aşılınca asayiş dilekçesi gelir.
  void _escapeCrime(_ActiveCrime c) {
    final v = c.culprit;
    _clearCrimeState(v);
    v.crimeCooldown = _kCrimeCooldown;
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
          milestone: c.def.isGrave);
      _openVerdict(v, c, prevented: false, guard: null);
      return;
    }

    _crimeSuspicion++;
    _chronicle(
        Voice.say(
            c.def.annalPool,
            _voice(null,
                seed: _stableSeed('meçhul${c.kind.name}$_dayCount', _dayCount))),
        icon: c.def.icon,
        milestone: c.def.isGrave);
    _showNotification(Voice.say(
        _kEscapedPool, _voice(null, seed: _stableSeed('kaçtı${v.name}', _dayCount))));

    if (_crimeSuspicion >= _kSuspicionThreshold) {
      _feelVillage(NpcEmotion.fear, 10, -0.05);
      _showNotification(Voice.say(_kSuspicionPool,
          _voice(null, seed: _stableSeed('şüphe$_crimeSuspicion', _dayCount))));
      if (_pendingPetition == null) {
        final p = PetitionSystem.byId('crimeWave');
        if (p != null) _presentPetition(p);
      }
    }
  }

  /// Suç, hedefe varılamadığı için düştü (kimse görmedi, kimse zarar görmedi).
  void _abortCrime() {
    final c = _activeCrime;
    if (c == null) return;
    _clearCrimeState(c.culprit);
    c.culprit.crimeCooldown = _kCrimeCooldown * 0.5;
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
    for (final g in _villagers) {
      if (g.activity == VillagerActivity.chasing) {
        g.activity = VillagerActivity.none;
        g.hasteFactor = 1.0;
        g.chatBubbleIcon = '';
        g.chatBubbleTime = 0;
      }
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
    if (refresh) _chaseRefresh = _kChaseRefresh;

    // Fark etme süresi — muhafız suça anında ışınlanmaz.
    _crimeNoticed += dt;
    if (_crimeNoticed < _kGuardNotice) return;

    // Menzil: suç işlenmeden GÖRÜŞ, işlendikten sonra GÜRÜLTÜ.
    final range = c.done ? _kGuardResponse : _kGuardSight;

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

    // Yakaladı!
    if (bestD <= _kCatchDist) {
      _catchCriminal(v, guard: best);
      return;
    }

    // Kovalıyor — öne yüklenmiş koşu, hedef taze tutulur. Ateş başında
    // oturuyorsa slotu USULÜNCE bırakır (doğrudan sitClaimed=false yazmak
    // anchor rezervasyonunu sızdırır — o slota bir daha kimse oturamazdı).
    if (best.sitClaimed) best.cancelSit();
    best.activity = VillagerActivity.chasing;
    best.hasteFactor = 1.35;
    best.chatBubbleIcon = '🛡️';
    best.chatBubbleTime = 2.0;
    if (refresh) best.goTo(v.gridX, v.gridY, 0.5);
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

    _clearCrimeState(v);
    v.feel(NpcEmotion.fear, 6.0, moodDelta: -0.15);
    v.chatBubbleIcon = '⛓️';
    v.chatBubbleTime = 5.0;
    v.state = VillagerState.idle;
    v.targetCol = v.gridX;
    v.targetRow = v.gridY;
    v.idleTimer = 6.0;
    v.crimeCooldown = _kCrimeCooldown;
    v.crimeCount++;
    _activeCrime = null;
    _crimeSuspicion = (_crimeSuspicion - 1).clamp(0, 99);

    // Önlendiyse kurban kurtulur (kaçırılan serbest, hedef sağ).
    if (prevented && vic != null && !vic.isDying) {
      if (vic.activity == VillagerActivity.abducted) {
        vic.activity = VillagerActivity.none;
        vic.chatBubbleIcon = '';
        vic.chatBubbleTime = 0;
      }
      vic.feel(NpcEmotion.content, 4.0, moodDelta: 0.10);
      _showNotification(Voice.say(
          _kRescuedPool,
          _voice(v,
              other: vic, seed: _stableSeed('kurtar${vic.name}', _dayCount))));
    }

    _reactNearby(v.gridX, v.gridY, 6.0, NpcEmotion.wonder, 3.0);
    addCameraShake(3.0, dur: 0.35);

    final ctx = _voice(v,
        other: vic,
        seed: _stableSeed('yakala${v.name}', _dayCount),
        extra: {'muhafız': guard?.name ?? ''});
    _showNotification(Voice.say(
        guard != null ? _kCaughtGuardPool : _kCaughtPlayerPool, ctx));
    _chronicle(Voice.say(c.def.caughtAnnalPool, ctx),
        icon: c.def.icon, milestone: c.def.isGrave);
    _lifeEvent(v, Voice.say(c.def.caughtAnnalPool, ctx),
        icon: c.def.icon, milestone: true);

    // Meclis'e çıkar — hüküm senin.
    _openVerdict(v, c, prevented: prevented, guard: guard);
  }

  /// Yakalanan faili yargı dilekçesiyle önüne getirir. Dilekçeyi getiren
  /// (author) KURBAN ya da yakalayan muhafızdır — suçlu değil; "gündeme geldik"
  /// jesti mağdurun hanesine gitsin.
  void _openVerdict(VillagerEntity culprit, _ActiveCrime c,
      {required bool prevented, VillagerEntity? guard}) {
    var p = PetitionSystem.byId('crimeVerdict');
    if (p == null) return;
    // KÜREK CEZASI (NİZAM) — yürürlükteyse yargıya beşinci bir hüküm açılır:
    // mahkûm sürülmez ya da idam edilmez, taş ocağına koşulur (köy taş kazanır,
    // bir el eksilmez). Emek ekseninin sert ama üretken hükmü.
    if (_policies.sealed.contains('nizam.labor')) {
      p = p.withExtraOption(const PetitionOption(
        label: 'Kürek cezasına yolla',
        detail: '{suçlu} zindana atılır, taş ocağında çalıştırılır. Köy taş '
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
      ));
    }
    _accusedCriminal = culprit;
    final author = (c.victim != null && !c.victim!.isDying)
        ? c.victim
        : (guard ?? _nearestWitness(culprit));
    _presentPetition(p, author: author, extra: {
      'suçlu': culprit.name,
      'suç': c.def.label,
      'hal': prevented ? 'son anda önlendi' : 'iş işten geçmişti',
      'sabıka': culprit.crimeCount > 1 ? 'Sabıkalı.' : 'İlk kez.',
    });
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
    v.crimeCooldown = _kCrimeCooldown * 2;
    v.chatBubbleIcon = '🕊️';
    v.chatBubbleTime = 4.0;
    _feelVillage(NpcEmotion.wonder, 6, -0.02);
    final ctx = _voice(v, seed: _stableSeed('af${v.name}', _dayCount));
    _chronicle(Voice.say(_kPardonAnnalPool, ctx), icon: '🕊️');
    _showNotification(Voice.say(_kPardonPool, ctx));
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
    v.crimeCooldown = _kCrimeCooldown * 3;
    v.chatBubbleIcon = '⛓️';
    v.chatBubbleTime = 5.0;
    if (v.surname.isNotEmpty) _houses.nudge(v.surname, moodDelta: -0.06);
    _gatherAtFire(kGameDaySeconds * 0.35, max: 6);
    _feelVillage(NpcEmotion.wonder, 8, 0.03); // düzen görüldü
    addCameraShake(4.0, dur: 0.4);
    final ctx = _voice(v, seed: _stableSeed('ceza${v.name}', _dayCount));
    _chronicle(Voice.say(_kPunishAnnalPool, ctx), icon: '⛓️');
    _showNotification(Voice.say(_kPunishPool, ctx));
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
    // Mahkûm emeği — köy sert hükmün karşılığını taşta görür.
    _stockpile.stone = (_stockpile.stone + 14).clamp(0, 1 << 30);
    _captureLaborCount++; // telemetri: kürek cezası kaç kez uygulandı
    v.feel(NpcEmotion.grief, 6.0, moodDelta: -0.20);
    v.injuryDays = v.injuryDays < 2.0 ? 2.0 : v.injuryDays;
    v.crimeCooldown = _kCrimeCooldown * 3;
    v.chatBubbleIcon = '⛓️';
    v.chatBubbleTime = 5.0;
    if (v.surname.isNotEmpty) _houses.nudge(v.surname, moodDelta: -0.05);
    _feelVillage(NpcEmotion.wonder, 8, 0.02); // düzen görüldü, üretken sertlik
    addCameraShake(3.0, dur: 0.35);
    final ctx = _voice(v, seed: _stableSeed('kürek${v.name}', _dayCount));
    _chronicle(
        Voice.say(const [
          '⛓ {ad} taş ocağına koşuldu. Borcunu taşla ödüyor.',
          '⛓ Kürek hükmü: {ad} zindanda, gündüzleri ocakta.',
        ], ctx),
        icon: '⛓️');
    _showNotification(Voice.say(const [
      '⛓ {ad} kürek cezasına çarptırıldı — köy 14 taş kazandı.',
      '⛓ {ad} taş ocağında. Sert ama üretken bir hüküm.',
    ], ctx));
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
        milestone: true);
    _showNotification(Voice.say(_kRansomReturnPool, ctx));
  }

  /// Fidye reddedildi — rehin bir daha dönmez.
  void _refuseRansom() {
    final v = _ransomVictim;
    _ransomVictim = null;
    if (v == null) return;
    _feelVillage(NpcEmotion.grief, 14, -0.18);
    pushPolicyMorale(-0.08, 5.0);
    final ctx = _voice(v, seed: _stableSeed('fidyeret${v.name}', _dayCount));
    _chronicle(Voice.say(_kRansomLostAnnalPool, ctx),
        icon: '🕯️', milestone: true);
    _showNotification(Voice.say(_kRansomLostPool, ctx));
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
