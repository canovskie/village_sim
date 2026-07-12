import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Manor Lords çıtası: sade, diegetik, ferah. Skeuomorphic ahşap/parşömen YOK,
/// çamurlu çikolata palet YOK, sıcak-kahve YOK. Bunun yerine: rafine SOĞUK-nötr
/// grafit "ink" yüzeyler (kanallar birbirine yakın, B≥R → kahve değil, serin
/// kömür/grafit), HUD için çerçevesiz okunabilirlik scrim'i, güçlü tipografi
/// (Cinzel + Spectral), tutarlı Phosphor ikon seti, ölçülü tek vurgu.
abstract final class AppUi {
  // ── Yüzeyler (soğuk-nötr grafit — de-wood edilmiş) ──────────────────────
  // RGB kanalları birbirine yakın, hafif MAVİ eğik (B ≥ R) → "ahşap/kahve"
  // değil, serin grafit-kömür.
  static const scrim     = Color(0xD6080A0C); // modal arka karartma
  static const surface0  = Color(0xFF0C0D0F); // en derin (track/oyuk)
  static const surface1  = Color(0xFF14161A); // panel gövdesi
  static const surface2  = Color(0xFF1C1F24); // yükseltilmiş / header
  static const surface3  = Color(0xFF272B31); // hover / seçili
  static const line      = Color(0xFF2E333A); // hairline kenar (nötr-soğuk)
  static const lineSoft  = Color(0x14FFFFFF); // ince üst iç ışık

  // ── Metin (nötr off-white — ne parşömen sıcaklığı ne slate mavisi) ──────
  static const textHi  = Color(0xFFF0EEE9); // ana
  static const textMid = Color(0xFFBEBAB2); // ikincil
  static const textLo  = Color(0xFF87817A); // soluk / etiket

  // Vurgu üstüne oturan koyu "ink" (dolu buton/chip metni).
  static const ink = Color(0xFF150D06);

  // ── Vurgular ─────────────────────────────────────────────────────────────
  // Grafit taban SOĞUK kalır; ana vurgu ise ocak/ember SICAKLIĞI verir —
  // "ateşi yak" temasının kalbi. (Robotik mavi accent DEĞİL.)
  static const accent     = Color(0xFFE49139); // ember — ana vurgu
  static const accentSoft = Color(0xFFF3B978);
  static const accentDeep = Color(0xFFB0611E);
  static const sage       = Color(0xFF7FC08C); // pozitif
  static const rust       = Color(0xFFD8552E); // tehlike
  static const gold       = Color(0xFFD9C15E); // para / lüks
  static const info       = Color(0xFF52B9B0); // su / lojistik (teal)

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
        // Geniş & yumuşak ambient — "ağır slab" değil, havada yüzen rafine derinlik.
        BoxShadow(color: Color(0x47000000), blurRadius: 30, offset: Offset(0, 14)),
        // Tek piksellik temas gölgesi.
        BoxShadow(color: Color(0x24000000), blurRadius: 3, offset: Offset(0, 1)),
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
        fg = AppUi.ink;
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
  /// Çerçevesiz: durağanda şeffaf (kutu yok), yalnız hover/aktifte yüzey çıkar.
  /// Ferah HUD strip'i için.
  final bool ghost;

