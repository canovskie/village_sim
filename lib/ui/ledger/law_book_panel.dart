import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../systems/governance/estate_system.dart';
import '../../systems/governance/law_book.dart';
import '../../systems/governance/law_compass.dart';
import '../../systems/governance/oral_tradition.dart';
import '../../systems/governance/regime.dart';
import '../../text/voice.dart';
import '../core/app_ui.dart';
import '../core/mobile_ui.dart';
import '../core/semantic_icon.dart';
import 'law_compass_view.dart';
import 'ledger_board.dart';

part 'law_book_hex.dart';
part 'law_seal_ritual.dart';

/// KANUNNAME — ALTIGEN PETEK MİMARİSİ.
///
/// 30+ hüküm tek düzlemde göz yoruyordu. İki katman: üstte bir avuç TEMA
/// (altıgen çiçek — merkez göbek + 6 yaprak), bir temaya dokununca o konunun
/// 3-6 hükmü okunur satır olarak açılır. Bir hükme dokun → kendi meclisi
/// (mühür ritüeli). Arama temaları atlar, doğrudan hükme gider.
///
///   • Açılışta çiçek merkezden dışa doğru açılır (bloom).
///   • Arkada meşale közleri yükselir (levha ocakla aydınlanmış gibi).
///   • Köyün Sesi'nin teması altın bir hâleyle nabız atar.
///   • Mühür geri alınmaz + bir dönemde tek hüküm (mürekkep) korunur —
///     bu yüzden toplu toggle YOK, her hüküm kendi meclisini açar.

enum _LawState { enacted, available, graveLocked, hidden }

enum _NodeState { sealed, open, next, locked, foreclosed }

/// Tema rengi — petek yapraklarını ayırır (kol renklerinden türer/genişler).
Color themeColor(LawTheme t) => switch (t) {
  LawTheme.toprak => AppUi.sage,
  LawTheme.suru => const Color(0xFFC9A24B),
  LawTheme.aile => const Color(0xFFC97B94),
  LawTheme.koy => AppUi.accent,
  LawTheme.asayis => AppUi.rust,
  LawTheme.inanc => AppUi.info,
};

class LawBookView extends StatefulWidget {
  final Set<String> sealed;

  /// Mühür günleri (ferman id → oyun günü). Boş/eksik = damgasız defter.
  final Map<String, int> sealedOn;

  final LawContext ctx;
  final String? spotlightId;
  final double inkDrySec;
  final double inkDryTotalSec;
  final int seed;
  final void Function(LawDef law) onOpenLaw;

  /// REJİM — defterin başındaki kadran bunları okur. null = rejim sistemi
  /// bağlanmamış yüzey (preview/harness); kart eski hâliyle çizilir.
  final RegimeRule? rule;
  final double unrest;
  final VillageRegime? sworn;
  final VoidCallback? onSwearOath;

  /// Çürüme (Faz 3) + imanın mekanik karşılığı — kadran bunları da çizer.
  final double rot;
  final FaithEffect? faith;

  /// Mühürlü bir hükmü BEDELLE feshet. null = fesih kapalı (harness).
  final void Function(LawDef law)? onRepeal;

  /// TAHTA KİPİ (telefon yatay) — pusula · arama · petek ALT ALTA değil YAN
  /// YANA. Alt alta dizilim 360dp'lik defter penceresinde peteği tamamen fold
  /// altına itiyordu (bkz. ui/ledger/ledger_board.dart); iki sütunda üçü de ilk
  /// karede görünür ve hiçbiri kaydırma istemez.
  final bool board;

  const LawBookView({
    super.key,
    required this.sealed,
    required this.onOpenLaw,
    this.sealedOn = const {},
    this.ctx = const LawContext(),
    this.spotlightId,
    this.inkDrySec = 0,
    this.inkDryTotalSec = 0,
    this.seed = 0,
    this.rule,
    this.unrest = 0,
    this.sworn,
    this.onSwearOath,
    this.onRepeal,
    this.rot = 0,
    this.faith,
    this.board = false,
  });

  @override
  State<LawBookView> createState() => _LawBookViewState();
}

