import 'package:flutter/material.dart';
import '../core/resources.dart';
import 'app_ui.dart';

/// Oyun HUD'u — sol-üst kaynak/nüfus panosu + sağ-üst saat panosu + kontroller.
/// Modern koyu app_ui dili: temiz paneller, vektör ikonlar, animasyonlu moral.
class GameHUD extends StatelessWidget {
  final ResourceBundle stockpile;
  final int woodInTransit, stoneInTransit, ironInTransit, coalInTransit, foodInTransit;

  final int villagerCount, farmerCount, woodcutterCount, minerCount, fisherCount, builderCount, busyBuilders;
  final int shepherdCount, floristCount, homelessCount;

  final double timeOfDay, rainIntensity, dayLight;
  final int dayCount;

  final int buildingCount, pendingOrderCount;

  final double morale;
  final bool lowWater, starving;
  final String? eventLabel;

  /// Stok kapasitesi (wood/stone/iron/coal/food tavanı). Hücre tavana
  /// ulaşınca "dolu" uyarısı gösterilir.
  final int stockCapacity;
  /// 0..1 nabız (sahneden _time türevi) — dolu kaynak hücresi bununla yanar.
  final double fullPulse;
  /// Moral katkı kırılımı (etiket, delta) — moral barı hover tooltip'i.
  final List<(String, double)> moraleBreakdown;
  /// 'evsiz' sayısına tıklanınca evsiz köylüleri kısa süre vurgular.
  final VoidCallback? onHighlightHomeless;

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
    this.shepherdCount = 0,
    this.floristCount = 0,
    this.homelessCount = 0,
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
    this.stockCapacity = 1 << 30,
    this.fullPulse = 0,
    this.moraleBreakdown = const [],
    this.onHighlightHomeless,
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
      villagerCount + farmerCount + woodcutterCount + minerCount +
      fisherCount + builderCount + shepherdCount + floristCount;

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
              Expanded(child: _ResCell(GameIconData.wood, const Color(0xFFD79A5B), stockpile.wood, woodInTransit, capacity: stockCapacity, pulse: fullPulse)),
              Expanded(child: _ResCell(GameIconData.stone, const Color(0xFFB8B8B8), stockpile.stone, stoneInTransit, capacity: stockCapacity, pulse: fullPulse)),
              Expanded(child: _ResCell(GameIconData.iron, const Color(0xFFCED2EC), stockpile.iron, ironInTransit, capacity: stockCapacity, pulse: fullPulse)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _ResCell(GameIconData.coal, const Color(0xFF9A9A9A), stockpile.coal, coalInTransit, capacity: stockCapacity, pulse: fullPulse)),
              Expanded(child: _ResCell(GameIconData.wheat, AppUi.sage, stockpile.food, foodInTransit, capacity: stockCapacity, pulse: fullPulse)),
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

  // Profession palette — tooltip + olası inline kullanım.
  static const _farmerC = AppUi.sage;
  static const _woodC   = Color(0xFFE7B374);
  static const _minerC  = Color(0xFFC5CDE9);
  static const _fisherC = AppUi.info;
  static const _shepC   = Color(0xFFCDB79A);
  static const _floriC  = Color(0xFFE08AB0);
  static const _buildC  = Color(0xFFD8C088);

