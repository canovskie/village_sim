import 'dart:math';
import 'package:flutter/material.dart';
import '../buildings/building_entity.dart';
import '../core/resources.dart';
import '../text/voice.dart';

/// Olayların KALICI kimlikleri. Kod bir olayı BUNLARLA tanır — asla başlıkla.
/// Başlık oyuncunun gördüğü metindir ve serbestçe yeniden yazılabilir; id ise
/// omen/sahne/senaryo bağlarının tutunduğu çividir.
abstract final class EventIds {
  static const drought   = 'drought';
  static const plague    = 'plague';
  static const beastRaid = 'beastRaid';
  static const storm     = 'storm';
  static const houseFire = 'houseFire';
  static const bard      = 'bard';
  static const caravan   = 'caravan';
  static const bounty    = 'bounty';
  static const accord    = 'accord';
}

/// Olay kategorisi — UI banner rengi ve filtre için.
enum EventCategory { positive, negative, neutral }

/// Sahne efekt kimliği — renderer'ın hangi animasyonu çizeceğini belirler.
/// Her id painter içinde özel partikül/overlay pass'e karşılık gelir.
enum EventFx {
  none,
  festival,       // BESPOKE şenlik: flama/çelenk + konfeti yağmuru + yükselen fener
  cropBlight,     // BESPOKE: tarlalarda yayılan mantar lekesi + şapka + spor
  vigil,          // BESPOKE: ateş çevresinde mum halkası + yükselen ruh kıvılcımı (matem)
  cultRite,       // BESPOKE: parlayan ayin çemberi + dönen rünler + okült ışıltı
  meteorShower,   // BESPOKE: gece gökten süzülen kayan yıldızlar + köye düşen göktaşı flaşı
  wedding,        // BESPOKE: ateş başında dans eden çift + yükselen kalpler + yaprak/konfeti yağmuru
  harvestBounty,  // BESPOKE: tarlalarda altın ışıltı + olgunlaşan başak + yukarı süzülen bereket zerresi
  plagueAura,     // hastalıklı yeşil ekran tonu + yavaşlama (görsel: sick duruşu)
  fireOutbreak,   // rastgele bina üstünde alev + yoğun duman
  storm,          // yağmur boost + ekran maviye kayar
  droughtHaze,    // ekran sarımsı, hava sıcak hissi
  beastEyes,      // gece ateş etrafında çift kırmızı göz
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
  final int  population;
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

  final String label;   // buton metni (örn. "Yakala")
  final String detail;  // alt açıklama (örn. "15 altına muhafız tutarsın")

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

  /// Bu seçenek için kısa "sonuç" mesajı — banner'da gösterilir.
  final String resolutionMessage;

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
  });

  /// UI önizlemesi için kompakt etki listesi (banner deltaSummary ile aynı şema).
  List<(String, String)> deltaSummary() {
    final r = <(String, String)>[];
    if (foodDelta  != 0) r.add(('🍞', EventOutcome._fmt(foodDelta)));
    if (goldDelta  != 0) r.add(('🪙', EventOutcome._fmt(goldDelta)));
    if (woodDelta  != 0) r.add(('🪵', EventOutcome._fmt(woodDelta)));
    if (stoneDelta != 0) r.add(('🪨', EventOutcome._fmt(stoneDelta)));
    if (ironDelta  != 0) r.add(('⚙', EventOutcome._fmt(ironDelta)));
    if (coalDelta  != 0) r.add(('⬛', EventOutcome._fmt(coalDelta)));
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
  /// (mevcut akış, delta'lar direkt uygulanır). Doluysa modal açılır,
  /// oyun yarıduraklatılır, oyuncu seçene kadar bekler.
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
    if (foodDelta  != 0) r.add(('🍞', _fmt(foodDelta)));
    if (goldDelta  != 0) r.add(('🪙', _fmt(goldDelta)));
    if (woodDelta  != 0) r.add(('🪵', _fmt(woodDelta)));
    if (stoneDelta != 0) r.add(('🪨', _fmt(stoneDelta)));
    if (ironDelta  != 0) r.add(('⚙', _fmt(ironDelta)));
    if (coalDelta  != 0) r.add(('⬛', _fmt(coalDelta)));
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
}

