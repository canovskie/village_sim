import '../buildings/building_type.dart';
import '../core/constants.dart';
import 'season.dart';

/// ─── REFERANS KÖYÜN PLANI (saf veri) ─────────────────────────────────────────
///
/// Kurulum mantığı `scene/scene_reference_village.dart`'ta (main.dart'ın part'ı,
/// yani UI'a bağlı); PLAN burada, bağımsız bir kütüphanede durur. Sebep: plan
/// testlenebilsin — "bütün binalar başlangıç bölgesine sığıyor mu, çakışıyor mu,
/// kaç yatak var" sorularını sahneyi ayağa kaldırmadan sormak gerekiyor
/// (bkz. test/reference_village_test.dart).

/// Sabit dünya tohumu — harita, göl, orman, dekor hep aynı çıkar.
///
/// Rastgele seçilmedi: üreticinin "kuru başlangıç bölgesi" garantisi plandan
/// DAR (kenardan 2 tile içeri çekiliyor), yani gölün plan kutusuna sarkmadığı
/// tohumlar taranıp seçildi. Tohumu değiştirirsen reference_village_test'teki
/// "plan kutusuna su düşmez" testi seni uyarır — rastgele bir sayı yazma.
const int kReferenceSeed = 730024;

/// Referans köyün yazıldığı sabit kayıt slotu (menüden her giriş burayı tazeler).
const String kReferenceSlotId = 'reference';
const String kReferenceSlotName = 'Referans Köy';

/// Referans köyün takvim günü — 24. gün, oturmuş bir köyün geçmişi kadar.
/// Kronik satırları bu güne kadar tarihlenir; küçültmek geçmişi geleceğe atar.
const int kReferenceDay = 24;

/// Bu günün mevsimi — dört varyantın referans aldığı temel (bugün: yaz).
Season get kReferenceBaseSeason => seasonForDay(kReferenceDay);

/// MEVSİMLİK VARYANT — dört köy de AYNI planı kurar, yalnız takvim farklıdır.
///
/// Takvim hep İLERİ sarılır ve mevsim içindeki AYNI güne denk getirilir
/// (yaz 24 → sonbahar 28 → kış 32 → ilkbahar 36). İki sebep:
///   • Geriye sarmak kroniği geleceğe atardı (satırlar 24. güne kadar yazılı).
///   • Aynı gün-içi konum, dört köyün tek farkının MEVSİM olmasını garanti eder;
///     "kışın şu oldu" derken mevsim dışında değişen bir şey kalmaz.
int kReferenceDayFor(Season s) =>
    kReferenceDay +
    kDaysPerSeason *
        ((s.index - kReferenceBaseSeason.index) % Season.values.length);

/// Varyantın kayıt slotu. Temel mevsim (yaz) KANONİK slotu kullanır — menüdeki
/// "Referans Köy" girişi ile aynı dosya; diğer üçü kendi slotunda yaşar.
String kReferenceSlotIdFor(Season s) =>
    s == kReferenceBaseSeason ? kReferenceSlotId : '${kReferenceSlotId}_${s.name}';

String kReferenceSlotNameFor(Season s) =>
    s == kReferenceBaseSeason ? kReferenceSlotName : 'Referans · ${s.label}';

/// Planın sol-üst köşesi + boyu. Dünya üretici merkez etrafında 23×19'luk bir
/// "başlangıç bölgesi" bırakır (su ve maden oraya girmez) — plan tam ona oturur.
const int kRefOx = kCols ~/ 2 - 11;
const int kRefOy = kRows ~/ 2 - 9;
const int kRefW = 23;
const int kRefH = 19;

