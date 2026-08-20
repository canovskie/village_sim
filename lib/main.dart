// ═══════════════════════════════════════════════════════════════════════════
//  KÖY SİMÜLASYONU — HARİTA
//
//  main.dart tek bir devasa dosya DEĞİL: `VillageScene` durumunu paylaşan 43
//  part'ın çatısı. "Bu iş nerede yaşıyor?" sorusunun cevabı aşağıdadır. Yeni
//  bir sistem eklerken buraya BİR SATIR ekle — haritasız kalan kod, takip
//  edilemeyen koddur.
//
//  ── DÜNYA & DÖNGÜ ─────────────────────────────────────────────────────────
//   scene_world          dünya kurulumu + uzamsal sorgular + nüfus sayımları
//   scene_tick           ana döngü: her sistemin sırayla sürüldüğü yer
//   scene_land           arazi/reveal (ZOOM KISITI modeli)
//   scene_save           tam dünya kayıt/yükleme (JSON, indeks-bazlı referans)
//
//  ── OYUNCUNUN ELİ ─────────────────────────────────────────────────────────
//   scene_input          pointer/gesture; scene_placement  bina+alan+yol koyma
//   scene_ui             build() ve panel/HUD çizimi (SADECE widget)
//   scene_divan          Köy Defteri — köy içi her şeyin tek kapısı
//   scene_dev_console    geliştirici komutları; scene_scenarios denge testleri
//
//  ── KÖYLÜNÜN İÇİ (canlı köy omurgası) ─────────────────────────────────────
//   scene_mind           dürtü → teklif → niyet hakemi (TEK karar otoritesi)
//   scene_perception     köylüler birbirini görür; scene_act niyeti eyleme çevirir
//   scene_npc_routine    amaçlı gündelik gidiş-gelişler
//   scene_npc_activity   sohbet/müzik/dans; scene_reactions gövde dili yankısı
//   scene_pressure       KÖYÜN HÂLİ tablosunu köylülere işler (yasa → gövde)
//   scene_personality    kişisel anlar (yıldönümü, çağrı)
//
//  ── EMEK ──────────────────────────────────────────────────────────────────
//   scene_jobs           bina-doğumlu işler (inşaat/tarla/maden/kesim/çobanlık)
//   scene_work           sivil meslek döngüleri (değirmenci/hancı/rahip/avcı)
//   scene_craft          zanaatın doğuşu/kaybı; scene_reed evsizin geçimi
//   scene_fire           ateşin yakıtı; scene_firepit_gather akşam toplanması
//   scene_shelter        çadır ↔ ocak mesafesi: kışın üşüyen çadır, gece uyanma
//
//  ── YÖNETİŞİM ─────────────────────────────────────────────────────────────
//   scene_law            KANUNNAME: kapılar + mühür + günlük idame
//   scene_petitions      dilekçe/meclis + karar motoru (_applyDecisionEffects)
//   scene_regime         pusula → rejim kimliği; scene_estates hane/zümre dengesi
//   scene_house_actions  oyuncunun hanelere proaktif müdahalesi
//
//  ── KOŞUNUN YAYI (başı ve sonu) ───────────────────────────────────────────
//   scene_flow           görev akışı + Tüzük kademesi (merdivenin kendisi)
//   scene_guide          KURULUŞ öğreticisi — parmakla gösteren spot
//   scene_lessons        ORTA OYUN dersleri — sonradan açılan sistemlerin kartı
//   scene_collapse       kaybetme eşiği: ayrılık → köy dağılır
//   scene_reckoning      HESAPLAŞMA: 6. yılda sancak/berat/ilhak, koşu biter
//   (eskalasyonun tek kaynağı systems/village_year.dart — sistemler kendi
//    içinde "gün N'den sonra" DEMEZ, oradan okur)
//
//  ── OLAYLAR & HİKÂYE ──────────────────────────────────────────────────────
//   scene_events         rastgele olay + fx; scene_imperial dış tehdit
//   scene_vignette       olayın DÜNYADAKİ sahnesi: roller + adımlar ("İzle")
//   scene_crime          suç evreleri; scene_conflict çekişme/kan davası
//   scene_illness        hastalık/salgın; scene_funeral cenaze; scene_wedding düğün
//   scene_merchant       gezgin tüccar (görev akışı için bkz. KOŞUNUN YAYI)
//   scene_chronicle      vakanüvis (kalıcı günce + başarımlar; her satırın bir
//                        TÜRÜ var → defterin süzgeci ui/chronicle_filter)
//   scene_voice          sahnenin metin ağzı (tüm oyuncu-yüzü cümleler)
//
//  ── TEST YATAKLARI ────────────────────────────────────────────────────────
//   scene_probe          köyün yaşadığının SAYIYLA kanıtı (headless prova)
//   scene_reference_village  sabit tohumlu ortak test köyü
//
//  NOT: sistemlerin SAF çekirdekleri lib/systems ve lib/entities altındadır
//  (law_book, petition_system, world_pressure, villager_mind…). scene_* onları
//  köye BAĞLAR; saf mantık oraya değil, systems/ altına yazılır — testi orada.
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'buildings/building_entity.dart';
import 'buildings/building_function.dart';
import 'buildings/building_lore.dart';
import 'buildings/building_renderer.dart';
import 'buildings/building_type.dart';
import 'buildings/craft.dart';
import 'characters/life_stage.dart';
import 'characters/npc_visual.dart';
import 'characters/personality.dart';
import 'characters/villager_names.dart';
import 'characters/villager_type.dart';
import 'core/constants.dart';
import 'core/resources.dart';
import 'cutscene/cutscene.dart';
import 'cutscene/cutscene_player.dart';
import 'dev/animation_room.dart';
import 'dev/dev_command.dart';
import 'dev/dev_console.dart';
import 'dev/dev_script_store.dart';
import 'entities/build_order.dart';
import 'entities/imperial_soldier.dart';
import 'entities/merchant_entity.dart';
import 'entities/road_order.dart';
import 'entities/villager_entity.dart';
import 'entities/villager_job.dart';
import 'entities/work_site.dart';
import 'entities/worker_entity.dart';
import 'farm/farm_renderer.dart';
import 'farm/farm_tile.dart';
import 'rendering/animal_renderer.dart';
import 'rendering/decor_renderer.dart';
import 'rendering/flame_renderer.dart';
import 'rendering/game_painter.dart';
import 'rendering/grave_renderer.dart';
import 'rendering/ground_weather_renderer.dart';
import 'rendering/mine_renderer.dart';
import 'rendering/mud_renderer.dart';
import 'rendering/nature_renderer.dart';
import 'rendering/prop_renderer.dart';
import 'rendering/reed_bed_renderer.dart';
import 'rendering/resource_renderer.dart';
import 'rendering/road_renderer.dart';
import 'rendering/smoke_renderer.dart';
import 'rendering/snow_ground_renderer.dart';
import 'rendering/tile_renderer.dart';
import 'rendering/tool_renderer.dart';
import 'rendering/tree_renderer.dart';
import 'save/save_manager.dart';
import 'scene/scene_data.dart';
import 'systems/anchor_system.dart';
import 'systems/audio_manager.dart';
import 'systems/building_system.dart';
import 'systems/carrier_system.dart';
import 'systems/chronicle.dart';
import 'systems/crime_system.dart';
import 'systems/decision_pacing.dart';
import 'systems/estate_system.dart';
import 'systems/event_system.dart';
import 'systems/founding_choice.dart';
import 'systems/hay_processor.dart';
import 'systems/hearth_warmth.dart';
import 'systems/house_action.dart';
import 'systems/house_head.dart';
import 'systems/house_stance.dart';
import 'systems/house_system.dart';
import 'systems/imperial.dart';
import 'systems/law_book.dart';
import 'systems/law_compass.dart';
import 'systems/lighting_system.dart';
import 'systems/path_context.dart';
import 'systems/petition_system.dart';
import 'systems/platform_adapt.dart';
import 'systems/quest_book.dart';
import 'systems/reckoning.dart';
import 'systems/regime.dart';
import 'systems/road_route.dart';
import 'systems/road_system.dart';
import 'systems/separation_system.dart';
import 'systems/village_collapse.dart';
import 'systems/village_custom.dart';
import 'systems/village_lessons.dart';
import 'systems/village_year.dart';
import 'systems/villager_act.dart';
import 'systems/villager_memory.dart';
import 'systems/villager_mind.dart';
import 'systems/villager_morale.dart';
import 'systems/winter.dart';
import 'systems/world_pressure.dart';
import 'text/village_names.dart';
import 'text/voice.dart';
import 'ui/app_ui.dart';
import 'ui/building_brief.dart';
import 'ui/building_info_panel.dart';
import 'ui/building_panel.dart';
import 'ui/collapse_screen.dart';
import 'ui/command_bar.dart';
import 'ui/dev_panel.dart';
import 'ui/event_banner.dart';
import 'ui/event_choice_modal.dart';
import 'ui/guide_spotlight.dart';
import 'ui/hud.dart';
import 'ui/imperial_modal.dart';
import 'ui/law_book_panel.dart';
import 'ui/lesson_card.dart';
import 'ui/loading_screen.dart';
import 'ui/main_menu_screen.dart';
import 'ui/mobile_ui.dart';
import 'ui/mode_button.dart';
import 'ui/objective_panel.dart';
import 'ui/petition_modal.dart';
import 'ui/reckoning_screen.dart';
import 'ui/road_panel.dart';
import 'ui/save_slots_screen.dart';
import 'ui/settings_model.dart';
import 'ui/village_ledger.dart';
import 'ui/villager_info_panel.dart';
import 'ui/villager_roster_view.dart';
import 'ui/work_site_panel.dart';
import 'ui/world_tag.dart';
import 'world/animal_entity.dart';
import 'world/bee_flock.dart';
import 'world/bird_flock.dart';
import 'world/day_night_cycle.dart';
import 'world/decor_entity.dart';
import 'world/egg_entity.dart';
import 'world/grave.dart';
import 'world/hay_entity.dart';
import 'world/land_expansion.dart';
import 'world/leaf_burst.dart';
import 'world/loot_cache.dart';
import 'world/mine_node.dart';
import 'world/nature_entity.dart';
import 'world/reed_bed.dart';
import 'world/reference_village_plan.dart';
import 'world/resource_box.dart';
import 'world/resource_placement.dart';
import 'world/road_surface.dart';
import 'world/road_tile.dart';
import 'world/season.dart';
import 'world/tree_entity.dart';
import 'world/world_generator.dart';

part 'scene/scene_act.dart';
part 'scene/scene_building_spawn.dart';
part 'scene/scene_collapse.dart';
part 'scene/scene_chronicle.dart';
part 'scene/scene_conflict.dart';
part 'scene/scene_craft.dart';
part 'scene/scene_crime.dart';
part 'scene/scene_custom.dart';
part 'scene/scene_decision_pacing.dart';
part 'scene/scene_dev_console.dart';
part 'scene/scene_divan.dart';
part 'scene/scene_estates.dart';
part 'scene/scene_events.dart';
part 'scene/scene_fire.dart';
part 'scene/scene_firepit_gather.dart';
part 'scene/scene_flow.dart';
part 'scene/scene_forage.dart';
part 'scene/scene_funeral.dart';
part 'scene/scene_guide.dart';
part 'scene/scene_house_actions.dart';
part 'scene/scene_house_stance.dart';
part 'scene/scene_illness.dart';
part 'scene/scene_imperial.dart';
part 'scene/scene_input.dart';
part 'scene/scene_jobs.dart';
part 'scene/scene_land.dart';
part 'scene/scene_law.dart';
part 'scene/scene_lessons.dart';
part 'scene/scene_loot.dart';
part 'scene/scene_merchant.dart';
part 'scene/scene_mind.dart';
part 'scene/scene_npc_activity.dart';
part 'scene/scene_npc_routine.dart';
part 'scene/scene_perception.dart';
part 'scene/scene_personality.dart';
part 'scene/scene_petitions.dart';
part 'scene/scene_placement.dart';
part 'scene/scene_pressure.dart';
part 'scene/scene_probe.dart';
part 'scene/scene_reactions.dart';
part 'scene/scene_reckoning.dart';
part 'scene/scene_reed.dart';
part 'scene/scene_reference_village.dart';
part 'scene/scene_regime.dart';
part 'scene/scene_save.dart';
// `_VillageSceneState` part-of bölmeleri — her dosya konsept bazında bir
// alan (yerleştirme, tick döngüsü, world helper'ları, UI, vs).
part 'scene/scene_scenarios.dart';
part 'scene/scene_shelter.dart';
part 'scene/scene_tick.dart';
part 'scene/scene_ui.dart';
part 'scene/scene_ui_panels.dart';
part 'scene/scene_ui_overlays.dart';
part 'scene/scene_vignette.dart';
part 'scene/scene_voice.dart';
part 'scene/scene_wedding.dart';
part 'scene/scene_winter.dart';
part 'scene/scene_work.dart';
part 'scene/scene_work_sites.dart';
part 'scene/scene_world.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Mobilde: yatay kilit + tam ekran + kenardan kenara (bkz. PlatformAdapt).
  // Masaüstünde no-op.
  await PlatformAdapt.applyMobileChrome();
  // Kullanıcı tercihleri (ses/sarsıntı/dil) diskten — runApp'ten ÖNCE, yoksa
  // ilk kare varsayılan seviyeyle çalar ve sessize almış oyuncu bir "pat"
  // duyar. Okuma başarısız olursa varsayılanlarda kalır, açılış engellenmez.
  await SettingsModel.instance.load();
  runApp(const VillageSimApp());
}

