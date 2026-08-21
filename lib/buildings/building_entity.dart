import 'building_function.dart';
import 'building_type.dart';

/// [BuildingEntity.ownerSurname] için özel değer: mülk artık kimsenin değil,
/// KÖYÜN (topyekûn el koyma / kamulaştırma sonrası).
const String kPublicOwner = '\u0000köy';

class BuildingEntity {
  final BuildingType type;
  final int col;
  final int row;

  /// Maden ocağı gibi içeride çalışma olan binalar için
  bool isActive = false;

  /// Oyuncu binayı manuel olarak duraklattıysa true — gathering/processing
  /// rolündeki binalar tick'te bu bayrağa göre işçi/üretim çalıştırmayı atlar.
  bool userPaused = false;

  // ── İşlevsel durum (building_system tarafından yönetilir) ──────────────────

  /// Pazar pasif gelir zamanlayıcısı (saniye).
  double incomeTimer = 0.0;

  /// Konut su deposu 0..1 (yalnızca housing). Sakinler tüketir, kuyu doldurur.
  /// Boşalınca köy morali düşer. Yeni ev dolu başlar.
  double waterLevel = 1.0;

  /// Bu evde yaşayan köylü sayısı — main her tick günceller (su tüketimi için).
  int occupants = 0;

  /// PENCERE IŞIĞI (0 sönük ↔ 1 tam yanar). Sakinlerin UYANIK oranından türer
  /// ve yumuşak akar: son uyuyan yatınca evin camı birkaç saniyede söner,
  /// biri kalkınca yeniden yanar.
  ///
  /// Neden var: gece kurulmadan önce bütün evler sabaha kadar aynı parlaklıkta
  /// yanıyordu — köyün "yattığı" hiçbir yerde görünmüyordu. Tek alan iki
  /// tüketiciyi birden besler (yerdeki halo `LightingSystem.collect` +
  /// sprite üstündeki cam parlaması `BuildingRenderer`), böylece ikisi
  /// birbirinden ayrışamaz.
  ///
  /// KAYDEDİLMEZ: türetilmiş bir değer, yüklemeden sonra birkaç saniyede
  /// kendi doğru değerine oturur.
  double windowGlow = 1.0;

  /// Yapının görünen hasar seviyesi (0 = sağlam, 1 = ağır yanık/hasar).
  ///
  /// Yangın ve vandalizm bunu yükseltir; ekonomik ceza yerine dünyada kalan
  /// okunaklı izdir. Kaydedilir: oyuncu yangından sonra aynı tertemiz evi
  /// görerek ne olduğunu unutmasın.
  double damage = 0.0;

  /// [occupants]'ın UYANIK olanı — [windowGlow]'un hedefi buradan çıkar.
  /// Doluluk sayımıyla aynı geçişte tazelenir (bkz. _tickPopulationAndHunger).
  int awakeOccupants = 0;

  /// MÜLK SAHİBİ hane (soyad). Boş = sahibi sakinlerden TÜRETİLİR (kimin evinde
  /// kim oturuyorsa onun sayılır). Bağışlanan mülkte açıkça yazılır; topyekûn
  /// el koymadan sonra [kPublicOwner] olur (mülk köyün).
  String ownerSurname = '';

  /// İnşa tamamlanma anındaki sahne zamanı. _BuildingDrawable ilk birkaç
  /// saniyede scale pop + toz bulutu çizer ("yeni doğmuş" hissi).
  /// 0 = henüz ayarlanmamış (eski binalar / world-init).
  double spawnTime = 0;

  /// Son satış anındaki sahne zamanı (yalnız market). 0 = hiç satış yok.
  /// _BuildingDrawable bunu okuyup 1 sn'lik altın parıltısı animasyonu çizer.
  double lastSaleTime = 0;

  /// Geçici yas işareti — bu evden biri öldüğünde çatının üstünde belirir.
  /// Kayıt edilmez; yalnızca ölümün dünya üzerindeki kısa görsel yankısıdır.
  double deathMarkerUntil = 0;
  int deathMarkerCount = 0;

  /// Tavuk kümesi yumurta zamanlayıcısı (saniye). Her tick artar; eşiği
  /// aşınca +1 food üretir, sıfırlanır. main.dart update loop yönetir.
  double eggTimer = 0.0;

  /// Arı kovanı bal zamanlayıcısı (saniye). Her tick çiçek-sayısı çarpanıyla
  /// artar; eşiği aşınca +1 bal üretir, sıfırlanır. scene_tick yönetir.
  double honeyTimer = 0.0;

  /// Ateş yeri yakıt seviyesi 0..1 (yalnız firepit için anlamlı). Zamanla
  /// tükenir; ateşçi odun taşıyıp doldurur. 0 olunca ateş söner (alev+ışık
  /// gider, köy çapı huzursuzluk). scene_fire yönetir.
  double fireFuel = 1.0;

  /// Bu binanın BAŞINDA görevli bir köylü duruyor mu (yalnız post-işi olan
  /// binalar: değirmen…). scene_work her taramada tazeler; verim/panel buradan
  /// okur — "işçi orada mı" sorusunun tek doğruluğu. Geçici, kaydedilmez.
  bool staffed = false;

  /// Değirmen öğütme sayacı (saniye, yalnız mill). Balya teslim edilince
  /// [kMillGrindSeconds] olur, scene_tick her tick azaltır; >0 iken değirmen
  /// çalışıyor (isActive=duman + panel "Çalışıyor"). Geçici — kaydedilmez.
  double grindPulse = 0.0;

  /// Değirmen rotorunun son açısı (radyan). Değirmen duraklatılmadığı sürece
  /// ilerler; sim durunca veya duraklatılınca kanatlar bulunduğu açıda kalır.
  /// Kayıtta tutulur ki yükleme sırasında X pozuna sıçramasın.
  double millRotorAngle = 0.0;

  /// Ambara/ocağa somut bir ürün indiğinde başlayan kısa dünya tepkisi. Panel
  /// bildirimi değil: bina avlusundaki kasa/çuval yerleşmesi ve küçük oturma
  /// darbesi bunu okur. Türetilmiş/geçici olduğu için kayda girmez.
  double deliveryPulse = 0.0;

  /// Bu oturumda binaya inen ürün sayısı. Ekonominin kendisi değildir; yalnız
  /// avludaki 1-3 parçalık görsel yığının yoğunluğunu belirler.
  int deliveryTally = 0;

  BuildingEntity({required this.type, required this.col, required this.row});

  int get cols => kBuildingMeta[type]!.cols;
  int get rows => kBuildingMeta[type]!.rows;

  /// İşlevsel tanım (rol, kapasite, civic etki...). Tanımsızsa null.
  BuildingFunction? get fn => kBuildingFunctions[type];

  /// Depth for painter's algorithm: front corner col+row sum
  double get depth => (col + cols + row + rows).toDouble();
}
