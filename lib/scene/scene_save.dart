part of '../main.dart';

/// Tam dünya kayıt/yükleme — köyün TÜM kalıcı state'ini JSON'a çevirir ve
/// kaldığı yerden geri kurar. Köylüler (isim/yaş/aile/moral/görsel kimlik),
/// binalar, kaynaklar, zümreler, dilekçe hafızası, harita, gün/saat dahil.
///
/// Tasarım:
///  - Kimlik yok → referanslar İNDEKS ile çözülür (köylü/bina liste sırası).
///    Yükleme aynı sırada kurar, sonra parents/children/homeBuilding bağlanır.
///  - Geçici state (görev hedefi, path cache, render lerp, anlık duygu/oturma)
///    KAYDEDİLMEZ → yükleme sonrası işçiler hedefi yeniden bulur, cache yeniden
///    türetilir. Görünür sonuç birebir aynı köy, içeride taze AI.
///  - Su tile'ları doğrudan kaydedilir → generator determinizmine bağımlı değil.
extension _SceneSave on _VillageSceneState {
  // ── Yardımcılar ────────────────────────────────────────────────────────────

  int _colInt(Color c) => c.toARGB32();
  Color _colFromInt(int v) => Color(v);

  T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
    if (name is String) {
      for (final v in values) {
        if (v.name == name) return v;
      }
    }
    return fallback;
  }

  double _d(Object? v, [double fb = 0]) => (v as num?)?.toDouble() ?? fb;
  int _i(Object? v, [int fb = 0]) => (v as num?)?.toInt() ?? fb;
  bool _b(Object? v, [bool fb = false]) => (v as bool?) ?? fb;

  // ── NpcVisual ──────────────────────────────────────────────────────────────

  Map<String, dynamic> _visualToJson(NpcVisual v) => {
    'skin': _colInt(v.skin),
    'hair': _colInt(v.hair),
    'hairStyle': v.hairStyle.name,
    'eyes': _colInt(v.eyes),
    'hasBeard': v.hasBeard,
    'beardStyle': v.beardStyle.name,
    'clothingShift': v.clothingShift,
    'blinkPhase': v.blinkPhase,
    'isMale': v.isMale,
    'build': v.build,
  };

  NpcVisual _visualFromJson(Map<String, dynamic> j) => NpcVisual(
    skin: _colFromInt(_i(j['skin'], 0xFFFFCB9A)),
    hair: _colFromInt(_i(j['hair'], 0xFF3E2A14)),
    hairStyle: _enumByName(HairStyle.values, j['hairStyle'], HairStyle.short),
    eyes: _colFromInt(_i(j['eyes'], 0xFF4A381E)),
    hasBeard: _b(j['hasBeard']),
    beardStyle: _enumByName(
      BeardStyle.values,
      j['beardStyle'],
      BeardStyle.none,
    ),
    clothingShift: _d(j['clothingShift']),
    blinkPhase: _d(j['blinkPhase']),
    isMale: _b(j['isMale'], true),
    // Eski kayıtlarda yok → 1.0 (nötr beden), köylü aynı görünmeye devam eder.
    build: j['build'] == null ? 1.0 : _d(j['build']),
  );

  // ── Kayıt tetikleyiciler ────────────────────────────────────────────────────

  /// Gerçek-zaman birikimiyle periyodik otomatik kayıt. _onTick her frame çağırır.
  void _maybeAutoSave(double realDt) {
    _autoSaveAccum += realDt;
    if (_autoSaveAccum >= _VillageSceneState._kAutoSaveInterval) {
      _autoSaveAccum = 0;
      _saveNow();
    }
  }

  /// Mevcut köyü slota yazar (async, fire-and-forget). [manual] true ise
  /// kullanıcıya kısa "Kaydedildi" geri bildirimi gösterir.
  /// [asSlot]/[asName] verilirse kayıt SAHNENİN slotuna değil oraya yazılır.
  /// Godmode'un mevsimlik referans köyleri bunu kullanır: tek oturumda dört
  /// ayrı slot üretilebilsin (sahnenin `_slotId`'si final, değiştirilemez).
  Future<void> _saveNow({
    bool manual = false,
    String? asSlot,
    String? asName,
  }) async {
    final slot = asSlot ?? _slotId;
    if (_saving || slot.isEmpty) return;
    _saving = true;
    try {
      final data = <String, dynamic>{
        'version': SaveManager.schemaVersion,
        'meta': SaveSlotMeta(
          id: slot,
          name: asName ?? _slotName,
          savedAt: DateTime.now(),
          day: _dayCount,
          population: _villagers.length,
          identity: _houses.identityName,
        ).toJson(),
        'world': captureWorld(),
      };
      await SaveManager.instance.writeSlot(slot, data);
      if (manual && mounted) {
        _showNotification('💾 Köy kaydedildi');
      }
    } catch (_) {
      if (manual && mounted) _showNotification('⚠ Kayıt başarısız');
    } finally {
      _saving = false;
    }
  }

  /// Sol-alttaki menü kümesi — tek "⚙" tutamağı altında OYUN dışı işler:
  /// menüye dön + kaydet. Köy içi hiçbir şey burada durmaz (hikâye güncesi
  /// buradaydı, Köy Defteri'nin KRONİK bölümüne taşındı: köyün kendisiyle ilgili
  /// her şey tek kapıda). Açılınca öğeler gear'ın ÜSTÜNDE belirir (alttaki inşa
  /// çubuğundan uzakta). Varsayılan kapalı (sade ekran).
  Widget buildSaveButton() {
    // MOBİL: bu küme telefonda ÇİZİLMEZ. Dünyanın ortasında sahipsiz duran bir
    // "⚙ Menü" pill'iydi — beş yuvalı kenar ızgarasının ("Kenar Rayı",
    // ui/mobile_ui.dart) hiçbirine ait değildi ve tema hissini en çok bozan tek
    // öğeydi. İçeriği (Kaydet / Ana menü) sağ ray'ın araçlar menüsüne taşındı.
    if (useCompactGameUi(context)) return const SizedBox.shrink();
    // Sol-ÜST (HUD şeridinin altında, Defter mührünün eski yeri) — Komuta
    // çubuğu artık alt kenarı sahiplendi, gear ondan uzağa taşındı. Küme AŞAĞI
    // açılır: gear üstte, öğeler altında.
    return Positioned(
      left: 14,
      top: 56,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gear tutamağı — her zaman görünür; kümeyi aç/kapa.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () =>
                  setStateHere(() => _menuClusterOpen = !_menuClusterOpen),
              child: SizedBox(
                child: Center(
                  child: AppChip(
                    label: _menuClusterOpen ? '⚙ Kapat' : '⚙ Menü',
                    color: AppUi.accent,
                  ),
                ),
              ),
            ),
            if (_menuClusterOpen) ...[
              const SizedBox(height: 10),
              // Ana menüye dönüş — onay ister, onaylanınca kaydedip çıkar.
              MenuButton(
                onTap: () => setStateHere(() => _exitConfirmOpen = true),
              ),
              const SizedBox(height: 10),
              SaveButton(onTap: () => _saveNow(manual: true)),
            ],
          ],
        ),
      ),
    );
  }

  /// Ana menüye dönüş onay modal'ı — yanlışlıkla çıkışı önler. Çıkış
  /// otomatik kaydeder, böylece oyuncu hiçbir ilerleme kaybetmez.
  Widget buildExitConfirm() {
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setStateHere(() => _exitConfirmOpen = false),
              child: Container(color: const Color(0x99000000)),
            ),
          ),
          Center(
            child: AppPanel(
              width: 320,
              accent: AppUi.accent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ana menüye dön', style: AppUi.title),
                  const SizedBox(height: 8),
                  Text(
                    'Köy otomatik kaydedilecek ve ana menüye döneceksin. '
                    'Kaldığın yerden devam edebilirsin.',
                    style: AppUi.body.copyWith(color: AppUi.textMid),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: 'Vazgeç',
                          kind: AppButtonKind.ghost,
                          onTap: () =>
                              setStateHere(() => _exitConfirmOpen = false),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppButton(
                          label: 'Kaydet ve Çık',
                          kind: AppButtonKind.filled,
                          onTap: _exitToMenu,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Kaydeder ve ana menüye döner.
  Future<void> _exitToMenu() async {
    setStateHere(() => _exitConfirmOpen = false);
    await _saveNow();
    widget.onExitToMenu?.call();
  }

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

    return {
      // ── Skaler sim state ──
      'time': _time,
      'worldSeed': _worldSeed,
      'dayCount': _dayCount,
      'lastTimeOfDay': _lastTimeOfDay,
      'timeOfDay': _cycle.timeOfDay,
      'camera': [_camera.dx, _camera.dy],
      'zoom': _zoom,
      'speedIdx': _speedIdx,
      'morale': _morale,
      'avgIndividualMorale': _avgIndividualMorale,
      'foodHunger': _foodHunger,
      'hasFire': _hasFire,
      'charterTier': _charterTier,
      'governanceLegacy': _governanceLegacy,
      'lastPopMilestone': _lastPopMilestone,
      'firstReedBedShown': _firstReedBedShown,
      'firepit': bRef(_firepitBuilding),
      'firekeeper': vRef(_firekeeper),

      // ── Harita + kaynaklar + sistemler ──
      'water': [
        for (final t in _waterTiles) [t.$1, t.$2],
      ],
      'stockpile': _stockpileToJson(),
      'policies': _policiesToJson(),
      'houses': _houses.toJson(),
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
      'knownCrafts': _knownCrafts.toList(),
      // Hikâye güncesi (yapısal) + başarımlar + sinematik durumu (anılar kalıcı).
      'storyLog': [for (final e in _storyLog) e.toJson()],
      'achievedMilestones': _achievedMilestones.toList(),
      'oreDiscovered': _oreDiscovered.toList(),
      'villageName': _villageName,
      'famineShown': _famineShown,
      'tierCutscenesShown': _tierCutscenesShown.toList(),
      'imperialFavor': _imperialFavor,
      'imperialTimer': _imperialTimer,
      // Sinematik merdiveni — yazılmazsa her yüklemede "ilk ziyaret" sanılır
      // ve film baştan oynar (tam da kaçındığımız tekrar).
      // Hane baskı sayacı — yazılmazsa yüklemede sert geçmiş silinir ve
      // oyuncu aynı haneyi sıfır bedelle yeniden sağabilir.
      'housePressure': _housePressure,
      'imperialVisits': _imperialVisits,
      'impGrudge': _impGrudge,
      'impGrimShown': _impGrimShown,

      // ── Varlıklar ──
      'buildings': [for (final b in _buildings) _buildingToJson(b)],
      'villagers': [for (final v in _villagers) _villagerToJson(v, bRef, vRef)],
      'orders': [for (final o in _orders) _orderToJson(o)],
      'roadOrders': [for (final o in _roadOrders) _roadOrderToJson(o)],
      'roads': [for (final t in _roadSystem.all) _roadTileToJson(t)],
      'farmTiles': [for (final t in _farmTiles) _farmTileToJson(t)],
      'trees': [for (final t in _trees) _treeToJson(t)],
      'mineNodes': [for (final n in _mineNodes) _mineNodeToJson(n)],
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
            'age': l.age,
            // Görülmüş olmak zulanın bulunabilirliğini belirler → kalıcı.
            'witnessed': l.witnessed,
            'culprit': vRef(l.culprit),
            'culpritName': l.culpritName,
          },
      ],

      // ── Dilekçe / meclis ──
      'pendingPetition': _pendingPetition?.id,
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
      'petitionForced': _petitionForced,
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
      'policyMoraleEffects': [
        for (final e in _policyMoraleEffects)
          {'untilSim': e.untilSim, 'amount': e.amount},
      ],
      'migrationTimerSec': _migrationTimerSec,
      'meteorShowerTimer': _meteorShowerTimer,
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
  };

  /// KANUNNAME — mühür seti + girilen dava kolu + ıslak mürekkep. Tek doğruluk
  /// kaynağı `sealed`; bool'lar yüklemede ondan türer (bkz. restoreSealed).
  Map<String, dynamic> _policiesToJson() => {
    'sealed': _policies.sealed.toList(),
    'inkDryUntilSim': _policies.inkDryUntilSim,
    // Gündeme gelmiş hüküm id'leri — yüklemede bütün defter "yeni açıldı"
    // diye bağırmasın diye taşınır (bkz. _tickLawGates).
    'lawSeen': _lawSeen.toList(),
  };

  Map<String, dynamic> _buildingToJson(BuildingEntity b) => {
    'type': b.type.name,
    'col': b.col,
    'row': b.row,
    'isActive': b.isActive,
    'userPaused': b.userPaused,
    'incomeTimer': b.incomeTimer,
    'waterLevel': b.waterLevel,
    'occupants': b.occupants,
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
      'state': v.state.name,
      'targetCol': v.targetCol,
      'targetRow': v.targetRow,
      'isFavorite': v.isFavorite,
      'wed': v.wed,
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
      // Kışlık giysi — köyün emeği; yükleyince sırtından düşmesin.
      if (v.hasCoat) 'hasCoat': true,
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

  Map<String, dynamic> _resourceBoxToJson(ResourceBox r) => {
    'type': r.type.name,
    'x': r.gridX,
    'y': r.gridY,
    'slotIndex': r.slotIndex,
  };

  Map<String, dynamic> _hayToJson(HayEntity h) => {
    'type': h.type.name,
    'x': h.gridX,
    'y': h.gridY,
    'slotIndex': h.slotIndex,
    'pileSize': h.pileSize,
    // spawnTime kayıtlıysa harmanın FIFO sırası ve düşme animasyonu
    // yüklemeden sonra da doğru kalır (_time de kaydediliyor).
    'spawnTime': h.spawnTime,
  };

  // ── Restore (JSON → state) ──────────────────────────────────────────────────

  /// Kaydedilmiş dünyayı geri kurar. initState'ten (asset yüklemeden önce)
  /// `_generateWorld` yerine çağrılır → setState KULLANMAZ.
  void restoreWorld(Map<String, dynamic> w) {
    // 1) Her şeyi temizle (generator'ın yaptığı scaffolding ama generator yok).
    _waterTiles.clear();
    _lotuses.clear();
    _reeds.clear();
    _reedBeds.clear();
    _berryBushes.clear();
    _cookedMeals = 0;
    _berriesPicked = 0;
    _decor.clear();
    _trees.clear();
    _cleared.clear();
    _wilderness.clear();
    _wildTreeTiles.clear();
    _mineNodes.clear();
    _buildings.clear();
    _orders.clear();
    _roadOrders.clear();
    _roadSystem.clear();
    _placingRoad = null;
    _roadErase = false;
    _clearRoadDrag();
    _cows.clear();
    _villagers.clear();
    _resourceBoxes.clear();
    _eggs.clear();
    _lootCaches.clear();
    _hayEntities.clear();
    _birdFlocks.clear();
    _beeSwarms.clear();
    _graves.clear();
    _petitionFollowUps.clear();
    _petitionCooldowns.clear();
    _villageMemory.clear();
    _knownCrafts.clear();
    _completedQuests.clear();
    _guideShown.clear();
    _coatsMade = 0;
    _coatPriority = CoatPriority.frail;
    _coldHouses.clear();
    _firstShearShown = false;
    _firstCoatShown = false;
    _winterDay = -1;
    _shearYear = -1;
    _winterEveDay = -1;
    _winterMurmurDay = -1;
    _guideOpen = false;
    _guideWanted = false;
    _guideStepId = '';
    _questVoiceWho = null;
    _questVoiceLine = '';
    _questVoiceLeft = 0;
    _storyLog.clear();
    _achievedMilestones.clear();
    _tierCutscenesShown.clear();
    _activeCutscene = null; // yüklenen oyunda sinematik oynamaz
    // İmparatorluk sinematik merdiveni — restore aşağıda okur; okunmazsa
    // (yeni oyun) sıfırdan başlar: ilk ziyaret yine tam film.
    _housePressure.clear();
    _betrothalForced = false;
    _imperialVisits = 0;
    _impGrudge = false;
    _impGrimShown = false;
    _policyMoraleEffects.clear();
    // Düğün kur state'i geçici — önceki oyundan sızmasın (çift _villagers
    // yeniden kurulduğunda eski ref'ler geçersiz). _weddingCouple aşağıda
    // pending'e göre yeniden bağlanır.
    _brideElect = null;
    _groomElect = null;
    _courtshipTimer = 0;
    _weddingScan = 0;
    // Omen (olay mayalanması) geçici — yüklemede sıfırla (yeni olay zamanla gelir).
    _omenEvent = null;
    _omenLeft = 0;
    _activeFx.clear();
    _stockpile.clear();
    _selectedBuilding = null;
    _selectedVillager = null;
    _followedVillager = null;
    _pendingChoice = null;
    _activeEvent = null;

    // 2) Skaler state.
    _time = _d(w['time']);
    _worldSeed = _i(w['worldSeed']);
    _dayCount = _i(w['dayCount'], 1);
    _lastTimeOfDay = _d(w['lastTimeOfDay']);
    _cycle.timeOfDay = _d(w['timeOfDay'], 0.45);
    final cam = w['camera'];
    if (cam is List && cam.length == 2) {
      _camera = Offset(_d(cam[0]), _d(cam[1]));
    }
    _zoom = _d(w['zoom'], 1.0);
    _speedIdx = _i(
      w['speedIdx'],
    ).clamp(0, _VillageSceneState._speedSteps.length - 1);
    _timeScale = _VillageSceneState._speedSteps[_speedIdx];
    _morale = _d(w['morale'], 0.5);
    _avgIndividualMorale = _d(w['avgIndividualMorale'], 0.6);
    _foodHunger = _d(w['foodHunger']);
    _hasFire = _b(w['hasFire']);
    _charterTier = _i(w['charterTier']);
    _governanceLegacy = _d(w['governanceLegacy']);
    _lastPopMilestone = _i(w['lastPopMilestone']);
    _firstReedBedShown = _b(w['firstReedBedShown']);

    // 3) Harita / kaynaklar / sistemler.
    for (final t in (w['water'] as List? ?? const [])) {
      if (t is List && t.length == 2) _waterTiles.add((_i(t[0]), _i(t[1])));
    }
    _restoreStockpile(w['stockpile']);
    _restorePolicies(w['policies']);
    if (w['houses'] is Map) {
      _houses.loadJson(Map<String, dynamic>.from(w['houses'] as Map));
    }
    for (final q in (w['completedQuests'] as List? ?? const [])) {
      _completedQuests.add(q as String);
    }
    for (final g in (w['guideShown'] as List? ?? const [])) {
      _guideShown.add(g as String);
    }
    _coatsMade = _i(w['coatsMade']);
    _coatPriority = CoatPriority.values.firstWhere(
      (c) => c.name == w['coatPriority'],
      orElse: () => CoatPriority.frail,
    );
    _firstShearShown = w['firstShearShown'] == true;
    _firstCoatShown = w['firstCoatShown'] == true;
    for (final s in (w['storyLog'] as List? ?? const [])) {
      // Yeni format = map; eski kayıt = düz string (gün bilinmez → 0).
      if (s is Map) {
        _storyLog.add(ChronicleEntry.fromJson(Map<String, dynamic>.from(s)));
      } else if (s is String) {
        _storyLog.add(ChronicleEntry(day: 0, icon: '📜', text: s));
      }
    }
    for (final m in (w['achievedMilestones'] as List? ?? const [])) {
      _achievedMilestones.add(m as String);
    }
    _oreDiscovered.clear();
    final ore = w['oreDiscovered'] as List?;
    if (ore == null) {
      // Eski kayıt: madenler bandsız (rastgele) üretilmişti → hepsi bilinir
      // say, yükleme sonrası sahte "damar bulundu" yağmasını önle.
      _oreDiscovered.addAll([for (final t in OreType.values) t.name]);
    } else {
      for (final t in ore) {
        _oreDiscovered.add(t as String);
      }
    }
    _villageName = (w['villageName'] as String?) ?? 'Köy';
    _imperialFavor = _d(w['imperialFavor'], 0.5);
    _imperialTimer = _d(w['imperialTimer'], 6.0 * kGameDaySeconds);
    _imperialDemand = null; // yüklemede aktif ziyaret yok
    final hp = w['housePressure'];
    if (hp is Map) {
      for (final e in hp.entries) {
        _housePressure[e.key as String] = _d(e.value);
      }
    }
    _imperialVisits = _i(w['imperialVisits']);
    _impGrudge = _b(w['impGrudge']);
    _impGrimShown = _b(w['impGrimShown']);
    _famineShown = _b(w['famineShown']);
    for (final t in (w['tierCutscenesShown'] as List? ?? const [])) {
      _tierCutscenesShown.add(_i(t));
    }
    for (final f in (w['villageMemory'] as List? ?? const [])) {
      _villageMemory.add(f as String);
    }
    for (final c in (w['knownCrafts'] as List? ?? const [])) {
      _knownCrafts.add(c as String);
    }

    // 4) Binalar (önce — referans hedefi).
    for (final raw in (w['buildings'] as List? ?? const [])) {
      _buildings.add(_buildingFromJson(Map<String, dynamic>.from(raw as Map)));
    }

    // 5) Köylüler — iki geçiş (önce yarat, sonra aile/ev bağla).
    final vJsons = <Map<String, dynamic>>[
      for (final raw in (w['villagers'] as List? ?? const []))
        Map<String, dynamic>.from(raw as Map),
    ];
    for (final vj in vJsons) {
      _villagers.add(_villagerFromJson(vj));
    }
    for (var i = 0; i < vJsons.length; i++) {
      final vj = vJsons[i];
      final v = _villagers[i];
      final homeIdx = _i(vj['home'], -1);
      if (homeIdx >= 0 && homeIdx < _buildings.length) {
        v.homeBuilding = _buildings[homeIdx];
      }
      for (final p in (vj['parents'] as List? ?? const [])) {
        final pi = _i(p, -1);
        if (pi >= 0 && pi < _villagers.length) v.parents.add(_villagers[pi]);
      }
      for (final c in (vj['children'] as List? ?? const [])) {
        final ci = _i(c, -1);
        if (ci >= 0 && ci < _villagers.length) v.children.add(_villagers[ci]);
      }
      for (final g in (vj['grudges'] as List? ?? const [])) {
        final gm = g as Map;
        final gi = _i(gm['v'], -1);
        if (gi >= 0 && gi < _villagers.length) {
          v.grudges[_villagers[gi]] = _d(gm['until']);
        }
      }
      // KANAAT — kime ne kadar güvendiği (bkz. villager_memory). Anıların
      // kendisi kaydedilmez (zaten söner); kalıcı olan bu iz.
      for (final o in (vj['opinion'] as List? ?? const [])) {
        final om = o as Map;
        final oi = _i(om['v'], -1);
        if (oi >= 0 && oi < _villagers.length) {
          v.memory.opinion[_villagers[oi]] = _d(om['o']);
        }
      }
      for (final e in (vj['bloodEnemies'] as List? ?? const [])) {
        final ei = _i(e, -1);
        if (ei >= 0 && ei < _villagers.length) {
          v.bloodEnemies.add(_villagers[ei]);
        }
      }
    }

    // 5b) ESKİ KAYIT GÖÇÜ — soyadsız köylüleri hanelere bağla.
    _migrateHouseholdSurnames();

    // 6) Referans wiring (firepit / firekeeper).
    final fpIdx = _i(w['firepit'], -1);
    _firepitBuilding = (fpIdx >= 0 && fpIdx < _buildings.length)
        ? _buildings[fpIdx]
        : null;
    final fkIdx = _i(w['firekeeper'], -1);
    _firekeeper = (fkIdx >= 0 && fkIdx < _villagers.length)
        ? _villagers[fkIdx]
        : null;

    // 7) Hayvanlar. (Eski işçi dizileri — builders/farmers/miners/fishers/
    // florists/shepherds/woodcutters/lumberCamps — artık YOK SAYILIR: işçiler
    // gerçek köylü işine dönüştü [scene_jobs]. İş kaynakları [_orders/_farmTiles/
    // _mineNodes...] bağımsız kalıcı; açılışta _syncJobWorkforce köylüleri atar.
    // Eski kayıt hatasız yüklenir, yetim/donmuş avatar kalmaz.)
    for (final raw in (w['animals'] as List? ?? const [])) {
      _cows.add(_animalFromJson(Map<String, dynamic>.from(raw as Map)));
    }

    // 8) Dünya nesneleri.
    for (final raw in (w['orders'] as List? ?? const [])) {
      _orders.add(_orderFromJson(Map<String, dynamic>.from(raw as Map)));
    }
    for (final raw in (w['roadOrders'] as List? ?? const [])) {
      _roadOrders.add(
        _roadOrderFromJson(Map<String, dynamic>.from(raw as Map)),
      );
    }
    for (final raw in (w['roads'] as List? ?? const [])) {
      final j = Map<String, dynamic>.from(raw as Map);
      _roadSystem.add(
        RoadTile(
          col: _i(j['col']),
          row: _i(j['row']),
          surface: _enumByName(
            RoadSurface.values,
            j['surface'],
            RoadSurface.dirt,
          ),
        ),
      );
    }
    for (final raw in (w['farmTiles'] as List? ?? const [])) {
      _farmTiles.add(_farmTileFromJson(Map<String, dynamic>.from(raw as Map)));
    }
    for (final raw in (w['trees'] as List? ?? const [])) {
      _trees.add(_treeFromJson(Map<String, dynamic>.from(raw as Map)));
    }
    for (final raw in (w['mineNodes'] as List? ?? const [])) {
      _mineNodes.add(_mineNodeFromJson(Map<String, dynamic>.from(raw as Map)));
    }
    // Reveal artık KAMERA KISITI (zoom) — arazi örtüsü yok. Eski kayıtlardaki
    // 'cleared' alanı yok sayılır; land setleri boş kalır (scene_land).
    for (final raw in (w['lotuses'] as List? ?? const [])) {
      final j = Map<String, dynamic>.from(raw as Map);
      _lotuses.add(
        LotusEntity(
          col: _i(j['col']),
          row: _i(j['row']),
          variant: _i(j['variant']),
        ),
      );
    }
    for (final raw in (w['reeds'] as List? ?? const [])) {
      final j = Map<String, dynamic>.from(raw as Map);
      _reeds.add(
        ReedClump(
          col: _i(j['col']),
          row: _i(j['row']),
          col2: _i(j['col2']),
          row2: _i(j['row2']),
          growth: _d(j['growth'], 1.0),
        ),
      );
    }
    for (final raw in (w['berryBushes'] as List? ?? const [])) {
      final j = Map<String, dynamic>.from(raw as Map);
      _berryBushes.add(
        BerryBush(
          col: _i(j['col']),
          row: _i(j['row']),
          variant: _i(j['variant']),
          ripeness: _d(j['ripe'], 1.0),
        ),
      );
    }
    _cookedMeals = _i(w['cookedMeals']);
    _berriesPicked = _i(w['berriesPicked']);
    _firstMealShown = _b(w['firstMealShown']);
    for (final raw in (w['decor'] as List? ?? const [])) {
      _decor.add(_decorFromJson(Map<String, dynamic>.from(raw as Map)));
    }
    for (final raw in (w['graves'] as List? ?? const [])) {
      _graves.add(_graveFromJson(Map<String, dynamic>.from(raw as Map)));
    }
    for (final raw in (w['reedBeds'] as List? ?? const [])) {
      final j = Map<String, dynamic>.from(raw as Map);
      final bed = ReedBed(gridX: _d(j['x']), gridY: _d(j['y']));
      final oi = _i(j['owner'], -1);
      if (oi >= 0 && oi < _villagers.length) bed.owner = _villagers[oi];
      _reedBeds.add(bed);
    }
    for (final raw in (w['resourceBoxes'] as List? ?? const [])) {
      final j = Map<String, dynamic>.from(raw as Map);
      _resourceBoxes.add(
        ResourceBox(
          type: _enumByName(
            ResourceBoxType.values,
            j['type'],
            ResourceBoxType.woodChunk,
          ),
          gridX: _d(j['x']),
          gridY: _d(j['y']),
        )..slotIndex = _i(j['slotIndex']),
      );
    }
    for (final raw in (w['hay'] as List? ?? const [])) {
      final j = Map<String, dynamic>.from(raw as Map);
      _hayEntities.add(
        HayEntity(
            type: _enumByName(HayType.values, j['type'], HayType.pile),
            gridX: _d(j['x']),
            gridY: _d(j['y']),
          )
          ..slotIndex = _i(j['slotIndex'])
          ..pileSize = _i(j['pileSize'], 1)
          ..spawnTime = _d(j['spawnTime']),
      );
    }
    // Gömülü zulalar — mal toprakta durmaya devam eder. Fail indeksi
    // çözülemezse (ölmüş/sürülmüş) zula SAHİPSİZ döner: mal hâlâ bulunabilir
    // ama kimseyi suçlamaz (bkz. `_forgetLootOwner` ile aynı sözleşme).
    for (final raw in (w['lootCaches'] as List? ?? const [])) {
      final j = Map<String, dynamic>.from(raw as Map);
      final ci = _i(j['culprit'], -1);
      _lootCaches.add(
        LootCache(
            gridX: _d(j['x']),
            gridY: _d(j['y']),
            kind: _enumByName(
              ResourceKind.values,
              j['kind'],
              ResourceKind.food,
            ),
            amount: _i(j['amount']),
            culpritName: '${j['culpritName'] ?? ''}',
            culprit: (ci >= 0 && ci < _villagers.length)
                ? _villagers[ci]
                : null,
          )
          ..age = _d(j['age'])
          ..witnessed = _b(j['witnessed']),
      );
    }

    // 9) Dilekçe / meclis.
    final pid = w['pendingPetition'];
    _pendingPetition = pid is String ? PetitionSystem.byId(pid) : null;
    final paIdx = _i(w['petitionAuthor'], -1);
    _petitionAuthor = (paIdx >= 0 && paIdx < _villagers.length)
        ? _villagers[paIdx]
        : null;

    // 9b) Suç durumu. Yürüyen suç + rehin kaydedilmez (anlık sahne) → yalnız
    // kalıcı olan geri gelir: şüphe defteri, af sayacı, hüküm bekleyen fail.
    _activeCrime = null;
    _ransomVictim = null;
    _crimePollSec = 0;
    _chaseRefresh = 0;
    _unrest = _d(w['unrest']).clamp(0.0, 1.0);
    _regimeRot = _d(w['regimeRot']).clamp(0.0, 1.0);
    _chronicShown = w['chronicShown'] == true;
    _crisisCooldown = _d(w['crisisCooldown']);
    _unrestStirShown = w['unrestStirShown'] == true;
    _regimeScan = 0;
    _regimeCrisisUnrest = const {};
    _crimeSuspicion = _i(w['crimeSuspicion']);
    _crimePardons = _i(w['crimePardons']);
    // Eski kayıtta yok — o köyün suç geçmişi bilinmiyor. Affedilen/şüphe kadarı
    // en azından bir şey olduğunu söylüyor; sıfırdan iyi bir alt sınır.
    _crimesSeen = _i(w['crimesSeen'], _crimeSuspicion + _crimePardons);
    // Eski kayıtta yok — mezar/husumet varsa köy bunları görmüş demektir; hüküm
    // gündemi sıfırdan başlamasın diye dünyadan bir alt sınır türetilir.
    _illnessSeen = _i(w['illnessSeen'], _graves.length);
    _feudsSeen = _i(w['feudsSeen'], _villagers.any((v) => v.inFeud) ? 1 : 0);
    final acIdx = _i(w['accusedCriminal'], -1);
    _accusedCriminal = (acIdx >= 0 && acIdx < _villagers.length)
        ? _villagers[acIdx]
        : null;
    // Dayanağı kalmayan dilekçeyi at: rehin kaydedilmediği için fidye kararı
    // anlamsız; sanığı bulunamayan yargı dilekçesi de öyle.
    if (_pendingPetition?.id == 'ransom' ||
        (_pendingPetition?.id == 'crimeVerdict' && _accusedCriminal == null)) {
      _pendingPetition = null;
      _accusedCriminal = null;
    }
    // Kayıttaki dilekçe HAM hâliyle döner (havuz + yer tutucu). Modal'a ham
    // `{ad}` göstermemek için yeniden konuştur — tohum gün+id olduğundan
    // kayıttan önce okunan cümlenin AYNISI çıkar.
    _petitionExtra = {
      for (final e in (w['petitionExtra'] as Map? ?? const {}).entries)
        '${e.key}': '${e.value}',
    };
    final restored = _pendingPetition;
    if (restored != null) {
      _pendingPetition = restored.spoken(
        _voice(
          _petitionAuthor,
          seed: _petitionSeed(restored),
          extra: _petitionExtra,
        ),
      );
    } else {
      _petitionExtra = const {};
    }

    _petitionTimer = _d(w['petitionTimer'], 1.0 * kGameDaySeconds);
    _petitionDeadline = _d(w['petitionDeadline']);
    _petitionModalOpen = _b(w['petitionModalOpen']) && _pendingPetition != null;
    _petitionForced = _b(w['petitionForced']) && _pendingPetition != null;
    // Bekleyen düğünün çifti — kayıttaki İKİ İNDEKSTEN geri bağlanır, yeniden
    // seçilmez. Biri artık yoksa (eski kayıt / bozuk indeks) çift kurulmaz ve
    // dilekçe konusuz kalır → `_tickWedding` onu masadan kaldırır. Uydurma bir
    // çift bağlamak, oyuncunun okuduğundan başkasını evlendirmek demekti.
    _weddingCouple = null;
    if (_pendingPetition?.id == 'villageWedding') {
      final wc = w['weddingCouple'];
      if (wc is List && wc.length == 2) {
        final bi = _i(wc[0], -1), gi = _i(wc[1], -1);
        if (bi >= 0 &&
            bi < _villagers.length &&
            gi >= 0 &&
            gi < _villagers.length) {
          _weddingCouple = (_villagers[bi], _villagers[gi]);
        }
      }
    }
    for (final raw in (w['petitionFollowUps'] as List? ?? const [])) {
      final j = Map<String, dynamic>.from(raw as Map);
      final ai = _i(j['actor'], -1);
      _petitionFollowUps.add((
        id: j['id'] as String,
        fireAtSim: _d(j['fireAtSim']),
        actor: (ai >= 0 && ai < _villagers.length) ? _villagers[ai] : null,
        actorName: (j['actorName'] as String?) ?? '',
      ));
    }
    final cds = w['petitionCooldowns'];
    if (cds is Map) {
      cds.forEach((k, v) => _petitionCooldowns[k as String] = _d(v));
    }

    // 10) Olay / politika moral / ambient.
    _eventTimer = _d(w['eventTimer'], kEventFirstDelay);
    _eventMorale = _d(w['eventMorale']);
    _eventMoraleLeft = _d(w['eventMoraleLeft']);
    _eventLabel = w['eventLabel'] as String?;
    for (final raw in (w['policyMoraleEffects'] as List? ?? const [])) {
      final j = Map<String, dynamic>.from(raw as Map);
      _policyMoraleEffects.add((
        untilSim: _d(j['untilSim']),
        amount: _d(j['amount']),
      ));
    }
    _migrationTimerSec = _d(w['migrationTimerSec']);
    _meteorShowerTimer = _d(w['meteorShowerTimer'], 4.0 * kGameDaySeconds);

    // 11) Türetilmiş yapıları yeniden kur.
    // Reach kayda GİRMEZ — bina/görevden türer. Snap'lemezsek `_kSpanStart`ten
    // başlayıp 1.2/sn tırmanır: oturmuş bir köyü açınca kamera dakikalarca
    // kendiliğinden geri çekilir. Hedefe doğrudan otur (referans köy de aynısını
    // yapar; hesap tek yerde: `_landExpansionTarget`).
    _reachSpan = _landExpansionTarget;
    _applyPolicySideChannels();
    _pathContext.bumpVersion();
    _anchorSystem.rebuild(_buildings);
    _rebuildSpatialCaches();
    _rebuildBeeSwarms();
    // İş yerleri türetilmiş yapılara (bina/tarla/sipariş) dayandığı için mühür
    // devri BURADA, hepsi kurulduktan sonra olur. Yer bilmeyen eski kayıtlar
    // bugünkü iş yerlerine bağlanır.
    _adoptLegacyAssignments();
    _groundVersion++;
    _spatialTimer = 0.0;
  }

  void _restoreStockpile(Object? j) {
    if (j is! Map) return;
    _stockpile.wood = _i(j['wood']);
    _stockpile.stone = _i(j['stone']);
    _stockpile.iron = _i(j['iron']);
    _stockpile.coal = _i(j['coal']);
    _stockpile.food = _i(j['food']);
    _stockpile.honey = _i(j['honey']);
    _stockpile.reed = _i(j['reed']);
    _stockpile.wool = _i(j['wool']);
    _stockpile.gold = _i(j['gold']);
  }

  void _restorePolicies(Object? j) {
    if (j is! Map) return;
    final ids = (j['sealed'] as List?)?.whereType<String>() ?? const <String>[];
    // 'path' eski kayıtlarda vardı (dava kolu) — artık yok, sessizce yok sayılır.
    _policies.restoreSealed(ids);
    _policies.inkDryUntilSim = _d(j['inkDryUntilSim']);
    _lawSeen
      ..clear()
      ..addAll(
        (j['lawSeen'] as List?)?.whereType<String>() ?? const <String>[],
      );
    // Eski kayıtta liste yok → ilk tarama sessiz geçsin (o köyün gündemi zaten
    // oluşmuş, hepsini "yeni" diye duyurmak yanlış olur).
    _lawSeeded = false;
    _lawCtxCache = null;
    _lawCtxAge = 0;
  }

  /// Ada göre enum — eşleşmezse null (dava seçilmemiş kayıtlar için).
  BuildingEntity _buildingFromJson(Map<String, dynamic> j) {
    final b = BuildingEntity(
      type: _enumByName(BuildingType.values, j['type'], BuildingType.firepit),
      col: _i(j['col']),
      row: _i(j['row']),
    );
    b.isActive = _b(j['isActive']);
    b.userPaused = _b(j['userPaused']);
    b.incomeTimer = _d(j['incomeTimer']);
    b.waterLevel = _d(j['waterLevel'], 1.0);
    b.occupants = _i(j['occupants']);
    b.ownerSurname = (j['ownerSurname'] as String?) ?? '';
    b.eggTimer = _d(j['eggTimer']);
    b.honeyTimer = _d(j['honeyTimer']);
    b.fireFuel = _d(j['fireFuel'], 1.0);
    b.millRotorAngle = _d(j['millRotorAngle']);
    return b;
  }

  VillagerEntity _villagerFromJson(Map<String, dynamic> j) {
    final visual = _visualFromJson(
      Map<String, dynamic>.from(j['visual'] as Map),
    );
    final v = VillagerEntity(
      type: _enumByName(VillagerType.values, j['type'], VillagerType.farmer),
      name: (j['name'] as String?) ?? 'Köylü',
      male: visual.isMale,
      startCol: _d(j['spawnCol']),
      startRow: _d(j['spawnRow']),
      visual: visual,
      personalitySeed: (j['personalitySeed'] as num?)?.toInt(),
      ageDays: _d(j['ageDays']),
      lifespanDays: j['lifespanDays'] == null
          ? double.infinity
          : _d(j['lifespanDays']),
    );
    v.annivCount = _i(j['annivCount']);
    v.hasCoat = j['hasCoat'] == true;
    // Eski kayıtta yoksa: yetişkin/yaşlı zaten çağrısını bulmuş say (an tekrar
    // tetiklenmesin); çocuk/genç ise büyürken keşfedecek.
    v.callingFound = _b(j['callingFound'], v.ageDays >= kAdultStartDay);
    // Eski kayıtta yoksa: genç+ zaten büyümüş say (an tekrar tetiklenmesin).
    v.grewUpMoment = _b(j['grewUpMoment'], v.ageDays >= kYouthStartDay);
    v.gridX = _d(j['x']);
    v.gridY = _d(j['y']);
    v.renderX = v.gridX;
    v.renderY = v.gridY;
    // Kayıttan dönen köylü "zaten öyle duruyordu" — dönüş animasyonu oynamasın
    // (yoksa yükleme anında köyün yarısı yerinde takla atar).
    v.loco.snapFacing(_b(j['facingRight'], true));
    v.state = _enumByName(VillagerState.values, j['state'], VillagerState.idle);
    v.targetCol = _d(j['targetCol'], v.gridX);
    v.targetRow = _d(j['targetRow'], v.gridY);
    v.isFavorite = _b(j['isFavorite']);
    v.wed = _b(j['wed']);
    // Üstlenilmiş iş rolü — atama detayı (claim/faz) _syncJobWorkforce'la kurulur.
    final jobRole = j['jobRole'] as String?;
    if (jobRole != null) {
      final role = _enumByName(JobRole.values, jobRole, JobRole.none);
      if (role != JobRole.none) v.job = VillagerJob(role);
    }
    // Oyuncunun elle kilitlediği iş. Anahtar YOKSA null kalır (otomatik havuz);
    // `none` yazılıysa bilinçli "boş dursun" kararıdır ve korunur — bu yüzden
    // burada `jobRole`'daki gibi none'ı eleyen bir kapı YOK.
    final assigned = j['assignedRole'] as String?;
    if (assigned != null) {
      v.assignedRole = _enumByName(JobRole.values, assigned, JobRole.none);
    }
    // İş yeri mührü. ESKİ KAYITTA YOK: rol var, yer yok. O köylüler
    // `_adoptLegacyAssignments` ile yükleme sonunda rolüne uyan en yakın yere
    // yazılır — kadro sessizce dağılmasın.
    v.assignedSiteId = j['assignedSite'] as String?;
    v.surname = (j['surname'] as String?) ?? '';
    v.injuryDays = _d(j['injuryDays']);
    v.sickDays = _d(j['sickDays']);
    v.laborDays = _d(j['laborDays']);
    v.disabled = _b(j['disabled']);
    v.feudKills = _i(j['feudKills']);
    v.crimeCount = _i(j['crimeCount']);
    for (final e in (j['life'] as List? ?? const [])) {
      if (e is Map) {
        v.life.add(ChronicleEntry.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    v.fertilityDays = j['fertilityDays'] == null
        ? double.nan
        : _d(j['fertilityDays']);
    v.birthCount = _i(j['birthCount']);
    v.isSage = _b(j['isSage']);
    v.mood = _d(j['mood']);
    v.energy = _d(j['energy'], 1.0);
    v.morale = _d(j['morale'], 0.6);
    if (j['drives'] case final Map<String, dynamic> d) v.mind.restore(d);
    v.lowMoraleTime = _d(j['lowMoraleTime']);
    v.moraleReason = (j['moraleReason'] as String?) ?? 'huzurlu';
    // Eski kayıtta servet yok → yetişkinlere makul bir taban ver (0'da kalmasın).
    v.wealth = _d(j['wealth'], v.ageDays >= kAdultStartDay ? 30 : 0);
    final rawMastery = j['mastery'];
    if (rawMastery is Map) {
      rawMastery.forEach((k, val) => v.mastery[k as String] = _d(val));
    }
    return v;
  }

  AnimalEntity _animalFromJson(Map<String, dynamic> j) {
    final a = AnimalEntity(
      kind: _enumByName(AnimalKind.values, j['kind'], AnimalKind.cow),
      barnCol: _i(j['barnCol']),
      barnRow: _i(j['barnRow']),
      startCol: _d(j['x']),
      startRow: _d(j['y']),
      isMale: _b(j['isMale'], false),
      // Eski kayıtlarda yaş yok → yetişkin varsay (default ctor değeri).
      ageDays: j['ageDays'] == null
          ? AnimalEntity.kAnimalAdultDay
          : _d(j['ageDays']),
      lifespanDays: j['lifespanDays'] == null ? null : _d(j['lifespanDays']),
    );
    a.hunger = _d(j['hunger']);
    a.milkProgress = _d(j['milkProgress']);
    a.facingRight = _b(j['facingRight'], true);
    a.facing4 = _enumByName(AnimalFacing.values, j['facing4'], AnimalFacing.s);
    final fert = j['fertilityDays'];
    if (fert != null) a.fertilityDays = _d(fert);
    return a;
  }

  BuildOrder _orderFromJson(Map<String, dynamic> j) {
    final o = BuildOrder(
      type: _enumByName(BuildingType.values, j['type'], BuildingType.firepit),
      col: _i(j['col']),
      row: _i(j['row']),
    );
    o.crew = 0; // geçici — builder yeniden talep eder
    o.completed = _b(j['completed']);
    o.progress = _d(j['progress']);
    return o;
  }

  RoadOrder _roadOrderFromJson(Map<String, dynamic> j) {
    final o = RoadOrder(
      col: _i(j['col']),
      row: _i(j['row']),
      surface: _enumByName(RoadSurface.values, j['surface'], RoadSurface.dirt),
    );
    o.assigned = false;
    o.completed = _b(j['completed']);
    o.progress = _d(j['progress']);
    return o;
  }

  FarmTile _farmTileFromJson(Map<String, dynamic> j) {
    final t = FarmTile(_i(j['col']), _i(j['row']));
    t.stage = _i(j['stage']);
    t.growthProgress = _d(j['growthProgress']);
    // Eski kayıtlarda ekim yoktu — tarlalar ekili sayılır (yükleyince köy
    // birden çıplak toprağa dönmesin).
    t.needsSowing = j['needsSowing'] as bool? ?? false;
    t.fallowRemaining = _d(j['fallow']);
    return t;
  }

  TreeEntity _treeFromJson(Map<String, dynamic> j) {
    final t = TreeEntity(
      col: _i(j['col']),
      row: _i(j['row']),
      type: _enumByName(TreeType.values, j['type'], TreeType.pine),
      isGrowing: _b(j['growing']),
      isWild: _b(j['wild']),
    );
    t.isMarkedForCutting = _b(j['marked']);
    t.isFelled = _b(j['felled']);
    t.fellAge = _d(j['fellAge']);
    t.fallDirection = _i(j['fallDirection'], 1) < 0 ? -1 : 1;
    t.fallImpactEmitted = _b(j['fallImpactEmitted']);
    return t;
  }

  MineNode _mineNodeFromJson(Map<String, dynamic> j) {
    final n = MineNode(
      col: _i(j['col']),
      row: _i(j['row']),
      type: _enumByName(OreType.values, j['type'], OreType.stone),
    );
    n.isMarkedForMining = _b(j['marked']);
    n.isDepleted = _b(j['depleted']);
    return n;
  }

  DecorEntity _decorFromJson(Map<String, dynamic> j) => DecorEntity(
    col: _i(j['col']),
    row: _i(j['row']),
    kind: _enumByName(DecorKind.values, j['kind'], DecorKind.daisy),
    variant: _i(j['variant']),
    jitterX: _d(j['jitterX']),
    jitterY: _d(j['jitterY']),
    swaySeed: _i(j['swaySeed']),
  );

  Grave _graveFromJson(Map<String, dynamic> j) => Grave(
    col: _d(j['col']),
    row: _d(j['row']),
    variant: _i(j['variant']),
    name: (j['name'] as String?) ?? '',
    jitterX: _d(j['jitterX']),
    jitterY: _d(j['jitterY']),
  );
}
