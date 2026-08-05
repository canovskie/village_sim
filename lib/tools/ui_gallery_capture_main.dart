// OYUNUN TÜM UI YÜZEYLERİNİN ÖNİZLEME GALERİSİ — tek çalıştırmada her ekranı,
// paneli, modalı ve tasarım-sistemi parçasını mock veriyle render edip ayrı ayrı
// PNG'ye çeker + `manifest.json` yazar (HTML galeriyi bu manifest besler).
//
// Neden tek harness: her yüzey için ayrı `flutter run` (17 tane vardı) hem yavaş
// hem de kapsamı dağıtıyor. Burada yüzeyler SIRAYLA aynı app içinde gösterilir.
//
// Boyut hilesi: her yüzey kendi mantıksal ölçüsünde (ör. 1440×900) layout olur,
// ekrana sığsın diye FittedBox ile KÜÇÜLTÜLEREK gösterilir; ama
// RenderRepaintBoundary.toImage boundary'nin KENDİ katmanını çizer — üstteki
// scale/clip capture'a girmez. Yani pencere 800×600 olsa da çıktı tam ölçüdür.
//
// Çalıştır:  flutter run -d macos -t lib/tools/ui_gallery_capture_main.dart
// Çıktı:     preview/ui/<id>.png + preview/ui/manifest.json
// Env:       OUT=<dizin>  ONLY=<id,id>  (yalnız bu yüzeyleri çek)
//            PHONE=1      TELEFON MODU — her yüzeyi kendi masaüstü ölçüsünde
//                         değil, REFERANS CİHAZ (iPhone 11, 896×414 yatay +
//                         çentik güvenli alanı) ölçüsünde çizer, mobil yazı
//                         tabanını uygular. "Bu panelin telefonda hâli ne?"
//                         sorusunun tek koşuluk cevabı.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../buildings/building_entity.dart';
import '../buildings/building_renderer.dart';
import '../rendering/character_renderer.dart';
import '../buildings/building_lore.dart';
import '../buildings/building_type.dart';
import '../characters/villager_type.dart';
import '../core/resources.dart';
import '../cutscene/cutscene.dart';
import '../cutscene/cutscene_player.dart';
import '../dev/dev_command.dart';
import '../dev/dev_console.dart';
import '../entities/villager_entity.dart';
import '../save/save_manager.dart';
import '../scene/scene_data.dart';
import '../systems/building_system.dart';
import '../systems/chronicle.dart';
import '../systems/estate_system.dart';
import '../systems/event_system.dart';
import '../systems/house_system.dart';
import '../systems/imperial.dart';
import '../systems/regime.dart';
import '../systems/law_book.dart';
import '../systems/petition_system.dart';
import '../systems/quest_book.dart';
import '../text/voice.dart';
import '../ui/about_screen.dart';
import '../ui/app_ui.dart';
import '../ui/building_info_panel.dart';
import '../ui/building_brief.dart';
import '../ui/building_panel.dart';
import '../ui/command_bar.dart';
import '../ui/dev_panel.dart';
import '../ui/village_ledger.dart';
import '../ui/event_banner.dart';
import '../ui/event_choice_modal.dart';
import '../ui/hud.dart';
import '../ui/imperial_modal.dart';
import '../ui/law_book_panel.dart';
import '../ui/law_compass_view.dart';
import '../ui/loading_screen.dart';
import '../ui/main_menu_screen.dart';
import '../ui/mobile_ui.dart';
import '../ui/mode_button.dart';
import '../ui/world_tag.dart';
import '../ui/objective_panel.dart';
import '../ui/option_scene_card.dart';
import '../ui/petition_modal.dart';
import '../ui/petition_scene_card.dart';
import '../ui/road_panel.dart';
import '../ui/save_slots_screen.dart';
import '../ui/settings_screen.dart';
import '../ui/villager_info_panel.dart';
import '../ui/villager_roster_view.dart';
import '../world/road_surface.dart';
import '../world/season.dart';
import 'law_demo_ctx.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Yüzey tanımı
// ─────────────────────────────────────────────────────────────────────────────

class Shot {
  final String id;
  final String title;
  final String group;
  final String note;
  final double w;
  final double h;
  final int settleMs;
  final Widget Function() build;
  const Shot({
    required this.id,
    required this.title,
    required this.group,
    required this.build,
    this.note = '',
    this.w = 1280,
    this.h = 800,
    this.settleMs = 1400,
  });
}

void _noop() {}

// ── Ortak mock veri ─────────────────────────────────────────────────────────

ResourceBundle _stock() => ResourceBundle(
  wood: 62,
  stone: 38,
  iron: 12,
  coal: 9,
  food: 74,
  honey: 5,
  reed: 11,
  gold: 26,
);

const _houses = <HouseSnapshot>[
  HouseSnapshot(
    surname: 'Demirhan',
    label: 'Demirhan Hanesi',
    mood: 0.78,
    swayShare: 0.44,
    ascendant: true,
    members: 6,
    tier: EstateMoodTier.content,
  ),
  HouseSnapshot(
    surname: 'Aksoy',
    label: 'Aksoy Hanesi',
    mood: 0.34,
    swayShare: 0.19,
    ascendant: false,
    members: 4,
    tier: EstateMoodTier.sullen,
  ),
  HouseSnapshot(
    surname: 'Yıldız',
    label: 'Yıldız Hanesi',
    mood: 0.60,
    swayShare: 0.22,
    ascendant: false,
    members: 3,
    tier: EstateMoodTier.neutral,
  ),
  HouseSnapshot(
    surname: 'Karaca',
    label: 'Karaca Hanesi',
    mood: 0.48,
    swayShare: 0.15,
    ascendant: false,
    members: 2,
    tier: EstateMoodTier.uneasy,
  ),
];

// Defterin TÜZÜK ve KRONİK bölümleri için demo veri.
const _demoCompletedQuests = {'firepit', 'lumber', 'house', 'farm'};

final _demoQuests = QuestBook.activeQuests(
  QuestContext(
    buildings: const [],
    farmTiles: const [],
    population: 24,
    stock: ResourceBundle(wood: 60, stone: 30, food: 41, gold: 18),
    policies: VillagePolicies(),
    decorCount: 12,
    charterTier: 1,
  ),
  _demoCompletedQuests,
);

const _demoChronicle = <ChronicleEntry>[
  ChronicleEntry(day: 1, icon: '🔥', text: 'Ateş yakıldı, köy kuruldu.'),
  ChronicleEntry(
    day: 9,
    icon: '💍',
    text: 'Ayşe ile Kemal ateş başında evlendi.',
    milestone: true,
  ),
  ChronicleEntry(day: 15, icon: '📜', text: 'Komşuluk beratı mühürlendi.'),
  ChronicleEntry(
    day: 21,
    icon: '⚔',
    text: 'Aksoy ile Karaca arasında kan davası başladı.',
    milestone: true,
  ),
  ChronicleEntry(day: 26, icon: '🌾', text: 'İlk harman kaldırıldı.'),
];

