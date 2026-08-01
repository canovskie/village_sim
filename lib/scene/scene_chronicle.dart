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
///
/// ÜSLUP — kayıt tutan bir kâtip yazar, anlatıcı değil. Kısa, düz cümle. Duyguyu
/// taşıyan sıfat yok; kuruluğun kendisi duygudur:
///     "Gün 41. İlyas örsü bıraktı. Ocak soğudu."
/// Tekrar eden satırlar HAVUZDUR (bkz. `lib/text/voice.dart`) — aynı olay ikinci
/// kez yazıldığında yıllık aynı kelimeleri kullanmaz.
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
      final ctx = _voice(v);
      switch (now) {
        case LifeStage.youth:
          _lifeEvent(v, Voice.say(_kYouthLines, ctx), icon: '🌱');
        case LifeStage.adult:
          _lifeEvent(v, Voice.say(_kAdultLines, ctx),
              icon: '💪', milestone: true);
        case LifeStage.elder:
          _lifeEvent(v, Voice.say(_kElderLines, ctx), icon: '🧓',
              milestone: true);
        case LifeStage.child:
          break; // geriye geçiş olmaz
      }
    }
  }

  /// Yaşam-evresi satırları — köylünün KENDİ güncesi, özne zaten o; ad tekrar
  /// edilmez. Kuru kayıt: ne oldu, ardından ne değişti.
  static const List<String> _kYouthLines = [
    'Boy attı. Sesi kalınlaştı.',
    'Çocukluğu bitti. İşe koşuldu.',
    'Oyunu bıraktı, aleti eline aldı.',
  ];
  static const List<String> _kAdultLines = [
    'Yetişkin sayıldı. Artık {meslek}.',
    '{meslek} oldu. Kendi ekmeğini kazanıyor.',
    'Reşit oldu. Köyün {meslek} defterine yazıldı.',
  ];
  static const List<String> _kElderLines = [
    'Yaşlandı. İşi genç ellere bıraktı.',
    'Beli büküldü. Sözü ağırlaştı.',
    'Yaşlılar arasına katıldı. {mevsim} onu evde buldu.',
  ];

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
  /// Kâtip üslubu: ne yapıldı, ardından ne değişti. Tek nefes, iki cümle.
  static const List<(BuildingType, String, String)> _kFirstBuildings = [
    (BuildingType.well, 'Kuyu açıldı. Su artık köyün içinde.', '🪣'),
    (BuildingType.market, 'Pazar kuruldu. Tezgâhlar ilk kez doldu.', '🛒'),
    (BuildingType.tavern, 'Taverna açıldı. Akşamın gidecek bir yeri var.', '🍺'),
    (BuildingType.church, 'Kilise dikildi. Çan ilk kez çaldı.', '⛪'),
  ];

  /// Şu an sağlanan tüm başarımlar (id, başlık, ikon). Hem canlı tarama
  /// (`_tickAchievements`) hem sessiz backfill (`_backfillAchievements`) tek
  /// kaynaktan okusun → eşik mantığı asla ikiye ayrışmaz.
  Iterable<(String, String, String)> _satisfiedAchievements() sync* {
    // Nüfus — köyde yaşayan herkes (anonim işçi avatarları kaldırıldı).
    final pop = _villagers.length;
    for (final t in _kPopThresholds) {
      if (pop >= t) {
        yield ('pop_$t', 'Nüfus $t cana çıktı. Meydan daraldı.', '🎉');
      }
    }
    // İlk binalar.
    for (final (type, title, icon) in _kFirstBuildings) {
      if (_buildings.any((b) => b.type == type)) {
        yield ('build_${type.name}', title, icon);
      }
    }
    // Yıl dönümü — 1 yıl = 4 mevsim × kDaysPerSeason gün.
    final year = (_dayCount - 1) ~/ (kDaysPerSeason * Season.values.length);
    if (year >= 1) {
      yield ('year_$year', '$year. yıl doldu. Köy hâlâ ayakta.', '🗓️');
    }
  }

  /// Durum-taraması başarımları — scene_tick'in ana döngüsünden çağrılır
  /// (eski `_tickMilestones` yerine). _award idempotent olduğundan her tick
  /// güvenle taranır.
  void _tickAchievements() {
    for (final (id, title, icon) in _satisfiedAchievements()) {
      _award(id, title, icon);
    }
  }

  /// HAZIR kurulan köyler (referans/showcase) için: şu an zaten sağlanan tüm
  /// başarımları SESSİZCE kazanılmış işaretler — toast/kronik/sevinç YOK. Bunlar
  /// köyün geçmişinde çoktan geçilmiş eşiklerdir; oturmuş köy açılır açılmaz
  /// başarımların "çat çat" patlaması (ilk tick'te hepsi birden) bununla önlenir.
  void _backfillAchievements() {
    for (final (id, _, _) in _satisfiedAchievements()) {
      _achievedMilestones.add(id);
    }
  }
}
