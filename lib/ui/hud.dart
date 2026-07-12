import 'package:flutter/material.dart';
import '../core/resources.dart';
import '../world/season.dart';
import 'app_ui.dart';

/// Oyun HUD'u — Manor Lords çıtası: çerçevesiz, ferah ince üst şerit.
/// Kutu YOK; üstte aşağı solan okunabilirlik scrim'i, tek satır kaynak/nüfus/
/// moral solda, saat/mevsim sağda, ghost kontroller en sağda. Köşeler/dünya açık.
class GameHUD extends StatelessWidget {
  final ResourceBundle stockpile;
  final int woodInTransit, stoneInTransit, ironInTransit, coalInTransit, foodInTransit;

  final int villagerCount, farmerCount, woodcutterCount, minerCount, fisherCount, builderCount, busyBuilders;
  final int shepherdCount, floristCount, homelessCount;

  final double timeOfDay, rainIntensity, dayLight;
  final int dayCount;
  final Season season;
  final double seasonProgress;

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

  /// Oyun içi hızlı sessiz toggle — ayarlara girmeden tüm sesi kıs/aç.
  final bool muted;
  final VoidCallback onToggleMute;

  /// Köy Nüfus Defteri (istatistik) modalını açar — HUD'daki nüfus butonu.
  final VoidCallback? onOpenRoster;

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
    required this.season,
    this.seasonProgress = 0,
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
    required this.muted,
    required this.onToggleMute,
    this.onOpenRoster,
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

  Color get _moraleColor => morale >= 0.6
      ? AppUi.sage
      : morale >= 0.4
          ? AppUi.accentSoft
          : AppUi.rust;

  int get _totalPop =>
      villagerCount + farmerCount + woodcutterCount + minerCount +
      fisherCount + builderCount + shepherdCount + floristCount;

  // Tüm HUD tooltip'leri için ortak rafine kutu (palete uyumlu, eski bluish yok).
  static final BoxDecoration _tipDeco = BoxDecoration(
    color: const Color(0xF2100E0B),
    borderRadius: BorderRadius.circular(10),
    border: Border.all(color: AppUi.line),
    boxShadow: AppUi.softShadow,
  );
  static const EdgeInsets _tipPad =
      EdgeInsets.symmetric(horizontal: 12, vertical: 9);

