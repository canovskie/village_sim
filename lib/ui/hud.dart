import 'package:flutter/material.dart';
import '../core/resources.dart';
import 'app_ui.dart';

/// Oyun HUD'u — sol-üst kaynak/nüfus panosu + sağ-üst saat panosu + kontroller.
/// Modern koyu app_ui dili: temiz paneller, vektör ikonlar, animasyonlu moral.
class GameHUD extends StatelessWidget {
  final ResourceBundle stockpile;
  final int woodInTransit, stoneInTransit, ironInTransit, coalInTransit, foodInTransit;

  final int villagerCount, farmerCount, woodcutterCount, minerCount, fisherCount, builderCount, busyBuilders;

  final double timeOfDay, rainIntensity, dayLight;
  final int dayCount;

  final int buildingCount, pendingOrderCount;

  final double morale;
  final bool lowWater, starving;
  final String? eventLabel;

  final bool godMode;
  final VoidCallback onNewMap, onToggleGod, onTriggerEvent;

  final double effectTimeLeft;
  final double effectDuration;
  final bool effectPositive;

  final VoidCallback onToggleDev;

  final double timeScale;
  final VoidCallback onCycleSpeed;

  const GameHUD({
    super.key,
    required this.stockpile,
    required this.woodInTransit,
    required this.stoneInTransit,
    required this.ironInTransit,
    required this.coalInTransit,
    required this.foodInTransit,
    required this.villagerCount,
    required this.farmerCount,
    required this.woodcutterCount,
    required this.minerCount,
    required this.fisherCount,
    required this.builderCount,
    required this.busyBuilders,
    required this.timeOfDay,
    required this.rainIntensity,
    required this.dayLight,
    required this.dayCount,
    required this.buildingCount,
    required this.pendingOrderCount,
    required this.morale,
    required this.lowWater,
    required this.starving,
    this.eventLabel,
    required this.godMode,
    required this.onNewMap,
    required this.onToggleGod,
    required this.onTriggerEvent,
    required this.timeScale,
    required this.onCycleSpeed,
    this.effectTimeLeft = 0,
    this.effectDuration = 1,
    this.effectPositive = true,
    required this.onToggleDev,
  });

  // ── Türetilenler ──────────────────────────────────────────────────────────

