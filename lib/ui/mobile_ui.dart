import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../systems/platform_adapt.dart';
import 'app_ui.dart';

/// Harness/test override — macOS'ta tablet TAKLİT edilirken dokunma
/// yerleşimini zorlar. Gerçek cihazda gerekmez ([PlatformAdapt.isMobile]
/// zaten true); yalnız önizleme ve widget testleri bunu kullanır.
bool debugForceTouchUi = false;

/// DOKUNMA yerleşimi mi? — [useCompactGameUi]'dan farklı olarak ekran ÖLÇÜSÜNE
/// değil ORTAMA bakar.
///
/// Ayrım şu yüzden gerekti: tablet (iPad 1180×820) yükseklik eşiğini geçtiği
/// için masaüstü yerleşimini alıyordu → ana menü ekranın altından taşıp
/// kaydırmaya düşüyordu. "Dar mı" (ölçü) ile "parmakla mı" (ortam) iki ayrı
/// sorudur:
///   • [useCompactGameUi] → ALÇAK ekran kroması (oyun HUD'ı sıkışsın mı?)
///   • [useTouchUi]       → dokunma yerleşimi (büyük hedef, kaydırmasız menü)
bool useTouchUi(BuildContext context) =>
    debugForceTouchUi || PlatformAdapt.isMobile || useCompactGameUi(context);

/// İnşa paletindeki gerçek bir araç/kart seçildiğinde kataloğun dünyayı örtmeye
/// devam etmemesi için yukarı doğru gönderilen niyet. Kategori sekmesi bunu
/// göndermez; oyuncu önce sekmeyi, sonra istediği aracı seçebilir.
class BuildCatalogCloseNotification extends Notification {
  const BuildCatalogCloseNotification();
}

/// ═══════════════════════════════════════════════════════════════════════════
/// MOBİL TEMA — "KENAR RAYI"
/// ═══════════════════════════════════════════════════════════════════════════
///
/// Telefonda oyun YATAY çalışır (bkz. systems/platform_adapt.dart): geniş ama
/// ALÇAK bir ekran. Orada kıt olan kaynak yükseklik, bol olan genişliktir.
/// Masaüstü yerleşimini küçültmek bu yüzden işe yaramadı — üst üste binen
/// levhalar ekranın yarısını yiyor, kalan her şey "ortada yüzen kutu" oluyordu.
///
/// Bu dosya TEMANIN KENDİSİDİR. Üç kural vardır, hiçbir yüzey tek başına
/// bunları bükmez:
///
///  1. **TEK YÜZEY** — bütün mobil kroma aynı opak grafit yüzeyi kullanır
///     ([MobileSurface]). Cam/bulanıklık yoktur: hareketli köy mobilde yüzeylerin
///     rengini ve okunurluğunu değiştirmez; HUD masaüstü panel diliyle aynıdır.
///
///  2. **TEK IZGARA** — kroma yalnız KENARA yapışır, ortası daima köydür.
///     Üstte TEK ince şerit (kaynaklar · saat · kontroller aynı satırda), altta
///     üç yuva (inşa · bağlam · kapılar). Hepsi aynı [gutter] boşluğunda.
///     "Şuraya bir kapsül daha koyayım" YOK — yeni bir şey bu beş yuvadan
///     birine girer ya da bir sayfaya ([MobileSheet]) gider.
///
///  3. **TEK TABAN** — telefonda 11px altı yazı ve 44dp altı dokunma hedefi
///     yoktur. Yazı tabanı tek tek fontSize avlayarak değil, ağacın kökünde
///     [mobileTextScaler] ile uygulanır.
///
/// Masaüstü bu dosyadan ETKİLENMEZ; her şey [useCompactGameUi] arkasındadır.
abstract final class MobileUi {
  // ── Izgara ────────────────────────────────────────────────────────────────

  /// Ekran kenarı ile kroma arasındaki tek boşluk. Her yerde bu.
  static const gutter = 8.0;

  /// Kroma nesneleri arası boşluk (kapsül ile kapsül arası).
  static const gap = 6.0;

  /// Tek yarıçap. Kapsül de sayfa da bunu kullanır → tek yüzey dili.
  static const radius = 12.0;

