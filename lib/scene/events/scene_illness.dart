part of '../main.dart';

/// HASTALIK & KIRILGANLIK — köyün "hayat kırılgan" katmanı (kullanıcı kararı:
/// hastalık + sert kış; politika toggle'ı YOK, hep açık).
///
/// Tasarım sözleşmesi (cozy'yi bozmadan kırılganlık):
///  - **Çoğu iyileşir.** Hastalık öncelikle bir DÜŞKÜNLÜK durumudur (yavaşlar,
///    dinlenir); ölüm yalnız ÇOK YAŞLI / DÜŞÜK MORALLİ için ve KÜÇÜK olasılıkla.
///  - **Önlenebilir.** İyi beslenme (ambar tok) + mabet iyileşmeyi hızlandırır,
///    ölüm riskini kırar. Kötü yönetilen köy daha kırılgan.
///  - **Nadir + tekil.** Aynı anda en fazla birkaç hasta; toplu salgın ayrı bir
///    yol (veba OLAYI, bkz. scene_events — şifacı seçilmezse ölümcül).
///  - **Çocuk hastalıktan ÖLMEZ** (hastalanabilir ama ölüm riski ~0) — cozy.
///  - **Sert kış kırılganlığı burada:** kış + erzak azlığı hem hastalanmayı hem
///    yaşlının ölüm riskini belirgin büyütür (ayrı bir "kış ölümü" sistemi değil,
///    aynı kırılganlığın mevsimsel yüzü).
extension _SceneIllness on _VillageSceneState {
  /// Hastalık başlangıç taraması (sim-sn) — nadir, sakin.
  static const double _kIllnessScan = 5.0;

  /// Köy geneli GÜNLÜK hastalanma olayı tabanı (çarpanlar altında ölçeklenir).
  static const double _kOnsetDailyBase = 0.06;

  /// Aynı anda en çok bu kadar hasta (üstündeyse yeni onset yok — salgın plague'in işi).
  static const int _kMaxConcurrentSick = 2;

  /// Bir hastalık atağının süresi (oyun günü) — bu sürede iyileşir ya da (nadir) yenilir.
  static const double _kSickDaysMin = 1.5;
  static const double _kSickDaysMax = 3.0;

  /// Yaşlı + kötü koşulda GÜNLÜK ölüm riski tabanı (kırılganlık çarpanıyla ölçeklenir).
  static const double _kSickDeathPerDay = 0.06;

  /// Hamamın otomatik bakım döngüsü. Oyuncuya yeni bir aç/kapa işi çıkarmaz:
  /// menzilde hasta/yaralı varsa külhan bir günlük 1 odun alır; yoksa kalan
  /// sıcaklık korunur. [isActive] hem iyileşme sisteminin hem panelin gerçeği.
  void _tickBathhouseCare(double dt) {
    for (final b in _buildings) {
      if (b.type != BuildingType.bathhouse) continue;
      final hasPatient = _villagers.any(
        (v) =>
            !v.isDying &&
            (v.sickDays > 0 || v.injuryDays > 0) &&
            withinBuildingEffect(
              type: b.type,
              col: b.col,
              row: b.row,
              targetX: v.gridX,
              targetY: v.gridY,
            ),
      );
      final step = stepBathhouseFuel(
        secondsLeft: b.serviceTimer,
        dt: dt,
        woodAvailable: _stockpile.wood,
        hasPatient: hasPatient,
      );
      b.serviceTimer = step.secondsLeft;
      b.isActive = step.active;
      if (step.woodUsed > 0) _stockpile.wood -= step.woodUsed;
    }
  }

  bool _coveredByActiveBathhouse(VillagerEntity v) => _buildings.any(
    (b) =>
        b.type == BuildingType.bathhouse &&
        b.isActive &&
        withinBuildingEffect(
          type: b.type,
          col: b.col,
          row: b.row,
          targetX: v.gridX,
          targetY: v.gridY,
        ),
  );

