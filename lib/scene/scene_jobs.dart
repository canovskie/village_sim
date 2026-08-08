part of '../main.dart';

/// İŞ ATAMA + YÜRÜTME — anonim işçi avatarlarının (BuilderEntity/FarmFarmer/…)
/// yerini alan sistem. Bina-doğumlu işleri artık GERÇEK köylüler yapar; her
/// görünen NPC tam [VillagerEntity]'dir (ad/kişilik/öykü) ve tıklanır.
///
/// İki katman:
///   • [_syncJobWorkforce] (throttle ~2 sn): her iş kaynağı için hedef kadroyu
///     hesaplar, boş uygun yetişkinleri işe atar / fazlayı bırakır. İş gücü
///     NÜFUSLA sınırlı — hayalet işçi yok; boş kimse yoksa iş bekler + uyarı.
///   • [_tickJobs] (her frame): atanmış köylülerin iş state-machine'ini sürer.
///     KRİTİK: köylüyü PUPPET ETMEZ — yalnız `v.goTo(hedef)` verir, hareketi
///     köylünün kendi `update()`'i yürütür (iki gövde-sürücüsü çakışması olmaz).
///     Aksiyon (inşa/hasat) sayacı/animasyonu burada per-frame ilerler.
extension _SceneJobs on _VillageSceneState {
  static const double _kJobSyncInterval = 2.0;

  /// Bir köylü YENİ bir işe atanmaya uygun mu — boş, yetişkin, meşgul değil.
  /// OYUNCU ELLE ATADIYSA havuz dışıdır ([VillagerEntity.assignedRole]): otomatik
  /// kadro onu ne kapar ne de başka role çeker.
  bool _freeForJob(VillagerEntity v) =>
      v.assignedRole == null &&
      // HANE ELİNİ ÇEKTİ — küskün hanenin üyesi otomatik kadroya girmez
      // (bkz. scene_house_stance). Kadro açığı bir HATA değil, bir SONUÇ:
      // köy o hane ile arasını düzeltene kadar o eller boş kalır.
      !_houseWithholdsLabor(v) &&
      !v.hasActiveJob &&
      v.jobReassignCd <= 0 &&
      v.canRunErrands &&
      !v.isDying &&
      !v.isInsideBuilding &&
      !v.isSleeping &&
      !v.isCarrying &&
      !v.sitClaimed &&
      v.mind.intent.priority <
          IntentPriority.ceremony && // sahnedekine iş verme
      v.activity == VillagerActivity.none;

  /// Atanmış bir köylünün iş state-machine'i BU FRAME çalışmalı mı — uyku/taşıma/
  /// oturma/ölüm/sosyal aktivite işi askıya alır (köylü onu bitirince iş devam
  /// eder; claim korunur). Bu koşullarda `goTo` verilmez.
  bool _jobActiveNow(VillagerEntity v) =>
      v.hasActiveJob &&
      !v.isDying &&
      !v.isInsideBuilding &&
      !v.isSleeping &&
      !v.isCarrying &&
      !v.sitClaimed &&
      // Dayatılmış sahne (olay vinyeti, tören) işi ASKIYA alır — tıpkı oturmak
      // gibi. Bu kapı olmadan iş döngüsü her frame `goTo` verip koreografiyi
      // ezerdi: `activity` ceremony altında none kalır, filtre onu yakalamaz.
      // Claim korunur; sahne bitince iş kaldığı yerden sürer.
      v.mind.intent.priority < IntentPriority.ceremony &&
      v.activity == VillagerActivity.none &&
      // GECE PAYDOSU + KÖYÜN HÂLİ PAYDOSU.
      //
      // Bu iki kapı `scene_work`te (tezgâh/post işleri) VARDI, burada YOKTU —
      // iki iş sistemi geceye dair farklı şey söylüyordu. Sonucu ölçtüm:
      // tarla/maden/balta işi karanlıkta sürüyor, iş döngüsünün her karedeki
      // `goTo`su köylüyü `walkingToSleep`ten koparıyor ve `_wasSleeping` tek
      // atışlık kilit olduğu için o köylü SABAHA KADAR yatağa dönemiyordu.
      // Derin gecede 15-18 kişilik köyde uyuyan 0-7 arasındaydı; baskın niyet
      // saat 03:00'te "İşinde"ydi.
      //
      // Eşik ve muafiyet scene_work ile birebir aynı: karanlık = dayLight
      // 0.35 altı, nöbetçi muaf (muhafız geceyi zaten devriyede geçirir).
      (_cycle.dayLight > 0.35 || v.nightDuty) &&
      v.workPause <= 0 &&
      !identical(v, _draggedVillager);

  /// Bu rolü ÜSTLENMİŞ köylü sayısı — HUD/panel sayaçlarının tek kaynağı.
  /// (Eski anonim işçi listeleri kaldırıldı; onlar hep boştu, sayaçlar da 0.)
  int _jobCount(JobRole role) =>
      _villagers.where((v) => v.job?.role == role).length;

  // ── ATAMA (throttle) ────────────────────────────────────────────────────────

