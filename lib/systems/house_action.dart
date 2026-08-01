/// HANE EYLEMLERİ — oyuncunun hanelere KARŞI harekete geçtiği katman.
///
/// Yönetişim bugüne dek TEPKİSELDİ: köy dilekçe getirir, oyuncu hüküm verirdi.
/// Bu katman oyuncuya PROAKTİF ajans verir — mülk bağışlar, ceza keser, mala el
/// koyar, nikâh bağlar, sürgüne yollar, gizli iş çevirir. Güç fantezisi
/// "hakem"den "hükümdar"a kayar; bedeli meşruiyettir.
///
/// Tasarım kuralları:
///  1. **Bedelsiz eylem yok.** Kaynak kazandıran eylem (el koyma) en yüksek
///     siyasi bedeli öder; yoksa el koyma sonsuz kaynak musluğu olurdu.
///  2. **Köy izler.** Her eylem hedefi kadar DİĞER haneleri de etkiler: sert
///     hüküm korku yayar, kayırma kıskançlık doğurur.
///  3. **Tekrar pahalıdır.** Aynı haneye üst üste sertlik "hüküm" olmaktan
///     çıkıp "gasp" olur — bedel katlanır (bkz. [escalationMul]).
///  4. **Yetki kapılıdır.** Sert eylemler hem REJİM (politik pusula authority
///     ekseni) hem YASA (mühürlü ferman) ister. Kılıç yolu güç verir, meşruiyet
///     alır.
///
/// Bu dosya SAF: sahne state'i tutmaz, rastgelelik içermez → test edilebilir
/// (bkz. test/house_action_test.dart). Uygulama scene_house_actions.dart'ta.
library;

enum HouseActionKind {
  /// 🎁 Mülk bağışla — hane güçlenir, sana borçlanır. Diğerleri kıskanır.
  grant,

  /// ⚖ Ceza kes — hane hizaya gelir, nüfuzu kırılır. Kan dökülmez.
  punish,

  /// 🏚 Mala el koy — ambarı mühürle. Kaynak kazandırır, en pahalı siyasi bedel.
  seize,

  /// 💍 Nikâh bağla — hür rejimde ÖNERİ, baskı rejiminde ZORLA.
  betroth,

  /// 🚷 Sürgüne yolla — reisi (ya da bir üyeyi) köyden atar. En sert hüküm.
  exile,

  /// 🕯 Gizli iş çevir — hanenin nüfuzunu sessizce kırar. İfşa riski taşır.
  scheme,
}

extension HouseActionKindX on HouseActionKind {
  String get icon => switch (this) {
        HouseActionKind.grant => '🎁',
        HouseActionKind.punish => '⚖',
        HouseActionKind.seize => '🏚',
        HouseActionKind.betroth => '💍',
        HouseActionKind.exile => '🚷',
        HouseActionKind.scheme => '🕯',
      };

  String get label => switch (this) {
        HouseActionKind.grant => 'Mülk bağışla',
        HouseActionKind.punish => 'Ceza kes',
        HouseActionKind.seize => 'Mala el koy',
        HouseActionKind.betroth => 'Nikâh bağla',
        HouseActionKind.exile => 'Sürgüne yolla',
        HouseActionKind.scheme => 'Gizli iş çevir',
      };

  /// Sert eylem mi — tekrar bedeli ([escalationMul]) yalnız bunlarda birikir.
  bool get harsh => switch (this) {
        HouseActionKind.seize ||
        HouseActionKind.exile ||
        HouseActionKind.punish =>
          true,
        _ => false,
      };

  /// Gerektirdiği mühürlü ferman (null = yasa şartı yok).
  String? get requiredLaw => switch (this) {
        HouseActionKind.seize => 'nizam.registry',
        HouseActionKind.exile => 'nizam.exile',
        _ => null,
      };

