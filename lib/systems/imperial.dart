// İmparatorluk (dış tehdit) — vergici askerî heyetin talebi. Köy zenginleştikçe
// dikkat çeker (koşullu ritim). Pazarlık/anlaşma sağlanmazsa şiddet yaşanır;
// anlaşmak her zaman daha avantajlı. İmparatorlukla ilişki (_imperialFavor)
// pazarlık şansını ve talebin sertliğini belirler.

import '../characters/villager_type.dart';
import '../cutscene/cutscene.dart';
import '../text/voice.dart';
import 'combat_motion.dart';

enum ImperialDemandKind { goldTax, foodLevy, woodLevy, conscript }

/// Köyün eşikte uyguladığı savunma doktrini. Direniş artık tek bir zar değil:
/// oyuncu hangi bedeli göze aldığını seçer, dünya koreografisi de buna göre
/// isimlendirilir.
enum ImperialDefensePlan { holdLine, barricade, counterCharge }

extension ImperialDefensePlanText on ImperialDefensePlan {
  String get title => switch (this) {
    ImperialDefensePlan.holdLine => 'Kalkan hattı',
    ImperialDefensePlan.barricade => 'Dar geçit',
    ImperialDefensePlan.counterCharge => 'Karşı hücum',
  };

  String get detail => switch (this) {
    ImperialDefensePlan.holdLine =>
      'Muhafızlar önde tutar. Dengeli; silah varsa bir tanesi yıpranır.',
    ImperialDefensePlan.barricade =>
      '8 keresteyle yolu daralt. Kazanma şansı artar, can kaybı azalır.',
    ImperialDefensePlan.counterCharge =>
      'Milis ilk darbeyi vurur. En güçlü ihtimal, fakat hat kırılırsa bedeli ağır.',
  };
}

class ImperialPlanPreview {
  final ImperialDefensePlan plan;
  final double chance;
  final int woodCost;
  final int weaponCost;
  final int casualtyDelta;
  final bool available;

  const ImperialPlanPreview({
    required this.plan,
    required this.chance,
    required this.woodCost,
    required this.weaponCost,
    required this.casualtyDelta,
    required this.available,
  });
}

ImperialPlanPreview imperialPlanPreview({
  required ImperialDefensePlan plan,
  required ImperialDefensePreview defense,
  required int wood,
}) {
  final (
    chanceDelta,
    woodCost,
    weaponCost,
    casualtyDelta,
    available,
  ) = switch (plan) {
    ImperialDefensePlan.holdLine => (
      0.02,
      0,
      defense.weapons > 0 ? 1 : 0,
      0,
      true,
    ),
    ImperialDefensePlan.barricade => (0.13, 8, 0, -1, wood >= 8),
    ImperialDefensePlan.counterCharge => (
      0.19,
      0,
      defense.weapons > 0 ? 1 : 0,
      1,
      defense.guards + defense.tools + defense.weapons >= 3,
    ),
  };
  return ImperialPlanPreview(
    plan: plan,
    chance: (defense.chance + chanceDelta).clamp(0.0, 0.95),
    woodCost: woodCost,
    weaponCost: weaponCost,
    casualtyDelta: casualtyDelta,
    available: available,
  );
}

/// Eşik muharebesinin okunur ritmi. Hem dünya animasyonu hem HUD aynı saf
/// fonksiyonu kullanır; ekrandaki başlıkla askerlerin pozu ayrışmaz.
enum ImperialBattleBeat {
  mustering,
  firstImpact,
  counterstrike,
  finalPush,
  result,
}

ImperialBattleBeat imperialBattleBeat(double remaining) {
  if (remaining > 7.0) return ImperialBattleBeat.mustering;
  if (remaining > 5.4) return ImperialBattleBeat.firstImpact;
  if (remaining > 3.7) return ImperialBattleBeat.counterstrike;
  if (remaining > 1.8) return ImperialBattleBeat.finalPush;
  return ImperialBattleBeat.result;
}

/// Tek bir eşik düellosunun o karedeki fiziksel hareketi. Muharebenin sonucu
/// yönetim hesabında belirlenir; bu saf fonksiyon sonucun dünyada nasıl
/// oynanacağını belirler. [lane] gecikmesi bütün hattın aynı karede mekanik
/// biçimde dürtmesini engeller.
class ImperialCombatMotion {
  final double attackerAdvance;
  final double defenderAdvance;
  final bool attackerStriking;
  final bool defenderStriking;
  final bool attackerHit;
  final bool defenderHit;

