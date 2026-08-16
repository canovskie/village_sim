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

  void _tickIllness(double dt) {
    if (_villagers.isEmpty) return;
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
      if (ageF > 0 && v.sickDays > 0) {
        final frail = ageF *
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
        // İyileşme = gövde dili (content + hafif mood) + kronik kaydı; baş-üstü
        // ikon YOK (çökük duruş kalkar, köylü dikelir — görünür işaret budur).
        v.feel(NpcEmotion.content, 3.0, moodDelta: 0.06);
        final ctx = _voice(v, seed: _stableSeed('iyileş${v.name}', _dayCount));
        _chronicle(
            Voice.say(const [
              '{ad} hastalığı atlattı, ayağa kalktı.',
              '{ad} iyileşti; köy rahat bir nefes aldı.',
            ], ctx),
            icon: '🌿');
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

    // TECRİT FERMANI — hasta kendi damına kapandığında bulaşma yarıya iner.
    // Bedeli fermanın kendisinde değil, dünyada: tecritteki el tarlada eksilir
    // (aşağıda köylü doğrudan evine yollanıyor) ve ocak tarafı küser.
    final pOnset = _kOnsetDailyBase *
        (winter ? 2.0 : 1.0) *
        (foodShort ? 1.6 : 1.0) *
        (_policies.quarantine ? 0.5 : 1.0) *
        (_kIllnessScan / kGameDaySeconds);
    if (_rng.nextDouble() >= pOnset) return;

    // Aday havuzu + kırılganlık ağırlığı (yaşlı/düşük moralli daha olası).
    final cands = <VillagerEntity>[];
    final weights = <double>[];
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
      weights.add(ageW * (1.4 - v.morale.clamp(0.0, 1.0)) * neglectW);
    }
    if (cands.isEmpty) return;

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
    final ctx = _voice(chosen, seed: _stableSeed('hasta${chosen.name}', _dayCount));
    _showNotification(Voice.say(
        _policies.quarantine
            ? const [
                '🌿 {ad} ateşlendi; kapısına dal asıldı. Kimse girmiyor.',
                '🌿 {ad} hastalandı — tecride çekildi, çanağı eşiğe bırakılıyor.',
              ]
            : const [
                '🤒 {ad} hastalandı, yatağa düştü. Köy başında.',
                '🤒 {ad} ateşlendi — birkaç gün dinlenmesi gerek.',
              ],
        ctx));
    _chronicle(
        Voice.say(const [
          '{ad} hastalandı.',
          '{ad} yatağa düştü; köy iyileşmesini bekliyor.',
        ], ctx),
        icon: '🤒', kind: ChronicleKind.crisis);
  }

  /// VEBA TOLÜ — toplu salgının bedeli (scene_events plague kararı çağırır).
  /// [healer] true ise (şifacı çağrıldı) salgın erken kırılır: ÖLÜM YOK, yalnız
  /// birkaç kişi hafif hasta olur. false ise (kendi başına atlat) salgın köyün
  /// EN KIRILGANLARINI (yaşlı + düşük moralli) alır + birkaçını ağır hasta eder
  /// (bazıları atlatır, bazıları atlatamaz — hastalık döngüsü karar verir).
  void _plagueToll({required bool healer}) {
    final pool = _villagers
        .where((v) => !v.isDying && v.lifeStage != LifeStage.child)
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
            ctx),
        icon: '⚰️',
        milestone: true, kind: ChronicleKind.crisis);
    _markDeathHouse(v);
    v.startDying(funeral: true);
  }
}
