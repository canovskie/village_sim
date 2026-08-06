// Köy Defteri önizleme harness'ı — defterin BEŞ bölümünü de (Divan / Kanunname
// / Nüfus / Tüzük / Kronik) mock veriyle render edip tek koşuda PNG'ye çeker.
// Tüm oyunu açmadan layout doğrulaması için.
//
// Çalıştır:  flutter run -d macos -t lib/tools/ledger_capture_main.dart
// Çıktı:     /tmp/ledger_<bölüm>.png  (DIVAN_INK=0 → mürekkep ıslak hâli)
//
// NOT: macOS'ta pencere ÖN PLANDA olmalı — arkadayken motor kare pompalamaz ve
// hiç yakalama olmaz. Render assert'leri (non-uniform border + borderRadius,
// Positioned-only Stack çöküşü…) paneli sessizce boş bırakır; bu yüzden
// FlutterError.onError yakalanıp RENDER_ERROR olarak basılır.
import 'dart:io';

import 'package:flutter/material.dart';

import '../characters/life_stage.dart';
import '../characters/npc_visual.dart';
import '../characters/villager_type.dart';
import '../core/resources.dart';
import '../entities/villager_entity.dart';
import '../scene/scene_data.dart';
import '../systems/chronicle.dart';
import '../systems/estate_system.dart';
import '../systems/house_system.dart';
import '../systems/petition_system.dart';
import '../systems/quest_book.dart';
import '../ui/app_ui.dart';
import '../ui/village_ledger.dart';
import '../ui/villager_roster_view.dart';
import 'capture_support.dart';
import 'law_demo_ctx.dart';

final GlobalKey _key = GlobalKey();

int _renderErrors = 0;

