import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../characters/life_stage.dart';
import '../characters/npc_visual.dart';
import '../characters/villager_type.dart';
import '../cutscene/cutscene.dart';
import '../cutscene/cutscene_player.dart';
import '../rendering/character_renderer.dart';
import '../systems/imperial.dart';
import '../ui/app_ui.dart';

/// ANİMASYON ODASI — animasyonları canlı görmek ve kurcalamak için dev ekranı.
///
/// Neden var: sinematik/karakter animasyonlarını denemek için tek yol PNG çeken
/// capture harness'ıydı; her deneme birkaç dakika derleme demekti ve zamanda
/// yaşayan şeyleri (yürüyüş fazı, varış anı, idle nefesi, kamera hareketi) tek
/// karede görmek zaten mümkün değil. Burada her şey gerçek zamanlı akar,
/// yavaşlatılır, duraklatılır.
///
/// İki sekme:
///  - SAHNELER  : oyundaki GERÇEK sinematikler (kopya değil — aynı veriden
///                oynar, o yüzden sahnede yapılan düzeltme buraya da yansır)
///  - KARAKTER  : tek figür büyük; meslek/evre/poz/yürüyüş/taşıma/meşale
///                anahtarlarıyla CharacterRenderer'ın tüm hâlleri
class AnimationRoomScreen extends StatelessWidget {
  /// Açılışta hangi sekme (0 sahneler, 1 karakter).
  final int initialTab;
  const AnimationRoomScreen({super.key, this.initialTab = 0});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUi.surface0,
      body: SafeArea(
        child: Column(
          children: [
            _Header(onClose: () => Navigator.of(context).maybePop()),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                // AppTabs intrinsic panel için tasarlanmış: içerik Column
                // mainAxisSize.min + AnimatedSize içinde, yani SINIRSIZ
                // yükseklik alıyor. Buradaki sekmeler Expanded/ListView
                // kullandığı için öylece sıfıra çöküyordu (ekran bomboş
                // çıkıyordu). Kalan yüksekliği ölçüp içeriğe biz veriyoruz.
                child: LayoutBuilder(
                  builder: (_, c) {
                    final h = (c.maxHeight - _kTabBarH).clamp(220.0, 4000.0);
                    return AppTabs(initial: initialTab, tabs: [
                      ('SAHNELER', SizedBox(height: h, child: const _ScenesTab())),
                      ('KARAKTER', SizedBox(height: h, child: const _CharacterTab())),
                    ]);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// AppTabs'in sekme şeridi + altındaki boşluk (pill dikey padding 8+8 + yazı +
/// kenarlık + 12 px ara). İçeriğe kalan yüksekliği hesaplarken düşülür.
const double _kTabBarH = 46;

class _Header extends StatelessWidget {
  final VoidCallback onClose;
  const _Header({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 10),
      child: Row(
        children: [
          Text('ANİMASYON ODASI', style: AppUi.title),
          const SizedBox(width: 10),
          Expanded(
            child: Text('animasyonları canlı dene',
                style: AppUi.body.copyWith(color: AppUi.textLo)),
          ),
          GestureDetector(
            onTap: onClose,
            child: AppChip(label: '✕ Kapat', color: AppUi.accent),
          ),
        ],
      ),
    );
  }
}

// ── SAHNELER ────────────────────────────────────────────────────────────────

/// Odanın oynatabildiği sahne. [build] her seferinde çağrılır → sahne verisi
/// KOPYALANMAZ, oyundakiyle aynı kaynaktan kurulur.
class _SceneEntry {
  final String label;
  final String note;
  final Cutscene Function() build;
  const _SceneEntry(this.label, this.note, this.build);
}

/// Düğün/imparatorluk sahneleri gerçek oyun verisi ister; odada temsilî ama
/// AYNI kurucularla üretilir (metin/kadraj/kamera birebir oyundaki gibi).
List<_SceneEntry> _scenes() => [
      _SceneEntry('Açılış', 'kuruluş filmi · tilt + kadraj + adlandırma kapısı',
          () => kOpeningCutscene),
      _SceneEntry('İlk ateş (POV)', 'köyün ortak gözü · göz kapağı + komşu omuzları',
          () => kFireLightingCutscene),
      _SceneEntry('Kademe 1', 'kuşbakışı küçük köy + karşılama',
          () => cutsceneForTier(1)!),
      _SceneEntry('Kademe 2', 'kuşbakışı büyüyen köy + pazar',
          () => cutsceneForTier(2)!),
      _SceneEntry('Kademe 3 (final)', 'kuşbakışı dolu köy + başlık kartı',
          () => cutsceneForTier(3)!),
      _SceneEntry('Kıtlık', 'kuşbakışı boş tarlalar + akşam', () => kFamineCutscene),
      _SceneEntry('Düğün', 'gerçek çifte göre kurulur · ateş közü gecesi',
          () => weddingCutscene(
                brideType: VillagerType.farmer,
                brideVisual: NpcVisual.fromSeed(24),
                brideName: 'Ayşe',
                groomType: VillagerType.blacksmith,
                groomVisual: NpcVisual.fromSeed(51),
                groomName: 'Musa',
              )),
      _SceneEntry('İmparatorluk · altın', 'düşman ton (itibar 0.2) · yakın plan',
          () => imperialArrivalCutscene(
              const ImperialDemand(ImperialDemandKind.goldTax, 40),
              favor: 0.2,
              seed: 7)),
      _SceneEntry('İmparatorluk · devşirme', 'ek tehdit çekimi (dostane ton)',
          () => imperialArrivalCutscene(
              const ImperialDemand(ImperialDemandKind.conscript, 1),
              favor: 0.8,
              seed: 3)),
    ];

class _ScenesTab extends StatefulWidget {
  const _ScenesTab();
  @override
  State<_ScenesTab> createState() => _ScenesTabState();
}

class _ScenesTabState extends State<_ScenesTab> {
  late final List<_SceneEntry> _list = _scenes();
  int _sel = 0;
  int _epoch = 0; // artınca oynatıcı sıfırdan kurulur (başa sar)
  bool _paused = false;
  double _speed = 1.0;
  int _shot = 0;
  double _elapsed = 0;
  int _shotCount = 1;
  double _lastReadout = -1; // göstergeyi ~10 Hz tazele (her kare değil)

  /// Kurulmuş sahne — her karede yeniden kurulmaz. (Düğün/imparatorluk
  /// sahneleri kurucu fonksiyonlar; her karede çağırmak boşuna iş.)
  late Cutscene _cutscene = _list[_sel].build();

  void _reload({int? select}) => setState(() {
        if (select != null) _sel = select;
        _epoch++;
        _shot = 0;
        _elapsed = 0;
        _lastReadout = -1;
        _cutscene = _list[_sel].build();
      });

  @override
  Widget build(BuildContext context) {
    final entry = _list[_sel];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 210,
          child: ListView.builder(
            padding: const EdgeInsets.only(right: 10, top: 2),
            itemCount: _list.length,
            itemBuilder: (_, i) {
              final s = _list[i];
              final on = i == _sel;
              return GestureDetector(
                onTap: () => _reload(select: i),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: on ? AppUi.surface2 : AppUi.surface1,
                    borderRadius: BorderRadius.circular(AppUi.radiusSm),
                    border: Border.all(
                        color: on ? AppUi.accent : AppUi.line, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.label,
                          style: AppUi.bodyHi.copyWith(
                              color: on ? AppUi.accent : AppUi.textHi)),
                      const SizedBox(height: 3),
                      Text(s.note,
                          style: AppUi.label.copyWith(color: AppUi.textLo)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppUi.radiusSm),
                  child: Container(
                    color: Colors.black,
                    child: CutscenePlayer(
                      // Sahne + epoch birlikte anahtar → seçim/başa sar sıfırlar.
                      key: ValueKey('${entry.label}#$_epoch'),
                      cutscene: _cutscene,
                      loop: true,
                      paused: _paused,
                      timeScale: _speed,
                      onProgress: (shot, elapsed, count) {
                        // Gösterge PARENT'ta; oynatıcının kendi setState'i
                        // burayı tazelemez. Her kare setState etmek yerine
                        // ~10 Hz'de bir tazeleriz (okunabilirlik için yeterli,
                        // sahneyi gereksiz yere yeniden kurmaz).
                        if (!mounted) return;
                        _shot = shot;
                        _shotCount = count;
                        if ((elapsed - _lastReadout).abs() < 0.1) return;
                        _lastReadout = elapsed;
                        setState(() => _elapsed = elapsed);
                      },
                      onDone: () {},
                      onNameChosen: (_) {},
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _transport(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _transport() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppUi.surface1,
        borderRadius: BorderRadius.circular(AppUi.radiusSm),
        border: Border.all(color: AppUi.line),
      ),
      child: Row(
        children: [
          _btn(_paused ? '▶ Oynat' : '⏸ Duraklat',
              () => setState(() => _paused = !_paused),
              on: _paused),
          const SizedBox(width: 8),
          _btn('↺ Başa', _reload),
          const SizedBox(width: 16),
          for (final s in const [0.25, 0.5, 1.0, 2.0]) ...[
            _btn('${s == 1.0 ? '1' : s}×', () => setState(() => _speed = s),
                on: _speed == s),
            const SizedBox(width: 6),
          ],
          const Spacer(),
          Text(
            'çekim ${_shot + 1}/$_shotCount · t=${_elapsed.toStringAsFixed(1)}s',
            style: AppUi.label.copyWith(color: AppUi.textMid),
          ),
        ],
      ),
    );
  }
}

Widget _btn(String label, VoidCallback onTap, {bool on = false}) {
  return GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: on ? AppUi.accent.withValues(alpha: 0.18) : AppUi.surface2,
        borderRadius: BorderRadius.circular(AppUi.radiusSm),
        border: Border.all(color: on ? AppUi.accent : AppUi.line),
      ),
      child: Text(label,
          style: AppUi.button
              .copyWith(color: on ? AppUi.accent : AppUi.textMid)),
    ),
  );
}

// ── KARAKTER ────────────────────────────────────────────────────────────────

class _CharacterTab extends StatefulWidget {
  const _CharacterTab();
  @override
  State<_CharacterTab> createState() => _CharacterTabState();
}

class _CharacterTabState extends State<_CharacterTab>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _time = 0;

  int _typeIdx = 0;
  LifeStage _stage = LifeStage.adult;
  CharPose _pose = CharPose.normal;
  NpcCostume _costume = NpcCostume.none;
  bool _walking = true;
  bool _carrying = false;
  bool _flip = false;
  bool _commander = false;
  bool _attacking = false;
  bool _sleeping = false;
  double _torch = 0.0;
  double _speed = 1.0;
  int _seed = 7;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((el) {
      final dt = ((el - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
      _last = el;
      setState(() => _time += dt * _speed);
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppUi.radiusSm),
            child: Container(
              color: const Color(0xFF11161F),
              child: CustomPaint(
                painter: _CharPainter(
                  type: VillagerType.values[_typeIdx],
                  stage: _stage,
                  pose: _pose,
                  costume: _costume,
                  walking: _walking,
                  carrying: _carrying,
                  flip: _flip,
                  commander: _commander,
                  attacking: _attacking,
                  sleeping: _sleeping,
                  torch: _torch,
                  time: _time,
                  seed: _seed,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(width: 250, child: _controls()),
      ],
    );
  }

  Widget _controls() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cycle('MESLEK', VillagerType.values[_typeIdx].name,
              () => setState(() => _typeIdx =
                  (_typeIdx + 1) % VillagerType.values.length)),
          _cycle('EVRE', _stage.name, () {
            final v = LifeStage.values;
            setState(() => _stage = v[(v.indexOf(_stage) + 1) % v.length]);
          }),
          _cycle('POZ', _pose.name, () {
            const v = CharPose.values;
            setState(() => _pose = v[(v.indexOf(_pose) + 1) % v.length]);
          }),
          _cycle('KOSTÜM', _costume.name, () {
            const v = NpcCostume.values;
            setState(() => _costume = v[(v.indexOf(_costume) + 1) % v.length]);
          }),
          _cycle('GÖRSEL KİMLİK', 'seed $_seed',
              () => setState(() => _seed = (_seed + 13) % 997)),
          const SizedBox(height: 10),
          _toggle('yürüyor', _walking, (v) => _walking = v),
          _toggle('taşıyor', _carrying, (v) => _carrying = v),
          _toggle('aynala (flip)', _flip, (v) => _flip = v),
          _toggle('uyuyor', _sleeping, (v) => _sleeping = v),
          _toggle('komutan', _commander, (v) => _commander = v),
          _toggle('saldırı pozu', _attacking, (v) => _attacking = v),
          const SizedBox(height: 10),
          _slider('MEŞALE', _torch, 0, 1, (v) => _torch = v),
          _slider('HIZ', _speed, 0.1, 2.5, (v) => _speed = v),
          const SizedBox(height: 8),
          Text(
            'Not: duygu/mood gövde dili entity katmanında (game_painter) '
            'uygulanıyor, CharacterRenderer parametresi değil — burada yok.',
            style: AppUi.label.copyWith(color: AppUi.textLo),
          ),
        ],
      ),
    );
  }

  Widget _cycle(String label, String value, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: AppUi.surface1,
            borderRadius: BorderRadius.circular(AppUi.radiusSm),
            border: Border.all(color: AppUi.line),
          ),
          child: Row(
            children: [
              Expanded(
                  child: Text(label,
                      style: AppUi.label.copyWith(color: AppUi.textLo))),
              Text(value, style: AppUi.bodyHi.copyWith(color: AppUi.accent)),
              const SizedBox(width: 6),
              Text('▸', style: AppUi.body.copyWith(color: AppUi.textMid)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toggle(String label, bool value, void Function(bool) set) {
    return GestureDetector(
      onTap: () => setState(() => set(!value)),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Text(value ? '☑' : '☐',
                style: AppUi.body
                    .copyWith(color: value ? AppUi.accent : AppUi.textLo)),
            const SizedBox(width: 8),
            Text(label,
                style: AppUi.body
                    .copyWith(color: value ? AppUi.textHi : AppUi.textMid)),
          ],
        ),
      ),
    );
  }

  Widget _slider(String label, double value, double min, double max,
      void Function(double) set) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label  ${value.toStringAsFixed(2)}',
            style: AppUi.label.copyWith(color: AppUi.textLo)),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: AppUi.accent,
            inactiveTrackColor: AppUi.line,
            thumbColor: AppUi.accent,
            overlayShape: SliderComponentShape.noOverlay,
            trackHeight: 3,
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: (v) => setState(() => set(v)),
          ),
        ),
      ],
    );
  }
}

