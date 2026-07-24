import 'package:flutter/material.dart';
import '../core/resources.dart';
import '../scene/scene_data.dart';
import '../systems/event_system.dart';
import 'app_ui.dart';

// ScenarioReport + SimSnapshot data classes lib/scene/scene_data.dart'tan
// gelir — tek kaynaktan (main.dart hem buradan hem oradan import ediyordu).

/// Geliştirici test paneli — sağdan slide-in, kategorilere ayrılmış butonlar.
/// Modern koyu app_ui dilinde. Production'da kaldırılmadan önce her sistemi
/// tek tıkla test için.
class DevPanel extends StatelessWidget {
  // ── Durum okumaları ─────────────────────────────────────────────────────
  final bool   godMode;
  final double rainIntensity;
  final double timeOfDay;
  final int    villagerCount;
  final int    buildingCount;
  final int    fps; // 0 = bilinmiyor

  // ── Callback'ler ────────────────────────────────────────────────────────
  final VoidCallback onClose;
  final VoidCallback onOpenConsole;
  final VoidCallback onToggleGod;
  final void Function(double) onSetRain;
  final void Function(double) onSetTimeOfDay;
  final void Function(EventOutcome) onTriggerEvent;
  final void Function(ResourceKind, int) onAddResource;
  final VoidCallback onSpawnVillager;
  final VoidCallback onKillRandomVillager;
  final VoidCallback onClearEffects;
  final VoidCallback onNewMap;
  final VoidCallback onWakeAll;
  final VoidCallback onSeedLivingVillage;

  // Sim analiz — denge testi
  final double simSpeedBoost;       // 1..30x
  final List<SimSnapshot> simHistory;
  final void Function(double) onSetSimSpeed;
  final VoidCallback onClearSimHistory;

  // Otomatik senaryo testleri
  final String? activeScenario;     // null = pasif, dolu = çalışıyor
  final double  scenarioProgress;   // 0..1
  final ScenarioReport? lastReport;
  final VoidCallback onScenarioBaseline;
  final VoidCallback onScenarioPlague;
  final VoidCallback onScenarioDrought;
  final VoidCallback onScenarioFire;

  // Sosyal aktivite tetikleyicileri
  final VoidCallback onPlayMusic;
  final VoidCallback onStartDance;
  final VoidCallback onStartChat;
  final VoidCallback onStartConflict;
  final VoidCallback onIgniteFeud;
  /// Rastgele bir suç tetikler (sinsi yaklaşma → eylem → kaçış; yakalanabilir).
  final VoidCallback onStartCrime;
  final VoidCallback onClearActivities;
  final VoidCallback onMeteorShower;

  // Görsel test "full performans" godmode aksiyonları
  final VoidCallback onSeedShowcase;
  final VoidCallback onSetDawn;
  final VoidCallback onSetNoon;
  final VoidCallback onSetDusk;
  final VoidCallback onSetNight;
  final VoidCallback onToggleRain;
  final VoidCallback onAllPolicies;
  final VoidCallback onClearPolicies;
  /// Test: köyün bildiği tüm zanaatları aç (kilitli binaları menüde göster).
  final VoidCallback onUnlockAllCrafts;
  final VoidCallback onMakeSage;
  final VoidCallback onSpawnMigrant;
  /// Test: İmparatorluk vergi heyetini anında sahneye çağır (refah/sayaç geçitlerini
  /// atlar) — yaklaşan kolon + sinematik + pazarlığı beklemeden izle.
  final VoidCallback onSummonImperial;
  final VoidCallback onForcePetition;
  /// Test: dilekçeyi ambient getir + mühleti ~12s'e kıs (geri sayım/sıkışma/zorla
  /// açılışı beklemeden izle).
  final VoidCallback onForcePetitionShortFuse;
  /// Test: zorunlu huzuru anında tetikle (mühlet doldu → modal açılır, sim durur).
  final VoidCallback onForcePetitionAudience;
  /// Seçilebilir dilekçeler: (id, '🎉 Başlık') — DevPanel her biri için buton.
  final List<(String, String)> petitions;
  final void Function(String id) onForcePetitionId;
  final bool perfMode;
  final VoidCallback onTogglePerf;
  /// Ekranda kayan dev olay günlüğü konsolu açık mı (god mode'dan bağımsız).
  final bool devLogOn;
  final VoidCallback onToggleDevLog;

