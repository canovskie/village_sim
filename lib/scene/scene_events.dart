part of '../main.dart';

/// Rastgele olay tetikleme + sonuç uygulama + aktif fx aggregation.
/// EventSystem.roll'un üst katmandaki state etkileri burada birleşir.
/// part of main.dart — State'in tüm private alanlarına erişim.
extension _SceneEvents on _VillageSceneState {
  /// Omen (mayalanma) süresi aralığı (sn) — olay vurmadan önceki diegetik uyarı.
  static const double _kOmenMin = 4.0;
  static const double _kOmenMax = 7.0;

  /// Olay zamanlayıcısı + omen ilerlemesi. scene_tick'in ana döngüsünden çağrılır
  /// (eski doğrudan `_triggerRandomEvent` yerine — artık olay önce mayalanır).
  void _tickEventOmen(double dt) {
    // Omen sürüyor mu → dolunca olay vurur. Bu ilerleme godMode'da DA işler ki
    // dev panelden elle tetiklenen olay (showcase köyü genelde godMode) vursun.
    if (_omenEvent != null) {
      _omenLeft -= dt;
      if (_omenLeft <= 0) _strikeOmen();
      return;
    }
    // Harness zorlaması — godMode'dan bağımsız, tek atış.
    if (kProbeTriggerEvent) {
      kProbeTriggerEvent = false;
      _beginOmen();
      return;
    }
    // Otomatik olay üretimi yalnızca godMode KAPALIYKEN (dev elle tetikler).
    if (_godMode) return;
    // KADEMELİ UYANIŞ (bkz. scene_flow): kuruluş sürerken rastgele olay yok.
    // Sayaç da işlemez — yoksa kuruluş biter bitmez birikmiş süre boşalıp
    // ilk olay anında patlardı.
    if (!_governanceAwake) return;
    _eventTimer -= dt;
    if (_eventTimer <= 0) {
      _beginOmen();
      // YIL BASKISI (bkz. systems/village_year.dart): aralık yıl geçtikçe
      // kısalır. Sıklaşan şey olay TABLOSUNUN TAMAMI — yani geç oyun daha
      // olaylı olur, daha cezalı değil. Ceza tarafını vergi zaten büyütüyor;
      // ikisini birden sertleştirmek geç oyunu cozy çizginin dışına atardı.
      final tempo = pressureForDay(_dayCount).eventTempo; // 1.0 → 0.65
      _eventTimer = (kEventMinInterval +
              _rng.nextDouble() * (kEventMaxInterval - kEventMinInterval)) *
          tempo;
    }
  }

  /// DevPanel + tick girişi — bir olay mayalamaya başlar (anında vurmaz).
  void _triggerRandomEvent() => _beginOmen();

  /// Mayalanmayı başlat: olayı seç, omen süresini ayarla, diegetik uyarıyı oynat.
  void _beginOmen() {
    if (_omenEvent != null || _pendingChoice != null) return;
    final ctx = EventContext(
      population: _villagers.length,
      stockpile:  _stockpile,
      buildings:  _buildings,
    );
    // Zorlanmış olay (dev konsol / test) — çekilişi atlar. Tüketilir: bir kez
    // sahnelenir, sonrası yine rastgeledir.
    EventOutcome? forced;
    if (kForcedEventId.isNotEmpty) {
      for (final ev in EventSystem.events) {
        if (ev.id == kForcedEventId) {
          forced = ev;
          break;
        }
      }
      kForcedEventId = '';
    }
    final e = forced ?? EventSystem.roll(_rng, ctx);
    logDev('Rastgele olay mayalanıyor: ${e.title}', tag: '🎲', color: AppUi.info);
    _omenEvent = e;
    _omenLeft = _kOmenMin + _rng.nextDouble() * (_kOmenMax - _kOmenMin);
    _playOmen(e);
  }

