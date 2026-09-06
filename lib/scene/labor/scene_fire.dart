part of '../main.dart';

/// Ateş yakıt sistemi — köyün ateşi artık beslenmek ister. Yakıt zamanla
/// tükenir; bir köylü (ateşçi) stoktan ODUN ya da KÖMÜR alıp ateşe taşır.
/// İkisi de biterse ateşçi çaresizdir, yakıt 0'a iner ve ATEŞ SÖNER → köy
/// karanlıkta/soğukta kalır: köy çapı huzursuzluk (zümre morali ↓), bir
/// dilekçe ve görsel sönüş.
///
/// KÖMÜR — ocağın uzun yanan yakıtı. Bir parça odunun ~2.3 katı yakıt verir
/// ([_kFuelPerCoal]), ve kışın ocak çok daha hızlı yediği için
/// ([_kFireBurnDaysWinter]) asıl karşılığını kışın verir. Kömürün pazarda
/// satılabilir olması bunu gerçek bir tercihe çevirir: sonbaharda madenciyi
/// kömüre koşup kışa hazırlanmak mı, yoksa çıkanı satıp altına dönmek mi.
///
/// Cozy/no-fail: sönmek köyü öldürmez; yakıt gelince ateşçi yeniden yakar.
/// Görsel telgraf: yakıt azaldıkça alev + ışık kısılır (sönmeden önce belli olur).
extension _SceneFire on _VillageSceneState {
  /// Beslenmezse ateşin tamamen sönmesi (oyun günü). Dolu → boş süresi.
  static const double _kFireBurnDays = 2.0;

  /// Kışın ocak daha çok yer — soğuk yakıtı hızlı tüketir. Kış boyu (4 gün)
  /// kabaca 9 odun ya da 4 kömür eder: hazırlık yapmayı gerektirir, ama
  /// hazırlıksız köyü de öldürmez (sönmek geri dönülebilir).
  static const double _kFireBurnDaysWinter = 1.25;
  /// Bu seviyenin altına inince ateşçi odun taşımaya çağrılır.
  static const double _kFireRefuelThreshold = 0.55;

  /// Ocak Nöbeti Fermanı yürürlükteyken eşik — ateş yarıya inmeden beslenir.
  static const double _kFireWatchThreshold = 0.85;
  /// Bir odunun kattığı yakıt — dolu ateş ~3 odun (hafif odun vergisi).
  static const double _kFuelPerLog = 0.35;

  /// Bir kömürün kattığı yakıt — odunun ~2.3 katı; tek parça ateşi neredeyse
  /// doldurur. Kömür pazarda odundan pahalı (bkz. kMarketSellRates), o yüzden
  /// ocağa atmanın bedeli var; karşılığı da taşıma trafiğinin yarıya inmesi.
  static const double _kFuelPerCoal = 0.80;
  /// Ateşçi atama taraması (sn).
  static const double _kFirekeeperScanSec = 1.5;
  /// Odun stoğu bu seviyenin ALTINA inince "odun azalıyor" dilekçesi (erken
  /// uyarı — ateş sönmeden önce oyuncu önlem alabilsin).
  static const int _kWoodLowWarn = 5;
  /// Uyarı histerezi: stok bu seviyeye çıkınca yeniden "sağlıklı" sayılır
  /// (bir sonraki düşüşte yine uyarı çıkabilir).
  static const int _kWoodHealthy = 12;

  // ── Ocağın sesi ([[lib/text/voice.dart]]) ─────────────────────────────────

  static const _kFireDiedPool = [
    '🔥 Son kor da karardı. Köy soğukta kaldı, ocağa odun gerek.',
    '🔥 Ateş söndü. Küller soğumadan karanlık çöktü; odun lazım.',
    '🔥 Ocak kendi kendine söndü. Kimse elini ısıtacak yer bulamıyor.',
  ];
  /// Kışın ocak hem hızlı yer hem kömürle beslenir — sönerse sesi de bunu der.
  static const _kFireDiedWinterPool = [
    '🔥 Kışın ortasında ocak sustu. Odun ya da kömür, ne bulunursa gerek.',
    '🔥 Son kor kar altında karardı. Ambarda ne odun kaldı ne kömür.',
    '🔥 Ateş kışa dayanamadı. Köy soğukta; ocağın yakacağı tükendi.',
  ];
  static const _kFireRelitPool = [
    '🔥 Odun kütürdedi, alev yükseldi. Köy ısındı.',
    '🔥 Ateş yeniden tutuştu. İlk kıvılcımda çocuklar bağırdı.',
    '🔥 Ocak yeniden yanıyor.',
  ];

