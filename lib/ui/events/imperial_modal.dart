import 'package:flutter/material.dart';
import '../systems/imperial.dart';
import '../systems/imperial_raid.dart';
import '../systems/regime.dart';
import 'app_ui.dart';
import 'gameplay_dioramas.dart';
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
  final int wood;
  final String raidTitle;
  final String raidIntel;
  final ImperialRaidScenario? raidScenario;

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
  final void Function(ImperialDefensePlan plan)? onDefensePlan;

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
    this.wood = 0,
    this.raidTitle = 'Sınır Baskısı',
    this.raidIntel = '',
    this.raidScenario,
    this.haggleEase = 0,
    this.postureNote = '',
    this.councilVerdict,
    this.councilLine = '',
    required this.onAccept,
    required this.onRefuse,
    required this.onRansom,
    required this.onHaggle,
    required this.onResist,
    this.onDefensePlan,
  });

  @override
  State<ImperialModal> createState() => _ImperialModalState();
}

class _ImperialModalState extends State<ImperialModal> {
  bool _haggling = false;
  bool _planningDefense = false;

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
  List<Widget> _narrative(ImperialDemand demand, {bool compact = false}) => [
    Row(
      children: [
        GameIcon(GameIconData.bow, size: compact ? 18 : 22, color: AppUi.rust),
        SizedBox(width: compact ? 7 : 10),
        Flexible(
          child: Text(
            'İMPARATORLUK HEYETİ',
            style: AppUi.label.copyWith(color: AppUi.rust),
          ),
        ),
      ],
    ),
    SizedBox(height: compact ? 4 : 8),
    Text(
      _haggling ? 'Pazarlık masası' : widget.raidTitle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppUi.title.copyWith(fontSize: compact ? 16 : 18),
    ),
    if (!_haggling && widget.raidIntel.isNotEmpty) ...[
      SizedBox(height: compact ? 3 : 5),
      Text(
        widget.raidIntel,
        maxLines: compact ? 1 : 3,
        overflow: TextOverflow.ellipsis,
        style: AppUi.body.copyWith(
          fontSize: compact ? 9.5 : 10.5,
          height: compact ? 1.2 : 1.35,
          color: AppUi.rust,
        ),
      ),
    ],
    SizedBox(height: compact ? 5 : 9),
    ImperialDemandDiorama(
      demand: demand,
      fraction: 1,
      favor: widget.favor,
      guards: widget.defensePreview.guards,
      height: compact ? 96 : 154,
    ),
    SizedBox(height: compact ? 5 : 9),
    Text(
      _haggling ? 'Komutan kalemi bıraktı. Teklifini bekliyor.' : demand.bite,
      maxLines: compact ? 2 : 3,
      overflow: TextOverflow.ellipsis,
      style: AppUi.body.copyWith(
        fontSize: compact ? 10.5 : 11.5,
        height: compact ? 1.25 : 1.4,
      ),
    ),
    SizedBox(height: compact ? 5 : 9),
    _favorBar(compact: compact),
    if (widget.postureNote.isNotEmpty || widget.councilVerdict != null) ...[
      SizedBox(height: compact ? 5 : 10),
      _regimeBanner(compact: compact),
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
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _narrative(d, compact: true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(width: 1, color: AppUi.line),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 4,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_haggling)
                              ..._haggleOptions(d)
                            else if (_planningDefense)
                              ..._defensePlanOptions()
                            else
                              ..._mainOptions(d),
                          ],
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
        constraints: const BoxConstraints(maxWidth: 760),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(26),
          child: AppReveal(
            child: AppPanel(
              accent: AppUi.rust,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 300,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: _narrative(d),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Container(width: 1, height: 330, color: AppUi.line),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: _haggling
                          ? _haggleOptions(d)
                          : _planningDefense
                          ? _defensePlanOptions()
                          : _mainOptions(d),
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

  Widget _favorBar({bool compact = false}) {
    final lit = (widget.favor.clamp(0.0, 1.0) * 5).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < 5; i++) ...[
              Container(
                width: compact ? 12 : 15,
                height: compact ? 12 : 15,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < lit ? _favorColor : AppUi.surface1,
                  border: Border.all(color: i < lit ? _favorColor : AppUi.line),
                ),
                child: i < lit
                    ? const Center(
                        child: Text('•', style: TextStyle(fontSize: 8)),
                      )
                    : null,
              ),
              if (i != 4) SizedBox(width: compact ? 3 : 5),
            ],
            SizedBox(width: compact ? 6 : 9),
            Text(
              'İTİBAR',
              style: AppUi.label.copyWith(
                color: _favorColor,
                fontSize: compact ? 8 : null,
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 2 : 4),
        Text(
          _favorWord,
          maxLines: compact ? 1 : null,
          overflow: compact ? TextOverflow.ellipsis : null,
          style: AppUi.body.copyWith(
            fontSize: compact ? 9.5 : 10.5,
            color: AppUi.textLo,
          ),
        ),
      ],
    );
  }

