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

  /// Çağrı tarama periyodu (sn) — yıldönümünden ayrı, daha sık (geçiş kaçmasın).
  static const double _kCallingScanInterval = 2.5;

  /// "Çağrısını buldu" anı — köyde büyüyen bir genç yetişkinliğe adım atınca
  /// mesleği görünür olur ([hasProfession]) ve bu bir kez kutlanır. Çağrısını
  /// dinledi mi (kişilik = meslek), yoksa ailesinin yoluna mı razı oldu — ona
  /// göre renklenir. Taramada en fazla bir an (sakin tempo). Cozy: tamamen
  /// pozitif; çağrısına rağmen başka mesleğe çekilenin kırgınlığı Faz 2'de.
  void _tickCallingMoments(double dt) {
    _callingScan += dt;
    if (_callingScan < _kCallingScanInterval) return;
    _callingScan = 0;
    if (_villagers.isEmpty) return;
    for (final v in _villagers) {
      if (v.isDying || v.callingFound) continue;
      if (v.lifeStage == LifeStage.adult || v.lifeStage == LifeStage.elder) {
        v.callingFound = true;
        _announceCalling(v);
        return; // taramada tek an
      }
    }
  }

  void _announceCalling(VillagerEntity v) {
    final prof = v.type.displayName.toLowerCase();
    final heeded = v.type == v.calling; // çağrısını dinledi mi
    if (heeded) {
      // Köyde o mesleğin ilk/tek temsilcisi mi → çağrısının öncüsü.
      final pioneer = !_villagers.any((o) =>
          o != v && !o.isDying && o.hasProfession && o.type == v.type);
      v.feel(NpcEmotion.wonder, 4.0, moodDelta: pioneer ? 0.14 : 0.10);
      v.chatBubbleIcon = '🌟';
      v.chatBubbleTime = 4.5;
      _reactNearby(v.gridX, v.gridY, 4.0, NpcEmotion.joy, 2.0, moodDelta: 0.02);
      if (pioneer) {
        _showNotification(
            '🌟 ${v.name} büyüdü — köyün ilk $prof oldu, çağrısının öncüsü.');
        _chronicle('${v.name} köyün ilk $prof oldu — çağrısının öncüsü.',
            icon: '🌟', milestone: true);
      } else {
        _showNotification(
            '🌟 ${v.name} büyüdü — içindeki çağrıyı dinledi, $prof oldu.');
        _chronicle('${v.name} çağrısını buldu: $prof.', icon: '🌟');
      }
    } else {
      // Çağrısına rağmen ailesinin yoluna çekildi — buruk büyüme. Kalıcı
      // kırgınlık moral formülünden gelir ('gönlü başka işte').
      final want = v.calling.displayName.toLowerCase();
      v.feel(NpcEmotion.content, 3.5, moodDelta: -0.05);
      v.chatBubbleIcon = '🌫️';
      v.chatBubbleTime = 4.0;
      _showNotification(
          '${v.name} büyüdü ve $prof oldu — ama içinde $want olma özlemi kaldı.');
      _chronicle('${v.name} $prof oldu; gönlü ise $want işinde.', icon: '🌫️');
    }
  }
}
