part of '../main.dart';

/// Dilekçe / Meclis sistemi — köy periyodik olarak senden bir şey ister,
/// sen karar verirsin. Yönetişimin omurgası: pasif toggle yerine akan karar.
///
/// Mühlet ritmi: dilekçe gelince DOĞRUDAN ekrana gelir (modal hemen açılır) —
/// köy yüz yüze konuşur, kopuk bir bildirim ikonu değil. Oyun DURMAZ (ambient):
/// boşluğa dokununca modal kapanır, dilekçe HUD mührüne iner + tükenen mühlet
/// halkası sakin sakin işler (sonra mühre tıklayıp tekrar açarsın). Mühlet
/// dolarsa modal ZORLA tam-ekran açılır + sim duraklar — görmezden gelinemez.
/// Bekletmenin bedeli var (zümre küser + moral dip), ama karar yine oyuncunundur.
///
/// Bağımlı sistemler: PetitionSystem (üretim), pushPolicyMorale (geçici moral),
/// _applyPolicySideChannels + _policies (yasa yürürlüğe), _attachFxTargets (fx).
extension _ScenePetitions on _VillageSceneState {
  /// İki dilekçe arası bekleme (sn) — ~1.5 oyun günü.
  static const double _kPetitionInterval = 1.5 * kGameDaySeconds;
  /// Mühlet (sn) — ~2 oyun günü sakin yanıt penceresi; dolunca zorunlu huzur.
  static const double _kPetitionGrace = 2.0 * kGameDaySeconds;
  /// Mühletin son bu oranı = "sıkışma" — mühür kızarır, nabız hızlanır.
  static const double _kPetitionUrgentFrac = 0.30;
  /// Çözülen dilekçenin tekrar random çıkmaması için hafıza cooldown'u.
  static const double _kPetitionRepeatCooldown = 4.0 * kGameDaySeconds;

  void _tickPetitions(double dt) {
    // Köy kurulmadan / nüfus çok azken dilekçe yok.
    if (!_hasFire || _villagers.length < 2) return;
    // KADEMELİ UYANIŞ (bkz. scene_flow): köy kendi ayakları üstünde durmadan
    // yönetişim başlamaz. Zorunlu huzur/suç yargısı gibi OLAY-güdümlü çağrılar
    // `_presentPetition`'a doğrudan gider, bu kapıdan geçmez — yani bekleyen
    // bir karar varsa yine de önüne gelir.
    if (!_governanceAwake && _pendingPetition == null) return;

    if (_pendingPetition != null) {
      // Zorunlu huzura geçtiyse mühlet işlemez (modal zaten açık, sim duraklı).
      if (_petitionForced) return;
      _petitionDeadline -= dt;
      if (_petitionDeadline <= 0) _deadlineReached();
      return;
    }

    // TEK SÖZ FERMANI (NİZAM son basamağı) — köy artık senden bir şey İSTEMEZ.
    // Dilekçe yazan divan lağvedildi; köyün İSTEK kanalı (random roll + zincir)
    // kapanır. Suç yargısı ve fidye gibi OLAY-güdümlü çağrılar (_presentPetition
    // doğrudan) devam eder — onlar köyün ricası değil, senin hükmünü bekleyen
    // vakıalar. Sessizliğin bedeli fermanın kendisinde: moral yavaşça sızar.
    if (_policies.sealed.contains('nizam.sole')) return;

    // Önce zamanı gelen takip dilekçesi (zincir) — random'dan öncelikli.
    for (int i = 0; i < _petitionFollowUps.length; i++) {
      if (_petitionFollowUps[i].fireAtSim <= _time) {
        final link = _petitionFollowUps[i];
        _petitionFollowUps.removeAt(i);
        final p = PetitionSystem.byId(link.id);
        if (p != null) {
          // Aktör hâlâ köyde mi: varsa zinciri O sürdürür. Yoksa dilekçeyi
          // başkası getirir ama adı metinde durur ({giden}) — kaybın kendisi
          // zincirin bir dalıdır.
          final alive = link.actor != null &&
              !link.actor!.isDying &&
              _villagers.contains(link.actor);
          _presentPetition(
            p,
            author: alive ? link.actor : null,
            extra: {
              'giden': link.actorName,
              'gidenDurum': alive ? 'döndü' : 'dönmedi',
            },
          );
          return;
        }
        break;
      }
    }

    _petitionTimer -= dt;
    if (_petitionTimer > 0) return;
    _petitionTimer = _petitionInterval();

    // Yakında çözülmüş (cooldown'daki) dilekçeleri random'dan çıkar.
    final blocked = <String>{
      for (final e in _petitionCooldowns.entries)
        if (e.value > _time) e.key,
    };
    final p = PetitionSystem.roll(_buildPetitionContext(), _rng, blocked: blocked);
    if (p == null) return; // uygun dilekçe yok — bir sonraki turda tekrar dene
    _presentPetition(p);
  }

  /// Bir dilekçeyi sunar — DOĞRUDAN ekrana getirir (modal hemen açılır). Küçük
  /// bir mühür-bildirimi ikonu değil; köy kapına gelmiştir, yüz yüzedir. Yine de
  /// oyunu DURDURMAZ (ambient): boşluğa dokununca modal kapanır, dilekçe HUD
  /// mührüne iner ve mühlet sakin sakin işlemeye devam eder (sonra tekrar açarsın
  /// ya da mühlet dolunca zorunlu huzur gelir).
  /// [author] verilirse sözcü seçimi atlanır ve dilekçeyi O köylü getirir (ör.
  /// suç yargısında mağdur/tanık — fail değil). [extra] metne ek bağlam dokur
  /// (`{suçlu}`, `{suç}` gibi dilekçeye özel yer tutucular).
  void _presentPetition(Petition rawPetition,
      {VillagerEntity? author, Map<String, String> extra = const {}}) {
    AudioManager.instance.playSfx(Sfx.bellChime);
    if (author != null && !author.isDying) {
      _petitionAuthor = author;
      final (cc, cr) = _villageCenter();
      author.lookToward(cc.toDouble(), cr.toDouble());
    } else {
      _summonSpokesperson(rawPetition); // diegetik: sözcü merkeze döner (+_petitionAuthor)
    }
    _petitionExtra = extra;
    // Dilekçeyi KONUŞTUR: havuzdan varyant seç + sözcünün adı/mesleği/hanesi,
    // mevsim ve gün metne dokunsun. Tohum gün+id'den türer → modalı kapatıp
    // açınca ya da kayıttan dönünce aynı cümle okunur.
    final p = rawPetition.spoken(
      _voice(_petitionAuthor, seed: _petitionSeed(rawPetition), extra: extra),
    );
    setStateHere(() {
      _pendingPetition   = p;
      _petitionForced    = false;
      _petitionDeadline  = _kPetitionGrace;
      _petitionModalOpen = true; // gelir gelmez ekranda — kopuk bildirim değil
    });
    _showNotification('📜 ${p.petitioner} bir dilekçe sundu');
  }

