/// GÖRÜŞ KURALLARI — saf geometri/ışık hesabı.
///
/// Sahne katmanından ayrı tutuluyor çünkü suçun gizliliği tam olarak burada
/// doğuyor: karanlıkta menzil daralır, arkanı dönmüşsen görmezsin. "Sinsice
/// sokulma" evresinin süs değil gerçek olmasını sağlayan kural bu, dolayısıyla
/// test altında olmalı.
abstract final class Sight {
  /// Gündüz görüş menzili (tile).
  static const double day = 11.0;

  /// Gecenin en karanlığında görüş menzili (tile).
  static const double night = 4.0;

  /// Elde meşale varsa karanlıkta kazanılan ek menzil.
  static const double torchBonus = 2.0;

  /// Arkada kalanı görme menzili çarpanı (çevresel görüş).
  static const double behindFactor = 0.45;

  /// Gürültülü olayların duyulma menzili — yön aranmaz.
  static const double earshot = 7.0;

  /// Işığa (ve meşaleye) göre görüş menzili.
  static double rangeFor({required double dayLight, bool hasTorch = false}) {
    final dl = dayLight.clamp(0.0, 1.0);
    final r = night + (day - night) * dl;
    return hasTorch ? r + torchBonus : r;
  }

  /// (dx,dy) göreli konumundaki bir şey görülür mü?
  ///
  /// [facingRight] gözlemcinin baktığı yön. Hedef ters taraftaysa menzil
  /// [behindFactor] ile daralır — tamamen kör değil, ama arkadan yaklaşan
  /// birini fark etmesi zordur.
  static bool visible({
    required double dx,
    required double dy,
    required bool facingRight,
    required double range,
  }) {
    final ahead = facingRight ? dx >= 0 : dx <= 0;
    final r = ahead ? range : range * behindFactor;
    return dx * dx + dy * dy <= r * r;
  }

  /// Duyulur mu — yönden bağımsız, sabit menzil.
  static bool audible({required double dx, required double dy}) =>
      dx * dx + dy * dy <= earshot * earshot;
}

/// GÖRÜLEN ŞEYİN TÜRÜ — bir köylünün hatırlayabileceği olaylar.
///
/// Liste kasten dar: her tür ya bir davranışı besler ya panelde okunur. Kimsenin
/// kullanmadığı bir anı türü, hafızayı "dolu gösteren" ama hiçbir şey
/// değiştirmeyen süstür (bkz. world_pressure'daki aynı sözleşme).
enum Notion {
  /// Birinin suç işlediğini görmek — ihbarın ve kanaatin kaynağı.
  crime,

  /// Kavga/arbede görmek.
  brawl,

  /// Ölüm görmek.
  death,

  /// Doğum duymak/görmek.
  birth,

  /// Düğün.
  wedding,

  /// Birinin iyiliğini görmek (paylaşma, yardım) — kanaati yukarı çeker.
  kindness,

  /// Muhafızın birini yakaladığını görmek — asayişin görünür yüzü.
  arrest,
}

/// Bir anının oyuncu-yüzü karşılığı. Panelde "hatırladıkları" satırı bunu yazar.
String notionLabel(Notion n) => switch (n) {
      Notion.crime => 'bir suç gördü',
      Notion.brawl => 'bir kavga gördü',
      Notion.death => 'bir ölüme tanık oldu',
      Notion.birth => 'bir doğum duydu',
      Notion.wedding => 'bir düğün gördü',
      Notion.kindness => 'bir iyilik gördü',
      Notion.arrest => 'bir yakalanma gördü',
    };

/// Anının kanaate etkisi (özneye dair). Pozitif = özneyi sevdirir.
double notionOpinionShift(Notion n) => switch (n) {
      Notion.crime => -0.45,
      Notion.brawl => -0.18,
      Notion.kindness => 0.30,
      Notion.wedding => 0.06,
      Notion.birth => 0.04,
      Notion.death => 0,
      Notion.arrest => -0.10,
    };

/// Anının TEDİRGİNLİK dürtüsüne kattığı yük (bkz. scene_mind Drive.unease).
double notionUnease(Notion n) => switch (n) {
      Notion.crime => 0.35,
      Notion.brawl => 0.22,
      Notion.death => 0.30,
      Notion.arrest => 0.10,
      Notion.birth => 0,
      Notion.wedding => 0,
      Notion.kindness => 0,
    };

/// BİR ANI — köylünün gördüğü/duyduğu tekil olay.
///
/// [firsthand] ayrımı sistemin kalbi: gözüyle gören ihbar edebilir, kulaktan
/// duyan yalnız dedikodu yayar. Bu ayrım olmadan bir söylenti köyde
/// yakalanmalar zincirine dönerdi.
class Recollection {
  final Notion kind;

  /// Olayın öznesi (fail/kahraman) — köylü nesnesi. Döngüsel import olmasın
  /// diye [Object]; okuyan taraf cast eder ([VillagerJob.claim] ile aynı desen).
  final Object? subject;

  /// Öznenin o anki adı — özne köyden ayrılsa/ölse de anı okunabilir kalsın.
  final String subjectName;

  /// Olayın yeri (tile).
  final double x, y;

  /// Kaydedildiği sim zamanı.
  final double at;

  /// Gözüyle mi gördü (true) yoksa anlatıldı mı (false).
  final bool firsthand;

  /// Tazelik/güç 0..1 — zamanla söner, sönünce anı düşer.
  double strength;

  Recollection({
    required this.kind,
    required this.subjectName,
    required this.x,
    required this.y,
    required this.at,
    required this.firsthand,
    this.subject,
    this.strength = 1.0,
  });

  /// Bu anı ihbar edilebilir mi — yalnız gözüyle görülmüş TAZE bir suç.
  bool get reportable =>
      kind == Notion.crime && firsthand && strength > 0.35 && subject != null;

