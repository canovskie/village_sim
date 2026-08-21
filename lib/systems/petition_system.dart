import 'dart:math';
import '../text/voice.dart';
import '../world/season.dart';
import 'estate_system.dart';
import 'law_compass.dart';

part 'petition_catalog.dart';
part 'petition_catalog_core.dart';
part 'petition_catalog_estates.dart';
part 'petition_catalog_law.dart';
part 'petition_catalog_factions.dart';
part 'petition_catalog_chains.dart';
part 'petition_catalog_herd.dart';
part 'petition_catalog_mature.dart';
part 'petition_catalog_trees.dart';

/// Dilekçeye bağlı görsel/anlık tepki — sahne bunu somut animasyona çevirir
/// (sadece istatistik değil: köy gözle görülür biçimde tepki verir).
enum PetitionFx {
  none,
  festival, // BESPOKE: flama+konfeti+fener + köylüler ateşe toplanıp dans
  cropBlight, // BESPOKE: tarlalarda yayılan mantar + ürün çürür (farm growth ↓)
  vigil, // BESPOKE: bir köylü kaybı + mum töreni (köy toplanır, matem)
  mourn, // bir köylü kaybı + sessiz uğurlama (animasyon yok, moral ↓↓)
  cult, // BESPOKE: ayin çemberi + köylüler toplanır (yeni inanç)
  templeRaised, // BESPOKE: köyün ortasına GERÇEK bir mabet dikilir + ayin çemberi
  remembrance, // BESPOKE: anma günü — köy toplanır + mum töreni (KİMSE ölmez)
  wedding, // BESPOKE: sade düğün — gerçek çift ateş başında, kalp/yaprak yağmuru
  weddingGrand, // BESPOKE: coşkulu düğün — önce tam ekran 2B sinematik, sonra alay/şenlik
  harvestBounty, // BESPOKE: tarlalar altın ışıltıyla olgunlaşır + bereket zerresi yükselir
  callingGranted, // BESPOKE: dilekçe sahibi mesleğini bırakıp çağrısının peşinden gider
  feudPeace, // BESPOKE: iki aile barışır — kan davası sona erer (husumet silinir)
  feudExile, // BESPOKE: kan davasının suçlusu köyden sürülür → husumet kapanır
  feudExecute, // BESPOKE: suçlu 2B sahnede idam edilir → kan davası kanla kapanır
  // ── SUÇ hükümleri (scene_crime) ───────────────────────────────────────────
  crimePardon, // BESPOKE: suçüstü yakalanan fail bağışlanır (merhametin bedeli var)
  crimePunish, // BESPOKE: fail meydanda teşhir edilir — köy düzeni görür
  crimeExile, // BESPOKE: fail köyden sürülür
  crimeExecute, // BESPOKE: fail halkın önünde idam edilir
  crimeLabor, // BESPOKE (NİZAM): mahkûm sürülmez, taş ocağına koşulur (kürek cezası)
  crimePenance, // BESPOKE (DERGÂH): fail meydanda günahını söyler, ceza yerine utanç
  crimeWatch, // asayiş kararı — şüphe defteri kapanır (gece nöbeti/kayıtsızlık)
  ransomPaid, // BESPOKE: fidye ödenir, kaçırılan köylü köye döner
  ransomRefused, // BESPOKE: fidye reddedilir, rehin bir daha dönmez
  // ── HANE KARŞILIĞI (scene_house_stance) ───────────────────────────────────
  // Esirgeyen haneyi iki yoldan biriyle çözersin: GÖNLÜNÜ alırsın (hâl yükselir,
  // merdivenden iner) ya da BELİNİ kırarsın (nüfuz düşer, esirgeyecek kozu
  // kalmaz). İkisi de işe yarar; bedelleri farklıdır.
  houseAppeased, // hanenin gönlü alınır — esirgeme çözülür, ambarını açar
  houseRebuked, // hanenin nüfuzu kırılır — küskün kalır ama kozu kalmaz
}

/// Dilekçenin duygu tonu — modal/mühür vurgu rengini ve havasını belirler.
/// UI bağlamı: oyuncu daha açmadan kararın ağırlığını sezsin (sıcak mı, kara mı).
enum PetitionTone {
  warm, // kutlama/şefkat — sage/ember sıcaklığı
  solemn, // hüzün/anma — soluk, ağırbaşlı
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

