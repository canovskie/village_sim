part of '../main.dart';

/// İŞ YERLERİ — iş vermenin KİŞİDEN YERE taşındığı katman.
///
/// Eski yüzey köylü panelinde on bir rol rozetiydi: oyuncu bir köylü seçer,
/// kartını açar, "Madenci" der. O yüzeyin iki kusuru vardı. Birincisi
/// simülasyonla aynı dili konuşmuyordu — `_syncJobWorkforce` hep "bu maden bir
/// el ister" diye düşünür (bina sayar, hedef kadro kurar), panel ise "bu adam
/// madenci olsun" derdi. İkincisi Kanunname'nin reddettiği şeyin ta kendisiydi:
/// bedelsiz açılıp kapanan bir tercihler paneli.
///
/// Bu dosya simülasyonun kendi cümlesini ekrana çıkarır. Her iş kaynağı bir
/// [WorkSite]'tır: istediği el sayısı ve o an başında duran kadrosu vardır.
/// Oyuncu rol seçmez — YUVA doldurur.
///
/// Tek doğruluk kaynağı yine köylünün üstündeki mühürdür
/// ([VillagerEntity.assignedRole] + [VillagerEntity.assignedSiteId]);
/// [WorkSite] her çağrıda sahneden yeniden türetilen SALT OKUNUR bir anlık
/// görüntüdür, hiçbir yerde saklanmaz.
extension _SceneWorkSites on _VillageSceneState {
  /// Tarla ve böğürtlenlik TEK küme sayılır — kaç parsel/çalı olursa olsun bir
  /// iş yeri. Kimlikleri sabit: küme merkezinden türetseydik oyuncu bir parsel
  /// daha açınca merkez kayar, kimlik değişir, verilmiş kadro sessizce koparadı.
  static const String kFieldSiteId = 'field';
  static const String kPatchSiteId = 'patch';

  static String _buildingSiteId(BuildingEntity b, JobRole role) =>
      'b:${b.col},${b.row}:${role.name}';
  static String _orderSiteId(BuildOrder o) => 'o:${o.col},${o.row}';
  static const String kRoadSiteId = 'road';

  // ── Türetme ────────────────────────────────────────────────────────────────

  /// Köyün BUGÜNKÜ iş yerleri. Sıra oyuncuya bakan sıradır: önce eli olmayan
  /// (kadrosuz ama istekli) yerler, sonra kalanlar — panel listesinde acil olan
  /// yukarı çıksın.
  List<WorkSite> _workSites() {
    // Önce YERLER kurulur (kadro henüz boş), sonra köylüler dağıtılır.
    final skeletons = <_SiteSkeleton>[];
    _collectBuildingSites(skeletons);
    _collectFieldSite(skeletons);
    _collectPatchSite(skeletons);
    _collectConstructionSites(skeletons);
    final known = {for (final s in skeletons) s.id};

    // Kadro dağıtımı iki kademe: mühürlüler kendi yerine, mühürsüzler aynı
    // roldeki EN YAKIN yere. Böylece iki madenli köyde panel doğru ocağın
    // altında doğru adamı gösterir.
    final byId = <String, List<VillagerEntity>>{};
    final loose = <VillagerEntity>[]; // yeri belirsiz — yakınlığa göre dağıtılır

    for (final v in _villagers) {
      final role = v.job?.role ?? JobRole.none;
      if (role == JobRole.none) continue;
      final pinned = v.assignedSiteId;
      // Mührü ARTIK OLMAYAN bir yere bakıyorsa (ocak yıkıldı, sipariş bitti)
      // köylü hayalet kadro olmasın: mühürsüzlerle birlikte yeniden dağıtılır.
      // Aksi halde rolünde çalışmaya devam eder ama hiçbir panelde görünmezdi.
      if (pinned != null && known.contains(pinned)) {
        (byId[pinned] ??= []).add(v);
      } else {
        loose.add(v);
      }
    }

    for (final v in loose) {
      final role = v.job!.role;
      _SiteSkeleton? best;
      double bestD2 = double.infinity;
      for (final s in skeletons) {
        if (s.role != role) continue;
        final dx = v.gridX - s.cx, dy = v.gridY - s.cy;
        final d2 = dx * dx + dy * dy;
        if (d2 < bestD2) {
          bestD2 = d2;
          best = s;
        }
      }
      // Rolüne uyan HİÇBİR yer yoksa (köyün son madeni yıkıldı) köylü hiçbir
      // yuvada görünmez. Bu bir hata değil, panelin doğru söylemesi: o işin
      // artık yeri yok — köylünün kendi kartı rolünü hâlâ okur ve "İşten al"
      // orada durur.
      if (best != null) (byId[best.id] ??= []).add(v);
    }

    final sites = <WorkSite>[
      for (final s in skeletons) s.build(byId[s.id] ?? const []),
    ];

    sites.sort((a, b) {
      // Aç kalan yer (isteyip kimseyi bulamayan) hep önde.
      final ah = a.starving ? 0 : 1, bh = b.starving ? 0 : 1;
      if (ah != bh) return ah - bh;
      return a.label.compareTo(b.label);
    });
    return sites;
  }

