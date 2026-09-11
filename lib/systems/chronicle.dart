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

/// Bir kararın köyde bıraktığı okunabilir neden-sonuç zinciri.
///
/// Chronicle satırının kendisi kısa yıllıktır; bu yapı aynı satırın ardındaki
/// bağı saklar. Alanlar özellikle metindir: Defter ham delta/formül göstermek
/// yerine kâtibin `karar → sonuç → uzun vade` cümlesini kurar. Tamamı nullable
/// bir üst alanda yaşadığı için eski kayıtlar hiçbir migrasyon anahtarı
/// gerektirmeden açılır.
class DecisionTrace {
  final String sourceDecision;
  final String firstOutcome;
  final String affected;
  final String laterOutcome;
  final String reckoningAxis;

  /// 1 küçük, 2 önemli, 3 ağır. Final seçicisi ham sayıyı göstermez; yalnızca
  /// koşunun en ağır, birbirinden farklı izlerini ayırmak için kullanır.
  final int weight;

  const DecisionTrace({
    required this.sourceDecision,
    required this.firstOutcome,
    required this.affected,
    required this.laterOutcome,
    required this.reckoningAxis,
    this.weight = 1,
  });

  String get ledgerLine => [
    sourceDecision,
    firstOutcome,
    affected,
    laterOutcome,
  ].where((s) => s.trim().isNotEmpty).join(' → ');

  Map<String, dynamic> toJson() => {
    's': sourceDecision,
    'i': firstOutcome,
    'a': affected,
    'l': laterOutcome,
    'x': reckoningAxis,
    if (weight != 1) 'w': weight,
  };

  factory DecisionTrace.fromJson(Map<String, dynamic> j) => DecisionTrace(
    sourceDecision: j['s'] as String? ?? '',
    firstOutcome: j['i'] as String? ?? '',
    affected: j['a'] as String? ?? '',
    laterOutcome: j['l'] as String? ?? '',
    reckoningAxis: j['x'] as String? ?? 'Karar mirası',
    weight: ((j['w'] as num?)?.toInt() ?? 1).clamp(1, 3),
  );
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

  /// Yalnız oyuncu kararlarında bulunan yapısal neden-sonuç izi.
  final DecisionTrace? trace;

  const ChronicleEntry({
    required this.day,
    required this.icon,
    required this.text,
    this.milestone = false,
    this.kind = ChronicleKind.life,
    this.trace,
  });

  ChronicleEntry copyWith({DecisionTrace? trace, ChronicleKind? kind}) =>
      ChronicleEntry(
        day: day,
        icon: icon,
        text: text,
        milestone: milestone,
        kind: kind ?? this.kind,
        trace: trace ?? this.trace,
      );

  Map<String, dynamic> toJson() => {
    'day': day,
    'icon': icon,
    'text': text,
    if (milestone) 'ms': true,
    // Varsayılan tür yazılmaz — eski kayıtlar da zaten 'life' olarak döner.
    if (kind != ChronicleKind.life) 'k': kind.name,
    if (trace != null) 'tr': trace!.toJson(),
  };

  factory ChronicleEntry.fromJson(Map<String, dynamic> j) => ChronicleEntry(
    day: (j['day'] as num?)?.toInt() ?? 0,
    icon: j['icon'] as String? ?? '📜',
    text: j['text'] as String? ?? '',
    milestone: j['ms'] == true,
    kind:
        ChronicleKind.values.where((k) => k.name == j['k']).firstOrNull ??
        ChronicleKind.life,
    trace: j['tr'] is Map
        ? DecisionTrace.fromJson(Map<String, dynamic>.from(j['tr'] as Map))
        : null,
  );
}

/// Defter özetinin ortak sıralaması: en yeni anlamlı karar izi önce.
List<ChronicleEntry> recentDecisionTraces(
  Iterable<ChronicleEntry> chronicle, {
  int limit = 5,
}) {
  if (limit <= 0) return const [];
  return chronicle
      .where((e) => e.trace != null)
      .toList(growable: false)
      .reversed
      .take(limit)
      .toList(growable: false);
}
