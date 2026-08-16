import 'package:flutter/material.dart';
import '../systems/imperial.dart';
import '../systems/regime.dart';
import '../text/voice.dart';
import 'app_ui.dart';
import 'mobile_ui.dart';

/// İmparatorluk vergi heyetiyle pazarlık modalı. Karar ZORUNLU (boşluğa
/// dokunup kaçılamaz — sim duraklı). Kaynak talebinde basit pazarlık mini-oyunu
/// (teklif kademeleri, itibara göre tutar/tutmaz); devşirmede fidye seçeneği.
class ImperialModal extends StatefulWidget {
  final ImperialDemand demand;
  final double favor; // 0..1 İmparatorlukla ilişki
  final int ransomCost; // devşirme fidyesi (altın)
  final bool canAcceptFull; // tam ödeme karşılanabiliyor mu
  final bool canRansom; // fidye karşılanabiliyor mu
  final double resistChance; // heyeti kovma başarı şansı (0 = denenemez)
  final ImperialDefensePreview defensePreview;

  // ── REJİM (bkz. systems/regime.dart) ────────────────────────────────────────
  /// Pazarlık eşiğinden düşülen — tüccar köy daha ucuza anlaşır (görüntü sahne
  /// hesabıyla birebir tutsun diye).
  final double haggleEase;

  /// Köyün rejiminden gelen dış-güç duruşu (boş = merkez, çizilmez).
  final String postureNote;