  void _tickIllness(double dt) {
    if (_villagers.isEmpty) return;
    _maybeTriggerFoundingTentIllness();
    final step = dt / kGameDaySeconds;
    final winter = _season.isFrozen;
    final foodShort = _wasStarving;

    // Mabet varsa yakınındaki hasta daha hızlı iyileşir (yaralanma iyileşmesiyle
    // aynı diegetik şifa mantığı).
    final church = _firstBuildingOf(BuildingType.church);
    final cx = church == null ? 0.0 : church.col + church.cols / 2.0;
    final cy = church == null ? 0.0 : church.row + church.rows / 2.0;

    var anySick = false;
    for (final v in _villagers) {
      if (v.sickDays <= 0 || v.isDying) continue;
      anySick = true;

      // ── İyileşme — tok köy + mabet hızlandırır ──────────────────────────────
      double rate = 1.0;
      if (!foodShort) rate += 0.6; // karnı tok köylü toparlanır
      rate += bathhouseRecoveryRate(_coveredByActiveBathhouse(v)) - 1.0;
      if (church != null) {
        final dx = v.gridX - cx, dy = v.gridY - cy;
        if (dx * dx + dy * dy <= 5.0 * 5.0) rate += 1.2; // mabet yanında bakım
      }
      v.sickDays -= step * rate;

      // ── Ölüm riski — YALNIZ yaşlı/zayıf için anlamlı; çoğu iyileşir ─────────
      // Kırılganlık: yaş (yaşlı >> yetişkin >> genç) × düşük moral × erzak azlığı
      // × kış. Sert kış + boş ambar → yaşlı gerçekten kaybedilebilir.
      final ageF = switch (v.lifeStage) {
        LifeStage.elder => 1.0,
        LifeStage.adult => 0.15,
        LifeStage.youth => 0.03,
        LifeStage.child => 0.0, // çocuk hastalıktan ölmez (cozy)
      };
      // Ölüm zarı yalnız HÂLÂ hastayken — iyileşme anını (sickDays≤0) ölüm
      // kapmasın (iyileşen köylü son karede ölmesin).
      if (!v.tutorialIllness && ageF > 0 && v.sickDays > 0) {
        final frail =
            ageF *
            (1.15 - v.morale.clamp(0.0, 1.0)) *
            (foodShort ? 1.8 : 1.0) *
            (winter ? 1.6 : 1.0);
        if (_rng.nextDouble() < _kSickDeathPerDay * frail * step) {
          _illnessDeath(v, winter: winter);
          continue;
        }
      }

      // ── İyileşti ────────────────────────────────────────────────────────────
      if (v.sickDays <= 0) {
        v.sickDays = 0;
        v.tutorialIllness = false;
        // İyileşme = gövde dili (content + hafif mood) + kronik kaydı; baş-üstü
        // ikon YOK (çökük duruş kalkar, köylü dikelir — görünür işaret budur).
        v.feel(NpcEmotion.content, 3.0, moodDelta: 0.06);
        final ctx = _voice(v, seed: _stableSeed('iyileş${v.name}', _dayCount));
        _chronicle(
          Voice.say(const [
            '{ad} hastalığı atlattı, ayağa kalktı.',
            '{ad} iyileşti; köy rahat bir nefes aldı.',
          ], ctx),
          icon: '🌿',
        );
      }
    }

    // ── Yeni hastalık (throttle'lı, nadir) ────────────────────────────────────
    _illnessScan += dt;
    if (_illnessScan >= _kIllnessScan) {
      _illnessScan = 0;
      // Hastalığın SESİ — köyde hasta varken seyrek bir öksürük. Baş üstünde
      // ikon yok, sokakta öksüren biri var: hastalık göze değil kulağa da
      // görünsün. Tarama 5 sn'de bir dönüyor → ~40 sn'de bir duyulur.
      // Zar MOTORUN rastgelesiyle atılır (`playSfxChance`): sahnenin `_rng`'si
      // sim'in deterministik akışıdır, ses ondan sayı tüketirse aynı tohumlu
      // köy başka bir yola girer.
      if (anySick) AudioManager.instance.playSfxChance(Sfx.cough, 0.12);
      _maybeOnsetIllness(winter, foodShort);
    }
  }

