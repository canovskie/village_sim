import 'package:flutter/material.dart';
import '../systems/event_system.dart';
import 'game_theme.dart';

/// Bir rastgele olay tetiklendiğinde ekranın üst-ortasında çıkan zengin
/// banner kartı. Kategoriye göre renklenir (pozitif yeşil, negatif kırmızı,
/// nötr amber), etki kutucukları + countdown bar ile birlikte.
class EventBanner extends StatelessWidget {
  final EventOutcome event;
  /// Banner'ın ekranda toplam kalış süresi içinde geriye kalan saniye.
  final double timeLeft;
  /// Toplam görünme süresi (countdown bar oranı için).
  final double duration;
  final VoidCallback onClose;

  const EventBanner({
    super.key,
    required this.event,
    required this.timeLeft,
    required this.duration,
    required this.onClose,
  });

  Color get _accent => switch (event.category) {
        EventCategory.positive => const Color(0xFF6FBE4A),
        EventCategory.negative => const Color(0xFFD45A45),
        EventCategory.neutral  => const Color(0xFFE9A23B),
      };

  String get _categoryLabel => switch (event.category) {
        EventCategory.positive => 'Olumlu',
        EventCategory.negative => 'Olumsuz',
        EventCategory.neutral  => 'Olay',
      };

  @override
  Widget build(BuildContext context) {
    final progress = duration <= 0 ? 0.0 : (timeLeft / duration).clamp(0.0, 1.0);
    final deltas = event.deltaSummary();
    return Container(
      width: 360,
      decoration: BoxDecoration(
        color: const Color(0xEE1A140C),
        border: Border.all(color: _accent.withValues(alpha: 0.85), width: 2),
        boxShadow: [
          BoxShadow(
              color: _accent.withValues(alpha: 0.25),
              blurRadius: 12, spreadRadius: 1),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Üst şerit: ikon + başlık + kategori + close
          Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: _accent.withValues(alpha: 0.55), width: 1),
              ),
              gradient: LinearGradient(
                colors: [
                  _accent.withValues(alpha: 0.20),
                  _accent.withValues(alpha: 0.04),
                ],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                // Büyük ikon kutusu
                Container(
                  width: 44, height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F0B06),
                    border: Border.all(color: _accent, width: 1.5),
                  ),
                  child: Text(event.icon, style: const TextStyle(fontSize: 26)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(event.title,
                          style: TextStyle(
                            color: _accent,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            letterSpacing: 0.6,
                          )),
                      const SizedBox(height: 2),
                      Text(_categoryLabel,
                          style: const TextStyle(
                            color: MedievalTheme.textSecondary,
                            fontSize: 9,
                            fontFamily: 'monospace',
                          )),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onClose,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: MedievalTheme.chipDecoration(),
                    child: const Text('✕',
                        style: TextStyle(
                          color: MedievalTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        )),
                  ),
                ),
              ],
            ),
          ),
          // Mesaj gövdesi
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 8),
            child: Text(event.message,
                style: const TextStyle(
                  color: MedievalTheme.textPrimary,
                  fontSize: 10.5,
                  height: 1.4,
                  fontFamily: 'monospace',
                )),
          ),
          // Etki kutucukları
          if (deltas.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 9),
              child: Wrap(
                spacing: 5, runSpacing: 5,
                children: deltas.map((d) => _deltaChip(d.$1, d.$2)).toList(),
              ),
            ),
          // Countdown bar
          Container(
            height: 3,
            color: const Color(0x33000000),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: Container(color: _accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _deltaChip(String icon, String label) {
    // Renk delta işaretine göre kırmızı/yeşil; moral chip her zaman amber.
    final isMoral = icon == '😊';
    final isNeg = label.startsWith('-');
    final color = isMoral
        ? const Color(0xFFE9A23B)
        : (isNeg ? const Color(0xFFE07868) : const Color(0xFF8BD267));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0B06),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              )),
        ],
      ),
    );
  }
}
