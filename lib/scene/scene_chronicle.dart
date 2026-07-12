part of '../main.dart';

/// Vakanüvis — köyün kalıcı hikâye güncesi (kronik) + başarım/dönüm noktası
/// sistemi. [[project_staged_events]] Faz 4: sahnelenmiş olayların 5. evresi
/// burada toplanır. Düz toast yerine kalıcı, kategorize, tek-seferlik anılar.
///
/// İki yazım yolu:
///   _chronicle(text, icon:…)            → sıradan günce satırı
///   _award(id, title, icon)             → tek-seferlik başarım (milestone:true)
///
/// Başarımlar iki kaynaktan gelir: durum-taraması (`_tickAchievements`: nüfus,
/// ilk binalar, yıl dönümleri) + olay kancaları (ilk düğün/doğum/veda/afet/bereket
/// → ilgili sahne dosyaları `_award` çağırır).
extension _SceneChronicle on _VillageSceneState {
  /// Günceye bir satır yazar — gün otomatik damgalanır.
  void _chronicle(String text, {String icon = '📜', bool milestone = false}) {
    _storyLog.add(ChronicleEntry(
        day: _dayCount, icon: icon, text: text, milestone: milestone));
  }

  /// Bir KÖYLÜNÜN kişisel yaşam öyküsüne olay ekler — gün damgalı. Panelde
  /// zaman çizelgesi olarak okunur (bireye bağlanma). Köy-çapı `_chronicle`'ın
  /// birey karşılığı.
  void _lifeEvent(VillagerEntity v, String text,
      {String icon = '•', bool milestone = false}) {
    v.life.add(ChronicleEntry(
        day: _dayCount, icon: icon, text: text, milestone: milestone));
  }

  /// Yaşam-evresi geçişlerini yakalar (lifeStage türetilmiş — önceki evreyi
  /// izleyip değişince yaşam öyküsüne yazar). Throttle'lı; scene_tick'ten.
  void _tickLifeStory(double dt) {
    _lifeStoryScan -= dt;
    if (_lifeStoryScan > 0) return;
    _lifeStoryScan = 1.0;
    for (final v in _villagers) {
      if (v.isDying) continue;
      final now = v.lifeStage;
      final prev = v.lastStageSeen;
      v.lastStageSeen = now;
      if (prev == null || prev == now) continue; // ilk tarama / değişim yok
      switch (now) {
        case LifeStage.youth:
          _lifeEvent(v, 'Gençliğe adım attı', icon: '🌱');
        case LifeStage.adult:
          _lifeEvent(v, 'Yetişkin oldu — ${v.type.displayName} oldu',
              icon: '💪', milestone: true);
        case LifeStage.elder:
          _lifeEvent(v, 'Yaşlılığın huzuruna erdi', icon: '🧓',
              milestone: true);
        case LifeStage.child:
          break; // geriye geçiş olmaz
      }
    }
  }

  /// Tek-seferlik başarım: daha önce kazanılmadıysa kronik (vurgulu) + 🏆 toast
  /// + köy sevinci. Aynı id bir daha tetiklenmez (kalıcı).
  void _award(String id, String title, String icon) {
    if (_achievedMilestones.contains(id)) return;
    _achievedMilestones.add(id);
    _chronicle(title, icon: icon, milestone: true);
    _showNotification('🏆 $title');
    _feelVillage(NpcEmotion.joy, 6, 0.05);
  }

  /// Nüfus eşikleri (kümülatif başarım).
  static const List<int> _kPopThresholds = [10, 20, 30, 50, 75, 100];

  /// İlk kez dikildiğinde başarım veren binalar — (tip, başlık, ikon).
  static const List<(BuildingType, String, String)> _kFirstBuildings = [
    (BuildingType.well, 'İlk kuyu kazıldı', '🪣'),
    (BuildingType.market, 'İlk pazar kuruldu', '🛒'),
    (BuildingType.tavern, 'İlk taverna açıldı', '🍺'),
    (BuildingType.church, 'İlk kilise dikildi', '⛪'),
  ];

  /// Durum-taraması başarımları — scene_tick'in ana döngüsünden çağrılır
  /// (eski `_tickMilestones` yerine). _award idempotent olduğundan her tick
  /// güvenle taranır.
  void _tickAchievements() {
    // Nüfus — köylü + tüm işçi tipleri.
    final pop = _villagers.length +
        _farmers.length +
        _woodcutters.length +
        _miners.length +
        _fishers.length +
        _builders.length +
        _shepherds.length +
        _florists.length;
    for (final t in _kPopThresholds) {
      if (pop >= t) _award('pop_$t', 'Köy $t kişiye ulaştı', '🎉');
    }

    // İlk binalar.
    for (final (type, title, icon) in _kFirstBuildings) {
      if (_buildings.any((b) => b.type == type)) {
        _award('build_${type.name}', title, icon);
      }
    }

    // Yıl dönümü — 1 yıl = 4 mevsim × kDaysPerSeason gün. Tamamlanan her yıl bir
    // dayanıklılık başarımı (köy bir yılı daha atlattı).
    final year = (_dayCount - 1) ~/ (kDaysPerSeason * Season.values.length);
    if (year >= 1) {
      _award('year_$year', '$year. yıl tamamlandı — köy hâlâ ayakta', '🗓️');
    }
  }
}
