part of 'petition_system.dart';

/// DİLEKÇE KATALOĞU — TAKİP DİLEKÇELERİ (zincir) (6 dilekçe).
///
/// Katalog tek dosyada 2856 satırdı; bölümler zaten `═` bantlarıyla
/// ayrılmıştı, o sınırlar dosya sınırı yapıldı. SIRA KORUNUR:
/// [_kPetitionDefs] bu listeleri eski sırayla yayar.
final List<_PetitionDef> _kChainPetitions = [
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
      stakes:
          'Tapınak verirsen çemberin çatısı olur; sınırlarsan bir şey söner.',
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
          detail:
              'Altın ve taş gider. Çember köyün ortasına, çatı altına taşınır.',
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
          estateMood: [
            (Estate.faithful, 0.14),
            (Estate.hearth, -0.10),
            (Estate.artisans, -0.05),
          ],
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
      stakes:
          'Taraf tutarsan biri köyü terk eder; uzlaştırmak altın ve sabır ister.',
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
          // Çözüm metni boş (isim reaksiyondan gelir) → kâtibin satırı ayrıca
          // yazılır; yoksa günceye "İnançta Bölünme: Bir hizbi destekle"
          // diye kuru bir başlık düşerdi.
          annalPool: [
            'Bir hizip tutuldu. Kaybeden taraf çıkınını topladı, tapınağın '
                'kapısındaki işaretlerden biri kazındı.',
            'Taraf tutuldu. Sabahçılarla gececiler bir daha aynı duayı okumadı.',
            'Bölünme hükümle bitti. Kapıdaki iki işaretten biri silindi.',
          ],
          moraleAmount: -0.04,
          moraleDays: 4,
          fx: PetitionFx.vigil, // ayrılış; mum töreni havası
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
            'Bugün geçen kervanın yükünde kuru kereste var. Bedelini keseden ödersen '
            'bu gece ocağa iner. Sen bilirsin.”',
        '“{ad} benim, ormanı ben kesiyorum. Yakın hattı bitirdik, artık uzağa gidiyoruz; '
            'bir yük odun için yarım gün yol var. Yetiştiririz de, bir gece açık verirsek '
            'ocak söner. Riski söylemiş olayım.”',
        '“Ocağın közü sabaha zar zor çıkıyor. Odunluğa girdim, ayağımın altında kabuk '
            'var, odun yok. Ya keseden bir şey ayır, ya bize güven; ikisi de olur, ama '
            'bugün karar ver.”',
      ],
      options: [
        PetitionOption(
          label: 'Kervandan kereste satın al',
          detail:
              'Kese açılır. Kervanın kuru kerestesi ocağa iner, ateş güvende.',
          resolutionPool: [
            '🪵 Kervanın kuru kerestesi bedeli ödenerek odunluğa indirildi.',
            '🪵 Kuru kereste kervandan satın alındı. {ad} istiflerken ilk kez rahat bir nefes verdi.',
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
      stakes:
          'Acil odun altın ister; beklemek köyü bir gece daha karanlıkta bırakır.',
      bodyPool: [
        '“Efendim, ocak söndü. Külü karıştırdım, tek bir kor bulamadım. Çocuklar üç '
            'battaniyenin altında ve hâlâ titriyorlar. Kapıdaki kervanda kuru odun var; '
            'ya bedelini ödeyeceğiz, ya bu geceyi karanlıkta geçireceğiz.”',
        '“Ateşçi sabaha kadar körükledi, olmadı; yakacak bir şey yoktu ki. Köyün '
            'ortasında kara bir daire kaldı, hepsi bu. İnsanlar oraya bakıp duruyor. Bir '
            'şey yap.”',
        '“{ad} benim, kırk yıldır bu ocağı ben yakarım; babam yakardı, o da babasından '
            'öğrenmiş. İlk kez söndü, utanıyorum. Odun bul bana, bu gece yeniden '
            'yakayım.”',
      ],
      options: [
        PetitionOption(
          label: 'Kervandan odun satın al',
          detail:
              'Kese açılır, kervanın kuru odunu indirilir. Ateşçi ocağı yeniden yakar.',
          resolutionPool: [
            '🪵 Kervanın kuru odunu bedeli ödenerek indirildi. {ad} ocağı yeniden yaktı.',
            '🪵 Kervandan kuru odun alındı. İlk alev çıktığında köy alkışladı.',
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
];
