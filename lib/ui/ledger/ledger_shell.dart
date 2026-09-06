part of 'village_ledger.dart';

/// DEFTER KABUĞU — çerçeve, sayfa zemini, mühür ve bölüm rayı (shell). İçerik VillageLedger'da.
/// Köy Defteri'ne özel dış cilt. Ortak [AppGildedFrame] ağırlığını korur ama
/// köşelerde kayıt işaretleri ve kenar ortalarında bölüm ayraçları ekler.
/// Bunlar çivi/ahşap süsü değil, taş baskı bir arşiv sayfasının geometrisi.
class _LedgerFrame extends StatelessWidget {
  final Widget child;
  const _LedgerFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AppGildedFrame(accent: AppUi.accent, child: child),
        const IgnorePointer(child: CustomPaint(painter: _LedgerFramePainter())),
      ],
    );
  }
}

class _LedgerFramePainter extends CustomPainter {
  const _LedgerFramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final faint = Paint()
      ..color = AppUi.gold.withValues(alpha: 0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final bright = Paint()
      ..color = AppUi.accent.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Dört köşede birbirinin aynası olan kesik kayıt işaretleri.
    for (final sx in [-1.0, 1.0]) {
      for (final sy in [-1.0, 1.0]) {
        final x = sx < 0 ? 8.0 : size.width - 8.0;
        final y = sy < 0 ? 8.0 : size.height - 8.0;
        final p = Path()
          ..moveTo(x, y + sy * 18)
          ..lineTo(x, y + sy * 7)
          ..quadraticBezierTo(x, y, x + sx * 7, y)
          ..lineTo(x + sx * 18, y);
        canvas.drawPath(p, faint);
        canvas.drawCircle(Offset(x + sx * 22, y), 1.4, bright);
      }
    }

    // Cildin üst ve alt orta ayraçları: küçük, keskin bir mühür geometrisi.
    void divider(double y, double sy) {
      final cx = size.width / 2;
      canvas.drawLine(Offset(cx - 34, y), Offset(cx - 8, y), faint);
      canvas.drawLine(Offset(cx + 8, y), Offset(cx + 34, y), faint);
      final diamond = Path()
        ..moveTo(cx, y + sy * 4)
        ..lineTo(cx + 5, y)
        ..lineTo(cx, y - sy * 4)
        ..lineTo(cx - 5, y)
        ..close();
      canvas.drawPath(diamond, bright);
    }

    divider(4, 1);
    divider(size.height - 4, -1);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Bölüm sayfasının çok hafif arşiv alanı: mürekkep tonu köşeden içeri sızar,
/// büyük kayıt yayları yüzeye ölçek verir. Opak kart çizmez; içerik nefes alır.
class _LedgerPageField extends StatelessWidget {
  final Color tone;
  final Widget child;
  const _LedgerPageField({required this.tone, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: _LedgerPageFieldPainter(tone)),
        child,
      ],
    );
  }
}

class _LedgerPageFieldPainter extends CustomPainter {
  final Color tone;
  const _LedgerPageFieldPainter(this.tone);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.92, -0.86),
          radius: 1.12,
          colors: [tone.withValues(alpha: 0.10), Colors.transparent],
        ).createShader(Offset.zero & size),
    );

    final ink = Paint()
      ..color = tone.withValues(alpha: 0.055)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final center = Offset(size.width * 0.94, size.height * 0.12);
    for (final radius in [52.0, 84.0, 118.0]) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        math.pi * 0.45,
        math.pi * 1.05,
        false,
        ink,
      );
    }
    canvas.drawLine(
      Offset(size.width * 0.72, 0),
      Offset(size.width, size.height * 0.28),
      ink,
    );
  }

  @override
  bool shouldRepaint(covariant _LedgerPageFieldPainter oldDelegate) =>
      oldDelegate.tone != tone;
}