/// Köyün planı — (tip, yerel sütun, yerel satır). Sıra ÖNEMLİ:
///   1. ateş yeri (5 kurucuyu doğurur), 2. konutlar (kurucular yerleşsin),
///   3. gerisi.
const List<(BuildingType, int, int)> kRefLayout = [
  // ── Meydan ────────────────────────────────────────────────────────────────
  (BuildingType.firepit, 11, 8),
  // ── Konut mahallesi (batı) — 8 ev + 2 çadır = 18 yatak ────────────────────
  (BuildingType.woodenHouse, 0, 1),
  (BuildingType.woodenHouse, 0, 4),
  (BuildingType.woodenHouse, 0, 7),
  (BuildingType.woodenHouse, 0, 10),
  (BuildingType.woodenHouse, 3, 1),
  (BuildingType.woodenHouse, 3, 4),
  (BuildingType.woodenHouse, 3, 7),
  (BuildingType.woodenHouse, 3, 10),
  (BuildingType.tent, 6, 2),
  (BuildingType.tent, 6, 5),
  // ── Yönetim & mabet (kuzey) ───────────────────────────────────────────────
  (BuildingType.townhall, 9, 1),
  (BuildingType.church, 15, 1),
  (BuildingType.warehouse, 19, 1),
  (BuildingType.market, 18, 4),
  // ── Meydan çevresi ────────────────────────────────────────────────────────
  (BuildingType.well, 13, 9),
  (BuildingType.tavern, 8, 10),
  (BuildingType.tailor, 6, 8),
  (BuildingType.floristCottage, 15, 8),
  (BuildingType.beehive, 17, 9),
  // ── Üretim (güney) ────────────────────────────────────────────────────────
  (BuildingType.chickenCoop, 9, 13),
  (BuildingType.barn, 12, 13),
  (BuildingType.mill, 16, 13),
  (BuildingType.lumberCamp, 0, 15),
  (BuildingType.fisherCabin, 3, 15),
  // ── Fenerler ──────────────────────────────────────────────────────────────
  (BuildingType.lamppost, 10, 6),
  (BuildingType.lamppost, 13, 6),
  (BuildingType.lamppost, 10, 11),
  (BuildingType.lamppost, 14, 11),
  (BuildingType.lamppost, 14, 4),
  (BuildingType.lamppost, 7, 14),
];

/// Tarla blokları — (c1, r1, c2, r2) yerel, sınırlar dahil.
const List<(int, int, int, int)> kRefFarms = [
  (6, 16, 11, 18),
  (13, 16, 17, 18),
];

/// Oduncunun korusu — kutunun BATISINDA, deterministik satranç deseni.
/// Oduncu kulübesi "yakında ağaç" ister ([kLumberTerritoryRadius]); dünya
/// üreticinin ormanı oraya düşmeyebilir, bu yüzden garanti altına alınır.
/// (c1, r1, c2, r2) yerel — negatif sütunlar kutunun dışını gösterir.
const (int, int, int, int) kRefGrove = (-7, 12, -2, 18);

/// Köyün mühürlü kanunları. Toplam vektör = (otorite +1, iktisat +2, iman +1)
/// → ölü bandın (ham ±2.4) içinde, yani köy MERKEZ (Ilımlı Köy) kalır. Rejim
/// testleri buradan istenen köşeye itilebilir.
///
/// NOT: iktisat vektörleri yeniden ölçüldüğünde (bkz. law_compass kLawVectors —
/// "sıradan köy hayatı hükmü iktisat eksenini oynatmaz") bu set +4'e kayıp
/// Mülkçü olmuştu; dengeyi `eldersExemptFromFood` (−2) geri getiriyor. O da
/// oturmuş ORTALAMA bir köy için zaten en doğal hükümlerden biri.
const List<String> kRefLaws = [
  'neighborliness', //        imece bağı        (nötr)
  'irrigation', //            ortak su seferi   (iktisat −1)
  'herdGrowth', //            ortak sürü        (nötr)
  'hospitality', //           açık kapı         (otorite −1, iktisat +2)
  'apprenticeship', //        usta-çırak        (otorite +1, iktisat +2)
  'freeRange', //             bırakınız otlasın (otorite −1, iktisat +1)
  'eldersExemptFromFood', //  yaşlıya saygı     (iktisat −2)
  'nizam.watch', //           gece nöbeti       (otorite +2)
  'peacefulEnd', //           huzurlu veda      (iman +1)
];

/// Referans köyün hedef nüfusu — yatak sayısına EŞİT olmalı (ne evsiz kalsın
/// ne ev boş dursun). Testte doğrulanır.
const int kRefPopulation = 18;
