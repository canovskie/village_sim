part of '../main.dart';

/// KURULUŞ ÖĞRETİCİSİ — "şimdi ne yapacağım"ın ekrandaki karşılığı.
///
/// Bu dosya adımı bir HEDEFE çevirir ve hedefi kademeli çözer: oyuncu bir
/// tıklık ilerleyince işaret kendiliğinden bir sonraki halkaya geçer. Kimseyi
/// kilitlemez (vinyet tıklamayı geçirir), kimseyi zorlamaz (karta dokunmak
/// kapatır).
///
/// KAPSAM — İKİ KEZ DARALDI, İKİ KEZ AYNI SEBEPLE.
///
/// Önce "kademe 0"dı, yani kuruluşun dokuz adımının dokuzu da rehberliydi:
/// oyuncu köyü kurarken sürekli birinin parmağını izliyordu, öğretici
/// öğretmiyor EŞLİK EDİYORDU. Şimdi kapsam adımın kendisinde yazıyor
/// ([Quest.guided]) ve yalnız DÖRT adım rehberli — dördü de kendi başına
/// bulunamayacak şeyler. Gerisi o dördünün tekrarı; orada işaret öğretmez,
/// dırdır eder.
///
/// İkinci daralma iş vermeydi: "bir köylüye tıkla, İŞ bölümünden Toplayıcı de"
/// zinciri tamamen kalktı, çünkü artık köy kadrosunu kendi kuruyor
/// (bkz. scene_jobs `_foragerTarget`). Öğretilecek bir şey kalmayınca
/// öğreten katman da kalkar.
extension _SceneGuide on _VillageSceneState {
  /// Yeni adımdan sonra spotun EN AZ bekleyeceği süre. Asıl bekleme kapısı
  /// aşağıdaki konuşma gatei: önce köyün sesi, SONRA parmak. İlk denemede spot
  /// replik hâlâ ekrandayken açıldı ve kendi karartması cümleyi okunmaz yaptı —
  /// iki anlatım aynı anda konuşunca ikisi de kaybediyor.
  ///
  /// TEMPO DERSİ: bu pay 1.4 sn'ydi ve `_kQuestVoiceLife` (5.0) + gate (0.8) ile
  /// birleşince her adım arasına ~4.2 sn ölü zaman koyuyordu. On iki adımlık
  /// kuruluşta bu bir dakikaya yakın bekleme demek: oyuncu ne yapacağını
  /// biliyor, öğretici hâlâ konuşuyor. Sıra doğru (ses → parmak), süre yanlıştı.
  static const double _kGuideLead = 0.45;

  /// Konuşma bu eşiğin altına inmeden spot açılmaz (sönüş payı).
  static const double _kGuideVoiceGate = 0.8;

  /// Adım repliğinin ömrü. Cümleler tek satır (bkz. [Quest.voice]) — okumak
  /// 2 sn sürüyor, 5 sn ekranda tutmak beklemek demekti. Balon zaten yumuşak
  /// sönüyor; oyuncu erken davranırsa spot onu beklemez.
  static const double _kQuestVoiceLife = 2.8;

  /// Öğretici bu adıma eşlik ediyor mu — kapsam artık görevin kendisinde
  /// yazıyor (bkz. [Quest.guided]), sahnede değil.
  bool get _guideActive => _stepCache?.quest.guided ?? false;

