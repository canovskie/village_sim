import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../characters/life_stage.dart';
import '../../characters/npc_visual.dart';
import '../../characters/villager_type.dart';
import '../../entities/villager_entity.dart';
import '../../rendering/character_renderer.dart';
import '../../systems/events/chronicle.dart';
import '../../systems/governance/house_stance.dart';
import '../../systems/governance/house_system.dart';
import '../../systems/governance/law_book.dart';
import '../../systems/governance/law_compass.dart';
import '../../systems/governance/petition_system.dart';
import '../../systems/governance/regime.dart';
import '../../systems/run/quest_book.dart';
import '../../systems/run/reckoning.dart';
import '../../text/voice.dart';
import '../core/app_ui.dart';
import '../core/mobile_ui.dart';
import '../core/semantic_icon.dart';
import '../events/petition_scene_card.dart';
import '../hud/guide_spotlight.dart';
import '../hud/objective_panel.dart';
import '../hud/villager_roster_view.dart';
import 'chronicle_filter.dart';
import 'law_book_panel.dart';
import 'ledger_board.dart';

part 'ledger_agenda.dart';
part 'ledger_council.dart';
part 'ledger_hero.dart';
part 'ledger_house_cards.dart';
part 'ledger_mobile.dart';
part 'ledger_shell.dart';
part 'ledger_tabs.dart';

/// KÖY DEFTERİ — köy içi işlerin TEK kapısı.
///
/// Eskiden köyün kendi hakkındaki her bilgisi ayrı bir yüzeyde dağınıktı:
/// Divan sol üstte bir mühür, Nüfus Defteri HUD'ın sağındaki geliştirici
/// düğmeleri arasında bir ikon, Hikâye güncesi sol alttaki ⚙ kümesinde bir
/// chip, Görevler sol kenarda ayrı bir pano, Kanunname ise Divan'ın içinde bir
/// sekme. Oyuncu "köyüme dair X'e nereden bakıyordum?" diye ekranı taramak
/// zorundaydı. Defter bunların hepsini tek çerçevede, sol raftaki beş bölümde
/// toplar — kapı bir tane, içeride bölüm değiştirirsin:
///
///   • ⚖ DİVAN     — gündem (bekleyen dilekçe + mayalanan baskılar) + gerilimler
///   • 📜 KANUNNAME — politik pusula + hüküm defteri + kararların kalıcı izi
///   • 👥 NÜFUS     — köylüler + haneler (servet/moral/barınma dökümü)
///   • 🎯 TÜZÜK     — kimlik kademesi merdiveni + açık/biten görevler
///   • 📖 KRONİK    — köyün büyük anlarının güncesi + başarımlar
///
/// Salt-okunur bir gösterge: yeni simülasyon yürütmez, mevcut state'i okur.
/// Tek istisna aksiyonlar: bekleyen dilekçeyi açmak ve bir fermanı meclise
/// koymak (mühür ritüeli) — ikisi de defteri kapatıp kendi yüzeyini açar.

/// Defterin bölümleri — sol raf sırası bu enum sırasıdır.
enum LedgerSection {
  divan('⚖', 'DİVAN', 'gündem ve gerilimler', 'DİVAN'),
  kanun('📜', 'KANUNNAME', 'pusula ve hükümler', 'KANUN'),
  nufus('👥', 'NÜFUS', 'köylüler ve haneler', 'NÜFUS'),
  tuzuk('🎯', 'TÜZÜK', 'kademe ve görevler', 'TÜZÜK'),
  kronik('📖', 'KRONİK', 'köyün hikâyesi', 'KRONİK');

  final String icon;
  final String label;

  /// Raf öğesinin altındaki tek satırlık künye — bölümün ne olduğunu söyler.
  final String blurb;

  /// Telefonun sol rayı için KISA etiket. Ray 116dp; "KANUNNAME" 11px yazı
  /// tabanıyla oraya sığmıyor, üç noktaya düşüyordu (bkz. ui/ledger/ledger_board.dart).
  final String short;

