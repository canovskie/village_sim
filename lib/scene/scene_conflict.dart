part of '../main.dart';

/// Çekişmeler — köyde NADİREN patlayan ağız dalaşı / yumruklaşma / küsme.
/// Tasarım ([[feedback_event_animation]] + [[feedback_chill_gameplay]]):
///  - Tamamen GÖVDE DİLİ: öfke postürü (mevcut emotion render) + yumruklaşmada
///    ileri-geri itiş hareketi + kamera sarsıntısı. Baş üstü "öfke yüzü" yok;
///    yalnız kısa bir bağırış aksanı baloncuğu (💢) — selam/dans gibi.
///  - Maliyet YOK (cozy): kimse ölmez, kaynak gitmez. Etki anlık mood + kalıcı
///    moral düşüşü ([feel] moodDelta) + küslük (grudge).
///  - GERÇEKÇİ FAKTÖRLERE bağlı: düşük moral, kötü ruh hali, huysuz/gururlu/
///    cesur mizaç (yumuşak/çekingen yatıştırır), çağrı kırgınlığı, küskün zümre,
///    açlık & soğuk gece köy gerginliğini artırır. Yatıştırıcı (yumuşak mizaçlı
///    komşu) araya girip kavgayı büyümeden bitirebilir.
extension _SceneConflict on _VillageSceneState {
  /// Tarama aralığı (sn). Sık taranır ama çıkış olasılığı düşük → nadir.
  static const double _kConflictPoll = 3.0;
  /// Taban kavga olasılığı (poll başına, tek aday çift için). Faktörler bunu
  /// ölçekler; sakin köyde neredeyse hiç, gergin köyde ara sıra.
  static const double _kConflictBase = 0.06;
  /// Küslük süresi (oyun günü) aralığı.
  static const double _kGrudgeMinDays = 2.0;
  static const double _kGrudgeMaxDays = 5.0;

  // ── KAN DAVASI ölümcüllük olasılıkları (yumruklaşma sonucu) ────────────────
  /// İlk kan: kriz anındaki sıradan bir yumruklaşmanın ölümle bitme ihtimali
  /// (çok düşük — kan davası NADİR başlasın).
  static const double _kFirstBloodFatal = 0.05;
  /// İntikam: zaten kan davalı iki kişinin kavgasının ölümle bitme ihtimali
  /// (daha yüksek — kan davası kan ister, döngü kendini besler).
  static const double _kFeudRevengeFatal = 0.13;
  /// Sıradan (kan davasız) ağır yumruklaşmanın ölümle bitme TABAN riski —
  /// şiddetle ölçeklenir, [_kFirstBloodFatal] ile sınırlı. Kavgayı ciddileştirir
  /// (artık her yumruklaşma küçük bir ölüm riski taşır).
  static const double _kBrawlFatalBase = 0.03;

  // ── Köyün sesi: çekişme metin havuzları ([[lib/text/voice.dart]]) ──────────
  // Her satır bir HAVUZ; seed'e göre biri seçilir. Ekler ({ad-i}, {öteki-in})
  // ünlü uyumuyla üretilir — elle yapıştırılmaz.

  static const _kTensionCauses = ['Aç karınlar', 'Sönük yüzler', 'Soğuk geceler'];
  static const _kTensionPool = [
    '⚠️ {sebep} sabırları inceltti. Bugün laf lafı çabuk açıyor.',
    '⚠️ Kuyu başında sesler yükseldi. {sebep} kimseyi rahat bırakmıyor.',
    '⚠️ Selamlar kısaldı, bakışlar uzadı. {sebep} köyü diken üstünde tutuyor.',
  ];

  static const _kHealedLamePool = [
    '💚 {ad} ayağa kalktı. Aksayarak da olsa yürüyor.',
    '💚 {ad-in} yaraları kapandı, topallaması kaldı.',
    '💚 {ad} işinin başına döndü. Adımı eskisi gibi değil.',
  ];
  static const _kHealedPool = [
    '💚 {ad} sargısını bugün kendi çözdü.',
    '💚 {ad-in} yarası kapandı. İlk kez dışarı çıktı.',
    '💚 {ad} yeniden iş tutuyor.',
  ];

  static const _kPeacePool = [
    '🕊️ {ad} ile {öteki} yaka paça olacaktı. {barışçı} ikisinin arasına girdi.',
    '🕊️ {barışçı} elini {ad-in} omzuna koydu. Kavga orada kaldı.',
    '🕊️ {ad} ile {öteki} atıştı. {barışçı} ikisini de bir kenara çekti.',
  ];

  static const _kArguePool = [
    '💢 {ad} ile {öteki} laf yarıştırıyor, aralarında iki adım kalmadı. (ayırmak için dokun)',
    '💢 {ad-in} sesi {öteki-e} yükseldi. Herkes durup baktı. (ayırmak için dokun)',
    '💢 {ad} ile {öteki} çenesini tutamıyor. (ayırmak için dokun)',
  ];
  static const _kBrawlPool = [
    '👊 {ad} ile {öteki} yumruklaştı. Ayırmak için üstlerine dokun.',
    '👊 {ad-in} yumruğu {öteki-e} indi. Ayırmak sana kalmış: üstlerine dokun.',
    '👊 {ad} ile {öteki} toza bulandı, kimse ayırmıyor. (dokun)',
  ];
  static const _kBrawlChroniclePool = [
    '{ad} ile {öteki} yumruklaştı; köy gerildi.',
    '{ad-in} kavgası {öteki-le} meydanda görüldü.',
    'Meydanda kavga: {ad} ile {öteki}.',
  ];

  static const _kSeparatedFeudPool = [
    '✋ Köy {sayı} kişilik kan kavgasının üstüne yürüdü, zorla ayırıyor.',
    '✋ {sayı} kişi birbirine girdi. Köylüler kollarından tutup çekiyor.',
    '✋ Kan davası kavgasına köy hep birlikte daldı: {sayı} kişi zorla ayrılıyor.',
  ];
  static const _kSeparatedPool = [
    '✋ Köylüler koşup kavganın ortasına girdi.',
    '✋ İki komşu kavgaya atıldı, kolları tuttular.',
    '✋ Kimse seyretmedi, araya girip ayırdılar.',
  ];
  static const _kJoinedFeudPool = [
    '🩸 Kan davası kabardı: {sayı} kişi daha kavgaya daldı.',
    '🩸 {sayı} kişi daha koşup geldi. Artık iki soy birbirine girmiş durumda.',
    '🩸 Eski hesap ortaya döküldü, {sayı} kişi daha yumruklara karıştı.',
  ];
  static const _kJoinedPool = [
    '👊 Kavga büyüdü: {sayı} kişi daha karıştı.',
    '👊 Seyredenler duramadı, {sayı} kişi daha araya daldı.',
    '👊 Yumruklar çoğaldı, {sayı} kişi daha girdi işin içine.',
  ];

