import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../main.dart' show kCaptureMode;
import '../save/save_manager.dart';
import '../systems/audio_manager.dart';
import '../rendering/flame_renderer.dart';
import '../tools/light_editor_main.dart';
import '../tools/placement_editor_main.dart';
import 'about_screen.dart';
import 'app_ui.dart';
import 'mobile_ui.dart';
import 'save_slots_screen.dart';
import 'settings_screen.dart';
import 'sky_widgets.dart';
import '../dev/animation_room.dart';

/// Açılış ekranı — atmosferik ŞAFAK sahnesi (yeni köy = yeni başlangıç) +
/// zarif altın başlık + temiz koyu menü paneli. Ön planda karşılayıcı köylü
/// silüeti seni bekler. Diegetik-lite: sahne sıcaklığı verir, UI modern kalır.
class MainMenuScreen extends StatefulWidget {
  final VoidCallback onNewGame;
  final void Function(SaveSlotMeta) onContinue;

  /// İSTİSNAİ giriş — testlerin ortak zemini olan sabit "Referans Köy"ü kurar.
  /// Normal oyuncu akışının parçası değil; kasten menüde durur ki her testte
  /// aynı köyden başlanabilsin (bkz. scene_reference_village.dart).
  final VoidCallback onReferenceVillage;

  /// Önizleme/test seam'i: kayıt durumunu diske sormadan zorlar
  /// (true → "DEVAM ET"li hâl, false → tek kartlı ilk açılış).
  /// Oyunda hep null.
  static bool? debugSavesOverride;

  const MainMenuScreen({
    super.key,
    required this.onNewGame,
    required this.onContinue,
    required this.onReferenceVillage,
  });

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen>
    with SingleTickerProviderStateMixin {
  static const _legacyBackdrop = bool.fromEnvironment('LEGACY_MENU_BACKDROP');

  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _time = 0;
  bool _hasSaves = false;
  bool _slotsOpen = false;

  // Sahnedeki güneşin ekran-uzayı merkezi (ışınlar + hâle bundan türetilir).
  Offset _sunCenter(Size size) =>
      Offset(size.width * 0.72, size.height * 0.44 + 62);

  @override
  void initState() {
    super.initState();
    FlameRenderer.loadAll();
    // MENÜ MÜZİĞİ — şafak sahnesinin parçası. Ses motoru burada da ayağa
    // kaldırılır: menü oyundan önce gelir, oyuna hiç girmeyen oyuncu da
    // (ayarlar/kayıtlar) sessiz bir uygulama görmemeli. Dosya yoksa sessiz.
    if (!kCaptureMode) {
      AudioManager.instance.start();
      AudioManager.instance.playMusic(MusicTrack.menu);
    }
    _refreshHasSaves();
    _ticker = createTicker((elapsed) {
      final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.1);
      _last = elapsed;
      setState(() => _time += dt);
    })..start();
  }

  Future<void> _refreshHasSaves() async {
    final has =
        MainMenuScreen.debugSavesOverride ??
        await SaveManager.instance.hasAnySave();
    if (mounted) setState(() => _hasSaves = has);
  }

  /// Kayıtlı köyler artık AYRI SAYFA değil — şafak sahnesinin üstünde overlay
  /// pano (atmosfer kesilmesin, geri dönüş tek dokunuş/Esc).
  void _openSlots() => setState(() => _slotsOpen = true);

