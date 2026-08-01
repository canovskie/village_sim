// IŞIK PASS'İ MALİYET ÖLÇÜMÜ — "yarı çözünürlük blur gerçekten kazandırıyor mu?"
//
// game_painter'ın gece ışıklandırması üç TAM EKRAN saveLayer + ImageFilter.blur
// (σ6 / σ8 / σ18) kullanıyor. Retina bir pencerede maliyeti piksel sayısıyla
// ölçekleniyor ve FPS denetiminde en büyük tek yük olarak işaretlendi.
// Bilinen çare: maskeyi YARI çözünürlükte rasterize edip 2× büyütmek (blur
// zaten yumuşattığı için fark gözle görünmez, piksel sayısı ~4× düşer).
//
// Ama bu, KİLİTLİ bir görsel katman. Dokunmadan önce ölçmek şart:
// tahminle değil sayıyla karar verilir.
//
// ÖLÇÜM YÖNTEMİ: `PictureRecorder`'a çizmek hiçbir şey ölçmez (yalnız komut
// kaydeder, blur GPU'da rasterizasyonda çalışır). Bu yüzden her kare
// `picture.toImage()` ile GERÇEKTEN rasterize edilir; ölçülen süre budur.
//
// Çalıştır:  flutter run -d macos -t lib/tools/light_bench_main.dart
// Çıktı:     stdout (ms/kare, iki yöntem)
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Retina bir oyun penceresinin yaklaşık kare tamponu.
const int _w = 2560;
const int _h = 1600;
const int _frames = 40;
const int _lights = 26; // yoğun bir gece köyü

class _Light {
  final double x, y, r;
  const _Light(this.x, this.y, this.r);
}

List<_Light> _makeLights() {
  final rnd = Random(7);
  return [
    for (var i = 0; i < _lights; i++)
      _Light(rnd.nextDouble() * _w, rnd.nextDouble() * _h,
          60 + rnd.nextDouble() * 90),
  ];
}

/// Tek bir ışık halkasının radial gradient'i — game_painter'daki 7 duraklı
/// gradient birebir (maliyet profili aynı olsun diye).
Paint _lightPaint(_Light l, double radius, int alpha) {
  return Paint()
    ..shader = ui.Gradient.radial(
      Offset(l.x, l.y),
      radius,
      [
        Color.fromARGB(alpha, 0xFF, 0xE0, 0xB0),
        Color.fromARGB((alpha * 0.92).round(), 0xFF, 0xE0, 0xB0),
        Color.fromARGB((alpha * 0.71).round(), 0xFF, 0xE0, 0xB0),
        Color.fromARGB((alpha * 0.30).round(), 0xFF, 0xE0, 0xB0),
        Color.fromARGB((alpha * 0.08).round(), 0xFF, 0xE0, 0xB0),
        Color.fromARGB((alpha * 0.02).round(), 0xFF, 0xE0, 0xB0),
        const Color(0x00FFE0B0),
      ],
      const [0.0, 0.15, 0.30, 0.50, 0.70, 0.85, 1.0],
    );
}

/// BUGÜNKÜ YOL — üç tam ekran saveLayer, her biri kendi blur'u ile.
void _paintFullRes(Canvas canvas, List<_Light> lights) {
  final rect = Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble());
  canvas.saveLayer(rect, Paint());
  canvas.drawRect(rect, Paint()..color = const Color(0xCC0A1024));

  for (final (sigma, blend, rMul, alpha) in [
    (6.0, BlendMode.dstOut, 0.45, 130),
    (8.0, BlendMode.plus, 0.55, 55),
    (18.0, BlendMode.plus, 1.7, 28),
  ]) {
    canvas.saveLayer(
        rect,
        Paint()
          ..blendMode = blend
          ..imageFilter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma));
    for (final l in lights) {
      final r = l.r * rMul;
      canvas.drawCircle(Offset(l.x, l.y), r, _lightPaint(l, r, alpha));
    }
    canvas.restore();
  }
  canvas.restore();
}

