import 'dart:math';
import 'estate_system.dart';

/// Dilekçeye bağlı görsel/anlık tepki — sahne bunu somut animasyona çevirir
/// (sadece istatistik değil: köy gözle görülür biçimde tepki verir).
enum PetitionFx {
  none,
  festival,    // BESPOKE: flama+konfeti+fener + köylüler ateşe toplanıp dans
  cropBlight,  // BESPOKE: tarlalarda yayılan mantar + ürün çürür (farm growth ↓)
  vigil,       // BESPOKE: bir köylü kaybı + mum töreni (köy toplanır, matem)
  mourn,       // bir köylü kaybı + sessiz uğurlama (animasyon yok, moral ↓↓)
  cult,        // BESPOKE: ayin çemberi + köylüler toplanır (yeni inanç)
  remembrance, // BESPOKE: anma günü — köy toplanır + mum töreni (KİMSE ölmez)
  wedding,     // BESPOKE: iki köylü evlenir — ateş başında dans + kalp/yaprak yağmuru
  harvestBounty, // BESPOKE: tarlalar altın ışıltıyla olgunlaşır + bereket zerresi yükselir
}

/// Dilekçenin duygu tonu — modal/mühür vurgu rengini ve havasını belirler.
/// UI bağlamı: oyuncu daha açmadan kararın ağırlığını sezsin (sıcak mı, kara mı).
enum PetitionTone {
  warm,    // kutlama/şefkat — sage/ember sıcaklığı
  solemn,  // hüzün/anma — soluk, ağırbaşlı
  ominous, // tehdit/kriz — rust, tedirgin
  neutral, // sıradan rica
}

/// Bir dilekçedeki tek seçenek: oyuncunun verebileceği karar + sonuçları.
/// Etkiler bildirimsel (declarative) — sahne `_resolvePetition` ile uygular:
/// kaynak deltaları, geçici moral (pushPolicyMorale), yasa yürürlüğe sokma,
/// şenlik efekti. Olay-seçim altyapısının yönetişim karşılığı.
class PetitionOption {
  /// Buton başlığı (ör. "Kabul et").
  final String label;
  /// Alt açıklama — kararın ne yapacağı.
  final String detail;
  /// Köye duyurulacak çözüm metni (notification).
  final String resolution;

  // Kaynak deltaları (negatif = harcama).
  final int foodDelta;
  final int woodDelta;
  final int stoneDelta;
  final int ironDelta;
  final int goldDelta;

  /// Geçici köy morali: [moraleAmount] (0..±1) [moraleDays] gün boyunca.
  final double moraleAmount;
  final double moraleDays;

  /// Anlık görsel efekt (şenlik vb.).
  final PetitionFx fx;

  /// Zincir: bu seçenek seçilince ileride tetiklenecek takip dilekçesi (id).
  /// null = zincir yok. Köyün "hafızası" — ret → ısrar, onay → takip.
  final String? followUpId;
  /// Takip dilekçesinin kaç oyun günü sonra geleceği.
  final double followUpDelayDays;

  /// Köy hafızasına yazılacak kalıcı bayraklar (ör. 'cult.active'). Sonraki
  /// dilekçeler bunları `canFire` ile okur → kararlar uzun vadede hatırlanır.
  final List<String> setsFlags;
  /// Köy hafızasından silinecek bayraklar (ör. bir yolu kapatınca).
  final List<String> clearsFlags;

  /// Bu kararın ZÜMRELER üstündeki morali etkisi — (zümre, ±delta) çiftleri.
  /// Pozitif = sevindirir (+ köyü o zümreye doğru kaydırır, nüfuz kazanır),
  /// negatif = gücendirir. Politik dengenin omurgası: çoğu seçenek birini
  /// sevindirip diğerini küstürür.
  final List<(Estate, double)> estateMood;

  const PetitionOption({
    required this.label,
    required this.detail,
    required this.resolution,
    this.foodDelta = 0,
    this.woodDelta = 0,
    this.stoneDelta = 0,
    this.ironDelta = 0,
    this.goldDelta = 0,
    this.moraleAmount = 0,
    this.moraleDays = 0,
    this.fx = PetitionFx.none,
    this.followUpId,
    this.followUpDelayDays = 1.5,
    this.setsFlags = const [],
    this.clearsFlags = const [],
    this.estateMood = const [],
  });

  /// UI etki chip'leri — (ikon, etiket) çiftleri.
  List<(String, String)> get effectChips {
    final out = <(String, String)>[];
    void res(String icon, int v) {
      if (v != 0) out.add((icon, '${v > 0 ? '+' : ''}$v'));
    }
    res('🌾', foodDelta);
    res('🪵', woodDelta);
    res('🪨', stoneDelta);
    res('⛏️', ironDelta);
    res('★', goldDelta);
    if (moraleAmount != 0) {
      final pct = (moraleAmount * 100).round();
      out.add(('😊', '${pct > 0 ? '+' : ''}$pct%'));
    }
    // Zümre etkisi — kim sevinir/küser (politik dengeyi göster).
    for (final (e, d) in estateMood) {
      if (d == 0) continue;
      out.add((e.icon, d > 0 ? '▲' : '▼'));
    }
    return out;
  }
}

