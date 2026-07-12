import 'package:flutter/material.dart';
import '../scene/scene_data.dart';
import '../systems/estate_system.dart';
import '../systems/house_system.dart';
import '../systems/petition_system.dart';
import 'app_ui.dart';
import 'petition_scene_card.dart';

/// Divan — köyün her zaman açık yönetişim merkezi. Dilekçe artık "araya giren
/// modal" değil, Divan'a düşen bir mesele. Bu yüzey dört derdi tek yapıda toplar:
///
///   • GÜNDEM     — sim'in beslediği akan meseleler (bekleyen dilekçe + mayalanan
///                  baskılar). Köyde olan biten yönetişime AKAR ("omurga").
///   • GERİLİMLER — 4 zümre havası, hep görünür ("arada görünmezlik" kırılır).
///   • KÖYÜN HÂLİ — yürürlükteki yasalar + kararların kalıcı izleri ("sonuç
///                  hissedilir": hükmünün köyü ne hâle getirdiğini görürsün).
///
/// Salt-okunur bir gösterge: yeni simülasyon yürütmez, mevcut state'i okur.
/// Bekleyen dilekçeyi açmak dışındaki aksiyonlar (proaktif meclis) sonraki faz.

/// Gündeme düşmüş ya da mayalanan tek bir mesele.
class DivanMatter {
  final String icon;
  final String title;
  final String sub;

  /// 0..1 baskı/yakınlık — mayalanma fitili ne kadar dolu (1 = az kaldı).
  final double pressure;
  final PetitionTone tone;

  /// Şu an HUD'da bekleyen gerçek dilekçe mi (gündemin tepesine oturur + yanıt
  /// butonu görünür). false = henüz mayalanan, karar istemeyen baskı.
  final bool pending;

  /// Bekleyen dilekçe için kalan mühlet oranı (1→0); pending değilse yok sayılır.
  final double graceProgress;
  final bool urgent;

  /// Proaktif müdahale anahtarı — bu mesele için meclis çağrılabiliyorsa
  /// (`feud` | `estate:<name>`). null = doğrudan müdahale yok (sadece bilgi).
  final String? conveneId;

  const DivanMatter({
    required this.icon,
    required this.title,
    required this.sub,
    required this.pressure,
    this.tone = PetitionTone.neutral,
    this.pending = false,
    this.graceProgress = 1.0,
    this.urgent = false,
    this.conveneId,
  });
}

/// Köyün kalıcı hâlini özetleyen tek rozet (yürürlükteki yasa ya da hafıza izi).
class DivanFact {
  final String icon;
  final String label;
  final Color color;
  const DivanFact(this.icon, this.label, this.color);
}

class DivanPanel extends StatelessWidget {
  /// Köyün kaydığı kimlik adı.
  final String identity;

  /// Kimlik mekanik bonusu özeti (varsa).
  final String? identityBonus;

  // Köy durum şeridi.
  final double morale;
  final int population;
  final int food;
  final int gold;

  /// Gündem — bekleyenler önce, sonra mayalananlar (baskıya göre sıralı gelir).
  final List<DivanMatter> agenda;

  /// Köyün haneleri (salience sıralı) — her an görünür gerilim.
  final List<HouseSnapshot> houses;

  /// Yürürlükteki yasalar.
  final List<DivanFact> laws;

  /// Kararların kalıcı izleri (hafıza bayrakları → okunur rozet).
  final List<DivanFact> marks;

  /// Kararların mirası — büyük kararların köy ruhunda biriken KALICI moral izi
  /// (±). 0 ise gösterilmez. Hükmünün sönmeyen ağırlığı.
  final double legacy;

  /// Bekleyen dilekçeyi (varsa) tam modal olarak aç.
  final VoidCallback? onOpenPetition;

  /// Proaktif meclis çağır (id: `address` | `feud` | `estate:<name>`). null ise
  /// ajans kapalı (eski davranış).
  final void Function(String id)? onConvene;

  /// Meclis şu an çağrılabilir mi — false ise convene afordansları soluk +
  /// "dinleniyor" ipucu (cooldown).
  final bool councilReady;

  // ── KARAR DEFTERİ (fermanlar/yasalar) ───────────────────────────────────────
  // 2026-07-13: Politika editörü CIVIC BİNADAN (belediye paneli) buraya taşındı.
  // Yönetişim artık tek merkez: gündem+Meclis ile yasalar aynı Divan'da, ayrı
  // sekmelerde (tek panele yığılmasın). null → "Karar Defteri" sekmesi gizlenir.
  final VillagePolicies? policies;
  final void Function(String key)? onTogglePolicy;
  final void Function(FamilyPolicy fp)? onSetFamilyPolicy;