  /// Eylem kapsülü yüksekliği (alt şerit: inşa, bağlam, kapılar).
  static const actionH = 48.0;

  /// Apple HIG dokunma hedefi alt sınırı.
  static const tap = 44.0;

  /// Üst şerit yüksekliği — TEK satır: kaynaklar · saat · kontroller.
  /// Dokunma tabanına eşit; daha incesi düğmeleri 44dp'nin altına düşürürdü.
  /// Üstte ne varsa (rozetler, görev takipçisi) bu hattan aşağı hizalanır.
  static const barH = tap;

  /// Sağ sütun genişliği — üst şeridin altına hizalanan görev takipçisi bunu
  /// kullanır; sağ kenar tek bir hat olsun diye sabit.
  static const railW = 172.0;

  /// Telefonda okunabilirlik alt sınırı (bkz. [mobileTextScaler]).
  static const fontFloor = 11.0;

  /// iPhone 11 yatay için ana pencere bütçesi. Modal/defter ekranı bütünüyle
  /// kaplamaz; etrafında dünyayı ve kapatma perdesini okunur bırakan bir pay
  /// kalır. İçerik taşarsa pencere değil, kendi gövdesi kayar.
  static const windowMaxW = 760.0;
  static const windowMaxH = 360.0;

  // ── Yan sayfa (detay panelleri) ───────────────────────────────────────────

  /// Detay panelleri telefonda "yüzen kutu" değil, sağa yapışan TAM BOY sayfa
  /// olur. Genişlik: okunur bir sütun, ama dünyayı da göstermeye devam eden
  /// bir pay bırakır.
  static double sheetWidth(Size screen) =>
      math.min(304.0, math.max(272.0, screen.width * 0.34));

  // ── Yardımcılar ───────────────────────────────────────────────────────────

  /// Kroma bandının üst kenarı (çentik + gutter).
  static double top(BuildContext c) => MediaQuery.paddingOf(c).top + gutter;

  /// Kroma bandının alt kenarı.
  static double bottom(BuildContext c) =>
      MediaQuery.paddingOf(c).bottom + gutter;

  static double left(BuildContext c) => MediaQuery.paddingOf(c).left + gutter;

  static double right(BuildContext c) => MediaQuery.paddingOf(c).right + gutter;

  /// KÖŞE kroması için yanal kenar boşluğu — üst şerit, alt sıra, takipçi.
  ///
  /// Yatay tutulan telefonda çentik/ada YAN kenardadır ve iOS o kenara 47-59dp
  /// güvenli alan bildirir. Bunu olduğu gibi uygulamak üst şeridi ve alt sırayı
  /// iki yandan ~67dp içeri itiyordu: kroma kenara oturmuyor, ekranın iki
  /// yanında ölü şerit kalıyordu. Oysa çentik o kenarın DİKEY ORTASINDAdır —
  /// üst hat (y≈8-52) ile alt hat ona hiç değmez. Orada temizlenmesi gereken tek
  /// şey yuvarlak EKRAN KÖŞESİdir; [cornerSafe] onun içindir.
  ///
  /// Dikeyde ortadan geçen her şey (tam boy [MobileSheet], sağ dock panelleri)
  /// çentik bandını KESER — onlar [left]/[right] ile tam inset'i kullanmayı
  /// sürdürür.
  static const cornerSafe = 16.0;

  static double edgeLeft(BuildContext c) =>
      math.min(MediaQuery.paddingOf(c).left, cornerSafe) + gutter;

  static double edgeRight(BuildContext c) =>
      math.min(MediaQuery.paddingOf(c).right, cornerSafe) + gutter;

  /// Karar pencereleri ve büyük defter için ortak, güvenli alanı hesaba katan
  /// boyut. iPhone 11'de sonuç 760×360pt olur; daha dar bir test yüzeyinde
  /// mevcut alana kırpılır. Bu turda referans iPhone 11 olsa da taşma üretmeyen
  /// alt sınır davranışı ücretsiz gelir.
  static Size windowSize(
    BuildContext c, {
    double maxWidth = windowMaxW,
    double maxHeight = windowMaxH,
  }) {
    final screen = MediaQuery.sizeOf(c);
    final availableW = math.max(0.0, screen.width - left(c) - right(c));
    final availableH = math.max(0.0, screen.height - top(c) - bottom(c));
    return Size(
      math.min(maxWidth, availableW),
      math.min(maxHeight, availableH),
    );
  }
}

