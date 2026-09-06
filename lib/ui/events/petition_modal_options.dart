part of 'petition_modal.dart';

/// SEÇENEK KARTLARI — seçenek şeridi ve kart gövdeleri (grid/yoğun), etki tabletleri.
/// Kararlar YATAY kart şeridi. Her seçenek eylemini canlandıran 2B sahneyle
/// taçlanmış bir kart (Reigns/Total War hissi). Az seçenek (2) ortalanır ve
/// panele yayılır; masaüstünde çok seçenek yatay kaydırılır. Telefonda bütün
/// kararlar sabit bir ızgarada görünür; karar ekranı kaydırma istemez.
class _OptionStrip extends StatefulWidget {
  final List<PetitionOption> options;
  final Color accent;
  final void Function(PetitionOption) onChoose;
  final String? Function(PetitionOption)? blockedReason;
  final void Function(PetitionOption, bool)? onPressChange;

  /// Telefon yatayda pano iki sütuna açılır ve kararlar SAĞ sütunda alt alta
  /// dizilir — dar bir sütunda yatay kart şeridi tek kart bile göstermezdi.
  final bool vertical;
  const _OptionStrip({
    required this.options,
    required this.accent,
    required this.onChoose,
    this.blockedReason,
    this.onPressChange,
    this.vertical = false,
  });
  @override
  State<_OptionStrip> createState() => _OptionStripState();
}

class _OptionStripState extends State<_OptionStrip> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final opts = widget.options;
    // 3'e kadar seçenek panele sığar → yay (Expanded). Fazlası kaydırılır.
    final fits = opts.length <= 3;

    Widget card(
      PetitionOption o, {
      bool dense = false,
      bool gridCompact = false,
    }) {
      final reason = widget.blockedReason?.call(o);
      return _OptionCard(
        option: o,
        accent: widget.accent,
        dense: dense,
        gridCompact: gridCompact,
        blockedReason: reason,
        onTap: reason == null ? () => widget.onChoose(o) : null,
        onPressChange: reason == null ? widget.onPressChange : null,
      );
    }

    if (widget.vertical) {
      final columns = opts.length > 3 ? 2 : 1;
      final rows = (opts.length / columns).ceil();
      return Column(
        children: [
          for (var row = 0; row < rows; row++) ...[
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var column = 0; column < columns; column++) ...[
                    if (row * columns + column < opts.length)
                      Expanded(
                        child: card(
                          opts[row * columns + column],
                          dense: columns == 1,
                          gridCompact: columns > 1,
                        ),
                      )
                    else
                      const Expanded(child: SizedBox.shrink()),
                    if (column != columns - 1) const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
            if (row != rows - 1) const SizedBox(height: 6),
          ],
        ],
      );
    }

    if (fits) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int i = 0; i < opts.length; i++) ...[
              Expanded(child: card(opts[i])),
              if (i != opts.length - 1) const SizedBox(width: 9),
            ],
          ],
        ),
      );
    }

    // Kaydırmalı şerit — sabit kart genişliği + kenar "devamı var" ipucu.
    return SizedBox(
      height: 214,
      child: ShaderMask(
        shaderCallback: (rect) => const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0x00000000),
            Color(0xFFFFFFFF),
            Color(0xFFFFFFFF),
            Color(0x00000000),
          ],
          stops: [0.0, 0.035, 0.965, 1.0],
        ).createShader(rect),
        blendMode: BlendMode.dstIn,
        child: ListView.separated(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          itemCount: opts.length,
          separatorBuilder: (_, _) => const SizedBox(width: 9),
          itemBuilder: (_, i) => SizedBox(width: 156, child: card(opts[i])),
        ),
      ),
    );
  }
}

/// Tek karar kartı — üstte eylemi canlandıran 2B sahne (bağışla/cezalandır/
/// sür/idam/kürek), altında başlık + kısa flavor + SONUÇ ikon tabletleri.
/// Hover'da ton-aksanlı kenar + parıltı; dokun = kararı uygula.
class _OptionCard extends StatefulWidget {
  final PetitionOption option;
  final Color accent;
  final VoidCallback? onTap;
  final String? blockedReason;
  final void Function(PetitionOption, bool)? onPressChange;

  /// YOĞUN varyant — sahne üstte değil SOLDA, yazı sağda. Telefon yatayda
  /// kararlar dar bir sütuna dizildiği için dikey kart (84dp sahne + 3 satır
  /// metin) sütuna iki karttan fazlasını sığdırmıyordu.
  final bool dense;
  final bool gridCompact;
  const _OptionCard({
    required this.option,
    required this.accent,
    required this.onTap,
    this.blockedReason,
    this.onPressChange,
    this.dense = false,
    this.gridCompact = false,
  });
  @override
  State<_OptionCard> createState() => _OptionCardState();
}