  void _closeSlots() {
    setState(() => _slotsOpen = false);
    _refreshHasSaves();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final touch = useTouchUi(context);

    return Scaffold(
      backgroundColor: const Color(0xFF78976D),
      body: Stack(
        children: [
          _MenuSpringBackground(
            touch: touch,
            wideMobile: touch && size.aspectRatio >= 1.72,
            time: _time,
          ),
          // ── Atmosfer (SABAH) ──────────────────────────────────────────────
          // Eski prosedürel sahne yalnız geliştirme karşılaştırması için
          // --dart-define=LEGACY_MENU_BACKDROP=true ile açılabilir.
          if (_legacyBackdrop) const _DawnSky(),
          // Uyanan kuşlar — yüksekte gevşek V, yavaş süzülür.
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _WakingBirdsPainter(time: _time)),
            ),
          ),
          // Yükselen güneş (tepelerin ardından doğar — horizon onu kısmen örter).
          if (_legacyBackdrop)
            Positioned(
              left: _sunCenter(size).dx - 66,
              top: _sunCenter(size).dy - 66,
              child: _SunWithGlow(time: _time),
            ),
          // Güneşten köye uzanan yumuşak sabah ışınları.
          if (_legacyBackdrop)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _LightRaysPainter(
                    time: _time,
                    sun: _sunCenter(size),
                  ),
                ),
              ),
            ),
          if (_legacyBackdrop)
            _DriftingClouds(time: _time, screenWidth: size.width),
          if (_legacyBackdrop)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: CustomPaint(
                size: Size(size.width, size.height * 0.46),
                painter: _HorizonPainter(time: _time),
              ),
            ),
          // Tepelerin eteğinde sürüklenen sabah sisi.
          if (_legacyBackdrop)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: CustomPaint(
                  size: Size(size.width, size.height * 0.42),
                  painter: _MorningMistPainter(time: _time),
                ),
              ),
            ),
          // Güneşe doğru yoğunlaşan alt sıcak parıltı (şafak altını).
          if (_legacyBackdrop)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Container(
                  height: size.height * 0.5,
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0.42, 1.0),
                      radius: 1.0,
                      colors: [Color(0x33FFC880), Color(0x00FFC880)],
                    ),
                  ),
                ),
              ),
            ),
          // Karşılayıcı köylü — ön planda, şafakla arkadan aydınlanır.
          if (_legacyBackdrop)
            Positioned(
              left: size.width * 0.05,
              bottom: -4,
              child: IgnorePointer(
                child: _WelcomerVillager(
                  time: _time,
                  screenHeight: size.height,
                ),
              ),
            ),
          // Çok hafif vinyet — menü metnini oturtur ama sahneyi karartmaz.
          // (Eski 0x73 siyah, aydınlık sabahı geri kirletiyordu.)
          const Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.15,
                    colors: [Color(0x00102A3A), Color(0x33102A3A)],
                    stops: [0.62, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // ── İçerik ────────────────────────────────────────────────────────
          SafeArea(
            child: LayoutBuilder(
              builder: (context, box) => touch
                  ? _touchLayout(context, box)
                  : _wideLayout(context, box),
            ),
          ),

          // ── Kayıtlı köyler — sahnenin ÜSTÜNDE, sayfa değiştirmeden ─────────
          if (_slotsOpen)
            SaveSlotsPanel(
              onClose: _closeSlots,
              onContinue: (meta) {
                setState(() => _slotsOpen = false);
                widget.onContinue(meta);
              },
            ),
        ],
      ),
    );
  }

  // ── Yerleşimler ───────────────────────────────────────────────────────────

  /// Masaüstü: sahnenin soluna yaslanan sinematik navigasyon. Köy görüntüsünün
  /// merkezi ve sağ tarafı tamamen açık kalır; menü artık ortada yüzen bir
  /// kart değil, ekranın kenarından başlayan bir başlık/navigation katmanıdır.
  Widget _wideLayout(BuildContext context, BoxConstraints box) {
    final left = (box.maxWidth * 0.055).clamp(38.0, 84.0);
    final stage = SizedBox(
      width: 460,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppReveal(child: _TitleBlock()),
          const SizedBox(height: 42),
          AppReveal(
            delay: const Duration(milliseconds: 120),
            child: _MenuCard(
              hasSaves: _hasSaves,
              onNewGame: widget.onNewGame,
              onContinue: _openSlots,
              onReferenceVillage: widget.onReferenceVillage,
              onSettings: () => _open(context, const SettingsScreen()),
              onAbout: () => _open(context, const AboutScreen()),
              onLightEditor: () => _open(context, const LightEditorScreen()),
              onPlacementEditor: () =>
                  _open(context, const PlacementEditorScreen()),
              onAnimationRoom: () =>
                  _open(context, const AnimationRoomScreen()),
            ),
          ),
        ],
      ),
    );

    return Stack(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.only(
              left: left,
              right: 24,
              top: 24,
              bottom: 24,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: stage,
            ),
          ),
        ),
        Positioned(
          right: 32,
          bottom: 24,
          child: AppReveal(
            delay: const Duration(milliseconds: 220),
            child: Row(
              children: [
                Container(width: 34, height: 1, color: const Color(0x99F1C588)),
                const SizedBox(width: 10),
                Text(
                  'BAHARIN İLK SABAHI',
                  style: AppUi.label.copyWith(
                    color: AppUi.textHi.withValues(alpha: 0.78),
                    fontSize: 9,
                    letterSpacing: 2.4,
                    shadows: const [
                      Shadow(color: Color(0xDD000000), blurRadius: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// TELEFON + TABLET: kademeli hiyerarşi, üç bant, KAYDIRMA YOK.
  ///
  /// Eski hâl iki ayrı sorunla geliyordu: telefonda 8 eşit satır 2 sütuna
  /// diziliyor (hiyerarşi yok, uzun etiketler "REFERANS K…" diye kırpılıyor),
  /// tablet ise yükseklik eşiğini geçtiği için masaüstü sütununu alıp ekranın
  /// altından taşıyordu. Çözüm tek yerleşim:
  ///
  ///   1. KİMLİK ŞERİDİ — madalyon + kelime işareti + slogan yan yana (dikey
  ///      kompozisyon burada yükseklik yiyor, yatayda bedava).
  ///   2. BİRİNCİL KARTLAR — oyuncunun %95 dokunduğu iki eylem, büyük.
  ///   3. ALT BANT — ikincil çipler solda, geliştirici rozetleri sağda.
  ///
  /// Bütün yükseklikler KALAN boşluktan türetilir ve sonunda bir FittedBox
  /// güvencesi vardır → hiçbir ekranda taşma/kaydırma olamaz.
  Widget _touchLayout(BuildContext context, BoxConstraints box) {
    final w = box.maxWidth, h = box.maxHeight;
    final short = h < 560;
    final contentW = min(short ? 780.0 : 940.0, w - 28);
    final heroH = short ? 76.0 : 108.0;
    final boardH = min(short ? 190.0 : 246.0, h - heroH - 22);
    final railW = (contentW * 0.35).clamp(236.0, 330.0);
    final gap = short ? 10.0 : 16.0;

    return MobileTextFloor(
      child: Stack(
        children: [
          Positioned(
            top: 8,
            left: 14,
            right: 14,
            child: AppReveal(
              child: _HeroBand(height: heroH, short: short),
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 6,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                width: contentW,
                height: boardH,
                child: Row(
                  children: [
                    Expanded(
                      child: AppReveal(
                        delay: const Duration(milliseconds: 90),
                        child: _PrimaryRow(
                          height: boardH,
                          short: short,
                          hasSaves: _hasSaves,
                          onContinue: _openSlots,
                          onNewGame: widget.onNewGame,
                        ),
                      ),
                    ),
                    SizedBox(width: gap),
                    SizedBox(
                      width: railW,
                      child: AppReveal(
                        delay: const Duration(milliseconds: 160),
                        child: _BottomBand(
                          height: boardH,
                          onSettings: () =>
                              _open(context, const SettingsScreen()),
                          onAbout: () => _open(context, const AboutScreen()),
                          onReferenceVillage: widget.onReferenceVillage,
                          onLightEditor: () =>
                              _open(context, const LightEditorScreen()),
                          onPlacementEditor: () =>
                              _open(context, const PlacementEditorScreen()),
                          onAnimationRoom: () =>
                              _open(context, const AnimationRoomScreen()),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _open(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
}

// ─── Bahar ana menü arkaplanı ───────────────────────────────────────────────

/// Masaüstü ve yatay mobil için ayrı kadraj kullanır. Görsellerin merkezinde
/// bilinçli olarak sakin bir okuma alanı var; yatay koyuluk perdesi bu alanı
/// logo ve menü kartlarının altında biraz daha sakinleştirir.
class _MenuSpringBackground extends StatelessWidget {
  final bool touch;
  final bool wideMobile;
  final double time;
  const _MenuSpringBackground({
    required this.touch,
    required this.wideMobile,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    final asset = wideMobile
        ? 'assets/ui/menu_spring_mobile.webp'
        : 'assets/ui/menu_spring_desktop.webp';

    return Positioned.fill(
      child: RepaintBoundary(
        child: IgnorePointer(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                asset,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                filterQuality: FilterQuality.high,
              ),
              _TreeSwayLayer(asset: asset, wideMobile: wideMobile, time: time),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: touch
                        ? const [
                            Color(0x24101A14),
                            Color(0x12101A14),
                            Color(0x06101A14),
                          ]
                        : const [
                            Color(0xE60B100D),
                            Color(0xC90B100D),
                            Color(0x70101812),
                            Color(0x10101812),
                          ],
                    stops: touch
                        ? const [0.0, 0.52, 1.0]
                        : const [0.0, 0.25, 0.48, 0.72],
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: touch
                        ? const [
                            Color(0x4A08120D),
                            Color(0x00101812),
                            Color(0x99101812),
                          ]
                        : const [
                            Color(0x1408120D),
                            Color(0x00101812),
                            Color(0x38101812),
                          ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
              CustomPaint(
                painter: _SpringAmbientPainter(
                  time: time,
                  wideMobile: wideMobile,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Aynı arkaplanın yalnız ağaç tacı bölgelerini birkaç piksel kaydırır.
/// Gövdeler ve binalar sabit kalır; hareket rüzgâr alan yapraklarda toplanır.
class _TreeSwayLayer extends StatelessWidget {
  final String asset;
  final bool wideMobile;
  final double time;

  const _TreeSwayLayer({
    required this.asset,
    required this.wideMobile,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    // Tek sinüs mekanik sallanır; iki yavaş frekans birbirine binince ağaç
    // bazen durulur, bazen hafif bir rüzgâr alır. Gövde sabit, yalnız taç oynar.
    final sway = sin(time * 0.72) * 2.2 + sin(time * 0.19 + 0.8) * 1.1;
    final lift = cos(time * 0.51) * 0.55 + sin(time * 0.27) * 0.25;
    return ClipPath(
      clipper: _TreeCanopyClipper(wideMobile),
      clipBehavior: Clip.antiAlias,
      child: Transform.translate(
        offset: Offset(sway, lift),
        child: Image.asset(
          asset,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

class _TreeCanopyClipper extends CustomClipper<Path> {
  final bool wideMobile;
  const _TreeCanopyClipper(this.wideMobile);

  @override
  Path getClip(Size size) {
    final w = size.width, h = size.height;
    final path = Path();
    if (wideMobile) {
      path
        ..addOval(Rect.fromLTWH(-w * 0.04, h * 0.10, w * 0.18, h * 0.52))
        ..addOval(Rect.fromLTWH(w * 0.07, h * 0.15, w * 0.15, h * 0.40));
    } else {
      path
        ..addOval(Rect.fromLTWH(-w * 0.04, h * 0.04, w * 0.20, h * 0.31))
        ..addOval(Rect.fromLTWH(w * 0.13, h * 0.12, w * 0.20, h * 0.30))
        ..addOval(Rect.fromLTWH(w * 0.80, h * 0.12, w * 0.15, h * 0.23));
    }
    return path;
  }

  @override
  bool shouldReclip(_TreeCanopyClipper oldClipper) =>
      oldClipper.wideMobile != wideMobile;
}

/// Su, çiçek, rüzgâr yaprakları, polen/toz ve ateş hareketlerini tek
/// hafif CustomPaint pass'inde toplar.
class _SpringAmbientPainter extends CustomPainter {
  final double time;
  final bool wideMobile;

  _SpringAmbientPainter({required this.time, required this.wideMobile});

  static final _water = Paint()
    ..blendMode = BlendMode.plus
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;
  static final _petal = Paint()..isAntiAlias = true;
  static final _leaf = Paint()..isAntiAlias = true;
  static final _leafVein = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;
  static final _dust = Paint()
    ..blendMode = BlendMode.plus
    ..isAntiAlias = true;
  static final _stone = Paint()
    ..color = const Color(0xCC65584A)
    ..isAntiAlias = true;
  static final _emberGround = Paint()
    ..color = const Color(0x660F1712)
    ..isAntiAlias = true;
  static final _log = Paint()
    ..color = const Color(0xFF6B3E22)
    ..strokeWidth = 3.2
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size size) {
    _drawWater(canvas, size);
    _drawDust(canvas, size);
    _drawPetals(canvas, size);
    _drawWindLeaves(canvas, size);
    _drawFire(canvas, size);
  }

  /// Her parçacığın rotası kareden kareye değişmesin diye sabit,
  /// ucuz bir 0..1 hash. `Random` yaratmak ya da liste tutmak gerektirmez.
  double _unit(int seed) {
    final value = sin(seed * 12.9898 + 78.233) * 43758.5453;
    return value - value.floorToDouble();
  }

  /// Güneşli orta/sağ vadide havada asılı polen ve toz zerreleri. Noktalar
  /// aşağı düşmez; yavaşça yükselip yana süzülür. Bu katman hareketi
  /// uzaktan hissettirir, menü metninin altına kar yağdırmaz.
  void _drawDust(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final count = wideMobile ? 22 : 38;
    final scale = (size.shortestSide / 700).clamp(0.68, 1.55);

    for (var i = 0; i < count; i++) {
      final speed = 0.018 + _unit(i * 17 + 3) * 0.018;
      final phase = (time * speed + _unit(i * 29 + 11)) % 1.0;
      final baseX = wideMobile
          ? w * (0.08 + _unit(i * 41 + 5) * 0.84)
          : w * (0.38 + _unit(i * 41 + 5) * 0.58);
      final baseY = h * (0.18 + _unit(i * 53 + 7) * 0.60);
      final x =
          baseX +
          phase * w * (0.035 + _unit(i * 13 + 2) * 0.045) +
          sin(time * 0.42 + i * 1.9) * 7 * scale;
      final y =
          baseY -
          phase * h * (0.035 + _unit(i * 31 + 9) * 0.055) +
          sin(time * 0.31 + i * 2.3) * 5 * scale;
      final breathe = pow(sin(phase * pi).clamp(0.0, 1.0), 1.4).toDouble();
      final alpha = breathe * (0.10 + _unit(i * 67 + 1) * 0.28);
      final radius = (0.65 + _unit(i * 73 + 4) * 1.15) * scale;

      _dust.color = const Color(0xFFFFE6A8).withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), radius, _dust);

      // Seyrek iri zerre güneşi yakalayıp bir anlık parıldar. Haç değil,
      // iki kısa ışık çizgisi; masalsı ama göze bağırmaz.
      if (i % 11 == 0 && alpha > 0.16) {
        _dust
          ..strokeWidth = 0.65 * scale
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          Offset(x - radius * 2.2, y),
          Offset(x + radius * 2.2, y),
          _dust,
        );
        canvas.drawLine(
          Offset(x, y - radius * 1.7),
          Offset(x, y + radius * 1.7),
          _dust,
        );
      }
    }
  }

  void _drawWater(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final left = Path();
    if (wideMobile) {
      left
        ..moveTo(w * 0.29, h * 0.46)
        ..cubicTo(w * 0.26, h * 0.57, w * 0.20, h * 0.68, w * 0.17, h * 0.80)
        ..cubicTo(w * 0.13, h * 0.91, w * 0.09, h * 0.95, w * 0.06, h * 1.03);
    } else {
      left
        ..moveTo(w * 0.42, h * 0.36)
        ..cubicTo(w * 0.37, h * 0.44, w * 0.32, h * 0.48, w * 0.30, h * 0.53)
        ..cubicTo(w * 0.25, h * 0.61, w * 0.17, h * 0.69, w * 0.10, h * 0.75)
        ..cubicTo(w * 0.06, h * 0.79, w * 0.02, h * 0.82, -w * 0.02, h * 0.85);
    }
    _flowAlong(canvas, left, size.shortestSide * 0.008, 0);

    if (!wideMobile) {
      final mill = Path()
        ..moveTo(w * 0.66, h * 0.30)
        ..cubicTo(w * 0.65, h * 0.40, w * 0.67, h * 0.48, w * 0.73, h * 0.56);
      _flowAlong(canvas, mill, size.shortestSide * 0.006, 17);
    }
  }

  void _flowAlong(Canvas canvas, Path path, double dash, int phase) {
    for (final metric in path.computeMetrics()) {
      final count = (metric.length / (dash * 3.8)).clamp(8, 24).round();
      for (var i = 0; i < count; i++) {
        final t = (time * 0.075 + i / count + phase * 0.013) % 1.0;
        final tangent = metric.getTangentForOffset(metric.length * t);
        if (tangent == null) continue;
        final pulse = sin(t * pi).clamp(0.0, 1.0);
        _water
          ..color = Color.fromRGBO(190, 232, 255, 0.05 + pulse * 0.17)
          ..strokeWidth = 0.55 + pulse * 0.75;
        final unit = tangent.vector / tangent.vector.distance;
        canvas.drawLine(
          tangent.position - unit * dash * 0.45,
          tangent.position + unit * dash * 0.45,
          _water,
        );
      }
    }
    _water.blendMode = BlendMode.plus;
  }

  void _drawPetals(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final originX = wideMobile ? w * 0.08 : w * 0.18;
    final spreadX = wideMobile ? w * 0.17 : w * 0.19;
    final originY = wideMobile ? h * 0.18 : h * 0.13;
    final fallH = wideMobile ? h * 0.54 : h * 0.40;
    final scale = (size.shortestSide / 700).clamp(0.7, 1.5);
    for (var i = 0; i < 16; i++) {
      final phase = (time * (0.035 + i % 3 * 0.006) + i * 0.071) % 1.0;
      final x =
          originX +
          ((i * 37) % 101) / 100 * spreadX +
          sin(time * 0.9 + i * 1.7) * 8 * scale;
      final y = originY + phase * fallH;
      final alpha = sin(phase * pi).clamp(0.0, 1.0) * 0.72;
      _petal.color =
          (i % 3 == 0 ? const Color(0xFFFFD8E4) : const Color(0xFFFFF1E2))
              .withValues(alpha: alpha);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(sin(time * 1.3 + i) * 0.8);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: 2.8 * scale,
          height: 1.5 * scale,
        ),
        _petal,
      );
      canvas.restore();
    }
  }

  /// Ağaçlardan kopup sahneyi çapraz geçen yapraklar. Ufaktakiler orta
  /// planda, her beşinci yaprak daha büyük/yumuşak çizilerek kameraya yakın
  /// okunur; böylece tek bir düz partikül düzlemi yerine derinlik oluşur.
  void _drawWindLeaves(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final count = wideMobile ? 14 : 24;
    final scale = (size.shortestSide / 700).clamp(0.70, 1.6);
    const colors = [
      Color(0xFF8BAA59), // taze yeşil
      Color(0xFF6F8C46),
      Color(0xFFC6A052), // güneş vurmuş yaprak
      Color(0xFFB87542),
      Color(0xFFD5B969),
    ];

    for (var i = 0; i < count; i++) {
      final near = i % 5 == 0;
      final speed = 0.045 + _unit(i * 19 + 6) * 0.035;
      final phase = (time * speed + _unit(i * 43 + 8)) % 1.0;
      final lane = _unit(i * 61 + 4);
      final startX = -w * 0.10 + _unit(i * 71 + 3) * w * 0.82;
      final travel = w * (0.34 + _unit(i * 23 + 9) * 0.44);
      final wrap = w * 1.18;
      final x = (startX + phase * travel + w * 0.10) % wrap - w * 0.10;
      final y =
          h * (0.08 + lane * 0.48) +
          phase * h * (0.16 + _unit(i * 37 + 7) * 0.23) +
          sin(time * (0.75 + _unit(i * 11) * 0.55) + i * 1.8) *
              (8 + 10 * lane) *
              scale;

      final life = sin(phase * pi).clamp(0.0, 1.0);
      // Masaüstünde sol tarafta logo/menü var: yaprak oradan geçebilir ama
      // metni kirletmeden neredeyse silinir. Sağdaki açık sahnede belirginleşir.
      final readingFade = !wideMobile && x < w * 0.42 ? 0.22 : 1.0;
      final alpha = life * readingFade * (near ? 0.48 : 0.62);
      if (alpha < 0.015) continue;

      final length =
          (near ? 10.0 : 5.8) * (0.76 + _unit(i * 47 + 2) * 0.55) * scale;
      final width = length * (0.38 + _unit(i * 79 + 1) * 0.12);
      final color = colors[i % colors.length].withValues(alpha: alpha);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(
        time * (0.75 + _unit(i * 83 + 2) * 1.4) +
            i * 0.91 +
            sin(time * 0.6 + i) * 0.8,
      );
      final path = Path()
        ..moveTo(-length * 0.52, 0)
        ..quadraticBezierTo(0, -width, length * 0.52, 0)
        ..quadraticBezierTo(0, width, -length * 0.52, 0)
        ..close();
      _leaf
        ..color = color
        ..maskFilter = near
            ? MaskFilter.blur(BlurStyle.normal, 0.55 * scale)
            : null;
      canvas.drawPath(path, _leaf);

      if (near) {
        _leafVein
          ..color = const Color(0xFF4C5E31).withValues(alpha: alpha * 0.65)
          ..strokeWidth = 0.55 * scale;
        canvas.drawLine(
          Offset(-length * 0.36, 0),
          Offset(length * 0.38, 0),
          _leafVein,
        );
      }
      canvas.restore();
    }
    _leaf.maskFilter = null;
  }

  void _drawFire(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cx = wideMobile ? w * 0.245 : w * 0.305;
    final cy = wideMobile ? h * 0.68 : h * 0.70;
    final scale = (size.shortestSide / 650).clamp(0.72, 1.45);
    final glow = Paint()
      ..shader = ui.Gradient.radial(
        Offset(cx, cy - 5 * scale),
        32 * scale,
        [
          const Color(0x66FF9A38),
          const Color(0x20FFBE61),
          const Color(0x00FFBE61),
        ],
        [0.0, 0.45, 1.0],
      )
      ..blendMode = BlendMode.plus;
    canvas.drawCircle(Offset(cx, cy - 5 * scale), 32 * scale, glow);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy + 1.5 * scale),
        width: 25 * scale,
        height: 8 * scale,
      ),
      _emberGround,
    );
    _log.strokeWidth = 3.2 * scale;
    canvas.drawLine(
      Offset(cx - 7 * scale, cy + 1.5 * scale),
      Offset(cx + 7 * scale, cy - 2.5 * scale),
      _log,
    );
    canvas.drawLine(
      Offset(cx - 7 * scale, cy - 2.5 * scale),
      Offset(cx + 7 * scale, cy + 1.5 * scale),
      _log,
    );

    for (var i = 0; i < 7; i++) {
      final a = i / 7 * pi * 2;
      canvas.drawCircle(
        Offset(cx + cos(a) * 9 * scale, cy + sin(a) * 3.2 * scale),
        2.4 * scale,
        _stone,
      );
    }
    FlameRenderer.draw(canvas, cx, cy, 1.45 * scale, time, 41, intensity: 0.9);
  }

  @override
  bool shouldRepaint(_SpringAmbientPainter oldDelegate) =>
      oldDelegate.time != time || oldDelegate.wideMobile != wideMobile;
}

// ─── Başlık bloğu ────────────────────────────────────────────────────────────

class _TitleBlock extends StatelessWidget {
  const _TitleBlock();
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 94,
          height: 94,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [Color(0x52FFD89D), Color(0x14E49139), Color(0x00E49139)],
              stops: [0.0, 0.58, 1.0],
            ),
            border: Border.all(color: const Color(0x33F7E8CF)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x44000000),
                blurRadius: 22,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: const GameLogo(size: 74),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BİR KÖYÜN HİKÂYESİ',
                style: AppUi.label.copyWith(
                  color: const Color(0xFFF4D8AB),
                  fontSize: 9,
                  letterSpacing: 3.0,
                  shadows: const [
                    Shadow(color: Color(0xCC101812), blurRadius: 8),
                  ],
                ),
              ),
              const SizedBox(height: 5),
              ShaderMask(
                shaderCallback: (r) => const LinearGradient(
                  colors: [Color(0xFFFFFFFF), Color(0xFFF0C27C)],
                ).createShader(r),
                child: const Text(
                  'LUW',
                  style: TextStyle(
                    fontFamily: AppUi.fontDisplay,
                    fontWeight: FontWeight.w700,
                    fontSize: 46,
                    height: 1,
                    letterSpacing: 13,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Color(0xCC000000),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'ATEŞİ KORU  ·  KÖYÜ KUR  ·  HİKÂYENİ YAZ',
                style: AppUi.label.copyWith(
                  color: AppUi.textHi.withValues(alpha: 0.76),
                  fontSize: 8.5,
                  letterSpacing: 1.45,
                  shadows: const [
                    Shadow(color: Color(0xDD101812), blurRadius: 7),
                  ],
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'SÜRÜM 0.1.0',
                style: AppUi.label.copyWith(
                  color: AppUi.textHi.withValues(alpha: 0.42),
                  fontSize: 8,
                  letterSpacing: 1.8,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Menü kartı (masaüstü) ───────────────────────────────────────────────────

class _MenuCard extends StatelessWidget {
  final VoidCallback onNewGame,
      onSettings,
      onAbout,
      onContinue,
      onLightEditor,
      onPlacementEditor,
      onAnimationRoom,
      onReferenceVillage;
  final bool hasSaves;

  const _MenuCard({
    required this.onNewGame,
    required this.onContinue,
    required this.onReferenceVillage,
    required this.hasSaves,
    required this.onSettings,
    required this.onAbout,
    required this.onLightEditor,
    required this.onPlacementEditor,
    required this.onAnimationRoom,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hasSaves ? 'KÖYÜNE DÖN' : 'YENİ BİR BAŞLANGIÇ',
          style: AppUi.label.copyWith(
            color: const Color(0xFFF1C588),
            fontSize: 9.5,
            letterSpacing: 2.8,
            shadows: const [Shadow(color: Color(0xDD000000), blurRadius: 7)],
          ),
        ),
        const SizedBox(height: 8),
        if (hasSaves) ...[
          _MenuRow(
            icon: GameIconData.home,
            label: 'DEVAM ET',
            note: 'Kaldığın köye dön',
            primary: true,
            onTap: onContinue,
            height: 76,
          ),
          const SizedBox(height: 4),
        ],
        _MenuRow(
          icon: GameIconData.flame,
          label: 'YENİ KÖY',
          note: 'Yeni bir yerleşim kur',
          primary: !hasSaves,
          onTap: onNewGame,
          height: 76,
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 44,
          child: Row(
            children: [
              Expanded(
                child: _MenuChip(
                  icon: GameIconData.gear,
                  label: 'AYARLAR',
                  onTap: onSettings,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MenuChip(
                  icon: GameIconData.scroll,
                  label: 'HAKKINDA',
                  onTap: onAbout,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const _SectionRule(label: 'GELİŞTİRİCİ ARAÇLARI'),
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(
              child: _MenuRow(
                icon: GameIconData.scroll,
                label: 'REFERANS KÖY',
                onTap: onReferenceVillage,
                height: 38,
                compact: true,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _MenuRow(
                icon: GameIconData.bolt,
                label: 'IŞIK EDİTÖRÜ',
                onTap: onLightEditor,
                height: 38,
                compact: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _MenuRow(
                icon: GameIconData.hammer,
                label: 'EBAT EDİTÖRÜ',
                onTap: onPlacementEditor,
                height: 38,
                compact: true,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _MenuRow(
                icon: GameIconData.play,
                label: 'ANİMASYONLAR',
                onTap: onAnimationRoom,
                height: 38,
                compact: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionRule extends StatelessWidget {
  final String label;
  const _SectionRule({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0x33F5E6CB), height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            label,
            style: AppUi.label.copyWith(
              color: AppUi.textLo,
              fontSize: 9,
              letterSpacing: 2.0,
            ),
          ),
        ),
        const Expanded(child: Divider(color: Color(0x33F5E6CB), height: 1)),
      ],
    );
  }
}

class _MenuRow extends StatefulWidget {
  final GameIconData icon;
  final String label;
  final String? note;
  final bool primary;
  final bool compact;
  final VoidCallback onTap;

  final double height;
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.note,
    this.primary = false,
    this.compact = false,
    this.height = 54,
  });

  @override
  State<_MenuRow> createState() => _MenuRowState();
}

class _MenuRowState extends State<_MenuRow> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final hot = _hover || _down;
    final lit = hot || widget.primary;
    final accent = AppUi.accent;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOut,
          height: widget.height,
          padding: EdgeInsets.symmetric(horizontal: widget.compact ? 10 : 14),
          transform: _down
              ? Matrix4.translationValues(0, 1, 0)
              : Matrix4.identity(),
          decoration: widget.compact
              ? BoxDecoration(
                  color: hot
                      ? const Color(0xCC283029)
                      : const Color(0x99161B18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: hot
                        ? accent.withValues(alpha: 0.68)
                        : const Color(0x26FFFFFF),
                  ),
                )
              : BoxDecoration(
                  gradient: LinearGradient(
                    colors: lit
                        ? [
                            accent.withValues(alpha: hot ? 0.24 : 0.16),
                            const Color(0x0018201A),
                          ]
                        : const [Color(0x2918201A), Color(0x0018201A)],
                    stops: const [0.0, 0.88],
                  ),
                  border: Border(
                    left: BorderSide(
                      color: lit ? accent : const Color(0x5CFFFFFF),
                      width: lit ? 3 : 1,
                    ),
                    bottom: BorderSide(
                      color: lit
                          ? const Color(0x4DE49139)
                          : const Color(0x24FFFFFF),
                    ),
                  ),
                ),
          child: Row(
            children: [
              // İkon madalyonu
              Container(
                width: widget.compact ? 26 : 38,
                height: widget.compact ? 26 : 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.compact ? 7 : 11),
                  color: lit
                      ? accent.withValues(alpha: 0.14)
                      : const Color(0x66101412),
                  border: Border.all(
                    color: lit
                        ? accent.withValues(alpha: 0.55)
                        : const Color(0x22FFFFFF),
                    width: 1,
                  ),
                ),
                child: GameIcon(
                  widget.icon,
                  size: widget.compact ? 13 : 18,
                  color: lit ? AppUi.accentSoft : AppUi.textMid,
                ),
              ),
              SizedBox(width: widget.compact ? 9 : 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        style: TextStyle(
                          fontFamily: AppUi.fontDisplay,
                          fontWeight: FontWeight.w700,
                          fontSize: widget.compact ? 11 : 16,
                          letterSpacing: widget.compact ? 1.1 : 2.0,
                          color: lit ? AppUi.textHi : AppUi.textMid,
                        ),
                      ),
                    ),
                    if (widget.note != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.note!,
                        maxLines: 1,
                        style: AppUi.body.copyWith(
                          color: lit ? AppUi.textMid : AppUi.textLo,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!widget.compact)
                GameIcon(
                  GameIconData.chevron,
                  size: 14,
                  color: lit ? accent : AppUi.textLo.withValues(alpha: 0.6),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Dokunma yerleşimi: kimlik şeridi ───────────────────────────────────────

/// Madalyon + kelime işareti + slogan YAN YANA. Masaüstündeki dikey kompozisyon
/// (madalyon, altında başlık, altında kural, altında slogan) alçak ekranda
/// tek başına 250px yiyordu; yatayda aynı bilgi 78px'e sığar.
class _HeroBand extends StatelessWidget {
  final double height;
  final bool short;
  const _HeroBand({required this.height, required this.short});

  @override
  Widget build(BuildContext context) {
    final logoSize = (height * 0.86).clamp(60.0, 94.0);
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: logoSize,
            height: logoSize,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Color(0x4DFFD89D),
                  Color(0x15E49139),
                  Color(0x00E49139),
                ],
                stops: [0.0, 0.6, 1.0],
              ),
            ),
            child: GameLogo(size: logoSize * 0.76),
          ),
          SizedBox(width: short ? 12 : 18),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (r) => const LinearGradient(
                    colors: [Color(0xFFFFFFFF), Color(0xFFF2C681)],
                  ).createShader(r),
                  child: Text(
                    'LUW',
                    style: TextStyle(
                      fontFamily: AppUi.fontDisplay,
                      fontWeight: FontWeight.w700,
                      fontSize: short ? 28 : 38,
                      height: 1,
                      letterSpacing: short ? 8 : 11,
                      color: Colors.white,
                      shadows: const [
                        Shadow(
                          color: Color(0xCC000000),
                          blurRadius: 12,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'ATEŞİ KORU  ·  KÖYÜ KUR  ·  HİKÂYENİ YAZ',
                    style: AppUi.label.copyWith(
                      color: AppUi.textHi.withValues(alpha: 0.8),
                      fontSize: short ? 8.5 : 10,
                      letterSpacing: short ? 1.35 : 1.8,
                      shadows: const [
                        Shadow(color: Color(0xDD101812), blurRadius: 7),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0x7A101512),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0x28FFFFFF)),
            ),
            child: Text(
              'SÜRÜM 0.1.0',
              style: AppUi.label.copyWith(
                color: AppUi.textHi.withValues(alpha: 0.6),
                fontSize: 8.5,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Dokunma yerleşimi: birincil kartlar ────────────────────────────────────

/// Oyuncunun menüde yaptığı iki şey. Diğer her şeyden BÜYÜK olmaları
/// kademelendirmenin kendisi: 8 eşit satırda hiyerarşi yoktu, göz nereye
/// gideceğini bilmiyordu.
class _PrimaryRow extends StatelessWidget {
  final double height;
  final bool short, hasSaves;
  final VoidCallback onContinue, onNewGame;
  const _PrimaryRow({
    required this.height,
    required this.short,
    required this.hasSaves,
    required this.onContinue,
    required this.onNewGame,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Column(
        children: [
          if (hasSaves) ...[
            Expanded(
              child: _PrimaryCard(
                icon: GameIconData.home,
                label: 'DEVAM ET',
                note: 'kaldığın köye dön',
                primary: true,
                height: (height - 8) / 2,
                short: short,
                onTap: onContinue,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Expanded(
            child: _PrimaryCard(
              icon: GameIconData.flame,
              label: 'YENİ KÖY',
              note: 'ateşi yeniden yak',
              primary: !hasSaves,
              height: hasSaves ? (height - 8) / 2 : height,
              short: short,
              onTap: onNewGame,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryCard extends StatefulWidget {
  final GameIconData icon;
  final String label, note;
  final bool primary, short;
  final double height;
  final VoidCallback onTap;
  const _PrimaryCard({
    required this.icon,
    required this.label,
    required this.note,
    required this.primary,
    required this.short,
    required this.height,
    required this.onTap,
  });

  @override
  State<_PrimaryCard> createState() => _PrimaryCardState();
}

class _PrimaryCardState extends State<_PrimaryCard> {
  bool _hover = false, _down = false;

  @override
  Widget build(BuildContext context) {
    final hot = _hover || _down;
    final lit = hot || widget.primary;
    const accent = AppUi.accent;
    final disc = (widget.height * 0.54).clamp(40.0, 58.0);

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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          transform: _down
              ? Matrix4.translationValues(1.5, 0, 0)
              : Matrix4.identity(),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: lit
                  ? [
                      accent.withValues(alpha: hot ? 0.32 : 0.22),
                      const Color(0xE6171C18),
                      const Color(0xB0101512),
                    ]
                  : const [
                      Color(0xD9212822),
                      Color(0xE6171C18),
                      Color(0xB0101512),
                    ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: lit
                  ? accent.withValues(alpha: 0.72)
                  : const Color(0x38FFFFFF),
              width: lit ? 1.5 : 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          padding: EdgeInsets.symmetric(horizontal: widget.short ? 16 : 22),
          child: Row(
            children: [
              Container(
                width: disc,
                height: disc,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(disc * 0.28),
                  color: lit
                      ? accent.withValues(alpha: 0.16)
                      : const Color(0x66101412),
                  border: Border.all(
                    color: lit
                        ? accent.withValues(alpha: 0.55)
                        : const Color(0x28FFFFFF),
                    width: 1,
                  ),
                ),
                child: GameIcon(
                  widget.icon,
                  size: disc * 0.46,
                  color: lit ? AppUi.accentSoft : AppUi.textMid,
                ),
              ),
              SizedBox(width: widget.short ? 14 : 20),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      maxLines: 1,
                      style: TextStyle(
                        fontFamily: AppUi.fontDisplay,
                        fontWeight: FontWeight.w700,
                        fontSize: widget.short ? 17 : 21,
                        letterSpacing: 2.2,
                        height: 1,
                        color: lit ? AppUi.textHi : AppUi.textMid,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      widget.note,
                      maxLines: 1,
                      style: AppUi.body.copyWith(
                        color: lit ? AppUi.textMid : AppUi.textLo,
                        fontStyle: FontStyle.italic,
                        fontSize: widget.short ? 11 : 13,
                      ),
                    ),
                  ],
                ),
              ),
              GameIcon(
                GameIconData.chevron,
                size: 16,
                color: lit ? AppUi.accent : AppUi.textLo,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Dokunma yerleşimi: alt bant ────────────────────────────────────────────

/// İkincil kapılar solda (ayarlar · hakkında), GELİŞTİRİCİ araçları sağda
/// küçük rozet olarak. Dev girişleri oyuncu akışının parçası değil; oyun
/// menüsünde birincil eylemlerle aynı boyda durmaları yanlış kademelendirmeydi.
/// Rozetin adı uzun basınca (Tooltip) görünür.
class _BottomBand extends StatelessWidget {
  final double height;
  final VoidCallback onSettings,
      onAbout,
      onReferenceVillage,
      onLightEditor,
      onPlacementEditor,
      onAnimationRoom;
  const _BottomBand({
    required this.height,
    required this.onSettings,
    required this.onAbout,
    required this.onReferenceVillage,
    required this.onLightEditor,
    required this.onPlacementEditor,
    required this.onAnimationRoom,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _MenuChip(
                    icon: GameIconData.gear,
                    label: 'AYARLAR',
                    onTap: onSettings,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MenuChip(
                    icon: GameIconData.scroll,
                    label: 'HAKKINDA',
                    onTap: onAbout,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 52,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xE6222823), Color(0xE8171C19)],
                ),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: const Color(0x38FFFFFF)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x44000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _DevBadge(
                    icon: GameIconData.scroll,
                    tip: 'Referans Köy',
                    onTap: onReferenceVillage,
                  ),
                  _DevBadge(
                    icon: GameIconData.bolt,
                    tip: 'Işık Editörü',
                    onTap: onLightEditor,
                  ),
                  _DevBadge(
                    icon: GameIconData.hammer,
                    tip: 'Ebat Editörü',
                    onTap: onPlacementEditor,
                  ),
                  _DevBadge(
                    icon: GameIconData.play,
                    tip: 'Animasyonlar',
                    onTap: onAnimationRoom,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuChip extends StatefulWidget {
  final GameIconData icon;
  final String label;
  final VoidCallback onTap;
  const _MenuChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_MenuChip> createState() => _MenuChipState();
}

class _MenuChipState extends State<_MenuChip> {
  bool _hover = false, _down = false;

  @override
  Widget build(BuildContext context) {
    final hot = _hover || _down;
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOut,
          // Dokunma tabanı: kapsül bandın tamamını doldurur (>= 44dp).
          height: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: hot
                  ? const [Color(0xF0323932), Color(0xF0222822)]
                  : const [Color(0xE6222823), Color(0xE8171C19)],
            ),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: hot
                  ? AppUi.accent.withValues(alpha: 0.75)
                  : const Color(0x38FFFFFF),
              width: hot ? 1.4 : 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x44000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GameIcon(
                widget.icon,
                size: 15,
                color: hot ? AppUi.accentSoft : AppUi.textMid,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      fontFamily: AppUi.fontDisplay,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      letterSpacing: 1.4,
                      color: hot ? AppUi.textHi : AppUi.textMid,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DevBadge extends StatefulWidget {
  final GameIconData icon;
  final String tip;
  final VoidCallback onTap;
  const _DevBadge({required this.icon, required this.tip, required this.onTap});

  @override
  State<_DevBadge> createState() => _DevBadgeState();
}

class _DevBadgeState extends State<_DevBadge> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          // 44dp dokunma tabanı — rozet küçük görünür, hedefi küçülmez.
          child: SizedBox(
            width: MobileUi.tap,
            height: MobileUi.tap,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 130),
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _hover
                      ? AppUi.accent.withValues(alpha: 0.15)
                      : const Color(0x30101412),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: _hover
                        ? AppUi.accent.withValues(alpha: 0.6)
                        : const Color(0x24FFFFFF),
                  ),
                ),
                child: GameIcon(
                  widget.icon,
                  size: 17,
                  color: _hover ? AppUi.accentSoft : AppUi.textMid,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Güneş + hâle ───────────────────────────────────────────────────────────

class _SunWithGlow extends StatelessWidget {
  final double time;
  const _SunWithGlow({required this.time});
  @override
  Widget build(BuildContext context) {
    final pulse = sin(time * 0.5) * 0.06 + 0.94;
    return SizedBox(
      width: 132,
      height: 132,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Geniş soluk şafak hâlesi
          Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Color.fromRGBO(255, 226, 178, 0.60 * pulse),
                  Color.fromRGBO(255, 190, 120, 0.22 * pulse),
                  const Color(0x00FFC080),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
          // Dar parlak çekirdek — yeni doğan güneş sıcak-beyaz
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Color.fromRGBO(255, 246, 224, 0.9 * pulse),
                  const Color(0x00FFE6BE),
                ],
              ),
            ),
          ),
          // Güneş diski — sert kare değil, sıcak-beyaz yumuşak disk
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0xFFFFFBF0), Color(0xFFFFE7C2)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sürüklenen bulutlar ──────────────────────────────────────────────────────

class _DriftingClouds extends StatelessWidget {
  final double time;
  final double screenWidth;
  const _DriftingClouds({required this.time, required this.screenWidth});

  @override
  Widget build(BuildContext context) {
    final wrap = screenWidth + 120.0;
    final drift = (time * 6.0) % wrap;
    double cx(double base) => (base + drift) % wrap - 60;
    return Stack(
      children: [
        Positioned(
          left: cx(40),
          top: 70,
          child: const PixelCloud(scale: 1.1, parallax: 0.6),
        ),
        Positioned(
          left: cx(screenWidth * 0.35),
          top: 110,
          child: const PixelCloud(scale: 0.8, parallax: 0.4),
        ),
        Positioned(
          left: cx(screenWidth * 0.70),
          top: 50,
          child: const PixelCloud(scale: 1.3, parallax: 0.8),
        ),
        Positioned(
          left: cx(screenWidth * 0.92),
          top: 130,
          child: const PixelCloud(scale: 0.7, parallax: 0.35),
        ),
      ],
    );
  }
}

// ── Ufuk silüeti ─────────────────────────────────────────────────────────────

class _HorizonPainter extends CustomPainter {
  final double time;
  _HorizonPainter({required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // — UZAK SIRT: atmosferik perspektif → puslu, gökle neredeyse karışır.
    final farPath = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.40)
      ..quadraticBezierTo(w * 0.22, h * 0.20, w * 0.48, h * 0.34)
      ..quadraticBezierTo(w * 0.72, h * 0.46, w, h * 0.26)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(farPath, Paint()..color = const Color(0xFF8FB6AC));

    // — ORTA TEPE
    final midPath = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.55)
      ..quadraticBezierTo(w * 0.30, h * 0.30, w * 0.55, h * 0.50)
      ..quadraticBezierTo(w * 0.80, h * 0.65, w, h * 0.40)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(midPath, Paint()..color = const Color(0xFF3D6B5E));

    // Sırt çizgisine güneş öpücüğü — tepe hattı ışığa doğru altın parlar.
    canvas.drawPath(
      midPath,
      Paint()
        ..color = const Color(0x66FFDDA0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // Binalar ekran genişliğiyle ölçeklenir — sabit piksel ebat geniş ekranda
    // köyü oyuncak gibi gösteriyordu.
    final s = (w / 900).clamp(0.9, 1.9);

    void building(
      double cx,
      double cy,
      double bw,
      double bh, {
      bool hasRoof = true,
      bool hasWindow = true,
    }) {
      // Gövde: siyah değil SICAK ARDUVAZ — sağ (güneş) yüzü belirgin açılır.
      canvas.drawRect(
        Rect.fromLTWH(cx - bw / 2, cy - bh, bw, bh),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(cx - bw / 2, 0),
            Offset(cx + bw / 2, 0),
            [const Color(0xFF23343C), const Color(0xFF44585C)],
          ),
      );
      if (hasRoof) {
        final roof = Path()
          ..moveTo(cx - bw / 2 - 2, cy - bh)
          ..lineTo(cx, cy - bh - bw * 0.45)
          ..lineTo(cx + bw / 2 + 2, cy - bh)
          ..close();
        // Kiremit — sabah güneşi çatıyı yakalar, terracotta ısınır.
        canvas.drawPath(
          roof,
          Paint()
            ..shader = ui.Gradient.linear(
              Offset(cx - bw / 2, 0),
              Offset(cx + bw / 2, 0),
              [const Color(0xFF6B4034), const Color(0xFFA8674A)],
            ),
        );
      }
      if (hasWindow) {
        // Sabah oldu: lambalar sönmek üzere, camlar artık çoğunlukla gökyüzünü
        // yansıtıyor — kor gibi yanan pencere geceye aitti.
        final flicker = (sin(time * 3.5 + cx) * 0.2 + 0.8).clamp(0.6, 1.0);
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(cx, cy - bh * 0.55),
            width: bw * 0.22,
            height: bh * 0.22,
          ),
          Paint()
            ..color = Color.fromRGBO(
              255,
              214,
              150,
              (0.42 * flicker).clamp(0.15, 1.0),
            ),
        );
      }
    }

    // Köy ORTA TEPENİN eteğine kurulur; birazdan çizilecek yakın çayır
    // temellerini örtecek → derinlik. (Düz bir zemin çizgisine dizilmiş evler
    // ekranı boydan boya kesen çirkin bir yatay çizgi bırakıyordu.)
    final groundY = h * 0.74;
    building(w * 0.14, groundY + 6 * s, 38 * s, 32 * s);
    building(w * 0.24, groundY + 2 * s, 28 * s, 22 * s);
    building(w * 0.34, groundY + 8 * s, 44 * s, 40 * s);
    building(w * 0.62, groundY + 4 * s, 24 * s, 20 * s, hasWindow: false);
    building(w * 0.72, groundY + 9 * s, 36 * s, 36 * s);
    building(w * 0.86, groundY + 3 * s, 30 * s, 28 * s);

    // Kule merkezden UZAK: ortada menü paneli duruyor, w*0.44'te tamamen
    // gizleniyordu.
    final towerX = w * 0.29;
    final towerH = 64 * s, towerW = 16 * s;
    canvas.drawRect(
      Rect.fromLTWH(towerX - towerW / 2, groundY - towerH, towerW, towerH),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(towerX - towerW / 2, 0),
          Offset(towerX + towerW / 2, 0),
          [const Color(0xFF283A42), const Color(0xFF4E646A)],
        ),
    );
    // Çan katı — düz bir kapak, kuleyi fabrika bacasına benzetiyordu.
    final belfryY = groundY - towerH;
    canvas.drawRect(
      Rect.fromLTWH(towerX - 11 * s, belfryY - 16 * s, 22 * s, 16 * s),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(towerX - 11 * s, 0),
          Offset(towerX + 11 * s, 0),
          [const Color(0xFF2E434B), const Color(0xFF566E74)],
        ),
    );
    // Sivri kiremit külah
    canvas.drawPath(
      Path()
        ..moveTo(towerX - 14 * s, belfryY - 16 * s)
        ..lineTo(towerX, belfryY - 34 * s)
        ..lineTo(towerX + 14 * s, belfryY - 16 * s)
        ..close(),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(towerX - 14 * s, 0),
          Offset(towerX + 14 * s, 0),
          [const Color(0xFF6B4034), const Color(0xFFA8674A)],
        ),
    );
    // Çan boşluğu — kemerli, içinde sabah ışığı
    final towerFlicker = (sin(time * 2.0) * 0.15 + 0.85).clamp(0.6, 1.0);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(towerX - 5 * s, belfryY - 12 * s, 10 * s, 11 * s),
        topLeft: Radius.circular(5 * s),
        topRight: Radius.circular(5 * s),
      ),
      Paint()
        ..color = Color.fromRGBO(
          255,
          228,
          170,
          (0.55 * towerFlicker).clamp(0.2, 1.0),
        ),
    );

    // Meydan ateşi — sabah oldu, sadece közü kaldı: soluk sıcak bir leke.
    final fireFlicker = (sin(time * 6.0) * 0.25 + 0.75).clamp(0.5, 1.0);
    canvas.drawCircle(
      Offset(w * 0.34, groundY - 4),
      30 * s,
      Paint()
        ..color = Color.fromRGBO(
          255,
          170,
          80,
          (0.18 * fireFlicker).clamp(0.05, 1.0),
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );

    // Sabah bacaları — evler uyanıyor, ocaklar tütüyor.
    void smoke(double cx, double topY) {
      final smk = Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      for (int i = 0; i < 5; i++) {
        final t = i / 4.0;
        final rise = t * 46 * s;
        final wob = sin(time * 0.9 + i * 0.8 + cx) * (5 + t * 10) * s;
        final a = (0.34 * (1 - t)).clamp(0.0, 1.0);
        smk.color = Color.fromRGBO(255, 251, 243, a);
        canvas.drawCircle(
          Offset(cx + wob, topY - rise),
          (3.0 + t * 5.0) * s,
          smk,
        );
      }
    }

    smoke(w * 0.14, groundY - 30 * s);
    smoke(w * 0.72, groundY - 32 * s);

    // — YAKIN ÇAYIR: dümdüz kesilmiş bir bant DEĞİL, yumuşak eğri bir sırt.
    // Köyün temellerini örter, sahneye üçüncü derinlik katmanını verir.
    final nearTop = h * 0.80;
    final nearPath = Path()
      ..moveTo(0, h)
      ..lineTo(0, nearTop + 10)
      ..quadraticBezierTo(w * 0.20, nearTop - 16, w * 0.46, nearTop + 2)
      ..quadraticBezierTo(w * 0.74, nearTop + 22, w, nearTop - 8)
      ..lineTo(w, h)
      ..close();
    // Düz tek renk yerine dikey gradyan: sırt ışıkta, dip serin — çayır
    // düz bir yeşil leke olmaktan çıkar.
    canvas.drawPath(
      nearPath,
      Paint()
        ..shader = ui.Gradient.linear(Offset(0, nearTop - 16), Offset(0, h), [
          const Color(0xFF3E6B5F),
          const Color(0xFF224340),
        ]),
    );
    // Güneşten (sağ) çayıra düşen geniş, çok soluk ışık havuzu
    canvas.save();
    canvas.clipPath(nearPath);
    canvas.drawRect(
      Rect.fromLTWH(0, nearTop - 20, w, h - nearTop + 20),
      Paint()
        ..shader = ui.Gradient.radial(Offset(w * 0.78, nearTop + 6), w * 0.55, [
          const Color(0x30FFD79E),
          const Color(0x00FFD79E),
        ]),
    );
    canvas.restore();
    // Sırt hattına sabah ışığı — çayırın tepesi altın bir tel gibi parlar.
    canvas.drawPath(
      nearPath,
      Paint()
        ..color = const Color(0x5CFFD8A0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }

  @override
  bool shouldRepaint(_HorizonPainter old) => old.time != time;
}

// ─── Şafak gökyüzü ───────────────────────────────────────────────────────────

/// SABAHIN İLK SAATİ — güneş çoktan doğmuş, gök açılmış. Tepede berrak gök
/// mavisi, ortada turkuaz→soluk su yeşili, ufka doğru şeftali→sabah altını.
/// Mor/leylak bandı kasten YOK: o bant sahneyi bunaltıyordu (bkz. şafak öncesi
/// çivit sürümü). Aşağı inildikçe değer AÇILIR, koyulaşmaz — umut bu yönden gelir.
class _DawnSky extends StatelessWidget {
  const _DawnSky();
  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF4E8FC4), // açık gök mavisi
            Color(0xFF7FB9CE), // turkuaz
            Color(0xFFBBD9C0), // soluk su yeşili
            Color(0xFFF6C98E), // şeftali
            Color(0xFFFFD98A), // ufuk altını
          ],
          stops: [0.0, 0.26, 0.50, 0.76, 1.0],
        ),
      ),
      child: SizedBox.expand(),
    );
  }
}

// ─── Sabah ışınları ──────────────────────────────────────────────────────────

/// Yükselen güneşten köye doğru açılan yumuşak yelpaze ışınları. Çok düşük
/// alfa + additive harman → göz almadan "sabah ferahlığı" hissi.
class _LightRaysPainter extends CustomPainter {
  final double time;
  final Offset sun;
  _LightRaysPainter({required this.time, required this.sun});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(sun.dx, sun.dy);
    const n = 7;
    final len = size.height * 0.95;
    for (int i = 0; i < n; i++) {
      // Aşağıya doğru açılan yelpaze + nazik salınım
      final a =
          pi / 2 + (i - (n - 1) / 2) * 0.19 + sin(time * 0.25 + i) * 0.025;
      final width = 42.0 + (i % 3) * 22.0;
      final alpha = i.isEven ? 0.028 : 0.016;
      final ex = cos(a) * len, ey = sin(a) * len;
      final path = Path()
        ..moveTo(0, 0)
        ..lineTo(ex - width, ey)
        ..lineTo(ex + width, ey)
        ..close();
      final shader = ui.Gradient.linear(Offset.zero, Offset(ex, ey), [
        Color.fromRGBO(255, 224, 160, alpha),
        const Color(0x00FFE0A0),
      ]);
      canvas.drawPath(
        path,
        Paint()
          ..shader = shader
          ..blendMode = BlendMode.plus
          // Kenarları yumuşat: keskin üçgenler "ışın" değil "üçgen" okunuyordu.
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LightRaysPainter o) => o.time != time || o.sun != sun;
}

// ─── Sabah sisi ──────────────────────────────────────────────────────────────

class _MorningMistPainter extends CustomPainter {
  final double time;
  _MorningMistPainter({required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final p = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);
    // Sis YUKARIDA, tepe eteğinde kalır: aşağı indikçe hızla söner. Ön plandaki
    // köylüyü sarmalayan sis "korku filmi" hissinin yarısıydı.
    for (int i = 0; i < 4; i++) {
      final y = h * (0.34 + i * 0.11);
      final drift = sin(time * 0.14 + i * 1.3) * w * 0.05;
      final a = (0.15 - i * 0.038).clamp(0.0, 1.0);
      p.color = Color.fromRGBO(246, 252, 250, a);
      final rect = Rect.fromCenter(
        center: Offset(w * 0.5 + drift, y),
        width: w * 1.25,
        height: 26 + i * 8.0,
      );
      canvas.drawRRect(RRect.fromRectXY(rect, 60, 60), p);
    }
  }

  @override
  bool shouldRepaint(_MorningMistPainter o) => o.time != time;
}

// ─── Uyanan kuşlar ───────────────────────────────────────────────────────────

/// Yüksekte gevşek V düzeninde, kanat çırparak yavaşça süzülen sabah kuşları.
class _WakingBirdsPainter extends CustomPainter {
  final double time;
  _WakingBirdsPainter({required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final baseX = (time * 10.0) % (w + 160) - 80;
    final baseY = size.height * 0.20;
    final stroke = Paint()
      ..color = const Color(0x5C2C4A5A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const offsets = [
      Offset(0, 0),
      Offset(-22, 10),
      Offset(22, 10),
      Offset(-44, 22),
      Offset(44, 22),
    ];
    for (int i = 0; i < offsets.length; i++) {
      final cx = baseX + offsets[i].dx;
      final cy = baseY + offsets[i].dy + sin(time * 0.3 + i) * 3;
      final flap = sin(time * 6.0 + i * 1.1) * 3.5;
      final path = Path()
        ..moveTo(cx - 7, cy + flap)
        ..quadraticBezierTo(cx, cy - 3, cx, cy)
        ..quadraticBezierTo(cx, cy - 3, cx + 7, cy + flap);
      canvas.drawPath(path, stroke);
    }
  }

  @override
  bool shouldRepaint(_WakingBirdsPainter o) => o.time != time;
}

// ─── Karşılayıcı köylü ───────────────────────────────────────────────────────

/// Ön planda seni bekleyen köylü. Kasten SİLÜET DEĞİL: kukuletasız, yüzü
/// görünen, giysisi renkli, sabah ışığını yiyen bir insan. (Önceki sürüm
/// kapkara cübbeli + kukuletalı + yüzsüz + fenerli + sisin içindeydi — hepsi
/// birebir korku ikonografisi; birlikte "hoş geldin" değil "kaç" diyorlardı.)
/// Elinde fener yerine ekmek sepeti var: karşılamanın nesnesi ışık değil, ikram.
class _WelcomerVillager extends StatelessWidget {
  final double time;

  /// Ekran yüksekliği — figür sabit pikselde kalırsa geniş ekranda kaybolur;
  /// ön plan olduğunu hissettirmesi için yükseklikle ölçeklenir.
  final double screenHeight;
  const _WelcomerVillager({required this.time, required this.screenHeight});

  static const _base = Size(172, 236);

  @override
  Widget build(BuildContext context) {
    final scale = (screenHeight * 0.30 / _base.height).clamp(0.78, 1.7);
    return CustomPaint(
      size: Size(_base.width * scale, _base.height * scale),
      painter: _WelcomerPainter(time: time, scale: scale),
    );
  }
}

class _WelcomerPainter extends CustomPainter {
  final double time;
  final double scale;
  _WelcomerPainter({required this.time, required this.scale});

  // Sabah güneşi SAĞDAN geliyor (bkz. _sunCenter) → sağ kenarlar sıcak açılır,
  // sol kenarlar hafif serinler. Hiçbir yerde saf siyah yok.
  static const _skinLit = Color(0xFFFFD9A8);
  static const _skinShade = Color(0xFFCE9268);
  static const _linenLit = Color(0xFFFBF1DC);
  static const _linenShade = Color(0xFFD3C3A6);
  static const _vestLit = Color(0xFFE0A44E);
  static const _vestShade = Color(0xFFA96E2E);
  static const _trouserLit = Color(0xFF7E9184);
  static const _trouserShade = Color(0xFF4E6058);
  static const _leather = Color(0xFF8A5A34);
  static const _hair = Color(0xFF4A3328);
  static const _rim = Color(0xFFFFE9C0);

  /// Soldan sağa (gölge → ışık) yatay gradyan — figürün her parçası aynı
  /// ışık yönünü paylaşsın diye tek yerden üretilir.
  Paint _lit(double left, double right, Color shade, Color lit) => Paint()
    ..shader = ui.Gradient.linear(Offset(left, 0), Offset(right, 0), [
      shade,
      lit,
    ]);

  @override
  void paint(Canvas canvas, Size size) {
    // Tüm geometri 172×236'lık taban kadraja göre yazıldı; ölçek tek yerden.
    canvas.save();
    canvas.scale(scale);
    final w = size.width / scale, h = size.height / scale;
    final breathe = sin(time * 1.3) * 1.4; // nefes bob'u
    final feetY = h - 10;
    final cx = w * 0.46;

    const headR = 14.0;
    final headC = Offset(cx, h * 0.20);
    final shoulderY = h * 0.30;
    final hipY = h * 0.585;

    canvas.save();
    canvas.translate(0, breathe);

    // ── Yer gölgesi (güneş sağdan → gölge sola düşer, sıcak-yeşil zemine)
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - 9, feetY + 3), width: 80, height: 16),
      Paint()
        ..color = const Color(0x4A16302C)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );

    // ── Bacaklar + çizmeler
    for (final dx in const [-14.0, 3.0]) {
      canvas.drawRRect(
        RRect.fromRectXY(
          Rect.fromLTWH(cx + dx, hipY - 4, 12, feetY - hipY + 4),
          4,
          4,
        ),
        _lit(cx + dx, cx + dx + 12, _trouserShade, _trouserLit),
      );
      canvas.drawRRect(
        RRect.fromRectXY(Rect.fromLTWH(cx + dx - 1, feetY - 14, 14, 14), 3, 3),
        _lit(cx + dx - 1, cx + dx + 13, const Color(0xFF3E3128), _leather),
      );
    }

    // ── Gövde: keten gömlek (omuzlar yuvarlak, bele doğru hafif daralır)
    final shirt = Path()
      ..moveTo(cx - 22, shoulderY + 5)
      ..quadraticBezierTo(cx - 21, shoulderY - 4, cx - 11, shoulderY - 6)
      ..lineTo(cx + 11, shoulderY - 6)
      ..quadraticBezierTo(cx + 21, shoulderY - 4, cx + 22, shoulderY + 5)
      ..lineTo(cx + 19, hipY)
      ..lineTo(cx - 19, hipY)
      ..close();
    canvas.drawPath(shirt, _lit(cx - 22, cx + 22, _linenShade, _linenLit));

    // ── Ochre yelek: göğüste V açıklığı bırakan iki panel
    for (final s in const [-1.0, 1.0]) {
      final panel = Path()
        ..moveTo(cx + s * 4, shoulderY - 4)
        ..lineTo(cx + s * 16, shoulderY - 3)
        ..lineTo(cx + s * 15, hipY + 2)
        ..lineTo(cx + s * 4, hipY + 2)
        ..lineTo(cx + s * 4, shoulderY + 16)
        ..close();
      canvas.drawPath(panel, _lit(cx - 16, cx + 16, _vestShade, _vestLit));
    }

    // ── Kemer
    canvas.drawRRect(
      RRect.fromRectXY(
        Rect.fromCenter(center: Offset(cx, hipY - 3), width: 42, height: 7),
        2,
        2,
      ),
      _lit(cx - 21, cx + 21, const Color(0xFF6B4326), _leather),
    );

    // ── Sepeti tutan kol (sol, aşağı-dışa)
    final basketHand = Offset(cx - 33, hipY - 8);
    canvas.drawPath(
      Path()
        ..moveTo(cx - 19, shoulderY + 4)
        ..quadraticBezierTo(
          cx - 31,
          shoulderY + 28,
          basketHand.dx,
          basketHand.dy,
        ),
      Paint()
        ..color = _linenShade
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(basketHand, 5.5, Paint()..color = _skinShade);

    // ── Selam veren kol (sağ, yukarı) — yavaş, geniş, dostane salınım
    final wave = sin(time * 2.2) * 0.26;
    final shoulder = Offset(cx + 19, shoulderY + 4);
    final elbow = Offset(cx + 33, shoulderY + 20);
    final hand = Offset(
      elbow.dx + cos(-1.35 + wave) * 34,
      elbow.dy + sin(-1.35 + wave) * 34,
    );
    canvas.drawPath(
      Path()
        ..moveTo(shoulder.dx, shoulder.dy)
        ..lineTo(elbow.dx, elbow.dy)
        ..lineTo(hand.dx, hand.dy),
      Paint()
        ..color = _linenLit
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    // Açık el — parmaklar ayrık değil ama avuç bize dönük, "merhaba" jesti
    canvas.drawCircle(hand, 6.0, Paint()..color = _skinLit);

    // ── Boyun
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(cx, headC.dy + headR - 1),
        width: 11,
        height: 10,
      ),
      Paint()..color = _skinShade,
    );

    // ── Baş
    canvas.drawCircle(
      headC,
      headR,
      _lit(headC.dx - headR, headC.dx + headR, _skinShade, _skinLit),
    );

    // ── Saç: tepeyi ve şakakları örten kısa kesim (kukuleta YOK)
    final hairPath = Path()
      ..moveTo(cx - headR, headC.dy + 1)
      ..quadraticBezierTo(
        cx - headR - 1,
        headC.dy - headR,
        cx,
        headC.dy - headR,
      )
      ..quadraticBezierTo(
        cx + headR + 1,
        headC.dy - headR,
        cx + headR,
        headC.dy + 1,
      )
      ..lineTo(cx + headR - 2, headC.dy - 2)
      ..quadraticBezierTo(cx, headC.dy - 9, cx - headR + 2, headC.dy - 2)
      ..close();
    canvas.drawPath(hairPath, Paint()..color = _hair);

    // ── Yüz: iki göz + yumuşak gülümseme + yanak allığı
    final eye = Paint()..color = const Color(0xFF3A2A22);
    canvas.drawCircle(Offset(cx - 5, headC.dy + 1.5), 1.7, eye);
    canvas.drawCircle(Offset(cx + 5, headC.dy + 1.5), 1.7, eye);
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, headC.dy + 4.5), width: 11, height: 8),
      pi * 0.18,
      pi * 0.64,
      false,
      Paint()
        ..color = const Color(0xFF8A5138)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7
        ..strokeCap = StrokeCap.round,
    );
    final blush = Paint()..color = const Color(0x4CE08A6A);
    canvas.drawCircle(Offset(cx - 8.5, headC.dy + 4), 2.6, blush);
    canvas.drawCircle(Offset(cx + 8.5, headC.dy + 4), 2.6, blush);

    // ── Ekmek sepeti (fenerin yerini alan nesne: ikram, ışık değil)
    final sway = sin(time * 1.4) * 1.6;
    final bx = basketHand.dx + sway, by = basketHand.dy + 20;
    final basket = Path()
      ..moveTo(bx - 15, by - 10)
      ..lineTo(bx + 15, by - 10)
      ..lineTo(bx + 11, by + 11)
      ..lineTo(bx - 11, by + 11)
      ..close();
    // Somunlar sepetin ağzından taşar
    for (final o in const [-7.0, 0.0, 7.0]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(bx + o, by - 13 + (o == 0 ? -2 : 0)),
          width: 11,
          height: 9,
        ),
        Paint()..color = const Color(0xFFE3B96E),
      );
    }
    canvas.drawPath(
      basket,
      _lit(bx - 15, bx + 15, const Color(0xFF8A5A2C), const Color(0xFFCE9450)),
    );
    // Örgü çizgileri
    final weave = Paint()
      ..color = const Color(0x593F2712)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    for (int i = 1; i <= 2; i++) {
      final t = i / 3.0;
      final yy = by - 10 + t * 21;
      final hw = 15 - t * 4;
      canvas.drawLine(Offset(bx - hw, yy), Offset(bx + hw, yy), weave);
    }
    // Sap
    canvas.drawArc(
      Rect.fromCenter(center: Offset(bx, by - 10), width: 26, height: 20),
      pi,
      pi,
      false,
      Paint()
        ..color = const Color(0xFF8A5A2C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );

    // ── Rim-light: güneş sağdan, kenarları ince ve sıcak öper (abartısız)
    void rimStroke(Path p, double alpha, double width) => canvas.drawPath(
      p,
      Paint()
        ..color = _rim.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
    rimStroke(
      Path()..addArc(
        Rect.fromCircle(center: headC, radius: headR),
        -pi * 0.48,
        pi * 0.62,
      ),
      0.75,
      2.0,
    );
    rimStroke(
      Path()
        ..moveTo(cx + 22, shoulderY + 5)
        ..lineTo(cx + 19, hipY),
      0.45,
      1.8,
    );
    rimStroke(
      Path()
        ..moveTo(elbow.dx, elbow.dy)
        ..lineTo(hand.dx, hand.dy),
      0.55,
      1.4,
    );

    canvas.restore(); // nefes bob'u
    canvas.restore(); // ölçek
  }

  @override
  bool shouldRepaint(_WelcomerPainter o) => o.time != time || o.scale != scale;
}
