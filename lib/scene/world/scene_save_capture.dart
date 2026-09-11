part of '../../main.dart';

/// KAYIT — capture yarısı (state → JSON). Yeni bir alan eklerken restore yarısına da ekle (scene_save_restore).
extension _SceneSaveCapture on _VillageSceneState {
  // ── Capture (state → JSON) ──────────────────────────────────────────────────

  /// Tüm dünyayı JSON-uyumlu bir map'e çevirir.
  Map<String, dynamic> captureWorld() {
    // Referans çözümü için indeks tabloları.
    final bIndex = <BuildingEntity, int>{};
    for (var i = 0; i < _buildings.length; i++) {
      bIndex[_buildings[i]] = i;
    }
    final vIndex = <VillagerEntity, int>{};
    for (var i = 0; i < _villagers.length; i++) {
      vIndex[_villagers[i]] = i;
    }
    int bRef(Object? b) => b is BuildingEntity ? (bIndex[b] ?? -1) : -1;
    int vRef(Object? v) => v is VillagerEntity ? (vIndex[v] ?? -1) : -1;
    // İmparatorluk payload'u aktif modal açılınca sahne alanına taşınır. Autosave
    // modal açıkken de çalışabildiği için aktif talebi de aynı kuyruk formatında
    // sakla; aksi hâlde yüklemede karar sessizce kaybolurdu.
    final savedImperialDemand = _pacedImperialDemand ?? _imperialDemand;
    final savedImperialRequestId =
        _pacedImperialRequestId ??
        (_decisionPacing.active?.kind == HeavyDecisionKind.imperial
            ? _decisionPacing.active!.id
            : null);

    return {
      // ── Skaler sim state ──
      'time': _time,
      'worldSeed': _worldSeed,
      'dayCount': _dayCount,
      'lastTimeOfDay': _lastTimeOfDay,
      'timeOfDay': _cycle.timeOfDay,
      'camera': [_camera.dx, _camera.dy],
      'zoom': _zoom,
      'cameraGuideSeen': _cameraGuideSeen,
      'speedIdx': _speedIdx,
      // Değeri ayrıca yazmak indeks düzeninden bağımsız güvenli göç sağlar.
      'timeScale': _timeScale,
      'morale': _morale,
      'avgIndividualMorale': _avgIndividualMorale,
      'foodHunger': _foodHunger,
      'hasFire': _hasFire,
      'charterTier': _charterTier,
      'governanceLegacy': _governanceLegacy,
      'merchantTimer': _merchantTimer,
      'merchantTradeCd': _merchantTradeCd,
      // Kararın dünyada süren işleri ve olayların tekrarlanan davranış izi.
      // Bunlar UI efekti değil: yükleyerek ulağı erken döndürmek ya da olayın
      // köydeki sonucunu silmek mümkün olmamalı.
      'decisionProcesses': [
        for (final process in _decisionProcesses) process.toJson(),
      ],
      'governanceAftermath': [
        for (final aftermath in _governanceAftermath) aftermath.toJson(),
      ],
      'lawBehaviorNextSim': _lawBehaviorNextSim,
      'lawBehaviorCursor': _lawBehaviorCursor,
      'lastPopMilestone': _lastPopMilestone,
      'firstReedBedShown': _firstReedBedShown,
      'foundingFirstNightFastForwarded': _foundingFirstNightFastForwarded,
      'foundingBedWorkElapsed': _foundingBedWorkElapsed,
      'foundingFirstNightWaitReal': _foundingFirstNightWaitReal,
      'foundingTentsReadyDay': _foundingTentsReadyDay,
      'foundingTentIllnessTriggered': _foundingTentIllnessTriggered,
      'firepit': bRef(_firepitBuilding),
      'firekeeper': vRef(_firekeeper),

      // ── Harita + kaynaklar + sistemler ──
      'water': [
        for (final t in _waterTiles) [t.$1, t.$2],
      ],
      'stockpile': _stockpileToJson(),
      'policies': _policiesToJson(),
      'houses': _houses.toJson(),
      // Kaybetme eşiği: kurulmuşluk filigranı + geri sayım. İkisi de KAYDEDİLİR
      // — yoksa yüklenen köyde "ancak kurduğunu kaybedersin" kuralı sıfırlanır
      // (peak 0'a düşer, sistem yeniden uyur) ve tükenmekte olan bir köy
      // kaydedip yükleyerek sayacı silebilirdi.
      'peakAdults': _peakAdults,
      'collapseCountdown': _collapseCountdown,
      // Hesaplaşma: ilan BİR KEZ düşer, dolayısıyla kaydedilmeli — yoksa
      // yüklenen köy berat yılını her açılışta yeniden ilan eder. Kararın
      // kendisi de yazılır ki mühürlü kaydın gerekçesi menüde okunsun.
      'reckoningHeralded': _reckoningHeralded,
      'karneYear': _karneYear,
      'reckoningVerdict': _reckoningVerdict?.name,
      // Görülen orta oyun dersleri — yüklenen köyde kış ikinci kez
      // anlatılmasın (öğretmek değil dırdır etmek olurdu).
      'lessonsSeen': _lessonsSeen.toList(),
      'completedQuests': _completedQuests.toList(),
      // Öğretici spotu görülmüş adımlar — yüklenen köyde ders tekrarlanmaz.
      'guideShown': _guideShown.toList(),
      // KIŞ — dağıtılmamış giysi, dağıtım kararı, ilk-kez törenleri.
      // Sönmüş ocaklar (_coldHouses) ve kar çarpanı TÜREVDİR: ilk kış
      // taramasında yeniden hesaplanır, kayda yazılmaz.
      'coatsMade': _coatsMade,
      'coatPriority': _coatPriority.name,
      'firstShearShown': _firstShearShown,
      'firstCoatShown': _firstCoatShown,
      'villageMemory': _villageMemory.toList(),
      'storyCasts': {
        for (final e in _storyCasts.entries)
          e.key.name: e.value.toJson(
            (v) => _storyPersonPresent(v) ? vRef(v) : -1,
          ),
      },
      // KÖY NABZI — açık küçük hikâye + ileride dönecek sonuç yankıları.
      // Kartın açık/kapalı hâli UI geçicisidir; yalnız hikâyenin kendisi kalır.
      'villagePulseNextReal': _villagePulseNextReal,
      'villagePulse': _villagePulse == null
          ? null
          : {
              'kind': _villagePulse!.kind.name,
              'actor': vRef(_villagePulse!.actor),
              'other': vRef(_villagePulse!.other),
              'remainingReal': _villagePulse!.remainingReal,
              'totalReal': _villagePulse!.totalReal,
            },
      'villagePulseEchoes': [
        for (final e in _villagePulseEchoes)
          {
            'dueSim': e.dueSim,
            'icon': e.icon,
            'text': e.text,
            'actor': vRef(e.actor),
          },
      ],
      'knownCrafts': _knownCrafts.toList(),
      'specialistOffersClaimed': _specialistOffersClaimed,
      // Merkezi ağır-karar otoritesi + henüz yüzeye çıkmamış payload'lar.
      // Yalnız timer'ları yazmak yetmez: kuyruk kaybolursa oyuncunun önüne
      // gelmemiş karar sessizce buharlaşır.
      'decisionPacing': _decisionPacing.toJson(),
      'decisionCustoms': _decisionCustoms.toJson(),
      'pacedPetitions': [
        for (final payload in _pacedPetitions)
          {
            'requestId': payload.requestId,
            'petitionId': payload.petition.id,
            'author': vRef(payload.author),
            'extra': payload.extra,
          },
      ],
      'pacedChoices': [
        for (final payload in _pacedChoices)
          {'requestId': payload.requestId, 'eventId': payload.event.id},
      ],
      'pacedImperialRequestId': savedImperialRequestId,
      'pacedImperialDemand': savedImperialDemand == null
          ? null
          : {
              'kind': savedImperialDemand.kind.name,
              'amount': savedImperialDemand.amount,
            },
      // Hikâye güncesi (yapısal) + başarımlar + sinematik durumu (anılar kalıcı).
      'storyLog': [for (final e in _storyLog) e.toJson()],
      'achievedMilestones': _achievedMilestones.toList(),
      'oreDiscovered': _oreDiscovered.toList(),
      'villageName': _villageName,
      'famineShown': _famineShown,
      'imperialBattle': _captureImperialBattle(vRef),
      'imperialFavor': _imperialFavor,
      'imperialTimer': _imperialTimer,
      // Sinematik merdiveni — yazılmazsa her yüklemede "ilk ziyaret" sanılır
      // ve film baştan oynar (tam da kaçındığımız tekrar).
      // Hane baskı sayacı — yazılmazsa yüklemede sert geçmiş silinir ve
      // oyuncu aynı haneyi sıfır bedelle yeniden sağabilir.
      'housePressure': _housePressure,
      'imperialVisits': _imperialVisits,
      'impGrudge': _impGrudge,
      'impFilmsShown': _impFilmsShown.toList(),

      // ── Varlıklar ──
      'buildings': [for (final b in _buildings) _buildingToJson(b)],
      'villagers': [for (final v in _villagers) _villagerToJson(v, bRef, vRef)],
      // Ziyaretçi nüfus değildir ama kararın dünya kanıtıdır. Kervan varken
      // kaydedip yüklemek “köyde kervan yok” diye seçeneği kapatmamalı.
      'merchants': [
        for (final m in _merchants)
          if (!m.finished)
            {
              'name': m.name,
              'male': m.isMale,
              'type': m.type.name,
              'visitorKind': m.visitorKind.name,
              'phase': m.phase.name,
              'groupId': m.groupId,
              'leader': m.isGroupLeader,
              'cart': m.hasCart,
              'x': m.gridX,
              'y': m.gridY,
              'browseX': m.browseX,
              'browseY': m.browseY,
              'exitX': m.exitX,
              'exitY': m.exitY,
              'headingX': m.travelHeadingX,
              'headingY': m.travelHeadingY,
              'browseLeft': m.browseLeft,
              'greetingLeft': m.greetingLeft,
            },
      ],
      'orders': [for (final o in _orders) _orderToJson(o)],
      'roadOrders': [for (final o in _roadOrders) _roadOrderToJson(o)],
      'roads': [for (final t in _roadSystem.all) _roadTileToJson(t)],
      'farmTiles': [for (final t in _farmTiles) _farmTileToJson(t)],
      'harmanSites': [
        for (final site in _harmanSites) {'col': site.col, 'row': site.row},
      ],
      'trees': [for (final t in _trees) _treeToJson(t)],
      'mineNodes': [for (final n in _mineNodes) _mineNodeToJson(n)],
      'landmarks': [
        for (final s in _landmarks)
          {
            'col': s.col,
            'row': s.row,
            'kind': s.kind.name,
            'outcome': s.outcome.name,
            'discovered': s.discovered,
          },
      ],
      'animals': [for (final a in _cows) _animalToJson(a)],
      'lotuses': [
        for (final l in _lotuses)
          {'col': l.col, 'row': l.row, 'variant': l.variant},
      ],
      'reeds': [for (final r in _reeds) _reedClumpToJson(r)],
      // Böğürtlen çalıları — olgunluk KALICI dünya durumu. Kaydedilmezse köy
      // her yüklemede toplanmamış çalılarla dolu uyanır (bedava yiyecek).
      'berryBushes': [
        for (final b in _berryBushes)
          {
            'col': b.col,
            'row': b.row,
            'variant': b.variant,
            'ripe': b.ripeness,
          },
      ],
      'cookedMeals': _cookedMeals,
      'berriesPicked': _berriesPicked,
      'woodHarvested': _woodHarvested,
      if (_firstMealShown) 'firstMealShown': true,
      'decor': [for (final d in _decor) _decorToJson(d)],
      'graves': [for (final g in _graves) _graveToJson(g)],
      'reedBeds': [
        for (final b in _reedBeds)
          {'x': b.gridX, 'y': b.gridY, 'owner': vRef(b.owner)},
      ],
      'resourceBoxes': [for (final r in _resourceBoxes) _resourceBoxToJson(r)],
      'hay': [for (final h in _hayEntities) _hayToJson(h)],
      // Gömülü zulalar — KALICI dünya durumu. Kaydedilmezse çalınan mal
      // yüklemede sessizce buharlaşırdı (stoktan çıkmış, toprakta da yok).
      'lootCaches': [
        for (final l in _lootCaches)
          {
            'x': l.gridX,
            'y': l.gridY,
            'kind': l.kind.name,
            'amount': l.amount,
            'weaponAmount': l.weaponAmount,
            'age': l.age,
            // Görülmüş olmak zulanın bulunabilirliğini belirler → kalıcı.
            'witnessed': l.witnessed,
            'culprit': vRef(l.culprit),
            'culpritName': l.culpritName,
          },
      ],

      // ── Dilekçe / meclis ──
      'pendingPetition': _pendingPetition?.id,
      'queuedPetition': _queuedPetition?.id,
      'queuedPresentDelay': _queuedPresentDelay,
      'petitionAuthor': vRef(_petitionAuthor),
      // Bekleyen düğünün ÇİFTİ. Eskiden kaydedilmiyordu ve yüklemede
      // `_findCourtship()` ile RASTGELE yeni bir çift bağlanıyordu: modal
      // kayıttaki gelini (`petitionAuthor`) gösterip "Kutla" BAŞKA birini
      // evlendiriyordu. Kimin evlendiği oyuncunun okuduğu şeyle aynı olmalı.
      'weddingCouple': _weddingCouple == null
          ? null
          : [vRef(_weddingCouple!.$1), vRef(_weddingCouple!.$2)],
      // Dilekçeye özel yer tutucular ({suçlu}, {suç}…) — metin yüklemede aynen
      // yeniden dokunabilsin diye saklanır.
      'petitionExtra': _petitionExtra,
      'petitionTimer': _petitionTimer,
      'petitionDeadline': _petitionDeadline,
      'petitionModalOpen': _petitionModalOpen,
      // Kapıda bekleyen huzur (eski adıyla 'petitionForced' — zorunlu huzur
      // donması kaldırıldı; eski kayıtların bayrağı restore'da buna göçer).
      'petitionOverdue': _petitionOverdue,
      'petitionOverdueTimer': _petitionOverdueTimer,
      'petitionFollowUps': [
        for (final f in _petitionFollowUps)
          {
            'id': f.id,
            'fireAtSim': f.fireAtSim,
            // Zincirin aktörü indeksle taşınır (köylü referansı kaydedilemez).
            'actor': vRef(f.actor),
            'actorName': f.actorName,
          },
      ],
      'petitionCooldowns': _petitionCooldowns,

      // ── Suç (scene_crime) ──
      // Yürüyen suç (_activeCrime) ve rehin (_ransomVictim) KAYDEDİLMEZ: ikisi
      // de anlık sahne durumu. Kayıttan dönüldüğünde suç düşer, rehin kaybolmuş
      // sayılır ve dayanaksız kalan yargı/fidye dilekçesi yüklemede atılır.
      // ── Rejim (scene_regime) ──
      // Yemin AYRI kaydedilmez: köy hafızası bayrağında durur (oath.<rejim>),
      // o da _villageMemory ile zaten taşınır. Tek doğruluk kaynağı orası.
      'unrest': _unrest,
      'crisisCooldown': _crisisCooldown,
      'unrestStirShown': _unrestStirShown,
      // Çürüme (Faz 3) — huzursuzluğun kalıcı izi + kronik hâl duyuru bayrağı.
      'regimeRot': _regimeRot,
      'chronicShown': _chronicShown,

      'crimeSuspicion': _crimeSuspicion,
      'crimePardons': _crimePardons,
      'crimesSeen': _crimesSeen,
      // Kanunname kapıları bunları okur (Tecrit / Diyet) — kayıttan dönen köyün
      // defteri aynı hükümleri göstermeli, yoksa gündem sıfırlanmış görünür.
      'illnessSeen': _illnessSeen,
      'feudsSeen': _feudsSeen,
      'accusedCriminal': vRef(_accusedCriminal),

      // ── Olay / politika moral / ambient timer ──
      'eventTimer': _eventTimer,
      'eventMorale': _eventMorale,
      'eventMoraleLeft': _eventMoraleLeft,
      'eventLabel': _eventLabel,
      // Kuyrukta bekleyen karar olayı — kapıda kuyruk sim'i durdurmadığı için
      // oyuncu bekleyen kararla kaydedebilir; yazılmazsa yüklenen köyde karar
      // sessizce buharlaşırdı (kayıp haber verilir kuralının kayıt hâli).
      'pendingChoice': _pendingChoice?.id,
      'choiceDeadline': _choiceDeadline,
      'choiceGrace': _choiceGrace,
      'policyMoraleEffects': [
        for (final e in _policyMoraleEffects)
          {'untilSim': e.untilSim, 'amount': e.amount},
      ],
      'migrationTimerSec': _migrationTimerSec,
    };
  }