class _LawBookViewState extends State<LawBookView>
    with TickerProviderStateMixin {
  // Petek açılışı (bloom). CAPTURE'da son karesiyle başlar: harness kareyi
  // açılıştan ~200ms sonra alıyordu ve peteğin yedi altıgeninden ancak üçü
  // görünüyordu — yerleşim doğru olsa bile ekran görüntüsü "yarısı eksik" gibi
  // okunuyor, doğrulama aracı yanlış alarm veriyordu.
  late final AnimationController _bloom = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 720),
    value: AppUi.captureStatic ? 1 : 0,
  )..forward();
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);
  late final AnimationController _embers = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 7000),
  )..repeat();

  final TextEditingController _search = TextEditingController();
  String _query = '';
  LawTheme? _open; // null = çiçek görünümü

  /// Kısa ekranda pusula kartı açık mı (bkz. [LawCompassCard.compact]).
  /// Masaüstünde okunmaz — kart orada zaten hep tam çizilir.
  bool _compassOpen = false;

  bool get _inkWet => widget.inkDrySec > 0.5;

  @override
  void dispose() {
    _bloom.dispose();
    _pulse.dispose();
    _embers.dispose();
    _search.dispose();
    super.dispose();
  }

  // ── Hüküm hâli ─────────────────────────────────────────────────────────────

  /// Hükmün defterdeki hâli. Kapısı kapalı SIRADAN hüküm defterde hiç yoktur
  /// (köyün derdi doğunca belirir); kapısı kapalı AĞIR hüküm gerekçesiyle
  /// kilitli durur — bkz. [LawBook.visible].
  _LawState _stOf(LawDef l) {
    if (widget.sealed.contains(l.id)) return _LawState.enacted;
    if (!LawBook.visible(l, widget.sealed, widget.ctx)) return _LawState.hidden;
    if (LawBook.gateLocked(l, widget.ctx)) return _LawState.graveLocked;
    return _LawState.available;
  }

  _NodeState _nodeOf(_LawState s) => switch (s) {
    _LawState.enacted => _NodeState.sealed,
    _LawState.available => _NodeState.open,
    _ => _NodeState.locked,
  };

  int _enactedInTheme(LawTheme t) =>
      LawBook.ofTheme(t).where((l) => widget.sealed.contains(l.id)).length;

  bool _matches(LawDef l) =>
      _query.isEmpty || l.title.toLowerCase().contains(_query);

  LawDef? get _spotlight =>
      widget.spotlightId == null ? null : LawBook.byId(widget.spotlightId!);

  // ── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // TELEFON YATAY: defterin gövdesine ~300dp kalıyor. Pusula kartı (150) +
    // idame (40) + arama (40) + boşluklar peteği tamamen fold altına itiyordu —
    // kanun defteri açıldığında TEK ferman görünmüyordu. Kısa ekranda pusula
    // tek satırlık künyeye iner (dokununca açılır) ve boşluklar daralır.
    final compact = useCompactGameUi(context);
    if (widget.board) return _boardLayout();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // POLİTİK PUSULA — defterin başında, hükümlerden ÖNCE: "bu defter
        // köyü ne yaptı?". Eski künye şeridi (kol sayan bir cümle + sayaç)
        // buna gömüldü; kimlik artık tahmin değil, ölçülen konum.
        LawCompassCard(
          sealed: widget.sealed,
          totalLaws: kLawBook.length,
          rule: widget.rule,
          unrest: widget.unrest,
          sworn: widget.sworn,
          onSwearOath: widget.onSwearOath,
          rot: widget.rot,
          faith: widget.faith,
          compact: compact,
          expanded: _compassOpen,
          onToggleExpand: () => setState(() => _compassOpen = !_compassOpen),
        ),
        // Kısa ekranda idame + arama TEK satır: ikisi de tek satırlık şerit,
        // alt alta konunca 48dp'yi peteğin payından yiyorlardı.
        if (compact) ...[
          const SizedBox(height: 8),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(child: _searchBar()),
                if (totalUpkeepLabel(widget.sealed) != null) ...[
                  const SizedBox(width: 8),
                  _totalUpkeepBar(topPad: 0),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
        ] else ...[
          _totalUpkeepBar(),
          const SizedBox(height: 12),
          _searchBar(),
          const SizedBox(height: 12),
        ],
        if (_query.isNotEmpty)
          _searchResults()
        else if (_open != null)
          _themeDrill(_open!)
        else
          _flowerView(),
      ],
    );
  }

  // ── TAHTA DİZİLİMİ (telefon yatay) ───────────────────────────────────────

  /// İki sütun: SOLDA köyün yönü (pusula + günlük idame), SAĞDA defterin
  /// kendisi (arama + petek / tema açılımı).
  ///
  /// Ayrım keyfi değil: sol sütun "köy nereye gidiyor" sorusunun DURAĞAN
  /// cevabı, sağ sütun oyuncunun içinde gezindiği YER. Alt alta dizilince
  /// durağan olan, gezinileni ekrandan kovuyordu.
  Widget _boardLayout() {
    final upkeep = totalUpkeepLabel(widget.sealed);
    return BoardRow(
      children: [
        BoardCol(
          flex: 38,
          head: 'POLİTİK PUSULA',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Kart dikey kipte kısaltılmış hâliyle iPhone 11'e sığar; daha
              // ALÇAK bir cihazda (ör. 360dp'lik ucuz Android) yine de taşabilir.
              // scaleDown emniyet kemeri: gereken cihazda küçültür, gerekmeyende
              // hiçbir şey yapmaz. Kaydırma açmaktan iyidir — kadran ölçekle
              // okunur kalır, yarım kalan bir sütun okunmaz.
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) => FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: c.maxWidth,
                      child: LawCompassCard(
                        sealed: widget.sealed,
                        totalLaws: kLawBook.length,
                        rule: widget.rule,
                        unrest: widget.unrest,
                        sworn: widget.sworn,
                        onSwearOath: widget.onSwearOath,
                        rot: widget.rot,
                        faith: widget.faith,
                        vertical: true,
                      ),
                    ),
                  ),
                ),
              ),
              if (upkeep != null) ...[
                const SizedBox(height: 8),
                _totalUpkeepBar(topPad: 0),
              ],
            ],
          ),
        ),
        BoardCol(
          flex: 62,
          head: _open == null ? 'KANUNNAME' : _open!.label.toUpperCase(),
          headTrailing: BoardCount(
            '${widget.sealed.length}/${kLawBook.length} mühürlü',
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: _searchBar()),
                  if (_open != null && _query.isEmpty) ...[
                    const SizedBox(width: 8),
                    _boardBackChip(),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Expanded(child: _boardBody()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _boardBody() {
    if (_query.isNotEmpty) {
      final hits = _searchHits();
      return BoardPager(
        count: hits.length,
        rowH: 52,
        rowGap: 6,
        emptyText: 'Bu adda bir ferman yok.',
        itemBuilder: (_, i) => _boardLawRow(hits[i], showTheme: true),
      );
    }
    if (_open != null) {
      final laws = [
        for (final l in LawBook.ofTheme(_open!))
          if (_stOf(l) != _LawState.hidden) l,
      ];
      return BoardPager(
        count: laws.length,
        rowH: 52,
        rowGap: 6,
        emptyText:
            'Bu tema henüz uyanmadı — köyün hâli buranın hükümlerini açmıyor.',
        itemBuilder: (_, i) => _boardLawRow(laws[i]),
      );
    }
    // PETEK — sabit geometrili bir kompozisyon (330×342). Sütuna sığmadığı
    // kadarını ölçekleyerek girer; parçalayıp yeniden dizmek çiçeği çiçek
    // olmaktan çıkarırdı, oysa oradaki bilgi zaten "altı tema + ilerleme".
    return LayoutBuilder(
      builder: (context, c) => Center(
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: _hw + 1.5 * _hw,
            height: 3 * _hh,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: _embers,
                      builder: (_, _) =>
                          CustomPaint(painter: _EmberPainter(_embers.value)),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_bloom, _pulse]),
                    builder: (_, _) {
                      final spot = _spotlight;
                      final voiceTheme = spot == null
                          ? null
                          : LawBook.themeOf(spot);
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _hexAt('C', isHub: true),
                          for (final (t, pos) in _petals)
                            _hexAt(pos, theme: t, voice: t == voiceTheme),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _boardBackChip() {
    final color = themeColor(_open!);
    return GestureDetector(
      onTap: () => setState(() => _open = null),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: MobileUi.tap,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppUi.surface2,
          borderRadius: BorderRadius.circular(AppUi.radiusSm),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_back_rounded, size: 15, color: color),
            const SizedBox(width: 6),
            Text(
              'TEMALAR',
              style: AppUi.label.copyWith(fontSize: 9, color: AppUi.textHi),
            ),
          ],
        ),
      ),
    );
  }

  /// Tahta için SABİT BOYLU (52dp) ferman satırı.
  ///
  /// Sayfalanabilmesi için boyunun bilinmesi şart (bkz. [BoardPager]); masaüstü
  /// kartındaki üç satırlık özet tek satıra iner. Kaybolan bilgi yok: hükmün
  /// tam metni zaten bir dokunuş arkasındaki mühür ritüelinde.
  Widget _boardLawRow(LawDef l, {bool showTheme = false}) {
    final st = _stOf(l);
    final color = branchColor(l.branch);
    final tappable = st == _LawState.available && !_inkWet;
    final spotlight = l.id == widget.spotlightId && st == _LawState.available;
    final customary = OralTradition.supports(l, widget.ctx.memory);
    final (tag, tagColor) = _tagFor(
      st,
      color,
      spotlight,
      customary: customary,
      day: widget.sealedOn[l.id],
    );
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, _) => BoardTile(
        onTap: tappable ? () => widget.onOpenLaw(l) : null,
        tint: st == _LawState.enacted ? color : null,
        highlight: spotlight,
        padding: const EdgeInsets.fromLTRB(8, 6, 9, 6),
        child: Row(
          children: [
            _Medallion(
              state: _nodeOf(st),
              color: color,
              icon: l.icon,
              size: 28,
              pulse: tappable ? _pulse.value : 0,
              pop: 0,
              selected: false,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _shortTitle(l.title),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppUi.bodyHi.copyWith(
                            fontSize: 12,
                            height: 1.1,
                            color: st == _LawState.graveLocked
                                ? AppUi.textLo
                                : AppUi.textHi,
                          ),
                        ),
                      ),
                      if (showTheme) ...[
                        const SizedBox(width: 5),
                        SemanticIcon(
                          LawBook.themeOf(l).icon,
                          size: 10,
                          color: AppUi.textLo,
                          fallback: GameIconData.scroll,
                        ),
                      ],
                      const SizedBox(width: 5),
                      _stateDot(st, color),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          tag,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppUi.label.copyWith(
                            fontSize: 7.5,
                            color: tagColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      if (upkeepLabel(l) != null) ...[
                        const SizedBox(width: 5),
                        _upkeepChip(l),
                      ],
                      if (st == _LawState.enacted &&
                          widget.onRepeal != null &&
                          LawBook.repealable(l)) ...[
                        const SizedBox(width: 5),
                        _repealChip(l),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// DEFTERİN GÜNLÜK HESABI — mühürlü fermanların toplam idamesi. Defter
  /// kabardıkça köyün sırtındaki yük de kabarır; oyuncu bu toplamı görmeden
  /// öşür + kutsal gün + gece bekçisini üst üste mühürleyip ambarın neden
  /// eridiğini anlayamıyordu. Hiçbir idame yoksa satır hiç çizilmez.
  /// [topPad] 0 verilirse şerit kendi üst boşluğunu koymaz — kısa ekranda
  /// arama kutusuyla aynı satıra girdiği için gerekli. Aynı yerleşimde
  /// "Defterin günlük idamesi" açıklaması da düşer; kalan yalnız rakamdır
  /// (satırın tamamı zaten idame şeridi olarak okunuyor).
  Widget _totalUpkeepBar({double topPad = 10}) {
    final label = totalUpkeepLabel(widget.sealed);
    if (label == null) return const SizedBox.shrink();
    final (gold, food) = LawBook.dailyUpkeep(widget.sealed);
    final drain = gold < 0 || food < 0;
    final c = drain ? AppUi.rust : AppUi.sage;
    final inline = topPad == 0;
    return Padding(
      padding: EdgeInsets.only(top: topPad),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppUi.surface0,
          borderRadius: BorderRadius.circular(AppUi.radiusSm),
          border: Border.all(color: c.withValues(alpha: 0.28)),
        ),
        child: Row(
          // Expanded yalnız tam-genişlik hâlinde kullanılabilir; satır içi
          // hâlde Row kendi içeriği kadar dar kalmalı.
          mainAxisSize: inline ? MainAxisSize.min : MainAxisSize.max,
          children: [
            Icon(
              drain ? Icons.trending_down : Icons.trending_up,
              size: 14,
              color: c,
            ),
            const SizedBox(width: 8),
            if (inline)
              Text(
                label,
                style: AppUi.bodyHi.copyWith(
                  fontSize: 12,
                  color: c,
                  fontWeight: FontWeight.w700,
                ),
              )
            else ...[
              Expanded(
                child: Text(
                  'Defterin günlük idamesi',
                  style: AppUi.body.copyWith(
                    fontSize: 11.5,
                    color: AppUi.textMid,
                  ),
                ),
              ),
              Text(
                label,
                style: AppUi.bodyHi.copyWith(
                  fontSize: 12,
                  color: c,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _searchBar() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppUi.surface0,
        borderRadius: BorderRadius.circular(AppUi.radiusSm),
        border: Border.all(color: AppUi.line),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 16, color: AppUi.textLo),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              cursorColor: AppUi.accent,
              style: AppUi.body.copyWith(fontSize: 12.5, color: AppUi.textHi),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Ferman ara…',
                hintStyle: AppUi.body.copyWith(
                  fontSize: 12.5,
                  color: AppUi.textLo,
                ),
              ),
            ),
          ),
          if (_query.isNotEmpty)
            GestureDetector(
              onTap: () => setState(() {
                _query = '';
                _search.clear();
              }),
              child: const Icon(Icons.close, size: 15, color: AppUi.textLo),
            ),
        ],
      ),
    );
  }

  // ── ÇİÇEK ──────────────────────────────────────────────────────────────────

  static const double _hw = 132, _hh = 114, _cx = 165, _cy = 171;
  static const Map<String, List<double>> _off = {
    'C': [0, 0],
    'N': [0, -_hh],
    'S': [0, _hh],
    'NE': [0.75 * _hw, -0.5 * _hh],
    'SE': [0.75 * _hw, 0.5 * _hh],
    'NW': [-0.75 * _hw, -0.5 * _hh],
    'SW': [-0.75 * _hw, 0.5 * _hh],
  };
  static const Map<String, int> _bloomOrder = {
    'C': 0,
    'N': 1,
    'NE': 2,
    'SE': 3,
    'S': 4,
    'SW': 5,
    'NW': 6,
  };
  // Yaprak sırası (saat yönü): üst → sağ-üst → sağ-alt → alt → sol-alt → sol-üst.
  static const List<(LawTheme, String)> _petals = [
    (LawTheme.toprak, 'N'),
    (LawTheme.suru, 'NE'),
    (LawTheme.aile, 'SE'),
    (LawTheme.koy, 'S'),
    (LawTheme.asayis, 'SW'),
    (LawTheme.inanc, 'NW'),
  ];

  Widget _flowerView() {
    final spot = _spotlight;
    final voiceTheme = spot == null ? null : LawBook.themeOf(spot);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (spot != null) _voiceCaption(spot),
        const SizedBox(height: 4),
        Center(
          child: SizedBox(
            width: _hw + 1.5 * _hw,
            height: 3 * _hh,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: _embers,
                      builder: (_, _) =>
                          CustomPaint(painter: _EmberPainter(_embers.value)),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_bloom, _pulse]),
                    builder: (_, _) => Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _hexAt('C', isHub: true),
                        for (final (t, pos) in _petals)
                          _hexAt(pos, theme: t, voice: t == voiceTheme),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Bir temaya dokun — o konunun hükümleri açılır.',
          textAlign: TextAlign.center,
          style: AppUi.body.copyWith(
            fontSize: 11.5,
            color: AppUi.textLo,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _hexAt(
    String pos, {
    bool isHub = false,
    LawTheme? theme,
    bool voice = false,
  }) {
    final off = _off[pos]!;
    final start = _bloomOrder[pos]! * 0.09;
    final raw = ((_bloom.value - start) / 0.55).clamp(0.0, 1.0);
    final t = Curves.easeOutBack.transform(raw);
    final color = isHub ? AppUi.gold : themeColor(theme!);
    final total = isHub ? kLawBook.length : LawBook.ofTheme(theme!).length;
    final done = isHub ? widget.sealed.length : _enactedInTheme(theme!);

    return Positioned(
      left: _cx + off[0] - _hw / 2,
      top: _cy + off[1] - _hh / 2,
      child: Transform.scale(
        scale: 0.3 + 0.7 * t,
        child: Opacity(
          opacity: raw,
          child: _Hex(
            icon: isHub ? '⚖' : theme!.icon,
            label: isHub ? 'KANUNNAME' : theme!.label,
            progress: '$done / $total',
            color: color,
            isHub: isHub,
            voicePulse: voice ? _pulse.value : -1,
            onTap: isHub ? null : () => setState(() => _open = theme),
          ),
        ),
      ),
    );
  }

  Widget _voiceCaption(LawDef l) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppUi.gold.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppUi.gold.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('◆', style: TextStyle(fontSize: 8, color: AppUi.gold)),
          const SizedBox(width: 7),
          Flexible(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'KÖYÜN SESİ  ',
                    style: AppUi.label.copyWith(
                      fontSize: 8.5,
                      color: AppUi.gold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  TextSpan(
                    text: l.title,
                    style: AppUi.body.copyWith(
                      fontSize: 11,
                      color: AppUi.textMid,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ── TEMA AÇILIMI ───────────────────────────────────────────────────────────

  Widget _themeDrill(LawTheme t) {
    final color = themeColor(t);
    final laws = [
      for (final l in LawBook.ofTheme(t))
        if (_stOf(l) != _LawState.hidden) l,
    ];
    final done = _enactedInTheme(t);
    return Column(
      key: ValueKey(t),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _open = null),
          child: Container(
            padding: const EdgeInsets.fromLTRB(11, 9, 15, 9),
            decoration: BoxDecoration(
              color: AppUi.surface2,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back_rounded, size: 17, color: color),
                const SizedBox(width: 7),
                Text(
                  'TÜM TEMALAR',
                  style: AppUi.label.copyWith(
                    fontSize: 11,
                    color: AppUi.textHi,
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _themeBadge(t, color),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t.label,
                  style: AppUi.title.copyWith(fontSize: 18, height: 1.1),
                ),
                const SizedBox(height: 2),
                Text(
                  '$done / ${LawBook.ofTheme(t).length} hüküm deftere girdi',
                  style: AppUi.body.copyWith(
                    fontSize: 10.5,
                    color: AppUi.textLo,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.45),
                color.withValues(alpha: 0),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < laws.length; i++) ...[
          _lawTile(laws[i], entrance: i),
          if (i < laws.length - 1) const SizedBox(height: 8),
        ],
        _dormantNote(t, color, laws.isEmpty),
      ],
    );
  }

  /// Bu temada köyün HÂLİ elvermediği için henüz deftere düşmemiş hükümler.
  /// Liste doluysa yalnız sayısını fısıldar (defter büyüyor hissi); tema
  /// bomboşsa neden boş olduğunu köyün ağzından söyler — oyuncu "bug mu?"
  /// demesin, "köyüm daha oraya gelmedi" desin.
  Widget _dormantNote(LawTheme t, Color color, bool themeEmpty) {
    final dormant = [
      for (final l in LawBook.ofTheme(t))
        if (!widget.sealed.contains(l.id) &&
            !LawBook.groupTaken(l, widget.sealed) &&
            LawBook.gateLocked(l, widget.ctx) &&
            !l.grave)
          l,
    ];
    if (dormant.isEmpty) return const SizedBox.shrink();

    final reasons = <String>{
      for (final l in dormant)
        if (l.gateReason.isNotEmpty) l.gateReason,
    }.take(themeEmpty ? 2 : 0).toList();

    return Padding(
      padding: EdgeInsets.only(top: themeEmpty ? 4 : 14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
        decoration: BoxDecoration(
          color: AppUi.surface2.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.16)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              themeEmpty
                  ? '🔒 Bu sayfa henüz yazılmadı — ${dormant.length} hüküm köyün hâlini bekliyor.'
                  : '🔒 ${dormant.length} hüküm daha var; köyün hâli değişince deftere düşer.',
              style: AppUi.body.copyWith(
                fontSize: 11,
                color: AppUi.textLo,
                height: 1.35,
              ),
            ),
            for (final r in reasons) ...[
              const SizedBox(height: 7),
              Text(
                '“$r”',
                style: AppUi.body.copyWith(
                  fontSize: 10.5,
                  color: AppUi.textLo.withValues(alpha: 0.85),
                  fontStyle: FontStyle.italic,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _themeBadge(LawTheme t, Color color) => SizedBox(
    width: 46,
    height: 40,
    child: ClipPath(
      clipper: _HexClipper(),
      child: Container(
        color: color.withValues(alpha: 0.18),
        alignment: Alignment.center,
        child: SemanticIcon(
          t.icon,
          size: 20,
          color: color,
          fallback: GameIconData.scroll,
        ),
      ),
    ),
  );

  // ── ARAMA ──────────────────────────────────────────────────────────────────

  /// Aramanın vurduğu fermanlar — hem masaüstü listesi hem tahta sayfalayıcısı
  /// aynı sonucu okusun diye ayrı.
  List<LawDef> _searchHits() => [
    for (final l in kLawBook)
      if (_stOf(l) != _LawState.hidden && _matches(l)) l,
  ];

  Widget _searchResults() {
    final hits = _searchHits();
    if (hits.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 26),
        child: Center(
          child: Text(
            '“$_query” ile eşleşen ferman yok.',
            style: AppUi.body.copyWith(
              fontSize: 11.5,
              color: AppUi.textLo,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${hits.length} sonuç',
          style: AppUi.label.copyWith(
            fontSize: 9,
            color: AppUi.textLo,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < hits.length; i++) ...[
          _lawTile(hits[i], entrance: i, showTheme: true),
          if (i < hits.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }

  // ── HÜKÜM KUTUCUĞU ─────────────────────────────────────────────────────────

  Widget _lawTile(LawDef l, {int entrance = 0, bool showTheme = false}) {
    final st = _stOf(l);
    final color = branchColor(l.branch);
    final tappable = st == _LawState.available && !_inkWet;
    final spotlight = l.id == widget.spotlightId && st == _LawState.available;
    final customary = OralTradition.supports(l, widget.ctx.memory);
    final (tag, tagColor) = _tagFor(
      st,
      color,
      spotlight,
      customary: customary,
      day: widget.sealedOn[l.id],
    );

    return GestureDetector(
      onTap: tappable ? () => widget.onOpenLaw(l) : null,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, _) => Container(
          padding: const EdgeInsets.fromLTRB(10, 9, 11, 9),
          decoration: BoxDecoration(
            color: st == _LawState.enacted
                ? color.withValues(alpha: 0.06)
                : AppUi.surface0,
            borderRadius: BorderRadius.circular(AppUi.radiusSm),
            border: Border.all(
              color: spotlight
                  ? color.withValues(alpha: 0.55)
                  : st == _LawState.enacted
                  ? color.withValues(alpha: 0.28)
                  : AppUi.line,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Medallion(
                state: _nodeOf(st),
                color: color,
                icon: l.icon,
                size: 32,
                pulse: tappable ? _pulse.value : 0,
                pop: 0,
                selected: false,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _shortTitle(l.title),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppUi.bodyHi.copyWith(
                              fontSize: 12.5,
                              height: 1.1,
                              color: st == _LawState.graveLocked
                                  ? AppUi.textLo
                                  : AppUi.textHi,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (showTheme) ...[
                          const SizedBox(width: 6),
                          SemanticIcon(
                            LawBook.themeOf(l).icon,
                            size: 10,
                            color: AppUi.textLo,
                            fallback: GameIconData.scroll,
                          ),
                        ],
                        const SizedBox(width: 6),
                        _stateDot(st, color),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      LawBook.summary(l.id),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppUi.body.copyWith(
                        fontSize: 10,
                        height: 1.3,
                        color: st == _LawState.graveLocked
                            ? AppUi.textLo.withValues(alpha: 0.7)
                            : AppUi.textMid,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            tag,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppUi.label.copyWith(
                              fontSize: 7.5,
                              color: tagColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        if (upkeepLabel(l) != null) ...[
                          _upkeepChip(l),
                          const SizedBox(width: 6),
                        ],
                        if (st == _LawState.enacted &&
                            widget.onRepeal != null &&
                            LawBook.repealable(l))
                          _repealChip(l),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// GÜNLÜK İDAME rozeti — bir ferman imzalandığı gün bitmiyor; her sabah
  /// köyün sırtında. [LawBook.dailyUpkeep] bunu her gün ambardan/keseden
  /// sessizce kesiyordu ve hiçbir yüzeyde yazmıyordu: oyuncu neden açlığa
  /// girdiğini göremiyordu. Artık rakam, kesildiği yerin yanında duruyor.
  Widget _upkeepChip(LawDef l) {
    final label = upkeepLabel(l)!;
    final drain = l.goldPerDay < 0 || l.foodPerDay < 0;
    final c = drain ? AppUi.rust : AppUi.sage;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: c.withValues(alpha: 0.10),
        border: Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: AppUi.label.copyWith(
          fontSize: 7.5,
          letterSpacing: 0.4,
          color: c,
        ),
      ),
    );
  }

  /// FESİH — "mühür ebediyen geri alınmaz" tezi gevşetildi: günlük geçim
  /// hükümleri bozulabilir. Bedava değil (mürekkep uzun kurur, moral iz
  /// bırakır) ve kimliği yazan hükümlerde hiç görünmez.
  Widget _repealChip(LawDef l) => GestureDetector(
    onTap: _inkWet ? null : () => widget.onRepeal!(l),
    behavior: HitTestBehavior.opaque,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppUi.rust.withValues(alpha: _inkWet ? 0.18 : 0.45),
        ),
      ),
      child: Text(
        'feshet',
        style: AppUi.label.copyWith(
          fontSize: 7.5,
          letterSpacing: 0.8,
          color: _inkWet ? AppUi.textLo.withValues(alpha: 0.5) : AppUi.rust,
        ),
      ),
    ),
  );

  /// Hükmün altındaki tek satırlık künye. Mühürlü fermanda GÜN de yazar:
  /// "hangi kışın ortasında imzalamıştım?" sorusunun cevabı kararın yanında
  /// dursun (damgasız eski kayıtlar sade hâline döner).
  (String, Color) _tagFor(
    _LawState st,
    Color color,
    bool spotlight, {
    required bool customary,
    int? day,
  }) => switch (st) {
    _LawState.enacted => (
      day != null && day > 0 ? '$day. gün mühürlendi' : 'deftere girdi',
      AppUi.gold,
    ),
    _LawState.graveLocked => ('kilitli — köy büyüyünce', AppUi.textLo),
    _ =>
      _inkWet
          ? ('müzakere bekliyor', AppUi.textLo)
          : customary
          ? ('yerleşmiş töre · yazıya geçir', AppUi.gold)
          : spotlight
          ? ('köyün sesi · şimdi gerek', color)
          : ('çıkarılabilir', color),
  };

  String _shortTitle(String t) {
    for (final suf in const [' Fermanı', ' Beratı']) {
      if (t.endsWith(suf)) return t.substring(0, t.length - suf.length);
    }
    return t;
  }

  Widget _stateDot(_LawState s, Color color) {
    final c = switch (s) {
      _LawState.enacted => AppUi.gold,
      _LawState.available => _inkWet ? AppUi.textLo : color,
      _ => AppUi.textLo.withValues(alpha: 0.5),
    };
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(shape: BoxShape.circle, color: c),
    );
  }
}
