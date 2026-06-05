import 'package:flutter/material.dart';
import '../core/resources.dart';
import '../scene/scene_data.dart';
import '../systems/event_system.dart';
import 'game_theme.dart';

// ScenarioReport + SimSnapshot data classes lib/scene/scene_data.dart'tan
// gelir — tek kaynaktan (main.dart hem buradan hem oradan import ediyordu).

/// Geliştirici test paneli — sağdan slide-in, kategorilere ayrılmış butonlar.
/// Production'da kaldırılmadan önce her sistemi tek tıkla test için.
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
  final VoidCallback onClearActivities;

  const DevPanel({
    super.key,
    required this.godMode,
    required this.rainIntensity,
    required this.timeOfDay,
    required this.villagerCount,
    required this.buildingCount,
    this.fps = 0,
    required this.onClose,
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
    required this.onClearActivities,
  });

  static const _accent = Color(0xFFE9A23B);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          width: 320,
          decoration: const BoxDecoration(
            color: Color(0xF21A140C),
            border: Border(
              left: BorderSide(color: _accent, width: 2),
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _header(),
                _statusBar(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _section('Hızlı Kurulum'),
                        _bigPrimaryBtn(
                          '🏡  Yaşayan Köy Kur',
                          'Yeni harita + binalar + tarla + 5 köylü + bol kaynak',
                          onSeedLivingVillage,
                        ),
                        const SizedBox(height: 14),
                        _section('Olaylar'),
                        _eventsGrid(),
                        const SizedBox(height: 14),
                        _section('Kaynaklar'),
                        _resourcesGrid(),
                        const SizedBox(height: 14),
                        _section('Zaman & Hava'),
                        _slider('Saat',
                            '${(timeOfDay * 24).toStringAsFixed(1)} / 24',
                            timeOfDay, onSetTimeOfDay),
                        _slider('Yağmur',
                            '${(rainIntensity * 100).round()}%',
                            rainIntensity, onSetRain),
                        const SizedBox(height: 14),
                        _section('Köy'),
                        _wrapButtons([
                          _DevBtn('👶 +Köylü', onSpawnVillager),
                          _DevBtn('🕯 Rastgele Öldür', onKillRandomVillager),
                          _DevBtn('💤 Herkesi Uyandır', onWakeAll),
                          _DevBtn('🗺 Yeni Harita', onNewMap),
                        ]),
                        const SizedBox(height: 14),
                        _section('Sosyal Aktiviteler'),
                        _wrapButtons([
                          _DevBtn('🎸 Müzik', onPlayMusic),
                          _DevBtn('💃 Dans', onStartDance),
                          _DevBtn('💬 Sohbet', onStartChat),
                          _DevBtn('🧹 Temizle', onClearActivities),
                        ]),
                        const SizedBox(height: 14),
                        _section('Otomatik Senaryolar'),
                        _scenarioControls(),
                        if (lastReport != null) ...[
                          const SizedBox(height: 7),
                          _reportCard(lastReport!),
                        ],
                        const SizedBox(height: 14),
                        _section('Denge Testi (Simülasyon)'),
                        _simSpeedSlider(),
                        const SizedBox(height: 7),
                        _simHistoryChart(),
                        const SizedBox(height: 5),
                        _DevBtn('🗑 Geçmişi Temizle', onClearSimHistory),
                        const SizedBox(height: 14),
                        _section('Diğer'),
                        _wrapButtons([
                          _DevBtn(godMode ? '⚡ GodMode AÇIK' : '⚡ GodMode',
                              onToggleGod, active: godMode),
                          _DevBtn('🧹 Efektleri Temizle', onClearEffects),
                        ]),
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
          bottom: BorderSide(color: Color(0x33FFFFFF), width: 1),
        ),
      ),
      child: Row(
        children: [
          const Text('🐞', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Geliştirici Paneli',
                style: TextStyle(
                  color: _accent,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  letterSpacing: 1.2,
                )),
          ),
          GestureDetector(
            onTap: onClose,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: MedievalTheme.chipDecoration(),
              child: const Text('✕',
                  style: TextStyle(
                      color: MedievalTheme.textSecondary,
                      fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      color: const Color(0x22000000),
      child: Row(
        children: [
          _stat('NPC', '$villagerCount'),
          const SizedBox(width: 14),
          _stat('Bina', '$buildingCount'),
          if (fps > 0) ...[
            const SizedBox(width: 14),
            _stat('FPS', '$fps'),
          ],
        ],
      ),
    );
  }

  Widget _stat(String label, String value) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label ',
              style: const TextStyle(
                color: MedievalTheme.textSecondary,
                fontSize: 9.5,
                fontFamily: 'monospace',
              )),
          Text(value,
              style: const TextStyle(
                color: MedievalTheme.textAccent,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              )),
        ],
      );

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 7),
        child: Text(title.toUpperCase(),
            style: const TextStyle(
              color: _accent,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
              fontFamily: 'monospace',
            )),
      );

  // ── Olay grid'i ─────────────────────────────────────────────────────────
  Widget _eventsGrid() {
    return Wrap(
      spacing: 5, runSpacing: 5,
      children: [
        for (final e in EventSystem.events)
          _ChoiceTinyBtn(
            label: '${e.icon} ${e.title}',
            color: switch (e.category) {
              EventCategory.positive => const Color(0xFF6FBE4A),
              EventCategory.negative => const Color(0xFFD45A45),
              EventCategory.neutral  => const Color(0xFFE9A23B),
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
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text('${k.icon} ${k.label}',
                style: const TextStyle(
                  color: MedievalTheme.textPrimary,
                  fontSize: 10.5,
                  fontFamily: 'monospace',
                )),
          ),
          _DevBtn('+50', () => onAddResource(k, 50)),
          const SizedBox(width: 4),
          _DevBtn('+999', () => onAddResource(k, 999)),
          const SizedBox(width: 4),
          _DevBtn('−50', () => onAddResource(k, -50)),
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
                width: 60,
                child: Text(label,
                    style: const TextStyle(
                      color: MedievalTheme.textSecondary,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    )),
              ),
              Text(valueText,
                  style: const TextStyle(
                    color: MedievalTheme.textAccent,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  )),
            ],
          ),
          SizedBox(
            height: 24,
            child: Slider(
              value: v.clamp(0.0, 1.0),
              activeColor: _accent,
              inactiveColor: const Color(0x44FFFFFF),
              thumbColor: _accent,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _wrapButtons(List<Widget> children) =>
      Wrap(spacing: 5, runSpacing: 5, children: children);

  // ── Otomatik senaryo kontrolleri ───────────────────────────────────────
  Widget _scenarioControls() {
    if (activeScenario != null) {
      // Çalışıyorken progress bar
      return Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
        decoration: BoxDecoration(
          color: const Color(0xFF1B130A),
          border: Border.all(color: _accent.withValues(alpha: 0.6), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('▶', style: TextStyle(color: _accent, fontSize: 13)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(activeScenario!,
                      style: const TextStyle(
                        color: MedievalTheme.textAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      )),
                ),
                Text('${(scenarioProgress * 100).round()}%',
                    style: const TextStyle(
                      color: MedievalTheme.textSecondary,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    )),
              ],
            ),
            const SizedBox(height: 5),
            Container(
              height: 3,
              color: const Color(0x33000000),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: scenarioProgress,
                child: Container(color: _accent),
              ),
            ),
          ],
        ),
      );
    }
    return Wrap(
      spacing: 5, runSpacing: 5,
      children: [
        _DevBtn('🏘 Baz Köy (10dk)', onScenarioBaseline),
        _DevBtn('🤒 Salgın (8dk)', onScenarioPlague),
        _DevBtn('☀ Kuraklık (8dk)', onScenarioDrought),
        _DevBtn('🔥 Yangın (5dk)', onScenarioFire),
      ],
    );
  }

  // ── Senaryo sonuç raporu ───────────────────────────────────────────────
  Widget _reportCard(ScenarioReport r) {
    final verdictColor = r.warnings.isEmpty
        ? const Color(0xFF6FC07A)
        : (r.warnings.length > 1
            ? const Color(0xFFE07868)
            : _accent);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
      decoration: BoxDecoration(
        color: const Color(0xFF120E08),
        border: Border.all(color: verdictColor.withValues(alpha: 0.6), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('📊 ${r.name}',
                  style: TextStyle(
                    color: verdictColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  )),
              const Spacer(),
              Text('${(r.durationSec / 60).toStringAsFixed(1)}dk',
                  style: const TextStyle(
                    color: MedievalTheme.textSecondary,
                    fontSize: 9,
                    fontFamily: 'monospace',
                  )),
            ],
          ),
          const SizedBox(height: 6),
          Text(r.verdict,
              style: TextStyle(
                color: verdictColor,
                fontSize: 10,
                fontFamily: 'monospace',
                fontStyle: FontStyle.italic,
              )),
          const SizedBox(height: 6),
          // Kaynak deltaları
          Wrap(
            spacing: 6, runSpacing: 4,
            children: r.resources.entries.map((e) {
              final (start, end) = e.value;
              final delta = end - start;
              final c = delta > 0
                  ? const Color(0xFF6FC07A)
                  : (delta < 0 ? const Color(0xFFE07868)
                              : MedievalTheme.textSecondary);
              return Text(
                '${e.key}: $start→$end (${delta >= 0 ? "+" : ""}$delta)',
                style: TextStyle(
                  color: c, fontSize: 9, fontFamily: 'monospace',
                ),
              );
            }).toList(),
          ),
          // Nüfus deltası
          const SizedBox(height: 4),
          Text(
            'Nüfus: ${r.popStart} → ${r.popEnd} '
            '(${r.popEnd - r.popStart >= 0 ? "+" : ""}${r.popEnd - r.popStart})',
            style: TextStyle(
              color: (r.popEnd - r.popStart) > 0
                  ? const Color(0xFF6FC07A)
                  : ((r.popEnd - r.popStart) < 0
                      ? const Color(0xFFE07868)
                      : MedievalTheme.textSecondary),
              fontSize: 9.5, fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
            ),
          ),
          // Uyarılar
          if (r.warnings.isNotEmpty) ...[
            const SizedBox(height: 6),
            for (final w in r.warnings)
              Padding(
                padding: const EdgeInsets.only(top: 1.5),
                child: Text('⚠ $w',
                    style: const TextStyle(
                      color: Color(0xFFE07868),
                      fontSize: 9,
                      fontFamily: 'monospace',
                    )),
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
              const SizedBox(
                width: 60,
                child: Text('Sim Hızı',
                    style: TextStyle(
                      color: MedievalTheme.textSecondary,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    )),
              ),
              Text('×${simSpeedBoost.toStringAsFixed(1)}',
                  style: const TextStyle(
                    color: MedievalTheme.textAccent,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  )),
              const SizedBox(width: 8),
              if (simSpeedBoost > 1.01)
                const Text('⏩ HIZLI',
                    style: TextStyle(
                      color: Color(0xFFE9A23B),
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    )),
            ],
          ),
          SizedBox(
            height: 24,
            child: Slider(
              value: simSpeedBoost.clamp(1.0, 30.0),
              min: 1.0, max: 30.0,
              activeColor: _accent,
              inactiveColor: const Color(0x44FFFFFF),
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
          color: const Color(0x22000000),
          border: Border.all(color: const Color(0x33FFFFFF), width: 1),
        ),
        child: const Text('Snapshot bekleniyor… (5 sn/snapshot)',
            style: TextStyle(
              color: MedievalTheme.textSecondary,
              fontSize: 9,
              fontFamily: 'monospace',
            )),
      );
    }
    final last = simHistory.last;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Üst satır: anlık değerler
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0x22000000),
            border: Border.all(color: const Color(0x33FFFFFF), width: 1),
          ),
          child: Row(
            children: [
              _statTiny('G', '${last.day}'),
              const SizedBox(width: 7),
              _statTiny('👥', '${last.population}'),
              const SizedBox(width: 7),
              _statTiny('🏠', '${last.buildings}'),
            ],
          ),
        ),
        const SizedBox(height: 5),
        // Kaynak grafikleri (mini sparkline her kaynak için)
        _sparkline('🪵 odun',  (s) => s.wood,  const Color(0xFFC08A4A)),
        _sparkline('🪨 taş',   (s) => s.stone, const Color(0xFFB0B0A8)),
        _sparkline('⚙ demir', (s) => s.iron,  const Color(0xFFAEB6E0)),
        _sparkline('⬛ kömür', (s) => s.coal,  const Color(0xFF6A6A6A)),
        _sparkline('🍞 yiyec', (s) => s.food,  const Color(0xFF6FC07A)),
        _sparkline('🪙 altın', (s) => s.gold,  const Color(0xFFE0C040)),
        _sparkline('👥 nüfus', (s) => s.population * 4, const Color(0xFFE9A23B)),
      ],
    );
  }

  Widget _statTiny(String label, String value) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label ',
              style: const TextStyle(
                color: MedievalTheme.textSecondary,
                fontSize: 9,
                fontFamily: 'monospace',
              )),
          Text(value,
              style: const TextStyle(
                color: MedievalTheme.textAccent,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              )),
        ],
      );

  Widget _sparkline(String label,
      int Function(SimSnapshot) read, Color color) {
    final values = simHistory.map(read).toList();
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final lastV = values.last;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(label,
                style: const TextStyle(
                  color: MedievalTheme.textSecondary,
                  fontSize: 9,
                  fontFamily: 'monospace',
                )),
          ),
          Expanded(
            child: SizedBox(
              height: 16,
              child: CustomPaint(
                painter: _SparkPainter(values, maxV, color),
              ),
            ),
          ),
          const SizedBox(width: 5),
          SizedBox(
            width: 32,
            child: Text('$lastV',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: color,
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                )),
          ),
        ],
      ),
    );
  }

  /// Büyük vurgulu buton — Hızlı Kurulum gibi öne çıkan aksiyonlar için.
  Widget _bigPrimaryBtn(String title, String subtitle, VoidCallback onTap) {
    return _BigBtn(title: title, subtitle: subtitle, onTap: onTap);
  }
}