// ─── 3. kural: yazı tabanı ────────────────────────────────────────────────────

/// Telefonda 11px altı yazı bırakmayan ölçekleyici.
///
/// Oyunun UI'ı masaüstünde doğdu: 7.5–10.5px etiketler her yerde (tek koşuda
/// 500+ görülme). Telefonda bunlar okunmuyordu. Tek tek fontSize düzeltmek hem
/// yüzlerce dokunuş hem de kaçınılmaz olarak yarım kalan bir iş — bunun yerine
/// ağacın kökünde ölçekleriz.
///
/// SERT taban, rampa değil: 11 ve üstü OLDUĞU GİBİ kalır, altı 11'e çekilir.
///   7.5 → 11 · 9.5 → 11 · 10.5 → 11 · 11 → 11 · 14 → 14 · 44 → 44
/// Yumuşak rampa da denenebilirdi ama doğru olan bu: 11'in ALTINDA telefonda
/// zaten hiyerarşi yok — orada 7.5 ile 9.5 arasındaki fark okunmuyor, ikisi de
/// "küçük". Ayrım zaten ağırlık/renk/harf aralığıyla taşınıyor. Sert taban
/// ayrıca yerleşimi en az bozan seçenek: yalnız okunmayan uç büyür (en fazla
/// +3.5px), doğru boyda olan hiçbir yazı şişmez.
class MobileTextScaler extends TextScaler {
  const MobileTextScaler([this.parent = TextScaler.noScaling]);

  final TextScaler parent;

  @override
  double scale(double fontSize) {
    final s = parent.scale(fontSize);
    return s < MobileUi.fontFloor ? MobileUi.fontFloor : s;
  }

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => 1.0;

  @override
  bool operator ==(Object other) =>
      other is MobileTextScaler && other.parent == parent;

  @override
  int get hashCode => parent.hashCode;

  @override
  String toString() => 'MobileTextScaler(floor ${MobileUi.fontFloor})';
}

/// Alt ağaçtaki bütün yazılara mobil taban ölçeğini uygular. Masaüstünde
/// hiçbir şey yapmaz (aynı ağacı döndürür).
class MobileTextFloor extends StatelessWidget {
  final Widget child;
  const MobileTextFloor({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!useCompactGameUi(context)) return child;
    final mq = MediaQuery.of(context);
    if (mq.textScaler is MobileTextScaler) return child;
    return MediaQuery(
      data: mq.copyWith(textScaler: MobileTextScaler(mq.textScaler)),
      child: child,
    );
  }
}

// ─── 1. kural: tek yüzey ─────────────────────────────────────────────────────

/// Mobil kromanın ortak opak grafit yüzeyi.
///
/// Telefonda hareketli dünya üstündeki blur/cam, her paneli ayrı bir lens gibi
/// gösteriyor ve GPU'ya da gereksiz backdrop pass'i ekliyordu. Bu yüzey normal
/// panel diliyle aynı gradient + hairline kenarı kullanır; arkasını bulanıklaştırmaz.
class MobileSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  /// Uyarı/aktif hallerde camı hafifçe boyar (rust, accent…). Yapı aynı kalır.
  final Color? tone;

  /// Köşe yarıçapını tek kenara toplar (sağ sayfa: yalnız sol köşeler yuvarlak).
  final BorderRadius? shape;

  const MobileSurface({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.tone,
    this.shape,
  });

  @override
  Widget build(BuildContext context) {
    final radius = shape ?? BorderRadius.circular(MobileUi.radius);
    final top = tone == null
        ? AppUi.surface2
        : Color.alphaBlend(tone!.withValues(alpha: 0.26), AppUi.surface2);
    final bottom = tone == null
        ? AppUi.surface1
        : Color.alphaBlend(tone!.withValues(alpha: 0.18), AppUi.surface1);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, bottom],
        ),
        borderRadius: radius,
        border: Border.all(color: AppUi.line, width: 1),
        boxShadow: AppUi.softShadow,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(height: 1, color: AppUi.lineSoft),
            ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}

