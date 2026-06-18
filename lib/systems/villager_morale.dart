/// Bireysel köylü moralinin KOŞUL formülü. Saf/yan-etkisiz: girdi koşullarından
/// bir hedef moral (0..1) + baskın sebep etiketi üretir. Sahne (`scene_tick`)
/// her köylü için ~1sn'de bir çağırır ve `VillagerEntity.morale`'i bu hedefe
/// yavaşça süzer. Yaşam olaylarının anlık etkisi ayrıca `feel(moodDelta)`
/// üzerinden gelir (bkz. villager_entity).
///
/// Cozy/no-fail: değerler ölçülü; en kötü koşul yığını bile moralı ~0.1'in
/// altına nadiren indirir, toparlama hızlıdır.
library;

class MoraleEval {
  final double target; // 0..1
  final String reason; // panelde gösterilecek baskın sebep
  const MoraleEval(this.target, this.reason);
}

/// [estateMood] köylünün zümresinin morali (0..1, ~0.55 nötr).
/// [elderRespected] yaşlı + "huzur/saygı" politikası aktif.
MoraleEval evaluateVillagerMorale({
  required bool homeless,
  required bool starving,
  required bool lowWater,
  required bool cold, // gece + ateş/ısı yok
  required double estateMood,
  required bool elderRespected,
}) {
  const base = 0.62;
  double t = base;

  // Negatif koşullar (sebep adayları, büyüklükçe).
  final neg = <(double, String)>[];
  if (homeless) {
    t -= 0.30;
    neg.add((0.30, 'evsiz'));
  }
  if (starving) {
    t -= 0.26;
    neg.add((0.26, 'aç'));
  }
  if (cold) {
    t -= 0.16;
    neg.add((0.16, 'üşüyor'));
  }
  if (lowWater) {
    t -= 0.14;
    neg.add((0.14, 'susuz'));
  }

  // Zümre durumu: memnun zümre üyesini kaldırır, küskün zümre çeker (±~0.18).
  final estateShift = (estateMood - 0.55) * 0.42;
  t += estateShift;

  // Yaşlıya saygı politikası.
  if (elderRespected) t += 0.08;

  t = t.clamp(0.0, 1.0);

  // Baskın sebep: en büyük negatif; yoksa zümre/seviye temelli olumlu etiket.
  String reason;
  if (neg.isNotEmpty) {
    neg.sort((a, b) => b.$1.compareTo(a.$1));
    reason = neg.first.$2;
  } else if (estateShift < -0.05) {
    reason = 'zümresi küskün';
  } else if (t >= 0.75) {
    reason = 'huzurlu';
  } else if (t >= 0.5) {
    reason = 'hoşnut';
  } else {
    reason = 'idare ediyor';
  }

  return MoraleEval(t, reason);
}
