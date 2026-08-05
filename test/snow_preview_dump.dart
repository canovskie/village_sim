// HIZLI kar önizlemesi — köy sahnesi kurmadan sadece kar katmanı.
//
// Karın nasıl yağdığına bakmak için bütün köyü ayağa kaldırmak (referans köy +
// kışa sarma + kare çekme) dakikalar sürüyor. Kar SAF bir kural olduğu için
// (bkz. lib/rendering/snow_field.dart) burada tek başına, kışın gerçek zemin
// tonlarına çizilebilir — saniyeler.
//
// Çalıştır:  flutter test test/snow_preview_dump.dart
// Çıktı:     /tmp/snow_gunduz_t*.png, /tmp/snow_gece_t*.png
//
// Dosya adı kasten `_test.dart` ile bitmiyor: normal `flutter test` taramasına
// takılmasın, sadece elle çağrılsın.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/rendering/snow_field.dart';

/// Karın ÜSTÜNE düştüğü zemin — karın asıl sınavı bu.
///
/// Kışın sahnenin arkası ikiye ayrılır: parlak kar tile'ı (ortalaması #DBE6F2,
/// asset'ten ölçüldü) ve onun üstündeki koyu lekeler (ağaç, çatı, kaya). Beyaz
/// bir tane ilkinde kaybolur, koyu bir tane ikincisinde. Önizleme ikisini de
/// aynı karede tutar, yoksa "düzeldi" demek yanıltıcı olur.
void _backdrop(Canvas c, Size size, double lit) {
  final ground = Color.lerp(
    const Color(0xFF2C3448), // gece: ay ışığında lacivert kar
    const Color(0xFFDBE6F2), // gündüz: gerçek kar tile ortalaması
    lit,
  )!;
  final dark = Color.lerp(
    const Color(0xFF141A26),
    const Color(0xFF3E4A3C), // kışlık koyu ağaç/çatı
    lit,
  )!;
  c.drawRect(Offset.zero & size, Paint()..color = ground);

  // Koyu lekeler — ağaç kümeleri / çatılar için kaba vekiller.
  final p = Paint()..color = dark;
  const blobs = <Rect>[
    Rect.fromLTWH(90, 120, 260, 190),
    Rect.fromLTWH(520, 40, 200, 140),
    Rect.fromLTWH(830, 300, 330, 240),
    Rect.fromLTWH(160, 560, 240, 180),
    Rect.fromLTWH(600, 620, 180, 150),
  ];
  for (final b in blobs) {
    c.drawRRect(RRect.fromRectXY(b, 26, 26), p);
  }
}

/// game_ambient.dart `_drawSnow` ile AYNI boyama — painter'ın alanlarına
/// (dayLight/zoom/perfMode) bağlı olduğu için burada elle yansıtılıyor.
void _snow(Canvas c, Size size, double time, double dayLight) {
  final lit = dayLight.clamp(0.0, 1.0);
  final wr = (0xDA + 0x20 * lit).round().clamp(0, 255);
  final wg = (0xE6 + 0x16 * lit).round().clamp(0, 255);
  final wb = (0xF6 + 0x09 * lit).round().clamp(0, 255);
  final kr = (0x74 + 0x22 * lit).round().clamp(0, 255);
  final kg = (0x8A + 0x22 * lit).round().clamp(0, 255);
  final kb = (0xAE + 0x1A * lit).round().clamp(0, 255);
  final toneLit = 0.32 + 0.68 * (1.0 - lit);
  const haloA = 0.26;
  final vis = 0.58 + 0.42 * lit;
  final p = Paint()..isAntiAlias = true;

  SnowField.forEach(
    (x, y, r, a, halo, tone) {
      final core = (a * vis * 255).round().clamp(0, 255);
      if (core < 3) return;
      final center = Offset(x, y);
      if (halo > 0) {
        p.color = Color.fromARGB(
          (core * haloA).round().clamp(0, 255),
          kr,
          kg,
          kb,
        );
        c.drawCircle(center, halo, p);
      }
      final t = tone * toneLit;
      p.color = Color.fromARGB(
        core,
        (kr + (wr - kr) * t).round().clamp(0, 255),
        (kg + (wg - kg) * t).round().clamp(0, 255),
        (kb + (wb - kb) * t).round().clamp(0, 255),
      );
      c.drawCircle(center, r, p);
    },
    size: size,
    time: time,
    zoom: 1.0,
    perfMode: false,
  );
}

void main() {
  const size = Size(1280, 800);
  // Aynı yağışın uzak anları: desen tekrar ediyor mu, rüzgâr yön değiştiriyor
  // mu, taneler zamanla ızgaraya oturuyor mu — tek karede görülmez.
  const moments = <double>[3.0, 11.0, 47.0, 130.0];
  const lights = <String, double>{'gunduz': 0.95, 'gece': 0.12};

  test('kar önizleme kareleri', () async {
    for (final l in lights.entries) {
      for (final t in moments) {
        final rec = ui.PictureRecorder();
        final c = Canvas(rec, Offset.zero & size);
        _backdrop(c, size, l.value);
        _snow(c, size, t, l.value);
        final img = await rec.endRecording().toImage(
          size.width.toInt(),
          size.height.toInt(),
        );
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        final path = '/tmp/snow_${l.key}_t${t.toInt()}.png';
        File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
        // ignore: avoid_print
        print('yazıldı: $path');
      }
    }
  });
}