  Map<String, dynamic> _stockpileToJson() => {
    'wood': _stockpile.wood,
    'stone': _stockpile.stone,
    'iron': _stockpile.iron,
    'coal': _stockpile.coal,
    'food': _stockpile.food,
    'honey': _stockpile.honey,
    'reed': _stockpile.reed,
    'wool': _stockpile.wool,
    'gold': _stockpile.gold,
    'weapons': _stockpile.weapons,
  };

  /// KANUNNAME — mühür seti + girilen dava kolu + ıslak mürekkep. Tek doğruluk
  /// kaynağı `sealed`; bool'lar yüklemede ondan türer (bkz. restoreSealed).
  Map<String, dynamic> _policiesToJson() => {
    'sealed': _policies.sealed.toList(),
    // Mühür günleri — hüküm hangi gün deftere girdi (defterde yanında yazar).
    'sealedOn': _policies.sealedOn,
    'inkDryUntilSim': _policies.inkDryUntilSim,
    // Gündeme gelmiş hüküm id'leri — yüklemede bütün defter "yeni açıldı"
    // diye bağırmasın diye taşınır (bkz. _tickLawGates).
    'lawSeen': _lawSeen.toList(),
  };

  Map<String, dynamic> _buildingToJson(BuildingEntity b) => {
    'type': b.type.name,
    if (b.design != BuildingDesign.original) 'design': b.design.name,
    'col': b.col,
    'row': b.row,
    'isActive': b.isActive,
    'userPaused': b.userPaused,
    'incomeTimer': b.incomeTimer,
    'serviceTimer': b.serviceTimer,
    if (b.inscription.isNotEmpty) 'inscription': b.inscription,
    'waterLevel': b.waterLevel,
    'occupants': b.occupants,
    'damage': b.damage,
    'ownerSurname': b.ownerSurname,
    'eggTimer': b.eggTimer,
    'honeyTimer': b.honeyTimer,
    'fireFuel': b.fireFuel,
    if (b.type == BuildingType.mill) 'millRotorAngle': b.millRotorAngle,
  };

