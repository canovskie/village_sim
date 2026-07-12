part of '../main.dart';

/// Zümre / Hizip katmanı — yönetişimin kalbi. Dilekçe (ve ileride ferman)
/// kararları zümrelerin moralini + nüfuzunu oynatır; köy yavaşça bir kimliğe
/// kayar. Geri bildirim HİBRİT: belediye panelinde sade "Zümre Nabzı" özeti +
/// diegetik ipuçları (sözcü sahneye gelir, küskün zümre köyde somurtur).
///
/// KISIT (bkz. feedback_event_animation): tüm ifade gövde dili → [feel];
/// baş üstü emoji / floating ikon YOK. Cozy: küskünlük cezalandırmaz, görünür kılar.
extension _SceneEstates on _VillageSceneState {
  /// Küskün zümre somurtma taraması — bu aralıkla (sn) bir üye gövde refleksi.
  static const double _kAggrievedScan = 5.0;

  /// Pozitif moral etkisinin nüfuza dönüşüm katsayısı: sevindirdiğin zümre
  /// köyde o oranda ağırlık kazanır (köy o yöne kayar). Küstürmek nüfuz almaz.
  static const double _kSwayFromMood = 1.0;

  // ── Kimlik mekanik bonusu ──────────────────────────────────────────────────
  // Baskın zümre (köy kimliği) yalnızca dekor değil, SOMUT bir avantaj getirir.
  // Cozy: hepsi pozitif, küçük ama hissedilir; köyü bir yöne adamanın ödülü.
  //   🌾 Bereketli Köy  → tarlalar daha gürbüz büyür      (_fxFarmMul'a katılır)
  //   🔨 Zanaat Kasabası → her balyadan daha çok ürün çıkar (bale verimi)
  //   🏡 Köklü Yuva      → tutumlu sofra, daha az tüketim   (mouths çarpanı)
  //   🕯️ Kutsal Köy     → köye sinen huzur, moral tabanı yükselir

  /// Tarla büyüme bonusu — Bereketli Köy ise tarlalar %15 hızlı olgunlaşır.
  double get _identityFarmMul =>
      _identityEstate == Estate.laborers ? 1.15 : 1.0;

  /// Balya→ürün verim bonusu — Zanaat Kasabası ise her balya %15 fazla verir.
  double get _identityYieldMul =>
      _identityEstate == Estate.artisans ? 1.15 : 1.0;

  /// Yiyecek tüketim çarpanı — Köklü Yuva ise köy %15 daha tutumlu (0.85).
  double get _identityFoodMul =>
      _identityEstate == Estate.hearth ? 0.85 : 1.0;

  /// Bireysel moral hedefine eklenen kutsama — Kutsal Köy ise herkese huzur.
  double get _identityMoraleBonus =>
      _identityEstate == Estate.faithful ? 0.06 : 0.0;


  /// Mevsim dönümü — köyde diegetik bir an + Emekçi zümre tepkisi. Tarım
  /// Emekçilerin sesi olduğundan mevsim onların moralini/nüfuzunu oynatır:
  /// sonbahar bereketi yükseltir, kış kıtlığı huzursuz eder.
  void _onSeasonTurn(Season to) {
    switch (to) {
      case Season.spring:
        _showNotification('🌱 İlkbahar geldi — tarlalar uyanıyor, ekim vakti.');
        _chronicle('İlkbahar: tarlalar yeniden yeşeriyor.', icon: '🌱');
        _nudgeHousesByEstate(Estate.laborers, moodDelta: 0.04, swayGain: 0.02);

      case Season.summer:
        _showNotification('☀️ Yaz bastırdı — ekinler susadı, kuyular hayati.');
        _chronicle('Yaz: güneş yükseldi, sulama olmadan ekin kavrulur.',
            icon: '☀️');

      case Season.autumn:
        _showNotification('🍂 Sonbahar — hasat bereketi başladı, ambarlar dolacak!');
        _chronicle('Sonbahar: bereketli hasat mevsimi.', icon: '🍂');
        // Emekçilerin mevsimi — moral + nüfuz yükselir, köy kısa süre sevinir.
        _nudgeHousesByEstate(Estate.laborers, moodDelta: 0.06, swayGain: 0.06);
        pushPolicyMorale(0.04, 2.0);

      case Season.winter:
        // Kış kıtlık sınavı — ambar zayıfsa Emekçiler huzursuz, doluysa huzurlu.
        final mouths = _villagers.length + _farmers.length;
        final lean = _stockpile.food < mouths * 3;
        if (lean) {
          _showNotification('❄️ Kış bastırdı — tarlalar dondu, ambar dar.');
          _chronicle('Kış: tarlalar dondu, kışlık erzak kaygısı.', icon: '❄️');
          _nudgeHousesByEstate(Estate.laborers, moodDelta: -0.05);
        } else {
          _showNotification('❄️ Kış bastırdı — tarlalar dondu ama ambar dolu.');
          _chronicle('Kış: tarlalar uykuda, ambar dolu, köy huzurlu.',
              icon: '❄️');
          _nudgeHousesByEstate(Estate.laborers, moodDelta: 0.02);
        }
    }
  }

