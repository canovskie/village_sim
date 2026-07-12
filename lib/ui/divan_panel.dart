import 'package:flutter/material.dart';
import '../systems/house_system.dart';
import '../systems/petition_system.dart';
import 'app_ui.dart';

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
          child: AppReveal(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: GestureDetector(
                onTap: () {}, // panel içi dokunuş kapatmasın
                child: AppPanel(
                  accent: AppUi.accent,
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _header(),
                      const SizedBox(height: 12),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const AppSectionLabel('GÜNDEM'),
                              _agendaSection(),
                              const SizedBox(height: 14),
                              const AppSectionLabel('GERİLİMLER'),
                              _tensions(),
                              if (identityBonus != null) ...[
                                const SizedBox(height: 8),
                                _identityBonusRow(),
                              ],
                              if (laws.isNotEmpty ||
                                  marks.isNotEmpty ||
                                  legacy.abs() > 0.005) ...[
                                const SizedBox(height: 14),
                                const AppSectionLabel('KÖYÜN HÂLİ'),
                                if (legacy.abs() > 0.005) ...[
                                  _legacyLine(),
                                  if (laws.isNotEmpty || marks.isNotEmpty)
                                    const SizedBox(height: 8),
                                ],
                                if (laws.isNotEmpty || marks.isNotEmpty)
                                  _factWrap(),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Başlık + köy durum şeridi ───────────────────────────────────────────────

  Widget _header() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('⚖', style: TextStyle(fontSize: 22)),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('DİVAN', style: AppUi.title),
              const SizedBox(height: 2),
              Text(identity,
                  style: AppUi.label.copyWith(
                      color: AppUi.gold, letterSpacing: 0.6)),
            ],
          ),
        ),
        _stateStrip(),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onClose,
          behavior: HitTestBehavior.opaque,
          child: const Padding(
            padding: EdgeInsets.all(2),
            child: GameIcon(GameIconData.close, size: 16, color: AppUi.textLo),
          ),
        ),
      ],
    );
  }

  Widget _stateStrip() {
    Widget cell(String txt, Color c, {bool emoji = false}) => Padding(
          padding: const EdgeInsets.only(left: 10),
          child: Text(txt,
              style: emoji
                  ? const TextStyle(fontSize: 14)
                  : AppUi.number.copyWith(fontSize: 12.5, color: c)),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        cell(_moraleFace, AppUi.textHi, emoji: true),
        cell('$population', AppUi.textMid),
        cell('$food', AppUi.sage),
        cell('$gold', AppUi.gold),
      ],
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
        // Proaktif inisiyatif kanalı — köy istemese de meclisi sen çağır.
        if (onConvene != null) ...[
          const SizedBox(height: 10),
          _addressButton(),
        ],
      ],
    );
  }

  /// 📢 Söylev Ver — her an erişilebilir proaktif meclis (kimliği yönlendir).
  /// Meclis dinlenirken (cooldown) soluk + ipucu.
  Widget _addressButton() {
    final ready = councilReady;
    return GestureDetector(
      onTap: ready ? () => onConvene!('address') : null,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: ready ? 1.0 : 0.5,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: ready
                ? Color.alphaBlend(
                    AppUi.accent.withValues(alpha: 0.14), AppUi.surface1)
                : AppUi.surface0,
            borderRadius: BorderRadius.circular(AppUi.radiusSm),
            border: Border.all(
                color: ready
                    ? AppUi.accent.withValues(alpha: 0.55)
                    : AppUi.line),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('📢', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              Text(ready ? 'MECLİS ÇAĞIR · SÖYLEV VER' : 'MECLİS DİNLENİYOR',
                  style: AppUi.label.copyWith(
                      fontSize: 9.5,
                      letterSpacing: 1.0,
                      color: ready ? AppUi.accentSoft : AppUi.textLo)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _matterRow(DivanMatter m) {
    final c = toneColor(m.tone);
    final pending = m.pending;
    return GestureDetector(
      onTap: pending ? onOpenPetition : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
        decoration: BoxDecoration(
          color: pending
              ? Color.alphaBlend(c.withValues(alpha: 0.10), AppUi.surface1)
              : AppUi.surface0,
          borderRadius: BorderRadius.circular(AppUi.radiusSm),
          border: Border(
            left: BorderSide(
                color: c.withValues(alpha: pending ? 0.95 : 0.5), width: 3),
            top: BorderSide(color: AppUi.line),
            right: BorderSide(color: AppUi.line),
            bottom: BorderSide(color: AppUi.line),
          ),
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
    // Salience sıralı gelir; en fazla 6 açık göster, gerisi özet.
    final shown = houses.length > 6 ? 6 : houses.length;
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
