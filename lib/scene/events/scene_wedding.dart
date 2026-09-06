part of '../main.dart';

/// Düğün — "olay = dünyada yaşayan yaşam döngüsü" iskeletinin ilk dikey dilimi.
/// Soyut bir eşik-dilekçesi (adults≥4) değil; GERÇEK bir çiftin hikâyesi:
///
///   1. Mayalanma (kur)  — aynı evde yaşayan, kan bağı olmayan, henüz evlenmemiş
///      bir çift seçilir; günlerce görünür biçimde kur yapar (bakışma/dans/kalp).
///   2. Herald + Karar    — kur olgunlaşınca düğün dilekçesi BU çifte bağlı sunulur
///      (yazar = gelin, modal'da gerçek köylü). Coşkulu mu sade mi? (scene_petitions)
///   3. Sahnede çözüm     — coşkuluysa önce gerçek çifte benzeyen tam ekran 2B
///      sinematik (yeminler), ardından dünya-içi alay: çift ateşin onur konuğu,
///      köy çevrede halaya durur. Sadeyse sinematik yok, yalnız dünya-içi alay.
///   4. Vakanüvis         — "X & Y evlendi" kalıcı güncede (📖 Hikâye).
///
/// Diğer olaylar bu deseni izleyecek (Faz 2+). Reaktif primitifler — _gatherAtFire,
/// _tryStartDanceFor, _chronicle, weddingCutscene — paylaşılır.
extension _SceneWedding on _VillageSceneState {
  /// Kur taraması/jest throttle'ı (sn) — cozy, yavaş.
  static const double _kWeddingScan = 6.0;
  /// Kur olgunlaşma süresi (oyun günü) — bu kadar görünür kur sonrası dilekçe.
  static const double _kCourtshipDays = 0.8;
  /// Kur eşleşmesinde yaş-yakınlığı YUMUŞAK eğilimi: aday ağırlığı yaş farkıyla
  /// exp(-fark/ölçek) sönimler. Ölçek büyükse eğilim zayıf. Yetişkinlik bracket'i
  /// ~9.5 gün → 3.0 ölçek "yakın çift olası, uç fark nadir ama mümkün" verir.
  /// (Sert sınır DEĞİL — kullanıcı kararı: yumuşak eğilim.)
  static const double _kCourtshipAgeScale = 3.0;

  // ── Sevdanın sesi ([[lib/text/voice.dart]]) ───────────────────────────────

  static const _kCourtshipPool = [
    '💞 {ad} bugün {öteki-e} iki kez fazladan baktı.',
    '💞 {ad} ile {öteki} işini artık hep yan yana tutuyor.',
    '💞 Akşam ateşinde {ad} kendine {öteki-in} yanında yer ayırdı.',
  ];
  static const _kCourtshipChroniclePool = [
    '{ad} ile {öteki} birbirine gönül verdi',
    '{ad-in} gönlü {öteki-e} düştü',
    '{ad} ile {öteki} artık hep yan yana',
  ];
  static const _kBetrothalPool = [
    '💍 {ad} ile {öteki} evlenmek istiyor. Köy bir düğün bekliyor.',
    '💍 Söz kesildi: {ad} ile {öteki}. Gerisi köyün kararı.',
    '💍 {ad} ile {öteki} el ele meclisin önünde duruyor, izin istiyorlar.',
  ];
  static const _kWedChroniclePool = [
    '{ad} ile {öteki} evlendi',
    '{ad} ile {öteki} bir ocak kurdu',
    '{ad-in} nikâhı {öteki-le} kıyıldı',
  ];
  static const _kWedLifePool = [
    '{öteki} ile evlendi',
    '{öteki-le} nikâh kıydı',
    '{öteki} ile bir ocak kurdu',
  ];