  void _syncJobWorkforce(double dt) {
    if (_jobBlockWarnCd > 0) _jobBlockWarnCd -= dt;
    _jobSyncCd -= dt;
    if (_jobSyncCd > 0) return;
    _jobSyncCd = _kJobSyncInterval;

    // Oyuncunun eli önce — aksi halde `_reconcileRole` hedefi otomatik doldurur,
    // hemen ardından elle atama gelir ve tarlada iki çiftçi belirir.
    _applyPlayerAssignments();

    // BUILDER: bekleyen bina/yol siparişi varsa kadro; yoksa 0. Bina, KADROSU
    // TAM olmadan yükselmediği için hedef el sayısı sipariş sayısı değil
    // siparişlerin istediği el toplamıdır.
    var wantedHands = 0;
    for (final o in _orders) {
      if (!o.completed) wantedHands += o.requiredWorkers;
    }
    for (final o in _roadOrders) {
      if (!o.completed) wantedHands++;
    }
    final builderTarget = wantedHands.clamp(0, kMaxBuilders);
    final firstOrder = _orders.where((o) => !o.completed).firstOrNull;
    _reconcileRole(
      JobRole.builder,
      builderTarget,
      matchType: null,
      near: firstOrder != null
          ? (firstOrder.col + 0.5, firstOrder.row + 0.5)
          : null,
      blockMsg: '🔨 İnşa edilecek yer var ama boş usta yok.',
    );

    // FARMER: tarla ihtiyacı + emek arzı (mevcut _farmWorkforceTarget). Kış:
    // tarla donuk → kadro 0 (çiftçi kış molasına köye karışır).
    final farmerTarget = _season.isFrozen ? 0 : _farmWorkforceTarget();
    if (_farmTiles.isNotEmpty && farmerTarget == 0 && !_season.isFrozen) {
      // Tarla var ama işleyecek el yok (nüfus/uygunluk) → nazik dürtme.
      if (_jobBlockWarnCd <= 0) {
        _jobBlockWarnCd = 60.0;
        _showNotification(
          '🌾 Tarla var ama işleyen yok — bir köylü çiftçi '
          'olmalı ya da Ekin Seferberliği fermanı çıkmalı.',
        );
      }
    }
    _reconcileRole(
      JobRole.farmer,
      farmerTarget,
      matchType: VillagerType.farmer,
      near: _farmTiles.isNotEmpty
          ? (_farmTiles.first.col + 0.5, _farmTiles.first.row + 0.5)
          : null,
      blockMsg: '🌾 Tarla var ama işleyen boş köylü yok.',
    );

    // MADENCİ / BALIKÇI / ÇİÇEKÇİ — bina başına 1 (kaynak varken); işyerine
    // en yakın boş köylü atanır.
    (double, double)? nearBuilding(BuildingType t) {
      final b = _buildings.where((x) => x.type == t).firstOrNull;
      if (b == null) return null;
      final m = kBuildingMeta[t]!;
      return (b.col + m.cols / 2.0, b.row + m.rows / 2.0);
    }

    final mines = _buildings
        .where((b) => b.type == BuildingType.mineBuilding)
        .length;
    final cabins = _buildings
        .where((b) => b.type == BuildingType.fisherCabin)
        .length;
    final cottages = _buildings
        .where((b) => b.type == BuildingType.floristCottage)
        .length;
    _reconcileRole(
      JobRole.miner,
      mines,
      matchType: VillagerType.miner,
      near: nearBuilding(BuildingType.mineBuilding),
      blockMsg: '⛏️ Maden hazır ama çıkaracak boş köylü yok.',
    );
    _reconcileRole(
      JobRole.fisher,
      cabins,
      matchType: VillagerType.fisher,
      near: nearBuilding(BuildingType.fisherCabin),
      blockMsg: '🎣 İskele boş — balığa çıkacak kimse yok.',
    );
    _reconcileRole(
      JobRole.florist,
      cottages,
      matchType: null,
      near: nearBuilding(BuildingType.floristCottage),
      blockMsg: '🌸 Çiçekçi kulübesi boş.',
    );

    // ÇOBAN — ağıl başına 1 (sağım + sürü). Tek çoban hem güder hem sağar
    // (eski anonim ShepherdEntity mükerrerliği kalktı).
    final barns = _buildings.where((b) => b.type == BuildingType.barn).length;
    _reconcileRole(
      JobRole.shepherd,
      barns,
      matchType: VillagerType.shepherd,
      near: nearBuilding(BuildingType.barn),
      blockMsg: '🐄 Ağıl var ama çoban yok.',
    );

    // ODUNCU — kereste kampı başına 1 (kesim). Bölge yönetimi (işaretleme+
    // fidan) ayrı per-kamp yürür (_tickLumberCampManage).
    final camps = _buildings
        .where((b) => b.type == BuildingType.lumberCamp)
        .length;
    _reconcileRole(
      JobRole.woodcutter,
      camps,
      matchType: null,
      near: nearBuilding(BuildingType.lumberCamp),
      blockMsg: '🪓 Kereste kampı var ama oduncu yok.',
    );

    // TOPLAYICI / AŞÇI — KÖY KENDİ AÇLIĞINA BAKAR.
    //
    // Bu iki hedef uzun süre 0'dı: erken oyunun tek amacı oyuncunun "kim ne
    // yapsın" kararını vermesiydi, o yüzden köy kendiliğinden ne toplayıcı ne
    // aşçı atıyordu. Oyundaki karşılığı karar değil MİKRO KONTROL oldu —
    // oyuncu tek tek köylüye böğürtlen atıyor, atamazsa kimse yemek yapmıyordu.
    // Bir karar tek seferliktir; bu her seferlikti.
    //
    // Elle atananlar bu hedeflerden MUAF (bkz. `assignedRole`): oyuncu üç kişiyi
    // sepete koyduysa otomatik kadro onları geri almaz. Oyuncunun eli üstüne
    // yazar, yerine geçmez.
    _reconcileRole(
      JobRole.forager,
      _foragerTarget(),
      matchType: null,
      near: _nearestSpot([
        for (final b in _berryBushes) (b.col + 0.5, b.row + 0.5),
      ]),
      blockMsg: '',
    );
    _reconcileRole(
      JobRole.cook,
      _cookTarget(),
      matchType: null,
      near: nearBuilding(BuildingType.firepit),
      blockMsg: '',
    );

    // DOKUMACI — KIŞIN İŞİ. Tarla donunca çiftçi kadrosu boşa düşüyordu:
    // köyün yarısı kış boyunca ortalıkta dolanıyor, mevsim "ölü zaman" gibi
    // geçiyordu. Kışın ve yün varken köy kendiliğinden tezgâha oturur.
    //
    // Hedef sayı yünle sınırlı: iki tezgâh bir kışlık için yeter, üç dokumacı
    // yünü bir günde bitirip yine boş kalırdı. Elle atananlar bu hedeften
    // muaf (bkz. `assignedRole`) — oyuncunun kararı her mevsim geçerli.
    // SONBAHAR DA DAHİL: kışlık giysi kışın değil KIŞ GELMEDEN dokunur.
    // Yalnız kışa bağlıyken hazırlık kartı sonbahar boyunca "kışlık eksik"
    // diyor ama oyuncunun yapabileceği hiçbir şey olmuyordu — uyarı değil
    // sitem. Kırkım sonbaharda, tezgâh da sonbaharda başlar; kışın süren
    // dokuma yalnız açığı kapatır.
    final weaveSeason = _season == Season.autumn || _season == Season.winter;
    // Eşik BİR GİYSİLİK yün: "6 yün birikince başla" dediğimizde tezgâh
    // sonbaharın yarısını bekleyerek geçiriyordu (kırkım damla damla gelir).
    final wantWeavers = weaveSeason && _stockpile.wool >= 3
        ? (_stockpile.wool ~/ 9).clamp(1, 2)
        : 0;
    _reconcileRole(
      JobRole.weaver,
      wantWeavers,
      matchType: null,
      blockMsg: '',
    );
  }

  /// Kaç el sepete gitsin — İHTİYAÇ KADAR, sessizce.
  ///
  /// Sofra dolduğunda 0'a iner: köy gereksiz yere çalı yolmaz, çalılar da
  /// yenilenmeye vakit bulur (bkz. [kBerryRegrowSeconds]). Kışın 0 — çalı
  /// meyve vermez, oraya el yollamak köylüyü boşuna yürütmek olurdu.
  int _foragerTarget() {
    if (_berryBushes.isEmpty || _season.isFrozen) return 0;
    final mouths = _villagers.length;
    if (mouths == 0) return 0;
    final perMouth = (_stockpile.food + _cookedMeals) / mouths;
    if (perMouth >= kForageComfort) return 0;
    if (perMouth >= kForageLow) return 1;
    // Aç köyde her üç ağıza bir sepet — nüfusun yarısını çalıya sürmez.
    return (mouths / 3).ceil().clamp(1, kMaxForagers);
  }

  /// Ocağın başında kaç el — ateş yanıyorsa, pişirecek ham yiyecek varsa ve
  /// sofra tavanı dolmadıysa. Tavan dolunca aşçı zaten boş dururdu; hedefi
  /// düşürüp köye karışması daha doğru.
  int _cookTarget() {
    if (_firepitBuilding == null) return 0;
    if (_stockpile.food < kCookFoodCost) return 0;
    if (_cookedMeals >= _mealCap) return 0;
    return _villagers.length >= kSecondCookPop ? 2 : 1;
  }

