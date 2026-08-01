part of '../main.dart';

/// KÖYÜN HÂLİ — sahne tarafı.
///
/// [WorldPressure] saf tabloyu üretir; burası onu köye **uygular**. Kanunname
/// artık paneldeki bir satır değil: mühür basıldığı an sokağın ne zaman
/// boşaldığı, kimin nereye yürüdüğü, kaç muhafızın devriyede olduğu, gövdelerin
/// nasıl durduğu değişir.
///
/// Tek sahip ilkesi: basıncı yalnız [_recomputePressure] üretir, yalnız
/// [_applyPressure] dünyaya işler. Başka hiçbir yerde yasa id'sine bakıp
/// davranış bükülmez — bakılacaksa buraya bir alan eklenir.
extension _ScenePressure on _VillageSceneState {
  /// Basınç tazeleme aralığı (sim sn). Tablo ucuz ama her kare gereksiz.
  static const double _kPressureScan = 1.0;

  void _tickPressure(double dt) {
    _pressureScan += dt;
    if (_pressureScan < _kPressureScan) return;
    final elapsed = _pressureScan;
    _pressureScan = 0;
    _recomputePressure();
    _applyPressure(elapsed);
  }

  /// Dünyanın hâlini derler. Mühür/yemin/fesih anında da doğrudan çağrılır ki
  /// oyuncu kararının sonucunu bir saniye beklemeden görsün.
  void _recomputePressure() {
    _pressure = WorldPressure.derive(
      sealed: _policies.sealed,
      compass: _compassPos,
      regime: _regimeIdentity.regime,
      season: _season,
      unrest: _unrest,
      dayCount: _dayCount,
      scarcity: _scarcity,
      plenty: _plenty,
      memory: _villageMemory,
    );
  }

  /// AÇLIK EŞİĞİ — ambarın hangi seviyesinin altında köy aç sayılır.
  ///
  /// ORTAK AMBAR fermanı bu eşiği yarıya indirir: pay eşit dağıtıldığında kıtlık
  /// kimseyi tek başına vurmaz, köy ambar gerçekten dibe vurana dek dayanır.
  /// "Kimse aç kalmaz" cümlesinin mekanik karşılığı budur (bedeli üretim
  /// hevesindedir — bkz. world_pressure: rejim.ortakAmbar workDrive).
  ///
  /// Tek doğruluk kaynağı: hem [_scarcity] hem [_tickPopulationAndHunger]
  /// buradan okur, yoksa suç iklimi ile moral farklı eşiklere bakardı.
  double get _starveRamp => _policies.sealed.contains('rejim.ortakAmbar')
      ? kStarveRampFood * 0.5
      : kStarveRampFood.toDouble();

  /// Yoksunluk 0..1 — ambar [_starveRamp] altına inince tırmanır. Açlık
  /// suç dürtüsünün en eski sebebi; sayı olarak değil, sebep olarak girer.
  double get _scarcity => _stockpile.food >= _starveRamp
      ? 0.0
      : (1.0 - _stockpile.food / _starveRamp).clamp(0.0, 1.0);

  /// BOLLUK 0..1 — [_scarcity]'nin öbür ucu. Açlık eşiğinin **iki katından**
  /// sonra tırmanmaya başlar, dört buçuk katında dolar.
  ///
  /// Eşik bilinçli olarak geç: ambarın açlık sınırının hemen üstünde olması
  /// refah değil, yalnızca "bugün aç değiliz" demektir. Kılığın değişmesi için
  /// köyün gerçekten harman taşıması gerek — yoksa palet sürekli oynar ve
  /// kimse neden değiştiğini anlamaz.
  double get _plenty {
    final ramp = _starveRamp;
    if (ramp <= 0) return 0;
    return ((_stockpile.food / ramp - 2.0) / 2.5).clamp(0.0, 1.0);
  }

