import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/core/constants.dart';
import 'package:village_sim/entities/woodcutter_entity.dart';
import 'package:village_sim/world/tree_entity.dart';

void main() {
  group('WoodcutterEntity state machine', () {
    test('idle picks a marked tree as target', () {
      final w = WoodcutterEntity(startCol: 5, startRow: 5);
      final tree = TreeEntity(col: 6, row: 6, type: TreeType.pine)
        ..isMarkedForCutting = true;
      final trees = <TreeEntity>[tree];

      w.update(0.016, trees, Random(0));

      expect(w.state, WoodcutterState.walkingToTree);
      expect(tree.isBeingChopped, isTrue);
    });

    test('idle ignores unmarked / felled / already-chopped trees', () {
      final w = WoodcutterEntity(startCol: 5, startRow: 5);
      final trees = <TreeEntity>[
        TreeEntity(col: 6, row: 5, type: TreeType.pine), // unmarked
        TreeEntity(col: 7, row: 5, type: TreeType.pine)
          ..isMarkedForCutting = true ..isFelled = true, // already felled
        TreeEntity(col: 8, row: 5, type: TreeType.pine)
          ..isMarkedForCutting = true ..isBeingChopped = true, // someone else's
      ];

      w.update(0.016, trees, Random(0));
      expect(w.state, WoodcutterState.idle);
    });

    test('reaches tree, switches to chopping', () {
      final w = WoodcutterEntity(startCol: 6, startRow: 6);
      final tree = TreeEntity(col: 6, row: 6, type: TreeType.pine)
        ..isMarkedForCutting = true;
      final trees = <TreeEntity>[tree];

      // Birkaç frame sürmeli — ağaç hemen yanında olunca arriveD ≤ 0.9.
      for (int i = 0; i < 5; i++) {
        w.update(0.016, trees, Random(0));
        if (w.state == WoodcutterState.chopping) break;
      }
      expect(w.state, WoodcutterState.chopping);
    });

    test('chopping for kChopDuration produces harvestReady once', () {
      final w = WoodcutterEntity(startCol: 6, startRow: 6);
      final tree = TreeEntity(col: 6, row: 6, type: TreeType.pine)
        ..isMarkedForCutting = true;
      final trees = <TreeEntity>[tree];

      // Chopping state'ine ulaş
      while (w.state != WoodcutterState.chopping) {
        w.update(0.05, trees, Random(0));
      }

      // kChopDuration boyunca tick'le
      int harvestCount = 0;
      double elapsed = 0;
      while (elapsed < kChopDuration + 0.5) {
        w.update(0.05, trees, Random(0));
        if (w.harvestReady) harvestCount++;
        elapsed += 0.05;
      }

      expect(harvestCount, 1, reason: 'harvestReady must fire exactly once');
      expect(tree.isFelled, isTrue);
      expect(w.state, WoodcutterState.idle);
    });

    test('chopping aborts when tree gets felled externally', () {
      final w = WoodcutterEntity(startCol: 6, startRow: 6);
      final tree = TreeEntity(col: 6, row: 6, type: TreeType.pine)
        ..isMarkedForCutting = true;
      final trees = <TreeEntity>[tree];

      while (w.state != WoodcutterState.chopping) {
        w.update(0.05, trees, Random(0));
      }
      tree.isFelled = true; // başka bir aktör kesti
      w.update(0.05, trees, Random(0));

      expect(w.state, WoodcutterState.idle);
    });
  });
}
