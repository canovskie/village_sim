enum ResourceBoxType { woodChunk, stoneBox, ironBox, coalBox }

class ResourceBox {
  final ResourceBoxType type;
  double gridX;
  double gridY;
  bool isBeingCarried = false;
  bool isDelivered = false;

  ResourceBox({required this.type, required this.gridX, required this.gridY});

  double get depth => gridX + gridY;

  String get spriteName {
    switch (type) {
      case ResourceBoxType.woodChunk: return 'woodchunk';
      case ResourceBoxType.stoneBox:  return 'stonebox';
      case ResourceBoxType.ironBox:   return 'ironbox';
      case ResourceBoxType.coalBox:   return 'coalbox';
    }
  }
}
