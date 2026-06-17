import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Modern, sıcak-koyu oyun UI dili. Skeuomorphic ahşap/parşömen yerine:
/// koyu rafine paneller, tek sıcak vurgu (ember), güçlü tipografi
/// (Cinzel başlık + Spectral gövde), vektör ikon seti, reaktif animasyon.
///
/// Tasarım hedefi: Against the Storm / Manor Lords çıtası — ciddi, cilalı,
/// "oyun arayüzü"; flash-oyun değil.
abstract final class AppUi {
  // ── Yüzeyler (sıcak koyu) ───────────────────────────────────────────────
  static const scrim     = Color(0xCC0E0A06); // modal arka karartma
  static const surface0  = Color(0xFF17120C); // en derin
  static const surface1  = Color(0xFF211A12); // panel gövdesi
  static const surface2  = Color(0xFF2B2118); // yükseltilmiş / header
  static const surface3  = Color(0xFF362A1E); // hover / seçili
  static const line      = Color(0xFF3E2F20); // hairline kenar
  static const lineSoft  = Color(0x22FFFFFF); // ince iç ışık

  // ── Metin ───────────────────────────────────────────────────────────────
  static const textHi  = Color(0xFFF4E9D2); // ana
  static const textMid = Color(0xFFCBB892); // ikincil
  static const textLo  = Color(0xFF94815F); // soluk / etiket

  // ── Vurgular ─────────────────────────────────────────────────────────────
  static const accent     = Color(0xFFE98A38); // ember — ana vurgu
  static const accentSoft = Color(0xFFF4B273);
  static const accentDeep = Color(0xFFB5621F);
  static const sage       = Color(0xFF92C166); // pozitif
  static const rust       = Color(0xFFD8552E); // tehlike
  static const gold       = Color(0xFFE9C552); // para / lüks
  static const info       = Color(0xFF5FAAD2); // su / lojistik

  // ── Tipografi ────────────────────────────────────────────────────────────
  static const fontDisplay = 'Cinzel';   // başlık / oyma kapital
  static const fontText    = 'Spectral'; // gövde / sayı / buton

  static const display = TextStyle(
    fontFamily: fontDisplay,
    fontWeight: FontWeight.w700,
    fontSize: 44,
    height: 1.02,
    letterSpacing: 3.0,
    color: textHi,
  );

  static const title = TextStyle(
    fontFamily: fontDisplay,
    fontWeight: FontWeight.w700,
    fontSize: 16,
    letterSpacing: 1.4,
    color: textHi,
  );

  static const label = TextStyle(
    fontFamily: fontDisplay,
    fontWeight: FontWeight.w600,
    fontSize: 9.5,
    letterSpacing: 1.8,
    color: textLo,
  );

  static const body = TextStyle(
    fontFamily: fontText,
    fontWeight: FontWeight.w500,
    fontSize: 12.5,
    height: 1.3,
    color: textMid,
  );

  static const bodyHi = TextStyle(
    fontFamily: fontText,
    fontWeight: FontWeight.w700,
    fontSize: 13,
    color: textHi,
  );

  static const number = TextStyle(
    fontFamily: fontText,
    fontWeight: FontWeight.w700,
    fontSize: 14,
    color: textHi,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const button = TextStyle(
    fontFamily: fontText,
    fontWeight: FontWeight.w700,
    fontSize: 12,
    letterSpacing: 0.8,
    color: textHi,
  );

  // ── Ortak dekorasyon ───────────────────────────────────────────────────
  static const radius = 14.0;
  static const radiusSm = 9.0;

  static List<BoxShadow> get softShadow => const [
        BoxShadow(color: Color(0x66000000), blurRadius: 18, offset: Offset(0, 8)),
        BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 1)),
      ];
}

// ─── Panel ───────────────────────────────────────────────────────────────────

/// Temiz koyu panel — yumuşak gradient + hairline kenar + üst iç ışık + gölge.
/// Tüm modal/dock yüzeylerinin temeli.
class AppPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double? width;
  final BorderRadius? borderRadius;
  final Color? accent;

  const AppPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.width,
    this.borderRadius,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final r = borderRadius ?? BorderRadius.circular(AppUi.radius);
    return Container(
      width: width,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppUi.surface2, AppUi.surface1],
        ),
        borderRadius: r,
        border: Border.all(color: AppUi.line, width: 1),
        boxShadow: AppUi.softShadow,
      ),
      child: ClipRRect(
        borderRadius: r,
        child: Stack(
          children: [
            // Üst iç ışık çizgisi — yüzeye hafif kabarıklık
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(height: 1, color: AppUi.lineSoft),
            ),
            // İsteğe bağlı üst aksan şeridi
            if (accent != null)
              Positioned(
                top: 0, left: 0, right: 0,
                child: Container(
                  height: 2.5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      accent!.withValues(alpha: 0.0),
                      accent!,
                      accent!.withValues(alpha: 0.0),
                    ]),
                  ),
                ),
              ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}