class VillageSimApp extends StatelessWidget {
  const VillageSimApp({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(
    title: 'Luw',
    debugShowCheckedModeBanner: false,
    home: _AppRoot(),
  );
}

/// Ana menüden oyuna ve geri geçişi yöneten kök widget.
/// Sahne değişimini state ile yapıyoruz; böylece oyundan çıkış doğrudan
/// menüye döner ve oyun durumu yeni başladığında temiz olur.
class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  bool _inGame = false;
  int _gameKey = 0; // Her yeni oyun için VillageScene'i yeniden oluşturur

  // Aktif oyunun slot kimliği + adı + (varsa) yüklenecek dünya. _loadWorld
  // null ise taze köy üretilir; doluysa o slottan kaldığı yerden devam edilir.
  Map<String, dynamic>? _loadWorld;
  String _slotId = '';
  String _slotName = 'Köy';

  /// Bu oturum referans köy mü (sabit test zemini) — bkz. scene_reference_village.
  bool _reference = false;

  void _startNew() {
    setState(() {
      _loadWorld = null;
      _reference = false;
      _slotId = SaveManager.instance.newSlotId();
      _slotName = 'Köy';
      _inGame = true;
      _gameKey++;
    });
  }

  /// Referans köy — testlerin ortak zemini. Her girişte SIFIRDAN, birebir aynı
  /// kurulur ve sabit slota ([kReferenceSlotId]) yazılır; yani o slottaki önceki
  /// oturum tazelenir. Kaldığı yerden devam istenirse Kayıtlı Köyler'den açılır
  /// (o zaman normal bir kayıt gibi davranır, yeniden kurulmaz).
  void _startReference() {
    setState(() {
      _loadWorld = null;
      _reference = true;
      _slotId = kReferenceSlotId;
      _slotName = kReferenceSlotName;
      _inGame = true;
      _gameKey++;
    });
  }

  Future<void> _continue(SaveSlotMeta meta) async {
    final data = await SaveManager.instance.readSlot(meta.id);
    final world = data?['world'];
    if (world is! Map) {
      _startNew();
      return;
    }
    if (!mounted) return;
    setState(() {
      _loadWorld = Map<String, dynamic>.from(world);
      _reference = false; // kayıttan devam → yeniden kurma, olduğu gibi yükle
      _slotId = meta.id;
      _slotName = meta.name;
      _inGame = true;
      _gameKey++;
    });
  }

  void _exitGame() => setState(() => _inGame = false);

  @override
  Widget build(BuildContext context) {
    if (_inGame) {
      return VillageScene(
        key: ValueKey(_gameKey),
        onExitToMenu: _exitGame,
        initialWorld: _loadWorld,
        slotId: _slotId,
        slotName: _slotName,
        referenceVillage: _reference,
      );
    }
    return MainMenuScreen(
      onNewGame: _startNew,
      onContinue: _continue,
      onReferenceVillage: _startReference,
    );
  }
}

// ─── MAIN SCENE ──────────────────────────────────────────────────────────────

/// Debug/capture hook: true iken yeni oyun açılış sinematiğini + ateş-yerleştirme
/// modunu atlar, sim doğrudan akar (scene_capture_main.dart bunu set eder).
bool kCaptureMode = false;
double kCaptureZoom = 1.0;
int kCaptureCarve =
    0; // capture: başlangıçta bu kadar halka ön-hattı "oy" (kütük/recede demo)
bool kCaptureSceneReady =
    false; // asset yüklenip sahne hazır olunca true (harness bekler)
/// capture: günün vaktini DONDUR (0..1; negatif = kapalı, saat normal akar).
/// Işıklandırma gibi vakte bağlı katmanların "önce/sonra" karşılaştırmasını
/// yapabilmek için şart: iki kare farklı saatte çekilirse fark ölçülemez.
double kCaptureTimeOfDay = -1;

/// capture: referans köy hangi MEVSİMDE kurulsun (bkz. kReferenceDayFor).
/// Kışın çadır/yakıt/tarla davranışını çekmek için harness'ın köyü yazın kurup
/// takvimi elle sarmasına gerek kalmasın — köy doğrudan o mevsimde doğar.
Season kCaptureReferenceSeason = kReferenceBaseSeason;

/// capture/teşhis: akış tik'inin nabzı. `_tickFlow` her taramada yazar —
/// harness kareyi çekmeden önce okur. "Adım şeridi bazen hiç görünmüyor"
/// şikâyetinde ilk soru şudur: tarama koştu mu, koştuysa ne buldu?
String kFlowDebug = '';

/// capture/teşhis: sim'i DURDURAN modalın adı ('' = akıyor). Harness'te
/// "köy neden ilerlemedi" sorusunun tek satırlık cevabı — donmuş bir sahnede
/// kFlowDebug artık güncellenmediği için son değeri yalan söyler.
String kProbePause = '';
bool kCaptureShowcase =
    false; // capture: showcase köyünü kur (meslek iş döngüsü testi)
/// capture: iş döngüsü telemetrisi — harness bunu okuyup davranışı doğrular.
String kCaptureWorkReport = '';

/// capture: suç test yatağı — suç yoksa sürekli yenisini zorlar (olasılık kapısı
/// atlanır) ki bütün evreler (sokulma/eylem/kaçış/yakalanma) gözlenebilsin.
bool kCaptureCrime = false;

/// capture: suç telemetrisi — harness evreleri + muhafız tepkisini buradan okur.
String kCaptureCrimeReport = '';

/// capture: yalnız BU suçu tetikle (null = rastgele) — riskli yolları hedefli test et.
CrimeKind? kCaptureCrimeKind;

/// capture: İmparatorluk varış anonsunu (buildImperialAlert) sahne hazır olunca
/// bir kez tetikle → tasarımı harness'te görsel doğrulamak için.
bool kCaptureImperialAlert = false;

/// capture: muhafızları devre dışı bırak — suçun TAMAMLANIP kaçmasını gözle
/// (kaçış → şüphe → asayiş dilekçesi zinciri muhafızlı köyde hiç tetiklenmez).
bool kCaptureNoGuard = false;

/// capture: NİZAM kolunu baştan mühürle — Kürek Cezası hükmü + Hane Sicili
/// (meçhul suç yok) sim'de gerçekten yürüyor mu doğrula.
bool kCaptureSealNizam = false;

/// PROVA: köyün davranış özeti — harness ([living_probe_main]) her aralıkta
/// buraya yazılan raporu stdout'a basar. "Tek tek NPC izleyemem" sorununun
/// cevabı: köyün yaşadığı sayıyla görülür.
bool kProbeOn = false;
String kProbeReport = '';
int kProbeReportSeq = 0; // her yeni raporda artar (harness "yeni mi" anlar)
/// Harness sim hızını buradan yükseltir (0 = dokunma, normal oyun hızı).
/// Sahne her tick bunu okur; DevPanel slider'ı yerine geçmez, onunla çarpışmaz.
double kDevSpeedBoostOverride = 0;

/// Harness bunu true yapınca sahne bir sonraki fırsatta suç tetikler (tanık →
/// dedikodu → ihbar zincirini gözlemek için). Sahne tüketip false'a çeker.
bool kProbeTriggerCrime = false;

/// Harness bunu true yapınca sahne bir sonraki üreme taramasında doğumu ZORLAR
/// (uygun her anneyi hazır say). Sahne tüketip false'a çeker.
///
/// Neden var: referans köyde boş yatak yok → 34 sim gününde tek doğum olmuyor,
/// yani doğum yolu hiçbir testte çalışmıyordu. Tam da bu yüzden orada bir
/// `ConcurrentModificationError` fark edilmeden durabildi (bkz.
/// `_tickReproduction`). Bu bayrak o kör noktayı kapatır.
bool kProbeForceBirth = false;

/// Prova: bu koşuda kaç bebek doğdu (doğum yolunun gerçekten koştuğunun kanıtı).
int kProbeBirths = 0;

/// Bir sonraki rastgele olayı BU kimliğe zorlar ([EventIds]); boşsa normal
/// ağırlıklı çekiliş yapılır. Sahne tüketip temizler.
///
/// Neden var: her olayın kendi NPC vinyeti var (bkz. scene_vignette) ama
/// çekiliş ağırlıklı — 9 sahnenin tamamını gözlemek/test etmek rastgeleliğe
/// kalırsa hiçbiri düzenli koşmaz. Dev konsol "Olay Sahnele" komutu ve
/// event_vignette_test bunu kullanır.
String kForcedEventId = '';

/// Harness bunu true yapınca sahne bir sonraki tick'te olay mayalandırır
/// (godMode açık olsa bile). [kForcedEventId] ile birlikte kullanılır.
/// Sahne tüketip false'a çeker.
bool kProbeTriggerEvent = false;

/// Sahnedeki vinyetin olay kimliği ('' = sahne yok) ve kadro büyüklüğü.
/// "Olay sessizce sahnelenmedi" kör noktasının tek kanıtı bu iki sayı.
String kProbeVignetteId = '';
int kProbeVignetteCast = 0;

/// Capture harness: vinyet sahneye çıkar çıkmaz kamerayı odağına kilitler
/// ("İzle" düğmesine basılmış gibi). Yalnız görsel doğrulama içindir; oyunda
/// kamerayı olay ele geçirmez (bkz. scene_vignette._watchVignette).
bool kCaptureAutoWatch = false;

/// `ceremony` niyetinde takılı kalan köylü sayısı (yalnız [kMindTelemetryOn]
/// açıkken güncellenir). Vinyet kadrosu salıverilmezse burası sıfıra dönmez —
/// scene_vignette'in en ölümcül tuzağının alarmı.
int kProbeCeremonyLocked = 0;

/// ÇADIR & OCAK telemetrisi (scene_shelter yazar). Mekanik sessizce hiç
/// çalışmayabilir — "kışın çadır üşütür" cümlesi ancak sayılan bir şey varsa
/// doğrulanabilir. `_coldTents` son taramadaki üşüyen köylü sayısı, `_rouses`
/// bu koşuda soğuktan kaç kez kalkıldığı.
int kProbeColdTents = 0;

/// PROVA: kar çarpanını TAŞIYAN köylü sayısı (bkz. scene_winter
/// `_applySnowFooting`). Kural saf ve testli olsa bile kimse uygulamazsa kış
/// aynı hızda geçer ve hiçbir şey patlamaz — bu sayaç o sessiz kopmayı görünür
/// kılar (bkz. test/snow_test.dart).
int kProbeSnowFooted = 0;
int kProbeColdRouses = 0;

/// FAZ 4 telemetrisi — hırsızlık sahnesinin ânları (`_tickProbe` her tick yazar).
/// "İçeride" penceresi birkaç saniyedir; yarım günlük rapor aralığı onu kaçırır.
bool kProbeTheftInside = false;
bool kProbeTheftSack = false;
int kProbeLootCount = 0;
int kProbeLootTotal = 0;

/// Hırsızlığın dokunduğu üç kaynağın stok toplamı.
int kProbeStockTotal = 0;

/// Bu koşuda çalınan toplam mal + zuladan geri alınan toplam mal.
///
/// Korunum bunlarla ölçülür, ham stokla DEĞİL: köyün ekonomisi paralel dönüyor
/// (köylü yiyor, işçi üretiyor), o yüzden stok toplamı hırsızlıktan bağımsız
/// oynar. Sözleşme: `çalınan == toprakta duran + geri alınan`.
int kProbeTheftTaken = 0;
int kProbeLootRecovered = 0;

// ── HANE KARŞILIĞI provası (bkz. scene_house_stance) ────────────────────────
// "Yapıldı ama canlı görülmedi" tuzağına karşı: esirgeme merdiveni gerçek
// sahnede döndüğünde ölçülebilsin. Harness [kProbeHouseWithhold] ile en nüfuzlu
// haneyi küstürür, [kProbeHouseAppease] ile barıştırır; sayaçlar sonucu söyler.

/// Harness true yapınca sahne en nüfuzlu haneyi merdivenin ambar basamağına
/// iter. Sahne tüketip false'a çeker.
bool kProbeHouseWithhold = false;

/// Harness true yapınca esirgeyen hanenin gönlü alınır (dilekçe hükmü ile aynı
/// yol). Sahne tüketip false'a çeker.
bool kProbeHouseAppease = false;

/// Küstürülen hanenin soyadı — testin doğru haneyi izlemesi için.
String kProbeHouseName = '';

/// Şu an bir şey esirgeyen hane sayısı + o hanelerin ambarlarında saklı toplam.
int kProbeHousesWithholding = 0;
int kProbeHouseStash = 0;

/// Hanesi elini çektiği için işsiz kalan köylü sayısı (o andaki fotoğraf).
int kProbeHouseIdled = 0;

// ── Hesaplaşma provası (bkz. scene_reckoning) ───────────────────────────────

/// Harness bunu true yaparsa hesaplaşma PROVA köyünde de işler. Dağılmanın
/// [kProbeCollapseArmed] muafiyetiyle aynı sözleşme.
bool kProbeReckoningArmed = false;

/// >0 ise sahne gün sayacını buraya ATLATIR (tek atışlık, sahne sıfırlar).
/// Hesaplaşma altıncı yıldadır; oraya gerçek zamanda pump ederek varmak
/// dakikalar sürer ve ölçülen şey zamanın geçişi değil, tarihin geldiğinde
/// ne olduğudur.
int kProbeJumpToDay = 0;

/// Orta oyun dersleri provası (bkz. scene_lessons). Harness bunu true yaparsa
/// dersler PROVA köyünde de açılır; normalde kapalıdır (kare yakalama ders
/// kartını çekerdi).
bool kProbeLessonsArmed = false;
int kProbeLessonsShown = 0;
String kProbeLastLesson = '';

/// Prova telemetrisi — sahnenin okuduğu değerlerin ta kendisi.
int kProbeYear = 0;
bool kProbeReckoningHeralded = false;
String kProbeVerdict = '';
double kProbeStanding = 0;

/// Denge ölçümü için gün/kese/nüfus. Hesaplaşma "köyün ağırlığını" refahtan
/// da okuyor (bkz. ReckoningInput.grit) ve vergi iştahı yılla iki katına
/// çıkıyor — kesenin o eğriyi taşıyıp taşımadığı ölçülebilir olmalı.
int kProbeDay = 0;
int kProbeGold = 0;
int kProbePop = 0;

// ── Kaybetme eşiği provası (bkz. scene_collapse) ────────────────────────────

/// Harness bunu true yaparsa kaybetme eşiği PROVA köyünde de işler. Normalde
/// referans/showcase/capture köyleri ölümsüzdür (harness ölürse prova ölür);
/// bu bayrak o muafiyeti bilerek kaldırır.
bool kProbeCollapseArmed = false;

/// Harness true yapınca sahnede aşamalı OLAY patlamaz. Karar isteyen olay
/// modali simi durdurur; prova bunu "sistem çalışmıyor" sanır.
bool kProbeNoEvents = false;

/// Harness true yapınca en nüfuzlu hane kopuşa itilir ve ayrılık sayacı
/// eşiğin hemen altına kurulur.
///
/// Kanca KALICIDIR (bkz. [kProbeSchismHouse]): tek atışlık bir dürtme yetmez,
/// çünkü oyun küskünlüğü geri çeker — hane mood'u üye moraline gravite eder,
/// moral de koşullara. Sistem kendini toparladığı için sayaç sıfırlanıyor ve
/// prova "ayrılık kolu ölü" diye YANLIŞ yerden düşüyordu.
bool kProbeForceSchism = false;

/// Kopuşta TUTULAN hane (prova). Boş = tutma yok. Test temizler.
String kProbeSchismHouse = '';

/// Harness true olduğu SÜRECE köy geri sayım bandında tutulur (yetişkinler
/// budanır). Aynı sebeple kalıcı: referans köyde çocuklar yetişkinliğe geçip
/// köyü banttan çıkarıyor ve geri sayım sıfırlanıyordu — ki bu oyunun DOĞRU
/// davranışı (köy toparlandı), yalnız provanın kurgusu yanlıştı.
bool kProbeDrainVillage = false;

/// Telemetri: köyün evresi, geri sayımın kalanı, dağıldı mı, kaç hane gitti.
String kProbeVitality = '';
double kProbeCollapseDaysLeft = -1;
bool kProbeCollapsed = false;
int kProbeHousesLeft = 0;

/// Köyü döndüren el sayısı (prova tanısı) — evre beklenmedikse önce buna bak.
int kProbeAdults = 0;

/// Harness bunu true yapınca sahne meydana GÖRÜLMÜŞ bir zula gömer — zulanın
/// bulunma+iade yolunun gerçekten koştuğunu sınamak için. Sahne tüketip
/// false'a çeker.
bool kProbePlantLoot = false;

/// PROVA: imparatorluk heyetini bastırır. Pazarlık modali simi DONDURUR
/// (kProbePause 'imparatorluk') ve heyeti ölçmeyen harness'lar bu pencerede
/// ölür — olay modalinin kProbeNoEvents'i neyse bu da odur.
bool kProbeNoImperial = false;

/// PROVA: koşu boyunca EN AZ BİR köylü el salladı mı (bkz. CharGesture.wave).
/// Selam gövdeye taşındı; en sinsi hata "jest var ama hiç tetiklenmiyor"dur ve
/// jestin kendisi hiçbir sayıya dokunmadığı için başka türlü görülmez.
bool kProbeWaveSeen = false;

/// PROVA: baş üstünde görülen YASAKLI ikon (selam/hikâye/olay baloncuğu geri
/// sızarsa dolar). Boş = borç ödenmiş duruyor.
String kProbeBannedBubble = '';

/// PROVA: harness'in imparatorluk MUAFİYETİNİ kaldırır. Prova/showcase
/// köylerinde pazarlık modalı her tick siliniyor (tıklayacak oyuncu yok, modal
/// simi sonsuza dek dondururdu — bkz. scene_tick'teki bastırma listesi). Eşik
/// provası bu modalın düğmesine BASACAĞI için muafiyetten çıkar.
bool kProbeImperialArmed = false;

/// PROVA: heyeti bir sonraki tick'te sahneye çağırır (`_devSummonImperial`).
/// Sahne tüketip false'a çeker. Modal açılınca sim DURUR — bundan sonrasını
/// pump değil, testin karar düğmesine basması yürütür.
bool kProbeSummonImperial = false;

/// PROVA: direniş zarını KAZANDIRIR. Eşik sahnesi ([kThresholdVignetteId])
/// yalnız kazanılan dirende kurulur; zara bırakılırsa test çoğu koşuda sahneyi
/// hiç görmez ve "sessiz susma" kör noktası ölçülemez.
bool kProbeForceResistWin = false;

/// PROVA: karar KUYRUĞUNUN muafiyetini kaldırır. Prova/showcase köylerinde
/// `_pendingChoice` her tick siliniyor (bastırma listesi) — kuyruk provası tam
/// da o bekleyişi ve zaman aşımını ölçeceği için muafiyetten çıkar
/// (kProbeImperialArmed'ın kuyruk karşılığı).
bool kProbeChoiceQueueArmed = false;

/// PROVA telemetrisi: şu an kuyrukta bekleyen karar olayının id'si ('' = yok).
/// "Kuyruk var ama hiç dolmuyor / hiç boşalmıyor" ancak buradan görülür.
String kProbeChoiceWaiting = '';

/// PROVA telemetrisi: mühleti dolup KENDİ yoluna giren karar sayısı. Zaman
/// aşımı simin akmasına bağlıdır (donuk simde mühlet hiç erimez) — bu sayaç
/// artıyorsa hem kuyruk hem akış canlı demektir.
int kProbeChoiceTimeouts = 0;

/// PROVA: gecikmiş dilekçenin (kapıda bekleyen huzur) muafiyetini kaldırır.
/// Bastırma listesi `_petitionOverdue`'yu her tick düşürür (uzun telemetri
/// koşularında hane/moral eğrisi kirlenmesin); gecikme provası tam da o
/// bekleyişi ölçeceği için muafiyetten çıkar.
bool kProbePetitionQueueArmed = false;

/// PROVA telemetrisi: koşuda EN AZ BİR dilekçe kapıda beklemeye geçti mi
/// (mühlet doldu, donma yok, bedel işliyor). "Eskalasyon kodu var ama hiç
/// tetiklenmiyor" ancak buradan görülür.
bool kProbePetitionOverdueSeen = false;

/// KARAR İZİ provası — harness bunu true yapınca sahne bekleyen dilekçenin İLK
/// şıkkını seçer (oyuncunun kararı gibi); bekleyen yoksa dilekçe kuyruğunu
/// hemen açar. Sahne tüketip false'a çeker.
bool kProbeDecideNow = false;

/// Güncedeki KARAR türü satır sayısı — "karar verildi ama hiçbir yere
/// yazılmadı" hatasının tek görünür kanıtı.
int kProbeDecisionLines = 0;

/// Son karar satırının metni (tanı için).
String kProbeLastDecision = '';

/// KAYIT GİDİŞ-DÖNÜŞÜ provası — harness bunu true yapınca sahne kendi köyünü
/// kaydeder (captureWorld → jsonEncode) ve o JSON'dan geri yükler
/// (restoreWorld). Yani "kaydet, sonra aç" tek tick'te yaşanır.
/// Sahne tüketip false'a çeker; sonucu [kProbeSaveError]'a yazar.
bool kProbeSaveRoundtrip = false;

/// Gidiş-dönüşte atılan istisna ('' = temiz). Kayıt yolu istisnayı YUTUYOR
/// (`_saveNow` catch'i "⚠ Kayıt başarısız" der ve susar) — bu yüzden hata
/// ancak burada görünür.
String kProbeSaveError = '';

/// Sahnenin kaydettiği dünyanın JSON'u — [kProbeSaveRoundtrip] tüketilince
/// yazılır. Harness bunu bozup (alan silip) [kProbeRestoreJson]'a koyarak
/// ESKİ SÜRÜM kaydı taklit edebilir.
String kProbeWorldJson = '';

/// Harness buraya bir dünya JSON'u koyarsa sahne onu yükler ve tüketir.
/// "Bu kaydı aç" demenin headless yolu.
String kProbeRestoreJson = '';

/// Bespoke sahnesi OLMAYAN kararların günceye düşen satır sayısı — yani bu
/// turda eklenen yolun (`_chronicleDecision`) gerçekten koştuğunun kanıtı.
/// Kendi cümlesini zaten yazan fx'ler (sulh/çağrı/suç hükmü) buraya sayılmaz.
int kProbePlainDecisions = 0;

/// Bekleyen dilekçenin id'si (tanı) — 'karar düşmedi' bulgusunda ilk bakılacak
/// yer: dilekçe hiç gelmedi mi, yoksa gelip kaydedilmedi mi?
String kProbePendingPetition = '';

/// TEST/capture: hakem telemetrisi. Açıkken scene_mind her müzakere turunda
/// köyün canlılık kanıtını buraya yazar — kaç köylü yürüdü, kaç farklı niyet
/// var, en uzun süredir değişmeyen niyet kaç saniyelik. Donma testi
/// (test/mind_liveness_test.dart) "köy hâlâ yaşıyor mu" sorusunu bundan
/// yanıtlar; ekran görüntüsü ya da widget sayısı bu soruyu yanıtlayamaz.
bool kMindTelemetryOn = false;

/// Toplam kat edilen mesafe (tile) — donmuş köyde artmaz.
double kMindDistance = 0;

/// Sahnede o an görülen farklı niyet sayısı.
int kMindDistinctIntents = 0;

/// En uzun süredir değişmemiş niyetin yaşı (sn) — kilitlenme göstergesi.
double kMindOldestIntent = 0;

/// capture: yargıda kürek cezası varsa hep onu seç (taş kazanımını gözle).
bool kCaptureLaborOnly = false;

class VillageScene extends StatefulWidget {
  final VoidCallback? onExitToMenu;

