// HESAPLAŞMA — koşunun kapanışı.
//
// Kaybetme eşiği (village_collapse) uzun süre tek kutuptu: köy dağılabiliyordu
// ama kazanılabilmiyordu. Oyun bitmiyor, SUSUYORDU — son kademeye varılınca
// görev listesi boşalıyor, HUD şeridi kayboluyor, geriye yalnız bakım kalıyordu.
//
// Hesaplaşma o boşluğu simetriyle kapatır: [kReckoningYear] geldiğinde
// imparatorluk vergi için değil KARAR için gelir. Defteri açar, köyün altı
// yılına bakar ve bir şey söyler: ya beratı verir, ya sancağı tanır, ya da
// köyü ilhak eder.
//
// ── ÖLÇÜNÜN TASARIMI ───────────────────────────────────────────────────────
// Kritik karar şu: hesaplaşma KAÇ BİNA DİKTİĞİNE BAKMAZ. Geç oyun görevleri
// bir inşa listesine dönüşmüştü (şadırvan, kütüphane, hamam, anıt…) ve oyunun
// en güçlü tarafı — dilekçe, kanunname, haneler — ilerlemenin ölçüsü değil
// dekoruydu. Burada tersi geçerli: köy, insanlarını nasıl idare ettiğiyle
// tartılır. Bina ancak nüfusu taşıdığı kadar sayılır.
//
// İKİ AYRI HAYATTA KALMA YOLU vardır ve bu bilinçlidir:
//   • DAYANMAK  — haneler seninle, tüzük kalın, köy kalabalık → sancak.
//                 İmparatorluğun sevmesine ihtiyacın yok.
//   • EĞİLMEK   — yıllarca ödedin, komutanla aran iyi → berat.
//                 Zayıf köy de ayakta kalabilir, ama tabi kalarak.
// İkisi de olmazsa ilhak. Yani oyuncu ya güçlü ya uysal olmalı; ikisinde de
// vasat kalan köy defterde bir satıra iner.
//
// Saf: Flutter yok, sahne yok, rastgelelik yok (bkz. test/reckoning_test).
library;

import '../characters/villager_type.dart';
import '../cutscene/cutscene.dart';
import '../text/voice.dart';
import 'law_compass.dart';

/// İmparatorluğun kararı.
enum ReckoningVerdict {
  /// 🏴 SANCAK — köy kendi bayrağını diker. İmparatorluk tabiyet değil
  /// komşuluk teklif eder. En zor sonuç; yalnız kendi ayakları üstünde
  /// duran köy alır.
  sancak,

  /// 📜 BERAT — köy tanınır ama tabi kalır. Vergisi devam eder, adı deftere
  /// kalıcı yazılır. "Kazanmak" budur: ayakta kaldın, kendinin olmadın.
  berat,

  /// ⛓ İLHAK — köy imparatorluğun bir mülkü olur. Kimse ölmez, ocak sönmez;
  /// ama artık burayı sen yönetmezsin. Defter kapanır.
  ilhak,
}

extension ReckoningVerdictX on ReckoningVerdict {
  /// Kapanış ekranının başlığı.
  String get title => switch (this) {
        ReckoningVerdict.sancak => 'SANCAK DİKİLDİ',
        ReckoningVerdict.berat => 'BERAT VERİLDİ',
        ReckoningVerdict.ilhak => 'KÖY İLHAK EDİLDİ',
      };

  String get icon => switch (this) {
        ReckoningVerdict.sancak => '🏴',
        ReckoningVerdict.berat => '📜',
        ReckoningVerdict.ilhak => '⛓',
      };

  /// Koşu iyi bitti mi — ekranın rengi ve kroniğin tonu bunu okur.
  bool get favorable => this != ReckoningVerdict.ilhak;

