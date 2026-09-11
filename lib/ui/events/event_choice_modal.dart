import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/resources.dart';
import '../../systems/events/event_system.dart';
import '../core/app_ui.dart';
import '../core/mobile_ui.dart';
import '../core/semantic_icon.dart';
import 'event_artwork.dart';
import 'event_scene_card.dart';

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
  final String? Function(EventChoice)? blockedReason;

  const EventChoiceModal({
    super.key,
    required this.event,
    required this.onChoose,
    this.onDismiss,
    this.stockpile,
    this.blockedReason,
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
            child: AppGildedFrame(
              accent: _accent,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 5, child: _eventStory(compact: true)),
                  Container(width: 1, color: AppUi.line),
                  Expanded(
                    flex: 4,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(9, 9, 9, 9),
                      child: _choiceDeck(compact: true, dense: true),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _wideBody() => SafeArea(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final panelWidth = min(1180.0, constraints.maxWidth - 40);
        final panelHeight = min(680.0, constraints.maxHeight - 40);
        final dense = panelHeight < 610;
        return Center(
          child: SizedBox(
            width: panelWidth,
            height: panelHeight,
            child: _swallow(
              AppReveal(
                child: AppGildedFrame(
                  accent: _accent,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: panelWidth * .43,
                        child: _eventStory(compact: dense),
                      ),
                      Container(width: 1, color: AppUi.line),
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.all(dense ? 12 : 18),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF1B1E23), Color(0xFF111318)],
                            ),
                          ),
                          child: _choiceDeck(compact: false, dense: dense),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );

  Widget _eventStory({required bool compact}) {
    final artwork = eventArtworkAsset(event);
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (artwork != null)
            EventArtwork(
              asset: artwork,
              height: double.infinity,
              accent: _accent,
            )
          else
            EventSceneCard(
              event: event,
              height: double.infinity,
              drawBorder: false,
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x3D050607),
                  Color(0x00050607),
                  Color(0xE8111215),
                ],
                stops: [0, .42, 1],
              ),
            ),
          ),
          Positioned(
            left: compact ? 13 : 24,
            top: compact ? 12 : 22,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 9 : 13,
                vertical: compact ? 4 : 6,
              ),
              decoration: BoxDecoration(
                color: const Color(0xD6171010),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: _accent.withValues(alpha: .72)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SemanticIcon(
                    event.icon,
                    size: compact ? 11 : 14,
                    color: _accent,
                    fallback: GameIconData.dice,
                    label: event.title,
                  ),
                  SizedBox(width: compact ? 6 : 8),
                  Text(
                    'KÖY OLAYI · $_categoryLabel',
                    style: AppUi.label.copyWith(
                      color: _accent,
                      fontSize: compact ? 8 : 10,
                      letterSpacing: compact ? .8 : 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: compact ? 14 : 28,
            right: compact ? 14 : 28,
            bottom: compact ? 14 : 28,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _upper(event.title),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppUi.title.copyWith(
                    fontSize: compact ? 21 : 36,
                    height: 1.06,
                    letterSpacing: compact ? 1.4 : 2.2,
                    shadows: const [
                      Shadow(color: Color(0xF0000000), blurRadius: 10),
                    ],
                  ),
                ),
                SizedBox(height: compact ? 6 : 10),
                Container(width: compact ? 44 : 68, height: 2, color: _accent),
                SizedBox(height: compact ? 6 : 10),
                Text(
                  event.message,
                  maxLines: compact ? 3 : 5,
                  overflow: TextOverflow.ellipsis,
                  style: AppUi.body.copyWith(
                    color: AppUi.textHi,
                    fontSize: compact ? 11 : 15,
                    height: compact ? 1.3 : 1.48,
                    shadows: const [
                      Shadow(color: Color(0xF0000000), blurRadius: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _choiceDeck({required bool compact, required bool dense}) {
    final choices = event.choices!;
    final columns = choices.length <= 3 ? 1 : 2;
    final rows = (choices.length / columns).ceil();
    return Column(
      children: [
        for (var row = 0; row < rows; row++) ...[
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var column = 0; column < columns; column++) ...[
                  if (row * columns + column < choices.length)
                    Expanded(
                      child: _choiceCard(
                        choices[row * columns + column],
                        compact: compact || columns > 1,
                        dense: dense,
                      ),
                    )
                  else
                    const Expanded(child: SizedBox.shrink()),
                  if (column != columns - 1) SizedBox(width: compact ? 6 : 10),
                ],
              ],
            ),
          ),
          if (row != rows - 1) SizedBox(height: compact ? 7 : 10),
        ],
      ],
    );
  }

  Widget _choiceCard(
    EventChoice choice, {
    required bool compact,
    required bool dense,
  }) {
    final reason = blockedReason?.call(choice);
    final enabled =
        reason == null && (stockpile == null || choice.canAfford(stockpile!));
    return Tooltip(
      message: reason ?? (!enabled ? 'Kaynak yetersiz' : ''),
      child: _ChoiceCard(
        choice: choice,
        accent: _accent,
        compact: compact,
        dense: dense,
        onTap: enabled ? () => onChoose(choice) : null,
      ),
    );
  }
}

String _upper(String text) =>
    text.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();

/// Hover/press feedback'li olay seçim kartı.
class _ChoiceCard extends StatefulWidget {
  final EventChoice choice;
  final Color accent;
  final VoidCallback? onTap;
  final bool compact;
  final bool dense;
  const _ChoiceCard({
    required this.choice,
    required this.accent,
    required this.onTap,
    this.compact = false,
    this.dense = false,
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
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _hover
                    ? [const Color(0xFF252930), const Color(0xFF171A1F)]
                    : [const Color(0xFF1A1D22), const Color(0xFF101216)],
              ),
              borderRadius: BorderRadius.circular(11),
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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: widget.compact ? 3 : 4,
                        child: EventChoiceSceneCard(
                          choice: c,
                          height: double.infinity,
                        ),
                      ),
                      Expanded(
                        flex: widget.compact ? 6 : 7,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            widget.compact ? 9 : 18,
                            widget.compact ? 8 : 14,
                            widget.compact ? 8 : 13,
                            widget.compact ? 7 : 12,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 3,
                                    height: widget.compact ? 13 : 18,
                                    color: accent,
                                  ),
                                  SizedBox(width: widget.compact ? 7 : 10),
                                  Expanded(
                                    child: Text(
                                      _upper(c.label),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppUi.title.copyWith(
                                        fontSize: widget.compact ? 10.5 : 16,
                                        height: 1.12,
                                        letterSpacing: widget.compact ? .5 : 1,
                                      ),
                                    ),
                                  ),
                                  GameIcon(
                                    GameIconData.chevron,
                                    size: widget.compact ? 11 : 14,
                                    color: _hover ? accent : AppUi.textLo,
                                  ),
                                ],
                              ),
                              SizedBox(height: widget.compact ? 4 : 8),
                              Text(
                                c.detail,
                                maxLines: widget.compact || widget.dense
                                    ? 2
                                    : 3,
                                overflow: TextOverflow.ellipsis,
                                style: AppUi.body.copyWith(
                                  color: AppUi.textLo,
                                  fontSize: widget.compact ? 9 : 11.5,
                                  height: 1.32,
                                ),
                              ),
                              if (deltas.isNotEmpty) ...[
                                SizedBox(height: widget.compact ? 5 : 10),
                                Wrap(
                                  spacing: widget.compact ? 4 : 6,
                                  runSpacing: 4,
                                  children: [
                                    for (final delta in deltas.take(3))
                                      _deltaChip(delta.$1, delta.$2),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!enabled)
                    Positioned(
                      left: 7,
                      right: 7,
                      bottom: 7,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppUi.surface0.withValues(alpha: .94),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: AppUi.rust),
                        ),
                        child: Text(
                          'YETERSİZ KAYNAK',
                          textAlign: TextAlign.center,
                          style: AppUi.label.copyWith(
                            color: AppUi.rust,
                            fontSize: 7.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
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
      padding: EdgeInsets.symmetric(
        horizontal: widget.compact ? 5 : 7,
        vertical: widget.compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: TextStyle(fontSize: widget.compact ? 9 : 11)),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppUi.number.copyWith(
              fontSize: widget.compact ? 8.5 : 10.5,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
