part of 'cutscene_player.dart';

// SİNEMATİK — kamera + kare boyayıcı
// (Bu dosya cutscene_player.dart bölünürken ayrıldı — sınıflar
//  aynen taşındı, tek satırı değişmedi.)

class _Cam {
  final double panX;
  final double panY;
  final double zoom;
  const _Cam(this.panX, this.panY, this.zoom);
}

/// Prosedürel arka plan + aktör çizimi. CharacterRenderer origin'de çizer;
/// translate+scale ile sahneye yerleştirilir.
///
/// Kamera pan'i artık TÜM sahneyi birlikte sürüklemez: her katman derinliğine
/// göre farklı hızda kayar (gökyüzü neredeyse sabit, ön plan otları en hızlı)
/// → düz bir resmin kayması yerine gerçek derinlik. Zoom sahne geneline uygulanır.
class _CutscenePainter extends CustomPainter {
  final CutsceneShot shot;
  final double time;
  final double shotElapsed;
  final double fade; // 0→1 karartmadan açılma
  final double fadeDepth; // karartmanın en koyu değeri (mekân değişimi = 1.0)
  final double moveElapsed; // fade bittikten sonra geçen süre (aktör hareketi)
  final double moveDur; // en uzak aktörün yürüyüş süresi
  final double camT; // 0→1 kamera ilerlemesi (state çekim süresine bağlar)
  final String? speaker; // o an konuşan aktörün adı (null = anlatı sesi)
  final double introT; // 0→1 letterbox bantlarının inişi (sinematik başı)
  /// Ekranın altında diyalog kutusu + letterbox'ın yediği yükseklik (px).
  /// Kadraj özneyi bu bandın ÜSTÜNDE tutar.
  final double reservedBottom;
  final bool ignited; // tapToIgnite: ateş yandı mı (yanmadan glow çizilmez)
  final double igniteElapsed; // yandıktan sonra geçen süre (flash); <0 = yok
  _CutscenePainter({
    required this.shot,
    required this.time,
    required this.shotElapsed,
    required this.fade,
    required this.fadeDepth,
    required this.moveElapsed,
    required this.moveDur,
    required this.camT,
    required this.speaker,
    required this.introT,
    required this.reservedBottom,
    this.ignited = true,
    this.igniteElapsed = -1.0,
  });

  // ── Katman derinlikleri (pan çarpanı) ──────────────────────────────────────
  static const double _dSky = 0.10; // gök + güneş + bulut
  static const double _dFar = 0.32; // uzak tepeler
  static const double _dNear = 0.58; // yakın tepeler
  static const double _dGround = 0.85; // zemin + AKTÖRLER (aynı düzlem şart)
  static const double _dFore = 1.35; // ön plan otları

  double _lerp(double a, double b, double t) => a + (b - a) * t;
  double _ease(double t) => t * t * (3 - 2 * t);

  /// Yürüyüş yol profili — trapez hız (kısa hızlanma → SABİT tempo → yavaşlayıp
  /// durma). Baştan sona smoothstep verilirse aktör tüm yolu ivmelenerek gider;
  /// yolun ortasında bile hızı değişir ve kafile "sürüklenen resim" gibi durur.
  double _travel(double t) {
    if (t <= 0) return 0;
    if (t >= 1) return 1;
    const a = 0.14; // hızlanma payı
    const b = 0.80; // yavaşlamanın başladığı yer
    const total = 1 - a / 2 - (1 - b) / 2;
    double area;
    if (t <= a) {
      area = t * t / (2 * a);
    } else if (t <= b) {
      area = a / 2 + (t - a);
    } else {
      final u = t - b;
      area = a / 2 + (b - a) + (u - u * u / (2 * (1 - b)));
    }
    return (area / total).clamp(0.0, 1.0);
  }

  /// Deterministik gürültü. Eski `(i * 73) % 100` deseni yıldızları ve közleri
  /// çapraz sıralara diziyordu (kafes görünüyordu) — bu düzensiz dağıtır.
  double _h(int i, int salt) {
    final x = sin(i * 127.1 + salt * 311.7) * 43758.5453;
    return x - x.floorToDouble();
  }

  /// Sahnenin anahtar ışığı — kaynağın ekrandaki yatay yeri (0..1), kaynağa
  /// dönük yana vurulan sıcaklık ve gövdenin tamamına inen ortam gölgesi.
  /// null = ışıklandırma yok (başlık kartı).
  ({double keyX, Color warm, Color ambient})? get _keyLight =>
      switch (shot.bg) {
        // Şafak: güneş sağda, ışık yumuşak şeftali; ortam hafif serin.
        CutsceneBg.valleyDawn => (
          keyX: 0.72,
          warm: const Color(0x4DFFD9A8),
          ambient: const Color(0x1F1A2440),
        ),
        // Gündüz yol: tepeden dolgun ışık, ortam neredeyse yok.
        CutsceneBg.road => (
          keyX: 0.62,
          warm: const Color(0x2EFFF3D0),
          ambient: const Color(0x14161E2E),
        ),
        // Akşam: güneş arkada kaldığı için gövde silüete YAKLAŞIR — yalnız
        // güneşe dönük kenar turuncu yanar (kontra ışık). Sıcaklık gölgeden
        // güçlü olursa figür sahneden parlak çıkar, akşam hissi kaçar.
        CutsceneBg.valleyDusk => (
          keyX: 0.50,
          warm: const Color(0x4DFF9A50),
          ambient: const Color(0x66141A33),
        ),
        // Gece ateşi: tek kaynak ortadaki ateş, ortam lacivert.
        CutsceneBg.fireNight => (
          keyX: 0.50,
          warm: const Color(0x8CFFAE55),
          ambient: const Color(0x59101C34),
        ),
        CutsceneBg.titleCard => null,
      };

