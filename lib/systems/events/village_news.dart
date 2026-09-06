/// Köyde olup biteni kısa, öncelikli ve okunabilir haberlere dönüştüren saf
/// içerik modeli. Sahne zamanlayıcıyı, UI ise yalnız çizimi sahiplenir.
library;

enum VillageNewsTopic {
  village,
  people,
  work,
  stores,
  weather,
  safety,
  council,
  trade,
  imperial,
  system,
}

extension VillageNewsTopicCopy on VillageNewsTopic {
  String get label => switch (this) {
    VillageNewsTopic.village => 'KÖYDEN',
    VillageNewsTopic.people => 'KÖY HALKI',
    VillageNewsTopic.work => 'İŞLİKLERDEN',
    VillageNewsTopic.stores => 'AMBARDAN',
    VillageNewsTopic.weather => 'HAVADAN',
    VillageNewsTopic.safety => 'NÖBETTEN',
    VillageNewsTopic.council => 'DİVANDAN',
    VillageNewsTopic.trade => 'YOLDAN',
    VillageNewsTopic.imperial => 'SINIRDAN',
    VillageNewsTopic.system => 'OYUN',
  };

  String get fallbackHeadline => switch (this) {
    VillageNewsTopic.village => 'Köyün Hâli',
    VillageNewsTopic.people => 'Köylüler Arasında',
    VillageNewsTopic.work => 'İşler İlerliyor',
    VillageNewsTopic.stores => 'Ambar Haberi',
    VillageNewsTopic.weather => 'Hava Değişiyor',
    VillageNewsTopic.safety => 'Köyde Asayiş',
    VillageNewsTopic.council => 'Divanda Söz Var',
    VillageNewsTopic.trade => 'Yoldan Gelenler',
    VillageNewsTopic.imperial => 'İmparatorluktan Haber',
    VillageNewsTopic.system => 'Kısa Bilgi',
  };
}

enum VillageNewsTone { neutral, favorable, caution, critical }

enum VillageNewsPriority { routine, noteworthy, important, urgent }

/// Plakette görünen tek haber.
///
/// [rawMessage] eski bildirim çağrıları ve geliştirici günlüğü için korunur.
/// Oyuncu yüzünde [headline] ile [body] çizilir. Yeni içerik alanları açıkça
/// verebilir; eski yüzlerce string ise [fromMessage] ile güvenle sınıflanır.
class VillageNews {
  final String rawMessage;
  final String headline;
  final String body;
  final VillageNewsTopic topic;
  final VillageNewsTone tone;
  final VillageNewsPriority priority;
  final String stamp;
  final String dedupeKey;

  const VillageNews({
    required this.rawMessage,
    required this.headline,
    required this.body,
    required this.topic,
    required this.tone,
    required this.priority,
    this.stamp = 'ŞİMDİ',
    required this.dedupeKey,
  });

  factory VillageNews.fromMessage(
    String message, {
    String? headline,
    VillageNewsTopic? topic,
    VillageNewsTone? tone,
    VillageNewsPriority? priority,
    String stamp = 'ŞİMDİ',
  }) {
    final clean = _cleanMessage(message);
    final inferenceText = message.trim();
    final inferredTopic = topic ?? _inferTopic(inferenceText);
    final inferredTone = tone ?? _inferTone(inferenceText);
    final copy = _splitCopy(clean);
    final resolvedHeadline = headline?.trim().isNotEmpty == true
        ? headline!.trim()
        : (copy.headline ?? inferredTopic.fallbackHeadline);
    final resolvedBody = copy.body.isEmpty ? clean : copy.body;
    return VillageNews(
      rawMessage: message,
      headline: resolvedHeadline,
      body: resolvedBody,
      topic: inferredTopic,
      tone: inferredTone,
      priority:
          priority ??
          _inferPriority(inferenceText, inferredTone, inferredTopic),
      stamp: stamp,
      dedupeKey: _normalise('$resolvedHeadline $resolvedBody'),
    );
  }

  /// Yeni katalog içeriğinin ayrıştırma kuralına yaslanmadan doğrudan haber
  /// yazabilmesi için açık kurucu.
  factory VillageNews.compose({
    required String headline,
    required String body,
    required VillageNewsTopic topic,
    VillageNewsTone tone = VillageNewsTone.neutral,
    VillageNewsPriority priority = VillageNewsPriority.routine,
    String stamp = 'ŞİMDİ',
  }) {
    final cleanHeadline = headline.trim();
    final cleanBody = body.trim();
    return VillageNews(
      rawMessage: '$cleanHeadline. $cleanBody',
      headline: cleanHeadline,
      body: cleanBody,
      topic: topic,
      tone: tone,
      priority: priority,
      stamp: stamp,
      dedupeKey: _normalise('$cleanHeadline $cleanBody'),
    );
  }

