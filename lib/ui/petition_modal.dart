import 'package:flutter/material.dart';
import '../systems/petition_system.dart';
import 'app_ui.dart';

/// Köyden gelen bir ricanın oyuncu-yüzlü karşılığı — Meclis önüne gelen
/// dilekçe. Modern koyu panel diline (AppUi) oturur: rafine yüzey, tek sıcak
/// vurgu, güçlü tipografi hiyerarşisi (dilekçe metni → sunan zümre → seçenekler
/// → sonuçlar). Ambient — boşluğa dokununca kapanır ([onDismiss]), dilekçe
/// bekleyen kalır (HUD rozeti durur). [onChoose] kararı uygular.
class PetitionModal extends StatelessWidget {
  final Petition petition;
  /// Karar anındaki köy durumu — bağlam şeridinde gösterilir (oyuncu
  /// moral/nüfus/yiyecek/altını görerek karar versin). null = şerit gizli.
  final ({double morale, int population, int food, int gold})? state;
  final void Function(PetitionOption) onChoose;
  final VoidCallback onDismiss;

  const PetitionModal({
    super.key,
    required this.petition,
    this.state,
    required this.onChoose,
    required this.onDismiss,
  });

  /// Dilekçe tonuna göre vurgu rengi — etiket/stakes/aksan renklendirmesi.
  Color get _toneAccent => switch (petition.tone) {
        PetitionTone.warm => AppUi.sage,
        PetitionTone.solemn => AppUi.textMid,
        PetitionTone.ominous => AppUi.rust,
        PetitionTone.neutral => AppUi.accent,
      };

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Arkayı karart + boşluğa dokun = kapat (ambient, karar zorunlu değil).
        Positioned.fill(
          child: GestureDetector(
            onTap: onDismiss,
            child: const ColoredBox(color: AppUi.scrim),
          ),
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(26),
              // Modalın içine dokununca arkadaki dismiss tetiklenmesin.
              child: GestureDetector(
                onTap: () {},
                child: AppReveal(
                  child: AppPanel(
                    accent: _toneAccent,
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _header(),
                        if (state != null) ...[
                          const SizedBox(height: 13),
                          _VillageStateStrip(state: state!),
                        ],
                        const SizedBox(height: 14),
                        // Gövde — dilekçe metni, okunaklı sıcak ton.
                        Text(
                          petition.body,
                          textAlign: TextAlign.center,
                          style: AppUi.body.copyWith(fontSize: 12, height: 1.55),
                        ),
                        if (petition.stakes != null) ...[
                          const SizedBox(height: 11),
                          _StakesLine(text: petition.stakes!, accent: _toneAccent),
                        ],
                        const AppDivider(),
                        for (int i = 0; i < petition.options.length; i++) ...[
                          _PetitionOptionCard(
                            option: petition.options[i],
                            onTap: () => onChoose(petition.options[i]),
                          ),
                          if (i != petition.options.length - 1)
                            const SizedBox(height: 9),
                        ],
                        const SizedBox(height: 12),
                        // Ambient ipucu — karar ertelenebilir.
                        Text('boşluğa dokun — kararı sonraya bırak',
                            style: AppUi.label.copyWith(
                                fontSize: 8.5, letterSpacing: 1.0)),
                      ],
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

  Widget _header() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PetitionGlyph(icon: petition.icon, accent: _toneAccent),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 2),
              Text('DİLEKÇE',
                  style: AppUi.label.copyWith(color: _toneAccent)),
              const SizedBox(height: 4),
              Text(petition.title,
                  style: AppUi.title.copyWith(fontSize: 17, height: 1.1)),
              const SizedBox(height: 4),
              Text(petition.petitioner,
                  style: AppUi.body.copyWith(fontSize: 11, color: AppUi.textLo)),
              if (petition.note != null) ...[
                const SizedBox(height: 8),
                AppChip(label: petition.note!, color: AppUi.rust),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Dilekçe glifi — koyu kare, ton-aksanlı kenar + soft glow. Eski balmumu
/// mührünün modern karşılığı: resmi, "Meclis'e sunulmuş" his.
class _PetitionGlyph extends StatelessWidget {
  final String icon;
  final Color accent;
  final double size;
  const _PetitionGlyph({required this.icon, required this.accent, this.size = 56});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppUi.surface0,
        borderRadius: BorderRadius.circular(AppUi.radiusSm),
        border: Border.all(color: accent.withValues(alpha: 0.7), width: 1.5),
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: 0.26), blurRadius: 12),
        ],
      ),
      child: Text(icon, style: TextStyle(fontSize: size * 0.46)),
    );
  }
}

