import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../systems/estate_system.dart' show EstateMoodTier;
import '../systems/house_system.dart';
import '../systems/imperial.dart';
import 'app_ui.dart';

/// Ekranın sağ kenarında sabit duran "HANELER" panosu — eski zümre barının
/// yerini alır. Politik katman artık soyut sınıflar değil, DOĞUMUNU İZLEDİĞİN
/// haneler ([[project_estates]] Zümre→Hane geçişi). Salience'a göre sıralı:
/// öne çıkan (küskün / güçlü / kalabalık) haneler üstte açık, sessiz kalanlar
/// tek satırda özetlenir — köy büyürken pano taşmaz.
///
/// Her hane satırı: kimlik noktacığı (soyaddan türeyen sabit renk) + hane adı +
/// üye sayısı + MOOD barı (renk+dolgu+kelime aynı şeyi söyler). Baskın hane
/// altın yıldız. Ahşap madalyon/emoji yığını YOK ([[feedback ui_not_flash]]),
/// canlılık abartısız ([[feedback lighting_restraint]]).
class HouseBanner extends StatefulWidget {
  final List<HouseSnapshot> houses;

  /// İmparatorluk (DIŞ güç) nabzı — hanelerin altında ayrı satır. null = gizli.
  final ImperialSnapshot? imperial;

  /// Köyün kaydığı kimlik ("Dengeli Köy" / baskın hane adı).
  final String identity;

  final bool collapsed;
  final VoidCallback? onToggleCollapse;

  /// Divan'ı (tam yönetişim panosu) aç.
  final VoidCallback? onOpenDivan;

  /// Gündemdeki mesele sayısı — alt "DİVAN" pilinde rozet.
  final int agendaCount;

  const HouseBanner({
    super.key,
    required this.houses,
    this.imperial,
    required this.identity,
    this.collapsed = false,
    this.onToggleCollapse,
    this.onOpenDivan,
    this.agendaCount = 0,
  });

  @override
  State<HouseBanner> createState() => _HouseBannerState();
}