  Map<String, dynamic> _villagerToJson(
    VillagerEntity v,
    int Function(Object?) bRef,
    int Function(Object?) vRef,
  ) {
    // Porter callback/hedefleri geçici runtime state'idir ve JSON'a girmez.
    // Enum'u tek başına kaydetmek yüklemede boş elle (0,0)'a yürüyen bir NPC
    // üretirdi; snapshot'ta görevi kesilmiş, bulunduğu yerde idle sayılır.
    final transientCarry = v.hasCarryTask;
    return {
      'type': v.type.name,
      'name': v.name,
      'visual': _visualToJson(v.visual),
      'personalitySeed': v.personalitySeed,
      'annivCount': v.annivCount,
      'callingFound': v.callingFound,
      'grewUpMoment': v.grewUpMoment,
      'spawnCol': v.spawnCol,
      'spawnRow': v.spawnRow,
      'x': v.gridX,
      'y': v.gridY,
      'facingRight': v.facingRight,
      'ageDays': v.ageDays,
      'lifespanDays': v.lifespanDays.isFinite ? v.lifespanDays : null,
      'state': transientCarry ? VillagerState.idle.name : v.state.name,
      'targetCol': transientCarry ? v.gridX : v.targetCol,
      'targetRow': transientCarry ? v.gridY : v.targetRow,
      'isFavorite': v.isFavorite,
      'wed': v.wed,
      'avoidsMarriage': v.avoidsMarriage,
      if (v.isLeaving)
        'leavingTo': [v.leavingDestination.$1, v.leavingDestination.$2],
      // Üstlenilmiş iş — yalnız rol adı; faz/sayaç/claim geçici (açılışta
      // _syncJobWorkforce yeniden kurar, tıpkı workCooldown gibi).
      if (v.hasActiveJob) 'jobRole': v.job!.role.name,
      // OYUNCUNUN ELİ — bu, `jobRole`'dan farklı olarak KARAR'dır, durum değil.
      // Yüklerken geri konmazsa köy sessizce otomatik dağıtıma döner ve oyuncu
      // kurduğu iş bölümünü kaybeder. `none` da geçerli bir karardır ("boş dursun").
      if (v.assignedRole != null) 'assignedRole': v.assignedRole!.name,
      // HANGİ İŞ YERİ — `assignedRole` "ne iş" der, bu "nerede" der. İki
      // madenli köyde rol tek başına yeri geri getirmez; yazılmazsa yükleyişte
      // kadro yanlış ocağın altında görünürdü.
      if (v.assignedSiteId != null) 'assignedSite': v.assignedSiteId,
      if (v.surname.isNotEmpty) 'surname': v.surname,
      if (v.injuryDays > 0) 'injuryDays': v.injuryDays,
      if (v.sickDays > 0) 'sickDays': v.sickDays,
      if (v.tutorialIllness) 'tutorialIllness': true,
      // Kışlık giysi — köyün emeği; yükleyince sırtından düşmesin.
      if (v.hasCoat) 'hasCoat': true,
      if (v.wardrobe != NpcWardrobe.standard) 'wardrobe': v.wardrobe.name,
      if (v.laborDays > 0) 'laborDays': v.laborDays,
      if (v.disabled) 'disabled': true,
      'life': [for (final e in v.life) e.toJson()],
      'fertilityDays': v.fertilityDays.isNaN ? null : v.fertilityDays,
      'birthCount': v.birthCount,
      'isSage': v.isSage,
      'mood': v.mood,
      'energy': v.energy,
      'morale': v.morale,
      // DÜRTÜLER — köylünün aklı (bkz. villager_mind). Niyet KAYDEDİLMEZ
      // (yüklemede hakem yeniden karar verir) ama dürtüler kalıcıdır: aç
      // yatan köylü aç uyanmalı, yoksa yükleme köyü sıfırlanmış gibi olur.
      'drives': v.mind.toJson(),
      // KANAAT — anılar söner (kaydedilmez, geçicidir) ama bıraktıkları iz
      // kalır. "Ne yaptığını hatırlamıyorum ama ondan hoşlanmıyorum" hâli
      // kayıttan sonra da sürsün: köyün sosyal dokusu yüklemede sıfırlanmaz.
      'opinion': [
        for (final e in v.memory.opinion.entries)
          if (vRef(e.key) >= 0) {'v': vRef(e.key), 'o': e.value},
      ],
      'lowMoraleTime': v.lowMoraleTime,
      'moraleReason': v.moraleReason,
      'wealth': v.wealth,
      if (v.mastery.isNotEmpty) 'mastery': v.mastery,
      'home': bRef(v.homeBuilding),
      'parents': [for (final p in v.parents) vRef(p)],
      'children': [for (final c in v.children) vRef(c)],
      'grudges': [
        for (final e in v.grudges.entries) {'v': vRef(e.key), 'until': e.value},
      ],
      'bloodEnemies': [for (final e in v.bloodEnemies) vRef(e)],
      'feudKills': v.feudKills,
      if (v.crimeCount > 0) 'crimeCount': v.crimeCount,
    };
  }