  /// [id]'li iş yerinin bugünkü hâli — yoksa null (bina yıkıldı, sipariş bitti).
  WorkSite? _siteById(String id) {
    for (final s in _workSites()) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Bu binanın barındırdığı iş yerleri — bir bina birden fazla iş doğurabilir
  /// (ocak: aşçı + —ambar yoksa— dokumacı).
  List<WorkSite> _sitesOfBuilding(BuildingEntity b) =>
      _workSites().where((s) => identical(s.source, b)).toList();

  /// [role] için köyün gösterebileceği tek yer — öğretici ışığı buraya bakar.
  /// Birden fazlaysa kadrosu en aç olanı seçer (oyuncunun ilgilenmesi gereken).
  WorkSite? _siteForRole(JobRole role) {
    WorkSite? best;
    for (final s in _workSites()) {
      if (s.role != role) continue;
      if (best == null || (s.crew.length < best.crew.length)) best = s;
    }
    return best;
  }

  // ── Kaynak başına iskelet ──────────────────────────────────────────────────

  void _collectBuildingSites(List<_SiteSkeleton> out) {
    final loom = _loomSpot;
    // `_buildings` yalnız YÜKSELMİŞ yapıları tutar (yükselmekte olanlar
    // `_orders` kuyruğunda, ayrı şantiye iş yeri olarak çıkar).
    for (final b in _buildings) {
      final m = kBuildingMeta[b.type];
      final cx = b.col + (m?.cols ?? b.cols) / 2.0;
      final cy = b.row + (m?.rows ?? b.rows) / 2.0;
      final label = m?.label ?? 'Yapı';

      void add(
        JobRole role,
        int wanted, {
        String? idleReason,
        bool autoStaffed = true,
      }) {
        out.add(
          _SiteSkeleton(
            id: _buildingSiteId(b, role),
            kind: WorkSiteKind.building,
            role: role,
            label: label,
            wanted: wanted,
            cx: cx,
            cy: cy,
            source: b,
            idleReason: idleReason,
            autoStaffed: autoStaffed,
          ),
        );
      }

      switch (b.type) {
        case BuildingType.mineBuilding:
          add(JobRole.miner, 1);
        case BuildingType.fisherCabin:
          // Göl kışın donar — yuva kapanmaz, yalnız sebebi yazar. Kapatsaydık
          // oyuncunun kışın verdiği karar baharda kendiliğinden silinirdi.
          add(
            JobRole.fisher,
            1,
            idleReason: waterFrozen(_season) ? 'Göl dondu — ağ atılmaz.' : null,
          );
        case BuildingType.floristCottage:
          add(JobRole.florist, 1);
        case BuildingType.barn:
          add(JobRole.shepherd, 1);
        case BuildingType.lumberCamp:
          add(JobRole.woodcutter, 1);
        case BuildingType.firepit:
          // AŞÇI kendiliğinden atanmaz (bkz. `_syncJobWorkforce`): erken oyunun
          // tek amacı oyuncunun "kim ne yapsın" kararını vermesi.
          add(
            JobRole.cook,
            1,
            autoStaffed: false,
            idleReason: _stockpile.food < kCookFoodCost
                ? 'Ocakta pişirecek ham yiyecek yok.'
                : null,
          );
        default:
          break;
      }

      // DOKUMACI tezgâhı ambarda kurulur, ambar yoksa ocağın başında
      // (bkz. `_loomSpot`) — yer hangisiyse yuva orada durur.
      if (identical(loom, b)) {
        add(
          JobRole.weaver,
          _weaverWanted(),
          idleReason: _weaverIdleReason(),
        );
      }
    }
  }

  /// Dokumacı kadrosunun mevsimlik hedefi — `_syncJobWorkforce`'takiyle AYNI
  /// hesap. İki yerde iki formül olsaydı panel bir sayı, sim başka bir sayı
  /// söylerdi.
  int _weaverWanted() {
    final weaveSeason = _season == Season.autumn || _season == Season.winter;
    if (!weaveSeason || _stockpile.wool < 3) return 0;
    return (_stockpile.wool ~/ 9).clamp(1, 2);
  }

  String? _weaverIdleReason() {
    if (_season != Season.autumn && _season != Season.winter) {
      return 'Tezgâh mevsimi değil — kışlık sonbaharda dokunur.';
    }
    if (_stockpile.wool < 3) return 'Yün yok — kırkım beklenir.';
    if (!_coatsNeeded) return 'Köyün herkesi giyindi.';
    return null;
  }

  void _collectFieldSite(List<_SiteSkeleton> out) {
    if (_farmTiles.isEmpty) return;
    // Küme merkezi yalnız KAMERA için — kimlik sabit (bkz. kFieldSiteId).
    double sx = 0, sy = 0;
    for (final t in _farmTiles) {
      sx += t.col + 0.5;
      sy += t.row + 0.5;
    }
    final n = _farmTiles.length;
    final frozen = _season.isFrozen;
    out.add(
      _SiteSkeleton(
        id: kFieldSiteId,
        kind: WorkSiteKind.field,
        role: JobRole.farmer,
        label: n > 1 ? 'Tarlalar' : 'Tarla',
        wanted: frozen ? 0 : _farmWorkforceTarget(),
        cx: sx / n,
        cy: sy / n,
        idleReason: frozen ? 'Toprak dondu — tarla kış molasında.' : null,
      ),
    );
  }

  void _collectPatchSite(List<_SiteSkeleton> out) {
    if (_berryBushes.isEmpty) return;
    double sx = 0, sy = 0;
    for (final b in _berryBushes) {
      sx += b.col + 0.5;
      sy += b.row + 0.5;
    }
    final n = _berryBushes.length;
    final ripe = _berryBushes.where((b) => b.harvestable).length;
    out.add(
      _SiteSkeleton(
        id: kPatchSiteId,
        kind: WorkSiteKind.patch,
        role: JobRole.forager,
        label: 'Böğürtlenlik',
        // Bina istemeyen tek iş — oyunun ilk saniyesinden itibaren verilebilir
        // olması erken oyunun bütün meselesi. Köy oraya kimseyi kendiliğinden
        // yollamaz; bu yuvayı yalnız oyuncu doldurur.
        wanted: 1,
        autoStaffed: false,
        cx: sx / n,
        cy: sy / n,
        idleReason: ripe == 0 ? 'Çalılar çıplak — meyve yeniden gelecek.' : null,
      ),
    );
  }

  void _collectConstructionSites(List<_SiteSkeleton> out) {
    for (final o in _orders) {
      if (o.completed) continue;
      final m = kBuildingMeta[o.type];
      out.add(
        _SiteSkeleton(
          id: _orderSiteId(o),
          kind: WorkSiteKind.construction,
          role: JobRole.builder,
          label: 'Şantiye · ${m?.label ?? 'Yapı'}',
          wanted: o.requiredWorkers,
          cx: o.col + (m?.cols ?? 1) / 2.0,
          cy: o.row + (m?.rows ?? 1) / 2.0,
          source: o,
        ),
      );
    }
    // YOLLAR tek iş yeri sayılır: her karo ayrı bir şantiye olsaydı köyün
    // panelinde otuz "Şantiye · Yol" satırı olurdu.
    final pending = _roadOrders.where((o) => !o.completed).toList();
    if (pending.isEmpty) return;
    double sx = 0, sy = 0;
    for (final o in pending) {
      sx += o.col + 0.5;
      sy += o.row + 0.5;
    }
    out.add(
      _SiteSkeleton(
        id: kRoadSiteId,
        kind: WorkSiteKind.construction,
        role: JobRole.builder,
        label: 'Yol İşi',
        wanted: pending.length.clamp(1, kMaxBuilders),
        cx: sx / pending.length,
        cy: sy / pending.length,
      ),
    );
  }

  /// Bu karonun üstünde YAPISI OLMAYAN bir iş yeri var mı — haritadan seçim
  /// bunun üstünden çalışır. Bina iş yerleri buraya girmez: onlara zaten
  /// binanın kendisine tıklanarak ulaşılır (`_buildingAt`).
  ///
  /// Sıra çakışmayı çözer: şantiye tarladan öndedir (yeni yapı bir tarlanın
  /// üstüne kurulmuşsa oyuncu şantiyeyi kastediyordur), çalılık en sonda.
  String? _siteIdAt(int col, int row) {
    for (final o in _orders) {
      if (o.completed) continue;
      final m = kBuildingMeta[o.type];
      final w = m?.cols ?? 1, h = m?.rows ?? 1;
      if (col >= o.col && col < o.col + w && row >= o.row && row < o.row + h) {
        return _SceneWorkSites._orderSiteId(o);
      }
    }
    for (final o in _roadOrders) {
      if (!o.completed && o.col == col && o.row == row) {
        return _SceneWorkSites.kRoadSiteId;
      }
    }
    for (final t in _farmTiles) {
      if (t.col == col && t.row == row) return _SceneWorkSites.kFieldSiteId;
    }
    for (final b in _berryBushes) {
      if (b.col == col && b.row == row) return _SceneWorkSites.kPatchSiteId;
    }
    return null;
  }

  // ── Oyuncunun eli: yuvayı doldur / boşalt ─────────────────────────────────

  /// Boş yuvaya el ver — iş yerine EN YAKIN uygun köylüyü mühürler.
  ///
  /// Köylüyü oyuncu seçmez, YER seçer: "şu ocağa bir el" demek yeter. En
  /// yakını almak yalnız kolaylık değil, doğruluk meselesi — uzaktaki köylü
  /// yola çıkıp path bulamayınca takılırdı (bkz. `_reconcileRole`'ün aynı
  /// yakınlık sıralaması).
  ///
  /// Kimse boş değilse false döner ve sebebini söyler.
  bool _fillSlot(WorkSite site) {
    final v = _nearestFreeFor(site);
    if (v == null) {
      _showNotification(
        '${site.role.icon} ${site.label} el bekliyor ama köyde boş kimse yok.',
      );
      return false;
    }
    _pinToSite(v, site);
    return true;
  }

  /// Belirli bir köylüyü bu yuvaya koy (panelden isim seçildiğinde).
  void _pinToSite(VillagerEntity v, WorkSite site) {
    v.assignedSiteId = site.id;
    _assignVillagerJob(v, site.role);
  }

  /// Yuvayı boşalt — köylü otomatik iş gücü havuzuna geri döner.
  ///
  /// Yer KAPANMAZ, yalnız o el çekilir: köy hâlâ bir el istiyorsa otomatik
  /// kadro yuvayı başka biriyle doldurur. "Bu ocak boş dursun" demek başka bir
  /// eylemdir — binayı duraklatmak (bkz. [BuildingEntity.userPaused]).
  ///
  /// Çıkarılan köylüye kısa bir soğuma konur: konmasaydı bir sonraki kadro
  /// senkronu (2 sn) en yakın boşu ararken çoğu zaman AYNI adamı bulur, yuva
  /// aynı yüzle geri dolar ve oyuncu hiçbir şey olmadığını sanırdı.
  void _emptySlot(VillagerEntity v) {
    v.assignedSiteId = null;
    _assignVillagerJob(v, null);
    v.jobReassignCd = 12.0;
  }

  /// Bu iş yerine yollanabilecek en yakın boş köylü. Baz mesleği eşleşen
  /// (çiftçi tarlaya, madenci ocağa) öncelenir — `_reconcileRole` ile aynı
  /// kural, iki yerde iki davranış olmasın.
  VillagerEntity? _nearestFreeFor(WorkSite site) {
    final match = _baseTypeFor(site.role);
    VillagerEntity? best;
    double bestKey = double.infinity;
    for (final v in _villagers) {
      if (!_freeForJob(v)) continue;
      final dx = v.gridX - site.cx, dy = v.gridY - site.cy;
      // Meslek eşleşmesi mesafeden ÖNCE gelir: eşleşen aday, uzak da olsa
      // eşleşmeyen yakının önüne geçsin diye anahtara büyük bir sabit eklenir.
      final key = dx * dx + dy * dy + (v.type == match ? 0 : 1e6);
      if (key < bestKey) {
        bestKey = key;
        best = v;
      }
    }
    return best;
  }

  /// Rolün tercih ettiği baz meslek — yoksa null (herhangi boş yetişkin).
  VillagerType? _baseTypeFor(JobRole role) => switch (role) {
    JobRole.farmer => VillagerType.farmer,
    JobRole.miner => VillagerType.miner,
    JobRole.fisher => VillagerType.fisher,
    JobRole.shepherd => VillagerType.shepherd,
    _ => null,
  };

  /// Köylünün ŞU AN çalıştığı yer — köylü panelinin okuduğu satır.
  WorkSite? _siteOfVillager(VillagerEntity v) {
    if (!v.hasActiveJob) return null;
    for (final s in _workSites()) {
      if (s.crew.contains(v)) return s;
    }
    return null;
  }

  /// Eski kayıttan gelen ([assignedRole] dolu, [assignedSiteId] boş) köylüleri
  /// bugünkü iş yerlerine mühürler. Kayıt yüklendikten sonra bir kez çağrılır;
  /// yeri bulunamayan köylü mühürsüz kalır (rolü durur, panelde yuvasız görünür
  /// — sessizce işten almaktansa böylesi dürüst).
  void _adoptLegacyAssignments() {
    final sites = _workSites();
    for (final v in _villagers) {
      final role = v.assignedRole;
      if (role == null || role == JobRole.none) continue;
      if (v.assignedSiteId != null) continue;
      WorkSite? best;
      double bestD2 = double.infinity;
      for (final s in sites) {
        if (s.role != role) continue;
        final dx = v.gridX - s.cx, dy = v.gridY - s.cy;
        final d2 = dx * dx + dy * dy;
        if (d2 < bestD2) {
          bestD2 = d2;
          best = s;
        }
      }
      if (best != null) v.assignedSiteId = best.id;
    }
  }
}

/// Kadrosu henüz dağıtılmamış iş yeri — [_workSites] iki geçişte çalışır
/// (önce yerleri kur, sonra köylüleri en yakın yere dağıt), bu ara formu o
/// yüzden var. Dışarı sızmaz.
class _SiteSkeleton {
  final String id;
  final WorkSiteKind kind;
  final JobRole role;
  final String label;
  final int wanted;
  final double cx, cy;
  final Object? source;
  final String? idleReason;
  final bool autoStaffed;

  const _SiteSkeleton({
    required this.id,
    required this.kind,
    required this.role,
    required this.label,
    required this.wanted,
    required this.cx,
    required this.cy,
    this.source,
    this.idleReason,
    this.autoStaffed = true,
  });

  WorkSite build(List<VillagerEntity> crew) => WorkSite(
    id: id,
    kind: kind,
    role: role,
    label: label,
    wanted: wanted,
    cx: cx,
    cy: cy,
    source: source,
    crew: List.unmodifiable(crew),
    idleReason: idleReason,
    autoStaffed: autoStaffed,
  );
}
