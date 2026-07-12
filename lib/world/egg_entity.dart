/// Tavuğun bıraktığı GÖRÜNÜR yumurta. Bir süre yerde durur, sonra çözülür:
///  - [willHatch] ise civciv çıkar (sürü büyür),
///  - değilse toplanır → +1 food (kümes bakımının soyutlaması).
/// Kısa ömürlü/efemer — kayda yazılmaz (reload'da yeni döngü üretir).
class EggEntity {
  final int barnCol;
  final int barnRow;
  double gridX;
  double gridY;
  final double spawnTime;  // drop animasyonu için sahne zamanı
  double age = 0;          // sn
  final bool willHatch;
  final double resolveAt;  // bu süreden sonra çözülür (toplan/çatla)

  EggEntity({
    required this.barnCol,
    required this.barnRow,
    required this.gridX,
    required this.gridY,
    required this.spawnTime,
    required this.willHatch,
    required this.resolveAt,
  });

  double get depth => gridX + gridY;
  bool get resolved => age >= resolveAt;
}
