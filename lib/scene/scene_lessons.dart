part of '../main.dart';

/// ORTA OYUN DERSLERİ — kuruluştan sonra açılan sistemlerin öğretmeni.
///
/// Ders kataloğu ve tetikleri `systems/village_lessons.dart`'ta (saf); burası
/// onları köye bağlar. Sahnenin işi üç şey:
///   1. Köyün hâlini derslerin anlayacağı dile çevirmek ([_lessonContext]).
///   2. Dersi DOĞRU ANDA açmak — yani oyuncu başka bir işin içinde değilken.
///   3. Görüleni kaydetmek (bkz. scene_save `lessonsSeen`).
///
/// ── NE ZAMAN SUSAR ────────────────────────────────────────────────────────
/// Ders kartı, oyuncunun dikkatinin başka yerde olduğu HİÇBİR anda açılmaz:
/// sinematik, karar modalı, dilekçe, ferman töreni, imparatorluk pazarlığı,
/// açık Defter, olay banner'ı ve kuruluş öğreticisi — hepsi önde. Bu liste
/// uzun görünüyor ama kısaltmanın bedeli ağır: iki anlatım aynı anda
/// konuşunca ikisi de kaybeder (kuruluş öğreticisinde bire bir yaşandı).
///
/// Kuruluş bitmeden de konuşmaz: köy daha ayağa kalkmadan "hane kızgınlığı"
/// anlatmak, henüz olmayan bir şeyi öğretmektir.
extension _SceneLessons on _VillageSceneState {
  /// Ders koşulları bu aralıkla (sn) yoklanır. Ucuz bir tarama değil (hane
  /// duruşlarını gezer), ama saniyede bir yeterli: dersler yıl boyunca
  /// yedi kez açılır.
  static const double _kLessonScan = 1.5;

  /// Bir ders kapandıktan sonra bir sonrakinin bekleyeceği süre. Arka arkaya
  /// iki kart, oyuncunun ikisini de okumadan kapatmasına yol açar.
  static const double _kLessonGap = 8.0;

  /// Dersler bu köyde işliyor mu. Harness/showcase köylerinde kart açılırsa
  /// kare yakalama ders kartını çeker ve prova ekranı okuyamaz.
  bool get _lessonsEnabled =>
      kProbeLessonsArmed || (!kCaptureMode && !widget.referenceVillage);

  LessonContext _lessonContext() {
    var upset = 0;
    for (final h in _houses.snapshot()) {
      if (h.members <= 0) continue;
      // Serzeniş VE üstü: oyuncunun uyarı penceresi burada başlar. "El çekti"yi
      // beklemek dersi zarar oluştuktan sonra vermek olurdu.
      if (h.stance.index >= HouseStance.murmuring.index) upset++;
    }
    return LessonContext(
      season: _season,
      upsetHouses: upset,
      crimesSeen: _crimesSeen,
      knownCrafts: _knownCrafts.length,
      coatsPending: _coatsMade,
      enactedPolicies: _policies.enactedCount,
      regimeNamed: _regimeIdentity.regime != VillageRegime.moderate,
      imperialVisits: _imperialVisits,
    );
  }

  /// Ders açılabilir mi — oyuncunun dikkati serbest mi.
  bool get _lessonWindowOpen {
    if (_activeLesson != null) return false;
    if (_lessonGap > 0) return false;
    // Kuruluş sürerken sus: köy daha ayağa kalkmadı, öğretilecek sistem yok.
    // (Aynı kapı yönetişimi de uyandırır — bkz. scene_flow `_governanceAwake`.)
    if (!_governanceAwake) return false;
    // Kuruluş öğreticisi konuşuyorsa iki anlatım çakışır.
    if (_guideOpen || _guideWanted) return false;
    if (_activeCutscene != null ||
        _pendingChoice != null ||
        _petitionModalOpen ||
        _lawRitual != null ||
        _imperialDemand != null ||
        _pendingJudgment != null) {
      return false;
    }
    // Defter açıkken kart onun üstüne düşerdi; olay banner'ı da aynı yeri
    // (üst-orta) kullanıyor.
    if (_ledgerSection != null) return false;
    if (_activeEvent != null) return false;
    return true;
  }

  void _tickLessons(double dt) {
    if (!_lessonsEnabled) return;
    if (_lessonGap > 0) _lessonGap -= dt;
    _lessonScan += dt;
    if (_lessonScan < _kLessonScan) return;
    _lessonScan = 0;
    if (!_lessonWindowOpen) return;

    final lesson = VillageLessons.pick(_lessonContext(), _lessonsSeen);
    if (lesson == null) return;
    _lessonsSeen.add(lesson.id);
    kProbeLessonsShown++;
    kProbeLastLesson = lesson.id;
    logDev('DERS: ${lesson.id}');
    // Kroniğe DÜŞMEZ: ders bir olay değil, bir açıklama. Vakanüvis köyün
    // başına gelenleri yazar, oyuncuya ne anlatıldığını değil.
    setStateHere(() => _activeLesson = lesson);
  }

  void _dismissLesson() {
    if (_activeLesson == null) return;
    setStateHere(() {
      _activeLesson = null;
      _lessonGap = _kLessonGap;
    });
  }

  /// Ders kartı katmanı — olay banner'ıyla AYNI yerde (üst-orta) durur ve
  /// ikisi asla birlikte çizilmez (bkz. [_lessonWindowOpen]).
  Widget buildLessonCard() {
    return Positioned(
      top: 90,
      left: 0,
      right: 0,
      child: Center(
        child: RepaintBoundary(
          child: ListenableBuilder(
            listenable: _frame,
            builder: (_, _) {
              final l = _activeLesson;
              if (l == null) return const SizedBox.shrink();
              return LessonCard(
                lesson: l,
                onClose: _dismissLesson,
              );
            },
          ),
        ),
      ),
    );
  }
}
