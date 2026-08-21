import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../systems/audio_manager.dart';

/// İzometrik oyun telefonda yatay çalışır. Yükseklik, telefon ile tablet
/// ayrımında genişlikten daha güvenilir; capture harness'i de aynı mantıksal
/// ölçüleri MediaQuery üzerinden verir.
bool useCompactGameUi(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  return size.height <= 500 && size.width < 1000;
}

/// Manor Lords çıtası: sade, diegetik, ferah. Skeuomorphic ahşap/parşömen YOK,
/// çamurlu çikolata palet YOK, sıcak-kahve YOK. Bunun yerine: rafine SOĞUK-nötr
/// grafit "ink" yüzeyler (kanallar birbirine yakın, B≥R → kahve değil, serin
/// kömür/grafit), HUD için çerçevesiz okunabilirlik scrim'i, güçlü tipografi
/// (Cinzel + Spectral), tutarlı Phosphor ikon seti, ölçülü tek vurgu.
abstract final class AppUi {
  /// Önizleme/capture harness'i true yapar → animasyonlu bileşenler (AppMeter)
  /// ilk kareyi son değeriyle çizer. Aksi halde TweenAnimationBuilder'ın
  /// AnimationController'ı, harness'in zorlanmış kare saatiyle çakışıp assert
  /// atar ve panel SİYAH çıkar (bkz. ui_gallery_capture_main). Oyunda false.
  static bool captureStatic = false;

  // ── Yüzeyler (soğuk-nötr grafit — de-wood edilmiş) ──────────────────────
  // RGB kanalları birbirine yakın, hafif MAVİ eğik (B ≥ R) → "ahşap/kahve"
  // değil, serin grafit-kömür.
  static const scrim = Color(0xD6080A0C); // modal arka karartma
  static const surface0 = Color(0xFF0C0D0F); // en derin (track/oyuk)
  static const surface1 = Color(0xFF14161A); // panel gövdesi
  static const surface2 = Color(0xFF1C1F24); // yükseltilmiş / header
  static const surface3 = Color(0xFF272B31); // hover / seçili
  static const line = Color(0xFF2E333A); // hairline kenar (nötr-soğuk)
  static const lineSoft = Color(0x14FFFFFF); // ince üst iç ışık

  // Cam yüzey kenarları (AppGlass). Camın okunması KENARDAN gelir: ince bir
  // parlak çeper + üstte tek piksellik spekülar çizgi. Bunlar olmadan buzlu
  // yüzey "yarı saydam gri kutu" gibi görünür, cam gibi değil.
  static const glassEdge = Color(0x2EFFFFFF); // çeper
  static const glassHi = Color(0x3DFFFFFF); // üst spekülar

  // ── Metin (nötr off-white — ne parşömen sıcaklığı ne slate mavisi) ──────
  static const textHi = Color(0xFFF0EEE9); // ana
  static const textMid = Color(0xFFBEBAB2); // ikincil
  static const textLo = Color(0xFF87817A); // soluk / etiket

  // Vurgu üstüne oturan koyu "ink" (dolu buton/chip metni).
  static const ink = Color(0xFF150D06);

  // ── Vurgular ─────────────────────────────────────────────────────────────
  // Grafit taban SOĞUK kalır; ana vurgu ise ocak/ember SICAKLIĞI verir —
  // "ateşi yak" temasının kalbi. (Robotik mavi accent DEĞİL.)
  static const accent = Color(0xFFE49139); // ember — ana vurgu
  static const accentSoft = Color(0xFFF3B978);
  static const accentDeep = Color(0xFFB0611E);
  static const sage = Color(0xFF7FC08C); // pozitif
  static const rust = Color(0xFFD8552E); // tehlike
  static const gold = Color(0xFFD9C15E); // para / lüks
  static const info = Color(0xFF52B9B0); // su / lojistik (teal)