  /// Kayıt mührüne yazılan kısa gerekçe (menüde kapanmış defterin altında).
  String get sealReason => switch (this) {
        ReckoningVerdict.sancak => 'Sancağını dikti',
        ReckoningVerdict.berat => 'Beratını aldı',
        ReckoningVerdict.ilhak => 'İmparatorluğa katıldı',
      };
}

/// Hesaplaşmanın girdileri. Hepsi 0..1'e NORMALİZE gelir; ham sayıyı sahne
/// çevirir (bkz. scene_reckoning `_reckoningInput`). Böylece bu dosya köyün
/// iç birimlerini (kile, nüfuz, itibar) hiç bilmez ve tek başına test edilir.
class ReckoningInput {
  /// Hanelerin köyle arası — kaçı seninle kaldı, kaçı küstü. Ağırlığı en
  /// yüksek girdi: köyü ayakta tutan şey binalar değil, hanelerin rızasıdır.
  final double unity;

  /// Tüzüğün kalınlığı — yürürlükteki hüküm sayısı + kimliğin kazanılmış
  /// olması. Kanunname'nin oyunun omurgası olduğu iddiası burada tartılır.
  final double charter;

  /// Köyün ağırlığı — nüfus ve refah. Az ama zorunlu: on kişilik bir köy ne
  /// kadar iyi yönetilirse yönetilsin sancak dikemez.
  final double grit;

  /// Kararların mirası — büyük dilekçelerin bıraktığı kalıcı iz
  /// (governanceLegacy). Yönetişimin uzun hafızası.
  final double legacy;

  /// İmparatorlukla ilişki. Gücün DEĞİL, uysallığın ölçüsü — kendi başına
  /// sancak kazandırmaz, ama zayıf köyü ilhaktan kurtarır.
  final double favor;

  const ReckoningInput({
    required this.unity,
    required this.charter,
    required this.grit,
    required this.legacy,
    required this.favor,
  });

  /// Köyün KENDİ ayakları üstünde durma gücü (0..1). İmparatorluk sevgisi
  /// bilerek DIŞARIDA: bu, "sensiz de yaşarım" diyebilme ölçüsüdür.
  double get standing => (unity * 0.34 +
          charter * 0.30 +
          grit * 0.22 +
          legacy * 0.14)
      .clamp(0.0, 1.0);
}

/// Sancak eşiği — kendi başına ayakta durmanın bedeli yüksektir.
///
/// ÖLÇÜLDÜ, tahmin edilmedi: referans köy (oturmuş, ORTALAMA bir köy) bu
/// ölçüde 0.61 okuyor. Eşik ilk denemede 0.62'ydi ve ortalama bir köy en üst
/// sonucun on binde on üçü kadar yakınına geliyordu — yani sancak bedavaydı.
/// 0.72, referans köyün belirgin biçimde ÜSTÜ: haneleri neredeyse tümüyle
/// kazanmadan, tüzüğü kalınlaştırmadan ve köyü büyütmeden ulaşılmaz.
/// Bu sayı değişirse test/reckoning_probe_test'teki referans köy beklentisi
/// de kontrol edilmeli.
const double kSancakThreshold = 0.72;

/// Berat eşiği — köy kendini döndürebiliyorsa tanınır.
const double kBeratThreshold = 0.40;

/// Zayıf köyün ilhaktan kurtulma tabanı: bu gücün altında hiçbir uysallık
/// yetmez (imparatorluk boş bir kabuğu himaye etmez, yutar).
const double kFavorRescueFloor = 0.28;

/// Uysallıkla kurtulmanın gerektirdiği itibar.
const double kFavorRescue = 0.60;

/// Kararı ver. Tek kapı: sahne de test de burayı çağırır.
ReckoningVerdict judge(ReckoningInput input) {
  final s = input.standing;
  if (s >= kSancakThreshold) return ReckoningVerdict.sancak;
  if (s >= kBeratThreshold) return ReckoningVerdict.berat;
  if (s >= kFavorRescueFloor && input.favor >= kFavorRescue) {
    return ReckoningVerdict.berat;
  }
  return ReckoningVerdict.ilhak;
}

