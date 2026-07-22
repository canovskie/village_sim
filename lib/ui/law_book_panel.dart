import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../systems/estate_system.dart';
import '../systems/law_book.dart';
import '../text/voice.dart';
import 'app_ui.dart';
import 'law_compass_view.dart';

/// KANUNNAME — ALTIGEN PETEK MİMARİSİ.
///
/// 30+ hüküm tek düzlemde göz yoruyordu. İki katman: üstte bir avuç TEMA
/// (altıgen çiçek — merkez göbek + 6 yaprak), bir temaya dokununca o konunun
/// 3-6 hükmü okunur satır olarak açılır. Bir hükme dokun → kendi meclisi
/// (mühür ritüeli). Arama temaları atlar, doğrudan hükme gider.
///
///   • Açılışta çiçek merkezden dışa doğru açılır (bloom).
///   • Arkada meşale közleri yükselir (levha ocakla aydınlanmış gibi).
///   • Köyün Sesi'nin teması altın bir hâleyle nabız atar.
///   • Mühür geri alınmaz + bir dönemde tek hüküm (mürekkep) korunur —
///     bu yüzden toplu toggle YOK, her hüküm kendi meclisini açar.

enum _LawState { enacted, available, graveLocked, hidden }

enum _NodeState { sealed, open, next, locked, foreclosed }

/// Tema rengi — petek yapraklarını ayırır (kol renklerinden türer/genişler).
Color themeColor(LawTheme t) => switch (t) {
      LawTheme.toprak => AppUi.sage,
      LawTheme.suru => const Color(0xFFC9A24B),
      LawTheme.aile => const Color(0xFFC97B94),
      LawTheme.koy => AppUi.accent,
      LawTheme.asayis => AppUi.rust,
      LawTheme.inanc => AppUi.info,
    };

class LawBookView extends StatefulWidget {
  final Set<String> sealed;
  final LawContext ctx;
  final String? spotlightId;
  final double inkDrySec;
  final double inkDryTotalSec;
  final int seed;
  final void Function(LawDef law) onOpenLaw;

  const LawBookView({
    super.key,
    required this.sealed,
    required this.onOpenLaw,
    this.ctx = const LawContext(),
    this.spotlightId,
    this.inkDrySec = 0,
    this.inkDryTotalSec = 0,
    this.seed = 0,
  });

  @override
  State<LawBookView> createState() => _LawBookViewState();
}

