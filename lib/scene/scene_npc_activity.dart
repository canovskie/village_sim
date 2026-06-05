part of '../main.dart';

/// Sosyal canlılık: chat/music/dance — bağlama duyarlı, dağıtık per-NPC
/// değerlendirme. Pazar/taverna/ateş/akşam/yağmur çarpanları kullanır.
/// part of main.dart — State'in tüm private alanlarına erişim.
extension _SceneNpcActivity on _VillageSceneState {
  void _tryStartChats() {
    if (_villagers.length < 2) return;
    final rainy = _cycle.rainIntensity > 0.30;
    final t = _cycle.timeOfDay;
    final eveningBoost = (t > 0.62 && t < 0.88) ? 1.4 : 1.0;
    final night = _cycle.dayLight < 0.45;

    final markets  = _spotsOf(BuildingType.market);
    final taverns  = _spotsOf(BuildingType.tavern);
    final firepits = _spotsOf(BuildingType.firepit);

    for (final v in _villagers) {
      if (v.isInsideBuilding || v.isSleeping || !v.hasProfession) continue;
      if (v.activity != VillagerActivity.none) continue;
      if (v.socialCooldown > 0) continue;
      if (v.isCarrying || v.isWalking) {
        if (_rng.nextDouble() > 0.20) continue;
      }

      double ctx = 1.0;
      final atMarket  = _nearAny(v.gridX, v.gridY, markets,  3.0);
      final atTavern  = _nearAny(v.gridX, v.gridY, taverns,  3.5);
      final atFire    = _nearAny(v.gridX, v.gridY, firepits, 4.0);
      if (atMarket) ctx *= 3.0;
      if (atTavern) ctx *= 3.5;
      if (atFire && night) ctx *= 2.5;
      ctx *= eveningBoost;
      if (rainy) ctx *= 0.35;

      final base = 0.006 * ctx;
      if (_rng.nextDouble() > base) continue;

      final r = _rng.nextDouble();
      bool started = false;
      if (!rainy && (atTavern || (atFire && night)) && r < 0.25) {
        started = _tryStartDanceFor(v);
      } else if (!rainy && (atTavern || (atFire && night)) && r < 0.50) {
        started = _tryStartMusicFor(v);
      } else {
        started = _tryStartChatFor(v);
      }
      if (started) {
        v.socialCooldown = 60 + _rng.nextDouble() * 120;
      }
    }
  }

  bool _tryStartChatFor(VillagerEntity v) {
    final partner = _findNearbyIdle(v);
    if (partner == null) return false;
    final icon = _VillageSceneState._kChatIcons[
        _rng.nextInt(_VillageSceneState._kChatIcons.length)];
    final dur  = 3.5 + _rng.nextDouble() * 2.0;
    v.activity = VillagerActivity.chat;
    v.chatBubbleIcon = icon;
    v.chatBubbleTime = dur;
    partner.activity = VillagerActivity.chat;
    partner.chatBubbleIcon = icon;
    partner.chatBubbleTime = dur;
    partner.socialCooldown = 60 + _rng.nextDouble() * 120;
    return true;
  }

  bool _tryStartMusicFor(VillagerEntity v) {
    v.activity = VillagerActivity.music;
    v.chatBubbleIcon = '🎸';
    v.chatBubbleTime = 9 + _rng.nextDouble() * 5;
    return true;
  }

  bool _tryStartDanceFor(VillagerEntity v) {
    final partner = _findNearbyIdle(v);
    if (partner == null) return false;
    final dur = 7 + _rng.nextDouble() * 4;
    v.activity = VillagerActivity.dance;
    v.chatBubbleIcon = '💃';
    v.chatBubbleTime = dur;
    partner.activity = VillagerActivity.dance;
    partner.chatBubbleIcon = '💃';
    partner.chatBubbleTime = dur;
    partner.socialCooldown = 60 + _rng.nextDouble() * 120;
    return true;
  }

  /// Dev panel: rastgele uygun NPC'de müzik başlat.
  bool _devStartMusic() {
    final adults = _villagers.where(
        (v) => !v.isInsideBuilding && !v.isSleeping && v.hasProfession &&
               v.activity == VillagerActivity.none).toList()
      ..shuffle(_rng);
    if (adults.isEmpty) return false;
    _tryStartMusicFor(adults.first);
    adults.first.socialCooldown = 60 + _rng.nextDouble() * 60;
    return true;
  }

  /// Dev panel: rastgele uygun çiftte dans başlat.
  bool _devStartDance() {
    final adults = _villagers.where(
        (v) => !v.isInsideBuilding && !v.isSleeping && v.hasProfession &&
               v.activity == VillagerActivity.none).toList()
      ..shuffle(_rng);
    for (final v in adults) {
      if (_tryStartDanceFor(v)) {
        v.socialCooldown = 60 + _rng.nextDouble() * 60;
        return true;
      }
    }
    return false;
  }

  /// Dev panel: rastgele uygun çiftte sohbet başlat.
  bool _devStartChat() {
    final adults = _villagers.where(
        (v) => !v.isInsideBuilding && !v.isSleeping && v.hasProfession &&
               v.activity == VillagerActivity.none).toList()
      ..shuffle(_rng);
    for (final v in adults) {
      if (_tryStartChatFor(v)) {
        v.socialCooldown = 60 + _rng.nextDouble() * 60;
        return true;
      }
    }
    return false;
  }

  /// Tüm aktif aktiviteleri ve cooldownları sıfırla.
  void _devClearActivities() {
    for (final v in _villagers) {
      v.activity = VillagerActivity.none;
      v.chatBubbleIcon = '';
      v.chatBubbleTime = 0;
      v.socialCooldown = 0;
    }
  }

  /// [v]'ye yakın (≤2.5 tile), boş, yetişkin başka bir NPC.
  VillagerEntity? _findNearbyIdle(VillagerEntity v) {
    for (final o in _villagers) {
      if (identical(o, v)) continue;
      if (o.isInsideBuilding || o.isSleeping || !o.hasProfession) continue;
      if (o.activity != VillagerActivity.none) continue;
      if (o.socialCooldown > 0) continue;
      final dx = v.gridX - o.gridX;
      final dy = v.gridY - o.gridY;
      if (dx * dx + dy * dy <= 2.5 * 2.5) return o;
    }
    return null;
  }

  List<(double, double)> _spotsOf(BuildingType t) => _buildings
      .where((b) => b.type == t)
      .map((b) => (b.col + b.cols / 2.0, b.row + b.rows / 2.0))
      .toList();

  bool _nearAny(double x, double y, List<(double, double)> pts, double r) {
    final r2 = r * r;
    for (final p in pts) {
      final dx = x - p.$1;
      final dy = y - p.$2;
      if (dx * dx + dy * dy <= r2) return true;
    }
    return false;
  }
}
