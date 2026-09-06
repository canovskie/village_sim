import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/rendering/resource_renderer.dart';
import 'package:village_sim/world/resource_box.dart';

void main() {
  test('yerde doğan yemek sepeti ağır kaynak kasası kadar şişmez', () {
    final basket = ResourceRenderer.groundSpriteWidth(
      ResourceBoxType.foodBasket,
    );
    final crate = ResourceRenderer.groundSpriteWidth(ResourceBoxType.woodChunk);

    expect(basket, 16);
    expect(basket, lessThanOrEqualTo(crate / 2));
  });
}
