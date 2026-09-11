part of '../petition_system.dart';

/// Rejim krizleri sabit kimlikle kaydedilir; şık sonuçları metne bağlı değildir.
final List<_PetitionDef> _kRegimePetitions = [
  _PetitionDef(
    (c) => false,
    0,
    const Petition(
      id: 'regime.crisis.revolt',
      petitioner: 'Köyün hâli',
      icon: '👑',
      title: 'İsyan Kaynıyor',
      bodyPool: [
        'Ambar arkasında toplananlar var. Sen yaklaşınca sesler kesiliyor.',
      ],
      tone: PetitionTone.ominous,
      stakes: 'Karar geciktikçe köyün huzursuzluğu sürer.',
      options: [
        PetitionOption(
          label: 'Meydana in, taviz ver',
          unrestDelta: -0.50,
          detail: 'Kese açılır, öfke iner.',
          resolutionPool: [
            '👑 Meydanda konuştun. Kese hafifledi, omuzlar gevşedi.',
          ],
          goldDelta: -15,
          moraleAmount: 0.06,
          moraleDays: 5,
          estateMood: [(Estate.laborers, 0.10), (Estate.hearth, 0.08)],
        ),
        PetitionOption(
          label: 'Elebaşını bul, sürgün et',
          unrestDelta: -0.28,
          action: PetitionAction.exileAgitator,
          detail: 'Korku susturur; bir süreliğine.',
          resolutionPool: [
            '👑 Elebaşı köyden sürüldü. Meydan sustu; bakışlar susmadı.',
          ],
          moraleAmount: -0.05,
          moraleDays: 4,
          estateMood: [
            (Estate.hearth, -0.10),
            (Estate.faithful, -0.08),
            (Estate.artisans, 0.04),
          ],
        ),
        PetitionOption(
          label: 'Aldırma',
          unrestDelta: 0.06,
          detail: 'Duymazdan gel; kaynayan kaynasın.',
          resolutionPool: ['👑 Aldırmadın. Ambar arkasındaki halka büyüdü.'],
          moraleAmount: -0.04,
          moraleDays: 4,
        ),
      ],
    ),
    gravity: PetitionGravity.critical,
  ),
  _PetitionDef(
    (c) => false,
    0,
    const Petition(
      id: 'regime.crisis.deadlock',
      petitioner: 'Köyün hâli',
      icon: '🤝',
      title: 'Meclis Kilitlendi',
      bodyPool: [
        'Herkes konuştu, kimse ikna olmadı. Divan aynı meselede düğümlendi.',
      ],
      tone: PetitionTone.ominous,
      stakes: 'Karar geciktikçe köyün huzursuzluğu sürer.',
      options: [
        PetitionOption(
          label: 'Arabulucu ata',
          unrestDelta: -0.45,
          action: PetitionAction.settleCouncil,
          detail: 'Dışarıdan bir söz, düğümü çözer (10 akçe).',
          resolutionPool: [
            '🤝 Arabulucu masaya oturdu. Divan üç gün sonra ilk kez dağıldı.',
          ],
          goldDelta: -10,
          moraleAmount: 0.05,
          moraleDays: 4,
          estateMood: [(Estate.hearth, 0.06), (Estate.laborers, 0.05)],
        ),
        PetitionOption(
          label: 'Meclisi dağıt, kararı sen ver',
          unrestDelta: -0.30,
          action: PetitionAction.settleCouncil,
          detail: 'Düğüm çözülür; meşruiyet çözülmez.',
          resolutionPool: [
            '🤝 Meclisi dağıttın. Karar çıktı; kimse alkışlamadı.',
          ],
          moraleAmount: -0.05,
          moraleDays: 4,
          estateMood: [(Estate.laborers, -0.10), (Estate.hearth, -0.06)],
        ),
        PetitionOption(
          label: 'Bekle, konuşsunlar',
          unrestDelta: -0.12,
          action: PetitionAction.extendCouncil,
          detail: 'Meşru ama yavaş; divan bir gün daha kilitli.',
          resolutionPool: [
            '🤝 Bekledin. Meclis hâlâ konuşuyor, defter hâlâ kapalı.',
          ],
          estateMood: [(Estate.laborers, 0.04)],
        ),
      ],
    ),
    gravity: PetitionGravity.critical,
  ),
  _PetitionDef(
    (c) => false,
    0,
    const Petition(
      id: 'regime.crisis.idleness',
      petitioner: 'Köyün hâli',
      icon: '⚖',
      title: 'Tezgâh Soğudu',
      bodyPool: [
        'Pay nasılsa eşit; kimse fazladan yük almıyor. İş görünüyor ama yürümüyor.',
      ],
      tone: PetitionTone.ominous,
      stakes: 'Karar geciktikçe köyün huzursuzluğu sürer.',
      options: [
        PetitionOption(
          label: 'Denetçi koy',
          unrestDelta: -0.40,
          detail: 'Kim ne yaptı yazılır (12 akçe).',
          resolutionPool: [
            '⚖ Denetçi tezgâh tezgâh geziyor. İş yürüdü; keyif kaçtı.',
          ],
          goldDelta: -12,
          estateMood: [(Estate.laborers, -0.08), (Estate.artisans, 0.05)],
        ),
        PetitionOption(
          label: 'Çok çalışana fazla pay',
          unrestDelta: -0.50,
          detail: 'Eşitlikten bir tutam ödün.',
          resolutionPool: [
            '⚖ Fazla çalışana fazla pay. Tezgâh ısındı, sofrada mırıltı var.',
          ],
          moraleAmount: 0.04,
          moraleDays: 5,
          estateMood: [(Estate.artisans, 0.12), (Estate.laborers, -0.08)],
        ),
        PetitionOption(
          label: 'Bir şey yapma',
          unrestDelta: 0.05,
          detail: 'Pay eşit kalsın, heves nasılsa döner.',
          resolutionPool: ['⚖ Bir şey yapmadın. Tezgâh soğumaya devam etti.'],
          moraleAmount: -0.03,
          moraleDays: 4,
        ),
      ],
    ),
    gravity: PetitionGravity.critical,
  ),
  _PetitionDef(
    (c) => false,
    0,
    const Petition(
      id: 'regime.crisis.inequality',
      petitioner: 'Köyün hâli',
      icon: '🏪',
      title: 'Makas Açıldı',
      bodyPool: [
        'Bazı haneler biriktirirken başkaları sofrasını dolduramıyor. Köy bir karşılık bekliyor.',
      ],
      tone: PetitionTone.ominous,
      stakes: 'Karar geciktikçe köyün huzursuzluğu sürer.',
      options: [
        PetitionOption(
          label: 'Zenginden al, muhtaca ver',
          unrestDelta: -0.50,
          detail: 'Kese 20 akçe hafifler, sofra dolar.',
          resolutionPool: [
            '🏪 Pay dağıtıldı. Sazlıktaki yatak bu gece boş kaldı.',
          ],
          goldDelta: -20,
          moraleAmount: 0.06,
          moraleDays: 5,
          estateMood: [(Estate.laborers, 0.12), (Estate.artisans, -0.08)],
        ),
        PetitionOption(
          label: 'Yoksul sofralara pay ayır',
          unrestDelta: -0.35,
          detail: 'Veren el görünsün; makas kapanmaz ama acı diner.',
          resolutionPool: [
            '🏪 Yoksul sofralara pay ayıruldu. Kapıda sıra var ama kimse aç dönmüyor.',
          ],
          goldDelta: -8,
          moraleAmount: 0.04,
          moraleDays: 5,
          estateMood: [(Estate.faithful, 0.12), (Estate.hearth, 0.06)],
        ),
        PetitionOption(
          label: 'Pazar kendi dengesini bulur',
          unrestDelta: 0.08,
          detail: 'Karışma; kese dolsun.',
          resolutionPool: [
            '🏪 Karışmadın. Kese doldu, sazlıktaki yatak sayısı da arttı.',
          ],
          goldDelta: 15,
          moraleAmount: -0.05,
          moraleDays: 5,
          estateMood: [(Estate.artisans, 0.10), (Estate.laborers, -0.10)],
        ),
      ],
    ),
    gravity: PetitionGravity.critical,
  ),
];