  // ── Tipografi ────────────────────────────────────────────────────────────
  static const fontDisplay = 'Cinzel'; // başlık / oyma kapital
  static const fontText = 'Spectral'; // gövde / sayı / buton

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

// ─── Cam yüzey ───────────────────────────────────────────────────────────────

/// Oyun dünyasının ÜSTÜNDE duran HUD yüzeyleri için buzlu cam.
///
/// Neden ayrı bir primitif: HUD okunabilirliği eskiden üst üste binen İKİ
/// karartmayla çözüyordu (geniş scrim + opak chip plakası). Dünyanın üstüne
/// düşen siyah bant hissi buradan geliyordu. Cam aynı işi karartmayla değil
/// BULANIKLIKLA yapar: arkadaki köy görünür kalır, ama yüksek frekanslı detay
/// silinir ve metin için sakin bir zemin doğar.
///
/// İki kritik nokta:
/// * [BackdropFilter] MUTLAKA bir ClipRRect içinde olmalı — yoksa filtre
///   sınırsız yayılır ve tüm ekranı bulanıklaştırır.
/// * Her örnek bir saveLayer + Gaussian pass demek. Oyun-içi overlay'de sayıyı
///   AZ tut: chip başına değil, ŞERİT başına bir cam (üst HUD 2, alt bar 1).
class AppGlass extends StatelessWidget {
  final Widget child;
  final BorderRadius? borderRadius;
  final EdgeInsets padding;

  /// Bulanıklık yarıçapı. 10-14 arası buzlu cam; altı "kirli pencere".
  final double sigma;

  /// Camın "sütlülüğü" — 0 tamamen berrak, 1 opak. Parlak gündüz gökyüzünde
  /// metnin ayakta kalması bu değere bağlı; 0.30 altına inme.
  final double density;

  /// Taban rengi — varsayılan soğuk grafit. Uyarı durumlarında (rust vb.)
  /// camı hafifçe o yöne boyamak için.
  final Color? tint;

  /// Kenar override'ı. Varsayılan çepeçevre ince çeper; ekran boyunca uzanan
  /// şeritler (alt komuta barı) için tek kenar verilir.
  ///
  /// DİKKAT: non-uniform Border (ör. `Border(top: ...)`) sıfırdan farklı bir
  /// [borderRadius] ile BİRLİKTE kullanılamaz — Flutter assert atar. Tek kenar
  /// veriyorsan radius'u [BorderRadius.zero] yap.
  final BoxBorder? border;