const _agenda = <DivanMatter>[
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

const _sealedLaws = <String>{
  'neighborliness',
  'winterFodder',
  'sharedHarvest',
  'nizam.watch',
};

VillagerEntity _mkVillager(
  String name,
  String surname,
  VillagerType t,
  double age, {
  int seed = 7,
}) {
  return VillagerEntity(
    type: t,
    name: name,
    surname: surname,
    male: seed.isEven,
    startCol: 0,
    startRow: 0,
    ageDays: age,
    personalitySeed: seed,
  );
}

/// Aile bağları + yaşam öyküsü dolu bir köylü — panelin bütün bölümleri dolsun.
VillagerEntity _richVillager() {
  final v = _mkVillager(
    'Ayşe',
    'Demirhan',
    VillagerType.merchant,
    6.5,
    seed: 11,
  );
  v.morale = 0.72;
  v.mood = 0.3;
  v.isFavorite = true;
  v.wed = true;
  final esi = _mkVillager(
    'Kemal',
    'Demirhan',
    VillagerType.blacksmith,
    7.0,
    seed: 4,
  );
  final anne = _mkVillager(
    'Nur',
    'Demirhan',
    VillagerType.farmer,
    14.0,
    seed: 6,
  );
  final kardes = _mkVillager(
    'Elif',
    'Demirhan',
    VillagerType.priest,
    5.0,
    seed: 9,
  );
  final cocuk = _mkVillager(
    'Deniz',
    'Demirhan',
    VillagerType.farmer,
    0.6,
    seed: 3,
  );
  v.parents.add(anne);
  anne.children.addAll([v, kardes]);
  kardes.parents.add(anne);
  v.children.add(cocuk);
  cocuk.parents.addAll([v, esi]);
  esi.children.add(cocuk);
  v.life.addAll(const [
    ChronicleEntry(day: 1, icon: '👶', text: 'Demirhan Hanesi\'nde doğdu.'),
    ChronicleEntry(
      day: 3,
      icon: '✨',
      text: 'Çağrısını buldu — tüccar oldu.',
      milestone: true,
    ),
    ChronicleEntry(
      day: 5,
      icon: '💍',
      text: 'Kemal ile evlendi.',
      milestone: true,
    ),
    ChronicleEntry(day: 6, icon: '👶', text: 'Deniz doğdu.'),
    ChronicleEntry(day: 6, icon: '🎉', text: 'Köy şenliğinde ozanı ağırladı.'),
  ]);
  return v;
}

List<VillagerStatRow> _statRows() {
  const surnames = [
    'Demirhan',
    'Aksoy',
    'Yıldız',
    'Karaca',
    'Şahin',
    'Kaya',
    'Doğan',
  ];
  const names = [
    'Ayşe',
    'Kemal',
    'Zeynep',
    'Veli',
    'Hatice',
    'Murat',
    'Elif',
    'Osman',
    'Leyla',
    'Can',
    'Deniz',
    'Emre',
    'Selin',
    'Baran',
    'Nur',
    'Kaan',
  ];
  final types = VillagerType.values;
  String label(int t) => switch (t) {
    4 => 'Konak',
    3 => 'Taş Ev',
    2 => 'Ahşap Ev',
    1 => 'Çadır',
    _ => 'Evsiz',
  };
  int tier(double w) => w > 120
      ? 4
      : w > 80
      ? 3
      : w > 45
      ? 2
      : w > 20
      ? 1
      : 0;
  final out = <VillagerStatRow>[];
  for (int i = 0; i < 34; i++) {
    final v = _mkVillager(
      names[i % names.length],
      surnames[i % surnames.length],
      types[i % types.length],
      2.0 + (i % 12),
      seed: i + 3,
    );
    v.wealth = (i * 37 % 160).toDouble();
    v.morale = (i * 13 % 100) / 100.0;
    v.isFavorite = i % 7 == 0;
    out.add(VillagerStatRow(v, label(tier(v.wealth)), tier(v.wealth)));
  }
  return out;
}

List<SaveSlotMeta> _slots() {
  // NOT: sabit tarih — capture'lar arasında "4 dk önce" oynamasın diye değil,
  // gerçek DateTime.now() kullanılır; galeri anlık görüntüdür.
  final now = DateTime.now();
  return [
    SaveSlotMeta(
      id: '1',
      name: 'Bahçeköy',
      savedAt: now.subtract(const Duration(minutes: 4)),
      day: 41,
      population: 24,
      identity: 'Demirhan Hanesi',
    ),
    SaveSlotMeta(
      id: '2',
      name: 'Yeşilpınar',
      savedAt: now.subtract(const Duration(hours: 6)),
      day: 12,
      population: 9,
      identity: 'Dengeli Köy',
    ),
    SaveSlotMeta(
      id: '3',
      name: 'Taşocağı',
      savedAt: now.subtract(const Duration(days: 3)),
      day: 77,
      population: 38,
      identity: 'Aksoy Hanesi',
    ),
  ];
}

const _voiceCtx = VoiceCtx(
  seed: 5,
  name: 'İlyas',
  other: 'Ayşe',
  profession: 'Demirci',
  house: 'Karaoğlan',
  estate: 'Emekçiler',
  village: 'Bahçeköy',
  season: Season.winter,
  day: 41,
);

List<Petition> _petitions() {
  final all = PetitionSystem.allForTest.map((p) => p.spoken(_voiceCtx)).toList()
    ..sort((a, b) => b.options.length.compareTo(a.options.length));
  return all;
}

EventOutcome _eventPlain() =>
    EventSystem.events.firstWhere((e) => e.choices == null);
EventOutcome _eventChoice() =>
    EventSystem.events.firstWhere((e) => e.choices != null);

/// Oyun dünyasının yerine geçen sıcak zemin — HUD/banner gibi dünya üstü
/// katmanlar boşlukta yüzmesin.
Widget _worldBackdrop({Widget? child}) => DecoratedBox(
  decoration: const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF2A3A4A), Color(0xFF3E4A3A), Color(0xFF243026)],
      stops: [0.0, 0.55, 1.0],
    ),
  ),
  // Material ATASI ŞART: yoksa Text'ler Flutter'ın "unstyled" fallback'iyle
  // (sarı çift alt-çizgi) çizilir → önizleme paneli gerçekte olmayan bir
  // alt-çizgi bug'ı gösterir. Gerçek oyunda paneller Scaffold içinde.
  child: Material(
    type: MaterialType.transparency,
    child: SizedBox.expand(child: child),
  ),
);

Widget _label(String text) => Padding(
  padding: const EdgeInsets.only(bottom: 6, top: 2),
  child: Text(
    text.toUpperCase(),
    style: AppUi.label.copyWith(
      fontSize: 8,
      color: AppUi.textLo,
      letterSpacing: 1.4,
    ),
  ),
);

// ─────────────────────────────────────────────────────────────────────────────
// Yüzey listesi
// ─────────────────────────────────────────────────────────────────────────────

