part of '../main.dart';

/// ─── KIŞ: HAZIRLIK, YÜN ZİNCİRİ, İHMAL ───────────────────────────────────────
///
/// Kışın matematiği [systems/winter.dart]'ta (saf); burası onu köye bağlar:
///
///   • **Kırkım** — sonbaharda çoban koyunu kırkar → yün. Yılda bir kez.
///   • **Dokuma** — [JobRole.weaver] yünü kışlık giysiye çevirir. Kışın
///     tarla donunca kadronun boşa düşmediği yer burası.
///   • **Dağıtım** — giysi kime? Oyuncunun kararı ([CoatPriority]); köy
///     kendiliğinden en kırılganı giydirmez, oyuncunun dediğini yapar.
///   • **Ev ocağı** — kışın haneler de yakacak yer. Önceden yalnız meydan
///     ateşi yakıt istiyordu, yani taş ev diken köy kışı bedelsiz çıkarıyordu.
///   • **Hazırlık** — köy kışa hazır mı; sonbaharın son günü köy konuşur.
///   • **İhmal** — kış tek başına öldürmez; ihmaller BİRİKİNCE hastalık
///     ağırlaşır (bkz. scene_illness).
///
/// TASARIM: kış cezalandırmaz, hazırlığı ödüllendirir. Hazırlıklı köyde kış
/// sakin ve güzeldir (uzun ateş başı akşamları, tezgâh sesi); hazırlıksız
/// köyde ağır. Hiçbir mekanik oyuncuyu "kaybettirmez" — yalnız pahalıya
/// mal olur.
extension _SceneWinter on _VillageSceneState {
  // ── Sabitler ─────────────────────────────────────────────────────────────

  /// Bir koyundan bir kırkımda çıkan yün.
  ///
  /// AYAR NOTU: ilk değer 2'ydi ve kışlık zinciri anlamsız kalıyordu —
  /// referans köyün iki koyunu yılda 4 yün, yani TEK giysi veriyordu. "Kime
  /// giysi" bir dağıtım kararı değil, bir şakaydı. 4 yün/koyun ile aynı köy
  /// yılda ~2 giysi çıkarır; herkesi giydirmek isteyen köy SÜRÜSÜNÜ BÜYÜTMEK
  /// zorunda kalır. Kışın çobanlığa bağlanması bilinçli: kışlık giysi para
  /// değil emek ve zaman ister.
  static const int _kWoolPerSheep = 4;

  /// Bir kışlık giysi kaç yün yer.
  static const int _kWoolPerCoat = 3;

  /// Tezgâh başında bir giysinin dokunma süresi (sn, sim zamanı).
  static const double _kWeaveDuration = 9.0;

  /// Kırkım menzili + çobanın kırkım molası.
  static const double _kShearRange = 1.7;
  static const double _kShearCooldown = 2.2;

  /// Ev ocağı yakıt taraması — gün başına bir kez yeter (bkz. `_winterDay`).
  static const double _kHearthFuelScan = 1.0;

  // ── Kırkım ───────────────────────────────────────────────────────────────

  /// Sonbahar geldiğinde sürüyü yeniden kırkılabilir yap.
  ///
  /// Mevsim dönüşünü sahne zaten izliyor (`_lastSeason`), ama kırkım bayrağını
  /// oraya gömmek mevsim kodunu yün'e bağlardı; kışın kendi dosyası kendi
  /// bayrağını sıfırlar.
  void _resetShearing() {
    for (final a in _cows) {
      a.shorn = false;
    }
  }

  /// Çobanın kırkım hamlesi — sonbaharda, kırkılmamış bir koyun yakınındaysa.
  ///
  /// `true` dönerse çoban bu tick'te kırkımla meşguldür ve normal güdüm
  /// döngüsü (otlatma/bekçilik) atlanır.
  bool _tryShear(VillagerEntity v) {
    if (_season != Season.autumn) return false;
    if (v.workCooldown > 0) return false;
    AnimalEntity? target;
    var bestD = 1e9;
    for (final a in _cows) {
      if (a.kind != AnimalKind.sheep || a.shorn || a.isDying) continue;
      final d = _wdist(v.gridX, v.gridY, a.gridX, a.gridY);
      if (d < bestD) {
        bestD = d;
        target = a;
      }
    }
    if (target == null) return false;
    if (bestD < _kShearRange) {
      target.shorn = true;
      _stockpile.wool += _kWoolPerSheep;
      v.feel(NpcEmotion.content, 3.0, moodDelta: 0.02);
      v.lookToward(target.gridX, target.gridY);
      _setWorkPose(v, ActPose.stoop);
      v.workCooldown = _kShearCooldown;
      logDev('🧶 ${v.name} bir koyun kırktı (+$_kWoolPerSheep yün)',
          tag: '🧶');
      if (!_firstShearShown) {
        _firstShearShown = true;
        _showNotification(Voice.say(_kFirstShearPool,
            _voice(v, seed: _stableSeed('kırkım', _dayCount))));
      }
    } else if (!_enRouteTo(v, target.gridX, target.gridY)) {
      v.goTo(target.gridX, target.gridY, 1.0);
    }
    return true;
  }