  /// İşçi base — pozisyon + dolaşma merkezi (spawn). Görev/path state taşınmaz.
  /// ESKİ KAYIT GÖÇÜ — soyadsız köylüleri hane grafiğine bağlar.
  ///
  /// Hane sistemi köylüyü SOYADINDAN tanır: besleme döngüsü (scene_estates)
  /// `if (v.surname.isNotEmpty)` diyor. Haneler eklenmeden önce yapılmış
  /// kayıtlarda kimsenin soyadı yok → Divan masası boş, hane kartları boş,
  /// hane eylemleri hedefsiz. Kayıt BOZUK değil, EKSİK: yönetişimin yarısı
  /// sessizce ölü açılıyor ve oyuncu bunu bir hata olarak da göremiyor.
  ///
  /// Göç aile bağlarını izler: ebeveyn/çocuk grafiğinin her bağlantılı bileşeni
  /// TEK hanedir. Bileşende soyadı olan biri varsa (karışık kayıt) o ad
  /// kullanılır — erkek üye önce, çünkü soy erkek üzerinden taşınıyor
  /// (bkz. `_patrilinealSurname`). Kimsede yoksa yeni bir soy adı verilir.
  /// Bağsız köylü kendi hanesini kurar; dışarıdan gelen (tüccar/mülteci)
  /// zaten öyle sayılıyor.
  ///
  /// Kendi kendini kapatır: soyadsız kimse kalmayınca hiçbir şey yapmaz, yani
  /// yeni kayıtlarda bedeli tek bir taramadır.
  void _migrateHouseholdSurnames() {
    if (_villagers.every((v) => v.surname.isNotEmpty)) return;

    final seen = <VillagerEntity>{};
    for (final start in _villagers) {
      if (!seen.add(start)) continue;
      // Bileşeni gez (iki yönlü: ebeveyn + çocuk).
      final comp = <VillagerEntity>[start];
      for (var i = 0; i < comp.length; i++) {
        for (final kin in comp[i].parents) {
          if (seen.add(kin)) comp.add(kin);
        }
        for (final kin in comp[i].children) {
          if (seen.add(kin)) comp.add(kin);
        }
      }

      var name = '';
      for (final m in comp) {
        if (m.isMale && m.surname.isNotEmpty) {
          name = m.surname;
          break;
        }
      }
      if (name.isEmpty) {
        for (final m in comp) {
          if (m.surname.isNotEmpty) {
            name = m.surname;
            break;
          }
        }
      }
      if (name.isEmpty) name = randomVillagerSurname(_rng);

      for (final m in comp) {
        if (m.surname.isEmpty) m.surname = name;
      }
    }
  }

