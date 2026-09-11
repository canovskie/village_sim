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

/// İçerik paketleri yalnız burada sıralanır. Her paket kendi kapısını,
/// ağırlığını ve ciddiyetini taşır; motor olay kimliği bilmez.
final List<_PetitionDef> _kPetitionDefs = [
  ..._kCorePetitions,
  ..._kLifecyclePetitions,
  ..._kPersonalPetitions,
  ..._kStoryPetitions,
  ..._kRegimePetitions,
];
