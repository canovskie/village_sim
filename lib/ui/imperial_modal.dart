import 'package:flutter/material.dart';
import '../systems/imperial.dart';
import 'app_ui.dart';

/// İmparatorluk vergi heyetiyle pazarlık modalı. Karar ZORUNLU (boşluğa
/// dokunup kaçılamaz — sim duraklı). Kaynak talebinde basit pazarlık mini-oyunu
/// (teklif kademeleri, itibara göre tutar/tutmaz); devşirmede fidye seçeneği.
class ImperialModal extends StatefulWidget {
  final ImperialDemand demand;
  final double favor;       // 0..1 İmparatorlukla ilişki
  final int ransomCost;     // devşirme fidyesi (altın)
  final bool canAcceptFull; // tam ödeme karşılanabiliyor mu
  final bool canRansom;     // fidye karşılanabiliyor mu
  final double resistChance; // heyeti kovma başarı şansı (0 = denenemez)
  final VoidCallback onAccept;
  final VoidCallback onRefuse;
  final VoidCallback onRansom;
  final void Function(double offerFraction) onHaggle;
  final VoidCallback onResist;

  const ImperialModal({
    super.key,
    required this.demand,
    required this.favor,
    required this.ransomCost,
    required this.canAcceptFull,
    required this.canRansom,
    required this.resistChance,
    required this.onAccept,
    required this.onRefuse,
    required this.onRansom,
    required this.onHaggle,
    required this.onResist,
  });

  @override
  State<ImperialModal> createState() => _ImperialModalState();
}

class _ImperialModalState extends State<ImperialModal> {
  bool _haggling = false;

  String get _favorWord {
    final f = widget.favor;
    if (f >= 0.7) return 'sana iyi gözle bakıyor';
    if (f >= 0.45) return 'sana tarafsız bakıyor';
    if (f >= 0.25) return 'senden hoşnut değil';
    return 'sana düşman gözüyle bakıyor';
  }

  Color get _favorColor {
    final f = widget.favor;
    if (f >= 0.7) return AppUi.sage;
    if (f >= 0.45) return AppUi.gold;
    if (f >= 0.25) return AppUi.accent;
    return AppUi.rust;
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.demand;
    return Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: AppUi.scrim)),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(26),
              child: AppReveal(
                child: AppPanel(
                  accent: AppUi.rust,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('⚔️', style: TextStyle(fontSize: 22)),
                          const SizedBox(width: 10),
                          Text('İMPARATORLUK HEYETİ',
                              style: AppUi.label.copyWith(color: AppUi.rust)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Vergi vakti geldi',
                          style: AppUi.title.copyWith(fontSize: 18)),
                      const SizedBox(height: 10),
                      Text(
                        _haggling
                            ? 'Komutan kaşını kaldırdı: "Ne öneriyorsun köylü? '
                                'Dikkatli ol — sabrımı zorlama."'
                            : 'Silahlı bir bölük meydanda. Komutan buyurdu: '
                                '"${d.label} — derhal." ${d.isConscript ? '' : 'Ödemezsen alırız."'}',
                        style: AppUi.body.copyWith(fontSize: 12.5, height: 1.5),
                      ),
                      const SizedBox(height: 12),
                      _favorBar(),
                      const AppDivider(),
                      if (_haggling)
                        ..._haggleOptions(d)
                      else
                        ..._mainOptions(d),
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

  Widget _favorBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppStatBar(
          label: 'İMPARATORLUK İTİBARIN',
          value: widget.favor.clamp(0.0, 1.0),
          trailing: '${(widget.favor * 100).round()}%',
          color: _favorColor,
        ),
        const SizedBox(height: 4),
        Text('İmparatorluk $_favorWord.',
            style: AppUi.body.copyWith(fontSize: 10.5, color: AppUi.textLo)),
      ],
    );
  }

  List<Widget> _mainOptions(ImperialDemand d) {
    return [
      if (d.isConscript) ...[
        _opt('Genci teslim et', 'Bir genç askere alınır — köy yas tutar.',
            AppUi.textMid, widget.onAccept),
        _opt(
            'Altınla kurtar · ${widget.ransomCost}★',
            widget.canRansom
                ? 'Fidye öde, genç köyde kalır.'
                : 'Yeterli altın yok.',
            AppUi.gold,
            widget.canRansom ? widget.onRansom : null),
      ] else ...[
        _opt(
            'Tam öde · ${d.amount}${d.icon}',
            widget.canAcceptFull
                ? 'Talebi karşıla — güvenli, itibar artar.'
                : 'Elindeki yetmez; ne varsa alınır.',
            AppUi.sage,
            widget.onAccept),
        _opt('Pazarlık et', 'İtibarın yüksekse daha azı tutabilir — riskli.',
            AppUi.accent, () => setState(() => _haggling = true)),
      ],
      const SizedBox(height: 8),
      // Direniş — yalnız köy yeterince güçlüyse (muhafız/kalabalık). Başarı
      // şansı AÇIKÇA gösterilir (#7 saydamlık): körlemesine kumar değil.
      if (widget.resistChance > 0)
        _opt(
            'Diren ve kov  ·  %${(widget.resistChance * 100).round()} başarı',
            'Heyeti zorla kov. Tutarsa onur + ölüm yok; tutmazsa savunucular düşer.',
            AppUi.accent,
            widget.onResist),
      _opt('Reddet', 'Hiçbir şey verme — ama kan dökülür.', AppUi.rust,
          widget.onRefuse),
    ];
  }

  List<Widget> _haggleOptions(ImperialDemand d) {
    // Teklif kademeleri — gerçek miktarı göster. Eşik itibara bağlı (sahnedeki
    // 0.85 - favor*0.45 ile aynı): #7 saydamlık → hangi teklifin tutacağını
    // oyuncuya açıkça göster (deneme-yanılma yerine bilinçli risk).
    const fracs = [0.5, 0.7, 0.85];
    final threshold = 0.85 - widget.favor * 0.45;
    return [
      for (final f in fracs)
        _opt(
            '${(d.amount * f).round()}${d.icon} öner  (%${(f * 100).round()})',
            f >= threshold
                ? '✓ İtibarın bu teklifi tutturmaya yeter — büyük olasılıkla kabul.'
                : '⚠ Düşük teklif — komutan reddedip öfkelenebilir (tam ödersin).',
            f >= threshold ? AppUi.sage : AppUi.rust,
            () => widget.onHaggle(f)),
      const SizedBox(height: 8),
      _opt('Vazgeç', 'Pazarlığı bırak, baştaki seçeneklere dön.', AppUi.textLo,
          () => setState(() => _haggling = false)),
    ];
  }

  Widget _opt(String label, String detail, Color accent, VoidCallback? onTap) {
    final disabled = onTap == null;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: disabled ? 0.5 : 1.0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: AppUi.surface0,
              borderRadius: BorderRadius.circular(AppUi.radiusSm),
              border: Border.all(color: accent.withValues(alpha: 0.55)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppUi.bodyHi.copyWith(fontSize: 13.5)),
                const SizedBox(height: 2),
                Text(detail,
                    style: AppUi.body.copyWith(
                        fontSize: 10.5, color: AppUi.textLo)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