  // ── KERESTE KAMPI BÖLGE YÖNETİMİ ────────────────────────────────────────────
  // Eski LumberCampEntity._manageTrees'in bina-bazlı hali: her kampın çevresinde
  // büyümüş ağaçları kesime işaretler + bölge seyreldiyse fidan diker. Kesim
  // işini oduncu köylü ([_runWoodcutter]) yapar.
  void _tickLumberCampManage(double dt) {
    _lumberManageCd -= dt;
    if (_lumberManageCd > 0) return;
    _lumberManageCd =
        kLumberManageMinInterval +
        _rng.nextDouble() *
            (kLumberManageMaxInterval - kLumberManageMinInterval);
    final forbidden = _forbiddenForTrees;
    for (final b in _buildings) {
      if (b.type != BuildingType.lumberCamp) continue;
      final cx = b.col + 1.0, cy = b.row + 1.0;
      const r2 = kLumberTerritoryRadius * kLumberTerritoryRadius;
      final inZone = <TreeEntity>[];
      for (final t in _trees) {
        if (t.isFelled) continue;
        final dx = t.col + 0.5 - cx, dy = t.row + 0.5 - cy;
        if (dx * dx + dy * dy <= r2) inZone.add(t);
      }
      final grown = inZone.where((t) => !t.isGrowing).toList();
      int marked = grown.where((t) => t.isMarkedForCutting).length;
      for (final t in grown) {
        if (marked >= kLumberMaxMarked) break;
        if (!t.isMarkedForCutting && !t.isBeingChopped) {
          t.isMarkedForCutting = true;
          marked++;
        }
      }
      if (inZone.length < kLumberTargetTrees) {
        _plantLumberSapling(cx, cy, forbidden);
      }
    }
  }

  void _plantLumberSapling(double cx, double cy, Set<(int, int)> forbidden) {
    final occupied = {
      for (final t in _trees)
        if (!t.isFelled) (t.col, t.row),
    };
    for (int attempt = 0; attempt < 25; attempt++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final dist = 1.5 + _rng.nextDouble() * (kLumberTerritoryRadius - 1.0);
      final col = (cx + cos(angle) * dist).round();
      final row = (cy + sin(angle) * dist).round();
      if (col < 1 || row < 1 || col >= kCols - 1 || row >= kRows - 1) continue;
      if (occupied.contains((col, row))) continue;
      if (_waterTiles.contains((col, row))) continue;
      if (forbidden.contains((col, row))) continue;
      _trees.add(
        TreeEntity(col: col, row: row, type: TreeType.pine, isGrowing: true),
      );
      return;
    }
  }

  // ── ODUNCU ──────────────────────────────────────────────────────────────────
  // İşaretli en yakın ağaca yürü → kes (kChopDuration) → odun kütüğü. claim = ağaç.
  void _runWoodcutter(VillagerEntity v, double dt) {
    final job = v.job!;
    var tree = job.claim is TreeEntity ? job.claim as TreeEntity : null;
    if (tree != null && tree.isFelled) {
      tree.isBeingChopped = false;
      tree.chopPhase = -1;
      job.claim = null;
      tree = null;
    }
    if (tree == null) {
      job.working = false;
      TreeEntity? best;
      double bestD = double.infinity;
      for (final t in _trees) {
        if (!t.isMarkedForCutting ||
            t.isBeingChopped ||
            t.isFelled ||
            t.isGrowing) {
          continue;
        }
        final dx = t.col + 0.5 - v.gridX, dy = t.row + 0.5 - v.gridY;
        final d = dx * dx + dy * dy;
        if (d < bestD) {
          bestD = d;
          best = t;
        }
      }
      if (best == null) return;
      best.isBeingChopped = true;
      job.claim = best;
      tree = best;
      job.phase = 0;
    }
    final tx = tree.col + 0.5, ty = tree.row + 0.5;
    if (job.phase == 0) {
      final dx = v.gridX - tx, dy = v.gridY - ty;
      if (dx * dx + dy * dy <= 1.1 * 1.1) {
        v.state = VillagerState.idle;
        v.facingRight = tx > v.gridX;
        job.phase = 1;
        job.timer = 0;
        job.phaseAnim = 0;
      } else if (!_enRouteTo(v, tx, ty)) {
        v.goTo(tx, ty, 0.2);
      }
      return;
    }
    job.working = true;
    v.idleTimer = 0.5;
    job.timer += dt;
    job.phaseAnim = (job.phaseAnim + dt * 2 * pi * 1.1) % (2 * pi);
    tree.chopPhase = job.phaseAnim;
    if (job.timer >= kChopDuration) {
      final hc = tree.col, hr = tree.row;
      // İzometrik ekran x'i (gridX-gridY) eksenidir. Ağaç oduncunun ekran
      // tarafının tersine düşer; böylece gövde işçinin üstüne kapanmaz.
      final workerScreenDelta =
          (v.gridX - v.gridY) - ((tree.col + 0.5) - (tree.row + 0.5));
      tree.beginFall(awayFromScreenDelta: -workerScreenDelta);
      job.claim = null;
      job.phase = 0;
      job.working = false;
      job.phaseAnim = 0;
      final box = ResourceBox(
        type: ResourceBoxType.woodChunk,
        gridX: hc.toDouble(),
        gridY: hr.toDouble(),
      );
      ResourcePlacement.placeBox(
        box,
        hc.toDouble(),
        hr.toDouble(),
        _resourceBoxes,
        _time,
      );
      _resourceBoxes.add(box);
    }
  }

  // ── OYUNCUNUN ELİ ───────────────────────────────────────────────────────────
  // Erken oyunun omurgası: köyün kimin ne yaptığına oyuncu karar verir. Otomatik
  // kadro (`_reconcileRole`) yalnız GERİ KALANI dağıtır — elle atanmış köylüyü
  // ne kapar ne bırakır (bkz. `_freeForJob` + aşağıdaki release kapısı).

  /// Elle verilmiş işleri köylülerin üstüne geçir. `assignedRole == JobRole.none`
  /// "boş dursun" demektir: köylü işten alınır ve otomatik havuza da dönmez.
  void _applyPlayerAssignments() {
    for (final v in _villagers) {
      final want = v.assignedRole;
      if (want == null) continue;
      final cur = v.job?.role ?? JobRole.none;
      if (cur == want) continue;
      // Hasta/yaralı/çocuk köylüye iş GEÇİRİLMEZ ama kararı SİLİNMEZ: iyileşince
      // kendi işine döner. (Kararı burada sıfırlasaydık oyuncu bir hastalıktan
      // sonra kurduğu iş bölümünü sessizce kaybederdi.)
      if (!v.canRunErrands || v.isDying) continue;
      // Hane elini çekmişse oyuncunun kararı da SAKLANIR ama uygulanmaz —
      // hastalık deseniyle birebir aynı. Bu kapı olmadan iki döngü çakışırdı:
      // `_applyPlayerAssignments` (2 sn) işi geri verir, `_dropWithheldJobs`
      // (4 sn) alırdı; köylü sürekli işe girip çıkar, sahne titrerdi.
      if (_houseWithholdsLabor(v)) continue;
      if (v.job != null) _releaseJob(v); // eski claim'ler salıverilsin
      if (want != JobRole.none) v.job = VillagerJob(want);
    }
  }

