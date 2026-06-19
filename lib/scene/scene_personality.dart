part of '../main.dart';

/// Kişilik katmanı — köylülerin kişisel anları. Şimdilik: yıldönümü (yaş
/// kilometre taşı). Köylü köyde belli bir süreyi doldurunca sıcak, küçük bir
/// kutlama anı yaşar (bildirim + sevinç gövde dili). Cozy: spam yok, taramada
/// en fazla bir kutlama; tamamen pozitif.
extension _ScenePersonality on _VillageSceneState {
  /// Bir "yıl" kaç oyun günü — yıldönümü bu aralıkla gelir.
  static const double _kAnnivYearDays = 6.0;

  /// Yıldönümü tarama periyodu (sn, sim zamanı).
  static const double _kAnnivScanInterval = 6.0;

  void _tickPersonalMoments(double dt) {
    _annivScan += dt;
    if (_annivScan < _kAnnivScanInterval) return;
    _annivScan = 0;
    if (_villagers.isEmpty) return;

    // Yıldönümü hak eden bir köylü bul (taramada yalnız biri — sakin tempo).
    // Karışık gez ki hep aynı kişi öne çıkmasın.
    final order = List<int>.generate(_villagers.length, (i) => i)..shuffle(_rng);
    for (final i in order) {
      final v = _villagers[i];
      if (v.isDying) continue;
      final years = (v.ageDays / _kAnnivYearDays).floor();
      if (years >= 1 && years > v.annivCount) {
        v.annivCount = years;
        _celebrateAnniversary(v, years);
        return; // taramada tek kutlama
      }
    }
  }

  /// Tek köylünün yıldönümü — sıcak bildirim + sevinç gövde dili + komşu tepkisi.
  void _celebrateAnniversary(VillagerEntity v, int years) {
    v.feel(NpcEmotion.joy, 4.0, moodDelta: 0.08);
    v.chatBubbleIcon = '🎂';
    v.chatBubbleTime = 4.0;
    _reactNearby(v.gridX, v.gridY, 4.0, NpcEmotion.joy, 2.0, moodDelta: 0.03);
    final like = v.personality.likes.label;
    _showNotification('🎂 ${v.name} köyde $years. yılını kutluyor — $like sevdalısı.');
  }
}