  // ── Dokuma ───────────────────────────────────────────────────────────────

  /// Tezgâhın yeri — ambar varsa orası (yün orada durur), yoksa ocak başı.
  /// Yeni bina İSTEMEZ: kış işinin ayrı bir yapı beklemesi, kışı oyuncunun
  /// önceden bilmesi gereken bir sınava çevirirdi.
  BuildingEntity? get _loomSpot {
    for (final b in _buildings) {
      if (b.type == BuildingType.warehouse) return b;
    }
    return _firepitBuilding;
  }

  /// DOKUMACI — yünü kışlık giysiye çevirir.
  ///
  /// Aşçı döngüsünün kardeşi (bkz. scene_forage `_runCook`): hedefe yürü,
  /// başında dur, sayaç dolunca ürün. Fark: ürün stoğa değil KÖYÜN SIRTINA
  /// gider (`_coatsMade` → dağıtım).
  void _runWeaver(VillagerEntity v, double dt) {
    final job = v.job!;
    final spot = _loomSpot;
    if (spot == null) {
      job.working = false;
      job.harvesting = false;
      return;
    }
    // Yün yoksa ya da köyün herkesi giyindiyse tezgâh başında bekleme.
    if (_stockpile.wool < _kWoolPerCoat || !_coatsNeeded) {
      job.working = false;
      job.harvesting = false;
      job.phase = 0;
      job.timer = 0;
      return;
    }

    final tx = spot.col + spot.cols / 2.0, ty = spot.row + spot.rows / 2.0;
    if (job.phase == 0) {
      final dx = v.gridX - tx, dy = v.gridY - ty;
      if (dx * dx + dy * dy <= 1.8 * 1.8) {
        v.state = VillagerState.idle;
        v.facingRight = tx > v.gridX;
        job.phase = 1;
        job.timer = 0;
        job.phaseAnim = 0;
      } else if (!_enRouteTo(v, tx, ty)) {
        final free = _freeSpotNear(tx, ty, 1.6);
        v.goTo(free?.$1 ?? tx, free?.$2 ?? ty, 0.2);
      }
      return;
    }

    job.working = true;
    job.harvesting = true; // tezgâh başında eğilme duruşu
    v.idleTimer = 0.5;
    job.timer += dt;
    job.phaseAnim = (job.phaseAnim + dt * 2 * pi * 0.8) % (2 * pi);
    if (job.timer >= _kWeaveDuration) {
      job.timer = 0;
      if (_stockpile.wool >= _kWoolPerCoat && _coatsNeeded) {
        _stockpile.wool -= _kWoolPerCoat;
        _coatsMade++;
        v.feel(NpcEmotion.content, 3, moodDelta: 0.03);
        if (!_firstCoatShown) {
          _firstCoatShown = true;
          _showNotification(Voice.say(_kFirstCoatPool,
              _voice(v, seed: _stableSeed('ilkgiysi', _dayCount))));
          _feelVillage(NpcEmotion.joy, 3, 0.03);
        }
      }
    }
  }

  /// Giyinmemiş kimse kaldı mı — dokumacının durma koşulu.
  bool get _coatsNeeded {
    for (final v in _villagers) {
      if (!v.isDying && !v.hasCoat) return true;
    }
    return false;
  }

  // ── Dağıtım ──────────────────────────────────────────────────────────────

