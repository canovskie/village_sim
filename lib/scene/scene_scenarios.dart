part of '../main.dart';

/// Otomatik denge testleri — DevPanel'den çalıştırılır. Köyü preset'e
/// kurar, 30× hızda sim'i `durationSec` kadar koşturur, başlangıç + bitiş
/// snapshot'larından `ScenarioReport` üretir.
///
/// part of main.dart — State'in tüm private field'larına erişim için.
extension _SceneScenarios on _VillageSceneState {
  Future<void> _runScenario(
    String name,
    double durationSec,
    void Function() setup,
  ) async {
    if (_scenarioName != null) return;
    setStateHere(() {
      _scenarioName = name;
      _scenarioProgress = 0;
      _lastReport = null;
      _simHistory.clear();
    });
    setup();

    // Start snapshot.
    final start = _snapshot();
    // 30× hız → durationSec / 30 saniye gerçek zaman.
    const speed = 30.0;
    _devSpeedBoost = speed;
    final realMs = (durationSec / speed * 1000).round();
    const stepMs = 100;
    final steps = (realMs / stepMs).round();
    for (int i = 0; i < steps; i++) {
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: stepMs));
      if (mounted) {
        setStateHere(() => _scenarioProgress = (i + 1) / steps);
      }
    }
    _devSpeedBoost = 1.0;
    final end = _snapshot();

    // Rapor.
    final report = _buildReport(name, durationSec, start, end);
    if (mounted) {
      setStateHere(() {
        _scenarioName = null;
        _scenarioProgress = 0;
        _lastReport = report;
      });
      _showNotification('✓ Senaryo tamamlandı: $name');
    }
  }

  SimSnapshot _snapshot() => SimSnapshot(
    simTime: _time,
    day: _dayCount,
    population: _villagers.length,
    buildings: _buildings.length,
    wood: _stockpile.wood,
    stone: _stockpile.stone,
    iron: _stockpile.iron,
    coal: _stockpile.coal,
    food: _stockpile.food,
    gold: _stockpile.gold,
  );

  ScenarioReport _buildReport(
    String name,
    double durationSec,
    SimSnapshot a,
    SimSnapshot b,
  ) {
    final mins = durationSec / 60;
    final resources = <String, (int, int)>{
      'odun': (a.wood, b.wood),
      'taş': (a.stone, b.stone),
      'demir': (a.iron, b.iron),
      'kömür': (a.coal, b.coal),
      'yiyecek': (a.food, b.food),
      'altın': (a.gold, b.gold),
    };
    final warnings = <String>[];
    final foodPerMin = (b.food - a.food) / mins;
    final woodPerMin = (b.wood - a.wood) / mins;
    final popDelta = b.population - a.population;

    if (foodPerMin > 25) {
      warnings.add(
        'Yiyecek çok hızlı biriyor (+${foodPerMin.toStringAsFixed(1)}/dk)',
      );
    } else if (foodPerMin < -5) {
      warnings.add(
        'Yiyecek erimekte (${foodPerMin.toStringAsFixed(1)}/dk) — köy aç kalır',
      );
    }
    if (woodPerMin > 30) {
      warnings.add(
        'Odun çok hızlı biriyor (+${woodPerMin.toStringAsFixed(1)}/dk)',
      );
    }
    if (popDelta == 0 && mins > 5) {
      warnings.add('Nüfus durağan — büyüme döngüsü tetiklenmiyor olabilir');
    }
    if (popDelta < 0) {
      warnings.add('Nüfus azaldı ($popDelta) — açlık veya doğal ölüm baskın');
    }

    String verdict;
    if (warnings.isEmpty) {
      verdict = 'Denge ok ✓ — kaynak akışı sürdürülebilir.';
    } else if (warnings.length <= 1) {
      verdict = 'Genel olarak iyi, küçük not var.';
    } else {
      verdict = 'Dengesizlik tespit edildi — ${warnings.length} uyarı.';
    }
    return ScenarioReport(
      name: name,
      durationSec: durationSec,
      popStart: a.population,
      popEnd: b.population,
      resources: resources,
      verdict: verdict,
      warnings: warnings,
    );
  }

  // ── Hazır senaryolar ────────────────────────────────────────────────────
  void _scenarioBaseline() =>
      _runScenario('Baz Köy (10 dk)', 600, _buildLivingVillage);

  void _scenarioPlague() => _runScenario('Salgın Stresi (8 dk)', 480, () {
    _buildLivingVillage();
    final e = EventSystem.events.firstWhere((e) => e.id == EventIds.plague);
    _applyEventAutomatic(
      EventOutcome(
        id: e.id,
        title: e.title,
        icon: e.icon,
        message: e.message,
        category: e.category,
        severity: e.severity,
        moraleModifier: -0.25,
        duration: 60,
        effect: const EventEffect(
          fx: EventFx.plagueAura,
          npcSpeedMul: 0.7,
          duration: 60,
        ),
      ),
    );
  });

  void _scenarioDrought() => _runScenario('Kuraklık (8 dk)', 480, () {
    _buildLivingVillage();
    final e = EventSystem.events.firstWhere((e) => e.id == EventIds.drought);
    _applyEventAutomatic(e);
  });

  void _scenarioFire() => _runScenario('Yangın (5 dk)', 300, () {
    _buildLivingVillage();
    final e = EventSystem.events.firstWhere((e) => e.id == EventIds.houseFire);
    _applyEventAutomatic(
      EventOutcome(
        id: e.id,
        title: e.title,
        icon: e.icon,
        message: e.message,
        category: e.category,
        severity: e.severity,
        woodDelta: -28,
        moraleModifier: -0.15,
        duration: 30,
        effect: const EventEffect(fx: EventFx.fireOutbreak, duration: 60),
      ),
    );
  });
}
