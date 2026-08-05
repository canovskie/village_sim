import 'dart:math';

import 'package:flutter/material.dart';

import 'app_ui.dart';

/// ÖĞRETİCİ SPOT — "şuna tıkla"yı ekranda GÖSTEREN katman.
///
/// Neden var: kuruluş adımlarının metni doğruydu ama hiçbir yeri
/// göstermiyordu. Oyuncu "bir köylüye tıkla, İŞ bölümünden Toplayıcı de"
/// cümlesini okuyup ekranda İŞ bölümünü arıyordu — üstelik o bölüme ancak
/// köylüyü seçip "Detay"a bastıktan sonra varılıyor. Cümlenin anlattığı yol
/// üç tıklık ve üçü de görünmez.
///
/// Tasarım kuralları:
///   • ENGELLEMEZ. Karartma katmanı [IgnorePointer]; oyuncu spotun gösterdiği
///     şeye doğrudan tıklar. Öğretici bir kapı değil, bir işaret.
///   • TEK HEDEF. Aynı anda bir delik. İki ok gösteren öğretici öğretmez.
///   • KENDİ KAPANIR. Oyuncu isteneni yapınca hedef değişir/kaybolur ve spot
///     düşer; "Anladım" yalnızca sabırsız oyuncu için.
///   • Karartma İLİMLİ (0.55) — ekranı siyaha boğan öğretici, altındaki köyü
///     de saklar; oyuncunun neyi neden yaptığını görmesi gerekir.
class GuideAnchors {
  GuideAnchors._();

  /// id → o widget'ın canlı [BuildContext]'i. Rect'i cache'lemek yerine
  /// context tutuyoruz: panel kayınca/yeniden yerleşince ölçü kendiliğinden
  /// tazelenir, bayat dikdörtgen kalmaz.
  static final Map<String, BuildContext> _live = {};

  static void attach(String id, BuildContext ctx) => _live[id] = ctx;

  static void detach(String id, BuildContext ctx) {
    if (identical(_live[id], ctx)) _live.remove(id);
  }

  /// Hedefin ekran-uzayı dikdörtgeni — mount değilse null.
  ///
  /// null dönmesi öğreticinin BİLGİSİDİR, hatası değil: "kart görünmüyor"
  /// demek "önce kategoriyi aç" demek (bkz. sahne tarafındaki kademeli hedef
  /// çözümü).
  static Rect? rectOf(String id) {
    final ctx = _live[id];
    if (ctx == null || !ctx.mounted) return null;
    final box = ctx.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  static bool has(String id) => rectOf(id) != null;

  // ── id sözlüğü ──────────────────────────────────────────────────────────
  // Tek yerden türetilir ki sahne ile arayüz aynı dizeyi iki yerde yazmasın.
  static String build(String typeName) => 'build:$typeName';
  static String buildTab(String catName) => 'tab:$catName';
  /// İş yerinin İLK BOŞ KADRO YUVASI — öğreticinin "işi ver" halkası.
  /// Eskiden köylü panelindeki rol rozetiydi (`job:<rol>`); iş verme kişiden
  /// yere taşınınca hedef de yuvaya taşındı.
  static String slot(String roleName) => 'slot:$roleName';
  static String command(String label) => 'cmd:$label';
}

/// Spotun bulabilmesi için kendini kaydeden sarmalayıcı. Çizime hiç
/// karışmaz — yalnız [GuideAnchors]'a "ben buradayım" der.
class GuideTarget extends StatefulWidget {
  const GuideTarget({super.key, required this.id, required this.child});

  final String id;
  final Widget child;

  @override
  State<GuideTarget> createState() => _GuideTargetState();
}

class _GuideTargetState extends State<GuideTarget> {
  @override
  void dispose() {
    GuideAnchors.detach(widget.id, context);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Her build'de tazele: aynı id başka bir yerde yeniden doğduysa (mobil ↔
    // masaüstü yerleşimi) son mount kazanır.
    GuideAnchors.attach(widget.id, context);
    return widget.child;
  }
}

/// Spotun göstereceği şey — ya bir arayüz çapası ya da dünyada bir nokta.
@immutable
class GuideCue {
  const GuideCue({
    required this.title,
    required this.body,
    this.anchorId,
    this.spot,
    this.radius = 46,
  });

  /// Arayüz hedefi (düğme/kart). Doluysa delik o widget'ın ölçüsünden çıkar.
  final String? anchorId;

  /// Dünya hedefi (köylü/meydan) — ekran-uzayı nokta. [anchorId] boşsa kullanılır.
  final Offset? spot;
  final double radius;

  /// Kısa emir başlığı — "Bir köylü seç".
  final String title;

  /// Tek cümlelik açıklama.
  final String body;

  /// İki cue aynı şeyi mi gösteriyor — sahne bunu "spot yerinde duruyor mu"
  /// kararında kullanır (her karede yeniden animasyon başlatmamak için).
  bool sameAs(GuideCue? o) =>
      o != null &&
      o.anchorId == anchorId &&
      o.title == title &&
      (o.spot == null) == (spot == null);
}

class GuideSpotlight extends StatefulWidget {
  const GuideSpotlight({super.key, required this.cue, required this.onDismiss});

  final GuideCue cue;
  final VoidCallback onDismiss;

