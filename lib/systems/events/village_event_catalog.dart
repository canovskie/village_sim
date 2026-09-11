part of 'event_system.dart';

bool _wellVillage(EventContext c) =>
    c.population >= 5 && c.buildings.any((b) => b.type == BuildingType.well);
bool _marketVillage(EventContext c) =>
    c.population >= 6 &&
    c.stockpile.food >= c.population * 5 + 12 &&
    c.buildings.any((b) => b.type == BuildingType.market);
bool _settledVillage(EventContext c) =>
    c.population >= 6 &&
    c.buildings.any(
      (b) =>
          b.type == BuildingType.woodenHouse ||
          b.type == BuildingType.stoneHouseBlue ||
          b.type == BuildingType.stoneHouseGreen,
    );

/// Topluluk, pazar ve hava gündemi. Son şık daima bedelsiz pasif zaman aşımıdır.
/// Müdahaleler kaynak ve zaman ister; kalıcı dünyada iş yapan insanlar görünür.
const kVillageEvents = <EventOutcome>[
  EventOutcome(
    id: EventIds.muddyWell,
    title: 'Kuyunun Suyu Bulandı',
    icon: '🪣',
    category: EventCategory.negative,
    severity: EventSeverity.major,
    canFire: _wellVillage,
    messagePool: [
      'Kovalar dipten çamur çekiyor. Kuyunun çevresinde birikenler temizleme işi için odun ve el istiyor.',
      'Kuyunun ağzı dağıldı, su bulanık geliyor. Köyün su taşıyanları bir onarım sırası bekliyor.',
    ],
    annalPool: ['Ortak kuyuda su taşıma işi aksadı.'],
    choices: [
      EventChoice(
        id: 'repair',
        label: 'Kuyu başını onar',
        detail: '4 odun ayır. Su taşıyanlar kuyunun başında birlikte çalışsın.',
        resolutionMessage:
            'Kuyu başı onarıma alındı. Kovalar sırayla el değiştiriyor.',
        annal: 'Ortak kuyu için odun ayrıldı, su işi birlikte üstlenildi.',
        woodDelta: -4,
        requiresResources: true,
        moraleModifier: 0.03,
        duration: kGameDaySeconds,
        aftermath: GovernanceAftermathSpec(
          GovernanceBeatKind.waterDuty,
          'Kuyu onarımı',
          1,
        ),
      ),
      EventChoice(
        id: 'endure',
        label: 'Şimdilik bekle',
        detail: 'Ambar korunur. Su işi bir gün daha ağır ilerler.',
        resolutionMessage: 'Kuyu bekletildi. Köylüler suyu daha yavaş taşıyor.',
        annal: 'Kuyu onarımı ertelendi; gündelik işler yavaşladı.',
        moraleModifier: -0.03,
        duration: kGameDaySeconds,
        effect: EventEffect(npcSpeedMul: 0.95, duration: kGameDaySeconds),
        aftermath: GovernanceAftermathSpec(
          GovernanceBeatKind.waterDuty,
          'Aksayan su işi',
          1,
        ),
      ),
    ],
  ),
  EventOutcome(
    id: EventIds.marketSurplus,
    title: 'Pazarda Fazla Zahire',
    icon: '🌾',
    category: EventCategory.positive,
    severity: EventSeverity.major,
    canFire: _marketVillage,
    messagePool: [
      'Ambarın payından fazlası pazar önüne yığıldı. Esnaf satın almak, komşular ortak sofra kurmak istiyor.',
      'Köy bugün ihtiyacından fazlasını biriktirdi. Fazla zahire keseye mi girsin, sofraya mı?',
    ],
    annalPool: ['Köy fazla zahirenin kullanımını konuştu.'],
    choices: [
      EventChoice(
        id: 'sell',
        label: 'Pazarda sat',
        detail: '12 yiyeceği 8 altına çevir.',
        resolutionMessage: 'Zahire pazara taşındı. Köyün kesesi doldu.',
        annal: 'Fazla zahire pazarda satıldı.',
        foodDelta: -12,
        goldDelta: 8,
        requiresResources: true,
        aftermath: GovernanceAftermathSpec(
          GovernanceBeatKind.marketDuty,
          'Zahire satışı',
          0.5,
        ),
      ),
      EventChoice(
        id: 'share',
        label: 'Ortak sofra kur',
        detail: '8 yiyecek ayır. Köy birlikte yesin.',
        resolutionMessage:
            'Ortak sofra açıldı. Komşular ekmeğini aynı yerde böldü.',
        annal: 'Fazla zahireyle köy sofrası kuruldu.',
        foodDelta: -8,
        requiresResources: true,
        moraleModifier: 0.06,
        duration: kGameDaySeconds,
        effect: EventEffect(fx: EventFx.festival, duration: 24),
        aftermath: GovernanceAftermathSpec(
          GovernanceBeatKind.celebration,
          'Ortak sofra',
          0.5,
        ),
      ),
      EventChoice(
        id: 'store',
        label: 'Ambarda kalsın',
        detail: 'Fazla zahire sonraki günlere saklansın.',
        resolutionMessage: 'Zahire ambarda kaldı. Köy yarının payını korudu.',
        annal: 'Fazla zahire yedek olarak saklandı.',
        aftermath: GovernanceAftermathSpec(
          GovernanceBeatKind.warehouseDuty,
          'Zahireyi saklama',
          0.5,
        ),
      ),
    ],
  ),
  EventOutcome(
    id: EventIds.approachingStorm,
    title: 'Fırtına Yaklaşıyor',
    icon: '🌧️',
    category: EventCategory.negative,
    severity: EventSeverity.major,
    canFire: _settledVillage,
    weight: 0.7,
    messagePool: [
      'Rüzgâr işliklerdeki örtüleri kaldırıyor. Ustalar malzemeyi bağlamak için odun istiyor.',
      'Kara bulutlar köyün üstüne geliyor. Açıkta duran malzemeyi şimdi bağlamak işleri hafifletebilir.',
    ],
    annalPool: ['Köy yaklaşan fırtına için hazırlık konuştu.'],
    choices: [
      EventChoice(
        id: 'secure',
        label: 'Malzemeyi sağlamlaştır',
        detail: '6 odun harca. Fırtınada inşaat daha az yavaşlasın.',
        resolutionMessage:
            'Ustalar malzemeyi bağladı. Yağmur altında iş daha yavaş da olsa sürüyor.',
        annal: 'Fırtına öncesi işlik malzemesi sağlamlaştırıldı.',
        woodDelta: -6,
        requiresResources: true,
        effect: EventEffect(
          fx: EventFx.storm,
          rainBoost: 0.5,
          builderMul: 0.85,
          duration: kGameDaySeconds / 2,
        ),
        aftermath: GovernanceAftermathSpec(
          GovernanceBeatKind.repairDuty,
          'Fırtına hazırlığı',
          0.5,
        ),
      ),
      EventChoice(
        id: 'shelter',
        label: 'Yağmurun geçmesini bekle',
        detail: 'Odun harcanmaz. İnşaat yarım gün belirgin biçimde yavaşlar.',
        resolutionMessage:
            'Ustalar sığınağa çekildi. Yağmur dinene kadar iş ağır ilerliyor.',
        annal: 'Fırtına hazırlığı yapılmadı; ustalar işlerini yavaşlattı.',
        effect: EventEffect(
          fx: EventFx.storm,
          rainBoost: 0.5,
          builderMul: 0.60,
          duration: kGameDaySeconds / 2,
        ),
        aftermath: GovernanceAftermathSpec(
          GovernanceBeatKind.shelterDuty,
          'Fırtınadan korunma',
          0.5,
        ),
      ),
    ],
  ),
];
