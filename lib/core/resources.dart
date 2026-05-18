/// Köyün ekonomik kaynakları.
/// İşçi NPC'leri ham kaynak üretir, taşıyıcılar depoya/ateşe getirir,
/// inşaat orderları stockpile'dan tüketir.
enum ResourceKind {
  wood('🪵', 'Odun'),
  stone('🪨', 'Taş'),
  iron('⚙', 'Demir'),
  coal('♦', 'Kömür'),
  food('🌾', 'Yiyecek'),
  gold('★', 'Altın');

  final String icon;
  final String label;
  const ResourceKind(this.icon, this.label);
}

/// Köy stoğu — değişebilir miktar takipçisi.
class ResourceBundle {
  int wood;
  int stone;
  int iron;
  int coal;
  int food;
  int gold;

  ResourceBundle({
    this.wood  = 0,
    this.stone = 0,
    this.iron  = 0,
    this.coal  = 0,
    this.food  = 0,
    this.gold  = 0,
  });

  int get(ResourceKind k) => switch (k) {
        ResourceKind.wood  => wood,
        ResourceKind.stone => stone,
        ResourceKind.iron  => iron,
        ResourceKind.coal  => coal,
        ResourceKind.food  => food,
        ResourceKind.gold  => gold,
      };

  void add(ResourceKind k, int amount) {
    switch (k) {
      case ResourceKind.wood:  wood  += amount;
      case ResourceKind.stone: stone += amount;
      case ResourceKind.iron:  iron  += amount;
      case ResourceKind.coal:  coal  += amount;
      case ResourceKind.food:  food  += amount;
      case ResourceKind.gold:  gold  += amount;
    }
  }

  bool canAfford(ResourceCost c) =>
      wood  >= c.wood  &&
      stone >= c.stone &&
      iron  >= c.iron  &&
      coal  >= c.coal  &&
      food  >= c.food  &&
      gold  >= c.gold;

  void spend(ResourceCost c) {
    wood  -= c.wood;
    stone -= c.stone;
    iron  -= c.iron;
    coal  -= c.coal;
    food  -= c.food;
    gold  -= c.gold;
  }

  void clear() {
    wood = stone = iron = coal = food = gold = 0;
  }

  /// Eksik kaynakları "12 🪵 + 3 🪨" gibi gösterilebilir biçimde döner.
  String formatMissing(ResourceCost c) {
    final parts = <String>[];
    void check(ResourceKind k, int have, int need) {
      if (need > have) parts.add('${need - have} ${k.icon}');
    }
    check(ResourceKind.wood,  wood,  c.wood);
    check(ResourceKind.stone, stone, c.stone);
    check(ResourceKind.iron,  iron,  c.iron);
    check(ResourceKind.coal,  coal,  c.coal);
    check(ResourceKind.food,  food,  c.food);
    check(ResourceKind.gold,  gold,  c.gold);
    return parts.join(' ');
  }
}

/// Bir inşaatın / işlemin malzeme maliyeti — değişmez.
class ResourceCost {
  final int wood;
  final int stone;
  final int iron;
  final int coal;
  final int food;
  final int gold;

  const ResourceCost({
    this.wood  = 0,
    this.stone = 0,
    this.iron  = 0,
    this.coal  = 0,
    this.food  = 0,
    this.gold  = 0,
  });

  static const empty = ResourceCost();

  bool get isFree =>
      wood == 0 && stone == 0 && iron == 0 &&
      coal == 0 && food == 0 && gold == 0;

  /// Sıfır olmayan kaynakları (kind, amount) listesi olarak döner.
  List<(ResourceKind, int)> get entries => [
        if (wood  > 0) (ResourceKind.wood,  wood),
        if (stone > 0) (ResourceKind.stone, stone),
        if (iron  > 0) (ResourceKind.iron,  iron),
        if (coal  > 0) (ResourceKind.coal,  coal),
        if (food  > 0) (ResourceKind.food,  food),
        if (gold  > 0) (ResourceKind.gold,  gold),
      ];
}