  /// Kaldığı yerden devam için yüklenecek dünya (null = taze köy).
  final Map<String, dynamic>? initialWorld;

  /// Bu oyunun yazılacağı kayıt slotu.
  final String slotId;
  final String slotName;

  /// true → taze köy yerine REFERANS KÖY kurulur (sabit test zemini; açılış
  /// sinematiği/ateş yerleştirme atlanır). Bkz. scene_reference_village.dart.
  final bool referenceVillage;
  const VillageScene({
    super.key,
    this.onExitToMenu,
    this.initialWorld,
    this.slotId = '',
    this.slotName = 'Köy',
    this.referenceVillage = false,
  });
  @override
  State<VillageScene> createState() => _VillageSceneState();
}

class _VillageSceneState extends State<VillageScene>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // ── part-of yardımcısı: setState @protected olduğundan extension'lardan
  // doğrudan çağrılamıyor. Bu wrapper sayesinde scene_*.dart part dosyaları
  // setStateHere(() {...}) ile state mutate edebilir.
  void setStateHere(VoidCallback fn) => setState(fn);

  // ── Game loop ──────────────────────────────────────────────────────────────
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  // Referans köy kurulumda bunu SABİT tohumla değiştirir (aynı köy her seferinde)
  // → final değil. Normal oyunda tohumsuz Random olarak kalır.
  Random _rng = Random();
  double _time = 0;

  // ── Ortak ağır-karar ritmi ────────────────────────────────────────────────
  // Dilekçe, seçimli olay, suç hükmü ve imparatorluk aynı oyuncu dikkatini
  // kullanır. Saf otorite zaman/öncelik/ölçümü; bu payload listeleri ise sahne
  // nesnelerini taşır. Hepsi kayda yazılır (bkz. scene_save).
  DecisionPacing _decisionPacing = DecisionPacing();
  final List<_PacedPetition> _pacedPetitions = [];
  final List<_PacedChoice> _pacedChoices = [];
  ImperialDemand? _pacedImperialDemand;
  String? _pacedImperialRequestId;

  // ── Kamera sarsıntısı (juice) — sarsıcı olaylarda kısa titreşim ─────────────
  // SettingsModel.shakeOnEvents kapalıysa hiç tetiklenmez. addCameraShake ile
  // kurulur, her frame söner; buildGameCanvas kamerayı bu offset'le çizer.
  double _shakeMag = 0;
  double _shakeTime = 0;
  double _shakeDur = 0.5;

  // ── Şimşek flash (fırtınada) — şekilsiz, beyaz, yumuşak gök parlaması ───────
  /// Anlık flash yoğunluğu (0..1) — buildLightningFlash beyaz overlay alfa'sı.
  double _lightningFlash = 0;

  /// Sonraki şimşeğe kalan süre (sn). Fırtına yokken dondurulur.
  double _lightningTimer = 6;

  /// Çift çakım (flicker) için ikinci darbeye kalan süre (>0 ise bekliyor).
  double _lightningPulse = 0;

  /// Şimşekten sonra gök gürültüsüne kalan süre (>0 bekliyor) — ışık-ses gecikmesi.
  double _thunderDelay = 0;

  // ── İmparatorluk (dış tehdit / vergici askerî heyet) ───────────────────────
  /// İmparatorlukla ilişki (0..1) — pazarlık şansı + talep sertliği + sıklık.
  double _imperialFavor = 0.5;

  /// Bir sonraki ziyarete kalan süre (sim sn). İlk ziyaret için gecikmeli.
  double _imperialTimer = 6.0 * kGameDaySeconds;

  /// Aktif talep (null = ziyaret yok). Non-null iken sim duraklar + modal açık.
  ImperialDemand? _imperialDemand;

  // ── Hane eylemleri (oyuncunun hanelere karşı proaktif ajansı) ──────────────
  /// Soyad → BASKI sayacı: o haneye yakın geçmişte kaç sert eylem yapıldı.
  /// Zamanla sönümlenir (_tickHousePressure); bedel katlayıcısı buradan okunur
  /// → aynı haneyi üst üste sağmak pahalanır. Kayda yazılır.
  final Map<String, double> _housePressure = {};

  /// Hane entrikası yoklama sayacı (sim sn) — bkz. _tickHouseIntrigue.
  double _houseIntrigueScan = 0;

  /// Siyasi nikâh: organik kur AYNI EVİ şart koşar, siyasi nikâh haneler
  /// arasıdır → bu bayrak o şartı gevşetir (bkz. _coupleStillValid).
  bool _betrothalForced = false;

  /// Kaç kez pazarlığa oturuldu — sinematik merdiveninin tabanı (ilk ziyaret
  /// tam film, sonrası rutin). Bkz. scene_imperial._startImperialParley.
  int _imperialVisits = 0;

  /// Bir sonraki ziyaret KİNLİ mi (ret / direniş sonrası) → ton değişti, film
  /// geri gelir. Ziyaret başlarken tüketilir.
  bool _impGrudge = false;

  /// Hangi imparatorluk filmi oynatıldı ('conscript', 'grudge'). Her tür koşuda
  /// BİR KEZ film olur; ikincisinde aynı kompozisyon tören değil kesintidir.
  /// Bkz. scene_imperial._startImperialParley.
  final Set<String> _impFilmsShown = {};

  /// Fiziksel asker heyeti — köye formasyonla yürüyen geçici varlıklar (bkz.
  /// scene_imperial). Köyün sakini DEĞİL; kayda yazılmaz, nüfusa karışmaz.
  final List<ImperialSoldier> _soldiers = [];

  /// Heyet ziyaretinin evresi — yaklaşma/pazarlık/ayrılış makinesi.
  ImperialVisitPhase _imperialPhase = ImperialVisitPhase.idle;

  /// Formasyon çapası (komutanın hedefi) — yaklaşırken parley'e, ayrılırken
  /// çıkışa doğru kayar; askerler buna göre slotlanır.
  double _impAnchorCol = 0, _impAnchorRow = 0;

  /// Son yürüyüş yönü (formasyon slotlarını döndürmek için) — normalize.
  double _impDirX = 0, _impDirY = 1;

  /// Pazarlık noktası (köy eşiği) ve çıkış/giriş köşesi.
  double _impParleyCol = 0, _impParleyRow = 0;
  double _impExitCol = 0, _impExitRow = 0;

  /// Yaklaşma anında ölçülen refah — ayrılışta sonraki ziyaret aralığı için.
  double _impProsperity = 0;

  /// Bu ziyaret şiddetle bitti mi (reddetme / direniş ezilmesi) → ayrılış yerine
  /// önce köy merkezine YAĞMA dalışı (raiding evresi).
  bool _imperialRaid = false;

  /// Darbeyle düşecek kurbanlar — karar anında seçilir ama askerler merkeze
  /// VARINCA `startDying` çağrılır (ölüm darbe anıyla senkron).
  final List<VillagerEntity> _imperialRaidVictims = [];

  /// Yağma dalışında darbe vuruldu mu (bir kez) + dalış/bekleyiş sayacı.
  bool _impStruck = false;
  double _impRaidTimer = 0;
  double _imperialClashTimer = 0;

  /// Yağma dalış hedefi (köy merkezi, karaya sabit).
  double _impRaidCol = 0, _impRaidRow = 0;

  // ── Kayıt (otomatik + manuel) ───────────────────────────────────────────────
  /// Bu oyunun yazıldığı kayıt slotu.
  late final String _slotId = widget.slotId;

  /// Kayıt kartında görünen ad. Açılışta köye verilen ad bunu EZER — yeni
  /// kayıt menüde "Köy" değil, oyuncunun koyduğu adla durur.
  late String _slotName = widget.slotName;

  /// Periyodik otomatik kayıt için gerçek-zaman (wall clock) birikimi.
  double _autoSaveAccum = 0;
  static const double _kAutoSaveInterval = 30.0; // sn (gerçek zaman)
  /// Aynı anda iki yazım çakışmasın diye basit kilit.
  bool _saving = false;

  // ── Asset loading ──────────────────────────────────────────────────────────
  /// Tüm sprite cache'leri yüklenene kadar oyun render edilmez.
  /// initState'te paralel başlatılır; yüklenince ticker başlar.
  late final Future<void> _assetsReady;
  bool _assetsLoaded = false;

  // ── Economy ────────────────────────────────────────────────────────────────
  // Köy stoğu — taşıyıcılar tarafından doldurulur, inşaat orderları tüketir.
  // Ateş yeri ücretsiz; gerçek malzemeler işçiler ürettikçe birikir.
  final ResourceBundle _stockpile = ResourceBundle();

  // Binalardan türeyen köy istatistikleri (kapasite, moral, taşıyıcı hızı).
  // Her tick updateBuildings ile güncellenir; panel ve HUD okur.
  VillageStats _stats = const VillageStats(
    stockCapacity: kBaseStockCapacity,
    morale: 0.5,
    carrierSpeedMultiplier: 1.0,
    wellCount: 0,
  );

  // ── Entities ───────────────────────────────────────────────────────────────
  final List<VillagerEntity> _villagers = [];

  /// Gezgin tüccarlar — köyün sakini DEĞİL, arada gelip giden ambiyans (bkz.
  /// scene_merchant). Nüfusa/eve/dilekçeye karışmaz; kayda yazılmaz.
  final List<MerchantEntity> _merchants = [];

  /// Sonraki tüccar ziyaretine kalan süre (sim-saniye). _tickMerchants yönetir.
  double _merchantTimer = 0.7 * kGameDaySeconds;

  /// Oyalanan tüccarın sonraki alımına kalan süre (sn) — ziyaret başında kurulur,
  /// browsing evresinde işler (bkz. _tickMerchants trade). Kaydedilmez (geçici).
  double _merchantTradeCd = 0.0;
  final List<BuildingEntity> _buildings = [];
  final List<BuildOrder> _orders = [];

  // ── Yol sistemi ────────────────────────────────────────────────────────────
  // _roadSystem tamamlanmış yolları tutar (autotile + hız çarpanı kaynağı).
  // _roadOrders builder kuyruğu — completed olunca _roadSystem'e geçer.
  //
  // DÖŞEME AKIŞI (eskiden serbest-el + anında commit'ti; parmak titremesi
  // yanlış tile'lara yol döşüyor, geri alınamıyordu):
  //   sürükle → ÖNİZLE (hiçbir şey harcanmaz) → bırak → döşe.
  // Güzergâh serbest el değil, başlangıç ile bitiş arasında DİK "L" — baskın
  // eksende git, sonra köşeyi dön. Tahmin edilebilir, titremeye bağışık.
  final RoadSystem _roadSystem = RoadSystem();
  final List<RoadOrder> _roadOrders = [];

  /// Seçili yüzey (döşeme modu). [_roadErase] true iken null olur.
  RoadSurface? _placingRoad;

  /// Silgi modu — sürüklenen güzergâhtaki yolları/bekleyen emirleri kaldırır.
  /// Yanlış döşenmiş eski yollar için tek çare (öncesinde yol hiç silinemiyordu).
  bool _roadErase = false;

  /// Yol modu (döşe ya da sil) aktif mi.
  bool get _roadMode => _placingRoad != null || _roadErase;

  /// Sürükleme uçları — önizleme bunlardan türer.
  (int, int)? _roadDragStart;
  (int, int)? _roadDragEnd;

  /// Önizlenen güzergâh: (tile, uygulanabilir mi). Painter yeşil/kırmızı çizer.
  /// Yerinde mutate edilir → painter içerik karşılaştıramaz, [_roadPreviewV]
  /// sayacı repaint kararını verir.
  final List<((int, int), bool)> _roadPreview = [];
  int _roadPreviewV = 0;