  const ImperialCombatMotion({
    required this.attackerAdvance,
    required this.defenderAdvance,
    required this.attackerStriking,
    required this.defenderStriking,
    required this.attackerHit,
    required this.defenderHit,
  });
}

ImperialCombatMotion imperialCombatMotion({
  required double remaining,
  required int lane,
  required bool villageWon,
}) {
  final beat = imperialBattleBeat(remaining);
  final delay = (lane % 4) * 0.075;
  var attacker = 0.0;
  var defender = 0.0;
  var attackerStriking = false;
  var defenderStriking = false;
  var attackerHit = false;
  var defenderHit = false;

  switch (beat) {
    case ImperialBattleBeat.mustering:
      break;
    case ImperialBattleBeat.firstImpact:
      final progress = ((7.0 - remaining) / 1.6).clamp(0.0, 1.0).toDouble();
      final lunge = combatLunge(progress, delay);
      attacker = lunge * 1.65;
      attackerStriking = lunge > 0.42;
      defenderHit = lunge > 0.72;
      defender = defenderHit ? 0.22 * combatSmooth((lunge - 0.72) / 0.28) : 0;
    case ImperialBattleBeat.counterstrike:
      final progress = ((5.4 - remaining) / 1.7).clamp(0.0, 1.0).toDouble();
      final lunge = combatLunge(progress, delay);
      attacker = 0.40 - lunge * 0.32;
      defender = -lunge * 1.05;
      defenderStriking = lunge > 0.40;
      attackerHit = lunge > 0.70;
    case ImperialBattleBeat.finalPush:
      final progress = ((3.7 - remaining) / 1.9).clamp(0.0, 1.0).toDouble();
      final drive = combatSmooth((progress - delay).clamp(0.0, 1.0));
      if (villageWon) {
        attacker = 0.18 - drive * 0.78;
        defender = -0.30 - drive * 0.72;
        defenderStriking = drive > 0.18 && drive < 0.92;
        attackerHit = drive > 0.38 && drive < 0.94;
      } else {
        attacker = 0.45 + drive * 1.45;
        defender = 0.15 + drive * 0.88;
        attackerStriking = drive > 0.18 && drive < 0.92;
        defenderHit = drive > 0.38 && drive < 0.94;
      }
    case ImperialBattleBeat.result:
      if (villageWon) {
        attacker = -0.62;
        defender = -0.95;
        attackerHit = true;
      } else {
        attacker = 1.90;
        defender = 1.03;
        defenderHit = true;
      }
  }

  return ImperialCombatMotion(
    attackerAdvance: attacker,
    defenderAdvance: defender,
    attackerStriking: attackerStriking,
    defenderStriking: defenderStriking,
    attackerHit: attackerHit,
    defenderHit: defenderHit,
  );
}

/// Oyuncunun çatışmayı yönetmediği savunma önizlemesi. Panel bunu gösterir;
/// aynı [chance] değeri karar anında otomatik çözümde kullanılır.
class ImperialDefensePreview {
  final int guards;
  final int weapons;
  final int tools;
  final double chance;
  final String note;

  const ImperialDefensePreview({
    required this.guards,
    required this.weapons,
    required this.tools,
    required this.chance,
    required this.note,
  });
}

ImperialDefensePreview imperialDefensePreview({
  required int guards,
  required int population,
  required int weapons,
  required int iron,
  required int wood,
  required int stone,
  required double favor,
  double regimeBonus = 0,
}) {
  // Silah yoksa balta, tırpan, kazma gibi günlük araçlar savunmaya katılır.
  final tools = (iron ~/ 2 + wood ~/ 3 + stone ~/ 5).clamp(0, population);
  final weaponPower = weapons * 0.10;
  final toolPower = tools * 0.035;
  final base =
      guards * 0.18 +
      (population - 10).clamp(0, 20) * 0.012 +
      weaponPower +
      toolPower +
      (favor - 0.5) * 0.08 +
      regimeBonus;
  final chance = (0.10 + base).clamp(0.0, 0.92);
  final note = weapons > 0
      ? 'Silahlı muhafızlar önde; araç gereçler yedek güç.'
      : tools > 0
      ? 'Silah yok. Balta, tırpan ve kazmalarla karşılık verilecek.'
      : 'Silah ve araç gereç yok; savunma yalnızca kalabalığa dayanıyor.';
  return ImperialDefensePreview(
    guards: guards,
    weapons: weapons,
    tools: tools,
    chance: chance,
    note: note,
  );
}

