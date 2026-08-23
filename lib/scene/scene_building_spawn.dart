part of '../main.dart';

/// Bina tamamlandığında ne olur + NPC spawn (başlangıç + yetişkin doğum) +
/// uyku hedefi atama + spawn pozisyon temizleme + tek-tıkla canlı köy.
/// part of main.dart — State'in tüm private alanlarına erişim.
extension _SceneBuildingSpawn on _VillageSceneState {
  /// Dev köyleri için ekili tarla: gerçek oyunda çiftçi önce tohum atar
  /// (needsSowing), ama showcase/yaşayan köy ilk karede olgun görünmeli —
  /// tile'lar rastgele büyüme aşamasında ekili doğar.
  FarmTile _devSownTile(int c, int r) {
    final t = FarmTile(c, r)..sow();
    t.stage = _rng.nextInt(4);
    t.growthProgress = _rng.nextDouble();
    return t;
  }

  // ── Doğumun / gelenin sesi ([[lib/text/voice.dart]]) ──────────────────────
  // Doğum küçük ve fizikseldir: bir ses, bir kucak, ocağa atılan fazladan odun.

  static const _kJoinFamilyPool = [
    '👶 {aile} hanesinde bir çocuk daha: {ad}.',
    '👶 {aile} sofrasına {ad} oturdu. Kapıları bugün kalabalık.',
    '👶 {ad} artık {aile} çatısı altında.',
  ];
  static const _kJoinPool = [
    '👶 {ad} dünyaya geldi.',
    '👶 Köyün yeni sakini: {ad}.',
    '👶 {ad} bugün köye katıldı.',
  ];
  static const _kBirthPool = [
    '👶 {bebek} doğdu. {ad} sabaha kadar uyumadı, {öteki} kapının önünde bekledi.',
    '👶 {ad} ile {öteki-in} çocuğu oldu. Adını {bebek} koydular.',
    '👶 Evde bir ses daha var: {bebek}. {öteki} ocağa fazladan odun attı.',
  ];
  static const _kBirthLifePool = ['Çocuğu oldu: {bebek}', '{bebek} doğdu'];
  static const _kMigrantPool = [
    '🚶 {ad} kervanla geldi, boş yatağa yerleşti. Köyün ona alışması sürer.',
    '🚶 {ad} kervandan ayrılıp kapıyı çaldı ve kaldı. Yeni gelene ısınmak zaman ister.',
    '🚶 {ad} kervan yolculuğunu burada bitirip köye yerleşti. İlk günler herkes birbirini süzüyor.',
  ];

  /// Ahır/kümes panelinden hayvan satın al — bina BOŞ kurulur, sürü buradan
  /// kurulur. Altın harcar; kapasiteyi aşamaz. Cinsiyet akıllı: o binada erkek
  /// yoksa erkek gelir (çift kurulup üreyebilsin), varsa dişi. Genç yetişkin
  /// doğar (uzun üreme/ömür penceresi).
  void _buyAnimal(BuildingEntity b, AnimalKind kind) {
    final cap = kAnimalBarnCap[kind] ?? 5;
    final living = _cows
        .where(
          (c) =>
              !c.isDying &&
              c.kind == kind &&
              c.barnCol == b.col &&
              c.barnRow == b.row,
        )
        .toList();
    if (living.length >= cap) {
      _showNotification('${animalKindLabel(kind)} için yer yok (dolu)');
      return;
    }
    final cost = kAnimalGoldCost[kind] ?? 5;
    if (_stockpile.gold < cost) {
      _showNotification('Yetersiz altın — $cost★ gerek');
      return;
    }
    final male = !living.any((c) => c.isMale); // erkek yoksa erkek getir
    final (sx, sy) = _nearestLand(
      b.col + b.cols / 2.0,
      b.row + b.rows.toDouble(),
    );
    setStateHere(() {
      _stockpile.gold -= cost;
      _cows.add(
        AnimalEntity(
          kind: kind,
          barnCol: b.col,
          barnRow: b.row,
          startCol: sx + (_rng.nextDouble() - 0.5) * 0.6,
          startRow: sy + (_rng.nextDouble() - 0.5) * 0.6,
          isMale: male,
          ageDays: AnimalEntity.kAnimalAdultDay + _rng.nextDouble() * 2.0,
          lifespanDays:
              AnimalEntity.kAnimalElderDay + 8.0 + _rng.nextDouble() * 12.0,
        ),
      );
    });
    if (kind == AnimalKind.cow) {
      AudioManager.instance.playSfx(Sfx.cowMoo);
    } else if (kind == AnimalKind.chicken) {
      AudioManager.instance.playSfx(Sfx.chickenCluck);
    }
    _showNotification('${animalKindLabel(kind)} ağıla katıldı  (-$cost★)');
  }

  /// Bir kişilik tohumunun çağrısı (içindeki meslek eğilimi). Doğan/göçen
  /// köylülerin mesleği bununla belirlenir — rastgele değil, kişilikten doğar.
  VillagerType _callingForSeed(int seed) =>
      callingFor(Personality.fromSeed(seed), seed);

  /// İstenen mesleğe çağrısı olan bir kişilik tohumu bul — kurucuların
  /// kişiliği mesleğiyle uyumlu olsun diye (demirci ateş sever, muhafız cesur…).
  /// Bulamazsa rastgele tohum döner (deterministik kalır).
  int _seedForCalling(VillagerType want) {
    for (int i = 0; i < 240; i++) {
      final s = _rng.nextInt(0x7FFFFFFF);
      if (_callingForSeed(s) == want) return s;
    }
    return _rng.nextInt(0x7FFFFFFF);
  }

  /// Köyün en eksik sivil mesleği (yetişkinler arasında en az temsil edilen) —
  /// "zanaat yönlendirmesi" politikası gencin yönünü buraya çeker. Belirgin bir
  /// eksiklik yoksa (hepsi dengeli) null döner → çağrı/çıraklık devreye girer.
  VillagerType? _scarcestTrade() {
    // callingFor()'un sivil havuzuyla BİREBİR aynı olmalı — yoksa politika
    // ulaşılamayan bir mesleğe yönlendirir ya da yenileri hiç göremez.
    const civilian = [
      VillagerType.farmer,
      VillagerType.merchant,
      VillagerType.blacksmith,
      VillagerType.guard,
      VillagerType.priest,
      VillagerType.shepherd,
      VillagerType.hunter,
      VillagerType.miller,
      VillagerType.innkeeper,
    ];
    final count = {for (final t in civilian) t: 0};
    for (final v in _villagers) {
      if (v.isDying || !v.hasProfession) continue;
      if (count.containsKey(v.type)) count[v.type] = count[v.type]! + 1;
    }
    final lo = count.values.reduce(min);
    final hi = count.values.reduce(max);
    if (lo == hi) return null; // denge var — yönlendirilecek belirgin eksik yok
    final scarce = [
      for (final e in count.entries)
        if (e.value == lo) e.key,
    ];
    return scarce[_rng.nextInt(scarce.length)];
  }

  /// Soy ERKEK üzerinden taşınır (kullanıcı kararı). Bir çocuğun soyadı:
  /// babasının → (yoksa) diğer ebeveynin → (yoksa) köyün baskın soyunun.
  /// Köy boşsa yeni bir soyad üretir (ilk kuruluş).
  String _patrilinealSurname(List<VillagerEntity> parents) {
    for (final p in parents) {
      if (p.isMale && p.surname.isNotEmpty) return p.surname;
    }
    for (final p in parents) {
      if (p.surname.isNotEmpty) return p.surname;
    }
    return _villageLineage();
  }

  /// Köyün baskın soyu = yaşayanlar arasında en kalabalık soyad. Yoksa yeni soy.
  String _villageLineage() {
    final count = <String, int>{};
    for (final v in _villagers) {
      if (v.isDying || v.surname.isEmpty) continue;
      count[v.surname] = (count[v.surname] ?? 0) + 1;
    }
    if (count.isEmpty) return randomVillagerSurname(_rng);
    var best = count.keys.first;
    for (final e in count.entries) {
      if (e.value > count[best]!) best = e.key;
    }
    return best;
  }