  // A* pathfinding context — roadSystem + blockedTiles ref + version sayacı.
  // World topology değişince (yeni bina/yol, maden tükenme) version bump'lanır
  // ve NPC'ler cached path'i invalidate eder.
  late final PathContext _pathContext = PathContext(roadSystem: _roadSystem);
  // Sosyal noktalardaki (kuyu vd.) rezerve edilebilir slot'ları yöneten otorite.
  // Topology değişince (yeni/silinmiş bina) rebuild edilir, runtime claim/release
  // sırasında dokunulmaz — aksi halde aktif rezervasyonlar reset olur.
  final AnchorSystem _anchorSystem = AnchorSystem();

  // ── Firepit & home sistemi ─────────────────────────────────────────────────
  bool _hasFire = false;
  BuildingEntity? _firepitBuilding;
  // ── Ateş yakıtı (scene_fire) ───────────────────────────────────────────────
  // Ateş artık beslenmek ister: yakıt tükenir, ateşçi odun ya da kömür taşır,
  // ikisi de bittiyse söner → köy çapı huzursuzluk + dilekçe.
  bool _fireWasBurning = true; // sönme/yeniden yanma geçişi için
  double _firekeeperScan = 0; // ateşçi atama poll sayacı
  VillagerEntity? _firekeeper; // o an ateşe yakıt taşıyan köylü
  ResourceKind? _firekeeperFuel; // omuzladığı yakıt (null = eli boş)
  double _firekeeperGiveUp = 0; // ulaşamazsa görevi bırakma sim zamanı
  // Odun azalma uyarısı için histerez: stok sağlıklı seviyeye çıkmadan uyarı
  // çıkmaz; bir kez çıkınca tekrar sağlığa dönene dek susar (spam önler).
  bool _woodHealthy = false;
  // ── Çadır & ocak (scene_shelter) ───────────────────────────────────────────
  // Ocaktan uzağa kurulmuş çadır kışın üşütür: köylü gece titreyerek kalkar,
  // ateşin başına gider. Sayaçlar geçici — kayda girmez.
  double _rouseScan = 0; // gece uyandırma poll sayacı
  int _shelterDay = -1; // gecelik kotanın ait olduğu gün
  final Map<VillagerEntity, int> _rousedTonight = {}; // bu gece kaç kez kalktı
  double _shelterMurmurWait = 0; // köyün bu dertten söz etme bekleyişi (gün)
  BuildingEntity? _selectedBuilding;
  VillagerEntity? _selectedVillager;

  /// Seçili BİNASIZ iş yeri ([WorkSite.id]) — tarla, böğürtlenlik, şantiye.
  /// Bina iş yerleri `_selectedBuilding` üstünden açılır (kadro o binanın
  /// kendi kartında durur); burası yalnız yapısı olmayan işler için.
  ///
  /// Kimlik tutulur, nesne değil: iş yerleri her karede sahneden yeniden
  /// türetilir ([_workSites]) — bayat bir nesne tutsaydık sipariş tamamlanınca
  /// panel ölü bir şantiyeyi göstermeye devam ederdi.
  String? _selectedSiteId;

  /// Komuta çubuğu: seçili öğe önce ORTA segmentte kompakt görünür; tam panel
  /// (BuildingInfoPanel/VillagerInfoPanel) yalnız "Detay"a basınca açılır. Yeni
  /// seçimde sıfırlanır (setState'lerde `_selectedBuilding=` yanına eklendi).
  bool _detailExpanded = false;

  /// Oyuncu "Takip et" eylemini kullanırsa kamera bu NPC'ye demirlenir;
  /// her tick'te yumuşak lerp ile NPC merkeze çekilir. Manuel pan (scaleStart)
  /// otomatik iptal eder. null = serbest kamera.
  VillagerEntity? _followedVillager;

  // ── Camera + Zoom ──────────────────────────────────────────────────────────
  Offset _camera = const Offset(-160, -80);
  Offset? _panAnchor;
  Offset? _cameraAnchor;
  double _zoom = 1.0;
  double _scaleStart = 1.0;

  // ── Kamera "reach" (ulaşılabilir bölge) ──────────────────────────────────────
  // Reveal = ZOOM KISITLAMASI: kamera reach dışını gösteremez → gerçek harita
  // kenarı asla kadraja girmez ("havada yüzen ada" yok). Reach zamanla büyür
  // (hikâye beat'leri → organik). Clamp EKRAN eksenlerinde (u=c-r, v=c+r) yapılır;
  // ulaşılabilir bölge = harita elmasına içten çizilmiş ekran-hizalı dikdörtgen
  // → ÖLÜ KÖŞE YOK. Detay: scene_input._clampCamera.
  static const double _kMaxZoom = 4.0;

  /// Elmasın ucunda hep kalan tampon (hu+hv cinsinden) — void asla görünmez.
  /// Bu tampon "israf" değil, no-edge yanılsamasını sağlayan çerçevedir.
  static const double _kEdgeBuffer = 10.0;

  /// Başlangıç reach span'i (hu+hv) — kullanıcı onaylı açılış uzaklığı.
  static const double _kSpanStart = 50.0;

  /// Reach span'i (hu+hv). Üst sınır `_maxSpan` = min(kCols,kRows)-1-tampon.
  double _reachSpan = _kSpanStart; // hikâye beat'leri + organik ile büyür
  bool _cameraCentered = false; // ilk geçerli frame'de merkeze ortala
  // "Dünya açılıyor" anı: reach genişlerken oyuncu TAM zoom-out'a yapışıksa
  // kamerayı yumuşakça geriye bırakırız (scene_land._updateLandExpansion).
  double _lastMinZoom = 0.0;

  /// Reach'in İLK kez kadraja aldığı cevher türleri (OreType.name) — keşif
  /// bildirimi + kronik tek sefer yazılır (scene_land._tickOreDiscovery).
  /// Kalıcı (save'e girer).
  final Set<String> _oreDiscovered = {};
  double _oreScanTimer = 0; // keşif taraması throttle'ı (1 sn)

  // ── Placement ──────────────────────────────────────────────────────────────
  BuildingType? _placing;
  (int, int)? _ghost;
  // İnşa paleti seçili kategori sekmesi (alt çubuk). Civic = ateş/belediye ile başla.
  BuildCategory _buildCategory = BuildCategory.civic;
  // Akıllı yerleştirme: hayalet geçersiz tile üstündeyse SEBEP (örn. "Yakında
  // ağaç yok"); geçerli/placing yokken null. Hover'da güncellenir.
  String? _placeReason;
  // İNŞA KÜNYESİ — hayaletin durduğu yerin ÖLÇÜMÜ (bkz. _siteFactsAt). Künye
  // panelindeki yerleşim ipuçları bununla canlı doğrulanır ("3 ağaç ✓").
  // Hayalet tile değiştirdiğinde yenilenir; hayalet yokken null (ipuçları
  // nötr, yalnız metin okunur).
  SiteFacts? _placeFacts;
  // Tatlı not seçici — her bina seçiminde artar, künyede havuzdan başka bir
  // cümle çıkar (tek string yazma kuralı, bkz. voice.dart).
  int _loreNoteSeed = 0;
  // Çoklu dikim: tek tık → bir bina kur + seçimi bırak. Basılı tutup sürükle
  // (long-press) → bu mod açılır, dokunulan her tile'a bina dikilir; bırakınca
  // seçim bırakılır. _placeStrokeTiles aynı tile'a iki kez denemeyi engeller.
  bool _multiPlace = false;
  final Set<(int, int)> _placeStrokeTiles = {};
  // Tutup-bırak: oyuncunun sürüklediği köylü (null = yok). Sürükleme sırasında
  // tick onu dondurur, imleci takip eder; bırakınca normale döner.
  VillagerEntity? _draggedVillager;
  bool _dragMovedVillager = false;
  Size _viewSize = Size.zero;

  // ── Hover künyesi (DÜNYA-uzayı: imleci değil, hedefi takip eder) ────────────
  // PERF KURALI: hover hiçbir notifier bumplamaz, setState çağırmaz. Yalnız bu
  // alanları yazar; künye widget'ı zaten _frame'e bağlı olduğundan bir sonraki
  // karede (≤16ms) kendini günceller. Eski sürüm her fare pikselinde _frame'i
  // bumpluyordu → 60 alanlı painter + CommandBar + quest tracker saniyede ~100
  // kez rebuild oluyordu (kasmanın kaynağı).
  VillagerEntity? _hoverVillager;
  BuildingEntity? _hoverBuilding;
  Grave? _hoverGrave;

  /// Künyenin belirmeye başladığı _time damgası (yumuşak fade-in için).
  double _hoverSince = 0;

  /// Son hit-test edilen imleç konumu — küçük titremelerde testi atlamak için.
  Offset? _hoverProbe;

  // ── Day/Night ──────────────────────────────────────────────────────────────
  final DayNightCycle _cycle = DayNightCycle();

  // ── Farm ───────────────────────────────────────────────────────────────────
  final List<FarmTile> _farmTiles = [];

  /// Ambarsız köyde balyalar harmanda çürür (carrier_system depo şartı arar) —
  /// tarla kurulu ama yiyecek gelmiyor. Sessiz kalmasın: aralıklı uyarı.
  double _baleStallWarnCd = 0.0;

  /// İş atama uzlaştırma throttle'ı ([_syncJobWorkforce]).
  double _jobSyncCd = 0.0;

  /// Kereste kampı bölge yönetimi throttle'ı ([_tickLumberCampManage]).
  double _lumberManageCd = 0.0;

  /// "İş var ama boş köylü yok" uyarısı throttle'ı (spam'siz).
  double _jobBlockWarnCd = 0.0;

  // ── Trees ──────────────────────────────────────────────────────────────────
  final List<TreeEntity> _trees = [];

  // ── Arazi / vahşi orman (scene_land) — "Nefes Alan Orman" ───────────────────
  // Köy sol-üst küçük bir açıklıkta başlar; harita geri kalanı vahşi ORMAN =
  // tek engel. Açıklığa komşu "ön hat" halkasında gerçek kesilebilir ağaçlar
  // (TreeEntity.isWild) durur; derin orman entity'siz kanopidir. Oduncular ön
  // hattı yer → devrilen ağacın tile'ı açılır, orman içeri bir halka çekilir.
  // Eski "vahşi orman / sis" reveal'ından kalıntı setler — zoom-reveal modelinde
  // HEP BOŞ (reveal = kamera kısıtı, örtü yok). Placement gate / obstacle /
  // painter guard'ları boş-guard'la kendiliğinden devre dışı. Tam alan temizliği
  // ayrı refactor: [scene_land].
  final Set<(int, int)> _cleared = {};
  final Set<(int, int)> _wilderness = {};
  final Set<(int, int)> _wildTreeTiles = {};
  final int _forestVersion = 0; // painter repaint tokeni (sabit)
  final List<LeafBurst> _leafBursts = []; // devrilen ağaç yaprak patlaması (fx)

  // ── Lumber (ağaç kesme) ────────────────────────────────────────────────────
  // Oduncu kulübeleri — her bina kendi LumberCampEntity'sine sahip
  bool _lumberMode = false;
  (int, int)? _lumberStart;
  (int, int)? _lumberEnd;

  // ── World ─────────────────────────────────────────────────────────────────
  late int _worldSeed;
  final Set<(int, int)> _waterTiles = {};
  final List<LotusEntity> _lotuses = [];
  final List<ReedClump> _reeds = [];

  /// Böğürtlen çalıları — köyün BİNASIZ tek üretim kaynağı (bkz. [BerryBush]).
  /// Toplayıcı buradan yiyecek getirir; kışın yenilenmez.
  final List<BerryBush> _berryBushes = [];

  /// Ocakta pişmiş sıcak yemek adedi. Açlık tüketiminde ham yiyeceğin YERİNE
  /// geçer (aynı hasat iki katı ağız doyurur) — bkz. [_tickPopulationAndHunger].
  int _cookedMeals = 0;
  // ── Ground decor (çiçek, mantar, çalı, kütük, taş) — pure visual ─────────
  final List<DecorEntity> _decor = [];

  // ── Mezarlık — kilise yanında biriken mezarlar (cenaze sistemi) ──────────
  final List<Grave> _graves = [];
  // Ateş etrafı saz yatakları — evsizler biçtiği sazla kurar, geceleri uyur.
  final List<ReedBed> _reedBeds = [];
  double _reedScan = 0; // _tickReed throttle sayacı
  double _workScan = 0; // _tickWork throttle sayacı (meslek iş döngüleri)
  double _weaponCraftTimer = 0;

  /// Showcase köyünde arazi yüzünden kurulamayan binalar (sessiz atlama olmasın).
  final List<String> _showcaseSkipped = [];

  /// Referans köyde plana oturmayan binalar (aynı gerekçe — sessiz düşme yok).
  final List<String> _refSkipped = [];

  // Kilometre taşı bildirimleri — bir kez tetiklenir.
  int _lastPopMilestone = 0;
  bool _firstReedBedShown = false;

  // ── Mining (maden kazma) ───────────────────────────────────────────────────
  final List<MineNode> _mineNodes = [];
  // ── Fisher ────────────────────────────────────────────────────────────────

  // ── Florist (çiçekçi kulübesi NPC'si) ─────────────────────────────────────

  // ── Ağıl: çobanlar + inekler ──────────────────────────────────────────────
  final List<AnimalEntity> _cows = [];

  /// Kümeslerin bıraktığı görünür yumurtalar (toplan→food / çatla→civciv).
  final List<EggEntity> _eggs = [];

  /// Gömülü zulalar — hırsızın toprağa verdiği çuvallar (Faz 4). Çalınan mal
  /// buharlaşmaz; burada durur ve bulunabilir.
  final List<LootCache> _lootCaches = [];

  // ── Ambient gökyüzü kuş sürüleri ──────────────────────────────────────────
  // Etkileşim yok, pure atmosphere. Gündüz periyodik spawn, off-grid temizle.
  final List<BirdFlock> _birdFlocks = [];
  double _birdFlockSpawnTimer = 20.0; // ilk sürü 20s sonra

  // ── Ambient arı sürüleri — her arı kovanına bağlı, kovan etrafında orbit ──
  // Topology değişince _rebuildBeeSwarms ile kovanlardan türetilir (mevcutlar
  // pozisyona göre korunur). Pure atmosphere, gece fade.
  final List<BeeSwarm> _beeSwarms = [];

  // ── Ambient göktaşı yağmuru — seyrek, gece özel gök gösterisi (karar yok) ──
  // Geri sayım gün-gece boyunca akar; sıfırlanınca gece tetiklenir, köylüler
  // izler + moral artar. Nadir/özel — ilk gösteri ~4. gün, sonra her 5-9 günde.
  double _meteorShowerTimer = 4.0 * kGameDaySeconds;

  // ── Belediye politikaları — oyuncunun nüfus üstündeki kararları ──────────
  // Default hepsi kapalı. BuildingInfoPanel toggle ile değiştirir.
  final VillagePolicies _policies = VillagePolicies();

  /// Misafirperverlik politikası açıkken bir sonraki gezgin spawn timer'ı.
  /// Random 3-6 oyun günü; spawn olunca yeniden roll edilir.
  double _migrationTimerSec = 0;

  /// Dışarıya Nikâh Fermanı yürürlükteyken bir sonraki gelin/damat timer'ı.
  /// Göçten yavaş (5-9 oyun günü) — eş bulmak akın değil, tek tek olan bir şey.
  double _marriageMigrationSec = 0;

  /// Komşuluk poll sayacı — 1.2s aralıkla selamlaşma scan.
  double _greetPollSec = 0;

  /// Gömülü zula taraması sayacı (bkz. scene_loot).
  double _lootScanSec = 0;

  /// Çocuk oyunu poll sayacı — yakın iki çocuk kovalamaca/oyun scan'i.
  double _childPlayPollSec = 0;

  /// Aile birleşimi poll sayacı — 15s aralıkla solo eşleştirme.
  double _reunionPollSec = 0;

  /// Bilge yaşlı emergence poll — ~60s aralıkla rastgele tetikleme şansı.
  double _sageCheckSec = 60;

  /// Reproduction tick throttle — fertility kontrolü her frame gerek değil.
  /// 0.5s aralıkla full villager scan, kullanıcı fark etmez.
  double _reproPollSec = 0;

