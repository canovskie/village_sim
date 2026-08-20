part of '../main.dart';

extension _SceneDeathMarkers on _VillageSceneState {
  /// Ölümün evde görünür bir izi: 8 saniyelik yas işareti ve aynı evdeki
  /// kayıplar için küçük sayaç. Evsiz köylüde işaret üretilemez.
  void _markDeathHouse(VillagerEntity v) {
    final home = v.homeBuilding;
    if (home is! BuildingEntity) return;
    home.deathMarkerUntil = max(home.deathMarkerUntil, _time + 8.0);
    home.deathMarkerCount = (home.deathMarkerCount + 1).clamp(1, 9);
  }
}

/// Komşuluk/birleşim spatial hash buffer — top-level reused (her poll'da
/// clear+refill, allocate yok). Bucket key = (gridX~/2, gridY~/2).
final Map<(int, int), List<int>> _greetBuckets = {};

/// Sahne game loop — `_onTick` orijinal davranışla aynı sırada alt-metotlara
/// bölünmüş halde. part of main.dart — State'in tüm private alanlarına erişim.
extension _SceneTick on _VillageSceneState {
  void _onTick(Duration elapsed) {
    final raw = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.1);
    _last = elapsed;
    _clampCamera(_viewSize); // kamera reach clamp'i (ilk ortalama + sürekli)
    _maybeAutoSave(raw); // periyodik otomatik kayıt (gerçek-zaman birikimi)
    // HUD'u ~10Hz'de güncelle (her frame değil) — pahalı ağaç, yavaş veri.
    _hudAccum += raw;
    if (_hudAccum >= _VillageSceneState._kHudInterval) {
      _hudAccum = 0;
      _hudFrame.value = _hudFrame.value + 1;
      // Çocuk sayısı ses aksanı için — HUD ile aynı 10Hz'de sayılır. Her
      // karede saymak gereksiz: sayı saniyeler içinde değişmez, sesin sayacı
      // zaten dakikalık.
      _childCount = 0;
      for (final v in _villagers) {
        if (v.lifeStage == LifeStage.child && !v.isDying) _childCount++;
      }
    }
    if (_shakeTime > 0) _shakeTime -= raw; // kamera sarsıntısı sönümü (juice)
    if (_imperialAlertLeft > 0) {
      _imperialAlertLeft -=
          raw; // İmparatorluk varış anonsu geri sayımı (gerçek-zaman)
    }
    // Ses ortamı — gerçek-zaman dt ile (sim duraklasa/sinematikte de akar).
    AudioManager.instance.update(
      raw,
      dayLight: _cycle.dayLight,
      rng: _rng,
      children: _childCount,
    );
    AudioManager.instance.applyAmbient(
      dayLight: _cycle.dayLight,
      rain: _cycle.rainIntensity,
      hasFire: _hasFire,
    );
    // CAPTURE: sim'i durduran modalları bastır — harness'te onları kapatacak
    // oyuncu yok, açılan ilk sinematik/olay simülasyonu sonsuza dek dondurur
    // (iş döngüsü telemetrisi bu yüzden bir kez tamamen "donuk" okundu).
    // Prova harness'i de (kProbeOn) bunları bastırır — köyü karar bekleyen bir
    // modal sonsuza dek dondurmasın; harness'te tıklayacak oyuncu yok.
    if (kCaptureShowcase || kProbeOn) {
      _activeCutscene = null;
      // İSTİSNA: kuyruk provası tam da bekleyişi ve zaman aşımını ölçer (bkz.
      // kProbeChoiceQueueArmed). Muafiyet kalkmazsa kuyruk her tick silinir ve
      // test "olay hiç kuyruğa girmedi" der — sistem çalışıyorken.
      if (!kProbeChoiceQueueArmed) {
        _pendingChoice = null;
        _choiceModalOpen = false;
      }
      // İSTİSNA: eşik provası tam da bu modalın düğmesine basacaktır (bkz.
      // kProbeImperialArmed). Muafiyet kaldırılmazsa heyet her tick silinir ve
      // test "pazarlık hiç açılmadı" der — sistem çalışıyorken.
      if (!kProbeImperialArmed) _imperialDemand = null;
      if (!kProbePetitionQueueArmed) _petitionOverdue = false;
    }
    // GECİKMİŞ DİLEKÇE HARNESS'LERDE SUSTURULUR. Eski akışta mühleti dolan
    // dilekçe modalı zorla açıp simi SONSUZA DEK donduruyordu (köy gün 27'de
    // donup kışı hiç görmedi, test "çadır mekaniği ölü" diye bağırdı). Donma
    // kalktı; yine de kapıda bekleyen huzurun gün-başı bedeli uzun koşan
    // telemetri harness'lerinde hane/moral eğrisini kirletir — düşürülür.
    // (Sinematik/olay/imparatorluk bilerek DOKUNULMADAN kalır — görsel
    // harness'ler tam da onları çekiyor.)
    if (kCaptureMode && !kProbePetitionQueueArmed) _petitionOverdue = false;
    // CAPTURE: İmparatorluk varış anonsunu bir kez tetikle (harness görsel test).
    if (kCaptureImperialAlert &&
        kCaptureSceneReady &&
        _imperialAlertLeft <= 0 &&
        _imperialAlertSub.isEmpty) {
      _imperialAlertSub = 'Sancak göründü. Vergi kolonu köyün üstüne yürüyor.';
      _imperialAlertLeft = _VillageSceneState._kImperialAlertDur;
    }
    // SİMİ DURDURAN yalnız üç şey kaldı: dağılma (dünyanın sonu), sinematik
    // (kamera başka yerde) ve imparatorluk pazarlığı (nadir, meşru kesinti).
    // Olay kararı ve dilekçe artık DONDURMAZ — kapıda kuyruk: mühür bekler,
    // mühlet erir, dünya yaşamaya devam eder (bkz. scene_events/_petitions).
    // Time scale × dev speed boost uygulanır. Boost denge testi için 1-30x
    // arası DevPanel slider'ından gelir; normal oyunda 1.0.
    final effectiveScale =
        (_collapsed || // köy dağıldı → dünya durur
            _activeCutscene != null ||
            _imperialDemand != null)
        ? 0.0
        : _timeScale *
              (kDevSpeedBoostOverride > 0
                  ? kDevSpeedBoostOverride
                  : _devSpeedBoost);
    // dt clamp scaling: boost 1x ise 50ms hard cap (spiral koruma — render
    // yavaşlasa bile sim sıçramaz). Boost > 1.5x ise kullanıcı bilerek hızlı
    // sim istiyor, clamp gevşek (boost × 0.05) → hızlandırma çalışır.
    // Bu sayede normal oynanış güvenli, denge testi 30x'te tam hızlı.
    final clampMax = effectiveScale > 1.5 ? effectiveScale * 0.05 : 0.05;
    if (kCaptureMode) {
      // Dağılma telemetrisi BURADA yazılır: köy dağılınca dt sıfırlanır ve
      // tick zinciri (dolayısıyla _tickCollapse) hiç koşmaz. Sayaç orada
      // kalsaydı prova sonsuza dek "dağılmadı" derdi.
      kProbeCollapsed = _collapsed;
      // Olay/dilekçe bu listeden ÇIKTI: artık dondurmuyorlar (kapıda kuyruk).
      // Bekleyen karar kProbeChoiceWaiting'te ayrıca okunur.
      kProbePause = _collapsed
          ? 'dağıldı'
          : _activeCutscene != null
          ? 'sinematik'
          : _imperialDemand != null
          ? 'imparatorluk'
          : '';
    }
    final dt = (raw * effectiveScale).clamp(0.0, clampMax);
    if (dt <= 0) {
      _frame.value = _frame.value + 1;
      return;
    }
    // setState yerine sim mutate + _frame.value++ → outer ağaç rebuild olmaz,
    // sadece ListenableBuilder bağlı bölgeler repaint olur.
    _advanceWorldClock(dt);
    // Bütün ağır kararların ortak saati. Dünya saati ilerledikten hemen sonra
    // sessizlik kapısını açar; bekleyen payload'lar simi durdurmadan sırada kalır.
    _tickDecisionPacing();
    _applyGodModeRefill();
    final starvation = _tickPopulationAndHunger(dt);
    _tickEventsAndFx(dt);
    _tickWeatherReaction(dt); // yağmur başla/dur → gövde dili + sığınağa koş
    _tickLightning(dt); // fırtınada beyaz gök flash'ı (şekilsiz)
    _tickBuildingSystems(dt, starvation);
    _maybeRebuildSpatialCache(dt);
    _tickEntities(dt);
    _tickMerchants(dt); // arada gelip giden gezgin tüccar (ambiyans)
    _tickPostMotion(dt);
    _tickDerivedAndMeta(dt);
    _spontaneousLife(dt); // sürekli baseline canlılık (rastgele refleks)
    _tickPersonalMoments(dt); // kişisel anlar (yıldönümü + çocuk→genç büyüme)
    _tickCallingMoments(dt); // çağrısını buldu (genç→yetişkin meslek keşfi)
    _tickFriendshipMoments(dt); // dostluk (karşılıklı kanaat → can dostu)
    _tickCraftDiscovery(
      dt,
    ); // birikim → yapı zanaatı köye doğar (marangozluk/taş)
    _tickComfort(dt); // konfor talebi (surplus → şölen + moral)
    _frame.value = _frame.value + 1;
  }

  // ── Saat / gün ─────────────────────────────────────────────────────────────

  void _advanceWorldClock(double dt) {
    _time += dt;
    _cycle.update(dt);
    // Harness: vakit dondurulduysa saati geri sabitle (bkz. kCaptureTimeOfDay).
    // Gün sarma kontrolünden ÖNCE uygulanır, yoksa donmuş gece her karede
    // "yeni gün" sanılıp _dayCount uçardı.
    if (kCaptureTimeOfDay >= 0) {
      _cycle.timeOfDay = kCaptureTimeOfDay;
      _lastTimeOfDay = kCaptureTimeOfDay;
    }
    // Gün sayacı — timeOfDay sarınca (örn. 0.98 → 0.02) yeni gün.
    if (_cycle.timeOfDay < _lastTimeOfDay) {
      _dayCount++;
      _applyLawUpkeep(); // defter bir kez yazılır ama her gün konuşur
    }
    // Şafak — gün doğumu eşiğini (0.25) geçince horoz öter (bir kez/gün).
    if (_lastTimeOfDay < 0.25 && _cycle.timeOfDay >= 0.25) {
      AudioManager.instance.playSfx(Sfx.roosterCrow);
    }
    _lastTimeOfDay = _cycle.timeOfDay;
    // Mevsim dönümü — gün değişince mevsim de değişmiş olabilir.
    final season = _season;
    if (_lastSeason == null) {
      _lastSeason = season; // ilk tick / yükleme: sessizce kur
    } else if (season != _lastSeason) {
      _lastSeason = season;
      _onSeasonTurn(season);
    }
  }

  // ── Şimşek flash ────────────────────────────────────────────────────────────
  // Fırtınada (yağmur > 0.6) seyrek, ŞEKİLSİZ beyaz gök parlaması. Bir yere
  // düşmez, çizgi/şekil yok — sadece tüm gökyüzü kısa süre aydınlanır (gerçek
  // hayattaki gibi). Yumuşak (≤0.30 alfa), bazen çift çakım (flicker).
  void _tickLightning(double dt) {
    if (_lightningFlash > 0) {
      _lightningFlash -= dt * 3.2; // ~0.3s'de söner
      if (_lightningFlash < 0) _lightningFlash = 0;
    }
    // Işık-ses gecikmesi: şimşek çaktıktan kısa süre sonra gök gürültüsü
    // (uzak fırtına hissi). Fırtına bitse bile bekleyen gümbürtü çalsın.
    if (_thunderDelay > 0) {
      _thunderDelay -= dt;
      if (_thunderDelay <= 0) AudioManager.instance.playSfx(Sfx.thunderClap);
    }
    final storm = _cycle.rainIntensity > 0.6;
    if (!storm) {
      _lightningTimer = 4.0 + _rng.nextDouble() * 4.0;
      _lightningPulse = 0;
      return;
    }
    // İkincil çakım (flicker) — ana flash'tan kısa süre sonra hafif darbe.
    if (_lightningPulse > 0) {
      _lightningPulse -= dt;
      if (_lightningPulse <= 0) _lightningFlash = 0.17;
    }
    _lightningTimer -= dt;
    if (_lightningTimer <= 0) {
      _lightningTimer = 6.0 + _rng.nextDouble() * 11.0;
      _lightningFlash = 0.26 + _rng.nextDouble() * 0.04; // göz yormayan tavan
      _lightningPulse = _rng.nextBool() ? 0.08 + _rng.nextDouble() * 0.05 : 0.0;
      // Uzak gök gürültüsü flash'tan ~0.5–1.4s sonra (mesafe hissi).
      _thunderDelay = 0.5 + _rng.nextDouble() * 0.9;
    }
  }

  // ── God mode refill ───────────────────────────────────────────────────────

  void _applyGodModeRefill() {
    if (!_godMode) return;
    _stockpile.wood = 9999;
    _stockpile.stone = 9999;
    _stockpile.iron = 9999;
    _stockpile.coal = 9999;
    _stockpile.food = 9999;
    _stockpile.gold = 9999;
    _hasFire = true;
    // İnşaatları anında tamamla
    for (final o in _orders) {
      o.progress = 1.0;
      o.completed = true;
    }
  }

  // ── Nüfus & yiyecek tüketimi ──────────────────────────────────────────────

  /// Housing occupancy recount + tüm "ağızların" yiyecek tüketimi. Açlık
  /// durumunu 0..1 döndürür (kStarveRampFood altında devreye girer).
  double _tickPopulationAndHunger(double dt) {
    // Konut doluluğunu güncelle — ev su tüketimi sakin sayısına bağlı.
    for (final b in _buildings) {
      if (b.fn?.role == BuildingRole.housing) {
        b.occupants = 0;
        b.awakeOccupants = 0;
      }
    }
    for (final v in _villagers) {
      if (v.homeBuilding case final h?) {
        final home = h as BuildingEntity;
        home.occupants++;
        if (!v.isSleeping) home.awakeOccupants++;
      }
    }
    // PENCERE IŞIĞI — evin camı sakinleri uyudukça söner. Aynı sayımın içinde
    // yapılır: ayrı bir tarama, aynı listeyi ikinci kez gezmek olurdu.
    //
    // Yumuşak akış şart: sert geçişte köy her gece tek karede kararıyor, "ışık
    // söndü" değil "ışık bozuldu" gibi duruyor. ~2 sn'lik exp-lerp, son uyuyan
    // yattıktan sonra camın sönmesine yetecek kadar yavaş.
    final glowK = 1 - exp(-dt * 0.55);
    for (final b in _buildings) {
      if (b.fn?.role != BuildingRole.housing) continue;
      final target = b.occupants == 0 ? 0.0 : b.awakeOccupants / b.occupants;
      b.windowGlow += (target - b.windowGlow) * glowK;
    }

    // Tüm köylüler + işçiler zamanla yiyecek yer; üretim yetmezse stok azalır.
    // Yaşlıya saygı politikası açıksa yaşlılar tüketmez.
    final exemptElders = _policies.eldersExemptFromFood
        ? _villagers.where((v) => v.lifeStage == LifeStage.elder).length
        : 0;
    final mouths = _villagers.length - exemptElders;
    if (!_godMode && mouths > 0) {
      // Kimlik bonusu: Köklü Yuva tutumlu sofra kurar (_identityFoodMul=0.85).
      _foodHunger +=
          dt *
          mouths *
          _identityFoodMul *
          (kFoodPerVillagerPerDay / kGameDaySeconds);
      if (_foodHunger >= 1.0) {
        var eat = _foodHunger.floor();
        _foodHunger -= eat;
        // SICAK YEMEK ÖNCE — ocakta pişen yemek ham yiyeceğin yerine geçer.
        // Aşçı 1 ham yiyecekten 2 yemek çıkardığı için köy, aynı hasadı
        // pişirdiğinde iki katı süre idare eder. Erken oyunda oyuncunun
        // "birini aşçı yapayım" kararının somut karşılığı bu satır.
        if (_cookedMeals > 0 && eat > 0) {
          final fromMeals = eat < _cookedMeals ? eat : _cookedMeals;
          _cookedMeals -= fromMeals;
          eat -= fromMeals;
        }
        if (eat > 0) {
          _stockpile.food = (_stockpile.food - eat).clamp(0, 1 << 30);
        }
      }
    }
    // Açlık 0..1: stok [_starveRamp] altına inince devreye girer (moral düşer).
    // Eşik sabit değil — Ortak Ambar fermanı onu yarıya indirir.
    return _stockpile.food >= _starveRamp
        ? 0.0
        : (1.0 - _stockpile.food / _starveRamp);
  }

  // ── Olaylar & efektler ────────────────────────────────────────────────────

  void _tickEventsAndFx(double dt) {
    // Aktif geçici etki sönümlenir; zamanlayıcı dolunca yeni olay tetiklenir.
    if (_eventMoraleLeft > 0) {
      _eventMoraleLeft -= dt;
      if (_eventMoraleLeft <= 0) {
        _eventMorale = 0;
        _eventLabel = null;
      }
    }
    // Pop-up banner countdown — süresi bitince banner kapanır.
    if (_activeEventLeft > 0) {
      _activeEventLeft -= dt;
      if (_activeEventLeft <= 0) {
        _activeEvent = null;
      }
    }
    // Aktif sahne efektleri — decay + aggregate (tint, rain, mul'lar).
    _updateActiveFx(dt);
    // Yağmur boost'u — fırtına, yaz yağmuru efektlerinde rain min yükseltilir.
    if (_fxRainBoost > _cycle.rainIntensity) {
      _cycle.rainIntensity = _fxRainBoost;
    }
    if (_villagers.isNotEmpty) {
      // Olaylar önce mayalanır (omen: diegetik uyarı), sonra vurur — bkz.
      // scene_events. Otomatik üretim godMode'da kapalı ama omen İLERLEMESİ
      // (dev-tetiklenen olay dahil) her zaman işler — gate metodun içinde.
      _tickEventOmen(dt);
    }
    // Kuyrukta bekleyen karar — mühlet erir; dolarsa köy pasif seçeneği
    // kendi yaşar (kapıda kuyruk: sim donmaz, karar da yok olmaz).
    _tickChoiceDeadline(dt);
  }

  // ── Bina sistemleri (üretim/ticaret/stat + aktiflik bayrakları) ───────────

  void _tickBuildingSystems(double dt, double starvation) {
    // ── Açlık → bir kerelik görünür reaksiyon (formül değil) ──────────────
    // Açlığa girilince köy görünür tedirgin olur: gövde dili (keder) + ayrık
    // moral nudge. Toparlanınca bayrak sıfırlanır (tekrar tetiklenebilir).
    if (!_wasStarving && starvation > 0.5) {
      _wasStarving = true;
      _feelVillage(NpcEmotion.grief, 6, -0.05);
      nudgeMorale(-0.10);
    } else if (_wasStarving && starvation < 0.15) {
      _wasStarving = false;
    }
    // Derin kıtlık — koşuda bir kez işaretlenir. Eskiden tam ekran sinematik
    // oynardı; kaldırıldı. Kıtlık zaten dünyada görülüyor (yukarıdaki keder
    // gövde dili + moral düşüşü) ve haberi güncede duruyor. Tam ekran film
    // yalnız kuruluş / imparatorluk / hesaplaşma için saklı.
    if (!_famineShown && starvation > 0.85 && _villagers.length >= 6) {
      _famineShown = true;
      _feelVillage(NpcEmotion.grief, 12, -0.06); // krize dönük ikinci dalga
      _chronicle('Kıtlık baş gösterdi', icon: '🍂', milestone: true);
      _showNotification('🍂 Kıtlık baş gösterdi. Ambar boş, karınlar aç.');
    }

    // ── Moral (pasif gösterge) ────────────────────────────────────────────
    // Hedef yalnızca OLAY + POLİTİKA + bilge'den gelir — ekonomi (yemek/su/
    // stok/bina) moral hesabına KATILMAZ. _morale hedefe yumuşakça süzülür;
    // etki bitince taban 0.5'e geri döner. Ayrıca ayrık reaksiyonlar
    // [nudgeMorale] ile anlık iter. Hiçbir mantık _morale'i okumaz.
    final moraleTarget =
        (0.5 +
                _eventMorale +
                (_villagers.any((v) => v.isSage) ? 0.08 : 0.0) +
                _policyMoralePermanent() +
                _policyMoraleTemporary() +
                _governanceLegacy + // büyük kararların kalıcı ruh izi
                // Bireysel moral ortalaması köy moraline beslenir: koşullar (ev/
                // yiyecek/su/ısınma/zümre) bireyler üzerinden DOLAYLI yansır.
                (_avgIndividualMorale - 0.62) * 0.5)
            .clamp(0.0, 1.0);
    _morale +=
        (moraleTarget - _morale) * (dt * kMoraleEaseRate).clamp(0.0, 1.0);
    _morale = _morale.clamp(0.0, 1.0);

    // Konut suyu, pazar geliri, stok kapasitesi, amenite morali. Köy morali
    // (bireysel ortalama) pasif geçer.
    _stats = updateBuildings(
      dt: dt,
      buildings: _buildings,
      stockpile: _stockpile,
      enforceCapacity: !_godMode,
      morale: _morale,
    );
    // Ahır bonusunu taşıyıcılara uygula
    for (final v in _villagers) {
      v.carrySpeedMultiplier = _stats.carrierSpeedMultiplier;
    }

    // Toplama binaları çalışıyor mu? (panel durumu)
    for (final b in _buildings) {
      switch (b.type) {
        // Toplama binaları: yakınında ATANMIŞ (çalışan) köylü varsa aktif —
        // işçiler artık gerçek köylü (job) olduğundan job rolüne bakılır.
        case BuildingType.mineBuilding:
          b.isActive = _jobWorkerActiveNear(JobRole.miner, b);
        case BuildingType.lumberCamp:
          b.isActive = _jobWorkerActiveNear(
            JobRole.woodcutter,
            b,
            radius: kLumberTerritoryRadius,
          );
        case BuildingType.fisherCabin:
          b.isActive = _villagers.any(
            (v) => v.job?.role == JobRole.fisher && v.job!.working,
          );
        case BuildingType.barn:
          b.isActive = _jobWorkerActiveNear(JobRole.shepherd, b, radius: 6.0);
        case BuildingType.mill:
          // Balya teslimleri grindPulse'ı besler (carrier_system); burada
          // tüketilir. >0 iken değirmen "çalışıyor" → çalışma dumanı + panel.
          if (b.grindPulse > 0) b.grindPulse -= dt;
          b.isActive = b.grindPulse > 0 && !b.userPaused;
          if (!b.userPaused) {
            // Değirmen kanatları operasyonel olduğu sürece döner; un öğütme
            // darbesi yalnızca duman/toz ve paneldeki "çalışıyor" durumunu
            // belirler. Sakin, ağır tempo: yaklaşık 10.5 saniyede bir tur.
            // Sim durursa veya bina duraklatılırsa açı ilerlemez.
            b.millRotorAngle = (b.millRotorAngle + dt * 0.60) % (2 * pi);
          }
        default:
          break;
      }
    }
  }

  // ── Spatial cache (throttled) ──────────────────────────────────────────────

  void _maybeRebuildSpatialCache(double dt) {
    // Engel/yumuşak-engel set'leri yavaş değişir → her frame değil, throttle'lı
    // yeniden kur (su statik; maden/sazlık değişimi kSpatialRebuildInterval
    // gecikmesiyle yansır — yürüyüş için görünmez).
    _spatialTimer -= dt;
    if (_spatialTimer <= 0) {
      _rebuildSpatialCaches();
      _spatialTimer = kSpatialRebuildInterval;
    }
  }

  // ── Entity tick (villager, worker, animal, üretim) ─────────────────────────

  void _tickEntities(double dt) {
    final obstacles = _obstacles;
    final softObs = _softObs;
    // Sim multiplier'ları — aktif efekt aggregate'inden.
    final npcDt = dt * _fxNpcSpeedMul;
    final farmDt = dt * _fxFarmMul;
    // (builder dt artık _tickJobs içinde _fxBuilderMul ile hesaplanır)

    for (final v in _villagers) {
      // Oyuncu elinde tuttuğu köylü dondurulur (tutup-bırak) — AI hareketi
      // imleci ezmesin; bırakınca normale döner.
      if (identical(v, _draggedVillager)) continue;
      v.update(
        npcDt,
        kCols,
        kRows,
        _rng,
        waterTiles: obstacles,
        softObstacles: softObs,
        dayLight: _cycle.dayLight,
        rainIntensity: _cycle.rainIntensity,
      );
    }
    // Doğal ölüm — ömrü dolan yaşlılar köyden ayrılır. Taşıma işi varsa
    // önce bitirsin (yerde öksüz kutu/balya kalmasın). Belediye yerini doldurur.
    // Aile bağı: ölenin parents listesinden onu kaldır, kendisinin children
    // listesinde de parent ref'lerini temizle (çocuklar yetim olabilir).
    // Yaşlıya huzur: lifespan'in son %5'inde aging 5× hızlanır → birkaç günde
    // sakince ayrılır, uzun bekleme olmaz.
    if (_policies.peacefulEnd) {
      for (final v in _villagers) {
        if (v.lifeStage == LifeStage.elder &&
            v.ageDays > v.lifespanDays * 0.95 &&
            v.ageDays < v.lifespanDays) {
          v.ageDays += dt * 4.0 / kGameDaySeconds;
        }
      }
    }

    // Doğal ölüm → ANLIK silme yok: köylü gözle görülür biçimde çöker + solar
    // (collapse animasyonu), animasyon bitince listeden çıkar. Taşıma işi varsa
    // önce bitirsin (yerde öksüz kutu/balya kalmasın). Aile bağı ölüm başlarken
    // koparılır ki sim (doğurganlık/sosyal) onu artık saymasın.
    for (final v in _villagers) {
      if (v.isDying || v.isCarrying) continue;
      if (v.ageDays >= v.lifespanDays) {
        logDev('${v.name} eceliyle göçüyor', tag: '⚰', color: AppUi.info);
        for (final p in v.parents) {
          p.children.remove(v);
        }
        for (final c in v.children) {
          c.parents.remove(v);
        }
        _markDeathHouse(v);
        v.startDying(funeral: true);
      }
    }
    // Çöküş animasyonu biten köylüleri kaldır + doğal ölümlerde cenaze düzenle.
    // Tören _gatherAtFire ile _villagers'ı tarar → ölü listeden çıktıktan SONRA
    // çalışmalı (cenaze sistemi scene_funeral'da).
    final dead = <(VillagerEntity, int)>[];
    final removed = <VillagerEntity>[];
    _villagers.removeWhere((v) {
      // Ölüm animasyonu bitti VEYA sürgün kenara vardı (leftVillage) → çıkar.
      // Sürgün cenaze ALMAZ (deathHoldsFuneral false), ama zanaat kaybı + küslük
      // temizliği (aşağıda) ikisi için de geçerli.
      if (!v.deathFinished && !v.leftVillage) return false;
      final orphans = v.children.where((c) => c.parents.isEmpty).length;
      if (v.deathHoldsFuneral) dead.add((v, orphans));
      removed.add(v);
      return true;
    });
    // Ölenlere kalan tüm sahne referanslarını kopar (sosyal bellek + seçim/
    // dilekçe/düğün işaretçileri) — tek kapı `_forgetVillager`.
    for (final r in removed) {
      _forgetVillager(r);
    }
    for (final (v, orphans) in dead) {
      _holdFuneral(v, orphans: orphans);
    }
    // Zanaat kaybı — köyden AYRILAN herkes için (doğal ölüm + idam + sürgün;
    // hepsi startDying'den bu listeye düşer). Kaçırma/asker raw remove olduğu
    // için buraya girmez (geri dönebilirler → zanaat düşmez). v zaten _villagers
    // dışında → "başka yaşayan usta" kontrolü doğru. (bkz. scene_craft)
    for (final v in removed) {
      _onCraftHolderDeath(v);
    }

    // Doğal doğum — fertility timer'ı dolan kadınlar için partner + yatak
    // kontrolü, varsa bebek spawn. Maliyet yok (chill-gameplay).
    // Throttle: her frame full villager scan gereksiz; 0.5s polling oyuncu
    // tarafından hissedilmez (anne hâlâ aynı tick'te doğurur).
    _reproPollSec -= dt;
    if (_reproPollSec <= 0) {
      _reproPollSec = 0.5;
      _tickReproduction();
      _tickAnimalReproduction();
    }
    _tickMigration(dt);
    _tickNeighborGreet(dt);
    _tickChildPlay(dt);
    _tickFamilyReunion(dt);
    _tickSharedHarvest(dt);
    _tickSageEmergence(dt);
    // İş atama + yürütme — inşaatçı/çiftçi/… artık gerçek köylü (bkz. scene_jobs).
    // Köylüler yukarıda güncellendi (hareket); jobs onlara sonraki hedefi verir
    // ve aksiyon sayaçlarını ilerletir.
    _tickJobs(dt, obstacles, softObs);
    _syncJobWorkforce(dt);
    // Tamamlanan inşaatlar için özel aksiyonlar
    bool topologyChanged = false;
    for (final o in _orders) {
      if (o.completed) {
        _onBuildingCompleted(o);
        topologyChanged = true;
      }
    }
    if (_roadOrders.any((o) => o.completed)) topologyChanged = true;
    _orders.removeWhere((o) => o.completed);
    _roadOrders.removeWhere((o) => o.completed);
    // World topology değişti → NPC'ler cached path'i invalidate etsin +
    // anchor sistemi yeni binalara göre slot'ları yenilesin.
    if (topologyChanged) {
      _pathContext.bumpVersion();
      _anchorSystem.rebuild(_buildings);
      _rebuildBeeSwarms();
    }
    final season = _season;
    for (final t in _farmTiles) {
      t.update(farmDt, season);
    }
    // Çiftçilik artık atanmış köylüler eliyle (_runFarmer, scene_jobs) —
    // kuyu/hasat/ekim/sulama döngüsü orada. Hasat hay'ini de o üretir.
    // Yeni balyanın spawnTime'ı gerçek sahne zamanı olsun: aksi hâlde varsayılan
    // 0 yüzünden oyun ilerledikten sonra oluşan balya drop/settle animasyonunu
    // atlayıp harmanda bir anda beliriyordu.
    processHayPiles(_hayEntities, _farmTiles, time: _time);
    _tickBaleStallWarning(dt);
    // Oduncu kesimi artık atanmış köylü (scene_jobs: _runWoodcutter) — kesip
    // odun kütüğü bırakır. Kereste kampının BÖLGE YÖNETİMİ (ağaç işaretleme +
    // fidan dikme, binaya bağlı) burada per-kamp yürür:
    _tickLumberCampManage(dt);
    // Fidan büyümesini güncelle + devrilme animasyonunu ilerlet. Kes'lenen
    // ağaç anında kaybolmaz: isFelled olunca [fellAge] artar, ağaç tabandan
    // yana DEVRİLİR; ancak devrilme bitince (kFallDuration) tile açılır/kalkar.
    for (final t in _trees) {
      t.update(dt);
      if (t.isFelled) {
        t.fellAge += dt;
        if (!t.fallImpactEmitted && t.fellAge >= TreeEntity.kImpactAge) {
          t.fallImpactEmitted = true;
          _leafBursts.add(
            LeafBurst(
              t.col + 0.5,
              t.row + 0.5,
              _rng.nextInt(1 << 20),
              direction: t.fallDirection,
            ),
          );
          addCameraShake(1.4, dur: 0.18);
        }
      }
    }
    // Devrilmesi tamamlananlar: wild → orman geri çekilir + tile açılır;
    // her kesim dünyada devrilmiş gövde + küçük bir kütük dibi izi bırakır.
    // Scatter ağaçta
    // doğa-dostu politikada yakına fidan gelir. (Henüz devrilenler listede
    // kalır, çizilmeye devam eder.)
    final done = _trees
        .where((t) => t.isFelled && t.fellAge >= TreeEntity.kFallDuration)
        .toList();
    bool landOpened = false;
    for (final f in done) {
      if (f.isWild) {
        if (_openFrontierTile(f.col, f.row)) {
          landOpened = true;
        }
      } else if (_policies.treePlanting) {
        _plantSaplingNear(f.col, f.row);
      }
      if (!_decor.any(
        (d) => d.col == f.col && d.row == f.row && d.kind == DecorKind.stump,
      )) {
        _decor.add(
          DecorEntity(
            col: f.col,
            row: f.row,
            kind: DecorKind.stump,
            variant: (f.col * 17 + f.row * 31).abs() % 2,
            jitterX: 0,
            jitterY: 0,
            swaySeed: f.col * 17 + f.row * 31,
          ),
        );
      }
      // Devrilen gövde kesimden sonra dünyada kalır; stump ile aynı tile'da
      // çizildiğinde log üstte görünür ve kesim sonucu anlık bir "pop" yerine
      // yerin gerçekten değiştiği hissini verir.
      if (!_decor.any(
        (d) =>
            d.col == f.col && d.row == f.row && d.kind == DecorKind.fallenLog,
      )) {
        _decor.add(
          DecorEntity(
            col: f.col,
            row: f.row,
            kind: DecorKind.fallenLog,
            variant: (f.col * 31 + f.row * 17).abs() % 2,
            jitterX: 0,
            jitterY: 0,
            swaySeed: f.col * 31 + f.row * 17,
          ),
        );
      }
    }
    _trees.removeWhere(
      (t) => t.isFelled && t.fellAge >= TreeEntity.kFallDuration,
    );
    if (landOpened) _spatialTimer = 0; // engel/land cache'i ilk tick'te tazele
    // Madenci / balıkçı / çiçekçi artık atanmış köylüler (scene_jobs: _runMiner/
    // _runFisher/_runFlorist) — cevher/yiyecek üretimi + sulama orada.
    // Ağıl: inekler otlar, çobanlar sağar. Sağım = +1 food (balıkçı pattern).
    for (final c in _cows) {
      c.update(npcDt, _rng, waterTiles: obstacles);
    }
    // Doğal ölüm — ömrü dolan hayvan anlık silinmez: görünür biçimde çöker+solar
    // (köylüyle simetrik), animasyon bitince listeden çıkar. Chill: kaynak cezası
    // yok. Ölüm zümre moralini scene_estates'te beslesin diye sayacı tut.
    for (final c in _cows) {
      if (!c.isDying && c.ageDays >= c.lifespanDays) {
        c.startDying();
        _animalDeathsPending++;
      }
    }
    _cows.removeWhere((c) => c.deathFinished);
    _tickEggs(dt);
    // Arı Kovanı: pasif bal üretimi, menzildeki çiçek sayısıyla hızlanır.
    // Çiçeksiz kovan da yavaşça bal verir; florist'in yanına konulan kovan
    // 2-3 kat hızlanır → "doğru yerleşim" ödüllendirilir. Bal lüks/moral.
    for (final b in _buildings) {
      if (b.type != BuildingType.beehive) continue;
      final meta = kBuildingMeta[BuildingType.beehive]!;
      final cx = b.col + meta.cols * 0.5;
      final cy = b.row + meta.rows * 0.5;
      final r2 = meta.effectRadius * meta.effectRadius;
      int flowers = 0;
      for (final d in _decor) {
        if (d.crushed || !_isFlowerDecor(d.kind)) continue;
        final dx = (d.col + 0.5) - cx;
        final dy = (d.row + 0.5) - cy;
        if (dx * dx + dy * dy <= r2) flowers++;
      }
      // Hız çarpanı: çiçeksiz 1.0, her çiçek +adım, tavana kadar. TEK KAYNAK
      // (building_lore) — inşa künyesindeki "×2.1" rozeti de bunu okur.
      final speed = honeySpeedFromFlowers(flowers);
      b.honeyTimer += dt * speed;
      if (b.honeyTimer >= kHoneyInterval) {
        b.honeyTimer = 0.0;
        _stockpile.honey += 1;
      }
    }
    // Çoban artık atanmış köylü (scene_jobs: _runShepherd) — sağım + sürü.
    final mineCountBefore = _mineNodes.length;
    _mineNodes.removeWhere((n) => n.isDepleted);
    if (_mineNodes.length != mineCountBefore) _pathContext.bumpVersion();
    _carrierTimer -= dt;
    if (_carrierTimer <= 0) {
      _carrierTimer = kCarrierAssignInterval;
      assignCarriers(
        villagers: _villagers,
        buildings: _buildings,
        resourceBoxes: _resourceBoxes,
        hayEntities: _hayEntities,
        stockpile: _stockpile,
        anchorSystem: _anchorSystem,
        baleYieldMultiplier:
            _season.yieldMultiplier *
            (_policies.cropRotation ? 1.2 : 1.0) *
            _identityYieldMul * // kimlik bonusu: Zanaat Kasabası +%15
            _regimeWorkMul * // rejim çürümesi: tembellik krizi verimi kısar
            _millerYieldMul(), // değirmenin başında değirmenci varsa +%25
        // Balyayı ambara İNDİREN köylünün hanesi esirgiyorsa ürün köye değil
        // o hanenin kendi ambarına gider (bkz. scene_house_stance).
        routeFood: _deliverFoodFrom,
      );
    }
  }

  // ── Hareket yumuşatma & separation ────────────────────────────────────────

  void _tickPostMotion(double dt) {
    applySeparation(
      dt: dt,
      villagers: _villagers,
      cows: _cows,
      // _obstacles: su + maden + solid bina. Separation NPC'leri buraya
      // itmesin (eski "waterTiles" param adı geçici; pratikte tüm engeller).
      waterTiles: _obstacles,
    );

    // Hareket yumuşatma — renderX/Y ve moveIntensity.
    // AI'ın gridX/Y sıçramaları animasyona anlık değil, exp-lerp ile
    // yansır → donuk değil akıcı.
    for (final v in _villagers) {
      v.smoothMotion(dt);
    }

    // Meşale fade — köylüler gece dışarıda dolaşırken torch yansın.
    final dl = _cycle.dayLight;
    final rain = _cycle.rainIntensity;
    for (final v in _villagers) {
      v.tickTorch(dt, dl, rain);
    }

    // Ambient kuş sürüleri — gündüzleri 35-90s aralıkla bir kenardan girer,
    // karşıya uçar, off-grid olunca temizlenir. Etkileşim yok, pure atmosfer.
    if (_cycle.dayLight > 0.35) {
      _birdFlockSpawnTimer -= dt;
      if (_birdFlockSpawnTimer <= 0) {
        _birdFlocks.add(BirdFlock.spawnRandomEdge(_rng));
        _birdFlockSpawnTimer = 35.0 + _rng.nextDouble() * 55.0;
      }
    }
    for (final f in _birdFlocks) {
      f.update(dt);
    }
    _birdFlocks.removeWhere((f) => f.isDead);

    // Ambient göktaşı yağmuru — geri sayım gün boyu akar; süresi dolduğunda
    // yalnız gece (yıldızlar görünürken) tetiklenir. Karar yok: köylüler izler,
    // moral artar. Seyrek, özel bir cozy ödül.
    if (_hasFire) {
      _meteorShowerTimer -= dt;
      if (_meteorShowerTimer <= 0 && _cycle.dayLight < 0.28) {
        _startMeteorShower();
        _meteorShowerTimer = (5.0 + _rng.nextDouble() * 4.0) * kGameDaySeconds;
      }
    }

    // Sazlık yeniden büyür — biçilmiş kümeler su kenarında yavaşça olgunlaşır
    // (yenilenebilir kaynak). Birkaç küme, her frame ucuz.
    for (final r in _reeds) {
      r.tickRegrow(dt, kReedRegrowSeconds);
    }

    // Böğürtlen çalıları yeniden meyvelenir (kışın durur) — bkz. scene_forage.
    _tickBerryRegrow(dt);

    // Arı sürüleri — her kovana bağlı, kovan etrafında orbit. Kovan yaşadığı
    // sürece yaşar (spawn/teardown completion hook + rebuild'de). Pure atmosfer.
    for (final sw in _beeSwarms) {
      sw.update(dt);
    }

    _tickDecorCrush(
      dt,
    ); // üstüne basılan çiçek ezilip solar → popülasyon kendini seyreltir
  }

  /// Çiçek ezilme döngüsü — köylü/işçi bir çiçeğin üstünden geçince çiçek
  /// görünür biçimde yassılaşıp solar (crush animasyonu), bitince listeden
  /// çıkar. Çiçek popülasyonu böylece köyün yaşamıyla doğal olarak seyrelir;
  /// florist + çiçek bahçesi yeniden serper → denge. Sadece çiçekler ezilir
  /// (mantar/çalı/kütük değil). Hareket sonrası (post-motion) çalışır ki
  /// köylü pozisyonları güncel olsun.
  void _tickDecorCrush(double dt) {
    if (_decor.isEmpty) return;

    // Yeni ezilmeleri tetikle — her sağlam çiçeği tüm hareket eden köylülere
    // karşı yakınlık testinden geçir (ilk isabet yeter → early break).
    const double r2 = 0.40 * 0.40; // ~yarım tile: doğrudan basış
    for (final d in _decor) {
      if (d.crushed || !_isFlowerDecor(d.kind)) continue;
      if (_moverOnTile(d.col + 0.5, d.row + 0.5, r2)) d.startCrush();
    }

    // Animasyonu ilerlet + biten çiçekleri temizle (tickCrush true dönerse bitti).
    _decor.removeWhere((d) => d.tickCrush(dt));
  }

  /// Ekranda hareket eden herhangi bir köylü/işçi (cx,cy) merkezine r2
  /// (kare mesafe) içinde mi — çiçek ezilme tetiği. Tüm meslek listelerini
  /// tarar; ilk isabette döner.
  bool _moverOnTile(double cx, double cy, double r2) {
    bool near(double gx, double gy) {
      final dx = gx - cx;
      final dy = gy - cy;
      return dx * dx + dy * dy <= r2;
    }

    for (final v in _villagers) {
      if (near(v.gridX, v.gridY)) return true;
    }
    return false;
  }

  /// Ambient göktaşı yağmuru gösterisini başlatır — gökyüzü fx + uyumayan
  /// köylüler başını kaldırıp izler (🌠 bubble) + birkaçı ateşe toplanır +
  /// köy moralı artar. Karar/soru yok; saf bir cozy gece ödülü.
  void _startMeteorShower() {
    const dur = kGameDaySeconds * 0.35; // birkaç dakikalık gece gösterisi
    const e = EventEffect(fx: EventFx.meteorShower, duration: dur);
    _activeFx.add(ActiveFx(e, dur));
    addCameraShake(4, dur: 0.7); // hafif huşû titreşimi (juice)
    for (final v in _villagers) {
      if (v.isSleeping || v.isInsideBuilding) continue;
      // Baş üstünde 🌠 YOK. Hayranlık zaten GÖVDEDE var: `NpcEmotion.wonder`
      // köylüyü doğrultup yukarı kaldırıyor (bkz. game_drawables emoLift).
      // Baloncuk onun üstüne olayın ADINI yazıyordu — süresini duyguya
      // devrettik, gösteriyi izleyen kalabalık aynı süre boyunca doğrulmuş
      // durur.
      v.feel(NpcEmotion.wonder, 6 + _rng.nextDouble() * 4, moodDelta: 0.12);
    }
    _gatherAtFire(dur, max: 8);
    pushPolicyMorale(0.06, 2.0);
    _showNotification(
      '🌠 Gökyüzü göktaşı yağmuruyla doldu — köy başını kaldırıp izledi.',
    );
  }

  /// Decor türü bir çiçek mi — arı kovanı bal sinerjisi (menzildeki çiçek
  /// sayısı üretimi hızlandırır). Mantar/çalı/kütük çiçek sayılmaz.
  bool _isFlowerDecor(DecorKind k) =>
      k == DecorKind.daisy ||
      k == DecorKind.poppy ||
      k == DecorKind.lavender ||
      k == DecorKind.buttercup ||
      k == DecorKind.clover;

  /// Arı sürülerini mevcut kovanlardan türetir. Var olan sürüler pozisyona
  /// göre korunur (orbit state sıfırlanmaz); kaldırılan kovanın sürüsü düşer,
  /// yeni kovana taze sürü eklenir. Topology değişiminde çağrılır.
  void _rebuildBeeSwarms() {
    final kept = <BeeSwarm>[];
    for (final b in _buildings) {
      if (b.type != BuildingType.beehive) continue;
      final hx = b.col + 0.5;
      final hy = b.row + 0.5;
      BeeSwarm? existing;
      for (final s in _beeSwarms) {
        if ((s.hiveX - hx).abs() < 0.01 && (s.hiveY - hy).abs() < 0.01) {
          existing = s;
          break;
        }
      }
      kept.add(existing ?? BeeSwarm.spawn(hx, hy, _rng));
    }
    _beeSwarms
      ..clear()
      ..addAll(kept);
  }

  // ── Türetilmiş HUD sayımları + sosyal + objektif + snapshot ───────────────

  void _tickDerivedAndMeta(double dt) {
    // Otonom arazi açılımı — köy yer istedikçe ön-hat ağaçlarını işaretle
    // (içeride ~2sn throttle'lı; oduncu AI'sı keser, orman geri çekilir).
    _updateLandExpansion(dt);

    // Yaprak patlaması fx yaşlandır/temizle (devrilen ağaç juice'u).
    if (_leafBursts.isNotEmpty) {
      for (final lb in _leafBursts) {
        lb.age += dt;
      }
      _leafBursts.removeWhere((lb) => lb.dead);
    }

    // HUD "yolda" kaynak sayımları — tek geçiş (build içinde 5 ayrı
    // .where().length taraması yerine; her frame allocation'ı keser).
    _woodInTransit = _stoneInTransit = _ironInTransit = _coalInTransit = 0;
    for (final b in _resourceBoxes) {
      if (b.isDelivered) continue;
      switch (b.type) {
        case ResourceBoxType.woodChunk:
          _woodInTransit++;
        case ResourceBoxType.stoneBox:
          _stoneInTransit++;
        case ResourceBoxType.ironBox:
          _ironInTransit++;
        case ResourceBoxType.coalBox:
          _coalInTransit++;
      }
    }
    _foodInTransit = 0;
    for (final h in _hayEntities) {
      if (h.isBale && !h.isDelivered) _foodInTransit++;
    }

    // Işık kaynaklarını topla — her tick güncel. Throttle DENENDİ AMA GERİ
    // ALINDI: LightingSystem.collect içinde yağmur fade (fireRainFade),
    // NPC torch flicker (sin(time*4.3)), ve hareketli torch konumu
    // (renderX/Y) hepsi anlık değişir → 100ms cache yağmurda ateşi step-jump
    // ettiriyor, meşale glow'u NPC'den geri kalıyor. Görsel bug riskine
    // performans kazancı değmez (asıl kazanç repro throttle + spatial hash).
    _lightSources = LightingSystem.collect(
      buildings: _buildings,
      villagers: _villagers,
      dayLight: _cycle.dayLight,
      rainIntensity: _cycle.rainIntensity,
      time: _time,
    );

    // ── Sohbet baloncukları + iç dünya — sosyal/duygusal canlılık katmanı ──
    // Aktif baloncukları decay et + her NPC'nin mood/energy/emotion'ını ilerlet.
    final dl = _cycle.dayLight;
    for (final v in _villagers) {
      final resting =
          v.isSleeping ||
          v.activity == VillagerActivity.warm ||
          v.activity == VillagerActivity.listening;
      v.tickInnerLife(dt, dl, resting);
      if (v.waveTime > 0) v.waveTime -= dt; // selam jesti (bkz. CharGesture)
      if (v.chatBubbleTime > 0) {
        v.chatBubbleTime -= dt;
        if (v.chatBubbleTime <= 0) {
          v.chatBubbleIcon = '';
          if (v.convoIcons.isNotEmpty) v.clearConvo();
          // Anlatıcı hala oturuyorsa warm'a düş (story bitti, ısınıyor).
          v.activity = v.sitClaimed
              ? VillagerActivity.warm
              : VillagerActivity.none;
        }
      }
    }
    // Kişisel cooldown'lar her tick decay.
    for (final v in _villagers) {
      if (v.socialCooldown > 0) v.socialCooldown -= dt;
      if (v.conflictCooldown > 0) v.conflictCooldown -= dt;
    }
    // Hamam külhanları — bakım gereken biri varsa yakacak harcar; çatışma
    // ve hastalıktan ÖNCE ki ikisi de aynı aktiflik durumunu okusun.
    _tickBathhouseCare(dt);
    // Çekişme/kavga taraması — nadir, gerçekçi faktörlere bağlı.
    _tickConflicts(dt);
    // Suç — sinsi yaklaşma / eylem / kaçış + muhafız müdahalesi (aynı anda tek).
    _tickCrime(dt);
    // Gömülü zulalar — iz kapanır, üstüne basan bulur, mal ambara döner.
    _tickLoot(dt);
    // Kürek cezası — mahkûmları ocağa koşar, günlük taş ürettirir, salıverir.
    _tickConvictLabor(dt);
    // Hastalık & kırılganlık — nadir hastalık (çoğu iyileşir), yaşlı/kış ölüm riski.
    _tickIllness(dt);
    // İmparatorluk vergi heyeti — koşullu (zengin köy dikkat çeker).
    _tickImperial(dt);
    _socialScanTimer += dt;
    if (_socialScanTimer >= _VillageSceneState._kSocialScanInterval) {
      _socialScanTimer = 0;
      // Sohbet/müzik/dans taraması KALDIRILDI — artık YALNIZLIK dürtüsünden
      // doğan bir teklif ([_bidSocial], scene_mind). Eskiden bu tarama boştaki
      // herkese zar atıyordu; şimdi konuşma ihtiyacı olan konuşuyor.
    }
    // Saz yatağı döngüsü — evsizler sazlık biçip ateş etrafına yatak kurar.
    // Rutinden ÖNCE: yatak peşindeki evsizi sahiplenip rutinden korur.
    _tickReed(dt);
    _tickWork(dt); // meslek iş döngüleri (çoban/avcı/değirmenci/hancı/rahip)
    _tickWeaponCraft(dt);
    // Kanunname kapıları — köyün hâli değiştikçe deftere yeni hüküm düşer.
    _tickLawGates(dt);
    // Rejim — huzursuzluk birikimi + rejime özgü kriz (kimliğin bedeli).
    _tickRegime(dt);
    // KÖYÜN HÂLİ — yasa/rejim/mevsim/huzursuzluk tek davranış tablosuna iner,
    // tablo köylülere işlenir. Rejimden SONRA gelmeli: aynı karede biriken
    // huzursuzluk aynı karede sokağa yansısın.
    _tickPressure(dt);
    // ALGI — hafızalar söner, ölüm tanıklıkları yakalanır. Akıldan ÖNCE:
    // gördüğü şey aynı karede kararına girsin.
    _tickPerception(dt);
    // KÖYLÜNÜN AKLI — dürtüler beslenir, teklifler tartılır, niyet seçilir.
    // Basınçtan SONRA, yürütücü sistemlerden ÖNCE: kararı aynı karede
    // yürütecek sistemler (iş/saz/suç) hemen görsün.
    _tickMind(dt);
    // İHBAR — muhafıza koşan tanık yolunu tamamlar.
    _tickInforming(dt);
    // EYLEMLER — varış noktalarındaki mikro-sahneler (kova doldur, sepetle
    // dön, maşrapa kaldır). Akıldan SONRA: aynı karede kurulan sahne hemen
    // ilk adımını atsın.
    _tickActs(dt);
    // PROVA — harness açıksa köyün davranış özetini periyodik üret.
    if (kProbeOn) _tickProbe(dt);
    // Kilometre taşları — nüfus eşikleri (bir kez tatlı bildirim).
    _tickAchievements();
    // Bireysel yaşam öyküsü — evre geçişlerini (reşit oluş/yaşlanma) yakala.
    _tickLifeStory(dt);
    // Amaçlı hedef akışı — boşalan köylülere zamana/ihtiyaca göre POI ata.
    _tickRoutine(dt);
    // Ateş başı toplanma + hikaye saati taramaları.
    _tickFirepitGather(dt);
    // Ateş yakıtı — tükeniş, ateşçi odun taşıma, sönme/yeniden yanma.
    _tickFire(dt);
    // Çadır ↔ ocak — kışın ateşten uzak çadırda üşüyen köylüyü geceleyin kaldırır.
    _tickShelter(dt);
    _tickPetitions(dt);
    // Düğün yaşam döngüsü — gerçek çift kur yapar → çifte bağlı düğün dilekçesi.
    _tickWedding(dt);
    _tickHousePressure(dt);
    _tickHouseIntrigue(
      dt,
    ); // haneler karşılık verir (ittifak/gizleme/kışkırtma) // hane baskı sayacı sönümlenir (eylem bedeli normale döner)
    // Zümre dengesi — moral tabana süzülür + küskün zümre diegetik somurtma.
    _tickEstates(dt);
    // HANE KARŞILIĞI — hane elini/ürününü/masasını geri çeker ya da geri verir.
    // _tickEstates'ten SONRA: duruş o tick'te güncellenmiş mood'dan türer.
    if (_stashOpenedCd > 0) _stashOpenedCd -= dt;
    _tickHouseStance(dt);
    // KAYBETME EŞİĞİ — ayrılık sayacı + köyün ayakta kalabilirliği. Hane
    // katmanından SONRA: ayrılık kopuş duruşundan, dağılma da ayrılıktan doğar.
    _tickCollapse(dt);
    // HESAPLAŞMA — koşunun kazanılabilir kapanışı. Dağılmadan SONRA: köy zaten
    // dağıldıysa berat konuşmaz (kapanmış defterin üstüne ikinci kapanış).
    _tickReckoning(dt);

    // Köy Akışı — görev tamamlanması → görsel ödül + politika-odaklı kademe.
    _tickFlow(dt);
    // KIŞ — kırkım/dokuma/giysi dağıtımı + ev ocaklarının yakacağı + hazırlık
    // uyarısı. Kendi içinde saniyelik taramaya iner (gün başına muhasebe).
    _tickWinter(dt);
    // ORTA OYUN DERSLERİ — kuruluştan sonra açılan sistemlerin öğretmeni.
    // _tickGuide'dan ÖNCE: ders penceresi kuruluş öğreticisinin açık olup
    // olmadığına bakıyor, o bayrak bu karede güncellenmeden okunmalı ki iki
    // anlatım aynı karede birden açılmasın.
    _tickLessons(dt);
    // Kuruluş öğreticisi — adımı ekranda GÖSTEREN spot (yalnız kademe 0).
    // _tickFlow'dan SONRA: adım cache'i bu karede tazelenmiş olsun, spot bir
    // tarama geriden gelmesin.
    _tickGuide(dt);

    // Denge testi snapshot'u — 5 sn'de bir kaynak/nüfus kaydı.
    _simSnapshotTimer += dt;
    if (_simSnapshotTimer >= _VillageSceneState._kSnapshotInterval) {
      _simSnapshotTimer = 0;
      _simHistory.add(
        SimSnapshot(
          simTime: _time,
          day: _dayCount,
          population: _villagers.length,
          buildings: _buildings.length,
          wood: _stockpile.wood,
          stone: _stockpile.stone,
          iron: _stockpile.iron,
          coal: _stockpile.coal,
          food: _stockpile.food,
          gold: _stockpile.gold,
        ),
      );
      if (_simHistory.length > _VillageSceneState._kMaxSnapshots) {
        _simHistory.removeAt(0);
      }
    }

    // ── Olay vinyeti ────────────────────────────────────────────────────────
    // Adımları _tickActs yürütür; burası sahnenin ÖMRÜNÜ ve kadronun
    // salıverilmesini bekler (ceremony önceliği başka türlü düşmez).
    _tickVignette(dt);

    // ── Kamera takibi ───────────────────────────────────────────────────────
    // Köylü kartından "Takip et" açılırsa kamera her tick NPC merkezine
    // yumuşak çekilir. NPC eve girince/uyuyunca/silinince takip otomatik düşer.
    _tickCameraFollow(dt);
    // "İzle" — olay vinyetinin odağına yumuşak kayış (takipten AYRI kanal).
    _tickWatchCamera(dt);
  }

  /// İZLE KAMERASI — vinyetin odağını kadraja alır.
  ///
  /// Takipten (`_followedVillager`) bilerek ayrı: takip bir GÖVDEYE demirler ve
  /// süresizdir; izle bir SAHNEYE bakar ve kendiliğinden bırakır. Zoom'a
  /// dokunmaz — oyuncunun kurduğu yakınlık onun kararıdır.
  void _tickWatchCamera(double dt) {
    if (_watchLeft <= 0) return;
    _watchLeft -= dt;
    if (_viewSize.width <= 0 || _viewSize.height <= 0) return;
    final targetX = -(_watchX - _watchY) * kTileW / 2;
    final targetY = _viewSize.height * 0.22 - (_watchX + _watchY) * kTileH / 2;
    // Takipten daha yumuşak (3.0 vs 4.0): sahneye "atlamak" değil, kaymak.
    final lerpT = (1.0 - 1.0 / (1.0 + 3.0 * dt)).clamp(0.0, 1.0);
    _camera = Offset.lerp(_camera, Offset(targetX, targetY), lerpT) ?? _camera;
    _clampCamera(_viewSize);
  }

  void _tickCameraFollow(double dt) {
    final v = _followedVillager;
    if (v == null) return;
    // İçeride/listede yoksa takibi düşür.
    if (v.isInsideBuilding || !_villagers.contains(v)) {
      _followedVillager = null;
      return;
    }
    if (_viewSize.width <= 0 || _viewSize.height <= 0) return;
    // gridToScreen'i ekran merkezine sabitleyecek camera offset (zoom pivot
    // ekran merkezi olduğu için zoom değerinden bağımsız çalışır).
    final targetX = -(v.gridX - v.gridY) * kTileW / 2;
    final targetY = _viewSize.height * 0.22 - (v.gridX + v.gridY) * kTileH / 2;
    // Smooth yakınsama — dt'ye duyarlı (low/high fps fark etmez).
    final lerpT = (1.0 - 1.0 / (1.0 + 4.0 * dt)).clamp(0.0, 1.0);
    _camera = Offset.lerp(_camera, Offset(targetX, targetY), lerpT) ?? _camera;
  }

  // ── Doğal doğum ───────────────────────────────────────────────────────────
  // Fertility timer'ı dolan kadınlar için partner + boş yatak kontrol.
  // chill-gameplay: food cost yok. Partner: aynı homeBuilding'de yaşayan
  // yetişkin erkek (yaşlı değil, kan bağı YOK — parent/child/sibling değil).
  void _tickReproduction() {
    if (_godMode == false && _villagers.isEmpty) return;

    // PROVA: harness doğum yolunu zorluyorsa yatak + sayaç kapılarını bu tarama
    // boyunca atla (bkz. [kProbeForceBirth]). Tek tüketimlik.
    final forced = kProbeForceBirth;
    if (forced) {
      kProbeForceBirth = false;
      for (final v in _villagers) {
        if (!v.isMale && v.lifeStage == LifeStage.adult) v.fertilityDays = 0;
      }
    }

    // Köyde boş yatak var mı? Yoksa hiç doğum olmaz.
    if (!forced && _freeHousingSlots() <= 0) return;

    // Ev → adult erkekler index (couple search için tek pass). Eski O(n²)
    // versiyon her hazır mother için tüm villager'ı tarıyordu.
    Map<Object, List<VillagerEntity>>? maleByHome;

    // Doğanları BİRİKTİR, döngüden SONRA doğur — `_spawnBabyFromParents`
    // `_villagers.add` yapıyor; liste üstünde iterasyon sürerken eklemek
    // ConcurrentModificationError atar (hayvan tarafında aynı bug düzeltilmiş,
    // bkz. `_tickAnimalReproduction`; köylü tarafı atlanmıştı → HER doğum
    // tick'in geri kalanını -iş dağıtımı, tarla büyümesi, göç- düşürüyordu).
    final pending = <(VillagerEntity, VillagerEntity)>[];

    // Mevcut adult kadınlar üzerinden geçiyoruz. Bir tick'te birden fazla
    // doğum mümkün ama her doğum housing slot tüketir → kapasite zinciri
    // doğal sınır.
    for (final mother in _villagers) {
      // NaN = eligible değil, > 0 = hâlâ counting → atla; ≤ 0 = hazır.
      if (mother.fertilityDays.isNaN || mother.fertilityDays > 0) continue;
      // Aile planlaması sınırı aşıldıysa fertility frozen.
      if (mother.birthCount >= _policies.maxChildren) {
        mother.fertilityDays = double.nan;
        continue;
      }
      final home = mother.homeBuilding;
      if (home == null) continue;

      // Index lazy-build — sadece ilk hazır mother'da bir kez.
      if (maleByHome == null) {
        maleByHome = {};
        for (final v in _villagers) {
          if (!v.isMale || v.lifeStage != LifeStage.adult) continue;
          final h = v.homeBuilding;
          if (h == null) continue;
          (maleByHome[h] ??= []).add(v);
        }
      }

      // Partner ara — aynı evdeki erkekler arasında kan bağı olmayan.
      VillagerEntity? father;
      final mates = maleByHome[home];
      if (mates != null) {
        Set<VillagerEntity>? motherParents;
        for (final cand in mates) {
          if (identical(cand, mother)) continue;
          if (mother.parents.contains(cand)) continue;
          if (mother.children.contains(cand)) continue;
          motherParents ??= mother.parents.toSet();
          final shareParent = cand.parents.any(motherParents.contains);
          if (shareParent) continue;
          father = cand;
          break;
        }
      }

      if (father == null) {
        // Partner yok — kısa süre sonra tekrar dene (her tick scan etmemek için)
        mother.fertilityDays = 0.5 + _rng.nextDouble() * 0.8;
        continue;
      }

      // Free housing check tekrar — bu tick'te SIRAYA GİREN doğumlar da yer
      // tüketir. (`_freeHousingSlots` `b.occupants`'ı okur, o da yalnız tick
      // başında tazelenir → `pending` düşülmezse aynı boş yatağa iki bebek
      // doğardı. Eskiden de öyleydi; kuyruk bunu görünür kıldı.)
      if (!forced && _freeHousingSlots() - pending.length <= 0) break;

      pending.add((mother, father));
      // Post-partum cooldown: aile teşviki açıksa yarıya iner.
      final base = _policies.familyEncouragement ? 2.5 : 5.0;
      final span = _policies.familyEncouragement ? 1.5 : 4.0;
      mother.fertilityDays = base + _rng.nextDouble() * span;
    }

    for (final (mother, father) in pending) {
      _spawnBabyFromParents(mother, father);
    }
  }

  // ── Hayvan üremesi (çift bazlı, köylü deseninin aynası) ────────────────────
  // Aynı ağıl + aynı tür: fertility'si dolan yetişkin dişi + en az bir yetişkin
  // erkek varsa yavru doğar. Kapasite (ağıl başına tür limiti) doğal tavan.
  // chill-gameplay: kaynak maliyeti yok. "Sürü Büyütme" politikası kapalıysa
  // üreme durur (meclis kararı).
  static const Map<AnimalKind, int> _herdCapPerBarn = {
    AnimalKind.cow: 5,
    AnimalKind.sheep: 5,
    AnimalKind.chicken: 6,
  };

  void _tickAnimalReproduction() {
    if (!_policies.herdGrowth) return;
    if (_cows.isEmpty) return;

    // Ağıl+tür başına: canlı sayım + en az bir yetişkin erkek var mı?
    final counts = <(int, int, AnimalKind), int>{};
    final hasMale = <(int, int, AnimalKind), bool>{};
    for (final a in _cows) {
      if (a.isDying) continue;
      final key = (a.barnCol, a.barnRow, a.kind);
      counts[key] = (counts[key] ?? 0) + 1;
      if (a.isMale && a.isAdult) hasMale[key] = true;
    }

    // Doğanları BİRİKTİR, döngüden SONRA ekle. `_cows` üstünde iterasyon
    // yaparken `_cows.add` çağırmak ConcurrentModificationError atar —
    // hızlandırılmış simülasyonda (birden çok doğum aynı tick'te) düzenli
    // olarak çöktürüyordu (prova testi yakaladı).
    final newborns = <AnimalEntity>[];
    for (final mother in _cows) {
      if (mother.isMale || mother.isDying) continue;
      if (mother.fertilityDays.isNaN || mother.fertilityDays > 0) continue;
      if (mother.lifeStage != AnimalLifeStage.adult) continue;
      final key = (mother.barnCol, mother.barnRow, mother.kind);
      if (hasMale[key] != true) {
        // Erkek yok — kısa süre sonra tekrar dene (her tick taramamak için).
        mother.fertilityDays = 0.5 + _rng.nextDouble() * 0.8;
        continue;
      }
      final cap = _herdCapPerBarn[mother.kind] ?? 5;
      if ((counts[key] ?? 0) >= cap) {
        // Ağıl dolu — bekle, yer açılınca (ölüm) tekrar dener.
        mother.fertilityDays = 1.0 + _rng.nextDouble() * 1.0;
        continue;
      }

      // Yavru doğar — annenin yanında, ageDays=0 (yavru evresi).
      final jx = (_rng.nextDouble() - 0.5) * 0.5;
      final jy = (_rng.nextDouble() - 0.5) * 0.5;
      newborns.add(
        AnimalEntity(
          kind: mother.kind,
          barnCol: mother.barnCol,
          barnRow: mother.barnRow,
          startCol: mother.gridX + jx,
          startRow: mother.gridY + jy,
          isMale: _rng.nextBool(),
          ageDays: 0.0,
          lifespanDays:
              AnimalEntity.kAnimalElderDay + 8.0 + _rng.nextDouble() * 12.0,
        ),
      );
      counts[key] = (counts[key] ?? 0) + 1;
      _animalBirthsPending++;
      // Doğum sonrası bekleme: aile teşviki açıksa hayvanlar da hızlı çoğalır.
      final base = _policies.familyEncouragement ? 3.0 : 5.0;
      mother.fertilityDays = base + _rng.nextDouble() * 4.0;
    }
    _cows.addAll(newborns);
  }

  // ── Yumurta döngüsü ─────────────────────────────────────────────────────────
  // Kümeste yetişkin DİŞİ tavuk varken periyodik GÖRÜNÜR yumurta bırakılır.
  // Yumurta bir süre yerde durur, sonra çözülür: toplanır → +1 food, ya da
  // (şans + kapasite varsa) çatlar → civciv. Görsel + yaşayan döngü.
  static const double _kEggHatchChance = 0.30;
  static const double _kEggCollectTime = 7.0; // toplanma süresi (sn)
  static const double _kEggHatchTime = 16.0; // çatlama süresi (sn)
  static const int _kMaxEggsPerCoop = 3; // yerde biriken yumurta tavanı

  void _tickEggs(double dt) {
    final chickenCap = kAnimalBarnCap[AnimalKind.chicken] ?? 6;

    // Yumurtlama — her kümes için.
    for (final b in _buildings) {
      if (b.type != BuildingType.chickenCoop) continue;
      AnimalEntity? hen;
      for (final c in _cows) {
        if (c.kind == AnimalKind.chicken &&
            !c.isMale &&
            c.isAdult &&
            !c.isDying &&
            c.barnCol == b.col &&
            c.barnRow == b.row) {
          hen = c;
          break;
        }
      }
      if (hen == null) continue; // yetişkin dişi yoksa yumurtlama
      final eggsHere = _eggs
          .where((e) => e.barnCol == b.col && e.barnRow == b.row)
          .length;
      if (eggsHere >= _kMaxEggsPerCoop) continue; // yer doldu, bekle
      b.eggTimer += dt;
      if (b.eggTimer >= kEggInterval) {
        b.eggTimer = 0.0;
        final chickens = _cows
            .where(
              (c) =>
                  c.kind == AnimalKind.chicken &&
                  !c.isDying &&
                  c.barnCol == b.col &&
                  c.barnRow == b.row,
            )
            .length;
        final willHatch =
            chickens < chickenCap && _rng.nextDouble() < _kEggHatchChance;
        _eggs.add(
          EggEntity(
            barnCol: b.col,
            barnRow: b.row,
            gridX: hen.gridX,
            gridY: hen.gridY,
            spawnTime: _time,
            willHatch: willHatch,
            resolveAt: willHatch ? _kEggHatchTime : _kEggCollectTime,
          ),
        );
      }
    }

    if (_eggs.isEmpty) return;
    // Yaşlandır + çözümle.
    for (final e in _eggs) {
      e.age += dt;
    }
    final resolved = <EggEntity>[];
    _eggs.removeWhere((e) {
      if (!e.resolved) return false;
      resolved.add(e);
      return true;
    });
    for (final e in resolved) {
      if (e.willHatch) {
        final chickens = _cows
            .where(
              (c) =>
                  c.kind == AnimalKind.chicken &&
                  !c.isDying &&
                  c.barnCol == e.barnCol &&
                  c.barnRow == e.barnRow,
            )
            .length;
        if (chickens < chickenCap) {
          _cows.add(
            AnimalEntity(
              kind: AnimalKind.chicken,
              barnCol: e.barnCol,
              barnRow: e.barnRow,
              startCol: e.gridX,
              startRow: e.gridY,
              isMale: _rng.nextBool(),
              ageDays: 0.0,
              lifespanDays:
                  AnimalEntity.kAnimalElderDay + 8.0 + _rng.nextDouble() * 12.0,
            ),
          );
          _animalBirthsPending++;
          AudioManager.instance.playSfx(Sfx.chickenCluck);
        } else {
          _stockpile.food += 1; // kapasite doldu → yumurta sofraya
        }
      } else {
        _stockpile.food += 1; // toplandı
      }
    }
  }

  /// Misafirperverlik politikası açıkken periyodik gezgin spawn'ı. Boş ev
  /// gerekir. Timer 3-6 oyun günü randomize, spawn olunca yeniden roll.
  /// Policy kapalıyken timer dondurulur.
  void _tickMigration(double dt) {
    // DIŞARIYA NİKÂH FERMANI — açık kapıdan bağımsız, kendi yavaş kanalı.
    // Açık Kapı rastgele bir yabancı getirir; bu ferman YALNIZ kalmış birine eş
    // getirir ve gelen kendi adıyla yeni bir hane kurar (bkz.
    // _spawnMarriageMigrant). İki kanal ayrı çünkü iki farklı şey vaat ediyorlar.
    _tickMarriageMigration(dt);

    if (!_policies.hospitality) {
      _migrationTimerSec = 0; // kapalıyken sıfırla, yeniden açılınca fresh roll
      return;
    }
    if (_migrationTimerSec <= 0) {
      _migrationTimerSec = (3.0 + _rng.nextDouble() * 3.0) * kGameDaySeconds;
    }
    _migrationTimerSec -= dt;
    if (_migrationTimerSec > 0) return;
    if (_freeHousingSlots() <= 0) {
      // Yatak yoksa kısa retry
      _migrationTimerSec = 0.5 * kGameDaySeconds;
      return;
    }
    _spawnMigrant();
    _migrationTimerSec = (3.0 + _rng.nextDouble() * 3.0) * kGameDaySeconds;
  }

  /// Nikâh göçü — Açık Kapı'dan belirgin YAVAŞ (5-9 gün). Eş bulmak bir akın
  /// değil, tek tek olan bir şey; ferman köyü göçmenle doldurmasın.
  /// Uygun yalnız yoksa denemeden bekler (boşa timer yakmaz).
  void _tickMarriageMigration(double dt) {
    if (!_policies.outsideMarriage) {
      _marriageMigrationSec = 0;
      return;
    }
    if (_marriageMigrationSec <= 0) {
      _marriageMigrationSec = (5.0 + _rng.nextDouble() * 4.0) * kGameDaySeconds;
    }
    _marriageMigrationSec -= dt;
    if (_marriageMigrationSec > 0) return;
    // Denedi; olmadıysa kısa retry (yalnız biri sonra ortaya çıkabilir).
    _marriageMigrationSec = _spawnMarriageMigrant()
        ? (5.0 + _rng.nextDouble() * 4.0) * kGameDaySeconds
        : 1.0 * kGameDaySeconds;
  }

  // ── Komşuluk: NPC'ler birbirine selam verir ──────────────────────────────
  // 1.2s aralıkla poll; her villager için yakındaki bir uygun komşu varsa
  // %25 ihtimal selam (el sallama jesti + glance). Per-villager greet cooldown
  // (8-14s) spam'ı engeller.
  // Spatial hash (2-tile bucket): O(n²) yerine O(n). Search radius 1.6 tile
  // → 3×3 komşu bucket araması yeterli. Bucket map reused across polls.
  void _tickNeighborGreet(double dt) {
    // Selamlaşma HER ZAMAN açık (düşük taban) — sokakta yan yana geçen köylüler
    // sessizce yürümesin. "Komşuluk" politikası bunu yalnız SICAKLAŞTIRIR
    // (aşağıda oran), bir anahtar değil (eskiden politikasız hiç selam yoktu →
    // köy ölü hissediyordu).
    _greetPollSec -= dt;
    if (_greetPollSec > 0) return;
    _greetPollSec = 1.2;

    // Bucket grid — 2-tile cell, eligible villager indekslerini gruplar.
    _greetBuckets.clear();
    for (int i = 0; i < _villagers.length; i++) {
      final v = _villagers[i];
      // Çocuklar da selamlaşır (el sallar) — köyün sokakları çocuklu canlanır.
      if (v.chatBubbleTime > 0) continue;
      if (v.greetCooldown > 0) continue;
      final key = (v.gridX.floor() ~/ 2, v.gridY.floor() ~/ 2);
      (_greetBuckets[key] ??= []).add(i);
    }

    for (final v in _villagers) {
      if (v.chatBubbleTime > 0) continue;
      if (v.greetCooldown > 0) {
        v.greetCooldown -= 1.2;
        continue;
      }
      // Taban her zaman açık; komşuluk politikası selamı sıklaştırır.
      final greetChance = _policies.neighborliness ? 0.40 : 0.18;
      if (_rng.nextDouble() > greetChance) continue;

      // En yakın uygun komşu — 1.6 tile içinde, 3×3 komşu bucket'tan ara.
      VillagerEntity? near;
      double bestD = 2.56; // 1.6²
      final bx = v.gridX.floor() ~/ 2;
      final by = v.gridY.floor() ~/ 2;
      for (int dx = -1; dx <= 1; dx++) {
        for (int dy = -1; dy <= 1; dy++) {
          final neighbors = _greetBuckets[(bx + dx, by + dy)];
          if (neighbors == null) continue;
          for (final j in neighbors) {
            final o = _villagers[j];
            if (identical(o, v)) continue;
            // Küs olanlar / kan düşmanları birbirini selamlamaz (soğuk omuz).
            if (v.hasGrudgeWith(o, _time) || v.isBloodEnemy(o)) continue;
            final ddx = v.gridX - o.gridX;
            final ddy = v.gridY - o.gridY;
            final d2 = ddx * ddx + ddy * ddy;
            if (d2 < bestD) {
              bestD = d2;
              near = o;
            }
          }
        }
      }
      if (near == null) continue;

      // Karşılıklı selam — GÖVDEDE: ikisi de elini kaldırıp sallar, birbirine
      // bakar, ikisi de cooldown'a girer. Baş üstünde ikon YOK (bkz.
      // CharGesture.wave); selamı anlatan şey kolun kendisidir.
      v.waveTime = VillagerEntity.kWaveDuration;
      near.waveTime = VillagerEntity.kWaveDuration;
      v.greetCooldown = 8.0 + _rng.nextDouble() * 6.0;
      near.greetCooldown = 8.0 + _rng.nextDouble() * 6.0;
      v.glanceAround(duration: 0.7);
      near.glanceAround(duration: 0.7);
      v.feel(NpcEmotion.content, 1.6, moodDelta: 0.03);
      near.feel(NpcEmotion.content, 1.6, moodDelta: 0.03);
    }
  }

  // ── Çocuk oyunu: yakın iki çocuk birlikte oynar ─────────────────────────────
  // Çocuklar meslek/ateş/sohbet sistemlerinin dışındaydı — eskiden yalnız sessiz
  // koşuşturuyorlardı (envanterin işaret ettiği "köyün en ölü noktası"). Burada
  // iki çocuk yan yana geldiğinde kısa, neşeli bir oyun başlar: biri diğerine
  // koşar (kovalamaca), ikisi de sevinçle zıplar. Kanıtlanmış selamlaşma
  // deseninin çocuk sürümü; aktivite kilidi onları hakemden korur, süre bitince
  // (scene_tick baloncuk decay) activity none'a döner, wander devam eder.
  void _tickChildPlay(double dt) {
    _childPlayPollSec -= dt;
    if (_childPlayPollSec > 0) return;
    _childPlayPollSec = 1.5;
    if (_cycle.dayLight < 0.35) return; // oyun gündüz olur
    if (_cycle.rainIntensity > 0.4) return; // yağmurda içeri

    bool eligible(VillagerEntity c) =>
        c.lifeStage == LifeStage.child &&
        !c.isDying &&
        !c.isSleeping &&
        !c.isInsideBuilding &&
        c.activity == VillagerActivity.none &&
        c.chatBubbleTime <= 0 &&
        c.socialCooldown <= 0;

    // Çocuklar az → düz O(n²) yeterli (bucket grid'e gerek yok).
    for (int i = 0; i < _villagers.length; i++) {
      final a = _villagers[i];
      if (!eligible(a)) continue;
      for (int j = i + 1; j < _villagers.length; j++) {
        final b = _villagers[j];
        if (!eligible(b)) continue;
        final dx = a.gridX - b.gridX, dy = a.gridY - b.gridY;
        if (dx * dx + dy * dy > 2.2 * 2.2) continue; // yeterince yakın değil
        _startChildPlay(a, b);
        break; // a eşleşti → sonraki çocuğa geç
      }
    }
  }

  void _startChildPlay(VillagerEntity a, VillagerEntity b) {
    final dur = 3.5 + _rng.nextDouble() * 2.5;
    for (final c in [a, b]) {
      c.activity = VillagerActivity.playing;
      c.chatBubbleTime = dur;
      c.chatBubbleIcon = ''; // baş-üstü ikon YOK — oyun gövde diliyle okunur
      c.socialCooldown = 12 + _rng.nextDouble() * 10;
      c.feel(
        NpcEmotion.joy,
        dur,
        moodDelta: 0.05,
      ); // neşeli zıplama (emoBounce)
    }
    // Biri diğerine koşar (kovalamaca hissi); öteki yerinde neşeyle zıplar.
    final chaser = _rng.nextBool() ? a : b;
    final quarry = identical(chaser, a) ? b : a;
    chaser.facingRight = quarry.gridX >= chaser.gridX;
    quarry.facingRight = chaser.gridX >= quarry.gridX;
    chaser.goTo(quarry.gridX, quarry.gridY, 0);
  }

  // ── Aile birleşimi: solo yetişkinleri eşleştir ──────────────────────────
  // Bekar yetişkin (ev'inde zıt cinsiyetli yetişkin yok) iki kişiyi
  // birleştirir: birini diğerinin evine taşır (yatak boş olanına). Tetik
  // periyodik (~15s) — agresif değil, organik.
  // Optim: ev → yetişkin listesi index tek pass. Eski versiyon O(n²) iki kez
  // (her single check ev sakinlerini tekrar tarıyordu); şimdi O(n).
  void _tickFamilyReunion(double dt) {
    if (!_policies.familyReunion) return;
    _reunionPollSec -= dt;
    if (_reunionPollSec > 0) return;
    _reunionPollSec = 15.0;

    // Ev → yetişkin sakinler index (single pass).
    final adultsByHome = <Object, List<VillagerEntity>>{};
    for (final v in _villagers) {
      if (v.lifeStage != LifeStage.adult) continue;
      final h = v.homeBuilding;
      if (h == null) continue;
      (adultsByHome[h] ??= []).add(v);
    }

    // Bekar = ev'inde uygun partner (zıt cins + kan bağı yok) bulunmayan
    // yetişkin. Index üstünden kontrol → tek pass.
    bool isSingle(VillagerEntity p) {
      final mates = adultsByHome[p.homeBuilding];
      if (mates == null) return false;
      for (final c in mates) {
        if (identical(c, p)) continue;
        if (c.isMale == p.isMale) continue;
        if (p.parents.contains(c) || p.children.contains(c)) continue;
        final shareParent = c.parents.any(p.parents.toSet().contains);
        if (!shareParent) return false; // uygun partner var
      }
      return true;
    }

    final singleW = <VillagerEntity>[];
    final singleM = <VillagerEntity>[];
    for (final v in _villagers) {
      if (v.lifeStage != LifeStage.adult || v.homeBuilding == null) continue;
      if (!isSingle(v)) continue;
      (v.isMale ? singleM : singleW).add(v);
    }
    if (singleW.isEmpty || singleM.isEmpty) return;

    singleW.shuffle(_rng);
    singleM.shuffle(_rng);
    final w = singleW.first;
    final m = singleM.first;

    // Hangi evde yatak var? Index'ten occupancy direkt.
    BuildingEntity? targetHome;
    for (final cand in [w.homeBuilding, m.homeBuilding]) {
      if (cand == null) continue;
      final b = cand as BuildingEntity;
      final f = b.fn;
      if (f == null) continue;
      final occ = adultsByHome[b]?.length ?? 0;
      if (occ < f.housingCapacity) {
        targetHome = b;
        break;
      }
    }
    if (targetHome == null) return; // her iki ev de dolu — başka tur

    // Taşı: hangisi targetHome'da değilse onu oraya geçir.
    if (w.homeBuilding != targetHome) w.homeBuilding = targetHome;
    if (m.homeBuilding != targetHome) m.homeBuilding = targetHome;
    // Aile birleşim ödülü — köy 5 gün boyunca +%2 moral hisseder.
    pushPolicyMorale(0.02, 5.0);
    _showNotification('💞 ${w.name} & ${m.name} aile kurdu.');
  }

  // ── Ambarsız hasat uyarısı ─────────────────────────────────────────────
  // Balya ancak AMBARA taşınır (carrier_system). Ambar yoksa hasat harmanda
  // yığılır, tarla dönüyor ama stoğa tek yiyecek girmiyor — ve oyuncu bunu
  // hiçbir yerden anlayamıyordu. 2 balya biriktiyse ~45 sn'de bir söyle.
  void _tickBaleStallWarning(double dt) {
    if (_baleStallWarnCd > 0) _baleStallWarnCd -= dt;
    if (_anchorSystem.warehousePoints.isNotEmpty) return;
    if (_baleStallWarnCd > 0) return;
    var bales = 0;
    for (final h in _hayEntities) {
      if (h.isBale && !h.isDelivered) bales++;
    }
    if (bales < 2) return;
    _baleStallWarnCd = 45.0;
    _showNotification(
      '🌾 Balyalar harmanda bekliyor — ambar olmadan '
      'hasat ambara girmiyor.',
    );
  }

  // ── Saha eli kadrosu ───────────────────────────────────────────────────
  // Tarla artık kendi çiftçisini DOĞURMAZ (kullanıcı kararı). Saha eli
  // (FarmFarmer) sayısı bir hedefe uzlaştırılır:
  //   taban = köyün yaşayan çiftçi-meslekli köylü sayısı (kişilik çağrısı)
  //         + Ekin Seferberliği Fermanı açıksa kFarmLaborPolicyBonus
  //   hedef = min(taban, tarlanın ihtiyacı)   // toprak+emek İKİSİ de şart
  // Böylece boş tarla çizmek bedava emek vermez; çok çiftçi de tarlasız
  // ortada gezmez. Hedef düşerse fazla saha eli (boştakiler önce) çekilir.
  int _farmLaborSupply() {
    var farmers = 0;
    for (final v in _villagers) {
      if (v.isDying) continue;
      if (v.type == VillagerType.farmer && v.hasProfession) farmers++;
    }
    if (_policies.farmLabor) farmers += kFarmLaborPolicyBonus;
    return farmers;
  }

  int _farmWorkforceTarget() {
    if (_farmTiles.isEmpty) return 0;
    final landNeed = (_farmTiles.length / kTilesPerFarmer).ceil().clamp(
      1,
      kMaxFarmers,
    );
    return _farmLaborSupply().clamp(0, landNeed);
  }

  // (Çiftçi kadrosu artık _syncJobWorkforce ile — gerçek köylüler atanır;
  // eski FarmFarmer avatar spawn/çek döngüsü kaldırıldı. _farmWorkforceTarget
  // yukarıda korunur, generic sync onu kullanır.)

  // ── Müşterek hasat: dengeleme (iki yönlü) ──────────────────────────────
  // Geride kalan tarla +%50 hızlanır, ileri olan geri çekilir. Toplam çıktı
  // korunur ama eş zamanlı olgunlaşma → bedel: hızlı tarla öne çıkamaz,
  // oyuncu agresif sulamayla farkı açamaz.
  //
  // İki tuzak (ikisi de bir zamanlar bug'dı):
  //   • Donmuş tarlada çalışmaz — kışın isGrowing hâlâ true (stage<4), yoksa
  //     ekin kar altında geri sarardı.
  //   • İtme t.update() ile YAPILMAZ — o su sayacını/nadası da tüketirdi.
  //     nudgeGrowth() sadece progress'e dokunur.
  void _tickSharedHarvest(double dt) {
    if (!_policies.sharedHarvest) return;
    if (_farmTiles.isEmpty) return;
    if (_season.isFrozen) return;

    double sum = 0;
    int n = 0;
    for (final t in _farmTiles) {
      if (!t.isGrowing) continue;
      sum += t.growthProgress;
      n++;
    }
    if (n == 0) return;
    final avg = sum / n;
    // update()'in aynı karede eklediği artışın yarısı kadar kanca.
    final unit =
        dt *
        _fxFarmMul *
        0.5 *
        _season.growthMultiplier /
        FarmTile.growthTimePerStage;
    for (final t in _farmTiles) {
      if (!t.isGrowing) continue;
      if (t.growthProgress < avg - 0.10) {
        t.nudgeGrowth(unit); // geride kalan +%50
      } else if (t.growthProgress > avg + 0.10) {
        t.nudgeGrowth(-unit); // öne geçen frenlenir
      }
    }
  }

  // ── Bilge yaşlı: random event ───────────────────────────────────────────
  // Koşullar: 2+ yaşlı yaşıyor, mevcut bilge yok. Her ~60s'de düşük şansla
  // (%8) bir yaşlı bilge ilan edilir. Bilge yaşadığı sürece köyde +%8
  // moral bonus (computeVillageStats'a eventMorale üstüne eklenir).
  static const _kSagePool = [
    '👵 {ad} artık köyün bilgesi. Kim ne sorsa kapısını çalıyor.',
    '👵 Köy {ad-e} danışmaya başladı. Sözü ağır basıyor.',
    '👵 {ad} ocak başındaki en eski yeri aldı. Bilge o.',
  ];

  void _tickSageEmergence(double dt) {
    _sageCheckSec -= dt;
    if (_sageCheckSec > 0) return;
    _sageCheckSec = 60.0;
    if (_villagers.any((v) => v.isSage)) return;
    final elders = _villagers
        .where((v) => v.lifeStage == LifeStage.elder && !v.isSage)
        .toList();
    if (elders.length < 2) return;
    // Yaşlıya huzur açıksa bilge çıkma şansı yarıya iner (uzun yaşlılık
    // olmadan bilgelik zor olgunlaşır — gerçek bir bedel).
    final chance = _policies.peacefulEnd ? 0.04 : 0.08;
    if (_rng.nextDouble() > chance) return;
    final sage = elders[_rng.nextInt(elders.length)];
    sage.isSage = true;
    _lifeEvent(sage, 'Köyün bilgesi oldu', icon: '✨', milestone: true);
    _showNotification(
      Voice.say(
        _kSagePool,
        _voice(sage, seed: _stableSeed('bilge${sage.name}', _dayCount)),
      ),
    );
  }

  // ── Politika morali — kalıcı bedeller ────────────────────────────────────
  // Politikaların düz toplam etkisi (her tick aynı). Açıkken eventMorale'ye
  // negatif/pozitif eklenir, oyuncu kararının ağırlığı barda görünür.
  double _policyMoralePermanent() {
    double m = 0;
    // Aile planlaması mutex
    switch (_policies.family) {
      case FamilyPolicy.open:
        break;
      case FamilyPolicy.oneChild:
        m -= 0.05;
      case FamilyPolicy.twoChild:
        m -= 0.02;
    }
    if (_policies.familyEncouragement) m -= 0.02;
    if (_policies.peacefulEnd) m += 0.03;
    if (_policies.eldersExemptFromFood) m -= 0.04;
    return m;
  }

  // Geçici efektler — göçmen uyumu (-3%, 2 gün), aile birleşimi (+2%, 5 gün).
  // _policyMoraleEffects listesindeki süresi geçmemişlerin toplamı.
  double _policyMoraleTemporary() {
    _policyMoraleEffects.removeWhere((e) => e.untilSim <= _time);
    double sum = 0;
    for (final e in _policyMoraleEffects) {
      sum += e.amount;
    }
    return sum;
  }

  /// Geçici moral efekti pushla — UI'da görünmesi için. Doğal kullanım:
  /// - Göçmen geldi → push(-0.03, 2 gün)
  /// - Aile kuruldu → push(+0.02, 5 gün)
  void pushPolicyMorale(double amount, double durationDays) {
    _policyMoraleEffects.add((
      untilSim: _time + durationDays * kGameDaySeconds,
      amount: amount,
    ));
  }

  /// Morale anlık ayrık iter (birikim göstergesi). Görünür bir eylem/olay olur
  /// olmaz çağrılır (ör. açlığa girildi → -, doğum/şenlik → +). Sonra _morale
  /// yine tabana süzülür. Pasif gösterge — hiçbir mantık okumaz.
  void nudgeMorale(double delta) {
    _morale = (_morale + delta).clamp(0.0, 1.0);
  }
}
