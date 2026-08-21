// REJİM — pusulanın oyuncuya DOKUNAN yarısı.
//
// [law_compass.dart] köyün nereye yattığını hesaplar; bu dosya o yatışın
// SONUÇLARINI tanımlar. Kanunname'nin asıl sözü buydu: "kimlik seçilmez,
// mühürlerle kazanılır" — ama kazanılan kimliğin bir bedeli ve bir ayrıcalığı
// yoksa pusula yalnız bir süstür.
//
// Üç şey burada tanımlanır:
//
//   1. YETKİ ([RegimeRule]) — rejim oyuncunun kendi gücünü büker. Baskı rejimi
//      hızlı mühür + susturulmuş dilekçe verir; hür rejim seni yavaşlatır ve
//      meclis SANA RAĞMEN karar verebilir. "Tiran mutlaktır, demokrat kısıtlı."
//
//   2. HUZURSUZLUK ([unrestStep]) — her rejim kendi çürümesini besler. Bu bir
//      game-over çubuğu DEĞİL: eşiği aşınca rejime özgü bir KRİZ doğar, kriz
//      yeni bir uğraş açar (cozy çizgi korunur).
//
//   3. MECLİS ([voteOnLaw], [pickCouncilOption]) — hür rejimde köyün kendi
//      iradesi. Ferman oya sunulur, bekleyen dilekçeyi köy kendi çözer.
//
// Saf mantık: Flutter yok, sahne yok, rastgelelik yok → test edilebilir.
import 'estate_system.dart';
import 'law_compass.dart';
import 'petition_system.dart';

/// Rejime özgü çürüme biçimi. Her biri farklı bir dünyada-yaşayan sonuç doğurur.
enum RegimeCrisis {
  /// Merkez cezasızdır — ılımlı köy sönük olabilir, ama zorlanmaz.
  none,

  /// 👑 Mühürlü El: korku moral yer, altta isyan kaynar.
  revolt,

  /// 🤝 Ortak Ocak: herkes konuşur, kimse karar veremez.
  deadlock,

  /// ⚖ Demir Sofra: zorla paylaşımın bedeli sinsi bir tembellik.
  idleness,

  /// 🏪 Açık Pazar: kese açık ama makas da açık.
  inequality,
}

/// Rejimin OYUNCUYA ne yaptığı. Sayılar tasarım kararıdır; denge tek yerde.
class RegimeRule {
  /// Kadranda/Divan'da yazan yetki başlığı — oyuncu ne olduğunu tek bakışta
  /// görsün ("MUTLAK SÖZ" ile "MECLİS ORTAK" aynı oyun değildir).
  final String powerTitle;

  /// Yetkinin tek cümlelik somut karşılığı (ne kazandın, ne kaybettin).
  final String powerNote;

  /// Müzakere temposu çarpanı. Baskıda mürekkep çabuk kurur (0.6 = %40 hızlı),
  /// hür rejimde meclis konuşur (1.35 = %35 yavaş).
  final double inkDryMul;

  /// Mühlet dolunca köy KENDİ kararını verir mi (hür rejim). false ise mühlet
  /// dolumu klasik zorunlu huzurdur ya da [ignoresPetitions] ile susar.
  final bool councilDecides;

  /// Ferman meclis oyuna sunulur mu — hür + KÖKLÜ rejimde evet. Oyun geçmezse
  /// mühür basılmaz; mürekkep yine de bir süre ıslak kalır (meclis dağılır).
  final bool councilVotesLaws;

  /// Baskı rejimi: köyün istek kanalı susar — mühlet dolan dilekçe zorunlu
  /// huzura değil, sessizce ÇÖPE gider. Bedeli huzursuzluktur.
  final bool ignoresPetitions;

  /// Meclisin kararını veto etmenin köy moraline maliyeti (hür rejim).
  final double vetoMoraleCost;

  /// Günlük huzursuzluk birikimi (rejimin kendi doğası).
  final double unrestPerDay;

