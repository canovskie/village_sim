part of '../main.dart';

/// KÖY NABZI — bekleme anlarını isimli insanların küçük gündemleriyle doldurur.
///
/// Bu sistem bir ikinci dilekçe kuyruğu değildir:
///   • modal açmaz, dünyadaki kişiye ilişir;
///   • gerçek zaman aralığı kullanır, dolayısıyla 2× hızda yağmur gibi yağmaz;
///   • tek cümle + iki kısa karar taşır;
///   • oyuncu dokunmazsa kişi kendi kararını verir;
///   • önemli sonuç 1-3 oyun günü sonra yeniden hatırlanır.
enum _VillagePulseKind {
  sharedMeal,
  doorstepGarden,
  calling,
  reconcile,
  care,
  rest,
  mending,
}

class _VillagePulse {
  final _VillagePulseKind kind;
  final VillagerEntity actor;
  final VillagerEntity? other;
  final double totalReal;
  double remainingReal;

  _VillagePulse({
    required this.kind,
    required this.actor,
    this.other,
    this.totalReal = GameplayPacing.pulseDecisionRealSeconds,
    double? remainingReal,
  }) : remainingReal = remainingReal ?? totalReal;
}

class _VillagePulseDraft {
  final _VillagePulseKind kind;
  final VillagerEntity actor;
  final VillagerEntity? other;
  const _VillagePulseDraft(this.kind, this.actor, [this.other]);
}

class _VillagePulseEcho {
  final double dueSim;
  final String icon;
  final String text;
  final VillagerEntity? actor;
  const _VillagePulseEcho({
    required this.dueSim,
    required this.icon,
    required this.text,
    this.actor,
  });
}

extension _SceneVillagePulse on _VillageSceneState {
  // ── Döngü ────────────────────────────────────────────────────────────────

  /// [realDt] hız çarpanından ÖNCEKİ zaman; hikâye aralığının tek sahibi.
  /// Sim duruyorsa scene_tick bu metodu çağırmaz, yani oyuncu mola verdiğinde
  /// köylüler arkada karar vermez.
  void _tickVillagePulse(double realDt) {
    _tickVillagePulseEchoes();
    if (!_villagePulseWorldReady) return;

    final active = _villagePulse;
    if (active != null) {
      if (active.actor.isDying || !_villagers.contains(active.actor)) {
        _villagePulse = null;
        _villagePulseOpen = false;
        _villagePulseNextReal = _nextVillagePulseDelay();
        return;
      }
      if (_villagePulseUiBusy) return;
      active.remainingReal -= realDt;
      if (active.remainingReal <= 0) _resolveVillagePulse(autonomous: true);
      return;
    }

    if (_villagePulseUiBusy) return;
    _villagePulseNextReal -= realDt;
    if (_villagePulseNextReal <= 0) _startVillagePulse();
  }

  bool get _villagePulseWorldReady =>
      !kCaptureMode &&
      !kProbeOn &&
      !_foundingModeActive &&
      _governanceAwake &&
      _hasFire &&
      _villagers.length >= 3;

  /// Büyük bir karar/panel açıkken küçük hikâye görünmez ve mühleti donuk kalır.
  /// Oyuncu Defter okurken arka planda fırsat kaçırmaz.
  bool get _villagePulseUiBusy =>
      _activeCutscene != null ||
      _imperialDemand != null ||
      _petitionModalOpen ||
      _choiceModalOpen ||
      _ledgerSection != null ||
      _lawRitual != null ||
      _exitConfirmOpen ||
      _pendingJudgment != null ||
      _detailExpanded;