  /// Oyuncu bir köylüye iş verdi/aldı — atamanın tek giriş kapısı.
  /// [role] `null` ise köylü otomatik iş gücüne GERİ DÖNER (kilit kalkar);
  /// [JobRole.none] ise elle boşa alınır (otomatik de dokunmaz).
  ///
  /// UI bunu artık DOĞRUDAN çağırmaz — oyuncunun yüzeyi iş yeri yuvalarıdır
  /// (bkz. `_fillSlot` / `_emptySlot`). Burası o yüzeyin altındaki ilkel işlem
  /// olarak kaldı; öğretici, dev konsolu ve senaryolar buradan geçer.
  void _assignVillagerJob(VillagerEntity v, JobRole? role) {
    // Hane esirgiyorsa oyuncunun eli de geçmez — reddin sesi vardır. Bu kapı
    // olmasaydı sistem defolu olurdu: oyuncu grevdeki herkesi elle atayıp
    // esirgemeyi tümüyle etkisizleştirebilirdi.
    if (role != null && _refuseAssignment(v, role)) return;
    v.assignedRole = role;
    // Kilit kalkıyorsa YER mührü de düşer — yoksa köylü otomatik havuza döner
    // ama panelde hâlâ o ocağın yuvasında görünürdü.
    if (role == null || role == JobRole.none) v.assignedSiteId = null;
    // Kilit kalkarken elindeki işi de bırak: aksi halde köylü "otomatik havuzda"
    // görünür ama hâlâ eski rolde çalışır, sonraki sync'e kadar sayaçlar yalan söyler.
    if (role == null) {
      if (v.job != null) _releaseJob(v);
    } else {
      _applyPlayerAssignments();
      // Âdete aykırıysa köy duysun — engellemez, yalnız tepki verir
      // (bkz. scene_custom + systems/village_custom).
      if (role != JobRole.none &&
          VillageCustom.isAgainst(role, male: v.isMale)) {
        _reactToCustomBreach(v, role);
      }
    }
    _jobSyncCd = 0; // kadro dengesi bu tick yeniden kurulsun
  }

  /// [role] için atanmış köylü sayısını [target]'a yaklaştır. Az ise boş uygun
  /// yetişkin ata ([matchType] varsa o mesleği tercih et — çoban/çiftçi/madenci
  /// gibi baz-meslek eşleşmesi), fazla ise bırak (önce çalışmayanı). Kadro
  /// kurulamadıysa (target>0 ama boş kimse yok) nazik uyarı.
  void _reconcileRole(
    JobRole role,
    int target, {
    VillagerType? matchType,
    (double, double)? near,
    required String blockMsg,
  }) {
    final assigned = _villagers.where((v) => v.job?.role == role).toList();

    if (assigned.length < target) {
      var need = target - assigned.length;
      // Aday havuzu: boş uygun yetişkinler. Önce baz-meslek eşleşmesi, sonra
      // İŞYERİNE YAKINLIK (uzak köylü atanıp path-aware erişemeyip takılmasın —
      // en yakın köylü işi alır, hedef ulaşılabilir olur).
      double d2(VillagerEntity v) {
        if (near == null) return 0;
        final dx = v.gridX - near.$1, dy = v.gridY - near.$2;
        return dx * dx + dy * dy;
      }

      final pool = _villagers.where(_freeForJob).toList()
        ..sort((a, b) {
          if (matchType != null) {
            final am = a.type == matchType ? 0 : 1;
            final bm = b.type == matchType ? 0 : 1;
            if (am != bm) return am - bm;
          }
          return d2(a).compareTo(d2(b));
        });
      for (final v in pool) {
        if (need <= 0) break;
        v.job = VillagerJob(role);
        need--;
      }
      // Hâlâ eksikse (nüfus yetmedi) nazik uyar — spam'siz. Boş [blockMsg]
      // "bu rolün uyarısı yok" demek: sessiz roller (toplayıcı/aşçı/dokumacı)
      // köyün kendi refleksi, oyuncunun yapabileceği bir şey yok — o kapı
      // kapalıyken boş bir bildirim düşerdi.
      if (need > 0 && target > 0 && blockMsg.isNotEmpty && _jobBlockWarnCd <= 0) {
        _jobBlockWarnCd = 60.0;
        _showNotification(blockMsg);
      }
    } else if (assigned.length > target) {
      var extra = assigned.length - target;
      // Önce boşta/çalışmayanları bırak (yarım iş kesilmesin).
      assigned.sort((a, b) {
        final aw = (a.job?.working ?? false) ? 1 : 0;
        final bw = (b.job?.working ?? false) ? 1 : 0;
        return aw - bw; // çalışmayan (0) önce
      });
      for (final v in assigned) {
        if (extra <= 0) break;
        // Elle atanmışa DOKUNMA — oyuncu tek kereste kampına üç oduncu koyduysa
        // bu bir hata değil, bir karar. Fazlalık sayısı hedefin üstünde kalır.
        if (v.assignedRole != null) continue;
        _releaseJob(v);
        extra--;
      }
    }
  }

  /// Bina yakınında BU rolde çalışan (working) atanmış köylü var mı — bina
  /// "aktif" panel durumu için (eski worker.state kontrolünün yerini alır).
  bool _jobWorkerActiveNear(
    JobRole role,
    BuildingEntity b, {
    double radius = 5.0,
  }) {
    final cx = b.col + b.cols / 2.0, cy = b.row + b.rows / 2.0;
    final r2 = radius * radius;
    for (final v in _villagers) {
      if (v.job?.role != role || !(v.job?.working ?? false)) continue;
      final dx = v.gridX - cx, dy = v.gridY - cy;
      if (dx * dx + dy * dy <= r2) return true;
    }
    return false;
  }

  /// Köylüyü işten al — tuttuğu claim'leri SALIVER (yoksa sipariş "atandı"da
  /// asılı kalır), sonra işi temizle.
  void _releaseJob(VillagerEntity v) {
    final job = v.job;
    if (job == null) return;
    switch (job.role) {
      case JobRole.builder:
        if (job.claim is BuildOrder) {
          final o = job.claim as BuildOrder;
          if (o.crew > 0) o.crew--;
        }
        if (job.claim is RoadOrder) (job.claim as RoadOrder).assigned = false;
      case JobRole.farmer:
        // Tuttuğu tile bayraklarını + kuyu slot'unu bırak (yoksa tarla
        // "biçiliyor/ekiliyor"da ya da kuyu slot'u dolu asılı kalır).
        if (job.claim is FarmTile) {
          (job.claim as FarmTile).beingHarvested = false;
          (job.claim as FarmTile).beingSown = false;
        }
        if (job.claim3 is AnchorPoint && job.claim2 is AnchorSlot) {
          (job.claim3 as AnchorPoint).release(job.claim2 as AnchorSlot, v);
        }
      case JobRole.miner:
        if (job.claim is MineNode) {
          (job.claim as MineNode).isBeingMined = false;
          (job.claim as MineNode).chopPhase = -1;
        }
      case JobRole.shepherd:
        if (job.claim is AnimalEntity) {
          (job.claim as AnimalEntity).isBeingMilked = false;
        }
      case JobRole.woodcutter:
        if (job.claim is TreeEntity) {
          (job.claim as TreeEntity).isBeingChopped = false;
          (job.claim as TreeEntity).chopPhase = -1;
        }
      case JobRole.forager:
        // Üstlendiği çalıyı SALIVER — yoksa o çalı kimsenin toplayamadığı
        // sessiz bir ölü nokta olarak kalır.
        if (job.claim is BerryBush) {
          (job.claim as BerryBush).isBeingPicked = false;
        }
      default:
        break;
    }
    v.job = null;
    _setWorkPose(v, null); // işi bıraktı — iş duruşu/aleti de düşer
  }

  // ── YÜRÜTME (her frame) ─────────────────────────────────────────────────────

