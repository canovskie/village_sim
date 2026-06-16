part of '../main.dart';

/// Rastgele olay tetikleme + sonuç uygulama + aktif fx aggregation.
/// EventSystem.roll'un üst katmandaki state etkileri burada birleşir.
/// part of main.dart — State'in tüm private alanlarına erişim.
extension _SceneEvents on _VillageSceneState {
  void _triggerRandomEvent() {
    final ctx = EventContext(
      population: _villagers.length,
      stockpile:  _stockpile,
      buildings:  _buildings,
    );
    final e = EventSystem.roll(_rng, ctx);

    if (e.needsChoice) {
      _pendingChoice = e;
      _showNotification('${e.icon} ${e.title} — karar bekliyor');
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
    _activeEvent = e;
    _activeEventLeft = kEventBannerDuration;

    if (e.effect != null && e.effect!.duration > 0) {
      _activeFx.add(ActiveFx(e.effect!, e.effect!.duration));
      _attachFxTargets(e.effect!);
    }

    _reactToEvent(e); // köy gövde diliyle tepki verir (emoji yok, postür)
    _showNotification(e.message);
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
      _attachFxTargets(fx);
    }
    _activeEvent = EventOutcome(
      title:    '${base.title} — ${c.label}',
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
      case EventFx.thiefDash:
        emotion = NpcEmotion.anger; dur = 6; mood = -0.02;
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
    _fxFarmMul     = farm;
    _fxBuilderMul  = builder;
    if (!_fxActiveIds.contains(EventFx.fireOutbreak) &&
        _burningBuildings.isNotEmpty) {
      _burningBuildings.clear();
    }
  }
}
