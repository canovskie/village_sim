// YÖNETİŞİMİN DÜNYADAKİ KARŞILIĞI — karar kartının sayı değiştirip kaybolmasını
// önleyen saf sözleşmeler.
//
// Sahne bu verileri gerçek NPC `Act` dizilerine çevirir. Bu dosya köylü,
// bina veya widget tanımaz; katalog, kayıt ve test aynı tipleri okuyabilir.

/// Bir seçenek, metninde adı geçen hangi dış aktörü gerçekten görmeyi şart
/// koşuyor? `none` dışındaki seçenek dünyada kanıt yoksa seçilemez.
enum DecisionPresence { none, activeCaravan }

/// Kararın anında delta vermek yerine başlattığı yolculuk/iş.
enum DecisionProcessKind { marketWoodRun, emergencyWoodRun }

/// Katalogdaki sabit süreç tarifi.
class DecisionProcessSpec {
  final DecisionProcessKind kind;
  final String title;
  final String departureText;
  final String completionText;
  final String completionAnnal;
  final double durationDays;
  final int foodOnComplete;
  final int woodOnComplete;
  final int stoneOnComplete;
  final int ironOnComplete;
  final int goldOnComplete;

  const DecisionProcessSpec({
    required this.kind,
    required this.title,
    required this.departureText,
    required this.completionText,
    required this.completionAnnal,
    required this.durationDays,
    this.foodOnComplete = 0,
    this.woodOnComplete = 0,
    this.stoneOnComplete = 0,
    this.ironOnComplete = 0,
    this.goldOnComplete = 0,
  });
}

/// Kayıtta yaşayan süreç örneği. Aktör adı kimliği taşır; kayıt yüklenince
/// aynı isim bulunamazsa başka uygun köylü işi tamamlar, sonuç kaybolmaz.
class DecisionProcess {
  final String id;
  final DecisionProcessKind kind;
  final String title;
  final String actorName;
  final double startedSim;
  final double dueSim;
  final String completionText;
  final String completionAnnal;
  final int foodOnComplete;
  final int woodOnComplete;
  final int stoneOnComplete;
  final int ironOnComplete;
  final int goldOnComplete;

  const DecisionProcess({
    required this.id,
    required this.kind,
    required this.title,
    required this.actorName,
    required this.startedSim,
    required this.dueSim,
    required this.completionText,
    required this.completionAnnal,
    this.foodOnComplete = 0,
    this.woodOnComplete = 0,
    this.stoneOnComplete = 0,
    this.ironOnComplete = 0,
    this.goldOnComplete = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'title': title,
    'actorName': actorName,
    'startedSim': startedSim,
    'dueSim': dueSim,
    'completionText': completionText,
    'completionAnnal': completionAnnal,
    'food': foodOnComplete,
    'wood': woodOnComplete,
    'stone': stoneOnComplete,
    'iron': ironOnComplete,
    'gold': goldOnComplete,
  };

  static DecisionProcess? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final j = Map<String, dynamic>.from(raw);
    final kindName = j['kind'] as String? ?? '';
    final kind = DecisionProcessKind.values
        .where((e) => e.name == kindName)
        .firstOrNull;
    if (kind == null) return null;
    double d(String key) => (j[key] as num?)?.toDouble() ?? 0;
    int i(String key) => (j[key] as num?)?.toInt() ?? 0;
    return DecisionProcess(
      id: j['id'] as String? ?? '',
      kind: kind,
      title: j['title'] as String? ?? '',
      actorName: j['actorName'] as String? ?? '',
      startedSim: d('startedSim'),
      dueSim: d('dueSim'),
      completionText: j['completionText'] as String? ?? '',
      completionAnnal: j['completionAnnal'] as String? ?? '',
      foodOnComplete: i('food'),
      woodOnComplete: i('wood'),
      stoneOnComplete: i('stone'),
      ironOnComplete: i('iron'),
      goldOnComplete: i('gold'),
    );
  }
}

