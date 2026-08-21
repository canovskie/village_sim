part of 'petition_system.dart';

/// DİLEKÇE KATALOĞU — YASA-DUYARLI DİLEKÇELER (10 dilekçe).
///
/// Katalog tek dosyada 2856 satırdı; bölümler zaten `═` bantlarıyla
/// ayrılmıştı, o sınırlar dosya sınırı yapıldı. SIRA KORUNUR:
/// [_kPetitionDefs] bu listeleri eski sırayla yayar.
final List<_PetitionDef> _kLawPetitions = [
  // ════════════════════════════════════════════════════════════════════════
  // YASA-DUYARLI DİLEKÇELER — yürürlükteki bir yasa köyde canlı bir sosyal
  // karşılık doğurur (politika↔dilekçe köprüsü).
  // ════════════════════════════════════════════════════════════════════════

  // 🌱 Dönemli ekim yürürlükte → tarla bereketlenir ama pazar payı daralır.
  _PetitionDef(
    (c) => c.cropRotation && c.adults >= 5,
    0.55,
    const Petition(
      id: 'rotationMarket',
      petitioner: 'Tezgâh esnafı',
      icon: '🌱',
      title: 'Dönemli Ekim Pazarı Daraltıyor',
      tone: PetitionTone.neutral,
      estate: Estate.artisans,
      note: '⚖ Dönemli Ekim yürürlükte',
      stakes: 'Yasada direnirsen tezgâh boş kalır; gevşetirsen toprak yorulur.',
      bodyPool: [
        '“Efendim, pazara buğday az geliyor; tarlanın yarısı dinleniyor diye tezgâhın '
            'yarısı boş. Dün akşama kadar iki kile un gördüm, ikisi de başka hanenindi. Ya '
            'takvimi biraz gevşet, ya keseden bize bir pay ayır.”',
        '“Toprak dinlensin, hay hay; kimse toprağa düşman değil. Ama ben neyi öğüteyim, '
            'neyi satayım? Bu {mevsim} boyu tezgâhımın tozunu aldım, üstüne mal koymadım. '
            'Bir şey yap.”',
        '“{ad} benim, esnafın sözcüsü. Yasa iyi yasadır, itirazımız ona değil; '
            'itirazımız aç kalan tezgâha. Emekçi bereketini aldı, biz kesemizi '
            'kaybettik. Bir denge kur.”',
      ],
      options: [
        PetitionOption(
          label: 'Takvimde diren',
          detail:
              'Toprak dinlenmeye devam eder. Esnaf tezgâhının tozunu almaya.',
          resolutionPool: [
            '🌱 Takvim değişmedi. Tarlanın yarısı dinleniyor, esnaf homurdanıyor.',
            '🌱 Yasa yasadır dendi. {ad} tezgâhını toplayıp gitti, arkasına bakmadı.',
          ],
          estateMood: [
            (Estate.laborers, 0.10),
            (Estate.hearth, 0.04),
            (Estate.artisans, -0.12),
          ],
        ),
        PetitionOption(
          label: 'Esnafa pay ayır',
          detail:
              'Keseden altın akar. Tezgâh doğrulur, harmandakiler burnundan solur.',
          resolutionPool: [
            '🔨 Esnafa pay ayrıldı. {ad-in} tezgâhı yeniden doldu, harmandakiler duydu.',
            '🔨 Kese açıldı. Pazar canlandı; tarladan dönenler o akşam selam vermedi.',
          ],
          goldDelta: -5,
          estateMood: [(Estate.artisans, 0.14), (Estate.laborers, -0.08)],
        ),
      ],
    ),
  ),

  // 🚪 Misafirperverlik yürürlükte + boş hane var → kervandan biri yerleşmek ister.
  _PetitionDef(
    (c) => c.hospitality && c.hasHousing && c.population >= 5 && c.food >= 8,
    0.6,
    const Petition(
      id: 'wandererSettles',
      petitioner: 'Kervandan ayrılan bir yolcu',
      icon: '🚪',
      title: 'Kervandan Bir Yolcu Yerleşmek İstiyor',
      tone: PetitionTone.warm,
      estate: Estate.artisans,
      note: '⚖ Misafirperverlik yasası',
      stakes: 'Sofraya bir boğaz daha; karşılığında iş tutan bir çift el.',
      bodyPool: [
        '“Kervanla geldim; burada kapıda bekletmediler, ekmek verdiler, adımı '
            'sordular. Boş bir hane varmış diye duydum. Marangoz oğluyum, elim iş '
            'tutar; yalnız bir çatı isterim.”',
        '“Efendim, kervandaki yüküm bir balta ve iki gömlek. Bir kışı daha yolda '
            'geçiremem. {köy} bana tanıdık geldi, sebebini bilmiyorum. Bir köşe ver, '
            'gerisini kendim yaparım.”',
        '“Kervanla uzun yol geldim. Yolda öğrendiğim ne varsa buraya bırakırım: bir hastalığın '
            'otu, bir tohumun vakti, iki de türkü. Karşılığında bir yatak ve sofrada bir '
            'yer isterim.”',
      ],
      options: [
        PetitionOption(
          label: 'Hoş geldin, yerleş',
          detail:
              'Sofraya bir boğaz eklenir. Köye bir çift el, bir yığın haber.',
          resolutionPool: [
            '🚪 Kervan yolcusu boş haneye yerleşti. İlk işi kapının menteşesini onarmak oldu.',
            '🚪 Kapı açıldı. Kervan yolcusu o akşam ateşin başında uzak bir kıyıyı anlattı.',
          ],
          foodDelta: -3,
          moraleAmount: 0.05,
          moraleDays: 3,
          estateMood: [
            (Estate.artisans, 0.12),
            (Estate.hearth, 0.05),
            (Estate.laborers, -0.03),
          ],
        ),
        PetitionOption(
          label: 'Bu sefer olmaz',
          detail: 'Sofra dar. Yolcu çıkınını toplar, kervanla devam eder.',
          resolutionPool: [
            '🚪 Yolcu geri çevrildi. Baltasını sırtlayıp kervana döndü, dönüp bakmadı.',
            '🚪 Yer yok dendi. Sabah kapıda sadece ayak izleri kalmıştı.',
          ],
          moraleAmount: -0.03,
          moraleDays: 2,
          estateMood: [(Estate.artisans, -0.08), (Estate.hearth, 0.03)],
        ),
      ],
    ),
  ),

  // 🎉 Çiftçiler hasat şenliği ister.
  _PetitionDef(
    (c) => c.food >= 30,
    1.0,
    const Petition(
      id: 'harvestFestival',
      petitioner: 'Harmandan çıkan çiftçiler',
      icon: '🎉',
      title: 'Hasat Şenliği',
      tone: PetitionTone.warm,
      estate: Estate.laborers,
      stakes: 'Bir kese altın; karşılığında günlerce konuşulacak bir gece.',
      bodyPool: [
        '“Ambar ağzına kadar dolu, kapağını zor kapatıyoruz. Harman bitti, elimiz ilk '
            'kez boş. Bir şenlik kur: ateş yansın, davul çalsın; ayaklarımız bir gece '
            'toprağı iş için değil oyun için dövsün.”',
        '“{ad} benim, orağı ben salladım. Bu {mevsim} kimse aç kalmayacak; bunu bilmek '
            'insanı bir tuhaf ediyor, kutlamak istiyor. Biraz altın harca. Söz, sabaha '
            'kadar konuşulur.”',
        '“Efendim, çocuklar harman yerinde şimdiden dönüp duruyor, kimse onlara oyna '
            'demedi. Köy kutlamak istiyor, bir izin bekliyor. Ateşi biz yakarız, sen bir '
            'söz söyle yeter.”',
      ],
      options: [
        PetitionOption(
          label: 'Şenlik kurulsun!',
          detail: 'Kese açılır. Ateş, davul, sabaha kadar süren bir gece.',
          resolutionPool: [
            '🎉 Şenlik kuruldu. Ateş sabaha kadar yandı, {ad} en son oturan oldu.',
            '🎉 Davul meydanda çalındı. İhtiyarlar bile bir tur döndü, sonra kendilerine güldüler.',
          ],
          goldDelta: -6,
          moraleAmount: 0.12,
          moraleDays: 4,
          fx: PetitionFx.festival,
          followUpId: 'festivalAnnual',
          followUpDelayDays: 2.0,
          estateMood: [(Estate.laborers, 0.12), (Estate.hearth, 0.06)],
        ),
        PetitionOption(
          label: 'Belki sonra',
          detail:
              'Kese kapalı. Ateş her akşamki gibi yanar, davul kutuda kalır.',
          resolutionPool: [
            '🎉 Şenlik ertelendi. Çocuklar harman yerinde bir süre daha dönüp dağıldı.',
            '🎉 Sonra dendi. {ad} davulu ambara geri kaldırdı.',
          ],
          moraleAmount: -0.02,
          moraleDays: 1,
          estateMood: [(Estate.laborers, -0.07)],
        ),
      ],
    ),
  ),

  // 🍄 Hasada mantar bulaştı (kriz). Etki alanı: TARLA.
  // hasCrops şart: tarlası olmayan köyde "ekin hastalığı" hem FX hem büyüme
  // cezası bakımından tamamen no-op bir kriz oluyordu.
  _PetitionDef(
    (c) => c.hasCrops && c.food >= 6,
    0.9,
    const Petition(
      id: 'cropBlight',
      petitioner: 'Telaşlı çiftçiler',
      icon: '🍄',
      title: 'Hasada Mantar Bulaştı',
      tone: PetitionTone.ominous,
      estate: Estate.laborers,
      stakes: 'Bugün bir kese altın, ya da bu {mevsim} ambarın yarısı.',
      bodyPool: [
        '“Efendim, koştum geldim. Doğu tarlasında başakların dibi kararmış; elimi '
            'sürdüm, parmağımda un gibi bir toz kaldı. Bu bir gecede yayılır. Bugün '
            'ilaçlarsak durur; yarın konuşursak konuşacak bir şey kalmaz.”',
        '“Sabah çiy kalkarken gördüm: yapraklarda kül rengi bir tüy var, koklayınca '
            'genzi yakıyor. Babam bunu bir kez görmüştü, o yıl kimse ekmek yüzü '
            'görmedi. Ne yapacaksan bugün yap.”',
        '“{ad} benim, üç tarlayı da dolaştım. Birinde yok, ikisinde var, üçüncüsünün '
            'sınırına dayanmış. Otları kaynatıp serper, birkaç sıra ürünü de sökersek '
            'durdururuz. Beklersek elimizde saman kalır.”',
      ],
      options: [
        PetitionOption(
          label: 'İlaçla, bulaşanı sök',
          detail: 'Altın ve birkaç sıra ürün gider. Mantar sınırda durur.',
          resolutionPool: [
            '🌾 Bulaşan sıralar söküldü, kalanı kaynatılmış otla serpildi. Mantar sınırı geçemedi.',
            '🌾 Tarlalar gece boyu ilaçlandı. Sabah {ad} eli boş değil, yorgun döndü.',
          ],
          goldDelta: -8,
          foodDelta: -3,
          moraleAmount: 0.02,
          moraleDays: 2,
          // İyi bakım hatırlanır → toprak ileride bereketle karşılık verir.
          setsFlags: ['fields.tended'],
          followUpId: 'bountifulHarvest',
          followUpDelayDays: 3.0,
          estateMood: [(Estate.laborers, 0.12), (Estate.artisans, -0.05)],
        ),
        PetitionOption(
          label: 'Bırak, doğa halletsin',
          detail: 'Ne altın ne emek. Mantar rüzgârla sıradan sıraya geçer.',
          resolutionPool: [
            '🍄 Mantar üç tarlaya birden yayıldı. Başaklar avuçta un gibi dağılıyor.',
            '🍄 Karışılmadı. {ad} ambarın kapağını açtı, kapattı, bir şey demedi.',
          ],
          foodDelta: -14,
          moraleAmount: -0.05,
          moraleDays: 3,
          fx: PetitionFx.cropBlight,
          setsFlags: ['fields.neglected'],
          estateMood: [(Estate.laborers, -0.16)],
        ),
      ],
    ),
  ),

  // ☀️ Yaz kuraklığı — MEVSİMSEL.
  _PetitionDef(
    (c) => c.season == Season.summer && c.hasCrops && c.food >= 5,
    0.95,
    const Petition(
      id: 'summerDrought',
      petitioner: 'Bunalmış çiftçiler',
      icon: '☀️',
      title: 'Yaz Kuraklığı Bastırdı',
      tone: PetitionTone.ominous,
      estate: Estate.laborers,
      stakes: 'Su taşımak altın ister; taşımamak ambarı boşaltır.',
      bodyPool: [
        '“On dokuz gündür damla yok, sayıyorum. Toprak öyle çatladı ki çatlağa elimi '
            'soktum, bileğime kadar girdi. Kuyudan taşırsak yetiştiririz. Bize birkaç el '
            've biraz altın ver.”',
        '“Efendim, sabah tarlaya girdim; başaklar ayağıma değince çıtırdadı, kuru saman '
            'gibi. Bugün kanal açarsak su tarlaya iner. Yarın açarsak toprağı sularız, '
            'ekini değil.”',
        '“{ad} benim, üç yaz gördüm böyle; üçünde de yağmur yetişti. Bu sefer üstümüzden '
            'bulut bile geçmiyor. Bekleyip dua etmeyi denedik; şimdi kova taşımayı '
            'deneyelim.”',
      ],
      options: [
        PetitionOption(
          label: 'Su taşıyın, kanal açın',
          detail: 'Altın ve emek gider. Kuyudan tarlaya su iner.',
          resolutionPool: [
            '💧 Gece boyu kova taşındı, sabaha kanal tarlaya ulaştı. Ekin kurtuldu.',
            '💧 Kanal açıldı. {ad} suyun ilk kez tarlaya girdiği yerde durup baktı.',
          ],
          goldDelta: -7,
          moraleAmount: 0.02,
          moraleDays: 2,
          setsFlags: ['fields.tended'],
          estateMood: [(Estate.laborers, 0.12), (Estate.artisans, -0.04)],
        ),
        PetitionOption(
          label: 'Yağmuru bekleyin',
          detail: 'Ne kova ne kanal. Güneş başakları olduğu yerde kavurur.',
          resolutionPool: [
            '🌾 Yağmur gelmedi. Başaklar tarlada ayakta kurudu, ambar dar kaldı.',
            '🌾 Beklendi. {ad} kuru bir başağı avucunda ufalayıp yere bıraktı.',
          ],
          foodDelta: -12,
          moraleAmount: -0.04,
          moraleDays: 3,
          fx: PetitionFx.cropBlight,
          setsFlags: ['fields.neglected'],
          estateMood: [(Estate.laborers, -0.14)],
        ),
      ],
    ),
  ),

  // ❄️ Kış erzak meclisi — MEVSİMSEL.
  _PetitionDef(
    (c) => c.season == Season.winter && c.population >= 4 && c.food >= 8,
    0.85,
    const Petition(
      id: 'winterProvisions',
      petitioner: 'Köy meclisi',
      icon: '❄️',
      title: 'Kış Erzağı Nasıl Bölüşülecek?',
      tone: PetitionTone.neutral,
      estate: Estate.hearth,
      stakes:
          'Sıkı hesap bahara çıkarır; bol sofra köyü ısıtır, ambarı eritir.',
      bodyPool: [
        '“Efendim, ambarı saydık, eksiğiyle saydık. Bahara doksan gün var, kaç gün '
            'yiyeceğimizi kâğıda yazdık. Ya kileyi ölçüp bölüşeceğiz, ya bu soğukta '
            'insanları karnı yarım yatırmayacağız. Karar senin.”',
        '“Toprak taş gibi, kazma girmiyor; ne ekilecek ne toplanacak. Elimizde ne varsa '
            'o. Kimi sıkı tut diyor, kimi bu soğukta bir sıcak çorba her şeyden kıymetli '
            'diyor. İkisi de doğru, ama biri seçilecek.”',
        '“{ad} benim, ambarın anahtarı bende. Dün gece bir kadın kapıya geldi, çocuğu '
            'üşüyor diye bir kile fazla istedi; veremedim. Sen söyle: kapıyı sıkı mı '
            'tutayım, açayım mı?”',
      ],
      options: [
        PetitionOption(
          label: 'Hesaplı bölün',
          detail: 'Kile ölçülür. Karınlar yarım, ambar bahara sağlam.',
          resolutionPool: [
            '🥖 Erzak kileyle bölündü. Kimse aç kalmadı, kimse doymadı da.',
            '🥖 {ad} ambarın kapağını her akşam ölçüyle açtı. Erzak bahara yetecek.',
          ],
          moraleAmount: -0.02,
          moraleDays: 2,
          estateMood: [(Estate.hearth, 0.06), (Estate.laborers, 0.04)],
        ),
        PetitionOption(
          label: 'Sofrayı bol kur',
          detail: 'Ambar açılır. Köy ısınır, kile hızla erir.',
          resolutionPool: [
            '🔥 Kış sofrası bol kuruldu. Çocuklar ilk kez tabağı sıyırmadan kalktı.',
            '🔥 Ambar açıldı. {köy} o akşam ısındı; {ad} kileyi saymayı bıraktı.',
          ],
          foodDelta: -10,
          moraleAmount: 0.06,
          moraleDays: 3,
          fx: PetitionFx.festival,
          estateMood: [(Estate.hearth, 0.08), (Estate.faithful, 0.04)],
        ),
      ],
    ),
  ),

  // 🕯️ Kayıp — bir köylü kendini bıraktı. Köylü her hâlükârda gider.
  _PetitionDef(
    (c) => c.population >= 5,
    0.4,
    const Petition(
      id: 'lostSoul',
      petitioner: 'Acı bir haber',
      icon: '🕯️',
      title: 'Köy Yasta',
      tone: PetitionTone.solemn,
      estate: Estate.hearth,
      stakes: 'Giden gitti. Geriye kalan tek soru: köy nasıl yas tutacak?',
      bodyPool: [
        '“Kapısı sabah da kapalıydı, öğlen de. Sonunda girdik. Ocağı günlerdir '
            'yanmamış, ekmeği olduğu gibi duruyordu. Kimse ona bir şey sormamış, kimse '
            'fark etmemiş; şimdi hepimiz konuşuyoruz. Köy nasıl yas tutsun?”',
        '“Efendim, dün akşam ateşin başında yanımda oturuyordu, tek kelime etmedi. Ben '
            'de sormadım, yorgundur dedim. Sabah bulduk. Bir söz söyle bize, ne '
            'yapacağımızı bilmiyoruz.”',
        '“{köy} bu sabah bir haberle uyandı. Çamaşırı ipte, tenceresi ocakta; sanki geri '
            'gelecekmiş gibi. Kadınlar avluda ayakta duruyor, kimse içeri girmiyor. Bir '
            'tören mi yapalım, sessizce mi uğurlayalım?”',
      ],
      options: [
        PetitionOption(
          label: 'Anma töreni düzenle',
          detail:
              'Köy ateşin başında toplanır, mumlar yakılır. Acı ortaklaşır.',
          resolutionPool: [''], // dinamik mesaj reaksiyondan gelir (isimle)
          // Çözüm metni boş (isim reaksiyondan gelir) → günceye düşecek
          // cümlenin ayrıca yazılması gerekir; yoksa kâtip "Köy Yasta: Anma
          // töreni düzenle" diye kuru bir başlık yazardı.
          annalPool: [
            'Anma töreni yapıldı. Ateşin başında mumlar sabaha kadar yandı.',
            'Köy giden için toplandı. Ad okundu, kimse acele etmedi.',
            'Yas ortak tutuldu. O akşam hiçbir kapı erken kapanmadı.',
          ],
          fx: PetitionFx.vigil,
          estateMood: [(Estate.hearth, 0.08), (Estate.faithful, 0.06)],
        ),
        PetitionOption(
          label: 'Sessizce uğurla',
          detail: 'Tören yok. Herkes kendi kapısının ardında yas tutar.',
          resolutionPool: [''],
          annalPool: [
            'Tören yapılmadı. Giden sessizce uğurlandı.',
            'Yas kapıların ardında tutuldu. Meydan boş kaldı.',
            'Anma verilmedi. Mumlar sandıkta kaldı.',
          ],
          fx: PetitionFx.mourn,
          estateMood: [(Estate.hearth, -0.08), (Estate.faithful, -0.05)],
        ),
      ],
    ),
  ),

  // ⛪ Yeni bir inanç. Zincir başı: "Bırak" → cult.active + cultGrows takibi.
  _PetitionDef(
    (c) =>
        c.population >= 5 &&
        !c.remembers('cult.active') &&
        !c.remembers('cult.suppressed'),
    0.5,
    const Petition(
      id: 'newFaith',
      petitioner: 'Tedirgin bir köylü',
      icon: '⛪',
      title: 'Yeni Bir İnanç',
      tone: PetitionTone.ominous,
      stakes: 'Göz yumarsan kök salar; dağıtırsan bir şey söner.',
      estate: Estate.faithful,
      bodyPool: [
        '“Efendim, gece yarısı su almaya çıktım. Ateşin başında beş kişi vardı, hiçbiri '
            'bizim duamızı okumuyordu; yere bir çember çizmiş, ortasına taş dizmişlerdi. '
            'Kızım da onların arasındaydı. Ne yapacağımı bilemedim, sana geldim.”',
        '“Ambarın arka duvarına bir işaret kazımışlar, ne olduğunu kimse bilmiyor. '
            'Çocuklar onu taklit ediyor, ezgisini bile öğrenmişler. Kötü bir şey mi, '
            'yeni bir şey mi, ayıramıyorum. Sen bak.”',
        '“{köy} sessizce ikiye ayrılıyor. Kimi o çemberden yüzü aydınlık dönüyor, kimi '
            'kapısını iki kez sürgülüyor. Ben ne diyeceğimi bilmiyorum. Sözü sen söyle.”',
      ],
      options: [
        PetitionOption(
          label: 'Bırak, inansınlar',
          detail:
              'Çember bozulmaz. Ateş başındaki ayin sürer, kimi ocak huzursuz.',
          resolutionPool: [
            '⛪ Ayinlere göz yumuldu. Çember her gece büyüyor, ezgi köyün diline yerleşti.',
            '⛪ İnanç kök saldı. Ambarın duvarındaki işareti artık çocuklar da çiziyor.',
          ],
          fx: PetitionFx.cult,
          setsFlags: ['cult.active'],
          followUpId: 'cultGrows',
          followUpDelayDays: 3.0,
          estateMood: [(Estate.faithful, 0.14), (Estate.hearth, -0.08)],
        ),
        PetitionOption(
          label: 'Vazgeçir onları',
          detail:
              'Çember silinir. Ateş başındaki toplantı dağılır, hevesler kırılır.',
          resolutionPool: [
            '⛪ Çember silindi. Ateşin başında bu gece kimse toplanmadı.',
            '⛪ İnanç dağıldı. Duvardaki işaret kazındı; izi hâlâ görünüyor.',
          ],
          moraleAmount: -0.03,
          moraleDays: 2,
          setsFlags: ['cult.suppressed'],
          estateMood: [(Estate.faithful, -0.14), (Estate.hearth, 0.06)],
        ),
      ],
    ),
  ),

  // ⛪ Anma Günü — kilise varsa cemaat göçenleri anmak ister. KİMSE ölmez.
  _PetitionDef(
    (c) => c.hasChurch && c.population >= 4,
    0.6,
    const Petition(
      id: 'remembranceDay',
      petitioner: 'Kilise cemaati',
      icon: '⛪',
      title: 'Anma Günü',
      tone: PetitionTone.solemn,
      estate: Estate.faithful,
      stakes:
          'Bir günlük durgunluk; karşılığında konuşulmayan adlar konuşulur.',
      bodyPool: [
        '“Efendim, mezarlıkta üç taşın yazısı silinmiş; kimin olduğunu soracak birini de '
            'bulamadım. Bir anma günü kur, adları yüksek sesle okuyalım, çocuklar duysun. '
            'Mum ucuz, unutmak pahalı.”',
        '“Geçen kış gidenler için hiçbirimiz doğru dürüst ağlayamadık; iş vardı, kış '
            'vardı. İçimizde kaldı. Bir gün ver bize: kilisede toplanalım, mumları '
            'yakalım, sonra rahat edelim.”',
        '“{ad} benim, mumları ben döküyorum. Elimde kırk mum var, hepsi bir isim için '
            'ayrıldı. Bir gün ilan et de yakalım. Hüzünlü olacak, biliyorum; ama '
            'ondan sonra köy hafifler.”',
      ],
      options: [
        PetitionOption(
          label: 'Anma günü ilan et',
          detail: 'Köy kiliseye iner. Adlar tek tek okunur, mumlar yakılır.',
          resolutionPool: [
            '⛪ Anma günü yapıldı. Kırk mum yandı, kırk ad okundu; kimse acele etmedi.',
            '⛪ Kilise doldu. {ad} son mumu yaktığında kimse yerinden kalkmamıştı.',
          ],
          moraleAmount: 0.06,
          moraleDays: 4,
          fx: PetitionFx.remembrance,
          estateMood: [(Estate.faithful, 0.10), (Estate.hearth, 0.05)],
        ),
        PetitionOption(
          label: 'Bugün değil',
          detail: 'Anma ertelenir. Mumlar sandıkta, adlar sessiz kalır.',
          resolutionPool: [
            '⛪ Anma günü ertelendi. {ad} mumları geri kaldırdı, tek tek sayarak.',
            '⛪ Bugün değil dendi. Mezarlıkta silinen yazıları soran olmadı.',
          ],
          moraleAmount: -0.02,
          moraleDays: 2,
          estateMood: [(Estate.faithful, -0.08)],
        ),
      ],
    ),
  ),

  // 💍 Köy düğünü — GERÇEK bir çift yuva kurar (scene_wedding id ile sunar).
  _PetitionDef(
    (c) => false,
    0.0,
    const Petition(
      id: 'villageWedding',
      petitioner: 'Sevdalı bir çift',
      icon: '💍',
      title: 'Bir Düğün Var',
      tone: PetitionTone.warm,
      estate: Estate.hearth,
      stakes: 'Coşkulu düğün keseyi hafifletir; sade tören gönlü yine ısıtır.',
      bodyPool: [
        '“Efendim, {öteki-i} ilk kez harmanda gördüm; saçında saman vardı, gülüyordu. O '
            'günden beri aklımdan çıkmadı. Yuva kurmak istiyoruz. Sen söyle: ateş '
            'yakalım mı, sessizce mi yapalım?”',
        '“İki yıldır aynı çeşmeden, aynı saatte su alırız; köy bunu bizden önce anladı. '
            'Artık o kapıyı bir kez çalıp içeri girmek istiyorum. {öteki} razı, ben '
            'razıyım. Kalan söz sende.”',
        '“Babam öldüğünde bana bir tek bu evi bıraktı, içinde iki tabak var. İkincisini '
            'bugüne kadar kimseye çıkarmadım. Bu {mevsim} çıkarmak istiyorum. Düğün büyük '
            'olsun, küçük olsun, sen bilirsin; yeter ki olsun.”',
      ],
      options: [
        PetitionOption(
          label: 'Coşkulu bir düğün!',
          detail: 'Kese açılır. Ateş, davul, alay, sabaha kadar oyun.',
          resolutionPool: [
            '💍 Düğün kuruldu. {ad} ile {öteki} ateşin çevresinde döndü, köy peşlerine takıldı.',
            '💍 Davul meydanda çalındı. {ad-in} eli {öteki-in} elinden sabaha kadar çıkmadı.',
          ],
          goldDelta: -4,
          moraleAmount: 0.10,
          moraleDays: 4,
          fx: PetitionFx.weddingGrand,
          estateMood: [
            (Estate.hearth, 0.10),
            (Estate.laborers, 0.04),
            (Estate.artisans, -0.04),
          ],
        ),
        PetitionOption(
          label: 'Sade bir tören yeter',
          detail: 'Kese kapalı. Ateşin başında kısa, içten bir tören.',
          resolutionPool: [
            '💍 Sade bir tören yapıldı. {ad} ile {öteki} ateşin başında el ele oturdu.',
            '💍 Nikâh ateşin başında kıyıldı. Kimse davul aramadı.',
          ],
          moraleAmount: 0.05,
          moraleDays: 3,
          fx: PetitionFx.wedding,
          estateMood: [(Estate.hearth, 0.06)],
        ),
      ],
    ),
  ),
];
