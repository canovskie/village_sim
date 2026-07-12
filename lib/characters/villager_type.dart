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

  /// Meslek-başı GÜNLÜK ham gelir (soyut "sikke"). Cozy: küçük, göreli farklar —
  /// tüccar/zanaatkâr en çok, geçim meslekleri daha az. [_tickVillagerMorale]
  /// bunu moral (üretkenlik) + ev kademesiyle çarpıp servete ekler.
  double get wealthDailyIncome {
    switch (this) {
      case VillagerType.merchant:
        return 3.2;
      case VillagerType.blacksmith:
        return 2.6;
      case VillagerType.mage:
        return 2.3;
      case VillagerType.miner:
        return 2.2;
      case VillagerType.guard:
        return 1.9;
      case VillagerType.fisher:
        return 1.7;
      case VillagerType.farmer:
        return 1.6;
    }
  }
}
