part of '../main.dart';

/// ÇADIR & OCAK — barınağın ateşe uzaklığı kışın bir bedele dönüşür.
///
/// Çadırın kendi ocağı yoktur (bkz. building_function): bezin altındaki tek
/// sıcaklık köyün ateşinden gelendir. Yazın bunun bir önemi yok; KIŞIN ocaktan
/// uzağa kurulmuş çadır üç ayrı yerden konuşur:
///
///  1. **Moral** — `coldShelter` terimi (villager_morale): "çadırı ateşten uzak"
///     köylü panelinde baskın sebep olarak okunur.
///  2. **Dürtü** — üşüme dürtüsü hızlı büyür, uykuda bile sönmez; sıcak evinde
///     yatan köylü ısınırken çadırdaki ısınamaz (scene_mind `_tickDrives`).
///  3. **Gövde** — dürtü dolunca köylü gecenin ortasında titreyerek kalkar ve
///     ateşin başına gider. Rahatsızlığın görünür hâli budur; baş üstünde ikon
///     ya da sayı yok (bkz. feedback_event_animation).
///
/// Cozy/no-fail: kimse donarak ölmez. Bedel moral ve uykusuzluktur — ve çaresi
/// oyuncunun elinde: çadırı ocağın çevresine kur, ocağı besle, ev dik.
extension _SceneShelter on _VillageSceneState {
  /// Soğuktan uyanma taraması (sn) — gece boyunca seyrek yoklanır, köy tek
  /// karede ayağa kalkmasın.
  static const double _kRouseScan = 6.0;

  /// Uyanmak için gereken üşüme dürtüsü. Eşik yüksek: köylü hafif serinlikte
  /// değil, gerçekten dayanamayınca kalkar.
  static const double _kRouseChill = 0.72;

  /// Aynı köylü bir gecede en fazla bu kadar kez kalkar (uyku/ateş mekiği
  /// olmasın); gün sayacıyla sıfırlanır.
  static const int _kRousesPerNight = 2;

  /// Köyün çadır derdini duyurma aralığı (oyun günü) — kışta bir kez.
  static const double _kMurmurDays = 3.0;

  // ── Köyün sesi ([[lib/text/voice.dart]]) ──────────────────────────────────

  static const _kColdTentPool = [
    '⛺ Çadırdakiler geceyi titreyerek geçirdi — ocaktan yana ne varsa uzak.',
    '⛺ "Bezin altı taş gibi soğuk." Ateşe uzak çadırlarda kimse uyuyamıyor.',
    '⛺ Kış çadıra işledi. Ocağın sıcağı o kadar öteye varmıyor.',
  ];

  /// Bir noktanın ocaktan aldığı sıcaklık (0..1). Ocak kurulmamış ya da sönükse
  /// sıfır — kışın ateşin sönmesi bütün çadır mahallesini birden üşütür.
  double _hearthWarmthAt(double gx, double gy) {
    final fire = _firepitBuilding;
    if (fire == null || !_fireBurning) return 0;
    final (fx, fy) = _centerOf(fire);
    return hearthWarmth(dx: gx - fx, dy: gy - fy, burning: true);
  }

  /// Bu binanın (çadırın) ocaktan aldığı sıcaklık.
  double _shelterWarmthOf(BuildingEntity b) {
    final (bx, by) = _centerOf(b);
    return _hearthWarmthAt(bx, by);
  }

  /// Köylünün barınağı kışın üşütüyor mu — çadır + kış + ocak uzak.
  bool _inColdShelter(VillagerEntity v) {
    final home = v.homeBuilding;
    if (home is! BuildingEntity || home.type != BuildingType.tent) return false;
    return shelterIsCold(
      tent: true,
      winter: _season == Season.winter,
      warmth: _shelterWarmthOf(home),
    );
  }

