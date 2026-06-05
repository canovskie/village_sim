import '../buildings/building_entity.dart';
import '../buildings/building_function.dart';
import '../buildings/building_type.dart';
import '../farm/farm_tile.dart';

/// Köyün kuruluş aşamalarını izleyen hedef listesi — yeni oyuncu için
/// "ne yapacağım" rehberi. Her hedef state'e göre tamamlanmış sayılır;
/// renderer mini panelde gösterir, tamamlandıkça ✓ olur.
class Objective {
  final String id;
  final String icon;
  final String label;
  final String hint;
  /// Mevcut state ile tamamlanma kontrolü.
  final bool Function(ObjectiveContext) check;

  const Objective({
    required this.id,
    required this.icon,
    required this.label,
    required this.hint,
    required this.check,
  });
}

class ObjectiveContext {
  final List<BuildingEntity> buildings;
  final List<FarmTile> farmTiles;
  final int population;

  const ObjectiveContext({
    required this.buildings,
    required this.farmTiles,
    required this.population,
  });

  bool hasBuilding(BuildingType t) => buildings.any((b) => b.type == t);
}

/// Bir objective'in durum snapshot'u — UI tarafı buna bakar.
class ObjectiveState {
  final Objective obj;
  final bool completed;
  /// Sırada gelen (henüz tamamlanmamış ilk) hedef mi — UI vurgular.
  final bool active;
  const ObjectiveState(this.obj, this.completed, this.active);
}

class ObjectiveTracker {
  /// Kuruluş sırası — köyün doğal gelişim yolu.
  static const List<Objective> _list = [
    Objective(
      id: 'firepit',
      icon: '🔥',
      label: 'Ateş Yeri kur',
      hint: 'Köy meydanına ateş yak (ücretsiz). NPC\'ler buradan doğar — '
          'köyün kalbi.',
      check: _hasFirepit,
    ),
    Objective(
      id: 'lumber',
      icon: '🪓',
      label: 'Oduncu kulübesi',
      hint: 'Başlangıçta 25 odun var. Ağaçların yakınına Oduncu Kulübesi '
          'kur (12 odun) — düzenli odun akışı başlar.',
      check: _hasLumber,
    ),
    Objective(
      id: 'house',
      icon: '🏠',
      label: 'İlk evi kur',
      hint: 'Köylülerin gece uyuması için bir Köy Evi inşa et (18 odun + '
          '4 taş).',
      check: _hasHouse,
    ),
    Objective(
      id: 'farm',
      icon: '🌾',
      label: 'Tarla aç',
      hint: 'Yiyecek üretmek için Tarla modunda bir alan seç.',
      check: _hasFarm,
    ),
    Objective(
      id: 'well',
      icon: '💧',
      label: 'Kuyu kur',
      hint: 'Kuyu evlere su sağlar ve moral verir. Tarlanın yanına yararlı.',
      check: _hasWell,
    ),
    Objective(
      id: 'townhall',
      icon: '🏛',
      label: 'Belediye kur',
      hint: 'Belediye yeni köylülerin doğumunu başlatır — köyün büyüme motoru.',
      check: _hasTownhall,
    ),
    Objective(
      id: 'tavern',
      icon: '🍺',
      label: 'Taverna kur',
      hint: 'Taverna köy moralini güçlü biçimde yükseltir.',
      check: _hasTavern,
    ),
    Objective(
      id: 'growth',
      icon: '👨‍👩‍👧',
      label: 'Nüfusu 10\'a çıkar',
      hint: 'Belediye köylü doğurdukça nüfus artar. Bol yiyecek + ev kapasitesi gerek.',
      check: _hasPopulation10,
    ),
  ];

  /// Mevcut state için tüm hedeflerin durumunu döner.
  /// Active = ilk henüz tamamlanmamış hedef (oyuncu odaklanır).
  static List<ObjectiveState> evaluate(ObjectiveContext ctx) {
    final result = <ObjectiveState>[];
    bool foundActive = false;
    for (final o in _list) {
      final done = o.check(ctx);
      final active = !done && !foundActive;
      if (active) foundActive = true;
      result.add(ObjectiveState(o, done, active));
    }
    return result;
  }

  // ── Hedef kontrolleri ───────────────────────────────────────────────────
  static bool _hasFirepit(ObjectiveContext c)  => c.hasBuilding(BuildingType.firepit);
  static bool _hasHouse(ObjectiveContext c)    => c.buildings.any(
        (b) => b.fn?.role == BuildingRole.housing,
      );
  static bool _hasFarm(ObjectiveContext c)     => c.farmTiles.isNotEmpty;
  static bool _hasLumber(ObjectiveContext c)   => c.hasBuilding(BuildingType.lumberCamp);
  static bool _hasWell(ObjectiveContext c)     => c.hasBuilding(BuildingType.well);
  static bool _hasTownhall(ObjectiveContext c) => c.hasBuilding(BuildingType.townhall);
  static bool _hasTavern(ObjectiveContext c)   => c.hasBuilding(BuildingType.tavern);
  static bool _hasPopulation10(ObjectiveContext c) => c.population >= 10;
}