  /// REJİM BANDI — köyün dış-güç duruşu + (hür rejimde) meclisin önerisi.
  /// Bu, imparatorluk masasının iç yönetişimle kesiştiği yer: baskı köyünde
  /// söz tek elden senindir, hür köyde meclis bir duruş gösterir ve dışına
  /// çıkmak meşruiyet yer.
  Widget _regimeBanner({bool compact = false}) {
    return Container(
      width: double.infinity,
      padding: compact
          ? const EdgeInsets.fromLTRB(8, 6, 8, 6)
          : const EdgeInsets.fromLTRB(12, 10, 12, 11),
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
              maxLines: compact ? 1 : null,
              overflow: compact ? TextOverflow.ellipsis : null,
              style: AppUi.body.copyWith(
                fontSize: compact ? 9.5 : 11,
                height: compact ? 1.2 : 1.4,
                color: AppUi.textMid,
              ),
            ),
          if (widget.councilVerdict != null) ...[
            if (widget.postureNote.isNotEmpty)
              SizedBox(height: compact ? 3 : 7),
            Text(
              '🏛 ${widget.councilLine}',
              maxLines: compact ? 1 : null,
              overflow: compact ? TextOverflow.ellipsis : null,
              style: AppUi.bodyHi.copyWith(
                fontSize: compact ? 9.5 : 11.5,
                height: compact ? 1.2 : 1.4,
                color: AppUi.accent,
              ),
            ),
            if (!compact) ...[
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
        if (!useCompactGameUi(context)) _defensePanel(),
        _opt(
          'Savunmayı seç  ·  %${(widget.resistChance * 100).round()} başarı',
          'Köyün eşikte nasıl dövüşeceğini belirle.',
          AppUi.accent,
          widget.onDefensePlan == null
              ? widget.onResist
              : () => setState(() => _planningDefense = true),
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

  List<Widget> _defensePlanOptions() {
    final plans = [
      for (final plan in ImperialDefensePlan.values)
        imperialPlanPreview(
          plan: plan,
          defense: widget.defensePreview,
          wood: widget.wood,
        ),
    ];
    return [
      Text('SAVUNMA DÜZENİ', style: AppUi.label.copyWith(color: AppUi.accent)),
      const SizedBox(height: 3),
      Text(
        'Seçtiğin düzen yalnız oranı değil, yenilginin can bedelini de değiştirir.',
        style: AppUi.body.copyWith(fontSize: 10.5, color: AppUi.textLo),
      ),
      for (final p in plans)
        _opt(
          '${p.plan.title}  ·  %${(_scenarioChance(p) * 100).round()}',
          '${p.plan.detail}${p.woodCost > 0 ? '  Bedel: ${p.woodCost}🪵.' : ''}',
          p.available ? AppUi.accent : AppUi.textLo,
          p.available ? () => widget.onDefensePlan!(p.plan) : null,
          defies: _defies(ImperialVerdict.resist),
        ),
      const SizedBox(height: 8),
      _opt(
        'Geri dön',
        'Henüz mızraklar inmedi.',
        AppUi.textLo,
        () => setState(() => _planningDefense = false),
      ),
    ];
  }

  double _scenarioChance(ImperialPlanPreview preview) {
    final raid = widget.raidScenario;
    if (raid == null) return preview.chance;
    final planBonus = switch (preview.plan) {
      ImperialDefensePlan.holdLine => raid.holdBonus,
      ImperialDefensePlan.barricade => raid.barricadeBonus,
      ImperialDefensePlan.counterCharge => raid.chargeBonus,
    };
    return (preview.chance + planBonus - raid.attackDelta).clamp(.02, .95);
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
                    const GameIcon(
                      GameIconData.axe,
                      size: 16,
                      color: AppUi.accentSoft,
                    ),
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
    final compact = useCompactGameUi(context);
    return Padding(
      padding: EdgeInsets.only(top: compact ? 5 : 8),
      child: GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: disabled ? 0.5 : 1.0,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 10 : 14,
              vertical: compact ? 7 : 11,
            ),
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppUi.bodyHi.copyWith(
                          fontSize: compact ? 12 : 13.5,
                        ),
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
                  maxLines: compact ? 1 : null,
                  overflow: compact ? TextOverflow.ellipsis : null,
                  style: AppUi.body.copyWith(
                    fontSize: compact ? 9.5 : 10.5,
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
