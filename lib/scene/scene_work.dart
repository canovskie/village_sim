part of '../main.dart';

/// Sivil mesleklerin İŞ DÖNGÜLERİ — çoban / avcı / değirmenci / hancı / rahip.
///
/// İki farklı işçi modeli var, karıştırma:
///   • BİNA-DOĞUMLU işçi (oduncu, madenci, balıkçı): bina kendi entity'sini
///     doğurur, mantığı worker_entity'de. Bunlar VillagerType DEĞİL.
///   • SİVİL meslek (bu dosya): çağrıyla doğar, köylüdür, işini KENDİ arar.
///     Model [_SceneReed]'in self-service döngüsü: iş bul → yürü → çalış → etki.
///
/// Tek sahip ilkesi: bir köylünün gerçekten yapacak işi varsa ([_workTaskAvailable])
/// genel rutin ([_tickRoutine]) ona dokunmaz. İş yoksa rutin devralır — köylü
/// işyerinde boş boş çakılı kalmaz, köye karışır.
///
/// Cozy sözleşmesi: işler KAYNAK YAKMAZ, kimse cezalandırılmaz. Etkiler küçük
/// ve görünür (hayvan doyar, av eti gelir, değirmen verimi artar, han/kilise
/// çevresi iyi hisseder).
extension _SceneWork on _VillageSceneState {
  static const double _kWorkScan = 0.6;

  /// Çoban bu açlığın üstündeki hayvana koşar. DÜŞÜK tutuldu: hayvanlar kendi
  /// otladığı için açlık nadiren yükselir; eşik yüksek olursa çoban hiç iş
  /// yapmaz (ilk denemede 0.35'te tam olarak bu oldu — telemetri gösterdi).
  static const double _kTendHunger = 0.15;
  /// Bir bakımın hayvandan düşürdüğü açlık.
  static const double _kTendRelief = 0.45;
  /// Çobanın iki bakım arası nefesi (sn).
  static const double _kTendCooldown = 6.0;

  /// Av "ormanı": ateşten bu kadar uzaktaki ağaçlar (yakın ağaç oduncunun işi).
  static const double _kHuntMinDist = 7.0;
  /// Bir avın getirdiği yiyecek.
  static const int _kHuntFood = 5;
  /// İki av arası (sn) — ~yarım oyun günü, av bol kaynak olmasın.
  static const double _kHuntCooldown = kGameDaySeconds * 0.5;
  /// Avcının pusuda bekleme süresi (sn).
  static const double _kHuntStalk = 4.0;

  /// "İşinin başında" sayılmak için STAND SPOT'a azami uzaklık (bina merkezine
  /// değil — merkez engeldir, oraya yürünemez).
  static const double _kAtPost = 1.2;
  /// Hancı/rahibin çevresine "iyi geldiği" yarıçap.
  static const double _kAuraRadius = 3.2;
  /// Aura iki dokunuş arası (sn).
  static const double _kAuraCooldown = 12.0;
  /// Çobanın sürüye azami uzaklığı — bundan uzaklaşırsa geri döner.
  static const double _kFlockRange = 3.0;

  /// Muhafızın nöbet noktaları — köyün kıymetli/kalabalık yerleri (suçun hedef
  /// aldığı yerler). Muhafız bunlar arasında dolaşır; suç çıkarsa üstüne koşar
  /// (kovalama scene_crime'da: `_guardResponse`).
  static const List<BuildingType> _kWatchPosts = [
    BuildingType.warehouse,
    BuildingType.market,
    BuildingType.barn,
    BuildingType.firepit,
  ];

  /// Muhafızın post değiştirme periyodu (sn) — devriye hissi.
  static const double _kWatchRotate = 30.0;

  /// Bu meslek kendi iş döngüsünü sürüyor mu?
  bool _hasJobLoop(VillagerEntity v) =>
      // Üstlenilmiş bina-işi (inşaat/tarla/maden…) — rutin/wander ona dokunmasın.
      v.hasActiveJob ||
      (v.canRunErrands &&
          (v.type == VillagerType.shepherd ||
              v.type == VillagerType.hunter ||
              v.type == VillagerType.miller ||
              v.type == VillagerType.innkeeper ||
              v.type == VillagerType.priest ||
              v.type == VillagerType.guard));

