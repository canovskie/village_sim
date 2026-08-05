part of '../main.dart';

/// Köy Akışı — görev tamamlanmasını izler, GÖRSEL ödül dağıtır, politika-türevli
/// Tüzük kademesini ilerletir. No-fail: yalnızca pozitif. Kaynak ödülü YOK;
/// ödüller kutlama FX + köy sevinci (gövde dili) + kalıcı çiçeklenme.
extension _SceneFlow on _VillageSceneState {
  static const double _kFlowScan = 0.5;

  /// QuestContext'i mevcut state'ten kurar.
  QuestContext _questContext() => QuestContext(
        buildings: _buildings,
        farmTiles: _farmTiles,
        population: _villagers.length,
        stock: _stockpile,
        policies: _policies,
        decorCount: _decor.length,
        charterTier: _charterTier,
        // GEÇ OYUN — köyün ne kurduğu kadar ne BİLDİĞİ ve ne kadar YERLEŞTİĞİ.
        craftCount: _knownCrafts.length,
        roadCount: _roadSystem.all.length,
        // Kimlik seçilmez, mühürlerin toplamından doğar (bkz. scene_regime);
        // "ılımlı" = henüz bir duruş yok demek.
        regimeNamed: _regimeIdentity.regime != VillageRegime.moderate,
        // ── Kuruluş kademesi ────────────────────────────────────────────────
        dayCount: _dayCount,
        everCooked: _firstMealShown,
        berriesPicked: _berriesPicked,
        // YALNIZ elle verilen roller: kuruluş görevleri oyuncunun kararını
        // ölçüyor, köyün kendi kendine yaptığını değil.
        playerAssignedRoles: {
          for (final v in _villagers) ?v.assignedRole,
        },
        speakerNames: _founderNames(),
      );

  /// Kurucu meslek → o meslekten YAŞAYAN bir köylünün adı.
  ///
  /// Görevi kimin istediğini yazabilmek için (bkz. [Quest.speaker]). Kurucu
  /// öldüyse aynı meslekten biri devralır; kimse kalmadıysa görev isimsiz
  /// görünür — durur, kaybolmaz.
  Map<VillagerType, String> _founderNames() {
    final m = <VillagerType, String>{};
    for (final v in _villagers) {
      if (v.isDying || !v.hasProfession) continue;
      m.putIfAbsent(v.type, () => v.name);
    }
    return m;
  }

  // ── KADEMELİ UYANIŞ ────────────────────────────────────────────────────────
  //
  // Eskiden bütün sistemler SABİT bir saatle açılıyordu: ilk dilekçe 1. günde,
  // ilk olay ~1.5. günde. Kuruluş 12 mikro adıma bölününce bu iki tetik
  // öğreticinin tam ortasına düşer oldu — oyuncu daha "sepeti kime vereyim"i
  // çözerken karşısına bir divan kararı çıkıyordu.
  //
  // Artık kapı ZAMAN değil KÖYÜN HÂLİ: yönetişim (dilekçe/olay) ancak köy
  // kendi ayakları üstünde durunca (kuruluş kademesi geçilince) uyanır. Suç
  // ondan da sonra — çalınacak bir şeyin, kıskanılacak bir hanenin olması
  // gerekir. Sıra: ateş → yemek → barınak → yönetişim → suç.
  //
  // Emniyet supabı GÜN sayısıdır: oyuncu kuruluş görevlerini hiç
  // tamamlamasa bile köy sonsuza kadar sessiz kalmaz.
  static const int _kAwakenDayFallback = 4;

  /// Yönetişim uyandı mı — dilekçe ve rastgele olayların ortak kapısı.
  bool get _governanceAwake =>
      _charterTier >= 1 || _dayCount >= _kAwakenDayFallback;

