part of '../main.dart';

/// Ateş başı toplanma — akşam saatlerinde boştaki köylüler ateşe gelir,
/// anchor slot tutup oturur (warm). 3+ kişi oturduğunda yaşlı bir köylü
/// hikaye anlatmaya başlar; diğerleri dinler. Bittiğinde köye ufak moral.
///
/// Hayata geçirildiği yer: scene_firepit_gather (bu dosya).
/// Bağımlı sistemler: anchor_system.firepitSitPoints, VillagerActivity.warm/
/// storytelling/listening, _eventMorale/_eventMoraleLeft (HUD).
extension _SceneFirepitGather on _VillageSceneState {
  // ── Tetik pencereleri ──────────────────────────────────────────────────────
  /// Toplanma akşam başlar — dayLight bu eşiğin altına düştüğünde gather
  /// scan'i aktif olur. Gece (kNightThreshold) eşiğine inince zaten herkes
  /// uyumaya gider, sit otomatik cancel.
  static const double _kEveningGatherStart = 0.55;

  /// Gather scan periyodu (sn) — her N sn'de bir uygun NPC'leri tarar.
  static const double _kGatherScanInterval = 2.5;

  /// Hikaye saati tetik kontrolü periyodu.
  static const double _kStoryScanInterval = 4.0;

  /// Oturma süresi aralığı (sn) — dinlence süresi.
  static const double _kSitMinSec = 22.0;
  static const double _kSitMaxSec = 40.0;

  /// Hikaye süresi (sn) — anlatıcı bu kadar konuşur, dinleyiciler kalır.
  static const double _kStoryDuration = 18.0;

  /// Hikaye bitince köye eklenen moral bonusu + süresi (HUD'da görünür).
  static const double _kStoryMoralBonus = 0.10;
  static const double _kStoryMoralDuration = 35.0;

  /// Bir gather scan'de en fazla kaç NPC ateşe yönlendirilir — sahnenin
  /// "akın" hissetmemesi için.
  static const int _kMaxRecruitsPerScan = 2;

  /// Bir storytelling tetiğinde minimum oturan kişi sayısı (anlatıcı dahil).
  static const int _kMinSittersForStory = 3;

  // ── Tick'ten çağrılan ana scan'ler ────────────────────────────────────────
  void _tickFirepitGather(double dt) {
    if (_buildings.every((b) => b.type != BuildingType.firepit)) return;

    _gatherScanTimer += dt;
    if (_gatherScanTimer >= _kGatherScanInterval) {
      _gatherScanTimer = 0;
      _scanGather();
    }

    _storyScanTimer += dt;
    if (_storyScanTimer >= _kStoryScanInterval) {
      _storyScanTimer = 0;
      _scanStorytellers();
    }
  }

  /// Akşam pencerelerinde boştaki NPC'leri yakındaki ateş başına otur'a yolla.
  void _scanGather() {
    final dl = _cycle.dayLight;
    // Sadece akşam: dayLight night threshold ile evening start arası.
    if (dl >= _kEveningGatherStart || dl < kNightThreshold) return;
    if (_cycle.rainIntensity > 0.4) return; // yağmurda toplanma yok

    int recruited = 0;
    // Karışık tarama — her zaman aynı NPC önde olmasın.
    final candidates = List<VillagerEntity>.from(_villagers)..shuffle(_rng);
    for (final v in candidates) {
      if (recruited >= _kMaxRecruitsPerScan) break;
      if (!_canGather(v)) continue;
      // Slot rezerve et (NPC'nin pozisyonuna en yakını, maks 14 tile).
      final claim = _anchorSystem.claimNearestFirepitSit(
          v.gridX, v.gridY, v);
      if (claim == null) continue;
      final (point, slot) = claim;
      final cx = point.building.col + point.building.cols / 2.0;
      final cy = point.building.row + point.building.rows / 2.0;
      final dur = _kSitMinSec + _rng.nextDouble() * (_kSitMaxSec - _kSitMinSec);
      v.assignSit(slot.col, slot.row, cx, cy, dur,
          () => point.release(slot, v));
      recruited++;
    }
  }

  /// Bir köylünün ateşe çağrılmaya uygun olup olmadığı.
  bool _canGather(VillagerEntity v) {
    if (v.sitClaimed) return false;
    if (v.isSleeping || v.isInsideBuilding) return false;
    if (v.isCarrying) return false;
    if (v.activity != VillagerActivity.none) return false;
    if (v.socialCooldown > 0) return false;
    // Çocuk hariç (çocuklar oyun oynamaya devam etsin, akın hissi vermesin).
    if (v.isChild) return false;
    return true;
  }

  /// Her firepit için: oturanlar sayılır, eşiği aşarsa hikaye başlat.
  void _scanStorytellers() {
    final dl = _cycle.dayLight;
    if (dl >= _kEveningGatherStart || dl < kNightThreshold) return;

    for (final b in _buildings) {
      if (b.type != BuildingType.firepit) continue;
      final cx = b.col + b.cols / 2.0;
      final cy = b.row + b.rows / 2.0;
      // Bu ateşin etrafında oturanları topla (slot pozisyonu < 1.8 tile).
      final sitters = <VillagerEntity>[];
      for (final v in _villagers) {
        if (!v.isSeatedAtFire) continue;
        final dx = v.sitArriveX - cx;
        final dy = v.sitArriveY - cy;
        if (dx * dx + dy * dy > 1.8 * 1.8) continue;
        sitters.add(v);
      }
      if (sitters.length < _kMinSittersForStory) continue;
      // Zaten anlatıcı varsa atla.
      if (sitters.any((s) => s.activity == VillagerActivity.storytelling)) {
        continue;
      }
      _startStory(sitters);
    }
  }

  /// Anlatıcıyı seç (yaşlı tercih), diğerlerini listening yap, bittiğinde
  /// moral bonusu uygula.
  void _startStory(List<VillagerEntity> sitters) {
    // Yaşlı varsa yaşlıyı seç — yoksa rastgele yetişkin.
    sitters.sort((a, b) {
      final aE = a.lifeStage == LifeStage.elder ? 0 : 1;
      final bE = b.lifeStage == LifeStage.elder ? 0 : 1;
      return aE - bE;
    });
    final storyteller = sitters.first;
    storyteller.activity       = VillagerActivity.storytelling;
    storyteller.chatBubbleIcon = '📖';
    storyteller.chatBubbleTime = _kStoryDuration;
    // Anlatım süresi en az hikaye süresi kadar (kısa sürede kalkmasın).
    if (storyteller.warmthTimer < _kStoryDuration + 2) {
      storyteller.warmthTimer = _kStoryDuration + 2;
    }
    for (int i = 1; i < sitters.length; i++) {
      final l = sitters[i];
      l.activity = VillagerActivity.listening;
      // Dinleyicilerin oturma süresi anlatım kadar uzasın.
      if (l.warmthTimer < _kStoryDuration + 2) {
        l.warmthTimer = _kStoryDuration + 2;
      }
    }
    // Köye geçici moral bonusu — HUD'a yansır.
    if (_eventMoraleLeft < _kStoryMoralDuration) {
      _eventMorale     = _kStoryMoralBonus;
      _eventMoraleLeft = _kStoryMoralDuration;
      _eventLabel      = 'Ateş başı hikâye';
    }
  }
}