/// ÖNERİLEN YOL — ışık maskeleri YARI çözünürlükte ayrı bir resme rasterize
/// edilir, sonra 2× büyütülerek kompozit edilir. Blur sigma'sı da yarılanır
/// (yarı çözünürlükte σ/2, tam çözünürlükte σ ile aynı yayılımı verir).
void _paintHalfRes(Canvas canvas, List<_Light> lights) {
  final rect = Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble());
  canvas.saveLayer(rect, Paint());
  canvas.drawRect(rect, Paint()..color = const Color(0xCC0A1024));

  for (final (sigma, blend, rMul, alpha) in [
    (6.0, BlendMode.dstOut, 0.45, 130),
    (8.0, BlendMode.plus, 0.55, 55),
    (18.0, BlendMode.plus, 1.7, 28),
  ]) {
    // 1) Maskeyi yarı ölçekte kaydet.
    final rec = ui.PictureRecorder();
    final c2 = Canvas(rec);
    c2.scale(0.5);
    c2.saveLayer(
        rect,
        Paint()
          ..imageFilter =
              ui.ImageFilter.blur(sigmaX: sigma / 2, sigmaY: sigma / 2));
    for (final l in lights) {
      final r = l.r * rMul;
      c2.drawCircle(Offset(l.x, l.y), r, _lightPaint(l, r, alpha));
    }
    c2.restore();
    final pic = rec.endRecording();
    // 2) Yarı çözünürlükte GERÇEK raster.
    final img = pic.toImageSync((_w / 2).round(), (_h / 2).round());
    // 3) 2× büyüterek kompozit — blur zaten yumuşattığı için upscale görünmez.
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      rect,
      Paint()
        ..blendMode = blend
        ..filterQuality = FilterQuality.low,
    );
    img.dispose();
    pic.dispose();
  }
  canvas.restore();
}

/// ÜÇÜNCÜ YOL — gradient'i her karede yeniden hesaplama, BİR KEZ dokuya piş.
///
/// İlk iki ölçüm blur'un tek suçlu olmadığını gösterdi: her karede 26 ışık × 3
/// pass = 78 radial gradient shader'ı kuruluyor ve rasterize ediliyor. Radial
/// gradient ışığın YARIÇAPINDAN bağımsız bir şekil (aynı 7 durak, yalnız ölçek
/// ve renk değişiyor) → tek bir gri tonlamalı dokuya pişirilip her ışık için
/// ölçeklenmiş quad olarak basılabilir. Renk `colorFilter`, şiddet `alpha` ile
/// gelir. Çözünürlük DÜŞMEZ, yani görsel risk yok.
ui.Image? _radialSprite;

Future<ui.Image> _bakeRadial() async {
  const s = 256;
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  const r = s / 2.0;
  c.drawCircle(
    const Offset(r, r),
    r,
    Paint()
      ..shader = ui.Gradient.radial(
        const Offset(r, r),
        r,
        [
          const Color(0xFFFFFFFF),
          const Color(0xEBFFFFFF),
          const Color(0xB5FFFFFF),
          const Color(0x4DFFFFFF),
          const Color(0x14FFFFFF),
          const Color(0x05FFFFFF),
          const Color(0x00FFFFFF),
        ],
        const [0.0, 0.15, 0.30, 0.50, 0.70, 0.85, 1.0],
      ),
  );
  final pic = rec.endRecording();
  final img = await pic.toImage(s, s);
  pic.dispose();
  return img;
}

void _paintSprite(Canvas canvas, List<_Light> lights) {
  final rect = Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble());
  final sprite = _radialSprite!;
  final src = Rect.fromLTWH(
      0, 0, sprite.width.toDouble(), sprite.height.toDouble());
  canvas.saveLayer(rect, Paint());
  canvas.drawRect(rect, Paint()..color = const Color(0xCC0A1024));

  for (final (sigma, blend, rMul, alpha) in [
    (6.0, BlendMode.dstOut, 0.45, 130),
    (8.0, BlendMode.plus, 0.55, 55),
    (18.0, BlendMode.plus, 1.7, 28),
  ]) {
    canvas.saveLayer(
        rect,
        Paint()
          ..blendMode = blend
          ..imageFilter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma));
    final p = Paint()
      ..filterQuality = FilterQuality.low
      ..colorFilter = ui.ColorFilter.mode(
          Color.fromARGB(alpha, 0xFF, 0xE0, 0xB0), BlendMode.modulate);
    for (final l in lights) {
      final r = l.r * rMul;
      canvas.drawImageRect(
          sprite, src, Rect.fromCircle(center: Offset(l.x, l.y), radius: r), p);
    }
    canvas.restore();
  }
  canvas.restore();
}

/// Gerçekçi köy dağılımı — ışıklar ekranın ORTASINDA kümelenir (köy merkezi),
/// tüm ekrana serpilmez. Bench'in ilk hâli en kötü durumu ölçüyordu.
List<_Light> _makeClustered() {
  final rnd = Random(11);
  const cx = _w * 0.5, cy = _h * 0.52;
  return [
    for (var i = 0; i < _lights; i++)
      _Light(cx + (rnd.nextDouble() - 0.5) * _w * 0.42,
          cy + (rnd.nextDouble() - 0.5) * _h * 0.36,
          60 + rnd.nextDouble() * 90),
  ];
}

