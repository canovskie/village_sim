import '../world/resource_box.dart';
import '../world/hay_entity.dart';

/// Yere düşen kaynak kutuları ve saman yığınları için tile-bazlı yerleştirme.
///
/// Mantık:
/// - Çağırıcı yaklaşık `(gridX, gridY)` verir (örn. kesilen ağacın merkezi).
/// - En yakın tile merkezine snap'lenir.
/// - O tile'daki aktif (carry edilmemiş, teslim edilmemiş) kutu sayısına göre
///   3×3 sub-grid içinden bir slot atanır → kutular üst üste değil, mini grid
///   içinde dağılarak yığılır.
/// - 9'dan fazla kutu olursa modulo + jitter ile dağılır (görsel sıkışma yok).
/// - `spawnTime` doldurulur → renderer drop animation tetikler.
class ResourcePlacement {
  // 3×3 sub-grid offset'leri (tile center'a göre, tile birimi).
  // Stack hissi için: ön-sıra (y+) önce dolar, sonra orta, sonra arka.
  static const List<(double, double)> _slotOffsets = [
    (0.00, 0.15),  // 0: ön-orta (en önde, en görünür)
    (-0.20, 0.10), // 1: ön-sol
    (0.20, 0.10),  // 2: ön-sağ
    (0.00, 0.00),  // 3: orta
    (-0.20, -0.05),// 4: orta-sol
    (0.20, -0.05), // 5: orta-sağ
    (0.00, -0.15), // 6: arka-orta
    (-0.20, -0.20),// 7: arka-sol
    (0.20, -0.20), // 8: arka-sağ
  ];

  /// Sub-grid slot offset'i — slotIndex 0..8 düzenli yerleşim,
  /// 9+ olursa baz dokuzluk + küçük rastgele jitter.
  static (double, double) offsetFor(int slotIndex) {
    final base = _slotOffsets[slotIndex % _slotOffsets.length];
    if (slotIndex < 9) return base;
    // Overflow: deterministik jitter (slotIndex hash'inden).
    final h = slotIndex * 73856093;
    final jx = ((h & 0xFF) / 255.0 - 0.5) * 0.15;
    final jy = (((h >> 8) & 0xFF) / 255.0 - 0.5) * 0.15;
    return (base.$1 + jx, base.$2 + jy);
  }

  /// [box] için yer hazırla: yaklaşık [gridX]/[gridY]'yi tile merkezine snap'le,
  /// o tile'daki kutu sayısına göre slot ata, drop animation için zaman damgası.
  static void placeBox(ResourceBox box, double gridX, double gridY,
      List<ResourceBox> allBoxes, double time) {
    final col = gridX.floor();
    final row = gridY.floor();
    box.gridX = col + 0.5;
    box.gridY = row + 0.5;
    box.spawnTime = time;
    box.slotIndex = _countAtTile(allBoxes, col, row, exclude: box);
  }

  /// Saman pile için yer hazırla. Aynı tile'da hâlihazırda pile varsa onun
  /// üstüne katman ekle (pileSize artırır), yeni instance yaratma —
  /// caller karar verir, bu helper sadece slot atar.
  static void placeHay(HayEntity hay, double gridX, double gridY,
      List<HayEntity> allHay, double time) {
    final col = gridX.floor();
    final row = gridY.floor();
    hay.gridX = col + 0.5;
    hay.gridY = row + 0.5;
    hay.spawnTime = time;
    hay.slotIndex = _countHayAtTile(allHay, col, row, exclude: hay);
  }

  static int _countAtTile(List<ResourceBox> boxes, int col, int row,
      {ResourceBox? exclude}) {
    int n = 0;
    for (final b in boxes) {
      if (identical(b, exclude)) continue;
      if (b.isBeingCarried || b.isDelivered) continue;
      if (b.gridX.floor() == col && b.gridY.floor() == row) n++;
    }
    return n;
  }

  static int _countHayAtTile(List<HayEntity> hay, int col, int row,
      {HayEntity? exclude}) {
    int n = 0;
    for (final h in hay) {
      if (identical(h, exclude)) continue;
      if (h.isBeingCarried || h.isDelivered) continue;
      if (h.gridX.floor() == col && h.gridY.floor() == row) n++;
    }
    return n;
  }
}

/// Drop animasyonu süresi (sn). spawnTime'dan sonraki bu süre boyunca
/// renderer kutuyu yukarıdan iniş + bounce ile çizer.
const double kDropDuration = 0.45;