  Map<String, dynamic> _animalToJson(AnimalEntity a) => {
    'kind': a.kind.name,
    'barnCol': a.barnCol,
    'barnRow': a.barnRow,
    'x': a.gridX,
    'y': a.gridY,
    'facingRight': a.facingRight,
    'facing4': a.facing4.name,
    'hunger': a.hunger,
    'milkProgress': a.milkProgress,
    'isMale': a.isMale,
    'ageDays': a.ageDays,
    'lifespanDays': a.lifespanDays,
    'fertilityDays': a.fertilityDays.isNaN ? null : a.fertilityDays,
  };

  Map<String, dynamic> _orderToJson(BuildOrder o) => {
    'type': o.type.name,
    if (o.design != BuildingDesign.original) 'design': o.design.name,
    'col': o.col,
    'row': o.row,
    'completed': o.completed,
    'progress': o.progress,
  };

  Map<String, dynamic> _roadOrderToJson(RoadOrder o) => {
    'col': o.col,
    'row': o.row,
    'surface': o.surface.name,
    'assigned': o.assigned,
    'completed': o.completed,
    'progress': o.progress,
  };

  Map<String, dynamic> _roadTileToJson(RoadTile t) => {
    'col': t.col,
    'row': t.row,
    'surface': t.surface.name,
  };

