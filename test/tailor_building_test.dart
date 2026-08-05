import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/buildings/building_function.dart';
import 'package:village_sim/buildings/building_type.dart';
import 'package:village_sim/buildings/craft.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Terzi erken oyunda erişilebilir bir üretim binasıdır', () {
    final meta = kBuildingMeta[BuildingType.tailor];

    expect(meta, isNotNull);
    expect((meta!.cols, meta.rows), (2, 2));
    expect(meta.label, 'Terzi');
    expect(kBuildingCategory[BuildingType.tailor], BuildCategory.uretim);
    expect(kBuildingCraft[BuildingType.tailor], isNull);
    expect(kBuildingFunctions[BuildingType.tailor]?.role, BuildingRole.none);
  });

  test('Terzi sprite varlığı asset paketine dahildir', () async {
    final data = await rootBundle.load('assets/buildings/tailor.png');
    expect(data.lengthInBytes, greaterThan(0));
  });
}