  /// Hayvan doğum/ölüm sayaçları — zümre morali beslemesi (scene_estates)
  /// bunları tüketir: doğum Emekçi moralini ↑, ölüm/açlık ↓.
  int _animalBirthsPending = 0;
  int _animalDeathsPending = 0;

  /// Oynayan sinematik (null = yok). Açılış/kademe/final/kriz hepsi buradan.
  /// Non-null iken sim duraklar (scene_tick) + tam ekran CutscenePlayer overlay.
  Cutscene? _activeCutscene;

  /// Köyün hikâye güncesi (kronik) — büyük anlar + başarımlar, yapısal kayıtlar.
  /// Köy Defteri'nin KRONİK bölümünden okunur. `_chronicle` ile yazılır;
  /// başarımlar `_award` ile (milestone:true). Kalıcı (kaydedilir).
  final List<ChronicleEntry> _storyLog = [];

  /// Bir kez kazanılan başarımların id kümesi — tekrar tetiklenmez (kaydedilir).
  final Set<String> _achievedMilestones = {};

  /// Derin kıtlık bir kez ilan edildi mi (günce satırı + bildirim tekrarlamasın).
  bool _famineShown = false;

  /// Açılışta oyuncunun verdiği köy adı (kimlik/günce; oynanışa etki yok).
  String _villageName = 'Köy';

  /// İlk ateş kurulduktan sonra, köy gerçek haritada görünürken açılan kimlik
  /// kartı. Açılış sinematiği artık isim formunu taşımıyor.
  bool _villageNamePromptOpen = false;
  final _villageNamePromptCtrl = TextEditingController();
  final _houseNamePromptCtrl = TextEditingController();

  /// Açılış sinematiği bitince oyuncu ateş yerini haritada seçmeli mi.
  bool _introPlaceFire = false;

  /// Kafilenin yükü seçildi mi (sinematiğin ilk kapısı). Sinematik atlanırsa
  /// false kalır → kapanışta varsayılan yük uygulanır.
  bool _foundingChoiceMade = false;

  /// Kafilenin haritaya giriş noktası (EKRAN eksenlerinde: u=c−r, v=c+r).
  /// Kuruluş kararı kadroyu değiştirdiğinde kafile yeniden doğar; aynı yerden
  /// doğmazsa kameranın ilk-frame kilidi (bkz. scene_input `_clampCamera`)
  /// eski kalbe takılı kalır ve kurucular kadrajın kenarına düşer.
  double _caravanU = 0, _caravanV = 0;
  bool _caravanEntrySet = false;

  // ── Düğün yaşam döngüsü (scene_wedding) ──────────────────────────────────
  /// Şu an kur yapan/nişanlı çift — aynı evde, karşı cins, kan bağı yok, ikisi
  /// de henüz evlenmemiş. Kur olgunlaşınca düğün dilekçesi bunlara bağlı sunulur.
  VillagerEntity? _brideElect;
  VillagerEntity? _groomElect;

  /// Kur olgunlaşma sayacı (sn) — 0'a inince düğün dilekçesi sunulur.
  double _courtshipTimer = 0;

  /// Kur taraması throttle'ı.
  double _weddingScan = 0;

  /// Düğün dilekçesi sunulurken bağlanan çift (resolution bunları sahneler).
  (VillagerEntity, VillagerEntity)? _weddingCouple;

  /// Yaşam-evresi geçiş taraması throttle'ı (reşit oluş/yaşlanma → yaşam öyküsü).
  double _lifeStoryScan = 0;

  /// İlk ateş kurulunca "ateş yakma" sinematiği oynatılsın mı (bir kez).
  bool _firstFirePending = false;

  /// Sinematik kapandıktan sonra kısa süre canvas yerleştirmesini yok say —
  /// "ilerle" için atılan artçı dokunuşun ateşi kazara kurmasını önler.
  double _placeGuardUntil = 0;

  /// Açılış sinematiğinde köye + haneye ad verildi.
  ///
  /// Köyün adı artık yalnız günceye yazılan bir süs değil: KAYIT SLOTUNUN adı
  /// olur (menüdeki kart "Köy" değil "Pınarköy" der). Hane adı ise kurucuların
  /// soyadı olarak dünyaya işlenir — hane kartları, meclis masası, dilekçeler
  /// hep onu konuşur. [house] boşsa kuruluşta atanan rastgele soyad korunur.
  ///
  /// Ad artık yalnız kayda düşmez: havuzdan geldiyse NEDEN o ad olduğu da
  /// kroniğe yazılır (bkz. text/village_names.dart). Köyün ilk kaydı bir etiket
  /// değil, bir gerekçe olur — "Pınarbaşı: suyun gözü tam burada açılır."
  void _onVillageNamed(String name, String house) {
    setStateHere(() {
      final village = name.trim().isEmpty ? 'Köy' : name.trim();
      _villageName = village;
      _slotName = village;
      _villageNamePromptOpen = false;
      final meaning = meaningOfVillageName(village);
      _chronicle(
        meaning == null
            ? 'Bu yurdun adı kondu: $village.'
            : 'Bu yurdun adı kondu: $village. $meaning',
        icon: '🏷️',
        milestone: true,
      );
      if (house.trim().isNotEmpty) {
        _renameFoundingLineage(house.trim());
        _chronicle(
          'Ocağın adı: ${house.trim()} Hanesi',
          icon: '🏠',
          milestone: true,
        );
      }
    });
  }

  /// Kafilenin yükü seçildi (sinematiğin ilk kapısı) — kadro + stok dünyaya
  /// işlenir. Oyuncu seçmeden atlarsa [_onCutsceneDone] varsayılanı uygular.
  void _onFoundingChoice(FoundingChoice c) {
    _foundingChoiceMade = true;
    setStateHere(() {
      _applyFoundingChoice(c);
      _chronicle('${c.icon} ${c.title}', icon: '🛒');
    });
  }

  /// Sinematik bittiğinde — overlay'i kapat; açılışsa oyuncuyu ateş yeri
  /// seçimine (gerçek harita) yönlendir.
  void _onCutsceneDone() {
    setStateHere(() => _activeCutscene = null);
    // Kapanış sinematiği bitti → karne ekranı. Bayrağı burada düşürmek şart:
    // `_reckoned` bunu okuyor ve build bir sonraki karede ekranı açar.
    if (_reckoningPlaying) {
      setStateHere(() => _reckoningPlaying = false);
      return;
    }
    if (_introPlaceFire) {
      _introPlaceFire = false;
      // Sinematik ATLANDIYSA kapılar hiç açılmamış olur; köy yine de bir
      // kararla kurulmalı — varsayılan yük uygulanır (kadro/stok boşta kalmaz).
      if (!_foundingChoiceMade) {
        _foundingChoiceMade = true;
        _applyFoundingChoice(FoundingChoice.fallback);
      }
      _firstFirePending = true;
      setStateHere(() {
        _placing = BuildingType.firepit;
        _stepBeacon = null;
      });
      // Oyuncunun o an ulaşabildiği alanı tek kadrajda görsün; haritanın
      // tamamını açmıyoruz, _minZoomForReach mevcut reveal sınırını koruyor.
      if (_viewSize.width > 0 && _viewSize.height > 0) {
        _zoom = _minZoomForReach(_viewSize);
        _clampCamera(_viewSize);
      }
      _placeGuardUntil = _time + 0.7; // artçı "ilerle" dokunuşunu yut
      _showNotification('🔥 İlk ateş: köyün içinde uygun bir yere dokun.');
    }
  }

  /// Geçici moral etkileri — politika olaylarından (göçmen uyumu, aile birleşimi).
  /// Her giriş (untilSim, amount). _time geçince düşer; aktiflerin toplamı
  /// `_eventMorale`'ye eklenir.
  final List<({double untilSim, double amount})> _policyMoraleEffects = [];

  /// Kararların mirası — büyük yönetişim kararlarının köy ruhunda bıraktığı
  /// KALICI iz (geçici nudge'ın aksine sönmez). Milestone fx'ler birikir
  /// ([_legacyOf]), ±0.12 ile sınırlı (cozy: hükmün ağırlığı hissedilir ama
  /// morali domine etmez). Moral hedefine + HUD tooltip'e + Divan'a yansır.
  double _governanceLegacy = 0;

  // ── Resources ─────────────────────────────────────────────────────────────
  final List<ResourceBox> _resourceBoxes = [];
  final List<HayEntity> _hayEntities = [];
  double _carrierTimer = 0.0;

  /// Nüfus yiyecek tüketimi için kesirli birikim (≥1 olunca stoktan düşülür).
  double _foodHunger = 0.0;

  // Gün sayacı — timeOfDay 1.0'ı geçip sardığında artar.
  int _dayCount = 1;
  double _lastTimeOfDay = 0.0;

  /// Aktif mevsim — gün sayacından türetilir (ayrı state yok, save/load bedava).
  Season get _season => seasonForDay(_dayCount);

  /// Mevsim dönümünü yakalamak için son görülen mevsim. null → ilk tick'te
  /// sessizce kurulur (yüklemede/başlangıçta sahte olay tetiklenmez).
  Season? _lastSeason;

  // ── Spatial cache (her frame yeniden kurulmaz; kSpatialRebuildInterval) ──────
  // Engel/yumuşak-engel/kuyu/yasak set'leri yavaş değişir; throttle'lı yenilenir.
  final Set<(int, int)> _obstacles = {};
  final Set<(int, int)> _softObs = {};
  // 1-tile genişlikte engel koridorları (karşılıklı komşuları blocked).
  // PathContext bu tile'ları yüksek cost'la pahalı yapar → A* mümkünse
  // etrafından dolaşır. Block DEĞİL: tek geçit oraysa NPC yine geçer.
  final Set<(int, int)> _squeezeTiles = {};
  final Set<(int, int)> _forbiddenForTrees = {};
  double _spatialTimer = 0.0;

  // HUD için "yolda" kaynak sayımları — her frame tek geçişte hesaplanır
  // (build içinde 5 ayrı .where().length yerine).
  int _woodInTransit = 0,
      _stoneInTransit = 0,
      _ironInTransit = 0,
      _coalInTransit = 0,
      _foodInTransit = 0;

  /// Kesilip yere düşen kütük sayısı. Başlangıç stoğundan ayrı tutulur: ilk
  /// oduncu görevi kulübenin dikildiğini değil, işin gerçekten başladığını
  /// doğrular.
  int _woodHarvested = 0;

  // Köy morali — PASİF BİRİKİM GÖSTERGESİ. Ekonomiden türemez; olay/eylem/
  // politika hedefe doğru iter, _morale yavaşça oraya süzülür ve tabana döner.
  // Hiçbir oyun mantığı bunu okumaz — yalnızca HUD/panel gösterir (_stats.morale).
  double _morale = 0.5;

  // Köylülerin ortalama BİREYSEL morali (0..1) — scene_estates._tickVillagerMorale
  // her tick günceller; köy moraline (moraleTarget) ve panele beslenir.
  double _avgIndividualMorale = 0.6;

  // ── Reaktif ortam (sürekli canlılık) ─────────────────────────────────────
  double _spontaneousTimer = 0; // ara sıra rastgele NPC'ye küçük gövde refleksi
  bool _lastRainy = false; // yağmur geçiş tespiti (başla/dur reaksiyonu)
  bool _wasStarving = false; // açlığa giriş tespiti (bir kerelik reaksiyon)

  // ── Rastgele olaylar ───────────────────────────────────────────────────────
  double _eventTimer = kEventFirstDelay; // bir sonraki olaya kalan süre
  double _eventMorale = 0.0; // aktif geçici moral etkisi (+/−)
  double _eventMoraleLeft = 0.0; // o etkinin kalan süresi (sn)
  String? _eventLabel; // aktif geçici olayın HUD etiketi
  // Pop-up event banner — son tetiklenen olay; ekran ortasında zengin kart.
  EventOutcome? _activeEvent;
  double _activeEventLeft = 0.0;

  // Karar bekleyen olay — KAPIDA KUYRUK modeli: modal kendiliğinden AÇILMAZ,
  // sim DURMAZ. Olay vurunca HUD'a karar mührü iner (tükenen mühlet halkası),
  // oyuncu mühre tıklayınca modal açılır (_choiceModalOpen). Mühlet dolarsa
  // köy pasif seçeneği kendi yaşar (EventOutcome.timeoutChoice) — müdahale
  // asla kendiliğinden olmaz, ama dünya da sonsuza dek nefesini tutmaz.
  EventOutcome? _pendingChoice;
  bool _choiceModalOpen = false;
  // Kalan/toplam mühlet (oyun sn) — mühür halkası remain/grace okur.
  double _choiceDeadline = 0;
  double _choiceGrace = 1;
  // Son %34'e girerken BİR KEZ hatırlatma düşer (uyarı rampası: kayıp
  // sessizce gelmez). Yeni olay kuyruğa girince sıfırlanır.
  bool _choiceUrgentWarned = false;

  // ── Olay mayalanması (omen) — scene_events ──────────────────────────────────
  // Olay ANINDA patlamaz: önce birkaç saniyelik diegetik uyarı (haberci metni +
  // hafif fx ön-titreşimi + köy tedirginliği) yaşanır, sonra olay vurur. "Yoktan
  // belirme" hissini kırar — oyuncu geleni sezer, hatta hazırlanır.
  EventOutcome? _omenEvent;
  double _omenLeft = 0;

  // ── Olay vinyeti (scene_vignette) ──────────────────────────────────────────
  // Her rastgele olayın DÜNYADA izlenebilir hâli: rolleri ve adımları olan bir
  // NPC sahnesi (kuyudan boş çıkan kova, sokakta çöken hasta, kova zinciri).
  // Kadro `IntentPriority.ceremony` ile dayatılır → salıverme ŞART, tek kapısı
  // `_releaseVignette`. Detay ve tuzak: scene_vignette.dart başlığı.
  Vignette? _vignette;
  // "İzle" kamerası: bir vinyetin odağına yumuşak kayış. `_watchLeft > 0` iken
  // her tick lerp'lenir; manuel pan (scaleStart) ya da sahne bitişi düşürür.
  double _watchX = 0, _watchY = 0;
  double _watchLeft = 0;

  // ── Dilekçe / Meclis (scene_petitions) ─────────────────────────────────────
  // Ambient yönetişim: köy periyodik dilekçe sunar, HUD'da mühür belirir.
  // Modal açıkken de oyun DURMAZ; modal yalnız oyuncu mühre tıklayınca açılır.
  Petition? _pendingPetition;
  Petition? _queuedPetition;
  double _queuedPresentDelay = 0;
  bool _petitionModalOpen = false;
  // Mühlet doldu → KAPIDA BEKLEYEN HUZUR: sim durmaz, modal zorla açılmaz.
  // Sözcü köy merkezinde bekler, mühür kalıcı kızarır ve bekletmenin bedeli
  // GÜN BAŞINA işler (_tickOverduePetition). Otomatik ret YOK — karar yine
  // oyuncunundur; yalnız donma kalktı. (Rejim yolları bundan önce çalışır:
  // baskı rejimi dilekçeyi sessizce düşürür, hür rejimde meclis kendi çözer.)
  bool _petitionOverdue = false;
  // Gecikme sayacı — her dolan oyun gününde bedel yinelenir.
  double _petitionOverdueTimer = 0;
  double _petitionTimer =
      1.0 * kGameDaySeconds; // ilk dilekçe ~1 oyun günü sonra
  double _petitionDeadline = 0;
  // Zincir: tetiklenmiş takip dilekçeleri (id + ne zaman geleceği sim time).
  /// Zincirin bir sonraki halkası: ne zaman, hangi dilekçe ve KİMİN ağzından.
  /// [actor] ilk halkayı getiren köylüdür — zincir boyunca aynı yüz konuşsun
  /// diye taşınır (ölmüş/gitmişse null'a düşer ama [actorName] metinde kalır:
  /// "yola çıkan dönmedi" cümlesi ancak adı bilinirse kurulabilir).
  final List<
    ({String id, double fireAtSim, VillagerEntity? actor, String actorName})
  >
  _petitionFollowUps = [];
  // Hafıza: çözülen dilekçe id → cooldown sim time (aynısı hemen random çıkmasın).
  final Map<String, double> _petitionCooldowns = {};
  // Köyün kalıcı hafızası: geçmiş kararların bıraktığı bayraklar (ör. 'cult.active').
  // Dilekçeler bunu okuyup dallanır; köyün "öyküsü" burada birikir.
  final Set<String> _villageMemory = {};
  // Köyün bildiği zanaatlar (bkz. buildings/craft.dart). Bir bina, arkasındaki
  // zanaat burada olmadıkça dikilemez. Baştan BOŞ — köy yalnız ortak survival
  // kitini (çadır/ateş/kuyu/depo/oduncu) bilir; gerisi insanlardan organik doğar.
  final Set<String> _knownCrafts = {};
  // Bekleyen dilekçeyi GETİREN gerçek köylü (rastgele değil — kim olduğu bilinir).
  // Modal portresinde gösterilir; tıklanınca bilgi/aile paneli açılır.
  VillagerEntity? _petitionAuthor;
  // Bekleyen dilekçenin metnine dokunacak ek bağlam ({suçlu}, {suç}, {yer}…).
  // Sunum anında bir kez kullanılır; sonra temizlenir.
  Map<String, String> _petitionExtra = const {};

