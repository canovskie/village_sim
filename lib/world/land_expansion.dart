/// Dünyanın açılma eğrisi — reach span hedefinin SAF matematiği.
///
/// Reach bir örtü değil kamera kısıtıdır ([[lib/scene/scene_land.dart]]); bu
/// dosya yalnız "ilerlemeye karşılık ne kadar span" sorusunu cevaplar, sahne
/// katmanına hiç bağlı değildir → testten doğrudan çağrılır.
library;

/// Asimptotun harita kenarına bıraktığı emniyet payı (span).
const double kSpanCeilMargin = 4.0;

/// Eğrinin ölçeği. 45 seçildi çünkü erken oyunu eski LİNEER eğriyle neredeyse
/// birebir örtüştürür (ilerleme 20'de 69.4 vs 70) — açılış hissi değişmez,
/// eğri yalnız geç oyunda ayrışır.
const double kSpanScale = 45.0;

/// Reach hedefi — **asimptotik**, [ceil]'e ulaşmaz.
///
/// Eski model lineerdi (`start + ilerleme`) ve harita sınırına clamp'lenirdi:
/// yeterince büyük bir köyde dünya açılmayı BIRAKIYORDU. Oysa köyün ayak izi
/// √N ile büyür, hak edilen alan N ile — ikisi hiç kesişmez, yani orada bir
/// darlık değil yalnızca "dünya durdu" hissi vardı.
///
/// Hiperbolik eğri o duvarı kaldırır: [progress] sonsuza gitse bile sonuç
/// [ceil]'e YAKLAŞIR, hiç dokunmaz. Maliyet: tek bölme.
///
/// - `progress = 0` → tam olarak [start]
/// - `progress → ∞` → [ceil] (limitte, hiçbir sonlu değerde değil)
/// - [start] ile [ceil] arasında monoton artar.
double landExpansionTarget({
  required double start,
  required double ceil,
  required double progress,
  double scale = kSpanScale,
}) {
  if (ceil <= start) return start; // dar harita — açılacak yer yok
  final p = progress < 0 ? 0.0 : progress;
  return ceil - (ceil - start) * scale / (scale + p);
}
