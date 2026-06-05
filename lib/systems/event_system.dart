import 'dart:math';
import 'package:flutter/material.dart';
import '../buildings/building_entity.dart';
import '../buildings/building_type.dart';
import '../core/resources.dart';

/// Olay kategorisi — UI banner rengi ve filtre için.
enum EventCategory { positive, negative, neutral }

/// Sahne efekt kimliği — renderer'ın hangi animasyonu çizeceğini belirler.
/// Her id painter içinde özel partikül/overlay pass'e karşılık gelir.
enum EventFx {
  none,
  celebration,    // ateş çevresinde kalp/nota partikülleri
  plagueAura,     // NPC'lerin üstünde yeşil hastalık ikonu
  harvestSparkle, // tarla/ambar üstünde altın yıldız parıltı
  fireOutbreak,   // rastgele bina üstünde alev + yoğun duman
  storm,          // yağmur boost + ekran maviye kayar
  droughtHaze,    // ekran sarımsı, hava sıcak hissi
  treasureGlow,   // köy meydanına altın parlama
  miracleLight,   // gökten ışın hüzmesi
  thiefDash,      // ekran kenarından koşan koyu silüet
  beastEyes,      // gece ateş etrafında çift kırmızı göz
  visitorArrived, // dışarıdan giren NPC silueti
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

  bool hasBuilding(BuildingType t) =>
      buildings.any((b) => b.type == t);

  int countBuilding(BuildingType t) =>
      buildings.where((b) => b.type == t).length;
}

