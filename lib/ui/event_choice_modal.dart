import 'package:flutter/material.dart';
import '../systems/event_system.dart';
import 'game_theme.dart';

/// Karar gerektiren olaylar için tam-ekran modal. Arka planı karartır,
/// ortada zengin kart: ikon + başlık + olay mesajı + seçenek kartları.
/// Her seçim kartı: label + detay + etki chip'leri.
class EventChoiceModal extends StatelessWidget {
  final EventOutcome event;
  final void Function(EventChoice) onChoose;

  const EventChoiceModal({
    super.key,
    required this.event,
    required this.onChoose,
  });

  Color get _accent => switch (event.category) {
        EventCategory.positive => const Color(0xFF6FBE4A),
        EventCategory.negative => const Color(0xFFD45A45),
        EventCategory.neutral  => const Color(0xFFE9A23B),
      };

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      // Tüm arkayı karart — oyuncu odağı modal'a.
      color: const Color(0xCC050308),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: Container(
            margin: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF120D08),
              border: Border.all(color: _accent.withValues(alpha: 0.85), width: 2),
              boxShadow: [
                BoxShadow(
                    color: _accent.withValues(alpha: 0.35),
                    blurRadius: 24, spreadRadius: 2),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _header(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                  child: Text(event.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: MedievalTheme.textPrimary,
                        fontSize: 12,
                        height: 1.5,
                        fontFamily: 'monospace',
                      )),
                ),
                const Divider(height: 1, color: Color(0x33FFFFFF)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                  child: Column(
                    children: [
                      for (final c in event.choices!) ...[
                        _choiceCard(c),
                        if (c != event.choices!.last) const SizedBox(height: 9),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _accent.withValues(alpha: 0.30),
            _accent.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        border: Border(
          bottom: BorderSide(color: _accent.withValues(alpha: 0.55), width: 1),
        ),
      ),
      child: Row(
        children: [
          // Büyük ikon kutusu — dramatik
          Container(
            width: 64, height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF0A0805),
              border: Border.all(color: _accent, width: 2),
            ),
            child: Text(event.icon, style: const TextStyle(fontSize: 40)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('OLAY',
                    style: TextStyle(
                      color: _accent.withValues(alpha: 0.7),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2.2,
                      fontFamily: 'monospace',
                    )),
                const SizedBox(height: 4),
                Text(event.title,
                    style: TextStyle(
                      color: _accent,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      letterSpacing: 0.5,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _choiceCard(EventChoice c) {
    final deltas = c.deltaSummary();
    return _ChoiceButton(
      accent: _accent,
      onTap: () => onChoose(c),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 6, height: 16,
                  color: _accent,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(c.label,
                      style: const TextStyle(
                        color: MedievalTheme.textAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      )),
                ),
                const Icon(Icons.arrow_forward,
                    color: MedievalTheme.textSecondary, size: 14),
              ],
            ),
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.only(left: 15),
              child: Text(c.detail,
                  style: const TextStyle(
                    color: MedievalTheme.textSecondary,
                    fontSize: 10,
                    height: 1.4,
                    fontFamily: 'monospace',
                  )),
            ),
            if (deltas.isNotEmpty) ...[
              const SizedBox(height: 7),
              Padding(
                padding: const EdgeInsets.only(left: 15),
                child: Wrap(
                  spacing: 5, runSpacing: 5,
                  children: deltas.map((d) => _deltaChip(d.$1, d.$2)).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _deltaChip(String icon, String label) {
    final isMoral = icon == '😊';
    final isNeg = label.startsWith('-');
    final color = isMoral
        ? const Color(0xFFE9A23B)
        : (isNeg ? const Color(0xFFE07868) : const Color(0xFF8BD267));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0805),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                color: color, fontSize: 9.5,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              )),
        ],
      ),
    );
  }
}

/// Hover/press feedback için seçim butonu.
class _ChoiceButton extends StatefulWidget {
  final Widget child;
  final Color accent;
  final VoidCallback onTap;
  const _ChoiceButton(
      {required this.child, required this.accent, required this.onTap});
  @override
  State<_ChoiceButton> createState() => _ChoiceButtonState();
}

class _ChoiceButtonState extends State<_ChoiceButton> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: _hover
                ? widget.accent.withValues(alpha: 0.12)
                : const Color(0xFF0F0A06),
            border: Border.all(
              color: _hover
                  ? widget.accent
                  : widget.accent.withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
