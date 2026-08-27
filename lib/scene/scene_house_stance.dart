part of '../main.dart';

/// HANE KARŞILIĞI — hanenin geri çektiği şeyin köyde GÖRÜNDÜĞÜ yer.
///
/// Saf merdiven `systems/house_stance.dart`'ta; burası onu köyün dört gerçek
/// koluna bağlar. Hane katmanının bugüne dek eksik olan yarısı bu dört kol:
///
///   1. EMEK   — küskün hanenin üyeleri işe çıkmaz (`_houseWithholdsLabor`,
///               scene_jobs `_freeForJob` + elle atama kapısı).
///   2. ÜRÜN   — ürettikleri yiyecek köy ambarına değil hanenin kendi
///               ambarına gider (`_deliverFoodFrom`, tüm yiyecek girişleri).
///   3. NİKÂH  — kopmuş hane kız/oğul vermez (`_houseRefusesBetrothal`,
///               scene_wedding kur taraması).
///   4. MASA   — reis divandaki sandalyesini boş bırakır
///               (`_houseBoycottsCouncil`, ledger/divan masası).
///
/// GERİ DÖNÜŞLÜ: hiçbir kol kalıcı değil. Hane razı olunca ambarını KENDİ açar
/// ve sakladığı köye geri akar (`_releaseHouseStashes`) — barışın karşılığı
/// ambarın birkaç gün boyunca kendiliğinden şişmesidir. Oyuncu bu yüzden
/// "cezalandırılmış" değil, PAZARLIK içinde hisseder.
///
/// SESSİZ OLMAZ: her basamak değişimi köyün ağzından duyurulur (havuzlu metin,
/// bkz. project_voice_system) + vakanüvise düşer. Oyuncunun ambarı sebepsiz
/// kurumaz; kimin, neden esirgediği her zaman söylenir.
extension _SceneHouseStance on _VillageSceneState {
  /// Duruş tarama aralığı (sn). Merdiven yavaş bir şey — sık yoklamaya gerek yok.
  static const double _kStanceScan = 4.0;

  /// Esirgeyen hanenin üyesi bu aralıkla (sn) bir kez görünür biçimde işi bırakır.
  static const double _kIdleGesture = 9.0;

  // ── Tick ────────────────────────────────────────────────────────────────────

  void _tickHouseStance(double dt) {
    _houseStanceScan += dt;
    _stashReturnAccum += dt;
    if (_houseStanceScan < _kStanceScan) return;
    final elapsed = _houseStanceScan;
    _houseStanceScan = 0;

    _probeHouseStance();
    _pollStanceChanges();
    // Gün kesri bir kez hesaplanır: hem ambar geri akışı hem ayrılık sayacı
    // aynı zamanı kullanmalı (ikisi ayrı biriktirici kullanırsa hane "razı"
    // sayıldığı turda sayaç yine ilerler ve ayrılık haksız yere yaklaşırdı).
    final dayFrac = _stashReturnAccum / kGameDaySeconds;
    _stashReturnAccum = 0;
    _releaseHouseStashes(dayFrac);
    _tickSchism(dayFrac);
    _dropWithheldJobs(elapsed);
  }