  /// Ateş şu an yanıyor mu — kurulmuş + yakıtı var.
  bool get _fireBurning =>
      _hasFire && (_firepitBuilding?.fireFuel ?? 0) > 0.001;

  /// Ocağın bu mevsimdeki tükenme süresi (oyun günü). Kışın kısalır.
  double get _fireBurnDaysNow =>
      _season == Season.winter ? _kFireBurnDaysWinter : _kFireBurnDays;

  /// Ateşçinin bu sefer omuzlayacağı yakıt. Kışın KÖMÜR tercih edilir (uzun
  /// yanar → ocağa daha az gidiş geliş, hızlanan tüketimi karşılar), diğer
  /// mevsimlerde odun (kömür satılığa kalsın). Tercih edilen stokta yoksa
  /// diğerine düşülür; ikisi de yoksa null → ateşçi çağrılmaz, ocak söner.
  ResourceKind? _pickFireFuel() {
    final preferCoal = _season == Season.winter;
    final first  = preferCoal ? ResourceKind.coal : ResourceKind.wood;
    final second = preferCoal ? ResourceKind.wood : ResourceKind.coal;
    if (_stockpile.get(first) > 0) return first;
    if (_stockpile.get(second) > 0) return second;
    return null;
  }

  void _tickFire(double dt) {
    final fire = _firepitBuilding;
    if (!_hasFire || fire == null) return;

    // 1) Yakıt tükenişi.
    if (fire.fireFuel > 0) {
      fire.fireFuel =
          (fire.fireFuel - dt / (_fireBurnDaysNow * kGameDaySeconds))
              .clamp(0.0, 1.0);
    }

    // 2) Sönme / yeniden yanma geçişleri (kenar tetikli).
    final burning = fire.fireFuel > 0.001;
    if (_fireWasBurning && !burning) {
      _onFireDied();
    } else if (!_fireWasBurning && burning) {
      _onFireRelit();
    }
    _fireWasBurning = burning;

    // 3) Ateşçi akışı — düşük yakıt + odun varsa biri taşısın.
    _firekeeperScan += dt;
    if (_firekeeperScan >= _kFirekeeperScanSec) {
      _firekeeperScan = 0;
      _maybeDispatchFirekeeper(fire);
    }
    _advanceFirekeeper(fire);

    // 4) Odun azalma erken uyarısı — ateş sönmeden önce dilekçe.
    _tickWoodWarning();
  }

  /// Odun stoğu kritiğe inince (ama henüz bitmeden) oduncuların sesiyle bir
  /// uyarı dilekçesi sunar. Histerez: stok önce sağlıklı seviyeye çıkmalı,
  /// sonra düşüşte tek sefer tetiklenir (spam yok). Oyun başında stok zaten
  /// düşükken yanlış uyarı çıkmaz (önce dolması beklenir).
  void _tickWoodWarning() {
    final wood = _stockpile.wood;
    if (wood >= _kWoodHealthy) {
      _woodHealthy = true;
      return;
    }
    if (_woodHealthy && wood < _kWoodLowWarn) {
      _woodHealthy = false;
      if (_pendingPetition == null) {
        final p = PetitionSystem.byId('woodLow');
        if (p != null) _presentPetition(p);
      }
    }
  }

