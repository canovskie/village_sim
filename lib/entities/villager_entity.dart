import 'dart:math';

import '../characters/life_stage.dart';
import '../characters/npc_visual.dart';
import '../characters/personality.dart';
import '../characters/villager_type.dart';
import '../core/constants.dart';
import '../systems/chronicle.dart';
import '../systems/villager_act.dart';
import '../systems/villager_memory.dart';
import '../systems/villager_mind.dart';
import 'villager_job.dart';
import 'worker_entity.dart';

enum VillagerState {
  moving,
  idle,
  sleeping,
  walkingToSleep,
  walkingToPickup,
  carrying,
}

/// NPC'nin boş zaman hareket kişiliği — "otlayan inek" tekdüzeliğini kırar.
/// Tipe göre atanır (bkz. [VillagerEntity._behaviorFor]); her davranışın
/// kendine has dolaşma yarıçapı, duraklama süresi, yürüyüş hızı ve etrafa
/// bakınma sıklığı vardır.
///   - [patrol]    : iki nokta arası mekik + uçlarda tarama (muhafız)
///   - [ponder]    : çoğunlukla durağan, nadiren yavaş adım (büyücü)
///   - [stroll]    : orta menzilli amaçlı turlar (tüccar, çiftçi)
///   - [homebody]  : spawn çevresinde dar, telaşlı (demirci, madenci)
///   - [waterside] : geniş dolaşır, su kıyısını tercih eder (balıkçı)
///   - [playful]   : çocuk — hızlı kısa koşuşturmalar, sık yön değiştirme,
///                   yuva çevresinde oyun (yaşam evresi child iken geçerli)
enum WanderBehavior { patrol, ponder, stroll, homebody, waterside, playful }

/// NPC'nin o anki sosyal aktivitesi — görsel atmosfer için (gameplay etkisi
/// yok). [chat] yan yana iki kişi konuşur, [music] tek kişi gitar çalar,
/// [dance] yan yana iki kişi yerinde sallanır. [warm] ateş başında çömelmiş
/// ısınır. [storytelling] yaşlı NPC ateş başında hikaye anlatır.
/// [listening] dinleyici — storyteller çevresinde oturan, kıpırdamayan NPC.
/// [arguing] iki kişi yüz yüze ağız dalaşı (öfke postürü + bağırış baloncuğu),
/// [brawling] yumruklaşma (öfke + ileri-geri itiş hareketi + kamera sarsıntısı).
///
/// SUÇ evreleri (bkz. scene_crime.dart) — hepsi gövde diliyle okunur, baş üstü
/// "suçlu" ikonu yoktur: [prowling] hedefe sinsice sokulma (çömelmiş, tetikte),
/// [committing] eylemin kendisi (kısa, telaşlı kıpırtı + aksan baloncuğu),
/// [fleeing] olay yerinden kaçış (korku postürü + hızlanma), [chasing] muhafızın
/// kovalaması (öne yüklenmiş koşu), [abducted] kaçırılan kurbanın sürüklenmesi.
enum VillagerActivity {
  none,
  chat,
  music,
  dance,
  warm,
  storytelling,
  listening,
  arguing,
  brawling,
  watchingConflict, // kavgaya koşup bakan / ürküp geri çekilen çevre halkası
  prowling,
  committing,
  fleeing,
  chasing,
  abducted,
  playing, // çocuk oyunu — kovalamaca/birlikte zıplama (scene_tick _tickChildPlay)
}

/// NPC'nin anlık duygusu — "canlılık" altyapısı. Geçici tepki olarak tetiklenir
/// ([VillagerEntity.feel]); baş üstü ikon + görsel tepki (yürüyüş/irkilme) +
/// kalıcı [VillagerEntity.mood] kaymasını sürer. [none] = nötr (ikon yok).
///   joy=sevinç, content=huzur, grief=keder, fear=korku, wonder=hayret,
///   anger=öfke, love=sevgi/aşk.
enum NpcEmotion { none, joy, content, grief, fear, wonder, anger, love }

/// Ateş başı oturma duruşu — olay reaksiyonu ([_gatherAtFire]) belirler,
/// renderer CharPose'a çevirir. [sit] normal toplanma, [kneel] ayin/ibadet,
/// [mourn] yas töreni. assignSit her oturmada [sit]'e sıfırlar.
enum FirePose { sit, kneel, mourn }

class VillagerEntity extends WorkerEntity {
  /// Meslek. Doğumda çağrı/çıraklık/köy-ihtiyacından atanır; çoğunlukla sabittir
  /// ama meslek-değiştirme dilekçesi onaylanınca [switchProfession] ile değişir
  /// ([speed]/[behavior] getter olduğu için yeni mesleğe göre güncellenir).
  VillagerType type;

  /// Köylünün adı — kurucu NPC'lerde rastgele atanır, sonradan doğanlar
  /// _spawnGrownVillager'da random alır. Aile/bildirim sisteminde kullanılır.
  /// Oyuncu bilgi panelinden istediği zaman yeniden adlandırabilir.
  String name;

  /// Hane (soy) adı — politik/sosyal kimlik (Zümre→Hane geçişi). Kurucu/göçmen
  /// yeni bir hane açar; doğan çocuk baba (yoksa anne) tarafının hanesini miras
  /// alır. Boş = henüz haneye atanmamış (eski kayıt). Değiştirilebilir; ctor
  /// [surname] paramıyla veya kayıttan yüklemede atanır.
  String surname;

  /// Oyuncu bu köylüyü "favori" olarak işaretledi mi (kalp/yıldız). Panel
  /// rozeti + kayıp ruh seçiminden korunma.
  bool isFavorite = false;

  /// Bu köylü köyde bir düğünle evlendi mi. Bir kez true olunca tekrar düğün
  /// adayı seçilmez (scene_wedding kur sürecinin kapısı). Eş ölse bile true
  /// kalır — cozy: kimse zorla yeniden evlendirilmez.
  bool wed = false;

  /// Bu köylünün KİŞİSEL yaşam öyküsü — doğum, reşit oluş, evlilik, çocuk,
  /// bilgelik, kayıp… Panelde zaman çizelgesi olarak okunur (bireye bağlanma).
  /// `_lifeEvent` ile yazılır, kaydedilir. Kronolojik (en eski = doğum üstte).
  final List<ChronicleEntry> life = [];

  /// Yaşam-evresi geçişlerini yakalamak için son görülen evre (geçici, türetilir;
  /// scene `_tickLifeStory` karşılaştırır). null = henüz taranmadı (ilk tick kurar).
  LifeStage? lastStageSeen;

  /// Değişmez kişilik tohumu — mizaç/sevdiği/künye bundan deterministik türer.
  /// Kayıt yalnızca bu int'i tutar; [personality] yüklemede yeniden üretilir.
  final int personalitySeed;

  /// Köylünün kişiliği (mizaç + sevdiği şey + künye). Seed'den lazy üretilir.
  late final Personality personality = Personality.fromSeed(personalitySeed);

  /// Kutlanan yıldönümü sayısı — yaş kilometre taşı geçince artar (kişisel an).
  int annivCount = 0;

  /// "Büyüdü" anı yaşandı mı — çocuk→genç geçişinde bir kez kutlanır (köyün
  /// işlerine ilk el atış). Genç+ yaşla doğanlar köyde büyümediği için baştan
  /// true (an tetiklenmez); bebek doğanlar büyüyünce sahne tetikler.
  bool grewUpMoment;

  /// "Çağrısını buldu" anı yaşandı mı — genç→yetişkin geçişinde meslek görünür
  /// olur ([hasProfession]) ve bu bir kez kutlanır. Yetişkin/yaşlı yaşıyla
  /// doğanlar (kurucu/göçmen) köyde büyümediği için baştan true (an tetiklenmez);
  /// bebek olarak doğanlar büyüyünce sahne ([_tickCallingMoments]) tetikler.
  bool callingFound;

  /// İçindeki çağrı — kişilikten doğan meslek eğilimi (değişmez). Yetişkinlikte
  /// gerçekleşen [type] ile uyumluysa "çağrısını dinledi"; değilse (çıraklıkla
  /// başka mesleğe çekilmiş) bir kırgınlık tohumudur (Faz 2).
  VillagerType get calling => callingFor(personality, personalitySeed);

  /// Mesleğini değiştirir (meslek-değiştirme dilekçesi onaylanınca). [type]
  /// değişken; [speed]/[behavior] getter olduğundan otomatik yeni mesleğe uyar.
  /// Devriye uçları yeni personaya göre yeniden türesin diye patrol init sıfırlanır.
  void switchProfession(VillagerType to) {
    type = to;
    _patInit = false;
  }

  /// Aile bağları — bebek doğduğunda evdeki yetişkin sakinler ebeveyn olur
  /// (max 2). Kurucu NPC'lerde boş. Ölüm anında karşı taraf listesinden
  /// referansı kaldırılır.
  final List<VillagerEntity> parents = [];
  final List<VillagerEntity> children = [];

  double targetCol;
  double targetRow;

  /// ÜSTLENİLEN İŞ — anonim işçi avatarlarının yerini alır (bkz. [VillagerJob]).
  /// null = boş/serbest. Aktifken sahne iş döngüsü ([_SceneWork]) köylüye
  /// `goTo` hedefleri verir; köylü kendi başına gezinmez ([update] idle dalı
  /// bunu görünce wander fallback'ini atlar). Kayıtta yalnız `job.role` tutulur;
  /// atama `_syncJobWorkforce` ile her açılışta yeniden kurulur.
  VillagerJob? job;

  /// Aktif (none olmayan) bir işi üstlenmiş mi — iş döngüsü/rutin kapısı.
  bool get hasActiveJob => job != null && job!.role != JobRole.none;

  /// İş bırakıldıktan sonra kısa süre tekrar işe atanmama süresi (sn) — ör.
  /// erişilemez hedefte takılıp iş bırakınca aynı köylü hemen yeniden aynı işe
  /// atanıp yeniden takılmasın. 0 = serbest. Geçici (kaydedilmez).
  double jobReassignCd = 0.0;

  /// OYUNCUNUN ELLE VERDİĞİ İŞ — `null` ise bu köylü otomatik iş gücü havuzunda
  /// (eski davranış: `_reconcileRole` en yakın boş yetişkini kapar). Doluysa
  /// köylü o rolde KİLİTLİDİR: otomatik atama onu başka role çekemez ve fazlalık
  /// sayılıp bırakamaz — yalnız oyuncu geri alabilir.
  ///
  /// Bu alan erken oyunun omurgası: "kimin ne yaptığına oyuncu karar verir"
  /// hissi buradan gelir. [JobRole.none] "boş dursun" demektir (otomatikten de
  /// muaf) — `null` ile aynı şey DEĞİL.
  JobRole? assignedRole;

