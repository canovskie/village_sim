import '../world/season.dart';
import 'law_compass.dart';

/// KÖYÜN HÂLİ — dünyanın o anki basıncı, tek okunur tablo.
///
/// Kanunname'nin mühürleri, rejim, mevsim ve huzursuzluk burada TEK bir
/// davranış tablosuna indirgenir; aşağıdaki bütün sistemler (rutin, iş, suç,
/// devriye, gövde dili, meşale) yasaya değil **bu tabloya** bakar.
///
/// SÖZLEŞME — bu dosyaya alan eklemenin tek şartı: alanın gerçekten okunduğu
/// bir yer olmak. Kimsenin okumadığı bir basınç alanı, panelde yanan ama köyde
/// karşılığı olmayan bir sayıdan ibarettir; bu sistem tam olarak onu bitirmek
/// için var. Yeni alan → aynı commit'te tüketicisi.
///
/// Ölçek dili: `*Pull` ve `*Drive` alanları **çarpandır**, 1.0 = taban (hiçbir
/// hüküm yokken köyün normali). 0..1 aralıklı alanlar (deference, wariness…)
/// yoğunluktur, 0 = yok.
class WorldPressure {
  // ── ZAMAN & RUTİN ──────────────────────────────────────────────────────────

  /// Gece eşiği kayması (0 = yasak yok). Köylünün "gece oldu, içeri" kararı
  /// `dayLight < kNightThreshold + curfewBias` ile verilir; bias büyüdükçe köy
  /// daha AYDINLIKKEN sokağı boşaltır. Sokağa çıkma yasağının görünür yüzü bu.
  final double curfewBias;

  /// İş dürtüsü — mesai uzar/kısalır, tezgâh başına dönüş sıklaşır.
  final double workDrive;

  /// Dinlenme/boş vakit dürtüsü — ateş başı, gezinti, komşu.
  final double restDrive;

  // ── MEKÂN & KALABALIK (POI çekim çarpanları) ───────────────────────────────

  final double marketPull;
  final double tavernPull;
  final double wellPull;
  final double firePull;
  final double churchPull;

  /// Meydan/meclis önü — hür rejimin kalabalığı buradan doğar.
  final double squarePull;

  final double homePull;

  /// Komşu ziyareti — mülkçü hükümler kısar, komşuluk beratı açar.
  final double visitPull;

  final double strollPull;

  // ── DEVRİYE ────────────────────────────────────────────────────────────────

  /// Muhafızların ne kadarı fiilen devriyede (0..1). Gece bekçisi fermanı bunu
  /// yükseltir; sokakta görünen muhafız sayısı buradan.
  final double patrolDensity;

  /// Devriyenin uyanıklığı — görüş menzili ve tepki hızı çarpanı.
  final double patrolVigilance;

  // ── GÖVDE DİLİ (0..1 yoğunluk) ─────────────────────────────────────────────

  /// Otoriteye boyun eğme — muhafız yaklaşınca yol verme, baş eğme.
  final double deference;

  /// Sözünü sakınmama — tartışma, el kol hareketi, meydanda toplanma.
  final double outspoken;

  /// Tedirginlik — omuz üstünden bakma, hızlı adım, mesafe koyma.
  final double wariness;

  /// Şenlik — sıçrayan adım, sık gülüşme, dans/müzik eğilimi.
  final double cheer;

  // ── GÖRÜNEN HÂL (Faz 5: basınç → kıyafet / kalabalık / siluet) ─────────────
  //
  // Yukarıdaki alanlar köylünün NE YAPTIĞINI değiştirir; bu üçü köyün NASIL
  // GÖRÜNDÜĞÜNÜ. Aynı köy, aynı binalar, aynı saat — ama ambar boşken kumaş
  // soluk, baskı altında sokak seyrek ve adım hızlı, tedirginlikte omuzlarda
  // şal olur. Yasanın gövdeye inen son kanalı.

