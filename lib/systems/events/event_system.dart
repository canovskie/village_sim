import 'dart:math';
import 'package:flutter/material.dart';
import '../../buildings/building_entity.dart';
import '../../buildings/building_type.dart';
import '../../characters/life_stage.dart';
import '../../core/resources.dart';
import '../../text/voice.dart';
import '../governance/governance_action.dart';

part 'event_catalog.dart';
part 'village_event_catalog.dart';

/// Olayların KALICI kimlikleri. Kod bir olayı BUNLARLA tanır — asla başlıkla.
/// Başlık oyuncunun gördüğü metindir ve serbestçe yeniden yazılabilir; id ise
/// omen/sahne/senaryo bağlarının tutunduğu çividir.
abstract final class EventIds {
  /// Zanaat açma akışının sistem-içi kararı; rastgele olay kataloğuna ait değil.
  static const specialistCaravan = 'specialistCaravan';
  static const muddyWell = 'muddyWell';
  static const marketSurplus = 'marketSurplus';
  static const approachingStorm = 'approachingStorm';
}

/// Olay kategorisi — UI banner rengi ve filtre için.
enum EventCategory { positive, negative, neutral }

/// Sahne efekt kimliği — renderer'ın hangi animasyonu çizeceğini belirler.
/// Her id painter içinde özel partikül/overlay pass'e karşılık gelir.
enum EventFx {
  none,
  festival, // ocak/meydan merkezli flama, yerel konfeti ve kâğıt fener
  cropBlight, // mevcut tarla sprite'ında solma dalgası + mantar asset'leri
  vigil, // ateş çevresinde sırayla yerleşen mum halkası ve ince duman
  cultRite, // zemine sabit, kademeli çizilen ayin halkası
  wedding, // meydan çelengi + çift çevresinde taç yaprakları
  harvestBounty, // mevcut ekin sprite'ında olgunlaşma/altın cross-fade dalgası
  plagueAura, // hastalıklı yeşil ekran tonu + yavaşlama (görsel: sick duruşu)
  fireOutbreak, // rastgele bina üstünde alev + yoğun duman
  storm, // yağmur boost + ekran maviye kayar
  droughtHaze, // ekran sarımsı, hava sıcak hissi
  beastEyes, // gece ateş etrafında çift kırmızı göz
}

/// Tek bir olay efektinin kendi zaman çizgisi.
///
/// Eski renderer yalnız sahnenin global saatini okuyordu. Bu yüzden yeni
/// başlayan bir bereket/şenlik efekti giriş karesinden değil, oyunun o anki
/// rastgele fazından başlıyordu. Bu küçük snapshot her efekti 0'dan başlatır ve
/// giriş/çıkış zarflarını olayın kendi süresine bağlar.
class EventFxPlayback {
  final double elapsed;
  final double duration;
  final double timeLeft;

  const EventFxPlayback({
    required this.elapsed,
    required this.duration,
    required this.timeLeft,
  });

  double get progress =>
      duration <= 0 ? 1.0 : (elapsed / duration).clamp(0.0, 1.0);

  double fadeIn([double seconds = 1.0]) =>
      seconds <= 0 ? 1.0 : (elapsed / seconds).clamp(0.0, 1.0);

  double fadeOut([double seconds = 1.0]) =>
      seconds <= 0 ? 1.0 : (timeLeft / seconds).clamp(0.0, 1.0);

  double envelope({double enter = 1.0, double exit = 1.0}) =>
      fadeIn(enter) * fadeOut(exit);
}

/// Bir olayın aktifken sahneye uyguladığı görsel + simülasyon etkileri.
/// Tüm alanlar opsiyonel — sadece anlam taşıyanlar set edilir.
class EventEffect {
  /// Sahne partikül/overlay seçici.
  final EventFx fx;

  /// Ekran tonu — yumuşak alpha ile sahne üstüne çizilir.
  /// Null = ton değişimi yok.
  final Color? screenTint;

  /// Yağmur şiddeti override — efekt aktifken bu en az `rainBoost` olur.
  final double rainBoost;

  /// NPC hız çarpanı (1.0 = değişim yok). Salgın 0.7, vb.
  final double npcSpeedMul;

  /// Çiftçi/tarla büyüme çarpanı (1.0 = değişim yok). Kuraklık 0.4, hasat 1.5.
  final double farmGrowthMul;

