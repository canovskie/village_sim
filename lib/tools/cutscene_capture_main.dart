import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../characters/villager_type.dart';
import '../cutscene/cutscene.dart';
import '../cutscene/cutscene_player.dart';

/// 2B sinematik capture harness — oynatıcıyı gerçek fontlarla kurar ve
/// BELİRLİ ZAMAN DAMGALARINDA kare çeker. Galeri harness'ı sinematikten tek bir
/// kare alıyor; oysa buradaki işlerin çoğu ZAMANDA yaşıyor (yürüyüş fazı, varış,
/// idle nefes, konuşmacı kısma, parallax pan). Her kare ayrı bir oynatıcı
/// örneğidir: sahne baştan başlar, istenen saniyeye kadar kare pompalanır.
///
///   flutter run -d macos -t lib/tools/cutscene_capture_main.dart
///
/// Çıktı: preview/cutscene/*.png  (OUT ile değiştirilebilir)
///
/// TUZAK (bkz. proje hafızası): macOS'ta pencere ön planda değilken motor kare
/// üretmez — kareler elde pompalanır (_settle), yoksa hepsi aynı çıkar.

const double _w = 760;
const double _h = 428;

/// Tek kare talebi: sahne + kaçıncı saniyede yakalanacağı.
class Frame {
  final String id;
  final String note;
  final Cutscene cutscene;
  final double at; // sinematik başından itibaren saniye
  const Frame(this.id, this.note, this.cutscene, this.at);
}

// ── Test bobinleri — gerçek sahnelerden kesilmiş tek çekimler ────────────────

/// Kafile yürüyüşü (açılış çekim 2): mesafeler kasten çok farklı → ayak kayması
/// ve varış sıralaması burada görünür.
const Cutscene _reelWalk = Cutscene([
  CutsceneShot(
    bg: CutsceneBg.road,
    panFrom: 0.0,
    panTo: 0.05,
    tiltFrom: -0.10,
    tiltTo: 0.0,
    zoomFrom: 1.0,
    zoomTo: 1.05,
    actors: [
      // NOT: gerçek açılış çekimiyle birebir aynı olmalı (cutscene.dart) —
      // bobin eskirse düzeltilen staging karede görünmez.
      CutsceneActor(type: VillagerType.guard, seed: 21, fromX: -0.85, toX: 0.18, y: 0.86, scale: 1.2, walk: true),
      CutsceneActor(type: VillagerType.merchant, seed: 3, fromX: -0.62, toX: 0.34, y: 0.80, scale: 1.05, walk: true),
      CutsceneActor(type: VillagerType.farmer, seed: 12, fromX: -0.42, toX: 0.50, y: 0.82, scale: 1.1, walk: true),
      CutsceneActor(type: VillagerType.priest, seed: 7, fromX: -0.22, toX: 0.68, y: 0.78, scale: 1.0, walk: true),
    ],
    lines: [
      CutsceneLine('Günlerce yürüdüler. Yaşlılar arabada, çocuklar arkada, bir de topal keçi.'),
    ],
  ),
]);

/// Şafak + Maple: idle nefes/sway, ışık huzmeleri, zemin sisi, ön plan otları.
const Cutscene _reelDawn = Cutscene([
  CutsceneShot(
    bg: CutsceneBg.valleyDawn,
    zoomFrom: 1.0,
    zoomTo: 1.05,
    panFrom: 0.0,
    panTo: 0.05,
    actors: [
      CutsceneActor(type: VillagerType.priest, name: 'Maple', seed: 7, fromX: 0.42, y: 0.80, scale: 1.6),
    ],
    lines: [
      CutsceneLine('Ben Maple. Bu kafileyi yıllardır ben yürütüyorum.', speaker: 'Maple'),
    ],
  ),
]);

/// İmparatorluk: sağdan giren kolon + komutan konuşurken diğerlerinin kısılması.
const Cutscene _reelImperial = Cutscene([
  CutsceneShot(
    bg: CutsceneBg.valleyDusk,
    panFrom: 0.04,
    panTo: 0.0,
    zoomFrom: 1.02,
    zoomTo: 1.08,
    actors: [
      CutsceneActor(type: VillagerType.guard, name: 'Komutan', seed: 31, fromX: 1.25, toX: 0.60, y: 0.84, scale: 1.35, flip: true, walk: true),
      CutsceneActor(type: VillagerType.guard, seed: 44, fromX: 1.5, toX: 0.42, y: 0.80, scale: 1.1, flip: true, walk: true),
      CutsceneActor(type: VillagerType.guard, seed: 52, fromX: 1.75, toX: 0.26, y: 0.86, scale: 1.25, flip: true, walk: true),
    ],
    lines: [
      CutsceneLine('Toz bulutu yola oturdu. Ateş başındakiler ayağa kalktı.'),
      CutsceneLine('Bu köy defterde kayıtlı. Kayıtlı olan öder.', speaker: 'Komutan'),
    ],
  ),
]);