  /// PROVA kancası — harness merdiveni gerçek sahnede sürebilsin diye
  /// (bkz. test/house_stance_probe_test.dart). Oyunda hiçbir etkisi yok:
  /// bayraklar yalnız testte/capture'da set edilir.
  void _probeHouseStance() {
    if (kProbeHouseWithhold) {
      kProbeHouseWithhold = false;
      // En nüfuzlu haneyi seç — kozu olan hane merdiveni gerçekten tırmanır.
      String? best;
      var bestShare = -1.0;
      for (final s in _houses.snapshot()) {
        if (s.members <= 0) continue;
        if (s.swayShare > bestShare) {
          bestShare = s.swayShare;
          best = s.surname;
        }
      }
      if (best != null) {
        kProbeHouseName = best;
        // Hâli dibe çek + kozu büyüt → ambar basamağı.
        _houses.nudge(best, moodDelta: -1.0, swayGain: 3.0);
        // Üye moralleri hâli geri yukarı çeker (mood üye moraline gravite
        // eder); prova penceresinde tutunması için onları da indir.
        for (final v in _villagers) {
          if (v.surname == best) v.morale = 0.05;
        }
      }
    }
    if (kProbeHouseAppease) {
      kProbeHouseAppease = false;
      // Prova başta seçtiği haneyi sonuna kadar izlemeli. Uzun sim sırasında
      // başka bir hane daha kötü duruma düşebilir; genel "en kötü hane"
      // seçicisini kullanmak hükmü yanlış haneye gönderip izlenen ambarı
      // kapalı bırakıyordu.
      final sn = kProbeHouseName.isEmpty ? null : kProbeHouseName;
      if (sn != null) {
        _appeaseWithholdingHouse(null, targetSurname: sn);
        for (final v in _villagers) {
          if (v.surname == sn) v.morale = 0.85;
        }
        _houses.nudge(sn, moodDelta: 1.0);
      }
    }
    // Telemetri — testin okuduğu tek doğruluk kaynağı. Saklanan yiyecek
    // KÖY GENELİ DEĞİL, izlenen hane bazında ölçülür: prova köyü strese
    // sokuyor, başka bir hane de kendiliğinden ambar kapatabiliyor ve köy
    // toplamı "barıştırdığım hane ambarını açtı mı" sorusuna yalan söylüyordu.
    kProbeHousesWithholding = _withholdingHouses.length;
    kProbeHouseStash = kProbeHouseName.isEmpty
        ? [
            for (final s in _houses.surnames) _houses.stashOf(s),
          ].fold(0, (a, b) => a + b)
        : _houses.stashOf(kProbeHouseName);
    var idle = 0;
    for (final v in _villagers) {
      if (!v.isDying && _houseWithholdsLabor(v)) idle++;
    }
    kProbeHouseIdled = idle;
  }

  /// Merdiven basamağı değişen haneleri duyurur. Basamak İÇİ oynamalar sessiz —
  /// köy her mood kıpırdanışında konuşsaydı bildirim gürültüsü olurdu.
  void _pollStanceChanges() {
    for (final s in _houses.snapshot()) {
      final prev = _houseStanceSeen[s.surname];
      if (prev == s.stance) continue;
      _houseStanceSeen[s.surname] = s.stance;
      // İlk görüş: duruşu kaydet ama duyurma (kayıt yüklemesi köyü
      // "Karahan elini çekti" diye karşılamasın — o zaten öyleydi).
      if (prev == null) continue;
      _announceStance(s, worse: s.stance.index > prev.index);
    }
    // Sönmüş haneler haritada kalmasın.
    if (_houseStanceSeen.length > _houses.houseCount) {
      final live = _houses.surnames.toSet();
      _houseStanceSeen.removeWhere((k, _) => !live.contains(k));
    }
  }

  /// Bir hanenin duruş değişimini köyün ağzından söyler + vakanüvise düşürür.
  void _announceStance(HouseSnapshot s, {required bool worse}) {
    final head = _headOfSurname(s.surname);
    final ctx = _voice(
      head,
      seed: _stableSeed('duruş${s.surname}${s.stance.name}', _dayCount),
      extra: {'hane': s.surname},
    );
    final pool = switch (s.stance) {
      HouseStance.loyal => _kStanceLoyal,
      HouseStance.content => _kStanceCooled,
      HouseStance.murmuring => worse ? _kStanceMurmur : _kStanceCooled,
      HouseStance.withdrawn => worse ? _kStanceWithdrawn : _kStanceCooled,
      HouseStance.hoarding => _kStanceHoarding,
      HouseStance.defiant => _kStanceDefiant,
    };
    _showNotification('${s.stance.icon} ${Voice.say(pool, ctx)}');
    // Yalnız ESİRGEME basamakları vakanüvise düşer — serzeniş günlük bir şey,
    // kroniği doldurmasın.
    if (s.stance.withholds || (!worse && s.stance == HouseStance.content)) {
      _chronicle(
        Voice.say(_kStanceAnnal, ctx),
        icon: s.stance.icon,
        kind: ChronicleKind.crisis,
      );
    }
    logDev(
      'hane duruş: ${s.surname} → ${s.stance.name} '
      '(hâl ${s.mood.toStringAsFixed(2)}, pay ${s.swayShare.toStringAsFixed(2)})',
    );
  }

  /// Bir soyadın reisi — duruş cümlelerinin ağzı. Canlı üye yoksa null.
  VillagerEntity? _headOfSurname(String surname) {
    final members = [
      for (final v in _villagers)
        if (!v.isDying && v.surname == surname) v,
    ];
    return headOfHouse(members);
  }

