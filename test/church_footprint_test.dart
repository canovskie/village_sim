import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/buildings/building_type.dart';
import 'package:village_sim/core/constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'kilisenin merdiven ve yan kaideleri ayrılan arazi içinde kalır',
    () async {
      // church.png üstünde ölçülen ZEMİN temasları. Kule/çatı tepesi arazi
      // değildir; tüm sprite kutusunu grid'e çevirmek yanlış alan ayırır.
      const groundPoints = [
        (12, 966), // sol çiçeklik
        (35, 995),
        (309, 1120), // ön merdiven
        (377, 1147), // merdiven yanı saksı
        (491, 1135), // duyuru levhasının ayağı
        (672, 1134), // sağ ön saksı
        (748, 1118), // sağ ön taş kaide
        (856, 1129), // varil ayağı
        (965, 1090), // sandık ayağı
        (1068, 1002), // sağ yan saksı
        (1081, 946),
        (110, 949), // sol yan temel
        (980, 955), // sağ arka temel
      ];
      final meta = kBuildingMeta[BuildingType.church]!;
      final png = await rootBundle.load('assets/buildings/church.png');
      final imageW = png.getUint32(16);
      final imageH = png.getUint32(20);
      final width = (meta.cols + meta.rows) * kTileW / 2 * meta.spriteScale;
      final scale = width / imageW;
      final left =
          ((meta.cols - meta.rows) * kTileW / 2 - width * meta.groundXCenter)
              .roundToDouble();
      final top =
          ((meta.cols + meta.rows) * kTileH / 2 - imageH * scale * meta.groundY)
              .roundToDouble();

      for (final (px, py) in groundPoints) {
        final sx = left + px * scale;
        final sy = top + py * scale;
        final col = sx / kTileW + sy / kTileH;
        final row = sy / kTileH - sx / kTileW;
        expect(
          col,
          inInclusiveRange(0.0, meta.cols.toDouble()),
          reason: '($px,$py) tabanı sütun sınırının dışında',
        );
        expect(
          row,
          inInclusiveRange(0.0, meta.rows.toDouble()),
          reason: '($px,$py) tabanı satır sınırının dışında',
        );
      }
      // Alan düzeltmesi kiliseyi yeniden küçültmemeli.
      expect(width, closeTo(268.8, 0.01));
    },
  );
}