  static const _kCrippledPool = [
    '🩼 {ad} bir daha eskisi gibi yürüyemeyecek. Dizi o kavgada gitti.',
    '🩼 {ad-i} yerden kaldırdılar. Ayağını basamıyor, bir daha da basamayacak.',
    '🩼 {ad} bastonsuz doğrulamadı. Bu aksaklık artık onun.',
  ];
  static const _kCrippledChroniclePool = [
    '{ad} kavgada sakat kaldı; ömrü boyunca aksayacak.',
    '{ad-in} bir bacağı o kavgada kaldı.',
    'Kavga bitti, {ad} bir daha düz yürüyemedi.',
  ];
  static const _kHurtSeverePool = [
    '🤕 {ad} kanlar içinde kaldı. Günlerce yatacak.',
    '🤕 {ad-i} kollarında taşıdılar. Kaburgası tutmuyor.',
    '🤕 {ad} ağır yedi, bir süre iş göremez.',
  ];
  static const _kHurtPool = [
    '🤕 {ad-in} dudağı patladı.',
    '🤕 {ad} eli yüzü şişmiş halde çekildi.',
    '🤕 {ad} yara aldı ama ayakta durdu.',
  ];

  static const _kRevengePool = [
    '🩸 Kan yerde kalmadı. {ad}, {öteki-i} öldürdü.',
    '🩸 {ad} eski hesabı kapattı: {öteki} yerde.',
    '🩸 {ad} vurdu, {öteki} bir daha kalkmadı. Dava sürüyor.',
  ];
  static const _kRevengeChroniclePool = [
    'Kan davası kan aldı: {ad}, {öteki-i} öldürdü.',
    '{ad}, düşmanı {öteki-i} kavgada öldürdü.',
    '{öteki} kan davasında can verdi; vuran {ad}.',
  ];
  static const _kFeudStartPool = [
    '🩸 {ad} kavgada {öteki-i} öldürdü. İki soy artık birbirine düşman.',
    '🩸 {öteki} meydanda can verdi. Vuran {ad}. İki aile bugünden sonra birbirine bakmaz.',
    '🩸 Yumruk ağır düştü, {öteki} kalkmadı. {ad-in} ailesiyle kan davası başladı.',
  ];
  static const _kFeudStartChroniclePool = [
    'Kan davası başladı: {ad}, kavgada {öteki-i} öldürdü.',
    '{öteki-in} ölümüyle iki aile kan davasına girdi.',
    '{ad} kavgada {öteki-i} öldürdü; iki soy düşman oldu.',
  ];
  static const _kKillPool = [
    '🩸 {ad-in} yumruğu {öteki-i} öldürdü. Kimse buna niyetli değildi.',
    '🩸 Kavga ağır bitti. {öteki} bir daha kalkmadı.',
    '🩸 {ad} elini indirdiğinde {öteki} yerdeydi.',
  ];
  static const _kKillChroniclePool = [
    '{ad} bir kavgada {öteki-i} öldürdü.',
    '{öteki} kavgada öldü; vuran {ad}.',
    'Kavga {öteki-in} ölümüyle bitti.',
  ];

  static const _kIntervenePairPool = [
    '✋ Aralarına girdin. {ad} ile {öteki} ayrıldı, köy nefes aldı.',
    '✋ {ad-i} bir yana, {öteki-i} öbür yana çektin. Kavga bitti.',
    '✋ Sen araya girince ikisi de elini indirdi.',
  ];
  static const _kInterveneSoloPool = [
    '✋ {ad} yumruğunu açtı.',
    '✋ {ad-i} kenara çektin, öfkesi yavaşça indi.',
    '✋ {ad} derin bir nefes aldı. Meydan yatıştı.',
  ];

  static const _kExilePool = [
    '🚷 {ad} yolun başına kadar yürütüldü. Arkasına bakmadı.',
    '🚷 {ad-e} köyün kapısı kapandı.',
    '🚷 {ad} bohçasını topladı, köyden çıkarıldı.',
  ];
  static const _kExileFeudChroniclePool = [
    '{ad} köyden sürüldü; kan davası uzaklaşmayla dindi.',
    '{ad-in} sürgünü kan borcunu kapattı.',
    'Köy {ad-i} sürdü, husumet onunla birlikte gitti.',
  ];
  static const _kExileChroniclePool = [
    '{ad} köyden sürüldü.',
    '{ad-e} köy kapısı kapandı.',
    'Köy {ad-i} artık istemiyordu; gitti.',
  ];
  static const _kExecutePool = [
    '⚖️ {ad} meydanda idam edildi. Kalabalık dağılırken kimse konuşmadı.',
    '⚖️ Hüküm okundu, {ad} diz çöktü. Köy bunu unutmayacak.',
    '⚖️ {ad-in} cezası halkın önünde infaz edildi. Çocukları içeri aldılar.',
  ];
  static const _kExecuteFeudChroniclePool = [
    '{ad} idam edildi; kan davası kanla bastırıldı.',
    'Kan davasının hesabı {ad-in} idamıyla kapandı.',
    'Köy {ad-i} idam etti, husumet orada kesildi.',
  ];
  static const _kExecuteChroniclePool = [
    '{ad} idam edildi.',
    'Meydanda {ad-in} idamı görüldü.',
    'Köy {ad-i} idam etti.',
  ];

  void _tickConflicts(double dt) {
    _recoverInjuries(dt); // yaralılar her tick iyileşir (poll'dan bağımsız)
    _conflictPollSec -= dt;
    if (_conflictPollSec > 0) return;
    _conflictPollSec = _kConflictPoll;
    if (!_hasFire || _villagers.length < 4) return;

    // Köy-geneli gerginlik çarpanı — açlık/soğuk/düşük köy morali alevlendirir.
    double glob = 1.0;
    if (_wasStarving) glob += 0.6;
    if (_cycle.dayLight < 0.28 && !_hasFire) glob += 0.3; // soğuk karanlık
    if (_stats.morale < 0.4) glob += 0.4;

    // GERGİNLİK HERALD'I (#6): kavga nadir ve sebebi görünmezken oyuncu olaya
    // hazırlıksız yakalanır. Gerginlik eşiği aşınca (kavgadan ÖNCE) diegetik
    // bir uyarı + hafif sarsıntı → "köy geriliyor" hissedilir, kör değil.
    _tensionHeraldSec -= dt;
    if (glob >= 1.5 && _tensionHeraldSec <= 0) {
      _tensionHeraldSec = 1.5 * kGameDaySeconds; // günde ~bir kez hatırlat
      final cause = _wasStarving
          ? _kTensionCauses[0]
          : (_stats.morale < 0.4 ? _kTensionCauses[1] : _kTensionCauses[2]);
      addCameraShake(2.0, dur: 0.3);
      _showNotification(Voice.say(
          _kTensionPool,
          _voice(null,
              seed: _stableSeed('tension$cause', _dayCount),
              extra: {'sebep': cause})));
    }

    // Uygun (uyanık, dışarıda, boşta, yetişkin, cooldown'suz) köylüler + öfke yükü.
    final eligible = <VillagerEntity>[];
    final irr = <VillagerEntity, double>{};
    for (final v in _villagers) {
      if (!_conflictEligible(v)) continue;
      eligible.add(v);
      irr[v] = _irritability(v);
    }
    if (eligible.length < 2) return;

    // Tek aday kışkırtıcı — öfke yüküyle ağırlıklı seç (gergin köylü öne çıkar).
    final instigator = _weightedPick(eligible, irr);
    if (instigator == null) return;

    // En yakın uygun komşu (1.9 tile içinde).
    final other = _nearestConflictPartner(instigator, eligible);
    if (other == null) return;

    // Çift kavga olasılığı: ortalama öfke × köy gerginliği × taban; küs çift
    // (eski yara) daha yatkın; KAN DÜŞMANLARI ise sürekli birbirine tutuşur.
    double p = ((irr[instigator]! + irr[other]!) * 0.5) * glob * _kConflictBase;
    if (instigator.isBloodEnemy(other)) {
      p *= 6.0; // kan davası: yan yana gelince neredeyse hep kıvılcım
    } else if (instigator.hasGrudgeWith(other, _time)) {
      p *= 3.0;
    }
    // KANAAT (bkz. villager_memory) — gördükleri yüzünden birbirinden
    // hoşlanmayan iki köylü daha kolay tutuşur. Kavga artık yalnız mizaç ve
    // köy gerginliğinden değil, ARALARINDA GEÇENLERDEN de doğuyor: suçunu
    // gördüğün adamla aynı meydanda durmak zor.
    final mutual = (-instigator.memory.opinionOf(other)).clamp(0.0, 1.0) +
        (-other.memory.opinionOf(instigator)).clamp(0.0, 1.0);
    if (mutual > 0.2) p *= 1.0 + mutual * 1.6;
    if (_rng.nextDouble() >= p.clamp(0.0, 0.9)) return;

    logDev('Kavga tetiği: ${instigator.name} ↔ ${other.name}',
        tag: '⚔', color: AppUi.rust);
    _startConflict(instigator, other, glob);
  }

