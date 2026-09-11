/// Kararlarla konan gündelik usuller. Hafıza tek kural kaynağıdır;
/// yalnız yürüyen sıra ve tekrar zamanı kayda ayrıca yazılır.
class DecisionCustoms {
  int cookingDay = -1;
  final Set<String> cookedHouses = {};
  double nextPatrolSim = 0;

  static bool musicAllowed(Set<String> memory, double timeOfDay) {
    if (timeOfDay >= 0.25 && timeOfDay < 0.75) return true;
    if (memory.contains('music.quiet')) return false;
    // Gün batımından sonraki ilk oyun saati.
    if (memory.contains('music.hour')) {
      return timeOfDay >= 0.75 && timeOfDay < 0.75 + 1 / 24;
    }
    return true;
  }

  static bool bellWorn(Set<String> memory, double timeOfDay) =>
      !memory.contains('bell.day') || (timeOfDay >= 0.25 && timeOfDay < 0.75);

  static double hearthPriority(
    Set<String> memory, {
    required bool elder,
    required double chill,
  }) => (memory.contains('hearth.elders') && elder ? 2.0 : 0.0) + chill;

  String? cookingHouse(Set<String> memory, int day, List<String> arrivalOrder) {
    if (!memory.contains('oven.rotation') && !memory.contains('oven.early')) {
      return null;
    }
    if (cookingDay != day) {
      cookingDay = day;
      cookedHouses.clear();
    }
    var houses = arrivalOrder.toSet().toList();
    if (houses.isEmpty) return null;
    if (houses.every(cookedHouses.contains)) cookedHouses.clear();
    if (memory.contains('oven.rotation')) {
      houses.sort();
      final offset = day % houses.length;
      houses = [...houses.skip(offset), ...houses.take(offset)];
    }
    return houses.firstWhere((h) => !cookedHouses.contains(h));
  }

  Map<String, Object> toJson() => {
    'cookingDay': cookingDay,
    'cookedHouses': cookedHouses.toList(),
    'nextPatrolSim': nextPatrolSim,
  };
  static DecisionCustoms fromJson(Object? raw) {
    final result = DecisionCustoms();
    if (raw is! Map) return result;
    result.cookingDay = (raw['cookingDay'] as num?)?.toInt() ?? -1;
    result.cookedHouses.addAll(
      (raw['cookedHouses'] as List? ?? []).whereType<String>(),
    );
    result.nextPatrolSim = (raw['nextPatrolSim'] as num?)?.toDouble() ?? 0;
    return result;
  }
}
