import '../buildings/building_entity.dart';
import '../buildings/building_function.dart';
import '../buildings/building_type.dart';
import '../core/resources.dart';
import '../farm/farm_tile.dart';
import '../scene/scene_data.dart';

/// Köy Akışı — bol görev + politika-odaklı Tüzük ilerlemesi (no-fail).
///
/// Tasarım: `ObjectiveTracker`'ın (artık emekli) zenginleştirilmiş hâli.
/// Görevler bildirimsel `check`'lerle tamamlanır; her görev bir **görsel ödül**
/// taşır (kaynak DEĞİL). Köyün kimlik kademesi (charterTier) AĞIRLIKLA çıkarılan
/// politikalara (berat) bağlıdır → ilerleme yönetişim-odaklı. Hiçbir görev
/// başarısız olmaz, kademe yalnızca ilerler.

/// Görev kategorisi — panel ikonlandırması / gruplama için.
enum QuestCategory { founding, production, population, social, governance, beauty }

/// Görsel ödül yoğunluğu — scene_flow `_grantVisualReward` bunu FX + decor
/// kombosuna çevirir (kaynak yok). sparkle<bloom<festival<landmark.
enum VisualReward { sparkle, bloom, festival, landmark }

/// Tek bir görev — bildirimsel, durağan.
class Quest {
  final String id;
  final String icon;
  final String label;
  final String hint;
  final QuestCategory category;
  /// Hangi kimlik kademesinde açılır (charterTier >= tier ise görünür).
  final int tier;
  final bool Function(QuestContext) check;
  final VisualReward reward;

  const Quest({
    required this.id,
    required this.icon,
    required this.label,
    required this.hint,
    required this.category,
    required this.tier,
    required this.check,
    required this.reward,
  });
}

/// Görevlerin baktığı köy durumu — zengin snapshot.
class QuestContext {
  final List<BuildingEntity> buildings;
  final List<FarmTile> farmTiles;
  final int population;
  final ResourceBundle stock;
  final VillagePolicies policies;
  final int decorCount;
  final int charterTier;

  const QuestContext({
    required this.buildings,
    required this.farmTiles,
    required this.population,
    required this.stock,
    required this.policies,
    required this.decorCount,
    required this.charterTier,
  });

  int get enactedPolicies => policies.enactedCount;
  bool has(BuildingType t) => buildings.any((b) => b.type == t);
  bool hasRole(BuildingRole r) => buildings.any((b) => b.fn?.role == r);
}

/// Bir görevin panel için durum snapshot'u.
class QuestState {
  final Quest quest;
  final bool completed;
  /// İlk henüz tamamlanmamış (açık) görev mi — UI vurgular.
  final bool active;
  const QuestState(this.quest, this.completed, this.active);
}

/// Köyün kimlik kademesi tanımı — ad + ilerleme eşiği.
class CharterTier {
  final String name;
  final String icon;
  /// Bu kademeye geçmek için gereken minimum yürürlükteki politika sayısı.
  final int minPolicies;
  /// + gereken toplam tamamlanmış görev sayısı.
  final int minQuests;
  const CharterTier(this.name, this.icon, this.minPolicies, this.minQuests);
}

class QuestBook {
  /// Kimlik kademeleri — ilerleme AĞIRLIKLA politikaya bağlı (mid+ kademeler
  /// berat ister), kuruluş (0→1) görev-sayısı ile.
  static const List<CharterTier> tiers = [
    CharterTier('Yeni Ocak',        '🔥', 0, 0),
    CharterTier('Konuksever Köy',   '🏡', 0, 4),
    CharterTier('Şenlikli Kasaba',  '🎏', 2, 9),
    CharterTier('Bereketli Kasaba', '🌟', 4, 15),
  ];

  static int get maxTier => tiers.length - 1;

  /// completedCount + enactedPolicies → ulaşılan en yüksek kademe.
  static int charterTier(int completedCount, int enactedPolicies) {
    var t = 0;
    for (var i = 1; i < tiers.length; i++) {
      if (enactedPolicies >= tiers[i].minPolicies &&
          completedCount >= tiers[i].minQuests) {
        t = i;
      } else {
        break;
      }
    }
    return t;
  }

  static CharterTier tierOf(int t) => tiers[t.clamp(0, maxTier)];

  /// Bir sonraki kademe (varsa) — panel "ilerleme ipucu" için.
  static CharterTier? nextTier(int t) =>
      t < maxTier ? tiers[t + 1] : null;

