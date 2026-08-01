import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../characters/life_stage.dart';
import '../characters/npc_visual.dart';
import '../characters/villager_type.dart';
import '../entities/villager_entity.dart';
import '../rendering/character_renderer.dart';
import '../systems/chronicle.dart';
import '../systems/house_system.dart';
import '../systems/petition_system.dart';
import '../systems/quest_book.dart';
import '../text/voice.dart';
import '../systems/law_book.dart';
import '../systems/law_compass.dart';
import '../systems/regime.dart';
import 'app_ui.dart';
import 'mobile_ui.dart';
import 'law_book_panel.dart';
import 'petition_scene_card.dart';
import 'villager_roster_view.dart';

part 'ledger_council.dart';
part 'ledger_house_cards.dart';

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
  divan('⚖', 'DİVAN', 'gündem ve gerilimler'),
  kanun('📜', 'KANUNNAME', 'pusula ve hükümler'),
  nufus('👥', 'NÜFUS', 'köylüler ve haneler'),
  tuzuk('🎯', 'TÜZÜK', 'kademe ve görevler'),
  kronik('📖', 'KRONİK', 'köyün hikâyesi');

  final String icon;
  final String label;

  /// Raf öğesinin altındaki tek satırlık künye — bölümün ne olduğunu söyler.
  final String blurb;

  const LedgerSection(this.icon, this.label, this.blurb);
}

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
  });
}