  /// Bir zümrenin "küskün" (sullen) sayılması için mood eşiği — bunun altında
  /// o zümre ısrarla dilekçe gönderir + dilekçe sıklığı artar.
  static const double _kSullenMood = 0.40;

  /// Şu an küskün (sullen eşiği altı) HANENİN baskın meslek-zümresi — estate-
  /// etiketli grievance dilekçelerini "hangi hane küskün"e göre besler. Yoksa null.
  Estate? _sullenEstate() {
    final s = _houses.mostAggrieved;
    if (s == null || _houses.moodOf(s) >= _kSullenMood) return null;
    return _dominantEstateOfHouse(s);
  }

  /// Dilekçeler arası bekleme — SABİT.
  ///
  /// Eskiden küskün bir hane varsa ×0.6 (dilekçeler %40 hızlanırdı) → köy seni
  /// "aileleri dengede tut" oyununa zorluyordu: bir hane küsünce üstüne dilekçe
  /// yağardı. Kullanıcı kararı: aileler arası denge ZORUNLU olmasın. Küskün hane
  /// hâlâ dilekçe yazabilir (anlatı), ama seni cezalandıran bir baskı üretmez.
  double _petitionInterval() => _kPetitionInterval;

  /// Köyün anlık durumunu dilekçe koşulları için derler.
  PetitionContext _buildPetitionContext() {
    int adults = 0;
    for (final v in _villagers) {
      if (v.lifeStage != LifeStage.elder &&
          v.lifeStage != LifeStage.child &&
          v.hasProfession) {
        adults++;
      }
    }
    // Sürü durumu — yem sıkıntısı / hayvan dilekçelerinin kapısı.
    int herd = 0;
    double hungerSum = 0;
    for (final c in _cows) {
      if (c.isDying) continue;
      herd++;
      hungerSum += c.hunger;
    }
    final herdHungry = herd > 0 && hungerSum / herd > 0.5;
    return PetitionContext(
      population: _villagers.length,
      adults: adults,
      food: _stockpile.food,
      gold: _stockpile.gold,
      morale: _stats.morale,
      hasChurch: _churchBuilding != null,
      memory: _villageMemory,
      aggrievedEstate: _sullenEstate(),
      ascendant: _houses.ascendant == null
          ? null
          : _dominantEstateOfHouse(_houses.ascendant!),
      herdSize: herd,
      herdHungry: herdHungry,
      season: _season,
      hasCrops: _farmTiles.any((t) => t.isGrowing || t.readyToHarvest),
      hasResentful: _resentfulVillager() != null,
      hasFeud: _feudMember() != null,
      // Meçhul kalan suçların biriktirdiği şüphe → asayiş dilekçesinin kapısı.
      crimeSuspicion: _crimeSuspicion,
      // Politika↔dilekçe köprüsü: yürürlükteki yasalar sosyal karşılık doğurur.
      cropRotation: _policies.cropRotation,
      hospitality: _policies.hospitality,
      hasHousing: _buildings.any((b) =>
          b.fn?.role == BuildingRole.housing &&
          _villagers.where((v) => v.homeBuilding == b).length <
              b.fn!.housingCapacity),
      // ── OLGUNLUK — köyün yaşlandığını dilekçe sistemi de görsün ───────────
      dayCount: _dayCount,
      // Kurucu kuşak: köyde DOĞMAMIŞ (dışarıdan gelmiş/başlangıçta var olan)
      // yetişkin kaldı mı. Hepsi gidince köy kendi başlangıcını hatırlamıyor.
      foundersAlive: _villagers.any((v) => !v.isDying && v.parents.isEmpty),
      houseCount: _houses.houseCount,
      dominantSway: _dominantHouseShare(),
      sealedLaws: _policies.sealed.length,
      regime: _regimeIdentity.regime,
      unrest: _unrest,
      craftLost: _villageMemory.contains('craft.lost'),
      imperialVisits: _imperialVisits,
      governanceLegacy: _governanceLegacy,
    );
  }

  /// En güçlü hanenin köy içindeki nüfuz payı 0..1 — tek hane köyü gölgesine
  /// aldığında bunun sosyal karşılığı olsun diye (geç oyun dilekçe kapısı).
  double _dominantHouseShare() {
    var best = 0.0;
    for (final h in _houses.snapshot()) {
      if (h.swayShare > best) best = h.swayShare;
    }
    return best;
  }

  /// Bir kan davasının yaşayan taraflarından biri (sulh dilekçesinin öznesi) —
  /// yoksa null. En mutsuz olanı önceler (yükü en ağır taşıyan konuşur).
  VillagerEntity? _feudMember() {
    final cands =
        _villagers.where((v) => !v.isDying && v.inFeud).toList();
    if (cands.isEmpty) return null;
    cands.sort((a, b) => a.morale.compareTo(b.morale));
    return cands.first;
  }