/// DÖRDÜNCÜ YOL — çizim AYNI, yalnız `saveLayer` sınırı ışıkların kapladığı
/// kutuya (+ blur payı) daraltılır.
///
/// Bugün üç katman da TAM EKRAN tampon ayırıyor; oysa ışıklar köy merkezinde
/// kümelenmiş durumda ve blur lokal bir işlem. Sınırı daraltmak tek bir pikseli
/// bile değiştirmez (kutunun dışında zaten çizim yok), ama tampon alanı ve
/// blur'ın taradığı piksel sayısı doğrudan düşer. Çözünürlük düşürmenin aksine
/// GÖRSEL RİSKİ YOK — bu yüzden kilitli katman için doğru aday bu.
void _paintTightBounds(Canvas canvas, List<_Light> lights) {
  final rect = Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble());
  canvas.saveLayer(rect, Paint());
  canvas.drawRect(rect, Paint()..color = const Color(0xCC0A1024));

  for (final (sigma, blend, rMul, alpha) in [
    (6.0, BlendMode.dstOut, 0.45, 130),
    (8.0, BlendMode.plus, 0.55, 55),
    (18.0, BlendMode.plus, 1.7, 28),
  ]) {
    // Kutu: ışık yarıçapları + 3σ blur payı. 3σ, gauss'un görünür sınırı.
    var l0 = double.infinity, t0 = double.infinity;
    var r0 = -double.infinity, b0 = -double.infinity;
    for (final l in lights) {
      final r = l.r * rMul + sigma * 3;
      if (l.x - r < l0) l0 = l.x - r;
      if (l.y - r < t0) t0 = l.y - r;
      if (l.x + r > r0) r0 = l.x + r;
      if (l.y + r > b0) b0 = l.y + r;
    }
    final bounds = Rect.fromLTRB(l0, t0, r0, b0).intersect(rect);
    if (bounds.isEmpty) continue;

    canvas.saveLayer(
        bounds,
        Paint()
          ..blendMode = blend
          ..imageFilter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma));
    for (final l in lights) {
      final r = l.r * rMul;
      canvas.drawCircle(Offset(l.x, l.y), r, _lightPaint(l, r, alpha));
    }
    canvas.restore();
  }
  canvas.restore();
}

/// DÖNÜŞÜMLÜ A/B ÖLÇÜM — ardışık ölçüm bu makinede işe yaramıyor.
///
/// İlk denemede yöntemler peş peşe ölçüldü ve sonuçlar koşudan koşuya 2×
/// oynadı (aynı "dar sınır" bir koşuda 1.51× hızlı, diğerinde 0.50× yavaş
/// çıktı; taban 45.8 → 27.3 ms). Sebep: makinede paralel derleme/test var,
/// termal ve zamanlayıcı gürültüsü ölçülen farktan BÜYÜK. Ardışık ölçümde bu
/// gürültü tamamen bir yönteme yazılıyor.
///
/// Çözüm: kareler DÖNÜŞÜMLÜ koşulur (A,B,A,B...) → yavaşlama iki yönteme de
/// aynı oranda dağılır. Rapor ortalama değil MEDYAN ve MİN: medyan tek tük
/// sıçramaya dayanıklı, min ise "gürültüsüz hâlde ne kadar sürüyor"un en iyi
/// tahmini.
Future<void> _abBench(
    String labelA, void Function(Canvas) a,
    String labelB, void Function(Canvas) b,
    {int frames = 60}) async {
  final ta = <double>[], tb = <double>[];

  Future<double> once(void Function(Canvas) body) async {
    final sw = Stopwatch()..start();
    final rec = ui.PictureRecorder();
    body(Canvas(rec));
    final p = rec.endRecording();
    final im = await p.toImage(_w, _h);
    sw.stop();
    im.dispose();
    p.dispose();
    return sw.elapsedMicroseconds / 1000.0;
  }

  for (var i = 0; i < 5; i++) {
    await once(a);
    await once(b);
  }
  for (var i = 0; i < frames; i++) {
    ta.add(await once(a));
    tb.add(await once(b));
  }
  ta.sort();
  tb.sort();
  double med(List<double> l) => l[l.length ~/ 2];
  stdout.writeln('$labelA  medyan ${med(ta).toStringAsFixed(2)} ms · '
      'min ${ta.first.toStringAsFixed(2)} ms');
  stdout.writeln('$labelB  medyan ${med(tb).toStringAsFixed(2)} ms · '
      'min ${tb.first.toStringAsFixed(2)} ms');
  final dMed = med(ta) - med(tb), dMin = ta.first - tb.first;
  stdout.writeln('  → fark: medyan ${dMed >= 0 ? '-' : '+'}'
      '${dMed.abs().toStringAsFixed(2)} ms · '
      'min ${dMin >= 0 ? '-' : '+'}${dMin.abs().toStringAsFixed(2)} ms '
      '(eksi = ikinci yöntem daha hızlı)');
}