  /// Oyuncunun mühürlediği İŞ YERİ ([WorkSite.id]) — "hangi maden, hangi
  /// kereste kampı". [assignedRole] "ne iş" der, bu "nerede" der.
  ///
  /// Neden ayrı bir alan: iki maden ocağı olan bir köyde rol tek başına yetmez
  /// — panel dolu yuvayı yanlış ocağın altında gösterir, oyuncu birine koyduğu
  /// adamı öbüründe görürdü. Rol yerden türetilebilir ama yer rolden
  /// türetilemez; bu yüzden mühür yere basılır.
  ///
  /// `null` + [assignedRole] dolu = eski kayıttan gelen atama (yer bilinmiyor);
  /// ilk kadro senkronunda köylü rolüne uyan en yakın yere yazılır.
  String? assignedSiteId;

  /// Oyuncu bu köylünün işini elle mi belirledi — okunabilirlik kısayolu.
  bool get isPlayerAssigned => assignedRole != null;

  /// Özel kostüm — meslekten bağımsız görsel override (bkz. [NpcCostume]).
  /// Normal köylüler `none`; imparatorluk askerleri spawn'da `imperial` set eder.
  /// Geçici varlık özelliği — kaydedilmez (askerler kayda yazılmaz).
  NpcCostume costume = NpcCostume.none;

  /// İmparatorluk kostümünde komutan mı — true ise miğfer üstünde uzun kızıl
  /// sorguç + pelerin (heyetin lideri görünür biçimde ayrışır).
  bool imperialCommander = false;

  /// İmparatorluk çatışmasında saldırı modunda mı. Askerde mızrak dürtüsü,
  /// köylüde muhafız mızrağı / eldeki balta-tırpan savruluşu üretir.
  bool imperialAttacking = false;

  /// Eşik muharebesinde darbe tepkisi. Hareket motoru geri itilmeyi, renderer
  /// kısa gövde sendelemesini çizer; ziyaret bitince temizlenir.
  bool imperialHit = false;

  /// NPC kavgasının yönlendirilmiş düello motorunda mı? Eski sinüs tabanlı
  /// yerinde sallanmayı susturur; konum ve vuruşu scene_conflict yönetir.
  bool npcDueling = false;

  VillagerState state = VillagerState.idle;
  double idleTimer = 0;

  // ── Rutin / errand (amaçlı hedef akışı) ────────────────────────────────────
  /// true → köylü boşta ve serbest; sahne rutin sistemi ona amaçlı bir hedef
  /// (pazar/taverna/kuyu/ev...) atamalı. Atanınca [goTo] ile false olur.
  bool needsErrand = false;
  bool _onErrand = false;
  double _errandDwell = 0; // hedefe varınca kaç sn oyalanacak
  double _errandWait = 0; // atanmayı kaç sn bekledi (fallback için)

  /// Errand/iş koşturması yapabilir mi — çocuk değil, yaralı/hasta değil VE
  /// kürek cezasında değil (yaralı/hasta dinlenir, mahkûm ocakta; hepsi köyün
  /// gündelik işine karışmaz). [injuryDays], [sickDays], [laborDays].
  bool get canRunErrands =>
      lifeStage != LifeStage.child &&
      injuryDays <= 0 &&
      sickDays <= 0 &&
      laborDays <= 0;

  // ── KÖYÜN HÂLİ (world_pressure) — köylüye işlenen dünya basıncı ────────────
  // Sahne her saniye [_applyPressure] ile tazeler; köylü bunları kendi
  // update()'inde okur. Yasanın gövdeye değdiği yer burası.

  /// Gece eşiği kayması. `dayLight < kNightThreshold + curfewBias` → köylü
  /// içeri çekilir; sokağa çıkma yasağı arttıkça köy daha aydınlıkken boşalır.
  double curfewBias = 0;

  /// Gece feneri mecburiyeti — meslek/yaş şartı olmadan meşale hakkı verir
  /// ([torchEligibleDefault]).
  bool lanternMandate = false;

  /// YÜRÜYEN EYLEM — varış noktasındaki mikro-sahne (bkz. scene_act). null ise
  /// köylünün elinde somut bir iş yok.
  Act? act;

  /// Elindeki görünür nesne — kova/çuval/ekmek/maşrapa/sepet/odun.
  /// Eylem adımları yazar, [PropRenderer] çizer, hız buna göre yavaşlar.
  PropKind prop = PropKind.none;

  /// Eylem sırasındaki iş duruşu (null = normal).
  ActPose? actPose;

  /// HAFIZA — gördükleri (sönen anılar) + kime ne kadar güvendiği (kalıcı
  /// kanaat). Köylüler artık birbirini GÖRÜYOR (bkz. scene_perception);
  /// gördükleri sonraki kararlarını ve kime nasıl davrandıklarını etkiliyor.
  final VillagerMemory memory = VillagerMemory();

  /// AKIL — dürtüler + yürürlükteki niyet + sebep. Köylünün bir sonraki
  /// eylemini artık "hangi sistem önce kaptı" değil bu belirler (bkz.
  /// [scene_mind.dart]). Panelde gösterilen "ne yapıyor / neden" buradan okunur.
  final VillagerMind mind = VillagerMind();

  // ── DURUŞ (bearing) — köyün hâlinin gövdeye inen hâli ──────────────────────
  // Anlık duygudan ([feel]/[NpcEmotion]) FARKLI: duygu bir olaya verilen geçici
  // tepki, duruş ise köylünün o dönemki SÜREKLİ hâli. Baskı altındaki köyde
  // kimse "korku ikonu" taşımaz — sadece herkes biraz daha eğik yürür. Üçü de
  // 0..1; render katmanı ([_VillagerDrawable]) postüre çevirir.

  /// Boyun eğme — omuz düşük, baş hafif önde, adım kısa.
  double bearingBow = 0;

  /// Tedirginlik — gergin salınım, sık omuz üstü bakış, hızlı adım.
  double bearingTense = 0;

  /// Dinçlik/şenlik — dik duruş, adımda hafif sekme.
  double bearingLift = 0;

  /// GECE NÖBETİ — bu köylü geceyi uyanık geçirir (muhafız). Devriye yoğunluğu
  /// ([WorldPressure.patrolDensity]) kaç muhafızın nöbete kalacağını belirler;
  /// nöbetçi gece uykuya çekilmez, postunda kalır. Sokağa çıkma yasağının
  /// görünür tamamlayıcısı: boşalan sokakta yürüyen tek siluet.
  bool nightDuty = false;

  /// PAYDOS (sn) — mesai dürtüsü düşükken (Kutsal Gün, nadas, kış, bolluk)
  /// köylü işini gerçekten bırakır: tezgâh boş kalır, rutin devralır, meydan
  /// dolar. Sayaç bitince kendiliğinden işine döner. Kaydedilmez (geçici hâl).
  double workPause = 0;

  /// Sahne rutin sistemi çağırır: amaçlı bir hedefe yürü, varınca [dwell] sn
  /// orada oyalan (bir şey yapıyormuş gibi). Amaçsız wander'ın yerini alır.
  /// Bir noktaya dönüp bakar — gerçek gövde dili ("fark etti, baktı").
  /// Yalnızca yönü çevirir (glance tetiklemez ki bakış o noktada sabit kalsın).
  /// Reaksiyon dalgalarında ([_reactNearby]) çağrılır.
  void lookToward(double x, double y) {
    if ((x - gridX).abs() > 0.05) facingRight = x > gridX;
  }

  void goTo(double x, double y, double dwell) {
    // Dış sistemlerden gelen yeni hareket emri porter state-machine'ini
    // ezmemeli. Önce yükü güvenle yere bırakıp teslim rezervasyonunu sal.
    if (hasCarryTask) cancelCarryTask();
    targetCol = x;
    targetRow = y;
    _errandDwell = dwell;
    _onErrand = true;
    needsErrand = false;
    _errandWait = 0;
    state = VillagerState.moving;
    // NOT: burada eskiden `glanceAround` vardı — köylü tam yola çıkacakken
    // ters dönüp geri dönüyordu. Yola çıkış anı bakınma anı değil; bakınma
    // artık varışta ([_tickIdleAnim]) ve durakta olur.
  }

  /// Ana hız — meslekten türer (getter; meslek değişince güncellenir).
  /// Yaralı/sakatsa [injuryFactor] ile yavaşlar (görünür aksama); kaçarken /
  /// kovalarken [hasteFactor] ile hızlanır (telaş gözle görülür).
  /// Elindeki yükün hız çarpanı — dolu kova ve çuval taşıyan yavaşlar.
  /// Yüklü köylünün yavaşlaması hem inandırıcı hem oynanışta işlevsel:
  /// çuvalla kaçan hırsız yakalanabilir olmalı.
  double get propFactor => propSpeedFactor(prop);

  /// İŞE GİDİŞ PAYI — gündelik gezintiyi değil, yalnız görünür bir iş hedefine
  /// yürüyen köylüyü hızlandırır. Eski tempoda 10-12 tile uzaktaki işyeri bir
  /// gerçek dakika boyunca yalnız yürüyüş gösteriyordu; oyuncunun gördüğü
  /// vardiya iş değil yoldu. Yük taşırken uygulanmaz: ağır nesnenin okunur
  /// yavaşlığı ve suç kovalamacasının dengesi korunur.
  double get workTravelFactor {
    if (state != VillagerState.moving || isCarrying) return 1.0;
    final purposefulWork = hasActiveJob || mind.owns(IntentKind.work);
    return purposefulWork ? 1.40 : 1.0;
  }

  @override
  double get speed =>
      _speedFor(type) *
      injuryFactor *
      hasteFactor *
      propFactor *
      paceFactor *
      groundFactor *
      workTravelFactor;

  /// ZEMİN ÇARPANI — kışın kar (bkz. winter.kSnowSpeedMultiplier). Mevsim
  /// döndükçe sahne yazar; transient (kaydedilmez, ilk tick'te yeniden kurulur).
  ///
  /// Neden ayrı bir alan: hız getter'ının mevsimi sorgulaması, varlığı dünya
  /// durumuna bağlardı. Köylü zemini bilmez, ona söylenir.
  double groundFactor = 1.0;

