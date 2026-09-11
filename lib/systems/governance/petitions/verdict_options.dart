part of '../petition_system.dart';

/// Aynı kanun kapıları ilk sunumda, kuyrukta ve kayıt yüklemede uygulanır.
Petition crimeVerdictFor(Set<String> sealed) {
  var p = PetitionSystem.requireById(PetitionIds.crimeVerdict);
  // KÜREK CEZASI (NİZAM) — yürürlükteyse yargıya beşinci bir hüküm açılır:
  // mahkûm sürülmez ya da idam edilmez, taş ocağına koşulur (köy taş kazanır,
  // bir el eksilmez). Emek ekseninin sert ama üretken hükmü.
  if (sealed.contains('nizam.labor')) {
    p = p.withExtraOption(
      const PetitionOption(
        label: 'Kürek cezasına yolla',
        detail:
            '{suçlu} zindana atılır, taş ocağında çalıştırılır. Köy taş '
            'kazanır; bir el de eksilmez.',
        resolutionPool: [
          '⛓ {suçlu} taş ocağına koşuldu. Kürek sesi meydana kadar geliyor.',
          '⛓ Hüküm: kürek. {suçlu} borcunu taşla ödeyecek.',
          '⛓ {suçlu} zindanı boyladı; sabah ilk taş ocağa indi.',
        ],
        moraleAmount: 0.02,
        moraleDays: 3,
        fx: PetitionFx.crimeLabor,
        estateMood: [(Estate.laborers, 0.06), (Estate.faithful, -0.08)],
      ),
    );
  }
  // TÖVBE MEYDANI (DERGÂH) — kılıcın karşılığı. Fail ne sürülür ne dövülür:
  // günahını meydanda söyler. Affın mekanik bedeli olan bağış sayacını
  // ARTIRMAZ (bkz. [_sentenceToPenance]); caydırıcılığı utançtan gelir.
  if (sealed.contains('dergah.penance')) {
    p = p.withExtraOption(
      const PetitionOption(
        label: 'Tövbeye çağır',
        detail:
            '{suçlu} günahını meydanda, köyün önünde söyler. Ceza kesilmez; '
            'bedel utançtır. Af gibi düzeni gevşetmez.',
        resolutionPool: [
          '🙏 {suçlu} meydana çıkarıldı. Günahını kendi ağzıyla söyleyecek.',
          '🙏 Hüküm: tövbe. {suçlu} bedelini köyün gözü önünde ödeyecek.',
          '🙏 {suçlu} tövbeye çağrıldı; meydan sessizce doldu.',
        ],
        moraleAmount: 0.03,
        moraleDays: 3,
        fx: PetitionFx.crimePenance,
        estateMood: [
          (Estate.faithful, 0.10),
          (Estate.hearth, -0.06),
          (Estate.artisans, -0.04),
        ],
      ),
    );
  }
  // SÜRGÜN FERMANI (NİZAM) — mühürlü değilse köy kimseyi yola vuramaz.
  // Hane sürgünü zaten bu fermanı şart koşuyordu (bkz. house_action.gateFor);
  // yargı da aynı kapıdan geçsin, yoksa aynı hüküm bir kapıda yasak bir
  // kapıda serbest olurdu.
  if (!sealed.contains('nizam.exile')) {
    p = p.without(const {PetitionFx.crimeExile});
  }
  return p;
}