  /// Kavgaya girebilir mi — uyanık, dışarıda, yetişkin, boşta, cooldown'suz,
  /// AKUT YARALI DEĞİL (yaralı dövüşemez; kalıcı sakat dövüşebilir).
  bool _conflictEligible(VillagerEntity v) =>
      !v.isDying &&
      !v.isSleeping &&
      !v.isInsideBuilding &&
      v.hasProfession &&
      !v.isCarrying &&
      !v.sitClaimed &&
      v.injuryDays <= 0 &&
      v.activity == VillagerActivity.none &&
      v.chatBubbleTime <= 0 &&
      v.conflictCooldown <= 0;

  /// Yaralıların zamanla iyileşmesi — her tick (poll'dan bağımsız). Kilise
  /// (infirmary) varsa köy çapında daha hızlı; kilise YANINDA dinlenen yaralı
  /// çok daha hızlı iyileşir (diegetik şifa). injuryDays dolunca sağlığına
  /// kavuşur (kalıcı sakatlık kalır).
  void _recoverInjuries(double dt) {
    final church = _churchBuilding;
    final cx = church == null ? 0.0 : church.col + church.cols / 2.0;
    final cy = church == null ? 0.0 : church.row + church.rows / 2.0;
    final step = dt / kGameDaySeconds;
    for (final v in _villagers) {
      if (v.injuryDays <= 0) continue;
      double rate = 1.0;
      if (church != null) {
        rate += 0.8; // köyde şifa imkânı → daha hızlı iyileşme
        final dx = v.gridX - cx, dy = v.gridY - cy;
        if (dx * dx + dy * dy <= 5.0 * 5.0) rate += 1.4; // kilise yanında bakım
      }
      v.injuryDays -= step * rate;
      if (v.injuryDays <= 0) {
        v.injuryDays = 0;
        v.feel(NpcEmotion.content, 3.0, moodDelta: 0.06);
        _showNotification(Voice.say(
            v.disabled ? _kHealedLamePool : _kHealedPool, _voice(v)));
      }
    }
  }

  /// Köylünün anlık "öfke yükü" (0..~1.4) — gerçekçi faktörlerden türer.
  double _irritability(VillagerEntity v) {
    double s = 0;
    s += (0.62 - v.morale).clamp(0.0, 1.0) * 0.9; // mutsuzluk en büyük etken
    s += (-v.mood).clamp(0.0, 1.0) * 0.3;         // kötü ruh hali ekler
    s += _traitAggro(v);                          // mizaç
    if (v.callingFound && v.type != v.calling) s += 0.25; // çağrı kırgınlığı
    // Küskün HANE üyesi daha çabuk parlar.
    if (v.surname.isNotEmpty && _houses.moodOf(v.surname) < 0.4) s += 0.25;
    return s.clamp(0.0, 1.4);
  }

  /// Mizaç temelli saldırganlık katkısı — huysuz/cesur/gururlu/kıpır artırır,
  /// yumuşak/çekingen/neşeli yatıştırır. Baskın mizaç tam, ikincil yarım ağırlık.
  double _traitAggro(VillagerEntity v) {
    double a = 0;
    final traits = v.personality.traits;
    for (int i = 0; i < traits.length; i++) {
      final w = i == 0 ? 1.0 : 0.5;
      a += switch (traits[i]) {
        Trait.grumpy => 0.35 * w,
        Trait.brave => 0.20 * w,
        Trait.proud => 0.22 * w,
        Trait.restless => 0.12 * w,
        Trait.gentle => -0.40 * w,
        Trait.shy => -0.18 * w,
        Trait.cheerful => -0.20 * w,
        _ => 0.0,
      };
    }
    return a;
  }

  /// Öfke yüküyle ağırlıklı rastgele köylü seçimi (gergin olan daha olası).
  VillagerEntity? _weightedPick(
      List<VillagerEntity> pool, Map<VillagerEntity, double> weight) {
    double total = 0;
    for (final v in pool) {
      total += weight[v]!.clamp(0.05, 1.4); // herkese küçük taban şans
    }
    if (total <= 0) return null;
    var pick = _rng.nextDouble() * total;
    for (final v in pool) {
      pick -= weight[v]!.clamp(0.05, 1.4);
      if (pick <= 0) return v;
    }
    return pool.last;
  }

  /// [v]'ye en yakın uygun kavga komşusu (1.9 tile içinde) — kan düşmanı varsa
  /// onu önceler (husumet diğer her şeyden güçlü çeker). Yoksa null.
  VillagerEntity? _nearestConflictPartner(
      VillagerEntity v, List<VillagerEntity> pool) {
    VillagerEntity? best;
    double bestD = 1.9 * 1.9;
    VillagerEntity? bestEnemy;
    double bestED = 1.9 * 1.9;
    for (final o in pool) {
      if (identical(o, v)) continue;
      final dx = v.gridX - o.gridX;
      final dy = v.gridY - o.gridY;
      final d2 = dx * dx + dy * dy;
      if (d2 < bestD) {
        bestD = d2;
        best = o;
      }
      if (v.isBloodEnemy(o) && d2 < bestED) {
        bestED = d2;
        bestEnemy = o;
      }
    }
    return bestEnemy ?? best;
  }