  Map<String, dynamic> _farmTileToJson(FarmTile t) => {
    'col': t.col,
    'row': t.row,
    'stage': t.stage,
    'growthProgress': t.growthProgress,
    'needsSowing': t.needsSowing,
    'fallow': t.fallowRemaining,
  };

  Map<String, dynamic> _treeToJson(TreeEntity t) => {
    'col': t.col,
    'row': t.row,
    'type': t.type.name,
    'marked': t.isMarkedForCutting,
    'felled': t.isFelled,
    'fellAge': t.fellAge,
    'fallDirection': t.fallDirection,
    'fallImpactEmitted': t.fallImpactEmitted,
    'growing': t.isGrowing,
    'wild': t.isWild,
  };

  Map<String, dynamic> _mineNodeToJson(MineNode n) => {
    'col': n.col,
    'row': n.row,
    'type': n.type.name,
    'marked': n.isMarkedForMining,
    'depleted': n.isDepleted,
  };

  Map<String, dynamic> _reedClumpToJson(ReedClump r) => {
    'col': r.col,
    'row': r.row,
    'col2': r.col2,
    'row2': r.row2,
    'growth': r.growth,
  };

  Map<String, dynamic> _decorToJson(DecorEntity d) => {
    'col': d.col,
    'row': d.row,
    'kind': d.kind.name,
    'variant': d.variant,
    'jitterX': d.jitterX,
    'jitterY': d.jitterY,
    'swaySeed': d.swaySeed,
  };