  void _startVillagePulse() {
    final drafts = _villagePulseDrafts();
    if (drafts.isEmpty) {
      _villagePulseNextReal =
          GameplayPacing.pulseRetryMinRealSeconds +
          _rng.nextDouble() *
              (GameplayPacing.pulseRetryMaxRealSeconds -
                  GameplayPacing.pulseRetryMinRealSeconds);
      return;
    }

    var pool = drafts;
    final varied = drafts
        .where(
          (d) =>
              d.kind != _villagePulseLastKind &&
              !identical(d.actor, _villagePulseLastActor),
        )
        .toList();
    if (varied.isNotEmpty) pool = varied;
    final d = pool[_rng.nextInt(pool.length)];
    _villagePulse = _VillagePulse(kind: d.kind, actor: d.actor, other: d.other);
    _villagePulseOpen = false;
    _villagePulseLastKind = d.kind;
    _villagePulseLastActor = d.actor;

    // Tek-seferlik kişisel gündemleri daha doğarken mühürle. Oyuncu görmezden
    // gelse bile aynı kişi iki dakika sonra aynı isteği yeniden söylemez.
    if (d.kind == _VillagePulseKind.doorstepGarden ||
        d.kind == _VillagePulseKind.calling ||
        d.kind == _VillagePulseKind.reconcile) {
      _villageMemory.add(_villagePulseMemoryKey(d.kind, d.actor, d.other));
    }
  }

  List<_VillagePulseDraft> _villagePulseDrafts() {
    final alive = _villagers
        .where(
          (v) =>
              !v.isDying &&
              !v.isLeaving &&
              v.lifeStage != LifeStage.child &&
              v.laborDays <= 0 &&
              _villagePulseActorOnScreen(v),
        )
        .toList();
    if (alive.isEmpty) return const [];

    final out = <_VillagePulseDraft>[];

    // Ortak sofra tekrar edebilir; aday sayısını sınırlamak ağırlığını diğer
    // nadir kişisel hikâyelerin üstüne bindirmesin.
    final meal = [...alive]..shuffle(_rng);
    for (final v in meal.take(2)) {
      out.add(_VillagePulseDraft(_VillagePulseKind.sharedMeal, v));
    }

    // Her köyde tekrar üretilebilen iki farklı gündem. Kişisel tek-seferlik
    // hikâyeler tükendiğinde havuz yalnız "ortak sofra"ya çökmesin.
    final everyday = [...alive]..shuffle(_rng);
    if (everyday.isNotEmpty) {
      out.add(_VillagePulseDraft(_VillagePulseKind.rest, everyday.first));
    }
    final damaged = _buildings.where((b) => b.damage > 0.08).toList();
    if (damaged.isNotEmpty && alive.isNotEmpty) {
      out.add(_VillagePulseDraft(_VillagePulseKind.mending, everyday.last));
    }

    for (final v in alive) {
      final home = v.homeBuilding;
      if (home is BuildingEntity &&
          !_villageMemory.contains(
            _villagePulseMemoryKey(_VillagePulseKind.doorstepGarden, v),
          )) {
        out.add(_VillagePulseDraft(_VillagePulseKind.doorstepGarden, v));
      }
      if (v.callingFound &&
          v.type != v.calling &&
          !_villageMemory.contains(
            _villagePulseMemoryKey(_VillagePulseKind.calling, v),
          )) {
        out.add(_VillagePulseDraft(_VillagePulseKind.calling, v));
      }
      if (v.sickDays > 0.3) {
        out.add(_VillagePulseDraft(_VillagePulseKind.care, v));
      }
      for (final e in v.grudges.entries) {
        final other = e.key;
        if (e.value <= _time || other.isDying || !_villagers.contains(other)) {
          continue;
        }
        // Çifti bir kez ekle; aynı kırgınlık iki yönden yazılmış olabilir.
        if (_villagers.indexOf(v) >= _villagers.indexOf(other)) continue;
        final key = _villagePulseMemoryKey(
          _VillagePulseKind.reconcile,
          v,
          other,
        );
        if (!_villageMemory.contains(key)) {
          out.add(_VillagePulseDraft(_VillagePulseKind.reconcile, v, other));
        }
      }
    }
    return out;
  }