  // ── Hedef çözümü ─────────────────────────────────────────────────────────
  //
  // Tek kural: HER ZAMAN sıradaki TEK tıklamayı göster. Oyuncu onu yapınca
  // durum değişir ve bir sonraki çağrı doğal olarak bir sonraki halkayı
  // döndürür. "Şunu, sonra şunu, sonra şunu" diyen bir öğretici okunmaz.
  GuideCue? _resolveGuideCue() {
    final q = _stepCache?.quest;
    if (q == null || !q.guided) return null;

    // Sinematik/karar/modal önde — öğretici onların üstüne çıkmaz. Bu liste
    // Stack sırasıyla el ele gider: spot katmanı defterin üstünde çizildiği
    // için modalların da üstünde; "hiç çizilmesin" kararı burada verilir.
    if (_activeCutscene != null ||
        _pendingChoice != null ||
        _petitionModalOpen ||
        _lawRitual != null ||
        _imperialDemand != null) {
      return null;
    }

    // ── 1) YÖNETİŞİM ADIMI ────────────────────────────────────────────────
    // İki halka: Defter'i aç → KANUNNAME rafına geç. (Mühür ânı rafın içinde;
    // orası artık oyuncunun kendi kararı, işaret oraya kadar götürür.)
    if (q.uiTarget == QuestUi.lawBook) {
      if (_ledgerSection == null) {
        return const GuideCue(
          anchorId: GuideAnchors.gateDefter,
          title: 'Defter\'i aç',
          body: 'Köyün yazılı işleri burada döner: divan, kanunname, nüfus. '
              'Berat da buradan çıkar.',
        );
      }
      if (_ledgerSection == LedgerSection.kanun) return null; // raf açık, yol belli
      const railId = GuideAnchors.sectionKanun;
      if (!GuideAnchors.has(railId)) return null; // telefon rayı çapasız
      return const GuideCue(
        anchorId: railId,
        title: 'Kanunname',
        body: 'Hükümler bu rafta. Birini seç ve mührü bas — geri alınmaz, '
            'köyün huyu o satırdan başlar.',
      );
    }

    // ── 2) İNŞA ADIMI ─────────────────────────────────────────────────────
    // İki halka: kartı seç → yerini göster. (Kart görünmüyorsa önce sekme.)
    final bt = _stepBuildTarget;
    if (bt != null) {
      final label = kBuildingMeta[bt]?.label ?? 'yapı';
      if (_placing == bt) {
        final heart = _villageHeart();
        final at = heart == null ? null : _guideScreenOf(heart.$1, heart.$2);
        if (at == null) return null;
        return GuideCue(
          spot: at,
          radius: 62,
          title: 'Yerini seç',
          body: 'Boş bir kareye tıkla, $label oraya kurulsun. Hayalet '
              'kırmızıysa orası uygun değil — biraz yana kay.',
        );
      }
      final cardId = GuideAnchors.build(bt.name);
      if (GuideAnchors.has(cardId)) {
        return GuideCue(
          anchorId: cardId,
          title: 'Kartı seç',
          body: _completedQuests.isEmpty
              // İLK ADIM aynı zamanda tek öğretme fırsatı: haritada gezmeyi de
              // burada söyleriz, ayrı bir "kamera dersi" ekranı açmadan.
              ? '$label kartına tıkla, sonra haritada bir yer göster. '
                  'Haritayı sürükleyerek gezebilir, tekerlekle yaklaşabilirsin.'
              : '$label kartına tıkla; ardından kurulacağı yeri göstereceksin.',
        );
      }
      final cat = kBuildingCategory[bt];
      if (cat != null) {
        return GuideCue(
          anchorId: GuideAnchors.buildTab(cat.name),
          title: 'Kategoriyi aç',
          body: '$label kartı "${cat.label}" bölümünde. Sekmeye geç.',
        );
      }
      return null;
    }

    // ── 3) HEDEFSİZ ADIM ──────────────────────────────────────────────────
    // "İlk geceyi çıkar" gibi bekleme adımları: gösterilecek düğme yok.
    // Spot açmayız — olmayan bir yeri işaret eden öğretici güven kaybettirir.
    return null;
  }

  /// Izgara → ekran (zoom dahil). Künye katmanıyla aynı dönüşüm; iki ayrı
  /// hesap iki ayrı yere işaret eder.
  Offset? _guideScreenOf(double gx, double gy) {
    if (_viewSize.width <= 0 || _viewSize.height <= 0) return null;
    final center = Offset(_viewSize.width / 2, _viewSize.height / 2);
    final p = (gridToScreen(gx, gy, _viewSize, _camera) - center) * _zoom +
        center;
    // Ekran dışındaysa spot açma — karartılmış bir ekranda görünmeyen bir
    // delik, oyuncuya "bir şey oldu ama nerede" dedirtir. Kamera zaten
    // hedefe kayıyor; bir sonraki karede içeri girer.
    if (p.dx < 40 || p.dx > _viewSize.width - 40) return null;
    if (p.dy < 40 || p.dy > _viewSize.height - 40) return null;
    return p;
  }

  // ── Sürüş ────────────────────────────────────────────────────────────────

  // ── Köyün sesi ───────────────────────────────────────────────────────────

  /// Bir kurucu tek cümle söyler. Boş cümle/ölü konuşmacı sessizce düşer —
  /// kurucu ölmüşse adım isimsiz devam eder, kaybolmaz.
  void _questSpeak(VillagerEntity? who, String? line, {double life = 7.5}) {
    if (who == null || line == null || line.isEmpty) return;
    if (who.isDying) return;
    _questVoiceWho = who;
    _questVoiceLine = line;
    _questVoiceLeft = life;
    _questVoiceLife = life;
  }

