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
    // Moral tabana süzülür (sway sönmez) — kararlar günlerce yankılanır.
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

  /// Dilekçeyi GETİRECEK gerçek köylüyü seçer (rastgele "Çiftçiler" değil —
  /// somut biri). Önce dilekçenin zümresinden uygun bir yetişkin; yoksa
  /// herhangi bir yetişkin (yazar asla boş kalmasın). Uyuyan/içerideki bile
  /// olabilir — portre + bilgi için kimliği yeterli.
  VillagerEntity? _pickPetitionAuthor(Petition p) {
    final adults = _villagers
        .where((v) => v.hasProfession && !v.isDying)
        .toList();
    if (adults.isEmpty) return null;
    final e = p.estate;
    if (e != null) {
      final est = adults
          .where((v) => estateOfVillager(v.type, v.lifeStage) == e)
          .toList();
      if (est.isNotEmpty) return est[_rng.nextInt(est.length)];
    }
    return adults[_rng.nextInt(adults.length)];
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
