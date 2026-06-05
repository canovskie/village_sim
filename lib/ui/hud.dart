import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../core/resources.dart';

/// Modern "buzlu cam" HUD. Ahşap/altın/monospace yok; yarı saydam blur'lu
/// paneller, saç-teli ışık kenar, temiz sans-serif tipografi (tabular rakamlar),
/// tek sıcak amber vurgu, yuvarlak köşeler, bol boşluk.
///
/// Yerleşim köşe-panel: sol-üst kaynak+köy, sağ-üst gün/saat madalyonu+kontroller.
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

  /// Aktif geçici efekt — eventLabel + kalan süre (saniye) + toplam süre.
  /// `effectTimeLeft > 0` ise mini progress chip gösterilir; aksi takdirde
  /// eventLabel düz badge olarak çizilir.
  final double effectTimeLeft;
  final double effectDuration;
  final bool   effectPositive;

  /// Geliştirici paneli aç/kapa.
  final VoidCallback onToggleDev;

  /// Aktif zaman çarpanı: 0.0 = duraklatılmış, 1.0/2.0/4.0 = oynat hızı.
  final double timeScale;
  /// Butona basıldıkça hız adımları arasında döndür (1×→2×→4×→pause→…).
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

  // ── Palet (modern, cool dark + amber accent) ────────────────────────────────
  static const _textHi  = Color(0xFFEDF0F4);
  static const _textMid = Color(0xFF98A2AE);
  static const _textLo  = Color(0xFF5C6471);
  static const _amber   = Color(0xFFE9A23B);
  static const _danger  = Color(0xFFE2603F);
  static const _success = Color(0xFF6FC07A);
  static const _line    = Color(0x1FFFFFFF);

  static const _num = [ui.FontFeature.tabularFigures()];

  // ── Türetilenler ────────────────────────────────────────────────────────────
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
      ? _success
      : morale >= 0.4
          ? _amber
          : _danger;

  int get _totalPop =>
      villagerCount + farmerCount + woodcutterCount +
      minerCount + fisherCount + builderCount;

  // ── Yerleşim ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 10, left: 10,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                child: _mainPanel(),
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
                    const SizedBox(height: 10),
                    _controlRow(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Sol-üst: kaynak + köy (tek cam panel, hairline ayraçlı) ──────────────────
  Widget _mainPanel() => _glass(
        width: 232,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              _resCell(ResourceKind.wood, stockpile.wood, woodInTransit),
              _resCell(ResourceKind.stone, stockpile.stone, stoneInTransit),
              _resCell(ResourceKind.iron, stockpile.iron, ironInTransit),
            ]),
            const SizedBox(height: 9),
            Row(children: [
              _resCell(ResourceKind.coal, stockpile.coal, coalInTransit),
              _resCell(ResourceKind.food, stockpile.food, foodInTransit),
              _resCell(ResourceKind.gold, stockpile.gold, 0, accent: true),
            ]),
            _divider(),
            // Nüfus + işçiler
            Row(children: [
              const Text('👥', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 6),
              Text('$_totalPop',
                  style: const TextStyle(
                      color: _textHi, fontSize: 16, fontWeight: FontWeight.w700,
                      fontFeatures: _num, height: 1.0)),
              const SizedBox(width: 4),
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Text('köylü', style: TextStyle(color: _textMid, fontSize: 10)),
              ),
              const Spacer(),
              _workers(),
            ]),
            const SizedBox(height: 9),
            _moraleMeter(),
            if (lowWater || starving || eventLabel != null) ...[
              const SizedBox(height: 9),
              Wrap(spacing: 5, runSpacing: 5, children: [
                if (starving) _badge('🍞', 'Açlık', _danger),
                if (lowWater) _badge('💧', 'Susuz', _danger),
                if (eventLabel != null && effectTimeLeft > 0)
                  _effectChip()
                else if (eventLabel != null)
                  _badge(null, eventLabel!, _amber),
              ]),
            ],
          ],
        ),
      );

  // ── Sağ-üst: gün / saat / hava ───────────────────────────────────────────────
  Widget _dayPanel() => _glass(
        width: 128,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('GÜN $dayCount',
                style: const TextStyle(
                    color: _amber, fontSize: 9.5, fontWeight: FontWeight.w700,
                    letterSpacing: 2.0, fontFeatures: _num)),
            const SizedBox(height: 3),
            Text(_clockText,
                style: const TextStyle(
                    color: _textHi, fontSize: 26, fontWeight: FontWeight.w300,
                    letterSpacing: 1.0, fontFeatures: _num, height: 1.0)),
            const SizedBox(height: 5),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(_weatherIcon, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 5),
              Text(_weatherLabel,
                  style: const TextStyle(color: _textMid, fontSize: 10.5)),
            ]),
          ],
        ),
      );

  Widget _controlRow() => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _speedButton(),
          const SizedBox(width: 7),
          _iconButton('🎲', onTriggerEvent),
          const SizedBox(width: 7),
          _iconButton('⚡', onToggleGod, active: godMode),
          const SizedBox(width: 7),
          _iconButton('🗺', onNewMap),
          const SizedBox(width: 7),
          _iconButton('🐞', onToggleDev),
        ],
      );

  /// Zaman yönetimi butonu — hıza göre simge değişir, pause'da kırmızı vurgu.
  Widget _speedButton() {
    final paused = timeScale <= 0.01;
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
    final highlight = paused || timeScale > 1.01;
    return GestureDetector(
      onTap: onCycleSpeed,
      child: Container(
        width: 34, height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: paused
              ? _danger.withValues(alpha: 0.28)
              : (highlight
                  ? _amber.withValues(alpha: 0.30)
                  : const Color(0xCC12161D)),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
              color: paused
                  ? _danger.withValues(alpha: 0.75)
                  : (highlight ? _amber.withValues(alpha: 0.7) : _line),
              width: 1),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: label.length > 1 ? 11 : 14,
              fontWeight: FontWeight.w700,
              color: paused ? _danger : _textHi,
              fontFeatures: _num,
            )),
      ),
    );
  }

  // ── Parçalar ─────────────────────────────────────────────────────────────────

  Widget _resCell(ResourceKind kind, int stored, int transit, {bool accent = false}) {
    final empty = stored == 0 && transit == 0;
    final valueColor = empty ? _textLo : (accent ? _amber : _textHi);
    return Expanded(
      child: Tooltip(
        message: '${kind.label}\nStokta: $stored'
            '${transit > 0 ? '\nYolda: $transit' : ''}',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: empty ? 0.4 : 1.0,
              child: Text(kind.icon, style: const TextStyle(fontSize: 13)),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text('$stored',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: valueColor, fontSize: 13, fontWeight: FontWeight.w700,
                      fontFeatures: _num)),
            ),
            if (transit > 0)
              Padding(
                padding: const EdgeInsets.only(left: 1, bottom: 4),
                child: Text('+$transit',
                    style: const TextStyle(
                        color: _textMid, fontSize: 8, fontWeight: FontWeight.w600,
                        fontFeatures: _num)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _workers() {
    final stats = <(String, int, Color)>[
      ('⚘', farmerCount, _success),
      ('⚒', woodcutterCount, const Color(0xFFD79A5B)),
      ('⛏', minerCount, const Color(0xFFAEB6E0)),
      ('⚓', fisherCount, const Color(0xFF5FB6D6)),
    ].where((s) => s.$2 > 0).toList();
    if (stats.isEmpty) return const SizedBox.shrink();
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (final (icon, n, col) in stats)
        Padding(
          padding: const EdgeInsets.only(left: 7),
          child: Text('$icon$n',
              style: TextStyle(
                  color: col, fontSize: 11, fontWeight: FontWeight.w600,
                  fontFeatures: _num)),
        ),
    ]);
  }

  Widget _moraleMeter() {
    final c = _moraleColor;
    return Row(children: [
      const Text('moral',
          style: TextStyle(
              color: _textMid, fontSize: 9.5, fontWeight: FontWeight.w600,
              letterSpacing: 0.8)),
      const SizedBox(width: 8),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Container(
            height: 6,
            color: const Color(0x22FFFFFF),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: morale.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [c.withValues(alpha: 0.75), c]),
                    boxShadow: [
                      BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 5),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),
      Text('${(morale * 100).round()}%',
          style: TextStyle(
              color: c, fontSize: 11, fontWeight: FontWeight.w700, fontFeatures: _num)),
    ]);
  }

  Widget _badge(String? icon, String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.45), width: 1),
        ),
        child: Text(icon == null ? label : '$icon $label',
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w700)),
      );

  /// Aktif geçici etki chip'i — label + alt kenarında kalan süre çubuğu.
  /// Pozitif olaylar yeşil, negatif kırmızı tonda.
  Widget _effectChip() {
    final color = effectPositive ? _success : _danger;
    final progress = effectDuration <= 0
        ? 0.0
        : (effectTimeLeft / effectDuration).clamp(0.0, 1.0);
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 3, 8, 2),
            child: Text(eventLabel!,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                )),
          ),
          // Countdown bar — chip'in alt kenarı boyunca.
          Container(
            height: 2,
            width: 80,
            color: const Color(0x33000000),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: Container(color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconButton(String icon, VoidCallback onTap, {bool active = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34, height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active
              ? _amber.withValues(alpha: 0.30)
              : const Color(0xCC12161D),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
              color: active ? _amber.withValues(alpha: 0.7) : _line, width: 1),
        ),
        child: Opacity(
          opacity: active ? 1.0 : 0.92,
          child: Text(icon, style: const TextStyle(fontSize: 14)),
        ),
      ),
    );
  }

  Widget _divider() => Container(
        height: 1,
        margin: const EdgeInsets.symmetric(vertical: 10),
        color: _line,
      );

  /// "Cam" panel: yarı saydam koyu gradyan + saç-teli ışık kenar + gölge.
  /// Canlı BackdropFilter blur kullanmaz — her frame yeniden blur hesaplamak
  /// (arkadaki oyun sürekli değiştiği için cache'lenemez) çok pahalıdır.
  Widget _glass({required Widget child, required double width, EdgeInsets? padding}) {
    return Container(
      width: width,
      padding: padding ?? const EdgeInsets.fromLTRB(14, 12, 14, 13),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xCC161C26), Color(0xB30A0E14)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _line, width: 1),
        boxShadow: const [
          BoxShadow(color: Color(0x55000000), blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: child,
    );
  }
}