  const AppIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.active = false,
    this.tint,
    this.size = 38,
    this.text,
    this.ghost = false,
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
                    : (widget.ghost ? Colors.transparent : AppUi.surface1),
            borderRadius: BorderRadius.circular(AppUi.radiusSm),
            border: Border.all(
                color: widget.active
                    ? tint
                    : (widget.ghost && !hot ? Colors.transparent : AppUi.line),
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
            GameIcon(icon!, size: 11, color: solid ? AppUi.ink : color),
            const SizedBox(width: 5),
          ],
          Text(label,
              style: AppUi.button.copyWith(
                fontSize: 9.5,
                letterSpacing: 1.0,
                color: solid ? AppUi.ink : AppUi.textHi,
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
  // Gecikmeyi controller süresine katıp Interval ile geciktiriyoruz — böylece
  // ayrı bir Timer (Future.delayed) açılmaz; test ortamında "timersPending"
  // assert'i tetiklenmez ve animasyon bitince ticker durur.
  static const int _revealMs = 260;
  late final int _delayMs = widget.delay.inMilliseconds;
  late final AnimationController _c = AnimationController(
      vsync: this, duration: Duration(milliseconds: _revealMs + _delayMs));
  late final Animation<double> _a = CurvedAnimation(
    parent: _c,
    curve: Interval(
      _delayMs / (_revealMs + _delayMs),
      1.0,
      curve: Curves.easeOutCubic,
    ),
  );

  @override
  void initState() {
    super.initState();
    _c.forward();
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

// ─── Phosphor ikon seti ──────────────────────────────────────────────────────
//
// Elle çizilen tutarsız CustomPainter seti yerine tek tutarlı çizim dili:
// Phosphor (ağırlıklı 'fill'). GameIconData enum aynı kalır — çağrı yerleri
// değişmez; her değer bir Phosphor glyph'ine eşlenir. Premium, dengeli, okunaklı.

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
  // ses
  sound, soundOff,
}

class GameIcon extends StatelessWidget {
  final GameIconData icon;
  final double size;
  final Color color;
  const GameIcon(this.icon, {super.key, this.size = 16, required this.color});

  @override
  Widget build(BuildContext context) =>
      Icon(_glyph(icon), size: size, color: color);
}

// GameIconData → Phosphor glyph. Çoğu 'fill' (küçük boyda kütle + okunaklılık);
// saf-çizgi olanlar (chevron/close) 'bold' daha temiz; confetti 'regular'.
IconData _glyph(GameIconData i) {
  const fill = PhosphorIconsStyle.fill;
  const bold = PhosphorIconsStyle.bold;
  const regular = PhosphorIconsStyle.regular;
  switch (i) {
    // menü
    case GameIconData.flame:     return PhosphorIcons.flame(fill);
    case GameIconData.gear:      return PhosphorIcons.gearSix(fill);
    case GameIconData.scroll:    return PhosphorIcons.scroll(fill);
    case GameIconData.chevron:   return PhosphorIcons.caretRight(bold);
    case GameIconData.close:     return PhosphorIcons.x(bold);
    case GameIconData.star:      return PhosphorIcons.star(fill);
    // kaynak
    case GameIconData.wood:      return PhosphorIcons.tree(fill);
    case GameIconData.stone:     return PhosphorIcons.mountains(fill);
    case GameIconData.iron:      return PhosphorIcons.cube(fill);
    case GameIconData.coal:      return PhosphorIcons.stack(fill);
    case GameIconData.wheat:     return PhosphorIcons.grains(fill);
    case GameIconData.coin:      return PhosphorIcons.coins(fill);
    case GameIconData.honey:     return PhosphorIcons.hexagon(fill);
    case GameIconData.drop:      return PhosphorIcons.drop(fill);
    case GameIconData.reed:      return PhosphorIcons.plant(fill);
    // insan / iş
    case GameIconData.people:    return PhosphorIcons.usersThree(fill);
    case GameIconData.axe:       return PhosphorIcons.axe(fill);
    case GameIconData.pickaxe:   return PhosphorIcons.shovel(fill);
    case GameIconData.fish:      return PhosphorIcons.fish(fill);
    case GameIconData.hammer:    return PhosphorIcons.hammer(fill);
    // hava
    case GameIconData.sun:       return PhosphorIcons.sun(fill);
    case GameIconData.moon:      return PhosphorIcons.moon(fill);
    case GameIconData.rain:      return PhosphorIcons.cloudRain(fill);
    case GameIconData.storm:     return PhosphorIcons.cloudLightning(fill);
    case GameIconData.dawn:      return PhosphorIcons.sunHorizon(fill);
    // aksiyon
    case GameIconData.pause:     return PhosphorIcons.pause(fill);
    case GameIconData.play:      return PhosphorIcons.play(fill);
    case GameIconData.festival:  return PhosphorIcons.confetti(regular);
    case GameIconData.demolish:  return PhosphorIcons.trash(fill);
    case GameIconData.tax:       return PhosphorIcons.handCoins(fill);
    case GameIconData.sell:      return PhosphorIcons.storefront(fill);
    case GameIconData.dice:      return PhosphorIcons.diceFive(fill);
    case GameIconData.bolt:      return PhosphorIcons.lightning(fill);
    case GameIconData.map:       return PhosphorIcons.mapTrifold(fill);
    case GameIconData.bug:       return PhosphorIcons.bug(fill);
    case GameIconData.speed:     return PhosphorIcons.fastForward(fill);
    // durum
    case GameIconData.cog:       return PhosphorIcons.gear(fill);
    case GameIconData.heart:     return PhosphorIcons.heart(fill);
    case GameIconData.home:      return PhosphorIcons.house(fill);
    case GameIconData.warehouse: return PhosphorIcons.warehouse(fill);
    // ses
    case GameIconData.sound:     return PhosphorIcons.speakerHigh(fill);
    case GameIconData.soundOff:  return PhosphorIcons.speakerSlash(fill);
  }
}