  const LedgerSection(this.icon, this.label, this.blurb, this.short);
}

/// Defterin her bölümü kendi mürekkep tonunu taşır. Renk yalnız süs değil:
/// oyuncu başlığı okumadan bile hangi sayfaya geçtiğini çevresel tondan anlar.
Color ledgerSectionTone(LedgerSection section) => switch (section) {
  LedgerSection.divan => AppUi.accent,
  LedgerSection.kanun => AppUi.gold,
  LedgerSection.nufus => AppUi.sage,
  LedgerSection.tuzuk => AppUi.rust,
  LedgerSection.kronik => const Color(0xFFB079D4),
};

/// Gündeme düşmüş ya da mayalanan tek bir mesele.
class DivanMatter {
  final String icon;
  final String title;
  final String sub;

  /// 0..1 baskı/yakınlık — mayalanma fitili ne kadar dolu (1 = az kaldı).
  final double pressure;
  final PetitionTone tone;

  /// Şu an HUD'da bekleyen gerçek dilekçe mi (gündemin tepesine oturur + yanıt
  /// butonu görünür). false = henüz mayalanan, karar istemeyen baskı.
  final bool pending;

  /// Bekleyen dilekçe için kalan mühlet oranı (1→0); pending değilse yok sayılır.
  final double graceProgress;
  final bool urgent;

  const DivanMatter({
    required this.icon,
    required this.title,
    required this.sub,
    required this.pressure,
    this.tone = PetitionTone.neutral,
    this.pending = false,
    this.graceProgress = 1.0,
    this.urgent = false,
  });
}

/// Köyün kalıcı hâlini özetleyen tek rozet (yürürlükteki yasa ya da hafıza izi).
class DivanFact {
  final String icon;
  final String label;
  final Color color;
  const DivanFact(this.icon, this.label, this.color);
}

/// Divan masasındaki bir sandalye — bir hanenin GERÇEK reisi. Sahne, her soyun
/// canlı üyelerinden reisi seçer (en yaşlı yetişkin erkek; yoksa en yaşlı
/// yetişkin) ve o köylünün görsel kimliğini buraya koyar. Rastgele DEĞİL:
/// oyuncu masada tanıdığı yüzleri görür. [CouncilTable] bunları çizer.
class DivanSeat {
  final NpcVisual visual; // köylünün gerçek yüzü/kıyafeti
  final VillagerType type;
  final LifeStage stage;
  final String name; // reisin adı (masada altına yazılır)
  final String surname;
  final double mood; // hanenin hâli 0..1 → duruş/ifade
  final bool ascendant; // köyün gölgesine kaydığı hane mi (altın halka)
  final int members; // canlı üye sayısı (eylem kartı başlığı)
  final double swayShare; // köy içi nüfuz payı 0..1

  /// Hanenin köye karşı DURUŞU — masada da görünür (bkz. house_stance).
  final HouseStance stance;

  /// Reis masaya oturmuyor mu — kopmuş hane sandalyesini boş bırakır.
  /// Sandalye listeden ÇIKARILMAZ: oyuncu boykot eden haneye hâlâ dokunabilmeli
  /// (barıştırmak da bir eylemdir). Figür yalnızca "orada değil" gibi çizilir.
  bool get absent => stance.withholds && stance == HouseStance.defiant;

  const DivanSeat({
    required this.visual,
    required this.type,
    required this.stage,
    required this.name,
    required this.surname,
    required this.mood,
    required this.ascendant,
    this.members = 0,
    this.swayShare = 0,
    this.stance = HouseStance.content,
  });
}

/// Meclis masasında bir reise dokununca açılan kartın TEK eylem satırı.
/// Sahne üretir (kural/bedel `systems/governance/house_action.dart`'ta); UI yalnız gösterir.
/// Kapalı eylem GİZLENMEZ — gerekçesiyle sönük durur ki oyuncu neyin neden
/// mümkün olmadığını (ferman mı, rejim mi, kese mi) görsün.
class HouseActionEntry {
  final String icon;
  final String label;