/// Kapanış ekranındaki karne satırı: neyin ne kadar taşıdığı.
///
/// Oyuncu sonucu görsün yetmez, NEDEN'ini de görsün: hangi sütunun boş
/// kaldığını okuyamayan oyuncu bir dahaki koşuda aynı yere gelir.
class ReckoningLedgerRow {
  final String label;
  final double value; // 0..1
  final String note; // değere göre tek cümle

  const ReckoningLedgerRow(this.label, this.value, this.note);
}

List<ReckoningLedgerRow> reckoningLedger(ReckoningInput i) => [
      ReckoningLedgerRow('Hanelerin rızası', i.unity, _band(i.unity, const [
        'Haneler yüzünü çevirmişti.',
        'Bazı haneler seninleydi, bazıları değil.',
        'Haneler arkanda durdu.',
      ])),
      ReckoningLedgerRow('Tüzüğün kalınlığı', i.charter, _band(i.charter, const [
        'Köyün yazılı bir huyu yoktu.',
        'Birkaç hüküm vardı, bir duruş yoktu.',
        'Kanunname köyün huyunu belirliyordu.',
      ])),
      ReckoningLedgerRow('Köyün ağırlığı', i.grit, _band(i.grit, const [
        'Köy küçük kaldı, sesi uzağa gitmedi.',
        'Köy kendini döndürüyordu, fazlası değil.',
        'Kalabalık ve tok bir kasabaydı.',
      ])),
      ReckoningLedgerRow('Kararların mirası', i.legacy, _band(i.legacy, const [
        'Büyük kararlar köyde kötü iz bıraktı.',
        'Kararlar gelip geçti, iz bırakmadı.',
        'Verdiğin kararlar köyün hafızasında iyi durdu.',
      ])),
      ReckoningLedgerRow('İmparatorlukla arası', i.favor, _band(i.favor, const [
        'Komutanın defterinde adın kırmızıydı.',
        'Ne dost ne düşman: ödedin, geçti.',
        'Heyet buraya gelmeyi iş değil usul sayıyordu.',
      ])),
    ];

String _band(double v, List<String> three) =>
    v < 0.34 ? three[0] : (v < 0.67 ? three[1] : three[2]);