  /// Kurucu kadro — İKİ ÇİFT + BİR YAŞLI.
  ///
  /// Eskiden beş kurucu meslek listesinden sırayla doğar, cinsiyetleri
  /// `i.isEven` ile serpiştirilirdi: kimse kimsenin nesi olmazdı. Oyuncunun ilk
  /// on dakikada bağlanacağı bir ilişki yoktu, sadece beş çalışan vardı.
  ///
  /// Şimdi kadro bir AİLE: iki evli çift ve bir dul yaşlı. Bu, üç sistemi ilk
  /// günden çalıştırır — doğum (aynı evde kan bağı olmayan çift arar), hane
  /// (tek soyad = tek ocak) ve ateş başı hikâye saati (yaşlı = anlatıcı).
  ///
  /// Sıra ÖNEMLİ: barınak atama listeyi baştan tarar (bkz. housing dalı), yani
  /// çiftler yan yana dizildiği için ilk iki kapasiteli ev onları eş olarak
  /// içine alır. Sırayı bozmak çiftleri ayrı evlere düşürür ve doğumu susturur.
  static const List<(VillagerType, bool)> _kFounderRoster = [
    (VillagerType.farmer, true), // reis — köyün ekmeği
    (VillagerType.shepherd, false), // eşi
    (VillagerType.hunter, true), // genç adam
    (VillagerType.miller, false), // eşi
    (VillagerType.priest, true), // dul yaşlı — ateşin başındaki ses
  ];

  /// KÖYÜN KURULUŞU — kafile yürüyerek gelir.
  ///
  /// Kurucular artık ateş yakılınca yoktan var olmuyor; oyun BAŞLADIĞI anda
  /// haritanın bir kenarından çıkıp köyün kurulacağı yere doğru yürüyorlar.
  /// Sebebi doğrudan şikâyetin kendisi: eski açılışta ekranda hiç kimse yoktu,
  /// oyuncu boş bir çayıra bakıp "şimdi ne yapacağım" diyordu. Artık ilk saniyede
  /// sahnede beş insan var ve bir yere gidiyorlar.
  ///
  /// [_generateWorld] sonunda çağrılır (ateş yeri henüz YOK).
  /// [roster] verilmezse varsayılan kadro, [lineage] verilmezse rastgele soyad
  /// kullanılır. İkisi de kuruluş kararının ([FoundingChoice]) sahnedeki karşılığı.
  void _spawnFoundingCaravan({
    List<(VillagerType, bool)>? roster,
    String? lineage,
  }) {
    const cx = kCols / 2.0, cy = kRows / 2.0;
    // Giriş yönü — kafile haritanın rastgele bir yanından girer, hep aynı
    // yerden gelmesin. Mesafe kısa tutuldu (~16 tile): açılış kamerasının
    // içinde kalsın, yürüyüş dakikalar değil saniyeler sürsün.
    // GİRİŞ NOKTASI EKRAN EKSENLERİNDE SEÇİLİR (u = c−r, v = c+r).
    //
    // Eskiden dünya-uzayında "rastgele açı × 12 tile" idi ve yorumu "açılış
    // kadrajının içinde kalır" diyordu. TUTMUYORDU: 12 tile'lık dünya mesafesi
    // ekran-X'inde 12·|cosθ−sinθ| = 17 tile'a kadar çıkar. Ölçtüm — bir koşuda
    // kalp u=−17.2'ye düştü, yani merkezden 550px yana.
    //
    // Bu yalnız "kenarda durur" meselesi değil: 1. günde reach kutusu tam
    // viewport genişliğinde olduğu için kameranın YATAY serbestliği sıfırdır
    // (bkz. scene_input `_clampCamera`). Kamera köye ortalanır, clamp onu
    // anında geri çeker ve oyuncu insanlarını kadrajın köşesinde bulur.
    // Dünya "zoom-out ile büyüdüğü" için erken oyunda kadraj pazarlığa kapalı;
    // o hâlde kafile kadrajın içine DOĞMALI.
    //
    // ±7 tile: iki ekran ekseninde de rahat pay. Yön yine rastgele — kafile
    // hep aynı yandan girmez, sadece görünmeyen bir yandan girmez.
    //
    // Nokta BİR KEZ seçilir ve saklanır: kuruluş kararı kadroyu değiştirince
    // kafile yeniden doğar, ama AYNI yerden doğmalı — kamera kilidi (aşağıdaki
    // clamp notu) bir kez takıldıktan sonra köyün kalbi yer değiştiremez.
    if (!_caravanEntrySet) {
      _caravanEntrySet = true;
      _caravanU = (_rng.nextDouble() * 2 - 1) * 7.0;
      _caravanV = (_rng.nextDouble() * 2 - 1) * 7.0;
    }
    final u0 = _caravanU;
    final v0 = _caravanV;
    final ex = cx + (v0 + u0) / 2;
    final ey = cy + (v0 - u0) / 2;
    // Yürüyüş yönü seçilen noktadan türer (kafile merkeze doğru dizilir).
    final angle = atan2(ey - cy, ex - cx);

    // TEK SOYAD — köy tek hane ile kurulur; kurucular birbirinin kan bağı
    // DEĞİL (parents boş), o yüzden aralarında çift olabilirler.
    final family = lineage ?? randomVillagerSurname(_rng);
    final crew = roster ?? _kFounderRoster;
    final founders = <VillagerEntity>[];

    for (int i = 0; i < crew.length; i++) {
      final (type, male) = crew[i];
      final elder = i == 4;
      // Beşinciden SONRASI "fazladan can" — kuruluş kararıyla gelen bekâr
      // (bkz. FoundingChoice). Çift değildir; eşi dışarıdan gelir.
      final spare = i > 4;
      // Çiftler yaşça yakın, yaşlı belirgin biçimde ileri yaşta — köy ilk
      // günden bir kuşak farkı taşısın (hikâye saati bundan besleniyor).
      final age = elder
          ? kElderStartDay + _rng.nextDouble() * 6
          : spare
          ? kAdultStartDay + _rng.nextDouble() * 3
          : kAdultStartDay + (i < 2 ? 12 : 2) + _rng.nextDouble() * 5;
      // Kafile TEK SIRA yürür: arkadakiler öndekinin izinde, hafif yalpayla.
      final back = i * 1.15;
      final v = VillagerEntity(
        type: type,
        name: randomVillagerName(_rng, male: male),
        surname: family,
        male: male,
        // Kişilik mesleğiyle uyumlu — çağrı sistemiyle tutarlı köy.
        personalitySeed: _seedForCalling(type),
        startCol: ex + cos(angle) * back + (_rng.nextDouble() - 0.5) * 0.9,
        startRow: ey + sin(angle) * back + (_rng.nextDouble() - 0.5) * 0.9,
        ageDays: age,
        lifespanDays: _rollLifespan(),
      );
      // Evli sayılırlar — düğün adayı havuzuna düşmesinler (yaşlı dul, o da
      // `wed` kalır: cozy kural gereği kimse zorla yeniden evlendirilmez).
      // Fazladan can BEKÂRDIR: köyün ilk düğünü onunla olur.
      v.wed = !spare;
      v.lastStageSeen = v.lifeStage;
      founders.add(v);
      _villagers.add(v);
      _lifeEvent(
        v,
        elder
            ? 'Kafileyle bu topraklara geldi'
            : spare
            ? 'Kafile onu geride bırakmadı'
            : 'Köyü kurmaya geldi',
        icon: '🧭',
        milestone: true,
      );
    }

    // Hepsi merkeze doğru yürüsün — varışta oyalanırlar (dwell), oyuncu ateş
    // yerini seçene kadar orada dolanırlar.
    for (int i = 0; i < founders.length; i++) {
      final v = founders[i];
      final a = _rng.nextDouble() * 2 * pi;
      final r = 1.0 + _rng.nextDouble() * 2.2;
      final (tx, ty) = _nearestLand(cx + cos(a) * r, cy + sin(a) * r);
      v.goTo(tx, ty, 6.0 + _rng.nextDouble() * 4.0);
    }

    _fixNpcSpawns();
  }

