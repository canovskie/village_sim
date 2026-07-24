import 'package:flutter/material.dart';
import '../systems/imperial.dart';
import '../text/voice.dart';
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

  /// Metin tohumu — TALEBE bağlı, rebuild'e değil. setState (pazarlık sekmesi)
  /// cümleyi değiştirmesin diye Random değil, sabit bir tohum kullanılır.
  int get _seed =>
      (widget.demand.amount * 131 + widget.demand.kind.index * 17) & 0x7fffffff;

  /// Komutanın masadaki sözü. İtibar merdiveni: yüksekte neredeyse nazik bir
  /// memur, düşükte sıkılmış bir cellat. Sesini hiçbir kademede yükseltmez.
  String get _commanderLine {
    final f = widget.favor;
    final d = widget.demand;
    if (_haggling) {
      return Voice.pick([
        'Komutan kalemi bıraktı. "Söyle. Ama önce şunu bil: rakamı ben koymadım, '
            'ben yalnız eksiğini tamamlarım."',
        'Komutan sana ilk kez doğrudan baktı. "Dinliyorum. Kısa tut, atlar ayakta."',
        'Komutan defteri parmağıyla tuttu. "Bir sayı söyle köylü. Yanlış sayı da '
            'bir cevaptır, unutma."',
      ], _seed);
    }
    final opener = Voice.pick(
        f >= 0.7
            ? const [
                'Komutan atından indi, eldivenini çıkardı. Defteri açtı:',
                'Komutan seni adınla selamladı, sonra defteri açtı:',
              ]
            : f >= 0.25
                ? const [
                    'Bölük meydanda dizildi. Komutan defterini açtı, satırı buldu:',
                    'Komutan inmedi bile. Eyerden okudu:',
                  ]
                : const [
                    'Askerler sıraya girdi, mızraklar indi. Komutan defteri sıkıntıyla açtı:',
                    'Komutan bugün konuşmak istemiyor. Satırı buldu, parmağını üstüne koydu:',
                  ],
        _seed);
    final close = f >= 0.7
        ? 'Bugün de kolay geçsin.'
        : f >= 0.25
            ? 'Akşama kadar vaktin var.'
            : 'Bu satır bir şekilde kapanacak. Nasıl kapanacağı senin elinde değil, '
                'ne kadar acıyacağı senin elinde.';
    return '$opener\n"${d.label}." ${d.bite} $close';
  }

  String get _favorWord {
    final f = widget.favor;
    if (f >= 0.7) return 'adın temiz sayfada duruyor';
    if (f >= 0.45) return 'adın yazılı, karşısı henüz boş';
    if (f >= 0.25) return 'adının karşısına bir çentik atılmış';
    return 'adın, silinmiş köylerin arasına yazılmış';
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
                      Text(_haggling ? 'Pazarlık masası' : 'Defter açıldı',
                          style: AppUi.title.copyWith(fontSize: 18)),
                      const SizedBox(height: 10),
                      Text(
                        _commanderLine,
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
        Text('İmparatorluğun defterinde $_favorWord.',
            style: AppUi.body.copyWith(fontSize: 10.5, color: AppUi.textLo)),
      ],
    );
  }

  List<Widget> _mainOptions(ImperialDemand d) {
    return [
      if (d.isConscript) ...[
        _opt('Genci teslim et', 'Kolona katılır ve bir daha dönmez. Köy yas tutar.',
            AppUi.textMid, widget.onAccept),
        _opt(
            'Altınla kurtar · ${widget.ransomCost}★',
            widget.canRansom
                ? 'Keseyi tart, çocuğu bırak. İtibar da biraz kazanılır.'
                : 'Kese bu kadarını kaldırmıyor.',
            AppUi.gold,
            widget.canRansom ? widget.onRansom : null),
      ] else ...[
        _opt(
            'Tam öde · ${d.amount}${d.icon}',
            widget.canAcceptFull
                ? 'Rakamı sorgusuz kapat. En güvenli yol; itibarın yükselir.'
                : 'Elindeki yetmiyor. Ne bulurlarsa onu alırlar.',
            AppUi.sage,
            widget.onAccept),
        _opt('Pazarlık et', 'Daha düşük bir sayı söyle. İtibarın yüksekse tutar.',
            AppUi.accent, () => setState(() => _haggling = true)),
      ],
      const SizedBox(height: 8),
      // Direniş — yalnız köy yeterince güçlüyse (muhafız/kalabalık). Başarı
      // şansı AÇIKÇA gösterilir (#7 saydamlık): körlemesine kumar değil.
      if (widget.resistChance > 0)
        _opt(
            'Diren ve kov  ·  %${(widget.resistChance * 100).round()} başarı',
            'Muhafızlar eşiğe dizilir. Tutarsa kimse ölmez, köy başını dik tutar; '
                'tutmazsa ilk düşenler onlar olur.',
            AppUi.accent,
            widget.onResist),
      _opt('Reddet', 'Hiçbir şey verme. Bedeli komutan kendi eliyle toplar.',
          AppUi.rust, widget.onRefuse),
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
                ? '✓ İtibarın bu sayıyı taşır. Kalemi büyük ihtimalle çizer.'
                : '⚠ Bu sayı komutanı güldürür. Reddederse rakamın tamamını ödersin.',
            f >= threshold ? AppUi.sage : AppUi.rust,
            () => widget.onHaggle(f)),
      const SizedBox(height: 8),
      _opt('Vazgeç', 'Ağzını açma. Baştaki seçeneklere dön.', AppUi.textLo,
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