  /// Dokunan giysileri sırtlara dağıtır — oyuncunun seçtiği önceliğe göre.
  ///
  /// Köy kendiliğinden "en doğru"yu yapmaz. Kime giysi sorusunun cevabı bir
  /// yönetim kararıdır ve sonucu görünür: kışın hangi hane titrer, hangi
  /// çocuk hasta olur, bu seçimden çıkar.
  void _distributeCoats() {
    if (_coatsMade <= 0) return;
    final pool = <VillagerEntity>[
      for (final v in _villagers)
        if (!v.isDying && !v.hasCoat) v,
    ];
    if (pool.isEmpty) return;
    pool.sort((a, b) => _coatRank(a).compareTo(_coatRank(b)));
    while (_coatsMade > 0 && pool.isNotEmpty) {
      final who = pool.removeAt(0);
      who.hasCoat = true;
      _coatsMade--;
      who.feel(NpcEmotion.content, 3, moodDelta: 0.05);
    }
  }

  /// Sıralama anahtarı — KÜÇÜK olan önce giyinir.
  int _coatRank(VillagerEntity v) => switch (_coatPriority) {
    // Kırılgan önce: çocuk ve yaşlı. Köyün "insanca" seçimi; karşılığında
    // tarlada/ormanda çalışan üşür ve işi yavaşlar.
    CoatPriority.frail => switch (v.lifeStage) {
      LifeStage.child => 0,
      LifeStage.elder => 1,
      _ => 2,
    },
    // Çalışan önce: köy üretimi düşmesin. Soğuk, evde oturana kalır.
    CoatPriority.workers => v.hasActiveJob ? 0 : (v.hasProfession ? 1 : 2),
    // Hane hane, sırayla: kimse ayrıcalıklı değil, kimse unutulmaz.
    // Soyadın kararlı sırası + hane içi yaş → aynı hanenin ikinci kişisi
    // sıraya girmeden diğer hanenin ilki giyinir.
    CoatPriority.households => v.surname.hashCode.abs() % 97,
  };

  // ── Ev ocağı ─────────────────────────────────────────────────────────────

  /// KIŞIN HANELER DE YAKAR. Gün başına bir kez: dolu her ev/çadır ocağı için
  /// yakacak düşülür. Odun biterse kömür yakılır; ikisi de yoksa hane SOĞUK
  /// kalır ve sakinleri gece üşür (bkz. `_houseHearthCold`).
  ///
  /// Neden gün başına: her tick düşmek kesirli stok muhasebesi ister ve
  /// oyuncunun ambarı "sızıyor" gibi görünürdü. Kış bir GÜNLÜK muhasebedir.
  void _tickHouseHearths() {
    if (_season != Season.winter) {
      if (_coldHouses.isNotEmpty) _coldHouses.clear();
      return;
    }
    var need = 0.0;
    final lit = <BuildingEntity>[];
    for (final b in _buildings) {
      if (kBuildingFunctions[b.type]?.housingCapacity == null) continue;
      if ((kBuildingFunctions[b.type]?.housingCapacity ?? 0) <= 0) continue;
      // Çadırın ocağı yoktur — sıcağı meydandan gelir (bkz. hearth_warmth).
      if (b.type == BuildingType.tent) continue;
      if (!_villagers.any((v) => v.homeBuilding == b)) continue;
      lit.add(b);
      need += kHouseHearthFuelPerDay;
    }
    _coldHouses.clear();
    if (lit.isEmpty) return;

    // Önce odun, yetmezse kömür. Kömür daha uzun yanar → daha az adet gider.
    var paid = 0.0;
    final wood = min(_stockpile.wood, need.ceil());
    _stockpile.wood -= wood;
    paid += wood;
    if (paid < need) {
      final short = need - paid;
      final coal = min(_stockpile.coal, (short / kCoalFuelValue).ceil());
      _stockpile.coal -= coal;
      paid += coal * kCoalFuelValue;
    }
    if (paid >= need) return;

    // Yakacak yetmedi: en uzaktaki hanelerden başlayarak ocaklar söner.
    // "En uzak" bilinçli: köy merkezine yakın olan ateşten de ısınır, kenardaki
    // hane tamamen kendi başınadır — mesafenin kışın bedeli olması kuralı
    // burada da geçerli (bkz. cold-tent).
    final coldCount =
        ((need - paid) / kHouseHearthFuelPerDay).ceil().clamp(0, lit.length);
    lit.sort((a, b) => _hearthDistanceOf(b).compareTo(_hearthDistanceOf(a)));
    for (var i = 0; i < coldCount; i++) {
      _coldHouses.add(lit[i]);
    }
    if (_coldHouses.isNotEmpty && _winterMurmurDay != _dayCount) {
      _winterMurmurDay = _dayCount;
      _showNotification(Voice.say(
          _kColdHousePool, _voice(null, seed: _stableSeed('soğukev', _dayCount))));
      _feelVillage(NpcEmotion.fear, 4, -0.04);
    }
  }