  /// Şu an GERÇEKTEN yapacak iş var mı? Yoksa rutin devralsın.
  bool _workTaskAvailable(VillagerEntity v) {
    // Üstlenilmiş iş her zaman "yapılacak iş"tir (site'ta çakılı kalsın, rutin
    // errand atamasın). Gündüz/gece ayrımı iş yürütücüsünde (uyku askıya alır).
    if (v.hasActiveJob) return true;
    // PAYDOS — köyün hâli mesaiyi kestiyse (bkz. world_pressure.workDrive) bu
    // köylünün şu an işi YOKTUR; rutin devralır. Tek kapı: paydosu yalnız
    // _applyPressure verir, burası sadece okur.
    if (v.workPause > 0) return false;
    // İş gündüz — tek istisna gece nöbetçisi (bkz. WorldPressure.patrolDensity).
    if (_cycle.dayLight <= 0.35 && !v.nightDuty) return false;
    switch (v.type) {
      case VillagerType.shepherd:
        // Sürü varsa çobanın işi HEP vardır (acıkanı besler ya da başında bekler).
        return _nearestAnimal(v) != null;
      case VillagerType.hunter:
        return v.workCooldown <= 0 && _huntTree(v) != null;
      case VillagerType.miller:
        return _postReachable(BuildingType.mill, v);
      case VillagerType.innkeeper:
        return _postReachable(BuildingType.tavern, v);
      case VillagerType.priest:
        return _postReachable(BuildingType.church, v);
      case VillagerType.guard:
        // Nöbet tutulacak bir yer varsa muhafızın işi HEP vardır.
        return _watchPost(v) != null;
      default:
        return false;
    }
  }

  /// Muhafızın o an nöbet tutacağı bina — ulaşılabilir postlar arasında zamanla
  /// DÖNER (her ~30 sn başka bir noktaya geçer → sabit heykel değil, devriye).
  /// Dönüş sırası köylüye göre kaydırılır ki iki muhafız aynı yerde toplanmasın.
  /// Post yoksa null → rutin devralır (köylü ulaşılamaz binaya bakıp donmaz).
  BuildingEntity? _watchPost(VillagerEntity v) {
    final reachable = <BuildingEntity>[];
    for (final t in _kWatchPosts) {
      final b = _nearestOf(t, v);
      if (b != null && _standSpotFor(b, v) != null) reachable.add(b);
    }
    if (reachable.isEmpty) return null;
    final turn = (_time / _kWatchRotate).floor() + v.name.hashCode.abs();
    return reachable[turn % reachable.length];
  }

  /// İşyeri var VE yanına yürünebilir mi? İkisi de yoksa iş "yok" sayılır →
  /// rutin devralır, köylü ulaşılamaz binaya bakıp donmaz.
  bool _postReachable(BuildingType type, VillagerEntity v) {
    final b = _nearestOf(type, v);
    return b != null && _standSpotFor(b, v) != null;
  }

  /// Köylü ZATEN bu hedefe mi yürüyor?
  ///
  /// Kritik: "state == moving ise dokunma" demek YETMEZ — köylünün kendi
  /// başına gezinme (wander) davranışı onu neredeyse sürekli `moving` tutar,
  /// o yüzden iş emri hiç verilemez ve köylü ömrü boyunca voltasında döner
  /// (telemetride hancı tam olarak böyle takıldı: st=moving, d hep 8-9).
  /// Doğru soru: "benim hedefime mi gidiyor?" — gitmiyorsa emri VER (wander'ı
  /// ez); gidiyorsa rahat bırak, varmasını bekle.
  bool _enRouteTo(VillagerEntity v, double x, double y) =>
      v.state == VillagerState.moving &&
      (v.targetCol - x).abs() < 0.6 &&
      (v.targetRow - y).abs() < 0.6;

