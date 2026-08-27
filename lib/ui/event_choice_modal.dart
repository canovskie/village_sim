import 'package:flutter/material.dart';
import '../core/resources.dart';
import '../systems/event_system.dart';
import 'app_ui.dart';
import 'event_artwork.dart';
import 'mobile_ui.dart';
import 'semantic_icon.dart';

/// Karar gerektiren olaylar için tam-ekran modal. Arka planı karartır,
/// ortada koyu rafine kart: ikon + başlık + olay mesajı + seçenek kartları.
/// Her seçim kartı: label + detay + etki chip'leri.
///
/// [onDismiss] verilirse boşluğa dokunmak modalı kapatır — karar HUD'daki
/// mühre geri iner (kapıda kuyruk; mühlet akmaya devam eder). Verilmezse
/// eski davranış: yalnız seçimle kapanır.
class EventChoiceModal extends StatelessWidget {
  final EventOutcome event;
  final void Function(EventChoice) onChoose;
  final VoidCallback? onDismiss;
  final ResourceBundle? stockpile;

  const EventChoiceModal({
    super.key,
    required this.event,
    required this.onChoose,
    this.onDismiss,
    this.stockpile,
  });

  Color get _accent => switch (event.category) {
    EventCategory.positive => AppUi.sage,
    EventCategory.negative => AppUi.rust,
    EventCategory.neutral => AppUi.accent,
  };

  String get _categoryLabel => switch (event.category) {
    EventCategory.positive => 'FIRSAT',
    EventCategory.negative => 'TEHLİKE',
    EventCategory.neutral => 'OLAY',
  };

