import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Diegetic "köy panosu" görsel sözlüğü — HUD ve seçim panellerini ortak
/// bir el yapımı dilde toplar. Plank (ahşap), parşömen, çakılı çivi, deri
/// sekme; modern cam veya flat panel yerine bunlar kullanılır.
abstract final class CozyUi {
  // ── Palet ──────────────────────────────────────────────────────────────────
  // Ahşap: cilalı meşe; üstte sıcak vernik, altta gölge. Önceki tonlar fazla
  // koyu-mat görünüyordu; bunlar gözle plank algılanacak kadar sıcak.
  static const woodLight  = Color(0xFF9B6638); // üst vernik ışığı
  static const woodMid    = Color(0xFF77442A); // orta gövde
  static const woodDark   = Color(0xFF3E1F0B); // alt karanlık
  static const woodGrain  = Color(0xFF2C160A); // damar çizgileri (alpha ile uygulanır)
  static const woodHi     = Color(0xFFCE9358); // üst kenar (rim light)

  // Parşömen: kullanılmış kahverengiye çalan krem.
  static const parchment      = Color(0xFFE8D5A3);
  static const parchmentMid   = Color(0xFFD2B679);
  static const parchmentEdge  = Color(0xFFA88753);
  static const parchmentInk   = Color(0xFF3A2410);
  static const parchmentInk2  = Color(0xFF6B4830);

  // Çivi (demir başı): koyu, hafif highlight ile çakılı duruyor.
  static const nailIron    = Color(0xFF1A1108);
  static const nailRim     = Color(0xFF4A3018);
  static const nailHi      = Color(0xFFB59560);

  // Deri sekme: koyu kahverengi yerine bakır-tabaka — ahşap üstüne döşenmiş
  // taze sığır derisi gibi açık tonda. Pasifte de okunaklı.
  static const leather     = Color(0xFF7A4A20);
  static const leatherHi   = Color(0xFFD09558);
  static const leatherMid  = Color(0xFF9B6028);
  static const leatherDark = Color(0xFF3E1F0B);

  // Aksiyon vurguları (sıcak)
  static const ember       = Color(0xFFE0782A); // ana vurgu — "yanmış oranj"
  static const emberSoft   = Color(0xFFF1A565);
  static const sage        = Color(0xFF8AB060); // pozitif
  static const rust        = Color(0xFFC04428); // tehlike

  // ── Tipografi ──────────────────────────────────────────────────────────────
  /// Tahtaya kazınmış başlık — ahşap üstü açık serif.
  static const carvedTitle = TextStyle(
    color: Color(0xFFFFE9B8),
    fontSize: 12,
    fontWeight: FontWeight.w900,
    letterSpacing: 2.4,
    fontFamily: 'monospace',
    shadows: [
      Shadow(color: Color(0xDD1A0E04), blurRadius: 0, offset: Offset(0, 1)),
      Shadow(color: Color(0x66000000), blurRadius: 3, offset: Offset(0, 2)),
    ],
  );

  /// Tahtaya kazınmış sayı.
  static const carvedNumber = TextStyle(
    color: Color(0xFFFFEAB6),
    fontSize: 14,
    fontWeight: FontWeight.w900,
    fontFamily: 'monospace',
    fontFeatures: [FontFeature.tabularFigures()],
    shadows: [
      Shadow(color: Color(0xDD1A0E04), blurRadius: 0, offset: Offset(0, 1)),
      Shadow(color: Color(0x66000000), blurRadius: 3, offset: Offset(0, 2)),
    ],
  );

  static const carvedSmall = TextStyle(
    color: Color(0xFFE0BE7A),
    fontSize: 9.5,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.2,
    fontFamily: 'monospace',
    shadows: [
      Shadow(color: Color(0xDD1A0E04), blurRadius: 0, offset: Offset(0, 1)),
    ],
  );

  /// Parşömen üstü el yazısı feel — koyu mürekkep.
  static const inkTitle = TextStyle(
    color: parchmentInk,
    fontSize: 13,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.6,
    fontFamily: 'monospace',
  );

  static const inkBody = TextStyle(
    color: parchmentInk,
    fontSize: 10.5,
    fontWeight: FontWeight.w600,
    fontFamily: 'monospace',
  );