  /// KURULUŞ KARARI dünyaya işlenir — kafilenin yükü (bkz. [FoundingChoice]).
  ///
  /// Kurucular sinematik başlamadan önce doğmuştu (kafile `_generateWorld`
  /// sonunda kurulur; kamera kadrajı buna bağlı). Karar kadroyu değiştirdiği
  /// için kafile YENİDEN doğar — meslek başına kişilik tohumu `final`, yani
  /// yerinde meslek değiştirmek köylüyü kendi çağrısına yabancılaştırırdı
  /// (kuruluşun ilk beş kişisi kırgın başlamamalı).
  ///
  /// Güvenli olmasının sebebi zamanlama: sinematik oynarken sim DURUR, kimse
  /// bir işe/eve/çapaya bağlanmamıştır. Ateş kurulduktan sonra çağrılmaz.
  void _applyFoundingChoice(FoundingChoice c) {
    if (_hasFire) return; // kuruluş geçti — kadro artık köyün kendi malı
    // Soyad korunur: ad kapısı (bir sonraki çekim) henüz açılmadı, kuruluşta
    // atanan rastgele soyad burada kaybolmamalı.
    final family = _villagers.isNotEmpty ? _villagers.first.surname : null;
    _villagers.clear();
    _spawnFoundingCaravan(roster: c.roster, lineage: family);

    _stockpile.wood = c.wood;
    _stockpile.stone = c.stone;
    _stockpile.food = c.food;
  }

  /// Hanenin adını oyuncu koydu — kurucuların hepsine soyad olarak işlenir.
  /// ("… Hanesi" hane kartlarında, meclis masasında, dilekçelerde konuşur.)
  void _renameFoundingLineage(String house) {
    final name = house.trim();
    if (name.isEmpty) return;
    for (final v in _villagers) {
      v.surname = name;
    }
  }

  /// Ateş yakıldı — kurucular ocağın başına toplanır.
  ///
  /// Kafile zaten sahnede olduğu için burada artık kimse DOĞMAZ: köylüler
  /// ateşin çevresine yürütülür. (Eski davranış — ışınlanarak beliren beş
  /// kurucu — yalnız showcase/referans köy gibi kafilesiz kurulumlar için
  /// yedekte duruyor.)
  void _spawnStartingNPCs(BuildingEntity firepit) {
    final cx = firepit.col + 0.5;
    final cy = firepit.row + 0.5;

    if (_villagers.isEmpty) {
      _spawnFoundingCaravan();
      // Kafilesiz kurulum (test/showcase): kurucuları doğrudan ateşin dibine al.
      for (int i = 0; i < _villagers.length; i++) {
        final angle = i * (2 * pi / _villagers.length);
        final dist = 1.2 + _rng.nextDouble() * 0.6;
        _villagers[i].gridX = cx + cos(angle) * dist;
        _villagers[i].gridY = cy + sin(angle) * dist;
      }
      _fixNpcSpawns();
      return;
    }

    // Kafile geldi: ocağın çevresine dizil. Işınlanma yok — yürüyerek.
    for (int i = 0; i < _villagers.length; i++) {
      final v = _villagers[i];
      final angle = i * (2 * pi / _villagers.length);
      final dist = 1.6 + _rng.nextDouble() * 0.8;
      final (tx, ty) = _nearestLand(
        cx + cos(angle) * dist,
        cy + sin(angle) * dist,
      );
      v.goTo(tx, ty, 8.0);
      _lifeEvent(
        v,
        'Köyün ocağı yakıldığında oradaydı',
        icon: '🔥',
        milestone: true,
      );
    }
  }

  /// Gece: uyku hedeflerini ata. Ev varsa ev merkezi, yoksa ateş etrafı.
  void _assignSleepTargets() {
    int idx = 0;
    for (final v in _villagers) {
      if (v.homeBuilding case final home?) {
        final b = home as BuildingEntity;
        final meta = kBuildingMeta[b.type]!;
        v.sleepTarget = (b.col + meta.cols / 2.0, b.row + meta.rows / 2.0);
        v.sleepIsHome = true;
      } else if (_bedOf(v) case final bed?) {
        // Evsiz ama saz yatağı var → kendi yatağında uyur (dışarıda, ateş başı).
        v.sleepTarget = (bed.gridX, bed.gridY);
        v.sleepIsHome = false;
      } else if (_firepitBuilding != null) {
        final fp = _firepitBuilding!;
        final angle = idx * (2 * pi / _villagers.length);
        final dist = 1.4 + (_rng.nextDouble() * 0.7);
        v.sleepTarget = (
          fp.col + 0.5 + cos(angle) * dist,
          fp.row + 0.5 + sin(angle) * dist,
        );
        v.sleepIsHome = false;
      }
      idx++;
    }
  }

  /// Belediyenin büyüme döngüsü dolunca yeni köylü doğurur, boş eve yerleştirir.
  /// Atandığı evdeki yetişkin sakinler (max 2) ebeveyn olur, aile bağı kurulur.
  void _spawnGrownVillager(BuildingEntity townhall) {
    BuildingEntity? house;
    for (final b in _buildings) {
      final f = b.fn;
      if (f == null || f.role != BuildingRole.housing) continue;
      final occ = _villagers.where((v) => v.homeBuilding == b).length;
      if (occ < f.housingCapacity) {
        house = b;
        break;
      }
    }

    // Meslek = içindeki çağrı; ama zanaat yönlendirmesi açıksa köyün eksik
    // mesleğine yöneltilebilir (çağrısı tutmazsa kırgınlık).
    final pseed = _rng.nextInt(0x7FFFFFFF);
    final scarce = _policies.tradeGuidance ? _scarcestTrade() : null;
    final type = (scarce != null && _rng.nextInt(3) != 0)
        ? scarce
        : _callingForSeed(pseed);
    final (sx, sy) = _nearestLand(
      townhall.col + townhall.cols / 2.0,
      townhall.row + townhall.rows.toDouble(),
    );
    final male = _rng.nextBool();
    final v = VillagerEntity(
      type: type,
      name: randomVillagerName(_rng, male: male),
      // Soyad ebeveyn atandıktan SONRA belirlenir (baba soyu). Eskiden burada
      // rastgele soyad veriliyordu → köyde doğan çocuk bile yepyeni bir hane
      // kurardı, köy durmadan yeni ailelere bölünürdü.
      surname: '',
      male: male,
      personalitySeed: pseed,
      startCol: sx,
      startRow: sy,
      lifespanDays: _rollLifespan(),
      // "Yetişkin köylü katıldı" — ageDays set edilmezse 0 kalıp BEBEK olarak
      // beliriyordu (çocuk ölçeği + meslek edinemez): niyetle çelişki. Genç bir
      // yetişkin olarak gelsin.
      ageDays: kAdultStartDay + _rng.nextDouble() * 1.5,
    );
    if (house != null) {
      v.homeBuilding = house;
      final adults =
          _villagers
              .where(
                (p) => p.homeBuilding == house && p.lifeStage.hasProfession,
              )
              .toList()
            ..shuffle(_rng);
      for (final p in adults.take(2)) {
        v.parents.add(p);
        p.children.add(v);
      }
    }
    // Soy ERKEK üzerinden taşınır: baba varsa onun soyadı, yoksa hane büyüğünün,
    // o da yoksa köyün soyu. Böylece köyde doğan herkes mevcut aileye katılır —
    // yeni haneler yalnız DIŞARIDAN gelenlerle (tüccar/mülteci) kurulur.
    v.surname = _patrilinealSurname(v.parents);
    v.appearScaleIn(0.4); // pat belirme yerine yumuşak "belirme"
    _villagers.add(v);

    final kin = v.parents.map((p) => p.name).join(' & ');
    _showNotification(
      Voice.say(
        v.parents.isEmpty ? _kJoinPool : _kJoinFamilyPool,
        _voice(
          v,
          seed: _stableSeed('katıl${v.name}', _dayCount + _villagers.length),
          extra: {'aile': kin},
        ),
      ),
    );
    _lifeEvent(v, 'Köye katıldı', icon: '🚶');
    v.lastStageSeen = v.lifeStage;
  }