  /// Konuşma balonunun 0→1 görünürlüğü (giriş 0.35 sn, çıkış 0.9 sn).
  double get _questVoiceOpacity {
    if (_questVoiceLeft <= 0) return 0;
    final elapsed = _questVoiceLife - _questVoiceLeft;
    final fadeIn = (elapsed / 0.35).clamp(0.0, 1.0);
    final fadeOut = (_questVoiceLeft / 0.9).clamp(0.0, 1.0);
    return fadeIn < fadeOut ? fadeIn : fadeOut;
  }

  void _tickGuide(double dt) {
    // Konuşma sayacı öğreticiden BAĞIMSIZ sönümlenir: kuruluşun son adımı
    // biterken kademe atlar ve `_guideActive` düşer — cümle ekranda donmasın.
    if (_questVoiceLeft > 0) {
      _questVoiceLeft -= dt;
      if (_questVoiceLeft <= 0) {
        _questVoiceWho = null;
        _questVoiceLine = '';
      }
    }
    final id = _stepCache?.quest.id ?? '';

    // Adım değişti → açık spotu indir, yenisi için nefes payı ver.
    // İstek (`_guideWanted`) ile açılış AYRI: hedef o an çözülemiyor olabilir
    // (kamera kayıyor, panel kapalı, köylü ekran dışında). İstek durur,
    // açılış hedef belirince olur.
    //
    // BU BLOK ÖĞRETİCİDEN BAĞIMSIZ ÇALIŞIR. Kapsam dörde inince ilk hâlinde
    // `_guideActive` kapısının ARKASINDA kaldı ve rehbersiz adımların
    // cümlelerini de sustururdu: köy artık yalnız dört adımda konuşurdu.
    // Oysa spot ile ses ayrı iki şey — biri yol gösterir, öbürü köyü canlı
    // tutar. Ses HER adımda düşer, parmak yalnız dört adımda çıkar.
    if (id != _guideStepId) {
      _guideStepId = id;
      _guideDelay = _kGuideLead;
      _guideWanted = _guideActive && id.isNotEmpty && !_guideShown.contains(id);
      _guideOpen = false;
      // ÖNCE KÖY KONUŞUR. Adımı isteyen kurucu cümlesini söyler ve görünür
      // biçimde umutlanır; spot ancak o cümle okunduktan sonra gelir.
      final q = _stepCache?.quest;
      if (q != null) {
        final who = _questSpeaker(q);
        _questSpeak(who, q.voice, life: _kQuestVoiceLife);
        who?.feel(NpcEmotion.wonder, 4, moodDelta: 0.03);
      }
    }
    if (!_guideActive) {
      if (_guideOpen) _guideOpen = false;
      return;
    }
    if (id.isEmpty) return;

    if (_guideOpen) {
      // Oyuncu isteneni yaptıysa hedef kaybolur → spot kendini kapatır.
      if (_resolveGuideCue() == null) _guideOpen = false;
      return;
    }

    if (!_guideWanted) return;
    // Dilekçe/modal açıkken öğretme — oyuncu başka bir işin içinde.
    //
    // DEFTER İSTİSNA: berat adımının hedefi Defter'in İÇİNDE (kanunname rafı).
    // Genel kural burada uygulansaydı öğretici tam gideceği yerde susardı.
    final inLedgerStep = _stepCache?.quest.uiTarget == QuestUi.lawBook;
    if ((_ledgerSection != null && !inLedgerStep) ||
        _petitionModalOpen ||
        _imperialDemand != null) {
      return;
    }
    _guideDelay -= dt;
    if (_guideDelay > 0) return;
    // Köylü hâlâ konuşuyorsa bekle — spotun karartması cümleyi yutar.
    if (_questVoiceLeft > _kGuideVoiceGate) return;
    // Hedef henüz yoksa İSTEK DURUR: bir sonraki karede yeniden denenir.
    if (_resolveGuideCue() == null) return;
    _guideShown.add(id);
    _guideWanted = false;
    _guideOpen = true;
  }