  /// Karar değiştirme bekleme süresi (sn) — >0 iken tüm politika satırları kilitli.
  final double policyCooldownSec;

  /// Açılışta seçili sekme: 0 = MECLİS, 1 = KARAR DEFTERİ.
  final int initialTab;

  final VoidCallback onClose;

  const DivanPanel({
    super.key,
    required this.identity,
    this.identityBonus,
    required this.morale,
    required this.population,
    required this.food,
    required this.gold,
    required this.agenda,
    required this.houses,
    required this.laws,
    required this.marks,
    this.legacy = 0,
    required this.onOpenPetition,
    this.onConvene,
    this.councilReady = false,
    this.policies,
    this.onTogglePolicy,
    this.onSetFamilyPolicy,
    this.policyCooldownSec = 0,
    this.initialTab = 0,
    required this.onClose,
  });

  static Color toneColor(PetitionTone t) => switch (t) {
        PetitionTone.warm => AppUi.sage,
        PetitionTone.solemn => AppUi.info,
        PetitionTone.ominous => AppUi.rust,
        PetitionTone.neutral => AppUi.accent,
      };

  /// Moralin sürekli renge çevrimi (estate_banner moodTone ile aynı dil).
  static Color moodTone(double m) {
    const ember = Color(0xFFE8934A); // mood sıcaklık kodu, UI accent'ten bağımsız
    const gold = Color(0xFFD9C088);
    if (m < 0.32) return Color.lerp(AppUi.rust, ember, (m / 0.32).clamp(0.0, 1.0))!;
    if (m < 0.50) {
      return Color.lerp(ember, gold, ((m - 0.32) / 0.18).clamp(0.0, 1.0))!;
    }
    if (m < 0.70) {
      return Color.lerp(gold, AppUi.sage, ((m - 0.50) / 0.20).clamp(0.0, 1.0))!;
    }
    return AppUi.sage;
  }

  String get _moraleFace {
    if (morale >= 0.72) return '😄';
    if (morale >= 0.55) return '🙂';
    if (morale >= 0.40) return '😐';
    if (morale >= 0.28) return '😟';
    return '😣';
  }

  /// Hero sahnesinin tonu — köyün moraline göre (mutlu=warm, orta=neutral,
  /// düşük=ominous). Toplanma sahnesi köyün ruh hâliyle renklenir.
  PetitionTone get _heroTone => morale >= 0.6
      ? PetitionTone.warm
      : morale >= 0.4
          ? PetitionTone.neutral
          : PetitionTone.ominous;

  String get _moraleWord {
    if (morale >= 0.72) return 'köy şen ve dingin';
    if (morale >= 0.55) return 'köyde huzur var';
    if (morale >= 0.40) return 'köyün havası kararsız';
    if (morale >= 0.28) return 'köy tedirgin';
    return 'köyde huzursuzluk var';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Hafif karartma — Divan bir gösterge, oyun durmaz; boşluğa dokun = kapat.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onClose,
            child: const ColoredBox(color: AppUi.scrim),
          ),
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: GestureDetector(
                onTap: () {}, // panel içi dokunuş kapatmasın
                // Açılış: scale+fade. NOT: AppReveal KULLANMA — bu ağaçta
                // (scroll view içinde, sınırsız yükseklik) opacity 0'da takılıp
                // paneli görünmez bırakıyor. TweenAnimationBuilder güvenli.
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  builder: (_, t, child) => Opacity(
                    opacity: t,
                    child: Transform.translate(
                      offset: Offset(0, (1 - t) * 10),
                      child: Transform.scale(
                        scale: 0.97 + t * 0.03,
                        alignment: Alignment.topCenter,
                        child: child,
                      ),
                    ),
                  ),
                  child: _GildedFrame(
                    accent: AppUi.accent,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _hero(),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _villageStrip(),
                              const SizedBox(height: 14),
                              // İki sekme: MECLİS (gündem/aksiyon) ve KARAR
                              // DEFTERİ (yasalar). Tek panele yığmak yerine
                              // ayır → her görünüm nefes alsın.
                              _DivanTabs(
                                initial: initialTab,
                                meclis: _meclisTab(),
                                karar: (policies != null &&
                                        onTogglePolicy != null)
                                    ? _kararTab()
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Sekme içerikleri ───────────────────────────────────────────────────────

  /// MECLİS sekmesi — köyü toplama aksiyonu + gündem + gerilimler.
  Widget _meclisTab() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Divan'ın başrolü: köyü toplamak en görünür, davetkâr aksiyon.
        if (onConvene != null) ...[
          _meclisAction(),
          const SizedBox(height: 16),
        ],
        const AppSectionLabel('GÜNDEM'),
        _agendaSection(),
        const SizedBox(height: 16),
        const AppSectionLabel('GERİLİMLER'),
        _tensions(),
        if (identityBonus != null) ...[
          const SizedBox(height: 8),
          _identityBonusRow(),
        ],
      ],
    );
  }

