part of 'village_ledger.dart';

/// ─── MECLİS MASASI ──────────────────────────────────────────────────────────
///
/// Divan sekmesinin görsel kalbi: yuvarlak masa + etrafında GERÇEK hane
/// reisleri (headOfHouse). Kimin masada oturduğu uydurma değil, köyün hane
/// kayıtlarından gelir.
///
/// TUZAK (bir kez ısırdı): masa oranı YÜKSEKLİKTEN türetilir — genişlikten
/// türetilince dar ekranda oval eziliyordu.

class CouncilTable extends StatefulWidget {
  final List<DivanSeat> seats;

  /// Reise dokununca açılacak eylemler. null → masa salt gösterim.
  final List<HouseActionEntry> Function(String surname)? actionsFor;

  /// ÖNİZLEME/CAPTURE için açık başlayacak koltuk (-1 = kapalı). Oyunda
  /// kullanılmaz; harness kartı dokunmadan çekebilsin diye.
  final int initiallySelected;

  /// TAHTA KİPİ (telefon) — masa sabit boy yerine VERİLEN alanı doldurur ve
  /// reise dokununca açılan eylem kartı masanın ALTINA eklenmez, ÜSTÜNE biner.
  ///
  /// Neden: tahtada sütunun boyu sabittir (bkz. ui/ledger_board.dart). Kart
  /// alta eklenince sütun uzamak ister, uzayamaz, taşar. Kartı masanın üstüne
  /// bindirmek yerleşimi hiç kıpırdatmaz — ve telefonda zaten doğru olan
  /// davranış budur: seçtiğin reisin kartı, masanın önüne çıkar.
  final bool fill;

  const CouncilTable({
    super.key,
    required this.seats,
    this.actionsFor,
    this.initiallySelected = -1,
    this.fill = false,
  });
  @override
  State<CouncilTable> createState() => _CouncilTableState();
}