  // ── Build: çerçevesiz ince üst şerit ────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          // Üst okunabilirlik scrim'i — KUTU DEĞİL: aşağı doğru solan karartma,
          // parlak gündüz gökyüzünde de metin/ikon okunur kalsın.
          Positioned(
            top: 0, left: 0, right: 0,
            child: IgnorePointer(
              child: Container(
                height: 74,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    // İçeriği örtecek kadar koyu, sonra hızla erir — karanlık
                    // bant değil, sadece okunabilirlik dokunuşu.
                    colors: [Color(0x9E000000), Color(0x52000000), Color(0x00000000)],
                    stops: [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
          ),
          // Orta üst: gök şeridi — güneş ile ay düz bir hat üzerinde birbirini
          // kovalar (yarım gün arayla). Tıklanmaz, sadece günün nabzı.
          Positioned(
            top: 10, left: 0, right: 0,
            child: IgnorePointer(
              child: Center(
                child: _CelestialTrack(
                  timeOfDay: timeOfDay,
                  dayLight: dayLight,
                  pulse: fullPulse,
                ),
              ),
            ),
          ),
          // Şerit içeriği — tek satır, çerçevesiz.
          Positioned(
            top: 8, left: 16, right: 14,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Dar pencerede taşma şeridi yerine sessizce kırp.
                Flexible(
                  child: ClipRect(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const NeverScrollableScrollPhysics(),
                      child: _leftCluster(),
                    ),
                  ),
                ),
                _rightCluster(),
              ],
            ),
          ),
          // Sol-alt: uyarı rozetleri (açlık/susuz/olay) — şeridin hemen altında.
          if (starving || lowWater || eventLabel != null)
            Positioned(top: 56, left: 16, child: _badgeRow()),
        ],
      ),
    );
  }

  // ── Sol küme: kaynaklar · nüfus · moral ─────────────────────────────────────

  Widget _leftCluster() => Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _resources(),
          _sep(),
          _popInline(),
          _sep(),
          _moraleInline(),
        ],
      );

  Widget _sep() => Container(
        width: 1,
        height: 18,
        margin: const EdgeInsets.symmetric(horizontal: 11),
        color: const Color(0x1AFFFFFF),
      );

  Widget _resources() => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _res(GameIconData.wood, const Color(0xFFD79A5B), stockpile.wood, woodInTransit, capped: true),
          _res(GameIconData.stone, const Color(0xFFC0C0C0), stockpile.stone, stoneInTransit, capped: true),
          _res(GameIconData.iron, const Color(0xFFCED2EC), stockpile.iron, ironInTransit, capped: true),
          _res(GameIconData.coal, const Color(0xFFA6A6A6), stockpile.coal, coalInTransit, capped: true),
          _res(GameIconData.wheat, AppUi.sage, stockpile.food, foodInTransit, capped: true),
          _res(GameIconData.coin, AppUi.gold, stockpile.gold, 0),
          if (stockpile.honey > 0)
            _res(GameIconData.honey, const Color(0xFFE7B23A), stockpile.honey, 0),
          if (stockpile.reed > 0)
            _res(GameIconData.reed, const Color(0xFF8FB36A), stockpile.reed, 0),
        ],
      );

  static const _amber = Color(0xFFE8A23A);

  // Tek kaynak: ikon + sayı (+taşımadaki). Tavan dolunca kehribar + nabız.
  Widget _res(GameIconData icon, Color color, int stored, int transit,
      {bool capped = false}) {
    final empty = stored == 0 && transit == 0;
    final full = capped && stored >= stockCapacity;
    final iconColor = full ? _amber : color;
    final numColor = full
        ? Color.lerp(_amber, const Color(0xFFFFE0A0), fullPulse)!
        : (empty ? AppUi.textLo : AppUi.textHi);
    return Padding(
      padding: const EdgeInsets.only(right: 15),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GameIcon(icon,
              size: 16,
              color: empty ? iconColor.withValues(alpha: 0.45) : iconColor),
          const SizedBox(width: 5),
          Text('$stored',
              style: AppUi.number.copyWith(fontSize: 15.5, color: numColor)),
          if (transit > 0)
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 5),
              child: Text('+$transit',
                  style: AppUi.number.copyWith(
                      fontSize: 9, color: AppUi.accentSoft)),
            ),
        ],
      ),
    );
  }

  // ── Nüfus (inline) — hover'da meslek dağılımı ──────────────────────────────

  // Profession palette — tooltip kırılımı.
  static const _farmerC = AppUi.sage;
  static const _woodC   = Color(0xFFE7B374);
  static const _minerC  = Color(0xFFC5CDE9);
  static const _fisherC = AppUi.info;
  static const _shepC   = Color(0xFFCDB79A);
  static const _floriC  = Color(0xFFE08AB0);
  static const _buildC  = Color(0xFFD8C088);

  Widget _popInline() {
    return Tooltip(
      richMessage: _professionBreakdown(),
      padding: _tipPad,
      margin: const EdgeInsets.only(left: 12),
      decoration: _tipDeco,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GameIcon(GameIconData.people, size: 16, color: AppUi.textMid),
          const SizedBox(width: 6),
          Text('$_totalPop', style: AppUi.number.copyWith(fontSize: 15.5)),
          if (homelessCount > 0) ...[
            const SizedBox(width: 13),
            GestureDetector(
              onTap: onHighlightHomeless,
              behavior: HitTestBehavior.opaque,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                GameIcon(GameIconData.home, size: 15, color: AppUi.rust),
                const SizedBox(width: 5),
                Text('$homelessCount',
                    style: AppUi.number
                        .copyWith(fontSize: 15.5, color: AppUi.rust)),
              ]),
            ),
          ],
          const SizedBox(width: 7),
          GameIcon(GameIconData.chevron, size: 11, color: AppUi.textLo),
        ],
      ),
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

  // ── Moral (inline) — kalp + ince çubuk + % ─────────────────────────────────

  Widget _moraleInline() {
    final c = _moraleColor;
    final m = morale.clamp(0.0, 1.0);
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GameIcon(GameIconData.heart, size: 15, color: c),
        const SizedBox(width: 7),
        Container(
          width: 58,
          height: 6,
          decoration: BoxDecoration(
            color: const Color(0x40000000),
            borderRadius: BorderRadius.circular(4),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: m),
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOutCubic,
                builder: (_, v, _) => FractionallySizedBox(
                  widthFactor: v,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        c.withValues(alpha: 0.8),
                        Color.lerp(c, Colors.white, 0.25)!,
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 7),
        Text('${(m * 100).round()}%',
            style: AppUi.number.copyWith(fontSize: 12, color: c)),
      ],
    );
    if (moraleBreakdown.isEmpty) return child;
    return Tooltip(
      richMessage: _moraleTooltip(),
      padding: _tipPad,
      decoration: _tipDeco,
      child: child,
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

  // ── Sağ küme: saat/mevsim + ghost kontroller ───────────────────────────────

  Widget _rightCluster() => Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _timeBlock(),
          const SizedBox(width: 16),
          _controls(),
        ],
      );

  Color get _seasonColor => switch (season) {
        Season.spring => const Color(0xFF8FD17A),
        Season.summer => const Color(0xFFE6C260),
        Season.autumn => const Color(0xFFE08A4B),
        Season.winter => const Color(0xFF9FC4E0),
      };

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

  Widget _timeBlock() {
    final inner = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          GameIcon(_weatherIcon, size: 16, color: AppUi.textMid),
          const SizedBox(width: 8),
          Text(_clockText,
              style: AppUi.number.copyWith(fontSize: 22, letterSpacing: 1.0)),
        ]),
        const SizedBox(height: 2),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Text('GÜN $dayCount',
              style: AppUi.label.copyWith(
                  fontSize: 10, letterSpacing: 1.4, color: AppUi.textMid)),
          Text('  ·  ',
              style: AppUi.label.copyWith(fontSize: 10, color: AppUi.textLo)),
          Text(season.label.toUpperCase(),
              style: AppUi.label.copyWith(
                  fontSize: 10, letterSpacing: 1.4, color: _seasonColor)),
        ]),
        const SizedBox(height: 5),
        SizedBox(
          width: 124,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: seasonProgress.clamp(0.0, 1.0),
              minHeight: 2,
              backgroundColor: const Color(0x1FFFFFFF),
              valueColor:
                  AlwaysStoppedAnimation(_seasonColor.withValues(alpha: 0.8)),
            ),
          ),
        ),
      ],
    );
    return Tooltip(
      message: _timeHint,
      textStyle:
          AppUi.body.copyWith(fontSize: 12, height: 1.4, color: AppUi.textHi),
      padding: _tipPad,
      decoration: _tipDeco,
      child: inner,
    );
  }

  // ── Ghost kontroller (çerçevesiz; hover/aktifte yüzey çıkar) ────────────────

  Widget _controls() => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _speedButton(),
          const SizedBox(width: 4),
          // Köy Nüfus Defteri — köylü hane/meslek/servet/moral istatistikleri.
          AppIconButton(
              icon: GameIconData.people,
              onTap: onOpenRoster,
              ghost: true,
              size: 34),
          const SizedBox(width: 4),
          AppIconButton(
            icon: muted ? GameIconData.soundOff : GameIconData.sound,
            onTap: onToggleMute,
            active: muted,
            tint: muted ? AppUi.rust : null,
            ghost: true,
            size: 34,
          ),
          const SizedBox(width: 4),
          AppIconButton(
              icon: GameIconData.dice,
              onTap: onTriggerEvent,
              ghost: true,
              size: 34),
          const SizedBox(width: 4),
          AppIconButton(
              icon: GameIconData.bolt,
              onTap: onToggleGod,
              active: godMode,
              ghost: true,
              size: 34),
          const SizedBox(width: 4),
          AppIconButton(
              icon: GameIconData.map,
              onTap: onNewMap,
              ghost: true,
              size: 34),
          const SizedBox(width: 4),
          AppIconButton(
              icon: GameIconData.bug,
              onTap: onToggleDev,
              ghost: true,
              size: 34),
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
          tint: AppUi.rust,
          ghost: true,
          size: 34);
    }
    final label = timeScale <= 1.01 ? '1×' : timeScale <= 2.01 ? '2×' : '4×';
    return AppIconButton(
      icon: GameIconData.speed,
      text: label,
      onTap: onCycleSpeed,
      active: boosted,
      ghost: true,
      size: 34,
    );
  }

  // ── Uyarı rozetleri ────────────────────────────────────────────────────────

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