  /// Tabloyu köylülerin üstüne işler — köylü başına ucuz alan yazımı.
  void _applyPressure(double elapsed) {
    final p = _pressure;
    // Mesai açığı: 1.0'ın altındaki her puan paydos ihtimalidir. Katsayı
    // bilinçli düşük — Kutsal Gün'de (0.45) köy bir anda değil, sabah boyunca
    // yavaşça tezgâhtan çekilir; ani "herkes durdu" karesi sahte durur.
    final pauseChance = (1.0 - p.workDrive).clamp(0.0, 1.0) * 0.12 * elapsed;

    _assignNightWatch(p.patrolDensity);

    for (final v in _villagers) {
      // SOKAĞA ÇIKMA — köylünün "gece oldu" eşiği kayar. Tek Söz mühürlüyse
      // köy ortalık daha aydınlıkken içeri çekilir; ışık hâlâ varken boşalan
      // sokak, yasanın en okunur yüzü.
      v.curfewBias = p.curfewBias;

      // FENER — hüküm gece ışığı mecbur kılıyorsa meşale eşiği düşer. Muhafızın
      // ayrı bir "nöbet meşalesi" alanı YOK: mesleği gereği zaten gece meşale
      // taşıyor, ayrı bir bayrak hiçbir şeyi değiştirmezdi.
      v.lanternMandate = p.lanternMandate;

      // DURUŞ — köyün hâli gövdeye iner. Kişisel moral duruşu yumuşatır ya da
      // sertleştirir: mutlu bir köylü baskı altında bile daha dik yürür, mutsuz
      // olan şenlikte bile omuz düşük durur. Böylece köy tek tip robot olmaz.
      final personal = (v.morale - 0.5) * 2.0; // -1..1
      // HANENİN HÂLİ de gövdededir. Bir karar bir haneyi gücendirdiğinde
      // (estateMood / house nudge) şimdiye dek yalnız bir sayı düşüyordu; o
      // hanenin insanlarında hiçbir şey değişmiyordu. Artık küskün hanenin
      // adamları daha sinik ve gergin durur, gözetilen hane dik gezer —
      // "kimi kolladığın" sokakta okunur. Ağırlık kişisel moralin altında:
      // hane bir renk katar, kimliği ezmez.
      final house = v.surname.isEmpty
          ? 0.0
          : ((_houses.moodOf(v.surname) - 0.55) * 2.0).clamp(-1.0, 1.0);
      v.bearingBow = (p.deference - personal * 0.20 - house * 0.15)
          .clamp(0.0, 1.0)
          .toDouble();
      v.bearingTense = (p.wariness - personal * 0.25 - house * 0.18)
          .clamp(0.0, 1.0)
          .toDouble();
      v.bearingLift =
          (p.cheer + personal * 0.25 + house * 0.18 - p.wariness * 0.5)
              .clamp(0.0, 1.0)
              .toDouble();

      // KILIK — ambarın hâli kumaşa iner (Faz 5). Köy geneli tek değerdir:
      // kıtlık kimseyi ayırmaz, herkesin keteni aynı solar. Hane/servet
      // ayrımı BİLEREK yok — "kim daha zengin" ayrı bir eksen (hane kuşağı
      // zaten onu söylüyor), burada konuşan köyün ambarı.
      v.provision = p.provision;

      // TELAŞ — adım sıklığı. speed getter'ı bunu diğer çarpanlarla (yaralı,
      // yüklü, kaçan) ÇARPAR; burada yalnız köyün hâlinden gelen pay yazılır.
      v.paceFactor = p.hurry;

      // PAYDOS — süresi dolanı işine bırak, dolmayanı say.
      if (v.workPause > 0) {
        v.workPause -= elapsed;
        continue;
      }
      // Üstlenilmiş işi olan (inşaat/tarla/maden) yarım bırakmaz; paydos
      // yalnız meslek döngüsü sürenlere işler.
      if (pauseChance <= 0 || v.hasActiveJob || !_hasJobLoop(v)) continue;
      if (_rng.nextDouble() < pauseChance) {
        // Yaklaşık yarım oyun günü çeyreği — "bugün çalışılmıyor" okunacak
        // kadar uzun, günü öldürecek kadar değil.
        v.workPause = 60.0 + _rng.nextDouble() * 80.0;
      }
    }
  }

  /// GECE NÖBETİ — muhafızların ne kadarı geceyi uyanık geçirir.
  ///
  /// Seçim rastgele DEĞİL, listedeki sıraya göre deterministik: aynı köyde aynı
  /// muhafızlar nöbetçidir, her saniye başkası uyanmaz (titreme olurdu).
  /// Nöbetçi sayısı en az 1'e yuvarlanır — devriye açıksa sokakta hiç kimse
  /// olmaması "yasa var ama kimse yok" hissi verirdi.
  void _assignNightWatch(double density) {
    final guards = <VillagerEntity>[];
    for (final v in _villagers) {
      if (v.type != VillagerType.guard || v.isDying || !v.hasProfession) {
        // Muhafız değilse nöbet bayrağı asla takılı kalmasın (meslek değişimi).
        if (v.nightDuty) v.nightDuty = false;
        continue;
      }
      guards.add(v);
    }
    if (guards.isEmpty) return;
    final want = density <= 0.01
        ? 0
        : (guards.length * density).round().clamp(1, guards.length);
    for (int i = 0; i < guards.length; i++) {
      guards[i].nightDuty = i < want;
    }
  }
}
