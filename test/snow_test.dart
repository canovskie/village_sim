// KAR — zeminde, gökte ve YAĞIŞIN KENDİSİNDE.
//
// Karın üç ayrı yaşadığı yer var ve üçü de SESSİZCE ölebilir:
//   • ZEMİN: kışın yürüme yavaşlar. Çarpan bir sabit olarak durur, sahnenin
//     onu köylülere YAZMASI gerekir. Yazmazsa hiçbir şey patlamaz, hiçbir test
//     kırılmaz, kış sadece "aynı hızda" geçer.
//   • GÖK: kar yağışının kapısı painter'ın içinde bir koşuldu — yalnız kare
//     çekerek sınanabilirdi.
//   • YAĞIŞ: tanelerin nerede olduğu. "Kar dandik yağıyor" bir his değil,
//     ölçülebilir dört kusurdu (ızgara yerleşim, senkron salınım, tek hız,
//     kenarda pop) ve hepsi geri gelebilir çünkü hiçbiri hata vermez.
//
// Bu dosya üçünü de kurala bağlar; sondaki prova testi ise kabloyu sınar:
// gerçek kış köyünde köylülerin ayağı gerçekten ağır mı (bkz. cold_tent_probe
// aynı dersin ilkiydi — "0 üşüyen" ile "mekanik bağlanmamış" aynı görünüyordu).
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/main.dart';
import 'package:village_sim/rendering/snow_field.dart';
import 'package:village_sim/systems/winter.dart';
import 'package:village_sim/world/reference_village_plan.dart';
import 'package:village_sim/world/season.dart';

/// Tek bir karede çözülmüş tane (test tarafı toplayıcısı).
class _Flake {
  _Flake(this.x, this.y, this.r, this.a, this.halo, this.tone);
  final double x, y, r, a, halo, tone;
}

const _size = Size(1280, 800);

List<_Flake> _frame(double time, {double zoom = 1.0, bool perf = false}) {
  final out = <_Flake>[];
  SnowField.forEach(
    (x, y, r, a, halo, tone) => out.add(_Flake(x, y, r, a, halo, tone)),
    size: _size,
    time: time,
    zoom: zoom,
    perfMode: perf,
  );
  return out;
}

/// Katmanlar `tone` ile ayrılır — her derinliğin kendi beyazlığı var.
List<_Flake> _layer(List<_Flake> all, SnowLayerSpec spec) =>
    all.where((f) => f.tone == spec.tone).toList();

double _mean(Iterable<double> xs) => xs.reduce((a, b) => a + b) / xs.length;