  Map<String, dynamic> _graveToJson(Grave g) => {
    'col': g.col,
    'row': g.row,
    'variant': g.variant,
    'name': g.name,
    'jitterX': g.jitterX,
    'jitterY': g.jitterY,
  };

  VillagerEntity? _carrierHolding(Object item) {
    for (final v in _villagers) {
      if (identical(v.carriedItem, item)) return v;
    }
    return null;
  }

  Map<String, dynamic> _resourceBoxToJson(ResourceBox r) {
    final carrier = _carrierHolding(r);
    return {
      'type': r.type.name,
      // Pickup öncesinde kaynak zaten yerde ve koordinatı korunur. Ele alınmış
      // yükse snapshot kesintisi onu taşıyıcının ayağında dünyaya bırakır.
      'x': carrier?.gridX ?? r.gridX,
      'y': carrier?.gridY ?? r.gridY,
      'amount': r.amount,
      'slotIndex': r.slotIndex,
    };
  }

  Map<String, dynamic> _hayToJson(HayEntity h) {
    final carrier = _carrierHolding(h);
    return {
      'type': h.type.name,
      'x': carrier?.gridX ?? h.gridX,
      'y': carrier?.gridY ?? h.gridY,
      'slotIndex': h.slotIndex,
      'pileSize': h.pileSize,
      // spawnTime kayıtlıysa harmanın FIFO sırası ve düşme animasyonu
      // yüklemeden sonra da doğru kalır (_time de kaydediliyor).
      'spawnTime': h.spawnTime,
      if (h.targetHarmanCol != null) 'harmanCol': h.targetHarmanCol,
      if (h.targetHarmanRow != null) 'harmanRow': h.targetHarmanRow,
    };
  }

