/// KÖYÜN DAĞILMASI — oyunun kaybetme eşiği.
///
/// Bu oyun uzun süre "kaybedilemez"di ve boşlukta durmasının sebebi buydu:
/// hiçbir karar geri dönülemez bir şey maliyet etmiyordu. Artık ediyor —
/// köy dağılabilir, koşu biter, kayıt kapanır.
///
/// TASARIMIN TEK KURALI: **kayıp haber verilmiş olmalı.** Habersiz ölen köy
/// öğretmez, yalnız sinirlendirir. Bu yüzden dağılma bir ANDA olmaz; köy önce
/// [VillageVitality.strained] (kıpırdanma), sonra [VillageVitality.failing]
/// (geri sayım görünür) evrelerinden geçer. Geri sayım devam ederken toparlarsan
/// sayaç SIFIRLANIR — eşik bir kapan değil, bir süredir.
///
/// İKİNCİ KURAL: **ancak kurduğunu kaybedersin.** Kuruluş kadrosu zaten azdır;
/// sistem, köy bir kez ayağa kalkana ([kFoundedAdults] yetişkin görene) kadar
/// UYUR. Yoksa oyun daha ilk günden ölüm uyarısı verirdi ve bu bir tehdit değil
/// bir gürültü olurdu.
///
/// Bu dosya SAF: sahne state'i tutmaz, metin/rastgelelik içermez → test
/// edilebilir (bkz. test/village_collapse_test.dart).
library;

/// Köyün ayakta kalabilirliği — sertlik sırasına göre.
enum VillageVitality {
  /// Köy kendini döndürüyor.
  healthy,

  /// Eller azaldı. Henüz tehlike yok ama köy gerginleşti (yalnız uyarı).
  strained,

  /// Köy kendini döndüremiyor. GERİ SAYIM işler — toparlanmazsa dağılır.
  failing,

  /// Dağıldı. Koşu biter.
  collapsed,
}

extension VillageVitalityX on VillageVitality {
  /// Oyuncuya gösterilecek mi — sağlıklı köy hiçbir şey göstermez.
  bool get visible => index >= VillageVitality.strained.index;

  /// Geri sayım işliyor mu.
  bool get counting => this == VillageVitality.failing;
}

/// Köyün "kurulmuş" sayılması için bir kez görmesi gereken yetişkin sayısı.
/// Bunun altında sistem tamamen uyur (kuruluş kadrosu ~5 kişidir).
const int kFoundedAdults = 6;

/// Bu yetişkin sayısının altında köy GERGİN — görünür uyarı, geri sayım yok.
const int kStrainedAdults = 4;

/// Bu yetişkin sayısının altında köy kendini döndüremez — GERİ SAYIM başlar.
const int kFailingAdults = 2;

/// Geri sayımın uzunluğu (oyun günü). Toparlanırsan sıfırlanır.
///
/// Neden kısa değil: bu süre oyuncunun gerçekten bir şey YAPABİLECEĞİ kadar
/// olmalı (göçmen kabul et, haneyi barıştır, kışı çıkar). Kısa bir sayaç
/// "kaybettin" demenin süslü yolu olurdu.
const double kCollapseGraceDays = 6.0;

/// Köyün dağılma nedeni — mezar taşına yazılır.
enum CollapseCause {
  /// Kimse kalmadı (ölüm/göç/ayrılık birikti).
  emptied,

  /// İnsan var ama köyü döndürecek yetişkin kalmadı.
  noHands,
}

/// Köyün o anki hâli + geri sayımın kalanı.
class CollapseState {
  final VillageVitality vitality;

  /// Dağılmaya kalan oyun günü. Geri sayım işlemiyorsa `double.infinity`.
  final double daysLeft;

  /// Dağıldıysa nedeni; yoksa null.
  final CollapseCause? cause;

  const CollapseState({
    required this.vitality,
    this.daysLeft = double.infinity,
    this.cause,
  });

  bool get collapsed => vitality == VillageVitality.collapsed;

  /// Geri sayımın ne kadarı tükendi (0..1) — UI çubuğu için.
  double get spent => daysLeft.isInfinite
      ? 0.0
      : (1.0 - daysLeft / kCollapseGraceDays).clamp(0.0, 1.0);
}

/// Köyün hâli. [peakAdults] köyün BUGÜNE DEK gördüğü en yüksek yetişkin sayısı
/// (kurulmuşluk kapısı), [countdown] geri sayımda geçen gün.
///
/// Yetişkin = mesleği olabilen, ölmekte olmayan köylü. Çocuk sayılmaz: köyü
/// döndüren el onlarınki değil. Ama nüfus tümüyle biterse neden [emptied]'dır.
CollapseState evaluateCollapse({
  required int adults,
  required int population,
  required int peakAdults,
  required double countdown,
}) {
  // Köy henüz ayağa kalkmadı → sistem uyur. Ancak kurduğunu kaybedersin.
  if (peakAdults < kFoundedAdults) {
    return const CollapseState(vitality: VillageVitality.healthy);
  }
  if (population <= 0) {
    return const CollapseState(
        vitality: VillageVitality.collapsed, cause: CollapseCause.emptied);
  }
  if (adults <= 0) {
    return const CollapseState(
        vitality: VillageVitality.collapsed, cause: CollapseCause.noHands);
  }
  if (adults <= kFailingAdults) {
    final left = kCollapseGraceDays - countdown;
    if (left <= 0) {
      return const CollapseState(
          vitality: VillageVitality.collapsed, cause: CollapseCause.noHands);
    }
    return CollapseState(
        vitality: VillageVitality.failing, daysLeft: left);
  }
  if (adults <= kStrainedAdults) {
    return const CollapseState(vitality: VillageVitality.strained);
  }
  return const CollapseState(vitality: VillageVitality.healthy);
}

/// Geri sayımın yeni değeri. Köy hâlâ çöküyorsa ilerler, TOPARLADIYSA
/// sıfırlanır — eşik bir kapan değil, geri alınabilir bir süredir.
double advanceCountdown({
  required double countdown,
  required VillageVitality vitality,
  required double dayFrac,
}) {
  if (!vitality.counting) return 0;
  return countdown + (dayFrac <= 0 ? 0 : dayFrac);
}

// ── AYRILIK: kopmuş hane köyü terk eder ──────────────────────────────────────
//
// Dağılmanın SİYASİ yolu. Kopuş ([HouseStance.defiant]) bugüne dek bir durumdu;
// artık bir eşiktir: hane bu kadar gün kopuk kalırsa çeker gider. İnsanlarını,
// sakladığı yiyeceği alır; evleri boş kalır. Geri dönüş yoktur.
//
// Yeterince hane giderse köyü döndürecek el kalmaz → dağılma. Yani oyuncu köyü
// yalnız açlıktan değil, SİYASETTEN de kaybedebilir.

/// Kopuşta bu kadar gün kalan hane köyü terk eder (oyun günü).
///
/// Merdivenin kendisi (razı → serzeniş → el çekti → ambar → kopuş) zaten uzun
/// bir uyarı rampasıdır; bu sayaç onun son basamağıdır, ilk uyarı değil.
const double kSchismDays = 6.0;

/// Hane ayrılmaya ne kadar yakın (0..1) — 1.0 = bu gün gidiyorlar.
double schismProgress(double defiantDays) =>
    (defiantDays / kSchismDays).clamp(0.0, 1.0);

/// Ayrılık için SON UYARI penceresi — bu orandan sonra köy açıkça uyarılır
/// ("arabalar yüklendi"). Sessiz bir ayrılık kabul edilemez.
const double kSchismFinalWarn = 0.72;