  /// Ne yapacağı — kapalıysa NEDEN kapalı olduğu.
  final String detail;

  /// Kısa sonuç rozetleri ("+18 altın", "hâl −0.30", "korku +").
  final List<String> effects;

  final bool enabled;
  final VoidCallback? onTap;

  const HouseActionEntry({
    required this.icon,
    required this.label,
    required this.detail,
    this.effects = const [],
    required this.enabled,
    this.onTap,
  });
}

class VillageLedger extends StatelessWidget {
  /// Metin havuzlarının tohumu (sahne GÜN sayısını verir). Pano gün boyunca
  /// aynı kelimelerle konuşur; ertesi gün başka kelimelerle. Rebuild'de
  /// zıplamaması için rastgele DEĞİL, tohumlu seçim (bkz. [Voice.pick]).
  final int seed;

  /// Köyün kaydığı kimlik adı.
  final String identity;

  /// KÖYÜN ADI — defterin künyesinde durur ("PINARBAŞI DEFTERİ"). Oyuncunun
  /// kuruluşta verdiği ad oyun içinde hiçbir yüzeyde görünmüyordu; defter köy
  /// içi işlerin tek kapısı olduğu için adın evi burasıdır. Boş ya da
  /// varsayılan ("Köy") ise jenerik künyeye düşer.
  final String village;

  /// Kimlik mekanik bonusu özeti (varsa).
  final String? identityBonus;

  // Köy durum şeridi.
  final double morale;
  final int population;
  final int food;
  final int gold;

  final List<ReckoningLedgerRow> karne;
  final int karneYear;
  final String karneVerdict;
  final String karneAdviceLine;

  /// Gündem — bekleyenler önce, sonra mayalananlar (baskıya göre sıralı gelir).
  final List<DivanMatter> agenda;

  /// Köyün haneleri (salience sıralı) — her an görünür gerilim.
  final List<HouseSnapshot> houses;

  /// Divan masasındaki reisler — her hanenin GERÇEK reisi (bkz. [DivanSeat]).
  /// Boşsa masa çizilmez (henüz hane yok).
  final List<DivanSeat> seats;

  /// Bir haneye uygulanabilecek eylemler — masadaki reise dokununca açılan
  /// kart bunu çağırır. null ise masa salt gösterimdir (dokunulamaz).
  final List<HouseActionEntry> Function(String surname)? houseActionsFor;

  /// ÖNİZLEME/CAPTURE: hane kartı açık başlasın (bkz. [CouncilTable]).
  final int openHouseCard;

  /// TOPYEKÛN EL KOYMA kartı — masanın altında, ayrı ve tehlikeli. Kapalıyken
  /// de gösterilir (gerekçesiyle) ki oyuncu bu yolun var olduğunu bilsin.
  /// null → hiç gösterilmez.
  final HouseActionEntry? massSeizure;

  /// Yürürlükteki yasalar.
  final List<DivanFact> laws;

  /// Kararların kalıcı izleri (hafıza bayrakları → okunur rozet).
  final List<DivanFact> marks;

  /// Köyün bildiği zanaatlar — "köyün eli" (kademeli gelişmenin görünür yüzü).
  final List<DivanFact> crafts;

  /// Kararların mirası — büyük kararların köy ruhunda biriken KALICI moral izi
  /// (±). 0 ise gösterilmez. Hükmünün sönmeyen ağırlığı.
  final double legacy;

  /// Bekleyen dilekçeyi (varsa) tam modal olarak aç.
  final VoidCallback? onOpenPetition;

  // ── KANUNNAME (yasa defteri) ────────────────────────────────────────────────
  // Eski "Karar Defteri" bir toggle listesiydi; eski "Meclis'i Topla" bir
  // düğmeydi. İkisi de öldü. Yerine tek bir yüzey: defter. Fermana dokun →
  // meclis toplanır (LawSealRitual) → mühür basılı tutularak basılır.
  final Set<String> sealed;