  void _tickWedding(double dt) {
    if (!_hasFire || _villagers.length < 2) return;

    // Masadaki düğün dilekçesi ÇİFTE BAĞLI — çift dağıldıysa dilekçe konusuz
    // kalır. Bu denetim aşağıdaki erken `return`'lerin ÜSTÜNDE durmalı: gündem
    // doluyken hiçbir doğrulama koşmuyordu, yani gelin kaçırıldıktan sonra bile
    // "Kutla" sahnede olmayan birini evlendiriyor ve alay ateşte bir oturma
    // slotu claim ediyordu. Köylü listede olmadığı için `update()` hiç koşmaz →
    // `_releaseSit` hiç tetiklenmez → o slot KALICI ölü (ateş başında bir yer
    // sonsuza dek eksilir).
    if (_pendingPetition?.id == 'villageWedding') {
      final c = _weddingCouple;
      if (c == null || !_coupleStillPresent(c.$1, c.$2)) _withdrawWedding();
      return;
    }
    // Düğün dilekçesi başka bir ağır kararın arkasında merkezi kuyrukta da
    // bekleyebilir. O sırada aynı çifti ezme veya ikinci bir kur başlatma.
    if (_pacedPetitions.any((p) => p.petition.id == 'villageWedding')) return;

    // Gündem doluysa (dilekçe bekliyor / sinematik oynuyor) kur ilerlemesin.
    if (_pendingPetition != null || _activeCutscene != null) return;

    // Nişanlı çift olgunlaşıyor mu?
    final bride = _brideElect, groom = _groomElect;
    if (bride != null && groom != null) {
      if (!_coupleStillValid(bride, groom)) {
        _abortWedding();
        return;
      }
      _courtshipTimer -= dt;
      if (_courtshipTimer <= 0) {
        _armWedding(bride, groom);
        return;
      }
    }

    _weddingScan -= dt;
    if (_weddingScan > 0) return;
    _weddingScan = _kWeddingScan;

    // Nişanlı çift varsa görünür kur jesti (throttled) — yeni çift arama.
    if (_brideElect != null && _groomElect != null) {
      _courtStep(_brideElect!, _groomElect!);
      return;
    }

    // Yakında düğün oldu/reddedildiyse cooldown'da bekle (üst üste düğün olmasın).
    final cd = _petitionCooldowns['villageWedding'];
    if (cd != null && cd > _time) return;

    final couple = _findCourtship();
    if (couple == null) return;
    final (w, m) = couple;
    _brideElect = w;
    _groomElect = m;
    _courtshipTimer = _kCourtshipDays * kGameDaySeconds;
    w.feel(NpcEmotion.love, 3.0, moodDelta: 0.04);
    m.feel(NpcEmotion.love, 3.0, moodDelta: 0.04);
    final ctx = _voice(w,
        other: m, seed: _stableSeed('kur${w.name}${m.name}', _dayCount));
    _chronicle(Voice.say(_kCourtshipChroniclePool, ctx), icon: '💞');
    _showNotification(Voice.say(_kCourtshipPool, ctx));
  }

