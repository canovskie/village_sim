import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../systems/estate_system.dart';
import 'app_ui.dart';

/// Ekranın kenarında sabit duran, canlı bir "zümre nabzı" tabelası.
///
/// Belediye panelindeki [EstateSnapshot] özetinin (bkz. building_info_panel
/// `_estatePulse`) ambient, her an görünen kardeşi. Rakam yığını değil — her
/// zümre nefes alan ışıltılı bir madalyon: moral → ışığın rengi+parlaklığı,
/// nüfuz payı → çevresindeki dolan halka, baskın zümre → altın çelenk + ★.
/// Değerler yumuşakça tween'lenir; ışık usulca soluk alır ([feedback
/// lighting_restraint] — abartısız).
class EstateBanner extends StatefulWidget {
  final List<EstateSnapshot> estates;

  /// Köyün kaydığı kimlik adı ("Dengeli Köy" / baskın zümre kimliği).
  final String identity;

  const EstateBanner({
    super.key,
    required this.estates,
    required this.identity,
  });

  @override
  State<EstateBanner> createState() => _EstateBannerState();
}

class _EstateBannerState extends State<EstateBanner>
    with SingleTickerProviderStateMixin {
  /// Tüm madalyonların paylaştığı yavaş "nefes" — her birine faz kayması ile
  /// dağıtılır, böylece eşzamanlı atmaz (organik).
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  )..repeat();

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _breath,
      builder: (context, _) {
        return AppPanel(
          width: 78,
          accent: AppUi.accent,
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 9),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'ZÜMRELER',
                maxLines: 1,
                style: TextStyle(
                  color: Color(0xFFE0BE7A),
                  fontSize: 9,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w700,
                  fontFamily: AppUi.fontDisplay,
                  shadows: [
                    Shadow(
                        color: Color(0xDD1A0E04),
                        blurRadius: 0,
                        offset: Offset(0, 1)),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Container(
                height: 0.8,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                color: const Color(0x55D2B57E),
              ),
              const SizedBox(height: 8),
              for (int i = 0; i < widget.estates.length; i++) ...[
                _EstateMedallion(
                  snap: widget.estates[i],
                  // 0..1 nefes fazı, indise göre kaydırılmış.
                  phase: (_breath.value + i * 0.22) % 1.0,
                ),
                if (i != widget.estates.length - 1)
                  const SizedBox(height: 9),
              ],
              const SizedBox(height: 7),
              Container(
                height: 0.8,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                color: const Color(0x33D2B57E),
              ),
              const SizedBox(height: 5),
              Text(
                widget.identity,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFE8C57A),
                  fontSize: 8.5,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  fontFamily: AppUi.fontDisplay,
                  shadows: [
                    Shadow(
                        color: Color(0xDD1A0E04),
                        blurRadius: 0,
                        offset: Offset(0, 1)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Tek zümrenin canlı madalyonu. Hedef moral/sway değerleri yumuşakça
/// tween'lenir; [phase] ile gelen nefes parlaklığı ve halka rengini oynatır.
class _EstateMedallion extends StatelessWidget {
  final EstateSnapshot snap;
  final double phase;

  const _EstateMedallion({required this.snap, required this.phase});

  /// Moralin sürekli (eşiksiz) renge çevrimi — kızgın(kırmızı)→tedirgin(kor)→
  /// kayıtsız(altın)→memnun(adaçayı). Tier'in keskin sıçraması yerine yumuşak.
  static Color moodTone(double m) {
    const red = AppUi.rust;
    const ember = AppUi.accent;
    const gold = Color(0xFFD9C088);
    const sage = AppUi.sage;
    if (m < 0.32) return Color.lerp(red, ember, (m / 0.32).clamp(0.0, 1.0))!;
    if (m < 0.50) {
      return Color.lerp(ember, gold, ((m - 0.32) / 0.18).clamp(0.0, 1.0))!;
    }
    if (m < 0.70) {
      return Color.lerp(gold, sage, ((m - 0.50) / 0.20).clamp(0.0, 1.0))!;
    }
    return sage;
  }

  @override
  Widget build(BuildContext context) {
    // Sinüs nefes 0..1 (yumuşak).
    final breath = 0.5 - 0.5 * math.cos(phase * math.pi * 2);
    const dur = Duration(milliseconds: 650);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(end: snap.mood),
          duration: dur,
          curve: Curves.easeOut,
          builder: (context, mood, _) {
            return TweenAnimationBuilder<double>(
              tween: Tween(end: snap.swayShare.clamp(0.0, 1.0)),
              duration: dur,
              curve: Curves.easeOut,
              builder: (context, sway, _) {
                final tone = moodTone(mood);
                return SizedBox(
                  width: 50,
                  height: 50,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      CustomPaint(
                        size: const Size(50, 50),
                        painter: _MedallionPainter(
                          mood: mood,
                          sway: sway,
                          breath: breath,
                          tone: tone,
                          ascendant: snap.ascendant,
                        ),
                      ),
                      // Zümre amblemi (orta).
                      Text(snap.estate.icon,
                          style: const TextStyle(fontSize: 17)),
                      // Moral yüzü — sağ-altta küçük rozet.
                      Positioned(
                        right: -1,
                        bottom: -1,
                        child: Container(
                          padding: const EdgeInsets.all(1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xCC2A1608),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: tone.withValues(alpha: 0.7),
                                width: 0.8),
                          ),
                          child: Text(snap.tier.face,
                              style: const TextStyle(fontSize: 9.5)),
                        ),
                      ),
                      // Baskın zümre çelengi — altın ★.
                      if (snap.ascendant)
                        const Positioned(
                          top: -4,
                          child: Text('★',
                              style: TextStyle(
                                color: Color(0xFFFFD45A),
                                fontSize: 11,
                                shadows: [
                                  Shadow(
                                      color: Color(0xCC000000),
                                      blurRadius: 3),
                                ],
                              )),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(height: 1),
        Text(
          snap.estate.label,
          style: TextStyle(
            color: snap.ascendant
                ? const Color(0xFFFFE9B8)
                : const Color(0xFFD9BE8A),
            fontSize: 7.6,
            letterSpacing: 0.2,
            fontWeight: snap.ascendant ? FontWeight.w800 : FontWeight.w600,
            fontFamily: AppUi.fontText,
            shadows: const [
              Shadow(color: Color(0xCC1A0E04), blurRadius: 0, offset: Offset(0, 1)),
            ],
          ),
        ),
      ],
    );
  }
}

class _MedallionPainter extends CustomPainter {
  final double mood; // 0..1
  final double sway; // 0..1
  final double breath; // 0..1
  final Color tone;
  final bool ascendant;

  _MedallionPainter({
    required this.mood,
    required this.sway,
    required this.breath,
    required this.tone,
    required this.ascendant,
  });

  // Halka boşluğu altta — top'tan saat yönünde dolar.
  static const double _gap = math.pi * 2 * 0.26;
  static double get _sweepMax => math.pi * 2 - _gap;
  static double get _start => math.pi / 2 + _gap / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;

    // ── Nefes alan dış ışık halesi (moral → parlaklık) ───────────────────────
    // Memnun zümre sıcak ve sakin parlar; küskün loş kalır. Abartısız.
    final glowR = r * (0.92 + breath * 0.12);
    final glowA = (0.10 + mood * 0.26) * (0.6 + breath * 0.4);
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          tone.withValues(alpha: glowA),
          tone.withValues(alpha: 0),
        ],
        stops: const [0.42, 1.0],
      ).createShader(Rect.fromCircle(center: c, radius: glowR * 1.25));
    canvas.drawCircle(c, glowR * 1.25, glow);

    // ── Madalyon diski (cilalı ahşap) ────────────────────────────────────────
    final discR = r * 0.70;
    final disc = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.35, -0.45),
        colors: [Color(0xFF8C5C32), Color(0xFF512B12), Color(0xFF2C160A)],
        stops: [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: c, radius: discR));
    canvas.drawCircle(c, discR, disc);
    canvas.drawCircle(
      c,
      discR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0xFF1A0E04),
    );
    // Üst içe vurgu (cila).
    canvas.drawCircle(
      Offset(c.dx, c.dy - discR * 0.28),
      discR * 0.5,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0x33FFE3B0),
            const Color(0x00FFE3B0),
          ],
        ).createShader(
            Rect.fromCircle(center: Offset(c.dx, c.dy - discR * 0.28), radius: discR * 0.5)),
    );

    // ── Nüfuz halkası ────────────────────────────────────────────────────────
    final ringR = r * 0.86;
    final ringRect = Rect.fromCircle(center: c, radius: ringR);
    // İz (boş kanal).
    canvas.drawArc(
      ringRect,
      _start,
      _sweepMax,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round
        ..color = const Color(0x66000000),
    );
    // Dolan yay (moral rengi) — yumuşak parıltıyla.
    final swept = _sweepMax * sway.clamp(0.0, 1.0);
    if (swept > 0.001) {
      canvas.drawArc(
        ringRect,
        _start,
        swept,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.4
          ..strokeCap = StrokeCap.round
          ..color = tone.withValues(alpha: 0.45 + breath * 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2),
      );
      canvas.drawArc(
        ringRect,
        _start,
        swept,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round
          ..color = Color.lerp(tone, const Color(0xFFFFF1D5), 0.25)!
              .withValues(alpha: 0.95),
      );
    }

    // ── Baskın çelenk — altın ince halka ────────────────────────────────────
    if (ascendant) {
      canvas.drawCircle(
        c,
        ringR + 2.4,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0xFFFFD45A)
              .withValues(alpha: 0.55 + breath * 0.30),
      );
    }
  }

  @override
  bool shouldRepaint(_MedallionPainter old) =>
      old.mood != mood ||
      old.sway != sway ||
      old.breath != breath ||
      old.tone != tone ||
      old.ascendant != ascendant;
}
