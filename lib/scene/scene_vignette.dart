part of '../main.dart';

/// OLAY VİNYETİ — rastgele olayın DÜNYADA izlenebilir hâli.
///
/// Derdi tek cümleyle: olay bir banner'dı. `_stageEventResponse` köyün gövde
/// dilini kımıldatıyordu ama sahnede olan şey her olayda aynıydı — *birkaç kişi
/// bir noktaya yürüyor*. Kuraklıkla fırtınayı, vebayla bereketi birbirinden
/// ayıran hiçbir okunur eylem yoktu.
///
/// Vinyet bunun karşıtı: her olayın ROLLERİ ve ADIMLARI olur. Kuraklıkta biri
/// kovayı indirir ve **boş** çeker; vebada biri sokakta çöker, komşusu yanına
/// diz çöker; yangında kuyuyla ev arasında dolu kovalar taşınır. Oyuncu bakınca
/// ne olduğunu METİN OKUMADAN anlar.
///
/// Mimari: yeni bir hareket sistemi DEĞİL. Faz 3'ün [Act]/[PropKind]
/// dağarcığını (bkz. [_SceneAct]) olay diline koşar — bu yüzden vinyet
/// oyuncuların zaten tanıdığı gövdeyi konuşur.
///
/// ⚠ TEK BÜYÜK TUZAK — SALIVERME. Roller [IntentPriority.ceremony] ile
/// dayatılır; hakem ([_SceneMind]) o önceliği **hiçbir koşulda** düşürmez
/// (`_expireIntent`'in son güvenlik ağı bile `priority < ceremony` şartlı).
/// Yani vinyet oyuncusunu SALIVERMEZSE köylü ömür boyu o rolde donar. Salıverme
/// tek kapıdan olur: [_releaseVignette]. Her çıkış yolu oradan geçmeli.
extension _SceneVignette on _VillageSceneState {
  /// Bir vinyetin azami ömrü (sn) — koreografi tıkansa bile kadro bu sürede
  /// mutlaka salıverilir. Adım dizilerinin hiçbiri bunun yarısını aşmaz.
  static const double _kVignetteLife = 30.0;

  /// Kadro seçiminde tarama yarıçapı (tile) — bundan uzaktakiler sahneye
  /// zamanında yetişemez, çağırmak "haritanın öbür ucundan koşan adam" üretir.
  static const double _kCastRadius = 26.0;

  // ══════════════════════════════════════════════════════════════════════════
  // YÖNETMEN
  // ══════════════════════════════════════════════════════════════════════════

  /// Olayı (ve varsa oyuncunun kararını) bir vinyete çevirir.
  ///
  /// [_stageEventResponse]'tan çağrılır: koro (kalabalığın koşuşması) orada
  /// kalır, BAŞ ROLLER burada oynar. İkisi birlikte sahneyi kurar.
  void _stageVignette(EventOutcome e, {String? choiceId}) {
    // Süren bir vinyet varsa önce onu kapat — iki sahne aynı kadroyu paylaşamaz.
    _releaseVignette();
    switch (e.id) {
      case EventIds.drought:   _vgDrought();
      case EventIds.plague:    _vgPlague(choiceId);
      case EventIds.beastRaid: _vgBeastRaid(choiceId);
      case EventIds.storm:     _vgStorm();
      case EventIds.houseFire: _vgHouseFire(choiceId);
      case EventIds.bard:      _vgBard();
      case EventIds.caravan:   _vgCaravan();
      case EventIds.bounty:    _vgBounty();
      case EventIds.accord:    _vgAccord();
    }
    final vg = _vignette;
    if (vg != null) {
      logDev('Vinyet sahnede: ${vg.title} (${vg.cast.length} rol)',
          tag: '🎭', color: AppUi.sage);
    }
    // Prova telemetrisi — "olay sessizce sahnelenmedi" kör noktasının kanıtı
    // (bkz. test/event_vignette_test.dart).
    kProbeVignetteId = vg?.eventId ?? '';
    kProbeVignetteCast = vg?.cast.length ?? 0;
    if (kCaptureAutoWatch && vg != null) _watchVignette();
  }

  /// Vinyet saati. Kadro adımlarını [_tickActs] yürütür; burası yalnız ÖMRÜ ve
  /// SALIVERMEYİ yönetir (bkz. sınıf başlığındaki tuzak).
  void _tickVignette(double dt) {
    final vg = _vignette;
    if (vg == null) return;
    vg.life -= dt;
    if (vg.life <= 0) {
      _releaseVignette();
      return;
    }
    // Kadronun tamamı eylemini bitirdiyse sahne de bitmiştir — ömrün dolmasını
    // beklemek, rolünü oynamış köylüyü boşuna kilitli tutardı.
    for (final v in vg.cast) {
      if (v.act != null && _villagers.contains(v)) return;
    }
    _releaseVignette();
  }

