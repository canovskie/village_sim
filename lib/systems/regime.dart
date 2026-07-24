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
          ? base.inkDryMul * 0.85 // baskı: daha da hızlı
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
            powerNote: 'Kimse itiraz etmiyor, kimse de arkanda değil. '
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
            powerNote: 'Ferman meclis oyuna sunulur, bekleyen dilekçeyi köy '
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
            powerNote: 'Köy kendi işini görür; sen karışmazsan da döner. '
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
            powerNote: 'Eşitliği dağıtan el senin: mühür çabuk basılır, itiraz '
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
            powerNote: 'Mühür anında basılır, dilekçe susar. Kimse itiraz '
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
    final calm =
        rule.unrestRelief * ((morale - 0.45) / 0.55).clamp(0.0, 1.0);
    return (rule.unrestPerDay - calm) * days;
  }

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
                'sen geçerken kesiyorlar.'
          ),
        RegimeCrisis.deadlock => (
            'MECLİS KİLİTLENDİ',
            'Herkes konuştu, kimse ikna olmadı. Divan üç gündür aynı '
                'cümlenin etrafında dönüyor.'
          ),
        RegimeCrisis.idleness => (
            'TEZGÂH SOĞUDU',
            'Pay nasılsa eşit; kimse fazladan bir kova taşımıyor. '
                'İş görünüyor ama iş yürümüyor.'
          ),
        RegimeCrisis.inequality => (
            'MAKAS AÇILDI',
            'Bir hane iki ev birden yaptırdı, öbürü sazlıkta yatıyor. '
                'Aynı köyde iki ayrı kış yaşanıyor.'
          ),
        RegimeCrisis.none => ('', ''),
      };

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
          0.5 + d * 3.0 + (m - 0.55) * 0.9 + (villageMorale - 0.5) * 0.35;
      final ok = score >= 0.5;
      if (ok) yes++;
      voices.add(CouncilVoice(e, ok, _voiceLine(e, ok, d, m)));
    }
    final support = yes / Estate.values.length;
    return CouncilVote(support, support >= threshold, voices);
  }

  static String _voiceLine(Estate e, bool yes, double effect, double mood) {
    if (yes) {
      if (effect > 0.02) return '${e.label}: "Bunu biz de isterdik."';
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

  /// Yemin metni — ritüelde okunan ferman. Köyün ağzından, buyuruldu diliyle.
  static (String, String) oathText(RegimeIdentity id) => switch (id.regime) {
        VillageRegime.commune => (
            'KÖYÜN YEMİNİ · ORTAK OCAK',
            '"Buyuruldu ki: bu köyde sofra ortaktır, söz meydanındır. '
                'Kimse öne geçmeye, kimse geride kalmaya. Elimiz birdir."'
          ),
        VillageRegime.market => (
            'KÖYÜN YEMİNİ · AÇIK PAZAR',
            '"Buyuruldu ki: bu köyün kapısı yola, yolu kervana açıktır. '
                'Herkes kendi kısmetinin sahibidir; alan da veren de serbesttir."'
          ),
        VillageRegime.ironTable => (
            'KÖYÜN YEMİNİ · DEMİR SOFRA',
            '"Buyuruldu ki: bu köyde pay eşittir ve payı ayıran eldir. '
                'Eşitliğe itiraz, sofraya itirazdır."'
          ),
        VillageRegime.sealedHand => (
            'KÖYÜN YEMİNİ · MÜHÜRLÜ EL',
            '"Buyuruldu ki: bu köyün tek sözü, tek mührü, tek eli vardır. '
                'Söz sorulmaz, söz verilir."'
          ),
        VillageRegime.moderate => ('', ''),
      };
}
