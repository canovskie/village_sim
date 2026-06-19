part of '../main.dart';

/// Bina tamamlandığında ne olur + NPC spawn (başlangıç + yetişkin doğum) +
/// uyku hedefi atama + spawn pozisyon temizleme + tek-tıkla canlı köy.
/// part of main.dart — State'in tüm private alanlarına erişim.
extension _SceneBuildingSpawn on _VillageSceneState {
  /// Başlangıç hayvanı — yetişkin ama yaşları çeşitli (hep birlikte
  /// yaşlanıp aynı anda ölmesinler), ömrü randomize.
  AnimalEntity _spawnAnimal(
      AnimalKind kind, BuildOrder o, double col, double row, bool male) {
    final age = AnimalEntity.kAnimalAdultDay +
        _rng.nextDouble() *
            (AnimalEntity.kAnimalElderDay - AnimalEntity.kAnimalAdultDay);
    final lifespan = AnimalEntity.kAnimalElderDay + 5.0 + _rng.nextDouble() * 9.0;
    return AnimalEntity(
      kind: kind,
      barnCol: o.col,
      barnRow: o.row,
      startCol: col,
      startRow: row,
      isMale: male,
      ageDays: age,
      lifespanDays: lifespan,
    );
  }

  void _spawnStartingNPCs(BuildingEntity firepit) {
    final cx = firepit.col + 0.5;
    final cy = firepit.row + 0.5;

    final types = [
      VillagerType.farmer,
      VillagerType.merchant,
      VillagerType.blacksmith,
      VillagerType.guard,
      VillagerType.mage,
    ];
    for (int i = 0; i < types.length; i++) {
      final angle = i * (2 * pi / types.length);
      final dist = 1.2 + _rng.nextDouble() * 0.6;
      // Kurucular yetişkin/yaşlı yaşıyla doğar — köy ilk günden işlevsel.
      final founderAge =
          kAdultStartDay + _rng.nextDouble() * (kElderStartDay - kAdultStartDay + 5);
      final male = _rng.nextBool();
      _villagers.add(
        VillagerEntity(
          type: types[i],
          name: randomVillagerName(_rng, male: male),
          male: male,
          startCol: cx + cos(angle) * dist,
          startRow: cy + sin(angle) * dist,
          ageDays: founderAge,
          lifespanDays: _rollLifespan(),
        ),
      );
    }

    // 2 inşaatçı
    for (int i = 0; i < 2; i++) {
      final angle = pi / 4 + i * pi;
      _builders.add(
        BuilderEntity(
          startCol: cx + cos(angle) * 1.8,
          startRow: cy + sin(angle) * 1.8,
        ),
      );
    }

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

    const civilianTypes = [
      VillagerType.farmer,
      VillagerType.merchant,
      VillagerType.blacksmith,
      VillagerType.guard,
      VillagerType.mage,
    ];
    final type = civilianTypes[_rng.nextInt(civilianTypes.length)];
    final (sx, sy) = _nearestLand(
      townhall.col + townhall.cols / 2.0,
      townhall.row + townhall.rows.toDouble(),
    );
    final male = _rng.nextBool();
    final v = VillagerEntity(
      type: type,
      name: randomVillagerName(_rng, male: male),
      male: male,
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
    _villagers.add(v);

    final msg = v.parents.isEmpty
        ? '👶 ${v.name} doğdu!'
        : '👶 ${v.parents.map((p) => p.name).join(' & ')} ailesine ${v.name} katıldı';
    _showNotification(msg);
  }

  /// Doğal doğum — anne+baba'dan bebek üretir, parents ref'leri kurulur,
  /// evin yakınında spawn. Anne fertilityDays resetlenir. Maliyet yok.
  /// Bebek `LifeStage.child` evresinde — büyüdükçe `hasProfession` olur.
  void _spawnBabyFromParents(VillagerEntity mother, VillagerEntity father) {
    final home = mother.homeBuilding as BuildingEntity?;
    if (home == null) return;

    const civilianTypes = [
      VillagerType.farmer,
      VillagerType.merchant,
      VillagerType.blacksmith,
      VillagerType.guard,
      VillagerType.mage,
    ];
    // Çıraklık politikası: bebek 2/3 ihtimal anne/baba mesleğini öğrenir,
    // 1/3 ihtimal soy kırılır (rastgele meslek). Tam mirasilik soy zinciri
    // çeşitliliğini öldürür — bedel hafif tutuldu.
    final type = (_policies.apprenticeship && _rng.nextInt(3) != 0)
        ? (_rng.nextBool() ? mother.type : father.type)
        : civilianTypes[_rng.nextInt(civilianTypes.length)];
    final male = _rng.nextBool();
    final (sx, sy) = _nearestLand(
      home.col + home.cols / 2.0,
      home.row + home.rows.toDouble(),
    );
    final baby = VillagerEntity(
      type: type,
      name: randomVillagerName(_rng, male: male),
      male: male,
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

    _showNotification(
        '👶 ${mother.name} & ${father.name} ailesine ${baby.name} doğdu!');
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

    const civilianTypes = [
      VillagerType.farmer,
      VillagerType.merchant,
      VillagerType.blacksmith,
      VillagerType.guard,
      VillagerType.mage,
    ];
    final type = civilianTypes[_rng.nextInt(civilianTypes.length)];
    final male = _rng.nextBool();
    // Yetişkin başlasın — bebek değil, hayatta tecrübeli (göç anlamlı olsun).
    final ageDays = 20.0 + _rng.nextDouble() * 30.0;
    final migrant = VillagerEntity(
      type: type,
      name: randomVillagerName(_rng, male: male),
      male: male,
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
        '🚶 ${migrant.name} köye katıldı (köy alışırken hafif gerilim).');
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
        _showNotification('Ateş yakıldı! Köy kurulmaya başlıyor...');

      case BuildingType.woodenHouse:
        int assigned = 0;
        for (final v in _villagers) {
          if (assigned >= 2) break;
          if (v.homeBuilding == null) {
            v.homeBuilding = building;
            assigned++;
          }
        }
        if (assigned > 0) {
          _showNotification('$assigned köylü eve taşındı.');
        }

      case BuildingType.lumberCamp:
        _lumberCamps.add(
          LumberCampEntity(buildingCol: o.col, buildingRow: o.row),
        );

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
        // Bina engel sayıldığı için spawn footprint güney kenarı dışında.
        _miners.add(
          MinerEntity(
            startCol: o.col + meta.cols / 2.0,
            startRow: o.row + meta.rows + 0.3,
          ),
        );

      case BuildingType.fisherCabin:
        // Balıkçı kulübesi (2x2): spawn footprint güneyi dışında.
        _fishers.add(
          FisherEntity(startCol: o.col + 1.0, startRow: o.row + 2.3),
        );

      case BuildingType.barn:
        // Ağıl tamamlanınca bir çoban + 3 inek + 2 koyun spawn et.
        // Footprint dışı slotlara — yığılma yok, bina blok'unda spawn yok.
        _shepherds.add(
          ShepherdEntity(barnCol: o.col, barnRow: o.row),
        );
        // Cinsiyet: çift bazlı üreme için başlangıçta hem dişi hem erkek olsun.
        const cowOffsets = [
          (-0.6, 2.4),
          ( 1.5, 2.9),
          ( 3.6, 1.6),
        ];
        const cowMales = [false, true, false]; // 2 dişi + 1 boğa
        for (var i = 0; i < cowOffsets.length; i++) {
          final (dc, dr) = cowOffsets[i];
          final jx = (_rng.nextDouble() - 0.5) * 0.4;
          final jy = (_rng.nextDouble() - 0.5) * 0.4;
          _cows.add(_spawnAnimal(AnimalKind.cow, o,
              o.col + dc + jx, o.row + dr + jy, cowMales[i]));
        }
        const sheepOffsets = [
          ( 0.4, 3.2),
          ( 2.6, 2.6),
        ];
        const sheepMales = [false, true]; // 1 koyun + 1 koç
        for (var i = 0; i < sheepOffsets.length; i++) {
          final (dc, dr) = sheepOffsets[i];
          final jx = (_rng.nextDouble() - 0.5) * 0.4;
          final jy = (_rng.nextDouble() - 0.5) * 0.4;
          _cows.add(_spawnAnimal(AnimalKind.sheep, o,
              o.col + dc + jx, o.row + dr + jy, sheepMales[i]));
        }

      case BuildingType.floristCottage:
        _spawnFlowerGardenDecor(o);
        // Çiçekçi NPC kulübeden çıkar. Spawn pozisyonu footprint güney kenarı.
        final meta = kBuildingMeta[BuildingType.floristCottage]!;
        _florists.add(FloristEntity(
          startCol: o.col + meta.cols / 2.0,
          startRow: o.row + meta.rows + 0.3,
          cottageCol: o.col,
          cottageRow: o.row,
          effectRadius: meta.effectRadius,
        ));

      case BuildingType.chickenCoop:
        // Tavuk kümesi: 3-4 tavuk spawn et, footprint güney/yan kenarına.
        // Yumurta üretimi main update loop'unda timer'la — kümes pasif food.
        const chickenOffsets = [
          (0.4, 2.3),
          (1.6, 2.5),
          (2.5, 1.4),
          (-0.4, 1.5),
        ];
        const chickenMales = [false, true, false, false]; // 1 horoz
        for (var i = 0; i < chickenOffsets.length; i++) {
          final (dc, dr) = chickenOffsets[i];
          final jx = (_rng.nextDouble() - 0.5) * 0.3;
          final jy = (_rng.nextDouble() - 0.5) * 0.3;
          _cows.add(_spawnAnimal(AnimalKind.chicken, o,
              o.col + dc + jx, o.row + dr + jy, chickenMales[i]));
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
          if (!overlap) _farmTiles.add(FarmTile(c, r));
        }
      }
      final needed = (_farmTiles.length / 6).ceil().clamp(1, 4);
      while (_farmers.length < needed) {
        final angle = _rng.nextDouble() * 2 * pi;
        _farmers.add(FarmFarmer(
          startCol: 16 + cos(angle) * 1.5,
          startRow: 3.5 + sin(angle) * 1.5,
        ));
      }
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
        // Arı kovanı çiçekçinin yanına — bal sinerjisi (etki alanı çiçekleri).
        (BuildingType.beehive,         17, 13),
        // Ekstra fenerler
        (BuildingType.lamppost,         8, 8),
        (BuildingType.lamppost,        14, 8),
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

      // Tarla + 2 çiftçi — pazarın üstü
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
          if (!overlap) _farmTiles.add(FarmTile(c, r));
        }
      }
      while (_farmers.length < 2) {
        _farmers.add(FarmFarmer(
          startCol: 17 + _rng.nextDouble() * 2,
          startRow: 5 + _rng.nextDouble() * 1,
        ));
      }
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
    });
    _showNotification('🎭 Showcase köyü kuruldu — her tip görsel test için hazır');
  }
}