  /// Binanın meydan ateşine uzaklığı (tile) — ocak yoksa sonsuz.
  double _hearthDistanceOf(BuildingEntity b) {
    final fp = _firepitBuilding;
    if (fp == null) return 1e9;
    final dx = (b.col + b.cols / 2.0) - (fp.col + fp.cols / 2.0);
    final dy = (b.row + b.rows / 2.0) - (fp.row + fp.rows / 2.0);
    return sqrt(dx * dx + dy * dy);
  }

  /// Bu köylünün evi kışın SOĞUK mu (yakacak yetmedi) — üşüme hesabına girer.
  bool _houseHearthCold(VillagerEntity v) {
    if (_coldHouses.isEmpty) return false;
    final home = v.homeBuilding;
    return home is BuildingEntity && _coldHouses.contains(home);
  }

  // ── Hazırlık ─────────────────────────────────────────────────────────────

  /// Köyün kışa hazırlık tablosu. Sonbaharda "yetişir mi", kışın "dayanır mı"
  /// sorusunun tek cevabı; HUD kartı da bunu okur.
  WinterReadiness get _winterReadiness {
    final animals = _cows.where((a) => !a.isDying).length;
    final coats = _villagers.where((v) => !v.isDying && v.hasCoat).length;
    // Kışın ortasındaysak KALAN gün üzerinden sor: "hazır mıyım" sorusu
    // mevsim ilerledikçe "dayanır mıyım"a döner.
    final days = _season == Season.winter
        ? (kWinterDays - ((_dayCount - 1) % kDaysPerSeason)).clamp(1, kWinterDays)
        : kWinterDays;
    return winterReadiness(
      mouths: _villagers.length,
      animals: animals,
      wood: _stockpile.wood.toDouble(),
      coal: _stockpile.coal.toDouble(),
      food: _stockpile.food.toDouble(),
      // Yem = saman/saz: ahırın kışlık stoğu bunlardan sayılır.
      fodder: _stockpile.reed.toDouble() + _hayEntities.length.toDouble(),
      coats: coats,
      days: days,
      // Yıl geçtikçe kış sertleşir (bkz. systems/village_year.dart). Gösterge
      // de aynı sayıyı okur: panelde yazan hazırlık oranı, simin kullandığı
      // oranın ta kendisi olmalı — iki ayrı hesap iki ayrı kış demektir.
      bite: pressureForDay(_dayCount).winterBite,
    );
  }

  /// KIŞIN SESİ — hazırlık ekranda değil, köyün ağzında durur.
  ///
  /// Sürekli açık kış kartı kaldırıldığında (bkz. ui/winter_section.dart) bu
  /// üç an, oyuncunun kışı öğrendiği tek yer oldu; bu yüzden ZAMANLAMASI
  /// önemli. Kural: uyarı, hakkında bir şey YAPILABİLECEK zaman gelir.
  ///
  ///   • Sonbaharın ilk günü — hatırlatma. Kırkım ve istif bu mevsimin işi;
  ///     köy "kışa gireceğiz" der, "geç kaldın" demez.
  ///   • Sonbaharın son günü — hüküm. Hazırsa rahat, değilse telaşlı.
  ///   • Kışın ortası — mırıltı, yalnız bir kalem gerçekten tükenmeye
  ///     yakınken (bkz. `_maybeWinterPinch`).
  ///
  /// Kışın ORTASINDA söylenen "yakacak yok" bilgi değil sitemdir — o yüzden
  /// hüküm cümlesi kış başlamadan, hatırlatma ise mevsimin başında gelir.
  void _maybeWinterVoice() {
    _maybeAutumnPrep();
    _maybeWinterEve();
    _maybeWinterPinch();
  }

  /// Mevsimin kaçıncı günündeyiz (0 = ilk gün).
  int get _dayInSeason => (_dayCount - 1) % kDaysPerSeason;

