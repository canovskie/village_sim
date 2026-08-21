part of 'petition_system.dart';

/// DİLEKÇE KATALOĞU — TEMEL DİLEKÇELER (3 dilekçe).
///
/// Katalog tek dosyada 2856 satırdı; bölümler zaten `═` bantlarıyla
/// ayrılmıştı, o sınırlar dosya sınırı yapıldı. SIRA KORUNUR:
/// [_kPetitionDefs] bu listeleri eski sırayla yayar.
final List<_PetitionDef> _kCorePetitions = [
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
      note: '↩ {suç} · {hal}',
      stakes:
          'Merhamet cesaret verir, sertlik korku salar. İkisinin de bedeli var.',
      bodyPool: [
        '“Gözümle gördüm efendim. {suçlu} yaptı, inkâr edecek hâli yok; '
            'kolundan tuttuğumuzda hâlâ eli titriyordu. {sabıka} Şimdi meydanda '
            'diz çökmüş bekliyor. Ne dersen o olur; ama {köy} de bekliyor, '
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
          detail:
              '{suçlu} serbest kalır. Köy adaletsizlik hisseder; suça cesaret artar.',
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
          detail:
              '{suçlu} teşhir edilir: günlerce iş göremez, köy düzeni görür.',
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
          detail:
              'En sert hüküm: {suçlu} halkın önünde infaz edilir. Köyü dehşet sarar.',
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
            'köylü köylünün yüzüne bakmıyor. Üç kere hesap tutmadı, üç kere de fail '
            'bulunamadı. Böyle giderse burada kimse rahat uyuyamaz.”',
        '“Bir şey oluyor bu köyde ve kimse görmüyor. Ya da görüyor da '
            'söylemiyor. Bize bir düzen lazım efendim; göz lazım. Yoksa '
            'birbirimizden şüphelenmeye başlayacağız, o da bizi bitirir.”',
        '“Malımız gidiyor, sesimiz çıkmıyor. Sen bize bir yol göster: ya bir '
            'göz koy başımıza, ya da rahatımıza bakalım da olan olsun.”',
      ],
      options: [
        PetitionOption(
          label: 'Gece nöbeti kur',
          detail:
              'Köy nöbet tutar: suç belirgin biçimde azalır, ama uykusuz köylü yorulur.',
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
          detail:
              'Devriyeye ek pay ayrılır. Bedeli altın; nöbetin yorgunluğu yok.',
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
          detail:
              'Hiçbir şey yapılmaz. Köy tedirgin kalır, suç beslenmeye devam eder.',
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
            'canını al. Bir gün mühlet vermişler. {köy} bekliyor; ama boş bir '
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
];
