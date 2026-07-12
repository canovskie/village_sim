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
  festival,       // BESPOKE şenlik: flama/çelenk + konfeti yağmuru + yükselen fener
  cropBlight,     // BESPOKE: tarlalarda yayılan mantar lekesi + şapka + spor
  vigil,          // BESPOKE: ateş çevresinde mum halkası + yükselen ruh kıvılcımı (matem)
  cultRite,       // BESPOKE: parlayan ayin çemberi + dönen rünler + okült ışıltı
  meteorShower,   // BESPOKE: gece gökten süzülen kayan yıldızlar + köye düşen göktaşı flaşı
  wedding,        // BESPOKE: ateş başında dans eden çift + yükselen kalpler + yaprak/konfeti yağmuru
  harvestBounty,  // BESPOKE: tarlalarda altın ışıltı + olgunlaşan başak + yukarı süzülen bereket zerresi
  plagueAura,     // NPC'lerin üstünde yeşil hastalık ikonu
  fireOutbreak,   // rastgele bina üstünde alev + yoğun duman
  storm,          // yağmur boost + ekran maviye kayar
  droughtHaze,    // ekran sarımsı, hava sıcak hissi
  thiefDash,      // ekran kenarından koşan koyu silüet
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
  /// Dramatik, animasyonlu olaylar — her birinin görünür bir dünya etkisi +
  /// bespoke fx'i var (kullanıcı kararı: "sadece hareketli şeyler"). Pozitif
  /// coşkuyu artık dilekçe/ambient sistemi taşır (şenlik, düğün, göktaşı).
  static const events = <EventOutcome>[
    // ─── NEGATİF (afet/tehdit — hepsi bespoke fx) ─────────────────────────────
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

    // ─── POZİTİF / SÜRPRİZ (köye gelen iyilik — hepsi sahnelenir) ──────────────
    // "Hepsi negatif" hissini kırar: köye bazen iyi şeyler de uğrar. Hepsi omen
    // (sevinçli bekleyiş) + dünya-içi sahne (toplanma/müzik/dans/şölen) yaşar.
    EventOutcome(
      title: 'Gezgin Ozan', icon: '🎵',
      message: 'Bir gezgin ozan köye uğradı — ezgileri herkesi neşelendirdi.',
      category: EventCategory.positive,
      moraleModifier: 0.12, duration: 40,
      weight: 0.9,
    ),
    EventOutcome(
      title: 'Gezgin Tüccar', icon: '🛒',
      message: 'Bir kervan pazara uğradı — bereketli bir alışveriş oldu.',
      category: EventCategory.positive,
      goldDelta: 10, foodDelta: 4, moraleModifier: 0.05, duration: 30,
      weight: 0.8,
    ),
    EventOutcome(
      title: 'Bereketli Hasat', icon: '🌾',
      message: 'Başaklar beklenmedik bir bollukla doldu — ambarlar şenlendi.',
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
      title: 'Zümre Barışı', icon: '🤝',
      message: 'Zümreler arasındaki gerginlik yumuşadı — köy bir nefes aldı.',
      category: EventCategory.positive,
      moraleModifier: 0.10, duration: 40,
      weight: 0.6,
    ),
  ];

  /// Verilen bağlamda uygun olan olaylar arasından ağırlıklı rastgele seçim.
  /// Koşullar:
  /// - Salgın → en az 6 köylü
  /// - Ev Yangını → en az 5 köylü ve odun stoğu ≥ 28
  /// - Hırsız → mevcut altın ≥ 22 veya pazar var
  /// Diğerleri (Kuraklık, Hayvan Baskını, Fırtına) koşulsuz uygundur.
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
      case 'Salgın':
        return ctx.population >= 6;
      case 'Ev Yangını':
        return ctx.population >= 5 && ctx.stockpile.wood >= 28;
      case 'Hırsız':
        return ctx.stockpile.gold >= 22 ||
               ctx.hasBuilding(BuildingType.market);
      // Pozitif olaylar — küçük köyde anlamsız olmasın diye nüfus kapısı.
      case 'Gezgin Ozan':
        return ctx.population >= 4;
      case 'Gezgin Tüccar':
        return ctx.population >= 5;
      case 'Zümre Barışı':
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