  void _tickJobs(
    double dt,
    Set<(int, int)> obstacles,
    Set<(int, int)> softObs,
  ) {
    final buildDt = dt * _fxBuilderMul;
    // Şantiyede o an kaç el var — bu karede yeniden sayılır, kadro şartı
    // (bkz. _runBuilder) bir önceki karenin sayısını okur. Kadro eksik kaldıkça
    // sabır dolar; dolunca eldeki el tek başına başlar.
    for (final o in _orders) {
      o.workersAtSite = o.arrivals;
      o.arrivals = 0;
      if (o.crew < o.requiredWorkers) {
        o.waited += dt;
      } else {
        o.waited = 0;
      }
    }
    for (final v in _villagers) {
      if (v.jobReassignCd > 0) v.jobReassignCd -= dt;
      if (!v.hasActiveJob) continue;
      if (!_jobActiveNow(v)) {
        _setWorkPose(v, null); // paydos/gece/duraklama — iş duruşunu bırak
        continue;
      }
      final job = v.job!;
      // ÂDET — köyün usulüne aykırı iş AĞIR ilerler (bkz. village_custom).
      // Tek çarpan, tek yer: panelde yazan uyarı ile burada uygulanan yavaşlama
      // aynı `judge()` çağrısından çıkar, iki liste yoktur.
      // Âdet çarpanı × ÜŞÜME cezası. Titreyen el iş görmez: kışın üşümesi
      // dolan köylü yavaşlar (bkz. systems/winter.dart chillWorkPenalty).
      // Eşikli — hafif üşüme kimseyi yavaşlatmaz, yoksa kış boyunca köy
      // sürekli ağır çekim olurdu.
      final cm = VillageCustom.speedMul(job.role, male: v.isMale) *
          chillWorkPenalty(v.mind.drive(Drive.chill));
      switch (job.role) {
        case JobRole.builder:
          _runBuilder(v, buildDt * cm, obstacles);
        case JobRole.farmer:
          _runFarmer(v, dt * _fxFarmMul * cm);
        case JobRole.miner:
          _runMiner(v, dt * _fxNpcSpeedMul * cm);
        case JobRole.fisher:
          // Göl donmuşsa olta atılmaz. Rol listeden zaten düşüyor ama ELLE
          // atanmış balıkçı kışın buz başında bekler kalırdı — iş bu tick
          // boş geçer, köylü köye karışır (rol elinden ALINMAZ).
          if (waterFrozen(_season)) {
            v.job?.working = false;
            break;
          }
          _runFisher(v, dt * _fxNpcSpeedMul * cm);
        case JobRole.florist:
          _runFlorist(v, dt * _fxNpcSpeedMul * cm);
        case JobRole.shepherd:
          _runShepherd(v, dt * _fxNpcSpeedMul * cm);
        case JobRole.woodcutter:
          _runWoodcutter(v, dt * _fxNpcSpeedMul * cm);
        case JobRole.forager:
          _runForager(v, dt * _fxNpcSpeedMul * cm);
        case JobRole.cook:
          _runCook(v, dt * _fxNpcSpeedMul * cm);
        case JobRole.weaver:
          _runWeaver(v, dt * _fxNpcSpeedMul * cm);
        default:
          break;
      }
      // GÖVDE DİLİ — görev başında çalışan köylü ekranda da çalışsın (bkz.
      // _setWorkPose). "Çalışıyor" sinyali rol-bağımsız: bina-işlerinde
      // `job.working`, çiftçide durağan tarla eylemi bayrakları
      // (`harvesting` ekim/biçme, `carryingWater` su taşıma/dökme). Yürürken/
      // hedef ararken bunlar false → duruş temizlenir, köylü doğal yürür.
      final working = job.working || job.harvesting || job.carryingWater;
      if (working) {
        // Eğilerek yapılan işler (ekim/biçme/su) STOOP; ritmik alet işleri
        // (çekiç/kazma/balta/olta) LABOR. Çiftçi su taşırken elinde dolu kova
        // görünür — mevcut prop çizimini yeniden kullanır (yeni sprite yok).
        final (pose, prop) = switch (job.role) {
          JobRole.farmer => (
            ActPose.stoop,
            job.carryingWater ? PropKind.bucketFull : PropKind.none,
          ),
          JobRole.florist => (ActPose.stoop, PropKind.basket),
          // Sağım için çömelir ve YANINDA KOVA olur. `working` bu rolde yalnız
          // sağım evresinde true (sürüyü güderken false), o yüzden kova sahnenin
          // dışına taşmaz. Mevcut kova çizimi kullanılır — yeni sprite yok.
          JobRole.shepherd => (ActPose.stoop, PropKind.bucketFull),
          JobRole.forager => (ActPose.stoop, PropKind.basket), // çalıdan sepete
          JobRole.cook => (ActPose.stoop, PropKind.none), // kazanı karıştırır
          JobRole.weaver => (ActPose.stoop, PropKind.none), // tezgâha eğilir
          _ => (ActPose.labor, PropKind.none), // çekiç/kazma/balta/olta ritmi
        };
        _setWorkPose(v, pose, prop: prop);
      } else {
        _setWorkPose(v, null);
      }
      // Stuck-guard: çalışmıyorken (yürürken) yerinde donarsa (erişilemez
      // hedef → A* path yok → köylü "moving"de sabit) işi bırak, köye karışsın;
      // kısa süre tekrar atanmasın (aksi halde sync onu hemen geri alıp
      // yeniden dondururdu).
      if (v.hasActiveJob && !job.working) {
        final moved = (v.gridX - job.lastX).abs() + (v.gridY - job.lastY).abs();
        if (moved < 0.04) {
          job.stuckTimer += dt;
        } else {
          job.stuckTimer = 0;
        }
        job.lastX = v.gridX;
        job.lastY = v.gridY;
        if (job.stuckTimer > 12.0) {
          _releaseJob(v);
          v.jobReassignCd = 25.0;
          v.state = VillagerState.idle;
          v.idleTimer = 0.4;
        }
      } else if (v.hasActiveJob) {
        job.stuckTimer = 0;
      }
    }
  }

  // ── İNŞAATÇI ────────────────────────────────────────────────────────────────
  // Eski BuilderEntity state-machine'inin KARAR+ETKİ yarısı; hareket köylüde.
  // phase 0 = sipariş kap + site'a yürü, phase 1 = inşa et (per-frame ilerler).

