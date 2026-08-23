part of '../main.dart';

/// Köy Akışı — görev tamamlanmasını izler, GÖRSEL ödül dağıtır, politika-türevli
/// Tüzük kademesini ilerletir. No-fail: yalnızca pozitif. Kaynak ödülü YOK;
/// ödüller kutlama FX + köy sevinci (gövde dili) + kalıcı çiçeklenme.
extension _SceneFlow on _VillageSceneState {
  static const double _kFlowScan = 0.5;

  /// OCAK → ÇADIR → ODUNCU zinciri gerçekten dönene kadar oyun kuruluş
  /// modundadır. Bu bir save bayrağı değil, dünyanın gerçek durumundan
  /// türetilir; eski kayıtlar ve yarıda kapatılan oyunlar doğru yerden devam eder.
  bool get _foundingModeActive =>
      _charterTier == 0 && !_completedQuests.contains('lumber');

  /// Kuruluş modunda oyuncunun yerini seçtiği, aradaki usta bekleyişinin
  /// otomatik geçileceği iki ilk yapı.
  bool _isFoundingBootstrapBuilding(BuildingType type) =>
      _foundingModeActive &&
      (type == BuildingType.tent || type == BuildingType.lumberCamp);

  /// QuestContext'i mevcut state'ten kurar.
  QuestContext _questContext() {
    // Tek snapshot, tek hesap: görev taraması dört kefeyi ayrı ayrı okusa da
    // hane nüfuzu ve refah her seferinde yeniden hesaplanmaz.
    final reckoning = _reckoningInput();
    final yearsPassed = yearOf(_dayCount) - 1;
    return QuestContext(
      buildings: _buildings,
      farmTiles: _farmTiles,
      population: _villagers.length,
      stock: _stockpile,
      policies: _policies,
      decorCount: _decor.length,
      charterTier: _charterTier,
      // GEÇ OYUN — köyün ne kurduğu kadar ne BİLDİĞİ ve ne kadar YERLEŞTİĞİ.
      craftCount: _knownCrafts.length,
      woodHarvested: _woodHarvested,
      roadCount: _roadSystem.all.length,
      connectedProductionSites: _connectedProductionSites(),
      // Kimlik seçilmez, mühürlerin toplamından doğar (bkz. scene_regime);
      // "ılımlı" = henüz bir duruş yok demek.
      regimeNamed: _regimeIdentity.regime != VillageRegime.moderate,
      dayCount: _dayCount,
      // HANELER — geç kademe merdiveni kararları ölçer, binaları değil.
      loyalHouses: _houseCountWhere((s) => s == HouseStance.loyal),
      withheldHouses: _houseCountWhere((s) => s.withholds),
      houseCount: _livingHouseCount,
      unity: reckoning.unity,
      charter: reckoning.charter,
      grit: reckoning.grit,
      legacy: reckoning.legacy,
      standing: reckoning.standing,
      // Tamamlanmış her yıl bir kış; imparatorluk ziyareti ayrı baskı.
      // Bu toplam yalnız tarihsel kapıdır, sonuç kefeleri ayrıca aranır.
      pressuresWeathered: yearsPassed + _imperialVisits,
      speakerNames: _founderNames(),
    );
  }

  /// AYNI kesintisiz yola bağlanan üretim noktalarının en yüksek sayısı.
  ///
  /// Yol saymak kolayca boş araziye döşenen altmış kareye dönüşür. Burada önce
  /// yol bileşenleri bulunur, sonra her bileşenin kapısına değdiği üretim
  /// yapıları sayılır. Toplama/değirmen/pazar üretim dolaşımına girer; konut,
  /// süs ve ambar sırf yola yakın diye üretim noktası sayılmaz.
  int _connectedProductionSites() => connectedProductionSiteCount(
    buildings: _buildings,
    roadTiles: [for (final road in _roadSystem.all) (road.col, road.row)],
  );

  /// Üyesi olan hanelerden duruşu koşulu sağlayanların sayısı.
  int _houseCountWhere(bool Function(HouseStance) test) {
    var n = 0;
    for (final h in _houses.snapshot()) {
      if (h.members > 0 && test(h.stance)) n++;
    }
    return n;
  }

