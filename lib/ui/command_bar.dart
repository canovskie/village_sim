import 'package:flutter/material.dart';
import 'app_ui.dart';
import 'guide_spotlight.dart';
import 'mobile_ui.dart';

/// KOMUTA ÇUBUĞU — oyunun tek alt komuta hattı (konsept 04).
///
/// Eski dağınık yüzen panelleri (sol ObjectivePanel, sol/sağ mühürler, ayrı
/// alt araç çubuğu) TEK bir hatta toplar:
///   • SOL  — inşa paleti (kategori + kartlar) → [buildSegment]
///   • ORTA — seçili şeyin (bina/köylü) bağlam eylemleri → [context] (yoksa ipucu)
///   • SAĞ  — derin menü kapıları (Defter / Divan / Nüfus)
///
/// Üst HUD sade kalır; görev takibi ayrı ince [QuestTracker] (sağ üst). Böylece
/// ekranda sürekli yalnız: HUD + görev takipçisi + tek alt çubuk kalır.
class CommandBar extends StatefulWidget {
  /// Sol segment — inşa paleti içeriği (kategori sekmeleri + kartlar).
  final Widget buildSegment;

  /// Orta segment — seçili öğe bağlamı. null ise sakin bir ipucu gösterilir.
  final CommandContext? context;

  final VoidCallback onDefter;
  final VoidCallback onDivan;
  final VoidCallback onRoster;

  /// Defter kapısındaki bekleyen gündem rozeti (0 = rozet yok).
  final int agenda;

  /// Köyün adı — boş orta segmentte fısıldanır ("Pınarbaşı: bir bina ya da
  /// köylü seç"). Oyuncunun kuruluşta verdiği ad oyun ekranında hiçbir yerde
  /// geçmiyordu; en sakin yer burası.
  final String village;

  const CommandBar({
    super.key,
    required this.buildSegment,
    required this.onDefter,
    required this.onDivan,
    required this.onRoster,
    this.context,
    this.agenda = 0,
    this.village = '',
  });

  @override
  State<CommandBar> createState() => _CommandBarState();
}

class _CommandBarState extends State<CommandBar> {
  bool _catalogOpen = false;