  /// Yüksek moralin günlük yatıştırması — tavan değeri; moral 0.45'in altında
  /// hiç yatıştırmaz, 1.0'da tamamı işler.
  final double unrestRelief;

  /// Eşiği aşınca doğan kriz.
  final RegimeCrisis crisis;

  const RegimeRule({
    required this.powerTitle,
    required this.powerNote,
    required this.inkDryMul,
    required this.councilDecides,
    required this.councilVotesLaws,
    required this.ignoresPetitions,
    required this.vetoMoraleCost,
    required this.unrestPerDay,
    required this.unrestRelief,
    required this.crisis,
  });
}

/// İmanın MEKANİK karşılığı — pusuladaki dinî boyanın gerçek sonuçları.
/// Hepsi mevcut sistemlere küçük ama hissedilir kancalar (bkz. [Regime.faithEffectOf]).
class FaithEffect {
  /// Günlük huzursuzluk yatıştırmasına eklenen (sabır/kader).
  final double unrestRelief;

  /// İmparatorluğa direniş şansına eklenen (inanç için durmak).
  final double resistBonus;

  /// Suç baskısı çarpanı (<1 — cemaat gözü suçu kısar).
  final double crimeDamp;

  /// Köy moral tabanına eklenen teselli.
  final double moraleFloor;

  /// Devşirmenin iç faturası çarpanı (>1 — evladı yabancıya vermek ağır).
  final double conscriptSting;

  /// Kadranda gösterilen tek cümle (bant altında boş).
  final String note;

  const FaithEffect({
    required this.unrestRelief,
    required this.resistBonus,
    required this.crimeDamp,
    required this.moraleFloor,
    required this.conscriptSting,
    required this.note,
  });
}

/// Köyün rejiminden gelen dış-güç duruşu — imparatorluk pazarlığını büker.
class ImperialPosture {
  /// Direniş şansına eklenen (militan rejim +, tüccar rejim −).
  final double resistBonus;

  /// Pazarlık eşiğinden düşülen (tüccar rejim daha ucuza anlaşır).
  final double haggleEase;

  /// İmparatorluğun gördüğü servet çarpanı — mülkçü köy daha çok göz doldurur,
  /// ortakçı köy gözden ırak kalır (ziyaret sıklığı + talep sertliği).
  final double attentionMul;

  /// Modal'da gösterilen tek cümlelik duruş (boş = merkez, çizilmez).
  final String note;

  const ImperialPosture({
    required this.resistBonus,
    required this.haggleEase,
    required this.attentionMul,
    required this.note,
  });
}

/// Köyün imparatorluk talebine karşı ortak duruşu — hür rejimde meclis seçer.
/// [comply] öde/fidye ver, [haggle] pazarlık et, [resist] diren ve kov.
/// "Reddet" (bilinçli kıyım) meclisin önerisi ASLA olmaz; o oyuncunun kendi
/// pervasız tercihidir.
enum ImperialVerdict { comply, haggle, resist }

/// Meclisteki tek bir sesin oyu — ritüelde yüz yüze okunur.
class CouncilVoice {
  final Estate estate;
  final bool yes;
  final String line;
  const CouncilVoice(this.estate, this.yes, this.line);
}

/// Bir fermanın meclis oylaması.
class CouncilVote {
  /// Destek oranı 0..1 (kaç zümre evet dedi).
  final double support;
  final bool passed;
  final List<CouncilVoice> voices;
  const CouncilVote(this.support, this.passed, this.voices);
}

abstract final class Regime {
  /// Huzursuzluk kıpırdanma eşiği — köy homurdanmaya başlar (herald anı).
  static const double kStir = 0.55;

  /// Kriz eşiği — rejime özgü olay patlar.
  static const double kCrisis = 0.85;

  /// Yemin edilebilmesi için gereken kararlılık (pusula yoğunluğu). Köklü
  /// olmayan bir köy kendini ilan edemez — [LawCompass.kConvictionBand] ile
  /// aynı sınır: "sinsi kayma seni ele verir, yemin seni mühürler".
  static const double kOathConviction = LawCompass.kConvictionBand;

