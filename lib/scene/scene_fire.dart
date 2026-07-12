part of '../main.dart';

/// Ateş yakıt sistemi — köyün ateşi artık beslenmek ister. Yakıt zamanla
/// tükenir; bir köylü (ateşçi) stoktan odun alıp ateşe taşır. Odun biterse
/// ateşçi çaresizdir, yakıt 0'a iner ve ATEŞ SÖNER → köy karanlıkta/soğukta
/// kalır: köy çapı huzursuzluk (zümre morali ↓), bir dilekçe ve görsel sönüş.
///
/// Cozy/no-fail: sönmek köyü öldürmez; odun gelince ateşçi yeniden yakar.
/// Görsel telgraf: yakıt azaldıkça alev + ışık kısılır (sönmeden önce belli olur).
extension _SceneFire on _VillageSceneState {
  /// Beslenmezse ateşin tamamen sönmesi (oyun günü). Dolu → boş süresi.
  static const double _kFireBurnDays = 2.0;
  /// Bu seviyenin altına inince ateşçi odun taşımaya çağrılır.
  static const double _kFireRefuelThreshold = 0.55;
  /// Bir odunun kattığı yakıt — dolu ateş ~3 odun (hafif odun vergisi).
  static const double _kFuelPerLog = 0.35;
  /// Ateşçi atama taraması (sn).
  static const double _kFirekeeperScanSec = 1.5;
  /// Odun stoğu bu seviyenin ALTINA inince "odun azalıyor" dilekçesi (erken
  /// uyarı — ateş sönmeden önce oyuncu önlem alabilsin).
  static const int _kWoodLowWarn = 5;
  /// Uyarı histerezi: stok bu seviyeye çıkınca yeniden "sağlıklı" sayılır
  /// (bir sonraki düşüşte yine uyarı çıkabilir).
  static const int _kWoodHealthy = 12;

  /// Ateş şu an yanıyor mu — kurulmuş + yakıtı var.
  bool get _fireBurning =>
      _hasFire && (_firepitBuilding?.fireFuel ?? 0) > 0.001;

  void _tickFire(double dt) {
    final fire = _firepitBuilding;
    if (!_hasFire || fire == null) return;

    // 1) Yakıt tükenişi.
    if (fire.fireFuel > 0) {
      fire.fireFuel =
          (fire.fireFuel - dt / (_kFireBurnDays * kGameDaySeconds))
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

  /// Yakıt eşiğin altında, stokta odun var ve atanmış ateşçi yoksa — en yakın
  /// uygun yetişkini ateşe odun taşımaya yollar.
  void _maybeDispatchFirekeeper(BuildingEntity fire) {
    if (_firekeeper != null) return;
    if (fire.fireFuel >= _kFireRefuelThreshold) return;
    if (_stockpile.wood <= 0) return; // odun yok → ateşçi çaresiz

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
    _firekeeperLoaded = true; // soyut: stoktan bir kütük omuzladı
    _firekeeperGiveUp = _time + 30.0; // ulaşamazsa 30 sn sonra vazgeç
    // Ateşin hemen güneyine yürü (bina tile'ı dolu — kenara konumlan).
    best.goTo(fx, fy + 1.1, 1.5);
    best.chatBubbleIcon = '🪵'; // diegetik: odun taşıyor
    best.chatBubbleTime = 4.0;
  }

  /// Atanmış ateşçiyi izler: ateşe varınca odunu bırakır (stok−1, yakıt+),
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
      _firekeeperLoaded = false;
      return;
    }

    final fx = fire.col + fire.cols / 2.0;
    final fy = fire.row + fire.rows / 2.0;
    final dx = v.gridX - fx, dy = v.gridY - fy;
    if (dx * dx + dy * dy > 2.4 * 2.4) return; // henüz varmadı

    // Vardı — odunu ateşe at.
    if (_firekeeperLoaded && _stockpile.wood > 0) {
      _stockpile.wood -= 1;
      fire.fireFuel = (fire.fireFuel + _kFuelPerLog).clamp(0.0, 1.0);
      v.lookToward(fx, fy);
      v.feel(NpcEmotion.content, 1.6); // ocağı besledi
    }
    _firekeeper = null;
    _firekeeperLoaded = false;
  }

  /// Ateş söndü — köy karanlıkta/soğukta. Köy çapı huzursuzluk + dilekçe.
  void _onFireDied() {
    _showNotification('🔥 Ateş söndü! Köy karanlıkta, soğukta kaldı — odun lazım.');
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
    _showNotification('🔥 Ateş yeniden canlandı — köy ısındı.');
    _feelVillage(NpcEmotion.joy, 6, 0.08);
    _nudgeHousesByEstate(Estate.hearth, moodDelta: 0.06);
  }
}