  /// Nabız bir HUD bildirimi değil, dünyada görülen bir insandır. Kameranın
  /// dışındaki birini seçmek oyuncuya görünmeyen bir sayaç kurmak olurdu;
  /// yalnız o an ekranda bulunan kişi aday havuzuna girer.
  bool _villagePulseActorOnScreen(VillagerEntity v) {
    final size = _viewSize;
    if (size.width <= 0 || size.height <= 0) return false;
    final (gx, gy) = _villagePulseFocus(v);
    final raw = gridToScreen(gx, gy, size, _camera + _shakeOffset);
    final center = Offset(size.width / 2, size.height / 2);
    final p = center + (raw - center) * _zoom;
    return p.dx >= 36 &&
        p.dx <= size.width - 36 &&
        p.dy >= 72 &&
        p.dy <= size.height - 90;
  }

  (double, double) _villagePulseFocus(VillagerEntity v) {
    final home = v.homeBuilding;
    if (v.isInsideBuilding && home is BuildingEntity) {
      return (home.col + home.cols / 2, home.row + home.rows / 2);
    }
    return (v.gridX, v.gridY);
  }

  String _villagePulseMemoryKey(
    _VillagePulseKind kind,
    VillagerEntity actor, [
    VillagerEntity? other,
  ]) {
    final names = other == null
        ? '${actor.name}.${actor.surname}'
        : ([
            '${actor.name}.${actor.surname}',
            '${other.name}.${other.surname}',
          ]..sort()).join('+');
    return 'pulse.${kind.name}.$names';
  }

  // ── Metin + maliyet ──────────────────────────────────────────────────────

  String _villagePulseIcon(_VillagePulse p) => switch (p.kind) {
    _VillagePulseKind.sharedMeal => '🍲',
    _VillagePulseKind.doorstepGarden => '🌼',
    _VillagePulseKind.calling => '🛠️',
    _VillagePulseKind.reconcile => '🤝',
    _VillagePulseKind.care => '🍯',
    _VillagePulseKind.rest => '🌤',
    _VillagePulseKind.mending => '🔨',
  };

  String _villagePulseTitle(_VillagePulse p) => switch (p.kind) {
    _VillagePulseKind.sharedMeal => 'Ateş başında bir tas daha',
    _VillagePulseKind.doorstepGarden => 'Kapının önüne biraz renk',
    _VillagePulseKind.calling => 'Eli başka işe gidiyor',
    _VillagePulseKind.reconcile => 'Eski kırgınlık',
    _VillagePulseKind.care => 'Hastaya bir el',
    _VillagePulseKind.rest => 'Bir nefeslik pay',
    _VillagePulseKind.mending => 'Çatıda ilk çatlak',
  };

  String _villagePulseBody(_VillagePulse p) => switch (p.kind) {
    _VillagePulseKind.sharedMeal =>
      '${p.actor.name}, bu akşam ocaktaki yemeği köy halkıyla paylaşmak istiyor.',
    _VillagePulseKind.doorstepGarden =>
      '${p.actor.name}, evinin önüne küçük bir çit ve birkaç çiçek dikmek istiyor.',
    _VillagePulseKind.calling =>
      '${p.actor.name} ${p.actor.type.displayName.toLowerCase()} olarak çalışıyor; gönlü ${p.actor.calling.displayName.toLowerCase()} işinde.',
    _VillagePulseKind.reconcile =>
      '${p.actor.name} ile ${p.other!.name} aynı sofraya oturursa aralarındaki buz eriyebilir.',
    _VillagePulseKind.care =>
      '${p.actor.name} hastalığı ağır geçiriyor. Bir kaşık bal gücünü çabuk toplamasını sağlar.',
    _VillagePulseKind.rest =>
      '${p.actor.name} günlerdir aynı işi sürdürüyor. Bugün erkenden ocağa dönmek istiyor.',
    _VillagePulseKind.mending =>
      '${p.actor.name} yıpranan yapılardan birini bugün onarmak istiyor.',
  };