  void _tickEstates(double dt) {
    // Önce bireysel moralleri güncelle → zümrelere üye-morali beslensin.
    _tickVillagerMorale(dt);
    // Hane moralleri üye moraline süzülür — kararlar günlerce yankılanır.
    _houses.tick(dt, kGameDaySeconds);

    // ── Sürü sağlığı → Emekçi zümre morali ──────────────────────────────────
    // Doğum sevinç verir, ölüm hüzünlendirir (chill: küçük dokunuşlar). Ayrıca
    // sürü açsa moral yavaşça düşer — bakımsız ahır Emekçileri huzursuz eder.
    if (_animalBirthsPending > 0) {
      _nudgeHousesByEstate(Estate.laborers,
          moodDelta: 0.02 * _animalBirthsPending);
      _animalBirthsPending = 0;
    }
    if (_animalDeathsPending > 0) {
      _nudgeHousesByEstate(Estate.laborers,
          moodDelta: -0.015 * _animalDeathsPending);
      _animalDeathsPending = 0;
    }
    if (_cows.isNotEmpty) {
      var hungrySum = 0.0;
      for (final c in _cows) {
        if (!c.isDying) hungrySum += c.hunger;
      }
      final avgHunger = hungrySum / _cows.length;
      // avgHunger 0..1; tok sürü hafif +, aç sürü hafif − (günlük tempoda).
      final delta = (0.25 - avgHunger) * 0.04 * (dt / kGameDaySeconds);
      _nudgeHousesByEstate(Estate.laborers, moodDelta: delta);
    }

    // Kimlik kayması — baskın HANE değişince köy görünür bir ana kayar (köy
    // artık bir hanenin gölgesinde). Kimlik = prestij + köyün kısa sevinci +
    // artık SOMUT mekanik bonus (baskın hanenin baskın hizbinden türer).
    final asc = _houses.pollAscendantChange();
    if (asc.changed) {
      _updateVillageIdentity(); // bonus anında yeni kimliğe geçsin
      if (asc.current != null) {
        _showNotification('👑 Köy bir haneye kayıyor: ${asc.current} Hanesi.');
        _chronicle('Köy ${asc.current} Hanesi\'nin gölgesine kaydı.',
            icon: '👑');
        pushPolicyMorale(0.05, 2.0); // köyün kısa sevinci
      } else {
        _showNotification('⚖️ Köyün baskın hanesi çözüldü — denge geri döndü.');
        _chronicle('Köy dengeye döndü — baskın hane çözüldü.', icon: '⚖️');
      }
    }

    // Diegetik: en küskün zümrenin bir üyesi ara sıra somurtsun (gövde dili).
    _estateMoodScan += dt;
    if (_estateMoodScan < _kAggrievedScan) return;
    _estateMoodScan = 0;
    _updateVillageIdentity(); // hane bileşimi zamanla kayabilir → tazele
    _showAggrievedPosture();
  }

  /// Köy kimliğini ([_identityEstate]) baskın hanenin baskın hizbinden türetir →
  /// kimlik mekanik bonusları (_identityFarmMul / _identityYieldMul /
  /// _identityFoodMul / _identityMoraleBonus) bu hizbe göre devreye girer. Baskın
  /// hane yoksa null (nötr — "Dengeli Köy"). Zümre→Hane geçişinde kopan "son tel":
  /// önceden hiç atanmadığından bonuslar kalıcı nötrdü; artık canlı.
  void _updateVillageIdentity() {
    final asc = _houses.ascendant;
    _identityEstate = asc == null ? null : _dominantEstateOfHouse(asc);
  }