  /// Kılık ekseni: **-1 yoksunluk ↔ +1 refah** (0 = taban palet).
  ///
  /// Diğer alanların aksine İŞARETLİ: iki uçlu bir eksen tek sayıyla okunur
  /// olmalı, yoksa renderer iki alanı kendi içinde birleştirmek zorunda kalır.
  /// Eksi tarafta kumaş doygunluğunu yitirir ve gri-kahveye kayar (soluk keten,
  /// yamalı yaka); artı tarafta renk doyar ve hafif aydınlanır.
  ///
  /// Tüketici: `character_renderer._cloth` (tüm giysi renkleri buradan geçer).
  final double provision;

  /// Öbeklenme eğilimi 0..1 (taban 0.35) — sokağın nasıl DOLDUĞU.
  ///
  /// Yüksekken köylü boş bir noktaya değil, insanın olduğu yere gider: meydan
  /// öbeklenir, konuşma halkaları büyür. Düşükken herkes kendi işine yürür,
  /// sokak seyrek okunur. `squarePull` "meydana git" der; bu alan "yanına git"
  /// der — ikisi ayrı şey (dolu meydan ile dağınık meydan aynı çekimle olur).
  ///
  /// Tüketici: `scene_npc_routine._pickErrand` (komşu/öbek adayı ağırlığı).
  final double huddle;

  /// Adım telaşı çarpanı (1.0 = normal tempo).
  ///
  /// Baskı ve tedirginlik sokakta oyalanmayı bitirir: geçişler hızlanır.
  /// Şenlik ve dinginlik tersine ağırlaştırır. Hız kişinin kendi hâlinden
  /// (yaralı/yüklü/kaçan) BAĞIMSIZ bir çarpandır, onlarla çarpılır.
  ///
  /// Tüketici: `VillagerEntity.paceFactor` → `speed`.
  final double hurry;

  // ── NESNE ──────────────────────────────────────────────────────────────────

  /// Gece feneri zorunlu — köylü karanlıkta elinde ışıkla dolaşır.
  final bool lanternMandate;

  // ── SUÇ İKLİMİ ─────────────────────────────────────────────────────────────

  /// Suça yeltenme çarpanı — yoksunluk ve mülk açar, ortaklık kapatır.
  final double crimeUrge;

  /// Yakalanma korkusu — caydırıcılık; failin cesaretini kırar.
  final double crimeRisk;

  /// İhbar eğilimi — tanığın muhafıza koşma ihtimali.
  final double informUrge;

  const WorldPressure({
    this.curfewBias = 0,
    this.workDrive = 1,
    this.restDrive = 1,
    this.marketPull = 1,
    this.tavernPull = 1,
    this.wellPull = 1,
    this.firePull = 1,
    this.churchPull = 1,
    this.squarePull = 1,
    this.homePull = 1,
    this.visitPull = 1,
    this.strollPull = 1,
    this.patrolDensity = 0.5,
    this.patrolVigilance = 1,
    this.deference = 0,
    this.outspoken = 0.25,
    this.wariness = 0,
    this.cheer = 0.2,
    this.provision = 0,
    this.huddle = 0.35,
    this.hurry = 1,
    this.lanternMandate = false,
    this.crimeUrge = 1,
    this.crimeRisk = 1,
    this.informUrge = 0.35,
  });

  /// Hiçbir hüküm mühürlenmemiş köy — her şeyin tabanı.
  static const WorldPressure neutral = WorldPressure();