  /// Mühür günleri (ferman id → oyun günü); defterde hükmün yanında yazar.
  final Map<String, int> sealedOn;

  final LawContext lawContext;
  final String? lawSpotlightId;
  final double inkDrySec;
  final double inkDryTotalSec;
  final void Function(LawDef law)? onOpenLaw;

  // ── REJİM — kimliğin bedeli (bkz. systems/governance/regime.dart) ──────────────────────
  /// Yürürlükteki yetki kuralı + köyün huzursuzluğu; defterin başındaki kadran
  /// bunları okur. null = rejim bağlanmamış yüzey (preview/harness).
  final RegimeRule? regimeRule;
  final double unrest;
  final VillageRegime? swornRegime;

  /// Çürüme (Faz 3) + imanın mekanik karşılığı.
  final double regimeRot;
  final FaithEffect? faithEffect;

  /// KÖYÜN YEMİNİ edilebiliyorsa çağrılır (null = kart düğmeyi çizmez).
  final VoidCallback? onSwearOath;

  /// Mühürlü bir hükmü bedelle feshet (null = fesih kapalı).
  final void Function(LawDef law)? onRepealLaw;

  // ── NÜFUS ───────────────────────────────────────────────────────────────────
  /// Köylü defter satırları (barınma bilgisi sahnede türetilir).
  final List<VillagerStatRow> rosterRows;

  /// Bir köylü satırına dokununca detay paneli açılır (defter kapanır).
  final void Function(VillagerEntity)? onSelectVillager;

  // ── TÜZÜK ───────────────────────────────────────────────────────────────────
  /// Açık (tamamlanmamış) görevler — ilki `active`.
  final List<QuestState> quests;

  /// Tamamlanmış görev id'leri — merdivende ✓ olarak görünür.
  final Set<String> completedQuests;

  /// Köyün şu anki kimlik kademesi (QuestBook.tiers indeksi).
  final int charterTier;

  /// Yürürlükteki politika (berat) sayısı — kademe eşiği bunu ister.
  final int enactedPolicies;

  // ── KRONİK ──────────────────────────────────────────────────────────────────
  /// Köyün büyük anlarının güncesi (eskiden yeniye eklenir; ters gösterilir).
  final List<ChronicleEntry> chronicle;

  /// Kazanılmış başarım sayısı.
  final int milestoneCount;

  // ── Raf ─────────────────────────────────────────────────────────────────────
  /// Raf öğesi rozetleri — 0/absent ise rozet çizilmez (ör. gündem sayısı,
  /// mühürlenmeyi bekleyen hüküm sayısı, açık görev sayısı).
  final Map<LedgerSection, int> badges;

  /// Açılışta seçili bölüm.
  final LedgerSection initialSection;

  final VoidCallback onClose;

  const VillageLedger({
    super.key,
    this.seed = 0,
    required this.identity,
    this.village = '',
    this.identityBonus,
    required this.morale,
    required this.population,
    required this.food,
    required this.gold,
    this.karne = const [],
    this.karneYear = 0,
    this.karneVerdict = '',
    this.karneAdviceLine = '',
    required this.agenda,
    required this.houses,
    this.seats = const [],
    this.houseActionsFor,
    this.openHouseCard = -1,
    this.massSeizure,
    required this.laws,
    required this.marks,
    this.crafts = const [],
    this.legacy = 0,
    required this.onOpenPetition,
    this.sealed = const {},
    this.sealedOn = const {},
    this.lawContext = const LawContext(),
    this.lawSpotlightId,
    this.inkDrySec = 0,
    this.inkDryTotalSec = 0,
    this.onOpenLaw,
    this.regimeRule,
    this.unrest = 0,
    this.swornRegime,
    this.onSwearOath,
    this.onRepealLaw,
    this.regimeRot = 0,
    this.faithEffect,
    this.rosterRows = const [],
    this.onSelectVillager,
    this.quests = const [],
    this.completedQuests = const {},
    this.charterTier = 0,
    this.enactedPolicies = 0,
    this.chronicle = const [],
    this.milestoneCount = 0,
    this.badges = const {},
    this.initialSection = LedgerSection.divan,
    required this.onClose,
  });

