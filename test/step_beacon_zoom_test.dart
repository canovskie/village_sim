// ADIM İŞARETİNİN ZOOM HİZASI — halka hedefinden kaymasın.
//
// Kırılan hata: `_drawStepBeacon` lighting pass'inden SONRA, yani EKRAN
// uzayında çiziliyor (gece karanlığının altında kalmaması için doğru bir
// karar). Ama konumunu düz `gridToScreen` ile hesaplıyordu; o dönüşüm zoom'u
// bilmez. Dünya ekran merkezine göre ölçeklenirken halka yerinde kalıyor,
// oyuncu yaklaşıp uzaklaşınca işaret hedefinden KAYIYORDU — hem de oyunun
// "şuraya bak" diyen, en çok güvenilmesi gereken tek işaretinde.
//
// Bu dosya `game_ambient.dart:_worldToScreen`'in (paint'teki zoom dönüşümünün
// aynısı) matematiğini birebir çoğaltır — villager_hittest_test'in deseni;
// gerçek sahne/tick gerekmez. Değişirse ikisini birlikte güncelle.

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/core/constants.dart';

/// game_ambient.dart:_worldToScreen — dünya noktası → ekran (zoom dahil).
Offset worldToScreen(double gx, double gy, Size size, Offset camera,
    double zoom) {
  final s = gridToScreen(gx, gy, size, camera);
  final cx = size.width / 2;
  final cy = size.height / 2;
  return Offset(cx + (s.dx - cx) * zoom, cy + (s.dy - cy) * zoom);
}

/// scene_ui / scene_world / scene_guide'ın künye-katmanı dönüşümü. Halka ile
/// AYNI noktayı vermeli: iki ayrı hesap iki ayrı yeri gösterir.
Offset overlayScreen(Offset world, Size size, double zoom) {
  final center = Offset(size.width / 2, size.height / 2);
  return (world - center) * zoom + center;
}

void main() {
  const size = Size(1200.0, 800.0);
  const camera = Offset(-40.0, 25.0);
  // Ekran merkezinde OLMAYAN bir hedef: merkezdeki nokta her zoom'da yerinde
  // kalır, yani hatayı gizler. Kayma merkezden uzaklıkla büyür.
  const target = (34.0, 21.0);

  test('halka künye katmanıyla aynı noktayı verir (her zoom)', () {
    for (final zoom in [0.20, 0.5, 1.0, 1.6, 4.0]) {
      final beacon =
          worldToScreen(target.$1, target.$2, size, camera, zoom);
      final overlay = overlayScreen(
          gridToScreen(target.$1, target.$2, size, camera), size, zoom);
      expect((beacon - overlay).distance, lessThan(0.01),
          reason: 'zoom=$zoom: halka ile künye katmanı ayrışmış');
    }
  });

  test('zoom 1 dışında düz gridToScreen hedefi ıskalar', () {
    // Regresyon kilidi: birisi `_worldToScreen`i tekrar `gridToScreen`e
    // düşürürse bu iki beklenti aynı anda tutmaz.
    final raw = gridToScreen(target.$1, target.$2, size, camera);
    expect((worldToScreen(target.$1, target.$2, size, camera, 1.0) - raw)
        .distance, lessThan(0.01),
        reason: 'zoom=1 iki hesabın çakıştığı tek nokta olmalı');
    for (final zoom in [0.35, 2.5]) {
      final fixed = worldToScreen(target.$1, target.$2, size, camera, zoom);
      expect((fixed - raw).distance, greaterThan(40.0),
          reason: 'zoom=$zoom: zoom\'suz hesap gözle görülür biçimde kayar');
    }
  });

  test('halka ölçeği zoom ile gider ama kaybolmaz/ekranı yutmaz', () {
    // `_drawStepBeacon`'daki kelepçe: ekran uzayında çizilen zemin halkası
    // ölçeğini kendi taşımalı, yoksa uzaklaşınca yedi tile kaplar.
    double k(double zoom) => zoom.clamp(0.65, 1.6);
    expect(k(0.20), 0.65, reason: 'en uzakta halka görünmez olmamalı');
    expect(k(1.0), 1.0, reason: 'varsayılan zoom ölçeği bozmamalı');
    expect(k(4.0), 1.6, reason: 'en yakında halka ekranı yutmamalı');
    // Orta halka bir tile'dan geniş kalmalı (zemin deseninden ayrışma kuralı).
    for (final zoom in [0.20, 1.0, 4.0]) {
      expect(62 * k(zoom), greaterThan(kTileW * 0.6),
          reason: 'zoom=$zoom: halka zemin deseninde kaybolur');
    }
  });
}