  const DevPanel({
    super.key,
    required this.godMode,
    required this.rainIntensity,
    required this.timeOfDay,
    required this.villagerCount,
    required this.buildingCount,
    this.fps = 0,
    required this.onClose,
    required this.onOpenConsole,
    required this.onToggleGod,
    required this.onSetRain,
    required this.onSetTimeOfDay,
    required this.onTriggerEvent,
    required this.onAddResource,
    required this.onSpawnVillager,
    required this.onKillRandomVillager,
    required this.onClearEffects,
    required this.onNewMap,
    required this.onWakeAll,
    required this.onSeedLivingVillage,
    required this.simSpeedBoost,
    required this.simHistory,
    required this.onSetSimSpeed,
    required this.onClearSimHistory,
    this.activeScenario,
    this.scenarioProgress = 0,
    this.lastReport,
    required this.onScenarioBaseline,
    required this.onScenarioPlague,
    required this.onScenarioDrought,
    required this.onScenarioFire,
    required this.onPlayMusic,
    required this.onStartDance,
    required this.onStartChat,
    required this.onStartConflict,
    required this.onIgniteFeud,
    required this.onStartCrime,
    required this.onClearActivities,
    required this.onMeteorShower,
    required this.onSeedShowcase,
    required this.onSetDawn,
    required this.onSetNoon,
    required this.onSetDusk,
    required this.onSetNight,
    required this.onToggleRain,
    required this.onAllPolicies,
    required this.onClearPolicies,
    required this.onUnlockAllCrafts,
    required this.onMakeSage,
    required this.onSpawnMigrant,
    required this.onSummonImperial,
    required this.onForcePetition,
    required this.onForcePetitionShortFuse,
    required this.onForcePetitionAudience,
    required this.petitions,
    required this.onForcePetitionId,
    required this.perfMode,
    required this.onTogglePerf,
    required this.devLogOn,
    required this.onToggleDevLog,
  });