  /// Omen evresi — diegetik uyarı: haberci metni + olayın fx'inin hafif (cezasız)
  /// ön-titreşimi + köyün tehdide tedirgin bakışı (gövde dili). Sim duraklamaz.
  void _playOmen(EventOutcome e) {
    _showNotification(_omenText(e));
    final positive = e.category == EventCategory.positive;
    // Negatif: olayın KENDİ fx'inin cezasız ön-titreşimi (felaket önsezisi).
    // Pozitif: ön-titreşim yok — sürpriz/sevinç sahnede patlar.
    if (!positive) {
      final fx = e.effect?.fx ?? EventFx.none;
      if (fx != EventFx.none) {
        _activeFx.add(ActiveFx(EventEffect(fx: fx, duration: _omenLeft), _omenLeft));
        if (fx == EventFx.fireOutbreak && e.effect != null) {
          _attachFxTargets(e.effect!);
        }
      }
    }
    // Köy odak noktasına döner — negatifte tedirgin, pozitifte umutla (gövde dili).
    final (tx, ty) = _eventFocusPoint(e);
    final emo = positive ? NpcEmotion.wonder : NpcEmotion.fear;
    final mood = positive ? 0.01 : -0.01;
    int n = 0;
    for (final v in _villagers) {
      if (n >= 6) break;
      if (v.isInsideBuilding || v.isSleeping || v.isDying) continue;
      v.lookToward(tx, ty);
      v.feel(emo, 3.0, moodDelta: mood);
      n++;
    }
  }

  /// Omen havuzları — olay HENÜZ olmadı; bunlar dünyanın seğirmesi. Sessiz,
  /// somut, hafifçe yanlış. Kimliğe göre seçilir (başlık serbestçe değişebilsin).
  static const Map<String, List<String>> _kOmens = {
    EventIds.drought: [
      '☀ Kuyunun suyu bir karış aşağıda. Kova ipi ilk kez ıslanmadan çıktı.',
      '☀ Tarlanın kenarında toprak çatladı. Çatlak dün yoktu.',
      '☀ Gökte tek bulut yok, üç gündür. Yaprak bile kımıldamıyor.',
    ],
    EventIds.plague: [
      '🤒 Değirmenci sabah kalkamadı. Karısı kimseye söylemedi.',
      '🤒 İki çocuk oyunun ortasında oturdu, kalkmadı.',
      '🤒 Geceleyin bir haneden öksürük geliyor. Susmuyor.',
    ],
    EventIds.beastRaid: [
      '🐺 Köpekler ağaç hattına bakıp hırlıyor, havlamıyorlar.',
      '🐺 Çobanın sürüsü bu akşam ağıla girmek için itişti.',
      '🐺 Ormanın kıyısında bir uluma duyuldu. Ardından çok sessiz oldu.',
    ],
    EventIds.storm: [
      '⛈ Kuşlar alçaktan uçuyor, hepsi aynı yöne.',
      '⛈ Ufuk mürekkep gibi karardı. Rüzgâr yön değiştirdi.',
      '⛈ Hava ağırlaştı; kepenkler kendiliğinden çarpmaya başladı.',
    ],
    EventIds.houseFire: [
      '🔥 Bir bacadan kıvılcım sıçradı, çatının samanına düştü.',
      '🔥 Bir kulübenin damından ince, yanlış renkte bir duman çıkıyor.',
      '🔥 Ocak fazla harlandı. Kuru kereste tam duvarın dibinde.',
    ],
    // Pozitif — sevinçli bekleyiş.
    EventIds.bard: [
      '🎵 Yoldan tel sesi geliyor. Yaklaşıyor.',
      '🎵 Tepede sırtında saz taşıyan bir yolcu göründü.',
      '🎵 Çocuklar yola koştu; birinin türkü söylediğini duymuşlar.',
    ],
    EventIds.caravan: [
      '🛒 Tepenin ardında toz bulutu var. Toz katır tozu.',
      '🛒 Yoldan çıngırak sesi geliyor, tek tek değil, sıra sıra.',
      '🛒 Pazarcı tezgâhını erkenden genişletti. Bir şey duymuş olmalı.',
    ],
    EventIds.bounty: [
      '🌾 Başaklar sapı bükecek kadar ağır. Daha orak vurulmadı.',
      '🌾 Çiftçi bir avuç tane aldı, saydı, bir daha saydı.',
      '🌾 Tarla göz alabildiğine sarardı. Erken oldu.',
    ],
    EventIds.accord: [
      '🤝 İki küskün hane bugün aynı kuyudan su çekti. Kavga çıkmadı.',
      '🤝 Bir kapının önüne, kimin bıraktığı belli olmayan bir sepet konmuş.',
      '🤝 Dargın iki adam meydanda karşılaştı. İkisi de yolunu değiştirmedi.',
    ],
  };