  // ── 2. ÜRÜN: hanenin kendi ambarı ───────────────────────────────────────────

  /// Bir köylünün ürettiği [amount] yiyeceğin köy ambarına GİREN kısmı.
  /// Ambara gerçekten eklenen tam sayı döner.
  ///
  /// Tüm yiyecek girişlerinin tek kapısı — küskün hanenin ürünü buradan
  /// hanenin kendi ambarına sapar, sadık hanenin ikramı buradan eklenir.
  /// Kesirler [_foodCarry]'de birikir: bir kile bile yok olmaz.
  int _deliverFoodFrom(VillagerEntity? v, int amount) {
    if (amount <= 0) return 0;
    var share = amount.toDouble();
    final surname = v == null ? '' : v.surname;
    if (surname.isNotEmpty) {
      final w = _houses.withholdingOf(surname);
      if (w.hoard > 0) {
        share -= _houses.hoard(surname, share * w.hoard);
      } else if (w.bounty > 0) {
        share += amount * w.bounty; // sadık hanenin ikramı
      }
    }
    _foodCarry += share;
    final whole = _foodCarry.floor();
    if (whole <= 0) return 0;
    _foodCarry -= whole;
    _stockpile.food += whole;
    return whole;
  }

  /// Razı olmuş hanelerin ambarları köye geri akar — birkaç güne yayılır ki
  /// oyuncu barışın karşılığını ambarda GÖRSÜN.
  void _releaseHouseStashes(double dayFrac) {
    if (dayFrac <= 0) return;
    final back = _houses.releaseStashes(dayFrac);
    if (back.isEmpty) return;
    var total = 0;
    for (final e in back.entries) {
      total += e.value;
      if (kCaptureMode && e.key == kProbeHouseName) {
        kProbeHouseReleased += e.value;
      }
      // Kapağını ilk açan haneyi köy duysun (tek satır, en büyük pay yeter).
      if (e.value >= 3 && _stashOpenedCd <= 0) {
        _stashOpenedCd = 90.0;
        final ctx = _voice(
          _headOfSurname(e.key),
          seed: _stableSeed('ambar${e.key}', _dayCount),
          extra: {'hane': e.key},
        );
        _showNotification('🫓 ${Voice.say(_kStashOpened, ctx)}');
      }
    }
    if (total > 0) _stockpile.food += total;
  }

  // ── 1. EMEK: hane elini çeker ───────────────────────────────────────────────

  /// Bu köylü hanesinin emek grevine dahil mi. Seçim DETERMİNİSTİK
  /// ([VillagerEntity.personalitySeed] üzerinden): aynı hanede aynı kişiler
  /// çekilir, her tarama farklı kişi seçilip köy titremez.
  bool _houseWithholdsLabor(VillagerEntity v) {
    if (v.surname.isEmpty || _godMode) return false;
    final w = _houses.withholdingOf(v.surname);
    if (w.labor <= 0) return false;
    return _houseMemberRank(v) < w.labor;
  }

  /// Köylünün hane içindeki sabit sırası 0..1 — kimin önce elini çektiği.
  double _houseMemberRank(VillagerEntity v) =>
      ((v.personalitySeed * 2654435761) & 0xFFFFF) / 0xFFFFF;

  /// Elini çekmiş köylüler ellerindeki işi bıraksın. Yalnız TARAMA aralığında
  /// çalışır (her frame değil) ve işi bırakma anını görünür kılar: köylü aletini
  /// indirir, hane hâline göre kırgın ya da öfkeli durur.
  void _dropWithheldJobs(double elapsed) {
    _withheldGesture -= elapsed;
    final gesture = _withheldGesture <= 0;
    if (gesture) _withheldGesture = _kIdleGesture;
    for (final v in _villagers) {
      if (v.isDying || !v.hasActiveJob) continue;
      if (!_houseWithholdsLabor(v)) continue;
      _releaseJob(v);
      // Oyuncunun elle verdiği iş de düşer — ama KARARI silinmez: hane razı
      // olunca köylü oyuncunun koyduğu işe kendi döner (bkz. scene_jobs
      // `_applyPlayerAssignments`, hastalık deseniyle aynı).
      if (!gesture || v.isSleeping || v.isInsideBuilding) continue;
      v.feel(
        _houses.moodOf(v.surname) < 0.22 ? NpcEmotion.anger : NpcEmotion.grief,
        2.2,
      );
    }
  }