  String _villagePulsePrimaryLabel(_VillagePulse p) => switch (p.kind) {
    _VillagePulseKind.sharedMeal => 'Sofrayı büyüt',
    _VillagePulseKind.doorstepGarden => 'Çit ve fidan ver',
    _VillagePulseKind.calling => 'Çağrısını izlesin',
    _VillagePulseKind.reconcile => 'Aynı sofraya çağır',
    _VillagePulseKind.care => 'Bir kaşık bal ver',
    _VillagePulseKind.rest => 'Bugünü kısa tutsun',
    _VillagePulseKind.mending => 'Sağlam onarım yap',
  };

  String? _villagePulsePrimarySub(_VillagePulse p) => switch (p.kind) {
    _VillagePulseKind.sharedMeal => '3 yiyecek',
    _VillagePulseKind.doorstepGarden => '2 odun',
    _VillagePulseKind.calling => 'Mesleği değişir',
    _VillagePulseKind.reconcile => '2 yiyecek',
    _VillagePulseKind.care => '1 bal',
    _VillagePulseKind.rest => 'Moral kazanır',
    _VillagePulseKind.mending => '2 odun',
  };

  String _villagePulseSecondaryLabel(_VillagePulse p) => switch (p.kind) {
    _VillagePulseKind.sharedMeal => 'Kendi aralarında paylaşsınlar',
    _VillagePulseKind.doorstepGarden => 'Kendi imkânıyla yapsın',
    _VillagePulseKind.calling => 'Köyün işi önce',
    _VillagePulseKind.reconcile => 'Karışma',
    _VillagePulseKind.care => 'Köy halkı baksın',
    _VillagePulseKind.rest => 'İşini tamamlasın',
    _VillagePulseKind.mending => 'Eldekiyle yamasın',
  };

  String? _villagePulseSecondarySub(_VillagePulse p) => switch (p.kind) {
    _VillagePulseKind.sharedMeal => 'Küçük bir sofra',
    _VillagePulseKind.doorstepGarden => 'Tek çiçeklik',
    _VillagePulseKind.calling => 'Şimdiki işinde kalır',
    _VillagePulseKind.reconcile => 'Kırgınlık sürer',
    _VillagePulseKind.care => 'Yavaş iyileşir',
    _VillagePulseKind.rest => 'Üretim sürer',
    _VillagePulseKind.mending => 'Küçük onarım',
  };

  bool _villagePulsePrimaryEnabled(_VillagePulse p) => switch (p.kind) {
    _VillagePulseKind.sharedMeal => _stockpile.food >= 3,
    _VillagePulseKind.doorstepGarden => _stockpile.wood >= 2,
    _VillagePulseKind.calling => true,
    _VillagePulseKind.reconcile => _stockpile.food >= 2,
    _VillagePulseKind.care => _stockpile.honey >= 1,
    _VillagePulseKind.rest => true,
    _VillagePulseKind.mending => _stockpile.wood >= 2,
  };

  // ── Karar + dünya sonucu ─────────────────────────────────────────────────

  void _chooseVillagePulse(bool primary) {
    final p = _villagePulse;
    if (p == null || (primary && !_villagePulsePrimaryEnabled(p))) return;
    _resolveVillagePulse(primary: primary);
  }

