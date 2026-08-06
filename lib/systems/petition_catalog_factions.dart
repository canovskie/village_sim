part of 'petition_system.dart';

/// DİLEKÇE KATALOĞU — HİZİP · BÜYÜK KARARLAR · DIŞ KRİZLER (9 dilekçe).
///
/// Katalog tek dosyada 2856 satırdı; bölümler zaten `═` bantlarıyla
/// ayrılmıştı, o sınırlar dosya sınırı yapıldı. SIRA KORUNUR:
/// [_kPetitionDefs] bu listeleri eski sırayla yayar.
final List<_PetitionDef> _kFactionPetitions = [
    // ─── Hizip dilekçeleri — bir zümrenin kazancı, diğerinin kaybı ──────────

    // 💰 Pazar vergisi — Emekçiler tüccarlardan vergi ister (ambar fonu).
    _PetitionDef(
      (c) => c.adults >= 5,
      0.7,
      const Petition(
        id: 'marketTax',
        petitioner: 'Çiftçi sözcüsü',
        icon: '💰',
        title: 'Pazar Vergisi',
        tone: PetitionTone.neutral,
        estate: Estate.laborers,
        stakes: 'Vergi ambarı doldurur, tüccarı küstürür. Serbest pazar tersini yapar.',
        bodyPool: [
          '“Efendim, pazarda bir kile buğdayın parası benim elime bir avuç geliyor, '
              'tüccarın kesesine bir kese. Toprağı ben kazıyorum. Küçük bir pazar vergisi '
              'koy; kışın hepimiz o ortak ambardan yiyelim.”',
          '“{ad} benim, harmanı ben savuruyorum. Geçen hafta kendi buğdayımı pazardan '
              'iki katına geri satın almak zorunda kaldım. Böyle bir düzen olmaz. Vergiyi '
              'koy.”',
          '“Kimse tüccara düşman değil; malı o taşıyor, riski o alıyor. Ama kâr tek kapıda '
              'birikirse köy o kapıya muhtaç olur. Ufak bir pay al, ortak keseye koy. Zor '
              'gün gelince kimse kimseye yalvarmasın.”',
        ],
        options: [
          PetitionOption(
            label: 'Vergiyi koy',
            detail: 'Tüccardan pay alınır, ortak kese dolar. Tezgâh homurdanır.',
            resolutionPool: [
              '💰 Pazar vergisi kondu. Ortak kese doldu, tüccarlar tartıyı iki kez kontrol etti.',
              '💰 Vergi yürürlükte. {ad} ilk payı kendi elleriyle ambara taşıdı.',
            ],
            goldDelta: 6,
            estateMood: [(Estate.laborers, 0.12), (Estate.hearth, 0.05), (Estate.artisans, -0.15)],
          ),
          PetitionOption(
            label: 'Pazarı serbest bırak',
            detail: 'Vergi yok. Ticaret akar, harmandaki eller burulur.',
            resolutionPool: [
              '💰 Pazar serbest kaldı. Tüccarlar keseyi bağladı, çiftçiler başını çevirdi.',
              '💰 Vergi konmadı. {ad} o gün pazara hiç uğramadı.',
            ],
            estateMood: [(Estate.artisans, 0.12), (Estate.laborers, -0.09)],
          ),
        ],
      ),
    ),

    // 🌙 Kutsal gün — İnananlar dinlenme/ibadet günü ister; iş durur.
    _PetitionDef(
      (c) => c.population >= 6 &&
          (c.hasChurch || c.remembers('cult.active')),
      0.6,
      const Petition(
        id: 'holyDay',
        petitioner: 'İnananların sözcüsü',
        icon: '🌙',
        title: 'Kutsal Gün',
        tone: PetitionTone.solemn,
        estate: Estate.faithful,
        stakes: 'Haftada bir gün çark durur; durmazsa inananlar durur.',
        bodyPool: [
          '“Efendim, {ad} benim. Haftada bir gün isteriz: o gün ne örs sesi olsun ne '
              'orak. Sabah dua, öğlen sessizlik, akşam sofra. İnsan bir kez olsun durup '
              'nereye gittiğine baksın.”',
          '“Yedi gün çalışan insan sekizinci gün ne olduğunu unutur. Ben ekmeğe şükretmeyi '
              'unuttum; elimle koydum ağzıma, farkında bile değildim. Bir gün durursak '
              'hatırlarız. Bir gün istiyoruz.”',
          '“Emekçi bir gün kaybederiz diyor; doğru diyor. Biz de diyoruz ki bir gün '
              'durmazsak kaybedilecek bir şey kalmayacak. Kutsal günü ilan et, kaybı biz '
              'telafi ederiz.”',
        ],
        options: [
          PetitionOption(
            label: 'Kutsal günü ilan et',
            detail: 'Haftada bir gün çark durur. Ruhlar dinlenir, tarla bekler.',
            resolutionPool: [
              '🌙 Kutsal gün ilan edildi. O sabah köyde tek bir çekiç sesi duyulmadı.',
              '🌙 Haftanın bir günü işe kapandı. {ad} sabah duasını meydanda açtı.',
            ],
            moraleAmount: 0.05,
            moraleDays: 6,
            setsFlags: ['holyDay.active'],
            estateMood: [(Estate.faithful, 0.14), (Estate.hearth, 0.05), (Estate.laborers, -0.08), (Estate.artisans, -0.08)],
          ),
          PetitionOption(
            label: 'İş başına',
            detail: 'Gün kaybı olmaz. Örs de çalışır orak da; inananlar susar.',
            resolutionPool: [
              '🌙 Kutsal gün reddedildi. {ad} duasını tezgâhın başında okudu.',
              '🌙 İş başına dendi. İnananlar itiraz etmedi, sadece bir daha istemedi.',
            ],
            estateMood: [(Estate.faithful, -0.12), (Estate.laborers, 0.06), (Estate.artisans, 0.06)],
          ),
        ],
      ),
    ),

    // 🧓 Yaşlılar meclisi mi, gençlerin sesi mi — Ocak vs genç emek/zanaat.
    _PetitionDef(
      (c) => c.population >= 6 && c.adults >= 4,
      0.6,
      const Petition(
        id: 'eldersCouncil',
        petitioner: 'Köyün ihtiyarları',
        icon: '🧓',
        title: 'Kimin Sözü Geçer?',
        tone: PetitionTone.neutral,
        estate: Estate.hearth,
        stakes: 'Tecrübe mi konuşsun, atılganlık mı? Biri seçilir, öbürü küser.',
        bodyPool: [
          '“Efendim, geçen ay değirmenin yerini bize sormadan seçtiler. İki yıl önce aynı '
              'yeri sel almıştı; kimse bilmiyordu, biz biliyorduk. Bir yaşlılar meclisi '
              'kur, kararlar önce bizim kapıdan geçsin.”',
          '“{ad} benim, seksen kışım oldu. Gençlerin hızına sözüm yok, hızlı olsunlar; ama '
              'hız hatayı da hızlandırır. Otursunlar bir dinlesinler, sonra koşsunlar. '
              'Dinleyecek bir yer olsun yeter.”',
          '“Kararı kim veriyor, kimse bilmiyor. Gençler kendi aralarında konuşup işe '
              'başlıyor, biz duvar dibinden seyrediyoruz. Ya bizi masaya al, ya açıkça '
              'söyle: bu köyün sözü artık bizim değil.”',
        ],
        options: [
          PetitionOption(
            label: 'Yaşlılar meclisi kurulsun',
            detail: 'Kararlar önce ihtiyarların kapısından geçer. Gençler geride bekler.',
            resolutionPool: [
              '🧓 Yaşlılar meclisi kuruldu. İlk kararı değirmenin yerini değiştirmek oldu.',
              '🧓 Söz ihtiyarlara verildi. {ad} meclisin başına oturdu, gençler ayakta kaldı.',
            ],
            setsFlags: ['council.elders'],
            estateMood: [(Estate.hearth, 0.14), (Estate.faithful, 0.04), (Estate.laborers, -0.06), (Estate.artisans, -0.06)],
          ),
          PetitionOption(
            label: 'Gençlerin sesi duyulsun',
            detail: 'Karar genç ellerde. İhtiyarlar duvar dibinden seyreder.',
            resolutionPool: [
              '🧒 Söz gençlere verildi. Aynı hafta iki yeni iş başladı, ikisi de aceleye geldi.',
              '🧒 Gençler masaya oturdu. {ad} kapıdan bir kez baktı, sonra evine döndü.',
            ],
            setsFlags: ['council.youth'],
            estateMood: [(Estate.laborers, 0.08), (Estate.artisans, 0.08), (Estate.hearth, -0.12)],
          ),
        ],
      ),
    ),

    // ─── BÜYÜK KARARLAR — DÖRT zümreyi birden oynatan ağır tercihler ──────────

    // 🛣️ Ticaret yolu — dünyaya açıl mı, kendine mi yet?
    _PetitionDef(
      (c) => c.population >= 8 &&
          !c.remembers('road.open') &&
          !c.remembers('road.closed'),
      0.6,
      const Petition(
        id: 'bigDecisionRoad',
        petitioner: 'Köy meclisi',
        icon: '🛣️',
        title: 'Dünyaya Açılalım mı?',
        tone: PetitionTone.neutral,
        stakes: 'Yol kervan getirir, kervan yabancı âdet. Kapalı köy huzurlu ama dar.',
        bodyPool: [
          '“Efendim, dağın ardındaki geçit iki günlük iş, o kadar. Açarsak kervanlar '
              'buradan geçer; ipek de gelir, haber de. Ama yaşlılar yabancı yol yabancı '
              'âdet getirir diyor. Meclis ikiye bölündü, karar sende.”',
          '“Bu köyün yolu bir katır patikası, araba bile geçmiyor. Dışarıdan gelenler bize '
              'kaç para verdiklerini söylemiyor, çünkü karşılaştıracak kimsemiz yok. Yolu '
              'aç da dünyayı görelim. Ya da kapat, dünya da bizi görmesin.”',
          '“{köy} kırk yıldır kendi ekmeğini yer, kendi suyunu içer. Kimi bunu gurur '
              'sayıyor, kimi hapis. Şunu bilerek karar ver: yolu bir açarsan geri '
              'kapatamazsın.”',
        ],
        options: [
          PetitionOption(
            label: 'Ticaret yolunu aç',
            detail: 'Geçit açılır. Kervan, kazanç, uzak haber; bir de yabancı âdet.',
            resolutionPool: [
              '🛣️ Geçit açıldı. İlk gece dağ yolunda üç meşale göründü.',
              '🛣️ Yol açıldı. {köy} kapısını dünyaya araladı; yaşlılar kendi kapılarını iki kez sürgüledi.',
            ],
            goldDelta: -4,
            setsFlags: ['road.open'],
            followUpId: 'roadCaravan',
            followUpDelayDays: 3.0,
            estateMood: [(Estate.artisans, 0.16), (Estate.laborers, 0.06), (Estate.faithful, -0.10), (Estate.hearth, -0.10)],
          ),
          PetitionOption(
            label: 'Köy kendine yetsin',
            detail: 'Geçit kapalı. Gelenek yerinde durur, pazar durgun kalır.',
            resolutionPool: [
              '🏡 Yol açılmadı. {köy} kendi ekmeğini yemeye devam ediyor.',
              '🏡 Kapılar kapalı kaldı. Tüccarlar mallarını yine katıra yükledi.',
            ],
            setsFlags: ['road.closed'],
            estateMood: [(Estate.hearth, 0.12), (Estate.faithful, 0.10), (Estate.artisans, -0.12), (Estate.laborers, -0.05)],
          ),
        ],
      ),
    ),

    // 🏗️ Ortak emek nereye? Değirmen mi, sunak mı?
    _PetitionDef(
      (c) => c.population >= 7 && c.adults >= 4,
      0.5,
      const Petition(
        id: 'bigDecisionProject',
        petitioner: 'Köyün ustabaşısı',
        icon: '🏗️',
        title: 'Ortak Emek Nereye Aksın?',
        tone: PetitionTone.neutral,
        stakes: 'Değirmen un verir, sunak anlam. Bu mevsim ikisi birden olmaz.',
        bodyPool: [
          '“Efendim, elimde otuz gün ve yirmi çift el var, fazlası yok. Emekçiler değirmen '
              'istiyor: un çabuk olur, herkes doyar. İnananlar sunak istiyor: köyün bir '
              'kalbi olsun diyorlar. İkisini kaldıramam. Söyle, ilk kazığı nereye çakayım?”',
          '“{ad} benim, ustabaşı. Taşlar hazır, kalasları kestik; ama planı iki türlü '
              'çizdim, ikisi de duvarımda asılı. Birini yırtacağım. Hangisini?”',
          '“Değirmenin çarkı dönerse kışın kimse aç kalmaz, doğru. Ama geçen yıl '
              'gömdüğümüz çocuk için diz çökecek bir taş bile bulamadık, o da doğru. Birini '
              'seç; öbürünü seneye bırakalım.”',
        ],
        options: [
          PetitionOption(
            label: 'Değirmen kuralım',
            detail: 'Çark döner, un artar. Sunağın taşları bir yıl daha bekler.',
            resolutionPool: [
              '🏗️ Değirmenin ilk kazığı çakıldı. Çark bu {mevsim} dönmeye başlayacak.',
              '🏗️ Değirmen seçildi. {ad} sunağın planını duvardan indirdi ama yırtmadı.',
            ],
            foodDelta: 6,
            estateMood: [(Estate.laborers, 0.14), (Estate.artisans, 0.10), (Estate.faithful, -0.10), (Estate.hearth, -0.06)],
          ),
          PetitionOption(
            label: 'Sunak yükseltelim',
            detail: 'Taş üstüne taş konur. Un bekler, köyün bir kalbi olur.',
            resolutionPool: [
              '🕯️ Sunak yükseldi. İlk mumu bir çocuk yaktı, kimse ona söylememişti.',
              '🕯️ Sunak seçildi. {ad} değirmenin planını katlayıp sandığa koydu.',
            ],
            moraleAmount: 0.06,
            moraleDays: 4,
            fx: PetitionFx.cult,
            estateMood: [(Estate.faithful, 0.14), (Estate.hearth, 0.10), (Estate.laborers, -0.10), (Estate.artisans, -0.06)],
          ),
        ],
      ),
    ),

    // 🐪 ZİNCİR: ticaret yolu açıldıysa bir kervan gelir.
    _PetitionDef(
      (c) => false,
      0.0,
      const Petition(
        id: 'roadCaravan',
        petitioner: 'Tozlu bir kervan',
        icon: '🐪',
        title: 'Yoldan Bir Kervan Geldi',
        tone: PetitionTone.warm,
        estate: Estate.artisans,
        note: '↩ Yolun ilk kervanı',
        stakes: 'Bir gecelik erzak; karşılığında dolu bir kese ve uzak haberler.',
        bodyPool: [
          '“Efendim, yirmi gün yol yaptık; develerin ayağı su topladı. Yükümüzde ipek var, '
              'tuz var, bir de karşı kıyının haberleri. Bir gece izin ver: meydanda pazar '
              'kuralım, sabah yola çıkalım. Karnımızı doyurun, keseyi biz dolduralım.”',
          '“Yeni açtığın yolu ilk biz gördük, tozunu ilk biz yuttuk. Bir gecelik konak '
              'isteriz; karşılığında köyün pazarını bir günde doldururuz. Reddedersen '
              'darılmayız, ama bir daha bu yoldan geçmeyiz.”',
          '“Dört köy geçtik, hiçbiri kapısını açmadı; kervan kapıda bekletilir mi? Sizin '
              'çeşmenin suyu tatlıymış diye duyduk. Bir gece ver bize, sabaha kadar '
              'meydana mal sereriz.”',
        ],
        options: [
          PetitionOption(
            label: 'Kervanı ağırla',
            detail: 'Bir gecelik erzak gider. Meydanda pazar kurulur, kese dolar.',
            resolutionPool: [
              '🐪 Kervan ağırlandı. Meydan sabaha kadar ipek ve tuz koktu, kese doldu.',
              '🐪 Develer çeşmeye bağlandı. {köy} o gece uzak kıyıların haberini dinledi.',
            ],
            foodDelta: -5,
            goldDelta: 12,
            moraleAmount: 0.08,
            moraleDays: 3,
            fx: PetitionFx.festival,
            estateMood: [(Estate.artisans, 0.12), (Estate.laborers, 0.05), (Estate.hearth, 0.03)],
          ),
          PetitionOption(
            label: 'Geçip gitsinler',
            detail: 'Kapı kapalı. Kervan durmaz, kese açılmaz.',
            resolutionPool: [
              '🐪 Kervan durmadan geçti. Tozu çökene kadar çocuklar arkasından baktı.',
              '🐪 Ağırlanmadılar. Yollarına devam ettiler; bir daha bu yoldan geçmezler.',
            ],
            moraleAmount: -0.02,
            moraleDays: 1,
            estateMood: [(Estate.artisans, -0.08)],
          ),
        ],
      ),
    ),

    // ─── Dış krizler ─────────────────────────────────────────────────────────

    // 🌵 Kuraklık — su kıt; tarla mı, hane mi öncelikli?
    _PetitionDef(
      (c) => c.population >= 6 && c.food >= 10,
      0.5,
      const Petition(
        id: 'drought',
        petitioner: 'Kuyubaşındaki kalabalık',
        icon: '🌵',
        title: 'Kuraklık',
        tone: PetitionTone.ominous,
        estate: Estate.laborers,
        stakes: 'Su tarlaya giderse haneler susar; haneye giderse ekin kavrulur.',
        bodyPool: [
          '“Efendim, kuyunun ipini iki kulaç uzattık, kova hâlâ çamur getiriyor. Kalan '
              'suyu ya tarlaya vereceğiz ya evlere. İkisine birden yetmez, ölçtük. Sen '
              'söyle: kim susasın?”',
          '“Kadınlar sabahtan beri kuyubaşında sırada, kova başına bir ölçek düşüyor. '
              'Tarladakiler aşağıda bekliyor, onların da hakkı var. Kavga çıkacak; sen '
              'karar vermezsen ben ayıramam.”',
          '“{ad} benim, kuyunun başındayım. Dün gece biri gizlice iki kova çekmiş. Kim '
              'olduğunu biliyorum ama söylemeyeceğim, çünkü çocuğu susuz. Bu iş böyle '
              'gitmez, bir düzen koy.”',
        ],
        options: [
          PetitionOption(
            label: 'Tarlalara öncelik',
            detail: 'Su tarlaya iner. Ekin kurtulur, kuyubaşında sıra uzar.',
            resolutionPool: [
              '🌾 Su tarlaya verildi. Ekin kurtuldu; haneler kovayı yarım doldurdu.',
              '🌾 Öncelik tarlanın oldu. {ad} kuyubaşında sırayı kendi tuttu, kimseye fazla vermedi.',
            ],
            foodDelta: 4,
            estateMood: [(Estate.laborers, 0.10), (Estate.hearth, -0.07)],
          ),
          PetitionOption(
            label: 'Hanelere eşit pay',
            detail: 'Su evlere bölünür. Kimse susuz kalmaz, tarla kavrulur.',
            resolutionPool: [
              '🏡 Su hanelere eşit bölündü. Tarlalarda toprak çatladı, kimse oraya bakmadı.',
              '🏡 Öncelik hanelerin oldu. {ad} son kovayı bir çocuğa verdi, tarlaya hiç bakmadı.',
            ],
            foodDelta: -6,
            moraleAmount: -0.02,
            moraleDays: 2,
            fx: PetitionFx.cropBlight,
            estateMood: [(Estate.hearth, 0.08), (Estate.laborers, -0.09)],
          ),
        ],
      ),
    ),

    // 🧳 Göçmen kafilesi — yorgun yabancılar kapıda; kabul mü, geçiş mi?
    _PetitionDef(
      (c) => c.population >= 6,
      0.5,
      const Petition(
        id: 'migrantCaravan',
        petitioner: 'Yorgun gezginler',
        icon: '🧳',
        title: 'Kapıda Bir Kafile',
        tone: PetitionTone.neutral,
        estate: Estate.artisans,
        stakes: 'Sofraya on boğaz eklenir; ya da kapıda on sırt döner.',
        bodyPool: [
          '“Efendim, on bir kişiyiz, dördü çocuk. Köyümüz yandı; geriye bir eşek ve iki '
              'torba un kaldı. Dilenmiyoruz, iş isteriz: taş taşırız, harman kaldırırız. '
              'Bir kış geçirelim, bahara ne dersen yaparız.”',
          '“Kapınızın önünde üç gündür bekliyoruz. Kimse kovmadı, kimse de içeri çağırmadı. '
              'Çocuklar çeşmenizden su içiyor, utanıyoruz. Bir söz söyle: kalalım mı, '
              'gidelim mi?”',
          '“Bizde bir marangoz var, bir de ebe. {köy} kapısını açarsa karşılığını görür. '
              'Açmazsa hakkını helal etsin, yolumuza devam ederiz.”',
        ],
        options: [
          PetitionOption(
            label: 'Kapıyı aç, kabul et',
            detail: 'Sofraya boğaz eklenir. Yeni eller, yeni yüzler, tedirgin bir ocak.',
            resolutionPool: [
              '🧳 Kafile içeri alındı. Ebe daha ilk gece bir doğuma yetişti.',
              '🧳 Kapı açıldı. Yaşlılar pencereden baktı, kimse selam vermedi.',
            ],
            foodDelta: -4,
            setsFlags: ['migrants.welcomed'],
            estateMood: [(Estate.artisans, 0.12), (Estate.hearth, -0.10)],
          ),
          PetitionOption(
            label: 'Geçip gitsinler',
            detail: 'Kapı kapalı. Kafile yoluna devam eder, köy düzenini korur.',
            resolutionPool: [
              '🚪 Kafile yola devam etti. Çeşmenin başında dört çocuk ayakkabısı unutulmuştu.',
              '🚪 Kapı açılmadı. {köy} kendi düzenini korudu, kimse bir şey konuşmadı.',
            ],
            estateMood: [(Estate.hearth, 0.08), (Estate.artisans, -0.08)],
          ),
        ],
      ),
    ),

    // 🏴 Komşu köy elçisi — ticaret anlaşması mı, kendi yolumuz mu?
    _PetitionDef(
      (c) => c.population >= 8 && c.gold >= 4,
      0.45,
      const Petition(
        id: 'neighborEnvoy',
        petitioner: 'Komşu köyün elçisi',
        icon: '🏴',
        title: 'Komşudan Elçi',
        tone: PetitionTone.neutral,
        estate: Estate.artisans,
        stakes: 'Anlaşma keseyi doldurur; mühür yabancıyla kurulan ilk bağ olur.',
        bodyPool: [
          '“Selam getirdim, bir de teklif. Bizim un fazlamız var, sizin demir. Yılda iki '
              'kez pazar kuralım, tartıyı ortak tutalım. Şu berata bir mühür bas, gerisi '
              'kendiliğinden yürür.”',
          '“Efendim, iki köyün arasındaki dere hep kavga konusu oldu; babalarımız orada '
              'birbirine sopa çekti. Ben o kavgayı bitirmeye geldim. Ticaret bağlarsak dere '
              'sınır olmaktan çıkar, yol olur.”',
          '“Elimde bir kese var, açmadan masaya bırakırım: niyetimiz temiz. '
              'İnananlarınızın tedirginliğini duydum, haklılar da; yabancı âdet bulaşıcıdır. '
              'Ama açlık daha bulaşıcı. Kararı sen ver.”',
        ],
        options: [
          PetitionOption(
            label: 'Beratı mühürle',
            detail: 'Mühür basılır. Pazar açılır, kese dolar, inananlar burulur.',
            resolutionPool: [
              '🏴 Berat mühürlendi. İlk pazar dere kenarında kuruldu, iki köy tartıyı birlikte tuttu.',
              '🏴 Elçi keseyi masada bıraktı. {köy} ilk kez dışarıdan kazandı.',
            ],
            goldDelta: 8,
            setsFlags: ['pact.neighbor'],
            estateMood: [(Estate.artisans, 0.12), (Estate.faithful, -0.06)],
          ),
          PetitionOption(
            label: 'Kendi yolumuz',
            detail: 'Berat mühürsüz kalır. Köy ruhunu korur, tezgâh fırsatı kaçırır.',
            resolutionPool: [
              '🕯️ Elçi geri çevrildi. Beratı katlayıp koynuna koydu, tek kelime etmedi.',
              '🕯️ Anlaşma olmadı. Dere yine sınır, yine kavga konusu.',
            ],
            estateMood: [(Estate.faithful, 0.08), (Estate.hearth, 0.05), (Estate.artisans, -0.10)],
          ),
        ],
      ),
    ),

];