  /// Köyün hâlini derler. Saf fonksiyon: aynı girdi → aynı tablo (test edilir).
  ///
  /// [sealed] mühürlü hüküm id'leri, [compass] politik konum, [regime] kimlik,
  /// [season] mevsim, [unrest] huzursuzluk 0..1, [dayCount] gün sayacı
  /// (kutsal günün haftalık ritmi buradan), [scarcity] yoksunluk 0..1
  /// (ambar boşsa suç dürtüsü gerçek bir sebeple yükselsin), [plenty] bolluk
  /// 0..1 (ambar ihtiyacın kat kat üstündeyse kılık da onu söylesin).
  static WorldPressure derive({
    required Set<String> sealed,
    required CompassPosition compass,
    required VillageRegime regime,
    required Season season,
    required double unrest,
    required int dayCount,
    double scarcity = 0,
    double plenty = 0,
    Set<String> memory = const {},
  }) {
    final b = _Builder();

    for (final id in sealed) {
      _applyLaw(b, id, season: season, dayCount: dayCount);
    }
    _applyMemory(b, memory);
    _applyRegime(b, regime, compass);
    _applySeason(b, season);
    _applyMood(b, unrest: unrest, scarcity: scarcity);
    // EN SON: görünen hâl, birikmiş tablodan türer (bkz. [_deriveLook]).
    _deriveLook(b, scarcity: scarcity, plenty: plenty);

    return b.freeze();
  }

