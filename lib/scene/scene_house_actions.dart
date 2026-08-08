part of '../main.dart';

/// HANE EYLEMLERİ — oyuncunun hanelere karşı harekete geçtiği katman (uygulama).
///
/// Kurallar ve bedeller SAF katmanda (`systems/house_action.dart`, testli);
/// burası o kararları köye İŞLER: kaynak, hane hâli/nüfuzu, huzursuzluk, moral,
/// kronik ve görünür tepki. Meclis masasında bir reise dokununca açılan kart
/// bu metotları çağırır.
///
/// Bedel modeli: her eylem hedefi kadar DİĞER haneleri de etkiler (korku/
/// kıskançlık), ve aynı haneye üst üste sertlik BASKI biriktirir → bedel
/// katlanır (`_housePressure`). Böylece tek haneyi sağıp durmak işe yaramaz.
extension _SceneHouseActions on _VillageSceneState {
  /// Baskı sayacının yarılanma süresi (oyun günü) — köyün hafızası kısa değil.
  static const double _kPressureTauDays = 6.0;

  // ── Sorgular ───────────────────────────────────────────────────────────────

  /// Bir hanenin canlı üyeleri.
  List<VillagerEntity> _houseMembers(String surname) => [
        for (final v in _villagers)
          if (!v.isDying && v.surname == surname) v,
      ];

  /// Bu haneye yakın geçmişte kaç sert eylem yapıldı (bedel katlayıcı).
  int _houseHarshCount(String surname) =>
      (_housePressure[surname] ?? 0).floor();

  /// Eylem yapılabilir mi (rejim + ferman + kese + hane durumu).
  HouseActionGate _houseActionGate(HouseActionKind kind, String surname) =>
      gateFor(
        kind,
        authority: _compassPos.authority,
        sealedLaws: _policies.sealed,
        members: _houseMembers(surname).length,
        gold: _stockpile.gold,
        grantTier: _grantTierFor(surname),
      );

  /// Eylemin sonucu — UI önizlemede, sahne uygulamada AYNI değerleri kullanır.
  HouseActionOutcome _houseActionOutcome(
          HouseActionKind kind, String surname) =>
      outcomeOf(
        kind,
        members: _houseMembers(surname).length,
        recentHarsh: _houseHarshCount(surname),
        authoritarian: _compassPos.authority >= 0.15,
        grantTier: _grantTierFor(surname) ?? 2,
      );

  // ── Uygulama ───────────────────────────────────────────────────────────────

  /// Bir hane eylemini uygular. Kapı kapalıysa hiçbir şey yapmaz (UI zaten
  /// göstermez; bu ikinci savunma hattı).
  void _applyHouseAction(HouseActionKind kind, String surname) {
    final gate = _houseActionGate(kind, surname);
    if (!gate.open) {
      _showNotification('⚖ ${gate.reason}');
      return;
    }
    final o = _houseActionOutcome(kind, surname);

    setStateHere(() {
      // 1) Kaynak.
      if (o.gold != 0) _stockpile.gold = (_stockpile.gold + o.gold).clamp(0, 1 << 30);
      if (o.food != 0) _stockpile.food = (_stockpile.food + o.food).clamp(0, 1 << 30);

      // 2) Hedef hane + öteki haneler (köy izler).
      if (o.targetMood != 0 || o.targetSway != 0) {
        _houses.nudge(surname,
            moodDelta: o.targetMood,
            swayGain: o.targetSway > 0 ? o.targetSway : 0);
        // nudge yalnız POZİTİF nüfuz ekler; kırılma ayrıca uygulanır.
        if (o.targetSway < 0) _drainHouseSway(surname, -o.targetSway);
      }
      if (o.otherMood != 0) _nudgeOtherHouses(surname, o.otherMood);

      // 3) Köyün sabrı ve morali.
      if (o.unrest != 0) {
        _unrest = (_unrest + o.unrest).clamp(0.0, 1.0);
      }
      if (o.villageMorale != 0) {
        pushPolicyMorale(o.villageMorale, o.moraleDays);
      }

      // 4) Sert eylem baskı biriktirir (bir sonraki sefer daha pahalı).
      if (kind.harsh) {
        _housePressure[surname] = (_housePressure[surname] ?? 0) + 1.0;
      }

      // 5) Eyleme özel gerçek sonuç.
      switch (kind) {
        case HouseActionKind.grant:
          _actGrant(surname);
        case HouseActionKind.punish:
          _actPunish(surname);
        case HouseActionKind.seize:
          _actSeize(surname, o);
        case HouseActionKind.betroth:
          _actBetroth(surname);
        case HouseActionKind.exile:
          _actExile(surname);
        case HouseActionKind.scheme:
          _actScheme(surname);
      }
    });
  }