class _HouseBannerState extends State<HouseBanner>
    with SingleTickerProviderStateMixin {
  static const double _width = 198;

  /// Panoda kaç hane açıkça listelenir — gerisi "sessiz hane" olarak özetlenir.
  static const int _maxShown = 5;

  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  )..repeat();

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _breath,
      builder: (context, _) {
        final breath = 0.5 - 0.5 * math.cos(_breath.value * math.pi * 2);
        final houses = widget.houses;
        final shown = math.min(houses.length, _maxShown);
        final hidden = houses.length - shown;
        return AppPanel(
          width: _width,
          accent: AppUi.accent,
          padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(),
              if (!widget.collapsed) ...[
                const SizedBox(height: 11),
                if (houses.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text('Henüz bir hane şekillenmedi.',
                        style: AppUi.body.copyWith(
                            fontSize: 10.5, color: AppUi.textLo)),
                  )
                else ...[
                  for (int i = 0; i < shown; i++) ...[
                    _HouseRow(
                      snap: houses[i],
                      breath: breath,
                      onTap: widget.onOpenDivan,
                    ),
                    if (i != shown - 1) const SizedBox(height: 3),
                  ],
                  if (hidden > 0) ...[
                    const SizedBox(height: 5),
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Text('…ve $hidden sessiz hane',
                          style: AppUi.body.copyWith(
                              fontSize: 9.5,
                              color: AppUi.textLo,
                              fontStyle: FontStyle.italic)),
                    ),
                  ],
                ],
                if (widget.imperial != null) ...[
                  const SizedBox(height: 11),
                  const AppSectionLabel('DIŞ GÜÇ'),
                  _ImperialRow(
                    snap: widget.imperial!,
                    breath: breath,
                    onTap: widget.onOpenDivan,
                  ),
                ],
                const SizedBox(height: 11),
                _identityFooter(),
              ],
              if (widget.onOpenDivan != null) ...[
                const SizedBox(height: 11),
                _divanPill(),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _header() {
    return GestureDetector(
      onTap: widget.onToggleCollapse,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          const Text('HANELER', style: AppUi.label),
          const Spacer(),
          Transform.rotate(
            angle: widget.collapsed ? -1.5708 : 1.5708,
            child: const GameIcon(GameIconData.chevron,
                size: 11, color: AppUi.textLo),
          ),
        ],
      ),
    );
  }

  Widget _identityFooter() {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: AppUi.line)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            widget.identity,
            style: AppUi.label
                .copyWith(color: AppUi.accentSoft, letterSpacing: 0.6),
          ),
        ),
        Expanded(child: Container(height: 1, color: AppUi.line)),
      ],
    );
  }

  Widget _divanPill() {
    final count = widget.agendaCount;
    final hot = count > 0;
    return GestureDetector(
      onTap: widget.onOpenDivan,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: hot
              ? Color.alphaBlend(
                  AppUi.accent.withValues(alpha: 0.16), AppUi.surface1)
              : AppUi.surface1,
          borderRadius: BorderRadius.circular(AppUi.radiusSm),
          border: Border.all(
              color: hot ? AppUi.accent.withValues(alpha: 0.7) : AppUi.line,
              width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GameIcon(GameIconData.scroll,
                size: 14, color: hot ? AppUi.accent : AppUi.textMid),
            const SizedBox(width: 7),
            Text('DİVAN',
                style: AppUi.button.copyWith(
                    fontSize: 11,
                    letterSpacing: 1.2,
                    color: hot ? AppUi.textHi : AppUi.textMid)),
            if (hot) ...[
              const SizedBox(width: 7),
              Container(
                constraints: const BoxConstraints(minWidth: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                    color: AppUi.accent,
                    borderRadius: BorderRadius.circular(20)),
                child: Text('$count',
                    textAlign: TextAlign.center,
                    style:
                        AppUi.number.copyWith(fontSize: 10, color: AppUi.ink)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Hanenin kimlik rengi — soyaddan deterministik (moralden bağımsız, sabit).
/// Küratörlü toprak paleti: haneler birbirinden ayrılır ama oyunun sıcak/
/// soğuk dengesine oturur (neon yok).
const List<Color> _kHousePalette = [
  Color(0xFF8FB255), // adaçayı
  Color(0xFFE0954A), // bakır
  Color(0xFF9E86C9), // mor
  Color(0xFFD8AE56), // altın
  Color(0xFF6FA9B8), // tozlu deniz
  Color(0xFFC57B6B), // terrakota
  Color(0xFF8DA0C0), // arduvaz mavi
  Color(0xFFB0A24E), // zeytin
];

Color _houseColor(String surname) {
  var h = 0;
  for (final c in surname.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return _kHousePalette[h % _kHousePalette.length];
}

/// Mood → sürekli renk (küskün kırmızı → tedirgin kor → kayıtsız altın →
/// memnun adaçayı). Zümre barıyla aynı semantik.
Color _moodTone(double m) {
  const red = AppUi.rust;
  const ember = Color(0xFFE8934A);
  const gold = Color(0xFFD9C088);
  const sage = AppUi.sage;
  if (m < 0.32) return Color.lerp(red, ember, (m / 0.32).clamp(0.0, 1.0))!;
  if (m < 0.50) {
    return Color.lerp(ember, gold, ((m - 0.32) / 0.18).clamp(0.0, 1.0))!;
  }
  if (m < 0.70) {
    return Color.lerp(gold, sage, ((m - 0.50) / 0.20).clamp(0.0, 1.0))!;
  }
  return sage;
}

String _moodWord(EstateMoodTier tier) {
  switch (tier) {
    case EstateMoodTier.content:
      return 'memnun';
    case EstateMoodTier.neutral:
      return 'kayıtsız';
    case EstateMoodTier.uneasy:
      return 'tedirgin';
    case EstateMoodTier.sullen:
      return 'küskün';
  }
}

class _HouseRow extends StatelessWidget {
  final HouseSnapshot snap;
  final double breath;
  final VoidCallback? onTap;

  const _HouseRow({required this.snap, required this.breath, this.onTap});

  @override
  Widget build(BuildContext context) {
    final tone = _moodTone(snap.mood);
    final idColor = _houseColor(snap.surname);
    final asc = snap.ascendant;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 7, 6, 7),
        decoration: BoxDecoration(
          color: asc ? idColor.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: idColor,
                    shape: BoxShape.circle,
                    boxShadow: asc
                        ? [
                            BoxShadow(
                                color: idColor.withValues(alpha: 0.6),
                                blurRadius: 5)
                          ]
                        : null,
                  ),
                ),
                if (asc) ...[
                  const GameIcon(GameIconData.star,
                      size: 10, color: AppUi.gold),
                  const SizedBox(width: 3),
                ],
                Expanded(
                  child: Text(
                    snap.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppUi.fontDisplay,
                      fontSize: 12,
                      letterSpacing: 0.3,
                      fontWeight: asc ? FontWeight.w700 : FontWeight.w600,
                      color: asc ? AppUi.textHi : AppUi.textMid,
                    ),
                  ),
                ),
                if (snap.members > 0) ...[
                  const SizedBox(width: 5),
                  Text('·${snap.members}',
                      style: AppUi.body
                          .copyWith(fontSize: 9.5, color: AppUi.textLo)),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _MoodBar(
                      value: snap.mood, color: tone, glow: asc ? breath : 0),
                ),
                const SizedBox(width: 9),
                SizedBox(
                  width: 54,
                  child: Text(
                    _moodWord(snap.tier),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: AppUi.fontText,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                      color: tone,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// İmparatorluk (DIŞ güç) satırı — hanelerle aynı dil, soğuk okunur.
class _ImperialRow extends StatelessWidget {
  final ImperialSnapshot snap;
  final double breath;
  final VoidCallback? onTap;

  const _ImperialRow({required this.snap, required this.breath, this.onTap});

  static Color _favorTone(double f) {
    const hostile = AppUi.rust;
    const wary = AppUi.gold;
    const allied = AppUi.info;
    if (f < 0.5) return Color.lerp(hostile, wary, (f / 0.5).clamp(0.0, 1.0))!;
    return Color.lerp(wary, allied, ((f - 0.5) / 0.5).clamp(0.0, 1.0))!;
  }

  @override
  Widget build(BuildContext context) {
    final dim = snap.watching ? 1.0 : 0.5;
    final tone = _favorTone(snap.favor);
    final barTone = snap.active
        ? Color.lerp(const Color(0xFFE8934A), AppUi.rust, snap.imminence)!
        : tone;
    final (statusText, statusColor) = snap.active
        ? ('TALEP VAR', AppUi.rust)
        : !snap.watching
            ? ('gözden ırak', AppUi.textLo)
            : (snap.favorLabel, tone);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: dim,
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 7, 6, 7),
          decoration: BoxDecoration(
            color: snap.active
                ? AppUi.rust.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: barTone,
                      shape: BoxShape.circle,
                      boxShadow: snap.active
                          ? [
                              BoxShadow(
                                  color: AppUi.rust.withValues(alpha: 0.6),
                                  blurRadius: 5)
                            ]
                          : null,
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'İmparatorluk',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppUi.fontDisplay,
                        fontSize: 12,
                        letterSpacing: 0.3,
                        fontWeight: FontWeight.w600,
                        color: AppUi.textMid,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _MoodBar(
                      value: snap.watching ? snap.imminence : 0.0,
                      color: barTone,
                      glow: snap.active ? breath : 0,
                    ),
                  ),
                  const SizedBox(width: 9),
                  SizedBox(
                    width: 62,
                    child: Text(
                      statusText,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontFamily: AppUi.fontText,
                        fontSize: 9.5,
                        fontWeight:
                            snap.active ? FontWeight.w800 : FontWeight.w600,
                        letterSpacing: snap.active ? 0.4 : 0.2,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// İnce, oyuk kanallı mood barı. Değer yumuşak tween'lenir; [glow] > 0 ise
/// dolan kısım hafifçe soluk alır (yalnız baskın hane / aktif tehdit).
class _MoodBar extends StatelessWidget {
  final double value; // 0..1
  final Color color;
  final double glow; // 0..1 nefes
  const _MoodBar({required this.value, required this.color, this.glow = 0});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: AppUi.surface0,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: AppUi.line, width: 0.6),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Align(
          alignment: Alignment.centerLeft,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => FractionallySizedBox(
              widthFactor: v,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    color.withValues(alpha: 0.75),
                    Color.lerp(color, Colors.white, 0.18)!,
                  ]),
                  boxShadow: glow > 0
                      ? [
                          BoxShadow(
                              color: color.withValues(alpha: 0.35 * glow),
                              blurRadius: 5)
                        ]
                      : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