  static RegimeRule ruleOf(VillageRegime r, {bool oath = false}) {
    final base = _base(r);
    if (!oath || r == VillageRegime.moderate) return base;
    // YEMİN: rejimin hem ayrıcalığını hem ataletini derinleştirir. Uçlar daha
    // uç, bedeller daha ağır — "yemin seni mühürler".
    return RegimeRule(
      powerTitle: base.powerTitle,
      powerNote: base.powerNote,
      inkDryMul: base.inkDryMul < 1
          ? base.inkDryMul *
                0.85 // baskı: daha da hızlı
          : base.inkDryMul * 1.10, // hür: meclis daha da ağır işler
      councilDecides: base.councilDecides,
      councilVotesLaws: base.councilVotesLaws,
      ignoresPetitions: base.ignoresPetitions,
      vetoMoraleCost: base.vetoMoraleCost * 1.5,
      unrestPerDay: base.unrestPerDay * 1.35,
      unrestRelief: base.unrestRelief,
      crisis: base.crisis,
    );
  }

  static RegimeRule _base(VillageRegime r) => switch (r) {
    // Merkez CEZASIZ — ılımlı köy sönüktür ama zorlanmaz.
    VillageRegime.moderate => const RegimeRule(
      powerTitle: 'SÖZÜN GEÇER',
      powerNote:
          'Kimse itiraz etmiyor, kimse de arkanda değil. '
          'Uçların gücüne erişemezsin ama bedelini de ödemezsin.',
      inkDryMul: 1.0,
      councilDecides: false,
      councilVotesLaws: false,
      ignoresPetitions: false,
      vetoMoraleCost: 0,
      unrestPerDay: 0,
      unrestRelief: 0.05,
      crisis: RegimeCrisis.none,
    ),
    VillageRegime.commune => const RegimeRule(
      powerTitle: 'MECLİS ORTAK',
      powerNote:
          'Ferman meclis oyuna sunulur, bekleyen dilekçeyi köy '
          'kendi çözer. Yavaşsın ama meşrusun.',
      inkDryMul: 1.35,
      councilDecides: true,
      councilVotesLaws: true,
      ignoresPetitions: false,
      vetoMoraleCost: 0.07,
      unrestPerDay: 0.010,
      unrestRelief: 0.050,
      crisis: RegimeCrisis.deadlock,
    ),
    VillageRegime.market => const RegimeRule(
      powerTitle: 'AZ MÜDAHALE',
      powerNote:
          'Köy kendi işini görür; sen karışmazsan da döner. '
          'Ama para konuşur, makas açılır.',
      inkDryMul: 1.15,
      councilDecides: true,
      councilVotesLaws: false,
      ignoresPetitions: false,
      vetoMoraleCost: 0.035,
      unrestPerDay: 0.012,
      unrestRelief: 0.045,
      crisis: RegimeCrisis.inequality,
    ),
    VillageRegime.ironTable => const RegimeRule(
      powerTitle: 'YÜKSEK YETKİ',
      powerNote:
          'Eşitliği dağıtan el senin: mühür çabuk basılır, itiraz '
          'kısadır. Bedeli sinsi bir tembellik.',
      inkDryMul: 0.80,
      councilDecides: false,
      councilVotesLaws: false,
      ignoresPetitions: false,
      vetoMoraleCost: 0.02,
      unrestPerDay: 0.018,
      unrestRelief: 0.035,
      crisis: RegimeCrisis.idleness,
    ),
    VillageRegime.sealedHand => const RegimeRule(
      powerTitle: 'MUTLAK SÖZ',
      powerNote:
          'Mühür anında basılır, dilekçe susar. Kimse itiraz '
          'etmiyor — sebebi rıza değil ve sen bunu biliyorsun.',
      inkDryMul: 0.60,
      councilDecides: false,
      councilVotesLaws: false,
      ignoresPetitions: true,
      vetoMoraleCost: 0,
      unrestPerDay: 0.028,
      unrestRelief: 0.030,
      crisis: RegimeCrisis.revolt,
    ),
  };

