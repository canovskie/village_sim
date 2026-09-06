part of '../petition_system.dart';

/// OCAK / KÜÇÜK KÖY GÜNDEMİ
///
/// Bunlar devlet meselesi değil; aynı ateşin çevresinde yaşayan birkaç insanın
/// gündelik sürtüşmeleri. İlk kademede yalnız bu paket açıktır. Köy büyüyünce
/// tamamen kaybolmazlar fakat [petitionGravityWeight] onları ağır gündemin
/// gerisine iter.
final List<_PetitionDef> _kPersonalPetitions = [
  _PetitionDef(
    (c) =>
        c.unwedAdultMen > 0 &&
        !c.remembers('personalStyle.free') &&
        !c.remembers('personalStyle.traditional'),
    1.35,
    const Petition(
      id: PetitionIds.personalStyle,
      petitioner: '{ad} · {meslek}',
      icon: '🧵',
      title: 'Kendi Yolum',
      stakes: 'Bir insanın kendi hayatı ile köyün alışkanlığı karşı karşıya.',
      tone: PetitionTone.solemn,
      authorKind: PetitionAuthorKind.unwedAdultMan,
      bodyPool: [
        'Evlenmek istemiyorum. Köyde kendi yolumu çizmek ve dilediğim kıyafeti giymek istiyorum.',
        'Benden beklenen hayat bana göre değil. Kendi hâlimle yaşamak, istediğim kıyafeti giymek istiyorum.',
      ],
      options: [
        PetitionOption(
          label: 'Kendi kararını versin',
          detail: 'Hayatını ve kıyafetini özgürce seçsin.',
          resolutionPool: [
            '🧵 {ad} kendi yolunu seçti. Ertesi sabah meydana kendi diktiği kıyafetle çıktı.',
            '🧵 Divan karışmadı. {ad} bugün kendini saklamadan köyün içinden geçti.',
          ],
          annalPool: [
            '{ad-in} hayatına ve kıyafetine karışılmamasına hükmedildi.',
            '{ad} kendi yolunu seçme hakkını aldı.',
          ],
          moraleAmount: 0.02,
          moraleDays: 1.5,
          setsFlags: ['personalStyle.free'],
          actorEffect: PetitionActorEffect.flowingOutfit,
        ),
        PetitionOption(
          label: 'Köy geleneği sürsün',
          detail: 'Köyün beklentilerine uyması istensin.',
          resolutionPool: [
            '🧥 {ad-in} önüne köyün uygun gördüğü kıyafet bırakıldı. Söz söylemeden aldı.',
            '🧥 Divan geleneği seçti. {ad} meydana köyün biçtiği kıyafetle döndü.',
          ],
          annalPool: [
            '{ad-in} köy geleneğine uygun yaşamasına hükmedildi.',
            'Divan {ad-in} talebini reddetti; gelenek sürdü.',
          ],
          setsFlags: ['personalStyle.traditional'],
          actorEffect: PetitionActorEffect.traditionalOutfit,
        ),
      ],
    ),
    gravity: PetitionGravity.personal,
  ),
  _PetitionDef(
    (c) => c.population >= 4,
    1.05,
    const Petition(
      id: PetitionIds.ovenTurn,
      petitioner: 'Ocak komşuları',
      icon: '🥖',
      title: 'Fırın Sırası',
      stakes: 'İki tepsi, tek sıcak taş.',
      bodyPool: [
        'İki hane sabah ekmeğini aynı anda pişirmek istiyor. Biri hamurun önce mayalandığını, öteki çocukların aç beklediğini söylüyor.',
        'Ortak fırının önünde yine sıra kavgası çıktı. Kimin önce gireceğini Divan söylesin diyorlar.',
      ],
      options: [
        PetitionOption(
          label: 'Sırayı dönüşümlü tut',
          detail: 'Her sabah başka hane önce girsin.',
          resolutionPool: [
            '🥖 Fırın sırası günlere bölündü. Kapıdaki tartışma dindi.',
          ],
          annalPool: ['Ortak fırın için dönüşümlü sıra kondu.'],
          moraleAmount: 0.01,
          moraleDays: 1.0,
        ),
        PetitionOption(
          label: 'Erken gelen girsin',
          detail: 'Fırının başına ilk varan taşı kullansın.',
          resolutionPool: [
            '🌅 Fırın ilk gelene bırakıldı. O günden sonra köy biraz daha erken uyanmaya başladı.',
          ],
          annalPool: ['Ortak fırında erken gelenin önceliği kabul edildi.'],
        ),
      ],
    ),
    gravity: PetitionGravity.personal,
  ),
  _PetitionDef(
    (c) => c.population >= 3,
    1.0,
    const Petition(
      id: PetitionIds.hearthSeat,
      petitioner: 'Ocak başındakiler',
      icon: '🔥',
      title: 'Ateşin Yanındaki Yer',
      stakes: 'En sıcak taş her akşam bir kişiye yetiyor.',
      bodyPool: [
        'Yaşlılar ateşe en yakın yerin kendilerine ayrılmasını istiyor. İşten dönenler ise en çok üşüyenin oturması gerektiğini söylüyor.',
        'Ocak başındaki sıcak yer yüzünden her akşam aynı homurtu çıkıyor. Bir usul koymamızı istediler.',
      ],
      options: [
        PetitionOption(
          label: 'Yaşlılara ayır',
          detail: 'Ateşin yanı köyün yaşlılarının olsun.',
          resolutionPool: ['🔥 En sıcak taş yaşlılara ayrıldı.'],
          annalPool: ['Ocak başındaki sıcak yer yaşlılara ayrıldı.'],
          moraleAmount: 0.01,
          moraleDays: 0.8,
        ),
        PetitionOption(
          label: 'En çok üşüyen otursun',
          detail: 'Yer yaşa değil, o akşamki ihtiyaca göre verilsin.',
          resolutionPool: [
            '🔥 Ocak başında sabit yer kalmadı; üşüyen öne geçti.',
          ],
          annalPool: [
            'Ateşe en yakın yerin en çok üşüyene verilmesi kararlaştırıldı.',
          ],
        ),
      ],
    ),
    gravity: PetitionGravity.personal,
  ),
  _PetitionDef(
    (c) => c.population >= 4,
    0.95,
    const Petition(
      id: PetitionIds.wellBucket,
      petitioner: 'Kuyu komşuları',
      icon: '🪣',
      title: 'Ortak Kova',
      stakes: 'Kovanın sapı gevşedi; kimse kendisinin kırdığını kabul etmiyor.',
      bodyPool: [
        'Kuyunun tek kovası yine çatlamış. Haneler yenisini ortak ambardan mı yapalım, herkes kendi kovasını mı getirsin diye soruyor.',
        'Ortak kova suyun içinde kaldı. Bir yenisi için ambardan odun istiyorlar; bazıları da herkes kendi yükünü taşısın diyor.',
      ],
      options: [
        PetitionOption(
          label: 'Yeni ortak kova yap',
          detail: 'Ambardan odun ver; kuyu herkesin kalsın.',
          resolutionPool: ['🪣 Kuyunun yanına sağlam bir ortak kova asıldı.'],
          annalPool: ['Ortak kuyu için ambardan yeni kova yapıldı.'],
          woodDelta: -2,
          moraleAmount: 0.01,
          moraleDays: 1.0,
        ),
        PetitionOption(
          label: 'Herkes kovasını getirsin',
          detail: 'Ortak ambar harcanmasın.',
          resolutionPool: [
            '🪣 Kuyunun çevresi ayrı ayrı hane kovalarıyla doldu.',
          ],
          annalPool: [
            'Kuyuda ortak kova kaldırıldı; her hane kendi kovasını getirdi.',
          ],
        ),
      ],
    ),
    gravity: PetitionGravity.personal,
  ),
  _PetitionDef(
    (c) => c.herdSize > 0,
    0.85,
    const Petition(
      id: PetitionIds.animalBell,
      petitioner: 'Hayvan bakanlar',
      icon: '🔔',
      title: 'Çanın Sesi',
      stakes: 'Hayvan kaybolmuyor; fakat çan bütün gece susmuyor.',
      bodyPool: [
        'Sürüye takılan çan hayvanları bulmayı kolaylaştırıyor. Yakın evdekiler ise geceleri sesten uyuyamadıklarını söylüyor.',
        'Çoban çanı çıkarmak istemiyor; ocak komşuları her gece aynı tınıyı dinlemekten bıkmış.',
      ],
      options: [
        PetitionOption(
          label: 'Çan sürüde kalsın',
          detail: 'Hayvanı bulmak sessizlikten önemli.',
          resolutionPool: ['🔔 Çan sürüde kaldı; sesi köy gecelerine karıştı.'],
          annalPool: ['Sürü çanının kullanılmasına devam edildi.'],
        ),
        PetitionOption(
          label: 'Gece çıkarılsın',
          detail: 'Gündüz takılsın, ağılda susturulsun.',
          resolutionPool: ['🌙 Çan gün batınca çıkarılmaya başlandı.'],
          annalPool: ['Sürü çanının geceleri çıkarılması kararlaştırıldı.'],
          moraleAmount: 0.01,
          moraleDays: 0.8,
        ),
      ],
    ),
    gravity: PetitionGravity.personal,
  ),
  _PetitionDef(
    (c) => c.population >= 5,
    0.9,
    const Petition(
      id: PetitionIds.quietEvening,
      petitioner: 'Ocak çevresindeki haneler',
      icon: '🎶',
      title: 'Akşam Türküsü',
      stakes: 'Birinin neşesi, ötekinin uykusu.',
      tone: PetitionTone.warm,
      bodyPool: [
        'Gençler iş bitince ocak başında türkü söylemek istiyor. Erken kalkanlar sesin gün batınca kesilmesini istiyor.',
        'Akşamları ocak başı şenleniyor ama yakın evlerde uyku kalmıyor. Türkünün saatini Divan belirlesin dediler.',
      ],
      options: [
        PetitionOption(
          label: 'Bir saat türkü serbest',
          detail: 'Gün batımından sonra kısa süre söylensin.',
          resolutionPool: ['🎶 Ocak başı bir saat şenlendi, sonra köy sustu.'],
          annalPool: [
            'Akşam türküsüne gün batımından sonra bir saat izin verildi.',
          ],
          moraleAmount: 0.02,
          moraleDays: 1.0,
        ),
        PetitionOption(
          label: 'Gece sessiz olsun',
          detail: 'Türkü gündüz söylensin; ocak başı erken dağılsın.',
          resolutionPool: ['🌙 Gün batınca ocak başı sessizleşti.'],
          annalPool: ['Köyde gün batımından sonra sessizlik istendi.'],
        ),
      ],
    ),
    gravity: PetitionGravity.personal,
  ),
];