  /// Okuma süresi karakter miktarıyla büyür. Acil haberler oyuncunun gözünden
  /// kaçmasın diye daha kısa metinlerde de en az altı saniye kalır.
  Duration get readDuration {
    final calculated = (4800 + rawMessage.length * 28).clamp(4800, 12000);
    final minimum = priority == VillageNewsPriority.urgent ? 6000 : 4800;
    return Duration(milliseconds: calculated < minimum ? minimum : calculated);
  }

  static String _cleanMessage(String message) {
    final withoutLead = message.trim().replaceFirst(
      RegExp(r'^[^A-Za-zÇĞİÖŞÜçğıöşü0-9]+'),
      '',
    );
    return withoutLead.trim().isEmpty ? message.trim() : withoutLead.trim();
  }

  static ({String? headline, String body}) _splitCopy(String clean) {
    for (final separator in const [' — ', ' – ', ': ', '. ', ' · ']) {
      final at = clean.indexOf(separator);
      if (at >= 3 && at <= 38 && at + separator.length < clean.length) {
        return (
          headline: clean.substring(0, at).trim(),
          body: clean.substring(at + separator.length).trim(),
        );
      }
    }
    return (headline: null, body: clean);
  }

  static VillageNewsTopic _inferTopic(String clean) {
    final text = clean.toLowerCase();
    if (_has(text, const [
      'imparator',
      'berat',
      'sancak',
      'ilhak',
      'heyet',
      'baskın',
      'asker',
    ])) {
      return VillageNewsTopic.imperial;
    }
    if (_has(text, const [
      'divan',
      'dilekçe',
      'hüküm',
      'kanun',
      'ferman',
      'meclis',
      'vergi',
    ])) {
      return VillageNewsTopic.council;
    }
    if (_has(text, const [
      'kaydedildi',
      'kayıt',
      'hız:',
      'duraklatıldı',
      'seçilen',
      'test',
      'bulunamadı',
      'modu',
      'dokun',
      'önce ',
      'yetersiz',
      'için yer yok',
      'uygun değil',
    ])) {
      return VillageNewsTopic.system;
    }
    if (_has(text, const [
      'suç',
      'fail',
      'devriye',
      'alarm',
      'kavga',
      'husumet',
      'fidye',
      'öldü',
      'yaralandı',
      'ceza',
      'yangın',
      'hırsız',
    ])) {
      return VillageNewsTopic.safety;
    }
    if (_has(text, const [
      'kış',
      'kar',
      'don',
      'yağmur',
      'fırtına',
      'gök',
      'mevsim',
      'soğuk',
      'ilkbahar',
      'sonbahar',
      'yaz ',
    ])) {
      return VillageNewsTopic.weather;
    }
    if (_has(text, const [
      'kervan',
      'tüccar',
      'yolcu',
      'pazar',
      'ziyaretçi',
      'yabancı',
    ])) {
      return VillageNewsTopic.trade;
    }
    if (_has(text, const [
      'yiyecek',
      'ambar',
      'odun',
      'taş',
      'demir',
      'kömür',
      'altın',
      'bal ',
      'kese',
      'stok',
      'hasat',
    ])) {
      return VillageNewsTopic.stores;
    }
    if (_has(text, const [
      'inşa',
      'onar',
      'şantiye',
      'tarla',
      'maden',
      'işi',
      'zanaat',
      'üret',
      'tezgâh',
      'değirmen',
    ])) {
      return VillageNewsTopic.work;
    }
    if (_has(text, const [
      'doğdu',
      'evlendi',
      'düğün',
      'nikâh',
      'aile',
      'cenaze',
      'hasta',
      'köylü',
      'hane',
      'barıştı',
      'ayrıldı',
      'göç',
    ])) {
      return VillageNewsTopic.people;
    }
    return VillageNewsTopic.village;
  }

  static VillageNewsTone _inferTone(String clean) {
    final text = clean.toLowerCase();
    if (_has(text, const [
      'köy dağıldı',
      'öldü',
      'ölüyor',
      'açlık',
      'yangın',
      'baskın',
      'infaz',
      'kaybedildi',
      'yıkıldı',
      '☠',
    ])) {
      return VillageNewsTone.critical;
    }
    if (_has(text, const [
      'yetersiz',
      'başarısız',
      'yaralandı',
      'ceza',
      'kıtlık',
      'soğuk',
      'hastalandı',
      'kırgınlık',
      'yetmiyor',
      'uygun değil',
      'kalmadı',
      'bulunamadı',
      'ödenemedi',
      'için yer yok',
      '⚠',
      '🚫',
      '🩸',
    ])) {
      return VillageNewsTone.caution;
    }
    if (_has(text, const [
      'tamamlandı',
      'sevindi',
      'kuruldu',
      'iyileşti',
      'barıştı',
      'kazandı',
      'bereket',
      'çiçek',
      'kaydedildi',
      'başardı',
      'şenlik',
      'düğün',
      '✓',
      '🏆',
    ])) {
      return VillageNewsTone.favorable;
    }
    return VillageNewsTone.neutral;
  }