  /// Gerektirdiği en düşük yetki (politik pusula authority ekseni, −1 hür …
  /// +1 baskı). Yumuşak eylemler her rejimde açıktır.
  double get requiredAuthority => switch (this) {
        HouseActionKind.seize => 0.15,
        HouseActionKind.exile => 0.30,
        _ => -1.0,
      };
}

/// Bir eylemin o an yapılabilir olup olmadığı + kapalıysa GEREKÇESİ.
/// Gerekçe UI'da gösterilir: oyuncu duvara çarptığında nedenini bilsin
/// ("meclis reddeder" ile "ferman yok" aynı şey değildir).
class HouseActionGate {
  final bool open;
  final String? reason;
  const HouseActionGate.open()
      : open = true,
        reason = null;
  const HouseActionGate.shut(String this.reason) : open = false;
}

/// Bir eylemin sonucu — UI bunu EYLEMDEN ÖNCE önizleme olarak gösterir,
/// sahne aynı değerlerle uygular. Tek doğruluk kaynağı.
class HouseActionOutcome {
  /// Kaynak deltaları (+ kazanç, − harcama).
  final int gold;
  final int food;

  /// Hedef hanenin hâli (mood) deltası.
  final double targetMood;

  /// Hedef hanenin nüfuzu (sway) deltası.
  final double targetSway;

  /// DİĞER hanelerin hâli — sert hüküm korku yayar, kayırma kıskandırır.
  final double otherMood;

  /// Köyün huzursuzluğu (+ kötü).
  final double unrest;

  /// Geçici köy morali etkisi ve süresi (gün).
  final double villageMorale;
  final double moraleDays;

  const HouseActionOutcome({
    this.gold = 0,
    this.food = 0,
    this.targetMood = 0,
    this.targetSway = 0,
    this.otherMood = 0,
    this.unrest = 0,
    this.villageMorale = 0,
    this.moraleDays = 3,
  });
}

/// Aynı haneye üst üste sertlik: 1. kez hüküm, 3. kez gasp. Bedel katlanır ki
/// oyuncu tek haneyi sağıp duramasın.
double escalationMul(int recentHarsh) => 1.0 + 0.6 * recentHarsh.clamp(0, 4);

/// Eylemin yapılabilirliği. [authority] politik pusula ekseni (−1 hür … +1
/// baskı), [sealedLaws] mühürlü ferman kimlikleri, [members] hanenin canlı üye
/// sayısı, [gold] köyün kesesi.
HouseActionGate gateFor(
  HouseActionKind kind, {
  required double authority,
  required Set<String> sealedLaws,
  required int members,
  required int gold,
  /// Bağışta kurulacak mülk kademesi (2..4). null = hane zaten konakta →
  /// bağışlanacak daha iyi mülk yok.
  int? grantTier,
}) {
  final law = kind.requiredLaw;
  if (law != null && !sealedLaws.contains(law)) {
    return HouseActionGate.shut(switch (kind) {
      HouseActionKind.seize => 'Hane defteri fermanı mühürlü değil — neyin '
          'kimde olduğu yazılı olmadan mala el konmaz.',
      HouseActionKind.exile => 'Sürgün fermanı mühürlü değil — köy henüz '
          'kimseyi yola vurmuyor.',
      _ => 'Bu iş için gereken ferman mühürlü değil.',
    });
  }
  if (authority < kind.requiredAuthority) {
    return HouseActionGate.shut(
        'Meclis buna razı olmaz. Bu yetki ancak sözün mutlaklaştığı bir '
        'köyde kullanılır.');
  }
  if (kind == HouseActionKind.grant) {
    if (grantTier == null) {
      return const HouseActionGate.shut(
          'Bu hane zaten konakta oturuyor — bağışlayacak daha iyi mülk yok.');
    }
    final cost = grantCost(members, grantTier);
    if (gold < cost) {
      return HouseActionGate.shut('Kese yetmiyor — bu bağış $cost altın ister.');
    }
  }
  if (kind == HouseActionKind.scheme && gold < _kSchemeCost) {
    return HouseActionGate.shut('Gizli iş de para ister — $_kSchemeCost altın.');
  }
  if (kind == HouseActionKind.exile && members <= 1) {
    return HouseActionGate.shut(
        'Hanede tek can kaldı. Onu da yola vurursan soy tükenir.');
  }
  if (kind == HouseActionKind.betroth && members <= 0) {
    return HouseActionGate.shut('Nikâh bağlanacak kimse yok.');
  }
  return const HouseActionGate.open();
}