  /// Kuruluş dersinin kontrollü hastalığı.
  ///
  /// Bütün kurucular çadıra girdikten, odun, su ve tarla temeli hazır olduktan
  /// sonra sağlıklı bir çadır sakini ateşlenir. Oyuncu bütün kararları verdikten
  /// sonra sırf gün sayacı dönsün diye bekletilmez.
  /// Bu hastalık normal iyileşme döngüsünü kullanır fakat ölüm zarı atmaz.
  /// Aynı anda marangozluk açılır: oyuncuya "ev gerek" deyip kilitli bir ev
  /// kartı göstermek öğretmek değil, yolu kapatmak olurdu.
  void _maybeTriggerFoundingTentIllness() {
    if (_foundingTentIllnessTriggered || _completedQuests.contains('house')) {
      return;
    }
    const foundations = {'firstNight', 'tent', 'lumber', 'well', 'farm'};
    if (!foundations.every(_completedQuests.contains)) return;
    final candidates = _villagers.where((v) {
      final home = v.homeBuilding;
      return !v.isDying &&
          v.lifeStage != LifeStage.child &&
          v.lifeStage != LifeStage.elder &&
          v.sickDays <= 0 &&
          v.injuryDays <= 0 &&
          home is BuildingEntity &&
          home.type == BuildingType.tent;
    }).toList();
    final chosen = candidates.firstOrNull;

    // Marangozluğu önce aç: bütün uygun kurucular zaten hastaysa kontrollü
    // hastalığı üstlerine ikinci kez bindirmeden görev yine ilerleyebilsin.
    final builder =
        _villagers
            .where((v) => !identical(v, chosen) && !v.isDying)
            .firstOrNull ??
        chosen;
    if (builder != null) {
      final currentMastery = builder.mastery[Craft.carpentry] ?? 0.0;
      if (currentMastery < 22.0) builder.mastery[Craft.carpentry] = 22.0;
    }
    _knownCrafts.add(Craft.carpentry);
    _foundingTentIllnessTriggered = true;

    if (chosen == null) {
      _showNotification(
        '🤒 Çadırdaki hastalık kalıcı dam ihtiyacını gösterdi. Köy Evi artık kurulabilir.',
      );
      _chronicle(
        'Çadırdaki hastalık köyü kalıcı dam için marangozluğa yöneltti.',
        icon: '🤒',
        kind: ChronicleKind.crisis,
        milestone: true,
      );
      return;
    }

    chosen.sickDays = 2.0;
    chosen.tutorialIllness = true;
    chosen.feel(NpcEmotion.fear, 3.5, moodDelta: -0.04);
    _sendHome(chosen);
    chosen.chatBubbleIcon = '🤒';
    chosen.chatBubbleTime = 5.0;
    _illnessSeen++;
    AudioManager.instance.playSfx(Sfx.cough);
    _showNotification(
      '🤒 ${chosen.name} çadırda ateşlendi — bez duvar yetmedi. Köy Evi artık kurulabilir.',
    );
    _chronicle(
      '${chosen.name} çadırın neminde hastalandı. Köy, kalıcı dam için marangozluğa başladı.',
      icon: '🤒',
      kind: ChronicleKind.crisis,
      milestone: true,
    );
  }

  /// TECRİT — hastayı kendi damına yollar. Evi yoksa (evsiz/sazlıkta yatan)
  /// hiçbir şey yapmaz: kapısı olmayanı kapıya kapatamazsın.
  ///
  /// Yürüyüşü hüküm başlatır, gerisini normal akış sürdürür: hasta köylü zaten
  /// iş almıyor ([scene_mind] `sickDays > 0` → dinleniyor), o yüzden eve varınca
  /// orada kalır. Ayrı bir "tecritte" durumu YOK — olmayan bir durum eklemek
  /// yerine var olanı doğru yere yönlendirmek yeter.
  void _sendHome(VillagerEntity v) {
    final home = v.homeBuilding as BuildingEntity?;
    if (home == null) return;
    v.activity = VillagerActivity.none;
    v.act = null;
    v.prop = PropKind.none;
    v.goTo(home.col + home.cols / 2.0, home.row + home.rows / 2.0, 6.0);
    v.chatBubbleIcon = '🌿'; // kapıya asılan dal
    v.chatBubbleTime = 4.0;
  }

