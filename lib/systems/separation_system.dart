import 'dart:math';
import '../core/constants.dart';
import '../entities/villager_entity.dart';
import '../world/animal_entity.dart';
import 'locomotion.dart';

/// NPC'lere hafif ayrışma kuvveti uygular — iç içe geçmeyi önler.
/// Aktif çalışan entity'ler (hasat, kazma, balık tutma, inşa) sabit kalır;
/// hareketli olanlar onlardan itilir.
///
/// Spatial hash (1 tile bucket): O(n²) yerine O(n).
/// kSeparationRadius < 1 olduğu için 3×3 komşu bucket araması yeterli.
///
/// İKİ KANAL (git-gel düzeltmesi). Eskiden tek kanal vardı: konumu doğrudan
/// itmek. Yürüyen NPC hedefine gidiyor, separation onu yana atıyor, ertesi kare
/// hedefe geri dönüyordu — kalabalıkta gözle görülür bir titreme. Artık:
///   1. YÖNLENDİRME (asıl kanal) — komşudan kaçınma vektörü
///      [Locomotion.addAvoid] ile gidiş yönüne karışır. NPC hedefine giderken
///      kavis çizip yandan dolanır; ışınlanma yok.
///   2. AYIRMA (yalnız gerçek örtüşmede) — iki gövde fiilen iç içe geçtiyse
///      ([kOverlapFrac] × yarıçap altı) küçük bir konum düzeltmesi kalır.
///      Bu, sıfır hızda birbirine yapışmış NPC'leri ayırmak için gerekli.
void applySeparation({
  required double dt,
  required List<VillagerEntity> villagers,
  required Set<(int, int)> waterTiles,
  List<AnimalEntity> cows = const [],
}) {
  // (gridX, gridY, setter, isWorking, loco) — tüm hareketli entity'ler.
  // [loco] null ise (hayvanlar) yalnız konum kanalı çalışır.
  // VillagerEntity için sitClaimed=true → "working" sayılır: ateş başında
  // oturan ya da slota yürüyen NPC kendi pozisyonunda kalır, separation
  // perturbasyonu olmaz. Başkaları onların etrafında dönmeye devam eder.
  // Aksi takdirde seated NPC drift → isSeatedAtFire toggle → sitYScale flicker.
  final entities =
      <(double, double, void Function(double, double), bool, Locomotion?)>[
    for (final v in villagers)
      (v.gridX, v.gridY, (x, y) { v.gridX = x; v.gridY = y; }, v.sitClaimed,
          v.loco),
    for (final c in cows)
      (c.gridX, c.gridY, (x, y) { c.gridX = x; c.gridY = y; },
          c.isBeingMilked, null),
  ];

  if (entities.length < 2) return;

  /// Gerçek örtüşme eşiği — bunun altında konum düzeltmesi de devreye girer.
  const overlapFrac = 0.72;

  // Bucket grid: tile-bazlı (1×1 tile bucket).
  final buckets = <(int, int), List<int>>{};
  for (int i = 0; i < entities.length; i++) {
    final (x, y, _, _, _) = entities[i];
    final key = (x.floor(), y.floor());
    (buckets[key] ??= []).add(i);
  }

  for (int i = 0; i < entities.length; i++) {
    final (xi, yi, seti, workingI, locoI) = entities[i];
    if (workingI) continue; // çalışırken dokunma

    final bx = xi.floor();
    final by = yi.floor();
    double nx = xi, ny = yi;      // konum kanalı (yalnız gerçek örtüşme)
    double steerX = 0, steerY = 0; // yönlendirme kanalı

    // 3×3 komşu bucket — sadece yakın entity'ler.
    for (int dc = -1; dc <= 1; dc++) {
      for (int dr = -1; dr <= 1; dr++) {
        final neighbors = buckets[(bx + dc, by + dr)];
        if (neighbors == null) continue;
        for (final j in neighbors) {
          if (i == j) continue;
          final (xj, yj, _, _, _) = entities[j];
          final dx   = xi - xj;
          final dy   = yi - yj;
          final dist = sqrt(dx * dx + dy * dy);
          if (dist >= kSeparationRadius || dist <= 0.001) continue;

          final falloff = (kSeparationRadius - dist) / kSeparationRadius;
          // Radyal — birbirinden uzaklaştırma.
          final radX = dx / dist;
          final radY = dy / dist;
          // Tanjantsal (sabit +90° rot) — head-on deadlock'ı kırmak için.
          // İki entity için (dx, dy) işaretleri zıt → tangential bileşen de zıt
          // → biri kuzeye, diğeri güneye sapıp pas geçer; dans yapmazlar.
          final tanX = -dy / dist;
          final tanY =  dx / dist;

          // 1) Yönlendirme — gidiş yönüne karışacak birimsiz kaçınma vektörü.
          //    Tanjant ağırlığı burada radyalden yüksek: NPC geri itilmek
          //    yerine YANDAN DOLANIR (git-gel'in asıl çaresi).
          steerX += (radX * 0.6 + tanX * 1.0) * falloff;
          steerY += (radY * 0.6 + tanY * 1.0) * falloff;

          // 2) Ayırma — yalnız fiilen iç içe geçmişse.
          if (dist < kSeparationRadius * overlapFrac) {
            final push = falloff * kSeparationStrength * dt;
            nx += (radX + tanX * 0.35) * push;
            ny += (radY + tanY * 0.35) * push;
          }
        }
      }
    }

    if (locoI != null && (steerX != 0 || steerY != 0)) {
      final m = sqrt(steerX * steerX + steerY * steerY);
      // Birimlendirilip sınırlanır: kaçınma hedefi EZMEZ, büker. 1.0'ı geçseydi
      // NPC hedefini bırakıp komşudan kaçmaya başlardı.
      final k = (m > 1.0 ? 1.0 / m : 1.0) * 0.85;
      locoI.addAvoid(steerX * k, steerY * k);
    }

    // Engel tile'ına itme — waterTiles set'i pratikte _obstacles (su + maden
    // + solid bina). NPC bu tile'lara separation force ile sokulamaz.
    if (nx != xi || ny != yi) {
      final cx = nx.clamp(0.0, kCols - 1.0);
      final cy = ny.clamp(0.0, kRows - 1.0);
      if (!waterTiles.contains((cx.round(), cy.round()))) {
        seti(cx, cy);
      }
    }
  }
}