  const AppGlass({
    super.key,
    required this.child,
    this.borderRadius,
    this.padding = EdgeInsets.zero,
    this.sigma = 12,
    this.density = 0.42,
    this.tint,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final r = borderRadius ?? BorderRadius.circular(AppUi.radiusSm);
    final base = tint ?? AppUi.surface1;
    return ClipRRect(
      borderRadius: r,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: r,
            // Üstte biraz daha yoğun: ışık yukarıdan gelir, cam üstte "toplar".
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                base.withValues(alpha: density),
                base.withValues(alpha: density * 0.74),
              ],
            ),
            border: border ?? Border.all(color: AppUi.glassEdge, width: 1),
          ),
          child: Stack(
            children: [
              // Üst spekülar çizgi — camı "yarı saydam gri kutu"dan ayıran şey.
              Positioned(
                top: 0,
                left: 6,
                right: 6,
                child: Container(height: 1, color: AppUi.glassHi),
              ),
              Padding(padding: padding, child: child),
            ],
          ),
        ),
      ),
    );
  }
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
    final top = accent == null
        ? AppUi.surface2
        : Color.alphaBlend(accent!.withValues(alpha: 0.11), AppUi.surface2);
    final bottom = accent == null
        ? AppUi.surface1
        : Color.alphaBlend(accent!.withValues(alpha: 0.045), AppUi.surface1);
    return Container(
      width: width,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, bottom],
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
              top: 0,
              left: 0,
              right: 0,
              child: Container(height: 1, color: AppUi.lineSoft),
            ),
            // İsteğe bağlı üst aksan şeridi
            if (accent != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 2.5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accent!.withValues(alpha: 0.0),
                        accent!,
                        accent!.withValues(alpha: 0.0),
                      ],
                    ),
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
    final tint =
        widget.tint ??
        (widget.kind == AppButtonKind.danger ? AppUi.rust : AppUi.accent);
    final hot = (_hover || _down) && !disabled;

    late final Color bg;
    late final Color border;
    late final Color fg;
    switch (widget.kind) {
      case AppButtonKind.filled:
        // Sakin BİRİNCİL — doygun ember blok değil (Flash hissinin kaynağıydı),
        // grafit üzerine derin ember doku + net kenar. Palet token'ı aynı.
        bg = hot
            ? Color.alphaBlend(tint.withValues(alpha: 0.34), AppUi.surface2)
            : Color.alphaBlend(tint.withValues(alpha: 0.22), AppUi.surface1);
        border = tint.withValues(alpha: hot ? 0.9 : 0.62);
        fg = AppUi.textHi;
        break;
      case AppButtonKind.danger:
        // Yıkıcı eylem ÖLÇÜLÜ — doygun kırmızı blok değil, kırmızı tonal.
        bg = hot
            ? Color.alphaBlend(tint.withValues(alpha: 0.24), AppUi.surface2)
            : Color.alphaBlend(tint.withValues(alpha: 0.13), AppUi.surface1);
        border = tint.withValues(alpha: hot ? 0.85 : 0.5);
        fg = AppUi.textHi;
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
        widget.kind == AppButtonKind.filled ||
        widget.kind == AppButtonKind.danger;

    final Widget btn = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      // Telefonda dokunma tabanı: 38dp'lik buton temanın üç kuralından birini
      // (44dp) deliyordu — üstelik bunlar panellerin BİRİNCİL eylemleri
      // ("Takip et", "Şölen ver"). Masaüstünde 38 kalır.
      height: widget.sub != null
          ? null
          : (useCompactGameUi(context)
                ? (widget.height < 44 ? 44 : widget.height)
                : widget.height),
      padding: EdgeInsets.symmetric(
        horizontal: 14,
        vertical: widget.sub == null ? 0 : 8,
      ),
      transform: _down
          ? Matrix4.translationValues(0, 1, 0)
          : Matrix4.identity(),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppUi.radiusSm),
        border: Border.all(color: border, width: 1.2),
        // Renkli ışıma/halo YOK (göz yormanın baş sebebiydi) — yalnız ince,
        // nötr bir derinlik gölgesi. Vurgu artık renkle değil, kenar+dokuyla.
        boxShadow: filled
            ? const [
                BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.icon != null) ...[
            // İkon sıcak accent tint (dolu blok gittiği için ikon vurguyu taşır).
            GameIcon(widget.icon!, size: 15, color: tint),
            const SizedBox(width: 8),
          ],
          // Flexible + ellipsis: dar slotta taşıp overflow şeridi çizmesin.
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: AppUi.button.copyWith(color: fg),
                ),
                if (widget.sub != null)
                  Text(
                    widget.sub!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: AppUi.body.copyWith(
                      fontSize: 9.5,
                      color: filled
                          ? fg.withValues(alpha: 0.75)
                          : tint.withValues(alpha: 0.95),
                    ),
                  ),
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
        // DOKUNUŞ SESİ tek yerde: bütün paneller AppButton kullanıyor, o yüzden
        // her çağrı yerine tek tek ses eklemek yerine kapı burası. Devre dışı
        // düğme ses de çıkarmaz (tıklanmamış gibi davranır).
        onTap: disabled
            ? null
            : () {
                AudioManager.instance.playSfx(Sfx.uiTap);
                widget.onTap!();
              },
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
    // Görsel düğme kompakt kalır; telefon dokunma kutusu görünmeden 44pt'ye
    // tamamlanır. Böylece 26–32pt kapatma ikonları paneli şişirmeden rahatça
    // yakalanır.
    final targetSize = useCompactGameUi(context) && widget.size < 44
        ? 44.0
        : widget.size;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          width: targetSize,
          height: targetSize,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 130),
              width: widget.size,
              height: widget.size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: widget.active
                    ? Color.alphaBlend(
                        tint.withValues(alpha: 0.24),
                        AppUi.surface2,
                      )
                    : hot
                    ? AppUi.surface3
                    : (widget.ghost ? Colors.transparent : AppUi.surface1),
                borderRadius: BorderRadius.circular(AppUi.radiusSm),
                border: Border.all(
                  color: widget.active
                      ? tint
                      : (widget.ghost && !hot
                            ? Colors.transparent
                            : AppUi.line),
                  width: widget.active ? 1.5 : 1,
                ),
                boxShadow: widget.active
                    ? [
                        BoxShadow(
                          color: tint.withValues(alpha: 0.4),
                          blurRadius: 10,
                        ),
                      ]
                    : null,
              ),
              child: widget.text != null
                  ? Text(
                      widget.text!,
                      style: AppUi.button.copyWith(
                        color: hot ? AppUi.textHi : AppUi.textMid,
                        fontSize: 13,
                      ),
                    )
                  : GameIcon(
                      widget.icon,
                      size: widget.size * 0.46,
                      color: hot ? AppUi.textHi : AppUi.textMid,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Stat / progress çubuğu ──────────────────────────────────────────────────

/// Meter dolum parçası — [AppStatBar] hem animasyonlu hem statik (capture) yolda
/// aynı görünümü kullansın diye tek yerde. Sakin, mat renk geçişi; ışıma yok.
Widget _meterFill(double factor, Color color) => FractionallySizedBox(
  widthFactor: factor,
  child: Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [color.withValues(alpha: 0.78), color.withValues(alpha: 0.95)],
      ),
    ),
  ),
);

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
        SizedBox(
          width: labelWidth,
          child: Text(label, style: AppUi.label),
        ),
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
                // Sakin dolum — parlak beyaz gloss + renkli ışıma yok (Flash/göz
                // yorgunluğu). Capture harness'inde animasyon KAPALI (assert →
                // siyah kare); oyunda yumuşak dolum animasyonu.
                child: AppUi.captureStatic
                    ? _meterFill(value.clamp(0.0, 1.0), color)
                    : TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
                        duration: const Duration(milliseconds: 450),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, _) => _meterFill(v, color),
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 9),
        SizedBox(
          width: 42,
          child: Text(
            trailing,
            textAlign: TextAlign.right,
            style: AppUi.number.copyWith(fontSize: 11, color: color),
          ),
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
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width - 24,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: solid
            ? color.withValues(alpha: 0.92)
            : color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.7), width: 1),
        // Renkli ışıma yok — chip kenar + dolguyla okunur, halo göz yormasın.
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            GameIcon(icon!, size: 11, color: solid ? AppUi.ink : color),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppUi.button.copyWith(
                fontSize: 9.5,
                letterSpacing: 1.0,
                color: solid ? AppUi.ink : AppUi.textHi,
              ),
            ),
          ),
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
      gradient: LinearGradient(
        colors: [Color(0x00000000), AppUi.line, Color(0x00000000)],
      ),
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
    child: Row(
      children: [
        Text(label, style: AppUi.label),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1, color: AppUi.line)),
      ],
    ),
  );
}

