import '../buildings/building_type.dart';

class BuildOrder {
  final BuildingType type;
  final int col;
  final int row;

  bool assigned = false;   // a builder picked it up
  bool completed = false;  // building has been placed

  double progress = 0.0;   // 0..1 during construction

  BuildOrder({required this.type, required this.col, required this.row});
}
