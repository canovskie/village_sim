enum HayType { pile, bale }

class HayEntity {
  HayType type;
  double gridX;
  double gridY;
  bool isBeingCarried = false;
  bool isDelivered = false;
  final int _pileContribution = 1;

  HayEntity({required this.type, required this.gridX, required this.gridY});

  // Bale size=0.5; depth = front corner (gridX+0.5 + gridY+0.5)
  double get depth => isBale ? gridX + gridY + 1.0 : gridX + gridY;
  bool get isBale => type == HayType.bale;
  int get pileContribution => _pileContribution;
}