  /// İki köylü arasında çekişmeyi başlatır: yüz yüze dönüş + öfke postürü +
  /// bağırış baloncuğu; cesur/gururlu + gergin köyde yumruklaşmaya tırmanır.
  /// Yakındaki yumuşak mizaçlı komşu araya girip büyümeden yatıştırabilir.
  void _startConflict(VillagerEntity a, VillagerEntity b, double glob) {
    // Yüz yüze dön + oldukları yerde dur (wander'a kaçmasınlar).
    _faceAndHold(a, b);
    _faceAndHold(b, a);

    final intensity =
        ((_irritability(a) + _irritability(b)) * 0.5 * glob).clamp(0.0, 1.5);

    // Kan davalı çift mi — husumet kavgayı her zaman yumruklaşmaya çevirir ve
    // sulh olmadıkça hiçbir komşu yatıştıramaz.
    final feudPair = a.isBloodEnemy(b);

    // Yatıştırıcı: yakında yumuşak/neşeli mizaçlı, kavgada olmayan biri (kan
    // davasında işe yaramaz).
    final peace = feudPair ? null : _findPeacemaker(a, b);

    // Yumruklaşma olasılığı: tırmanış + saldırgan mizaç; yatıştırıcı varsa düşük.
    double fist = (intensity - 0.45).clamp(0.0, 1.0) * 0.55 +
        _traitAggro(a).clamp(0.0, 1.0) * 0.3 +
        _traitAggro(b).clamp(0.0, 1.0) * 0.3;
    if (peace != null) fist *= 0.25;
    final brawl = feudPair || _rng.nextDouble() < fist;

    final dur = (brawl ? 4.5 : 3.0) + _rng.nextDouble() * 1.8;
    const shout = '💢';
    for (final v in [a, b]) {
      v.activity = brawl ? VillagerActivity.brawling : VillagerActivity.arguing;
      v.chatBubbleIcon = shout;
      v.chatBubbleTime = dur;
      v.feel(NpcEmotion.anger, dur, moodDelta: brawl ? -0.14 : -0.07);
      v.conflictCooldown = 60.0 + _rng.nextDouble() * 90.0;
    }

    // Çevre tepkisi — komşular dönüp bakar (yumruklaşmada irkilme, ağız
    // dalaşında merak); gövde dili, hafif tedirginlik.
    final mx = (a.gridX + b.gridX) * 0.5;
    final my = (a.gridY + b.gridY) * 0.5;
    _reactNearby(mx, my, brawl ? 5.0 : 4.0,
        brawl ? NpcEmotion.fear : NpcEmotion.wonder, 2.5,
        moodDelta: -0.02);
    // TANIKLIK — yumruklaşma gürültülüdür, bakmayan da duyar. Ağız dalaşı
    // sessizdir: yalnız o yöne bakan görür. Gören, kavgacılara dair kanaatini
    // günlerce taşır (bkz. scene_perception).
    if (brawl) {
      _witnessEvent(Notion.brawl,
          x: mx, y: my, subject: a, subjectName: a.name,
          loud: true, exclude: [a, b]);
    }

    if (brawl) addCameraShake(4.0, dur: 0.4);

    // ── ÖLÜMCÜL TIRMANIŞ ──────────────────────────────────────────────────
    // Yalnız yumruklaşma; intikam (kan davalı) en ölümcül, kriz anı ilk kanı
    // dökebilir, ayrıca HER ağır yumruklaşma ufak bir ölüm riski taşır
    // (şiddetle ölçekli). Favoriler maktul olmaz.
    if (brawl) {
      final double fatal = feudPair
          ? _kFeudRevengeFatal
          : (intensity > 1.0 && glob > 1.3)
              ? _kFirstBloodFatal
              : (_kBrawlFatalBase * intensity).clamp(0.0, _kFirstBloodFatal);
      if (fatal > 0 &&
          _rng.nextDouble() < fatal &&
          _resolveFatalBrawl(a, b, feudPair)) {
        return; // ölüm + (kan davası): normal küslük/kronik akışı atlanır
      }
    }

    // Yatıştırıcı araya girerse: kavga sönimler, o köylü huzur duyar.
    if (peace != null) {
      peace.lookToward(mx, my);
      peace.feel(NpcEmotion.content, 2.5, moodDelta: 0.03);
      _showNotification(Voice.say(
          _kPeacePool,
          _voice(a,
              other: b,
              seed: _stableSeed('peace${a.name}${b.name}', _dayCount),
              extra: {'barışçı': peace.name})));
      return; // yatıştırıldı: küslük/kronik yok
    }

    // SÜRPRİZ TIRMANMA — yalnız yumruklaşma: beklenmedik katılanlar + ayıranlar.
    final escalated = brawl && _escalateBrawl(a, b, dur, feud: feudPair);

    // ── SAKATLIK/YARALANMA — ölümden çok daha sık; kaybeden yaralanır, ağırsa
    // kalıcı sakatlık. Escalation'dan SONRA çağrılır ki yaralanma bildirimi
    // (daha önemli) en son görünsün (_showNotification son çağrıyı gösterir).
    bool injured = false;
    if (brawl) {
      final injChance =
          ((feudPair ? 0.30 : 0.14) + intensity * 0.10).clamp(0.0, 0.6);
      if (_rng.nextDouble() < injChance) {
        injured = _injureLoser(a, b, feud: feudPair, intensity: intensity);
      }
    }

    // Küslük (küsme): kavga sonrası bir süre dargın kalabilirler.
    final grudgeChance = brawl ? 0.6 : 0.30;
    if (_rng.nextDouble() < grudgeChance) {
      _formGrudge(a, b);
    }

    final ctx = _voice(a,
        other: b, seed: _stableSeed('fight${a.name}${b.name}', _dayCount));
    if (brawl) {
      // Yalnız YUMRUKLAŞMADA ses var: atışma sık, sesli olsaydı köy sürekli
      // gürültülü olurdu (ve gerçek kavganın ağırlığı kaybolurdu).
      AudioManager.instance.playSfx(Sfx.fightScuffle);
      _chronicle(Voice.say(_kBrawlChroniclePool, ctx), icon: '💢');
      // Escalation/yaralanma kendi bildirimini verdiyse base'i tekrarlama.
      if (!escalated && !injured) {
        _showNotification(Voice.say(_kBrawlPool, ctx));
      }
    } else {
      _showNotification(Voice.say(_kArguePool, ctx));
    }
  }

  /// Köylüyü [target]'a döndürür ve oldukça yerinde tutar (çekişme süresince
  /// dolaşmaya kaçmasın).
  void _faceAndHold(VillagerEntity v, VillagerEntity target) {
    v.facingRight = target.gridX > v.gridX;
    v.state = VillagerState.idle;
    v.targetCol = v.gridX;
    v.targetRow = v.gridY;
    v.idleTimer = 5.0;
  }

  /// Çiftin yakınında (3 tile) kavgada olmayan yumuşak/neşeli mizaçlı bir
  /// yatıştırıcı bul — yoksa null.
  VillagerEntity? _findPeacemaker(VillagerEntity a, VillagerEntity b) {
    final mx = (a.gridX + b.gridX) * 0.5;
    final my = (a.gridY + b.gridY) * 0.5;
    for (final v in _villagers) {
      if (identical(v, a) || identical(v, b)) continue;
      if (v.isDying || v.isSleeping || v.isInsideBuilding || !v.hasProfession) {
        continue;
      }
      if (v.activity == VillagerActivity.arguing ||
          v.activity == VillagerActivity.brawling) {
        continue;
      }
      final traits = v.personality.traits;
      if (!traits.contains(Trait.gentle) && !traits.contains(Trait.cheerful)) {
        continue;
      }
      final dx = v.gridX - mx;
      final dy = v.gridY - my;
      if (dx * dx + dy * dy <= 3.0 * 3.0) return v;
    }
    return null;
  }

  // ── SÜRPRİZ TIRMANMA — kalabalıklaşma + ayırma ─────────────────────────────

  double _dist2(VillagerEntity v, double mx, double my) {
    final dx = v.gridX - mx;
    final dy = v.gridY - my;
    return dx * dx + dy * dy;
  }

