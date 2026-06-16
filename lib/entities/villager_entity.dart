import 'dart:math';
import '../characters/villager_type.dart';
import '../characters/npc_visual.dart';
import '../characters/life_stage.dart';
import '../core/constants.dart';
import 'worker_entity.dart';

enum VillagerState { moving, idle, sleeping, walkingToSleep, walkingToPickup, carrying }

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
enum VillagerActivity { none, chat, music, dance, warm, storytelling, listening }

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
  final VillagerType type;

  /// Köylünün adı — kurucu NPC'lerde rastgele atanır, sonradan doğanlar
  /// _spawnGrownVillager'da random alır. Aile/bildirim sisteminde kullanılır.
  /// Oyuncu bilgi panelinden istediği zaman yeniden adlandırabilir.
  String name;

  /// Oyuncu bu köylüyü "favori" olarak işaretledi mi (kalp/yıldız). Sadece
  /// görsel — panel başlığında rozet, ileride hızlı erişim listesi için temel.
  bool isFavorite = false;

  /// Oyuncu tarafından kaç kez selamlanmış (etkileşim sayacı, panelde göster).
  int greetCount = 0;

  /// Oyuncudan kaç hediye aldı.
  int giftCount = 0;

  /// Aile bağları — bebek doğduğunda evdeki yetişkin sakinler ebeveyn olur
  /// (max 2). Kurucu NPC'lerde boş. Ölüm anında karşı taraf listesinden
  /// referansı kaldırılır.
  final List<VillagerEntity> parents  = [];
  final List<VillagerEntity> children = [];

  double targetCol;
  double targetRow;

  VillagerState state = VillagerState.idle;
  double idleTimer = 0;

  // ── Rutin / errand (amaçlı hedef akışı) ────────────────────────────────────
  /// true → köylü boşta ve serbest; sahne rutin sistemi ona amaçlı bir hedef
  /// (pazar/taverna/kuyu/ev...) atamalı. Atanınca [goTo] ile false olur.
  bool needsErrand = false;
  bool _onErrand = false;
  double _errandDwell = 0;   // hedefe varınca kaç sn oyalanacak
  double _errandWait = 0;    // atanmayı kaç sn bekledi (fallback için)

  /// Çocuklar errand yürütmez (oyuncul dolaşır); yetişkin/genç/yaşlı yürütür.
  bool get canRunErrands => lifeStage != LifeStage.child;

  /// Sahne rutin sistemi çağırır: amaçlı bir hedefe yürü, varınca [dwell] sn
  /// orada oyalan (bir şey yapıyormuş gibi). Amaçsız wander'ın yerini alır.
  /// Bir noktaya dönüp bakar — gerçek gövde dili ("fark etti, baktı").
  /// Yalnızca yönü çevirir (glance tetiklemez ki bakış o noktada sabit kalsın).
  /// Reaksiyon dalgalarında ([_reactNearby]) çağrılır.
  void lookToward(double x, double y) {
    if ((x - gridX).abs() > 0.05) facingRight = x > gridX;
  }

  void goTo(double x, double y, double dwell) {
    targetCol = x;
    targetRow = y;
    _errandDwell = dwell;
    _onErrand = true;
    needsErrand = false;
    _errandWait = 0;
    state = VillagerState.moving;
    glanceAround(duration: 0.6);
  }

  @override
  final double speed;

  /// Bu NPC'nin boş zaman hareket kişiliği — tipe göre sabit.
  final WanderBehavior behavior;

  /// Etrafa bakınma sayacı — boştayken yerinde dönüp gözlem yapar.
  double _lookTimer = 0;

  // ── Devriye (patrol) durumu — iki uç nokta arası mekik ────────────────────
  bool _patInit = false;   // uçlar spawn'a göre bir kez hesaplanır
  bool _patToB  = true;    // sıradaki hedef B mi (değilse A)
  double _patAx = 0, _patAy = 0, _patBx = 0, _patBy = 0;

  // Uyku sistemi
  bool _wasSleeping = false;
  /// Nereye gidip uyuyacak (main.dart tarafından her gece atanır)
  (double, double)? sleepTarget;
  /// true → eve girmiş sayılır (render edilmez)
  bool sleepIsHome = false;
  /// Şu an bina içinde mi (gizlenir)
  bool isInsideBuilding = false;
  /// Atanan ev binası (null = evsiz)
  Object? homeBuilding; // BuildingEntity türü, döngüsel import önlemek için Object

  // Porter/carry sistemi
  Object? _pickupItem;           // ResourceBox veya HayEntity
  Object? carriedItem;           // aktif taşıma sırasında görünür
  double _pickupX = 0, _pickupY = 0;
  double _deliverX = 0, _deliverY = 0;
  void Function()? _onDelivered;

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

  /// Bilge yaşlı — random event "Bilge Yaşlı Belirdi" ile yalnız bir köylüye
  /// atanır (yaşam boyu kalır). Köyde bilge varken ufak moral bonusu doğar.
  bool isSage = false;

  /// Sosyal aktivite durumu — atmosferik "yaşayan köy" katmanı.
  /// [activity] aktif tip; [chatBubbleTime] kalan süre; [chatBubbleIcon]
  /// baloncukta gösterilen emoji.
  double chatBubbleTime = 0;
  String chatBubbleIcon = '';
  VillagerActivity activity = VillagerActivity.none;
  /// Bu NPC'nin son aktiviteden sonraki kişisel cooldown'u (sn). Her NPC
  /// kendi başına değerlendirilir → global cap yok, nüfus arttıkça toplam
  /// aktivite doğal artar. 60-180 sn.
  double socialCooldown = 0;

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
    if (e != NpcEmotion.none && (emotion == NpcEmotion.none || dur >= emotionTime)) {
      emotion = e;
      emotionTime = dur;
      _emotionDur = dur;
    }
    if (moodDelta != 0) mood = (mood + moodDelta).clamp(-1.0, 1.0);
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
    isDying = true;
    _deathDur = duration;
    _deathT = duration;
    deathHoldsFuneral = funeral;
    emotion = NpcEmotion.none;
    emotionTime = 0;
    if (sitClaimed) _cancelSit();
  }

  /// İç dünyayı her tick ilerletir: duygu zamanlayıcısı, mood'un nötre dönüşü,
  /// enerji tüketimi/yenilenmesi. [dayLight] gündüz/gece, [resting] uyku/ısınma.
  void tickInnerLife(double dt, double dayLight, bool resting) {
    // Ölüm animasyonu sırasında iç dünya donar — sadece çöküş geri sayar.
    if (isDying) {
      _deathT -= dt;
      return;
    }
    if (emotionTime > 0) {
      emotionTime -= dt;
      if (emotionTime <= 0) emotion = NpcEmotion.none;
    }
    // Mood yavaşça nötre döner (gün başına ~0.5 sönüm).
    if (mood != 0) {
      final decay = (dt / kGameDaySeconds) * 0.5;
      if (mood > 0) {
        mood = (mood - decay).clamp(0.0, 1.0);
      } else {
        mood = (mood + decay).clamp(-1.0, 0.0);
      }
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
  void assignSit(double slotX, double slotY, double centerX, double centerY,
      double duration, void Function() release) {
    sitArriveX  = slotX;
    sitArriveY  = slotY;
    sitFaceX    = centerX;
    sitFaceY    = centerY;
    warmthTimer = duration;
    _releaseSit = release;
    sitClaimed  = true;
    activity    = VillagerActivity.warm;
    firePose    = FirePose.sit; // varsayılan; reaksiyon sonradan değiştirebilir
    chatBubbleIcon = '';
    chatBubbleTime = 0;
  }

  /// Oturmayı iptal et — slot'u serbest bırak, alanları temizle. Uyku/karar
  /// dışı durumlar için savunmacı.
  void _cancelSit() {
    _releaseSit?.call();
    _releaseSit = null;
    sitClaimed  = false;
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
    required bool male,
    required super.startCol,
    required super.startRow,
    int? visualSeed,
    this.ageDays = 0,
    this.lifespanDays = double.infinity,
  })  : targetCol = startCol,
        targetRow = startRow,
        speed     = _speedFor(type),
        behavior  = _behaviorFor(type),
        // Visual seed'ten görsel detaylar (saç/ten/göz) gelir, ama cinsiyet
        // dışarıdan zorlanır → name ile uyumlu kalır.
        super(
          visual: NpcVisual.fromSeed(
              visualSeed ?? _autoSeed(type, startCol, startRow),
              forceMale: male),
        );

  /// NPC'nin cinsiyeti — visual.isMale ile aynı (getter pratik erişim).
  bool get isMale => visual.isMale;

  /// Otomatik visual seed — type + spawn pozisyonu hash'i.  Aynı pozisyondan
  /// aynı tipte spawn olan iki NPC olmaz pratikte, ama görsel seed verilebilir.
  static int _autoSeed(VillagerType t, double c, double r) =>
      t.index * 7919
      ^ (c * 1009).toInt() * 13
      ^ (r * 1031).toInt() * 31
      ^ DateTime.now().microsecondsSinceEpoch & 0xFFFF;

  bool get isSleeping => state == VillagerState.sleeping;

  /// Villager torch eligibility: yetişkin/yaşlı, dışarıda, uyumuyor, ateşte
  /// oturmuyor. walkingToSleep eligible — eve yürürken torch yansın.
  /// sitClaimed olup henüz oturmamış da eligible (ateşe yürürken torch).
  @override
  bool get torchEligibleDefault =>
      !isInsideBuilding &&
      state != VillagerState.sleeping &&
      !isSeatedAtFire &&
      hasProfession;
  bool get isCarrying => state == VillagerState.carrying || state == VillagerState.walkingToPickup;

  /// Güncel yaşam evresi (yaştan türer).
  LifeStage get lifeStage => lifeStageForDays(ageDays);

  /// Yetişkin/yaşlı → meslek görünümü; çocuk/genç → mesleksiz köylü.
  bool get hasProfession => lifeStage.hasProfession;

  /// Çocuk mu? Taşıma/iş ataması dışı tutulur, oyuncu davranış uygular.
  bool get isChild => lifeStage == LifeStage.child;

  /// O anki etkin dolaşma davranışı. Çocukken tipinin davranışı yerine
  /// [WanderBehavior.playful]; büyüyünce kendi tip davranışına döner.
  WanderBehavior get _activeBehavior =>
      isChild ? WanderBehavior.playful : behavior;

  void assignCarryTask(Object item, double pickX, double pickY,
      double destX, double destY, {void Function()? onDelivered}) {
    _pickupItem  = item;
    _pickupX     = pickX;
    _pickupY     = pickY;
    _deliverX    = destX;
    _deliverY    = destY;
    _onDelivered = onDelivered;
    state        = VillagerState.walkingToPickup;
    isWalking    = true;
  }

  static double _speedFor(VillagerType t) {
    switch (t) {
      case VillagerType.farmer:     return 1.2;
      case VillagerType.merchant:   return 0.9;
      case VillagerType.blacksmith: return 0.8;
      case VillagerType.guard:      return 1.6;
      case VillagerType.mage:       return 0.7;
      case VillagerType.miner:      return 0.85;
      case VillagerType.fisher:     return 1.1;
    }
  }

  static WanderBehavior _behaviorFor(VillagerType t) => switch (t) {
        VillagerType.guard      => WanderBehavior.patrol,
        VillagerType.mage       => WanderBehavior.ponder,
        VillagerType.merchant   => WanderBehavior.stroll,
        VillagerType.farmer     => WanderBehavior.stroll,
        VillagerType.blacksmith => WanderBehavior.homebody,
        VillagerType.miner      => WanderBehavior.homebody,
        VillagerType.fisher     => WanderBehavior.waterside,
      };

  // ── Kişilik parametreleri (etkin davranışa göre) ───────────────────────────
  /// Spawn çevresinde dolaşma yarıçapı (tile).
  double get _roamRadius => switch (_activeBehavior) {
        WanderBehavior.patrol    => 3.0,
        WanderBehavior.ponder    => 1.5,
        WanderBehavior.stroll    => 3.5,
        WanderBehavior.homebody  => 1.8,
        WanderBehavior.waterside => 4.0,
        WanderBehavior.playful   => 3.0, // yuva çevresinde koşuşturur
      };

  /// Hedefe varınca duraklama süresi aralığı (saniye).
  (double, double) get _dwellRange => switch (_activeBehavior) {
        WanderBehavior.patrol    => (2.0, 4.0),
        WanderBehavior.ponder    => (4.0, 9.0),
        WanderBehavior.stroll    => (1.5, 4.5),
        WanderBehavior.homebody  => (1.0, 3.0),
        WanderBehavior.waterside => (2.0, 5.0),
        WanderBehavior.playful   => (0.2, 1.2), // hiç durmaz, hep hareket halinde
      };

  /// Yürürken ana hıza uygulanan çarpan — kişiliğe göre tempo.
  double get _tripSpeed => switch (_activeBehavior) {
        WanderBehavior.patrol    => 1.0,
        WanderBehavior.ponder    => 0.55,
        WanderBehavior.stroll    => 0.7,
        WanderBehavior.homebody  => 0.65,
        WanderBehavior.waterside => 0.85,
        WanderBehavior.playful   => 1.35, // kısa hızlı koşuşturmalar
      };

  /// Boştayken bir "bakınma anında" yön değiştirme olasılığı.
  double get _lookChance => switch (_activeBehavior) {
        WanderBehavior.patrol    => 0.7,
        WanderBehavior.ponder    => 0.5,
        WanderBehavior.stroll    => 0.4,
        WanderBehavior.homebody  => 0.55,
        WanderBehavior.waterside => 0.35,
        WanderBehavior.playful   => 0.85, // meraklı, sürekli etrafa bakar
      };

  /// Yeni hedef seçerken bazen hiç gitmeyip olduğu yerde oyalanma olasılığı.
  double get _stayChance => switch (_activeBehavior) {
        WanderBehavior.patrol    => 0.0,
        WanderBehavior.ponder    => 0.45,
        WanderBehavior.stroll    => 0.12,
        WanderBehavior.homebody  => 0.22,
        WanderBehavior.waterside => 0.10,
        WanderBehavior.playful   => 0.05, // nadiren durur
      };

  void update(double dt, int gridCols, int gridRows, Random rng,
      {Set<(int, int)> waterTiles  = const {},
       Set<(int, int)> softObstacles = const {},
       double dayLight = 1.0,
       double rainIntensity = 0.0}) {

    // Ölüyor — AI/hareket donar (renderer çöküşü çizer, scene timer'ı sayar).
    if (isDying) return;

    // ── Yaşlanma — her durumda (uyku/taşıma dahil) ilerler ────────────────
    ageDays += dt / kGameDaySeconds;

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
    final isNight = dayLight < kNightThreshold;
    final isDawn  = dayLight >= kDawnThreshold;

    // ── Porter: finish delivery first even at night ──────────────────────────
    // dt * carrySpeedMultiplier → step = speed * carrySpeedMult * dt (matematik
    // birebir aynı, ama moveTowards path-aware: uzak pickup yolları A* ile takip).
    if (state == VillagerState.walkingToPickup) {
      if (moveTowards(_pickupX, _pickupY, dt * carrySpeedMultiplier, arriveD: 0.25)) {
        gridX       = _pickupX;
        gridY       = _pickupY;
        carriedItem = _pickupItem;
        _pickupItem = null;
        state       = VillagerState.carrying;
        isWalking   = false;
      } else {
        isWalking = true;
      }
      walkPhase += dt * (isWalking ? speed * 5.5 : 1.2);
      walkPhase %= pi * 2;
      return;
    }

    if (state == VillagerState.carrying) {
      if (moveTowards(_deliverX, _deliverY, dt * carrySpeedMultiplier, arriveD: 0.25)) {
        gridX = _deliverX;
        gridY = _deliverY;
        _onDelivered?.call();
        _onDelivered = null;
        carriedItem  = null;
        state        = VillagerState.idle;
        idleTimer    = 0.4 + rng.nextDouble() * 1.5;
        isWalking    = false;
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
      if (isNight && !_wasSleeping) {
        _cancelSit();
        // fall through → aşağıdaki isNight bloğu sleep'i başlatsın
      } else {
        if (!isSeatedAtFire) {
          // Slot'a yürü
          isWalking = true;
          if (moveTowards(sitArriveX, sitArriveY, dt, arriveD: 0.18)) {
            gridX     = sitArriveX;
            gridY     = sitArriveY;
            isWalking = false;
            facingRight = sitFaceX > gridX;
          }
        } else {
          // Oturmuş — süre tüket, yüzü ateşe dön.
          facingRight = sitFaceX > gridX;
          isWalking   = false;
          warmthTimer -= dt;
          if (warmthTimer <= 0) {
            _cancelSit();
            state     = VillagerState.idle;
            idleTimer = 0.4 + rng.nextDouble() * 0.8;
          }
        }
        walkPhase += dt * (isWalking ? speed * 5.5 : 0.6);
        walkPhase %= pi * 2;
        return;
      }
    }

    if (isNight && !_wasSleeping) {
      _wasSleeping = true;
      if (sleepTarget != null) {
        state     = VillagerState.walkingToSleep;
        isWalking = true;
      } else {
        state     = VillagerState.sleeping;
        isWalking = false;
      }
    } else if (isDawn && _wasSleeping) {
      state               = VillagerState.idle;
      idleTimer           = 1.0 + rng.nextDouble() * 2.0;
      _wasSleeping        = false;
      isInsideBuilding    = false;
    }

    if (state == VillagerState.walkingToSleep) {
      final (tx, ty) = sleepTarget!;
      if (moveTowards(tx, ty, dt, arriveD: 0.55)) {
        gridX = tx; gridY = ty;
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
        idleTimer  -= dt;
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
          // Oyalanma bitti → amaçlı hedef akışı. Sahne rutin sistemi
          // (needsErrand) zamana/ihtiyaca göre bir POI atar; o gelene kadar
          // köylü "ne yapsam" diye kısa bekler. Atanamazsa (POI yok / çocuk)
          // eski kişisel dolaşmaya düşer — donuk kalmaz.
          if (canRunErrands) {
            needsErrand = true;
            _errandWait += dt;
            if (_errandWait > 4.0) {
              _pickNewTarget(gridCols, gridRows, rng, waterTiles, softObstacles);
              _errandWait = 0;
            }
          } else {
            _pickNewTarget(gridCols, gridRows, rng, waterTiles, softObstacles);
          }
        }

      case VillagerState.moving:
        final prevX = gridX;
        final prevY = gridY;
        if (moveTowards(targetCol, targetRow, dt * _tripSpeed, arriveD: 0.05)) {
          gridX = targetCol;
          gridY = targetRow;
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
          gridX     = prevX;
          gridY     = prevY;
          state     = VillagerState.idle;
          idleTimer = 0.1;
        }

      case VillagerState.sleeping:
      case VillagerState.walkingToSleep:
      case VillagerState.walkingToPickup:
      case VillagerState.carrying:
        break; // yukarıda ele alındı
    }

    isWalking  = state == VillagerState.moving;
    walkPhase += dt * (isWalking ? speed * 5.5 : 1.2);
    walkPhase %= pi * 2;
  }

  /// Kişiliğe göre yeni dolaşma hedefi seçer.  Hedefler artık spawn noktasına
  /// demirlenir (haritada başıboş sürüklenme yerine kendi bölgesinde kalır).
  void _pickNewTarget(int cols, int rows, Random rng,
      Set<(int, int)> waterTiles, Set<(int, int)> softObstacles) {
    const pad  = 1;
    final minC = pad.toDouble(), minR = pad.toDouble();
    final maxC = (cols - 1 - pad).toDouble();
    final maxR = (rows - 1 - pad).toDouble();

    // Bazı kişilikler bazen hiç hareket etmeden olduğu yerde oyalanır.
    if (_activeBehavior != WanderBehavior.patrol && rng.nextDouble() < _stayChance) {
      final (lo, hi) = _dwellRange;
      idleTimer = lo + rng.nextDouble() * (hi - lo);
      return;
    }

    // Devriye: iki sabit uç arasında mekik.
    if (_activeBehavior == WanderBehavior.patrol) {
      if (!_patInit) _initPatrol(rng, minC, minR, maxC, maxR, waterTiles);
      targetCol = _patToB ? _patBx : _patAx;
      targetRow = _patToB ? _patBy : _patAy;
      state     = VillagerState.moving;
      return;
    }

    // Tur başına yarıçap dalgalanması — tekdüze adımları kırar.
    final radius = _roamRadius * (0.7 + rng.nextDouble() * 0.5);

    (double, double)? result;
    if (_activeBehavior == WanderBehavior.waterside) {
      result = _waterEdgeTarget(
          rng, radius, waterTiles, softObstacles, minC, minR, maxC, maxR);
    }
    result ??= pickWanderTarget(
      spawnCol, spawnRow, radius, rng,
      waterTiles:    waterTiles,
      softObstacles: softObstacles,
      minC: minC, minR: minR, maxC: maxC, maxR: maxR,
    );

    if (result != null) {
      targetCol = result.$1;
      targetRow = result.$2;
      state     = VillagerState.moving;
    } else {
      idleTimer = 0.3 + rng.nextDouble();
    }
  }

  /// Devriye uçlarını spawn'dan geçen rastgele bir eksen boyunca bir kez kurar.
  void _initPatrol(Random rng, double minC, double minR, double maxC,
      double maxR, Set<(int, int)> waterTiles) {
    _patInit = true;
    final ang  = rng.nextDouble() * pi;          // 0..π → eksen yönü
    final half = 2.5 + rng.nextDouble() * 2.0;   // yarı uzunluk
    final dx = cos(ang) * half, dy = sin(ang) * half;
    _patAx = (spawnCol - dx).clamp(minC, maxC);
    _patAy = (spawnRow - dy).clamp(minR, maxR);
    _patBx = (spawnCol + dx).clamp(minC, maxC);
    _patBy = (spawnRow + dy).clamp(minR, maxR);
    // Bir uç su üstüne denk gelirse spawn'a çek.
    if (waterTiles.contains((_patAx.round(), _patAy.round()))) {
      _patAx = spawnCol; _patAy = spawnRow;
    }
    if (waterTiles.contains((_patBx.round(), _patBy.round()))) {
      _patBx = spawnCol; _patBy = spawnRow;
    }
  }

  /// Su kenarı hedefi — suya komşu ama su olmayan bir tile tercih eder.
  /// Bulunamazsa null döner (çağıran normal dolaşmaya düşer).
  (double, double)? _waterEdgeTarget(Random rng, double radius,
      Set<(int, int)> waterTiles, Set<(int, int)> softObstacles,
      double minC, double minR, double maxC, double maxR) {
    for (int i = 0; i < 10; i++) {
      final tx = (spawnCol + rng.nextDouble() * radius * 2 - radius)
          .clamp(minC, maxC);
      final ty = (spawnRow + rng.nextDouble() * radius * 2 - radius)
          .clamp(minR, maxR);
      final c = tx.round(), r = ty.round();
      if (waterTiles.contains((c, r))) continue;
      if (softObstacles.contains((c, r))) continue;
      final nearWater = waterTiles.contains((c + 1, r)) ||
          waterTiles.contains((c - 1, r)) ||
          waterTiles.contains((c, r + 1)) ||
          waterTiles.contains((c, r - 1));
      if (nearWater) return (tx, ty);
    }
    return null;
  }
}