  /// Tek bir hükmün dünyaya dokunuşu. Buradaki her satır, aşağıda gözle
  /// görülebilecek bir değişikliktir — moral deltası değil.
  static void _applyLaw(
    _Builder b,
    String id, {
    required Season season,
    required int dayCount,
  }) {
    switch (id) {
      // ── GEÇİM ──────────────────────────────────────────────────────────────
      case 'neighborliness': // Komşuluk Beratı
        b.visitPull *= 1.55;
        b.cheer += 0.10;
        b.informUrge += 0.10; // komşu komşuyu kollar
        b.wariness -= 0.05;

      case 'winterFodder': // Kışlık Yem Fermanı
        if (season == Season.winter) {
          b.workDrive *= 1.20; // kışın da ahır işi var
          b.restDrive *= 0.90;
        }

      case 'sharedHarvest': // Müşterek Harman Fermanı
        b.squarePull *= 1.35; // harman meydanda
        b.visitPull *= 1.15;
        b.cheer += 0.08;
        if (season == Season.autumn) b.workDrive *= 1.15;

      case 'irrigation': // Su Yolu Fermanı
        b.wellPull *= 1.80; // kova trafiği: kuyu–tarla arası canlanır
        b.workDrive *= 1.10;

      case 'farmLabor': // Ekin Seferberliği Fermanı
        b.workDrive *= 1.40; // mesai uzar
        b.restDrive *= 0.70;
        b.tavernPull *= 0.70;
        b.strollPull *= 0.75;
        b.cheer -= 0.08;

      case 'hospitality': // Açık Kapı Fermanı
        b.visitPull *= 1.30;
        b.tavernPull *= 1.25;
        b.wariness -= 0.10;
        b.cheer += 0.06;

      case 'familyReunion': // Yuva Kurma Beratı
        b.homePull *= 1.30;
        b.visitPull *= 1.20;

      case 'herdGrowth': // Sürü Beratı
        b.workDrive *= 1.08;

      case 'cropRotation': // Dönemli Ekim Beratı
        b.workDrive *= 0.94; // nadas: tarla nefes alır, çiftçi de

      case 'apprenticeship': // Çıraklık Beratı
        b.workDrive *= 1.06;
        b.visitPull *= 1.10; // çırak ustanın peşinde

      case 'oneChild': // Tek Beşik Fermanı
        b.homePull *= 0.90;
        b.cheer -= 0.10;
        b.wariness += 0.05;

      case 'twoChild': // İki Beşik Fermanı
        b.homePull *= 0.96;

      case 'familyEncouragement': // Beşik Beratı
        b.homePull *= 1.20;
        b.cheer += 0.08;

      case 'tradeGuidance': // Eksik Zanaat Fermanı
        b.workDrive *= 1.10;
        b.marketPull *= 1.15;

      case 'freeRange': // Serbest Otlak Fermanı
        b.strollPull *= 1.25; // sürü uzaklaşır, köy kenarı canlanır

      case 'treePlanting': // Fidan Fermanı
        b.workDrive *= 1.06;
        b.strollPull *= 1.15;

      case 'peacefulEnd': // Huzurlu Son Beratı
        b.churchPull *= 1.35;
        b.cheer += 0.04;
        b.wariness -= 0.05;

      case 'slowMaturity': // Uzun Çocukluk Fermanı
        b.strollPull *= 1.20; // çocuk daha uzun süre oyunda
        b.cheer += 0.06;

      case 'eldersExemptFromFood': // Yaşlıya Saygı Fermanı
        b.restDrive *= 1.15;
        b.firePull *= 1.20; // yaşlılar ateş başında
        b.cheer += 0.05;

      case 'quarantine': // Tecrit Fermanı
        // Kapılar kapanır: komşu ziyareti ve meydan seyrelir, herkes damına
        // çekilir. Tedirginlik hafif artar (kimin hasta olduğu konuşuluyor).
        b.visitPull *= 0.70;
        b.squarePull *= 0.85;
        b.homePull *= 1.20;
        b.wariness += 0.06;
        b.cheer -= 0.04;

      case 'hearthWatch': // Ocak Nöbeti Fermanı
        // Sönmeyen ateş köyü kendine çeker — akşamları meydan ateşi doluyor.
        b.firePull *= 1.45;
        b.squarePull *= 1.10;
        b.cheer += 0.06;
        b.workDrive *= 1.04; // odun taşımak da bir iş

      case 'outsideMarriage': // Dışarıya Nikâh Fermanı
        // Dışarı bakan köy: yol, han, pazar canlanır; yabancıya tedirginlik iner.
        b.marketPull *= 1.20;
        b.tavernPull *= 1.20;
        b.strollPull *= 1.15;
        b.wariness -= 0.06;

      case 'greenVillage': // Yeşil Köy Beratı
        b.strollPull *= 1.35;
        b.cheer += 0.08;
        b.wariness -= 0.05;

      // ── NİZAM ──────────────────────────────────────────────────────────────
      case 'nizam.watch': // Gece Bekçisi Fermanı
        // Caydırıcılığı `crime.watch` bayrağı üstünden [_applyMemory] verir
        // (bu hüküm o bayrağı basar) — burada yalnız hükme özgü kalanı yaz.
        b.patrolDensity += 0.10;
        b.patrolVigilance *= 1.25;
        b.wariness += 0.06;

      case 'nizam.registry': // Hane Sicili Fermanı
        b.deference += 0.12;
        b.crimeRisk *= 1.20;
        b.informUrge += 0.18; // sicil tutulan yerde iz bırakmak zor
        b.wariness += 0.05;

      case 'nizam.labor': // Kürek Cezası Fermanı
        b.workDrive *= 1.15;
        b.deference += 0.18;
        b.crimeRisk *= 1.35;
        b.cheer -= 0.10;
        b.outspoken -= 0.08;

      case 'nizam.exile': // Sürgün Fermanı
        b.deference += 0.15;
        b.crimeRisk *= 1.30;
        b.informUrge += 0.10;
        b.wariness += 0.10;
        b.visitPull *= 0.92;

      case 'nizam.bloodPrice': // Diyet Fermanı
        // Öç elden alınınca kan davası gerilimi düşer: köy birbirine daha az
        // diş biler ama hesabı kesenin tutması gerektiğini de bilir.
        b.wariness -= 0.05;
        b.deference += 0.08;
        b.visitPull *= 1.10; // husumetli haneler yeniden birbirine uğrar
        b.crimeUrge *= 1.06; // "bedeli ödenir" fikri eli biraz gevşetir

      case 'nizam.sole': // Tek Söz Fermanı — köyün en sert hükmü
        b.curfewBias += 0.16; // sokak erken boşalır
        b.lanternMandate = true; // karanlıkta yüzsüz dolaşılmaz: elde ışık
        b.deference += 0.35;
        b.outspoken -= 0.30;
        b.squarePull *= 0.45; // meydanda toplanılmaz
        b.tavernPull *= 0.70;
        b.visitPull *= 0.75;
        b.homePull *= 1.30;
        b.wariness += 0.22;
        b.cheer -= 0.15;
        b.patrolDensity += 0.25;
        b.patrolVigilance *= 1.30;
        b.crimeRisk *= 1.60;
        b.informUrge += 0.20;

      // ── DERGÂH ─────────────────────────────────────────────────────────────
      case 'dergah.holyDay': // Kutsal Gün Fermanı — haftalık ritim
        final holy = dayCount % 7 == 0;
        if (holy) {
          b.workDrive *= 0.45; // o gün çalışılmaz
          b.churchPull *= 2.40;
          b.squarePull *= 1.60;
          b.restDrive *= 1.40;
          b.cheer += 0.18;
        } else {
          b.churchPull *= 1.10;
        }

      case 'dergah.lodge': // Dergâh Fermanı
        b.churchPull *= 1.45;
        b.restDrive *= 1.10;

      case 'dergah.tithe': // Öşür Fermanı
        b.churchPull *= 1.25;
        b.marketPull *= 0.90;
        b.crimeUrge *= 1.08; // kesilen paydan doğan hınç

      case 'dergah.penance': // Tövbe Meydanı Fermanı
        b.squarePull *= 1.40; // tövbe meydanda edilir, herkes görür
        b.churchPull *= 1.20;
        b.crimeRisk *= 1.15;
        b.deference += 0.08;

      case 'dergah.oneFaith': // Tek İnanç Fermanı
        b.churchPull *= 1.80;
        b.deference += 0.20;
        b.outspoken -= 0.18;
        b.wariness += 0.10;
        b.informUrge += 0.12;

      // ── REJİM FERMANLARI ───────────────────────────────────────────────────
      case 'rejim.meclisDaimi': // Meclis-i Daimi Fermanı
        b.squarePull *= 2.00; // meclis önü hiç boşalmaz
        b.outspoken += 0.30;
        b.deference -= 0.12;
        b.cheer += 0.06;

      case 'rejim.mulkTapusu': // Mülk Tapusu Fermanı
        b.homePull *= 1.35; // herkes kendi mülkünde
        b.visitPull *= 0.75;
        b.marketPull *= 1.30;
        b.crimeUrge *= 1.25; // çalınacak bir "senin"i olması gerekir

      case 'rejim.ortakAmbar': // Ortak Ambar Fermanı
        // "Kimse fazladan bir kova taşımadı — pay nasılsa eşit." Getirisi
        // açlık eşiğinde (bkz. scene_pressure._starveRamp), bedeli burada:
        // eşit pay üretim hevesini kırar. İkisi olmadan ferman tek yönlüydü.
        b.workDrive *= 0.88;
        b.marketPull *= 0.70;
        b.squarePull *= 1.25;
        b.visitPull *= 1.20;
        b.crimeUrge *= 0.65; // ortak malın hırsızı olmaz

      case 'rejim.muhassil': // Muhassıl Fermanı
        b.patrolDensity += 0.20;
        b.deference += 0.15;
        b.marketPull *= 1.15;
        b.crimeUrge *= 1.10;
        b.wariness += 0.08;
    }
  }