/// Bağışın altın bedeli. Bağış artık GERÇEK bir mülktür (yeni ev kurulur), o
/// yüzden bedel kademeye göre ağırlaşır: ahşap ev başka, konak başka.
/// [tier] 2=ahşap ev, 3=taş ev, 4=konak.
int grantCost(int members, [int tier = 2]) =>
    switch (tier) {
      4 => 80,
      3 => 40,
      _ => 18,
    } +
    members * 2;

const int _kSchemeCost = 6;

/// Eylemin sonucu — bedel ve kazanç burada tek yerde hesaplanır.
///
/// [members] hane büyüklüğü (el koyma getirisi ve bağış bedeli buradan),
/// [recentHarsh] bu haneye yakın geçmişte kaç sert eylem yapıldığı,
/// [authoritarian] rejim baskıcı mı (nikâh zorlaması ve entrika ifşası değişir).
HouseActionOutcome outcomeOf(
  HouseActionKind kind, {
  required int members,
  required int recentHarsh,
  required bool authoritarian,
  int grantTier = 2,
}) {
  final esc = kind.harsh ? escalationMul(recentHarsh) : 1.0;
  final m = members.clamp(1, 20);

  return switch (kind) {
    // Kayırma: hane güçlenir ve sana borçlanır; ÖTEKİLER kıskanır. Bağış
    // hedefin NÜFUZUNU da büyütür — kayırdığın hane bir gün gölgen olabilir.
    HouseActionKind.grant => HouseActionOutcome(
        gold: -grantCost(m, grantTier),
        targetMood: 0.18,
        targetSway: 0.5,
        otherMood: -0.04,
        unrest: -0.02,
        villageMorale: 0.02,
        moraleDays: 3,
      ),

    // Ceza: hizaya getirir, nüfuzu kırar, kan dökmez. Köy hafif ürperir.
    HouseActionKind.punish => HouseActionOutcome(
        targetMood: -0.14 * esc,
        targetSway: -0.3 * esc,
        otherMood: -0.02,
        unrest: 0.03 * esc,
        villageMorale: -0.02,
        moraleDays: 2,
      ),

    // El koyma: TEK kaynak kazandıran eylem → en ağır siyasi bedel. Getiri
    // hane büyüklüğüyle artar (büyük hanenin ambarı doludur).
    HouseActionKind.seize => HouseActionOutcome(
        gold: 10 + m * 3,
        food: 6 + m * 2,
        targetMood: -0.30 * esc,
        targetSway: -0.8 * esc,
        otherMood: -0.06 * esc,
        unrest: 0.10 * esc,
        villageMorale: -0.05,
        moraleDays: 3,
      ),

    // Nikâh: hür rejimde ÖNERİ (hafif gücenme), baskıda ZORLAMA (ağır).
    HouseActionKind.betroth => authoritarian
        ? const HouseActionOutcome(
            targetMood: -0.12,
            otherMood: -0.03,
            unrest: 0.05,
            villageMorale: -0.02,
            moraleDays: 2,
          )
        : const HouseActionOutcome(
            targetMood: -0.05,
            otherMood: 0.0,
            unrest: 0.01,
          ),

    // Sürgün: en sert hüküm. Hane kanar, köy korkar.
    HouseActionKind.exile => HouseActionOutcome(
        targetMood: -0.35 * esc,
        targetSway: -1.0 * esc,
        otherMood: -0.08 * esc,
        unrest: 0.12 * esc,
        villageMorale: -0.06,
        moraleDays: 4,
      ),

    // Entrika: hâl DEĞİŞMEZ (kimse bilmiyor), yalnız nüfuz sessizce kırılır.
    // Bedeli ifşa riskidir (sahne tarafında yuvarlanır), burada yalnız kese.
    HouseActionKind.scheme => const HouseActionOutcome(
        gold: -_kSchemeCost,
        targetSway: -0.5,
      ),
  };
}

