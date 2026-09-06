part of 'law_book_panel.dart';

/// PETEK PARÇALARI — altıgen kırpıcı, altıgen yaprak, köz boyacısı ve tema madalyonu.
// ─── ALTIGEN ─────────────────────────────────────────────────────────────────

class _HexClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) {
    final w = s.width, h = s.height;
    return Path()
      ..moveTo(w * 0.25, 0)
      ..lineTo(w * 0.75, 0)
      ..lineTo(w, h * 0.5)
      ..lineTo(w * 0.75, h)
      ..lineTo(w * 0.25, h)
      ..lineTo(0, h * 0.5)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _Hex extends StatelessWidget {
  final String icon, label, progress;
  final Color color;
  final bool isHub;
  final double voicePulse; // -1 = köyün sesi değil
  final VoidCallback? onTap;

  const _Hex({
    required this.icon,
    required this.label,
    required this.progress,
    required this.color,
    required this.isHub,
    required this.voicePulse,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final voice = voicePulse >= 0;
    return SizedBox(
      width: 132,
      height: 114,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Köyün Sesi halesi — nabız atan altın parıltı.
          if (voice)
            Transform.scale(
              scale: 1.05 + voicePulse * 0.06,
              child: SizedBox(
                width: 132,
                height: 114,
                child: ClipPath(
                  clipper: _HexClipper(),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          AppUi.gold.withValues(
                            alpha: 0.15 + voicePulse * 0.22,
                          ),
                          AppUi.gold.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          GestureDetector(
            onTap: onTap,
            child: ClipPath(
              clipper: _HexClipper(),
              // Kol renginde ince halka.
              child: Container(
                color: color.withValues(alpha: 0.55),
                padding: const EdgeInsets.all(3),
                child: ClipPath(
                  clipper: _HexClipper(),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(-0.3, -0.45),
                        radius: 0.9,
                        colors: [
                          Color.lerp(
                            AppUi.surface2,
                            color,
                            isHub ? 0.16 : 0.22,
                          )!,
                          AppUi.surface1,
                        ],
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(icon, style: const TextStyle(fontSize: 22)),
                          const SizedBox(height: 3),
                          SizedBox(
                            width: 96,
                            child: Text(
                              label,
                              textAlign: TextAlign.center,
                              style: AppUi.title.copyWith(
                                fontSize: isHub ? 11.5 : 11,
                                height: 1.1,
                                letterSpacing: isHub ? 1.4 : 0.3,
                                color: isHub ? AppUi.gold : AppUi.textHi,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            progress,
                            style: AppUi.number.copyWith(
                              fontSize: 10,
                              color: isHub
                                  ? AppUi.gold.withValues(alpha: 0.8)
                                  : color.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Meşale közleri — levhanın arkasında yükselen sıcak parçacıklar. Prosedürel
/// (durum tutmaz): her köz kendi fazından türer, [t] döngüsüyle akar.
class _EmberPainter extends CustomPainter {
  final double t;
  const _EmberPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    const n = 16;
    final p = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    for (var i = 0; i < n; i++) {
      final seed = (i * 0.61803398875) % 1.0;
      final baseX = seed * size.width;
      final phase = (t + i / n) % 1.0;
      final y = size.height * (1 - phase) - 6;
      final x = baseX + math.sin(phase * 6.2832 + i) * 11;
      final a = math.sin(phase * math.pi) * 0.5;
      if (a <= 0.01) continue;
      final r = 1.0 + (i % 3) * 0.7;
      p.color = Color.fromRGBO(228, 150 + (i % 3) * 18, 74, a * 0.6);
      canvas.drawCircle(Offset(x, y), r, p);
    }
  }

  @override
  bool shouldRepaint(covariant _EmberPainter old) => old.t != t;
}

// ─── BERAT MEDALYONU ─────────────────────────────────────────────────────────

class _Medallion extends StatelessWidget {
  final _NodeState state;
  final Color color;
  final String icon;
  final double size;
  final double pulse;
  final double pop;
  final bool selected;

  const _Medallion({
    required this.state,
    required this.color,
    required this.icon,
    required this.pulse,
    required this.pop,
    required this.selected,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    final popScale = 1 + (pop < 0.5 ? pop * 0.7 : (1 - pop) * 0.7);
    final glow = state == _NodeState.open
        ? 0.18 + pulse * 0.4
        : (state == _NodeState.sealed ? 0.12 : (pop > 0 ? (1 - pop) : 0.0));

    final (
      Color ringColor,
      double ringWidth,
      double iconAlpha,
    ) = switch (state) {
      _NodeState.sealed => (Color.lerp(color, AppUi.gold, 0.25)!, 1.8, 1.0),
      _NodeState.open => (color, 2.0, 1.0),
      _NodeState.next => (color.withValues(alpha: 0.4), 1.4, 0.42),
      _NodeState.locked => (AppUi.line, 1.2, 0.5),
      _NodeState.foreclosed => (AppUi.line, 1.2, 0.0),
    };

    final well = state == _NodeState.sealed
        ? RadialGradient(
            center: const Alignment(-0.3, -0.4),
            colors: [
              Color.lerp(color, AppUi.textHi, 0.1)!.withValues(alpha: 0.5),
              color.withValues(alpha: 0.16),
              AppUi.surface0,
            ],
            stops: const [0.0, 0.55, 1.0],
          )
        : const RadialGradient(
            center: Alignment(-0.3, -0.4),
            colors: [AppUi.surface2, AppUi.surface0],
          );

    Widget content;
    if (state == _NodeState.foreclosed) {
      content = Text(
        '✕',
        style: TextStyle(
          fontSize: size * 0.36,
          color: AppUi.rust.withValues(alpha: 0.55),
        ),
      );
    } else {
      content = Opacity(
        opacity: iconAlpha,
        child: Text(icon, style: TextStyle(fontSize: size * 0.45, height: 1)),
      );
    }

    final badge = size * 0.36;
    return Transform.scale(
      scale: popScale,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? AppUi.gold.withValues(alpha: 0.85)
                : Colors.transparent,
            width: 1.4,
          ),
          boxShadow: glow > 0.02
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: glow * 0.5),
                    blurRadius: 8 + glow * 7,
                    spreadRadius: glow * 1.2,
                  ),
                ]
              : null,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: well,
                border: Border.all(color: ringColor, width: ringWidth),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x55000000),
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: content,
            ),
            if (state == _NodeState.sealed)
              Positioned(
                right: -1,
                bottom: -1,
                child: Container(
                  width: badge,
                  height: badge,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppUi.gold,
                    border: Border.all(color: AppUi.surface0, width: 1.4),
                  ),
                  alignment: Alignment.center,
                  child: GameIcon(
                    GameIconData.star,
                    size: badge * 0.52,
                    color: AppUi.ink,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