  /// Diegetik omen metni — olaydan ÖNCE köyün sezdiği işaret. Varyant, gün +
  /// olay kimliğinden türeyen SABİT tohumla seçilir (aynı gün aynı cümle).
  String _omenText(EventOutcome e) {
    final pool = _kOmens[e.id];
    if (pool == null || pool.isEmpty) return '${e.icon} Köyde bir kıpırtı var.';
    return Voice.say(pool, _voice(null, seed: _eventSeed(e)));
  }

  /// Bir olayın metin tohumu: gün + olay kimliği. Aynı gün aynı olay → aynı
  /// varyant (banner, bildirim ve günce aynı cümleyi konuşur).
  int _eventSeed(EventOutcome e) => _stableSeed(e.id, _dayCount);

  /// Omen doldu → olay gerçekten vurur.
  void _strikeOmen() {
    final e = _omenEvent;
    _omenEvent = null;
    _omenLeft = 0;
    if (e == null) return;
    // Başarım: köyün ilk afeti / ilk bereketi (tek seferlik dönüm noktaları).
    if (e.category == EventCategory.negative) {
      _award('first_crisis', 'İlk afet görüldü. Köy yerinde durdu.', '⛑️');
    } else if (e.category == EventCategory.positive) {
      _award('first_blessing', 'Talih ilk kez bu kapıya uğradı.', '✨');
    }
    // PROVA: karar isteyen olay simi DONDURUR (bkz. kProbePause). Harness'lar
    // bunu ölçemez ve yanlış yerden düşer; prova köyünde olaylar susturulabilir.
    if (kProbeNoEvents) return;
    if (e.needsChoice) {
      // Modal ile bildirim aynı cümleyi konuşsun: varyant burada materyalize.
      _pendingChoice = e.withMessage(e.messageFor(_eventSeed(e)));
      _showNotification('${e.icon} ${e.title}. Köy karar bekliyor.');
      return;
    }
    _applyEventAutomatic(e);
  }

  /// Karar gerektirmeyen olayın etkilerini ve banner'ı uygular.
  void _applyEventAutomatic(EventOutcome e) {
    if (e.foodDelta != 0) {
      _stockpile.food = (_stockpile.food + e.foodDelta).clamp(0, 1 << 30);
    }
    if (e.woodDelta != 0) {
      _stockpile.wood = (_stockpile.wood + e.woodDelta).clamp(0, 1 << 30);
    }
    if (e.stoneDelta != 0) {
      _stockpile.stone = (_stockpile.stone + e.stoneDelta).clamp(0, 1 << 30);
    }
    if (e.ironDelta != 0) {
      _stockpile.iron = (_stockpile.iron + e.ironDelta).clamp(0, 1 << 30);
    }
    if (e.coalDelta != 0) {
      _stockpile.coal = (_stockpile.coal + e.coalDelta).clamp(0, 1 << 30);
    }
    if (e.goldDelta != 0) {
      _stockpile.gold = (_stockpile.gold + e.goldDelta).clamp(0, 1 << 30);
    }

    if (e.isTemporary) {
      _eventMorale     = e.moraleModifier;
      _eventMoraleLeft = e.duration;
      _eventLabel      = '${e.icon} ${e.title}';
    }
    // Havuzdan varyantı SABİT tohumla seç ve olaya işle — banner ile bildirim
    // aynı cümleyi göstersin (ikisi de `.message` okur).
    final seed  = _eventSeed(e);
    final shown = e.withMessage(e.messageFor(seed));
    _activeEvent = shown;
    _activeEventLeft = kEventBannerDuration;

    if (e.effect != null && e.effect!.duration > 0) {
      _activeFx.add(ActiveFx(e.effect!, e.effect!.duration));
      _attachFxTargets(e.effect!);
    }

    _reactToEvent(e); // köy gövde diliyle tepki verir (emoji yok, postür)
    _stageEventResponse(e, choiceId: null); // köylüler amaçlı koşuşur (sahne)
    // Vakanüvis: kuru, kısa yıllık satırı (havuzdan; olay başlığı değil).
    _chronicle(Voice.weave(e.annalFor(seed), _voice(null, seed: seed)),
        icon: e.icon);
    _showNotification(shown.message);
  }

