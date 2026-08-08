/// Köyün hikâye güncesi (kronik): kayıt tipi + süzgeç türü.
/// [[project_staged_events]] Faz 4.
library;

/// Bir günce satırının TÜRÜ — panelin süzgeci bunu okur.
///
/// Neden gerekti: günce düz ve filtresiz tek listeydi. Altı yıllık bir koşuda
/// mevsim annalleri, doğumlar, nikâhlar ve büyüme satırları birikince oyuncunun
/// VERDİĞİ KARARLAR aralarında boğuluyordu — "ben o fermanı ne zaman, neye
/// karşılık imzalamıştım?" sorusunun cevabı listede vardı ama bulunamıyordu.
///
/// Üç tür yeter; daha incesi süzgeci kendisi bir bulmacaya çevirir:
enum ChronicleKind {
  /// ⚖ Oyuncunun VERDİĞİ karar: dilekçe şıkkı, mühür, fesih, hüküm, pazarlık,
  /// hane eylemi, olay seçimi. Süzgecin asıl varlık sebebi bu.
  decision('⚖', 'KARARLAR'),

  /// 👥 Köyün kendi yaşadığı: doğum, nikâh, büyüme, zanaat, bina, mevsim.
  life('👥', 'YAŞAM'),

  /// ⚠ Köyün başına gelen: afet, suç, kavga, hastalık, ölüm, yağma.
  crisis('⚠', 'SIKINTI');

  final String icon;
  final String label;
  const ChronicleKind(this.icon, this.label);
}

/// Günceye düşen tek bir satır. Düz string yerine yapısal: gün + ikon + metin +
/// başarım bayrağı + tür → 📖 panel kategorize gösterir, dönüm noktaları
/// (başarımlar) vurgulu çizilir.
class ChronicleEntry {
  /// 1-bazlı oyun günü (0 = bilinmiyor, eski kayıttan migrasyon).
  final int day;
  /// Satır ikonu (emoji) — olay türünü görsel olarak ayırır.
  final String icon;
  final String text;
  /// Kalıcı dönüm noktası / başarım mı — panelde vurgulu (rozet + accent).
  final bool milestone;

  /// Süzgeç türü. Varsayılan [ChronicleKind.life]: köyün kendi yaşadığı satır.
  /// Karar ve sıkıntı satırları YAZAN yerde açıkça işaretlenir.
  final ChronicleKind kind;

  const ChronicleEntry({
    required this.day,
    required this.icon,
    required this.text,
    this.milestone = false,
    this.kind = ChronicleKind.life,
  });

  Map<String, dynamic> toJson() => {
        'day': day,
        'icon': icon,
        'text': text,
        if (milestone) 'ms': true,
        // Varsayılan tür yazılmaz — eski kayıtlar da zaten 'life' olarak döner.
        if (kind != ChronicleKind.life) 'k': kind.name,
      };

  factory ChronicleEntry.fromJson(Map<String, dynamic> j) => ChronicleEntry(
        day: (j['day'] as num?)?.toInt() ?? 0,
        icon: j['icon'] as String? ?? '📜',
        text: j['text'] as String? ?? '',
        milestone: j['ms'] == true,
        kind: ChronicleKind.values
                .where((k) => k.name == j['k'])
                .firstOrNull ??
            ChronicleKind.life,
      );
}