class _LawBookViewState extends State<LawBookView>
    with TickerProviderStateMixin {
  late final AnimationController _bloom = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 720),
  )..forward();
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);
  late final AnimationController _embers = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 7000),
  )..repeat();

  final TextEditingController _search = TextEditingController();
  String _query = '';
  LawTheme? _open; // null = çiçek görünümü

  bool get _inkWet => widget.inkDrySec > 0.5;

  @override
  void dispose() {
    _bloom.dispose();
    _pulse.dispose();
    _embers.dispose();
    _search.dispose();
    super.dispose();
  }

  // ── Hüküm hâli ─────────────────────────────────────────────────────────────

  _LawState _stOf(LawDef l) {
    if (widget.sealed.contains(l.id)) return _LawState.enacted;
    if (LawBook.groupTaken(l, widget.sealed)) return _LawState.hidden;
    if (LawBook.gateLocked(l, widget.ctx)) return _LawState.graveLocked;
    return _LawState.available;
  }

  _NodeState _nodeOf(_LawState s) => switch (s) {
        _LawState.enacted => _NodeState.sealed,
        _LawState.available => _NodeState.open,
        _ => _NodeState.locked,
      };

  int _enactedInTheme(LawTheme t) =>
      LawBook.ofTheme(t).where((l) => widget.sealed.contains(l.id)).length;

  bool _matches(LawDef l) =>
      _query.isEmpty || l.title.toLowerCase().contains(_query);

  LawDef? get _spotlight =>
      widget.spotlightId == null ? null : LawBook.byId(widget.spotlightId!);

  // ── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // POLİTİK PUSULA — defterin başında, hükümlerden ÖNCE: "bu defter
        // köyü ne yaptı?". Eski künye şeridi (kol sayan bir cümle + sayaç)
        // buna gömüldü; kimlik artık tahmin değil, ölçülen konum.
        LawCompassCard(sealed: widget.sealed, totalLaws: kLawBook.length),
        const SizedBox(height: 12),
        _searchBar(),
        const SizedBox(height: 12),
        if (_query.isNotEmpty)
          _searchResults()
        else if (_open != null)
          _themeDrill(_open!)
        else
          _flowerView(),
      ],
    );
  }

  Widget _searchBar() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppUi.surface0,
        borderRadius: BorderRadius.circular(AppUi.radiusSm),
        border: Border.all(color: AppUi.line),
      ),
      child: Row(children: [
        Icon(Icons.search, size: 16, color: AppUi.textLo),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _search,
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            cursorColor: AppUi.accent,
            style: AppUi.body.copyWith(fontSize: 12.5, color: AppUi.textHi),
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              hintText: 'Ferman ara…',
              hintStyle:
                  AppUi.body.copyWith(fontSize: 12.5, color: AppUi.textLo),
            ),
          ),
        ),
        if (_query.isNotEmpty)
          GestureDetector(
            onTap: () => setState(() {
              _query = '';
              _search.clear();
            }),
            child: Icon(Icons.close, size: 15, color: AppUi.textLo),
          ),
      ]),
    );
  }

  // ── ÇİÇEK ──────────────────────────────────────────────────────────────────

  static const double _hw = 132, _hh = 114, _cx = 165, _cy = 171;
  static const Map<String, List<double>> _off = {
    'C': [0, 0],
    'N': [0, -_hh],
    'S': [0, _hh],
    'NE': [0.75 * _hw, -0.5 * _hh],
    'SE': [0.75 * _hw, 0.5 * _hh],
    'NW': [-0.75 * _hw, -0.5 * _hh],
    'SW': [-0.75 * _hw, 0.5 * _hh],
  };
  static const Map<String, int> _bloomOrder = {
    'C': 0,
    'N': 1,
    'NE': 2,
    'SE': 3,
    'S': 4,
    'SW': 5,
    'NW': 6,
  };
  // Yaprak sırası (saat yönü): üst → sağ-üst → sağ-alt → alt → sol-alt → sol-üst.
  static const List<(LawTheme, String)> _petals = [
    (LawTheme.toprak, 'N'),
    (LawTheme.suru, 'NE'),
    (LawTheme.aile, 'SE'),
    (LawTheme.koy, 'S'),
    (LawTheme.asayis, 'SW'),
    (LawTheme.inanc, 'NW'),
  ];

  Widget _flowerView() {
    final spot = _spotlight;
    final voiceTheme = spot == null ? null : LawBook.themeOf(spot);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (spot != null) _voiceCaption(spot),
        const SizedBox(height: 4),
        Center(
          child: SizedBox(
            width: _hw + 1.5 * _hw,
            height: 3 * _hh,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: _embers,
                      builder: (_, _) =>
                          CustomPaint(painter: _EmberPainter(_embers.value)),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_bloom, _pulse]),
                    builder: (_, _) => Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _hexAt('C', isHub: true),
                        for (final (t, pos) in _petals)
                          _hexAt(pos, theme: t, voice: t == voiceTheme),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text('Bir temaya dokun — o konunun hükümleri açılır.',
            textAlign: TextAlign.center,
            style: AppUi.body.copyWith(
                fontSize: 11.5,
                color: AppUi.textLo,
                fontStyle: FontStyle.italic)),
      ],
    );
  }

  Widget _hexAt(String pos, {bool isHub = false, LawTheme? theme, bool voice = false}) {
    final off = _off[pos]!;
    final start = _bloomOrder[pos]! * 0.09;
    final raw = ((_bloom.value - start) / 0.55).clamp(0.0, 1.0);
    final t = Curves.easeOutBack.transform(raw);
    final color = isHub ? AppUi.gold : themeColor(theme!);
    final total = isHub ? kLawBook.length : LawBook.ofTheme(theme!).length;
    final done =
        isHub ? widget.sealed.length : _enactedInTheme(theme!);

    return Positioned(
      left: _cx + off[0] - _hw / 2,
      top: _cy + off[1] - _hh / 2,
      child: Transform.scale(
        scale: 0.3 + 0.7 * t,
        child: Opacity(
          opacity: raw,
          child: _Hex(
            icon: isHub ? '⚖' : theme!.icon,
            label: isHub ? 'KANUNNAME' : theme!.label,
            progress: '$done / $total',
            color: color,
            isHub: isHub,
            voicePulse: voice ? _pulse.value : -1,
            onTap: isHub ? null : () => setState(() => _open = theme),
          ),
        ),
      ),
    );
  }

  Widget _voiceCaption(LawDef l) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppUi.gold.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppUi.gold.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Text('◆', style: TextStyle(fontSize: 8, color: AppUi.gold)),
        const SizedBox(width: 7),
        Flexible(
          child: Text.rich(
            TextSpan(children: [
              TextSpan(
                  text: 'KÖYÜN SESİ  ',
                  style: AppUi.label.copyWith(
                      fontSize: 8.5, color: AppUi.gold, letterSpacing: 1.2)),
              TextSpan(
                  text: l.title,
                  style: AppUi.body
                      .copyWith(fontSize: 11, color: AppUi.textMid)),
            ]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ]),
    );
  }

  // ── TEMA AÇILIMI ───────────────────────────────────────────────────────────

  Widget _themeDrill(LawTheme t) {
    final color = themeColor(t);
    final laws = [
      for (final l in LawBook.ofTheme(t)) if (_stOf(l) != _LawState.hidden) l
    ];
    final done = _enactedInTheme(t);
    return Column(
      key: ValueKey(t),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _open = null),
          child: Container(
            padding: const EdgeInsets.fromLTRB(11, 9, 15, 9),
            decoration: BoxDecoration(
              color: AppUi.surface2,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.arrow_back_rounded, size: 17, color: color),
              const SizedBox(width: 7),
              Text('TÜM TEMALAR',
                  style: AppUi.label.copyWith(
                      fontSize: 11, color: AppUi.textHi, letterSpacing: 1.4)),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          _themeBadge(t, color),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(t.label,
                  style: AppUi.title.copyWith(fontSize: 18, height: 1.1)),
              const SizedBox(height: 2),
              Text('$done / ${LawBook.ofTheme(t).length} hüküm deftere girdi',
                  style: AppUi.body.copyWith(fontSize: 10.5, color: AppUi.textLo)),
            ],
          ),
        ]),
        const SizedBox(height: 12),
        Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              color.withValues(alpha: 0.45),
              color.withValues(alpha: 0),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < laws.length; i++) ...[
          _lawTile(laws[i], entrance: i),
          if (i < laws.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _themeBadge(LawTheme t, Color color) => SizedBox(
        width: 46,
        height: 40,
        child: ClipPath(
          clipper: _HexClipper(),
          child: Container(
            color: color.withValues(alpha: 0.18),
            alignment: Alignment.center,
            child: Text(t.icon, style: const TextStyle(fontSize: 20)),
          ),
        ),
      );

  // ── ARAMA ──────────────────────────────────────────────────────────────────

  Widget _searchResults() {
    final hits = [
      for (final l in kLawBook)
        if (_stOf(l) != _LawState.hidden && _matches(l)) l
    ];
    if (hits.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 26),
        child: Center(
          child: Text('“$_query” ile eşleşen ferman yok.',
              style: AppUi.body.copyWith(
                  fontSize: 11.5,
                  color: AppUi.textLo,
                  fontStyle: FontStyle.italic)),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${hits.length} sonuç',
            style: AppUi.label
                .copyWith(fontSize: 9, color: AppUi.textLo, letterSpacing: 1.4)),
        const SizedBox(height: 8),
        for (var i = 0; i < hits.length; i++) ...[
          _lawTile(hits[i], entrance: i, showTheme: true),
          if (i < hits.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }

  // ── HÜKÜM KUTUCUĞU ─────────────────────────────────────────────────────────

  Widget _lawTile(LawDef l, {int entrance = 0, bool showTheme = false}) {
    final st = _stOf(l);
    final color = branchColor(l.branch);
    final tappable = st == _LawState.available && !_inkWet;
    final spotlight = l.id == widget.spotlightId && st == _LawState.available;
    final (tag, tagColor) = _tagFor(st, color, spotlight);

    return GestureDetector(
      onTap: tappable ? () => widget.onOpenLaw(l) : null,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, _) => Container(
          padding: const EdgeInsets.fromLTRB(10, 9, 11, 9),
          decoration: BoxDecoration(
            color: st == _LawState.enacted
                ? color.withValues(alpha: 0.06)
                : AppUi.surface0,
            borderRadius: BorderRadius.circular(AppUi.radiusSm),
            border: Border.all(
              color: spotlight
                  ? color.withValues(alpha: 0.55)
                  : st == _LawState.enacted
                      ? color.withValues(alpha: 0.28)
                      : AppUi.line,
            ),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _Medallion(
              state: _nodeOf(st),
              color: color,
              icon: l.icon,
              size: 32,
              pulse: tappable ? _pulse.value : 0,
              pop: 0,
              selected: false,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(_shortTitle(l.title),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppUi.bodyHi.copyWith(
                              fontSize: 12.5,
                              height: 1.1,
                              color: st == _LawState.graveLocked
                                  ? AppUi.textLo
                                  : AppUi.textHi,
                              fontWeight: FontWeight.w700)),
                    ),
                    if (showTheme) ...[
                      const SizedBox(width: 6),
                      Text(LawBook.themeOf(l).icon,
                          style: const TextStyle(fontSize: 10)),
                    ],
                    const SizedBox(width: 6),
                    _stateDot(st, color),
                  ]),
                  const SizedBox(height: 3),
                  Text(LawBook.summary(l.id),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppUi.body.copyWith(
                          fontSize: 10,
                          height: 1.3,
                          color: st == _LawState.graveLocked
                              ? AppUi.textLo.withValues(alpha: 0.7)
                              : AppUi.textMid)),
                  const SizedBox(height: 4),
                  Text(tag,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppUi.label.copyWith(
                          fontSize: 7.5, color: tagColor, letterSpacing: 0.5)),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  (String, Color) _tagFor(_LawState st, Color color, bool spotlight) =>
      switch (st) {
        _LawState.enacted => ('deftere girdi', AppUi.gold),
        _LawState.graveLocked => ('kilitli — köy büyüyünce', AppUi.textLo),
        _ => _inkWet
            ? ('müzakere bekliyor', AppUi.textLo)
            : (spotlight
                ? ('köyün sesi · şimdi gerek', color)
                : ('çıkarılabilir', color)),
      };

  String _shortTitle(String t) {
    for (final suf in const [' Fermanı', ' Beratı']) {
      if (t.endsWith(suf)) return t.substring(0, t.length - suf.length);
    }
    return t;
  }

  Widget _stateDot(_LawState s, Color color) {
    final c = switch (s) {
      _LawState.enacted => AppUi.gold,
      _LawState.available => _inkWet ? AppUi.textLo : color,
      _ => AppUi.textLo.withValues(alpha: 0.5),
    };
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(shape: BoxShape.circle, color: c),
    );
  }
}

// ─── ALTIGEN ─────────────────────────────────────────────────────────────────

class _HexClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) {
    final w = s.width, h = s.height;
    return Path()
      ..moveTo(w * 0.25, 0)
      ..lineTo(w * 0.75, 0)
      ..lineTo(w, h * 0.5)
      ..lineTo(w * 0.75, h)
      ..lineTo(w * 0.25, h)
      ..lineTo(0, h * 0.5)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _Hex extends StatelessWidget {
  final String icon, label, progress;
  final Color color;
  final bool isHub;
  final double voicePulse; // -1 = köyün sesi değil
  final VoidCallback? onTap;

  const _Hex({
    required this.icon,
    required this.label,
    required this.progress,
    required this.color,
    required this.isHub,
    required this.voicePulse,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final voice = voicePulse >= 0;
    return SizedBox(
      width: 132,
      height: 114,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Köyün Sesi halesi — nabız atan altın parıltı.
          if (voice)
            Transform.scale(
              scale: 1.05 + voicePulse * 0.06,
              child: SizedBox(
                width: 132,
                height: 114,
                child: ClipPath(
                  clipper: _HexClipper(),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(colors: [
                        AppUi.gold.withValues(alpha: 0.15 + voicePulse * 0.22),
                        AppUi.gold.withValues(alpha: 0.0),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          GestureDetector(
            onTap: onTap,
            child: ClipPath(
              clipper: _HexClipper(),
              // Kol renginde ince halka.
              child: Container(
                color: color.withValues(alpha: 0.55),
                padding: const EdgeInsets.all(3),
                child: ClipPath(
                  clipper: _HexClipper(),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(-0.3, -0.45),
                        radius: 0.9,
                        colors: [
                          Color.lerp(AppUi.surface2, color, isHub ? 0.16 : 0.22)!,
                          AppUi.surface1,
                        ],
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(icon, style: const TextStyle(fontSize: 22)),
                          const SizedBox(height: 3),
                          SizedBox(
                            width: 96,
                            child: Text(label,
                                textAlign: TextAlign.center,
                                style: AppUi.title.copyWith(
                                    fontSize: isHub ? 11.5 : 11,
                                    height: 1.1,
                                    letterSpacing: isHub ? 1.4 : 0.3,
                                    color: isHub ? AppUi.gold : AppUi.textHi)),
                          ),
                          const SizedBox(height: 2),
                          Text(progress,
                              style: AppUi.number.copyWith(
                                  fontSize: 10,
                                  color: isHub
                                      ? AppUi.gold.withValues(alpha: 0.8)
                                      : color.withValues(alpha: 0.85))),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Meşale közleri — levhanın arkasında yükselen sıcak parçacıklar. Prosedürel
/// (durum tutmaz): her köz kendi fazından türer, [t] döngüsüyle akar.
class _EmberPainter extends CustomPainter {
  final double t;
  const _EmberPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    const n = 16;
    final p = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    for (var i = 0; i < n; i++) {
      final seed = (i * 0.61803398875) % 1.0;
      final baseX = seed * size.width;
      final phase = (t + i / n) % 1.0;
      final y = size.height * (1 - phase) - 6;
      final x = baseX + math.sin(phase * 6.2832 + i) * 11;
      final a = math.sin(phase * math.pi) * 0.5;
      if (a <= 0.01) continue;
      final r = 1.0 + (i % 3) * 0.7;
      p.color = Color.fromRGBO(228, 150 + (i % 3) * 18, 74, a * 0.6);
      canvas.drawCircle(Offset(x, y), r, p);
    }
  }

  @override
  bool shouldRepaint(covariant _EmberPainter old) => old.t != t;
}

// ─── BERAT MEDALYONU ─────────────────────────────────────────────────────────

class _Medallion extends StatelessWidget {
  final _NodeState state;
  final Color color;
  final String icon;
  final double size;
  final double pulse;
  final double pop;
  final bool selected;

  const _Medallion({
    required this.state,
    required this.color,
    required this.icon,
    required this.pulse,
    required this.pop,
    required this.selected,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    final popScale = 1 + (pop < 0.5 ? pop * 0.7 : (1 - pop) * 0.7);
    final glow = state == _NodeState.open
        ? 0.18 + pulse * 0.4
        : (state == _NodeState.sealed ? 0.12 : (pop > 0 ? (1 - pop) : 0.0));

    final (Color ringColor, double ringWidth, double iconAlpha) = switch (state) {
      _NodeState.sealed => (Color.lerp(color, AppUi.gold, 0.25)!, 1.8, 1.0),
      _NodeState.open => (color, 2.0, 1.0),
      _NodeState.next => (color.withValues(alpha: 0.4), 1.4, 0.42),
      _NodeState.locked => (AppUi.line, 1.2, 0.5),
      _NodeState.foreclosed => (AppUi.line, 1.2, 0.0),
    };

    final well = state == _NodeState.sealed
        ? RadialGradient(
            center: const Alignment(-0.3, -0.4),
            colors: [
              Color.lerp(color, AppUi.textHi, 0.1)!.withValues(alpha: 0.5),
              color.withValues(alpha: 0.16),
              AppUi.surface0,
            ],
            stops: const [0.0, 0.55, 1.0],
          )
        : const RadialGradient(
            center: Alignment(-0.3, -0.4),
            colors: [AppUi.surface2, AppUi.surface0],
          );

    Widget content;
    if (state == _NodeState.foreclosed) {
      content = Text('✕',
          style: TextStyle(
              fontSize: size * 0.36, color: AppUi.rust.withValues(alpha: 0.55)));
    } else {
      content = Opacity(
        opacity: iconAlpha,
        child: Text(icon, style: TextStyle(fontSize: size * 0.45, height: 1)),
      );
    }

    final badge = size * 0.36;
    return Transform.scale(
      scale: popScale,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? AppUi.gold.withValues(alpha: 0.85)
                : Colors.transparent,
            width: 1.4,
          ),
          boxShadow: glow > 0.02
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: glow * 0.5),
                    blurRadius: 8 + glow * 7,
                    spreadRadius: glow * 1.2,
                  )
                ]
              : null,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: well,
                border: Border.all(color: ringColor, width: ringWidth),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x55000000),
                      blurRadius: 2,
                      offset: Offset(0, 1)),
                ],
              ),
              alignment: Alignment.center,
              child: content,
            ),
            if (state == _NodeState.sealed)
              Positioned(
                right: -1,
                bottom: -1,
                child: Container(
                  width: badge,
                  height: badge,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppUi.gold,
                    border: Border.all(color: AppUi.surface0, width: 1.4),
                  ),
                  alignment: Alignment.center,
                  child: Text('✓',
                      style: TextStyle(
                          fontSize: badge * 0.6,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          color: AppUi.ink)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Kol rengi — nizam kızıl (kılıç), dergâh teal (kandil), geçim adaçayı (toprak).
Color branchColor(LawBranch b) => switch (b) {
      LawBranch.gecim => AppUi.sage,
      LawBranch.nizam => AppUi.rust,
      LawBranch.dergah => AppUi.info,
    };

// ─── MÜHÜR RİTÜELİ (meclis) ─────────────────────────────────────────────────

class LawSealRitual extends StatefulWidget {
  final LawDef law;
  final int seed;

  /// Mühürlü fermanlar — pusula önizlemesi ("bu ferman ibreyi nereye iter")
  /// mevcut konumu bilmeden çizilemez.
  final Set<String> sealed;

  final VoidCallback onSeal;
  final VoidCallback onDismiss;

  const LawSealRitual({
    super.key,
    required this.law,
    required this.onSeal,
    required this.onDismiss,
    this.sealed = const {},
    this.seed = 0,
  });

  @override
  State<LawSealRitual> createState() => _LawSealRitualState();
}

class _LawSealRitualState extends State<LawSealRitual>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onSeal();
    });

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  LawDef get law => widget.law;
  Color get accent => branchColor(law.branch);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onDismiss,
            child: const ColoredBox(color: AppUi.scrim),
          ),
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: GestureDetector(
                onTap: () {},
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  builder: (_, t, child) => Opacity(
                    opacity: t,
                    child: Transform.scale(
                      scale: 0.96 + t * 0.04,
                      alignment: Alignment.center,
                      child: child,
                    ),
                  ),
                  child: AppGildedFrame(
                    accent: accent,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _kicker(),
                          const SizedBox(height: 10),
                          _effectLine(),
                          // NE YAPAR'ın hemen altında NEREYE GÖTÜRÜR: mühür
                          // basmadan önce oyuncu ibrenin nereye kayacağını
                          // görür (kimlik değişecekse eski → yeni).
                          const SizedBox(height: 10),
                          LawCompassNudge(
                              sealed: widget.sealed, lawId: law.id),
                          const SizedBox(height: 12),
                          _decree(),
                          const SizedBox(height: 14),
                          const AppSectionLabel('MECLİS'),
                          const SizedBox(height: 6),
                          _council(),
                          if (law.isGrave) ...[
                            const SizedBox(height: 12),
                            _gravityWarning(),
                          ],
                          const SizedBox(height: 16),
                          _sealButton(),
                          const SizedBox(height: 8),
                          _dismissRow(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _kicker() => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(law.icon, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('MECLİS TOPLANDI',
                    style: AppUi.label.copyWith(
                        fontSize: 8.5, color: accent, letterSpacing: 1.6)),
                const SizedBox(height: 3),
                Text(law.title,
                    style: AppUi.title.copyWith(fontSize: 17, height: 1.15)),
              ],
            ),
          ),
        ],
      );

  /// NE YAPAR — meclisin başında, şiirsel buyruktan önce düz bir cümle.
  Widget _effectLine() {
    final s = LawBook.summary(law.id);
    if (s.isEmpty) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, size: 13, color: accent),
        const SizedBox(width: 7),
        Expanded(
          child: Text(s,
              style: AppUi.body.copyWith(
                  fontSize: 11.5, height: 1.35, color: AppUi.textMid)),
        ),
      ],
    );
  }

  Widget _decree() => ClipRRect(
        borderRadius: BorderRadius.circular(AppUi.radiusSm),
        child: Stack(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 13, 12),
              decoration: BoxDecoration(
                color: AppUi.surface0,
                borderRadius: BorderRadius.circular(AppUi.radiusSm),
                border: Border.all(color: AppUi.line),
              ),
              child: Text(
                law.decree,
                style: AppUi.body.copyWith(
                    fontSize: 13,
                    height: 1.55,
                    color: AppUi.textHi,
                    fontStyle: FontStyle.italic),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                  width: 2.5, color: accent.withValues(alpha: 0.75)),
            ),
          ],
        ),
      );

  Widget _council() {
    final moods = {for (final (e, d) in law.seal.estateMood) e: d};
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final e in Estate.values) _estateRow(e, moods[e] ?? 0.0),
      ],
    );
  }

  Widget _estateRow(Estate e, double delta) {
    final silent = delta == 0;
    final stance = stanceOf(delta);
    final color = silent
        ? AppUi.textLo
        : delta > 0
            ? AppUi.sage
            : AppUi.rust;
    final line = silent
        ? '${e.label} ses çıkarmadı.'
        : Voice.pick(stanceLines(e, stance), widget.seed + e.index);
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            child: Text(e.icon, style: const TextStyle(fontSize: 13)),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(line,
                style: AppUi.body.copyWith(
                    fontSize: 10.5, height: 1.35, color: color)),
          ),
        ],
      ),
    );
  }

  Widget _gravityWarning() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
      decoration: BoxDecoration(
        color: AppUi.rust.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppUi.radiusSm),
        border: Border.all(color: AppUi.rust.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('⚠', style: TextStyle(fontSize: 12, color: AppUi.rust)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
                'Bu, köyün ne olduğunu ilan eden ağır bir hüküm. Basılınca '
                'köyün ruhunda kalıcı bir iz bırakır.',
                style: AppUi.body.copyWith(
                    fontSize: 10.5, height: 1.35, color: AppUi.rust)),
          ),
        ],
      ),
    );
  }

  Widget _sealButton() {
    return GestureDetector(
      onTapDown: (_) => _press.forward(),
      onTapUp: (_) => _press.reverse(),
      onTapCancel: () => _press.reverse(),
      child: AnimatedBuilder(
        animation: _press,
        builder: (_, _) {
          final t = _press.value;
          return Container(
            height: 50,
            decoration: BoxDecoration(
              color: AppUi.surface0,
              borderRadius: BorderRadius.circular(AppUi.radiusSm),
              border: Border.all(
                  color: Color.lerp(accent.withValues(alpha: 0.5), accent, t)!,
                  width: 1 + t),
            ),
            child: Stack(
              children: [
                FractionallySizedBox(
                  widthFactor: t,
                  child: Container(
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.22 + t * 0.16),
                      borderRadius: BorderRadius.circular(AppUi.radiusSm),
                    ),
                  ),
                ),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Transform.scale(
                        scale: 1 + t * 0.25,
                        child: Text('⚖',
                            style: TextStyle(
                                fontSize: 15,
                                color: Color.lerp(accent, AppUi.textHi, t))),
                      ),
                      const SizedBox(width: 9),
                      Text(
                        t > 0.02 ? 'BASILI TUT…' : law.seal.label.toUpperCase(),
                        style: AppUi.button.copyWith(
                            fontSize: 11.5,
                            color: Color.lerp(AppUi.textMid, AppUi.textHi, t),
                            letterSpacing: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _dismissRow() => Center(
        child: GestureDetector(
          onTap: widget.onDismiss,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'defteri kapat — bu ferman yazılmadı',
              style: AppUi.body.copyWith(fontSize: 10, color: AppUi.textLo),
            ),
          ),
        ),
      );
}