  /// fireOutbreak gibi belirli bir bina/NPC'ye bağlı fx'lerin hedeflerini
  /// seçer. Sahne renderı bu hedeflere göre özelleştirilmiş animasyon çizer.
  void _attachFxTargets(EventEffect ef) {
    if (ef.fx == EventFx.fireOutbreak) {
      final candidates = _buildings.where((b) =>
          b.type != BuildingType.firepit &&
          b.type != BuildingType.lamppost &&
          b.type != BuildingType.well).toList();
      if (candidates.isNotEmpty) {
        _burningBuildings.add(candidates[_rng.nextInt(candidates.length)]);
      }
    }
  }

  /// Karar bekleyen olayda oyuncu seçim yaptığında: choice deltalarını uygula,
  /// modal kapat, banner ile sonuç gösterimi yap.
  void _applyEventChoice(EventOutcome base, EventChoice c) {
    if (c.foodDelta != 0) {
      _stockpile.food = (_stockpile.food + c.foodDelta).clamp(0, 1 << 30);
    }
    if (c.woodDelta != 0) {
      _stockpile.wood = (_stockpile.wood + c.woodDelta).clamp(0, 1 << 30);
    }
    if (c.stoneDelta != 0) {
      _stockpile.stone = (_stockpile.stone + c.stoneDelta).clamp(0, 1 << 30);
    }
    if (c.ironDelta != 0) {
      _stockpile.iron = (_stockpile.iron + c.ironDelta).clamp(0, 1 << 30);
    }
    if (c.coalDelta != 0) {
      _stockpile.coal = (_stockpile.coal + c.coalDelta).clamp(0, 1 << 30);
    }
    if (c.goldDelta != 0) {
      _stockpile.gold = (_stockpile.gold + c.goldDelta).clamp(0, 1 << 30);
    }
    if (c.moraleModifier != 0 && c.duration > 0) {
      _eventMorale     = c.moraleModifier;
      _eventMoraleLeft = c.duration;
      _eventLabel      = '${base.icon} ${base.title}';
    }
    final fx = c.effect ?? base.effect;
    if (fx != null && fx.duration > 0) {
      _activeFx.add(ActiveFx(fx, fx.duration));
      _attachFxTargets(fx); // fireOutbreak → _burningBuildings (sahne hedefi)
    }
    // Sahne: seçime göre köylüler amaçlı hareket eder (kova zinciri / kovalama /
    // kaçış). _attachFxTargets'tan SONRA — yangın hedefi artık biliniyor.
    // Kimliğe bakar, buton metnine DEĞİL (metin serbestçe yeniden yazılabilsin).
    _stageEventResponse(base, choiceId: c.id);
    // Vakanüvis: kararın kuru izi ("Kova zinciri kuruldu. Ev kurtarıldı.").
    _chronicle(c.annal.isEmpty ? '${base.title}: ${c.label}' : c.annal,
        icon: base.icon, kind: ChronicleKind.decision);
    _activeEvent = EventOutcome(
      id:       base.id,
      title:    base.title,
      icon:     base.icon,
      message:  c.resolutionMessage,
      category: base.category,
      severity: base.severity,
      foodDelta:  c.foodDelta,
      goldDelta:  c.goldDelta,
      woodDelta:  c.woodDelta,
      stoneDelta: c.stoneDelta,
      ironDelta:  c.ironDelta,
      coalDelta:  c.coalDelta,
      moraleModifier: c.moraleModifier,
      duration:       c.duration,
      effect:         fx,
    );
    _activeEventLeft = kEventBannerDuration;
    _reactToEvent(_activeEvent!); // çözüm sonrası köy gövde diliyle tepki verir
    _showNotification(c.resolutionMessage);
    setStateHere(() => _pendingChoice = null);
  }

