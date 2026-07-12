/// Köyün hikâye güncesi (kronik) için tek bir kayıt. Düz string yerine yapısal:
/// gün + ikon + metin + başarım bayrağı → 📖 panel zengin/kategorize gösterir,
/// dönüm noktaları (başarımlar) vurgulu çizilir. [[project_staged_events]] Faz 4.
class ChronicleEntry {
  /// 1-bazlı oyun günü (0 = bilinmiyor, eski kayıttan migrasyon).
  final int day;
  /// Satır ikonu (emoji) — olay türünü görsel olarak ayırır.
  final String icon;
  final String text;
  /// Kalıcı dönüm noktası / başarım mı — panelde vurgulu (rozet + accent).
  final bool milestone;

  const ChronicleEntry({
    required this.day,
    required this.icon,
    required this.text,
    this.milestone = false,
  });

  Map<String, dynamic> toJson() => {
        'day': day,
        'icon': icon,
        'text': text,
        if (milestone) 'ms': true,
      };

  factory ChronicleEntry.fromJson(Map<String, dynamic> j) => ChronicleEntry(
        day: (j['day'] as num?)?.toInt() ?? 0,
        icon: j['icon'] as String? ?? '📜',
        text: j['text'] as String? ?? '',
        milestone: j['ms'] == true,
      );
}