/// DEFTER MÜHRÜ — köy içi işlerin TEK kapısı, hep ekranda. Eskiden bu mühür
/// yalnız Divan'ı açardı; nüfus HUD ikonunda, hikâye ⚙ kümesinde, görevler ayrı
/// panodaydı. Artık hepsi bu mührün arkasında: dilekçe mührüyle aynı gilded dil
/// (altın kenar + madalyon + nabız), gündem doldukça kızışır.
/// Dokun → [VillageLedger] açılır.
class LedgerSeal extends StatefulWidget {
  final VoidCallback onTap;

  /// Gündemdeki mesele sayısı (bekleyen dilekçe + mayalananlar). 0 = sakin.
  final int agendaCount;

  /// Köy şu an bir dilekçeye yanıt bekliyor mu — mühür kızarır + nabız hızlanır.
  final bool pendingPetition;

  /// Defter yeni bir mühre açık mı (mürekkep kurudu) — "defter açık" ipucu.
  final bool bookOpen;

  const LedgerSeal({
    super.key,
    required this.onTap,
    this.agendaCount = 0,
    this.pendingPetition = false,
    this.bookOpen = false,
  });

  @override
  State<LedgerSeal> createState() => _LedgerSealState();
}

class _LedgerSealState extends State<LedgerSeal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: _dur(),
  )..repeat(reverse: true);

  bool _hover = false;

  Duration _dur() =>
      Duration(milliseconds: widget.pendingPetition ? 700 : 1900);

  @override
  void didUpdateWidget(LedgerSeal old) {
    super.didUpdateWidget(old);
    if (old.pendingPetition != widget.pendingPetition) {
      _ctrl.duration = _dur();
      _ctrl
        ..reset()
        ..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Sakin gündemde sönük ember; mesele varsa accent; dilekçe beklerken rust.
  Color get _accent => widget.pendingPetition
      ? AppUi.rust
      : (widget.agendaCount > 0 ? AppUi.accent : AppUi.textLo);

  String get _status {
    if (widget.pendingPetition) return 'köy söz bekliyor';
    if (widget.agendaCount > 0) return '${widget.agendaCount} mesele gündemde';
    if (widget.bookOpen) return 'defter yeni mühre açık';
    return 'köyün defteri';
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    // Gündem varken nefes alır; sakinken durur (dikkat çalmaz).
    final alive = widget.agendaCount > 0 || widget.pendingPetition;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final t = alive ? _ctrl.value : 0.0;
            final glow = (alive ? 0.20 : 0.08) + t * 0.34 + (_hover ? 0.18 : 0);
            final scale =
                1.0 +
                t * (widget.pendingPetition ? 0.05 : 0.03) +
                (_hover ? 0.03 : 0);
            return Transform.scale(
              scale: scale,
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 7, 13, 7),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppUi.surface2, AppUi.surface1],
                  ),
                  borderRadius: BorderRadius.circular(AppUi.radius),
                  border: Border.all(
                    color: AppUi.gold.withValues(alpha: _hover ? 0.5 : 0.34),
                    width: 1.1,
                  ),
                  boxShadow: [
                    ...AppUi.softShadow,
                    BoxShadow(
                      color: accent.withValues(alpha: glow),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ⚖ madalyon + (varsa) gündem sayacı rozeti.
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Color.alphaBlend(
                                  accent.withValues(alpha: 0.22),
                                  AppUi.surface0,
                                ),
                                AppUi.surface0,
                              ],
                            ),
                            border: Border.all(
                              color: AppUi.gold.withValues(alpha: 0.6),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.35),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: const Text(
                            '📖',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                        if (widget.agendaCount > 0)
                          Positioned(
                            top: -4,
                            right: -5,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: accent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: accent.withValues(alpha: 0.6),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: Text(
                                '${widget.agendaCount}',
                                style: AppUi.number.copyWith(
                                  fontSize: 9,
                                  color: AppUi.ink,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'KÖY DEFTERİ',
                          style: AppUi.title.copyWith(
                            fontSize: 13,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: accent,
                                boxShadow: [
                                  BoxShadow(
                                    color: accent.withValues(
                                      alpha: 0.4 + t * 0.4,
                                    ),
                                    blurRadius: 5,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _status,
                              style: AppUi.label.copyWith(
                                fontSize: 7.5,
                                letterSpacing: 0.8,
                                color: widget.pendingPetition
                                    ? AppUi.rust
                                    : AppUi.textLo,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─── DEFTERİN RAFI ──────────────────────────────────────────────────────────
/// Bölüm rafı + gövde. Bölüm state'i BURADA durur (dıştaki [VillageLedger]
/// stateless kalsın: sahne her tick rebuild ederken seçili bölüm sıfırlanmaz —
/// gövdeler `bodyFor` ile TEMBEL kurulur, yani görünmeyen bölüm hiç inşa
/// edilmez; 5 bölümü birden kurmak nüfus listesi yüzünden pahalı olurdu).
///
/// Geniş ekranda sol dikey raf, dar ekranda üstte yatay şerit.
class _LedgerShell extends StatefulWidget {
  final LedgerSection initial;
  final Map<LedgerSection, int> badges;
  final Set<LedgerSection> hidden;

  /// Köy durum şeridi (moral/nüfus/yiyecek/altın) — bölümden bağımsız, hep üstte.
  final Widget strip;
  final Widget railFooter;
  final Widget Function(LedgerSection) bodyFor;

  const _LedgerShell({
    required this.initial,
    required this.badges,
    required this.hidden,
    required this.strip,
    required this.railFooter,
    required this.bodyFor,
  });

  @override
  State<_LedgerShell> createState() => _LedgerShellState();
}

class _LedgerShellState extends State<_LedgerShell> {
  late LedgerSection _sec = widget.hidden.contains(widget.initial)
      ? LedgerSection.divan
      : widget.initial;

  List<LedgerSection> get _sections => [
    for (final s in LedgerSection.values)
      if (!widget.hidden.contains(s)) s,
  ];

  /// Sahne defteri "şu bölüm açılsın" diye yeniden açtığında (ör. HUD nüfus
  /// düğmesi) rafın seçimi de oraya kaysın — widget aynı ağaçta kalıyor olabilir.
  @override
  void didUpdateWidget(_LedgerShell old) {
    super.didUpdateWidget(old);
    if (old.initial != widget.initial &&
        !widget.hidden.contains(widget.initial)) {
      _sec = widget.initial;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        // YÜKSEKLİK de şart. Eskiden yalnız genişliğe bakılıyordu: telefon
        // YATAY modda 734dp geniş → "wide" sayılıp 186px'lik dikey rafa
        // düşüyordu, ama ekran 393dp kısa olduğu için beş bölümden ancak
        // dördü sığıyor, sonuncusu kesiliyordu. Kısa ekranda zaten hazır olan
        // yatay raf (_rowRail) doğru cevap.
        // 800×600 oyun penceresinde eski eşik 4dp yüzünden yatay düğme
        // duvarına düşüyordu. Cilt 420dp gövde bulduğunda indeks + nabız rahat
        // sığıyor; genişliği olan masaüstü artık gerçek masaüstü düzenini alır.
        final wide = c.maxWidth >= 660 && c.maxHeight >= 420;
        // Telefonda NÜFUS bölümü kendi KPI şeridini (nüfus/hane/moral/varlık)
        // zaten taşıyor. Köy şeridini de üstüne koyunca 393dp'lik ekranda
        // ART ARDA DÖRT yatay bant oluyordu (raf · köy şeridi · KPI şeridi ·
        // sırala) ve listeye yer kalmıyordu — 16px'lik taşma buradan geliyordu.
        // Kısa ekranda tekrar eden bandı düşür.
        // Telefonda köy şeridi HİÇ çizilmez. Gösterdiği dört sayı
        // (moral/nüfus/yiyecek/altın) üstteki HUD durum kapsülünde zaten
        // sürekli duruyor — defterde tekrarı 55dp'lik bir bant karşılığında
        // hiçbir yeni şey söylemiyor, üstelik NÜFUS bölümünün kendi KPI şeridi
        // aynı sayıları bir kez daha yazıyordu. 393dp'lik ekranda listeye yer
        // kalmamasının en büyük tek sebebi buydu.
        final showStrip = !useCompactGameUi(context) && !wide;
        final body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showStrip) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                child: widget.strip,
              ),
              Container(height: 1, color: AppUi.line),
            ],
            if (wide) _pageHeader(_sec),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 190),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                // Varsayılan layout Stack'i ORTALAR: kısa bir bölüm (ör. Kronik)
                // gövdenin ortasında asılı kalır, üstünde kocaman boşluk olur.
                // expand + topCenter → her bölüm alanı doldurur, içerik üstten
                // başlar (Nüfus'un Expanded+ListView'i de sınırlı yükseklik ister).
                layoutBuilder: (current, previous) => Stack(
                  fit: StackFit.expand,
                  alignment: Alignment.topCenter,
                  children: [...previous, ?current],
                ),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.04, 0),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(
                  key: ValueKey(_sec),
                  child: widget.bodyFor(_sec),
                ),
              ),
            ),
          ],
        );
        if (!wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _rowRail(),
              Container(height: 1, color: AppUi.line),
              Expanded(child: body),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sıra no + arma + uzun bölüm adı + rozet aynı satırda. 186dp'de
            // KANUNNAME kırpılıyordu; indeks okunurluğu için cilt biraz açıldı.
            SizedBox(width: 204, child: _rail()),
            Container(width: 1, color: AppUi.line),
            Expanded(
              child: _LedgerPageField(
                tone: ledgerSectionTone(_sec),
                child: body,
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Geniş: sol dikey raf ────────────────────────────────────────────────────

  Widget _rail() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF111419), AppUi.surface0],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'İÇİNDEKİLER',
                    style: AppUi.label.copyWith(
                      fontSize: 8,
                      color: AppUi.gold.withValues(alpha: 0.72),
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final s in _sections) ...[
                    // Kuruluşun berat adımı bu rafı gösterir (bkz. scene_guide).
                    if (s == LedgerSection.kanun)
                      GuideTarget(
                        id: GuideAnchors.sectionKanun,
                        child: _railItem(s),
                      )
                    else
                      _railItem(s),
                    const SizedBox(height: 5),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          widget.railFooter,
        ],
      ),
    );
  }

  Widget _railItem(LedgerSection s) {
    final on = _sec == s;
    final badge = widget.badges[s] ?? 0;
    final tone = ledgerSectionTone(s);
    final number = (_sections.indexOf(s) + 1).toString().padLeft(2, '0');
    return GestureDetector(
      onTap: () => setState(() => _sec = s),
      behavior: HitTestBehavior.opaque,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.fromLTRB(11, 9, 9, 9),
          decoration: BoxDecoration(
            color: on
                ? Color.alphaBlend(tone.withValues(alpha: 0.11), AppUi.surface1)
                : AppUi.surface0.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(AppUi.radiusSm),
            // UNIFORM kenar ŞART (non-uniform + borderRadius = paint assert →
            // hiç çizilmez). Seçili işareti bu yüzden ayrı bir katman değil,
            // eşit kenar + ikon rengiyle verilir.
            border: Border.all(
              color: on
                  ? tone.withValues(alpha: 0.62)
                  : AppUi.line.withValues(alpha: 0.46),
              width: on ? 1.3 : 1,
            ),
          ),
          child: Row(
            children: [
              Text(
                number,
                style: AppUi.number.copyWith(
                  fontSize: 8,
                  color: on ? tone : AppUi.textLo.withValues(alpha: 0.48),
                ),
              ),
              const SizedBox(width: 7),
              Opacity(
                opacity: on ? 1 : 0.72,
                child: SemanticIcon(
                  s.icon,
                  size: 15,
                  color: on ? tone : AppUi.textMid,
                  fallback: GameIconData.scroll,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      s.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppUi.label.copyWith(
                        fontSize: 10,
                        letterSpacing: 1.2,
                        color: on ? AppUi.textHi : AppUi.textMid,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      s.blurb,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppUi.body.copyWith(
                        fontSize: 9,
                        color: AppUi.textLo,
                      ),
                    ),
                  ],
                ),
              ),
              if (badge > 0) _badge(badge, on, tone),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(int n, bool on, Color tone) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: on ? 0.9 : 0.62),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$n',
        style: AppUi.number.copyWith(fontSize: 9, color: AppUi.ink),
      ),
    );
  }

  /// Ana sayfanın bölüm künyesi. Yatay sekmelerin kaybolduğu geniş düzende
  /// oyuncunun bulunduğu yer başlık, sıra numarası ve bölüm rengiyle görünür.
  Widget _pageHeader(LedgerSection section) {
    final tone = ledgerSectionTone(section);
    final badge = widget.badges[section] ?? 0;
    final number = (_sections.indexOf(section) + 1).toString().padLeft(2, '0');
    return Container(
      height: 56,
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [tone.withValues(alpha: 0.075), Colors.transparent],
        ),
        border: Border(bottom: BorderSide(color: tone.withValues(alpha: 0.22))),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.10),
              shape: BoxShape.circle,
              border: Border.all(color: tone.withValues(alpha: 0.46)),
            ),
            child: SemanticIcon(
              section.icon,
              size: 16,
              color: tone,
              fallback: GameIconData.scroll,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$number  ${section.label}',
                  style: AppUi.title.copyWith(
                    fontSize: 13.5,
                    color: AppUi.textHi,
                  ),
                ),
                Text(
                  section.blurb,
                  style: AppUi.body.copyWith(fontSize: 10, color: AppUi.textLo),
                ),
              ],
            ),
          ),
          if (badge > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: tone.withValues(alpha: 0.40)),
              ),
              child: Text(
                '$badge KAYIT',
                style: AppUi.label.copyWith(fontSize: 8, color: tone),
              ),
            ),
        ],
      ),
    );
  }

  // ── Dar: üstte yatay şerit ──────────────────────────────────────────────────

  Widget _rowRail() {
    return Container(
      color: AppUi.surface0.withValues(alpha: 0.55),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            for (final s in _sections) ...[
              _rowRailItem(s),
              const SizedBox(width: 6),
            ],
          ],
        ),
      ),
    );
  }

  Widget _rowRailItem(LedgerSection s) {
    final on = _sec == s;
    final badge = widget.badges[s] ?? 0;
    return GestureDetector(
      onTap: () => setState(() => _sec = s),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        // Yatay raf mobilde ANA gezinme — 37dp'de kalıyordu, 44 eşiğine çek.
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: on
              ? Color.alphaBlend(
                  AppUi.accent.withValues(alpha: 0.16),
                  AppUi.surface1,
                )
              : AppUi.surface0,
          borderRadius: BorderRadius.circular(AppUi.radiusSm),
          border: Border.all(
            color: on ? AppUi.accent.withValues(alpha: 0.55) : AppUi.line,
            width: on ? 1.3 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SemanticIcon(
              s.icon,
              size: 13,
              color: on ? AppUi.accentSoft : AppUi.textLo,
              fallback: GameIconData.scroll,
            ),
            const SizedBox(width: 7),
            Text(
              s.label,
              style: AppUi.label.copyWith(
                fontSize: 9.5,
                letterSpacing: 1.1,
                color: on ? AppUi.textHi : AppUi.textLo,
              ),
            ),
            if (badge > 0) _badge(badge, on, ledgerSectionTone(s)),
          ],
        ),
      ),
    );
  }
}