  /// Zümre-etiketli bir olay/karar etkisini HANELERE dağıtır: her hane,
  /// üyelerinin o mesleğe (zümreye) yaslandığı oranda etkilenir. `Estate` artık
  /// yalnız meslek-sınıflandırması; politik birim HANE. Nadir çağrılır (olaylar)
  /// → her villager taraması ucuz.
  void _nudgeHousesByEstate(Estate e,
      {double moodDelta = 0, double swayGain = 0}) {
    if (moodDelta == 0 && swayGain == 0) return;
    final lean = <String, int>{};
    final total = <String, int>{};
    for (final v in _villagers) {
      if (v.isDying || v.surname.isEmpty) continue;
      total[v.surname] = (total[v.surname] ?? 0) + 1;
      if (estateOfVillager(v.type, v.lifeStage) == e) {
        lean[v.surname] = (lean[v.surname] ?? 0) + 1;
      }
    }
    for (final entry in total.entries) {
      final frac = (lean[entry.key] ?? 0) / entry.value;
      if (frac <= 0) continue;
      _houses.nudge(entry.key,
          moodDelta: moodDelta * frac, swayGain: swayGain * frac);
    }
  }

  /// Bir hanenin baskın meslek-zümresi (üye çoğunluğu) — estate-etiketli
  /// grievance dilekçelerini "hangi hane küskün"e göre ateşlemek için köprü.
  Estate? _dominantEstateOfHouse(String surname) {
    final tally = <Estate, int>{};
    for (final v in _villagers) {
      if (v.isDying || v.surname != surname) continue;
      final e = estateOfVillager(v.type, v.lifeStage);
      tally[e] = (tally[e] ?? 0) + 1;
    }
    Estate? best;
    var bestN = 0;
    for (final entry in tally.entries) {
      if (entry.value > bestN) {
        bestN = entry.value;
        best = entry.key;
      }
    }
    return best;
  }

  /// Bir dilekçe kararının POLİTİK etkisi — option'ın authored zümre etkileri
  /// artık HANELERE (üye-yaslanma oranıyla) dağıtılır. Gündeme gelmek de ilgili
  /// hanelere ufak nüfuz kazandırır.
  void _applyEstatePetition(Petition p, PetitionOption o) {
    for (final (e, delta) in o.estateMood) {
      _nudgeHousesByEstate(e,
          moodDelta: delta, swayGain: delta > 0 ? delta * _kSwayFromMood : 0);
    }
    final pe = p.estate;
    if (pe != null) _nudgeHousesByEstate(pe, swayGain: 0.05);
  }

