import '../characters/villager_type.dart';
import '../characters/life_stage.dart';

/// Köyün zümreleri (hizipleri) — yönetişimin kalbi. Oyuncu "politik dengeci":
/// her kararı zümrelerin MORALİNİ (memnun↔küskün) ve NÜFUZUNU (köy ona ne kadar
/// kaydı) oynatır. Kimseyi tam memnun edemezsin — birini sevindirmek çoğu kez
/// diğerini gücendirir. Kaybetmek yok (cozy): küskün zümre köyde GÖRÜNÜR olur
/// (somurtan köylüler, sönük etkinlik), oyunu bitirmez.
///
/// Nüfuz zamanla birikir ve sönmez → köy yavaşça bir KİMLİĞE kayar (bkz.
/// [EstateSystem.ascendant]). Tek "doğru" yok; kimlik kazanmak ödüldür.
enum Estate {
  /// 🌾 Çiftçi + oduncu + madenci + balıkçı — toprağın ve emeğin sesi.
  laborers('Emekçiler', '🌾', 'Bereketli Köy'),

  /// 🔨 Tüccar + demirci — pazarın, zanaatın, keseyi dolduranların sesi.
  artisans('Zanaatkârlar', '🔨', 'Zanaat Kasabası'),

  /// 🕯️ Büyücü + inananlar (cult/kilise) — inancın, ayinin, mananın sesi.
  faithful('İnananlar', '🕯️', 'Kutsal Köy'),

  /// 🏡 Yaşlılar + aileler + ocağı bekleyenler — gelenek ve yuva sesi.
  hearth('Ocak', '🏡', 'Köklü Yuva');

  final String label;
  final String icon;

  /// Bu zümre baskın olursa köyün kayacağı kimlik adı.
  final String identity;
  const Estate(this.label, this.icon, this.identity);
}

/// Bir köylünün hangi zümreye ait olduğunu mesleğe + yaşam evresine göre verir.
/// Diegetik geri bildirimde (küskün zümre postürü) ve sözcü seçiminde kullanılır.
/// Yaşlı her meslekten olsa da önce OCAK'ın sesidir (gelenek/yuva).
Estate estateOfVillager(VillagerType type, LifeStage stage) {
  if (stage == LifeStage.elder) return Estate.hearth;
  switch (type) {
    case VillagerType.farmer:
    case VillagerType.miner:
    case VillagerType.fisher:
      return Estate.laborers;
    case VillagerType.merchant:
    case VillagerType.blacksmith:
      return Estate.artisans;
    case VillagerType.mage:
      return Estate.faithful;
    case VillagerType.guard:
      return Estate.hearth; // yuvanın bekçisi
  }
}

/// Bir zümrenin morali hangi kademede — yüz ikonu + diegetik tepki bunun üstünden.
enum EstateMoodTier {
  content('😊'),  // memnun
  neutral('😐'),  // kayıtsız
  uneasy('😟'),   // tedirgin
  sullen('😠');   // küskün

  final String face;
  const EstateMoodTier(this.face);
}

// NOT (2026-07-12): Zümre→Hane geçişi tamamlandı. Politik durum/motor artık
// [HouseSystem] (systems/house_system.dart). Eski EstateSystem/EstateState/
// EstateSnapshot sınıfları hiç örneklenmiyordu (ölü kod) → kaldırıldı. Yukarıdaki
// [Estate] enum + [estateOfVillager] + [EstateMoodTier] CANLI: meslek→hizip
// sınıflandırması ve mood kademesi olarak hâlâ her yerde kullanılıyor.
