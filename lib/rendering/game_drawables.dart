part of 'game_painter.dart';

/// ─── SAHNE VARLIKLARI (DRAWABLE) ────────────────────────────────────────────
///
/// Derinlik sıralı çizim listesine giren her şey: köylü, hayvan, bina, şantiye,
/// ağaç, dekor, mezar, saz, maden düğümü, kutu, yumurta, saman.
///
/// SÖZLEŞME: her drawable tek bir `depth` skaleri verir (painter's algorithm,
/// bkz. [_Drawable]) ve yalnız KENDİNİ çizer — kamera/ışık/atmosfer painter'ın
/// işidir. Yeni bir varlık türü eklerken buraya bir sınıf yaz, `_drawScene`
/// içinde tampona ekle; başka hiçbir yeri değiştirmen gerekmez.
///
/// Paint havuzu ve gölge yardımcıları `game_painter.dart`'ta durur (aynı
/// kütüphane → private erişim serbest).

// ─── DRAWABLE ABSTRACTION ────────────────────────────────────────────────────

abstract class _Drawable {
  double get depth;
  void draw(Canvas canvas, Size size, Offset camera);

  /// Stabil sort tie-break — buffer'daki ekleme sırası (her frame atanır).
  /// Eşit depth'te bu deterministik sıra kullanılır → titreme/rastgele örtme yok.
  int sortIndex = 0;

  /// Bu drawable bir "aktör" (NPC/işçi) ise wrapped entity; değilse null.
  /// Occlusion silhouette pass'i aktörleri buradan bulur. Bina içindeyken null.
  WorkerEntity? get actor => null;

  /// Bu drawable bir bina ise wrapped entity; değilse null. Occlusion testinde
  /// "önde çizilen örten" listesi buradan kurulur.
  BuildingEntity? get building => null;
}

