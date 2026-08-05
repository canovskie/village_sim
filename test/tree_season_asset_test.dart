import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('seasonal pine sprites are bundled with matching dimensions', () async {
    final summer = await rootBundle.load('assets/trees/pine.png');
    final autumn = await rootBundle.load('assets/trees/pine_autumn.png');
    final winter = await rootBundle.load('assets/trees/pine_winter.png');

    expect(_pngDimensions(summer), (width: 382, height: 669));
    expect(_pngDimensions(autumn), (width: 382, height: 669));
    expect(_pngDimensions(winter), (width: 382, height: 669));
  });
}

({int width, int height}) _pngDimensions(ByteData png) {
  expect(
    png.buffer.asUint8List(0, 8),
    orderedEquals(const [137, 80, 78, 71, 13, 10, 26, 10]),
  );
  return (
    width: png.getUint32(16, Endian.big),
    height: png.getUint32(20, Endian.big),
  );
}
