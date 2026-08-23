part of '../main.dart';

// ── Sohbet konuları — her konu sıralı bir replik ikonu dizisi. Karşılıklı
// sohbette çift bu diziyi sırayla "söyler" → baloncuk anlamlı görünür
// (rastgele tek emoji yerine konuşmanın konusu).
const List<String> _kTopicGeneral = ['💬', '🙂', '❓', '😄'];
const List<String> _kTopicFarm = ['🌾', '💧', '☀', '🥕'];
const List<String> _kTopicTrade = ['🪙', '📦', '⚖', '🤝'];
const List<String> _kTopicFood = ['🍺', '🍞', '😋', '🍲'];
const List<String> _kTopicFamily = ['👶', '❤', '🏠', '😊'];
const List<String> _kTopicWork = ['⚒', '🪵', '🪨', '💪'];
const List<String> _kTopicGossip = ['🤫', '👀', '😮', '🙊'];
const List<String> _kTopicWeather = ['☀', '🌧', '🌬', '🌈'];

/// Sosyal canlılık: chat/music/dance — bağlama duyarlı, dağıtık per-NPC
/// değerlendirme. Pazar/taverna/ateş/akşam/yağmur çarpanları kullanır.
/// part of main.dart — State'in tüm private alanlarına erişim.
extension _SceneNpcActivity on _VillageSceneState {
  // NOT: eski `_tryStartChats` toplu taraması SİLİNDİ. Sosyalleşme kararı artık
  // köylünün YALNIZLIK dürtüsünden doğuyor (bkz. scene_mind `_bidSocial`);
  // buradaki yardımcılar yalnız KAZANAN teklifin yürütmesidir.

  bool _tryStartChatFor(VillagerEntity v) {
    final partner = _findNearbyIdle(v);
    if (partner == null) return false;
    // DEDİKODU — sohbet artık gerçekten bir şey TAŞIYOR. İki köylü hafıza
    // alışverişi yapar; aktarılan anı "kulaktan" sayılır (dinleyen ihbar
    // edemez, yalnız kanaati değişir ve dedikoduyu sürdürür). Köyde şüphenin
    // sosyal yoldan birikmesi bu zincirledir — sayaçla değil.
    final gossiped = _exchangeGossip(v, partner);
    // Konuya bağlı replik dizisi + karşılıklı sıra (turn-taking). Daha uzun
    // süre → birkaç replik gidip gelir. Gerçek bir haber aktarıldıysa konu
    // dedikodudur; baloncuk uydurma bir konu göstermez.
    final icons = gossiped ? _kTopicGossip : _convoTopic(v, partner);
    final dur = 6.0 + _rng.nextDouble() * 3.0;
    _beginConvo(v, partner, icons, dur, starter: true);
    _beginConvo(partner, v, icons, dur, starter: false);
    partner.socialCooldown = 40 + _rng.nextDouble() * 80;
    // Yüzünü karşısındakine dön — sohbet ediyormuş gibi.
    v.facingRight = partner.gridX >= v.gridX;
    partner.facingRight = v.gridX >= partner.gridX;
    v.feel(NpcEmotion.content, dur, moodDelta: 0.03);
    partner.feel(NpcEmotion.content, dur, moodDelta: 0.03);
    return true;
  }

  /// Bir köylüyü sohbet durumuna sokar (karşılıklı konuşma state'i).
  void _beginConvo(
    VillagerEntity v,
    VillagerEntity other,
    List<String> icons,
    double dur, {
    required bool starter,
  }) {
    v.activity = VillagerActivity.chat;
    v.chatBubbleTime = dur;
    v.chatBubbleIcon = ''; // baloncuk artık convoNow()'dan gelir
    v.convoPartner = other;
    v.convoIcons = icons;
    v.convoTotal = dur;
    v.convoStarter = starter;
  }

