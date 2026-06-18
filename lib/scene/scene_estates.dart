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

  void _tickEstates(double dt) {
    // Önce bireysel moralleri güncelle → zümrelere üye-morali beslensin.
    _tickVillagerMorale(dt);
    // Moral tabana (artık üye moraline) süzülür — kararlar günlerce yankılanır.
    _estates.tick(dt, kGameDaySeconds);

    // Kimlik kayması — baskın zümre değiştiyse köy görünür biçimde dönüşür.
    final asc = _estates.ascendant;
    if (asc != _identityEstate) {
      final prev = _identityEstate;
      _identityEstate = asc;
      if (asc != null) _transformVillageIdentity(asc, prev);
    }

    // Diegetik: en küskün zümrenin bir üyesi ara sıra somurtsun (gövde dili).
    _estateMoodScan += dt;
    if (_estateMoodScan < _kAggrievedScan) return;
    _estateMoodScan = 0;
    _showAggrievedPosture();
  }

  /// Köy yeni bir kimliğe kaydı — görünür dönüşüm: kutlama + köy sevinci +
  /// kimliğe özel kalıcı dekor + köy hafızasına bayrak (ileride kimliğe özel
  /// dilekçeler/fermanlar bunu okuyabilir). Cozy: yalnızca pozitif, geri
  /// dönüşte ceza yok. [prev] önceki kimlik (ilk kez kayıyorsa null).
  void _transformVillageIdentity(Estate e, Estate? prev) {
    // Hafıza: tek aktif kimlik bayrağı tut (eskiyi sil, yeniyi yaz).
    _villageMemory.removeWhere((f) => f.startsWith('identity.'));
    _villageMemory.add('identity.${e.name}');

    // Kimliğe özel kalıcı dekor — köy gözle görülür bir karaktere bürünür.
    final (cc, cr) = _villageCenter();
    _scatterRewardDecor(cc, cr, 6, 10, kinds: _identityDecor(e));

    // Görünür kutlama + köy çapında sevinç (gövde dili).
    _activeFx.add(ActiveFx(
        const EventEffect(fx: EventFx.festival, duration: 16), 16));
    _feelVillage(NpcEmotion.joy, 10, 0.12);

    _showNotification(prev == null
        ? '${e.icon} Köyün bir ruhu oldu — artık bir "${e.identity}".'
        : '${e.icon} Köy yön değiştirdi — şimdi bir "${e.identity}".');
  }

  /// Kimliğe özgü dekor paleti — köyün karakterini görselleştirir.
  List<DecorKind> _identityDecor(Estate e) => switch (e) {
        // Bereketli Köy — altın kır çiçekleri, yonca: bolluk hissi.
        Estate.laborers => const [
            DecorKind.buttercup, DecorKind.daisy, DecorKind.clover,
          ],
        // Zanaat Kasabası — taş, kütük, çalı: işlenmiş/yapısal doku.
        Estate.artisans => const [
            DecorKind.pebble, DecorKind.stump, DecorKind.bushSmall,
          ],
        // Kutsal Köy — lavanta, kızıl mantar, gelincik: gizemli/ayinsel.
        Estate.faithful => const [
            DecorKind.lavender, DecorKind.mushroomRed, DecorKind.poppy,
          ],
        // Köklü Yuva — çalı, papatya, yonca, devrik kütük: sıcak/evcil.
        Estate.hearth => const [
            DecorKind.bushSmall, DecorKind.daisy, DecorKind.clover,
            DecorKind.fallenLog,
          ],
      };

  /// Bir dilekçe kararının zümre etkilerini uygular — moral oynar, sevindirilen
  /// zümre kalıcı nüfuz kazanır. `_resolvePetition`'ın setStateHere'i içinden
  /// çağrılır (doğrudan mutate).
  void _applyEstatePetition(Petition p, PetitionOption o) {
    for (final (e, delta) in o.estateMood) {
      _estates.nudge(
        e,
        moodDelta: delta,
        swayGain: delta > 0 ? delta * _kSwayFromMood : 0,
      );
    }
    // Etiketli zümre, talebine ilgi gösterilmesinden ufak bir nüfuz da kazanır
    // (kararın yönünden bağımsız: köyün gündemine girmek nüfuzdur).
    final pe = p.estate;
    if (pe != null) _estates.nudge(pe, swayGain: 0.05);
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

    // Hedefe süzme (tau ~0.5 oyun günü) — moral kalıcı, ani zıplamaz.
    final lerp = (dt / (0.5 * kGameDaySeconds)).clamp(0.0, 0.25);

    final estSum = <Estate, double>{};
    final estCnt = <Estate, int>{};
    double sum = 0;

    for (final v in _villagers) {
      if (v.isDying) {
        sum += v.morale;
        continue;
      }
      final est = estateOfVillager(v.type, v.lifeStage);
      final ev = evaluateVillagerMorale(
        homeless: v.homeBuilding == null,
        starving: starving,
        lowWater: lowWater,
        cold: coldNight && !v.isSleeping,
        estateMood: _estates.moodOf(est),
        elderRespected: elderPolicy && v.lifeStage == LifeStage.elder,
      );
      v.morale = (v.morale + (ev.target - v.morale) * lerp).clamp(0.0, 1.0);
      v.moraleReason = ev.reason;
      sum += v.morale;
      estSum[est] = (estSum[est] ?? 0) + v.morale;
      estCnt[est] = (estCnt[est] ?? 0) + 1;
    }
    _avgIndividualMorale = sum / _villagers.length;

    // Zümrelere üye morali bildir → zümre mood'u oraya gravite eder.
    for (final e in Estate.values) {
      final c = estCnt[e] ?? 0;
      if (c > 0) _estates.setMemberMorale(e, estSum[e]! / c);
    }

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

  /// Kronik mutsuz köylü köyü terk eder — diegetik kayıp (bildirim + zümre yası).
  void _emigrateVillager(VillagerEntity v) {
    _showNotification('${v.name} köyü terk etti — uzun süre mutsuzdu');
    _estates.nudge(estateOfVillager(v.type, v.lifeStage), moodDelta: -0.06);
    _removeVillager(v);
  }

  /// Dilekçeyi GETİRECEK köylüyü seçer: dilekçenin zümresinden EN MUTSUZ
  /// (düşük moralli) somut biri — şikayetin gerçek sahibi. Zümre üyesi yoksa
  /// köyün en mutsuzu. Tam determinist olmasın diye en düşük moralli birkaç
  /// aday arasından seçilir. Yazar asla boş kalmaz.
  VillagerEntity? _pickPetitionAuthor(Petition p) {
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

  /// En küskün zümrenin bir üyesini somurtmaya başlatır (gövde dili). Cozy:
  /// moral'i düşürmez (moodDelta 0), sadece köyde GÖRÜNÜR bir hoşnutsuzluk.
  void _showAggrievedPosture() {
    final e = _estates.mostAggrieved;
    if (e == null) return;
    final cands = _villagers
        .where((v) =>
            !v.isSleeping &&
            !v.isInsideBuilding &&
            !v.isDying &&
            !v.isCarrying &&
            v.hasProfession &&
            v.activity == VillagerActivity.none &&
            v.emotion == NpcEmotion.none &&
            estateOfVillager(v.type, v.lifeStage) == e)
        .toList();
    if (cands.isEmpty) return;
    final v = cands[_rng.nextInt(cands.length)];
    // Küskünlük derecesi morale bağlı — çok düşükse öfke, değilse buruk hüzün.
    final emo = _estates.moodOf(e) < 0.22 ? NpcEmotion.anger : NpcEmotion.grief;
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
        _estates.nudge(e,
            moodDelta: delta, swayGain: delta > 0 ? delta * _kSwayFromMood : 0);
      } else {
        _estates.nudge(e, moodDelta: -delta);
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

  /// Belediye paneli için zümre özeti (salt-okunur snapshot).
  List<EstateSnapshot> _estateSnapshot() => _estates.snapshot();
}
