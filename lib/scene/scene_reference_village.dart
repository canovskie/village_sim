part of '../main.dart';

/// ─── REFERANS KÖY ────────────────────────────────────────────────────────────
///
/// Testlerin ORTAK ZEMİNİ: oturmuş, sistemli ve ORTALAMA tek bir köy. Her
/// açılışta birebir aynı kurulur (sabit dünya tohumu + sabit rng) ve gerçek bir
/// KAYIT SLOTU'na yazılır (`kReferenceSlotId`) → "şu köyde şu davranışı gördüm"
/// demek anlamlı hale gelir.
///
/// Showcase köyünden farkı — showcase "her şeyi görmek" içindir (9999 kaynak,
/// her bina tipi, denge umrunda değil). Referans köy ORTALAMA olmak zorunda:
///   • Nüfus 18, yatak 18 (tam oturmuş — ne evsiz ne boş ev).
///   • Kaynak makul (bir kış çıkarır, iki bina diker; sınırsız değil).
///   • 11 mesleğin hepsi temsil edilir ama kadro şişik değil.
///   • Politik pusula MERKEZ'de (Ilımlı Köy) — 8 mühür var ama biri diğerini
///     dengeliyor, yani rejim testleri buradan İSTENEN yöne sürülebilir.
///   • İki hane: kurucu soy + dışarıdan yerleşmiş ikinci hane (yönetişim
///     makinesinin dönmesi için en az iki hane şart).
///
/// Determinizm notu: kurulum anı birebir tekrarlanır. Sonrasında sim akar ve
/// kare zamanlaması makineye göre değişir → uzun vadeli olay dizisi birebir
/// aynı olmaz. Test zemini "aynı BAŞLANGIÇ", "aynı gelecek" değil.
///
/// Planın kendisi (tohum, yerleşim, tarla, kanun listesi) SAF bir kütüphanede:
/// [lib/world/reference_village_plan.dart] — sahneyi ayağa kaldırmadan
/// testlenebilsin diye (bkz. test/reference_village_test.dart).
///
/// part of main.dart — State'in tüm private alanlarına erişir.

extension _SceneReferenceVillage on _VillageSceneState {
  int _refCol(int localCol) => kRefOx + localCol;
  int _refRow(int localRow) => kRefOy + localRow;

  /// Yerel kutunun (payla genişletilmiş) içinde mi?
  bool _inRefBox(int c, int r, {int pad = 0}) =>
      c >= kRefOx - pad &&
      c < kRefOx + kRefW + pad &&
      r >= kRefOy - pad &&
      r < kRefOy + kRefH + pad;

