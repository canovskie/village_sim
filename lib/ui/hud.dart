import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../core/resources.dart';
import '../world/season.dart';
import 'app_ui.dart';
import 'mobile_ui.dart';

/// Oyun HUD'u — Manor Lords çıtası: çerçevesiz, ferah ince üst şerit.
/// Kutu YOK; üstte aşağı solan okunabilirlik scrim'i, tek satır kaynak/nüfus/
/// moral solda, saat/mevsim sağda, ghost kontroller en sağda. Köşeler/dünya açık.
class GameHUD extends StatelessWidget {
  final ResourceBundle stockpile;
  final int woodInTransit,
      stoneInTransit,
      ironInTransit,
      coalInTransit,
      foodInTransit;

  final int villagerCount,
      farmerCount,
      woodcutterCount,
      minerCount,
      fisherCount,
      builderCount,
      busyBuilders;
  final int shepherdCount, floristCount, homelessCount;

  final double timeOfDay, rainIntensity, dayLight;
  final int dayCount;
  final Season season;
  final double seasonProgress;

  final int buildingCount, pendingOrderCount;

  final double morale;
  final bool lowWater, starving;
  final String? eventLabel;

  /// Stok kapasitesi (wood/stone/iron/coal/food tavanı). Hücre tavana
  /// ulaşınca "dolu" uyarısı gösterilir.
  final int stockCapacity;

  /// Cevher hücreleri (demir + kömür) gösterilsin mi. Maden kurulmadan ikisi de
  /// hep 0'dır; boş sayaç üst şeridi kalabalıklaştırmaktan başka iş görmez.
  /// Maden dikilince (ya da elde cevher varsa) kalıcı olarak açılır.
  final bool showOre;

  /// 0..1 nabız (sahneden _time türevi) — dolu kaynak hücresi bununla yanar.
  final double fullPulse;

  /// Moral katkı kırılımı (etiket, delta) — moral barı hover tooltip'i.
  final List<(String, double)> moraleBreakdown;

  /// 'evsiz' sayısına tıklanınca evsiz köylüleri kısa süre vurgular.
  final VoidCallback? onHighlightHomeless;

  final bool godMode;
  final VoidCallback onNewMap, onToggleGod, onTriggerEvent;

  final double effectTimeLeft;
  final double effectDuration;
  final bool effectPositive;

  final VoidCallback onToggleDev;

  /// MOBİL — oyun dışı işler (ana menüye dön / kaydet). Masaüstünde bunlar sol
  /// üstteki "⚙ Menü" kümesinde durur; telefonda o küme dünyanın ortasında
  /// sahipsiz bir pilldi ve tema dışıydı → ray'ın araçlar menüsüne taşındı.
  final VoidCallback? onExitToMenu;
  final VoidCallback? onSaveNow;

  /// Oyun içi hızlı sessiz toggle — ayarlara girmeden tüm sesi kıs/aç.
  final bool muted;
  final VoidCallback onToggleMute;

  /// Köy Nüfus Defteri (istatistik) modalını açar — HUD'daki nüfus butonu.
  final VoidCallback? onOpenRoster;

  /// MOBİL — sağda bir detay SAYFASI açık mı (köylü/bina). Açıkken üstteki
  /// durum kapsülü sayfanın altına kadar uzanmaz: uzanınca sayfa kapsülü tam
  /// ortasından kesiyor ve sayı yarım kalıyordu. Kapsül daralır, yazıları
  /// küçültmeden içeriğine sığar.
  final bool sheetOpen;

  final double timeScale;
  final VoidCallback onCycleSpeed;

  /// ŞU ANKİ ADIM — köyün şu an bekleyen tek işi (bkz. QuestBook.activeQuests).
  ///
  /// Erken oyunun asıl şikâyeti "ne yapacağımı bilmiyorum"du: sıradaki iş
  /// Köy Defteri'nin içinde, kapalı bir panelde duruyordu. Bu şerit onu
  /// ekranda TEK SATIR olarak tutar — panel açmadan, kesme yapmadan.
  /// `null` ise (merdivenin sonu) hiç çizilmez.
  final String? stepText;
  final GameIconData? stepIcon;
  /// Adımı isteyen köylünün adı — varsa satırın başında durur.
  final String? stepWho;

  const GameHUD({
    super.key,
    required this.stockpile,
    required this.woodInTransit,
    required this.stoneInTransit,
    required this.ironInTransit,
    required this.coalInTransit,
    required this.foodInTransit,
    required this.villagerCount,
    required this.farmerCount,
    required this.woodcutterCount,
    required this.minerCount,
    required this.fisherCount,
    required this.builderCount,
    required this.busyBuilders,
    this.shepherdCount = 0,
    this.floristCount = 0,
    this.homelessCount = 0,
    required this.timeOfDay,
    required this.rainIntensity,
    required this.dayLight,
    required this.dayCount,
    required this.season,
    this.seasonProgress = 0,
    required this.buildingCount,
    required this.pendingOrderCount,
    required this.morale,
    required this.lowWater,
    required this.starving,
    this.eventLabel,
    this.stockCapacity = 1 << 30,
    this.showOre = true,
    this.fullPulse = 0,
    this.moraleBreakdown = const [],
    this.onHighlightHomeless,
    required this.godMode,
    required this.onNewMap,
    required this.onToggleGod,
    required this.onTriggerEvent,
    required this.timeScale,
    required this.onCycleSpeed,
    this.stepText,
    this.stepIcon,
    this.stepWho,
    this.effectTimeLeft = 0,
    this.effectDuration = 1,
    this.effectPositive = true,
    required this.onToggleDev,
    this.onExitToMenu,
    this.onSaveNow,
    required this.muted,
    required this.onToggleMute,
    this.onOpenRoster,
    this.sheetOpen = false,
  });