  /// Oyuncu elle iş vermeye kalktı ve hane o kişiyi esirgiyor — reddin
  /// diegetik cevabı. `true` dönerse atama YAPILMAZ.
  bool _refuseAssignment(VillagerEntity v, JobRole role) {
    if (role == JobRole.none || !_houseWithholdsLabor(v)) return false;
    final ctx = _voice(
      v,
      seed: _stableSeed('ret${v.name}', _dayCount),
      extra: {'hane': v.surname},
    );
    _showNotification('✋ ${Voice.say(_kLaborRefusal, ctx)}');
    return true;
  }

  // ── 3. NİKÂH + 4. MASA ──────────────────────────────────────────────────────

  /// Kopmuş hane kız/oğul vermiyor — kur bu köylüye takılmaz.
  bool _houseRefusesBetrothal(VillagerEntity v) =>
      !_godMode &&
      v.surname.isNotEmpty &&
      _houses.withholdingOf(v.surname).betrothal;

  /// Reis masaya oturmuyor — divanda sandalyesi boş kalır.
  bool _houseBoycottsCouncil(String surname) =>
      !_godMode && surname.isNotEmpty && _houses.withholdingOf(surname).council;

  /// Masayı boykot eden hane sayısı — divan başlığı "kaç sandalye boş" desin.
  int get _councilBoycottCount {
    var n = 0;
    for (final s in _houses.surnames) {
      if (_houseBoycottsCouncil(s)) n++;
    }
    return n;
  }

  /// Köyde şu an bir şey esirgeyen haneler (en sert önce — snapshot zaten
  /// esirgeyeni başa alır). Dilekçe kapısı + panel rozeti buradan okur.
  List<HouseSnapshot> get _withholdingHouses => [
    for (final s in _houses.snapshot())
      if (s.stance.withholds) s,
  ];

  /// Hane karşılığı dilekçesinin konusu olan hane — en sert esirgeyen.
  /// null = herkes veriyor, dilekçe ateşlenmez.
  String? get _withholdingHouseSurname {
    final list = _withholdingHouses;
    if (list.isEmpty) return null;
    var worst = list.first;
    for (final h in list) {
      if (h.stance.index > worst.stance.index) worst = h;
    }
    return worst.surname;
  }

  // ── Dilekçe hükümleri ───────────────────────────────────────────────────────
  // Esirgeyen haneyi çözmenin İKİ gerçek yolu. İkisi de merdivenden indirir;
  // biri hâli (mood) yükselterek, diğeri kozu (sway) kırarak. Bedelleri farklı
  // olduğu için karar gerçek bir karardır.

  /// GÖNLÜNÜ AL — hanenin hâli sıçrar, esirgeme çözülür, ambarını açar.
  /// Kese bedeli seçeneğin `goldDelta`'sında (tek kaynak: dilekçe tanımı).
  void _appeaseWithholdingHouse(
    VillagerEntity? author, {
    String? targetSurname,
  }) {
    final surname =
        targetSurname ?? author?.surname ?? _withholdingHouseSurname;
    if (surname == null || surname.isEmpty) return;
    // Merdivenin en az iki basamak inmesini garantileyecek kadar — "gönlünü
    // aldım ama hâlâ elini çekiyor" hissi kararı anlamsız kılardı.
    _houses.nudge(surname, moodDelta: 0.34);
    _chronicle(
      '$surname Hanesi ile arası düzeltildi.',
      icon: '🤝',
      kind: ChronicleKind.decision,
    );
    logDev('hane hükmü: $surname gönlü alındı (+0.34 hâl)');
    // Hanenin insanları da bunu hissetsin — moral gövde dilinden okunur.
    for (final v in _villagers) {
      if (v.isDying || v.surname != surname) continue;
      v.morale = (v.morale + 0.08).clamp(0.0, 1.0);
      if (!v.isSleeping && !v.isInsideBuilding) v.feel(NpcEmotion.wonder, 2.5);
    }
  }