  /// KARAR DEFTERİ sekmesi — yürürlükteki yasalar/fermanlar (eskiden belediye
  /// binası panelindeydi) + kararların köyde bıraktığı kalıcı iz.
  Widget _kararTab() {
    final hasState =
        laws.isNotEmpty || marks.isNotEmpty || legacy.abs() > 0.005;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PolicyEditor(
          policies: policies!,
          onToggle: onTogglePolicy!,
          onSetFamily: onSetFamilyPolicy,
          cooldownSec: policyCooldownSec,
        ),
        if (hasState) ...[
          const SizedBox(height: 16),
          const AppSectionLabel('KÖYÜN HÂLİ'),
          if (legacy.abs() > 0.005) ...[
            _legacyLine(),
            if (laws.isNotEmpty || marks.isNotEmpty) const SizedBox(height: 8),
          ],
          if (laws.isNotEmpty || marks.isNotEmpty) _factWrap(),
        ],
      ],
    );
  }

  // ── Hero — sinematik toplanma sahnesi + kimlik + kapat ─────────────────────

  Widget _hero() {
    return SizedBox(
      height: 150,
      child: Stack(
        children: [
          // Köyün moraliyle renklenen toplanma (meclis) sahnesi.
          Positioned.fill(
            child: PetitionSceneCard.custom(
              scene: PetitionScene.gathering,
              tone: _heroTone,
              height: 150,
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
                _kicker('DİVAN'),
                const Spacer(),
                GestureDetector(
                  onTap: onClose,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: const Color(0xB3100E0B),
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: AppUi.gold.withValues(alpha: 0.3)),
                    ),
                    child: const GameIcon(GameIconData.close,
                        size: 13, color: AppUi.textMid),
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
                      Text(identity,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppUi.title.copyWith(
                            fontSize: 19,
                            color: AppUi.gold,
                            shadows: const [
                              Shadow(color: Color(0xCC000000), blurRadius: 8)
                            ],
                          )),
                      const SizedBox(height: 2),
                      Text(_moraleWord,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppUi.body.copyWith(
                              fontSize: 11,
                              color: AppUi.textMid,
                              shadows: const [
                                Shadow(color: Color(0xCC000000), blurRadius: 6)
                              ])),
                    ],
                  ),
                ),
                Text(_moraleFace, style: const TextStyle(fontSize: 22)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kicker(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xB3100E0B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppUi.accent.withValues(alpha: 0.55)),
        ),
        child: Text(text,
            style: AppUi.label.copyWith(color: AppUi.accent, fontSize: 9)),
      );

  /// ⚖ mühür madalyonu — hero'nun alt köşesinde, gilded halka.
  Widget _sealMedallion() {
    return Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [
          Color.alphaBlend(AppUi.accent.withValues(alpha: 0.22), AppUi.surface0),
          AppUi.surface0,
        ]),
        border: Border.all(color: AppUi.gold.withValues(alpha: 0.6), width: 1.6),
        boxShadow: [
          BoxShadow(color: AppUi.accent.withValues(alpha: 0.4), blurRadius: 12),
          const BoxShadow(color: Color(0x99000000), blurRadius: 6),
        ],
      ),
      child: const Text('⚖', style: TextStyle(fontSize: 24)),
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
          _stripCell(_moraleFace, '${(morale * 100).round()}%', 'moral',
              AppUi.accent,
              emoji: true),
          _stripDiv(),
          _stripCell('👥', '$population', 'nüfus', AppUi.textMid),
          _stripDiv(),
          _stripCell('🌾', '$food', 'yiyecek', AppUi.sage),
          _stripDiv(),
          _stripCell('🪙', '$gold', 'altın', AppUi.gold),
        ],
      ),
    );
  }

  Widget _stripDiv() => Container(width: 1, height: 24, color: AppUi.line);

  Widget _stripCell(String glyph, String value, String label, Color color,
      {bool emoji = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(glyph, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
            Text(value, style: AppUi.number.copyWith(fontSize: 13)),
          ],
        ),
        const SizedBox(height: 2),
        Text(label,
            style: AppUi.label.copyWith(fontSize: 7.5, letterSpacing: 0.8)),
      ],
    );
  }

  // ── MECLİS — öne çıkan davetkâr aksiyon kartı ──────────────────────────────

  Widget _meclisAction() {
    final ready = councilReady;
    return MouseRegion(
      cursor: ready ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTap: ready ? () => onConvene!('address') : null,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: ready
                  ? [
                      Color.alphaBlend(
                          AppUi.accent.withValues(alpha: 0.20), AppUi.surface2),
                      AppUi.surface1,
                    ]
                  : [AppUi.surface1, AppUi.surface0],
            ),
            borderRadius: BorderRadius.circular(AppUi.radiusSm),
            border: Border.all(
                color: ready ? AppUi.accent.withValues(alpha: 0.65) : AppUi.line,
                width: ready ? 1.4 : 1),
            boxShadow: ready
                ? [BoxShadow(color: AppUi.accent.withValues(alpha: 0.22), blurRadius: 14)]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppUi.surface0,
                  border: Border.all(
                      color: AppUi.gold.withValues(alpha: ready ? 0.6 : 0.3),
                      width: 1.4),
                  boxShadow: ready
                      ? [BoxShadow(color: AppUi.accent.withValues(alpha: 0.35), blurRadius: 8)]
                      : null,
                ),
                child: Text('⚖',
                    style: TextStyle(
                        fontSize: 20,
                        color: ready ? null : Colors.white.withValues(alpha: 0.5))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(ready ? 'MECLİS\'İ TOPLA' : 'MECLİS DİNLENİYOR',
                        style: AppUi.title.copyWith(
                            fontSize: 14,
                            letterSpacing: 1.0,
                            color: ready ? AppUi.textHi : AppUi.textLo)),
                    const SizedBox(height: 3),
                    Text(
                        ready
                            ? 'Köye söylev ver — köyün kimliğini yönlendir'
                            : 'Son karardan sonra köy bir süre dinleniyor',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppUi.body
                            .copyWith(fontSize: 10.5, color: AppUi.textLo)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GameIcon(GameIconData.chevron,
                  size: 17, color: ready ? AppUi.accent : AppUi.textLo),
            ],
          ),
        ),
      ),
    );
  }

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
                const Text('🕊️', style: TextStyle(fontSize: 15)),
                const SizedBox(width: 9),
                Expanded(
                  child: Text('Gündem sakin — köy şimdilik bir şey istemiyor.',
                      style: AppUi.body.copyWith(color: AppUi.textLo)),
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
    final c = toneColor(m.tone);
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
              ? Color.alphaBlend(c.withValues(alpha: 0.10), AppUi.surface1)
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
            Text(m.icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(m.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppUi.bodyHi.copyWith(
                                fontSize: 12.5,
                                color: pending ? AppUi.textHi : AppUi.textMid)),
                      ),
                      if (pending) ...[
                        const SizedBox(width: 7),
                        _pendingTag(m),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(m.sub,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppUi.body
                          .copyWith(fontSize: 10.5, color: AppUi.textLo)),
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
            ] else if (m.conveneId != null && onConvene != null) ...[
              const SizedBox(width: 8),
              _conveneButton(m.conveneId!),
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

  /// Mesele satırındaki proaktif müdahale düğmesi — "⚖ Meclis çağır". Patlamayı
  /// beklemeden bu gerilime şimdi otur. Meclis dinlenirken soluk + tıklanamaz.
  Widget _conveneButton(String conveneId) {
    final ready = councilReady;
    return GestureDetector(
      onTap: ready ? () => onConvene!(conveneId) : null,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: ready ? 1.0 : 0.4,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: AppUi.accent.withValues(alpha: ready ? 0.16 : 0.08),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
                color: AppUi.accent.withValues(alpha: ready ? 0.6 : 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⚖', style: TextStyle(fontSize: 11)),
              const SizedBox(width: 4),
              Text('Meclis',
                  style: AppUi.label.copyWith(
                      fontSize: 8,
                      letterSpacing: 0.5,
                      color: ready ? AppUi.accentSoft : AppUi.textLo)),
            ],
          ),
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
            color: (urgent ? AppUi.rust : AppUi.accent).withValues(alpha: 0.7)),
      ),
      child: Text(urgent ? 'AZ KALDI' : 'YANIT BEKLER',
          style: AppUi.label.copyWith(
              fontSize: 7.5,
              letterSpacing: 0.8,
              color: urgent ? AppUi.rust : AppUi.accentSoft)),
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
                gradient: LinearGradient(colors: [
                  c.withValues(alpha: 0.7),
                  Color.lerp(c, Colors.white, 0.25)!,
                ]),
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
        child: Text('Henüz bir hane şekillenmedi.',
            style: AppUi.body.copyWith(fontSize: 11, color: AppUi.textLo)),
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
            child: Text('…ve ${houses.length - shown} sessiz hane',
                style: AppUi.body.copyWith(
                    fontSize: 10,
                    color: AppUi.textLo,
                    fontStyle: FontStyle.italic)),
          ),
        ],
      ],
    );
  }

  static const List<Color> _kHousePalette = [
    Color(0xFF8FB255), Color(0xFFE0954A), Color(0xFF9E86C9), Color(0xFFD8AE56),
    Color(0xFF6FA9B8), Color(0xFFC57B6B), Color(0xFF8DA0C0), Color(0xFFB0A24E),
  ];

  static Color _houseColor(String surname) {
    var h = 0;
    for (final c in surname.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return _kHousePalette[h % _kHousePalette.length];
  }

  Widget _houseRow(HouseSnapshot s) {
    final tone = moodTone(s.mood);
    final idColor = _houseColor(s.surname);
    return Row(
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
                child: Text(s.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppUi.body.copyWith(
                        fontSize: 11.5,
                        color: s.ascendant ? AppUi.gold : AppUi.textMid,
                        fontWeight:
                            s.ascendant ? FontWeight.w800 : FontWeight.w600)),
              ),
              if (s.ascendant)
                const Padding(
                  padding: EdgeInsets.only(left: 3),
                  child: Text('★',
                      style: TextStyle(color: AppUi.gold, fontSize: 9)),
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
                        gradient: LinearGradient(colors: [
                          tone.withValues(alpha: 0.8),
                          Color.lerp(tone, Colors.white, 0.25)!,
                        ]),
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
          child: Text('%${(s.swayShare * 100).round()}',
              textAlign: TextAlign.right,
              style: AppUi.number.copyWith(
                  fontSize: 10,
                  color: s.ascendant ? AppUi.gold : AppUi.textLo)),
        ),
      ],
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
            child: Text(identityBonus!,
                style: AppUi.body
                    .copyWith(fontSize: 11, color: AppUi.gold)),
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
          const Text('📜', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Kararların mirası — köy ruhunda kalıcı iz',
                style: AppUi.body.copyWith(fontSize: 11, color: AppUi.textMid)),
          ),
          Text(pct,
              style: AppUi.number.copyWith(fontSize: 12.5, color: c)),
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
          Text(f.icon, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 5),
          Text(f.label,
              style: AppUi.body.copyWith(
                  fontSize: 10.5,
                  color: AppUi.textMid,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// İnce altın oyma çerçeveli koyu pano — dilekçe modalıyla AYNI dil (yönetişimin
/// iki yüzü aynı ağırlıkta görünsün). Hero illüstrasyonunu köşelere yaslar.
class _GildedFrame extends StatelessWidget {
  final Widget child;
  final Color accent;
  const _GildedFrame({required this.child, required this.accent});

  @override
  Widget build(BuildContext context) {
    const r = AppUi.radius;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppUi.surface2, AppUi.surface1],
        ),
        borderRadius: BorderRadius.circular(r),
        border: Border.all(color: AppUi.gold.withValues(alpha: 0.32), width: 1.2),
        boxShadow: [
          ...AppUi.softShadow,
          BoxShadow(color: accent.withValues(alpha: 0.16), blurRadius: 26),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: Stack(
          children: [
            child,
            // İçte ince altın hairline — "oyma" derinliği.
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  margin: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(r - 4),
                    border: Border.all(
                        color: AppUi.gold.withValues(alpha: 0.12), width: 1),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// DİVAN MÜHRÜ — yönetişimin KALICI, her an görünür kapısı. Meclis daha önce üç
/// kat gömülüydü (yan pano → pil → modal içi buton) ve bir seçim yapılınca kapısı
/// ekrandan kayboluyordu. Bu mühür hep ekranda durur: dilekçe mührüyle aynı
/// gilded dil (altın kenar + ⚖ madalyon + nabız), gündem doldukça kızışır.
/// Dokun → Divan açılır (Meclis oranın başrolü).
class DivanSeal extends StatefulWidget {
  final VoidCallback onTap;

  /// Gündemdeki mesele sayısı (bekleyen dilekçe + mayalananlar). 0 = sakin.
  final int agendaCount;

  /// Köy şu an bir dilekçeye yanıt bekliyor mu — mühür kızarır + nabız hızlanır.
  final bool pendingPetition;

  /// Meclis çağrılabilir mi (cooldown değilse) — "meclis hazır" ipucu.
  final bool councilReady;

  const DivanSeal({
    super.key,
    required this.onTap,
    this.agendaCount = 0,
    this.pendingPetition = false,
    this.councilReady = false,
  });

  @override
  State<DivanSeal> createState() => _DivanSealState();
}

class _DivanSealState extends State<DivanSeal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: _dur())
    ..repeat(reverse: true);

  bool _hover = false;

  Duration _dur() =>
      Duration(milliseconds: widget.pendingPetition ? 700 : 1900);

  @override
  void didUpdateWidget(DivanSeal old) {
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
    if (widget.councilReady) return 'meclis hazır';
    return 'gündem sakin';
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
            final scale = 1.0 + t * (widget.pendingPetition ? 0.05 : 0.03) +
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
                      width: 1.1),
                  boxShadow: [
                    ...AppUi.softShadow,
                    BoxShadow(
                        color: accent.withValues(alpha: glow),
                        blurRadius: 16,
                        spreadRadius: 1),
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
                            gradient: RadialGradient(colors: [
                              Color.alphaBlend(
                                  accent.withValues(alpha: 0.22), AppUi.surface0),
                              AppUi.surface0,
                            ]),
                            border: Border.all(
                                color: AppUi.gold.withValues(alpha: 0.6),
                                width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                  color: accent.withValues(alpha: 0.35),
                                  blurRadius: 6),
                            ],
                          ),
                          child: const Text('⚖',
                              style: TextStyle(fontSize: 16)),
                        ),
                        if (widget.agendaCount > 0)
                          Positioned(
                            top: -4,
                            right: -5,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: accent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                      color: accent.withValues(alpha: 0.6),
                                      blurRadius: 6),
                                ],
                              ),
                              child: Text('${widget.agendaCount}',
                                  style: AppUi.number.copyWith(
                                      fontSize: 9, color: AppUi.ink)),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('DİVAN',
                            style: AppUi.title
                                .copyWith(fontSize: 13, letterSpacing: 1.5)),
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
                                      color: accent
                                          .withValues(alpha: 0.4 + t * 0.4),
                                      blurRadius: 5),
                                ],
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(_status,
                                style: AppUi.label.copyWith(
                                    fontSize: 7.5,
                                    letterSpacing: 0.8,
                                    color: widget.pendingPetition
                                        ? AppUi.rust
                                        : AppUi.textLo)),
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

