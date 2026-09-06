part of '../petition_system.dart';

/// Üç aşamalı hikâyeler: başlangıç → önceki cevaba bağlı karşılaşma →
/// stratejik yılda ortak/özel geçmişe bağlı sonuç. Kaybın ayrı kapanışı var.
final List<_PetitionDef> _kStoryPetitions = [
  _PetitionDef(
    (c) => StoryThreads.canStart(StoryThread.family, c.memory, c.storyCasts),
    1.8,
    const Petition(
      id: 'story.family.start',
      petitioner: '{ad} · {hane}',
      icon: '🌱',
      title: 'Kapının Önündeki Pay',
      bodyPool: [
        '{ad} kapısının önünde küçük bir bahçe istiyor. {storyPartner} de yardım etmeye hazır. İlk tohum ve çit için köyden pay istiyorlar.',
        '{ad} ile {storyPartner} aynı kapının önünde bir bahçe kurmak istiyor. Tohumu birlikte ekecekler; başlangıç için senden yardım bekliyorlar.',
        'Köyde yerleşen {ad}, {storyPartner} ile kapısının önünü yeşertmek istiyor. İlk masrafı köy üstlenecek mi?',
      ],
      options: [
        PetitionOption(
          label: 'Bahçeye pay ayır',
          detail:
              '2 odun ve 3 yiyecek; evin çevresine çiçeklik, iki kişi arasında ortaklık.',
          resolutionPool: [
            '{ad} kapı bahçesi için köyün desteğini aldı.',
            'Divanın kararıyla {ad} kapı bahçesi için köyün desteğini aldı.',
            'Köyün duyduğu hüküm belliydi: {ad} kapı bahçesi için köyün desteğini aldı.',
          ],
          setsFlags: [
            'story.family.started',
            'story.family.helped',
            'story.family.garden',
          ],
          clearsFlags: [],
          goldDelta: 0,
          foodDelta: -3,
          woodDelta: -2,
          followUpId: 'story.family.helped',
          followUpDelayDays: 2.0,
        ),
        PetitionOption(
          label: 'Kendi imkânlarıyla başlasınlar',
          detail:
              'Köyden kaynak verilmez; bu iki kişi talepleriyle yeniden gelir.',
          resolutionPool: [
            '{ad} bahçenin ilk masrafını kendi üstlenmek üzere ayrıldı.',
            'Divanın kararıyla {ad} bahçenin ilk masrafını kendi üstlenmek üzere ayrıldı.',
            'Köyün duyduğu hüküm belliydi: {ad} bahçenin ilk masrafını kendi üstlenmek üzere ayrıldı.',
          ],
          setsFlags: ['story.family.started', 'story.family.declined'],
          clearsFlags: [],
          goldDelta: 0,
          foodDelta: 0,
          woodDelta: 0,
          followUpId: 'story.family.declined',
          followUpDelayDays: 2.0,
        ),
      ],
    ),
    gravity: PetitionGravity.personal,
  ),
  _PetitionDef(
    (c) => false,
    0,
    const Petition(
      id: 'story.family.helped',
      petitioner: '{ad} · {hane}',
      icon: '🌱',
      title: 'Bahçenin Kapısı',
      bodyPool: [
        'İlk bahçe için verdiğin payı {storyLead} unutmadı. {storyPartner} şimdi kapıyı komşulara da açmayı öneriyor.',
        '{storyLead} ile {storyPartner} ilk yardımını anıyor. Bahçenin çevresinde komşular da buluşabilsin mi?',
        'Bahçe için el uzattığın {storyLead} yeniden geldi. {storyPartner} buranın ortak bir buluşma yeri olmasını istiyor.',
      ],
      note: 'İlk kararının devamı · aynı iki kişi',
      options: [
        PetitionOption(
          label: 'Komşulara aç',
          detail:
              'İki kişi düzenli buluşur; ortak usul köyün hafızasına yazılır.',
          resolutionPool: [
            '{ad} ortak usul için söz aldı; aynı kişiler yeniden buluşacak.',
            'Divanın kararıyla {ad} ortak usul için söz aldı; aynı kişiler yeniden buluşacak.',
            'Köyün duyduğu hüküm belliydi: {ad} ortak usul için söz aldı; aynı kişiler yeniden buluşacak.',
          ],
          setsFlags: [
            'story.family.garden',
            'story.family.open',
            'pact.neighbor',
          ],
          clearsFlags: ['story.family.closed'],
          goldDelta: 0,
          foodDelta: 0,
          woodDelta: 0,
          followUpId: 'story.family.shared',
          followUpDelayDays: 2.0,
        ),
        PetitionOption(
          label: 'İki kişide kalsın',
          detail:
              'Ortak gelenek kurulmaz; mesele büyüyen köyde yeniden açılır.',
          resolutionPool: [
            '{ad} meselenin özel kalacağı cevabını aldı.',
            'Divanın kararıyla {ad} meselenin özel kalacağı cevabını aldı.',
            'Köyün duyduğu hüküm belliydi: {ad} meselenin özel kalacağı cevabını aldı.',
          ],
          setsFlags: ['story.family.closed'],
          clearsFlags: ['story.family.garden', 'story.family.open'],
          goldDelta: 0,
          foodDelta: 0,
          woodDelta: 0,
          followUpId: 'story.family.private',
          followUpDelayDays: 2.0,
        ),
      ],
    ),
    gravity: PetitionGravity.personal,
  ),
  _PetitionDef(
    (c) => false,
    0,
    const Petition(
      id: 'story.family.declined',
      petitioner: '{ad} · {hane}',
      icon: '🌱',
      title: 'Vazgeçmedikleri Bahçe',
      bodyPool: [
        'İlk istekte kaynak vermedin. {storyLead} ile {storyPartner} yine de vazgeçmedi; şimdi komşularla birlikte başlamayı öneriyorlar.',
        '{storyLead} önceki reddini hatırlıyor. {storyPartner} masrafı paylaşacak komşular bulmak için izin istiyor.',
        'Köyden ilk payı alamayan {storyLead} geri geldi. {storyPartner} ile kapılarını ortak işe açmak istiyorlar.',
      ],
      note: 'İlk kararının devamı · aynı iki kişi',
      options: [
        PetitionOption(
          label: 'Komşulara aç',
          detail:
              'İki kişi düzenli buluşur; ortak usul köyün hafızasına yazılır.',
          resolutionPool: [
            '{ad} ortak usul için söz aldı; aynı kişiler yeniden buluşacak.',
            'Divanın kararıyla {ad} ortak usul için söz aldı; aynı kişiler yeniden buluşacak.',
            'Köyün duyduğu hüküm belliydi: {ad} ortak usul için söz aldı; aynı kişiler yeniden buluşacak.',
          ],
          setsFlags: [
            'story.family.garden',
            'story.family.open',
            'pact.neighbor',
          ],
          clearsFlags: ['story.family.closed'],
          goldDelta: 0,
          foodDelta: 0,
          woodDelta: 0,
          followUpId: 'story.family.shared',
          followUpDelayDays: 2.0,
        ),
        PetitionOption(
          label: 'İki kişide kalsın',
          detail:
              'Ortak gelenek kurulmaz; mesele büyüyen köyde yeniden açılır.',
          resolutionPool: [
            '{ad} meselenin özel kalacağı cevabını aldı.',
            'Divanın kararıyla {ad} meselenin özel kalacağı cevabını aldı.',
            'Köyün duyduğu hüküm belliydi: {ad} meselenin özel kalacağı cevabını aldı.',
          ],
          setsFlags: ['story.family.closed'],
          clearsFlags: ['story.family.garden', 'story.family.open'],
          goldDelta: 0,
          foodDelta: 0,
          woodDelta: 0,
          followUpId: 'story.family.private',
          followUpDelayDays: 2.0,
        ),
      ],
    ),
    gravity: PetitionGravity.personal,
  ),
  _PetitionDef(
    (c) => false,
    0,
    const Petition(
      id: 'story.family.shared',
      petitioner: '{ad} · {hane}',
      icon: '🌱',
      title: 'Bahçeden Üretim Yoluna',
      bodyPool: [
        'Bir zamanlar bahçe için buluşan {storyLead} ve {storyPartner}, büyüyen köyde ürün yolunu konuşuyor. Ortaklığı üretim ağına taşıyacak mısın?',
        '{storyLead} ilk kapı bahçesini hatırlattı. {storyPartner} artık komşuların üretim noktalarını aynı yola bağlamasını istiyor.',
        'Köy büyüdü; {storyLead} ile {storyPartner} bahçedeki ortaklığı üreticiler arasında sürdürmek istiyor. Yol ağını kurmak yine senin elinde.',
      ],
      note: '3. yıl ve sonrası · köyün üretimi',
      options: [
        PetitionOption(
          label: 'Üretici ortaklığını destekle',
          detail:
              '8 altın; hanenin desteği güçlenir. Üç üretim noktasını aynı yola bağlama hedefi sürer.',
          resolutionPool: [
            '{ad} üretici ortaklığı için destek aldı; üretim yolunun tamamlanmasını bekliyor.',
            'Divanın kararıyla {ad} üretici ortaklığı için destek aldı; üretim yolunun tamamlanmasını bekliyor.',
            'Köyün duyduğu hüküm belliydi: {ad} üretici ortaklığı için destek aldı; üretim yolunun tamamlanmasını bekliyor.',
          ],
          setsFlags: [
            'story.family.garden',
            'story.family.done',
            'story.family.backed',
            'pact.neighbor',
          ],
          clearsFlags: ['story.family.closed'],
          goldDelta: -8,
          foodDelta: 0,
          woodDelta: 0,
        ),
        PetitionOption(
          label: 'Yerel anlaşmayla yetinelim',
          detail:
              'Kaynak harcanmaz; büyük ortaklık kurulmaz, bu hikâye kapanır.',
          resolutionPool: [
            '{ad} büyük ortaklık desteği alamadı; mesele yerel anlaşmayla kapandı.',
            'Divanın kararıyla {ad} büyük ortaklık desteği alamadı; mesele yerel anlaşmayla kapandı.',
            'Köyün duyduğu hüküm belliydi: {ad} büyük ortaklık desteği alamadı; mesele yerel anlaşmayla kapandı.',
          ],
          setsFlags: ['story.family.done', 'story.family.local'],
          clearsFlags: ['story.family.garden'],
          goldDelta: 0,
          foodDelta: 0,
          woodDelta: 0,
        ),
      ],
    ),
    gravity: PetitionGravity.personal,
  ),
  _PetitionDef(
    (c) => false,
    0,
    const Petition(
      id: 'story.family.private',
      petitioner: '{ad} · {hane}',
      icon: '🌱',
      title: 'Kapıda Kalan Ürün',
      bodyPool: [
        'Bahçeyi özel tutmuştun. {storyLead} ve {storyPartner} şimdi büyüyen köyde üretim yoluna katılmayı yeniden teklif ediyor.',
        '{storyLead} kapıda kalan bahçeyi hatırlatıyor. {storyPartner} bu kez üreticilerle ortak bir yol için destek istiyor.',
        'Önceki kararın bahçeyi iki kişiye bıraktı. {storyLead} ve {storyPartner} üretim ağına katılmak için yeni bir söz bekliyor.',
      ],
      note: '3. yıl ve sonrası · köyün üretimi',
      options: [
        PetitionOption(
          label: 'Üretici ortaklığını destekle',
          detail:
              '8 altın; hanenin desteği güçlenir. Üç üretim noktasını aynı yola bağlama hedefi sürer.',
          resolutionPool: [
            '{ad} üretici ortaklığı için destek aldı; üretim yolunun tamamlanmasını bekliyor.',
            'Divanın kararıyla {ad} üretici ortaklığı için destek aldı; üretim yolunun tamamlanmasını bekliyor.',
            'Köyün duyduğu hüküm belliydi: {ad} üretici ortaklığı için destek aldı; üretim yolunun tamamlanmasını bekliyor.',
          ],
          setsFlags: [
            'story.family.garden',
            'story.family.done',
            'story.family.backed',
            'pact.neighbor',
          ],
          clearsFlags: ['story.family.closed'],
          goldDelta: -8,
          foodDelta: 0,
          woodDelta: 0,
        ),
        PetitionOption(
          label: 'Yerel anlaşmayla yetinelim',
          detail:
              'Kaynak harcanmaz; büyük ortaklık kurulmaz, bu hikâye kapanır.',
          resolutionPool: [
            '{ad} büyük ortaklık desteği alamadı; mesele yerel anlaşmayla kapandı.',
            'Divanın kararıyla {ad} büyük ortaklık desteği alamadı; mesele yerel anlaşmayla kapandı.',
            'Köyün duyduğu hüküm belliydi: {ad} büyük ortaklık desteği alamadı; mesele yerel anlaşmayla kapandı.',
          ],
          setsFlags: ['story.family.done', 'story.family.local'],
          clearsFlags: ['story.family.garden'],
          goldDelta: 0,
          foodDelta: 0,
          woodDelta: 0,
        ),
      ],
    ),
    gravity: PetitionGravity.personal,
  ),
  _PetitionDef(
    (c) => false,
    0,
    const Petition(
      id: 'story.family.loss',
      petitioner: '{ad} · {hane}',
      icon: '🌱',
      title: 'Yarım Kalan Söz',
      bodyPool: [
        '{storyLead} ile {storyPartner} için başlayan mesele değişti: {storyMissing} artık köyde değil. Eski sözü nasıl kapatacağız?',
        'İlk kararı verdiğin iki kişiden {storyMissing} artık burada değil. {storyLead} ve {storyPartner} için açılan sayfa bir kapanış bekliyor.',
        '{storyMissing} köyden eksildi; eski görüşme aynı kişilerle süremeyecek. {storyLead} ve {storyPartner} için verdiğin sözü hatıraya mı dönüştürelim?',
      ],
      note: 'Köyden eksilen yüz · hikâyenin kapanışı',
      options: [
        PetitionOption(
          label: 'Sözü hatıra olarak sakla',
          detail: 'Kaynak bedeli yok; anma yapılır ve hikâye kapanır.',
          resolutionPool: [
            'Eski söz köyün hatırasına alındı; yarım kalan mesele kapandı.',
            'Divanın kararıyla Eski söz köyün hatırasına alındı; yarım kalan mesele kapandı.',
            'Köyün duyduğu hüküm belliydi: Eski söz köyün hatırasına alındı; yarım kalan mesele kapandı.',
          ],
          setsFlags: ['story.family.done', 'story.family.remembered'],
          clearsFlags: ['story.family.garden'],
          goldDelta: 0,
          foodDelta: 0,
          woodDelta: 0,
          fx: PetitionFx.remembrance,
        ),
        PetitionOption(
          label: 'Sayfayı sessizce kapat',
          detail: 'Kaynak bedeli yok; tören yapılmadan hikâye kapanır.',
          resolutionPool: [
            'Yarım kalan mesele sessizce kapatıldı; eski karar güncede kaldı.',
            'Divanın kararıyla Yarım kalan mesele sessizce kapatıldı; eski karar güncede kaldı.',
            'Köyün duyduğu hüküm belliydi: Yarım kalan mesele sessizce kapatıldı; eski karar güncede kaldı.',
          ],
          setsFlags: ['story.family.done', 'story.family.closed'],
          clearsFlags: ['story.family.garden'],
          goldDelta: 0,
          foodDelta: 0,
          woodDelta: 0,
        ),
      ],
    ),
    gravity: PetitionGravity.personal,
  ),
  _PetitionDef(
    (c) => StoryThreads.canStart(
      StoryThread.apprenticeship,
      c.memory,
      c.storyCasts,
    ),
    1.8,
    const Petition(
      id: 'story.apprenticeship.start',
      petitioner: '{ad} · {hane}',
      icon: '🪵',
      title: 'Ustanın Yanındaki Yer',
      bodyPool: [
        '{ad}, {storyPartner} için yanında bir öğrenme yeri istiyor. Bildiği {storyCraft} bilgisini çalışmadıkları saatlerde paylaşacak.',
        '{storyPartner} öğrenmek istiyor; {ad} da {storyCraft} bilgisini aktaracak birini arıyor. Birlikte çalışmaları için pay ayıracak mısın?',
        '{ad} bugün kendi ücretini değil, {storyPartner} için öğrenme fırsatını konuşuyor. Konu {storyCraft}; köy malzeme verecek mi?',
      ],
      options: [
        PetitionOption(
          label: 'Öğrenme payı ayır',
          detail:
              '4 odun; usta ve öğrenen boş vakitlerinde buluşur, gerçek ustalık birikir.',
          resolutionPool: [
            '{ad} öğrenme malzemesi aldı; boş saatlerde birlikte çalışacak.',
            'Divanın kararıyla {ad} öğrenme malzemesi aldı; boş saatlerde birlikte çalışacak.',
            'Köyün duyduğu hüküm belliydi: {ad} öğrenme malzemesi aldı; boş saatlerde birlikte çalışacak.',
          ],
          setsFlags: [
            'story.apprenticeship.started',
            'story.apprenticeship.helped',
            'story.apprenticeship.teaching',
          ],
          clearsFlags: [],
          goldDelta: 0,
          foodDelta: 0,
          woodDelta: -4,
          followUpId: 'story.apprenticeship.helped',
          followUpDelayDays: 2.0,
        ),
        PetitionOption(
          label: 'Şimdilik ertele',
          detail: 'Malzeme harcanmaz; aynı ikili yeni bir öneriyle geri gelir.',
          resolutionPool: [
            '{ad} öğrenme payını alamadı; bu isteği yeniden düşünmek üzere ayrıldı.',
            'Divanın kararıyla {ad} öğrenme payını alamadı; bu isteği yeniden düşünmek üzere ayrıldı.',
            'Köyün duyduğu hüküm belliydi: {ad} öğrenme payını alamadı; bu isteği yeniden düşünmek üzere ayrıldı.',
          ],
          setsFlags: [
            'story.apprenticeship.started',
            'story.apprenticeship.declined',
          ],
          clearsFlags: [],
          goldDelta: 0,
          foodDelta: 0,
          woodDelta: 0,
          followUpId: 'story.apprenticeship.declined',
          followUpDelayDays: 2.0,
        ),
      ],
    ),
    gravity: PetitionGravity.personal,
  ),
  _PetitionDef(
    (c) => false,
    0,
    const Petition(
      id: 'story.apprenticeship.helped',
      petitioner: '{ad} · {hane}',
      icon: '🪵',
      title: 'Bilgi Kimin Hakkı',
      bodyPool: [
        'Öğrenme payını verdiğin {storyLead} geri geldi. {storyPartner} ile başlayan çalışmanın köyün açık bir öğrenme geleneği olmasını istiyor.',
        '{storyLead} ilk malzeme desteğini hatırlatıyor. {storyPartner} ile ayırdıkları saatler köyün ortak usulü sayılacak mı?',
        '{storyPartner} için açtığın yer şimdi yeni bir soruyu getirdi: {storyLead} bu öğrenme hakkını köyün geleneğine dönüştürmek istiyor.',
      ],
      note: 'İlk kararının devamı · aynı iki kişi',
      options: [
        PetitionOption(
          label: 'Öğrenmeyi gelenek yap',
          detail:
              'İki kişi düzenli buluşur; ortak usul köyün hafızasına yazılır.',
          resolutionPool: [
            '{ad} ortak usul için söz aldı; aynı kişiler yeniden buluşacak.',
            'Divanın kararıyla {ad} ortak usul için söz aldı; aynı kişiler yeniden buluşacak.',
            'Köyün duyduğu hüküm belliydi: {ad} ortak usul için söz aldı; aynı kişiler yeniden buluşacak.',
          ],
          setsFlags: [
            'story.apprenticeship.teaching',
            'story.apprenticeship.open',
            'craft.school',
          ],
          clearsFlags: ['story.apprenticeship.closed'],
          goldDelta: 0,
          foodDelta: 0,
          woodDelta: 0,
          followUpId: 'story.apprenticeship.shared',
          followUpDelayDays: 2.0,
        ),
        PetitionOption(
          label: 'Özel anlaşma olarak kalsın',
          detail:
              'Ortak gelenek kurulmaz; mesele büyüyen köyde yeniden açılır.',
          resolutionPool: [
            '{ad} meselenin özel kalacağı cevabını aldı.',
            'Divanın kararıyla {ad} meselenin özel kalacağı cevabını aldı.',
            'Köyün duyduğu hüküm belliydi: {ad} meselenin özel kalacağı cevabını aldı.',
          ],
          setsFlags: ['story.apprenticeship.closed'],
          clearsFlags: [
            'story.apprenticeship.teaching',
            'story.apprenticeship.open',
          ],
          goldDelta: 0,
          foodDelta: 0,
          woodDelta: 0,
          followUpId: 'story.apprenticeship.private',
          followUpDelayDays: 2.0,
        ),
      ],
    ),
    gravity: PetitionGravity.personal,
  ),
  _PetitionDef(
    (c) => false,
    0,
    const Petition(
      id: 'story.apprenticeship.declined',
      petitioner: '{ad} · {hane}',
      icon: '🪵',
      title: 'Tezgâhın İkinci Çağrısı',
      bodyPool: [
        'İlk öğrenme payını ertelemiştin. {storyLead}, {storyPartner} ile boş saatlerde başlamayı teklif ediyor. Bu kez izin verecek misin?',
        '{storyLead} önceki cevabını unutmamış. {storyPartner} ile küçük başlayıp bilgiyi köye açmak istiyor.',
        'Malzeme isteği karşılanmayan {storyLead} yeniden geldi. {storyPartner} için ücretsiz boş saatlerini ayırmayı öneriyor.',
      ],
      note: 'İlk kararının devamı · aynı iki kişi',
      options: [
        PetitionOption(
          label: 'Öğrenmeyi gelenek yap',
          detail:
              'İki kişi düzenli buluşur; ortak usul köyün hafızasına yazılır.',
          resolutionPool: [
            '{ad} ortak usul için söz aldı; aynı kişiler yeniden buluşacak.',
            'Divanın kararıyla {ad} ortak usul için söz aldı; aynı kişiler yeniden buluşacak.',
            'Köyün duyduğu hüküm belliydi: {ad} ortak usul için söz aldı; aynı kişiler yeniden buluşacak.',
          ],
          setsFlags: [
            'story.apprenticeship.teaching',
            'story.apprenticeship.open',
            'craft.school',
          ],
          clearsFlags: ['story.apprenticeship.closed'],
          goldDelta: 0,
          foodDelta: 0,
          woodDelta: 0,
          followUpId: 'story.apprenticeship.shared',
          followUpDelayDays: 2.0,
        ),
        PetitionOption(
          label: 'Özel anlaşma olarak kalsın',
          detail:
              'Ortak gelenek kurulmaz; mesele büyüyen köyde yeniden açılır.',
          resolutionPool: [
            '{ad} meselenin özel kalacağı cevabını aldı.',
            'Divanın kararıyla {ad} meselenin özel kalacağı cevabını aldı.',
            'Köyün duyduğu hüküm belliydi: {ad} meselenin özel kalacağı cevabını aldı.',
          ],
          setsFlags: ['story.apprenticeship.closed'],
          clearsFlags: [
            'story.apprenticeship.teaching',
            'story.apprenticeship.open',
          ],
          goldDelta: 0,
          foodDelta: 0,
          woodDelta: 0,
          followUpId: 'story.apprenticeship.private',
          followUpDelayDays: 2.0,
        ),
      ],
    ),
    gravity: PetitionGravity.personal,
  ),
  _PetitionDef(
    (c) => false,
    0,
    const Petition(
      id: 'story.apprenticeship.shared',
      petitioner: '{ad} · {hane}',
      icon: '🪵',
      title: 'Bir Tezgâhtan Köyün Bilgisine',
      bodyPool: [
        '{storyLead} ve {storyPartner} için verdiğin öğrenme sözü, büyüyen köyde zanaatların korunması meselesine döndü. Bu geleneğe destek verecek misin?',
        'İlk tezgâh isteğini {storyLead} hatırlattı. {storyPartner} ile başlattıkları usulü, köyün yedi zanaatı yaşatma hedefinin parçası yapmak istiyor.',
        '{storyLead} ile {storyPartner} yeniden kapında. Köy büyüdükçe öğrenme geleneğinin de desteklenmesini istiyorlar; diğer zanaatları yaşatmak hâlâ köyün işi.',
      ],
      note: '3. yıl ve sonrası · köyün üretimi',
      options: [
        PetitionOption(
          label: 'Öğrenme geleneğini destekle',
          detail:
              '8 altın; iki hanenin desteği ve öğrenme bağı güçlenir. Yedi zanaatı yaşatma hedefi ayrıca sürer.',
          resolutionPool: [
            '{ad} öğrenme geleneği için destek aldı; köyün zanaatlarını koruma sözü kayda geçti.',
            'Divanın kararıyla {ad} öğrenme geleneği için destek aldı; köyün zanaatlarını koruma sözü kayda geçti.',
            'Köyün duyduğu hüküm belliydi: {ad} öğrenme geleneği için destek aldı; köyün zanaatlarını koruma sözü kayda geçti.',
          ],
          setsFlags: [
            'story.apprenticeship.teaching',
            'story.apprenticeship.done',
            'story.apprenticeship.backed',
            'craft.school',
          ],
          clearsFlags: ['story.apprenticeship.closed'],
          goldDelta: -8,
          foodDelta: 0,
          woodDelta: 0,
        ),
        PetitionOption(
          label: 'Yerel anlaşmayla yetinelim',
          detail:
              'Kaynak harcanmaz; büyük ortaklık kurulmaz, bu hikâye kapanır.',
          resolutionPool: [
            '{ad} büyük ortaklık desteği alamadı; mesele yerel anlaşmayla kapandı.',
            'Divanın kararıyla {ad} büyük ortaklık desteği alamadı; mesele yerel anlaşmayla kapandı.',
            'Köyün duyduğu hüküm belliydi: {ad} büyük ortaklık desteği alamadı; mesele yerel anlaşmayla kapandı.',
          ],
          setsFlags: [
            'story.apprenticeship.done',
            'story.apprenticeship.local',
          ],
          clearsFlags: ['story.apprenticeship.teaching'],
          goldDelta: 0,
          foodDelta: 0,
          woodDelta: 0,
        ),
      ],
    ),
    gravity: PetitionGravity.personal,
  ),
  _PetitionDef(
    (c) => false,
    0,
    const Petition(
      id: 'story.apprenticeship.private',
      petitioner: '{ad} · {hane}',
      icon: '🪵',
      title: 'İki Kişide Kalan Bilgi',
      bodyPool: [
        'Öğrenme meselesini iki kişide tutmuştun. {storyLead} ve {storyPartner} şimdi köyün zanaatlarını korumak için kararını yeniden açmanı istiyor.',
        '{storyLead} dar tuttuğun öğrenme hakkını hatırlatıyor. {storyPartner} ile köyün bilgisine katkı vermek istiyorlar.',
        'Köy büyüdü ama ilk tezgâh sözü sınırlı kaldı. {storyLead} ve {storyPartner} bu kez ortak bir öğrenme geleneği için geldi.',
      ],
      note: '3. yıl ve sonrası · köyün üretimi',
      options: [
        PetitionOption(
          label: 'Öğrenme geleneğini destekle',
          detail:
              '8 altın; iki hanenin desteği ve öğrenme bağı güçlenir. Yedi zanaatı yaşatma hedefi ayrıca sürer.',
          resolutionPool: [
            '{ad} öğrenme geleneği için destek aldı; köyün zanaatlarını koruma sözü kayda geçti.',
            'Divanın kararıyla {ad} öğrenme geleneği için destek aldı; köyün zanaatlarını koruma sözü kayda geçti.',
            'Köyün duyduğu hüküm belliydi: {ad} öğrenme geleneği için destek aldı; köyün zanaatlarını koruma sözü kayda geçti.',
          ],
          setsFlags: [
            'story.apprenticeship.teaching',
            'story.apprenticeship.done',
            'story.apprenticeship.backed',
            'craft.school',
          ],
          clearsFlags: ['story.apprenticeship.closed'],
          goldDelta: -8,
          foodDelta: 0,
          woodDelta: 0,
        ),
        PetitionOption(
          label: 'Yerel anlaşmayla yetinelim',
          detail:
              'Kaynak harcanmaz; büyük ortaklık kurulmaz, bu hikâye kapanır.',
          resolutionPool: [
            '{ad} büyük ortaklık desteği alamadı; mesele yerel anlaşmayla kapandı.',
            'Divanın kararıyla {ad} büyük ortaklık desteği alamadı; mesele yerel anlaşmayla kapandı.',
            'Köyün duyduğu hüküm belliydi: {ad} büyük ortaklık desteği alamadı; mesele yerel anlaşmayla kapandı.',
          ],
          setsFlags: [
            'story.apprenticeship.done',
            'story.apprenticeship.local',
          ],
          clearsFlags: ['story.apprenticeship.teaching'],
          goldDelta: 0,
          foodDelta: 0,
          woodDelta: 0,
        ),
      ],
    ),
    gravity: PetitionGravity.personal,
  ),
  _PetitionDef(
    (c) => false,
    0,
    const Petition(
      id: 'story.apprenticeship.loss',
      petitioner: '{ad} · {hane}',
      icon: '🪵',
      title: 'Yarım Kalan Söz',
      bodyPool: [
        '{storyLead} ile {storyPartner} için başlayan mesele değişti: {storyMissing} artık köyde değil. Eski sözü nasıl kapatacağız?',
        'İlk kararı verdiğin iki kişiden {storyMissing} artık burada değil. {storyLead} ve {storyPartner} için açılan sayfa bir kapanış bekliyor.',
        '{storyMissing} köyden eksildi; eski görüşme aynı kişilerle süremeyecek. {storyLead} ve {storyPartner} için verdiğin sözü hatıraya mı dönüştürelim?',
      ],
      note: 'Köyden eksilen yüz · hikâyenin kapanışı',
      options: [
        PetitionOption(
          label: 'Sözü hatıra olarak sakla',
          detail: 'Kaynak bedeli yok; anma yapılır ve hikâye kapanır.',
          resolutionPool: [
            'Eski söz köyün hatırasına alındı; yarım kalan mesele kapandı.',
            'Divanın kararıyla Eski söz köyün hatırasına alındı; yarım kalan mesele kapandı.',
            'Köyün duyduğu hüküm belliydi: Eski söz köyün hatırasına alındı; yarım kalan mesele kapandı.',
          ],
          setsFlags: [
            'story.apprenticeship.done',
            'story.apprenticeship.remembered',
          ],
          clearsFlags: ['story.apprenticeship.teaching'],
          goldDelta: 0,
          foodDelta: 0,
          woodDelta: 0,
          fx: PetitionFx.remembrance,
        ),
        PetitionOption(
          label: 'Sayfayı sessizce kapat',
          detail: 'Kaynak bedeli yok; tören yapılmadan hikâye kapanır.',
          resolutionPool: [
            'Yarım kalan mesele sessizce kapatıldı; eski karar güncede kaldı.',
            'Divanın kararıyla Yarım kalan mesele sessizce kapatıldı; eski karar güncede kaldı.',
            'Köyün duyduğu hüküm belliydi: Yarım kalan mesele sessizce kapatıldı; eski karar güncede kaldı.',
          ],
          setsFlags: [
            'story.apprenticeship.done',
            'story.apprenticeship.closed',
          ],
          clearsFlags: ['story.apprenticeship.teaching'],
          goldDelta: 0,
          foodDelta: 0,
          woodDelta: 0,
        ),
      ],
    ),
    gravity: PetitionGravity.personal,
  ),
  _PetitionDef(
    (c) => StoryThreads.canStart(StoryThread.accord, c.memory, c.storyCasts),
    1.8,
    const Petition(
      id: 'story.accord.start',
      petitioner: '{ad} · {hane}',
      icon: '🤝',
      title: 'İki Kapının Arasındaki Söz',
      bodyPool: [
        '{ad} ile {storyPartner}, hanelerinin ortak işler için kimin sözünü dinleyeceğinde anlaşamıyor. Aynı sofrada konuşmalarını sağlayacak mısın?',
        '{ad} kendi hanesinin sözünü savunuyor; {storyPartner} de kendi hanesini temsil ediyor. Ortak işler için bir konuşma sofrası istiyorlar.',
        'İki hane ortak işlerde ayrı telden çalıyor. {ad} ve {storyPartner} sıranın kimde olacağını konuşmak için önüne geldi.',
      ],
      options: [
        PetitionOption(
          label: 'Aynı sofraya çağır',
          detail:
              '4 yiyecek; iki temsilci arasında barışma ve düzenli buluşma bağı kurulur.',
          resolutionPool: [
            '{ad} ortak sofra için pay aldı; iki hane konuşmaya başlayacak.',
            'Divanın kararıyla {ad} ortak sofra için pay aldı; iki hane konuşmaya başlayacak.',
            'Köyün duyduğu hüküm belliydi: {ad} ortak sofra için pay aldı; iki hane konuşmaya başlayacak.',
          ],
          setsFlags: [
            'story.accord.started',
            'story.accord.helped',
            'story.accord.table',
          ],
          clearsFlags: [],
          goldDelta: 0,
          foodDelta: -4,
          woodDelta: 0,
          followUpId: 'story.accord.helped',
          followUpDelayDays: 2.0,
        ),
        PetitionOption(
          label: 'Haneler kendi konuşsun',
          detail:
              'Kaynak harcanmaz; ortak söz sorunu aynı kişilerle yeniden gelir.',
          resolutionPool: [
            '{ad} ortak sofra desteği olmadan kendi hanesine döndü.',
            'Divanın kararıyla {ad} ortak sofra desteği olmadan kendi hanesine döndü.',
            'Köyün duyduğu hüküm belliydi: {ad} ortak sofra desteği olmadan kendi hanesine döndü.',
          ],
          setsFlags: ['story.accord.started', 'story.accord.declined'],
          clearsFlags: [],
          goldDelta: 0,
          foodDelta: 0,
          woodDelta: 0,
          followUpId: 'story.accord.declined',
          followUpDelayDays: 2.0,
        ),
      ],
    ),
    gravity: PetitionGravity.personal,
  ),
  _PetitionDef(
    (c) => false,
    0,
    const Petition(
      id: 'story.accord.helped',
      petitioner: '{ad} · {hane}',
      icon: '🤝',
      title: 'Sofrada Kimin Sözü',
      bodyPool: [
        'Sofrasına pay verdiğin {storyLead} ve {storyPartner} geri geldi. Bir hanenin ağırlığı mı geçsin, söz sırayla mı söylensin?',
        '{storyLead} ilk ortak sofrayı hatırlatıyor. {storyPartner} iki hanenin de eşit söz hakkı olmasını istiyor.',
        'İki haneyi bir araya getirdin. Şimdi {storyLead} ve {storyPartner}, ortak işlerde nasıl söz alacaklarına hükmetmeni bekliyor.',
      ],
      note: 'İlk kararının devamı · aynı iki kişi',
      options: [
        PetitionOption(
          label: 'Söz sırayla söylensin',
          detail:
              'İki kişi düzenli buluşur; ortak usul köyün hafızasına yazılır.',
          resolutionPool: [
            '{ad} ortak usul için söz aldı; aynı kişiler yeniden buluşacak.',
            'Divanın kararıyla {ad} ortak usul için söz aldı; aynı kişiler yeniden buluşacak.',
            'Köyün duyduğu hüküm belliydi: {ad} ortak usul için söz aldı; aynı kişiler yeniden buluşacak.',
          ],
          setsFlags: [
            'story.accord.table',
            'story.accord.open',
            'assembly.tradition',
          ],
          clearsFlags: ['story.accord.closed'],
          goldDelta: 0,
          foodDelta: 0,
          woodDelta: 0,
          followUpId: 'story.accord.shared',
          followUpDelayDays: 2.0,
        ),
        PetitionOption(
          label: 'Haneler ayrı karar versin',
          detail:
              'Ortak gelenek kurulmaz; mesele büyüyen köyde yeniden açılır.',
          resolutionPool: [
            '{ad} meselenin özel kalacağı cevabını aldı.',
            'Divanın kararıyla {ad} meselenin özel kalacağı cevabını aldı.',
            'Köyün duyduğu hüküm belliydi: {ad} meselenin özel kalacağı cevabını aldı.',
          ],
          setsFlags: ['story.accord.closed'],
          clearsFlags: ['story.accord.table', 'story.accord.open'],
          goldDelta: 0,
          foodDelta: 0,
          woodDelta: 0,
          followUpId: 'story.accord.private',
          followUpDelayDays: 2.0,
        ),
      ],
    ),
    gravity: PetitionGravity.personal,
  ),
  _PetitionDef(
    (c) => false,
    0,
    const Petition(
      id: 'story.accord.declined',
      petitioner: '{ad} · {hane}',
      icon: '🤝',
      title: 'İki Hanenin İkinci Sözü',
      bodyPool: [
        'İlk ortak sofraya pay vermedin. {storyLead} ve {storyPartner} bu kez doğrudan söz sırasını çözmeni istiyor.',
        '{storyLead} ile {storyPartner} aynı anlaşmazlıkla geri geldi. Ortak işlerde söz eşit mi olacak, her hane kendi yoluna mı bakacak?',
        'Önceki kararın iki haneyi kendi başına bıraktı. {storyLead} ve {storyPartner} ortak bir usul olmadan ilerleyemeyeceklerini söylüyor.',
      ],
      note: 'İlk kararının devamı · aynı iki kişi',
      options: [
        PetitionOption(
          label: 'Söz sırayla söylensin',
          detail:
              'İki kişi düzenli buluşur; ortak usul köyün hafızasına yazılır.',
          resolutionPool: [
            '{ad} ortak usul için söz aldı; aynı kişiler yeniden buluşacak.',
            'Divanın kararıyla {ad} ortak usul için söz aldı; aynı kişiler yeniden buluşacak.',
            'Köyün duyduğu hüküm belliydi: {ad} ortak usul için söz aldı; aynı kişiler yeniden buluşacak.',
          ],
          setsFlags: [
            'story.accord.table',
            'story.accord.open',
            'assembly.tradition',
          ],
          clearsFlags: ['story.accord.closed'],
          goldDelta: 0,
          foodDelta: 0,
          woodDelta: 0,
          followUpId: 'story.accord.shared',
          followUpDelayDays: 2.0,
        ),
        PetitionOption(
          label: 'Haneler ayrı karar versin',
          detail:
              'Ortak gelenek kurulmaz; mesele büyüyen köyde yeniden açılır.',
          resolutionPool: [
            '{ad} meselenin özel kalacağı cevabını aldı.',
            'Divanın kararıyla {ad} meselenin özel kalacağı cevabını aldı.',
            'Köyün duyduğu hüküm belliydi: {ad} meselenin özel kalacağı cevabını aldı.',
          ],
          setsFlags: ['story.accord.closed'],
          clearsFlags: ['story.accord.table', 'story.accord.open'],
          goldDelta: 0,
          foodDelta: 0,
          woodDelta: 0,
          followUpId: 'story.accord.private',
          followUpDelayDays: 2.0,
        ),
      ],
    ),
    gravity: PetitionGravity.personal,
  ),
  _PetitionDef(
    (c) => false,
    0,
    const Petition(
      id: 'story.accord.shared',
      petitioner: '{ad} · {hane}',
      icon: '🤝',
      title: 'Eski Sofranın Son Yıl Sözü',
      bodyPool: [
        'İmparatorluğa hesap verme yılı yaklaşırken {storyLead} ilk ortak sofrayı hatırlattı. {storyPartner} ile köyün arkasında durmak için eski eşit söz kararını korumanı istiyor.',
        '{storyLead} ve {storyPartner}, yıllar önce verdiğin ortak söz hakkıyla kapında. Son hazırlık yılında bu birlikteliği destekleyecek misin?',
        'İlk sofrada bir araya getirdiğin iki hane şimdi köyün geleceğini konuşuyor. {storyLead} ve {storyPartner} eski uzlaşmayı son yılın desteğine çevirmek istiyor.',
      ],
      note: '5. yıl · hanelerin desteği',
      options: [
        PetitionOption(
          label: 'Ortak desteği güçlendir',
          detail:
              '8 altın; iki hanenin rızası güçlenir. Üç sadık haneyi kazanma hedefi ayrıca sürer.',
          resolutionPool: [
            '{ad} ortak destek için pay aldı; son yılın hane sözü kayda geçti.',
            'Divanın kararıyla {ad} ortak destek için pay aldı; son yılın hane sözü kayda geçti.',
            'Köyün duyduğu hüküm belliydi: {ad} ortak destek için pay aldı; son yılın hane sözü kayda geçti.',
          ],
          setsFlags: [
            'story.accord.table',
            'story.accord.done',
            'story.accord.backed',
            'assembly.tradition',
          ],
          clearsFlags: ['story.accord.closed'],
          goldDelta: -8,
          foodDelta: 0,
          woodDelta: 0,
        ),
        PetitionOption(
          label: 'Yerel anlaşmayla yetinelim',
          detail:
              'Kaynak harcanmaz; büyük ortaklık kurulmaz, bu hikâye kapanır.',
          resolutionPool: [
            '{ad} büyük ortaklık desteği alamadı; mesele yerel anlaşmayla kapandı.',
            'Divanın kararıyla {ad} büyük ortaklık desteği alamadı; mesele yerel anlaşmayla kapandı.',
            'Köyün duyduğu hüküm belliydi: {ad} büyük ortaklık desteği alamadı; mesele yerel anlaşmayla kapandı.',
          ],
          setsFlags: ['story.accord.done', 'story.accord.local'],
          clearsFlags: ['story.accord.table'],
          goldDelta: 0,
          foodDelta: 0,
          woodDelta: 0,
        ),
      ],
    ),
    gravity: PetitionGravity.personal,
  ),
  _PetitionDef(
    (c) => false,
    0,
    const Petition(
      id: 'story.accord.private',
      petitioner: '{ad} · {hane}',
      icon: '🤝',
      title: 'Ayrı Hanelerin Son Yıl Sözü',
      bodyPool: [
        'Haneleri kendi yollarına bırakmıştın. Son hazırlık yılında {storyLead} ve {storyPartner} köyün arkasında birlikte durmak için yeni bir uzlaşma istiyor.',
        '{storyLead} ayrı tuttuğun hane sözünü hatırlattı. {storyPartner} ile hesaplaşmadan önce birlikte hareket etmeyi teklif ediyor.',
        'İmparatorluğun gelişi yaklaşırken eski ayrılık yeniden kapına geldi. {storyLead} ve {storyPartner} son yıl için ortak destek sözü vermek istiyor.',
      ],
      note: '5. yıl · hanelerin desteği',
      options: [
        PetitionOption(
          label: 'Ortak desteği güçlendir',
          detail:
              '8 altın; iki hanenin rızası güçlenir. Üç sadık haneyi kazanma hedefi ayrıca sürer.',
          resolutionPool: [
            '{ad} ortak destek için pay aldı; son yılın hane sözü kayda geçti.',
            'Divanın kararıyla {ad} ortak destek için pay aldı; son yılın hane sözü kayda geçti.',
            'Köyün duyduğu hüküm belliydi: {ad} ortak destek için pay aldı; son yılın hane sözü kayda geçti.',
          ],
          setsFlags: [
            'story.accord.table',
            'story.accord.done',
            'story.accord.backed',
            'assembly.tradition',
          ],
          clearsFlags: ['story.accord.closed'],
          goldDelta: -8,
          foodDelta: 0,
          woodDelta: 0,
        ),
        PetitionOption(
          label: 'Yerel anlaşmayla yetinelim',
          detail:
              'Kaynak harcanmaz; büyük ortaklık kurulmaz, bu hikâye kapanır.',
          resolutionPool: [
            '{ad} büyük ortaklık desteği alamadı; mesele yerel anlaşmayla kapandı.',
            'Divanın kararıyla {ad} büyük ortaklık desteği alamadı; mesele yerel anlaşmayla kapandı.',
            'Köyün duyduğu hüküm belliydi: {ad} büyük ortaklık desteği alamadı; mesele yerel anlaşmayla kapandı.',
          ],
          setsFlags: ['story.accord.done', 'story.accord.local'],
          clearsFlags: ['story.accord.table'],
          goldDelta: 0,
          foodDelta: 0,
          woodDelta: 0,
        ),
      ],
    ),
    gravity: PetitionGravity.personal,
  ),
  _PetitionDef(
    (c) => false,
    0,
    const Petition(
      id: 'story.accord.loss',
      petitioner: '{ad} · {hane}',
      icon: '🤝',
      title: 'Yarım Kalan Söz',
      bodyPool: [
        '{storyLead} ile {storyPartner} için başlayan mesele değişti: {storyMissing} artık köyde değil. Eski sözü nasıl kapatacağız?',
        'İlk kararı verdiğin iki kişiden {storyMissing} artık burada değil. {storyLead} ve {storyPartner} için açılan sayfa bir kapanış bekliyor.',
        '{storyMissing} köyden eksildi; eski görüşme aynı kişilerle süremeyecek. {storyLead} ve {storyPartner} için verdiğin sözü hatıraya mı dönüştürelim?',
      ],
      note: 'Köyden eksilen yüz · hikâyenin kapanışı',
      options: [
        PetitionOption(
          label: 'Sözü hatıra olarak sakla',
          detail: 'Kaynak bedeli yok; anma yapılır ve hikâye kapanır.',
          resolutionPool: [
            'Eski söz köyün hatırasına alındı; yarım kalan mesele kapandı.',
            'Divanın kararıyla Eski söz köyün hatırasına alındı; yarım kalan mesele kapandı.',
            'Köyün duyduğu hüküm belliydi: Eski söz köyün hatırasına alındı; yarım kalan mesele kapandı.',
          ],
          setsFlags: ['story.accord.done', 'story.accord.remembered'],
          clearsFlags: ['story.accord.table'],
          goldDelta: 0,
          foodDelta: 0,
          woodDelta: 0,
          fx: PetitionFx.remembrance,
        ),
        PetitionOption(
          label: 'Sayfayı sessizce kapat',
          detail: 'Kaynak bedeli yok; tören yapılmadan hikâye kapanır.',
          resolutionPool: [
            'Yarım kalan mesele sessizce kapatıldı; eski karar güncede kaldı.',
            'Divanın kararıyla Yarım kalan mesele sessizce kapatıldı; eski karar güncede kaldı.',
            'Köyün duyduğu hüküm belliydi: Yarım kalan mesele sessizce kapatıldı; eski karar güncede kaldı.',
          ],
          setsFlags: ['story.accord.done', 'story.accord.closed'],
          clearsFlags: ['story.accord.table'],
          goldDelta: 0,
          foodDelta: 0,
          woodDelta: 0,
        ),
      ],
    ),
    gravity: PetitionGravity.personal,
  ),
];