  static const _accent = AppUi.accent;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          width: 320,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppUi.surface2, AppUi.surface1],
            ),
            border: Border(
              left: BorderSide(color: _accent, width: 2),
            ),
            boxShadow: [
              BoxShadow(color: Color(0x88000000), blurRadius: 24, offset: Offset(-6, 0)),
            ],
          ),
          child: SafeArea(
            child: Column(
              children: [
                _header(),
                _statusBar(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Komut konsolu — tüm dev aksiyonları tek arama
                        // kutusunda (buton çöplüğünün yerine geçen ana giriş).
                        _bigPrimaryBtn(
                          'Komut Konsolu  (`)',
                          'Ara · parametre gir · senaryo kaydet & tek tıkla oynat',
                          GameIconData.bolt,
                          onOpenConsole,
                        ),
                        const SizedBox(height: 7),
                        // Hızlı kurulum — en sık kullanılan iki aksiyon her
                        // zaman üstte, tek tık uzaklıkta.
                        _bigPrimaryBtn(
                          'Showcase Köyü',
                          'GodMode + tüm bina tipleri + tarla + ahır + 12 NPC + yaşlılar',
                          GameIconData.festival,
                          onSeedShowcase,
                        ),
                        const SizedBox(height: 7),
                        _bigPrimaryBtn(
                          'Yaşayan Köy Kur',
                          'Yeni harita + binalar + tarla + 5 köylü + bol kaynak',
                          GameIconData.home,
                          onSeedLivingVillage,
                        ),
                        const SizedBox(height: 4),
                        // Kalan her şey katlanabilir bölümlerde — panel uzun bir
                        // liste değil, ihtiyaç oldukça açılan başlıklar.
                        _CollapsibleSection(
                          title: 'GODMODE & GÖRSEL',
                          initiallyOpen: true,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _wrapButtons([
                                AppButton(
                                    label: godMode ? 'GodMode AÇIK' : 'GodMode',
                                    icon: GameIconData.bolt,
                                    kind: godMode
                                        ? AppButtonKind.filled
                                        : AppButtonKind.tonal,
                                    onTap: onToggleGod),
                                AppButton(label: 'Şafak', icon: GameIconData.dawn, onTap: onSetDawn),
                                AppButton(label: 'Öğle', icon: GameIconData.sun, onTap: onSetNoon),
                                AppButton(label: 'Akşam', icon: GameIconData.dawn, onTap: onSetDusk),
                                AppButton(label: 'Gece', icon: GameIconData.moon, onTap: onSetNight),
                                AppButton(
                                    label: rainIntensity > 0.05
                                        ? 'Yağmur KAPAT'
                                        : 'Yağmur AÇ',
                                    icon: GameIconData.rain,
                                    kind: rainIntensity > 0.05
                                        ? AppButtonKind.filled
                                        : AppButtonKind.tonal,
                                    tint: AppUi.info,
                                    onTap: onToggleRain),
                              ]),
                              const SizedBox(height: 7),
                              _wrapButtons([
                                AppButton(label: 'Tüm Yasaları Aç', icon: GameIconData.scroll, onTap: onAllPolicies),
                                AppButton(label: 'Tüm Zanaatları Aç', icon: GameIconData.hammer, onTap: onUnlockAllCrafts),
                                AppButton(label: 'Yasaları Sıfırla', icon: GameIconData.scroll, onTap: onClearPolicies),
                                AppButton(label: 'Bilge Yap', icon: GameIconData.star, onTap: onMakeSage),
                                AppButton(label: 'Göçmen Çağır', icon: GameIconData.people, onTap: onSpawnMigrant),
                                AppButton(label: '⚔️ İmparatorluk Çağır', icon: GameIconData.flame, kind: AppButtonKind.tonal, tint: AppUi.rust, onTap: onSummonImperial),
                                AppButton(label: 'Dilekçe Getir', icon: GameIconData.scroll, onTap: onForcePetition),
                                AppButton(label: 'Dilekçe: Kısa Mühlet', icon: GameIconData.scroll, kind: AppButtonKind.tonal, tint: AppUi.accent, onTap: onForcePetitionShortFuse),
                                AppButton(label: 'Dilekçe: Mühlet Bitir', icon: GameIconData.scroll, kind: AppButtonKind.tonal, tint: AppUi.rust, onTap: onForcePetitionAudience),
                                AppButton(
                                    label: perfMode ? 'Perf Modu AÇIK' : 'Perf Modu',
                                    icon: GameIconData.speed,
                                    kind: perfMode
                                        ? AppButtonKind.filled
                                        : AppButtonKind.tonal,
                                    tint: AppUi.sage,
                                    onTap: onTogglePerf),
                                AppButton(
                                    label: devLogOn
                                        ? '🎲 Olay Günlüğü AÇIK'
                                        : '🎲 Olay Günlüğü',
                                    icon: GameIconData.scroll,
                                    kind: devLogOn
                                        ? AppButtonKind.filled
                                        : AppButtonKind.tonal,
                                    tint: AppUi.info,
                                    onTap: onToggleDevLog),
                              ]),
                            ],
                          ),
                        ),
                        _CollapsibleSection(
                          title: 'DİLEKÇE SEÇ (ANINDA GETİR)',
                          child: _wrapButtons([
                            for (final p in petitions)
                              AppButton(
                                  label: p.$2,
                                  kind: AppButtonKind.ghost,
                                  onTap: () => onForcePetitionId(p.$1)),
                          ]),
                        ),
                        _CollapsibleSection(
                          title: 'OLAYLAR',
                          child: _eventsGrid(),
                        ),
                        _CollapsibleSection(
                          title: 'KAYNAKLAR',
                          child: _resourcesGrid(),
                        ),
                        _CollapsibleSection(
                          title: 'ZAMAN & HAVA',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _slider('Saat',
                                  '${(timeOfDay * 24).toStringAsFixed(1)} / 24',
                                  timeOfDay, onSetTimeOfDay),
                              _slider('Yağmur',
                                  '${(rainIntensity * 100).round()}%',
                                  rainIntensity, onSetRain),
                            ],
                          ),
                        ),
                        _CollapsibleSection(
                          title: 'KÖY',
                          child: _wrapButtons([
                            AppButton(label: '+Köylü', icon: GameIconData.people, onTap: onSpawnVillager),
                            AppButton(label: 'Rastgele Öldür', icon: GameIconData.flame, kind: AppButtonKind.danger, onTap: onKillRandomVillager),
                            AppButton(label: 'Herkesi Uyandır', icon: GameIconData.sun, onTap: onWakeAll),
                            AppButton(label: 'Yeni Harita', icon: GameIconData.map, onTap: onNewMap),
                          ]),
                        ),
                        _CollapsibleSection(
                          title: 'SOSYAL AKTİVİTELER',
                          child: _wrapButtons([
                            AppButton(label: 'Müzik', icon: GameIconData.festival, onTap: onPlayMusic),
                            AppButton(label: 'Dans', icon: GameIconData.festival, onTap: onStartDance),
                            AppButton(label: 'Sohbet', icon: GameIconData.people, onTap: onStartChat),
                            AppButton(label: 'Kavga', icon: GameIconData.people, tint: AppUi.rust, onTap: onStartConflict),
                            AppButton(label: 'Kan Davası', icon: GameIconData.people, tint: AppUi.rust, onTap: onIgniteFeud),
                            AppButton(label: 'Suç', icon: GameIconData.people, tint: AppUi.rust, onTap: onStartCrime),
                            AppButton(label: 'Göktaşı Yağmuru', icon: GameIconData.star, tint: AppUi.info, onTap: onMeteorShower),
                            AppButton(label: 'Temizle', icon: GameIconData.demolish, kind: AppButtonKind.ghost, onTap: onClearActivities),
                          ]),
                        ),
                        _CollapsibleSection(
                          title: 'OTOMATİK SENARYOLAR',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _scenarioControls(),
                              if (lastReport != null) ...[
                                const SizedBox(height: 9),
                                _reportCard(lastReport!),
                              ],
                            ],
                          ),
                        ),
                        _CollapsibleSection(
                          title: 'DENGE TESTİ (SİMÜLASYON)',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _simSpeedSlider(),
                              const SizedBox(height: 9),
                              _simHistoryChart(),
                              const SizedBox(height: 7),
                              AppButton(label: 'Geçmişi Temizle', icon: GameIconData.demolish, kind: AppButtonKind.ghost, onTap: onClearSimHistory),
                            ],
                          ),
                        ),
                        _CollapsibleSection(
                          title: 'DİĞER',
                          child: _wrapButtons([
                            AppButton(label: 'Efektleri Temizle', icon: GameIconData.demolish, kind: AppButtonKind.ghost, onTap: onClearEffects),
                          ]),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Üst başlık + close ──────────────────────────────────────────────────
  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppUi.line, width: 1),
        ),
      ),
      child: Row(
        children: [
          const GameIcon(GameIconData.bug, size: 20, color: _accent),
          const SizedBox(width: 11),
          Expanded(
            child: Text('Geliştirici Paneli',
                style: AppUi.title.copyWith(fontSize: 14, color: _accent)),
          ),
          AppIconButton(
            icon: GameIconData.close,
            size: 26,
            onTap: onClose,
          ),
        ],
      ),
    );
  }

  Widget _statusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      color: AppUi.surface0.withValues(alpha: 0.5),
      child: Row(
        children: [
          _stat('NPC', '$villagerCount'),
          const SizedBox(width: 16),
          _stat('Bina', '$buildingCount'),
          if (fps > 0) ...[
            const SizedBox(width: 16),
            _stat('FPS', '$fps'),
          ],
        ],
      ),
    );
  }

  Widget _stat(String label, String value) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${label.toUpperCase()} ', style: AppUi.label),
          Text(value, style: AppUi.number.copyWith(fontSize: 12)),
        ],
      );

  // ── Olay grid'i ─────────────────────────────────────────────────────────
  Widget _eventsGrid() {
    return Wrap(
      spacing: 6, runSpacing: 6,
      children: [
        for (final e in EventSystem.events)
          AppButton(
            label: '${e.icon} ${e.title}',
            kind: AppButtonKind.tonal,
            tint: switch (e.category) {
              EventCategory.positive => AppUi.sage,
              EventCategory.negative => AppUi.rust,
              EventCategory.neutral  => AppUi.accent,
            },
            onTap: () => onTriggerEvent(e),
          ),
      ],
    );
  }

  // ── Kaynak satırları ────────────────────────────────────────────────────
  Widget _resourcesGrid() {
    const kinds = ResourceKind.values;
    return Column(
      children: [
        for (final k in kinds) _resourceRow(k),
      ],
    );
  }

  Widget _resourceRow(ResourceKind k) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text('${k.icon} ${k.label}',
                style: AppUi.body.copyWith(fontSize: 11.5)),
          ),
          AppButton(
              label: '+50',
              height: 28,
              kind: AppButtonKind.tonal,
              onTap: () => onAddResource(k, 50)),
          const SizedBox(width: 5),
          AppButton(
              label: '+999',
              height: 28,
              kind: AppButtonKind.tonal,
              onTap: () => onAddResource(k, 999)),
          const SizedBox(width: 5),
          AppButton(
              label: '−50',
              height: 28,
              kind: AppButtonKind.ghost,
              onTap: () => onAddResource(k, -50)),
        ],
      ),
    );
  }

  // ── Slider satırı ──────────────────────────────────────────────────────
  Widget _slider(String label, String valueText, double v,
      void Function(double) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 64,
                child: Text(label.toUpperCase(), style: AppUi.label),
              ),
              Text(valueText, style: AppUi.number.copyWith(fontSize: 11)),
            ],
          ),
          SizedBox(
            height: 26,
            child: Slider(
              value: v.clamp(0.0, 1.0),
              activeColor: _accent,
              inactiveColor: AppUi.line,
              thumbColor: _accent,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _wrapButtons(List<Widget> children) =>
      Wrap(spacing: 6, runSpacing: 6, children: children);

  // ── Otomatik senaryo kontrolleri ───────────────────────────────────────
  Widget _scenarioControls() {
    if (activeScenario != null) {
      // Çalışıyorken progress bar
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
        decoration: BoxDecoration(
          color: AppUi.surface0,
          borderRadius: BorderRadius.circular(AppUi.radiusSm),
          border: Border.all(color: _accent.withValues(alpha: 0.6), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const GameIcon(GameIconData.play, size: 13, color: _accent),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(activeScenario!,
                      style: AppUi.bodyHi.copyWith(fontSize: 12)),
                ),
                Text('${(scenarioProgress * 100).round()}%',
                    style: AppUi.number.copyWith(fontSize: 11)),
              ],
            ),
            const SizedBox(height: 7),
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: AppUi.surface1,
                borderRadius: BorderRadius.circular(3),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: scenarioProgress,
                  child: Container(color: _accent),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Wrap(
      spacing: 6, runSpacing: 6,
      children: [
        AppButton(
            label: 'Baz Köy (10dk)',
            icon: GameIconData.home,
            onTap: onScenarioBaseline),
        AppButton(
            label: 'Salgın (8dk)',
            icon: GameIconData.bug,
            tint: AppUi.rust,
            onTap: onScenarioPlague),
        AppButton(
            label: 'Kuraklık (8dk)',
            icon: GameIconData.sun,
            tint: AppUi.gold,
            onTap: onScenarioDrought),
        AppButton(
            label: 'Yangın (5dk)',
            icon: GameIconData.flame,
            tint: AppUi.rust,
            onTap: onScenarioFire),
      ],
    );
  }

  // ── Senaryo sonuç raporu ───────────────────────────────────────────────
  Widget _reportCard(ScenarioReport r) {
    final verdictColor = r.warnings.isEmpty
        ? AppUi.sage
        : (r.warnings.length > 1 ? AppUi.rust : _accent);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
      decoration: BoxDecoration(
        color: AppUi.surface0,
        borderRadius: BorderRadius.circular(AppUi.radiusSm),
        border: Border.all(color: verdictColor.withValues(alpha: 0.6), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(r.name,
                    style: AppUi.bodyHi.copyWith(
                        fontSize: 12, color: verdictColor)),
              ),
              Text('${(r.durationSec / 60).toStringAsFixed(1)}dk',
                  style: AppUi.body.copyWith(
                      fontSize: 10, color: AppUi.textLo)),
            ],
          ),
          const SizedBox(height: 7),
          Text(r.verdict,
              style: AppUi.body.copyWith(
                  fontSize: 11,
                  color: verdictColor,
                  fontStyle: FontStyle.italic)),
          const SizedBox(height: 7),
          // Kaynak deltaları
          Wrap(
            spacing: 8, runSpacing: 5,
            children: r.resources.entries.map((e) {
              final (start, end) = e.value;
              final delta = end - start;
              final c = delta > 0
                  ? AppUi.sage
                  : (delta < 0 ? AppUi.rust : AppUi.textLo);
              return Text(
                '${e.key}: $start→$end (${delta >= 0 ? "+" : ""}$delta)',
                style: AppUi.body.copyWith(fontSize: 9.5, color: c),
              );
            }).toList(),
          ),
          // Nüfus deltası
          const SizedBox(height: 5),
          Text(
            'Nüfus: ${r.popStart} → ${r.popEnd} '
            '(${r.popEnd - r.popStart >= 0 ? "+" : ""}${r.popEnd - r.popStart})',
            style: AppUi.bodyHi.copyWith(
              fontSize: 10,
              color: (r.popEnd - r.popStart) > 0
                  ? AppUi.sage
                  : ((r.popEnd - r.popStart) < 0 ? AppUi.rust : AppUi.textLo),
            ),
          ),
          // Uyarılar
          if (r.warnings.isNotEmpty) ...[
            const SizedBox(height: 7),
            for (final w in r.warnings)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('⚠ $w',
                    style: AppUi.body.copyWith(
                        fontSize: 9.5, color: AppUi.rust)),
              ),
          ],
        ],
      ),
    );
  }

  // ── Sim hız slider ─────────────────────────────────────────────────────
  Widget _simSpeedSlider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 64,
                child: Text('SİM HIZI', style: AppUi.label),
              ),
              Text('×${simSpeedBoost.toStringAsFixed(1)}',
                  style: AppUi.number.copyWith(fontSize: 11)),
              const SizedBox(width: 9),
              if (simSpeedBoost > 1.01)
                AppChip(label: 'HIZLI', color: _accent, solid: true),
            ],
          ),
          SizedBox(
            height: 26,
            child: Slider(
              value: simSpeedBoost.clamp(1.0, 30.0),
              min: 1.0, max: 30.0,
              activeColor: _accent,
              inactiveColor: AppUi.line,
              thumbColor: _accent,
              onChanged: onSetSimSpeed,
            ),
          ),
        ],
      ),
    );
  }

  // ── Snapshot grafiği — son N kayıt mini line chart ─────────────────────
  Widget _simHistoryChart() {
    if (simHistory.isEmpty) {
      return Container(
        height: 60,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppUi.surface0,
          borderRadius: BorderRadius.circular(AppUi.radiusSm),
          border: Border.all(color: AppUi.line, width: 1),
        ),
        child: Text('Snapshot bekleniyor… (5 sn/snapshot)',
            style: AppUi.body.copyWith(fontSize: 10, color: AppUi.textLo)),
      );
    }
    final last = simHistory.last;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Üst satır: anlık değerler
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: AppUi.surface0,
            borderRadius: BorderRadius.circular(AppUi.radiusSm),
            border: Border.all(color: AppUi.line, width: 1),
          ),
          child: Row(
            children: [
              _statTiny('G', '${last.day}'),
              const SizedBox(width: 9),
              _statTiny('👥', '${last.population}'),
              const SizedBox(width: 9),
              _statTiny('🏠', '${last.buildings}'),
            ],
          ),
        ),
        const SizedBox(height: 7),
        // Kaynak grafikleri (mini sparkline her kaynak için)
        _sparkline('🪵 odun',  (s) => s.wood,  const Color(0xFFC08A4A)),
        _sparkline('🪨 taş',   (s) => s.stone, const Color(0xFFB0B0A8)),
        _sparkline('⚙ demir', (s) => s.iron,  const Color(0xFFAEB6E0)),
        _sparkline('⬛ kömür', (s) => s.coal,  const Color(0xFF6A6A6A)),
        _sparkline('🍞 yiyec', (s) => s.food,  AppUi.sage),
        _sparkline('🪙 altın', (s) => s.gold,  AppUi.gold),
        _sparkline('👥 nüfus', (s) => s.population * 4, _accent),
      ],
    );
  }

  Widget _statTiny(String label, String value) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label ',
              style: AppUi.body.copyWith(fontSize: 9.5, color: AppUi.textLo)),
          Text(value, style: AppUi.number.copyWith(fontSize: 11)),
        ],
      );

  Widget _sparkline(String label,
      int Function(SimSnapshot) read, Color color) {
    final values = simHistory.map(read).toList();
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final lastV = values.last;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 58,
            child: Text(label,
                style: AppUi.body.copyWith(fontSize: 9.5, color: AppUi.textLo)),
          ),
          Expanded(
            child: SizedBox(
              height: 16,
              child: CustomPaint(
                painter: _SparkPainter(values, maxV, color),
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 32,
            child: Text('$lastV',
                textAlign: TextAlign.right,
                style: AppUi.number.copyWith(fontSize: 10, color: color)),
          ),
        ],
      ),
    );
  }

  /// Büyük vurgulu buton — Hızlı Kurulum gibi öne çıkan aksiyonlar için.
  Widget _bigPrimaryBtn(
      String title, String subtitle, GameIconData icon, VoidCallback onTap) {
    return _BigBtn(
        title: title, subtitle: subtitle, icon: icon, onTap: onTap);
  }
}

