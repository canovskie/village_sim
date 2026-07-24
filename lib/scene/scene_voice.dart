part of '../main.dart';

/// Sahnenin metin ağzı — bir cümlenin dokunacağı köy gerçeklerini toplar.
///
/// Oyunun tüm anlatı metinleri havuzludur (bkz. `lib/text/voice.dart`): varyant
/// seçimi + `{ad}`, `{ad-in}`, `{meslek}`, `{hane}`, `{mevsim}` yer tutucuları.
/// Bu dosya, o havuzların köye bağlandığı tek nokta.
extension _SceneVoice on _VillageSceneState {
  /// [v] köylüsünün ağzından konuşmak için bağlam. [seed] verilmezse gün + isim
  /// üzerinden TÜRETİLİR — yani aynı gün aynı köylü için aynı cümle çıkar,
  /// kayıt/yükleme sonrası metin değişmez (rastgele Random kullanılmaz).
  VoiceCtx _voice(
    VillagerEntity? v, {
    VillagerEntity? other,
    int? seed,
    Map<String, String> extra = const {},
  }) {
    return VoiceCtx(
      seed: seed ?? _stableSeed(v?.name ?? '', _dayCount),
      name: v?.name,
      other: other?.name,
      profession: v == null || !v.hasProfession ? null : v.type.displayName,
      house: v == null || v.surname.isEmpty ? null : v.surname,
      estate: v == null ? null : estateOfVillager(v.type, v.lifeStage).label,
      village: _villageName,
      season: _season,
      day: _dayCount,
      extra: extra,
    );
  }

  /// Bir dilekçenin metin tohumu: gün + dilekçe kimliği. Aynı gün aynı dilekçe
  /// → aynı varyant (modalı kapatıp açınca metin değişmesin).
  int _petitionSeed(Petition p) => _stableSeed(p.id, _dayCount);

  int _stableSeed(String key, int day) => (key.hashCode ^ (day * 2654435761)) &
      0x7fffffff;
}