  /// Doğal doğum — anne+baba'dan bebek üretir, parents ref'leri kurulur,
  /// evin yakınında spawn. Anne fertilityDays resetlenir. Maliyet yok.
  /// Bebek `LifeStage.child` evresinde — büyüdükçe `hasProfession` olur.
  void _spawnBabyFromParents(VillagerEntity mother, VillagerEntity father) {
    final home = mother.homeBuilding as BuildingEntity?;
    if (home == null) return;

    // Kişilik tohumu önce: bebeğin içindeki çağrı (meslek eğilimi) bundan doğar.
    final pseed = _rng.nextInt(0x7FFFFFFF);
    final calling = _callingForSeed(pseed);
    // Meslek önceliği: (1) Zanaat yönlendirmesi köyün eksik mesleğine çeker,
    // (2) Çıraklık ana-baba zanaatına çeker, (3) yoksa kendi çağrısı. İlk ikisi
    // çağrıyla çatışırsa kırgınlık doğurur (Faz 2). Her biri 2/3 olasılıkla
    // baskın — soy/yönlendirme tam tekel kurmasın, çağrıya hep bir pencere kalsın.
    final scarce = _policies.tradeGuidance ? _scarcestTrade() : null;
    final VillagerType type;
    if (scarce != null && _rng.nextInt(3) != 0) {
      type = scarce;
    } else if (_policies.apprenticeship && _rng.nextInt(3) != 0) {
      type = _rng.nextBool() ? mother.type : father.type;
    } else {
      type = calling;
    }
    final male = _rng.nextBool();
    final (sx, sy) = _nearestLand(
      home.col + home.cols / 2.0,
      home.row + home.rows.toDouble(),
    );
    final baby = VillagerEntity(
      type: type,
      name: randomVillagerName(_rng, male: male),
      // Hane mirası: baba tarafının hanesi (yoksa anne) → "her soy bir hane".
      surname: father.surname.isNotEmpty ? father.surname : mother.surname,
      male: male,
      personalitySeed: pseed,
      startCol: sx,
      startRow: sy,
      lifespanDays: _rollLifespan(),
      // ageDays = 0 → LifeStage.child evresinde başlar
    );
    baby.homeBuilding = home;
    baby.parents.addAll([mother, father]);
    mother.children.add(baby);
    father.children.add(baby);
    mother.birthCount++;
    father.birthCount++;
    // KAN DAVASI mirası: bebek ebeveynlerinin kan düşmanlarını devralır;
    // düşmanlar da yeni doğanı düşman belleğine ekler → vendetta nesil atlar.
    final inherited = {...mother.bloodEnemies, ...father.bloodEnemies};
    for (final e in inherited) {
      if (e.isDying) continue;
      baby.bloodEnemies.add(e);
      e.bloodEnemies.add(baby);
    }
    _villagers.add(baby);
    kProbeBirths++; // prova sayacı — doğum yolunun gerçekten koştuğunun kanıtı

    // Doğum sevinci — GÖVDE DİLİ (baş-üstü ✨/🎉/❤️ ikonları YOK): anne/baba
    // kutlar, komşular dönüp bakar, bebek yumuşakça "belirir" (appearScaleIn).
    baby.appearScaleIn(); // tek karede pat belirme yerine küçükten süzülerek gelir
    mother.feel(NpcEmotion.joy, 5, moodDelta: 0.15);
    father.feel(NpcEmotion.love, 5, moodDelta: 0.12);
    _reactNearby(sx, sy, 5.0, NpcEmotion.joy, 4.0, moodDelta: 0.05);
    nudgeMorale(0.05); // görünür mutlu olay → moral göstergesini hafif iter

    final ctx = _voice(
      mother,
      other: father,
      seed: _stableSeed('doğum${baby.name}', _dayCount),
      extra: {'bebek': baby.name},
    );
    _showNotification(Voice.say(_kBirthPool, ctx));
    AudioManager.instance.playSfx(Sfx.birthJoy);
    _award('first_birth', 'Köyün ilk bebeği dünyaya geldi', '👶');
    // Yaşam öyküsü — bebeğin doğumu + ebeveynlerin yeni çocuğu (kuru, kısa).
    _lifeEvent(baby, 'Dünyaya geldi', icon: '👶', milestone: true);
    final line = Voice.say(_kBirthLifePool, ctx);
    _lifeEvent(mother, line, icon: '👶');
    _lifeEvent(father, line, icon: '👶');
    baby.lastStageSeen = baby.lifeStage; // child — spurious geçiş olayını önle
  }

  /// Misafirperverlik politikasıyla periyodik tetiklenir: bir gezgin
  /// haritanın kenarında doğar, boş bir eve yerleşir. Aile bağı yok
  /// (yapayalnız yetişkin gelir). Notification çağrılır.
  void _spawnMigrant() {
    // Boş ev seç
    BuildingEntity? house;
    for (final b in _buildings) {
      final f = b.fn;
      if (f == null || f.role != BuildingRole.housing) continue;
      final occ = _villagers.where((v) => v.homeBuilding == b).length;
      if (occ < f.housingCapacity) {
        house = b;
        break;
      }
    }
    if (house == null) return; // boş yatak yoksa zaten gelmez

    // Edge spawn pos — kenar randomu
    final edge = _rng.nextInt(4);
    late double sx, sy;
    switch (edge) {
      case 0:
        sx = _rng.nextDouble() * (kCols - 4) + 2;
        sy = 1;
      case 1:
        sx = kCols - 2.0;
        sy = _rng.nextDouble() * (kRows - 4) + 2;
      case 2:
        sx = _rng.nextDouble() * (kCols - 4) + 2;
        sy = kRows - 2.0;
      default:
        sx = 1;
        sy = _rng.nextDouble() * (kRows - 4) + 2;
    }
    final (lx, ly) = _nearestLand(sx, sy);

    // Meslek = içindeki çağrı (kişilik tohumundan).
    final pseed = _rng.nextInt(0x7FFFFFFF);
    final type = _callingForSeed(pseed);
    final male = _rng.nextBool();
    // Yetişkin başlasın — bebek değil, hayatta tecrübeli (göç anlamlı olsun).
    final ageDays = 20.0 + _rng.nextDouble() * 30.0;
    final migrant = VillagerEntity(
      type: type,
      name: randomVillagerName(_rng, male: male),
      surname: randomVillagerSurname(_rng),
      male: male,
      personalitySeed: pseed,
      startCol: lx,
      startRow: ly,
      lifespanDays: _rollLifespan(),
      ageDays: ageDays,
    );
    migrant.homeBuilding = house;
    _villagers.add(migrant);
    // Uyum süreci bedeli — köy 2 gün boyunca −%3 moral.
    pushPolicyMorale(-0.03, 2.0);
    _showNotification(
      Voice.say(
        _kMigrantPool,
        _voice(migrant, seed: _stableSeed('göç${migrant.name}', _dayCount)),
      ),
    );
    // Dışarıdan kanalı — gelen kişi köyün bilmediği bir zanaat taşıyorsa, onu
    // köye kazandırır (keşif bildirimi göç bildiriminin üstüne yazar).
    _discoverCallingCraft(migrant, _CraftSource.migrant);
  }

