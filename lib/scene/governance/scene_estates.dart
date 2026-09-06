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
        _showNotification('🌱 ${Voice.pick(_kSpringLines, _stableSeed('spring', _dayCount))}');
        _chronicle(Voice.pick(_kSpringAnnal, _stableSeed('springA', _dayCount)),
            icon: '🌱');
        _nudgeHousesByEstate(Estate.laborers, moodDelta: 0.04, swayGain: 0.02);

      case Season.summer:
        _showNotification('☀️ ${Voice.pick(_kSummerLines, _stableSeed('summer', _dayCount))}');
        _chronicle(Voice.pick(_kSummerAnnal, _stableSeed('summerA', _dayCount)),
            icon: '☀️');

      case Season.autumn:
        _showNotification('🍂 ${Voice.pick(_kAutumnLines, _stableSeed('autumn', _dayCount))}');
        _chronicle(Voice.pick(_kAutumnAnnal, _stableSeed('autumnA', _dayCount)),
            icon: '🍂');
        // Emekçilerin mevsimi — moral + nüfuz yükselir, köy kısa süre sevinir.
        _nudgeHousesByEstate(Estate.laborers, moodDelta: 0.06, swayGain: 0.06);
        pushPolicyMorale(0.04, 2.0);

      case Season.winter:
        // Kış kıtlık sınavı — ambar zayıfsa Emekçiler huzursuz, doluysa huzurlu.
        final mouths = _villagers.length;
        final lean = _stockpile.food < mouths * 3;
        if (lean) {
          _showNotification('❄️ ${Voice.pick(_kWinterLeanLines, _stableSeed('winterL', _dayCount))}');
          _chronicle(Voice.pick(_kWinterLeanAnnal, _stableSeed('winterLA', _dayCount)),
              icon: '❄️');
          _nudgeHousesByEstate(Estate.laborers, moodDelta: -0.05);
        } else {
          _showNotification('❄️ ${Voice.pick(_kWinterFullLines, _stableSeed('winterF', _dayCount))}');
          _chronicle(Voice.pick(_kWinterFullAnnal, _stableSeed('winterFA', _dayCount)),
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
        _showNotification(Voice.say(_kAscendLines,
            _voice(null, seed: _stableSeed('ascend', _dayCount),
                extra: {'soy': asc.current!})));
        _chronicle(
            Voice.say(_kAscendAnnal,
                _voice(null, seed: _stableSeed('ascendA', _dayCount),
                    extra: {'soy': asc.current!})),
            icon: '👑');
        pushPolicyMorale(0.05, 2.0); // köyün kısa sevinci
      } else {
        _showNotification(
            '⚖️ ${Voice.pick(_kBalanceLines, _stableSeed('balance', _dayCount))}');
        _chronicle(Voice.pick(_kBalanceAnnal, _stableSeed('balanceA', _dayCount)),
            icon: '⚖️');
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

    // Amenite morali: civic binaların toplam katkısı. Sabit bir "kültür binası"
    // listesi YOK — ağırlık bina tablosundaki civicValue'dan gelir, toplama +
    // doyum computeVillageStats'ta yapılır (bkz. amenityMoraleFrom).
    final amenityMorale = _stats.amenityMorale;

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
      // ...ve o çadır kışın ocaktan uzaktaysa üstüne bir de üşür. Mesafe TEK
      // kaynaktan okunur (bkz. hearth_warmth): panelde gösterilen halka ile
      // simin okuduğu sayı asla ayrışmasın.
      final coldShelter = poorHousing && _inColdShelter(v);
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
          // MÜLK TAPUSU — yazılı mülk kendi başına çalışır: serveti olan
          // servetinden de kazanır, makas açılır. Tapusuz köyde gelir yalnız
          // emeğin; tapulu köyde birikim de gelir getirir. "Bir hane iki dam
          // birden yazdırdı; öbürü yazdıracak bir şey bulamadı."
          // Bu ferman olmadan makas krizi (bkz. scene_regime) rejimden geliyordu
          // ama hükmün kendisinin ona hiçbir katkısı yoktu.
          final deedMul = _policies.sealed.contains('rejim.mulkTapusu')
              ? 1.0 + (v.wealth / 400.0).clamp(0.0, 0.5)
              : 1.0;
          v.wealth +=
              v.type.wealthDailyIncome * moraleFactor * houseMul * deedMul * dayFrac;
        }
        // Yaşam gideri — servetin %5'i/gün geri erir (asimptot + mesleksiz düşüş).
        v.wealth -= v.wealth * 0.05 * dayFrac;
        if (v.wealth < 0) v.wealth = 0;
      }

      final ev = evaluateVillagerMorale(
        homeless: homeless,
        poorHousing: poorHousing,
        coldShelter: coldShelter,
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
        // Civic binalar → "yaşanası köy" morali.
        amenityMorale: amenityMorale,
      );
      // Kimlik bonusu: Kutsal Köy ise herkesin moral hedefi biraz yükselir.
      // Kimlik bonusu + İMAN tesellisi (dinî köyde moral tabanı yükselir —
      // pusuladaki ☾ boyanın mekanik karşılığı, bkz. Regime.faithEffectOf).
      final target = (ev.target + _identityMoraleBonus + _faithEffect.moraleFloor)
          .clamp(0.0, 1.0);
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
        if (v.isDying || v.lowMoraleTime <= 2.2 * kGameDaySeconds) continue;
        // KOPMUŞ HANE TEK TEK SIZMAZ — hanesi köyden ayrılmaya hazırlanan
        // köylü, gecenin bir yarısı çıkınını bağlayıp yalnız gitmez; hanesiyle
        // birlikte gider (bkz. scene_collapse `_houseLeavesVillage`).
        //
        // Bu kapı olmadan ayrılık PRATİKTE İMKÂNSIZDI: bireysel göç 2.2 günde,
        // ayrılık 6 günde tetiklenir → küskün hane, kopuş sayacı dolmadan
        // üye üye eriyor, üyesi kalmayınca da "razı" sayılıp sayacı sıfırlanıyordu.
        // Provada birebir bu görüldü: 18 yetişkin 3'e indi, hane hiç ayrılmadı.
        if (v.surname.isNotEmpty &&
            _houses.stanceOf(v.surname) == HouseStance.defiant) {
          continue;
        }
        _emigrateVillager(v);
        break;
      }
    }
  }

  /// Kronik mutsuz köylü köyü terk eder — diegetik kayıp (bildirim + hane yası).
  void _emigrateVillager(VillagerEntity v) {
    _showNotification(Voice.say(_kEmigrateLines,
        _voice(v, seed: _stableSeed('emigrate${v.name}', _dayCount))));
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
    // Hane karşılığı: konuşan, elini çeken hanenin REİSİDİR — metindeki
    // {hane}/{ad} ondan gelir ve hükümler (`_appeaseWithholdingHouse`) doğru
    // haneye iner. Yazar yanlış seçilirse hüküm başka haneye vururdu.
    if (p.id == 'houseWithholding') {
      final sn = _withholdingHouseSurname;
      if (sn != null) {
        final head = _headOfSurname(sn);
        if (head != null) return head;
      }
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

}

// ── Mevsim ve hane satırları: havuzlu, seed gün numarasından ────────────────
// Bunlar oyunun EN ÇOK tekrar eden metinleri (her mevsim, her göç). Tek sabit
// cümle burada en çabuk ezberlenen yer olurdu; o yüzden havuz.

const _kSpringLines = [
  'İlkbahar girdi. Toprak yumuşadı, sabanın izi kalıyor.',
  'Kar çekildi. Tarlada ilk yeşil göründü, ekim vakti.',
  'İlkbahar geldi. Kuşlar döndü, tohum çuvalları açıldı.',
];
const _kSpringAnnal = [
  'İlkbahar girdi. Tarlalar sürüldü.',
  'Kar çekildi. Ekim başladı.',
  'İlkbahar. Toprak uyandı.',
];
const _kSummerLines = [
  'Yaz bastırdı. Kuyunun kovası ağır çıkıyor, ekin su istiyor.',
  'Sıcak oturdu. Öğle vakti tarlada kimse kalmıyor.',
  'Yaz geldi. Toprak çatlamaya başladı, sulama şart.',
];
const _kSummerAnnal = [
  'Yaz. Sıcak oturdu, sulama başladı.',
  'Yaz girdi. Kuyular kritik.',
  'Yaz. Ekin susadı.',
];
const _kAutumnLines = [
  'Sonbahar açtı. Harman başladı, ambarın kapağı sabaha kadar açık.',
  'Hasat vakti. Başak ağır, orak keskin.',
  'Sonbahar girdi. Arabalar dolu geliyor tarladan.',
];
const _kAutumnAnnal = [
  'Sonbahar. Harman başladı.',
  'Hasat girdi. Ambar doluyor.',
  'Sonbahar. Ambarlar açıldı.',
];
const _kWinterLeanLines = [
  'Kış bastırdı. Tarlalar dondu, ambarda dip göründü.',
  'Kar yağdı. Kilerde sayılı kile kaldı, herkes farkında.',
  'Kış girdi. Toprak taş gibi, ambar dar.',
];
const _kWinterLeanAnnal = [
  'Kış. Tarlalar dondu, erzak az.',
  'Kış girdi. Ambar dar.',
  'Kış. Kile sayılıyor.',
];
const _kWinterFullLines = [
  'Kış bastırdı. Tarlalar dondu ama ambarın kapağı zor kapanıyor.',
  'Kar yağdı. Ocaklar yanıyor, kiler dolu.',
  'Kış girdi. Toprak uykuda, sofra tok.',
];
const _kWinterFullAnnal = [
  'Kış. Tarlalar uykuda, ambar dolu.',
  'Kış girdi. Erzak yeterli.',
  'Kış. Kiler tam.',
];
const _kAscendLines = [
  '👑 Artık {soy} Hanesi konuşuyor, köy dinliyor.',
  '👑 {soy} Hanesi öne geçti. Meydanda ilk söz onların.',
  '👑 Köy {soy} Hanesi\'nin gölgesine girdi.',
];
const _kAscendAnnal = [
  '{soy} Hanesi öne geçti.',
  'Köy {soy} Hanesi\'ne yaslandı.',
  'Baskın hane: {soy}.',
];
const _kBalanceLines = [
  'Hiçbir hane öne çıkmıyor artık. Söz yeniden ortada.',
  'Baskın hane dağıldı. Meydanda herkes eşit yükseklikte konuşuyor.',
  'Denge döndü. Kimsenin sözü diğerinden ağır değil.',
];
const _kBalanceAnnal = [
  'Baskın hane çözüldü.',
  'Köy dengeye döndü.',
  'Hiçbir hane baskın değil.',
];
const _kEmigrateLines = [
  '{ad} çıkınını bağladı, kimseye söylemeden yola çıktı.',
  '{ad} gitti. Uzun zamandır burada değildi zaten.',
  '{ad-in} kapısı bu sabah açık kaldı. Geri dönmeyecek.',
  // Ayrılık, yeri bir ad hâline getirir: gidenin ardında bıraktığı artık
  // "köy" değil, adı olan bir yerdir.
  '{ad} {köy-den} ayrıldı. Yol göründü, arkasına bakmadı.',
];
