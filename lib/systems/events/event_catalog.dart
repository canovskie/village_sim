part of 'event_system.dart';

/// ─── RASTGELE OLAY KATALOĞU ───────────────────────────────────────────────
///
/// Olay motoru boş katalogla güvenle çalışır. Yeni içerik, konuya göre ayrı
/// bir `events/*.dart` part'ında tanımlanıp yalnız bu listede birleştirilir;
/// seçim, koşul ve ağırlık algoritması `event_system.dart`ta kalır.
const List<EventOutcome> kEventCatalog = <EventOutcome>[];
