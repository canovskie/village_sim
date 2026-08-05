import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/world/tree_entity.dart';

void main() {
  group('TreeEntity fall', () {
    test('starts cleanly and falls away from the worker', () {
      final tree = TreeEntity(col: 4, row: 7, type: TreeType.pine)
        ..isMarkedForCutting = true
        ..isBeingChopped = true
        ..chopPhase = 2.0;

      tree.beginFall(awayFromScreenDelta: -3);

      expect(tree.isFelled, isTrue);
      expect(tree.isBeingChopped, isFalse);
      expect(tree.isMarkedForCutting, isFalse);
      expect(tree.chopPhase, -1);
      expect(tree.fallDirection, -1);
      expect(tree.fellProgress, 0);
      expect(tree.fallImpactEmitted, isFalse);
    });

    test('progress is clamped while the final pose is held', () {
      final tree = TreeEntity(col: 1, row: 1, type: TreeType.pine)
        ..beginFall(awayFromScreenDelta: 2);

      tree.fellAge = TreeEntity.kFallDuration * 0.5;
      expect(tree.fellProgress, closeTo(0.5, 0.0001));
      tree.fellAge = TreeEntity.kFallDuration * 2;
      expect(tree.fellProgress, 1);
      expect(TreeEntity.kImpactAge, lessThan(TreeEntity.kFallDuration));
    });
  });
}