  /// Nadir onset — köyün genel kırılganlığına göre bir köylü hastalanır.
  void _maybeOnsetIllness(bool winter, bool foodShort) {
    var sickCount = 0;
    for (final v in _villagers) {
      if (v.sickDays > 0) sickCount++;
    }
    if (sickCount >= _kMaxConcurrentSick) return;

    // Aday havuzu + kırılganlık ağırlığı (yaşlı/düşük moralli daha olası).
    final cands = <VillagerEntity>[];
    final weights = <double>[];
    var bathRiskSum = 0.0;
    for (final v in _villagers) {
      if (v.isDying ||
          v.sickDays > 0 ||
          v.injuryDays > 0 ||
          v.laborDays > 0 ||
          v.lifeStage == LifeStage.child) {
        continue;
      }
      final ageW = switch (v.lifeStage) {
        LifeStage.elder => 3.0,
        LifeStage.adult => 1.0,
        LifeStage.youth => 0.5,
        LifeStage.child => 0.0,
      };
      cands.add(v);
      // İHMALİN AĞIRLIĞI — kış tek başına öldürmez, ihmal öldürür
      // (bkz. systems/winter.dart coldNeglect). Sönmüş ocak + soğuk barınak +
      // giysisizlik + boş ambar ÜST ÜSTE binerse o köylü hastalanma
      // kurasında öne çıkar. İki ihmale kadar çarpan 1.0'dır: kışın bir gece
      // ocağın sönmesi kimseyi hasta etmez.
      final neglectW = neglectIllnessMultiplier(_coldNeglectOf(v));
      final bathRisk = bathhouseIllnessRisk(_coveredByActiveBathhouse(v));
      bathRiskSum += bathRisk;
      weights.add(
        ageW * (1.4 - v.morale.clamp(0.0, 1.0)) * neglectW * bathRisk,
      );
    }
    if (cands.isEmpty) return;

    // TECRİT köy çapında, Hamam ise yalnız kapsadığı insanlar kadar
    // hastalık başlangıcını azaltır. Herkes korunuyorsa çarpan 0.45;
    // kimse korunmuyorsa 1.0. Sonraki aday ağırlığı da korunmayanı öne alır.
    final bathRiskMean = bathRiskSum / cands.length;
    final pOnset =
        _kOnsetDailyBase *
        (winter ? 2.0 : 1.0) *
        (foodShort ? 1.6 : 1.0) *
        (_policies.quarantine ? 0.5 : 1.0) *
        bathRiskMean *
        (_kIllnessScan / kGameDaySeconds);
    if (_rng.nextDouble() >= pOnset) return;

    var total = 0.0;
    for (final w in weights) {
      total += w;
    }
    if (total <= 0) return;
    var r = _rng.nextDouble() * total;
    VillagerEntity? chosen;
    for (var i = 0; i < cands.length; i++) {
      r -= weights[i];
      if (r <= 0) {
        chosen = cands[i];
        break;
      }
    }
    chosen ??= cands.last;

    chosen.sickDays =
        _kSickDaysMin + _rng.nextDouble() * (_kSickDaysMax - _kSickDaysMin);
    chosen.feel(NpcEmotion.fear, 2.5, moodDelta: -0.04);
    AudioManager.instance.playSfx(Sfx.cough); // hastalığın ilk işareti
    _illnessSeen++; // köyün hafızası — Tecrit Fermanı'nın kapısı bunu okur
    // TECRİT — hüküm yürürlükteyse hasta olduğu yerde kalmaz, doğrudan kendi
    // damına yürür. Fermanın GÖRÜNÜR yüzü budur: sokakta öksüren kimse yok,
    // bir kapı kapanıyor. (Tecritsiz köyde hasta olduğu yerde dinlenir.)
    if (_policies.quarantine) _sendHome(chosen);
    final ctx = _voice(
      chosen,
      seed: _stableSeed('hasta${chosen.name}', _dayCount),
    );
    _showNotification(
      Voice.say(
        _policies.quarantine
            ? const [
                '🌿 {ad} ateşlendi; kapısına dal asıldı. Kimse girmiyor.',
                '🌿 {ad} hastalandı — tecride çekildi, çanağı eşiğe bırakılıyor.',
              ]
            : const [
                '🤒 {ad} hastalandı, yatağa düştü. Köy başında.',
                '🤒 {ad} ateşlendi — birkaç gün dinlenmesi gerek.',
              ],
        ctx,
      ),
    );
    _chronicle(
      Voice.say(const [
        '{ad} hastalandı.',
        '{ad} yatağa düştü; köy iyileşmesini bekliyor.',
      ], ctx),
      icon: '🤒',
      kind: ChronicleKind.crisis,
    );
  }