  /// DIŞARIYA NİKÂH — yalnız kalmış bir yetişkine dışarıdan eş çağırır.
  ///
  /// Köy TEK SOYLA kurulur ve soy erkek üzerinden taşınır; yeni hane yalnız
  /// dışarıdan gelir. [_spawnMigrant] rastgele bir yabancıyı boş bir eve
  /// yerleştirir — bu ise BELİRLİ bir yalnızın damına, karşı cinsten ve kendi
  /// soyadıyla birini getirir. Yönetişim makinesi N-hane üstünde döndüğü için
  /// fermanın asıl kazancı budur: defterde yeni bir ad, masada yeni bir reis.
  ///
  /// Uygun yalnız yoksa (herkes eşli ya da yatak yok) sessizce vazgeçer.
  bool _spawnMarriageMigrant() {
    // Ev → yetişkin sakinler (tek pass) — "yalnız mı" bunun üstünden okunur.
    final adultsByHome = <Object, List<VillagerEntity>>{};
    for (final v in _villagers) {
      if (v.lifeStage != LifeStage.adult) continue;
      final h = v.homeBuilding;
      if (h == null) continue;
      (adultsByHome[h] ??= []).add(v);
    }

    VillagerEntity? lonely;
    BuildingEntity? home;
    for (final v in _villagers) {
      if (v.lifeStage != LifeStage.adult || v.isDying) continue;
      final h = v.homeBuilding as BuildingEntity?;
      if (h == null) continue;
      final f = h.fn;
      if (f == null) continue;
      final mates = adultsByHome[h] ?? const <VillagerEntity>[];
      // Evinde uygun (karşı cins + kan bağı yok) bir eş var mı?
      final paired = mates.any(
        (c) =>
            !identical(c, v) &&
            c.isMale != v.isMale &&
            !v.parents.contains(c) &&
            !v.children.contains(c) &&
            !c.parents.any(v.parents.toSet().contains),
      );
      if (paired) continue;
      if (mates.length >= f.housingCapacity) continue; // gelinin yatağı yok
      lonely = v;
      home = h;
      break;
    }
    if (lonely == null || home == null) return false;

    final (lx, ly) = _nearestLand(
      home.col + home.cols / 2.0,
      home.row + home.rows / 2.0,
    );
    final pseed = _rng.nextInt(0x7FFFFFFF);
    final male = !lonely.isMale; // eş karşı cinsten gelir
    final spouse = VillagerEntity(
      type: _callingForSeed(pseed),
      name: randomVillagerName(_rng, male: male),
      // Kendi soyadıyla gelir — köye yeni bir hane girsin (tek soy kırılır).
      surname: randomVillagerSurname(_rng),
      male: male,
      personalitySeed: pseed,
      startCol: lx,
      startRow: ly,
      lifespanDays: _rollLifespan(),
      ageDays: 20.0 + _rng.nextDouble() * 22.0,
    );
    spouse.homeBuilding = home;
    _villagers.add(spouse);
    // Nikâh göçü uyum bedeli ödemez — bu bir yabancının sızması değil, köyün
    // kendi çağırdığı bir gelin/damat. Karşılığı ılık bir moral.
    pushPolicyMorale(0.04, 3.0);
    lonely.feel(NpcEmotion.joy, 6.0, moodDelta: 0.16);
    spouse.feel(NpcEmotion.content, 5.0, moodDelta: 0.10);
    final ctx = _voice(
      spouse,
      other: lonely,
      seed: _stableSeed('nikâh${spouse.name}', _dayCount),
    );
    _showNotification(
      Voice.say(const [
        '👰 {ad} kervanla geldi; {öteki-in} ocağına gelin/damat oldu.',
        '👰 {öteki} artık yalnız değil — {ad} kendi adıyla köye yerleşti.',
      ], ctx),
    );
    _chronicle(
      Voice.say(const [
        '{ad} kervanla gelip {öteki} ile yuva kurdu; köye yeni bir ad girdi.',
        '{öteki-in} ocağına kervanla bir eş geldi: {ad}.',
      ], ctx),
      icon: '👰',
      milestone: true,
    );
    _discoverCallingCraft(spouse, _CraftSource.migrant);
    return true;
  }

  /// Doğa dostu politikası: kesilen ağacın yakınına bir fidan dik.
  /// 1-3 tile yarıçaplı candidate ara, ilk uygun tile'a fidan kondur.
  /// Uygun = grid içinde, su/bina/maden/ağaç/yol değil.
  void _plantSaplingNear(int felledCol, int felledRow) {
    final treeSet = {for (final t in _trees) (t.col, t.row)};
    for (int attempt = 0; attempt < 12; attempt++) {
      final dc = _rng.nextInt(5) - 2; // -2..+2
      final dr = _rng.nextInt(5) - 2;
      if (dc == 0 && dr == 0) continue;
      final c = felledCol + dc;
      final r = felledRow + dr;
      if (c < 1 || c >= kCols - 1 || r < 1 || r >= kRows - 1) continue;
      if (_obstacles.contains((c, r))) continue;
      if (treeSet.contains((c, r))) continue;
      if (_forbiddenForTrees.contains((c, r))) continue;
      // Fidan kalıcı bir yüzeydir; altında eski decor bırakma.
      _clearDecorTile(c, r);
      _trees.add(
        TreeEntity(col: c, row: r, type: TreeType.pine, isGrowing: true),
      );
      return;
    }
  }

  /// İnşaat tamamlandığında çalışır — bina tipine özel aksiyonlar.
  /// FERMANLA DİKİLEN YAPI — bir hüküm "kurula" diyorsa köy onu diker.
  ///
  /// Oyuncu menüsünden geçmez, zanaat beklemez (buyruk zanaat sormaz) ve kaynak
  /// da istemez: hükmün bedeli kendi `seal`'inde yazılıdır. Bunun olmadığı
  /// sürece "köyün ortasına bir dergâh kurula" diyen ferman dünyada hiçbir şey
  /// değiştirmiyordu — hüküm metniyle sahne arasındaki boşluğu bu kapatır.
  ///
  /// Merkezden dışa doğru halka halka ilk uygun yeri arar; yer bulunamazsa null
  /// döner (köy sıkışmışsa hüküm binasız kalır, çağıran sessizce geçer).
  BuildingEntity? _raiseDecreedBuilding(BuildingType type, {int maxRing = 14}) {
    final (cc, cr) = _villageCenter();
    for (int ring = 0; ring <= maxRing; ring++) {
      for (int dc = -ring; dc <= ring; dc++) {
        for (int dr = -ring; dr <= ring; dr++) {
          // Yalnız halkanın KENARI — içi önceki turlarda zaten tarandı.
          if (ring > 0 && dc.abs() != ring && dr.abs() != ring) continue;
          final c = cc + dc, r = cr + dr;
          if (!_isValidPlacement(c, r, type, ignoreCraft: true)) continue;
          final b = BuildingEntity(type: type, col: c, row: r);
          _buildings.add(b);
          _onBuildingCompleted(
            BuildOrder(type: type, col: c, row: r)..completed = true,
          );
          // Doğrudan yerleştirmede topology hook tetiklenmez (bkz.
          // _buildLivingVillage) — anchor slot'larını elle tazele.
          _anchorSystem.rebuild(_buildings);
          return b;
        }
      }
    }
    return null;
  }