  Map<String, dynamic>? _captureImperialBattle(int Function(Object?) vRef) {
    final battle = _imperialBattle;
    if (battle == null) return null;
    return {
      'simulation': battle.toJson(),
      'actors': {
        for (final entry in _battleActors.entries)
          entry.key.toString(): entry.value is ImperialSoldier
              ? -1
              : vRef(entry.value),
      },
      'soldiers': {
        for (final entry in _battleActors.entries)
          if (entry.value is ImperialSoldier)
            entry.key.toString(): {
              'visual': _visualToJson(entry.value.visual),
              'back': (entry.value as ImperialSoldier).backOffset,
              'side': (entry.value as ImperialSoldier).sideOffset,
            },
      },
      'civilians': _battleCivilians.map(vRef).toList(),
      'demandKind': _battleDemand!.kind.name,
      'demandAmount': _battleDemand!.amount,
      'raid': _imperialRaidScenario?.kind.name,
      'anchor': [_impAnchorCol, _impAnchorRow],
      'parley': [_impParleyCol, _impParleyRow],
      'aftermath': _battleAftermath,
      'previousZoom': _battlePreviousZoom,
    };
  }

  void _restoreImperialBattle(Object? raw) {
    if (raw is! Map) return;
    final battle = ImperialBattle.fromJson(
      Map<String, dynamic>.from(raw['simulation'] as Map),
    );
    final actors = raw['actors'] as Map, soldiers = raw['soldiers'] as Map;
    _battleActors.clear();
    _soldiers.clear();
    for (final f in battle.fighters) {
      final index = actors[f.id.toString()] as int;
      VillagerEntity v;
      if (f.side == BattleSide.empire) {
        final j = soldiers[f.id.toString()] as Map;
        final soldier = ImperialSoldier(
          startCol: f.x,
          startRow: f.y,
          commander: f.commander,
          backOffset: _d(j['back']),
          sideOffset: _d(j['side']),
          visual: _visualFromJson(
            Map<String, dynamic>.from(j['visual'] as Map),
          ),
        );
        _soldiers.add(soldier);
        v = soldier;
      } else {
        v = _villagers[index];
        _prepForScene(v);
        v.prop = v.type == VillagerType.guard
            ? PropKind.none
            : (v.type == VillagerType.farmer ? PropKind.scythe : PropKind.axe);
      }
      v.gridX = v.renderX = f.x;
      v.gridY = v.renderY = f.y;
      v.battleHealth = (f.health / f.maxHealth).clamp(0, 1);
      v.battleResolve = f.resolve;
      v.battleSwing = f.swing;
      v.battleFall = (f.downTime / .65).clamp(0, 1);
      if (battle.hasBarricade && f.side == BattleSide.village && f.id < 5) {
        // Rebuilt below once the saved approach direction is available.
        v.battlePost = (f.postX, f.postY);
      }
      v.state = VillagerState.idle;
      _battleActors[f.id] = v;
    }
    _battleCivilians.clear();
    for (final index in raw['civilians'] as List) {
      if (index is int && index >= 0 && index < _villagers.length) {
        _battleCivilians.add(_villagers[index]);
      }
    }
    _imperialBattle = battle;
    _imperialDefensePlan = battle.plan;
    _battleDemand = ImperialDemand(
      ImperialDemandKind.values.byName(raw['demandKind'] as String),
      raw['demandAmount'] as int,
    );
    _imperialRaidScenario = imperialRaidScenarios
        .where((s) => s.kind.name == raw['raid'])
        .firstOrNull;
    _imperialRaidTargetBuilding = _raidTargetBuilding(
      _imperialRaidScenario?.target,
    );
    final anchor = raw['anchor'] as List, parley = raw['parley'] as List;
    _impAnchorCol = _d(anchor[0]);
    _impAnchorRow = _d(anchor[1]);
    _impParleyCol = _d(parley[0]);
    _impParleyRow = _d(parley[1]);
    _impExitCol = battle.exitX;
    _impExitRow = battle.exitY;
    final (cx, cy) = _villageCenterD();
    _setMarchDir(cx - _impAnchorCol, cy - _impAnchorRow);
    for (final f in battle.fighters) {
      if (_battleActors[f.id]!.battlePost != null) {
        _battleActors[f.id]!.battlePost = (
          f.postX - _impDirX * .6,
          f.postY - _impDirY * .6,
        );
      }
    }
    _imperialBattleWon = battle.result == BattleResult.held;
    _battleAftermath = _d(raw['aftermath']);
    _battlePreviousZoom = raw['previousZoom'] == null
        ? null
        : _d(raw['previousZoom']);
    _imperialPhase = ImperialVisitPhase.clashing;
    _watchX = _impAnchorCol;
    _watchY = _impAnchorRow;
    _watchLeft = 2;
    kProbeImperialBattleActive = true;
    kProbeImperialBattleHits = battle.hits;
    kProbeImperialBattleResult = battle.result?.name ?? '';
  }
}