  /// Referans köyü kurar. Sahne hazır olduğunda (asset'ler yüklendikten sonra)
  /// bir kez çağrılır; ardından [_saveNow] ile slota yazılır.
  void buildReferenceVillage() {
    setStateHere(() {
      // ── 0. Determinizm ─────────────────────────────────────────────────────
      // Dünya üreticinin kendi rng'si var; sahnenin _rng'si isim/kişilik/yaş
      // dağıtır. İkisi de sabitlenmezse "aynı köy" sözü tutmaz.
      _rng = Random(kReferenceSeed);
      _generateWorld(forceSeed: kReferenceSeed);
      // _generateWorld yol boyunca _rng'yi tüketebilir → plan öncesi tazele.
      _rng = Random(kReferenceSeed ^ 0x5EED);

      _villageName = 'Referans';

      // ── 1. Arazi: köyün temizlediği alan ───────────────────────────────────
      // Yerleşik bir köy oturduğu yeri açmıştır. Kutu içindeki ağaç/sazlık
      // kaldırılır (yoksa plan araziye takılıp binaları sessizce düşürür),
      // kutunun hemen batısına oduncunun ormanı deterministik olarak dikilir.
      _trees.removeWhere((t) => _inRefBox(t.col, t.row, pad: 1));
      _reeds.removeWhere((r) =>
          _inRefBox(r.col, r.row, pad: 1) || _inRefBox(r.col2, r.row2, pad: 1));
      _plantReferenceGrove();

      // ── 2. Köyün bildikleri + ambarı ───────────────────────────────────────
      // Oturmuş köy zanaatlarını öğrenmiştir (madencilik dahil: damar uzakta
      // ama bilgi köyde). Kaynak ORTALAMA: bir kış çıkarır, iki bina diker.
      _knownCrafts.addAll(Craft.all);
      _stockpile.wood = 140;
      _stockpile.stone = 70;
      _stockpile.iron = 14;
      _stockpile.coal = 10;
      _stockpile.food = 120;
      _stockpile.gold = 55;
      _stockpile.honey = 8;
      _stockpile.reed = 12;

      // ── 3. Yerleşim ────────────────────────────────────────────────────────
      _refSkipped.clear();
      for (final (type, lc, lr) in kRefLayout) {
        final col = _refCol(lc);
        final row = _refRow(lr);
        if (!_isValidPlacement(col, row, type)) {
          _refSkipped.add(type.name);
          continue;
        }
        _buildings.add(BuildingEntity(type: type, col: col, row: row));
        _onBuildingCompleted(
          BuildOrder(type: type, col: col, row: row)..completed = true,
        );
      }
      // Doğrudan yerleştirmede topology kancası tetiklenmez — çapa slotlarını
      // (kuyu/ateş/bank) ve arı sürülerini elle türet.
      _anchorSystem.rebuild(_buildings);
      _rebuildBeeSwarms();

      // ── 4. Tarlalar ────────────────────────────────────────────────────────
      // Saha eli otomatik doğmaz: _syncFarmerWorkforce (tick) köyün çiftçi
      // kadrosuna bakıp ilk karede kurar.
      for (final (c1, r1, c2, r2) in kRefFarms) {
        for (int lc = c1; lc <= c2; lc++) {
          for (int lr = r1; lr <= r2; lr++) {
            final c = _refCol(lc);
            final r = _refRow(lr);
            if (_waterTiles.contains((c, r))) continue;
            if (_isOccupiedByBuilding(c, r)) continue;
            _farmTiles.add(_devSownTile(c, r));
          }
        }
      }

      // ── 5. İnsanlar ────────────────────────────────────────────────────────
      _populateReferenceVillage();

      // ── 6. Sürü ────────────────────────────────────────────────────────────
      _stockReferenceBarn();

      // ── 7. Kanunname + köyün hâli ──────────────────────────────────────────
      _policies.restoreSealed(kRefLaws);
      _applyPolicySideChannels();
      _morale = 0.62;
      _avgIndividualMorale = 0.62;
      _unrest = 0.08;
      _governanceLegacy = 0.0;
      _foodHunger = 0.0;

      // ── 8. Takvim & kamera ─────────────────────────────────────────────────
      // 24. gün, sabahın ortası: gündüz işi görünür, gece testine 1 tur var.
      _dayCount = 24;
      _cycle.timeOfDay = 0.33;
      _lastTimeOfDay = _cycle.timeOfDay;
      _lastSeason = _season;
      // Reach normalde bina/görevle büyür; köy hazır kurulduğu için hedefe elle
      // sıçra (yoksa kamera oturmuş köye dar gelir).
      _reachSpan = _landExpansionTarget;

      // ── 9. Kronik — köyün kısa geçmişi ─────────────────────────────────────
      // Gün damgaları elle veriliyor: _chronicle her satırı BUGÜNE yazar, oysa
      // burada anlatılan şey köyün GEÇMİŞİ (24 güne yayılmış bir tarih).
      _storyLog.clear();
      _storyLog.addAll(const [
        ChronicleEntry(
            day: 1, icon: '🔥', text: 'Köyün kuruluşu', milestone: true),
        ChronicleEntry(
            day: 6, icon: '🌾', text: 'İlk ambar doldu; kış korkusu geçti.'),
        ChronicleEntry(
            day: 11, icon: '🧳', text: 'Dışarıdan bir hane geldi, köye yerleşti.'),
        ChronicleEntry(
            day: 15,
            icon: '⚖',
            text: 'Kanunname açıldı: komşuluk ve gece nöbeti mühürlendi.',
            milestone: true),
        ChronicleEntry(
            day: 20,
            icon: '🌀',
            text: 'Değirmen döndü; un köyün kendi eliyle çıkıyor.'),
      ]);

      // Başarımlar: oturmuş köyün geçmişinde geçilmiş eşikler (nüfus/ilk bina/
      // yıl) SESSİZCE kazanılmış sayılır — yoksa ilk tick'te hepsi "çat çat"
      // patlar. Kronik zaten elle yazılmış geçmişi taşıyor (yukarıda).
      _backfillAchievements();

      _fixNpcSpawns();
    });

    // Defterin "köyün hâli" tablosu mühürlerden türer — kurulum sonrası tazele.
    _recomputePressure();

    _showNotification(_refSkipped.isEmpty
        ? '📐 Referans köy kuruldu — ${_villagers.length} kişi, '
            '${_buildings.length} yapı'
        : '📐 Referans köy kuruldu — ARAZİ YÜZÜNDEN KURULAMADI: '
            '${_refSkipped.join(", ")}');
  }