  /// Sulh kabul edilince (PetitionFx.feudPeace) — dilekçe sahibinin ailesi ile
  /// bir düşman ailesi arasındaki TÜM husumet silinir; kan davası sona erer.
  void _reconcileFeud(VillagerEntity? author) {
    final v = author;
    if (v == null || v.bloodEnemies.isEmpty) return;
    final enemy = v.bloodEnemies.first;
    _pacifyFeudOf(v); // v'nin ailesi ↔ tüm düşman aileleri: husumet silinir
    _feelVillage(NpcEmotion.content, 10, 0.10); // köy nefes alır
    v.feel(NpcEmotion.content, 4.0, moodDelta: 0.15);
    enemy.feel(NpcEmotion.content, 4.0, moodDelta: 0.15);
    final peaceCtx = _voice(v, other: enemy,
        seed: _stableSeed('sulh${v.name}${enemy.name}', _dayCount));
    _chronicle(
        Voice.say(const [
          'Kan davası kapandı. {ad} ile {öteki} aynı sofraya oturdu.',
          '{ad-in} ailesiyle {öteki-in} ailesi barıştı. Husumet defterden silindi.',
          'Sulh oldu. İki soy artık birbirinin adını anabiliyor.',
        ], peaceCtx),
        icon: '🕊️', milestone: true);
    _showNotification(Voice.say(const [
      '🕊️ {ad} ile {öteki} el sıkıştı. Kan davası bitti.',
      '🕊️ Diyet ödendi, husumet kapandı. {ad-in} ailesi de {öteki-in} ailesi de nefes aldı.',
      '🕊️ Sulh sağlandı. İki aile bugün ilk kez aynı ateşin başında oturdu.',
    ], peaceCtx));
  }

  /// Sulh dilekçesinde "Suçluyu sürgün et" seçilince — kan davasının en çok kan
  /// dökeni (suçlu) köyden sürülür, husumet uzaklaştırmayla kapanır.
  void _exileFeudCulprit() {
    final c = _feudCulprit();
    if (c != null) _exileVillager(c);
  }

  /// Sulh dilekçesinde "Suçluyu idam et" seçilince — en çok kan döken suçlu 2B
  /// sahnede halkın önünde idam edilir, kan davası kanla kapanır.
  void _executeFeudCulprit() {
    final c = _feudCulprit();
    if (c != null) _executeVillager(c);
  }

  /// Mesleği içindeki çağrıya uymayan (kırgın) köylüler arasından en mutsuz
  /// birkaçından biri — meslek değiştirme dilekçesinin yazarı/öznesi. Yoksa null.
  VillagerEntity? _resentfulVillager() {
    final cands = _villagers
        .where((v) => !v.isDying && v.callingFound && v.type != v.calling)
        .toList();
    if (cands.isEmpty) return null;
    cands.sort((a, b) => a.morale.compareTo(b.morale));
    final n = cands.length < 3 ? cands.length : 3;
    return cands[_rng.nextInt(n)];
  }

  /// Meslek değiştirme dilekçesi onaylanınca (PetitionFx.callingGranted) —
  /// dilekçe sahibi mesleğini çağrısına çevirir; kırgınlık diner, içi açılır.
  /// [author] = kararın öznesi (dilekçe sahibi); _applyDecisionEffects geçirir.
  void _grantCalling(VillagerEntity? author) {
    final v = author;
    if (v == null || v.isDying || v.type == v.calling) return;
    final from = v.type.displayName.toLowerCase();
    final to = v.calling;
    final toName = to.displayName.toLowerCase();
    v.switchProfession(to);
    v.feel(NpcEmotion.joy, 5.0, moodDelta: 0.25); // mismatch kalkar + anlık sevinç
    _reactNearby(v.gridX, v.gridY, 4.0, NpcEmotion.joy, 2.5, moodDelta: 0.03);
    final callCtx = _voice(v,
        seed: _stableSeed('calling${v.name}', _dayCount),
        extra: {'eski': from, 'yeni': toName});
    _chronicle(
        Voice.say(const [
          '{ad} {eski} işini bıraktı. Artık {yeni}.',
          '{ad-in} tezgâhı el değiştirdi. Kendi işine geçti: {yeni}.',
          '{ad} sonunda çağrısının ardına düştü. {eski} değil, {yeni}.',
        ], callCtx),
        icon: '🌟', milestone: true);
    _showNotification(Voice.say(const [
      '🌟 {ad} artık {yeni}. Ellerini ilk kez kendi seçtiği işe verdi.',
      '🌟 {ad} {eski} işini bıraktı, {yeni} oldu. Yüzü gülüyor.',
      '🌟 {ad} kendi işine geçti: {yeni}.',
    ], callCtx));
  }

  /// DEBUG (DevPanel): anında bir dilekçe getir + modal'ı aç. Koşullar uygunsa
  /// gerçek roll, değilse rastgele bir dilekçe — test için her zaman görünür.
  void _forcePetition() {
    setStateHere(() {
      final ctx = _buildPetitionContext();
      _pendingPetition =
          PetitionSystem.roll(ctx, _rng) ?? PetitionSystem.debugRandom(_rng);
      _petitionAuthor = _pickPetitionAuthor(_pendingPetition!);
      _petitionForced = false;
      _petitionDeadline = _kPetitionGrace;
      _petitionModalOpen = true; // hemen göster
    });
  }

  /// DEBUG (DevPanel): id ile BELİRLİ bir dilekçeyi anında getir + modal'ı aç.
  void _forcePetitionById(String id) {
    final p = PetitionSystem.byId(id);
    if (p == null) return;
    setStateHere(() {
      // Düğün gerçek bir çifte bağlıdır — dev zorlamada da bir çift bağla ki
      // tam deneyim (isimli çift + sinematik + sahne) görünsün.
      if (id == 'villageWedding') {
        _weddingCouple = _findCourtship();
        _petitionAuthor = _weddingCouple?.$1 ?? _pickPetitionAuthor(p);
      } else {
        _petitionAuthor = _pickPetitionAuthor(p);
      }
      _pendingPetition = p;
      _petitionForced = false;
      _petitionDeadline = _kPetitionGrace;
      _petitionModalOpen = true;
    });
  }

  /// DEBUG (DevPanel): bir dilekçeyi AMBIENT getir (modal AÇMA) + mühleti ~12s'e
  /// kıs — mühür geri sayımını, sıkışmayı (kızarma/AZ KALDI) ve mühlet dolunca
  /// zorunlu açılışı tek tıkla, beklemeden izle.
  void _forcePetitionShortFuse() {
    setStateHere(() {
      final ctx = _buildPetitionContext();
      _pendingPetition =
          PetitionSystem.roll(ctx, _rng) ?? PetitionSystem.debugRandom(_rng);
      _summonSpokesperson(_pendingPetition!); // _petitionAuthor atar
      _petitionForced = false;
      _petitionModalOpen = false; // mühür HUD'da — geri sayımı izle
      _petitionDeadline = 12.0; // kısa fitil: ~12 gerçek sn sonra zorla açılır
    });
  }

