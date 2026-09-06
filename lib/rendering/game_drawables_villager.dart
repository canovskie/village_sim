part of 'game_painter.dart';

/// KÖYLÜ DRAWABLE — köylünün sahnedeki çizimi: gövde, iş animasyonu, nefes/ıslaklık/kıvılcım/nota/baloncuk/zzz.
class _VillagerDrawable extends _Drawable {
  final VillagerEntity e;
  final double time;
  final double dayLight;
  final Season season;
  final double rainIntensity;
  final bool primitiveClothing;
  _VillagerDrawable(
    this.e,
    this.time,
    this.dayLight, {
    this.season = Season.spring,
    this.rainIntensity = 0,
    this.primitiveClothing = false,
  });
  @override
  double get depth => e.depth;
  @override
  WorkerEntity? get actor => e.isInsideBuilding ? null : e;
  @override
  void draw(Canvas canvas, Size size, Offset camera) {
    if (e.isInsideBuilding) return;

    final s = gridToScreen(e.renderX, e.renderY, size, camera);
    final porterLoad =
        e.state == VillagerState.carrying && e.carriedItem != null;
    final twoHandedItem = e.holdsItemTwoHanded;
    final hasHeldItem = porterLoad || e.prop != PropKind.none;
    // İki-elli yük sol eli de sahiplenir. Tek-elli prop ise sağ elde kalır ve
    // gece meşalesi sol elde yanmaya devam eder; yalnız prop'un kendisi meşale
    // ise ikinci bir meşale/glow çizilmez.
    final ambientTorchBlocked = twoHandedItem || e.prop == PropKind.torch;
    final jobIsActing =
        e.job?.working == true ||
        e.job?.harvesting == true ||
        e.job?.carryingWater == true;
    final wantsIdleBodyCue =
        e.wetShakeCue > 0 ||
        e.assignmentNodCue > 0 ||
        e.smithStrikeCue > 0 ||
        (!jobIsActing &&
            (e.exertionCue > 0 ||
                (e.state == VillagerState.idle &&
                    (e.mind.drive(Drive.hunger) > 0.58 ||
                        (season == Season.winter &&
                            e.mind.drive(Drive.chill) > 0.42)))));

    // Gölge — ayak altında, torch glow'un da altında.  Boyut karakter
    // ölçeğiyle (yaşam-evresi dahil) orantılı. (Ölüm dalı kendi solan gölgesini
    // çizer → burada atla.)
    if (!e.isDying) {
      _drawCharShadow(canvas, s.dx, s.dy, kCharScale * e.displayScale);
    }

    // Geçici vurgu halkası — HUD'dan "evsizleri göster" gibi tetiklenince
    // ayak altında nabız atan kehribar halka (son saniyede solar).
    if (e.highlightTimer > 0) {
      final pulse = 0.5 + 0.5 * sin(time * 6.0);
      final fade = e.highlightTimer.clamp(0.0, 1.0);
      final rw = 30.0 + 4.0 * pulse;
      final ring = Rect.fromCenter(
        center: Offset(s.dx, s.dy),
        width: rw,
        height: rw * 0.46,
      );
      _pHighlightRing.color = const Color(
        0xFFFFD25A,
      ).withValues(alpha: (0.45 + 0.4 * pulse) * fade);
      canvas.drawOval(ring, _pHighlightRing);
    }

    // Lokal meşale glow + alev — sprite'tan ÖNCE çizilir ki karakter üstüne
    // binsin. Entity.torchLevel tek karar noktası; 0..1 fade. Glow konumu
    // meşalenin GERÇEK ucunda (sağ omuz +x, baş üstü -68 yüksekliği — char
    // scale * lifeStage.renderScale ile ölçeklenmiş).
    final torchLv = e.torchLevel;
    final showTorch = torchLv > 0.02 && !ambientTorchBlocked;
    if (showTorch) {
      final charScaleNow = kCharScale * e.displayScale;
      final shoulderX = (e.effectiveFacingRight ? 1 : -1) * 5.0 * charScaleNow;
      final headY = -64 * charScaleNow;
      ToolRenderer.drawTorchGlow(
        canvas,
        s.dx + shoulderX,
        s.dy + headY,
        time,
        e.torchPhase,
        intensity: torchLv,
      );
    }

    // UYKU — yatay poz, yastık + battaniye + kapalı göz, hafif breath.
    //
    // YATMA/KALKMA GEÇİŞİ DENENDİ VE VAZGEÇİLDİ (2026-08-06). İki yol da
    // filmstrip'te çürüdü (`lib/tools/sleep_capture_main.dart`):
    //   1. Ayakta gövdeyi ayak ucundan devirmek → gövde yatay hâle gelirken
    //      yerden havada kalıyor.
    //   2. Erken takas + squash/stretch → takas anında tam boy gövdeden minik
    //      bir yığına düşüyor, aradaki ezilme gözle görülmüyor bile.
    // Kök sebep ikisinde de aynı: [CharacterRenderer.drawSleeping] ayakta
    // çizimden ÇOK daha küçük ve bambaşka bir kompozisyon. İki çizim
    // birbirine harmanlanamaz — geçiş isteniyorsa önce uyku çizimi ayakta
    // gövdenin oranlarına göre YENİDEN ÇİZİLMELİ. Harness o karşılaştırmayı
    // yan yana basar. O yapılana kadar anlık geçiş DAHA İYİ: yanlış bir
    // animasyon, animasyonsuzluktan daha çok göze batıyor.
    if (e.isSleeping && !e.isInsideBuilding && !e.isDying) {
      final sleepScale = kCharScale * e.displayScale;
      canvas.save();
      canvas.translate(s.dx, s.dy);
      canvas.scale(sleepScale, sleepScale);
      CharacterRenderer.drawSleeping(
        canvas,
        e.type,
        walkPhase: e.walkPhase,
        flipX: !e.facingRight,
        primitiveClothing: primitiveClothing,
      );
      canvas.restore();
      _drawZzz(canvas, s);
      return;
    }

    // Ölüm — collapse + fade. Anlık silinmek yerine ayakları kesilir gibi yana
    // devrilip yere yığılır ve solar (ayak ucu pivot). Gölge de küçülüp söner.
    if (e.isDying) {
      final dp = e.dyingProgress;
      final cs = kCharScale * e.displayScale;
      final dir = e.effectiveFacingRight ? 1.0 : -1.0;
      // İlk yarı: dizler çöker + yana devrilir. İkinci yarı: yerde solar.
      final topple = dp * 1.4 * dir; // ~80° yana yatış
      final sink = dp * 6.0 * cs; // yere oturma
      final squash = 1.0 - 0.18 * dp; // dikeyde hafif ezilme
      final alpha = (dp < 0.5 ? 1.0 : 1.0 - (dp - 0.5) / 0.5).clamp(0.0, 1.0);
      _drawCharShadow(canvas, s.dx, s.dy, cs * (1.0 - 0.45 * dp));
      canvas.saveLayer(
        Rect.fromCenter(center: s, width: 140 * cs, height: 180 * cs),
        Paint()..color = Color.fromARGB((alpha * 255).round(), 255, 255, 255),
      );
      canvas.translate(s.dx, s.dy + sink);
      canvas.rotate(topple);
      canvas.scale(cs, cs * squash);
      CharacterRenderer.draw(
        canvas,
        e.type,
        flipX: !e.effectiveFacingRight,
        walkPhase: e.walkPhase,
        moveIntensity: 0,
        carrying: false,
        torchLevel: 0,
        torchPhase: e.torchPhase,
        visual: e.visual,
        time: time,
        stage: e.lifeStage,
        costume: e.costume,
        wardrobe: e.wardrobe,
        commander: e.imperialCommander,
        attacking: e.imperialAttacking,
        combatSwing: e.battleSwing,
        houseAccent: houseAccentColor(e.surname),
        // Ölürken de köyün kumaşı üstünde; örtünme YOK (yerde yatan gövdede
        // omuz bandı yanlış yere düşerdi).
        provision: e.provision,
        primitiveClothing: primitiveClothing,
      );
      canvas.restore();
      return;
    }

    // Üstlenilmiş iş (inşaat/tarla/maden…) — köylüyü baz meslek yerine iş
    // sprite'ıyla (alet + aksiyon pozu) çiz. Kimlik (yüz/saç) e.visual'dan gelir,
    // yani isimli köylü doğru yüzle görünür. Gölge/torch yukarıda çizildi.
    // Yük/prop taşıyan işçi generic karakter yoluna düşer: o yol eldeki
    // nesneyi CharacterRenderer'ın torso transformuna bağlar. Erken return
    // eskiden kendi ürününü taşıyan işçiyi tamamen yüksüz, çiçekçi/toplayıcıyı
    // sepetsiz ve sağım yapan çobanı kovasız çiziyordu.
    if (e.battleHealth == null &&
        e.job != null &&
        _jobHasSprite(e.job!.role) &&
        e.wardrobe == NpcWardrobe.standard &&
        !e.isCarrying &&
        e.prop == PropKind.none &&
        !wantsIdleBodyCue) {
      _drawJobVillager(canvas, e, s);
      return;
    }

    // Yaşam evresine göre boy ölçeği — çocuk küçük, yetişkin tam, yaşlı hafif.
    final charScale = kCharScale * e.displayScale;
    // Dans → gerçek zıplama. NPC her vuruşta yere iner çıkar.
    double danceBounce = 0;
    double danceSway = 0;
    if (e.activity == VillagerActivity.dance) {
      // 2 Hz beat — sin'in mutlak değeri ile sürekli pozitif zıplama.
      danceBounce = sin(time * 6.0 + e.gridX * 1.1).abs() * 4.0;
      danceSway = sin(time * 3.0 + e.gridX * 0.7) * 0.20;
    }
    // Sohbet → konuşma jesti: konuşan sırasında belirgin baş-gövde "nod",
    // dinlerken hafif. Karşılıklı sohbetin canlı görünmesini sağlar.
    double talkBob = 0;
    double talkSway = 0;
    if (e.activity == VillagerActivity.chat) {
      final (speaking, _) = e.convoNow();
      final amp = speaking ? 1.0 : 0.3;
      talkBob = sin(time * 9.0 + e.gridX * 1.3).abs() * 1.5 * amp;
      talkSway = sin(time * 4.5 + e.gridX) * 0.05 * amp;
    }
    // Mood postürü — neşeli köylü dik + hafif yukarı, üzgün çökük + hafif aşağı.
    // Tüm yürüyen/duran NPC'ye uygulanır (uyku erken return; etkilenmez).
    double moodLift = 0;
    double moodScaleY = 1.0;
    if (e.mood > 0.15) {
      final m = e.mood.clamp(0.0, 1.0);
      moodScaleY = 1.0 + 0.03 * m;
      moodLift = 0.9 * m;
    } else if (e.mood < -0.15) {
      final m = (-e.mood).clamp(0.0, 1.0);
      moodScaleY = 1.0 - 0.06 * m;
      moodLift = -0.9 * m;
    }
    // Ateş başı oturma — sprite'ı dikeyde sıkıştırıp aşağı kaydırarak
    // "çömelme" hissi. Anlatıcıda hafif öne-arka sallanma.
    double sitYOff = 0;
    const double sitYScale = 1.0;
    double sitSway = 0;
    CharPose charPose = CharPose.normal;
    final isSeated =
        e.isSeatedAtFire &&
        (e.activity == VillagerActivity.warm ||
            e.activity == VillagerActivity.storytelling ||
            e.activity == VillagerActivity.listening);
    if (isSeated) {
      // Gerçek oturma duruşu — kaba squash değil. Duruşa göre yere oturt
      // (sprite'ı aşağı kaydır), uzuv pozunu CharacterRenderer halleder.
      switch (e.firePose) {
        case FirePose.sit:
          charPose = CharPose.sit;
          sitYOff = 9;
        case FirePose.kneel:
          charPose = CharPose.kneel;
          sitYOff = 7;
        case FirePose.mourn:
          charPose = CharPose.mourn;
          sitYOff = 10;
      }
      if (e.activity == VillagerActivity.storytelling) {
        sitSway = sin(time * 2.0 + e.gridX) * 0.06;
      }
    }
    // Tam-gövde iş duruşu (diz çökme / yere çökme — bkz. scene_vignette): uzuv
    // açılarını CharacterRenderer devralır. Ayakta gövdeye uygulanan mikro
    // tweak'ler (duygu sıçraması, bearing eğilmesi) bu duruşu BOZAR — çöken
    // adam sevinçten zıplamaz. isSeated ile aynı kapıdan geçer.
    final actFullBody = e.actPose != null && actPoseIsFullBody(e.actPose!);
    final bodyFree = !isSeated && !actFullBody;

    // ANLIK HÂL — sayısal ihtiyacı ikonla adlandırmak yerine bedende göster.
    // Yalnız boş/serbest gövdede çalışır; kavga, tören, iş ve taşıma pozlarını
    // ele geçirmez. Yağmur silkelemesi kapıya varışta özel olarak tetiklenir.
    final quietForCue =
        bodyFree &&
        e.activity == VillagerActivity.none &&
        e.actPose == null &&
        !e.isWalking &&
        !hasHeldItem;
    final hunger = e.mind.drive(Drive.hunger);
    final hungerBeat = sin(
      time * 1.45 + e.personalitySeed * 0.017,
    ).clamp(0.0, 1.0);
    final hungerAmount = quietForCue
        ? (((hunger - 0.58) / 0.42).clamp(0.0, 1.0) * hungerBeat)
        : 0.0;
    final chillAmount = quietForCue && season == Season.winter
        ? ((e.mind.drive(Drive.chill) - 0.42) / 0.58).clamp(0.0, 1.0)
        : 0.0;
    final exertionAmount = quietForCue
        ? (e.exertionCue / 1.35).clamp(0.0, 1.0)
        : 0.0;
    final wetAmount = bodyFree ? (e.wetShakeCue / 0.85).clamp(0.0, 1.0) : 0.0;
    final assignmentAmount = bodyFree
        ? (e.assignmentNodCue / 0.85).clamp(0.0, 1.0)
        : 0.0;
    final smithAmount = bodyFree && e.type == VillagerType.blacksmith
        ? e.smithStrikeCue.clamp(0.0, 1.0)
        : 0.0;
    double stateShove = 0, stateLift = 0, stateRot = 0, stateScaleY = 1.0;
    if (chillAmount > 0) {
      stateShove +=
          sin(time * 27.0 + e.personalitySeed * 0.11) * 0.9 * chillAmount;
      stateScaleY -= 0.045 * chillAmount;
      stateLift -= 0.6 * chillAmount;
    }
    if (hungerAmount > 0) {
      stateScaleY -= 0.055 * hungerAmount;
      stateLift -= 0.9 * hungerAmount;
      stateRot += 0.055 * hungerAmount * (e.effectiveFacingRight ? 1.0 : -1.0);
    }
    if (exertionAmount > 0) {
      // Ağır yük/iş bitti: önce doğrul, sonra yavaşça normal nefese dön.
      stateScaleY += 0.035 * exertionAmount;
      stateLift += 0.8 * exertionAmount;
    }
    if (wetAmount > 0) {
      stateShove +=
          sin(time * 39.0 + e.personalitySeed * 0.07) * 2.1 * wetAmount;
      stateRot += sin(time * 31.0) * 0.065 * wetAmount;
    }
    if (assignmentAmount > 0) {
      final nod = sin((1.0 - assignmentAmount) * pi * 2).abs();
      stateScaleY -= nod * 0.035;
      stateLift -= nod * 0.7;
    }

    // Duygu gövde dili — emoji DEĞİL, POSTÜR: sevinç sıçrar, yas çöküp öne
    // eğilir, korku titreyip kaçınır, hayranlık doğrulur, sevgi yumuşak salınır.
    // emotionIntensity ile başta zirve sonra söner (refleks gibi).
    // Oturanlarda duygu firePose ile anlatılır (ayin/yas/otur) → emotion pozu
    // yalnız ayaktakilere uygulanır.
    double emoBounce = 0, emoLift = 0, emoRot = 0, emoScaleY = 1.0;
    if (e.emotionTime > 0 &&
        e.emotion != NpcEmotion.none &&
        e.activity != VillagerActivity.dance &&
        bodyFree) {
      final k = e.emotionIntensity;
      final fdir = e.effectiveFacingRight ? 1.0 : -1.0;
      switch (e.emotion) {
        case NpcEmotion.joy:
          emoBounce =
              sin(time * 7.0 + e.gridX).abs() * 2.6 * k; // sevinç sıçraması
          emoLift = 0.6 * k;
        case NpcEmotion.love:
          emoRot = sin(time * 3.0 + e.gridX) * 0.07 * k; // yumuşak salınım
        case NpcEmotion.wonder:
          emoLift = 1.3 * k; // doğrulup yukarı bakış
          emoScaleY = 1.0 + 0.03 * k;
        case NpcEmotion.content:
          emoRot =
              sin(time * 1.6 + e.gridX) * 0.03 * k; // huzurlu hafif sallanış
        case NpcEmotion.grief:
          emoScaleY = 1.0 - 0.11 * k; // çöküş
          emoLift = -1.4 * k; // başı/gövdeyi aşağı
          emoRot = 0.06 * k * fdir; // öne eğilme
        case NpcEmotion.fear:
          emoBounce = sin(time * 22.0 + e.gridX) * 0.9 * k; // titreme
          emoRot = -0.10 * k * fdir; // geriye kaçınma
        case NpcEmotion.anger:
          emoBounce = sin(time * 18.0 + e.gridX) * 0.7 * k; // gerginlik
          emoRot = 0.05 * k * fdir; // öne yüklenme
        case NpcEmotion.none:
          break;
      }
    }
    // Yumruklaşma — gövde rakibe doğru ileri-geri saldırır (gerçek hareket,
    // emoji değil). Öfke postürüyle birleşince inandırıcı bir arbede olur.
    double brawlShove = 0;
    if (e.activity == VillagerActivity.brawling && !e.npcDueling) {
      final dir = e.effectiveFacingRight ? 1.0 : -1.0;
      brawlShove = sin(time * 13.0 + e.gridX * 1.3) * 2.6 * dir;
    }
    // SUÇ gövde dili (scene_crime) — baş üstü "suçlu" ikonu YOK; suç yalnız
    // POSTÜRDEN okunur: fail çömelip sinsice sokulur, eylem sırasında telaşla
    // kıpırdar, sonra öne atılıp kaçar; muhafız üstüne yüklenerek koşar;
    // kaçırılan kurban geriye direnip çırpınır. Ölçülü genlikler — "yukarıdan
    // izleyen" oyuncu fark etsin ama sahne cambazlığa dönmesin.
    double crimeShove = 0, crimeLift = 0, crimeRot = 0, crimeScaleY = 1.0;
    if (e.activity == VillagerActivity.prowling ||
        e.activity == VillagerActivity.committing ||
        e.activity == VillagerActivity.fleeing ||
        e.activity == VillagerActivity.chasing ||
        e.activity == VillagerActivity.abducted) {
      final cdir = e.effectiveFacingRight ? 1.0 : -1.0;
      switch (e.activity) {
        case VillagerActivity.prowling:
          crimeScaleY = 0.90; // çömelme
          crimeLift = -1.6; // alçalıp gölgeye sinme
          crimeRot = 0.09 * cdir; // öne eğik sinsi duruş
        case VillagerActivity.committing:
          crimeShove = sin(time * 17.0 + e.gridX * 1.7) * 1.5 * cdir; // telaş
          crimeScaleY = 0.94;
          crimeLift = -1.0;
        case VillagerActivity.fleeing:
          crimeLift = sin(time * 16.0 + e.gridX).abs() * 1.8; // telaşlı sıçrama
          crimeRot = 0.11 * cdir; // öne atılma
        case VillagerActivity.chasing:
          crimeLift = sin(time * 14.0 + e.gridX).abs() * 1.2;
          crimeRot = 0.09 * cdir; // öne yüklenme
        case VillagerActivity.abducted:
          crimeRot = -0.16 * cdir; // geriye direnme
          crimeShove = sin(time * 20.0 + e.gridY) * 1.2; // çırpınma
        default:
          break;
      }
    }
    // İŞ DURUŞU (bkz. scene_act) — mikro-sahnede eğilme/işleme/içme. Varış
    // noktalarını "orada duran adam" olmaktan çıkaran şey bu: kuyu başında
    // eğilen, tezgâhta iş gören, maşrapayı kaldıran gövde.
    double actLift = 0, actRot = 0, actScaleY = 1.0, actShove = 0;
    if (e.actPose != null && !isSeated) {
      // NOT: kneel/slump bu switch içinde charPose+sitYOff kurar, lift/rot
      // ÜRETMEZ — gövdeyi CharacterRenderer'a devreder.
      final adir = e.effectiveFacingRight ? 1.0 : -1.0;
      switch (e.actPose!) {
        case ActPose.stand:
          break;
        case ActPose.stoop:
          // Eğilme — gövde kısalır, öne devrilir, baş aşağı iner.
          actScaleY = 0.86;
          actLift = -3.0;
          actRot = 0.20 * adir;
        case ActPose.labor:
          // Tekrarlı el işi — ritmik öne-arkaya yüklenme.
          actShove = sin(time * 4.2 + e.gridX) * 1.3 * adir;
          actRot = (0.06 + sin(time * 4.2 + e.gridX) * 0.05) * adir;
          actScaleY = 0.96;
        case ActPose.sip:
          // İçme/yeme — hafif geriye kafa atma, yavaş ritim.
          actRot = -0.07 * adir * (0.5 + 0.5 * sin(time * 1.6 + e.gridY));
          actLift = 0.6;
        case ActPose.kneel:
          // Dizüstü — uzuvları CharacterRenderer çizer, burada yalnız gövdeyi
          // yere oturturuz (ateş başı oturmayla aynı kaydırma mantığı).
          charPose = CharPose.kneel;
          sitYOff = 7;
        case ActPose.slump:
          // Yere çökmüş/kapanmış — vinyetin en ağır jesti.
          charPose = CharPose.mourn;
          sitYOff = 10;
      }
    }

    // DURUŞ (bearing) — köyün hâlinin sürekli gövde dili (bkz. scene_pressure).
    // Anlık duygudan ayrı bir kanal: burada ikon yok, irkilme yok; yalnız
    // köylünün o dönem NASIL durduğu.
    //
    // GENLİK KALİBRASYONU: değerler 0..1 ama pratikte sert bir rejimde bile
    // ~0.5-0.7 bandında gezinir. Eski katsayılar o bantta 0.5 px eğilme / %3
    // ezilme üretiyordu — yani baskı rejimiyle hür rejim arasındaki gövde farkı
    // GÖRÜNMÜYORDU (37 px'lik NPC'de yarım piksel yok demektir). Katsayılar
    // ~2.5× artırıldı: 0.6 baskıda ~1.5 px eğilme + %7 çöküş + ~4° öne kapanma,
    // yani anlık KEDER refleksine yakın ama sürekli. Tavan (1.0) yine de kukla
    // sınırının altında kalır.
    double bearLift = 0, bearRot = 0, bearScaleY = 1.0, bearShove = 0;
    if (bodyFree) {
      final bow = e.bearingBow;
      final tense = e.bearingTense;
      final lift = e.bearingLift;
      if (bow > 0.02) {
        bearScaleY -= 0.12 * bow; // omuz düşük
        bearLift -= 2.4 * bow; // baş/gövde aşağı
        bearRot += 0.11 * bow * (e.effectiveFacingRight ? 1.0 : -1.0);
      }
      if (tense > 0.02) {
        // Gergin, düzensiz salınım — ritmi nefesten farklı olsun ki "tedirgin"
        // okunsun, "üşüyor" değil.
        bearShove += sin(time * 5.2 + e.gridY * 1.9) * 1.35 * tense;
        bearScaleY -= 0.05 * tense;
      }
      if (lift > 0.02) {
        bearScaleY += 0.07 * lift; // dik duruş
        bearLift += 1.7 * lift;
        // Yürürken adımda hafif sekme — duranda sıçratma (yerinde zıplayan
        // köylü neşeli değil, bozuk görünür).
        if (e.isWalking) {
          bearLift += sin(e.walkPhase * 2.0).abs() * 2.1 * lift;
        }
      }
      // HASTALIK — sürekli çökük, hâlsiz duruş (baş-üstü ikon DEĞİL, gövde dili).
      // Hasta köylü omuzları düşük, öne kapanmış durur; yavaş, düzensiz bir
      // titreme (nefesten farklı ritim) "iyi değil" hissini verir. Salgın ekran
      // tonu + yavaşlamayla birlikte köyün hâli gözle okunur.
      if (e.sickDays > 0) {
        bearScaleY -= 0.06; // omuzlar düşük
        bearLift -= 1.1; // baş/gövde aşağı
        bearRot += 0.06 * (e.effectiveFacingRight ? 1.0 : -1.0); // öne kapanma
        bearShove += sin(time * 2.4 + e.gridY) * 0.35; // hâlsiz salınım
      }
    }

    canvas.save();
    canvas.translate(
      s.dx + brawlShove + crimeShove + bearShove + actShove + stateShove,
      s.dy -
          danceBounce -
          talkBob -
          moodLift +
          sitYOff -
          emoBounce -
          emoLift -
          crimeLift -
          bearLift -
          actLift -
          stateLift,
    );
    if (danceSway != 0) canvas.rotate(danceSway);
    if (sitSway != 0) canvas.rotate(sitSway);
    if (talkSway != 0) canvas.rotate(talkSway);
    if (emoRot != 0) canvas.rotate(emoRot);
    if (crimeRot != 0) canvas.rotate(crimeRot);
    if (bearRot != 0) canvas.rotate(bearRot);
    if (actRot != 0) canvas.rotate(actRot);
    if (stateRot != 0) canvas.rotate(stateRot);
    // Idle micro-anim — nefes + sway, yalnız dans/oturma/sohbet yokken anlamlı
    // (idle helper'ları walking/işteyken zaten 0/1 döner).
    final calm = danceSway == 0 && sitSway == 0 && talkSway == 0;
    if (calm) {
      final swayR = e.idleSwayRotation(time);
      if (swayR != 0) canvas.rotate(swayR);
    }
    final breathY = calm ? e.idleBreathScale(time) : 1.0;
    // JEST SEÇİMİ — selam kısa ve sayaçlı, anlatım aktivitenin kendisi kadar
    // sürer. İkisi de tek kolu devralır, o yüzden selam önceliklidir: el
    // sallayan anlatıcı bir kolla iki iş yapamaz.
    final (gesture, gestureAmount) = hasHeldItem
        ? (CharGesture.none, 0.0)
        : e.waveTime > 0
        ? (CharGesture.wave, _waveEnvelope(e.waveTime))
        : e.activity == VillagerActivity.storytelling
        // Anlatımın sönüşü hikâyenin son saniyesine bağlı; kalkışı oturma
        // geçişinin içinde erir (anlatıcı zaten yeni oturmuştur).
        ? (CharGesture.tell, (e.chatBubbleTime / 1.2).clamp(0.0, 1.0))
        : smithAmount > 0.02
        ? (CharGesture.hammerStrike, smithAmount)
        : exertionAmount > 0.02
        ? (CharGesture.wipeBrow, exertionAmount)
        : hungerAmount > 0.02
        ? (CharGesture.holdStomach, hungerAmount)
        : (CharGesture.none, 0.0);
    // DÖNÜŞ — yön değişimi artık tek karede aynalanmıyor; sprite yatayda
    // daralıp öbür yöne açılıyor ([WorkerEntity.turnScaleX], ~0.22 sn).
    canvas.scale(
      charScale * e.turnScaleX,
      charScale *
          sitYScale *
          breathY *
          moodScaleY *
          emoScaleY *
          crimeScaleY *
          bearScaleY *
          actScaleY *
          stateScaleY,
    );
    // Darbe tepkisi ayak ucundan geriye sendeleme olarak okunur. Pozisyonel
    // geri itilmeyi combat motoru yapar; bu küçük gövde kırılması darbeyi
    // yürüyüşten ayırır. Yön aynalaması dönüşü de doğru tarafa çevirir.
    if (e.battleFall > 0) {
      final fall = e.battleFall;
      final eased = fall * fall * (3 - 2 * fall);
      canvas.rotate((e.effectiveFacingRight ? -1 : 1) * eased * 1.45);
      canvas.scale(1, 1 - eased * .12);
    } else if (e.imperialHit) {
      final recoil = 0.13 + sin(time * 18.0 + e.visual.blinkPhase) * 0.035;
      canvas.rotate(-recoil);
      canvas.scale(0.96, 0.985);
    }
    void drawHeldItem(Canvas heldCanvas) {
      if (porterLoad) {
        final item = e.carriedItem!;
        if (item is ResourceBox) {
          ResourceRenderer.drawCarriedBox(heldCanvas, item);
        } else if (item is HayEntity) {
          ResourceRenderer.drawCarriedHay(heldCanvas, item);
        }
        return;
      }
      PropRenderer.draw(
        heldCanvas,
        e.prop,
        // Callback CharacterRenderer'ın yön aynalamasının İÇİNDE çalışır.
        // Burada tekrar yön vermek çift aynalama üretirdi; sağ-kanonik çizim
        // gövdeyle birlikte sola çevrilir.
        facingRight: true,
        walkPhase: e.walkPhase,
        moveIntensity: e.moveIntensity,
        time: time,
        combat: e.imperialAttacking,
        combatSwing: e.battleSwing,
      );
    }

    CharacterRenderer.draw(
      canvas,
      e.type,
      flipX: !e.effectiveFacingRight,
      walkPhase: e.walkPhase,
      moveIntensity: e.moveIntensity,
      carrying: twoHandedItem,
      pose: charPose,
      torchLevel: ambientTorchBlocked ? 0 : torchLv,
      torchPhase: e.torchPhase,
      visual: e.visual,
      time: time,
      stage: e.lifeStage,
      costume: e.costume,
      wardrobe: e.wardrobe,
      commander: e.imperialCommander,
      attacking: e.imperialAttacking,
      combatSwing: e.battleSwing,
      houseAccent: houseAccentColor(e.surname),
      // KÖYÜN HÂLİ (Faz 5): kılık köyün ambarından, örtünme köylünün KENDİ
      // gerginliğinden. bearingTense'e kişisel moral ve hanenin hâli zaten
      // karışmış → şal köy ortalamasını değil bu adamı anlatır.
      provision: e.provision,
      shroud: e.bearingTense,
      primitiveClothing: primitiveClothing,
      // JEST — selam ve hikâye anlatımı GÖVDEDE oynar, başın üstünde değil.
      gesture: gesture,
      gestureAmount: gestureAmount,
      heldItem: hasHeldItem ? drawHeldItem : null,
      heldItemBehindBody: !porterLoad && e.prop == PropKind.sack,
    );
    // Müzik aktivitesinde eline saz/bağlama çiz — sprite scale'inde, göğüs
    // hizasında. Karakter sprite ile birlikte çizilir ki flip etse de doğru
    // tarafta olsun.
    if (!hasHeldItem &&
        e.activity == VillagerActivity.music &&
        e.chatBubbleTime > 0) {
      canvas.save();
      // Göğüs hizası — yaklaşık y=-52 (origin ayakta), x=4 (sağ el).
      canvas.translate(e.facingRight ? 6 : -6, -52);
      // Hafif çalma animasyonu — el sağ-sol küçük titreşim
      canvas.rotate(sin(time * 8 + e.gridX) * 0.08);
      ToolRenderer.drawSaz(canvas);
      canvas.restore();
    }
    canvas.restore();
    if (e.battleHealth != null) {
      final bar = Rect.fromLTWH(s.dx - 13, s.dy - 106 * charScale, 26, 3);
      canvas.drawRRect(
        RRect.fromRectAndRadius(bar.inflate(1), const Radius.circular(2)),
        Paint()..color = const Color(0xDD131B23),
      );
      canvas.drawRect(
        Rect.fromLTWH(bar.left, bar.top, bar.width * e.battleHealth!, 3),
        Paint()
          ..color = e.costume == NpcCostume.imperial
              ? const Color(0xFFD77461)
              : const Color(0xFF85BBA1),
      );
      canvas.drawRect(
        Rect.fromLTWH(
          bar.left,
          bar.bottom + 2,
          bar.width * (e.battleResolve ?? 0),
          1.5,
        ),
        Paint()..color = const Color(0xFFE0C17A),
      );
      if (e.imperialHit) {
        final spark = Paint()
          ..color = const Color(0xFFFFDE9A)
          ..strokeWidth = 1.5;
        final center = Offset(
          s.dx + (e.effectiveFacingRight ? 8 : -8),
          s.dy - 48 * charScale,
        );
        for (var i = 0; i < 5; i++) {
          final angle = i * pi * 2 / 5 + time * 3;
          final dir = Offset(cos(angle), sin(angle));
          canvas.drawLine(center + dir * 3, center + dir * 8, spark);
        }
      }
    }
    if (smithAmount > 0.02) {
      _drawSmithSparks(canvas, s, smithAmount, charScale);
    }
    if (chillAmount > 0.05) _drawColdBreath(canvas, s, chillAmount, charScale);
    if (wetAmount > 0.02) _drawWetShakeDrops(canvas, s, wetAmount, charScale);
    // Sohbet baloncuğu.
    final bubbleBase = Offset(
      s.dx,
      s.dy - danceBounce - talkBob - moodLift + sitYOff,
    );
    if (e.activity == VillagerActivity.chat) {
      // Karşılıklı konuşma — yalnız sırası gelen konuşur (konuya bağlı replik).
      final (speaking, cIcon) = e.convoNow();
      if (speaking && cIcon.isNotEmpty) {
        _drawChatBubble(canvas, bubbleBase, cIcon, e.chatBubbleTime);
      }
    } else if (e.chatBubbleTime > 0 &&
        e.chatBubbleIcon.isNotEmpty &&
        e.activity != VillagerActivity.music &&
        e.activity != VillagerActivity.dance) {
      // Statik baloncuk — geriye yalnız NESNE/İŞARET anlatanlar kaldı: kapıya
      // asılan dal 🌿 (hasta ev), kavgadan çekilen 🕊️. Duygu ve olay anlatan
      // baloncuklar (selam 👋, hikâye 📖, göktaşı 🌠) gövdeye taşındı —
      // sırasıyla CharGesture.wave, CharGesture.tell, NpcEmotion.wonder.
      _drawChatBubble(canvas, bubbleBase, e.chatBubbleIcon, e.chatBubbleTime);
    }
    // Müzik aktivitesinde sazın etrafında uçuşan notalar.
    if (e.activity == VillagerActivity.music && e.chatBubbleTime > 0) {
      _drawMusicNotes(
        canvas,
        Offset(s.dx, s.dy - danceBounce),
        e.gridX,
        e.gridY,
        e.chatBubbleTime,
      );
    }
    // (Baş üstü duygu emojisi KALDIRILDI — duygu artık yalnızca gövde diliyle
    // anlatılır: yukarıdaki emoBounce/emoLift/emoRot/emoScaleY postürü.)
  }