  /// Anlatmaya değer mi — dedikodunun hammaddesi.
  bool get worthTelling => strength > 0.25;
}

/// KÖYLÜNÜN HAFIZASI — gördükleri + kime ne kadar güvendiği.
///
/// İki katman bilinçli olarak ayrı:
///   • [recollections] SÖNER — korku üç saniyede unutulmaz ama bir hafta da
///     sürmez; olayların kendisi geçicidir.
///   • [opinion] KALIR — olay unutulsa da bıraktığı kanaat kalır. "Kimin ne
///     yaptığını hatırlamıyorum ama ondan hoşlanmıyorum" insani ve ucuzdur.
class VillagerMemory {
  /// En yeni anılar önde. [kCapacity] ile sınırlı — hafıza sonsuz değil.
  final List<Recollection> recollections = [];

  /// Özne → kanaat (-1 düşman … +1 dost). Anahtarlar köylü nesnesi.
  final Map<Object, double> opinion = {};

  /// Bir köylünün taşıyabileceği en fazla anı. Aşılınca EN ZAYIF anı düşer
  /// (en eski değil: köyde dün olan bir cinayet, bugün görülen bir kavgadan
  /// daha kalıcı olmalı).
  static const int kCapacity = 8;

  /// Anıların sönme hızı (güç/sn cinsinden değil, gün başına). Sahne bunu
  /// oyun günü uzunluğuna bölerek uygular.
  static const double kFadePerDay = 0.55;

  /// Kanaatin nötre dönüş hızı (gün başına) — kin de sevgi de bakımsız kalırsa
  /// yavaşça soğur, ama anılardan çok daha yavaş.
  static const double kOpinionCoolPerDay = 0.06;

  bool get isEmpty => recollections.isEmpty;

  /// Yeni bir anı ekle. Aynı özne + aynı tür için TAZE bir kayıt varsa yenisi
  /// eklenmez, mevcut olan güçlendirilir — yoksa tek bir kavga sahnesi köylünün
  /// hafızasını sekiz kopyayla doldururdu.
  ///
  /// Dönüş: gerçekten YENİ bir anı mı (tepki/ihbar bunun üstünden tetiklenir).
  bool remember(Recollection r, {double mergeWindow = 30.0}) {
    for (final old in recollections) {
      if (old.kind != r.kind) continue;
      if (!identical(old.subject, r.subject)) continue;
      if ((r.at - old.at).abs() > mergeWindow) continue;
      // Aynı olayın tekrar görülmesi anıyı tazeler; ikinci kez kaydetmez.
      old.strength = old.strength > r.strength ? old.strength : r.strength;
      return false;
    }

    recollections.insert(0, r);
    if (r.subject != null) {
      final shift = notionOpinionShift(r.kind) * (r.firsthand ? 1.0 : 0.45);
      if (shift != 0) nudgeOpinion(r.subject!, shift);
    }
    if (recollections.length > kCapacity) {
      var weakest = 0;
      for (var i = 1; i < recollections.length; i++) {
        if (recollections[i].strength < recollections[weakest].strength) {
          weakest = i;
        }
      }
      recollections.removeAt(weakest);
    }
    return true;
  }

  /// Kanaati oynat (sınırlar içinde).
  void nudgeOpinion(Object who, double delta) {
    opinion[who] = ((opinion[who] ?? 0) + delta).clamp(-1.0, 1.0);
  }

  double opinionOf(Object who) => opinion[who] ?? 0;

  /// Zamanı ilerlet: anılar söner, sönenler düşer, kanaatler nötre yaklaşır.
  void fade(double dtDays) {
    if (dtDays <= 0) return;
    final drop = kFadePerDay * dtDays;
    recollections.removeWhere((r) {
      r.strength -= drop;
      return r.strength <= 0.05;
    });

    final cool = kOpinionCoolPerDay * dtDays;
    opinion.removeWhere((_, v) => v.abs() <= cool);
    for (final k in opinion.keys.toList()) {
      final v = opinion[k]!;
      opinion[k] = v > 0 ? v - cool : v + cool;
    }
  }

  /// İhbar edilebilir en güçlü anı (yoksa null).
  Recollection? get strongestReportable {
    Recollection? best;
    for (final r in recollections) {
      if (!r.reportable) continue;
      if (best == null || r.strength > best.strength) best = r;
    }
    return best;
  }

  /// Anlatmaya en değer anı — dedikodunun konusu.
  Recollection? get strongestTellable {
    Recollection? best;
    for (final r in recollections) {
      if (!r.worthTelling) continue;
      if (best == null || r.strength > best.strength) best = r;
    }
    return best;
  }

  /// Bu anıyı zaten biliyor mu (dedikodunun aynı kişiye tekrar tekrar
  /// anlatılmasını engeller).
  bool knows(Notion kind, Object? subject) {
    for (final r in recollections) {
      if (r.kind == kind && identical(r.subject, subject)) return true;
    }
    return false;
  }

  /// Belirli bir köylüyü suçlu olarak hatırlıyor mu — kaçınma davranışının
  /// ve kurban seçiminin kaynağı.
  bool suspects(Object who) {
    for (final r in recollections) {
      if (r.kind == Notion.crime && identical(r.subject, who)) return true;
    }
    return false;
  }

  /// Panelde okunur özet — en taze birkaç anı.
  List<String> readout({int max = 3}) {
    final out = <String>[];
    for (final r in recollections) {
      if (out.length >= max) break;
      final who = r.subjectName.isEmpty ? '' : ' (${r.subjectName})';
      final hand = r.firsthand ? '' : ' — kulaktan';
      out.add('${notionLabel(r.kind)}$who$hand');
    }
    return out;
  }
}