  /// Nüfuz kırma — [HouseSystem.nudge] yalnız nüfuz EKLER (kararlar biriktirir);
  /// eylemle nüfuz kırmak yeni bir yetenek, o yüzden ayrı kapıdan.
  void _drainHouseSway(String surname, double amount) =>
      _houses.drainSway(surname, amount);

  /// Hedef DIŞINDAKİ hanelerin hâlini oynatır — korku ya da kıskançlık.
  void _nudgeOtherHouses(String except, double moodDelta) {
    for (final s in _houses.surnames.toList()) {
      if (s == except) continue;
      _houses.nudge(s, moodDelta: moodDelta);
    }
  }

  // ── Eylemler ───────────────────────────────────────────────────────────────

  /// 🎁 MÜLK BAĞIŞLA — hane güçlenir ve sana borçlanır. Ötekiler kıskanır.
  /// Dikkat: bağış hedefin NÜFUZUNU da büyütür; beslediğin hane bir gün köyün
  /// gölgesi olabilir (kayırmanın uzun vadeli bedeli).
  void _actGrant(String surname) {
    final members = _houseMembers(surname);
    final head = headOfHouse(members);
    final tier = _grantTierFor(surname);
    if (head == null || tier == null) return;

    // Bağış ARTIK GERÇEK: köy hanenin adına yeni bir konut diker ve hane oraya
    // taşınır. (Mevcut evi "yükseltmek" yok — konut zinciri yükseltme değil,
    // yan yana yaşayan kademelerdir; bu yüzden yeni mülk KURULUR.)
    final b = _buildGrantedHome(surname, tier, head);
    if (b == null) {
      // Yer bulunamadı — bağış yapılmadı, kese de dokunulmamış sayılsın.
      _stockpile.gold += grantCost(members.length, tier);
      _showNotification('🎁 Köyde bu mülkü dikecek uygun boş yer yok.');
      return;
    }

    // Hane taşınır: reis + kendi hanesinden olan yakınları yeni mülke geçer
    // (kapasite kadar). Eski ev boşalır, köyde kalır.
    final cap = (b.fn?.housingCapacity ?? 1).clamp(1, 99);
    final movers = <VillagerEntity>[head];
    for (final v in members) {
      if (movers.length >= cap) break;
      if (identical(v, head)) continue;
      movers.add(v);
    }
    for (final v in movers) {
      v.homeBuilding = b;
    }
    b.occupants = movers.length;

    head.feel(NpcEmotion.joy, 6.0, moodDelta: 0.10);
    _lifeEvent(head, '${_grantTierName(tier)} bağışı aldı',
        icon: '🎁', milestone: true);
    _chronicle(
        '$surname Hanesine ${_grantTierName(tier).toLowerCase()} bağışlandı; '
        'ocakları bu akşam yeni bir çatının altında yandı.',
        icon: '🎁', milestone: true);
    _showNotification(
        '🎁 $surname Hanesi ${_grantTierName(tier).toLowerCase()} aldı — '
        'minnet de nüfuz da onların.');
  }