  /// Telaş çarpanı — kaçan suçlu / kovalayan muhafız kısa süreliğine hızlanır.
  /// scene_crime yazar, iş bitince 1.0'a döner. Transient (kaydedilmez).
  double hasteFactor = 1.0;

  /// KÖYÜN TEMPOSU — basınç tablosunun adım payı (bkz. WorldPressure.hurry).
  /// Baskı/tedirginlik altında sokakta oyalanma biter, geçişler hızlanır.
  /// scene_pressure yazar; kişisel telaştan ([hasteFactor]) ayrıdır ve onunla
  /// çarpılır. Transient — her tabloda yeniden yazılır, kaydedilmez.
  double paceFactor = 1.0;

  /// KILIK — köyün ambar hâli, -1 yoksunluk … +1 refah (bkz.
  /// WorldPressure.provision). Yalnız çizim okur: giysi renkleri buradan
  /// soluklaşır ya da doyar. scene_pressure yazar, transient.
  double provision = 0.0;

  /// Bu NPC'nin boş zaman hareket kişiliği — meslekten türer (getter; meslek
  /// değişince yeni personaya geçer).
  WanderBehavior get behavior => _behaviorFor(type);

  /// Etrafa bakınma sayacı — boştayken yerinde dönüp gözlem yapar.
  double _lookTimer = 0;

  // ── Devriye (patrol) durumu — iki uç nokta arası mekik ────────────────────
  bool _patInit = false; // uçlar spawn'a göre bir kez hesaplanır
  bool _patToB = true; // sıradaki hedef B mi (değilse A)
  double _patAx = 0, _patAy = 0, _patBx = 0, _patBy = 0;

  // Uyku sistemi
  bool _wasSleeping = false;

  /// Şafakta kademeli uyanış için kişisel gecikme (sn) — köy dalga dalga
  /// uyansın, herkes aynı karede kapıdan fırlamasın. <0 = henüz kurulmadı.
  double _wakeDelay = -1.0;

  /// UYKUSUZ KALAN SÜRE (sn) — soğuktan kalkan köylü bu süre boyunca uyku
  /// akışına dönmez. Olmasaydı gece uyanmak imkânsızdı: `isNight` bir sonraki
  /// karede köylüyü yeniden yatağa yollardı (bkz. [rouseShivering]).
  double sleepRestless = 0;

  /// Nereye gidip uyuyacak (main.dart tarafından her gece atanır)
  (double, double)? sleepTarget;

  /// true → eve girmiş sayılır (render edilmez)
  bool sleepIsHome = false;

  /// Şu an bina içinde mi (gizlenir)
  bool isInsideBuilding = false;

  /// Atanan ev binası (null = evsiz)
  Object?
  homeBuilding; // BuildingEntity türü, döngüsel import önlemek için Object

  /// Geçici vurgu (sn) — HUD'dan "evsizleri göster" gibi tetiklenir; painter
  /// bu süre boyunca köylünün etrafına nabız atan bir halka çizer.
  double highlightTimer = 0;

  // Porter/carry sistemi
  Object? _pickupItem; // ResourceBox veya HayEntity
  Object? carriedItem; // aktif taşıma sırasında görünür
  double _pickupX = 0, _pickupY = 0;
  double _deliverX = 0, _deliverY = 0;
  void Function()? _onDelivered;
  void Function(bool wasPickedUp)? _onCarryCancelled;
  bool _cancellingCarryTask = false;

  /// Ahır binalarının verdiği taşıma hızı çarpanı (≥1). main.dart her tick atar.
  /// Yalnızca pickup/teslimat hareketine uygulanır.
  double carrySpeedMultiplier = 1.0;

  /// Yaş (oyun günü cinsinden) — her tick artar, yaşam evresini belirler.
  /// Doğan köylü 0'dan başlar; kurucu NPC'ler yetişkin yaşıyla doğar.
  double ageDays;

  /// Doğal ölüm yaşı (oyun günü). [ageDays] bunu geçince yaşlı köylü ölür.
  /// Varsayılan sonsuz = ölümsüz (geriye dönük güvenli); main gerçek değer verir.
  final double lifespanDays;

  /// Doğurganlık sayacı (oyun günü cinsinden).
  /// - `NaN` = eligible değil (çocuk/yaşlı/erkek/evsiz) — init bekliyor
  /// - `> 0`  = aktif geri sayım
  /// - `≤ 0`  = hazır; scene `_tickReproduction` tetikleyip resetler
  /// Yetişkin kadın bir eve yerleşince initialize edilir, eligibility kaybolunca
  /// NaN'a döner. chill-gameplay: doğum food consume etmez.
  double fertilityDays = double.nan;

  /// Bu köylünün hayatta yaptığı doğum sayısı — istatistik / panel.
  int birthCount = 0;

  /// Komşuluk politikası kapsamında: bu NPC bir sonraki selamlaşmaya
  /// kaç sn kaldı (poll bazlı azalır). Spam'ı önler.
  double greetCooldown = 0.0;

  /// Bir çekişmeden sonra tekrar kavgaya tutuşmadan önceki bekleme (sn). Spam'ı
  /// önler — kavga eden köylü bir süre sakinleşir. Kaydedilmez (geçici).
  double conflictCooldown = 0.0;

  /// AKUT YARALANMA — kalan iyileşme süresi (oyun günü). >0 iken köylü yaralı:
  /// belirgin yavaşlar, kavgaya giremez, morali düşer. Zamanla 0'a iner (iyileşir).
  /// Kaydedilir. Kavgada (scene_conflict) atanır.
  double injuryDays = 0.0;

  /// HASTALIK — kalan hastalık süresi (oyun günü). >0 iken köylü düşkün:
  /// yavaşlar ve dinlenir (işe/errand'a gitmez). ÇOĞU İYİLEŞİR; yalnız çok
  /// yaşlı/düşük moralli için küçük ölüm riski taşır (bkz. scene_illness).
  /// İyi beslenme + mabet iyileşmeyi hızlandırır. Kaydedilir.
  double sickDays = 0.0;

  /// KÜREK CEZASI — kalan zorunlu emek süresi (oyun günü). >0 iken köylü
  /// mahkûm: normal işe/errand'a gitmez, kadroya alınmaz; gündüzleri taş
  /// ocağına koşulur ve köye günlük taş üretir ([_tickConvictLabor]). Süre
  /// dolunca salıverilir. Kaydedilir. scene_crime `_sentenceToLabor` atar.
  double laborDays = 0.0;

  /// KALICI SAKATLIK — ağır bir yaralanma kalıcı aksaklık bırakır: ömür boyu
  /// hafif yavaş (limp). injuryDays bitse de kalır. Kaydedilir.
  bool disabled = false;

  /// Yaralı/sakat/hasta hız çarpanı — akut yaralı çok yavaş (0.55), hasta düşkün
  /// (0.7), kalıcı sakat hafif aksak (0.8), sağlam 1.0. [speed] bununla ölçeklenir
  /// → gövde dili (aksama/ağırlaşma).
  double get injuryFactor =>
      injuryDays > 0 ? 0.55 : (sickDays > 0 ? 0.7 : (disabled ? 0.8 : 1.0));

  /// Küslükler — bu köylünün dargın olduğu kişiler → küslüğün biteceği sim zamanı
  /// ([_time]). Kavga sonrası kurulur; süresi dolunca lazy temizlenir. Küs çiftler
  /// selamlaşmaz ve yeniden kavgaya daha yatkındır. Kayıtta indeksle serileşir.
  final Map<VillagerEntity, double> grudges = {};

  /// [other] ile şu an (sim zamanı [now]) aktif bir küslük var mı.
  bool hasGrudgeWith(VillagerEntity other, double now) {
    final until = grudges[other];
    return until != null && until > now;
  }

  /// KAN DAVASI — bu köylünün kan düşmanları (kalıcı, süresiz). Bir kavga
  /// ölümle bitince katil + maktul aileleri karşılıklı kan düşmanı olur; doğan
  /// bebek ebeveynlerinin düşmanlığını miras alır. Kan düşmanları asla
  /// selamlaşmaz, sürekli kavgaya çekilir, intikam cinayeti zinciri sürebilir.
  /// Yalnız sulh dilekçesiyle temizlenir. Kayıtta indeksle serileşir.
  final Set<VillagerEntity> bloodEnemies = {};

  bool isBloodEnemy(VillagerEntity o) => bloodEnemies.contains(o);
  bool get inFeud => bloodEnemies.isNotEmpty;

  /// Bu köylünün kan davasında işlediği cinayet sayısı — "suçlu" (idam/sürgün
  /// hedefi) belirlemede en çok kan dökeni öne çıkarır. Kaydedilir.
  int feudKills = 0;

  // ── SUÇ SİCİLİ (scene_crime) ───────────────────────────────────────────────
  /// Bu köylünün SUÇÜSTÜ YAKALANDIĞI suç sayısı. Yalnız yakalananlar sayılır —
  /// meçhul kalan suç kimsenin siciline yazılmaz (köy failini bilmiyor).
  /// Sicilli köylü panelde görünür, yargı dilekçesinde "sabıkalı" diye anılır.
  /// Kaydedilir.
  int crimeCount = 0;

  /// Bir suçtan (ya da affedilmeden) sonra tekrar suça yeltenmeden önceki
  /// bekleme (sn). Spam'ı önler. Transient — kayda yazılmaz.
  double crimeCooldown = 0.0;

  /// Bilge yaşlı — random event "Bilge Yaşlı Belirdi" ile yalnız bir köylüye
  /// atanır (yaşam boyu kalır). Köyde bilge varken ufak moral bonusu doğar.
  bool isSage = false;

  /// Sosyal aktivite durumu — atmosferik "yaşayan köy" katmanı.
  /// [activity] aktif tip; [chatBubbleTime] kalan süre; [chatBubbleIcon]
  /// baloncukta gösterilen emoji.
  double chatBubbleTime = 0;
  String chatBubbleIcon = '';
  VillagerActivity activity = VillagerActivity.none;

  /// EL SALLAMA — komşuluk selamının gövdedeki karşılığı (bkz. scene_tick
  /// `_tickNeighborGreet`). Kalan süre (sn); çizim tarafı bunu bir kol
  /// kaldırma + salınım zarfına çevirir (bkz. `CharGesture.wave`).
  ///
  /// Selam eskiden başın üstünde bir 👋 baloncuğuydu. Baloncuk hiçbir şey
  /// anlatmıyordu: aynı çerçeve, aynı yerde, yalnız içindeki karakter
  /// değişiyordu — oyun "birileri selamlaştı" diye YAZIYORDU, göstermiyordu.
  /// Transient: kayda YAZILMAZ (1,6 sn'lik bir jest kaydı hak etmez).
  double waveTime = 0;
  static const double kWaveDuration = 1.6;