  /// Bir olayı köy çapı gövde-dili tepkisine çevirir (baş üstü emoji YOK).
  /// Önce belirli fx'ler ince ayar, sonra kategori/şiddet.
  void _reactToEvent(EventOutcome e) {
    final NpcEmotion emotion;
    double dur, mood;
    switch (e.effect?.fx) {
      case EventFx.beastEyes:
        emotion = NpcEmotion.fear; dur = 7; mood = -0.03;
      case EventFx.meteorShower:
        emotion = NpcEmotion.wonder; dur = 8; mood = 0.03;
      case EventFx.harvestBounty:
        emotion = NpcEmotion.joy; dur = 8; mood = 0.05;
      default:
        switch (e.category) {
          case EventCategory.positive:
            emotion = NpcEmotion.joy; dur = 6; mood = 0.04;
          case EventCategory.negative:
            final major = e.severity == EventSeverity.major;
            emotion = NpcEmotion.fear;
            dur = major ? 8 : 5;
            mood = major ? -0.05 : -0.03;
          case EventCategory.neutral:
            emotion = NpcEmotion.wonder; dur = 6; mood = 0.0;
        }
    }
    _feelVillage(emotion, dur, mood);

    // Juice: sarsıcı olaylarda kamera titreşimi (ayar kapalıysa no-op).
    final shake = switch (e.effect?.fx) {
      EventFx.fireOutbreak => 12.0,
      EventFx.storm        => 9.0,
      EventFx.beastEyes    => 8.0,
      EventFx.meteorShower => 5.0,
      _ => e.category == EventCategory.negative
          ? (e.severity == EventSeverity.major ? 10.0 : 5.0)
          : 0.0,
    };
    if (shake > 0) addCameraShake(shake, dur: 0.55);
  }

  // ── Sahnelenmiş tepki — köylüler olaya AMAÇLI hareketle yanıt verir ─────────
  // Salt duygu+sarsıntı değil: tehdide koşar (muhafız/kova zinciri/kovalama) ya
  // da barınağa/ateşe kaçar. Olayı "dünyada gerçekleşen" bir an yapar.