double _stdev(Iterable<double> xs) {
  final m = _mean(xs);
  return sqrt(_mean(xs.map((x) => (x - m) * (x - m))));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('zemin — karda yürüme', () {
    test('yalnız kış yavaşlatır, diğer üç mevsim tam hız', () {
      expect(groundFactorFor(Season.winter), kSnowSpeedMultiplier);
      for (final s in Season.values.where((s) => s != Season.winter)) {
        expect(groundFactorFor(s), 1.0, reason: '${s.label} yavaşlatmamalı');
      }
    });

    test('yavaşlama hissedilir ama ağır çekim değil', () {
      // Bu iki sınır tasarım kararı: 1.0'a yapışırsa kar hiç hissedilmez,
      // 0.8'in altına inerse köy kış boyunca ağır çekim olur.
      expect(kSnowSpeedMultiplier, lessThan(0.95));
      expect(kSnowSpeedMultiplier, greaterThan(0.80));
    });

    test('kış bitince çarpan 1.0\'a DÖNER (kalıcı yavaşlık bırakmaz)', () {
      // Tek yönlü bir uygulama (yalnız kışın yaz, hiç sıfırlama) köyü
      // ilkbaharda da yavaş bırakırdı ve sebebi hiçbir yerde görünmezdi.
      final winter = groundFactorFor(Season.winter);
      final spring = groundFactorFor(Season.spring);
      expect(spring, greaterThan(winter));
      expect(spring, 1.0);
    });
  });

  group('gök — kar yağışı kapısı', () {
    bool vis({
      Season season = Season.winter,
      double zoom = 1.0,
      bool festival = false,
      bool meteorShower = false,
      bool storm = false,
    }) => snowfallVisible(
      season: season,
      zoom: zoom,
      festival: festival,
      meteorShower: meteorShower,
      storm: storm,
    );

    test('kar yalnız kışın yağar', () {
      expect(vis(), isTrue);
      for (final s in Season.values.where((s) => s != Season.winter)) {
        expect(vis(season: s), isFalse, reason: '${s.label} kar yağmamalı');
      }
    });

    test('fırtına kendi karını çizer — üstüne ikinci kat binmez', () {
      // İkisi birden çizilirse aynı hava iki kez çizilmiş olur: kar iki kat
      // yoğun görünür ve fırtınanın rüzgârlı dili kaybolur.
      expect(vis(storm: true), isFalse);
    });

    test('şenlik ve göktaşı kendi partikül dilini kullanır', () {
      expect(vis(festival: true), isFalse);
      expect(vis(meteorShower: true), isFalse);
    });

    test('çok uzak zoom\'da tane gürültüye döner — çizilmez', () {
      expect(vis(zoom: 0.34), isFalse);
      expect(vis(zoom: 0.35), isTrue, reason: 'eşiğin kendisi dahil');
      expect(vis(zoom: 2.0), isTrue);
    });
  });

  // ── YAĞIŞ: tanelerin kendisi ────────────────────────────────────────────
  //
  // Buradaki her test, karın "dandik" göründüğü hâlin BİR sebebini kilitler.
  // Hiçbiri estetik değil; hepsi ölçülebilir bir desen kusuru.
  group('yağış — tane alanı', () {
    final far = kSnowLayers[0];
    final near = kSnowLayers[2];

    test('yoğunluk gerçekten kar seviyesinde (eski 65 tane değil)', () {
      // Asıl şikâyet buydu: 1280×800'de 65 tane = tane başına ~10.000 piksel,
      // yani kar değil havada asılı birkaç zerre.
      final n = _frame(7.0).length;
      expect(n, greaterThan(200), reason: 'kar yine seyreldi');
      // Üst sınır da tasarım kararı: kare maliyeti ve okunurluk.
      expect(n, lessThan(420));
    });

    test('yoğunluk ekran ALANIYLA ölçeklenir', () {
      // Sabit sayı geniş pencerede boşluk, telefonda tıkanıklık demekti.
      final small = <_Flake>[];
      SnowField.forEach(
        (x, y, r, a, h, t) => small.add(_Flake(x, y, r, a, h, t)),
        size: const Size(640, 360),
        time: 7.0,
        zoom: 1.0,
      );
      expect(small.length, lessThan(_frame(7.0).length * 0.75));
    });

    test('yatay yerleşim IZGARAYA oturmaz', () {
      // Eski kod x'i `(i * 1733 + seed) % 997` ile üretiyordu: sıralanmış
      // taneler arasındaki boşluk neredeyse SABİT çıkıyor, göz bunu düşey bant
      // olarak seçiyordu. Rastgele bir alanda sıralı boşluklar üstel dağılır
      // (sapma/ortalama ≈ 1); ızgarada bu oran ~0'a iner.
      for (final t in const [3.0, 41.0, 123.0]) {
        final xs = _layer(_frame(t), far).map((f) => f.x).toList()..sort();
        final gaps = [for (var i = 1; i < xs.length; i++) xs[i] - xs[i - 1]];
        expect(
          _stdev(gaps) / _mean(gaps),
          greaterThan(0.55),
          reason: 't=$t: taneler eşit aralıklı — yerleşim ızgaraya oturmuş',
        );
      }
    });

    test('katman TEK PARÇA yalpalamaz (salınım desenkron)', () {
      // Her tane aynı frekansla sallanırsa katman bir perde gibi sağa sola
      // gider. O durumda iki kare arasındaki yatay kayma HER tanede aynıdır.
      final a = _layer(_frame(20.0), near);
      final b = _layer(_frame(20.5), near);
      final dx = [for (var i = 0; i < a.length; i++) b[i].x - a[i].x];
      expect(
        _stdev(dx),
        greaterThan(1.0),
        reason: 'bütün taneler aynı miktar kaydı — salınım senkron',
      );
    });

    test('katman içinde TEK düşüş hızı yok (yürüyen bant değil)', () {
      // Aynı hız = taneler aralarındaki mesafeyi hiç değiştirmeden iner.
      final a = _layer(_frame(20.0), near);
      final b = _layer(_frame(20.2), near);
      final dy = <double>[
        for (var i = 0; i < a.length; i++)
          if (b[i].y > a[i].y) b[i].y - a[i].y, // sarmayanlar
      ];
      expect(dy.length, greaterThan(10));
      expect(
        _stdev(dy) / _mean(dy),
        greaterThan(0.10),
        reason: 'her tane aynı hızda düşüyor',
      );
    });

    test('kenarda POP yok — tane açılarak girer, sönerek çıkar', () {
      // Aksi hâlde iri yakın taneler ekranın üstünde birden beliriyordu.
      for (final t in const [5.0, 33.0, 77.0]) {
        for (final f in _frame(t)) {
          final spec = kSnowLayers.firstWhere((L) => L.tone == f.tone);
          if (f.y < -8 || f.y > _size.height + 8) {
            expect(
              f.a,
              lessThan(spec.alpha * 0.35),
              reason: 't=$t: kenardaki tane tam opak — pop eder',
            );
          }
        }
      }
    });

    test('tane hiçbir zaman güvenlik payının dışına taşmaz', () {
      for (final t in const [0.0, 9.0, 60.0, 400.0]) {
        for (final f in _frame(t)) {
          expect(
            f.x,
            inInclusiveRange(-kSnowMargin - 1, _size.width + kSnowMargin + 1),
          );
          expect(
            f.y,
            inInclusiveRange(-kSnowMargin - 1, _size.height + kSnowMargin + 1),
          );
          expect(f.a, inInclusiveRange(0.0, 1.0));
        }
      }
    });

    test('rüzgâr YÖN DEĞİŞTİRİR — kar hep aynı tarafa eğik akmaz', () {
      // Sabit sürüklenme bir süre sonra "kar sağa akıyor" hissine kilitlenir.
      final ws = [for (var t = 0.0; t < 200.0; t += 2.0) SnowField.wind(t)];
      expect(ws.reduce(max), greaterThan(50));
      expect(ws.reduce(min), lessThan(-50));
    });

    test('yağış dalga dalga gelir ama tane KAYBOLMAZ', () {
      // Nefes alfada olmalı; sayıda olsaydı taneler yok olup belirirdi.
      final counts = {for (var t = 0.0; t < 120.0; t += 6.0) _frame(t).length};
      expect(counts.length, 1, reason: 'tane sayısı zamanla değişiyor — pop');
      final fs = [for (var t = 0.0; t < 200.0; t += 2.0) SnowField.flurry(t)];
      expect(fs.reduce(max) - fs.reduce(min), greaterThan(0.15));
      expect(
        fs.reduce(min),
        greaterThan(0.5),
        reason: 'kar tamamen kesilmemeli',
      );
    });

    test('perf modu ve uzak zoom seyreltir', () {
      expect(_frame(7.0, perf: true).length, lessThan(_frame(7.0).length));
      expect(_frame(7.0, zoom: 0.4).length, lessThan(_frame(7.0).length));
    });

    test('SAF: aynı girdi aynı kareyi verir', () {
      final a = _frame(13.7);
      final b = _frame(13.7);
      expect(a.length, b.length);
      for (var i = 0; i < a.length; i++) {
        expect(a[i].x, b[i].x);
        expect(a[i].y, b[i].y);
      }
    });
  });

  // ── PROVA: kablo bağlı mı ───────────────────────────────────────────────
  //
  // Yukarıdaki testlerin hepsi geçerken kış yine de hızlı geçebilir: kural
  // doğru, kimse uygulamıyor. Burada gerçek bir kış köyü kurulur ve
  // köylülerin ayağına bakılır.
  group('prova — kış köyünde ayak gerçekten ağır', () {
    setUp(() {
      final m =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      for (final ch in const [
        'xyz.luan/audioplayers',
        'xyz.luan/audioplayers.global',
        'plugins.flutter.io/shared_preferences',
        'plugins.flutter.io/path_provider',
      ]) {
        m.setMockMethodCallHandler(MethodChannel(ch), (call) async {
          if (call.method == 'getAll') return <String, Object>{};
          return null;
        });
      }
      m.setMockStreamHandler(
        const EventChannel('xyz.luan/audioplayers.global/events'),
        null,
      );
      kProbeOn = false;
      kCaptureMode = false;
      kDevSpeedBoostOverride = 0;
      kProbeSnowFooted = 0;
      kCaptureReferenceSeason = kReferenceBaseSeason;
    });

    tearDown(() {
      kCaptureReferenceSeason = kReferenceBaseSeason;
      kDevSpeedBoostOverride = 0;
    });

    testWidgets('kışta kurulan köyün köylüleri kar çarpanını taşır', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      kCaptureMode = true;
      kCaptureSceneReady = false;
      // Mevsimlik referans köy: kışa kadar gün saymaya gerek yok, köy KIŞTA
      // doğar (bkz. project reference village mevsimlik varyantlar).
      kCaptureReferenceSeason = Season.winter;

      await tester.runAsync(() async {
        await tester.pumpWidget(
          const MaterialApp(
            home: VillageScene(referenceVillage: true, slotId: 'snowprobe'),
          ),
        );
        for (var i = 0; i < 1200 && !kCaptureSceneReady; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      });
      await tester.pump();
      expect(
        kCaptureSceneReady,
        isTrue,
        reason: 'referans köy kurulamadı — bu testin karla ilgisi YOK',
      );

      // Kış taraması saniyelik; birkaç saniye akıt.
      kDevSpeedBoostOverride = 8.0;
      for (var i = 0; i < 200 && kProbeSnowFooted == 0; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(
        kProbeSnowFooted,
        greaterThan(0),
        reason:
            'kış köyünde kimsenin ayağı ağırlaşmadı — kar çarpanı '
            'köylülere hiç yazılmıyor olabilir (bkz. _applySnowFooting).',
      );

      kDevSpeedBoostOverride = 0;
      await tester.pumpWidget(const SizedBox());
    });
  });
}