  /// Bir gün(ün parçası) için huzursuzluk deltası.
  ///
  /// Yüksek moral huzursuzluğu FRENLER ama sıfırlamaz: Mühürlü El'de tam moral
  /// bile birikimi ancak dengeler (0.028 kazanç ↔ 0.030 yatıştırma). Yani tiran
  /// köy ayakta kalabilir — ama tek bir kötü mevsim onu kenara iter.
  static double unrestStep(
    RegimeRule rule, {
    required double morale,
    required double days,
  }) {
    final calm = rule.unrestRelief * ((morale - 0.45) / 0.55).clamp(0.0, 1.0);
    return (rule.unrestPerDay - calm) * days;
  }

  // ── ÇÜRÜME — huzursuzluğun bıraktığı KALICI iz ──────────────────────────────
  //
  // [unrestStep] hızlı bir nabızdır: olayla sıçrar, kararla iner. Ama sürekli
  // kaynayan bir köy iyileşince eski köy olmaz — bir yara izi kalır. Çürüme o
  // izdir: yavaş birikir, çok daha yavaş geçer, ve eşiği aşınca rejime özgü
  // KRONİK bir hâl doğurur (tek atımlık kriz değil, süregiden bir durum).
  //
  // Oyun-sonu DEĞİL: kronik hâl yeni bir uğraş açar, köyü öldürmez. Çıkışı da
  // kapalı değildir — köy uzun süre sakin kalırsa iz yavaşça silinir.

  /// Kronik hâlin başladığı eşik — rejime özgü süregiden bedel devreye girer.
  static const double kChronic = 0.60;

  /// Rejimin çözülme eşiği — kronik bedel ağırlaşır, dış güç kokuyu alır.
  static const double kFailing = 0.85;

  /// Bir gün(ün parçası) için çürüme deltası.
  ///
  /// Yalnız köy KAYNARKEN (kStir üstü) birikir; sakinken siler. Birikim silmeden
  /// ~2 kat hızlıdır: bir köyü çürütmek, iyileştirmekten kolaydır.
  static double rotStep({required double unrest, required double days}) {
    if (unrest >= kStir) {
      final over = ((unrest - kStir) / (1.0 - kStir)).clamp(0.0, 1.0);
      return (0.035 + 0.075 * over) * days;
    }
    // Sakin köy izini yavaşça siler — ne kadar sakinse o kadar hızlı.
    final calm = ((kStir - unrest) / kStir).clamp(0.0, 1.0);
    return -0.020 * calm * days;
  }

  /// Her krizin bıraktığı ek iz — kriz atlatılsa bile köy bir şey kaybeder.
  static const double kRotPerCrisis = 0.12;

  /// Kronik hâlin okunur adı + köyün ağzından ne olduğu. Rejime özgü: her köy
  /// kendi seçtiği yoldan çürür.
  static (String, String) chronicText(RegimeCrisis c) => switch (c) {
    RegimeCrisis.revolt => (
      'KÖY BÖLÜNDÜ',
      'Artık iki köy var: senin gördüğün ve ambar arkasında toplanan. '
          'Kimse gitmiyor, kimse de kalmıyor.',
    ),
    RegimeCrisis.deadlock => (
      'DİVAN FELCİ',
      'Meclis toplanıyor, dağılıyor, yine toplanıyor. Mürekkep '
          'kurumadan yeni bir tartışma başlıyor.',
    ),
    RegimeCrisis.idleness => (
      'DURGUNLUK',
      'Tezgâh açık, eller yavaş. Kimse tembel değil; kimse de acele '
          'etmiyor. Köy kendi hızını unuttu.',
    ),
    RegimeCrisis.inequality => (
      'İKİ AYRI KÖY',
      'Bir uçta iki damlı haneler, öbür uçta sazlıkta yatanlar. '
          'Aynı çeşmeden su içiyorlar, aynı köyde yaşamıyorlar.',
    ),
    RegimeCrisis.none => ('', ''),
  };