  void _tickFlow(double dt) {
    _flowScan += dt;
    if (_flowScan < _kFlowScan) return;
    _flowScan = 0;

    final ctx = _questContext();
    // HUD şeridi bu taramadan beslenir (build'de değil) — bkz. _currentStep.
    _refreshCurrentStep(ctx);
    _flowScans++;
    // Teşhis YALNIZ harness'ta: bu satır her taramada string kurar ve köyün
    // kalbini yeniden hesaplar — gerçek oyunda bedava değil.
    if (kCaptureMode) {
      kFlowDebug = 'tarama=$_flowScans adım=${_stepCache?.quest.id ?? "YOK"} '
        'açık=${QuestBook.activeQuests(ctx, _completedQuests).length} '
        'kademe=$_charterTier nüfus=${_villagers.length} '
        'gün=$_dayCount mevsim=${_season.label} '
        'kış=%${(_winterReadiness.overall * 100).round()} '
        'yün=${_stockpile.wool} giysi=${_villagers.where((v) => v.hasCoat).length}/${_villagers.length} '
        'soğukEv=${_coldHouses.length} '
        'dokumacı=${_villagers.where((v) => v.job?.role == JobRole.weaver).length} '
        'bekleyenGiysi=$_coatsMade '
        'işaret=${_stepBeacon == null ? "yok" : "var"} '
        'öğretici=${_guideOpen ? "AÇIK" : _guideWanted ? "bekliyor(${_guideDelay.toStringAsFixed(1)})" : "kapalı"} '
        'hedef=${_resolveGuideCue()?.title ?? "YOK"} '
        'kalp=${_villageHeart()} kamera=$_camera kilit=$_cameraCentered '
          'görünüm=$_viewSize';
    }

    // Yeni tamamlanan TEK görev — akışı sakin pacele, ödül burst'ünü önle
    // (showcase köyünde aynı anda çok görev sağlanmış olabilir).
    for (final q in QuestBook.all) {
      if (q.tier > _charterTier) continue;
      if (_completedQuests.contains(q.id)) continue;
      if (!q.check(ctx)) continue;
      _completedQuests.add(q.id);
      _grantVisualReward(q.reward);
      AudioManager.instance.playSfx(Sfx.bellChime);
      // GÖREVİ İSTEYEN KİŞİ KARŞILIK VERSİN — görev listesi bir alışveriş
      // listesi değil, köyün insanlarının istekleri. İsteyen biri varsa
      // tamamlanma onun adıyla duyurulur ve o köylü GÖRÜNÜR biçimde sevinir
      // (gövde dili; baş üstü ikon yok — bkz. feedback_event_animation).
      final asker = _questSpeaker(q);
      if (asker != null) {
        asker.feel(NpcEmotion.joy, 5, moodDelta: 0.10);
        // Emek görülmeden kapanmasın: isteyen kişi dünyada karşılık verir.
        // Bildirim şeridi geçip gidiyor, cümle köylünün başının üstünde durur.
        _questSpeak(asker, q.thanks, life: 6.0);
        _showNotification('✓ ${q.label} — ${asker.name} sevindi.');
      } else {
        _showNotification('✓ ${q.label}');
      }
      break; // bir scan'de bir ödül → sürekli, sakin akış
    }

    // Kademe atlama — politika-odaklı Tüzük ilerlemesi (büyük kutlama).
    final newTier =
        QuestBook.charterTier(_completedQuests.length, _policies.enactedCount);
    if (newTier > _charterTier) {
      _charterTier = newTier;
      final tier = QuestBook.tierOf(newTier);
      _grantVisualReward(VisualReward.landmark);
      _reactFestival(); // ateşe toplanma + dans (scene_petitions şablonu)
      // Kademe TÖRENSEL an: köy artık dışarıda başka bir adla anılıyor —
      // cümle "köyünüz" değil, köyün KENDİ adıyla kurulur.
      _showNotification(
          '${tier.icon} $_villageName artık "${tier.name}" diye anılıyor!');
      // Nadir tam ekran sinematik — kademe filmi (bir kez).
      final cs = cutsceneForTier(newTier);
      if (cs != null && !_tierCutscenesShown.contains(newTier)) {
        _tierCutscenesShown.add(newTier);
        _playCutscene(cs, logEntry: '$_villageName "${tier.name}" oldu');
      }
    }
  }

