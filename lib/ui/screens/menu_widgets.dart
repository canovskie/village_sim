part of 'main_menu_screen.dart';

// ANA MENÜ — kartlar, satırlar, hero bandı, çipler
// (Bu dosya main_menu_screen.dart bölünürken ayrıldı — sınıflar
//  aynen taşındı, tek satırı değişmedi.)

class _TitleBlock extends StatelessWidget {
  const _TitleBlock();
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 94,
          height: 94,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [Color(0x52FFD89D), Color(0x14E49139), Color(0x00E49139)],
              stops: [0.0, 0.58, 1.0],
            ),
            border: Border.all(color: const Color(0x33F7E8CF)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x44000000),
                blurRadius: 22,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: const GameLogo(size: 74),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BİR KÖYÜN HİKÂYESİ',
                style: AppUi.label.copyWith(
                  color: const Color(0xFFF4D8AB),
                  fontSize: 9,
                  letterSpacing: 3.0,
                  shadows: const [
                    Shadow(color: Color(0xCC101812), blurRadius: 8),
                  ],
                ),
              ),
              const SizedBox(height: 5),
              ShaderMask(
                shaderCallback: (r) => const LinearGradient(
                  colors: [Color(0xFFFFFFFF), Color(0xFFF0C27C)],
                ).createShader(r),
                child: const Text(
                  'LUW',
                  style: TextStyle(
                    fontFamily: AppUi.fontDisplay,
                    fontWeight: FontWeight.w700,
                    fontSize: 46,
                    height: 1,
                    letterSpacing: 13,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Color(0xCC000000),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'ATEŞİ KORU  ·  KÖYÜ KUR  ·  HİKÂYENİ YAZ',
                style: AppUi.label.copyWith(
                  color: AppUi.textHi.withValues(alpha: 0.76),
                  fontSize: 8.5,
                  letterSpacing: 1.45,
                  shadows: const [
                    Shadow(color: Color(0xDD101812), blurRadius: 7),
                  ],
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'SÜRÜM 0.1.0',
                style: AppUi.label.copyWith(
                  color: AppUi.textHi.withValues(alpha: 0.42),
                  fontSize: 8,
                  letterSpacing: 1.8,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Menü kartı (masaüstü) ───────────────────────────────────────────────────

class _MenuCard extends StatelessWidget {
  final VoidCallback onNewGame,
      onSettings,
      onAbout,
      onContinue,
      onLightEditor,
      onPlacementEditor,
      onAnimationRoom,
      onReferenceVillage;
  final bool hasSaves;

  const _MenuCard({
    required this.onNewGame,
    required this.onContinue,
    required this.onReferenceVillage,
    required this.hasSaves,
    required this.onSettings,
    required this.onAbout,
    required this.onLightEditor,
    required this.onPlacementEditor,
    required this.onAnimationRoom,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hasSaves ? 'KÖYÜNE DÖN' : 'YENİ BİR BAŞLANGIÇ',
          style: AppUi.label.copyWith(
            color: const Color(0xFFF1C588),
            fontSize: 9.5,
            letterSpacing: 2.8,
            shadows: const [Shadow(color: Color(0xDD000000), blurRadius: 7)],
          ),
        ),
        const SizedBox(height: 8),
        if (hasSaves) ...[
          _MenuRow(
            icon: GameIconData.home,
            label: 'DEVAM ET',
            note: 'Kaldığın köye dön',
            primary: true,
            onTap: onContinue,
            height: 76,
          ),
          const SizedBox(height: 4),
        ],
        _MenuRow(
          icon: GameIconData.flame,
          label: 'YENİ KÖY',
          note: 'Yeni bir yerleşim kur',
          primary: !hasSaves,
          onTap: onNewGame,
          height: 76,
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 44,
          child: Row(
            children: [
              Expanded(
                child: _MenuChip(
                  icon: GameIconData.gear,
                  label: 'AYARLAR',
                  onTap: onSettings,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MenuChip(
                  icon: GameIconData.scroll,
                  label: 'HAKKINDA',
                  onTap: onAbout,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const _SectionRule(label: 'GELİŞTİRİCİ ARAÇLARI'),
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(
              child: _MenuRow(
                icon: GameIconData.scroll,
                label: 'REFERANS KÖY',
                onTap: onReferenceVillage,
                height: 38,
                compact: true,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _MenuRow(
                icon: GameIconData.bolt,
                label: 'IŞIK EDİTÖRÜ',
                onTap: onLightEditor,
                height: 38,
                compact: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _MenuRow(
                icon: GameIconData.hammer,
                label: 'EBAT EDİTÖRÜ',
                onTap: onPlacementEditor,
                height: 38,
                compact: true,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _MenuRow(
                icon: GameIconData.play,
                label: 'ANİMASYONLAR',
                onTap: onAnimationRoom,
                height: 38,
                compact: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionRule extends StatelessWidget {
  final String label;
  const _SectionRule({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0x33F5E6CB), height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            label,
            style: AppUi.label.copyWith(
              color: AppUi.textLo,
              fontSize: 9,
              letterSpacing: 2.0,
            ),
          ),
        ),
        const Expanded(child: Divider(color: Color(0x33F5E6CB), height: 1)),
      ],
    );
  }
}

class _MenuRow extends StatefulWidget {
  final GameIconData icon;
  final String label;
  final String? note;
  final bool primary;
  final bool compact;
  final VoidCallback onTap;

  final double height;
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.note,
    this.primary = false,
    this.compact = false,
    this.height = 54,
  });

  @override
  State<_MenuRow> createState() => _MenuRowState();
}

class _MenuRowState extends State<_MenuRow> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final hot = _hover || _down;
    final lit = hot || widget.primary;
    const accent = AppUi.accent;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOut,
          height: widget.height,
          padding: EdgeInsets.symmetric(horizontal: widget.compact ? 10 : 14),
          transform: _down
              ? Matrix4.translationValues(0, 1, 0)
              : Matrix4.identity(),
          decoration: widget.compact
              ? BoxDecoration(
                  color: hot
                      ? const Color(0xCC283029)
                      : const Color(0x99161B18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: hot
                        ? accent.withValues(alpha: 0.68)
                        : const Color(0x26FFFFFF),
                  ),
                )
              : BoxDecoration(
                  gradient: LinearGradient(
                    colors: lit
                        ? [
                            accent.withValues(alpha: hot ? 0.24 : 0.16),
                            const Color(0x0018201A),
                          ]
                        : const [Color(0x2918201A), Color(0x0018201A)],
                    stops: const [0.0, 0.88],
                  ),
                  border: Border(
                    left: BorderSide(
                      color: lit ? accent : const Color(0x5CFFFFFF),
                      width: lit ? 3 : 1,
                    ),
                    bottom: BorderSide(
                      color: lit
                          ? const Color(0x4DE49139)
                          : const Color(0x24FFFFFF),
                    ),
                  ),
                ),
          child: Row(
            children: [
              // İkon madalyonu
              Container(
                width: widget.compact ? 26 : 38,
                height: widget.compact ? 26 : 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.compact ? 7 : 11),
                  color: lit
                      ? accent.withValues(alpha: 0.14)
                      : const Color(0x66101412),
                  border: Border.all(
                    color: lit
                        ? accent.withValues(alpha: 0.55)
                        : const Color(0x22FFFFFF),
                    width: 1,
                  ),
                ),
                child: GameIcon(
                  widget.icon,
                  size: widget.compact ? 13 : 18,
                  color: lit ? AppUi.accentSoft : AppUi.textMid,
                ),
              ),
              SizedBox(width: widget.compact ? 9 : 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        style: TextStyle(
                          fontFamily: AppUi.fontDisplay,
                          fontWeight: FontWeight.w700,
                          fontSize: widget.compact ? 11 : 16,
                          letterSpacing: widget.compact ? 1.1 : 2.0,
                          color: lit ? AppUi.textHi : AppUi.textMid,
                        ),
                      ),
                    ),
                    if (widget.note != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.note!,
                        maxLines: 1,
                        style: AppUi.body.copyWith(
                          color: lit ? AppUi.textMid : AppUi.textLo,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!widget.compact)
                GameIcon(
                  GameIconData.chevron,
                  size: 14,
                  color: lit ? accent : AppUi.textLo.withValues(alpha: 0.6),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Dokunma yerleşimi: kimlik şeridi ───────────────────────────────────────

/// Madalyon + kelime işareti + slogan YAN YANA. Masaüstündeki dikey kompozisyon
/// (madalyon, altında başlık, altında kural, altında slogan) alçak ekranda
/// tek başına 250px yiyordu; yatayda aynı bilgi 78px'e sığar.
class _HeroBand extends StatelessWidget {
  final double height;
  final bool short;
  const _HeroBand({required this.height, required this.short});

  @override
  Widget build(BuildContext context) {
    final logoSize = (height * 0.86).clamp(60.0, 94.0);
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: logoSize,
            height: logoSize,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Color(0x4DFFD89D),
                  Color(0x15E49139),
                  Color(0x00E49139),
                ],
                stops: [0.0, 0.6, 1.0],
              ),
            ),
            child: GameLogo(size: logoSize * 0.76),
          ),
          SizedBox(width: short ? 12 : 18),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (r) => const LinearGradient(
                    colors: [Color(0xFFFFFFFF), Color(0xFFF2C681)],
                  ).createShader(r),
                  child: Text(
                    'LUW',
                    style: TextStyle(
                      fontFamily: AppUi.fontDisplay,
                      fontWeight: FontWeight.w700,
                      fontSize: short ? 28 : 38,
                      height: 1,
                      letterSpacing: short ? 8 : 11,
                      color: Colors.white,
                      shadows: const [
                        Shadow(
                          color: Color(0xCC000000),
                          blurRadius: 12,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'ATEŞİ KORU  ·  KÖYÜ KUR  ·  HİKÂYENİ YAZ',
                    style: AppUi.label.copyWith(
                      color: AppUi.textHi.withValues(alpha: 0.8),
                      fontSize: short ? 8.5 : 10,
                      letterSpacing: short ? 1.35 : 1.8,
                      shadows: const [
                        Shadow(color: Color(0xDD101812), blurRadius: 7),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0x7A101512),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0x28FFFFFF)),
            ),
            child: Text(
              'SÜRÜM 0.1.0',
              style: AppUi.label.copyWith(
                color: AppUi.textHi.withValues(alpha: 0.6),
                fontSize: 8.5,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Dokunma yerleşimi: birincil kartlar ────────────────────────────────────

/// Oyuncunun menüde yaptığı iki şey. Diğer her şeyden BÜYÜK olmaları
/// kademelendirmenin kendisi: 8 eşit satırda hiyerarşi yoktu, göz nereye
/// gideceğini bilmiyordu.
class _PrimaryRow extends StatelessWidget {
  final double height;
  final bool short, hasSaves;
  final VoidCallback onContinue, onNewGame;
  const _PrimaryRow({
    required this.height,
    required this.short,
    required this.hasSaves,
    required this.onContinue,
    required this.onNewGame,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Column(
        children: [
          if (hasSaves) ...[
            Expanded(
              child: _PrimaryCard(
                icon: GameIconData.home,
                label: 'DEVAM ET',
                note: 'kaldığın köye dön',
                primary: true,
                height: (height - 8) / 2,
                short: short,
                onTap: onContinue,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Expanded(
            child: _PrimaryCard(
              icon: GameIconData.flame,
              label: 'YENİ KÖY',
              note: 'ateşi yeniden yak',
              primary: !hasSaves,
              height: hasSaves ? (height - 8) / 2 : height,
              short: short,
              onTap: onNewGame,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryCard extends StatefulWidget {
  final GameIconData icon;
  final String label, note;
  final bool primary, short;
  final double height;
  final VoidCallback onTap;
  const _PrimaryCard({
    required this.icon,
    required this.label,
    required this.note,
    required this.primary,
    required this.short,
    required this.height,
    required this.onTap,
  });

  @override
  State<_PrimaryCard> createState() => _PrimaryCardState();
}

class _PrimaryCardState extends State<_PrimaryCard> {
  bool _hover = false, _down = false;

  @override
  Widget build(BuildContext context) {
    final hot = _hover || _down;
    final lit = hot || widget.primary;
    const accent = AppUi.accent;
    final disc = (widget.height * 0.54).clamp(40.0, 58.0);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          transform: _down
              ? Matrix4.translationValues(1.5, 0, 0)
              : Matrix4.identity(),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: lit
                  ? [
                      accent.withValues(alpha: hot ? 0.32 : 0.22),
                      const Color(0xE6171C18),
                      const Color(0xB0101512),
                    ]
                  : const [
                      Color(0xD9212822),
                      Color(0xE6171C18),
                      Color(0xB0101512),
                    ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: lit
                  ? accent.withValues(alpha: 0.72)
                  : const Color(0x38FFFFFF),
              width: lit ? 1.5 : 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          padding: EdgeInsets.symmetric(horizontal: widget.short ? 16 : 22),
          child: Row(
            children: [
              Container(
                width: disc,
                height: disc,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(disc * 0.28),
                  color: lit
                      ? accent.withValues(alpha: 0.16)
                      : const Color(0x66101412),
                  border: Border.all(
                    color: lit
                        ? accent.withValues(alpha: 0.55)
                        : const Color(0x28FFFFFF),
                    width: 1,
                  ),
                ),
                child: GameIcon(
                  widget.icon,
                  size: disc * 0.46,
                  color: lit ? AppUi.accentSoft : AppUi.textMid,
                ),
              ),
              SizedBox(width: widget.short ? 14 : 20),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      maxLines: 1,
                      style: TextStyle(
                        fontFamily: AppUi.fontDisplay,
                        fontWeight: FontWeight.w700,
                        fontSize: widget.short ? 17 : 21,
                        letterSpacing: 2.2,
                        height: 1,
                        color: lit ? AppUi.textHi : AppUi.textMid,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      widget.note,
                      maxLines: 1,
                      style: AppUi.body.copyWith(
                        color: lit ? AppUi.textMid : AppUi.textLo,
                        fontStyle: FontStyle.italic,
                        fontSize: widget.short ? 11 : 13,
                      ),
                    ),
                  ],
                ),
              ),
              GameIcon(
                GameIconData.chevron,
                size: 16,
                color: lit ? AppUi.accent : AppUi.textLo,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Dokunma yerleşimi: alt bant ────────────────────────────────────────────

/// İkincil kapılar solda (ayarlar · hakkında), GELİŞTİRİCİ araçları sağda
/// küçük rozet olarak. Dev girişleri oyuncu akışının parçası değil; oyun
/// menüsünde birincil eylemlerle aynı boyda durmaları yanlış kademelendirmeydi.
/// Rozetin adı uzun basınca (Tooltip) görünür.
class _BottomBand extends StatelessWidget {
  final double height;
  final VoidCallback onSettings,
      onAbout,
      onReferenceVillage,
      onLightEditor,
      onPlacementEditor,
      onAnimationRoom;
  const _BottomBand({
    required this.height,
    required this.onSettings,
    required this.onAbout,
    required this.onReferenceVillage,
    required this.onLightEditor,
    required this.onPlacementEditor,
    required this.onAnimationRoom,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _MenuChip(
                    icon: GameIconData.gear,
                    label: 'AYARLAR',
                    onTap: onSettings,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MenuChip(
                    icon: GameIconData.scroll,
                    label: 'HAKKINDA',
                    onTap: onAbout,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 52,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xE6222823), Color(0xE8171C19)],
                ),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: const Color(0x38FFFFFF)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x44000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _DevBadge(
                    icon: GameIconData.scroll,
                    tip: 'Referans Köy',
                    onTap: onReferenceVillage,
                  ),
                  _DevBadge(
                    icon: GameIconData.bolt,
                    tip: 'Işık Editörü',
                    onTap: onLightEditor,
                  ),
                  _DevBadge(
                    icon: GameIconData.hammer,
                    tip: 'Ebat Editörü',
                    onTap: onPlacementEditor,
                  ),
                  _DevBadge(
                    icon: GameIconData.play,
                    tip: 'Animasyonlar',
                    onTap: onAnimationRoom,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuChip extends StatefulWidget {
  final GameIconData icon;
  final String label;
  final VoidCallback onTap;
  const _MenuChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_MenuChip> createState() => _MenuChipState();
}

class _MenuChipState extends State<_MenuChip> {
  bool _hover = false, _down = false;

  @override
  Widget build(BuildContext context) {
    final hot = _hover || _down;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOut,
          // Dokunma tabanı: kapsül bandın tamamını doldurur (>= 44dp).
          height: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: hot
                  ? const [Color(0xF0323932), Color(0xF0222822)]
                  : const [Color(0xE6222823), Color(0xE8171C19)],
            ),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: hot
                  ? AppUi.accent.withValues(alpha: 0.75)
                  : const Color(0x38FFFFFF),
              width: hot ? 1.4 : 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x44000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GameIcon(
                widget.icon,
                size: 15,
                color: hot ? AppUi.accentSoft : AppUi.textMid,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      fontFamily: AppUi.fontDisplay,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      letterSpacing: 1.4,
                      color: hot ? AppUi.textHi : AppUi.textMid,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DevBadge extends StatefulWidget {
  final GameIconData icon;
  final String tip;
  final VoidCallback onTap;
  const _DevBadge({required this.icon, required this.tip, required this.onTap});

  @override
  State<_DevBadge> createState() => _DevBadgeState();
}

class _DevBadgeState extends State<_DevBadge> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          // 44dp dokunma tabanı — rozet küçük görünür, hedefi küçülmez.
          child: SizedBox(
            width: MobileUi.tap,
            height: MobileUi.tap,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 130),
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _hover
                      ? AppUi.accent.withValues(alpha: 0.15)
                      : const Color(0x30101412),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: _hover
                        ? AppUi.accent.withValues(alpha: 0.6)
                        : const Color(0x24FFFFFF),
                  ),
                ),
                child: GameIcon(
                  widget.icon,
                  size: 17,
                  color: _hover ? AppUi.accentSoft : AppUi.textMid,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Güneş + hâle ───────────────────────────────────────────────────────────