/// Fiziksel asker heyetinin ziyaret evresi (bkz. scene_imperial `_tickImperial`).
///   - [idle]        : heyet yok; sayaç sıradaki ziyareti bekler.
///   - [approaching] : harita kenarından köy eşiğine formasyonla yürüyorlar
///                     (sim AKAR; oyuncu yaklaşan kolonu görür). Varınca pazarlık.
///   - [parley]      : eşikte dizilip beklerler; talep modalı/sinematiği açık
///                     (sim DURUR). Oyuncu karar verince ayrılışa geçer.
///   - [clashing]    : direniş KAZANILDI → eşikte kısa bir karşılaşma. Köy
///                     hatta dizilirken (bkz. scene_vignette `_vgThreshold`)
///                     heyet önce bekler, bir hamle yapar, sonra geri döner:
///                     evre sırf o hamle için değil, HATTIN KURULMASINA zaman
///                     tanımak için uzun tutulur.
///   - [raiding]     : reddedildi/direniş ezildi → askerler köy MERKEZİNE dalar;
///                     varışta "darbe" (kurbanlar çöker + sarsıntı + kızıl tint),
///                     kısa bekleyiş, sonra ayrılışa geçer. Şiddetin görünür anı.
///   - [leaving]     : geldikleri köşeye geri yürürler; varınca despawn → idle.
enum ImperialVisitPhase {
  idle,
  approaching,
  parley,
  clashing,
  raiding,
  leaving,
}

/// Direniş kazanıldığında sahnelenen "eşik" vinyetinin kimliği. Sahne
/// tarafında [_vgThreshold] kurar, prova telemetrisi (`kProbeVignetteId`) bunu
/// yazar — testin sahneyi tanıdığı tek isim burasıdır.
const String kThresholdVignetteId = 'imperial.threshold';

class ImperialDemand {
  final ImperialDemandKind kind;

  /// goldTax/foodLevy/woodLevy → miktar; conscript → 1 (bir genç).
  final int amount;
  const ImperialDemand(this.kind, this.amount);

  bool get isConscript => kind == ImperialDemandKind.conscript;

  String get icon => switch (kind) {
    ImperialDemandKind.goldTax => '★',
    ImperialDemandKind.foodLevy => '🌾',
    ImperialDemandKind.woodLevy => '🪵',
    ImperialDemandKind.conscript => '🧑',
  };

  /// Talebin tam karşılığının okunur özeti — defterdeki satır.
  String get label => switch (kind) {
    ImperialDemandKind.goldTax => '$amount altın öşür',
    ImperialDemandKind.foodLevy => '$amount kile tahıl',
    ImperialDemandKind.woodLevy => '$amount kütük kereste',
    ImperialDemandKind.conscript => 'bir genç (devşirme)',
  };

  /// Rakamın köye gerçek faturası. Komutan sayıyı okur; köy bunu öder. Talep
  /// metinlerinde sayının yanına bu cümle konur ki "%s kütük" soyut kalmasın.
  String get bite => switch (kind) {
    ImperialDemandKind.goldTax =>
      'Kese dibine kadar boşalır. Kışa girerken avucunuzda bakır bile kalmaz.',
    ImperialDemandKind.foodLevy =>
      'Ambarın tabanı görünür. Harmandan ne arttıysa arabalara yüklenir.',
    ImperialDemandKind.woodLevy =>
      'Ahırın çatı kirişleri sökülür, istif yol kenarına dizilir.',
    ImperialDemandKind.conscript =>
      'Bir ocaktan bir evlat eksilir. Anası kapıda bekler, çocuk dönmez.',
  };
}

// ImperialSnapshot hiç örneklenmiyordu (ölü kod) → kaldırıldı; EstateSnapshot
// ile aynı hikâye. Madalyon istenirse alanları imparatorluk state'inden okur.