  /// [v], [f]'nin yakın kan akrabası mı (ebeveyn/çocuk/kardeş) — sadakatle
  /// kavgaya katılma kapısı.
  bool _isKin(VillagerEntity v, VillagerEntity f) {
    if (f.parents.contains(v) || f.children.contains(v)) return true;
    for (final p in v.parents) {
      if (f.parents.contains(p)) return true; // ortak ebeveyn = kardeş
    }
    return false;
  }

  /// Bir köylünün "ayırıcı" uygunluğu — yumuşak/neşeli en iyi arabulucu, cesur
  /// fiziken araya girer, yaşlı saygı taşır; huysuz gitmez. ≤0 = uygun değil.
  double _separatorScore(VillagerEntity v) {
    final t = v.personality.traits;
    double s = 0;
    if (t.contains(Trait.gentle)) s += 1.0;
    if (t.contains(Trait.cheerful)) s += 0.7;
    if (t.contains(Trait.brave)) s += 0.5;
    if (v.lifeStage == LifeStage.elder) s += 0.4;
    if (t.contains(Trait.grumpy)) s -= 0.6;
    return s;
  }

  /// Yumruklaşma patlayınca SÜRPRİZ tırmanma: (1) beklenmedik kişiler kavgaya
  /// katılır (kan akrabalığı/husumet/öfke), (2) sakin komşular araya girmeye
  /// koşar ve kavgayı kısaltır. Kan davasında daha kalabalık + kırmızı flaş.
  /// Tamamen gövde dili + goTo koşuşma. Bir bildirim üretirse true döner.
  bool _escalateBrawl(VillagerEntity a, VillagerEntity b, double dur,
      {required bool feud}) {
    final mx = (a.gridX + b.gridX) * 0.5;
    final my = (a.gridY + b.gridY) * 0.5;

    // Kan davası kıvılcımı — kısa kırmızı flaş + güçlü sarsıntı (sürpriz an).
    if (feud) {
      _activeFx.add(ActiveFx(
          const EventEffect(screenTint: Color(0x33AA1414), duration: 1.4), 1.4));
      addCameraShake(7.0, dur: 0.6);
    }

    final fighters = <VillagerEntity>{a, b};

    // ── KATILANLAR — beklenmedik dahil olma ────────────────────────────────
    final maxJoin = feud ? 4 : 2;
    final joinBase = feud ? 0.9 : 0.35;
    int joined = 0;
    final near = _villagers
        .where((v) =>
            !fighters.contains(v) &&
            _conflictEligible(v) &&
            _dist2(v, mx, my) <= 6.5 * 6.5)
        .toList()
      ..sort((x, y) => _dist2(x, mx, my).compareTo(_dist2(y, mx, my)));
    for (final v in near) {
      if (joined >= maxJoin) break;
      double pull = 0;
      if (_isKin(v, a) || _isKin(v, b)) pull += 0.7; // sadakat
      if (feud && (v.isBloodEnemy(a) || v.isBloodEnemy(b))) {
        pull += 0.9; // husumet — kan düşmanı kavgaya dalar
      }
      pull += _traitAggro(v).clamp(0.0, 0.6) * 0.5; // huysuz/cesur kapılır
      pull += (0.55 - v.morale).clamp(0.0, 0.55); // mutsuz kapılır
      if (_rng.nextDouble() >= (joinBase * pull).clamp(0.0, 0.95)) continue;
      // Katıl: kavgaya koş + öfke postürü.
      v.goTo((mx + (_rng.nextDouble() - 0.5) * 1.4).clamp(1.0, kCols - 2.0),
          (my + (_rng.nextDouble() - 0.5) * 1.4).clamp(1.0, kRows - 2.0), dur);
      v.activity = VillagerActivity.brawling;
      v.chatBubbleIcon = '💢';
      v.chatBubbleTime = dur;
      v.feel(NpcEmotion.anger, dur, moodDelta: -0.10);
      v.conflictCooldown = 60.0 + _rng.nextDouble() * 90.0;
      fighters.add(v);
      joined++;
    }

    // ── AYIRANLAR — başkaları araya girip ayırmaya koşar ────────────────────
    final maxSep = (fighters.length >= 3 || feud) ? 2 : 1;
    int sep = 0;
    final calm = _villagers
        .where((v) =>
            !fighters.contains(v) &&
            !v.isDying &&
            !v.isSleeping &&
            !v.isInsideBuilding &&
            v.hasProfession &&
            v.activity != VillagerActivity.brawling &&
            v.activity != VillagerActivity.arguing &&
            _separatorScore(v) > 0 &&
            _dist2(v, mx, my) <= 7.0 * 7.0)
        .toList()
      ..sort((x, y) {
        final px = _separatorScore(x), py = _separatorScore(y);
        if (px != py) return py.compareTo(px);
        return _dist2(x, mx, my).compareTo(_dist2(y, mx, my));
      });
    for (final v in calm) {
      if (sep >= maxSep) break;
      // Koşup araya girme (goTo + feel) ayırmayı anlatır — baş-üstü ✋ ikonu YOK.
      v.goTo((mx + (_rng.nextDouble() - 0.5) * 1.2).clamp(1.0, kCols - 2.0),
          (my + (_rng.nextDouble() - 0.5) * 1.2).clamp(1.0, kRows - 2.0), 3.0);
      v.feel(NpcEmotion.wonder, 3.0, moodDelta: 0.02);
      v.conflictCooldown = 30.0;
      sep++;
    }

    // Ayıran geldiyse kavga kısalır → herkes erken yatışır (görünür "ayırma").
    if (sep > 0) {
      for (final f in fighters) {
        if (f.chatBubbleTime > 3.0) f.chatBubbleTime = 3.0;
      }
      _showNotification(Voice.say(
          feud ? _kSeparatedFeudPool : _kSeparatedPool,
          _voice(a,
              other: b,
              seed: _stableSeed('sep${a.name}${fighters.length}', _dayCount),
              extra: {'sayı': '${fighters.length}'})));
      return true;
    }
    if (joined > 0) {
      _showNotification(Voice.say(
          feud ? _kJoinedFeudPool : _kJoinedPool,
          _voice(a,
              other: b,
              seed: _stableSeed('join${a.name}$joined', _dayCount),
              extra: {'sayı': '$joined'})));
      return true;
    }
    return false;
  }

  /// DEBUG (DevPanel): yan yana iki uygun yetişkin bulup hemen kavga başlatır.
  /// Faktör/olasılık atlanır — test için garantili tetikler.
  bool _devStartConflict() {
    final pool = _villagers.where(_conflictEligible).toList()..shuffle(_rng);
    for (final v in pool) {
      final o = _nearestConflictPartner(v, pool);
      if (o != null) {
        _startConflict(v, o, 1.4); // yüksek gerginlik → yumruklaşmaya yatkın
        return true;
      }
    }
    return false;
  }

