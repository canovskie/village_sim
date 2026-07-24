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
  static const _kBirthLifePool = [
    'Çocuğu oldu: {bebek}',
    '{bebek} doğdu',
  ];
  static const _kMigrantPool = [
    '🚶 {ad} yolun tozuyla geldi, boş yatağa yerleşti. Köyün ona alışması sürer.',
    '🚶 {ad} kapıyı çaldı ve kaldı. Yabancıya ısınmak zaman ister.',
    '🚶 {ad} köye yerleşti. İlk günler herkes birbirini süzüyor.',
  ];

  /// Ahır/kümes panelinden hayvan satın al — bina BOŞ kurulur, sürü buradan
  /// kurulur. Altın harcar; kapasiteyi aşamaz. Cinsiyet akıllı: o binada erkek
  /// yoksa erkek gelir (çift kurulup üreyebilsin), varsa dişi. Genç yetişkin
  /// doğar (uzun üreme/ömür penceresi).
  void _buyAnimal(BuildingEntity b, AnimalKind kind) {
    final cap = kAnimalBarnCap[kind] ?? 5;
    final living = _cows
        .where((c) =>
            !c.isDying &&
            c.kind == kind &&
            c.barnCol == b.col &&
            c.barnRow == b.row)
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
    final (sx, sy) =
        _nearestLand(b.col + b.cols / 2.0, b.row + b.rows.toDouble());
    setStateHere(() {
      _stockpile.gold -= cost;
      _cows.add(AnimalEntity(
        kind: kind,
        barnCol: b.col,
        barnRow: b.row,
        startCol: sx + (_rng.nextDouble() - 0.5) * 0.6,
        startRow: sy + (_rng.nextDouble() - 0.5) * 0.6,
        isMale: male,
        ageDays: AnimalEntity.kAnimalAdultDay + _rng.nextDouble() * 2.0,
        lifespanDays:
            AnimalEntity.kAnimalElderDay + 8.0 + _rng.nextDouble() * 12.0,
      ));
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
      callingFor(Personality.fromSeed(seed, VillagerType.farmer), seed);

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
    final scarce = [for (final e in count.entries) if (e.value == lo) e.key];
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

  void _spawnStartingNPCs(BuildingEntity firepit) {
    final cx = firepit.col + 0.5;
    final cy = firepit.row + 0.5;

    final types = [
      VillagerType.farmer,
      VillagerType.merchant,
      VillagerType.blacksmith,
      VillagerType.guard,
      VillagerType.priest,
    ];
    // KÖY TEK AİLEYLE KURULUR (kullanıcı kararı): beş kurucu da aynı soyadı
    // taşır → tek hane. Eskiden beş AYRI soyad vardı ve oyun daha ilk günden
    // "aileler arası denge" oyununa zorluyordu. Kurucular birbirinin kan bağı
    // DEĞİL (parents boş) → aralarında çift kurulabilir; kur/üreme sistemleri
    // zaten ebeveyn/çocuk/kardeş engelini soyada değil KAN BAĞINA bakarak koyar.
    final lineage = randomVillagerSurname(_rng);
    for (int i = 0; i < types.length; i++) {
      final angle = i * (2 * pi / types.length);
      final dist = 1.2 + _rng.nextDouble() * 0.6;
      // Kurucular yetişkin/yaşlı yaşıyla doğar — köy ilk günden işlevsel.
      final founderAge =
          kAdultStartDay + _rng.nextDouble() * (kElderStartDay - kAdultStartDay + 5);
      // Cinsiyet GARANTİLİ karışık (3 erkek / 2 kadın) — rastgele bırakılsaydı
      // kurucu aile tek cinsiyete düşüp soyu hiç devam ettiremeyebilirdi.
      final male = i.isEven;
      final founder = VillagerEntity(
        type: types[i],
        name: randomVillagerName(_rng, male: male),
        surname: lineage,
        male: male,
        // Kurucu kişiliği mesleğiyle uyumlu — çağrı sistemiyle tutarlı köy.
        personalitySeed: _seedForCalling(types[i]),
        startCol: cx + cos(angle) * dist,
        startRow: cy + sin(angle) * dist,
        ageDays: founderAge,
        lifespanDays: _rollLifespan(),
      );
      _villagers.add(founder);
      // Yaşam öyküsü — köyün kuruluş kuşağı (evre geçiş taramasına da kalibre).
      _lifeEvent(founder, 'Köyün kurucularından oldu', icon: '🔥',
          milestone: true);
      founder.lastStageSeen = founder.lifeStage;
    }

    // (İnşaatçı artık ayrı avatar değil — bekleyen sipariş çıkınca boş bir
    // köylü _syncJobWorkforce ile inşaatçı olarak atanır; bkz. scene_jobs.)

    _fixNpcSpawns();
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
    );
    if (house != null) {
      v.homeBuilding = house;
      final adults = _villagers
          .where((p) =>
              p.homeBuilding == house && p.lifeStage.hasProfession)
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
    _villagers.add(v);

    final kin = v.parents.map((p) => p.name).join(' & ');
    _showNotification(Voice.say(
        v.parents.isEmpty ? _kJoinPool : _kJoinFamilyPool,
        _voice(v,
            seed: _stableSeed('katıl${v.name}', _dayCount + _villagers.length),
            extra: {'aile': kin})));
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

    // Doğum sevinci — gövde dili: anne/baba kutlar, komşular dönüp bakar.
    mother.feel(NpcEmotion.joy, 5, moodDelta: 0.15);
    father.feel(NpcEmotion.love, 5, moodDelta: 0.12);
    // Görünür doğum şenliği — parıltı/kutlama baloncukları (juice).
    baby.chatBubbleIcon = '✨';
    baby.chatBubbleTime = 5.0;
    mother.chatBubbleIcon = '🎉';
    mother.chatBubbleTime = 4.0;
    father.chatBubbleIcon = '❤️';
    father.chatBubbleTime = 4.0;
    _reactNearby(sx, sy, 5.0, NpcEmotion.joy, 4.0, moodDelta: 0.05);
    nudgeMorale(0.05); // görünür mutlu olay → moral göstergesini hafif iter

    final ctx = _voice(mother,
        other: father,
        seed: _stableSeed('doğum${baby.name}', _dayCount),
        extra: {'bebek': baby.name});
    _showNotification(Voice.say(_kBirthPool, ctx));
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
    _showNotification(Voice.say(
        _kMigrantPool,
        _voice(migrant,
            seed: _stableSeed('göç${migrant.name}', _dayCount))));
    // Dışarıdan kanalı — gelen kişi köyün bilmediği bir zanaat taşıyorsa, onu
    // köye kazandırır (keşif bildirimi göç bildiriminin üstüne yazar).
    _discoverCallingCraft(migrant, _CraftSource.migrant);
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
      _trees.add(TreeEntity(
        col: c, row: r, type: TreeType.pine, isGrowing: true,
      ));
      return;
    }
  }

  /// İnşaat tamamlandığında çalışır — bina tipine özel aksiyonlar.
  void _onBuildingCompleted(BuildOrder o) {
    final building = _buildings.firstWhere(
      (b) => b.col == o.col && b.row == o.row && b.type == o.type,
      orElse: () => BuildingEntity(type: o.type, col: o.col, row: o.row),
    );
    // _BuildingDrawable spawn-pop animasyonu (ilk ~0.6s scale + toz) için.
    building.spawnTime = _time;

    // Yeni bina dikildi — civardaki köylüler hayranlıkla dönüp bakar (gövde
    // dili; baş üstü emoji yok). Yerel canlılık dalgası.
    _reactNearby(o.col + 1.0, o.row + 1.0, 6.0, NpcEmotion.wonder, 3.5,
        moodDelta: 0.04);

    switch (o.type) {
      case BuildingType.firepit:
        _hasFire = true;
        _firepitBuilding = building;
        _spawnStartingNPCs(building);
        // Açılış akışı: ateş yeri seçildi → kısa "ateş yakma" sinematiği.
        if (_firstFirePending) {
          _firstFirePending = false;
          _playCutscene(kFireLightingCutscene);
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

      case BuildingType.lumberCamp:
        // (Oduncu artık atanmış köylü — _syncJobWorkforce kampa en yakın boş
        // köylüyü oduncu yapar; bölge yönetimi _tickLumberCampManage'de.)
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

  /// Yeşil köy: bina çevresine 2-4 rastgele çiçek/çalı/buttercup decor ekler.
  /// 2-tile radius footprint dışından sample, su/bina/dekor çakışmasız.
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
        if (c >= b.col && c < b.col + b.cols &&
            r >= b.row && r < b.row + b.rows) {
          continue;
        }
        if (_waterTiles.contains((c, r))) continue;
        if (_isOccupiedByBuilding(c, r)) continue;
        if (_decor.any((d) => d.col == c && d.row == r)) continue;
        if (_trees.any((t) => t.col == c && t.row == r)) continue;
        candidates.add((c, r));
      }
    }
    if (candidates.isEmpty) return;
    candidates.shuffle(_rng);
    final pick = 2 + _rng.nextInt(3); // 2-4
    for (int i = 0; i < pick && i < candidates.length; i++) {
      final (c, r) = candidates[i];
      _decor.add(DecorEntity(
        col: c,
        row: r,
        kind: kinds[_rng.nextInt(kinds.length)],
        variant: _rng.nextInt(3),
        jitterX: (_rng.nextDouble() - 0.5) * 0.5,
        jitterY: (_rng.nextDouble() - 0.5) * 0.5,
        swaySeed: _rng.nextInt(1000),
      ));
    }
  }

  /// Çiçek bahçesi etki alanı içinde RANDOM tile'lara çiçek demeti dağıtır.
  /// "Aşırı kalabalık olmasın" hedefi: radius içindeki uygun tile'ların
  /// yalnızca yaklaşık %35'i çiçeklenir, gerisi çim kalır → boşluklu, doğal.
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
        // Bina footprint'i hariç tut — planter ortayı kapsıyor zaten
        if (c == o.col && r == o.row) continue;
        // Yarıçap içinde mi (Öklid)
        final dx = (c + 0.5) - cx;
        final dy = (r + 0.5) - cy;
        if (dx * dx + dy * dy > radius * radius) continue;
        // Su / bina / mevcut dekor / ağaç çakışması yok
        if (_waterTiles.contains((c, r))) continue;
        if (_isOccupiedByBuilding(c, r)) continue;
        if (_decor.any((d) => d.col == c && d.row == r)) continue;
        if (_trees.any((t) => t.col == c && t.row == r)) continue;
        candidates.add((c, r));
      }
    }
    candidates.shuffle(_rng);

    // Yalnızca yaklaşık 1/3'ünü çiçeklendir → seyrek, doğal hava.
    // Üst limit 7: bahçe etrafı tıka basa dolmasın.
    final pick = (candidates.length * 0.35).round().clamp(3, 7);
    for (int i = 0; i < pick && i < candidates.length; i++) {
      final (c, r) = candidates[i];
      _decor.add(DecorEntity(
        col: c,
        row: r,
        kind: kinds[_rng.nextInt(kinds.length)],
        variant: _rng.nextInt(3),
        jitterX: (_rng.nextDouble() - 0.5) * 0.5,
        jitterY: (_rng.nextDouble() - 0.5) * 0.5,
        swaySeed: _rng.nextInt(1000),
      ));
    }
  }

  /// Verilen tile herhangi bir bina footprint'inin içinde mi?
  bool _isOccupiedByBuilding(int col, int row) {
    for (final b in _buildings) {
      final m = kBuildingMeta[b.type];
      if (m == null) continue;
      if (col >= b.col && col < b.col + m.cols &&
          row >= b.row && row < b.row + m.rows) {
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
      fix(v.gridX, v.gridY, (x, y) { v.gridX = x; v.gridY = y; });
    }
    for (final f in _farmers) {
      fix(f.gridX, f.gridY, (x, y) { f.gridX = x; f.gridY = y; });
    }
    for (final w in _woodcutters) {
      fix(w.gridX, w.gridY, (x, y) { w.gridX = x; w.gridY = y; });
    }
    for (final m in _miners) {
      fix(m.gridX, m.gridY, (x, y) { m.gridX = x; m.gridY = y; });
    }
    for (final b in _builders) {
      fix(b.gridX, b.gridY, (x, y) { b.gridX = x; b.gridY = y; });
    }
    for (final f in _fishers) {
      fix(f.gridX, f.gridY, (x, y) { f.gridX = x; f.gridY = y; });
    }
  }

  /// Test: tek tıkla yaşayan köy. Yeni harita üretir, başlangıç bölgesine
  /// belirli pattern'le binaları kurar, bol kaynak verir, küçük bir tarla
  /// + çiftçi ekler. Firepit'ten 5 başlangıç NPC zaten otomatik doğar.
  void _buildLivingVillage() {
    setStateHere(() {
      _generateWorld();
      _knownCrafts.addAll(Craft.all); // test köyü tüm zanaatları bilir
      _stockpile.wood  = 200;
      _stockpile.stone = 150;
      _stockpile.iron  = 50;
      _stockpile.coal  = 30;
      _stockpile.food  = 100;
      _stockpile.gold  = 80;

      // Layout — safe area (col 0..20, row 0..16) içinde. (type, col, row).
      const layout = <(BuildingType, int, int)>[
        (BuildingType.firepit,     10, 8),
        (BuildingType.townhall,    12, 4),
        (BuildingType.woodenHouse,  4, 4),
        (BuildingType.woodenHouse,  4, 7),
        (BuildingType.woodenHouse,  4, 10),
        (BuildingType.woodenHouse,  7, 10),
        (BuildingType.tavern,       7, 4),
        (BuildingType.well,         9, 7),
        (BuildingType.warehouse,   16, 9),
        (BuildingType.lamppost,    10, 6),
        (BuildingType.lamppost,    10, 10),
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
            if (c >= b.col && c < b.col + b.cols &&
                r >= b.row && r < b.row + b.rows) {
              overlap = true; break;
            }
          }
          if (!overlap) _farmTiles.add(_devSownTile(c, r));
        }
      }
      // Saha eli otomatik doğmaz — _syncFarmerWorkforce (tick) ilk karede
      // köyün çiftçi kadrosuna göre kadroyu kurar.
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
      _stockpile.wood  = 9999;
      _stockpile.stone = 9999;
      _stockpile.iron  = 999;
      _stockpile.coal  = 999;
      _stockpile.food  = 9999;
      _stockpile.gold  = 999;

      // Grid layout — tüm bina tipleri, çakışmasız. Safe area (col 1..22,
      // row 1..18). Sıra: erken/orta/ileri oyun + dekoratif.
      const layout = <(BuildingType, int, int)>[
        // Sıra 1: ateş yeri + temel
        (BuildingType.firepit,         10, 2),
        (BuildingType.well,             9, 4),
        (BuildingType.lamppost,        12, 2),
        (BuildingType.lamppost,         8, 2),
        // Sıra 2: evler — solda ev kümesi
        (BuildingType.woodenHouse,      2, 4),
        (BuildingType.woodenHouse,      2, 7),
        (BuildingType.woodenHouse,      2, 10),
        (BuildingType.woodenHouse,      2, 13),
        // Üretim — orta sütun
        (BuildingType.lumberCamp,       5, 4),
        (BuildingType.fisherCabin,      5, 7),
        (BuildingType.mineBuilding,     5, 10),
        (BuildingType.chickenCoop,      5, 13),
        // Civic — sağ sütun
        (BuildingType.townhall,        11, 6),
        (BuildingType.tavern,          11, 10),
        (BuildingType.market,          15, 4),
        (BuildingType.warehouse,       15, 8),
        // Ahır + Ağıl — alt sıra
        (BuildingType.stable,          15, 12),
        (BuildingType.barn,            19, 4),
        // Diğer
        (BuildingType.mill,            19, 8),
        (BuildingType.floristCottage,  19, 12),
        // Kilise — rahibin işyeri (iş döngüsü testi için şart)
        (BuildingType.church,          11, 14),
        // Arı kovanı çiçekçinin yanına — bal sinerjisi (etki alanı çiçekleri).
        (BuildingType.beehive,         17, 13),
        // Ekstra fenerler
        (BuildingType.lamppost,         8, 8),
        (BuildingType.lamppost,        14, 8),
      ];
      // Arazi (ağaç/su) bazı slotları geçersiz kılabilir → o bina SESSİZCE
      // atlanıyordu ve showcase "her tip hazır" sözünü tutmuyordu (değirmen/
      // taverna/kilise böyle kaybolup iş döngüsü testini yanılttı). Artık
      // atlananlar sayılıp bildirimde açıkça söyleniyor.
      _showcaseSkipped.clear();
      for (final (type, col, row) in layout) {
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
      for (int c = farmC1; c <= farmC2; c++) {
        for (int r = farmR1; r <= farmR2; r++) {
          if (_waterTiles.contains((c, r))) continue;
          bool overlap = false;
          for (final b in _buildings) {
            if (c >= b.col && c < b.col + b.cols &&
                r >= b.row && r < b.row + b.rows) {
              overlap = true; break;
            }
          }
          if (!overlap) _farmTiles.add(_devSownTile(c, r));
        }
      }
      // Saha eli _syncFarmerWorkforce (tick) tarafından kurulur.
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
        VillagerType.guard, // devriye + suçüstü yakalama (scene_crime) test yatağı
      ];
      // Yetişkin köylü sayısı yetmezse ek doğur — 5 mesleğin HEPSİ temsil edilsin
      // (aksi halde showcase rastgele biçimde bazı meslekleri hiç göstermez).
      while (_villagers.where((v) => v.hasProfession && !v.isDying).length <
          showcaseTrades.length) {
        final before = _villagers.length;
        _spawnGrownVillager(townhall);
        if (_villagers.length == before) break; // doğuramıyor → sonsuz döngü olmasın
      }
      final grown = _villagers
          .where((v) => v.hasProfession && !v.isDying)
          .toList();
      for (int i = 0; i < showcaseTrades.length && i < grown.length; i++) {
        grown[i].switchProfession(showcaseTrades[i]);
      }

      // Ağıla sürü koy — çobanın bakacak hayvanı olsun (ağıl normalde BOŞ kurulur).
      final barn = _buildings.where((b) => b.type == BuildingType.barn).firstOrNull;
      if (barn != null) {
        for (int i = 0; i < 5; i++) {
          final (sx, sy) = _nearestLand(
              barn.col + barn.cols / 2.0, barn.row + barn.rows.toDouble());
          _cows.add(AnimalEntity(
            kind: i < 2 ? AnimalKind.cow : AnimalKind.sheep,
            barnCol: barn.col,
            barnRow: barn.row,
            startCol: sx + (_rng.nextDouble() - 0.5) * 1.6,
            startRow: sy + (_rng.nextDouble() - 0.5) * 1.6,
            isMale: i.isEven,
            ageDays: AnimalEntity.kAnimalAdultDay + _rng.nextDouble() * 2.0,
            lifespanDays: AnimalEntity.kAnimalElderDay + 8.0 +
                _rng.nextDouble() * 12.0,
          ));
        }
      }
    });
    _showNotification(_showcaseSkipped.isEmpty
        ? '🎭 Showcase köyü kuruldu — her tip görsel test için hazır'
        : '🎭 Showcase kuruldu — ARAZİ YÜZÜNDEN KURULAMADI: '
            '${_showcaseSkipped.join(", ")}');
  }
}