  /// Bu haneye bağışlanacak MÜLK KADEMESİ — hâlihazırda oturdukları en iyi
  /// konutun bir üstü. Zaten konaktalarsa null (bağışlanacak daha iyisi yok).
  int? _grantTierFor(String surname) {
    var best = 0;
    for (final v in _houseMembers(surname)) {
      final (_, t) = _housingInfo(v);
      if (t > best) best = t;
    }
    final next = best + 1;
    return next >= 2 && next <= 4 ? next : (best == 0 ? 2 : null);
  }

  String _grantTierName(int tier) => switch (tier) {
        4 => 'Konak',
        3 => 'Taş Ev',
        _ => 'Ahşap Ev',
      };

  BuildingType _grantTypeFor(int tier, String surname) => switch (tier) {
        4 => BuildingType.manor,
        3 => surname.hashCode.isEven
            ? BuildingType.stoneHouseBlue
            : BuildingType.stoneHouseGreen,
        _ => BuildingType.woodenHouse,
      };

  /// Bağışlanan konutu hanenin mevcut evine YAKIN boş bir yere diker. Yer
  /// bulunamazsa null (çağıran bedeli iade eder).
  BuildingEntity? _buildGrantedHome(
      String surname, int tier, VillagerEntity head) {
    final type = _grantTypeFor(tier, surname);
    final home = head.homeBuilding as BuildingEntity?;
    final (vcx, vcy) = _villageCenter();
    final oc = home?.col ?? vcx;
    final orr = home?.row ?? vcy;

    // Evinin çevresinden başlayıp halka halka dışa doğru uygun yer ara.
    for (int rad = 2; rad <= 14; rad++) {
      for (int dc = -rad; dc <= rad; dc++) {
        for (int dr = -rad; dr <= rad; dr++) {
          if (dc.abs() != rad && dr.abs() != rad) continue; // yalnız halka
          final c = oc + dc, r = orr + dr;
          if (!_isValidPlacement(c, r, type)) continue;
          final b = BuildingEntity(type: type, col: c, row: r);
          b.ownerSurname = surname; // mülkün sahibi belli
          _buildings.add(b);
          _onBuildingCompleted(
              BuildOrder(type: type, col: c, row: r)..completed = true);
          _anchorSystem.rebuild(_buildings);
          return b;
        }
      }
    }
    return null;
  }

  /// ⚖ CEZA KES — kan dökmeden hizaya getirme. Hane küser, köy ürperir.
  void _actPunish(String surname) {
    final members = _houseMembers(surname);
    for (final v in members.take(4)) {
      v.feel(NpcEmotion.grief, 5.0, moodDelta: -0.08);
    }
    _chronicle('$surname Hanesi meydanda cezalandırıldı; kimse sesini çıkarmadı.',
        icon: '⚖');
    _showNotification('⚖ $surname Hanesine ceza kesildi.');
  }

  /// 🏚 MALA EL KOY — ambar mühürlenir. Tek kaynak kazandıran eylem, bu yüzden
  /// en ağır siyasi bedeli öder (bkz. outcomeOf).
  void _actSeize(String surname, HouseActionOutcome o) {
    final members = _houseMembers(surname);
    for (final v in members) {
      v.feel(NpcEmotion.anger, 6.0, moodDelta: -0.12);
    }
    // SAKLADIKLARI DA ÇIKAR — hane küskünlükten ötürü ürününü kendi ambarına
    // indirdiyse (bkz. scene_house_stance) mühür onu da bulur. "Mala el koy"un
    // esirgeyen haneye karşı asıl anlamı bu: gizlediğini görünür kılar.
    final hidden = _houses.drainStash(surname);
    if (hidden > 0) _stockpile.food += hidden;
    _chronicle(
        '$surname Hanesinin ambarı mühürlendi: ${o.gold} altın, '
        '${o.food + hidden} kile köyün kesesine yazıldı.',
        icon: '🏚', milestone: true);
    _showNotification(hidden > 0
        ? '🏚 $surname Hanesinin malına el kondu — sakladıkları $hidden kile '
            'de ambara indi.'
        : '🏚 $surname Hanesinin malına el kondu — köy bunu konuşacak.');
  }