class EventSystem {
  /// Dramatik, animasyonlu olaylar — her birinin görünür bir dünya etkisi +
  /// bespoke fx'i var (kullanıcı kararı: "sadece hareketli şeyler"). Pozitif
  /// coşkuyu artık dilekçe/ambient sistemi taşır (şenlik, düğün, göktaşı).
  static const events = <EventOutcome>[
    // ─── NEGATİF (afet/tehdit — hepsi bespoke fx) ─────────────────────────────
    EventOutcome(
      id: EventIds.drought,
      title: 'Kuraklık', icon: '☀',
      messagePool: [
        'Kuyunun kovası bugün iki kez boş çıktı. Tarlada toprak ayak altında un gibi dağılıyor.',
        'Dere yatağı taş kesti. Başaklar öğle olmadan başını eğiyor.',
        'Sıcak sabahtan beri kımıldamıyor. Ekinin kökü kuru toprağı çoktan bıraktı.',
      ],
      annalPool: [
        'Gün {gün}. Kuyu dibini gösterdi. Tarla kavruldu.',
        'Gün {gün}. Yağmur yağmadı. Ekin ayakta kurudu.',
        'Gün {gün}. {mevsim} kurak geçti. Ambar eksik doldu.',
      ],
      category: EventCategory.negative,
      foodDelta: -15, moraleModifier: -0.20, duration: 45,
      weight: 1.0,
      effect: EventEffect(
        fx: EventFx.droughtHaze,
        screenTint: Color(0x26FFB04A),
        farmGrowthMul: 0.4,
        duration: 45,
      ),
    ),
    EventOutcome(
      id: EventIds.plague,
      title: 'Salgın', icon: '🤒',
      messagePool: [
        'İki hane kapısını içeriden sürgüledi. Geceleri öksürük sesi geliyor.',
        'Ateşi çıkan üç köylü yatağa düştü. Hastalık ocaktan ocağa atlıyor.',
        'Pazarda kimse kimseye yaklaşmıyor. Hastalık {köy} sınırından çoktan girdi.',
      ],
      annalPool: [
        'Gün {gün}. Hastalık girdi. Kapılar sürgülendi.',
        'Gün {gün}. Ateş üç haneye düştü. Pazar boşaldı.',
        'Gün {gün}. Salgın başladı. {mevsim} uzun sürecek.',
      ],
      category: EventCategory.negative,
      severity: EventSeverity.major,
      weight: 0.7,
      effect: EventEffect(
        fx: EventFx.plagueAura,
        screenTint: Color(0x22507040),
        npcSpeedMul: 0.85,
        duration: 25,
      ),
      choices: [
        EventChoice(
          id: 'healer',
          label: 'Şifacı çağır',
          detail: '20 altın. Kasabadan şifacı gelir, hastalık erken kırılır.',
          resolutionMessage:
              'Şifacı kapı kapı dolaştı, kaynattığı otu her ocağa bıraktı. Öksürük seyrekleşti.',
          annal: 'Şifacı çağrıldı. Hastalık erken kırıldı.',
          goldDelta: -20, moraleModifier: -0.10, duration: 20,
          effect: EventEffect(
            fx: EventFx.plagueAura,
            screenTint: Color(0x18507040),
            npcSpeedMul: 0.92,
            duration: 20,
          ),
        ),
        EventChoice(
          id: 'endure',
          label: 'Kendi başına atlat',
          detail: 'Kimse çağrılmaz. Hastalık tam gücüyle ve uzun sürer.',
          resolutionMessage:
              'Köy hastalığı kendi yatağında bekledi. Bedelini de o yatakta ödedi.',
          annal: 'Şifacı çağrılmadı. Köy hastalığı yatarak bekledi.',
          moraleModifier: -0.25, duration: 50,
          effect: EventEffect(
            fx: EventFx.plagueAura,
            screenTint: Color(0x22507040),
            npcSpeedMul: 0.7,
            duration: 50,
          ),
        ),
      ],
    ),
    EventOutcome(
      id: EventIds.beastRaid,
      title: 'Kurtlar', icon: '🐺',
      messagePool: [
        'Ağılın çiti gece yarısı yıkıldı. Geriye kan ve dört ayak izi kaldı.',
        'Sürü bu sabah eksik döndü. Ağaç hattında kırık dallar, taze iz var.',
        'Koyunlar tek yığın halinde sıkıştı, hiçbiri otlamıyor. Kurt kokusu almışlar.',
      ],
      annalPool: [
        'Gün {gün}. Kurtlar ağıla indi. Çit yıkıldı.',
        'Gün {gün}. Sürü eksik döndü. Ağaç hattı beklendi.',
        'Gün {gün}. Ormandan kurt geldi. {köy} kapısını erken kapattı.',
      ],
      category: EventCategory.negative,
      weight: 0.9,
      effect: EventEffect(fx: EventFx.beastEyes, duration: 25),
      choices: [
        EventChoice(
          id: 'guards',
          label: 'Muhafızları gönder',
          detail: '5 yiyecek. Meşaleli adamlar ağaç hattına dayanır, sürü kurtulur.',
          resolutionMessage:
              'Meşaleler ağaç hattına dayandı. Uluma uzaklaştı, sürü ağılda kaldı.',
          annal: 'Muhafızlar gönderildi. Sürü kurtarıldı.',
          foodDelta: -5,
        ),
        EventChoice(
          id: 'hide',
          label: 'Kapıları sürgüle',
          detail: 'Kimse dışarı çıkmaz. Ağıl açıkta kalır: yiyecek -18, moral -10%.',
          resolutionMessage:
              'Kapılar sürgülendi, ağıl açıkta kaldı. Sabah sayım eksik çıktı.',
          annal: 'Kapılar sürgülendi. Ağıl kurda bırakıldı.',
          foodDelta: -18, moraleModifier: -0.10, duration: 25,
        ),
      ],
    ),
    EventOutcome(
      id: EventIds.storm,
      title: 'Fırtına', icon: '⛈',
      messagePool: [
        'Rüzgâr çatı kirişini söktü, tahtalar avluya savruldu.',
        'Kepenkler gece boyu çarptı. Sabah damların yarısı yerdeydi.',
        'Dolu taze sıvayı deldi. Yığılı kereste dereye gitti.',
      ],
      annalPool: [
        'Gün {gün}. Fırtına çatıları söktü.',
        'Gün {gün}. Rüzgâr kerestenin yarısını götürdü.',
        'Gün {gün}. {mevsim} fırtınası vurdu. İnşaat durdu.',
      ],
      category: EventCategory.negative,
      woodDelta: -16, moraleModifier: -0.10, duration: 20,
      weight: 0.9,
      effect: EventEffect(
        fx: EventFx.storm,
        screenTint: Color(0x33203040),
        rainBoost: 1.0,
        builderMul: 0.0,
        duration: 20,
      ),
    ),
    EventOutcome(
      id: EventIds.houseFire,
      title: 'Ev Yangını', icon: '🔥',
      messagePool: [
        'Bacadan sıçrayan kıvılcım samanı tutuşturdu. Alev şimdiden kirişte.',
        'Bir kulübenin kapısından duman fışkırıyor, içeriden çıtırtı geliyor.',
        'Ocaktan kaçan köz kuru çatıyı yakaladı. Rüzgâr da körüklüyor.',
      ],
      annalPool: [
        'Gün {gün}. Bir kulübe tutuştu.',
        'Gün {gün}. Yangın çıktı. Duman meydandan görüldü.',
        'Gün {gün}. Ateş çatıya vurdu. {köy} uyanık geceledi.',
      ],
      category: EventCategory.negative,
      severity: EventSeverity.major,
      weight: 0.5,
      effect: EventEffect(
        fx: EventFx.fireOutbreak,
        screenTint: Color(0x18FF6020),
        duration: 14,
      ),
      choices: [
        EventChoice(
          id: 'extinguish',
          label: 'Kova zinciri kur',
          detail: '10 odun, 4 yiyecek. Kuyudan çatıya el ele su taşınır.',
          resolutionMessage:
              'Kova zinciri kuyudan çatıya uzandı. Kirişler tuttu, ev ayakta kaldı.',
          annal: 'Kova zinciri kuruldu. Ev kurtarıldı.',
          woodDelta: -10, foodDelta: -4, moraleModifier: -0.05, duration: 18,
        ),
        EventChoice(
          id: 'letBurn',
          label: 'Yansın',
          detail: 'Kimse müdahale etmez. Odun -28, moral -15%.',
          resolutionMessage:
              'Kulübe sabaha kül oldu. Köylüler tek kelime etmeden dağıldı.',
          annal: 'Yangına girilmedi. Kulübe kül oldu.',
          woodDelta: -28, moraleModifier: -0.15, duration: 30,
        ),
      ],
    ),

    // ─── POZİTİF / SÜRPRİZ (köye gelen iyilik — hepsi sahnelenir) ──────────────
    // "Hepsi negatif" hissini kırar: köye bazen iyi şeyler de uğrar. Hepsi omen
    // (sevinçli bekleyiş) + dünya-içi sahne (toplanma/müzik/dans/şölen) yaşar.
    EventOutcome(
      id: EventIds.bard,
      title: 'Gezgin Ozan', icon: '🎵',
      messagePool: [
        'Yoldan sazlı bir adam geldi, ateşin başına oturdu. Çemberi ilk kuran çocuklar oldu.',
        'Ozan ilk türküye başlayınca kimse işine dönmedi. Akşam uzadıkça uzadı.',
        'Bir kopuz sesi meydanı doldurdu. {köy} bu gece geç yattı.',
      ],
      annalPool: [
        'Gün {gün}. Bir ozan uğradı. Meydanda türkü söylendi.',
        'Gün {gün}. Ozan geldi, iki gece kaldı.',
        'Gün {gün}. Ateş başında saz çalındı.',
      ],
      category: EventCategory.positive,
      moraleModifier: 0.12, duration: 40,
      weight: 0.9,
    ),
    EventOutcome(
      id: EventIds.caravan,
      title: 'Kervan', icon: '🛒',
      messagePool: [
        'Kervan tepeyi aştı, katırlar yüklü. Pazara tuz, kumaş, bir de bal kokusu indi.',
        'Tüccar denkleri açtı. Akşama kadar el kese değiştirdi.',
        'Yabancının terazisi doğru tarttı. Alışveriş {köy} lehine kapandı.',
      ],
      annalPool: [
        'Gün {gün}. Kervan geldi. Pazar bir gün açık kaldı.',
        'Gün {gün}. Tuz ve kumaş alındı, kese doldu.',
        'Gün {gün}. Tüccar uğradı. Ticaret {köy} lehine döndü.',
      ],
      category: EventCategory.positive,
      goldDelta: 10, foodDelta: 4, moraleModifier: 0.05, duration: 30,
      weight: 0.8,
    ),
    EventOutcome(
      id: EventIds.bounty,
      title: 'Bereketli Hasat', icon: '🌾',
      messagePool: [
        'Başak öyle ağır ki sap taşımıyor. Orak bugün iki kat iş gördü.',
        'Ambarın kapısı zor kapandı. Çuvallar duvara kadar dizili.',
        'Tarla altın rengine kesti. Toprak bu yıl {köy} halkına cömert davrandı.',
      ],
      annalPool: [
        'Gün {gün}. Hasat bereketli geçti. Ambar doldu.',
        'Gün {gün}. Başak ağır geldi. Çuval yetmedi.',
        'Gün {gün}. Toprak cömert davrandı.',
      ],
      category: EventCategory.positive,
      foodDelta: 18, moraleModifier: 0.08, duration: 30,
      weight: 0.7,
      effect: EventEffect(
        fx: EventFx.harvestBounty,
        farmGrowthMul: 1.5,
        duration: 30,
      ),
    ),
    EventOutcome(
      id: EventIds.accord,
      title: 'Hanelerin Barışı', icon: '🤝',
      messagePool: [
        'İki hane kuyu başında karşılaştı, kavga çıkmadı. Biri diğerine sıra verdi.',
        'Yıllardır selam vermeyen iki kapı bu akşam aynı ateşe oturdu.',
        'Küskün haneler ekmeği bölüştü. Meydan uzun zamandır bu kadar rahat değildi.',
      ],
      annalPool: [
        'Gün {gün}. Küskün haneler barıştı.',
        'Gün {gün}. İki hane aynı ateşe oturdu.',
        'Gün {gün}. {köy} dargınlığı bıraktı.',
      ],
      category: EventCategory.positive,
      moraleModifier: 0.10, duration: 40,
      weight: 0.6,
    ),
  ];