  /// Ortak rüzgâr sinyali — ağaç/ot/duman aynı esintiden beslenir (kopuk kopuk
  /// sallanan öğeler yerine tek bir hava).
  double get _wind => sin(time * 0.55) + 0.45 * sin(time * 1.31);

  /// Katmanı KENDİ derinliğinde çizer: yatay/dikey kayma derinlikle orantılı,
  /// büyütme de öyle. Zoom'u tek parça uygulamak "resim büyüyor" hissi verir;
  /// katman katman uygulamak (dolly) "sahneye giriyoruz" der.
  void _layer(Canvas c, Size size, _Cam cam, double depth, VoidCallback draw) {
    c.save();
    final z = 1 + (cam.zoom - 1) * (depth / _dGround);
    c.translate(size.width / 2, size.height / 2);
    c.scale(z);
    c.translate(-size.width / 2, -size.height / 2);
    c.translate(-cam.panX * depth, -cam.panY * depth);
    draw();
    c.restore();
  }

  /// Kameranın bu karedeki hâli — pan/tilt/zoom + kadraj kaydırması.
  _Cam _camera(Size size) {
    final panX = _lerp(shot.panFrom, shot.panTo, camT) * size.width;
    final tilt = _lerp(shot.tiltFrom, shot.tiltTo, camT) * size.height;
    final zoom =
        _lerp(shot.zoomFrom, shot.zoomTo, camT) *
        (shot.framing == CutsceneFraming.close ? 1.16 : 1.0);
    var camX = panX, camY = tilt + _framingLift(size);
    if (shot.pov) {
      // Öznel kamera nefes alır. Sabit duran kadraj "kamera" olur; hafifçe
      // salınan kadraj "birinin gözü". Genlik kasten çok küçük (%0.5) —
      // fazlası mide bulandırır.
      camY +=
          sin(time * 0.85) * size.height * 0.005 +
          sin(time * 0.31) * size.height * 0.003;
      camX += sin(time * 0.57 + 1.3) * size.width * 0.004;
    }
    return _Cam(camX, camY, zoom);
  }