List<Shot> buildShots() => <Shot>[
  // ── Ekranlar ────────────────────────────────────────────────────────────
  Shot(
    id: 'main_menu',
    title: 'Ana Menü — Şafak Sahnesi',
    group: 'Ekranlar',
    note: 'Akşamdan gün doğumuna geçen prosedürel sahne, fenerli karşılayıcı.',
    w: 1440,
    h: 900,
    settleMs: 2800,
    build: () => MainMenuScreen(
      onNewGame: _noop,
      onContinue: (_) {},
      onReferenceVillage: _noop,
    ),
  ),
  Shot(
    id: 'save_slots',
    title: 'Kayıtlı Köyler',
    group: 'Ekranlar',
    note: 'Menü sahnesi üstünde overlay pano; en son köye tek tıkla devam.',
    w: 1440,
    h: 900,
    settleMs: 1800,
    build: () => Scaffold(
      backgroundColor: const Color(0xFF3C2A46),
      body: Stack(
        fit: StackFit.expand,
        children: [
          SaveSlotsPanel(
            onClose: _noop,
            onContinue: (_) {},
            loader: () async => _slots(),
          ),
        ],
      ),
    ),
  ),
  Shot(
    id: 'save_slots_empty',
    title: 'Kayıtlı Köyler — Boş Durum',
    group: 'Ekranlar',
    w: 1440,
    h: 900,
    settleMs: 1800,
    build: () => Scaffold(
      backgroundColor: const Color(0xFF3C2A46),
      body: Stack(
        fit: StackFit.expand,
        children: [
          SaveSlotsPanel(
            onClose: _noop,
            onContinue: (_) {},
            loader: () async => <SaveSlotMeta>[],
          ),
        ],
      ),
    ),
  ),
  const Shot(
    id: 'settings',
    title: 'Ayarlar',
    group: 'Ekranlar',
    w: 1100,
    h: 800,
    build: SettingsScreen.new,
  ),
  const Shot(
    id: 'about',
    title: 'Hakkında',
    group: 'Ekranlar',
    w: 1000,
    h: 800,
    build: AboutScreen.new,
  ),
  const Shot(
    id: 'loading',
    title: 'Yükleme Ekranı',
    group: 'Ekranlar',
    w: 900,
    h: 520,
    settleMs: 1800,
    build: LoadingScreen.new,
  ),
  Shot(
    id: 'cutscene_opening',
    title: 'Açılış Sinematiği',
    group: 'Ekranlar',
    note: 'İmparatorluğun vergi elinden kaçış — 2B sinematik oynatıcı.',
    w: 1440,
    h: 810,
    settleMs: 2600,
    build: () => CutscenePlayer(cutscene: kOpeningCutscene, onDone: _noop),
  ),
  Shot(
    id: 'cutscene_choice',
    title: 'Açılış — Kafilenin Yükü',
    group: 'Ekranlar',
    note:
        'Sinematiğe gömülü İLK karar: kurucu kadro, nüfus ve başlangıç '
        'stoğu bu karttan çıkar.',
    w: 1440,
    h: 810,
    // Kapı ~24 sn'de açılır (iki replik + daktilo). Yakalama beklemesin
    // diye sahne saati hızlandırılır; kapı UI'ı zamanlamadan bağımsız.
    settleMs: 6000,
    build: () => CutscenePlayer(
      cutscene: kOpeningCutscene,
      timeScale: 6.0,
      onDone: _noop,
    ),
  ),
  Shot(
    id: 'cutscene_name',
    title: 'Açılış — Köyün ve Hanenin Adı',
    group: 'Ekranlar',
    note:
        'İkinci kapı: köyün adı kayıt kartına, hane adı kurucuların '
        'soyadına işlenir.',
    w: 1440,
    h: 810,
    settleMs: 5000,
    // Ad kapısı sinematiğin SON çekimidir; önündeki kapı (kafile yükü)
    // oyuncu cevabı beklediği için yakalama oraya kendiliğinden varamaz.
    // O yüzden yalnız son çekim oynatılır.
    build: () => CutscenePlayer(
      cutscene: Cutscene([kOpeningCutscene.shots.last]),
      timeScale: 6.0,
      onDone: _noop,
    ),
  ),

  // ── Oyun içi HUD katmanı ────────────────────────────────────────────────
  Shot(
    id: 'cutscene_name_keyboard',
    title: 'Açılış — Ad Girişi / Klavye Açık',
    group: 'Ekranlar',
    note:
        'Mobil yatay klavye açıldığında başlık çekilir; ince '
        'kimlik rayı klavyenin hemen üstünde kalır.',
    w: 1440,
    h: 810,
    settleMs: 5000,
    build: () => Builder(
      builder: (context) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(viewInsets: const EdgeInsets.only(bottom: 180)),
          child: CutscenePlayer(
            cutscene: Cutscene([kOpeningCutscene.shots.last]),
            timeScale: 6.0,
            onDone: _noop,
          ),
        );
      },
    ),
  ),
  Shot(
    id: 'world_tag',
    title: 'Hover Künyesi — Dünya İçi',
    group: 'Oyun İçi HUD',
    note:
        'İmleç bir NPC üstüne gelince: kutu/kart YOK, hedefi takip eden '
        'yazıt + ayak halkası. Okunurluk gölgeden gelir.',
    w: 1000,
    h: 460,
    build: () => _worldBackdrop(
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _TagDemoPainter())),
          const WorldTagRing(feet: Offset(250, 330), radius: 26, opacity: 1.0),
          const WorldTag(
            anchor: Offset(250, 108),
            title: 'Ayşe Hatun',
            line2: 'çiftçi · Demirci Hanesi',
            line3: 'tarlada · keyfi iyi',
            opacity: 1.0,
          ),
          const WorldTagRing(feet: Offset(560, 330), radius: 26, opacity: 1.0),
          const WorldTag(
            anchor: Offset(560, 108),
            title: 'Kara Mustafa',
            line2: 'madenci · evsiz',
            line3: 'hasta · kırgın',
            opacity: 1.0,
          ),
          // Mezar künyesi — aynı dil, nötr renk.
          const WorldTag(
            anchor: Offset(830, 300),
            title: 'İsmail Dede',
            line2: 'huzur içinde yatıyor',
            line3: '',
            opacity: 1.0,
            accent: Color(0xFF7E86A0),
          ),
        ],
      ),
    ),
  ),
  Shot(
    id: 'hud',
    title: 'HUD — Kaynak / Zaman / Moral',
    group: 'Oyun İçi HUD',
    note: 'Üst kaynak şeridi, mevsim-gün göstergesi, hız ve dev kısayolları.',
    w: 1440,
    h: 520,
    build: () => _worldBackdrop(
      child: GameHUD(
        stockpile: _stock(),
        woodInTransit: 4,
        stoneInTransit: 2,
        ironInTransit: 0,
        coalInTransit: 1,
        foodInTransit: 6,
        villagerCount: 24,
        farmerCount: 5,
        woodcutterCount: 3,
        minerCount: 2,
        fisherCount: 2,
        builderCount: 4,
        busyBuilders: 2,
        shepherdCount: 1,
        floristCount: 1,
        homelessCount: 2,
        timeOfDay: 0.34,
        rainIntensity: 0,
        dayLight: 0.9,
        dayCount: 41,
        season: Season.autumn,
        seasonProgress: 0.45,
        buildingCount: 17,
        pendingOrderCount: 3,
        morale: 0.63,
        lowWater: false,
        starving: false,
        eventLabel: 'Gezgin ozan köye uğradı',
        stockCapacity: 200,
        fullPulse: 0,
        moraleBreakdown: const [
          ('Ocak başı', 0.08),
          ('Konut', 0.06),
          ('Kültür', 0.04),
          ('Kalabalık', -0.05),
        ],
        onHighlightHomeless: _noop,
        godMode: false,
        onNewMap: _noop,
        onToggleGod: _noop,
        onTriggerEvent: _noop,
        timeScale: 1,
        onCycleSpeed: _noop,
        effectTimeLeft: 7,
        effectDuration: 12,
        effectPositive: true,
        onToggleDev: _noop,
        muted: false,
        onToggleMute: _noop,
        onOpenRoster: _noop,
      ),
    ),
  ),
  Shot(
    id: 'build_panel',
    title: 'İnşa Paleti — Kategoriler',
    group: 'Oyun İçi HUD',
    note: 'Alt çubuğun sekmeli hâli; kilitli zanaatlar soluk görünür.',
    w: 1400,
    h: 700,
    build: () => _worldBackdrop(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final c in [
              BuildCategory.konut,
              BuildCategory.uretim,
              BuildCategory.ticaret,
              BuildCategory.civic,
              BuildCategory.altyapi,
            ]) ...[
              _label(c.label),
              BuildingPanel(
                stockpile: _stock(),
                selected: c == BuildCategory.konut
                    ? BuildingType.woodenHouse
                    : null,
                onSelect: (_) {},
                hasFirepit: true,
                category: c,
                // Birkaç zanaat kilitli — kilitli görünümü de görelim.
                isUnlocked: (t) => t.index % 5 != 3,
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    ),
  ),
  Shot(
    id: 'road_panel',
    title: 'Yol Paleti',
    group: 'Oyun İçi HUD',
    w: 720,
    h: 260,
    build: () => _worldBackdrop(
      child: Center(
        child: RoadPanel(
          stockpile: _stock(),
          selected: RoadSurface.stone,
          onSelect: (_) {},
          onSelectErase: () {},
        ),
      ),
    ),
  ),
  Shot(
    id: 'objective_panel',
    title: 'Tüzük / Görev Panosu',
    group: 'Oyun İçi HUD',
    note: 'Kademe başlığı + açık görevler + sıradaki kademe.',
    w: 520,
    h: 620,
    build: () {
      final quests = [
        for (int i = 0; i < 8; i++)
          QuestState(QuestBook.all[i % QuestBook.all.length], i < 3, i == 3),
      ];
      return _worldBackdrop(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Align(
            alignment: Alignment.topLeft,
            child: ObjectivePanel(
              quests: quests,
              tierIndex: 1,
              tierName: QuestBook.tiers[1].name,
              tierIcon: QuestBook.tiers[1].icon,
              completedCount: 3,
              totalCount: 8,
              next: QuestBook.tiers.length > 2 ? QuestBook.tiers[2] : null,
              collapsed: false,
              onToggleCollapse: _noop,
            ),
          ),
        ),
      );
    },
  ),
  // Konsept 04 — KOMUTA: tam ekran, alt komuta çubuğu + görev takipçisi.
  Shot(
    id: 'komuta',
    title: 'Komuta — Alt Komuta Çubuğu (konsept 04)',
    group: 'Oyun İçi HUD',
    note: 'Sol inşa · orta bağlam eylemleri · sağ menü; görev sağ üstte.',
    w: 1400,
    h: 760,
    build: () => _worldBackdrop(
      child: Stack(
        children: [
          // Görev takipçisi — sağ üst
          Positioned(
            right: 16,
            top: 14,
            child: QuestTracker(
              icon: GameIconData.wheat,
              activeLabel: 'Toprağı sür',
              tierName: 'Kapısı Açık Köy',
              done: 3,
              total: 8,
              onOpen: _noop,
            ),
          ),
          // Komuta çubuğu — tam genişlik, altta
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: CommandBar(
              agenda: 2,
              onDefter: _noop,
              onDivan: _noop,
              onRoster: _noop,
              buildSegment: BuildingPanel(
                stockpile: _stock(),
                selected: BuildingType.woodenHouse,
                onSelect: (_) {},
                hasFirepit: true,
                category: BuildCategory.konut,
              ),
              context: CommandContext(
                title: 'Köy Evi',
                subtitle: 'Demirhan Hanesi',
                stats: const [
                  ('Sakinler', '3/2', Color(0xFF7FC08C)),
                  ('Su', '62%', Color(0xFF52B9B0)),
                ],
                actions: [
                  CommandAction('Şenlik', GameIconData.festival, onTap: _noop),
                  CommandAction('Taşı', GameIconData.hammer, onTap: _noop),
                  CommandAction(
                    'Yık',
                    GameIconData.demolish,
                    danger: true,
                    onTap: _noop,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  ),
  // Komuta — İNŞA seçimi: orta segment binanın AÇIKLAMASINI gösterir.
  Shot(
    id: 'komuta_build',
    title: 'Komuta — İnşa Seçimi (bina açıklaması)',
    group: 'Oyun İçi HUD',
    note: 'Palette\'ten bina seçilince orta segment "ne işe yarar" der.',
    w: 1400,
    h: 760,
    build: () => _worldBackdrop(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: CommandBar(
          agenda: 2,
          onDefter: _noop,
          onDivan: _noop,
          onRoster: _noop,
          buildSegment: BuildingPanel(
            stockpile: _stock(),
            selected: BuildingType.mill,
            onSelect: (_) {},
            hasFirepit: true,
            category: BuildCategory.uretim,
          ),
          context: CommandContext(
            title: 'Değirmen',
            description:
                'Kanatlar döndükçe içerisi un kokar. Değirmen çalışırken '
                'tarladan gelen her balya +1 fazla yiyecek eder.',
            actions: [
              CommandAction('Vazgeç', GameIconData.close, onTap: _noop),
            ],
          ),
        ),
      ),
    ),
  ),
  // İnşa künyesi — "nereye kurulmalı" katmanı (canlı ✓/○ + tatlı not).
  Shot(
    id: 'build_brief_tent',
    title: 'İnşa Künyesi — Çadır (ocağın yanında)',
    group: 'Oyun İçi HUD',
    note: 'Yerleşim avantajı canlı doğrulanır: ocağın menzilinde ✓ yanar.',
    w: 900,
    h: 640,
    build: () => _worldBackdrop(
      child: const Center(
        child: BuildingBrief(
          type: BuildingType.tent,
          facts: SiteFacts(
            hearthWarmth: 1.0,
            hasHearth: true,
            hearthLit: true,
            homesNear: 2,
            openTilesNear: 22,
          ),
          reason: null,
          noteSeed: 0,
        ),
      ),
    ),
  ),
  Shot(
    id: 'build_brief_blocked',
    title: 'İnşa Künyesi — Oduncu (kural ihlali)',
    group: 'Oyun İçi HUD',
    note: 'Kural sağlanmayınca "!" + kırmızı sebep satırı; avantaj ○ kalır.',
    w: 900,
    h: 640,
    build: () => _worldBackdrop(
      child: const Center(
        child: BuildingBrief(
          type: BuildingType.lumberCamp,
          facts: SiteFacts(openTilesNear: 30),
          reason: 'Yakında ağaç yok — ormana yakın kur',
          noteSeed: 1,
        ),
      ),
    ),
  ),
  Shot(
    id: 'build_brief_mobile',
    title: 'İnşa Künyesi — Telefon (ince şerit)',
    group: 'Mobil',
    note:
        'Alçak ekranda künye başlıksız tek satırlık şerit; ad/maliyet '
        'komuta çubuğunda kalır.',
    w: 896,
    h: 414,
    build: () => _worldBackdrop(
      child: const Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: EdgeInsets.fromLTRB(8, 0, 0, 66),
          child: BuildingBrief(
            type: BuildingType.beehive,
            facts: SiteFacts(flowersNear: 6, openTilesNear: 18),
            reason: null,
            noteSeed: 2,
          ),
        ),
      ),
    ),
  ),
  Shot(
    id: 'divan_seal',
    title: 'Divan Mührü + Mod Düğmeleri',
    group: 'Oyun İçi HUD',
    note: 'Hep görünür yönetişim girişi ve dünya modu düğmeleri.',
    w: 700,
    h: 300,
    build: () => _worldBackdrop(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LedgerSeal(
              onTap: _noop,
              agendaCount: 3,
              pendingPetition: true,
              bookOpen: true,
            ),
            const SizedBox(width: 22),
            LedgerSeal(
              onTap: _noop,
              agendaCount: 0,
              pendingPetition: false,
              bookOpen: false,
            ),
            const SizedBox(width: 30),
            ModeButton(
              icon: '🌾',
              label: 'Tarla',
              active: true,
              accentColor: AppUi.sage,
              onTap: _noop,
            ),
            const SizedBox(width: 10),
            ModeButton(
              icon: '🪓',
              label: 'Kes',
              active: false,
              accentColor: AppUi.accent,
              onTap: _noop,
            ),
            const SizedBox(width: 10),
            ModeButton(
              icon: '⛏',
              label: 'Kaz',
              active: false,
              accentColor: AppUi.info,
              onTap: _noop,
            ),
          ],
        ),
      ),
    ),
  ),

  // ── Paneller ────────────────────────────────────────────────────────────
  for (final (i, name) in const [(0, 'Genel'), (1, 'Kişilik'), (2, 'Öykü')])
    Shot(
      id: 'villager_tab$i',
      title: 'Köylü Paneli — $name',
      group: 'Paneller',
      w: 560,
      h: 900,
      settleMs: 1500,
      build: () => Scaffold(
        backgroundColor: AppUi.surface0,
        body: Center(
          child: SingleChildScrollView(
            child: VillagerInfoPanel(
              villager: _richVillager(),
              homeLabel: 'Konak',
              isFollowed: false,
              onClose: _noop,
              onSelect: (_) {},
              onToggleFollow: _noop,
              onToggleFavorite: _noop,
              onRename: (_) {},
              initialTab: i,
            ),
          ),
        ),
      ),
    ),
  for (final (i, name) in const [(0, 'Köylüler'), (1, 'Haneler')])
    Shot(
      id: 'roster_tab$i',
      title: 'Köy Defteri · Nüfus — $name',
      group: 'Paneller',
      note:
          'Defterin NÜFUS bölümü: sıralı köylü listesi ve hane grupları '
          '(oyunda defter çerçevesi içinde durur).',
      w: 1360,
      h: 900,
      settleMs: 2400,
      // Stack + expand ŞART: VillagerRosterView gömülebilir bir gövdedir
      // (Expanded + ListView) → SINIRLI yükseklik ister.
      build: () => Scaffold(
        backgroundColor: const Color(0xFF14171B),
        body: Stack(
          fit: StackFit.expand,
          children: [
            VillagerRosterView(
              rows: _statRows(),
              houses: _houses,
              onSelect: (_) {},
              initialTab: i,
            ),
          ],
        ),
      ),
    ),
  for (final (id, type, title) in const [
    ('building_townhall', BuildingType.townhall, 'Belediye'),
    ('building_market', BuildingType.market, 'Pazar'),
    ('building_house', BuildingType.woodenHouse, 'Ahşap Ev'),
  ])
    Shot(
      id: 'info_$id',
      title: 'Bina Paneli — $title',
      group: 'Paneller',
      w: 560,
      h: 900,
      settleMs: 1500,
      build: () {
        final b = BuildingEntity(type: type, col: 40, row: 40)
          ..isActive = true
          ..occupants = 3
          ..waterLevel = 0.62;
        final residents = [
          _mkVillager('Kemal', 'Demirhan', VillagerType.blacksmith, 7, seed: 4),
          _mkVillager('Nur', 'Demirhan', VillagerType.farmer, 12, seed: 6),
          _mkVillager('Deniz', 'Demirhan', VillagerType.farmer, 1.2, seed: 3),
        ];
        return Scaffold(
          backgroundColor: AppUi.surface0,
          body: Center(
            child: SingleChildScrollView(
              child: BuildingInfoPanel(
                building: b,
                residents: residents,
                stockpile: _stock(),
                stats: const VillageStats(
                  stockCapacity: 200,
                  morale: 0.63,
                  carrierSpeedMultiplier: 1.1,
                  wellCount: 2,
                  amenityMorale: 0.12,
                ),
                population: 24,
                populationCap: 30,
                onClose: _noop,
                onSell: (_) {},
                onFestival: _noop,
                onDemolish: _noop,
                onMove: _noop,
                onTogglePaused: _noop,
                onCollectTax: _noop,
                onRefillWater: _noop,
                onOpenDivan: _noop,
                planning: const PopulationPlanning(
                  children: 6,
                  adults: 14,
                  elders: 4,
                  couples: 5,
                  pregnantSoon: 1,
                  housedSlots: 22,
                  totalHousing: 26,
                  foodPerDay: 12.5,
                  foodStock: 74,
                ),
              ),
            ),
          ),
        );
      },
    ),

  // ── Yönetişim ───────────────────────────────────────────────────────────
  for (final (i, name) in const [
    (0, 'Divan'),
    (1, 'Kanunname'),
    (2, 'Nüfus'),
    (3, 'Tüzük'),
    (4, 'Kronik'),
  ])
    Shot(
      id: 'divan_tab$i',
      title: 'Köy Defteri — $name',
      group: 'Yönetişim',
      note:
          'Köy içi işlerin tek kapısı: divan/kanunname/nüfus/tüzük/kronik '
          'aynı çerçevede, sol rafta.',
      w: 1360,
      h: 900,
      settleMs: 2000,
      build: () => Scaffold(
        backgroundColor: const Color(0xFF1A2A20),
        body: Stack(
          fit: StackFit.expand,
          children: [
            VillageLedger(
              identity: 'Demirhan Hanesi',
              identityBonus: '★ Bereketli Köy — tarlalar %15 gürbüz büyür',
              morale: 0.63,
              population: 24,
              food: 41,
              gold: 18,
              agenda: _agenda,
              houses: _houses,
              laws: const [
                DivanFact('👨‍👩‍👧', 'Aile teşviki', AppUi.info),
                DivanFact('🕯️', 'Kutsal gün', AppUi.info),
              ],
              marks: const [
                DivanFact('🌾', 'Tarlalara iyi bakıldı', AppUi.sage),
                DivanFact('🤝', 'Komşuyla anlaşma', AppUi.sage),
              ],
              legacy: 0.09,
              onOpenPetition: _noop,
              sealed: _sealedLaws,
              lawContext: kDemoLawContext,
              lawSpotlightId: 'irrigation',
              inkDrySec: 0,
              inkDryTotalSec: 240,
              onOpenLaw: (_) {},
              rosterRows: _statRows(),
              onSelectVillager: (_) {},
              quests: _demoQuests,
              completedQuests: _demoCompletedQuests,
              charterTier: 1,
              enactedPolicies: 2,
              chronicle: _demoChronicle,
              milestoneCount: 2,
              badges: const {
                LedgerSection.divan: 3,
                LedgerSection.kanun: 5,
                LedgerSection.tuzuk: 4,
              },
              initialSection: LedgerSection.values[i],
              onClose: _noop,
            ),
          ],
        ),
      ),
    ),
  Shot(
    id: 'law_book',
    title: 'Kanunname — Altıgen Petek',
    group: 'Yönetişim',
    note: 'Merkez göbek + 6 tema yaprağı; temaya dokununca hükümler açılır.',
    w: 1000,
    h: 900,
    settleMs: 2000,
    build: () => Scaffold(
      backgroundColor: const Color(0xFF1A2A20),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: AppGildedFrame(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: LawBookView(
                  sealed: _sealedLaws,
                  ctx: kDemoLawContext,
                  spotlightId: 'irrigation',
                  inkDrySec: 0,
                  inkDryTotalSec: 240,
                  onOpenLaw: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  ),
  Shot(
    id: 'law_ritual',
    title: 'Mühür Ritüeli',
    group: 'Yönetişim',
    note: 'Ferman mühürlenirken zümreler masada; pusula ibresinin kayışı.',
    w: 920,
    h: 780,
    settleMs: 2200,
    build: () => Scaffold(
      backgroundColor: const Color(0xFF1A2A20),
      body: Stack(
        fit: StackFit.expand,
        children: [
          LawSealRitual(
            law: LawBook.byId('nizam.watch') ?? kLawBook.first,
            sealed: _sealedLaws,
            onSeal: _noop,
            onDismiss: _noop,
          ),
        ],
      ),
    ),
  ),
  Shot(
    id: 'law_compass',
    title: 'Politik Pusula',
    group: 'Yönetişim',
    note:
        'İki eksen / dört rejim; mühür öncesi "ibre nereye kayar" önizlemesi.',
    w: 560,
    h: 940,
    settleMs: 1800,
    build: () => Scaffold(
      backgroundColor: AppUi.surface1,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _label('İmececi çiftçi köyü'),
            const LawCompassCard(
              sealed: {
                'sharedHarvest',
                'winterFodder',
                'irrigation',
                'eldersExemptFromFood',
              },
              totalLaws: 30,
            ),
            const SizedBox(height: 16),
            _label('Dinî mutlakiyet'),
            const LawCompassCard(
              sealed: {
                'dergah.oneFaith',
                'dergah.penance',
                'nizam.registry',
                'nizam.sole',
              },
              totalLaws: 30,
            ),
            const SizedBox(height: 16),
            _label('Ritüel önizlemesi — kimlik değiştiren mühür'),
            const LawCompassNudge(
              sealed: {'sharedHarvest', 'winterFodder', 'irrigation'},
              lawId: 'nizam.sole',
            ),
          ],
        ),
      ),
    ),
  ),

  // ── Modallar ────────────────────────────────────────────────────────────
  for (final i in const [0, 1])
    Shot(
      id: 'petition_$i',
      title: 'Dilekçe Modalı ${i + 1}',
      group: 'Modallar',
      note: 'Birinci ağızdan metin + sahne kartı + karar seçenekleri.',
      w: 640,
      h: 940,
      settleMs: 2000,
      build: () {
        final list = _petitions();
        final p = list[i % list.length];
        return Scaffold(
          backgroundColor: const Color(0xFF14171C),
          body: PetitionModal(
            petition: p,
            state: (morale: 0.41, population: 24, food: 41, gold: 18),
            onChoose: (_) {},
            onDismiss: _noop,
          ),
        );
      },
    ),
  Shot(
    id: 'petition_scenes',
    title: 'Dilekçe Sahne Kartları',
    group: 'Modallar',
    note: 'Dilekçenin geçtiği yeri çizen prosedürel kart seti.',
    w: 1200,
    h: 700,
    build: () => Scaffold(
      backgroundColor: const Color(0xFF14171C),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: GridView.count(
          crossAxisCount: 4,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 1.6,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final s in PetitionScene.values)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: PetitionSceneCard.custom(
                        scene: s,
                        tone: PetitionTone.solemn,
                        height: 200,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    s.name,
                    textAlign: TextAlign.center,
                    style: AppUi.label.copyWith(fontSize: 9),
                  ),
                ],
              ),
          ],
        ),
      ),
    ),
  ),
  Shot(
    id: 'option_scenes',
    title: 'Karar-Eylem Sahneleri',
    group: 'Modallar',
    note: 'Her karar seçeneğinin altındaki motif kartı (bağışla/sür/idam…).',
    w: 1300,
    h: 700,
    build: () => Scaffold(
      backgroundColor: const Color(0xFF14171C),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: GridView.count(
          crossAxisCount: 4,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 1.35,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final s in OptionScene.values)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: OptionSceneCard(scene: s, height: 200),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    s.name,
                    textAlign: TextAlign.center,
                    style: AppUi.label.copyWith(fontSize: 9),
                  ),
                ],
              ),
          ],
        ),
      ),
    ),
  ),
  Shot(
    id: 'imperial_modal',
    title: 'İmparatorluk Talebi',
    group: 'Modallar',
    note: 'Pazarlık mini-oyunu: öde / pazarlık et / fidye / direniş.',
    w: 820,
    h: 940,
    settleMs: 1800,
    build: () => Scaffold(
      backgroundColor: const Color(0xFF14171C),
      body: ImperialModal(
        demand: const ImperialDemand(ImperialDemandKind.goldTax, 45),
        favor: 0.35,
        ransomCost: 30,
        canAcceptFull: true,
        canRansom: true,
        resistChance: 0.28,
        // REJİM × İMPARATORLUK — hür + köklü köyde meclis bir duruş önerir;
        // dışına çıkan seçenek "meşruiyet bedeli" rozeti taşır.
        haggleEase: 0.16,
        postureNote:
            'Ortak Ocak: bütün köy eşikte. Ama vergiye cevabı meclis verir.',
        councilVerdict: ImperialVerdict.haggle,
        councilLine: 'Meclis pazarlıktan yana — verilecekse en azı verilsin.',
        onAccept: _noop,
        onRefuse: _noop,
        onRansom: _noop,
        onHaggle: (_) {},
        onResist: _noop,
      ),
    ),
  ),
  Shot(
    id: 'event_banner',
    title: 'Olay Bandı',
    group: 'Modallar',
    w: 1000,
    h: 240,
    build: () => _worldBackdrop(
      child: EventBanner(
        event: _eventPlain(),
        timeLeft: 8,
        duration: 12,
        onClose: _noop,
      ),
    ),
  ),
  Shot(
    id: 'event_choice',
    title: 'Olay Kararı Modalı',
    group: 'Modallar',
    w: 760,
    h: 640,
    build: () => Scaffold(
      backgroundColor: const Color(0xFF14171C),
      body: EventChoiceModal(event: _eventChoice(), onChoose: (_) {}),
    ),
  ),

  // ── Geliştirici ─────────────────────────────────────────────────────────
  Shot(
    id: 'dev_panel',
    title: 'Geliştirici Paneli',
    group: 'Geliştirici',
    note: 'God mode, saat/hava, senaryolar, olay tetikleyiciler, sim hızı.',
    w: 560,
    h: 980,
    settleMs: 1600,
    build: () => Scaffold(
      backgroundColor: AppUi.surface0,
      body: DevPanel(
        godMode: true,
        rainIntensity: 0.2,
        timeOfDay: 0.34,
        villagerCount: 24,
        buildingCount: 17,
        fps: 60,
        snowOn: true,
        onToggleSnow: _noop,
        season: Season.winter,
        onJumpSeason: (_) {},
        onSeedReference: (_) {},
        onClose: _noop,
        onOpenConsole: _noop,
        onToggleGod: _noop,
        onSetRain: (_) {},
        onSetTimeOfDay: (_) {},
        onTriggerEvent: (_) {},
        onAddResource: (_, _) {},
        onSpawnVillager: _noop,
        onKillRandomVillager: _noop,
        onClearEffects: _noop,
        onNewMap: _noop,
        onWakeAll: _noop,
        onSeedLivingVillage: _noop,
        simSpeedBoost: 1,
        simHistory: const [
          SimSnapshot(
            simTime: 0,
            day: 1,
            population: 5,
            buildings: 2,
            wood: 20,
            stone: 10,
            iron: 0,
            coal: 0,
            food: 30,
            gold: 5,
          ),
          SimSnapshot(
            simTime: 600,
            day: 21,
            population: 14,
            buildings: 9,
            wood: 44,
            stone: 26,
            iron: 6,
            coal: 4,
            food: 58,
            gold: 14,
          ),
          SimSnapshot(
            simTime: 1200,
            day: 41,
            population: 24,
            buildings: 17,
            wood: 62,
            stone: 38,
            iron: 12,
            coal: 9,
            food: 74,
            gold: 26,
          ),
        ],
        onSetSimSpeed: (_) {},
        onClearSimHistory: _noop,
        activeScenario: null,
        scenarioProgress: 0,
        lastReport: null,
        onScenarioBaseline: _noop,
        onScenarioPlague: _noop,
        onScenarioDrought: _noop,
        onScenarioFire: _noop,
        onPlayMusic: _noop,
        onStartDance: _noop,
        onStartChat: _noop,
        onStartConflict: _noop,
        onIgniteFeud: _noop,
        onStartCrime: _noop,
        onClearActivities: _noop,
        onMeteorShower: _noop,
        onSeedShowcase: _noop,
        onSetDawn: _noop,
        onSetNoon: _noop,
        onSetDusk: _noop,
        onSetNight: _noop,
        onToggleRain: _noop,
        onAllPolicies: _noop,
        onClearPolicies: _noop,
        onUnlockAllCrafts: _noop,
        onMakeSage: _noop,
        onSpawnMigrant: _noop,
        onSummonImperial: _noop,
        onForcePetition: _noop,
        onForcePetitionShortFuse: _noop,
        onForcePetitionAudience: _noop,
        petitions: const [
          ('fireDied', 'Ateş söndü'),
          ('crimeVerdict', 'Yargı'),
          ('switchProfession', 'Meslek değişimi'),
        ],
        onForcePetitionId: (_) {},
        perfMode: false,
        onTogglePerf: _noop,
        devLogOn: true,
        onToggleDevLog: _noop,
      ),
    ),
  ),

  Shot(
    id: 'dev_console',
    title: 'Dev Konsolu (`)',
    group: 'Geliştirici',
    note: 'Quake-style komut arama + parametre formu + senaryo kayıt/oynat.',
    w: 900,
    h: 760,
    settleMs: 1600,
    build: () {
      final rec = DevRecorder();
      final cmds = <DevCommand>[
        DevCommand(
          id: 'spawnVillager',
          label: 'Köylü doğur',
          hint: 'Belirtilen sayıda yetişkin köye katılır',
          category: DevCat.nufus,
          params: const [DevParam.integer('n', 'Adet', intDefault: 3)],
          run: (_) {},
        ),
        DevCommand(
          id: 'summonImperial',
          label: 'İmparatorluğu çağır',
          hint: 'Vergici heyet harita kenarından yürüyerek gelir',
          category: DevCat.olay,
          run: (_) {},
        ),
        DevCommand(
          id: 'forcePetition',
          label: 'Dilekçe zorla',
          hint: 'Sıradaki dilekçeyi hemen sun',
          category: DevCat.yonetisim,
          run: (_) {},
        ),
        DevCommand(
          id: 'setSeason',
          label: 'Mevsimi ayarla',
          category: DevCat.zaman,
          run: (_) {},
        ),
        DevCommand(
          id: 'addResource',
          label: 'Kaynak ekle',
          hint: 'Ambara istediğin kadar mal yaz',
          category: DevCat.ekonomi,
          run: (_) {},
        ),
        DevCommand(
          id: 'seedShowcase',
          label: 'Showcase köyü kur',
          hint: 'Depo + ağıl + sürü + muhafızla dolu köy',
          category: DevCat.koy,
          run: (_) {},
        ),
      ];
      return Scaffold(
        backgroundColor: AppUi.surface0,
        body: Stack(
          fit: StackFit.expand,
          children: [
            _worldBackdrop(),
            DevConsole(
              commands: cmds,
              recorder: rec,
              scripts: const [
                DevScript('Kış + kıtlık', [], builtin: true),
                DevScript('İmparatorluk baskını', []),
              ],
              onRun: (_, _) {},
              onRunScript: (_) {},
              onSaveScript: (_) {},
              onDeleteScript: (_) {},
              onClose: _noop,
            ),
          ],
        ),
      );
    },
  ),

  // ── Tasarım sistemi ─────────────────────────────────────────────────────
  Shot(
    id: 'design_system',
    title: 'Tasarım Sistemi — app_ui Bileşenleri',
    group: 'Tasarım Sistemi',
    note:
        'Panel, buton türleri, çip, istatistik çubuğu, sekme, yaldızlı çerçeve.',
    w: 1100,
    h: 940,
    build: () => const _DesignSheet(),
  ),
  Shot(
    id: 'icons',
    title: 'İkon Seti — GameIconData',
    group: 'Tasarım Sistemi',
    note: 'Vektörel HUD ikonlarının tamamı.',
    w: 1100,
    h: 700,
    build: () => const _IconSheet(),
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Tasarım sistemi sayfaları
// ─────────────────────────────────────────────────────────────────────────────

class _DesignSheet extends StatelessWidget {
  const _DesignSheet();

  @override
  Widget build(BuildContext context) {
    Widget swatch(String name, Color c) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 40,
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppUi.line),
          ),
        ),
        const SizedBox(height: 4),
        Text(name, style: AppUi.label.copyWith(fontSize: 8)),
      ],
    );

    return Scaffold(
      backgroundColor: AppUi.surface0,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('KÖY SİMÜLASYONU — ARAYÜZ DİLİ', style: AppUi.display),
            const SizedBox(height: 4),
            Text(
              'Cinzel başlık / Spectral gövde, soğuk grafit yüzey + ember vurgu',
              style: AppUi.body,
            ),
            const AppDivider(),
            const AppSectionLabel('Renk'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                swatch('surface0', AppUi.surface0),
                swatch('surface1', AppUi.surface1),
                swatch('surface2', AppUi.surface2),
                swatch('surface3', AppUi.surface3),
                swatch('line', AppUi.line),
                swatch('accent', AppUi.accent),
                swatch('accentSoft', AppUi.accentSoft),
                swatch('accentDeep', AppUi.accentDeep),
                swatch('sage', AppUi.sage),
                swatch('rust', AppUi.rust),
                swatch('gold', AppUi.gold),
                swatch('info', AppUi.info),
              ],
            ),
            const AppDivider(),
            const AppSectionLabel('Butonlar'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: const [
                AppButton(
                  label: 'Mühürle',
                  icon: GameIconData.scroll,
                  kind: AppButtonKind.filled,
                ),
                AppButton(
                  label: 'Meclisi Topla',
                  icon: GameIconData.people,
                  kind: AppButtonKind.tonal,
                ),
                AppButton(label: 'Vazgeç', kind: AppButtonKind.ghost),
                AppButton(
                  label: 'Yık',
                  icon: GameIconData.demolish,
                  kind: AppButtonKind.danger,
                ),
                AppButton(
                  label: 'Şölen Ver',
                  sub: '8 yiyecek · 5 altın',
                  icon: GameIconData.festival,
                  kind: AppButtonKind.tonal,
                ),
                AppIconButton(icon: GameIconData.pause, active: false),
                AppIconButton(icon: GameIconData.play, active: true),
                AppIconButton(icon: GameIconData.speed, text: '2×'),
              ],
            ),
            const AppDivider(),
            const AppSectionLabel('Çipler ve Göstergeler'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                AppChip(
                  label: 'Bereketli',
                  icon: GameIconData.wheat,
                  color: AppUi.sage,
                ),
                AppChip(
                  label: 'Kıtlık',
                  icon: GameIconData.warehouse,
                  color: AppUi.rust,
                ),
                AppChip(
                  label: 'Ticaret',
                  icon: GameIconData.coin,
                  color: AppUi.gold,
                  solid: true,
                ),
                AppChip(
                  label: 'Yağmur',
                  icon: GameIconData.rain,
                  color: AppUi.info,
                ),
              ],
            ),
            const SizedBox(height: 14),
            const AppStatBar(
              label: 'Moral',
              value: 0.63,
              trailing: '%63',
              color: AppUi.accent,
            ),
            const SizedBox(height: 6),
            const AppStatBar(
              label: 'Ambar',
              value: 0.37,
              trailing: '74/200',
              color: AppUi.sage,
            ),
            const SizedBox(height: 6),
            const AppStatBar(
              label: 'Su',
              value: 0.18,
              trailing: 'az',
              color: AppUi.info,
            ),
            const AppDivider(),
            const AppSectionLabel('Panel · Sekme · Yaldızlı Çerçeve'),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppPanel(
                    child: AppTabs(
                      tabs: [
                        (
                          'GENEL',
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Text(
                              'Sekmeli panel gövdesi. Yoğun panellerde ortak AppTabs '
                              'kullanılır; başlık büyük harf, gövde Spectral.',
                              style: AppUi.body,
                            ),
                          ),
                        ),
                        ('KİŞİLİK', const SizedBox(height: 60)),
                        ('ÖYKÜ', const SizedBox(height: 60)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: AppGildedFrame(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('FERMAN', style: AppUi.title),
                          const SizedBox(height: 6),
                          Text(
                            'Yaldızlı çerçeve yalnız yönetişim yüzeylerinde: '
                            'Kanunname, Divan ve mühür ritüeli.',
                            style: AppUi.body,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _IconSheet extends StatelessWidget {
  const _IconSheet();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUi.surface0,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('İKON SETİ', style: AppUi.display),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.count(
                crossAxisCount: 10,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.05,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final i in GameIconData.values)
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GameIcon(i, size: 26, color: AppUi.textHi),
                        const SizedBox(height: 6),
                        Text(
                          i.name,
                          textAlign: TextAlign.center,
                          style: AppUi.label.copyWith(fontSize: 8),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Galeri sürücüsü
// ─────────────────────────────────────────────────────────────────────────────

final GlobalKey _boundary = GlobalKey();
final GlobalKey<_GalleryState> _gallery = GlobalKey<_GalleryState>();

class _Gallery extends StatefulWidget {
  final List<Shot> shots;
  const _Gallery({super.key, required this.shots});
  @override
  State<_Gallery> createState() => _GalleryState();
}

/// REFERANS CİHAZ — mobil tasarım önce buna göre kurulur (bkz. PHONE env).
/// iPhone 11 yatay: 896×414 dp, çentik yanlarda 44dp, alt çubuk 21dp.
final bool kPhoneMode = (Platform.environment['PHONE'] ?? '').isNotEmpty;
const Size kPhoneSize = Size(896, 414);
const EdgeInsets kPhoneSafe = EdgeInsets.only(left: 44, right: 44, bottom: 21);

class _GalleryState extends State<_Gallery> {
  int _i = 0;
  void show(int i) => setState(() => _i = i);

  @override
  Widget build(BuildContext context) {
    final s = widget.shots[_i];
    Widget child;
    try {
      child = s.build();
    } catch (e, st) {
      stdout.writeln('SHOT_BUILD_FAIL: ${s.id}: $e\n$st');
      child = ColoredBox(
        color: const Color(0xFF2A1414),
        child: Center(
          child: Text(
            '${s.id} kurulamadı\n$e',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
      );
    }
    return ColoredBox(
      color: const Color(0xFF07080A),
      child: Center(
        // Mantıksal ölçüde layout, ekrana sığdırmak için küçültme — capture
        // boundary'nin kendi katmanından okunur, bu scale çıktıya girmez.
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: kPhoneMode ? kPhoneSize.width : s.w,
            height: kPhoneMode ? kPhoneSize.height : s.h,
            child: MediaQuery(
              data: MediaQueryData(
                size: kPhoneMode ? kPhoneSize : Size(s.w, s.h),
                devicePixelRatio: 1,
                padding: kPhoneMode ? kPhoneSafe : EdgeInsets.zero,
                viewPadding: kPhoneMode ? kPhoneSafe : EdgeInsets.zero,
                textScaler: TextScaler.noScaling,
                platformBrightness: Brightness.dark,
              ),
              child: RepaintBoundary(
                key: _boundary,
                // Telefon modunda mobil yazı tabanı da devrede olmalı —
                // oyunda ağacın kökünde uygulanıyor (bkz. main.dart).
                //
                // Stack ŞART: telefon dalına düşen paneller (villager/bina)
                // [MobileSheet] döndürür, o da bir Positioned'dır. Stack'siz
                // ağaçta layout patlar ve kare SİYAH çıkar — oyunda bu paneller
                // zaten sahnenin Stack'i içindedir (bkz. main.dart).
                child: MobileTextFloor(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [KeyedSubtree(key: ValueKey(s.id), child: child)],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Görsel hata (border assert, taşma vb.) sessizce yutulmasın — "panel
  // çizilmedi" bug'larının çoğu burada yakalanır.
  FlutterError.onError = (d) => stdout.writeln('FLUTTER_ERROR: ${d.exception}');

  // Animasyonlu meter'ları statik çiz — TweenAnimationBuilder'ın controller'ı
  // zorlanmış kare saatiyle assert atıp bina panelini SİYAH bırakıyordu.
  AppUi.captureStatic = true;

  // Bina thumbnail'larını yükle — yoksa İnşa Paleti tüm binaları jenerik ev
  // ikonuyla gösterir (oyunda gerçek sprite thumbnail'ları çizilir). PNG'si
  // olmayan bina zaten oyunda da jenerik kalır → önizleme sadık olur.
  await BuildingRenderer.loadAll();

  final all = buildShots();
  final only = (Platform.environment['ONLY'] ?? '')
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toSet();
  final shots = only.isEmpty
      ? all
      : all.where((s) => only.contains(s.id)).toList();

  final outPath = Platform.environment['OUT'] ?? 'preview/ui';
  final outDir = Directory(outPath)..createSync(recursive: true);

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _Gallery(key: _gallery, shots: shots),
    ),
  );

  // İlk kare + font yüklemesi otursun.
  await _settle(900);

  final captured = <String>{};
  String? prevHash;
  for (int i = 0; i < shots.length; i++) {
    final s = shots[i];
    _gallery.currentState!.show(i);
    await _settle(s.settleMs);
    var bytes = await _grab(s);
    // Aynı kare iki kez → sahne yeniden çizilmemiş (pencere arkada kaldıysa
    // macOS kare üretmez). Zorla birkaç kare daha pompalayıp tekrar dene.
    var hash = bytes == null ? null : _hash(bytes);
    if (hash != null && hash == prevHash) {
      await _settle(s.settleMs);
      bytes = await _grab(s);
      hash = bytes == null ? null : _hash(bytes);
    }
    final stale = hash != null && hash == prevHash;
    final ok = bytes != null && !stale;
    if (bytes != null) {
      File('${outDir.path}/${s.id}.png').writeAsBytesSync(bytes);
      prevHash = hash;
    }
    stdout.writeln(
      '[${i + 1}/${shots.length}] '
      '${ok ? 'OK  ' : (stale ? 'STALE' : 'FAIL')} ${s.id}',
    );
    if (ok) captured.add(s.id);
  }

  // Manifest TÜM yüzey listesinden yazılır (yalnız diskte PNG'si olanlar).
  // ONLY ile tek yüzey tazelendiğinde galeri geri kalanını kaybetmesin diye.
  final manifest = [
    for (final s in all)
      if (File('${outDir.path}/${s.id}.png').existsSync())
        {
          'id': s.id,
          'title': s.title,
          'group': s.group,
          'note': s.note,
          'file': '${s.id}.png',
          'w': s.w,
          'h': s.h,
        },
  ];
  File(
    '${outDir.path}/manifest.json',
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(manifest));
  stdout.writeln(
    'GALLERY_DONE: ${captured.length}/${shots.length} çekildi, '
    'manifest ${manifest.length} yüzey → ${outDir.path}',
  );
  exit(0);
}

/// Uygulama açılışından beri geçen süre — pompalanan karelere motorunkine yakın
/// bir zaman damgası vermek için (ticker'lar geriye giden zamanla bozulmasın).
final Stopwatch _clock = Stopwatch()..start();

/// Kareyi ELDE zorlar. macOS'ta pencere ön planda değilken motor kare üretmez;
/// o zaman setState hiç boyanmaz ve capture bir öncekinin aynısını verir
/// (bütün galeri "ana menü" çıkar). handleBeginFrame/handleDrawFrame ikilisi
/// build+layout+paint hattını odaktan bağımsız çalıştırır; animasyon ticker'ları
/// da bu sayede ilerler.
Future<void> _settle(int ms) async {
  final steps = (ms / 16).ceil();
  for (int i = 0; i < steps; i++) {
    // Gerçek zaman da geçmeli: asset yükleme / FutureBuilder gibi async işler
    // yalnızca kare pompalayarak tamamlanmaz.
    await Future<void>.delayed(const Duration(milliseconds: 16));
    final b = WidgetsBinding.instance;
    if (b.schedulerPhase == SchedulerPhase.idle) {
      b.handleBeginFrame(_clock.elapsed);
      b.handleDrawFrame();
    }
  }
}

String _hash(Uint8List bytes) {
  // Ucuz içerik parmak izi — bayat kare tespiti için yeterli (kriptografik değil).
  var h = 0x811c9dc5;
  for (int i = 0; i < bytes.length; i += 97) {
    h = (h ^ bytes[i]) * 0x01000193 & 0xFFFFFFFF;
  }
  return '${bytes.length}:$h';
}

Future<Uint8List?> _grab(Shot s) async {
  final ctx = _boundary.currentContext;
  if (ctx == null) {
    stdout.writeln('CAPTURE_FAIL: no context (${s.id})');
    return null;
  }
  try {
    final b = ctx.findRenderObject() as RenderRepaintBoundary;
    final img = await b.toImage(pixelRatio: 2.0);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();
    return bytes?.buffer.asUint8List();
  } catch (e) {
    stdout.writeln('CAPTURE_FAIL: ${s.id}: $e');
    return null;
  }
}

/// Künye shot'ı için iki gerçek köylü sprite'ı — künyenin sahnenin ÜSTÜNDE
/// değil, sahneye AİT durduğu ancak gerçek gövdeyle görülür.
class _TagDemoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    void body(double x, double y, VillagerType t, double phase) {
      canvas.save();
      canvas.translate(x, y);
      canvas.scale(1.7);
      CharacterRenderer.draw(canvas, t, walkPhase: phase, moveIntensity: 0.85);
      canvas.restore();
    }

    body(250, 330, VillagerType.farmer, 1.2);
    body(560, 330, VillagerType.miner, 3.4);
    // Mezar taşı yerine sade bir höyük — künyenin nötr rengini denemek için.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(806, 316, 48, 26),
        const Radius.circular(12),
      ),
      Paint()..color = const Color(0xFF3A4038),
    );
  }

  @override
  bool shouldRepaint(_TagDemoPainter old) => false;
}