  /// Bu NPC'nin son aktiviteden sonraki kişisel cooldown'u (sn). Her NPC
  /// kendi başına değerlendirilir → global cap yok, nüfus arttıkça toplam
  /// aktivite doğal artar. 60-180 sn.
  double socialCooldown = 0;

  /// Meslek iş döngüsü bekleme sayacı (sn) — avcının av arası, çobanın bakım
  /// arası vb. (bkz. scene_work.dart). Transient: kayda YAZILMAZ, yüklemede
  /// sıfırlanır (en kötü ihtimalle bir iş bir kez erken tetiklenir).
  double workCooldown = 0;

  // ── Sohbet konuşması — karşılıklı + konuya bağlı baloncuk ───────────────────
  /// Sohbette karşıdaki kişi (yüz dönme + sıra için). null = solo/yok.
  VillagerEntity? convoPartner;

  /// Konuşmanın replik ikonları — konuya göre seçilmiş sıralı emoji dizisi
  /// (ör. çiftçi sohbeti 🌾💧☀️). Rastgele tek emoji yerine "konu".
  List<String> convoIcons = const [];

  /// Konuşmanın toplam süresi — sıra hesabı (elapsed = total - chatBubbleTime).
  double convoTotal = 0;

  /// Çiftte "başlatan" mı — replikleri sırayla bölüşmek için (0,2.. vs 1,3..).
  bool convoStarter = false;

  /// Şu an konuşuyor muyum + hangi replik ikonu. Sıra-temelli: ~1.4s'de bir
  /// konuşan değişir → "A der, B yanıtlar" hissi. Konuşmuyorsam (false,'').
  (bool, String) convoNow() {
    if (convoIcons.isEmpty || convoTotal <= 0 || chatBubbleTime <= 0) {
      return (false, '');
    }
    final elapsed = convoTotal - chatBubbleTime;
    const lineLen = 1.4;
    final line = (elapsed / lineLen).floor();
    final iAmSpeaker = line.isEven == convoStarter;
    if (!iAmSpeaker) return (false, '');
    return (true, convoIcons[line % convoIcons.length]);
  }

  /// Sohbet bitince konuşma durumunu temizler.
  void clearConvo() {
    convoPartner = null;
    convoIcons = const [];
    convoTotal = 0;
  }

  // ── Duygu / iç dünya (canlılık altyapısı) ──────────────────────────────────
  /// Kalıcı ruh hali: -1 (mutsuz) .. +1 (mutlu), 0 nötr. Olaylar ve etkileşimler
  /// [feel] ile iter; [tickInnerLife] her tick yavaşça nötre çeker.
  /// SADECE GÖRSEL: duruş/yüz ifadesini besler — davranışın NEDENİ değildir
  /// (rutin/sosyal seçim artık mood'a bakmaz; sayı davranışı yönetmez).
  double mood = 0.0;

  /// Enerji 0..1 — gündüz/iş tüketir, uyku/ısınma doldurur.
  /// SADECE GÖSTERİM (panelde bar) — hiçbir mantık bunu okumaz/gate'lemez.
  double energy = 1.0;

  // ── Bireysel MORAL (kalıcı yaşam memnuniyeti) ───────────────────────────────
  /// 0 (perişan) .. 1 (mutlu). [mood]'dan farklı: KALICI ve mantığı etkiler.
  /// Sahne her ~1sn koşullardan (ev/yiyecek/su/ısınma/zümre durumu) bir hedef
  /// hesaplar, morale oraya yavaş süzülür; yaşam olayları [feel]'in moodDelta'sı
  /// ile anlık iter. Etkiler: dilekçeyi en mutsuz ilgili köylü getirir, postür
  /// kalıcı çöker (mood tabanı), uzun süre çok düşükse köyü terk eder; ayrıca
  /// zümre + köy moraline beslenir. [VillagerMorale] formülü hesaplar.
  double morale = 0.6;

  /// Moral kritik eşik altındayken geçen süre (sn) — göç kararı için birikir,
  /// toparlayınca hızla erir. Sahne okur.
  double lowMoraleTime = 0.0;

  /// Panelde gösterilecek baskın sebep ("evsiz", "aç", "huzurlu" …). Sahne yazar.
  String moraleReason = 'huzurlu';

  // ── Servet (göreceli varlık) ───────────────────────────────────────────────
  /// Köylünün biriktirdiği soyut varlık ("sikke"). Çalışan yetişkinler her gün
  /// mesleklerine göre kazanır; moral (üretkenlik) + ev kademesi çarpar; küçük
  /// bir yaşam gideri asimptota çeker (sınırsız büyümez). Çocuk/mesleksiz
  /// kazanmaz → gider zamanla sıfıra indirir. Köy Nüfus Defteri'nde "zenginlik"
  /// sütununda gösterilir VE mekanik sürer: yoksul köylü (wealth<10) suça daha
  /// yatkın, hırsız daha zengin komşuyu hedefler, çalınan servet el değiştirir
  /// (bkz. scene_crime). Günlük gelir scene_estates'te işlenir ([wealthDailyIncome]),
  /// kayıtta saklanır.
  double wealth = 0;

  /// Zanaat ustalığı — bu köylünün her zanaatta biriktirdiği deneyim (birikim
  /// kanalı, bkz. buildings/craft.dart). Yalnız YAPI zanaatları (marangozluk/taş
  /// ustalığı) buradan doğar: odun/taş taşıdıkça artar, eşiği geçen köylü o
  /// zanaatı köye kazandırır. Meslek zanaatları çağrıdan gelir, buraya yazılmaz.
  /// Kayıtta saklanır.
  final Map<String, double> mastery = {};
  void gainMastery(String craft, double amount) =>
      mastery[craft] = (mastery[craft] ?? 0) + amount;

  /// Anlık duygu (geçici tepki). [emotionTime] > 0 iken aktif → renderer bunu
  /// GÖVDE DİLİNE çevirir (emoji DEĞİL): yas çöküşü, sevinç zıplaması, korku
  /// geri çekilmesi vb. Solunca [NpcEmotion.none]'a döner.
  NpcEmotion emotion = NpcEmotion.none;
  double emotionTime = 0.0;
  double _emotionDur = 0.0;

  /// Duygunun anlık şiddeti 0..1 — başta zirve, sonuna doğru söner. Renderer
  /// gövde dili (eğilme/zıplama/titreme) genliğini buna göre ölçekler.
  double get emotionIntensity {
    if (emotionTime <= 0 || _emotionDur <= 0) return 0.0;
    final t = (emotionTime / _emotionDur).clamp(0.0, 1.0);
    // Hızlı yükseliş (ilk %20) + yumuşak iniş — refleks gibi.
    return t > 0.8 ? (1.0 - t) / 0.2 : t / 0.8;
  }

  /// Anlık bir duygu tetikler: geçici görsel tepki ([dur] sn) + kalıcı mood
  /// kayması ([moodDelta]). Daha güçlü duygu zayıfı ezmez — süre uzar.
  void feel(NpcEmotion e, double dur, {double moodDelta = 0}) {
    if (e != NpcEmotion.none &&
        (emotion == NpcEmotion.none || dur >= emotionTime)) {
      emotion = e;
      emotionTime = dur;
      _emotionDur = dur;
    }
    if (moodDelta != 0) {
      mood = (mood + moodDelta).clamp(-1.0, 1.0);
      // Yaşam olayı kalıcı morali de iter (doğum/şenlik/ısınma → +, ölüm/
      // kayıp → −). Koşul-hedefine göre yavaşça geri süzülür.
      morale = (morale + moodDelta * 0.4).clamp(0.0, 1.0);
    }
  }

  // ── Ölüm animasyonu (collapse + fade) ──────────────────────────────────────
  /// Köylü ölüyor mu — anlık silinmez; gözle görülür biçimde yere çöker, solar,
  /// sonra sahneden kaldırılır. Hem doğal ölüm hem olay ölümleri buradan geçer.
  bool isDying = false;
  double _deathT = 0.0, _deathDur = 1.6;

  /// Animasyon bitince doğal-ölüm cenazesi düzenlensin mi (olay ölümlerinde
  /// kendi töreni var → false).
  bool deathHoldsFuneral = false;

  /// Ölüm animasyonu ilerlemesi 0..1 (renderer çöküş/solma için kullanır).
  double get dyingProgress =>
      _deathDur <= 0 ? 1.0 : (1.0 - _deathT / _deathDur).clamp(0.0, 1.0);

  /// Animasyon tamamlandı → sahne bu köylüyü kaldırabilir.
  bool get deathFinished => isDying && _deathT <= 0;

  /// Ölümü başlat: hareketi/oturmayı durdur, geri sayımı kur. [funeral] doğal
  /// ölümlerde true (sahne tören düzenler).
  void startDying({double duration = 1.6, bool funeral = false}) {
    if (isDying) return;
    // Terminal bayrak callback'ten ÖNCE kurulmalı. İptal callback'i yeniden
    // taşıma atamaya kalkarsa ölen köylü bunu güvenilir biçimde reddeder.
    isDying = true;
    // Ani/olay ölümü doğal ölüm hattındaki "önce teslim et" kapısından
    // geçmeyebilir. Yükü ve teslim slot'unu sahibine iade etmeden AI'ı
    // dondurursak kaynak görünmez, anchor da sonsuza dek dolu kalır.
    cancelCarryTask();
    _deathDur = duration;
    _deathT = duration;
    deathHoldsFuneral = funeral;
    emotion = NpcEmotion.none;
    emotionTime = 0;
    if (sitClaimed) _cancelSit();
  }

  // ── Sürgün (köyden ayrılış — ölüm DEĞİL) ────────────────────────────────────
  /// Sürgün edilen köylü olduğu yerde ÖLMEZ; harita kenarına doğru yürür ve
  /// varınca sahneden çekilir (metinle uyum: "yolun başına yürütüldü, çıkarıldı").
  /// AI donar (update erken döner), yalnız kenara yürüme sürer.
  bool isLeaving = false;
  double _leaveX = 0, _leaveY = 0;

  /// Kenara vardı → sahne bir sonraki geçişte listeden çıkarabilir.
  bool leftVillage = false;