  /// İnşaatçı çalışma çarpanı (1.0 = değişim yok). Fırtınada 0.0 (durur).
  final double builderMul;

  /// Bu sahne efektinin toplam aktif süresi (sn). Genelde moral süresi ile
  /// uyumlu, ama anlık olaylar için de görsel "buruşma" verebilir.
  final double duration;

  const EventEffect({
    this.fx = EventFx.none,
    this.screenTint,
    this.rainBoost = 0.0,
    this.npcSpeedMul = 1.0,
    this.farmGrowthMul = 1.0,
    this.builderMul = 1.0,
    this.duration = 0.0,
  });
}

/// Olay önemi — HUD/notif görünürlüğünü ayarlamak için (şimdilik flag).
enum EventSeverity { minor, major }

/// Bir olay tetiklendiğinde sahnenin görmesi gereken durum.
/// `EventSystem.roll` koşullu filtrelemede kullanır.
class EventContext {
  final int population;
  final ResourceBundle stockpile;
  final List<BuildingEntity> buildings;

  const EventContext({
    required this.population,
    required this.stockpile,
    required this.buildings,
  });
}

/// Karar gerektiren olaylarda oyuncuya sunulan seçenek. Seçilince delta'lar
/// stoğa uygulanır, varsa moral ve sahne efekti aktive edilir.
class EventChoice {
  /// Kalıcı kimlik — sahne tepkisi (kova zinciri / kovalama / kaçış) buna bakar.
  /// Buton metni değişince davranış bozulmasın diye label'a ASLA switch'lenmez.
  final String id;

  final String label; // buton metni (örn. "Yakala")
  final String detail; // alt açıklama (örn. "15 altına muhafız tutarsın")

  /// Vakanüvis satırı — kuru, kısa; kararın yıllığa düşen izi.
  final String annal;

  final int foodDelta;
  final int goldDelta;
  final int woodDelta;
  final int stoneDelta;
  final int ironDelta;
  final int coalDelta;
  final double moraleModifier;
  final double duration;
  final EventEffect? effect;

  /// true ise negatif kaynak deltaları olay kaybı değil oyuncunun ödediği
  /// müdahale bedelidir; stok yetmiyorsa seçenek seçilemez.
  final bool requiresResources;

  /// Bu seçenek için kısa "sonuç" mesajı — banner'da gösterilir.
  final String resolutionMessage;
  final GovernanceAftermathSpec? aftermath;

  const EventChoice({
    required this.id,
    required this.label,
    required this.detail,
    required this.resolutionMessage,
    this.annal = '',
    this.foodDelta = 0,
    this.goldDelta = 0,
    this.woodDelta = 0,
    this.stoneDelta = 0,
    this.ironDelta = 0,
    this.coalDelta = 0,
    this.moraleModifier = 0,
    this.duration = 0,
    this.effect,
    this.requiresResources = false,
    this.aftermath,
  });

  bool canAfford(ResourceBundle stock) =>
      !requiresResources ||
      (stock.food >= -foodDelta &&
          stock.gold >= -goldDelta &&
          stock.wood >= -woodDelta &&
          stock.stone >= -stoneDelta &&
          stock.iron >= -ironDelta &&
          stock.coal >= -coalDelta);

  /// UI önizlemesi için kompakt etki listesi (banner deltaSummary ile aynı şema).
  List<(String, String)> deltaSummary() {
    final r = <(String, String)>[];
    if (foodDelta != 0) r.add(('🍞', EventOutcome._fmt(foodDelta)));
    if (goldDelta != 0) r.add(('🪙', EventOutcome._fmt(goldDelta)));
    if (woodDelta != 0) r.add(('🪵', EventOutcome._fmt(woodDelta)));
    if (stoneDelta != 0) r.add(('🪨', EventOutcome._fmt(stoneDelta)));
    if (ironDelta != 0) r.add(('⚙', EventOutcome._fmt(ironDelta)));
    if (coalDelta != 0) r.add(('⬛', EventOutcome._fmt(coalDelta)));
    if (moraleModifier != 0) {
      final m = moraleModifier > 0
          ? '+${(moraleModifier * 100).round()}%'
          : '${(moraleModifier * 100).round()}%';
      r.add(('😊', '$m·${duration.round()}sn'));
    }
    return r;
  }
}

