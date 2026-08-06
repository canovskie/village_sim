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

/// Bölümler ayrı part dosyalarında; burası yalnız SIRAYI tutar.
final List<_PetitionDef> _kPetitionDefs = [
  ..._kCorePetitions,
  ..._kEstatePetitions,
  ..._kLawPetitions,
  ..._kFactionPetitions,
  ..._kChainPetitions,
  ..._kHerdPetitions,
  ..._kMaturePetitions,
  ..._kTreePetitions,
];