// ─── DİVAN SEKMELERİ ────────────────────────────────────────────────────────
/// MECLİS ↔ KARAR DEFTERİ geçişi. Divan'ın iki yüzü tek panele yığılmasın diye
/// ayrı sekmelerde durur (kullanıcı: "kalabalık panellere giresim gelmiyor").
/// [karar] null ise (politika bağlanmamış) sekme çubuğu hiç çizilmez.
class _DivanTabs extends StatefulWidget {
  final Widget meclis;
  final Widget? karar;
  final int initial;
  const _DivanTabs({required this.meclis, this.karar, this.initial = 0});

  @override
  State<_DivanTabs> createState() => _DivanTabsState();
}

class _DivanTabsState extends State<_DivanTabs> {
  late int _i = widget.karar == null ? 0 : widget.initial.clamp(0, 1);

  @override
  Widget build(BuildContext context) {
    final karar = widget.karar;
    if (karar == null) return widget.meclis;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: _pill('MECLİS', 0)),
          const SizedBox(width: 8),
          Expanded(child: _pill('KARAR DEFTERİ', 1)),
        ]),
        const SizedBox(height: 14),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 190),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position:
                    Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero)
                        .animate(anim),
                child: child,
              ),
            ),
            child: KeyedSubtree(
              key: ValueKey(_i),
              child: _i == 0 ? widget.meclis : karar,
            ),
          ),
        ),
      ],
    );
  }

  Widget _pill(String label, int i) {
    final on = _i == i;
    return GestureDetector(
      onTap: () => setState(() => _i = i),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: on ? AppUi.accent.withValues(alpha: 0.16) : AppUi.surface0,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
              color: on ? AppUi.accent.withValues(alpha: 0.65) : AppUi.line,
              width: on ? 1.3 : 1),
        ),
        child: Center(
          child: Text(label,
              style: AppUi.label.copyWith(
                fontSize: 9.5,
                letterSpacing: 1.1,
                color: on ? AppUi.textHi : AppUi.textLo,
              )),
        ),
      ),
    );
  }
}