  /// Hür + köklü rejimde meclisin önerdiği duruş (null = sen karar verirsin).
  /// Öneriyle çelişen seçenekler "meşruiyet bedeli" etiketiyle işaretlenir.
  final ImperialVerdict? councilVerdict;
  final String councilLine;

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
    this.defensePreview = const ImperialDefensePreview(
      guards: 0,
      weapons: 0,
      tools: 0,
      chance: 0,
      note: 'Savunma bilgisi hazır değil.',
    ),
    this.haggleEase = 0,
    this.postureNote = '',
    this.councilVerdict,
    this.councilLine = '',
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
      _seed,
    );
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
        if (useCompactGameUi(context)) _compactBody(d) else _wideBody(d),
      ],
    );
  }

  /// Anlatı bloğu — heyetin künyesi, komutanın satırı, itibar, rejim bandı.
  List<Widget> _narrative() => [
    Row(
      children: [
        const GameIcon(GameIconData.bow, size: 22, color: AppUi.rust),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            'İMPARATORLUK HEYETİ',
            style: AppUi.label.copyWith(color: AppUi.rust),
          ),
        ),
      ],
    ),
    const SizedBox(height: 8),
    Text(
      _haggling ? 'Pazarlık masası' : 'Defter açıldı',
      style: AppUi.title.copyWith(fontSize: 18),
    ),
    const SizedBox(height: 10),
    Text(
      _commanderLine,
      style: AppUi.body.copyWith(fontSize: 12.5, height: 1.5),
    ),
    const SizedBox(height: 12),
    _favorBar(),
    if (widget.postureNote.isNotEmpty || widget.councilVerdict != null) ...[
      const SizedBox(height: 10),
      _regimeBanner(),
    ],
  ];

  /// TELEFON YATAY — solda heyetin sözü, sağda cevabın.
  ///
  /// 460dp'lik dikey kolon iPhone 11'de (896×414) hem iki yanda ~350dp ölü alan
  /// bırakıyor hem de "Tam öde / Pazarlık et / Reddet" düğmelerini ekranın
  /// altına itiyordu — vergi ültimatomunda cevap seçenekleri görünmüyordu.
  Widget _compactBody(ImperialDemand d) {
    return Builder(
      builder: (context) {
        final window = MobileUi.windowSize(context);
        return Positioned.fill(
          child: Center(
            child: SizedBox(
              width: window.width,
              height: window.height,
              child: AppReveal(
                child: AppPanel(
                  accent: AppUi.rust,
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 5,
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _narrative(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(width: 1, color: AppUi.line),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 4,
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_haggling)
                                ..._haggleOptions(d)
                              else
                                ..._mainOptions(d),
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
        );
      },
    );
  }

  Widget _wideBody(ImperialDemand d) {
    return Center(
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
                  ..._narrative(),
                  const AppDivider(),
                  if (_haggling) ..._haggleOptions(d) else ..._mainOptions(d),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _favorBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Etiket ÜSTTE, kendi satırında. AppStatBar'ın yan etiket yuvası 72dp;
        // "İMPARATORLUK İTİBARIN" oraya sığmayıp üç satıra ve kelime ORTASINDAN
        // bölünüyordu ("İMPARAT / ORLUK / İTİBARIN").
        const Text('İMPARATORLUK İTİBARIN', style: AppUi.label),
        const SizedBox(height: 6),
        AppStatBar(
          label: '',
          labelWidth: 0,
          value: widget.favor.clamp(0.0, 1.0),
          trailing: '${(widget.favor * 100).round()}%',
          color: _favorColor,
        ),
        const SizedBox(height: 4),
        Text(
          'İmparatorluğun defterinde $_favorWord.',
          style: AppUi.body.copyWith(fontSize: 10.5, color: AppUi.textLo),
        ),
      ],
    );
  }

  /// REJİM BANDI — köyün dış-güç duruşu + (hür rejimde) meclisin önerisi.
  /// Bu, imparatorluk masasının iç yönetişimle kesiştiği yer: baskı köyünde
  /// söz tek elden senindir, hür köyde meclis bir duruş gösterir ve dışına
  /// çıkmak meşruiyet yer.
  Widget _regimeBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
      decoration: BoxDecoration(
        color: AppUi.surface0,
        borderRadius: BorderRadius.circular(AppUi.radiusSm),
        border: Border.all(color: AppUi.accent.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.postureNote.isNotEmpty)
            Text(
              '⚑ ${widget.postureNote}',
              style: AppUi.body.copyWith(
                fontSize: 11,
                height: 1.4,
                color: AppUi.textMid,
              ),
            ),
          if (widget.councilVerdict != null) ...[
            if (widget.postureNote.isNotEmpty) const SizedBox(height: 7),
            Text(
              '🏛 ${widget.councilLine}',
              style: AppUi.bodyHi.copyWith(
                fontSize: 11.5,
                height: 1.4,
                color: AppUi.accent,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Başka türlü seçersen meclise rağmen karar vermiş olursun — '
              'moral ve huzur bunun bedelini öder.',
              style: AppUi.body.copyWith(
                fontSize: 9.5,
                height: 1.35,
                color: AppUi.textLo,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Bir seçenek meclisin duruşuyla çelişiyor mu — çelişiyorsa "meşruiyet
  /// bedeli" etiketi eklenir. Meclis yoksa (baskı/ılımlı rejim) hiç çizilmez.
  bool _defies(ImperialVerdict v) =>
      widget.councilVerdict != null && widget.councilVerdict != v;
  bool get _refuseDefies => widget.councilVerdict != null;

  List<Widget> _mainOptions(ImperialDemand d) {
    return [
      if (d.isConscript) ...[
        _opt(
          'Genci teslim et',
          'Kolona katılır ve bir daha dönmez. Köy yas tutar.',
          AppUi.textMid,
          widget.onAccept,
          defies: _defies(ImperialVerdict.comply),
        ),
        _opt(
          'Altınla kurtar · ${widget.ransomCost}★',
          widget.canRansom
              ? 'Keseyi tart, çocuğu bırak. İtibar da biraz kazanılır.'
              : 'Kese bu kadarını kaldırmıyor.',
          AppUi.gold,
          widget.canRansom ? widget.onRansom : null,
          defies: _defies(ImperialVerdict.comply),
        ),
      ] else ...[
        _opt(
          'Tam öde · ${d.amount}${d.icon}',
          widget.canAcceptFull
              ? 'Rakamı sorgusuz kapat. En güvenli yol; itibarın yükselir.'
              : 'Elindeki yetmiyor. Ne bulurlarsa onu alırlar.',
          AppUi.sage,
          widget.onAccept,
          defies: _defies(ImperialVerdict.comply),
        ),
        _opt(
          'Pazarlık et',
          'Daha düşük bir sayı söyle. İtibarın yüksekse tutar.',
          AppUi.accent,
          () => setState(() => _haggling = true),
          defies: _defies(ImperialVerdict.haggle),
        ),
      ],
      const SizedBox(height: 8),
      // Direniş — yalnız köy yeterince güçlüyse (muhafız/kalabalık). Başarı
      // şansı AÇIKÇA gösterilir (#7 saydamlık): körlemesine kumar değil.
      if (widget.resistChance > 0) ...[
        _defensePanel(),
        _opt(
          'Savunmayı seç  ·  %${(widget.resistChance * 100).round()} başarı',
          'Sonuç otomatik hesaplanır; çatışmayı sen yönetmezsin.',
          AppUi.accent,
          widget.onResist,
          defies: _defies(ImperialVerdict.resist),
        ),
      ],
      _opt(
        'Reddet',
        'Hiçbir şey verme. Bedeli komutan kendi eliyle toplar.',
        AppUi.rust,
        widget.onRefuse,
        defies: _refuseDefies,
      ),
    ];
  }

  Widget _defensePanel() {
    final p = widget.defensePreview;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 9),
      decoration: BoxDecoration(
        color: AppUi.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppUi.radiusSm),
        border: Border.all(color: AppUi.accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(
            'assets/combat/combat_badge.png',
            width: 46,
            height: 46,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SAVUNMA DEĞERLENDİRMESİ',
                  style: AppUi.label.copyWith(color: AppUi.accent),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Image.asset(
                      'assets/combat/defense_shield.png',
                      width: 22,
                      height: 22,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${p.guards}',
                      style: AppUi.bodyHi.copyWith(fontSize: 11),
                    ),
                    const SizedBox(width: 10),
                    Image.asset(
                      'assets/combat/imperial_sword.png',
                      width: 22,
                      height: 22,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${p.weapons}',
                      style: AppUi.bodyHi.copyWith(fontSize: 11),
                    ),
                    const SizedBox(width: 10),
                    const GameIcon(GameIconData.axe,
                        size: 16, color: AppUi.accentSoft),
                    const SizedBox(width: 3),
                    Text(
                      '${p.tools}',
                      style: AppUi.bodyHi.copyWith(fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  p.note,
                  style: AppUi.body.copyWith(fontSize: 10, color: AppUi.textLo),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _haggleOptions(ImperialDemand d) {
    // Teklif kademeleri — gerçek miktarı göster. Eşik itibara bağlı (sahnedeki
    // 0.85 - favor*0.45 ile aynı): #7 saydamlık → hangi teklifin tutacağını
    // oyuncuya açıkça göster (deneme-yanılma yerine bilinçli risk).
    const fracs = [0.5, 0.7, 0.85];
    // Eşik sahne hesabıyla birebir: itibar + REJİM kolaylığı (tüccar köy ucuza).
    final threshold = (0.85 - widget.favor * 0.45 - widget.haggleEase).clamp(
      0.0,
      1.0,
    );
    return [
      for (final f in fracs)
        _opt(
          '${(d.amount * f).round()}${d.icon} öner  (%${(f * 100).round()})',
          f >= threshold
              ? '✓ İtibarın bu sayıyı taşır. Kalemi büyük ihtimalle çizer.'
              : '⚠ Bu sayı komutanı güldürür. Reddederse rakamın tamamını ödersin.',
          f >= threshold ? AppUi.sage : AppUi.rust,
          () => widget.onHaggle(f),
        ),
      const SizedBox(height: 8),
      _opt(
        'Vazgeç',
        'Ağzını açma. Baştaki seçeneklere dön.',
        AppUi.textLo,
        () => setState(() => _haggling = false),
      ),
    ];
  }

  Widget _opt(
    String label,
    String detail,
    Color accent,
    VoidCallback? onTap, {
    bool defies = false,
  }) {
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: AppUi.bodyHi.copyWith(fontSize: 13.5),
                      ),
                    ),
                    // Meclise rağmen seçim: küçük kırmızı uyarı rozeti.
                    if (defies) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppUi.rust.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          'meşruiyet bedeli',
                          style: AppUi.label.copyWith(
                            fontSize: 7,
                            color: AppUi.rust,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: AppUi.body.copyWith(
                    fontSize: 10.5,
                    color: AppUi.textLo,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
