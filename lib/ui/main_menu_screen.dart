import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../dev/animation_room.dart';
import '../main.dart' show kCaptureMode;
import '../rendering/flame_renderer.dart';
import '../save/save_manager.dart';
import '../systems/audio_manager.dart';
import '../tools/light_editor_main.dart';
import '../tools/placement_editor_main.dart';
import 'about_screen.dart';
import 'app_ui.dart';
import 'mobile_ui.dart';
import 'save_slots_screen.dart';
import 'settings_screen.dart';
import 'sky_widgets.dart';

part 'menu_scenery.dart';
part 'menu_widgets.dart';
part 'menu_dawn.dart';

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
