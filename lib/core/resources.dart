/// Köyün ekonomik kaynakları.
/// İşçi NPC'leri ham kaynak üretir, taşıyıcılar depoya/ateşe getirir,
/// inşaat orderları stockpile'dan tüketir.
enum ResourceKind {
  wood('🪵', 'Odun', 'wood'),
  stone('🪨', 'Taş', 'stone'),
  iron('⚙', 'Demir', 'iron'),
  coal('♦', 'Kömür', 'coal'),
  food('🌾', 'Yiyecek', 'food'),
  honey('🍯', 'Bal', 'honey'),
  reed('🌿', 'Saz', 'reed'),
  /// Kışlık giysinin hammaddesi — sonbaharda koyundan kırkılır, dokumacı
  /// giysiye çevirir (bkz. systems/winter.dart, scene_winter.dart). Omurga
  /// kaynağı DEĞİL: HUD'ın ikincil panelinde bal/sazın yanında durur.
  wool('🧶', 'Yün', 'wool'),
  gold('★', 'Altın', 'gold');

  final String icon;
  final String label;
  /// Pixel-art ikon dosya çekirdeği — `assets/ui/icon_$asset.png` (UiIcon).
  final String asset;
  const ResourceKind(this.icon, this.label, this.asset);
}

/// Köy stoğu — değişebilir miktar takipçisi.
class ResourceBundle {
  int wood;
  int stone;
  int iron;
  int coal;
  int food;
  int honey;
  int reed;
  int wool;
  int gold;

  ResourceBundle({
    this.wood  = 0,
    this.stone = 0,
    this.iron  = 0,
    this.coal  = 0,
    this.food  = 0,
    this.honey = 0,
    this.reed  = 0,
    this.wool  = 0,
    this.gold  = 0,
  });

  int get(ResourceKind k) => switch (k) {
        ResourceKind.wood  => wood,
        ResourceKind.stone => stone,
        ResourceKind.iron  => iron,
        ResourceKind.coal  => coal,
        ResourceKind.food  => food,
        ResourceKind.honey => honey,
        ResourceKind.reed  => reed,
        ResourceKind.wool  => wool,
        ResourceKind.gold  => gold,
      };

  void add(ResourceKind k, int amount) {
    switch (k) {
      case ResourceKind.wood:  wood  += amount;
      case ResourceKind.stone: stone += amount;
      case ResourceKind.iron:  iron  += amount;
      case ResourceKind.coal:  coal  += amount;
      case ResourceKind.food:  food  += amount;
      case ResourceKind.honey: honey += amount;
      case ResourceKind.reed:  reed  += amount;
      case ResourceKind.wool:  wool  += amount;
      case ResourceKind.gold:  gold  += amount;
    }
  }

  bool canAfford(ResourceCost c) =>
      wood  >= c.wood  &&
      stone >= c.stone &&
      iron  >= c.iron  &&
      coal  >= c.coal  &&
      food  >= c.food  &&
      honey >= c.honey &&
      reed  >= c.reed  &&
      wool  >= c.wool  &&
      gold  >= c.gold;

  void spend(ResourceCost c) {
    wood  -= c.wood;
    stone -= c.stone;
    iron  -= c.iron;
    coal  -= c.coal;
    food  -= c.food;
    honey -= c.honey;
    reed  -= c.reed;
    wool  -= c.wool;
    gold  -= c.gold;
  }

  void clear() {
    wood = stone = iron = coal = food = honey = reed = wool = gold = 0;
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
    check(ResourceKind.honey, honey, c.honey);
    check(ResourceKind.reed,  reed,  c.reed);
    check(ResourceKind.wool,  wool,  c.wool);
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
  final int honey;
  final int reed;
  /// Yün hiçbir binanın maliyetinde YOK (giysiye gider). Alan yine de duruyor:
  /// ResourceKind üzerinden dönen ortak kod (canAfford/spend/formatMissing)
  /// simetri olmadan sessizce yün'ü atlar.
  final int wool;
  final int gold;

  const ResourceCost({
    this.wood  = 0,
    this.stone = 0,
    this.iron  = 0,
    this.coal  = 0,
    this.food  = 0,
    this.honey = 0,
    this.reed  = 0,
    this.wool  = 0,
    this.gold  = 0,
  });

  static const empty = ResourceCost();

  bool get isFree =>
      wood == 0 && stone == 0 && iron == 0 &&
      coal == 0 && food == 0 && honey == 0 && reed == 0 && wool == 0 &&
      gold == 0;

  /// Sıfır olmayan kaynakları (kind, amount) listesi olarak döner.
  List<(ResourceKind, int)> get entries => [
        if (wood  > 0) (ResourceKind.wood,  wood),
        if (stone > 0) (ResourceKind.stone, stone),
        if (iron  > 0) (ResourceKind.iron,  iron),
        if (coal  > 0) (ResourceKind.coal,  coal),
        if (food  > 0) (ResourceKind.food,  food),
        if (honey > 0) (ResourceKind.honey, honey),
        if (reed  > 0) (ResourceKind.reed,  reed),
        if (gold  > 0) (ResourceKind.gold,  gold),
      ];
}
