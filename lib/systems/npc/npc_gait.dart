import 'dart:math';

/// Screen-space leg pose for the small frontal/three-quarter NPC silhouette.
///
/// This deliberately is not an exact two-bone IK solve. With a 31 px hip to
/// ankle height and two 17 px bones, exact IK has to push the knee about 7 px
/// sideways even while standing. At game scale that turns both legs into the
/// same dark zig-zag. Instead the knee stays almost below the hip and bends
/// only as the foot travels; the stance boot remains planted on the floor.
({(double, double) hip, (double, double) knee, (double, double) ankle})
npcLegPose(double hipX, double swing, double lift) {
  final hip = (hipX, -36.0);
  final safeLift = lift.clamp(0.0, 3.0);
  final ankleY = -5.0 - safeLift * 3;
  final stride = (sin(swing) * 13).clamp(-7.0, 7.0);
  final ankle = (hipX - stride, ankleY);

  // The knee follows much less of the horizontal travel than the boot. This
  // reads as a hinged leg, without the permanent sideways kink of exact IK.
  final bend = (stride.abs() * 0.35 + safeLift * 0.55).clamp(0.0, 2.8);
  final bendDirection = stride == 0 ? 0.0 : stride.sign;
  final knee = (
    (hip.$1 + ankle.$1) / 2 + bendDirection * bend,
    (hip.$2 + ankle.$2) / 2 - safeLift * 0.18,
  );
  return (hip: hip, knee: knee, ankle: ankle);
}
