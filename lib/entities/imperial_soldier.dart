import '../characters/villager_type.dart';
import '../characters/npc_visual.dart';
import '../characters/life_stage.dart';
import 'villager_entity.dart';

/// İmparatorluk vergici heyetinin FİZİKSEL askeri — köye dışarıdan formasyonla
/// yürüyerek gelen geçici varlık (bkz. scene_imperial). Görsel/animasyon olarak
/// bir [VillagerEntity] ([NpcCostume.imperial] kostümü → koyu çelik zırh + kızıl
/// tabard + miğfer) ama köyün SAKİNİ DEĞİL: ayrı `_soldiers` listesinde tutulur,
/// `update()` (yaşlanma/iş/doğurganlık) çağrılmaz, hareketini sahne yürütür.
/// Kayda yazılmaz — ziyaret bitince listeden silinir (tüccar/kuş gibi geçici).
///
/// Formasyon: heyet bir "çapa" (komutanın hedefi) etrafında dizilir. Her asker
/// çapaya göre [backOffset] (yürüyüş yönünde geri) + [sideOffset] (yana) kadar
/// kaymış bir slotu hedefler → kolon/saf düzeninde yürürler.
class ImperialSoldier extends VillagerEntity {
  /// Heyetin lideri mi — komutan en önde (slot 0), uzun kızıl sorguç + pelerin.
  final bool commander;

  /// Yürüyüş yönünde çapanın GERİSİNDE durma mesafesi (tile). 0 = çapada (komutan).
  final double backOffset;

  /// Yürüyüş yönüne dik YANA kayma (tile). Saf genişliği.
  final double sideOffset;

  /// true → çıkışa vardı, sahne listeden çıkarmalı.
  bool finished = false;

  ImperialSoldier({
    required super.startCol,
    required super.startRow,
    required this.commander,
    required this.backOffset,
    required this.sideOffset,
    int? seed,
  }) : super(
          type: VillagerType.guard, // animasyon iskeleti; kostüm görünümü ezer
          name: commander ? 'İmparatorluk Komutanı' : 'İmparatorluk Askeri',
          male: true,
          visualSeed: seed,
          ageDays: kAdultStartDay, // yetişkin; "çağrı" anı tetiklenmesin
        ) {
    costume = NpcCostume.imperial;
    imperialCommander = commander;
  }

  /// Sahne her tick çağırır — atanmış slot hedefine ([tx],[ty]) yürür. Varışta
  /// [isWalking]=false (yerinde bekler). VillagerEntity.update'in aksine AI yok.
  /// Dönüş: hedefe (yaklaşık) vardı mı.
  bool stepTo(double dt, double tx, double ty,
      {double dayLight = 1.0,
      double rainIntensity = 0.0,
      double speedMul = 1.0,
      double arriveD = 0.18}) {
    isWalking = true;
    final arrived = moveTowards(tx, ty, dt * speedMul, arriveD: arriveD);
    if (arrived) isWalking = false;
    smoothMotion(dt);
    // Gece gelirlerse meşale yansın (heyet meşaleli gelir). finished → söner.
    tickTorch(dt, dayLight, rainIntensity, eligibleOverride: !finished);
    return arrived;
  }
}