/// Bir rastgele köy olayının sonucu. Anlık delta'lar hemen stoğa uygulanır;
/// [moraleModifier] varsa [duration] saniye boyunca köy moraline eklenir.
class EventOutcome {
  /// Kalıcı kimlik ([EventIds]). Omen metni, sahnelenmiş tepki, odak noktası ve
  /// tetiklenme koşulu hep buna bakar — başlığa DEĞİL. Başlık yeniden yazılınca
  /// hiçbir bağ kopmaz.
  final String id;

  final String title;
  final String icon;

  /// Olayın anlatısı — tek metin değil HAVUZ. Aynı olay ikinci kez geldiğinde
  /// başka kelimelerle okunur; varyant sabit tohumla seçilir ([messageFor]).
  final List<String> messagePool;

  /// Vakanüvis havuzu — kuru, kısa yıllık satırı ("Kuyu dibini gösterdi.").
  final List<String> annalPool;

  /// Havuz verilmeyen (senaryo/çözüm gibi tek-metinlik) olaylarda kullanılan
  /// düz metin. Havuz doluysa yok sayılır.
  final String _single;

  final EventCategory category;
  final EventSeverity severity;

  // Anlık kaynak değişimleri (sıfırsa o kaynağa dokunulmaz).
  final int foodDelta;
  final int goldDelta;
  final int woodDelta;
  final int stoneDelta;
  final int ironDelta;
  final int coalDelta;

  // Geçici moral etkisi.
  final double moraleModifier;
  final double duration;

  /// Bu olayın o anki köy durumunda tetiklenebilir olup olmadığı.
  /// null = her zaman uygun.
  final bool Function(EventContext)? canFire;

  /// Rölatif ağırlık — `roll` sırasında uygun olaylar arası seçim.
  final double weight;

  /// Sahne animasyonu + simülasyon etkileri. Null = sadece kaynak/moral
  /// değişimi (görsel etki yok).
  final EventEffect? effect;

  /// Karar gerektiren olaylarda oyuncu seçenekleri. Null = otomatik olay
  /// (mevcut akış, delta'lar direkt uygulanır). Doluysa olay KUYRUĞA girer:
  /// HUD'a karar mührü iner, sim akmaya devam eder, mühlet dolarsa köy
  /// [timeoutChoice]'u kendi yaşar (kapıda kuyruk — oyun donmaz).
  final List<EventChoice>? choices;

  const EventOutcome({
    this.id = '',
    required this.title,
    required this.icon,
    String message = '',
    this.messagePool = const <String>[],
    this.annalPool = const <String>[],
    required this.category,
    this.severity = EventSeverity.minor,
    this.foodDelta = 0,
    this.goldDelta = 0,
    this.woodDelta = 0,
    this.stoneDelta = 0,
    this.ironDelta = 0,
    this.coalDelta = 0,
    this.moraleModifier = 0,
    this.duration = 0,
    this.canFire,
    this.weight = 1.0,
    this.effect,
    this.choices,
  }) : _single = message;

  /// Gösterilecek metin. Havuzdan varyant seçilmemişse ilki (UI'ın doğrudan
  /// `.message` okuduğu yerler için güvenli varsayılan).
  String get message => messagePool.isEmpty ? _single : messagePool.first;

  /// Varyantı SABİT tohumla seçer (gün gibi) — her karede yeni Random yok,
  /// kayıt/yükleme sonrası cümle değişmez.
  String messageFor(int seed) =>
      messagePool.isEmpty ? _single : Voice.pick(messagePool, seed);

  /// Vakanüvis satırı — havuzdan sabit tohumla. Havuz boşsa başlığa düşer.
  String annalFor(int seed) =>
      annalPool.isEmpty ? title : Voice.pick(annalPool, seed);

  /// Seçilen varyantı taşıyan kopya — banner/modal ile bildirim aynı cümleyi
  /// göstersin diye olay vurduğu anda materyalize edilir.
  EventOutcome withMessage(String m) => EventOutcome(
    id: id,
    title: title,
    icon: icon,
    message: m,
    annalPool: annalPool,
    category: category,
    severity: severity,
    foodDelta: foodDelta,
    goldDelta: goldDelta,
    woodDelta: woodDelta,
    stoneDelta: stoneDelta,
    ironDelta: ironDelta,
    coalDelta: coalDelta,
    moraleModifier: moraleModifier,
    duration: duration,
    canFire: canFire,
    weight: weight,
    effect: effect,
    choices: choices,
  );