/// Karar gerektiren olaylarda oyuncuya sunulan seçenek. Seçilince delta'lar
/// stoğa uygulanır, varsa moral ve sahne efekti aktive edilir.
class EventChoice {
  final String label;   // buton metni (örn. "Yakala")
  final String detail;  // alt açıklama (örn. "15 altına muhafız tutarsın")

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
    required this.label,
    required this.detail,
    required this.resolutionMessage,
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
  final String title;
  final String icon;
  final String message;

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
    required this.title,
    required this.icon,
    required this.message,
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
  });

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
  /// 15+ olay — pozitif ve negatif dengeli, koşullu tetiklenme ile.
  static const events = <EventOutcome>[
    // ─── POZİTİF ────────────────────────────────────────────────────────────
    EventOutcome(
      title: 'Bereketli Hasat', icon: '🌾',
      message: 'Tarlalar dolup taştı — ambarlara bol yiyecek geldi.',
      category: EventCategory.positive,
      foodDelta: 28, weight: 1.0,
      effect: EventEffect(
        fx: EventFx.harvestSparkle,
        farmGrowthMul: 1.5,
        duration: 20,
      ),
    ),
    EventOutcome(
      title: 'Gezgin Tüccar', icon: '🪙',
      message: 'Yabancı bir tüccar köye uğradı. Pazarlık başlayabilir.',
      category: EventCategory.positive,
      weight: 1.0,
      effect: EventEffect(fx: EventFx.visitorArrived, duration: 18),
      choices: [
        EventChoice(
          label: 'Mal sat',
          detail: 'Ahşap stoğundan 10 birim ver, karşılığında bol altın al.',
          resolutionMessage: 'Tüccarla anlaştın — yüklü ahşap, dolu kese.',
          woodDelta: -10, goldDelta: 38,
        ),
        EventChoice(
          label: 'Sadece selamla',
          detail: 'Bir küçük hediye yeter; tüccar gönülden ayrılır.',
          resolutionMessage: 'Tüccar hediyeni alıp yola devam etti.',
          goldDelta: 8,
        ),
        EventChoice(
          label: 'Geri çevir',
          detail: 'Köy şu an alışveriş ortamında değil.',
          resolutionMessage: 'Tüccar surat asıp gitti.',
          moraleModifier: -0.05, duration: 15,
        ),
      ],
    ),
    EventOutcome(
      title: 'Şenlik', icon: '🎉',
      message: 'Meydanda şenlik kuruldu, herkes moral buldu.',
      category: EventCategory.positive,
      moraleModifier: 0.20, duration: 45,
      weight: 1.0,
      effect: EventEffect(
        fx: EventFx.celebration,
        npcSpeedMul: 1.15,
        duration: 45,
      ),
    ),
    EventOutcome(
      title: 'Balık Sürüsü', icon: '🐟',
      message: 'Göle büyük bir balık sürüsü geldi — ağlar doldu.',
      category: EventCategory.positive,
      foodDelta: 22, weight: 0.9,
      effect: EventEffect(fx: EventFx.harvestSparkle, duration: 14),
    ),
    EventOutcome(
      title: 'Mucize', icon: '✨',
      message: 'Kıtlığın ortasında köye gizemli bir yardım ulaştı.',
      category: EventCategory.positive,
      severity: EventSeverity.major,
      foodDelta: 18, moraleModifier: 0.15, duration: 30,
      weight: 0.6,
      effect: EventEffect(
        fx: EventFx.miracleLight,
        screenTint: Color(0x22FFE8B0),
        duration: 12,
      ),
    ),
    EventOutcome(
      title: 'Eski Hazine', icon: '💎',
      message: 'Köylüler tarlada toprağa gömülü altın küpü buldu!',
      category: EventCategory.positive,
      severity: EventSeverity.major,
      goldDelta: 55, weight: 0.5,
      effect: EventEffect(fx: EventFx.treasureGlow, duration: 14),
    ),
    EventOutcome(
      title: 'Gezgin Şifacı', icon: '🌿',
      message: 'Otacı bir kadın köye uğradı — yardım istiyor.',
      category: EventCategory.positive,
      weight: 0.8,
      effect: EventEffect(fx: EventFx.visitorArrived, duration: 20),
      choices: [
        EventChoice(
          label: 'Misafir et',
          detail: '8 yiyecek harca, şifacı köyde kalsın; huzur uzun sürer.',
          resolutionMessage: 'Şifacı sofrana oturdu — köy ruhu rahatladı.',
          foodDelta: -8, moraleModifier: 0.22, duration: 45,
        ),
        EventChoice(
          label: 'Yolu üzerinde uğurla',
          detail: 'Küçük yardım, kısa moral artışı.',
          resolutionMessage: 'Şifacı duayla yola devam etti.',
          moraleModifier: 0.08, duration: 18,
        ),
      ],
    ),
    EventOutcome(
      title: 'Cömert Yolcu', icon: '🧳',
      message: 'Yolu düşen bir yolcu, yardımları için köye altın bıraktı.',
      category: EventCategory.positive,
      goldDelta: 12, moraleModifier: 0.08, duration: 18,
      weight: 0.9,
      effect: EventEffect(fx: EventFx.visitorArrived, duration: 16),
    ),
    EventOutcome(
      title: 'Yaz Yağmuru', icon: '🌦',
      message: 'Bereketli bir yağmur tarlalara can verdi.',
      category: EventCategory.positive,
      foodDelta: 10, moraleModifier: 0.10, duration: 25,
      weight: 0.9,
      effect: EventEffect(
        fx: EventFx.none,
        rainBoost: 0.5,
        farmGrowthMul: 1.3,
        duration: 25,
      ),
    ),

    // ─── NEGATİF ────────────────────────────────────────────────────────────
    EventOutcome(
      title: 'Kuraklık', icon: '☀',
      message: 'Kuraklık bastı — ekinler soldu, moral düştü.',
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
      title: 'Salgın', icon: '🤒',
      message: 'Köyde bir salgın çıktı. Müdahale etmezsen uzun sürer.',
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
          label: 'Şifacı çağır',
          detail: '20 altın harca; salgın hızla kontrol altına alınır.',
          resolutionMessage: 'Şifacı çağrıldı — salgın yavaşladı.',
          goldDelta: -20, moraleModifier: -0.10, duration: 20,
          effect: EventEffect(
            fx: EventFx.plagueAura,
            screenTint: Color(0x18507040),
            npcSpeedMul: 0.92,
            duration: 20,
          ),
        ),
        EventChoice(
          label: 'Kendi başına atlat',
          detail: 'Müdahale yok — etki tam ve uzun sürer.',
          resolutionMessage: 'Köy kendi başına savaştı, bedeli ağır oldu.',
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
      title: 'Hayvan Baskını', icon: '🐺',
      message: 'Kurtlar köyün kenarına dadandı. Hareket gerekiyor!',
      category: EventCategory.negative,
      weight: 0.9,
      effect: EventEffect(fx: EventFx.beastEyes, duration: 25),
      choices: [
        EventChoice(
          label: 'Muhafızları gönder',
          detail: '5 yiyecek harca; kurtlar geri püskürtülür, az kayıp.',
          resolutionMessage: 'Muhafızlar sürüleri korudu, kurtlar geri çekildi.',
          foodDelta: -5,
        ),
        EventChoice(
          label: 'Saklan',
          detail: 'Hayvan kayıpları tam: yiyecek -18, moral -10%.',
          resolutionMessage: 'Korkudan saklandın, ahırı kaybettin.',
          foodDelta: -18, moraleModifier: -0.10, duration: 25,
        ),
      ],
    ),
    EventOutcome(
      title: 'Hırsız', icon: '🦹',
      message: 'Pazardan altın kapan bir hırsız kaçıyor!',
      category: EventCategory.negative,
      weight: 0.8,
      effect: EventEffect(fx: EventFx.thiefDash, duration: 8),
      choices: [
        EventChoice(
          label: 'Peşine düş',
          detail: '15 altın muhafız ücreti; kayıp önlenir.',
          resolutionMessage: 'Hırsız yakalandı — para muhafıza, altın köyde.',
          goldDelta: -15,
        ),
        EventChoice(
          label: 'Bırak gitsin',
          detail: 'Kovalamak risk — altın 22 birim eksilir.',
          resolutionMessage: 'Hırsız sokaklarda kayboldu, altın gitti.',
          goldDelta: -22,
        ),
      ],
    ),
    EventOutcome(
      title: 'Fırtına', icon: '⛈',
      message: 'Şiddetli fırtına çatıları söktü, ahşap kayboldu.',
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
      title: 'Ev Yangını', icon: '🔥',
      message: 'Bir kulübede yangın çıktı! Kararını çabuk ver.',
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
          label: 'Söndürme ekibi',
          detail: '10 odun + 4 yiyecek bedeli; hasarın yarısı atlatılır.',
          resolutionMessage: 'Köylüler kovaları kaptı, alevler durduruldu.',
          woodDelta: -10, foodDelta: -4, moraleModifier: -0.05, duration: 18,
        ),
        EventChoice(
          label: 'Yansın',
          detail: 'Müdahale yok; odun -28, moral -15%.',
          resolutionMessage: 'Kulübe küle döndü, köy bir akşam üzüldü.',
          woodDelta: -28, moraleModifier: -0.15, duration: 30,
        ),
      ],
    ),

    // ─── NÖTR ───────────────────────────────────────────────────────────────
    EventOutcome(
      title: 'Yolcu Geçti', icon: '🚶',
      message: 'Yolu düşen biri kısa bir mola verdi, gitti.',
      category: EventCategory.neutral,
      moraleModifier: 0.05, duration: 15,
      weight: 0.7,
      effect: EventEffect(fx: EventFx.visitorArrived, duration: 12),
    ),
  ];

  /// Verilen bağlamda uygun olan olaylar arasından ağırlıklı rastgele seçim.
  /// Koşullar:
  /// - Balık sürüsü → balıkçı kulübesi gerekir
  /// - Mucize → yiyecek stoğu kıtlığa yaklaşmış olmalı (< 12)
  /// - Eski hazine → en az 8 köylü
  /// - Salgın → en az 6 köylü
  /// - Yangın → en az 5 köylü ve odun stoğu ≥ 28
  /// - Hırsız → mevcut altın ≥ 22 veya pazar var
  /// - Yaz yağmuru → en az 1 tarla (farm tile zorunlu değil; basitleştirme:
  ///   en az 1 değirmen veya ahır → çiftçilik var sayılır). Şimdilik tek
  ///   koşul: nüfus ≥ 3.
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
          (e) => e.title == 'Kuraklık', orElse: () => events.first);
    }
    return _weightedPick(rng, viable, weights);
  }

  static bool _canFire(EventOutcome e, EventContext ctx) {
    switch (e.title) {
      case 'Balık Sürüsü':
        return ctx.hasBuilding(BuildingType.fisherCabin);
      case 'Mucize':
        return ctx.stockpile.food < 12;
      case 'Eski Hazine':
        return ctx.population >= 8;
      case 'Salgın':
        return ctx.population >= 6;
      case 'Ev Yangını':
        return ctx.population >= 5 && ctx.stockpile.wood >= 28;
      case 'Hırsız':
        return ctx.stockpile.gold >= 22 ||
               ctx.hasBuilding(BuildingType.market);
      case 'Yaz Yağmuru':
        return ctx.population >= 3;
      case 'Gezgin Tüccar':
        return ctx.hasBuilding(BuildingType.market);
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