  void startLeaving(double edgeX, double edgeY) {
    if (isLeaving || isDying) return;
    // Terminal bayrak callback'ten önce kurulur; aksi halde callback aynı
    // köylüye yeni porter işi verip ayrılış state'inin altında sızdırabilir.
    isLeaving = true;
    // Sürgün/ayrılış taşıma state-machine'ini artık sürdürmez. Yükü köylünün
    // ayağına bırakıp teslim rezervasyonunu sal; harita kenarına görünmez bir
    // kutuyla yürüyüp kaynağı da köyden silmesin.
    cancelCarryTask();
    _leaveX = edgeX;
    _leaveY = edgeY;
    emotion = NpcEmotion.grief; // ağır, başı önde ayrılış (gövde dili)
    emotionTime = 5.0;
    if (sitClaimed) _cancelSit();
  }

  // ── Yaş-evresi boyutu (yumuşatılmış) ────────────────────────────────────────
  /// [LifeStage.renderScale] AYRIK (0.60→0.82→1.00→0.95); doğrudan çizilirse
  /// köylü evre eşiğinde tek karede sıçrayarak büyür/küçülür. [displayScale] o
  /// hedefe ~1.2s'de süzülür (ilk karede snap) — renderer bunu kullanır.
  double displayScale = 1.0;
  bool _displayScaleInit = false;

  /// "Belirme" — doğum / köye katılma anında köylü tek karede pat belirmesin;
  /// [from] küçük ölçekten hedef boyuta yumuşakça süzülür (displayScale lerp'i).
  void appearScaleIn([double from = 0.2]) {
    displayScale = from;
    _displayScaleInit = true;
  }

  /// İç dünyayı her tick ilerletir: duygu zamanlayıcısı, mood'un nötre dönüşü,
  /// enerji tüketimi/yenilenmesi. [dayLight] gündüz/gece, [resting] uyku/ısınma.
  void tickInnerLife(double dt, double dayLight, bool resting) {
    if (highlightTimer > 0) highlightTimer -= dt;
    // Ölüm animasyonu sırasında iç dünya donar — sadece çöküş geri sayar.
    if (isDying) {
      _deathT -= dt;
      return;
    }
    if (emotionTime > 0) {
      emotionTime -= dt;
      if (emotionTime <= 0) emotion = NpcEmotion.none;
    }
    // Mood, anlık olaydan sonra MORAL TABANINA döner (nötr 0'a değil): kalıcı
    // olarak mutsuz köylü görünür biçimde çöker, mutlu olan dik durur. Böylece
    // bireysel moral, gövde diline kalıcı yansır (gün başına ~0.5 sönüm).
    final moodFloor = ((morale - 0.62) * 0.85).clamp(-0.55, 0.35);
    if ((mood - moodFloor).abs() > 0.001) {
      final decay = (dt / kGameDaySeconds) * 0.5;
      if (mood > moodFloor) {
        mood = (mood - decay).clamp(moodFloor, 1.0);
      } else {
        mood = (mood + decay).clamp(-1.0, moodFloor);
      }
    }
    // Kronik mutsuzluk sayacı — göç kararı için (sahne okur). Düşükken birikir,
    // toparlayınca 2× hızla erir.
    if (morale < 0.18) {
      lowMoraleTime += dt;
    } else if (lowMoraleTime > 0) {
      lowMoraleTime = (lowMoraleTime - dt * 2).clamp(0.0, 1e9);
    }
    // Enerji: dinlenirken dolar, gündüz aktifken tükenir (gün döngüsüne göre).
    final rate = dt / kGameDaySeconds;
    if (resting) {
      energy = (energy + rate * 1.6).clamp(0.0, 1.0);
    } else if (dayLight > 0.3) {
      energy = (energy - rate * 0.7).clamp(0.0, 1.0);
    }
  }

  // ── Ateş başı oturma sistemi ───────────────────────────────────────────────
  /// Ateş slotuna yöneliyor mu / oturmuş mu (ikisi de bu flag ile). false
  /// olunca normal idle/moving döngüsüne döner. [sitArriveX,Y]'ye varınca
  /// "oturuyor", [warmthTimer] tükenince [_releaseSit] çağrılır.
  bool sitClaimed = false;

  /// Hedef slot tile koordinatı.
  double sitArriveX = 0, sitArriveY = 0;

  /// Ateş merkezinin koordinatı — oturunca yüz ona dönsün.
  double sitFaceX = 0, sitFaceY = 0;

  /// Oturma süresi (sn). Yürürken de azalmaz; varınca tikleyince azalır.
  double warmthTimer = 0;

  /// Slot'u serbest bırakan callback — scene_firepit_gather verir.
  void Function()? _releaseSit;

  /// Oturma duruşu — varsayılan bağdaş; olay reaksiyonu ayin/yas'a çevirebilir.
  FirePose firePose = FirePose.sit;

  /// Şu an gerçekten oturmuş, ısınıyor/dinliyor mu (slot pozisyonunda mı).
  bool get isSeatedAtFire {
    if (!sitClaimed) return false;
    final dx = sitArriveX - gridX;
    final dy = sitArriveY - gridY;
    return dx * dx + dy * dy < 0.09; // ~0.3 tile
  }

  /// Scene tarafından çağrılır. Slot rezerve edildikten sonra NPC'yi
  /// "ateş başına git, otur" durumuna sokar.
  void assignSit(
    double slotX,
    double slotY,
    double centerX,
    double centerY,
    double duration,
    void Function() release,
  ) {
    sitArriveX = slotX;
    sitArriveY = slotY;
    sitFaceX = centerX;
    sitFaceY = centerY;
    warmthTimer = duration;
    _releaseSit = release;
    sitClaimed = true;
    activity = VillagerActivity.warm;
    firePose = FirePose.sit; // varsayılan; reaksiyon sonradan değiştirebilir
    chatBubbleIcon = '';
    chatBubbleTime = 0;
  }

  /// Oturmayı DIŞARIDAN iptal et — slot'u usulüne uygun bırakır (rezervasyon
  /// sızdırmaz). Acil bir iş köylüyü ateş başından kaldırdığında kullanılır
  /// (ör. muhafız suça koşarken — bkz. scene_crime `_guardResponse`).
  void cancelSit() => _cancelSit();

  /// Oturmayı iptal et — slot'u serbest bırak, alanları temizle. Uyku/karar
  /// dışı durumlar için savunmacı.
  void _cancelSit() {
    _releaseSit?.call();
    _releaseSit = null;
    sitClaimed = false;
    warmthTimer = 0;
    if (activity == VillagerActivity.warm ||
        activity == VillagerActivity.storytelling ||
        activity == VillagerActivity.listening) {
      activity = VillagerActivity.none;
    }
  }

  VillagerEntity({
    required this.type,
    required this.name,
    this.surname = '',
    required bool male,
    required super.startCol,
    required super.startRow,
    int? visualSeed,
    NpcVisual? visual,
    int? personalitySeed,
    this.ageDays = 0,
    this.lifespanDays = double.infinity,
  }) : personalitySeed = personalitySeed ?? _autoPersonalitySeed(),
       // Yetişkin/yaşlı yaşıyla doğan (kurucu/göçmen) çağrısını "köyde büyürken"
       // bulmadı → an tetiklenmesin. Bebek (ageDays≈0) büyüyünce keşfeder.
       callingFound = ageDays >= kAdultStartDay,
       // Genç ve üstü yaşla doğan köylü çocukluğunu köyde yaşamadı → "büyüdü"
       // anı tetiklenmesin.
       grewUpMoment = ageDays >= kYouthStartDay,
       targetCol = startCol,
       targetRow = startRow,
       // [visual] verilirse (kayıttan yükleme) birebir o görsel kimlik korunur;
       // yoksa seed'ten üretilir. Cinsiyet dışarıdan zorlanır → name ile uyumlu.
       super(
         visual:
             visual ??
             NpcVisual.fromSeed(
               visualSeed ?? _autoSeed(type, startCol, startRow),
               forceMale: male,
             ),
       ) {
    // Yetişkin/yaşlı doğanlar (kurucu/göçmen) köye zaten birikmiş bir varlıkla
    // gelir → Nüfus Defteri ilk günden çeşitli görünsün (seed'ten deterministik).
    // Bebekler 0'dan başlar, büyüyüp meslek edinince kazanmaya başlar.
    if (ageDays >= kAdultStartDay) {
      wealth = 14 + (this.personalitySeed.abs() % 55).toDouble();
    }
  }

  /// NPC'nin cinsiyeti — visual.isMale ile aynı (getter pratik erişim).
  bool get isMale => visual.isMale;

  /// Hane etiketi — "Demirhan Hanesi" biçimi; soyad yoksa boş (eski kayıt).
  String get houseLabel => surname.isEmpty ? '' : '$surname Hanesi';

  /// Otomatik visual seed — type + spawn pozisyonu hash'i.  Aynı pozisyondan
  /// aynı tipte spawn olan iki NPC olmaz pratikte, ama görsel seed verilebilir.
  /// Kişilik için rastgele tohum — her köylü farklı kişilik alsın diye varsayılan.
  /// Kayıttan yüklemede gerçek değer dışarıdan verilir (deterministik kalır).
  static int _autoPersonalitySeed() => Random().nextInt(0x7FFFFFFF);

  static int _autoSeed(VillagerType t, double c, double r) =>
      t.index * 7919 ^
      (c * 1009).toInt() * 13 ^
      (r * 1031).toInt() * 31 ^
      DateTime.now().microsecondsSinceEpoch & 0xFFFF;

  bool get isSleeping => state == VillagerState.sleeping;

  /// SOĞUKTAN UYANMA — ocağın sıcağı ulaşmayan çadırda kışı geçiren köylü
  /// gecenin ortasında titreyerek kalkar ([_SceneShelter] çağırır).
  ///
  /// Uyanmak burada bilerek "yatağı terk etmek"tir: köylü dışarı çıkar, akıl
  /// devralır ve üşüme dürtüsü onu ateş başına götürür ([_bidHearth]). Rahatsız
  /// olduğunu anlatan şey baş üstünde bir ikon değil, gecenin ortasında ateşin
  /// çevresinde biriken insanlardır.
  ///
  /// [restlessFor] süresince uyku akışı kapalı kalır; sonra köylü — hâlâ geceyse
  /// — yatağına döner. Zaten uyanıksa hiçbir şey yapmaz.
  void rouseShivering({double restlessFor = 95.0}) {
    if (state != VillagerState.sleeping &&
        state != VillagerState.walkingToSleep) {
      return;
    }
    state = VillagerState.idle;
    idleTimer =
        0.3 + (personalitySeed % 7) * 0.1; // herkes aynı anda doğrulmasın
    isInsideBuilding = false;
    isWalking = false;
    _wasSleeping = false;
    _wakeDelay = -1.0;
    sleepRestless = restlessFor;
  }