class _VillagerDrawable extends _Drawable {
  final VillagerEntity e;
  final double time;
  final double dayLight;
  final bool primitiveClothing;
  _VillagerDrawable(
    this.e,
    this.time,
    this.dayLight, {
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
        commander: e.imperialCommander,
        attacking: e.imperialAttacking,
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
    if (e.job != null &&
        _jobHasSprite(e.job!.role) &&
        !e.isCarrying &&
        e.prop == PropKind.none) {
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
      s.dx + brawlShove + crimeShove + bearShove + actShove,
      s.dy -
          danceBounce -
          talkBob -
          moodLift +
          sitYOff -
          emoBounce -
          emoLift -
          crimeLift -
          bearLift -
          actLift,
    );
    if (danceSway != 0) canvas.rotate(danceSway);
    if (sitSway != 0) canvas.rotate(sitSway);
    if (talkSway != 0) canvas.rotate(talkSway);
    if (emoRot != 0) canvas.rotate(emoRot);
    if (crimeRot != 0) canvas.rotate(crimeRot);
    if (bearRot != 0) canvas.rotate(bearRot);
    if (actRot != 0) canvas.rotate(actRot);
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
          actScaleY,
    );
    // Darbe tepkisi ayak ucundan geriye sendeleme olarak okunur. Pozisyonel
    // geri itilmeyi combat motoru yapar; bu küçük gövde kırılması darbeyi
    // yürüyüşten ayırır. Yön aynalaması dönüşü de doğru tarafa çevirir.
    if (e.imperialHit) {
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
      commander: e.imperialCommander,
      attacking: e.imperialAttacking,
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

/// Kervan liderinin hareket ankrajına bağlı at arabası. İnsan sprite'ından
/// ayrı drawable olduğu için büyük silüet binalar/NPC'lerle doğru derinlikte
/// örtüşür ve occlusion aktörü olarak da tanınır.
class _HorseCartDrawable extends _Drawable {
  final MerchantEntity e;
  final double time;
  _HorseCartDrawable(this.e, this.time);

  @override
  double get depth => e.depth;

  @override
  WorkerEntity? get actor => e;

  @override
  void draw(Canvas canvas, Size size, Offset camera) {
    final s = gridToScreen(e.renderX, e.renderY, size, camera);
    VehicleRenderer.drawHorseCart(
      canvas,
      s,
      facingRight: e.effectiveFacingRight,
      walkPhase: e.walkPhase,
      isMoving: e.moveIntensity > 0.12,
      time: time,
    );
  }
}

class _CowDrawable extends _Drawable {
  final AnimalEntity a;
  _CowDrawable(this.a);
  @override
  double get depth => a.depth;
  @override
  void draw(Canvas canvas, Size size, Offset camera) {
    final s = gridToScreen(a.renderX, a.renderY, size, camera);
    AnimalRenderer.drawCow(
      canvas,
      s,
      facing: a.facing4,
      walkPhase: a.walkPhase,
      isWalking: a.isWalking,
      scale: a.renderScale * (a.isDying ? (1 - 0.25 * a.deathProgress) : 1.0),
      alpha: a.isDying ? (1 - a.deathProgress) : 1.0,
    );
  }
}

class _SheepDrawable extends _Drawable {
  final AnimalEntity a;
  _SheepDrawable(this.a);
  @override
  double get depth => a.depth;
  @override
  void draw(Canvas canvas, Size size, Offset camera) {
    final s = gridToScreen(a.renderX, a.renderY, size, camera);
    AnimalRenderer.drawSheep(
      canvas,
      s,
      facing: a.facing4,
      walkPhase: a.walkPhase,
      isWalking: a.isWalking,
      scale: a.renderScale * (a.isDying ? (1 - 0.25 * a.deathProgress) : 1.0),
      alpha: a.isDying ? (1 - a.deathProgress) : 1.0,
    );
  }
}

class _ChickenDrawable extends _Drawable {
  final AnimalEntity a;
  _ChickenDrawable(this.a);
  @override
  double get depth => a.depth;
  @override
  void draw(Canvas canvas, Size size, Offset camera) {
    final s = gridToScreen(a.renderX, a.renderY, size, camera);
    AnimalRenderer.drawChicken(
      canvas,
      s,
      facing: a.facing4,
      walkPhase: a.walkPhase,
      isWalking: a.isWalking,
      scale: a.renderScale * (a.isDying ? (1 - 0.25 * a.deathProgress) : 1.0),
      alpha: a.isDying ? (1 - a.deathProgress) : 1.0,
    );
  }
}

class _DecorDrawable extends _Drawable {
  final DecorEntity d;
  final double time;
  _DecorDrawable(this.d, this.time);
  @override
  double get depth => d.depth;
  @override
  void draw(Canvas canvas, Size size, Offset camera) {
    final center = gridToScreen(
      d.col + 0.5 + d.jitterX,
      d.row + 0.5 + d.jitterY,
      size,
      camera,
    );
    DecorRenderer.draw(canvas, center, d, time: time);
  }
}

class _WorldLandmarkDrawable extends _Drawable {
  final WorldLandmark site;
  _WorldLandmarkDrawable(this.site);
  @override
  double get depth => site.depth;
  @override
  void draw(Canvas canvas, Size size, Offset camera) {
    final center = gridToScreen(site.col + 0.5, site.row + 0.5, size, camera);
    WorldLandmarkRenderer.draw(canvas, center, site);
  }
}

class _GraveDrawable extends _Drawable {
  final Grave g;
  _GraveDrawable(this.g);
  @override
  double get depth => g.depth;
  @override
  void draw(Canvas canvas, Size size, Offset camera) {
    final center = gridToScreen(
      g.col + 0.5 + g.jitterX,
      g.row + 0.5 + g.jitterY,
      size,
      camera,
    );
    GraveRenderer.draw(canvas, center, g);
  }
}

class _ReedBedDrawable extends _Drawable {
  final ReedBed b;
  _ReedBedDrawable(this.b);
  @override
  double get depth => b.depth;
  @override
  void draw(Canvas canvas, Size size, Offset camera) {
    final center = gridToScreen(b.gridX, b.gridY, size, camera);
    ReedBedRenderer.draw(
      canvas,
      center,
      seed: (b.gridX * 13 + b.gridY * 7).round(),
    );
  }
}

class _LotusDrawable extends _Drawable {
  final LotusEntity l;
  final double time;
  _LotusDrawable(this.l, this.time);
  @override
  double get depth => l.depth;
  @override
  void draw(Canvas canvas, Size size, Offset camera) {
    final center = gridToScreen(l.col + 0.5, l.row + 0.5, size, camera);
    NatureRenderer.drawLotus(
      canvas,
      center,
      variant: l.variant,
      time: time,
      seed: l.col * 23 + l.row * 37,
    );
  }
}

class _ReedDrawable extends _Drawable {
  final ReedClump r;
  final double time;
  _ReedDrawable(this.r, this.time);
  @override
  double get depth => r.depth;
  @override
  void draw(Canvas canvas, Size size, Offset camera) {
    // İki tile'ın üst köşelerinin ortası
    final s1 = gridToScreen(r.col.toDouble(), r.row.toDouble(), size, camera);
    final s2 = gridToScreen(r.col2.toDouble(), r.row2.toDouble(), size, camera);
    final cx = (s1.dx + s2.dx) / 2;
    final cy = (s1.dy + s2.dy) / 2 + kTileH / 2; // tile orta yüksekliğine in
    NatureRenderer.drawReeds(
      canvas,
      cx,
      cy,
      time: time,
      seed: r.col * 19 + r.row * 41,
      col: r.col.toDouble(),
      row: r.row.toDouble(),
      growth: r.growth,
    );
  }
}

class _BerryBushDrawable extends _Drawable {
  final BerryBush b;
  final double time;
  _BerryBushDrawable(this.b, this.time);
  @override
  double get depth => b.depth;
  @override
  void draw(Canvas canvas, Size size, Offset camera) {
    // Tile merkezinin ALT yarısı — çalı zemine oturur, tile'ın ortasında
    // havada durmaz (sazla aynı hizalama mantığı).
    final s = gridToScreen(b.col + 0.5, b.row + 0.5, size, camera);
    NatureRenderer.drawBerryBush(
      canvas,
      s.dx,
      s.dy + kTileH * 0.18,
      ripeness: b.ripeness,
      variant: b.variant,
      seed: b.col * 29 + b.row * 47,
      time: time,
      col: b.col.toDouble(),
      row: b.row.toDouble(),
    );
  }
}

class _TreeDrawable extends _Drawable {
  final TreeEntity t;
  final double time;
  final Season season;
  _TreeDrawable(this.t, this.time, this.season);
  @override
  double get depth => t.depth;
  @override
  void draw(Canvas canvas, Size size, Offset camera) {
    final center = gridToScreen(t.col + 0.5, t.row + 0.5, size, camera);
    // Çam gövdesi tabanında dar elips gölge
    _drawTreeShadow(
      canvas,
      center.dx,
      center.dy,
      28.0,
      t.growthScale,
      t.fellProgress,
      t.fallDirection,
    );
    TreeRenderer.draw(
      canvas,
      t.type,
      center,
      time: time,
      seed: t.col * 17 + t.row * 31,
      chopPhase: t.chopPhase,
      growthScale: t.growthScale,
      col: t.col + 0.5,
      row: t.row + 0.5,
      season: season,
      fellProgress: t.fellProgress,
      fallDirection: t.fallDirection,
    );
  }
}

class _BuildingDrawable extends _Drawable {
  final BuildingEntity b;
  final double time;
  final double dayLight;
  final double rainIntensity;
  final Season season;

  /// fireOutbreak event'inde bu bina yanıyor mu — sprite üstüne alev + duman.
  final bool burning;
  final bool perfMode;
  _BuildingDrawable(
    this.b,
    this.time,
    this.dayLight,
    this.rainIntensity,
    this.season,
    this.burning,
    this.perfMode,
  );
  // Painter's algorithm: bina ön-en (frontmost) tile'ının diagonal sum'ı.
  // (col+cols-1, row+rows-1) bina footprint'inin güney-doğu (ön) tile'ı.
  // Eski formül (col+row + (cols+rows)/2 = orta) → bina arkasındaki NPC önde
  // görünebiliyordu. Ön-tile sort'u izometride doğru z-order verir.
  @override
  double get depth => (b.col + b.cols - 1.0) + (b.row + b.rows - 1.0);
  @override
  BuildingEntity? get building => b;
  @override
  void draw(Canvas canvas, Size size, Offset camera) {
    final corners = _corners(b.col, b.row, b.cols, b.rows, size, camera);
    // GÖLGE ARTIK BURADA ÇİZİLMEZ — ayrı pass'te (paint() başında, sahne
    // sprite'larından önce). Bu sayede başka binaların gölgesi bu sprite'ın
    // üstüne taşmaz, hep zemin seviyesinde kalır.

    // Spawn pop: ilk 0.6 sn'de overshoot settle (scale 1.06 → 1.0). Anchor =
    // front köşe → bina alttan büyür gibi durur. spawnTime == 0 (eski/init
    // binalar) için 0..0.6 aralığı kapalı, hiç pop yok.
    final age = b.spawnTime > 0 ? time - b.spawnTime : 999.0;
    final popping = age >= 0 && age < 0.6;
    if (popping) {
      final t = age / 0.6;
      final scale = 1.0 + 0.06 * (1.0 - t) * (1.0 - t);
      final fx = corners.$4.dx;
      final fy = corners.$4.dy;
      canvas.save();
      canvas.translate(fx, fy);
      canvas.scale(scale, scale);
      canvas.translate(-fx, -fy);
      BuildingRenderer.draw(
        canvas,
        b.type,
        corners.$1,
        corners.$2,
        corners.$3,
        corners.$4,
        time: time,
        seed: b.col * 17 + b.row * 31,
        dayLight: dayLight,
        rainIntensity: rainIntensity,
        isActive: b.isActive,
        perfMode: perfMode,
        fireFuel: b.fireFuel,
        millRotorAngle: b.millRotorAngle,
        deliveryPulse: b.deliveryPulse,
        deliveryTally: b.deliveryTally,
        season: season,
        windowGlow: b.windowGlow,
      );
      canvas.restore();
    } else {
      BuildingRenderer.draw(
        canvas,
        b.type,
        corners.$1,
        corners.$2,
        corners.$3,
        corners.$4,
        time: time,
        seed: b.col * 17 + b.row * 31,
        dayLight: dayLight,
        rainIntensity: rainIntensity,
        isActive: b.isActive,
        perfMode: perfMode,
        fireFuel: b.fireFuel,
        millRotorAngle: b.millRotorAngle,
        deliveryPulse: b.deliveryPulse,
        deliveryTally: b.deliveryTally,
        season: season,
        windowGlow: b.windowGlow,
      );
    }

    // Toz bulutu — ilk 0.4 sn footprint kenarlarında 3 partikül. Açık bej ton.
    if (b.spawnTime > 0 && age >= 0 && age < 0.4) {
      final dust = 1.0 - age / 0.4;
      final midY = (corners.$2.dy + corners.$3.dy) * 0.5 + 2;
      final fw = (corners.$3.dx - corners.$2.dx).abs();
      final dustScale = 0.35 + fw / 200.0; // büyük bina ~ daha geniş toz
      const dustTint = Color(0xFFE8DCC4);
      SmokeRenderer.draw(
        canvas,
        corners.$2.dx + 4,
        midY,
        dustScale,
        time,
        b.col * 31 + b.row * 7,
        tint: dustTint,
        intensity: dust,
      );
      SmokeRenderer.draw(
        canvas,
        corners.$4.dx,
        corners.$4.dy - 1,
        dustScale,
        time,
        b.col * 31 + b.row * 11,
        tint: dustTint,
        intensity: dust,
      );
      SmokeRenderer.draw(
        canvas,
        corners.$3.dx - 4,
        midY,
        dustScale,
        time,
        b.col * 31 + b.row * 13,
        tint: dustTint,
        intensity: dust,
      );
    }

    if (b.damage > 0.02) {
      _drawDamageOverlay(
        canvas,
        corners.$1,
        corners.$2,
        corners.$3,
        corners.$4,
        b.damage,
      );
    }

    // Alev ve duman is katmanının üstünde kalmalı: yangın sürerken okunur,
    // söndüğünde altta kalan kalıcı hasar tek başına görünür.
    if (burning) {
      _drawBurningOverlay(
        canvas,
        corners.$1,
        corners.$2,
        corners.$3,
        corners.$4,
      );
    }

    // Pazar satış parıltısı — son satış üstünden < 1sn ise altın yukarı çıkar.
    if (b.lastSaleTime > 0) {
      final saleAge = time - b.lastSaleTime;
      if (saleAge >= 0 && saleAge < 1.0) {
        // Pazar üstü merkez — back ile front'un X ortası, back Y'den biraz aşağı.
        final cx = (corners.$1.dx + corners.$4.dx) * 0.5;
        final cy = corners.$1.dy + 4;
        ParticleRenderer.drawGoldSparkle(canvas, cx, cy, saleAge);
      }
    }

    // Yas işareti — bu evden biri öldüğünde çatının üstünde kısa süre görünür.
    // Dünya işareti metin bildirimini tamamlar: oyuncu hangi ocağın sustuğunu
    // kamerayı çevirmeden de seçebilir.
    if (b.deathMarkerUntil > time && b.fn?.role == BuildingRole.housing) {
      final left = b.deathMarkerUntil - time;
      final fade = left < 1.5 ? (left / 1.5).clamp(0.0, 1.0) : 1.0;
      final pulse = 0.5 + 0.5 * sin(time * 4.0 + b.col * 0.7);
      final alpha = (fade * (0.78 + pulse * 0.16) * 255).round().clamp(0, 255);
      final cx = (corners.$1.dx + corners.$4.dx) * 0.5;
      final cy = corners.$1.dy - 34 - pulse * 2.0;
      final markerPaint = Paint()..color = Color.fromARGB(alpha, 35, 24, 28);
      final clothPaint = Paint()..color = Color.fromARGB(alpha, 139, 31, 43);
      canvas.drawLine(
        Offset(cx, cy + 16),
        Offset(cx, cy - 13),
        markerPaint..strokeWidth = 2.0,
      );
      final flag = Path()
        ..moveTo(cx + 1, cy - 12)
        ..lineTo(cx + 17, cy - 8)
        ..lineTo(cx + 1, cy - 2)
        ..close();
      canvas.drawPath(flag, clothPaint);
      canvas.drawCircle(Offset(cx, cy + 18), 3.5, markerPaint);
      final glyph = TextPainter(
        text: TextSpan(
          text: '✝',
          style: TextStyle(
            color: Color.fromARGB(alpha, 245, 226, 193),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      glyph.paint(canvas, Offset(cx - glyph.width / 2, cy - 10));
      if (b.deathMarkerCount > 1) {
        final count = TextPainter(
          text: TextSpan(
            text: '${b.deathMarkerCount}',
            style: TextStyle(
              color: Color.fromARGB(alpha, 255, 245, 220),
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        count.paint(canvas, Offset(cx + 10, cy - 3));
      }
    }
  }

  // Yanan bina overlay'i — sprite çatısı/orta seviyesinde 2-3 alev + yukarı
  // kalkan koyu duman partikülleri + sıcak halo. Footprint köşelerinden
  // ortalanmış pozisyon hesabı.
  static final Paint _pBurnGlow = Paint()..isAntiAlias = true;
  static final Paint _pDamage = Paint()
    ..isAntiAlias = true
    ..strokeCap = StrokeCap.round;

  /// Kalıcı hasar izi: çatıya sinen is, iki kırık hat ve ağır hasarda kapıya
  /// çakılmış destek tahtaları. Geometri footprint'ten türediği için aynı
  /// katman kulübe, taş konut ve konakta da sprite'a özgü koordinat istemeden
  /// doğru yere oturur.
  void _drawDamageOverlay(
    Canvas canvas,
    Offset back,
    Offset left,
    Offset right,
    Offset front,
    double damage,
  ) {
    final d = damage.clamp(0.0, 1.0);
    final cx = (back.dx + front.dx) * 0.5;
    final roofY = (back.dy + left.dy) * 0.5 - 6;
    final width = (right.dx - left.dx).abs();
    final alpha = (45 + 105 * d).round().clamp(0, 160);
    _pDamage
      ..style = PaintingStyle.fill
      ..color = Color.fromARGB(alpha, 31, 24, 22);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, roofY),
        width: width * (0.42 + d * 0.22),
        height: 7 + d * 5,
      ),
      _pDamage,
    );

    _pDamage
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 + d * 1.1
      ..color = Color.fromARGB(
        (80 + 115 * d).round().clamp(0, 195),
        58,
        38,
        30,
      );
    canvas.drawLine(
      Offset(cx - width * 0.16, roofY - 2),
      Offset(cx - width * 0.03, roofY + 4),
      _pDamage,
    );
    if (d > 0.35) {
      canvas.drawLine(
        Offset(cx + width * 0.10, roofY - 3),
        Offset(cx + width * 0.22, roofY + 3),
        _pDamage,
      );
    }
    if (d > 0.62) {
      _pDamage
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = const Color(0xFF765038);
      final boardY = front.dy - 8;
      canvas.drawLine(
        Offset(cx - width * 0.11, boardY - 3),
        Offset(cx + width * 0.08, boardY + 2),
        _pDamage,
      );
      canvas.drawLine(
        Offset(cx - width * 0.08, boardY + 3),
        Offset(cx + width * 0.11, boardY - 2),
        _pDamage,
      );
    }
  }

  void _drawBurningOverlay(
    Canvas canvas,
    Offset back,
    Offset left,
    Offset right,
    Offset front,
  ) {
    // Sprite çatı orta noktası: footprint orta x, back y (sprite yukarı
    // doğru uzar). Tile genişliğine göre alev ölçeği.
    final cx = (back.dx + front.dx) * 0.5;
    final roofY = (back.dy + left.dy) * 0.5 - 4; // back'ten biraz yukarı
    final tileW = (right.dx - left.dx).abs();
    final flameScale = tileW / 26.0;

    // Sıcak halo (additive plus blend — gece sıcak parlama)
    final pulse = sin(time * 4.7 + b.col * 0.3) * 0.15 + 0.85;
    _pBurnGlow.blendMode = BlendMode.plus;
    _pBurnGlow.color = Color.fromARGB(
      (140 * pulse).round().clamp(0, 200),
      0xFF,
      0x60,
      0x18,
    );
    canvas.drawCircle(Offset(cx, roofY), 30 * flameScale, _pBurnGlow);
    _pBurnGlow.blendMode = BlendMode.srcOver;

    // Birden fazla alev — çatıya yayılır
    for (int i = 0; i < 3; i++) {
      final fx = cx + (i - 1) * (10 * flameScale);
      final fy = roofY - (i == 1 ? 4 * flameScale : 0);
      FlameRenderer.draw(
        canvas,
        fx,
        fy,
        flameScale * 2.0,
        time + i * 0.41,
        b.col * 7 + i,
        intensity: 1.0,
        sparks: true,
      );
    }

    // Yangın dumanı — sprite-based, koyu siyah-gri tint, yoğun yüksek scale.
    // İki duman sütunu (çatının iki ucundan) → yangının büyüklüğünü vurgular.
    SmokeRenderer.draw(
      canvas,
      cx - 4 * flameScale,
      roofY,
      flameScale * 2.4,
      time,
      b.col * 17 + b.row * 31,
      tint: const Color(0xFF504842),
      intensity: 1.0,
    );
    SmokeRenderer.draw(
      canvas,
      cx + 4 * flameScale,
      roofY - 2,
      flameScale * 2.0,
      time + 0.7,
      b.col * 23 + b.row * 41 + 7,
      tint: const Color(0xFF504842),
      intensity: 0.9,
    );
  }
}

class _ScaffoldDrawable extends _Drawable {
  final BuildOrder order;
  final double time;
  _ScaffoldDrawable(this.order, this.time);
  @override
  double get depth {
    // Ön köşe — _BuildingDrawable ile aynı kuralda kalmak için tutarlı.
    final m = kBuildingMeta[order.type]!;
    return (order.col + m.cols - 1.0) + (order.row + m.rows - 1.0);
  }

  @override
  void draw(Canvas canvas, Size size, Offset camera) {
    final m = kBuildingMeta[order.type]!;
    final (back, left, right, front) = _corners(
      order.col,
      order.row,
      m.cols,
      m.rows,
      size,
      camera,
    );

    // ── 1) Zemin diamond — inşaat alanı (toprak/sıkıştırılmış renk) ──
    _scratchPath
      ..reset()
      ..moveTo(back.dx, back.dy)
      ..lineTo(right.dx, right.dy)
      ..lineTo(front.dx, front.dy)
      ..lineTo(left.dx, left.dy)
      ..close();
    canvas.drawPath(_scratchPath, _pScaffGround);
    canvas.drawPath(_scratchPath, _pScaffBorder);

    // ── 2) Bina sprite reveal (smoothstep + jitter + clip kenarı gölge) ──
    BuildingRenderer.drawConstruction(
      canvas,
      order.type,
      left,
      right,
      front,
      order.progress,
      time,
    );
  }
}

(Offset, Offset, Offset, Offset) _corners(
  int col,
  int row,
  int cols,
  int rows,
  Size size,
  Offset camera,
) {
  final back = gridToScreen(col.toDouble(), row.toDouble(), size, camera);
  final left = gridToScreen(
    col.toDouble(),
    (row + rows).toDouble(),
    size,
    camera,
  );
  final right = gridToScreen(
    (col + cols).toDouble(),
    row.toDouble(),
    size,
    camera,
  );
  final front = gridToScreen(
    (col + cols).toDouble(),
    (row + rows).toDouble(),
    size,
    camera,
  );
  return (back, left, right, front);
}

class _MineDrawable extends _Drawable {
  final MineNode n;
  _MineDrawable(this.n);
  @override
  double get depth => n.depth;
  @override
  void draw(Canvas canvas, Size size, Offset camera) {
    final s = gridToScreen(n.col.toDouble(), n.row.toDouble(), size, camera);
    MineRenderer.draw(
      canvas,
      s.dx,
      s.dy,
      type: n.type,
      chopPhase: n.chopPhase,
      seed: n.col * 13 + n.row * 29,
    );
  }
}

/// Oduncu kulübesinin otonom NPC'si. WoodcutterEntity'den ayrı bir tip
/// (LumberCampEntity) ama davranış/sprite birebir aynı → woodcutter sprite'ı
/// reuse. Önceden painter'a hiç geçirilmemişti — render edilmeden ağaç
/// kesiyordu (ağaç "kendi kendine düşüyor" bug'ı).
class _ResourceBoxDrawable extends _Drawable {
  final ResourceBox b;
  final double time;
  _ResourceBoxDrawable(this.b, this.time);
  @override
  double get depth {
    // Stack içindeki ön-arka offset depth'e dahil — aynı tile'da öndeki
    // kutu arkadakini sprite olarak kapatır.
    final off = ResourcePlacement.offsetFor(b.slotIndex);
    return (b.gridX + off.$1) + (b.gridY + off.$2);
  }

  @override
  void draw(Canvas canvas, Size size, Offset camera) {
    final off = ResourcePlacement.offsetFor(b.slotIndex);
    final s = gridToScreen(b.gridX + off.$1, b.gridY + off.$2, size, camera);
    ResourceRenderer.drawBox(canvas, b, s.dx, s.dy, time);
  }
}

class _EggDrawable extends _Drawable {
  final EggEntity e;
  final double time;
  _EggDrawable(this.e, this.time);
  @override
  double get depth => e.depth;
  @override
  void draw(Canvas canvas, Size size, Offset camera) {
    final s = gridToScreen(e.gridX, e.gridY, size, camera);
    // Drop animasyonu (ilk 0.4s yukarıdan iner).
    double y = s.dy - 3;
    final since = time - e.spawnTime;
    if (since < 0.4) {
      final t = since / 0.4;
      y -= (1 - t) * (1 - t) * 9;
    }
    // Çatlamaya yakın hafif sallanma (willHatch).
    double wob = 0;
    if (e.willHatch && e.age > e.resolveAt - 2.0) {
      wob = sin(time * 18 + e.gridX) * 1.3;
    }
    final c = Offset(s.dx + wob, y);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(s.dx, s.dy - 0.5), width: 7, height: 3.5),
      Paint()..color = const Color(0x33000000),
    );
    canvas.drawOval(
      Rect.fromCenter(center: c, width: 6.5, height: 8.5),
      Paint()..color = const Color(0xFFF3E9D2),
    );
    canvas.drawOval(
      Rect.fromCenter(center: c.translate(-1, -1.6), width: 2.4, height: 3.4),
      Paint()..color = const Color(0xFFFFFDF5),
    );
  }
}

/// GÖMÜLÜ ZULA — eşelenmiş toprak öbeği.
///
/// PROSEDÜREL, PNG DEĞİL (Faz 3'ün prop kararıyla aynı gerekçe): sprite
/// beklenirse özellik görünmez kalır. Taze toprak koyu ve belirgindir, iz
/// kapandıkça soluklaşıp otla karışır — oyuncunun "geç kaldım" hissi bu
/// solmadan okunur, bir sayaçtan değil.
class _LootCacheDrawable extends _Drawable {
  final LootCache l;
  final double fade;
  _LootCacheDrawable(this.l, this.fade);
  @override
  double get depth => l.depth;
  @override
  void draw(Canvas canvas, Size size, Offset camera) {
    final s = gridToScreen(l.gridX, l.gridY, size, camera);
    final trace = lootTrace(l.age, fade, witnessed: l.witnessed);
    // Kapanmış iz de tümüyle kaybolmaz — üstüne basan bulabilmeli, yani
    // görünür bir şey kalmalı. Taban 0.30, tazelikle 1.0'a çıkar.
    final vis = 0.30 + 0.70 * trace;

    // Çukurun gölgesi (hafif oval çöküntü).
    canvas.drawOval(
      Rect.fromCenter(center: s, width: 13, height: 6.5),
      Paint()..color = Color.fromRGBO(30, 22, 16, 0.30 * vis),
    );
    // Eşelenmiş toprak — taze kahve, solunca griye kayar.
    final soil = Color.lerp(
      const Color(0xFF5A4A3A),
      const Color(0xFF3E3A2E),
      1 - trace,
    )!;
    canvas.drawOval(
      Rect.fromCenter(center: s.translate(0, -1), width: 10.5, height: 5.0),
      Paint()..color = soil.withValues(alpha: vis),
    );
    // Üstte birkaç kesek — düz bir leke değil, kazılmış toprak.
    final clod = Paint()
      ..color = Color.lerp(
        const Color(0xFF6B5744),
        soil,
        1 - trace,
      )!.withValues(alpha: vis);
    canvas.drawOval(
      Rect.fromCenter(center: s.translate(-2.6, -2.4), width: 4.0, height: 2.4),
      clod,
    );
    canvas.drawOval(
      Rect.fromCenter(center: s.translate(1.9, -3.0), width: 3.2, height: 2.0),
      clod,
    );
  }
}

class _HayDrawable extends _Drawable {
  final HayEntity h;
  final double time;
  _HayDrawable(this.h, this.time);
  @override
  double get depth {
    if (h.isBale) return h.gridX + h.gridY + 1.0;
    final off = ResourcePlacement.offsetFor(h.slotIndex);
    return (h.gridX + off.$1) + (h.gridY + off.$2);
  }

  @override
  void draw(Canvas canvas, Size size, Offset camera) {
    if (h.isBale) {
      const bs = 0.5;
      final right = gridToScreen(h.gridX + bs, h.gridY, size, camera);
      final left = gridToScreen(h.gridX, h.gridY + bs, size, camera);
      final front = gridToScreen(h.gridX + bs, h.gridY + bs, size, camera);
      final spriteW = (right.dx - left.dx).abs();
      ResourceRenderer.drawBale(canvas, front.dx, front.dy, spriteW, time, h);
    } else {
      final off = ResourcePlacement.offsetFor(h.slotIndex);
      final s = gridToScreen(h.gridX + off.$1, h.gridY + off.$2, size, camera);
      ResourceRenderer.drawHay(canvas, h, s.dx, s.dy, time);
    }
  }
}

// ─── PAINTER ─────────────────────────────────────────────────────────────────
