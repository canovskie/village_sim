part of '../../main.dart';

/// Olayları dünya içinde oynatan genel vinyet çalışma zamanı.
/// Yeni içerik kendi rol ve adımlarını bağlar; motor kadro salıverme, kamera ve
/// yönetmen yaşam döngüsünü ortak yürütür.
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

  /// Katalog olayları için boş bağlantı noktası. Yeni olay paketi kendi
  /// koreografisini buradan kaydeder.
  void _stageVignette(EventOutcome e, {String? choiceId}) {
    _releaseVignette();
  }

  /// Sahne kurulduktan sonraki ortak kuyruk: günlük satırı, prova telemetrisi,
  /// capture harness'ının otomatik kamerası.
  // ignore: unused_element — retained event-package staging hook.
  void _announceVignette() {
    final vg = _vignette;
    if (vg != null) {
      logDev(
        'Vinyet sahnede: ${vg.title} (${vg.cast.length} rol)',
        tag: '🎭',
        color: AppUi.sage,
      );
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
    final castIdle = vg.cast.every(
      (v) => !_villagers.contains(v) || v.act == null,
    );
    _handleEventSceneSignals(_eventSceneDirector.tick(dt, castIdle: castIdle));
    if (_vignette != null && !_eventSceneDirector.isBusy) {
      _releaseVignette(resetDirector: false);
    }
  }

  /// Saf yönetmenin sinyallerini dünya tarafındaki beat kancalarına çevirir.
  /// Olay paketleri yalnız kendi beat id'lerini dinler; sıra ve timeout kararı
  /// burada değil [EventSceneDirector]'dadır.
  void _handleEventSceneSignals(List<EventSceneSignal> signals) {
    var completed = false;
    for (final signal in signals) {
      final vg = _vignette;
      if (vg == null || signal.plan.key != vg.sceneKey) continue;
      switch (signal.kind) {
        case EventSceneSignalKind.beatEntered:
          final id = signal.beat!.id;
          vg.beatId = id;
          vg.onBeatEnter[id]?.call();
        case EventSceneSignalKind.completed:
        case EventSceneSignalKind.cancelled:
          completed = true;
        case EventSceneSignalKind.started:
        case EventSceneSignalKind.beatExited:
          break;
      }
    }
    if (completed && _vignette != null) {
      _releaseVignette(resetDirector: false);
    }
  }

  /// SAHNEYİ KAPAT — kadroyu dayatılmış niyetten kurtarır.
  ///
  /// Ceremony önceliğini yalnız burası geri alabilir. `mind.clear()` çağrılmazsa
  /// köylü sonsuza dek "sahnede" sayılır ve hiçbir teklif onu kurtaramaz.
  void _releaseVignette({bool resetDirector = true}) {
    final vg = _vignette;
    if (vg == null) {
      if (resetDirector) _eventSceneDirector.reset();
      return;
    }
    for (final v in vg.cast) {
      v.act = null;
      v.actPose = null;
      v.prop = PropKind.none;
      // Koro rolleri müzik/dansı Act ile aynı ömürde taşır. Sahne kapanınca
      // aktiviteyi de bırak; aksi hâlde ceremony çözülse bile köylü yeni karar
      // alamadan eski kutlamada takılı kalır.
      if (v.activity == VillagerActivity.music ||
          v.activity == VillagerActivity.dance) {
        v.activity = VillagerActivity.none;
        v.chatBubbleTime = 0;
        v.chatBubbleIcon = '';
      }
      v.imperialAttacking = false;
      v.imperialHit = false;
      if (v.mind.intent.kind == IntentKind.ceremony) v.mind.clear();
    }
    // Ceremony niyetini bu kütüphanede yalnız vinyet rolleri dayatır. Kadro
    // büyürken bir rol listeden düşse bile köylü ömür boyu törende kalmasın:
    // kapanış, canlı köydeki sahipsiz ceremony artıklarını da süpürür.
    for (final v in _villagers) {
      if (v.mind.intent.kind != IntentKind.ceremony) continue;
      v.act = null;
      v.actPose = null;
      v.prop = PropKind.none;
      v.activity = VillagerActivity.none;
      v.mind.clear();
    }
    _vignette = null;
    kProbeVignetteId = '';
    kProbeVignetteCast = 0;
    // Kamera sahneye kilitliyse bırak — izlenecek bir şey kalmadı.
    if (_watchLeft > 0) _watchLeft = 0;
    if (resetDirector) _eventSceneDirector.reset();
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
    // Olayı uzaktan minik yürüyen noktalar olarak değil, beden dili okunacak
    // kadar yakından göster; oyuncu zaten daha yakınsa kendi zoom'u korunur.
    final readable = _viewSize.shortestSide < 500 ? 1.38 : 1.28;
    if (_zoom < readable) _zoom = readable;
    // Sahne bitene kadar bak; en az 3 sn (son saniyesinde basılsa bile kayış
    // tamamlansın), en çok sahnenin kalan ömrü.
    _watchLeft = vg.life.clamp(3.0, _kVignetteLife);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // KADRO + ROL DAĞITIMI
  // ══════════════════════════════════════════════════════════════════════════

  /// Sahneyi açar — sonraki [_role] çağrıları bu sahneye yazılır.
  /// [gx],[gy] kamera odağı: "İzle"ye basınca kadraja gelecek nokta.
  // ignore: unused_element — retained event-package staging hook.
  void _openVignette(
    String eventId,
    String title,
    double gx,
    double gy, {
    EventScenePlan? plan,
    Map<String, VoidCallback> onBeatEnter = const {},
    bool ownsChorus = false,
  }) {
    final resolved =
        plan ?? EventScenePlan.standard(eventId: eventId, title: title);
    _vignette = Vignette(
      eventId: eventId,
      title: title,
      gx: gx,
      gy: gy,
      life: _kVignetteLife,
      sceneKey: resolved.key,
      onBeatEnter: onBeatEnter,
      ownsChorus: ownsChorus,
    );
    _handleEventSceneSignals(
      _eventSceneDirector.start(
        resolved,
        policy: EventSceneStartPolicy.replace,
      ),
    );
  }

  /// Bir role oyuncu bulur, adımları giydirir ve sahneye yazar.
  ///
  /// [near] rolün başlaması gereken yer (oraya en yakın uygun köylü seçilir),
  /// [reason] köylü panelinde görünecek birinci ağız sebep — boş bırakılamaz.
  /// Uygun kimse yoksa `null` döner ve koreografi o rolsüz devam eder: sahne
  /// eksik oynanır ama ASLA yarım kilitlenmez.
  // ignore: unused_element — retained event-package staging hook.
  VillagerEntity? _role(
    String label,
    String reason,
    double nearX,
    double nearY,
    List<ActStep> steps, {
    NpcEmotion emotion = NpcEmotion.none,
    double emotionDur = 8.0,
    bool Function(VillagerEntity)? prefer,
    double radius = _kCastRadius,
  }) {
    final vg = _vignette;
    if (vg == null || steps.isEmpty) return null;
    final v = _castNear(nearX, nearY, prefer: prefer, radius: radius);
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
    // Suçüstü yakalama gibi bazı sahneler muhafızı yeniden `goTo` çağırmadan
    // doğrudan role sokar. Taşıma zincirini burada kapatmazsak kaynak görünmez,
    // teslim slotu da rezerve kalır.
    v.cancelCarryTask();
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
    v.waveTime = 0; // yarım kalan selam sahnenin ortasında sallanmasın
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
  ///
  /// [radius] daraltılabilir: zamana karşı oynayan bir sahnede (heyet eşikte
  /// bekliyor) 26 tile öteden çağrılan adam kadraja YETİŞEMEZ — geç gelen rol
  /// sahneyi kurmaz, bozar.
  VillagerEntity? _castNear(
    double nearX,
    double nearY, {
    bool Function(VillagerEntity)? prefer,
    double radius = _kCastRadius,
  }) =>
      _bestCast(nearX, nearY, prefer, strict: true, radius: radius) ??
      _bestCast(nearX, nearY, prefer, strict: false, radius: radius);

  VillagerEntity? _bestCast(
    double nearX,
    double nearY,
    bool Function(VillagerEntity)? prefer, {
    required bool strict,
    double radius = _kCastRadius,
  }) {
    final vg = _vignette;
    VillagerEntity? best;
    double bestScore = double.infinity;
    for (final v in _villagers) {
      if (vg != null && vg.cast.contains(v)) continue;
      if (!(strict ? _vignetteFree(v) : _vignetteInterruptible(v))) continue;
      final d = _wdist(v.gridX, v.gridY, nearX, nearY);
      if (d > radius) continue;
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
    if (v.isCarrying) return false; // yükünü ortada bırakmaz
    if (v.sickDays > 0 || v.injuryDays > 0 || v.laborDays > 0) return false;
    if (v.isChild) return false; // çocuk rolleri _kidRole'ün
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
  // ignore: unused_element — retained event-package staging hook.
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
  // Yeni olay koreografileri bağımsız paketler olarak buraya bağlanır.

  /// EŞİK — heyet püskürtüldü. Köy heyetle kendi meydanı ARASINA dizilir.
  ///
  /// Bu sahnenin bir borcu var: kronik yıllardır "tırpanla, baltayla eşiğe
  /// dizildi" yazıyordu ama ekranda dizilen kimse yoktu. Direnişin KAYBI
  /// sahneleniyordu (askerler merkeze dalar, kurbanlar düşer), KAZANCI ise bir
  /// bildirim satırıyla geçiştiriliyordu — oyunun en gururlu ânı görünmezdi.
  ///
  /// Cümlesi: *aramızdan geçemezsiniz*. Bu yüzden koreografi tek şey yapar —
  /// hat kurulur ve DURUR. Kimse ileri atılmaz: saldırı değil, set.
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

  /// Saf yönetmendeki plan kimliği (`eventId:variant`).
  final String sceneKey;

  /// O an çalışan beat. UI/prova ve olay paketlerinin gözlem yüzeyi.
  String beatId = '';

  /// Olay dosyasının yalnız kendi beat'lerinde çalıştırdığı dünya kancaları.
  final Map<String, VoidCallback> onBeatEnter;

  /// true olduğunda olay paketi kalabalık/başrol koreografisinin tamamını
  /// üstlenmiştir; scene_events eski generic rally/celebration'ı bindirmez.
  final bool ownsChorus;

  Vignette({
    required this.eventId,
    required this.title,
    required this.gx,
    required this.gy,
    required this.life,
    required this.sceneKey,
    this.onBeatEnter = const {},
    this.ownsChorus = false,
  });
}