  /// Yakıt eşiğin altında, stokta yakıt var ve atanmış ateşçi yoksa — en yakın
  /// uygun yetişkini ateşe yakıt taşımaya yollar.
  void _maybeDispatchFirekeeper(BuildingEntity fire) {
    if (_firekeeper != null) return;
    // OCAK NÖBETİ FERMANI — ateş küllenmeyi beklemez, çok daha erken beslenir.
    // Kazanç: ocak pratikte hiç sönmez (moral düşüşü + fireDied dilekçesi
    // ortadan kalkar). Bedel açık ve kendiliğinden: eşik yükseldikçe kütük
    // sıklaşır, odun ambarı belirgin hızlı erir. Fermanın murmur'ı tam bunu der.
    final threshold =
        _policies.hearthWatch ? _kFireWatchThreshold : _kFireRefuelThreshold;
    if (fire.fireFuel >= threshold) return;
    final fuel = _pickFireFuel();
    if (fuel == null) return; // ne odun ne kömür → ateşçi çaresiz

    final fx = fire.col + fire.cols / 2.0;
    final fy = fire.row + fire.rows / 2.0;
    VillagerEntity? best;
    double bestD = 1e9;
    for (final v in _villagers) {
      if (v.isInsideBuilding ||
          v.isSleeping ||
          v.isDying ||
          v.isCarrying ||
          v.sitClaimed ||
          !v.hasProfession ||
          v.activity != VillagerActivity.none) {
        continue;
      }
      final dx = v.gridX - fx, dy = v.gridY - fy;
      final d = dx * dx + dy * dy;
      if (d < bestD) {
        bestD = d;
        best = v;
      }
    }
    if (best == null) return;

    _firekeeper = best;
    _firekeeperFuel = fuel; // soyut: stoktan bir kütük/parça omuzladı
    _firekeeperGiveUp = _time + 30.0; // ulaşamazsa 30 sn sonra vazgeç
    // Ateşin hemen güneyine yürü (bina tile'ı dolu — kenara konumlan).
    best.goTo(fx, fy + 1.1, 1.5);
    best.chatBubbleIcon = fuel.icon; // diegetik: ne taşıdığı görünsün
    best.chatBubbleTime = 4.0;
  }

  /// Atanmış ateşçiyi izler: ateşe varınca yakıtı bırakır (stok−1, yakıt+),
  /// yolda işlevsiz kalırsa (uyku/ölüm/taşıma) görevi serbest bırakır.
  void _advanceFirekeeper(BuildingEntity fire) {
    final v = _firekeeper;
    if (v == null) return;

    // Görevden düştü mü (işlevsiz kaldı ya da ateşe ulaşamadı)?
    if (v.isSleeping ||
        v.isInsideBuilding ||
        v.isDying ||
        v.isCarrying ||
        _time > _firekeeperGiveUp) {
      _firekeeper = null;
      _firekeeperFuel = null;
      return;
    }

    final fx = fire.col + fire.cols / 2.0;
    final fy = fire.row + fire.rows / 2.0;
    final dx = v.gridX - fx, dy = v.gridY - fy;
    if (dx * dx + dy * dy > 2.4 * 2.4) return; // henüz varmadı

    // Vardı — yakıtı ateşe at. Yolda stok tükenmiş olabilir (başka tüketici
    // ya da satış): o durumda eli boş döner, yakıt eklenmez.
    final fuel = _firekeeperFuel;
    if (fuel != null && _stockpile.get(fuel) > 0) {
      _stockpile.add(fuel, -1);
      final gain =
          fuel == ResourceKind.coal ? _kFuelPerCoal : _kFuelPerLog;
      fire.fireFuel = (fire.fireFuel + gain).clamp(0.0, 1.0);
      v.lookToward(fx, fy);
      v.feel(NpcEmotion.content, 1.6); // ocağı besledi
    }
    _firekeeper = null;
    _firekeeperFuel = null;
  }

  /// Ateş söndü — köy karanlıkta/soğukta. Köy çapı huzursuzluk + dilekçe.
  void _onFireDied() {
    _showNotification(Voice.say(
        _season == Season.winter ? _kFireDiedWinterPool : _kFireDiedPool,
        _voice(null, seed: _stableSeed('ateşsöndü', _dayCount))));
    _feelVillage(NpcEmotion.fear, 8, -0.12);
    // Ocak (yuva) en çok yaralanır; inananlar (ayin ateşi) onu izler.
    _nudgeHousesByEstate(Estate.hearth, moodDelta: -0.12);
    _nudgeHousesByEstate(Estate.faithful, moodDelta: -0.08);
    _nudgeHousesByEstate(Estate.laborers, moodDelta: -0.05);
    _nudgeHousesByEstate(Estate.artisans, moodDelta: -0.05);
    pushPolicyMorale(-0.06, 4.0);

    // Dilekçe: köy odun seferberliği bekliyor (boşsa anında sun).
    if (_pendingPetition == null) {
      final p = PetitionSystem.byId('fireDied');
      if (p != null) _presentPetition(p);
    }
  }

  /// Ateş yeniden canlandı — köy ısındı.
  void _onFireRelit() {
    _showNotification(Voice.say(
        _kFireRelitPool, _voice(null, seed: _stableSeed('ateşyandı', _dayCount))));
    _feelVillage(NpcEmotion.joy, 6, 0.08);
    _nudgeHousesByEstate(Estate.hearth, moodDelta: 0.06);
  }
}