/// Tam ekran mobil inşa kataloğu içinde kartların raf yerine geniş ızgara
/// kullanmasını sağlayan yerleşim bağlamı.
class MobileCatalogScope extends InheritedWidget {
  final bool expanded;

  const MobileCatalogScope({
    super.key,
    required this.expanded,
    required super.child,
  });

  static bool expandedOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<MobileCatalogScope>()
          ?.expanded ??
      false;

  @override
  bool updateShouldNotify(MobileCatalogScope oldWidget) =>
      expanded != oldWidget.expanded;
}

/// Kapsül içi dikey ayraç — grup ayrımı, kutu açmadan.
class MobileSep extends StatelessWidget {
  final double height;
  const MobileSep({super.key, this.height = 18});

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: height,
    margin: const EdgeInsets.symmetric(horizontal: 8),
    color: AppUi.glassEdge,
  );
}

/// Ray içi yatay ayraç.
class MobileRule extends StatelessWidget {
  const MobileRule({super.key});

  @override
  Widget build(BuildContext context) => Container(
    height: 1,
    margin: const EdgeInsets.symmetric(horizontal: 8),
    color: AppUi.glassEdge,
  );
}

// ─── 2. kural: tek ızgara — yan sayfa ────────────────────────────────────────

/// Detay panelleri için SAĞA YAPIŞAN tam boy sayfa.
///
/// Telefonda eski hâl: masaüstünden gelen sabit genişlikli (312/326) kutu,
/// ekranın ortasında yüzüyor, altı kesiliyor, üstteki rayı örtüyordu. Sayfa
/// bunun yerine kenara oturur, üst/alt gutter'a kadar uzanır, İÇİNDE kayar.
///
/// Not: sayfa açıkken sağ ray onun ALTINDA kalır — [MobileSheet] açıkken rayı
/// çizmemek çağıranın işi (bkz. scene_ui).
class MobileSheet extends StatelessWidget {
  /// Sayfanın başlığı — sol üstte, kapatma düğmesiyle aynı hatta.
  final Widget header;

  /// Kayan gövde.
  final Widget child;

  final VoidCallback onClose;

  /// Gövdenin altına sabitlenen eylem kuşağı (kayma ile birlikte kaçmaz).
  final Widget? footer;

  const MobileSheet({
    super.key,
    required this.header,
    required this.child,
    required this.onClose,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final w = MobileUi.sheetWidth(size);
    return Positioned(
      right: MobileUi.right(context),
      top: MobileUi.top(context),
      bottom: MobileUi.bottom(context),
      width: w,
      child: MobileSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
              child: Row(
                children: [
                  Expanded(child: header),
                  const SizedBox(width: 6),
                  _SheetClose(onTap: onClose),
                ],
              ),
            ),
            const MobileRule(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: child,
              ),
            ),
            if (footer != null) ...[
              const MobileRule(),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: footer!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SheetClose extends StatelessWidget {
  final VoidCallback onTap;
  const _SheetClose({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: const SizedBox(
      width: MobileUi.tap,
      height: MobileUi.tap,
      child: Center(
        child: GameIcon(GameIconData.close, size: 18, color: AppUi.textMid),
      ),
    ),
  );
}

// ─── Ortak parçalar ──────────────────────────────────────────────────────────

/// Ray/kapsül içindeki ikon düğmesi — dokunma hedefi daima 44dp.
class MobileTapIcon extends StatelessWidget {
  final GameIconData icon;
  final VoidCallback? onTap;
  final Color? color;
  final bool active;
  final String? tooltip;
  final double size;

  const MobileTapIcon({
    super.key,
    required this.icon,
    required this.onTap,
    this.color,
    this.active = false,
    this.tooltip,
    this.size = 19,
  });

  @override
  Widget build(BuildContext context) {
    final w = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: MobileUi.tap,
        height: MobileUi.tap,
        child: Center(
          child: GameIcon(
            icon,
            size: size,
            color: color ?? (active ? AppUi.accentSoft : AppUi.textMid),
          ),
        ),
      ),
    );
    if (tooltip == null) return w;
    return Tooltip(message: tooltip!, child: w);
  }
}
