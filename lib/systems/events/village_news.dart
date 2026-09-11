/// Köyde olup biteni kısa, öncelikli ve okunabilir haberlere dönüştüren saf
/// içerik ve yayın saati modeli. Sahne görünürlüğü, UI yalnız çizimi bağlar.
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
    String? eventKey,
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
      dedupeKey: eventKey ?? _normalise('$resolvedHeadline $resolvedBody'),
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
    String? eventKey,
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
      dedupeKey: eventKey ?? _normalise('$cleanHeadline $cleanBody'),
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
    final text = clean.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();
    if (_has(text, const [
      'eksik malzeme',
      'hız:',
      'duraklatıldı',
      'kayıt',
      'kaydedildi',
      'seçilen',
      'yetersiz',
      'için yer yok',
      'uygun değil',
    ])) {
      return VillageNewsTopic.system;
    }
    if (_has(text, const [
      '👶',
      '💞',
      '💔',
      '🚪',
      'doğdu',
      'aile kurdu',
      'hanesi',
    ])) {
      return VillageNewsTopic.people;
    }
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
    if (RegExp(
          r'(^|[^a-zçğıöşü])kar(ın|dan|la|lı)?($|[^a-zçğıöşü])',
        ).hasMatch(text) ||
        _has(text, const [
          'kış',
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
    final text = clean.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();
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
      'eksik malzeme',
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
    final text = clean.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();
    if (_has(text, const ['🚪', '💔', 'gitmeye hazırlan', 'çekip gitti'])) {
      return VillageNewsPriority.urgent;
    }
    if (_has(text, const ['👶', 'doğdu', 'aile kurdu'])) {
      return VillageNewsPriority.important;
    }
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

  static bool _has(String text, List<String> needles) => needles.any(
    (needle) =>
        RegExp(r'(^|[^a-zçğıöşü0-9])' + RegExp.escape(needle)).hasMatch(text),
  );

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
  /// Yalnız düşük öncelikli bekleyenlerin sınırı. Önemli ve acil kayıtlar
  /// okunmadan atılmaz; aynı olayın varyantları dedupeKey ile birleşir.
  final int maxPending;
  final Duration repeatDelay;
  VillageNews? _active;
  final List<VillageNews> _pending = [];
  final Map<String, double> _remaining = {};
  final Map<String, (double, VillageNewsPriority)> _recent = {};
  double _clock = 0;

  VillageNewsQueue({
    this.maxPending = 2,
    this.repeatDelay = const Duration(seconds: 30),
  }) : assert(maxPending > 0);

  VillageNews? get active => _active;
  List<VillageNews> get pending => List.unmodifiable(_pending);
  int get pendingCount => _pending.length;
  double get remainingFraction {
    final news = _active;
    if (news == null) return 0;
    return ((_remaining[news.dedupeKey] ?? _duration(news)) / _duration(news))
        .clamp(0.0, 1.0);
  }

  double _duration(VillageNews news) => news.readDuration.inMicroseconds / 1e6;

  /// Saat gerçek görünür süreyi sayar. Gizlenen haber ve sıradaki haberin
  /// bütçesi tükenmez; hızlandırılmış simülasyon bu saate etki etmez.
  void advance(double seconds, {required bool visible}) {
    if (seconds <= 0) return;
    _clock += seconds;
    _recent.removeWhere((_, value) => value.$1 <= _clock);
    final news = _active;
    if (!visible || news == null) return;
    final left = (_remaining[news.dedupeKey] ?? _duration(news)) - seconds;
    _remaining[news.dedupeKey] = left;
    if (left <= 0) completeActive();
  }

  VillageNewsQueueUpdate add(VillageNews news) {
    const rejected = VillageNewsQueueUpdate(
      accepted: false,
      activeChanged: false,
    );
    final recent = _recent[news.dedupeKey];
    if (recent != null &&
        recent.$1 > _clock &&
        recent.$2.index >= news.priority.index) {
      return rejected;
    }
    final current = _active;
    if (current?.dedupeKey == news.dedupeKey) {
      if (news.priority.index <= current!.priority.index) return rejected;
      _active = news; // aynı olay ağırlaştı: yeni uyarının tam süresi var
      _remaining[news.dedupeKey] = _duration(news);
      return const VillageNewsQueueUpdate(accepted: true, activeChanged: true);
    }
    final duplicate = _pending.indexWhere((n) => n.dedupeKey == news.dedupeKey);
    if (duplicate >= 0) {
      if (_pending[duplicate].priority.index >= news.priority.index) {
        return rejected;
      }
      _pending.removeAt(duplicate);
    }
    if (news.priority == VillageNewsPriority.routine &&
        news.topic != VillageNewsTopic.system) {
      return rejected;
    }

    _remaining[news.dedupeKey] = _duration(news);
    if (current == null) {
      _active = news;
      return const VillageNewsQueueUpdate(accepted: true, activeChanged: true);
    }
    if (news.priority.index > current.priority.index) {
      if (current.priority.index >= VillageNewsPriority.important.index) {
        _insertPending(current);
      } else {
        _remember(current);
      }
      _active = news;
      return const VillageNewsQueueUpdate(accepted: true, activeChanged: true);
    }
    _insertPending(news);
    // Küçük gündelik haberler için kısa tampon; krizler bu sınırı paylaşmaz.
    final ordinary = _pending
        .where((n) => n.priority.index < VillageNewsPriority.important.index)
        .toList();
    if (ordinary.length > maxPending) {
      final dropped = ordinary.last;
      _pending.remove(dropped);
      _remaining.remove(dropped.dedupeKey);
    }
    return VillageNewsQueueUpdate(
      accepted: _pending.contains(news),
      activeChanged: false,
    );
  }

  void _remember(VillageNews news) {
    _remaining.remove(news.dedupeKey);
    _recent.remove(news.dedupeKey);
    _recent[news.dedupeKey] = (
      _clock + repeatDelay.inMicroseconds / 1e6,
      news.priority,
    );
    if (_recent.length > 256) _recent.remove(_recent.keys.first);
  }

  VillageNews? completeActive() {
    if (_active != null) _remember(_active!);
    _active = _pending.isEmpty ? null : _pending.removeAt(0);
    return _active;
  }

  /// Oyuncunun yeni eylem cevabı eskisinin yerini alabilir.
  void replace(VillageNews news) {
    _remaining.clear();
    _active = news;
    _remaining[news.dedupeKey] = _duration(news);
    _pending.clear();
  }

  void clear() {
    _active = null;
    _pending.clear();
    _remaining.clear();
    _recent.clear();
    _clock = 0;
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
}