  void _runBuilder(VillagerEntity v, double dt, Set<(int, int)> obstacles) {
    final job = v.job!;
    var bo = job.claim is BuildOrder ? job.claim as BuildOrder : null;
    var ro = job.claim is RoadOrder ? job.claim as RoadOrder : null;

    // Claim geçersizleştiyse (iptal/silme) bırak — ekip sayacı geri düşer.
    if (bo != null && bo.completed) {
      if (bo.crew > 0) bo.crew--;
      job.claim = null;
      bo = null;
    }
    if (ro != null && ro.completed) {
      job.claim = null;
      ro = null;
    }

    // Claim yoksa bir sipariş kap (bina önce — büyük yatırım).
    if (bo == null && ro == null) {
      job.working = false;
      job.progress = 0;
      for (final o in _orders) {
        // Kadrosu dolmamış ilk şantiye — bina, gereken el sayısı başına
        // toplanmadan yükselmez (bkz. BuildOrder.requiredWorkers).
        if (!o.completed && o.crew < o.requiredWorkers) {
          o.crew++;
          job.claim = o;
          bo = o;
          break;
        }
      }
      if (bo == null) {
        for (final o in _roadOrders) {
          if (!o.assigned && !o.completed) {
            o.assigned = true;
            job.claim = o;
            ro = o;
            break;
          }
        }
      }
      if (bo == null && ro == null) return; // iş yok — sync sıradaki turda alır
      job.phase = 0;
      job.timer = 0;
    }

    // Hedef nokta — bina için footprint MERKEZİ (şu an açık zemin; henüz bina
    // yok → yürünebilir; köşe+1 çoğu kez komşu binaya denk gelip A* path'i
    // bulunamıyordu). Yol için tile (köprüde komşu kara). Varış GEVŞEK: site'a
    // yeterince yaklaşınca inşaya başlar (path-aware köylü tam köşeye
    // oturamayabilir).
    final double tx, ty, arrive;
    if (bo != null) {
      final meta = kBuildingMeta[bo.type]!;
      tx = bo.col + meta.cols / 2.0;
      ty = bo.row + meta.rows / 2.0;
      arrive = (meta.cols > meta.rows ? meta.cols : meta.rows) / 2.0 + 1.2;
    } else {
      final r = ro!;
      if (r.surface == RoadSurface.woodBridge) {
        final land = _adjacentLandTile(r.col, r.row, obstacles);
        tx = land.$1;
        ty = land.$2;
      } else {
        tx = r.col + 0.5;
        ty = r.row + 0.5;
      }
      arrive = 1.0;
    }

    if (job.phase == 0) {
      // Site'a yeterince yaklaştıysa inşaya geç.
      final dx = v.gridX - tx, dy = v.gridY - ty;
      if (dx * dx + dy * dy <= arrive * arrive) {
        v.state = VillagerState.idle;
        v.facingRight = tx > v.gridX;
        job.phase = 1;
        job.timer = 0;
        job.working = true;
      } else if (!_enRouteTo(v, tx, ty)) {
        v.goTo(tx, ty, 0.3);
      }
      return;
    }

    // phase 1: inşa — per-frame süre + çekiç salınımı + ilerleme çubuğu.
    v.idleTimer = 0.5; // wander'a düşmesin; yerinde çakılı kalsın

    // BİNA YOL — malzemesiz, tek elle, eski akış.
    if (bo == null) {
      final r = ro!;
      job.working = true;
      job.timer += dt;
      job.phaseAnim = (job.phaseAnim + dt * 4.0) % (pi * 2);
      job.progress = (job.timer / r.surface.buildDuration).clamp(0.0, 1.0);
      if (job.timer >= r.surface.buildDuration) {
        r.completed = true;
        _roadSystem.add(RoadTile(col: r.col, row: r.row, surface: r.surface));
        job.claim = null;
        job.phase = 0;
        job.timer = 0;
        job.working = false;
        job.progress = 0;
      }
      return;
    }

    // BİNA — KADRO ŞARTI: gereken el sayısı şantiyede toplanmadan gövde
    // yükselmez. Gelen ilk usta bekler (çekiç sallamaz), ekip tamamlanınca
    // inşaat eskisi gibi tek hızda aşağıdan yukarı çıkar.
    bo.arrivals++; // bu karede şantiyedeyim (tick başında sayıya devredilir)
    if (!bo.crewReady) {
      job.working = false;
      job.progress = bo.progress;
      v.facingRight = (bo.col + 1.0) > v.gridX;
      return;
    }
    job.working = true;
    job.phaseAnim = (job.phaseAnim + dt * 4.0) % (pi * 2);
    // İlerleme ŞANTİYEDE tutulur ve kare başına BİR kez yazılır — yoksa
    // kadrodaki her el ayrı ayrı ilerletir, bina kişi sayısı kadar hızlı çıkardı.
    if (bo.tickStamp != _time) {
      bo.tickStamp = _time;
      bo.progress = (bo.progress + dt / _buildDurationFor(bo.type)).clamp(
        0.0,
        1.0,
      );
    }
    job.progress = bo.progress;
    if (bo.progress >= 1.0) {
      bo.completed = true;
      AudioManager.instance.playSfx(Sfx.buildDone);
      _buildings.add(BuildingEntity(type: bo.type, col: bo.col, row: bo.row));
      if (bo.crew > 0) bo.crew--;
      job.claim = null;
      job.phase = 0;
      job.timer = 0;
      job.working = false;
      job.progress = 0;
    }
  }

  // ── ÇİFTÇİ ──────────────────────────────────────────────────────────────────
  // Eski FarmFarmer state-machine'inin karar+etki yarısı; hareket köylüde.
  // phase: 0 karar, 1/2 ekim yürü/ek, 3/4 hasat yürü/biç, 5/6 kuyu yürü/su al,
  // 7/8 sulama yürü/sula. Kuyu slot'u claim2, kuyu point'i claim3, tarla claim.
  void _runFarmer(VillagerEntity v, double dt) {
    final job = v.job!;
    job.cooldown -= dt;
    final frozen = _season.isFrozen;
    final irrigate = _policies.irrigation;
    final fallow = _policies.cropRotation ? kFarmFallowDuration : 0.0;

    // Render bayrakları — faz'a göre aşağıda set edilir.
    job.harvesting = false;
    job.carryingWater = false;
    job.splashTimer = -1;

    final target = job.claim is FarmTile ? job.claim as FarmTile : null;

    switch (job.phase) {
      case 0: // karar
        if (frozen) return; // kış molası (sync kadroyu zaten 0'a çeker)
        // Sulama turu — Su Yolu Fermanı + boş kuyu slot'u + büyüyen ekin.
        if (irrigate &&
            job.cooldown <= 0 &&
            _anchorSystem.wellPoints.isNotEmpty &&
            _farmTiles.any((t) => t.isGrowing)) {
          final claim = _anchorSystem.claimNearestWell(v.gridX, v.gridY, v);
          if (claim != null) {
            final dx = claim.$2.col - v.gridX, dy = claim.$2.row - v.gridY;
            if (dx * dx + dy * dy <=
                kFarmWellMaxDistance * kFarmWellMaxDistance) {
              job.cooldown = kFarmWaterCooldown;
              job.claim3 = claim.$1;
              job.claim2 = claim.$2;
              job.phase = 5;
              return;
            } else {
              claim.$1.release(claim.$2, v); // uzak → iade
            }
          }
        }
        // Önce hasat: olgun ekin bekletilmez.
        final best = _nearestFarmTile(
          v,
          (t) => t.readyToHarvest && !t.beingHarvested,
        );
        if (best != null) {
          best.beingHarvested = true;
          job.claim = best;
          job.phase = 3;
          return;
        }
        // Sonra ekim: boş (nadası dolmuş) toprağa tohum.
        final sow = _nearestFarmTile(v, (t) => t.readyToSow);
        if (sow != null) {
          sow.beingSown = true;
          job.claim = sow;
          job.phase = 1;
        }
        return;

      case 1: // ekime yürü
        if (target == null || !target.needsSowing) {
          target?.beingSown = false;
          job.claim = null;
          job.phase = 0;
          return;
        }
        _walkToTileThen(v, target.col + 0.5, target.row + 0.5, () {
          job.phase = 2;
          job.timer = 0;
        });
        return;

      case 2: // ekiyor
        job.harvesting = true;
        v.idleTimer = 0.5;
        job.timer += dt;
        job.phaseAnim = (job.phaseAnim + dt * 2 * pi) % (2 * pi);
        if (job.timer >= kFarmSowDuration) {
          target?.sow();
          job.claim = null;
          job.phase = 0;
          job.phaseAnim = 0;
        }
        return;

      case 3: // hasada yürü
        if (target == null) {
          job.phase = 0;
          return;
        }
        _walkToTileThen(v, target.col + 0.5, target.row + 0.5, () {
          job.phase = 4;
          job.timer = 0;
        });
        return;

      case 4: // biçiyor
        job.harvesting = true;
        v.idleTimer = 0.5;
        job.timer += dt;
        job.phaseAnim = (job.phaseAnim + dt * 2 * pi * 1.4) % (2 * pi);
        if (job.timer >= kFarmHarvestDuration) {
          final hc = target?.col ?? v.gridX.round();
          final hr = target?.row ?? v.gridY.round();
          target?.harvest(fallowSeconds: fallow);
          job.claim = null;
          job.phase = 0;
          job.phaseAnim = 0;
          _spawnFarmHay(hc, hr);
        }
        return;

      case 5: // kuyuya yürü
        job.carryingWater = true;
        final slot = job.claim2 is AnchorSlot ? job.claim2 as AnchorSlot : null;
        if (slot == null) {
          job.phase = 0;
          return;
        }
        _walkToTileThen(v, slot.col, slot.row, () {
          job.phase = 6;
          job.timer2 = 0;
        });
        return;

      case 6: // su alıyor
        job.carryingWater = true;
        v.idleTimer = 0.5;
        job.timer2 += dt;
        job.splashTimer = job.timer2;
        if (job.timer2 >= kFarmWaterFetchTime) {
          if (job.claim3 is AnchorPoint && job.claim2 is AnchorSlot) {
            (job.claim3 as AnchorPoint).release(job.claim2 as AnchorSlot, v);
          }
          job.claim2 = null;
          job.claim3 = null;
          job.timer2 = 0;
          // Sulanacak en yakın büyüyen ekin.
          final wt = _nearestFarmTile(v, (t) => t.isGrowing);
          if (wt != null) {
            job.claim = wt;
            job.phase = 7;
          } else {
            job.claim = null;
            job.phase = 0; // ekin yok → suyu bırak
          }
        }
        return;

      case 7: // sulamaya yürü
        job.carryingWater = true;
        if (target == null) {
          job.phase = 0;
          return;
        }
        _walkToTileThen(v, target.col + 0.5, target.row + 0.5, () {
          job.phase = 8;
          job.timer2 = 0;
        });
        return;

      case 8: // suluyor
        job.carryingWater = true;
        v.idleTimer = 0.5;
        job.timer2 += dt;
        job.splashTimer = job.timer2;
        if (job.timer2 >= kFarmWaterTime) {
          if (target != null) {
            final cx = target.col + 0.5, cy = target.row + 0.5;
            const r2 = kFarmWaterSplashRadius * kFarmWaterSplashRadius;
            for (final t in _farmTiles) {
              if (!t.isGrowing) continue;
              final dx = t.col + 0.5 - cx, dy = t.row + 0.5 - cy;
              if (dx * dx + dy * dy <= r2) {
                t.boostGrowth(kFarmWaterBoostDuration);
              }
            }
          }
          job.claim = null;
          job.phase = 0;
          job.timer2 = 0;
        }
        return;
    }
  }