  /// Çürümenin okunur hâli.
  static String rotLabel(double rot) => rot >= kFailing
      ? 'çözülüyor'
      : rot >= kChronic
      ? 'kronikleşti'
      : rot >= 0.30
      ? 'iz bıraktı'
      : 'sağlam';

  /// Huzursuzluğun okunur hâli — Divan'da tek kelime.
  static String unrestLabel(double u) => u >= kCrisis
      ? 'kaynıyor'
      : u >= kStir
      ? 'kıpırdanıyor'
      : u >= 0.25
      ? 'homurdanıyor'
      : 'sakin';

  /// Kriz başlığı + köyün ağzından ne olduğu.
  static (String, String) crisisText(RegimeCrisis c) => switch (c) {
    RegimeCrisis.revolt => (
      'İSYAN KAYNIYOR',
      'Ambar arkasında toplananlar var. Konuşmayı kesmiyorlar, '
          'sen geçerken kesiyorlar.',
    ),
    RegimeCrisis.deadlock => (
      'MECLİS KİLİTLENDİ',
      'Herkes konuştu, kimse ikna olmadı. Divan üç gündür aynı '
          'cümlenin etrafında dönüyor.',
    ),
    RegimeCrisis.idleness => (
      'TEZGÂH SOĞUDU',
      'Pay nasılsa eşit; kimse fazladan bir kova taşımıyor. '
          'İş görünüyor ama iş yürümüyor.',
    ),
    RegimeCrisis.inequality => (
      'MAKAS AÇILDI',
      'Bir hane iki ev birden yaptırdı, öbürü sazlıkta yatıyor. '
          'Aynı köyde iki ayrı kış yaşanıyor.',
    ),
    RegimeCrisis.none => ('', ''),
  };

  // ── İMAN — overlay'in MEKANİK gövdesi ───────────────────────────────────────
  //
  // İman pusulada ayrı bir sert eksen değil, rejimin üstüne binen bir BOYA
  // ([RegimeIdentity.religious] — Mühürlü El → Şeyh Beyliği). Ama boya yalnız
  // ismi değiştiriyorsa oyuncu için yoktur. Bu blok imanın gerçek karşılığını
  // verir: inanan köy sıkıntıya daha çok DAYANIR, suça daha az meyleder, dış
  // güce karşı inancı için dimdik durur — ama evladını yabancıya vermek ona
  // çok daha ağır gelir.
  //
  // Değerler [LawCompass.kFaithBand] (0.45) civarında anlam kazanır; altında
  // etkiler küçüktür (köyde bir kandil yanıyor, o kadar).

  static FaithEffect faithEffectOf(double faith) {
    final f = faith.clamp(0.0, 1.0);
    // Bant altında etki cılız kalsın: eğrinin ağırlığı bandın ÜSTÜNDE.
    final w = f <= LawCompass.kFaithBand
        ? f * 0.45 / LawCompass.kFaithBand * 0.45
        : 0.45 +
              (f - LawCompass.kFaithBand) / (1 - LawCompass.kFaithBand) * 0.55;
    return FaithEffect(
      // SABIR — "kader" hikâyesi olan köy yoksulluğu ve baskıyı daha uzun taşır.
      // Bu, dinî bir tiranın neden ayakta kalabildiğinin cevabıdır.
      unrestRelief: 0.018 * w,
      // İnancı için direnen köy, canı için direnenden farklıdır.
      resistBonus: 0.10 * w,
      // Cemaat gözü + günah korkusu: suç baskısı kısılır.
      crimeDamp: 1.0 - 0.28 * w,
      // Teselli: köyün moral tabanı hafifçe yükselir.
      moraleFloor: 0.05 * w,
      // Devşirme: evladı "yoldan çıkmış" bir güce vermek çok daha ağır yara.
      conscriptSting: 1.0 + 0.6 * w,
      note: f < LawCompass.kFaithBand
          ? ''
          : 'İnanan köy: sıkıntıya sabreder, suça az meyleder, inancı için '
                'direnir — ama evladını yabancıya vermek ona ağır gelir.',
    );
  }