  /// Konuşan iki köylüye bağlama göre bir konu (replik ikonu dizisi) seçer:
  /// meslek, yakın bina (pazar/taverna), aile, mood. Ağırlıklı rastgele.
  List<String> _convoTopic(VillagerEntity a, VillagerEntity b) {
    bool isType(VillagerType t) => a.type == t || b.type == t;
    final mx = (a.gridX + b.gridX) / 2, my = (a.gridY + b.gridY) / 2;
    bool near(BuildingType bt, double r) => _nearAny(mx, my, _spotsOf(bt), r);

    final cands = <(List<String>, double)>[];
    void add(List<String> topic, double w) {
      if (w > 0) cands.add((topic, w));
    }

    add(_kTopicFarm, isType(VillagerType.farmer) ? 2.5 : 0);
    add(
      _kTopicWork,
      (isType(VillagerType.blacksmith) || isType(VillagerType.miner)) ? 2.2 : 0,
    );
    add(
      _kTopicTrade,
      near(BuildingType.market, 4)
          ? 2.5
          : (isType(VillagerType.merchant) ? 1.5 : 0),
    );
    add(_kTopicFood, near(BuildingType.tavern, 4) ? 2.6 : 0);
    add(
      _kTopicFamily,
      (a.children.isNotEmpty || b.children.isNotEmpty) ? 1.8 : 0,
    );
    add(_kTopicGossip, 1.0);
    add(_kTopicWeather, 0.8);
    add(_kTopicGeneral, 1.6);

    double total = 0;
    for (final c in cands) {
      total += c.$2;
    }
    var pick = _rng.nextDouble() * total;
    for (final c in cands) {
      pick -= c.$2;
      if (pick <= 0) return c.$1;
    }
    return _kTopicGeneral;
  }

  bool _tryStartMusicFor(VillagerEntity v) {
    v.activity = VillagerActivity.music;
    v.chatBubbleIcon = '🎸';
    v.chatBubbleTime = 9 + _rng.nextDouble() * 5;
    v.feel(NpcEmotion.content, 9, moodDelta: 0.04);
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
    partner.socialCooldown = 40 + _rng.nextDouble() * 80;
    v.feel(NpcEmotion.joy, dur, moodDelta: 0.06);
    partner.feel(NpcEmotion.joy, dur, moodDelta: 0.06);
    return true;
  }

  /// Dev panel: rastgele uygun NPC'de müzik başlat.
  bool _devStartMusic() {
    final adults =
        _villagers
            .where(
              (v) =>
                  !v.isInsideBuilding &&
                  !v.isSleeping &&
                  v.hasProfession &&
                  !v.isCarrying &&
                  v.activity == VillagerActivity.none,
            )
            .toList()
          ..shuffle(_rng);
    if (adults.isEmpty) return false;
    _tryStartMusicFor(adults.first);
    adults.first.socialCooldown = 40 + _rng.nextDouble() * 50;
    return true;
  }

  /// Dev panel: rastgele uygun çiftte dans başlat.
  bool _devStartDance() {
    final adults =
        _villagers
            .where(
              (v) =>
                  !v.isInsideBuilding &&
                  !v.isSleeping &&
                  v.hasProfession &&
                  !v.isCarrying &&
                  v.activity == VillagerActivity.none,
            )
            .toList()
          ..shuffle(_rng);
    for (final v in adults) {
      if (_tryStartDanceFor(v)) {
        v.socialCooldown = 40 + _rng.nextDouble() * 50;
        return true;
      }
    }
    return false;
  }

  /// Dev panel: rastgele uygun çiftte sohbet başlat.
  bool _devStartChat() {
    final adults =
        _villagers
            .where(
              (v) =>
                  !v.isInsideBuilding &&
                  !v.isSleeping &&
                  v.hasProfession &&
                  !v.isCarrying &&
                  v.activity == VillagerActivity.none,
            )
            .toList()
          ..shuffle(_rng);
    for (final v in adults) {
      if (_tryStartChatFor(v)) {
        v.socialCooldown = 40 + _rng.nextDouble() * 50;
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
  ///
  /// KANAAT KAPISI: suçunu gördüğün ya da hakkında kötü kanaat beslediğin
  /// biriyle sohbete oturmazsın. Bu, hafızanın en sessiz ama en okunur
  /// sonucudur — bir suçtan sonra köyde konuşmalar seyrelir, fail yalnız kalır.
  VillagerEntity? _findNearbyIdle(VillagerEntity v) {
    for (final o in _villagers) {
      if (identical(o, v)) continue;
      if (o.isInsideBuilding ||
          o.isSleeping ||
          o.isLeaving ||
          !o.hasProfession) {
        continue;
      }
      if (o.isCarrying || o.isDying) continue;
      if (o.activity != VillagerActivity.none) continue;
      if (o.socialCooldown > 0) continue;
      if (v.memory.suspects(o) || v.memory.opinionOf(o) < -0.40) continue;
      if (o.memory.suspects(v) || o.memory.opinionOf(v) < -0.40) continue;
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
