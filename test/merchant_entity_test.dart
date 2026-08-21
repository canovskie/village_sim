import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/entities/merchant_entity.dart';
import 'package:village_sim/entities/worker_entity.dart';

void main() {
  setUp(() {
    WorkerEntity.pathContext = null;
    WorkerEntity.roadSystem = null;
  });

  test('ziyaretçi giriş, selam, oyalanma ve çıkış evrelerini tamamlar', () {
    final visitor = MerchantEntity(
      startCol: 2,
      startRow: 2,
      browseX: 2,
      browseY: 2,
      exitX: 2,
      exitY: 2,
      visitorKind: VisitorKind.traveler,
      greetingLeft: 0.5,
      browseLeft: 0.5,
    );
    final rng = Random(7);

    visitor.step(0.1, rng);
    expect(visitor.phase, MerchantPhase.greeting);
    expect(visitor.waveTime, greaterThan(0));

    visitor.step(0.6, rng);
    expect(visitor.phase, MerchantPhase.browsing);

    visitor.step(0.6, rng);
    expect(visitor.phase, MerchantPhase.leaving);

    visitor.step(0.1, rng);
    expect(visitor.finished, isTrue);
  });

  test('yalnız insan kervan lideri ticaret yapar', () {
    MerchantEntity make({required bool leader, required bool cart}) =>
        MerchantEntity(
          startCol: 0,
          startRow: 0,
          browseX: 1,
          browseY: 1,
          exitX: 2,
          exitY: 2,
          visitorKind: VisitorKind.caravan,
          isGroupLeader: leader,
          hasCart: cart,
        );

    expect(make(leader: true, cart: false).canTrade, isTrue);
    expect(make(leader: false, cart: false).canTrade, isFalse);
    expect(make(leader: true, cart: true).canTrade, isFalse);
  });

  test('at arabası yaya kervancıdan daha ağır ilerler', () {
    final cart = MerchantEntity(
      startCol: 0,
      startRow: 0,
      browseX: 3,
      browseY: 3,
      exitX: 5,
      exitY: 5,
      hasCart: true,
    );
    final walker = MerchantEntity(
      startCol: 0,
      startRow: 0,
      browseX: 3,
      browseY: 3,
      exitX: 5,
      exitY: 5,
    );

    expect(cart.speed, lessThan(walker.speed));
  });
}
