part of 'petition_modal.dart';

/// DİLEKÇE BAŞLIĞI — hero, madalyon, karar bağlamı, köy hâli şeridi ve bedel satırı.
/// Dilekçe HERO bloğu — illüstrasyon panosu + üstte DİLEKÇE künyesi/not, altta
/// gradient zemin üstüne madalyon portre + oyma başlık + sunan. Total War olay
/// panosunun "tek nefeste oku" hissi: resim konuşur, yazı asgaridir.
class _PetitionHero extends StatelessWidget {
  final Petition petition;
  final Color accent;
  final VillagerEntity? author;
  final VoidCallback? onAuthorTap;
  final String kicker;
  final Key? portraitKey;
  final Offset portraitLookOffset;
  final PortraitExpression portraitExpression;
  final bool portraitBlink;

  /// Hero yüksekliği — telefon yatayda (iki sütun) alçaltılır, yoksa 196dp'lik
  /// masaüstü hero'su 414dp'lik ekranın yarısını yerdi.
  final double height;
  const _PetitionHero({
    required this.petition,
    required this.accent,
    this.author,
    this.onAuthorTap,
    this.kicker = 'DİLEKÇE',
    this.height = 196,
    this.portraitKey,
    this.portraitLookOffset = Offset.zero,
    this.portraitExpression = PortraitExpression.neutral,
    this.portraitBlink = false,
  });

  @override
  Widget build(BuildContext context) {
    final a = author;
    final artwork = petitionArtworkAsset(petition);
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          // Full-bleed prosedürel illüstrasyon (kendi kenarlığını çizmez).
          Positioned.fill(
            child: artwork == null
                ? PetitionSceneCard(
                    petition: petition,
                    height: height,
                    drawBorder: false,
                  )
                : EventArtwork(asset: artwork, height: height, accent: accent),
          ),
          // Alt okunaklılık zemini — başlık/portre için koyu gradient.
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 116,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0xE6100E0B)],
                  ),
                ),
              ),
            ),
          ),
          // Üst künye şeridi: DİLEKÇE etiketi + (varsa) bağlam notu rozeti.
          Positioned(
            left: 14,
            right: 14,
            top: 12,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kicker(kicker),
                const Spacer(),
                if (petition.note != null)
                  Flexible(
                    // AppChip DEĞİL: chip'in Text'i kırpılmadığı için uzun not
                    // hero satırını taşırıyordu (RenderFlex overflow). Bu rozet
                    // ellipsis yapar → dar hero'da güvenle sığar.
                    child: _noteChip(
                      petition.note!,
                      petition.note!.startsWith('✦') ? AppUi.gold : AppUi.rust,
                    ),
                  ),
              ],
            ),
          ),
          // Alt blok: madalyon portre/glif + başlık + sunan.
          Positioned(
            left: 14,
            right: 14,
            bottom: 12,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (a != null)
                  GestureDetector(
                    onTap: onAuthorTap,
                    child: _Medallion.portrait(
                      a,
                      accent,
                      key: portraitKey,
                      lookOffset: portraitLookOffset,
                      expression: portraitExpression,
                      blink: portraitBlink,
                    ),
                  )
                else
                  _Medallion.glyph(petition.icon, accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        petition.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppUi.title.copyWith(
                          fontSize: 18,
                          height: 1.08,
                          shadows: const [
                            Shadow(color: Color(0xCC000000), blurRadius: 8),
                          ],
                        ),
                      ),
                      const SizedBox(height: 3),
                      if (a != null)
                        GestureDetector(
                          onTap: onAuthorTap,
                          child: Text(
                            '${a.isMale ? '♂' : '♀'} ${a.name} · ${a.hasProfession ? a.type.displayName : a.lifeStage.label}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppUi.body.copyWith(
                              fontSize: 11,
                              color: accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      else
                        Text(
                          petition.petitioner,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppUi.body.copyWith(
                            fontSize: 11,
                            color: AppUi.textMid,
                          ),
                        ),
                      // Yazar hanesi adına konuşur — politik katman hane-bazlı.
                      if (a != null && a.houseLabel.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          '⌂ ${a.houseLabel} adına',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppUi.body.copyWith(
                            fontSize: 10,
                            color: AppUi.textMid,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kicker(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xB3100E0B),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: accent.withValues(alpha: 0.55), width: 1),
    ),
    child: Text(text, style: AppUi.label.copyWith(color: accent, fontSize: 9)),
  );

  /// Hero not rozeti — AppChip'in kırpılmayan Text'i yerine ellipsis'li sürüm
  /// (uzun bağlam notu dar hero satırını taşırmasın).
  Widget _noteChip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.7), width: 1),
    ),
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppUi.button.copyWith(
        fontSize: 9.5,
        letterSpacing: 1.0,
        color: AppUi.textHi,
      ),
    ),
  );
}

