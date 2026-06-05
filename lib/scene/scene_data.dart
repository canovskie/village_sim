import '../systems/event_system.dart';

/// Sahnede aktif olan bir EventEffect örneği — banner kapansa da efekt
/// kendi süresince yaşar (animasyon süresi != moral süresi olabilir).
class ActiveFx {
  final EventEffect effect;
  double timeLeft;
  ActiveFx(this.effect, this.timeLeft);
}

/// Otomatik senaryo sonuç raporu — DevPanel'de gösterilir.
class ScenarioReport {
  final String name;
  final double durationSec;     // sim saniyesi geçilen
  final int popStart, popEnd;
  final Map<String, (int, int)> resources; // 'wood' → (start, end)
  final String verdict;         // metin özeti (denge skoru / not)
  final List<String> warnings;  // dengesizlik uyarıları
  const ScenarioReport({
    required this.name,
    required this.durationSec,
    required this.popStart,
    required this.popEnd,
    required this.resources,
    required this.verdict,
    required this.warnings,
  });
}

/// Denge testi için zaman içinde kaynak/nüfus snapshot'u.
class SimSnapshot {
  final double simTime;
  final int day;
  final int population;
  final int buildings;
  final int wood, stone, iron, coal, food, gold;
  const SimSnapshot({
    required this.simTime,
    required this.day,
    required this.population,
    required this.buildings,
    required this.wood,
    required this.stone,
    required this.iron,
    required this.coal,
    required this.food,
    required this.gold,
  });
}