/// Köyden gelen bir dilekçe — kim, ne istiyor, hangi seçenekler.
class Petition {
  final String id;
  /// Dilekçeyi sunan ("Köyün yaşlıları", "Çiftçiler", ...).
  final String petitioner;
  final String icon;
  final String title;
  /// Dilekçe gövde metni — talep, cozy tonda.
  final String body;
  /// Takip dilekçelerinde küçük bağlam rozeti (ör. "↩ Geçen sefer ertelemiştin").
  /// null = normal dilekçe.
  final String? note;
  /// Kararın özünü tek satırda özetleyen "ne pahasına" ipucu (UI'da gösterilir).
  /// null = gösterme.
  final String? stakes;
  /// Duygu tonu — modal/mühür vurgu rengi + havası.
  final PetitionTone tone;
  /// Bu dilekçeyi getiren ZÜMRE — sözcü o zümreden seçilir, sahneye o köylü
  /// yürür (diegetik). null = belirli bir zümre adına değil (genel köy).
  final Estate? estate;
  final List<PetitionOption> options;

  const Petition({
    required this.id,
    required this.petitioner,
    required this.icon,
    required this.title,
    required this.body,
    required this.options,
    this.note,
    this.stakes,
    this.tone = PetitionTone.neutral,
    this.estate,
  });
}

/// Dilekçe üretimi için köyün anlık durumu (koşul kapıları okur).
class PetitionContext {
  final int population;
  final int adults;
  final int food;
  final int gold;
  final double morale;
  /// Köyde tamamlanmış bir kilise var mı — anma dilekçelerini açar.
  final bool hasChurch;
  /// Köyün kalıcı hafızası — geçmiş kararların bıraktığı bayraklar. Dilekçeler
  /// bunu okuyup dallanır (ör. 'cult.active' varsa farklı dilekçeler açılır).
  final Set<String> memory;

  const PetitionContext({
    required this.population,
    required this.adults,
    required this.food,
    required this.gold,
    required this.morale,
    required this.hasChurch,
    this.memory = const {},
  });

  bool remembers(String flag) => memory.contains(flag);
}

/// İçsel tanım: bir dilekçe + ne zaman uygun olduğu + ağırlığı.
class _PetitionDef {
  final bool Function(PetitionContext) canFire;
  final double weight;
  final Petition petition;
  const _PetitionDef(this.canFire, this.weight, this.petition);
}

/// Dilekçe üretici — köyün durumuna göre ağırlıklı, koşula bağlı seçim.
/// Cozy ton: köy senden bir şey rica eder, sert değil sıcak.
abstract final class PetitionSystem {
  /// Uygun dilekçeleri toplar, ağırlıkla rastgele birini döner. Hiçbiri
  /// uygun değilse null (o turda dilekçe yok). [blocked] = yakında çözülmüş
  /// (cooldown'daki) dilekçe id'leri — tekrar random çıkmasınlar.
  static Petition? roll(PetitionContext ctx, Random rng,
      {Set<String> blocked = const {}}) {
    final eligible = _defs
        .where((d) => d.canFire(ctx) && !blocked.contains(d.petition.id))
        .toList(growable: false);
    if (eligible.isEmpty) return null;
    final total = eligible.fold<double>(0, (s, d) => s + d.weight);
    var pick = rng.nextDouble() * total;
    for (final d in eligible) {
      pick -= d.weight;
      if (pick <= 0) return d.petition;
    }
    return eligible.last.petition;
  }

  /// DEBUG: koşulları yok sayıp rastgele bir dilekçe döner (DevPanel testi).
  /// Takip-yalnızca dilekçeler (canFire=false) hariç tutulur.
  static Petition debugRandom(Random rng) {
    final rollable =
        _defs.where((d) => d.weight > 0).toList(growable: false);
    return rollable[rng.nextInt(rollable.length)].petition;
  }

  /// Id ile dilekçe bulur — takip dilekçeleri zincirle bu yolla tetiklenir.
  static Petition? byId(String id) {
    for (final d in _defs) {
      if (d.petition.id == id) return d.petition;
    }
    return null;
  }

  /// Tüm dilekçeler (takip dahil) — DevPanel seçici listesi için.
  static List<Petition> get all =>
      _defs.map((d) => d.petition).toList(growable: false);