  /// Köy hafızasındaki kalıcı bayraklar — yasa olmayan ama dünyayı bağlayan
  /// kararlar (dilekçeyle kurulan nöbet, kurulan dergâh…). Yasa yolu bunları
  /// zaten kendi `setsFlags`'iyle bastığı için etki BURADA tek kez uygulanır;
  /// [_applyLaw] aynı bayrağı ikinci kez çarpmaz (çift sayım tuzağı).
  static void _applyMemory(_Builder b, Set<String> memory) {
    if (memory.contains('crime.watch')) {
      // Gece nöbeti — ister yasadan ister dilekçeden gelsin, sokakta gözü olan
      // bir köy suçu zor kaldırır.
      b.crimeRisk *= 1.55;
      b.patrolDensity += 0.25;
    }
    if (memory.contains('holyDay.active')) {
      b.churchPull *= 1.15;
    }
    if (memory.contains('cult.active')) {
      b.churchPull *= 1.20;
      b.deference += 0.05;
    }
  }

  /// Rejimin kendi rengi — tek tek hükümlerin toplamı değil, kimliğin tonu.
  /// Pusula şiddeti ([CompassPosition.intensity]) etkiyi ölçekler: köy kimliğine
  /// ne kadar kök salmışsa siluet o kadar keskin.
  static void _applyRegime(
      _Builder b, VillageRegime regime, CompassPosition compass) {
    final k = compass.intensity.clamp(0.0, 1.0);
    if (k <= 0.01) return;

    switch (regime) {
      case VillageRegime.moderate:
        break;

      case VillageRegime.commune: // 🤝 Hür + Ortakçı
        b.squarePull *= 1 + 0.55 * k;
        b.visitPull *= 1 + 0.40 * k;
        b.outspoken += 0.22 * k;
        b.cheer += 0.12 * k;
        b.homePull *= 1 - 0.15 * k;
        b.crimeUrge *= 1 - 0.20 * k;

      case VillageRegime.market: // 🏪 Hür + Mülkçü
        b.marketPull *= 1 + 0.70 * k;
        b.tavernPull *= 1 + 0.30 * k;
        b.outspoken += 0.15 * k;
        b.workDrive *= 1 + 0.18 * k;
        b.visitPull *= 1 - 0.15 * k;
        b.crimeUrge *= 1 + 0.18 * k;

      case VillageRegime.ironTable: // ⚖ Baskı + Ortakçı
        b.workDrive *= 1 + 0.30 * k;
        b.deference += 0.28 * k;
        b.outspoken -= 0.22 * k;
        b.squarePull *= 1 + 0.20 * k; // toplanma var ama emirle
        b.marketPull *= 1 - 0.25 * k;
        b.patrolDensity += 0.20 * k;
        b.cheer -= 0.10 * k;

      case VillageRegime.sealedHand: // 👑 Baskı + Mülkçü
        b.deference += 0.35 * k;
        b.outspoken -= 0.30 * k;
        b.squarePull *= 1 - 0.40 * k;
        b.homePull *= 1 + 0.30 * k;
        b.visitPull *= 1 - 0.30 * k;
        b.patrolDensity += 0.30 * k;
        b.patrolVigilance *= 1 + 0.25 * k;
        b.wariness += 0.20 * k;
        b.cheer -= 0.15 * k;
        b.curfewBias += 0.06 * k;
    }

    // İman overlay — mühürden bağımsız, pusulanın dinî ekseni.
    if (compass.faith > 0.35) {
      final f = ((compass.faith - 0.35) / 0.65).clamp(0.0, 1.0);
      b.churchPull *= 1 + 0.60 * f;
      b.deference += 0.10 * f;
    }
  }