/// HESAPLAŞMA SİNEMATİĞİ — koşunun son sahnesi.
///
/// Oyunun en nadir sinematiği olmalı ve öyle: bir köy bunu ömründe bir kez
/// görür (bkz. project_cutscene_craft — sinematik eskalasyon merdiveni).
/// Yapı bilerek imparatorluk gelişinin AYNISI değil: orada süvariler eşikte
/// durur ve pazarlık başlar; burada komutan defteri KAPATIR. Son çekim
/// karar rengindedir — sancakta şafak, ilhakta kapanış vinyeti.
///
/// Saf fonksiyon (sahne state'i yok) — animasyon odası da oynatabilsin.
Cutscene reckoningCutscene(
  ReckoningVerdict v, {
  required String village,
  required double favor,
  required int seed,
}) {
  final named = village.trim().isNotEmpty;
  final vName = named ? village.trim() : 'bu köy';

  // Defterin açılışı: itibar tonu burada da okunur. Karar zaten verilmiştir;
  // ton yalnız kaç yıldır nasıl geçindiğinizi söyler.
  final opening = Voice.pick(
      favor < 0.35
          ? [
              'Heyet bu sefer kalabalık geldi ve kimse selam vermedi.',
              'Defteri taşıyan katip önde yürüdü. Komutan arkasında, sessiz.',
            ]
          : favor >= 0.7
              ? [
                  'Tanıdık sancak, tanıdık yüz. Ama bu sefer at üstünde değil, '
                      'yaya geldiler.',
                  'Komutan kapıda durdu ve şapkasını çıkardı. Bu bir usul '
                      'ziyareti değildi.',
                ]
              : [
                  'Yolun ucunda toz göründü. Bu sefer kimse tarlaya dönmedi.',
                  'Heyet meydanda durdu. Kalabalık kendiliğinden bir halka oldu.',
                ],
      seed);

  final ruling = switch (v) {
    ReckoningVerdict.sancak => [
        CutsceneLine(
            '$vName. Altı yıl önce burada bir ocak vardı, bir de sizin '
            'inadınız.',
            speaker: 'Komutan'),
        const CutsceneLine(
            'Bu defterde sizin sayfanız artık tutmuyor. Kendi defterinizi '
            'kendiniz tutacaksınız.',
            speaker: 'Komutan'),
        const CutsceneLine(
            'Sancağınızı dikin. İmparatorluk komşunuzdur; efendiniz değil.',
            speaker: 'Komutan'),
      ],
    ReckoningVerdict.berat => [
        CutsceneLine('$vName. Sayfanız dolmuş. Rakamlar tutuyor.',
            speaker: 'Komutan'),
        const CutsceneLine(
            'Beratınız burada. Adınız kalıcı yazıldı, kimse bir daha '
            'silemez.',
            speaker: 'Komutan'),
        const CutsceneLine(
            'Vergi devam eder. Ama bir daha kapınıza silahla gelmem.',
            speaker: 'Komutan'),
      ],
    ReckoningVerdict.ilhak => [
        CutsceneLine('$vName. Altı yıl. Sayfada yazacak bir şey birikmemiş.',
            speaker: 'Komutan'),
        const CutsceneLine(
            'Kendini döndüremeyen yeri imparatorluk döndürür. Usul budur.',
            speaker: 'Komutan'),
        const CutsceneLine(
            'Kimse gitmeyecek, kimse ölmeyecek. Yalnız buranın kararını '
            'artık siz vermeyeceksiniz.',
            speaker: 'Komutan'),
      ],
  };

  return Cutscene([
    CutsceneShot(
      bg: CutsceneBg.valleyDusk,
      panFrom: 0.05,
      panTo: 0.0,
      zoomFrom: 1.02,
      zoomTo: 1.08,
      actors: const [
        CutsceneActor(type: VillagerType.guard, seed: 31, fromX: 1.2, toX: 0.62, y: 0.84, scale: 1.2, flip: true, walk: true),
        CutsceneActor(type: VillagerType.guard, seed: 44, fromX: 1.45, toX: 0.44, y: 0.80, scale: 1.1, flip: true, walk: true),
      ],
      lines: [
        CutsceneLine(opening),
        const CutsceneLine(
            'Katip defteri açtı. Altı yılın hesabı iki sayfaya sığmıştı.'),
      ],
    ),
    CutsceneShot(
      bg: CutsceneBg.valleyDusk,
      framing: CutsceneFraming.close,
      zoomFrom: 1.1,
      zoomTo: 1.0,
      actors: const [
        CutsceneActor(type: VillagerType.guard, name: 'Komutan', seed: 31, fromX: 0.5, y: 0.80, scale: 1.6, flip: true),
      ],
      lines: ruling,
    ),
    // Kapanış çekimi karar rengindedir: sancakta yeni bir şafak, beratta
    // akşamın sükûneti, ilhakta kapanan bir perde.
    CutsceneShot(
      bg: switch (v) {
        ReckoningVerdict.sancak => CutsceneBg.valleyDawn,
        ReckoningVerdict.berat => CutsceneBg.fireNight,
        ReckoningVerdict.ilhak => CutsceneBg.titleCard,
      },
      zoomFrom: 1.0,
      zoomTo: 1.05,
      lines: [
        CutsceneLine(switch (v) {
          ReckoningVerdict.sancak =>
            'Heyet gitti. Direk o gün dikildi ve $vName ertesi sabah kendi '
                'adına uyandı.',
          ReckoningVerdict.berat =>
            'Heyet gitti. Berat kütüphaneye kondu; o akşam ateş her zamankinden '
                'kalabalıktı.',
          ReckoningVerdict.ilhak =>
            'Heyet gitmedi. Bir kısmı kaldı, defteri devraldı ve $vName '
                'başkasının sayfası oldu.',
        }),
      ],
    ),
  ]);
}