  /// DEBUG (DevPanel): zorunlu huzuru ANINDA tetikle. Bekleyen dilekçe varsa onu
  /// zorla aç; yoksa önce bir dilekçe getirip hemen zorunlu huzura geçir.
  void _forcePetitionAudienceNow() {
    if (_pendingPetition == null) {
      setStateHere(() {
        final ctx = _buildPetitionContext();
        _pendingPetition =
            PetitionSystem.roll(ctx, _rng) ?? PetitionSystem.debugRandom(_rng);
        _summonSpokesperson(_pendingPetition!);
        _petitionForced = false;
        _petitionModalOpen = false;
        _petitionDeadline = _kPetitionGrace;
      });
    }
    _forceAudience();
  }

  /// HUD mührüne tıklayınca — modal aç.
  void _openPetition() => setStateHere(() => _petitionModalOpen = true);

  /// Modal'ı kapat ama dilekçeyi bekleyen bırak (ambient — karar zorunlu değil).
  /// Zorunlu huzurda (mühlet doldu) kapatılamaz — köy yanıt bekliyor.
  void _dismissPetition() {
    if (_petitionForced) return;
    setStateHere(() => _petitionModalOpen = false);
  }

  /// Oyuncu bir seçeneği seçti: deltaları + morali + yasayı + fx'i uygula.
  void _resolvePetition(Petition p, PetitionOption o) {
    setStateHere(() {
      // Bildirimsel etkiler (dilekçe + meclis ortak) — fx/tepki dilekçeyi
      // getiren köylüye bağlanır.
      _applyDecisionEffects(p, o, _petitionAuthor);
      // Rejim krizinin şıkka bağlı huzursuzluk etkisi (yalnız regime.* için).
      _applyRegimeChoice(p, o);

      // Hafıza: bu dilekçe bir süre tekrar random çıkmasın.
      _petitionCooldowns[p.id] = _time + _kPetitionRepeatCooldown;

      _pendingPetition   = null;
      _petitionAuthor    = null;
      _petitionExtra     = const {};
      _petitionModalOpen = false;
      _petitionForced    = false;
      _petitionTimer     = _petitionInterval();
    });
    // Boş resolution → mesaj reaksiyonun kendisinden gelir (ör. kayıp ismi).
    if (o.resolution.isNotEmpty) _showNotification(o.resolution);
  }

  /// Bir kararın (dilekçe YA DA meclis oturumu) bildirimsel etkilerini uygular:
  /// kaynak/moral/fx/zümre/hafıza/zincir + sahnede yaşanan tepki. Tek doğruluk —
  /// hem [_resolvePetition] hem [_resolveCouncil] buraya akar. [author] fx ve
  /// tepki için ilgili köylü (dilekçe sahibi ya da meclise çağrılan sözcü); bu
  /// yüzden global `_petitionAuthor`'a değil, açıkça geçilen değere bağlıdır
  /// (meclis ile bekleyen dilekçenin yazarı birbirine karışmasın).
  void _applyDecisionEffects(Petition p, PetitionOption o, VillagerEntity? author) {
    if (o.foodDelta != 0) {
      _stockpile.food = (_stockpile.food + o.foodDelta).clamp(0, 1 << 30);
    }
    if (o.woodDelta != 0) {
      _stockpile.wood = (_stockpile.wood + o.woodDelta).clamp(0, 1 << 30);
    }
    if (o.stoneDelta != 0) {
      _stockpile.stone = (_stockpile.stone + o.stoneDelta).clamp(0, 1 << 30);
    }
    if (o.ironDelta != 0) {
      _stockpile.iron = (_stockpile.iron + o.ironDelta).clamp(0, 1 << 30);
    }
    if (o.goldDelta != 0) {
      _stockpile.gold = (_stockpile.gold + o.goldDelta).clamp(0, 1 << 30);
    }
    if (o.moraleAmount != 0 && o.moraleDays > 0) {
      pushPolicyMorale(o.moraleAmount, o.moraleDays);
    }
    _applyPetitionFx(o.fx, author);
    // Bespoke sahnesi olmayan seçenek de GÖRÜLSÜN: karar sahibi ve çevresi
    // gövdeyle karşılık verir (bkz. scene_reactions._reactPlainDecision).
    // Eskiden bu seçenekler yalnız bildirim + sayı değişimiydi.
    if (o.fx == PetitionFx.none) _reactPlainDecision(o, author);
    // Zümre dengesi: kararın morali oynatması + nüfuz kayması (köy kimliği).
    _applyEstatePetition(p, o);
    // Yazarın hanesi, talebine ilgi gösterilmesinden ("dinlendik") ufak bir
    // memnuniyet duyar. Kararın YÖNÜ zaten _applyEstatePetition ile hane-
    // yaslanmasına göre dağıtıldı; burası sadece "gündeme geldik" jesti.
    if (author != null && author.surname.isNotEmpty) {
      _houses.nudge(author.surname, moodDelta: 0.04, swayGain: 0.03);
    }

    // KALICI SONUÇ (Faz 3): büyük kararlar geçici nudge'la kalmaz — köy ruhunda
    // sönmeyen bir iz (governanceLegacy) + köyün kalbinde fiziksel bir iz bırakır.
    final legacy = _legacyOf(o.fx);
    if (legacy != 0) {
      _governanceLegacy = (_governanceLegacy + legacy).clamp(-0.12, 0.12);
    }
    _plantDecisionTrace(o.fx);

    // Köy hafızası: kararın bıraktığı kalıcı bayraklar (zincir/dallanma okur).
    _villageMemory.addAll(o.setsFlags);
    _villageMemory.removeAll(o.clearsFlags);

    // Zincir: seçenek bir takip dilekçesi tetikliyorsa kuyruğa al.
    if (o.followUpId != null) {
      // Zincirin sonraki halkası AYNI YÜZLE gelsin: bu kararı getiren köylü
      // taşınır. Rastgele bir sözcü "yolladığın adam döndü" diyemez.
      _petitionFollowUps.add((
        id: o.followUpId!,
        fireAtSim: _time + o.followUpDelayDays * kGameDaySeconds,
        actor: author,
        actorName: author?.name ?? '',
      ));
    }

    // Karar sahnede yaşansın: ilgili köylü tepkisini gösterir (zümresini
    // sevindirdiysen şükran, küstürdüysen yüz çevirme).
    _reactDecisionOutcome(author, o);
  }