  /// Mevsimin dünyaya dokunuşu — yasadan bağımsız, ama aynı tablodan konuşur.
  static void _applySeason(_Builder b, Season season) {
    switch (season) {
      case Season.spring:
        b.strollPull *= 1.15;
        b.cheer += 0.06;
      case Season.summer:
        b.wellPull *= 1.30; // sıcakta su
        b.strollPull *= 1.10;
        b.workDrive *= 1.05;
      case Season.autumn:
        b.workDrive *= 1.12; // hasat telaşı
        b.marketPull *= 1.15;
      case Season.winter:
        b.firePull *= 1.60; // ateş başı
        b.tavernPull *= 1.25;
        b.homePull *= 1.25;
        b.strollPull *= 0.60;
        b.workDrive *= 0.85;
        b.curfewBias += 0.04; // erken kararan gün
    }
  }

  /// Huzursuzluk ve yoksunluk — köyün sinir uçları.
  static void _applyMood(_Builder b,
      {required double unrest, required double scarcity}) {
    final u = unrest.clamp(0.0, 1.0);
    if (u > 0.25) {
      final t = ((u - 0.25) / 0.75).clamp(0.0, 1.0);
      b.wariness += 0.30 * t;
      b.cheer -= 0.25 * t;
      b.outspoken += 0.20 * t; // huzursuzluk önce dile gelir
      b.squarePull *= 1 + 0.35 * t; // sonra meydana
      b.crimeUrge *= 1 + 0.55 * t;
      b.informUrge -= 0.15 * t; // kimse kimseyi ele vermez
      b.tavernPull *= 1 + 0.20 * t;
    }

    final s = scarcity.clamp(0.0, 1.0);
    if (s > 0.05) {
      b.crimeUrge *= 1 + 0.90 * s; // açlık en eski sebep
      b.cheer -= 0.20 * s;
      b.wariness += 0.15 * s;
      b.marketPull *= 1 + 0.25 * s;
      b.workDrive *= 1 + 0.15 * s;
    }
  }

