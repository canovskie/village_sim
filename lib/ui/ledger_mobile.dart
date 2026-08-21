part of 'village_ledger.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// MOBİL DEFTER — sütun tahtası
/// ═══════════════════════════════════════════════════════════════════════════
///
/// Defterin telefon yatay yerleşimi. Gerekçe ve ızgara kuralları
/// `ui/ledger_board.dart` başında; burası o kuralların Köy Defteri'ne
/// uygulanışıdır. Masaüstü gövdeleri ([VillageLedger._meclisTab] vb.) HİÇ
/// değişmez — telefon ayrı gövdeler kullanır çünkü sorun boyut değil DİZİLİM:
/// aynı içeriği küçültmek 760×360'ta işe yaramıyor, yeniden dizmek gerekiyor.
///
/// Bütçe (iPhone 11, pencere 760×360):
///   ray 136 · gövde 621 → kenar boşluğuyla 597×334 çizilebilir alan.
/// Her bölüm bu alanı SÜTUNLARA böler ve hiçbir sütun dikey kaydırmaz.

// ─── Kabuk: ray + tahta ──────────────────────────────────────────────────────

class _LedgerBoardShell extends StatefulWidget {
  final LedgerSection initial;
  final Map<LedgerSection, int> badges;
  final Set<LedgerSection> hidden;

  /// Rayın tepesindeki kimlik satırı (köyün adı).
  final Widget identityHeader;

  final Widget Function(LedgerSection) boardFor;
  final VoidCallback onClose;

  const _LedgerBoardShell({
    required this.initial,
    required this.badges,
    required this.hidden,
    required this.identityHeader,
    required this.boardFor,
    required this.onClose,
  });

  @override
  State<_LedgerBoardShell> createState() => _LedgerBoardShellState();
}

class _LedgerBoardShellState extends State<_LedgerBoardShell> {
  late LedgerSection _sec = widget.hidden.contains(widget.initial)
      ? LedgerSection.divan
      : widget.initial;

  List<LedgerSection> get _sections => [
    for (final s in LedgerSection.values)
      if (!widget.hidden.contains(s)) s,
  ];

  Color _tone(LedgerSection section) => switch (section) {
    LedgerSection.divan => AppUi.accent,
    LedgerSection.kanun => AppUi.gold,
    LedgerSection.nufus => AppUi.sage,
    LedgerSection.tuzuk => AppUi.rust,
    LedgerSection.kronik => const Color(0xFFB079D4),
  };