/// Köy durumu şeridi — karar anında moral/nüfus/yiyecek/altın özeti. Oyuncu
/// dilekçeyi köyün gerçek hâliyle tartar. Koyu iç band.
class _VillageStateStrip extends StatelessWidget {
  final ({double morale, int population, int food, int gold}) state;
  const _VillageStateStrip({required this.state});

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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppUi.surface0,
        borderRadius: BorderRadius.circular(AppUi.radiusSm),
        border: Border.all(color: AppUi.line, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _cell(emoji: _moraleFace, value: '${(state.morale * 100).round()}%',
              label: 'moral', color: AppUi.accent),
          _div(),
          _cell(icon: GameIconData.people, value: '${state.population}',
              label: 'nüfus', color: AppUi.textMid),
          _div(),
          _cell(icon: GameIconData.wheat, value: '${state.food}',
              label: 'yiyecek', color: AppUi.sage),
          _div(),
          _cell(icon: GameIconData.coin, value: '${state.gold}',
              label: 'altın', color: AppUi.gold),
        ],
      ),
    );
  }

  Widget _div() => Container(width: 1, height: 24, color: AppUi.line);

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
              Text(emoji, style: const TextStyle(fontSize: 12))
            else if (icon != null)
              GameIcon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(value, style: AppUi.number.copyWith(fontSize: 13)),
          ],
        ),
        const SizedBox(height: 2),
        Text(label,
            style: AppUi.label.copyWith(fontSize: 7.5, letterSpacing: 0.8)),
      ],
    );
  }
}

/// "Ne pahasına" tek satırı — kararın özünü ton renginde vurgular. Oyuncu
/// gövdeyi okumadan da neyin tehlikede olduğunu sezer.
class _StakesLine extends StatelessWidget {
  final String text;
  final Color accent;
  const _StakesLine({required this.text, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 7, 12, 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppUi.radiusSm),
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GameIcon(GameIconData.scroll, size: 13, color: accent),
          const SizedBox(width: 8),
          Flexible(
            child: Text(text,
                style: AppUi.body.copyWith(
                    fontSize: 11,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                    color: AppUi.textHi)),
          ),
        ],
      ),
    );
  }
}

/// Bir dilekçe seçeneği — koyu seçim kartı: başlık + açıklama + etki rozetleri.
/// Hover'da sıcak ember parıltısı.
class _PetitionOptionCard extends StatefulWidget {
  final PetitionOption option;
  final VoidCallback onTap;
  const _PetitionOptionCard({required this.option, required this.onTap});
  @override
  State<_PetitionOptionCard> createState() => _PetitionOptionCardState();
}

class _PetitionOptionCardState extends State<_PetitionOptionCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final o = widget.option;
    final chips = o.effectChips;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
          decoration: BoxDecoration(
            color: _hover
                ? Color.alphaBlend(
                    AppUi.accent.withValues(alpha: 0.14), AppUi.surface2)
                : AppUi.surface1,
            borderRadius: BorderRadius.circular(AppUi.radiusSm),
            border: Border.all(
              color: _hover ? AppUi.accent : AppUi.line,
              width: _hover ? 1.5 : 1,
            ),
            boxShadow: _hover
                ? [
                    BoxShadow(
                        color: AppUi.accent.withValues(alpha: 0.25),
                        blurRadius: 10),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 16,
                    decoration: BoxDecoration(
                      color: _hover ? AppUi.accent : AppUi.accentDeep,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(o.label,
                        style: AppUi.bodyHi.copyWith(fontSize: 13)),
                  ),
                  GameIcon(GameIconData.chevron,
                      size: 14,
                      color: _hover ? AppUi.accent : AppUi.textLo),
                ],
              ),
              const SizedBox(height: 5),
              Padding(
                padding: const EdgeInsets.only(left: 13),
                child: Text(o.detail,
                    style: AppUi.body.copyWith(fontSize: 11, height: 1.4)),
              ),
              if (chips.isNotEmpty) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 13),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final d in chips) _effectChip(d.$1, d.$2),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _effectChip(String icon, String label) {
    final color = _chipColor((icon, label));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 4),
          Text(label,
              style: AppUi.number.copyWith(fontSize: 10.5, color: color)),
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

/// HUD'da bekleyen dilekçeyi gösteren rozet — koyu kompakt panel + glif +
/// "Dilekçe" yazısı. Hafifçe nabız atar; tıklanınca [onTap] modal açar.
class PetitionSeal extends StatefulWidget {
  final VoidCallback onTap;
  const PetitionSeal({super.key, required this.onTap});
  @override
  State<PetitionSeal> createState() => _PetitionSealState();
}

class _PetitionSealState extends State<PetitionSeal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final t = _ctrl.value;
            final glow = 0.22 + t * 0.34;
            final scale = 1.0 + t * 0.04;
            return Transform.scale(
              scale: scale,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppUi.radius),
                  boxShadow: [
                    BoxShadow(
                        color: AppUi.accent.withValues(alpha: glow),
                        blurRadius: 14,
                        spreadRadius: 1),
                  ],
                ),
                child: AppPanel(
                  accent: AppUi.accent,
                  padding: const EdgeInsets.fromLTRB(9, 7, 13, 7),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _PetitionGlyph(
                          icon: '📜', accent: AppUi.accent, size: 30),
                      const SizedBox(width: 9),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('YENİ',
                              style: AppUi.label
                                  .copyWith(color: AppUi.rust, fontSize: 7.5)),
                          const SizedBox(height: 1),
                          Text('Dilekçe',
                              style: AppUi.title.copyWith(fontSize: 14)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
