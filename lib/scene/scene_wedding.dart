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

  void _tickWedding(double dt) {
    if (!_hasFire || _villagers.length < 2) return;
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
    _chronicle('${w.name} ile ${m.name} birbirine gönül verdi', icon: '💞');
    _showNotification('💞 ${w.name} ile ${m.name}’nin arası ısınıyor…');
  }

  /// Aynı evde yaşayan, karşı cins, kan bağı olmayan, henüz evlenmemiş iki
  /// yetişkin — (kadın, erkek). Yoksa null. _tickFamilyReunion index desenini izler.
  (VillagerEntity, VillagerEntity)? _findCourtship() {
    final byHome = <Object, List<VillagerEntity>>{};
    for (final v in _villagers) {
      if (v.lifeStage != LifeStage.adult || v.isDying || v.wed) continue;
      final h = v.homeBuilding;
      if (h == null) continue;
      (byHome[h] ??= []).add(v);
    }
    for (final mates in byHome.values) {
      if (mates.length < 2) continue;
      for (final w in mates) {
        if (w.isMale) continue;
        for (final m in mates) {
          if (!m.isMale) continue;
          if (w.parents.contains(m) || w.children.contains(m)) continue;
          if (m.parents.contains(w) || m.children.contains(w)) continue;
          if (w.parents.any(m.parents.toSet().contains)) continue; // kardeş
          return (w, m);
        }
      }
    }
    return null;
  }

  /// Nişanlı çift hâlâ geçerli mi (ikisi de hayatta, evlenmemiş, aynı evde yetişkin).
  bool _coupleStillValid(VillagerEntity a, VillagerEntity b) {
    if (a.isDying || b.isDying || a.wed || b.wed) return false;
    if (a.lifeStage != LifeStage.adult || b.lifeStage != LifeStage.adult) {
      return false;
    }
    if (a.homeBuilding == null || a.homeBuilding != b.homeBuilding) return false;
    if (!_villagers.contains(a) || !_villagers.contains(b)) return false;
    return true;
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
  }

  /// Kur olgunlaştı → düğün dilekçesini ÇİFTE BAĞLI sun. Yazar = gelin (modal'da
  /// gerçek, tıklanabilir köylü). Herald: çift ateşe doğru döner (diegetik).
  void _armWedding(VillagerEntity bride, VillagerEntity groom) {
    _brideElect = null;
    _groomElect = null;
    _courtshipTimer = 0;
    final p = PetitionSystem.byId('villageWedding');
    if (p == null) return;
    _weddingCouple = (bride, groom);
    _pendingPetition = p;
    _petitionForced = false;
    _petitionDeadline = _ScenePetitions._kPetitionGrace;
    _petitionAuthor = bride;
    // Herald — çift köy merkezine (ateşe) döner, içleri sevgiyle dolar.
    final (cc, cr) = _villageCenter();
    for (final v in [bride, groom]) {
      if (v.isSleeping || v.isInsideBuilding || v.isDying) continue;
      v.lookToward(cc.toDouble(), cr.toDouble());
      v.feel(NpcEmotion.love, 3.0, moodDelta: 0.03);
    }
    _showNotification(
        '💍 ${bride.name} & ${groom.name} evlenmek istiyor — köy bir düğün bekliyor');
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

    final dur = kGameDaySeconds * 0.5;
    _activeFx.add(ActiveFx(EventEffect(fx: EventFx.wedding, duration: dur), dur));
    _feelVillage(NpcEmotion.love, 14, grand ? 0.18 : 0.12);

    VillagerEntity? bride, groom;
    if (couple != null) {
      bride = couple.$1;
      groom = couple.$2;
      bride.wed = true;
      groom.wed = true;
      _chronicle('${bride.name} & ${groom.name} evlendi', icon: '💍');
      _award('first_wedding', 'Köyün ilk düğünü kutlandı', '💍');
      _lifeEvent(bride, '${groom.name} ile evlendi', icon: '💍',
          milestone: true);
      _lifeEvent(groom, '${bride.name} ile evlendi', icon: '💍',
          milestone: true);
    }

    // Coşkulu → gerçek çifte benzeyen tam ekran 2B sinematik (sim duraklar).
    // Sahneleme aşağıda HEMEN kurulur → sinematik bitince köy zaten kutlamada.
    if (grand && bride != null && groom != null) {
      _activeCutscene = weddingCutscene(
        brideType: bride.type, brideVisual: bride.visual, brideName: bride.name,
        groomType: groom.type, groomVisual: groom.visual, groomName: groom.name,
      );
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
      v.chatBubbleIcon = '💍';
      v.chatBubbleTime = dur;
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