class _CouncilTableState extends State<CouncilTable>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _t = 0;
  Duration _last = Duration.zero;

  /// Painter'ın her karede doldurduğu koltuk merkezleri — dokunma vuruş testi
  /// AYNI geometriyi kullansın diye (iki yerde hesaplanırsa kayarlar).
  final List<Offset> _seatCenters = [];

  /// Seçili reisin masadaki sırası (-1 = kart kapalı).
  late int _selected = widget.initiallySelected;

  void _tapAt(Offset p) {
    if (widget.actionsFor == null) return;
    var best = -1;
    var bestD = double.infinity;
    for (int i = 0; i < _seatCenters.length; i++) {
      final d = (p - _seatCenters[i]).distance;
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    // Cömert dokunma yarıçapı — figürler küçük, parmak büyük.
    if (best < 0 || bestD > 46) {
      setState(() => _selected = -1);
      return;
    }
    setState(() => _selected = _selected == best ? -1 : best);
  }

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  void _tick(Duration e) {
    final dt = ((e - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = e;
    setState(() => _t += dt);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sel = (_selected >= 0 && _selected < widget.seats.length)
        ? widget.seats[_selected]
        : null;
    if (widget.fill) return _filled(sel);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RepaintBoundary(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppUi.radiusSm),
            child: SizedBox(
              // TELEFON YATAY: defterin gövdesine ~300dp kalıyor. 236dp'lik
              // masa + künye + ipucu o gövdenin tamamını yiyor, Divan açılınca
              // GÜNDEM maddeleri (yani yanıt bekleyen işler) fold altında
              // kalıyordu — oyuncu Divan'ı açıp yapacak iş göremiyordu.
              // Masa oranları yükseklikten türediği için (bkz. _CouncilPainter)
              // alçaltmak sahneyi bozmaz, sadece küçültür.
              height: useCompactGameUi(context) ? 150 : 236,
              width: double.infinity,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => _tapAt(d.localPosition),
                child: CustomPaint(
                  painter: _CouncilPainter(
                      widget.seats, _t, _seatCenters, _selected),
                ),
              ),
            ),
          ),
        ),
        if (sel != null) ...[
          const SizedBox(height: 8),
          _HouseActionCard(
            seat: sel,
            entries: widget.actionsFor!(sel.surname),
            onClose: () => setState(() => _selected = -1),
          ),
        ] else if (widget.actionsFor != null && widget.seats.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('Bir reise dokun — hanesiyle işin varsa oradan görürsün.',
              textAlign: TextAlign.center,
              style: AppUi.label.copyWith(color: AppUi.textLo)),
        ],
      ],
    );
  }

  /// Tahta kipi — masa alanı doldurur, eylem kartı üstüne biner.
  Widget _filled(DivanSeat? sel) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppUi.radiusSm),
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _tapAt(d.localPosition),
              child: CustomPaint(
                painter:
                    _CouncilPainter(widget.seats, _t, _seatCenters, _selected),
              ),
            ),
          ),
          // NOT: "Bir reise dokun" ipucu tahtada YOK — painter masanın dibine
          // zaten reislerin isim şeridini çiziyor ve ipucu tam onun üstüne
          // biniyordu. İsimler okunur durduğu sürece dokunulacağı da anlaşılır.

          // Eylem kartı masanın ÖNÜNE çıkar. Kendi içinde kayar: eylem sayısı
          // haneye göre değişir ve sütunun boyu bunu bilemez — kaydırma yalnız
          // bu küçük yüzeye hapsedilir, ekranın tamamına bulaşmaz.
          if (sel != null)
            Positioned.fill(
              child: DecoratedBox(
                decoration: const BoxDecoration(color: AppUi.scrim),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(4),
                  child: _HouseActionCard(
                    seat: sel,
                    entries: widget.actionsFor!(sel.surname),
                    onClose: () => setState(() => _selected = -1),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// DİVAN HALKASI — hanelerin reisleri közün etrafında yarım ay dizilmiş,
/// oyuncuya bakıyor. **Masa nesnesi YOK**: boyanmış kahverengi bir levha hem
/// çirkindi hem de bu projenin palet kuralını çiğniyordu (de-wood: soğuk grafit
/// yüzeyler, kahve/parşömen yasak — bkz. feedback_no_wood_palette). Çizilecek
/// levha olmayınca çirkinleşecek yüzey de kalmıyor; geriye zemin, ışık, gölge
/// ve İNSANLAR kalıyor.
///
/// Kompozisyon: közden yayılan sıcak ışık havuzu + radyal uzayan gölgeler +
/// tam boy figürler (belden kesme YOK) + altta isim şeridi.
class _CouncilPainter extends CustomPainter {
  final List<DivanSeat> seats;
  final double t;

  /// Vuruş testi için figür merkezleri — painter doldurur, widget okur.
  final List<Offset> outSeatCenters;

  /// Seçili sıra (-1 yok).
  final int selected;

  _CouncilPainter(this.seats, this.t, this.outSeatCenters, this.selected);

  /// İsim şeridinin yüksekliği (alt kenar).
  static const double _kStrip = 26;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final floorY = (h - _kStrip) * 0.80; // figürlerin bastığı taban
    final cx = w / 2;

    _floor(canvas, size, floorY);

    final n = seats.length;
    if (n == 0) return;

    // Yarım ay: ortadakiler UZAKTA (yukarıda, küçük), kenardakiler YAKINDA.
    double u(int i) => n == 1 ? 0 : (i - (n - 1) / 2) / ((n - 1) / 2);
    // Halka SIKI olmalı: aralık panel genişliğinden değil FİGÜR boyundan
    // türetilir, yoksa geniş panelde dört kişi bir sıraya dizilir ve
    // "toplanmış" değil "sıraya girmiş" görünürler.
    final lift = (h - _kStrip) * 0.17;
    final figW = (h / 236.0) * 46;
    final spread =
        math.min(w * 0.36, n <= 1 ? 0.0 : figW * 1.55 * (n - 1) / 2);

    Offset footOf(int i) {
      final uu = u(i);
      return Offset(cx + uu * spread, floorY - lift * (1 - uu * uu));
    }

    double scaleOf(int i) {
      final a = u(i).abs();
      return (h / 236.0) * (1.18 + 0.17 * a);
    }

    // Köz: halkanın ORTASINDA ama biraz ÖNDE — merkezdeki figür örtmesin.
    final ember = Offset(cx, floorY + (h - _kStrip) * 0.10);
    _emberPool(canvas, size, ember);

    // Arkadan öne çiz (merkez uzak → önce).
    final order = List.generate(n, (i) => i)
      ..sort((a, b) => u(a).abs().compareTo(u(b).abs()));

    outSeatCenters
      ..clear()
      ..addAll(List.filled(n, Offset.zero));

    for (final i in order) {
      final foot = footOf(i);
      final s = scaleOf(i);
      outSeatCenters[i] = foot.translate(0, -42 * s);
      _figure(canvas, size, seats[i], foot, s, ember, i == selected);
    }

    _ember(canvas, ember, h);
    _sparks(canvas, size, ember);
    _nameStrip(canvas, size, footOf, scaleOf);
  }

  // ── Zemin ──────────────────────────────────────────────────────────────────

  /// Soğuk grafit zemin — arkada karanlık, önde hafif açılan bir düzlem.
  /// Ahşap/parşömen YOK; sıcaklık yalnız közden gelir.
  void _floor(Canvas canvas, Size size, double floorY) {
    final w = size.width, h = size.height;
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFF0B0D11));
    // Arka duvar → zemin geçişi (yumuşak ufuk).
    final wall = Rect.fromLTWH(0, 0, w, floorY);
    canvas.drawRect(
        wall,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: const [Color(0xFF0A0C10), Color(0xFF15181F)],
          ).createShader(wall));
    final floor = Rect.fromLTWH(0, floorY - 1, w, h - floorY + 1);
    canvas.drawRect(
        floor,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: const [Color(0xFF1A1E26), Color(0xFF0C0E13)],
          ).createShader(floor));
    // Köşe kararması — dikkat ortada toplansın.
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = RadialGradient(
            center: Alignment.center,
            radius: 0.95,
            colors: const [Color(0x00000000), Color(0x8C000000)],
            stops: const [0.5, 1.0],
          ).createShader(Offset.zero & size));
  }

  /// Közün zemine düşürdüğü sıcak ışık havuzu — halkayı bir arada tutan şey bu.
  void _emberPool(Canvas canvas, Size size, Offset ember) {
    final flick = 0.9 + 0.1 * math.sin(t * 6.0) + 0.05 * math.sin(t * 13.0);
    final rx = size.width * 0.30 * flick;
    final ry = size.height * 0.20 * flick;
    final r = Rect.fromCenter(
        center: ember, width: rx * 2, height: ry * 2);
    canvas.drawOval(
        r,
        Paint()
          ..shader = RadialGradient(colors: [
            Color.fromRGBO(255, 176, 88, 0.52 * flick),
            Color.fromRGBO(255, 130, 50, 0.18),
            const Color(0x00000000),
          ], stops: const [
            0.0,
            0.45,
            1.0
          ]).createShader(r));
  }

  /// Köz/mangal — küçük, sıcak, canlı. Halkanın merkezi.
  void _ember(Canvas canvas, Offset at, double h) {
    final flick = 0.85 + 0.15 * math.sin(t * 9) + 0.08 * math.sin(t * 17);
    final base = h * 0.052;

    // OCAK TAŞLARI — ateşi yere oturtan halka. Közün baktığı yüzleri sıcak,
    // arkaları koyu; ateşin "bir yerde yandığını" söyleyen şey bu.
    for (int i = 0; i < 9; i++) {
      final a = i * (math.pi * 2 / 9) + 0.3;
      final sx = at.dx + math.cos(a) * base * 2.9;
      final sy = at.dy + math.sin(a) * base * 1.25;
      final lit = (0.5 + 0.5 * math.sin(a - math.pi / 2)).clamp(0.0, 1.0);
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(sx, sy), width: base * 1.1, height: base * 0.7),
          Paint()
            ..color = Color.lerp(const Color(0xFF1B1F26),
                const Color(0xFF6B4630), lit * 0.75 * flick)!);
    }

    // Kömür yatağı (koyu, közle aydınlanan birkaç parça).
    for (int i = 0; i < 5; i++) {
      final a = i * 1.26;
      final o = at.translate(math.cos(a) * base * 1.5, math.sin(a) * base * 0.5);
      canvas.drawOval(
          Rect.fromCenter(center: o, width: base * 1.5, height: base * 0.8),
          Paint()..color = const Color(0xFF241812));
      canvas.drawOval(
          Rect.fromCenter(
              center: o, width: base * 0.9, height: base * 0.45),
          Paint()
            ..color = Color.fromRGBO(
                255, 120, 40, (0.35 + 0.3 * math.sin(t * 3 + i)).clamp(0.1, 0.7)));
    }

    // Alev dilleri — küçük, iki kat.
    for (int i = 0; i < 3; i++) {
      final sp = t * (3.0 + i * 0.8) + i * 1.9;
      final hh = base * (2.2 + 0.9 * math.sin(sp)) * flick;
      final ww = base * (0.85 - i * 0.16);
      final lean = math.sin(sp * 0.9) * ww * 0.35;
      final rr = Rect.fromLTRB(
          at.dx - ww, at.dy - hh, at.dx + ww, at.dy + base * 0.2);
      canvas.drawPath(
          Path()
            ..moveTo(at.dx - ww, at.dy)
            ..quadraticBezierTo(
                at.dx - ww * 0.9, at.dy - hh * 0.55, at.dx + lean, at.dy - hh)
            ..quadraticBezierTo(
                at.dx + ww * 0.9, at.dy - hh * 0.55, at.dx + ww, at.dy)
            ..close(),
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Color.fromRGBO(255, 226, 160, 0.95),
                Color.fromRGBO(255, 146, 46, 0.75),
                const Color(0x00C83C14),
              ],
              stops: const [0.0, 0.45, 1.0],
            ).createShader(rr));
    }
  }

  /// Ateşten yükselen közler + ince duman — sahneye hayat veren şey. Sabit bir
  /// alev "resim", yükselen köz "yanıyor" demek.
  void _sparks(Canvas canvas, Size size, Offset at) {
    final paint = Paint();
    for (int i = 0; i < 16; i++) {
      final life = (t * 0.38 + _h(i, 91)) % 1.0;
      final rise = size.height * 0.42 * life;
      final drift = math.sin(t * 1.2 + i * 1.7) * size.width * 0.020 * life;
      final x = at.dx + (_h(i, 92) - 0.5) * size.width * 0.045 + drift;
      final y = at.dy - rise - size.height * 0.02;
      final a = (1 - life) * (1 - life) * 0.9;
      paint.color = Color.fromRGBO(255, 176, 84, a);
      canvas.drawCircle(Offset(x, y), 1.0 + _h(i, 93) * 1.5, paint);
    }
    // Duman sütunu — çok soluk, genişleyerek yükselir.
    for (int i = 0; i < 5; i++) {
      final life = (t * 0.16 + i * 0.2) % 1.0;
      final rise = size.height * 0.55 * life;
      final w = size.width * (0.035 + 0.075 * life);
      final y = at.dy - rise - size.height * 0.03;
      final x = at.dx + math.sin(t * 0.5 + i * 1.3) * size.width * 0.018 * life;
      final r = Rect.fromCenter(center: Offset(x, y), width: w, height: w * 0.7);
      canvas.drawOval(
          r,
          Paint()
            ..shader = RadialGradient(colors: [
              Color.fromRGBO(180, 150, 140, 0.10 * (1 - life)),
              const Color(0x00B4968C),
            ]).createShader(r));
    }
  }

  /// Deterministik gürültü (köz/duman dağılımı) — rastgelelik yok, kare
  /// yeniden çizilince parçacıklar zıplamaz.
  double _h(int i, int salt) {
    final x = math.sin(i * 127.1 + salt * 311.7) * 43758.5453;
    return x - x.floorToDouble();
  }

  // ── Figürler ───────────────────────────────────────────────────────────────

  /// Bir reis — TAM BOY (belden kesme yok), közden gelen sıcak kenar ışığıyla,
  /// zeminde közden UZAĞA uzanan gölgesiyle.
  void _figure(Canvas canvas, Size size, DivanSeat seat, Offset foot, double s,
      Offset ember, bool isSelected) {
    // Gölge: közden dışa doğru uzar (ışık kaynağı köz).
    final dx = foot.dx - ember.dx, dy = foot.dy - ember.dy;
    final len = math.max(1.0, math.sqrt(dx * dx + dy * dy));
    final ang = math.atan2(dy, dx);
    canvas.save();
    canvas.translate(foot.dx, foot.dy + 1);
    canvas.rotate(ang);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(len * 0.10, 0),
            width: 46 * s + len * 0.20,
            height: 11 * s),
        Paint()
          ..color = const Color(0x66000000)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3.5 * s));
    canvas.restore();

    // Seçili: ayak dibinde ember halka.
    if (isSelected) {
      final r = Rect.fromCenter(
          center: foot.translate(0, 2), width: 56 * s, height: 17 * s);
      canvas.drawOval(
          r,
          Paint()
            ..shader = RadialGradient(colors: [
              const Color(0xB3E9C552),
              const Color(0x00E9C552),
            ]).createShader(r));
    }

    // Baskın hane: başın arkasında altın hâle.
    if (seat.ascendant) {
      final hc = foot.translate(0, -58 * s);
      canvas.drawCircle(
          hc,
          52 * s,
          Paint()
            ..shader = RadialGradient(colors: [
              const Color(0x33E9C552),
              const Color(0x00E9C552),
            ], stops: const [
              0.25,
              1.0
            ]).createShader(Rect.fromCircle(center: hc, radius: 52 * s)));
    }

    final bounds = Rect.fromCenter(
        center: foot.translate(0, -45 * s), width: 110 * s, height: 110 * s);
    canvas.saveLayer(bounds, Paint());
    canvas.save();
    canvas.translate(foot.dx, foot.dy);
    canvas.scale(s, s);
    CharacterRenderer.draw(
      canvas,
      seat.type,
      flipX: false, // karşıya, bize bakar
      walkPhase: t * 1.15 + seat.name.hashCode % 100 * 0.03,
      moveIntensity: 0,
      // NOT: CharPose.sit DENENDİ ve geri alındı — o poz oyunun İZOMETRİK
      // görünümü için (bob:15 + bacaklar öne katlı); düz cepheden bakınca
      // figürler havada uçuyor gibi duruyor. Ayakta poz burada doğru okur.
      visual: seat.visual,
      time: t,
      stage: seat.stage,
    );
    canvas.restore();

    // Işık MESAFEYLE söner: köze yakın oturan sıcak ve parlak, uzaktaki sönük
    // ve soğuk. Herkese aynı kenar ışığı verilince sahne düz kalıyordu.
    final near = (1.0 - (len / (size.width * 0.34))).clamp(0.0, 1.0);
    final flick = 0.92 + 0.08 * math.sin(t * 7.5 + foot.dx);
    canvas.drawRect(
        bounds,
        Paint()
          ..blendMode = BlendMode.srcATop
          ..color = Color.fromRGBO(14, 20, 32, 0.42 - 0.24 * near));
    final warmFromRight = foot.dx < ember.dx;
    canvas.drawRect(
        bounds,
        Paint()
          ..blendMode = BlendMode.srcATop
          ..shader = LinearGradient(
            begin: warmFromRight ? Alignment.centerRight : Alignment.centerLeft,
            end: warmFromRight ? Alignment.centerLeft : Alignment.centerRight,
            colors: [
              Color.fromRGBO(255, 178, 100, (0.34 + 0.42 * near) * flick),
              const Color(0x00FFB264),
            ],
            stops: const [0.0, 0.82],
          ).createShader(bounds));
    canvas.restore();
  }

  // ── İsim şeridi ────────────────────────────────────────────────────────────

  /// Adlar sahnenin İÇİNE boyanmaz (havada duruyor gibi olurdu) — altta kendi
  /// şeridinde, her figürün hizasında durur.
  void _nameStrip(Canvas canvas, Size size, Offset Function(int) footOf,
      double Function(int) scaleOf) {
    final y = size.height - _kStrip;
    canvas.drawLine(Offset(size.width * 0.06, y), Offset(size.width * 0.94, y),
        Paint()..color = const Color(0x1FFFFFFF));

    for (int i = 0; i < seats.length; i++) {
      final seat = seats[i];
      final x = footOf(i).dx;
      final on = i == selected;
      final tp = TextPainter(
        text: TextSpan(
          text: seat.name,
          style: TextStyle(
            fontFamily: AppUi.fontText,
            fontSize: 10,
            height: 1.0,
            fontWeight: on || seat.ascendant ? FontWeight.w800 : FontWeight.w600,
            color: on
                ? AppUi.accent
                : seat.ascendant
                    ? AppUi.gold
                    : AppUi.textMid,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 90);
      final dot = _councilHouseColor(seat.surname);
      final totalW = tp.width + 10;
      canvas.drawCircle(Offset(x - totalW / 2 + 3, y + 12), 2.6,
          Paint()..color = dot);
      tp.paint(canvas, Offset(x - totalW / 2 + 10, y + 7));
    }
  }

  @override
  bool shouldRepaint(covariant _CouncilPainter old) => true;
}


/// rejim mi, kese mi).