  /// Sonbaharın İLK GÜNÜ, yılda bir: köy kışı hatırlar.
  ///
  /// Yalnız eksik varken konuşur — ambarı zaten dolu köye "hazırlan" demek
  /// gürültüdür. Cümle bir emir değil, bir mevsim sezgisi: neyin eksik
  /// olduğunu söyler ki oyuncu daha kırkım vakti geçmeden yönelsin.
  void _maybeAutumnPrep() {
    if (_season != Season.autumn || _dayInSeason != 0) return;
    if (_winterPrepYear == _seasonYear) return;
    _winterPrepYear = _seasonYear;
    final r = _winterReadiness;
    if (r.ready) return;
    final w = r.weakest;
    _showNotification(Voice.say(
      _kAutumnPrepPool,
      _voice(_winterSpeaker,
          seed: _stableSeed('kışhatırla', _dayCount),
          extra: {'kalem': w.label.toLowerCase()}),
    ));
  }

  /// Sonbaharın SON GÜNÜ köy bir kez konuşur: hazırsa rahat, değilse telaşlı.
  void _maybeWinterEve() {
    if (_season != Season.autumn) return;
    if (_dayInSeason != kDaysPerSeason - 1 || _winterEveDay == _dayCount) return;
    _winterEveDay = _dayCount;
    final r = _winterReadiness;
    if (r.ready) {
      _showNotification(Voice.say(_kWinterReadyPool,
          _voice(null, seed: _stableSeed('kışhazır', _dayCount))));
      _feelVillage(NpcEmotion.content, 4, 0.04);
      _chronicle('Köy kışa hazır girdi', icon: '❄️');
    } else {
      final w = r.weakest;
      _showNotification(Voice.say(
        _kWinterShortPool,
        _voice(_winterSpeaker,
            seed: _stableSeed('kışeksik', _dayCount),
            extra: {'kalem': w.label.toLowerCase()}),
      ));
      _feelVillage(NpcEmotion.fear, 4, -0.05);
      _chronicle('Köy kışa eksik girdi: ${w.label.toLowerCase()}', icon: '❄️', kind: ChronicleKind.crisis);
    }
  }

  /// KIŞIN ORTASINDA tek bir mırıltı: bir geçim kalemi son gününe girdiyse.
  ///
  /// Gösterge kalktığına göre stoğun bittiğini oyuncunun ambarı açıp
  /// bakmasına bağlamak olmazdı — ama her gün "yakacak azalıyor" demek de
  /// kartın bağırmasının başka bir biçimi olurdu. Eşik bu yüzden dar:
  /// yalnız İLK tükenecek kalem, yalnız bir günden az kaldıysa, günde bir kez.
  void _maybeWinterPinch() {
    if (_season != Season.winter || _winterPinchDay == _dayCount) return;
    final r = _winterReadiness;
    final t = r.tightest;
    if (r.daysLeftOf(t) >= 1.0) return;
    _winterPinchDay = _dayCount;
    _showNotification(Voice.say(
      _kWinterPinchPool,
      _voice(_winterSpeaker,
          seed: _stableSeed('kışkıtlık', _dayCount),
          extra: {'kalem': t.label.toLowerCase()}),
    ));
    _feelVillage(NpcEmotion.fear, 3, -0.03);
  }

  /// Kışı KİM söyler — işi kışa bakan biri: dokumacı, yoksa çoban, yoksa
  /// köyün herhangi bir yetişkini. Cümlenin ağzı belli olsun diye: kış
  /// ekranda bir uyarı değil, birinin söylediği bir şey.
  VillagerEntity? get _winterSpeaker {
    VillagerEntity? shepherd;
    VillagerEntity? anyone;
    for (final v in _villagers) {
      if (v.isDying || v.lifeStage == LifeStage.child) continue;
      if (v.job?.role == JobRole.weaver) return v;
      if (v.job?.role == JobRole.shepherd) shepherd ??= v;
      anyone ??= v;
    }
    return shepherd ?? anyone;
  }

  // ── İhmal ────────────────────────────────────────────────────────────────

  /// Bir köylünün üstünde biriken ihmal sayısı (0-4). Hastalık riski buradan
  /// ağırlaşır (bkz. scene_illness) — kış tek başına öldürmez.
  int _coldNeglectOf(VillagerEntity v) {
    if (_season != Season.winter) return 0;
    return coldNeglect(
      fireDead: !_fireBurning,
      coldShelter: _inColdShelter(v) || _houseHearthCold(v),
      noCoat: !v.hasCoat,
      larderEmpty: _stockpile.food <= 0,
    );
  }

  // ── Günlük kış muhasebesi ────────────────────────────────────────────────

