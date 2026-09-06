// Combat koreografilerinin ortak, sahneden bağımsız hareket zarfları.
// İmparatorluk safı ve NPC düellosu aynı hamle dilini kullanır; taraf seçimi,
// hasar ve toplumsal sonuçlar kendi sistemlerinde kalır.

double combatSmooth(double value) {
  final t = value.clamp(0.0, 1.0).toDouble();
  return t * t * (3.0 - 2.0 * t);
}

/// Gecikmeli tek hamle zarfı: yaklaşır, temas eder, başlangıç noktasına döner.
double combatLunge(double progress, [double delay = 0]) {
  final t = ((progress - delay) / (1.0 - delay)).clamp(0.0, 1.0).toDouble();
  if (t < 0.56) return combatSmooth(t / 0.56);
  return 1.0 - combatSmooth((t - 0.56) / 0.44);
}

class NpcCombatMotion {
  /// Pozitif değer rakibe doğru, negatif değer ondan uzağa harekettir.
  final double aAdvance;
  final double bAdvance;
  final bool aStriking;
  final bool bStriking;
  final bool aHit;
  final bool bHit;

  /// Fiziksel sonuç bu karede uygulanabilir. Bir düelloda yalnız ilk temas
  /// tüketilir; sonraki temaslar yalnız animasyondur.
  final bool impact;

  const NpcCombatMotion({
    required this.aAdvance,
    required this.bAdvance,
    required this.aStriking,
    required this.bStriking,
    required this.aHit,
    required this.bHit,
    required this.impact,
  });
}

/// İki NPC'nin dönüşümlü hamleleri. Kan davası daha sık ve daha derin temas
/// üretir; [aStarts] mizaç/zarla seçilen ilk saldırganı ritme taşır.
NpcCombatMotion npcCombatMotion({
  required double elapsed,
  required double duration,
  required bool feud,
  required bool aStarts,
}) {
  final total = duration <= 0 ? 0.001 : duration;
  final progress = (elapsed / total).clamp(0.0, 1.0).toDouble();
  if (progress < 0.12) {
    final close = combatSmooth(progress / 0.12) * 0.16;
    return NpcCombatMotion(
      aAdvance: close,
      bAdvance: close,
      aStriking: false,
      bStriking: false,
      aHit: false,
      bHit: false,
      impact: false,
    );
  }
  if (progress >= 0.84) {
    final part = combatSmooth((progress - 0.84) / 0.16);
    return NpcCombatMotion(
      aAdvance: 0.16 - part * 0.25,
      bAdvance: 0.16 - part * 0.25,
      aStriking: false,
      bStriking: false,
      aHit: false,
      bHit: false,
      impact: false,
    );
  }

  final exchanges = feud ? 5 : 3;
  final combatProgress = (progress - 0.12) / 0.72;
  final scaled = combatProgress * exchanges;
  final exchange = scaled.floor().clamp(0, exchanges - 1);
  final local = scaled - exchange;
  final lunge = combatLunge(local);
  final aAttacks = exchange.isEven == aStarts;
  final strike = lunge > 0.38;
  final hit = lunge > 0.78;
  final reach = feud ? 0.58 : 0.46;
  final recoil = feud ? 0.24 : 0.16;

  return NpcCombatMotion(
    aAdvance: 0.16 + (aAttacks ? lunge * reach : (hit ? -recoil : 0)),
    bAdvance: 0.16 + (!aAttacks ? lunge * reach : (hit ? -recoil : 0)),
    aStriking: aAttacks && strike,
    bStriking: !aAttacks && strike,
    aHit: !aAttacks && hit,
    bHit: aAttacks && hit,
    impact: hit,
  );
}