  static const inkMuted = TextStyle(
    color: parchmentInk2,
    fontSize: 9.5,
    fontStyle: FontStyle.italic,
    fontFamily: 'monospace',
  );

  static const inkLabel = TextStyle(
    color: parchmentInk2,
    fontSize: 8.5,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.4,
    fontFamily: 'monospace',
  );
}

// ─── Ahşap Plank Panel ──────────────────────────────────────────────────────

/// Köşelerinde çivi başı olan, damarlı ahşap panel.
/// HUD'un sol-üst kaynak panosunda ve sağ-üst saat tabelasında kullanılır.
class WoodPlankPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double? width;
  final bool showNails;
  final BorderRadius? borderRadius;

  const WoodPlankPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(12, 9, 12, 10),
    this.width,
    this.showNails = true,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(4);
    return SizedBox(
      width: width,
      child: Stack(
        children: [
          // Damarlı ahşap zemin + bakır kenar.
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  CozyUi.woodLight,
                  CozyUi.woodMid,
                  CozyUi.woodDark,
                ],
                stops: [0.0, 0.55, 1.0],
              ),
              borderRadius: radius,
              border: Border.all(color: const Color(0xFF1F0E04), width: 1.6),
              boxShadow: const [
                BoxShadow(color: Color(0xAA000000), blurRadius: 14, offset: Offset(2, 6)),
                BoxShadow(color: Color(0x55000000), blurRadius: 3, offset: Offset(0, 1)),
              ],
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: Stack(
                children: [
                  CustomPaint(
                    painter: _WoodGrainPainter(),
                    child: Padding(padding: padding, child: child),
                  ),
                  // Üst kenar "rim light" — tahta cilası vurgusu
                  Positioned(
                    top: 0, left: 0, right: 0,
                    child: IgnorePointer(
                      child: Container(
                        height: 2,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x88E5B074),
                              Color(0x00E5B074),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 4 köşe çivisi
          if (showNails) ...const [
            Positioned(top: 4, left: 4,   child: NailHead()),
            Positioned(top: 4, right: 4,  child: NailHead()),
            Positioned(bottom: 4, left: 4,  child: NailHead()),
            Positioned(bottom: 4, right: 4, child: NailHead()),
          ],
        ],
      ),
    );
  }
}

/// Yatay damarlar + 1 küçük budak — ahşap dokusu hissi.
class _WoodGrainPainter extends CustomPainter {
  static final _rng = math.Random(424242);
  static final List<_Streak> _streaks = _gen();

  static List<_Streak> _gen() {
    final s = <_Streak>[];
    for (int i = 0; i < 14; i++) {
      s.add(_Streak(
        y: _rng.nextDouble(),
        amp: 0.4 + _rng.nextDouble() * 0.8,
        shade: _rng.nextDouble() * 0.7 + 0.5,
        width: 0.8 + _rng.nextDouble() * 1.4,
        light: _rng.nextBool(),
      ));
    }
    return s;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = true;
    for (final s in _streaks) {
      final y = s.y * size.height;
      paint.color = s.light
          ? CozyUi.woodHi.withValues(alpha: 0.10 * s.shade)
          : CozyUi.woodGrain.withValues(alpha: 0.28 * s.shade);
      paint.strokeWidth = s.width;
      // Yatay sinus dalgası — düz çizgi olmasın
      final p = Path();
      p.moveTo(0, y);
      for (double x = 0; x <= size.width; x += 3) {
        final yy = y + math.sin((x / size.width) * math.pi * 2 + s.amp) * 0.9;
        p.lineTo(x, yy);
      }
      paint.style = PaintingStyle.stroke;
      canvas.drawPath(p, paint);
    }
    // Birkaç küçük budak (knot) — ahşap karakteri için
    final knotPaint = Paint()
      ..color = const Color(0x55150A02)
      ..isAntiAlias = true;
    canvas.drawCircle(
      Offset(size.width * 0.78, size.height * 0.62),
      math.min(size.width, size.height) * 0.05,
      knotPaint,
    );
    knotPaint.color = const Color(0x33150A02);
    canvas.drawCircle(
      Offset(size.width * 0.22, size.height * 0.30),
      math.min(size.width, size.height) * 0.035,
      knotPaint,
    );
  }

