/// SUÇ — köyde nadiren işlenen, gözle görülür, faile bağlı yasadışı eylemler.
///
/// Tasarım sözleşmesi (bkz. [[feedback_event_animation]], [[project_conflicts]]):
///  - Suç bir İSTATİSTİK DEĞİL, sahnede yaşanan bir andır: fail sinsice hedefe
///    sokulur (çömelmiş prowl), eylemi yapar, kaçar. Baş üstü "suçlu" ikonu yok;
///    yalnız kısa bir aksan baloncuğu + gövde dili.
///  - "Dikkat çekmesin ama görünsün": suç ANINDA faili İSİMLE ifşa eden bildirim
///    YOK. Köy yalnızca bir kıpırtı sezer ([hintPool] — yer söyler, isim söylemez).
///    Faili bulmak oyuncunun işi: suçüstü yakalamak için üstüne dokunacak.
///  - Yakalanmazsa fail meçhul kalır (sonradan "aslında oymuş" ifşası YOK);
///    yalnızca köyde şüphe birikir → asayiş dilekçesi gelir.
///  - AĞIR suçlar (kundakçılık/yaralama/adam kaçırma/suikast) rastgele çıkmaz;
///    bir SEBEBE bağlıdır (kan davası, kin, sefalet, dip moral). Hafif suçlar
///    (hırsızlık/yankesicilik/vandalizm/kaçak av/dolandırıcılık/iftira) daha
///    serbesttir ama yine yoksunluk/mutsuzluk besler.
///  - Taciz/tecavüz TANIM DIŞI — bu havuzda yoktur, eklenmeyecektir.
library;

/// Suçun ağırlığı — hafif suç serbest doğar, ağır suç SEBEP ister.
enum CrimeSeverity { petty, grave }

/// Köyde işlenebilen 10 suç.
enum CrimeKind {
  // ── Hafif (gündelik) ──────────────────────────────────────────────────────
  theft,        // Hırsızlık — ambardan/depodan mal aşırma
  pickpocket,   // Yankesicilik — bir köylünün kesesini kesme
  vandalism,    // Vandalizm — bir binaya zarar verme (tamir odun yer)
  poaching,     // Kaçak avlanma — sürüden hayvan çalma/kesme
  fraud,        // Dolandırıcılık — tartıda hile, köyün kesesinden altın aşırma
  slander,      // İftira — bir köylünün adını lekeleme (küslük + hane hâli ↓)
  // ── Ağır (sebebe bağlı) ───────────────────────────────────────────────────
  arson,        // Kundakçılık — bina ateşe verilir
  assault,      // Yaralama — kurban ağır yaralanır/sakat kalır
  abduction,    // Adam kaçırma — kurban köyden götürülür (fidye)
  assassination,// Suikast — kurban öldürülür (kan davası doğurabilir)
}

/// Bir suç türünün tanımı: kimliği, ağırlığı ve köyün ağzından metin havuzları.
///
/// Havuz sözleşmesi ([[project_voice_system]]): tek string YAZMA — her metin bir
/// varyant havuzudur, seed'e göre biri seçilir ve Türkçe ek motoruyla dokunur.
/// Yer tutucular: `{ad}` fail, `{öteki}` kurban, `{yer}` olay yeri, `{köy}`.
class CrimeDef {
  final CrimeKind kind;
  /// Suçun adı — dilekçe/kronik içinde geçer ("hırsızlık").
  final String label;
  /// Aksan baloncuğu ikonu (eylem anında failin üstünde kısa görünür).
  final String icon;
  final CrimeSeverity severity;
  /// Havuz içi göreli ağırlık (aynı ağırlık sınıfı içinde).
  final double weight;
  /// Eylemin hedefte sürdüğü süre (sn) — oyuncunun suçüstü yakalama penceresi.
  final double actSeconds;

  /// KÖYÜN SEZGİSİ — suç başlarken çıkan, FAİLİ İSİMLENDİRMEYEN ipucu. Yalnız
  /// yeri söyler; oyuncu bakıp faili kendi bulur. `{yer}` doldurulur.
  final List<String> hintPool;
  /// Suç tamamlandı, fail kaçtı (yakalanmadı) — köy zararı fark eder.
  final List<String> deedPool;
  /// Kronik (fail meçhul) — kuru vakanüvis dili, isim YOK.
  final List<String> annalPool;
  /// Kronik (fail suçüstü yakalandı) — `{ad}` fail.
  final List<String> caughtAnnalPool;

  const CrimeDef({
    required this.kind,
    required this.label,
    required this.icon,
    required this.severity,
    required this.weight,
    required this.actSeconds,
    required this.hintPool,
    required this.deedPool,
    required this.annalPool,
    required this.caughtAnnalPool,
  });