  /// GÖRÜNEN HÂL — köyün nasıl göründüğü, ne yaptığından TÜRETİLİR.
  ///
  /// Bilinçli olarak hüküm hüküm yazılmaz: her fermana ayrıca "şu kadar
  /// öbeklen, şu kadar acele et" satırı eklemek 34 yerde tekrar demekti ve ilk
  /// unutulan hükümde köy sessizce eski görüntüsünde kalırdı. Bunun yerine üç
  /// kanal, YUKARIDA birikmiş gövde dili alanlarından okunur — yani yeni bir
  /// hüküm `deference`/`wariness`/`cheer`/`curfewBias` değerlerine dokunduğu an
  /// görüntüsü de kendiliğinden değişir. Sözleşme: bu üç alanın kaynağı tektir.
  static void _deriveLook(_Builder b,
      {required double scarcity, required double plenty}) {
    // KILIK — ambarın hâli. Yoksunluk kumaşı soldurur, bolluk doyurur.
    // Yoksunluk daha AĞIR basar (0.9 vs 0.7): aç köy, tok köyden daha çabuk
    // okunur olmalı; refah sessiz bir zenginliktir, kıtlık bağırır.
    b.provision = plenty.clamp(0.0, 1.0) * 0.7 - scarcity.clamp(0.0, 1.0) * 0.9;

    // KALABALIK — insanın insana yaklaşma isteği. Sözü açık ve şen köy
    // öbeklenir; itaat, tedirginlik ve sokağa çıkma yasağı dağıtır.
    // curfewBias'ın katsayısı yüksek (2.0) ama alanın kendisi 0.22'de tavanlı →
    // en sert yasakta bile öbeklenmeyi tamamen sıfırlamaz, seyreltir.
    b.huddle = 0.35 +
        (b.outspoken - 0.25) * 0.55 +
        (b.cheer - 0.2) * 0.35 +
        (b.squarePull - 1) * 0.18 +
        (b.visitPull - 1) * 0.12 -
        b.deference * 0.45 -
        b.wariness * 0.40 -
        b.curfewBias * 2.0;

    // TELAŞ — sokakta oyalanma mı, geçip gitme mi. Tedirgin ve itaatkâr köy
    // hızlı yürür; şen ve dinlenmeye vakti olan köy ağır.
    b.hurry = 1.0 +
        b.wariness * 0.22 +
        b.deference * 0.15 +
        b.curfewBias * 0.80 -
        (b.cheer - 0.2) * 0.12 -
        (b.restDrive - 1) * 0.10;
  }

