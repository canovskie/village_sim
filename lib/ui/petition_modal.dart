import 'package:flutter/material.dart';
import '../systems/petition_system.dart';
import 'cozy_theme.dart';

/// Parşömen dilekçe fermanı — köyden gelen bir ricanın diegetic karşılığı.
/// Ahşap/parşömen cozy diline (CozyUi) oturur: yıpranmış kâğıt, balmumu mühür,
/// deri seçim sekmeleri. Ambient — boşluğa dokununca kapanır ([onDismiss]),
/// dilekçe bekleyen kalır (mühür HUD'da durur). [onChoose] kararı uygular.
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
        PetitionTone.warm => CozyUi.sage,
        PetitionTone.solemn => CozyUi.parchmentInk2,
        PetitionTone.ominous => CozyUi.rust,
        PetitionTone.neutral => CozyUi.ember,
      };

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Arkayı karart + boşluğa dokun = kapat (ambient, karar zorunlu değil).
        Positioned.fill(
          child: GestureDetector(
            onTap: onDismiss,
            child: const ColoredBox(color: Color(0xBB07040A)),
          ),
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 470),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(26),
              // Modalın içine dokununca arkadaki dismiss tetiklenmesin.
              child: GestureDetector(
                onTap: () {},
                child: ParchmentPanel(
                  pinned: false,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _header(),
                      if (state != null) ...[
                        const SizedBox(height: 11),
                        _VillageStateStrip(state: state!),
                      ],
                      const SizedBox(height: 13),
                      // Gövde — parşömen üstü mürekkep, okunaklı sıcak ton.
                      Text(
                        petition.body,
                        textAlign: TextAlign.center,
                        style: CozyUi.inkBody.copyWith(fontSize: 11, height: 1.6),
                      ),
                      if (petition.stakes != null) ...[
                        const SizedBox(height: 9),
                        _StakesLine(text: petition.stakes!, accent: _toneAccent),
                      ],
                      const SizedBox(height: 6),
                      const CozyDivider(wood: false),
                      const SizedBox(height: 4),
                      for (int i = 0; i < petition.options.length; i++) ...[
                        _PetitionOptionCard(
                          option: petition.options[i],
                          onTap: () => onChoose(petition.options[i]),
                        ),
                        if (i != petition.options.length - 1)
                          const SizedBox(height: 9),
                      ],
                      const SizedBox(height: 11),
                      // Ambient ipucu — karar ertelenebilir.
                      Text('— boşluğa dokun: kararı sonraya bırak —',
                          style: CozyUi.inkMuted.copyWith(fontSize: 8.5)),
                    ],
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
        _WaxSeal(icon: petition.icon),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 2),
              Text('D İ L E K Ç E',
                  style: CozyUi.inkLabel.copyWith(
                      color: _toneAccent, fontSize: 8.5, letterSpacing: 3)),
              const SizedBox(height: 3),
              Text(petition.title,
                  style: CozyUi.inkTitle.copyWith(fontSize: 16, height: 1.1)),
              const SizedBox(height: 4),
              Text(petition.petitioner,
                  style: CozyUi.inkMuted.copyWith(fontSize: 10)),
              if (petition.note != null) ...[
                const SizedBox(height: 7),
                WaxBadge(label: petition.note!, color: CozyUi.rust),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Embossed balmumu mühür — dış kırmızı mum halkası + iç krem disk + emoji.
/// Dilekçeye resmi, "köy mührüyle damgalanmış" bir his verir.
class _WaxSeal extends StatelessWidget {
  final String icon;
  final double size;
  const _WaxSeal({required this.icon, this.size = 58});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.35, -0.4),
          radius: 1.0,
          colors: [Color(0xFFC0492E), Color(0xFF8E2418), Color(0xFF5E160E)],
          stops: [0.0, 0.6, 1.0],
        ),
        border: Border.all(color: const Color(0xFF45100A), width: 1.5),
        boxShadow: const [
          BoxShadow(color: Color(0x99000000), blurRadius: 7, offset: Offset(1, 3)),
          BoxShadow(
              color: Color(0x55E0A060), blurRadius: 2, offset: Offset(-1, -1)),
        ],
      ),
      child: Container(
        width: size * 0.72,
        height: size * 0.72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            center: Alignment(-0.2, -0.3),
            radius: 1.0,
            colors: [Color(0xFFF1E1B0), CozyUi.parchmentMid],
          ),
          border: Border.all(
              color: const Color(0xFF7A1E14).withValues(alpha: 0.55), width: 1),
        ),
        child: Text(icon, style: TextStyle(fontSize: size * 0.41)),
      ),
    );
  }
}