  /// Köye duyurulacak çözüm metni — VARYANT HAVUZU. Sunum anında seed'e göre
  /// biri seçilir ve bağlamla dokunur (bkz. [Petition.spoken]).
  final List<String> resolutionPool;

  /// Seçili çözüm metni. Ham tanımda havuzun ilki; [Petition.spoken] sonrası
  /// havuz tek elemana indiği için bu, o köye özel dokunmuş cümledir.
  String get resolution => resolutionPool.isEmpty ? '' : resolutionPool.first;

  /// VAKANÜVİS satırı — bu şıkkın köyün güncesine düşen kalıcı izi. Havuzdur:
  /// aynı karar ikinci kez verilince yıllık aynı kelimeleri kullanmasın.
  ///
  /// Neden ayrı bir alan: [resolution] bir BİLDİRİM (uçar, birkaç saniye durur),
  /// bu ise KAYIT. Üslup da farklı — çözüm metni köye seslenir, annal kâtibin
  /// kuru cümlesidir: ne istendi, ne verildi. Boş bırakılırsa sahne yine de bir
  /// satır yazar ("Başlık: Şık") — yani hiçbir karar kayıtsız kalmaz, yalnız
  /// yazılmamış olanın cümlesi cılız durur.
  final List<String> annalPool;

  /// Seçili annal metni ([spoken] sonrası havuz tek elemana iner).
  String get annal => annalPool.isEmpty ? '' : annalPool.first;

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
    required this.resolutionPool,
    this.annalPool = const <String>[],
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

  /// Bu seçeneğin metinlerini bağlamla doldurur (bkz. [Petition.spoken]).
  PetitionOption spoken(VoiceCtx c) => PetitionOption(
    label: Voice.weave(label, c),
    detail: Voice.weave(detail, c),
    resolutionPool: [Voice.say(resolutionPool, c)],
    // Annal da bağlamla dokunur ama KENDİ tohumundan varyant seçer: çözüm
    // metniyle aynı kalıba düşüp cümleyi ikizlemesin.
    annalPool: annalPool.isEmpty
        ? const <String>[]
        : [Voice.say(annalPool, c.copyWith(seed: c.seed + 7717))],
    foodDelta: foodDelta,
    woodDelta: woodDelta,
    stoneDelta: stoneDelta,
    ironDelta: ironDelta,
    goldDelta: goldDelta,
    moraleAmount: moraleAmount,
    moraleDays: moraleDays,
    fx: fx,
    followUpId: followUpId,
    followUpDelayDays: followUpDelayDays,
    setsFlags: setsFlags,
    clearsFlags: clearsFlags,
    estateMood: estateMood,
  );

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

  /// Dilekçe gövdesi — VARYANT HAVUZU. Köylü kendi ağzından konuşur; aynı
  /// dilekçe ikinci kez geldiğinde başka kelimelerle okunsun diye havuzdur.
  /// İçinde `{ad}`, `{ad-in}`, `{meslek}`, `{hane}` yer tutucuları geçebilir.
  final List<String> bodyPool;