// ─── Oyma altın çerçeve (premium diyalog yüzeyi) ─────────────────────────────

/// İnce altın oyma çerçeveli koyu pano — oyunun "önemli an" diyalog dili
/// (dilekçe modalı, Divan, kayıt ekranı aynı ağırlıkta görünsün). Parşömen/ahşap
/// YOK. Çocuğu köşelere kadar yaslar (hero illüstrasyonu için kendi clip'i var).
class AppGildedFrame extends StatelessWidget {
  final Widget child;
  final Color accent;
  const AppGildedFrame({
    super.key,
    required this.child,
    this.accent = AppUi.accent,
  });

  @override
  Widget build(BuildContext context) {
    const r = AppUi.radius;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppUi.surface2, AppUi.surface1],
        ),
        borderRadius: BorderRadius.circular(r),
        border: Border.all(
          color: AppUi.gold.withValues(alpha: 0.32),
          width: 1.2,
        ),
        boxShadow: [
          ...AppUi.softShadow,
          BoxShadow(color: accent.withValues(alpha: 0.16), blurRadius: 26),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: Stack(
          children: [
            child,
            // İçte ince altın hairline — "oyma" derinliği.
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  margin: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(r - 4),
                    border: Border.all(
                      color: AppUi.gold.withValues(alpha: 0.12),
                      width: 1,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Sekmeler ────────────────────────────────────────────────────────────────

/// Sekme çubuğu + animasyonlu içerik geçişi. Yoğun panelleri tek kaydırma
/// duvarına yığmak yerine nefes alan görünümlere böler (kullanıcı: "bu kalabalık
/// panellere giresim gelmiyor"). Tek sekme kalırsa çubuk çizilmez.
class AppTabs extends StatefulWidget {
  /// (etiket, içerik) — boş içerikli sekmeyi çağıran taraf zaten elemeli.
  final List<(String, Widget)> tabs;
  final int initial;
  const AppTabs({super.key, required this.tabs, this.initial = 0});

  @override
  State<AppTabs> createState() => _AppTabsState();
}

class _AppTabsState extends State<AppTabs> {
  late int _i = widget.initial.clamp(0, widget.tabs.length - 1);

  @override
  void didUpdateWidget(AppTabs old) {
    super.didUpdateWidget(old);
    // Sekme sayısı değişirse (ör. öykü doldu) seçim taşmasın.
    if (_i >= widget.tabs.length) _i = widget.tabs.length - 1;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tabs.isEmpty) return const SizedBox.shrink();
    if (widget.tabs.length == 1) return widget.tabs.first.$2;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (int i = 0; i < widget.tabs.length; i++) ...[
              if (i != 0) const SizedBox(width: 6),
              Expanded(child: _pill(widget.tabs[i].$1, i)),
            ],
          ],
        ),
        const SizedBox(height: 12),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 190),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.05, 0),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: KeyedSubtree(key: ValueKey(_i), child: widget.tabs[_i].$2),
          ),
        ),
      ],
    );
  }

  Widget _pill(String label, int i) {
    final on = _i == i;
    return GestureDetector(
      onTap: () => setState(() => _i = i),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOut,
        // Telefonda sekme = ana gezinme; 34dp'de kalıyordu. 44 dokunma eşiği
        // mobil temanın üç kuralından biri (bkz. ui/mobile_ui.dart).
        constraints: useCompactGameUi(context)
            ? const BoxConstraints(minHeight: 44)
            : const BoxConstraints(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: on ? AppUi.accent.withValues(alpha: 0.16) : AppUi.surface0,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: on ? AppUi.accent.withValues(alpha: 0.65) : AppUi.line,
            width: on ? 1.3 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppUi.label.copyWith(
              fontSize: 9,
              letterSpacing: 0.9,
              color: on ? AppUi.textHi : AppUi.textLo,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Giriş animasyonu sarmalayıcı ────────────────────────────────────────────

/// Panel açılışında scale + fade + yukarı kayma — reaktif his.
///
/// ⚠️ 2026-07-13 — BUG FIX: eski hâli elle kurulmuş `AnimationController` +
/// `CurvedAnimation` + `AnimatedBuilder` idi ve çocuğu SINIRSIZ YÜKSEKLİKTE
/// olduğunda (scroll view içinde, ya da yüksekliği verilmemiş SizedBox'ta)
/// opacity 0'da takılıp PANELİ TAMAMEN GÖRÜNMEZ bırakıyordu — Divan, köylü ve
/// bina panelleri bu yüzden çizilmiyordu. Aynı görsel efekt `TweenAnimationBuilder`
/// (örtük animasyon) ile kurulunca her ağaçta güvenle çalışıyor. Gecikme yine
/// ayrı Timer açmadan Interval ile verilir. Bkz. [[feedback_ui_render_traps]].
class AppReveal extends StatelessWidget {
  final Widget child;
  final Duration delay;
  const AppReveal({super.key, required this.child, this.delay = Duration.zero});

  static const int _revealMs = 260;

  @override
  Widget build(BuildContext context) {
    // Capture harness'inde animasyon YOK: pencere arka planda kalırsa vsync
    // gelmez, tween 0'da donar ve giriş animasyonlu her yüzey PNG'de GÖRÜNMEZ
    // olur (opacity 0). Orada doğrudan son kare çizilir.
    if (AppUi.captureStatic) return child;
    final delayMs = delay.inMilliseconds;
    final total = _revealMs + delayMs;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: total),
      curve: Interval(delayMs / total, 1.0, curve: Curves.easeOutCubic),
      builder: (_, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 10),
          child: Transform.scale(
            scale: 0.97 + t * 0.03,
            alignment: Alignment.topCenter,
            child: child,
          ),
        ),
      ),
      child: child,
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
  flame,
  gear,
  scroll,
  chevron,
  close,
  star,
  // kaynak
  wood,
  stone,
  iron,
  coal,
  wheat,
  coin,
  honey,
  drop,
  reed,
  wool,
  snow,
  // insan / iş
  people,
  axe,
  pickaxe,
  fish,
  hammer,
  // meslek (rahip / çoban / avcı / değirmenci / hancı)
  church,
  herd,
  bow,
  mill,
  tankard,
  // hava
  sun,
  moon,
  rain,
  storm,
  dawn,
  // aksiyon
  pause,
  play,
  festival,
  demolish,
  tax,
  sell,
  dice,
  bolt,
  map,
  bug,
  speed,
  // durum
  cog,
  heart,
  home,
  warehouse,
  // ses
  sound,
  soundOff,
  // görev/civic (emoji yerine temalı glyph — görev panosu)
  bank,
  market,
  flower,
  scales,
  handshake,
  crown,
  door,

  /// "İzle" — kamerayı olay vinyetine götüren düğme (bkz. EventBanner).
  eye,

  /// Kaydet — mobil ray'ın araçlar menüsünde (masaüstündeki sol-üst küme).
  save,
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

/// Oyunun ana işareti: köyün kurulduğu ilk ateş.
///
/// Logo ayrı bir görsel asset değildir; loading ekranındaki ateş sembolünün
/// kendisidir. Böylece menü, loading ve Hakkında ekranı aynı kimliği kullanır.
///
/// TELEFONDAKİ UYGULAMA SİMGESİYLE AYNI İŞLEM (`assets/ui/app_icon.svg`): alev
/// düz tek renk değil, tepeden dibe [AppUi.accentSoft] → [AppUi.accent] →
/// [AppUi.accentDeep] geçişi. Simge birebir bu üç durağı 0 / 0.58 / 1
/// noktalarında kullanır; sayılar oradan alındı, uydurulmadı. Ana ekrandaki
/// simgeyle oyunun içindeki işaret artık aynı şeyi gösteriyor.
class GameLogo extends StatelessWidget {
  final double size;

  /// Arkasındaki kor halesi — simgedeki `ember` radyal geçişinin karşılığı.
  ///
  /// Varsayılan KAPALI: logonun dört yerinden üçü zaten bir madalyonun
  /// (menü) ya da nabız atan halkanın (loading) içinde duruyor, ikinci bir
  /// hale alevi yıkayıp siliyor. Yalnız çıplak durduğu yerde (Hakkında) açılır.
  /// Açıkken widget'ın kapladığı kutu [size]'ın 1.5 katıdır.
  final bool glow;

  /// Alevin canlılığı 0..1. 1 = simgenin tam paleti; düştükçe geçiş kora
  /// çekilir. Loading ekranının nabzı ARTIK BUNU sürüyor (eski `color`
  /// parametresi yerine): nabız tek renk yakıp söndürmek yerine aynı
  /// gradyanı canlandırıp söndürüyor, yani kimlik nabızda da bozulmuyor.
  final double warmth;

  const GameLogo({
    super.key,
    required this.size,
    this.glow = false,
    this.warmth = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final w = warmth.clamp(0.0, 1.0);
    final flame = ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (r) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(AppUi.accentDeep, AppUi.accentSoft, w)!,
          Color.lerp(AppUi.accentDeep, AppUi.accent, w)!,
          AppUi.accentDeep,
        ],
        stops: const [0.0, 0.58, 1.0],
      ).createShader(r),
      // Maske srcIn ile boyayacak → alttaki glif TAM opak olmalı, yoksa
      // gradyan glifin kendi renginden süzülür ve soluk çıkar.
      child: GameIcon(GameIconData.flame, size: size, color: Colors.white),
    );
    return Semantics(
      image: true,
      label: 'LUW oyun logosu',
      child: ExcludeSemantics(
        child: glow
            ? SizedBox(
                width: size * 1.5,
                height: size * 1.5,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppUi.accent.withValues(alpha: 0.42 * w),
                            AppUi.accent.withValues(alpha: 0.14 * w),
                            AppUi.accent.withValues(alpha: 0.0),
                          ],
                          stops: const [0.0, 0.48, 1.0],
                        ),
                      ),
                      child: const SizedBox.expand(),
                    ),
                    flame,
                  ],
                ),
              )
            : flame,
      ),
    );
  }
}