  /// Kadraj kaydırması — özneyi diyalog kutusunun üstüne çeker.
  ///
  /// Kutu + letterbox ekranın altından ~çeyreğini yiyor; aktör oraya denk
  /// gelince ayak basma noktası kayboluyor ve figür havada asılı duruyordu.
  /// Kaydırma AKTÖR düzleminde (\_dGround) ölçülür, katmanlara oradan yayılır.
  double _framingLift(Size size) {
    if (shot.actors.isEmpty || shot.framing == CutsceneFraming.wide) return 0;
    double baseY = 0, tallest = 0;
    for (final a in shot.actors) {
      if (a.y > baseY) baseY = a.y;
      final h = size.height * 0.30 * a.scale;
      if (h > tallest) tallest = h;
    }
    final feet = baseY * size.height;
    final barH = size.height * 0.10;
    final safeBottom = size.height - max(reservedBottom, barH) - 8;
    // Yakın planda ayak zaten kadraj dışı: bel hizası korunur.
    final anchor = shot.framing == CutsceneFraming.close
        ? feet - tallest * 0.45
        : feet;
    final over = anchor - safeBottom;
    return over > 0 ? over / _dGround : 0;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Kamera: pan/tilt/zoom çekim boyunca KASITLI ilerler ve sonunda oturur
    // (sonsuz drift yok). camT state'te shotEnd'e göre normalize edilir.
    // Zoom ve kaydırma artık KATMAN KATMAN uygulanır (bkz. _layer).
    final cam = _camera(size);

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    _paintBackground(canvas, size, cam);
    _paintActors(canvas, size, cam);
    _paintForeground(canvas, size, cam);

    canvas.restore();

    // Köşe kararması — dikkat sahnenin ortasında toplanır.
    _vignette(canvas, size);

    // Sinematik letterbox bantları — sinematiğin başında iner (anlık siyah
    // çubuk yerine perde açılışı).
    final barH = size.height * 0.10 * _ease(introT);
    if (barH > 0.5) {
      final barPaint = Paint()..color = const Color(0xFF000000);
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, barH), barPaint);
      canvas.drawRect(
        Rect.fromLTWH(0, size.height - barH, size.width, barH),
        barPaint,
      );
    }

    // Çekim başı geçişi. POV'da bu bir KARARMA değil GÖZ KAPAĞI: iki bant
    // yukarıdan ve aşağıdan kapanır, sonra açılır. Kadrajın "birinin gözü"
    // olduğunu tek başına söyleyen en güçlü sinyal bu.
    if (fade < 1.0) {
      if (shot.pov) {
        _eyelids(canvas, size, fade);
      } else {
        canvas.drawRect(
          Offset.zero & size,
          Paint()..color = Color.fromRGBO(0, 0, 0, (1.0 - fade) * fadeDepth),
        );
      }
    }
  }

  // ── Arka planlar (prosedürel) ──────────────────────────────────────────────
  void _paintBackground(Canvas canvas, Size size, _Cam cam) {
    switch (shot.bg) {
      case CutsceneBg.valleyDawn:
        _layer(canvas, size, cam, _dSky, () {
          _sky(canvas, size, const [
            Color(0xFF8FA8C4),
            Color(0xFFE8B892),
            Color(0xFFF6C79E),
            Color(0xFFF9DDBE),
            Color(0xFFFBEFD6),
          ]);
          _sun(
            canvas,
            size,
            const Offset(0.72, 0.30),
            30,
            const Color(0xFFFFE6B0),
          );
          _sunShafts(
            canvas,
            size,
            const Offset(0.72, 0.30),
            const Color(0xFFFFE7BC),
          );
          _clouds(canvas, size, const Color(0x66FFF0DC), n: 5, speed: 4.0);
        });
        _layer(canvas, size, cam, _dFar, () {
          _hills(canvas, size, 0.62, const Color(0xFFB69FB0), 3, 0.05);
          _treeLine(
            canvas,
            size,
            0.62,
            0.05,
            3,
            const Color(0xFFA48FA0),
            n: 16,
            scale: 0.75,
            salt: 1,
          );
          _haze(canvas, size, 0.655, const Color(0x59FFE3C8));
        });
        _layer(canvas, size, cam, _dNear, () {
          _hills(canvas, size, 0.70, const Color(0xFF8FA07E), 5, 0.10);
          _treeLine(
            canvas,
            size,
            0.70,
            0.10,
            5,
            const Color(0xFF6E7F60),
            n: 20,
            salt: 2,
          );
        });
        _layer(canvas, size, cam, _dGround, () {
          _ground(canvas, size, 0.78, const Color(0xFF6E7E54));
          _mist(canvas, size, 0.775, const Color(0xFFFFF2DE));
        });
      case CutsceneBg.road:
        _layer(canvas, size, cam, _dSky, () {
          _sky(canvas, size, const [
            Color(0xFF8CC6E8),
            Color(0xFFAFD8EE),
            Color(0xFFCDE9F6),
            Color(0xFFEAF6FF),
          ]);
          _clouds(canvas, size, const Color(0x88FFFFFF), n: 6, speed: 5.5);
        });
        _layer(canvas, size, cam, _dFar, () {
          _hills(canvas, size, 0.62, const Color(0xFFB6CFA8), 3, 0.05);
          _haze(canvas, size, 0.655, const Color(0x4CFFFFFF));
        });
        _layer(canvas, size, cam, _dNear, () {
          _hills(canvas, size, 0.66, const Color(0xFF9FC089), 4, 0.06);
          _treeLine(
            canvas,
            size,
            0.66,
            0.06,
            4,
            const Color(0xFF6F9457),
            n: 22,
            salt: 3,
          );
        });
        _layer(canvas, size, cam, _dGround, () {
          _ground(canvas, size, 0.80, const Color(0xFF7C9A55));
          _path(canvas, size);
        });
      case CutsceneBg.valleyDusk:
        _layer(canvas, size, cam, _dSky, () {
          _sky(canvas, size, const [
            Color(0xFF241A3E),
            Color(0xFF4A3A66),
            Color(0xFF9A5E72),
            Color(0xFFD87B57),
            Color(0xFFE8915A),
          ]);
          _sun(
            canvas,
            size,
            const Offset(0.5, 0.52),
            36,
            const Color(0xFFFFCB6E),
          );
          _clouds(canvas, size, const Color(0x59FFB98A), n: 4, speed: 3.0);
          _birds(canvas, size);
        });
        _layer(canvas, size, cam, _dFar, () {
          _hills(canvas, size, 0.64, const Color(0xFF5A4566), 3, 0.05);
          _haze(canvas, size, 0.66, const Color(0x59E8915A));
        });
        _layer(canvas, size, cam, _dNear, () {
          _hills(canvas, size, 0.72, const Color(0xFF3A3048), 5, 0.10);
          _treeLine(
            canvas,
            size,
            0.72,
            0.10,
            5,
            const Color(0xFF2A2338),
            n: 20,
            salt: 4,
          );
        });
        _layer(
          canvas,
          size,
          cam,
          _dGround,
          () => _ground(canvas, size, 0.80, const Color(0xFF2C2436)),
        );
      case CutsceneBg.fireNight:
        _layer(canvas, size, cam, _dSky, () {
          _sky(canvas, size, const [
            Color(0xFF060B22),
            Color(0xFF0A1330),
            Color(0xFF142244),
            Color(0xFF1E3052),
          ]);
          _stars(canvas, size);
        });
        _layer(
          canvas,
          size,
          cam,
          _dFar,
          () => _hills(canvas, size, 0.60, const Color(0xFF0C1528), 3, 0.05),
        );
        _layer(canvas, size, cam, _dNear, () {
          _hills(canvas, size, 0.66, const Color(0xFF0E1A30), 4, 0.06);
          _treeLine(
            canvas,
            size,
            0.66,
            0.06,
            4,
            const Color(0xFF0A1424),
            n: 18,
            salt: 5,
          );
        });
        _layer(canvas, size, cam, _dGround, () {
          _ground(canvas, size, 0.80, const Color(0xFF0A1322));
          // Odun yığını her zaman; ateş+hâle yanma seviyesine göre.
          _logs(
            canvas,
            Offset(size.width * 0.5, size.height * 0.80),
            size.height * 0.10,
          );
          // Yanma seviyesi: gate (dokun) ise yanınca ramp; gate yoksa oto-bloom.
          final double fireLevel;
          if (shot.gate == CutsceneGate.tapToIgnite) {
            fireLevel = ignited ? (igniteElapsed / 0.6).clamp(0.0, 1.0) : 0.0;
          } else {
            fireLevel = (shotElapsed / 1.3).clamp(0.0, 1.0);
          }
          if (fireLevel > 0.02) {
            final c = Offset(size.width * 0.5, size.height * 0.80);
            // Zemine düşen sıcak ışık havuzu — ateşin gerçekten YERDE yandığını
            // söyleyen şey bu (yoksa hâle havada asılı duruyor).
            final pool = Rect.fromCenter(
              center: c.translate(0, size.height * 0.012),
              width: size.width * 0.62 * (0.6 + 0.4 * fireLevel),
              height: size.height * 0.10 * (0.6 + 0.4 * fireLevel),
            );
            canvas.drawOval(
              pool,
              Paint()
                ..shader = RadialGradient(
                  colors: [
                    Color.fromRGBO(255, 160, 70, 0.34 * fireLevel),
                    const Color.fromRGBO(255, 120, 50, 0.0),
                  ],
                ).createShader(pool),
            );
            _fireGlow(canvas, size, const Offset(0.5, 0.80), fireLevel);
            _flames(canvas, size, c, fireLevel);
            _fireEmbers(canvas, size, const Offset(0.5, 0.80), fireLevel);
          }
        });
      case CutsceneBg.titleCard:
        canvas.drawRect(
          Offset.zero & size,
          Paint()..color = const Color(0xFF0C0A07),
        );
        // Hafif radyal vinyet ışığı + uçuşan közler.
        final c = Offset(size.width * 0.5, size.height * 0.52);
        canvas.drawCircle(
          c,
          size.width * 0.4,
          Paint()
            ..shader =
                RadialGradient(
                  colors: [
                    AppUi.accent.withValues(alpha: 0.10),
                    const Color(0x00000000),
                  ],
                ).createShader(
                  Rect.fromCircle(center: c, radius: size.width * 0.4),
                ),
        );
        _embers(canvas, size);
    }
  }

  // ── POV (köyün ortak gözü) ─────────────────────────────────────────────────

  /// Göz kapağı geçişi — [open] 0 kapalı, 1 tam açık. Bantlar düz değil hafif
  /// kavisli (kapak kirpik hattı gibi kapanır).
  void _eyelids(Canvas canvas, Size size, double open) {
    final e = _ease(open.clamp(0.0, 1.0));
    final lid = size.height * 0.52 * (1 - e);
    if (lid <= 0.5) return;
    final black = Paint()..color = const Color(0xFF000000);
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, lid)
        ..quadraticBezierTo(size.width * 0.5, lid + size.height * 0.05, 0, lid)
        ..close(),
      black,
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height)
        ..lineTo(size.width, size.height)
        ..lineTo(size.width, size.height - lid)
        ..quadraticBezierTo(
          size.width * 0.5,
          size.height - lid - size.height * 0.04,
          0,
          size.height - lid,
        )
        ..close(),
      black,
    );
  }

  /// Kadrajın iki yanındaki komşular — halkanın içinde durduğumuzu söyleyen
  /// koyu omuz/baş silüetleri. Nefesle hafifçe kıpırdar; gece sahnesinde iç
  /// kenarları ateşten sıcak bir kontur alır (el sprite'ı yok, gerek de yok).
  void _neighbors(Canvas canvas, Size size) {
    final warm = shot.bg == CutsceneBg.fireNight;
    for (int side = 0; side < 2; side++) {
      final left = side == 0;
      // Kameraya çok yakın duran biri kadrajın YARISINA yakınını kaplar. Küçük
      // çizilirse "uzakta duran ufak adam" olur, omuz hissi kaybolur.
      final r = size.width * (0.105 + _h(side, 61) * 0.020);
      final bob = sin(time * 0.7 + side * 2.1) * size.height * 0.007;
      final headY = size.height * (0.48 + _h(side, 62) * 0.07) + bob;
      final cx = left ? -size.width * 0.05 : size.width * 1.05;
      final head = Offset(cx, headY);
      final shoulders = Rect.fromCenter(
        center: Offset(cx, headY + r * 1.75),
        width: r * 4.4,
        height: r * 3.4,
      );

      // Kameraya yakın olan odak dışıdır: gövdenin çevresine yumuşak bir hâle
      // koyarak "net değil" hissi verilir (gerçek blur her karede pahalı).
      final halo = Paint()..color = const Color(0x59070A10);
      canvas.drawCircle(head, r * 1.10, halo);
      canvas.drawOval(shoulders.inflate(r * 0.12), halo);

      final body = Paint()..color = const Color(0xF5070A10);
      canvas.drawOval(shoulders, body);
      canvas.drawCircle(head, r, body);

      // Ateş sahnesinde iç kenar közden kontur alır — silüet düz karaltı
      // olmaktan çıkıp ışığın içinde duran bir insana döner.
      if (warm) {
        final rim = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..color = const Color(0x66FFA352);
        canvas.save();
        // Yalnız kadrajın içine bakan yarısı aydınlanır.
        canvas.clipRect(
          left
              ? Rect.fromLTWH(cx, 0, size.width, size.height)
              : Rect.fromLTWH(0, 0, cx, size.height),
        );
        canvas.drawCircle(head, r, rim);
        canvas.drawOval(shoulders, rim);
        canvas.restore();
      }
    }
  }

  /// En yakın katman — ekranın alt kenarında rüzgârda sallanan otlar. Asıl işi
  /// derinlik: pan'de en hızlı kayan şey bu olduğu için kamera hareketi
  /// "resim kaydı" değil "sahneye giriyoruz" hissi verir.
  void _paintForeground(Canvas canvas, Size size, _Cam cam) {
    final col = switch (shot.bg) {
      CutsceneBg.valleyDawn => const Color(0xFF3F4A2E),
      CutsceneBg.road => const Color(0xFF48632C),
      CutsceneBg.valleyDusk => const Color(0xFF171326),
      CutsceneBg.fireNight => const Color(0xFF060C16),
      CutsceneBg.titleCard => null,
    };
    // POV: kamera halkanın İÇİNDE duruyor → kadrajın iki yanında komşuların
    // omuzları. Köyün ortak gözü olduğumuzu söyleyen şey bu (ot değil).
    if (shot.pov) {
      _layer(canvas, size, cam, _dFore, () => _neighbors(canvas, size));
      return;
    }
    if (col == null) return;
    _layer(canvas, size, cam, _dFore, () => _grassBand(canvas, size, col));
  }

  void _vignette(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    canvas.drawRect(
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment.center,
          radius: 0.85,
          colors: [Color(0x00000000), Color(0x59000000)],
          stops: [0.55, 1.0],
        ).createShader(r),
    );
  }

  void _sky(Canvas canvas, Size size, List<Color> colors) {
    // Gök dikey taşar (tilt/kadraj kaydırınca kenarda boşluk kalmasın) ama
    // GRADYAN ekran ölçüsüne göre haritalanır — yoksa ufuk rengi kadraj dışına
    // kayar ve her sahnenin tonu değişir. Taşan kısım kenar rengiyle dolar.
    final grad = Rect.fromLTWH(0, 0, size.width, size.height);
    final r = Rect.fromLTWH(
      -size.width * 0.2,
      -size.height * 0.35,
      size.width * 1.4,
      size.height * 1.7,
    );
    canvas.drawRect(
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ).createShader(grad),
    );
  }

  void _sun(Canvas canvas, Size size, Offset norm, double r, Color col) {
    final c = Offset(norm.dx * size.width, norm.dy * size.height);
    // Nefes alan hâle — sabit disk yerine hafifçe soluyan ışık.
    final breath = 1.0 + 0.04 * sin(time * 0.5);
    canvas.drawCircle(
      c,
      r * 3.0 * breath,
      Paint()
        ..shader = RadialGradient(
          colors: [
            col.withValues(alpha: 0.42),
            col.withValues(alpha: 0.12),
            col.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r * 3.0 * breath)),
    );
    canvas.drawCircle(c, r, Paint()..color = col);
  }

  /// Güneşten inen yumuşak huzmeler — şafak sahnesinin nefesi (menü şafağıyla
  /// aynı dil). Abartısız: alfa düşük, açılar yavaş salınır.
  void _sunShafts(Canvas canvas, Size size, Offset norm, Color col) {
    final o = Offset(norm.dx * size.width, norm.dy * size.height);
    canvas.save();
    canvas.translate(o.dx, o.dy);
    for (int i = 0; i < 5; i++) {
      final ang = 1.95 + i * 0.17 + sin(time * 0.23 + i) * 0.015;
      final w = size.height * (0.055 + _h(i, 21) * 0.055);
      final len = size.height * 1.25;
      final a =
          (0.10 + _h(i, 22) * 0.07) * (0.7 + 0.3 * sin(time * 0.4 + i * 1.3));
      canvas.save();
      canvas.rotate(ang);
      final r = Rect.fromLTWH(0, -w / 2, len, w);
      canvas.drawRect(
        r,
        Paint()
          ..shader = LinearGradient(
            colors: [
              col.withValues(alpha: a),
              col.withValues(alpha: 0.0),
            ],
          ).createShader(r),
      );
      canvas.restore();
    }
    canvas.restore();
  }

  /// Sürüklenen bulutlar — yumuşak radyal blob'lar (MaskFilter yerine shader:
  /// tam ekran blur her karede pahalı).
  void _clouds(
    Canvas canvas,
    Size size,
    Color col, {
    int n = 5,
    double speed = 5.0,
  }) {
    for (int i = 0; i < n; i++) {
      final w = size.width * (0.22 + _h(i, 3) * 0.22);
      final hgt = w * (0.16 + _h(i, 4) * 0.09);
      final span = size.width * 1.6 + w * 2;
      final x =
          ((_h(i, 5) * span + time * speed * (0.5 + _h(i, 6))) % span) -
          w -
          size.width * 0.3;
      final y = size.height * (0.06 + _h(i, 7) * 0.26);
      for (int k = 0; k < 2; k++) {
        final rr = Rect.fromLTWH(
          x + w * 0.16 * k,
          y - hgt * 0.22 * k,
          w * (1 - 0.22 * k),
          hgt * (1 - 0.18 * k),
        );
        canvas.drawOval(
          rr,
          Paint()
            ..shader = RadialGradient(
              colors: [col, col.withValues(alpha: 0.0)],
              stops: const [0.35, 1.0],
            ).createShader(rr),
        );
      }
    }
  }

  /// Ufuk pusu — tepe eteğinde ince ışık bandı; katmanları birbirinden ayırır.
  void _haze(Canvas canvas, Size size, double y, Color col) {
    final r = Rect.fromLTWH(
      -size.width * 0.2,
      y * size.height - size.height * 0.06,
      size.width * 1.4,
      size.height * 0.12,
    );
    canvas.drawRect(
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [col.withValues(alpha: 0.0), col, col.withValues(alpha: 0.0)],
        ).createShader(r),
    );
  }

  /// Zemin sisi — yavaşça sürüklenen alçak tüller (şafak/uyanış hissi).
  void _mist(Canvas canvas, Size size, double y, Color col) {
    for (int i = 0; i < 6; i++) {
      final w = size.width * (0.30 + _h(i, 31) * 0.35);
      final hgt = size.height * (0.030 + _h(i, 32) * 0.030);
      final span = size.width * 1.5 + w * 2;
      final x =
          ((_h(i, 33) * span + time * (2.5 + _h(i, 34) * 3.5)) % span) -
          w -
          size.width * 0.25;
      final yy = y * size.height + size.height * (_h(i, 35) * 0.05 - 0.055);
      final rr = Rect.fromLTWH(x, yy, w, hgt);
      canvas.drawOval(
        rr,
        Paint()
          ..shader = RadialGradient(
            colors: [
              col.withValues(alpha: 0.20 + _h(i, 36) * 0.16),
              col.withValues(alpha: 0.0),
            ],
            stops: const [0.30, 1.0],
          ).createShader(rr),
      );
    }
  }

  /// Akşam gökyüzünde süzülen kuş sürüsü — kanat çırpışı zamana bağlı.
  void _birds(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x66000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final span = size.width * 1.6;
    for (int i = 0; i < 7; i++) {
      final x =
          ((_h(i, 41) * span + time * (6 + _h(i, 42) * 5)) % span) -
          size.width * 0.3;
      final y =
          size.height * (0.14 + _h(i, 43) * 0.16) + sin(time * 0.8 + i) * 3;
      final s = 4.0 + _h(i, 44) * 3.0;
      final flap = 0.35 + 0.65 * (0.5 + 0.5 * sin(time * 5.5 + i * 1.7));
      canvas.drawPath(
        Path()
          ..moveTo(x - s, y)
          ..quadraticBezierTo(x - s * 0.45, y - s * flap, x, y)
          ..quadraticBezierTo(x + s * 0.45, y - s * flap, x + s, y),
        paint,
      );
    }
  }

  /// Tepe silüeti — birkaç sinüs tümseği, [baseY] normalize, [bumps] tümsek.
  /// Pan'de kenar açılmasın diye ekranın iki yanına taşarak çizilir.
  void _hills(
    Canvas canvas,
    Size size,
    double baseY,
    Color col,
    int bumps,
    double amp,
  ) {
    final ov = size.width * 0.22;
    // Dikey taşma: kadraj/tilt sahneyi yukarı çektiğinde alt kenarda boşluk
    // açılmasın diye tepe eteği ekranın altına taşar.
    final bottom = size.height * 1.6;
    final path = Path()..moveTo(-ov, bottom);
    final y0 = baseY * size.height;
    final a = amp * size.height;
    path.lineTo(-ov, y0);
    const steps = 64;
    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final x = -ov + (size.width + ov * 2) * t;
      final rt = x / size.width;
      final y = y0 - a * (0.5 + 0.5 * sin(rt * pi * bumps + baseY * 10));
      path.lineTo(x, y);
    }
    path.lineTo(size.width + ov, bottom);
    path.close();
    // Düz tek renk dolgu tepeyi "kesilmiş karton" yapıyordu: sırt çizgisi ışık
    // alır, etek dibi koyulaşır → hacim.
    final r = Rect.fromLTWH(
      -ov,
      y0 - a,
      size.width + ov * 2,
      size.height - (y0 - a),
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(col, const Color(0xFFFFFFFF), 0.10)!,
            col,
            Color.lerp(col, const Color(0xFF000000), 0.22)!,
          ],
          stops: const [0.0, 0.28, 1.0],
        ).createShader(r),
    );
  }

  /// Sırt çizgisine ağaç silüetleri — düz sinüs tepesi "boyalı karton" gibi
  /// duruyordu; ağaçlar hem siluet kırar hem rüzgârda hafifçe eğilir.
  void _treeLine(
    Canvas canvas,
    Size size,
    double baseY,
    double amp,
    int bumps,
    Color col, {
    int n = 20,
    double scale = 1.0,
    int salt = 0,
  }) {
    final ov = size.width * 0.22;
    final y0 = baseY * size.height;
    final a = amp * size.height;
    for (int i = 0; i < n; i++) {
      final x = -ov + (size.width + ov * 2) * _h(i, salt * 10 + 1);
      final rt = x / size.width;
      final y = y0 - a * (0.5 + 0.5 * sin(rt * pi * bumps + baseY * 10)) + 1;
      final hgt = size.height * (0.020 + _h(i, salt * 10 + 2) * 0.024) * scale;
      final sway = _wind * hgt * 0.045 * (0.5 + _h(i, salt * 10 + 3));
      canvas.drawPath(
        Path()
          ..moveTo(x - hgt * 0.26, y)
          ..lineTo(x + sway, y - hgt)
          ..lineTo(x + hgt * 0.26, y)
          ..close(),
        Paint()..color = col,
      );
    }
  }

  /// Ön plan ot bandı — ekranın alt kenarında rüzgârda sallanan bıçaklar.
  void _grassBand(Canvas canvas, Size size, Color col) {
    final baseY = size.height * 1.02;
    final ov = size.width * 0.3;
    final paint = Paint()
      ..color = col
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 64; i++) {
      final x = -ov + (size.width + ov * 2) * _h(i, 11);
      final hgt = size.height * (0.10 + _h(i, 12) * 0.15);
      final sw =
          (_wind * 0.6 + sin(time * 0.9 + i * 0.6) * 0.5) *
          hgt *
          0.18 *
          (0.5 + _h(i, 13));
      paint.strokeWidth = 2.0 + _h(i, 14) * 2.2;
      canvas.drawPath(
        Path()
          ..moveTo(x, baseY)
          ..quadraticBezierTo(
            x + sw * 0.35,
            baseY - hgt * 0.55,
            x + sw,
            baseY - hgt,
          ),
        paint,
      );
    }
  }

  void _ground(Canvas canvas, Size size, double topY, Color col) {
    canvas.drawRect(
      Rect.fromLTWH(
        -size.width * 0.22,
        topY * size.height,
        size.width * 1.44,
        size.height * (1.6 - topY),
      ),
      Paint()..color = col,
    );
  }

  void _path(Canvas canvas, Size size) {
    final top = size.height * 0.80;
    final p = Path()
      ..moveTo(size.width * 0.46, top)
      ..lineTo(size.width * 0.54, top)
      ..lineTo(size.width * 0.72, size.height)
      ..lineTo(size.width * 0.28, size.height)
      ..close();
    canvas.drawPath(p, Paint()..color = const Color(0xFFCBB07A));
    // Yol kenarı çakıl/ot tutamları — düz sarı üçgen "yol" gibi durmasın.
    final tuft = Paint()..color = const Color(0xFF6E8C4A);
    for (int i = 0; i < 14; i++) {
      final t = _h(i, 51);
      final y = top + (size.height - top) * t;
      final halfW = size.width * (0.04 + 0.18 * t);
      final side = i.isEven ? -1.0 : 1.0;
      final x = size.width * 0.5 + side * (halfW + size.width * 0.01);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, y),
          width: size.width * (0.012 + _h(i, 52) * 0.016),
          height: size.height * 0.008,
        ),
        tuft,
      );
    }
  }

  void _stars(Canvas canvas, Size size) {
    final paint = Paint();
    for (int i = 0; i < 70; i++) {
      final x = _h(i, 61) * size.width * 1.4 - size.width * 0.2;
      final y = _h(i, 62) * size.height * 0.60;
      final tw = 0.35 + 0.65 * (0.5 + 0.5 * sin(time * 1.6 + _h(i, 63) * 6.3));
      final r = 0.7 + _h(i, 64) * 0.9;
      paint.color = Color.fromRGBO(255, 255, 255, tw * 0.75);
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  /// Yakılmamış odun yığını — ateş yanmadan önce görünür (dokun ipucu hedefi).
  void _logs(Canvas canvas, Offset base, double s) {
    final wood = Paint()..color = const Color(0xFF3A2412);
    canvas.save();
    canvas.translate(base.dx, base.dy);
    for (final a in [-0.5, 0.0, 0.5]) {
      canvas.save();
      canvas.rotate(a);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: s * 1.4,
            height: s * 0.22,
          ),
          const Radius.circular(2),
        ),
        wood,
      );
      canvas.restore();
    }
    canvas.restore();
  }

  /// [level] 0..1 — yanma şiddeti (oto-bloom / dokunma rampası). Boyut+alfa ölçer.
  void _fireGlow(Canvas canvas, Size size, Offset norm, [double level = 1.0]) {
    final c = Offset(norm.dx * size.width, norm.dy * size.height);
    final flick = 0.85 + 0.15 * sin(time * 9) + 0.08 * sin(time * 17);
    final r = size.width * 0.30 * flick * (0.45 + 0.55 * level);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFB24D).withValues(alpha: 0.55 * flick * level),
            const Color(0xFFE9742E).withValues(alpha: 0.18 * level),
            const Color(0x00000000),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    // Köz çekirdeği.
    canvas.drawCircle(
      c,
      7 * flick * level,
      Paint()..color = const Color(0xFFFFD27A),
    );
  }

  /// Alev dilleri. Eskiden "ateş" yalnız radyal bir hâle + 7 px köz çekirdeği
  /// idi: hem ateşe benzemiyordu hem de diyalog kutusu önüne gelince gece
  /// sahnesinin BAŞROLÜ tamamen kayboluyordu. Diller kutunun üstüne çıkar.
  void _flames(Canvas canvas, Size size, Offset c, double level) {
    final h0 = size.height * 0.26 * level;
    final w0 = size.width * 0.055;
    for (int i = 0; i < 5; i++) {
      final sp = time * (2.6 + i * 0.7) + i * 1.9;
      final lean = sin(sp) * w0 * 0.30 + _wind * w0 * 0.08;
      final hgt =
          h0 * (0.55 + 0.45 * (0.5 + 0.5 * sin(sp * 1.3))) * (1 - i * 0.10);
      final wid = w0 * (1.0 - i * 0.14) * (0.85 + 0.15 * sin(sp * 0.9));
      final r = Rect.fromLTRB(c.dx - wid, c.dy - hgt, c.dx + wid, c.dy);
      canvas.drawPath(
        Path()
          ..moveTo(c.dx - wid, c.dy)
          ..quadraticBezierTo(
            c.dx - wid * 0.9,
            c.dy - hgt * 0.55,
            c.dx + lean,
            c.dy - hgt,
          )
          ..quadraticBezierTo(
            c.dx + wid * 0.9,
            c.dy - hgt * 0.55,
            c.dx + wid,
            c.dy,
          )
          ..close(),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Color.fromRGBO(255, 228, 158, 0.92 * level),
              Color.fromRGBO(255, 150, 46, 0.72 * level),
              const Color(0x00C83C14),
            ],
            stops: const [0.0, 0.45, 1.0],
          ).createShader(r),
      );
    }
  }

  /// Ateşten yükselen közler — alev "duran bir hâle" olmaktan çıkar.
  void _fireEmbers(Canvas canvas, Size size, Offset norm, double level) {
    final c = Offset(norm.dx * size.width, norm.dy * size.height);
    final paint = Paint();
    for (int i = 0; i < 18; i++) {
      final life = (time * 0.42 + _h(i, 71)) % 1.0;
      final rise = size.height * 0.24 * life;
      final drift =
          sin(time * 1.1 + i * 1.7) * size.width * 0.030 * life +
          _wind * size.width * 0.012 * life;
      final x = c.dx + (_h(i, 72) - 0.5) * size.width * 0.10 + drift;
      final y = c.dy - rise - size.height * 0.01;
      final a = (1 - life) * (1 - life) * 0.85 * level;
      paint.color = Color.fromRGBO(255, 178, 77, a);
      canvas.drawCircle(Offset(x, y), 1.2 + _h(i, 73) * 1.4, paint);
    }
  }

  void _embers(Canvas canvas, Size size) {
    final paint = Paint();
    for (int i = 0; i < 26; i++) {
      final phase = (time * 0.25 + _h(i, 81)) % 1.0;
      final x = _h(i, 82) * size.width + sin(time * 0.8 + i) * 12;
      final y = size.height * (0.95 - phase * 0.7);
      final a = (1 - phase) * 0.6;
      paint.color = Color.fromRGBO(233, 138, 56, a);
      canvas.drawCircle(Offset(x, y), 1.6, paint);
    }
  }

  // ── Aktörler ────────────────────────────────────────────────────────────────
  void _paintActors(Canvas canvas, Size size, _Cam cam) {
    if (shot.actors.isEmpty) return;
    // Konuşan aktör sahnede mi (anlatı sesinde kimse kısılmaz).
    final hasSpeaker =
        speaker != null && shot.actors.any((a) => a.name == speaker);

    // Aktörler aynı SÜREDE değil aynı HIZDA yürür: mesafeler çok farklı
    // (kafilede biri 1.5 ekran, biri 0.4 ekran gidiyor). Ortak süre verilirse
    // yavaş olanın ayakları kayar ve herkes aynı anda varır (asker dizilişi).
    double maxDist = 0;
    for (final a in shot.actors) {
      final d = (a.toX - a.fromX).abs();
      if (d > maxDist) maxDist = d;
    }

    canvas.save();
    // Aktörler zeminle AYNI düzlemde (aynı derinlik) — yoksa yürürken zeminden
    // kayarlar.
    final z = 1 + (cam.zoom - 1) * 1.0;
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(z);
    canvas.translate(-size.width / 2, -size.height / 2);
    canvas.translate(-cam.panX * _dGround, -cam.panY * _dGround);
    for (int i = 0; i < shot.actors.length; i++) {
      final a = shot.actors[i];
      final dist = (a.toX - a.fromX).abs();
      final own = maxDist <= 1e-4 ? 0.0 : moveDur * (dist / maxDist);
      final p = own <= 1e-4 ? 1.0 : (moveElapsed / own).clamp(0.0, 1.0);
      final nx = _lerp(a.fromX, a.toX, _travel(p));
      final x = nx * size.width;
      final y = a.y * size.height;
      final targetH = size.height * 0.30 * a.scale;
      final s = targetH / 90.0;

      // Yürüyüş fazı KAT EDİLEN YOLDAN türetilir → adım boyu gövdeyle orantılı,
      // hız ne olursa olsun ayak kaymaz (eski hâli sabit `time * 8` idi).
      final travelled = (nx - a.fromX).abs() * size.width;
      final stride = targetH * 0.50; // bir adımda kat edilen yol
      final walkPhase = travelled / stride * pi;
      // Varıştan beri geçen süre. _Anim'in idle nefes/sway'i TAMAMEN faza bağlı;
      // varınca faz 0'da bırakılırsa aktör nefes bile almayan bir heykel olur.
      final settled = max(0.0, moveElapsed - own);
      final speaking = hasSpeaker && a.name == speaker;
      final phase =
          walkPhase +
          settled * (speaking ? 1.9 : 1.25) + // konuşan biraz daha canlı
          i * 1.7 +
          a.seed * 0.31; // herkes aynı anda nefes almasın
      // Yürüyüşten idle'a yumuşak geçiş (varışta poz sıçraması olmasın).
      final mi = a.walk ? (1.0 - settled / 0.5).clamp(0.0, 1.0) : 0.0;
      // Yürürken GİDİLEN yöne bakar (eski kod hep sağa baktırıyordu: soldan
      // gelen heyet geri geri yürümüş gibi görünüyordu), varınca kendi yönüne.
      final flip = (a.walk && p < 1.0) ? a.toX < a.fromX : a.flip;

      // Yumuşak zemin gölgesi — sert oval yerine kenarı dağılan temas gölgesi.
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, y + 2),
          width: targetH * 0.52,
          height: targetH * 0.13,
        ),
        Paint()
          ..color = const Color(0x3D000000)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, targetH * 0.035),
      );

      // Konuşmayan aktörler kısılır — üç aynı muhafız arasında komutanın
      // hangisi olduğu ancak böyle okunuyor (diyalog kutusu adı yazsa bile).
      final dim = hasSpeaker && !speaking;
      // Sahnenin ışığı aktöre de düşer. Düz aydınlatılan gövde her mekânda aynı
      // parlaklıkta kalıyordu: akşam sahnesinde de öğle sahnesindekiyle aynı →
      // arka plana yapıştırılmış çıkartma hissi.
      final key = _keyLight;
      final lit = key != null;
      final bounds = Rect.fromCenter(
        center: Offset(x, y - targetH * 0.5),
        width: targetH * 1.9,
        height: targetH * 1.8,
      );
      if (dim || lit) canvas.saveLayer(bounds, Paint());

      canvas.save();
      canvas.translate(x, y);
      canvas.scale(s, s);
      CharacterRenderer.draw(
        canvas,
        a.type,
        flipX: flip,
        walkPhase: phase,
        moveIntensity: mi,
        visual: a.visual ?? NpcVisual.fromSeed(a.seed),
        time: time,
        stage: LifeStage.adult,
      );
      canvas.restore();

      if (key != null) {
        // 1) Ortam gölgesi — gövdenin tamamı sahnenin saatine oturur.
        canvas.drawRect(
          bounds,
          Paint()
            ..blendMode = BlendMode.srcATop
            ..color = key.ambient,
        );
        // 2) Anahtar ışık — kaynağa dönük yan aydınlanır (kaynak sahnenin
        //    güneşi ya da ateşi; ekran uzayında solda mı sağda mı ona bakılır).
        final fromRight = x < key.keyX * size.width;
        canvas.drawRect(
          bounds,
          Paint()
            ..blendMode = BlendMode.srcATop
            ..shader = LinearGradient(
              begin: fromRight ? Alignment.centerRight : Alignment.centerLeft,
              end: fromRight ? Alignment.centerLeft : Alignment.centerRight,
              colors: [key.warm, key.warm.withValues(alpha: 0.0)],
              stops: const [0.0, 0.78],
            ).createShader(bounds),
        );
      }
      if (dim) {
        canvas.drawRect(
          bounds,
          Paint()
            ..blendMode = BlendMode.srcATop
            ..color = const Color(0x73070B16),
        );
      }
      if (dim || lit) canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CutscenePainter old) => true;
}