  void _tickWork(double dt) {
    // Cooldown'lar gerçek zamanda akar (tarama throttle'ından bağımsız).
    for (final v in _villagers) {
      if (v.workCooldown > 0) v.workCooldown -= dt;
    }

    _workScan += dt;
    if (_workScan < _kWorkScan) return;
    _workScan = 0;
    // Gece: uyku/rutin sistemi devralır — nöbetçiler HARİÇ. Gece bekçisi
    // fermanı altında sokak boşalırken devriye postunda dönmeye devam eder.
    final night = _cycle.dayLight <= 0.35;

    for (final v in _villagers) {
      if (night && !v.nightDuty) continue;
      // SAHİPLİK — akıl bu köylüyü işe verdi mi? Vermediyse dokunma. Eskiden
      // burası "boştaysa kap" diyordu ve aynı köylüyü ateş/sohbet/saz
      // sistemleriyle yarışa sokuyordu (bkz. scene_mind).
      if (!v.mind.owns(IntentKind.work)) continue;
      // Üstlenilmiş bina-işi olan köylüyü civil döngü SÜRMEZ — onu _tickJobs
      // yürütür (yoksa çoban-tipli bir inşaatçı hem güder hem inşa eder → çift
      // goTo çakışması).
      if (v.hasActiveJob) continue;
      if (v.workPause > 0) continue; // paydos — köyün hâli mesaiyi kesti
      if (!_hasJobLoop(v)) continue;
      if (v.isInsideBuilding ||
          v.isSleeping ||
          v.isCarrying ||
          v.sitClaimed ||
          v.isDying ||
          v.activity != VillagerActivity.none) {
        continue;
      }
      // Gövde dilini her taramada sıfırla — post'taki dal (aşağıda) yeniden
      // kurar, yürüyen/işsiz kalanda temizlenmiş kalır. Tarama 0.6s'de bir
      // döner ama duruş yapışkan bir alan; iki tarama arası sabit görünür.
      _setWorkPose(v, null);
      switch (v.type) {
        case VillagerType.shepherd:
          _workShepherd(v);
        case VillagerType.hunter:
          _workHunter(v);
        case VillagerType.miller:
          _workAtPost(v, BuildingType.mill);
        case VillagerType.innkeeper:
          _workHost(v, BuildingType.tavern, NpcEmotion.joy);
        case VillagerType.priest:
          _workHost(v, BuildingType.church, NpcEmotion.content);
        case VillagerType.guard:
          _workGuard(v);
        default:
          break;
      }
    }

    if (kCaptureShowcase) _reportWork();
  }

  /// Capture telemetrisi — harness iş döngülerinin GERÇEKTEN döndüğünü buradan
  /// doğrular (ekran görüntüsü tek başına "çalışıyor mu" sorusunu yanıtlamaz).
  void _reportWork() {
    final sb = StringBuffer();
    final mills = _buildings.where((b) => b.type == BuildingType.mill).length;
    final taverns = _buildings.where((b) => b.type == BuildingType.tavern).length;
    final churches = _buildings.where((b) => b.type == BuildingType.church).length;
    sb.write('b[mill=$mills tavern=$taverns church=$churches] ');
    // Soy dökümü — "tek aile ile başla" doğrulaması (hane sayısı + kimler).
    final fam = <String, int>{};
    for (final v in _villagers) {
      if (v.isDying) continue;
      fam[v.surname.isEmpty ? '(yok)' : v.surname] =
          (fam[v.surname.isEmpty ? '(yok)' : v.surname] ?? 0) + 1;
    }
    sb.write('aile=${fam.length} ${fam.entries.map((e) => '${e.key}:${e.value}').join(',')} ');
    sb.write('food=${_stockpile.food}');
    if (_cows.isNotEmpty) {
      final avg = _cows.fold<double>(0, (s, a) => s + a.hunger) / _cows.length;
      sb.write(' herdHunger=${avg.toStringAsFixed(2)}');
    }
    for (final v in _villagers) {
      if (!_hasJobLoop(v)) continue;
      final b = switch (v.type) {
        VillagerType.miller => _nearestOf(BuildingType.mill, v),
        VillagerType.innkeeper => _nearestOf(BuildingType.tavern, v),
        VillagerType.priest => _nearestOf(BuildingType.church, v),
        _ => null,
      };
      String where = '';
      if (b != null) {
        final (bx, by) = _centerOf(b);
        final spot = _standSpotFor(b, v);
        where = ' d=${_wdist(v.gridX, v.gridY, bx, by).toStringAsFixed(1)}'
            ' spot=${spot == null ? 'NULL' : '${spot.$1.toInt()},${spot.$2.toInt()}'}';
      }
      sb.write(' | ${v.type.name}$where st=${v.state.name}'
          ' act=${v.activity.name} err=${v.needsErrand ? 1 : 0}'
          ' cd=${v.workCooldown.toStringAsFixed(0)}');
    }
    kCaptureWorkReport = sb.toString();
  }