/// Gece ateşi: köz yükselişi, yıldız dağılımı, sıcak hâle.
const Cutscene _reelFire = Cutscene([
  CutsceneShot(
    bg: CutsceneBg.fireNight,
    zoomFrom: 1.10,
    zoomTo: 1.0,
    actors: [
      CutsceneActor(type: VillagerType.farmer, seed: 12, fromX: 0.36, y: 0.80, scale: 1.4, flip: true),
      CutsceneActor(type: VillagerType.priest, name: 'Maple', seed: 7, fromX: 0.64, y: 0.80, scale: 1.45),
    ],
    lines: [
      CutsceneLine('Ateşe fazladan odun attılar. Köy halka oldu, ortada iki kişi kaldı.'),
      CutsceneLine('Otur, ısın. Yarından sonrası sana kalmış.', speaker: 'Maple'),
    ],
  ),
]);

/// Kuşbakışı — izometrik yüksek açı, köy büyüdükçe yoğunlaşır.
const Cutscene _reelAerialSmall = Cutscene([
  CutsceneShot(
    bg: CutsceneBg.aerial,
    aerialGrowth: 0.30,
    framing: CutsceneFraming.wide,
    zoomFrom: 1.0,
    zoomTo: 1.08,
    lines: [CutsceneLine('Ocaklar çoğaldı. Patika, gide gele yola dönüştü.')],
  ),
]);

const Cutscene _reelAerialBig = Cutscene([
  CutsceneShot(
    bg: CutsceneBg.aerial,
    aerialGrowth: 1.0,
    framing: CutsceneFraming.wide,
    zoomFrom: 1.0,
    zoomTo: 1.12,
    lines: [CutsceneLine('Ambarlar kışa hazır. İlk gelen çocuklar şimdi kendi çocuklarını taşıyor.')],
  ),
]);

/// POV — köyün ortak gözü: halkanın içinden bakış, göz kapağı açılışı.
const Cutscene _reelPov = Cutscene([
  CutsceneShot(
    bg: CutsceneBg.fireNight,
    pov: true,
    tiltFrom: 0.06,
    tiltTo: -0.02,
    zoomFrom: 1.14,
    zoomTo: 1.0,
    actors: [
      CutsceneActor(type: VillagerType.farmer, seed: 12, fromX: 0.30, y: 0.80, scale: 1.2, flip: true),
      CutsceneActor(type: VillagerType.priest, name: 'Maple', seed: 7, fromX: 0.70, y: 0.80, scale: 1.25),
    ],
    lines: [
      CutsceneLine('Çıra tutuştu. İlk kez halka olduk; eller ateşe uzandı, kimse ilk sözü söylemedi.'),
      CutsceneLine('Oturun, ısının. Yarından sonrası size kalmış.', speaker: 'Maple'),
    ],
  ),
]);

List<Frame> buildFrames() => const [
      Frame('walk_0', 'tilt: kamera gökten iniyor', _reelWalk, 0.9),
      Frame('walk_1', 'kafile yürürken (erken — hepsi yolda)', _reelWalk, 1.5),
      Frame('walk_2', 'ön sıra vardı, arka sıra hâlâ yürüyor', _reelWalk, 3.0),
      Frame('walk_3', 'varış + anlatı (idle nefes)', _reelWalk, 6.5),
      Frame('dawn_1', 'ORTA plan: ayak basma noktası kutunun üstünde', _reelDawn, 2.2),
      Frame('dawn_2', 'şafak: pan ilerlemiş (parallax)', _reelDawn, 5.5),
      Frame('imperial_1', 'kolon girerken (sola bakıyor mu)', _reelImperial, 1.8),
      Frame('imperial_2', 'komutan konuşurken (diğerleri kısık)', _reelImperial, 7.5),
      Frame('fire_1', 'gece ateşi: alev + közler', _reelFire, 3.0),
      Frame('fire_2', 'ateş ışığı aktörlerin üstünde', _reelFire, 7.0),
      Frame('aerial_1', 'KUŞBAKIŞI: küçük köy', _reelAerialSmall, 3.0),
      Frame('aerial_2', 'KUŞBAKIŞI: büyümüş köy', _reelAerialBig, 5.0),
      Frame('pov_0', 'POV: göz kapağı açılırken', _reelPov, 0.16),
      Frame('pov_1', 'POV: halkanın içinden (komşu omuzları)', _reelPov, 3.5),
    ];