  @override
  Widget build(BuildContext context) {
    // Scrim'e dokun = mühre geri in; kartın kendisi dokunuşu yutar (_swallow,
    // panel hizasında). Dilekçe modalının kapanma diliyle aynı.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onDismiss,
      child: ColoredBox(
        // Tüm arkayı karart — oyuncu odağı modal'a.
        color: AppUi.scrim,
        child: useCompactGameUi(context) ? _compactBody(context) : _wideBody(),
      ),
    );
  }

  /// Panelin üstüne gelen dokunuş scrim'e sızmasın — panel içi boşluğa
  /// dokunmak modalı KAPATMAZ (yanlışlıkla kapama en çok telefonda can yakar).
  Widget _swallow(Widget child) => GestureDetector(onTap: () {}, child: child);

  List<Widget> _choiceCards({bool compact = false}) => [
    for (final c in event.choices!) ...[
      _ChoiceCard(
        choice: c,
        accent: _accent,
        compact: compact,
        onTap: stockpile == null || c.canAfford(stockpile!)
            ? () => onChoose(c)
            : null,
      ),
      if (c != event.choices!.last) const SizedBox(height: 9),
    ],
  ];

  /// Mobil kararlar kaymaz: mevcut yüksekliği seçenekler eşit paylaşır.
  /// Olay kataloğunda 2 seçenek var; üçe çıksa da aynı ekrana bölünür.
  Widget _compactChoices() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (int i = 0; i < event.choices!.length; i++) ...[
        Expanded(
          child: _ChoiceCard(
            choice: event.choices![i],
            accent: _accent,
            compact: true,
            onTap: stockpile == null || event.choices![i].canAfford(stockpile!)
                ? () => onChoose(event.choices![i])
                : null,
          ),
        ),
        if (i != event.choices!.length - 1) const SizedBox(height: 7),
      ],
    ],
  );

  /// TELEFON YATAY — solda olay, sağda seçenekler. Tek sütunda üç seçenekli
  /// bir olay 414dp'lik ekranın altından taşıyordu; iki sütun hem taşmayı hem
  /// de iki yandaki ~340dp'lik ölü alanı bitirir.
  Widget _compactBody(BuildContext context) {
    final window = MobileUi.windowSize(context);
    return Center(
      child: SizedBox(
        width: window.width,
        height: window.height,
        child: _swallow(
          AppReveal(
            child: AppPanel(
              accent: _accent,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 5,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _header(compact: true),
                        const SizedBox(height: 7),
                        EventArtwork(
                          asset: eventArtworkAsset(event),
                          height: 100,
                          accent: _accent,
                        ),
                        const SizedBox(height: 7),
                        Text(
                          event.message,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: AppUi.body.copyWith(
                            fontSize: 12,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(width: 1, color: AppUi.line),
                  const SizedBox(width: 10),
                  Expanded(flex: 4, child: _compactChoices()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _wideBody() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _swallow(
            AppReveal(
              child: AppPanel(
                accent: _accent,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _header(),
                    const SizedBox(height: 12),
                    EventArtwork(
                      asset: eventArtworkAsset(event),
                      height: 164,
                      accent: _accent,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      event.message,
                      textAlign: TextAlign.center,
                      style: AppUi.body.copyWith(fontSize: 12.5, height: 1.5),
                    ),
                    const AppDivider(),
                    ..._choiceCards(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header({bool compact = false}) {
    return Row(
      children: [
        // Olay ikonu — koyu kare, aksan kenar + soft glow.
        Container(
          width: compact ? 50 : 60,
          height: compact ? 50 : 60,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppUi.surface0,
            borderRadius: BorderRadius.circular(AppUi.radiusSm),
            border: Border.all(
              color: _accent.withValues(alpha: 0.7),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(color: _accent.withValues(alpha: 0.28), blurRadius: 14),
            ],
          ),
          child: SemanticIcon(
            event.icon,
            size: compact ? 27 : 32,
            color: _accent,
            fallback: GameIconData.dice,
            label: event.title,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_categoryLabel, style: AppUi.label.copyWith(color: _accent)),
              const SizedBox(height: 4),
              Text(
                event.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppUi.title.copyWith(
                  fontSize: compact ? 16 : 18,
                  color: _accent,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Hover/press feedback'li olay seçim kartı.
class _ChoiceCard extends StatefulWidget {
  final EventChoice choice;
  final Color accent;
  final VoidCallback? onTap;
  final bool compact;
  const _ChoiceCard({
    required this.choice,
    required this.accent,
    required this.onTap,
    this.compact = false,
  });
  @override
  State<_ChoiceCard> createState() => _ChoiceCardState();
}

class _ChoiceCardState extends State<_ChoiceCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.choice;
    final accent = widget.accent;
    final deltas = c.deltaSummary();
    final enabled = widget.onTap != null;
    return MouseRegion(
      onEnter: (_) {
        if (enabled) setState(() => _hover = true);
      },
      onExit: (_) => setState(() => _hover = false),
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 120),
          opacity: enabled ? 1.0 : 0.46,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            padding: widget.compact
                ? const EdgeInsets.fromLTRB(10, 8, 10, 8)
                : const EdgeInsets.fromLTRB(12, 10, 12, 11),
            decoration: BoxDecoration(
              color: _hover
                  ? Color.alphaBlend(
                      accent.withValues(alpha: 0.14),
                      AppUi.surface2,
                    )
                  : AppUi.surface1,
              borderRadius: BorderRadius.circular(AppUi.radiusSm),
              border: Border.all(
                color: _hover ? accent : AppUi.line,
                width: _hover ? 1.5 : 1,
              ),
              boxShadow: _hover
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.25),
                        blurRadius: 10,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 16,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        c.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppUi.bodyHi.copyWith(
                          fontSize: widget.compact ? 12.5 : 13,
                        ),
                      ),
                    ),
                    GameIcon(
                      GameIconData.chevron,
                      size: 14,
                      color: _hover ? accent : AppUi.textLo,
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Padding(
                  padding: const EdgeInsets.only(left: 13),
                  child: Text(
                    c.detail,
                    maxLines: widget.compact ? 2 : null,
                    overflow: widget.compact ? TextOverflow.ellipsis : null,
                    style: AppUi.body.copyWith(
                      fontSize: widget.compact ? 10.5 : 11,
                      height: 1.35,
                    ),
                  ),
                ),
                if (deltas.isNotEmpty &&
                    (!widget.compact || deltas.length <= 3)) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 13),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: deltas
                          .map((d) => _deltaChip(d.$1, d.$2))
                          .toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _deltaChip(String icon, String label) {
    final isMoral = icon == '😊';
    final isNeg = label.startsWith('-');
    // Fayda sage ↑ / bedel rust ↓ — sonuçları tipografi+renkle koru.
    final color = isMoral ? AppUi.accent : (isNeg ? AppUi.rust : AppUi.sage);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppUi.number.copyWith(fontSize: 10.5, color: color),
          ),
        ],
      ),
    );
  }
}
