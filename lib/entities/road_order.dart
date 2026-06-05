import '../world/road_surface.dart';

/// Builder'ın işleyeceği yol döşeme görevi. BuildOrder'ın yol versiyonu;
/// paralel kuyrukta tutulur, builder her iki kuyruğu da tarar.
class RoadOrder {
  final int col;
  final int row;
  final RoadSurface surface;

  bool assigned = false;
  bool completed = false;
  double progress = 0.0;

  RoadOrder({required this.col, required this.row, required this.surface});
}