// ─── Buton ───────────────────────────────────────────────────────────────────

enum AppButtonKind { filled, tonal, ghost, danger }

class AppButton extends StatefulWidget {
  final String label;
  final GameIconData? icon;
  final VoidCallback? onTap;
  final AppButtonKind kind;
  final Color? tint;
  final String? sub;
  final bool expand;
  final double height;

  const AppButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.kind = AppButtonKind.tonal,
    this.tint,
    this.sub,
    this.expand = false,
    this.height = 38,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null;
    final tint = widget.tint ??
        (widget.kind == AppButtonKind.danger ? AppUi.rust : AppUi.accent);
    final hot = (_hover || _down) && !disabled;

    late final Color bg;
    late final Color border;
    late final Color fg;
    switch (widget.kind) {
      case AppButtonKind.filled:
      case AppButtonKind.danger:
        bg = hot ? Color.lerp(tint, Colors.white, 0.12)! : tint;
        border = Color.lerp(tint, Colors.black, 0.35)!;
        fg = const Color(0xFF1A0E04);
        break;
      case AppButtonKind.tonal:
        bg = hot
            ? Color.alphaBlend(tint.withValues(alpha: 0.26), AppUi.surface2)
            : Color.alphaBlend(tint.withValues(alpha: 0.14), AppUi.surface1);
        border = tint.withValues(alpha: hot ? 0.85 : 0.45);
        fg = AppUi.textHi;
        break;
      case AppButtonKind.ghost:
        bg = hot ? AppUi.surface3 : Colors.transparent;
        border = hot ? AppUi.line : Colors.transparent;
        fg = hot ? AppUi.textHi : AppUi.textMid;
        break;
    }

    final filled =
        widget.kind == AppButtonKind.filled || widget.kind == AppButtonKind.danger;

    Widget btn = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      height: widget.sub == null ? widget.height : null,
      padding: EdgeInsets.symmetric(
          horizontal: 14, vertical: widget.sub == null ? 0 : 8),
      transform: _down ? Matrix4.translationValues(0, 1, 0) : Matrix4.identity(),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppUi.radiusSm),
        border: Border.all(color: border, width: 1.2),
        boxShadow: hot && filled
            ? [BoxShadow(color: tint.withValues(alpha: 0.45), blurRadius: 12)]
            : filled
                ? const [
                    BoxShadow(
                        color: Color(0x55000000),
                        blurRadius: 4,
                        offset: Offset(0, 2))
                  ]
                : null,
      ),
      child: Row(
        mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.icon != null) ...[
            GameIcon(widget.icon!,
                size: 15, color: filled ? fg : tint),
            const SizedBox(width: 8),
          ],
          // Flexible + ellipsis: dar slotta taşıp overflow şeridi çizmesin.
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: AppUi.button.copyWith(color: fg)),
                if (widget.sub != null)
                  Text(widget.sub!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: AppUi.body.copyWith(
                          fontSize: 9.5,
                          color: filled
                              ? fg.withValues(alpha: 0.75)
                              : tint.withValues(alpha: 0.95))),
              ],
            ),
          ),
        ],
      ),
    );

    return MouseRegion(
      cursor: disabled ? MouseCursor.defer : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTapDown: disabled ? null : (_) => setState(() => _down = true),
        onTapUp: disabled ? null : (_) => setState(() => _down = false),
        onTapCancel: disabled ? null : () => setState(() => _down = false),
        onTap: widget.onTap,
        child: Opacity(opacity: disabled ? 0.4 : 1.0, child: btn),
      ),
    );
  }
}

/// Kare ikon butonu — HUD kontrolleri için.
class AppIconButton extends StatefulWidget {
  final GameIconData icon;
  final VoidCallback? onTap;
  final bool active;
  final Color? tint;
  final double size;
  final String? text; // ikon yerine kısa metin (örn "2×")