  /// Panelde/konsolda okunur özet — hangi basıncın açık olduğunu tek bakışta
  /// görmek için (dev günlüğü ve Divan "köyün hâli" satırı).
  List<String> get readout {
    final out = <String>[];
    void mul(String label, double v, {double eps = 0.06}) {
      if ((v - 1).abs() < eps) return;
      final pct = ((v - 1) * 100).round();
      out.add('$label ${pct > 0 ? '+' : ''}$pct%');
    }

    void lvl(String label, double v, {double eps = 0.08}) {
      if (v.abs() < eps) return;
      out.add('$label ${(v * 100).round()}');
    }

    if (curfewBias > 0.02) out.add('sokağa çıkma ${(curfewBias * 100).round()}');
    mul('mesai', workDrive);
    mul('meydan', squarePull);
    mul('pazar', marketPull);
    mul('meyhane', tavernPull);
    mul('mabet', churchPull);
    mul('komşu', visitPull);
    mul('ev', homePull);
    mul('kuyu', wellPull);
    mul('ateş', firePull);
    mul('gezinti', strollPull);
    lvl('devriye', patrolDensity - 0.5);
    lvl('itaat', deference);
    lvl('söz', outspoken - 0.25);
    lvl('tedirginlik', wariness);
    lvl('şenlik', cheer - 0.2);
    lvl('kılık', provision, eps: 0.10);
    lvl('öbeklenme', huddle - 0.35, eps: 0.10);
    mul('telaş', hurry);
    mul('suç dürtüsü', crimeUrge);
    mul('caydırıcılık', crimeRisk);
    if (lanternMandate) out.add('fener mecburi');
    return out;
  }
}

/// Değiştirilebilir ara tablo — [WorldPressure.derive] içinde biriktirilir,
/// sonunda sınırlara kıstırılıp dondurulur.
class _Builder {
  double curfewBias = 0;
  double workDrive = 1;
  double restDrive = 1;
  double marketPull = 1;
  double tavernPull = 1;
  double wellPull = 1;
  double firePull = 1;
  double churchPull = 1;
  double squarePull = 1;
  double homePull = 1;
  double visitPull = 1;
  double strollPull = 1;
  double patrolDensity = 0.5;
  double patrolVigilance = 1;
  double deference = 0;
  double outspoken = 0.25;
  double wariness = 0;
  double cheer = 0.2;
  double provision = 0;
  double huddle = 0.35;
  double hurry = 1;
  bool lanternMandate = false;
  double crimeUrge = 1;
  double crimeRisk = 1;
  double informUrge = 0.35;

  /// Tavanlar bilinçli: hükümler üst üste binse bile köy tanınmaz hâle gelmesin.
  /// Özellikle [curfewBias] sert kısıtlı — aksi hâlde köy gündüz vakti yatar.
  WorldPressure freeze() => WorldPressure(
        curfewBias: curfewBias.clamp(0.0, 0.22),
        workDrive: workDrive.clamp(0.35, 2.0),
        restDrive: restDrive.clamp(0.40, 2.0),
        marketPull: marketPull.clamp(0.20, 3.0),
        tavernPull: tavernPull.clamp(0.20, 3.0),
        wellPull: wellPull.clamp(0.20, 3.0),
        firePull: firePull.clamp(0.20, 3.0),
        churchPull: churchPull.clamp(0.20, 3.5),
        squarePull: squarePull.clamp(0.15, 3.5),
        homePull: homePull.clamp(0.30, 3.0),
        visitPull: visitPull.clamp(0.20, 3.0),
        strollPull: strollPull.clamp(0.20, 3.0),
        patrolDensity: patrolDensity.clamp(0.0, 1.0),
        patrolVigilance: patrolVigilance.clamp(0.5, 2.2),
        deference: deference.clamp(0.0, 1.0),
        outspoken: outspoken.clamp(0.0, 1.0),
        wariness: wariness.clamp(0.0, 1.0),
        cheer: cheer.clamp(0.0, 1.0),
        // Kılık iki uçlu; tavanlar bilinçli olarak 1'in altında değil, çünkü
        // renderer zaten kendi içinde ölçekliyor (bkz. _cloth).
        provision: provision.clamp(-1.0, 1.0),
        huddle: huddle.clamp(0.0, 1.0),
        // Telaş dar bantta: köy koşmaz, adımını sıklaştırır. 1.35 üstü
        // "herkes kaçıyor" gibi durur, 0.85 altı sim'i uyuşuk gösterir.
        hurry: hurry.clamp(0.85, 1.35),
        lanternMandate: lanternMandate,
        crimeUrge: crimeUrge.clamp(0.15, 3.0),
        crimeRisk: crimeRisk.clamp(0.40, 3.0),
        informUrge: informUrge.clamp(0.0, 1.0),
      );
}