  /// Aynı evde yaşayan, karşı cins, kan bağı olmayan, henüz evlenmemiş iki
  /// yetişkin — (kadın, erkek). Yoksa null. _tickFamilyReunion index desenini izler.
  (VillagerEntity, VillagerEntity)? _findCourtship() {
    final byHome = <Object, List<VillagerEntity>>{};
    for (final v in _villagers) {
      if (v.lifeStage != LifeStage.adult || v.isDying || v.wed) continue;
      // KOPMUŞ HANE KIZ/OĞUL VERMEZ — hane esirgemenin son basamağında köyle
      // akrabalık da kurmaz (bkz. scene_house_stance). Kur hiç başlamaz;
      // hane razı olunca aday havuzuna kendiliğinden döner.
      if (_houseRefusesBetrothal(v)) continue;
      final h = v.homeBuilding;
      if (h == null) continue;
      (byHome[h] ??= []).add(v);
    }
    // Geçerli tüm (kadın, erkek) adaylarını topla; yaş-yakınlığına YUMUŞAK ağırlık
    // ver. Eskiden ilk geçerli çift dönüyordu (yaş körü) → taze yetişkin bir
    // neredeyse-yaşlıyla eşit olasılıkla eşleşebiliyordu. Artık yakın yaş daha
    // olası, uç fark seyrek (sert sınır yok).
    final cands = <(VillagerEntity, VillagerEntity)>[];
    final weights = <double>[];
    for (final mates in byHome.values) {
      if (mates.length < 2) continue;
      for (final w in mates) {
        if (w.isMale) continue;
        for (final m in mates) {
          if (!m.isMale) continue;
          if (w.parents.contains(m) || w.children.contains(m)) continue;
          if (m.parents.contains(w) || m.children.contains(w)) continue;
          if (w.parents.any(m.parents.toSet().contains)) continue; // kardeş
          cands.add((w, m));
          final gap = (w.ageDays - m.ageDays).abs();
          weights.add(exp(-gap / _kCourtshipAgeScale));
        }
      }
    }
    if (cands.isEmpty) return null;
    // Ağırlıklı çekiliş — yaşça yakın çift daha olası.
    var total = 0.0;
    for (final wgt in weights) {
      total += wgt;
    }
    var r = _rng.nextDouble() * total;
    for (var i = 0; i < cands.length; i++) {
      r -= weights[i];
      if (r <= 0) return cands[i];
    }
    return cands.last;
  }

  /// Nişanlı çift hâlâ geçerli mi (ikisi de hayatta, evlenmemiş, aynı evde yetişkin).
  bool _coupleStillValid(VillagerEntity a, VillagerEntity b) {
    if (a.isDying || b.isDying || a.wed || b.wed) return false;
    if (a.lifeStage != LifeStage.adult || b.lifeStage != LifeStage.adult) {
      return false;
    }
    // Siyasi nikâh (zorlama) haneler ARASIDIR — aynı ev şartı yalnız organik
    // kur için geçerli, yoksa bağlanan çift anında geçersiz sayılırdı.
    if (!_betrothalForced &&
        (a.homeBuilding == null || a.homeBuilding != b.homeBuilding)) {
      return false;
    }
    if (!_villagers.contains(a) || !_villagers.contains(b)) return false;
    return true;
  }

  /// Masadaki düğünün çifti HÂLÂ SAHNEDE Mİ — dar varlık denetimi.
  ///
  /// [_coupleStillValid] bilerek kullanılmaz: o KUR koşullarını da sorar (aynı
  /// hane) ve `_armWedding` `_betrothalForced`'ı sıfırladığı için siyasi nikâhın
  /// çifti -farklı hanelerden- dilekçe masaya konar konmaz "geçersiz" sayılırdı.
  /// Dilekçe armlandıktan sonra tek soru şudur: bu iki insan hâlâ burada mı.
  bool _coupleStillPresent(VillagerEntity a, VillagerEntity b) =>
      !a.isDying &&
      !b.isDying &&
      !a.wed &&
      !b.wed &&
      _villagers.contains(a) &&
      _villagers.contains(b);

  /// Konusu kalmayan düğün dilekçesini masadan kaldır (gelin/damat öldü,
  /// kaçırıldı ya da devşirildi). Kimsenin suçu değil → huzursuzluk/moral
  /// cezası YOK; yalnız köy sessizce haberi alır.
  void _withdrawWedding() {
    final p = _pendingPetition;
    _weddingCouple = null;
    _brideElect = null;
    _groomElect = null;
    _courtshipTimer = 0;
    _betrothalForced = false;
    if (p == null) return;
    setStateHere(() {
      _petitionCooldowns[p.id] = _time + 2.0 * kGameDaySeconds;
      _pendingPetition = null;
      _petitionAuthor = null;
      _petitionExtra = const {};
      _petitionModalOpen = false;
      _petitionOverdue = false;
      _petitionOverdueTimer = 0;
      _petitionTimer = _petitionInterval();
    });
    _showNotification('💔 Düğün dağıldı. Masadaki dilekçenin artık sahibi yok.');
    _chronicle('Beklenen nikâh kıyılamadı. Çiftten geriye söz kaldı.',
        icon: '💔');
  }