/// GÖRSEL EŞİTLİK KANITI — dar sınır çizimi değiştiriyor mu?
///
/// Tam sahne karesiyle karşılaştırma İŞE YARAMAZ: köy iki koşu arasında
/// deterministik değil (kişilik tohumu rastgele, ateş/meşale titreşimi zamana
/// bağlı, köylüler yürüyor) → kareler zaten %94 farklı çıkıyor ve değişikliğin
/// payı ölçülemiyor. Bu yüzden yalnız IŞIK PASS'İ, aynı sentetik ışıklarla,
/// aynı süreçte iki kez çizilip diff'lenir. Fark sıfırsa teknik güvenlidir.
Future<void> _proveIdentical(List<_Light> lights) async {
  Future<ui.Image> render(void Function(Canvas) body) async {
    final rec = ui.PictureRecorder();
    body(Canvas(rec));
    final p = rec.endRecording();
    final img = await p.toImage(_w, _h);
    p.dispose();
    return img;
  }

  final a = await render((c) => _paintFullRes(c, lights));
  final b = await render((c) => _paintTightBounds(c, lights));
  final da = await a.toByteData(format: ui.ImageByteFormat.rawRgba);
  final db = await b.toByteData(format: ui.ImageByteFormat.rawRgba);
  final ba = da!.buffer.asUint8List(), bb = db!.buffer.asUint8List();

  var diff = 0, maxD = 0;
  for (var i = 0; i < ba.length; i++) {
    final d = (ba[i] - bb[i]).abs();
    if (d != 0) {
      diff++;
      if (d > maxD) maxD = d;
    }
  }
  stdout.writeln('');
  stdout.writeln('── GÖRSEL EŞİTLİK (tam ekran sınır vs dar sınır) ──');
  stdout.writeln('farklı bayt: $diff / ${ba.length}  ·  '
      'maksimum kanal farkı: $maxD');
  stdout.writeln(diff == 0
      ? 'SONUÇ: BİREBİR AYNI — dar sınır çizimi değiştirmiyor.'
      : 'SONUÇ: FARK VAR — sınır payı yetersiz, kullanma.');
  a.dispose();
  b.dispose();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final lights = _makeLights();
  stdout.writeln('IŞIK PASS BENCH — ${_w}x$_h, $_lights ışık, $_frames kare');

  // ── ASIL SORU: dar sınır kazandırıyor mu? (dönüşümlü, gürültüye dayanıklı)
  final cluster = _makeClustered();
  stdout.writeln('');
  stdout.writeln('── A/B: KÜMELENMİŞ IŞIKLAR (gerçek köy dağılımı) ──');
  await _abBench(
    'tam ekran sınır',
    (c) => _paintFullRes(c, cluster),
    'dar sınır      ',
    (c) => _paintTightBounds(c, cluster),
  );
  stdout.writeln('');
  stdout.writeln('── A/B: EKRANA YAYILMIŞ IŞIKLAR (en kötü durum) ──');
  await _abBench(
    'tam ekran sınır',
    (c) => _paintFullRes(c, lights),
    'dar sınır      ',
    (c) => _paintTightBounds(c, lights),
  );
  // Diğer iki aday da AYNI dönüşümlü yöntemle ölçülür — ilk (ardışık) ölçümde
  // bunlar 1.14× ile 1.77× arasında salınmıştı, yani sıralama gürültüydü.
  _radialSprite = await _bakeRadial();
  stdout.writeln('');
  stdout.writeln('── A/B: yarı çözünürlük (kümelenmiş) ──');
  await _abBench(
    'tam çözünürlük ',
    (c) => _paintFullRes(c, cluster),
    'yarı çözünürlük',
    (c) => _paintHalfRes(c, cluster),
  );
  stdout.writeln('');
  stdout.writeln('── A/B: pişmiş radial doku (kümelenmiş) ──');
  await _abBench(
    'gradient shader',
    (c) => _paintFullRes(c, cluster),
    'pişmiş doku    ',
    (c) => _paintSprite(c, cluster),
  );

  await _proveIdentical(cluster);
  await _proveIdentical(lights);
  exit(0);
}
