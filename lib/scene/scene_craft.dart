part of '../main.dart';

/// ─── Zanaatın Yaşamı ────────────────────────────────────────────────────────
///
/// Kilit iskeleti buildings/craft.dart'ta (hangi bina hangi zanaat). Burası o
/// zanaatın köye NASIL girdiği: üç organik kanal —
///   • Çağrı    → [_announceCalling] (scene_personality) bunu çağırır.
///   • Dışarıdan→ [_spawnMigrant] (scene_building_spawn) bunu çağırır.
///   • Birikim  → taşıyıcı odun/taş boşalttıkça mastery birikir; [_tickCraftDiscovery]
///               eşiği geçeni köye kazandırır.
/// Kayıp (son usta ölünce) Faz C'de eklenecek.
extension _SceneCraft on _VillageSceneState {
  /// Yapı zanaatı keşif eşiği — tek bir köylünün bir zanaatta biriktirmesi
  /// gereken ustalık (odun/taş kutusu teslimi başına +1). Erken oyunun ilk
  /// birkaç günü aktif taşımayla marangozluk doğsun diye ölçülü tutuldu.
  static const double _kMasteryDiscoverThreshold = 22.0;
  static const double _kCraftScanInterval = 3.0;
  /// Bir zanaatı "hâlâ bilen" sayılmak için gereken ustalık — keşif eşiğinden
  /// düşük: az taşımış bir el de zanaatı canlı tutar (yapı zanaatları böylece
  /// nadiren kaybolur; asıl kayıp riski TEK temsilcili meslek zanaatlarında).
  static const double _kMasteryHolderThreshold = 8.0;

  /// Bir zanaatı köye kat (idempotent). Zaten biliniyorsa hiçbir şey yapmaz.
  /// Yeni eklendiyse hafif bildirim + günce satırı + köy çapında sevinç → true.
  bool _discoverCraft(String craft,
      {VillagerEntity? by, required _CraftSource source}) {
    if (!_knownCrafts.add(craft)) return false; // Set.add: yeni değilse false
    final name = Craft.displayName(craft);
    final ctx = by != null
        ? _voice(by,
            seed: _stableSeed('zanaat$craft', _dayCount),
            extra: {'zanaat': name})
        : null;
    final pool = switch (source) {
      _CraftSource.calling => _kCraftCallingPool,
      _CraftSource.migrant => _kCraftMigrantPool,
      _CraftSource.mastery => _kCraftMasteryPool,
    };
    final msg = ctx != null ? Voice.say(pool, ctx) : '$name köye geldi.';
    _showNotification('⚒ $msg');
    _chronicle(msg, icon: '⚒', milestone: true);
    _feelVillage(NpcEmotion.wonder, 3.0, 0.04);
    if (by != null) {
      by.feel(NpcEmotion.wonder, 4.0, moodDelta: 0.12);
      by.chatBubbleIcon = '⚒';
      by.chatBubbleTime = 4.5;
    }
    return true;
  }

  /// Çağrı/göç kanalı ortak yardımcı: köylünün mesleğinin taşıdığı zanaatı
  /// (varsa, henüz bilinmiyorsa) köye kat.
  void _discoverCallingCraft(VillagerEntity v, _CraftSource source) {
    final craft = kCallingCraft[v.type];
    if (craft != null) _discoverCraft(craft, by: v, source: source);
  }

  /// Birikim kanalı — yapı zanaatları (marangozluk/taş) yalnız buradan doğar.
  /// Bir köylünün ustalığı eşiği geçtiyse o zanaatı köye kazandırır; o köylü
  /// zanaatın öncüsüdür.
  void _tickCraftDiscovery(double dt) {
    _craftScan += dt;
    if (_craftScan < _kCraftScanInterval) return;
    _craftScan = 0;
    for (final craft in Craft.structural) {
      if (_knownCrafts.contains(craft)) continue;
      for (final v in _villagers) {
        if (v.isDying) continue;
        if ((v.mastery[craft] ?? 0) >= _kMasteryDiscoverThreshold) {
          _discoverCraft(craft, by: v, source: _CraftSource.mastery);
          break; // bu zanaat açıldı; sıradaki zanaata geç
        }
      }
    }
  }

  // ── Kayıp & çıraklık koruması (melez) ─────────────────────────────────────

  /// Bir köylü öldüğünde (scene_funeral) çağrılır. v ARTIK _villagers içinde
  /// DEĞİL (funeral öncesi çıkarıldı) → "başka yaşayan usta" = _villagers'ta
  /// biri. Sahibi olduğu bir zanaatın son ustasıysa: çıraklık politikası +
  /// bir çırak varsa bilgi sürer; yoksa zanaat köyden kaybolur (bina menüden
  /// kaybolur, dikili yapılar kalır).
  /// Köyde bilgi arşivi (kütüphane/belediye) varken hiçbir zanaat kaybolmaz —
  /// "Lonca" fikrinin somut hâli: kurumsal hafıza bilgiyi kalıcı güvenceye alır.
  /// Erken oyunda bilgi usta-çıraka bağlı kırılgan; arşiv dikilince kaybolmaz.
  bool get _hasKnowledgeArchive => _buildings.any((b) =>
      b.type == BuildingType.library || b.type == BuildingType.townhall);