/// Kararın köyün KİMLİĞİNE göre okunuşu — aynı berat, Mühürlü El'de başka,
/// Ortak Ocak'ta başka bir şey demektir. Kapanışın "bu benim köyümdü" hissi
/// buradan gelir; rejim yalnız oyun ortasında değil, son cümlede de görünür.
String verdictEpilogue(ReckoningVerdict v, VillageRegime regime) =>
    switch (v) {
      ReckoningVerdict.sancak => switch (regime) {
          VillageRegime.commune =>
            'Sancağı bir kişi dikmedi. Direği tutan altı el vardı ve hiçbiri '
                'diğerinden uzun değildi.',
          VillageRegime.market =>
            'Sancak pazarın ortasına dikildi. O gün alışveriş durmadı; '
                'bağımsızlık da bir mal gibi hesaplandı, ödendi, alındı.',
          VillageRegime.ironTable =>
            'Sancak dikildiğinde herkes aynı sofradaydı. Kimse ötekinden fazla '
                'yemedi, kimse ötekinden az. Direği o eşitlik ayakta tuttu.',
          VillageRegime.sealedHand =>
            'Sancağı tek bir el dikti ve köy sustu. Korkuyla mı gururla mı, '
                'onu torunlar tartışacak.',
          VillageRegime.moderate =>
            'Sancak dikildi ama üstünde bir arma yoktu. Bu köy hiçbir şeye tam '
                'karar vermemişti; yine de kimseye boyun eğmemişti.',
        },
      ReckoningVerdict.berat => switch (regime) {
          VillageRegime.commune =>
            'Beratı meclis okudu, tek bir ağız değil. Tabi olmak da ortak '
                'alınmış bir karardı.',
          VillageRegime.market =>
            'Berat bir sözleşmeydi ve iyi pazarlık edilmişti. Vergi ödenir, '
                'kese açık kalır.',
          VillageRegime.ironTable =>
            'Berat geldi, sofra bozulmadı. Dışarıya tabi, içeride eşit: '
                'köy bu ikisini birlikte taşımayı öğrendi.',
          VillageRegime.sealedHand =>
            'Berat mühürlendi. Komutan gitti, korku kaldı; köyü ayakta tutan '
                'şeyin hangisi olduğu belli değil.',
          VillageRegime.moderate =>
            'Berat verildi. Köy ne bir şey oldu ne de kayboldu; deftere '
                'temiz bir satır olarak geçti.',
        },
      ReckoningVerdict.ilhak => switch (regime) {
          VillageRegime.commune =>
            'Meclis son kez toplandı ve dağılma kararını da ortak aldı. '
                'Konuşarak geçen yıllar, konuşacak vakit bırakmamıştı.',
          VillageRegime.market =>
            'Köy satıldı demediler, "devredildi" dediler. Defterde iki rakam '
                'vardı ve ikisi de imparatorluğundu.',
          VillageRegime.ironTable =>
            'Sofra söküldü, tahtaları arabaya yüklendi. Eşitlik kaldı: '
                'artık herkes eşit derecede tebaaydı.',
          VillageRegime.sealedHand =>
            'Mühür istendi ve verildi. Tek elin kurduğu düzen, tek bir imzayla '
                'el değiştirdi.',
          VillageRegime.moderate =>
            'Kimse direnmedi, kimse sevinmedi. Köy bir sabah kalktı ve '
                'başkasının oldu.',
        },
    };