  /// Olayın (ve varsa seçimin) köy davranışına çevrimi. Hem olay hem seçim
  /// KİMLİKLE tanınır — başlık/buton metni yeniden yazılınca sahne susmasın.
  void _stageEventResponse(EventOutcome base, {String? choiceId}) {
    final (tx, ty) = _eventFocusPoint(base);
    final (cx, cy) = _villageCenter();
    final center = (cx.toDouble(), cy.toDouble());
    // BAŞ ROLLER — olayın izlenebilir çekirdeği (roller + adımlar). Aşağıdaki
    // rally/kutlama artık KORO: kalabalığın koşuşması. Vinyet önce çağrılır ki
    // baş roller kadroyu koro dağılmadan seçebilsin (ikisi de aynı "boştaki
    // köylü" havuzundan besleniyor; koro rolleri kapmasın).
    _stageVignette(base, choiceId: choiceId);
    switch (base.id) {
      // ── Pozitif — köye gelen iyilik dünya-içi kutlamayla karşılanır ──────────
      case EventIds.bard:
        _stageCelebration(music: true, dance: true, gather: 7);
      case EventIds.caravan:
        _spawnMerchant(); // olayla birlikte fiziksel tüccar da köşeden gelsin
        _stageCelebration(atMarket: true, gather: 6);
      case EventIds.bounty:
        _stageCelebration(dance: true, gather: 6);
      case EventIds.accord:
        _stageReconciliation();
      // ── Negatif — tehdide amaçlı tepki ──────────────────────────────────────
      case EventIds.beastRaid:
        if (choiceId == 'guards') {
          _rallyToward(tx, ty, count: 4, emotion: NpcEmotion.anger, dwell: 5);
        } else {
          _rallyToward(center.$1, center.$2,
              count: 5, emotion: NpcEmotion.fear, dwell: 5); // ateşe sığın
        }
      case EventIds.houseFire:
        if (choiceId == 'extinguish') {
          _rallyToward(tx, ty, count: 5, emotion: NpcEmotion.fear, dwell: 6);
        } else {
          _rallyToward(center.$1, center.$2,
              count: 4, emotion: NpcEmotion.grief, dwell: 5); // geri çekil
        }
      case EventIds.plague:
        // DİKKAT: bu fonksiyon olay BAŞINDA (choiceId=null) ve KARAR sonrası
        // (choiceId!=null) iki kez çağrılır. Ölümcül tol YALNIZ karar anında —
        // başta köy henüz tedirgin, kimse ölmez.
        if (choiceId == null) {
          _rallyToward(center.$1, center.$2,
              count: 3, emotion: NpcEmotion.fear, dwell: 5); // tedirgin toplanma
        } else if (choiceId == 'healer') {
          _rallyToward(center.$1, center.$2,
              count: 3, emotion: NpcEmotion.fear, dwell: 6); // tedavi etrafı
          _plagueToll(healer: true); // erken kırıldı — ölüm yok, birkaç hafif hasta
        } else {
          _plagueToll(healer: false); // şifacı yok → salgın en zayıfları alır
        }
      case EventIds.drought:
        _rallyToward(tx, ty, count: 4, emotion: NpcEmotion.fear, dwell: 5); // kuyu
      case EventIds.storm:
        _rallyToward(center.$1, center.$2,
            count: 5, emotion: NpcEmotion.fear, dwell: 5); // barınağa koş
    }
  }

  /// Olayın "odak noktası" — köylülerin koşacağı/bakacağı yer (negatifte tehdit,
  /// pozitifte geliş/toplanma yönü).
  (double, double) _eventFocusPoint(EventOutcome e) {
    switch (e.id) {
      case EventIds.houseFire:
        if (_burningBuildings.isNotEmpty) {
          final b = _burningBuildings.first;
          return (b.col + b.cols / 2.0, b.row + b.rows / 2.0);
        }
        return _villageCenterD();
      case EventIds.caravan:
        final m = _firstBuildingOf(BuildingType.market);
        if (m != null) return (m.col + m.cols / 2.0, m.row + m.rows / 2.0);
        return _villageEdgePoint();
      case EventIds.beastRaid:
      case EventIds.bard: // yoldan gelir → kenar yönüne bakılır (geliş hissi)
        return _villageEdgePoint();
      case EventIds.drought:
        final w = _firstBuildingOf(BuildingType.well);
        if (w != null) return (w.col + w.cols / 2.0, w.row + w.rows / 2.0);
        return _villageCenterD();
      default:
        return _villageCenterD();
    }
  }