/// Hero üzerindeki dairesel madalyon — dilekçeyi getiren köylünün portresi ya
/// da (yazar yoksa) konu glifi. İnce altın halka + ton-aksanlı dış glow ile
/// illüstrasyonun alt kenarına oturur (Total War portre madalyonu hissi).
/// Portre varyantında dokununca bilgi/aile paneli açılır (modal sarar).
class _Medallion extends StatelessWidget {
  final VillagerEntity? villager;
  final String? glyph;
  final Color accent;
  final Offset lookOffset;
  final PortraitExpression expression;
  final bool blink;
  const _Medallion._({
    super.key,
    this.villager,
    this.glyph,
    required this.accent,
    this.lookOffset = Offset.zero,
    this.expression = PortraitExpression.neutral,
    this.blink = false,
  });

  factory _Medallion.portrait(
    VillagerEntity v,
    Color accent, {
    Key? key,
    Offset lookOffset = Offset.zero,
    PortraitExpression expression = PortraitExpression.neutral,
    bool blink = false,
  }) => _Medallion._(
    key: key,
    villager: v,
    accent: accent,
    lookOffset: lookOffset,
    expression: expression,
    blink: blink,
  );
  factory _Medallion.glyph(String icon, Color accent) =>
      _Medallion._(glyph: icon, accent: accent);

  static const double _size = 60;

