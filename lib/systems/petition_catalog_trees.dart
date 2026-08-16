part of 'petition_system.dart';

/// DİLEKÇE KATALOĞU — OLAY AĞAÇLARI (5 dilekçe).
///
/// Katalog tek dosyada 2856 satırdı; bölümler zaten `═` bantlarıyla
/// ayrılmıştı, o sınırlar dosya sınırı yapıldı. SIRA KORUNUR:
/// [_kPetitionDefs] bu listeleri eski sırayla yayar.
final List<_PetitionDef> _kTreePetitions = [
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
      const Petition(
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
              'biliyorum. Ama bir başıma bilmek yetmez; bana bir dam altı verin, '
              'öğreteyim. Yoksa benimle birlikte bu iş yine gider.”',
          '“Geldim işte. Aletleri getirdim, ellerim de öğrendi. Köyün ortasında '
              'bir yer isterim, çıraklar gelsin otursun. Ya da istemem, kendi '
              'köşemde çalışırım; o zaman da bu iş benim işim olur, köyün değil.”',
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
      const Petition(
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
      const Petition(
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
              'Kimse hırsız demiyor; ama herkes düşünüyor.”',
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
      const Petition(
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
              '🗣 Gelenek başladı. {ad} artık sırasını bekliyor; ama bekliyor.',
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
      const Petition(
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