/// ÖŞÜR RAKAMI — vergicinin defterden okuduğu sayı.
///
/// Sahnede üç satırdı ve orada test edilemiyordu; oysa bu bir DENGE kararı ve
/// denge kararları ölçülebilir bir yerde durmalı.
///
/// İki taban vardır, büyüğü geçerlidir:
///   • NÜFUS tabanı — fakir köyü korur. Kese boşsa talep insaflı kalır.
///   • KESE payı — zengin köyü yakalar. Ölçüm gösterdi ki altın nüfustan çok
///     daha hızlı birikiyor (17 canlık köyde ~27 altın/gün) ve yalnız nüfusa
///     bakan bir vergi istif yapan köyün yanından geçip gidiyordu: kese
///     doluyor, hiçbir karar zorlaşmıyordu.
///
/// [severity] itibardan gelen sertlik (1.0–1.8), [appetite] yılın iştahı
/// (1.0–2.0), [treasuryShare] yılın kese payı (0.20–0.45).
int imperialGoldDemand({
  required int population,
  required int treasury,
  required double severity,
  required double appetite,
  required double treasuryShare,
}) {
  final byPop = population * 1.6 * severity * appetite;
  final byPurse = (treasury < 0 ? 0 : treasury) * treasuryShare * severity;
  final take = byPop > byPurse ? byPop : byPurse;
  return take.round().clamp(6, 9999);
}