  // ── SUÇ (scene_crime) ──────────────────────────────────────────────────────
  // Sahnede aynı anda TEK suç yürür — köy suç çukuru değil; nadir, tekil ve
  // izlenebilir bir an. Yakalanan fail Meclis'e çıkar (yargı dilekçesi).
  _ActiveCrime? _activeCrime;
  double _crimePollSec = 0;
  // Muhafızın kovalama hedefini tazeleme sayacı (fail kaçarken).
  double _chaseRefresh = 0;
  // Suç başlayalı kaç sn oldu — muhafızın "fark etme" gecikmesi buradan okunur.
  double _crimeNoticed = 0;
  // MEÇHUL kalan suçların biriktirdiği şüphe — eşiği aşınca asayiş dilekçesi.
  int _crimeSuspicion = 0;
  // Köyde bugüne dek İŞLENMİŞ suç sayısı (yakalansın yakalanmasın, sönsün ya da
  // sönmesin). Şüphe gibi düşmez — köyün hafızası. NİZAM kolunun kapıları buna
  // bakar: suç görülmeden ceza kanunu yazılmaz (bkz. law_book gate'leri).
  int _crimesSeen = 0;
  // Köyde bugüne dek görülmüş hastalık atağı (veba dahil). Tecrit Fermanı'nın
  // kapısı buna bakar — köy hastalıkla tanışmadan tecrit konuşulmaz.
  int _illnessSeen = 0;
  // Köydeki çocuk sayısı — SES aksanı için, HUD ile aynı 10Hz'de sayılır
  // (bkz. scene_tick). Simülasyon bu sayıyı okumaz, kayda da girmez.
  int _childCount = 0;
  // Kan davası doğuran ölümcül kavga sayısı. Diyet Fermanı'nın kapısı.
  // Sulh olsa da düşmez: köy o kanı bir kez gördü.
  int _feudsSeen = 0;
  // Kaç kez af çıktı — merhametin politik bedeli (suç baskısını artırır).
  int _crimePardons = 0;

  // ── PROVA SAYAÇLARI (scene_probe) — davranışın uçtan uca çalıştığını sayıyla
  // görmek için. Ucuz int'ler; harness bunları okuyup köyün yaşadığını kanıtlar
  // (tek tek NPC izlemeye gerek kalmadan). Normal oyunda yalnız artarlar.
  int _probeWitnessed = 0; // gözüyle suç/kavga/ölüm gören köylü-olay sayısı
  int _probeGossip = 0; // ağızdan ağza aktarılan haber sayısı
  int _probeInformed = 0; // muhafıza teslim edilen ihbar sayısı
  // Suçüstü yakalanıp hüküm bekleyen fail (yargı dilekçesi buna bakar). Suçun
  // ADI dilekçe metnine _petitionExtra ile dokunur; hüküm faile uygulanır.
  VillagerEntity? _accusedCriminal;
  // Capture harness: yargı seçeneklerini sırayla denemek için sayaç (test).
  int _captureVerdictTurn = 0;
  // Capture harness: kürek cezası (NİZAM) kaç kez uygulandı — taş kazanımı
  // örnekleme aralığında görünmese bile bu sayaç kanıtlar.
  int _captureLaborCount = 0;
  // Mahkûm emeğinin kesirli taş biriktiricisi — günlük akış tam sayı taşa
  // ulaşınca stoğa yazılır (bkz. _tickConvictLabor). Kaydedilmez (küçük/geçici).
  double _convictStoneAcc = 0.0;
  // Kaçırılan (rehin) köylü — fidye ödenirse sahneye döner. _villagers'ta DEĞİL.
  // Kayıt sözleşmesi: rehin kaydedilmez (bkz. scene_save) — kayıttan dönünce
  // kaybolmuş sayılır.
  VillagerEntity? _ransomVictim;

  // ── Kanunname (scene_ui: _sealLaw) ─────────────────────────────────────────
  // Oyuncu AJANSI artık yasa defteri. "Meclis Çağır" düğmesi kaldırıldı: meclis
  // bir aksiyon değil, İMZANIN KENDİSİ. Bir fermanı defterin önüne koyduğunda
  // (_lawRitual != null) dört zümre masaya oturur, yüzünü gösterir; mühür basılı
  // tutularak basılır ve GERİ ALINMAZ.
  LawDef? _lawRitual; // != null → mühür ritüeli açık
  // Son mühürün toplam müzakere süresi — defterdeki halka bunun oranını çizer.
  double _inkDryTotal = 0;

  // ── Defterin KADEMELİ AÇILIMI (scene_ui: _tickLawGates) ────────────────────
  // Bir hüküm, derdi köyde doğmadan deftere düşmez. Kapılar köyün hâlinden
  // okunur (LawContext); bağlam pahalı olduğundan saniyede bir tazelenir.
  LawContext? _lawCtxCache;
  double _lawCtxAge = 0;

  /// Bugüne dek gündeme GELMİŞ hüküm id'leri — bir hüküm iki kez duyurulmaz.
  /// Kaydedilir; yoksa her yüklemede bütün defter "yeni açıldı" diye bağırır.
  final Set<String> _lawSeen = {};

  /// İlk tarama yapıldı mı — köyün başlangıç gündemi sessizce içeri alınır.
  bool _lawSeeded = false;

  // ── REJİM (scene_regime) ───────────────────────────────────────────────────
  // Pusulanın oyuncuya dokunan yarısı: kimliğin bedeli. Huzursuzluk rejimin
  // kendi doğasından birikir (Ilımlı Köy'de hiç birikmez — merkez cezasızdır),
  // eşiği aşınca rejime özgü kriz doğar. Yemin edilen rejim `_villageMemory`
  // bayrağında durur (ayrı doğruluk kaynağı yok), yalnız günü burada tutulur.
  double _unrest = 0.0;
  double _regimeScan = 0; // huzursuzluk poll sayacı (2 sn)
  double _crisisCooldown = 0; // krizler arası nefes (sim sn)
  bool _unrestStirShown = false; // "köy homurdanıyor" uyarısı bir kez
  /// Yürüyen kriz dilekçesinde şık başlığı → huzursuzluk deltası. Kriz
  /// sunulurken dolar, karar verilince tükenir (anlık, kaydedilmez).
  Map<String, double> _regimeCrisisUnrest = const {};

  /// ÇÜRÜME — huzursuzluğun bıraktığı KALICI iz (bkz. Regime.rotStep). Yavaş
  /// birikir, daha yavaş silinir; eşiği aşınca rejime özgü KRONİK hâl doğar
  /// (süregiden bedel, tek atımlık kriz değil). Oyun-sonu değil: çıkışı var.
  double _regimeRot = 0.0;

  /// Kronik hâl duyurusu bir kez yapılsın (girişte + çıkışta).
  bool _chronicShown = false;

  // ── KÖYÜN HÂLİ (world_pressure) ────────────────────────────────────────────
  // Yasa/rejim/mevsim/huzursuzluk → TEK davranış tablosu. Rutin, iş, suç,
  // devriye, gövde dili ve meşale artık yasaya değil buraya bakar; yani mühür
  // basmak aşağıda gözle görülen bir değişiklik demek. `_recomputePressure`
  // ucuz (34 hüküm üstünde tek geçiş) ama her kare gereksiz — 1 sn'de bir ve
  // mühür/yemin/mevsim değişiminde tazelenir.
  WorldPressure _pressure = WorldPressure.neutral;
  double _pressureScan = 0;

  /// Dürtü tazeleme sayacı (bkz. scene_mind).
  double _driveScan = 0;

  /// Suç iklimi — tur başına bir kez hesaplanan köy-geneli çarpan (scene_mind).
  /// Köylü başına hesaplamak tur başına onlarca gereksiz liste ayırıyordu.
  double _crimeClimate = 0;

  /// Prova rapor sayacı (scene_probe).
  double _probeTimer = 0;

  /// Hafıza sönme tarama sayacı (bkz. scene_perception).
  double _perceptionScan = 0;

  // ── Haneler (soylar) — köyün politik birimi (eski 4-zümre sistemi söküldü;
  // `Estate` enum yalnız meslek-sınıflandırması olarak kaldı). Her köylü
  // surname'iyle bir haneye ait; hane üye moralinden doğar/güçlenir; dilekçe/
  // ferman/olay kararları hanelerin mood+sway'ini oynatır.
  final HouseSystem _houses = HouseSystem();

  /// Küskün hane postürü poll sayacı — ~5s aralıkla diegetik somurtma.
  double _estateMoodScan = 0;

  // ── Hane karşılığı (bkz. systems/house_stance + scene_house_stance) ────────
  // Hanenin sana ne verdiği / neyi geri çektiği. Duruş türetilmiştir (mood +
  // nüfuz payı), KAYDEDİLMEZ — mood/sway/stash kayıttan gelince kendi doğar.

  /// Soyad → en son DUYURULAN duruş. Merdiven basamağı değiştiğinde köy
  /// konuşsun diye tutulur; sessiz kaymalar (aynı basamakta ince oynama)
  /// bildirim üretmez.
  final Map<String, HouseStance> _houseStanceSeen = {};

  /// Duruş tarama sayacı (sn) — merdiven basamağı bu aralıkla yoklanır.
  double _houseStanceScan = 0;

  /// Hanelerin sakladığı ambarların geri akışı için gün kesri biriktirici.
  double _stashReturnAccum = 0;

  /// Yiyecek girişlerinin KESİR artığı. Hane payı/ikramı kesirli olabilir
  /// (1 balık × %45 saklama); artık burada birikir, bir kile bile yok olmaz.
  double _foodCarry = 0;

  /// "Hane ambarını açtı" bildirimi soğuması (sn) — geri akış birkaç gün
  /// sürdüğünden her taramada tekrar duyurulmasın.
  double _stashOpenedCd = 0;

  // ── Kaybetme eşiği (bkz. systems/village_collapse + scene_collapse) ───────

  /// Köyün BUGÜNE DEK gördüğü en yüksek yetişkin sayısı. "Ancak kurduğunu
  /// kaybedersin" kuralının filigranı — kuruluş kadrosu uyarı üretmesin.
  int _peakAdults = 0;

  /// Dağılma geri sayımında geçen oyun günü. Köy toparlanınca sıfırlanır.
  double _collapseCountdown = 0;

  /// Köyün o anki ayakta kalabilirliği — HUD şeridi bunu okur.
  CollapseState _collapse = const CollapseState(
    vitality: VillageVitality.healthy,
  );

  /// En son DUYURULAN evre — aynı evrede tekrar konuşulmasın.
  VillageVitality _vitalitySeen = VillageVitality.healthy;

  /// Köy dağıldı mı — true ise sim durur ve mezar taşı ekranı açılır.
  bool _collapsed = false;
  CollapseCause? _collapseCause;

  /// Ayrılık son uyarısı verilmiş haneler (hane başına bir kez).
  final Set<String> _schismWarned = {};

  // ── Hesaplaşma (bkz. systems/reckoning + scene_reckoning) ────────────────
  //
  // Dağılmanın simetriği: koşunun KAZANILABİLİR kapanışı. Alanlar dağılma
  // bloğunun hemen ardında duruyor çünkü ikisi tek bir soruyu paylaşır —
  // bu köyün defteri nasıl kapandı.

  /// Berat yılı ilan edildi mi (bir kez, [kReckoningHeraldYear] yılında).
  bool _reckoningHeralded = false;
  int _karneYear = 0;

  /// Verilen karar. null = koşu sürüyor. Doluysa oyun bitmiştir.
  ReckoningVerdict? _reckoningVerdict;

  /// Kapanış sinematiği hâlâ oynuyor mu — bitince kapanış ekranı açılır.
  /// Karar ile ekran arasındaki bu tampon olmazsa sinematik hiç görünmez.
  bool _reckoningPlaying = false;

  /// Karneyi besleyen girdiler — karar ANINDAKİ hâl. Ekran bunu yeniden
  /// hesaplamaz: sim durduktan sonra okunan değerler kararı vereni yansıtmaz.
  ReckoningInput? _reckoningInputCache;

  /// Hesaplaşma tarama sayacı (sn).
  double _reckoningScan = 0;

  // ── Orta oyun dersleri (bkz. systems/village_lessons + scene_lessons) ─────

  /// Görülmüş dersler — bir ders bir kez açılır. KAYDEDİLİR: yüklenen köyde
  /// oyuncuya kışı ikinci kez anlatmak, öğretmek değil dırdır etmektir.
  final Set<String> _lessonsSeen = {};

  /// Ekranda duran ders kartı (null = yok).
  Lesson? _activeLesson;

  /// Ders tarama sayacı + kartlar arası nefes payı (sn).
  double _lessonScan = 0;
  double _lessonGap = 0;

  /// Ayakta kalabilirlik tarama sayacı + gün kesri biriktirici (sn).
  double _vitalityScan = 0;
  double _collapseAccum = 0;

  /// Esirgeyen hane üyesinin görünür "işi bıraktı" jesti için sayaç (sn).
  double _withheldGesture = 0;

  /// Köyün kimliği = baskın hanenin baskın hizbi; kimlik mekanik bonuslarını
  /// (_identityFarmMul / _identityYieldMul / _identityFoodMul /
  /// _identityMoraleBonus) besler. null = baskın hane yok (nötr, "Dengeli Köy").
  /// `_updateVillageIdentity` (scene_estates) günceller. Kaydedilmez (baskın
  /// haneden yüklemede yeniden türer).
  Estate? _identityEstate;

  // Geliştirici test paneli açık mı.
  bool _devPanelOpen = false;

  // Geliştirici komut konsolu (backtick ile açılır) — buton-başına-closure
  // yerine tek kayıt defteri + arama + parametre + kayıt/oynatma.
  bool _devConsoleOpen = false;
  final DevRecorder _devRecorder = DevRecorder();
  final List<DevScript> _devUserScripts = [];
  final FocusNode _devKeyFocus = FocusNode(debugLabel: 'devConsoleHotkey');

  // KÖY DEFTERİ — köy içi işlerin tek kapısı: null = kapalı, doluysa o bölüm
  // açık (Divan / Kanunname / Nüfus / Tüzük / Kronik). Eskiden bunlar üç ayrı
  // bayraktı (_divanOpen + _statsPanelOpen + _storyPanelOpen) ve üç ayrı
  // yerden açılıyordu; tek state = aynı anda iki köy panelinin üst üste
  // binmesi de imkânsız. Salt-okunur gösterge; oyun durmaz. scene_world
  // reset'te kapanır.
  LedgerSection? _ledgerSection;

  // Ana menüye dönüş onay modal'ı açık mı.
  bool _exitConfirmOpen = false;

  // Kan davası yargısı onay bekliyor mu — (hedef köylü, idam mı/sürgün mü).
  // null = kapalı. scene_ui.buildJudgmentConfirm bunu okur.
  (VillagerEntity, bool)? _pendingJudgment;

  // Alt-sol menü kümesi (menü/kaydet/📖) açık mı — gear ile aç-kapa, varsayılan kapalı.
  bool _menuClusterOpen = false;

  // ── Köy Akışı (görev defteri + politika-odaklı Tüzük kademesi) ────────────
  // Tamamlanmış görev id'leri (yeni tamamlanan → görsel ödül + bildirim).
  final Set<String> _completedQuests = {};
  // Köyün kimlik kademesi (charterTier) — politika+görevle ilerler, asla gerilemez.
  int _charterTier = 0;
  // _tickFlow throttle sayacı.
  double _flowScan = 0;