  /// "Göster" düğmesi — kamerayı adımın hedefine götürür, spotu açar.
  ///
  /// Kamera kanalı "İzle" ile aynı (`_watchLeft`): iki ayrı kamera sürücüsü
  /// aynı kareyi çekiştirir. Oyuncu ekrana dokununca kilit zaten düşüyor.
  void _guideShow() {
    final q = _stepCache?.quest;
    if (q == null) return;
    // Hedef: dünyadaki işaret varsa oraya, yoksa görevi isteyen köylüye.
    final beacon = _stepBeacon;
    if (beacon != null) {
      _watchX = beacon.$1;
      _watchY = beacon.$2;
      _watchLeft = 2.2;
    } else {
      final who = _questSpeaker(q);
      if (who != null) {
        _watchX = who.gridX;
        _watchY = who.gridY;
        _watchLeft = 2.2;
      }
    }
    // Kamera kayarken spot açılırsa delik ekranda gezinir — kayış otursun,
    // sonra tick açsın (hedef çözülür çözülmez).
    _guideWanted = true;
    _guideDelay = 0.5;
    _guideOpen = false;
  }

  void _guideDismiss() {
    _guideOpen = false;
  }

  /// Köyün sesi katmanı — konuşanın başının üstünde tek cümle.
  ///
  /// Künye katmanıyla AYNI dönüşümü kullanır (zoom dahil); iki ayrı hesap
  /// cümleyi köylünün yanına değil yakınına koyar. Konuşan içeri girdiyse
  /// ya da ekran dışına çıktıysa çizilmez — sahipsiz bir cümle havada kalmaz.
  Widget buildQuestSpeech() {
    return Positioned.fill(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: ListenableBuilder(
            listenable: _frame,
            builder: (_, _) {
              final who = _questVoiceWho;
              final op = _questVoiceOpacity;
              if (who == null || op <= 0.01 || _questVoiceLine.isEmpty) {
                return const SizedBox.shrink();
              }
              if (who.isInsideBuilding || !_villagers.contains(who)) {
                return const SizedBox.shrink();
              }
              final at = _guideScreenOf(who.renderX, who.renderY);
              if (at == null) return const SizedBox.shrink();
              final x = _speechX(at.dx, at.dy);
              // Sprite tepesi ayak noktasından ~126 birim yukarıda (künye
              // katmanından ölçülü sabit) — cümle şapkanın içine düşmesin.
              final sc = kCharScale * who.lifeStage.renderScale * _zoom;
              return Stack(
                children: [
                  WorldSpeech(
                    anchor: Offset(
                      x,
                      (at.dy - 126 * sc - 10).clamp(56.0, _viewSize.height),
                    ),
                    name: who.name,
                    line: _questVoiceLine,
                    opacity: op,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Cümlenin yatay yeri — köylüyü takip eder ama SAĞ ÜSTTEKİ GÖREV KARTININ
  /// altına girmez. İlk denemede tam oraya denk geldi ve cümlenin ortasındaki
  /// üç kelime kartın arkasında kayboldu: metin sağlamdı, görünen yarısı
  /// anlamsızdı. Kartın yaşadığı bantta (üst ~380px) tavan kartın soluna çekilir.
  double _speechX(double x, double y) {
    const half = 132.0; // WorldSpeech maxWidth 260 / 2 + pay
    const lo = half + 12;
    var hi = _viewSize.width - half - 12;
    if (y < 380) hi = _viewSize.width - 262 - half;
    if (hi <= lo) return x;
    return x.clamp(lo, hi).toDouble();
  }

  /// Spot katmanı — Stack'te Köy Defteri'nin ÜSTÜNDE (bkz. main.dart'taki
  /// yerleşim notu). Hangi durumlarda hiç çizilmeyeceği [_resolveGuideCue]'nun
  /// erken çıkışlarında tek yerden karara bağlanır.
  Widget buildGuideSpotlight() {
    return Positioned.fill(
      child: RepaintBoundary(
        child: ListenableBuilder(
          listenable: _frame,
          builder: (_, _) {
            if (!_guideOpen) return const SizedBox.shrink();
            // Hedef her karede yeniden çözülür: oyuncu bir tıklık ilerleyince
            // (köylüyü seçti, Detay'a bastı) spot kendiliğinden sonraki halkaya
            // geçer — yeni bir tetik yazmaya gerek yok.
            final cue = _resolveGuideCue();
            if (cue == null) return const SizedBox.shrink();
            return GuideSpotlight(
              cue: cue,
              onDismiss: () => setStateHere(_guideDismiss),
            );
          },
        ),
      ),
    );
  }
}