  bool get isGrave => severity == CrimeSeverity.grave;
}

abstract final class CrimeSystem {
  static const Map<CrimeKind, CrimeDef> defs = {
    // ════════════════════════════════════════════════════════════════════════
    // HAFİF SUÇLAR — yoksunluk/mutsuzluk besler, sebep şartı yok
    // ════════════════════════════════════════════════════════════════════════

    CrimeKind.theft: CrimeDef(
      kind: CrimeKind.theft,
      label: 'hırsızlık',
      icon: '🪙',
      severity: CrimeSeverity.petty,
      weight: 1.6,
      actSeconds: 5.0,
      hintPool: [
        '🌑 {yer} tarafında bir gölge kıpırdadı.',
        '🌑 {yer} kapısı aralık kaldı. Kimse açtığını söylemiyor.',
        '🌑 {yer} çevresinde birinin işi yokken işi var.',
      ],
      deedPool: [
        '🪙 {yer} eksildi. Kimse kimseyi görmedi.',
        '🪙 Sabah sayım tutmadı: {yer} soyulmuş.',
        '🪙 {yer} açık, yükü yarım. Fail meçhul.',
      ],
      annalPool: [
        'Ambardan mal eksildi; fail bulunamadı.',
        'Bir gece deponun yükü azaldı. Kimse görmedi.',
        'Köy hırsızlığa uğradı, kimsenin adı geçmedi.',
      ],
      caughtAnnalPool: [
        '{ad} ambardan çalarken yakalandı.',
        '{ad-in} eli köyün malına uzandı; suçüstü tutuldu.',
        'Hırsız çıktı: {ad}.',
      ],
    ),

    CrimeKind.pickpocket: CrimeDef(
      kind: CrimeKind.pickpocket,
      label: 'yankesicilik',
      icon: '👛',
      severity: CrimeSeverity.petty,
      weight: 1.3,
      actSeconds: 4.0,
      hintPool: [
        '🌑 {yer} kalabalığında biri fazla yaklaşıyor.',
        '🌑 {yer} tarafında omuzlar sürtündü, bir el fazlaydı.',
        '🌑 {yer} çevresinde bir el, sahibinden hızlı.',
      ],
      deedPool: [
        '👛 {öteki-in} kesesi kesilmiş. Kimi göreceğini bilmiyor.',
        '👛 {öteki} cebini yokladı, boştu.',
        '👛 {öteki-in} parası gitti; yüzünü göremedi.',
      ],
      annalPool: [
        'Meydanda bir kese kesildi; fail bulunamadı.',
        'Bir köylünün parası çalındı, kimse görmedi.',
        'Yankesici köyde dolaştı, eli boş dönmedi.',
      ],
      caughtAnnalPool: [
        '{ad} yankesicilik yaparken yakalandı.',
        '{ad-in} eli {öteki-in} kesesindeydi; suçüstü tutuldu.',
        'Kese kesen {ad} çıktı.',
      ],
    ),

    CrimeKind.vandalism: CrimeDef(
      kind: CrimeKind.vandalism,
      label: 'vandalizm',
      icon: '🪓',
      severity: CrimeSeverity.petty,
      weight: 1.1,
      actSeconds: 5.0,
      hintPool: [
        '🌑 {yer} tarafından tahta çatırtısı geliyor.',
        '🌑 {yer} duvarında bir tıkırtı var, iş sesi değil.',
        '🌑 {yer} çevresinde biri öfkeyle bir şey deviriyor.',
      ],
      deedPool: [
        '🪓 {yer} kırılmış. Tamiri odun yedi.',
        '🪓 Sabah {yer} kapısı parçalanmış bulundu.',
        '🪓 Biri {yer} tahtalarını kırmış; kimse görmemiş.',
      ],
      annalPool: [
        'Bir bina kırıldı; tamiri köyün sırtına kaldı.',
        'Gece biri köyün malına zarar verdi, adı bilinmiyor.',
        'Vandalizm: kimse görmedi, herkes ödedi.',
      ],
      caughtAnnalPool: [
        '{ad} köyün malını kırarken yakalandı.',
        '{ad-in} baltası köyün duvarına indi; suçüstü tutuldu.',
        'Kıran el {ad-in} eliymiş.',
      ],
    ),

    CrimeKind.poaching: CrimeDef(
      kind: CrimeKind.poaching,
      label: 'kaçak avlanma',
      icon: '🐑',
      severity: CrimeSeverity.petty,
      weight: 1.0,
      actSeconds: 6.0,
      hintPool: [
        '🌑 {yer} tarafında sürü ürktü. Çoban orada değil.',
        '🌑 {yer} çevresinde hayvanlar huysuzlandı.',
        '🌑 {yer} yakınında biri sürüye fazla sokuluyor.',
      ],
      deedPool: [
        '🐑 Sürüden bir hayvan eksik. Kimse ses etmiyor.',
        '🐑 Ağılın sayımı tutmadı; bir can gitmiş.',
        '🐑 Sürüden birini almışlar. Fail meçhul.',
      ],
      annalPool: [
        'Sürüden bir hayvan çalındı; fail bulunamadı.',
        'Kaçak av: köyün sürüsü bir can eksildi.',
        'Ağıl soyuldu, kimsenin adı geçmedi.',
      ],
      caughtAnnalPool: [
        '{ad} sürüden hayvan çalarken yakalandı.',
        '{ad} ağıla girerken suçüstü tutuldu.',
        'Kaçak avcı {ad} çıktı.',
      ],
    ),

    CrimeKind.fraud: CrimeDef(
      kind: CrimeKind.fraud,
      label: 'dolandırıcılık',
      icon: '⚖️',
      severity: CrimeSeverity.petty,
      weight: 0.9,
      actSeconds: 5.0,
      hintPool: [
        '🌑 {yer} tarafında bir tartı fazla hızlı dönüyor.',
        '🌑 {yer} çevresinde hesap iki kere yazılıyor.',
        '🌑 {yer} tezgâhında biri defteri kendine göre tutuyor.',
      ],
      deedPool: [
        '⚖️ Köyün kesesi eksik çıktı. Hesap tutmuyor.',
        '⚖️ Tartıda hile yapılmış; altın buhar oldu.',
        '⚖️ Defter şişirilmiş. Parayı kimin aldığı belli değil.',
      ],
      annalPool: [
        'Köyün hesabından altın eksildi; fail bulunamadı.',
        'Tartıda hile yapıldı, kimse itiraf etmedi.',
        'Dolandırıcılık: defter yalan söyledi.',
      ],
      caughtAnnalPool: [
        '{ad} tartıda hile yaparken yakalandı.',
        '{ad-in} defteri yalan çıktı; suçüstü tutuldu.',
        'Köyü dolandıran {ad} çıktı.',
      ],
    ),

    CrimeKind.slander: CrimeDef(
      kind: CrimeKind.slander,
      label: 'iftira',
      icon: '🗣️',
      severity: CrimeSeverity.petty,
      weight: 1.0,
      actSeconds: 5.0,
      hintPool: [
        '🌑 {yer} tarafında fısıltı dolaşıyor, sahibi belli değil.',
        '🌑 {yer} çevresinde bir söz kulaktan kulağa geziyor.',
        '🌑 {yer} başında birileri birinin arkasından konuşuyor.',
      ],
      deedPool: [
        '🗣️ {öteki} hakkında asılsız bir söz yayıldı. Köy yutar gibi oldu.',
        '🗣️ {öteki-in} adına leke sürüldü; kimin sürdüğü belli değil.',
        '🗣️ {öteki} bugün başını kaldıramadı. Söylenti tuttu.',
      ],
      annalPool: [
        'Bir köylünün adına iftira atıldı; atan bulunamadı.',
        'Söylenti dolaştı, bir hane yüzü yere baktı.',
        'İftira: kimse çıkıp "ben dedim" demedi.',
      ],
      caughtAnnalPool: [
        '{ad} iftira atarken yakalandı.',
        '{ad-in} yaydığı söz yalan çıktı; {öteki} aklandı.',
        'İftirayı atan {ad}\'mış.',
      ],
    ),

    // ════════════════════════════════════════════════════════════════════════
    // AĞIR SUÇLAR — SEBEP ister (kan davası / kin / sefalet / dip moral)
    // ════════════════════════════════════════════════════════════════════════

    CrimeKind.arson: CrimeDef(
      kind: CrimeKind.arson,
      label: 'kundakçılık',
      icon: '🔥',
      severity: CrimeSeverity.grave,
      weight: 1.0,
      actSeconds: 6.0,
      hintPool: [
        '🌒 {yer} tarafında yanık kokusu var, ocak yanmıyor.',
        '🌒 {yer} çevresinde biri elinde meşaleyle dolanıyor.',
        '🌒 {yer} duvarına bir gölge fazla yaklaştı.',
      ],
      deedPool: [
        '🔥 {yer} tutuştu! Ateşi biri koydu, kimse görmedi.',
        '🔥 Alevler {yer} sardı. Ocaktan çıkmadı bu.',
        '🔥 {yer} yanıyor — bu yangın kendiliğinden çıkmadı.',
      ],
      annalPool: [
        'Bir bina kundaklandı; fail bulunamadı.',
        'Köy yangınla uyandı. Ateşi koyanın adı bilinmiyor.',
        'Kundakçılık: alev köyün malını yedi, suçlu gölgede kaldı.',
      ],
      caughtAnnalPool: [
        '{ad} binayı ateşe verirken yakalandı.',
        '{ad-in} elinde meşaleyle tutuldu; yangın büyümeden söndü.',
        'Kundakçı {ad} çıktı.',
      ],
    ),

    CrimeKind.assault: CrimeDef(
      kind: CrimeKind.assault,
      label: 'yaralama',
      icon: '🔪',
      severity: CrimeSeverity.grave,
      weight: 1.2,
      actSeconds: 4.0,
      hintPool: [
        '🌒 {yer} tarafında biri birini köşeye sıkıştırıyor.',
        '🌒 {yer} çevresinde bir el belindeki demire gitti.',
        '🌒 {yer} arkasında iki gölge fazla yakın.',
      ],
      deedPool: [
        '🔪 {öteki} kanlar içinde bulundu. Vuranı göremedi.',
        '🔪 {öteki-i} arkadan vurmuşlar; ayağa kalkamıyor.',
        '🔪 {öteki} ağır yaralı. Fail karanlıkta kayboldu.',
      ],
      annalPool: [
        'Bir köylü ağır yaralandı; vuran bulunamadı.',
        'Kanlı bir gece: fail meçhul kaldı.',
        'Yaralama: köy korkuyla uyandı, suçlu gölgede.',
      ],
      caughtAnnalPool: [
        '{ad}, {öteki-i} vururken yakalandı.',
        '{ad-in} bıçağı {öteki-e} kalkmıştı; suçüstü tutuldu.',
        'Vuran {ad} çıktı; {öteki} sağ kurtuldu.',
      ],
    ),

    CrimeKind.abduction: CrimeDef(
      kind: CrimeKind.abduction,
      label: 'adam kaçırma',
      icon: '🕳️',
      severity: CrimeSeverity.grave,
      weight: 0.7,
      actSeconds: 9.0,
      hintPool: [
        '🌒 {yer} tarafında biri sürükleniyor, ayakları yerde değil.',
        '🌒 {yer} çevresinde boğuk bir ses köyün dışına doğru gitti.',
        '🌒 {yer} yolunda iki kişi var, biri gitmek istemiyor.',
      ],
      deedPool: [
        '🕳️ {öteki} köyden götürüldü. Yolun sonunda iz kalmadı.',
        '🕳️ {öteki-i} kaçırdılar. Kapısı açık, yatağı boş.',
        '🕳️ {öteki} kayıp. Onu götüreni kimse göremedi.',
      ],
      annalPool: [
        'Bir köylü kaçırıldı; kaçıran bulunamadı.',
        'Köy bir canını kaybetti: götürüldü, iz yok.',
        'Adam kaçırma: yatak boş kaldı, fail meçhul.',
      ],
      caughtAnnalPool: [
        '{ad}, {öteki-i} kaçırırken yakalandı.',
        '{ad} yolun başında tutuldu; {öteki} kurtarıldı.',
        'Kaçıran {ad} çıktı; {öteki} köye geri döndü.',
      ],
    ),

    CrimeKind.assassination: CrimeDef(
      kind: CrimeKind.assassination,
      label: 'suikast',
      icon: '🗡️',
      severity: CrimeSeverity.grave,
      weight: 0.5,
      actSeconds: 4.0,
      hintPool: [
        '🌒 {yer} tarafında biri gölgeden çıkmıyor, birini bekliyor.',
        '🌒 {yer} çevresinde bir adım fazla sessiz.',
        '🌒 {yer} arkasında bir demir parladı.',
      ],
      deedPool: [
        '🗡️ {öteki} öldürüldü. Vuran karanlığa karıştı.',
        '🗡️ {öteki-i} sırtından vurmuşlar. Kimse görmedi.',
        '🗡️ {öteki} bir daha kalkmadı. Fail meçhul.',
      ],
      annalPool: [
        'Bir köylü suikaste kurban gitti; katil bulunamadı.',
        'Kanlı bir hesap kapandı, kimin kapattığı bilinmiyor.',
        'Suikast: köy bir canını verdi, suçlu gölgede kaldı.',
      ],
      caughtAnnalPool: [
        '{ad}, {öteki-i} öldürürken yakalandı.',
        '{ad-in} bıçağı {öteki-e} saplanmadan tutuldu.',
        'Suikastçı {ad} çıktı; {öteki} sağ kurtuldu.',
      ],
    ),
  };

  static CrimeDef def(CrimeKind k) => defs[k]!;

  /// Test kancası — prose testi tüm havuzları konuşturup ham `{...}` yer tutucu
  /// kalmadığını doğrular.
  static List<CrimeDef> get all => defs.values.toList(growable: false);
}