  /// Birkaç boştaki köylüyü bir noktaya doğru koşturur (tehdide en yakınlar
  /// önce → "koşuşturma" hissi) + uygun gövde dili. `goTo` ile güvenilir hareket.
  void _rallyToward(double x, double y,
      {int count = 4,
      NpcEmotion emotion = NpcEmotion.fear,
      double dwell = 4.0}) {
    final cands = _villagers
        .where((v) =>
            !v.isInsideBuilding &&
            !v.isSleeping &&
            v.hasProfession &&
            !v.isCarrying &&
            !v.isDying &&
            !v.sitClaimed &&
            // Vinyetin baş rolü koroya karışmaz: ceremony niyeti `activity`yi
            // none bırakır, bu yüzden filtre onu YAKALAMAZ ve koşturarak
            // koreografiyi bozardı (kova doldurmaya giden adam meydana kaçar).
            v.mind.intent.priority < IntentPriority.ceremony &&
            v.activity == VillagerActivity.none)
        .toList();
    cands.sort((a, b) {
      final da = (a.gridX - x) * (a.gridX - x) + (a.gridY - y) * (a.gridY - y);
      final db = (b.gridX - x) * (b.gridX - x) + (b.gridY - y) * (b.gridY - y);
      return da.compareTo(db);
    });
    int n = 0;
    for (final v in cands) {
      if (n >= count) break;
      final ox = (_rng.nextDouble() - 0.5) * 1.6;
      final oy = (_rng.nextDouble() - 0.5) * 1.6;
      v.goTo((x + ox).clamp(1.0, kCols - 2.0), (y + oy).clamp(1.0, kRows - 2.0),
          dwell);
      v.feel(emotion, dwell + 2.0);
      n++;
    }
  }

  /// Pozitif olay sahnesi: birkaç köylü müzik/dans eder, gerisi toplanır (ateş
  /// ya da pazar başı) — köy gözle görülür biçimde kutlar. Moral/fx olayın
  /// kendisinden gelir; bu yalnız gövde dilini/toplanmayı sahneler.
  void _stageCelebration({
    bool atMarket = false,
    bool music = false,
    bool dance = false,
    int gather = 6,
  }) {
    const dur = kGameDaySeconds * 0.4;
    // Önce müzisyen/dansçılar (activity != none olur → toplanma onları atlamaz).
    if (music) _startActivityForSome(_tryStartMusicFor, 2, dur);
    if (dance) _startActivityForSome(_tryStartDanceFor, 2, dur);
    // Kalabalık toplanır — tüccarda pazara, diğerlerinde ateşe.
    if (atMarket) {
      final m = _firstBuildingOf(BuildingType.market);
      if (m != null) {
        _rallyToward(m.col + m.cols / 2.0, m.row + m.rows / 2.0,
            count: gather, emotion: NpcEmotion.joy, dwell: 6);
      } else {
        _gatherAtFire(dur, max: gather);
      }
    } else {
      _gatherAtFire(dur, max: gather);
    }
    _feelVillage(NpcEmotion.joy, 8.0, 0.04);
  }

  /// Bir aktiviteyi (müzik/dans) en fazla [count] uygun boş köylüde başlatır.
  void _startActivityForSome(
      bool Function(VillagerEntity) start, int count, double dur) {
    final idle = _villagers
        .where((v) =>
            !v.isInsideBuilding &&
            !v.isSleeping &&
            v.hasProfession &&
            !v.isCarrying &&
            !v.isDying &&
            !v.sitClaimed &&
            v.mind.intent.priority < IntentPriority.ceremony && // baş rol hariç
            v.activity == VillagerActivity.none &&
            v.socialCooldown <= 0)
        .toList()
      ..shuffle(_rng);
    int n = 0;
    for (final v in idle) {
      if (n >= count) break;
      if (start(v)) {
        v.socialCooldown = dur;
        n++;
      }
    }
  }

  /// Zümre barışı: en küskün zümrenin morali belirgin yükselir + köy ateş
  /// başında dayanışmayla toplanır. Estate sistemine dokunur (event_system'in
  /// erişemediği) — bu yüzden sahnede yapılır.
  void _stageReconciliation() {
    final low = _houses.mostAggrieved;
    if (low != null) _houses.nudge(low, moodDelta: 0.14);
    _stageCelebration(dance: true, gather: 7);
  }