VillagerEntity _mk(String name, String surname, VillagerType type,
    {double wealth = 40, double morale = 0.6, double age = 4}) {
  final v = VillagerEntity(
    type: type,
    name: name,
    surname: surname,
    male: name.hashCode.isEven,
    startCol: 0,
    startRow: 0,
    ageDays: age,
  );
  v.wealth = wealth;
  v.morale = morale;
  return v;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final base = FlutterError.onError;
  FlutterError.onError = (details) {
    final msg = details.exceptionAsString();
    if (isClockClash(msg)) return; // harness artefaktı, panelle ilgisi yok
    _renderErrors++;
    stdout.writeln('RENDER_ERROR: $msg');
    base?.call(details);
  };

  // Mürekkep ıslak mı — defter kilitli hâlini de çekebilelim.
  final inkWet = (Platform.environment['DIVAN_INK'] ?? '1') == '0';

  const agenda = <DivanMatter>[
    DivanMatter(
      icon: '🥖',
      title: 'Ambar inceliyor',
      sub: 'Erzak azalıyor — köy bölüşüm kararı istemeden tedbir al.',
      pressure: 0.72,
      tone: PetitionTone.ominous,
      pending: true,
      graceProgress: 0.42,
    ),
    DivanMatter(
      icon: '🩸',
      title: 'Kan davası köyü zehirliyor',
      sub: 'İki aile arasında kan dökülüyor — sulh kararı yaklaşıyor.',
      pressure: 0.9,
      tone: PetitionTone.ominous,
    ),
    DivanMatter(
      icon: '⌂',
      title: 'Aksoy Hanesi küskün',
      sub: 'Gönülleri alınmazsa ısrarla gündeme gelecekler.',
      pressure: 0.55,
      tone: PetitionTone.solemn,
    ),
  ];

  const houses = <HouseSnapshot>[
    HouseSnapshot(
        surname: 'Demirhan',
        label: 'Demirhan Hanesi',
        mood: 0.78,
        swayShare: 0.44,
        ascendant: true,
        members: 6,
        tier: EstateMoodTier.content),
    HouseSnapshot(
        surname: 'Aksoy',
        label: 'Aksoy Hanesi',
        mood: 0.34,
        swayShare: 0.19,
        ascendant: false,
        members: 4,
        tier: EstateMoodTier.sullen),
    HouseSnapshot(
        surname: 'Yıldız',
        label: 'Yıldız Hanesi',
        mood: 0.60,
        swayShare: 0.22,
        ascendant: false,
        members: 3,
        tier: EstateMoodTier.neutral),
    HouseSnapshot(
        surname: 'Karaca',
        label: 'Karaca Hanesi',
        mood: 0.48,
        swayShare: 0.15,
        ascendant: false,
        members: 2,
        tier: EstateMoodTier.uneasy),
  ];

  // MECLİS MASASI — dört hanenin reisleri (gerçek görsel kimlikle). Mood/ascendant
  // yukarıdaki houses ile eşleşir; nüfuza göre Demirhan ortada olur.
  final seats = <DivanSeat>[
    DivanSeat(
        visual: NpcVisual.fromSeed(31),
        type: VillagerType.blacksmith,
        stage: LifeStage.elder,
        name: 'Kemal',
        surname: 'Demirhan',
        mood: 0.78,
        ascendant: true,
        members: 6,
        swayShare: 0.44),
    DivanSeat(
        visual: NpcVisual.fromSeed(12),
        type: VillagerType.farmer,
        stage: LifeStage.adult,
        name: 'Osman',
        surname: 'Aksoy',
        mood: 0.34,
        ascendant: false,
        members: 4,
        swayShare: 0.19),
    DivanSeat(
        visual: NpcVisual.fromSeed(58),
        type: VillagerType.merchant,
        stage: LifeStage.adult,
        name: 'Veli',
        surname: 'Yıldız',
        mood: 0.60,
        ascendant: false,
        members: 3,
        swayShare: 0.22),
    DivanSeat(
        visual: NpcVisual.fromSeed(7),
        type: VillagerType.hunter,
        stage: LifeStage.adult,
        name: 'Baran',
        surname: 'Karaca',
        mood: 0.48,
        ascendant: false,
        members: 2,
        swayShare: 0.15),
  ];

  const laws = <DivanFact>[
    DivanFact('👨‍👩‍👧', 'Aile teşviki', AppUi.info),
    DivanFact('🕯️', 'Kutsal gün', AppUi.info),
  ];
  const marks = <DivanFact>[
    DivanFact('🌾', 'Tarlalara iyi bakıldı', AppUi.sage),
    DivanFact('🤝', 'Komşuyla anlaşma', AppUi.sage),
  ];
  const crafts = <DivanFact>[
    DivanFact('🪵', 'Marangozluk', AppUi.accent),
    DivanFact('🍞', 'Fırıncılık', AppUi.accent),
  ];

  // NÜFUS — 26 köylü; servet/moral/barınma dağılımı geniş olsun (satır taşması,
  // sıralama ve portre layout'u gerçekçi yükte görünsün).
  const surnames = ['Demirhan', 'Aksoy', 'Yıldız', 'Karaca'];
  const names = [
    'Ayşe', 'Kemal', 'Zeynep', 'Veli', 'Hatice', 'Murat', 'Elif', 'Osman',
    'Leyla', 'Can', 'Deniz', 'Emre', 'Selin', 'Baran', 'Nur', 'Kaan',
  ];
  const types = VillagerType.values;
  final rosterRows = [
    for (int i = 0; i < 26; i++)
      () {
        final w = (i * 37 % 160).toDouble();
        final tier = w > 120
            ? 4
            : w > 80
                ? 3
                : w > 45
                    ? 2
                    : w > 20
                        ? 1
                        : 0;
        final label = switch (tier) {
          4 => 'Konak',
          3 => 'Taş Ev',
          2 => 'Ahşap Ev',
          1 => 'Çadır',
          _ => 'Evsiz',
        };
        return VillagerStatRow(
          _mk(names[i % names.length], surnames[i % surnames.length],
              types[i % types.length],
              wealth: w, morale: (i * 13 % 100) / 100.0),
          label,
          tier,
        );
      }(),
  ];

  // TÜZÜK — kademe 1'de, ilk dört görevi bitirmiş bir köy.
  const completed = {'firepit', 'lumber', 'house', 'farm'};
  final quests = QuestBook.activeQuests(
    QuestContext(
      buildings: const [],
      farmTiles: const [],
      population: 26,
      stock: ResourceBundle(wood: 60, stone: 30, food: 41, gold: 18),
      policies: VillagePolicies(),
      decorCount: 12,
      charterTier: 1,
    ),
    completed,
  );

  const chronicle = <ChronicleEntry>[
    ChronicleEntry(day: 1, icon: '🔥', text: 'Ateş yakıldı, köy kuruldu.'),
    ChronicleEntry(
        day: 4,
        icon: '🏡',
        text: 'İlk hane çatısını kapattı; Demirhanlar artık üşümüyor.'),
    ChronicleEntry(
        day: 9,
        icon: '💍',
        text: 'Ayşe ile Kemal ateş başında evlendi.',
        milestone: true),
    ChronicleEntry(day: 15, icon: '📜', text: 'Komşuluk beratı mühürlendi.'),
    ChronicleEntry(
        day: 21,
        icon: '⚔',
        text: 'Aksoy ile Karaca arasında kan davası başladı.',
        milestone: true),
    ChronicleEntry(day: 26, icon: '🌾', text: 'İlk harman kaldırıldı.'),
  ];

  for (final section in LedgerSection.values) {
    runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RepaintBoundary(
        key: _key,
        child: Scaffold(
          backgroundColor: const Color(0xFF1A2A20), // sahne yerine sakin zemin
          body: Stack(
            fit: StackFit.expand,
            children: [
              // Kalıcı mühür — oyundaki yeriyle aynı (sol üst).
              Positioned(
                left: 14,
                top: 92,
                child: LedgerSeal(
                  onTap: () {},
                  agendaCount: agenda.length,
                  pendingPetition: true,
                  bookOpen: !inkWet,
                ),
              ),
              VillageLedger(
                // Her bölüm TAZE bir ağaçtan çizilsin: aynı element yeniden
                // kullanılırsa raf/gövde geçiş animasyonunun ortasında yakalanıp
                // iki bölüm üst üste binmiş gibi görünür (yakalama artefaktı).
                key: ValueKey(section),
                initialSection: section,
                badges: const {
                  LedgerSection.divan: 3,
                  LedgerSection.kanun: 5,
                  LedgerSection.nufus: 2,
                  LedgerSection.tuzuk: 4,
                },
                identity: 'Demirhan Hanesi',
                village: 'Değirmenli',
                identityBonus: '★ Bereketli Köy — tarlalar %15 gürbüz büyür',
                morale: 0.63,
                population: 26,
                food: 41,
                gold: 18,
                agenda: agenda,
                houses: houses,
                seats: seats,
                openHouseCard: -1, // capture: kart kapalı (kamulaştırma kartı görünsün)
                massSeizure: const HouseActionEntry(
                    icon: '⚑',
                    label: 'MÜLKİYETİ KALDIR',
                    detail: 'Bu köy mülkü kutsal sayıyor. Ortak sofraya '
                        'inanmayan bir düzen, mülkiyeti kendi eliyle kaldırmaz.',
                    enabled: false),
                houseActionsFor: (surname) => const [
                  HouseActionEntry(
                      icon: '🎁',
                      label: 'Mülk bağışla',
                      detail: 'Hane borçlanır ve güçlenir; ötekiler kayırmayı görür.',
                      effects: ['−16 altın', 'hâl +0.18', 'nüfuz +0.5'],
                      enabled: true),
                  HouseActionEntry(
                      icon: '⚖',
                      label: 'Ceza kes',
                      detail: 'Kan dökmeden hizaya getirir; köy sessizce ürperir.',
                      effects: ['hâl −0.14', 'nüfuz −0.3', 'huzursuzluk +0.03'],
                      enabled: true),
                  HouseActionEntry(
                      icon: '🏚',
                      label: 'Mala el koy',
                      detail: 'Hane defteri fermanı mühürlü değil — neyin kimde '
                          'olduğu yazılı olmadan mala el konmaz.',
                      enabled: false),
                  HouseActionEntry(
                      icon: '💍',
                      label: 'Nikâh bağla',
                      detail: 'İki haneye nikâh önerirsin; gönül rızası aranır.',
                      effects: ['hâl −0.05'],
                      enabled: true),
                  HouseActionEntry(
                      icon: '🚷',
                      label: 'Sürgüne yolla',
                      detail: 'Meclis buna razı olmaz. Bu yetki ancak sözün '
                          'mutlaklaştığı bir köyde kullanılır.',
                      enabled: false),
                  HouseActionEntry(
                      icon: '🕯',
                      label: 'Gizli iş çevir',
                      detail: 'Nüfuzlarını sessizce kırarsın — ifşa olursan bedeli ağır.',
                      effects: ['−6 altın', 'nüfuz −0.5', 'ifşa riski %34'],
                      enabled: true),
                ],
                laws: laws,
                marks: marks,
                crafts: crafts,
                legacy: 0.09,
                onOpenPetition: () {},
                sealed: const {
                  'neighborliness',
                  'winterFodder',
                  'familyReunion',
                },
                lawContext: kDemoLawContext,
                lawSpotlightId: 'irrigation',
                inkDrySec: inkWet ? 180 : 0,
                inkDryTotalSec: 240,
                onOpenLaw: (_) {},
                rosterRows: rosterRows,
                onSelectVillager: (_) {},
                quests: quests,
                completedQuests: completed,
                charterTier: 1,
                enactedPolicies: 2,
                chronicle: chronicle,
                milestoneCount: 2,
                onClose: () {},
              ),
            ],
          ),
        ),
      ),
    ));
    // Reveal + bar/portre animasyonları otursun. Sadece beklemek YETMEZ:
    // pencere ön planda değilse motor kare üretmez, ticker donar ve panelin
    // açılış Opacity'si 0'da kalır → kapkara kare. Kareyi elde pompala.
    await settleFrames(1400);
    await captureBoundary(_key, '/tmp/ledger_${section.name}.png', pixelRatio: 2.0);
  }

  stdout.writeln(
      _renderErrors == 0 ? 'RENDER_OK' : 'RENDER_ERRORS: $_renderErrors');
  exit(0);
}