  static Color toneColor(PetitionTone t) => switch (t) {
    PetitionTone.warm => AppUi.sage,
    PetitionTone.solemn => AppUi.info,
    PetitionTone.ominous => AppUi.rust,
    PetitionTone.neutral => AppUi.accent,
  };

  /// Moralin sürekli renge çevrimi (estate_banner moodTone ile aynı dil).
  static Color moodTone(double m) {
    const ember = Color(
      0xFFE8934A,
    ); // mood sıcaklık kodu, UI accent'ten bağımsız
    const gold = Color(0xFFD9C088);
    if (m < 0.32) {
      return Color.lerp(AppUi.rust, ember, (m / 0.32).clamp(0.0, 1.0))!;
    }
    if (m < 0.50) {
      return Color.lerp(ember, gold, ((m - 0.32) / 0.18).clamp(0.0, 1.0))!;
    }
    if (m < 0.70) {
      return Color.lerp(gold, AppUi.sage, ((m - 0.50) / 0.20).clamp(0.0, 1.0))!;
    }
    return AppUi.sage;
  }

  /// Hero sahnesinin tonu — köyün moraline göre (mutlu=warm, orta=neutral,
  /// düşük=ominous). Toplanma sahnesi köyün ruh hâliyle renklenir.
  PetitionTone get _heroTone => morale >= 0.6
      ? PetitionTone.warm
      : morale >= 0.4
      ? PetitionTone.neutral
      : PetitionTone.ominous;