  /// Seçili gövde metni ([spoken] sonrası: bu köye, bu köylüye dokunmuş hâli).
  String get body => bodyPool.isEmpty ? '' : bodyPool.first;

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
    required this.bodyPool,
    required this.options,
    this.note,
    this.stakes,
    this.tone = PetitionTone.neutral,
    this.estate,
  });

  /// Aynı dilekçe, sonuna eklenmiş bir seçenekle. Yürürlükteki bir yasa yargıya
  /// yeni bir hüküm açtığında (ör. NİZAM'ın Kürek Cezası) kullanılır — sabit
  /// dilekçeyi kopyalamadan bir şık daha ekler. [spoken]'dan ÖNCE çağrılmalı ki
  /// eklenen seçenek de bağlamla dokunsun.
  Petition withExtraOption(PetitionOption extra) => Petition(
    id: id,
    petitioner: petitioner,
    icon: icon,
    title: title,
    bodyPool: bodyPool,
    options: [...options, extra],
    note: note,
    stakes: stakes,
    tone: tone,
    estate: estate,
  );

  /// Aynı dilekçe, belirli bir etkiye sahip seçenekler çıkarılmış hâli. Bir
  /// hüküm ancak fermanı mühürlüyse verilebiliyorsa ([PetitionFx.crimeExile] ↔
  /// Sürgün Fermanı) sabit dilekçeyi kopyalamadan o şık kaldırılır.
  ///
  /// Son seçeneği asla düşürmez: seçeneksiz dilekçe oyuncuyu kilitler.
  Petition without(Set<PetitionFx> drop) {
    final kept = [
      for (final o in options)
        if (!drop.contains(o.fx)) o,
    ];
    if (kept.isEmpty || kept.length == options.length) return this;
    return Petition(
      id: id,
      petitioner: petitioner,
      icon: icon,
      title: title,
      bodyPool: bodyPool,
      options: kept,
      note: note,
      stakes: stakes,
      tone: tone,
      estate: estate,
    );
  }

  /// Dilekçeyi KONUŞTURUR: her havuzdan bir varyant seçer ve içindeki yer
  /// tutucuları köyün o anki gerçekleriyle (sözcünün adı/mesleği/hanesi,
  /// mevsim, gün) doldurur. Sonuç: metinleri artık sabit, sunuma hazır bir
  /// kopya — UI'nin gördüğü tek şey bu.
  ///
  /// Sunum anında BİR KEZ çağrılır; böylece oyuncu modalı kapatıp yeniden
  /// açtığında metin değişmez ve kayıt/yükleme sonrası da aynı kalır.
  Petition spoken(VoiceCtx c) => Petition(
    id: id,
    petitioner: Voice.weave(petitioner, c),
    icon: icon,
    title: Voice.weave(title, c),
    bodyPool: [Voice.say(bodyPool, c)],
    note: note == null ? null : Voice.weave(note!, c),
    stakes: stakes == null ? null : Voice.weave(stakes!, c),
    tone: tone,
    estate: estate,
    // Seçeneklerin çözüm metinleri de aynı bağlamdan beslenir; her seçenek
    // kendi tohumuyla seçsin ki dört şık aynı kalıba düşmesin.
    options: [
      for (var i = 0; i < options.length; i++)
        options[i].spoken(c.copyWith(seed: c.seed + 101 * (i + 1))),
    ],
  );
}

