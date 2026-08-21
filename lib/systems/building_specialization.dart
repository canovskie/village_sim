import '../buildings/building_function.dart';
import '../buildings/building_type.dart';
import '../characters/life_stage.dart';

/// Geç dönem binalarının birbirine karışmayan saf kuralları.
///
/// Sahne bu fonksiyonları uygular, bina paneli de aynı sabitleri okur. Böylece
/// künyede yazan menzil/oran ile simülasyondaki gerçek etki ayrışmaz.

// ─── Hamam: yakacak ↔ yerel bakım ───────────────────────────────────

const double kBathhouseFuelSeconds = kGameDaySeconds;

class BathhouseFuelStep {
  final double secondsLeft;
  final int woodUsed;
  final bool active;

  const BathhouseFuelStep({
    required this.secondsLeft,
    required this.woodUsed,
    required this.active,
  });
}

/// Külhan yalnız menzilde hasta/yaralı varken yanar. Kullanılmayan sıcaklık
/// saklanır; hasta yokken sayaç akmaz ve odun harcanmaz.
BathhouseFuelStep stepBathhouseFuel({
  required double secondsLeft,
  required double dt,
  required int woodAvailable,
  required bool hasPatient,
}) {
  if (!hasPatient) {
    return BathhouseFuelStep(
      secondsLeft: secondsLeft.clamp(0.0, kBathhouseFuelSeconds),
      woodUsed: 0,
      active: false,
    );
  }
  final remaining = (secondsLeft - dt).clamp(0.0, kBathhouseFuelSeconds);
  if (remaining > 0) {
    return BathhouseFuelStep(secondsLeft: remaining, woodUsed: 0, active: true);
  }
  if (woodAvailable < kBathhouseFuelWood) {
    return const BathhouseFuelStep(secondsLeft: 0, woodUsed: 0, active: false);
  }
  return const BathhouseFuelStep(
    secondsLeft: kBathhouseFuelSeconds,
    woodUsed: kBathhouseFuelWood,
    active: true,
  );
}

double bathhouseRecoveryRate(bool coveredByActiveBathhouse) =>
    coveredByActiveBathhouse ? 1.0 + kBathhouseRecoveryBonus : 1.0;

double bathhouseIllnessRisk(bool coveredByActiveBathhouse) =>
    coveredByActiveBathhouse ? kBathhouseIllnessRiskMultiplier : 1.0;

// ─── Anıt: kurulduğu andaki kimliği saklar ────────────────────────

String monumentInscription({
  required String regimeTitle,
  required String houseIdentity,
  required int day,
}) => '$regimeTitle · $houseIdentity · $day. gün';

// ─── Çan Kulesi: yerel alarm örgütlenmesi ───────────────────────────

bool withinBuildingEffect({
  required BuildingType type,
  required int col,
  required int row,
  required double targetX,
  required double targetY,
}) {
  final meta = kBuildingMeta[type]!;
  if (meta.effectRadius <= 0) return false;
  final x = col + meta.cols / 2.0;
  final y = row + meta.rows / 2.0;
  final dx = targetX - x;
  final dy = targetY - y;
  return dx * dx + dy * dy <= meta.effectRadius * meta.effectRadius;
}

double bellGuardResponseRange(double baseRange, {required bool covered}) =>
    baseRange * (covered ? kBellGuardResponseMultiplier : 1.0);

// ─── Han: gerçek ziyaretçi/ticaret temposu ──────────────────────────────

double merchantVisitGap(double base, {required bool hasCaravanserai}) =>
    base * (hasCaravanserai ? kCaravanseraiVisitGapMultiplier : 1.0);

double merchantVisitDuration(double base, {required bool hasCaravanserai}) =>
    base * (hasCaravanserai ? kCaravanseraiVisitDurationMultiplier : 1.0);
