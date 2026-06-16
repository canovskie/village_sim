part of '../main.dart';

/// Sürekli reaktif "canlı köy" katmanı — olaylar ve eylemler köyde GÖRÜNÜR,
/// **gövde diliyle** (postür + dönüp bakma) yankı bulur.
///
/// KISIT (bkz. feedback_event_animation): baş üstü emoji / floating ikon YOK;
/// sayısal refleksiyon YOK. Tüm ifade [VillagerEntity.feel] → game_painter
/// postür kanalından geçer (sevinç sıçrar, yas çöker, korku titrer...).
extension _SceneReactions on _VillageSceneState {
  /// Uyanık/dışarıdaki tüm köylülere ortak bir duygu (gövde dili) yaşatır —
  /// bir olayın köy çapında kişisel yankısı. [feel]'in özünü kullanır.
  void _feelVillage(NpcEmotion e, double dur, double moodDelta) {
    for (final v in _villagers) {
      if (v.isSleeping || v.isInsideBuilding || v.isDying) continue;
      v.feel(e, dur, moodDelta: moodDelta);
    }
  }

  /// Bir noktada olan şeye YEREL tepki dalgası: yarıçaptaki uyanık köylüler o
  /// noktaya **dönüp bakar** (lookToward) + gövde refleksi (feel). Mesafeyle
  /// yumuşar — yakın olan daha güçlü/uzun tepki verir.
  void _reactNearby(double x, double y, double radius, NpcEmotion e, double dur,
      {double moodDelta = 0}) {
    final r2 = radius * radius;
    for (final v in _villagers) {
      if (v.isSleeping || v.isInsideBuilding || v.isDying) continue;
      final dx = v.gridX - x, dy = v.gridY - y;
      final d2 = dx * dx + dy * dy;
      if (d2 > r2) continue;
      final k = 1.0 - (d2 / r2); // 0..1 yakınlık
      v.lookToward(x, y);
      v.feel(e, dur * (0.6 + 0.4 * k), moodDelta: moodDelta * k);
    }
  }

  /// Sürekli baseline canlılık — ara sıra rastgele uyanık/sakin bir köylüye
  /// kısa, düşük yoğunluklu gövde refleksi (huzur/merak). İkon yok, sadece
  /// postür → köy hiçbir an tamamen durağan kalmaz.
  void _spontaneousLife(double dt) {
    _spontaneousTimer -= dt;
    if (_spontaneousTimer > 0) return;
    _spontaneousTimer = kSpontaneousLifeMin +
        _rng.nextDouble() * (kSpontaneousLifeMax - kSpontaneousLifeMin);
    if (_villagers.length < 2) return;
    // Birkaç deneme: uyanık, dışarıda, sakin (idle, aktivitesiz) biri.
    for (int i = 0; i < 5; i++) {
      final v = _villagers[_rng.nextInt(_villagers.length)];
      if (v.isSleeping || v.isInsideBuilding || v.isDying || v.isCarrying) {
        continue;
      }
      if (v.activity != VillagerActivity.none || v.sitClaimed) continue;
      final e = _rng.nextBool() ? NpcEmotion.content : NpcEmotion.wonder;
      v.feel(e, 1.6 + _rng.nextDouble() * 1.2);
      return;
    }
  }

  /// Hava durumu geçişi → gerçek davranış. Yağmur başlayınca dış mekândaki
  /// köylüler irkilir (fear-lite) ve sığınağa/eve yönelir (errand'i kısa kes).
  /// Açınca rahatlama dalgası. Bir kez tetiklenir (_lastRainy ile).
  void _tickWeatherReaction(double dt) {
    final rainy = _cycle.rainIntensity > 0.30;
    if (rainy == _lastRainy) return;
    _lastRainy = rainy;
    if (rainy) {
      _feelVillage(NpcEmotion.fear, 2.2, 0);
      // Sığınağa koş: dışarıdaki gezginleri eve yönelt (varsa), yoksa errand iste.
      for (final v in _villagers) {
        if (v.isSleeping || v.isInsideBuilding || v.isDying) continue;
        if (v.isCarrying || v.sitClaimed) continue;
        if (v.activity != VillagerActivity.none) continue; // sohbeti/dansı bölme
        if (v.homeBuilding case final h?) {
          final hb = h as BuildingEntity;
          final cx = hb.col + hb.cols / 2.0, cy = hb.row + hb.rows / 2.0;
          final spot = _freeSpotNear(cx, cy, 1.6);
          if (spot != null) v.goTo(spot.$1, spot.$2, 4 + _rng.nextDouble() * 4);
        }
      }
    } else {
      _feelVillage(NpcEmotion.content, 3.0, 0);
    }
  }
}