// ── Buton bileşenleri ──────────────────────────────────────────────────────

class _DevBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool active;
  const _DevBtn(this.label, this.onTap, {this.active = false});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active
              ? DevPanel._accent.withValues(alpha: 0.30)
              : const Color(0xFF221A10),
          border: Border.all(
              color: active
                  ? DevPanel._accent
                  : const Color(0x44FFFFFF),
              width: 1),
        ),
        child: Text(label,
            style: const TextStyle(
              color: MedievalTheme.textPrimary,
              fontSize: 10,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
            )),
      ),
    );
  }
}

class _BigBtn extends StatefulWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _BigBtn({required this.title, required this.subtitle, required this.onTap});
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
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: _hover
                ? DevPanel._accent.withValues(alpha: 0.24)
                : DevPanel._accent.withValues(alpha: 0.14),
            border: Border.all(
              color: _hover
                  ? DevPanel._accent
                  : DevPanel._accent.withValues(alpha: 0.55),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.title,
                  style: const TextStyle(
                    color: MedievalTheme.textAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  )),
              const SizedBox(height: 3),
              Text(widget.subtitle,
                  style: const TextStyle(
                    color: MedievalTheme.textSecondary,
                    fontSize: 9.5,
                    fontFamily: 'monospace',
                  )),
            ],
          ),
        ),
      ),
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
      ..color = const Color(0x22FFFFFF)
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

class _ChoiceTinyBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ChoiceTinyBtn(
      {required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          border: Border.all(color: color.withValues(alpha: 0.55), width: 1),
        ),
        child: Text(label,
            style: TextStyle(
              color: color,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
            )),
      ),
    );
  }
}