  @override
  bool shouldRepaint(_WoodGrainPainter old) => false;
}

class _Streak {
  final double y, amp, shade, width;
  final bool light;
  _Streak({
    required this.y,
    required this.amp,
    required this.shade,
    required this.width,
    required this.light,
  });
}

// ─── Çivi Başı ──────────────────────────────────────────────────────────────

/// Demir çivi başı — radial gradient + 1px highlight.
class NailHead extends StatelessWidget {
  final double size;
  const NailHead({super.key, this.size = 9});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: Alignment(-0.35, -0.45),
          radius: 1.0,
          colors: [
            Color(0xFFD2B57E),
            CozyUi.nailHi,
            CozyUi.nailRim,
            CozyUi.nailIron,
          ],
          stops: [0.0, 0.30, 0.65, 1.0],
        ),
        boxShadow: [
          BoxShadow(color: Color(0xCC000000), blurRadius: 2.0, offset: Offset(0.5, 1.2)),
        ],
      ),
    );
  }
}

// ─── Parşömen Panel ─────────────────────────────────────────────────────────

/// Çakılı, kıvrık kenarlı parşömen kağıt — seçim panelleri için.
class ParchmentPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double? width;
  /// Sağ-üst köşede çakılı çivi göster (sanki duvara asılmış).
  final bool pinned;

  const ParchmentPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(12, 10, 12, 12),
    this.width,
    this.pinned = true,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(2);
    return SizedBox(
      width: width,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: const RadialGradient(
                center: Alignment(-0.1, -0.2),
                radius: 1.3,
                colors: [
                  Color(0xFFF1E1B0),
                  CozyUi.parchment,
                  Color(0xFFCAA86A),
                ],
                stops: [0.0, 0.55, 1.0],
              ),
              borderRadius: radius,
              border: Border.all(color: CozyUi.parchmentEdge, width: 0.8),
              boxShadow: const [
                BoxShadow(color: Color(0x66000000), blurRadius: 12, offset: Offset(2, 5)),
                BoxShadow(color: Color(0x22000000), blurRadius: 1, offset: Offset(0, 1)),
              ],
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: CustomPaint(
                painter: _ParchmentSpecksPainter(),
                child: Padding(padding: padding, child: child),
              ),
            ),
          ),
          // Sağ-üst köşede çakılı çivi → duvara asılı hissi
          if (pinned) const Positioned(top: -3, right: 14, child: NailHead(size: 10)),
        ],
      ),
    );
  }
}

/// Parşömene seyrek nokta-zerre dağıtımı; gerçek kağıt dokusu.
class _ParchmentSpecksPainter extends CustomPainter {
  static final _rng = math.Random(7777);
  static final List<Offset> _specks = List.generate(
      36, (_) => Offset(_rng.nextDouble(), _rng.nextDouble()));
  static final List<double> _sizes =
      List.generate(36, (_) => 0.5 + _rng.nextDouble() * 1.1);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0x223A2410)
      ..isAntiAlias = false;
    for (int i = 0; i < _specks.length; i++) {
      final o = _specks[i];
      canvas.drawCircle(
        Offset(o.dx * size.width, o.dy * size.height),
        _sizes[i],
        p,
      );
    }
    // Üst-sol köşeye hafif gölge (kağıdın hafif kıvrılmış kenarı)
    final shade = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment(-0.4, -0.4),
        colors: [Color(0x33000000), Color(0x00000000)],
      ).createShader(Rect.fromLTWH(0, 0, size.width * 0.4, size.height * 0.4));
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width * 0.4, size.height * 0.4),
      shade,
    );
  }

  @override
  bool shouldRepaint(_ParchmentSpecksPainter old) => false;
}

// ─── Deri Sekme Butonu ──────────────────────────────────────────────────────

/// Eski deri parça → aksiyon butonu. Hover/active'da hafif bakır parıltısı.
class LeatherButton extends StatelessWidget {
  final String label;
  final String? icon;
  final VoidCallback? onTap;
  final bool active;
  final bool disabled;
  final Color? tint;
  final double height;
  final double horizontalPadding;
  final double fontSize;