  /// Villager torch eligibility: yetişkin/yaşlı, dışarıda, uyumuyor, ateşte
  /// oturmuyor. walkingToSleep eligible — eve yürürken torch yansın.
  /// sitClaimed olup henüz oturmamış da eligible (ateşe yürürken torch).
  ///
  /// [lanternMandate] (bkz. WorldPressure) mesleksizi de kapsar: hüküm gece
  /// ışığı mecbur kıldıysa sokaktaki HERKESİN elinde ışık olur — çocuk da
  /// dahil, çünkü yasa yaşa bakmaz.
  @override
  bool get torchEligibleDefault =>
      !isInsideBuilding &&
      state != VillagerState.sleeping &&
      !isSeatedAtFire &&
      !holdsItemTwoHanded &&
      (hasProfession || lanternMandate);
  bool get isCarrying =>
      state == VillagerState.carrying || state == VillagerState.walkingToPickup;

  /// Porter'ın görünür state'i dışarıdan ezilmiş olsa bile özel görev alanları
  /// doluysa görev hâlâ aktiftir. Çakışan atama ve kayıt normalizasyonu yalnız
  /// enum'a bakarsa kaynak/callback sızıntısını kaçırır.
  bool get hasCarryTask =>
      isCarrying ||
      _pickupItem != null ||
      carriedItem != null ||
      _onDelivered != null ||
      _onCarryCancelled != null;

  /// Renderer'ın iki eli yük duruşuna alacağı tek kapı. Pickup'a giderken yük
  /// henüz elde değildir; porter yükü ancak [carriedItem] dolunca iki ellidir.
  /// Gündelik sahnelerdeki çuval/sepet/odun da aynı duruşu kullanır.
  bool get holdsItemTwoHanded =>
      (state == VillagerState.carrying && carriedItem != null) ||
      propTwoHanded(prop);

  /// Genel taşıyıcı taramasının bir köylüyü yarım sahneden/iş darbesinden
  /// koparmaması için model-seviyesi uygunluk. Atanmış ama henüz hedef
  /// sahiplenmemiş bir işçi porter olabilir; başlamış faz/claim/su turu olamaz.
  bool get canAcceptCarryTask {
    final activeJob = job;
    final jobIsBetweenCycles =
        activeJob == null ||
        (activeJob.phase == 0 &&
            activeJob.claim == null &&
            activeJob.claim2 == null &&
            activeJob.claim3 == null &&
            !activeJob.working &&
            !activeJob.harvesting &&
            !activeJob.carryingWater &&
            activeJob.harvestHayPos == null);
    return state == VillagerState.idle &&
        !isWalking &&
        !hasCarryTask &&
        !_cancellingCarryTask &&
        !isDying &&
        !isLeaving &&
        !isInsideBuilding &&
        canRunErrands &&
        !sitClaimed &&
        !isSeatedAtFire &&
        activity == VillagerActivity.none &&
        act == null &&
        actPose == null &&
        prop == PropKind.none &&
        waveTime <= 0 &&
        chatBubbleTime <= 0 &&
        jobIsBetweenCycles &&
        mind.intent.priority < IntentPriority.committed;
  }

  /// Güncel yaşam evresi (yaştan türer).
  LifeStage get lifeStage => lifeStageForDays(ageDays);

  /// Yetişkin/yaşlı → meslek görünümü; çocuk/genç → mesleksiz köylü.
  bool get hasProfession => lifeStage.hasProfession;

  /// Çocuk mu? Taşıma/iş ataması dışı tutulur, oyuncu davranış uygular.
  bool get isChild => lifeStage == LifeStage.child;

  /// KIŞLIK GİYSİ — dokumacının ürettiği yün giysiyi giyiyor mu.
  ///
  /// Üşümeyi bitirmez, yavaşlatır (bkz. systems/winter.dart kCoatChillRelief):
  /// bitirseydi bir kış dokuyan köy mevsimi tamamen çözer, ocağın ve damın
  /// anlamı kalmazdı. Kayıtta tutulur — köyün emeği yüklenince kaybolmasın.
  bool hasCoat = false;

  /// O anki etkin dolaşma davranışı. Çocukken tipinin davranışı yerine
  /// [WanderBehavior.playful]; büyüyünce kendi tip davranışına döner.
  WanderBehavior get _activeBehavior =>
      isChild ? WanderBehavior.playful : behavior;

  bool assignCarryTask(
    Object item,
    double pickX,
    double pickY,
    double destX,
    double destY, {
    void Function()? onDelivered,
    void Function(bool wasPickedUp)? onCancelled,
  }) {
    // `false`, görevin hiç başlamadığı anlamına gelir; bu durumda callback
    // çağrılmaz. Önceden anchor claim eden çağıran bool kolunda kendi claim'ini
    // geri alır. Aktif görevi burada zorla kesmek yarım sahne/iş ve yeniden
    // giriş yarışları üretiyordu.
    if (!canAcceptCarryTask) return false;

    _pickupItem = item;
    carriedItem = null;
    _pickupX = pickX;
    _pickupY = pickY;
    _deliverX = destX;
    _deliverY = destY;
    _onDelivered = onDelivered;
    _onCarryCancelled = onCancelled;
    state = VillagerState.walkingToPickup;
    isWalking = true;
    return true;
  }

  /// Aktif porter zincirini güvenle kes. Callback, yük gerçekten ele alınmışsa
  /// `true` alır; çağıran böylece yerdeki item'i pickup noktasında bırakmakla
  /// köylünün mevcut konumuna düşürmek arasında doğru kararı verir.
  void cancelCarryTask() {
    if (!hasCarryTask) return;

    final wasPickedUp = carriedItem != null;
    final onCancelled = _onCarryCancelled;
    _pickupItem = null;
    carriedItem = null;
    _onDelivered = null;
    _onCarryCancelled = null;
    _pickupX = _pickupY = _deliverX = _deliverY = 0;
    loco.reset();
    if (state == VillagerState.walkingToPickup ||
        state == VillagerState.carrying) {
      state = VillagerState.idle;
      idleTimer = 0.2;
    }
    isWalking = false;
    // Önce iç state temizlenir. Callback boyunca yeni görev kabul edilmez;
    // böylece dış hareket/ölüm/işten ayrılma emri callback'in yeniden atadığı
    // bir görevi hemen ezip ikinci bir kaynak sızıntısı oluşturamaz.
    _cancellingCarryTask = true;
    try {
      onCancelled?.call(wasPickedUp);
    } finally {
      _cancellingCarryTask = false;
    }
  }

  /// Taşıma zincirinin kalan gerçek süresi. Panel koordinatları bilmez; modelin
  /// yürüdüğü pickup/teslim hedefini ve aynı [speed] değerini okuyarak ETA'yı
  /// tek kapıdan verir. null = şu an taşıma işi yok.
  double? get deliveryEtaSeconds {
    final double tx, ty;
    if (state == VillagerState.walkingToPickup) {
      tx = _pickupX;
      ty = _pickupY;
    } else if (state == VillagerState.carrying) {
      tx = _deliverX;
      ty = _deliverY;
    } else {
      return null;
    }
    final dx = tx - gridX;
    final dy = ty - gridY;
    final pace = speed * carrySpeedMultiplier;
    return pace <= 0.01 ? null : sqrt(dx * dx + dy * dy) / pace;
  }

  static double _speedFor(VillagerType t) {
    switch (t) {
      case VillagerType.farmer:
        return 1.2;
      case VillagerType.merchant:
        return 0.9;
      case VillagerType.blacksmith:
        return 0.8;
      case VillagerType.guard:
        return 1.6;
      case VillagerType.priest:
        return 0.7; // ağır, ölçülü adım
      case VillagerType.miner:
        return 0.85;
      case VillagerType.fisher:
        return 1.1;
      case VillagerType.shepherd:
        return 1.0; // sürünün temposu
      case VillagerType.hunter:
        return 1.45; // sessiz ve çevik
      case VillagerType.miller:
        return 0.9;
      case VillagerType.innkeeper:
        return 0.95;
    }
  }

  static WanderBehavior _behaviorFor(VillagerType t) => switch (t) {
    VillagerType.guard => WanderBehavior.patrol,
    VillagerType.priest => WanderBehavior.ponder,
    VillagerType.merchant => WanderBehavior.stroll,
    VillagerType.farmer => WanderBehavior.stroll,
    VillagerType.blacksmith => WanderBehavior.homebody,
    VillagerType.miner => WanderBehavior.homebody,
    VillagerType.fisher => WanderBehavior.waterside,
    // Çoban + avcı köyün dışına açılır (geniş roam) — sürü/orman peşinde.
    VillagerType.shepherd => WanderBehavior.stroll,
    VillagerType.hunter => WanderBehavior.patrol,
    // Değirmenci + hancı işinin başında durur.
    VillagerType.miller => WanderBehavior.homebody,
    VillagerType.innkeeper => WanderBehavior.homebody,
  };

  // ── Kişilik parametreleri (etkin davranışa göre) ───────────────────────────
  /// Spawn çevresinde dolaşma yarıçapı (tile).
  double get _roamRadius => switch (_activeBehavior) {
    WanderBehavior.patrol => 3.0,
    WanderBehavior.ponder => 1.5,
    WanderBehavior.stroll => 3.5,
    WanderBehavior.homebody => 1.8,
    WanderBehavior.waterside => 4.0,
    WanderBehavior.playful => 3.0, // yuva çevresinde koşuşturur
  };

  /// Hedefe varınca duraklama süresi aralığı (saniye).
  (double, double) get _dwellRange => switch (_activeBehavior) {
    WanderBehavior.patrol => (2.0, 4.0),
    WanderBehavior.ponder => (4.0, 9.0),
    WanderBehavior.stroll => (1.5, 4.5),
    WanderBehavior.homebody => (1.0, 3.0),
    WanderBehavior.waterside => (2.0, 5.0),
    WanderBehavior.playful => (0.2, 1.2), // hiç durmaz, hep hareket halinde
  };