  @override
  Widget build(BuildContext context) {
    final v = villager;
    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppUi.surface0,
        // Çift halka: dış ince altın + iç ton-aksan (oyma madalyon hissi).
        border: Border.all(
          color: AppUi.gold.withValues(alpha: 0.55),
          width: 1.6,
        ),
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: 0.45), blurRadius: 14),
          const BoxShadow(color: Color(0x99000000), blurRadius: 6),
        ],
      ),
      padding: const EdgeInsets.all(2),
      child: ClipOval(
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: accent.withValues(alpha: 0.8),
              width: 1.2,
            ),
          ),
          child: ClipOval(
            child: v != null
                ? TweenAnimationBuilder<Offset>(
                    tween: Tween(end: lookOffset),
                    duration: const Duration(milliseconds: 90),
                    curve: Curves.easeOut,
                    builder: (context, animatedLook, _) => CustomPaint(
                      key: const ValueKey('compact-divan-portrait-paint'),
                      painter: PortraitPainter(
                        visual: v.visual,
                        stage: v.lifeStage,
                        type: v.type,
                        hasProfession: v.hasProfession,
                        lookOffset: animatedLook,
                        expression: expression,
                        blink: blink,
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      glyph ?? '📜',
                      style: const TextStyle(fontSize: _size * 0.44),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _DecisionContext extends StatelessWidget {
  final String text;
  final bool compact;

  const _DecisionContext({required this.text, this.compact = false});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: EdgeInsets.symmetric(
      horizontal: compact ? 8 : 11,
      vertical: compact ? 6 : 8,
    ),
    decoration: BoxDecoration(
      color: AppUi.accent.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(AppUi.radiusSm),
      border: Border.all(color: AppUi.accent.withValues(alpha: .32)),
    ),
    child: Text(
      text,
      textAlign: TextAlign.center,
      maxLines: compact ? 3 : 4,
      overflow: TextOverflow.ellipsis,
      style: AppUi.body.copyWith(
        color: AppUi.textHi,
        fontSize: compact ? 9.5 : 10.5,
        height: 1.35,
      ),
    ),
  );
}

/// Köy durumu şeridi — karar anında moral/nüfus/yiyecek/altın özeti. Oyuncu
/// dilekçeyi köyün gerçek hâliyle tartar. Koyu iç band.
class _VillageStateStrip extends StatelessWidget {
  final ({double morale, int population, int food, int gold}) state;
  final bool compact;
  const _VillageStateStrip({required this.state, this.compact = false});

  /// Morale göre yüz — köyün ruh hâlinin tek bakışta okunması.
  String get _moraleFace {
    final m = state.morale;
    if (m >= 0.75) return '😄';
    if (m >= 0.55) return '🙂';
    if (m >= 0.35) return '😐';
    if (m >= 0.2) return '🙁';
    return '😣';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 5 : 8,
      ),
      decoration: BoxDecoration(
        color: AppUi.surface0,
        borderRadius: BorderRadius.circular(AppUi.radiusSm),
        border: Border.all(color: AppUi.line, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _cell(
            emoji: _moraleFace,
            value: '${(state.morale * 100).round()}%',
            label: 'moral',
            color: AppUi.accent,
          ),
          _div(),
          _cell(
            icon: GameIconData.people,
            value: '${state.population}',
            label: 'nüfus',
            color: AppUi.textMid,
          ),
          _div(),
          _cell(
            icon: GameIconData.wheat,
            value: '${state.food}',
            label: 'yiyecek',
            color: AppUi.sage,
          ),
          _div(),
          _cell(
            icon: GameIconData.coin,
            value: '${state.gold}',
            label: 'altın',
            color: AppUi.gold,
          ),
        ],
      ),
    );
  }

  Widget _div() =>
      Container(width: 1, height: compact ? 19 : 24, color: AppUi.line);

  Widget _cell({
    GameIconData? icon,
    String? emoji,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emoji != null)
              SemanticIcon(
                emoji,
                size: compact ? 10 : 12,
                color: color,
                fallback: GameIconData.heart,
              )
            else if (icon != null)
              GameIcon(icon, size: compact ? 10 : 12, color: color),
            SizedBox(width: compact ? 2 : 4),
            Text(
              value,
              style: AppUi.number.copyWith(fontSize: compact ? 11 : 13),
            ),
          ],
        ),
        SizedBox(height: compact ? 1 : 2),
        Text(
          label,
          style: AppUi.label.copyWith(
            fontSize: compact ? 7 : 7.5,
            letterSpacing: compact ? 0.4 : 0.8,
          ),
        ),
      ],
    );
  }
}

/// "Ne pahasına" gerilim satırı — kararın özünü tek nefeste verir (gövdeyi
/// okumadan neyin tehlikede olduğunu sezdirir). İnce altın "‹ ›" işaretleri
/// arasında ortalı, ton renginde ışıyan band.
class _StakesLine extends StatelessWidget {
  final String text;
  final Color accent;
  final bool compact;
  const _StakesLine({
    required this.text,
    required this.accent,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 6 : 9,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.04),
            accent.withValues(alpha: 0.16),
            accent.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(AppUi.radiusSm),
        border: Border.all(color: accent.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GameIcon(GameIconData.scroll, size: compact ? 11 : 13, color: accent),
          SizedBox(width: compact ? 6 : 9),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              maxLines: compact ? 2 : null,
              overflow: compact ? TextOverflow.ellipsis : null,
              style: AppUi.body.copyWith(
                fontSize: compact ? 10.5 : 11.5,
                height: compact ? 1.25 : 1.35,
                fontWeight: FontWeight.w700,
                color: AppUi.textHi,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
