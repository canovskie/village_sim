part of 'village_ledger.dart';

/// DEFTER SEKMELERİ — meclis, karne, karar, tüzük ve kronik sayfalarının gövdeleri.
extension _VillageLedgerTabs on VillageLedger {

  // ── Bölüm içerikleri ───────────────────────────────────────────────────────

  /// GÜNDEM sekmesi — köyün senden ne istediği + zümre gerilimleri.
  Widget _meclisTab() {
    return Builder(
      builder: (context) {
        // Meclis masası — hanelerin gerçek reisleri, yuvarlak masada karşıda.
        final council = <Widget>[
          if (seats.isNotEmpty) ...[
            const AppSectionLabel('MECLİS HALKASI'),
            const SizedBox(height: 6),
            CouncilTable(
              seats: seats,
              actionsFor: houseActionsFor,
              initiallySelected: openHouseCard,
            ),
            if (massSeizure != null) ...[
              const SizedBox(height: 10),
              _MassSeizureCard(entry: massSeizure!),
            ],
            const SizedBox(height: 16),
          ],
        ];
        final agenda = <Widget>[
          const AppSectionLabel('GÜNDEM'),
          _agendaSection(),
          const SizedBox(height: 16),
          const AppSectionLabel('GERİLİMLER'),
          _tensions(),
          if (identityBonus != null) ...[
            const SizedBox(height: 8),
            _identityBonusRow(),
          ],
          if (karne.isNotEmpty) ...[const SizedBox(height: 16), _karneBlock()],
        ];
        // TELEFON YATAY: defterin gövdesine ~300dp kalıyor; masa + künye ilk
        // ekranı doldurunca Divan açıldığında YANIT BEKLEYEN İŞ görünmüyordu.
        // Divan'ın işi gündemdir, halka atmosferdir — kısa ekranda sıra değişir.
        final compact = useCompactGameUi(context);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: compact
              ? [...agenda, const SizedBox(height: 16), ...council]
              : [...council, ...agenda],
        );
      },
    );
  }

  Widget _karneBlock() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AppSectionLabel('İMPARATORLUĞUN GÖZÜ — $karneYear. YIL'),
      const SizedBox(height: 7),
      for (final row in karne) ...[
        Text(row.label, style: AppUi.label.copyWith(color: AppUi.textMid)),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: row.value.clamp(0.0, 1.0),
            minHeight: 5,
            backgroundColor: AppUi.surface2,
            valueColor: const AlwaysStoppedAnimation(AppUi.gold),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          row.note,
          style: AppUi.body.copyWith(fontSize: 10.5, color: AppUi.textLo),
        ),
        const SizedBox(height: 7),
      ],
      if (karneVerdict.isNotEmpty)
        Text(
          'Defter bugün kapansaydı: $karneVerdict',
          style: AppUi.bodyHi.copyWith(fontSize: 11, color: AppUi.gold),
        ),
      if (karneAdviceLine.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            karneAdviceLine,
            style: AppUi.body.copyWith(fontSize: 10.5, color: AppUi.textMid),
          ),
        ),
    ],
  );

  /// KANUNNAME sekmesi — yasa defteri + kararların köyde bıraktığı kalıcı iz.
  Widget _kararTab() {
    final hasState = marks.isNotEmpty || legacy.abs() > 0.005;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LawBookView(
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
        ),
        if (hasState) ...[
          const SizedBox(height: 16),
          const AppSectionLabel('KÖYÜN HÂLİ'),
          if (legacy.abs() > 0.005) ...[
            _legacyLine(),
            if (marks.isNotEmpty) const SizedBox(height: 8),
          ],
          if (marks.isNotEmpty) _factWrap(),
        ],
        if (crafts.isNotEmpty) ...[
          const SizedBox(height: 16),
          const AppSectionLabel('KÖYÜN ELİ — BİLİNEN ZANAATLAR'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final f in crafts) _factChip(f)],
          ),
        ],
      ],
    );
  }

  // ── TÜZÜK sekmesi — kimlik kademesi merdiveni + görevler ───────────────────

  /// Görev panosu eskiden sol kenarda küçük bir kutuydu ve yalnız AÇIK görevleri
  /// gösteriyordu: köyün nereye gittiği (kademe merdiveni) ve nereden geldiği
  /// (biten görevler) görünmüyordu. Defterde ikisi de var.
  Widget _tuzukTab() {
    final active = quests.where((q) => q.active).firstOrNull;
    final done = QuestBook.all
        .where((q) => completedQuests.contains(q.id))
        .toList(growable: false);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppSectionLabel('KÖYÜN KADEMESİ'),
        const SizedBox(height: 8),
        for (int i = 0; i < QuestBook.tiers.length; i++) ...[
          _tierRow(i, QuestBook.tiers[i], done.length),
          if (i != QuestBook.tiers.length - 1) const SizedBox(height: 6),
        ],
        const SizedBox(height: 18),
        const AppSectionLabel('AÇIK GÖREVLER'),
        const SizedBox(height: 8),
        if (quests.isEmpty)
          Text(
            'Bu kademede iş kalmadı — yeni bir berat çıkar, köy bir üst '
            'basamağa geçsin.',
            style: AppUi.body.copyWith(fontSize: 11.5, color: AppUi.sage),
          )
        else
          for (final q in quests) _questRow(q),
        if (active != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
            decoration: BoxDecoration(
              color: AppUi.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppUi.radiusSm),
              border: Border.all(color: AppUi.accent.withValues(alpha: 0.38)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const GameIcon(
                  GameIconData.chevron,
                  size: 12,
                  color: AppUi.accentSoft,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    active.quest.hint,
                    style: AppUi.body.copyWith(
                      fontSize: 11.5,
                      color: AppUi.textHi,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (done.isNotEmpty) ...[
          const SizedBox(height: 18),
          AppSectionLabel('BİTENLER — ${done.length}/${QuestBook.all.length}'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final q in done)
                _factChip(DivanFact(q.icon, q.label, AppUi.sage)),
            ],
          ),
        ],
      ],
    );
  }

  Widget _tierRow(int i, CharterTier t, int doneCount) {
    final passed = i < charterTier;
    final current = i == charterTier;
    final c = current
        ? AppUi.gold
        : passed
        ? AppUi.sage
        : AppUi.textLo;
    // Kilitli kademede eşiğe ne kadar kaldığı yazılır — ilerleme somut olsun.
    final needPol = (t.minPolicies - enactedPolicies).clamp(0, 99);
    final needQ = (t.minQuests - doneCount).clamp(0, 99);
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
      decoration: BoxDecoration(
        color: current
            ? Color.alphaBlend(
                AppUi.gold.withValues(alpha: 0.10),
                AppUi.surface1,
              )
            : AppUi.surface0,
        borderRadius: BorderRadius.circular(AppUi.radiusSm),
        border: Border.all(
          color: current ? AppUi.gold.withValues(alpha: 0.5) : AppUi.line,
          width: current ? 1.3 : 1,
        ),
      ),
      child: Row(
        children: [
          Opacity(
            opacity: passed || current ? 1 : 0.45,
            child: SemanticIcon(
              t.icon,
              size: 15,
              color: AppUi.gold,
              fallback: GameIconData.crown,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppUi.body.copyWith(
                    fontSize: 12.5,
                    color: current ? AppUi.textHi : AppUi.textMid,
                    fontWeight: current ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
                if (!passed && !current && (needPol > 0 || needQ > 0)) ...[
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (needPol > 0) '$needPol berat',
                      if (needQ > 0) '$needQ görev',
                    ].join(' · '),
                    style: AppUi.body.copyWith(
                      fontSize: 10,
                      color: AppUi.textLo,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            passed
                ? '✓'
                : current
                ? 'ŞİMDİ'
                : 'kilitli',
            style: AppUi.label.copyWith(fontSize: 8.5, color: c),
          ),
        ],
      ),
    );
  }

  Widget _questRow(QuestState s) {
    final on = s.active;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            child: GameIcon(
              questGlyph(s.quest.id),
              size: 12,
              color: on ? AppUi.accent : AppUi.textLo,
            ),
          ),
          Expanded(
            child: Text(
              s.quest.label,
              style: on
                  ? AppUi.bodyHi.copyWith(fontSize: 12)
                  : AppUi.body.copyWith(fontSize: 12, color: AppUi.textLo),
            ),
          ),
          if (on)
            Text(
              'SIRADAKİ',
              style: AppUi.label.copyWith(
                fontSize: 7.5,
                color: AppUi.accentSoft,
              ),
            ),
        ],
      ),
    );
  }

  // ── KRONİK sekmesi — köyün büyük anları ────────────────────────────────────

  Widget _kronikTab() {
    if (chronicle.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(
          Voice.pick(const [
            'Defterin bu sayfası boş. Köy henüz anlatılacak bir şey yaşamadı.',
            'Henüz yazılacak bir şey yok — ilk büyük gün gelmedi.',
            'Kronik sayfası temiz. Bu da bir başlangıç.',
          ], seed),
          style: AppUi.body.copyWith(color: AppUi.textLo),
        ),
      );
    }
    // Süzgeç (bkz. ui/ledger/chronicle_filter.dart): "ne karar vermiştim?" sorusunun
    // cevabı listede vardı ama bulunamıyordu.
    return ChronicleFilter(
      entries: chronicle,
      builder: (_, filtered, chips) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSectionLabel(
            milestoneCount > 0
                ? 'BÜYÜK ANLAR — 🏆 $milestoneCount BAŞARIM'
                : 'BÜYÜK ANLAR',
          ),
          const SizedBox(height: 6),
          chips,
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'Bu türde kayıt yok.',
                style: AppUi.body.copyWith(color: AppUi.textLo),
              ),
            ),
          for (final e in filtered) _chronicleRow(e),
        ],
      ),
    );
  }

  Widget _chronicleRow(ChronicleEntry e) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: SemanticIcon(
              e.icon,
              size: 15,
              color: AppUi.textLo,
              fallback: GameIconData.scroll,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (e.day > 0)
                  Text(
                    '${e.day}. Gün',
                    style: AppUi.label.copyWith(
                      color: AppUi.textLo,
                      fontSize: 10,
                    ),
                  ),
                Text(
                  e.text,
                  style: e.milestone
                      ? AppUi.body.copyWith(
                          fontSize: 12.5,
                          height: 1.4,
                          fontWeight: FontWeight.w700,
                          color: AppUi.gold,
                        )
                      : AppUi.body.copyWith(fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
