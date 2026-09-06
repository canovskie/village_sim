import 'dart:math';

/// Two equal bone lengths with an ankle target on (or above) the ground.
/// The stance foot never swings below the floor as a rigid pendulum would.
({(double, double) hip, (double, double) knee, (double, double) ankle})
npcLegPose(double hipX, double swing, double lift) {
  final hip = (hipX, -36.0);
  const bone = 17.0;
  final ankleY = -5.0 - lift.clamp(0.0, 3.0) * 3;
  final maxStride = sqrt(4 * bone * bone - pow(ankleY - hip.$2, 2));
  final stride = (sin(swing) * 18).clamp(-maxStride, maxStride);
  final ankle = (hipX - stride, ankleY);
  final dx = ankle.$1 - hip.$1, dy = ankle.$2 - hip.$2;
  final distance = sqrt(dx * dx + dy * dy);
  final bend = sqrt(max(0.0, bone * bone - distance * distance / 4));
  final knee = (
    (hip.$1 + ankle.$1) / 2 + dy / distance * bend,
    (hip.$2 + ankle.$2) / 2 - dx / distance * bend,
  );
  return (hip: hip, knee: knee, ankle: ankle);
}
