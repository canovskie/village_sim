/// Bir köylünün ÜSTLENDİĞİ iş (geçici atama) — anonim işçi avatarlarının yerini
/// alır. Kritik ilke: iş, köylünün gövdesini PUPPET ETMEZ. İş yalnızca "ne
/// yapılacağına" karar verir ([_SceneWork] içindeki `_workBuilder/_workFarmer/…`
/// döngüleri) ve hedefi `v.goTo(...)` ile verir; hareketi köylünün KENDİ
/// `update()`'i yürütür (iki gövde-sürücüsü çakışması olmaz).
///
/// [JobRole] köylünün baz mesleğinden ([VillagerType]) BAĞIMSIZDIR: builder/
/// woodcutter/florist'in meslek karşılığı yok (herhangi boş yetişkin üstlenir);
/// miner/fisher/shepherd/farmer'da baz meslek eşleşmesi tercih edilir. Böylece
/// yeni VillagerType eklemenin 9-yer checklist'i tetiklenmez ve panelde çift
/// kimlik okunur: "Çiftçi — şu an ambar inşa ediyor".
enum JobRole {
  none,
  builder,
  farmer,
  miner,
  fisher,
  florist,
  shepherd,
  woodcutter,

  /// Böğürtlen çalılarını toplar → ham yiyecek. Bina istemez: ilk günden
  /// yapılabilen tek üretim işi, kuruluş kademesinin omurgası.
  forager,

  /// Ocak başında ham yiyeceği pişirir → doyuran yiyecek. Ateş yeri ister.
  cook,

  /// Yünü kışlık giysiye çevirir. KIŞIN İŞİ: tarla donunca kadro boşa
  /// düşmesin diye var — bina istemez, ocağın ya da ambarın başında dokunur.
  weaver,
}

extension JobRoleLabel on JobRole {
  /// Aktif işin oyuncu-yüzü etiketi (panel/hover). none = boş.
  String get label => switch (this) {
    JobRole.none => '',
    JobRole.builder => 'İnşaatçı',
    JobRole.farmer => 'Çiftçi',
    JobRole.miner => 'Madenci',
    JobRole.fisher => 'Balıkçı',
    JobRole.florist => 'Çiçekçi',
    JobRole.shepherd => 'Çoban',
    JobRole.woodcutter => 'Oduncu',
    JobRole.forager => 'Toplayıcı',
    JobRole.cook => 'Aşçı',
    JobRole.weaver => 'Dokumacı',
  };

  /// Panel/künye ikonu — elle atama yüzeyinde rolü bir bakışta okutur.
  String get icon => switch (this) {
    JobRole.none => '🚫',
    JobRole.builder => '🔨',
    JobRole.farmer => '🌾',
    JobRole.miner => '⛏️',
    JobRole.fisher => '🎣',
    JobRole.florist => '🌷',
    JobRole.shepherd => '🐄',
    JobRole.woodcutter => '🪓',
    JobRole.forager => '🧺',
    JobRole.cook => '🍲',
    JobRole.weaver => '🧶',
  };
}

/// Köylüye takılan geçici iş durumu (kompozisyon; [VillagerEntity.job]).
/// Faz/sayaç/claim ile çok-evreli üretimi sıralar; render bayraklarını da tutar
/// ki çizim katmanı ([_VillagerDrawable]) doğru sprite/aleti/çubuğu göstersin.
/// Faz-özel alanlar geçicidir (kayıtta yalnız [role] tutulur; kalanı ilk tick'te
/// iş döngüsü + `_syncJobWorkforce` yeniden kurar — tıpkı `workCooldown` gibi).
class VillagerJob {
  VillagerJob(this.role);

  JobRole role;

  /// Rol-özel alt-durum (eski BuilderState/FarmerState yerine sıra numarası).
  int phase = 0;

  /// Birincil aksiyon sayacı (inşa/hasat/ekim/madencilik/kesim süresi).
  double timer = 0;

  /// İkincil sayaç (su alma / sulama gibi ayrık ikinci aksiyon).
  double timer2 = 0;