/// Köy durumu şeridi — karar anında moral/nüfus/yiyecek/altın özeti. Oyuncu
/// dilekçeyi köyün gerçek hâliyle tartar (UI bağlamı). Parşömen üstü ince band.
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x22000000),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
            color: CozyUi.parchmentEdge.withValues(alpha: 0.5), width: 0.8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _cell(_moraleFace, '${(state.morale * 100).round()}%', 'moral'),
          _div(),
          _cell('👥', '${state.population}', 'nüfus'),
          _div(),
          _cell('🌾', '${state.food}', 'yiyecek'),
          _div(),
          _cell('★', '${state.gold}', 'altın'),
        ],
      ),
    );
  }

  Widget _div() => Container(
      width: 0.8,
      height: 22,
      color: CozyUi.parchmentEdge.withValues(alpha: 0.35));

  Widget _cell(String icon, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 11)),
            const SizedBox(width: 3),
            Text(value,
                style: CozyUi.inkTitle.copyWith(fontSize: 12, height: 1.0)),
          ],
        ),
        const SizedBox(height: 1),
        Text(label,
            style: CozyUi.inkLabel.copyWith(fontSize: 7, letterSpacing: 0.5)),
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
      padding: const EdgeInsets.fromLTRB(9, 5, 10, 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(3),
        border: Border(left: BorderSide(color: accent, width: 2.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('⚖', style: TextStyle(fontSize: 11, color: accent)),
          const SizedBox(width: 7),
          Flexible(
            child: Text(text,
                style: CozyUi.inkBody.copyWith(
                    fontSize: 9.5,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    color: CozyUi.parchmentInk)),
          ),
        ],
      ),
    );
  }
}

/// Bir dilekçe seçeneği — deri sekme üstünde başlık + açıklama + balmumu etki
/// rozetleri. Hover'da sıcak bakır parıltısı.
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
          padding: const EdgeInsets.fromLTRB(12, 9, 11, 10),
          decoration: BoxDecoration(
            // Parşömen üstüne yapıştırılmış biraz daha koyu kâğıt şeridi.
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: _hover
                  ? const [Color(0xFFF0DBA2), Color(0xFFDFC384)]
                  : const [Color(0xFFE3CB92), Color(0xFFD0B274)],
            ),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: _hover ? CozyUi.ember : CozyUi.parchmentEdge,
              width: _hover ? 1.6 : 1,
            ),
            boxShadow: _hover
                ? [
                    BoxShadow(
                        color: CozyUi.ember.withValues(alpha: 0.30),
                        blurRadius: 9,
                        spreadRadius: 0.5),
                  ]
                : const [
                    BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 2,
                        offset: Offset(0, 1)),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  // Sol kenar deri/mühür şeridi.
                  Container(
                    width: 4,
                    height: 16,
                    decoration: BoxDecoration(
                      color: _hover ? CozyUi.ember : CozyUi.leather,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(o.label,
                        style: CozyUi.inkTitle.copyWith(
                            fontSize: 12.5,
                            color: _hover
                                ? const Color(0xFF2A1606)
                                : CozyUi.parchmentInk)),
                  ),
                  Icon(Icons.east,
                      size: 13,
                      color: (_hover ? CozyUi.rust : CozyUi.parchmentInk2)
                          .withValues(alpha: 0.8)),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 13),
                child: Text(o.detail,
                    style: CozyUi.inkBody.copyWith(
                        fontSize: 9.5,
                        height: 1.4,
                        color: CozyUi.parchmentInk2,
                        fontWeight: FontWeight.w500)),
              ),
              if (chips.isNotEmpty) ...[
                const SizedBox(height: 7),
                Padding(
                  padding: const EdgeInsets.only(left: 13),
                  child: Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: [
                      for (final d in chips)
                        WaxBadge(icon: d.$1, label: d.$2, color: _chipColor(d)),
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

  Color _chipColor((String, String) d) {
    if (d.$1 == '📜') return CozyUi.ember; // yasa
    return d.$2.startsWith('-') ? CozyUi.rust : CozyUi.sage; // negatif/pozitif
  }
}

/// HUD'da bekleyen dilekçeyi gösteren mühürlü tomar rozeti — küçük balmumu
/// mührü + "Dilekçe" yazısı. Hafifçe nabız atar; tıklanınca [onTap] modal açar.
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
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: CozyUi.ember.withValues(alpha: glow),
                        blurRadius: 13,
                        spreadRadius: 1),
                  ],
                ),
                child: ParchmentPanel(
                  pinned: false,
                  padding: const EdgeInsets.fromLTRB(8, 5, 12, 5),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _WaxSeal(icon: '📜', size: 30),
                      const SizedBox(width: 8),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('YENİ',
                              style: CozyUi.inkLabel
                                  .copyWith(color: CozyUi.rust, fontSize: 7.5)),
                          Text('Dilekçe',
                              style: CozyUi.inkTitle.copyWith(fontSize: 13)),
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