// ── Gök şeridi: güneş ↔ ay kovalamacası ──────────────────────────────────────

/// Düz yatay bir hat üzerinde ilerleyen iki gök cismi. Güneş 06:00'da soldan
/// doğar, 18:00'de sağdan batar; ay tam yarım gün geriden aynı hattı kat eder —
/// böylece ikisi hattı devirli olarak kovalar. Hattın dışına çıkan cisim
/// uçlardaki yumuşak solmayla kaybolur, karşı uçtan geri girer.
class _CelestialTrack extends StatelessWidget {
  final double timeOfDay, dayLight, pulse;
  const _CelestialTrack({
    required this.timeOfDay,
    required this.dayLight,
    required this.pulse,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 240,
        height: 34,
        child: CustomPaint(
          painter: _CelestialTrackPainter(
            timeOfDay: timeOfDay,
            dayLight: dayLight,
            pulse: pulse,
          ),
        ),
      );
}

class _CelestialTrackPainter extends CustomPainter {
  final double timeOfDay, dayLight, pulse;
  _CelestialTrackPainter({
    required this.timeOfDay,
    required this.dayLight,
    required this.pulse,
  });

  static const _sun  = Color(0xFFF0B457);
  static const _moon = Color(0xFFCBD8E6);

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * 0.62;
    const pad = 12.0;
    final x0 = pad, x1 = size.width - pad, span = x1 - x0;