  @override
  void didUpdateWidget(covariant CommandBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.context == null && widget.context != null) {
      _catalogOpen = false;
    }
  }

  @override
  Widget build(BuildContext ctx) {
    if (useCompactGameUi(ctx)) return _mobile();
    return _desktop();
  }

  Widget _desktop() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xEE0C0D0F), Color(0x660C0D0F)],
        ),
        border: Border(top: BorderSide(color: AppUi.line)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 5, 10, 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── SOL: inşa ────────────────────────────────────────────────────
          // Esnek + yatay kaydırılabilir: çok binalı kategoride dar ekranda
          // (mobil, yatay-kilitli) TAŞMASIN — fazlası kayar. Geniş ekranda
          // doğal genişliğinde durur (loose fit).
          Flexible(
            flex: 3,
            fit: FlexFit.loose,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                RotatedBox(
                  quarterTurns: 3,
                  child: Text(
                    'İNŞA',
                    style: AppUi.label.copyWith(
                      fontSize: 7.5,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: widget.buildSegment,
                  ),
                ),
              ],
            ),
          ),
          const _Divider(),
          // ── ORTA: bağlam ─────────────────────────────────────────────────
          Expanded(
            flex: 2,
            child: widget.context ?? _ContextHint(village: widget.village),
          ),
          const _Divider(),
          // ── SAĞ: menü kapıları ───────────────────────────────────────────
          _Seg(
            label: 'KÖY',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MenuButton(
                  icon: GameIconData.scroll,
                  label: 'Defter',
                  badge: widget.agenda,
                  onTap: widget.onDefter,
                ),
                const SizedBox(width: 4),
                _MenuButton(
                  icon: GameIconData.bank,
                  label: 'Divan',
                  onTap: widget.onDivan,
                ),
                const SizedBox(width: 4),
                _MenuButton(
                  icon: GameIconData.people,
                  label: 'Nüfus',
                  onTap: widget.onRoster,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobile() {
    // "KENAR RAYI"nın ALT hattı — üç yuva, hepsi AYNI yükseklikte
    // ([MobileUi.actionH]) ve aynı taban çizgisinde: inşa · bağlam · kapılar.
    //
    // Önceki hâl yine üç kapsüldü ama her biri kendi yüksekliğini içeriğinden
    // alıyordu (48'lik inşa düğmesi, 40'lık bağlam, 52'lik kapılar) ve
    // `CrossAxisAlignment.end` ile alttan hizalanıyordu → üstleri basamak
    // basamaktı. Sabit yükseklik bunu bitirir; kroma tek bir hat gibi okunur.
    // Kenar boşlukları SafeArea'dan DEĞİL [MobileUi] ızgarasından: yatayda
    // SafeArea çentiğin tam inset'ini (59dp) uyguluyor, alt sıra iki yandan
    // kenardan kopuyordu. Alt hat çentik bandının altında kalır — orada yalnız
    // yuvarlak köşe payı gerekir. Altta ise gerçek güvenli alan (ana ekran
    // çubuğu) aynen korunur.
    return Builder(
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: MobileUi.edgeLeft(context),
          right: MobileUi.edgeRight(context),
          bottom: MobileUi.bottom(context),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              alignment: Alignment.bottomCenter,
              child: !_catalogOpen
                  ? const SizedBox(width: double.infinity)
                  : MobileSurface(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: SizedBox(
                        width: double.infinity,
                        child: widget.buildSegment,
                      ),
                    ),
            ),
            const SizedBox(height: MobileUi.gap),
            SizedBox(
              height: MobileUi.actionH,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  MobileSurface(
                    child: _MobileBuildButton(
                      open: _catalogOpen,
                      onTap: () => setState(() => _catalogOpen = !_catalogOpen),
                    ),
                  ),
                  // Bağlam yuvası yalnız seçim VARSA yer kaplar — boşken kapsül
                  // açılmaz, orası harita kalır.
                  if (widget.context != null)
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: MobileUi.gap,
                        ),
                        child: MobileSurface(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Center(child: widget.context!),
                        ),
                      ),
                    ),
                  MobileSurface(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _MenuButton(
                          icon: GameIconData.scroll,
                          label: 'Defter',
                          badge: widget.agenda,
                          compact: true,
                          onTap: widget.onDefter,
                        ),
                        _MenuButton(
                          icon: GameIconData.bank,
                          label: 'Divan',
                          compact: true,
                          onTap: widget.onDivan,
                        ),
                        _MenuButton(
                          icon: GameIconData.people,
                          label: 'Nüfus',
                          compact: true,
                          onTap: widget.onRoster,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileBuildButton extends StatelessWidget {
  final bool open;
  final VoidCallback onTap;
  const _MobileBuildButton({required this.open, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: open ? 'İnşa kataloğunu kapat' : 'İnşa kataloğunu aç',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 70,
          height: 48,
          decoration: BoxDecoration(
            color: open
                ? Color.alphaBlend(
                    AppUi.accent.withValues(alpha: 0.24),
                    AppUi.surface2,
                  )
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppUi.radiusSm),
            border: Border.all(color: open ? AppUi.accent : Colors.transparent),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Telefonda ikon 20'ydi: 11px'lik etiketin yanında sembol yazıyı
              // eziyor, 48dp'lik yuva tıka basa doluyordu. 16 ikonu etiketle
              // aynı ağırlığa getirir, kapsülde nefes bırakır.
              GameIcon(
                GameIconData.hammer,
                size: 16,
                color: open ? AppUi.accentSoft : AppUi.textMid,
              ),
              const SizedBox(height: 3),
              Text(
                'İNŞA',
                style: AppUi.label.copyWith(
                  fontSize: 11,
                  letterSpacing: 0.8,
                  color: open ? AppUi.accentSoft : AppUi.textLo,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bir komuta segmenti — üstte küçük dikey etiket + içerik.
class _Seg extends StatelessWidget {
  final String label;
  final Widget child;
  const _Seg({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        RotatedBox(
          quarterTurns: 3,
          child: Text(
            label,
            style: AppUi.label.copyWith(fontSize: 7.5, letterSpacing: 1.4),
          ),
        ),
        const SizedBox(width: 8),
        child,
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 52,
    margin: const EdgeInsets.symmetric(horizontal: 12),
    color: AppUi.lineSoft,
  );
}

/// Orta segment boşken — köyün nabzını fısıldayan sakin satır.
class _ContextHint extends StatelessWidget {
  final String village;
  const _ContextHint({this.village = ''});

  /// Adı olan köy kendi adıyla seslenir; adsız/varsayılan köy jenerik konuşur.
  String get _line {
    final v = village.trim();
    if (v.isEmpty || v.toLowerCase() == 'köy') {
      return 'Bir bina ya da köylü seç — işleri buradan görürsün.';
    }
    return '$v: bir bina ya da köylü seç — işleri buradan görürsün.';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const GameIcon(GameIconData.home, size: 15, color: AppUi.textLo),
        const SizedBox(width: 9),
        Flexible(
          child: Text(
            _line,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppUi.body.copyWith(fontSize: 12, color: AppUi.textLo),
          ),
        ),
      ],
    );
  }
}

/// Seçili öğenin (bina/köylü) komuta bağlamı — başlık + özet + birincil eylemler.
/// Tam ayrıntı (sakinler/öykü/açıklama) "Detay" ile açılır; çubuk yalnız en sık
/// dokunulan bilgiyi ve eylemleri taşır.
class CommandContext extends StatelessWidget {
  final String title;
  final String? subtitle;

  /// Uzun açıklama satırı — inşa için bina seçilince "ne işe yarar" metni.
  /// Verilirse özet ölçülerin YERİNE gösterilir (2 satır, italik).
  final String? description;

  /// Özet ölçüler — (etiket, değer, renk). En çok 3.
  final List<(String, String, Color)> stats;

  /// Eylemler — soldan sağa; ilki birincil sayılır.
  final List<CommandAction> actions;

  const CommandContext({
    super.key,
    required this.title,
    this.subtitle,
    this.description,
    this.stats = const [],
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final compact = useCompactGameUi(context);
    return Row(
      children: [
        // Başlık + (açıklama VEYA özet) — kalan alanı doldurur, metin sarar.
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppUi.title.copyWith(
                        fontSize: 14,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        '· $subtitle',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppUi.body.copyWith(
                          fontSize: 10.5,
                          color: AppUi.textLo,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (!compact && description != null) ...[
                const SizedBox(height: 4),
                Text(
                  description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppUi.body.copyWith(
                    fontSize: 11.5,
                    height: 1.32,
                    fontStyle: FontStyle.italic,
                    color: AppUi.textMid,
                  ),
                ),
              ] else if (!compact && stats.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    for (var i = 0; i < stats.length; i++) ...[
                      if (i > 0)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            '·',
                            style: TextStyle(color: AppUi.textLo, fontSize: 11),
                          ),
                        ),
                      Text(
                        '${stats[i].$1} ',
                        style: AppUi.body.copyWith(
                          fontSize: 11,
                          color: AppUi.textMid,
                        ),
                      ),
                      Text(
                        stats[i].$2,
                        style: AppUi.number.copyWith(
                          fontSize: 12,
                          color: stats[i].$3,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
        if (actions.isNotEmpty) SizedBox(width: compact ? 6 : 14),
        // Eylemler
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) SizedBox(width: compact ? 4 : 7),
          // Öğretici "Detay"ı gösterebilsin diye eylemler çapalı: iş verme
          // adımının orta halkası bu düğme ve görünmezliği zincirin en
          // sinsi kopukluğuydu (köylüyü seçmek kartı AÇMIYOR).
          GuideTarget(
            id: GuideAnchors.command(actions[i].label),
            child: _ActionButton(
              action: actions[i],
              primary: i == 0,
              showLabel: compact && actions.length == 1,
            ),
          ),
        ],
      ],
    );
  }
}

/// Komuta bağlam eylemi.
class CommandAction {
  final String label;
  final GameIconData icon;
  final VoidCallback? onTap;

  /// Yıkıcı (kırmızı ölçülü) eylem mi.
  final bool danger;
  const CommandAction(this.label, this.icon, {this.onTap, this.danger = false});
}

class _ActionButton extends StatefulWidget {
  final CommandAction action;
  final bool primary;
  final bool showLabel;
  const _ActionButton({
    required this.action,
    required this.primary,
    this.showLabel = false,
  });
  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final a = widget.action;
    final tint = a.danger ? AppUi.rust : AppUi.accent;
    final disabled = a.onTap == null;
    final hot = _hover && !disabled;
    final compact = useCompactGameUi(context);
    final labelled = compact && widget.showLabel;
    // Sakin (de-Flash): birincil derin ember tonal, ikincil grafit; ışıma yok.
    final Color bg;
    final Color border;
    if (widget.primary || a.danger) {
      bg = Color.alphaBlend(
        tint.withValues(alpha: hot ? 0.30 : 0.20),
        AppUi.surface1,
      );
      border = tint.withValues(alpha: hot ? 0.9 : 0.55);
    } else {
      bg = hot ? AppUi.surface3 : AppUi.surface1;
      border = AppUi.line;
    }
    final button = MouseRegion(
      cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: a.onTap,
        child: Opacity(
          opacity: disabled ? 0.45 : 1,
          child: Container(
            width: compact && !labelled ? 44 : null,
            height: compact ? 44 : null,
            constraints: compact
                ? const BoxConstraints(minWidth: 44, minHeight: 44)
                : null,
            padding: compact && !labelled
                ? EdgeInsets.zero
                : EdgeInsets.symmetric(
                    horizontal: compact ? 10 : 13,
                    vertical: compact ? 0 : 9,
                  ),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppUi.radiusSm),
              border: Border.all(color: border, width: 1.1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                GameIcon(a.icon, size: 14, color: tint),
                if (!compact || labelled) ...[
                  const SizedBox(width: 7),
                  Text(
                    a.label,
                    style: AppUi.button.copyWith(
                      fontSize: 11,
                      color: AppUi.textHi,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    return compact ? Tooltip(message: a.label, child: button) : button;
  }
}

/// Sağ segmentteki derin-menü kapısı.
class _MenuButton extends StatefulWidget {
  final GameIconData icon;
  final String label;
  final int badge;
  final bool compact;
  final VoidCallback onTap;
  const _MenuButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.compact = false,
    this.badge = 0,
  });
  @override
  State<_MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<_MenuButton> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          // Mobil: yuvayla AYNI yükseklik ([MobileUi.actionH]) — 52'ydi ve
          // 48'lik alt hatta 4px taşıyordu. Genişlik 56: 50'de "DEFTER" ile
          // "DİVAN" etiketleri birbirine değiyordu (ekranda tek bir bulanık
          // kelime kütlesi gibi duruyordu).
          width: widget.compact ? 56 : 58,
          height: widget.compact ? MobileUi.actionH : null,
          padding: EdgeInsets.symmetric(vertical: widget.compact ? 3 : 7),
          decoration: BoxDecoration(
            color: _hover ? AppUi.surface2 : Colors.transparent,
            borderRadius: BorderRadius.circular(AppUi.radiusSm),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  GameIcon(
                    // Mobilde 16: alt hattaki bütün semboller (İNŞA dahil) aynı
                    // boyda olsun, 11px etiketin üstünde şişkin durmasın.
                    widget.icon,
                    size: widget.compact ? 16 : 20,
                    color: _hover ? AppUi.accentSoft : AppUi.textMid,
                  ),
                  if (widget.badge > 0)
                    Positioned(
                      right: -8,
                      top: -6,
                      child: Container(
                        // Rozet 15dp/9px'ti ve mobil yazı tabanının DIŞINDA
                        // bırakılmıştı — telefonda okunmuyordu. Tabana girdi,
                        // daire de ona göre büyüdü.
                        constraints: const BoxConstraints(minWidth: 17),
                        height: 17,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: AppUi.accent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${widget.badge}',
                          style: AppUi.button.copyWith(
                            fontSize: widget.compact ? 10 : 9,
                            color: AppUi.ink,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                widget.label.toUpperCase(),
                style: AppUi.label.copyWith(
                  fontSize: widget.compact ? 11 : 7.5,
                  letterSpacing: 0.8,
                  color: _hover ? AppUi.textMid : AppUi.textLo,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// GÖREV TAKİPÇİSİ — sağ üst köşe, ince kart. Yalnız AKTİF görevi ve ilerlemeyi
/// gösterir; tam liste + kademeler Defter'de (bkz. konsept 04). Eski sürekli-açık
/// sol ObjectivePanel'in yerini alır.
class QuestTracker extends StatelessWidget {
  final GameIconData icon;
  final String activeLabel;

  /// Kademe adı (başlık) + tamamlanan/toplam.
  final String tierName;
  final int done;
  final int total;
  final VoidCallback onOpen;

  /// ADIMIN NASIL YAPILDIĞI — kartın var oluş sebebi.
  ///
  /// Bu metin (bkz. Quest.hint) hep üretiliyordu ama hiçbir yerde
  /// ÇİZİLMİYORDU: takipçi yalnız başlığı gösteriyor, cümle Defter'in Tüzük
  /// sekmesinde saklı kalıyordu. Oyuncunun "ne yapacağım"ı bilip "nasıl"ı
  /// bilmemesinin tek sebebi buydu. null → kart eski ince hâlinde kalır.
  final String? hint;

  /// Görevi isteyen köylünün adı — cümle bir sistem mesajı değil, birinin
  /// ricası gibi okunsun diye.
  final String? speakerName;

  /// Genişletilmiş mi. Kuruluşta açık gelir, köy kurulunca ince banda döner.
  final bool expanded;
  final VoidCallback? onToggleExpand;

  /// "Göster" — kamerayı hedefe götürür + öğretici spotu açar. null ise
  /// düğme çizilmez (gösterilecek bir yeri olmayan adımlar).
  final VoidCallback? onShow;

  const QuestTracker({
    super.key,
    required this.icon,
    required this.activeLabel,
    required this.tierName,
    required this.done,
    required this.total,
    required this.onOpen,
    this.hint,
    this.speakerName,
    this.expanded = false,
    this.onToggleExpand,
    this.onShow,
  });

  @override
  Widget build(BuildContext context) {
    final frac = total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0);
    // Genişleme yalnız gösterilecek bir ipucu VARSA anlamlı — cümlesiz açılan
    // kart sadece boşluk büyütür.
    final open = expanded && hint != null;

    if (useCompactGameUi(context)) {
      // Sağ ray'ın devamı: aynı cam, aynı yarıçap, RAY'IN GENİŞLİĞİ (dışarıdan
      // Positioned width'i ile gelir). Kendi maxWidth'ini dayatmıyor — ayrı
      // genişlikte bir kutu olduğu an sağ kenar yine tırtıklanıyordu.
      return MobileSurface(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onToggleExpand ?? onOpen,
              child: SizedBox(
                height: MobileUi.tap,
                child: Row(
                  children: [
                    GameIcon(icon, size: 16, color: AppUi.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        activeLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppUi.bodyHi.copyWith(fontSize: 11.5),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$done/$total',
                      style:
                          AppUi.number.copyWith(fontSize: 11, color: AppUi.sage),
                    ),
                    if (hint != null) ...[
                      const SizedBox(width: 6),
                      Transform.rotate(
                        angle: open ? -1.5708 : 1.5708,
                        child: const GameIcon(GameIconData.chevron,
                            size: 13, color: AppUi.textLo),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (open) ...[
              const SizedBox(height: 2),
              _hintBlock(compact: true),
              const SizedBox(height: 10),
            ],
          ],
        ),
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        width: open ? 248 : 208,
        padding: const EdgeInsets.fromLTRB(13, 10, 13, 11),
        decoration: BoxDecoration(
          color: const Color(0xEB14161A),
          borderRadius: BorderRadius.circular(AppUi.radius),
          border: Border.all(
            // Kuruluşta kart oyuncunun bakması GEREKEN yer — kenarı ember.
            color: open ? AppUi.accent.withValues(alpha: 0.45) : AppUi.line,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Künye satırı → Defter'in Tüzük bölümü (tam liste orada).
            GestureDetector(
              onTap: onOpen,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  const GameIcon(GameIconData.scroll, size: 12, color: AppUi.accent),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      tierName.toUpperCase(),
                      overflow: TextOverflow.ellipsis,
                      style: AppUi.title.copyWith(
                        fontSize: 10,
                        letterSpacing: 1.1,
                        color: AppUi.accentSoft,
                      ),
                    ),
                  ),
                  Text(
                    '$done/$total',
                    style: AppUi.number.copyWith(
                      fontSize: 10,
                      color: AppUi.sage,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 9),
            GestureDetector(
              onTap: hint == null ? onOpen : onToggleExpand,
              behavior: HitTestBehavior.opaque,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: GameIcon(icon, size: 14, color: AppUi.accent),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      activeLabel,
                      // Açıkken başlık kırpılmaz: kuruluş adımlarının adı uzun
                      // ("Sepeti birine ver, ilk yiyecek gelsin") ve tek satıra
                      // sıkışınca cümlenin yarısı kayboluyordu.
                      maxLines: open ? 3 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppUi.bodyHi.copyWith(fontSize: 12.5, height: 1.3),
                    ),
                  ),
                  if (hint != null) ...[
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Transform.rotate(
                        angle: open ? -1.5708 : 1.5708,
                        child: const GameIcon(GameIconData.chevron,
                            size: 12, color: AppUi.textLo),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (open) ...[
              const SizedBox(height: 9),
              _hintBlock(compact: false),
            ],
            const SizedBox(height: 9),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Container(
                height: 4,
                color: AppUi.surface0,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: frac == 0 ? 0.06 : frac,
                    child: Container(color: AppUi.accent),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// NASIL YAPILIR bloğu — isteyen kişi + cümle + "Göster".
  Widget _hintBlock({required bool compact}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
      decoration: BoxDecoration(
        color: AppUi.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppUi.radiusSm),
        border: Border.all(color: AppUi.accent.withValues(alpha: 0.32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (speakerName case final who?) ...[
            Text(
              '$who istiyor',
              style: AppUi.label.copyWith(
                fontSize: 9,
                color: AppUi.accentSoft,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
          ],
          Text(
            hint ?? '',
            style: AppUi.body.copyWith(
              fontSize: compact ? 11.5 : 11,
              color: AppUi.textHi,
              height: 1.45,
            ),
          ),
          if (onShow != null) ...[
            const SizedBox(height: 9),
            SizedBox(
              height: 30,
              child: AppButton(
                label: 'Göster',
                icon: GameIconData.star,
                kind: AppButtonKind.tonal,
                height: 30,
                expand: true,
                onTap: onShow,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