  /// HUD şeridinin gösterdiği "şu anki adım" — `_tickFlow` tazeler (build'de
  /// hesaplanmaz; bkz. scene_flow `_currentStep`).
  QuestState? _stepCache;

  /// Akış taraması kaç kez koştu — teşhis (bkz. kFlowDebug).
  int _flowScans = 0;

  /// Şu anki adımın DÜNYADAKİ hedefi (ızgara koordinatı) — çizim oraya sakin
  /// bir işaret koyar (bkz. scene_flow `_refreshStepBeacon`). Kişi hedefli
  /// adımlar burayı kullanmaz, köylünün kendi halkasını yakar.
  (double, double)? _stepBeacon;

  // ── Kuruluş öğreticisi (bkz. scene_guide.dart) ────────────────────────────
  // Spot yalnız kademe 0'da çalışır ve adım başına BİR kez kendiliğinden açılır;
  // sonrası oyuncunun "Göster" düğmesine kalır.

  /// Otomatik spotu görmüş adımlar — kayıtta saklanır, yükleyince tekrarlamaz.
  final Set<String> _guideShown = {};

  /// Spot ekranda mı.
  bool _guideOpen = false;

  /// Spot AÇILMAK İSTİYOR ama hedef henüz çözülmedi (kamera kayıyor, panel
  /// kapalı, köylü ekran dışında). İstek ile açılış ayrı tutulmazsa spot ya
  /// hiç açılmaz ya da yanlış yere delik açar.
  bool _guideWanted = false;

  /// Sürücünün en son gördüğü adım — değişince spot sıfırlanır.
  String _guideStepId = '';

  /// Yeni adımdan sonra spotun beklediği süre (önce köyün sesi, sonra parmak).
  double _guideDelay = 0;

  // ── KIŞ (bkz. scene_winter.dart + systems/winter.dart) ────────────────────

  /// Dokunmuş ama HENÜZ DAĞITILMAMIŞ kışlık giysi. Sırtlara `_distributeCoats`
  /// dağıtır; oyuncunun önceliği ([_coatPriority]) kimin önce giyineceğini
  /// söyler.
  int _coatsMade = 0;

  /// GİYSİ KİME? Kışın tek gerçek dağıtım kararı — köy kendiliğinden "en
  /// doğru"yu yapmaz, oyuncunun dediğini yapar ve sonucu kışın görünür.
  CoatPriority _coatPriority = CoatPriority.frail;

  /// Yakacak yetmediği için ocağı sönen haneler (kışın, gün başına hesaplanır).
  final Set<BuildingEntity> _coldHouses = {};

  /// Kış muhasebesi sayaçları — tarama, gün ve yıl anahtarları.
  double _winterScan = 0;
  int _winterDay = -1;
  int _shearYear = -1;
  int _winterEveDay = -1;
  int _winterMurmurDay = -1;

  /// Kışın sesi: mevsim başı hatırlatmasının yılı ve kıtlık mırıltısının günü
  /// (bkz. scene_winter `_maybeWinterVoice`). Kış artık ekranda duran bir
  /// kartla değil köyün ağzıyla anlatılıyor; bu iki anahtar aynı şeyin iki kez
  /// söylenmesini engeller.
  int _winterPrepYear = -1;
  int _winterPinchDay = -1;

  /// Köyün ilk kırkımı / ilk kışlığı duyuruldu mu (bir kereye mahsus tören).
  bool _firstShearShown = false;
  bool _firstCoatShown = false;

  /// Görev kartı açık mı — null = OTOMATİK (kuruluşta açık, köy kurulunca ince
  /// banda döner). Oyuncu bir kez dokunduysa kararı onundur, otomatiğe dönmez.
  bool? _questCardOverride;

  // ── Köyün sesi (kuruluş) ──────────────────────────────────────────────────
  // Adımı İSTEYEN kurucu onu dünyada söyler, biten adıma da o karşılık verir.
  // Görev listesi bir alışveriş listesi değil, köyün insanlarının istekleri —
  // ama bu şimdiye kadar yalnız panelde bir isim satırıydı.
  VillagerEntity? _questVoiceWho;
  String _questVoiceLine = '';
  double _questVoiceLeft = 0;
  double _questVoiceLife = 1;

  // ── Köyün âdeti (bkz. systems/village_custom.dart) ────────────────────────
  // Âdete aykırı atamada öğretici uyarı ROL BAŞINA bir kez çıkar; oyuncu dersi
  // aldıktan sonra aynı cümleyi her atamada okumak zorunda kalmasın (kural
  // değil huy olduğu için ısrar etmez). Rol adları tutulur.
  final Set<String> _customLessons = {};

  /// Köyün ilk sıcak yemeği duyuruldu mu (bkz. scene_forage) — kuruluşun
  /// küçük törenlerinden biri, bir kez çıkar. Aynı zamanda "ilk yemek" kuruluş
  /// görevinin kapısı (bkz. quest_book `everCooked`).
  bool _firstMealShown = false;

  /// Kümülatif toplanmış böğürtlen sepeti. Kuruluş görevi STOĞA değil buna
  /// bakar; stoğa bakılsaydı yenen yiyecek görevi geri almış gibi görünürdü.
  int _berriesPicked = 0;

  // Sosyal canlılık — bağlama duyarlı, dağıtık yoğunluk.
  // Her NPC kendi cooldown'unda bağımsız değerlendirilir; global cap yok.
  // Bağlam çarpanları (pazar/taverna/ateş/gece/yağmur) per-NPC ihtimalini
  // ayarlar → nüfus arttıkça doğal olarak köy daha canlı olur, dağıtık
  // bölgeler sessiz kalır.
  double _socialScanTimer = 0;

  /// NPC rutin (errand) tarama sayacı — scene_npc_routine.
  double _routineScan = 0;
  static const double _kSocialScanInterval =
      3.0; // her NPC için 3 sn'de bir bak

  // Ateş başı toplanma + hikaye saati (scene_firepit_gather) timer'ları.
  // Tick periyotları extension içinde sabit; field'lar burada tutulur.
  double _storyScanTimer = 0;

  // Kişisel anlar (yıldönümü) tarama sayacı — scene_personality.
  double _annivScan = 0;

  // Hastalık başlangıç taraması sayacı — scene_illness (nadir onset).
  double _illnessScan = 0;

  // "Çağrısını buldu" (genç→yetişkin meslek keşfi) tarama sayacı.
  double _callingScan = 0;
  // Dostluk anı tarama sayacı + kutlanan çiftler (kişilikSeed çifti anahtarı).
  // Kutlama kozmetik → kaydedilmez; yüklemeden sonra en fazla bir kez tekrarı
  // zararsız (cozy, spam'siz zaten seyrek).
  double _bondScan = 0;
  final Set<String> _bondSeen = {};
  // Zanaat keşfi tarama sayacı (birikim kanalı — mastery eşiği kontrolü).
  double _craftScan = 0;

  // Çekişme/kavga tarama sayacı — scene_conflict (nadir, faktöre bağlı).
  double _conflictPollSec = 0;
  // Gerginlik uyarısı throttle (sn) — köy gerginliği yükselince oyuncuya
  // diegetik herald gösterilir (kavga patlamadan önce görünür kılınır).
  double _tensionHeraldSec = 0;

  // Konfor talebi sayacı — köy ara sıra surplus konfor malını şölene çevirir
  // (bal/fazla yiyecek → moral). Pozitif sink, ceza yok. scene_firepit_gather.
  double _comfortTimer = 1.2 * kGameDaySeconds;

  // Dev: simülasyon hız boost'u. Normal _timeScale ile çarpılır. 1.0 = normal,
  // 30.0 = hızlı denge testi. DevPanel slider'ı set eder.
  double _devSpeedBoost = 1.0;

  // Dev: 5 sn'de bir kaynak/nüfus snapshot — denge analizi için. Son 30
  // snapshot tutulur, grafik/tablo gösterilir.
  final List<SimSnapshot> _simHistory = [];
  double _simSnapshotTimer = 0;
  static const int _kMaxSnapshots = 30;
  static const double _kSnapshotInterval = 5.0;

  // Otomatik senaryo testi durumu.
  String? _scenarioName; // çalışan senaryonun adı (null = pasif)
  double _scenarioProgress = 0;
  ScenarioReport? _lastReport;

  // Aktif sahne efektleri — banner'dan bağımsız, sahnede partikül/overlay
  // çizen ve simülasyona multiplier uygulayan etkiler. Bir tick'te aşağıdaki
  // alanlara aggregate edilir.
  final List<ActiveFx> _activeFx = [];
  // Aggregate cache (her tick yenilenir):
  Color _fxTint = const Color(0x00000000); // ekran üstüne overlay
  double _fxRainBoost = 0.0; // min rain intensity zorlaması
  double _fxNpcSpeedMul = 1.0; // NPC hız çarpanı
  double _fxFarmMul = 1.0; // tarla büyüme çarpanı
  double _fxBuilderMul = 1.0; // inşaatçı çarpanı
  final Set<EventFx> _fxActiveIds = {}; // hangi fx'ler aktif (render için)

  // fireOutbreak fx aktifken yanan spesifik bina(lar). Event tetiklendiğinde
  // rastgele konut/işyeri seçilir, fx süresince işaretli kalır. Painter
  // sprite'ın üstüne alev + yoğun duman çizer.
  final Set<BuildingEntity> _burningBuildings = {};

  // ── God mode ───────────────────────────────────────────────────────────────
  bool _godMode = false;

  /// Performans modu — pahalı ambient efektleri (fireflies, polen, kuş sürüleri,
  /// gölge refinement, light pass detayı) tek tıkla kapatır. Görsel atmosfer
  /// kaybı karşılığında dev FPS kazancı. Test/oynanış sırasında zayıf donanım
  /// yardımı.
  bool _perfMode = false;

  // ── Zaman yönetimi ─────────────────────────────────────────────────────────
  // Simülasyon hızı çarpanı. 0.0 = duraklatılmış (sahne animasyonları da
  // donar, sadece UI canlı kalır), 1×/2×/4× hızlandırma. HUD'daki tek butona
  // basınca cycle eder.
  static const List<double> _speedSteps = [1.0, 2.0, 4.0, 0.0];
  int _speedIdx = 0;
  double _timeScale = 1.0;

  bool _mineMode = false;
  (int, int)? _mineStart;
  (int, int)? _mineEnd;

  bool _farmMode = false;
  (int, int)? _farmStart;
  (int, int)? _farmEnd;

  // ── Notification ───────────────────────────────────────────────────────────
  String? _notification;
  int _notifId = 0;

  // ── Dev olay günlüğü ───────────────────────────────────────────────────────
  // Dev modda ekranda kayan konsol: her random roll / olay tetiği burada bir
  // satır olur. _showNotification otomatik besler; sessiz roll'lar (doğum, suç
  // seçimi, kavga tetiği vb.) açıkça logDev() çağırır. Kapalıyken (_devLogOn
  // false) hiç biriktirmez → normal oyunda sıfır maliyet. God mode'dan bağımsız
  // ayrı bayrak: god mode otomatik olayları durdurur, günlüğü normal oyunda da
  // izleyebilmek için ayrı tutuldu.
  bool _devLogOn = false;
  final List<DevLogEntry> _devLog = [];
  int _devLogSeq = 0;

  // ── İmparatorluk varış anonsu ──────────────────────────────────────────────
  // Kolon harita kenarından yürümeye başlayınca birkaç saniye tam-ekran gergin
  // uyarı ("İMPARATORLUK GELİYOR") belirir. Sim DURMAZ (oyuncu kolonu görür);
  // süre dolunca solup gider. Animasyon _time'dan, geri sayım gerçek dt'den.
  static const double _kImperialAlertDur = 4.6;
  double _imperialAlertLeft = 0.0;
  String _imperialAlertSub = '';

