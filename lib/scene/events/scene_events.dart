part of '../../main.dart';

/// Rastgele olay tetikleme + sonuç uygulama + aktif fx aggregation.
/// EventSystem.roll'un üst katmandaki state etkileri burada birleşir.
/// part of main.dart — State'in tüm private alanlarına erişim.
extension _SceneEvents on _VillageSceneState {
  /// Omen (mayalanma) süresi aralığı (sn) — olay vurmadan önceki diegetik uyarı.
  static const double _kOmenMin = GameplayPacing.omenMinSimSeconds;
  static const double _kOmenMax = GameplayPacing.omenMaxSimSeconds;

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
      // YIL BASKISI (bkz. systems/run/village_year.dart): aralık yıl geçtikçe
      // kısalır. Sıklaşan şey olay TABLOSUNUN TAMAMI — yani geç oyun daha
      // olaylı olur, daha cezalı değil. Ceza tarafını vergi zaten büyütüyor;
      // ikisini birden sertleştirmek geç oyunu cozy çizginin dışına atardı.
      final tempo = pressureForDay(_dayCount).eventTempo; // 1.0 → 0.65
      _eventTimer =
          (GameplayPacing.eventMinSimSeconds +
              _rng.nextDouble() *
                  (GameplayPacing.eventMaxSimSeconds -
                      GameplayPacing.eventMinSimSeconds)) *
          tempo;
    }
  }

  /// DevPanel + tick girişi — bir olay mayalamaya başlar (anında vurmaz).
  void _triggerRandomEvent() => _beginOmen();

  /// Mayalanmayı başlat: olayı seç, omen süresini ayarla, diegetik uyarıyı oynat.
  void _beginOmen() {
    if (_omenEvent != null ||
        _pendingChoice != null ||
        _pacedChoices.isNotEmpty) {
      return;
    }
    final ctx = EventContext(
      population: _villagers.length,
      stockpile: _stockpile,
      buildings: _buildings,
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
    if (e == null) {
      _eventTimer = GameplayPacing.eventMaxSimSeconds;
      return;
    }
    logDev(
      'Rastgele olay mayalanıyor: ${e.title}',
      tag: '🎲',
      color: AppUi.info,
    );
    _omenEvent = e;
    _omenLeft = _kOmenMin + _rng.nextDouble() * (_kOmenMax - _kOmenMin);
    _playOmen(e);
  }

  /// Omen evresi — diegetik uyarı: haberci metni + olayın fx'inin hafif (cezasız)
  /// ön-titreşimi + köyün tehdide tedirgin bakışı (gövde dili). Sim duraklamaz.
  void _playOmen(EventOutcome e) {
    _showNotification(
      _omenText(e),
      headline: 'Köyde Bir Kıpırtı',
      topic: VillageNewsTopic.village,
      tone: e.category == EventCategory.negative
          ? VillageNewsTone.caution
          : VillageNewsTone.neutral,
      priority: VillageNewsPriority.noteworthy,
    );
    final positive = e.category == EventCategory.positive;
    // Negatif: olayın KENDİ fx'inin cezasız ön-titreşimi (felaket önsezisi).
    // Pozitif: ön-titreşim yok — sürpriz/sevinç sahnede patlar.
    if (!positive) {
      final fx = e.effect?.fx ?? EventFx.none;
      if (fx != EventFx.none) {
        _activeFx.add(
          ActiveFx(EventEffect(fx: fx, duration: _omenLeft), _omenLeft),
        );
        if (fx == EventFx.fireOutbreak && e.effect != null) {
          _attachFxTargets(e.effect!);
        }
      }
    }
    // Köy odak noktasına döner — negatifte tedirgin, pozitifte umutla (gövde dili).
    final (tx, ty) = _villageCenterD();
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

  /// Yeni olay paketi kendi mayalanma metnini tanımlayana kadar genel işaret.
  String _omenText(EventOutcome e) => '${e.icon} Köyde bir kıpırtı var.';

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
    // PROVA: harness'ların çoğu olay istemez (kadro/telemetri kirlenir);
    // prova köyünde olaylar susturulabilir.
    if (kProbeNoEvents) return;
    if (e.needsChoice) {
      _queueChoiceEvent(e);
      return;
    }
    _applyEventAutomatic(e);
  }

  /// Mühletin son bu oranı = uyarı rampası — mühür kızarır + BİR KEZ
  /// hatırlatma düşer. Dilekçe mührünün %30'uyla aynı ailede.
  static const double _kChoiceUrgentFrac = 0.34;

  /// Karar olayını KUYRUĞA koyar — KAPIDA KUYRUK modeli: modal açılmaz, sim
  /// akmaya devam eder. HUD'a karar mührü iner, mühlet şiddete göre erir:
  ///   major (yangın/salgın) → ~24 sn
  ///   minor (kurt vb.)      → ~30 sn
  /// Karar görünür kalır ama oyuncunun gündemini bir dakikadan uzun işgal etmez.
  void _queueChoiceEvent(EventOutcome e) {
    _requestPacedChoice(e);
  }

  /// Merkezi ritim kapısı bu olaya sıra verdiğinde görünür karar mührünü kurar.
  void _activateChoiceEvent(EventOutcome e) {
    // Kervan olayı bir metin değil, gerçek bir ziyaret grubudur. Karar mührü
    // düşmeden araba ve yükçüler yoldan görünür.
    final grace = e.severity == EventSeverity.major ? 24.0 : 30.0;
    // Modal/mühür/bildirim aynı cümleyi konuşsun: varyant burada materyalize.
    final shown = e.withMessage(e.messageFor(_eventSeed(e)));
    setStateHere(() {
      _pendingChoice = shown;
      _choiceGrace = grace;
      _choiceDeadline = grace;
      _choiceModalOpen = false;
      _choiceUrgentWarned = false;
    });
    kProbeChoiceWaiting = e.id;
    _easeToBaseSpeed();
    // Tehdit karar penceresi boyunca GÖRÜNÜR kalsın: olayın cezasız görsel
    // fx'i (omen'deki ön-titreşimin devamı) pencere süresince yenilenir.
    // Yalnız görsel taşınır (tint) — mul/ceza kolları karara kadar işlemez.
    final fx = e.effect;
    if (e.category == EventCategory.negative &&
        fx != null &&
        fx.fx != EventFx.none) {
      _activeFx.add(
        ActiveFx(
          EventEffect(fx: fx.fx, screenTint: fx.screenTint, duration: grace),
          grace,
        ),
      );
      // Yangın hedefi omen'de seçilmişti; ara tick'te temizlendiyse yeniden.
      if (fx.fx == EventFx.fireOutbreak && _burningBuildings.isEmpty) {
        _attachFxTargets(fx);
      }
    }
    _reactToEvent(shown); // köy gövde diliyle tepki verir — iş değil, bekleyiş
    _showNotification(
      '${e.icon} ${e.title}. Köy karar bekliyor.',
      headline: e.title,
      topic: VillageNewsTopic.village,
      tone: e.category == EventCategory.negative
          ? VillageNewsTone.caution
          : VillageNewsTone.neutral,
      priority: VillageNewsPriority.important,
    );
  }

  /// Kuyruktaki kararın mühleti — scene_tick her tick çağırır. Sim donuksa
  /// dt gelmez, mühlet de erimez: bekleyiş ancak YAŞAYAN köyde işler.
  void _tickChoiceDeadline(double dt) {
    final e = _pendingChoice;
    if (e == null || !e.needsChoice) return;
    _choiceDeadline -= dt;
    if (!_choiceUrgentWarned &&
        _choiceDeadline / _choiceGrace <= _kChoiceUrgentFrac) {
      _choiceUrgentWarned = true;
      _showNotification(
        '${e.icon} ${e.title}: köy hâlâ senden söz bekliyor.',
        headline: e.title,
        topic: VillageNewsTopic.village,
        tone: VillageNewsTone.caution,
        priority: VillageNewsPriority.urgent,
      );
    }
    if (_choiceDeadline <= 0) {
      final c = e.timeoutChoice;
      if (c == null) {
        setStateHere(() => _pendingChoice = null);
        return;
      }
      kProbeChoiceTimeouts++;
      _applyEventChoice(e, c, timedOut: true);
    }
  }

  /// Karar mührüne tıklanınca — modal açılır (sim yine durmaz; mühlet de
  /// akmaya devam eder, okurken dolarsa sonuç bildirimle düşer).
  void _openChoiceModal() => setStateHere(() => _choiceModalOpen = true);

  /// Boşluğa dokununca modal mühre geri iner — karar kuyruğu bozulmaz.
  void _dismissChoiceModal() => setStateHere(() => _choiceModalOpen = false);

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
      _eventMorale = e.moraleModifier;
      _eventMoraleLeft = e.duration;
      _eventLabel = '${e.icon} ${e.title}';
    }
    // Havuzdan varyantı SABİT tohumla seç ve olaya işle — banner ile bildirim
    // aynı cümleyi göstersin (ikisi de `.message` okur).
    final seed = _eventSeed(e);
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
    _chronicle(
      Voice.weave(e.annalFor(seed), _voice(null, seed: seed)),
      icon: e.icon,
    );
    _showNotification(
      shown.message,
      headline: shown.title,
      topic: VillageNewsTopic.village,
      tone: switch (shown.category) {
        EventCategory.positive => VillageNewsTone.favorable,
        EventCategory.negative => VillageNewsTone.caution,
        EventCategory.neutral => VillageNewsTone.neutral,
      },
      priority: shown.severity == EventSeverity.major
          ? VillageNewsPriority.important
          : VillageNewsPriority.noteworthy,
    );
  }

  /// fireOutbreak gibi belirli bir bina/NPC'ye bağlı fx'lerin hedeflerini
  /// seçer. Sahne renderı bu hedeflere göre özelleştirilmiş animasyon çizer.
  void _attachFxTargets(EventEffect ef) {
    if (ef.fx == EventFx.fireOutbreak) {
      // Yangın önce konuta düşer: olayın görsel sonucu (isli çatı, kırık cam)
      // bir haneye ait olmalı. Konut yoksa eski geniş aday kümesine geri dön.
      final candidates = _buildings
          .where((b) => b.fn?.role == BuildingRole.housing)
          .toList();
      final pool = candidates.isNotEmpty
          ? candidates
          : _buildings
                .where(
                  (b) =>
                      b.type != BuildingType.firepit &&
                      b.type != BuildingType.lamppost &&
                      b.type != BuildingType.well,
                )
                .toList();
      if (pool.isNotEmpty) {
        final target = pool[_rng.nextInt(pool.length)];
        target.damage = target.damage < 0.72 ? 0.72 : target.damage;
        _burningBuildings.add(target);
      }
    }
  }

  /// Karar bekleyen olayda seçim uygulanınca: choice deltalarını uygula,
  /// kuyruğu boşalt, banner ile sonuç gösterimi yap. [timedOut] = seçim
  /// oyuncudan değil mühletin dolmasından geldi (köy pasif seçeneği yaşadı);
  /// günce satırı bunu açıkça söyler — sessiz kayıp yok.
  void _applyEventChoice(
    EventOutcome base,
    EventChoice c, {
    bool timedOut = false,
  }) {
    if (!timedOut && !c.canAfford(_stockpile)) {
      _showNotification(
        'Bu karar için köyün kaynağı yetmiyor.',
        headline: 'Karar Uygulanamadı',
        topic: VillageNewsTopic.system,
        tone: VillageNewsTone.caution,
        priority: VillageNewsPriority.urgent,
      );
      return;
    }
    if (base.id == EventIds.specialistCaravan) {
      _acceptSpecialistChoice(c);
    }
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
      _eventMorale = c.moraleModifier;
      _eventMoraleLeft = c.duration;
      _eventLabel = '${base.icon} ${base.title}';
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
    _startEventAftermath(base, c);
    // Vakanüvis: kararın kuru izi ("Kova zinciri kuruldu. Ev kurtarıldı.").
    // Zaman aşımında iz "söz gelmedi" diye başlar — suskunluk da bir karardır
    // ve güncede öyle okunur.
    final annal = c.annal.isEmpty ? '${base.title}: ${c.label}' : c.annal;
    _chronicle(
      timedOut ? 'Söz gelmedi. $annal' : annal,
      icon: base.icon,
      kind: ChronicleKind.decision,
    );
    _activeEvent = EventOutcome(
      id: base.id,
      title: base.title,
      icon: base.icon,
      message: c.resolutionMessage,
      category: base.category,
      severity: base.severity,
      foodDelta: c.foodDelta,
      goldDelta: c.goldDelta,
      woodDelta: c.woodDelta,
      stoneDelta: c.stoneDelta,
      ironDelta: c.ironDelta,
      coalDelta: c.coalDelta,
      moraleModifier: c.moraleModifier,
      duration: c.duration,
      effect: fx,
    );
    _activeEventLeft = kEventBannerDuration;
    _reactToEvent(_activeEvent!); // çözüm sonrası köy gövde diliyle tepki verir
    _showNotification(
      c.resolutionMessage,
      headline: base.title,
      topic: VillageNewsTopic.village,
      tone: switch (base.category) {
        EventCategory.positive => VillageNewsTone.favorable,
        EventCategory.negative => VillageNewsTone.caution,
        EventCategory.neutral => VillageNewsTone.neutral,
      },
      priority: base.severity == EventSeverity.major
          ? VillageNewsPriority.important
          : VillageNewsPriority.noteworthy,
    );
    kProbeChoiceWaiting = '';
    setStateHere(() {
      _pendingChoice = null;
      _choiceModalOpen = false;
      _choiceDeadline = 0;
    });
  }

  /// Bir olayı köy çapı gövde-dili tepkisine çevirir (baş üstü emoji YOK).
  /// Önce belirli fx'ler ince ayar, sonra kategori/şiddet.
  void _reactToEvent(EventOutcome e) {
    final NpcEmotion emotion;
    double dur, mood;
    switch (e.effect?.fx) {
      case EventFx.beastEyes:
        emotion = NpcEmotion.fear;
        dur = 7;
        mood = -0.03;
      case EventFx.harvestBounty:
        emotion = NpcEmotion.joy;
        dur = 8;
        mood = 0.05;
      default:
        switch (e.category) {
          case EventCategory.positive:
            emotion = NpcEmotion.joy;
            dur = 6;
            mood = 0.04;
          case EventCategory.negative:
            final major = e.severity == EventSeverity.major;
            emotion = NpcEmotion.fear;
            dur = major ? 8 : 5;
            mood = major ? -0.05 : -0.03;
          case EventCategory.neutral:
            emotion = NpcEmotion.wonder;
            dur = 6;
            mood = 0.0;
        }
    }
    _feelVillage(emotion, dur, mood);

    // Juice: sarsıcı olaylarda kamera titreşimi (ayar kapalıysa no-op).
    final shake = switch (e.effect?.fx) {
      EventFx.fireOutbreak => 12.0,
      EventFx.storm => 9.0,
      EventFx.beastEyes => 8.0,
      _ =>
        e.category == EventCategory.negative
            ? (e.severity == EventSeverity.major ? 10.0 : 5.0)
            : 0.0,
    };
    if (shake > 0) addCameraShake(shake, dur: 0.55);
  }

  // ── Sahnelenmiş tepki — köylüler olaya AMAÇLI hareketle yanıt verir ─────────
  // Salt duygu+sarsıntı değil: tehdide koşar (muhafız/kova zinciri/kovalama) ya
  // da barınağa/ateşe kaçar. Olayı "dünyada gerçekleşen" bir an yapar.

  /// Olay paketinin dünya koreografisini ortak yönetmene devreder.
  void _stageEventResponse(EventOutcome base, {String? choiceId}) {
    _stageVignette(base, choiceId: choiceId);
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
          _fxActiveIds.isNotEmpty ||
          _fxPlayback.isNotEmpty) {
        _fxTint = const Color(0x00000000);
        _fxRainBoost = 0.0;
        _fxNpcSpeedMul = 1.0;
        _fxFarmMul = 1.0;
        _fxBuilderMul = 1.0;
        _fxActiveIds.clear();
        _fxPlayback.clear();
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
    _fxPlayback.clear();
    for (final f in _activeFx) {
      final ef = f.effect;
      _fxActiveIds.add(ef.fx);
      if (ef.fx != EventFx.none) {
        final duration = ef.duration > 0 ? ef.duration : f.timeLeft;
        final playback = EventFxPlayback(
          elapsed: (duration - f.timeLeft).clamp(0.0, duration),
          duration: duration,
          timeLeft: f.timeLeft.clamp(0.0, duration),
        );
        final previous = _fxPlayback[ef.fx];
        // Aynı efekt üst üste tetiklenirse en yeni örnek görsel zaman çizgisini
        // yeniden başlatır; simülasyon çarpanları aşağıda yine birlikte işler.
        if (previous == null || playback.elapsed < previous.elapsed) {
          _fxPlayback[ef.fx] = playback;
        }
      }
      if (ef.screenTint != null && ef.screenTint!.a > 0) {
        final a = ef.screenTint!.a;
        rA += a;
        rR += ef.screenTint!.r * a;
        rG += ef.screenTint!.g * a;
        rB += ef.screenTint!.b * a;
        totalTintA += a;
      }
      if (ef.rainBoost > rain) rain = ef.rainBoost;
      npc *= ef.npcSpeedMul;
      farm *= ef.farmGrowthMul;
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
    _fxRainBoost = rain;
    _fxNpcSpeedMul = npc;
    // Kimlik bonusu (Bereketli Köy +%15) × rejim çürümesi (Demir Sofra
    // huzursuzken tezgâh soğur, bkz. scene_regime._regimeWorkMul).
    _fxFarmMul = farm * _identityFarmMul * _regimeWorkMul;
    _fxBuilderMul = builder;
    if (!_fxActiveIds.contains(EventFx.fireOutbreak) &&
        _burningBuildings.isNotEmpty) {
      _burningBuildings.clear();
    }
  }
}