  void _onBuildingCompleted(BuildOrder o) {
    final building = _buildings.firstWhere(
      (b) => b.col == o.col && b.row == o.row && b.type == o.type,
      orElse: () => BuildingEntity(type: o.type, col: o.col, row: o.row),
    );
    final footprint = kBuildingMeta[o.type]!;
    // Doğrudan kurulan/dev/referans yapılar `_doPlace` kapısını atlar;
    // tamamlanma kancası ikinci emniyet ağıdır. Bina ve spawn-pop FX'i
    // aynı tile'daki eski dekorla hiçbir zaman birlikte yaşamaz.
    _clearDecorFootprint(o.col, o.row, footprint.cols, footprint.rows);
    // _BuildingDrawable spawn-pop animasyonu (ilk ~0.6s scale + toz) için.
    building.spawnTime = _time;

    // Yeni bina dikildi — civardaki köylüler hayranlıkla dönüp bakar (gövde
    // dili; baş üstü emoji yok). Yerel canlılık dalgası.
    _reactNearby(
      o.col + 1.0,
      o.row + 1.0,
      6.0,
      NpcEmotion.wonder,
      3.5,
      moodDelta: 0.04,
    );

    switch (o.type) {
      case BuildingType.firepit:
        _hasFire = true;
        _firepitBuilding = building;
        _spawnStartingNPCs(building);
        // Açılış akışı: ateş yeri seçildi → ilk ateş. Eskiden burada tam ekran
        // sinematik vardı; kaldırıldı. Tam ekran film artık yalnız TONU
        // DEĞİŞTİREN üç ana ana saklı (kuruluş / imparatorluk / hesaplaşma).
        // İlk ateş zaten dünyada anlatılabilir bir an: kadro ateşin başına
        // toplanır, köy hayranlıkla bakar, sarsıntı ocağı işaret eder.
        if (_firstFirePending) {
          _firstFirePending = false;
          addCameraShake(3.0, dur: 0.5);
          _feelVillage(NpcEmotion.wonder, 6.0, 0.08);
          _gatherAtFire(kGameDaySeconds * 0.25, max: 6);
          _chronicle(
            'İlk ateş yakıldı. Köyün ocağı tütmeye başladı.',
            icon: '🔥',
            milestone: true,
          );
          _showNotification(
            '🔥 İlk ateş yandı. Yakıtı odunla beslenir; stokta biraz odun bırak.',
          );
        } else {
          _showNotification('Ateş yakıldı! Köy kurulmaya başlıyor...');
        }

      case BuildingType.tent:
      case BuildingType.woodenHouse:
      case BuildingType.stoneHouseBlue:
      case BuildingType.stoneHouseGreen:
      case BuildingType.manor:
        // Yeni barınak — evsizleri kapasitesi kadar içine al. Çadır 1, ev 2,
        // taş konut 3, konak 4 (housingCapacity).
        final cap = building.fn?.housingCapacity ?? 0;
        int assigned = 0;
        for (final v in _villagers) {
          if (assigned >= cap) break;
          if (v.homeBuilding == null) {
            v.homeBuilding = building;
            assigned++;
          }
        }
        if (assigned > 0) {
          final where = o.type == BuildingType.tent ? 'çadıra' : 'eve';
          _showNotification('$assigned köylü $where yerleşti.');
        }
        // Ateş bir başlangıç noktasıdır; köy, ilk barınak tamamlanınca gerçek
        // bir yerleşime dönüşür. İsim istemini ateş anından buraya taşıyoruz.
        if (o.type == BuildingType.tent &&
            _charterTier == 0 &&
            _villageName == 'Köy' &&
            !_villageNamePromptOpen) {
          setStateHere(() => _villageNamePromptOpen = true);
        }

      case BuildingType.lumberCamp:
        // (Oduncu artık atanmış köylü — _syncJobWorkforce kampa en yakın boş
        // köylüyü oduncu yapar; bölge yönetimi _tickLumberCampManage'de.)
        // Kuruluşta iki saniyelik normal kadro taramasını bekletme: kulübe
        // kalktığı anda bir sonraki tick oduncuyu seçsin.
        if (_foundingModeActive) _jobSyncCd = 0;
        break;

      case BuildingType.mineBuilding:
        final meta = kBuildingMeta[o.type]!;
        for (final n in _mineNodes) {
          if (n.col >= o.col &&
              n.col < o.col + meta.cols &&
              n.row >= o.row &&
              n.row < o.row + meta.rows) {
            n.isMarkedForMining = true;
          }
        }
      // (Madenci artık ayrı avatar değil — _syncJobWorkforce boş bir köylüyü
      // madenci olarak atar; bkz. scene_jobs _runMiner.)

      case BuildingType.fisherCabin:
        // (Balıkçı artık atanmış köylü — _runFisher.)
        break;

      case BuildingType.barn:
        // Ağıl BOŞ kurulur — inek/koyun bina ile gelmez (oyuncu panelden satın
        // alır). Çoban artık atanmış köylü — _syncJobWorkforce ağıla en yakın
        // boş köylüyü çoban yapar (scene_jobs _runShepherd sağar).
        break;

      case BuildingType.floristCottage:
        _spawnFlowerGardenDecor(o);
      // (Çiçekçi artık atanmış köylü — _runFlorist bahçeyi sular.)

      case BuildingType.chickenCoop:
        // Kümes BOŞ kurulur — tavuklar bina ile gelmez; oyuncu panelden satın
        // alır ([_buyAnimal]). Yumurta görünür entity + çatlama (scene_tick).
        break;

      case BuildingType.townhall:
        // İlk Belediye, Kanunname'nin ilerleme eşiğidir. O ana dek yasa
        // gündemi taranmadı; mevcut dünya şartlarını sessizce başlangıç
        // gündemi olarak kaydet ki kilit açılır açılmaz bildirim yağmasın.
        _lawCtxCache = null;
        if (_villageMemory.add('institution.townhall')) {
          final oralCount = OralTradition.decisionCount(_villageMemory);
          _lawSeen.addAll(
            LawBook.openAgenda(_policies.sealed, _lawContext).map((l) => l.id),
          );
          _lawSeeded = true;
          _chronicle(
            oralCount > 0
                ? 'Belediye kuruldu. Ateş başında verilmiş $oralCount söz, '
                      'Kanunname’ye dayanak oldu.'
                : 'Belediye kuruldu. Köyün mührü yerini buldu; Kanunname açıldı.',
            icon: '🏛',
            milestone: true,
          );
          _showNotification(
            oralCount > 0
                ? '🏛 Belediye kuruldu — $oralCount ocak sözü artık yazıya geçebilir.'
                : '🏛 Belediye kuruldu — Kanunname artık Köy Defteri’nde.',
          );
        }
        break;

      case BuildingType.monument:
        building.inscription = monumentInscription(
          regimeTitle: _regimeIdentity.title,
          houseIdentity: _houses.identityName,
          day: _dayCount,
        );
        _chronicle(
          'Anıta kazındı: ${building.inscription}.',
          icon: '🏛',
          milestone: true,
        );

      case BuildingType.caravanserai:
        // Devam eden ziyaret yoksa Hanın sıklaştırıcı etkisi mevcut bekleme
        // süresine de hemen yansısın; ilk sonucu bir tam döngü gecikmesin.
        final firstHan =
            _buildings
                .where((b) => b.type == BuildingType.caravanserai)
                .length ==
            1;
        if (firstHan && _merchants.isEmpty && _merchantTimer > 0) {
          _merchantTimer = merchantVisitGap(
            _merchantTimer,
            hasCaravanserai: true,
          );
        }

      default:
        break;
    }

    // Yeşil köy politikası: tamamlanan her binanın çevresine 2-4 küçük decor
    // (çiçek/çalı) serpiştir. Florist cottage zaten kendi geniş bahçesini
    // yaptığı için onu atla.
    if (_policies.greenVillage && o.type != BuildingType.floristCottage) {
      _sprinkleGreenAround(building);
    }
  }