  void _onCraftHolderDeath(VillagerEntity v) {
    // Bilgi arşivi (kütüphane/belediye) her zanaatı kalıcı korur → kayıp yok.
    if (_hasKnowledgeArchive) return;
    for (final craft in _craftsHeldBy(v).toList()) {
      final stillHeld =
          _villagers.any((o) => !o.isDying && _holdsCraft(o, craft));
      if (stillHeld) continue;
      final apprentice = _policies.apprenticeship ? _pickApprentice(v) : null;
      if (apprentice != null) {
        // Yapı zanaatında çırağa ustalık tohumla → gerçek usta olur. Meslek
        // zanaatında bilgi köyde "hatırlanır" (zanaat known kalır, çırak
        // büyüyünce fiilen uygular).
        if (Craft.structural.contains(craft)) {
          apprentice.gainMastery(craft, _kMasteryHolderThreshold);
        }
        final ctx = _voice(apprentice,
            seed: _stableSeed('çırak$craft', _dayCount),
            extra: {'zanaat': Craft.displayName(craft)});
        final msg = Voice.say(_kCraftApprenticePool, ctx);
        _showNotification('🪡 $msg');
        _chronicle(msg, icon: '🪡');
        apprentice.chatBubbleIcon = '🪡';
        apprentice.chatBubbleTime = 4.0;
      } else {
        _loseCraft(craft);
      }
    }
  }

  /// Bir zanaatı köyden sil (son ustası gitti, çırak yok). İdempotent.
  void _loseCraft(String craft) {
    if (!_knownCrafts.remove(craft)) return;
    // Köyün UNUTTUĞU şey kalıcı bir izdir: geç oyun dilekçeleri bunu okur
    // ("dedemin bildiği işi kimse bilmiyor"). Hafıza bayrağı kayda da girer.
    _villageMemory.add('craft.lost');
    final name = Craft.displayName(craft);
    final ctx = _villagers.isNotEmpty
        ? _voice(_villagers.first,
            seed: _stableSeed('kayıp$craft', _dayCount), extra: {'zanaat': name})
        : null;
    final msg = ctx != null ? Voice.say(_kCraftLostPool, ctx) : '$name unutuldu.';
    _showNotification('🕯️ $msg');
    _chronicle(msg, icon: '🕯️', milestone: true);
    _feelVillage(NpcEmotion.grief, 4.0, -0.05);
  }

  /// v'nin usta olduğu zanaatlar (yapı = ustalık eşiği; meslek = çalışan yetişkin).
  Iterable<String> _craftsHeldBy(VillagerEntity v) sync* {
    for (final craft in Craft.structural) {
      if ((v.mastery[craft] ?? 0) >= _kMasteryHolderThreshold) yield craft;
    }
    if (v.hasProfession) {
      final pc = kCallingCraft[v.type];
      if (pc != null) yield pc;
    }
  }

  bool _holdsCraft(VillagerEntity v, String craft) {
    if (Craft.structural.contains(craft)) {
      return (v.mastery[craft] ?? 0) >= _kMasteryHolderThreshold;
    }
    return v.hasProfession && kCallingCraft[v.type] == craft;
  }

  /// Bilgiyi sürdürecek çırak — önce ustanın yaşayan (henüz meslek edinmemiş)
  /// çocuğu, sonra köyün herhangi bir çocuğu/genci. Yetişkinden başka kimse
  /// yoksa null → bilgi kaybolur (çıraklık, GENÇ nesle bağlıdır).
  VillagerEntity? _pickApprentice(VillagerEntity master) {
    for (final c in master.children) {
      if (!c.isDying && !c.hasProfession && _villagers.contains(c)) return c;
    }
    for (final o in _villagers) {
      if (o.isDying) continue;
      if (o.lifeStage == LifeStage.child || o.lifeStage == LifeStage.youth) {
        return o;
      }
    }
    return null;
  }

  // ── Ses havuzları — {zanaat} yer tutucusu meslek/zanaat adıyla dokunur ─────

  /// Çağrı: köyde büyüyen biri o zanaatı ilk kez uygular.
  static const _kCraftCallingPool = [
    '{ad} çağrısını buldu — {zanaat} artık köyün elinde.',
    '{zanaat} köyde ilk kez can buldu; {ad} yolunu açtı.',
    'Köy bir zanaat daha öğrendi: {zanaat}. Ustası {ad}.',
  ];

  /// Dışarıdan: göçmen bilmediğimiz bir zanaatı taşır.
  static const _kCraftMigrantPool = [
    '{ad} uzaktan {zanaat} getirdi — köy bu işi ilk kez tanıyor.',
    'Yabancının hüneri köye kaldı: {zanaat} artık biliniyor.',
    '{zanaat}, {ad} ile birlikte köyün kapısından girdi.',
  ];

  /// Birikim: emek ustalığa döndü — çok taşıyan işlemeyi keşfetti.
  static const _kCraftMasteryPool = [
    '{ad} yıllarca taşıdı, sonunda {zanaat} onun elinde doğdu.',
    'Emek hüner oldu: {ad} sayesinde köy artık {zanaat} biliyor.',
    '{zanaat} kimseden öğrenilmedi — {ad} onu emekle buldu.',
  ];

  /// Kayıp: son usta gitti, kimse öğrenmemişti — zanaat unutuldu.
  static const _kCraftLostPool = [
    'Son ustası göçtü; {zanaat} köyde unutuldu.',
    '{zanaat} bilen kalmadı. El bir daha o işi tutmayacak.',
    'Kimse öğrenmemişti — {zanaat} ustayla birlikte toprağa girdi.',
  ];

  /// Çıraklık koruması: usta gitti ama çırağı işi sürdürdü.
  static const _kCraftApprenticePool = [
    '{ad} ustasının işini sürdürdü — {zanaat} köyde yaşıyor.',
    'Usta gitti ama {zanaat} {ad-in} elinde kaldı.',
    '{ad} çıraklıkta öğrendiğini unutmadı: {zanaat} sürüyor.',
  ];
}

/// Bir zanaatın köye giriş kanalı — bildirim/günce metnini renklendirir.
enum _CraftSource { calling, migrant, mastery }