  /// DOĞRUDAN MÜDAHALE — oyuncu kavgaya tıklayıp ayırır. Tıklanan dövüşçü +
  /// yanındaki dövüş ortağı anında durdurulur, yatışır; varsa aralarındaki
  /// küslük giderilir (oyuncu barıştırdı). Cozy: anlık + olumlu, bedelsiz,
  /// opsiyonel (kavga zaten kendiliğinden de söner). [v] kavgadaki köylü olmalı.
  void _interveneConflict(VillagerEntity v) {
    // Dövüş ortağı — en yakın diğer kavgacı (4 tile içinde); yoksa tek başına yatıştır.
    VillagerEntity? other;
    double bestD = 4.0 * 4.0;
    for (final o in _villagers) {
      if (identical(o, v)) continue;
      if (o.activity != VillagerActivity.brawling &&
          o.activity != VillagerActivity.arguing) {
        continue;
      }
      final dx = o.gridX - v.gridX;
      final dy = o.gridY - v.gridY;
      final d = dx * dx + dy * dy;
      if (d < bestD) {
        bestD = d;
        other = o;
      }
    }
    setStateHere(() {
      for (final p in [v, ?other]) {
        p.activity = VillagerActivity.none;
        // Yatıştır: öfke postürünü kes + hasarın bir kısmını geri al. Yatışma
        // feel(content) gövde diliyle okunur — baş-üstü 🕊️ ikonu YOK.
        p.feel(NpcEmotion.content, 2.5, moodDelta: 0.05);
        // Hemen tekrar kavgaya tutuşmasın.
        p.conflictCooldown = 90.0 + _rng.nextDouble() * 60.0;
        p.idleTimer = 1.0;
      }
      // Araları düzelt — küslüğü kaldır (oyuncunun müdahalesi barıştırdı).
      if (other != null) {
        v.grudges.remove(other);
        other.grudges.remove(v);
      }
      // #10: Aktif barış sağlamak NET POZİTİF — köy huzuru takdir eder, Ocak
      // (yuva/gelenek) gönlü ısınır. Kavga nadir olduğundan suistimal yok;
      // amaç oyuncuyu pasif izleyici kalmaktan çıkarıp araya girmeye teşvik.
      pushPolicyMorale(0.03, 1.5);
      _nudgeHousesByEstate(Estate.hearth, moodDelta: 0.03, swayGain: 0.02);
    });
    addCameraShake(2.0, dur: 0.25); // hafif "araya girme" dokunuşu
    _showNotification(Voice.say(
        other != null ? _kIntervenePairPool : _kInterveneSoloPool,
        _voice(v,
            other: other,
            seed: _stableSeed('sulh${v.name}', _dayCount + _villagers.length))));
  }

  /// İki köylü arasında karşılıklı küslük kurar (süresi rastgele).
  void _formGrudge(VillagerEntity a, VillagerEntity b) {
    final until = _time +
        (_kGrudgeMinDays +
                _rng.nextDouble() * (_kGrudgeMaxDays - _kGrudgeMinDays)) *
            kGameDaySeconds;
    a.grudges[b] = until;
    b.grudges[a] = until;
  }

  // ════════════════════════════════════════════════════════════════════════
  // SAKATLIK / YARALANMA
  // ════════════════════════════════════════════════════════════════════════

  /// Kavganın kaybedenini (favori değil, en düşük moralli) yaralar. İkisi de
  /// favoriyse kimse yaralanmaz (cozy koruma). Yaralandıysa true.
  bool _injureLoser(VillagerEntity a, VillagerEntity b,
      {required bool feud, required double intensity}) {
    final nonFav = [a, b].where((v) => !v.isFavorite).toList();
    if (nonFav.isEmpty) return false;
    nonFav.sort((x, y) => x.morale.compareTo(y.morale));
    _injureVillager(nonFav.first, feud: feud, intensity: intensity);
    return true;
  }