  /// BELİNİ KIR — hâl DÜŞER ama nüfuz kırılır. Koz gidince hane merdivenin
  /// üst basamaklarına çıkamaz (ambar kapatamaz, masa boykot edemez): küskün
  /// ama zararsız. Kesenden çıkmaz, köyün sabrından çıkar.
  void _rebukeWithholdingHouse(VillagerEntity? author) {
    final surname = author?.surname ?? _withholdingHouseSurname;
    if (surname == null || surname.isEmpty) return;
    // Nüfuzun büyük kısmı gider — kalan koz adil payın altına düşsün.
    _houses.drainSway(surname, 1.6);
    _houses.nudge(surname, moodDelta: -0.10);
    _unrest = (_unrest + 0.06).clamp(0.0, 1.0);
    _chronicle(
      '$surname Hanesi\'nin sözü meclis önünde kesildi.',
      icon: '⚖',
      kind: ChronicleKind.decision,
    );
    logDev('hane hükmü: $surname beli kırıldı (−1.6 nüfuz)');
    for (final v in _villagers) {
      if (v.isDying || v.surname != surname) continue;
      if (!v.isSleeping && !v.isInsideBuilding) v.feel(NpcEmotion.anger, 2.5);
    }
  }
}

// ── Hanenin ağzı ([[lib/text/voice.dart]]) ───────────────────────────────────
// Duruş değişimi köyün EN AĞIR haberlerinden biri; tek sabit cümle olamaz.

const _kStanceMurmur = [
  '{hane} Hanesi\'nde bu akşam söylenme var. Henüz kimse işi bırakmadı.',
  '{hane} Hanesi kapısını erken kapadı. Meydanda adın geçiyor.',
  '{ad} bugün iki laf etti, üçüncüsünü yuttu. {hane} Hanesi hoşnut değil.',
];

const _kStanceWithdrawn = [
  '{hane} Hanesi tarlaya çıkmadı. Alet kapıda duruyor.',
  '{ad} adamlarını içeri çağırdı. {hane} Hanesi bugün iş görmüyor.',
  '{hane} Hanesi elini işten çekti. Sebebini söylemeye de gerek görmüyorlar.',
];

const _kStanceHoarding = [
  '{hane} Hanesi ambarının kapağını kendine çevirdi. Köyün payı gelmiyor.',
  '{ad} bu yılki mahsulü kendi kilerine indirdi. {hane} Hanesi paylaşmıyor.',
  '{hane} Hanesi ne emek veriyor ne ürün. Ambar kendi ambarları artık.',
];

const _kStanceDefiant = [
  '{hane} Hanesi koptu. Masaya oturmuyor, kız vermiyor, iş görmüyor.',
  '{ad} sandalyesini geri itti. {hane} Hanesi bu köyün kararını tanımıyor.',
  '{hane} Hanesi ile aramızda söz kalmadı. Kapıları da, ambarları da kapalı.',
];

const _kStanceCooled = [
  '{hane} Hanesi yumuşadı. {ad} sabah yine kapıda göründü.',
  '{hane} Hanesi ile aramız düzeliyor. Aletler yeniden ellerinde.',
  '{ad} dargınlığı bıraktı. {hane} Hanesi köye döndü.',
];

const _kStanceLoyal = [
  '{hane} Hanesi arkanda. {ad} "ne gerekirse" dedi, fazlasını da yapıyor.',
  '{hane} Hanesi sana borçlu hissediyor. Verdiklerinin üstüne veriyorlar.',
  '{ad} hanesini topladı: {hane} Hanesi bu köyün yanında.',
];

const _kStanceAnnal = [
  '{hane} Hanesi\'nin köye karşı hâli değişti.',
  '{hane} Hanesi ile köyün arası yeni bir yere oturdu.',
  '{hane} Hanesi tavrını değiştirdi.',
];

const _kStashOpened = [
  '{hane} Hanesi ambarını açtı. Sakladıkları köyün ambarına iniyor.',
  '{ad} kilerin kapağını kaldırdı. {hane} Hanesi payını geri veriyor.',
  '{hane} Hanesi sakladığını çıkardı. Ambar birkaç gün şişecek.',
];

const _kLaborRefusal = [
  '{ad} işi almadı. {hane} Hanesi şu sıra köye emek vermiyor.',
  '{ad} başını çevirdi. "{hane} Hanesi\'nin elinden şimdilik iş çıkmaz."',
  '{ad} aleti eline almadı bile. Önce hanesiyle aranı düzeltmen gerek.',
];