  // ── Frame notifier ────────────────────────────────────────────────────────
  // Tick'te value++ → ListenableBuilder bağlı widget'lar repaint olur.
  // setState() yerine bunu kullanırız: outer Scaffold/PopScope ağacı her frame
  // yeniden inşa edilmez, sadece time-driven leaf'ler.
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);

  // PERF: HUD ayrı, DÜŞÜK frekanslı notifier — GameHUD ağacı pahalı ve verisi
  // (kaynak/nüfus/saat) yavaş değişir. Canvas/gökyüzü 60fps (_frame) kalır,
  // HUD ~10Hz rebuild olur (_hudFrame). _hudAccum gerçek-zaman biriktirir.
  final ValueNotifier<int> _hudFrame = ValueNotifier<int>(0);
  double _hudAccum = 0;
  static const double _kHudInterval = 0.1; // sn (≈10Hz)

  // Ground Picture cache invalidation tokeni — yeni harita üretildikçe artar,
  // painter cache'i bozar. Sadece map içeriği değişince invalidate.
  int _groundVersion = 0;

  // Aktif ışık kaynakları — her tick yeniden hesaplanır (gündüz boş).
  // Hem renderer hem ileride NPC "ışıkta mı?" sorgusu için ortak kaynak.
  List<LightSource> _lightSources = const [];

  // ──────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Backtick (`) global hotkey → dev komut konsolunu aç. Konsol açıkken
    // yut (return true), kapalıyken aç; kapatma konsolun kendi Esc'ine kalır
    // (böylece arama alanına backtick yazılabilir).
    HardwareKeyboard.instance.addHandler(_onDevHotkey);
    // Diske kaydedilmiş dev senaryolarını geri yükle (oturum aşırı kalıcı).
    // `this.` ŞART: metot bir extension'da (scene_dev_console) yaşıyor ve
    // NİTELİKSİZ çağrı extension üyelerini bulmaz (yalnız gerçek sınıf
    // üyelerini arar) — "undefined_method" hatası buradan geliyordu. Lint
    // bunu gereksiz sanıyor, değil.
    // ignore: unnecessary_this
    this._loadDevScripts();
    // Defter her değiştiğinde KÖYÜN HÂLİ tazelensin — oyuncu mührün sonucunu
    // bir sonraki taramayı beklemeden görsün (bkz. scene_pressure).
    // ignore: unnecessary_this
    _policies.onChanged = () => this._recomputePressure();

    // Gece eşiği geçişi — DayNightCycle edge-trigger eder.
    _cycle.onNightFall = () {
      _assignSleepTargets();
      // Berrak gece bayrağı set edildiyse ufak bir tebrik bildirimi.
      // %30 random → seyrek ama hatırlatıcı; cozy/chill tonda.
      if (_cycle.isClearNight) {
        _showNotification('🌌 Gökyüzü açık. Bu gece yıldızlar sayılır.');
      }
    };

    // Tüm worker'ların yol hız çarpanı sorgusu için tek otorite — bir kez set.
    WorkerEntity.roadSystem = _roadSystem;
    // A* pathfinding bağlamı — blockedTiles aşağıda spatial cache ile aynı
    // referansa bind edilir (içerik update, ref sabit).
    WorkerEntity.pathContext = _pathContext;
    _pathContext.blockedTiles = _obstacles;
    _pathContext.squeezeTiles = _squeezeTiles;

    // Kayıttan devam → dünyayı kaldığı yerden kur; yoksa taze köy üret.
    final save = widget.initialWorld;
    if (save != null) {
      restoreWorld(save);
    } else {
      _generateWorld();
      if (widget.referenceVillage) {
        // Referans köy: açılış sinematiği + ateş yerleştirme YOK — köy hazır
        // kurulur (asset'ler yüklenince, aşağıda). Test zemini beklemesin.
      } else if (!kCaptureMode) {
        // Yeni oyun → açılış sinematiği; bitince oyuncu ateş yerini seçer.
        _activeCutscene = kOpeningCutscene;
        _introPlaceFire = true;
        _chronicle('Köyün kuruluşu', icon: '🔥', milestone: true);
      } else {
        // Zoom-reveal: kamera clamp'i (_clampCamera) zaten reach'e göre
        // ortalayıp zoom'u sınırlar; capture ekstra bir şey yapmaz.
        _zoom = kCaptureZoom;
      }
    }
    _ticker = createTicker(_onTick);

    // Tüm asset cache'lerini paralel yükle. Yüklenmeden ticker başlamaz —
    // sprite cache'leri boşken painter düzgün çizemez.
    _assetsReady = Future.wait([
      BuildingRenderer.loadAll(),
      TileRenderer.loadAll(),
      FarmRenderer.loadAll(),
      TreeRenderer.loadAll(),
      ToolRenderer.loadAll(),
      PropRenderer.loadAll(),
      GraveRenderer.loadAll(),
      ReedBedRenderer.loadAll(),
      NatureRenderer.loadAll(),
      MudRenderer.loadAll(),
      SnowGroundRenderer.loadAll(),
      GroundWeatherRenderer.loadAll(),
      DecorRenderer.loadAll(),
      AnimalRenderer.loadAll(),
      MineRenderer.loadAll(),
      ResourceRenderer.loadAll(),
      RoadRenderer.loadAll(),
      FlameRenderer.loadAll(),
      SmokeRenderer.loadAll(),
    ]);
    _assetsReady.then((_) {
      if (!mounted) return;
      setState(() => _assetsLoaded = true);
      if (kCaptureShowcase) _buildShowcaseVillage();
      // Referans köy — asset'ler hazırken kurulur (bina/NPC görsellerine bağlı
      // kancalar tetiklenir), sonra sabit slota yazılır: gerçek bir kayıt dosyası.
      if (widget.referenceVillage && widget.initialWorld == null) {
        // ignore: unnecessary_this
        this.buildReferenceVillage(season: kCaptureReferenceSeason);
        _saveNow();
      }
      if (kCaptureSealNizam) {
        for (final id in const [
          'nizam.watch',
          'nizam.registry',
          'nizam.labor',
          'nizam.exile',
        ]) {
          final l = LawBook.byId(id);
          if (l != null) _policies.seal(l);
        }
        _applyPolicySideChannels();
      }
      // AÇILIŞ KADRAJI kamerayı TEK sahibi kurar: reach clamp'inin ilk-frame
      // dalı (scene_input `_clampCamera`). Burada ayrıca ortalamak, o dal
      // tarafından ilk karede eziliyordu.
      _ticker.start();
      kCaptureSceneReady = true; // capture harness bunu bekler
    });
    // Ses motoru — döngüler sessiz başlar, tick ortamı yükseltir. Capture/test
    // harness'lerinde audio eklentisi yok (MissingPluginException + AudioManager
    // late-init hatası); ses zaten duyulmayacağı için başlatma.
    if (!kCaptureMode) {
      AudioManager.instance.start();
      // KÖY MÜZİĞİ — sahne açılır açılmaz döngüye girer (dosya yoksa sessiz).
      // Menü parçası ana menüde çalar; buraya girildiğinde köy parçasına geçer.
      AudioManager.instance.playMusic(MusicTrack.village);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_onDevHotkey);
    _devKeyFocus.dispose();
    _villageNamePromptCtrl.dispose();
    _houseNamePromptCtrl.dispose();
    AudioManager.instance.dispose();
    _ticker.dispose();
    _frame.dispose();
    _hudFrame.dispose();
    super.dispose();
  }

  /// Genel kısayollar:
  ///   ` (backtick) → dev konsolu (açıkken dokunma: arama alanına backtick
  ///                  yazılabilsin; kapatma Esc/scrim ile).
  ///   Tab          → Köy Defteri aç/kapa (köy içi işlerin tek kapısı).
  ///   Esc          → açık defteri kapat.
  bool _onDevHotkey(KeyEvent e) {
    if (e is! KeyDownEvent) return false;
    if (e.logicalKey == LogicalKeyboardKey.backquote && !_devConsoleOpen) {
      setStateHere(() => _devConsoleOpen = true);
      return true;
    }
    // Defter kısayolu — modal/sinematik varken karışma (o an odak onların).
    final busy =
        _devConsoleOpen ||
        _petitionModalOpen ||
        _activeCutscene != null ||
        _imperialDemand != null ||
        _pendingChoice != null ||
        _lawRitual != null ||
        _exitConfirmOpen;
    if (e.logicalKey == LogicalKeyboardKey.tab && !busy) {
      setStateHere(
        () => _ledgerSection = _ledgerSection == null
            ? LedgerSection.divan
            : null,
      );
      return true;
    }
    if (e.logicalKey == LogicalKeyboardKey.escape && _ledgerSection != null) {
      setStateHere(() => _ledgerSection = null);
      return true;
    }
    return false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Uygulama arka plana/kapanışa giderken sessizce kaydet — emek kaybı olmasın.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _saveNow();
    }
  }

  // ── Zaman & bildirim helper'ları ───────────────────────────────────────────

  void _cycleSpeed() {
    setState(() {
      _speedIdx = (_speedIdx + 1) % _speedSteps.length;
      _timeScale = _speedSteps[_speedIdx];
    });
    final label = _timeScale == 0.0
        ? 'Duraklatıldı ⏸'
        : 'Hız: ${_timeScale.toInt()}×';
    _showNotification(label);
  }

  /// Karar mührü inince nefes 1×'e iner; duraklatma korunur.
  void _easeToBaseSpeed() {
    if (_timeScale <= 1.0) return;
    setState(() {
      _speedIdx = 0;
      _timeScale = 1.0;
    });
  }

  void _showNotification(String msg) {
    final id = ++_notifId;
    logDev(msg, tag: '📣');
    setState(() => _notification = msg);
    // Capture/prova harness'lerinde otokapatma timer'ını KURMA: banner görünmez
    // ve zorlanmış olay yağmurunda biriken 2 sn'lik Future.delayed'ler test
    // sonunda `!timersPending` assert'ini düşürür (prova testi yakaladı).
    if (kCaptureMode) return;
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _notifId == id) setState(() => _notification = null);
    });
  }

  /// Dev olay günlüğüne bir satır ekler. Yalnız _devLogOn açıkken biriktirir;
  /// kapalıyken erken döner (normal oyunda maliyetsiz). Yeni satır listenin
  /// başına eklenir, tavan 14. [tag] kısa kategori işareti (🎲/⚔/⚖/🎲…),
  /// [color] kanal rengi (varsayılan accent).
  void logDev(String text, {String tag = '', Color? color}) {
    if (!_devLogOn) return;
    _devLog.insert(
      0,
      DevLogEntry(++_devLogSeq, tag, text, color ?? AppUi.accent),
    );
    if (_devLog.length > 14) _devLog.removeRange(14, _devLog.length);
    if (mounted) setState(() {});
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  // Tüm widget alt-ağaçları scene_ui.dart'taki build* metotlarındadır.
  // Burada sadece Stack iskeleti + conditional layer'lar var.

  @override
  Widget build(BuildContext context) {
    if (!_assetsLoaded) {
      return LoadingScreen(
        village: _villageName,
        onCancel: widget.onExitToMenu,
      );
    }

    // KÖY DAĞILDI — koşu bitti. Sahnenin geri kalanı hiç kurulmaz: dünyanın
    // altında dönmeye devam eden bir sim, kapanmış bir defterin arkasında
    // anlamsızdır (ve mezar taşının üstüne bildirim düşürürdü).
    if (_collapsed) return buildCollapseScreen();

    // HESAPLAŞMA — koşu bir KARARLA bitti (berat/sancak/ilhak). Kapanış
    // sinematiği bittikten sonra açılır; oynarken sahne normal kalır ki film
    // köyün üstünde geçsin, boş bir ekranın üstünde değil.
    if (_reckoned) return buildReckoningScreen();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _saveNow(); // menüye dönerken sessizce kaydet
          widget.onExitToMenu?.call();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF234E6A), // deniz tabanı (flash önler)
        // Ad verme kapısı kendi mobil rayını klavyenin üstüne taşır.
        // Scaffold da aynı anda body'yi küçültürürse sinematik ezilir ve
        // inset iki kez uygulanır. Diğer oyun içi metin alanları normal davranır.
        resizeToAvoidBottomInset: _activeCutscene == null,
        // StackFit.expand ŞART: eski tam-ekran "gökyüzü" non-positioned katmanı
        // kaldırıldı → geriye kalan büyük çocuklar hep Positioned.fill (Stack
        // boyutuna katkısız). Loose fit'te Stack, pasif panellerin SizedBox.shrink
        // non-positioned çocuklarının boyutuna (≈0) çöker → tüm sahne görünmez
        // olur, arkadaki deniz tabanı rengi kalır. expand → Stack ekranı doldurur.
        // MOBİL TEMA — 3. kural: telefonda 11px altı yazı yok. Tek tek fontSize
        // avlamak yerine ağacın kökünde ölçekleriz (bkz. ui/mobile_ui.dart).
        // Masaüstünde bu sarmalayıcı hiçbir şey yapmaz.
        body: MobileTextFloor(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Gökyüzü widget katmanı KALDIRILDI — adayı çevreleyen deniz artık
              // painter içinde (OceanRenderer) çizilir; atmosfer/güneş/bulut orada.
              Positioned.fill(child: buildGameCanvas()),
              // Şimşek flash — dünya üstünde, HUD altında; şekilsiz beyaz parlama.
              Positioned.fill(
                child: RepaintBoundary(
                  child: ListenableBuilder(
                    listenable: _frame,
                    builder: (_, _) => IgnorePointer(
                      child: _lightningFlash <= 0.001
                          ? const SizedBox.shrink()
                          : ColoredBox(
                              color: Color.fromRGBO(
                                255,
                                255,
                                255,
                                _lightningFlash.clamp(0.0, 0.32),
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              // Köyün sesi — kuruluş adımını isteyen/teşekkür eden kurucunun
              // cümlesi. Dünyaya ait, HUD'ın ALTINDA: panelleri örtmez.
              buildQuestSpeech(),
              Positioned.fill(child: buildHudLayer()),
              // KOMUTA ÇUBUĞU (konsept 04) — inşa + seçim bağlamı + Defter/Divan/
              // Nüfus kapıları tek alt hatta. Eski alt araç çubuğu + Defter mührü +
              // ObjectivePanel + zümre bandını toplar.
              buildCommandBar(),
              // Görev takipçisi (sağ üst) — eski sürekli-açık ObjectivePanel yerine.
              buildQuestTracker(),
              if (_villageNamePromptOpen) buildVillageNamePrompt(),
              // Akıllı yerleştirme: hayalet geçersiz tile üstündeyse sebep çubuğu.
              // İnşa künyesi — elinde bina varken hep açık (ne işe yarar, nereye
              // kurulmalı, tatlı not + geçersizse sebep).
              if (_placing != null) buildBuildBrief(),
              // Bekleyen karar mühürleri (dilekçe + olay) — HUD üstünde, modal
              // kapalıyken. Kapıda kuyruk: kesinti yok, mühür sabırla bekler.
              if ((_pendingPetition != null && !_petitionModalOpen) ||
                  (_pendingChoice != null && !_choiceModalOpen))
                buildDecisionSeals(),
              // Tam seçim panelleri artık YALNIZ "Detay"la açılır (komuta çubuğu
              // ortada kompakt gösterir) — otomatik sağ-dock kalabalığı kalktı.
              if (_selectedBuilding != null && _detailExpanded)
                buildSelectedBuildingPanel(),
              if (_selectedVillager != null && _detailExpanded)
                buildSelectedVillagerPanel(),
              if (_selectedSiteId != null && _detailExpanded)
                buildSelectedWorkSitePanel(),
              // Karar bekleyen olay — modal YALNIZ mühre tıklanınca açılır ve
              // sim akmaya devam eder (kapıda kuyruk). Boşluğa dokun = mühre
              // geri iner; mühlet dolarsa köy pasif seçeneği kendi yaşar.
              if (_choiceModalOpen && _pendingChoice != null)
                buildEventChoiceModal(),
              // İmparatorluk vergi heyeti — karar zorunlu, sim duraklı.
              if (_imperialDemand != null) buildImperialModal(),
              if (_imperialPhase == ImperialVisitPhase.clashing)
                buildImperialClashOverlay(),
              // Dilekçe modal'ı — oyunu DURDURMAZ (ambient yönetişim).
              if (_petitionModalOpen && _pendingPetition != null)
                buildPetitionModal(),
              // Mühür ritüeli — meclis burada toplanır (ambient: oyun durmaz).
              // Divan'ın ÜSTÜNDE: defterden bir fermana dokununca öne gelir.
              if (_devPanelOpen) buildDevPanel(),
              // Dev komut konsolu — backtick (`) ile açılır; her şeyin üstünde.
              if (_devConsoleOpen) buildDevConsole(),
              // Köy Defteri — divan + kanunname + nüfus + tüzük + kronik tek
              // çerçevede. Oyun durmaz; boşluğa dokun = kapat. Dilekçe modal'ının
              // üstünde DEĞİL (modal açıksa deftere değil dilekçeye odaklanılır).
              if (_ledgerSection != null && !_petitionModalOpen)
                buildVillageLedger(),
              if (_lawRitual != null && !_petitionModalOpen) buildLawRitual(),
              // KURULUŞ ÖĞRETİCİSİ — vinyet + hedefte ince çerçeve. Tıklamayı
              // GEÇİRİR (bkz. guide_spotlight): gösterdiği düğmeye oyuncu
              // doğrudan basar.
              //
              // KÖY DEFTERİ'NİN ÜSTÜNDE olmak ZORUNDA: berat adımının hedefi
              // defterin İÇİNDEKİ kanunname rafı. Altta çizilseydi tam
              // gideceği yerde defterin arkasında kalırdı. Modalların üstünde
              // duruyor ama onlar açıkken hedef zaten çözülmez
              // (`_resolveGuideCue` erken çıkar), yani hiç çizilmez.
              buildGuideSpotlight(),
              if (_exitConfirmOpen) buildExitConfirm(),
              if (_pendingJudgment != null) buildJudgmentConfirm(),
              buildEventBanner(),
              // Ders kartı olay banner'ıyla AYNI yeri kullanır; ikisi asla
              // birlikte çizilmez (kontrol scene_lessons içinde).
              buildLessonCard(),
              // NOT: ObjectivePanel (görev takipçisine) ve EstateBanner (Divan'a)
              // Komuta yapısında toplandı — sürekli-açık sol/sağ yüzen panel yok.
              // Menü kümesi Stack'te tam ekran panellerden SONRA çiziliyor, yani
              // onların ÜSTÜNE biniyordu (Köy Defteri'nde DİVAN sekmesinin
              // üzerine oturuyordu). Panel açıkken hiç çizme.
              if (_ledgerSection == null &&
                  !_petitionModalOpen &&
                  _lawRitual == null &&
                  !_exitConfirmOpen &&
                  _pendingJudgment == null)
                buildSaveButton(),
              buildHoverLabel(),
              if (_notification != null) buildNotificationToast(),
              if (_devLogOn && _devLog.isNotEmpty) buildDevLogConsole(),
              if (_placing != null ||
                  _farmMode ||
                  _lumberMode ||
                  _mineMode ||
                  _roadMode)
                buildHintRibbon(),
              // İmparatorluk varış anonsu — HUD üstünde ama sinematiğin altında
              // (kolon eşiğe varınca cutscene bunu örter).
              // Koşul İÇERİDE (_frame'e bağlı): dış ağaç her frame rebuild
              // olmadığından buradaki bir `if` anonsu donuk bir karede dondurur.
              buildImperialAlert(),
              // KAYBETME EŞİĞİ şeridi — köy gergin/çöküyor evresindeyse geri
              // sayım HER AN görünür. Dağılmanın haber verilmiş olmasının
              // yarısı bu şerit (diğer yarısı bildirim/kronik).
              buildCollapseBanner(),
              // Berat geri sayımı — dağılma şeridine ÖNCELİK verir (ikisi aynı
              // yeri paylaşır; kontrol buildReckoningBanner içinde).
              buildReckoningBanner(),
              // Sinematik — her şeyin üstünde, tam ekran. Sim duraklı.
              if (_activeCutscene != null)
                Positioned.fill(
                  // Sinematik kimliğine bağlı key — sahne değişince oynatıcı
                  // state'i (shotIndex/done) sıfırdan kurulur; aynı widget'ın
                  // yeniden kullanılıp eski/karışık state ile yanlış oynamasını
                  // (ör. art arda iki kez görünme) engeller.
                  child: CutscenePlayer(
                    key: ValueKey(identityHashCode(_activeCutscene)),
                    cutscene: _activeCutscene!,
                    onDone: _onCutsceneDone,
                    showNameGate: !_introPlaceFire,
                    onNameChosen: _onVillageNamed,
                    onFoundingChoice: _onFoundingChoice,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
