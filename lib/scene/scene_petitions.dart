part of '../main.dart';

/// Dilekçe / Meclis sistemi — köy periyodik olarak senden bir şey ister,
/// sen karar verirsin. Yönetişimin omurgası: pasif toggle yerine akan karar.
///
/// Ambient: dilekçe gelince HUD'da mühürlü tomar belirir (oyun durmaz). Tıkla
/// → parşömen modal. Çok uzun cevapsız kalırsa kendiliğinden reddolur + ufak
/// moral dip (köy duyulmadığını hisseder).
///
/// Bağımlı sistemler: PetitionSystem (üretim), pushPolicyMorale (geçici moral),
/// _applyPolicySideChannels + _policies (yasa yürürlüğe), _attachFxTargets (fx).
extension _ScenePetitions on _VillageSceneState {
  /// İki dilekçe arası bekleme (sn) — ~1.5 oyun günü.
  static const double _kPetitionInterval = 1.5 * kGameDaySeconds;
  /// Cevapsız dilekçe ömrü (sn) — ~2 oyun günü, sonra otomatik reddolur.
  static const double _kPetitionDeadline = 2.0 * kGameDaySeconds;
  /// Çözülen dilekçenin tekrar random çıkmaması için hafıza cooldown'u.
  static const double _kPetitionRepeatCooldown = 4.0 * kGameDaySeconds;

  void _tickPetitions(double dt) {
    // Köy kurulmadan / nüfus çok azken dilekçe yok.
    if (!_hasFire || _villagers.length < 2) return;

    if (_pendingPetition != null) {
      _petitionDeadline -= dt;
      if (_petitionDeadline <= 0) _expirePetition();
      return;
    }

    // Önce zamanı gelen takip dilekçesi (zincir) — random'dan öncelikli.
    for (int i = 0; i < _petitionFollowUps.length; i++) {
      if (_petitionFollowUps[i].fireAtSim <= _time) {
        final id = _petitionFollowUps[i].id;
        _petitionFollowUps.removeAt(i);
        final p = PetitionSystem.byId(id);
        if (p != null) {
          _presentPetition(p);
          return;
        }
        break;
      }
    }

    _petitionTimer -= dt;
    if (_petitionTimer > 0) return;
    _petitionTimer = _kPetitionInterval;

    // Yakında çözülmüş (cooldown'daki) dilekçeleri random'dan çıkar.
    final blocked = <String>{
      for (final e in _petitionCooldowns.entries)
        if (e.value > _time) e.key,
    };
    final p = PetitionSystem.roll(_buildPetitionContext(), _rng, blocked: blocked);
    if (p == null) return; // uygun dilekçe yok — bir sonraki turda tekrar dene
    _presentPetition(p);
  }