  /// Açık kademedeki (tier <= charterTier) tamamlanmamış görevler — panel akışı.
  /// İlki "active" işaretlenir. Tamamlananlar listeden düşer (temiz to-do hissi).
  static List<QuestState> activeQuests(QuestContext ctx, Set<String> completed) {
    final res = <QuestState>[];
    var marked = false;
    for (final q in all) {
      if (q.tier > ctx.charterTier) continue;
      if (completed.contains(q.id)) continue;
      final active = !marked;
      marked = true;
      res.add(QuestState(q, false, active));
    }
    return res;
  }

  // ── Görev havuzu ──────────────────────────────────────────────────────────
  static const List<Quest> all = [
    // ── Tier 0 — Yeni Ocak (kuruluş) ─────────────────────────────────────
    Quest(
      id: 'firepit', icon: '🔥', label: 'Ateş Yeri kur',
      hint: 'Köy meydanına ateş yak (ücretsiz). NPC\'ler buradan doğar.',
      category: QuestCategory.founding, tier: 0,
      reward: VisualReward.sparkle, check: _firepit),
    Quest(
      id: 'lumber', icon: '🪓', label: 'Oduncu kulübesi kur',
      hint: 'Ağaçların yakınına Oduncu Kulübesi (12 odun) — odun akışı başlar.',
      category: QuestCategory.production, tier: 0,
      reward: VisualReward.sparkle, check: _lumber),
    Quest(
      id: 'house', icon: '🏠', label: 'İlk evi kur',
      hint: 'Köylülerin gece uyuması için bir Köy Evi (18 odun + 4 taş).',
      category: QuestCategory.founding, tier: 0,
      reward: VisualReward.bloom, check: _house),
    Quest(
      id: 'farm', icon: '🌾', label: 'Tarla aç',
      hint: 'Yiyecek üretmek için Tarla modunda bir alan seç.',
      category: QuestCategory.production, tier: 0,
      reward: VisualReward.sparkle, check: _farm),
    Quest(
      id: 'well', icon: '💧', label: 'Kuyu kur',
      hint: 'Kuyu evlere su sağlar. Tarlanın yanına yararlı.',
      category: QuestCategory.founding, tier: 0,
      reward: VisualReward.bloom, check: _well),

    // ── Tier 1 — Konuksever Köy ──────────────────────────────────────────
    Quest(
      id: 'townhall', icon: '🏛', label: 'Belediye kur',
      hint: 'Belediye yönetişimin merkezi — beratlar buradan çıkar.',
      category: QuestCategory.governance, tier: 1,
      reward: VisualReward.bloom, check: _townhall),
    Quest(
      id: 'firstPolicy', icon: '📜', label: 'İlk beratını çıkar',
      hint: 'Belediye panelinden bir politika yürürlüğe koy — köyün tüzüğü doğsun.',
      category: QuestCategory.governance, tier: 1,
      reward: VisualReward.festival, check: _firstPolicy),
    Quest(
      id: 'tavern', icon: '🍺', label: 'Taverna kur',
      hint: 'Taverna köyün sosyal kalbi — akşam buluşmaları canlanır.',
      category: QuestCategory.social, tier: 1,
      reward: VisualReward.bloom, check: _tavern),
    Quest(
      id: 'pop10', icon: '👪', label: 'Nüfusu 10\'a çıkar',
      hint: 'Belediye + bol yiyecek + ev kapasitesi → köy büyür.',
      category: QuestCategory.population, tier: 1,
      reward: VisualReward.festival, check: _pop10),
    Quest(
      id: 'church', icon: '⛪', label: 'Kilise kur',
      hint: 'Kilise huzur ve tören mekânı; yanına mezarlık doğar.',
      category: QuestCategory.social, tier: 1,
      reward: VisualReward.bloom, check: _church),

    // ── Tier 2 — Şenlikli Kasaba ─────────────────────────────────────────
    Quest(
      id: 'market', icon: '🛒', label: 'Pazar kur',
      hint: 'Pazar köyün ticaret meydanı — alışveriş telaşı başlar.',
      category: QuestCategory.production, tier: 2,
      reward: VisualReward.bloom, check: _market),
    Quest(
      id: 'beehive', icon: '🐝', label: 'Arı kovanı kur',
      hint: 'Çiçeklerin yakınına kovan koy — bal ve vızıltı gelir.',
      category: QuestCategory.production, tier: 2,
      reward: VisualReward.bloom, check: _beehive),
    Quest(
      id: 'florist', icon: '🌷', label: 'Çiçekçi kulübesi kur',
      hint: 'Çiçekçi köyü baştan başa renklendirir.',
      category: QuestCategory.beauty, tier: 2,
      reward: VisualReward.bloom, check: _florist),
    Quest(
      id: 'threePolicies', icon: '⚖️', label: 'Üç beratı yürürlüğe koy',
      hint: 'Köyün tüzüğü zenginleşsin — üç politika aktif olsun.',
      category: QuestCategory.governance, tier: 2,
      reward: VisualReward.festival, check: _threePolicies),
    Quest(
      id: 'neighborly', icon: '🤝', label: 'Komşuluk beratı çıkar',
      hint: 'Komşuluk politikası açılınca köylüler birbirine selam verir.',
      category: QuestCategory.governance, tier: 2,
      reward: VisualReward.bloom, check: _neighborly),
    Quest(
      id: 'pop20', icon: '🧑‍🤝‍🧑', label: 'Nüfusu 20\'ye çıkar',
      hint: 'Köy kasabaya dönüşüyor.',
      category: QuestCategory.population, tier: 2,
      reward: VisualReward.festival, check: _pop20),
    Quest(
      id: 'bloomVillage', icon: '🌸', label: 'Köyü çiçeklendir',
      hint: 'Görevler tamamlandıkça köy güzelleşir — 40 süs objesine ulaş.',
      category: QuestCategory.beauty, tier: 2,
      reward: VisualReward.bloom, check: _bloom40),

    // ── Tier 3 — Bereketli Kasaba ────────────────────────────────────────
    Quest(
      id: 'fivePolicies', icon: '👑', label: 'Beş beratlık tüzük',
      hint: 'Olgun bir yönetişim — beş politika aktif.',
      category: QuestCategory.governance, tier: 3,
      reward: VisualReward.landmark, check: _fivePolicies),
    Quest(
      id: 'hospitality', icon: '🚪', label: 'Misafirperverlik beratı',
      hint: 'Misafirperver köye gezginler katılır.',
      category: QuestCategory.governance, tier: 3,
      reward: VisualReward.bloom, check: _hospitality),
    Quest(
      id: 'warehouse', icon: '📦', label: 'Ambar kur',
      hint: 'Ambar stok kapasitesini büyütür.',
      category: QuestCategory.production, tier: 3,
      reward: VisualReward.bloom, check: _warehouse),
    Quest(
      id: 'pop30', icon: '🌟', label: 'Nüfusu 30\'a çıkar',
      hint: 'Bereketli, kalabalık bir kasaba.',
      category: QuestCategory.population, tier: 3,
      reward: VisualReward.festival, check: _pop30),
  ];