  /// Köy merkezi (double) — `_villageCenter` int sürümünün ondalık karşılığı.
  (double, double) _villageCenterD() {
    final (cx, cy) = _villageCenter();
    return (cx.toDouble(), cy.toDouble());
  }

  /// Köy merkezinden EN YAKIN harita kenarına doğru bir nokta (tehdit girişi).
  (double, double) _villageEdgePoint() {
    final (cx, cy) = _villageCenter();
    final dl = cx, dr = kCols - cx, dt = cy, db = kRows - cy;
    var m = dl;
    if (dr < m) m = dr;
    if (dt < m) m = dt;
    if (db < m) m = db;
    if (m == dl) return (2.0, cy.toDouble());
    if (m == dr) return ((kCols - 2).toDouble(), cy.toDouble());
    if (m == dt) return (cx.toDouble(), 2.0);
    return (cx.toDouble(), (kRows - 2).toDouble());
  }

  /// Verilen tipteki ilk binayı döner (yoksa null).
  BuildingEntity? _firstBuildingOf(BuildingType t) {
    for (final b in _buildings) {
      if (b.type == t) return b;
    }
    return null;
  }

  /// Aktif efektleri her tick decay et + aggregate. Sonra tint/rain/sim
  /// multiplier'ları toplanmış halde kullanıma hazır.
  void _updateActiveFx(double dt) {
    if (_activeFx.isEmpty) {
      if (_fxTint.a != 0 ||
          _fxRainBoost != 0 ||
          _fxNpcSpeedMul != 1.0 ||
          _fxFarmMul != 1.0 ||
          _fxBuilderMul != 1.0 ||
          _fxActiveIds.isNotEmpty) {
        _fxTint        = const Color(0x00000000);
        _fxRainBoost   = 0.0;
        _fxNpcSpeedMul = 1.0;
        _fxFarmMul     = 1.0;
        _fxBuilderMul  = 1.0;
        _fxActiveIds.clear();
      }
      return;
    }
    for (final f in _activeFx) {
      f.timeLeft -= dt;
    }
    _activeFx.removeWhere((f) => f.timeLeft <= 0);

    double rA = 0, rR = 0, rG = 0, rB = 0;
    double totalTintA = 0;
    double rain = 0;
    double npc = 1.0, farm = 1.0, builder = 1.0;
    _fxActiveIds.clear();
    for (final f in _activeFx) {
      final ef = f.effect;
      _fxActiveIds.add(ef.fx);
      if (ef.screenTint != null && ef.screenTint!.a > 0) {
        final a = ef.screenTint!.a;
        rA += a;
        rR += ef.screenTint!.r * a;
        rG += ef.screenTint!.g * a;
        rB += ef.screenTint!.b * a;
        totalTintA += a;
      }
      if (ef.rainBoost > rain) rain = ef.rainBoost;
      npc     *= ef.npcSpeedMul;
      farm    *= ef.farmGrowthMul;
      builder *= ef.builderMul;
    }
    if (totalTintA > 0) {
      _fxTint = Color.fromARGB(
        (rA / _activeFx.length * 255).round().clamp(0, 255),
        (rR / totalTintA * 255).round().clamp(0, 255),
        (rG / totalTintA * 255).round().clamp(0, 255),
        (rB / totalTintA * 255).round().clamp(0, 255),
      );
    } else {
      _fxTint = const Color(0x00000000);
    }
    _fxRainBoost   = rain;
    _fxNpcSpeedMul = npc;
    // Kimlik bonusu (Bereketli Köy +%15) × rejim çürümesi (Demir Sofra
    // huzursuzken tezgâh soğur, bkz. scene_regime._regimeWorkMul).
    _fxFarmMul     = farm * _identityFarmMul * _regimeWorkMul;
    _fxBuilderMul  = builder;
    if (!_fxActiveIds.contains(EventFx.fireOutbreak) &&
        _burningBuildings.isNotEmpty) {
      _burningBuildings.clear();
    }
  }
}