  void _resolveVillagePulse({bool primary = false, bool autonomous = false}) {
    final p = _villagePulse;
    if (p == null) return;
    final actor = p.actor;
    final other = p.other;

    // Kendi kararında bazı insanlar güvenli yolu, bazıları gönlünü seçer.
    if (autonomous) {
      primary = switch (p.kind) {
        _VillagePulseKind.calling =>
          actor.morale >= 0.58 || _rng.nextDouble() < 0.55,
        _VillagePulseKind.reconcile => _rng.nextDouble() < 0.42,
        _ => false,
      };
    }

    _villagePulse = null;
    _villagePulseOpen = false;
    _villagePulseNextReal = _nextVillagePulseDelay();

    switch (p.kind) {
      case _VillagePulseKind.sharedMeal:
        if (primary) {
          _stockpile.food -= 3;
          actor.feel(NpcEmotion.joy, 5.0, moodDelta: 0.10);
          _reactNearby(
            actor.gridX,
            actor.gridY,
            5.0,
            NpcEmotion.joy,
            3.0,
            moodDelta: 0.03,
          );
          if (_fireBurning) _gatherAtFire(kGameDaySeconds * 0.10, max: 5);
          pushPolicyMorale(0.02, 1.0);
          _lifeEvent(
            actor,
            'Köy halkına ateş başında sofra kurdu.',
            icon: '🍲',
          );
          _showNotification(
            '🍲 ${actor.name} ateş başında büyük bir sofra kurdu.',
          );
          _scheduleVillagePulseEcho(
            actor,
            '🍲',
            '${actor.name} tarafından kurulan sofra hâlâ köyün dilinde.',
          );
        } else {
          if (_stockpile.food > 0) _stockpile.food -= 1;
          actor.feel(NpcEmotion.content, 4.0, moodDelta: 0.04);
          if (_fireBurning) _gatherAtFire(kGameDaySeconds * 0.06, max: 3);
          _showNotification(
            '🍲 ${actor.name} elindekini iki köylüyle paylaştı.',
          );
        }

      case _VillagePulseKind.doorstepGarden:
        final count = primary ? 2 : 1;
        if (primary) _stockpile.wood -= 2;
        final planted = _plantPulseGarden(actor, count);
        actor.feel(NpcEmotion.joy, 4.5, moodDelta: primary ? 0.09 : 0.04);
        _lifeEvent(
          actor,
          primary
              ? 'Evinin önüne çitli bir çiçeklik kurdu.'
              : 'Kapısının önüne tek bir demet dikti.',
          icon: '🌼',
        );
        _showNotification(
          planted > 0
              ? '🌼 ${actor.name} kapısının önünü çiçeklendirdi.'
              : '🌼 ${actor.name} çiçeklere uygun bir köşe bulamadı.',
        );
        if (planted > 0) {
          _scheduleVillagePulseEcho(
            actor,
            '🌼',
            '${actor.name} kapısına diktiği çiçekleri büyüttü; köylüler de tohum istiyor.',
          );
        }

      case _VillagePulseKind.calling:
        if (primary) {
          final wanted = actor.calling.displayName.toLowerCase();
          _emptySlot(actor);
          _grantCalling(actor);
          _lifeEvent(
            actor,
            'Kendi çağrısının ardına düştü: $wanted.',
            icon: '🛠️',
          );
          _scheduleVillagePulseEcho(
            actor,
            '🛠️',
            '${actor.name} yeni işi ${actor.type.displayName.toLowerCase()} tezgâhında elini hızlandırdı.',
            days: 2.0,
          );
        } else {
          actor.feel(NpcEmotion.content, 3.5, moodDelta: -0.05);
          _lifeEvent(
            actor,
            'Gönlü başka işteyken köyün işinde kaldı.',
            icon: '🌫️',
          );
          _showNotification(
            autonomous
                ? '🌫️ ${actor.name} gönlünü susturup şimdiki işinde kaldı.'
                : '🌫️ ${actor.name} şimdilik ${actor.type.displayName.toLowerCase()} işinde kaldı.',
          );
        }

      case _VillagePulseKind.reconcile:
        if (other == null || other.isDying) return;
        if (primary) {
          if (!autonomous) _stockpile.food -= 2;
          actor.grudges.remove(other);
          other.grudges.remove(actor);
          actor.feel(NpcEmotion.content, 5.0, moodDelta: 0.10);
          other.feel(NpcEmotion.content, 5.0, moodDelta: 0.10);
          if (_fireBurning) _gatherAtFire(kGameDaySeconds * 0.08, max: 4);
          _lifeEvent(
            actor,
            '${other.name} ile aynı sofrada barıştı.',
            icon: '🤝',
          );
          _lifeEvent(
            other,
            '${actor.name} ile aynı sofrada barıştı.',
            icon: '🤝',
          );
          _showNotification(
            '🤝 ${actor.name} ile ${other.name} aynı sofrada barıştı.',
          );
          _scheduleVillagePulseEcho(
            actor,
            '🤝',
            '${actor.name} ile ${other.name} yeniden selamlaşmaya başladı.',
            days: 1.5,
          );
        } else {
          actor.feel(NpcEmotion.anger, 2.5, moodDelta: -0.02);
          _showNotification(
            '🕯 ${actor.name} ile ${other.name} arasındaki kırgınlık sürüyor.',
          );
        }

      case _VillagePulseKind.care:
        if (primary) {
          _stockpile.honey -= 1;
          actor.sickDays = max(0.0, actor.sickDays - 0.8);
          actor.feel(NpcEmotion.content, 5.0, moodDelta: 0.10);
          _lifeEvent(
            actor,
            'Hastalığında köyün balından şifa buldu.',
            icon: '🍯',
          );
          _showNotification('🍯 Bir kaşık bal ${actor.name} için iyi geldi.');
          _scheduleVillagePulseEcho(
            actor,
            '🌿',
            '${actor.name} yeniden kapısının önüne çıktı; rengi yerine geliyor.',
          );
        } else {
          actor.sickDays = max(0.0, actor.sickDays - 0.2);
          actor.feel(NpcEmotion.content, 4.0, moodDelta: 0.04);
          _reactNearby(actor.gridX, actor.gridY, 3.5, NpcEmotion.content, 2.0);
          _showNotification(
            '🌿 Köylüler ${actor.name} için kapıyı boş bırakmadı.',
          );
        }

      case _VillagePulseKind.rest:
        if (primary) {
          actor.feel(NpcEmotion.joy, 6.0, moodDelta: 0.09);
          actor.glanceAround(duration: 5.0);
          _lifeEvent(actor, 'Bir gün işini erken bırakıp ocakta soluklandı.');
          _showNotification(
            '🌤 ${actor.name} bugün işini erken bıraktı; yüzü biraz açıldı.',
          );
        } else {
          actor.feel(NpcEmotion.content, 3.0, moodDelta: -0.02);
          _showNotification(
            '🌤 ${actor.name} işi bitirdi, dinlenmeyi yarına bıraktı.',
          );
        }

      case _VillagePulseKind.mending:
        final damaged = _buildings.where((b) => b.damage > 0.0).toList()
          ..sort((a, b) => b.damage.compareTo(a.damage));
        if (damaged.isEmpty) return;
        final building = damaged.first;
        if (primary) {
          _stockpile.wood -= 2;
          building.damage = max(0.0, building.damage - 0.35);
          actor.feel(NpcEmotion.content, 4.0, moodDelta: 0.06);
          _showNotification(
            '🔨 ${actor.name} en yıpranmış yapıyı sağlam keresteyle onardı.',
          );
        } else {
          building.damage = max(0.0, building.damage - 0.10);
          _showNotification(
            '🔨 ${actor.name} çatlağı eldeki parçalarla geçici olarak kapattı.',
          );
        }
    }
  }

