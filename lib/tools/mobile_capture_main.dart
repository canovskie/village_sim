// MOBİL EKRAN OTOMASYONU — oyun ekranını GERÇEK telefon ölçülerinde sürer.
//
// Neden: mobilde kalan iş UI cilası (taşma / minik yazı / küçük dokunma hedefi /
// HUD yerleşimi). Bunları gerçek cihaza deploy edip gözle aramak yavaş; burada
// aynı VillageScene, telefonun MANTIKSAL ölçüsünde + çentik padding'iyle
// masaüstünde koşar, harness sentetik parmak olaylarıyla ekranı sürer ve her
// adımda hem PNG hem SAYISAL denetim üretir.
//
// Ne ölçer (kare başına):
//   • OVERFLOW   — RenderFlex/RenderBox taşma hataları (FlutterError kancası)
//   • OFFSCREEN  — telefon çerçevesinin dışına taşan yazı/dokunma hedefi
//                  (kaydırılabilir alanlar hariç tutulur)
//   • TAP<44     — 44dp altında kalan dokunma hedefleri (Apple HIG eşiği)
//   • FONT<11    — 11px altında kalan yazılar, boyuta göre gruplu
//
// NOT: mobil YATAY kilitli (bkz. systems/platform_adapt.dart) — profiller de
// yatay ölçüdedir. Köy = REFERANS KÖY (sabit tohum) → koşular kıyaslanabilir.
//
// Çalıştır:  flutter run -d macos -t lib/tools/mobile_capture_main.dart
// Çıktı:     preview/mobile/<cihaz>_<adım>.png + report.json + stdout özeti
// Env:       OUT=<dizin>  DEVICES=iphone15,small  STEPS=01_hud,13_ledger_divan
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../buildings/building_type.dart';
import '../ui/app_ui.dart';
import '../ui/village_ledger.dart';
import '../main.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Cihaz profilleri — hepsi YATAY (oyun yatay kilitli)
// ─────────────────────────────────────────────────────────────────────────────

class Phone {
  final String id;
  final String label;

  /// Mantıksal (dp) ölçü — yatay yönde.
  final double w, h;
  final double dpr;

  /// Çentik/ada + gezinme çubuğu güvenli alanı (yatay yönde).
  final EdgeInsets safe;

  const Phone(this.id, this.label, this.w, this.h, this.dpr, this.safe);
}

const _allDevices = <Phone>[
  // REFERANS CİHAZ — mobil tasarım önce buna göre kurulur, diğerleri sonra
  // buna uyarlanır. Geniş çentik (yatayda 44dp) + 414dp yükseklik.
  Phone(
    'iphone11',
    'iPhone 11',
    896,
    414,
    2.0,
    EdgeInsets.only(left: 44, right: 44, bottom: 21),
  ),
  // Çentikli amiral gemisi — yanlardan 59dp yeniyor, HUD'ın en sıkıştığı yer.
  Phone(
    'iphone15',
    'iPhone 15',
    852,
    393,
    3.0,
    EdgeInsets.only(left: 59, right: 59, bottom: 21),
  ),
  // Çentiksiz küçük iPhone — en dar YÜKSEKLİK (375dp): alt komuta çubuğu +
  // üst HUD şeridi arasında oyun alanı kalıyor mu?
  Phone('iphone_se', 'iPhone SE', 667, 375, 2.0, EdgeInsets.zero),
  // Delik-kamera Android — tek yanda kesim.
  Phone(
    'pixel7',
    'Pixel 7',
    915,
    412,
    2.625,
    EdgeInsets.only(left: 34, bottom: 24),
  ),
  // En kötü durum: ucuz/eski Android. Bir şey taşacaksa burada taşar.
  Phone('small', 'Küçük Android', 640, 360, 3.0, EdgeInsets.only(bottom: 20)),
  // Tablet — ters uç: panel oranları esneyip dağılıyor mu?
  Phone('ipad', 'iPad', 1180, 820, 2.0, EdgeInsets.only(bottom: 20)),
];

/// Apple HIG dokunma hedefi eşiği (Material 48 der; 44 muhafazakâr alt sınır).
const double kTapMin = 44.0;

/// Telefonda okunabilirlik alt sınırı.
const double kFontMin = 11.0;

// ─────────────────────────────────────────────────────────────────────────────
// Harness iskeleti
// ─────────────────────────────────────────────────────────────────────────────

final GlobalKey _frameKey = GlobalKey();
final GlobalKey _sceneKey = GlobalKey();
final ValueNotifier<Phone> _phone = ValueNotifier<Phone>(_allDevices.first);