  const AppIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.active = false,
    this.tint,
    this.size = 38,
    this.text,
  });

  @override
  State<AppIconButton> createState() => _AppIconButtonState();
}

class _AppIconButtonState extends State<AppIconButton> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final tint = widget.tint ?? AppUi.accent;
    final hot = _hover || widget.active;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          width: widget.size,
          height: widget.size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.active
                ? Color.alphaBlend(tint.withValues(alpha: 0.24), AppUi.surface2)
                : hot
                    ? AppUi.surface3
                    : AppUi.surface1,
            borderRadius: BorderRadius.circular(AppUi.radiusSm),
            border: Border.all(
                color: widget.active ? tint : AppUi.line,
                width: widget.active ? 1.5 : 1),
            boxShadow: widget.active
                ? [BoxShadow(color: tint.withValues(alpha: 0.4), blurRadius: 10)]
                : null,
          ),
          child: widget.text != null
              ? Text(widget.text!,
                  style: AppUi.button.copyWith(
                      color: hot ? AppUi.textHi : AppUi.textMid, fontSize: 13))
              : GameIcon(widget.icon,
                  size: widget.size * 0.46,
                  color: hot ? AppUi.textHi : AppUi.textMid),
        ),
      ),
    );
  }
}

// ─── Stat / progress çubuğu ──────────────────────────────────────────────────

class AppStatBar extends StatelessWidget {
  final String label;
  final double value; // 0..1
  final String trailing;
  final Color color;
  final double labelWidth;

  const AppStatBar({
    super.key,
    required this.label,
    required this.value,
    required this.trailing,
    required this.color,
    this.labelWidth = 72,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: labelWidth, child: Text(label, style: AppUi.label)),
        Expanded(
          child: Container(
            height: 8,
            decoration: BoxDecoration(
              color: AppUi.surface0,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: AppUi.line, width: 0.8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, _) => FractionallySizedBox(
                    widthFactor: v,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          color.withValues(alpha: 0.8),
                          color,
                          Color.lerp(color, Colors.white, 0.28)!,
                        ]),
                        boxShadow: [
                          BoxShadow(
                              color: color.withValues(alpha: 0.5), blurRadius: 5),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 9),
        SizedBox(
          width: 42,
          child: Text(trailing,
              textAlign: TextAlign.right,
              style: AppUi.number.copyWith(fontSize: 11, color: color)),
        ),
      ],
    );
  }
}

// ─── Chip / rozet ────────────────────────────────────────────────────────────

class AppChip extends StatelessWidget {
  final String label;
  final GameIconData? icon;
  final Color color;
  final bool solid;
  const AppChip({
    super.key,
    required this.label,
    this.icon,
    required this.color,
    this.solid = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: solid
            ? color.withValues(alpha: 0.92)
            : color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.7), width: 1),
        boxShadow: solid
            ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8)]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            GameIcon(icon!, size: 11, color: solid ? const Color(0xFF1A0E04) : color),
            const SizedBox(width: 5),
          ],
          Text(label,
              style: AppUi.button.copyWith(
                fontSize: 9.5,
                letterSpacing: 1.0,
                color: solid ? const Color(0xFF1A0E04) : AppUi.textHi,
              )),
        ],
      ),
    );
  }
}

class AppDivider extends StatelessWidget {
  const AppDivider({super.key});
  @override
  Widget build(BuildContext context) => Container(
        height: 1,
        margin: const EdgeInsets.symmetric(vertical: 9),
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [
            Color(0x00000000),
            AppUi.line,
            Color(0x00000000),
          ]),
        ),
      );
}

/// Küçük başlık etiketi + hairline — bölüm ayırıcı.
class AppSectionLabel extends StatelessWidget {
  final String label;
  const AppSectionLabel(this.label, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 2),
        child: Row(children: [
          Text(label, style: AppUi.label),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 1, color: AppUi.line)),
        ]),
      );
}

// ─── Giriş animasyonu sarmalayıcı ────────────────────────────────────────────

/// Panel açılışında scale + fade + yukarı kayma — reaktif his.
class AppReveal extends StatefulWidget {
  final Widget child;
  final Duration delay;
  const AppReveal({super.key, required this.child, this.delay = Duration.zero});
  @override
  State<AppReveal> createState() => _AppRevealState();
}