  /// [pred]'i sağlayan, köylüye en yakın tarla tile'ı (yoksa null).
  FarmTile? _nearestFarmTile(VillagerEntity v, bool Function(FarmTile) pred) {
    FarmTile? best;
    double bestD = double.infinity;
    for (final t in _farmTiles) {
      if (!pred(t)) continue;
      final dx = t.col + 0.5 - v.gridX, dy = t.row + 0.5 - v.gridY;
      final d = dx * dx + dy * dy;
      if (d < bestD) {
        bestD = d;
        best = t;
      }
    }
    return best;
  }

  /// Köylü (tx,ty) tile'ına yeterince yaklaştıysa [onArrive]'ı çağır; değilse
  /// oraya `goTo` ver (zaten yolda değilse). İş döngülerinin ortak yürü-sonra-yap.
  void _walkToTileThen(
    VillagerEntity v,
    double tx,
    double ty,
    void Function() onArrive,
  ) {
    final dx = v.gridX - tx, dy = v.gridY - ty;
    if (dx * dx + dy * dy <= 0.35 * 0.35) {
      v.state = VillagerState.idle;
      v.facingRight = tx > v.gridX;
      onArrive();
    } else if (!_enRouteTo(v, tx, ty)) {
      v.goTo(tx, ty, 0.2);
    }
  }

  /// Hasat çıktısı — saman yığını (balyaya, oradan depoya taşınır). Eski
  /// scene_tick harvestHayPos akışının yerini alır.
  void _spawnFarmHay(int col, int row) {
    final hay = HayEntity(
      type: HayType.pile,
      gridX: col.toDouble(),
      gridY: row.toDouble(),
    );
    ResourcePlacement.placeHay(
      hay,
      col.toDouble(),
      row.toDouble(),
      _hayEntities,
      _time,
    );
    _hayEntities.add(hay);
  }

  // ── MADENCİ ─────────────────────────────────────────────────────────────────
  // İşaretli madene yürü → kaz → cevher kutusu üret. claim = MineNode.
  void _runMiner(VillagerEntity v, double dt) {
    final job = v.job!;
    var node = job.claim is MineNode ? job.claim as MineNode : null;
    if (node != null && node.isDepleted) {
      node.isBeingMined = false;
      node.chopPhase = -1;
      job.claim = null;
      node = null;
    }
    if (node == null) {
      job.working = false;
      MineNode? best;
      double bestD = double.infinity;
      for (final n in _mineNodes) {
        if (!n.isMarkedForMining || n.isBeingMined || n.isDepleted) continue;
        final dx = n.col + 0.5 - v.gridX, dy = n.row + 0.5 - v.gridY;
        final d = dx * dx + dy * dy;
        if (d < bestD) {
          bestD = d;
          best = n;
        }
      }
      if (best == null) return;
      best.isBeingMined = true;
      job.claim = best;
      node = best;
      job.phase = 0;
    }
    final tx = node.col + 0.5, ty = node.row + 0.5;
    if (job.phase == 0) {
      // Maden tile'ı engel → bitişikten kaz (gevşek varış).
      final dx = v.gridX - tx, dy = v.gridY - ty;
      if (dx * dx + dy * dy <= 1.4 * 1.4) {
        v.state = VillagerState.idle;
        v.facingRight = tx > v.gridX;
        job.phase = 1;
        job.timer = 0;
        job.phaseAnim = 0;
      } else if (!_enRouteTo(v, tx, ty)) {
        v.goTo(tx, ty, 0.2);
      }
      return;
    }
    job.working = true;
    v.idleTimer = 0.5;
    job.timer += dt;
    job.phaseAnim = (job.phaseAnim + dt * 2 * pi) % (2 * pi);
    node.chopPhase = job.phaseAnim;
    if (job.timer >= node.type.mineTime) {
      final ore = node.type;
      final hc = node.col, hr = node.row;
      node.isDepleted = true;
      node.isBeingMined = false;
      node.chopPhase = -1;
      job.claim = null;
      job.phase = 0;
      job.phaseAnim = 0;
      job.working = false;
      final boxType = switch (ore) {
        OreType.iron => ResourceBoxType.ironBox,
        OreType.coal => ResourceBoxType.coalBox,
        _ => ResourceBoxType.stoneBox,
      };
      final box = ResourceBox(
        type: boxType,
        gridX: hc.toDouble(),
        gridY: hr.toDouble(),
      );
      ResourcePlacement.placeBox(
        box,
        hc.toDouble(),
        hr.toDouble(),
        _resourceBoxes,
        _time,
      );
      _resourceBoxes.add(box);
    }
  }

