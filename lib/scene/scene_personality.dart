part of '../main.dart';

/// Kişilik katmanı — köylülerin kişisel anları: yıldönümü (yaş kilometre taşı),
/// çağrısını buldu (genç→yetişkin meslek keşfi, [_tickCallingMoments]), BÜYÜDÜ
/// (çocuk→genç ilk iş), ve DOSTLUK (karşılıklı yüksek kanaat → can dostu).
/// Köylü sıcak, küçük bir an yaşar (bildirim + gövde dili + komşu tepkisi).
/// Cozy: spam yok, her taramada en fazla bir an; tamamen pozitif. Her an mevcut
/// veriye bağlıdır (yaş/lifeStage/opinion) — bağlanmayan süs an EKLENMEZ.
extension _ScenePersonality on _VillageSceneState {
  // ── "Büyüdü" anı (çocuk→genç) ──────────────────────────────────────────────
  static const _kGrewUpPool = [
    '🌱 {ad} büyüdü. Artık köyün işlerine el atıyor, peşinde koştuğu oyun değil.',
    '🌱 {ad} çocukluğu geride bıraktı. Sabah ilk kez kendi ayağıyla işe yürüdü.',
    '🌱 {ad} serpildi. Yükü hafif de olsa artık o da taşıyor.',
  ];
  static const _kGrewUpChroniclePool = [
    '{ad} büyüdü, köyün işine karıştı.',
    '{ad} çocukluktan çıktı.',
    '{ad} artık koşuşturmanın içinde.',
  ];

  // ── Dostluk anı (karşılıklı kanaat) ────────────────────────────────────────
  static const _kBondPool = [
    '🤝 {ad} ile {öteki} can dostu oldu. Artık işleri hep birlikte.',
    '🤝 {ad} ve {öteki} birbirinin sırdaşı — köyün en sağlam dostluğu.',
    '🤝 {ad-in} en yakını artık {öteki}. İkisini bir arada görmeye alıştı köy.',
  ];
  static const _kBondChroniclePool = [
    '{ad} ile {öteki} can dostu oldu.',
    '{ad} ve {öteki} arasında sağlam bir dostluk kuruldu.',
    '{ad-in} yol arkadaşı {öteki} oldu.',
  ];
  /// Dostluk anı tarama periyodu (sn) — seyrek, sakin tempo.
  static const double _kBondScanInterval = 5.0;
  /// İki köylünün "can dostu" sayılması için karşılıklı kanaat eşiği ([-1,1]).
  static const double _kBondThreshold = 0.55;

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
      // BÜYÜDÜ — çocukluktan çıkan genç bir kez kutlanır (köyün işine ilk el).
      if (!v.grewUpMoment && v.lifeStage != LifeStage.child) {
        v.grewUpMoment = true;
        _celebrateGrewUp(v);
        return; // taramada tek an
      }
      final years = (v.ageDays / _kAnnivYearDays).floor();
      if (years >= 1 && years > v.annivCount) {
        v.annivCount = years;
        _celebrateAnniversary(v, years);
        return; // taramada tek kutlama
      }
    }
  }

  /// Çocuk→genç büyüme anı — sıcak bildirim + filiz gövde dili + komşu tepkisi.
  void _celebrateGrewUp(VillagerEntity v) {
    v.feel(NpcEmotion.wonder, 3.5, moodDelta: 0.06);
    _reactNearby(v.gridX, v.gridY, 4.0, NpcEmotion.joy, 2.0, moodDelta: 0.02);
    final ctx = _voice(v, seed: _stableSeed('büyüdü${v.name}', _dayCount));
    _showNotification(Voice.say(_kGrewUpPool, ctx));
    _chronicle(Voice.say(_kGrewUpChroniclePool, ctx), icon: '🌱');
  }

  /// Tek köylünün yıldönümü — sıcak bildirim + sevinç gövde dili + komşu tepkisi.
  void _celebrateAnniversary(VillagerEntity v, int years) {
    v.feel(NpcEmotion.joy, 4.0, moodDelta: 0.08);
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
      _showNotification(Voice.say(_kCallingMissedPool, ctx));
      _chronicle(Voice.say(_kCallingMissedChroniclePool, ctx), icon: '🌫️');
    }
    // Çağrı kanalı — bu köylünün mesleği bir zanaat taşıyorsa ve köy henüz
    // bilmiyorsa, o zanaat şimdi köye doğar (kutlama bildirimi buradan gelir).
    _discoverCallingCraft(v, _CraftSource.calling);
  }

  /// DOSTLUK ANI — iki köylü birbirini yeterince sevince (karşılıklı kanaat
  /// [_kBondThreshold] üstü) "can dostu" olur ve bir kez kutlanır. Kanaat
  /// hafızadan gelir ([VillagerMemory.opinion]) — dedikodu/tanıklık/birlikte
  /// vakit değiştirir; yani bu an köyün gerçek ilişki dokusundan doğar, uydurma
  /// değil. Çift bazında dedupe: [_bondSeen] (kozmetik → kaydedilmez).
  void _tickFriendshipMoments(double dt) {
    _bondScan += dt;
    if (_bondScan < _kBondScanInterval) return;
    _bondScan = 0;
    if (_villagers.length < 2) return;
    // Karışık gez — hep aynı çift öne çıkmasın.
    final order = List<int>.generate(_villagers.length, (i) => i)..shuffle(_rng);
    for (final i in order) {
      final v = _villagers[i];
      if (v.isDying || v.lifeStage == LifeStage.child) continue;
      for (final e in v.memory.opinion.entries) {
        if (e.value < _kBondThreshold) continue;
        final o = e.key;
        if (o is! VillagerEntity || o.isDying || o.lifeStage == LifeStage.child) {
          continue;
        }
        if (o.memory.opinionOf(v) < _kBondThreshold) continue; // KARŞILIKLI şart
        final key = _bondKey(v, o);
        if (_bondSeen.contains(key)) continue;
        _bondSeen.add(key);
        _celebrateBond(v, o);
        return; // taramada tek an
      }
    }
  }

  /// İki köylünün sırasız çift anahtarı — kişilik tohumundan (kararlı).
  String _bondKey(VillagerEntity a, VillagerEntity b) {
    final x = a.personalitySeed, y = b.personalitySeed;
    return x <= y ? '$x:$y' : '$y:$x';
  }

  void _celebrateBond(VillagerEntity a, VillagerEntity b) {
    a.feel(NpcEmotion.love, 3.5, moodDelta: 0.06);
    b.feel(NpcEmotion.love, 3.5, moodDelta: 0.06);
    final ctx = _voice(a,
        other: b, seed: _stableSeed('dost${a.name}${b.name}', _dayCount));
    _showNotification(Voice.say(_kBondPool, ctx));
    _chronicle(Voice.say(_kBondChroniclePool, ctx), icon: '🤝');
  }
}