  // ── ÇOBAN — sürüsünden ayrılmaz; acıkanı otlağa götürür ───────────────────
  /// Çobanın işi iki katmanlı, çünkü hayvanlar zaten KENDİ otluyor (açlık nadiren
  /// eşiği geçer): (1) acıkan varsa ona bakar, (2) yoksa sürünün yanında kalır.
  /// (2) olmasaydı çoban çoğu zaman "işsiz" sayılıp rutine düşer, sürüyü bırakıp
  /// köyde volta atardı — mesleğin bütün kimliği kaybolurdu.
  void _workShepherd(VillagerEntity v) {
    final hungry = v.workCooldown <= 0 ? _hungriestAnimal(v) : null;
    if (hungry != null) {
      if (_wdist(v.gridX, v.gridY, hungry.gridX, hungry.gridY) < 1.7) {
        // Bakım: hayvanı otlağa yönlendirir → açlığı düşer, ikisi de rahatlar.
        hungry.hunger = (hungry.hunger - _kTendRelief).clamp(0.0, 1.0);
        v.feel(NpcEmotion.content, 3.0, moodDelta: 0.03);
        v.glanceAround(duration: 1.6);
        v.lookToward(hungry.gridX, hungry.gridY);
        _setWorkPose(v, ActPose.stoop); // eğilip hayvana bakar
        v.workCooldown = _kTendCooldown;
      } else if (!_enRouteTo(v, hungry.gridX, hungry.gridY)) {
        v.goTo(hungry.gridX, hungry.gridY, 1.0);
      }
      return;
    }

    // Sürünün başında bekle — çoban sürüsüyle görünür.
    final near = _nearestAnimal(v);
    if (near == null) return;
    if (_wdist(v.gridX, v.gridY, near.gridX, near.gridY) > _kFlockRange) {
      if (!_enRouteTo(v, near.gridX, near.gridY)) {
        v.goTo(near.gridX, near.gridY, 2.5);
      }
    } else {
      v.glanceAround(duration: 1.5);
      v.lookToward(near.gridX, near.gridY);
    }
  }

  /// Bakıma muhtaç (en aç) hayvan — eşiğin altındaysa null.
  AnimalEntity? _hungriestAnimal(VillagerEntity v) {
    AnimalEntity? best;
    double bestH = _kTendHunger;
    for (final a in _cows) {
      if (a.isDying) continue;
      if (a.hunger <= bestH) continue;
      bestH = a.hunger;
      best = a;
    }
    return best;
  }

  /// Sürüden en yakın hayvan (bekçilik hedefi) — yoksa null.
  AnimalEntity? _nearestAnimal(VillagerEntity v) {
    AnimalEntity? best;
    double bestD = 1e9;
    for (final a in _cows) {
      if (a.isDying) continue;
      final d = _wdist(v.gridX, v.gridY, a.gridX, a.gridY);
      if (d < bestD) {
        bestD = d;
        best = a;
      }
    }
    return best;
  }

  // ── AVCI — ormana açılır, av getirir ──────────────────────────────────────
  void _workHunter(VillagerEntity v) {
    if (v.workCooldown > 0) return;
    final t = _huntTree(v);
    if (t == null) return;

    final spot = _ringSpot(t.col, t.row, 1, 1, v);
    if (spot == null) return; // yanına varılamıyor → başka ağaç (sonraki tarama)
    if (_enRouteTo(v, spot.$1, spot.$2)) return; // zaten ava yürüyor
    if (_wdist(v.gridX, v.gridY, spot.$1, spot.$2) <= _kAtPost) {
      // Pusu → av. Kaynak yaratır (et), ağaca DOKUNMAZ (o oduncunun işi).
      _stockpile.food += _kHuntFood;
      v.feel(NpcEmotion.joy, 3.5, moodDelta: 0.05);
      v.glanceAround(duration: _kHuntStalk);
      _setWorkPose(v, ActPose.stoop); // pusuda çömelir
      v.workCooldown = _kHuntCooldown;
    } else {
      v.goTo(spot.$1, spot.$2, _kHuntStalk);
    }
  }

  /// Avlanılacak ORMAN ağacı — ateşten yeterince uzak (yakın ağaçlar köyün/
  /// oduncunun malı). Kesilmiş/işaretli olanlar sayılmaz.
  TreeEntity? _huntTree(VillagerEntity v) {
    final fp = _firepitBuilding;
    if (fp == null) return null;
    final cx = fp.col + fp.cols / 2.0;
    final cy = fp.row + fp.rows / 2.0;

    TreeEntity? best;
    double bestD = 1e9;
    for (final t in _trees) {
      if (t.isFelled || t.isMarkedForCutting || t.isBeingChopped) continue;
      final tx = t.col.toDouble(), ty = t.row.toDouble();
      if (_wdist(tx, ty, cx, cy) < _kHuntMinDist) continue; // köy içi değil
      final d = _wdist(tx, ty, v.gridX, v.gridY);
      if (d < bestD) {
        bestD = d;
        best = t;
      }
    }
    return best;
  }