  // ── Yardımcılar ────────────────────────────────────────────────────────────

  /// Oduncunun ormanı — kutunun batısına deterministik bir koru diker.
  /// Oduncu kulübesi "yakında ağaç" ister ([kLumberTerritoryRadius]); dünya
  /// üreticinin ormanı oraya düşmeyebilir, o yüzden garanti altına alınır.
  void _plantReferenceGrove() {
    final taken = {for (final t in _trees) (t.col, t.row)};
    final (gc1, gr1, gc2, gr2) = kRefGrove;
    for (int dc = gc1; dc <= gc2; dc++) {
      for (int dr = gr1; dr <= gr2; dr++) {
        // Seyrek ama dolu bir koru: satranç deseni + kenarlarda boşluk.
        if ((dc + dr).isOdd) continue;
        final c = _refCol(dc);
        final r = _refRow(dr);
        if (c < 1 || c >= kCols - 1 || r < 1 || r >= kRows - 1) continue;
        if (_waterTiles.contains((c, r))) continue;
        if (taken.contains((c, r))) continue;
        taken.add((c, r));
        _trees.add(TreeEntity(col: c, row: r, type: TreeType.pine));
      }
    }
  }

  /// Nüfusu kurar: 5 kurucu (ateş yeriyle doğdu) + dışarıdan yerleşmiş 3
  /// kişilik ikinci hane + köyde doğup büyümüş 10 kişi = 18. Yatak sayısı da
  /// 18 → ne evsiz kalır ne ev boş durur.
  void _populateReferenceVillage() {
    final townhall = _buildings
        .where((b) => b.type == BuildingType.townhall)
        .firstOrNull;
    if (townhall == null) return; // plan tutmadıysa nüfusu zorlamayalım

    // ── İkinci hane (dışarıdan) ────────────────────────────────────────────
    // Yönetişim en az iki hane ister; köyde doğan herkes kurucu soyu miras
    // aldığı için ikinci hane ancak DIŞARIDAN gelir.
    // Kurucu soyla ÇAKIŞMAMALI — aynı soyad çıkarsa iki hane tek haneye düşer
    // ve yönetişim testleri tek renkli kalır.
    final founderLine = _villageLineage();
    var settlerLine = randomVillagerSurname(_rng);
    for (int i = 0; i < 12 && settlerLine == founderLine; i++) {
      settlerLine = randomVillagerSurname(_rng);
    }
    final father = _refSettler(settlerLine,
        type: VillagerType.miller, male: true, ageDays: 9.2);
    final mother = _refSettler(settlerLine,
        type: VillagerType.innkeeper, male: false, ageDays: 8.4);
    final son = _refSettler(settlerLine,
        type: VillagerType.shepherd, male: true, ageDays: 4.0);
    if (father != null && mother != null && son != null) {
      son.parents.addAll([father, mother]);
      father.children.add(son);
      mother.children.add(son);
    }

    // ── Köyde doğup büyüyenler ─────────────────────────────────────────────
    // Yaş piramidi: 3 çocuk, 5 yetişkin, 2 yaşlı (oturmuş köyün dokusu).
    const ages = <double>[0.6, 1.3, 2.1, 3.4, 4.8, 6.2, 7.6, 9.9, 12.7, 14.1];
    for (final age in ages) {
      final before = _villagers.length;
      _spawnGrownVillager(townhall);
      if (_villagers.length == before) break; // yatak bitti → zorlamayalım
      final v = _villagers.last;
      v.ageDays = age;
      // Yaşı elle verilen köylü çağrısını "büyürken" bulmadı sayılır; aksi
      // halde ilk tick'te toplu "çağrısını buldu" anı patlar.
      v.callingFound = v.hasProfession;
      v.lastStageSeen = v.lifeStage;
      if (v.hasProfession) {
        v.wealth = 16 + (v.personalitySeed.abs() % 52).toDouble();
      }
    }

    // ── Meslek kadrosu ─────────────────────────────────────────────────────
    // Meslek normalde çağrıdan doğar → rastgele dağılır ve bazı meslekler hiç
    // çıkmaz. Referans köy 11 mesleğin HEPSİNİ temsil etmek zorunda: kurucular
    // (çiftçi/tüccar/demirci/muhafız/rahip) + yerleşenler (değirmenci/hancı/
    // çoban) sabit; kalan yetişkinlere eksikler verilir.
    const wanted = <VillagerType>[
      VillagerType.fisher,
      VillagerType.hunter,
      VillagerType.miner,
      VillagerType.farmer,
      VillagerType.guard,
    ];
    final fixed = <VillagerEntity?>{father, mother, son}
        .whereType<VillagerEntity>()
        .toSet();
    final free = _villagers
        .where((v) =>
            v.hasProfession && !v.isDying && !fixed.contains(v))
        .skip(5) // ilk 5 = kurucular, meslekleri sabit kalsın
        .toList();
    for (int i = 0; i < wanted.length && i < free.length; i++) {
      free[i].switchProfession(wanted[i]);
    }

    // ── Oturmuşluk: moral + birikmiş varlık ────────────────────────────────
    for (final v in _villagers) {
      v.morale = 0.58 + (v.personalitySeed.abs() % 17) / 100.0; // 0.58–0.74
      if (v.hasProfession && v.wealth <= 0) {
        v.wealth = 16 + (v.personalitySeed.abs() % 52).toDouble();
      }
    }
  }

