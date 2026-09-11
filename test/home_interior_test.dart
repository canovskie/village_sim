import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/systems/npc/home_interior.dart';

void main() {
  test(
    'dekor tohumları kararlı; yeni saksı ve sepetler oda içinde engeldir',
    () {
      expect({
        for (int i = -6; i < 6; i++) InteriorStyle.fromSeed(i),
      }, containsAll(InteriorStyle.values));
      for (final f in HomeInteriorLayout.standard.furniture) {
        expect(f.x, greaterThanOrEqualTo(0));
        expect(f.y, greaterThanOrEqualTo(0));
        expect(f.x + f.width, lessThanOrEqualTo(HomeInteriorLayout.width));
        expect(f.y + f.depth, lessThanOrEqualTo(HomeInteriorLayout.depth));
        if (f.blocksWalking) {
          expect(
            HomeInteriorLayout.standard.walkable(
              f.x + f.width / 2,
              f.y + f.depth / 2,
            ),
            isFalse,
          );
        }
      }
    },
  );
  test('her hazır davranışa mobilyanın içinden geçmeden ulaşılır', () {
    for (final scenario in InteriorScenario.values) {
      final room = HomeInteriorSimulation()..setScenario(scenario);
      for (int i = 0; i < 500; i++) {
        room.update(0.05);
        for (final a in room.actors) {
          expect(
            room.layout.walkable(a.x, a.y),
            isTrue,
            reason: '$scenario / ${a.slot} eşyanın içinde: ${a.position}',
          );
        }
      }
      if (scenario != InteriorScenario.daily) {
        expect(room.actors.every((a) => a.path.isEmpty), isTrue);
        expect(room.actors.every((a) => a.activity == a.destination), isTrue);
        expect(room.actors.every((a) => a.poseAmount == 1), isTrue);
      }
    }
  });

  test('yatak ve sofradan kalkmadan yeni yürüyüş başlamaz', () {
    final room = HomeInteriorSimulation()..setScenario(InteriorScenario.sleep);
    for (int i = 0; i < 30; i++) {
      room.update(1);
    }
    final before = room.actors.first.position;
    room.setScenario(InteriorScenario.supper);
    room.update(0.1);
    expect(room.actors.first.position, before);
    expect(room.actors.first.poseAmount, lessThan(1));
    for (int i = 0; i < 20; i++) {
      room.update(1);
    }
    expect(
      room.actors.every((a) => a.activity == InteriorActivity.table),
      isTrue,
    );
  });

  test('dışarıdaki sakin içeride görünmez; gerçek uyku yatağa bağlanır', () {
    final room = HomeInteriorSimulation();
    room.syncResident(0, present: false, sleeping: false);
    final before = room.actors.first.position;
    room.update(1, automatic: false);
    expect(room.actors.first.present, isFalse);
    expect(room.actors.first.position, before);
    room.syncResident(0, present: true, sleeping: true);
    expect(room.actors.first.activity, InteriorActivity.sleeping);
    expect(room.actors.first.poseAmount, 1);
    expect(room.actors.first.path, isEmpty);
  });

  test('boş ev ve duraklatma geçerlidir', () {
    final empty = HomeInteriorSimulation(residents: 0)..update(0.5);
    expect(empty.actors, isEmpty);
    final room = HomeInteriorSimulation();
    final before = room.actors.first.position;
    room.update(0);
    room.update(double.nan);
    expect(room.time, 0);
    expect(room.actors.first.position, before);
  });
}