class _CharPainter extends CustomPainter {
  final VillagerType type;
  final LifeStage stage;
  final CharPose pose;
  final NpcCostume costume;
  final bool walking, carrying, flip, commander, attacking, sleeping;
  final double torch, time;
  final int seed;
  _CharPainter({
    required this.type,
    required this.stage,
    required this.pose,
    required this.costume,
    required this.walking,
    required this.carrying,
    required this.flip,
    required this.commander,
    required this.attacking,
    required this.sleeping,
    required this.torch,
    required this.time,
    required this.seed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Zemin çizgisi + ölçek ızgarası — pozların ayağı yerden kaçıyor mu, kafa
    // taşıyor mu buradan okunur (asıl işi bu: hata GÖRÜNSÜN).
    final baseY = size.height * 0.78;
    final grid = Paint()
      ..color = const Color(0x1AFFFFFF)
      ..strokeWidth = 1;
    for (double y = baseY; y > 0; y -= 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    canvas.drawLine(Offset(0, baseY), Offset(size.width, baseY),
        Paint()
          ..color = const Color(0x59FFFFFF)
          ..strokeWidth = 1.5);

    final s = (size.height * 0.55) / 90.0;
    canvas.save();
    canvas.translate(size.width / 2, baseY);
    canvas.scale(s, s);
    if (sleeping) {
      CharacterRenderer.drawSleeping(canvas, type,
          walkPhase: time * 3.0, flipX: flip);
    } else {
      CharacterRenderer.draw(
        canvas,
        type,
        flipX: flip,
        // Yürüyüş fazı: gerçek NPC'deki gibi zamana bağlı; idle'da da faz akar
        // (idle nefes/sway _Anim'de TAMAMEN faza bağlı — 0 verilirse heykel).
        walkPhase: walking ? time * 7.0 : time * 1.3,
        moveIntensity: walking ? 1.0 : 0.0,
        carrying: carrying,
        pose: pose,
        torchLevel: torch,
        torchPhase: seed * 0.7,
        visual: NpcVisual.fromSeed(seed),
        time: time,
        stage: stage,
        costume: costume,
        commander: commander,
        attacking: attacking,
      );
    }
    canvas.restore();

    // Ölçek etiketi.
    final tp = TextPainter(
      text: TextSpan(
          text: '${(90 * s).round()} px',
          style: const TextStyle(color: Color(0x8CFFFFFF), fontSize: 11)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(10, baseY + 8));
  }

  @override
  bool shouldRepaint(covariant _CharPainter old) => true;
}

/// Dev konsolundan/menüden açmak için kısayol.
void openAnimationRoom(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const AnimationRoomScreen()),
  );
}

/// Odanın kendi başına çalışan sürümü için kök widget (bkz.
/// lib/tools/animation_room_main.dart) — köy yüklemeden açılır.
class AnimationRoomApp extends StatelessWidget {
  const AnimationRoomApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(brightness: Brightness.dark),
        home: const AnimationRoomScreen(),
      );
}
