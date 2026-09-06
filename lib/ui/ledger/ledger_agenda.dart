part of 'village_ledger.dart';

/// MECLİS GÜNDEMİ — gündem satırları, baskı çubuğu, gerilimler, hane satırları ve miras.
extension _VillageLedgerAgenda on VillageLedger {

  // ── Gündem ──────────────────────────────────────────────────────────────────

  Widget _agendaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (agenda.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                const GameIcon(
                  GameIconData.handshake,
                  size: 15,
                  color: AppUi.sage,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    Voice.pick(const [
                      'Kapıya kimse gelmedi. Köy bugün kendi işine bakıyor.',
                      'Ne şikâyet var ne dilekçe. Bu da bir hâl.',
                      'Dilekçe kâğıdı masada, dokunulmadan duruyor.',
                    ], seed),
                    style: AppUi.body.copyWith(color: AppUi.textLo),
                  ),
                ),
              ],
            ),
          )
        else
          for (int i = 0; i < agenda.length; i++) ...[
            _matterRow(agenda[i]),
            if (i != agenda.length - 1) const SizedBox(height: 7),
          ],
      ],
    );
  }

  Widget _matterRow(DivanMatter m) {
    final c = VillageLedger.toneColor(m.tone);
    final pending = m.pending;
    return GestureDetector(
      onTap: pending ? onOpenPetition : null,
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppUi.radiusSm),
        child: Stack(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 9, 11, 9),
              decoration: BoxDecoration(
                color: pending
                    ? Color.alphaBlend(
                        c.withValues(alpha: 0.10),
                        AppUi.surface1,
                      )
                    : AppUi.surface0,
                borderRadius: BorderRadius.circular(AppUi.radiusSm),
                // UNIFORM kenar ŞART: non-uniform renkli Border + borderRadius Flutter'da
                // paint assert'i atar ("borderRadius … uniform colors") → panel çizilmez.
                // Ton rengi bu yüzden ayrı bir sol şerit katmanı olarak çizilir (aşağıda).
                border: Border.all(color: AppUi.line),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SemanticIcon(
                    m.icon,
                    size: 16,
                    color: c,
                    fallback: GameIconData.scroll,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                m.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppUi.bodyHi.copyWith(
                                  fontSize: 12.5,
                                  color: pending ? AppUi.textHi : AppUi.textMid,
                                ),
                              ),
                            ),
                            if (pending) ...[
                              const SizedBox(width: 7),
                              _pendingTag(m),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          m.sub,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppUi.body.copyWith(
                            fontSize: 10.5,
                            color: AppUi.textLo,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Mayalanma fitili / mühlet — ince bar (ton renginde).
                        _pressureBar(
                          pending ? (1.0 - m.graceProgress) : m.pressure,
                          pending && m.urgent ? AppUi.rust : c,
                        ),
                      ],
                    ),
                  ),
                  if (pending) ...[
                    const SizedBox(width: 8),
                    GameIcon(GameIconData.chevron, size: 13, color: c),
                  ],
                ],
              ),
            ),
            // Sol ton şeridi — meselenin duygusal rengi (uniform-border kısıtı
            // yüzünden Border yerine ayrı katman; satırın boyuna uzar).
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 3,
                color: c.withValues(alpha: pending ? 0.95 : 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pendingTag(DivanMatter m) {
    final urgent = m.urgent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: (urgent ? AppUi.rust : AppUi.accent).withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (urgent ? AppUi.rust : AppUi.accent).withValues(alpha: 0.7),
        ),
      ),
      child: Text(
        urgent ? 'AZ KALDI' : 'YANIT BEKLER',
        style: AppUi.label.copyWith(
          fontSize: 7.5,
          letterSpacing: 0.8,
          color: urgent ? AppUi.rust : AppUi.accentSoft,
        ),
      ),
    );
  }

  Widget _pressureBar(double v, Color c) {
    return Container(
      height: 4,
      decoration: BoxDecoration(
        color: const Color(0x55000000),
        borderRadius: BorderRadius.circular(3),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: v.clamp(0.04, 1.0),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    c.withValues(alpha: 0.7),
                    Color.lerp(c, Colors.white, 0.25)!,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Gerilimler (zümre nabzı) ────────────────────────────────────────────────

  Widget _tensions() {
    if (houses.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          Voice.pick(const [
            'Ortada hane yok, isimler var. Soylar daha kök salmadı.',
            'Kimse kendi adını bir soyadın arkasına yazdırmadı henüz.',
            'Köy genç: ne hane var, ne husumet.',
          ], seed),
          style: AppUi.body.copyWith(fontSize: 11, color: AppUi.textLo),
        ),
      );
    }
    // Salience sıralı gelir; en fazla 4 açık göster, gerisi özet (sadelik).
    final shown = houses.length > 4 ? 4 : houses.length;
    return Column(
      children: [
        for (int i = 0; i < shown; i++) ...[
          _houseRow(houses[i]),
          if (i != shown - 1) const SizedBox(height: 6),
        ],
        if (houses.length > shown) ...[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '…ve ${houses.length - shown} hane, seslerini çıkarmadan',
              style: AppUi.body.copyWith(
                fontSize: 10,
                color: AppUi.textLo,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ],
    );
  }

  static const List<Color> _kHousePalette = [
    Color(0xFF8FB255),
    Color(0xFFE0954A),
    Color(0xFF9E86C9),
    Color(0xFFD8AE56),
    Color(0xFF6FA9B8),
    Color(0xFFC57B6B),
    Color(0xFF8DA0C0),
    Color(0xFFB0A24E),
  ];

  static Color _houseColor(String surname) {
    var h = 0;
    for (final c in surname.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return _kHousePalette[h % _kHousePalette.length];
  }

  Widget _houseRow(HouseSnapshot s) {
    final tone = VillageLedger.moodTone(s.mood);
    final idColor = _houseColor(s.surname);
    final row = Row(
      children: [
        Container(
          width: 9,
          height: 9,
          margin: const EdgeInsets.only(left: 6, right: 7),
          decoration: BoxDecoration(color: idColor, shape: BoxShape.circle),
        ),
        SizedBox(
          width: 116,
          child: Row(
            children: [
              Flexible(
                child: Text(
                  s.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppUi.body.copyWith(
                    fontSize: 11.5,
                    color: s.ascendant ? AppUi.gold : AppUi.textMid,
                    fontWeight: s.ascendant ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
              if (s.ascendant)
                const Padding(
                  padding: EdgeInsets.only(left: 3),
                  child: Text(
                    '★',
                    style: TextStyle(color: AppUi.gold, fontSize: 9),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 7,
            decoration: BoxDecoration(
              color: AppUi.surface0,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppUi.line, width: 0.8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: s.mood.clamp(0.0, 1.0)),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOut,
                  builder: (_, v, _) => FractionallySizedBox(
                    widthFactor: v,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            tone.withValues(alpha: 0.8),
                            Color.lerp(tone, Colors.white, 0.25)!,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(s.tier.face, style: const TextStyle(fontSize: 12)),
        SizedBox(
          width: 34,
          child: Text(
            '%${(s.swayShare * 100).round()}',
            textAlign: TextAlign.right,
            style: AppUi.number.copyWith(
              fontSize: 10,
              color: s.ascendant ? AppUi.gold : AppUi.textLo,
            ),
          ),
        ),
      ],
    );
    // Hane SESİNİ ÇIKARIYORSA (serzeniş ve üstü) satırın altına hâli yazılır.
    // Rakam değil CÜMLE: "hâl %31" oyuncuya hiçbir şey söylemez, "üç el işe
    // çıkmıyor" söyler. Serzeniş de görünür — o basamak oyuncunun ÜCRETSİZ
    // uyarı penceresidir; defterde susarsa rampa ilk bedelli basamaktan başlar
    // ve "kayıp her zaman haber verilir" sözü delinir.
    // Panelde okunan sayı simin okuduğu sayıdır (tek kaynak: snapshot).
    if (!s.stance.audible) return row;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [row, const SizedBox(height: 4), _stanceStrip(s)],
    );
  }

  /// Duruş şeridi — ne çekiliyor, ne saklanıyor, BİR ADIM ÖTEDE ne var.
  /// Serzeniş (bedelsiz uyarı) kehribar okunur, esirgeyen basamaklar kızıl.
  /// [nextRung] önizlemesi bedeli ÖNCEDEN gösterir: oyuncu merdivenin bir
  /// sonraki basamağını çıkmadan okuyabilmeli.
  Widget _stanceStrip(HouseSnapshot s) {
    final w = s.withholding;
    final hands = (s.members * w.labor).round();
    final next = nextRung(s.stance);
    final parts = <String>[
      if (!s.stance.withholds) 'henüz esirgemiyor',
      if (hands > 0) '$hands el işe çıkmıyor',
      if (s.stash > 0) '${s.stash} kile saklı',
      if (w.council) 'masada yok',
      if (w.betrothal) 'nikâh vermiyor',
      if (next != null) 'bir adım ötede: ${next.costHint}',
    ];
    final tint = s.stance.withholds ? AppUi.rust : AppUi.gold;
    return Padding(
      padding: const EdgeInsets.only(left: 22, right: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppUi.radiusSm),
          border: Border.all(color: tint.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            SemanticIcon(
              s.stance.icon,
              size: 11,
              color: tint,
              fallback: GameIconData.scales,
            ),
            const SizedBox(width: 6),
            Text(
              s.stance.label,
              style: AppUi.body.copyWith(
                fontSize: 10.5,
                color: AppUi.textMid,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                parts.join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppUi.body.copyWith(fontSize: 10.5, color: AppUi.textLo),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _identityBonusRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0x14E9C552),
        borderRadius: BorderRadius.circular(AppUi.radiusSm),
        border: Border.all(color: AppUi.gold.withValues(alpha: 0.33)),
      ),
      child: Row(
        children: [
          const Text('★', style: TextStyle(color: AppUi.gold, fontSize: 12)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              identityBonus!,
              style: AppUi.body.copyWith(fontSize: 11, color: AppUi.gold),
            ),
          ),
        ],
      ),
    );
  }

  // ── Köyün hâli (yasalar + izler) ────────────────────────────────────────────

  /// Kararların mirası satırı — hükmünün köy ruhunda biriken kalıcı ağırlığı.
  Widget _legacyLine() {
    final pos = legacy >= 0;
    final c = pos ? AppUi.sage : AppUi.rust;
    final pct = '${pos ? '+' : '−'}${(legacy.abs() * 100).round()}%';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppUi.radiusSm),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const GameIcon(GameIconData.scroll, size: 12, color: AppUi.textLo),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              pos
                  ? 'Verdiğin hükümler köyün gönlünde sıcak bir iz bıraktı'
                  : 'Verdiğin hükümlerin gölgesi köyün üstünden kalkmıyor',
              style: AppUi.body.copyWith(fontSize: 11, color: AppUi.textMid),
            ),
          ),
          Text(pct, style: AppUi.number.copyWith(fontSize: 12.5, color: c)),
        ],
      ),
    );
  }

  Widget _factWrap() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final f in laws) _factChip(f),
        for (final f in marks) _factChip(f),
      ],
    );
  }

  Widget _factChip(DivanFact f) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
      decoration: BoxDecoration(
        color: f.color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: f.color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SemanticIcon(
            f.icon,
            size: 11,
            color: f.color,
            fallback: GameIconData.star,
          ),
          const SizedBox(width: 5),
          Text(
            f.label,
            style: AppUi.body.copyWith(
              fontSize: 10.5,
              color: AppUi.textMid,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