  /// Köyün ŞU AN bekleyen tek işi — HUD şeridinin kaynağı.
  ///
  /// Görev panelinin "active" işaretlediği görevle AYNI şey (iki ayrı
  /// sıradaki-iş listesi olmaz): panelde vurgulanan satır ile şeritte yazan
  /// cümle her zaman aynı adımı gösterir. Merdiven bittiyse null → şerit
  /// çizilmez.
  ///
  /// Değer `_tickFlow` taramasında (0.5 sn) hesaplanır, build'de DEĞİL: HUD
  /// üç ayrı alan için (metin/ikon/kim) bunu okuyor ve her okumada 40 görevin
  /// check'ini yeniden çalıştırmak build başına üç tam tarama demekti.
  QuestState? get _currentStep => _stepCache;

  void _refreshCurrentStep(QuestContext ctx) {
    final open = QuestBook.activeQuests(ctx, _completedQuests);
    _stepCache = open.isEmpty ? null : open.first;
    _refreshStepBeacon();
  }

  /// ADIMIN HEDEFİNİ DÜNYADA İŞARETLE — "nereye bakacağım"ın cevabı.
  ///
  /// Kuruluş adımları metin olarak doğruydu ama ekranda hiçbir yeri
  /// göstermiyordu: oyuncu "böğürtlen çalısı"nı, "ağaçların dibi"ni, "bir
  /// köylü"yü kendisi aramak zorundaydı. Yönlendirmenin yetersiz kalmasının
  /// asıl sebebi cümlelerin kötü olması değil, hiçbir cümlenin bir YERİ
  /// göstermemesiydi.
  ///
  /// İki kanal: yer hedefi `_stepBeacon`'a (ızgara koordinatı) yazılır ve
  /// çizim oraya sakin bir işaret koyar; kişi hedefi ise köylünün mevcut
  /// `highlightTimer` halkasını tazeler (yeni bir görsel dil icat etmeye gerek
  /// yok, o halka zaten "şuna bak" demek için var).
  ///
  /// Tarama başına bir kez çalışır (0.5 sn) — her karede en yakın çalıyı
  /// aramak boşuna tarama olurdu.
  void _refreshStepBeacon() {
    final q = _stepCache?.quest;
    if (q == null) {
      _stepBeacon = null;
      return;
    }
    switch (q.pointer) {
      case QuestPointer.none:
        _stepBeacon = null;

      case QuestPointer.villager:
        // Hedef: oyuncunun iş verebileceği biri. Halkayı TAZELE (timer sürekli
        // dolduruluyor) ki adım bitene kadar yansın; adım bitince kendiliğinden
        // söner, ayrıca temizlemeye gerek kalmaz.
        _stepBeacon = null;
        final who = _stepVillager();
        if (who != null) who.highlightTimer = 1.2;

      case QuestPointer.berryBush:
        _stepBeacon = _nearestSpot([
          for (final b in _berryBushes) (b.col.toDouble(), b.row.toDouble()),
        ]);

      case QuestPointer.forest:
        _stepBeacon = _nearestSpot([
          for (final t in _trees) (t.col.toDouble(), t.row.toDouble()),
        ]);

      case QuestPointer.hearth:
        final fp = _firepitBuilding;
        _stepBeacon = fp == null
            ? null
            : (fp.col + fp.cols / 2.0, fp.row + fp.rows / 2.0);

      case QuestPointer.villageCenter:
        _stepBeacon = _villageHeart();
    }
  }

  /// İşi olmayan (ya da en azından boşta) bir köylü — "birine iş ver" adımının
  /// hedefi. Kurucu konuşmacı varsa ONU seçer: adımı söyleyen kişiyle
  /// işaretlenen kişi aynı olsun, oyuncu iki farklı yere bakmasın.
  VillagerEntity? _stepVillager() {
    final spoken = _questSpeaker(_stepCache!.quest);
    if (spoken != null && !spoken.isDying) return spoken;
    for (final v in _villagers) {
      if (v.isDying || v.isInsideBuilding) continue;
      if (!v.lifeStage.hasProfession) continue;
      if (v.hasActiveJob) continue;
      return v;
    }
    return null;
  }

