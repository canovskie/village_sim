/// Köylü meslekleri. NOT: kayıtlarda **isimle** serialize edilir
/// (`_enumByName` + fallback) → sıra değiştirmek kayıtları bozmaz, ama bir
/// değerin ADINI değiştirmek eski kayıtlarda o köylüyü fallback'e düşürür.
enum VillagerType {
  farmer,
  merchant,
  blacksmith,
  guard,
  /// Eski `mage` (büyücü) buydu — köy sim'ine yakışmayan asa/sivri şapka gitti,
  /// yerine inancın sesi olan rahip geldi (İnananlar zümresini o besler).
  priest,
  miner,
  fisher,
  shepherd,
  hunter,
  miller,
  innkeeper,
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
      case VillagerType.priest:
        return 'Rahip';
      case VillagerType.miner:
        return 'Madenci';
      case VillagerType.fisher:
        return 'Balıkçı';
      case VillagerType.shepherd:
        return 'Çoban';
      case VillagerType.hunter:
        return 'Avcı';
      case VillagerType.miller:
        return 'Değirmenci';
      case VillagerType.innkeeper:
        return 'Hancı';
    }
  }

  /// Meslek-başı GÜNLÜK ham gelir (soyut "sikke"). Cozy: küçük, göreli farklar —
  /// tüccar/zanaatkâr en çok, geçim meslekleri daha az. [_tickVillagerMorale]
  /// bunu moral (üretkenlik) + ev kademesiyle çarpıp servete ekler.
  double get wealthDailyIncome {
    switch (this) {
      case VillagerType.merchant:
        return 3.2;
      case VillagerType.innkeeper:
        return 2.8; // yolcu ağırlar, kese dolar
      case VillagerType.blacksmith:
        return 2.6;
      case VillagerType.miller:
        return 2.4; // un öğütür, herkes ona uğrar
      case VillagerType.priest:
        return 2.3;
      case VillagerType.miner:
        return 2.2;
      case VillagerType.guard:
        return 1.9;
      case VillagerType.hunter:
        return 1.8; // post/et — iyi ama düzensiz
      case VillagerType.fisher:
        return 1.7;
      case VillagerType.farmer:
        return 1.6;
      case VillagerType.shepherd:
        return 1.5; // sürü zenginliği köyün, çobanın değil
    }
  }
}