  // ── Görev kontrolleri ─────────────────────────────────────────────────────
  static bool _firepit(QuestContext c) => c.has(BuildingType.firepit);
  static bool _lumber(QuestContext c) => c.has(BuildingType.lumberCamp);
  static bool _house(QuestContext c) => c.hasRole(BuildingRole.housing);
  static bool _farm(QuestContext c) => c.farmTiles.isNotEmpty;
  static bool _well(QuestContext c) => c.has(BuildingType.well);
  static bool _townhall(QuestContext c) => c.has(BuildingType.townhall);
  static bool _tavern(QuestContext c) => c.has(BuildingType.tavern);
  static bool _church(QuestContext c) => c.has(BuildingType.church);
  static bool _market(QuestContext c) => c.has(BuildingType.market);
  static bool _beehive(QuestContext c) => c.has(BuildingType.beehive);
  static bool _florist(QuestContext c) => c.has(BuildingType.floristCottage);
  static bool _warehouse(QuestContext c) => c.has(BuildingType.warehouse);
  static bool _pop10(QuestContext c) => c.population >= 10;
  static bool _pop20(QuestContext c) => c.population >= 20;
  static bool _pop30(QuestContext c) => c.population >= 30;
  static bool _firstPolicy(QuestContext c) => c.enactedPolicies >= 1;
  static bool _threePolicies(QuestContext c) => c.enactedPolicies >= 3;
  static bool _fivePolicies(QuestContext c) => c.enactedPolicies >= 5;
  static bool _neighborly(QuestContext c) => c.policies.neighborliness;
  static bool _hospitality(QuestContext c) => c.policies.hospitality;
  static bool _bloom40(QuestContext c) => c.decorCount >= 40;
}