// ─── KARAR DEFTERİ (politika editörü) ───────────────────────────────────────
// 2026-07-13: building_info_panel.dart'tan (belediye binası paneli) BURAYA
// taşındı — yönetişim tek merkezde. Tab bar + ikonlu satırlar + yürürlükteki
// karar rozetleri + dairesel cooldown göstergesi.

class _PolicyEditor extends StatefulWidget {
  final VillagePolicies policies;
  final void Function(String key) onToggle;
  final void Function(FamilyPolicy fp)? onSetFamily;
  final double cooldownSec;
  const _PolicyEditor({
    required this.policies,
    required this.onToggle,
    required this.cooldownSec,
    this.onSetFamily,
  });

  @override
  State<_PolicyEditor> createState() => _PolicyEditorState();
}

class _PolicyEditorState extends State<_PolicyEditor> {
  PolicyCategory _tab = PolicyCategory.family;

  @override
  Widget build(BuildContext context) {
    final p = widget.policies;
    final cd = widget.cooldownSec;
    final locked = cd > 0;
    final cdFrac = (cd / 240.0).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: AppSectionLabel('YÜRÜRLÜKTE')),
            if (locked) _cooldownRing(cdFrac, cd),
          ],
        ),
        const SizedBox(height: 4),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topLeft,
          child: _activeChips(p),
        ),
        const SizedBox(height: 12),
        _tabBar(),
        const SizedBox(height: 8),
        Container(height: 1, color: AppUi.line),
        const SizedBox(height: 8),
        AnimatedSize(
          duration: const Duration(milliseconds: 230),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                        begin: const Offset(0.06, 0), end: Offset.zero)
                    .animate(anim),
                child: child,
              ),
            ),
            child: KeyedSubtree(
              key: ValueKey(_tab),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: _tabContent(p, locked),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _cooldownRing(double frac, double sec) {
    return SizedBox(
      width: 24,
      height: 24,
      child: Stack(alignment: Alignment.center, children: [
        SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            value: frac,
            strokeWidth: 2.6,
            valueColor: const AlwaysStoppedAnimation(AppUi.rust),
            backgroundColor: AppUi.line,
          ),
        ),
        Text('${sec.ceil()}',
            style: AppUi.number.copyWith(color: AppUi.rust, fontSize: 9)),
      ]),
    );
  }

  Widget _activeChips(VillagePolicies p) {
    final active = <Widget>[];
    if (p.family != FamilyPolicy.open) {
      active.add(AppChip(label: p.family.label, color: AppUi.accent));
    }
    for (final def in kPolicyDefs) {
      if (p.isOn(def.id)) {
        active.add(AppChip(label: def.label, color: AppUi.accent));
      }
    }
    if (active.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text('Henüz yürürlükte karar yok.',
            style: AppUi.body.copyWith(
                color: AppUi.textLo, fontStyle: FontStyle.italic)),
      );
    }
    return Wrap(spacing: 5, runSpacing: 5, children: active);
  }

  Widget _tabBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [for (final c in PolicyCategory.values) _tabPill(c)],
    );
  }

  Widget _tabPill(PolicyCategory c) {
    final selected = _tab == c;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = c),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? AppUi.accent.withValues(alpha: 0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
                color:
                    selected ? AppUi.accent.withValues(alpha: 0.6) : AppUi.line,
                width: 1),
          ),
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: TextStyle(
                  fontFamily: AppUi.fontDisplay,
                  color: selected ? AppUi.textHi : AppUi.textLo,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8),
              child: Text(c.label.toUpperCase()),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _tabContent(VillagePolicies p, bool locked) {
    final widgets = <Widget>[];
    if (_tab == PolicyCategory.family) {
      widgets.add(_subHeader('DOĞURGANLIK SINIRI'));
      for (final fp in FamilyPolicy.values) {
        widgets.add(_familyRadio(p, fp, locked));
      }
      widgets.add(const SizedBox(height: 8));
      widgets.add(_subHeader('BONUS'));
    }
    final defs = kPolicyDefs.where((d) => d.category == _tab).toList();
    for (final d in defs) {
      widgets.add(_policyTile(d, p.isOn(d.id), locked));
    }
    return widgets;
  }

  Widget _subHeader(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 4, top: 2),
        child: Text(label,
            style: AppUi.label.copyWith(fontSize: 8, color: AppUi.textLo)),
      );

  Widget _policyTile(PolicyDef d, bool on, bool locked) {
    const dur = Duration(milliseconds: 220);
    return GestureDetector(
      onTap: locked ? null : () => widget.onToggle(d.id),
      child: AnimatedOpacity(
        duration: dur,
        opacity: locked ? 0.5 : 1.0,
        child: AnimatedContainer(
          duration: dur,
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          margin: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: on ? AppUi.accent.withValues(alpha: 0.10) : AppUi.surface0,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: on ? AppUi.accent.withValues(alpha: 0.45) : AppUi.line,
                width: 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: dur,
                      style: AppUi.bodyHi.copyWith(
                          fontSize: 12.5,
                          color: on ? AppUi.textHi : AppUi.textMid,
                          fontWeight: on ? FontWeight.w700 : FontWeight.w600),
                      child: Text(d.label),
                    ),
                    const SizedBox(height: 2),
                    _consequenceLine('↑', d.benefit, AppUi.sage),
                    if (d.cost != null) _consequenceLine('↓', d.cost!, AppUi.rust),
                    if (d.estateMood.isNotEmpty) _estateEffectRow(d.estateMood),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _switch(on),
            ],
          ),
        ),
      ),
    );
  }

  Widget _switch(bool on) {
    const dur = Duration(milliseconds: 220);
    return AnimatedContainer(
      duration: dur,
      curve: Curves.easeOutCubic,
      width: 32,
      height: 18,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        color: on ? AppUi.accent : AppUi.surface3,
        border: Border.all(color: on ? AppUi.accent : AppUi.line, width: 1),
      ),
      child: AnimatedAlign(
        duration: dur,
        curve: Curves.easeOutCubic,
        alignment: on ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: on ? AppUi.ink : AppUi.textLo,
          ),
        ),
      ),
    );
  }

  Widget _familyRadio(VillagePolicies p, FamilyPolicy fp, bool locked) {
    const dur = Duration(milliseconds: 200);
    final selected = p.family == fp;
    final cb = widget.onSetFamily;
    return GestureDetector(
      onTap: (locked || cb == null) ? null : () => cb(fp),
      child: AnimatedOpacity(
        duration: dur,
        opacity: locked ? 0.5 : 1.0,
        child: AnimatedContainer(
          duration: dur,
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
          margin: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color:
                selected ? AppUi.accent.withValues(alpha: 0.10) : AppUi.surface0,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: selected
                    ? AppUi.accent.withValues(alpha: 0.45)
                    : AppUi.line,
                width: 1),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: dur,
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: selected ? AppUi.accent : AppUi.textLo, width: 1.6),
                  color: selected ? AppUi.accent : Colors.transparent,
                ),
                child: AnimatedScale(
                  duration: dur,
                  curve: Curves.easeOutBack,
                  scale: selected ? 1.0 : 0.0,
                  child: const Center(
                    child: Icon(Icons.circle, size: 5, color: AppUi.ink),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: dur,
                      style: AppUi.bodyHi.copyWith(
                          fontSize: 12.5,
                          color: selected ? AppUi.textHi : AppUi.textMid,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w600),
                      child: Text(fp.label),
                    ),
                    const SizedBox(height: 2),
                    _consequenceLine('↑', fp.benefit, AppUi.sage),
                    if (fp.cost != null)
                      _consequenceLine('↓', fp.cost!, AppUi.rust),
                    if (familyPolicyEstateMood(fp).isNotEmpty)
                      _estateEffectRow(familyPolicyEstateMood(fp)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _estateEffectRow(List<(Estate, double)> effects) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Wrap(
          spacing: 8,
          runSpacing: 3,
          children: [
            for (final (e, d) in effects)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(e.label,
                      style:
                          AppUi.body.copyWith(fontSize: 9.5, color: AppUi.textLo)),
                  const SizedBox(width: 2),
                  Text(d > 0 ? '▲' : '▼',
                      style: TextStyle(
                          color: d > 0 ? AppUi.sage : AppUi.rust,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900)),
                ],
              ),
          ],
        ),
      );

  Widget _consequenceLine(String prefix, String text, Color color) => Padding(
        padding: const EdgeInsets.only(top: 1),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(prefix,
                style: TextStyle(
                    color: color, fontSize: 10, fontWeight: FontWeight.w900)),
            const SizedBox(width: 4),
            Expanded(
              child: Text(text,
                  style: AppUi.body
                      .copyWith(fontSize: 9.5, color: color.withValues(alpha: 0.92))),
            ),
          ],
        ),
      );
}