  /// Bir kararın fx'inin köy ruhunda bıraktığı KALICI moral izi (Faz 3) —
  /// milestone anlar sönmeyen bir tortu bırakır (geçici nudge'dan farkı bu).
  /// Cozy: küçük değerler; toplam ±0.12 sınırı _applyDecisionEffects'te.
  double _legacyOf(PetitionFx fx) => switch (fx) {
        PetitionFx.feudPeace => 0.03,
        PetitionFx.feudExile => -0.02,
        PetitionFx.feudExecute => -0.04,
        // Suç hükümleri: adaletin kalıcı tortusu. Af merhametli ama düzeni
        // gevşetir; teşhir düzen kurar; sürgün/idam köyün ruhunu soğutur.
        PetitionFx.crimePardon => 0.01,
        PetitionFx.crimePunish => 0.01,
        PetitionFx.crimeExile => -0.02,
        PetitionFx.crimeExecute => -0.05,
        // Kürek cezası: sert ama üretken. İdam kadar soğutmaz, af kadar
        // gevşetmez — köy düzeni taşta somutlaşmış görür.
        PetitionFx.crimeLabor => -0.01,
        // Tövbe: köy hem bağışlar hem görür. Aftan farkı, bedelin ödenmiş
        // sayılması — ruhta af kadar ılık ama teşhir kadar öğretici bir iz.
        PetitionFx.crimePenance => 0.02,
        PetitionFx.crimeWatch => 0.0,
        PetitionFx.ransomPaid => 0.02,
        PetitionFx.ransomRefused => -0.04,
        PetitionFx.weddingGrand => 0.02,
        PetitionFx.wedding => 0.01,
        PetitionFx.harvestBounty => 0.015,
        PetitionFx.festival => 0.015,
        PetitionFx.cult => 0.015,
        // Ayakta duran taş, ayinden ağır iz bırakır: köy her gün onu görüyor.
        PetitionFx.templeRaised => 0.03,
        PetitionFx.remembrance => 0.015,
        PetitionFx.callingGranted => 0.01,
        PetitionFx.vigil => -0.01,
        PetitionFx.mourn => -0.03,
        PetitionFx.cropBlight => -0.02,
        PetitionFx.none => 0.0,
      };

  /// Ağır kararlar köyün kalbine kalıcı bir tematik iz diker (Faz 3) — "anı
  /// bahçesi": köyün gidişatı fiziksel olarak birikir, ertesi gün köy AYNI
  /// görünmez. Yalnız ağır anlar iz bırakır (sık şenlik/sade düğün değil).
  /// Mevcut prosedürel dekoru tema-eşli, sıkı bir küme olarak kullanır.
  void _plantDecisionTrace(PetitionFx fx) {
    final kinds = _traceDecor(fx);
    if (kinds == null) return;
    final (cc, cr) = _villageCenter();
    _scatterRewardDecor(cc, cr, 2, 2, kinds: kinds);
  }

  /// Karara göre fiziksel iz teması — null ise iz bırakmaz.
  List<DecorKind>? _traceDecor(PetitionFx fx) => switch (fx) {
        // Sulh → yaşamın dönüşü (yonca/papatya) + bir barış taşı.
        PetitionFx.feudPeace =>
          const [DecorKind.clover, DecorKind.daisy, DecorKind.pebble],
        // Sürgün/idam → çıplak taş + kütük (soğuk, ağır iz). Suç hükmünün
        // sürgün/idamı da aynı soğuk izi bırakır: adalet bedava değildir.
        PetitionFx.feudExile ||
        PetitionFx.feudExecute ||
        PetitionFx.crimeExile ||
        PetitionFx.crimeExecute =>
          const [DecorKind.pebble, DecorKind.stump],
        // İnanç ayini / dikilen mabet → lavanta + mantar (okült/kutsal).
        PetitionFx.cult ||
        PetitionFx.templeRaised =>
          const [DecorKind.lavender, DecorKind.mushroomRed],
        // Aleni tövbe → meydana lavanta + yonca: bağışlanmanın ılık izi.
        PetitionFx.crimePenance =>
          const [DecorKind.lavender, DecorKind.clover],
        // Bereket → altın çayır çiçekleri.
        PetitionFx.harvestBounty =>
          const [DecorKind.buttercup, DecorKind.poppy],
        // Coşkulu düğün → çiçek demeti.
        PetitionFx.weddingGrand =>
          const [DecorKind.poppy, DecorKind.daisy, DecorKind.buttercup],
        // Anma/matem → sessiz bir taş + lavanta (hatıra köşesi).
        PetitionFx.remembrance ||
        PetitionFx.vigil =>
          const [DecorKind.pebble, DecorKind.lavender],
        // Diğerleri fiziksel iz bırakmaz (çok sık ya da küçük anlar).
        _ => null,
      };

