part of 'petition_system.dart';

/// ─── DİLEKÇE KATALOĞU ───────────────────────────────────────────────────────
///
/// Köyün senden isteyebileceği HER ŞEY burada: koşul (canFire), ağırlık ve
/// dilekçenin kendisi (metin havuzları + seçenekler + sonuçlar).
///
/// Motor (roll/byId/debugRandom) `petition_system.dart`'ta durur — içerik ile
/// mekanizma aynı dosyada olunca ikisi de okunmaz hâle geliyordu. Yeni dilekçe
/// eklerken yalnız buraya dokun; motor değişmez.
///
/// SÖZLEŞME: bir seçeneğin sahnede görünür karşılığı `fx:` alanıdır. Boş
/// bırakılırsa karar yine GÖRÜLÜR (bkz. scene_reactions._reactPlainDecision)
/// ama bespoke bir gösteri olmaz.

final List<_PetitionDef> _kPetitionDefs = [
    // ════════════════════════════════════════════════════════════════════════
    // SUÇ (scene_crime) — yargı + asayiş + fidye
    // ════════════════════════════════════════════════════════════════════════

    // ⛓️ SUÇÜSTÜ YAKALANAN FAİL — hüküm senin. canFire=false: bu dilekçe random
    // çıkmaz, yalnız bir suçlu yakalanınca AÇIKÇA sunulur (_openVerdict).
    // Yer tutucular: {ad}=dilekçeyi getiren (kurban/tanık), {suçlu}, {suç},
    // {hal} (önlendi mi), {sabıka}.
    _PetitionDef(
      (c) => false,
      0,
      const Petition(
        id: 'crimeVerdict',
        petitioner: 'Köy, {suçlu} için hüküm bekliyor',
        icon: '⛓️',
        title: '{suçlu} Suçüstü Yakalandı',
        tone: PetitionTone.ominous,
        note: '↩ {suç} — {hal}',
        stakes: 'Merhamet cesaret verir, sertlik korku salar. İkisinin de bedeli var.',
        bodyPool: [
          '“Gözümle gördüm efendim. {suçlu} yaptı, inkâr edecek hâli yok; '
              'kolundan tuttuğumuzda hâlâ eli titriyordu. {sabıka} Şimdi meydanda '
              'diz çökmüş bekliyor. Ne dersen o olur — ama {köy} de bekliyor, '
              'unutma.”',
          '“Suç ortada, fail ortada: {suçlu}. {sabıka} Kimimiz bağışla diyor, '
              'kimimiz bir daha kimse cesaret edemesin diyor. Ben ne diyeceğimi '
              'bilmiyorum efendim, o yüzden sana getirdik.”',
          '“Bu köy küçük. Bugün {suçlu-i} bağışlarsan yarın kapımızı kilitlemeye '
              'başlarız; asarsan da her akşam o meydandan geçeriz. {sabıka} Hüküm '
              'senin, yükü hepimizin.”',
        ],
        options: [
          PetitionOption(
            label: 'Bağışla',
            detail: '{suçlu} serbest kalır. Köy adaletsizlik hisseder; suça cesaret artar.',
            resolutionPool: [
              'Bağışladın. {suçlu} başını kaldıramadan kalabalığın arasına karıştı.',
              'Merhamet ettin. Kimileri onayladı, kimileri yüzünü çevirdi.',
              'Elini salladın; {suçlu} serbest. Bu köy bunu hatırlayacak.',
            ],
            moraleAmount: -0.03,
            moraleDays: 3,
            fx: PetitionFx.crimePardon,
            estateMood: [(Estate.faithful, 0.10), (Estate.hearth, -0.05)],
          ),
          PetitionOption(
            label: 'Meydanda cezalandır',
            detail: '{suçlu} teşhir edilir: günlerce iş göremez, köy düzeni görür.',
            resolutionPool: [
              'Hüküm indi. {suçlu} meydanda cezasını çekti; köy sessizce dağıldı.',
              '{suçlu} halkın önünde cezalandırıldı. Kimse itiraz etmedi.',
              'Ceza kesildi. Bu akşam köyde kimse sesini yükseltmiyor.',
            ],
            moraleAmount: 0.05,
            moraleDays: 4,
            fx: PetitionFx.crimePunish,
            estateMood: [(Estate.hearth, 0.08), (Estate.laborers, 0.04)],
          ),
          PetitionOption(
            label: 'Köyden sür',
            detail: '{suçlu} köyü terk eder. Bir el eksilir; hanesi küser.',
            resolutionPool: [
              '{suçlu} bohçasını topladı. Yolun başında arkasına bakmadı.',
              'Sürgün. {suçlu-in} adı bir daha bu sofrada anılmayacak.',
              'Kapı kapandı. {suçlu} gitti, köy biraz daha ıssız.',
            ],
            moraleAmount: -0.02,
            moraleDays: 3,
            fx: PetitionFx.crimeExile,
            estateMood: [(Estate.hearth, 0.05), (Estate.faithful, -0.08)],
          ),
          PetitionOption(
            label: 'İdam et',
            detail: 'En sert hüküm: {suçlu} halkın önünde infaz edilir. Köyü dehşet sarar.',
            resolutionPool: [
              'Hüküm okundu. {suçlu} diz çöktü; meydan bir daha eskisi gibi olmadı.',
              '{suçlu} idam edildi. Köy dağılırken kimse konuşmadı.',
              'İnfaz tamam. Bu köy artık senden korkuyor.',
            ],
            moraleAmount: -0.10,
            moraleDays: 6,
            fx: PetitionFx.crimeExecute,
            estateMood: [(Estate.hearth, -0.12), (Estate.faithful, -0.10)],
          ),
        ],
      ),
    ),

    // 👁️ ASAYİŞ — üst üste MEÇHUL suç işlendi, köy güvenini yitiriyor.
    _PetitionDef(
      (c) => c.crimeSuspicion >= 3 && c.population >= 6,
      1.5,
      const Petition(
        id: 'crimeWave',
        petitioner: 'Köyün yaşlıları',
        icon: '👁️',
        title: 'Köy Kendi Gölgesinden Korkuyor',
        tone: PetitionTone.ominous,
        note: '↩ Üst üste suç işlendi, hiçbirinin faili bulunamadı',
        stakes: 'Nöbet güven verir ama köylüyü yorar. Kayıtsızlık bedava değil.',
        bodyPool: [
          '“Efendim, kapılar artık kilitleniyor. {köy} kimseye kefil olamıyor; '
              'komşu komşuya bakmıyor. Üç kere hesap tutmadı, üç kere de fail '
              'bulunamadı. Böyle giderse burada kimse rahat uyuyamaz.”',
          '“Bir şey oluyor bu köyde ve kimse görmüyor. Ya da görüyor da '
              'söylemiyor. Bize bir düzen lazım efendim — göz lazım. Yoksa '
              'birbirimizden şüphelenmeye başlayacağız, o da bizi bitirir.”',
          '“Malımız gidiyor, sesimiz çıkmıyor. Sen bize bir yol göster: ya bir '
              'göz koy başımıza, ya da rahatımıza bakalım da olan olsun.”',
        ],
        options: [
          PetitionOption(
            label: 'Gece nöbeti kur',
            detail: 'Köy nöbet tutar: suç belirgin biçimde azalır, ama uykusuz köylü yorulur.',
            resolutionPool: [
              'Nöbet başladı. Fenerler geç saate kadar yanıyor.',
              'Köy sırayla nöbete duruyor. Uykular kısaldı, kapılar rahatladı.',
              'Gece nöbeti kuruldu. Artık meydanda hep bir göz var.',
            ],
            goldDelta: -8,
            moraleAmount: -0.02,
            moraleDays: 4,
            fx: PetitionFx.crimeWatch,
            setsFlags: ['crime.watch'],
            estateMood: [(Estate.hearth, 0.10), (Estate.laborers, -0.05)],
          ),
          PetitionOption(
            label: 'Muhafıza güven',
            detail: 'Devriyeye ek pay ayrılır. Bedeli altın; nöbetin yorgunluğu yok.',
            resolutionPool: [
              'Muhafızların payı arttı. Devriye sıklaştı.',
              'Kese açıldı: köyün bekçisi artık daha uyanık.',
              'Devriyeye güvendin. Meydanda mızrak sesi eksik olmuyor.',
            ],
            goldDelta: -18,
            moraleAmount: 0.05,
            moraleDays: 4,
            fx: PetitionFx.crimeWatch,
            estateMood: [(Estate.hearth, 0.08), (Estate.artisans, 0.04)],
          ),
          PetitionOption(
            label: 'Geçer bu',
            detail: 'Hiçbir şey yapılmaz. Köy tedirgin kalır, suç beslenmeye devam eder.',
            resolutionPool: [
              'Bir şey yapılmadı. Köy kapısını kendi kilitledi.',
              'Bekledin. Yaşlılar başını salladı, kimse ısrar etmedi.',
              'Geçer dedin. Belki geçer.',
            ],
            moraleAmount: -0.06,
            moraleDays: 4,
            fx: PetitionFx.crimeWatch,
            estateMood: [(Estate.hearth, -0.10)],
          ),
        ],
      ),
    ),

    // 🕳️ FİDYE — kaçırılan köylü için haber geldi. canFire=false: açıkça sunulur.
    _PetitionDef(
      (c) => false,
      0,
      const Petition(
        id: 'ransom',
        petitioner: 'Yolun başında bırakılmış bir haber',
        icon: '🕳️',
        title: 'Fidye İstiyorlar',
        tone: PetitionTone.ominous,
        note: '↩ Kaçırılan köylü için bedel isteniyor',
        stakes: 'Ödersen kese boşalır. Ödemezsen o kapı bir daha açılmaz.',
        bodyPool: [
          '“Taşın altına sıkıştırılmış efendim. Okuması kolay: keseyi doldur, '
              'canını al. Bir gün mühlet vermişler. {köy} bekliyor — ama boş bir '
              'yatak da bekliyor.”',
          '“Haberi getiren yoktu, haber vardı. İstedikleri altın, verecekleri '
              'bir insan. Bu köyde kimse bu hesabı yapmaya alışkın değil efendim.”',
          '“Bedelini istiyorlar. Ödersek zayıf görünürüz derler; ödemezsek '
              'bir daha kimse geceleri dışarı çıkmaz. Karar senin.”',
        ],
        options: [
          PetitionOption(
            label: 'Fidyeyi öde',
            detail: 'Kese boşalır ama köylü sağ salim geri döner.',
            resolutionPool: [
              'Kese bırakıldı. Şafakta yolun başında bir gölge belirdi.',
              'Ödedin. Köy bir canını geri aldı.',
              'Altın gitti, insan geldi. Kimse pişman görünmüyor.',
            ],
            goldDelta: -35,
            moraleAmount: 0.08,
            moraleDays: 5,
            fx: PetitionFx.ransomPaid,
            estateMood: [(Estate.hearth, 0.12), (Estate.faithful, 0.06)],
          ),
          PetitionOption(
            label: 'Ödeme yapılmayacak',
            detail: 'Kese kapalı kalır. Kaçırılan köylü bir daha dönmez.',
            resolutionPool: [
              'Haber yanıtsız kaldı. O yatak bir daha toplanmadı.',
              'Ödemedin. Köy sustu, kapı açık kaldı.',
              'Bedel reddedildi. Kimse bir daha o adı yüksek sesle anmadı.',
            ],
            moraleAmount: -0.10,
            moraleDays: 6,
            fx: PetitionFx.ransomRefused,
            estateMood: [(Estate.hearth, -0.14), (Estate.faithful, -0.08)],
          ),
        ],
      ),
    ),

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
              'yarısı boş. Dün akşama kadar iki kile un gördüm, ikisi de komşunundu. Ya '
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
            detail: 'Toprak dinlenmeye devam eder. Esnaf tezgâhının tozunu almaya.',
            resolutionPool: [
              '🌱 Takvim değişmedi. Tarlanın yarısı dinleniyor, esnaf homurdanıyor.',
              '🌱 Yasa yasadır dendi. {ad} tezgâhını toplayıp gitti, arkasına bakmadı.',
            ],
            estateMood: [(Estate.laborers, 0.10), (Estate.hearth, 0.04), (Estate.artisans, -0.12)],
          ),
          PetitionOption(
            label: 'Esnafa pay ayır',
            detail: 'Keseden altın akar. Tezgâh doğrulur, harmandakiler burnundan solur.',
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

    // 🚪 Misafirperverlik yürürlükte + boş hane var → bir gezgin yerleşmek ister.
    _PetitionDef(
      (c) => c.hospitality && c.hasHousing && c.population >= 5 && c.food >= 8,
      0.6,
      const Petition(
        id: 'wandererSettles',
        petitioner: 'Yolu düşmüş bir gezgin',
        icon: '🚪',
        title: 'Bir Gezgin Yerleşmek İstiyor',
        tone: PetitionTone.warm,
        estate: Estate.artisans,
        note: '⚖ Misafirperverlik yasası',
        stakes: 'Sofraya bir boğaz daha; karşılığında iş tutan bir çift el.',
        bodyPool: [
          '“Sekiz köy gezdim, hiçbirinde kapıyı açık bulmadım. Sizde kapıda '
              'bekletmediler, ekmek verdiler, adımı sordular. Boş bir hane varmış diye '
              'duydum. Marangoz oğluyum, elim iş tutar; yalnız bir çatı isterim.”',
          '“Efendim, yükümde bir balta ve iki gömlek var, başka bir şeyim yok. Kışı bir kez '
              'daha yolda geçirirsem geçiremem. {köy} bana tanıdık geldi, sebebini '
              'bilmiyorum. Bir köşe ver, gerisini kendim yaparım.”',
          '“Üç nehir aştım. Yolda öğrendiğim ne varsa buraya bırakırım: bir hastalığın '
              'otu, bir tohumun vakti, iki de türkü. Karşılığında bir yatak ve sofrada bir '
              'yer isterim.”',
        ],
        options: [
          PetitionOption(
            label: 'Hoş geldin, yerleş',
            detail: 'Sofraya bir boğaz eklenir. Köye bir çift el, bir yığın haber.',
            resolutionPool: [
              '🚪 Gezgin boş haneye yerleşti. İlk işi kapının menteşesini onarmak oldu.',
              '🚪 Kapı açıldı. Gezgin o akşam ateşin başında uzak bir kıyıyı anlattı.',
            ],
            foodDelta: -3,
            moraleAmount: 0.05,
            moraleDays: 3,
            estateMood: [(Estate.artisans, 0.12), (Estate.hearth, 0.05), (Estate.laborers, -0.03)],
          ),
          PetitionOption(
            label: 'Bu sefer olmaz',
            detail: 'Sofra dar. Gezgin çıkınını toplar, yola devam eder.',
            resolutionPool: [
              '🚪 Gezgin geri çevrildi. Baltasını sırtlayıp yola koyuldu, dönüp bakmadı.',
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
            detail: 'Kese kapalı. Ateş her akşamki gibi yanar, davul kutuda kalır.',
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
        stakes: 'Sıkı hesap bahara çıkarır; bol sofra köyü ısıtır, ambarı eritir.',
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
            detail: 'Köy ateşin başında toplanır, mumlar yakılır. Acı ortaklaşır.',
            resolutionPool: [''], // dinamik mesaj reaksiyondan gelir (isimle)
            fx: PetitionFx.vigil,
            estateMood: [(Estate.hearth, 0.08), (Estate.faithful, 0.06)],
          ),
          PetitionOption(
            label: 'Sessizce uğurla',
            detail: 'Tören yok. Herkes kendi kapısının ardında yas tutar.',
            resolutionPool: [''],
            fx: PetitionFx.mourn,
            estateMood: [(Estate.hearth, -0.08), (Estate.faithful, -0.05)],
          ),
        ],
      ),
    ),

    // ⛪ Yeni bir inanç. Zincir başı: "Bırak" → cult.active + cultGrows takibi.
    _PetitionDef(
      (c) => c.population >= 5 &&
          !c.remembers('cult.active') &&
          !c.remembers('cult.suppressed'),
      0.5,
      const Petition(
        id: 'newFaith',
        petitioner: 'Tedirgin bir komşu',
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
            detail: 'Çember bozulmaz. Ateş başındaki ayin sürer, kimi ocak huzursuz.',
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
            detail: 'Çember silinir. Ateş başındaki toplantı dağılır, hevesler kırılır.',
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
        stakes: 'Bir günlük durgunluk; karşılığında konuşulmayan adlar konuşulur.',
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
            estateMood: [(Estate.hearth, 0.10), (Estate.laborers, 0.04), (Estate.artisans, -0.04)],
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

    // ─── Takip dilekçeleri (zincir) — yalnız bir önceki karara bağlı gelir ───

    // 🎊 Şenliği gelenek yapma teklifi (harvestFestival onayının takibi).
    _PetitionDef(
      (_) => false,
      0,
      const Petition(
        id: 'festivalAnnual',
        petitioner: 'Çiftçiler',
        icon: '🎊',
        title: 'Gelenek Olsun mu?',
        tone: PetitionTone.warm,
        estate: Estate.laborers,
        note: '↩ Şenlik günlerce konuşuldu',
        stakes: 'Bir söz: her hasatta bu ateş yeniden yansın.',
        bodyPool: [
          '“Efendim, şenlikten üç gün geçti; çocuklar hâlâ o davulun ritmini tencerelere '
              'vuruyor. Bir ihtiyar bana ölmeden bir daha görür müyüm diye sordu. Söz ver: '
              'her hasatta bu ateş yansın.”',
          '“{ad} benim. O gece kırk yıldır ilk kez oynadım; ayağım tutmadı ama umurumda '
              'değildi. Bunu bir kereye mahsus bırakma. Adı olsun, günü olsun; herkes ona '
              'göre beklesin.”',
          '“Şenlik bitti ama köy bitmedi, hâlâ konuşuyorlar. Bir şeyin gelenek olması için '
              'önce adının konması gerek. Sen adını koy, gerisini biz her yıl yaparız.”',
        ],
        options: [
          PetitionOption(
            label: 'Gelenek olsun',
            detail: 'Her hasatta ateş yanar. Köyün kendi bayramı olur.',
            resolutionPool: [
              '🎊 Hasat şenliği geleneğe yazıldı. Artık takvimde kendi günü var.',
              '🎊 Gelenek ilan edildi. {ad} tarih düşsün diye ambarın duvarına bir çentik attı.',
            ],
            moraleAmount: 0.06,
            moraleDays: 10,
            fx: PetitionFx.festival,
            setsFlags: ['festival.tradition'],
            estateMood: [(Estate.laborers, 0.12), (Estate.hearth, 0.06)],
          ),
          PetitionOption(
            label: 'Gerek yok',
            detail: 'Söz verilmez. Güzeldi, geçti.',
            resolutionPool: [
              '🎊 Gelenek olmadı. Davul ambara kaldırıldı, üstüne çuval yığıldı.',
              '🎊 Bir kereye mahsus dendi. {ad} bunu ihtiyara nasıl söyleyeceğini bilemedi.',
            ],
            moraleAmount: -0.02,
            moraleDays: 1,
            estateMood: [(Estate.laborers, -0.06)],
          ),
        ],
      ),
    ),

    // ⛪ Kült büyüdü (newFaith "Bırak" takibi).
    _PetitionDef(
      (_) => false,
      0,
      const Petition(
        id: 'cultGrows',
        petitioner: 'Yeni inananlar',
        icon: '🔮',
        title: 'İnanç Yayılıyor',
        tone: PetitionTone.ominous,
        estate: Estate.faithful,
        note: '↩ Ayinlere göz yummuştun',
        stakes: 'Tapınak verirsen çemberin çatısı olur; sınırlarsan bir şey söner.',
        bodyPool: [
          '“Efendim, çember artık ateşin başına sığmıyor. Dün gece dışarıda kalanlar '
              'yağmurun altında durdu, yine de gitmediler. Bize bir dam ver, taştan olsun. '
              'İbadetimizi kapı ardında değil, kapı önünde yapalım.”',
          '“{ad} benim; ilk çemberi ben çizmiştim, hatırlarsın. O zaman beş kişiydik, şimdi '
              'köyün yarısı. Bu kendi kendine büyüdü, ne ben çağırdım ne kimse zorladı. Bir '
              'ibadet yeri istiyoruz, hepsi bu.”',
          '“Yaşlılar bizden korkuyor, biliyorum; kapılarını erken kapatıyorlar. Korkunun '
              'sebebi karanlıkta toplanmamız. Bir tapınak ver de gündüz gözüyle ibadet '
              'edelim, korkacak bir şey kalmasın.”',
        ],
        options: [
          PetitionOption(
            label: 'Bir tapınak ver',
            detail: 'Altın ve taş gider. Çember köyün ortasına, çatı altına taşınır.',
            resolutionPool: [
              '🔮 Tapınağın ilk taşı kondu. Çember artık gündüz gözüyle toplanıyor.',
              '🔮 İnananlara bir dam verildi. {ad} o işareti kapıya kendi eliyle kazıdı.',
            ],
            goldDelta: -6,
            stoneDelta: -10,
            moraleAmount: 0.05,
            moraleDays: 5,
            fx: PetitionFx.templeRaised,
            setsFlags: ['cult.temple'],
            followUpId: 'cultSchism',
            followUpDelayDays: 4.0,
            estateMood: [(Estate.faithful, 0.14), (Estate.hearth, -0.10), (Estate.artisans, -0.05)],
          ),
          PetitionOption(
            label: 'Yeter, sınırla',
            detail: 'Ayin dağıtılır. İnananlar susar, ocak rahat nefes alır.',
            resolutionPool: [
              '⛪ Ayinler kısıtlandı. Ateşin başında bir daha kimse toplanmadı.',
              '⛪ İnanç sınırlandı. {ad} çemberi kendi ayağıyla sildi, sonra uzun süre orada durdu.',
            ],
            moraleAmount: -0.06,
            moraleDays: 4,
            clearsFlags: ['cult.active'],
            setsFlags: ['cult.suppressed'],
            estateMood: [(Estate.faithful, -0.16), (Estate.hearth, 0.08)],
          ),
        ],
      ),
    ),

    // ⚡ Kültte bölünme (cultGrows "tapınak" takibi).
    _PetitionDef(
      (_) => false,
      0,
      const Petition(
        id: 'cultSchism',
        petitioner: 'Bölünen cemaat',
        icon: '⚡',
        title: 'İnançta Bölünme',
        tone: PetitionTone.ominous,
        estate: Estate.faithful,
        note: '↩ Tapınağı sen vermiştin',
        stakes: 'Taraf tutarsan biri köyü terk eder; uzlaştırmak altın ve sabır ister.',
        bodyPool: [
          '“Efendim, verdiğin tapınakta artık iki ayrı dua okunuyor. Sabahçılarla '
              'gececiler birbirinin mumunu söndürüyor, dün kapıda itiştiler. Ya bir taraf '
              'tut, ya bizi bir masaya oturt. Bu hâl daha fazla sürmez.”',
          '“{ad} benim, eski öğretiye sadığım. Karşı taraf yeni bir sözcünün ardında; kötü '
              'insanlar değiller ama bizim duamızı yanlış sayıyorlar. Aynı damın altında iki '
              'hakikat durmuyor. Sen seç.”',
          '“Tapınağın kapısına iki ayrı işaret kazındı, biri ötekinin üstünü çizmiş. '
              'Çocuklar hangi tarafa oturacağını şaşırıyor. Ya birimizi kapı dışarı et, ya '
              'ikimizi aynı sofraya oturt. Ortası yok.”',
        ],
        options: [
          PetitionOption(
            label: 'Bir hizbi destekle',
            detail: 'Net taraf tutarsın. Kaybeden hizip çıkınını toplar.',
            resolutionPool: [''], // dinamik: ayrılanın ismi reaksiyondan
            moraleAmount: -0.04,
            moraleDays: 4,
            fx: PetitionFx.vigil, // ayrılış — mum töreni havası
            estateMood: [(Estate.faithful, -0.06)],
          ),
          PetitionOption(
            label: 'İki tarafı uzlaştır',
            detail: 'Altın ve sabır gider. İki hizip aynı ayinde diz çöker.',
            resolutionPool: [
              '🔮 İki hizip ortak bir ayinde barıştı. Kapıdaki iki işaret yan yana kazındı.',
              '🔮 Uzlaşma sağlandı. {ad} karşı tarafın mumunu kendi eliyle yaktı.',
            ],
            goldDelta: -8,
            moraleAmount: 0.07,
            moraleDays: 6,
            fx: PetitionFx.cult,
            setsFlags: ['cult.united'],
            estateMood: [(Estate.faithful, 0.10), (Estate.artisans, -0.05)],
          ),
        ],
      ),
    ),

    // 🌾 Bereketli hasat (cropBlight "İlaçla" takibi) — fields.tended ödülü.
    _PetitionDef(
      (_) => false,
      0,
      const Petition(
        id: 'bountifulHarvest',
        petitioner: 'Müteşekkir çiftçiler',
        icon: '🌾',
        title: 'Toprak Cömert',
        tone: PetitionTone.warm,
        estate: Estate.laborers,
        note: '↩ Tarlaya vaktinde baktın',
        stakes: 'Bereketi köyle paylaş, ya da pazara çıkarıp keseye çevir.',
        bodyPool: [
          '“Efendim, mantarı söktüğümüz sıralar en gür veren yerler oldu; toprak sanki '
              'borcunu ödüyor. Başaklar diz boyu, saymaya çalıştım şaşırdım. Kutlayalım mı, '
              'satalım mı, sen bilirsin; ama bunu bilmeni istedim.”',
          '“{ad} benim. O gece ilaçlarken sana içimden kızmıştım, boşa masraf dedim. Bugün '
              'tarlaya girdim, başaklar omzuma değdi. Yanılmışım. Bu bereket senin '
              'kararın.”',
          '“Ambarın kapısı kapanmıyor, çuvalları dışarı diziyoruz. Çocuklar başakların '
              'içinde kaybolup gülüyor. Fazlasını köye mi dağıtalım, pazara mı çıkaralım? '
              'İkisi de ayıp değil.”',
        ],
        options: [
          PetitionOption(
            label: 'Hasadı paylaş',
            detail: 'Fazlası köye dağıtılır. Ambar dolar, kapılar dolar.',
            resolutionPool: [
              '🌾 Bereket köye dağıtıldı. Her kapının önüne bir çuval bırakıldı.',
              '🌾 Hasat paylaşıldı. {ad} en son kendi payını aldı, o da yarım çuvaldı.',
            ],
            foodDelta: 18,
            moraleAmount: 0.08,
            moraleDays: 5,
            fx: PetitionFx.harvestBounty,
            estateMood: [(Estate.laborers, 0.12), (Estate.hearth, 0.05)],
          ),
          PetitionOption(
            label: 'Fazlayı sat',
            detail: 'Bolluk pazara çıkar. Kese dolar, sofra ölçülü kalır.',
            resolutionPool: [
              '🌾 Fazla hasat pazarda satıldı. Kese doldu, ambar ölçüsünde kaldı.',
              '🌾 Çuvallar kervana yüklendi. {ad} son çuvalı yüklerken bir avuç ayırıp cebine koydu.',
            ],
            foodDelta: 6,
            goldDelta: 10,
            moraleAmount: 0.03,
            moraleDays: 3,
            fx: PetitionFx.harvestBounty,
            estateMood: [(Estate.artisans, 0.12), (Estate.laborers, 0.03)],
          ),
        ],
      ),
    ),

    // 🪵 Odun azalıyor (scene_fire erken uyarı — random çıkmaz).
    _PetitionDef(
      (_) => false,
      0,
      const Petition(
        id: 'woodLow',
        petitioner: 'Oduncular',
        icon: '🪵',
        title: 'Odun Azalıyor',
        tone: PetitionTone.ominous,
        estate: Estate.laborers,
        stakes: 'Altın verirsen ateş güvende; güvenirsen ocak riske girer.',
        bodyPool: [
          '“Efendim, odunluğun dibi göründü; kalanı iki geceyi ancak çıkarır. Balta sesini '
              'duyuyorsun, boş durmuyoruz; ama ıslak odun yanmaz, kurutmak zaman ister. '
              'Komşu köyde kuru odun var. Sen bilirsin.”',
          '“{ad} benim, ormanı ben kesiyorum. Yakın hattı bitirdik, artık uzağa gidiyoruz; '
              'bir yük odun için yarım gün yol var. Yetiştiririz de, bir gece açık verirsek '
              'ocak söner. Riski söylemiş olayım.”',
          '“Ocağın közü sabaha zar zor çıkıyor. Odunluğa girdim, ayağımın altında kabuk '
              'var, odun yok. Ya keseden bir şey ayır, ya bize güven; ikisi de olur, ama '
              'bugün karar ver.”',
        ],
        options: [
          PetitionOption(
            label: 'Komşudan odun getirt',
            detail: 'Kese açılır. Odunluk bu akşam dolar, ateş güvende.',
            resolutionPool: [
              '🪵 Komşudan iki araba kuru odun geldi. Odunluk ağzına kadar doldu.',
              '🪵 Odun satın alındı. {ad} istiflerken ilk kez rahat bir nefes verdi.',
            ],
            goldDelta: -6,
            woodDelta: 8,
            estateMood: [(Estate.laborers, 0.05)],
          ),
          PetitionOption(
            label: 'Oduncular yetiştirir',
            detail: 'Masraf yok. Balta hızlanır, ocak riske girer.',
            resolutionPool: [
              '🪓 Oduncular ormana erkenden indi. Ateşin közü sabaha zor çıktı.',
              '🪓 Köy oduncularına güvendi. {ad} o gece de balta sallamayı sürdürdü.',
            ],
            estateMood: [(Estate.laborers, 0.06)],
          ),
        ],
      ),
    ),

    // 🔥 Ateş söndü (scene_fire programatik tetikler — random çıkmaz).
    _PetitionDef(
      (_) => false,
      0,
      const Petition(
        id: 'fireDied',
        petitioner: 'Üşüyen köy',
        icon: '🔥',
        title: 'Ateş Söndü',
        tone: PetitionTone.ominous,
        estate: Estate.hearth,
        stakes: 'Acil odun altın ister; beklemek köyü bir gece daha karanlıkta bırakır.',
        bodyPool: [
          '“Efendim, ocak söndü. Külü karıştırdım, tek bir kor bulamadım. Çocuklar üç '
              'battaniyenin altında ve hâlâ titriyorlar. Ya bu gece komşudan odun '
              'getirteceğiz, ya bu geceyi karanlıkta geçireceğiz.”',
          '“Ateşçi sabaha kadar körükledi, olmadı; yakacak bir şey yoktu ki. Köyün '
              'ortasında kara bir daire kaldı, hepsi bu. İnsanlar oraya bakıp duruyor. Bir '
              'şey yap.”',
          '“{ad} benim, kırk yıldır bu ocağı ben yakarım; babam yakardı, o da babasından '
              'öğrenmiş. İlk kez söndü, utanıyorum. Odun bul bana, bu gece yeniden '
              'yakayım.”',
        ],
        options: [
          PetitionOption(
            label: 'Acil odun getirt',
            detail: 'Kese açılır, odun bu gece gelir. Ateşçi ocağı yeniden yakar.',
            resolutionPool: [
              '🪵 Odun gece yarısı geldi. {ad} ocağı yeniden yaktı; kimse yatmadı, hepsi izledi.',
              '🪵 Acil odun getirtildi. İlk alev çıktığında köy alkışladı.',
            ],
            goldDelta: -10,
            woodDelta: 8,
            estateMood: [(Estate.hearth, 0.06)],
          ),
          PetitionOption(
            label: 'Oduncuları bekle',
            detail: 'Masraf yok. Köy bir gece daha sönük ocağın başında bekler.',
            resolutionPool: [
              '🪵 Ocak sönük kaldı. Köy bu gece de kara daireye bakarak yattı.',
              '🪵 Beklendi. {ad} ocağın başında boşuna sabahladı.',
            ],
            moraleAmount: -0.03,
            moraleDays: 2,
            estateMood: [(Estate.hearth, -0.05)],
          ),
        ],
      ),
    ),

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
            detail: 'Sofradan bir pay ahıra gider. Sürü toparlanır, süt geri gelir.',
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
              'akıyor, ağıl ekşi kokuyor. Bunu bir kez görmüştüm; o yıl komşu köyün sürüsü '
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
            detail: 'Kese açılır. Ağıl yıkanır, otlar kaynar, hastalık sınırda kalır.',
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

    // ════════════════════════════════════════════════════════════════════════
    // OLGUN KÖY — yalnız YAŞLANMIŞ köyün sorabileceği şeyler
    // ════════════════════════════════════════════════════════════════════════
    // Bu bölümden önce katalogdaki en yüksek kapı `nüfus >= 8` idi: köy sekiz
    // cana ulaştığı an oyunun sorabileceği HER ŞEY havuzdaydı ve onuncu saatte
    // de aynı sorular dönüyordu. Aşağıdakiler köyün yaşını, rejimini, hane
    // dengesini, unuttuklarını ve kendi geçmişini kapı olarak kullanır —
    // yani ancak köy oraya VARIRSA sorulurlar (bkz. PetitionContext.mature).

    // 🪦 Kurucu kuşaktan kimse kalmadı — köy kendi başlangıcını hatırlamıyor.
    _PetitionDef(
      (c) => c.mature && !c.foundersAlive && c.years >= 2,
      1.1,
      Petition(
        id: 'lateFounders',
        petitioner: 'Köyün yaşlıları',
        icon: '🪦',
        title: 'İlk Ocağı Yakanlar',
        tone: PetitionTone.solemn,
        note: '↩ Kurucu kuşaktan kimse kalmadı',
        stakes: 'Bir gün emek ister; karşılığı köyün kendini hatırlaması.',
        bodyPool: [
          '“Efendim, adım {ad}. Dün çocuklar bana ilk ateşi kimin yaktığını sordu, '
              'cevap veremedim. Adları aklımda değil. Bu köyü kuranlardan geriye bir '
              'taş bile yok. Bir anıt istemiyorum illa — bir gün isteriz, adları '
              'okunsun, çocuklar duysun.”',
          '“Bu {mevsim} son kurucumuzu da toprağa verdik. Artık burada doğmamış '
              'kimse kalmadı. Yeni gelen soruyor: burayı kim kurdu? Bilen yok. '
              'Bir kere olsun toplanıp o adları söyleyelim, sonra unutursak unutalım.”',
        ],
        options: [
          PetitionOption(
            label: 'Anma günü ver',
            detail: 'Köy toplanır, kurucuların adı okunur. Bir günlük iş durur.',
            resolutionPool: [
              '🪦 Köy ateşin başında toplandı. {ad} adları tek tek okudu, kimse sözünü kesmedi.',
              '🪦 Anma günü verildi. Çocuklar ilk kez ocağı yakanların adını duydu.',
            ],
            moraleAmount: 0.05,
            moraleDays: 4,
            fx: PetitionFx.remembrance,
            setsFlags: ['founders.remembered'],
            estateMood: [(Estate.hearth, 0.16), (Estate.faithful, 0.08)],
          ),
          PetitionOption(
            label: 'Yaşayanlara bak',
            detail: 'Geçmiş geçmişte kalır. Bugünün işi bugüne yeter.',
            resolutionPool: [
              '🪦 Anma verilmedi. {ad} bir süre ateşe baktı, sonra kalkıp işine gitti.',
              '🪦 “Ölüyü kaldıran, diriyi doyurmaz” dendi. Adlar bir daha anılmadı.',
            ],
            moraleAmount: -0.04,
            moraleDays: 3,
            estateMood: [(Estate.hearth, -0.12)],
          ),
        ],
      ),
    ),

    // 🧵 Bir zanaat unutuldu — köyün elinden bir iş çıktı.
    _PetitionDef(
      (c) => c.mature && c.craftLost,
      1.2,
      Petition(
        id: 'lateLostCraft',
        petitioner: 'Elleri boş kalanlar',
        icon: '🧵',
        title: 'Kimsenin Bilmediği İş',
        tone: PetitionTone.solemn,
        note: '↩ Köy bir zanaatı unuttu',
        stakes: 'Öğrenmek altına ve bir cana mal olur; unutmak kalıcıdır.',
        bodyPool: [
          '“Efendim, adım {ad}. Babamın yaptığı işi bugün kimse yapamıyor. Aletleri '
              'duruyor, elimde duruyor, ama nasıl tutulduğunu bilen kalmadı. Beni '
              'dışarı yollayın, bir ustanın yanında durayım, öğrenip döneyim.”',
          '“Bu köy bir işi kaybetti. Kimse konuşmuyor ama hepimiz biliyoruz. '
              'Komşu kasabada o işi bilen var derler. Yol parası verirseniz gider, '
              'öğrenir, geri getiririm. Getiremezsem de gitmiş sayılmam ya.”',
        ],
        options: [
          PetitionOption(
            label: 'Yola çıkar (12★)',
            detail: 'Kese açılır. Öğrenmeye giden döner — bilgiyle döner.',
            resolutionPool: [
              '🧵 {ad} yola çıktı. Döndüğünde elinde yeni bir alet, aklında eski bir iş vardı.',
              '🧵 Kese açıldı. Köy, unuttuğu işi yeniden öğrenmeye birini yolladı.',
            ],
            goldDelta: -12,
            moraleAmount: 0.04,
            moraleDays: 3,
            estateMood: [(Estate.laborers, 0.14)],
            // Zincir: yolcu birkaç gün sonra döner (ya da dönmez).
            followUpId: 'craftReturn',
            followUpDelayDays: 4.0,
          ),
          PetitionOption(
            label: 'Kese kapalı',
            detail: 'O iş burada bitti. Köy bildiğiyle yetinir.',
            resolutionPool: [
              '🧵 {ad} aletleri sandığa kaldırdı. Sandık bir daha açılmadı.',
              '🧵 “Bilmediğimiz işi biz de bilmeyiz” dendi. Kimse itiraz etmedi, kimse sevinmedi.',
            ],
            moraleAmount: -0.05,
            moraleDays: 3,
            estateMood: [(Estate.laborers, -0.14)],
          ),
        ],
      ),
    ),

    // 🏰 Bir hane köyün gölgesine oturdu.
    _PetitionDef(
      (c) => c.mature && c.houseCount >= 2 && c.dominantSway >= 0.45,
      1.15,
      Petition(
        id: 'lateHouseShadow',
        petitioner: 'Küçük haneler',
        icon: '🏰',
        title: 'Meydanı Kendi Sayan Hane',
        tone: PetitionTone.ominous,
        note: '↩ Tek hane köyün nüfuzunu topladı',
        stakes: 'Frenlersen güçlü hane küser; bırakırsan köy tek sesli kalır.',
        bodyPool: [
          '“Efendim, adım {ad}. Bir hane var, adını söylemeyeyim, herkes biliyor. '
              'Kuyunun sırası onların, harmanın önü onların, meydanda söz onların. '
              'Biz de bu köydeyiz. Bir kere olsun bizim de sözümüz geçsin.”',
          '“Kimseyi suçlamıyorum. Ama çocuğum büyüyünce kime çalışacağını şimdiden '
              'biliyor. Bu köy bir hanenin çiftliği mi oldu? Değilse bunu bir '
              'gösterin, biz de inanalım.”',
        ],
        options: [
          PetitionOption(
            label: 'Meydanı böl',
            detail: 'Söz sırası hanelere eşit dağıtılır. Güçlü hane gücenir.',
            resolutionPool: [
              '🏰 Meydan yeniden bölündü. Büyük hane sustu ama kalkıp gitmedi.',
              '🏰 “Bu köy kimsenin çiftliği değil” dendi. {ad} o gece rahat uyudu.',
            ],
            moraleAmount: 0.04,
            moraleDays: 4,
            setsFlags: ['house.curbed'],
            estateMood: [(Estate.laborers, 0.16), (Estate.hearth, -0.10)],
          ),
          PetitionOption(
            label: 'Güçlüyle çalış',
            detail: 'Düzen bozulmaz. Büyük hane köyü taşımaya devam eder.',
            resolutionPool: [
              '🏰 Karar değişmedi. Büyük hane ertesi sabah meydanı yine kendi açtı.',
              '🏰 “Köyü taşıyanın sözü de ağır olur” dendi. {ad} bir daha gelmedi.',
            ],
            moraleAmount: -0.03,
            moraleDays: 3,
            setsFlags: ['house.blessed'],
            estateMood: [(Estate.hearth, 0.12), (Estate.laborers, -0.14)],
          ),
        ],
      ),
    ),

    // 📜 Kanunname kalınlaştı — kimse hepsini hatırlamıyor.
    _PetitionDef(
      (c) => c.mature && c.sealedLaws >= 6,
      1.0,
      Petition(
        id: 'lateThickCharter',
        petitioner: 'Genç kuşak',
        icon: '📜',
        title: 'Kimse Hepsini Bilmiyor',
        tone: PetitionTone.neutral,
        note: '↩ Altıdan fazla mühür',
        stakes: 'Okuma günü bir iş gününe mal olur; okumamak kanunu unutturur.',
        bodyPool: [
          '“Efendim, adım {ad}. Dün bir yasağı bilmediğim için azar işittim. '
              'Kanunname kalınlaşmış, ben okumayı da bilmem. Yılda bir kez '
              'toplanıp yüksek sesle okunsa, hepimiz duysak olmaz mı?”',
          '“Babam ne mühürlendiğini sayabiliyordu. Ben sayamıyorum. Sayamadığım '
              'şeye nasıl uyacağım? Meydanda okuyun, dinleyelim.”',
        ],
        options: [
          PetitionOption(
            label: 'Okuma günü kur',
            detail: 'Yılda bir gün kanunname meydanda okunur. Bir gün iş durur.',
            resolutionPool: [
              '📜 Meydanda kanunname okundu. {ad} ilk kez hepsini baştan sona duydu.',
              '📜 Okuma günü kuruldu. Kalabalık dağılırken kimse “bilmiyordum” demedi.',
            ],
            moraleAmount: 0.04,
            moraleDays: 3,
            setsFlags: ['charter.read'],
            estateMood: [(Estate.faithful, 0.08), (Estate.laborers, 0.08)],
          ),
          PetitionOption(
            label: 'Bilen bilir',
            detail: 'Kanun defterdedir. Merak eden gelip sorar.',
            resolutionPool: [
              '📜 Okuma günü verilmedi. Defter rafta kaldı, tozu {mevsim} boyu alınmadı.',
              '📜 “Yasayı bilmemek mazeret değil” dendi. {ad} başını salladı, çıktı.',
            ],
            moraleAmount: -0.03,
            moraleDays: 2,
            estateMood: [(Estate.laborers, -0.08)],
          ),
        ],
      ),
    ),

    // ✊ Sert rejim + huzursuzluk: biri konuşmayı göze aldı.
    _PetitionDef(
      (c) =>
          c.mature &&
          (c.regime == VillageRegime.ironTable ||
              c.regime == VillageRegime.sealedHand) &&
          c.unrest >= 0.35,
      1.3,
      Petition(
        id: 'lateDissent',
        petitioner: 'Sesini yükselten',
        icon: '✊',
        title: 'Konuşmayı Göze Alan',
        tone: PetitionTone.ominous,
        note: '↩ Sert rejim + huzursuzluk',
        stakes: 'Dinlersen otoriten çatlar; susturursan korku büyür.',
        bodyPool: [
          '“Efendim, adım {ad}. Bunu söylediğim için başıma bir iş gelebilir, '
              'biliyorum. Ama artık kimse yüksek sesle konuşmuyor. Meydanda iki kişi '
              'yan yana durmuyor. Köy sizden korkuyor — sizi sevmiyor, korkuyor. '
              'Aradaki farkı bilirsiniz.”',
          '“Bir şey istemeye gelmedim. Söylemeye geldim: bu köy sustu. Susan köy '
              'çalışır ama size bir daha hiçbir şey anlatmaz. Duymak istemezseniz '
              'çıkar giderim, gene susarım.”',
        ],
        options: [
          PetitionOption(
            label: 'Dinle',
            detail: 'Meydanda konuşmasına izin verilir. Huzursuzluk iner, otorite yumuşar.',
            resolutionPool: [
              '✊ {ad} meydanda konuştu. Kimse alkışlamadı ama kimse de kaçmadı.',
              '✊ Söz verildi. O akşam meydanda iki kişi yan yana durdu.',
            ],
            moraleAmount: 0.06,
            moraleDays: 4,
            setsFlags: ['dissent.heard'],
            estateMood: [(Estate.laborers, 0.18), (Estate.hearth, 0.06)],
            followUpId: 'dissentEcho',
            followUpDelayDays: 3.0,
          ),
          PetitionOption(
            label: 'Sustur',
            detail: 'Bir daha konuşmaz. Köy de konuşmaz.',
            resolutionPool: [
              '✊ {ad} susturuldu. Ertesi sabah meydan her zamankinden boştu.',
              '✊ Söz kesildi. Köy başını önüne eğdi ve işine gitti.',
            ],
            moraleAmount: -0.07,
            moraleDays: 5,
            setsFlags: ['dissent.silenced'],
            estateMood: [(Estate.laborers, -0.20)],
            followUpId: 'dissentSilence',
            followUpDelayDays: 3.0,
          ),
        ],
      ),
    ),

    // 🌾 Hür rejim + huzur: köy kendinden büyük bir iş istiyor.
    _PetitionDef(
      (c) =>
          c.mature &&
          (c.regime == VillageRegime.commune ||
              c.regime == VillageRegime.market) &&
          c.unrest <= 0.15 &&
          c.population >= 16,
      1.05,
      Petition(
        id: 'lateAmbition',
        petitioner: 'Köyün orta yaşlıları',
        icon: '🌾',
        title: 'Elimiz Boş Durmasın',
        tone: PetitionTone.warm,
        note: '↩ Hür rejim, huzurlu köy',
        stakes: 'Ambar boşalır; karşılığı köyün kendine güveni.',
        bodyPool: [
          '“Efendim, adım {ad}. Kimse aç değil, kimse küs değil — ve tam da bu '
              'yüzden geldim. Elimiz boş durmasın. Ambardan biraz verin, hep '
              'birlikte bir iş çıkaralım. Ne olduğu bile önemli değil, birlikte '
              'olsun yeter.”',
          '“Bu {mevsim} rahat geçti. Rahat geçen köy sonra birbirini yemeye başlar, '
              'bilirim. Şimdi bir iş kuralım da o güne kalmasın.”',
        ],
        options: [
          PetitionOption(
            label: 'Ambarı aç, işe koyul',
            detail: 'Köy imeceye durur. Yiyecek gider, hevesle döner.',
            resolutionPool: [
              '🌾 Ambar açıldı. Köy sabaha kadar çalıştı, kimse yorulduğunu söylemedi.',
              '🌾 İmece kuruldu. {ad} en son kalkan oldu.',
            ],
            foodDelta: -22,
            moraleAmount: 0.08,
            moraleDays: 5,
            fx: PetitionFx.festival,
            estateMood: [(Estate.laborers, 0.16), (Estate.hearth, 0.10)],
          ),
          PetitionOption(
            label: 'Ambar dursun',
            detail: 'Rahat günün kıymetini bil. Kimse zorlanmaz.',
            resolutionPool: [
              '🌾 Ambar açılmadı. Köy o {mevsim} boyunca rahat etti, biraz da sıkıldı.',
              '🌾 “Bugünün rahatı yarının ekmeği” dendi. {ad} kabul etti ama içi rahat etmedi.',
            ],
            moraleAmount: -0.02,
            moraleDays: 2,
            estateMood: [(Estate.laborers, -0.06)],
          ),
        ],
      ),
    ),

    // ⚔ İmparatorluk bir daha gelecek — köy hazırlık istiyor.
    _PetitionDef(
      (c) => c.mature && c.imperialVisits >= 2,
      1.2,
      Petition(
        id: 'lateImperialShadow',
        petitioner: 'İki kez vergi verenler',
        icon: '⚔',
        title: 'Yine Gelecekler',
        tone: PetitionTone.ominous,
        note: '↩ İmparatorluk iki kez uğradı',
        stakes: 'Hazırlık altına mal olur; hazırlıksızlık daha pahalıya.',
        bodyPool: [
          '“Efendim, adım {ad}. İki kez geldiler, iki kez verdik. Üçüncüde ne '
              'isteyeceklerini ikimiz de biliyoruz. Bu sefer kapıda hazır bekleyelim '
              'derim — kese hazır, söz hazır. Şaşırmış görünmek pahalıya patlıyor.”',
          '“Sancağı gördüğümüzde köyün ne yapacağını kimse bilmiyor. Geçen sefer '
              'çocuklar ağladı, adamlar donakaldı. Bir kararımız olsun.”',
        ],
        options: [
          PetitionOption(
            label: 'Keseyi hazır tut (15★)',
            detail: 'Bir pay ayrılır. Gelen heyet kapıda hazır bulur.',
            resolutionPool: [
              '⚔ Kese ayrıldı ve kaldırıldı. Köy artık sancağı görünce ne yapacağını biliyor.',
              '⚔ Hazırlık yapıldı. {ad} keseyi kendi eliyle saydı, iki kez saydı.',
            ],
            goldDelta: -15,
            moraleAmount: 0.03,
            moraleDays: 4,
            setsFlags: ['imperial.prepared'],
            estateMood: [(Estate.hearth, 0.10)],
          ),
          PetitionOption(
            label: 'Geldiklerinde düşünürüz',
            detail: 'Bugünden kese bağlanmaz. Gelen görülür.',
            resolutionPool: [
              '⚔ Hazırlık yapılmadı. Köy ufka bakmayı sürdürdü.',
              '⚔ “Gelmeden telaş olmaz” dendi. {ad} başını salladı, inanmadı.',
            ],
            moraleAmount: -0.04,
            moraleDays: 3,
            estateMood: [(Estate.hearth, -0.10)],
          ),
        ],
      ),
    ),

    // ⚖ Yıllar önceki kararların bugünkü faturası (ya da armağanı).
    _PetitionDef(
      (c) => c.years >= 3 && c.governanceLegacy.abs() >= 0.06,
      1.1,
      Petition(
        id: 'lateLegacy',
        petitioner: 'Uzun hafızalılar',
        icon: '⚖',
        title: 'Yıllar Önce Verdiğin Karar',
        tone: PetitionTone.solemn,
        note: '↩ Yönetişim mirası ağır bastı',
        stakes: 'Kabul etmek bedel ister; inkâr etmek hafızayı sertleştirir.',
        bodyPool: [
          '“Efendim, adım {ad}. Ben o gün buradaydım. Ne karar verdiğinizi '
              'hatırlıyorum, kimin ne dediğini de. Yıllar geçti ama bu köy '
              'unutmadı — iyisiyle kötüsüyle bugün hâlâ onun üstünde yaşıyoruz. '
              'Bir kez olsun ağzınızdan duymak isterim: doğru muydu?”',
          '“Çocuklar o hikâyeyi birbirine anlatıyor artık. Anlatırken sizi de '
              'anlatıyorlar. Nasıl anlatılacağına bugün karar verebilirsiniz.”',
        ],
        options: [
          PetitionOption(
            label: 'Sahiplen',
            detail: 'Karar senindi, arkasında durursun. Köy ne olduğunu bilir.',
            resolutionPool: [
              '⚖ Karar sahiplenildi. {ad} “ben de öyle hatırlıyordum” dedi, gitti.',
              '⚖ Geçmiş inkâr edilmedi. Köy o akşam kendi hikâyesini yüksek sesle anlattı.',
            ],
            moraleAmount: 0.05,
            moraleDays: 5,
            setsFlags: ['legacy.owned'],
            estateMood: [(Estate.faithful, 0.10), (Estate.hearth, 0.08)],
          ),
          PetitionOption(
            label: 'Geçmişi kapat',
            detail: 'O gün geçti. Bugünün işine bakılır.',
            resolutionPool: [
              '⚖ “O defter kapandı” dendi. {ad} bir şey demedi ama defteri o kapatmadı.',
              '⚖ Geçmiş konuşulmadı. Çocuklar hikâyeyi yine de birbirine anlattı.',
            ],
            moraleAmount: -0.04,
            moraleDays: 4,
            estateMood: [(Estate.faithful, -0.10)],
          ),
        ],
      ),
    ),

    // ════════════════════════════════════════════════════════════════════════
    // OLAY AĞAÇLARI — bir karar, günler sonra kapıya geri gelir
    // ════════════════════════════════════════════════════════════════════════
    // Aşağıdakiler rastgele ÇIKMAZ (canFire=false): yalnız bir önceki halkanın
    // seçeneği çağırır (followUpId). Zincir boyunca AYNI köylü konuşur — ilk
    // halkayı kim getirdiyse dönen de odur; ölmüş/gitmişse adı {giden} olarak
    // metinde kalır ve bu, ağacın kendi dalıdır.

    // ── AĞAÇ 1: unutulan zanaatın peşinden ──────────────────────────────────
    // lateLostCraft → [Yola çıkar] → craftReturn → [Atölye kur] → craftSchool
    //                                            └ [Kendine saklasın] → craftHoard

    _PetitionDef(
      (c) => false,
      0,
      Petition(
        id: 'craftReturn',
        petitioner: 'Yoldan dönen',
        icon: '🧵',
        title: 'Yolcu Geri Döndü',
        tone: PetitionTone.warm,
        note: '↩ Zanaat öğrenmeye yolladığın kişi',
        stakes: 'Atölye kereste ister; kurmazsan bilgi tek elde kalır.',
        bodyPool: [
          '“Efendim, döndüm. {giden} olarak gittim, aynı adam olarak dönmedim. '
              'Ustanın yanında bir mevsim durdum, elimi tuttu, gösterdi. Şimdi '
              'biliyorum. Ama bir başıma bilmek yetmez — bana bir dam altı verin, '
              'öğreteyim. Yoksa benimle birlikte bu iş yine gider.”',
          '“Geldim işte. Aletleri getirdim, ellerim de öğrendi. Köyün ortasında '
              'bir yer isterim, çıraklar gelsin otursun. Ya da istemem, kendi '
              'köşemde çalışırım — o zaman da bu iş benim işim olur, köyün değil.”',
        ],
        options: [
          PetitionOption(
            label: 'Atölye kur (18 kereste)',
            detail: 'Öğrenen öğretir. Zanaat köyün olur, tek elde kalmaz.',
            resolutionPool: [
              '🧵 Atölye kuruldu. {ad} ilk gün üç çırak aldı, üçü de akşama kadar kalktı gitmedi.',
              '🧵 Dam altı verildi. Unutulan iş, köyün ortasında yeniden görünür oldu.',
            ],
            woodDelta: -18,
            moraleAmount: 0.06,
            moraleDays: 4,
            setsFlags: ['craft.school'],
            clearsFlags: ['craft.lost'],
            estateMood: [(Estate.laborers, 0.18), (Estate.hearth, 0.06)],
            followUpId: 'craftSchool',
            followUpDelayDays: 3.0,
          ),
          PetitionOption(
            label: 'Kendi köşesinde çalışsın',
            detail: 'Kereste harcanmaz. Bilgi bir kişide, bir hanede kalır.',
            resolutionPool: [
              '🧵 Atölye kurulmadı. {ad} kendi köşesinde çalışıyor, kapısı kapalı.',
              '🧵 “Bilen bilsin” dendi. İş yapıldı ama kimse nasıl yapıldığını görmedi.',
            ],
            moraleAmount: -0.02,
            moraleDays: 2,
            setsFlags: ['craft.hoarded'],
            clearsFlags: ['craft.lost'],
            estateMood: [(Estate.laborers, -0.10), (Estate.hearth, 0.06)],
            followUpId: 'craftHoard',
            followUpDelayDays: 4.0,
          ),
        ],
      ),
    ),

    _PetitionDef(
      (c) => false,
      0,
      Petition(
        id: 'craftSchool',
        petitioner: 'Atölyenin çırakları',
        icon: '🪵',
        title: 'Atölyede Kavga Var',
        tone: PetitionTone.neutral,
        note: '↩ Atölye kuruldu',
        stakes: 'Sıra kurarsan iş yavaşlar; kurmazsan çıraklar dağılır.',
        bodyPool: [
          '“Efendim, atölye iyi de kalabalık. Herkes aynı anda öğrenmek istiyor, '
              'alet bir tane. Dün iki çırak birbirine girdi. Bir sıra koyun, kim '
              'ne zaman oturacak belli olsun.”',
          '“{ad} sabahtan akşama öğretiyor, kendi işine vakit kalmıyor. Böyle '
              'giderse ya usta yorulup bırakacak ya da çıraklar küsüp gidecek.”',
        ],
        options: [
          PetitionOption(
            label: 'Sıra defteri tut',
            detail: 'Herkes sırasını bilir. İş yavaşlar ama kimse küsmez.',
            resolutionPool: [
              '🪵 Sıra defteri açıldı. Atölyede bir daha kavga çıkmadı, iş de aksamadı.',
              '🪵 Sıra kuruldu. {ad} artık akşamları kendi işine dönebiliyor.',
            ],
            moraleAmount: 0.04,
            moraleDays: 3,
            setsFlags: ['craft.guild'],
            estateMood: [(Estate.laborers, 0.14)],
          ),
          PetitionOption(
            label: 'Güçlü olan otursun',
            detail: 'Sıra yok. En hevesli öğrenir, gerisi kendi yolunu bulur.',
            resolutionPool: [
              '🪵 Sıra konmadı. İki çırak ertesi hafta gelmedi, biri hiç dönmedi.',
              '🪵 “Öğrenmek isteyen sabreder” dendi. Atölyede üç kişi kaldı.',
            ],
            moraleAmount: -0.03,
            moraleDays: 3,
            estateMood: [(Estate.laborers, -0.10)],
          ),
        ],
      ),
    ),

    _PetitionDef(
      (c) => false,
      0,
      Petition(
        id: 'craftHoard',
        petitioner: 'Kapıda bekleyenler',
        icon: '🔒',
        title: 'Kapalı Kapının Önünde',
        tone: PetitionTone.ominous,
        note: '↩ Bilgi tek elde kaldı',
        stakes: 'Zorlarsan usta küser; bırakırsan iş bir hanenin malı olur.',
        bodyPool: [
          '“Efendim, o kapı bize açılmıyor. İş yapılıyor, para kazanılıyor, ama '
              'nasıl yapıldığını gören yok. Köy parasını veriyor, köy öğrenmiyor. '
              'Bu iş kimin oldu şimdi?”',
          '“{giden} yolculuğa köyün kesesiyle çıktı. Döndü, kapısını kapattı. '
              'Kimse hırsız demiyor — ama herkes düşünüyor.”',
        ],
        options: [
          PetitionOption(
            label: 'Kapıyı açtır',
            detail: 'Köyün kesesiyle öğrenilen, köye öğretilir. Usta gücenir.',
            resolutionPool: [
              '🔒 Kapı açıldı. {ad} öğretti ama o günden sonra kimseyle şakalaşmadı.',
              '🔒 “Bu köyün kesesi, bu köyün bilgisi” dendi. Kapı bir daha kapanmadı.',
            ],
            moraleAmount: 0.03,
            moraleDays: 3,
            setsFlags: ['craft.school'],
            clearsFlags: ['craft.hoarded'],
            estateMood: [(Estate.laborers, 0.16), (Estate.hearth, -0.12)],
          ),
          PetitionOption(
            label: 'Emeği kendinin olsun',
            detail: 'Öğrenen sahibidir. Hane zenginleşir, köy seyreder.',
            resolutionPool: [
              '🔒 Kapı kapalı kaldı. {ad-in} hanesi o mevsim gözle görülür biçimde zenginleşti.',
              '🔒 “Giden oydu, öğrenen oydu” dendi. Kapının önündekiler dağıldı.',
            ],
            moraleAmount: -0.05,
            moraleDays: 4,
            goldDelta: 8,
            estateMood: [(Estate.laborers, -0.18), (Estate.hearth, 0.10)],
          ),
        ],
      ),
    ),

    // ── AĞAÇ 2: konuşmayı göze alanın ardı ──────────────────────────────────
    // lateDissent → [Dinle]   → dissentEcho    → [Meclis geleneği] / [Bir kereydi]
    //             → [Sustur]  → dissentSilence → [Ara bul] / [Sertleş]

    _PetitionDef(
      (c) => false,
      0,
      Petition(
        id: 'dissentEcho',
        petitioner: 'Meydanda toplananlar',
        icon: '🗣',
        title: 'Bir Kez Konuşan, Bir Daha Konuşur',
        tone: PetitionTone.neutral,
        note: '↩ Sözü dinledin',
        stakes: 'Gelenek kurarsan otoriteni bölersin; kapatırsan umut kırılır.',
        bodyPool: [
          '“Efendim, geçen sefer {giden} konuştu ve gök başımıza yıkılmadı. '
              'Şimdi başkaları da söz istiyor. Ayda bir gün meydan bizim olsun, '
              'derdimizi söyleyelim, siz de dinleyin. Karar yine sizin.”',
          '“Bir kapı araladınız. Şimdi arkasında sıra var. Kapatabilirsiniz de '
              'ama o sıra dağılmaz, sadece görünmez olur.”',
        ],
        options: [
          PetitionOption(
            label: 'Meydan günü gelenek olsun',
            detail: 'Ayda bir gün söz köyün. Otoriten paylaşılır, huzursuzluk iner.',
            resolutionPool: [
              '🗣 Meydan günü kuruldu. İlk gün beş kişi konuştu, üçü ilk kez sesini duydu.',
              '🗣 Gelenek başladı. {ad} artık sırasını bekliyor — ama bekliyor.',
            ],
            moraleAmount: 0.07,
            moraleDays: 6,
            setsFlags: ['assembly.tradition'],
            estateMood: [(Estate.laborers, 0.20), (Estate.faithful, -0.06)],
          ),
          PetitionOption(
            label: 'Bir kereydi',
            detail: 'O gün geçti. Meydan yine sessiz.',
            resolutionPool: [
              '🗣 Meydan günü verilmedi. Sıra dağıldı ama kimse evine gitmedi, bir süre durdular.',
              '🗣 “Bir kereydi” dendi. {ad} başını salladı; bu sefer itiraz etmedi.',
            ],
            moraleAmount: -0.05,
            moraleDays: 4,
            estateMood: [(Estate.laborers, -0.14)],
          ),
        ],
      ),
    ),

    _PetitionDef(
      (c) => false,
      0,
      Petition(
        id: 'dissentSilence',
        petitioner: 'Susanların arasından biri',
        icon: '🤐',
        title: 'Susturduğunun Ardından',
        tone: PetitionTone.ominous,
        note: '↩ Sesi kestin',
        stakes: 'Ara bulmak otoriteni yumuşatır; sertleşmek korkuyu kalıcılaştırır.',
        bodyPool: [
          '“Efendim, {giden} o günden beri kimseyle konuşmuyor. Kapısından çıkıyor, '
              'işine gidiyor, dönüyor. Ama artık burada değil gibi. Köy de öyle. '
              'Bir şey söyleyin ona, ne olur.”',
          '“Sustu, evet. Hepimiz sustuk. Şimdi meydan sessiz, tarla sessiz, sofra '
              'sessiz. Bunu istediniz mi bilmiyorum ama olan bu.”',
        ],
        options: [
          PetitionOption(
            label: 'Ara bul',
            detail: 'Sofrana çağırırsın. Ses geri gelmez ama küskünlük dağılır.',
            resolutionPool: [
              '🤐 Sofraya çağrıldı. {ad} geldi, az konuştu, ama geldi.',
              '🤐 Ara bulundu. Ertesi sabah meydanda iki kişi yeniden yan yana durdu.',
            ],
            moraleAmount: 0.05,
            moraleDays: 4,
            clearsFlags: ['dissent.silenced'],
            estateMood: [(Estate.laborers, 0.14), (Estate.hearth, 0.06)],
          ),
          PetitionOption(
            label: 'Bir daha açılmasın',
            detail: 'Ders verilir. Köy uzun süre konuşmaz.',
            resolutionPool: [
              '🤐 Söz bir daha açılmadı. O {mevsim} boyunca meydanda kimse durmadı.',
              '🤐 “Konuşan bilir sonucunu” dendi. Köy duydu; kimse cevap vermedi.',
            ],
            moraleAmount: -0.08,
            moraleDays: 6,
            setsFlags: ['village.hushed'],
            estateMood: [(Estate.laborers, -0.22), (Estate.faithful, -0.06)],
          ),
        ],
      ),
    ),

  ];