  /// 💍 NİKÂH BAĞLA — iki haneyi kanla bağlar. Hür rejimde öneri, baskıda
  /// zorlama. Organik kur AYNI EVİ şart koşar; siyasi nikâh tanımı gereği
  /// haneler arasıdır → [_betrothalForced] o şartı gevşetir.
  void _actBetroth(String surname) {
    final pair = _findPoliticalMatch(surname);
    if (pair == null) {
      _showNotification('💍 Nikâh bağlanacak uygun çift bulunamadı.');
      return;
    }
    final (bride, groom) = pair;
    _brideElect = bride;
    _groomElect = groom;
    _betrothalForced = true;
    _courtshipTimer = 0.4 * kGameDaySeconds; // siyasi nikâh beklemez
    bride.feel(NpcEmotion.fear, 4.0, moodDelta: -0.06);
    groom.feel(NpcEmotion.fear, 4.0, moodDelta: -0.06);
    final other = bride.surname == surname ? groom.surname : bride.surname;
    _chronicle(
        '${bride.name} ile ${groom.name} nikâhla bağlandı — $surname ile $other '
        'artık aynı kandan sayılıyor.',
        icon: '💍', milestone: true);
    _showNotification('💍 ${bride.name} ile ${groom.name} nikâha bağlandı.');
  }

  /// Siyasi nikâh için çift: hedef haneden evlenmemiş bir yetişkin + BAŞKA
  /// haneden evlenmemiş bir yetişkin (karşı cins, kan bağı yok). En nüfuzlu
  /// öteki hane tercih edilir — nikâh bir ittifaktır, rastgele değil.
  (VillagerEntity, VillagerEntity)? _findPoliticalMatch(String surname) {
    bool eligible(VillagerEntity v) =>
        !v.isDying && !v.wed && v.lifeStage == LifeStage.adult;

    final ours = _houseMembers(surname).where(eligible).toList();
    if (ours.isEmpty) return null;

    // Öteki haneleri nüfuza göre sırala (en güçlüsüyle bağ kurmak yeğdir).
    final others = <VillagerEntity>[];
    for (final s in _houses.snapshot()) {
      if (s.surname == surname) continue;
      others.addAll(_houseMembers(s.surname).where(eligible));
    }
    if (others.isEmpty) return null;

    for (final a in ours) {
      for (final b in others) {
        if (a.isMale == b.isMale) continue;
        if (a.parents.contains(b) || a.children.contains(b)) continue;
        if (a.parents.any(b.parents.toSet().contains)) continue; // kardeş
        return a.isMale ? (b, a) : (a, b); // (gelin, damat)
      }
    }
    return null;
  }

  /// 🚷 SÜRGÜNE YOLLA — hanenin REİSİNİ köyden atar. En sert hüküm: soy
  /// başsız kalır, köy korkar. Kapı zaten son canı korur (soy tükenmesin).
  void _actExile(String surname) {
    final head = headOfHouse(_houseMembers(surname));
    if (head == null) return;
    _chronicle('$surname Hanesinin reisi ${head.name} yola vuruldu.',
        icon: '🚷', milestone: true);
    _exileVillager(head); // mevcut sürgün mekanizması (kronik + moral + tepki)
  }