  /// Mühlet doldu — ne olacağını REJİM söyler. Sistemin kalbi burası:
  ///   • Baskı rejimi (Mühürlü El): dilekçe hiç açılmaz, sessizce düşer.
  ///     Köyün istek kanalı kapalıdır; bedeli huzursuzluk olarak birikir.
  ///   • Hür rejim (Ortak Ocak / Açık Pazar): MECLİS kendi kararını verir,
  ///     sen istemesen de uygulanır. "Yavaşsın ama meşrusun" bunun bedeli.
  ///   • Ilımlı / yüksek yetki: klasik zorunlu huzur — karar yine senin.
  /// Kriz dilekçeleri (regime.*) bu yoldan geçmez: onlar rejimin faturasıdır,
  /// köy senden yüz yüze karar bekler.
  void _deadlineReached() {
    final p = _pendingPetition;
    final rule = _regimeRule;
    if (p != null && !p.id.startsWith('regime.')) {
      if (rule.ignoresPetitions) {
        _silencePetition();
        return;
      }
      // MECLİS-İ DAİMİ FERMANI — yetki artık rejimden DEĞİL, defterden gelir.
      // Daim toplu meclis rejim kaysa bile dağılmaz; "daim" kelimesinin anlamı
      // bu. (Ferman eskiden yalnız bir basınç çarpanıydı: özeti "bekleyen
      // dilekçeyi köy kendi çözer" diyordu ama çözen şey rejimdi, ferman değil.)
      if (rule.councilDecides ||
          _policies.sealed.contains('rejim.meclisDaimi')) {
        _councilResolvePetition();
        return;
      }
    }
    _forceAudience();
  }

  /// Mühlet doldu → ZORUNLU HUZUR: modal kendiliğinden tam-ekran açılır, sim
  /// duraklar. Köy artık yanıt bekliyor; görmezden gelmek imkânsız. Bekletmenin
  /// bedeli var (ilgili zümre küser + hafif moral dip + getiren köylü sabırsız),
  /// ama otomatik ret YOK — karar yine oyuncunundur.
  void _forceAudience() {
    final p = _pendingPetition;
    if (p == null) return;
    AudioManager.instance.playSfx(Sfx.bellChime);
    setStateHere(() {
      _petitionForced    = true;
      _petitionDeadline  = 0;
      _petitionModalOpen = true;
      // Bekletmenin bedeli: dilekçenin zümresi köşeye sıkıştırıldığını hisseder.
      final e = p.estate;
      // Bekletmenin bedeli: dilekçenin (zümresine yaslanan) haneleri köşeye
      // sıkıştırıldığını hisseder — hane hâli düşer.
      if (e != null) _nudgeHousesByEstate(e, moodDelta: -0.05);
      pushPolicyMorale(-0.04, 2.0);
      // Getiren köylü: sabrı taştı — sahnede sabırsız/buruk gövde dili.
      final a = _petitionAuthor;
      if (a != null && !a.isDying) {
        a.feel(NpcEmotion.anger, 2.6, moodDelta: -0.04);
      }
    });
    _showNotification(
        '📜 ${p.petitioner} daha fazla bekleyemez — köy yanıtını istiyor.');
  }

  /// Karar verilince ilgili köylünün (ve çevresinin) görünür tepkisi.
  /// İşaret: kararın o köylünün zümresine net etkisi; yoksa köy moralinin yönü.
  /// "Sonuç istatistik değil, sahnede yaşanan bir an" dersi. [author] dilekçe
  /// sahibi ya da meclis sözcüsü (global state'e bağlı değil).
  void _reactDecisionOutcome(VillagerEntity? author, PetitionOption o) {
    final a = author;
    if (a == null || a.isDying) return;
    // Köylünün zümresine bu seçeneğin dokunuşu (estateMood listesinden).
    final est = estateOfVillager(a.type, a.lifeStage);
    double sentiment = 0;
    for (final (e, d) in o.estateMood) {
      if (e == est) sentiment += d;
    }
    // Zümre sinyali yoksa köy moralinin yönüne düş.
    if (sentiment == 0) sentiment = o.moraleAmount;
    if (sentiment > 0.01) {
      a.feel(NpcEmotion.joy, 3.2, moodDelta: 0.12);
      _reactNearby(a.gridX, a.gridY, 3.5, NpcEmotion.joy, 2.4, moodDelta: 0.02);
    } else if (sentiment < -0.01) {
      a.feel(NpcEmotion.grief, 3.2, moodDelta: -0.10);
      _reactNearby(a.gridX, a.gridY, 3.5, NpcEmotion.grief, 2.4, moodDelta: -0.02);
    } else {
      // Nötr karar — yine de duyulduğunu hisseder (hafif teselli).
      a.feel(NpcEmotion.content, 2.4, moodDelta: 0.04);
    }
    final (cc, cr) = _villageCenter();
    a.lookToward(cc.toDouble(), cr.toDouble());
  }

  /// Dilekçe/meclis efektini sahneye uygular — somut animasyon (sadece
  /// istatistik değil). [author] sahibe bağlı fx'ler (çağrı/sulh) için gerekir.
  void _applyPetitionFx(PetitionFx fx, VillagerEntity? author) {
    switch (fx) {
      case PetitionFx.none:
        break;
      case PetitionFx.festival:
        _reactFestival();
      case PetitionFx.cropBlight:
        _reactBlight();
      case PetitionFx.vigil:
        _reactVigil();
      case PetitionFx.mourn:
        _reactMourn();
      case PetitionFx.cult:
        _reactCult();
      case PetitionFx.templeRaised:
        _reactTempleRaised();
      case PetitionFx.remembrance:
        _reactRemembrance();
      case PetitionFx.wedding:
        _reactWedding(grand: false);
      case PetitionFx.weddingGrand:
        _reactWedding(grand: true);
      case PetitionFx.harvestBounty:
        _reactHarvestBounty();
      case PetitionFx.callingGranted:
        _grantCalling(author);
      case PetitionFx.feudPeace:
        _reconcileFeud(author);
      case PetitionFx.feudExile:
        _exileFeudCulprit();
      case PetitionFx.feudExecute:
        _executeFeudCulprit();
      // ── SUÇ hükümleri (scene_crime) ─────────────────────────────────────
      case PetitionFx.crimePardon:
        _pardonCriminal();
      case PetitionFx.crimePunish:
        _punishCriminal();
      case PetitionFx.crimeExile:
        _exileCriminal();
      case PetitionFx.crimeExecute:
        _executeCriminal();
      case PetitionFx.crimeLabor:
        _sentenceToLabor();
      case PetitionFx.crimePenance:
        _sentenceToPenance();
      case PetitionFx.crimeWatch:
        _resetSuspicion(); // asayiş kararı verildi → şüphe defteri kapanır
      case PetitionFx.ransomPaid:
        _payRansom();
      case PetitionFx.ransomRefused:
        _refuseRansom();
    }
  }

