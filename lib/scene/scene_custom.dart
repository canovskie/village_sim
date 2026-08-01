part of '../main.dart';

// ── Âdet dersi — rol başına BİR kez, öğretici ton ────────────────────────────
// Oyuncu ilk kez âdete aykırı bir atama yaptığında köy ne dediğini AÇIK AÇIK
// söyler. İkinci kez tekrarlanmaz: bu bir kural değil, bir huy — ısrar ederse
// dırdıra döner ve oyuncuyu kararından caydırmak istiyormuş gibi okunur.
const List<String> _kCustomBreachAxePool = [
  '🪓 {ad} baltayı eline aldı. Köyde bu işi erkekler yapar; kimse engellemiyor '
      'ama iş ağır ilerleyecek.',
  '🪓 Balta {ad-in} beline göre değil. Köyün usulü başka; yine de kesecekse '
      'geç keser.',
  '🪓 {ad} ormana yollandı. Bu köyde odunu erkek keser derler — söz senin, '
      'ama harman geç dolar.',
];

const List<String> _kCustomBreachHeavyPool = [
  '⛏️ {ad} bu işin kadrosunda değil. Köy böyle bilmez; iş yürür ama ağır yürür.',
  '⛏️ Kazmayı {ad-e} verdin. Usul bu değil derler; yine de kimse elinden almaz.',
  '⛏️ {ad} ağır işe koşuldu. Köyün âdeti başkasını yakıştırır — iş sarkacak.',
];

const List<String> _kCustomBreachBasketPool = [
  '🧺 {ad} sepeti aldı. Köy bu işi kadınlara yakıştırır; iş görülür ama ağırdan.',
  '🧺 Sepet {ad-in} elinde tuhaf duruyor derler. Kimse karışmaz, yalnız yavaş olur.',
  '🧺 {ad} toplamaya çıktı. Usul böyle değil derler — söz yine senin.',
];

/// KÖYÜN ÂDETİ — sahne tarafı.
///
/// Yargının kendisi saf ve testli: [VillageCustom]. Bu dosya yalnız o yargının
/// köyde DUYULAN karşılığını üretir — öğretici bir cümle, atanan köylünün
/// keyifsizliği ve çevredekilerin dönüp bakması.
///
/// Bilinçli olarak KÜÇÜK: oyun no-fail ve cozy (bkz. feedback_chill_gameplay).
/// Aykırı atama bir ceza değil, bir sürtünme. Oyuncu ısrar ederse köy alışır.
extension _SceneCustom on _VillageSceneState {
  /// Oyuncu [v]'ye âdete aykırı bir iş verdi — köy tepki versin.
  /// Yalnız [_assignVillagerJob] çağırır.
  void _reactToCustomBreach(VillagerEntity v, JobRole role) {
    // 1) ÖĞRETİCİ CÜMLE — rol başına bir kez.
    if (_customLessons.add(role.name)) {
      _showNotification(Voice.say(
          _breachPoolFor(role), _voice(v, seed: _stableSeed(role.name, _dayCount))));
    }

    // 2) ATANAN KÖYLÜ — alışık olmadığı işe girmenin huzursuzluğu. Kalıcı moral
    //    değil küçük bir çentik: köylü işi yapar, sadece keyifle yapmaz.
    v.feel(NpcEmotion.wonder, 2.6, moodDelta: -0.05);
    v.morale = (v.morale - 0.03).clamp(0.0, 1.0);

    // 3) ÇEVRE — görenler dönüp bakar. Bu, "köy konuşuyor"un gövde dili
    //    karşılığı; baş üstü ikon yok (bkz. feedback_event_animation).
    _reactNearby(v.gridX, v.gridY, 7.0, NpcEmotion.wonder, 2.0,
        moodDelta: -0.01);
  }

  /// Aykırılığın hangi âdete dokunduğuna göre havuz — balta/ağır iş/sepet.
  List<String> _breachPoolFor(JobRole role) => switch (role) {
        JobRole.woodcutter => _kCustomBreachAxePool,
        JobRole.miner || JobRole.fisher => _kCustomBreachHeavyPool,
        _ => _kCustomBreachBasketPool,
      };
}