  /// 🕯 GİZLİ İŞ ÇEVİR — hanenin nüfuzunu sessizce kırar. Kimse bilmez… ta ki
  /// ifşa olana dek. Hür rejimde kulak çoktur, risk yüksektir.
  void _actScheme(String surname) {
    final share = _houses.swayShare(surname);
    final risk = schemeExposureChance(
        authority: _compassPos.authority, targetSwayShare: share);
    final exposed = _rng.nextDouble() < risk;
    logDev('🕯 entrika: $surname · ifşa riski %${(risk * 100).round()} → '
        '${exposed ? 'İFŞA' : 'sessiz'}');

    if (!exposed) {
      _chronicle('$surname Hanesinin işleri sebepsiz aksadı; kimse nedenini bilmiyor.',
          icon: '🕯');
      _showNotification('🕯 İş görüldü. Kimse bir şey bilmiyor.');
      return;
    }

    // İFŞA — entrikanın gerçek bedeli. Hane küplere biner, köy sana bakar.
    _houses.nudge(surname, moodDelta: -0.28);
    _nudgeOtherHouses(surname, -0.10);
    _unrest = (_unrest + 0.14).clamp(0.0, 1.0);
    pushPolicyMorale(-0.07, 4.0);
    _housePressure[surname] = (_housePressure[surname] ?? 0) + 1.0;
    for (final v in _houseMembers(surname)) {
      v.feel(NpcEmotion.anger, 6.0, moodDelta: -0.14);
    }
    _chronicle(
        'Fısıltı büyüdü: $surname Hanesinin başına gelenler tesadüf değilmiş. '
        'Parmaklar seni gösteriyor.',
        icon: '👁', milestone: true);
    _showNotification('👁 Entrikan ifşa oldu — köy senden şüpheleniyor.');
  }

  // ── Zaman ──────────────────────────────────────────────────────────────────

  /// Baskı sayacı sönümlenir — köy unutur, ama yavaş. Sert davrandığın haneye
  /// bir süre dokunmazsan bedel normale döner.
  void _tickHousePressure(double dt) {
    if (_housePressure.isEmpty || dt <= 0) return;
    final k = (dt / (_kPressureTauDays * kGameDaySeconds)).clamp(0.0, 1.0);
    final gone = <String>[];
    for (final e in _housePressure.entries) {
      final v = e.value - e.value * k;
      if (v <= 0.02) {
        gone.add(e.key);
      } else {
        _housePressure[e.key] = v;
      }
    }
    for (final k2 in gone) {
      _housePressure.remove(k2);
    }
  }
}

/// HANELERİN KARŞILIĞI — entrika tek yönlü değildir. Ezdiğin hane susmaz:
/// ittifak kurar, ambarını saklar, husumet körükler, meclisi sana karşı toplar,
/// arkandan konuşur. Böylece "buton menüsü" politik bir masaya döner.
///
/// Tetik: hanenin KÜSKÜNLÜĞÜ (mood düşük) + BASKI geçmişi (`_housePressure`).
/// Yani entrika rastgele gürültü değil, senin davranışının faturasıdır.
extension _SceneHouseIntrigue on _VillageSceneState {
  /// Kaç oyun gününde bir hane entrika denemesi yoklanır.
  static const double _kIntrigueScanDays = 1.0;

  /// Bu hâlin altındaki hane entrika düşünmeye başlar.
  static const double _kGrudgeMood = 0.38;

  void _tickHouseIntrigue(double dt) {
    if (_villagers.length < 4) return; // küçük köyde entrika olmaz
    _houseIntrigueScan -= dt;
    if (_houseIntrigueScan > 0) return;
    _houseIntrigueScan = _kIntrigueScanDays * kGameDaySeconds;

    // En küskün + en çok ezilmiş haneyi bul (fatura ilk ona kesilir).
    HouseSnapshot? worst;
    var worstScore = 0.0;
    for (final h in _houses.snapshot()) {
      if (h.members <= 0 || h.mood >= _kGrudgeMood) continue;
      final pressure = _housePressure[h.surname] ?? 0;
      final score = (_kGrudgeMood - h.mood) * 2.0 + pressure * 0.5;
      if (score > worstScore) {
        worstScore = score;
        worst = h;
      }
    }
    if (worst == null) return;

    // Kırgınlık ne kadar derinse o kadar çok ihtimal. Tavan %55 — köy her gün
    // komplo kurmasın, entrika NADİR ve anlamlı kalsın.
    final chance = (0.10 + worstScore * 0.22).clamp(0.0, 0.55);
    final roll = _rng.nextDouble();
    logDev('🕯 hane entrikası: ${worst.surname} · kırgınlık '
        '${worstScore.toStringAsFixed(2)} · şans %${(chance * 100).round()} '
        '→ ${roll < chance ? 'İŞ ÇEVİRDİ' : 'sessiz'}');
    if (roll >= chance) return;

    _runHouseIntrigue(worst);
  }