  Widget _populationRow() {
    return Tooltip(
      richMessage: _professionBreakdown(),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      margin: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        color: const Color(0xF21A1B22),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: Row(children: [
        // Köylü — toplam nüfus.
        GameIcon(GameIconData.people, size: 15, color: AppUi.textMid),
        const SizedBox(width: 7),
        Text('$_totalPop', style: AppUi.number.copyWith(fontSize: 16)),
        const SizedBox(width: 5),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text('köylü',
              style: AppUi.label.copyWith(fontSize: 9, letterSpacing: 0.8)),
        ),
        const SizedBox(width: 16),
        // Evsiz — yan yana; >0 ise vurgulu (rust) + tıklanınca köyde vurgulanır.
        GestureDetector(
          onTap: homelessCount > 0 ? onHighlightHomeless : null,
          behavior: HitTestBehavior.opaque,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            GameIcon(GameIconData.home, size: 14,
                color: homelessCount > 0 ? AppUi.rust : AppUi.textMid),
            const SizedBox(width: 7),
            Text('$homelessCount',
                style: AppUi.number.copyWith(
                    fontSize: 16,
                    color: homelessCount > 0 ? AppUi.rust : AppUi.textMid)),
            const SizedBox(width: 5),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('evsiz',
                  style: AppUi.label.copyWith(fontSize: 9, letterSpacing: 0.8)),
            ),
          ]),
        ),
        const Spacer(),
        // İmleç ipucu — üstüne gelince meslek dağılımı.
        GameIcon(GameIconData.chevron, size: 11, color: AppUi.textMid),
      ]),
    );
  }

  // Hover tooltip — hangi mesleğe kaç köylü dağıtılmış (+ serbest + evsiz).
  InlineSpan _professionBreakdown() {
    final rows = <(String, int, Color)>[
      ('Çiftçi',   farmerCount,     _farmerC),
      ('Oduncu',   woodcutterCount, _woodC),
      ('Madenci',  minerCount,      _minerC),
      ('Balıkçı',  fisherCount,     _fisherC),
      ('Çoban',    shepherdCount,   _shepC),
      ('Çiçekçi',  floristCount,    _floriC),
      ('İnşaatçı', builderCount,    _buildC),
    ].where((r) => r.$2 > 0).toList();

    final base = AppUi.body.copyWith(fontSize: 12, height: 1.45);
    final children = <InlineSpan>[
      TextSpan(
        text: 'Meslek dağılımı\n',
        style: AppUi.label.copyWith(
            fontSize: 10, letterSpacing: 1.4, color: AppUi.accentSoft),
      ),
    ];
    if (rows.isEmpty) {
      children.add(TextSpan(
          text: 'Henüz meslek yok\n',
          style: base.copyWith(color: AppUi.textMid)));
    }
    for (final (name, n, col) in rows) {
      children.add(TextSpan(
          text: '$name  ', style: base.copyWith(color: AppUi.textMid)));
      children.add(TextSpan(
          text: '$n\n',
          style: base.copyWith(color: col, fontWeight: FontWeight.w700)));
    }
    // Serbest (mesleği olmayan köylü) + evsiz alt çizgi.
    children.add(TextSpan(
        text: '─────\n', style: base.copyWith(color: const Color(0x33FFFFFF))));
    children.add(TextSpan(
        text: 'Serbest  ', style: base.copyWith(color: AppUi.textMid)));
    children.add(TextSpan(
        text: '$villagerCount\n',
        style: base.copyWith(color: AppUi.textHi, fontWeight: FontWeight.w700)));
    children.add(TextSpan(
        text: 'Evsiz  ', style: base.copyWith(color: AppUi.textMid)));
    children.add(TextSpan(
        text: '$homelessCount',
        style: base.copyWith(
            color: homelessCount > 0 ? AppUi.rust : AppUi.textHi,
            fontWeight: FontWeight.w700)));
    return TextSpan(children: children);
  }

  Widget _moraleMeter() {
    final c = _moraleColor;
    final bar = AppStatBar(
      label: 'MORAL',
      value: morale.clamp(0.0, 1.0),
      trailing: '${(morale * 100).round()}%',
      color: c,
      labelWidth: 50,
    );
    if (moraleBreakdown.isEmpty) return bar;
    return Tooltip(
      richMessage: _moraleTooltip(),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xF21A1B22),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: bar,
    );
  }

  // Moral neden bu seviyede? Katkı kırılımı (taban + olay + politika + ...).
  InlineSpan _moraleTooltip() {
    final base = AppUi.body.copyWith(fontSize: 12, height: 1.45);
    final children = <InlineSpan>[
      TextSpan(
        text: 'Moral neden böyle\n',
        style: AppUi.label.copyWith(
            fontSize: 10, letterSpacing: 1.4, color: AppUi.accentSoft),
      ),
    ];
    for (final (label, delta) in moraleBreakdown) {
      final isBase = delta >= 0.49 && label == 'Taban';
      final col = isBase
          ? AppUi.textMid
          : (delta >= 0 ? AppUi.sage : AppUi.rust);
      final sign = isBase
          ? ''
          : (delta >= 0 ? '+' : '−');
      final pct = isBase
          ? '${(delta * 100).round()}%'
          : '$sign${(delta.abs() * 100).round()}%';
      children.add(TextSpan(
          text: '$label  ', style: base.copyWith(color: AppUi.textMid)));
      children.add(TextSpan(
          text: '$pct\n',
          style: base.copyWith(color: col, fontWeight: FontWeight.w700)));
    }
    children.add(TextSpan(
        text: '─────\n', style: base.copyWith(color: const Color(0x33FFFFFF))));
    children.add(TextSpan(
        text: 'Toplam  ', style: base.copyWith(color: AppUi.textMid)));
    children.add(TextSpan(
        text: '${(morale * 100).round()}%',
        style: base.copyWith(color: _moraleColor, fontWeight: FontWeight.w700)));
    return TextSpan(children: children);
  }

  // ── Sağ-üst saat panosu ────────────────────────────────────────────────────

  // Saat panosu hover ipucu — günün evresi + köyün ne yapacağı.
  String get _timeHint {
    final t = timeOfDay;
    final (phase, flavor) = switch (t) {
      < 0.22 => ('Gece', 'Köy uyuyor — ateş başı sıcak'),
      < 0.30 => ('Şafak söküyor', 'Köylüler birazdan uyanır'),
      < 0.45 => ('Sabah', 'İş başı — pazar canlanır'),
      < 0.55 => ('Öğle', 'Günün en aydınlık vakti'),
      < 0.68 => ('Öğleden sonra', 'İşler sürüyor'),
      < 0.78 => ('Akşam yaklaşıyor', 'Köy ateş başına toplanmaya başlar'),
      < 0.82 => ('Gün batıyor', 'Herkes yavaşça yuvasına/yatağına döner'),
      _      => ('Gece', 'Köy uyuyor — ateş başı sıcak'),
    };
    return 'Gün $dayCount · $phase\n$flavor';
  }

  Widget _dayPanelInner() => AppPanel(
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

  Widget _dayPanel() => Tooltip(
        message: _timeHint,
        textStyle: AppUi.body.copyWith(fontSize: 12, height: 1.4, color: AppUi.textHi),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xF21A1B22),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0x33FFFFFF)),
        ),
        child: _dayPanelInner(),
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
  /// Tavan (null = sınırsız: bal/saz/altın). stored>=capacity → "dolu" uyarısı.
  final int? capacity;
  /// 0..1 nabız — dolu hücrede kehribar yanıp söner.
  final double pulse;
  const _ResCell(this.icon, this.color, this.stored, this.transit,
      {this.capacity, this.pulse = 0});

  static const _amber = Color(0xFFE8A23A);

  @override
  Widget build(BuildContext context) {
    final empty = stored == 0 && transit == 0;
    final full = capacity != null && stored >= capacity!;
    // Dolu → kehribar; nabızla parlaklığı değişir (üretim boşa gidiyor uyarısı).
    final numColor = full
        ? Color.lerp(_amber, const Color(0xFFFFE0A0), pulse)!
        : (empty ? AppUi.textLo : AppUi.textHi);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Opacity(
          opacity: empty ? 0.5 : 1.0,
          child: GameIcon(icon, size: 16, color: full ? _amber : color),
        ),
        const SizedBox(width: 6),
        Text('$stored',
            style: AppUi.number.copyWith(fontSize: 16, color: numColor)),
        if (full)
          Padding(
            padding: const EdgeInsets.only(left: 3, bottom: 5),
            child: Text('DOLU',
                style: AppUi.label.copyWith(
                    fontSize: 7.5,
                    letterSpacing: 0.5,
                    color: _amber.withValues(alpha: 0.6 + 0.4 * pulse))),
          )
        else if (transit > 0)
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