  // ── Bireysel moral döngüsü ─────────────────────────────────────────────────
  /// Her tick: koşullardan her köylünün moral hedefini hesaplar, oraya yavaş
  /// süzer (kalıcı), zümrelere üye-ortalamasını besler, köy ortalamasını
  /// (`_avgIndividualMorale`) günceller ve kronik mutsuzları göç ettirir.
  /// Cozy: değerler ölçülü, göç nadir + telegraflı + godMode'da kapalı.
  void _tickVillagerMorale(double dt) {
    if (_villagers.isEmpty) {
      _avgIndividualMorale = 0.6;
      return;
    }
    // Köy-geneli koşullar (bir kez).
    final starving = _wasStarving;
    final lowWater = _buildings.any((b) =>
        b.fn?.role == BuildingRole.housing &&
        b.occupants > 0 &&
        b.waterLevel < 0.3);
    final coldNight = _cycle.dayLight < 0.28 && !_hasFire;
    final elderPolicy = _policies.eldersExemptFromFood || _policies.peacefulEnd;

    // Kültür mahallesi amenitesi: köyde kaç FARKLI kültür binası var
    // (kütüphane/hamam/okul/anıt/şadırvan) — çeşitlilik morali besler.
    const cultureTypes = {
      BuildingType.library,
      BuildingType.bathhouse,
      BuildingType.monument,
      BuildingType.fountain,
      BuildingType.shrine,
      BuildingType.belltower,
    };
    final cultureAmenities = cultureTypes
        .where((t) => _buildings.any((b) => b.type == t))
        .length;

    // Hedefe süzme (tau ~0.5 oyun günü) — moral kalıcı, ani zıplamaz.
    final lerp = (dt / (0.5 * kGameDaySeconds)).clamp(0.0, 0.25);

    // Haneler: soyad → moral toplamı + üye sayısı (hane mood'unu besler).
    final houseSum = <String, double>{};
    final houseCnt = <String, int>{};
    double sum = 0;

    // Servet birikimi bu tick'te kaç günlük ilerledi (frame-bağımsız).
    final dayFrac = dt / kGameDaySeconds;

    for (final v in _villagers) {
      if (v.isDying) {
        sum += v.morale;
        continue;
      }
      final homeType = v.homeBuilding == null
          ? null
          : (v.homeBuilding as BuildingEntity).type;
      final homeless = homeType == null;
      // Çadırda yaşıyor: evi var ama derme çatma → hafif hoşnutsuzluk.
      final poorHousing = homeType == BuildingType.tent;
      // Taş konut: Köy Evi'nden konforlu → hafif moral bonusu.
      final comfortHousing = homeType == BuildingType.stoneHouseBlue ||
          homeType == BuildingType.stoneHouseGreen;
      // Konak: en lüks yuva → güçlü moral bonusu.
      final luxuryHousing = homeType == BuildingType.manor;

      // ── Servet: çalışan yetişkinler mesleklerine göre kazanır ──────────────
      // Moral üretkenliği, ev kademesi refahı çarpar; küçük yaşam gideri servete
      // bir asimptot koyar (sınırsız büyümez). Mesleksiz/çocuk kazanmaz; gider
      // yine de işlediğinden servetleri zamanla erir.
      if (dayFrac > 0) {
        if (v.hasProfession) {
          final moraleFactor = 0.6 + v.morale * 0.8; // 0.6..1.4
          final houseMul = luxuryHousing
              ? 1.5
              : comfortHousing
                  ? 1.2
                  : poorHousing
                      ? 0.85
                      : homeless
                          ? 0.7
                          : 1.0;
          v.wealth += v.type.wealthDailyIncome * moraleFactor * houseMul * dayFrac;
        }
        // Yaşam gideri — servetin %5'i/gün geri erir (asimptot + mesleksiz düşüş).
        v.wealth -= v.wealth * 0.05 * dayFrac;
        if (v.wealth < 0) v.wealth = 0;
      }

      final ev = evaluateVillagerMorale(
        homeless: homeless,
        poorHousing: poorHousing,
        comfortHousing: comfortHousing,
        luxuryHousing: luxuryHousing,
        starving: starving,
        lowWater: lowWater,
        cold: coldNight && !v.isSleeping,
        houseMood: _houses.moodOf(v.surname),
        elderRespected: elderPolicy && v.lifeStage == LifeStage.elder,
        // Çağrısını bulmuş ama mesleği ona uymuyor → kalıcı kırgınlık.
        callingMismatch: v.callingFound && v.type != v.calling,
        // Bir kan davasının tarafı → sürekli gerilim.
        feudMember: v.inFeud,
        // Kavgada akut yaralı → ağrı/iş göremezlik.
        injured: v.injuryDays > 0,
        // Meydan/kültür mahallesi binaları → "yaşanası köy" morali.
        cultureAmenities: cultureAmenities,
      );
      // Kimlik bonusu: Kutsal Köy ise herkesin moral hedefi biraz yükselir.
      final target = (ev.target + _identityMoraleBonus).clamp(0.0, 1.0);
      v.morale = (v.morale + (target - v.morale) * lerp).clamp(0.0, 1.0);
      v.moraleReason = ev.reason;
      sum += v.morale;
      if (v.surname.isNotEmpty) {
        houseSum[v.surname] = (houseSum[v.surname] ?? 0) + v.morale;
        houseCnt[v.surname] = (houseCnt[v.surname] ?? 0) + 1;
      }
    }
    _avgIndividualMorale = sum / _villagers.length;

    // Haneleri besle: soyadlardan üye sayısı + ortalama moral (tick'te
    // hane mood'u buna gravite eder). Tükenmiş haneleri budar.
    _houses.rebuild(houseCnt, houseSum);

    // Göç: uzun süre perişan kalan köylü köyü terk eder. Son birkaç köylü
    // korunur; godMode/showcase'te kapalı. Tek seferde bir kişi.
    if (!_godMode && _villagers.length > 3) {
      for (final v in _villagers) {
        if (!v.isDying && v.lowMoraleTime > 2.2 * kGameDaySeconds) {
          _emigrateVillager(v);
          break;
        }
      }
    }
  }

  /// Kronik mutsuz köylü köyü terk eder — diegetik kayıp (bildirim + hane yası).
  void _emigrateVillager(VillagerEntity v) {
    _showNotification('${v.name} köyü terk etti — uzun süre mutsuzdu');
    if (v.surname.isNotEmpty) _houses.nudge(v.surname, moodDelta: -0.06);
    _removeVillager(v);
  }