  /// Küskün hanenin hamlesi — seçenekler duruma göre elenir (ittifak için
  /// ikinci bir küskün hane, husumet için uygun kurban gerekir).
  void _runHouseIntrigue(HouseSnapshot h) {
    final moves = <String>['hoard', 'rumor', 'rally'];
    // İttifak: başka bir küskün hane varsa.
    final allies = [
      for (final o in _houses.snapshot())
        if (o.surname != h.surname && o.members > 0 && o.mood < 0.46) o,
    ];
    if (allies.isNotEmpty) moves.add('ally');
    // Husumet körükleme: köy kalabalıksa ve zaten kan davası yoksa.
    if (_villagers.length >= 8 && _feudMember() == null) moves.add('stoke');

    final move = moves[_rng.nextInt(moves.length)];
    setStateHere(() {
      switch (move) {
        case 'ally':
          final ally = allies[_rng.nextInt(allies.length)];
          // İki küskün hane birleşir: ikisi de nüfuz kazanır, köy kutuplaşır.
          _houses.nudge(h.surname, swayGain: 0.9);
          _houses.nudge(ally.surname, swayGain: 0.7);
          _unrest = (_unrest + 0.05).clamp(0.0, 1.0);
          _chronicle(
              '${h.surname} ile ${ally.surname} haneleri sofrayı birleştirdi. '
              'İki küskün bir arada, artık tek ses.',
              icon: '🤝', milestone: true);
          _showNotification(
              '🤝 ${h.surname} ve ${ally.surname} el sıkıştı — bu ittifak sana karşı.');

        case 'hoard':
          // Ambarı saklar: köy kesesi/erzağı sessizce eksilir.
          final gold = 3 + _rng.nextInt(5);
          final food = 4 + _rng.nextInt(6);
          _stockpile.gold = (_stockpile.gold - gold).clamp(0, 1 << 30);
          _stockpile.food = (_stockpile.food - food).clamp(0, 1 << 30);
          _houses.nudge(h.surname, moodDelta: 0.04); // işlerine geldi
          _chronicle(
              '${h.surname} Hanesi payını ambara götürmedi; defterde eksik var.',
              icon: '🏚');
          _showNotification('🏚 ${h.surname} Hanesi mahsulünü sakladı '
              '(−$gold altın, −$food erzak).');

        case 'stoke':
          // Husumet körükler — kan davası köyü zehirler, fatura sana çıkar.
          if (_devIgniteFeud()) {
            _unrest = (_unrest + 0.06).clamp(0.0, 1.0);
            _chronicle(
                '${h.surname} Hanesi eski bir husumeti kaşıdı; kan yeniden aktı.',
                icon: '🩸', milestone: true);
            _showNotification('🩸 ${h.surname} Hanesi husumeti körükledi.');
          }

        case 'rally':
          // Meclisi sana karşı toplar: huzursuzluk + moral sızıntısı.
          _unrest = (_unrest + 0.09).clamp(0.0, 1.0);
          pushPolicyMorale(-0.05, 3.0);
          _nudgeOtherHouses(h.surname, -0.03);
          _chronicle(
              '${h.surname} Hanesi meclisi kendi çatısı altında topladı. '
              'Konuşulanı sen duymadın.',
              icon: '⚖', milestone: true);
          _showNotification('⚖ ${h.surname} Hanesi meclisi sana karşı topluyor.');

        default: // rumor
          pushPolicyMorale(-0.035, 3.0);
          _nudgeOtherHouses(h.surname, -0.04);
          _unrest = (_unrest + 0.03).clamp(0.0, 1.0);
          _chronicle(
              'Köyde bir söylenti dolaşıyor; kaynağı ${h.surname} Hanesinin kapısı.',
              icon: '👁');
          _showNotification('👁 ${h.surname} Hanesi arkandan konuşuyor.');
      }
    });
  }
}