final GlobalKey _boundary = GlobalKey();
final GlobalKey<_HarnessState> _harness = GlobalKey<_HarnessState>();

class _Harness extends StatefulWidget {
  final List<Frame> frames;
  const _Harness({super.key, required this.frames});
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  int _i = -1;
  int _epoch = 0;

  /// Sahneyi SIFIRDAN kurar (epoch → yeni key → yeni ticker → t=0).
  void mount(int i) => setState(() {
        _i = i;
        _epoch++;
      });

  @override
  Widget build(BuildContext context) {
    if (_i < 0) return const ColoredBox(color: Color(0xFF07080A));
    final f = widget.frames[_i];
    return ColoredBox(
      color: const Color(0xFF07080A),
      child: Center(
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: _w,
            height: _h,
            child: MediaQuery(
              data: const MediaQueryData(
                size: Size(_w, _h),
                devicePixelRatio: 1,
                textScaler: TextScaler.noScaling,
                platformBrightness: Brightness.dark,
              ),
              child: RepaintBoundary(
                key: _boundary,
                child: KeyedSubtree(
                  key: ValueKey('${f.id}#$_epoch'),
                  child: CutscenePlayer(cutscene: f.cutscene, onDone: _noop),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void _noop() {}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (d) => stdout.writeln('FLUTTER_ERROR: ${d.exception}');

  final frames = buildFrames();
  final outDir = Directory(Platform.environment['OUT'] ?? 'preview/cutscene')
    ..createSync(recursive: true);

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: _Harness(key: _harness, frames: frames),
  ));

  await _settle(700); // font + ilk kare
  for (int i = 0; i < frames.length; i++) {
    final f = frames[i];
    _harness.currentState!.mount(i);
    // Sahne t=0'dan başlar; istenen saniyeye kadar kare pompalanır.
    await _settle((f.at * 1000).round());
    final bytes = await _grab();
    if (bytes != null) {
      File('${outDir.path}/${f.id}.png').writeAsBytesSync(bytes);
    }
    stdout.writeln('[${i + 1}/${frames.length}] '
        '${bytes == null ? 'FAIL' : 'OK  '} ${f.id} @${f.at}s — ${f.note}');
  }
  stdout.writeln('CUTSCENE_DONE → ${outDir.path}');
  exit(0);
}

final Stopwatch _clock = Stopwatch()..start();

/// İstenen kadar GERÇEK süre bekler ve bu sırada kare pompalar.
///
/// İki tuzak birden var:
///  1) Pencere ön planda değilse motor kare üretmez → elde pompalamak şart,
///     yoksa bütün kareler t=0 çıkar (proje hafızasındaki capture tuzağı).
///  2) Zaman damgası GERÇEK saatten gelmeli. Sentetik 16 ms'lik saat denendi;
///     motor ön plandayken kendi vsync karelerini de ürettiği için iki saat
///     karışıyor ve sahne istenenin iki katı hızla akıyordu (yürüyüş kareleri
///     "çoktan varmış" çıkıyordu). Sabit ADIM SAYISI yerine gerçek süreye
///     kadar döneriz — sahne saati gerçek saatle birebir akar.
Future<void> _settle(int ms) async {
  final target = _clock.elapsed + Duration(milliseconds: ms);
  while (_clock.elapsed < target) {
    await Future<void>.delayed(const Duration(milliseconds: 8));
    final b = WidgetsBinding.instance;
    if (b.schedulerPhase == SchedulerPhase.idle) {
      b.handleBeginFrame(_clock.elapsed);
      b.handleDrawFrame();
    }
  }
}

Future<Uint8List?> _grab() async {
  final ctx = _boundary.currentContext;
  if (ctx == null) return null;
  final b = ctx.findRenderObject() as RenderRepaintBoundary;
  final img = await b.toImage(pixelRatio: 1.0);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  return data?.buffer.asUint8List();
}