class _OptionCardState extends State<_OptionCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final o = widget.option;
    final accent = widget.accent;
    final chips = o.effectChips;
    final blocked = widget.blockedReason != null;
    return MouseRegion(
      onEnter: (_) {
        if (!blocked) setState(() => _hover = true);
      },
      onExit: (_) => setState(() => _hover = false),
      cursor: blocked ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: blocked
            ? null
            : (_) => widget.onPressChange?.call(widget.option, true),
        onTapUp: blocked
            ? null
            : (_) => widget.onPressChange?.call(widget.option, false),
        onTapCancel: blocked
            ? null
            : () => widget.onPressChange?.call(widget.option, false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: blocked
                ? AppUi.surface1.withValues(alpha: 0.62)
                : _hover
                ? Color.alphaBlend(
                    accent.withValues(alpha: 0.12),
                    AppUi.surface2,
                  )
                : AppUi.surface1,
            borderRadius: BorderRadius.circular(AppUi.radiusSm),
            border: Border.all(
              color: _hover ? accent : AppUi.line,
              width: _hover ? 1.5 : 1,
            ),
            boxShadow: _hover
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.28),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppUi.radiusSm),
            child: Stack(
              children: [
                Opacity(
                  opacity: blocked ? 0.48 : 1,
                  child: widget.gridCompact
                      ? _gridBody(o, chips)
                      : widget.dense
                      ? _denseBody(o, chips)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Üst: eylem sahnesi (kartın başrolü).
                            Stack(
                              children: [
                                OptionSceneCard(
                                  scene: optionSceneFor(o),
                                  height: 84,
                                ),
                                // Alt okunaklılık zemini (başlık sahneye binmesin).
                                const Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  height: 34,
                                  child: IgnorePointer(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Color(0x00000000),
                                            Color(0xCC14171C),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 10,
                                  right: 10,
                                  bottom: 7,
                                  child: Text(
                                    o.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppUi.bodyHi.copyWith(
                                      fontSize: 13.5,
                                      shadows: const [
                                        Shadow(
                                          color: Color(0xCC000000),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(11, 8, 11, 11),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    o.detail,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppUi.body.copyWith(
                                      fontSize: 10,
                                      height: 1.35,
                                      color: AppUi.textLo,
                                    ),
                                  ),
                                  if (chips.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 5,
                                      runSpacing: 5,
                                      children: [
                                        for (final d in chips)
                                          _effectTablet(d.$1, d.$2),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
                if (blocked)
                  Positioned(
                    left: 7,
                    right: 7,
                    bottom: 7,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppUi.surface0.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: AppUi.rust),
                      ),
                      child: Text(
                        widget.blockedReason!,
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

  /// Dört ve üzeri telefon kararı — iki sütunlu, kaydırmasız kısa kart.
  /// Başlık ve bedel ilk bakışta kalır; uzun açıklama tek satıra sıkışır.
  Widget _gridBody(PetitionOption o, List<(String, String)> chips) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            o.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppUi.bodyHi.copyWith(fontSize: 11.5),
          ),
          const SizedBox(height: 2),
          Text(
            o.detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppUi.body.copyWith(
              fontSize: 9,
              height: 1.2,
              color: AppUi.textLo,
            ),
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 5),
            Wrap(
              spacing: 3,
              runSpacing: 3,
              children: [
                for (final d in chips.take(2)) _effectTablet(d.$1, d.$2),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Yoğun (telefon) gövde — sahne SOLDA şerit olarak, başlık/etki sağda.
  /// Sahne kartın başrolü olmayı sürdürür ama kararın kendisini ekrandan
  /// itmez: bir sütuna üç-dört karar birden sığar.
  Widget _denseBody(PetitionOption o, List<(String, String)> chips) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 62,
            child: OptionSceneCard(scene: optionSceneFor(o), height: 76),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(9, 7, 9, 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    o.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppUi.bodyHi.copyWith(fontSize: 12.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    o.detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppUi.body.copyWith(
                      fontSize: 9.5,
                      height: 1.3,
                      color: AppUi.textLo,
                    ),
                  ),
                  if (chips.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final d in chips) _effectTablet(d.$1, d.$2),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Tek sonuç tableti — ikon + delta, sonucun rengiyle. Kararın bedeli/faydası
  /// okunmadan görülür.
  Widget _effectTablet(String icon, String label) {
    final color = _chipColor((icon, label));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 12.5)),
          const SizedBox(width: 4),
          Text(label, style: AppUi.number.copyWith(fontSize: 11, color: color)),
        ],
      ),
    );
  }

  // Fayda sage / bedel rust / yasa ember — sonuç renk dili.
  Color _chipColor((String, String) d) {
    if (d.$1 == '📜') return AppUi.accent; // yasa
    if (d.$2 == '▲') return AppUi.sage; // zümre sevinir
    if (d.$2 == '▼') return AppUi.rust; // zümre küser
    return d.$2.startsWith('-') ? AppUi.rust : AppUi.sage; // negatif/pozitif
  }
}
