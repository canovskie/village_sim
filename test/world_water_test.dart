// SU YÜZEYİNİN SÖZLEŞMESİ — göl bir su kütlesi gibi durmalı.
//
// Kullanıcı şikâyeti (2026-08-01): "deniz benzeri bi saçmalık var, boşluk
// (yansıma) gibi duruyor, üstüne ağaç falan da var ama deniz şeklinde bozmuş
// yüzeyi." Yakalanan karede iki ayrı kusur vardı; bu test ikincisini —
// suyun İÇİNE düşen nesneleri — kalıcı olarak kilitler. (Birincisi, tile
// başına rastgele dalga fazından doğan "yamalı bohça" görüntüsü, çizim
// tarafında düzeltildi: bkz. WaterRenderer.drawTile `wavePhase`.)
//
// Neden test: gözle bakınca izometride "sudaki ağaç" ile "kıyıdaki ağacın
// suya taşan kanopisi" ayırt edilemiyor. Sorulacak doğru soru şu: ağacın
// OTURDUĞU KARE su mu?

import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/world/world_generator.dart';

void main() {
  // Birkaç tohum: tek harita "şanslı" çıkabilir, kusur harita üretimindeyse
  // tohumlar arasında tekrar eder.
  const seeds = [1, 7, 42, 1337, 90210];

  group('su üstünde nesne olmaz', () {
    test('hiçbir ağaç su karesinde durmaz', () {
      for (final seed in seeds) {
        final w = WorldGenerator(seed).generate();
        final onWater = [
          for (final t in w.trees)
            if (w.waterTiles.contains((t.col, t.row))) (t.col, t.row),
        ];
        expect(onWater, isEmpty,
            reason: 'tohum $seed: ${onWater.length} ağaç suyun içinde '
                '(ilk birkaçı: ${onWater.take(5).toList()}). İzometride bu, '
                'gölün yüzeyini "bozulmuş" gösteren şeyin ta kendisi.');
      }
    });

    test('hiçbir maden su karesinde durmaz', () {
      for (final seed in seeds) {
        final w = WorldGenerator(seed).generate();
        final onWater = [
          for (final m in w.mineNodes)
            if (w.waterTiles.contains((m.col, m.row))) (m.col, m.row),
        ];
        expect(onWater, isEmpty, reason: 'tohum $seed: maden suyun içinde');
      }
    });

    test('hiçbir böğürtlen çalısı su karesinde durmaz', () {
      for (final seed in seeds) {
        final w = WorldGenerator(seed).generate();
        final onWater = [
          for (final b in w.berryBushes)
            if (w.waterTiles.contains((b.col, b.row))) (b.col, b.row),
        ];
        expect(onWater, isEmpty, reason: 'tohum $seed: çalı suyun içinde');
      }
    });

    test('dekor su karesine düşmez', () {
      for (final seed in seeds) {
        final w = WorldGenerator(seed).generate();
        final onWater = [
          for (final d in w.decor)
            if (w.waterTiles.contains((d.col, d.row))) (d.col, d.row),
        ];
        expect(onWater, isEmpty,
            reason: 'tohum $seed: ${onWater.length} dekor suyun içinde');
      }
    });
  });

  group('kıyı çizgisi tırtıklı olmaz', () {
    int waterNeighbors(Set<(int, int)> w, int c, int r) {
      var n = 0;
      if (w.contains((c - 1, r))) n++;
      if (w.contains((c + 1, r))) n++;
      if (w.contains((c, r - 1))) n++;
      if (w.contains((c, r + 1))) n++;
      return n;
    }

    test('suyun içinde yalnız kalmış kara karesi olmaz', () {
      // Dört komşusu da su olan bir KARA karesi = gölün ortasındaki delik.
      // İzometride ada gibi değil, hata gibi okunur — hele üstünde ağaç varsa.
      for (final seed in seeds) {
        final w = WorldGenerator(seed).generate().waterTiles;
        final holes = <(int, int)>[];
        for (final (c, r) in w) {
          for (final n in [(c - 1, r), (c + 1, r), (c, r - 1), (c, r + 1)]) {
            if (w.contains(n)) continue;
            if (waterNeighbors(w, n.$1, n.$2) == 4) holes.add(n);
          }
        }
        expect(holes, isEmpty,
            reason: 'tohum $seed: gölün içinde ${holes.length} kara deliği '
                '${holes.take(5).toList()}');
      }
    });

    test('karaya sarkan tek su karesi olmaz', () {
      // Hiç su komşusu olmayan su karesi = çayırın ortasında bir su elması.
      for (final seed in seeds) {
        final w = WorldGenerator(seed).generate().waterTiles;
        final strays = [
          for (final (c, r) in w)
            if (waterNeighbors(w, c, r) == 0) (c, r),
        ];
        expect(strays, isEmpty,
            reason: 'tohum $seed: ${strays.length} başıboş su karesi '
                '${strays.take(5).toList()}');
      }
    });
  });
}
