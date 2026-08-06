part of 'petition_system.dart';

/// DİLEKÇE KATALOĞU — KÜSKÜNLÜK + KİMLİK ÖDÜLÜ (10 dilekçe).
///
/// Katalog tek dosyada 2856 satırdı; bölümler zaten `═` bantlarıyla
/// ayrılmıştı, o sınırlar dosya sınırı yapıldı. SIRA KORUNUR:
/// [_kPetitionDefs] bu listeleri eski sırayla yayar.
final List<_PetitionDef> _kEstatePetitions = [
    // ════════════════════════════════════════════════════════════════════════
    // KÜSKÜNLÜK DİLEKÇELERİ — bir zümre sullen eşiği altına düşünce ısrarla
    // gündeme gelir (canFire = aggrievedEstate + roll ağırlık boost). Cozy:
    // gidermek küçük bir jest, savsaklamak yalnızca o zümreyi biraz daha küstürür.
    // ════════════════════════════════════════════════════════════════════════

    // 🌫️ Bir köylü çağrısının peşinden gitmek ister — mesleği gönlüne uymuyor.
    // Yazar sahnede o kırgın köylüdür (_pickPetitionAuthor özel-durumu).
    _PetitionDef(
      (c) => c.hasResentful && c.population >= 4,
      1.1,
      const Petition(
        id: 'professionCalling',
        petitioner: '{ad}, gönlü başka işte',
        icon: '🌫️',
        title: '{ad} Başka Bir İşe Gitmek İstiyor',
        tone: PetitionTone.solemn,
        note: '↩ {ad} aylardır işine küs',
        stakes: 'İzin verirsen bir el eksilir; tutarsan {ad} kalır ama gönlü kalmaz.',
        bodyPool: [
          '“{meslek} derler bana, doğduğumdan beri öyle çağırırlar. Sabahları '
              'ellerime bakıyorum ve bu ellerin başka bir işi olduğunu biliyorum. '
              'Babamın mesleğiydi, bana kaldı; ben seçmedim. Bir kez olsun kendi '
              'seçtiğim işin ardına düşeyim.”',
          '“Efendim, sözü uzatmayacağım. On yıldır aynı yolu yürüyorum, aynı avluya '
              'giriyorum, aynı taşa basıyorum. Geceleri başka bir işi düşünüyorum, '
              'gündüz elimdekini düşürüyorum. İzin ver de peşinden gideyim.”',
          '“Anam öldüğü gün bana bu işi bıraktı, ben de tutayım dedim. Tuttum da, '
              'on beş yıl tuttum. Ama her akşam ayaklarım beni başka bir kapıya '
              'götürüyor; {köy} bunu benden iyi bilir. Bırak da o kapıyı çalayım.”',
        ],
        options: [
          PetitionOption(
            label: 'Peşinden gitsin',
            detail: '{ad} mesleğini bırakır; içi rahatlar, eski iş bir süre sahipsiz kalır.',
            resolutionPool: [
              '🌫️ {ad} takımını bıraktı. Yeni işine ilk sabahı gülerek başladı.',
              '🌫️ {ad} eski mesleğine veda etti. Akşam ateşinde ilk kez sesli güldüğünü söylüyorlar.',
            ],
            moraleAmount: 0.04,
            moraleDays: 2,
            fx: PetitionFx.callingGranted,
            estateMood: [(Estate.hearth, 0.10), (Estate.artisans, -0.05)],
          ),
          PetitionOption(
            label: 'Mesleğinde kalsın',
            detail: 'Düzen bozulmaz. {ad} işinin başına döner, gönlü orada değildir.',
            resolutionPool: [
              '🌫️ {ad} işinin başına döndü. O akşam kimseyle konuşmadı.',
              '🌫️ {ad-e} kal dendi. Kaldı; ama ocakta kimse ona bir şey soramadı.',
            ],
            moraleAmount: -0.05,
            moraleDays: 2,
            estateMood: [(Estate.hearth, -0.10), (Estate.artisans, 0.04)],
          ),
        ],
      ),
    ),

    // 🩸 Kan davası — köy yaşlıları iki aileyi barıştırman için yalvarır.
    _PetitionDef(
      (c) => c.hasFeud,
      1.4,
      const Petition(
        id: 'feudReconcile',
        petitioner: 'Köyün yaşlıları',
        icon: '🩸',
        title: 'Kan Davasını Bitir',
        tone: PetitionTone.ominous,
        note: '↩ İki hane kan kustu',
        stakes: 'Sulh bir kese altına mal olur; sessizlik bir mezara.',
        bodyPool: [
          '“Biz bu köyde iki cenaze kaldırdık, üçüncüsünün kefeni şimdiden hazır. '
              'İki hane birbirinin gölgesine tahammül edemiyor, çocuklar bile '
              'birbirine taş atıyor. Sen bir söz söyle, biz o sözü sofraya taşıyalım.”',
          '“Efendim, biz yaşlıyız, çok kan gördük; ama bu köyde böylesini görmedik. '
              'Değirmen yolunda iki adam birbirine bıçak çekti, aralarına girecek '
              'kimse çıkmadı. Diyet öderiz, elini öperiz, ne dersen yaparız. Yeter ki bitsin.”',
          '“Geçen hafta iki evin ortasındaki çeşmeden su alan olmadı; kimse öbürüne '
              'sırtını dönmeye cesaret edemiyor. Biz bu husumeti bir mezarla değil, '
              'bir sofrayla kapatmak isteriz. Sözü senden bekliyoruz.”',
        ],
        options: [
          PetitionOption(
            label: 'Sulh dayat, diyet öde',
            detail: 'Diyet keseden çıkar. İki hane aynı sofraya oturur, husumet kapanır.',
            resolutionPool: [
              '🕊️ Diyet ödendi. İki hane aynı ekmeği böldü, kan davası bitti.',
              '🕊️ Sulh kuruldu. İki hanenin büyükleri meydanda el sıkıştı, {köy} nefes aldı.',
            ],
            goldDelta: -6, // diyet / barış bedeli
            moraleAmount: 0.10,
            moraleDays: 4,
            fx: PetitionFx.feudPeace,
            estateMood: [(Estate.faithful, 0.12), (Estate.hearth, 0.12)],
          ),
          PetitionOption(
            label: 'Suçluyu köyden sür',
            detail: 'En çok kan dökeni yola vurursun. Husumet uzaklaşır, bir ocak sönük kalır.',
            resolutionPool: [
              '🚪 Suçlu yola çıkarıldı. Arkasından kimse bakmadı, kimse ağlamadı.',
              '🚪 Kan döken sürüldü. Evinin kapısı sabaha kadar açık kaldı.',
            ],
            fx: PetitionFx.feudExile,
            moraleAmount: -0.04,
            moraleDays: 2,
            estateMood: [(Estate.faithful, 0.04), (Estate.hearth, -0.06)],
          ),
          PetitionOption(
            label: 'Meydanda idam et',
            detail: 'Halkın önünde infaz. Kan davası kanla kapanır, köy günlerce susar.',
            resolutionPool: [
              '⚔️ Meydanda infaz edildi. O gece {köy} ocağında kimse konuşmadı.',
              '⚔️ Karar kanla kapandı. Çocukları meydandan uzak tuttular.',
            ],
            fx: PetitionFx.feudExecute,
            moraleAmount: -0.10,
            moraleDays: 4,
            estateMood: [(Estate.faithful, 0.06), (Estate.hearth, -0.12)],
          ),
          PetitionOption(
            label: 'Karışma, sürsün',
            detail: 'Hakem olmazsın. İntikam sırası kimdeyse ona kalır.',
            resolutionPool: [
              '🩸 Sulh reddedildi. İki hane de bıçağını yatağının altında tutuyor.',
              '🩸 Karışılmadı. Yaşlılar meclisten çıkarken tek kelime etmedi.',
            ],
            moraleAmount: -0.08,
            moraleDays: 3,
            estateMood: [(Estate.faithful, -0.10), (Estate.hearth, -0.10)],
          ),
        ],
      ),
    ),

    // 😤 Emekçiler yorgun — bir nefes molası ister.
    _PetitionDef(
      (c) => c.aggrievedEstate == Estate.laborers && c.population >= 4,
      1.0,
      const Petition(
        id: 'grievanceLaborers',
        petitioner: 'Yorgun emekçiler',
        icon: '🌾',
        title: 'Emekçiler Soluklanmak İstiyor',
        tone: PetitionTone.solemn,
        estate: Estate.laborers,
        note: '↩ Emekçiler küskün',
        stakes: 'Bir günlük mola bir günlük ürün eder; ret ise haftalarca sürer.',
        bodyPool: [
          '“Efendim, adım {ad}, orak sallarım. Şu avucuma bak: nasırın üstünde yeni '
              'nasır var, geceleri parmaklarımı açamıyorum. Bir gün istiyoruz, bir gün. '
              'Ertesi sabah yine tarladayız, söz.”',
          '“Bu {mevsim} ne oğlumun yüzünü gördüm ne karımın. Karanlıkta çıkıyoruz, '
              'karanlıkta dönüyoruz; çocuk beni komşu sanıyor. Emekçiler adına '
              'söylüyorum: bize bir dinlenme günü ver.”',
          '“Kimse işten kaçmıyor, öyle anlama. Ama dün yanımdaki çocuk harmanda ayakta '
              'uyuyakaldı, düşerken az kalsın orağın üstüne gidiyordu. Yorgun el iyi iş '
              'çıkarmaz. Bir gün soluklanalım.”',
        ],
        options: [
          PetitionOption(
            label: 'Bir gün dinlensinler',
            detail: 'Bir gün çark durur. Eller açılır, sırtlar doğrulur.',
            resolutionPool: [
              '🌾 Bir gün tarlaya inen olmadı. Emekçiler gölgede uyudu, kimse onları uyandırmadı.',
              '🌾 Mola verildi. {ad} akşam çocuğunu omzunda gezdirirken görüldü.',
            ],
            moraleAmount: 0.05,
            moraleDays: 2,
            estateMood: [(Estate.laborers, 0.18), (Estate.artisans, -0.04)],
          ),
          PetitionOption(
            label: 'İş başına dönsünler',
            detail: 'Mola yok. Yarın da orak, öbür gün de orak.',
            resolutionPool: [
              '🌾 Mola verilmedi. {ad} başını salladı, orağını alıp tarlaya indi.',
              '🌾 Emekçiler sabah erkenden işe döndü. Hiçbiri yolda konuşmadı.',
            ],
            moraleAmount: -0.02,
            moraleDays: 1,
            estateMood: [(Estate.laborers, -0.08)],
          ),
        ],
      ),
    ),

    // 🔨 Zanaatkârlar değer görmek ister.
    _PetitionDef(
      (c) => c.aggrievedEstate == Estate.artisans && c.population >= 4,
      1.0,
      const Petition(
        id: 'grievanceArtisans',
        petitioner: 'Küskün zanaatkârlar',
        icon: '🔨',
        title: 'Zanaatkârlar Değer Görmek İstiyor',
        tone: PetitionTone.solemn,
        estate: Estate.artisans,
        note: '↩ Zanaatkârlar küskün',
        stakes: 'Bir kese altın tezgâhı doğrultur; ilgisizlik ustayı köyden soğutur.',
        bodyPool: [
          '“Efendim, {ad} benim, tezgâh benim. Üç gündür tek çivi satamadım, körüğü '
              'boşuna yakıyorum. Pazarda bize ayrılan yer samanlığın arka duvarı. '
              'Bir köşe verin, bir de göz.”',
          '“Şu kapının menteşesini ben yaptım, üstünden geçtiğin köprünün mıhlarını da. '
              'Kimse sormaz, kimse bilmez; ama bir çivi eğrilse adım köyün diline düşer. '
              'Pazarda doğru dürüst bir tezgâh isterim, fazlası değil.”',
          '“Biz para dilenmiyoruz, iş dileniyoruz. {köy} pazarında tahta tezgâhımız '
              'çürüdü, yağmurda derileri sırtımızla örtüyoruz. Biraz altın ayır da '
              'altımızda sağlam bir çatı olsun.”',
        ],
        options: [
          PetitionOption(
            label: 'Pazara yatırım yap',
            detail: 'Kese açılır: yeni tezgâh, sağlam çatı. Harmandakiler burulur.',
            resolutionPool: [
              '🔨 Pazara yeni tezgâhlar kuruldu. {ad} sabaha kadar körüğünü söndürmedi.',
              '🔨 Yatırım yapıldı. Ustalar tezgâhın çatısını kendi elleriyle çaktı.',
            ],
            goldDelta: -6,
            moraleAmount: 0.03,
            moraleDays: 2,
            estateMood: [(Estate.artisans, 0.18), (Estate.laborers, -0.04)],
          ),
          PetitionOption(
            label: 'Şimdilik olmaz',
            detail: 'Kese kapalı. Tezgâhlar yine yağmur altında.',
            resolutionPool: [
              '🔨 Yatırım yok. {ad} çekicini bıraktı, sonra sessizce yine eline aldı.',
              '🔨 Kese açılmadı. Ustalar tezgâhını toplarken tek laf etmedi.',
            ],
            moraleAmount: -0.02,
            moraleDays: 1,
            estateMood: [(Estate.artisans, -0.08)],
          ),
        ],
      ),
    ),

    // 🕯️ İnananlar maneviyat ihmal edildiğinden huzursuz.
    _PetitionDef(
      (c) => c.aggrievedEstate == Estate.faithful && c.population >= 4,
      1.0,
      const Petition(
        id: 'grievanceFaithful',
        petitioner: 'Huzursuz inananlar',
        icon: '🕯️',
        title: 'İnananlar Anlam Arıyor',
        tone: PetitionTone.solemn,
        estate: Estate.faithful,
        note: '↩ İnananlar küskün',
        stakes: 'Bir dua günü bir iş gününe mal olur; ret ise gönülleri koparır.',
        bodyPool: [
          '“Efendim, adım {ad}. Bu köyde doğan bebeğe dua okuyan yok, ölen için mum '
              'yakan yok. Sabaha karşı ateşin başına oturup kendi kendime söyleniyorum. '
              'Bir gün ver, toplanalım, başımızı önümüze eğelim.”',
          '“Kışın çocuğumuz öldüğünde tek bir çan sesi duymadık. Köy o gün de çalıştı, '
              'ertesi gün de. Biz bu köyün ruhunu arıyoruz, bulamıyoruz. Bir ayin günü '
              'isteriz, o kadar.”',
          '“Ekmeği veren yalnız toprak değil, bu {mevsim} boyu bunu unuttuk. Ateşin '
              'başında toplanıp bir kez şükretmek çok mu şey? Bir akşam bize ver, '
              'sabah yine işimizin başındayız.”',
        ],
        options: [
          PetitionOption(
            label: 'Bir ayin gününe izin ver',
            detail: 'Akşam ateşi ayine kalır. Ocak biraz gölgede kalır.',
            resolutionPool: [
              '🕯️ İnananlar ateşin çevresine oturdu. Duayı {ad} açtı, sesi tutulana kadar okudu.',
              '🕯️ Ayin günü verildi. Gece köyde tek bir kapı kapanmadı, herkes ateşe geldi.',
            ],
            moraleAmount: 0.03,
            moraleDays: 2,
            fx: PetitionFx.cult,
            estateMood: [(Estate.faithful, 0.18), (Estate.hearth, -0.04)],
          ),
          PetitionOption(
            label: 'Sıradan günlere dön',
            detail: 'Ayin yok. Herkes yarın da işinin başında.',
            resolutionPool: [
              '🕯️ Ayin verilmedi. {ad} mumunu yakmadan cebine geri koydu.',
              '🕯️ İnananlar dağıldı. Ateşin başında bu gece kimse oturmadı.',
            ],
            moraleAmount: -0.02,
            moraleDays: 1,
            estateMood: [(Estate.faithful, -0.08)],
          ),
        ],
      ),
    ),

    // 🏡 Ocak (yaşlılar + aileler) gelenek ihmal edildiğinden küskün.
    _PetitionDef(
      (c) => c.aggrievedEstate == Estate.hearth && c.population >= 4,
      1.0,
      const Petition(
        id: 'grievanceHearth',
        petitioner: 'Ocağın yaşlıları',
        icon: '🏡',
        title: 'Ocak Unutulmak İstemiyor',
        tone: PetitionTone.solemn,
        estate: Estate.hearth,
        note: '↩ Ocak bir süredir küskün',
        stakes: 'Bir sofra bir kile buğdaya mal olur; unutulmak yıllara.',
        bodyPool: [
          '“Biz bu köyün ilk taşını koyduk, şimdi kapımızın önünden geçerken selam '
              'veren yok. Torunum benim adımı değil, mesleğimi biliyor. Bir ortak sofra '
              'kur, hepsi bu. Yan yana oturalım, kim kimin oğluymuş hatırlansın.”',
          '“Efendim, {ad} benim; şu ocağı yakan taşları ben taşıdım. Gençler artık '
              'yemeğini kapı önünde tek başına yiyor, kimse kimsenin ekmeğini bölmüyor. '
              'Bir gece hepimizi bir sofraya oturt. Bak o zaman köy neye benziyormuş.”',
          '“{hane} kapısı kırk yıldır açık durur, geçen ay ilk kez kimse gelmedi. '
              'Yaşlıyız, çok şey istemiyoruz: bir sofra, bir sıcak tencere, bir de '
              'yanımıza oturan biri.”',
        ],
        options: [
          PetitionOption(
            label: 'Ortak sofra kur',
            detail: 'Ambardan bir pay gider. Kuşaklar yan yana oturur.',
            resolutionPool: [
              '🏡 Ortak sofra kuruldu. {ad} torununa kendi babasının adını anlattı.',
              '🏡 Sofra uzun kuruldu, herkes sığdı. Yaşlılar en başa oturtuldu.',
            ],
            foodDelta: -4,
            moraleAmount: 0.04,
            moraleDays: 2,
            estateMood: [(Estate.hearth, 0.18), (Estate.faithful, 0.04)],
          ),
          PetitionOption(
            label: 'Şimdilik değil',
            detail: 'Sofra kurulmaz. Yaşlılar akşam yemeğini yine tek başına yer.',
            resolutionPool: [
              '🏡 Sofra kurulmadı. {ad} kapısını her zamankinden erken kapattı.',
              '🏡 Sonra dendi. Yaşlılar bunu daha önce de duymuştu.',
            ],
            moraleAmount: -0.02,
            moraleDays: 1,
            estateMood: [(Estate.hearth, -0.08)],
          ),
        ],
      ),
    ),

    // ════════════════════════════════════════════════════════════════════════
    // KİMLİK ÖDÜL DİLEKÇELERİ — köy bir kimliğe kaydığında (identity.<ad>
    // bayrağı) o kimliğe ÖZEL şenlik/hikâye açılır.
    // ════════════════════════════════════════════════════════════════════════

    // 🌾 Bereketli Köy → Bereket Bayramı (tarlalar altın ışıltıyla parlar).
    _PetitionDef(
      (c) => c.remembers('identity.laborers') && c.food >= 20,
      0.7,
      const Petition(
        id: 'identityHarvestFeast',
        petitioner: 'Ambar başındaki çiftçiler',
        icon: '🌾',
        title: 'Bereket Bayramı',
        tone: PetitionTone.warm,
        estate: Estate.laborers,
        note: '✦ Kimlik: Bereketli Köy',
        stakes: 'Bir kese altın; karşılığında günlerce parlayan tarlalar.',
        bodyPool: [
          '“Ambarın kapağı kapanmıyor, buğday eşikten taşıyor. Dedem böyle bir yıl '
              'görmedim derdi, işte gördük. Bir bereket bayramı kur; başaktan taç örüp '
              'meydana çıkalım.”',
          '“Efendim, {ad} benim, harmanı ben savurdum. Bu {mevsim} on kile fazla '
              'kaldırdık, saymaktan usandık. Böyle bir yıl bir daha ne zaman gelir? '
              'Kutlayalım da toprak şükrettiğimizi görsün.”',
          '“Çocuklar tarlada başak tacı örüyor, kimse onlara öğretmedi. Köy zaten kendi '
              'kendine kutluyor. Sen bir izin ver, biz meydanı donatalım.”',
        ],
        options: [
          PetitionOption(
            label: 'Bayramı kur!',
            detail: 'Altın harcanır. Tarlalar günlerce altın gibi parlar.',
            resolutionPool: [
              '🌾 Bereket Bayramı kuruldu. Meydan başak tacıyla doldu, tarlalar günlerce parladı.',
              '🌾 Bayram başladı. {ad} ilk demeti meydanın ortasına dikti, köy başına toplandı.',
            ],
            goldDelta: -5,
            moraleAmount: 0.12,
            moraleDays: 3,
            fx: PetitionFx.harvestBounty,
            estateMood: [(Estate.laborers, 0.10), (Estate.hearth, 0.05)],
          ),
          PetitionOption(
            label: 'Sade geçelim',
            detail: 'Kese kapalı. Harman kaldırılır, kutlama olmaz.',
            resolutionPool: [
              '🌾 Bayram kurulmadı. Başak taçları çocukların elinde soldu.',
              '🌾 Sade geçildi. Ambar dolu, meydan boş.',
            ],
            moraleAmount: -0.02,
            moraleDays: 1,
            estateMood: [(Estate.laborers, -0.05)],
          ),
        ],
      ),
    ),

    // 🔨 Zanaat Kasabası → Zanaat Panayırı (çevreden alıcı gelir, kazanç).
    _PetitionDef(
      (c) => c.remembers('identity.artisans') && c.population >= 6,
      0.7,
      const Petition(
        id: 'identityCraftFair',
        petitioner: 'Köyün ustaları',
        icon: '🔨',
        title: 'Zanaat Panayırı',
        tone: PetitionTone.warm,
        estate: Estate.artisans,
        note: '✦ Kimlik: Zanaat Kasabası',
        stakes: 'Panayır kurulursa çevre köyün kesesi bizim tezgâhta boşalır.',
        bodyPool: [
          '“Efendim, dün iki köy öteden bir adam geldi, sırf benim yaptığım orak için. '
              'Yolu iki gün sürmüş. Bir panayır kuralım, bırak onlar bize gelsin; biz her '
              'seferinde eşeğe yükleyip yollara düşmeyelim.”',
          '“{ad} benim, on yıldır çekiç sallıyorum. Şimdiye kadar adımı bilen yoktu, bu '
              '{mevsim} üç kez soruldu. Panayırı kur, tezgâhları meydana diz. Kese dolar, '
              'adımız daha da yayılır.”',
          '“Ambarda altmış parça iş bekliyor; alıcısı yok değil, gelemiyor. Bir panayır '
              'ilan et, çevre köyler bir gün için buraya aksın. Zararımız bir günlük '
              'çekiç sesi, kârı kese dolusu.”',
        ],
        options: [
          PetitionOption(
            label: 'Panayırı kur!',
            detail: 'Meydan tezgâhla dolar. Çevre köylerin kesesi burada boşalır.',
            resolutionPool: [
              '🔨 Panayır kuruldu. Akşama kadar örs sesi dinmedi, kese doldu.',
              '🔨 Çevre köyler akın etti. {ad-in} tezgâhında tek parça kalmadı.',
            ],
            goldDelta: 8,
            moraleAmount: 0.10,
            moraleDays: 3,
            fx: PetitionFx.festival,
            estateMood: [(Estate.artisans, 0.10), (Estate.laborers, 0.04)],
          ),
          PetitionOption(
            label: 'Gerek yok',
            detail: 'Panayır kurulmaz. Ustalar malını yine sırtında taşır.',
            resolutionPool: [
              '🔨 Panayır kurulmadı. {ad} işini eşeğe yükleyip yola çıktı.',
              '🔨 Gerek yok dendi. Tezgâhlar bir gün daha sessiz kaldı.',
            ],
            moraleAmount: -0.02,
            moraleDays: 1,
            estateMood: [(Estate.artisans, -0.05)],
          ),
        ],
      ),
    ),

    // 🕯️ Kutsal Köy → Büyük Ayin (köy çapında şükran töreni).
    _PetitionDef(
      (c) => c.remembers('identity.faithful') && c.population >= 5,
      0.7,
      const Petition(
        id: 'identityGreatRite',
        petitioner: 'Ateş başındaki cemaat',
        icon: '🕯️',
        title: 'Büyük Ayin',
        tone: PetitionTone.warm,
        estate: Estate.faithful,
        note: '✦ Köyün kimliği: Kutsal Köy',
        stakes: 'Bir gecelik ayin; köy sabaha dek diz üstünde.',
        bodyPool: [
          '“Efendim, uzak köylerden gelip bizim ateşimizin başında dua eden var artık. '
              'Adımız duyulmuş. Büyük bir ayin kuralım; bir gece boyunca ne çalışan olsun '
              'ne konuşan.”',
          '“{ad} benim, mumları ben yakarım. Bu köyde artık doğan çocuğa dua okunuyor, '
              'ölen için mum yakılıyor; unutmadık. Bir kez de bütün köy tek nefes olsun. '
              'Bir gece ver bize.”',
          '“Geceleri ateşin başında bir sessizlik oluyor, kimse onu bozmuyor. O sessizlik '
              'bize bir şey söylüyor. Büyük ayini kur da bütün köy onu bir kez duysun.”',
        ],
        options: [
          PetitionOption(
            label: 'Ayini başlat',
            detail: 'Bütün köy ateşin başına iner. O gece hiçbir çark dönmez.',
            resolutionPool: [
              '🕯️ Büyük Ayin başladı. Sabaha kadar ateş sönmedi, kimse ayağa kalkmadı.',
              '🕯️ Köy ateşin çevresinde diz çöktü. {ad} duayı okurken çocuklar bile susmuştu.',
            ],
            moraleAmount: 0.10,
            moraleDays: 3,
            fx: PetitionFx.cult,
            estateMood: [(Estate.faithful, 0.10), (Estate.hearth, 0.04)],
          ),
          PetitionOption(
            label: 'Sade dua yeter',
            detail: 'Ayin kurulmaz. Herkes kendi köşesinde okur.',
            resolutionPool: [
              '🕯️ Büyük ayin olmadı. {ad} mumları geri kaldırdı.',
              '🕯️ Sade bir dua ile yetinildi. Ateş her akşamki gibi yandı.',
            ],
            moraleAmount: -0.02,
            moraleDays: 1,
            estateMood: [(Estate.faithful, -0.05)],
          ),
        ],
      ),
    ),

    // 🏡 Köklü Yuva → Yuva Şöleni (herkesin katıldığı sıcak şölen).
    _PetitionDef(
      (c) => c.remembers('identity.hearth') && c.food >= 18,
      0.7,
      const Petition(
        id: 'identityHomecoming',
        petitioner: 'Hanelerin büyükleri',
        icon: '🏡',
        title: 'Yuva Şöleni',
        tone: PetitionTone.warm,
        estate: Estate.hearth,
        note: '✦ Köyün kimliği: Köklü Yuva',
        stakes: 'Ambardan bir pay; karşılığında bütün kuşaklar tek sofrada.',
        bodyPool: [
          '“Biz bu köyde üç kuşak gördük. Ama torunum, dedesinin hangi kapıda oturduğunu '
              'bilmiyor. Uzun bir sofra kur; bu akşam kimse kendi hanesinde yemesin.”',
          '“Efendim, {hane} kapısında kırk kişi yemek yer, dar gelmez. Komşunun kapısı da '
              'dar değil. Hepsini bir araya çekelim: bir yuva şöleni. Ambardan bir pay, '
              'karşılığında bir köy.”',
          '“{ad} benim, dört çocuk büyüttüm bu ocakta. Şimdi hepsi ayrı kapıda yemek '
              'yiyor, aynı köyde. Bir şölen ver; masayı öyle uzun kur ki ucu görünmesin.”',
        ],
        options: [
          PetitionOption(
            label: 'Şöleni ver!',
            detail: 'Ambardan pay gider. Uzun bir sofra, ucu görünmez.',
            resolutionPool: [
              '🏡 Sofra meydandan çeşmeye kadar uzadı. Kimse kendi kapısında yemedi.',
              '🏡 Yuva Şöleni kuruldu. {ad} sofranın başına oturdu, en son o kalktı.',
            ],
            foodDelta: -5,
            moraleAmount: 0.12,
            moraleDays: 3,
            fx: PetitionFx.festival,
            estateMood: [(Estate.hearth, 0.10), (Estate.laborers, 0.04)],
          ),
          PetitionOption(
            label: 'Mütevazı kalalım',
            detail: 'Şölen kurulmaz. Herkes kendi kapısında yer.',
            resolutionPool: [
              '🏡 Şölen kurulmadı. Akşam her hane kendi tenceresini kaynattı.',
              '🏡 Bu sefer olmasın dendi. {ad} uzun sofrayı hayal etmekle kaldı.',
            ],
            moraleAmount: -0.02,
            moraleDays: 1,
            estateMood: [(Estate.hearth, -0.05)],
          ),
        ],
      ),
    ),

];
