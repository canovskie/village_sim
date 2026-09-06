import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/buildings/building_entity.dart';
import 'package:village_sim/buildings/building_type.dart';
import 'package:village_sim/systems/labor/building_system.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('şapel tamamlanınca kiliseden küçük ama gerçek moral katkısı verir', () {
    double morale(BuildingType type) => computeVillageStats([
      BuildingEntity(type: type, col: 0, row: 0),
    ]).amenityMorale;

    expect(morale(BuildingType.chapel), greaterThan(0));
    expect(morale(BuildingType.chapel), lessThan(morale(BuildingType.church)));
    expect(
      morale(BuildingType.chapel),
      closeTo(amenityMoraleFrom({BuildingType.chapel: 1}), 1e-9),
    );
  });

  test('şapel mevsim görselleri gerçek saydamlıkla paketlenir', () async {
    for (final suffix in ['', '_winter']) {
      final data = await rootBundle.load('assets/buildings/chapel$suffix.png');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final image = (await codec.getNextFrame()).image;
      final pixels = (await image.toByteData())!.buffer.asUint8List();
      var transparent = 0;
      var opaque = 0;
      for (var i = 3; i < pixels.length; i += 4) {
        if (pixels[i] == 0) transparent++;
        if (pixels[i] > 240) opaque++;
      }
      final count = image.width * image.height;
      expect(transparent / count, greaterThan(0.25), reason: suffix);
      expect(opaque / count, greaterThan(0.25), reason: suffix);
      image.dispose();
      codec.dispose();
    }
  });
}