  /// Yürürken ana hıza uygulanan çarpan — kişiliğe göre tempo.
  double get _tripSpeed {
    // Mesleğin boş-zaman yürüyüş kişiliği işe gidişi yavaşlatmaz. Değirmenci
    // homebody olduğu için eski çarpan 0.65'ti; ekranın öbür ucundaki değirmene
    // bir gerçek dakika boyunca yürüyordu. İş hedefinde tam adım, gezintide
    // kişisel tempo korunur.
    if (hasActiveJob || mind.owns(IntentKind.work)) return 1.0;
    return switch (_activeBehavior) {
      WanderBehavior.patrol => 1.0,
      WanderBehavior.ponder => 0.55,
      WanderBehavior.stroll => 0.7,
      WanderBehavior.homebody => 0.65,
      WanderBehavior.waterside => 0.85,
      WanderBehavior.playful => 1.35, // kısa hızlı koşuşturmalar
    };
  }

  /// Boştayken bir "bakınma anında" yön değiştirme olasılığı.
  double get _lookChance => switch (_activeBehavior) {
    WanderBehavior.patrol => 0.7,
    WanderBehavior.ponder => 0.5,
    WanderBehavior.stroll => 0.4,
    WanderBehavior.homebody => 0.55,
    WanderBehavior.waterside => 0.35,
    WanderBehavior.playful => 0.85, // meraklı, sürekli etrafa bakar
  };

  /// Yeni hedef seçerken bazen hiç gitmeyip olduğu yerde oyalanma olasılığı.
  double get _stayChance => switch (_activeBehavior) {
    WanderBehavior.patrol => 0.0,
    WanderBehavior.ponder => 0.45,
    WanderBehavior.stroll => 0.12,
    WanderBehavior.homebody => 0.22,
    WanderBehavior.waterside => 0.10,
    WanderBehavior.playful => 0.05, // nadiren durur
  };

  void update(
    double dt,
    int gridCols,
    int gridRows,
    Random rng, {
    Set<(int, int)> waterTiles = const {},
    Set<(int, int)> softObstacles = const {},
    double dayLight = 1.0,
    double rainIntensity = 0.0,
  }) {
    // Ölüyor — AI/hareket donar (renderer çöküşü çizer, scene timer'ı sayar).
    if (isDying) return;

    // Sürgün — AI donar; köylü kenara yürür, varınca sahne onu kaldırır. Ölüm
    // çöküşü DEĞİL: köyden çıkıp gidiyor (bkz. startLeaving / _exileVillager).
    if (isLeaving) {
      isWalking = true;
      state = VillagerState.moving;
      if (moveTowards(_leaveX, _leaveY, dt, arriveD: 0.6)) leftVillage = true;
      walkPhase += dt * speed * 5.5;
      walkPhase %= pi * 2;
      return;
    }

    // ── Yaşlanma — her durumda (uyku/taşıma dahil) ilerler ────────────────
    ageDays += dt / kGameDaySeconds;
    // Yaş-evresi boyut geçişini yumuşat (eşikte sıçramayı önler; ilk karede snap).
    final targetScale = lifeStage.renderScale;
    if (_displayScaleInit) {
      displayScale += (targetScale - displayScale) * min(1.0, dt / 1.2);
    } else {
      displayScale = targetScale;
      _displayScaleInit = true;
    }

    // Meşale fade — WorkerEntity.tickTorch sahnenin son sweep'inden çalışır.
    // Eligibility villager'a özgü (override edilmiş): aşağıda
    // torchEligibleDefault getter'ı handle eder.

    // ── Doğurganlık sayacı — yetişkin kadın, ev sahibi → tick down.
    // 0'a inince scene _tickReproduction tetiği kontrol eder, doğum + reset.
    // Eligible değilse NaN'a düşer (init bekliyor).
    if (!isMale && lifeStage == LifeStage.adult && homeBuilding != null) {
      if (fertilityDays.isNaN) {
        // İlk kez eligible — uzun ilk gecikme (8-14 gün) aceleyi keser.
        fertilityDays = 8.0 + rng.nextDouble() * 6.0;
      } else if (fertilityDays > 0) {
        fertilityDays -= dt / kGameDaySeconds;
      }
      // ≤ 0 ise dokunma — scene tetik resetler.
    } else {
      fertilityDays = double.nan;
    }

    // ── Gece/gündüz geçişi ────────────────────────────────────────────────
    // [curfewBias] eşiği yukarı iter: sokağa çıkma yasağı altında köylü ortalık
    // hâlâ aydınlıkken içeri çekilir — akşam sokağı erken boşalır.
    //
    // TUZAK: uyanma eşiği yatma eşiğinin ÜSTÜNDE kalmalı. Yasak eşiği
    // kDawnThreshold'u geçerse köylü şafakta uyanır, aynı karede "hâlâ gece"
    // görüp tekrar yatar — kilitlenmiş bir titreme. Bu yüzden yasak ağırken
    // sabah da onunla birlikte kayar: yasak şafakla kalkar.
    final nightAt = kNightThreshold + curfewBias;
    final isNight = dayLight < nightAt;
    final isDawn =
        dayLight >=
        (kDawnThreshold > nightAt + 0.02 ? kDawnThreshold : nightAt + 0.02);

    // ── Porter: finish delivery first even at night ──────────────────────────
    // dt * carrySpeedMultiplier → step = speed * carrySpeedMult * dt (matematik
    // birebir aynı, ama moveTowards path-aware: uzak pickup yolları A* ile takip).
    if (state == VillagerState.walkingToPickup) {
      if (moveTowards(
        _pickupX,
        _pickupY,
        dt,
        arriveD: 0.25,
        speedScale: carrySpeedMultiplier,
      )) {
        gridX = _pickupX;
        gridY = _pickupY;
        loco.reset();
        final item = _pickupItem;
        if (item == null) {
          // Bozuk/yarım restore ya da dışarıdan kesilen görev teslim evresine
          // boş elle geçmesin; cancellation callback anchor'ı da geri alır.
          cancelCarryTask();
          return;
        }
        carriedItem = item;
        _pickupItem = null;
        state = VillagerState.carrying;
        isWalking = false;
      } else {
        isWalking = true;
      }
      walkPhase += dt * (isWalking ? speed * 5.5 : 1.2);
      walkPhase %= pi * 2;
      return;
    }

    if (state == VillagerState.carrying) {
      if (moveTowards(
        _deliverX,
        _deliverY,
        dt,
        arriveD: 0.25,
        speedScale: carrySpeedMultiplier,
      )) {
        gridX = _deliverX;
        gridY = _deliverY;
        loco.reset();
        final onDelivered = _onDelivered;
        // Teslim callback'i kaynak listesini değiştirebilir, hatta hata
        // fırlatabilir. Önce köylünün state'ini atomik biçimde temizle; aksi
        // halde callback sırasında aynı teslimat bir sonraki karede tekrarlanır.
        _pickupItem = null;
        carriedItem = null;
        _onDelivered = null;
        _onCarryCancelled = null;
        _pickupX = _pickupY = _deliverX = _deliverY = 0;
        state = VillagerState.idle;
        idleTimer = 0.4 + rng.nextDouble() * 1.5;
        isWalking = false;
        onDelivered?.call();
      } else {
        isWalking = true;
      }
      walkPhase += dt * (isWalking ? speed * 5.5 : 1.2);
      walkPhase %= pi * 2;
      return;
    }

    // ── Ateş başı oturma — wander'dan önce ama uyku'dan önce kontrol edilir.
    // Uyku geldiyse sit iptal edilip sleep akışı devralır.
    if (sitClaimed) {
      // Soğuktan kalkmış köylü ateş başına oturmak İÇİN kalktı — gece diye onu
      // hemen yatağa geri yollamak tüm mekanizmayı boşa çıkarırdı.
      if (isNight && !_wasSleeping && sleepRestless <= 0) {
        _cancelSit();
        // fall through → aşağıdaki isNight bloğu sleep'i başlatsın
      } else {
        if (!isSeatedAtFire) {
          // Slot'a yürü
          isWalking = true;
          if (moveTowards(sitArriveX, sitArriveY, dt, arriveD: 0.18)) {
            gridX = sitArriveX;
            gridY = sitArriveY;
            loco.reset();
            isWalking = false;
            facingRight = sitFaceX > gridX;
          }
        } else {
          // Oturmuş — süre tüket, yüzü ateşe dön.
          facingRight = sitFaceX > gridX;
          isWalking = false;
          warmthTimer -= dt;
          if (warmthTimer <= 0) {
            _cancelSit();
            state = VillagerState.idle;
            idleTimer = 0.4 + rng.nextDouble() * 0.8;
          }
        }
        walkPhase += dt * (isWalking ? speed * 5.5 : 0.6);
        walkPhase %= pi * 2;
        return;
      }
    }

    // Soğuktan kalkma sayacı — bitince köylü kaldığı yerden uykuya döner.
    if (sleepRestless > 0) sleepRestless = max(0.0, sleepRestless - dt);

    // YATAĞA DÖNÜŞ — `_wasSleeping` eskiden TEK ATIŞLIK bir kilitti: köylüyü
    // gece bir kez yataktan koparan her şey (iş döngüsünün goTo'su, tören,
    // taşıma görevi) onu SABAHA KADAR ayakta bırakıyordu. Ölçüm: derin gecede
    // 7-10 köylü "boşta" — uyumadan, iş yapmadan dikiliyorlardı.
    //
    // Kapı artık yeniden kurulabilir, ama üç şart altında: köylü gerçekten
    // BOŞTA olmalı (yürüyeni/çalışanı yataga zorlamak sahneyi bozar), şafak
    // OLMAMALI ve tören/oturma altında olmamalı. Şafak şartı histerezisi
    // korur: yatma ve kalkma eşikleri çakışırsa köylü şafakta yat-kalk
    // titrerdi (bkz. test/curfew_test.dart flip sayacı).
    final canReturnToBed =
        _wasSleeping &&
        !isDawn &&
        state == VillagerState.idle &&
        activity == VillagerActivity.none &&
        !sitClaimed;

    // Nöbetçi geceyi uyanık geçirir — uyku akışına hiç girmez.
    if (isNight &&
        (!_wasSleeping || canReturnToBed) &&
        !nightDuty &&
        sleepRestless <= 0) {
      _wasSleeping = true;
      if (sleepTarget != null) {
        state = VillagerState.walkingToSleep;
        isWalking = true;
      } else {
        state = VillagerState.sleeping;
        isWalking = false;
      }
    } else if (isDawn && _wasSleeping) {
      // KADEMELİ UYANIŞ — herkes aynı anda ışınlanıp kapıdan fırlamasın.
      // İlk şafak karesinde kişisel bir gecikme kurulur; köylü o kadar daha
      // "yatakta" kalır (state sleeping), sonra gerinerek (content) uyanır.
      // Sonuç: sabah dalga dalga başlar, ölü "toplu spawn" gider.
      if (_wakeDelay < 0) _wakeDelay = 0.5 + rng.nextDouble() * 6.0;
      _wakeDelay -= dt;
      if (_wakeDelay <= 0) {
        state = VillagerState.idle;
        idleTimer = 1.0 + rng.nextDouble() * 2.0;
        _wasSleeping = false;
        _wakeDelay = -1.0; // bir sonraki gece için sıfırla
        isInsideBuilding = false;
        facingRight = rng.nextBool();
        feel(NpcEmotion.content, 1.6, moodDelta: 0.02); // gerinme/esneme
      }
    }

    if (state == VillagerState.walkingToSleep) {
      final (tx, ty) = sleepTarget!;
      if (moveTowards(tx, ty, dt, arriveD: 0.55)) {
        gridX = tx;
        gridY = ty;
        loco.reset();
        state = VillagerState.sleeping;
        isWalking = false;
        if (sleepIsHome) isInsideBuilding = true;
      } else {
        isWalking = true;
      }
      walkPhase += dt * (isWalking ? speed * 5.5 : 0.4);
      walkPhase %= pi * 2;
      return;
    }

    if (state == VillagerState.sleeping) {
      walkPhase += dt * 0.4;
      walkPhase %= pi * 2;
      return;
    }

    // ── Normal gündüz davranışı ───────────────────────────────────────────
    switch (state) {
      case VillagerState.idle:
        idleTimer -= dt;
        _lookTimer -= dt;
        // Boştayken ara sıra etrafa bakınma — donuk durmak yerine canlı durur.
        if (_lookTimer <= 0) {
          if (idleTimer > 0.5 && rng.nextDouble() < _lookChance) {
            facingRight = !facingRight;
          }
          _lookTimer = 0.7 + rng.nextDouble() * 1.8;
        }
        // Bir sosyal aktivitedeyken (sohbet/müzik/dans) yerinde kal — hedef
        // seçip konuşmanın ortasında kayıp gitme.
        if (idleTimer <= 0 && activity == VillagerActivity.none) {
          // Aktif işi varsa kendi başına gezinme — sahne iş döngüsü
          // (`_workBuilder/_workFarmer/…`) bir sonraki `goTo` hedefini verecek.
          // Köylü işyerinde/site'ta sabit bekler; iş loop'u onu sürer.
          if (hasActiveJob) {
            // Kısa bekleme — iş loop'u (~0.6 sn) devralana dek yerinde dur.
            idleTimer = 0.5;
          } else if (canRunErrands) {
            // Oyalanma bitti → amaçlı hedef akışı. Sahne rutin sistemi
            // (needsErrand) zamana/ihtiyaca göre bir POI atar; o gelene kadar
            // köylü "ne yapsam" diye kısa bekler. Atanamazsa (POI yok / çocuk)
            // eski kişisel dolaşmaya düşer — donuk kalmaz.
            needsErrand = true;
            _errandWait += dt;
            if (_errandWait > 4.0) {
              _pickNewTarget(
                gridCols,
                gridRows,
                rng,
                waterTiles,
                softObstacles,
              );
              _errandWait = 0;
            }
          } else {
            _pickNewTarget(gridCols, gridRows, rng, waterTiles, softObstacles);
          }
        }

      case VillagerState.moving:
        final prevX = gridX;
        final prevY = gridY;
        // TUZAK (düzeltildi): arriveD 0.05 idi ve varışta konum hedefe SNAP
        // ediliyordu. Separation itmesiyle birleşince NPC hedefin çevresinde
        // mikro-salınım yapıyor, her salınımda ışınlanıyordu. Artık varış
        // yarıçapı gerçekçi (0.32) ve snap yok — lokomosyon zaten frenleyerek
        // geliyor, kalan farkı render lerp'i yutuyor.
        if (moveTowards(
          targetCol,
          targetRow,
          dt,
          arriveD: 0.32,
          speedScale: _tripSpeed,
        )) {
          // Devriyede vardığında sıradaki uca dön.
          if (_activeBehavior == WanderBehavior.patrol) _patToB = !_patToB;
          state = VillagerState.idle;
          if (_onErrand) {
            // Amaçlı hedefe vardı → orada bir süre oyalan (iş/sohbet/dinlence
            // hissi). Bitince needsErrand ile sahne yeni hedef atar.
            idleTimer = _errandDwell;
            _onErrand = false;
          } else {
            final (lo, hi) = _dwellRange;
            idleTimer = lo + rng.nextDouble() * (hi - lo);
          }
          _lookTimer = 0.4 + rng.nextDouble();
        } else if (waterTiles.contains((gridX.round(), gridY.round()))) {
          // Kısa hop (< 3 tile) için A* skip edilir; düz adım suya saplanırsa
          // pushback ile geri al + idle'a düş, hedefi yeniden seçsin.
          gridX = prevX;
          gridY = prevY;
          loco.reset();
          state = VillagerState.idle;
          idleTimer = 0.1;
        }

      case VillagerState.sleeping:
      case VillagerState.walkingToSleep:
      case VillagerState.walkingToPickup:
      case VillagerState.carrying:
        break; // yukarıda ele alındı
    }

    isWalking = state == VillagerState.moving;
    walkPhase += dt * (isWalking ? speed * 5.5 : 1.2);
    walkPhase %= pi * 2;
  }

