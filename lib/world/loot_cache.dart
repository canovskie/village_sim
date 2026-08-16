import '../core/resources.dart';

/// GÖMÜLÜ ZULA — hırsızın kaçarken toprağa gömdüğü çuval.
///
/// Faz 4'ün sözleşmesi: **gömmek bir jest değil, bir yer.** Sırf gövde dili
/// olarak toprağı eşeleyen hırsız, tam da "yapmak için yapılmış" olurdu — mal
/// buharlaşır, oyuncu için hiçbir şey değişmezdi. Zula dünyada DURUR: bulunur,
/// kazılır, mal köye döner ve failin adı ele verilir.
///
/// Çalınan mal bu yüzden anında yok olmaz; köyün stoğundan çıkar ama **hâlâ
/// köyün toprağındadır**. Hırsızlığın geri alınabilir olması, onu komik bir
/// sayı düşüşü olmaktan çıkarıp bir kovalamacaya çevirir.
class LootCache {
  /// Gömüldüğü nokta (tile).
  final double gridX, gridY;

  /// İçindeki mal.
  final ResourceKind kind;
  final int amount;

  /// ResourceKind dışında tutulan özel ganimet (eski kayıtlarla uyumlu).
  final int weaponAmount;

  /// Gömen köylü — yakalanınca zula onu ele verir. Köylü sahneden çıkarsa
  /// (ölüm/sürgün) referans koparılır, zula toprakta kalır: mal geri alınabilir
  /// ama artık kimseyi suçlamaz.
  Object? culprit;

  /// Failin gömme anındaki adı — köylü gitse de vakanüvis bir ad yazabilsin.
  final String culpritName;

  /// Gömüldükten bu yana geçen süre (sn). Taze toprak ele verir, zamanla kapanır.
  double age = 0;

  /// Gömerken GÖRÜLDÜ mü.
  ///
  /// Hırsızın asıl hatası budur. Kimse görmediyse iz kapanır ve zula fiilen
  /// kaybolur (mal köyün elinden çıkmıştır — hırsızlığın gerçek kazancı).
  /// Ama biri gömerken gördüyse köy YERİ kabaca bilir: iz kapansa da oraya
  /// bakılır. "Nerede gömdüğün" değil, "görülüp görülmediğin" belirleyici.
  bool witnessed = false;

  LootCache({
    required this.gridX,
    required this.gridY,
    required this.kind,
    required this.amount,
    required this.culpritName,
    this.weaponAmount = 0,
    this.culprit,
  });

  /// İzo derinlik sıralaması (painter's algo) — diğer dünya nesneleriyle aynı.
  double get depth => gridX + gridY;
}

/// Taze toprağın ele verme gücü (1 = yeni eşelenmiş, 0 = iz kapandı).
///
/// Gömüldüğü an iz bellidir; [fade] süresi boyunca ot kapanır ve zula yalnız
/// üstüne basılırsa bulunur. "Hemen gömüp kurtuldum" ile "geç kaldım" arasındaki
/// farkı bu eğri kurar: hırsızın kaçış hızı gerçekten işe yarar.
/// [witnessed] ise iz hiç tam kapanmaz: köy yeri kabaca bilir, oraya bakar.
/// Taban ([kWitnessedTraceFloor]) tazeliğin yerini alır — zula "kayıp" değil
/// "henüz kazılmamış" olur.
double lootTrace(double age, double fade, {bool witnessed = false}) {
  final t = fade <= 0 ? 0.0 : (1.0 - age / fade).clamp(0.0, 1.0);
  return witnessed && t < kWitnessedTraceFloor ? kWitnessedTraceFloor : t;
}

/// Görülerek gömülen zulanın iz tabanı — bulunması zaman alır ama olur.
const double kWitnessedTraceFloor = 0.55;

/// Bir arayanın zulayı fark edebileceği yarıçap (tile).
///
/// Taze izde geniş, kapanmış izde neredeyse sıfır — ama hiç sıfır değil:
/// üstüne basan bulur. Muhafızın görüşü ([alert]) izi büyütür.
double lootFindRadius(
  double trace, {
  double maxRadius = 3.6,
  double minRadius = 0.8,
  double alert = 1.0,
}) => (minRadius + (maxRadius - minRadius) * trace) * alert;