  /// Sahne tick'inden gün başına bir kez çağrılır.
  void _tickWinter(double dt) {
    _winterScan += dt;
    if (_winterScan < _kHearthFuelScan) return;
    _winterScan = 0;

    // Mevsim sonbahara döndü → sürü yeniden kırkılabilir.
    if (_season == Season.autumn && _shearYear != _seasonYear) {
      _shearYear = _seasonYear;
      _resetShearing();
    }
    _maybeWinterVoice();
    _distributeCoats();
    _applySnowFooting();
    if (_winterDay != _dayCount) {
      _winterDay = _dayCount;
      _tickHouseHearths();
    }
  }

  /// KARDA YÜRÜME — kışın herkes biraz ağır ilerler.
  ///
  /// Köylünün kendi hız getter'ı mevsimi sorgulamaz (varlığı dünya durumuna
  /// bağlamamak için); zemin çarpanı ona SÖYLENİR. Saniyelik taramada yazmak
  /// yeterli: mevsim gün ölçeğinde değişir.
  void _applySnowFooting() {
    final f = groundFactorFor(_season);
    var footed = 0;
    for (final v in _villagers) {
      if (v.groundFactor != f) v.groundFactor = f;
      if (v.groundFactor < 1.0) footed++;
    }
    kProbeSnowFooted = footed;
  }

  /// Kaçıncı yılın kaçıncı mevsimi — kırkım bayrağının yıl anahtarı.
  int get _seasonYear => (_dayCount - 1) ~/ (kDaysPerSeason * 4);
}

// ── Köyün sesi ────────────────────────────────────────────────────────────

const List<String> _kFirstShearPool = [
  '🧶 {ad} ilk koyunu kırktı. Yün ambara girdi — kışlık burada başlar.',
  '🧶 Makas sesi geldi ağıldan: {ad} yünü topladı.',
  '🧶 {ad-in} elinde ilk yün yumağı. Sonbahar dokumanın mevsimi.',
];

const List<String> _kFirstCoatPool = [
  '🧥 İlk kışlık dokundu. {ad} tezgâhtan kalkarken sırtı ağrıyordu.',
  '🧥 {ad} ilk giysiyi bitirdi — bu kış birinin sırtı sıcak.',
  '🧥 Tezgâh ilk kışlığını verdi. {ad-in} işi köye yaradı.',
];

const List<String> _kColdHousePool = [
  '🥶 Yakacak yetmedi: köyün ucundaki ocaklar söndü.',
  '🥶 Bazı hanelerde ocak yanmıyor — kütük kalmadı.',
  '🥶 Kenar mahallede bacalar tütmüyor. Yakacak bitti.',
];

/// Sonbaharın ilk günü — hatırlatma. Suçlayıcı değil; eksiği ADIYLA söyler ki
/// oyuncu neye yöneleceğini bilsin, bir çubuğu kovalamasın.
const List<String> _kAutumnPrepPool = [
  '🍂 {ad}: "Yapraklar döndü. Kışa {kalem} ile gireceğiz, o da az."',
  '🍂 {ad} ambara baktı: "{kalem} bu kış yetmez. Vaktimiz bir mevsim."',
  '🍂 "Sonbahar kısa," dedi {ad}. "Eksiğimiz {kalem}."',
];

/// Sonbaharın son günü, eksikle — hüküm. Telaş var, sitem yok: kış geliyor ve
/// köy ne ile karşılayacağını biliyor.
const List<String> _kWinterShortPool = [
  '❄️ {ad}: "Kış kapıda ve {kalem} yetmiyor. Sıkı bir kış olacak."',
  '❄️ {ad} elini ateşe tuttu: "{kalem} eksik girdik. Dikkatli harcayacağız."',
  '❄️ "Bu kış {kalem} sayılacak," dedi {ad}. "Herkes bilsin."',
];

/// Kışın ortası — bir kalem son gününde. Günde bir kez, tek kalem.
const List<String> _kWinterPinchPool = [
  '🥶 {ad}: "{kalem} bugüne zor yeter."',
  '🥶 Ambarın dibi göründü: {kalem} bitmek üzere.',
  '🥶 {ad} ambardan eli boş döndü — {kalem} kalmadı denecek kadar az.',
];

const List<String> _kWinterReadyPool = [
  '❄️ Kış kapıda ve köy hazır: ambar dolu, sırtlar giyinik.',
  '❄️ Yakacak istiflendi, erzak yerinde. Kış gelsin.',
  '❄️ Köy kışa hazır girdi — bu akşam kimse tedirgin değil.',
];