  /// Görünür kur jesti (throttle'lı, abartısız): bakışma + kalp + ara sıra dans.
  void _courtStep(VillagerEntity a, VillagerEntity b) {
    for (final v in [a, b]) {
      if (v.isSleeping || v.isInsideBuilding || v.isCarrying || v.isDying) {
        return;
      }
    }
    if (_rng.nextDouble() < 0.5) return; // her taramada değil — seyrek
    a.lookToward(b.gridX, b.gridY);
    b.lookToward(a.gridX, a.gridY);
    a.feel(NpcEmotion.love, 2.5, moodDelta: 0.02);
    b.feel(NpcEmotion.love, 2.5, moodDelta: 0.02);
    final dx = a.gridX - b.gridX, dy = a.gridY - b.gridY;
    if (dx * dx + dy * dy <= 2.5 * 2.5 &&
        a.activity == VillagerActivity.none &&
        b.activity == VillagerActivity.none &&
        a.socialCooldown <= 0 &&
        b.socialCooldown <= 0) {
      _tryStartDanceFor(a); // a yakındaki b ile eşleşir
    }
  }

  /// Nişan bozulur (biri öldü/ayrıldı/koşul düştü) — sessizce sıfırla.
  void _abortWedding() {
    _brideElect = null;
    _groomElect = null;
    _courtshipTimer = 0;
    _betrothalForced = false;
  }

  /// Kur olgunlaştı → düğün dilekçesini ÇİFTE BAĞLI sun. Yazar = gelin (modal'da
  /// gerçek, tıklanabilir köylü). Herald: çift ateşe doğru döner (diegetik).
  void _armWedding(VillagerEntity bride, VillagerEntity groom) {
    _brideElect = null;
    _groomElect = null;
    _courtshipTimer = 0;
    _betrothalForced = false; // bayrak SIZMASIN: sonraki kur organik olmalı
    final p = PetitionSystem.byId('villageWedding');
    if (p == null) return;
    _weddingCouple = (bride, groom);
    _presentPetition(p, author: bride);
    // Herald — çift köy merkezine (ateşe) döner, içleri sevgiyle dolar.
    final (cc, cr) = _villageCenter();
    for (final v in [bride, groom]) {
      if (v.isSleeping || v.isInsideBuilding || v.isDying) continue;
      v.lookToward(cc.toDouble(), cr.toDouble());
      v.feel(NpcEmotion.love, 3.0, moodDelta: 0.03);
    }
    _showNotification(Voice.say(
        _kBetrothalPool,
        _voice(bride,
            other: groom,
            seed: _stableSeed('nişan${bride.name}${groom.name}', _dayCount))));
  }

