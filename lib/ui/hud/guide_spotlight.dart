import 'dart:math';

import 'package:flutter/material.dart';

import 'app_ui.dart';

/// ÖĞRETİCİ İŞARETİ — "şuna tıkla"yı ekranda GÖSTEREN katman.
///
/// Tasarım kuralları:
///   • ENGELLEMEZ. Katman [IgnorePointer]; oyuncu işaretin gösterdiği şeye
///     doğrudan tıklar. Öğretici bir kapı değil, bir işaret.
///   • TEK HEDEF. Aynı anda bir çerçeve. İki ok gösteren öğretici öğretmez.
///   • KENDİ KAPANIR. Oyuncu isteneni yapınca hedef değişir/kaybolur ve işaret
///     düşer. Karta dokunmak da kapatır — ayrı bir düğme gerekmez.
///
/// GÖRSEL — DELİK DEĞİL VİNYET.
///
/// Önceki hâl mobil oyun onboarding'inin ta kendisiydi: tam ekran %55
/// karartma, hedefte bir delik, deliğin etrafında iki nabız halkası ve altta
/// "Anladım" düğmeli bir kart. Üç ayrı şey aynı anda bağırıyordu ve altındaki
/// köyü de saklıyordu — oyuncunun neyi neden yaptığını GÖRMESİ gerekir.
///
/// Şimdi karartma yok. Ekranın yalnız KENARLARI yumuşakça koyulaşır (vinyet),
/// hedefin üstü doğal kalır; göz kenarlardan merkeze kendiliğinden çekilir.
/// Hedefin çevresinde tek ince ember çizgi — nabız yok, halo yok
/// (bkz. feedback_lighting_restraint: additive/agresif değerler göz alıyor).
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
  static String command(String label) => 'cmd:$label';

  /// Komuta çubuğundaki Köy Defteri kapısı — yönetişim adımının ilk halkası.
  static const String gateDefter = 'gate:defter';

  /// Defterin içindeki KANUNNAME rafı — ikinci halka. Telefon rayı bu çapayı
  /// taşımaz; öğretici orada sessizce susar (yanlış yeri göstermektense).
  static const String sectionKanun = 'section:kanun';
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
}

class GuideSpotlight extends StatefulWidget {
  const GuideSpotlight({super.key, required this.cue, required this.onDismiss});

  final GuideCue cue;
  final VoidCallback onDismiss;

  @override
  State<GuideSpotlight> createState() => _GuideSpotlightState();
}

