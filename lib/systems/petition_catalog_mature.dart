part of 'petition_system.dart';

/// DİLEKÇE KATALOĞU — OLGUN KÖY (8 dilekçe).
///
/// Katalog tek dosyada 2856 satırdı; bölümler zaten `═` bantlarıyla
/// ayrılmıştı, o sınırlar dosya sınırı yapıldı. SIRA KORUNUR:
/// [_kPetitionDefs] bu listeleri eski sırayla yayar.
final List<_PetitionDef> _kMaturePetitions = [
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
      const Petition(
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
              'taş bile yok. Bir anıt istemiyorum illa; bir gün isteriz, adları '
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
      const Petition(
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
            detail: 'Kese açılır. Öğrenmeye giden döner; bilgiyle döner.',
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
      const Petition(
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
      const Petition(
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
      const Petition(
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
              'yan yana durmuyor. Köy sizden korkuyor; sizi sevmiyor, korkuyor. '
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
      const Petition(
        id: 'lateAmbition',
        petitioner: 'Köyün orta yaşlıları',
        icon: '🌾',
        title: 'Elimiz Boş Durmasın',
        tone: PetitionTone.warm,
        note: '↩ Hür rejim, huzurlu köy',
        stakes: 'Ambar boşalır; karşılığı köyün kendine güveni.',
        bodyPool: [
          '“Efendim, adım {ad}. Kimse aç değil, kimse küs değil; ve tam da bu '
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
      const Petition(
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
              'derim; kese hazır, söz hazır. Şaşırmış görünmek pahalıya patlıyor.”',
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
      const Petition(
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
              'unutmadı; iyisiyle kötüsüyle bugün hâlâ onun üstünde yaşıyoruz. '
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

];