  /// Yeşil köy: bina çevresine 1-2 küçük bitki vurgusu ekler.
  /// Fazlası her yeni yapıyla katlanıp köyü dekor halısına çeviriyordu.
  void _sprinkleGreenAround(BuildingEntity b) {
    const kinds = [
      DecorKind.daisy,
      DecorKind.buttercup,
      DecorKind.bushSmall,
      DecorKind.clover,
      DecorKind.lavender,
    ];
    final candidates = <(int, int)>[];
    for (int dr = -2; dr <= b.rows + 1; dr++) {
      for (int dc = -2; dc <= b.cols + 1; dc++) {
        final c = b.col + dc;
        final r = b.row + dr;
        if (c < 0 || c >= kCols || r < 0 || r >= kRows) continue;
        if (c >= b.col &&
            c < b.col + b.cols &&
            r >= b.row &&
            r < b.row + b.rows) {
          continue;
        }
        candidates.add((c, r));
      }
    }
    if (candidates.isEmpty) return;
    candidates.shuffle(_rng);
    final pick = 1 + _rng.nextInt(2); // 1-2
    var planted = 0;
    for (final (c, r) in candidates) {
      if (planted >= pick) break;
      final kind = kinds[_rng.nextInt(kinds.length)];
      if (_tryPlantDecor(c, r, kind)) planted++;
    }
  }

  /// Çiçek bahçesi etki alanı içinde RANDOM tile'lara çiçek demeti dağıtır.
  /// Radius içinde 2-4 demetlik bilinçli bir bahçe kurar. Her demet ortak
  /// spacing ve yüzey kuralından geçer; kulübenin asset'indeki çiçeklerle
  /// yarışan ikinci bir çiçek duvarı oluşmaz.
  void _spawnFlowerGardenDecor(BuildOrder o) {
    final meta = kBuildingMeta[BuildingType.floristCottage]!;
    final radius = meta.effectRadius;
    if (radius <= 0) return;

    // Bina merkezi (1×1 footprint'in iç koordinatı)
    final cx = o.col + meta.cols * 0.5;
    final cy = o.row + meta.rows * 0.5;
    final rTiles = radius.ceil();

    // Çiçek türü havuzu — bahçe wildflower karışımı
    const kinds = [
      DecorKind.daisy,
      DecorKind.poppy,
      DecorKind.buttercup,
      DecorKind.lavender,
    ];

    // Etki alanındaki ekilebilir tile'ları topla
    final candidates = <(int, int)>[];
    for (int dr = -rTiles; dr <= rTiles; dr++) {
      for (int dc = -rTiles; dc <= rTiles; dc++) {
        final c = o.col + dc;
        final r = o.row + dr;
        if (c < 0 || c >= kCols || r < 0 || r >= kRows) continue;
        // Bina footprint'i hariç tut — planter yapının kendisinde.
        if (c >= o.col &&
            c < o.col + meta.cols &&
            r >= o.row &&
            r < o.row + meta.rows) {
          continue;
        }
        // Yarıçap içinde mi (Öklid)
        final dx = (c + 0.5) - cx;
        final dy = (r + 0.5) - cy;
        if (dx * dx + dy * dy > radius * radius) continue;
        candidates.add((c, r));
      }
    }
    candidates.shuffle(_rng);

    final pick = (candidates.length * 0.22).round().clamp(2, 4);
    var planted = 0;
    for (final (c, r) in candidates) {
      if (planted >= pick) break;
      final kind = kinds[_rng.nextInt(kinds.length)];
      if (_tryPlantDecor(c, r, kind)) planted++;
    }
  }

  /// Verilen tile herhangi bir bina footprint'inin içinde mi?
  bool _isOccupiedByBuilding(int col, int row) {
    for (final b in _buildings) {
      final m = kBuildingMeta[b.type];
      if (m == null) continue;
      if (col >= b.col &&
          col < b.col + m.cols &&
          row >= b.row &&
          row < b.row + m.rows) {
        return true;
      }
    }
    return false;
  }

  /// NPC'leri su tile'larından kara üzerine taşı (spawn safety).
  void _fixNpcSpawns() {
    void fix(double gx, double gy, void Function(double, double) set) {
      final (nx, ny) = _nearestLand(gx, gy);
      if (nx != gx || ny != gy) set(nx, ny);
    }

    for (final v in _villagers) {
      fix(v.gridX, v.gridY, (x, y) {
        v.gridX = x;
        v.gridY = y;
      });
    }
  }

  /// Test: tek tıkla yaşayan köy. Yeni harita üretir, başlangıç bölgesine
  /// belirli pattern'le binaları kurar, bol kaynak verir, küçük bir tarla
  /// + çiftçi ekler. Firepit'ten 5 başlangıç NPC zaten otomatik doğar.
  void _buildLivingVillage() {
    setStateHere(() {
      _generateWorld();
      _knownCrafts.addAll(Craft.all); // test köyü tüm zanaatları bilir
      _stockpile.wood = 200;
      _stockpile.stone = 150;
      _stockpile.iron = 50;
      _stockpile.coal = 30;
      _stockpile.food = 100;
      _stockpile.gold = 80;

      // Layout — safe area (col 0..20, row 0..16) içinde. (type, col, row).
      const layout = <(BuildingType, int, int)>[
        (BuildingType.firepit, 10, 8),
        (BuildingType.townhall, 12, 4),
        (BuildingType.woodenHouse, 4, 4),
        (BuildingType.woodenHouse, 4, 7),
        (BuildingType.woodenHouse, 4, 10),
        (BuildingType.woodenHouse, 7, 10),
        (BuildingType.tavern, 7, 4),
        (BuildingType.well, 9, 7),
        (BuildingType.warehouse, 16, 9),
        (BuildingType.lamppost, 10, 6),
        (BuildingType.lamppost, 10, 10),
      ];
      for (final (type, col, row) in layout) {
        if (!_isValidPlacement(col, row, type)) continue;
        final b = BuildingEntity(type: type, col: col, row: row);
        _buildings.add(b);
        _onBuildingCompleted(
          BuildOrder(type: type, col: col, row: row)..completed = true,
        );
      }
      // Direkt yerleştirmede topology hook tetiklenmez — anchor slot'ları
      // (kuyu/ateş/bank) + arı sürülerini elle türet.
      _anchorSystem.rebuild(_buildings);
      _rebuildBeeSwarms();

      // Küçük tarla + çiftçi spawn — pazarın yanına (safe area kuzeyinde).
      const farmC1 = 14, farmR1 = 2, farmC2 = 18, farmR2 = 5;
      for (int c = farmC1; c <= farmC2; c++) {
        for (int r = farmR1; r <= farmR2; r++) {
          if (_waterTiles.contains((c, r))) continue;
          bool overlap = false;
          for (final b in _buildings) {
            if (c >= b.col &&
                c < b.col + b.cols &&
                r >= b.row &&
                r < b.row + b.rows) {
              overlap = true;
              break;
            }
          }
          if (!overlap) _farmTiles.add(_devSownTile(c, r));
        }
      }
      // Saha eli otomatik doğmaz — _syncFarmerWorkforce (tick) ilk karede
      // köyün çiftçi kadrosuna göre kadroyu kurar.
      _sanitizeDecorPopulation();
      _fixNpcSpawns();
    });
    _showNotification('🏡 Yaşayan köy kuruldu!');
  }