  /// Dilekçe çözüldü → düğünü dünyada SAHNELE. [grand] coşkulu (sinematik + büyük
  /// alay) / sade (yalnız dünya-içi alay). `_resolvePetition`'ın setState'i içinde
  /// çağrılır → alanlar doğrudan mutate edilir (festival/vigil deseni gibi).
  void _reactWedding({required bool grand}) {
    final couple = _weddingCouple;
    _weddingCouple = null;
    _brideElect = null;
    _groomElect = null;
    _courtshipTimer = 0;
    _betrothalForced = false;

    const dur = kGameDaySeconds * 0.5;
    AudioManager.instance.playSfx(Sfx.crowdApplause);
    _activeFx.add(ActiveFx(const EventEffect(fx: EventFx.wedding, duration: dur), dur));
    _feelVillage(NpcEmotion.love, 14, grand ? 0.18 : 0.12);

    VillagerEntity? bride, groom;
    // SON KAPI: çift hâlâ sahnede mi. `_tickWedding` konusuz dilekçeyi zaten
    // kaldırıyor, ama karar ile bu çağrı arasında da köylü sahneden çıkabilir
    // (aynı karede kaçırılma/ölüm). Doğrulanmadan geçilirse alay ateşte bir
    // oturma slotu claim eder ve o slot bir daha serbest kalmaz — sessiz,
    // kalıcı, geri alınamaz. Çift düştüyse kutlama jenerik sürer.
    if (couple != null && _coupleStillPresent(couple.$1, couple.$2)) {
      bride = couple.$1;
      groom = couple.$2;
      bride.wed = true;
      groom.wed = true;
      final seed = _stableSeed('düğün${bride.name}${groom.name}', _dayCount);
      final ctx = _voice(bride, other: groom, seed: seed);
      _chronicle(Voice.say(_kWedChroniclePool, ctx), icon: '💍');
      _award('first_wedding', 'Köyün ilk düğünü kutlandı', '💍');
      _lifeEvent(bride, Voice.say(_kWedLifePool, ctx), icon: '💍',
          milestone: true);
      _lifeEvent(
          groom, Voice.say(_kWedLifePool, _voice(groom, other: bride, seed: seed)),
          icon: '💍', milestone: true);
    }

    // Eskiden coşkulu düğün tam ekran 2B sinematikle açılırdı. Kaldırıldı:
    // düğün koşu boyunca TEKRARLAYAN bir olay, dolayısıyla aynı kompozisyon
    // her seferinde "Atla" tuşuna dönüşüyordu. Kutlama artık yalnız dünyada
    // yaşanır — alay aşağıda kurulur; coşkuluysa üstüne şenlik FX'i biner.
    if (grand && bride != null && groom != null) {
      _reactFestival();
      addCameraShake(2.0, dur: 0.4);
    }

    _stageWeddingProcession(bride, groom, dur, grand: grand);
  }

  /// Dünya-içi alay: gelin & damat ateşin onur konuğu (yan yana, kalp baloncuğu),
  /// köy çevrede toplanır, birkaç çift halaya durur.
  void _stageWeddingProcession(
      VillagerEntity? bride, VillagerEntity? groom, double dur,
      {required bool grand}) {
    final fire = _firepitBuilding;
    if (fire == null) return;

    // Onur konukları — ateşe taşınır (sit), kalpli baloncuk + sevinç.
    for (final v in [bride, groom]) {
      if (v == null || v.isSleeping || v.isDying) continue;
      final claim =
          _anchorSystem.claimNearestFirepitSit(v.gridX, v.gridY, v, maxDist: 999);
      if (claim != null) {
        final (point, slot) = claim;
        final cx = point.building.col + point.building.cols / 2.0;
        final cy = point.building.row + point.building.rows / 2.0;
        v.assignSit(
            slot.col, slot.row, cx, cy, dur, () => point.release(slot, v));
      }
      v.feel(NpcEmotion.love, dur, moodDelta: 0.10);
    }

    // Köy çevrede toplanır (onur konukları slotları aldı → gerisi kalanları).
    _gatherAtFire(dur, max: grand ? 8 : 5);

    // Birkaç çift halaya dursun (coşkuluda daha çok).
    final idle = _villagers
        .where((v) =>
            !v.isInsideBuilding &&
            !v.isSleeping &&
            v.hasProfession &&
            !v.isCarrying &&
            !v.sitClaimed &&
            !v.isDying &&
            v.activity == VillagerActivity.none)
        .toList()
      ..shuffle(_rng);
    int danced = 0;
    final maxDance = grand ? 4 : 2;
    for (final v in idle) {
      if (danced >= maxDance) break;
      if (_tryStartDanceFor(v)) {
        v.socialCooldown = dur;
        danced++;
      }
    }
  }
}