class _AppRevealState extends State<AppReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 260));
  late final Animation<double> _a =
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      builder: (_, child) => Opacity(
        opacity: _a.value,
        child: Transform.translate(
          offset: Offset(0, (1 - _a.value) * 10),
          child: Transform.scale(
            scale: 0.97 + _a.value * 0.03,
            alignment: Alignment.topCenter,
            child: child,
          ),
        ),
      ),
      child: widget.child,
    );
  }
}

// ─── Vektör ikon seti ────────────────────────────────────────────────────────
//
// Emoji yerine tek tutarlı çizim dili. Her ikon line/fill karışımı, dengeli
// ağırlık. GameIconData enum + tek CustomPainter.

enum GameIconData {
  // menü
  flame, gear, scroll, chevron, close, star,
  // kaynak
  wood, stone, iron, coal, wheat, coin, honey, drop, reed,
  // insan / iş
  people, axe, pickaxe, fish, hammer,
  // hava
  sun, moon, rain, storm, dawn,
  // aksiyon
  pause, play, festival, demolish, tax, sell, dice, bolt, map, bug, speed,
  // durum
  cog, heart, home, warehouse,
}

class GameIcon extends StatelessWidget {
  final GameIconData icon;
  final double size;
  final Color color;
  const GameIcon(this.icon, {super.key, this.size = 16, required this.color});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _GameIconPainter(icon, color)),
      );
}