  /// Dışarıdan gelip yerleşmiş bir köylü kurar (boş yatağa oturtur).
  /// [_spawnMigrant]'ın sessiz hali: bildirim/moral bedeli yok, çünkü bu göç
  /// ŞİMDİ olmuyor — köyün geçmişinde olmuş sayılıyor.
  VillagerEntity? _refSettler(
    String surname, {
    required VillagerType type,
    required bool male,
    required double ageDays,
  }) {
    BuildingEntity? house;
    for (final b in _buildings) {
      final f = b.fn;
      if (f == null || f.role != BuildingRole.housing) continue;
      if (_villagers.where((v) => v.homeBuilding == b).length <
          f.housingCapacity) {
        house = b;
        break;
      }
    }
    if (house == null) return null;
    final (sx, sy) = _nearestLand(
      house.col + house.cols / 2.0,
      house.row + house.rows.toDouble(),
    );
    final v = VillagerEntity(
      type: type,
      name: randomVillagerName(_rng, male: male),
      surname: surname,
      male: male,
      personalitySeed: _seedForCalling(type),
      startCol: sx,
      startRow: sy,
      ageDays: ageDays,
      lifespanDays: _rollLifespan(),
    );
    v.homeBuilding = house;
    v.lastStageSeen = v.lifeStage;
    _villagers.add(v);
    _lifeEvent(v, 'Köye dışarıdan gelip yerleşti', icon: '🧳', milestone: true);
    return v;
  }

  /// Ağıla ortalama bir sürü koyar — 3 koyun + 2 inek, karışık cinsiyet, hepsi
  /// yetişkin (üreme/yaşlanma döngüsü ilk günden dönebilsin).
  void _stockReferenceBarn() {
    final barn = _buildings.where((b) => b.type == BuildingType.barn).firstOrNull;
    if (barn == null) return;
    const kinds = <AnimalKind>[
      AnimalKind.cow,
      AnimalKind.cow,
      AnimalKind.sheep,
      AnimalKind.sheep,
      AnimalKind.sheep,
    ];
    for (int i = 0; i < kinds.length; i++) {
      final (sx, sy) = _nearestLand(
          barn.col + barn.cols / 2.0, barn.row + barn.rows.toDouble());
      _cows.add(AnimalEntity(
        kind: kinds[i],
        barnCol: barn.col,
        barnRow: barn.row,
        startCol: sx + (i - 2) * 0.7,
        startRow: sy + (i.isEven ? 0.5 : -0.5),
        isMale: i.isEven,
        ageDays: AnimalEntity.kAnimalAdultDay + 1.0 + i * 0.8,
        lifespanDays: AnimalEntity.kAnimalElderDay + 10.0 + i * 2.0,
      ));
    }
  }
}
