// ORTA OYUN DERSLERİ — kuruluştan sonra açılan sistemlerin tek öğretmeni.
//
// Öğretici kuruluşta bitiyordu. `scene_guide` yalnız iki şey biliyor: inşa
// kartı ve Kanunname rafı. Oysa köy ayağa kalktıktan SONRA açılan bir yığın
// sistem var — kış, kışlık giysi, hane kızgınlığı, suç ve yargı, zanaatın
// kaybı, tüzüğün bir kimliğe dönüşmesi, imparatorlukla ilişki. Hiçbiri
// öğretilmiyordu; oyuncu bunları ya deneyerek ya da hiç öğrenmiyordu.
//
// Bu boşluk hesaplaşma gelince gerçek bir soruna dönüştü: kapanış tam olarak
// bu sistemleri ölçüyor (bkz. systems/reckoning.dart). Oyuncunun neyle
// tartıldığını öğrenmeden tartılması, oyunun ona hiç anlatmadığı bir sınavdı.
//
// ── KURULUŞ ÖĞRETİCİSİNDEN FARKI ──────────────────────────────────────────
// Kuruluşta oyuncu ne yapacağını bilmez → parmakla gösterilir (spot, ekranı
// karartır, "şu kartı seç" der). Burada oyuncu oynamayı BİLİYOR; bilmediği
// şey karşısına çıkan sistemin ne olduğu. O yüzden ders bir parmak değil bir
// KART: ekranı karartmaz, tıklamayı engellemez, kendiliğinden kaybolmaz.
// Okunur ve kapatılır.
//
// ── ÜÇ KURAL ──────────────────────────────────────────────────────────────
//  1. Ders KOŞULLA açılır, takvimle değil. Kış dersi sonbahar gelince düşer;
//     hane dersi ilk hane söylenince. Zamanla tetiklenen ders, oyuncunun
//     yaşamadığı bir şeyi anlatır ve okunmaz.
//  2. Bir kez. Görülen ders kaydedilir (bkz. scene_save `lessonsSeen`).
//  3. Her dersin bir EYLEMİ vardır. "Haneler küsebilir" bilgi; "gönlünü almak
//     için bağış yap ya da nikâh kıy" derstir. Eylemi olmayan ders bir
//     tabeladır.
//
// Saf: Flutter yok, sahne yok, rastgelelik yok (bkz. test/village_lessons_test).
library;

import '../world/season.dart';

/// Dersin tetikleneceği ANI belirleyen köy hâli. Ham sayılar sahnede toplanır
/// (bkz. scene_lessons `_lessonContext`); bu dosya köyün iç birimlerini bilmez.
class LessonContext {
  final Season season;

  /// Serzeniş VEYA daha kötü durumdaki hane sayısı — yani oyuncunun UYARI
  /// penceresi. "El çekti"yi beklemek dersi geç verirdi.
  final int upsetHouses;

  /// Bugüne dek işlenen suç sayısı.
  final int crimesSeen;

  /// Köyde bilinen zanaat sayısı.
  final int knownCrafts;

  /// Dokunmuş ama sırtlara dağıtılmamış kışlık sayısı.
  final int coatsPending;

  /// Yürürlükteki hüküm sayısı.
  final int enactedPolicies;

  /// Köy bir rejim kimliği kazandı mı.
  final bool regimeNamed;

  /// Bugüne dek ağırlanan imparatorluk heyeti sayısı.
  final int imperialVisits;

  const LessonContext({
    required this.season,
    this.upsetHouses = 0,
    this.crimesSeen = 0,
    this.knownCrafts = 0,
    this.coatsPending = 0,
    this.enactedPolicies = 0,
    this.regimeNamed = false,
    this.imperialVisits = 0,
  });
}

/// Tek bir ders.
class Lesson {
  final String id;
  final String icon;

  /// Kart başlığı — neyin olduğunu söyler.
  final String title;

  /// Sistemin ne olduğu (1-2 cümle).
  final String body;

  /// OYUNCU NE YAPACAK. Her dersin bir eylemi olmalı; bu alan boş bırakılamaz
  /// (bkz. test: "her dersin bir eylemi var").
  final String action;

  /// Aynı anda birden çok ders açılırsa hangisi önce. KÜÇÜK sayı önce gelir.
  /// Sıralama aciliyete göre: hayatta kalma > kayıp riski > yönetişim.
  final int priority;

  final bool Function(LessonContext) when;

  const Lesson({
    required this.id,
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
    required this.priority,
    required this.when,
  });
}