/// O anki adımda toplanan taşma hataları (adım başına temizlenir).
final List<String> _overflowErrors = <String>[];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  kCaptureMode = true; // açılış sinematiği + ses motoru yok
  _installErrorHook();

  // İlk cihazla AÇ: sahne bir ölçüde kurulup sonra yeniden boyutlanırsa
  // ilk karede eski layout'un izi kalabiliyor.
  final devices = _selectedDevices();
  _phone.value = devices.first;

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ValueListenableBuilder<Phone>(
        valueListenable: _phone,
        builder: (_, d, _) => ColoredBox(
          color: const Color(0xFF0B0C0E),
          child: Center(
            // FittedBox: pencere telefondan küçük/büyük olsa da çerçeve TAM
            // mantıksal ölçüsünde layout olur (ui_gallery ile aynı hile).
            // Hit-test transform'u FittedBox taşır → localToGlobal ile ürettiğimiz
            // dokunuş koordinatları kendiliğinden doğru yere düşer.
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: d.w,
                height: d.h,
                // MediaQuery MaterialApp'in İÇİNDE: WidgetsApp kendi
                // MediaQuery.fromView'ını en dışta kurar, onu ezmemiz gerekir.
                child: MediaQuery(
                  data: MediaQueryData(
                    size: Size(d.w, d.h),
                    devicePixelRatio: d.dpr,
                    padding: d.safe,
                    viewPadding: d.safe,
                    textScaler: TextScaler.noScaling,
                  ),
                  child: RepaintBoundary(
                    key: _frameKey,
                    child: VillageScene(
                      key: _sceneKey,
                      referenceVillage:
                          true, // sabit tohum → kıyaslanabilir koşu
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  stdout.writeln('MOBILE: ${devices.length} cihaz × ${_script().length} adım');

  await _waitReady();

  final report = <Map<String, dynamic>>[];
  for (final d in devices) {
    _phone.value = d;
    await _pump(40); // relayout + kamera otursun
    report.add(await _runDevice(d));
  }

  await _writeReport(report);
  _printSummary(report);
  exit(0);
}

List<Phone> _selectedDevices() {
  final only = Platform.environment['DEVICES'];
  if (only == null || only.trim().isEmpty) return _allDevices;
  final ids = only.split(',').map((s) => s.trim()).toSet();
  final sel = _allDevices.where((d) => ids.contains(d.id)).toList();
  return sel.isEmpty ? _allDevices : sel;
}

String get _outDir => Platform.environment['OUT'] ?? 'preview/mobile';

void _installErrorHook() {
  final prev = FlutterError.onError;
  FlutterError.onError = (details) {
    final s = details.exceptionAsString();
    if (s.contains('overflowed') || s.contains('RenderFlex')) {
      _overflowErrors.add(s.split('\n').first.trim());
      return; // konsolu boğmasın; rapora zaten yazıyoruz
    }
    prev?.call(details);
  };
}

Future<void> _waitReady() async {
  var waited = 0;
  while (!kCaptureSceneReady && waited < 500) {
    await _pump(18); // ~300ms — kare zorlayarak bekle (yükleme ekranı da aksın)
    waited++;
  }
  await _pump(120); // referans köy kurulsun, kamera otursun
}

/// Oyun ekranını kapatan şeyleri geç. Sim canlı akıyor: araya eskalasyon
/// sinematiği ("Atla ▸") girebiliyor, önceki adım Defter/Dev Panel açık
/// bırakmış olabiliyor. Temizlenmezse SONRAKİ bütün adımlar sessizce ıskalar —
/// koşunun yarısını kaybettiren tuzak buydu.
Future<void> _ensureClean(Phone d, {bool closeLedger = true}) async {
  for (var i = 0; i < 8; i++) {
    final skip = _textCenter('Atla', exact: false);
    if (skip != null) {
      await _tap(skip);
      await _pump(24);
      continue;
    }
    if (_rectOfType('DevPanel') != null) {
      final x = _closeIconCenter();
      if (x == null) break;
      await _tap(x);
      await _pump(10);
      continue;
    }
    if (closeLedger && _rectOfType('VillageLedger') != null) {
      await _tap(_local(Offset(4, d.h * 0.5))); // perde = kapat
      await _pump(10);
      continue;
    }
    return;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sentetik parmak
// ─────────────────────────────────────────────────────────────────────────────

int _ptr = 1;

/// Kare zaman damgası — MOTORUN saatiyle aynı eksende ve DAİMA artan.
/// Kendi Stopwatch'ımızı kullanmak ölümcül: SchedulerBinding ilk kareyi epoch
/// başlangıcı sayar, sonraki damga daha küçük gelirse currentFrameTimeStamp
/// GERİ gider → AnimationController "elapsedInSeconds >= 0" assert'i patlar,
/// yarım kalan geçişler ekranda donuk katman bırakır.
Duration _rawTs = Duration.zero;
Duration get _ts => _rawTs;

/// KARE ZORLA — macOS penceresi arkadaysa/gizliyse işletim sistemi vsync
/// göndermez, hiçbir frame çizilmez ve harness ilk karede DONAR (eski
/// capture araçlarının "pencere arkadaysa kare üretilmez" tuzağı).
/// Burada frame'i elle sürüyoruz: build+layout+paint çalışır, ticker tick atar.
/// toImage layer ağacını doğrudan rasterize ettiği için ekrana composite
/// edilmese de kare doğru çıkar.
void _forceFrame() {
  final b = WidgetsBinding.instance;
  if (b.schedulerPhase != SchedulerPhase.idle) return;
  // Motor arada kendi karesini çizdiyse onun damgasını yakala, sonra ilerlet.
  try {
    final engine = b.currentSystemFrameTimeStamp;
    if (engine > _rawTs) _rawTs = engine;
  } catch (_) {
    // Henüz hiç kare çizilmedi — sıfırdan başla.
  }
  _rawTs += const Duration(milliseconds: 16);
  b.handleBeginFrame(_rawTs);
  b.handleDrawFrame();
}

Future<void> _pump([int frames = 2]) async {
  for (var i = 0; i < frames; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 16));
    _forceFrame();
  }
}

void _send(PointerEvent e) => GestureBinding.instance.handlePointerEvent(e);

Future<void> _tap(Offset p) async {
  final id = _ptr++;
  _send(
    PointerDownEvent(
      pointer: id,
      position: p,
      kind: PointerDeviceKind.touch,
      buttons: kPrimaryButton,
      timeStamp: _ts,
    ),
  );
  await _pump(3);
  _send(
    PointerUpEvent(
      pointer: id,
      position: p,
      kind: PointerDeviceKind.touch,
      timeStamp: _ts,
    ),
  );
  await _pump(8);
}

/// Tarama dokunuşu — 96 nokta denenirken tam _tap maliyeti çok pahalı.
Future<void> _tapQuick(Offset p) async {
  final id = _ptr++;
  _send(
    PointerDownEvent(
      pointer: id,
      position: p,
      kind: PointerDeviceKind.touch,
      buttons: kPrimaryButton,
      timeStamp: _ts,
    ),
  );
  await _pump(2);
  _send(
    PointerUpEvent(
      pointer: id,
      position: p,
      kind: PointerDeviceKind.touch,
      timeStamp: _ts,
    ),
  );
  await _pump(3);
}

Future<void> _drag(Offset from, Offset to, {int steps = 12}) async {
  final id = _ptr++;
  var cur = from;
  _send(
    PointerDownEvent(
      pointer: id,
      position: from,
      kind: PointerDeviceKind.touch,
      buttons: kPrimaryButton,
      timeStamp: _ts,
    ),
  );
  await _pump(2);
  for (var i = 1; i <= steps; i++) {
    final next = Offset.lerp(from, to, i / steps)!;
    _send(
      PointerMoveEvent(
        pointer: id,
        position: next,
        delta: next - cur,
        kind: PointerDeviceKind.touch,
        buttons: kPrimaryButton,
        timeStamp: _ts,
      ),
    );
    cur = next;
    await _pump(1);
  }
  _send(
    PointerUpEvent(
      pointer: id,
      position: cur,
      kind: PointerDeviceKind.touch,
      timeStamp: _ts,
    ),
  );
  await _pump(6);
}

/// İki parmakla açma/kapama — kamera zoom'u (onScaleUpdate) sürer.
Future<void> _pinch(
  Offset center,
  double fromGap,
  double toGap, {
  int steps = 14,
}) async {
  final a = _ptr++;
  final b = _ptr++;
  Offset left(double gap) => center - Offset(gap / 2, 0);
  Offset right(double gap) => center + Offset(gap / 2, 0);

  var la = left(fromGap), rb = right(fromGap);
  for (final (id, pos) in [(a, la), (b, rb)]) {
    _send(
      PointerDownEvent(
        pointer: id,
        position: pos,
        kind: PointerDeviceKind.touch,
        buttons: kPrimaryButton,
        timeStamp: _ts,
      ),
    );
  }
  await _pump(2);
  for (var i = 1; i <= steps; i++) {
    final gap = fromGap + (toGap - fromGap) * (i / steps);
    final na = left(gap), nr = right(gap);
    _send(
      PointerMoveEvent(
        pointer: a,
        position: na,
        delta: na - la,
        kind: PointerDeviceKind.touch,
        buttons: kPrimaryButton,
        timeStamp: _ts,
      ),
    );
    _send(
      PointerMoveEvent(
        pointer: b,
        position: nr,
        delta: nr - rb,
        kind: PointerDeviceKind.touch,
        buttons: kPrimaryButton,
        timeStamp: _ts,
      ),
    );
    la = na;
    rb = nr;
    await _pump(1);
  }
  _send(
    PointerUpEvent(
      pointer: a,
      position: la,
      kind: PointerDeviceKind.touch,
      timeStamp: _ts,
    ),
  );
  _send(
    PointerUpEvent(
      pointer: b,
      position: rb,
      kind: PointerDeviceKind.touch,
      timeStamp: _ts,
    ),
  );
  await _pump(6);
}

// ─────────────────────────────────────────────────────────────────────────────
// Ağaç sorguları — "şu yazıya dokun" gibi ölçüden BAĞIMSIZ hedefleme
// ─────────────────────────────────────────────────────────────────────────────

RenderBox get _frameBox =>
    _frameKey.currentContext!.findRenderObject()! as RenderBox;

List<Element> _allElements({String? within}) {
  final out = <Element>[];
  void rec(Element e) {
    out.add(e);
    e.visitChildren(rec);
  }

  final ctx = _frameKey.currentContext;
  if (ctx is! Element) return out;
  if (within == null) {
    rec(ctx);
    return out;
  }
  // Alt ağaca kısıtla — aynı yazı iki yerde olabiliyor (komuta çubuğundaki
  // "NÜFUS" kapısı ile Defter'in "NÜFUS" bölüm başlığı gibi).
  Element? root;
  void find(Element e) {
    if (root != null) return;
    if (e.widget.runtimeType.toString() == within) {
      root = e;
      return;
    }
    e.visitChildren(find);
  }

  find(ctx);
  final r = root;
  if (r != null) rec(r);
  return out;
}

RenderBox? _visible(Element e) {
  final ro = e.findRenderObject();
  if (ro is! RenderBox || !ro.attached || !ro.hasSize) return null;
  if (ro.size.isEmpty) return null;
  return ro;
}

/// Ekran dışına (ya da clip'in dışına) düşen bir hedefe parmak DEĞMEZ —
/// harness de dokunmuş saymamalı, yoksa sessizce hiçbir şey olmaz.
Offset? _tappablePoint(RenderBox ro) {
  final p = ro.localToGlobal(ro.size.center(Offset.zero));
  final frame = _frameBox;
  final local = frame.globalToLocal(p);
  final bounds = Offset.zero & frame.size;
  return bounds.contains(local) ? p : null;
}

/// Ekranda görünen bir yazının merkezini (global koordinat) verir.
Offset? _textCenter(String needle, {bool exact = true, String? within}) {
  for (final e in _allElements(within: within)) {
    final w = e.widget;
    final s = w is Text ? w.data : null;
    if (s == null) continue;
    final t = s.trim();
    if (exact ? t != needle : !t.contains(needle)) continue;
    final ro = _visible(e);
    if (ro == null) continue;
    final p = _tappablePoint(ro);
    if (p != null) return p;
  }
  return null;
}

/// Widget tipini ADIYLA bulur — private widget'lar (_BuildingTile) için.
Offset? _typeCenter(String typeName, {int index = 0}) {
  var seen = 0;
  for (final e in _allElements()) {
    if (e.widget.runtimeType.toString() != typeName) continue;
    final ro = _visible(e);
    if (ro == null) continue;
    final p = _tappablePoint(ro);
    if (p == null) continue; // clip dışında kalan kart — dokunulamaz
    if (seen++ != index) continue;
    return p;
  }
  return null;
}

/// Kapatma ikonuna dokunur (paneller GameIconData.close kullanır).
Offset? _closeIconCenter() {
  for (final e in _allElements()) {
    final w = e.widget;
    if (w is! GameIcon || w.icon != GameIconData.close) continue;
    final ro = _visible(e);
    if (ro == null) continue;
    final p = _tappablePoint(ro);
    if (p != null) return p;
  }
  return null;
}

Offset _local(Offset frameLocal) => _frameBox.localToGlobal(frameLocal);

/// Dünyanın üstündeki UI'ın kapladığı çerçeve-yerel dikdörtgenler: alanı
/// çerçevenin %35'inden küçük olan her dokunma hedefi. Dünya canvas'ı bu
/// eşiğin üstünde kaldığı için listeye girmez.
List<Rect> _smallTapRects(Phone d) {
  final frame = _frameBox;
  final maxArea = d.w * d.h * 0.35;
  final out = <Rect>[];
  for (final e in _allElements()) {
    final w = e.widget;
    final tappable =
        (w is GestureDetector && w.onTap != null) ||
        (w is InkWell && w.onTap != null);
    if (!tappable) continue;
    final ro = _visible(e);
    if (ro == null) continue;
    if (ro.size.width * ro.size.height > maxArea) continue;
    try {
      out.add(ro.localToGlobal(Offset.zero, ancestor: frame) & ro.size);
    } catch (_) {
      continue;
    }
  }
  return out;
}

/// Bir widget'ın çerçeve-yerel dikdörtgeni — "buraya dokunma" bölgeleri için.
Rect? _rectOfType(String typeName) {
  for (final e in _allElements()) {
    if (e.widget.runtimeType.toString() != typeName) continue;
    final ro = _visible(e);
    if (ro == null) continue;
    try {
      return ro.localToGlobal(Offset.zero, ancestor: _frameBox) & ro.size;
    } catch (_) {
      return null;
    }
  }
  return null;
}

// ─────────────────────────────────────────────────────────────────────────────
// Adım listesi — oyun ekranını sürer
// ─────────────────────────────────────────────────────────────────────────────

typedef StepRun = Future<String?> Function(Phone d);

class Step {
  final String id;
  final String note;
  final StepRun run;

  /// Adım öncesi Köy Defteri de kapatılsın mı? Defter adımları kendi
  /// açtıkları paneli kapatmamalı — onlar için false.
  final bool closeLedger;
  const Step(this.id, this.note, this.run, {this.closeLedger = true});
}

/// Dünya alanının merkezi — üst HUD şeridi ve alt komuta çubuğunun arası.
Offset _worldCenter(Phone d) => _local(Offset(d.w * 0.5, d.h * 0.42));

/// İnşa rafı yatay kayıyor ve kaydığı yerde kalıyor — cihaz değişiminde
/// (geniş → dar) kategori sekmeleri görüş dışına itiliyor. Kategoriye dokunmadan
/// önce rafı başa sar.
Future<void> _resetPalette(Phone d) async {
  final y = d.h - 26;
  await _drag(_local(Offset(d.w * 0.12, y)), _local(Offset(d.w * 0.62, y)));
}

/// Kategori sekmesine dokun — sekme rafın hangi ucunda olursa olsun.
/// Son kategori (Arazi/Yol) başa sarınca görüş dışında kalıyor, o yüzden
/// bulunamazsa raf ters yöne sarılıp bir kez daha denenir.
Future<String?> _tapCategory(Phone d, BuildCategory cat) async {
  final label = cat.label.toUpperCase();
  if (_textCenter(label) == null) {
    final open = await _tapText('İNŞA');
    if (open != null) return open;
    await _pump(12);
  }
  await _resetPalette(d);
  if (await _tapText(label) == null) return null;
  final y = d.h - 26;
  await _drag(_local(Offset(d.w * 0.62, y)), _local(Offset(d.w * 0.12, y)));
  return _tapText(label);
}

Future<String?> _tapText(
  String label, {
  bool exact = true,
  String? within,
}) async {
  final p = _textCenter(label, exact: exact, within: within);
  if (p == null) return 'bulunamadı: "$label"';
  await _tap(p);
  return null;
}

List<Step> _script() => <Step>[
  Step('01_hud', 'Sade oyun ekranı — HUD + dünya', (d) async => null),

  Step('02_pan', 'Dünyayı parmakla kaydır', (d) async {
    final c = _worldCenter(d);
    await _drag(c, c + Offset(-d.w * 0.28, -d.h * 0.12));
    return null;
  }),

  Step('03_zoom_out', 'İki parmakla uzaklaş', (d) async {
    await _pinch(_worldCenter(d), d.w * 0.34, d.w * 0.14);
    return null;
  }),

  Step('04_zoom_in', 'İki parmakla yakınlaş', (d) async {
    await _pinch(_worldCenter(d), d.w * 0.14, d.w * 0.40);
    return null;
  }),

  Step('05_build_konut', 'İnşa paleti — Konut', (d) async {
    return _tapCategory(d, BuildCategory.konut);
  }),

  Step('06_build_uretim', 'İnşa paleti — Üretim (en kalabalık raf)', (d) async {
    return _tapCategory(d, BuildCategory.uretim);
  }),

  Step('07_build_arazi', 'Arazi/Yol araçları', (d) async {
    return _tapCategory(d, BuildCategory.araziYol);
  }),

  Step('08_place_mode', 'Bina seçili — yerleştirme bağlamı', (d) async {
    final skip = await _tapCategory(d, BuildCategory.konut);
    if (skip != null) return skip;
    // Kartlar sırayla denenir: kaynağı yetmeyen / zanaatı bilinmeyen bina
    // seçilmez, ilk kart hep tutmaz. "Vazgeç" belirdiyse mod açılmıştır.
    for (var i = 0; i < 8; i++) {
      final tile = _typeCenter('_BuildingTile', index: i);
      if (tile == null) break;
      await _tap(tile);
      if (_textCenter('Vazgeç') != null) return null;
    }
    return 'yerleştirme moduna girilemedi';
  }),

  Step('09_cancel', 'Yerleştirmeden vazgeç', (d) async {
    return _tapText('Vazgeç');
  }),

  Step('10_npc_select', 'Köylüye/binaya dokun (isabet taraması)', (d) async {
    // Hedefin ekran konumu dışarıdan bilinemez → dünyayı ızgarayla tarayıp
    // "Detay" bağlam eylemi belirene kadar dener.
    //
    // TUZAK: HUD/görev takipçisi/Menü/komuta çubuğu dünyanın ÜSTÜNDE
    // duruyor. Tarama onlardan birine denk gelirse Defter ya da Dev Panel
    // açılır, kalan bütün dokunuşlar perdeye çarpar — tarama sessizce boşa
    // döner. İsim isim saymak yerine kural: KÜÇÜK dokunma hedefi olan her
    // yer yasak. (Dünya canvas'ı da bir GestureDetector, ama o kocaman —
    // eşiğin üstünde kaldığı için elenmiyor.)
    // 02'deki kaydırmayı geri al: kamera köyün üstüne dönsün, yoksa tarama
    // boş araziyi tarar.
    final c = _worldCenter(d);
    await _drag(c, c + Offset(d.w * 0.28, d.h * 0.12));

    for (var pass = 0; pass < 2; pass++) {
      // İkinci geçiş yakınlaşarak: hedefler büyür, ızgara aralığından
      // kaçamazlar.
      if (pass == 1) await _pinch(c, d.w * 0.16, d.w * 0.44);
      final blocked = _smallTapRects(d);
      const cols = 14, rows = 10;
      for (var gy = 0; gy < rows; gy++) {
        for (var gx = 0; gx < cols; gx++) {
          final local = Offset(
            d.w * (0.06 + gx * (0.88 / (cols - 1))),
            d.h * (0.14 + gy * (0.72 / (rows - 1))),
          );
          if (blocked.any((r) => r.inflate(6).contains(local))) continue;
          await _tapQuick(_local(local));
          if (_textCenter('Detay') != null) return null;
          if (_rectOfType('VillageLedger') != null) {
            await _tap(_local(Offset(4, d.h * 0.5))); // yanlışlıkla açıldı
          }
        }
      }
    }
    return 'isabet ettirilemedi';
  }),

  Step('11_npc_detail', 'Köylü paneli (tam ayrıntı)', (d) async {
    return _tapText('Detay');
  }),

  Step('12_npc_close', 'Paneli kapat', (d) async {
    final p = _closeIconCenter();
    if (p == null) return 'kapat ikonu yok';
    await _tap(p);
    return null;
  }),

  // Komuta çubuğu kapıları etiketi BÜYÜK HARFE çevirerek çiziyor.
  Step('13_ledger_divan', 'Köy Defteri — Divan', (d) async {
    return _tapText('Divan'.toUpperCase());
  }),

  // Bölüm başlıkları Defter'in İÇİNDE aranır: "NÜFUS" hem komuta çubuğunda
  // hem bölüm rafında var, kısıtlamazsak yanlış hedefe dokunur.
  Step('14_ledger_kanun', 'Köy Defteri — Kanunname', (d) async {
    return _tapText(LedgerSection.kanun.label, within: 'VillageLedger');
  }, closeLedger: false),

  Step('15_ledger_nufus', 'Köy Defteri — Nüfus', (d) async {
    return _tapText(LedgerSection.nufus.label, within: 'VillageLedger');
  }, closeLedger: false),

  Step('16_ledger_tuzuk', 'Köy Defteri — Tüzük', (d) async {
    return _tapText(LedgerSection.tuzuk.label, within: 'VillageLedger');
  }, closeLedger: false),

  Step('17_ledger_kronik', 'Köy Defteri — Kronik', (d) async {
    return _tapText(LedgerSection.kronik.label, within: 'VillageLedger');
  }, closeLedger: false),

  Step('18_ledger_close', 'Defteri kapat (boşluğa dokun)', (d) async {
    // Defter çerçevesi ekranın %95'i → sol kenarda scrim kalır.
    await _tap(_local(Offset(4, d.h * 0.5)));
    return null;
  }),
];

// ─────────────────────────────────────────────────────────────────────────────
// Koşu
// ─────────────────────────────────────────────────────────────────────────────

Future<Map<String, dynamic>> _runDevice(Phone d) async {
  final only = (Platform.environment['STEPS'] ?? '')
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toSet();

  final steps = <Map<String, dynamic>>[];
  for (final step in _script()) {
    if (only.isNotEmpty && !only.contains(step.id)) continue;
    // Adım TEMİZ ekranda başlasın — sim canlı, araya sinematik/panel girebilir.
    await _ensureClean(d, closeLedger: step.closeLedger);
    _overflowErrors.clear();
    String? skip;
    try {
      skip = await step.run(d);
    } catch (e) {
      skip = 'hata: $e';
    }
    await _pump(6);

    final audit = _audit(d);
    final png = '${d.id}_${step.id}.png';
    await _capture(d, png);

    steps.add(<String, dynamic>{
      'id': step.id,
      'note': step.note,
      'png': png,
      'skipped': ?skip,
      'overflow': _overflowErrors.toSet().toList(),
      'offscreen': audit.offscreen.map((h) => h.toJson()).toList(),
      'tapTargets': audit.smallTaps.map((h) => h.toJson()).toList(),
      'tinyText': audit.tinyText.map((h) => h.toJson()).toList(),
    });
    stdout.writeln(
      '  ${d.id}/${step.id}'
      '${skip != null ? "  SKIP($skip)" : ""}'
      '  of:${_overflowErrors.length}'
      ' off:${audit.offscreen.length}'
      ' tap:${audit.smallTaps.length}'
      ' font:${audit.tinyText.length}',
    );
  }
  return <String, dynamic>{
    'device': d.id,
    'label': d.label,
    'size': [d.w, d.h],
    'dpr': d.dpr,
    'safe': [d.safe.left, d.safe.top, d.safe.right, d.safe.bottom],
    'steps': steps,
  };
}

Future<void> _capture(Phone d, String name) async {
  final boundary = _frameKey.currentContext?.findRenderObject();
  if (boundary is! RenderRepaintBoundary) return;
  final image = await boundary.toImage(pixelRatio: d.dpr);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (bytes == null) return;
  final dir = Directory(_outDir);
  if (!dir.existsSync()) dir.createSync(recursive: true);
  await File('${dir.path}/$name').writeAsBytes(bytes.buffer.asUint8List());
}

// ─────────────────────────────────────────────────────────────────────────────
// Denetim — kareye bakmadan SAYI üretir
// ─────────────────────────────────────────────────────────────────────────────

class Hit {
  final String label;
  final String detail;
  final Rect rect;
  const Hit(this.label, this.detail, this.rect);

  Map<String, dynamic> toJson() => {
    'label': label,
    'detail': detail,
    'rect': [
      rect.left.roundToDouble(),
      rect.top.roundToDouble(),
      rect.width.roundToDouble(),
      rect.height.roundToDouble(),
    ],
  };
}

class Audit {
  final List<Hit> offscreen = [];
  final List<Hit> smallTaps = [];
  final List<Hit> tinyText = [];
}

/// Kuşatan kaydırma alanının EKSENİ — yoksa null.
///
/// `RenderViewportBase.axis` yetmiyor: SingleChildScrollView'un render'ı
/// (`_RenderSingleChildViewport`) private ve RenderViewportBase DEĞİL, ama
/// `RenderAbstractViewport` uyguluyor. Oyunun inşa rafı tam olarak o —
/// yakalanmayınca yatay kaymış her kart "ekran dışı" diye raporlanıyordu.
/// Bütün viewport'lar `axisDirection` getter'ını taşıdığı için oradan okuruz.
Axis? _scrollAxisOf(RenderObject ro) {
  final vp = RenderAbstractViewport.maybeOf(ro);
  if (vp == null) return null;
  if (vp is RenderViewportBase) return vp.axis;
  try {
    final dir = (vp as dynamic).axisDirection;
    if (dir is AxisDirection) return axisDirectionToAxis(dir);
  } catch (_) {
    // Eksen okunamadı — muhafazakâr davran, taşmayı raporla.
  }
  return null;
}

Audit _audit(Phone d) {
  final a = Audit();
  final frame = _frameBox;
  final bounds = Offset.zero & frame.size;
  final seenTap = <String>{};
  final seenOff = <String>{};

  for (final e in _allElements()) {
    final ro = _visible(e);
    if (ro == null) continue;

    Rect rect;
    try {
      rect = ro.localToGlobal(Offset.zero, ancestor: frame) & ro.size;
    } catch (_) {
      continue;
    }
    // Tamamen dışarıdaki devasa kutular (kaydırma içeriği) ilgilendirmiyor.
    if (rect.width > d.w * 2 || rect.height > d.h * 2) continue;

    final w = e.widget;
    final tappable =
        (w is GestureDetector && w.onTap != null) ||
        (w is InkWell && w.onTap != null);

    // ── Dokunma hedefi ────────────────────────────────────────────────────
    if (tappable) {
      // Tam-ekran scrim'ler (kapat-için-boşluk) hedef değil.
      final isScrim = rect.width > d.w * 0.9 && rect.height > d.h * 0.9;
      if (!isScrim && (ro.size.width < kTapMin || ro.size.height < kTapMin)) {
        final label = _labelOf(e);
        final key = '$label@${rect.left.round()},${rect.top.round()}';
        if (seenTap.add(key)) {
          a.smallTaps.add(
            Hit(
              label,
              '${ro.size.width.round()}×${ro.size.height.round()}dp',
              rect,
            ),
          );
        }
      }
    }

    // ── Yazı boyu ─────────────────────────────────────────────────────────
    if (ro is RenderParagraph) {
      // ETKİN boy — bildirilen boy DEĞİL. Mobil tema 11px'lik tabanı ağacın
      // kökünde bir TextScaler ile uyguluyor (bkz. ui/mobile_ui.dart), yani
      // `style.fontSize` hâlâ 7.5 derken ekrana 11 çiziliyor. Bildirilen boya
      // bakan eski ölçüm bu yüzden hiç değişmiyordu ve düzelmiş bir şeyi
      // "hâlâ bozuk" diye raporluyordu.
      final declared = ro.text.style?.fontSize;
      final size = declared == null ? null : ro.textScaler.scale(declared);
      final text = ro.text.toPlainText().trim();
      if (size != null && size < kFontMin && text.isNotEmpty) {
        a.tinyText.add(
          Hit(
            text.length > 28 ? '${text.substring(0, 28)}…' : text,
            '${size.toStringAsFixed(1)}px',
            rect,
          ),
        );
      }
    }

    // ── Çerçeve dışına taşma ──────────────────────────────────────────────
    // Yalnız yazı ve dokunma hedefleri: layout kutularının taşması normal
    // (clip'lenir), ama OKUNACAK / DOKUNULACAK bir şeyin taşması hatadır.
    if (ro is RenderParagraph || tappable) {
      // Kaydırılabilir alanda taşma normaldir — ama YALNIZ kaydırma ekseninde.
      // Yatay kaydırılan bir rafın DİKEY taşması gerçek hatadır (inşa paleti
      // yatay kayar ama ekran altından taşarsa oyuncu göremez).
      final scrollAxis = _scrollAxisOf(ro);
      final ignoreX = scrollAxis == Axis.horizontal;
      final ignoreY = scrollAxis == Axis.vertical;

      final probe = Rect.fromLTRB(
        ignoreX ? bounds.left : rect.left,
        ignoreY ? bounds.top : rect.top,
        ignoreX ? bounds.right : rect.right,
        ignoreY ? bounds.bottom : rect.bottom,
      );
      final inside = bounds.intersect(probe);
      final area = probe.width * probe.height;
      final visible = (inside.isEmpty || area <= 0)
          ? 0.0
          : (inside.width * inside.height) / area;
      if (visible < 0.98) {
        final label =
            (ro is RenderParagraph ? ro.text.toPlainText() : _labelOf(e))
                .trim();
        if (label.isNotEmpty) {
          final key = '$label@${rect.left.round()},${rect.top.round()}';
          if (seenOff.add(key)) {
            a.offscreen.add(
              Hit(
                label.length > 28 ? '${label.substring(0, 28)}…' : label,
                visible <= 0.0
                    ? 'tamamen dışarıda'
                    : '%${((1 - visible) * 100).round()} kesik',
                rect,
              ),
            );
          }
        }
      }
    }
  }
  return a;
}

String _labelOf(Element e) {
  final found = <String>[];
  void rec(Element c) {
    if (found.isNotEmpty) return;
    final w = c.widget;
    if (w is Text) {
      final s = (w.data ?? '').trim();
      if (s.isNotEmpty) {
        found.add(s);
        return;
      }
    }
    c.visitChildren(rec);
  }

  e.visitChildren(rec);
  return found.isNotEmpty ? found.first : e.widget.runtimeType.toString();
}

// ─────────────────────────────────────────────────────────────────────────────
// Rapor
// ─────────────────────────────────────────────────────────────────────────────

Future<void> _writeReport(List<Map<String, dynamic>> report) async {
  final dir = Directory(_outDir);
  if (!dir.existsSync()) dir.createSync(recursive: true);
  await File('${dir.path}/report.json').writeAsString(
    const JsonEncoder.withIndent(
      '  ',
    ).convert({'tapMin': kTapMin, 'fontMin': kFontMin, 'devices': report}),
  );
}

void _printSummary(List<Map<String, dynamic>> report) {
  stdout.writeln('\n═══ MOBİL RAPOR ═══');
  for (final dev in report) {
    final steps = (dev['steps'] as List).cast<Map<String, dynamic>>();
    var of = 0, off = 0;
    final taps = <String, String>{};
    final fonts = <String, int>{};
    final skips = <String>[];
    final offList = <String>{};

    for (final s in steps) {
      of += (s['overflow'] as List).length;
      off += (s['offscreen'] as List).length;
      if (s['skipped'] != null) skips.add('${s['id']}: ${s['skipped']}');
      for (final h in (s['offscreen'] as List).cast<Map<String, dynamic>>()) {
        offList.add('${h['label']} (${h['detail']})');
      }
      for (final h in (s['tapTargets'] as List).cast<Map<String, dynamic>>()) {
        taps['${h['label']}'] = '${h['detail']}';
      }
      for (final h in (s['tinyText'] as List).cast<Map<String, dynamic>>()) {
        final px = '${h['detail']}';
        fonts[px] = (fonts[px] ?? 0) + 1;
      }
    }

    final size = (dev['size'] as List).map((e) => e.round()).join('×');
    stdout.writeln('\n▸ ${dev['label']}  ($size)');
    stdout.writeln('  OVERFLOW   $of');
    stdout.writeln('  OFFSCREEN  $off');
    for (final o in offList.take(6)) {
      stdout.writeln('             · $o');
    }
    stdout.writeln('  TAP<${kTapMin.round()}dp   ${taps.length} ayrı hedef');
    final tapList = taps.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    for (final t in tapList.take(8)) {
      stdout.writeln('             · ${t.key} — ${t.value}');
    }
    final fontKeys = fonts.keys.toList()..sort();
    final total = fonts.values.fold(0, (a, b) => a + b);
    stdout.writeln(
      '  FONT<${kFontMin.round()}px   $total görülme '
      '(${fontKeys.map((k) => "$k×${fonts[k]}").join(", ")})',
    );
    if (skips.isNotEmpty) {
      stdout.writeln('  ATLANAN    ${skips.length}');
      for (final s in skips) {
        stdout.writeln('             · $s');
      }
    }
  }
  stdout.writeln('\nKareler: $_outDir/  ·  Ayrıntı: $_outDir/report.json');
}