  // ── DEĞİRMENCİ — değirmenin başında durur (verim bonusu buradan) ──────────
  void _workAtPost(VillagerEntity v, BuildingType type) {
    final b = _nearestOf(type, v);
    if (b == null) return;
    final spot = _standSpotFor(b, v);
    if (spot == null) return; // binaya yanaşılamıyor → rutin devralsın

    if (_enRouteTo(v, spot.$1, spot.$2)) return; // zaten yolda
    if (_wdist(v.gridX, v.gridY, spot.$1, spot.$2) <= _kAtPost) {
      // İşinin başında — oyalanır (bonus _millerYieldMul'dan okunur).
      _setWorkPose(v, ActPose.labor); // taş çevirir / harman döver: sürekli işlik
      if (v.workCooldown <= 0) {
        v.feel(NpcEmotion.content, 2.5, moodDelta: 0.02);
        v.workCooldown = _kAuraCooldown;
      }
      v.glanceAround(duration: 1.4);
      final (bx, by) = _centerOf(b);
      v.lookToward(bx, by);
    } else {
      v.goTo(spot.$1, spot.$2, 3.0);
    }
  }

  /// Başında değirmenci DURAN değirmenlerin balya verimi çarpanı — yoksa 1.0.
  /// scene_tick bunu baleYieldMultiplier'a çarpar (carrier_system'e dokunmadan).
  ///
  /// Yan etki: her değirmenin [BuildingEntity.staffed] bayrağını tazeler — panel
  /// "değirmenci başında mı" sorusunu buradan okur. Eskiden İLK bulduğu
  /// değirmenciyle dönüyordu: ikinci değirmene ikinci değirmenci koymak hiçbir
  /// şey katmıyordu. Artık her donanımlı değirmen katkı verir, ikincisi yarım
  /// (aynı harman iki kez bereketlenmez).
  double _millerYieldMul() {
    var staffedCount = 0;
    for (final b in _buildings) {
      if (b.type != BuildingType.mill) continue;
      var staffed = false;
      if (!b.userPaused) {
        for (final v in _villagers) {
          if (v.type != VillagerType.miller || v.isDying || v.isSleeping) {
            continue;
          }
          if (_nearestOf(BuildingType.mill, v) != b) continue;
          final spot = _standSpotFor(b, v);
          if (spot == null) continue;
          if (_wdist(v.gridX, v.gridY, spot.$1, spot.$2) <= _kAtPost) {
            staffed = true;
            break;
          }
        }
      }
      b.staffed = staffed;
      if (staffed) staffedCount++;
    }
    // 1. değirmenci tam, 2. yarım, 3. çeyrek… (kMillBonusMaxCount'la sınırlı).
    var mul = 1.0;
    for (var i = 0; i < staffedCount && i < kMillBonusMaxCount; i++) {
      mul += kMillerYieldBonus / (1 << i);
    }
    return mul;
  }

  // ── MUHAFIZ — nöbet noktaları arasında devriye gezer ──────────────────────
  /// Muhafız köyün kıymetli noktalarında (depo/pazar/ağıl/ateş) nöbet tutar ve
  /// zamanla post değiştirir. Suç işlenirken bu döngü DEVRE DIŞI kalır: fail
  /// üstüne koşma/yakalama scene_crime'ın işidir (`activity == chasing` iken
  /// `_tickWork` bu köylüye zaten dokunmaz).
  ///
  /// Nöbetin gerçek etkisi mekaniktir, süs değil: sahnedeki her uyanık muhafız
  /// suç olasılığını belirgin biçimde kısar (`_crimePressure`).
  void _workGuard(VillagerEntity v) {
    final b = _watchPost(v);
    if (b == null) return;
    final spot = _standSpotFor(b, v);
    if (spot == null) return;

    if (_enRouteTo(v, spot.$1, spot.$2)) return; // zaten posta yürüyor
    if (_wdist(v.gridX, v.gridY, spot.$1, spot.$2) <= _kAtPost) {
      // Nöbette — çevreyi tarar (gövde dili: sürekli bakınma; baş-üstü ikon YOK).
      if (v.workCooldown <= 0) {
        v.workCooldown = _kAuraCooldown;
      }
      v.glanceAround(duration: 2.0);
    } else {
      v.goTo(spot.$1, spot.$2, 4.0);
    }
  }

