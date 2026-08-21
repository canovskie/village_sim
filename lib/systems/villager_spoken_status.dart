import '../entities/villager_entity.dart';
import '../entities/villager_job.dart';
import 'villager_mind.dart';

/// Bir köylünün tek tıkta kendi ağzından söylediği anlık durum.
///
/// Öncelik ekranda görünen gerçeğe aittir: özel sahne/rahatsızlık, yürüyen
/// mikro-eylem, taşıma, aktif meslek, sonra niyet. Böylece cümle ayrı bir UI
/// tahmini değil, köylünün mevcut state-machine'inin kısa tercümesidir.
String villagerSpokenStatus(VillagerEntity v) {
  if (v.activity == VillagerActivity.abducted) return 'Beni kaçırdılar!';
  if (v.isDying) return 'İyi değilim...';
  if (v.isLeaving) return 'Köyden ayrılıyorum.';
  if (v.laborDays > 0) return 'Cezam için kürek çekiyorum.';
  if (v.sickDays > 0) return 'Hastayım, dinlenmeye çalışıyorum.';
  if (v.injuryDays > 0) return 'Yaralıyım, ağır hareket ediyorum.';

  final activity = switch (v.activity) {
    VillagerActivity.chat => 'Bir köylüyle sohbet ediyorum.',
    VillagerActivity.music => 'Köye bir ezgi çalıyorum.',
    VillagerActivity.dance => 'Meydanda oynuyorum.',
    VillagerActivity.warm => 'Ateşin başında ısınıyorum.',
    VillagerActivity.storytelling => 'Bir hikâye anlatıyorum.',
    VillagerActivity.listening => 'Anlatılanları dinliyorum.',
    VillagerActivity.arguing => 'Biriyle atışıyorum.',
    VillagerActivity.brawling => 'Kavgaya tutuldum.',
    VillagerActivity.watchingConflict => 'Kavgaya bakmaya koştum.',
    VillagerActivity.prowling => 'Kimse görmeden dolaşıyorum.',
    VillagerActivity.committing => 'Başımı belaya sokuyorum.',
    VillagerActivity.fleeing => 'Buradan kaçıyorum!',
    VillagerActivity.chasing => 'Birinin peşindeyim.',
    VillagerActivity.playing => 'Arkadaşlarımla oynuyorum.',
    VillagerActivity.none || VillagerActivity.abducted => null,
  };
  if (activity != null) return activity;

  if (v.isSleeping) return 'Uyuyorum.';
  if (v.isSeatedAtFire) return 'Ateşin başında soluklanıyorum.';

  final act = switch (v.act?.label) {
    'kuyudan su taşıyor' => 'Kuyudan su taşıyorum.',
    'pazardan alışveriş' => 'Pazardan alışveriş yapıyorum.',
    'meyhanede oturuyor' => 'Meyhanede soluklanıyorum.',
    'ambarda iş görüyor' => 'Ambarda iş görüyorum.',
    'ateşe odun getiriyor' => 'Ocağa odun getiriyorum.',
    'evinde soluklanıyor' => 'Evimde soluklanıyorum.',
    'köyde bir işi var' => 'Köyde bir işin peşindeyim.',
    _ => null,
  };
  if (act != null) return act;

  if (v.state == VillagerState.walkingToPickup) {
    return 'Taşıyacağım ürünü almaya gidiyorum.';
  }
  if (v.state == VillagerState.carrying) {
    return 'Ürünü ambara götürüyorum.';
  }

  final job = v.job;
  if (job != null && job.role != JobRole.none) {
    final active = job.working || job.harvesting || job.carryingWater;
    if (active) return _workingLine(job.role);
    if (v.state == VillagerState.moving && v.mind.owns(IntentKind.work)) {
      return 'İşimin başına gidiyorum.';
    }
  }

  return switch (v.mind.intent.kind) {
    IntentKind.work => 'İşimin başına dönüyorum.',
    IntentKind.errand =>
      v.isWalking ? 'Köydeki işime gidiyorum.' : 'Köyde bir iş görüyorum.',
    IntentKind.hearth => 'Isınmak için ocağa gidiyorum.',
    IntentKind.social => 'Biraz insan içine karışıyorum.',
    IntentKind.worship => 'İbadete gidiyorum.',
    IntentKind.rest => 'Dinlenmeye çekiliyorum.',
    IntentKind.forage => 'Geçimim için bir şeyler topluyorum.',
    IntentKind.inform => 'Gördüğümü devriyeye anlatmaya gidiyorum.',
    IntentKind.crime => 'Kimseye görünmeden bir iş çeviriyorum.',
    IntentKind.quarrel => 'Bir anlaşmazlığın içindeyim.',
    IntentKind.flee => 'Tehlikeden uzaklaşıyorum.',
    IntentKind.ceremony => 'Köyün törenine katılıyorum.',
    IntentKind.idle =>
      v.isWalking ? 'Biraz dolaşıyorum.' : 'Şimdilik soluklanıyorum.',
  };
}

String _workingLine(JobRole role) => switch (role) {
  JobRole.builder => 'Yapıyı inşa ediyorum.',
  JobRole.farmer => 'Toprağı işliyorum.',
  JobRole.miner => 'Cevher çıkarıyorum.',
  JobRole.fisher => 'Balık tutuyorum.',
  JobRole.florist => 'Çiçeklerle ilgileniyorum.',
  JobRole.shepherd => 'Sürüyle ilgileniyorum.',
  JobRole.woodcutter => 'Ağaç kesiyorum.',
  JobRole.forager => 'Böğürtlen topluyorum.',
  JobRole.cook => 'Yemek pişiriyorum.',
  JobRole.weaver => 'Kışlık dokuyorum.',
  JobRole.none => 'Şimdilik soluklanıyorum.',
};
