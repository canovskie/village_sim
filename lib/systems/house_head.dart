import '../characters/life_stage.dart';
import '../entities/villager_entity.dart';

/// HANE REİSİ seçimi — bir soyu (haneyi) temsil edecek GERÇEK köylüyü bulur.
///
/// Divan'ın meclis masasında oturan yüzler buradan gelir; masaya rastgele
/// figür konmaz, oyuncunun köyde tanıdığı kişiler oturur.
///
/// Kural (sırayla):
///  1. Soyun en yaşlı YETİŞKİN ERKEĞİ — soy erkek üzerinden yürüdüğü için
///     hanenin reisi de odur (bkz. tek-soy modeli).
///  2. Yetişkin erkek yoksa: en yaşlı yetişkin (kadın reis).
///  3. Hiç yetişkin yoksa: en yaşlı üye — öksüz hane de masada temsil edilir.
///
/// DETERMİNİSTİK: aynı üye listesi her zaman aynı reisi verir (rastgelelik yok).
/// Yaşlar eşitse ad alfabetik olarak sıra kırılır → liste sırası değişse bile
/// (tick'te köylüler yer değiştirir) masadaki yüz zıplamaz.
///
/// Ölmekte olanlar (`isDying`) çağıran tarafından elenmiş olmalıdır.
VillagerEntity? headOfHouse(List<VillagerEntity> members) {
  if (members.isEmpty) return null;

  final adults = members.where((v) => v.lifeStage.hasProfession).toList();
  // Erkek tercihi YALNIZ yetişkinler arasında geçerli. Hane tümüyle çocuklardan
  // ibaretse (öksüz hane) soyu en yaşlı olan temsil eder — yoksa kucaktaki
  // bebek erkek, ablasının önüne geçip masaya otururdu.
  final List<VillagerEntity> pick;
  if (adults.isNotEmpty) {
    final males = adults.where((v) => v.isMale).toList();
    pick = males.isNotEmpty ? males : adults;
  } else {
    pick = [...members];
  }

  pick.sort((a, b) {
    final byAge = b.ageDays.compareTo(a.ageDays); // en yaşlı önce
    if (byAge != 0) return byAge;
    return a.name.compareTo(b.name); // kararlı sıra kırıcı
  });
  return pick.first;
}
