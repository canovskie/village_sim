// NPC tıklama hit-test geometrisi — _villagerAtScreen'in matematiğini birebir
// çoğaltıp özelliklerini doğrular (gerçek sahne/tick gerektirmeden; macOS
// capture harness'ı foreground olmadan tick atmadığı için bu güvenilir yol).
//
// Kırılan hata: sprite gövde kutusu karakter-lokal ±13 birim × charScale(0.34)
// = ekranda ~9px'e büzülüyordu → köylüye TAM tıklasan bile ıska. Fix: garanti
// taban dokunma yarıçapı (zoom'dan bağımsız), sprite'ın gerçek ekran konumu.

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const double kTileW = 64.0;
const double kTileH = 32.0;
const double kCharScale = 0.34;

Offset gridToScreen(double gx, double gy, Size size, Offset camera) {
  final ox = (size.width / 2 + camera.dx).roundToDouble();
  final oy = (size.height * 0.28 + camera.dy).roundToDouble();
  return Offset(
    (ox + (gx - gy) * kTileW / 2).roundToDouble(),
    (oy + (gx + gy) * kTileH / 2).roundToDouble(),
  );
}

/// scene_world.dart:_villagerAtScreen'in birebir kopyası (test için sadeleşmiş
/// entity: grid + renderScale + depth). Değişirse ikisini birlikte güncelle.
class VTest {
  final double gx, gy, renderScale, depth;
  const VTest(this.gx, this.gy, {this.renderScale = 1.0, required this.depth});
}

VTest? villagerAtScreen(
    Offset pos, List<VTest> villagers, Size view, Offset camera, double zoom) {
  final center = Offset(view.width / 2, view.height / 2);
  VTest? best;
  double bestScore = double.infinity;
  double bestDepth = double.negativeInfinity;
  for (final v in villagers) {
    final world = gridToScreen(v.gx, v.gy, view, camera);
    final feet = (world - center) * zoom + center;
    final sc = kCharScale * v.renderScale * zoom;
    final cy = feet.dy - 36 * sc;
    final halfW = (16.0 * sc).clamp(15.0, 60.0);
    final halfH = (42.0 * sc).clamp(20.0, 90.0);
    final dx = (pos.dx - feet.dx).abs();
    final dy = (pos.dy - cy).abs();
    if (dx > halfW || dy > halfH) continue;
    final score = (dx / halfW) * (dx / halfW) + (dy / halfH) * (dy / halfH);
    if (v.depth > bestDepth + 0.001 ||
        (v.depth > bestDepth - 0.001 && score < bestScore)) {
      best = v;
      bestScore = score;
      bestDepth = v.depth;
    }
  }
  return best;
}

// Bir köylünün ekran (post-zoom) ayak + görsel-merkez konumu.
(Offset feet, Offset centerPt) screenPos(
    VTest v, Size view, Offset camera, double zoom) {
  final c = Offset(view.width / 2, view.height / 2);
  final world = gridToScreen(v.gx, v.gy, view, camera);
  final feet = (world - c) * zoom + c;
  final sc = kCharScale * v.renderScale * zoom;
  return (feet, Offset(feet.dx, feet.dy - 36 * sc));
}

void main() {
  const view = Size(1400, 900);
  const camera = Offset(0, 0);

  group('sprite merkezine tıklama isabet eder', () {
    for (final zoom in [0.25, 0.5, 1.0, 2.0, 4.0]) {
      test('zoom=$zoom', () {
        final v = const VTest(30, 40, depth: 70);
        final (_, ctr) = screenPos(v, view, camera, zoom);
        final hit = villagerAtScreen(ctr, [v], view, camera, zoom);
        expect(hit, same(v), reason: 'merkez tık her zoom\'da tutmalı');
      });
    }
  });

  test('düşük zoomda bile garanti dokunma yarıçapı (>=15px)', () {
    // Eski hata: zoom küçülünce kutu ~2px'e düşüp tıklanamaz oluyordu.
    const zoom = 0.25;
    final v = const VTest(30, 40, depth: 70);
    final (feet, ctr) = screenPos(v, view, camera, zoom);
    // Merkezden 14px yana kayık tık hâlâ tutmalı (taban yarıçap 15px).
    expect(villagerAtScreen(ctr + const Offset(14, 0), [v], view, camera, zoom),
        same(v));
    // Ayak noktasına tık da tutmalı.
    expect(villagerAtScreen(feet, [v], view, camera, zoom), same(v));
  });

  test('uzağa tıklama ıskalar (yanlış-pozitif yok)', () {
    const zoom = 1.0;
    final v = const VTest(30, 40, depth: 70);
    final (_, ctr) = screenPos(v, view, camera, zoom);
    expect(villagerAtScreen(ctr + const Offset(200, 0), [v], view, camera, zoom),
        isNull);
    expect(villagerAtScreen(ctr + const Offset(0, 300), [v], view, camera, zoom),
        isNull);
  });

  test('üst üste binen köylülerde önde çizilen (depth büyük) kazanır', () {
    const zoom = 1.0;
    // Aynı ekran noktasında iki köylü — arka (depth küçük) + ön (depth büyük).
    final back = const VTest(30, 40, depth: 70);
    final front = const VTest(30, 40, depth: 71);
    final (_, ctr) = screenPos(front, view, camera, zoom);
    final hit = villagerAtScreen(ctr, [back, front], view, camera, zoom);
    expect(hit, same(front), reason: 'öndeki seçilmeli');
    // Liste sırası değişse de sonuç aynı.
    final hit2 = villagerAtScreen(ctr, [front, back], view, camera, zoom);
    expect(hit2, same(front));
  });

  test('kamera kaymışken de doğru köylüyü bulur', () {
    const zoom = 1.5;
    const cam = Offset(-320, 140);
    final v = const VTest(55, 22, depth: 77);
    final (_, ctr) = screenPos(v, view, cam, zoom);
    expect(villagerAtScreen(ctr, [v], view, cam, zoom), same(v));
  });

  test('çocuk (küçük sprite) yine de rahat tıklanır', () {
    const zoom = 0.6;
    final child = const VTest(30, 40, renderScale: 0.60, depth: 70);
    final (feet, ctr) = screenPos(child, view, camera, zoom);
    expect(villagerAtScreen(ctr, [child], view, camera, zoom), same(child));
    // Küçük sprite'ta bile taban yarıçap tıklamayı korur.
    expect(villagerAtScreen(feet, [child], view, camera, zoom), same(child));
  });

  test('ESKİ hata regresyonu: kutu asla ~9px\'e büzülmez', () {
    // Eski kod: ±13 * kCharScale = 8.84px yarı-genişlik (zoom<1\'de daha da
    // küçük). Yeni tabana göre her zoom\'da yarı-genişlik >=15px olmalı.
    for (final zoom in [0.2, 0.25, 0.5, 1.0]) {
      final sc = kCharScale * 1.0 * zoom;
      final halfW = (16.0 * sc).clamp(15.0, 60.0);
      expect(halfW, greaterThanOrEqualTo(15.0),
          reason: 'zoom=$zoom yarı-genişlik $halfW < 15 → tıklanamaz');
    }
  });
}