  /// SAHNEYİ KAPAT — kadroyu dayatılmış niyetten kurtarır.
  ///
  /// Ceremony önceliğini yalnız burası geri alabilir. `mind.clear()` çağrılmazsa
  /// köylü sonsuza dek "sahnede" sayılır ve hiçbir teklif onu kurtaramaz.
  void _releaseVignette() {
    final vg = _vignette;
    if (vg == null) return;
    for (final v in vg.cast) {
      v.act = null;
      v.actPose = null;
      v.prop = PropKind.none;
      if (v.mind.intent.kind == IntentKind.ceremony) v.mind.clear();
    }
    _vignette = null;
    kProbeVignetteId = '';
    kProbeVignetteCast = 0;
    // Kamera sahneye kilitliyse bırak — izlenecek bir şey kalmadı.
    if (_watchLeft > 0) _watchLeft = 0;
  }

  /// "İZLE" — kamerayı sahnenin odağına götürür (banner düğmesi).
  ///
  /// Zoom'a DOKUNMAZ: oyuncunun kurduğu yakınlık onun kararıdır, olay onu
  /// zorla yakınlaştırmaz. Takip kanalı (`_followedVillager`) düşürülür —
  /// iki kamera aynı kareyi çekiştirirse ikisi de titrer.
  void _watchVignette() {
    final vg = _vignette;
    if (vg == null) return;
    _followedVillager = null;
    _watchX = vg.gx;
    _watchY = vg.gy;
    // Sahne bitene kadar bak; en az 3 sn (son saniyesinde basılsa bile kayış
    // tamamlansın), en çok sahnenin kalan ömrü.
    _watchLeft = vg.life.clamp(3.0, _kVignetteLife);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // KADRO + ROL DAĞITIMI
  // ══════════════════════════════════════════════════════════════════════════

  /// Sahneyi açar — sonraki [_role] çağrıları bu sahneye yazılır.
  /// [gx],[gy] kamera odağı: "İzle"ye basınca kadraja gelecek nokta.
  void _openVignette(String eventId, String title, double gx, double gy) {
    _vignette = Vignette(eventId: eventId, title: title, gx: gx, gy: gy,
        life: _kVignetteLife);
  }

  /// Bir role oyuncu bulur, adımları giydirir ve sahneye yazar.
  ///
  /// [near] rolün başlaması gereken yer (oraya en yakın uygun köylü seçilir),
  /// [reason] köylü panelinde görünecek birinci ağız sebep — boş bırakılamaz.
  /// Uygun kimse yoksa `null` döner ve koreografi o rolsüz devam eder: sahne
  /// eksik oynanır ama ASLA yarım kilitlenmez.
  VillagerEntity? _role(
    String label,
    String reason,
    double nearX,
    double nearY,
    List<ActStep> steps, {
    NpcEmotion emotion = NpcEmotion.none,
    double emotionDur = 8.0,
    bool Function(VillagerEntity)? prefer,
  }) {
    final vg = _vignette;
    if (vg == null || steps.isEmpty) return null;
    final v = _castNear(nearX, nearY, prefer: prefer);
    if (v == null) return null;
    _prepForScene(v);
    v.mind.impose(IntentKind.ceremony, reason);
    v.act = Act(label, steps);
    if (emotion != NpcEmotion.none) v.feel(emotion, emotionDur);
    vg.cast.add(v);
    return v;
  }

  /// Köylüyü sahneye hazırlar: yürüyen eylemi, elindeki nesneyi, oturmayı ve
  /// yumuşak aktiviteyi düşürür.
  ///
  /// Elde kalan nesne en sinsi artıktır: rolü üstüne giydirilen köylü eski
  /// eyleminin kovasını ömür boyu taşırdı (bkz. [_cancelAct]'ın gerekçesi).
  void _prepForScene(VillagerEntity v) {
    v.act = null;
    v.actPose = null;
    v.prop = PropKind.none;
    if (v.sitClaimed) v.cancelSit(); // slot serbest kalsın, yoksa sızar
    v.activity = VillagerActivity.none;
    // Yarım kalan sohbetin baloncuğu sahnenin üstünde asılı kalmasın (kendi
    // sayacı zaten dönüyor; bekletmek çöken adamın başında konuşma balonu
    // bırakırdı). Karşı taraf etkilenmez — onun sayacı ayrı.
    v.chatBubbleTime = 0;
    v.chatBubbleIcon = '';
    v.clearConvo();
  }

  /// [nearX],[nearY] noktasına en yakın uygun köylü. Sahnede zaten rolü olan
  /// seçilmez.
  ///
  /// İKİ KADEMELİ — ve bu isteğe bağlı bir incelik değil, sistemin çalışması
  /// için ŞART. Ölçüm: 18 kişilik referans köyde akşamüstü 15 köylü bir
  /// aktivitede, 11'i ateş başında oturmuş, 6'sı iş döngüsündeydi; katı filtre
  /// geriye SIFIR aday bırakıyordu. Yani sahne sessizce hiç kurulmuyordu.
  ///
  ///   1. Serbest olanlar — kimseyi bölmeden.
  ///   2. Yoksa BÖLÜNEBİLİR olanlar — işi başındaki, ateş başında oturan,
  ///      sohbet eden. Zaten olayın anlamı budur: köy elindekini bırakır.
  ///
  /// İkinci kademe bile dokunmaz: kavga, suç, kaçış, kovalama, dans/müzik.
  /// Onların kendi sahnesi var ve yarıda kesilirse saçmalar.
  VillagerEntity? _castNear(double nearX, double nearY,
      {bool Function(VillagerEntity)? prefer}) =>
      _bestCast(nearX, nearY, prefer, strict: true) ??
      _bestCast(nearX, nearY, prefer, strict: false);

  VillagerEntity? _bestCast(double nearX, double nearY,
      bool Function(VillagerEntity)? prefer, {required bool strict}) {
    final vg = _vignette;
    VillagerEntity? best;
    double bestScore = double.infinity;
    for (final v in _villagers) {
      if (vg != null && vg.cast.contains(v)) continue;
      if (!(strict ? _vignetteFree(v) : _vignetteInterruptible(v))) continue;
      final d = _wdist(v.gridX, v.gridY, nearX, nearY);
      if (d > _kCastRadius) continue;
      // Tercih edilen aday mesafede 12 tile'lık indirim alır: "şifacıyı çağır"
      // dediğimizde biraz uzaktaki şifacı, bitişikteki rastgele köylüye yeğlenir
      // — ama harita ucundakine değil.
      final score = prefer != null && prefer(v) ? d - 12.0 : d;
      if (score < bestScore) {
        bestScore = score;
        best = v;
      }
    }
    return best;
  }

  /// Hiçbir şeyi bölmeden sahneye alınabilir mi (1. kademe)?
  bool _vignetteFree(VillagerEntity v) =>
      _vignetteInterruptible(v) &&
      !v.hasActiveJob &&
      !v.sitClaimed &&
      !v.isSeatedAtFire &&
      v.activity == VillagerActivity.none;

  /// Bölünerek sahneye alınabilir mi (2. kademe)? Buradaki redler MUTLAK:
  /// hiçbir olay bunları bölemez.
  bool _vignetteInterruptible(VillagerEntity v) {
    if (v.isDying || v.isLeaving || v.isSleeping || v.isInsideBuilding) {
      return false;
    }
    if (v.isCarrying) return false;                 // yükünü ortada bırakmaz
    if (v.sickDays > 0 || v.injuryDays > 0 || v.laborDays > 0) return false;
    if (v.isChild) return false;                    // çocuk rolleri _kidRole'ün
    // Başlamış suç/kavga/kaçış/başka sahne yarıda kesilirse saçmalar.
    if (v.mind.intent.priority >= IntentPriority.committed) return false;
    return switch (v.activity) {
      // Bölünebilir: gündelik, sahibi olmayan uğraşlar.
      VillagerActivity.none ||
      VillagerActivity.chat ||
      VillagerActivity.warm ||
      VillagerActivity.storytelling ||
      VillagerActivity.listening ||
      VillagerActivity.playing => true,
      // Bölünemez: kendi evre makinesi olan sahneler.
      _ => false,
    };
  }

  /// Çocuk rolü — yola koşan, merakla bakan gövde. Yetişkin filtresinin
  /// tersine çevrilmiş hâli; bulunamazsa rol düşer.
  VillagerEntity? _kidRole(
    String label,
    String reason,
    double nearX,
    double nearY,
    List<ActStep> steps, {
    NpcEmotion emotion = NpcEmotion.none,
  }) {
    final vg = _vignette;
    if (vg == null) return null;
    VillagerEntity? best;
    double bestD = double.infinity;
    for (final v in _villagers) {
      if (!v.isChild) continue;
      if (vg.cast.contains(v)) continue;
      if (v.isDying || v.isLeaving || v.isSleeping || v.isInsideBuilding) {
        continue;
      }
      if (v.isCarrying) continue;
      if (v.sickDays > 0 || v.injuryDays > 0) continue;
      // Oyun/sohbet bölünebilir (çocuğu koşturan şey zaten olayın kendisi),
      // ama kaçış/kaçırılma bölünemez.
      if (v.activity != VillagerActivity.none &&
          v.activity != VillagerActivity.playing &&
          v.activity != VillagerActivity.chat &&
          v.activity != VillagerActivity.warm &&
          v.activity != VillagerActivity.listening) {
        continue;
      }
      if (v.mind.intent.priority >= IntentPriority.committed) continue;
      final d = _wdist(v.gridX, v.gridY, nearX, nearY);
      if (d > _kCastRadius || d >= bestD) continue;
      bestD = d;
      best = v;
    }
    if (best == null) return null;
    _prepForScene(best);
    best.mind.impose(IntentKind.ceremony, reason);
    best.act = Act(label, steps);
    if (emotion != NpcEmotion.none) best.feel(emotion, 8.0);
    vg.cast.add(best);
    return best;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // KOREOGRAFİLER — her olayın kendi iskeleti
  // ══════════════════════════════════════════════════════════════════════════
  //
  // Yazım kuralı: sahne bir CÜMLE anlatmalı ve o cümle metinsiz okunmalı.
  // "Kova indi, boş çıktı" (kuraklık) ile "kova doldu, ateşe koştu" (yangın)
  // aynı nesneyi kullanır ama zıt şey anlatır — fark ADIM DİZİSİNDEDİR.

  /// KURAKLIK — kuyu boş çıkar. Köyün en okunur mikro-sahnesinin (kuyudan su
  /// taşıma) TERSİ: aynı hazırlık, gelmeyen sonuç.
  void _vgDrought() {
    final well = _firstBuildingOf(BuildingType.well) ??
        _firstBuildingOf(BuildingType.fountain);
    final (wx, wy) = well != null ? _centerOf(well) : _villageCenterD();
    _openVignette(EventIds.drought, 'Kuyu boş çıktı', wx, wy);

    // A — kovayı indirir, çeker, BOŞ kalır, bir daha dener, kovayı bırakır.
    _role('kuyudan su çekmeye çalışıyor', 'kuyuda su kalmış mı, bakıyorum',
        wx, wy, [
      ActStep.goTo(wx, wy),
      const ActStep.take(PropKind.bucketEmpty),
      ActStep.face(wx, wy),
      const ActStep.work(2.4, pose: ActPose.stoop),   // indiriyor
      const ActStep.work(1.8, pose: ActPose.labor),   // ipi çekiyor
      // Kova hâlâ bucketEmpty — sahnenin bütün anlamı bu tek satırda: dolu
      // kovaya GEÇMEZ. Oyuncu elde boş kovayı görür.
      const ActStep.work(1.6, pose: ActPose.stand),   // duruyor, bakıyor
      const ActStep.work(2.2, pose: ActPose.labor),   // bir daha çekiyor
      const ActStep.put(),                            // kovayı yere bırakır
      const ActStep.work(3.0, pose: ActPose.kneel),   // kuyu başına çöker
    ], emotion: NpcEmotion.wonder);

    // B — komşu birkaç adım ötede durur, ona bakar.
    _role('kuyu başındakine bakıyor', 'kuyudan ses gelmedi', wx + 2, wy + 1, [
      ActStep.goTo(wx + 1.6, wy + 1.2),
      ActStep.face(wx, wy),
      const ActStep.work(9.0, pose: ActPose.stand),
    ], emotion: NpcEmotion.fear);

    // C — boş testiyle gelir, sıraya durur, eli boş döner.
    _role('kuyu sırasında bekliyor', 'su almaya geldim', wx - 2, wy + 2, [
      ActStep.goTo(wx - 1.5, wy + 1.5),
      const ActStep.take(PropKind.bucketEmpty),
      ActStep.face(wx, wy),
      const ActStep.work(7.0, pose: ActPose.stand),
      const ActStep.put(),
    ], emotion: NpcEmotion.fear);
  }

  /// VEBA — biri sokakta çöker, yakını yanına diz çöker, şifacı bohçayla koşar.
  /// Ölüm bilançosu [_plagueToll]'un işi; bu sahne onun İNSAN yüzü.
  void _vgPlague(String? choiceId) {
    // Hasta düşecek yer: köyün göbeği değil, birinin yürüdüğü sokak — sahneyi
    // meydana taşımak "tören" gibi durur, oysa bu ani bir çöküş.
    final fallen = _castNear(_villageCenterD().$1, _villageCenterD().$2);
    final (fx, fy) = fallen != null
        ? (fallen.gridX, fallen.gridY)
        : _villageCenterD();
    _openVignette(EventIds.plague, 'Biri sokakta düştü', fx, fy);

    // A — yürürken durur, sendeler, çöker ve kalkmaz.
    _role('ayakta duramıyor', 'başım dönüyor', fx, fy, [
      const ActStep.work(1.0, pose: ActPose.stand),   // durur
      const ActStep.work(1.4, pose: ActPose.stoop),   // öne katlanır
      const ActStep.work(12.0, pose: ActPose.slump),  // yere çöker, kalmaz
    ], emotion: NpcEmotion.grief, emotionDur: 12);

    // B — yakını koşar, yanına diz çöker.
    _role('düşenin başında', 'onu yalnız bırakamam', fx + 3, fy + 2, [
      ActStep.goTo(fx + 0.9, fy + 0.6),
      ActStep.face(fx, fy),
      const ActStep.work(11.0, pose: ActPose.kneel),
    ], emotion: NpcEmotion.grief, emotionDur: 11);

    // C — şifacı bohçayla gelir. Karar 'healer' ise erken yetişir (kısa yol),
    // değilse geç kalır: aynı roller, geciken zamanlama.
    final church = _firstBuildingOf(BuildingType.church);
    final (hx, hy) = church != null ? _centerOf(church) : (fx - 4, fy - 3);
    final late = choiceId != 'healer';
    _role('şifa taşıyor', late ? 'geç kaldım galiba' : 'ilacı yetiştiriyorum',
        hx, hy, [
      const ActStep.take(PropKind.basket),
      if (late) const ActStep.work(3.5, pose: ActPose.stand), // duraksama
      ActStep.goTo(fx - 0.9, fy + 0.7),
      ActStep.face(fx, fy),
      const ActStep.work(2.0, pose: ActPose.stoop),
      const ActStep.put(),
      ActStep.work(late ? 3.0 : 5.0, pose: ActPose.kneel),
    ], emotion: NpcEmotion.fear);
  }

  /// CANAVAR — kenara iki gövde çakılır, üçüncüsü köye haber taşır.
  /// Muhafız kararında duruş İLERİ, kaçış kararında sahne GERİYE akar.
  void _vgBeastRaid(String? choiceId) {
    final (ex, ey) = _villageEdgePoint();
    final (cx, cy) = _villageCenterD();
    _openVignette(EventIds.beastRaid, 'Ağaç hattına bakıyorlar', ex, ey);

    if (choiceId == 'guards') {
      // İki kişi kenara dizilir ve ORMANA döner — sırtı köye, yüzü karanlığa.
      _role('ağaç hattını gözlüyor', 'oradan bir şey geliyor', ex, ey, [
        ActStep.goTo(ex, ey),
        ActStep.face(ex * 2 - cx, ey * 2 - cy),      // köyün TERSİNE bakar
        const ActStep.work(12.0, pose: ActPose.stand),
      ], emotion: NpcEmotion.anger, emotionDur: 12);
      _role('nöbette', 'yanından ayrılmam', ex + 1.5, ey + 1, [
        ActStep.goTo(ex + 1.4, ey + 1.0),
        ActStep.face(ex * 2 - cx, ey * 2 - cy),
        const ActStep.work(11.0, pose: ActPose.stand),
      ], emotion: NpcEmotion.anger, emotionDur: 11);
    } else {
      // Kaçış: kenardaki adam köye doğru koşar, ateşin başında soluklanır.
      _role('köye koşuyor', 'kapıları kapatın', ex, ey, [
        ActStep.goTo(ex, ey),
        ActStep.goTo(cx, cy),
        ActStep.face(ex, ey),
        const ActStep.work(6.0, pose: ActPose.stand),
      ], emotion: NpcEmotion.fear, emotionDur: 10);
    }

    // Çoban: ağıla doğru sürüyü toplar (hayvan sistemi ayrı; bu onun gövdesi).
    final barn = _firstBuildingOf(BuildingType.barn) ??
        _firstBuildingOf(BuildingType.stable);
    if (barn != null) {
      final (bx, by) = _centerOf(barn);
      _role('sürüyü ağıla sokuyor', 'hepsi içeri girsin', bx, by, [
        ActStep.goTo(bx + 1.2, by + 0.8),
        ActStep.face(bx, by),
        const ActStep.work(4.0, pose: ActPose.labor),
        ActStep.goTo(bx - 1.2, by + 0.8),
        ActStep.face(bx, by),
        const ActStep.work(4.0, pose: ActPose.labor),
      ], emotion: NpcEmotion.fear);
    }

    // Bir çocuk ateşin dibine kaçar ve ormana bakar.
    final fire = _firepitBuilding;
    if (fire != null) {
      final (fx, fy) = _centerOf(fire);
      _kidRole('ateşin dibine kaçtı', 'orada bir şey var', fx, fy, [
        ActStep.goTo(fx + 0.8, fy + 0.8),
        ActStep.face(ex, ey),
        const ActStep.work(9.0, pose: ActPose.stand),
      ], emotion: NpcEmotion.fear);
    }
  }

  /// FIRTINA — köy dışarıda ne varsa içeri alır. Kimse kaçmaz; TOPLAR.
  void _vgStorm() {
    final ware = _firstBuildingOf(BuildingType.warehouse);
    final fire = _firepitBuilding;
    final (cx, cy) = ware != null ? _centerOf(ware) : _villageCenterD();
    _openVignette(EventIds.storm, 'Fırtınadan önce toplanıyor', cx, cy);

    // A — dışarıdaki sepeti kapıp ambara sokar.
    _role('malı içeri alıyor', 'ıslanmadan kaldıralım', cx + 3, cy + 2, [
      const ActStep.take(PropKind.basket),
      ActStep.goTo(cx, cy),
      ActStep.face(cx, cy),
      const ActStep.work(1.8, pose: ActPose.stoop),
      const ActStep.put(),
      ActStep.goTo(cx + 2.5, cy + 1.8),
      const ActStep.take(PropKind.sack),
      ActStep.goTo(cx, cy),
      const ActStep.work(1.6, pose: ActPose.stoop),
      const ActStep.put(),
    ], emotion: NpcEmotion.fear);

    // B — ateşi kurtarmaya odun taşır (ıslanırsa ocak söner: [_SceneFire]).
    if (fire != null) {
      final (fx, fy) = _centerOf(fire);
      _role('ateşe odun yığıyor', 'ocak sönmesin', fx + 2, fy + 2, [
        const ActStep.take(PropKind.firewood),
        ActStep.goTo(fx + 0.9, fy + 0.7),
        ActStep.face(fx, fy),
        const ActStep.work(2.4, pose: ActPose.stoop),
        const ActStep.put(),
        const ActStep.work(2.0, pose: ActPose.labor),
      ], emotion: NpcEmotion.fear);
    }

    // C — kepenk kapatıyor: KENDİ evinin önünde eğilip doğrulur.
    // Adayı önce seçip evini okuyoruz; `near` olarak onun bulunduğu yeri
    // veriyoruz ki `_role` büyük olasılıkla aynı kişiyi seçsin — "eve" değil
    // "en yakın kişiyi eve" göndermek başkasının kapısında kepenk kapattırırdı.
    final c = _castNear(cx, cy);
    if (c != null) {
      final home = c.homeBuilding;
      final (hx, hy) = home is BuildingEntity
          ? _centerOf(home)
          : (c.gridX, c.gridY);
      _role('kepenkleri kapatıyor', 'rüzgâr camı kırmasın', c.gridX, c.gridY, [
        ActStep.goTo(hx + 0.8, hy + 1.0),
        ActStep.face(hx, hy),
        const ActStep.work(3.0, pose: ActPose.labor),
        const ActStep.work(1.4, pose: ActPose.stoop),
        const ActStep.work(3.0, pose: ActPose.labor),
      ], emotion: NpcEmotion.fear);
    }
  }

  /// YANGIN — kuyu ile ev arasında DOLU kovalar gidip gelir.
  ///
  /// Kuraklığın ikizi ve zıddı: aynı kuyu, aynı kova, ama burada kova DOLAR ve
  /// koşarak taşınır. Zincir hissi iki taşıyıcının kaydırılmış (staggered)
  /// başlangıcından doğar — biri dönerken öteki gidiyordur.
  void _vgHouseFire(String? choiceId) {
    final burning = _burningBuildings.isNotEmpty ? _burningBuildings.first : null;
    final (bx, by) = burning != null ? _centerOf(burning) : _villageCenterD();
    final well = _firstBuildingOf(BuildingType.well) ??
        _firstBuildingOf(BuildingType.fountain);
    final (wx, wy) = well != null ? _centerOf(well) : _villageCenterD();
    // Odak: kuyu ile yangının ORTASI — zincirin tamamı kadraja girsin.
    _openVignette(EventIds.houseFire, 'Kova zinciri', (bx + wx) / 2, (by + wy) / 2);

    if (choiceId == 'retreat') {
      // Vazgeçildi: iki kişi eve bakar, biri dizlerinin üstüne çöker.
      _role('evin yanışını seyrediyor', 'yetişemedik', bx + 3, by + 2, [
        ActStep.goTo(bx + 2.4, by + 1.8),
        ActStep.face(bx, by),
        const ActStep.work(4.0, pose: ActPose.stand),
        const ActStep.work(7.0, pose: ActPose.kneel),
      ], emotion: NpcEmotion.grief, emotionDur: 11);
      _role('geri çekiliyor', 'ateş çok büyük', bx - 2, by + 2, [
        ActStep.goTo(bx - 2.2, by + 1.6),
        ActStep.face(bx, by),
        const ActStep.work(9.0, pose: ActPose.stand),
      ], emotion: NpcEmotion.fear);
      return;
    }

    // Taşıyıcı — kuyudan doldurur, yangına koşar, suyu atar, geri döner.
    List<ActStep> carrier(double offX, double offY, double delay) => [
          if (delay > 0) ActStep.work(delay, pose: ActPose.stand),
          ActStep.goTo(wx + offX, wy + offY),
          const ActStep.take(PropKind.bucketEmpty),
          ActStep.face(wx, wy),
          const ActStep.work(1.6, pose: ActPose.stoop),   // doldurur
          const ActStep.put(),
          const ActStep.take(PropKind.bucketFull),        // ağır → yavaş yürür
          ActStep.goTo(bx + offX, by + offY),
          ActStep.face(bx, by),
          const ActStep.work(1.2, pose: ActPose.labor),   // suyu savurur
          const ActStep.put(),
          ActStep.goTo(wx + offX, wy + offY),             // ikinci tur
          const ActStep.take(PropKind.bucketEmpty),
          ActStep.face(wx, wy),
          const ActStep.work(1.6, pose: ActPose.stoop),
          const ActStep.put(),
          const ActStep.take(PropKind.bucketFull),
          ActStep.goTo(bx + offX, by + offY),
          ActStep.face(bx, by),
          const ActStep.work(1.2, pose: ActPose.labor),
          const ActStep.put(),
        ];

    _role('kova taşıyor', 'su yetiştirmem lazım', wx, wy,
        carrier(0.9, 0.6, 0), emotion: NpcEmotion.fear, emotionDur: 14);
    _role('kova taşıyor', 'zincir kopmasın', bx, by,
        carrier(-0.9, 0.9, 2.6), emotion: NpcEmotion.fear, emotionDur: 14);

    // Zincirin ortasındaki adam: kımıldamaz, elden ele verir.
    _role('zincirin ortasında', 'elden ele veriyoruz',
        (bx + wx) / 2, (by + wy) / 2, [
      ActStep.goTo((bx + wx) / 2, (by + wy) / 2),
      ActStep.face(bx, by),
      const ActStep.work(14.0, pose: ActPose.labor),
    ], emotion: NpcEmotion.fear, emotionDur: 14);
  }

  /// OZAN — çocuk yola koşup karşılar, ateş başında çember kurulur.
  /// Müzik/dans aktivitelerini [_stageCelebration] yürütür; vinyet KARŞILAMA
  /// ânını ekler (olayın "geliyor" hissi sahnede yoktu).
  void _vgBard() {
    final (ex, ey) = _villageEdgePoint();
    final fire = _firepitBuilding;
    final (fx, fy) = fire != null ? _centerOf(fire) : _villageCenterD();
    _openVignette(EventIds.bard, 'Ozanı karşılıyorlar', fx, fy);

    _kidRole('ozanı karşılamaya koştu', 'türkü söyleyen geliyor', ex, ey, [
      ActStep.goTo(ex, ey),
      ActStep.face(ex, ey),
      const ActStep.work(2.0, pose: ActPose.stand),
      ActStep.goTo(fx + 1.0, fy + 0.8),               // ozanı köye çeker
      ActStep.face(fx, fy),
      const ActStep.work(5.0, pose: ActPose.stand),
    ], emotion: NpcEmotion.joy);

    _role('ozana yer açıyor', 'buraya otursun', fx, fy, [
      ActStep.goTo(fx + 1.4, fy - 0.6),
      ActStep.face(fx, fy),
      const ActStep.work(2.4, pose: ActPose.labor),   // kütük çekiyor
      const ActStep.work(6.0, pose: ActPose.stand),
    ], emotion: NpcEmotion.joy);

    _role('ozana ekmek getiriyor', 'yoldan gelene bir lokma', fx + 3, fy + 2, [
      const ActStep.take(PropKind.bread),
      ActStep.goTo(fx - 1.2, fy + 0.9),
      ActStep.face(fx, fy),
      const ActStep.work(1.6, pose: ActPose.stoop),
      const ActStep.put(),
      const ActStep.work(5.0, pose: ActPose.stand),
    ], emotion: NpcEmotion.joy);
  }

  /// KERVAN — pazarda yük iner, çuval ambara taşınır, sepetle eve dönülür.
  void _vgCaravan() {
    final market = _firstBuildingOf(BuildingType.market);
    final (mx, my) = market != null ? _centerOf(market) : _villageCenterD();
    final ware = _firstBuildingOf(BuildingType.warehouse);
    _openVignette(EventIds.caravan, 'Kervanın yükü iniyor', mx, my);

    // A — pazarda pazarlık, sepetle eve.
    final a = _castNear(mx, my);
    final aHome = a?.homeBuilding;
    final (ax, ay) = aHome is BuildingEntity ? _centerOf(aHome) : (mx + 3, my + 3);
    _role('pazarda pazarlık ediyor', 'kervandan bir şeyler alacağım', mx, my, [
      ActStep.goTo(mx + 1.0, my + 0.8),
      ActStep.face(mx, my),
      const ActStep.work(4.0, pose: ActPose.stand),
      const ActStep.take(PropKind.basket),
      ActStep.goTo(ax, ay),
      const ActStep.work(1.4, pose: ActPose.stoop),
      const ActStep.put(),
    ], emotion: NpcEmotion.joy);

    // B — çuvalı ambara indirir (kervanın yükü gözle görünür olsun).
    if (ware != null) {
      final (wx, wy) = _centerOf(ware);
      _role('kervanın yükünü indiriyor', 'çuvalları ambara', mx, my, [
        ActStep.goTo(mx - 1.0, my + 0.9),
        ActStep.face(mx, my),
        const ActStep.work(1.8, pose: ActPose.stoop),
        const ActStep.take(PropKind.sack),
        ActStep.goTo(wx, wy),
        ActStep.face(wx, wy),
        const ActStep.work(1.6, pose: ActPose.stoop),
        const ActStep.put(),
        ActStep.goTo(mx - 1.0, my + 0.9),
        const ActStep.take(PropKind.sack),
        ActStep.goTo(wx, wy),
        const ActStep.work(1.6, pose: ActPose.stoop),
        const ActStep.put(),
      ], emotion: NpcEmotion.joy, emotionDur: 12);
    }

    // C — çocuk tezgâhın önüne yapışır.
    _kidRole('tezgâhın önünde', 'onu görmek istiyorum', mx, my, [
      ActStep.goTo(mx + 0.7, my + 1.2),
      ActStep.face(mx, my),
      const ActStep.work(9.0, pose: ActPose.stand),
    ], emotion: NpcEmotion.wonder);
  }

  /// BEREKET — tarlada biçilir, dolu sepet ambara taşınır, istif yapılır.
  void _vgBounty() {
    // Odak: ekini olgun bir tarla; yoksa ambar; o da yoksa merkez.
    double tx, ty;
    final ripe = _farmTiles.where((f) => f.stage >= 3).toList();
    final ware = _firstBuildingOf(BuildingType.warehouse);
    if (ripe.isNotEmpty) {
      final f = ripe[_rng.nextInt(ripe.length)];
      tx = f.col.toDouble();
      ty = f.row.toDouble();
    } else if (ware != null) {
      (tx, ty) = _centerOf(ware);
    } else {
      (tx, ty) = _villageCenterD();
    }
    final (wx, wy) = ware != null ? _centerOf(ware) : (tx + 4, ty + 3);
    _openVignette(EventIds.bounty, 'Hasat taşınıyor', tx, ty);

    // İki hasatçı, kaydırılmış başlangıçla: tarla ↔ ambar akışı sürekli görünür.
    List<ActStep> reaper(double off, double delay) => [
          if (delay > 0) ActStep.work(delay, pose: ActPose.stand),
          ActStep.goTo(tx + off, ty + off * 0.5),
          ActStep.face(tx, ty),
          const ActStep.work(3.2, pose: ActPose.labor),   // biçiyor
          const ActStep.take(PropKind.basket),
          ActStep.goTo(wx + off, wy),
          ActStep.face(wx, wy),
          const ActStep.work(1.6, pose: ActPose.stoop),
          const ActStep.put(),
          ActStep.goTo(tx + off, ty + off * 0.5),
          const ActStep.work(3.0, pose: ActPose.labor),
          const ActStep.take(PropKind.basket),
          ActStep.goTo(wx + off, wy),
          const ActStep.work(1.4, pose: ActPose.stoop),
          const ActStep.put(),
        ];

    _role('hasadı taşıyor', 'başak sapı büküyor', tx, ty,
        reaper(0.8, 0), emotion: NpcEmotion.joy, emotionDur: 14);
    _role('hasadı taşıyor', 'bu yıl bereket var', tx, ty,
        reaper(-0.9, 2.4), emotion: NpcEmotion.joy, emotionDur: 14);

    // Ambar kapısında istifçi — akışın vardığı yer boş kalmasın.
    if (ware != null) {
      _role('ambarda istif yapıyor', 'hepsi sığacak mı bakalım', wx, wy, [
        ActStep.goTo(wx + 1.2, wy + 0.9),
        ActStep.face(wx, wy),
        const ActStep.work(13.0, pose: ActPose.labor),
      ], emotion: NpcEmotion.joy, emotionDur: 13);
    }
  }

  /// SULH — iki küskün hane meydanda buluşur, biri ekmeğini uzatır, tanık bakar.
  /// [_stageReconciliation] hanenin SAYISINI onarır; bu sahne onun görünür ânı.
  void _vgAccord() {
    final hall = _firstBuildingOf(BuildingType.townhall) ?? _firepitBuilding;
    final (cx, cy) = hall != null ? _centerOf(hall) : _villageCenterD();
    _openVignette(EventIds.accord, 'İki hane barışıyor', cx, cy);

    // A — küskün hanenin adamı; ekmeği o uzatır (barışı teklif eden taraf).
    final grieved = _houses.mostAggrieved;
    final a = _role('barışmaya geldi', 'bu iş burada bitsin', cx, cy, [
      const ActStep.take(PropKind.bread),
      ActStep.goTo(cx - 0.9, cy + 0.6),
      ActStep.face(cx + 0.9, cy + 0.6),
      const ActStep.work(2.4, pose: ActPose.stand),
      const ActStep.work(1.2, pose: ActPose.stoop),   // ekmeği uzatır
      const ActStep.put(),
      const ActStep.work(6.0, pose: ActPose.stand),
    ], emotion: NpcEmotion.love, prefer: (v) =>
        grieved != null && v.surname == grieved);

    // B — karşı hane. Aynı soyadı seçilmesin: barış tek hanede olmaz.
    _role('elini uzatıyor', 'küskünlük yeter', cx + 2, cy + 1, [
      ActStep.goTo(cx + 0.9, cy + 0.6),
      ActStep.face(cx - 0.9, cy + 0.6),
      const ActStep.work(3.0, pose: ActPose.stand),
      const ActStep.work(1.2, pose: ActPose.stoop),   // ekmeği alır
      const ActStep.work(6.0, pose: ActPose.stand),
    ], emotion: NpcEmotion.love, prefer: (v) =>
        a != null && v.surname.isNotEmpty && v.surname != a.surname);

    // C — tanık: köy bu ânı görmeli, yoksa barış dedikodu olarak kalır.
    _role('barışa tanık', 'gözlerimle gördüm', cx - 2, cy + 2, [
      ActStep.goTo(cx - 2.0, cy + 1.8),
      ActStep.face(cx, cy),
      const ActStep.work(11.0, pose: ActPose.stand),
    ], emotion: NpcEmotion.wonder, emotionDur: 11);
  }
}

/// Sahnedeki vinyet — roller, odak noktası ve kalan ömür.
///
/// Kadro listesi salıverme için ŞART: ceremony önceliğiyle dayatılan niyeti
/// yalnız bu listeyi gezen [_SceneVignette._releaseVignette] geri alabilir.
class Vignette {
  /// Hangi olayın sahnesi ([EventIds]).
  final String eventId;

  /// Oyuncu-yüzü kısa başlık — "İzle" düğmesinin ipucunda görünür.
  final String title;

  /// Kamera odağı (tile) — "İzle"ye basınca kadraja gelecek nokta.
  final double gx, gy;

  /// Rol verilmiş köylüler. Salıverme buradan geçer.
  final List<VillagerEntity> cast = [];

  /// Kalan ömür (sn). Sıfırlanınca kadro koşulsuz salıverilir.
  double life;

  Vignette({
    required this.eventId,
    required this.title,
    required this.gx,
    required this.gy,
    required this.life,
  });
}