    // Hat: uçlarda eriyen ince çizgi — kutu değil, sadece bir iz.
    canvas.drawLine(
      Offset(x0, y),
      Offset(x1, y),
      Paint()
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round
        ..shader = const LinearGradient(colors: [
          Color(0x00FFFFFF), Color(0x3DFFFFFF), Color(0x3DFFFFFF), Color(0x00FFFFFF),
        ], stops: [0.0, 0.18, 0.82, 1.0]).createShader(
          Rect.fromLTWH(x0, y - 1, span, 2),
        ),
    );
    // Öğle çentiği — hattın ortası.
    canvas.drawLine(
      Offset(size.width / 2, y - 3),
      Offset(size.width / 2, y + 3),
      Paint()
        ..strokeWidth = 1
        ..color = const Color(0x2EFFFFFF),
    );

    // Hat = tam bir gün. Güneş öğlen (0.5) tam ortada, ay tam yarım gün geriden
    // aynı yolu yürür — gece yarısı ortaya gelir. İkisi de hep hattadır:
    // biri sağ uçtan çıkarken diğeri soldan girer, sonsuz kovalamaca.
    final sunP  = timeOfDay % 1.0;
    final moonP = (timeOfDay + 0.5) % 1.0;

    // Arkadaki (sönük olan) önce çizilsin ki parlak olan üstte kalsın.
    if (dayLight >= 0.5) {
      _body(canvas, x0, span, y, moonP, _moon, false);
      _body(canvas, x0, span, y, sunP, _sun, true);
    } else {
      _body(canvas, x0, span, y, sunP, _sun, true);
      _body(canvas, x0, span, y, moonP, _moon, false);
    }
  }

  /// t 0..1 → hattın solundan sağına. Uçlarda yumuşakça solar (doğuş/batış).
  void _body(Canvas canvas, double x0, double span, double y, double t,
      Color color, bool isSun) {
    final x = x0 + span * t;

    final vis = t < 0.06
        ? t / 0.06
        : (t > 0.94 ? (1 - t) / 0.06 : 1.0);
    if (vis <= 0.01) return;
    // Ufka yakınken hafifçe alçalsın — düz hat ama nefes alan bir yay hissi.
    final lift = -2.0 * (1 - (2 * t - 1).abs());

    // Nöbetteki cisim parlak ve dolgun; diğeri hattın gerisinde soluk bir iz —
    // görünür kalır (kovalamaca okunsun) ama göz onu takip etmez.
    final active = (isSun ? dayLight : 1 - dayLight).clamp(0.0, 1.0);
    final glow = 0.2 + 0.8 * active;
    final a = vis * (0.22 + 0.78 * active);
    final c = Offset(x, y + lift - 6);
    final r = (isSun ? 5.5 : 4.6) * (0.78 + 0.22 * active);

    // Hale — nabızla çok hafif nefes alır.
    final halo = (r * 2.6) * (1 + 0.06 * (pulse * 2 - 1));
    canvas.drawCircle(
      c,
      halo,
      Paint()
        ..color = color.withValues(alpha: 0.16 * a * glow)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawCircle(c, r, Paint()..color = color.withValues(alpha: a));

    if (!isSun) {
      // Ayın gölgeli tarafı — küçük bir hilal ısırığı.
      canvas.drawCircle(
        c.translate(r * 0.45, -r * 0.25),
        r * 0.82,
        Paint()..color = const Color(0xFF12100D).withValues(alpha: a * 0.75),
      );
    }

    // Hat üzerinde bıraktığı iz — cismin altındaki hattı kendi rengiyle yakar.
    canvas.drawLine(
      Offset(x - 9, y), Offset(x + 9, y),
      Paint()
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: 0.30 * a),
    );
  }

  @override
  bool shouldRepaint(_CelestialTrackPainter old) =>
      old.timeOfDay != timeOfDay || old.dayLight != dayLight || old.pulse != pulse;
}
