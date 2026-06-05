import 'road_surface.dart';

/// Yerleştirilmiş bir yol parçası. Inşaat tamamlandığında RoadSystem'e eklenir.
class RoadTile {
  final int col;
  final int row;
  final RoadSurface surface;

  /// Render için stabil hash kaynağı (noise/varyant seçimi).
  late final int hash = (col * 73856093) ^ (row * 19349663);

  RoadTile({required this.col, required this.row, required this.surface});

  double get depth => (col + row).toDouble();
}