  /// Bir köylüyü yaralar — şiddet/kan davası ciddiyeti artırır. Ağır + (zaten
  /// yaralı/sakat | yaşlı | şans) → KALICI SAKATLIK. Yaralı kavgadan düşer,
  /// günlerce yavaş kalır (injuryDays), morali düşer; kalıcıysa ömür boyu aksar.
  void _injureVillager(VillagerEntity v,
      {required bool feud, required double intensity}) {
    final severe = _rng.nextDouble() <
        (0.18 + intensity * 0.12 + (feud ? 0.15 : 0.0)).clamp(0.0, 0.6);
    final alreadyHurt = v.injuryDays > 0 || v.disabled;
    final permanent = !v.disabled &&
        severe &&
        (alreadyHurt ||
            v.lifeStage == LifeStage.elder ||
            _rng.nextDouble() < 0.25);

    // Yaralı kavgadan düşer — acı, baş-üstü 🤕 ikonuyla değil GÖVDE DİLİYLE:
    // irkilme/çöküş (feel grief) + injuryDays aksayan duruşu + kiliseye aksayış.
    v.activity = VillagerActivity.none;
    v.feel(NpcEmotion.grief, 3.0, moodDelta: -0.05);
    if (v.conflictCooldown < 120.0) v.conflictCooldown = 120.0;
    addCameraShake(3.0, dur: 0.3);

    // Kilise (infirmary) varsa: yaralı tedavi için oraya aksayarak gider
    // (kilise yanında çok daha hızlı iyileşir — bkz. _recoverInjuries).
    final church = _churchBuilding;
    if (church != null) {
      final (tx, ty) = _nearestLand(
          church.col + church.cols / 2.0, church.row + church.rows + 0.5);
      v.goTo(tx, ty, 8.0);
    }

    final ctx =
        _voice(v, seed: _stableSeed('hurt${v.name}', _dayCount + v.hashCode));
    if (permanent) {
      v.disabled = true;
      v.injuryDays = 1.5 + _rng.nextDouble() * 1.5; // başta ağrılı dönem de var
      v.feel(NpcEmotion.grief, 5.0, moodDelta: -0.18);
      _chronicle(Voice.say(_kCrippledChroniclePool, ctx),
          icon: '🩼', milestone: true);
      _showNotification(Voice.say(_kCrippledPool, ctx));
    } else {
      final days =
          severe ? (2.0 + _rng.nextDouble() * 2.0) : (0.8 + _rng.nextDouble() * 1.2);
      if (days > v.injuryDays) v.injuryDays = days;
      v.feel(NpcEmotion.grief, 4.0, moodDelta: severe ? -0.12 : -0.07);
      _showNotification(
          Voice.say(severe ? _kHurtSeverePool : _kHurtPool, ctx));
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // KAN DAVASI
  // ════════════════════════════════════════════════════════════════════════

  /// Ölümcül yumruklaşma: biri ölür, iki aile kan düşmanı olur (ya da var olan
  /// kan davası kan alır). Favori köylü maktul OLMAZ. Gerçek bir ölüm gerçekleş
  /// tiyse true döner (çağıran normal akışı atlar).
  bool _resolveFatalBrawl(VillagerEntity a, VillagerEntity b, bool feudPair) {
    // Maktul adayı favori olamaz — ikisi de favoriyse ölüm olmaz.
    final nonFav = [a, b].where((v) => !v.isFavorite).toList();
    if (nonFav.isEmpty) return false;
    nonFav.sort((x, y) => x.morale.compareTo(y.morale)); // en mutsuz düşer
    final victim = nonFav.first;
    final killer = identical(victim, a) ? b : a;

    // Aileleri ölümden ÖNCE çıkar (bağlar koparılmadan kan akrabalığını topla).
    final killerKin = _bloodKin(killer);
    final victimKin = _bloodKin(victim);
    final side1 = killerKin.difference(victimKin); // katil tarafı
    final side2 = victimKin.difference(killerKin)..remove(victim); // ölen hariç

    // DİYET FERMANI — kanın bedeli keseden ödenirse öç elle alınmaz: kan davası
    // HİÇ doğmaz. Ama hükmün gücü kesenin gücü kadardır; hazine yetmiyorsa
    // ferman kâğıtta kalır ve husumet her zamanki gibi kurulur. Yönetişimin en
    // acı dersi burada: parası olmayan devletin adaleti de yoktur.
    // `!feudPair`: diyet YENİ husumetin doğmasını engeller, süreni satın almaz.
    // Zaten kan davalı iki hane arasındaki intikam kanı keseyle kapanmaz — o
    // ancak sulh/sürgün/idam ile biter (bkz. _pacifyFeudOf).
    final feudPossible = side1.isNotEmpty && side2.isNotEmpty;
    final bloodPriceLaw = _policies.sealed.contains('nizam.bloodPrice');
    final canPayBlood = bloodPriceLaw &&
        feudPossible &&
        !feudPair &&
        _stockpile.gold >= _kBloodPrice;

    if (canPayBlood) {
      _payBloodPrice(victim: victim, killer: killer, kin: side2);
    } else {
      // Kan davasını kur/genişlet — iki aile karşılıklı kan düşmanı.
      for (final k in side1) {
        for (final e in side2) {
          k.bloodEnemies.add(e);
          e.bloodEnemies.add(k);
        }
      }
      if (feudPossible && !feudPair) {
        _feudsSeen++; // Diyet Fermanı'nın kapısı bunu okur
      }
      if (bloodPriceLaw && feudPossible && !feudPair) {
        _showNotification('🩸 Diyet ödenemedi — kese boş. Husumet kuruldu.');
      }
    }
    final feudFormed = feudPossible && !canPayBlood;

    // Maktulü öldür — aile bağlarını kopar, görünür çöküş + cenaze.
    for (final p in victim.parents) {
      p.children.remove(victim);
    }
    for (final c in victim.children) {
      c.parents.remove(victim);
    }
    victim.startDying(funeral: true);

    // Katil dehşet içinde — kavga postürü kesilir; kan dökme sicili artar.
    killer.feudKills++;
    killer.activity = VillagerActivity.none;
    killer.chatBubbleIcon = '';
    killer.chatBubbleTime = 0;
    killer.feel(NpcEmotion.fear, 5.0, moodDelta: -0.12);

    // Köy sarsılır — derin yas + ağır moral + güçlü kamera sarsıntısı.
    _feelVillage(NpcEmotion.grief, 14, -0.22);
    pushPolicyMorale(-0.12, 6.0);
    addCameraShake(9.0, dur: 0.8);

    // SÜRPRİZ ANİMASYON — kan kıvılcımı: kırmızı flaş + iki klan UZAKTAN irkilir
    // (haritanın öbür ucundan bile başlarını çevirir; husumet/yas gövde dili).
    _activeFx.add(ActiveFx(
        const EventEffect(screenTint: Color(0x4DAA1414), duration: 1.8), 1.8));
    for (final k in side1) {
      if (k.isDying) continue;
      k.lookToward(victim.gridX, victim.gridY);
      // Diyet ödendiyse katil tarafı savunmaya geçmez, utanır: öç beklemiyorlar
      // çünkü hesap kapandı. Fermanın gövde dilindeki karşılığı bu.
      k.feel(canPayBlood ? NpcEmotion.grief : NpcEmotion.anger, 5.0,
          moodDelta: -0.05);
    }
    for (final k in side2) {
      if (k.isDying) continue;
      k.lookToward(killer.gridX, killer.gridY);
      k.feel(NpcEmotion.grief, 6.0, moodDelta: -0.10); // ölen tarafı yasa boğulur
    }

    final ctx = _voice(killer,
        other: victim,
        seed: _stableSeed('kill${killer.name}${victim.name}', _dayCount));
    if (canPayBlood) {
      _chronicle(
          Voice.say(const [
            '{ad} kan döktü; bedeli keseden ödendi, husumet kurulmadı.',
            '{öteki} toprağa verildi. Diyet {öteki-in} hanesine sayıldı; kimse '
                'bıçak çekmedi.',
          ], ctx),
          icon: '🩸',
          milestone: true);
      _showNotification(Voice.say(const [
        '🩸 {ad} kan döktü. Diyet ödendi — kan davası doğmadı.',
        '🩸 Bedel kesildi, öç elden alınmadı. {öteki-in} hanesi keseyi aldı.',
      ], ctx));
    } else if (feudPair) {
      _chronicle(Voice.say(_kRevengeChroniclePool, ctx),
          icon: '🩸', milestone: true);
      _showNotification(Voice.say(_kRevengePool, ctx));
    } else if (feudFormed) {
      _chronicle(Voice.say(_kFeudStartChroniclePool, ctx),
          icon: '🩸', milestone: true);
      _showNotification(Voice.say(_kFeudStartPool, ctx));
    } else {
      _chronicle(Voice.say(_kKillChroniclePool, ctx),
          icon: '🩸', milestone: true);
      _showNotification(Voice.say(_kKillPool, ctx));
    }
    return true;
  }

  /// DİYET — maktulün hanesine köyün kesesinden ödenen kan bedeli.
  ///
  /// Getirisi büyük (nesil aşan bir kan davası hiç doğmaz) o yüzden bedeli de
  /// hissedilir olmalı: tek seferde hazineden ciddi bir kesik. Yoksa ferman
  /// "ölümlerin sonucu olmasın" düğmesine dönerdi.
  static const int _kBloodPrice = 30;

  /// Bedeli öder ve maktulün hanesini tazmin eder. Husumet KURULMAZ — bağları
  /// çağıran zaten atlıyor; burası yalnız kesenin ve hanelerin tarafı.
  void _payBloodPrice({
    required VillagerEntity victim,
    required VillagerEntity killer,
    required Set<VillagerEntity> kin,
  }) {
    _stockpile.gold = (_stockpile.gold - _kBloodPrice).clamp(0, 1 << 30);
    // Maktulün hanesi: para acıyı dindirmez ama görülmüş olmak dindirir.
    if (victim.surname.isNotEmpty) {
      _houses.nudge(victim.surname, moodDelta: 0.10, swayGain: 0.04);
    }
    // Katilin hanesi bedeli köye borçlu: hâli düşer, nüfuzu erir.
    if (killer.surname.isNotEmpty && killer.surname != victim.surname) {
      _houses.nudge(killer.surname, moodDelta: -0.12);
      _houses.drainSway(killer.surname, 0.06);
    }
    // Maktulün yakınları öç yerine yas tutar — gövde dili öfke değil keder.
    for (final k in kin) {
      if (k.isDying) continue;
      k.feel(NpcEmotion.grief, 6.0, moodDelta: -0.08);
    }
    // Diyet ödenmiş bir ölüm köyü yine de sarsar, ama husumetsiz sarsar.
    pushPolicyMorale(0.04, 4.0); // kanın durdurulduğu görüldü (net etki hâlâ eksi)
  }

  /// Bir köylünün yaşayan kan akrabaları (kendisi dahil) — ebeveyn/çocuk graf'ı
  /// üzerinde BFS (kardeşler ortak ebeveyn üzerinden gelir). Ölenler atlanır.
  Set<VillagerEntity> _bloodKin(VillagerEntity start) {
    final seen = <VillagerEntity>{};
    final stack = <VillagerEntity>[start];
    while (stack.isNotEmpty) {
      final v = stack.removeLast();
      if (!seen.add(v)) continue;
      for (final p in v.parents) {
        if (!p.isDying) stack.add(p);
      }
      for (final c in v.children) {
        if (!c.isDying) stack.add(c);
      }
    }
    return seen;
  }

  // ════════════════════════════════════════════════════════════════════════
  // KAN DAVASI ÇÖZÜMLERİ — oyuncunun otoritesi (sulh / sürgün / idam)
  // ════════════════════════════════════════════════════════════════════════

  /// Kan davasının "suçlusu" — en çok kan döken (en yüksek feudKills), eşitlikte
  /// en çok düşmanı olan yaşayan feud üyesi. İdam/sürgün dilekçesinin hedefi.
  VillagerEntity? _feudCulprit() {
    final m = _villagers.where((v) => !v.isDying && v.inFeud).toList();
    if (m.isEmpty) return null;
    m.sort((a, b) {
      final k = b.feudKills.compareTo(a.feudKills);
      if (k != 0) return k;
      return b.bloodEnemies.length.compareTo(a.bloodEnemies.length);
    });
    return m.first;
  }

  /// [anchor]'ın ailesi ile TÜM düşman aileleri arasındaki husumeti siler —
  /// anchor'ın içinde olduğu kan davalarını tümüyle bitirir. Barış/sürgün/idam
  /// hepsi bunu çağırır (adalet/uzaklaştırma kan borcunu kapatır → döngü durur).
  void _pacifyFeudOf(VillagerEntity anchor) {
    final clanA = _bloodKin(anchor);
    final enemies = <VillagerEntity>{};
    for (final x in clanA) {
      enemies.addAll(x.bloodEnemies);
    }
    final enemyClan = <VillagerEntity>{};
    for (final e in enemies) {
      enemyClan.addAll(_bloodKin(e));
    }
    for (final x in clanA) {
      for (final y in enemyClan) {
        x.bloodEnemies.remove(y);
        y.bloodEnemies.remove(x);
      }
    }
  }

  /// SÜRGÜN — oyuncu bir köylüyü köyden kovar. Husumet kan borcu uzaklaştırma
  /// ile kapanır (kan davası diner), köylü köyü terk eder. Kanlı değil ama sert:
  /// köy tedirgin olur. Doğrudan panelden ya da sulh dilekçesinden çağrılır.
  void _exileVillager(VillagerEntity v) {
    final wasFeud = v.inFeud;
    if (wasFeud) _pacifyFeudOf(v);
    // Çevre tedirgin — uzaklaşan kişiye bakar (gövde dili).
    _reactNearby(v.gridX, v.gridY, 6.0, NpcEmotion.fear, 3.0,
        moodDelta: -0.03, alarm: 0.22);
    // SÜRGÜN FERMANI (NİZAM) — yürürlükteyse köy sürgüne alışmıştır; yola
    // vurmanın moral cezası yarıya iner (kapı çoktan aralanmış). Ferman sürgünü
    // bir travma olmaktan çıkarıp bir prosedüre çevirir — kılıç yolunun bedeli.
    final exileMorale = _policies.sealed.contains('nizam.exile') ? -0.025 : -0.05;
    pushPolicyMorale(exileMorale, 3.0);
    if (v.surname.isNotEmpty) _houses.nudge(v.surname, moodDelta: -0.05);
    final ctx = _voice(v, seed: _stableSeed('exile${v.name}', _dayCount));
    // Sürgün = ölüm çöküşü DEĞİL (metin "yolun başına yürütüldü" der). Aile bağı
    // kopar, sonra köylü en yakın harita KENARINA yürür; varınca scene_tick onu
    // listeden çıkarır (leftVillage). Ölüm hattından (startDying) ayrı.
    for (final p in v.parents) {
      p.children.remove(v);
    }
    for (final c in v.children) {
      c.parents.remove(v);
    }
    final toL = v.gridX, toR = kCols - v.gridX;
    final toT = v.gridY, toB = kRows - v.gridY;
    final m = min(min(toL, toR), min(toT, toB));
    double ex = v.gridX, ey = v.gridY;
    if (m == toL) {
      ex = 0.5;
    } else if (m == toR) {
      ex = kCols - 0.5;
    } else if (m == toT) {
      ey = 0.5;
    } else {
      ey = kRows - 0.5;
    }
    v.startLeaving(ex, ey);
    _chronicle(
        Voice.say(
            wasFeud ? _kExileFeudChroniclePool : _kExileChroniclePool, ctx),
        icon: '🚷', milestone: wasFeud);
    _showNotification(Voice.say(_kExilePool, ctx));
  }

  /// İDAM — oyuncunun en sert yetkisi. 2B sahnede halk toplanır, mahkûm yere
  /// çöker (gerçek ölüm + mezar); kan davası kanla kapanır. Köyü DEHŞET sarar
  /// (korku gövde dili + kırmızı flaş + ağır moral). "Gerekiyorsa" son çare.
  void _executeVillager(VillagerEntity v) {
    final wasFeud = v.inFeud;
    if (wasFeud) _pacifyFeudOf(v); // adalet kan borcunu kapatır → döngü durur

    // Halk toplanır — infaz tanığı (diz çökmüş saygı/dehşet duruşu).
    final dur = kGameDaySeconds * 0.5;
    _gatherAtFire(dur, max: 8, pose: FirePose.kneel);
    _activeFx.add(ActiveFx(
        const EventEffect(screenTint: Color(0x55AA1414), duration: 2.2), 2.2));

    // Mahkûmu infaz et — aile bağı kopar, görünür çöküş + mezar.
    for (final p in v.parents) {
      p.children.remove(v);
    }
    for (final c in v.children) {
      c.parents.remove(v);
    }
    v.startDying(funeral: true);

    // Köyü dehşet sarar — korku gövde dili + güçlü sarsıntı + ağır moral.
    _feelVillage(NpcEmotion.fear, 14, -0.20);
    pushPolicyMorale(-0.15, 6.0);
    addCameraShake(10.0, dur: 0.9);
    // İnfaz otoritesi sevilmez — Köklü Yuva (aile) ürker.
    _nudgeHousesByEstate(Estate.hearth, moodDelta: -0.08);

    final ctx = _voice(v, seed: _stableSeed('idam${v.name}', _dayCount));
    _chronicle(
        Voice.say(
            wasFeud ? _kExecuteFeudChroniclePool : _kExecuteChroniclePool, ctx),
        icon: '⚖️', milestone: true);
    _showNotification(Voice.say(_kExecutePool, ctx));
  }

  /// DEBUG (DevPanel): iki ayrı aileden köylü seçip ölümcül bir kavga +
  /// kan davası başlatır (test için garantili).
  bool _devIgniteFeud() {
    final pool = _villagers
        .where((v) => !v.isDying && v.hasProfession && !v.isFavorite)
        .toList();
    if (pool.length < 2) return false;
    pool.shuffle(_rng);
    final a = pool.first;
    final kin = _bloodKin(a);
    final b = pool.firstWhere(
        (v) => !identical(v, a) && !kin.contains(v),
        orElse: () => pool[1]);
    return _resolveFatalBrawl(a, b, false);
  }
}
