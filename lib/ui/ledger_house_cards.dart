part of 'village_ledger.dart';

/// ─── HANE EYLEM KARTLARI ────────────────────────────────────────────────────
///
/// Oyuncunun bir haneye karşı harekete geçtiği yüzey (bağış/ceza/el koyma/
/// nikâh/sürgün/entrika) ve topyekûn el koyma kartı.
///
/// Kartlar yalnız SUNAR ve geri çağırır; kararın bedeli/etkisi sahne tarafında
/// (house_action.dart + scene_house_actions.dart) hesaplanır.

class _HouseActionCard extends StatelessWidget {
  final DivanSeat seat;
  final List<HouseActionEntry> entries;
  final VoidCallback onClose;
  const _HouseActionCard({
    required this.seat,
    required this.entries,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final tone = VillageLedger.moodTone(seat.mood);
    final hue = _councilHouseColor(seat.surname);
    return Container(
      decoration: BoxDecoration(
        color: AppUi.surface1,
        borderRadius: BorderRadius.circular(AppUi.radiusSm),
        border: Border.all(
            color: seat.ascendant
                ? AppUi.gold.withValues(alpha: 0.5)
                : AppUi.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Başlık: hane kimliği + hâl + nüfuz ──────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            decoration: BoxDecoration(
              color: AppUi.surface2,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppUi.radiusSm)),
              border: Border(bottom: BorderSide(color: AppUi.line)),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration:
                      BoxDecoration(color: hue, shape: BoxShape.circle),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text('${seat.surname} Hanesi',
                                overflow: TextOverflow.ellipsis,
                                style: AppUi.bodyHi.copyWith(
                                    fontSize: 12.5,
                                    color: seat.ascendant
                                        ? AppUi.gold
                                        : AppUi.textHi)),
                          ),
                          if (seat.ascendant)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Text('★',
                                  style: TextStyle(
                                      color: AppUi.gold, fontSize: 10)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                          'reis ${seat.name} · ${seat.members} kişi · '
                          'nüfuz %${(seat.swayShare * 100).round()}',
                          style:
                              AppUi.label.copyWith(color: AppUi.textLo)),
                    ],
                  ),
                ),
                // Hâl çubuğu.
                SizedBox(
                  width: 54,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('hâl %${(seat.mood * 100).round()}',
                          style: AppUi.label.copyWith(color: tone)),
                      const SizedBox(height: 3),
                      Container(
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppUi.surface0,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: seat.mood.clamp(0.0, 1.0),
                              child: Container(color: tone),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onClose,
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.only(left: 10, right: 2),
                    child: Text('✕',
                        style:
                            TextStyle(color: AppUi.textLo, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
          // ── Eylemler ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                for (int i = 0; i < entries.length; i++) ...[
                  _row(entries[i]),
                  if (i != entries.length - 1) const SizedBox(height: 5),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(HouseActionEntry e) {
    final fg = e.enabled ? AppUi.textHi : AppUi.textLo;
    return GestureDetector(
      onTap: e.enabled ? e.onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: e.enabled ? 1.0 : 0.55,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: e.enabled ? AppUi.surface2 : AppUi.surface0,
            borderRadius: BorderRadius.circular(AppUi.radiusSm),
            border: Border.all(
                color: e.enabled ? AppUi.line : AppUi.line.withValues(alpha: 0.5)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(e.icon, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.label,
                        style: AppUi.bodyHi.copyWith(fontSize: 11.5, color: fg)),
                    const SizedBox(height: 2),
                    Text(e.detail,
                        style: AppUi.body
                            .copyWith(fontSize: 10, color: AppUi.textLo)),
                    if (e.effects.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        children: [
                          for (final f in e.effects) _effectChip(f),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (e.enabled)
                const Padding(
                  padding: EdgeInsets.only(left: 6, top: 1),
                  child: Text('›',
                      style: TextStyle(color: AppUi.accent, fontSize: 14)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Sonuç rozeti — kazanç yeşil, bedel kızıl okunsun (oyuncu tek bakışta
  /// neyin karşılığında ne verdiğini görmeli).
  Widget _effectChip(String text) {
    final good = text.startsWith('+');
    final bad = text.startsWith('−') || text.startsWith('-');
    final c = good
        ? AppUi.sage
        : bad
            ? AppUi.rust
            : AppUi.textMid;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Text(text,
          style: AppUi.label.copyWith(fontSize: 8.5, color: c)),
    );
  }
}

/// MÜLKİYETİ KALDIR kartı — masanın altında duran tek seferlik, geri dönüşsüz
/// hamle. Hane kartındaki sıradan eylemlerden GÖRSEL olarak ayrılır (kızıl
/// çerçeve, ayrı gövde): bu bir hüküm değil, rejim değişikliğidir.
class _MassSeizureCard extends StatelessWidget {
  final HouseActionEntry entry;
  const _MassSeizureCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final on = entry.enabled;
    final tint = on ? AppUi.rust : AppUi.textLo;
    return Opacity(
      opacity: on ? 1.0 : 0.6,
      child: GestureDetector(
        onTap: on ? entry.onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: on
                ? AppUi.rust.withValues(alpha: 0.10)
                : AppUi.surface0,
            borderRadius: BorderRadius.circular(AppUi.radiusSm),
            border: Border.all(
                color: tint.withValues(alpha: on ? 0.55 : 0.28),
                width: on ? 1.3 : 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.icon, style: TextStyle(fontSize: 15, color: tint)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.label,
                        style: AppUi.bodyHi.copyWith(
                            fontSize: 12,
                            letterSpacing: 0.6,
                            color: tint)),
                    const SizedBox(height: 3),
                    Text(entry.detail,
                        style: AppUi.body
                            .copyWith(fontSize: 10.5, color: AppUi.textLo)),
                    if (entry.effects.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        children: [
                          for (final f in entry.effects)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppUi.rust.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                    color: AppUi.rust.withValues(alpha: 0.3)),
                              ),
                              child: Text(f,
                                  style: AppUi.label.copyWith(
                                      fontSize: 8.5, color: AppUi.rust)),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