  /// Kayıp için aday köylü — yetişkin, favori değil, köyü boşaltmayacaksa.
  VillagerEntity? _pickLostSoul() {
    if (_villagers.length <= 4) return null;
    final cand = _villagers
        .where((v) =>
            v.hasProfession &&
            !v.isFavorite &&
            !v.isSleeping &&
            !v.isDying &&
            !v.isCarrying)
        .toList();
    if (cand.isEmpty) return null;
    return cand[_rng.nextInt(cand.length)];
  }

  /// Olay ölümü: aile bağlarını kopar + çöküş animasyonunu başlat. Köylü
  /// anında silinmez — gözle görülür biçimde yere yığılır, solar; scene_tick'in
  /// merkezi temizleme geçişi animasyon bitince listeden çıkarır. Doğal ölümün
  /// aksine kendi töreni var → funeral:false (cenaze düzenlenmez).
  void _removeVillager(VillagerEntity v) {
    for (final p in v.parents) {
      p.children.remove(v);
    }
    for (final c in v.children) {
      c.parents.remove(v);
    }
    v.startDying(funeral: false);
  }

  /// Boştaki yetişkinleri ateş başına topla (oturt) — matem/ayin için ortak.
  /// [pose] oturma duruşunu belirler (normal otur / ayin diz çök / yas eğil).
  void _gatherAtFire(double dur, {int max = 6, FirePose pose = FirePose.sit}) {
    final fire = _firepitBuilding;
    if (fire == null) return;
    final idle = _villagers
        .where((v) =>
            !v.isInsideBuilding &&
            !v.isSleeping &&
            v.hasProfession &&
            !v.isCarrying &&
            !v.sitClaimed &&
            !v.isDying &&
            // Vinyetin baş rolü toplanmaya katılmaz — ceremony niyeti
            // `activity`yi none bırakır, filtre onu yakalayıp ateşe oturtur ve
            // yürüyen koreografiyi keserdi (bkz. scene_vignette).
            v.mind.intent.priority < IntentPriority.ceremony &&
            v.activity == VillagerActivity.none)
        .toList()
      ..shuffle(_rng);
    int n = 0;
    for (final v in idle) {
      if (n >= max) break;
      final claim = _anchorSystem.claimNearestFirepitSit(
          v.gridX, v.gridY, v,
          maxDist: 999);
      if (claim == null) break;
      final (point, slot) = claim;
      final cx = point.building.col + point.building.cols / 2.0;
      final cy = point.building.row + point.building.rows / 2.0;
      v.assignSit(slot.col, slot.row, cx, cy, dur, () => point.release(slot, v));
      v.firePose = pose; // assignSit sit'e sıfırlar → istenen duruşa çevir
      n++;
    }
  }

  /// BESPOKE matem: bir köylü kaybedilir + mum töreni fx + köy ateşe toplanır.
  /// Tören acıyı yumuşatır (mourn'a göre daha az moral kaybı).
  void _reactVigil() {
    // Not: _resolvePetition'ın setStateHere'i içinde çağrılır → doğrudan mutate.
    final v = _pickLostSoul();
    final name = v?.name;
    final dur = kGameDaySeconds * 0.5;
    if (v != null) _removeVillager(v);
    final e = EventEffect(fx: EventFx.vigil, duration: dur);
    _activeFx.add(ActiveFx(e, dur));
    _gatherAtFire(dur, pose: FirePose.mourn); // yas duruşu — başlar öne eğik
    _feelVillage(NpcEmotion.grief, 10, -0.15);
    addCameraShake(5, dur: 0.6); // sessiz bir sarsıntı (juice)
    pushPolicyMorale(-0.06, 5.0);
    _showNotification(name != null
        ? '🕯️ $name için anma töreni — köy ateş başında bir araya geldi.'
        : '🕯️ Köy bir anma töreni düzenledi.');
  }

  /// Bir köylü kaybedilir + sessiz yas (animasyon yok, daha derin moral kaybı).
  void _reactMourn() {
    final v = _pickLostSoul();
    final name = v?.name;
    if (v != null) _removeVillager(v);
    _feelVillage(NpcEmotion.grief, 12, -0.22);
    pushPolicyMorale(-0.10, 5.0);
    _showNotification(name != null
        ? '🕯️ $name sessizce uğurlandı — köye ağır bir sessizlik çöktü.'
        : '🕯️ Köye ağır bir sessizlik çöktü.');
  }

  /// BESPOKE anma günü: köy ateş başında toplanır + mum töreni fx. Vigil'den
  /// farkı — KİMSE ölmez; bu sadece göçenleri anan bir tören (moral kapanışı
  /// option'dan gelir). Kilise dilekçesinin görünür karşılığı.
  void _reactRemembrance() {
    final dur = kGameDaySeconds * 0.5;
    final e = EventEffect(fx: EventFx.vigil, duration: dur);
    _activeFx.add(ActiveFx(e, dur));
    _gatherAtFire(dur, max: 8, pose: FirePose.mourn); // anma — başlar saygıyla eğik
    _feelVillage(NpcEmotion.content, 10, 0.06); // hüzünlü ama iyileştiren
  }

  /// BESPOKE ayin: okült çember fx + birkaç köylü ateşe toplanır (inananlar).
  void _reactCult() {
    final dur = kGameDaySeconds * 0.6;
    final e = EventEffect(fx: EventFx.cultRite, duration: dur);
    _activeFx.add(ActiveFx(e, dur));
    _gatherAtFire(dur, max: 4, pose: FirePose.kneel); // ayin — dizüstü yakarış
    _feelVillage(NpcEmotion.wonder, 8, 0.02);
    pushPolicyMorale(0.02, 5.0); // inananlar anlam bulur — net hafif +
  }

  /// BESPOKE mabet: köyün ortasına GERÇEK bir türbe/dergâh dikilir, sonra
  /// ayin çemberi kurulur. Ayinden ([_reactCult]) farkı, geriye ayakta duran
  /// bir taş bırakması — "kurula" diyen hüküm bunu demek zorunda.
  ///
  /// Köy sıkışıksa (yer yok) bina dikilmez; o zaman en azından ayin yapılır ve
  /// oyuncuya neden dikilmediği söylenir — sessiz başarısızlık bırakılmaz.
  void _reactTempleRaised() {
    final b = _raiseDecreedBuilding(BuildingType.shrine);
    _reactCult();
    if (b == null) {
      _showNotification(
          '⛪ Mabede yer bulunamadı; ayin ateşin başında yapıldı.');
      return;
    }
    _feelVillage(NpcEmotion.wonder, 10, 0.03);
    _chronicle('Köyün ortasına bir mabet dikildi.', icon: '⛪', milestone: true);
  }