  bool get isTemporary => duration > 0 && moraleModifier != 0;

  /// UI banner'ı için kompakt etki listesi.
  /// Her giriş: ('🍞', '+28') gibi.
  List<(String, String)> deltaSummary() {
    final r = <(String, String)>[];
    if (foodDelta != 0) r.add(('🍞', _fmt(foodDelta)));
    if (goldDelta != 0) r.add(('🪙', _fmt(goldDelta)));
    if (woodDelta != 0) r.add(('🪵', _fmt(woodDelta)));
    if (stoneDelta != 0) r.add(('🪨', _fmt(stoneDelta)));
    if (ironDelta != 0) r.add(('⚙', _fmt(ironDelta)));
    if (coalDelta != 0) r.add(('⬛', _fmt(coalDelta)));
    if (moraleModifier != 0) {
      final m = moraleModifier > 0
          ? '+${(moraleModifier * 100).round()}%'
          : '${(moraleModifier * 100).round()}%';
      r.add(('😊', '$m·${duration.round()}sn'));
    }
    return r;
  }

  static String _fmt(int v) => v > 0 ? '+$v' : '$v';

  bool get needsChoice => choices != null && choices!.isNotEmpty;

  /// ZAMAN AŞIMI SÖZLEŞMESİ — karar mühleti dolarsa köy BUNU yaşar.
  ///
  /// Kural: pasif seçenek ("kendi haline bırak" kolu: endure/hide/letBurn)
  /// her karar olayında listenin SONUNDA durur. Oyuncu susarsa dünya kendi
  /// yoluna girer; müdahale (şifacı/muhafız/kova zinciri) asla kendiliğinden
  /// yaşanmaz — bedel ödeyen her karar oyuncunun ağzından çıkmak zorundadır.
  /// Yeni karar olayı eklerken bu sırayı KORU (petition_catalog_test kalıbı
  /// gibi event_timeout_test bunu bekçiler).
  EventChoice? get timeoutChoice => needsChoice ? choices!.last : null;
}

class EventSystem {
  /// İçerik paketleri [kEventCatalog] altında toplanır. Motor ile içerik ayrı
  /// kaldığı için yeni bir olay paketi seçim algoritmasına dokunmadan eklenir.
  static const events = kEventCatalog;

  /// Verilen bağlamda uygun olan olaylar arasından ağırlıklı rastgele seçim.
  /// Katalog boşsa olay üretmez.
  static EventOutcome? roll(Random rng, EventContext ctx) =>
      rollFrom(events, rng, ctx);

  /// Verilen bir katalogdan seçim yapar. Ayrı içerik paketleri ve testler aynı
  /// üretim algoritmasını kullanır; sahte bir ikinci seçici oluşmaz.
  static EventOutcome? rollFrom(
    Iterable<EventOutcome> catalog,
    Random rng,
    EventContext ctx,
  ) {
    final viable = <EventOutcome>[];
    final weights = <double>[];
    for (final e in catalog) {
      if (e.weight <= 0) continue;
      if (!_canFire(e, ctx)) continue;
      viable.add(e);
      weights.add(e.weight);
    }
    if (viable.isEmpty) return null;
    return _weightedPick(rng, viable, weights);
  }

  /// Koşulu olmayan olay her zaman uygundur; koşullu olay kendi kapısını
  /// taşır. Bu kapıyı id switch'ine çevirmek içerik ile motoru yeniden bağlar.
  static bool _canFire(EventOutcome e, EventContext ctx) =>
      e.canFire?.call(ctx) ?? true;

  static EventOutcome _weightedPick(
    Random rng,
    List<EventOutcome> viable,
    List<double> weights,
  ) {
    var total = 0.0;
    for (final w in weights) {
      total += w;
    }
    var pick = rng.nextDouble() * total;
    for (int i = 0; i < viable.length; i++) {
      pick -= weights[i];
      if (pick <= 0) return viable[i];
    }
    return viable.last;
  }
}