/// Kanunların ve olay sonuçlarının tekrar eden, gözle okunur hareket ailesi.
enum GovernanceBeatKind {
  neighborVisit,
  waterDuty,
  fieldDuty,
  marketDuty,
  homeDuty,
  worshipDuty,
  watchDuty,
  fireDuty,
  herdDuty,
  treeDuty,
  councilDuty,
  warehouseDuty,
  apprenticeDuty,
  shelterDuty,
  careDuty,
  repairDuty,
  celebration,
}

class GovernanceAftermathSpec {
  final GovernanceBeatKind kind;
  final String source;
  final double durationDays;

  const GovernanceAftermathSpec(this.kind, this.source, this.durationDays);
}

/// Olay seçiminin birkaç saniyelik banner'dan sonra köyde kalan izi.
class GovernanceAftermath {
  final String id;
  final GovernanceBeatKind kind;
  final String source;
  final double untilSim;
  double nextBeatSim;

  GovernanceAftermath({
    required this.id,
    required this.kind,
    required this.source,
    required this.untilSim,
    required this.nextBeatSim,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'source': source,
    'untilSim': untilSim,
    'nextBeatSim': nextBeatSim,
  };

  static GovernanceAftermath? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final j = Map<String, dynamic>.from(raw);
    final kindName = j['kind'] as String? ?? '';
    final kind = GovernanceBeatKind.values
        .where((e) => e.name == kindName)
        .firstOrNull;
    if (kind == null) return null;
    return GovernanceAftermath(
      id: j['id'] as String? ?? '',
      kind: kind,
      source: j['source'] as String? ?? '',
      untilSim: (j['untilSim'] as num?)?.toDouble() ?? 0,
      nextBeatSim: (j['nextBeatSim'] as num?)?.toDouble() ?? 0,
    );
  }
}

class LawSignature {
  final String lawId;
  final GovernanceBeatKind kind;
  final String source;

  const LawSignature(this.lawId, this.kind, this.source);
}