  String get _clockText {
    final h = (timeOfDay * 24).floor() % 24;
    final m = ((timeOfDay * 24 - h) * 60).floor();
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  GameIconData get _weatherIcon {
    if (rainIntensity > 0.5) return GameIconData.storm;
    if (rainIntensity > 0.0) return GameIconData.rain;
    if (dayLight > 0.7) return GameIconData.sun;
    if (dayLight > 0.3) return GameIconData.dawn;
    return GameIconData.moon;
  }

  String get _weatherLabel {
    if (rainIntensity > 0.5) return 'sağanak';
    if (rainIntensity > 0.0) return 'yağmur';
    if (dayLight > 0.7) return 'açık';
    if (dayLight > 0.3) return 'alacakaranlık';
    return 'gece';
  }

  Color get _moraleColor => morale >= 0.6
      ? AppUi.sage
      : morale >= 0.4
          ? AppUi.accentSoft
          : AppUi.rust;

  int get _totalPop =>
      villagerCount + farmerCount + woodcutterCount + minerCount + fisherCount + builderCount;

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          Positioned(
            top: 10, left: 10,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _resourceBoard(),
                  if (starving || lowWater || eventLabel != null) ...[
                    const SizedBox(height: 8),
                    _badgeRow(),
                  ],
                ],
              ),
            ),
          ),
          Positioned(
            top: 10, right: 10,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _dayPanel(),
                  const SizedBox(height: 8),
                  _controlRow(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sol-üst kaynak panosu ──────────────────────────────────────────────────

  Widget _resourceBoard() => AppPanel(
        width: 256,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Expanded(child: _ResCell(GameIconData.wood, const Color(0xFFD79A5B), stockpile.wood, woodInTransit)),
              Expanded(child: _ResCell(GameIconData.stone, const Color(0xFFB8B8B8), stockpile.stone, stoneInTransit)),
              Expanded(child: _ResCell(GameIconData.iron, const Color(0xFFCED2EC), stockpile.iron, ironInTransit)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _ResCell(GameIconData.coal, const Color(0xFF9A9A9A), stockpile.coal, coalInTransit)),
              Expanded(child: _ResCell(GameIconData.wheat, AppUi.sage, stockpile.food, foodInTransit)),
              Expanded(child: _ResCell(GameIconData.coin, AppUi.gold, stockpile.gold, 0)),
            ]),
            if (stockpile.honey > 0 || stockpile.reed > 0) ...[
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: stockpile.honey > 0
                      ? _ResCell(GameIconData.honey, const Color(0xFFE7B23A), stockpile.honey, 0)
                      : const SizedBox(),
                ),
                Expanded(
                  child: stockpile.reed > 0
                      ? _ResCell(GameIconData.reed, const Color(0xFF8FB36A), stockpile.reed, 0)
                      : const SizedBox(),
                ),
                const Expanded(child: SizedBox()),
              ]),
            ],
            const AppDivider(),
            _populationRow(),
            const SizedBox(height: 8),
            _moraleMeter(),
          ],
        ),
      );

  Widget _populationRow() {
    final workers = <(GameIconData, int, Color)>[
      (GameIconData.wheat, farmerCount, AppUi.sage),
      (GameIconData.axe, woodcutterCount, const Color(0xFFE7B374)),
      (GameIconData.pickaxe, minerCount, const Color(0xFFC5CDE9)),
      (GameIconData.fish, fisherCount, AppUi.info),
    ].where((s) => s.$2 > 0).toList();

    return Row(children: [
      GameIcon(GameIconData.people, size: 15, color: AppUi.textMid),
      const SizedBox(width: 7),
      Text('$_totalPop', style: AppUi.number.copyWith(fontSize: 16)),
      const SizedBox(width: 5),
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text('köylü', style: AppUi.label.copyWith(fontSize: 9, letterSpacing: 0.8)),
      ),
      const Spacer(),
      for (final (icon, n, col) in workers)
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GameIcon(icon, size: 12, color: col),
              const SizedBox(width: 3),
              Text('$n', style: AppUi.number.copyWith(fontSize: 12, color: col)),
            ],
          ),
        ),
    ]);
  }

  Widget _moraleMeter() {
    final c = _moraleColor;
    return AppStatBar(
      label: 'MORAL',
      value: morale.clamp(0.0, 1.0),
      trailing: '${(morale * 100).round()}%',
      color: c,
      labelWidth: 50,
    );
  }

  // ── Sağ-üst saat panosu ────────────────────────────────────────────────────

  Widget _dayPanel() => AppPanel(
        width: 146,
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('GÜN $dayCount',
                style: AppUi.label.copyWith(
                    color: AppUi.accentSoft, fontSize: 10, letterSpacing: 2.4)),
            const SizedBox(height: 4),
            Text(_clockText,
                style: AppUi.number.copyWith(fontSize: 28, letterSpacing: 1.5)),
            const SizedBox(height: 5),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              GameIcon(_weatherIcon, size: 13, color: AppUi.textMid),
              const SizedBox(width: 6),
              Text(_weatherLabel,
                  style: AppUi.body.copyWith(fontSize: 11, color: AppUi.textMid)),
            ]),
          ],
        ),
      );

  // ── Kontroller ──────────────────────────────────────────────────────────────

  Widget _controlRow() => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _speedButton(),
          const SizedBox(width: 6),
          AppIconButton(icon: GameIconData.dice, onTap: onTriggerEvent),
          const SizedBox(width: 6),
          AppIconButton(icon: GameIconData.bolt, onTap: onToggleGod, active: godMode),
          const SizedBox(width: 6),
          AppIconButton(icon: GameIconData.map, onTap: onNewMap),
          const SizedBox(width: 6),
          AppIconButton(icon: GameIconData.bug, onTap: onToggleDev),
        ],
      );

  Widget _speedButton() {
    final paused = timeScale <= 0.01;
    final boosted = timeScale > 1.01;
    if (paused) {
      return AppIconButton(
          icon: GameIconData.pause,
          onTap: onCycleSpeed,
          active: true,
          tint: AppUi.rust);
    }
    final label = timeScale <= 1.01 ? '1×' : timeScale <= 2.01 ? '2×' : '4×';
    return AppIconButton(
      icon: GameIconData.speed,
      text: label,
      onTap: onCycleSpeed,
      active: boosted,
    );
  }

  // ── Uyarı rozetleri ──────────────────────────────────────────────────────

  Widget _badgeRow() => Wrap(spacing: 6, runSpacing: 5, children: [
        if (starving)
          const AppChip(icon: GameIconData.wheat, label: 'AÇLIK', color: AppUi.rust, solid: true),
        if (lowWater)
          const AppChip(icon: GameIconData.drop, label: 'SUSUZ', color: AppUi.rust, solid: true),
        if (eventLabel != null && effectTimeLeft > 0)
          _effectChip()
        else if (eventLabel != null)
          AppChip(label: eventLabel!.toUpperCase(), color: AppUi.accent, solid: true),
      ]);

  Widget _effectChip() {
    final color = effectPositive ? AppUi.sage : AppUi.rust;
    final progress =
        effectDuration <= 0 ? 0.0 : (effectTimeLeft / effectDuration).clamp(0.0, 1.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppChip(label: eventLabel!.toUpperCase(), color: color, solid: true),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: SizedBox(
            width: 96,
            height: 3,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: progress,
                child: Container(color: color),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Kaynak hücresi ──────────────────────────────────────────────────────────

class _ResCell extends StatelessWidget {
  final GameIconData icon;
  final Color color;
  final int stored;
  final int transit;
  const _ResCell(this.icon, this.color, this.stored, this.transit);

  @override
  Widget build(BuildContext context) {
    final empty = stored == 0 && transit == 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Opacity(
          opacity: empty ? 0.5 : 1.0,
          child: GameIcon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 6),
        Text('$stored',
            style: AppUi.number.copyWith(
                fontSize: 16,
                color: empty ? AppUi.textLo : AppUi.textHi)),
        if (transit > 0)
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 5),
            child: Text('+$transit',
                style: AppUi.number.copyWith(
                    fontSize: 9, color: AppUi.accentSoft)),
          ),
      ],
    );
  }
}
