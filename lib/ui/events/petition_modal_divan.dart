part of 'petition_modal.dart';

/// DİVAN YÜZEYİ — telefon/masaüstü divan yaşamı (göz kırpma/esneme), karar alanı, anlatı, portre, seçenek destesi, alt bant.
/// Telefon Divan'ında portre yaşamını taşır. Builder kullanmasının nedeni,
/// mevcut sıkı 760×360 yerleşimi yeniden sarmalayıp ölçülerini değiştirmeden
/// yalnız dokunma ve zaman durumunu araya koymaktır.
class _CompactDivanLife extends StatefulWidget {
  final Petition petition;
  final VillagerEntity? author;
  final void Function(PetitionOption) onChoose;
  final Widget Function(BuildContext, _CompactDivanLifeState) builder;

  const _CompactDivanLife({
    required this.petition,
    required this.author,
    required this.onChoose,
    required this.builder,
  });

  @override
  State<_CompactDivanLife> createState() => _CompactDivanLifeState();
}

class _CompactDivanLifeState extends State<_CompactDivanLife> {
  final GlobalKey portraitKey = GlobalKey();
  Timer? _blinkTimer;
  Timer? _blinkEndTimer;
  Timer? _yawnTimer;
  Timer? _yawnEndTimer;
  Offset lookOffset = Offset.zero;
  PortraitExpression expression = PortraitExpression.neutral;
  bool blink = false;
  bool _choosing = false;
  PetitionOption? _pressedOption;

  bool get _hasFace => widget.author != null;

  int get _idleSeed => widget.petition.id.codeUnits.fold<int>(
    widget.author?.name.codeUnits.fold<int>(0, (a, b) => a + b) ?? 0,
    (a, b) => a + b,
  );

  @override
  void initState() {
    super.initState();
    _scheduleIdleLife();
  }

  @override
  void didUpdateWidget(covariant _CompactDivanLife oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.petition.id != widget.petition.id ||
        oldWidget.author != widget.author) {
      _cancelIdleLife();
      lookOffset = Offset.zero;
      expression = PortraitExpression.neutral;
      blink = false;
      _choosing = false;
      _pressedOption = null;
      _scheduleIdleLife();
    }
  }

  void _scheduleIdleLife() {
    if (!_hasFace) return;
    _scheduleBlink();
    _scheduleYawn();
  }

  void _scheduleBlink() {
    _blinkTimer?.cancel();
    _blinkTimer = Timer(Duration(milliseconds: 3200 + (_idleSeed % 2400)), () {
      if (!mounted || _choosing || expression == PortraitExpression.yawn) {
        _scheduleBlink();
        return;
      }
      setState(() => blink = true);
      _blinkEndTimer = Timer(const Duration(milliseconds: 130), () {
        if (!mounted) return;
        setState(() => blink = false);
        _scheduleBlink();
      });
    });
  }

  void _scheduleYawn() {
    _yawnTimer?.cancel();
    _yawnTimer = Timer(Duration(milliseconds: 12000 + (_idleSeed % 6001)), () {
      if (!mounted || _choosing) return;
      if (_pressedOption != null) {
        _scheduleYawn();
        return;
      }
      setState(() {
        blink = false;
        expression = PortraitExpression.yawn;
      });
      _yawnEndTimer = Timer(const Duration(milliseconds: 2100), () {
        if (!mounted || _choosing) return;
        setState(() => expression = PortraitExpression.neutral);
        _scheduleYawn();
      });
    });
  }

  void _cancelIdleLife() {
    _blinkTimer?.cancel();
    _blinkEndTimer?.cancel();
    _yawnTimer?.cancel();
    _yawnEndTimer?.cancel();
  }

  void _trackFinger(PointerEvent event) {
    if (!_hasFace || _choosing) return;
    final renderObject = portraitKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;
    final local = renderObject.globalToLocal(event.position);
    final center = renderObject.size.center(Offset.zero);
    final next = Offset(
      ((local.dx - center.dx) / center.dx).clamp(-1.0, 1.0),
      ((local.dy - center.dy) / center.dy).clamp(-1.0, 1.0),
    );
    if ((next - lookOffset).distance < .025) return;
    setState(() => lookOffset = next);
  }

  void _releaseFinger(PointerEvent _) {
    if (!_hasFace || _choosing || lookOffset == Offset.zero) return;
    setState(() => lookOffset = Offset.zero);
  }

  void pressOption(PetitionOption option, bool pressed) {
    if (!_hasFace || _choosing) return;
    if (!pressed && !identical(_pressedOption, option)) return;
    _yawnTimer?.cancel();
    _yawnEndTimer?.cancel();
    setState(() {
      _pressedOption = pressed ? option : null;
      expression = pressed
          ? _previewExpressionFor(option)
          : PortraitExpression.neutral;
    });
    if (!pressed) _scheduleYawn();
  }

  void choose(PetitionOption option) {
    if (_choosing) return;
    if (!_hasFace) {
      widget.onChoose(option);
      return;
    }
    _cancelIdleLife();
    setState(() {
      _choosing = true;
      blink = false;
      lookOffset = Offset.zero;
      expression = _decisionReactionFor(option);
    });
    final applyChoice = widget.onChoose;
    Timer(const Duration(milliseconds: 900), () => applyChoice(option));
  }

  @override
  void dispose() {
    _cancelIdleLife();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _trackFinger,
      onPointerMove: _trackFinger,
      onPointerUp: _releaseFinger,
      onPointerCancel: _releaseFinger,
      child: IgnorePointer(
        ignoring: _choosing,
        child: widget.builder(context, this),
      ),
    );
  }
}

