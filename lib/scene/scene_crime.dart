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

  // ── HIRSIZLIK: eve gir → çuvalla çık → göm (Faz 4) ────────────────────────

  /// Fail binanın İÇİNDE mi ve içeride kalan süre (sn).
  ///
  /// İçerideyken sprite yoktur: ne oyuncu dokunabilir ne muhafız yakalayabilir.
  /// Sahnenin gerilimi tam burada — kapı kapanır, köy bekler. Yakalama penceresi
  /// kaybolmaz, ÇUVALLA ÇIKIŞA kayar (yüklü hırsız yavaştır: `propSpeedFactor`).
  bool inside = false;
  double insideLeft = 0;

  /// Çuvalın içindekiler — gömülürse zulaya geçer, yakalanırsa köye döner.
  /// Çalınan mal buharlaşmaz; yeri değişir.
  ResourceKind? lootKind;
  int lootAmount = 0;
  int weaponAmount = 0;

  /// Zulanın gömüleceği nokta — kaçışın hedefi.
  double bx = 0, by = 0;
  bool buried = false;

  /// Gömme işinin ilerlemesi (sn) — eğilip toprağı eşeleme süresi.
  double buryProgress = 0;

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
  // NOT: taban suç olasılığı (`_kCrimeBase`) KALDIRILDI — suç artık poll başına
  // zar atışıyla doğmuyor. Yeltenme eşiği hakemde: scene_mind `_kCrimeBidFloor`.
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

  // ── Kürek cezası (zindan emeği) ────────────────────────────────────────────
  /// Kürek hükmünün süresi (oyun günü) — mahkûm bu kadar gün ocakta.
  static const double _kLaborSentenceDays = 3.0;

  /// Mahkûmun günlük taş üretimi — köy sert hükmün karşılığını yavaş ama
  /// süregelen bir akışla görür (eski anlık +14 yerine gün gün birikir).
  static const double _kLaborStonePerDay = 6.0;

  /// Hükmün ilk günü peşin verilen taş — "emeğin ilk hasadı" (jest, akış ayrı).
  static const int _kLaborUpfrontStone = 4;

  /// Mahkûmun ocağa "vardım" sayılma mesafesi (tile).
  static const double _kLaborAtQuarry = 1.6;

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
  static const _kPenancePool = [
    '🙏 {ad} günahını meydanda söyledi. Sesi titredi, kimse bölmedi.',
    '🙏 {ad} tövbe etti. Köy dinledi, sonra yavaşça dağıldı.',
    '🙏 Hüküm: tövbe. {ad} bedelini utançla ödedi.',
  ];
  static const _kPenanceAnnalPool = [
    '{ad} meydanda tövbe etti; ceza kesilmedi.',
    'Köy {ad-in} tövbesini dinledi.',
    '{ad-in} günahı meydanda söylendi; defter orada kapandı.',
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
    // KADEMELİ UYANIŞ (bkz. scene_flow) — suç en son uyanır: çalınacak bir
    // şeyin, kıskanılacak bir hanenin olması gerekir. Kuruluş sürerken köyde
    // hırsızlık çıkması oyuncuya "burada bir şey ters" dedirtiyordu; oysa
    // henüz ortada köy yoktu.
    if (!_governanceAwake) return;

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

    // NOT: normal oyunda suç BURADAN doğmaz. Suça yeltenme artık köylünün
    // dürtülerinden doğan bir TEKLİF ([_bidCrime], scene_mind) — "5 saniyede
    // bir köye zar at" değil, "aç ve kırgın olan çalmayı gerçekten ister".
    // Bu blok yalnız test yatağının (kCaptureCrime) zorlama yolunu tutar.
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
      sb.write(
        '${c.kind.name} fail=${v.name}(${v.type.name})'
        ' evre=${c.phase.name} kalan=${c.phaseLeft.toStringAsFixed(1)}'
        ' act=${v.activity.name} st=${v.state.name}'
        ' dHedef=${dTarget.toStringAsFixed(1)}'
        ' dMuhafız=${dGuard < 0 ? 'yok' : dGuard.toStringAsFixed(1)}'
        ' yer=${c.place} done=${c.done ? 1 : 0}'
        ' menzil=${c.done ? _kGuardResponse : _kGuardSight}',
      );
      if (c.victim != null) sb.write(' kurban=${c.victim!.name}');
    }
    final guards = _awakeGuards();
    sb.write(' | muhafız=${guards.length}');
    for (final g in guards) {
      sb.write(' [${g.name} act=${g.activity.name}]');
    }
    sb.write(
      ' şüphe=$_crimeSuspicion sicilli='
      '${_villagers.where((v) => v.crimeCount > 0).length}'
      ' nüfus=${_villagers.length}'
      ' dilekçe=${_pendingPetition?.id ?? '-'}'
      ' rehin=${_ransomVictim?.name ?? '-'}'
      ' yiyecek=${_stockpile.food} altın=${_stockpile.gold}'
      ' taş=${_stockpile.stone}'
      ' nizam=${_policies.sealed.where((f) => f.startsWith('nizam.')).length}'
      ' kürek=$_captureLaborCount',
    );
    // Sim'i durduran modal'lar (sinematik/imparator) + kuyrukta bekleyenler —
    // harness'ta kimse tıklamadığı için "suç dondu" gibi görünen her şeyin
    // gerçek sebebi burada okunur. (Olay/dilekçe artık DONDURMAZ: kapıda
    // kuyruk — yine de bekliyorlarsa raporda görünsün.)
    sb.write(
      ' | durdu: sinematik=${_activeCutscene != null ? 1 : 0}'
      ' imparator=${_imperialDemand != null ? 1 : 0}'
      ' | bekleyen: seçim=${_pendingChoice != null ? 1 : 0}'
      ' gecikmişDilekçe=${_petitionOverdue ? 1 : 0}',
    );
    kCaptureCrimeReport = sb.toString();
  }

  /// Köyün "çaresizlik" çarpanı — suçu besleyen köy-geneli koşullar.
  ///
  /// Dünya-geneli etkenler (açlık, huzursuzluk, mülkiyet rejimi, nöbet yasası)
  /// artık TEK KAPIDAN, [WorldPressure] üstünden girer. Eskiden `_wasStarving`,
  /// `_unrest` ve `crime.watch` burada ayrı ayrı toplanıyordu; aynı yasa hem
  /// bayraktan hem tablodan sayıldığı için caydırıcılık iki kez uygulanıyordu.
  /// Burada kalanlar yalnız suça ÖZGÜ, yerel etkenler.
  double _crimePressure() {
    double g = 1.0;
    if (_stats.morale < 0.4) g += 0.5; // köy morali dipte
    if (_cycle.dayLight < 0.5) g += 0.4; // alacakaranlık cesaret verir
    // Bağışlanan suçlular cesaret verir — merhametin politik bedeli.
    g += (_crimePardons * 0.12).clamp(0.0, 0.5);
    // İMAN: cemaat gözü + günah korkusu suç baskısını kısar (crimeDamp < 1).
    g *= _faithEffect.crimeDamp;

    // KÖYÜN HÂLİ — sebep (açlık/huzursuzluk/mülk) ve caydırıcılık (nöbet/ceza).
    g *= _pressure.crimeUrge;
    g /= _pressure.crimeRisk;

    // CAYDIRICILIK — devriyedeki her muhafız suçu belirgin biçimde kısar.
    final guards = _awakeGuards().length;
    g /= 1.0 + guards * 0.45;
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
      v.waveTime <= 0 && // selamlaşmanın ortasında hırsızlığa kalkmaz
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
    if (v.inFeud) m += 1.0; // kan davası: en güçlü sebep
    if (v.grudges.values.any((t) => t > _time)) m += 0.6; // taze kin
    if (v.morale < 0.22) {
      m += 0.8; // sefalet
    } else if (v.morale < 0.35) {
      m += 0.4;
    }
    if (_wasStarving) m += 0.5; // aç insan gözü dönmüş
    if (v.surname.isNotEmpty && _houses.moodOf(v.surname) < 0.3) m += 0.4;
    if (v.crimeCount > 0) m += 0.2; // eşiği bir kez geçmiş
    return m;
  }

  /// Uyanık, sahnedeki muhafızlar (caydırıcılık + müdahale).
  List<VillagerEntity> _awakeGuards() => _villagers
      .where(
        (v) =>
            v.type == VillagerType.guard &&
            !v.isDying &&
            !v.isSleeping &&
            !v.isInsideBuilding &&
            v.hasProfession,
      )
      .toList();

  // ══════════════════════════════════════════════════════════════════════════
  // SUÇ SEÇİMİ — kim, neyi, nerede
  // ══════════════════════════════════════════════════════════════════════════

  // NOT: eski `_maybeStartCrime` (köy geneli zar atışı) SİLİNDİ. Fail seçimi
  // artık hakemin işi: her köylü kendi dürtüleriyle teklif verir, en çaresiz
  // olan kazanır (bkz. scene_mind `_bidCrime`). `_planCrime`/`_beginCrime`
  // aynen duruyor — yürütme değişmedi, KİMİN ve NEDEN yeltendiği değişti.

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
        return atBuilding(
          _nearestOf(BuildingType.market, v) ??
              _nearestOf(BuildingType.mill, v) ??
              _nearestOf(BuildingType.warehouse, v),
        );

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
        .where(
          (b) =>
              b.type != BuildingType.firepit &&
              b.type != BuildingType.lamppost &&
              b.type != BuildingType.well,
        )
        .toList();
    if (cands.isEmpty) return null;
    return cands[_rng.nextInt(cands.length)];
  }

  /// Failden belirgin biçimde zengin bir kurban (yankesicilik).
  VillagerEntity? _richVictim(VillagerEntity v) {
    final cands = _villagers
        .where(
          (o) =>
              !identical(o, v) &&
              !o.isDying &&
              !o.isSleeping &&
              !o.isInsideBuilding &&
              o.hasProfession &&
              o.wealth > v.wealth + 25,
        )
        .toList();
    if (cands.isEmpty) return null;
    return cands[_rng.nextInt(cands.length)];
  }

  /// Failin kan düşmanı ya da kin duyduğu, sahnedeki biri (ağır suç hedefi).
  /// Favoriler korunur (cozy sözleşmesi: oyuncunun sevdiği köylü maktul olmaz).
  VillagerEntity? _enemyVictim(VillagerEntity v) {
    final cands = _villagers
        .where(
          (o) =>
              !identical(o, v) &&
              !o.isDying &&
              !o.isSleeping &&
              !o.isInsideBuilding &&
              !o.isFavorite &&
              o.hasProfession &&
              (v.isBloodEnemy(o) || v.hasGrudgeWith(o, _time)),
        )
        .toList();
    if (cands.isEmpty) return null;
    return cands[_rng.nextInt(cands.length)];
  }

  /// Sahnedeki herhangi bir uygun kurban. [protectFavorite] true iken favoriler
  /// hedef olmaz (canına kastedilen suçlarda hep true).
  VillagerEntity? _anyVictim(VillagerEntity v, {bool protectFavorite = true}) {
    final cands = _villagers
        .where(
          (o) =>
              !identical(o, v) &&
              !o.isDying &&
              !o.isSleeping &&
              !o.isInsideBuilding &&
              o.hasProfession &&
              o.type != VillagerType.guard && // muhafıza pusu kurulmaz
              (!protectFavorite || !o.isFavorite),
        )
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
    if (c.kind == CrimeKind.theft && c.lootAmount > 0 && !c.buried) {
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
        if (c.kind == CrimeKind.theft && !c.buried && c.lootAmount > 0) {
          if (_wdist(v.gridX, v.gridY, c.bx, c.by) <= 1.2) {
            v.state = VillagerState.idle;
            v.targetCol = v.gridX;
            v.targetRow = v.gridY;
            v.actPose = ActPose.stoop;
            c.buryProgress += dt;
            v.idleTimer = _kBurySeconds - c.buryProgress + 0.2;
            if (c.buryProgress >= _kBurySeconds) _buryLoot(c);
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
    _witnessEvent(
      Notion.crime,
      x: c.tx,
      y: c.ty,
      subject: v,
      subjectName: v.name,
      exclude: c.victim == null ? const [] : [c.victim!],
    );

    if (c.kind == CrimeKind.abduction) {
      // Kurbanı kavra, köyün dışına yönel — uzun, görünür bir sürükleme.
      final vic = c.victim!;
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
    // Eylem yerinde dursun (wander eylemin ortasında kaçırmasın).
    v.state = VillagerState.idle;
    v.targetCol = v.gridX;
    v.targetRow = v.gridY;
    v.idleTimer = c.def.actSeconds;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HIRSIZLIK SAHNESİ (Faz 4) — eve gir → çuvalla çık → göm
  // ══════════════════════════════════════════════════════════════════════════

  /// İçeride geçen süre (sn) — köyün kapıyı izlediği gerilim anı. Uzun tutmak
  /// oyunu durdurur, kısa tutmak "girdi mi çıktı mı" belirsizliği yaratır.
  static const double _kInsideSeconds = 4.5;

  /// Zula gömme işi (sn) — eğilip toprağı eşeleme.
  static const double _kBurySeconds = 2.8;

  /// Taze toprak izinin kapanma süresi (sn) — yarım oyun günü. Bundan sonra
  /// zula yalnız üstüne basılırsa bulunur.
  static const double _kLootFade = 0.5 * kGameDaySeconds;

  /// Fail kapıdan içeri girer — sprite kaybolur, köy kapıyı izler.
  void _enterBuildingToSteal(_ActiveCrime c) {
    final v = c.culprit;
    c.inside = true;
    c.insideLeft = _kInsideSeconds;
    c.phaseLeft = _kInsideSeconds + 2.0; // güvenlik payı (takılma koruması)
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
    _witnessEvent(
      Notion.crime,
      x: v.gridX,
      y: v.gridY,
      subject: v,
      subjectName: v.name,
    );
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
    if (kind == null || amount <= 0) return;

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
    c.phaseLeft = _kFleeSeconds;
    v.activity = VillagerActivity.fleeing;
    v.hasteFactor = 1.35;
    v.feel(NpcEmotion.fear, _kFleeSeconds, moodDelta: -0.05);

    // HIRSIZLIK — kaçış rastgele "uzağa" değil, ZULAYA doğrudur. Yükü olan
    // hırsızın gidecek bir yeri vardır; kaçış penceresi de bu yüzden uzun
    // (yüklü ve yavaş: yakalanabilir olmalı).
    if (c.kind == CrimeKind.theft && c.lootAmount > 0) {
      final (bx, by) = _buryTarget(v);
      c.bx = bx;
      c.by = by;
      c.phaseLeft = _kFleeSeconds * 2.2;
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
        if (_stockpile.weapons > 0 && _rng.nextDouble() < 0.18) {
          c.weaponAmount = 1;
          _stockpile.weapons--;
        }
        kProbeTheftTaken += amount; // prova: malın korunumu kanıtı
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

    // Fidye haberi köye ulaşır. Masada başka bir dilekçe varsa sıraya girer
    // (üstüne binip onu ezmesin) — köy zaten yarım gün içinde haberi alır.
    final p = PetitionSystem.byId('ransom');
    if (p == null) return;
    if (_pendingPetition == null) {
      _presentPetition(p);
    } else {
      // Fidye zincirinin aktörü kaçırılan köylüdür — dilekçe onun adıyla gelir.
      _petitionFollowUps.add((
        id: 'ransom',
        fireAtSim: _time + 0.4 * kGameDaySeconds,
        actor: _ransomVictim,
        actorName: _ransomVictim?.name ?? '',
      ));
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
    if (c.kind == CrimeKind.theft && !c.buried && c.lootAmount > 0) {
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
        _kEscapedPool,
        _voice(null, seed: _stableSeed('kaçtı${v.name}', _dayCount)),
      ),
    );

    if (_crimeSuspicion >= _kSuspicionThreshold) {
      _feelVillage(NpcEmotion.fear, 10, -0.05);
      _showNotification(
        Voice.say(
          _kSuspicionPool,
          _voice(null, seed: _stableSeed('şüphe$_crimeSuspicion', _dayCount)),
        ),
      );
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
    // MAL BUHARLAŞMAZ. İptal, suçun en sessiz çıkışıdır (fail uyudu, öldü,
    // hedefe varamadı) ve çuval elindeyken buradan geçilirse `_clearCrimeState`
    // onu siler: stoktan düşmüş ama dünyada hiçbir yerde olmayan bir mal kalır.
    // Gece bastırıp kaçan hırsız uykuya daldığında tam olarak bu oluyordu.
    if (c.kind == CrimeKind.theft && !c.buried && c.lootAmount > 0) {
      _buryLoot(c); // bulunduğu yere gömülmüş sayılır — geri alınabilir kalır
    }
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
    //
    // KÖYÜN HÂLİ iki ayrı kanaldan büker: uyanık bir devriye daha uzağı GÖRÜR
    // (patrolVigilance), haber veren bir köy suçu daha uzaktan DUYURUR
    // (informUrge — gürültü tek başına değil, ağızdan ağza taşınır).
    final p = _pressure;
    final range = c.done
        ? _kGuardResponse * (0.75 + p.informUrge * 0.9)
        : _kGuardSight * p.patrolVigilance;

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
    if (bestD <= _kCatchDist && !c.inside) {
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
    _witnessEvent(
      Notion.arrest,
      x: v.gridX,
      y: v.gridY,
      subject: v,
      subjectName: v.name,
      loud: true,
    );

    // ÇUVALLA YAKALANDI — mal doğrudan köye döner. Yakalamanın somut ödülü
    // budur: yalnız fail değil, MAL da elde edilir. (Gömdükten sonra
    // yakalanırsa çuval elinde değildir; o mal zulada kalır ve ayrıca
    // bulunması gerekir — kaçış hızının gerçek bir bedeli olsun.)
    final loot = c.lootKind;
    if (loot != null && !c.buried && c.lootAmount > 0) {
      _stockpile.add(loot, c.lootAmount);
      kProbeLootRecovered += c.lootAmount;
      _showNotification(
        '🧺 Çuval geri alındı — ${c.lootAmount} ${loot.label.toLowerCase()} '
        'ambara döndü.',
      );
      c.lootAmount = 0;
    }

    _clearCrimeState(v);
    v.feel(NpcEmotion.fear, 6.0, moodDelta: -0.15);
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
      _showNotification(
        Voice.say(
          _kRescuedPool,
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
      Voice.say(guard != null ? _kCaughtGuardPool : _kCaughtPlayerPool, ctx),
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
    var p = PetitionSystem.byId('crimeVerdict');
    if (p == null) return;
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
    v.crimeCooldown = _kCrimeCooldown * 2;
    _feelVillage(NpcEmotion.wonder, 6, -0.02);
    final ctx = _voice(v, seed: _stableSeed('af${v.name}', _dayCount));
    _chronicle(
      Voice.say(_kPardonAnnalPool, ctx),
      icon: '🕊️',
      kind: ChronicleKind.decision,
    );
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
    if (v.surname.isNotEmpty) _houses.nudge(v.surname, moodDelta: -0.06);
    _gatherAtFire(kGameDaySeconds * 0.35, max: 6);
    _feelVillage(NpcEmotion.wonder, 8, 0.03); // düzen görüldü
    addCameraShake(4.0, dur: 0.4);
    final ctx = _voice(v, seed: _stableSeed('ceza${v.name}', _dayCount));
    _chronicle(
      Voice.say(_kPunishAnnalPool, ctx),
      icon: '⛓️',
      kind: ChronicleKind.decision,
    );
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
    // Kürek hükmü ANLIK bir ödül değil, SÜREGELEN bir emek: mahkûm günlerce
    // ocakta kalır ([_tickConvictLabor] günlük taş üretir + ocağa koşar).
    // Peşin taş yalnız "ilk hasat" jesti; asıl kazanım gün gün birikir.
    v.laborDays = _kLaborSentenceDays;
    // Suç/kaçış durumundan temiz çıkış — bundan sonra hareketi yalnız
    // _tickConvictLabor sürer (çakışan sürücü kalmasın).
    v.activity = VillagerActivity.none;
    v.act = null;
    v.prop = PropKind.none;
    _stockpile.stone = (_stockpile.stone + _kLaborUpfrontStone).clamp(
      0,
      1 << 30,
    );
    _captureLaborCount++; // telemetri: kürek cezası kaç kez uygulandı
    v.feel(NpcEmotion.grief, 6.0, moodDelta: -0.20);
    v.crimeCooldown = _kCrimeCooldown * 3;
    if (v.surname.isNotEmpty) _houses.nudge(v.surname, moodDelta: -0.05);
    _feelVillage(NpcEmotion.wonder, 8, 0.02); // düzen görüldü, üretken sertlik
    addCameraShake(3.0, dur: 0.35);
    final ctx = _voice(
      v,
      seed: _stableSeed('kürek${v.name}', _dayCount),
      extra: {'süre': _kLaborSentenceDays.round().toString()},
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
    v.crimeCooldown = _kCrimeCooldown * 4;
    if (v.surname.isNotEmpty) _houses.nudge(v.surname, moodDelta: -0.04);
    _feelVillage(NpcEmotion.wonder, 8, 0.02);
    final ctx = _voice(v, seed: _stableSeed('tövbe${v.name}', _dayCount));
    _chronicle(
      Voice.say(_kPenanceAnnalPool, ctx),
      icon: '🙏',
      kind: ChronicleKind.decision,
    );
    _lifeEvent(v, Voice.say(_kPenanceAnnalPool, ctx), icon: '🙏');
    _showNotification(Voice.say(_kPenancePool, ctx));
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
          if (_wdist(v.gridX, v.gridY, qx, qy) > _kLaborAtQuarry) {
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
        _convictStoneAcc += _kLaborStonePerDay * dayFrac;
      } else {
        _setWorkPose(v, null);
      }

      v.laborDays -= dayFrac;
      if (v.laborDays <= 0) {
        v.laborDays = 0;
        _setWorkPose(v, null);
        v.crimeCooldown =
            _kCrimeCooldown; // taze salıverme, hemen suça dönmesin
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
    _chronicle(
      Voice.say(_kRansomLostAnnalPool, ctx),
      icon: '🕯️',
      milestone: true,
      kind: ChronicleKind.crisis,
    );
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