  /// Verilen noktalardan köyün kalbine EN YAKIN olanı. "En yakın çalı" değil
  /// de "köye en yakın çalı": oyuncunun kamerası köyde, işaret ekranın dışında
  /// bir yeri gösterirse yol göstermez, kaybettirir.
  (double, double)? _nearestSpot(List<(double, double)> pts) {
    if (pts.isEmpty) return null;
    final heart = _villageHeart();
    if (heart == null) return pts.first;
    (double, double)? best;
    var bestD = double.infinity;
    for (final p in pts) {
      final dx = p.$1 - heart.$1, dy = p.$2 - heart.$2;
      final d = dx * dx + dy * dy;
      if (d < bestD) {
        bestD = d;
        best = p;
      }
    }
    return best;
  }

  /// Şu anki adımın istediği inşa kartı — arayüz işaretinin kaynağı.
  ///
  /// Zaten dikilmiş bir binayı işaretlemez: adım tamamlanma taramasıyla
  /// (0.5 sn) kapanana kadar geçen kısa aralıkta halka boş yere yanardı.
  BuildingType? get _stepBuildTarget {
    final t = _stepCache?.quest.buildTarget;
    if (t == null) return null;
    if (_buildings.any((b) => b.type == t)) return null;
    return t;
  }

  /// Şu anki adımın istediği iş rolü — öğreticinin hangi İŞ YERİNİ
  /// göstereceğini bu belirler (bkz. `_guidedSiteId`). Adım tamamlanmışsa
  /// (oyuncu o eli verdiyse) işaret düşer.
  JobRole? get _stepJobTarget => _stepCache?.quest.jobTarget;

  /// Köyün kalbi — ocak varsa orası, yoksa köylülerin ortalama konumu
  /// (kuruluşun ilk saniyesinde henüz hiçbir bina yok, ama insanlar var).
  (double, double)? _villageHeart() {
    final fp = _firepitBuilding;
    if (fp != null) return (fp.col + fp.cols / 2.0, fp.row + fp.rows / 2.0);
    if (_villagers.isEmpty) return null;
    var sx = 0.0, sy = 0.0;
    for (final v in _villagers) {
      sx += v.gridX;
      sy += v.gridY;
    }
    return (sx / _villagers.length, sy / _villagers.length);
  }

  /// Bu görevi isteyen yaşayan köylü — yoksa null (kurucu ölmüş olabilir).
  VillagerEntity? _questSpeaker(Quest q) {
    final t = q.speaker;
    if (t == null) return null;
    for (final v in _villagers) {
      if (v.isDying || v.type != t || !v.hasProfession) continue;
      return v;
    }
    return null;
  }

  /// Bir sinematiği oynatır (sim duraklar) + hikâye güncesine bir satır ekler
  /// (`_chronicle`, scene_chronicle). Satır sinematik atlansa bile kalır.
  void _playCutscene(Cutscene c, {String? logEntry}) {
    // Çift tetik koruması — aynı sahne zaten oynuyorsa yok say (aksi halde
    // oynatıcı state'i sıfırlanıp sahne baştan oynar = ekrana art arda 2 kez).
    if (identical(_activeCutscene, c)) return;
    // Capture harness'ı sahneyi çeker; kilometre taşı sinematiği araya girerse
    // kare köyü değil diyalog ekranını gösterir (güncesi yine de yazılsın).
    if (kCaptureMode) {
      if (logEntry != null) _chronicle(logEntry, icon: '🎬', milestone: true);
      return;
    }
    if (logEntry != null) _chronicle(logEntry, icon: '🎬', milestone: true);
    setStateHere(() => _activeCutscene = c);
  }