  static final List<_PetitionDef> _defs = [
    // 🎉 Çiftçiler hasat şenliği ister.
    _PetitionDef(
      (c) => c.food >= 30,
      1.0,
      const Petition(
        id: 'harvestFestival',
        petitioner: 'Çiftçiler',
        icon: '🎉',
        title: 'Hasat Şenliği',
        tone: PetitionTone.warm,
        estate: Estate.laborers,
        stakes: 'Biraz altın → günlerce sürecek coşku.',
        body: 'Ambar dolu, yüzler gülüyor. Çiftçiler bir hasat şenliği '
            'düzenlemek istiyor — ateş, müzik, dans. Biraz altın harcanır '
            'ama köy bunu uzun süre konuşur.',
        options: [
          PetitionOption(
            label: 'Şenlik düzensin!',
            detail: 'Altın harca, köye günlerce sürecek bir coşku ver.',
            resolution: '🎉 Hasat şenliği başladı — köy bir bayram yaşıyor!',
            goldDelta: -6,
            moraleAmount: 0.12,
            moraleDays: 4,
            fx: PetitionFx.festival,
            followUpId: 'festivalAnnual',
            followUpDelayDays: 2.0,
            estateMood: [(Estate.laborers, 0.12), (Estate.hearth, 0.06)],
          ),
          PetitionOption(
            label: 'Belki sonra',
            detail: 'Şimdilik mütevazı kalalım — küçük bir hayal kırıklığı.',
            resolution: '🎉 Şenlik ertelendi.',
            moraleAmount: -0.02,
            moraleDays: 1,
            estateMood: [(Estate.laborers, -0.07)],
          ),
        ],
      ),
    ),

    // 🍄 Hasada mantar bulaştı (kriz — karar verirsin, animasyon ya gösterir
    // ya önler). Etki alanı: TARLA (şenlikten tamamen farklı).
    _PetitionDef(
      (c) => c.food >= 6,
      0.9,
      const Petition(
        id: 'cropBlight',
        petitioner: 'Telaşlı çiftçiler',
        icon: '🍄',
        title: 'Hasada Mantar Bulaştı',
        tone: PetitionTone.ominous,
        estate: Estate.laborers,
        stakes: 'Müdahale et → kurtar; bırak → hasadın çoğu çürür.',
        body: 'Çiftçiler soluk soluğa geldi: tarlalara bir mantar musallat '
            'olmuş, başaklar çürümeye başlamış. Hızlı davranmazsak hasadın '
            'çoğu gider.',
        options: [
          PetitionOption(
            label: 'İlaçla, temizle',
            detail: 'Biraz altın + emek harca; mantar yayılmadan durdurulur.',
            resolution: '🌾 Mantar temizlendi — hasat kurtarıldı.',
            goldDelta: -8,
            foodDelta: -3,
            moraleAmount: 0.02,
            moraleDays: 2,
            // İyi bakım hatırlanır → toprak ileride bereketle karşılık verir.
            setsFlags: ['fields.tended'],
            followUpId: 'bountifulHarvest',
            followUpDelayDays: 3.0,
            estateMood: [(Estate.laborers, 0.12), (Estate.artisans, -0.05)],
          ),
          PetitionOption(
            label: 'Bırak, doğa halletsin',
            detail: 'Müdahale yok — mantar tarlalara yayılır, ürün çürür.',
            resolution: '🍄 Mantar tarlalara yayıldı — hasadın çoğu çürüdü.',
            foodDelta: -14,
            moraleAmount: -0.05,
            moraleDays: 3,
            fx: PetitionFx.cropBlight,
            setsFlags: ['fields.neglected'],
            estateMood: [(Estate.laborers, -0.16)],
          ),
        ],
      ),
    ),

    // 🕯️ İntihar / kayıp — bir köylü kendini kaybetti. KARAR: nasıl yanıt
    // verilir (köylü her hâlükârda gider). Etki alanı: NÜFUS + moral.
    _PetitionDef(
      (c) => c.population >= 5,
      0.4,
      const Petition(
        id: 'lostSoul',
        petitioner: 'Acı bir haber',
        icon: '🕯️',
        title: 'Köy Yasta',
        tone: PetitionTone.solemn,
        estate: Estate.hearth,
        stakes: 'Köylü her hâlükârda gider — yas nasıl tutulacak?',
        body: 'Bu sabah köy ağır bir haberle uyandı: içlerinden biri umudunu '
            'yitirmiş, kendini bırakmış. Geride sessiz bir boşluk kaldı. Köy '
            'nasıl yas tutsun?',
        options: [
          PetitionOption(
            label: 'Anma töreni düzenle',
            detail: 'Köy ateş başında toplanır, mumlar yakılır — acı paylaşılır.',
            resolution: '', // dinamik mesaj reaksiyondan gelir (isimle)
            fx: PetitionFx.vigil,
            estateMood: [(Estate.hearth, 0.08), (Estate.faithful, 0.06)],
          ),
          PetitionOption(
            label: 'Sessizce uğurla',
            detail: 'Tören yok; herkes kendi köşesinde yas tutar — acı daha derin.',
            resolution: '',
            fx: PetitionFx.mourn,
            estateMood: [(Estate.hearth, -0.08), (Estate.faithful, -0.05)],
          ),
        ],
      ),
    ),

    // ⛪ Din uydurma — birkaç köylü yeni bir inanç kurdu. Etki alanı: SOSYAL.
    // Zincir başı: "Bırak" → cult.active hafızası + cultGrows takibi.
    // Bir kez karar verilince (active/suppressed) tekrar random çıkmaz.
    _PetitionDef(
      (c) => c.population >= 5 &&
          !c.remembers('cult.active') &&
          !c.remembers('cult.suppressed'),
      0.5,
      const Petition(
        id: 'newFaith',
        petitioner: 'Tuhaf fısıltılar',
        icon: '⛪',
        title: 'Yeni Bir İnanç',
        tone: PetitionTone.ominous,
        estate: Estate.faithful,
        stakes: 'İzin ver → inanç kök salıp büyür; engelle → dağılır.',
        body: 'Köyde birkaç kişi geceleri ateş başında toplanıp kendi '
            'uydurdukları bir inancın ayinlerini yapmaya başlamış — tuhaf '
            'rünler, ezgiler, dualar. Kimi meraklı, kimi tedirgin.',
        options: [
          PetitionOption(
            label: 'Bırak, inansınlar',
            detail: 'Ayin sürer; inananlar anlam bulur, köy biraz tuhaflaşır.',
            resolution: '⛪ Yeni inanç köyde kök saldı — geceleri ateş başında ayinler var.',
            fx: PetitionFx.cult,
            setsFlags: ['cult.active'],
            followUpId: 'cultGrows',
            followUpDelayDays: 3.0,
            estateMood: [(Estate.faithful, 0.14), (Estate.hearth, -0.08)],
          ),
          PetitionOption(
            label: 'Vazgeçir onları',
            detail: 'Nazikçe son verilir; hevesleri kırılır ama köy eskiye döner.',
            resolution: '⛪ İnanç dağıldı — köy sıradan akışına döndü.',
            moraleAmount: -0.03,
            moraleDays: 2,
            setsFlags: ['cult.suppressed'],
            estateMood: [(Estate.faithful, -0.14), (Estate.hearth, 0.06)],
          ),
        ],
      ),
    ),

    // ⛪ Anma Günü — kilise varsa cemaat göçenleri anmak ister. Etki: SOSYAL +
    // moral kapanışı. KİMSE ölmez (vigil'den farkı bu — sadece tören).
    _PetitionDef(
      (c) => c.hasChurch && c.population >= 4,
      0.6,
      const Petition(
        id: 'remembranceDay',
        petitioner: 'Kilise cemaati',
        icon: '⛪',
        title: 'Anma Günü',
        tone: PetitionTone.solemn,
        estate: Estate.faithful,
        body: 'Cemaat kilisede toplanıp göçüp gidenleri anmak istiyor — '
            'mumlar yakılacak, isimler okunacak, köy bir araya gelecek. '
            'Hüzünlü ama gönülleri iyileştiren bir gün.',
        options: [
          PetitionOption(
            label: 'Anma günü düzenle',
            detail: 'Köy kilisede toplanır, sevdiklerini onurla anar — içler ferahlar.',
            resolution: '⛪ Anma günü düzenlendi — köy sevdiklerini andı, gönüller ısındı.',
            moraleAmount: 0.06,
            moraleDays: 4,
            fx: PetitionFx.remembrance,
            estateMood: [(Estate.faithful, 0.10), (Estate.hearth, 0.05)],
          ),
          PetitionOption(
            label: 'Bugün değil',
            detail: 'Köy işine döner; anma ertelenir, hafif bir burukluk kalır.',
            resolution: '⛪ Anma günü ertelendi.',
            moraleAmount: -0.02,
            moraleDays: 2,
            estateMood: [(Estate.faithful, -0.08)],
          ),
        ],
      ),
    ),

    // 💍 Köy düğünü — iki köylü yuva kurmak istiyor. Etki alanı: SOSYAL + moral.
    // Animasyon: ateş başında dans + yükselen kalpler + yaprak/konfeti yağmuru.
    _PetitionDef(
      (c) => c.adults >= 4,
      0.7,
      const Petition(
        id: 'villageWedding',
        petitioner: 'Sevdalı bir çift',
        icon: '💍',
        title: 'Bir Düğün Var',
        tone: PetitionTone.warm,
        estate: Estate.hearth,
        body: 'Köyden iki genç birbirine gönül vermiş, yuva kurmak istiyorlar. '
            'Köy bir düğün için sabırsız — ateş yakılsın, halay çekilsin mi, '
            'yoksa sade mi tutalım?',
        options: [
          PetitionOption(
            label: 'Coşkulu bir düğün!',
            detail: 'Biraz altın harca; ateş başında dans, müzik, kutlama olsun.',
            resolution: '💍 Düğün kuruldu — köy ateş başında göbek attı!',
            goldDelta: -4,
            moraleAmount: 0.10,
            moraleDays: 4,
            fx: PetitionFx.wedding,
            estateMood: [(Estate.hearth, 0.10), (Estate.laborers, 0.04), (Estate.artisans, -0.04)],
          ),
          PetitionOption(
            label: 'Sade bir tören yeter',
            detail: 'Mütevazı ama içten bir kutlama — köy yine sevinir.',
            resolution: '💍 Sade bir düğün yapıldı — çift mutlu, köy huzurlu.',
            moraleAmount: 0.05,
            moraleDays: 3,
            fx: PetitionFx.wedding,
            estateMood: [(Estate.hearth, 0.06)],
          ),
        ],
      ),
    ),

    // ─── Hizip dilekçeleri — bir zümrenin kazancı, diğerinin kaybı ──────────
    // Politik dengenin özü: net "doğru" yok, kimi sevindirirsen kimi küser.

    // 💰 Pazar vergisi — Emekçiler tüccarlardan vergi ister (ambar fonu).
    _PetitionDef(
      (c) => c.adults >= 5,
      0.7,
      const Petition(
        id: 'marketTax',
        petitioner: 'Çiftçi sözcüsü',
        icon: '💰',
        title: 'Pazar Vergisi',
        tone: PetitionTone.neutral,
        estate: Estate.laborers,
        stakes: 'Vergi koy → ambar dolar, tüccar küser; serbest bırak → tersi.',
        body: 'Emekçiler homurdanıyor: "Pazar şişiyor, kese tüccarda kalıyor. '
            'Küçük bir pazar vergisiyle ortak ambarı doldurup zor günlere '
            'hazırlanalım." Zanaatkârlar bundan hoşlanmayacak.',
        options: [
          PetitionOption(
            label: 'Vergiyi koy',
            detail: 'Tüccardan küçük bir pay alınır, ortak kese dolar.',
            resolution: '💰 Pazar vergisi kondu — ambar doldu, tüccarlar somurttu.',
            goldDelta: 6,
            estateMood: [(Estate.laborers, 0.12), (Estate.hearth, 0.05), (Estate.artisans, -0.15)],
          ),
          PetitionOption(
            label: 'Pazarı serbest bırak',
            detail: 'Vergi yok; zanaat akar ama emekçiler küser.',
            resolution: '💰 Pazar serbest kaldı — tüccarlar sevindi, emekçiler buruk.',
            estateMood: [(Estate.artisans, 0.12), (Estate.laborers, -0.09)],
          ),
        ],
      ),
    ),

    // 🌙 Kutsal gün — İnananlar dinlenme/ibadet günü ister; iş durur.
    _PetitionDef(
      (c) => c.population >= 6 &&
          (c.hasChurch || c.remembers('cult.active')),
      0.6,
      const Petition(
        id: 'holyDay',
        petitioner: 'İnananların sözcüsü',
        icon: '🌙',
        title: 'Kutsal Gün',
        tone: PetitionTone.solemn,
        estate: Estate.faithful,
        stakes: 'İlan et → huzur ama bir iş günü gider; reddet → tersi.',
        body: 'İnananlar haftada bir "kutsal gün" istiyor — herkesin işi bırakıp '
            'dinlendiği, ibadet ettiği bir gün. Ruhları dinginleştirir ama '
            'tarlada ve atölyede bir gün kaybedilir.',
        options: [
          PetitionOption(
            label: 'Kutsal günü ilan et',
            detail: 'Köy haftada bir durur — huzur artar, üretim azalır.',
            resolution: '🌙 Kutsal gün ilan edildi — köye dingin bir nefes indi.',
            moraleAmount: 0.05,
            moraleDays: 6,
            setsFlags: ['holyDay.active'],
            estateMood: [(Estate.faithful, 0.14), (Estate.hearth, 0.05), (Estate.laborers, -0.08), (Estate.artisans, -0.08)],
          ),
          PetitionOption(
            label: 'İş başına',
            detail: 'Gün kaybı olmaz; emekçi ve zanaatkâr memnun, inanan küs.',
            resolution: '🌙 Kutsal gün reddedildi — çarklar dönmeye devam ediyor.',
            estateMood: [(Estate.faithful, -0.12), (Estate.laborers, 0.06), (Estate.artisans, 0.06)],
          ),
        ],
      ),
    ),

    // 🧓 Yaşlılar meclisi mi, gençlerin sesi mi — Ocak vs genç emek/zanaat.
    _PetitionDef(
      (c) => c.population >= 6 && c.adults >= 4,
      0.6,
      const Petition(
        id: 'eldersCouncil',
        petitioner: 'Köyün ihtiyarları',
        icon: '🧓',
        title: 'Kimin Sözü Geçer?',
        tone: PetitionTone.neutral,
        estate: Estate.hearth,
        stakes: 'Yaşlılara kulak ver → gelenek; gençlere → atılganlık.',
        body: 'Köyde bir tartışma var: kararlarda kimin sözü ağır basmalı? '
            'İhtiyarlar bir "yaşlılar meclisi" kurulsun, tecrübe konuşsun '
            'istiyor. Genç emekçiler ve zanaatkârlar ise kendi seslerinin '
            'duyulmasını bekliyor.',
        options: [
          PetitionOption(
            label: 'Yaşlılar meclisi kurulsun',
            detail: 'Tecrübe öne geçer; gençler biraz geri planda kalır.',
            resolution: '🧓 Yaşlılar meclisi kuruldu — gelenek köyün pusulası oldu.',
            setsFlags: ['council.elders'],
            estateMood: [(Estate.hearth, 0.14), (Estate.faithful, 0.04), (Estate.laborers, -0.06), (Estate.artisans, -0.06)],
          ),
          PetitionOption(
            label: 'Gençlerin sesi duyulsun',
            detail: 'Atılgan genç eller söz sahibi olur; ihtiyarlar küser.',
            resolution: '🧒 Gençlere kulak verildi — köyde taze bir rüzgâr esti.',
            setsFlags: ['council.youth'],
            estateMood: [(Estate.laborers, 0.08), (Estate.artisans, 0.08), (Estate.hearth, -0.12)],
          ),
        ],
      ),
    ),

    // ─── Dış krizler — dışarıdan gelen baskı, zümreleri karşı karşıya getirir ─
    // Cozy: kaybetmek yok ama karar zümre dengesini sarsar.

    // 🌵 Kuraklık — su kıt; tarla mı, hane mi öncelikli?
    _PetitionDef(
      (c) => c.population >= 6 && c.food >= 10,
      0.5,
      const Petition(
        id: 'drought',
        petitioner: 'Kuyubaşı telaşı',
        icon: '🌵',
        title: 'Kuraklık',
        tone: PetitionTone.ominous,
        estate: Estate.laborers,
        stakes: 'Suyu tarlaya ver → hasat kurtulur, haneler susar; tersi olur.',
        body: 'Haftalardır yağmur yok, kuyu çekiliyor. Kalan suyu tarlalara mı '
            'verelim, yoksa hanelere eşit mi paylaştıralım? Her iki seçenek de '
            'birini susuz bırakacak.',
        options: [
          PetitionOption(
            label: 'Tarlalara öncelik',
            detail: 'Hasat kurtulur; haneler kısıtlanır, Ocak küser.',
            resolution: '🌾 Su tarlalara verildi — hasat kurtuldu, haneler kıstı.',
            foodDelta: 4,
            estateMood: [(Estate.laborers, 0.10), (Estate.hearth, -0.07)],
          ),
          PetitionOption(
            label: 'Hanelere eşit pay',
            detail: 'Evler rahatlar; tarlalar kavrulur, ürün kaybı olur.',
            resolution: '🏡 Su hanelere paylaştırıldı — tarlalar kavruldu.',
            foodDelta: -6,
            moraleAmount: -0.02,
            moraleDays: 2,
            fx: PetitionFx.cropBlight,
            estateMood: [(Estate.hearth, 0.08), (Estate.laborers, -0.09)],
          ),
        ],
      ),
    ),

    // 🧳 Göçmen kafilesi — yorgun yabancılar kapıda; kabul mü, geçiş mi?
    _PetitionDef(
      (c) => c.population >= 6,
      0.5,
      const Petition(
        id: 'migrantCaravan',
        petitioner: 'Yorgun gezginler',
        icon: '🧳',
        title: 'Kapıda Bir Kafile',
        tone: PetitionTone.neutral,
        estate: Estate.artisans,
        stakes: 'Kabul et → eller+pazar canlanır, Ocak tedirgin; geçir → tersi.',
        body: 'Uzak diyardan yorgun bir kafile köyün kapısına dayandı; sığınak '
            've ekmek istiyorlar. Zanaatkârlar yeni eller ve yeni pazar görüyor; '
            'Ocak ise yabancılardan tedirgin.',
        options: [
          PetitionOption(
            label: 'Kapıyı aç, kabul et',
            detail: 'Yeni yüzler köye katılır; biraz yiyecek gider, Ocak küser.',
            resolution: '🧳 Kafile köye buyur edildi — pazar canlandı, yeni yüzler geldi.',
            foodDelta: -4,
            setsFlags: ['migrants.welcomed'],
            estateMood: [(Estate.artisans, 0.12), (Estate.hearth, -0.10)],
          ),
          PetitionOption(
            label: 'Geçip gitsinler',
            detail: 'Köy kendi içine kapanır; Ocak rahatlar, zanaat küser.',
            resolution: '🚪 Kafile yoluna devam etti — köy kendi düzenini korudu.',
            estateMood: [(Estate.hearth, 0.08), (Estate.artisans, -0.08)],
          ),
        ],
      ),
    ),

    // 🏴 Komşu köy elçisi — ticaret anlaşması mı, kendi yolumuz mu?
    _PetitionDef(
      (c) => c.population >= 8 && c.gold >= 4,
      0.45,
      const Petition(
        id: 'neighborEnvoy',
        petitioner: 'Komşu köyün elçisi',
        icon: '🏴',
        title: 'Komşudan Elçi',
        tone: PetitionTone.neutral,
        estate: Estate.artisans,
        stakes: 'Anlaşma → kese dolar, İnananlar küser; reddet → tersi.',
        body: 'Komşu köyden bir elçi geldi: karşılıklı ticaret ve dostluk '
            'anlaşması öneriyor. Zanaatkârlar kese için heyecanlı; İnananlar ise '
            '"yabancı âdetler köyün ruhunu bozar" diye tedirgin.',
        options: [
          PetitionOption(
            label: 'Anlaşmayı yap',
            detail: 'Ticaret açılır, kese dolar; İnananlar yabancılaşmadan korkar.',
            resolution: '🏴 Komşuyla ticaret anlaşması imzalandı — kese doldu.',
            goldDelta: 8,
            setsFlags: ['pact.neighbor'],
            estateMood: [(Estate.artisans, 0.12), (Estate.faithful, -0.06)],
          ),
          PetitionOption(
            label: 'Kendi yolumuz',
            detail: 'Elçi geri çevrilir; köy ruhunu korur, zanaat fırsat kaçırır.',
            resolution: '🕯️ Elçi geri çevrildi — köy kendi yolunda kaldı.',
            estateMood: [(Estate.faithful, 0.08), (Estate.hearth, 0.05), (Estate.artisans, -0.10)],
          ),
        ],
      ),
    ),

    // ─── Takip dilekçeleri (zincir) — yalnız bir önceki karara bağlı gelir ───
    // canFire: false → random roll'a çıkmaz; sadece followUpId ile tetiklenir.

    // 🎊 Şenliği gelenek yapma teklifi (harvestFestival onayının takibi).
    _PetitionDef(
      (_) => false,
      0,
      const Petition(
        id: 'festivalAnnual',
        petitioner: 'Çiftçiler',
        icon: '🎊',
        title: 'Gelenek Olsun mu?',
        tone: PetitionTone.warm,
        estate: Estate.laborers,
        note: '↩ Şenlik günlerce konuşuldu',
        body: 'Geçen şenlik köyde derin bir iz bıraktı. Çiftçiler bunu her '
            'hasatta tekrarlanan bir gelenek yapmak istiyor — köyün kendi '
            'bayramı olsun.',
        options: [
          PetitionOption(
            label: 'Gelenek olsun',
            detail: 'Hasat şenliği köyün kalıcı bir neşe kaynağı olur.',
            resolution: '🎊 Hasat şenliği artık köyün geleneği!',
            moraleAmount: 0.06,
            moraleDays: 10,
            fx: PetitionFx.festival,
            setsFlags: ['festival.tradition'],
            estateMood: [(Estate.laborers, 0.12), (Estate.hearth, 0.06)],
          ),
          PetitionOption(
            label: 'Gerek yok',
            detail: 'Güzeldi ama her yıl şart değil.',
            resolution: '🎊 Gelenek fikri şimdilik rafa kalktı.',
            moraleAmount: -0.02,
            moraleDays: 1,
            estateMood: [(Estate.laborers, -0.06)],
          ),
        ],
      ),
    ),

    // ⛪ Kült büyüdü (newFaith "Bırak" takibi). cult.active hafızasının 2. adımı.
    // Karar dallanır: tapınak ver (cult.temple → cultSchism'e gider) ya da
    // sınırla (cult.active silinir, inanç söner).
    _PetitionDef(
      (_) => false,
      0,
      const Petition(
        id: 'cultGrows',
        petitioner: 'Yeni inananlar',
        icon: '🔮',
        title: 'İnanç Yayılıyor',
        tone: PetitionTone.ominous,
        estate: Estate.faithful,
        note: '↩ Ayinlere göz yummuştun',
        stakes: 'Tapınak ver → güçlenir; sınırla → söner.',
        body: 'Göz yumduğun inanç hızla yayıldı — artık köyün yarısı geceleri '
            'ateş başındaki ayinlere katılıyor. İnananlar kendilerine ait bir '
            'ibadet yeri istiyor. Bu bir dönüm noktası.',
        options: [
          PetitionOption(
            label: 'Bir tapınak ver',
            detail: 'Altın + taş harca; inanç köyün merkezine yerleşir.',
            resolution: '🔮 İnananlara bir ibadet yeri verildi — kült artık köyün bir parçası.',
            goldDelta: -6,
            stoneDelta: -10,
            moraleAmount: 0.05,
            moraleDays: 5,
            fx: PetitionFx.cult,
            setsFlags: ['cult.temple'],
            followUpId: 'cultSchism',
            followUpDelayDays: 4.0,
            estateMood: [(Estate.faithful, 0.14), (Estate.hearth, -0.10), (Estate.artisans, -0.05)],
          ),
          PetitionOption(
            label: 'Yeter, sınırla',
            detail: 'Ayinler kısıtlanır; inananlar küser ama köy dengesini korur.',
            resolution: '⛪ İnanç sınırlandı — ateşler söndü, köy eski hâline döndü.',
            moraleAmount: -0.06,
            moraleDays: 4,
            clearsFlags: ['cult.active'],
            setsFlags: ['cult.suppressed'],
            estateMood: [(Estate.faithful, -0.16), (Estate.hearth, 0.08)],
          ),
        ],
      ),
    ),

    // ⚡ Kültte bölünme (cultGrows "tapınak" takibi). cult.temple'ın 3. adımı —
    // yayın doruğu: iki hizip çatışır, biri köyü terk eder ya da uzlaşılır.
    _PetitionDef(
      (_) => false,
      0,
      const Petition(
        id: 'cultSchism',
        petitioner: 'Bölünen cemaat',
        icon: '⚡',
        title: 'İnançta Bölünme',
        tone: PetitionTone.ominous,
        estate: Estate.faithful,
        note: '↩ Tapınağı sen vermiştin',
        stakes: 'Saf tut → biri göçer; uzlaştır → altınla birliği koru.',
        body: 'Tapınaktaki inananlar ikiye bölündü: kimi eski öğretiye sadık, '
            'kimi yeni bir peygamberin ardında. Gerilim büyüyor, köy taraf '
            'tutmanı bekliyor.',
        options: [
          PetitionOption(
            label: 'Bir hizbi destekle',
            detail: 'Net taraf; kaybeden hizip küser, biri köyü terk eder.',
            resolution: '', // dinamik: ayrılanın ismi reaksiyondan
            moraleAmount: -0.04,
            moraleDays: 4,
            fx: PetitionFx.vigil, // ayrılış — mum töreni havası
            estateMood: [(Estate.faithful, -0.06)],
          ),
          PetitionOption(
            label: 'İki tarafı uzlaştır',
            detail: 'Altın + sabır harca; ortak bir ayinde barıştırırsın.',
            resolution: '🔮 İki hizip ortak bir ayinde barıştı — inanç bütünleşti.',
            goldDelta: -8,
            moraleAmount: 0.07,
            moraleDays: 6,
            fx: PetitionFx.cult,
            setsFlags: ['cult.united'],
            estateMood: [(Estate.faithful, 0.10), (Estate.artisans, -0.05)],
          ),
        ],
      ),
    ),

    // 🌾 Bereketli hasat (cropBlight "İlaçla" takibi). fields.tended ödülü:
    // iyi bakılan toprak günler sonra bolca verir. BESPOKE harvestBounty fx.
    _PetitionDef(
      (_) => false,
      0,
      const Petition(
        id: 'bountifulHarvest',
        petitioner: 'Müteşekkir çiftçiler',
        icon: '🌾',
        title: 'Toprak Cömert',
        tone: PetitionTone.warm,
        estate: Estate.laborers,
        note: '↩ Tarlalara iyi bakmıştın',
        stakes: 'İyi bakımın karşılığı — bol yiyecek + coşku.',
        body: 'Mantarı vaktinde temizlediğin tarlalar bu mevsim altın gibi '
            'parlıyor — başaklar bereketle dolu. Çiftçiler hasadı kutlamak, '
            'fazlasını köyle paylaşmak istiyor.',
        options: [
          PetitionOption(
            label: 'Hasadı kutla, paylaş',
            detail: 'Bolluk köye dağıtılır — ambar dolar, yüzler güler.',
            resolution: '🌾 Bereketli hasat kaldırıldı — ambarlar doldu, köy şükran içinde!',
            foodDelta: 18,
            moraleAmount: 0.08,
            moraleDays: 5,
            fx: PetitionFx.harvestBounty,
            estateMood: [(Estate.laborers, 0.12), (Estate.hearth, 0.05)],
          ),
          PetitionOption(
            label: 'Fazlayı sat',
            detail: 'Bolluğu altına çevir; daha az coşku ama dolu kese.',
            resolution: '🌾 Fazla hasat pazarda satıldı — kese doldu.',
            foodDelta: 6,
            goldDelta: 10,
            moraleAmount: 0.03,
            moraleDays: 3,
            fx: PetitionFx.harvestBounty,
            estateMood: [(Estate.artisans, 0.12), (Estate.laborers, 0.03)],
          ),
        ],
      ),
    ),

  ];
}