  /// VEBA TOLÜ — toplu salgının bedeli (scene_events plague kararı çağırır).
  /// [healer] true ise (şifacı çağrıldı) salgın erken kırılır: ÖLÜM YOK, yalnız
  /// birkaç kişi hafif hasta olur. false ise (kendi başına atlat) salgın köyün
  /// EN KIRILGANLARINI (yaşlı + düşük moralli) alır + birkaçını ağır hasta eder
  /// (bazıları atlatır, bazıları atlatamaz — hastalık döngüsü karar verir).
  void _plagueToll({required bool healer}) {
    final pool =
        _villagers
            .where(
              (v) =>
                  !v.isDying &&
                  !v.tutorialIllness &&
                  v.lifeStage != LifeStage.child,
            )
            .toList()
          ..sort((a, b) => _plagueFrailty(b).compareTo(_plagueFrailty(a)));
    if (pool.isEmpty) return;

    if (healer) {
      // Erken kırıldı — en kırılgan 1 kişi kısa süre hasta düşer, ölüm yok.
      if (pool.first.sickDays <= 0) {
        pool.first.sickDays = _kSickDaysMin;
        pool.first.feel(NpcEmotion.fear, 2.5, moodDelta: -0.03);
      }
      return;
    }

    // Şifacı yok — salgın en zayıfları doğrudan alır (nüfusa göre 1-2), sonra
    // birkaçını ağır hasta bırakır (belirsizlik: iyileşme/ölüm hastalık tickinde).
    //
    // TECRİT FERMANI — salgın bir can az alır. Hükmün en pahalı anda ödediği
    // karşılık budur: tecrit gündelik hayatı kısan bir yüktür ama vebada
    // gerçekten bir mezar eksiltir.
    var claim = pool.length >= 6 ? 2 : (pool.length >= 3 ? 1 : 0);
    if (_policies.quarantine && claim > 0) claim--;
    for (var i = 0; i < claim; i++) {
      _illnessDeath(pool[i], winter: _season.isFrozen);
    }
    for (var i = claim; i < pool.length && i < claim + 3; i++) {
      if (pool[i].sickDays <= 0) {
        pool[i].sickDays = _kSickDaysMax; // ağır
        pool[i].feel(NpcEmotion.fear, 3.0, moodDelta: -0.06);
      }
    }
    _feelVillage(NpcEmotion.grief, 12, -0.05); // köy yasa büründü
  }

  /// Veba hedef sıralaması için kırılganlık — yaşlı + düşük moral öne.
  double _plagueFrailty(VillagerEntity v) {
    final ageW = switch (v.lifeStage) {
      LifeStage.elder => 3.0,
      LifeStage.adult => 1.0,
      LifeStage.youth => 0.5,
      LifeStage.child => 0.0,
    };
    return ageW * (1.3 - v.morale.clamp(0.0, 1.0));
  }

  /// Hastalıktan/kıştan ölüm — doğal ölümle aynı temiz çıkış (aile bağı kopar,
  /// çöküş animasyonu + cenaze). Metin mevsime göre renklenir.
  void _illnessDeath(VillagerEntity v, {required bool winter}) {
    for (final p in v.parents) {
      p.children.remove(v);
    }
    for (final c in v.children) {
      c.parents.remove(v);
    }
    final ctx = _voice(v, seed: _stableSeed('vefat${v.name}', _dayCount));
    _chronicle(
      Voice.say(
        winter
            ? const [
                '{ad} sert kışa dayanamadı, hastalığa yenildi.',
                '{ad} kışın ortasında göçtü; ocağı erken söndü.',
              ]
            : const [
                '{ad} hastalıktan kalkamadı, aramızdan ayrıldı.',
                '{ad} hastalığa yenildi; köy yasa büründü.',
              ],
        ctx,
      ),
      icon: '⚰️',
      milestone: true,
      kind: ChronicleKind.crisis,
    );
    _markDeathHouse(v);
    v.startDying(funeral: true);
  }
}