  // ── BALIKÇI ─────────────────────────────────────────────────────────────────
  // Kıyıya yürü → olta at (kFishDuration) → +1 yiyecek. Fiziksel kutu yok.
  void _runFisher(VillagerEntity v, double dt) {
    final job = v.job!;
    if (job.phase == 0) {
      job.working = false;
      final shore = _nearestShore(v.gridX, v.gridY);
      if (shore == null) return;
      final tx = shore.$1.toDouble(), ty = shore.$2.toDouble();
      final dx = v.gridX - tx, dy = v.gridY - ty;
      if (dx * dx + dy * dy <= 0.4 * 0.4) {
        // Konumu snap'leme — köylü zaten <0.4 tile'da; ani zıplama yerine
        // bulunduğu yerde durur (renderX zaten hedefte). Bakış hedef kareye.
        v.state = VillagerState.idle;
        // Suya bak.
        final sc = tx.round(), sr = ty.round();
        for (final (wc, wr) in [
          (sc + 1, sr),
          (sc - 1, sr),
          (sc, sr + 1),
          (sc, sr - 1),
        ]) {
          if (_waterTiles.contains((wc, wr))) {
            v.facingRight = (wc - sc) - (wr - sr) > 0;
            break;
          }
        }
        job.phase = 1;
        job.timer = 0;
        job.phaseAnim = 0;
      } else if (!_enRouteTo(v, tx, ty)) {
        v.goTo(tx, ty, 0.2);
      }
      return;
    }
    job.working = true;
    v.idleTimer = 0.5;
    job.timer += dt;
    job.phaseAnim = (job.phaseAnim + dt * 2 * pi * 0.8) % (2 * pi);
    if (job.timer >= kFishDuration) {
      _deliverFoodFrom(v, 1);
      job.phase = 0;
      job.working = false;
      job.phaseAnim = 0;
    }
  }

  /// Suya komşu, su olmayan en yakın tile (kıyı). Yoksa null.
  (int, int)? _nearestShore(double gx, double gy) {
    if (_waterTiles.isEmpty) return null;
    (int, int)? best;
    double bestD = double.infinity;
    for (final (wc, wr) in _waterTiles) {
      for (final (nc, nr) in [
        (wc - 1, wr),
        (wc + 1, wr),
        (wc, wr - 1),
        (wc, wr + 1),
      ]) {
        if (_waterTiles.contains((nc, nr))) continue;
        final dx = nc - gx, dy = nr - gy;
        final d = dx * dx + dy * dy;
        if (d < bestD) {
          bestD = d;
          best = (nc, nr);
        }
      }
    }
    return best;
  }

  // ── ÇOBAN ───────────────────────────────────────────────────────────────────
  // En yakın ağıldaki hazır ineğe yürü → sağ (6 sn) → +1 yiyecek. claim = inek.
  void _runShepherd(VillagerEntity v, double dt) {
    final job = v.job!;
    var cow = job.claim is AnimalEntity ? job.claim as AnimalEntity : null;
    if (cow != null && !cow.isBeingMilked) {
      job.claim = null;
      cow = null;
    }
    if (cow == null) {
      job.working = false;
      final barn = _nearestOf(BuildingType.barn, v);
      if (barn == null) return;
      AnimalEntity? best;
      double bestD = double.infinity;
      for (final a in _cows) {
        if (!a.readyToMilk) continue;
        if (a.barnCol != barn.col || a.barnRow != barn.row) continue;
        final dx = a.gridX - v.gridX, dy = a.gridY - v.gridY;
        final d = dx * dx + dy * dy;
        if (d < bestD) {
          bestD = d;
          best = a;
        }
      }
      if (best == null) return;
      best.isBeingMilked = true;
      job.claim = best;
      cow = best;
      job.phase = 0;
    }
    final tx = cow.gridX, ty = cow.gridY;
    if (job.phase == 0) {
      final dx = v.gridX - tx, dy = v.gridY - ty;
      if (dx * dx + dy * dy <= 0.8 * 0.8) {
        v.state = VillagerState.idle;
        v.facingRight = tx > v.gridX;
        job.phase = 1;
        job.timer = 0;
        job.phaseAnim = 0;
      } else if (!_enRouteTo(v, tx, ty)) {
        v.goTo(tx, ty, 0.2);
      }
      return;
    }
    job.working = true;
    v.idleTimer = 0.5;
    job.timer += dt;
    job.phaseAnim = (job.phaseAnim + dt * 2 * pi) % (2 * pi);
    if (job.timer >= 6.0) {
      cow.onMilked();
      job.claim = null;
      job.phase = 0;
      job.working = false;
      job.phaseAnim = 0;
      _deliverFoodFrom(v, 1);
    }
  }

  // ── ÇİÇEKÇİ ─────────────────────────────────────────────────────────────────
  // En yakın kulübenin etki alanındaki çiçeği bul → yürü → sula. claim = DecorEntity.
  void _runFlorist(VillagerEntity v, double dt) {
    final job = v.job!;
    var flower = job.claim is DecorEntity ? job.claim as DecorEntity : null;
    if (flower != null && !_decor.contains(flower)) {
      job.claim = null;
      flower = null;
    }
    if (flower == null) {
      job.working = false;
      job.carryingWater = false;
      final cottage = _nearestOf(BuildingType.floristCottage, v);
      if (cottage == null) return;
      final meta = kBuildingMeta[BuildingType.floristCottage]!;
      final ox = cottage.col + meta.cols / 2.0,
          oy = cottage.row + meta.rows / 2.0;
      final r2 = meta.effectRadius * meta.effectRadius;
      DecorEntity? best;
      double bestD = double.infinity;
      for (final d in _decor) {
        if (d.crushed || !_isFlowerDecor(d.kind)) continue;
        final dx = d.col + 0.5 - ox, dy = d.row + 0.5 - oy;
        final rr = dx * dx + dy * dy;
        if (rr > r2) continue;
        final vx = d.col + 0.5 - v.gridX, vy = d.row + 0.5 - v.gridY;
        final vd = vx * vx + vy * vy;
        if (vd < bestD) {
          bestD = vd;
          best = d;
        }
      }
      if (best == null) return;
      job.claim = best;
      flower = best;
      job.phase = 0;
    }
    final tx = flower.col + 0.5, ty = flower.row + 0.7;
    if (job.phase == 0) {
      final dx = v.gridX - tx, dy = v.gridY - ty;
      if (dx * dx + dy * dy <= 0.35 * 0.35) {
        // Konumu snap'leme — zaten <0.35 tile'da; ani zıplama yok.
        v.state = VillagerState.idle;
        v.facingRight = flower.col >= v.gridX;
        job.phase = 1;
        job.timer = 0;
        job.phaseAnim = 0;
      } else if (!_enRouteTo(v, tx, ty)) {
        v.goTo(tx, ty, 0.2);
      }
      return;
    }
    job.working = true;
    job.carryingWater = true;
    v.idleTimer = 0.5;
    job.timer += dt;
    job.phaseAnim = (job.phaseAnim + dt * 2 * pi * 1.2) % (2 * pi);
    if (job.timer >= 1.6) {
      job.claim = null;
      job.phase = 0;
      job.working = false;
      job.carryingWater = false;
      job.phaseAnim = 0;
    }
  }

  /// İnşa süresi — footprint tile sayısıyla ölçekli (eski BuilderEntity ile aynı).
  double _buildDurationFor(BuildingType t) {
    final meta = kBuildingMeta[t]!;
    return 1.0 + meta.cols * meta.rows * 0.5;
  }

  /// (col,row)'un ilk kara komşusunun merkezi — köprü inşaatçısı su üstünde
  /// durmasın. Bulamazsa tile'ın kendi merkezi.
  (double, double) _adjacentLandTile(int col, int row, Set<(int, int)> water) {
    const dirs = [(0, -1), (1, 0), (0, 1), (-1, 0)];
    for (final (dc, dr) in dirs) {
      final nc = col + dc;
      final nr = row + dr;
      if (!water.contains((nc, nr))) return (nc + 0.5, nr + 0.5);
    }
    return (col + 0.5, row + 0.5);
  }
}