  // ── MECLİS ─────────────────────────────────────────────────────────────────

  /// Bir fermanın meclis oylaması. Her zümre kendi çıkarından oy verir:
  /// fermanın o zümreye etkisi + zümrenin o anki hâli + köyün genel morali.
  ///
  /// Küskün bir zümre kendisine dokunmayan fermana bile hayır der — meşruiyet
  /// bedavaya gelmez. Oyuncu bunu ancak hâlleri düzelterek aşar.
  static CouncilVote voteOnLaw({
    required List<(Estate, double)> effects,
    required Map<Estate, double> mood,
    required double villageMorale,
    double threshold = 0.5,
    double traditionSupport = 0,
  }) {
    final eff = <Estate, double>{};
    for (final (e, d) in effects) {
      eff[e] = (eff[e] ?? 0) + d;
    }
    final voices = <CouncilVoice>[];
    var yes = 0;
    for (final e in Estate.values) {
      final d = eff[e] ?? 0.0;
      final m = mood[e] ?? 0.55;
      final score =
          0.5 +
          d * 3.0 +
          (m - 0.55) * 0.9 +
          (villageMorale - 0.5) * 0.35 +
          traditionSupport;
      final ok = score >= 0.5;
      if (ok) yes++;
      voices.add(
        CouncilVoice(e, ok, _voiceLine(e, ok, d, m, traditionSupport > 0)),
      );
    }
    final support = yes / Estate.values.length;
    return CouncilVote(support, support >= threshold, voices);
  }

  static String _voiceLine(
    Estate e,
    bool yes,
    double effect,
    double mood,
    bool rootedInTradition,
  ) {
    if (yes) {
      if (effect > 0.02) return '${e.label}: "Bunu biz de isterdik."';
      if (rootedInTradition) {
        return '${e.label}: "Bu zaten tuttuğumuz yol."';
      }
      if (mood >= 0.6) return '${e.label}: "Senin sözün, biz arkasındayız."';
      return '${e.label}: "İtirazımız yok."';
    }
    if (effect < -0.02) return '${e.label}: "Bu ferman bizi vurur."';
    if (mood < 0.4) return '${e.label}: "Bize sorulan son şey neydi?"';
    return '${e.label}: "Acelesi ne? Biz ikna olmadık."';
  }

  /// Bekleyen bir dilekçeyi köy kendisi çözerse HANGİ seçeneği seçer.
  ///
  /// Meclis kendi derdinden seçer: küskün zümreyi memnun eden seçenek öne
  /// çıkar (mood ne kadar düşükse o zümreye yapılan iyilik o kadar değerli),
  /// köy morali ve ambarın hâli tartıya girer. Oyuncunun tercihi burada YOK —
  /// zaten mesele bu: hür rejimde köy sensiz de karar verir.
  static int pickCouncilOption(
    List<PetitionOption> options, {
    required Map<Estate, double> mood,
    required double villageMorale,
  }) {
    var best = 0;
    var bestScore = -1e9;
    for (var i = 0; i < options.length; i++) {
      final o = options[i];
      var s = 0.0;
      for (final (e, d) in o.estateMood) {
        final m = mood[e] ?? 0.55;
        // Küskün zümreye yapılan iyilik daha çok oy getirir; memnun zümreyi
        // gücendirmek ucuzdur.
        s += d * (d > 0 ? (1.3 - m) : (0.7 + m)) * 10;
      }
      s += o.moraleAmount * 6;
      // Ambara/keseye dokunan seçenekler: köy tok değilse yiyecek ağır basar.
      final hungry = villageMorale < 0.5 ? 1.6 : 1.0;
      s += o.foodDelta * 0.02 * hungry;
      s += (o.woodDelta + o.stoneDelta + o.ironDelta) * 0.008;
      s += o.goldDelta * 0.010;
      if (s > bestScore) {
        bestScore = s;
        best = i;
      }
    }
    return best;
  }