class _GameIconPainter extends CustomPainter {
  final GameIconData icon;
  final Color color;
  _GameIconPainter(this.icon, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final c = Offset(w / 2, h / 2);
    final u = w / 24.0; // 24-grid birim
    final stroke = Paint()
      ..color = color
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 * u
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..color = color
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;

    Offset p(double x, double y) => Offset(x * u, y * u);
    Path poly(List<List<double>> pts, {bool close = true}) {
      final path = Path()..moveTo(pts.first[0] * u, pts.first[1] * u);
      for (final pt in pts.skip(1)) {
        path.lineTo(pt[0] * u, pt[1] * u);
      }
      if (close) path.close();
      return path;
    }

    switch (icon) {
      case GameIconData.flame:
        final path = Path()
          ..moveTo(c.dx, p(0, 3).dy)
          ..quadraticBezierTo(p(19, 9).dx, p(19, 9).dy, p(16.5, 17).dx, p(16.5, 17).dy)
          ..quadraticBezierTo(c.dx, p(12, 24).dy, p(7.5, 17).dx, p(7.5, 17).dy)
          ..quadraticBezierTo(p(5, 9).dx, p(5, 9).dy, c.dx, p(12, 3).dy)
          ..close();
        canvas.drawPath(path, fill);
        break;
      case GameIconData.gear:
        const teeth = 8;
        for (int i = 0; i < teeth; i++) {
          final a = i / teeth * math.pi * 2;
          canvas.drawCircle(
              c + Offset(math.cos(a), math.sin(a)) * 9 * u, 1.7 * u, fill);
        }
        canvas.drawCircle(c, 6.5 * u, stroke);
        canvas.drawCircle(c, 2.6 * u, fill);
        break;
      case GameIconData.scroll:
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(5 * u, 3 * u, 14 * u, 18 * u),
                Radius.circular(2 * u)),
            stroke);
        for (int i = 0; i < 3; i++) {
          final y = (8 + i * 4) * u;
          canvas.drawLine(Offset(8 * u, y), Offset(16 * u, y),
              stroke..strokeWidth = 1.4 * u);
        }
        break;
      case GameIconData.chevron:
        canvas.drawPath(
            poly([[9, 5], [15, 12], [9, 19]], close: false), stroke);
        break;
      case GameIconData.close:
        canvas.drawLine(p(6, 6), p(18, 18), stroke);
        canvas.drawLine(p(18, 6), p(6, 18), stroke);
        break;
      case GameIconData.star:
        _star(canvas, c, 9 * u, 4.2 * u, fill);
        break;
      case GameIconData.wood:
        // tomruk istifi — alt iki kütük ucu + üstte bir kütük (halka damarlı)
        void log(Offset o) {
          canvas.drawCircle(o, 3.6 * u, stroke..strokeWidth = 1.8 * u);
          canvas.drawCircle(o, 1.5 * u, stroke..strokeWidth = 1.2 * u);
        }
        log(Offset(8 * u, 15 * u));
        log(Offset(16 * u, 15 * u));
        log(Offset(12 * u, 8.5 * u));
        break;
      case GameIconData.stone:
        canvas.drawPath(
            poly([[4, 16], [8, 8], [16, 8], [20, 16], [16, 20], [8, 20]]), fill);
        break;
      case GameIconData.iron:
        // külçe
        canvas.drawPath(
            poly([[5, 15], [8, 10], [16, 10], [19, 15], [16, 17], [8, 17]]), fill);
        canvas.drawLine(p(8, 13), p(16, 13),
            Paint()..color = AppUi.surface1..strokeWidth = 1.2 * u);
        break;
      case GameIconData.coal:
        canvas.drawPath(
            poly([[6, 15], [9, 9], [15, 9], [18, 14], [14, 19], [9, 18]]), fill);
        break;
      case GameIconData.wheat:
        canvas.drawLine(p(12, 21), p(12, 8), stroke);
        for (int i = 0; i < 3; i++) {
          final y = (8 + i * 3.5);
          canvas.drawPath(
              poly([[12, y + 1], [8, y], [12, y - 2.5]], close: false), stroke);
          canvas.drawPath(
              poly([[12, y + 1], [16, y], [12, y - 2.5]], close: false), stroke);
        }
        break;
      case GameIconData.coin:
        canvas.drawCircle(c, 8 * u, fill);
        canvas.drawCircle(c, 8 * u, stroke..color = color.withValues(alpha: 0.4));
        final star = Paint()..color = AppUi.surface1..isAntiAlias = true;
        _star(canvas, c, 4.6 * u, 2.0 * u, star);
        break;
      case GameIconData.honey:
        canvas.drawPath(
            poly([[8, 5], [16, 5], [19, 12], [12, 21], [5, 12]]), fill);
        break;
      case GameIconData.drop:
        final path = Path()
          ..moveTo(c.dx, p(12, 3).dy)
          ..quadraticBezierTo(p(19, 14).dx, p(19, 14).dy, c.dx, p(12, 21).dy)
          ..quadraticBezierTo(p(5, 14).dx, p(5, 14).dy, c.dx, p(12, 3).dy)
          ..close();
        canvas.drawPath(path, fill);
        break;
      case GameIconData.reed:
        // saz/ot — üç eğik bıçak + tepelerinde başak
        for (final dx in [-4.0, 0.0, 4.0]) {
          final bx = 12 + dx;
          canvas.drawPath(
              Path()
                ..moveTo(bx * u, 21 * u)
                ..quadraticBezierTo((bx + dx * 0.3) * u, 12 * u,
                    (bx + dx * 0.5) * u, 5 * u),
              stroke);
          canvas.drawOval(
              Rect.fromCenter(
                  center: Offset((bx + dx * 0.5) * u, 5 * u),
                  width: 2.4 * u, height: 4.5 * u),
              fill);
        }
        break;
      case GameIconData.people:
        canvas.drawCircle(Offset(9 * u, 9 * u), 3 * u, fill);
        canvas.drawCircle(Offset(16 * u, 10 * u), 2.4 * u, fill);
        canvas.drawPath(
            poly([[3.5, 20], [4.5, 14], [13.5, 14], [14.5, 20]]), fill);
        canvas.drawPath(
            poly([[13, 20], [14, 15], [20, 15], [21, 20]]), fill);
        break;
      case GameIconData.axe:
        canvas.drawLine(p(8, 20), p(15, 6), stroke);
        canvas.drawPath(
            poly([[14, 4], [20, 7], [16, 12], [12, 8]]), fill);
        break;
      case GameIconData.pickaxe:
        canvas.drawLine(p(12, 20), p(12, 8), stroke);
        canvas.drawPath(
            poly([[4, 9], [12, 6], [20, 9]], close: false),
            stroke..strokeWidth = 2.2 * u);
        break;
      case GameIconData.fish:
        final body = Path()
          ..moveTo(p(4, 12).dx, p(4, 12).dy)
          ..quadraticBezierTo(10 * u, 5 * u, 17 * u, 12 * u)
          ..quadraticBezierTo(10 * u, 19 * u, 4 * u, 12 * u)
          ..close();
        canvas.drawPath(body, fill);
        canvas.drawPath(poly([[17, 8], [21, 12], [17, 16]]), fill);
        canvas.drawCircle(Offset(8 * u, 11 * u), 1.0 * u,
            Paint()..color = AppUi.surface1);
        break;
      case GameIconData.hammer:
        canvas.drawLine(p(7, 20), p(14, 11), stroke);
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(12 * u, 5 * u, 8 * u, 5 * u),
                Radius.circular(1.5 * u)),
            fill);
        break;
      case GameIconData.sun:
        canvas.drawCircle(c, 5 * u, fill);
        for (int i = 0; i < 8; i++) {
          final a = i / 8 * math.pi * 2;
          final d = Offset(math.cos(a), math.sin(a));
          canvas.drawLine(c + d * 7.5 * u, c + d * 10 * u, stroke);
        }
        break;
      case GameIconData.moon:
        final path = Path()
          ..addArc(Rect.fromCircle(center: c, radius: 8 * u), -math.pi / 2, math.pi)
          ..arcToPoint(Offset(c.dx, c.dy - 8 * u),
              radius: Radius.circular(10 * u), clockwise: false);
        canvas.drawPath(path, fill);
        break;
      case GameIconData.rain:
        _cloud(canvas, u, fill);
        for (final dx in [-4.0, 0.0, 4.0]) {
          canvas.drawLine(Offset((12 + dx) * u, 16 * u),
              Offset((11 + dx) * u, 20 * u), stroke);
        }
        break;
      case GameIconData.storm:
        _cloud(canvas, u, fill);
        canvas.drawPath(
            poly([[13, 14], [9, 20], [12, 20], [10, 23]], close: false), stroke);
        break;
      case GameIconData.dawn:
        // ufuk çizgisi + yarım güneş + yukarı ışınlar
        canvas.drawArc(Rect.fromCircle(center: Offset(12 * u, 18 * u), radius: 5 * u),
            math.pi, math.pi, false, fill);
        for (int i = 0; i < 5; i++) {
          final a = math.pi + (i + 0.5) / 5 * math.pi;
          final d = Offset(math.cos(a), math.sin(a));
          canvas.drawLine(Offset(12 * u, 18 * u) + d * 6.5 * u,
              Offset(12 * u, 18 * u) + d * 8.5 * u, stroke);
        }
        canvas.drawLine(p(3, 18), p(21, 18), stroke);
        break;
      case GameIconData.pause:
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(7 * u, 6 * u, 3.5 * u, 12 * u), Radius.circular(1 * u)), fill);
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(13.5 * u, 6 * u, 3.5 * u, 12 * u), Radius.circular(1 * u)), fill);
        break;
      case GameIconData.play:
        canvas.drawPath(poly([[8, 6], [18, 12], [8, 18]]), fill);
        break;
      case GameIconData.festival:
        // havai fişek patlaması — merkez + ışınlar uçlarında kıvılcım
        canvas.drawCircle(c, 1.8 * u, fill);
        for (int i = 0; i < 8; i++) {
          final a = i / 8 * math.pi * 2;
          final d = Offset(math.cos(a), math.sin(a));
          canvas.drawLine(c + d * 3.5 * u, c + d * 7.5 * u,
              stroke..strokeWidth = 1.8 * u);
          canvas.drawCircle(c + d * 9 * u, 1.0 * u, fill);
        }
        break;
      case GameIconData.demolish:
        // çöp kutusu — kapak + gövde + dikey çizgiler
        canvas.drawLine(p(5, 7), p(19, 7), stroke);
        canvas.drawLine(p(10, 7), p(10, 5), stroke..strokeWidth = 1.6 * u);
        canvas.drawLine(p(14, 5), p(14, 7), stroke);
        final body = poly([[7, 8], [8, 19], [16, 19], [17, 8]]);
        canvas.drawPath(body, fill);
        final notch = Paint()..color = AppUi.surface1..isAntiAlias = true;
        canvas.drawRect(Rect.fromLTWH(10.5 * u, 10 * u, 1.3 * u, 7 * u), notch);
        canvas.drawRect(Rect.fromLTWH(13 * u, 10 * u, 1.3 * u, 7 * u), notch);
        break;
      case GameIconData.tax:
        for (int i = 0; i < 3; i++) {
          canvas.drawOval(
              Rect.fromCenter(
                  center: Offset(12 * u, (16 - i * 3.5) * u),
                  width: 12 * u, height: 4 * u),
              i == 2 ? fill : stroke..strokeWidth = 1.6 * u);
        }
        break;
      case GameIconData.sell:
        canvas.drawCircle(Offset(9 * u, 9 * u), 5 * u, stroke);
        canvas.drawLine(p(13, 13), p(19, 19), stroke);
        canvas.drawLine(p(9, 7), p(9, 11), stroke..strokeWidth = 1.4 * u);
        break;
      case GameIconData.dice:
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(5 * u, 5 * u, 14 * u, 14 * u),
                Radius.circular(3 * u)),
            stroke);
        for (final o in [[9.0, 9.0], [15.0, 9.0], [12.0, 12.0], [9.0, 15.0], [15.0, 15.0]]) {
          canvas.drawCircle(Offset(o[0] * u, o[1] * u), 1.2 * u, fill);
        }
        break;
      case GameIconData.bolt:
        canvas.drawPath(poly([[13, 3], [6, 13], [11, 13], [9, 21], [18, 10], [12, 10]]), fill);
        break;
      case GameIconData.map:
        canvas.drawPath(
            poly([[4, 6], [10, 4], [16, 6], [20, 4], [20, 18], [16, 20], [10, 18], [4, 20]]),
            stroke);
        canvas.drawLine(p(10, 4), p(10, 18), stroke..strokeWidth = 1.3 * u);
        canvas.drawLine(p(16, 6), p(16, 20), stroke..strokeWidth = 1.3 * u);
        break;
      case GameIconData.bug:
        canvas.drawOval(Rect.fromCenter(center: c, width: 10 * u, height: 13 * u), fill);
        canvas.drawCircle(Offset(12 * u, 6 * u), 2.4 * u, fill);
        for (final dy in [9.0, 12.0, 15.0]) {
          canvas.drawLine(Offset(7 * u, dy * u), Offset(3 * u, (dy - 1) * u), stroke..strokeWidth = 1.4 * u);
          canvas.drawLine(Offset(17 * u, dy * u), Offset(21 * u, (dy - 1) * u), stroke..strokeWidth = 1.4 * u);
        }
        break;
      case GameIconData.speed:
        canvas.drawPath(poly([[6, 6], [13, 12], [6, 18]]), fill);
        canvas.drawPath(poly([[12, 6], [19, 12], [12, 18]]), fill);
        break;
      case GameIconData.cog:
        canvas.drawCircle(c, 4 * u, stroke);
        for (int i = 0; i < 6; i++) {
          final a = i / 6 * math.pi * 2;
          final d = Offset(math.cos(a), math.sin(a));
          canvas.drawLine(c + d * 5 * u, c + d * 8 * u, stroke..strokeWidth = 2.4 * u);
        }
        break;
      case GameIconData.heart:
        final path = Path()
          ..moveTo(c.dx, p(12, 19).dy)
          ..cubicTo(p(2, 11).dx, p(2, 11).dy, p(6, 4).dx, p(6, 4).dy, c.dx, p(12, 8).dy)
          ..cubicTo(p(18, 4).dx, p(18, 4).dy, p(22, 11).dx, p(22, 11).dy, c.dx, p(12, 19).dy)
          ..close();
        canvas.drawPath(path, fill);
        break;
      case GameIconData.home:
        canvas.drawPath(poly([[4, 11], [12, 4], [20, 11]], close: false), stroke);
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(6 * u, 11 * u, 12 * u, 9 * u),
                Radius.circular(1 * u)),
            stroke);
        break;
      case GameIconData.warehouse:
        canvas.drawPath(poly([[3, 10], [12, 5], [21, 10], [21, 20], [3, 20]]), stroke);
        canvas.drawLine(p(8, 14), p(16, 14), stroke..strokeWidth = 1.5 * u);
        canvas.drawLine(p(8, 17), p(16, 17), stroke..strokeWidth = 1.5 * u);
        break;
    }
  }

  void _star(Canvas canvas, Offset c, double rOuter, double rInner, Paint paint) {
    final path = Path();
    for (int i = 0; i < 10; i++) {
      final r = i.isEven ? rOuter : rInner;
      final a = -math.pi / 2 + i * math.pi / 5;
      final pt = c + Offset(math.cos(a), math.sin(a)) * r;
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _cloud(Canvas canvas, double u, Paint fill) {
    canvas.drawCircle(Offset(9 * u, 11 * u), 4 * u, fill);
    canvas.drawCircle(Offset(15 * u, 11 * u), 5 * u, fill);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(6 * u, 11 * u, 12 * u, 4 * u), Radius.circular(2 * u)),
        fill);
  }

  @override
  bool shouldRepaint(_GameIconPainter old) =>
      old.icon != icon || old.color != color;
}
