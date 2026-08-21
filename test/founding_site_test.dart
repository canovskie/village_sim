import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/core/constants.dart';
import 'package:village_sim/systems/founding_site.dart';

void main() {
  test('first hearth accepts the dry central founding area', () {
    expect(isFoundingHearthTile(kCols ~/ 2, kRows ~/ 2), isTrue);
    expect(
      isFoundingHearthTile(
        kCols ~/ 2 + kFoundingHearthHalfCols - 1,
        kRows ~/ 2 + kFoundingHearthHalfRows - 1,
      ),
      isTrue,
    );
  });

  test('first hearth rejects map-edge and lakeside displacement', () {
    expect(isFoundingHearthTile(0, 0), isFalse);
    expect(isFoundingHearthTile(kCols - 1, kRows - 1), isFalse);
    expect(
      isFoundingHearthTile(
        kCols ~/ 2 + kFoundingHearthHalfCols + 2,
        kRows ~/ 2,
      ),
      isFalse,
    );
  });
}