  static VillageNewsPriority _inferPriority(
    String clean,
    VillageNewsTone tone,
    VillageNewsTopic topic,
  ) {
    final text = clean.toLowerCase();
    if (tone == VillageNewsTone.critical ||
        (topic == VillageNewsTopic.system && tone == VillageNewsTone.caution) ||
        _has(text, const [
          'acil',
          'köy dağılıyor',
          'hesaplaşma',
          'imparatorluk geliyor',
        ])) {
      return VillageNewsPriority.urgent;
    }
    if (tone == VillageNewsTone.caution ||
        _has(text, const [
          'karar bekliyor',
          'söz bekliyor',
          'dilekçe',
          'hüküm bekliyor',
          'heyet geldi',
        ])) {
      return VillageNewsPriority.important;
    }
    // Kayıt, hız ve araç geri bildirimi olumlu olsa da köy haberi değildir.
    // Ekran boşsa görünür; yaşayan köy gündeminin arkasında sıra oluşturmaz.
    if (topic == VillageNewsTopic.system) {
      return VillageNewsPriority.routine;
    }
    if (tone == VillageNewsTone.favorable ||
        _has(text, const ['geldi', 'başladı', 'tamamlandı', 'keşfedildi'])) {
      return VillageNewsPriority.noteworthy;
    }
    return VillageNewsPriority.routine;
  }

  static bool _has(String text, List<String> needles) =>
      needles.any(text.contains);

  static String _normalise(String text) =>
      text.toLowerCase().replaceAll(RegExp(r'[^a-zçğıöşü0-9]+'), ' ').trim();
}

class VillageNewsQueueUpdate {
  final bool accepted;
  final bool activeChanged;

  const VillageNewsQueueUpdate({
    required this.accepted,
    required this.activeChanged,
  });
}

/// Acil haberi bekletmeyen, eş haberleri üst üste yığmayan küçük yayın sırası.
class VillageNewsQueue {
  final int maxPending;
  VillageNews? _active;
  final List<VillageNews> _pending = [];

  VillageNewsQueue({this.maxPending = 2}) : assert(maxPending > 0);

  VillageNews? get active => _active;
  List<VillageNews> get pending => List.unmodifiable(_pending);
  int get pendingCount => _pending.length;

  VillageNewsQueueUpdate add(VillageNews news) {
    if (_active?.dedupeKey == news.dedupeKey ||
        _pending.any((item) => item.dedupeKey == news.dedupeKey)) {
      return const VillageNewsQueueUpdate(
        accepted: false,
        activeChanged: false,
      );
    }

    // Rutin köy cümleleri dünyada zaten görülen davranışlardır. Büyük plakete
    // yalnız doğrudan oyuncu geri bildirimi olan sistem satırları çıkabilir.
    if (news.priority == VillageNewsPriority.routine &&
        news.topic != VillageNewsTopic.system) {
      return const VillageNewsQueueUpdate(
        accepted: false,
        activeChanged: false,
      );
    }

    final current = _active;
    if (current == null) {
      _active = news;
      return const VillageNewsQueueUpdate(accepted: true, activeChanged: true);
    }

    // Gündelik ve yalnızca kayda değer haberler ekran doluyken eskir. Bunları
    // saklamak, birkaç saniyelik canlılığı dakikalar süren haber seline çevirir.
    if (news.priority.index < VillageNewsPriority.important.index) {
      return const VillageNewsQueueUpdate(
        accepted: false,
        activeChanged: false,
      );
    }

    // Karar/kriz, önündeki düşük önemli haberi keser. Yarım kalan haber ancak
    // kendisi de karar veya krizse korunur; gündelik satır geri dönmez.
    if (news.priority.index > current.priority.index) {
      if (current.priority.index >= VillageNewsPriority.important.index) {
        _insertPending(current);
      }
      _active = news;
      _trim();
      return const VillageNewsQueueUpdate(accepted: true, activeChanged: true);
    }

    _insertPending(news);
    _trim();
    return VillageNewsQueueUpdate(
      accepted: _pending.any((item) => identical(item, news)),
      activeChanged: false,
    );
  }

  VillageNews? completeActive() {
    _active = _pending.isEmpty ? null : _pending.removeAt(0);
    return _active;
  }

  void replace(VillageNews news) {
    _active = news;
    _pending.clear();
  }

  void clear() {
    _active = null;
    _pending.clear();
  }

  void _insertPending(VillageNews news) {
    final before = _pending.indexWhere(
      (item) => item.priority.index < news.priority.index,
    );
    if (before < 0) {
      _pending.add(news);
    } else {
      _pending.insert(before, news);
    }
  }

  void _trim() {
    if (_pending.length <= maxPending) return;
    _pending.removeLast();
  }
}
