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

  /// KÖYÜN ADI, Türkçe ekiyle — "Pınarbaşı'na", "Pınarbaşı'nın".
  ///
  /// Havuzlu metinlerde `{köy-e}` yer tutucusu kullanılır; bu yardımcı, havuzu
  /// olmayan tek cümlelik yerler (bildirim başlığı, kronik satırı) içindir.
  /// Naif `'$_villageName\'e'` yapıştırması ünlü uyumunu bozar.
  ///
  /// KURAL — adı KİM söylerse o anlamlı: köylü kendi yurduna "köy" der, adını
  /// söyleyen DIŞARIDANDIR (tüccar, vergici, göçmen, elçi) ya da an TÖRENSELDİR
  /// (kuruluş, kademe, yemin, vakayiname). Her cümleye ad sıkıştırmak metni
  /// makineleştirir; ad seyrek geçtiği için ağırlığını korur.
  String _villageWith(Suffix s) => withSuffix(_villageName, s);

  /// Bir dilekçenin metin tohumu: gün + dilekçe kimliği. Aynı gün aynı dilekçe
  /// → aynı varyant (modalı kapatıp açınca metin değişmesin).
  int _petitionSeed(Petition p) => _stableSeed(p.id, _dayCount);

  int _stableSeed(String key, int day) => (key.hashCode ^ (day * 2654435761)) &
      0x7fffffff;
}