  double _nextVillagePulseDelay() =>
      GameplayPacing.pulseNextMinRealSeconds +
      _rng.nextDouble() *
          (GameplayPacing.pulseNextMaxRealSeconds -
              GameplayPacing.pulseNextMinRealSeconds);

  int _plantPulseGarden(VillagerEntity actor, int wanted) {
    final home = actor.homeBuilding;
    if (home is! BuildingEntity) return 0;
    final cands = <(int, int)>[];
    for (int dc = -2; dc <= home.cols + 1; dc++) {
      for (int dr = -2; dr <= home.rows + 1; dr++) {
        final c = home.col + dc, r = home.row + dr;
        if (c < 1 || c >= kCols - 1 || r < 1 || r >= kRows - 1) continue;
        final beside =
            dc == -1 || dr == -1 || dc == home.cols || dr == home.rows;
        if (!beside) continue;
        cands.add((c, r));
      }
    }
    cands.shuffle(_rng);
    const flowers = [
      DecorKind.daisy,
      DecorKind.poppy,
      DecorKind.lavender,
      DecorKind.buttercup,
    ];
    var planted = 0;
    for (final (c, r) in cands) {
      if (planted >= wanted) break;
      final kind = flowers[_rng.nextInt(flowers.length)];
      if (_tryPlantDecor(c, r, kind, jitter: 0.38)) planted++;
    }
    return planted;
  }