// GameIconData → Phosphor glyph. Çoğu 'fill' (küçük boyda kütle + okunaklılık);
// saf-çizgi olanlar (chevron/close) 'bold' daha temiz; confetti 'regular'.
IconData _glyph(GameIconData i) {
  const fill = PhosphorIconsStyle.fill;
  const bold = PhosphorIconsStyle.bold;
  const regular = PhosphorIconsStyle.regular;
  switch (i) {
    // menü
    case GameIconData.flame:
      return PhosphorIcons.flame(fill);
    case GameIconData.gear:
      return PhosphorIcons.gearSix(fill);
    case GameIconData.scroll:
      return PhosphorIcons.scroll(fill);
    case GameIconData.chevron:
      return PhosphorIcons.caretRight(bold);
    case GameIconData.close:
      return PhosphorIcons.x(bold);
    case GameIconData.star:
      return PhosphorIcons.star(fill);
    // kaynak
    case GameIconData.wood:
      return PhosphorIcons.tree(fill);
    case GameIconData.stone:
      return PhosphorIcons.mountains(fill);
    case GameIconData.iron:
      return PhosphorIcons.cube(fill);
    case GameIconData.coal:
      return PhosphorIcons.stack(fill);
    case GameIconData.wheat:
      return PhosphorIcons.grains(fill);
    case GameIconData.coin:
      return PhosphorIcons.coins(fill);
    case GameIconData.honey:
      return PhosphorIcons.hexagon(fill);
    case GameIconData.drop:
      return PhosphorIcons.drop(fill);
    case GameIconData.reed:
      return PhosphorIcons.plant(fill);
    case GameIconData.snow:
      return PhosphorIcons.snowflake(fill);
    case GameIconData.wool:
      // Yumak yok; en yakın okunan biçim sarmal/iplik.
      return PhosphorIcons.spiral(fill);
    // insan / iş
    case GameIconData.people:
      return PhosphorIcons.usersThree(fill);
    case GameIconData.axe:
      return PhosphorIcons.axe(fill);
    case GameIconData.pickaxe:
      return PhosphorIcons.shovel(fill);
    case GameIconData.fish:
      return PhosphorIcons.fish(fill);
    case GameIconData.hammer:
      return PhosphorIcons.hammer(fill);
    // meslek
    case GameIconData.church:
      return PhosphorIcons.church(fill);
    case GameIconData.herd:
      return PhosphorIcons.cow(fill);
    case GameIconData.bow:
      return PhosphorIcons.crosshair(fill);
    case GameIconData.mill:
      return PhosphorIcons.windmill(fill);
    case GameIconData.tankard:
      return PhosphorIcons.beerStein(fill);
    // hava
    case GameIconData.sun:
      return PhosphorIcons.sun(fill);
    case GameIconData.moon:
      return PhosphorIcons.moon(fill);
    case GameIconData.rain:
      return PhosphorIcons.cloudRain(fill);
    case GameIconData.storm:
      return PhosphorIcons.cloudLightning(fill);
    case GameIconData.dawn:
      return PhosphorIcons.sunHorizon(fill);
    // aksiyon
    case GameIconData.pause:
      return PhosphorIcons.pause(fill);
    case GameIconData.play:
      return PhosphorIcons.play(fill);
    case GameIconData.festival:
      return PhosphorIcons.confetti(regular);
    case GameIconData.demolish:
      return PhosphorIcons.trash(fill);
    case GameIconData.tax:
      return PhosphorIcons.handCoins(fill);
    case GameIconData.sell:
      return PhosphorIcons.storefront(fill);
    case GameIconData.dice:
      return PhosphorIcons.diceFive(fill);
    case GameIconData.bolt:
      return PhosphorIcons.lightning(fill);
    case GameIconData.map:
      return PhosphorIcons.mapTrifold(fill);
    case GameIconData.bug:
      return PhosphorIcons.bug(fill);
    case GameIconData.speed:
      return PhosphorIcons.fastForward(fill);
    // durum
    case GameIconData.cog:
      return PhosphorIcons.gear(fill);
    case GameIconData.heart:
      return PhosphorIcons.heart(fill);
    case GameIconData.home:
      return PhosphorIcons.house(fill);
    case GameIconData.warehouse:
      return PhosphorIcons.warehouse(fill);
    // ses
    case GameIconData.sound:
      return PhosphorIcons.speakerHigh(fill);
    case GameIconData.soundOff:
      return PhosphorIcons.speakerSlash(fill);
    // görev/civic
    case GameIconData.bank:
      return PhosphorIcons.bank(fill);
    case GameIconData.market:
      return PhosphorIcons.storefront(fill);
    case GameIconData.flower:
      return PhosphorIcons.flower(fill);
    case GameIconData.scales:
      return PhosphorIcons.scales(fill);
    case GameIconData.handshake:
      return PhosphorIcons.handshake(fill);
    case GameIconData.crown:
      return PhosphorIcons.crown(fill);
    case GameIconData.door:
      return PhosphorIcons.door(fill);
    case GameIconData.eye:
      return PhosphorIcons.eye(fill);
    case GameIconData.save:
      return PhosphorIcons.floppyDisk(fill);
  }
}