  /// Üyesi olan hane sayısı. Boşalmış hane (üyesi ölmüş/gitmiş) sayılmaz:
  /// yoksa "bütün haneler razı" ölçüsü hayalet bir ocağa takılırdı.
  int get _livingHouseCount =>
      _houses.snapshot().where((h) => h.members > 0).length;

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
      kCaptureMode ||
      _charterTier >= 1 ||
      (_dayCount >= _kAwakenDayFallback &&
          !(_guideActive || _guideWanted || _guideOpen));

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
      kFlowDebug =
          'tarama=$_flowScans adım=${_stepCache?.quest.id ?? "YOK"} '
          'açık=${QuestBook.activeQuests(ctx, _completedQuests).length} '
          'kademe=$_charterTier nüfus=${_villagers.length} '
          'gün=$_dayCount mevsim=${_season.label} '
          'kış=%${(_winterReadiness.overall * 100).round()} '
          'yün=${_stockpile.wool} giysi=${_villagers.where((v) => v.hasCoat).length}/${_villagers.length} '
          'soğukEv=${_coldHouses.length} '
          'dokumacı=${_villagers.where((v) => v.job?.role == JobRole.weaver).length} '
          // KÖY KENDİ AÇLIĞINA BAKIYOR MU — mikro kontrol kalkınca tek soru bu.
          'toplayıcı=${_jobCount(JobRole.forager)}/${_foragerTarget()} '
          'aşçı=${_jobCount(JobRole.cook)}/${_cookTarget()} '
          'yiyecek=${_stockpile.food} yemek=$_cookedMeals '
          'bekleyenGiysi=$_coatsMade '
          'işaret=${_stepBeacon == null ? "yok" : "var"} '
          'öğretici=${_guideOpen
              ? "AÇIK"
              : _guideWanted
              ? "bekliyor(${_guideDelay.toStringAsFixed(1)})"
              : "kapalı"} '
          'hedef=${_resolveGuideCue()?.title ?? "YOK"} '
          'kalp=${_villageHeart()} kamera=$_camera kilit=$_cameraCentered '
          'görünüm=$_viewSize';
    }

    // Yeni tamamlanan TEK görev — akışı sakin pacele, ödül burst'ünü önle
    // (showcase köyünde aynı anda çok görev sağlanmış olabilir).
    for (final q in QuestBook.all) {
      if (!q.isAvailable(ctx)) continue;
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
      if (q.id == 'lumber') {
        // İlk üretim gerçekten çalıştı: kısıtlı katalog ve kapalı
        // yönetim kapıları aynı karede açılır. Ayrı bir modal yok;
        // kontrol devri dünyanın akmayı sürdürdüğü tek bir cümledir.
        _chronicle(
          'Kuruluş tamamlandı; ilk odun indi ve köy kendi işini çevirmeye başladı.',
          icon: '🌿',
          milestone: true,
        );
        _showNotification(
          '🌿 Köy kendi kendine dönüyor — yönetim artık sende.',
        );
      }
      break; // bir scan'de bir ödül → sürekli, sakin akış
    }

    // Kademe atlama — politika-odaklı Tüzük ilerlemesi (büyük kutlama).
    final newTier = QuestBook.charterTier(
      _completedQuests.length,
      _policies.enactedCount,
    );
    if (newTier > _charterTier) {
      _charterTier = newTier;
      final tier = QuestBook.tierOf(newTier);
      _grantVisualReward(VisualReward.landmark);
      _reactFestival(); // ateşe toplanma + dans (scene_petitions şablonu)
      // Kademe TÖRENSEL an: köy artık dışarıda başka bir adla anılıyor —
      // cümle "köyünüz" değil, köyün KENDİ adıyla kurulur.
      _showNotification(
        '${tier.icon} $_villageName artık "${tier.name}" diye anılıyor!',
      );
      // Eskiden burada kademe filmi oynardı. Merdiven altı basamak olduğu için
      // tam ekran film koşuda ALTI kez araya giriyordu — o sıklıkta bir film
      // artık tören değil kesinti. Kademe anı dünyada zaten tam kadro
      // anlatılıyor: landmark ödülü + ateş başı şenlik + köyün yeni adı.
      _chronicle(
        '$_villageName "${tier.name}" oldu',
        icon: tier.icon,
        milestone: true,
      );
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
    _refreshStepTarget();
  }

  /// ADIMIN DÜNYA HEDEFİ — yalnız "Göster" kamerasının gideceği yer.
  ///
  /// Eskiden bu koordinat dünyada sürekli nefes alan bir ok da çiziyordu.
  /// "Köy merkezi" kesin bir yerleştirme hedefi olmadığı için ok, oyuncuya
  /// anlamlı bir eylem söylemeden ortalıkta geziyordu. Artık koordinat yalnız
  /// oyuncu karttaki "Göster"i isterse kamerayı taşır; hedefin açıklaması da
  /// o anda açılan [GuideSpotlight] kartında kalır.
  ///
  /// Tarama başına bir kez çalışır (0.5 sn) — her karede en yakın ağacı
  /// aramak boşuna tarama olurdu.
  void _refreshStepTarget() {
    final q = _stepCache?.quest;
    if (q == null) {
      _stepBeacon = null;
      return;
    }
    // İlk ateş için ortada dolaşan halka işaretçisi yerine kamera biraz açılır
    // ve oyuncuya dünya üzerinde kendi seçimini yaptırır. Bu adımda hedef bir
    // nokta göstermek, oyuncunun "ateş tam buraya mı" diye imleci kovalamaya
    // zorlanmasına yol açıyordu.
    if (q.buildTarget == BuildingType.firepit &&
        _placing == BuildingType.firepit) {
      _stepBeacon = foundingHearthCenter();
      return;
    }
    switch (q.pointer) {
      case QuestPointer.none:
        _stepBeacon = null;

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

  /// Kuruluş görevinin yerleştirilmiş ama henüz bitmemiş şantiyesi.
  ///
  /// Oyuncu binayı seçip yerini koyduğunda öğretilecek eylemi zaten yaptı.
  /// Bundan sonrası inşaatçının yürümesini izlemek; takipçi bu değer
  /// doluyken "Beklemeyi geç" kaçışını gösterir.
  BuildOrder? get _foundingWaitOrder {
    if (_charterTier != 0) return null;
    final target = _currentStep?.quest.buildTarget;
    if (target == null) return null;
    for (final o in _orders) {
      if (!o.completed && o.type == target) return o;
    }
    return null;
  }

  /// Kuruluşta yer seçimi yapılmış bir şantiyenin yalnız BEKLEME kısmını atla.
  /// Kaynak/yerleştirme kararı korunur; bina normal tamamlanma hattına girer.
  void _skipFoundingBuildWait() {
    final o = _foundingWaitOrder;
    if (o == null) return;
    setStateHere(() {
      final exists = _buildings.any(
        (b) => b.type == o.type && b.col == o.col && b.row == o.row,
      );
      if (!exists) {
        _buildings.add(BuildingEntity(type: o.type, col: o.col, row: o.row));
      }
      o.progress = 1.0;
      o.completed = true;
      o.startAnnounced = true;
    });
    AudioManager.instance.playSfx(Sfx.buildDone);
    final label = kBuildingMeta[o.type]?.label ?? 'Yapı';
    _showNotification('⏩ $label tamamlandı — inşaat bekleyişi geçildi.');
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

  /// Köyün kalbi — ocak varsa orası, kuruluş sırasında kuru merkez açıklık.
  (double, double)? _villageHeart() {
    final fp = _firepitBuilding;
    if (fp != null) return (fp.col + fp.cols / 2.0, fp.row + fp.rows / 2.0);
    // Kuruluş kafilesi harita merkezine YÜRÜYOR. Kafile girişinin ortalamasını
    // kalp sayarsak kamera rastgele giriş kıyısına (bazen göle) kilitlenir.
    return foundingHearthCenter();
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
    // Kuruluş kademesinde şenlik FX'i ödülü görünür kılar; kalıcı
    // çiçek ise yalnız birkaç vurgu noktasıdır. Eski 8/12 demetlik dar
    // halkalar ilk iki kademede merkeze 100'den fazla sprite yığıyordu.
    // Ortak spacing+bütçe kapısıyla beraber bu sayılar köyü renklendirir,
    // zemini kaplamaz.
    final early = _charterTier <= 1;
    switch (kind) {
      case VisualReward.sparkle:
        _feelVillage(NpcEmotion.joy, 3, 0.04);
        if (early) {
          _activeFx.add(
            ActiveFx(const EventEffect(fx: EventFx.festival, duration: 4), 4),
          );
          _scatterRewardDecor(cc, cr, 2, 3);
        } else {
          _scatterRewardDecor(cc, cr, 3, 1);
        }
      case VisualReward.bloom:
        _feelVillage(NpcEmotion.joy, 4, 0.06);
        if (early) {
          _activeFx.add(
            ActiveFx(const EventEffect(fx: EventFx.festival, duration: 6), 6),
          );
          _scatterRewardDecor(cc, cr, 3, 5);
        } else {
          _scatterRewardDecor(cc, cr, 4, 2);
        }
      case VisualReward.festival:
        _activeFx.add(
          ActiveFx(const EventEffect(fx: EventFx.festival, duration: 14), 14),
        );
        _feelVillage(NpcEmotion.joy, 8, 0.10);
        _scatterRewardDecor(cc, cr, 5, 4);
      case VisualReward.landmark:
        _activeFx.add(
          ActiveFx(const EventEffect(fx: EventFx.festival, duration: 20), 20),
        );
        _feelVillage(NpcEmotion.joy, 12, 0.14);
        _scatterRewardDecor(cc, cr, 7, 6);
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

  /// Merkez çevresine kalıcı çiçek/çalı serpme. Bütün yüzey,
  /// spacing ve nüfus kuralları [scene_decor] içindeki tek kapıdan geçer.
  void _scatterRewardDecor(
    int cc,
    int cr,
    int radius,
    int count, {
    List<DecorKind>? kinds,
  }) {
    kinds ??= const [
      DecorKind.daisy,
      DecorKind.poppy,
      DecorKind.lavender,
      DecorKind.buttercup,
      DecorKind.clover,
      DecorKind.bushSmall,
    ];
    final cands = <(int, int)>[];
    for (int dr = -radius; dr <= radius; dr++) {
      for (int dc = -radius; dc <= radius; dc++) {
        final c = cc + dc, r = cr + dr;
        if (c < 1 || c >= kCols - 1 || r < 1 || r >= kRows - 1) continue;
        cands.add((c, r));
      }
    }
    if (cands.isEmpty) return;
    cands.shuffle(_rng);
    var planted = 0;
    for (final (c, r) in cands) {
      if (planted >= count) break;
      final kind = kinds[_rng.nextInt(kinds.length)];
      if (_tryPlantDecor(c, r, kind)) planted++;
    }
  }
}