  /// Bir dilekçeyi sunar (HUD mührü + bildirim).
  void _presentPetition(Petition p) {
    _pendingPetition  = p;
    _petitionDeadline = _kPetitionDeadline;
    _summonSpokesperson(p); // diegetik: zümre sözcüsü merkeze döner
    _showNotification('📜 ${p.petitioner} bir dilekçe sundu');
  }

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
    return PetitionContext(
      population: _villagers.length,
      adults: adults,
      food: _stockpile.food,
      gold: _stockpile.gold,
      morale: _stats.morale,
      hasChurch: _churchBuilding != null,
      memory: _villageMemory,
    );
  }

  /// DEBUG (DevPanel): anında bir dilekçe getir + modal'ı aç. Koşullar uygunsa
  /// gerçek roll, değilse rastgele bir dilekçe — test için her zaman görünür.
  void _forcePetition() {
    setStateHere(() {
      final ctx = _buildPetitionContext();
      _pendingPetition =
          PetitionSystem.roll(ctx, _rng) ?? PetitionSystem.debugRandom(_rng);
      _petitionDeadline = _kPetitionDeadline;
      _petitionModalOpen = true; // hemen göster
    });
  }

  /// DEBUG (DevPanel): id ile BELİRLİ bir dilekçeyi anında getir + modal'ı aç.
  void _forcePetitionById(String id) {
    final p = PetitionSystem.byId(id);
    if (p == null) return;
    setStateHere(() {
      _pendingPetition = p;
      _petitionDeadline = _kPetitionDeadline;
      _petitionModalOpen = true;
    });
  }

  /// HUD mührüne tıklayınca — modal aç.
  void _openPetition() => setStateHere(() => _petitionModalOpen = true);

  /// Modal'ı kapat ama dilekçeyi bekleyen bırak (ambient — karar zorunlu değil).
  void _dismissPetition() => setStateHere(() => _petitionModalOpen = false);

  /// Oyuncu bir seçeneği seçti: deltaları + morali + yasayı + fx'i uygula.
  void _resolvePetition(Petition p, PetitionOption o) {
    setStateHere(() {
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
      _applyPetitionFx(o.fx);
      // Zümre dengesi: kararın morali oynatması + nüfuz kayması (köy kimliği).
      _applyEstatePetition(p, o);

      // Köy hafızası: kararın bıraktığı kalıcı bayraklar (zincir/dallanma okur).
      _villageMemory.addAll(o.setsFlags);
      _villageMemory.removeAll(o.clearsFlags);

      // Hafıza: bu dilekçe bir süre tekrar random çıkmasın.
      _petitionCooldowns[p.id] = _time + _kPetitionRepeatCooldown;
      // Zincir: seçenek bir takip dilekçesi tetikliyorsa kuyruğa al.
      if (o.followUpId != null) {
        _petitionFollowUps.add((
          id: o.followUpId!,
          fireAtSim: _time + o.followUpDelayDays * kGameDaySeconds,
        ));
      }

      _pendingPetition   = null;
      _petitionModalOpen = false;
      _petitionTimer     = _kPetitionInterval;
    });
    // Boş resolution → mesaj reaksiyonun kendisinden gelir (ör. kayıp ismi).
    if (o.resolution.isNotEmpty) _showNotification(o.resolution);
  }

  /// Süresi dolan dilekçe — yumuşak otomatik ret + ufak moral dip.
  void _expirePetition() {
    final p = _pendingPetition;
    setStateHere(() {
      if (p != null) {
        _petitionCooldowns[p.id] = _time + _kPetitionRepeatCooldown;
      }
      _pendingPetition   = null;
      _petitionModalOpen = false;
      _petitionTimer     = _kPetitionInterval;
      pushPolicyMorale(-0.03, 2.0);
    });
    _showNotification(
        '📜 ${p?.petitioner ?? 'Köy'} cevap alamadı — hafif bir kırgınlık kaldı');
  }

  /// Dilekçe efektini sahneye uygular — somut animasyon (sadece istatistik değil).
  void _applyPetitionFx(PetitionFx fx) {
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
      case PetitionFx.remembrance:
        _reactRemembrance();
      case PetitionFx.wedding:
        _reactWedding();
      case PetitionFx.harvestBounty:
        _reactHarvestBounty();
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

  /// BESPOKE düğün: ateş başı dans + kalp/yaprak yağmuru fx. Birkaç çift dans
  /// eder, gerisi ateşe toplanır (şenliğin sıcak, küçük kardeşi). Etki = SOSYAL
  /// + moral (option'dan).
  void _reactWedding() {
    final dur = kGameDaySeconds * 0.5;
    final e = EventEffect(fx: EventFx.wedding, duration: dur);
    _activeFx.add(ActiveFx(e, dur));
    _feelVillage(NpcEmotion.love, 14, 0.16);

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
            v.activity == VillagerActivity.none)
        .toList()
      ..shuffle(_rng);

    int danced = 0;
    for (final v in idle) {
      if (danced < 3 && _tryStartDanceFor(v)) {
        v.socialCooldown = dur;
        danced++;
        continue;
      }
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

  // ── UI build (main.dart Stack'inden çağrılır) ──────────────────────────────

  /// Bekleyen dilekçe mührü — üst-orta, nabız atan tomar. Tıkla → modal.
  Widget buildPetitionSeal() {
    return Positioned(
      top: 16,
      left: 0,
      right: 0,
      child: Center(child: PetitionSeal(onTap: _openPetition)),
    );
  }

  /// Parşömen dilekçe modal'ı — köy durumu şeridiyle (bağlamla karar ver).
  Widget buildPetitionModal() {
    return Positioned.fill(
      child: PetitionModal(
        petition: _pendingPetition!,
        state: (
          morale: _stats.morale,
          population: _villagers.length,
          food: _stockpile.food,
          gold: _stockpile.gold,
        ),
        onChoose: (o) => _resolvePetition(_pendingPetition!, o),
        onDismiss: _dismissPetition,
      ),
    );
  }
}