class _GuideSpotlightState extends State<GuideSpotlight>
    with SingleTickerProviderStateMixin {
  /// Beliriş — işaret ekrana PAT diye düşmesin (öğretici bir uyarı değil).
  /// Tek denetleyici: nabız kalktığı için sürekli dönen bir animasyon da
  /// kalmadı, katman artık yalnız açılırken boyanır.
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  )..forward();

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final cue = widget.cue;

    return AnimatedBuilder(
      animation: _in,
      builder: (context, _) {
        // Hedefi HER KAREDE yeniden ölçeriz: köylü yürür, panel kayar,
        // kamera oynar. Sabitlenmiş bir çerçeve iki saniye sonra yalan söyler.
        final rect = cue.anchorId == null
            ? null
            : GuideAnchors.rectOf(cue.anchorId!);
        final Rect frame;
        final bool round;
        if (rect != null) {
          frame = rect.inflate(6);
          round = false;
        } else if (cue.spot != null) {
          frame = Rect.fromCircle(center: cue.spot!, radius: cue.radius);
          round = true;
        } else {
          // Hedef kayboldu — vinyeti tek başına bırakma, hiç çizme.
          return const SizedBox.shrink();
        }

        final appear = Curves.easeOutCubic.transform(_in.value);

        return Stack(
          children: [
            // (1) Vinyet + hedef çerçevesi. TIKLAMAYI GEÇİRİR — işaretin
            // gösterdiği düğmeye oyuncu doğrudan basabilmeli.
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _SpotPainter(
                    frame: frame,
                    round: round,
                    appear: appear,
                  ),
                ),
              ),
            ),
            // (2) Söz — çerçevenin altına, sığmıyorsa üstüne.
            _caption(size, frame, appear),
          ],
        );
      },
    );
  }

  Widget _caption(Size size, Rect frame, double appear) {
    const cardW = 288.0;
    final w = min(cardW, size.width - 32);
    // Yatayda çerçeveye ortala, ekran kenarlarına yapışma.
    final left = (frame.center.dx - w / 2)
        .clamp(16.0, max(16.0, size.width - w - 16))
        .toDouble();
    // Dikeyde: altta yer varsa alta, yoksa üste. Yüksekliği ölçmeye gerek
    // yok — üstteyken `bottom` ile demirliyoruz.
    final below = frame.bottom + 160 < size.height;

    final card = Opacity(
      opacity: appear,
      child: Transform.translate(
        offset: Offset(0, (1 - appear) * (below ? 10 : -10)),
        child: _card(w),
      ),
    );

    return below
        ? Positioned(left: left, top: frame.bottom + 14, width: w, child: card)
        : Positioned(
            left: left,
            bottom: size.height - frame.top + 14,
            width: w,
            child: card,
          );
  }

  /// Söz kartı. "Anladım" DÜĞMESİ YOK: bir cümle okumak için onay istemek
  /// öğreticiyi bir forma çevirir. Kartın kendisi kapatma yüzeyi — sabırsız
  /// oyuncu dokunur geçer, sabırlı oyuncu zaten isteneni yapınca kart düşer.
  Widget _card(double w) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onDismiss,
      child: Container(
        width: w,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: const Color(0xF2151519),
          borderRadius: BorderRadius.circular(AppUi.radius),
          // Kenarlık ÖLÇÜLÜ: kart zaten vinyetin ortasında tek başına duruyor,
          // bir de parlak bir çerçeveyle bağırması gerekmiyor.
          border: Border.all(color: AppUi.accent.withValues(alpha: 0.30)),
          boxShadow: const [
            BoxShadow(
              blurRadius: 24,
              color: Color(0x88000000),
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const GameIcon(GameIconData.star, size: 10,
                    color: AppUi.accent),
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
            const SizedBox(height: 6),
            Text(
              widget.cue.body,
              style: AppUi.body.copyWith(
                fontSize: 12,
                color: AppUi.textHi,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpotPainter extends CustomPainter {
  _SpotPainter({
    required this.frame,
    required this.round,
    required this.appear,
  });

  final Rect frame;
  final bool round;
  final double appear;

  /// Vinyetin en koyu noktası (ekranın dört köşesi). Bu sayı bilinçli olarak
  /// düşük: amaç köyü saklamak değil, gözün kenarlarda oyalanmasını kesmek.
  static const double _kEdge = 0.42;

  @override
  void paint(Canvas canvas, Size size) {
    // ── (1) VİNYET ────────────────────────────────────────────────────────
    // Merkezi HEDEF belirler, ekranın ortası değil: köşede duran bir düğmeyi
    // gösterirken karanlığın tam onun üstünde koyulaşması ters etki yapardı.
    // Yarıçap ekranın köşegeni kadar — gradyan hiçbir köşede bitmez, yani
    // kenarda görünür bir daire sınırı oluşmaz.
    final rect = Offset.zero & size;
    final center = Offset(
      frame.center.dx.clamp(size.width * 0.2, size.width * 0.8),
      frame.center.dy.clamp(size.height * 0.2, size.height * 0.8),
    );
    const ink = Color(0xFF05070A);
    final edge = _kEdge * appear;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(
            (center.dx / size.width) * 2 - 1,
            (center.dy / size.height) * 2 - 1,
          ),
          // 0.62 değil 1.05: gradyan ekranın köşegenini aşar, böylece hiçbir
          // köşede gradyanın BİTTİĞİ görünür bir daire sınırı oluşmaz.
          radius: 1.05,
          // Ortada TAM ŞEFFAF: hedefin üstünde tek piksel karartma yok.
          // Duraklar yumuşak — sert bir geçiş vinyeti bir "delik"e çevirir ve
          // baştan kaçtığımız şey tam olarak buydu.
          colors: [
            ink.withValues(alpha: 0),
            ink.withValues(alpha: 0),
            ink.withValues(alpha: edge * 0.55),
            ink.withValues(alpha: edge),
          ],
          stops: const [0.0, 0.30, 0.68, 1.0],
        ).createShader(rect),
    );

    // ── (2) HEDEF ÇERÇEVESİ ───────────────────────────────────────────────
    // Tek ince ember çizgi. Nabız YOK: yanıp sönen bir halka gözü çeker ama
    // okumayı da böler; hedef zaten vinyetin merkezinde duruyor.
    final path = Path();
    if (round) {
      // Dünya hedefi: izometrik zeminde daire "havada" durur — hafif basık
      // oval sahneye oturur (bkz. step beacon dersi).
      path.addOval(
        Rect.fromCenter(
          center: frame.center,
          width: frame.width,
          height: frame.height * 0.72,
        ),
      );
    } else {
      path.addRRect(
        RRect.fromRectAndRadius(frame, const Radius.circular(10)),
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..isAntiAlias = true
        ..color = AppUi.accent.withValues(alpha: 0.72 * appear),
    );
  }

  @override
  bool shouldRepaint(_SpotPainter old) =>
      old.frame != frame || old.appear != appear || old.round != round;
}
