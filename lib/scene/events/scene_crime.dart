part of '../../main.dart';

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

  /// Suç yeri bir Çan Kulesi menzilindeyse alarm bir kez çalar. Aynı suçta
  /// her tick ses/bildirim üretmemek için olayın üstünde tutulur.
  bool bellRung = false;

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

  /// İçeride geçen süre (sn) — köyün kapıyı izlediği gerilim anı. Uzun tutmak
  /// oyunu durdurur, kısa tutmak "girdi mi çıktı mı" belirsizliği yaratır.
  static const double _kInsideSeconds = 4.5;

  /// Zula gömme işi (sn) — eğilip toprağı eşeleme.
  static const double _kBurySeconds = 2.8;

  /// Taze toprak izinin kapanma süresi (sn) — yarım oyun günü. Bundan sonra
  /// zula yalnız üstüne basılırsa bulunur.
  static const double _kLootFade = 0.5 * kGameDaySeconds;

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
}