  /// BESPOKE mantar tepkisi: tarlalarda yayılan mantar animasyonu + günlerce
  /// süren ürün verimi düşüşü (farm growth ×0.25). Etki alanı = TARLA.
  void _reactBlight() {
    final dur = kGameDaySeconds * 1.5; // mantar günlerce sürer
    final e = EventEffect(
      fx: EventFx.cropBlight,
      farmGrowthMul: 0.25,
      duration: dur,
    );
    _activeFx.add(ActiveFx(e, dur));
    _feelVillage(NpcEmotion.fear, 8, -0.08); // çiftçiler tedirgin
  }

  /// BESPOKE bereket tepkisi: tarlalar altın ışıltıyla olgunlaşır (harvestBounty
  /// fx) + günlerce süren verim artışı (farm growth ×1.6). Mantarın pozitif
  /// karşıtı — etki alanı = TARLA. İyi bakımın görünür ödülü.
  void _reactHarvestBounty() {
    final dur = kGameDaySeconds * 1.0; // bereket bir gün boyunca tarlalarda parlar
    final e = EventEffect(
      fx: EventFx.harvestBounty,
      farmGrowthMul: 1.6,
      duration: dur,
    );
    _activeFx.add(ActiveFx(e, dur));
    _feelVillage(NpcEmotion.joy, 12, 0.12); // köy şükran içinde
    _gatherAtFire(dur, max: 5); // birkaçı kutlamak için ateşe toplanır
  }

  /// BESPOKE şenlik tepkisi: köy çapında flama/konfeti/fener fx'i + köylüleri
  /// ateş başına topla, birkaç çift dans ettir. Gerçek, görünür bir bayram.
  void _reactFestival() {
    AudioManager.instance.playSfx(Sfx.crowdFair);
    final dur = kGameDaySeconds * 0.6; // şenlik neredeyse bir gün sürer
    final e = EventEffect(fx: EventFx.festival, duration: dur);
    _activeFx.add(ActiveFx(e, dur));
    _feelVillage(NpcEmotion.joy, 14, 0.20);

    final fire = _firepitBuilding;
    if (fire == null) return;

    // Uygun (boş, yetişkin, dışarıda) köylüler — karışık sıra.
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
    for (final v in idle) {
      // Önce birkaç çift yakın partneriyle dans etsin (ateş yakını şart değil).
      if (danced < 4 && _tryStartDanceFor(v)) {
        v.socialCooldown = dur;
        danced++;
        continue;
      }
      // Gerisini ateş başına topla (uzaktan da gelsinler — şenlik daveti).
      final claim = _anchorSystem.claimNearestFirepitSit(
          v.gridX, v.gridY, v,
          maxDist: 999);
      if (claim == null) continue;
      final (point, slot) = claim;
      final cx = point.building.col + point.building.cols / 2.0;
      final cy = point.building.row + point.building.rows / 2.0;
      v.assignSit(slot.col, slot.row, cx, cy, dur, () => point.release(slot, v));
    }
  }

  // Düğün tepkisi (`_reactWedding`) + tüm kur/sahneleme yaşam döngüsü
  // scene_wedding.dart'ta — gerçek çift bazlı, sinematikli sahnelenmiş olay.

  // ── UI build (main.dart Stack'inden çağrılır) ──────────────────────────────

  /// Bekleyen dilekçe mührü — üst-orta, tükenen mühlet halkalı tomar. _frame'e
  /// bağlı: kalan mühlet her karede akar, son %30'da "sıkışma" (kızarma+hız).
  Widget buildPetitionSeal() {
    return Positioned(
      top: 16,
      left: 0,
      right: 0,
      child: Center(
        child: ListenableBuilder(
          listenable: _frame,
          builder: (context, _) {
            final remain =
                (_petitionDeadline / _kPetitionGrace).clamp(0.0, 1.0);
            return PetitionSeal(
              onTap: _openPetition,
              progress: remain,
              urgent: remain <= _kPetitionUrgentFrac,
              tone: _pendingPetition?.tone ?? PetitionTone.neutral,
            );
          },
        ),
      ),
    );
  }

  /// Parşömen dilekçe modal'ı — köy durumu şeridiyle (bağlamla karar ver).
  Widget buildPetitionModal() {
    return Positioned.fill(
      child: PetitionModal(
        petition: _pendingPetition!,
        author: _petitionAuthor,
        // Mühlet doldu → zorunlu huzur: kapatılamaz, köy yanıt bekliyor.
        forced: _petitionForced,
        state: (
          morale: _stats.morale,
          population: _villagers.length,
          food: _stockpile.food,
          gold: _stockpile.gold,
        ),
        onChoose: (o) => _resolvePetition(_pendingPetition!, o),
        onDismiss: _dismissPetition,
        // VETO yalnız MEŞRUİYETİ olan rejimde anlamlıdır: hür rejimde köyün
        // sözünü kesmek bir bedeldir. Baskı rejiminde zaten dilekçe susar,
        // ılımlı köyde reddetmek diye bir jest yok — orada karar vermek yeter.
        // Kriz dilekçeleri (regime.*) veto edilemez: onlar rejimin faturası.
        onVeto: (_regimeRule.vetoMoraleCost > 0 &&
                !_pendingPetition!.id.startsWith('regime.'))
            ? _vetoPetition
            : null,
        vetoNote: 'Meclisin sözünü kesersin: moral düşer, ilgili haneler '
            'küser, huzursuzluk artar.',
        onAuthorTap: _petitionAuthor == null
            ? null
            : () => setStateHere(() {
                  _selectedVillager = _petitionAuthor;
                  _petitionModalOpen = false; // dilekçe rozette bekler
                }),
      ),
    );
  }
}