/// Her hükmün tek ve tekrarlanan bir sokak imzası vardır. Bir hüküm burada
/// yoksa mekanik katsayısı çalışsa bile oyuncu onu insanlarda okuyamaz.
const lawSignatures = <String, LawSignature>{
  'neighborliness': LawSignature(
    'neighborliness',
    GovernanceBeatKind.neighborVisit,
    'Komşuluk Beratı',
  ),
  'winterFodder': LawSignature(
    'winterFodder',
    GovernanceBeatKind.herdDuty,
    'Kışlık Yem Fermanı',
  ),
  'sharedHarvest': LawSignature(
    'sharedHarvest',
    GovernanceBeatKind.warehouseDuty,
    'Müşterek Harman Fermanı',
  ),
  'irrigation': LawSignature(
    'irrigation',
    GovernanceBeatKind.waterDuty,
    'Su Yolu Fermanı',
  ),
  'farmLabor': LawSignature(
    'farmLabor',
    GovernanceBeatKind.fieldDuty,
    'Ekin Seferberliği Fermanı',
  ),
  'hospitality': LawSignature(
    'hospitality',
    GovernanceBeatKind.neighborVisit,
    'Açık Kapı Fermanı',
  ),
  'familyReunion': LawSignature(
    'familyReunion',
    GovernanceBeatKind.homeDuty,
    'Yuva Kurma Beratı',
  ),
  'herdGrowth': LawSignature(
    'herdGrowth',
    GovernanceBeatKind.herdDuty,
    'Sürü Beratı',
  ),
  'cropRotation': LawSignature(
    'cropRotation',
    GovernanceBeatKind.fieldDuty,
    'Dönemli Ekim Beratı',
  ),
  'apprenticeship': LawSignature(
    'apprenticeship',
    GovernanceBeatKind.apprenticeDuty,
    'Çıraklık Beratı',
  ),
  'oneChild': LawSignature(
    'oneChild',
    GovernanceBeatKind.homeDuty,
    'Tek Beşik Fermanı',
  ),
  'twoChild': LawSignature(
    'twoChild',
    GovernanceBeatKind.homeDuty,
    'İki Beşik Fermanı',
  ),
  'familyEncouragement': LawSignature(
    'familyEncouragement',
    GovernanceBeatKind.homeDuty,
    'Beşik Beratı',
  ),
  'tradeGuidance': LawSignature(
    'tradeGuidance',
    GovernanceBeatKind.marketDuty,
    'Eksik Zanaat Fermanı',
  ),
  'freeRange': LawSignature(
    'freeRange',
    GovernanceBeatKind.herdDuty,
    'Serbest Otlak Fermanı',
  ),
  'treePlanting': LawSignature(
    'treePlanting',
    GovernanceBeatKind.treeDuty,
    'Fidan Fermanı',
  ),
  'peacefulEnd': LawSignature(
    'peacefulEnd',
    GovernanceBeatKind.careDuty,
    'Huzurlu Son Beratı',
  ),
  'slowMaturity': LawSignature(
    'slowMaturity',
    GovernanceBeatKind.neighborVisit,
    'Uzun Çocukluk Fermanı',
  ),
  'eldersExemptFromFood': LawSignature(
    'eldersExemptFromFood',
    GovernanceBeatKind.fireDuty,
    'Yaşlıya Saygı Fermanı',
  ),
  'greenVillage': LawSignature(
    'greenVillage',
    GovernanceBeatKind.treeDuty,
    'Yeşil Köy Beratı',
  ),
  'quarantine': LawSignature(
    'quarantine',
    GovernanceBeatKind.careDuty,
    'Tecrit Fermanı',
  ),
  'hearthWatch': LawSignature(
    'hearthWatch',
    GovernanceBeatKind.fireDuty,
    'Ocak Nöbeti Fermanı',
  ),
  'outsideMarriage': LawSignature(
    'outsideMarriage',
    GovernanceBeatKind.marketDuty,
    'Dışarıya Nikâh Fermanı',
  ),
  'nizam.watch': LawSignature(
    'nizam.watch',
    GovernanceBeatKind.watchDuty,
    'Gece Bekçisi Fermanı',
  ),
  'nizam.registry': LawSignature(
    'nizam.registry',
    GovernanceBeatKind.councilDuty,
    'Hane Sicili Fermanı',
  ),
  'nizam.labor': LawSignature(
    'nizam.labor',
    GovernanceBeatKind.fieldDuty,
    'Kürek Cezası Fermanı',
  ),
  'nizam.exile': LawSignature(
    'nizam.exile',
    GovernanceBeatKind.watchDuty,
    'Sürgün Fermanı',
  ),
  'nizam.bloodPrice': LawSignature(
    'nizam.bloodPrice',
    GovernanceBeatKind.councilDuty,
    'Diyet Fermanı',
  ),
  'nizam.sole': LawSignature(
    'nizam.sole',
    GovernanceBeatKind.watchDuty,
    'Tek Söz Fermanı',
  ),
  'dergah.holyDay': LawSignature(
    'dergah.holyDay',
    GovernanceBeatKind.worshipDuty,
    'Kutsal Gün Fermanı',
  ),
  'dergah.lodge': LawSignature(
    'dergah.lodge',
    GovernanceBeatKind.worshipDuty,
    'Dergâh Fermanı',
  ),
  'dergah.tithe': LawSignature(
    'dergah.tithe',
    GovernanceBeatKind.warehouseDuty,
    'Öşür Fermanı',
  ),
  'dergah.penance': LawSignature(
    'dergah.penance',
    GovernanceBeatKind.worshipDuty,
    'Tövbe Meydanı Fermanı',
  ),
  'dergah.oneFaith': LawSignature(
    'dergah.oneFaith',
    GovernanceBeatKind.worshipDuty,
    'Tek İnanç Fermanı',
  ),
  'rejim.meclisDaimi': LawSignature(
    'rejim.meclisDaimi',
    GovernanceBeatKind.councilDuty,
    'Meclis-i Daimi Fermanı',
  ),
  'rejim.mulkTapusu': LawSignature(
    'rejim.mulkTapusu',
    GovernanceBeatKind.homeDuty,
    'Mülk Tapusu Fermanı',
  ),
  'rejim.ortakAmbar': LawSignature(
    'rejim.ortakAmbar',
    GovernanceBeatKind.warehouseDuty,
    'Ortak Ambar Fermanı',
  ),
  'rejim.muhassil': LawSignature(
    'rejim.muhassil',
    GovernanceBeatKind.marketDuty,
    'Muhassıl Fermanı',
  ),
};

