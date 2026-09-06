import 'package:flutter/material.dart';

import '../systems/chronicle.dart';
import 'app_ui.dart';
import 'semantic_icon.dart';

/// KRONİK SÜZGECİ — güncenin "ne arıyorum" şeridi.
///
/// Günce düz ve filtresiz tek listeydi: altı yıllık bir koşuda mevsim
/// annalleri, doğumlar, nikâhlar ve büyüme satırları birikince oyuncunun
/// VERDİĞİ kararlar aralarında kayboluyordu. Süzgeç bunun tek çaresi; sıralama
/// ya da arama değil, çünkü aranan şey bir kelime değil bir TÜR: "kararlarımı
/// göster".
///
/// Süzgeç durumu burada yaşar ([VillageLedger] ve mobil tahta ikisi de
/// StatelessWidget) ve gövdeyi çağıran kendi çizer: masaüstünde uzun liste,
/// telefonda iki sütunlu sayfa. Ortak olan yalnız seçim ve sayım.
class ChronicleFilter extends StatefulWidget {
  /// Günce — YAZILDIĞI sırada (eskiden yeniye). Süzgeç tersini verir.
  final List<ChronicleEntry> entries;

  /// [filtered] = seçili türe göre süzülmüş, en YENİ önce sıralı liste.
  /// [chips] = süzgeç şeridi; çağıran onu istediği yere koyar (başlığın altına).
  final Widget Function(
    BuildContext context,
    List<ChronicleEntry> filtered,
    Widget chips,
  ) builder;

  /// Şerit yoğunluğu — telefon tahtasında bir tık küçük.
  final bool compact;

  const ChronicleFilter({
    super.key,
    required this.entries,
    required this.builder,
    this.compact = false,
  });

  @override
  State<ChronicleFilter> createState() => _ChronicleFilterState();
}

class _ChronicleFilterState extends State<ChronicleFilter> {
  /// null = TÜMÜ.
  ChronicleKind? _kind;

  static Color _colorOf(ChronicleKind k) => switch (k) {
        ChronicleKind.decision => AppUi.gold,
        ChronicleKind.life => AppUi.sage,
        ChronicleKind.crisis => AppUi.rust,
      };

  @override
  Widget build(BuildContext context) {
    final counts = <ChronicleKind, int>{};
    for (final e in widget.entries) {
      counts[e.kind] = (counts[e.kind] ?? 0) + 1;
    }
    // Seçili tür sonradan boşalamaz (günce yalnız büyür) ama kayıttan dönen
    // eski bir defterde hiç kararı olmayabilir: boş türe düşülmez, sönük durur.
    final filtered = [
      for (final e in widget.entries.reversed)
        if (_kind == null || e.kind == _kind) e,
    ];

    final chips = Padding(
      padding: EdgeInsets.only(bottom: widget.compact ? 5 : 8),
      child: Wrap(
        spacing: 5,
        runSpacing: 5,
        children: [
          _chip(null, 'TÜMÜ', widget.entries.length, AppUi.accent),
          for (final k in ChronicleKind.values)
            _chip(k, k.label, counts[k] ?? 0, _colorOf(k), icon: k.icon),
        ],
      ),
    );

    return widget.builder(context, filtered, chips);
  }

  Widget _chip(
    ChronicleKind? k,
    String label,
    int count,
    Color color, {
    String? icon,
  }) {
    final on = _kind == k;
    final empty = count == 0;
    final c = empty ? AppUi.textLo : color;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: empty ? null : () => setState(() => _kind = k),
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 7 : 9, vertical: widget.compact ? 3 : 4),
        decoration: BoxDecoration(
          color: on ? c.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: c.withValues(alpha: on ? 0.75 : (empty ? 0.18 : 0.32))),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              SemanticIcon(icon,
                  size: widget.compact ? 9 : 10,
                  color: on ? AppUi.textHi : (empty ? AppUi.textLo : c),
                  fallback: GameIconData.scroll),
              const SizedBox(width: 4),
            ],
            Text(
              empty ? label : '$label · $count',
              style: AppUi.label.copyWith(
                fontSize: widget.compact ? 7.5 : 8.5,
                letterSpacing: 0.6,
                color: on ? AppUi.textHi : (empty ? AppUi.textLo : AppUi.textMid),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