  // ── HANCI / RAHİP — işyerinde durur, çevresine iyi gelir ──────────────────
  void _workHost(VillagerEntity v, BuildingType type, NpcEmotion e) {
    final b = _nearestOf(type, v);
    if (b == null) return;
    final spot = _standSpotFor(b, v);
    if (spot == null) return; // binaya yanaşılamıyor → rutin devralsın

    if (_enRouteTo(v, spot.$1, spot.$2)) return; // zaten yolda
    if (_wdist(v.gridX, v.gridY, spot.$1, spot.$2) <= _kAtPost) {
      if (v.workCooldown <= 0) {
        // Ağırlar / dua eder — yakındakiler bunu hisseder (gövde dili + aura).
        v.feel(e, 3.0, moodDelta: 0.03);
        _reactNearby(v.gridX, v.gridY, _kAuraRadius, e, 2.5, moodDelta: 0.02);
        v.workCooldown = _kAuraCooldown;
      }
      v.glanceAround(duration: 1.5);
    } else {
      v.goTo(spot.$1, spot.$2, 3.0);
    }
  }

  // ── Yardımcılar ───────────────────────────────────────────────────────────

  /// Köylüye en yakın, verilen türde bina — yoksa null.
  /// NOT: `_buildings` yalnız TAMAMLANMIŞ binaları tutar (inşaat halindekiler
  /// BuildOrder'da yaşar) → ayrıca "bitti mi" filtresi gerekmez.
  /// (Bir bina alanıyla "bitti mi" filtrelemeye kalkma — tüm binaları eler;
  /// bir kez bu tuzağa düşüldü.)
  BuildingEntity? _nearestOf(BuildingType type, VillagerEntity v) {
    BuildingEntity? best;
    double bestD = 1e9;
    for (final b in _buildings) {
      if (b.type != type) continue;
      final (bx, by) = _centerOf(b);
      final d = _wdist(bx, by, v.gridX, v.gridY);
      if (d < bestD) {
        bestD = d;
        best = b;
      }
    }
    return best;
  }

  (double, double) _centerOf(BuildingEntity b) =>
      (b.col + b.cols / 2.0, b.row + b.rows / 2.0);

  /// Binanın DIŞ HALKASINDAKİ, köylüye en yakın boş tile — "işinin başı".
  ///
  /// Neden `_freeSpotNear` değil: o, merkez çevresinde RASTGELE nokta dener;
  /// 2×2+ bir binada örneklerin çoğu binanın kendi üstüne (engel) düşer, 12
  /// denemede null döner ve fallback bina MERKEZİNE (engelin ta kendisine) goTo
  /// verirdi → pathfinder gidemez, köylü olduğu yerde çakılırdı (telemetride
  /// değirmenci d≈11'de takılı kaldı, bu şekilde yakalandı). Burası deterministik
  /// olarak footprint'in bir tile dışını tarar → hedef her zaman yürünebilir.
  (double, double)? _standSpotFor(BuildingEntity b, VillagerEntity v) =>
      _ringSpot(b.col, b.row, b.cols, b.rows, v);

  /// [col,row] köşeli, [cols]×[rows] bir footprint'in çevresindeki en yakın
  /// yürünebilir tile. Ağaç gibi 1×1 hedefler için de kullanılır.
  (double, double)? _ringSpot(
      int col, int row, int cols, int rows, VillagerEntity v) {
    (double, double)? best;
    double bestD = 1e9;
    for (int c = col - 1; c <= col + cols; c++) {
      for (int r = row - 1; r <= row + rows; r++) {
        final inside =
            c >= col && c < col + cols && r >= row && r < row + rows;
        if (inside) continue; // footprint'in kendisi değil, çevresi
        if (c < 1 || c >= kCols - 1 || r < 1 || r >= kRows - 1) continue;
        if (_obstacles.contains((c, r))) continue;
        if (_waterTiles.contains((c, r))) continue;
        final d = _wdist(c.toDouble(), r.toDouble(), v.gridX, v.gridY);
        if (d < bestD) {
          bestD = d;
          best = (c.toDouble(), r.toDouble());
        }
      }
    }
    return best;
  }

  double _wdist(double ax, double ay, double bx, double by) {
    final dx = ax - bx, dy = ay - by;
    return sqrt(dx * dx + dy * dy);
  }
}
