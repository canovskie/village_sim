import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/world/mine_node.dart';
import 'package:village_sim/world/world_generator.dart';

void main() {
  // Kontrollü kaynak açılımı: madenler reach bandlarında üretilmeli —
  // ilk yerleşim reach'inde (span ~50) HİÇ maden yok; her tür kendi bandında
  // en az bir grup bulunur (ilk grup dar banda zorlanır).
  test('madenler reach bandlarında, başlangıç reach\'inde maden yok', () {
    // Worst-case görünürlük metriği (world_generator._spanNeeded ile aynı).
    double spanNeeded(int c, int r) {
      const kCols = 128, kRows = 128;
      final du = ((c - r) - (kCols - kRows) / 2).abs();
      final dv = ((c + r) - (kCols + kRows - 2) / 2).abs();
      final su = du * 1.86, sv = dv * 1.65;
      return su > sv ? su : sv;
    }

    for (int seed = 1; seed <= 30; seed++) {
      final result = WorldGenerator(seed).generate();
      final byType = <OreType, List<double>>{};
      for (final n in result.mineNodes) {
        byType.putIfAbsent(n.type, () => []).add(spanNeeded(n.col, n.row));
      }
      for (final type in OreType.values) {
        final spans = byType[type];
        expect(spans, isNotNull,
            reason: 'seed=$seed: ${type.label} hiç üretilmedi');
        final minBand = switch (type) {
          OreType.stone => 56.0,
          OreType.coal => 72.0,
          OreType.iron => 88.0,
        };
        final lo = spans!.reduce((a, b) => a < b ? a : b);
        final hi = spans.reduce((a, b) => a > b ? a : b);
        expect(lo, greaterThanOrEqualTo(minBand),
            reason: 'seed=$seed: ${type.label} bandından erken ($lo < $minBand)');
        expect(hi, lessThanOrEqualTo(112.0),
            reason: 'seed=$seed: ${type.label} erişilmez derinlikte ($hi)');
        // İlk grup dar banda zorlanır → en yakın grup band+16 içinde olmalı.
        expect(lo, lessThanOrEqualTo(minBand + 16),
            reason: 'seed=$seed: ${type.label} yakın bandda grup yok ($lo)');
      }
    }
  });
}