class VillageLessons {
  static const List<Lesson> all = [
    // ── Hayatta kalma ────────────────────────────────────────────────────
    Lesson(
      id: 'winter',
      icon: '❄️',
      title: 'Kış geliyor',
      body: 'Sonbahar başladı; bundan sonraki mevsimde tarla donacak, ekin '
          'büyümeyecek. Kış cezalandırmaz, hazırlığı ödüllendirir: hazırlıklı '
          'köyde kış sakin geçer, hazırlıksız köyde ağır.',
      action: 'Defter\'in Kış sayfasında dört kalem var: yakacak, erzak, yem '
          've kışlık. Dördü de yeşilse kışı rahat çıkarırsın. Kömür odundan '
          'uzun yanar; maden kışın işe yarar.',
      priority: 0,
      when: _autumn,
    ),
    Lesson(
      id: 'coats',
      icon: '🧥',
      title: 'Kışlık dokundu',
      body: 'Dokumacı yünden kışlık çıkardı ama tezgâhta bekliyor. Kışlık '
          'giysi kimin sırtına gideceği KÖYÜN DEĞİL SENİN kararın.',
      action: 'Kırılganı (çocuk/yaşlı) önce giydirebilirsin, çalışanı önce '
          'giydirebilirsin ya da hane hane sırayla dağıtabilirsin. Üçü de '
          'savunulabilir; üçünün de kışın görünür bir bedeli var.',
      priority: 1,
      when: _coatsWaiting,
    ),

    // ── Kayıp riski ──────────────────────────────────────────────────────
    Lesson(
      id: 'houseMood',
      icon: '😒',
      title: 'Bir hane söyleniyor',
      body: 'Haneler köyün omurgası ve bu hane senden memnun değil. '
          'Kızgınlık bir merdiven: serzeniş → el çekti → ambar kapandı → '
          'kopuş. Kopuşta kalan hane bir süre sonra köyü TERK EDER, '
          'insanlarını ve sakladığı yiyeceği alarak.',
      action: 'Serzeniş senin uyarı pencerelin. Hanenin gönlünü bağışla, '
          'nikâhla ya da lehine bir kararla alabilirsin. Haneleri bir arada '
          'tutmak, berat gününde en ağır tartılan şeydir.',
      priority: 2,
      when: _housesUpset,
    ),
    Lesson(
      id: 'craft',
      icon: '🔨',
      title: 'Zanaat ustayla gider',
      body: 'Köy artık birkaç zanaat biliyor. Ama zanaat bir binada değil bir '
          'İNSANDA durur: ustası ölür de çırağı yoksa o zanaat köyden silinir '
          've onunla dikilen binalar bir daha dikilemez.',
      action: 'Ustaların yanına genç ver. Lonca kurmak zanaatı toptan korur. '
          'Bilinen zanaat sayısı geri de gidebilir — tek yönlü değildir.',
      priority: 3,
      when: _craftsGrowing,
    ),
    Lesson(
      id: 'crime',
      icon: '🗡',
      title: 'Köyde suç işlendi',
      body: 'Köy büyüdükçe çalınacak bir şey, kıskanılacak bir hane oluyor. '
          'Muhafız devriyesi suçüstü yakalayabilir; yakalanan biri sana '
          'yargılanmak üzere getirilir.',
      action: 'Yargı senin. Verdiğin ceza yalnız o kişiyi değil köyün '
          'huyunu da belirler — Kanunname\'deki hükümler cezanın sertliğini '
          've köyün buna ne diyeceğini değiştirir.',
      priority: 4,
      when: _crimeHappened,
    ),

    // ── Yönetişim ────────────────────────────────────────────────────────
    Lesson(
      id: 'charter',
      icon: '🧭',
      title: 'Mühürler bir yöne yatıyor',
      body: 'Birden çok hüküm yürürlükte. Bunlar ayrı ayrı kurallar değil: '
          'toplamları köye bir KİMLİK kazandırıyor. Kimlik menüden seçilmez, '
          'bastığın mühürlerden doğar.',
      action: 'Kanunname\'nin başındaki pusulaya bak — köyün nereye yattığını '
          'gösterir. Bir kimlik kazanmak yetkilerini değiştirir: baskı rejimi '
          'hızlı mühür verir, hür rejimde meclis sana rağmen karar verebilir.',
      priority: 5,
      when: _charterForming,
    ),
    Lesson(
      id: 'imperial',
      icon: '⚔',
      title: 'İmparatorluk defterinde bir satırsın',
      body: 'Heyet gitti ama geri gelecek ve her yıl istediği rakam büyüyecek. '
          'Nasıl davrandığın deftere yazılıyor: ödeyen köyle pazarlık edilir, '
          'direnen köye silahla gelinir.',
      action: 'Ödemek de direnmek de geçerli bir yol. Ödeyerek itibar '
          'biriktiren zayıf bir köy ayakta kalabilir; itibarı hiç olmayan '
          'güçlü bir köy de kendi başına durabilir. İkisi de olmayan köy '
          'berat gününde ilhak edilir.',
      priority: 6,
      when: _imperialVisited,
    ),
  ];

  /// Şu an açılması gereken ders — görülmüşleri atlar, en acili döner.
  /// Hiçbiri tetiklenmediyse null.
  static Lesson? pick(LessonContext ctx, Set<String> seen) {
    Lesson? best;
    for (final l in all) {
      if (seen.contains(l.id)) continue;
      if (!l.when(ctx)) continue;
      if (best == null || l.priority < best.priority) best = l;
    }
    return best;
  }

  // ── Tetikler ─────────────────────────────────────────────────────────────
  // Hepsi "şu an bu durum var mı" sorar; BİR KEZ'liği çağıran taraf (görülen
  // dersler kümesi) sağlar. Tetiğin kendi içinde tarih tutması, aynı bilgiyi
  // iki yerde saklamak olurdu.
  static bool _autumn(LessonContext c) => c.season == Season.autumn;
  static bool _coatsWaiting(LessonContext c) => c.coatsPending > 0;
  static bool _housesUpset(LessonContext c) => c.upsetHouses >= 1;
  static bool _craftsGrowing(LessonContext c) => c.knownCrafts >= 3;
  static bool _crimeHappened(LessonContext c) => c.crimesSeen >= 1;
  static bool _charterForming(LessonContext c) =>
      c.enactedPolicies >= 2 && !c.regimeNamed;
  static bool _imperialVisited(LessonContext c) => c.imperialVisits >= 1;
}
