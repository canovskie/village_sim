part of 'petition_modal.dart';

/// MÜHÜR — dilekçe mührü, madalyon ve mühlet halkası.
/// HUD'da bekleyen KARARI gösteren rozet — koyu kompakt panel + glif +
/// tükenen MÜHLET halkası. [progress] (1→0) kalan mühleti gösterir; halka
/// boşaldıkça akar. [urgent] (son %30) → ton kızarır, nabız hızlanır, uyarı
/// metni değişir. [tone] duygusal rengi halka/glow'a taşır.
///
/// Varsayılanlar dilekçe kılığıdır; olay kuyruğu aynı rozeti [label]/[glyph]/
/// durum metinleriyle 'KARAR' kılığında giyer — köyün tüm bekleyen kararları
/// tek görsel dili konuşsun (kapıda kuyruk).
class PetitionSeal extends StatefulWidget {
  final VoidCallback onTap;
  final double progress; // 1.0 = tam mühlet, 0.0 = doldu
  final bool urgent;
  final PetitionTone tone;
  final String label; // rozet başlığı ('DİLEKÇE' / 'KARAR')
  final String glyph; // madalyon glifi ('📜' / olay ikonu)
  final String statusIdle; // sakin durum satırı
  final String statusUrgent; // sıkışma durum satırı
  const PetitionSeal({
    super.key,
    required this.onTap,
    this.progress = 1.0,
    this.urgent = false,
    this.tone = PetitionTone.neutral,
    this.label = 'DİLEKÇE',
    this.glyph = '📜',
    this.statusIdle = 'köy söz bekliyor',
    this.statusUrgent = 'AZ KALDI: yanıt bekliyor',
  });
  @override
  State<PetitionSeal> createState() => _PetitionSealState();
}

class _PetitionSealState extends State<PetitionSeal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: _pulseDur(),
  )..repeat(reverse: true);

  Duration _pulseDur() => Duration(milliseconds: widget.urgent ? 620 : 1500);

  @override
  void didUpdateWidget(PetitionSeal old) {
    super.didUpdateWidget(old);
    // Sıkışmaya geçince nabız hızlanır (ve tersi) — controller süresini güncelle.
    if (old.urgent != widget.urgent) {
      _ctrl.duration = _pulseDur();
      _ctrl
        ..reset()
        ..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _toneAccent => switch (widget.tone) {
    PetitionTone.warm => AppUi.sage,
    PetitionTone.solemn => AppUi.textMid,
    PetitionTone.ominous => AppUi.rust,
    PetitionTone.neutral => AppUi.accent,
  };

  @override
  Widget build(BuildContext context) {
    // Sıkışmada her şey rust'a kayar (aciliyet rengi), değilse tonun rengi.
    final accent = widget.urgent ? AppUi.rust : _toneAccent;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final t = _ctrl.value;
            final glow =
                (widget.urgent ? 0.30 : 0.22) +
                t * (widget.urgent ? 0.46 : 0.34);
            final scale = 1.0 + t * (widget.urgent ? 0.06 : 0.04);
            return Transform.scale(
              scale: scale,
              // İnce altın çerçeveli koyu "dispatch" rozeti — modalın gilded
              // diliyle aynı: gold metalik kenar + ton-aksanlı glow + gradient.
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 7, 14, 7),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppUi.surface2, AppUi.surface1],
                  ),
                  borderRadius: BorderRadius.circular(AppUi.radius),
                  border: Border.all(
                    color: AppUi.gold.withValues(alpha: 0.34),
                    width: 1.1,
                  ),
                  boxShadow: [
                    ...AppUi.softShadow,
                    BoxShadow(
                      color: accent.withValues(alpha: glow),
                      blurRadius: widget.urgent ? 20 : 15,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Mühür madalyonu + çevresinde tükenen mühlet halkası.
                    SizedBox(
                      width: 42,
                      height: 42,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: const Size(42, 42),
                            painter: _MuhletRing(
                              progress: widget.progress,
                              accent: accent,
                            ),
                          ),
                          _SealMedallion(accent: accent, glyph: widget.glyph),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.label,
                          style: AppUi.title.copyWith(
                            fontSize: 14,
                            letterSpacing: 1.6,
                          ),
                        ),
                        const SizedBox(height: 3),
                        // Durum satırı — nabız atan nokta + terse etiket.
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: accent,
                                boxShadow: [
                                  BoxShadow(
                                    color: accent.withValues(
                                      alpha: 0.5 + t * 0.4,
                                    ),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              widget.urgent
                                  ? widget.statusUrgent
                                  : widget.statusIdle,
                              style: AppUi.label.copyWith(
                                color: widget.urgent
                                    ? AppUi.rust
                                    : AppUi.textLo,
                                fontSize: 8,
                                letterSpacing: widget.urgent ? 1.2 : 0.9,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Rozetin mühür madalyonu — dairesel koyu disk, ince altın halka + ton-aksanlı
/// iç glow, ortada glif (balmumu mührü ya da olay ikonu). Modal hero
/// madalyonunun küçük kardeşi.
class _SealMedallion extends StatelessWidget {
  final Color accent;
  final String glyph;
  const _SealMedallion({required this.accent, this.glyph = '📜'});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Color.alphaBlend(accent.withValues(alpha: 0.22), AppUi.surface0),
            AppUi.surface0,
          ],
        ),
        border: Border.all(
          color: AppUi.gold.withValues(alpha: 0.6),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 6),
        ],
      ),
      child: Text(glyph, style: const TextStyle(fontSize: 14)),
    );
  }
}

/// Madalyonun çevresinde tükenen mühlet halkası — altın-soluk iz + kalan süreyi
/// gösteren renkli yay (tepeden saat yönünde) + yayın ucunda parlayan "saat
/// ibresi" noktası. progress 1→0 azaldıkça yay kısalır.
class _MuhletRing extends CustomPainter {
  final double progress;
  final Color accent;
  const _MuhletRing({required this.progress, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 1.8;
    final rect = Rect.fromCircle(center: c, radius: r);
    // İz — ince altın hairline (rozetin gilded diliyle uyumlu).
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..color = AppUi.gold.withValues(alpha: 0.16);
    canvas.drawCircle(c, r, track);
    final p = progress.clamp(0.0, 1.0);
    if (p <= 0) return;
    const start = -1.5707963; // -90° (tepe)
    final sweep = 6.2831853 * p;
    // Yumuşak glow alt-katmanı.
    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round
        ..color = accent.withValues(alpha: 0.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );
    // Renkli yay.
    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..color = accent,
    );
    // Yayın ucunda parlayan ibre noktası.
    final a = start + sweep;
    final head = Offset(c.dx + r * cos(a), c.dy + r * sin(a));
    canvas.drawCircle(
      head,
      2.4,
      Paint()..color = Color.lerp(accent, Colors.white, 0.5)!,
    );
    canvas.drawCircle(
      head,
      4.5,
      Paint()
        ..color = accent.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }

  @override
  bool shouldRepaint(_MuhletRing old) =>
      old.progress != progress || old.accent != accent;
}
