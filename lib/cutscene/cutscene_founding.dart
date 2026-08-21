part of 'cutscene_player.dart';

// SİNEMATİK — kuruluş kararları (fikir çipi, kimlik, mühür düğmesi)
// (Bu dosya cutscene_player.dart bölünürken ayrıldı — sınıflar
//  aynen taşındı, tek satırı değişmedi.)

class _IdeaChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _IdeaChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: MobileUi.tap,
        // widthFactor: çip yalnız yazısı kadar yer kaplar. Kısıtsız bırakılırsa
        // [Center] gelen maxWidth'i doldurur ve Wrap içinde her çip TEK BAŞINA
        // bir satıra oturur (öneri şeridi dikey bir listeye dönüşür).
        child: Center(
          widthFactor: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0x660A0E0C),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0x38FFFFFF)),
            ),
            child: Text(
              label,
              style: AppUi.button.copyWith(
                fontSize: 10.5,
                letterSpacing: 0.6,
                color: AppUi.textMid,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Kuruluş kararını bir metin kartı değil, arabanın üstündeki küçük bir yük
/// dioraması olarak gösterir. Başlık yalnız seçimi adlandırır; artı/eksi satırı
/// kararın hesabını tek bakışta bırakır.
class _FoundingLoadCard extends StatefulWidget {
  final FoundingChoice choice;
  final VoidCallback onTap;

  const _FoundingLoadCard({
    super.key,
    required this.choice,
    required this.onTap,
  });

  @override
  State<_FoundingLoadCard> createState() => _FoundingLoadCardState();
}

class _FoundingLoadCardState extends State<_FoundingLoadCard> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final touch = useTouchUi(context);
    final active = _hover || _down;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 130),
          scale: _down ? 0.98 : (active ? 1.018 : 1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: EdgeInsets.fromLTRB(11, touch ? 8 : 10, 11, 11),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.alphaBlend(
                    AppUi.accent.withValues(alpha: active ? 0.16 : 0.07),
                    const Color(0xE8171512),
                  ),
                  const Color(0xF20C0D0C),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppUi.accent.withValues(alpha: active ? 0.86 : 0.42),
                width: active ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.42),
                  blurRadius: active ? 22 : 14,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: touch ? 62 : 74,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _FoundingLoadPainter(widget.choice.id),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  widget.choice.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppUi.bodyHi.copyWith(
                    fontSize: touch ? 11.5 : 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.choice.choiceSummary,
                  textAlign: TextAlign.center,
                  style: AppUi.label.copyWith(
                    fontSize: touch ? 8 : null,
                    color: AppUi.accentSoft,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '− ',
                      style: AppUi.body.copyWith(
                        fontSize: touch ? 9.5 : 11,
                        color: AppUi.textLo,
                      ),
                    ),
                    Text(
                      widget.choice.cost,
                      style: AppUi.body.copyWith(
                        fontSize: touch ? 9.5 : 11,
                        color: AppUi.textLo,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FoundingLoadPainter extends CustomPainter {
  final String kind;
  const _FoundingLoadPainter(this.kind);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final p = Paint()..isAntiAlias = false;

    p.color = const Color(0x60000000);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w / 2, h * 0.86),
        width: w * 0.64,
        height: h * 0.20,
      ),
      p,
    );

    switch (kind) {
      case 'seed':
        _crate(canvas, Offset(w * 0.50, h * 0.62), w * 0.30, h * 0.34);
        _sack(canvas, Offset(w * 0.36, h * 0.62), w * 0.15, h * 0.38);
        _sack(canvas, Offset(w * 0.65, h * 0.66), w * 0.13, h * 0.31);
        p
          ..color = const Color(0xFFD5AD4B)
          ..strokeWidth = 2;
        for (var i = 0; i < 4; i++) {
          final x = w * (0.43 + i * 0.045);
          canvas.drawLine(Offset(x, h * 0.48), Offset(x, h * 0.22), p);
          canvas.drawLine(
            Offset(x, h * 0.31),
            Offset(x + w * 0.035, h * 0.25),
            p,
          );
        }
        break;
      case 'tools':
        _crate(canvas, Offset(w * 0.52, h * 0.65), w * 0.43, h * 0.30);
        p
          ..color = const Color(0xFF8D542D)
          ..strokeWidth = 5;
        canvas.drawLine(
          Offset(w * 0.38, h * 0.67),
          Offset(w * 0.57, h * 0.20),
          p,
        );
        p.color = const Color(0xFFB9BEC4);
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(w * 0.60, h * 0.20),
            width: w * 0.22,
            height: h * 0.12,
          ),
          p,
        );
        p
          ..color = const Color(0xFF8D542D)
          ..strokeWidth = 4;
        canvas.drawLine(
          Offset(w * 0.63, h * 0.68),
          Offset(w * 0.70, h * 0.28),
          p,
        );
        p.color = const Color(0xFF9CA2A8);
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(w * 0.70, h * 0.27),
            width: w * 0.16,
            height: h * 0.10,
          ),
          p,
        );
        break;
      case 'people':
        const colors = [
          Color(0xFFD6B58A),
          Color(0xFFC98B58),
          Color(0xFFE0C39D),
          Color(0xFFAE7650),
          Color(0xFFF0D2A8),
          Color(0xFFC69A70),
        ];
        final xs = [0.29, 0.43, 0.57, 0.71, 0.37, 0.63];
        final ys = [0.52, 0.44, 0.43, 0.54, 0.67, 0.68];
        final scales = [0.86, 1.05, 1.08, 0.82, 0.70, 0.72];
        for (var i = 0; i < xs.length; i++) {
          _person(
            canvas,
            Offset(w * xs[i], h * ys[i]),
            h * 0.28 * scales[i],
            colors[i],
          );
        }
        break;
    }
  }

  void _crate(Canvas canvas, Offset center, double width, double height) {
    final rect = Rect.fromCenter(center: center, width: width, height: height);
    final p = Paint()
      ..isAntiAlias = false
      ..color = const Color(0xFF8A542C);
    canvas.drawRect(rect, p);
    p
      ..color = const Color(0xFFC28343)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(rect, p);
    canvas.drawLine(rect.topLeft, rect.bottomRight, p);
    canvas.drawLine(rect.topRight, rect.bottomLeft, p);
  }

  void _sack(Canvas canvas, Offset center, double width, double height) {
    final p = Paint()
      ..isAntiAlias = false
      ..color = const Color(0xFFC8A66C);
    canvas.drawOval(
      Rect.fromCenter(center: center, width: width, height: height),
      p,
    );
    p
      ..color = const Color(0xFF6F492B)
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(center.dx - width * 0.28, center.dy - height * 0.34),
      Offset(center.dx + width * 0.28, center.dy - height * 0.34),
      p,
    );
  }

  void _person(Canvas canvas, Offset center, double height, Color color) {
    final p = Paint()
      ..isAntiAlias = false
      ..color = color;
    final head = height * 0.28;
    canvas.drawCircle(
      Offset(center.dx, center.dy - height * 0.34),
      head / 2,
      p,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(center.dx, center.dy),
          width: height * 0.42,
          height: height * 0.58,
        ),
        const Radius.circular(3),
      ),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant _FoundingLoadPainter oldDelegate) =>
      oldDelegate.kind != kind;
}