  // ── YEMİN ──────────────────────────────────────────────────────────────────

  /// Köy kendini ilan edebilir mi — köklü bir kimliği olmalı ve daha önce
  /// yemin etmemiş olmalı.
  static bool oathAvailable(CompassPosition p, {required bool alreadySworn}) {
    if (alreadySworn) return false;
    final id = LawCompass.identify(p);
    return id.regime != VillageRegime.moderate &&
        p.intensity >= kOathConviction;
  }

  /// Yeminin köy hafızasına yazdığı bayrak — rejime özel fermanların dünya
  /// kapısı bunu okur (bkz. law_book gate'leri).
  static String oathFlag(VillageRegime r) => 'oath.${r.name}';

  // ── DIŞ GÜÇ: İMPARATORLUK KARŞISINDA DURUŞ ──────────────────────────────────
  //
  // İç yönetişim (rejim) ile dış tehdit (vergici heyet) artık birbirini görür.
  // Köyün kendi hakkında ettiği karar, imparatorluk kapıya dayandığında da
  // geçerlidir: baskı rejimi tek elden ve dimdik cevap verir; hür rejimde
  // heyetin talebi MECLİSE düşer — köyün sözü olmadan vergiye "hayır" denmez.

  /// Köyün rejiminden gelen dış-güç duruşu — pazarlık masasını şekillendirir.
  static ImperialPosture imperialPostureOf(
    VillageRegime r, {
    bool oath = false,
    required bool committed,
  }) {
    final base = switch (r) {
      // 👑 Mühürlü El — disiplinli, militan, "korkulan kapıdan hırsız girmez".
      // Heyet dimdik bir köyle konuştuğunu bilir: direniş eli güçlü, ama boyun
      // eğerse de makbul bir tâbi olur (itibar payı büyük).
      VillageRegime.sealedHand => const ImperialPosture(
        resistBonus: 0.20,
        haggleEase: -0.05,
        attentionMul: 1.12,
        note:
            'Mühürlü El: köy tek yumruk. Direnişte elin güçlü; boyun '
            'eğersen makbul bir tâbi olursun.',
      ),
      // ⚖ Demir Sofra — ortak disiplin: herkes aynı safta, ama zorla eşitlik
      // tezgâhı soğutmuş olabilir. Yükü hep birlikte kaldırır.
      VillageRegime.ironTable => const ImperialPosture(
        resistBonus: 0.12,
        haggleEase: 0.05,
        attentionMul: 0.88,
        note: 'Demir Sofra: yük ortak, saf tek. Herkes aynı anda diş sıkar.',
      ),
      // 🤝 Ortak Ocak — bütün köy eşiğe dizilir, ama karar meclisindir.
      VillageRegime.commune => const ImperialPosture(
        resistBonus: 0.10,
        haggleEase: 0.08,
        attentionMul: 0.85,
        note: 'Ortak Ocak: bütün köy eşikte. Ama vergiye cevabı meclis verir.',
      ),
      // 🏪 Açık Pazar — kese dolu, kol zayıf: kavgada değil pazarlıkta usta.
      // Görünür servet heyetin iştahını kabartır.
      VillageRegime.market => const ImperialPosture(
        resistBonus: -0.05,
        haggleEase: 0.16,
        attentionMul: 1.25,
        note:
            'Açık Pazar: kavgada değil pazarlıkta güçlü — ama dolu kese '
            'heyetin gözünü de üstüne çeker.',
      ),
      VillageRegime.moderate => const ImperialPosture(
        resistBonus: 0,
        haggleEase: 0,
        attentionMul: 1.0,
        note: '',
      ),
    };
    if (!oath || r == VillageRegime.moderate) return base;
    // Yemin duruşu keskinleştirir: militan köy daha da dik, tüccar köy daha da
    // kurnaz — ve görünürlük de artar (ilan edilmiş kimlik dikkat çeker).
    return ImperialPosture(
      resistBonus: base.resistBonus * 1.5,
      haggleEase: base.haggleEase * 1.3,
      attentionMul: base.attentionMul * 1.05,
      note: base.note,
    );
  }

