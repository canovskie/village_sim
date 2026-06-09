/// NPC yaşam evreleri. Bir köylü zamanla çocukluktan yaşlılığa ilerler.
/// Görsel boyut, kıyafet (mesleksiz köylü vs meslek) ve panel etiketi buradan.
enum LifeStage { child, youth, adult, elder }

/// Bir oyun gününün saniye cinsinden uzunluğu — DayNightCycle.dayDuration ile
/// aynı tutulmalı (240 sn = 4 dk tam gün).
const double kGameDaySeconds = 240.0;

// ─── Evre eşikleri (oyun günü cinsinden) ──────────────────────────────────────
// Doğan köylü bu süreler boyunca büyür. Tunable.
//   çocuk : 0      → kYouthStartDay   (~4 dk)
//   genç  : kYouth → kAdultStartDay
//   yetişkin (meslek edinir) : kAdult → kElderStartDay
//   yaşlı : kElder →  (sonsuz — ölüm yok)
const double kYouthStartDay = 1.0;
const double kAdultStartDay = 2.5;
const double kElderStartDay = 12.0;

// Doğal ölüm: köylü yaşlı evresine girdikten sonra bu aralıkta rastgele bir
// süre daha yaşar, sonra hayata veda eder. ageDays >= kElderStartDay + rastgele.
const double kElderLifeMin = 8.0;
const double kElderLifeMax = 18.0;

/// Yaşam evresi geçiş hızı çarpanı — `slowMaturity` politikası açıkken
/// scene 1/1.6 (~0.625) yapar, böylece eşik karşılaştırmasında ageDays
/// "küçültülmüş" gibi davranır → evreler 1.6× daha geç başlar. Default 1.0.
/// VillagerEntity policy'ye doğrudan erişmesin diye side channel.
double kMaturityScale = 1.0;

LifeStage lifeStageForDays(double days) {
  final d = days * kMaturityScale;
  return d < kYouthStartDay
      ? LifeStage.child
      : d < kAdultStartDay
          ? LifeStage.youth
          : d < kElderStartDay
              ? LifeStage.adult
              : LifeStage.elder;
}

extension LifeStageX on LifeStage {
  /// Türkçe etiket — panel ve bilgi gösterimleri.
  String get label => switch (this) {
        LifeStage.child => 'Çocuk',
        LifeStage.youth => 'Genç',
        LifeStage.adult => 'Yetişkin',
        LifeStage.elder => 'Yaşlı',
      };

  String get icon => switch (this) {
        LifeStage.child => '🧒',
        LifeStage.youth => '🧑',
        LifeStage.adult => '👤',
        LifeStage.elder => '🧓',
      };

  /// Sprite çizim ölçeği — çocuk küçük, yetişkin tam boy, yaşlı hafif küçülmüş.
  double get renderScale => switch (this) {
        LifeStage.child => 0.60,
        LifeStage.youth => 0.82,
        LifeStage.adult => 1.00,
        LifeStage.elder => 0.95,
      };

  /// Bu evrede meslek görünümü (ve mesleki kıyafet) edinilmiş mi?
  /// Çocuk/genç → mesleksiz standart köylü; yetişkin/yaşlı → meslek.
  bool get hasProfession =>
      this == LifeStage.adult || this == LifeStage.elder;
}