/// Masaüstü Divan'ındaki canlı alan. Etkileşim burada tutulur ki kompakt mobil
/// pano ve oyundaki diğer portreler etkilenmesin.
class _DivanDecisionArea extends StatefulWidget {
  final double panelWidth;
  final Petition petition;
  final VillagerEntity? author;
  final Color accent;
  final String kicker;
  final String? decisionContext;
  final VoidCallback? onAuthorTap;
  final bool dense;
  final void Function(PetitionOption) onChoose;
  final String? Function(PetitionOption)? blockedReason;
  final Widget? vetoRow;

  const _DivanDecisionArea({
    required this.panelWidth,
    required this.petition,
    required this.author,
    required this.accent,
    required this.kicker,
    required this.decisionContext,
    required this.onAuthorTap,
    required this.dense,
    required this.onChoose,
    required this.blockedReason,
    required this.vetoRow,
  });

  @override
  State<_DivanDecisionArea> createState() => _DivanDecisionAreaState();
}

class _DivanDecisionAreaState extends State<_DivanDecisionArea> {
  final GlobalKey _portraitKey = GlobalKey();
  Timer? _blinkTimer;
  Timer? _blinkEndTimer;
  Timer? _yawnTimer;
  Timer? _yawnEndTimer;
  Offset _lookOffset = Offset.zero;
  PortraitExpression _expression = PortraitExpression.neutral;
  PetitionOption? _hoveredOption;
  bool _blink = false;
  bool _choosing = false;

  bool get _hasFace => widget.author != null;

  @override
  void initState() {
    super.initState();
    _scheduleIdleLife();
  }

