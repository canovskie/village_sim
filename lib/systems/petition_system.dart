import 'dart:math';
import '../world/season.dart';
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
  wedding,     // BESPOKE: sade düğün — gerçek çift ateş başında, kalp/yaprak yağmuru
  weddingGrand,// BESPOKE: coşkulu düğün — önce tam ekran 2B sinematik, sonra alay/şenlik
  harvestBounty, // BESPOKE: tarlalar altın ışıltıyla olgunlaşır + bereket zerresi yükselir
  callingGranted,// BESPOKE: dilekçe sahibi mesleğini bırakıp çağrısının peşinden gider
  feudPeace,     // BESPOKE: iki aile barışır — kan davası sona erer (husumet silinir)
  feudExile,     // BESPOKE: kan davasının suçlusu köyden sürülür → husumet kapanır
  feudExecute,   // BESPOKE: suçlu 2B sahnede idam edilir → kan davası kanla kapanır
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
  /// Şu an gerçekten KÜSKÜN (sullen eşiği altı) zümre — yoksa null. Küskünlük
  /// "dişi": o zümre ısrarla dilekçe gönderir (canFire kapısı + roll ağırlığı).
  final Estate? aggrievedEstate;
  /// Köyün baskın zümresi (kimlik) — yoksa null. Kimliğe özel ödül dilekçeleri
  /// (şenlik/hikâye) bunun üzerinden de açılabilir (memory bayrağına ek).
  final Estate? ascendant;
  /// Ağıl/kümesteki canlı hayvan sayısı — sürü dilekçelerinin kapısı.
  final int herdSize;
  /// Sürü ortalama açlığı yüksek mi (bakımsız ahır) — yem sıkıntısı dilekçesi.
  final bool herdHungry;
  /// Aktif mevsim — mevsime özel dilekçelerin kapısı (yaz kuraklığı vb).
  final Season season;
  /// Köyde işlenen (büyüyen/hasada hazır) tarla var mı — tarım dilekçelerinin
  /// kapısı (tarla yoksa kuraklık/hasat dilekçesi anlamsız).
  final bool hasCrops;
  /// Mesleği içindeki çağrıya uymayan (kırgın) en az bir köylü var mı — meslek
  /// değiştirme dilekçesinin kapısı.
  final bool hasResentful;
  /// Köyde aktif bir kan davası var mı — sulh (barışma) dilekçesinin kapısı.
  final bool hasFeud;

  // ── Aktif yasalar (politika↔dilekçe köprüsü) ───────────────────────────────
  // Yürürlükteki bir yasa köyde sosyal bir karşılık doğurabilir: lehte olan
  // zümre teşekkür/şölen ister, aleyhte olan zümre geri adım talep eder.
  /// Dönemli ekim yürürlükte mi — çiftçi takvim şöleni dilekçesinin kapısı.
  final bool cropRotation;
  /// Misafirperverlik yürürlükte mi — gezgin yerleşme dilekçesinin kapısı.
  final bool hospitality;
  /// Köyde boş yatak (yerleşilecek hane) var mı — yerleşme dilekçesinin kapısı.
  final bool hasHousing;

  const PetitionContext({
    required this.population,
    required this.adults,
    required this.food,
    required this.gold,
    required this.morale,
    required this.hasChurch,
    this.memory = const {},
    this.aggrievedEstate,
    this.ascendant,
    this.herdSize = 0,
    this.herdHungry = false,
    this.season = Season.spring,
    this.hasCrops = false,
    this.hasResentful = false,
    this.hasFeud = false,
    this.cropRotation = false,
    this.hospitality = false,
    this.hasHousing = false,
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
    // Küskünlük dişi: küskün zümrenin dilekçeleri belirgin biçimde daha olası
    // → o zümre köyün gündemine ısrarla girer (huysuz/ısrarlı dilekçe hissi).
    final agg = ctx.aggrievedEstate;
    double weightOf(_PetitionDef d) =>
        (agg != null && d.petition.estate == agg) ? d.weight * 2.4 : d.weight;
    final total = eligible.fold<double>(0, (s, d) => s + weightOf(d));
    var pick = rng.nextDouble() * total;
    for (final d in eligible) {
      pick -= weightOf(d);
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
    // ════════════════════════════════════════════════════════════════════════
    // KÜSKÜNLÜK DİLEKÇELERİ — bir zümre sullen eşiği altına düşünce ısrarla
    // gündeme gelir (canFire = aggrievedEstate + roll ağırlık boost). Cozy:
    // gidermek küçük bir jest, savsaklamak yalnızca o zümreyi biraz daha küstürür.
    // ════════════════════════════════════════════════════════════════════════

    // 🌫️ Bir köylü çağrısının peşinden gitmek ister — mesleği gönlüne uymuyor.
    // Yazar sahnede o kırgın köylüdür (_pickPetitionAuthor özel-durumu).
    _PetitionDef(
      (c) => c.hasResentful && c.population >= 4,
      1.1,
      const Petition(
        id: 'professionCalling',
        petitioner: 'Gönlü başka işte bir köylü',
        icon: '🌫️',
        title: 'Çağrısının Peşinden Gitmek İstiyor',
        tone: PetitionTone.solemn,
        note: '↩ Bu köylü uzun süredir mesleğine küs',
        stakes: 'İzin ver → gönlü açılır ama eski el eksilir; reddet → küskünlük derinleşir.',
        body: 'Köyün biri uzun zamandır yaptığı işte mutsuz; içinde bambaşka '
            'bir çağrı var. Yıllardır taşıdığı zanaatı bırakıp gönlünün çektiği '
            'işe geçmek için izin istiyor. Bırakırsan biri o eski işten eksilir, '
            'ama bu kez kendi yolunda yürür.',
        options: [
          PetitionOption(
            label: 'Bırak, çağrısının peşinden gitsin',
            detail: 'Köylü mesleğini değiştirir — gönlü açılır, kırgınlığı diner.',
            resolution: '',
            moraleAmount: 0.04,
            moraleDays: 2,
            fx: PetitionFx.callingGranted,
            estateMood: [(Estate.hearth, 0.10), (Estate.artisans, -0.05)],
          ),
          PetitionOption(
            label: 'Mesleğinde kalsın',
            detail: 'Köy düzeni korunur ama köylünün küskünlüğü derinleşir.',
            resolution: '🌫️ Köylü mesleğinde kalmak zorunda kaldı — içi buruk.',
            moraleAmount: -0.05,
            moraleDays: 2,
            estateMood: [(Estate.hearth, -0.10), (Estate.artisans, 0.04)],
          ),
        ],
      ),
    ),

    // 🩸 Kan davası — köy yaşlıları iki aileyi barıştırman için yalvarır.
    _PetitionDef(
      (c) => c.hasFeud,
      1.4,
      const Petition(
        id: 'feudReconcile',
        petitioner: 'Köyün yaşlıları',
        icon: '🩸',
        title: 'Kan Davasını Bitir',
        tone: PetitionTone.ominous,
        note: '↩ İki aile birbirine kan kustu',
        stakes: 'Sulh → husumet silinir, köy nefes alır; reddet → ölüm döngüsü sürer.',
        body: 'İki aile arasındaki kan davası köyü zehirliyor — her karşılaşma '
            'bir kavgaya, kimi kavga bir mezara dönüyor. Köyün yaşlıları bir sulh '
            'meclisi topladı: barışı dayatırsan husumet diner. Reddedersen kan '
            'kanı çağırmaya devam eder.',
        options: [
          PetitionOption(
            label: 'Sulh dayat — barıştır',
            detail: 'Diyet öde, iki aileyi barıştır; husumet silinir, köy yarasını sarar.',
            resolution: '',
            goldDelta: -6, // diyet / barış bedeli
            moraleAmount: 0.10,
            moraleDays: 4,
            fx: PetitionFx.feudPeace,
            estateMood: [(Estate.faithful, 0.12), (Estate.hearth, 0.12)],
          ),
          PetitionOption(
            label: 'Suçluyu sürgün et',
            detail: 'En çok kan dökeni köyden kov — kan davası uzaklaştırmayla diner.',
            resolution: '',
            fx: PetitionFx.feudExile,
            moraleAmount: -0.04,
            moraleDays: 2,
            estateMood: [(Estate.faithful, 0.04), (Estate.hearth, -0.06)],
          ),
          PetitionOption(
            label: 'Suçluyu idam et',
            detail: 'Son çare: halkın önünde idam. Kan davası kanla biter ama köyü dehşet sarar.',
            resolution: '',
            fx: PetitionFx.feudExecute,
            moraleAmount: -0.10,
            moraleDays: 4,
            estateMood: [(Estate.faithful, 0.06), (Estate.hearth, -0.12)],
          ),
          PetitionOption(
            label: 'Karışma — kan davası sürsün',
            detail: 'Husumet devam eder; intikam döngüsü köyü kanatmaya devam eder.',
            resolution: '🩸 Sulh reddedildi — kan davası gölgesi köyün üstünde.',
            moraleAmount: -0.08,
            moraleDays: 3,
            estateMood: [(Estate.faithful, -0.10), (Estate.hearth, -0.10)],
          ),
        ],
      ),
    ),

    // 😤 Emekçiler yorgun — bir nefes molası ister.
    _PetitionDef(
      (c) => c.aggrievedEstate == Estate.laborers && c.population >= 4,
      1.0,
      const Petition(
        id: 'grievanceLaborers',
        petitioner: 'Yorgun emekçiler',
        icon: '🌾',
        title: 'Emekçiler Soluklanmak İstiyor',
        tone: PetitionTone.solemn,
        estate: Estate.laborers,
        note: '↩ Emekçiler bir süredir küskün',
        stakes: 'Küçük bir mola → tazelenmiş eller; ısrar → daha derin küskünlük.',
        body: 'Tarlada, ocakta, ormanda eller durmadan çalışıyor. Emekçiler '
            'soluk soluğa: bir dinlenme günü, bir nefes molası istiyorlar. '
            'Duyulmak istiyorlar.',
        options: [
          PetitionOption(
            label: 'Bir dinlenme günü ver',
            detail: 'Üretim kısa süre yavaşlar ama emekçiler tazelenir.',
            resolution: '🌾 Emekçiler bir gün soluklandı — yüzleri yumuşadı.',
            moraleAmount: 0.05,
            moraleDays: 2,
            estateMood: [(Estate.laborers, 0.18), (Estate.artisans, -0.04)],
          ),
          PetitionOption(
            label: 'İş başına dönsünler',
            detail: 'Mola yok — emekçilerin küskünlüğü derinleşir.',
            resolution: '🌾 Emekçiler başını önüne eğip işe döndü.',
            moraleAmount: -0.02,
            moraleDays: 1,
            estateMood: [(Estate.laborers, -0.08)],
          ),
        ],
      ),
    ),

    // 🔨 Zanaatkârlar değer görmek ister.
    _PetitionDef(
      (c) => c.aggrievedEstate == Estate.artisans && c.population >= 4,
      1.0,
      const Petition(
        id: 'grievanceArtisans',
        petitioner: 'Küskün zanaatkârlar',
        icon: '🔨',
        title: 'Zanaatkârlar Değer Görmek İstiyor',
        tone: PetitionTone.solemn,
        estate: Estate.artisans,
        note: '↩ Zanaatkârlar bir süredir küskün',
        stakes: 'Pazara biraz yatırım → gönül alma; görmezden gelme → küskünlük.',
        body: 'Tüccarlar ve demirciler söyleniyor: emekleri görülmüyor, '
            'pazarda sözleri geçmiyor. Küçük bir yatırım, bir tezgâh tahsisi '
            'gönüllerini alır.',
        options: [
          PetitionOption(
            label: 'Pazara yatırım yap',
            detail: 'Biraz altın harca; zanaatkârlar el üstünde tutulduğunu görsün.',
            resolution: '🔨 Pazar canlandı — zanaatkârların yüzü güldü.',
            goldDelta: -6,
            moraleAmount: 0.03,
            moraleDays: 2,
            estateMood: [(Estate.artisans, 0.18), (Estate.laborers, -0.04)],
          ),
          PetitionOption(
            label: 'Şimdilik olmaz',
            detail: 'Yatırım yok — zanaatkârlar daha da küser.',
            resolution: '🔨 Zanaatkârlar homurdanarak tezgâhına döndü.',
            moraleAmount: -0.02,
            moraleDays: 1,
            estateMood: [(Estate.artisans, -0.08)],
          ),
        ],
      ),
    ),

    // 🕯️ İnananlar maneviyat ihmal edildiğinden huzursuz.
    _PetitionDef(
      (c) => c.aggrievedEstate == Estate.faithful && c.population >= 4,
      1.0,
      const Petition(
        id: 'grievanceFaithful',
        petitioner: 'Huzursuz inananlar',
        icon: '🕯️',
        title: 'İnananlar Anlam Arıyor',
        tone: PetitionTone.solemn,
        estate: Estate.faithful,
        note: '↩ İnananlar bir süredir küskün',
        stakes: 'Bir ayin gününe izin → huzur; reddetme → maneviyat soğur.',
        body: 'Köyde maneviyat geri planda kaldı; inananlar huzursuz. Bir '
            'ayin günü, ateş başında bir dua vakti istiyorlar — anlam '
            'arıyorlar.',
        options: [
          PetitionOption(
            label: 'Bir ayin gününe izin ver',
            detail: 'İnananlar ateş başında toplanır, köy anlam bulur.',
            resolution: '🕯️ İnananlar ateş başında toplandı — yürekler yatıştı.',
            moraleAmount: 0.03,
            moraleDays: 2,
            fx: PetitionFx.cult,
            estateMood: [(Estate.faithful, 0.18), (Estate.hearth, -0.04)],
          ),
          PetitionOption(
            label: 'Sıradan günlere dön',
            detail: 'Ayin yok — inananların gönlü iyice soğur.',
            resolution: '🕯️ İnananlar sessizce dağıldı.',
            moraleAmount: -0.02,
            moraleDays: 1,
            estateMood: [(Estate.faithful, -0.08)],
          ),
        ],
      ),
    ),

    // 🏡 Ocak (yaşlılar + aileler) gelenek ihmal edildiğinden küskün.
    _PetitionDef(
      (c) => c.aggrievedEstate == Estate.hearth && c.population >= 4,
      1.0,
      const Petition(
        id: 'grievanceHearth',
        petitioner: 'Ocağın yaşlıları',
        icon: '🏡',
        title: 'Ocak Unutulmak İstemiyor',
        tone: PetitionTone.solemn,
        estate: Estate.hearth,
        note: '↩ Ocak bir süredir küskün',
        stakes: 'Geleneği onurlandır → sıcaklık; savsakla → ocak küser.',
        body: 'Yaşlılar ve aileler içlerine kapandı: gelenek unutuluyor, '
            'yuvaya özen azalıyor diyorlar. Küçük bir saygı jesti ocağı '
            'yeniden ısıtır.',
        options: [
          PetitionOption(
            label: 'Geleneği onurlandır',
            detail: 'Ortak bir sofra kur; yaşlılara saygı, yuvaya sıcaklık.',
            resolution: '🏡 Ocak yeniden ısındı — köy bir aile gibi.',
            foodDelta: -4,
            moraleAmount: 0.04,
            moraleDays: 2,
            estateMood: [(Estate.hearth, 0.18), (Estate.faithful, 0.04)],
          ),
          PetitionOption(
            label: 'Şimdilik değil',
            detail: 'Jest yok — ocağın küskünlüğü derinleşir.',
            resolution: '🏡 Yaşlılar içini çekip sustu.',
            moraleAmount: -0.02,
            moraleDays: 1,
            estateMood: [(Estate.hearth, -0.08)],
          ),
        ],
      ),
    ),

    // ════════════════════════════════════════════════════════════════════════
    // KİMLİK ÖDÜL DİLEKÇELERİ — köy bir kimliğe kaydığında (identity.<ad>
    // bayrağı) o kimliğe ÖZEL şenlik/hikâye açılır. Kimliğe ulaşmanın görünür
    // ödülü: yeni içerik + kutlama. Cozy: kutlamak ödül, sade geçmek ufak gönül.
    // ════════════════════════════════════════════════════════════════════════

    // 🌾 Bereketli Köy → Bereket Bayramı (tarlalar altın ışıltıyla parlar).
    _PetitionDef(
      (c) => c.remembers('identity.laborers') && c.food >= 20,
      0.7,
      const Petition(
        id: 'identityHarvestFeast',
        petitioner: 'Bereketli Köy',
        icon: '🌾',
        title: 'Bereket Bayramı',
        tone: PetitionTone.warm,
        estate: Estate.laborers,
        note: '✦ Köyün kimliği: Bereketli Köy',
        stakes: 'Biraz altın → tarlalar günlerce bereketle parlar.',
        body: 'Köy bolluğuyla anılır oldu. Emekçiler büyük bir bereket bayramı '
            'istiyor — tarlalar altın başaklarla süslenecek, sofralar dolacak, '
            'köy şükranla kutlayacak.',
        options: [
          PetitionOption(
            label: 'Bayramı kutla!',
            detail: 'Altın harca; tarlalar günlerce bereketle parlar, köy coşar.',
            resolution: '🌾 Bereket Bayramı başladı — tarlalar altın gibi!',
            goldDelta: -5,
            moraleAmount: 0.12,
            moraleDays: 3,
            fx: PetitionFx.harvestBounty,
            estateMood: [(Estate.laborers, 0.10), (Estate.hearth, 0.05)],
          ),
          PetitionOption(
            label: 'Sade geçelim',
            detail: 'Bu yıl mütevazı kalalım — küçük bir hayal kırıklığı.',
            resolution: '🌾 Bereket bayramı bu yıl sade geçti.',
            moraleAmount: -0.02,
            moraleDays: 1,
            estateMood: [(Estate.laborers, -0.05)],
          ),
        ],
      ),
    ),

    // 🔨 Zanaat Kasabası → Zanaat Panayırı (çevreden alıcı gelir, kazanç).
    _PetitionDef(
      (c) => c.remembers('identity.artisans') && c.population >= 6,
      0.7,
      const Petition(
        id: 'identityCraftFair',
        petitioner: 'Zanaat Kasabası',
        icon: '🔨',
        title: 'Zanaat Panayırı',
        tone: PetitionTone.warm,
        estate: Estate.artisans,
        note: '✦ Köyün kimliği: Zanaat Kasabası',
        stakes: 'Panayır kur → çevreden alıcı gelir, kese dolar + coşku.',
        body: 'Köyün ustaları nam saldı. Büyük bir panayır kurmak istiyorlar — '
            'çevre köylerden alıcılar gelecek, tezgâhlar dolacak, kese '
            'şişecek. Köy günlerce bunu konuşur.',
        options: [
          PetitionOption(
            label: 'Panayırı kur!',
            detail: 'Çevreden alıcı akar; köy kazanır ve şenlenir.',
            resolution: '🔨 Zanaat Panayırı kuruldu — kese doldu, köy şenlendi!',
            goldDelta: 8,
            moraleAmount: 0.10,
            moraleDays: 3,
            fx: PetitionFx.festival,
            estateMood: [(Estate.artisans, 0.10), (Estate.laborers, 0.04)],
          ),
          PetitionOption(
            label: 'Gerek yok',
            detail: 'Panayır kurulmaz — ustalar biraz kırılır.',
            resolution: '🔨 Panayır bu sefer kurulmadı.',
            moraleAmount: -0.02,
            moraleDays: 1,
            estateMood: [(Estate.artisans, -0.05)],
          ),
        ],
      ),
    ),

    // 🕯️ Kutsal Köy → Büyük Ayin (köy çapında şükran töreni).
    _PetitionDef(
      (c) => c.remembers('identity.faithful') && c.population >= 5,
      0.7,
      const Petition(
        id: 'identityGreatRite',
        petitioner: 'Kutsal Köy',
        icon: '🕯️',
        title: 'Büyük Ayin',
        tone: PetitionTone.warm,
        estate: Estate.faithful,
        note: '✦ Köyün kimliği: Kutsal Köy',
        stakes: 'Ayini başlat → köy huzur ve anlam içinde toplanır.',
        body: 'Köy kutsallığıyla anılır oldu. İnananlar büyük bir ayin, bir '
            'şükran töreni istiyor — ateş başında diz çöküp köyün ruhunu '
            'kutsayacaklar.',
        options: [
          PetitionOption(
            label: 'Ayini başlat',
            detail: 'Köy ateş başında toplanır; huzur ve anlam köyü sarar.',
            resolution: '🕯️ Büyük Ayin başladı — köy bir huzur içinde.',
            moraleAmount: 0.10,
            moraleDays: 3,
            fx: PetitionFx.cult,
            estateMood: [(Estate.faithful, 0.10), (Estate.hearth, 0.04)],
          ),
          PetitionOption(
            label: 'Sade dua yeter',
            detail: 'Büyük ayin olmaz — inananlar biraz buruk.',
            resolution: '🕯️ Bu sefer sade bir dua ile yetinildi.',
            moraleAmount: -0.02,
            moraleDays: 1,
            estateMood: [(Estate.faithful, -0.05)],
          ),
        ],
      ),
    ),

    // 🏡 Köklü Yuva → Yuva Şöleni (herkesin katıldığı sıcak şölen).
    _PetitionDef(
      (c) => c.remembers('identity.hearth') && c.food >= 18,
      0.7,
      const Petition(
        id: 'identityHomecoming',
        petitioner: 'Köklü Yuva',
        icon: '🏡',
        title: 'Yuva Şöleni',
        tone: PetitionTone.warm,
        estate: Estate.hearth,
        note: '✦ Köyün kimliği: Köklü Yuva',
        stakes: 'Şöleni ver → köy bir aile gibi ateş başında buluşur.',
        body: 'Köy sıcak yuvasıyla anılır oldu. Yaşlılar ve aileler büyük bir '
            'yuva şöleni istiyor — herkes ateş başında toplanacak, kuşaklar '
            'bir araya gelecek, köy bir aile gibi.',
        options: [
          PetitionOption(
            label: 'Şöleni ver!',
            detail: 'Sofralar kurulur; köy bir aile gibi ateş başında buluşur.',
            resolution: '🏡 Yuva Şöleni kuruldu — köy bir aile gibi toplandı!',
            foodDelta: -5,
            moraleAmount: 0.12,
            moraleDays: 3,
            fx: PetitionFx.festival,
            estateMood: [(Estate.hearth, 0.10), (Estate.laborers, 0.04)],
          ),
          PetitionOption(
            label: 'Mütevazı kalalım',
            detail: 'Şölen olmaz — ocak biraz buruk kalır.',
            resolution: '🏡 Yuva şöleni bu sefer ertelendi.',
            moraleAmount: -0.02,
            moraleDays: 1,
            estateMood: [(Estate.hearth, -0.05)],
          ),
        ],
      ),
    ),

    // ════════════════════════════════════════════════════════════════════════
    // YASA-DUYARLI DİLEKÇELER — yürürlükteki bir yasa köyde canlı bir sosyal
    // karşılık doğurur (politika↔dilekçe köprüsü). Çıkardığın kanun unutulmaz:
    // lehine olan zümre teşekkür eder, aleyhine olan geri adım ister.
    // ════════════════════════════════════════════════════════════════════════

    // 🌱 Dönemli ekim yürürlükte → tarla bereketlenir ama "pazar payı daralır"
    // (yasanın bedeli). Zanaatkârlar yakınır, emekçiler savunur — sen tartarsın.
    _PetitionDef(
      (c) => c.cropRotation && c.adults >= 5,
      0.55,
      const Petition(
        id: 'rotationMarket',
        petitioner: 'Tezgâh esnafı',
        icon: '🌱',
        title: 'Dönemli Ekim Pazarı Daraltıyor',
        tone: PetitionTone.neutral,
        estate: Estate.artisans,
        note: '⚖ Yürürlükteki yasa: Dönemli ekim',
        stakes: 'Kanunda diren → emekçi sevinir, esnaf küser; esnek davran → tersi.',
        body: 'Dönemli ekim toprağı şenlendirdi ama tarlalar sırayla '
            'dinlendiği için pazara çıkan ürün azaldı. Zanaatkârlar tezgâhların '
            'boş kaldığından yakınıyor: "Ya takvim biraz gevşesin, ya bize bir '
            'pay ayrılsın." Emekçiler ise bereketli toprağı korumakta kararlı.',
        options: [
          PetitionOption(
            label: 'Takvimde diren',
            detail: 'Toprağın bereketi sürer; emekçiler memnun, esnaf homurdanır.',
            resolution: '🌱 Dönemli ekim aynen sürüyor — tarlalar dinlenmeye devam.',
            estateMood: [(Estate.laborers, 0.10), (Estate.hearth, 0.04), (Estate.artisans, -0.12)],
          ),
          PetitionOption(
            label: 'Esnafa pay ayır',
            detail: 'Pazara biraz altın akıtılır; esnaf rahatlar, emekçi buruk.',
            resolution: '🔨 Pazara destek verildi — esnaf rahatladı, emekçi biraz küstü.',
            goldDelta: -5,
            estateMood: [(Estate.artisans, 0.14), (Estate.laborers, -0.08)],
          ),
        ],
      ),
    ),

    // 🚪 Misafirperverlik yürürlükte + boş hane var → bir gezgin köye yerleşmek
    // istiyor. Açık kapı politikasının görünür sosyal karşılığı.
    _PetitionDef(
      (c) => c.hospitality && c.hasHousing && c.population >= 5 && c.food >= 8,
      0.6,
      const Petition(
        id: 'wandererSettles',
        petitioner: 'Yolu düşmüş bir gezgin',
        icon: '🚪',
        title: 'Bir Gezgin Yerleşmek İstiyor',
        tone: PetitionTone.warm,
        estate: Estate.artisans,
        note: '⚖ Yürürlükteki yasa: Misafirperverlik',
        stakes: 'Kabul et → köye taze el ve haber; geri çevir → kapın boşa açık kalır.',
        body: 'Açık kapı politikan duyulmuş: uzaktan gelen bir gezgin köyün '
            'sıcaklığına vurulmuş, boş bir haneye yerleşip burada kök salmak '
            'istiyor. Eli iş tutuyor, dilinde uzak diyarların haberleri var. '
            'Ama bir boğaz daha sofraya ortak olacak.',
        options: [
          PetitionOption(
            label: 'Hoş geldin, yerleş',
            detail: 'Gezgin köye katılır; taze bir el, sıcak bir karşılama.',
            resolution: '🚪 Gezgin köye yerleşti — açık kapı bir dost kazandırdı.',
            foodDelta: -3,
            moraleAmount: 0.05,
            moraleDays: 3,
            estateMood: [(Estate.artisans, 0.12), (Estate.hearth, 0.05), (Estate.laborers, -0.03)],
          ),
          PetitionOption(
            label: 'Bu sefer olmaz',
            detail: 'Gezgin yoluna devam eder; kapın açık ama sofran dar kaldı.',
            resolution: '🚪 Gezgin geri çevrildi — açık kapı bu sefer kapandı.',
            moraleAmount: -0.03,
            moraleDays: 2,
            estateMood: [(Estate.artisans, -0.08), (Estate.hearth, 0.03)],
          ),
        ],
      ),
    ),

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

    // ☀️ Yaz kuraklığı — MEVSİMSEL. Yazın işlenen tarla varken güneş ekini
    // kavurur; kuyu suyu kritik. KARAR: emek/altın harca → kurtar, ya da bırak.
    // Etki: YİYECEK + Emekçi morali. "fields.tended" iyi bakım hatırlanır.
    _PetitionDef(
      (c) => c.season == Season.summer && c.hasCrops && c.food >= 5,
      0.95,
      const Petition(
        id: 'summerDrought',
        petitioner: 'Bunalmış çiftçiler',
        icon: '☀️',
        title: 'Yaz Kuraklığı Bastırdı',
        tone: PetitionTone.ominous,
        estate: Estate.laborers,
        stakes: 'Su taşı → ekin kurtulur; bırak → güneş başakları kavurur.',
        body: 'Günlerdir damla yağmur yok. Toprak çatladı, başaklar sararmaya '
            'başladı. Çiftçiler kuyudan su taşımak için fazladan el ve biraz '
            'altın istiyor — yoksa bu yazın hasadı güneşte kavrulacak.',
        options: [
          PetitionOption(
            label: 'Su taşıyın, kanal açın',
            detail: 'Altın + emek harca; kuyudan tarlaya su taşınır, ekin kurtulur.',
            resolution: '💧 Tarlalara su yetişti — ekin kuraklığı atlattı.',
            goldDelta: -7,
            moraleAmount: 0.02,
            moraleDays: 2,
            setsFlags: ['fields.tended'],
            estateMood: [(Estate.laborers, 0.12), (Estate.artisans, -0.04)],
          ),
          PetitionOption(
            label: 'Yağmuru bekleyin',
            detail: 'Müdahale yok — güneş başakları kavurur, hasat azalır.',
            resolution: '🌾 Hasadın çoğu güneşte kavruldu — ambar dar kaldı.',
            foodDelta: -12,
            moraleAmount: -0.04,
            moraleDays: 3,
            fx: PetitionFx.cropBlight,
            setsFlags: ['fields.neglected'],
            estateMood: [(Estate.laborers, -0.14)],
          ),
        ],
      ),
    ),

    // ❄️ Kış erzak meclisi — MEVSİMSEL. Kışın tarlalar donmuşken ambar
    // konuşur. KARAR: sıkı tut (erzak korunur, köy biraz kısılır) ya da
    // bolca paylaş (moral↑ ama erzak erir). Etki: YİYECEK + moral + Ocak/Emekçi.
    _PetitionDef(
      (c) => c.season == Season.winter && c.population >= 4 && c.food >= 8,
      0.85,
      const Petition(
        id: 'winterProvisions',
        petitioner: 'Köy meclisi',
        icon: '❄️',
        title: 'Kış Erzağı Nasıl Bölüşülecek?',
        tone: PetitionTone.neutral,
        estate: Estate.hearth,
        stakes: 'Sıkı tut → erzak dayanır; bolca paylaş → köy ısınır, ambar erir.',
        body: 'Tarlalar dondu, hasat yok. Ambardaki erzak bahara kadar idare '
            'edilmeli. Meclis soruyor: kışı sıkı bir hesapla mı geçirelim, '
            'yoksa soğuk günlerde sofrayı bolca açıp köyü ısıtalım mı?',
        options: [
          PetitionOption(
            label: 'Sıkı tutun, hesaplı bölün',
            detail: 'Erzak korunur; köy biraz kısılır ama bahara güvenle çıkar.',
            resolution: '🥖 Erzak hesaplı bölündü — ambar bahara dayanacak.',
            moraleAmount: -0.02,
            moraleDays: 2,
            estateMood: [(Estate.hearth, 0.06), (Estate.laborers, 0.04)],
          ),
          PetitionOption(
            label: 'Sofrayı açın, paylaşın',
            detail: 'Erzaktan cömertçe harcanır; köy ısınır ama ambar incelir.',
            resolution: '🔥 Kış sofrası bol kuruldu — köy ısındı, ambar inceldi.',
            foodDelta: -10,
            moraleAmount: 0.06,
            moraleDays: 3,
            fx: PetitionFx.festival,
            estateMood: [(Estate.hearth, 0.08), (Estate.faithful, 0.04)],
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

    // 💍 Köy düğünü — GERÇEK bir çift yuva kurar. Random roll DEĞİL: scene_wedding
    // kur sürecini izler, çift olgunlaşınca bu dilekçeyi id ile sunar (couple'a
    // bağlı). canFire=false + weight=0 → asla rastgele/dev-random çıkmaz.
    _PetitionDef(
      (c) => false,
      0.0,
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
            fx: PetitionFx.weddingGrand,
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

    // ─── BÜYÜK KARARLAR — DÖRT zümreyi birden oynatan ağır tercihler ──────────
    // Politik dengenin doruğu: tek bir karar tüm köyü yeniden hizalar. Net
    // "doğru" yok — iki zümreyi sevindirirken diğer ikisini küstürürsün. Köyün
    // kimliğini gerçekten bu kararlar şekillendirir.

    // 🛣️ Ticaret yolu — dünyaya açıl mı, kendine mi yet? Zanaat+Emek ister,
    // İnanç+Ocak yabancıdan/yozlaşmadan ürker. Açarsan kervan zinciri başlar.
    _PetitionDef(
      (c) => c.population >= 8 &&
          !c.remembers('road.open') &&
          !c.remembers('road.closed'),
      0.6,
      const Petition(
        id: 'bigDecisionRoad',
        petitioner: 'Köy meclisi',
        icon: '🛣️',
        title: 'Dünyaya Açılalım mı?',
        tone: PetitionTone.neutral,
        stakes: 'Yolu aç → ticaret ve kervan; kapalı kal → gelenek ve huzur.',
        body: 'Köy bir yol ağzında. Tüccarlar dışarıya bir ticaret yolu açmak '
            'istiyor — kervanlar, kazanç, uzak haberler gelir. Ama yaşlılar ve '
            'inananlar tedirgin: "Yabancı yol yabancı âdet getirir, köyün ruhu '
            'bozulur." Köyün kaderini belirleyecek bir karar.',
        options: [
          PetitionOption(
            label: 'Ticaret yolunu aç',
            detail: 'Kervanlar gelir, kese dolar; ama gelenek ve huzur sarsılır.',
            resolution: '🛣️ Ticaret yolu açıldı — köy dünyaya kapısını araladı.',
            goldDelta: -4,
            setsFlags: ['road.open'],
            followUpId: 'roadCaravan',
            followUpDelayDays: 3.0,
            estateMood: [(Estate.artisans, 0.16), (Estate.laborers, 0.06), (Estate.faithful, -0.10), (Estate.hearth, -0.10)],
          ),
          PetitionOption(
            label: 'Köy kendine yetsin',
            detail: 'Kapılar kapalı kalır; gelenek korunur ama ticaret kısılır.',
            resolution: '🏡 Köy kendi içine kapandı — gelenek korundu, pazar durgun.',
            setsFlags: ['road.closed'],
            estateMood: [(Estate.hearth, 0.12), (Estate.faithful, 0.10), (Estate.artisans, -0.12), (Estate.laborers, -0.05)],
          ),
        ],
      ),
    ),

    // 🏗️ Ortak emek nereye? Değirmen (üretim) mi, sunak (mana) mı? Dört zümre
    // ikiye bölünür: Emek+Zanaat üretimi, İnanç+Ocak mabedi ister.
    _PetitionDef(
      (c) => c.population >= 7 && c.adults >= 4,
      0.5,
      const Petition(
        id: 'bigDecisionProject',
        petitioner: 'Köyün ustabaşısı',
        icon: '🏗️',
        title: 'Ortak Emek Nereye Aksın?',
        tone: PetitionTone.neutral,
        stakes: 'Değirmen → bolluk; sunak → maneviyat. İki zümre sevinir, ikisi küser.',
        body: 'Köy bu mevsim ortak bir büyük işe girişecek ama tek seçim hakkı '
            'var. Emekçiler ve zanaatkârlar bir değirmen istiyor — un, bolluk, '
            'kazanç. İnananlar ve yaşlılar ise bir sunak, köyün ruhunu '
            'kutsayacak bir mabet istiyor. Hangisi?',
        options: [
          PetitionOption(
            label: 'Değirmen kuralım',
            detail: 'Üretim ve bolluk öne geçer; maneviyat geri planda kalır.',
            resolution: '🏗️ Değirmen kuruldu — köyde bolluğun çarkı dönmeye başladı.',
            foodDelta: 6,
            estateMood: [(Estate.laborers, 0.14), (Estate.artisans, 0.10), (Estate.faithful, -0.10), (Estate.hearth, -0.06)],
          ),
          PetitionOption(
            label: 'Sunak yükseltelim',
            detail: 'Köyün ruhu kutsanır; üretim hevesi bir süre geri çekilir.',
            resolution: '🕯️ Sunak yükseldi — köyün üstüne dingin bir kutsallık indi.',
            moraleAmount: 0.06,
            moraleDays: 4,
            fx: PetitionFx.cult,
            estateMood: [(Estate.faithful, 0.14), (Estate.hearth, 0.10), (Estate.laborers, -0.10), (Estate.artisans, -0.06)],
          ),
        ],
      ),
    ),

    // 🐪 ZİNCİR: ticaret yolu açıldıysa bir kervan gelir (roadCaravan). canFire
    // false + weight 0 → yalnız bigDecisionRoad zincirinden tetiklenir.
    _PetitionDef(
      (c) => false,
      0.0,
      const Petition(
        id: 'roadCaravan',
        petitioner: 'Tozlu bir kervan',
        icon: '🐪',
        title: 'Yoldan Bir Kervan Geldi',
        tone: PetitionTone.warm,
        estate: Estate.artisans,
        note: '↩ Açtığın ticaret yolundan ilk kervan',
        stakes: 'Ağırla → kazanç ve coşku; geçir → fırsat kaçar.',
        body: 'Açtığın yoldan ilk büyük kervan köye ulaştı — develer ipek, '
            'baharat, uzak diyar haberleriyle dolu. Tüccarlar bir gece '
            'ağırlanmak, pazar kurmak istiyor. Ağırlamak biraz erzak ister ama '
            'kese dolar, köy şenlenir.',
        options: [
          PetitionOption(
            label: 'Kervanı ağırla, pazar kurulsun',
            detail: 'Biraz erzak harca; kervan kazanç ve coşku bırakır.',
            resolution: '🐪 Kervan ağırlandı — pazar kuruldu, kese doldu, köy şenlendi!',
            foodDelta: -5,
            goldDelta: 12,
            moraleAmount: 0.08,
            moraleDays: 3,
            fx: PetitionFx.festival,
            estateMood: [(Estate.artisans, 0.12), (Estate.laborers, 0.05), (Estate.hearth, 0.03)],
          ),
          PetitionOption(
            label: 'Geçip gitsinler',
            detail: 'Kervan durmadan geçer; fırsat kaçar, zanaatkârlar burulur.',
            resolution: '🐪 Kervan durmadan geçti — fırsat bu sefer kaçtı.',
            moraleAmount: -0.02,
            moraleDays: 1,
            estateMood: [(Estate.artisans, -0.08)],
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

    // 🪵 Odun azalıyor (scene_fire erken uyarı — random çıkmaz). Ateş sönmeden
    // önce oduncular durumu bildirir; oyuncu önlem alsın ya da güvensin.
    _PetitionDef(
      (_) => false,
      0,
      const Petition(
        id: 'woodLow',
        petitioner: 'Oduncular',
        icon: '🪵',
        title: 'Odun Azalıyor',
        tone: PetitionTone.ominous,
        estate: Estate.laborers,
        stakes: 'Önlem al → tampon odun; güven → bedava ama ateş riske girer.',
        body: 'Oduncular haber saldı: odun stoğu tükenmek üzere. Ateş sönmeden '
            'bir şeyler yapmazsak köy karanlıkta kalabilir. Komşudan acil odun '
            'mı getirtelim, yoksa oduncuların yetiştireceğine mi güvenelim?',
        options: [
          PetitionOption(
            label: 'Komşudan odun getirt',
            detail: 'Altın harca; stok hemen güvenli seviyeye çıkar.',
            resolution: '🪵 Komşudan odun geldi — stok rahatladı, ateş güvende.',
            goldDelta: -6,
            woodDelta: 8,
            estateMood: [(Estate.laborers, 0.05)],
          ),
          PetitionOption(
            label: 'Oduncular yetiştirir',
            detail: 'Masraf yok; oduncuların emeğine güvenirsin (ateş riskte).',
            resolution: '🪓 Oduncular işe koyuldu — köy onlara güveniyor.',
            estateMood: [(Estate.laborers, 0.06)],
          ),
        ],
      ),
    ),

    // 🔥 Ateş söndü (scene_fire programatik tetikler — random çıkmaz). Köy odun
    // bekliyor: acil seferberlik (altın→odun) ya da oduncuları bekle.
    _PetitionDef(
      (_) => false,
      0,
      const Petition(
        id: 'fireDied',
        petitioner: 'Üşüyen köy',
        icon: '🔥',
        title: 'Ateş Söndü',
        tone: PetitionTone.ominous,
        estate: Estate.hearth,
        stakes: 'Acil odun al → ateş hemen yanar; bekle → oduncular yetişsin.',
        body: 'Ocak söndü, köy karanlıkta ve soğukta kaldı. Odun stoğu tükenmiş. '
            'Komşu köyden acil odun getirtelim mi, yoksa oduncuların yeni odun '
            'çıkarmasını mı bekleyelim?',
        options: [
          PetitionOption(
            label: 'Acil odun getirt',
            detail: 'Altın harca; hemen odun gelir, ateşçi ocağı yeniden yakar.',
            resolution: '🪵 Acil odun getirtildi — ateşçi ocağı yeniden yakıyor.',
            goldDelta: -10,
            woodDelta: 8,
            estateMood: [(Estate.hearth, 0.06)],
          ),
          PetitionOption(
            label: 'Oduncuları bekle',
            detail: 'Masraf yok; ateş, yeni odun çıkana dek sönük kalır.',
            resolution: '🪵 Köy oduncuları bekliyor — ocak şimdilik sönük.',
            moraleAmount: -0.03,
            moraleDays: 2,
            estateMood: [(Estate.hearth, -0.05)],
          ),
        ],
      ),
    ),

    // ════════════════════════════════════════════════════════════════════════
    // SÜRÜ DİLEKÇELERİ — hayvancılık yönetişimi. Yem sıkıntısı + hayvan hastalığı.
    // Cozy/no-fail: çözmek küçük bir maliyet, ertelemek yalnızca Emekçileri biraz
    // küstürür; hayvanlar dilekçe yüzünden ölmez (doğal ölüm ayrı, cezasız).
    // ════════════════════════════════════════════════════════════════════════

    // 🌾 Sürü aç — ahıra kışlık yem istenir.
    _PetitionDef(
      (c) => c.herdHungry && c.herdSize >= 2,
      1.1,
      const Petition(
        id: 'herdFodder',
        petitioner: 'Çoban',
        icon: '🌾',
        title: 'Sürü Yem İstiyor',
        tone: PetitionTone.ominous,
        estate: Estate.laborers,
        stakes: 'Yem ayır → tok, verimli sürü; ertele → zayıf hayvan, küskün çoban.',
        body: 'Çoban kaygılı: otlaklar yetmiyor, hayvanlar zayıf düşüyor. '
            'Ahıra bir miktar kışlık yem ayrılırsa sürü toparlanır, sütü '
            'bereketlenir. Yoksa verim düşecek.',
        options: [
          PetitionOption(
            label: 'Yem ayır',
            detail: 'Sofradan bir pay ahıra gider; sürü toparlanır, çoban rahatlar.',
            resolution: '🌾 Ahır yemle doldu — sürü toparlanıyor.',
            foodDelta: -6,
            moraleAmount: 0.03,
            moraleDays: 2,
            estateMood: [(Estate.laborers, 0.16), (Estate.hearth, -0.03)],
          ),
          PetitionOption(
            label: 'Otlağa güven',
            detail: 'Masraf yok; sürü zayıf kalır, çoban küser.',
            resolution: '🌾 Yem ayrılmadı — sürü cılız, çoban suskun.',
            moraleAmount: -0.02,
            moraleDays: 2,
            estateMood: [(Estate.laborers, -0.09)],
          ),
        ],
      ),
    ),

    // 🐄 Hayvan hastalığı — sürüye bakım/şifa istenir.
    _PetitionDef(
      (c) => c.herdSize >= 3,
      0.5,
      const Petition(
        id: 'herdAilment',
        petitioner: 'Çoban',
        icon: '🐄',
        title: 'Sürüde Hastalık Belirtisi',
        tone: PetitionTone.ominous,
        estate: Estate.laborers,
        stakes: 'Şifacı çağır → sürü iyileşir; bekle → moral düşer, çoban tedirgin.',
        body: 'Çoban birkaç hayvanın halsizleştiğini fark etti. Bir şifacı '
            'çağrılır, otlar kaynatılır ve ahır temizlenirse hastalık yayılmadan '
            'durur. Beklemek riskli.',
        options: [
          PetitionOption(
            label: 'Şifacı çağır',
            detail: 'Biraz altın harca; sürü bakılır, hastalık durur.',
            resolution: '🐄 Şifacı geldi — sürü toparlandı, ahır şenlendi.',
            goldDelta: -5,
            moraleAmount: 0.03,
            moraleDays: 2,
            estateMood: [(Estate.laborers, 0.14)],
          ),
          PetitionOption(
            label: 'Kendi geçer',
            detail: 'Masraf yok; köy tedirgin bekler, çoban kaygılanır.',
            resolution: '🐄 Köy bekledi — sürünün üstüne bir tedirginlik çöktü.',
            moraleAmount: -0.03,
            moraleDays: 2,
            estateMood: [(Estate.laborers, -0.08), (Estate.hearth, -0.03)],
          ),
        ],
      ),
    ),

  ];
}