  void _drawColdBreath(
    Canvas canvas,
    Offset feet,
    double amount,
    double charScale,
  ) {
    final dir = e.effectiveFacingRight ? 1.0 : -1.0;
    final phase = (time * 0.55 + e.personalitySeed * 0.013) % 1.0;
    // Nefesin aralıklı olması onu sürekli ağızdan çıkan dumandan ayırır.
    if (phase > 0.72) return;
    final p = phase / 0.72;
    final alpha = sin(pi * p) * amount * (0.48 + rainIntensity * 0.12);
    _pStateVapor.color = const Color(
      0xFFE8F1F2,
    ).withValues(alpha: alpha.clamp(0.0, 0.62));
    final mouth = Offset(
      feet.dx + dir * 6.0 * charScale,
      feet.dy - 57.0 * charScale,
    );
    for (int i = 0; i < 3; i++) {
      final q = (p + i * 0.13).clamp(0.0, 1.0);
      final center = Offset(
        mouth.dx + dir * (4.0 + q * 13.0),
        mouth.dy - q * 5.0 - i * 1.2,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: (3.0 + q * 4.5) * charScale,
          height: (1.8 + q * 2.5) * charScale,
        ),
        _pStateVapor,
      );
    }
  }

  void _drawWetShakeDrops(
    Canvas canvas,
    Offset feet,
    double amount,
    double charScale,
  ) {
    _pStateDrops.color = const Color(
      0xFF9DD5EA,
    ).withValues(alpha: (0.35 + amount * 0.45).clamp(0.0, 0.8));
    final pulse = sin(time * 24.0 + e.personalitySeed).abs();
    for (int i = 0; i < 5; i++) {
      final side = i.isEven ? 1.0 : -1.0;
      final spread = (7.0 + i * 2.8 + pulse * 4.0) * charScale;
      final center = Offset(
        feet.dx + side * spread,
        feet.dy - (25.0 + i * 6.0 - pulse * 3.0) * charScale,
      );
      canvas.drawCircle(
        center,
        (1.0 + (i % 2) * 0.45) * charScale,
        _pStateDrops,
      );
    }
  }

  void _drawSmithSparks(
    Canvas canvas,
    Offset feet,
    double amount,
    double charScale,
  ) {
    final contact = ((sin(time * 9.5) - 0.48) / 0.52).clamp(0.0, 1.0);
    if (contact <= 0.02) return;
    final dir = e.effectiveFacingRight ? 1.0 : -1.0;
    final origin = Offset(
      feet.dx + dir * 13.0 * charScale,
      feet.dy - 25.0 * charScale,
    );
    _pSmithSpark
      ..color = const Color(
        0xFFFFB43C,
      ).withValues(alpha: contact * amount * 0.92)
      ..strokeWidth = max(0.8, charScale)
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 6; i++) {
      final a = -pi * 0.9 + i * pi * 0.36;
      final len = (3.0 + i % 3 * 2.2) * charScale * contact;
      canvas.drawLine(
        origin,
        origin.translate(cos(a) * len, sin(a) * len),
        _pSmithSpark,
      );
    }
    _pSmithCore.color = const Color(
      0xFFFFF0A8,
    ).withValues(alpha: contact * amount);
    canvas.drawCircle(origin, 1.5 * charScale, _pSmithCore);
  }

  static final Paint _pStateVapor = Paint()..isAntiAlias = false;
  static final Paint _pStateDrops = Paint()..isAntiAlias = false;
  static final Paint _pSmithSpark = Paint()..isAntiAlias = true;
  static final Paint _pSmithCore = Paint()..isAntiAlias = true;

  void _drawMusicNotes(
    Canvas canvas,
    Offset base,
    double gx,
    double gy,
    double timeLeft,
  ) {
    // 3 nota — farklı fazda yükselip yan kayarak solar.
    const notes = ['♪', '♫', '♩'];
    for (int i = 0; i < 3; i++) {
      final phase = (time * 0.5 + i * 0.33 + gx * 0.1 + gy * 0.13) % 1.0;
      final rise = phase * 28;
      final sway = sin(time * 1.5 + i * 1.7 + gx) * 6 * phase;
      double a;
      if (phase < 0.15) {
        a = phase / 0.15;
      } else {
        a = 1.0 - (phase - 0.15) / 0.85;
      }
      a = a.clamp(0.0, 1.0);
      // Aktivite sönerken son 1.5 sn fade out.
      final lifeFade = timeLeft < 1.5 ? (timeLeft / 1.5) : 1.0;
      final alpha = (a * lifeFade * 220).round().clamp(0, 220);
      if (alpha < 10) continue;
      final tp = TextPainter(
        text: TextSpan(
          text: notes[i],
          style: TextStyle(
            fontSize: 10 + i * 1.5,
            color: Color.fromARGB(alpha, 240, 220, 180),
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(base.dx + 8 + sway, base.dy - 20 - rise));
    }
  }

  /// Selamın zarfı: kol kalkar, sallanır, iner. [left] kalan süre (sn).
  ///
  /// Zarf olmadan kol tek karede yukarı sıçrar ve jest "seğirme" gibi okunur —
  /// baloncuğun yerine bunu koymanın bütün anlamı hareketin KENDİSİ olduğu
  /// için, giriş ve çıkış rampası jestin parçası.
  double _waveEnvelope(double left) {
    const rise = 0.28, fall = 0.38;
    final elapsed = VillagerEntity.kWaveDuration - left;
    if (elapsed < rise) return (elapsed / rise).clamp(0.0, 1.0);
    if (left < fall) return (left / fall).clamp(0.0, 1.0);
    return 1.0;
  }

  void _drawChatBubble(
    Canvas canvas,
    Offset base,
    String icon,
    double timeLeft,
  ) {
    // Fade in (ilk 0.4 sn) + tut + fade out (son 0.6 sn).
    // Kısa sohbet (≤5 sn) ve uzun hikaye (>5 sn) baloncukları için ortak.
    double a;
    if (timeLeft < 0.6) {
      a = timeLeft / 0.6; // Fade out
    } else if (timeLeft > 4.6 && timeLeft < 5.0) {
      a = (5.0 - timeLeft) / 0.4; // Kısa baloncuk için fade in
    } else {
      a = 1.0;
    }
    a = a.clamp(0.0, 1.0);
    if (a <= 0.02) return;
    final alpha = (a * 255).round();

    // Hafif yukarı float — yaşıyor hissi.
    final yBob = sin(time * 2 + base.dx * 0.1) * 1.2;
    final cx = base.dx;
    final cy = base.dy - 26 + yBob;

    // Baloncuk arka planı — yumuşak beyaz kart + ince koyu çerçeve.
    final bgPaint = _pBubbleFill
      ..color = Color.fromARGB((alpha * 0.92).round(), 250, 246, 232);
    final borderPaint = _pBubbleBorder
      ..color = Color.fromARGB((alpha * 0.78).round(), 70, 50, 30);
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: 18, height: 16),
      const Radius.circular(4),
    );
    canvas.drawRRect(rect, bgPaint);
    canvas.drawRRect(rect, borderPaint);
    // Küçük "kuyruk" üçgeni (sprite'a doğru). Paylaşımlı scratch path (leaf draw).
    final tail = _scratchPath
      ..reset()
      ..moveTo(cx - 2, cy + 7)
      ..lineTo(cx + 2, cy + 7)
      ..lineTo(cx, cy + 11)
      ..close();
    canvas.drawPath(tail, bgPaint);
    canvas.drawPath(tail, borderPaint);
    // İkon metni.
    final tp = TextPainter(
      text: TextSpan(
        text: icon,
        style: TextStyle(
          fontSize: 11,
          color: Color.fromARGB(alpha, 30, 24, 16),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  void _drawZzz(Canvas canvas, Offset base) {
    // Pixel-art Z'ler — text yerine ParticleRenderer.drawSleepZzz.
    // 3 farklı seed → 3 Z asenkron drift eder, doğal "Z Z Z" hissi.
    final entitySeed = e.gridX.toInt() * 13 + e.gridY.toInt() * 7;
    for (int i = 0; i < 3; i++) {
      // Yatay offset yelpaze — uyuyan NPC baş çevresinde dağıt.
      final ox = (i - 1) * 4.0;
      ParticleRenderer.drawSleepZzz(
        canvas,
        base.dx + ox,
        base.dy - 24,
        time,
        entitySeed + i * 17,
      );
    }
  }

  /// Bu iş rolünün kendine ait bir çalışma sprite'ı/pozu var mı — varsa köylü
  /// baz meslek yerine iş görünümüyle (alet + aksiyon) çizilir.
  bool _jobHasSprite(JobRole role) => role != JobRole.none;

  /// Köylüyü ÜSTLENDİĞİ iş sprite'ıyla çiz (kimlik e.visual'dan). Gölge/torch
  /// zaten çizilmiş olarak gelir; burada gövde + alet + ilerleme/partikül.
  void _drawJobVillager(Canvas canvas, VillagerEntity e, Offset s) {
    // KÖYÜN HÂLİ — iş sprite'ları `CharacterRenderer.draw` üzerinden GEÇMEZ
    // (kendi meslek fonksiyonlarına doğrudan girerler), o yüzden kılık burada
    // ayrıca yazılır. Faz 3'ün dersi birebir aynıydı: köyün ÇOĞUNLUĞU işçidir,
    // yalnız errand yolunu bağlamak "köy değişmedi" demektir.
    // Örtünme yok: elinde kazma sallayan adam şala sarınmaz.
    CharacterRenderer.beginNpc(
      provision: e.provision,
      primitiveClothing: primitiveClothing,
    );
    final job = e.job!;
    final charScale = kCharScale * e.displayScale;
    final working = job.working;
    canvas.save();
    canvas.translate(s.dx, s.dy);
    // Aksiyon sırasında idle sway/breath uygulama (aksi halde nefes + sway).
    if (!working) {
      final swayR = e.idleSwayRotation(time);
      if (swayR != 0) canvas.rotate(swayR);
    }
    final breathY = working ? 1.0 : e.idleBreathScale(time);
    canvas.scale(charScale * e.turnScaleX, charScale * breathY);
    final flip = !e.effectiveFacingRight;
    // Aksiyon animasyonu köylünün duran walkPhase'i yerine job.phaseAnim'den.
    final actPhase = working ? job.phaseAnim : e.walkPhase;
    switch (job.role) {
      case JobRole.builder:
        CharacterRenderer.drawBuilder(
          canvas,
          flipX: flip,
          visual: e.visual,
          time: time,
          torchLevel: e.torchLevel,
          torchPhase: e.torchPhase,
          walkPhase: actPhase,
          moveIntensity: e.moveIntensity,
          working: working,
          houseAccent: houseAccentColor(e.surname),
          primitiveClothing: primitiveClothing,
        );
      case JobRole.farmer:
        CharacterRenderer.drawFarmer(
          canvas,
          flipX: flip,
          walkPhase: actPhase,
          moveIntensity: e.moveIntensity,
          harvesting: job.harvesting,
          harvestPhase: job.phaseAnim,
          carryingWater: job.carryingWater,
          visual: e.visual,
          time: time,
          torchLevel: e.torchLevel,
          torchPhase: e.torchPhase,
          houseAccent: houseAccentColor(e.surname),
          primitiveClothing: primitiveClothing,
        );
      case JobRole.miner:
        CharacterRenderer.drawMiner(
          canvas,
          flipX: flip,
          walkPhase: actPhase,
          moveIntensity: e.moveIntensity,
          mining: working,
          chopPhase: job.phaseAnim,
          visual: e.visual,
          time: time,
          torchLevel: e.torchLevel,
          torchPhase: e.torchPhase,
          houseAccent: houseAccentColor(e.surname),
          primitiveClothing: primitiveClothing,
        );
      case JobRole.fisher:
        CharacterRenderer.drawFisher(
          canvas,
          flipX: flip,
          walkPhase: actPhase,
          moveIntensity: e.moveIntensity,
          fishing: working,
          fishPhase: job.phaseAnim,
          visual: e.visual,
          time: time,
          torchLevel: e.torchLevel,
          torchPhase: e.torchPhase,
          houseAccent: houseAccentColor(e.surname),
          primitiveClothing: primitiveClothing,
        );
      case JobRole.shepherd:
        CharacterRenderer.drawShepherd(
          canvas,
          flipX: flip,
          walkPhase: actPhase,
          moveIntensity: e.moveIntensity,
          milking: working,
          milkPhase: job.phaseAnim,
          visual: e.visual,
          time: time,
          torchLevel: e.torchLevel,
          torchPhase: e.torchPhase,
          houseAccent: houseAccentColor(e.surname),
          primitiveClothing: primitiveClothing,
        );
      case JobRole.florist:
        CharacterRenderer.drawFarmer(
          canvas,
          flipX: flip,
          walkPhase: actPhase,
          moveIntensity: e.moveIntensity,
          harvesting: job.harvesting,
          harvestPhase: job.phaseAnim,
          carryingWater: job.carryingWater,
          visual: e.visual,
          time: time,
          torchLevel: e.torchLevel,
          torchPhase: e.torchPhase,
          houseAccent: houseAccentColor(e.surname),
          primitiveClothing: primitiveClothing,
        );
      case JobRole.woodcutter:
        CharacterRenderer.drawWoodcutter(
          canvas,
          flipX: flip,
          walkPhase: actPhase,
          moveIntensity: e.moveIntensity,
          chopping: working,
          chopPhase: job.phaseAnim,
          visual: e.visual,
          time: time,
          torchLevel: e.torchLevel,
          torchPhase: e.torchPhase,
          houseAccent: houseAccentColor(e.surname),
          primitiveClothing: primitiveClothing,
        );
      // TOPLAYICI / AŞÇI — ikisi de eğilip elle çalışan işler; çiçekçinin
      // yaptığı gibi çiftçi gövdesini (stoop + sepet duruşu) ödünç alırlar.
      // Kendi shaded çizimleri iş döngüleriyle birlikte gelecek.
      case JobRole.forager:
      // Dokumacı ayrı bir sprite İSTEMEZ: tezgâh başında eğilen gövde
      // aşçınınkiyle aynı okunur (bkz. scene_jobs pose eşlemesi). Yeni meslek
      // = yeni çizim değil; ayırt eden şey duruş ve elindeki iş.
      case JobRole.weaver:
      case JobRole.cook:
        CharacterRenderer.drawFarmer(
          canvas,
          flipX: flip,
          walkPhase: actPhase,
          moveIntensity: e.moveIntensity,
          harvesting: job.harvesting,
          harvestPhase: job.phaseAnim,
          carryingWater: false,
          visual: e.visual,
          time: time,
          torchLevel: e.torchLevel,
          torchPhase: e.torchPhase,
          houseAccent: houseAccentColor(e.surname),
          primitiveClothing: primitiveClothing,
        );
      case JobRole.none:
        break;
    }
    canvas.restore();

    // İş-özel overlay: ilerleme çubuğu + kıvılcım/talaş/splash.
    if (job.role == JobRole.builder && working) {
      _drawJobProgressBar(canvas, s, job.progress);
      if (workContactAmount(job.phaseAnim) > 0.72) {
        _drawJobSpark(canvas, s.dx, s.dy, e.facingRight);
      }
    }
    // Çiftçi kuyu/sulama anının ilk 0.4 sn'sinde su sıçraması.
    if (job.role == JobRole.farmer &&
        job.splashTimer >= 0 &&
        job.splashTimer < 0.4) {
      ParticleRenderer.drawSplash(
        canvas,
        s.dx,
        s.dy - 10,
        job.splashTimer / 0.4,
      );
    }
    // Madenci kazma darbesinde taş chip'i (chopPhase döngü başı %30).
    if (job.role == JobRole.miner && working) {
      final impactPhase = workImpactPhase(job.phaseAnim);
      if (impactPhase >= 0) {
        final lt = (impactPhase / (2 * pi)).clamp(0.0, 1.0);
        final dir = e.facingRight ? 1.0 : -1.0;
        final seed = e.gridX.toInt() * 7 + e.gridY.toInt() * 13;
        ParticleRenderer.drawChip(
          canvas,
          s.dx + dir * 12,
          s.dy - 18,
          lt,
          color: const Color(0xFFA8A4A0),
          shade: const Color(0xFF5A5450),
          direction: dir,
          seed: seed,
        );
      }
    }
  }

  void _drawJobProgressBar(Canvas canvas, Offset pos, double progress) {
    const w = 34.0, h = 4.0;
    final left = pos.dx - w / 2;
    final top = pos.dy - 52;
    canvas.drawRect(Rect.fromLTWH(left, top, w, h), _ppBg);
    canvas.drawRect(Rect.fromLTWH(left, top, w * progress, h), _ppFill);
    canvas.drawRect(Rect.fromLTWH(left, top, w, h), _ppBorder);
  }

  void _drawJobSpark(Canvas canvas, double sx, double sy, bool facingRight) {
    final dir = facingRight ? 1.0 : -1.0;
    final px = sx + dir * 14, py = sy - 38;
    final paint = Paint()
      ..color = const Color(0xFFFFFFB0)
      ..isAntiAlias = false;
    final dim = Paint()
      ..color = const Color(0xCCFFD060)
      ..isAntiAlias = false;
    canvas.drawRect(Rect.fromLTWH(px, py, 2, 2), paint);
    canvas.drawRect(Rect.fromLTWH(px + dir * 3, py - 2, 2, 2), paint);
    canvas.drawRect(Rect.fromLTWH(px - dir * 2, py + 2, 1, 1), dim);
    canvas.drawRect(Rect.fromLTWH(px + dir * 5, py + 1, 1, 1), dim);
  }
}
