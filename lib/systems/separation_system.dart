import 'dart:math';
import '../core/constants.dart';
import '../entities/villager_entity.dart';
import '../world/animal_entity.dart';
import 'locomotion.dart';

// Hot-path scratch storage. Separation runs once per rendered frame, so
// allocating an entity record (including a setter closure) plus a fresh hash
// map/list graph for every actor creates avoidable GC pressure in large
// villages. These buffers grow to the high-water mark and are reused.
final Map<(int, int), List<int>> _separationBuckets = {};
final List<List<int>> _activeSeparationBuckets = [];
final List<double> _sepX = [];
final List<double> _sepY = [];
final List<double> _sepPushX = [];
final List<double> _sepPushY = [];
final List<double> _sepSteerX = [];
final List<double> _sepSteerY = [];
final List<bool> _sepWorking = [];

void _ensureSeparationCapacity(int count) {
  while (_sepX.length < count) {
    _sepX.add(0);
    _sepY.add(0);
    _sepPushX.add(0);
    _sepPushY.add(0);
    _sepSteerX.add(0);
    _sepSteerY.add(0);
    _sepWorking.add(false);
  }
}

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
  Set<VillagerEntity> fixedVillagers = const {},
}) {
  final villagerCount = villagers.length;
  final count = villagerCount + cows.length;
  if (count < 2) return;

  _ensureSeparationCapacity(count);
  // Keep bucket lists alive between frames. The map grows only to the number
  // of world tiles actors have occupied, while its per-frame allocations drop
  // to zero after warm-up.
  for (final bucket in _activeSeparationBuckets) {
    bucket.clear();
  }
  _activeSeparationBuckets.clear();
  for (int i = 0; i < count; i++) {
    final isVillager = i < villagerCount;
    final x = isVillager ? villagers[i].gridX : cows[i - villagerCount].gridX;
    final y = isVillager ? villagers[i].gridY : cows[i - villagerCount].gridY;
    _sepX[i] = x;
    _sepY[i] = y;
    _sepPushX[i] = 0;
    _sepPushY[i] = 0;
    _sepSteerX[i] = 0;
    _sepSteerY[i] = 0;
    // A seated villager / milked animal is an immovable obstacle: others
    // still avoid it, but it must not drift.
    _sepWorking[i] = isVillager
        ? villagers[i].sitClaimed || fixedVillagers.contains(villagers[i])
        : cows[i - villagerCount].isBeingMilked;
    final key = (x.floor(), y.floor());
    final bucket = _separationBuckets[key] ??= <int>[];
    if (bucket.isEmpty) _activeSeparationBuckets.add(bucket);
    bucket.add(i);
  }

  /// Gerçek örtüşme eşiği — bunun altında konum düzeltmesi de devreye girer.
  const overlapFrac = 0.72;

  // Each unordered pair is evaluated once. The old outer-loop formulation
  // evaluated i→j and j→i separately even though the forces are symmetric.
  for (int i = 0; i < count; i++) {
    final xi = _sepX[i], yi = _sepY[i];
    final bx = xi.floor();
    final by = yi.floor();
    // 3×3 komşu bucket — sadece yakın entity'ler.
    for (int dc = -1; dc <= 1; dc++) {
      for (int dr = -1; dr <= 1; dr++) {
        final neighbors = _separationBuckets[(bx + dc, by + dr)];
        if (neighbors == null) continue;
        for (final j in neighbors) {
          if (j <= i) continue;
          final xj = _sepX[j], yj = _sepY[j];
          final dx = xi - xj;
          final dy = yi - yj;
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
          final tanY = dx / dist;

          // 1) Yönlendirme — gidiş yönüne karışacak birimsiz kaçınma vektörü.
          //    Tanjant ağırlığı burada radyalden yüksek: NPC geri itilmek
          //    yerine YANDAN DOLANIR (git-gel'in asıl çaresi).
          final steerX = (radX * 0.6 + tanX) * falloff;
          final steerY = (radY * 0.6 + tanY) * falloff;
          if (!_sepWorking[i]) {
            _sepSteerX[i] += steerX;
            _sepSteerY[i] += steerY;
          }
          if (!_sepWorking[j]) {
            _sepSteerX[j] -= steerX;
            _sepSteerY[j] -= steerY;
          }

          // 2) Ayırma — yalnız fiilen iç içe geçmişse.
          if (dist < kSeparationRadius * overlapFrac) {
            final push = falloff * kSeparationStrength * dt;
            final pushX = (radX + tanX * 0.35) * push;
            final pushY = (radY + tanY * 0.35) * push;
            if (!_sepWorking[i]) {
              _sepPushX[i] += pushX;
              _sepPushY[i] += pushY;
            }
            if (!_sepWorking[j]) {
              _sepPushX[j] -= pushX;
              _sepPushY[j] -= pushY;
            }
          }
        }
      }
    }
  }

  // Apply the accumulated result only after all pairs were evaluated, keeping
  // the same snapshot semantics as the previous record-based implementation.
  for (int i = 0; i < count; i++) {
    if (_sepWorking[i]) continue;
    final steerX = _sepSteerX[i], steerY = _sepSteerY[i];
    if (i < villagerCount && (steerX != 0 || steerY != 0)) {
      final m = sqrt(steerX * steerX + steerY * steerY);
      // Birimlendirilip sınırlanır: kaçınma hedefi EZMEZ, büker. 1.0'ı geçseydi
      // NPC hedefini bırakıp komşudan kaçmaya başlardı.
      final k = (m > 1.0 ? 1.0 / m : 1.0) * 0.85;
      villagers[i].loco.addAvoid(steerX * k, steerY * k);
    }

    // Engel tile'ına itme — waterTiles set'i pratikte _obstacles (su + maden
    // + solid bina). NPC bu tile'lara separation force ile sokulamaz.
    final xi = _sepX[i], yi = _sepY[i];
    final nx = xi + _sepPushX[i], ny = yi + _sepPushY[i];
    if (nx != xi || ny != yi) {
      final cx = nx.clamp(0.0, kCols - 1.0);
      final cy = ny.clamp(0.0, kRows - 1.0);
      if (!waterTiles.contains((cx.round(), cy.round()))) {
        if (i < villagerCount) {
          villagers[i]
            ..gridX = cx
            ..gridY = cy;
        } else {
          cows[i - villagerCount]
            ..gridX = cx
            ..gridY = cy;
        }
      }
    }
  }
}
