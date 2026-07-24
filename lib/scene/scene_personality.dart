part of '../main.dart';

/// Kişilik katmanı — köylülerin kişisel anları. Şimdilik: yıldönümü (yaş
/// kilometre taşı). Köylü köyde belli bir süreyi doldurunca sıcak, küçük bir
/// kutlama anı yaşar (bildirim + sevinç gövde dili). Cozy: spam yok, taramada
/// en fazla bir kutlama; tamamen pozitif.
extension _ScenePersonality on _VillageSceneState {
  // ── Kişisel anların sesi ([[lib/text/voice.dart]]) ────────────────────────

  static const _kAnnivPool = [
    '🎂 {ad} köyde {yıl}. yılını doldurdu. Akşam kâsesine fazladan çorba kondu.',
    '🎂 {yıl} yıldır burada. {sevdiği} deyince {ad-in} hâlâ gözü parlıyor.',
    '🎂 {ad} için {yıl}. yıl. Komşuları kapısına bir demet bırakmış.',
  ];
  static const _kCallingPioneerPool = [
    '🌟 {ad} büyüdü. Köyde bu işi ilk o yapıyor: {iş}.',
    '🌟 {ad} yetişkinliğe adım attı ve {iş} olarak işe koyuldu. Aletlerini kendi yaptı.',
    '🌟 Bugünden sonra köyün {iş} var: {ad}.',
  ];
  static const _kCallingPioneerChroniclePool = [
    '{ad} köyün ilk {iş} oldu.',
    'Köyde bu iş ilk kez tutuldu: {ad}, {iş}.',
    '{ad} bu işi köye getiren ilk kişi oldu: {iş}.',
  ];
  static const _kCallingHeededPool = [
    '🌟 {ad} büyüdü. İçinden geleni yaptı: {iş}.',
    '🌟 {ad} artık {iş}. Kimse şaşırmadı.',
    '🌟 {ad-in} eli işe yattı. {iş} oldu.',
  ];
  static const _kCallingHeededChroniclePool = [
    '{ad} çağrısını buldu: {iş}.',
    '{ad-in} eli işe yattı: {iş}.',
    '{ad} kendi yolunu tuttu: {iş}.',
  ];
  static const _kCallingMissedPool = [
    '{ad} büyüdü ve {iş} oldu. İstediği bu değildi.',
    '{ad-in} eline {iş} aletleri tutuşturuldu. Geceleri hâlâ {özlem} olmayı düşünüyor.',
    '{ad} artık {iş}. Gönlü {özlem} işinde kaldı.',
  ];
  static const _kCallingMissedChroniclePool = [
    '{ad} {iş} oldu; gönlü {özlem} işinde.',
    '{ad-in} yolu {iş} oldu, isteği {özlem}.',
    '{ad} {iş} olarak işe başladı; içindeki özlem başka.',
  ];

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
    _showNotification(Voice.say(
        _kAnnivPool,
        _voice(v,
            seed: _stableSeed('yıl${v.name}$years', _dayCount),
            extra: {
              'yıl': '$years',
              'sevdiği': v.personality.likes.label,
            })));
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
    final ctx = _voice(v,
        seed: _stableSeed('çağrı${v.name}', _dayCount),
        extra: {
          'iş': prof,
          'özlem': v.calling.displayName.toLowerCase(),
        });
    if (heeded) {
      // Köyde o mesleğin ilk/tek temsilcisi mi → çağrısının öncüsü.
      final pioneer = !_villagers.any((o) =>
          o != v && !o.isDying && o.hasProfession && o.type == v.type);
      v.feel(NpcEmotion.wonder, 4.0, moodDelta: pioneer ? 0.14 : 0.10);
      v.chatBubbleIcon = '🌟';
      v.chatBubbleTime = 4.5;
      _reactNearby(v.gridX, v.gridY, 4.0, NpcEmotion.joy, 2.0, moodDelta: 0.02);
      if (pioneer) {
        _showNotification(Voice.say(_kCallingPioneerPool, ctx));
        _chronicle(Voice.say(_kCallingPioneerChroniclePool, ctx),
            icon: '🌟', milestone: true);
      } else {
        _showNotification(Voice.say(_kCallingHeededPool, ctx));
        _chronicle(Voice.say(_kCallingHeededChroniclePool, ctx), icon: '🌟');
      }
    } else {
      // Çağrısına rağmen ailesinin yoluna çekildi — buruk büyüme. Kalıcı
      // kırgınlık moral formülünden gelir ('gönlü başka işte').
      v.feel(NpcEmotion.content, 3.5, moodDelta: -0.05);
      v.chatBubbleIcon = '🌫️';
      v.chatBubbleTime = 4.0;
      _showNotification(Voice.say(_kCallingMissedPool, ctx));
      _chronicle(Voice.say(_kCallingMissedChroniclePool, ctx), icon: '🌫️');
    }
    // Çağrı kanalı — bu köylünün mesleği bir zanaat taşıyorsa ve köy henüz
    // bilmiyorsa, o zanaat şimdi köye doğar (kutlama bildirimi buradan gelir).
    _discoverCallingCraft(v, _CraftSource.calling);
  }
}