  const LeatherButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.active = false,
    this.disabled = false,
    this.tint,
    this.height = 30,
    this.horizontalPadding = 11,
    this.fontSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    final accent = tint ?? CozyUi.ember;
    return Opacity(
      opacity: disabled ? 0.45 : 1.0,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: Container(
          height: height,
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: active
                  ? [
                      Color.alphaBlend(accent.withValues(alpha: 0.55), CozyUi.leatherHi),
                      Color.alphaBlend(accent.withValues(alpha: 0.30), CozyUi.leather),
                    ]
                  : const [
                      Color(0xFFB47542),
                      CozyUi.leather,
                    ],
            ),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: active ? accent : const Color(0xFF1F0E04),
              width: active ? 1.6 : 1.4,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.55),
                      blurRadius: 10,
                      spreadRadius: 0.5,
                    ),
                  ]
                : const [
                    BoxShadow(color: Color(0x66000000), blurRadius: 4, offset: Offset(0, 2)),
                  ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Text(icon!, style: TextStyle(fontSize: fontSize + 1)),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  color: active
                      ? const Color(0xFFFFF1D5)
                      : const Color(0xFFFCEDC4),
                  fontSize: fontSize,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                  fontFamily: 'monospace',
                  shadows: const [
                    Shadow(color: Color(0xCC1A0E04), blurRadius: 0, offset: Offset(0, 1)),
                    Shadow(color: Color(0x55000000), blurRadius: 2, offset: Offset(0, 1)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Mum Mührü Rozet ────────────────────────────────────────────────────────

/// Yarı-saydam wax-stamp şeklinde uyarı/etiket — açlık, susuz, event.
class WaxBadge extends StatelessWidget {
  final String? icon;
  final String label;
  final Color color;
  const WaxBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.alphaBlend(color.withValues(alpha: 0.85), const Color(0xFF1A0E04)),
            Color.alphaBlend(color.withValues(alpha: 0.55), const Color(0xFF120804)),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.85), width: 1),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 6, spreadRadius: 0.5),
        ],
      ),
      child: Text(
        icon == null ? label : '$icon $label',
        style: const TextStyle(
          color: Color(0xFFF8E2B6),
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          fontFamily: 'monospace',
          shadows: [
            Shadow(color: Color(0xAA000000), blurRadius: 0, offset: Offset(0, 1)),
          ],
        ),
      ),
    );
  }
}

// ─── Oyma Kaynak Hücresi ────────────────────────────────────────────────────

/// Tek bir kaynak göstergesi — ikon + sayı, oyma metin gibi gözükür.
class CarvedResource extends StatelessWidget {
  final String icon;
  final int stored;
  final int transit;
  final bool accent;
  const CarvedResource({
    super.key,
    required this.icon,
    required this.stored,
    this.transit = 0,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final empty = stored == 0 && transit == 0;
    // Sıfır kaynak bile okunur olmalı; cream tonunu koru, sadece bir tık soldur.
    final col = accent
        ? const Color(0xFFFFD980)
        : empty
            ? const Color(0xFFCAB082)
            : const Color(0xFFFFEAB6);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Opacity(
          opacity: empty ? 0.70 : 1.0,
          child: Text(icon, style: const TextStyle(fontSize: 15)),
        ),
        const SizedBox(width: 5),
        Text(
          '$stored',
          style: CozyUi.carvedNumber.copyWith(color: col, fontSize: 16),
        ),
        if (transit > 0)
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 5),
            child: Text(
              '+$transit',
              style: const TextStyle(
                color: Color(0xFFE0B978),
                fontSize: 9,
                fontWeight: FontWeight.w800,
                fontFamily: 'monospace',
                shadows: [
                  Shadow(color: Color(0xDD1A0E04), blurRadius: 0, offset: Offset(0, 1)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Sıcak Ayraç ────────────────────────────────────────────────────────────

class CozyDivider extends StatelessWidget {
  final bool wood;
  const CozyDivider({super.key, this.wood = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: wood
            ? const [Color(0x00000000), Color(0x66000000), Color(0x00000000)]
            : const [Color(0x00000000), Color(0x66C9A874), Color(0x00000000)]),
      ),
    );
  }
}