  @override
  void didUpdateWidget(_LedgerBoardShell old) {
    super.didUpdateWidget(old);
    if (old.initial != widget.initial &&
        !widget.hidden.contains(widget.initial)) {
      _sec = widget.initial;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BoardRail(
          header: widget.identityHeader,
          onClose: widget.onClose,
          items: [
            for (final s in _sections)
              BoardRailItem(
                icon: s.icon,
                label: s.short,
                color: _tone(s),
                badge: widget.badges[s] ?? 0,
                selected: _sec == s,
                guideId: s == LedgerSection.kanun
                    ? GuideAnchors.sectionKanun
                    : null,
                onTap: () => setState(() => _sec = s),
              ),
          ],
        ),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _tone(_sec).withValues(alpha: 0.075),
                  Colors.transparent,
                  Colors.transparent,
                ],
              ),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 170),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              layoutBuilder: (current, previous) => Stack(
                fit: StackFit.expand,
                children: [...previous, ?current],
              ),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.03, 0),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: KeyedSubtree(
                key: ValueKey(_sec),
                child: Padding(
                  padding: const EdgeInsets.all(LedgerBoard.pad),
                  child: widget.boardFor(_sec),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Bölüm tahtaları ─────────────────────────────────────────────────────────

/// Telefona özel gövdeler. Ayrı bir `extension` çünkü bunlar defterin
/// MASAÜSTÜ gövdelerinin yanına eklenen ikinci bir dizilim; aynı veriyi okur,
/// aynı yardımcıları çağırır, ama kendi ızgarasını kurar.
extension LedgerMobileBoards on VillageLedger {
  Widget mobileBoardFor(LedgerSection s) => switch (s) {
    LedgerSection.divan => _divanBoard(),
    LedgerSection.kanun => _kanunBoard(),
    LedgerSection.nufus => VillagerRosterView(
      rows: rosterRows,
      houses: houses,
      onSelect: onSelectVillager,
    ),
    LedgerSection.tuzuk => _tuzukBoard(),
    LedgerSection.kronik => _kronikBoard(),
  };

  /// Rayın tepesindeki kimlik satırı — künye + köyün adı.
  ///
  /// [FittedBox] şart: ray dar ekranda kimlik satırını 38dp'den 30/26dp'ye
  /// indiriyor (bkz. [BoardRail]) ve telefonda 11px yazı TABANI var — iki
  /// satır 8+12.5 istense bile 11+12.5 çiziliyor, 640×360'ta 6dp taşıyordu.
  /// Ölçekle küçültmek kırpmaktan iyi: köyün adı okunur kalır.
  Widget mobileIdentity() {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _ledgerKicker,
            style: AppUi.label.copyWith(fontSize: 8, color: AppUi.accentSoft),
          ),
          const SizedBox(height: 2),
          SizedBox(
            width: LedgerBoard.railW - 12,
            child: Text(
              identity,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppUi.title.copyWith(fontSize: 12.5, color: AppUi.gold),
            ),
          ),
        ],
      ),
    );
  }

  // ── DİVAN ─────────────────────────────────────────────────────────────────
  //
  // İki sütun. Solda GÜNDEM (defterin işi: yanıt bekleyen meseleler), sağda
  // köyün hâli (gerilimler) ve meclis halkası. Masaüstünde bunlar alt alta
  // 900dp'lik bir sütuna akıyor; telefonda gündem ile masa yan yana durur ve
  // ikisi de ilk karede TAM görünür.

  Widget _divanBoard() {
    final pendingCount = agenda.where((m) => m.pending).length;
    return BoardRow(
      children: [
        BoardCol(
          flex: 55,
          head: 'GÜNDEM',
          headTrailing: pendingCount > 0
              ? BoardCount('$pendingCount bekliyor', color: AppUi.accentSoft)
              : null,
          child: BoardPager(
            count: agenda.length,
            rowH: 54,
            rowGap: 6,
            emptyText: Voice.pick(const [
              'Kapıya kimse gelmedi. Köy bugün kendi işine bakıyor.',
              'Ne şikâyet var ne dilekçe. Bu da bir hâl.',
              'Dilekçe kâğıdı masada, dokunulmadan duruyor.',
            ], seed),
            itemBuilder: (_, i) => _MiniMatter(
              matter: agenda[i],
              onTap: agenda[i].pending ? onOpenPetition : null,
            ),
          ),
        ),
        BoardCol(
          flex: 45,
          head: 'GERİLİMLER',
          child: LayoutBuilder(
            builder: (context, c) {
              // Bu sütunda üç şey yarışıyor: gerilim satırları · toplu el koyma
              // kartı · meclis masası. Sabit sayı vermek (ilk hâl: "en fazla 4
              // hane") 640×360'lık ekranda 6dp taşırdı. Satır sayısı artık
              // kalan yerden türer: masaya ve karta payı ayrılır, gerilimler
              // NE KADAR SIĞIYORSA o kadar yazılır.
              const rowH = 24.0;
              const minCouncil = 92.0;
              // Kart tahtada SABİT boylu (bkz. [_MassSeizureCard.compact]);
              // rezerv tahmin değil, kartın gerçek boyu.
              final seizureH = massSeizure != null
                  ? _MassSeizureCard.boardHeight + 8
                  : 0.0;
              final reserved =
                  seizureH + (seats.isNotEmpty ? minCouncil + 8 : 0.0);
              final rows = houses.isEmpty
                  ? 0
                  : ((c.maxHeight - reserved - 8) / rowH).floor().clamp(
                      0,
                      houses.length < 4 ? houses.length : 4,
                    );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (houses.isEmpty)
                    Text(
                      'Köy genç: ne hane var, ne husumet.',
                      style: AppUi.body.copyWith(
                        fontSize: 11,
                        color: AppUi.textLo,
                      ),
                    )
                  else
                    for (final h in houses.take(rows)) _MiniTension(house: h),
                  const SizedBox(height: 8),
                  if (massSeizure != null) ...[
                    _MassSeizureCard(entry: massSeizure!, compact: true),
                    const SizedBox(height: 8),
                  ],
                  if (seats.isNotEmpty)
                    Expanded(
                      child: CouncilTable(
                        seats: seats,
                        actionsFor: houseActionsFor,
                        initiallySelected: openHouseCard,
                        fill: true,
                      ),
                    )
                  else
                    const Spacer(),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  // ── KANUNNAME ─────────────────────────────────────────────────────────────
  //
  // Kanun defteri kendi iç yerleşimini biliyor (pusula · arama · petek);
  // telefonda o üçünü alt alta değil YAN YANA ister. Bayrağı geçir, gerisini
  // LawBookView'in tahta dizilimi yapar.

  Widget _kanunBoard() {
    return LawBookView(
      sealed: sealed,
      sealedOn: sealedOn,
      ctx: lawContext,
      spotlightId: lawSpotlightId,
      inkDrySec: inkDrySec,
      inkDryTotalSec: inkDryTotalSec,
      seed: seed,
      onOpenLaw: onOpenLaw!,
      rule: regimeRule,
      unrest: unrest,
      sworn: swornRegime,
      onSwearOath: onSwearOath,
      onRepeal: onRepealLaw,
      rot: regimeRot,
      faith: faithEffect,
      board: true,
    );
  }

  // ── TÜZÜK ─────────────────────────────────────────────────────────────────
  //
  // Solda köyün nereye gittiği (kademe merdiveni), sağda şu an ne yapması
  // gerektiği (açık görevler + ipucu). Merdiven altı basamak — telefonda tek
  // sütunda dördü fold altında kalıyordu, iki sütunda hepsi görünür.

  Widget _tuzukBoard() {
    final active = quests.where((q) => q.active).firstOrNull;
    final done = QuestBook.all
        .where((q) => completedQuests.contains(q.id))
        .toList(growable: false);
    return BoardRow(
      children: [
        BoardCol(
          flex: 48,
          head: 'KÖYÜN KADEMESİ',
          headTrailing: BoardCount(
            '${charterTier + 1}/${QuestBook.tiers.length}',
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < QuestBook.tiers.length; i++) ...[
                if (i > 0) const SizedBox(height: 5),
                Expanded(
                  child: _MiniTier(
                    index: i,
                    tier: QuestBook.tiers[i],
                    doneCount: done.length,
                    ledger: this,
                  ),
                ),
              ],
            ],
          ),
        ),
        BoardCol(
          flex: 52,
          head: 'AÇIK GÖREVLER',
          headTrailing: BoardCount(
            '${done.length}/${QuestBook.all.length} bitti',
            color: AppUi.sage,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: BoardPager(
                  count: quests.length,
                  rowH: 30,
                  rowGap: 5,
                  emptyText:
                      'Bu kademede iş kalmadı — yeni bir berat çıkar, köy bir '
                      'üst basamağa geçsin.',
                  itemBuilder: (_, i) => _MiniQuest(state: quests[i]),
                ),
              ),
              if (active != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.fromLTRB(9, 7, 9, 7),
                  decoration: BoxDecoration(
                    color: AppUi.accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppUi.radiusSm),
                    border: Border.all(
                      color: AppUi.accent.withValues(alpha: 0.38),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const GameIcon(
                        GameIconData.chevron,
                        size: 11,
                        color: AppUi.accentSoft,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          active.quest.hint,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppUi.body.copyWith(
                            fontSize: 11,
                            color: AppUi.textHi,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── KRONİK ────────────────────────────────────────────────────────────────
  //
  // Güncenin doğal biçimi uzun bir liste; telefonda uzun liste = kaydırma.
  // İki sütunlu SAYFA hâline getirildi: bir karede 14 giriş, sonrası sayfa
  // çevirerek. "Gün" etiketi kendi satırını yemez, metinle aynı satırda durur.

  Widget _kronikBoard() {
    // BoardCol bir Expanded'dır — tek sütun bile olsa BoardRow (yani bir Flex)
    // içinde durmalı; yoksa ParentDataWidget hatası atar.
    //
    // Süzgeç şeridi sayfanın DIŞINDA, başlığın altında durur: sayfalayıcının
    // içine girse her sayfa çevrildiğinde yeniden çizilir ve dikey bütçeden
    // sürekli bir satır yerdi.
    return ChronicleFilter(
      entries: chronicle,
      compact: true,
      builder: (_, entries, chips) => BoardRow(
        children: [
          BoardCol(
            head: milestoneCount > 0
                ? 'BÜYÜK ANLAR — 🏆 $milestoneCount BAŞARIM'
                : 'BÜYÜK ANLAR',
            headTrailing: BoardCount('${entries.length} kayıt'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                chips,
                Expanded(
                  child: BoardPager(
                    count: entries.length,
                    columns: 2,
                    rowH: 42,
                    rowGap: 6,
                    emptyText: Voice.pick(const [
                      'Defterin bu sayfası boş. Köy henüz anlatılacak bir şey yaşamadı.',
                      'Henüz yazılacak bir şey yok — ilk büyük gün gelmedi.',
                      'Kronik sayfası temiz. Bu da bir başlangıç.',
                    ], seed),
                    itemBuilder: (_, i) => _MiniChronicle(entry: entries[i]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tahta satırları ─────────────────────────────────────────────────────────

/// GÜNDEM maddesi — 54dp. Masaüstü kartı 78dp; buradaki fark başlık ile künye
/// satırının arasındaki nefes ve iki satırlık alt metnin tek satıra inmesi.
/// Sıkıştırma bilgiyi düşürmez: mesele başlığı zaten cümleyi taşıyor, alt
/// metin bağlamı; ikisi de tek satırda okunur.
class _MiniMatter extends StatelessWidget {
  final DivanMatter matter;
  final VoidCallback? onTap;
  const _MiniMatter({required this.matter, this.onTap});

  @override
  Widget build(BuildContext context) {
    final m = matter;
    final c = VillageLedger.toneColor(m.tone);
    final pending = m.pending;
    return BoardTile(
      onTap: onTap,
      edge: c.withValues(alpha: pending ? 0.95 : 0.5),
      tint: pending ? c : null,
      highlight: pending,
      padding: const EdgeInsets.fromLTRB(9, 6, 9, 6),
      child: Row(
        children: [
          SemanticIcon(
            m.icon,
            size: 14,
            color: c,
            fallback: GameIconData.scroll,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        m.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppUi.bodyHi.copyWith(
                          fontSize: 12,
                          color: pending ? AppUi.textHi : AppUi.textMid,
                        ),
                      ),
                    ),
                    if (pending) ...[
                      const SizedBox(width: 6),
                      _MiniPendingTag(urgent: m.urgent),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  m.sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppUi.body.copyWith(
                    fontSize: 10.5,
                    color: AppUi.textLo,
                  ),
                ),
                const SizedBox(height: 4),
                BoardBar(
                  pending ? (1.0 - m.graceProgress) : m.pressure,
                  pending && m.urgent ? AppUi.rust : c,
                  height: 3,
                ),
              ],
            ),
          ),
          if (pending) ...[
            const SizedBox(width: 6),
            GameIcon(GameIconData.chevron, size: 12, color: c),
          ],
        ],
      ),
    );
  }
}

class _MiniPendingTag extends StatelessWidget {
  final bool urgent;
  const _MiniPendingTag({required this.urgent});

  @override
  Widget build(BuildContext context) {
    final c = urgent ? AppUi.rust : AppUi.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.7)),
      ),
      child: Text(
        urgent ? 'AZ KALDI' : 'YANIT BEKLER',
        style: AppUi.label.copyWith(
          fontSize: 7,
          letterSpacing: 0.6,
          color: urgent ? AppUi.rust : AppUi.accentSoft,
        ),
      ),
    );
  }
}

/// Hane gerilimi — 24dp'lik tek satır: renk noktası · ad · çubuk · yüzde.
/// Masaüstündeki 44dp'lik satırın bilgisi aynı; kaybolan tek şey satır arası
/// boşluk ve ayrı bir yüz ifadesi emojisi (yüzde zaten aynı şeyi söylüyor).
class _MiniTension extends StatelessWidget {
  final HouseSnapshot house;
  const _MiniTension({required this.house});

  @override
  Widget build(BuildContext context) {
    final c = VillageLedger.moodTone(house.mood);
    return SizedBox(
      height: 24,
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: _councilHouseColor(house.surname),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          SizedBox(
            width: 78,
            child: Text(
              house.surname,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppUi.body.copyWith(
                fontSize: 11,
                color: house.ascendant ? AppUi.gold : AppUi.textMid,
                fontWeight: house.ascendant ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          if (house.stance.audible) ...[
            const SizedBox(width: 4),
            Text(house.stance.icon, style: const TextStyle(fontSize: 9)),
          ],
          const SizedBox(width: 6),
          Expanded(child: BoardBar(house.mood, c)),
          const SizedBox(width: 6),
          SizedBox(
            width: 30,
            child: Text(
              '%${(house.mood * 100).round()}',
              textAlign: TextAlign.right,
              style: AppUi.number.copyWith(fontSize: 10, color: c),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kademe basamağı — sütunun boyuna göre esner (altı basamak alanı böler).
class _MiniTier extends StatelessWidget {
  final int index;
  final CharterTier tier;
  final int doneCount;
  final VillageLedger ledger;
  const _MiniTier({
    required this.index,
    required this.tier,
    required this.doneCount,
    required this.ledger,
  });

  @override
  Widget build(BuildContext context) {
    final passed = index < ledger.charterTier;
    final current = index == ledger.charterTier;
    final needPol = (tier.minPolicies - ledger.enactedPolicies).clamp(0, 99);
    final needQ = (tier.minQuests - doneCount).clamp(0, 99);
    final c = current
        ? AppUi.gold
        : passed
        ? AppUi.sage
        : AppUi.textLo;
    return BoardTile(
      tint: current ? AppUi.gold : null,
      highlight: current,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      child: Row(
        children: [
          Opacity(
            opacity: passed || current ? 1 : 0.45,
            child: SemanticIcon(
              tier.icon,
              size: 13,
              color: c,
              fallback: GameIconData.crown,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tier.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppUi.body.copyWith(
                    fontSize: 11.5,
                    color: current ? AppUi.textHi : AppUi.textMid,
                    fontWeight: current ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
                if (!passed && !current && (needPol > 0 || needQ > 0))
                  Text(
                    [
                      if (needPol > 0) '$needPol berat',
                      if (needQ > 0) '$needQ görev',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppUi.body.copyWith(
                      fontSize: 9.5,
                      color: AppUi.textLo,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          if (current)
            Text('ŞİMDİ', style: AppUi.label.copyWith(fontSize: 8, color: c))
          else
            GameIcon(
              passed ? GameIconData.star : GameIconData.door,
              size: 10,
              color: c,
            ),
        ],
      ),
    );
  }
}

/// Açık görev — 30dp'lik tek satır.
class _MiniQuest extends StatelessWidget {
  final QuestState state;
  const _MiniQuest({required this.state});

  @override
  Widget build(BuildContext context) {
    final on = state.active;
    return BoardTile(
      tint: on ? AppUi.accent : null,
      highlight: on,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      child: Row(
        children: [
          GameIcon(
            questGlyph(state.quest.id),
            size: 12,
            color: on ? AppUi.accent : AppUi.textLo,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              state.quest.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: on
                  ? AppUi.bodyHi.copyWith(fontSize: 11.5)
                  : AppUi.body.copyWith(fontSize: 11.5, color: AppUi.textLo),
            ),
          ),
          if (on) ...[
            const SizedBox(width: 6),
            Text(
              'SIRADAKİ',
              style: AppUi.label.copyWith(
                fontSize: 7.5,
                color: AppUi.accentSoft,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Kronik girişi — 42dp: gün künyesi metinle AYNI satırda, metin iki satıra
/// kadar. Masaüstünde gün kendi satırındaydı; telefonda o satır girişin
/// üçte birini yiyordu.
class _MiniChronicle extends StatelessWidget {
  final ChronicleEntry entry;
  const _MiniChronicle({required this.entry});

  @override
  Widget build(BuildContext context) {
    final e = entry;
    return BoardTile(
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
      edge: e.milestone ? AppUi.gold.withValues(alpha: 0.75) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: SemanticIcon(
              e.icon,
              size: 13,
              color: AppUi.textLo,
              fallback: GameIconData.scroll,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  if (e.day > 0)
                    TextSpan(
                      text: '${e.day}. gün  ',
                      style: AppUi.label.copyWith(
                        fontSize: 8.5,
                        color: AppUi.textLo,
                      ),
                    ),
                  TextSpan(text: e.text),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: e.milestone
                  ? AppUi.body.copyWith(
                      fontSize: 11,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                      color: AppUi.gold,
                    )
                  : AppUi.body.copyWith(fontSize: 11, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}