  void _scheduleVillagePulseEcho(
    VillagerEntity actor,
    String icon,
    String text, {
    double? days,
  }) {
    _villagePulseEchoes.add(
      _VillagePulseEcho(
        dueSim:
            _time + (days ?? (1.2 + _rng.nextDouble() * 1.4)) * kGameDaySeconds,
        icon: icon,
        text: text,
        actor: actor,
      ),
    );
  }

  void _tickVillagePulseEchoes() {
    for (var i = 0; i < _villagePulseEchoes.length; i++) {
      final e = _villagePulseEchoes[i];
      if (e.dueSim > _time) continue;
      _villagePulseEchoes.removeAt(i);
      final actor = e.actor;
      if (actor != null && _villagers.contains(actor) && !actor.isDying) {
        actor.feel(NpcEmotion.content, 4.0, moodDelta: 0.04);
      }
      _chronicle(e.text, icon: e.icon);
      _showNotification('${e.icon} ${e.text}');
      return; // aynı karede iki yankı birbirinin bildirimini ezmesin
    }
  }

  // ── Dünya işareti + kompakt kart ─────────────────────────────────────────

  Widget buildVillagePulseLayer() {
    return Positioned.fill(
      child: ListenableBuilder(
        listenable: _frame,
        builder: (context, _) {
          final p = _villagePulse;
          if (p == null || _villagePulseUiBusy) return const SizedBox.shrink();
          final size = _viewSize;
          if (size.width <= 0 || size.height <= 0) {
            return const SizedBox.shrink();
          }

          final (gx, gy) = _villagePulseFocus(p.actor);
          final raw = gridToScreen(gx, gy, size, _camera + _shakeOffset);
          final center = Offset(size.width / 2, size.height / 2);
          final screen = center + (raw - center) * _zoom;
          final markerVisible =
              screen.dx >= -32 &&
              screen.dx <= size.width + 32 &&
              screen.dy >= -32 &&
              screen.dy <= size.height + 64;
          final compact = useCompactGameUi(context);

          return Stack(
            children: [
              if (markerVisible)
                Positioned(
                  left: screen.dx - 22,
                  top: screen.dy - (66 * _zoom).clamp(50.0, 88.0),
                  child: VillagePulseMarker(
                    icon: _villagePulseIcon(p),
                    urgent: p.remainingReal <= 6,
                    onTap: () => setStateHere(() => _villagePulseOpen = true),
                  ),
                ),
              if (_villagePulseOpen)
                Positioned(
                  left: compact ? MobileUi.gutter : 16,
                  right: compact ? MobileUi.gutter : 16,
                  bottom: compact
                      ? MobileUi.bottom(context) + MobileUi.actionH + 12
                      : 106,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: VillagePulseCard(
                      icon: _villagePulseIcon(p),
                      actor: p.actor.name,
                      title: _villagePulseTitle(p),
                      body: _villagePulseBody(p),
                      primaryLabel: _villagePulsePrimaryLabel(p),
                      primarySub: _villagePulsePrimarySub(p),
                      primaryEnabled: _villagePulsePrimaryEnabled(p),
                      secondaryLabel: _villagePulseSecondaryLabel(p),
                      secondarySub: _villagePulseSecondarySub(p),
                      remainingFraction: p.remainingReal / p.totalReal,
                      secondsLeft: p.remainingReal.ceil().clamp(0, 99),
                      onPrimary: () => _chooseVillagePulse(true),
                      onSecondary: () => _chooseVillagePulse(false),
                      onClose: () =>
                          setStateHere(() => _villagePulseOpen = false),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
