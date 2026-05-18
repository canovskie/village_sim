enum VillagerType {
  farmer,
  merchant,
  blacksmith,
  guard,
  mage,
  miner,
  fisher,
}

extension VillagerTypeExtension on VillagerType {
  String get displayName {
    switch (this) {
      case VillagerType.farmer:
        return 'Çiftçi';
      case VillagerType.merchant:
        return 'Tüccar';
      case VillagerType.blacksmith:
        return 'Demirci';
      case VillagerType.guard:
        return 'Muhafız';
      case VillagerType.mage:
        return 'Büyücü';
      case VillagerType.miner:
        return 'Madenci';
      case VillagerType.fisher:
        return 'Balıkçı';
    }
  }
}
