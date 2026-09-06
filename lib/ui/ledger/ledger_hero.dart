part of 'village_ledger.dart';

/// DEFTER BAŞLIĞI — hero bandı, mühür madalyonu, köy şeridi ve nabız.
extension _VillageLedgerHero on VillageLedger {

  // ── Hero — sinematik toplanma sahnesi + kimlik + kapat ─────────────────────

  /// MOBİL hero — TEK satır, 54dp.
  ///
  /// Telefon yatayda defterin bütün derdi dikey bütçe: 82dp'lik hero + 60dp'lik
  /// bölüm rafı + 55dp'lik köy şeridi üst üste binince 365dp'lik çerçevede
  /// içeriğe ~160dp kalıyordu — NÜFUS'u açan oyuncu tek bir köylü satırı bile
  /// göremiyordu. Sahne kartı zemin olarak KALIR (defterin kimliği o), ama
  /// künye · kimlik · nabız · kapat tek hatta iner; ikinci satır (köyün hâli
  /// cümlesi) ve mühür madalyonu masaüstüne özel kalır.
  Widget _compactHero() {
    const h = 54.0;
    return SizedBox(
      height: h,
      child: Stack(
        children: [
          Positioned.fill(
            child: PetitionSceneCard.custom(
              scene: PetitionScene.gathering,
              tone: _heroTone,
              height: h,
              drawBorder: false,
            ),
          ),
          const Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x73100E0B), Color(0xE6100E0B)],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(left: 12, right: 4),
              child: Row(
                children: [
                  _kicker(_ledgerKicker),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      identity,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppUi.title.copyWith(
                        fontSize: 15,
                        color: AppUi.gold,
                        shadows: const [
                          Shadow(color: Color(0xCC000000), blurRadius: 8),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  GameIcon(GameIconData.heart, size: 14, color: _moraleTone),
                  const SizedBox(width: 5),
                  Text(
                    '${(morale * 100).round()}%',
                    style: AppUi.number.copyWith(
                      fontSize: 13,
                      color: _moraleTone,
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: onClose,
                    behavior: HitTestBehavior.opaque,
                    child: const SizedBox(
                      width: MobileUi.tap,
                      height: MobileUi.tap,
                      child: Center(
                        child: GameIcon(
                          GameIconData.close,
                          size: 17,
                          color: AppUi.textMid,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hero(BuildContext context) {
    // Kısa (yatay telefon) ekranda 132dp, 393dp'lik yüksekliğin üçte biriydi —
    // asıl içerik ekran dışına taşıyordu. Sahne kartı kalıyor, sadece inceliyor.
    final short = useCompactGameUi(context);
    if (short) return _compactHero();
    // Sol indeks + nabız, aşağıdaki iki kalın krom şeridini ortadan kaldırdı.
    // Hero artık daha sıkı bir sinematik kapak; içerik sayfasına 12dp daha
    // bırakırken mühür ve siluetler hâlâ rahatça okunuyor.
    const heroH = 120.0;
    return SizedBox(
      height: heroH,
      child: Stack(
        children: [
          // Köyün moraliyle renklenen toplanma (meclis) sahnesi.
          Positioned.fill(
            child: PetitionSceneCard.custom(
              scene: PetitionScene.gathering,
              tone: _heroTone,
              height: heroH,
              drawBorder: false,
            ),
          ),
          // Alt okunaklılık zemini.
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 98,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0xE6100E0B)],
                  ),
                ),
              ),
            ),
          ),
          // Üst künye + kapat.
          Positioned(
            left: 14,
            right: 12,
            top: 12,
            child: Row(
              children: [
                _kicker(_ledgerKicker),
                const Spacer(),
                GestureDetector(
                  onTap: onClose,
                  behavior: HitTestBehavior.opaque,
                  // Kapat düğmesinin dokunma alanı 25×25dp'ydi — paneli
                  // kapatan tek düğme için fazla küçük. Görsel daire aynı
                  // kalıyor, hit alanı 44'e büyüyor.
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: const Color(0xB3100E0B),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppUi.gold.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const GameIcon(
                          GameIconData.close,
                          size: 13,
                          color: AppUi.textMid,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Alt: ⚖ madalyon + kimlik başlığı + köyün hâli.
          Positioned(
            left: 14,
            right: 14,
            bottom: 12,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _sealMedallion(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        identity,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppUi.title.copyWith(
                          fontSize: 19,
                          color: AppUi.gold,
                          shadows: const [
                            Shadow(color: Color(0xCC000000), blurRadius: 8),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _moraleWord,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppUi.body.copyWith(
                          fontSize: 11,
                          color: AppUi.textMid,
                          shadows: const [
                            Shadow(color: Color(0xCC000000), blurRadius: 6),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Emoji surat yerine köyün nabzı: aynı bilgi, oyunun ikon
                // dilinde ve okunur bir sayıyla.
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GameIcon(GameIconData.heart, size: 15, color: _moraleTone),
                    const SizedBox(width: 5),
                    Text(
                      '${(morale * 100).round()}%',
                      style: AppUi.number.copyWith(
                        fontSize: 14,
                        color: _moraleTone,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Defterin künyesi — köyün adıyla. Ad yoksa (ya da hiç verilmediyse)
  /// jenerik "KÖY DEFTERİ" kalır; künye asla boş görünmez.
  String get _ledgerKicker {
    final v = village.trim();
    if (v.isEmpty || v.toLowerCase() == 'köy') return 'KÖY DEFTERİ';
    return '${upperTr(v)} DEFTERİ';
  }

  Widget _kicker(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xB3100E0B),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppUi.accent.withValues(alpha: 0.55)),
    ),
    child: Text(
      text,
      style: AppUi.label.copyWith(color: AppUi.accent, fontSize: 9),
    ),
  );

  /// ⚖ mühür madalyonu — hero'nun alt köşesinde, gilded halka.
  Widget _sealMedallion() {
    return Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Color.alphaBlend(
              AppUi.accent.withValues(alpha: 0.22),
              AppUi.surface0,
            ),
            AppUi.surface0,
          ],
        ),
        border: Border.all(
          color: AppUi.gold.withValues(alpha: 0.6),
          width: 1.6,
        ),
        boxShadow: [
          BoxShadow(color: AppUi.accent.withValues(alpha: 0.4), blurRadius: 12),
          const BoxShadow(color: Color(0x99000000), blurRadius: 6),
        ],
      ),
      child: const GameIcon(GameIconData.scales, size: 24, color: AppUi.gold),
    );
  }

  // ── Köy durum şeridi (moral/nüfus/yiyecek/altın) ───────────────────────────

  Widget _villageStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppUi.surface0,
        borderRadius: BorderRadius.circular(AppUi.radiusSm),
        border: Border.all(color: AppUi.line, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Emoji DEĞİL, Phosphor: bu şerit oyunun geri kalanıyla aynı ikon
          // dilini konuşmalı. Emoji glyph'ler cihazdan cihaza değişiyor, kendi
          // rengini/ağırlığını dayatıyor ve tam da altındaki nüfus KPI şeridi
          // aynı veriyi düzgün ikonla gösterdiği için ekranda iki farklı görsel
          // dil yan yana duruyordu.
          _stripCell(
            GameIconData.heart,
            '${(morale * 100).round()}%',
            'moral',
            _moraleTone,
          ),
          _stripDiv(),
          _stripCell(GameIconData.people, '$population', 'nüfus', AppUi.info),
          _stripDiv(),
          _stripCell(GameIconData.wheat, '$food', 'yiyecek', AppUi.sage),
          _stripDiv(),
          _stripCell(GameIconData.coin, '$gold', 'altın', AppUi.gold),
        ],
      ),
    );
  }

  /// Geniş ekranda köyün dört canlı sayısı ana sayfanın üstünde yatay bir
  /// bant oluşturmaz; cildin dibinde 2×2 bir "nabız" kümesi olur. Aynı veri,
  /// daha az krom ve defter metaforunda daha güçlü bir aidiyet.
  Widget _villageRailPulse() {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppUi.accent.withValues(alpha: 0.055),
            AppUi.surface0.withValues(alpha: 0.82),
          ],
        ),
        borderRadius: BorderRadius.circular(AppUi.radiusSm),
        border: Border.all(color: AppUi.gold.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: AppUi.accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'KÖYÜN NABZI',
                style: AppUi.label.copyWith(
                  fontSize: 8,
                  letterSpacing: 1.2,
                  color: AppUi.accentSoft,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _railStat(
                  GameIconData.heart,
                  '${(morale * 100).round()}%',
                  'moral',
                  _moraleTone,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _railStat(
                  GameIconData.people,
                  '$population',
                  'nüfus',
                  AppUi.info,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: _railStat(
                  GameIconData.wheat,
                  '$food',
                  'erzak',
                  AppUi.sage,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _railStat(
                  GameIconData.coin,
                  '$gold',
                  'altın',
                  AppUi.gold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _railStat(GameIconData icon, String value, String label, Color color) {
    return Row(
      children: [
        GameIcon(icon, size: 11, color: color),
        const SizedBox(width: 5),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 1,
                style: AppUi.number.copyWith(fontSize: 11.5, color: color),
              ),
              Text(
                label.toUpperCase(),
                maxLines: 1,
                style: AppUi.label.copyWith(fontSize: 7, letterSpacing: 0.6),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stripDiv() => Container(width: 1, height: 24, color: AppUi.line);

  Color get _moraleTone => morale >= 0.6
      ? AppUi.sage
      : morale >= 0.4
      ? AppUi.accentSoft
      : AppUi.rust;

  Widget _stripCell(
    GameIconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GameIcon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(value, style: AppUi.number.copyWith(fontSize: 13)),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label.toUpperCase(),
          style: AppUi.label.copyWith(fontSize: 8.5, letterSpacing: 0.8),
        ),
      ],
    );
  }
}
