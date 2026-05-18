import 'building_type.dart';

class BuildingEntity {
  final BuildingType type;
  final int col;
  final int row;

  /// Maden ocağı gibi içeride çalışma olan binalar için
  bool isActive = false;

  BuildingEntity({required this.type, required this.col, required this.row});

  int get cols => kBuildingMeta[type]!.cols;
  int get rows => kBuildingMeta[type]!.rows;

  /// Depth for painter's algorithm: front corner col+row sum
  double get depth => (col + cols + row + rows).toDouble();
}
