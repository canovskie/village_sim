import 'package:flutter/material.dart';
import '../core/resources.dart';
import 'cozy_theme.dart';

/// Diegetic "köy panosu" HUD'u — sol-üst ahşap kaynak panosu (çakılı çiviler,
/// damarlı ahşap, oyma sayılar) + sağ-üst ahşap saat tabelası + altta deri
/// sekme kontrolleri. Modern cam kalmadı; tüm dil el yapımı.
class GameHUD extends StatelessWidget {
  // Ekonomi
  final ResourceBundle stockpile;
  final int woodInTransit, stoneInTransit, ironInTransit, coalInTransit, foodInTransit;

  // Nüfus & işçiler
  final int villagerCount, farmerCount, woodcutterCount, minerCount, fisherCount, builderCount, busyBuilders;

  // Saat & hava
  final double timeOfDay, rainIntensity, dayLight;
  final int dayCount;

  // Bina
  final int buildingCount, pendingOrderCount;

  // Köy sağlığı
  final double morale;
  final bool   lowWater, starving;
  final String? eventLabel;

  // Kontroller
  final bool godMode;
  final VoidCallback onNewMap, onToggleGod, onTriggerEvent;

  final double effectTimeLeft;
  final double effectDuration;
  final bool   effectPositive;

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
    this.effectTimeLeft  = 0,
    this.effectDuration  = 1,
    this.effectPositive  = true,
    required this.onToggleDev,
  });

  // ── Türetilenler ──────────────────────────────────────────────────────────

  String get _clockText {
    final h = (timeOfDay * 24).floor() % 24;
    final m = ((timeOfDay * 24 - h) * 60).floor();
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  String get _weatherIcon {
    if (rainIntensity > 0.5) return '☔';
    if (rainIntensity > 0.0) return '🌧';
    if (dayLight > 0.7) return '☀';
    if (dayLight > 0.3) return '🌅';
    return '🌙';
  }

  String get _weatherLabel {
    if (rainIntensity > 0.5) return 'sağanak';
    if (rainIntensity > 0.0) return 'yağmur';
    if (dayLight > 0.7) return 'açık';
    if (dayLight > 0.3) return 'alacakaranlık';
    return 'gece';
  }

  Color get _moraleColor => morale >= 0.6
      ? CozyUi.sage
      : morale >= 0.4
          ? CozyUi.emberSoft
          : CozyUi.rust;

  int get _totalPop =>
      villagerCount + farmerCount + woodcutterCount +
      minerCount + fisherCount + builderCount;

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          // Sol-üst köşe: ahşap kaynak panosu + uyarı rozetleri.
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
          // Sağ-üst köşe: ahşap saat tabelası + deri sekme kontrolleri.
          Positioned(
            top: 10, right: 10,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _dayPlank(),
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

  // ── Sol-üst: tek ahşap pano — kaynaklar + nüfus + moral şeridi ──────────────

  Widget _resourceBoard() => WoodPlankPanel(
        width: 248,
        padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 2×3 oyma kaynak ızgarası
            Row(children: [
              Expanded(child: CarvedResource(icon: ResourceKind.wood.icon,
                  stored: stockpile.wood,  transit: woodInTransit)),
              Expanded(child: CarvedResource(icon: ResourceKind.stone.icon,
                  stored: stockpile.stone, transit: stoneInTransit)),
              Expanded(child: CarvedResource(icon: ResourceKind.iron.icon,
                  stored: stockpile.iron,  transit: ironInTransit)),
            ]),
            const SizedBox(height: 9),
            Row(children: [
              Expanded(child: CarvedResource(icon: ResourceKind.coal.icon,
                  stored: stockpile.coal,  transit: coalInTransit)),
              Expanded(child: CarvedResource(icon: ResourceKind.food.icon,
                  stored: stockpile.food,  transit: foodInTransit)),
              Expanded(child: CarvedResource(icon: ResourceKind.gold.icon,
                  stored: stockpile.gold,  transit: 0, accent: true)),
            ]),
            const CozyDivider(),
            // Nüfus + işçiler + moral — sıkıştırılmış tek satır
            _populationRow(),
            const SizedBox(height: 6),
            _moraleMeter(),
          ],
        ),
      );

  Widget _populationRow() {
    final workers = <(String, int, Color)>[
      ('⚘', farmerCount, CozyUi.sage),
      ('⚒', woodcutterCount, const Color(0xFFE7B374)),
      ('⛏', minerCount, const Color(0xFFC5CDE9)),
      ('⚓', fisherCount, const Color(0xFF89CFE6)),
    ].where((s) => s.$2 > 0).toList();

    return Row(children: [
      const Text('👥', style: TextStyle(fontSize: 14)),
      const SizedBox(width: 6),
      Text('$_totalPop',
          style: CozyUi.carvedNumber.copyWith(fontSize: 16)),
      const SizedBox(width: 5),
      Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Text('köylü', style: CozyUi.carvedSmall.copyWith(fontSize: 10)),
      ),
      const Spacer(),
      for (final (icon, n, col) in workers)
        Padding(
          padding: const EdgeInsets.only(left: 7),
          child: Text('$icon$n',
              style: TextStyle(
                color: col,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
                shadows: const [
                  Shadow(color: Color(0xDD1A0E04), blurRadius: 0, offset: Offset(0, 1)),
                ],
              )),
        ),
    ]);
  }

  /// Moral göstergesi — oyma çerçeve + renkli alev şeridi.
  Widget _moraleMeter() {
    final c = _moraleColor;
    return Row(children: [
      Text('moral', style: CozyUi.carvedSmall.copyWith(fontSize: 10, letterSpacing: 1.4)),
      const SizedBox(width: 8),
      Expanded(
        child: Container(
          height: 9,
          decoration: BoxDecoration(
            color: const Color(0xFF1A0E04),
            borderRadius: BorderRadius.circular(2.5),
            border: Border.all(color: const Color(0xFF120804), width: 1),
            boxShadow: const [
              BoxShadow(color: Color(0x88000000), blurRadius: 1.5, offset: Offset(0, 1)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: morale.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      c.withValues(alpha: 0.75),
                      c,
                      Color.lerp(c, Colors.white, 0.40)!,
                    ]),
                    boxShadow: [
                      BoxShadow(color: c.withValues(alpha: 0.65), blurRadius: 5),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(width: 7),
      SizedBox(
        width: 36,
        child: Text(
          '${(morale * 100).round()}%',
          textAlign: TextAlign.right,
          style: CozyUi.carvedNumber.copyWith(color: c, fontSize: 12),
        ),
      ),
    ]);
  }

  // ── Sağ-üst: ahşap saat tabelası ─────────────────────────────────────────

  Widget _dayPlank() => WoodPlankPanel(
        width: 140,
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('GÜN $dayCount',
                style: CozyUi.carvedTitle.copyWith(
                    color: CozyUi.emberSoft, fontSize: 11, letterSpacing: 2.8)),
            const SizedBox(height: 4),
            Text(_clockText,
                style: CozyUi.carvedNumber.copyWith(
                    fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
            const SizedBox(height: 4),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(_weatherIcon, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 5),
              Text(_weatherLabel,
                  style: CozyUi.carvedSmall.copyWith(fontSize: 10, letterSpacing: 0.8)),
            ]),
          ],
        ),
      );

  // ── Kontrol satırı — küçük deri sekmeler ─────────────────────────────────

  Widget _controlRow() => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _speedButton(),
          const SizedBox(width: 6),
          _iconBtn('🎲', onTriggerEvent),
          const SizedBox(width: 6),
          _iconBtn('⚡', onToggleGod, active: godMode),
          const SizedBox(width: 6),
          _iconBtn('🗺', onNewMap),
          const SizedBox(width: 6),
          _iconBtn('🐞', onToggleDev),
        ],
      );

  Widget _speedButton() {
    final paused = timeScale <= 0.01;
    final boosted = timeScale > 1.01;
    final String label;
    if (paused) {
      label = '⏸';
    } else if (timeScale <= 1.01) {
      label = '1×';
    } else if (timeScale <= 2.01) {
      label = '2×';
    } else {
      label = '4×';
    }
    return LeatherButton(
      label: label,
      onTap: onCycleSpeed,
      active: paused || boosted,
      tint: paused ? CozyUi.rust : CozyUi.ember,
      height: 38,
      horizontalPadding: 12,
      fontSize: label.length > 1 ? 13 : 17,
    );
  }

  Widget _iconBtn(String icon, VoidCallback onTap, {bool active = false}) {
    return LeatherButton(
      label: icon,
      onTap: onTap,
      active: active,
      height: 38,
      horizontalPadding: 11,
      fontSize: 17,
    );
  }

  // ── Uyarı rozetleri ──────────────────────────────────────────────────────

  Widget _badgeRow() => Wrap(spacing: 6, runSpacing: 5, children: [
        if (starving) const WaxBadge(icon: '🍞', label: 'AÇLIK', color: CozyUi.rust),
        if (lowWater) const WaxBadge(icon: '💧', label: 'SUSUZ', color: CozyUi.rust),
        if (eventLabel != null && effectTimeLeft > 0)
          _effectChip()
        else if (eventLabel != null)
          WaxBadge(label: eventLabel!.toUpperCase(), color: CozyUi.ember),
      ]);

  /// Aktif etki — wax mühür + alt kenarında kalan süre şeridi.
  Widget _effectChip() {
    final color = effectPositive ? CozyUi.sage : CozyUi.rust;
    final progress = effectDuration <= 0
        ? 0.0
        : (effectTimeLeft / effectDuration).clamp(0.0, 1.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WaxBadge(label: eventLabel!.toUpperCase(), color: color),
        const SizedBox(height: 2),
        Container(
          height: 2,
          width: 90,
          color: const Color(0x55000000),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress,
            child: Container(color: color),
          ),
        ),
      ],
    );
  }
}
