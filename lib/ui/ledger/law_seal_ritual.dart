part of 'law_book_panel.dart';

/// MÜHÜR RİTÜELİ — bir hükmün kendi meclisi: etki/gelenek/idame satırları, ferman, hane tepkileri, mühür düğmesi.
/// Kol rengi — nizam kızıl (kılıç), dergâh teal (kandil), geçim adaçayı (toprak).
Color branchColor(LawBranch b) => switch (b) {
  LawBranch.gecim => AppUi.sage,
  LawBranch.nizam => AppUi.rust,
  LawBranch.dergah => AppUi.info,
};

/// Bir fermanın GÜNLÜK idamesi, okunur tek satır — yoksa null.
/// "her gün" bilerek yazılı: tek seferlik bedelle karışmasın.
String? upkeepLabel(LawDef l) {
  final parts = <String>[];
  if (l.goldPerDay != 0) {
    parts.add('${l.goldPerDay > 0 ? '+' : ''}${l.goldPerDay} akçe');
  }
  if (l.foodPerDay != 0) {
    parts.add('${l.foodPerDay > 0 ? '+' : ''}${l.foodPerDay} kile');
  }
  return parts.isEmpty ? null : '${parts.join(' · ')}/gün';
}

/// Mühürlü fermanların TOPLAM günlük idamesi — defterin altında duran hesap.
String? totalUpkeepLabel(Set<String> sealed) {
  final (gold, food) = LawBook.dailyUpkeep(sealed);
  if (gold == 0 && food == 0) return null;
  final parts = <String>[];
  if (gold != 0) parts.add('${gold > 0 ? '+' : ''}$gold akçe');
  if (food != 0) parts.add('${food > 0 ? '+' : ''}$food kile');
  return '${parts.join(' · ')} / gün';
}

// ─── MÜHÜR RİTÜELİ (meclis) ─────────────────────────────────────────────────

class LawSealRitual extends StatefulWidget {
  final LawDef law;
  final int seed;

  /// Mühürlü fermanlar — pusula önizlemesi ("bu ferman ibreyi nereye iter")
  /// mevcut konumu bilmeden çizilemez.
  final Set<String> sealed;

  final VoidCallback onSeal;
  final VoidCallback onDismiss;
  final String traditionLine;

  const LawSealRitual({
    super.key,
    required this.law,
    required this.onSeal,
    required this.onDismiss,
    this.sealed = const {},
    this.seed = 0,
    this.traditionLine = '',
  });

  @override
  State<LawSealRitual> createState() => _LawSealRitualState();
}

class _LawSealRitualState extends State<LawSealRitual>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press =
      AnimationController(
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
                          if (widget.traditionLine.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _traditionLine(),
                          ],
                          // GÜNLÜK İDAME — kararın verildiği yerde dursun.
                          // Tek seferlik bedel `_council`/özet içinde geçiyor;
                          // bu satır "her sabah" olanı söyler.
                          _upkeepLine(),
                          // NE YAPAR'ın hemen altında NEREYE GÖTÜRÜR: mühür
                          // basmadan önce oyuncu ibrenin nereye kayacağını
                          // görür (kimlik değişecekse eski → yeni).
                          const SizedBox(height: 10),
                          LawCompassNudge(sealed: widget.sealed, lawId: law.id),
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
      SemanticIcon(
        law.icon,
        size: 26,
        color: accent,
        fallback: GameIconData.scales,
      ),
      const SizedBox(width: 11),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'MECLİS TOPLANDI',
              style: AppUi.label.copyWith(
                fontSize: 8.5,
                color: accent,
                letterSpacing: 1.6,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              law.title,
              style: AppUi.title.copyWith(fontSize: 17, height: 1.15),
            ),
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
          child: Text(
            s,
            style: AppUi.body.copyWith(
              fontSize: 11.5,
              height: 1.35,
              color: AppUi.textMid,
            ),
          ),
        ),
      ],
    );
  }

  Widget _traditionLine() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('🔥', style: TextStyle(fontSize: 12)),
      const SizedBox(width: 7),
      Expanded(
        child: Text(
          widget.traditionLine,
          style: AppUi.body.copyWith(
            fontSize: 11.5,
            height: 1.35,
            color: AppUi.gold,
          ),
        ),
      ),
    ],
  );

  /// HER SABAH NE OLUR — mühürlü kaldığı sürece keseden/ambardan akan.
  /// Yoksa hiç yer kaplamaz.
  Widget _upkeepLine() {
    final label = upkeepLabel(law);
    if (label == null) return const SizedBox.shrink();
    final drain = law.goldPerDay < 0 || law.foodPerDay < 0;
    final c = drain ? AppUi.rust : AppUi.sage;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            drain ? Icons.trending_down : Icons.trending_up,
            size: 13,
            color: c,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              'Günlük idame: $label',
              style: AppUi.body.copyWith(
                fontSize: 11.5,
                height: 1.35,
                color: c,
              ),
            ),
          ),
        ],
      ),
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
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          child: Container(width: 2.5, color: accent.withValues(alpha: 0.75)),
        ),
      ],
    ),
  );

  Widget _council() {
    final moods = {for (final (e, d) in law.seal.estateMood) e: d};
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [for (final e in Estate.values) _estateRow(e, moods[e] ?? 0.0)],
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
            child: SemanticIcon(
              e.icon,
              size: 13,
              color: color,
              fallback: GameIconData.people,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              line,
              style: AppUi.body.copyWith(
                fontSize: 10.5,
                height: 1.35,
                color: color,
              ),
            ),
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
                fontSize: 10.5,
                height: 1.35,
                color: AppUi.rust,
              ),
            ),
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
                width: 1 + t,
              ),
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
                        child: GameIcon(
                          GameIconData.scales,
                          size: 15,
                          color: Color.lerp(accent, AppUi.textHi, t)!,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Text(
                        t > 0.02 ? 'BASILI TUT…' : law.seal.label.toUpperCase(),
                        style: AppUi.button.copyWith(
                          fontSize: 11.5,
                          color: Color.lerp(AppUi.textMid, AppUi.textHi, t),
                          letterSpacing: 1.4,
                        ),
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