  /// Kişiliğe göre yeni dolaşma hedefi seçer.  Hedefler artık spawn noktasına
  /// demirlenir (haritada başıboş sürüklenme yerine kendi bölgesinde kalır).
  void _pickNewTarget(
    int cols,
    int rows,
    Random rng,
    Set<(int, int)> waterTiles,
    Set<(int, int)> softObstacles,
  ) {
    const pad = 1;
    final minC = pad.toDouble(), minR = pad.toDouble();
    final maxC = (cols - 1 - pad).toDouble();
    final maxR = (rows - 1 - pad).toDouble();

    // Bazı kişilikler bazen hiç hareket etmeden olduğu yerde oyalanır.
    if (_activeBehavior != WanderBehavior.patrol &&
        rng.nextDouble() < _stayChance) {
      final (lo, hi) = _dwellRange;
      idleTimer = lo + rng.nextDouble() * (hi - lo);
      return;
    }

    // Devriye: iki sabit uç arasında mekik.
    if (_activeBehavior == WanderBehavior.patrol) {
      if (!_patInit) _initPatrol(rng, minC, minR, maxC, maxR, waterTiles);
      targetCol = _patToB ? _patBx : _patAx;
      targetRow = _patToB ? _patBy : _patAy;
      state = VillagerState.moving;
      return;
    }

    // Tur başına yarıçap dalgalanması — tekdüze adımları kırar.
    final radius = _roamRadius * (0.7 + rng.nextDouble() * 0.5);

    (double, double)? result;
    if (_activeBehavior == WanderBehavior.waterside) {
      result = _waterEdgeTarget(
        rng,
        radius,
        waterTiles,
        softObstacles,
        minC,
        minR,
        maxC,
        maxR,
      );
    }
    // YÖN SÜREKLİLİĞİ — yeni hedef, mevcut gidişin devamı olmaya çalışır.
    // Bu olmadan ardışık iki hedef yarı yarıya zıt yönde çıkıyor ve köylü
    // gerçek anlamda git-gel yapıyordu. Durakta hız 0 olduğu için son bakış
    // yönü heading yerine geçer: "baktığı tarafa doğru yürür".
    var hx = loco.vx, hy = loco.vy;
    if (hx * hx + hy * hy < 0.02) {
      hx = facingRight ? 1.0 : -1.0;
      hy = 0.0;
    }
    result ??= pickWanderTarget(
      spawnCol,
      spawnRow,
      radius,
      rng,
      waterTiles: waterTiles,
      softObstacles: softObstacles,
      minC: minC,
      minR: minR,
      maxC: maxC,
      maxR: maxR,
      headX: hx,
      headY: hy,
      // Yarım tile'lık "hedefler" varış yarıçapının içinde kalıp anlık
      // titremeye dönüşüyordu — gerçek bir yolculuk en az bu kadar olsun.
      minDist: 1.4,
    );

    if (result != null) {
      targetCol = result.$1;
      targetRow = result.$2;
      state = VillagerState.moving;
    } else {
      idleTimer = 0.3 + rng.nextDouble();
    }
  }

  /// Devriye uçlarını spawn'dan geçen rastgele bir eksen boyunca bir kez kurar.
  void _initPatrol(
    Random rng,
    double minC,
    double minR,
    double maxC,
    double maxR,
    Set<(int, int)> waterTiles,
  ) {
    _patInit = true;
    final ang = rng.nextDouble() * pi; // 0..π → eksen yönü
    final half = 2.5 + rng.nextDouble() * 2.0; // yarı uzunluk
    final dx = cos(ang) * half, dy = sin(ang) * half;
    _patAx = (spawnCol - dx).clamp(minC, maxC);
    _patAy = (spawnRow - dy).clamp(minR, maxR);
    _patBx = (spawnCol + dx).clamp(minC, maxC);
    _patBy = (spawnRow + dy).clamp(minR, maxR);
    // Bir uç su üstüne denk gelirse spawn'a çek.
    if (waterTiles.contains((_patAx.round(), _patAy.round()))) {
      _patAx = spawnCol;
      _patAy = spawnRow;
    }
    if (waterTiles.contains((_patBx.round(), _patBy.round()))) {
      _patBx = spawnCol;
      _patBy = spawnRow;
    }
  }

  /// Su kenarı hedefi — suya komşu ama su olmayan bir tile tercih eder.
  /// Bulunamazsa null döner (çağıran normal dolaşmaya düşer).
  (double, double)? _waterEdgeTarget(
    Random rng,
    double radius,
    Set<(int, int)> waterTiles,
    Set<(int, int)> softObstacles,
    double minC,
    double minR,
    double maxC,
    double maxR,
  ) {
    for (int i = 0; i < 10; i++) {
      final tx = (spawnCol + rng.nextDouble() * radius * 2 - radius).clamp(
        minC,
        maxC,
      );
      final ty = (spawnRow + rng.nextDouble() * radius * 2 - radius).clamp(
        minR,
        maxR,
      );
      final c = tx.round(), r = ty.round();
      if (waterTiles.contains((c, r))) continue;
      if (softObstacles.contains((c, r))) continue;
      final nearWater =
          waterTiles.contains((c + 1, r)) ||
          waterTiles.contains((c - 1, r)) ||
          waterTiles.contains((c, r + 1)) ||
          waterTiles.contains((c, r - 1));
      if (nearWater) return (tx, ty);
    }
    return null;
  }
}
