import 'villager_entity.dart';
import 'villager_job.dart';

/// Bir iş yerinin NEREDEN doğduğu — panelin başlığı ve seçim yolu buradan
/// ayrışır (bina paneli mi, hafif iş yeri kartı mı).
enum WorkSiteKind {
  /// Ayakta duran bir bina: maden, iskele, ağıl, kereste kampı, ocak, ambar.
  building,

  /// Yükselmekte olan bir yapı ya da yol — kadrosu dolmadan gövde çıkmaz
  /// (bkz. [BuildOrder.crewReady]).
  construction,

  /// Köyün tarlaları — tek küme sayılır (kaç parsel olursa olsun bir iş yeri).
  field,

  /// Böğürtlenlik — bina istemeyen tek iş yeri. Doğa da bir iş yeridir:
  /// toplayıcının yuvası burada durur, yoksa oyunun ilk işi hiçbir yere
  /// tutunamazdı.
  patch,
}

/// İŞ YERİ — oyuncunun kadro verdiği YER.
///
/// Bu sınıf, iş vermenin kişiden yere taşınmasının taşıyıcısıdır. Eskiden
/// köylü panelinde on bir rol rozeti vardı ve oyuncu "Mehmet madenci olsun"
/// diyordu; oysa simülasyon hep "bu maden bir el ister" diye düşünüyordu
/// (bkz. `_syncJobWorkforce`). İki dil ayrıydı; rozetler o ayrığın üstünü
/// örten bir açılır listeydi.
///
/// [WorkSite] simülasyonun kendi cümlesini ekrana çıkarır: her iş yerinin
/// istediği el sayısı ([wanted]) ve o an başında duran kadrosu ([crew]) vardır.
/// Oyuncu boş yuvayı doldurur, dolu yuvayı boşaltır — rol seçmez, YER doldurur.
///
/// SALT OKUNUR ANLIK GÖRÜNTÜ: her çağrıda sahneden yeniden türetilir
/// (`_workSites()`), saklanmaz. Kalıcı olan tek şey köylünün üstündeki
/// [VillagerEntity.assignedSiteId] mührüdür.
class WorkSite {
  /// Kararlı kimlik — köylünün üstüne mühürlenir, kayda girer.
  ///
  /// Bina/şantiye için konumdan türer (`b:12,7`); tarla ve böğürtlenlik tek
  /// küme sayıldığı için sabittir (`field` / `patch`). Küme merkezinden
  /// türetmedik: oyuncu bir parsel daha açınca merkez kayar, kimlik değişir ve
  /// verilmiş bütün kadro sessizce kopardı.
  final String id;

  final WorkSiteKind kind;

  /// Bu yerin doğurduğu iş. Bir bina birden fazla iş yeri barındırabilir
  /// (ocak: aşçı + —ambar yoksa— dokumacı), o yüzden rol binada değil burada.
  final JobRole role;

  /// Panel başlığı — "Maden Ocağı", "Böğürtlenlik", "Şantiye · Ambar".
  final String label;

  /// KÖYÜN İSTEDİĞİ el sayısı. Otomatik kadro ([_reconcileRole]) bu sayıyı
  /// hedefler; oyuncu üstüne çıkabilir (fazladan el bir hata değil, bir karar).
  final int wanted;

  /// Grid merkezi — kamera ve öğretici ışığı buraya bakar.
  final double cx, cy;

  /// [BuildingEntity] | [BuildOrder] | [RoadOrder] | null (tarla/böğürtlenlik).
  final Object? source;

  /// Şu an bu yerin başında olan köylüler — hem oyuncunun mühürledikleri hem
  /// otomatik kadronun yolladıkları.
  final List<VillagerEntity> crew;

  /// Bu işi BUGÜN yapmak neden mümkün değil (göl dondu, yün bitti, tarla
  /// karın altında). null = iş yürüyor. Yuvayı KAPATMAZ — yalnız söyler;
  /// oyuncu yine de kadro bırakabilir (mevsim döner).
  final String? idleReason;

  const WorkSite({
    required this.id,
    required this.kind,
    required this.role,
    required this.label,
    required this.wanted,
    required this.cx,
    required this.cy,
    required this.crew,
    this.source,
    this.idleReason,
  });

  /// Panelde çizilecek yuva sayısı — dolu olanlar + HER ZAMAN bir boş yuva.
  ///
  /// Sondaki boş yuva bir süs değil: köyün istediğinden fazla el vermek
  /// (üç oduncu tek kampa) geçerli bir karardır ve bugüne dek mümkündü
  /// (bkz. `_reconcileRole`'ün elle-atanmışa dokunmama kapısı). Yuva sayısını
  /// [wanted]'a kilitleseydik o kararı sessizce elinden almış olurduk.
  int get slots => wanted > crew.length ? wanted : crew.length + 1;

  /// [wanted]'ın üstündeki yuvalar — panelde "fazladan" diye soluk çizilir.
  bool isExtraSlot(int index) => index >= wanted;

  /// Kadro tam mı (köyün istediği kadar el var mı).
  bool get staffed => crew.length >= wanted;

  /// Kimse yok ama köy istiyor — panelin ve künyenin uyarı hâli.
  bool get starving => wanted > 0 && crew.isEmpty;
}
