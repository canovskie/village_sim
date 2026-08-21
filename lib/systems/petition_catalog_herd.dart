part of 'petition_system.dart';

/// DİLEKÇE KATALOĞU — SÜRÜ DİLEKÇELERİ (2 dilekçe).
///
/// Katalog tek dosyada 2856 satırdı; bölümler zaten `═` bantlarıyla
/// ayrılmıştı, o sınırlar dosya sınırı yapıldı. SIRA KORUNUR:
/// [_kPetitionDefs] bu listeleri eski sırayla yayar.
final List<_PetitionDef> _kHerdPetitions = [
  // ════════════════════════════════════════════════════════════════════════
  // SÜRÜ DİLEKÇELERİ — hayvancılık yönetişimi. Cozy/no-fail.
  // ════════════════════════════════════════════════════════════════════════

  // 🌾 Sürü aç — ahıra kışlık yem istenir.
  _PetitionDef(
    (c) => c.herdHungry && c.herdSize >= 2,
    1.1,
    const Petition(
      id: 'herdFodder',
      petitioner: 'Çoban',
      icon: '🌾',
      title: 'Sürü Yem İstiyor',
      tone: PetitionTone.ominous,
      estate: Estate.laborers,
      stakes: 'Ambardan bir pay; yoksa cılız hayvan ve kesilen süt.',
      bodyPool: [
        '“Efendim, {ad} benim, sürüyü ben güderim. Otlak taş kesti; hayvan otu değil '
            'toprağı yalıyor. Kaburgaları sayılıyor. Sabah sağdım, kova yarısını bile '
            'bulmadı. Ambardan bir pay ayır, kışa böyle giremeyiz.”',
        '“İki gebe koyunum var, ikisi de zayıf. Böyle giderse kuzular ölü doğar; bunu '
            'görmek istemiyorum. Bir çuval arpa yeter, çok değil. Ahıra kendim taşırım.”',
        '“Kimse hayvanı benden çok sevmez, onları aç bırakmam. Ama bu {mevsim} otlak '
            'kurudu, ben ne yapayım? Sofradan bir pay ayır. Karşılığını sütle, yünle '
            'öderler; onlar borçlu kalmaz.”',
      ],
      options: [
        PetitionOption(
          label: 'Ambardan yem ayır',
          detail:
              'Sofradan bir pay ahıra gider. Sürü toparlanır, süt geri gelir.',
          resolutionPool: [
            '🌾 Ahıra arpa taşındı. {ad} sabah sağdığı kovayı kaldırıp gösterdi, ağzına kadar doluydu.',
            '🌾 Yem ayrıldı. Gebe koyunlar bir haftada doğruldu.',
          ],
          foodDelta: -6,
          moraleAmount: 0.03,
          moraleDays: 2,
          estateMood: [(Estate.laborers, 0.16), (Estate.hearth, -0.03)],
        ),
        PetitionOption(
          label: 'Otlağa güven',
          detail: 'Ambar kapalı. Sürü cılız kalır, çoban susar.',
          resolutionPool: [
            '🌾 Yem ayrılmadı. {ad} sürüyü daha uzağa, taşlığın ardına götürdü.',
            '🌾 Ahır boş kaldı. Sabah kovada süt yerine köpük vardı.',
          ],
          moraleAmount: -0.02,
          moraleDays: 2,
          estateMood: [(Estate.laborers, -0.09)],
        ),
      ],
    ),
  ),

  // 🐄 Hayvan hastalığı — sürüye bakım/şifa istenir.
  _PetitionDef(
    (c) => c.herdSize >= 3,
    0.5,
    const Petition(
      id: 'herdAilment',
      petitioner: 'Çoban',
      icon: '🐄',
      title: 'Sürüde Hastalık Belirtisi',
      tone: PetitionTone.ominous,
      estate: Estate.laborers,
      stakes: 'Şifacı altın ister; beklemek hem sürüyü hem çobanı yıpratır.',
      bodyPool: [
        '“Efendim, üç hayvan sabah zor kalktı, kalkınca da başı yerdeydi. Burunları '
            'akıyor, ağıl ekşi kokuyor. Bunu bir kez görmüştüm; o yıl kervanla gelen sürü '
            'yarıya indi. Bir şifacı çağır, ben otları kaynatmaya başladım bile.”',
        '“{ad} benim. Dün gece ağılda yattım, hayvanların nefesini dinledim; ikisi '
            'hırıltıyla soluyor. Sabah ağılı baştan aşağı yıkadım, olmadı. Bu benim '
            'harcım değil, bilen biri gelsin.”',
        '“Kuzu emmiyor, anası da yatıyor. İkisini ayırdım, belki bulaşmaz. Ama ağılda '
            'kırk hayvan var, hepsini ayıramam. Bir şifacı gelsin, kalanına baksın; '
            'beklersek geç kalırız.”',
      ],
      options: [
        PetitionOption(
          label: 'Şifacı çağır',
          detail:
              'Kese açılır. Ağıl yıkanır, otlar kaynar, hastalık sınırda kalır.',
          resolutionPool: [
            '🐄 Şifacı geldi. Ağıl yıkandı, otlar kaynatıldı; sabah üç hayvan da ayaktaydı.',
            '🐄 Sürüye bakıldı. {ad} kuzuyu kucağında anasına götürdü, kuzu emdi.',
          ],
          goldDelta: -5,
          moraleAmount: 0.03,
          moraleDays: 2,
          estateMood: [(Estate.laborers, 0.14)],
        ),
        PetitionOption(
          label: 'Kendi geçer',
          detail: 'Kese kapalı. Çoban gece ağılda yatmaya devam eder.',
          resolutionPool: [
            '🐄 Şifacı çağrılmadı. {ad} geceleri ağılda yatıyor, kimseye bir şey söylemiyor.',
            '🐄 Beklendi. Ağıldan gelen hırıltı iki gün daha sürdü.',
          ],
          moraleAmount: -0.03,
          moraleDays: 2,
          estateMood: [(Estate.laborers, -0.08), (Estate.hearth, -0.03)],
        ),
      ],
    ),
  ),
];