  /// Köyün hâli — kademe başına küçük bir havuz, güne göre bir varyant. Sıfat
  /// yığmak yerine köyün o gün NEYE benzediğini söyler (ses, koku, gövde).
  String get _moraleWord {
    final List<String> pool;
    if (morale >= 0.72) {
      pool = const [
        'akşamları meydanda türkü söyleniyor',
        'çocuklar geç saate kadar dışarıda',
        'ocaklar tütüyor, kimsenin acelesi yok',
      ];
    } else if (morale >= 0.55) {
      pool = const [
        'iş yolunda, sofra kurulu',
        'kimse şikâyet etmiyor, kimse de coşmuyor',
        'gün dolu geçiyor, gece sessiz',
      ];
    } else if (morale >= 0.40) {
      pool = const [
        'meydanda fısıltı var, sebebi belli değil',
        'gülüyorlar ama gözleri gülmüyor',
        'işler dönüyor, gönüller yarım',
      ];
    } else if (morale >= 0.28) {
      pool = const [
        'kapılar erken kapanıyor',
        'sofrada laf az, bakışlar kaçamak',
        'birbirlerine değil, sana bakıyorlar',
      ];
    } else {
      pool = const [
        'yolda selam kesildi',
        'kimse tarlaya gönülsüz gitmiyor, hiç gitmiyor',
        'bir kıvılcım yeter, herkes bunu biliyor',
      ];
    }
    return Voice.pick(pool, seed);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final compact = useCompactGameUi(context);
    // SABİT çerçeve (eskiden içeriğe göre büyüyen dar bir scroll sütunuydu):
    // defter beş bölüm taşıyor, bölüm değiştirince panel boyu zıplamamalı.
    //
    // MOBİL: telefon YATAY'da 393dp yüksek. %93 almak 27dp'yi hiçe harcamak
    // demekti — defterin dikey bütçesi zaten kritik (hero + raf + şerit üst
    // üste binince listeye tek satır kalıyordu). Kenar ızgarasının gutter'ı
    // dışında her pikseli al.
    final mobileWindow = compact ? MobileUi.windowSize(context) : null;
    final w = compact
        ? mobileWindow!.width
        : math.min(size.width * 0.95, 1040.0);
    final h = compact
        ? mobileWindow!.height
        : math.min(size.height * 0.93, 760.0);
    return Stack(
      children: [
        // Hafif karartma — defter bir gösterge, oyun durmaz; boşluğa dokun = kapat.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onClose,
            child: const ColoredBox(color: AppUi.scrim),
          ),
        ),
        Center(
          child: GestureDetector(
            onTap: () {}, // panel içi dokunuş kapatmasın
            // Açılış: scale+fade. NOT: AppReveal KULLANMA — opacity 0'da takılıp
            // paneli görünmez bırakabiliyor. TweenAnimationBuilder güvenli.
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              builder: (_, t, child) => Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, (1 - t) * 10),
                  child: Transform.scale(
                    scale: 0.97 + t * 0.03,
                    alignment: Alignment.center,
                    child: child,
                  ),
                ),
              ),
              child: SizedBox(
                width: w,
                height: h,
                child: _LedgerFrame(
                  // Politika bağlanmamışsa Kanunname bölümü yok.
                  child: compact
                      // TELEFON: hero bandı YOK. Künye rayın tepesine taşındı;
                      // gezinme dikeye döndü (bkz. ui/ledger/ledger_board.dart). Böylece
                      // 360dp'lik pencerede kroma yalnız kimlik satırı kadar
                      // yükseklik yer — kalan her piksel içeriğe gider.
                      ? _LedgerBoardShell(
                          initial: initialSection,
                          badges: badges,
                          hidden: {if (onOpenLaw == null) LedgerSection.kanun},
                          identityHeader: mobileIdentity(),
                          boardFor: mobileBoardFor,
                          onClose: onClose,
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _hero(context),
                            Expanded(
                              child: _LedgerShell(
                                initial: initialSection,
                                badges: badges,
                                hidden: {
                                  if (onOpenLaw == null) LedgerSection.kanun,
                                },
                                strip: _villageStrip(),
                                railFooter: _villageRailPulse(),
                                bodyFor: _bodyFor,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Bölüm gövdesi. Liste taşıyan bölümler (NÜFUS) kendi scroll'unu yürütür ve
  /// alanı doldurur; diğerleri tek bir dikey scroll içinde akar.
  Widget _bodyFor(LedgerSection s) => switch (s) {
    LedgerSection.divan => _scrollBody(_meclisTab()),
    LedgerSection.kanun => _scrollBody(_kararTab()),
    LedgerSection.nufus => VillagerRosterView(
      rows: rosterRows,
      houses: houses,
      onSelect: onSelectVillager,
    ),
    LedgerSection.tuzuk => _scrollBody(_tuzukTab()),
    LedgerSection.kronik => _scrollBody(_kronikTab()),
  };

  Widget _scrollBody(Widget child) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [child],
    ),
  );
}

// ── Meclis masası ─────────────────────────────────────────────────────────────

/// Hane renk paleti — [_houseColor] ile aynı, masa katmanında da erişilebilsin.
const List<Color> _kCouncilPalette = [
  Color(0xFF8FB255),
  Color(0xFFE0954A),
  Color(0xFF9E86C9),
  Color(0xFFD8AE56),
  Color(0xFF6FA9B8),
  Color(0xFFC57B6B),
  Color(0xFF8DA0C0),
  Color(0xFFB0A24E),
];
Color _councilHouseColor(String surname) {
  var h = 0;
  for (final c in surname.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return _kCouncilPalette[h % _kCouncilPalette.length];
}

/// Divan'ın başındaki YUVARLAK MASA — hanelerin GERÇEK reisleri karşıda oturmuş,
/// oyuncuya (sana) bakıyor. Aktörler [DivanSeat.visual] ile o köylünün gerçek
/// yüzünü/kıyafetini taşır (rastgele değil). Reisler masanın uzak yayına
/// yerleşir; masa yüzeyi bel altını örter → "masaya oturmuş" okunur. Kendi
/// ticker'ı var (nefes/ışık); panel yeniden çizilmese de canlı durur.
