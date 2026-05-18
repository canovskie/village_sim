import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/core/constants.dart';
import 'package:village_sim/entities/lumber_camp_entity.dart';
import 'package:village_sim/world/tree_entity.dart';

void main() {
  group('LumberCampEntity territory', () {
    test('marks at most kLumberMaxMarked trees per management cycle', () {
      final lc = LumberCampEntity(buildingCol: 10, buildingRow: 10);
      // Bina merkezi (11, 11). Etrafa 5 ağaç koy — hepsi territory içinde.
      final trees = <TreeEntity>[
        for (int i = 0; i < 5; i++)
          TreeEntity(col: 11 + i, row: 11, type: TreeType.pine),
      ];

      // İlk update bölge yönetimini hemen tetikler (manage timer 0).
      lc.update(0.016, trees, Random(0));

      final marked = trees.where((t) => t.isMarkedForCutting).length;
      expect(marked, kLumberMaxMarked,
          reason: 'aynı anda en fazla $kLumberMaxMarked ağaç işaretli olmalı');
    });

    test('plants a sapling when below kLumberTargetTrees', () {
      final lc = LumberCampEntity(buildingCol: 10, buildingRow: 10);
      // Sadece 2 ağaç var → hedef 5'in altında → fidan dikilmeli.
      final trees = <TreeEntity>[
        TreeEntity(col: 11, row: 11, type: TreeType.pine),
        TreeEntity(col: 12, row: 11, type: TreeType.pine),
      ];
      final initial = trees.length;

      lc.update(0.016, trees, Random(0));

      expect(trees.length, greaterThan(initial),
          reason: 'eksik ağaç → bir fidan eklenmiş olmalı');
      // Yeni eklenen büyüyor olmalı.
      final saplings = trees.where((t) => t.isGrowing).toList();
      expect(saplings.length, 1);
    });

    test('does not plant when already at kLumberTargetTrees', () {
      final lc = LumberCampEntity(buildingCol: 10, buildingRow: 10);
      // Tam hedef sayıda ağaç → fidan dikilmemeli.
      final trees = <TreeEntity>[
        for (int i = 0; i < kLumberTargetTrees; i++)
          TreeEntity(col: 11 + (i % 3), row: 11 + (i ~/ 3),
                     type: TreeType.pine),
      ];
      final initial = trees.length;

      lc.update(0.016, trees, Random(0));

      expect(trees.length, initial);
    });

    test('does not mark trees outside territory', () {
      final lc = LumberCampEntity(buildingCol: 10, buildingRow: 10);
      // Bina merkezi (11, 11). Territory yarıçapı 6 → (20, 20) çok uzak.
      final trees = <TreeEntity>[
        TreeEntity(col: 25, row: 25, type: TreeType.pine),
      ];

      lc.update(0.016, trees, Random(0));

      expect(trees.first.isMarkedForCutting, isFalse);
    });
  });
}
