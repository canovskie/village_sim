/// Oyuncunun ne kadar süre karşılıksız kalabileceğinin tek sözleşmesi.
///
/// Bunlar içerik sıklığını körlemesine artırmak için değil, üç ayrı ritmi
/// birbirinden ayırmak için var:
/// - küçük, isimli köy gündemi sürekli bir sonraki hamleyi verir;
/// - dilekçe orta ağırlıkta yönetişim kararıdır;
/// - rastgele olay seyrekçe büyük bir dünya değişimi yaratır.
///
/// Bir oyuncu hamlesinin ardından 15 saniyeden uzun tamamen boş bir pencere
/// oluşmaması ürün kabul sınırıdır. Büyük olayların daha seyrek olması bu
/// sınırı bozmaz; arayı Köy Nabzı ve oyuncunun proaktif araçları doldurur.
abstract final class GameplayPacing {
  static const double maxEmptyRealSeconds = 15.0;

  // Kuruluş: NPC koreografisi oyuncunun ilerlemesini rehin alamaz.
  static const double foundingBedTravelSimSeconds = 6.0;
  static const double foundingFirstNightSettleRealSeconds = 8.0;

  // Köy Nabzı: gerçek zaman, oyun hızından bağımsız.
  static const double firstPulseRealSeconds = 8.0;
  static const double pulseDecisionRealSeconds = 18.0;
  static const double pulseRetryMinRealSeconds = 5.0;
  static const double pulseRetryMaxRealSeconds = 8.0;
  static const double pulseNextMinRealSeconds = 10.0;
  static const double pulseNextMaxRealSeconds = 15.0;

  // Büyük dünya olayları: ilk olay erken görünür, devamı nabzı ezmez.
  static const double firstEventSimSeconds = 40.0;
  static const double eventMinSimSeconds = 80.0;
  static const double eventMaxSimSeconds = 120.0;
  static const double omenMinSimSeconds = 3.0;
  static const double omenMaxSimSeconds = 5.0;

  // Yönetişim: kuruluş açıldıktan sonra ilk söz çabuk gelir.
  static const double firstPetitionSimSeconds = 40.0;
  static const double petitionIntervalSimSeconds = 60.0;

  // Ağır kararlar birbirinin üstüne binmez ama dakikalarca da saklanmaz.
  static const double heavyDecisionQuietDays = 0.15;

  // Beklemek isteyen oyuncuya kaçış; ana tempo çözümü değildir.
  static const List<double> speedSteps = [1.0, 2.0, 4.0, 0.0];
}