/// İmparatorluk geliş sinematiğini TALEBE + İTİBARA göre kurar. Süvariler
/// ufuktan gelir; komutanın sözü talebin türünü, tonu da ilişkiyi (düşman/
/// tarafsız/dostane) yansıtır. Devşirmede ek bir tehdit çekimi. Mevcut guard
/// sprite'ları asker olarak kullanılır (yeni resim gerekmez).
///
/// SAF fonksiyon — sahne state'i tutmaz ki animasyon odası da AYNI sahneyi
/// oynatabilsin. Odanın kendi kopyasını tutması, sahnede yapılan düzeltmelerin
/// odaya yansımaması demek (bu tuzağa capture bobininde bir kez düşüldü).
/// [seed] metin varyantlarını sabitler (aynı gün aynı cümle). [village] köyün
/// ADI — komutan onu defterden okur; imparatorluk için burası bir yurt değil,
/// kayıtlı bir yer adıdır. Boş bırakılırsa cümleler jenerik "bu köy"e düşer
/// (animasyon odası/capture köy adı olmadan da bu sahneyi oynatabilsin).
Cutscene imperialArrivalCutscene(
  ImperialDemand d, {
  required double favor,
  required int seed,
  String village = '',
}) {
  final f = favor;
  final named =
      village.trim().isNotEmpty && village.trim().toLowerCase() != 'köy';
  final vName = village.trim();
  // İlişki tonuna göre giriş anlatımı.
  final arrival = Voice.pick(
    f < 0.3
        ? const [
            'Ufukta kara bir toz. Bu sefer selam vermeden geliyorlar.',
            'Yol boyunca kimse tarlada kalmadı. Herkes toza baktı, herkes anladı.',
          ]
        : f >= 0.7
        ? const [
            'Tanıdık sancak. Aynı komutan, aynı defter, yine kapıda.',
            'Heyet ağır ağır geldi. Kimse koşmadı, kimse kaçmadı; bu iş artık bir usul.',
          ]
        : const [
            'Toynak sesi tepeyi aştı. Köpekler sustu.',
            'Toz bulutu yola oturdu. Ateş başındakiler ayağa kalktı.',
          ],
    seed,
  );
  // Komutanın talebe özel buyruğu — defterden okunan satır + faturası.
  final order = switch (d.kind) {
    ImperialDemandKind.goldTax => '${d.amount} altın. Bugünün rakamı bu.',
    ImperialDemandKind.foodLevy =>
      '${d.amount} kile tahıl. Ambarınızı ben saymam, siz doldurursunuz.',
    ImperialDemandKind.woodLevy =>
      '${d.amount} kütük. Kalenin duvarı bir yerden yükselecek.',
    ImperialDemandKind.conscript =>
      named
          ? '$vName bir genç verecek. Adını siz koyun, yoksa ben seçerim.'
          : 'Bu köyden bir genç. Adını siz verin, yoksa ben seçerim.',
  };
  // İtibara göre komutanın tonu: yüksek itibarda neredeyse nazik, düşükte
  // sıkılmış ve ölümcül. Sesini hiç yükseltmez.
  final threat = Voice.pick(
    f < 0.3
        ? const [
            'Geçen kış iki köy sildim. İkisi de son ana kadar konuşacağını sandı.',
            'Bu satırın altını çizmek zorunda kalırsam, sabah burada duman durur.',
            'Yorgunum. Yorgun adamla pazarlık edilmez.',
          ]
        : f >= 0.7
        ? const [
            'Sizinle hep kolay oldu. Bozmayalım, ikimiz de rahat edelim.',
            'Defterde adınız temiz sayfada duruyor. Orada kalması işime gelir.',
          ]
        : const [
            'Borç ödenir. Nasıl ödendiğini defter yazmaz.',
            'İki yol var. İkisi de aynı rakamda biter, biri daha ucuza.',
          ],
    seed + 1,
  );

  return Cutscene([
    CutsceneShot(
      bg: CutsceneBg.valleyDusk,
      setPiece: CutsceneSetPiece.imperial,
      panFrom: 0.04,
      panTo: 0.0,
      zoomFrom: 1.02,
      zoomTo: 1.08,
      actors: const [
        CutsceneActor(
          type: VillagerType.guard,
          seed: 31,
          fromX: 1.25,
          toX: 0.66,
          y: 0.84,
          scale: 1.2,
          flip: true,
          walk: true,
          entranceDelay: 0.16,
        ),
        CutsceneActor(
          type: VillagerType.guard,
          seed: 44,
          fromX: 1.5,
          toX: 0.50,
          y: 0.80,
          scale: 1.1,
          flip: true,
          walk: true,
          entranceDelay: 0.32,
        ),
        CutsceneActor(
          type: VillagerType.guard,
          seed: 52,
          fromX: 1.75,
          toX: 0.36,
          y: 0.86,
          scale: 1.25,
          flip: true,
          walk: true,
        ),
      ],
      lines: [
        CutsceneLine(arrival),
        const CutsceneLine(
          'Süvariler eşikte durdu. Kimse inmedi, kimse acele etmedi.',
        ),
      ],
    ),
    CutsceneShot(
      bg: CutsceneBg.valleyDusk,
      setPiece: CutsceneSetPiece.imperial,
      // Komutan tek başına, dört replik boyunca: gerçek yakın plan —
      // bel altı kasıtlı olarak kadraj dışında, yüz büyür.
      framing: CutsceneFraming.close,
      zoomFrom: 1.1,
      zoomTo: 1.0,
      actors: const [
        CutsceneActor(
          type: VillagerType.guard,
          name: 'Komutan',
          seed: 31,
          fromX: 0.5,
          y: 0.80,
          scale: 1.6,
          flip: true,
        ),
      ],
      lines: [
        // Komutanın AÇILIŞ satırı köyün adını okur: defterde bir satırsınız
        // ve o satırın bir adı var. Adı ilk kez bir yabancının ağzından
        // duymak, adı ekranda bir etiket olmaktan çıkarır.
        CutsceneLine(
          Voice.pick(
            named
                ? [
                    '$vName. Defterde kayıtlı. Kayıtlı olan öder.',
                    'Sayfayı açıyorum: $vName. Bakalım bu yıl ne yazmışlar size.',
                    '$vName adını deftere ben yazmadım. Ben yalnız karşısındaki '
                        'haneyi doldurmaya geldim.',
                  ]
                : const [
                    'Bu köy defterde kayıtlı. Kayıtlı olan öder.',
                    'Adınızı deftere ben yazmadım. Ben yalnız karşısındaki haneyi doldurmaya geldim.',
                    'Sayfayı açıyorum. Bakalım bu yıl ne yazmışlar size.',
                  ],
            seed + 2,
          ),
          speaker: 'Komutan',
        ),
        CutsceneLine(order, speaker: 'Komutan'),
        CutsceneLine(d.bite, speaker: 'Komutan'),
        CutsceneLine(threat, speaker: 'Komutan'),
      ],
    ),
    // Devşirme — ek bir ürkütücü çekim: köy gencinin alınması ayrı bir an.
    if (d.isConscript)
      const CutsceneShot(
        bg: CutsceneBg.valleyDusk,
        setPiece: CutsceneSetPiece.imperial,
        zoomFrom: 1.0,
        zoomTo: 1.06,
        actors: [
          CutsceneActor(
            type: VillagerType.guard,
            seed: 52,
            fromX: 0.30,
            y: 0.82,
            scale: 1.3,
            flip: true,
          ),
          // Küçük ölçekli köylü → genç hissi (ayrı "genç" sprite'ı yok).
          CutsceneActor(
            type: VillagerType.farmer,
            seed: 9,
            fromX: 0.62,
            y: 0.84,
            scale: 0.85,
            pose: CutsceneActorPose.mourn,
          ),
        ],
        lines: [
          CutsceneLine(
            'Komutan gençlerin durduğu sıraya baktı. Analar bir adım öne çıktı, o hiç oynamadı.',
          ),
        ],
      ),
  ]);
}