  @override
  State<GuideSpotlight> createState() => _GuideSpotlightState();
}

class _GuideSpotlightState extends State<GuideSpotlight>
    with TickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  )..repeat();

  /// Beliriş — spot ekrana PAT diye düşmesin (öğretici bir uyarı değil).
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final cue = widget.cue;

    return AnimatedBuilder(
      animation: Listenable.merge([_c, _in]),
      builder: (context, _) {
        // Hedefi HER KAREDE yeniden ölçeriz: köylü yürür, panel kayar,
        // kamera oynar. Sabitlenmiş bir delik iki saniye sonra yalan söyler.
        final rect = cue.anchorId == null
            ? null
            : GuideAnchors.rectOf(cue.anchorId!);
        final Rect hole;
        final bool round;
        if (rect != null) {
          hole = rect.inflate(7);
          round = false;
        } else if (cue.spot != null) {
          hole = Rect.fromCircle(center: cue.spot!, radius: cue.radius);
          round = true;
        } else {
          // Hedef kayboldu — karartmayı tek başına bırakma, hiç çizme.
          return const SizedBox.shrink();
        }

        final pulse = 0.5 + 0.5 * sin(_c.value * 2 * pi);
        final appear = Curves.easeOutCubic.transform(_in.value);

        return Stack(
          children: [
            // (1) Karartma + delik. TIKLAMAYI GEÇİRİR — spotun gösterdiği
            // düğmeye oyuncu doğrudan basabilmeli.
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _SpotPainter(
                    hole: hole,
                    round: round,
                    pulse: pulse,
                    appear: appear,
                  ),
                ),
              ),
            ),
            // (2) Söz — deliğin altına, sığmıyorsa üstüne.
            _caption(size, hole, appear),
          ],
        );
      },
    );
  }

  Widget _caption(Size size, Rect hole, double appear) {
    const cardW = 296.0;
    final w = min(cardW, size.width - 32);
    // Yatayda deliğe ortala, ekran kenarlarına yapışma.
    final left = (hole.center.dx - w / 2)
        .clamp(16.0, max(16.0, size.width - w - 16))
        .toDouble();
    // Dikeyde: altta yer varsa alta, yoksa üste. Yüksekliği ölçmeye gerek
    // yok — üstteyken `bottom` ile demirliyoruz.
    final below = hole.bottom + 190 < size.height;

    final card = Opacity(
      opacity: appear,
      child: Transform.translate(
        offset: Offset(0, (1 - appear) * (below ? 10 : -10)),
        child: _card(w),
      ),
    );

    return below
        ? Positioned(left: left, top: hole.bottom + 16, width: w, child: card)
        : Positioned(
            left: left,
            bottom: size.height - hole.top + 16,
            width: w,
            child: card,
          );
  }

  Widget _card(double w) {
    return Container(
      width: w,
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 12),
      decoration: BoxDecoration(
        color: const Color(0xF51A1C21),
        borderRadius: BorderRadius.circular(AppUi.radius),
        border: Border.all(color: AppUi.accent.withValues(alpha: 0.55)),
        boxShadow: const [
          BoxShadow(
            blurRadius: 26,
            color: Color(0x99000000),
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GameIcon(GameIconData.star, size: 11, color: AppUi.accent),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  widget.cue.title.toUpperCase(),
                  style: AppUi.title.copyWith(
                    fontSize: 11,
                    letterSpacing: 1.1,
                    color: AppUi.accentSoft,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            widget.cue.body,
            style: AppUi.body.copyWith(
              fontSize: 12,
              color: AppUi.textHi,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: AppButton(
              label: 'Anladım',
              kind: AppButtonKind.ghost,
              height: 30,
              onTap: widget.onDismiss,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpotPainter extends CustomPainter {
  _SpotPainter({
    required this.hole,
    required this.round,
    required this.pulse,
    required this.appear,
  });

  final Rect hole;
  final bool round;
  final double pulse;
  final double appear;

  @override
  void paint(Canvas canvas, Size size) {
    final holePath = Path();
    if (round) {
      // Dünya hedefi: izometrik zeminde daire "havada" durur — hafif basık
      // oval sahneye oturur (bkz. step beacon dersi).
      holePath.addOval(
        Rect.fromCenter(
          center: hole.center,
          width: hole.width,
          height: hole.height * 0.72,
        ),
      );
    } else {
      holePath.addRRect(
        RRect.fromRectAndRadius(hole, const Radius.circular(11)),
      );
    }

    final dim = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      holePath,
    );
    canvas.drawPath(
      dim,
      Paint()..color = const Color(0xFF05070A).withValues(alpha: 0.55 * appear),
    );

    // Nefes alan kenar — deliğin sınırını söyler. Additive/halo YOK
    // (bkz. feedback_lighting_restraint): düz blend, düşük alfa.
    canvas.drawPath(
      holePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..isAntiAlias = true
        ..color = AppUi.accent.withValues(
          alpha: (0.35 + 0.35 * pulse) * appear,
        ),
    );
    // Dışa doğru genişleyen ikinci halka — gözü uzaktan çeker, yavaş.
    final grow = 6.0 + 10.0 * pulse;
    final outer = round
        ? (Path()..addOval(
            Rect.fromCenter(
              center: hole.center,
              width: hole.width + grow * 2,
              height: hole.height * 0.72 + grow * 1.4,
            ),
          ))
        : (Path()..addRRect(
            RRect.fromRectAndRadius(
              hole.inflate(grow),
              Radius.circular(11 + grow),
            ),
          ));
    canvas.drawPath(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..isAntiAlias = true
        ..color = AppUi.accent.withValues(alpha: 0.22 * (1 - pulse) * appear),
    );
  }

  @override
  bool shouldRepaint(_SpotPainter old) =>
      old.hole != hole ||
      old.pulse != pulse ||
      old.appear != appear ||
      old.round != round;
}