/// Meclis masasında bir reise dokununca açılan kartın TEK eylem satırı.
/// Sahne üretir (kural/bedel `systems/house_action.dart`'ta); UI yalnız gösterir.
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

  /// Kimlik mekanik bonusu özeti (varsa).
  final String? identityBonus;

  // Köy durum şeridi.
  final double morale;
  final int population;
  final int food;
  final int gold;

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
  final LawContext lawContext;
  final String? lawSpotlightId;
  final double inkDrySec;
  final double inkDryTotalSec;
  final void Function(LawDef law)? onOpenLaw;

  // ── REJİM — kimliğin bedeli (bkz. systems/regime.dart) ──────────────────────
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
    this.identityBonus,
    required this.morale,
    required this.population,
    required this.food,
    required this.gold,
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
    const ember = Color(0xFFE8934A); // mood sıcaklık kodu, UI accent'ten bağımsız
    const gold = Color(0xFFD9C088);
    if (m < 0.32) return Color.lerp(AppUi.rust, ember, (m / 0.32).clamp(0.0, 1.0))!;
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
    final w = compact
        ? size.width - 2 * MobileUi.gutter
        : math.min(size.width * 0.95, 1040.0);
    final h = compact
        ? size.height - 2 * MobileUi.gutter
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
                child: _GildedFrame(
                  accent: AppUi.accent,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _hero(context),
                      Expanded(
                        child: _LedgerShell(
                          initial: initialSection,
                          badges: badges,
                          // Politika bağlanmamışsa Kanunname bölümü yok.
                          hidden: {
                            if (onOpenLaw == null) LedgerSection.kanun,
                          },
                          strip: _villageStrip(),
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

  // ── Bölüm içerikleri ───────────────────────────────────────────────────────

  /// GÜNDEM sekmesi — köyün senden ne istediği + zümre gerilimleri.
  Widget _meclisTab() {
    return Builder(builder: (context) {
      // Meclis masası — hanelerin gerçek reisleri, yuvarlak masada karşıda.
      final council = <Widget>[
        if (seats.isNotEmpty) ...[
          const AppSectionLabel('MECLİS HALKASI'),
          const SizedBox(height: 6),
          CouncilTable(
              seats: seats,
              actionsFor: houseActionsFor,
              initiallySelected: openHouseCard),
          if (massSeizure != null) ...[
            const SizedBox(height: 10),
            _MassSeizureCard(entry: massSeizure!),
          ],
          const SizedBox(height: 16),
        ],
      ];
      final agenda = <Widget>[
        const AppSectionLabel('GÜNDEM'),
        _agendaSection(),
        const SizedBox(height: 16),
        const AppSectionLabel('GERİLİMLER'),
        _tensions(),
        if (identityBonus != null) ...[
          const SizedBox(height: 8),
          _identityBonusRow(),
        ],
      ];
      // TELEFON YATAY: defterin gövdesine ~300dp kalıyor; masa + künye ilk
      // ekranı doldurunca Divan açıldığında YANIT BEKLEYEN İŞ görünmüyordu.
      // Divan'ın işi gündemdir, halka atmosferdir — kısa ekranda sıra değişir.
      final compact = useCompactGameUi(context);
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: compact
            ? [...agenda, const SizedBox(height: 16), ...council]
            : [...council, ...agenda],
      );
    });
  }

  /// KANUNNAME sekmesi — yasa defteri + kararların köyde bıraktığı kalıcı iz.
  Widget _kararTab() {
    final hasState = marks.isNotEmpty || legacy.abs() > 0.005;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LawBookView(
          sealed: sealed,
          ctx: lawContext,
          spotlightId: lawSpotlightId,
          inkDrySec: inkDrySec,
          inkDryTotalSec: inkDryTotalSec,
          seed: seed,
          onOpenLaw: onOpenLaw!,
          rule: regimeRule,
          unrest: unrest,
          sworn: swornRegime,
          onSwearOath: onSwearOath,
          onRepeal: onRepealLaw,
          rot: regimeRot,
          faith: faithEffect,
        ),
        if (hasState) ...[
          const SizedBox(height: 16),
          const AppSectionLabel('KÖYÜN HÂLİ'),
          if (legacy.abs() > 0.005) ...[
            _legacyLine(),
            if (marks.isNotEmpty) const SizedBox(height: 8),
          ],
          if (marks.isNotEmpty) _factWrap(),
        ],
        if (crafts.isNotEmpty) ...[
          const SizedBox(height: 16),
          const AppSectionLabel('KÖYÜN ELİ — BİLİNEN ZANAATLAR'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final f in crafts) _factChip(f)],
          ),
        ],
      ],
    );
  }

  // ── TÜZÜK sekmesi — kimlik kademesi merdiveni + görevler ───────────────────

  /// Görev panosu eskiden sol kenarda küçük bir kutuydu ve yalnız AÇIK görevleri
  /// gösteriyordu: köyün nereye gittiği (kademe merdiveni) ve nereden geldiği
  /// (biten görevler) görünmüyordu. Defterde ikisi de var.
  Widget _tuzukTab() {
    final active = quests.where((q) => q.active).firstOrNull;
    final done = QuestBook.all
        .where((q) => completedQuests.contains(q.id))
        .toList(growable: false);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppSectionLabel('KÖYÜN KADEMESİ'),
        const SizedBox(height: 8),
        for (int i = 0; i < QuestBook.tiers.length; i++) ...[
          _tierRow(i, QuestBook.tiers[i], done.length),
          if (i != QuestBook.tiers.length - 1) const SizedBox(height: 6),
        ],
        const SizedBox(height: 18),
        const AppSectionLabel('AÇIK GÖREVLER'),
        const SizedBox(height: 8),
        if (quests.isEmpty)
          Text(
              'Bu kademede iş kalmadı — yeni bir berat çıkar, köy bir üst '
              'basamağa geçsin.',
              style: AppUi.body.copyWith(fontSize: 11.5, color: AppUi.sage))
        else
          for (final q in quests) _questRow(q),
        if (active != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
            decoration: BoxDecoration(
              color: AppUi.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppUi.radiusSm),
              border:
                  Border.all(color: AppUi.accent.withValues(alpha: 0.38)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('👉', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(active.quest.hint,
                      style: AppUi.body.copyWith(
                          fontSize: 11.5, color: AppUi.textHi, height: 1.45)),
                ),
              ],
            ),
          ),
        ],
        if (done.isNotEmpty) ...[
          const SizedBox(height: 18),
          AppSectionLabel('BİTENLER — ${done.length}/${QuestBook.all.length}'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final q in done)
                _factChip(DivanFact(q.icon, q.label, AppUi.sage)),
            ],
          ),
        ],
      ],
    );
  }

  Widget _tierRow(int i, CharterTier t, int doneCount) {
    final passed = i < charterTier;
    final current = i == charterTier;
    final c = current
        ? AppUi.gold
        : passed
            ? AppUi.sage
            : AppUi.textLo;
    // Kilitli kademede eşiğe ne kadar kaldığı yazılır — ilerleme somut olsun.
    final needPol = (t.minPolicies - enactedPolicies).clamp(0, 99);
    final needQ = (t.minQuests - doneCount).clamp(0, 99);
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
      decoration: BoxDecoration(
        color: current
            ? Color.alphaBlend(AppUi.gold.withValues(alpha: 0.10), AppUi.surface1)
            : AppUi.surface0,
        borderRadius: BorderRadius.circular(AppUi.radiusSm),
        border: Border.all(
            color: current ? AppUi.gold.withValues(alpha: 0.5) : AppUi.line,
            width: current ? 1.3 : 1),
      ),
      child: Row(
        children: [
          Opacity(
            opacity: passed || current ? 1 : 0.45,
            child: Text(t.icon, style: const TextStyle(fontSize: 15)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(t.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppUi.body.copyWith(
                        fontSize: 12.5,
                        color: current ? AppUi.textHi : AppUi.textMid,
                        fontWeight:
                            current ? FontWeight.w800 : FontWeight.w600)),
                if (!passed && !current && (needPol > 0 || needQ > 0)) ...[
                  const SizedBox(height: 2),
                  Text(
                      [
                        if (needPol > 0) '$needPol berat',
                        if (needQ > 0) '$needQ görev',
                      ].join(' · '),
                      style: AppUi.body
                          .copyWith(fontSize: 10, color: AppUi.textLo)),
                ],
              ],
            ),
          ),
          Text(
              passed
                  ? '✓'
                  : current
                      ? 'ŞİMDİ'
                      : 'kilitli',
              style: AppUi.label.copyWith(fontSize: 8.5, color: c)),
        ],
      ),
    );
  }

  Widget _questRow(QuestState s) {
    final on = s.active;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            child: Text(s.quest.icon, style: const TextStyle(fontSize: 12)),
          ),
          Expanded(
            child: Text(s.quest.label,
                style: on
                    ? AppUi.bodyHi.copyWith(fontSize: 12)
                    : AppUi.body.copyWith(fontSize: 12, color: AppUi.textLo)),
          ),
          if (on)
            Text('SIRADAKİ',
                style: AppUi.label
                    .copyWith(fontSize: 7.5, color: AppUi.accentSoft)),
        ],
      ),
    );
  }

  // ── KRONİK sekmesi — köyün büyük anları ────────────────────────────────────

  Widget _kronikTab() {
    if (chronicle.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(
            Voice.pick(const [
              'Defterin bu sayfası boş. Köy henüz anlatılacak bir şey yaşamadı.',
              'Henüz yazılacak bir şey yok — ilk büyük gün gelmedi.',
              'Kronik sayfası temiz. Bu da bir başlangıç.',
            ], seed),
            style: AppUi.body.copyWith(color: AppUi.textLo)),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionLabel(milestoneCount > 0
            ? 'BÜYÜK ANLAR — 🏆 $milestoneCount BAŞARIM'
            : 'BÜYÜK ANLAR'),
        const SizedBox(height: 6),
        for (final e in chronicle.reversed) _chronicleRow(e),
      ],
    );
  }

  Widget _chronicleRow(ChronicleEntry e) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(e.icon, style: const TextStyle(fontSize: 15)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (e.day > 0)
                  Text('${e.day}. Gün',
                      style: AppUi.label
                          .copyWith(color: AppUi.textLo, fontSize: 10)),
                Text(e.text,
                    style: e.milestone
                        ? AppUi.body.copyWith(
                            fontSize: 12.5,
                            height: 1.4,
                            fontWeight: FontWeight.w700,
                            color: AppUi.gold)
                        : AppUi.body.copyWith(fontSize: 12, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero — sinematik toplanma sahnesi + kimlik + kapat ─────────────────────

  /// MOBİL hero — TEK satır, 54dp.
  ///
  /// Telefon yatayda defterin bütün derdi dikey bütçe: 82dp'lik hero + 60dp'lik
  /// bölüm rafı + 55dp'lik köy şeridi üst üste binince 365dp'lik çerçevede
  /// içeriğe ~160dp kalıyordu — NÜFUS'u açan oyuncu tek bir köylü satırı bile
  /// göremiyordu. Sahne kartı zemin olarak KALIR (defterin kimliği o), ama
  /// künye · kimlik · nabız · kapat tek hatta iner; ikinci satır (köyün hâli
  /// cümlesi) ve mühür madalyonu masaüstüne özel kalır.
  Widget _compactHero() {
    const h = 54.0;
    return SizedBox(
      height: h,
      child: Stack(
        children: [
          Positioned.fill(
            child: PetitionSceneCard.custom(
              scene: PetitionScene.gathering,
              tone: _heroTone,
              height: h,
              drawBorder: false,
            ),
          ),
          const Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x73100E0B), Color(0xE6100E0B)],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(left: 12, right: 4),
              child: Row(
                children: [
                  _kicker('KÖY DEFTERİ'),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      identity,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppUi.title.copyWith(
                        fontSize: 15,
                        color: AppUi.gold,
                        shadows: const [
                          Shadow(color: Color(0xCC000000), blurRadius: 8)
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  GameIcon(GameIconData.heart, size: 14, color: _moraleTone),
                  const SizedBox(width: 5),
                  Text('${(morale * 100).round()}%',
                      style: AppUi.number
                          .copyWith(fontSize: 13, color: _moraleTone)),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: onClose,
                    behavior: HitTestBehavior.opaque,
                    child: const SizedBox(
                      width: MobileUi.tap,
                      height: MobileUi.tap,
                      child: Center(
                        child: GameIcon(GameIconData.close,
                            size: 17, color: AppUi.textMid),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hero(BuildContext context) {
    // Kısa (yatay telefon) ekranda 132dp, 393dp'lik yüksekliğin üçte biriydi —
    // asıl içerik ekran dışına taşıyordu. Sahne kartı kalıyor, sadece inceliyor.
    final short = useCompactGameUi(context);
    if (short) return _compactHero();
    const heroH = 132.0;
    return SizedBox(
      height: heroH,
      child: Stack(
        children: [
          // Köyün moraliyle renklenen toplanma (meclis) sahnesi.
          Positioned.fill(
            child: PetitionSceneCard.custom(
              scene: PetitionScene.gathering,
              tone: _heroTone,
              height: heroH,
              drawBorder: false,
            ),
          ),
          // Alt okunaklılık zemini.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 98,
            child: const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0xE6100E0B)],
                  ),
                ),
              ),
            ),
          ),
          // Üst künye + kapat.
          Positioned(
            left: 14,
            right: 12,
            top: 12,
            child: Row(
              children: [
                _kicker('KÖY DEFTERİ'),
                const Spacer(),
                GestureDetector(
                  onTap: onClose,
                  behavior: HitTestBehavior.opaque,
                  // Kapat düğmesinin dokunma alanı 25×25dp'ydi — paneli
                  // kapatan tek düğme için fazla küçük. Görsel daire aynı
                  // kalıyor, hit alanı 44'e büyüyor.
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: const Color(0xB3100E0B),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppUi.gold.withValues(alpha: 0.3)),
                        ),
                        child: const GameIcon(GameIconData.close,
                            size: 13, color: AppUi.textMid),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Alt: ⚖ madalyon + kimlik başlığı + köyün hâli.
          Positioned(
            left: 14,
            right: 14,
            bottom: 12,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _sealMedallion(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(identity,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppUi.title.copyWith(
                            fontSize: 19,
                            color: AppUi.gold,
                            shadows: const [
                              Shadow(color: Color(0xCC000000), blurRadius: 8)
                            ],
                          )),
                      const SizedBox(height: 2),
                      Text(_moraleWord,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppUi.body.copyWith(
                              fontSize: 11,
                              color: AppUi.textMid,
                              shadows: const [
                                Shadow(color: Color(0xCC000000), blurRadius: 6)
                              ])),
                    ],
                  ),
                ),
                // Emoji surat yerine köyün nabzı: aynı bilgi, oyunun ikon
                // dilinde ve okunur bir sayıyla.
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GameIcon(GameIconData.heart, size: 15, color: _moraleTone),
                    const SizedBox(width: 5),
                    Text('${(morale * 100).round()}%',
                        style: AppUi.number
                            .copyWith(fontSize: 14, color: _moraleTone)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kicker(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xB3100E0B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppUi.accent.withValues(alpha: 0.55)),
        ),
        child: Text(text,
            style: AppUi.label.copyWith(color: AppUi.accent, fontSize: 9)),
      );

  /// ⚖ mühür madalyonu — hero'nun alt köşesinde, gilded halka.
  Widget _sealMedallion() {
    return Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [
          Color.alphaBlend(AppUi.accent.withValues(alpha: 0.22), AppUi.surface0),
          AppUi.surface0,
        ]),
        border: Border.all(color: AppUi.gold.withValues(alpha: 0.6), width: 1.6),
        boxShadow: [
          BoxShadow(color: AppUi.accent.withValues(alpha: 0.4), blurRadius: 12),
          const BoxShadow(color: Color(0x99000000), blurRadius: 6),
        ],
      ),
      child: const Text('⚖', style: TextStyle(fontSize: 24)),
    );
  }

  // ── Köy durum şeridi (moral/nüfus/yiyecek/altın) ───────────────────────────

  Widget _villageStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppUi.surface0,
        borderRadius: BorderRadius.circular(AppUi.radiusSm),
        border: Border.all(color: AppUi.line, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Emoji DEĞİL, Phosphor: bu şerit oyunun geri kalanıyla aynı ikon
          // dilini konuşmalı. Emoji glyph'ler cihazdan cihaza değişiyor, kendi
          // rengini/ağırlığını dayatıyor ve tam da altındaki nüfus KPI şeridi
          // aynı veriyi düzgün ikonla gösterdiği için ekranda iki farklı görsel
          // dil yan yana duruyordu.
          _stripCell(GameIconData.heart, '${(morale * 100).round()}%', 'moral',
              _moraleTone),
          _stripDiv(),
          _stripCell(GameIconData.people, '$population', 'nüfus', AppUi.info),
          _stripDiv(),
          _stripCell(GameIconData.wheat, '$food', 'yiyecek', AppUi.sage),
          _stripDiv(),
          _stripCell(GameIconData.coin, '$gold', 'altın', AppUi.gold),
        ],
      ),
    );
  }

  Widget _stripDiv() => Container(width: 1, height: 24, color: AppUi.line);

  Color get _moraleTone => morale >= 0.6
      ? AppUi.sage
      : morale >= 0.4
          ? AppUi.accentSoft
          : AppUi.rust;

  Widget _stripCell(
      GameIconData icon, String value, String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GameIcon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(value, style: AppUi.number.copyWith(fontSize: 13)),
          ],
        ),
        const SizedBox(height: 2),
        Text(label.toUpperCase(),
            style: AppUi.label.copyWith(fontSize: 8.5, letterSpacing: 0.8)),
      ],
    );
  }

  // ── Gündem ──────────────────────────────────────────────────────────────────

  Widget _agendaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (agenda.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                const Text('🕊️', style: TextStyle(fontSize: 15)),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                      Voice.pick(const [
                        'Kapıya kimse gelmedi. Köy bugün kendi işine bakıyor.',
                        'Ne şikâyet var ne dilekçe. Bu da bir hâl.',
                        'Dilekçe kâğıdı masada, dokunulmadan duruyor.',
                      ], seed),
                      style: AppUi.body.copyWith(color: AppUi.textLo)),
                ),
              ],
            ),
          )
        else
          for (int i = 0; i < agenda.length; i++) ...[
            _matterRow(agenda[i]),
            if (i != agenda.length - 1) const SizedBox(height: 7),
          ],
      ],
    );
  }

  Widget _matterRow(DivanMatter m) {
    final c = toneColor(m.tone);
    final pending = m.pending;
    return GestureDetector(
      onTap: pending ? onOpenPetition : null,
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppUi.radiusSm),
        child: Stack(
          children: [
            Container(
        padding: const EdgeInsets.fromLTRB(14, 9, 11, 9),
        decoration: BoxDecoration(
          color: pending
              ? Color.alphaBlend(c.withValues(alpha: 0.10), AppUi.surface1)
              : AppUi.surface0,
          borderRadius: BorderRadius.circular(AppUi.radiusSm),
          // UNIFORM kenar ŞART: non-uniform renkli Border + borderRadius Flutter'da
          // paint assert'i atar ("borderRadius … uniform colors") → panel çizilmez.
          // Ton rengi bu yüzden ayrı bir sol şerit katmanı olarak çizilir (aşağıda).
          border: Border.all(color: AppUi.line),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(m.icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(m.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppUi.bodyHi.copyWith(
                                fontSize: 12.5,
                                color: pending ? AppUi.textHi : AppUi.textMid)),
                      ),
                      if (pending) ...[
                        const SizedBox(width: 7),
                        _pendingTag(m),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(m.sub,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppUi.body
                          .copyWith(fontSize: 10.5, color: AppUi.textLo)),
                  const SizedBox(height: 6),
                  // Mayalanma fitili / mühlet — ince bar (ton renginde).
                  _pressureBar(
                    pending ? (1.0 - m.graceProgress) : m.pressure,
                    pending && m.urgent ? AppUi.rust : c,
                  ),
                ],
              ),
            ),
            if (pending) ...[
              const SizedBox(width: 8),
              GameIcon(GameIconData.chevron, size: 13, color: c),
            ],
          ],
        ),
            ),
            // Sol ton şeridi — meselenin duygusal rengi (uniform-border kısıtı
            // yüzünden Border yerine ayrı katman; satırın boyuna uzar).
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 3,
                color: c.withValues(alpha: pending ? 0.95 : 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _pendingTag(DivanMatter m) {
    final urgent = m.urgent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: (urgent ? AppUi.rust : AppUi.accent).withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: (urgent ? AppUi.rust : AppUi.accent).withValues(alpha: 0.7)),
      ),
      child: Text(urgent ? 'AZ KALDI' : 'YANIT BEKLER',
          style: AppUi.label.copyWith(
              fontSize: 7.5,
              letterSpacing: 0.8,
              color: urgent ? AppUi.rust : AppUi.accentSoft)),
    );
  }

  Widget _pressureBar(double v, Color c) {
    return Container(
      height: 4,
      decoration: BoxDecoration(
        color: const Color(0x55000000),
        borderRadius: BorderRadius.circular(3),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: v.clamp(0.04, 1.0),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  c.withValues(alpha: 0.7),
                  Color.lerp(c, Colors.white, 0.25)!,
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Gerilimler (zümre nabzı) ────────────────────────────────────────────────

  Widget _tensions() {
    if (houses.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
            Voice.pick(const [
              'Ortada hane yok, isimler var. Soylar daha kök salmadı.',
              'Kimse kendi adını bir soyadın arkasına yazdırmadı henüz.',
              'Köy genç: ne hane var, ne husumet.',
            ], seed),
            style: AppUi.body.copyWith(fontSize: 11, color: AppUi.textLo)),
      );
    }
    // Salience sıralı gelir; en fazla 4 açık göster, gerisi özet (sadelik).
    final shown = houses.length > 4 ? 4 : houses.length;
    return Column(
      children: [
        for (int i = 0; i < shown; i++) ...[
          _houseRow(houses[i]),
          if (i != shown - 1) const SizedBox(height: 6),
        ],
        if (houses.length > shown) ...[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
                '…ve ${houses.length - shown} hane, seslerini çıkarmadan',
                style: AppUi.body.copyWith(
                    fontSize: 10,
                    color: AppUi.textLo,
                    fontStyle: FontStyle.italic)),
          ),
        ],
      ],
    );
  }

  static const List<Color> _kHousePalette = [
    Color(0xFF8FB255), Color(0xFFE0954A), Color(0xFF9E86C9), Color(0xFFD8AE56),
    Color(0xFF6FA9B8), Color(0xFFC57B6B), Color(0xFF8DA0C0), Color(0xFFB0A24E),
  ];

  static Color _houseColor(String surname) {
    var h = 0;
    for (final c in surname.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return _kHousePalette[h % _kHousePalette.length];
  }

  Widget _houseRow(HouseSnapshot s) {
    final tone = moodTone(s.mood);
    final idColor = _houseColor(s.surname);
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          margin: const EdgeInsets.only(left: 6, right: 7),
          decoration: BoxDecoration(color: idColor, shape: BoxShape.circle),
        ),
        SizedBox(
          width: 116,
          child: Row(
            children: [
              Flexible(
                child: Text(s.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppUi.body.copyWith(
                        fontSize: 11.5,
                        color: s.ascendant ? AppUi.gold : AppUi.textMid,
                        fontWeight:
                            s.ascendant ? FontWeight.w800 : FontWeight.w600)),
              ),
              if (s.ascendant)
                const Padding(
                  padding: EdgeInsets.only(left: 3),
                  child: Text('★',
                      style: TextStyle(color: AppUi.gold, fontSize: 9)),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 7,
            decoration: BoxDecoration(
              color: AppUi.surface0,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppUi.line, width: 0.8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: s.mood.clamp(0.0, 1.0)),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOut,
                  builder: (_, v, _) => FractionallySizedBox(
                    widthFactor: v,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          tone.withValues(alpha: 0.8),
                          Color.lerp(tone, Colors.white, 0.25)!,
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(s.tier.face, style: const TextStyle(fontSize: 12)),
        SizedBox(
          width: 34,
          child: Text('%${(s.swayShare * 100).round()}',
              textAlign: TextAlign.right,
              style: AppUi.number.copyWith(
                  fontSize: 10,
                  color: s.ascendant ? AppUi.gold : AppUi.textLo)),
        ),
      ],
    );
  }

  Widget _identityBonusRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0x14E9C552),
        borderRadius: BorderRadius.circular(AppUi.radiusSm),
        border: Border.all(color: AppUi.gold.withValues(alpha: 0.33)),
      ),
      child: Row(
        children: [
          const Text('★', style: TextStyle(color: AppUi.gold, fontSize: 12)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(identityBonus!,
                style: AppUi.body
                    .copyWith(fontSize: 11, color: AppUi.gold)),
          ),
        ],
      ),
    );
  }

  // ── Köyün hâli (yasalar + izler) ────────────────────────────────────────────

  /// Kararların mirası satırı — hükmünün köy ruhunda biriken kalıcı ağırlığı.
  Widget _legacyLine() {
    final pos = legacy >= 0;
    final c = pos ? AppUi.sage : AppUi.rust;
    final pct = '${pos ? '+' : '−'}${(legacy.abs() * 100).round()}%';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppUi.radiusSm),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Text('📜', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
                pos
                    ? 'Verdiğin hükümler köyün gönlünde sıcak bir iz bıraktı'
                    : 'Verdiğin hükümlerin gölgesi köyün üstünden kalkmıyor',
                style: AppUi.body.copyWith(fontSize: 11, color: AppUi.textMid)),
          ),
          Text(pct,
              style: AppUi.number.copyWith(fontSize: 12.5, color: c)),
        ],
      ),
    );
  }

  Widget _factWrap() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final f in laws) _factChip(f),
        for (final f in marks) _factChip(f),
      ],
    );
  }

  Widget _factChip(DivanFact f) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
      decoration: BoxDecoration(
        color: f.color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: f.color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(f.icon, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 5),
          Text(f.label,
              style: AppUi.body.copyWith(
                  fontSize: 10.5,
                  color: AppUi.textMid,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// İnce altın oyma çerçeveli koyu pano — dilekçe modalıyla AYNI dil (yönetişimin
/// iki yüzü aynı ağırlıkta görünsün). Hero illüstrasyonunu köşelere yaslar.
class _GildedFrame extends StatelessWidget {
  final Widget child;
  final Color accent;
  const _GildedFrame({required this.child, required this.accent});

  @override
  Widget build(BuildContext context) {
    const r = AppUi.radius;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppUi.surface2, AppUi.surface1],
        ),
        borderRadius: BorderRadius.circular(r),
        border: Border.all(color: AppUi.gold.withValues(alpha: 0.32), width: 1.2),
        boxShadow: [
          ...AppUi.softShadow,
          BoxShadow(color: accent.withValues(alpha: 0.16), blurRadius: 26),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: Stack(
          children: [
            child,
            // İçte ince altın hairline — "oyma" derinliği.
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  margin: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(r - 4),
                    border: Border.all(
                        color: AppUi.gold.withValues(alpha: 0.12), width: 1),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// DEFTER MÜHRÜ — köy içi işlerin TEK kapısı, hep ekranda. Eskiden bu mühür
/// yalnız Divan'ı açardı; nüfus HUD ikonunda, hikâye ⚙ kümesinde, görevler ayrı
/// panodaydı. Artık hepsi bu mührün arkasında: dilekçe mührüyle aynı gilded dil
/// (altın kenar + madalyon + nabız), gündem doldukça kızışır.
/// Dokun → [VillageLedger] açılır.
class LedgerSeal extends StatefulWidget {
  final VoidCallback onTap;

  /// Gündemdeki mesele sayısı (bekleyen dilekçe + mayalananlar). 0 = sakin.
  final int agendaCount;

  /// Köy şu an bir dilekçeye yanıt bekliyor mu — mühür kızarır + nabız hızlanır.
  final bool pendingPetition;

  /// Defter yeni bir mühre açık mı (mürekkep kurudu) — "defter açık" ipucu.
  final bool bookOpen;

  const LedgerSeal({
    super.key,
    required this.onTap,
    this.agendaCount = 0,
    this.pendingPetition = false,
    this.bookOpen = false,
  });

  @override
  State<LedgerSeal> createState() => _LedgerSealState();
}

class _LedgerSealState extends State<LedgerSeal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: _dur())
    ..repeat(reverse: true);

  bool _hover = false;

  Duration _dur() =>
      Duration(milliseconds: widget.pendingPetition ? 700 : 1900);

  @override
  void didUpdateWidget(LedgerSeal old) {
    super.didUpdateWidget(old);
    if (old.pendingPetition != widget.pendingPetition) {
      _ctrl.duration = _dur();
      _ctrl
        ..reset()
        ..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Sakin gündemde sönük ember; mesele varsa accent; dilekçe beklerken rust.
  Color get _accent => widget.pendingPetition
      ? AppUi.rust
      : (widget.agendaCount > 0 ? AppUi.accent : AppUi.textLo);

  String get _status {
    if (widget.pendingPetition) return 'köy söz bekliyor';
    if (widget.agendaCount > 0) return '${widget.agendaCount} mesele gündemde';
    if (widget.bookOpen) return 'defter yeni mühre açık';
    return 'köyün defteri';
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    // Gündem varken nefes alır; sakinken durur (dikkat çalmaz).
    final alive = widget.agendaCount > 0 || widget.pendingPetition;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final t = alive ? _ctrl.value : 0.0;
            final glow = (alive ? 0.20 : 0.08) + t * 0.34 + (_hover ? 0.18 : 0);
            final scale = 1.0 + t * (widget.pendingPetition ? 0.05 : 0.03) +
                (_hover ? 0.03 : 0);
            return Transform.scale(
              scale: scale,
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 7, 13, 7),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppUi.surface2, AppUi.surface1],
                  ),
                  borderRadius: BorderRadius.circular(AppUi.radius),
                  border: Border.all(
                      color: AppUi.gold.withValues(alpha: _hover ? 0.5 : 0.34),
                      width: 1.1),
                  boxShadow: [
                    ...AppUi.softShadow,
                    BoxShadow(
                        color: accent.withValues(alpha: glow),
                        blurRadius: 16,
                        spreadRadius: 1),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ⚖ madalyon + (varsa) gündem sayacı rozeti.
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(colors: [
                              Color.alphaBlend(
                                  accent.withValues(alpha: 0.22), AppUi.surface0),
                              AppUi.surface0,
                            ]),
                            border: Border.all(
                                color: AppUi.gold.withValues(alpha: 0.6),
                                width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                  color: accent.withValues(alpha: 0.35),
                                  blurRadius: 6),
                            ],
                          ),
                          child: const Text('📖',
                              style: TextStyle(fontSize: 16)),
                        ),
                        if (widget.agendaCount > 0)
                          Positioned(
                            top: -4,
                            right: -5,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: accent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                      color: accent.withValues(alpha: 0.6),
                                      blurRadius: 6),
                                ],
                              ),
                              child: Text('${widget.agendaCount}',
                                  style: AppUi.number.copyWith(
                                      fontSize: 9, color: AppUi.ink)),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('KÖY DEFTERİ',
                            style: AppUi.title
                                .copyWith(fontSize: 13, letterSpacing: 1.5)),
                        const SizedBox(height: 3),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: accent,
                                boxShadow: [
                                  BoxShadow(
                                      color: accent
                                          .withValues(alpha: 0.4 + t * 0.4),
                                      blurRadius: 5),
                                ],
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(_status,
                                style: AppUi.label.copyWith(
                                    fontSize: 7.5,
                                    letterSpacing: 0.8,
                                    color: widget.pendingPetition
                                        ? AppUi.rust
                                        : AppUi.textLo)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─── DEFTERİN RAFI ──────────────────────────────────────────────────────────
/// Bölüm rafı + gövde. Bölüm state'i BURADA durur (dıştaki [VillageLedger]
/// stateless kalsın: sahne her tick rebuild ederken seçili bölüm sıfırlanmaz —
/// gövdeler `bodyFor` ile TEMBEL kurulur, yani görünmeyen bölüm hiç inşa
/// edilmez; 5 bölümü birden kurmak nüfus listesi yüzünden pahalı olurdu).
///
/// Geniş ekranda sol dikey raf, dar ekranda üstte yatay şerit.
class _LedgerShell extends StatefulWidget {
  final LedgerSection initial;
  final Map<LedgerSection, int> badges;
  final Set<LedgerSection> hidden;

  /// Köy durum şeridi (moral/nüfus/yiyecek/altın) — bölümden bağımsız, hep üstte.
  final Widget strip;
  final Widget Function(LedgerSection) bodyFor;

  const _LedgerShell({
    required this.initial,
    required this.badges,
    required this.hidden,
    required this.strip,
    required this.bodyFor,
  });

  @override
  State<_LedgerShell> createState() => _LedgerShellState();
}

class _LedgerShellState extends State<_LedgerShell> {
  late LedgerSection _sec = widget.hidden.contains(widget.initial)
      ? LedgerSection.divan
      : widget.initial;

  List<LedgerSection> get _sections => [
        for (final s in LedgerSection.values)
          if (!widget.hidden.contains(s)) s,
      ];

  /// Sahne defteri "şu bölüm açılsın" diye yeniden açtığında (ör. HUD nüfus
  /// düğmesi) rafın seçimi de oraya kaysın — widget aynı ağaçta kalıyor olabilir.
  @override
  void didUpdateWidget(_LedgerShell old) {
    super.didUpdateWidget(old);
    if (old.initial != widget.initial &&
        !widget.hidden.contains(widget.initial)) {
      _sec = widget.initial;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        // YÜKSEKLİK de şart. Eskiden yalnız genişliğe bakılıyordu: telefon
        // YATAY modda 734dp geniş → "wide" sayılıp 186px'lik dikey rafa
        // düşüyordu, ama ekran 393dp kısa olduğu için beş bölümden ancak
        // dördü sığıyor, sonuncusu kesiliyordu. Kısa ekranda zaten hazır olan
        // yatay raf (_rowRail) doğru cevap.
        final wide = c.maxWidth >= 660 && c.maxHeight >= 430;
        // Telefonda NÜFUS bölümü kendi KPI şeridini (nüfus/hane/moral/varlık)
        // zaten taşıyor. Köy şeridini de üstüne koyunca 393dp'lik ekranda
        // ART ARDA DÖRT yatay bant oluyordu (raf · köy şeridi · KPI şeridi ·
        // sırala) ve listeye yer kalmıyordu — 16px'lik taşma buradan geliyordu.
        // Kısa ekranda tekrar eden bandı düşür.
        // Telefonda köy şeridi HİÇ çizilmez. Gösterdiği dört sayı
        // (moral/nüfus/yiyecek/altın) üstteki HUD durum kapsülünde zaten
        // sürekli duruyor — defterde tekrarı 55dp'lik bir bant karşılığında
        // hiçbir yeni şey söylemiyor, üstelik NÜFUS bölümünün kendi KPI şeridi
        // aynı sayıları bir kez daha yazıyordu. 393dp'lik ekranda listeye yer
        // kalmamasının en büyük tek sebebi buydu.
        final showStrip = !useCompactGameUi(context);
        final body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showStrip) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                child: widget.strip,
              ),
              Container(height: 1, color: AppUi.line),
            ],
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 190),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                // Varsayılan layout Stack'i ORTALAR: kısa bir bölüm (ör. Kronik)
                // gövdenin ortasında asılı kalır, üstünde kocaman boşluk olur.
                // expand + topCenter → her bölüm alanı doldurur, içerik üstten
                // başlar (Nüfus'un Expanded+ListView'i de sınırlı yükseklik ister).
                layoutBuilder: (current, previous) => Stack(
                  fit: StackFit.expand,
                  alignment: Alignment.topCenter,
                  children: [...previous, ?current],
                ),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                            begin: const Offset(0.04, 0), end: Offset.zero)
                        .animate(anim),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(
                  key: ValueKey(_sec),
                  child: widget.bodyFor(_sec),
                ),
              ),
            ),
          ],
        );
        if (!wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _rowRail(),
              Container(height: 1, color: AppUi.line),
              Expanded(child: body),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 186, child: _rail()),
            Container(width: 1, color: AppUi.line),
            Expanded(child: body),
          ],
        );
      },
    );
  }

  // ── Geniş: sol dikey raf ────────────────────────────────────────────────────

  Widget _rail() {
    return Container(
      color: AppUi.surface0.withValues(alpha: 0.55),
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final s in _sections) ...[
              _railItem(s),
              const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }

  Widget _railItem(LedgerSection s) {
    final on = _sec == s;
    final badge = widget.badges[s] ?? 0;
    return GestureDetector(
      onTap: () => setState(() => _sec = s),
      behavior: HitTestBehavior.opaque,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.fromLTRB(11, 9, 9, 9),
          decoration: BoxDecoration(
            color: on
                ? Color.alphaBlend(
                    AppUi.accent.withValues(alpha: 0.16), AppUi.surface1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppUi.radiusSm),
            // UNIFORM kenar ŞART (non-uniform + borderRadius = paint assert →
            // hiç çizilmez). Seçili işareti bu yüzden ayrı bir katman değil,
            // eşit kenar + ikon rengiyle verilir.
            border: Border.all(
                color: on ? AppUi.accent.withValues(alpha: 0.55) : AppUi.line,
                width: on ? 1.3 : 1),
          ),
          child: Row(
            children: [
              Opacity(
                opacity: on ? 1 : 0.72,
                child: Text(s.icon, style: const TextStyle(fontSize: 15)),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(s.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppUi.label.copyWith(
                          fontSize: 10,
                          letterSpacing: 1.2,
                          color: on ? AppUi.textHi : AppUi.textMid,
                        )),
                    const SizedBox(height: 2),
                    Text(s.blurb,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppUi.body
                            .copyWith(fontSize: 9, color: AppUi.textLo)),
                  ],
                ),
              ),
              if (badge > 0) _badge(badge, on),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(int n, bool on) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: AppUi.accent.withValues(alpha: on ? 0.9 : 0.7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text('$n',
          style: AppUi.number.copyWith(fontSize: 9, color: AppUi.ink)),
    );
  }

  // ── Dar: üstte yatay şerit ──────────────────────────────────────────────────

  Widget _rowRail() {
    return Container(
      color: AppUi.surface0.withValues(alpha: 0.55),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            for (final s in _sections) ...[
              _rowRailItem(s),
              const SizedBox(width: 6),
            ],
          ],
        ),
      ),
    );
  }

  Widget _rowRailItem(LedgerSection s) {
    final on = _sec == s;
    final badge = widget.badges[s] ?? 0;
    return GestureDetector(
      onTap: () => setState(() => _sec = s),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        // Yatay raf mobilde ANA gezinme — 37dp'de kalıyordu, 44 eşiğine çek.
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: on
              ? Color.alphaBlend(
                  AppUi.accent.withValues(alpha: 0.16), AppUi.surface1)
              : AppUi.surface0,
          borderRadius: BorderRadius.circular(AppUi.radiusSm),
          border: Border.all(
              color: on ? AppUi.accent.withValues(alpha: 0.55) : AppUi.line,
              width: on ? 1.3 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(s.icon, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 7),
            Text(s.label,
                style: AppUi.label.copyWith(
                  fontSize: 9.5,
                  letterSpacing: 1.1,
                  color: on ? AppUi.textHi : AppUi.textLo,
                )),
            if (badge > 0) _badge(badge, on),
          ],
        ),
      ),
    );
  }
}

// ── Meclis masası ─────────────────────────────────────────────────────────────

/// Hane renk paleti — [_houseColor] ile aynı, masa katmanında da erişilebilsin.
const List<Color> _kCouncilPalette = [
  Color(0xFF8FB255), Color(0xFFE0954A), Color(0xFF9E86C9), Color(0xFFD8AE56),
  Color(0xFF6FA9B8), Color(0xFFC57B6B), Color(0xFF8DA0C0), Color(0xFFB0A24E),
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