  @override
  void didUpdateWidget(covariant _DivanDecisionArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.petition.id != widget.petition.id ||
        oldWidget.author != widget.author) {
      _cancelIdleLife();
      _lookOffset = Offset.zero;
      _expression = PortraitExpression.neutral;
      _hoveredOption = null;
      _blink = false;
      _choosing = false;
      _scheduleIdleLife();
    }
  }

  int get _idleSeed => widget.petition.id.codeUnits.fold<int>(
    widget.author?.name.codeUnits.fold<int>(0, (a, b) => a + b) ?? 0,
    (a, b) => a + b,
  );

  void _scheduleIdleLife() {
    if (!_hasFace) return;
    _scheduleBlink();
    _scheduleYawn();
  }

  void _scheduleBlink() {
    _blinkTimer?.cancel();
    final delay = Duration(milliseconds: 3200 + (_idleSeed % 2400));
    _blinkTimer = Timer(delay, () {
      if (!mounted || _choosing || _expression == PortraitExpression.yawn) {
        _scheduleBlink();
        return;
      }
      setState(() => _blink = true);
      _blinkEndTimer = Timer(const Duration(milliseconds: 130), () {
        if (!mounted) return;
        setState(() => _blink = false);
        _scheduleBlink();
      });
    });
  }

  void _scheduleYawn() {
    _yawnTimer?.cancel();
    // Aynı kişi aynı ikilemde tutarlı ama robotik olmayan 12–18 sn bekler.
    final delay = Duration(milliseconds: 12000 + (_idleSeed % 6001));
    _yawnTimer = Timer(delay, () {
      if (!mounted || _choosing) return;
      if (_hoveredOption != null) {
        _scheduleYawn();
        return;
      }
      setState(() {
        _blink = false;
        _expression = PortraitExpression.yawn;
      });
      _yawnEndTimer = Timer(const Duration(milliseconds: 2100), () {
        if (!mounted || _choosing) return;
        setState(() => _expression = PortraitExpression.neutral);
        _scheduleYawn();
      });
    });
  }

  void _cancelIdleLife() {
    _blinkTimer?.cancel();
    _blinkEndTimer?.cancel();
    _yawnTimer?.cancel();
    _yawnEndTimer?.cancel();
  }

  void _trackPointer(PointerHoverEvent event) {
    if (!_hasFace || _choosing) return;
    final renderObject = _portraitKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;
    final local = renderObject.globalToLocal(event.position);
    final center = renderObject.size.center(Offset.zero);
    final next = Offset(
      ((local.dx - center.dx) / center.dx).clamp(-1.0, 1.0),
      ((local.dy - center.dy) / center.dy).clamp(-1.0, 1.0),
    );
    if ((next - _lookOffset).distance < .025) return;
    setState(() => _lookOffset = next);
  }

  void _stopTracking(PointerExitEvent _) {
    if (!_hasFace || _choosing) return;
    setState(() => _lookOffset = Offset.zero);
  }

  void _hoverOption(PetitionOption option, bool hovering) {
    if (!_hasFace || _choosing) return;
    if (!hovering && !identical(option, _hoveredOption)) return;
    final next = hovering ? option : null;
    if (identical(next, _hoveredOption)) return;
    _yawnTimer?.cancel();
    _yawnEndTimer?.cancel();
    setState(() {
      _hoveredOption = next;
      _expression = next == null
          ? PortraitExpression.neutral
          : _previewExpressionFor(next);
    });
    if (next == null) _scheduleYawn();
  }

  void _choose(PetitionOption option) {
    if (_choosing) return;
    if (!_hasFace) {
      widget.onChoose(option);
      return;
    }
    _cancelIdleLife();
    setState(() {
      _choosing = true;
      _blink = false;
      _lookOffset = Offset.zero;
      _expression = _decisionReactionFor(option);
    });
    // Karar önce yüzde okunur, sonra oyun durumuna uygulanıp pano kapanır.
    final applyChoice = widget.onChoose;
    Timer(const Duration(milliseconds: 900), () {
      applyChoice(option);
    });
  }

  @override
  void dispose() {
    _cancelIdleLife();
    // Seçim yapıldıysa modal dışarıdan kapanmış olsa bile karar kaybolmasın.
    // Timer bu yüzden iptal edilmez; callback State'e erişmez.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: _trackPointer,
      onExit: _stopTracking,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: widget.panelWidth * .41,
            child: _DivanNarrative(
              petition: widget.petition,
              author: widget.author,
              accent: widget.accent,
              kicker: widget.kicker,
              decisionContext: widget.decisionContext,
              onAuthorTap: widget.onAuthorTap,
              dense: widget.dense,
              portraitKey: _portraitKey,
              portraitLookOffset: _lookOffset,
              portraitExpression: _expression,
              portraitBlink: _blink,
            ),
          ),
          Container(width: 1, color: AppUi.gold.withValues(alpha: .18)),
          Expanded(
            child: Container(
              padding: EdgeInsets.fromLTRB(
                widget.dense ? 12 : 18,
                widget.dense ? 12 : 18,
                widget.dense ? 12 : 18,
                widget.dense ? 10 : 14,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1B1E23), Color(0xFF121418)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: IgnorePointer(
                      ignoring: _choosing,
                      child: _DivanOptionDeck(
                        options: widget.petition.options,
                        accent: widget.accent,
                        onChoose: _choose,
                        onHover: _hoverOption,
                        blockedReason: widget.blockedReason,
                        dense: widget.dense,
                      ),
                    ),
                  ),
                  if (widget.vetoRow != null) ...[
                    const SizedBox(height: 8),
                    widget.vetoRow!,
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DivanNarrative extends StatelessWidget {
  final Petition petition;
  final VillagerEntity? author;
  final Color accent;
  final String kicker;
  final String? decisionContext;
  final VoidCallback? onAuthorTap;
  final bool dense;
  final Key portraitKey;
  final Offset portraitLookOffset;
  final PortraitExpression portraitExpression;
  final bool portraitBlink;

  const _DivanNarrative({
    required this.petition,
    required this.author,
    required this.accent,
    required this.kicker,
    required this.decisionContext,
    required this.onAuthorTap,
    required this.dense,
    required this.portraitKey,
    required this.portraitLookOffset,
    required this.portraitExpression,
    required this.portraitBlink,
  });

  @override
  Widget build(BuildContext context) {
    final a = author;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF17191D), Color(0xFF111317)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: dense ? 54 : 68,
            padding: EdgeInsets.symmetric(horizontal: dense ? 16 : 24),
            decoration: const BoxDecoration(
              color: Color(0xA807090B),
              border: Border(bottom: BorderSide(color: AppUi.line)),
            ),
            child: Row(
              children: [
                Container(
                  width: dense ? 34 : 42,
                  height: dense ? 34 : 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: accent.withValues(alpha: .72)),
                  ),
                  child: Center(
                    child: GameIcon(
                      GameIconData.scales,
                      size: dense ? 18 : 22,
                      color: accent,
                    ),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Text(
                    kicker,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppUi.title.copyWith(
                      color: AppUi.accent,
                      fontSize: dense ? 14 : 17,
                      letterSpacing: 2.5,
                    ),
                  ),
                ),
                if (petition.note != null)
                  Flexible(
                    child: Text(
                      petition.note!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppUi.label.copyWith(color: AppUi.gold),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                dense ? 20 : 30,
                dense ? 12 : 18,
                dense ? 20 : 30,
                dense ? 10 : 16,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: a == null ? null : onAuthorTap,
                    child: _DivanPortrait(
                      key: portraitKey,
                      author: a,
                      glyph: petition.icon,
                      accent: accent,
                      size: dense ? 96 : 148,
                      lookOffset: portraitLookOffset,
                      expression: portraitExpression,
                      blink: portraitBlink,
                    ),
                  ),
                  SizedBox(height: dense ? 10 : 15),
                  Text(
                    _divanUpper(petition.title),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppUi.title.copyWith(
                      fontSize: dense ? 21 : 30,
                      height: 1.08,
                      letterSpacing: dense ? 2.1 : 2.8,
                    ),
                  ),
                  SizedBox(height: dense ? 5 : 8),
                  GestureDetector(
                    onTap: a == null ? null : onAuthorTap,
                    child: Text(
                      a == null
                          ? petition.petitioner
                          : '${a.name}  ·  ${a.hasProfession ? a.type.displayName : a.lifeStage.label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppUi.body.copyWith(
                        color: a == null ? AppUi.textMid : AppUi.gold,
                        fontSize: dense ? 11 : 13,
                        letterSpacing: .5,
                      ),
                    ),
                  ),
                  SizedBox(height: dense ? 8 : 12),
                  _DivanOrnament(accent: accent),
                  SizedBox(height: dense ? 8 : 13),
                  Flexible(
                    child: Text(
                      petition.body,
                      maxLines: dense ? 3 : 5,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppUi.body.copyWith(
                        color: AppUi.textMid,
                        fontSize: dense ? 12 : 15.5,
                        height: 1.52,
                      ),
                    ),
                  ),
                  if (petition.stakes != null) ...[
                    SizedBox(height: dense ? 7 : 10),
                    Text(
                      petition.stakes!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppUi.body.copyWith(
                        color: accent.withValues(alpha: .9),
                        fontSize: dense ? 10 : 11.5,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  if (decisionContext != null) ...[
                    SizedBox(height: dense ? 7 : 10),
                    _DecisionContext(text: decisionContext!, compact: dense),
                  ],
                  SizedBox(height: dense ? 7 : 11),
                  const _DivanOrnament(accent: AppUi.gold),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DivanPortrait extends StatelessWidget {
  final VillagerEntity? author;
  final String glyph;
  final Color accent;
  final double size;
  final Offset lookOffset;
  final PortraitExpression expression;
  final bool blink;

  const _DivanPortrait({
    super.key,
    required this.author,
    required this.glyph,
    required this.accent,
    required this.size,
    required this.lookOffset,
    required this.expression,
    required this.blink,
  });

  @override
  Widget build(BuildContext context) {
    final a = author;
    return Container(
      width: size,
      height: size * 1.12,
      padding: EdgeInsets.all(size * .075),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppUi.gold.withValues(alpha: .62), width: 2),
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: .24), blurRadius: 24),
          const BoxShadow(color: Color(0xB0000000), blurRadius: 14),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppUi.surface0,
          border: Border.all(color: accent.withValues(alpha: .6)),
        ),
        child: ClipOval(
          child: a == null
              ? Center(
                  child: Text(glyph, style: TextStyle(fontSize: size * .4)),
                )
              : TweenAnimationBuilder<Offset>(
                  tween: Tween(end: lookOffset),
                  duration: const Duration(milliseconds: 110),
                  curve: Curves.easeOut,
                  builder: (context, animatedLook, _) => CustomPaint(
                    key: const ValueKey('divan-portrait-paint'),
                    painter: PortraitPainter(
                      visual: a.visual,
                      stage: a.lifeStage,
                      type: a.type,
                      hasProfession: a.hasProfession,
                      lookOffset: animatedLook,
                      expression: expression,
                      blink: blink,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _DivanOrnament extends StatelessWidget {
  final Color accent;
  const _DivanOrnament({required this.accent});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Container(height: 1, color: AppUi.line)),
      const SizedBox(width: 9),
      Transform.rotate(
        angle: pi / 4,
        child: Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            border: Border.all(color: accent.withValues(alpha: .6)),
          ),
        ),
      ),
      const SizedBox(width: 9),
      Expanded(child: Container(height: 1, color: AppUi.line)),
    ],
  );
}

class _DivanOptionDeck extends StatelessWidget {
  final List<PetitionOption> options;
  final Color accent;
  final void Function(PetitionOption) onChoose;
  final void Function(PetitionOption, bool) onHover;
  final String? Function(PetitionOption)? blockedReason;
  final bool dense;

  const _DivanOptionDeck({
    required this.options,
    required this.accent,
    required this.onChoose,
    required this.onHover,
    required this.blockedReason,
    required this.dense,
  });

  @override
  Widget build(BuildContext context) {
    final columns = options.length <= 3 ? 1 : 2;
    final rows = (options.length / columns).ceil();
    return Column(
      children: [
        for (var row = 0; row < rows; row++) ...[
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var column = 0; column < columns; column++) ...[
                  if (row * columns + column < options.length)
                    Expanded(
                      child: _DivanChoiceCard(
                        option: options[row * columns + column],
                        accent: accent,
                        blockedReason: blockedReason?.call(
                          options[row * columns + column],
                        ),
                        onTap:
                            blockedReason?.call(
                                  options[row * columns + column],
                                ) ==
                                null
                            ? () => onChoose(options[row * columns + column])
                            : null,
                        onHover: onHover,
                        compact: columns > 1 || dense,
                      ),
                    )
                  else
                    const Expanded(child: SizedBox.shrink()),
                  if (column != columns - 1) SizedBox(width: dense ? 7 : 10),
                ],
              ],
            ),
          ),
          if (row != rows - 1) SizedBox(height: dense ? 7 : 10),
        ],
      ],
    );
  }
}

class _DivanChoiceCard extends StatefulWidget {
  final PetitionOption option;
  final Color accent;
  final String? blockedReason;
  final VoidCallback? onTap;
  final void Function(PetitionOption, bool) onHover;
  final bool compact;

  const _DivanChoiceCard({
    required this.option,
    required this.accent,
    required this.blockedReason,
    required this.onTap,
    required this.onHover,
    required this.compact,
  });

  @override
  State<_DivanChoiceCard> createState() => _DivanChoiceCardState();
}

class _DivanChoiceCardState extends State<_DivanChoiceCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final blocked = widget.blockedReason != null;
    final o = widget.option;
    final chips = o.effectChips;
    return MouseRegion(
      cursor: blocked ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
      onEnter: (_) {
        if (!blocked) {
          setState(() => _hover = true);
          widget.onHover(widget.option, true);
        }
      },
      onExit: (_) {
        setState(() => _hover = false);
        widget.onHover(widget.option, false);
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _hover
                  ? [const Color(0xFF252930), const Color(0xFF171A1F)]
                  : [const Color(0xFF1A1D22), const Color(0xFF101216)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hover ? widget.accent.withValues(alpha: .82) : AppUi.line,
              width: _hover ? 1.4 : 1,
            ),
            boxShadow: _hover
                ? [
                    BoxShadow(
                      color: widget.accent.withValues(alpha: .18),
                      blurRadius: 18,
                    ),
                  ]
                : const [BoxShadow(color: Color(0x66000000), blurRadius: 8)],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Stack(
              children: [
                Opacity(
                  opacity: blocked ? .42 : 1,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: widget.compact ? 3 : 4,
                        child: OptionSceneCard(
                          scene: optionSceneFor(o),
                          height: double.infinity,
                        ),
                      ),
                      Expanded(
                        flex: widget.compact ? 6 : 7,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            widget.compact ? 10 : 18,
                            widget.compact ? 9 : 16,
                            widget.compact ? 8 : 14,
                            widget.compact ? 8 : 13,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _divanUpper(o.label),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppUi.title.copyWith(
                                  fontSize: widget.compact ? 11 : 16,
                                  height: 1.15,
                                  letterSpacing: widget.compact ? .8 : 1.4,
                                ),
                              ),
                              SizedBox(height: widget.compact ? 4 : 8),
                              Text(
                                o.detail,
                                maxLines: widget.compact ? 2 : 3,
                                overflow: TextOverflow.ellipsis,
                                style: AppUi.body.copyWith(
                                  color: AppUi.textLo,
                                  fontSize: widget.compact ? 9 : 12,
                                  height: 1.35,
                                ),
                              ),
                              if (chips.isNotEmpty) ...[
                                SizedBox(height: widget.compact ? 6 : 12),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 5,
                                  children: [
                                    for (final chip in chips.take(3))
                                      _DivanEffectChip(
                                        icon: chip.$1,
                                        label: chip.$2,
                                        compact: widget.compact,
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (blocked)
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppUi.surface0.withValues(alpha: .95),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppUi.rust),
                      ),
                      child: Text(
                        widget.blockedReason!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: AppUi.label.copyWith(
                          color: AppUi.rust,
                          fontSize: 8,
                        ),
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
}

class _DivanEffectChip extends StatelessWidget {
  final String icon;
  final String label;
  final bool compact;

  const _DivanEffectChip({
    required this.icon,
    required this.label,
    required this.compact,
  });

  Color get _color {
    if (icon == '📜') return AppUi.accent;
    if (label == '▲') return AppUi.sage;
    if (label == '▼' || label.startsWith('-')) return AppUi.rust;
    if (icon == '🧥') return AppUi.gold;
    return AppUi.sage;
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: compact ? 6 : 9,
      vertical: compact ? 3 : 5,
    ),
    decoration: BoxDecoration(
      color: _color.withValues(alpha: .13),
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: _color.withValues(alpha: .55)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: TextStyle(fontSize: compact ? 10 : 13)),
        const SizedBox(width: 5),
        Text(
          label,
          style: AppUi.number.copyWith(
            color: _color,
            fontSize: compact ? 9 : 12,
          ),
        ),
      ],
    ),
  );
}

class _DivanFooter extends StatelessWidget {
  final bool forced;
  final bool mustChoose;
  final String dismissHint;
  final Color accent;
  final VoidCallback? onDismiss;

  const _DivanFooter({
    required this.forced,
    required this.mustChoose,
    required this.dismissHint,
    required this.accent,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final text = mustChoose
        ? 'BU KARARI SEN VERECEKSİN'
        : forced
        ? 'MÜHLET DOLDU · BEKLETMENİN BEDELİ İŞLİYOR'
        : _divanUpper(dismissHint);
    final color = forced
        ? AppUi.rust
        : mustChoose
        ? accent
        : AppUi.textLo;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onDismiss,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Color(0xFF101216),
          border: Border(top: BorderSide(color: AppUi.line)),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: AppUi.label.copyWith(
            color: color,
            fontSize: 10,
            letterSpacing: 1.8,
          ),
        ),
      ),
    );
  }
}