class _FoundingIdentity extends StatelessWidget {
  final String village;
  final String house;

  const _FoundingIdentity({required this.village, required this.house});

  @override
  Widget build(BuildContext context) {
    // upperTr: `toUpperCase()` Türkçe "i"yi noktasız "I" yapıyordu —
    // "Değirmenli" mührün üstünde "DEĞIRMENLI" diye yazıyordu (bkz. voice.dart).
    final villageName = village.isEmpty ? 'ADSIZ YURT' : upperTr(village);
    final houseName = house.isEmpty
        ? 'KURUCU HANE'
        : '${upperTr(house)} HANESİ';

    return SizedBox(
      width: 440,
      height: 196,
      child: CustomPaint(
        painter: const _FoundingSignPainter(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(46, 44, 46, 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'KÖYÜNÜ ADLANDIR',
                style: AppUi.label.copyWith(
                  color: const Color(0xFFF0C27B),
                  fontSize: 9,
                  letterSpacing: 2.4,
                ),
              ),
              const SizedBox(height: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  villageName,
                  maxLines: 1,
                  style: AppUi.display.copyWith(
                    fontSize: 32,
                    color: const Color(0xFFFFE0AF),
                    letterSpacing: 2.2,
                    shadows: const [
                      Shadow(color: Color(0xB0000000), offset: Offset(0, 2)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 9),
              Text(
                houseName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppUi.label.copyWith(
                  color: const Color(0xFFE5B873),
                  fontSize: 9.5,
                  letterSpacing: 1.7,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FoundingSignPainter extends CustomPainter {
  const _FoundingSignPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..isAntiAlias = false;
    final w = size.width;

    p
      ..color = const Color(0xFF3A291C)
      ..strokeWidth = 5;
    canvas.drawLine(Offset(w * 0.24, 0), Offset(w * 0.24, 34), p);
    canvas.drawLine(Offset(w * 0.76, 0), Offset(w * 0.76, 34), p);

    final shadow = Path()
      ..moveTo(26, 38)
      ..lineTo(w - 22, 38)
      ..lineTo(w - 12, 50)
      ..lineTo(w - 24, size.height - 12)
      ..lineTo(22, size.height - 12)
      ..lineTo(10, size.height - 26)
      ..close();
    canvas.save();
    canvas.translate(0, 7);
    p.color = const Color(0x76000000);
    canvas.drawPath(shadow, p);
    canvas.restore();

    final plank = Path()
      ..moveTo(24, 30)
      ..lineTo(w - 26, 30)
      ..lineTo(w - 12, 43)
      ..lineTo(w - 22, size.height - 20)
      ..lineTo(24, size.height - 20)
      ..lineTo(12, size.height - 34)
      ..close();
    p.shader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF724326), Color(0xFF422719), Color(0xFF2D1C14)],
    ).createShader(Offset.zero & size);
    canvas.drawPath(plank, p);
    p.shader = null;

    p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFFC98543);
    canvas.drawPath(plank, p);
    p
      ..strokeWidth = 1
      ..color = const Color(0x447A4B2E);
    canvas.drawLine(
      Offset(22, size.height * 0.52),
      Offset(w - 20, size.height * 0.49),
      p,
    );
    canvas.drawLine(
      Offset(34, size.height * 0.72),
      Offset(w - 34, size.height * 0.75),
      p,
    );
    p.style = PaintingStyle.fill;
    p.color = const Color(0xFFD7A45F);
    for (final x in [32.0, w - 34]) {
      canvas.drawCircle(Offset(x, 48), 3, p);
      canvas.drawCircle(Offset(x, size.height - 38), 3, p);
    }
  }

  @override
  bool shouldRepaint(covariant _FoundingSignPainter oldDelegate) => false;
}

class _FoundingSubmitButton extends StatefulWidget {
  final VoidCallback onTap;
  const _FoundingSubmitButton({required this.onTap});

  @override
  State<_FoundingSubmitButton> createState() => _FoundingSubmitButtonState();
}

class _FoundingSubmitButtonState extends State<_FoundingSubmitButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 46,
        transform: _down
            ? Matrix4.translationValues(0, 1.5, 0)
            : Matrix4.identity(),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFEAA04B), Color(0xFFBC6724)],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFF0C27B)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x4DE49139),
              blurRadius: 16,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const GameIcon(GameIconData.flame, size: 15, color: AppUi.ink),
            const SizedBox(width: 9),
            Text(
              'Adını koy ▸',
              style: AppUi.button.copyWith(
                color: AppUi.ink,
                fontFamily: AppUi.fontDisplay,
                fontSize: 12.5,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kameranın tek karedeki hâli — piksel cinsinden yatay/dikey kayma ve dolly
/// büyütmesi. Katmanlar bunu KENDİ derinlikleriyle ölçekleyerek uygular.