  /// Görsel showcase — godmode için "her şeyi görmek istiyorum" tek tıkla.
  /// Tüm bina tipleri grid'de yerleşir, ahır+kümes+çiçekçi+barn dolu, her
  /// meslekten en az 1 NPC + bir bilge yaşlı + boş yataklara dolanan NPC'ler.
  /// _buildLivingVillage'in genişletilmiş hali — test odaklı, denge umrunda
  /// değil.
  void _buildShowcaseVillage() {
    setStateHere(() {
      _generateWorld();
      _knownCrafts.addAll(Craft.all); // showcase tüm zanaatları bilir
      _stockpile.wood = 9999;
      _stockpile.stone = 9999;
      _stockpile.iron = 999;
      _stockpile.coal = 999;
      _stockpile.food = 9999;
      _stockpile.gold = 999;

      // Grid layout — tüm bina tipleri, çakışmasız. Dünya 128×128 olduğu için
      // showcase'u (1..22) köşeye değil, kameranın baktığı merkez açıklığa
      // yerleştir. Eski yerleşim köşede kalıyor, capture karesi ise merkezi
      // gösterdiği için bütün bina asset'leri görünmez oluyordu.
      const showOx = kCols ~/ 2 - 11;
      const showOy = kRows ~/ 2 - 9;
      // Showcase bir katalog karesi: yapıların siluetleri okunmalı. Dünya
      // üreticisinin doğal kanopisi aynı merkezde kalabildiği için yalnızca
      // yerleşim kutusunu temizle; kutunun dışındaki orman/nehir atmosferi
      // korunur.
      bool inShowcaseClear(int c, int r) =>
          c >= showOx - 2 &&
          c <= showOx + 22 &&
          r >= showOy - 2 &&
          r <= showOy + 17;
      _trees.removeWhere((t) => inShowcaseClear(t.col, t.row));
      _reeds.removeWhere(
        (r) => inShowcaseClear(r.col, r.row) || inShowcaseClear(r.col2, r.row2),
      );
      const layout = <(BuildingType, int, int)>[
        // Sıra 1: ateş yeri + temel
        (BuildingType.firepit, 10, 2),
        (BuildingType.well, 9, 4),
        (BuildingType.lamppost, 12, 2),
        (BuildingType.lamppost, 8, 2),
        // Sıra 2: evler — solda ev kümesi
        (BuildingType.woodenHouse, 2, 4),
        (BuildingType.woodenHouse, 2, 7),
        (BuildingType.woodenHouse, 2, 10),
        (BuildingType.woodenHouse, 2, 13),
        // Üretim — orta sütun
        (BuildingType.lumberCamp, 5, 4),
        (BuildingType.fisherCabin, 5, 7),
        (BuildingType.mineBuilding, 5, 10),
        (BuildingType.chickenCoop, 5, 13),
        // Civic — sağ sütun
        (BuildingType.townhall, 11, 6),
        (BuildingType.tavern, 11, 10),
        (BuildingType.market, 15, 4),
        (BuildingType.warehouse, 15, 8),
        // Ahır + Ağıl — alt sıra
        (BuildingType.stable, 15, 12),
        (BuildingType.barn, 19, 4),
        // Diğer
        (BuildingType.mill, 19, 8),
        (BuildingType.floristCottage, 19, 12),
        // Kilise — rahibin işyeri (iş döngüsü testi için şart)
        (BuildingType.church, 11, 14),
        // Arı kovanı çiçekçinin yanına — bal sinerjisi (etki alanı çiçekleri).
        (BuildingType.beehive, 17, 13),
        // Ekstra fenerler
        (BuildingType.lamppost, 8, 8),
        (BuildingType.lamppost, 14, 8),
      ];
      // Arazi (ağaç/su) bazı slotları geçersiz kılabilir → o bina SESSİZCE
      // atlanıyordu ve showcase "her tip hazır" sözünü tutmuyordu (değirmen/
      // taverna/kilise böyle kaybolup iş döngüsü testini yanılttı). Artık
      // atlananlar sayılıp bildirimde açıkça söyleniyor.
      _showcaseSkipped.clear();
      for (final (type, localCol, localRow) in layout) {
        final col = showOx + localCol;
        final row = showOy + localRow;
        if (!_isValidPlacement(col, row, type)) {
          _showcaseSkipped.add(type.name);
          continue;
        }
        final b = BuildingEntity(type: type, col: col, row: row);
        _buildings.add(b);
        _onBuildingCompleted(
          BuildOrder(type: type, col: col, row: row)..completed = true,
        );
      }
      // Direkt yerleştirmede topology hook tetiklenmez — anchor slot'ları
      // (kuyu/ateş/bank) + arı sürülerini elle türet.
      _anchorSystem.rebuild(_buildings);
      _rebuildBeeSwarms();

      // Tarla + çiftçiler — pazarın üstü
      const farmC1 = 14, farmR1 = 1, farmC2 = 20, farmR2 = 3;
      for (int localC = farmC1; localC <= farmC2; localC++) {
        for (int localR = farmR1; localR <= farmR2; localR++) {
          final c = showOx + localC;
          final r = showOy + localR;
          if (_waterTiles.contains((c, r))) continue;
          bool overlap = false;
          for (final b in _buildings) {
            if (c >= b.col &&
                c < b.col + b.cols &&
                r >= b.row &&
                r < b.row + b.rows) {
              overlap = true;
              break;
            }
          }
          if (!overlap) _farmTiles.add(_devSownTile(c, r));
        }
      }
      // Saha eli _syncFarmerWorkforce (tick) tarafından kurulur.
      _sanitizeDecorPopulation();
      _fixNpcSpawns();

      // Ekstra köylüler — yataklar dolsun, sokakta canlılık olsun.
      // _spawnGrownVillager townhall ile çalışır.
      final townhall = _buildings.firstWhere(
        (b) => b.type == BuildingType.townhall,
        orElse: () => _buildings.first,
      );
      for (int i = 0; i < 10; i++) {
        _spawnGrownVillager(townhall);
      }

      // Bir yaşlı spawn et — bilge yapılabilir hale gelsin.
      for (int i = 0; i < 2; i++) {
        _spawnGrownVillager(townhall);
        _villagers.last.ageDays = kElderStartDay + 1.0;
      }

      // Meslek çeşitliliğini GARANTİLE — normalde meslek çağrıdan doğar, yani
      // showcase'te rastgele dağılır ve yeni meslekler hiç çıkmayabilir. Test
      // yatağı olduğu için her yeni mesleği en az bir köylüye elle ver.
      const showcaseTrades = [
        VillagerType.shepherd,
        VillagerType.hunter,
        VillagerType.miller,
        VillagerType.innkeeper,
        VillagerType.priest,
        VillagerType
            .guard, // devriye + suçüstü yakalama (scene_crime) test yatağı
      ];
      // Yetişkin köylü sayısı yetmezse ek doğur — 5 mesleğin HEPSİ temsil edilsin
      // (aksi halde showcase rastgele biçimde bazı meslekleri hiç göstermez).
      while (_villagers.where((v) => v.hasProfession && !v.isDying).length <
          showcaseTrades.length) {
        final before = _villagers.length;
        _spawnGrownVillager(townhall);
        if (_villagers.length == before) {
          break; // doğuramıyor → sonsuz döngü olmasın
        }
      }
      final grown = _villagers
          .where((v) => v.hasProfession && !v.isDying)
          .toList();
      for (int i = 0; i < showcaseTrades.length && i < grown.length; i++) {
        grown[i].switchProfession(showcaseTrades[i]);
      }

      // Ağıla sürü koy — çobanın bakacak hayvanı olsun (ağıl normalde BOŞ kurulur).
      final barn = _buildings
          .where((b) => b.type == BuildingType.barn)
          .firstOrNull;
      if (barn != null) {
        for (int i = 0; i < 5; i++) {
          final (sx, sy) = _nearestLand(
            barn.col + barn.cols / 2.0,
            barn.row + barn.rows.toDouble(),
          );
          _cows.add(
            AnimalEntity(
              kind: i < 2 ? AnimalKind.cow : AnimalKind.sheep,
              barnCol: barn.col,
              barnRow: barn.row,
              startCol: sx + (_rng.nextDouble() - 0.5) * 1.6,
              startRow: sy + (_rng.nextDouble() - 0.5) * 1.6,
              isMale: i.isEven,
              ageDays: AnimalEntity.kAnimalAdultDay + _rng.nextDouble() * 2.0,
              lifespanDays:
                  AnimalEntity.kAnimalElderDay + 8.0 + _rng.nextDouble() * 12.0,
            ),
          );
        }
      }
    });
    _showNotification(
      _showcaseSkipped.isEmpty
          ? '🎭 Showcase köyü kuruldu — her tip görsel test için hazır'
          : '🎭 Showcase kuruldu — ARAZİ YÜZÜNDEN KURULAMADI: '
                '${_showcaseSkipped.join(", ")}',
    );
  }
}