  /// Verilen bağlamda uygun olan olaylar arasından ağırlıklı rastgele seçim.
  /// Koşullar:
  /// - plague    → en az 6 köylü
  /// - houseFire → en az 5 köylü ve odun stoğu ≥ 28
  /// - thief     → mevcut altın ≥ 22 veya pazar var
  /// Diğerleri (drought, beastRaid, storm) koşulsuz uygundur.
  static EventOutcome roll(Random rng, EventContext ctx) {
    final viable = <EventOutcome>[];
    final weights = <double>[];
    for (final e in events) {
      if (!_canFire(e, ctx)) continue;
      viable.add(e);
      weights.add(e.weight);
    }
    if (viable.isEmpty) {
      // Güvenlik: en azından kuraklık daima uygun olsun
      return events.firstWhere(
          (e) => e.id == EventIds.drought, orElse: () => events.first);
    }
    return _weightedPick(rng, viable, weights);
  }

  /// Koşul kapıları KİMLİĞE bakar — başlık yeniden yazılınca olay sessizce
  /// koşulsuz hale gelmesin diye.
  static bool _canFire(EventOutcome e, EventContext ctx) {
    switch (e.id) {
      case EventIds.plague:
        return ctx.population >= 6;
      case EventIds.houseFire:
        return ctx.population >= 5 && ctx.stockpile.wood >= 28;
      // Pozitif olaylar — küçük köyde anlamsız olmasın diye nüfus kapısı.
      case EventIds.bard:
        return ctx.population >= 4;
      case EventIds.caravan:
        return ctx.population >= 5;
      case EventIds.accord:
        return ctx.population >= 6;
      default:
        return true;
    }
  }

  static EventOutcome _weightedPick(
      Random rng, List<EventOutcome> viable, List<double> weights) {
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
