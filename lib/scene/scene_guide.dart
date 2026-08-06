part of '../main.dart';

/// KURULUŞ ÖĞRETİCİSİ — "şimdi ne yapacağım"ın ekrandaki karşılığı.
///
/// Sorun şuydu: kuruluş adımlarının metni doğruydu ama oyuncunun izleyeceği
/// YOL görünmüyordu. "Bir köylüye tıkla, İŞ bölümünden Toplayıcı de" cümlesi
/// üç ayrı tıklama tarif ediyor (köylüyü seç → Detay → rol) ve üçü de kendini
/// göstermiyor. Üstelik o cümle oyunda hiç çizilmiyordu bile: sağ üstteki
/// takipçi yalnız görev BAŞLIĞINI gösteriyor, ipucu Defter'in içinde kalıyordu.
///
/// Bu dosya adımı bir HEDEFE çevirir ve hedefi kademeli çözer: oyuncu bir
/// tıklık ilerleyince spot kendiliğinden bir sonraki halkaya geçer. Kimseyi
/// kilitlemez (karartma tıklamayı geçirir), kimseyi zorlamaz (Anladım hep var).
///
/// KAPSAM: yalnız kuruluş (kademe 0). Sonrası oyuncunun zaten bildiği
/// fiillerin tekrarı; orada spot öğretmez, dırdır eder.
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

  /// Öğretici çalışıyor mu — köy kendi ayakları üstünde durunca susar.
  bool get _guideActive => _charterTier == 0;

  /// Bu iş yerinin kartı şu an seçili mi. Bina iş yerleri binanın kendi
  /// kartından, binasızlar `_selectedSiteId`'den açılır — öğreticinin
  /// "seçildi mi" sorusu ikisini de tek yerden sormalı.
  bool _isSiteSelected(WorkSite s) =>
      _selectedSiteId == s.id ||
      (s.source != null && identical(_selectedBuilding, s.source));

  /// ÖĞRETİCİNİN gösterdiği iş yeri — paneller bu kimliği alıp o yerin ilk boş
  /// yuvasını spot hedefi olarak işaretler. Öğretici susmuşsa ya da adımın iş
  /// hedefi yoksa null (yuvalar sade kalır).
  String? get _guidedSiteId {
    if (!_guideActive) return null;
    final job = _stepJobTarget;
    if (job == null) return null;
    return _siteForRole(job)?.id;
  }

  // ── Hedef çözümü ─────────────────────────────────────────────────────────
  //
  // Tek kural: HER ZAMAN sıradaki TEK tıklamayı göster. Oyuncu onu yapınca
  // durum değişir ve bir sonraki çağrı doğal olarak bir sonraki halkayı
  // döndürür. "Şunu, sonra şunu, sonra şunu" diyen bir öğretici okunmaz.
  GuideCue? _resolveGuideCue() {
    final q = _stepCache?.quest;
    if (q == null) return null;

    // Sinematik/karar ekranı önde — öğretici onların üstüne çıkmaz.
    if (_activeCutscene != null || _pendingChoice != null) return null;

    // ── 1) İŞ VERME ADIMI ─────────────────────────────────────────────────
    //
    // Üç halka: İŞ YERİNİ seç → kartı aç → boş yuvayı doldur.
    //
    // Eskiden zincir kişiden başlıyordu (köylüyü seç → kartı aç → rolü ver).
    // İş verme yere taşınınca zincirin başı da yere taşındı — ve öğretici
    // artık oyuncuya doğru soruyu öğretiyor: "kim boşta?" değil, "hangi yer el
    // istiyor?".
    //
    // YERİ YOKSA BU HALKA ATLANIR. "Baltayı ormana sok" adımı hem kereste
    // kampını diktirir hem de kadro ister; kamp yokken burada durup null
    // dönseydik öğretici tam o anda susardı — oysa söylenecek şey var:
    // önce kampı kur. Aşağıdaki inşa halkası devralsın diye düşüyoruz.
    final job = q.jobTarget;
    final jobSite = job == null ? null : _siteForRole(job);
    if (job != null && jobSite != null) {
      final site = jobSite;
      if (_isSiteSelected(site)) {
        if (_detailExpanded) {
          return GuideCue(
            anchorId: GuideAnchors.slot(job.name),
            title: 'Bir el ver',
            body: 'Boş yuvaya bas. ${site.label} bir el istiyor; köy oraya en '
                'yakın boş köylüyü yollar.',
          );
        }
        return GuideCue(
          anchorId: GuideAnchors.command('Detay'),
          title: 'Kartı aç',
          body: '${site.label} seçili. "Detay"a bas — kadro kartın içinde.',
        );
      }
      final at = _guideScreenOf(site.cx, site.cy);
      if (at == null) return null;
      return GuideCue(
        spot: at,
        radius: 58,
        title: '${site.label} el bekliyor',
        body: 'Işığın yandığı yere tıkla. Köyde her işin bir yeri var; '
            'kadroyu oradan verirsin.',
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
    if (!_guideActive) {
      if (_guideOpen) _guideOpen = false;
      return;
    }
    final id = _stepCache?.quest.id ?? '';

    // Adım değişti → açık spotu indir, yenisi için nefes payı ver.
    // İstek (`_guideWanted`) ile açılış AYRI: hedef o an çözülemiyor olabilir
    // (kamera kayıyor, panel kapalı, köylü ekran dışında). İstek durur,
    // açılış hedef belirince olur.
    if (id != _guideStepId) {
      _guideStepId = id;
      _guideDelay = _kGuideLead;
      _guideWanted = id.isNotEmpty && !_guideShown.contains(id);
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
    if (id.isEmpty) return;

    if (_guideOpen) {
      // Oyuncu isteneni yaptıysa hedef kaybolur → spot kendini kapatır.
      if (_resolveGuideCue() == null) _guideOpen = false;
      return;
    }

    if (!_guideWanted) return;
    // Defter/dilekçe/modal açıkken öğretme — oyuncu başka bir işin içinde.
    if (_ledgerSection != null || _petitionModalOpen || _imperialDemand != null) {
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
      final who = q.jobTarget != null ? _stepVillager() : _questSpeaker(q);
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

  /// Spot katmanı — Stack'te PANELLERİN ÜSTÜNDE durmalı: iş verme adımı köylü
  /// kartının İÇİNDEKİ rol düğmesini gösterir, altta kalsa deliğin içi karanlık
  /// olurdu. Modalların (dilekçe/karar/defter) altında: `_tickGuide` zaten
  /// onlar açıkken spot açmaz.
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