/// Kuruluşun ilk kaynak krizi oyuncuya karar vermeyi öğretir. Normal dilekçe
/// gibi mühürde bekleyip rejim/meclis tarafından çözülemez; hüküm oyuncunundur.
bool petitionRequiresPlayerVerdict(String petitionId, int charterTier) =>
    petitionId == 'woodLow' && charterTier == 0;

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

  /// ŞU AN bir şey ESİRGEYEN hanenin soyadı (en sert olanı) — hane karşılığı
  /// dilekçesinin kapısı. null = her hane veriyor (bkz. house_stance).
  final String? withholdingHouse;

  /// MEÇHUL kalan suçların biriktirdiği şüphe (scene_crime) — asayiş
  /// dilekçesinin kapısı. Faili yakalanan suç şüphe biriktirmez.
  final int crimeSuspicion;

  // ── Aktif yasalar (politika↔dilekçe köprüsü) ───────────────────────────────
  // Yürürlükteki bir yasa köyde sosyal bir karşılık doğurabilir: lehte olan
  // zümre teşekkür/şölen ister, aleyhte olan zümre geri adım talep eder.
  /// Dönemli ekim yürürlükte mi — çiftçi takvim şöleni dilekçesinin kapısı.
  final bool cropRotation;

  /// Misafirperverlik yürürlükte mi — gezgin yerleşme dilekçesinin kapısı.
  final bool hospitality;

  /// Köyde boş yatak (yerleşilecek hane) var mı — yerleşme dilekçesinin kapısı.
  final bool hasHousing;

  // ── OLGUNLUK (geç oyun kapıları) ───────────────────────────────────────────
  // Bu alanlar eklenene dek katalogdaki EN YÜKSEK kapı `nüfus >= 8` idi: köy 8
  // cana ulaştığı an oyunun sorabileceği her şey havuzdaydı ve onuncu saatte de
  // aynı sorular dönüyordu. Dilekçe sistemi köyün YAŞLANDIĞINI göremiyordu.
  // Aşağıdakiler o körlüğü kapatır — hepsi zaten sahnede duran, kullanılmayan
  // veriler.

  /// Kaçıncı gün — köyün yaşı. Kuşak/eskime dilekçelerinin kapısı.
  final int dayCount;

  /// Kurucu kuşaktan yaşayan kimse kaldı mı. false = köy artık kendi
  /// hatırlamadığı bir başlangıcın üstünde yaşıyor.
  final bool foundersAlive;

  /// Köydeki hane (soy) sayısı ve en güçlü hanenin nüfuzu 0..1. Tek hane
  /// köyü domine ettiğinde bunun sosyal bir karşılığı olmalı.
  final int houseCount;
  final double dominantSway;

  /// Kanunname ne kadar kalın — mühürlenmiş ferman sayısı.
  final int sealedLaws;

  /// Köyün rejim kimliği ve huzursuzluğu. Sertleşen rejim itiraz, yumuşayan
  /// rejim cesaret doğurur.
  final VillageRegime regime;
  final double unrest;

  /// Bir zamanlar bilinip KAYBEDİLMİŞ zanaat var mı (son usta çırak
  /// bırakmadan öldü). Köyün unuttuğu şeyin dilekçesi.
  final bool craftLost;

  /// İmparatorluk köye kaç kez uğradı — dışarıyla ilişkinin geçmişi.
  final int imperialVisits;

  /// Yönetişim mirası −0.12..+0.12 — geçmiş kararların sönmeyen izi.
  final double governanceLegacy;

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
    this.withholdingHouse,
    this.crimeSuspicion = 0,
    this.cropRotation = false,
    this.hospitality = false,
    this.hasHousing = false,
    this.dayCount = 0,
    this.foundersAlive = true,
    this.houseCount = 1,
    this.dominantSway = 0,
    this.sealedLaws = 0,
    this.regime = VillageRegime.moderate,
    this.unrest = 0,
    this.craftLost = false,
    this.imperialVisits = 0,
    this.governanceLegacy = 0,
  });

  /// Köyün kaç yıllık olduğu (1 yıl = 4 mevsim). Metinlerde ve kapılarda
  /// gün sayısından daha okunur bir ölçü.
  int get years => dayCount ~/ (kDaysPerSeason * 4);

  /// Köy "olgun" mu — geç oyun dilekçelerinin ortak alt kapısı. Tek bir eşik
  /// yerine üç ayrı olgunlaşma işaretinden herhangi ikisi: yaş, kalabalık,
  /// yazılı düzen. Böylece hızlı büyüyen köy de, yavaş yaşayan köy de aynı
  /// noktaya kendi yolundan varır.
  bool get mature {
    var marks = 0;
    if (years >= 2) marks++;
    if (population >= 14) marks++;
    if (sealedLaws >= 3) marks++;
    return marks >= 2;
  }

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
  static Petition? roll(
    PetitionContext ctx,
    Random rng, {
    Set<String> blocked = const {},
  }) {
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
    final rollable = _defs.where((d) => d.weight > 0).toList(growable: false);
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

  /// Test kancası: metin gövdesinin tamamı (havuzlar ham hâliyle) — prose
  /// testi her dilekçeyi konuşturup ham yer tutucu kalmadığını doğrular.
  static List<Petition> get allForTest => [for (final d in _defs) d.petition];

  /// Test kancası: dilekçenin KAPISI ve ağırlığı. Bütünlük testi yalnız
  /// dilekçenin kendisine bakamaz — "bu dilekçe hiçbir köyde tetiklenmiyor"
  /// ve "bu takip halkası hiçbir şıktan çağrılmıyor" hataları ancak kapı
  /// görünürse yakalanır.
  static List<
    ({double weight, bool Function(PetitionContext) canFire, Petition petition})
  >
  get gatesForTest => [
    for (final d in _defs)
      (weight: d.weight, canFire: d.canFire, petition: d.petition),
  ];

  /// Dilekçe KATALOĞU ayrı dosyada (petition_catalog.dart) — motor ile
  /// içerik aynı dosyada durunca ikisi de okunmaz oluyordu.
  static final List<_PetitionDef> _defs = _kPetitionDefs;
}
