part of '../petition_system.dart';

/// Sahne tarafından doğrudan çağrılan yaşam kararları.
///
/// Bunlar rastgele gündem içeriği değildir: ateş ve evlilik sistemlerinin
/// tamamlanması için gereken karar yüzeyleridir. `canFire` kapıları bu yüzden
/// kapalıdır; ilgili sahne doğru anda `PetitionSystem.requireById` ile çağırır.
final List<_PetitionDef> _kLifecyclePetitions = [
  _PetitionDef(
    (_) => false,
    0,
    const Petition(
      id: PetitionIds.woodLow,
      petitioner: 'Oduncular',
      icon: '🪵',
      title: 'Odun Azalıyor',
      tone: PetitionTone.ominous,
      estate: Estate.laborers,
      stakes:
          'Kapıdaki yük hemen gelir; dış pazara giden ulaksa zamanında dönerse ocağı kurtarır.',
      bodyPool: [
        '“Efendim, odunluğun dibi göründü; kalanı iki geceyi ancak çıkarır. Balta sesini '
            'duyuyorsun, boş durmuyoruz; ama ıslak odun yanmaz, kurutmak zaman ister. '
            'Kapıda kervan varsa yükünü sorarız; yoksa pazara ulak çıkarırız. Ulak '
            'dönene kadar közü bizim tutmamız gerekecek. Sen bilirsin.”',
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
          presence: DecisionPresence.activeCaravan,
          estateMood: [(Estate.laborers, 0.05)],
        ),
        PetitionOption(
          label: 'Dış pazara ulak gönder',
          detail:
              'Bir köylü keseyle yola çıkar. Kereste yaklaşık yarım gün sonra gelir.',
          resolutionPool: [
            '🛤 {ad} dış pazara kereste almaya gönderildi; odun henüz ambarda değil.',
            '🛤 Kese {ad-in} eline verildi. Köy, pazar yolundan dönüşünü bekliyor.',
          ],
          goldDelta: -5,
          process: DecisionProcessSpec(
            kind: DecisionProcessKind.marketWoodRun,
            title: 'Pazar yolu',
            departureText: 'Dış pazara kereste almaya gidiyor',
            completionText:
                '🪵 Pazar ulağı kuru keresteyle döndü; yük ambara indirildi.',
            completionAnnal:
                'Dış pazara gönderilen ulak kereste yüküyle köye döndü.',
            durationDays: 0.55,
            woodOnComplete: 10,
          ),
          estateMood: [(Estate.laborers, 0.04)],
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
    gravity: PetitionGravity.personal,
  ),

  // 🔥 Ateş söndü (scene_fire programatik tetikler — random çıkmaz).
  _PetitionDef(
    (_) => false,
    0,
    const Petition(
      id: PetitionIds.fireDied,
      petitioner: 'Üşüyen köy',
      icon: '🔥',
      title: 'Ateş Söndü',
      tone: PetitionTone.ominous,
      estate: Estate.hearth,
      stakes:
          'Acil odun altın ister; beklemek köyü bir gece daha karanlıkta bırakır.',
      bodyPool: [
        '“Efendim, ocak söndü. Külü karıştırdım, tek bir kor bulamadım. Çocuklar üç '
            'battaniyenin altında ve hâlâ titriyorlar. Kapıda kervan varsa yükünü '
            'alabiliriz; yoksa iki kişiyi gece pazarına koştururuz. Her ikisinin de '
            'bedeli var; beklemekse soğuğun bedeli.”',
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
          presence: DecisionPresence.activeCaravan,
          estateMood: [(Estate.hearth, 0.06)],
        ),
        PetitionOption(
          label: 'Gece pazarına iki kişi gönder',
          detail:
              'Altın şimdi çıkar; iki köylü acil yakacakla gün doğmadan döner.',
          resolutionPool: [
            '🏃 İki köylü gece pazarına koştu. Sönük ocak dönüş yolunu bekliyor.',
            '🏃 Kese hazırlandı; {ad} yanına bir yol arkadaşı alıp karanlığa çıktı.',
          ],
          goldDelta: -8,
          process: DecisionProcessSpec(
            kind: DecisionProcessKind.emergencyWoodRun,
            title: 'Gece pazarı',
            departureText: 'Acil yakacak için gece pazarına gidiyor',
            completionText:
                '🔥 Gece pazarından yakacak geldi; odun ocağın yanına taşındı.',
            completionAnnal:
                'Gece pazarına gönderilenler yakacakla dönüp ocağı kurtardı.',
            durationDays: 0.35,
            woodOnComplete: 9,
          ),
          moraleAmount: -0.01,
          moraleDays: 1,
          estateMood: [(Estate.hearth, 0.03)],
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
    gravity: PetitionGravity.critical,
  ),

  _PetitionDef(
    (c) => false,
    0.0,
    const Petition(
      id: PetitionIds.villageWedding,
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
    gravity: PetitionGravity.communal,
  ),
];