/// Entrikanın ifşa olma olasılığı. Hür rejimde köy konuşur, kulak çoktur →
/// risk yüksek; baskı rejiminde kimse sormaz. Nüfuzlu haneye dokunmak da
/// tehlikelidir (gözü üstünde çok kişi vardır).
double schemeExposureChance({
  required double authority,
  required double targetSwayShare,
}) {
  final free = ((1.0 - authority) / 2.0).clamp(0.0, 1.0); // 1 = tam hür
  return (0.12 + free * 0.28 + targetSwayShare * 0.20).clamp(0.05, 0.75);
}

// ── TOPYEKÛN EL KOYMA (kamulaştırma) ─────────────────────────────────────────
//
// Tek tek hanelerin malına el koymak bir hükümdür; TÜM mülke el koymak bir
// REJİM değişikliğidir. Bu yüzden ayrı kapıdan geçer ve bir kez yapılır.
//
// Neden iki eksen birden? Mülkiyeti tümden kaldırmak yalnızca sert olmayı
// değil, ORTAKÇI olmayı da gerektirir: "Mühürlü El" (baskı+mülkçü) mülkü
// kutsal sayar, kendi mantığıyla çelişir. Bu hamlenin evi "Demir Sofra"dır.

/// Kamulaştırma için gereken en düşük otorite (pusula authority ekseni).
const double kMassSeizureAuthority = 0.55;

/// Gereken en yüksek ekonomi değeri — eksi = ortakçı (mülkçü köy yapamaz).
const double kMassSeizureEconomy = -0.30;

/// Kamulaştırmanın köy hafızasına bıraktığı kalıcı iz.
const String kMassSeizureFlag = 'mulk.kamu';

/// Topyekûn el koyma yapılabilir mi. [economy] − ortakçı … + mülkçü.
HouseActionGate massSeizureGate({
  required double authority,
  required double economy,
  required Set<String> sealedLaws,
  required bool alreadyDone,
  required int houseCount,
}) {
  if (alreadyDone) {
    return const HouseActionGate.shut(
        'Mülk zaten köyün. Bir kez kaldırılan mülkiyet ikinci kez kaldırılmaz.');
  }
  if (!sealedLaws.contains('nizam.registry')) {
    return const HouseActionGate.shut(
        'Hane defteri fermanı mühürlü değil — neyin kimde olduğu yazılı '
        'olmadan topyekûn el konmaz.');
  }
  if (authority < kMassSeizureAuthority) {
    return const HouseActionGate.shut(
        'Sözün bunun için yeterince mutlak değil. Köy hâlâ senin dışında da '
        'karar verebiliyor.');
  }
  if (economy > kMassSeizureEconomy) {
    return const HouseActionGate.shut(
        'Bu köy mülkü kutsal sayıyor. Ortak sofraya inanmayan bir düzen, '
        'mülkiyeti kendi eliyle kaldırmaz.');
  }
  if (houseCount < 2) {
    return const HouseActionGate.shut(
        'Kamulaştıracak hane yok — ortada tek ocak var.');
  }
  return const HouseActionGate.open();
}

/// Kamulaştırmanın köye getirisi — el konan konut sayısıyla ölçeklenir.
({int gold, int food, int wood}) massSeizureYield(int homes) => (
      gold: 25 + homes * 12,
      food: 15 + homes * 8,
      wood: 10 + homes * 6,
    );