  /// Üşüme dürtüsünün bu köylüde ne kadar hızlı büyüdüğü. Soğuk çadırda
  /// oturanda ocağa uzaklıkla orantılı biçimde hızlanır; ötekilerde 1.0.
  double _chillDriveMultiplierOf(VillagerEntity v) {
    // KİŞİSEL katsayı — kışlık giysi + yaş kırılganlığı. Barınağın payı
    // AYRI hesaplanır (aşağıda); ikisini tek çağrıya vermek ocak mesafesini
    // iki kez saydırırdı, o yüzden buraya shelterWarmth: 0 gider.
    final personal = chillMultiplier(
      coat: v.hasCoat,
      child: v.isChild,
      elder: v.lifeStage == LifeStage.elder,
      shelterWarmth: 0,
    );
    final home = v.homeBuilding;
    if (home is! BuildingEntity) return personal;
    // Yakacak bitince duvarlı evin ocağı da söner — o hane artık çadır gibidir
    // (bkz. scene_winter._coldHouses). Kışın asıl yakacak tüketimi hanelerde.
    if (_houseHearthCold(v)) {
      return personal * coldShelterDriveMultiplier(_shelterWarmthOf(home));
    }
    if (!_inColdShelter(v)) return personal;
    return personal * coldShelterDriveMultiplier(_shelterWarmthOf(home));
  }

  /// Barınağı köylüyü GECE ısıtıyor mu — yani uyurken üşümesi diner mi?
  ///
  /// Duvarlı ev her mevsim ısıtır (kendi ocağı vardır). Çadır yalnız kışın
  /// sorun çıkarır ve o zaman da ateşe yakınlığına bakılır. Evsizin barınağı
  /// yoktur; onu ısıtan tek şey ateşin dibindeki sazlık yatağıdır (scene_reed),
  /// ki oraya zaten ateşin sıcağı ulaşır.
  bool _sleepsWarm(VillagerEntity v) {
    final home = v.homeBuilding;
    if (home is BuildingEntity) {
      // Ocağı sönmüş ev artık ısıtmaz: kışın yakacak bittiyse duvar tek
      // başına yetmez (bkz. scene_winter._tickHouseHearths).
      if (_houseHearthCold(v)) return false;
      if (home.type != BuildingType.tent) return true;
      return !_inColdShelter(v);
    }
    return _hearthWarmthAt(v.gridX, v.gridY) > kColdShelterThreshold;
  }

  /// Gece taraması: soğuk çadırda dayanamayan köylüyü kaldırır + köyün bu
  /// dertten haberdar olmasını sağlar.
  void _tickShelter(double dt) {
    // Gün dönünce gecelik kalkma kotaları sıfırlanır.
    if (_shelterDay != _dayCount) {
      _shelterDay = _dayCount;
      _rousedTonight.clear();
    }

    _shelterMurmurWait -= dt / kGameDaySeconds;
    _rouseScan += dt;
    if (_rouseScan < _kRouseScan) return;
    _rouseScan = 0;

    // Kalkmanın anlamlı olduğu koşullar: kış + yanan ocak + yağmursuz gece.
    // Ocak sönükken uyandırmak köylüyü karanlıkta ortada bırakırdı — gidecek
    // sıcak bir yer olmadan uyanmak rahatsızlığı DAHA da artırır, çaresini
    // değil. Üşüyenleri saymak yine de her mevsim sürer (telemetri dürüst
    // kalsın: "0 kalkma" ile "0 üşüyen" aynı şey değil).
    final canRouse = _season == Season.winter &&
        _fireBurning &&
        _cycle.rainIntensity <= 0.4;

    var cold = 0;
    for (final v in _villagers) {
      if (v.isDying || v.isLeaving || !_inColdShelter(v)) continue;
      cold++;
      if (!canRouse || !v.isSleeping || v.isChild) continue;
      if (v.mind.drive(Drive.chill) < _kRouseChill) continue;
      final n = _rousedTonight[v] ?? 0;
      if (n >= _kRousesPerNight) continue;
      _rousedTonight[v] = n + 1;
      v.rouseShivering();
      // Akıl bir sonraki turda devralır: üşüme dürtüsü dolu olduğu için
      // `_bidHearth` kazanır ve köylü ateşin başına yürür.
      v.mind.clear();
      kProbeColdRouses++;
    }
    kProbeColdTents = cold;

    // Köy bu dertten bir kez söz etsin — sayı değil, ağız. Tek kişilik dert
    // sessiz geçer; iki hane birden üşüyorsa köyün gündemi olur.
    if (cold >= 2 && _shelterMurmurWait <= 0 && _cycle.dayLight < 0.35) {
      _shelterMurmurWait = _kMurmurDays;
      _showNotification(Voice.say(_kColdTentPool,
          _voice(null, seed: _stableSeed('soğukçadır', _dayCount))));
      _feelVillage(NpcEmotion.fear, 5, -0.05);
    }
  }
}