  /// Dilekçeyi GETİRECEK köylüyü seçer: dilekçenin zümresinden EN MUTSUZ
  /// (düşük moralli) somut biri — şikayetin gerçek sahibi. Zümre üyesi yoksa
  /// köyün en mutsuzu. Tam determinist olmasın diye en düşük moralli birkaç
  /// aday arasından seçilir. Yazar asla boş kalmaz.
  VillagerEntity? _pickPetitionAuthor(Petition p) {
    // Meslek değiştirme dilekçesi belirli bir köylüye aittir: kırgın olan.
    if (p.id == 'professionCalling') {
      final r = _resentfulVillager();
      if (r != null) return r;
    }
    // Sulh dilekçesi: kan davasının yaşayan bir tarafı konuşur.
    if (p.id == 'feudReconcile') {
      final f = _feudMember();
      if (f != null) return f;
    }
    final alive = _villagers.where((v) => !v.isDying).toList();
    if (alive.isEmpty) return null;
    var pool = alive;
    final e = p.estate;
    if (e != null) {
      final est = alive
          .where((v) => estateOfVillager(v.type, v.lifeStage) == e)
          .toList();
      if (est.isNotEmpty) pool = est;
    }
    pool.sort((a, b) => a.morale.compareTo(b.morale));
    final n = pool.length < 3 ? pool.length : 3;
    return pool[_rng.nextInt(n)];
  }

  /// Dilekçeyi getiren köylüyü seçip saklar (`_petitionAuthor`) ve sahneye
  /// diegetik olarak çıkarır: dışarıda/uyanıksa köy merkezine dönüp talebi
  /// dile getiren gövde refleksini yaşar. `_presentPetition` çağırır.
  void _summonSpokesperson(Petition p) {
    final v = _pickPetitionAuthor(p);
    _petitionAuthor = v;
    if (v == null || v.isSleeping || v.isInsideBuilding) return;
    final (cc, cr) = _villageCenter();
    v.lookToward(cc.toDouble(), cr.toDouble());
    // Talebi dile getirmek — tonuna göre kaygı/umut gövde refleksi.
    final emo = switch (p.tone) {
      PetitionTone.ominous => NpcEmotion.fear,
      PetitionTone.solemn => NpcEmotion.grief,
      PetitionTone.warm => NpcEmotion.wonder,
      PetitionTone.neutral => NpcEmotion.wonder,
    };
    v.feel(emo, 2.4);
  }

  /// En küskün HANENİN bir üyesini somurtmaya başlatır (gövde dili). Cozy:
  /// moral'i düşürmez, sadece köyde GÖRÜNÜR bir hoşnutsuzluk.
  void _showAggrievedPosture() {
    final s = _houses.mostAggrieved;
    if (s == null) return;
    final cands = _villagers
        .where((v) =>
            !v.isSleeping &&
            !v.isInsideBuilding &&
            !v.isDying &&
            !v.isCarrying &&
            v.hasProfession &&
            v.activity == VillagerActivity.none &&
            v.emotion == NpcEmotion.none &&
            v.surname == s)
        .toList();
    if (cands.isEmpty) return;
    final v = cands[_rng.nextInt(cands.length)];
    // Küskünlük derecesi morale bağlı — çok düşükse öfke, değilse buruk hüzün.
    final emo = _houses.moodOf(s) < 0.22 ? NpcEmotion.anger : NpcEmotion.grief;
    v.feel(emo, 2.0 + _rng.nextDouble() * 1.5);
  }

  /// Bir FERMAN kararının zümre etkisi (proaktif kaldıraç). [enacting] true →
  /// yürürlüğe sokmak: sevindirdiği zümre memnun olur + kalıcı nüfuz kazanır
  /// (köy o yöne kayar). false → kaldırmak: yalnızca mood'un TERSİ uygulanır
  /// (sevenler küser); nüfuz geri ALINMAZ — köy zaten o yöne kaymıştı.
  void _applyEstateDecree(List<(Estate, double)> effects,
      {required bool enacting}) {
    for (final (e, delta) in effects) {
      if (enacting) {
        _nudgeHousesByEstate(e,
            moodDelta: delta, swayGain: delta > 0 ? delta * _kSwayFromMood : 0);
      } else {
        _nudgeHousesByEstate(e, moodDelta: -delta);
      }
    }
  }

  /// Bir toggle fermanının zümre etkisini id'den çözer.
  List<(Estate, double)> _policyEstateMood(String id) {
    for (final d in kPolicyDefs) {
      if (d.id == id) return d.estateMood;
    }
    return const [];
  }

  /// Bir zümrenin doğal rakibi (#9 zümreler arası baskı). Emek↔Zanaat ekonomi
  /// ekseninde, İnanç↔Ocak ruh/gelenek ekseninde çekişir.
  Estate _estateRival(Estate e) => switch (e) {
        Estate.laborers => Estate.artisans,
        Estate.artisans => Estate.laborers,
        Estate.faithful => Estate.hearth,
        Estate.hearth => Estate.faithful,
      };
}
