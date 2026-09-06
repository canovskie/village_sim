import '../run/village_year.dart';

/// Üç karşılaşmanın kimliği ve zaman kapısı. Rastgele olay sıklığından
/// bağımsızdır; son karşılaşma mevcut koşunun stratejik yıllarına bağlanır.
enum StoryThread { family, apprenticeship, accord }

abstract final class StoryThreads {
  static String id(StoryThread thread, String chapter) =>
      'story.${thread.name}.$chapter';

  static StoryThread? threadOf(String petitionId) {
    for (final thread in StoryThread.values) {
      if (petitionId.startsWith('story.${thread.name}.')) return thread;
    }
    return null;
  }

  static bool isOpening(String petitionId) => petitionId.endsWith('.start');
  static bool isLoss(String petitionId) => petitionId.endsWith('.loss');
  static bool isFinal(String petitionId) =>
      petitionId.endsWith('.shared') || petitionId.endsWith('.private');

  static int minimumYear(String petitionId) {
    if (!isFinal(petitionId)) return 1;
    return threadOf(petitionId) == StoryThread.accord
        ? kReckoningHeraldYear
        : 3;
  }

  static bool ready(String petitionId, int dayCount) =>
      yearOf(dayCount) >= minimumYear(petitionId);

  static bool canStart(
    StoryThread thread,
    Set<String> memory,
    Set<StoryThread> availableCasts,
  ) =>
      availableCasts.contains(thread) &&
      !memory.contains(id(thread, 'started')) &&
      !memory.contains(id(thread, 'done'));

  /// Kaybı takvimden önce karşıla; yok olan kişiye yıllarca dilekçe bekletme.
  static String chapterForCast(String petitionId, {required bool intact}) =>
      intact || isLoss(petitionId)
      ? petitionId
      : id(threadOf(petitionId)!, 'loss');

  /// Kazanılmış ortaklıkların geç hedeflerdeki anlamı. Görevleri tamamlamaz;
  /// gerçek yol ağı, rıza ve tüzük koşulları ayrıca sağlanmalıdır.
  static String? questFor(StoryThread thread) => switch (thread) {
    StoryThread.family => 'roads',
    StoryThread.apprenticeship => 'crafts',
    StoryThread.accord => 'trustedCouncil',
  };
}

/// Referanslar sahnenin save indeksleriyle çevrilir. Adlar ayrıca saklanır:
/// köylü ölse veya adı değiştirilse bile yaşanan geçmiş kaybolmaz.
class StoryCast<T> {
  final T? lead;
  final T? partner;
  final String leadName;
  final String partnerName;
  final String craft;
  int lastMeetingDay;
  int lessons;

  StoryCast({
    required this.lead,
    required this.partner,
    required this.leadName,
    required this.partnerName,
    this.craft = '',
    this.lastMeetingDay = 0,
    this.lessons = 0,
  });

  Map<String, Object?> toJson(int Function(T?) reference) => {
    'lead': reference(lead),
    'partner': reference(partner),
    'leadName': leadName,
    'partnerName': partnerName,
    'craft': craft,
    'lastMeetingDay': lastMeetingDay,
    'lessons': lessons,
  };

  static StoryCast<T> fromJson<T>(
    Map<String, dynamic> json,
    T? Function(int) reference,
  ) => StoryCast<T>(
    lead: reference((json['lead'] as num?)?.toInt() ?? -1),
    partner: reference((json['partner'] as num?)?.toInt() ?? -1),
    leadName: json['leadName'] as String? ?? '',
    partnerName: json['partnerName'] as String? ?? '',
    craft: json['craft'] as String? ?? '',
    lastMeetingDay: (json['lastMeetingDay'] as num?)?.toInt() ?? 0,
    lessons: (json['lessons'] as num?)?.toInt() ?? 0,
  );
}