  /// Hür ve KÖKLÜ rejimde imparatorluğun talebi meclise düşer: köy kendi
  /// duruşunu belirler. Meclis ASLA "reddet"i (bilinçli kıyım) önermez —
  /// pay/haggle/resist arasından köyün çıkarına olanı seçer. Oyuncu bunun
  /// dışına çıkarsa (ör. meclis öderken reddederse) meşruiyet bedeli öder.
  static ImperialVerdict councilImperialVerdict({
    required double affordability, // eldeki / talep (>=1 rahat karşılar)
    required bool conscript,
    required double resistChance,
    required Map<Estate, double> mood,
    required double villageMorale,
  }) {
    final avg = mood.values.isEmpty
        ? 0.55
        : mood.values.reduce((a, b) => a + b) / mood.values.length;
    final proud = avg >= 0.6 && villageMorale >= 0.55;
    final angry = avg < 0.4;

    // Bir evlat istendiğinde meclis kolay teslim etmez: gücü varsa direnmek,
    // yoksa fidye/uzlaşma yolunu işaret eder.
    if (conscript) {
      if (resistChance >= 0.4 && !angry) return ImperialVerdict.resist;
      return ImperialVerdict.comply; // fidye ya da (çaresizse) teslim
    }
    // Güçlü + gururlu ya da zaten ödeyemeyecek durumda → köy direnmek ister.
    if (resistChance >= 0.42 && (proud || affordability < 0.6)) {
      return ImperialVerdict.resist;
    }
    // Rahatça karşılanıyor ve köy küskün değilse → öde, iş büyümesin.
    if (affordability >= 1.0 && !angry) return ImperialVerdict.comply;
    // Aradaki gri bölge: pazarlıkla en azını ver.
    return ImperialVerdict.haggle;
  }

  /// Meclisin duruşunun tek cümlelik okunuşu (modal başlığı).
  static String verdictLine(ImperialVerdict v, {required bool conscript}) =>
      switch (v) {
        ImperialVerdict.comply =>
          conscript
              ? 'Meclis bir evladı fidyeyle kurtarmaktan yana.'
              : 'Meclis ödemekten yana — iş büyümesin diyor.',
        ImperialVerdict.haggle =>
          'Meclis pazarlıktan yana — verilecekse en azı verilsin.',
        ImperialVerdict.resist =>
          'Meclis direnmekten yana — köy bu talebi kaldıramaz diyor.',
      };

  /// Yemin metni — ritüelde okunan ferman. Köyün ağzından, buyuruldu diliyle.
  static (String, String) oathText(RegimeIdentity id) => switch (id.regime) {
    VillageRegime.commune => (
      'KÖYÜN YEMİNİ · ORTAK OCAK',
      '"Buyuruldu ki: bu köyde sofra ortaktır, söz meydanındır. '
          'Kimse öne geçmeye, kimse geride kalmaya. Elimiz birdir."',
    ),
    VillageRegime.market => (
      'KÖYÜN YEMİNİ · AÇIK PAZAR',
      '"Buyuruldu ki: bu köyün kapısı yola, yolu kervana açıktır. '
          'Herkes kendi kısmetinin sahibidir; alan da veren de serbesttir."',
    ),
    VillageRegime.ironTable => (
      'KÖYÜN YEMİNİ · DEMİR SOFRA',
      '"Buyuruldu ki: bu köyde pay eşittir ve payı ayıran eldir. '
          'Eşitliğe itiraz, sofraya itirazdır."',
    ),
    VillageRegime.sealedHand => (
      'KÖYÜN YEMİNİ · MÜHÜRLÜ EL',
      '"Buyuruldu ki: bu köyün tek sözü, tek mührü, tek eli vardır. '
          'Söz sorulmaz, söz verilir."',
    ),
    VillageRegime.moderate => ('', ''),
  };
}
