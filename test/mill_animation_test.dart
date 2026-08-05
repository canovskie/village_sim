import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('mill animation sprites are bundled as full-size PNG layers', () async {
    final base = await rootBundle.load('assets/buildings/mill_base.png');
    final rotor = await rootBundle.load('assets/buildings/mill_rotor.png');

    expect(_pngDimensions(base), (width: 1270, height: 1239));
    expect(_pngDimensions(rotor), (width: 1254, height: 1254));
    expect(base.lengthInBytes, greaterThan(100000));
    expect(rotor.lengthInBytes, greaterThan(100000));
  });
}

({int width, int height}) _pngDimensions(ByteData png) {
  const signature = <int>[137, 80, 78, 71, 13, 10, 26, 10];
  expect(png.buffer.asUint8List(0, 8), orderedEquals(signature));
  return (
    width: png.getUint32(16, Endian.big),
    height: png.getUint32(20, Endian.big),
  );
}
