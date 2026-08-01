/// KÖYÜN ÂDETİ — kural değil, huy.
///
/// Bu köyde işin bir usulü vardır: baltayı erkek sallar, böğürtleni kadın
/// toplar. Oyun bunu ENGELLEMEZ. Oyuncu âdete aykırı atama yapabilir; bedeli
/// üç ayrı yerden çıkar:
///   1. iş daha yavaş yürür ([JobCustom.speedMul]),
///   2. köy arkadan konuşur (dedikodu + moral; bkz. `scene_custom`),
///   3. öğretici bir kez, nazikçe uyarır (aynı rol için tekrar etmez).
///
/// "Yapamaz" demekle "burada böyle yapılmaz" demek farklı şeylerdir; bu dosya
/// ikincisini modeller. Bu yüzden hiçbir yerde buton kapatmaz, atama reddetmez —
/// yalnızca bir YARGI döndürür.
///
/// Neden ayrı ve SAF bir dosya: âdet bir sayı değil bir hükümdür. Panelde
/// gösterilen uyarı ile simin uyguladığı yavaşlama TEK kaynaktan çıkmalı; iki
/// listeye bölünürse panel "uygun" derken sim yavaşlatır (projenin daha önce
/// civicValue'da ödediği bedel).
library;

import '../entities/villager_job.dart';

/// Bir işin bir köylüye âdet gözüyle nasıl göründüğü.
enum CustomStance {
  /// Köyün usulüne uygun — kimse dönüp bakmaz.
  fitting,

  /// Âdetin sözü yok — kadın da erkek de yapar (tarla, çobanlık, inşaat).
  neutral,

  /// Âdete aykırı — yapılır ama yavaş yapılır ve köy konuşur.
  against,
}

/// Bir (rol, cinsiyet) çiftinin âdet karşısındaki hükmü.
class JobCustom {
  final CustomStance stance;

  /// İş hızı çarpanı. Aykırı atamada 1'in altındadır: köylü işi bilmediği,
  /// aleti ona göre olmadığı ve etraf karıştığı için ağır ilerler.
  /// UYGUN atamada 1.0 — âdete uymak ÖDÜL değil, normaldir; bonus verilseydi
  /// köyün tamamı tek kalıba sıkışırdı.
  final double speedMul;

  const JobCustom(this.stance, this.speedMul);

  bool get isAgainst => stance == CustomStance.against;
}

abstract final class VillageCustom {
  /// Aykırı atamanın hız cezası. 0.65: iş görünür biçimde ağırlaşır ama
  /// oyuncunun kararı boşa da çıkmaz — kadın oduncu odun getirir, sadece geç
  /// getirir. Daha sert bir değer (0.3) "engellendim" hissi verirdi ki bu
  /// bilinçli olarak istenmiyor.
  static const double againstSpeedMul = 0.65;

  /// Âdetin bu işi kime yakıştırdığı. `null` = âdetin sözü yok (nötr).
  ///
  /// Kapsam bilinçli olarak DAR: yalnız köyün gerçekten ayırdığı işler burada.
  /// Tarla, çobanlık ve inşaat köy hayatında ortak emektir — onları listeye
  /// koymak âdeti huy olmaktan çıkarıp kurala çevirirdi.
  static bool? _expectedMale(JobRole role) => switch (role) {
        // Balta, kazma, ağ: köyün "ağır iş" saydıkları.
        JobRole.woodcutter => true,
        JobRole.miner => true,
        JobRole.fisher => true,
        // Sepet ve ocak: köyün kadına yakıştırdıkları.
        JobRole.forager => false,
        JobRole.cook => false,
        JobRole.florist => false,
        // Ortak emek — âdet karışmaz.
        JobRole.farmer => null,
        JobRole.shepherd => null,
        JobRole.builder => null,
        JobRole.none => null,
      };

  /// Bu köylü bu işi üstlenirse köy ne der.
  static JobCustom judge(JobRole role, {required bool male}) {
    final want = _expectedMale(role);
    if (want == null) return const JobCustom(CustomStance.neutral, 1.0);
    if (want == male) return const JobCustom(CustomStance.fitting, 1.0);
    return const JobCustom(CustomStance.against, againstSpeedMul);
  }

  /// Kısayol — iş döngülerinin okuduğu tek sayı.
  static double speedMul(JobRole role, {required bool male}) =>
      judge(role, male: male).speedMul;

  /// Âdete aykırı mı — panel/uyarı kapısı.
  static bool isAgainst(JobRole role, {required bool male}) =>
      judge(role, male: male).isAgainst;
}