  /// Aksiyonlar arası nefes (ör. çiftçinin su turu cooldown'u).
  double cooldown = 0;

  /// Birincil claim — üstünde çalışılan hedef (BuildOrder / RoadOrder /
  /// FarmTile / MineNode / ağaç tile'ı). Object? — döngüsel import kaçınılır,
  /// iş döngüsü cast eder.
  Object? claim;

  /// İkincil claim — ör. kuyu anchor slot'u (çiftçi sulama).
  Object? claim2;

  /// Üçüncül claim — ör. kuyu anchor point'i (slot'la beraber salınır).
  Object? claim3;

  // ── Render bayrakları (çizim katmanı okur) ────────────────────────────────
  /// İnşaatçı çekiçliyor / madenci kazıyor / oduncu kesiyor.
  bool working = false;

  /// Çiftçi tırpan/ekim eğilme hareketinde.
  bool harvesting = false;

  /// Çiftçi elinde su kovası (kuyuya/sulamaya).
  bool carryingWater = false;

  /// Aksiyon salınım fazı (çekiç/tırpan/kazma; 0..2π) — köylünün walkPhase'i
  /// dururken bunu sürer ki eylem animasyonu akıcı olsun.
  double phaseAnim = 0;

  /// İnşaat ilerleme çubuğu (0..1).
  double progress = 0;

  /// Su splash animasyon zamanı (>=0 ise ilk 0.4 sn'de splash çizilir; <0 kapalı).
  double splashTimer = -1;

  /// Hasat tamamlandığında dolu: sahne buradan [HayEntity] üretir. Her tick
  /// başında sıfırlanır (tek-atış sinyal).
  (int, int)? harvestHayPos;

  // ── Oyuncuya görünen iş ritmi ────────────────────────────────────────────
  /// O anki görünür çalışma vuruşunun geçen/toplam süresi. Hareket ve bekleme
  /// sırasında sıfırdır; çalışma başladığında scene_jobs aynı sayacı hem
  /// üretim mantığına hem panele yazar. Böylece panel ikinci bir tahmin hesabı
  /// yapmaz, motorun gerçekten okuduğu süreyi gösterir.
  double cycleElapsed = 0;
  double cycleDuration = 0;

  /// Bu atama boyunca tamamlanan somut iş sayısı. Kaydedilmez: bir ekonomi
  /// sayacı değil, oyuncunun açık panelde gördüğü kısa vardiya hafızasıdır.
  int completedCycles = 0;

  /// Temas sesi/partikülü aynı vuruşta bir kez çalışsın. Eğri temas
  /// penceresinden çıkınca scene_jobs yeniden kurar.
  bool impactLatched = false;

  void reportCycle(double elapsed, double duration) {
    cycleDuration = duration <= 0 ? 0 : duration;
    cycleElapsed = cycleDuration == 0 ? 0 : elapsed.clamp(0.0, cycleDuration);
  }

  void clearCycle() {
    cycleElapsed = 0;
    cycleDuration = 0;
  }

  void finishCycle() {
    completedCycles++;
    clearCycle();
  }

  /// Stuck-guard — çalışmıyorken (yürürken) yerinde ne kadar takıldığı (sn).
  /// Erişilemez hedefe path bulunamayınca köylü "moving"de donar; bu süre
  /// eşiği aşınca iş bırakılır (köye karışır). Hareket/çalışma sıfırlar.
  double stuckTimer = 0;
  double lastX = -999, lastY = -999;

  /// Bu köylünün işi bırakması — tüm faz/sayaç/claim sıfırlanır (claim'lerin
  /// SALIVERİLMESİ çağıranın sorumluluğu; burada yalnız referanslar temizlenir).
  void clear() {
    role = JobRole.none;
    phase = 0;
    timer = timer2 = cooldown = 0;
    claim = claim2 = claim3 = null;
    working = harvesting = carryingWater = false;
    phaseAnim = progress = 0;
    splashTimer = -1;
    harvestHayPos = null;
    cycleElapsed = cycleDuration = 0;
    completedCycles = 0;
    impactLatched = false;
  }
}