/// TOPYEKÛN EL KOYMA — mülkiyetin kaldırılması. Tek bir haneyi cezalandırmak
/// bir hüküm, TÜM mülke el koymak bir rejim değişikliğidir: bir kez yapılır,
/// geri alınmaz ve köyün hafızasına kalıcı olarak yazılır.
extension _SceneMassSeizure on _VillageSceneState {
  /// Kamulaştırılabilecek konutlar (sakini olsun olmasın, konut olan her yapı).
  List<BuildingEntity> _privateHomes() => [
        for (final b in _buildings)
          if ((b.fn?.housingCapacity ?? 0) > 0 && b.ownerSurname != kPublicOwner)
            b,
      ];

  bool get _massSeizureDone => _villageMemory.contains(kMassSeizureFlag);

  HouseActionGate _massSeizureGate() => massSeizureGate(
        authority: _compassPos.authority,
        economy: _compassPos.economy,
        sealedLaws: _policies.sealed,
        alreadyDone: _massSeizureDone,
        houseCount: _houses.houseCount,
      );

  /// Divan'daki kamulaştırma kartı — kapalıysa GEREKÇESİYLE görünür ki oyuncu
  /// bu yolun var olduğunu ve neyin eksik olduğunu bilsin.
  HouseActionEntry _massSeizureEntry() {
    final gate = _massSeizureGate();
    final homes = _privateHomes().length;
    final y = massSeizureYield(homes);
    return HouseActionEntry(
      icon: '⚑',
      label: 'MÜLKİYETİ KALDIR',
      detail: gate.open
          ? 'Köydeki $homes konutun tapusu köye geçer. Hiçbir hane bir daha '
              '"benim" diyemez. Geri dönüşü yok.'
          : gate.reason!,
      effects: gate.open
          ? [
              '+${y.gold} altın',
              '+${y.food} erzak',
              '+${y.wood} kereste',
              'tüm haneler −0.35',
              'huzursuzluk +0.30',
            ]
          : const [],
      enabled: gate.open,
      onTap: gate.open ? _applyMassSeizure : null,
    );
  }

  void _applyMassSeizure() {
    final gate = _massSeizureGate();
    if (!gate.open) return;
    final homes = _privateHomes();
    final y = massSeizureYield(homes.length);

    setStateHere(() {
      // 1) Tapular köye geçer.
      for (final b in homes) {
        b.ownerSurname = kPublicOwner;
      }

      // 2) Köyün kesesi dolar — bir defalık, büyük.
      _stockpile.gold += y.gold;
      _stockpile.food += y.food;
      _stockpile.wood += y.wood;

      // 3) HER hane kanar + nüfuzları düzlenir (kamulaştırmanın asıl anlamı:
      //    artık kimsenin ötekinden fazlası yok).
      for (final s in _houses.surnames.toList()) {
        _houses.nudge(s, moodDelta: -0.35);
        _houses.drainSway(s, 99.0); // hepsi tabana → baskın hane kalmaz
        _housePressure[s] = (_housePressure[s] ?? 0) + 1.0;
      }

      // 4) Köy sarsılır.
      _unrest = (_unrest + 0.30).clamp(0.0, 1.0);
      pushPolicyMorale(-0.12, 6.0);
      _feelVillage(NpcEmotion.fear, 20, -0.18);

      // 5) Kalıcı iz — bir daha yapılamaz, Divan'da mühür olarak durur.
      _villageMemory.add(kMassSeizureFlag);

      _chronicle(
          'Mülkiyet kaldırıldı. ${homes.length} konutun tapusu köye geçti; '
          'o gece hiçbir kapı kendi kilidiyle kapanmadı.',
          icon: '⚑', milestone: true);
      _showNotification('⚑ Mülkiyet kaldırıldı — artık her çatı köyün.');
    });
  }
}