/// Dokuz olayın her iki yolu aynı sahneyi oynamasın: seçimden sonra köyde
/// kalan davranış burada açıkça ayrılır.
GovernanceAftermathSpec? aftermathForChoice(String eventId, String choiceId) {
  final key = '$eventId:$choiceId';
  return switch (key) {
    'drought:irrigate' => const GovernanceAftermathSpec(
      GovernanceBeatKind.waterDuty,
      'Kuraklıkta sulama kararı',
      2.0,
    ),
    'drought:rationWater' => const GovernanceAftermathSpec(
      GovernanceBeatKind.homeDuty,
      'Su karnesi',
      2.0,
    ),
    'plague:healer' => const GovernanceAftermathSpec(
      GovernanceBeatKind.careDuty,
      'Şifacı tedavisi',
      2.0,
    ),
    'plague:endure' => const GovernanceAftermathSpec(
      GovernanceBeatKind.shelterDuty,
      'Salgını evlerde bekleme',
      2.5,
    ),
    'beastRaid:guards' => const GovernanceAftermathSpec(
      GovernanceBeatKind.watchDuty,
      'Sürü nöbeti',
      1.5,
    ),
    'beastRaid:hide' => const GovernanceAftermathSpec(
      GovernanceBeatKind.shelterDuty,
      'Canavardan sakınma',
      1.5,
    ),
    'storm:braceRoofs' => const GovernanceAftermathSpec(
      GovernanceBeatKind.repairDuty,
      'Çatıları berkitme',
      1.5,
    ),
    'storm:waitStorm' => const GovernanceAftermathSpec(
      GovernanceBeatKind.shelterDuty,
      'Fırtınayı içeride bekleme',
      1.5,
    ),
    'houseFire:extinguish' => const GovernanceAftermathSpec(
      GovernanceBeatKind.waterDuty,
      'Yangın sonrası su nöbeti',
      1.5,
    ),
    'houseFire:letBurn' => const GovernanceAftermathSpec(
      GovernanceBeatKind.repairDuty,
      'Yanan haneyi toplama',
      2.0,
    ),
    'bard:hostBard' => const GovernanceAftermathSpec(
      GovernanceBeatKind.celebration,
      'Ozan şöleni',
      1.5,
    ),
    'bard:hearOneSong' => const GovernanceAftermathSpec(
      GovernanceBeatKind.fireDuty,
      'Ateş başında tek türkü',
      0.8,
    ),
    'caravan:buyProvisions' => const GovernanceAftermathSpec(
      GovernanceBeatKind.warehouseDuty,
      'Kervan erzak teslimatı',
      1.0,
    ),
    'caravan:quickTrade' => const GovernanceAftermathSpec(
      GovernanceBeatKind.marketDuty,
      'Kervanla kısa ticaret',
      1.0,
    ),
    'bounty:storeBounty' => const GovernanceAftermathSpec(
      GovernanceBeatKind.warehouseDuty,
      'Bereketi ambara kaldırma',
      2.0,
    ),
    'bounty:harvestFeast' => const GovernanceAftermathSpec(
      GovernanceBeatKind.celebration,
      'Bereket sofrası',
      1.5,
    ),
    'accord:witnessAccord' => const GovernanceAftermathSpec(
      GovernanceBeatKind.councilDuty,
      'Aleni sulh',
      1.5,
    ),
    'accord:letAccordStand' => const GovernanceAftermathSpec(
      GovernanceBeatKind.neighborVisit,
      'Haneler arası özel sulh',
      1.5,
    ),
    _ => null,
  };
}