// ── Buton bileşenleri ──────────────────────────────────────────────────────

class _BigBtn extends StatefulWidget {
  final String title;
  final String subtitle;
  final GameIconData icon;
  final VoidCallback onTap;
  const _BigBtn(
      {required this.title,
      required this.subtitle,
      required this.icon,
      required this.onTap});
  @override
  State<_BigBtn> createState() => _BigBtnState();
}

class _BigBtnState extends State<_BigBtn> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
          decoration: BoxDecoration(
            color: _hover
                ? Color.alphaBlend(
                    AppUi.accent.withValues(alpha: 0.24), AppUi.surface2)
                : Color.alphaBlend(
                    AppUi.accent.withValues(alpha: 0.12), AppUi.surface1),
            borderRadius: BorderRadius.circular(AppUi.radiusSm),
            border: Border.all(
              color: _hover
                  ? AppUi.accent
                  : AppUi.accent.withValues(alpha: 0.55),
              width: 1.5,
            ),
            boxShadow: _hover
                ? [BoxShadow(color: AppUi.accent.withValues(alpha: 0.3), blurRadius: 12)]
                : null,
          ),
          child: Row(
            children: [
              GameIcon(widget.icon, size: 20, color: AppUi.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(widget.title,
                        style: AppUi.bodyHi.copyWith(fontSize: 13)),
                    const SizedBox(height: 3),
                    Text(widget.subtitle,
                        style: AppUi.body.copyWith(
                            fontSize: 10, color: AppUi.textLo)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Katlanabilir bölüm — başlığa dokununca içeriği açar/kapatır. Dev panel'i
/// uzun bir kaydırma yerine ihtiyaç oldukça açılan başlık listesine çevirir.
/// Kendi açık/kapalı state'ini tutar; panel her açıldığında [initiallyOpen]'a
/// döner (öngörülebilir varsayılan).
class _CollapsibleSection extends StatefulWidget {
  final String title;
  final Widget child;
  final bool initiallyOpen;
  const _CollapsibleSection({
    required this.title,
    required this.child,
    this.initiallyOpen = false,
  });
  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          borderRadius: BorderRadius.circular(AppUi.radiusSm),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(
              children: [
                Text(widget.title, style: AppUi.label),
                const SizedBox(width: 8),
                Expanded(child: Container(height: 1, color: AppUi.line)),
                const SizedBox(width: 6),
                Icon(
                  _open ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: AppUi.textLo,
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity, height: 0),
          secondChild: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(width: double.infinity, child: widget.child),
          ),
          crossFadeState:
              _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 160),
          sizeCurve: Curves.easeOut,
        ),
      ],
    );
  }
}

/// Mini line chart — snapshot history için. Max değer ile normalize edilir.
class _SparkPainter extends CustomPainter {
  final List<int> values;
  final int maxV;
  final Color color;
  _SparkPainter(this.values, this.maxV, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || maxV <= 0) return;
    final w = size.width;
    final h = size.height;
    final dx = w / (values.length - 1);
    // Arka plan ızgarası — orta yatay çizgi
    final pGrid = Paint()
      ..color = AppUi.lineSoft
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, h / 2), Offset(w, h / 2), pGrid);
    // Line strip
    final pLine = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..isAntiAlias = true;
    final path = Path();
    for (int i = 0; i < values.length; i++) {
      final v = values[i] / maxV;
      final x = i * dx;
      final y = h - v * h;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, pLine);
    // Son noktayı vurgula
    final lastX = (values.length - 1) * dx;
    final lastY = h - (values.last / maxV) * h;
    final pDot = Paint()..color = color..isAntiAlias = true;
    canvas.drawCircle(Offset(lastX, lastY), 1.8, pDot);
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      old.values != values || old.maxV != maxV || old.color != color;
}