  // ── Türetilenler ──────────────────────────────────────────────────────────

  String get _clockText {
    final h = (timeOfDay * 24).floor() % 24;
    final m = ((timeOfDay * 24 - h) * 60).floor();
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  GameIconData get _weatherIcon {
    if (rainIntensity > 0.5) return GameIconData.storm;
    if (rainIntensity > 0.0) return GameIconData.rain;
    if (dayLight > 0.7) return GameIconData.sun;
    if (dayLight > 0.3) return GameIconData.dawn;
    return GameIconData.moon;
  }

  Color get _moraleColor => morale >= 0.6
      ? AppUi.sage
      : morale >= 0.4
      ? AppUi.accentSoft
      : AppUi.rust;

  int get _totalPop =>
      villagerCount +
      farmerCount +
      woodcutterCount +
      minerCount +
      fisherCount +
      builderCount +
      shepherdCount +
      floristCount;

  // Tüm HUD tooltip'leri için ortak rafine kutu (palete uyumlu, eski bluish yok).
  static final BoxDecoration _tipDeco = BoxDecoration(
    color: const Color(0xF2100E0B),
    borderRadius: BorderRadius.circular(10),
    border: Border.all(color: AppUi.line),
    boxShadow: AppUi.softShadow,
  );
  static const EdgeInsets _tipPad = EdgeInsets.symmetric(
    horizontal: 12,
    vertical: 9,
  );

  // ── Build: çerçevesiz ince üst şerit ────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    assert(() {
      debugPrint(
        'HUDPROBE size=${MediaQuery.sizeOf(context)} '
        'pad=${MediaQuery.paddingOf(context)} '
        'compact=${useCompactGameUi(context)}',
      );
      return true;
    }());
    // MOBİL: SafeArea YOK — şerit kendi kenar boşluğunu [MobileUi.edgeLeft]/
    // [edgeRight] ile hesaplar. SafeArea yatayda çentiğin tam inset'ini (59dp)
    // uygulayıp şeridi iki yandan kenardan koparıyordu; şerit çentik bandının
    // bandına zaten girmiyor.
    if (useCompactGameUi(context)) return _mobileHud();
    return SafeArea(child: _desktopHud());
  }

  Widget _desktopHud() {
    return Stack(
      children: [
        // Üst okunabilirlik scrim'i — KUTU DEĞİL: aşağı doğru solan karartma,
        // parlak gündüz gökyüzünde de metin/ikon okunur kalsın.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Container(
              height: 74,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  // İçeriği örtecek kadar koyu, sonra hızla erir — karanlık
                  // bant değil, sadece okunabilirlik dokunuşu.
                  colors: [
                    Color(0x9E000000),
                    Color(0x52000000),
                    Color(0x00000000),
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
        ),
        // Orta üst: gök çemberi — güneş ile ay saat yönünde yörüngede birbirini
        // kovalar (yarım gün arayla). Tıklanmaz, sadece günün nabzı.
        Positioned(
          top: 2,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Center(
              child: _CelestialTrack(
                timeOfDay: timeOfDay,
                dayLight: dayLight,
                pulse: fullPulse,
              ),
            ),
          ),
        ),
        // Şerit içeriği — tek satır, çerçevesiz.
        Positioned(
          top: 8,
          left: 16,
          right: 14,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Dar pencerede taşma şeridi yerine sessizce kırp.
              Flexible(
                child: ClipRect(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    child: _leftCluster(),
                  ),
                ),
              ),
              _rightCluster(),
            ],
          ),
        ),
        // Şeridin hemen altı: önce ŞU ANKİ ADIM, sonra uyarı rozetleri.
        // Sıra bilinçli — adım her zaman var, rozetler ara sıra; adım altta
        // kalsaydı açlık uyarısı çıktığında yer değiştirip zıplardı.
        Positioned(
          top: 56,
          // 118: sol-üstte "⚙ Menü" tutamağı duruyor (scene_save.buildSaveButton,
          // left:14 top:56). 16'da başlarsak şerit onun ÜSTÜNE biner — ilk
          // capture'da tam olarak bu oldu. Rozet satırı da aynı hatta olduğu
          // için o gizli çakışma da burada kapanıyor.
          left: 118,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (stepText != null) _stepStrip(maxWidth: 430),
              if (starving || lowWater || eventLabel != null) ...[
                if (stepText != null) const SizedBox(height: 6),
                _badgeRow(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// ŞU ANKİ ADIM ŞERİDİ — tek satır, kesme yok, tıklanmaz.
  ///
  /// Bilinçli olarak bir KUTU değil ince bir hat: oyuncu buna sürekli bakacak,
  /// panel ağırlığında bir yüzey ekranın üstünü kalıcı olarak yer. Metin uzun
  /// gelirse tek satırda kırpılır (iki satıra taşarsa mobilde şeridin altındaki
  /// her şeyi aşağı iter).
  Widget _stepStrip({required double maxWidth}) {
    return IgnorePointer(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          padding: const EdgeInsets.fromLTRB(9, 5, 11, 5),
          decoration: BoxDecoration(
            color: const Color(0xCC0C0D0F),
            borderRadius: BorderRadius.circular(AppUi.radiusSm),
            border: Border.all(
                color: AppUi.accent.withValues(alpha: 0.38), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GameIcon(stepIcon ?? GameIconData.star,
                  size: 12, color: AppUi.accent),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  stepWho == null ? stepText! : '$stepWho: ${stepText!}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppUi.body.copyWith(
                      fontSize: 11, color: AppUi.textHi, height: 1.2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mobileHud() => Builder(
    builder: (context) {
      // Sayfa açıkken sağ tarafı ona bırak; kapalıyken şerit tüm genişliği alır.
      // ÖLÇÜ EKRANDAN alınır (MediaQuery), LayoutBuilder'ın verdiği GÜVENLİ ALAN
      // genişliğinden değil: MobileSheet de ekran genişliğinden hesaplıyor, ikisi
      // farklı tabana bakarsa ayrılan pay sayfadan dar kalır ve şerit yine
      // sayfanın altına girer (çentikli telefonda ~47dp).
      // Sağ kenar boşluğu: sayfa kapalıyken köşe payı, açıkken sayfanın SOL
      // kenarına kadar. Sayfa tam inset kullandığı için (çentik bandını keser)
      // pay ondan türetilir — iki farklı tabandan hesaplanırsa şerit sayfanın
      // altına giriyordu.
      final right = sheetOpen
          ? MobileUi.right(context) +
                MobileUi.sheetWidth(MediaQuery.sizeOf(context)) +
                MobileUi.gap
          : MobileUi.edgeRight(context);
      return _mobileHudBody(
        left: MobileUi.edgeLeft(context),
        right: right,
        top: MobileUi.top(context),
      );
    },
  );

  Widget _mobileHudBody({
    required double left,
    required double right,
    required double top,
  }) {
    // "KENAR RAYI" (bkz. ui/mobile_ui.dart) — telefonda kroma yalnız kenara
    // yapışır, ortası daima köydür.
    //
    // Üstte TEK ince şerit var: kaynaklar · saat · kontroller aynı satırda,
    // aynı cam yüzeyde. Öncesinde sol durum kapsülü ile sağ ray ayrı iki
    // nesneydi (ray iki satır, 85dp) — üst kenar iki farklı yükseklikte iki
    // bloktu ve alçak yatay ekranda dünyanın üstünden fazla pay yiyordu.
    return Stack(
      children: [
        Positioned(
          top: top,
          left: left,
          right: right,
          child: SizedBox(height: MobileUi.barH, child: _mobileBar()),
        ),
        // MOBİL — adım şeridi rayın hemen altında, tek satır. Genişliği ray
        // ile aynı hatta hizalı (kenar rayı teması: tek yüzey, tek ızgara).
        if (stepText != null || starving || lowWater || eventLabel != null)
          Positioned(
            top: top + MobileUi.barH + MobileUi.gap,
            left: left,
            right: right,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (stepText != null)
                  // Telefonda sabit bir tavan yerine kalan genişlik: yatay
                  // telefonda 430px ray'ı aşıyordu.
                  LayoutBuilder(
                    builder: (_, c) => _stepStrip(maxWidth: c.maxWidth),
                  ),
                if (starving || lowWater || eventLabel != null) ...[
                  if (stepText != null) const SizedBox(height: 6),
                  Align(alignment: Alignment.centerLeft, child: _badgeRow()),
                ],
              ],
            ),
          ),
      ],
    );
  }

  /// Üst şerit — kaynaklar (esner) · saat · kontroller, TEK cam yüzeyde.
  Widget _mobileBar() {
    return MobileSurface(
      padding: const EdgeInsets.only(left: 10),
      child: Row(
        children: [
          // Kaynak kümesi kalan yeri alır; dar ekranda taşmak yerine küçülür.
          Expanded(child: _mobileResources()),
          const MobileSep(),
          _mobileClock(),
          const MobileSep(height: 22),
          _speedButton(size: MobileUi.tap),
          MobileTapIcon(
            icon: muted ? GameIconData.soundOff : GameIconData.sound,
            onTap: onToggleMute,
            active: muted,
            color: muted ? AppUi.rust : null,
            tooltip: muted ? 'Sesi aç' : 'Sesi kıs',
          ),
          _mobileToolsMenu(),
        ],
      ),
    );
  }

  /// Kapsül içi dikey ayraç — gruplar arası nefes, kutu açmadan.
  Widget _pillDivider() => Container(
    width: 1,
    height: 16,
    margin: const EdgeInsets.symmetric(horizontal: 9),
    color: AppUi.glassEdge,
  );

  Widget _mobileResources() {
    final mc = _moraleColor;
    final m = morale.clamp(0.0, 1.0);
    // Şeridin içinde yaşar — KENDİ camını açmaz (cam içinde cam iki farklı
    // yüzey demek). scaleDown: dar ekranda taşmak yerine küçülür.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _mobileRes(
            GameIconData.wood,
            const Color(0xFFD79A5B),
            stockpile.wood,
            woodInTransit,
          ),
          _mobileRes(
            GameIconData.stone,
            const Color(0xFFC0C0C0),
            stockpile.stone,
            stoneInTransit,
          ),
          if (showOre) ...[
            _mobileRes(
              GameIconData.iron,
              const Color(0xFFCED2EC),
              stockpile.iron,
              ironInTransit,
            ),
            _mobileRes(
              GameIconData.coal,
              const Color(0xFFA6A6A6),
              stockpile.coal,
              coalInTransit,
            ),
          ],
          _mobileRes(
            GameIconData.wheat,
            AppUi.sage,
            stockpile.food,
            foodInTransit,
          ),
          _mobileRes(
            GameIconData.coin,
            AppUi.gold,
            stockpile.gold,
            0,
            last: true,
          ),
          // Nüfus + moral aynı kapsülde: ikisi de "köyün durumu".
          // Ayrı bir bar açmak ekranın bir katını daha yerdi.
          _pillDivider(),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onOpenRoster,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Sıfır genişlikte yükseklik dayatması: opaque hit alanı
                // kapsülün tamamını kaplasın, yalnız yazının satırını değil.
                const SizedBox(height: 44),
                const GameIcon(GameIconData.people, size: 14, color: AppUi.textMid),
                const SizedBox(width: 4),
                Text(
                  '$_totalPop',
                  style: AppUi.number.copyWith(fontSize: 13.5),
                ),
                if (homelessCount > 0) ...[
                  const SizedBox(width: 8),
                  const GameIcon(GameIconData.home, size: 14, color: AppUi.rust),
                  const SizedBox(width: 4),
                  Text(
                    '$homelessCount',
                    style: AppUi.number.copyWith(
                      fontSize: 13.5,
                      color: AppUi.rust,
                    ),
                  ),
                ],
                const SizedBox(width: 10),
                GameIcon(GameIconData.heart, size: 14, color: mc),
                const SizedBox(width: 4),
                Text(
                  '${(m * 100).round()}%',
                  style: AppUi.number.copyWith(fontSize: 13.5, color: mc),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileRes(
    GameIconData icon,
    Color color,
    int stored,
    int transit, {
    bool last = false,
  }) {
    final full = stored >= stockCapacity;
    final empty = stored == 0 && transit == 0;
    final tint = full ? _amber : color;
    return Padding(
      padding: EdgeInsets.only(right: last ? 0 : 13),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GameIcon(
            icon,
            size: 14,
            color: empty ? tint.withValues(alpha: 0.5) : tint,
          ),
          const SizedBox(width: 4),
          Text(
            '$stored',
            style: AppUi.number.copyWith(
              fontSize: 13.5,
              color: full ? _amber : (empty ? AppUi.textLo : AppUi.textHi),
            ),
          ),
          if (transit > 0)
            Text(
              '+$transit',
              style: AppUi.number.copyWith(
                fontSize: 11,
                color: AppUi.accentSoft,
              ),
            ),
        ],
      ),
    );
  }

  /// Rayın üst satırı — yüzeyi RAY sağlar, saat yalnız içeriktir.
  /// Şeridin ortası — hava · saat · gün/mevsim. Tek satırda yaşadığı için
  /// genişliği İÇERİĞİ kadardır (Spacer yok: sınırsız genişlikte patlar).
  Widget _mobileClock() {
    return Tooltip(
      message: _timeHint,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GameIcon(_weatherIcon, size: 15, color: _seasonColor),
          const SizedBox(width: 6),
          Text(_clockText, style: AppUi.number.copyWith(fontSize: 16)),
          const SizedBox(width: 7),
          Text(
            '$dayCount · ${season.label.toUpperCase()}',
            style: AppUi.label.copyWith(
              fontSize: 11,
              letterSpacing: 0,
              color: _seasonColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileToolsMenu() {
    return PopupMenuButton<_MobileHudAction>(
      tooltip: 'Oyun araçları',
      color: AppUi.surface2,
      offset: const Offset(0, 42),
      onSelected: (action) {
        switch (action) {
          case _MobileHudAction.event:
            onTriggerEvent();
          case _MobileHudAction.god:
            onToggleGod();
          case _MobileHudAction.map:
            onNewMap();
          case _MobileHudAction.dev:
            onToggleDev();
          case _MobileHudAction.save:
            onSaveNow?.call();
          case _MobileHudAction.exit:
            onExitToMenu?.call();
        }
      },
      itemBuilder: (_) => [
        if (onSaveNow != null)
          _mobileMenuItem(_MobileHudAction.save, GameIconData.save, 'Kaydet'),
        if (onExitToMenu != null)
          _mobileMenuItem(_MobileHudAction.exit, GameIconData.home, 'Ana menü'),
        if (onSaveNow != null || onExitToMenu != null) const PopupMenuDivider(),
        _mobileMenuItem(
          _MobileHudAction.event,
          GameIconData.dice,
          'Olay başlat',
        ),
        _mobileMenuItem(
          _MobileHudAction.god,
          GameIconData.bolt,
          'Tanrı modu',
          active: godMode,
        ),
        _mobileMenuItem(_MobileHudAction.map, GameIconData.map, 'Yeni harita'),
        _mobileMenuItem(
          _MobileHudAction.dev,
          GameIconData.bug,
          'Geliştirici paneli',
        ),
      ],
      child: const SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: GameIcon(GameIconData.gear, size: 19, color: AppUi.textMid),
        ),
      ),
    );
  }

  PopupMenuItem<_MobileHudAction> _mobileMenuItem(
    _MobileHudAction value,
    GameIconData icon,
    String label, {
    bool active = false,
  }) {
    return PopupMenuItem(
      value: value,
      height: 44,
      child: Row(
        children: [
          GameIcon(
            icon,
            size: 18,
            color: active ? AppUi.accent : AppUi.textMid,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: AppUi.bodyHi.copyWith(
              fontSize: 12.5,
              color: active ? AppUi.accentSoft : AppUi.textHi,
            ),
          ),
        ],
      ),
    );
  }

  // ── Sol küme: kaynaklar · nüfus · moral ─────────────────────────────────────

  Widget _leftCluster() => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [_resources(), _sep(), _popInline(), _sep(), _moraleInline()],
  );

  Widget _sep() => Container(
    width: 1,
    height: 18,
    margin: const EdgeInsets.symmetric(horizontal: 11),
    color: const Color(0x1AFFFFFF),
  );

  /// Üst şerit YALNIZ köyün omurga kaynaklarını taşır: oyuncunun harcadığı,
  /// karar verdiği şeyler. Bal kovan panelinde, saz hiç gösterilmez (evsizler
  /// kendi biçip kendi harcar — oyuncunun dokunmadığı bir sayaçtır).
  Widget _resources() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _res(
        GameIconData.wood,
        const Color(0xFFD79A5B),
        stockpile.wood,
        woodInTransit,
        capped: true,
      ),
      _res(
        GameIconData.stone,
        const Color(0xFFC0C0C0),
        stockpile.stone,
        stoneInTransit,
        capped: true,
      ),
      if (showOre) ...[
        _res(
          GameIconData.iron,
          const Color(0xFFCED2EC),
          stockpile.iron,
          ironInTransit,
          capped: true,
        ),
        _res(
          GameIconData.coal,
          const Color(0xFFA6A6A6),
          stockpile.coal,
          coalInTransit,
          capped: true,
        ),
      ],
      _res(
        GameIconData.wheat,
        AppUi.sage,
        stockpile.food,
        foodInTransit,
        capped: true,
      ),
      _res(GameIconData.coin, AppUi.gold, stockpile.gold, 0),
    ],
  );

  static const _amber = Color(0xFFE8A23A);

  // Tek kaynak: ikon + sayı (+taşımadaki). Tavan dolunca kehribar + nabız.
  Widget _res(
    GameIconData icon,
    Color color,
    int stored,
    int transit, {
    bool capped = false,
  }) {
    final empty = stored == 0 && transit == 0;
    final full = capped && stored >= stockCapacity;
    final iconColor = full ? _amber : color;
    final numColor = full
        ? Color.lerp(_amber, const Color(0xFFFFE0A0), fullPulse)!
        : (empty ? AppUi.textLo : AppUi.textHi);
    return Padding(
      padding: const EdgeInsets.only(right: 15),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GameIcon(
            icon,
            size: 16,
            color: empty ? iconColor.withValues(alpha: 0.45) : iconColor,
          ),
          const SizedBox(width: 5),
          Text(
            '$stored',
            style: AppUi.number.copyWith(fontSize: 15.5, color: numColor),
          ),
          if (transit > 0)
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 5),
              child: Text(
                '+$transit',
                style: AppUi.number.copyWith(
                  fontSize: 9,
                  color: AppUi.accentSoft,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Nüfus (inline) — hover'da meslek dağılımı ──────────────────────────────

  // Profession palette — tooltip kırılımı.
  static const _farmerC = AppUi.sage;
  static const _woodC = Color(0xFFE7B374);
  static const _minerC = Color(0xFFC5CDE9);
  static const _fisherC = AppUi.info;
  static const _shepC = Color(0xFFCDB79A);
  static const _floriC = Color(0xFFE08AB0);
  static const _buildC = Color(0xFFD8C088);

  Widget _popInline() {
    return Tooltip(
      richMessage: _professionBreakdown(),
      padding: _tipPad,
      margin: const EdgeInsets.only(left: 12),
      decoration: _tipDeco,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const GameIcon(GameIconData.people, size: 16, color: AppUi.textMid),
          const SizedBox(width: 6),
          Text('$_totalPop', style: AppUi.number.copyWith(fontSize: 15.5)),
          if (homelessCount > 0) ...[
            const SizedBox(width: 13),
            GestureDetector(
              onTap: onHighlightHomeless,
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const GameIcon(GameIconData.home, size: 15, color: AppUi.rust),
                  const SizedBox(width: 5),
                  Text(
                    '$homelessCount',
                    style: AppUi.number.copyWith(
                      fontSize: 15.5,
                      color: AppUi.rust,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(width: 7),
          const GameIcon(GameIconData.chevron, size: 11, color: AppUi.textLo),
        ],
      ),
    );
  }

  // Hover tooltip — hangi mesleğe kaç köylü dağıtılmış (+ serbest + evsiz).
  InlineSpan _professionBreakdown() {
    final rows = <(String, int, Color)>[
      ('Çiftçi', farmerCount, _farmerC),
      ('Oduncu', woodcutterCount, _woodC),
      ('Madenci', minerCount, _minerC),
      ('Balıkçı', fisherCount, _fisherC),
      // Ağıl işçisi = SÜTÇÜ (inek sağar). "Çoban" değil — çoban artık gerçek bir
      // meslek (VillagerType.shepherd): sürüyü otlatır, sağmaz. Aynı ada sahip
      // iki farklı iş olmasın diye ayrıldı.
      ('Sütçü', shepherdCount, _shepC),
      ('Çiçekçi', floristCount, _floriC),
      ('İnşaatçı', builderCount, _buildC),
    ].where((r) => r.$2 > 0).toList();

    final base = AppUi.body.copyWith(fontSize: 12, height: 1.45);
    final children = <InlineSpan>[
      TextSpan(
        text: 'Meslek dağılımı\n',
        style: AppUi.label.copyWith(
          fontSize: 10,
          letterSpacing: 1.4,
          color: AppUi.accentSoft,
        ),
      ),
    ];
    if (rows.isEmpty) {
      children.add(
        TextSpan(
          text: 'Henüz meslek yok\n',
          style: base.copyWith(color: AppUi.textMid),
        ),
      );
    }
    for (final (name, n, col) in rows) {
      children.add(
        TextSpan(
          text: '$name  ',
          style: base.copyWith(color: AppUi.textMid),
        ),
      );
      children.add(
        TextSpan(
          text: '$n\n',
          style: base.copyWith(color: col, fontWeight: FontWeight.w700),
        ),
      );
    }
    // Serbest (mesleği olmayan köylü) + evsiz alt çizgi.
    children.add(
      TextSpan(
        text: '─────\n',
        style: base.copyWith(color: const Color(0x33FFFFFF)),
      ),
    );
    children.add(
      TextSpan(
        text: 'Serbest  ',
        style: base.copyWith(color: AppUi.textMid),
      ),
    );
    children.add(
      TextSpan(
        text: '$villagerCount\n',
        style: base.copyWith(color: AppUi.textHi, fontWeight: FontWeight.w700),
      ),
    );
    children.add(
      TextSpan(
        text: 'Evsiz  ',
        style: base.copyWith(color: AppUi.textMid),
      ),
    );
    children.add(
      TextSpan(
        text: '$homelessCount',
        style: base.copyWith(
          color: homelessCount > 0 ? AppUi.rust : AppUi.textHi,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    return TextSpan(children: children);
  }

  // ── Moral (inline) — kalp + ince çubuk + % ─────────────────────────────────

  Widget _moraleInline() {
    final c = _moraleColor;
    final m = morale.clamp(0.0, 1.0);
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GameIcon(GameIconData.heart, size: 15, color: c),
        const SizedBox(width: 7),
        Container(
          width: 58,
          height: 6,
          decoration: BoxDecoration(
            color: const Color(0x40000000),
            borderRadius: BorderRadius.circular(4),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: m),
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOutCubic,
                builder: (_, v, _) => FractionallySizedBox(
                  widthFactor: v,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          c.withValues(alpha: 0.8),
                          Color.lerp(c, Colors.white, 0.25)!,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 7),
        Text(
          '${(m * 100).round()}%',
          style: AppUi.number.copyWith(fontSize: 12, color: c),
        ),
      ],
    );
    if (moraleBreakdown.isEmpty) return child;
    return Tooltip(
      richMessage: _moraleTooltip(),
      padding: _tipPad,
      decoration: _tipDeco,
      child: child,
    );
  }

  // Moral neden bu seviyede? Katkı kırılımı (taban + olay + politika + ...).
  InlineSpan _moraleTooltip() {
    final base = AppUi.body.copyWith(fontSize: 12, height: 1.45);
    final children = <InlineSpan>[
      TextSpan(
        text: 'Moral neden böyle\n',
        style: AppUi.label.copyWith(
          fontSize: 10,
          letterSpacing: 1.4,
          color: AppUi.accentSoft,
        ),
      ),
    ];
    for (final (label, delta) in moraleBreakdown) {
      final isBase = delta >= 0.49 && label == 'Taban';
      final col = isBase
          ? AppUi.textMid
          : (delta >= 0 ? AppUi.sage : AppUi.rust);
      final sign = isBase ? '' : (delta >= 0 ? '+' : '−');
      final pct = isBase
          ? '${(delta * 100).round()}%'
          : '$sign${(delta.abs() * 100).round()}%';
      children.add(
        TextSpan(
          text: '$label  ',
          style: base.copyWith(color: AppUi.textMid),
        ),
      );
      children.add(
        TextSpan(
          text: '$pct\n',
          style: base.copyWith(color: col, fontWeight: FontWeight.w700),
        ),
      );
    }
    children.add(
      TextSpan(
        text: '─────\n',
        style: base.copyWith(color: const Color(0x33FFFFFF)),
      ),
    );
    children.add(
      TextSpan(
        text: 'Toplam  ',
        style: base.copyWith(color: AppUi.textMid),
      ),
    );
    children.add(
      TextSpan(
        text: '${(morale * 100).round()}%',
        style: base.copyWith(color: _moraleColor, fontWeight: FontWeight.w700),
      ),
    );
    return TextSpan(children: children);
  }

  // ── Sağ küme: saat/mevsim + ghost kontroller ───────────────────────────────

  Widget _rightCluster() => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [_timeBlock(), const SizedBox(width: 16), _controls()],
  );

  Color get _seasonColor => switch (season) {
    Season.spring => const Color(0xFF8FD17A),
    Season.summer => const Color(0xFFE6C260),
    Season.autumn => const Color(0xFFE08A4B),
    Season.winter => const Color(0xFF9FC4E0),
  };

  // Saat panosu hover ipucu — günün evresi + köyün ne yapacağı.
  String get _timeHint {
    final t = timeOfDay;
    final (phase, flavor) = switch (t) {
      < 0.22 => ('Gece', 'Köy uyuyor. Ateş başı hâlâ sıcak.'),
      < 0.30 => ('Şafak söküyor', 'İlk ışık damlara vurdu.'),
      < 0.45 => ('Sabah', 'Kapılar açıldı, iş başladı.'),
      < 0.55 => ('Öğle', 'Gölgeler en kısa hâlinde.'),
      < 0.68 => ('Öğleden sonra', 'İşin ağır kısmı sürüyor.'),
      < 0.78 => ('Akşam yaklaşıyor', 'Ocaklar tütmeye başladı.'),
      < 0.82 => ('Gün batıyor', 'Herkes yavaşça kapısına dönüyor.'),
      _ => ('Gece', 'Köy uyuyor. Ateş başı hâlâ sıcak.'),
    };
    return 'Gün $dayCount · $phase\n$flavor';
  }

  Widget _timeBlock() {
    final inner = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GameIcon(_weatherIcon, size: 16, color: AppUi.textMid),
            const SizedBox(width: 8),
            Text(
              _clockText,
              style: AppUi.number.copyWith(fontSize: 22, letterSpacing: 1.0),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'GÜN $dayCount',
              style: AppUi.label.copyWith(
                fontSize: 10,
                letterSpacing: 1.4,
                color: AppUi.textMid,
              ),
            ),
            Text(
              '  ·  ',
              style: AppUi.label.copyWith(fontSize: 10, color: AppUi.textLo),
            ),
            Text(
              season.label.toUpperCase(),
              style: AppUi.label.copyWith(
                fontSize: 10,
                letterSpacing: 1.4,
                color: _seasonColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        SizedBox(
          width: 124,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: seasonProgress.clamp(0.0, 1.0),
              minHeight: 2,
              backgroundColor: const Color(0x1FFFFFFF),
              valueColor: AlwaysStoppedAnimation(
                _seasonColor.withValues(alpha: 0.8),
              ),
            ),
          ),
        ),
      ],
    );
    return Tooltip(
      message: _timeHint,
      textStyle: AppUi.body.copyWith(
        fontSize: 12,
        height: 1.4,
        color: AppUi.textHi,
      ),
      padding: _tipPad,
      decoration: _tipDeco,
      child: inner,
    );
  }

  // ── Ghost kontroller (çerçevesiz; hover/aktifte yüzey çıkar) ────────────────

  Widget _controls() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _speedButton(),
      const SizedBox(width: 4),
      // Köy Nüfus Defteri — köylü hane/meslek/servet/moral istatistikleri.
      AppIconButton(
        icon: GameIconData.people,
        onTap: onOpenRoster,
        ghost: true,
        size: 34,
      ),
      const SizedBox(width: 4),
      AppIconButton(
        icon: muted ? GameIconData.soundOff : GameIconData.sound,
        onTap: onToggleMute,
        active: muted,
        tint: muted ? AppUi.rust : null,
        ghost: true,
        size: 34,
      ),
      const SizedBox(width: 4),
      AppIconButton(
        icon: GameIconData.dice,
        onTap: onTriggerEvent,
        ghost: true,
        size: 34,
      ),
      const SizedBox(width: 4),
      AppIconButton(
        icon: GameIconData.bolt,
        onTap: onToggleGod,
        active: godMode,
        ghost: true,
        size: 34,
      ),
      const SizedBox(width: 4),
      AppIconButton(
        icon: GameIconData.map,
        onTap: onNewMap,
        ghost: true,
        size: 34,
      ),
      const SizedBox(width: 4),
      AppIconButton(
        icon: GameIconData.bug,
        onTap: onToggleDev,
        ghost: true,
        size: 34,
      ),
    ],
  );

  Widget _speedButton({double size = 34}) {
    final paused = timeScale <= 0.01;
    final boosted = timeScale > 1.01;
    if (paused) {
      return AppIconButton(
        icon: GameIconData.pause,
        onTap: onCycleSpeed,
        active: true,
        tint: AppUi.rust,
        ghost: true,
        size: size,
      );
    }
    final label = timeScale <= 1.01
        ? '1×'
        : timeScale <= 2.01
        ? '2×'
        : '4×';
    return AppIconButton(
      icon: GameIconData.speed,
      text: label,
      onTap: onCycleSpeed,
      active: boosted,
      ghost: true,
      size: size,
    );
  }

  // ── Uyarı rozetleri ────────────────────────────────────────────────────────

  Widget _badgeRow() => Wrap(
    spacing: 6,
    runSpacing: 5,
    children: [
      if (starving)
        const AppChip(
          icon: GameIconData.wheat,
          label: 'AÇLIK',
          color: AppUi.rust,
          solid: true,
        ),
      if (lowWater)
        const AppChip(
          icon: GameIconData.drop,
          label: 'SUSUZ',
          color: AppUi.rust,
          solid: true,
        ),
      if (eventLabel != null && effectTimeLeft > 0)
        _effectChip()
      else if (eventLabel != null)
        AppChip(
          label: eventLabel!.toUpperCase(),
          color: AppUi.accent,
          solid: true,
        ),
    ],
  );

  Widget _effectChip() {
    final color = effectPositive ? AppUi.sage : AppUi.rust;
    final progress = effectDuration <= 0
        ? 0.0
        : (effectTimeLeft / effectDuration).clamp(0.0, 1.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppChip(label: eventLabel!.toUpperCase(), color: color, solid: true),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: SizedBox(
            width: 96,
            height: 3,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: progress,
                child: Container(color: color),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

enum _MobileHudAction { save, exit, event, god, map, dev }

// ── Gök çemberi: güneş ↔ ay yörüngesi ───────────────────────────────────────

/// Günün saatini bir yörünge çemberi olarak gösterir. Güneş ile ay çemberin tam
/// karşılıklı iki ucunda, saat yönünde döner: güneş soldaki ufuk noktasından
/// doğar (şafak), tepeye tırmanır (öğle), sağdan batar (akşam) — ve o an ay
/// soldan doğar. Çemberin yatay çapı ufuk çizgisidir: üstteki yarım daire
/// gökyüzü, alttaki yer altı (oradaki cisim soluklaşır).
class _CelestialTrack extends StatelessWidget {
  final double timeOfDay, dayLight, pulse;
  const _CelestialTrack({
    required this.timeOfDay,
    required this.dayLight,
    required this.pulse,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 68,
    height: 68,
    child: CustomPaint(
      painter: _CelestialTrackPainter(
        timeOfDay: timeOfDay,
        dayLight: dayLight,
        pulse: pulse,
      ),
    ),
  );
}

class _CelestialTrackPainter extends CustomPainter {
  final double timeOfDay, dayLight, pulse;
  _CelestialTrackPainter({
    required this.timeOfDay,
    required this.dayLight,
    required this.pulse,
  });

  static const _sun = Color(0xFFF0B457);
  static const _moon = Color(0xFFCBD8E6);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 8;

    // Yörünge halkası — üst yarı (gökyüzü) daha belirgin, alt yarı (yer altı)
    // neredeyse siliniyor: bakan göz "gündüz kavsini" okusun.
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x59FFFFFF), Color(0x30FFFFFF), Color(0x0DFFFFFF)],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r, ring);

    // Ufuk çizgisi — çemberin yatay çapı; doğuş/batış eşiği.
    canvas.drawLine(
      Offset(c.dx - r - 3, c.dy),
      Offset(c.dx + r + 3, c.dy),
      Paint()
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round
        ..shader = const LinearGradient(
          colors: [
            Color(0x00FFFFFF),
            Color(0x38FFFFFF),
            Color(0x38FFFFFF),
            Color(0x00FFFFFF),
          ],
          stops: [0.0, 0.2, 0.8, 1.0],
        ).createShader(Rect.fromLTWH(c.dx - r - 3, c.dy - 1, (r + 3) * 2, 2)),
    );
    // Tepe (öğle) çentiği.
    canvas.drawLine(
      Offset(c.dx, c.dy - r - 3),
      Offset(c.dx, c.dy - r + 3),
      Paint()
        ..strokeWidth = 1
        ..color = const Color(0x2EFFFFFF),
    );

    // Saat yönü yörünge: 06:00 → sol ufuk, 12:00 → tepe, 18:00 → sağ ufuk,
    // 00:00 → dip. (Ekran y aşağı büyüdüğü için sin çıkarılıyor.)
    final sunA = math.pi - (timeOfDay - 0.25) * 2 * math.pi;
    final moonA = sunA + math.pi;

    // Ufkun altındaki (sönük) cisim önce çizilsin ki parlak olan üstte kalsın.
    final sunUp = math.sin(sunA) >= 0;
    if (sunUp) {
      _body(canvas, c, r, moonA, _moon, false);
      _body(canvas, c, r, sunA, _sun, true);
    } else {
      _body(canvas, c, r, sunA, _sun, true);
      _body(canvas, c, r, moonA, _moon, false);
    }
  }

  void _body(
    Canvas canvas,
    Offset center,
    double orbitR,
    double angle,
    Color color,
    bool isSun,
  ) {
    final p = Offset(
      center.dx + orbitR * math.cos(angle),
      center.dy - orbitR * math.sin(angle),
    );

    // Ufkun üstündeyse nöbette: dolgun ve haleli. Altındayken yer altında —
    // soluk bir iz olarak kalır (kovalamaca okunsun ama göz takip etmesin).
    final h = math.sin(angle); // +1 tepe, 0 ufuk, -1 dip
    final up = ((h + 0.12) / 0.24).clamp(
      0.0,
      1.0,
    ); // ufuk çevresinde yumuşak geçiş
    final a = 0.24 + 0.76 * up;
    final r = (isSun ? 5.2 : 4.4) * (0.75 + 0.25 * up);

    // Hale — nabızla çok hafif nefes alır; gündüz/gece nöbetiyle güçlenir.
    final glow = 0.2 + 0.8 * up;
    canvas.drawCircle(
      p,
      (r * 2.6) * (1 + 0.06 * (pulse * 2 - 1)),
      Paint()
        ..color = color.withValues(alpha: 0.18 * a * glow)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawCircle(p, r, Paint()..color = color.withValues(alpha: a));

    if (!isSun) {
      // Ayın gölgeli tarafı — küçük bir hilal ısırığı.
      canvas.drawCircle(
        p.translate(r * 0.45, -r * 0.25),
        r * 0.82,
        Paint()..color = const Color(0xFF12100D).withValues(alpha: a * 0.8),
      );
    }
  }

  @override
  bool shouldRepaint(_CelestialTrackPainter old) =>
      old.timeOfDay != timeOfDay ||
      old.dayLight != dayLight ||
      old.pulse != pulse;
}