  /// Görsel ödül — KAYNAK VERMEZ. Yoğunluğa göre kutlama FX + köy sevinci +
  /// köy merkezine kalıcı çiçek serpme (ilerledikçe köy gözle görülür güzelleşir).
  void _grantVisualReward(VisualReward kind) {
    final (cc, cr) = _villageCenter();
    // ERKEN OYUNDA ÖDÜL GÖRÜNMÜYORDU. `sparkle` üç çiçek serpiyordu — zaten
    // çiçekli bir çayıra üç çiçek. Oyuncu bir adımı bitirdiğini yalnız köşedeki
    // bildirimden anlıyordu, KÖYDEN anlamıyordu.
    //
    // İki değişiklik: (1) kuruluş kademesinde miktar artar ve yarıçap DARALIR
    // → serpme değil, ocağın çevresinde gözle görülür bir çiçeklenme halkası
    // olur; (2) en küçük ödül bile kısa bir şenlik FX'i taşır, yani ekranda
    // bir şey OLUR. Köy büyüdükçe (tier yükseldikçe) ödül eski sakin hâline
    // döner — o noktada zaten köyün her yeri çiçek.
    final early = _charterTier <= 1;
    switch (kind) {
      case VisualReward.sparkle:
        _feelVillage(NpcEmotion.joy, 3, 0.04);
        if (early) {
          _activeFx.add(ActiveFx(
              const EventEffect(fx: EventFx.festival, duration: 4), 4));
          _scatterRewardDecor(cc, cr, 2, 8);
        } else {
          _scatterRewardDecor(cc, cr, 3, 2);
        }
      case VisualReward.bloom:
        _feelVillage(NpcEmotion.joy, 4, 0.06);
        if (early) {
          _activeFx.add(ActiveFx(
              const EventEffect(fx: EventFx.festival, duration: 6), 6));
          _scatterRewardDecor(cc, cr, 3, 12);
        } else {
          _scatterRewardDecor(cc, cr, 4, 4);
        }
      case VisualReward.festival:
        _activeFx.add(ActiveFx(
            const EventEffect(fx: EventFx.festival, duration: 14), 14));
        _feelVillage(NpcEmotion.joy, 8, 0.10);
        _scatterRewardDecor(cc, cr, 5, 6);
      case VisualReward.landmark:
        _activeFx.add(ActiveFx(
            const EventEffect(fx: EventFx.festival, duration: 20), 20));
        _feelVillage(NpcEmotion.joy, 12, 0.14);
        _scatterRewardDecor(cc, cr, 7, 12);
    }
  }

  /// Köy merkezi — ateş yeri varsa orası, yoksa harita ortası (tile).
  (int, int) _villageCenter() {
    final f = _firepitBuilding;
    if (f != null) {
      return ((f.col + f.cols / 2).round(), (f.row + f.rows / 2).round());
    }
    return (kCols ~/ 2, kRows ~/ 2);
  }

  /// Merkez çevresine kalıcı çiçek/çalı serpme — su/bina/ağaç/dekor çakışmasız
  /// (`_sprinkleGreenAround` deseni).
  void _scatterRewardDecor(int cc, int cr, int radius, int count,
      {List<DecorKind>? kinds}) {
    kinds ??= const [
      DecorKind.daisy, DecorKind.poppy, DecorKind.lavender,
      DecorKind.buttercup, DecorKind.clover, DecorKind.bushSmall,
    ];
    final cands = <(int, int)>[];
    for (int dr = -radius; dr <= radius; dr++) {
      for (int dc = -radius; dc <= radius; dc++) {
        final c = cc + dc, r = cr + dr;
        if (c < 1 || c >= kCols - 1 || r < 1 || r >= kRows - 1) continue;
        if (_waterTiles.contains((c, r))) continue;
        if (_isOccupiedByBuilding(c, r)) continue;
        if (_trees.any((t) => t.col == c && t.row == r)) continue;
        if (_decor.any((d) => d.col == c && d.row == r)) continue;
        cands.add((c, r));
      }
    }
    if (cands.isEmpty) return;
    cands.shuffle(_rng);
    for (int i = 0; i < count && i < cands.length; i++) {
      final (c, r) = cands[i];
      _decor.add(DecorEntity(
        col: c, row: r,
        kind: kinds[_rng.nextInt(kinds.length)],
        variant: _rng.nextInt(3),
        jitterX: (_rng.nextDouble() - 0.5) * 0.5,
        jitterY: (_rng.nextDouble() - 0.5) * 0.5,
        swaySeed: _rng.nextInt(1000),
      ));
    }
  }
}
