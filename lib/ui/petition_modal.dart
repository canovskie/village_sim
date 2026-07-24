import 'dart:math';
import 'package:flutter/material.dart';
import '../systems/petition_system.dart';
import '../entities/villager_entity.dart';
import '../characters/villager_type.dart';
import '../characters/life_stage.dart';
import '../rendering/portrait_renderer.dart';
import 'app_ui.dart';
import 'option_scene_card.dart';
import 'petition_scene_card.dart';

/// Köyden gelen bir ricanın oyuncu-yüzlü karşılığı — Meclis önüne gelen
/// dilekçe. Modern koyu panel diline (AppUi) oturur: rafine yüzey, tek sıcak
/// vurgu, güçlü tipografi hiyerarşisi (dilekçe metni → sunan zümre → seçenekler
/// → sonuçlar). Ambient — boşluğa dokununca kapanır ([onDismiss]), dilekçe
/// bekleyen kalır (HUD rozeti durur). [onChoose] kararı uygular.
class PetitionModal extends StatelessWidget {
  final Petition petition;
  /// Karar anındaki köy durumu — bağlam şeridinde gösterilir (oyuncu
  /// moral/nüfus/yiyecek/altını görerek karar versin). null = şerit gizli.
  final ({double morale, int population, int food, int gold})? state;
  final void Function(PetitionOption) onChoose;
  final VoidCallback onDismiss;

  /// Mühlet doldu → zorunlu huzur: boşluğa dokunarak kapatılamaz, köy yanıt
  /// bekliyor (sim duraklı). Backdrop dismiss kapalı + ipucu yerine uyarı.
  final bool forced;

  /// Dilekçeyi getiren gerçek köylü — portre + ad + meslek gösterilir. null ise
  /// eski stil glif + zümre adı kullanılır.
  final VillagerEntity? author;
  /// Portreye/yazara dokununca — bilgi & aile paneli açılır.
  final VoidCallback? onAuthorTap;

  /// Hero künyesi — köyden gelen dilekçe için 'DİLEKÇE', oyuncunun çağırdığı
  /// proaktif meclis oturumu için 'MECLİS'. Aynı pano iki bağlamı taşır.
  final String kicker;
  /// Alt ipucu (ambient kapatma) — bağlama göre değişir ("kararı sonraya bırak"
  /// / "meclisi dağıt"). forced iken gösterilmez.
  final String dismissHint;

  /// VETO — hür rejimde oyuncunun kaba kuvveti: dilekçe hiç karara bağlanmadan
  /// düşer, meşruiyet bedeli ödenir (bkz. scene_regime._vetoPetition).
  /// null = veto yok (baskı rejiminde zaten söz senin; ılımlı köyde gereksiz).
  final VoidCallback? onVeto;

  /// Veto düğmesinin altına yazılan bedel — "moral düşer, haneler küser".
  final String vetoNote;

  const PetitionModal({
    super.key,
    required this.petition,
    this.state,
    required this.onChoose,
    required this.onDismiss,
    this.forced = false,
    this.author,
    this.onAuthorTap,
    this.kicker = 'DİLEKÇE',
    this.dismissHint = 'boşluğa dokun — kararı sonraya bırak',
    this.onVeto,
    this.vetoNote = '',
  });

  /// VETO satırı — seçeneklerin ALTINDA, bilerek sönük: bu bir şık değil,
  /// şıkları reddetmek. Meşruiyeti olan bir rejimde bunun bir faturası var.
  Widget _vetoRow() => GestureDetector(
        onTap: onVeto,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppUi.radiusSm),
            border: Border.all(color: AppUi.rust.withValues(alpha: 0.35)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('✋  DİLEKÇEYİ REDDET',
                  style: AppUi.label.copyWith(
                      fontSize: 9.5, color: AppUi.rust, letterSpacing: 1.3)),
              if (vetoNote.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(vetoNote,
                    textAlign: TextAlign.center,
                    style: AppUi.body
                        .copyWith(fontSize: 9.5, color: AppUi.textLo)),
              ],
            ],
          ),
        ),
      );

  /// Dilekçe tonuna göre vurgu rengi — etiket/stakes/aksan renklendirmesi.
  Color get _toneAccent => switch (petition.tone) {
        PetitionTone.warm => AppUi.sage,
        PetitionTone.solemn => AppUi.textMid,
        PetitionTone.ominous => AppUi.rust,
        PetitionTone.neutral => AppUi.accent,
      };

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Arkayı karart. Ambient'te boşluğa dokun = kapat; zorunlu huzurda
        // (mühlet doldu) dokunuş kapatmaz — köy yanıt bekliyor, koyu scrim.
        Positioned.fill(
          child: GestureDetector(
            onTap: forced ? null : onDismiss,
            child: ColoredBox(
                color: forced ? const Color(0xF20E0A06) : AppUi.scrim),
          ),
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 516),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              // Modalın içine dokununca arkadaki dismiss tetiklenmesin.
              child: GestureDetector(
                onTap: () {},
                child: AppReveal(
                  child: _GildedFrame(
                    accent: _toneAccent,
                    // Hero illüstrasyon panelin tam genişliğini kaplasın diye
                    // panelin kendi padding'i sıfır; iç bloklar kendi boşluğunu verir.
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ── HERO: sinematik illüstrasyon + madalyon portre +
                        // oyma başlık (Total War ikilem panosu) ──────────────
                        _PetitionHero(
                          petition: petition,
                          accent: _toneAccent,
                          author: author,
                          onAuthorTap: onAuthorTap,
                          kicker: kicker,
                        ),
                        // ── Gövde + kararlar bloğu ───────────────────────────
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Stakes = vurucu tek-satır gerilim (varsa başrol).
                              if (petition.stakes != null) ...[
                                _StakesLine(
                                    text: petition.stakes!, accent: _toneAccent),
                                const SizedBox(height: 10),
                              ],
                              // Gövde — ikincil, kısa flavor (metin minimumda).
                              Text(
                                petition.body,
                                textAlign: TextAlign.center,
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                style: AppUi.body.copyWith(
                                    fontSize: 11,
                                    height: 1.5,
                                    color: AppUi.textLo),
                              ),
                              if (state != null) ...[
                                const SizedBox(height: 12),
                                _VillageStateStrip(state: state!),
                              ],
                              const SizedBox(height: 14),
                              // Kararlar YATAY kart şeridi — her kart eylemi
                              // canlandıran 2B sahneyle taçlanır (Reigns/Total
                              // War kart hissi). 2 seçenekte yan yana sığar,
                              // 4-5'te yatay kaydırılır.
                              _OptionStrip(
                                options: petition.options,
                                accent: _toneAccent,
                                onChoose: onChoose,
                              ),
                              if (onVeto != null) ...[
                                const SizedBox(height: 10),
                                _vetoRow(),
                              ],
                              const SizedBox(height: 12),
                              // Ambient'te ertelenebilir; zorunlu huzurda köy
                              // yanıt bekler (kapatılamaz) — ipucu yerine uyarı.
                              forced
                                  ? Text('mühlet doldu — köy yanıtını bekliyor',
                                      textAlign: TextAlign.center,
                                      style: AppUi.label.copyWith(
                                          color: AppUi.rust,
                                          fontSize: 9,
                                          letterSpacing: 1.0))
                                  : Text(dismissHint,
                                      style: AppUi.label.copyWith(
                                          fontSize: 8.5, letterSpacing: 1.0)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// İnce altın oyma çerçeveli koyu pano — Total War panolarının "imparatorluk"
/// ağırlığını AppUi koyu diliyle verir: ince metalik kenar + içte hairline +
/// yumuşak gölge. Parşömen/ahşap YOK (UI cilalı kalır). Hero illüstrasyonu
/// köşelere kadar yaslar (kendi clip'i var).
class _GildedFrame extends StatelessWidget {
  final Widget child;
  final Color accent;
  const _GildedFrame({required this.child, required this.accent});

  @override
  Widget build(BuildContext context) {
    const r = AppUi.radius;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppUi.surface2, AppUi.surface1],
        ),
        borderRadius: BorderRadius.circular(r),
        // İnce altın metalik kenar (üst parlak → alt sönük → ince çizgi hissi).
        border: Border.all(color: AppUi.gold.withValues(alpha: 0.32), width: 1.2),
        boxShadow: [
          ...AppUi.softShadow,
          BoxShadow(color: accent.withValues(alpha: 0.16), blurRadius: 26),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: Stack(
          children: [
            child,
            // İçte ince altın hairline — "oyma" derinliği (IgnorePointer: tıklamayı engellemesin).
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  margin: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(r - 4),
                    border: Border.all(
                        color: AppUi.gold.withValues(alpha: 0.12), width: 1),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dilekçe HERO bloğu — illüstrasyon panosu + üstte DİLEKÇE künyesi/not, altta
/// gradient zemin üstüne madalyon portre + oyma başlık + sunan. Total War olay
/// panosunun "tek nefeste oku" hissi: resim konuşur, yazı asgaridir.
class _PetitionHero extends StatelessWidget {
  final Petition petition;
  final Color accent;
  final VillagerEntity? author;
  final VoidCallback? onAuthorTap;
  final String kicker;
  const _PetitionHero({
    required this.petition,
    required this.accent,
    this.author,
    this.onAuthorTap,
    this.kicker = 'DİLEKÇE',
  });

  @override
  Widget build(BuildContext context) {
    final a = author;
    return SizedBox(
      height: 196,
      child: Stack(
        children: [
          // Full-bleed prosedürel illüstrasyon (kendi kenarlığını çizmez).
          Positioned.fill(
            child: PetitionSceneCard(
              petition: petition,
              height: 196,
              drawBorder: false,
            ),
          ),
          // Alt okunaklılık zemini — başlık/portre için koyu gradient.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 116,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0xE6100E0B)],
                  ),
                ),
              ),
            ),
          ),
          // Üst künye şeridi: DİLEKÇE etiketi + (varsa) bağlam notu rozeti.
          Positioned(
            left: 14,
            right: 14,
            top: 12,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kicker(kicker),
                const Spacer(),
                if (petition.note != null)
                  Flexible(
                    // AppChip DEĞİL: chip'in Text'i kırpılmadığı için uzun not
                    // hero satırını taşırıyordu (RenderFlex overflow). Bu rozet
                    // ellipsis yapar → dar hero'da güvenle sığar.
                    child: _noteChip(
                        petition.note!,
                        petition.note!.startsWith('✦')
                            ? AppUi.gold
                            : AppUi.rust),
                  ),
              ],
            ),
          ),
          // Alt blok: madalyon portre/glif + başlık + sunan.
          Positioned(
            left: 14,
            right: 14,
            bottom: 12,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (a != null)
                  GestureDetector(
                    onTap: onAuthorTap,
                    child: _Medallion.portrait(a, accent),
                  )
                else
                  _Medallion.glyph(petition.icon, accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(petition.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppUi.title.copyWith(
                            fontSize: 18,
                            height: 1.08,
                            shadows: const [
                              Shadow(color: Color(0xCC000000), blurRadius: 8)
                            ],
                          )),
                      const SizedBox(height: 3),
                      if (a != null)
                        GestureDetector(
                          onTap: onAuthorTap,
                          child: Text(
                            '${a.isMale ? '♂' : '♀'} ${a.name} · ${a.hasProfession ? a.type.displayName : a.lifeStage.label}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppUi.body.copyWith(
                                fontSize: 11,
                                color: accent,
                                fontWeight: FontWeight.w700),
                          ),
                        )
                      else
                        Text(petition.petitioner,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppUi.body
                                .copyWith(fontSize: 11, color: AppUi.textMid)),
                      // Yazar hanesi adına konuşur — politik katman hane-bazlı.
                      if (a != null && a.houseLabel.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text('⌂ ${a.houseLabel} adına',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppUi.body.copyWith(
                                fontSize: 10,
                                color: AppUi.textMid,
                                fontStyle: FontStyle.italic)),
                      ],
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

  Widget _kicker(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xB3100E0B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: 0.55), width: 1),
        ),
        child: Text(text,
            style: AppUi.label.copyWith(color: accent, fontSize: 9)),
      );

  /// Hero not rozeti — AppChip'in kırpılmayan Text'i yerine ellipsis'li sürüm
  /// (uzun bağlam notu dar hero satırını taşırmasın).
  Widget _noteChip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.7), width: 1),
        ),
        child: Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppUi.button.copyWith(
              fontSize: 9.5,
              letterSpacing: 1.0,
              color: AppUi.textHi,
            )),
      );
}

/// Hero üzerindeki dairesel madalyon — dilekçeyi getiren köylünün portresi ya
/// da (yazar yoksa) konu glifi. İnce altın halka + ton-aksanlı dış glow ile
/// illüstrasyonun alt kenarına oturur (Total War portre madalyonu hissi).
/// Portre varyantında dokununca bilgi/aile paneli açılır (modal sarar).
class _Medallion extends StatelessWidget {
  final VillagerEntity? villager;
  final String? glyph;
  final Color accent;
  const _Medallion._({this.villager, this.glyph, required this.accent});

  factory _Medallion.portrait(VillagerEntity v, Color accent) =>
      _Medallion._(villager: v, accent: accent);
  factory _Medallion.glyph(String icon, Color accent) =>
      _Medallion._(glyph: icon, accent: accent);

  static const double _size = 60;

  @override
  Widget build(BuildContext context) {
    final v = villager;
    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppUi.surface0,
        // Çift halka: dış ince altın + iç ton-aksan (oyma madalyon hissi).
        border: Border.all(color: AppUi.gold.withValues(alpha: 0.55), width: 1.6),
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: 0.45), blurRadius: 14),
          const BoxShadow(color: Color(0x99000000), blurRadius: 6),
        ],
      ),
      padding: const EdgeInsets.all(2),
      child: ClipOval(
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: accent.withValues(alpha: 0.8), width: 1.2),
          ),
          child: ClipOval(
            child: v != null
                ? CustomPaint(
                    painter: PortraitPainter(
                      visual: v.visual,
                      stage: v.lifeStage,
                      type: v.type,
                      hasProfession: v.hasProfession,
                    ),
                  )
                : Center(
                    child: Text(glyph ?? '📜',
                        style: const TextStyle(fontSize: _size * 0.44)),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Köy durumu şeridi — karar anında moral/nüfus/yiyecek/altın özeti. Oyuncu
/// dilekçeyi köyün gerçek hâliyle tartar. Koyu iç band.
class _VillageStateStrip extends StatelessWidget {
  final ({double morale, int population, int food, int gold}) state;
  const _VillageStateStrip({required this.state});

  /// Morale göre yüz — köyün ruh hâlinin tek bakışta okunması.
  String get _moraleFace {
    final m = state.morale;
    if (m >= 0.75) return '😄';
    if (m >= 0.55) return '🙂';
    if (m >= 0.35) return '😐';
    if (m >= 0.2) return '🙁';
    return '😣';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppUi.surface0,
        borderRadius: BorderRadius.circular(AppUi.radiusSm),
        border: Border.all(color: AppUi.line, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _cell(emoji: _moraleFace, value: '${(state.morale * 100).round()}%',
              label: 'moral', color: AppUi.accent),
          _div(),
          _cell(icon: GameIconData.people, value: '${state.population}',
              label: 'nüfus', color: AppUi.textMid),
          _div(),
          _cell(icon: GameIconData.wheat, value: '${state.food}',
              label: 'yiyecek', color: AppUi.sage),
          _div(),
          _cell(icon: GameIconData.coin, value: '${state.gold}',
              label: 'altın', color: AppUi.gold),
        ],
      ),
    );
  }

  Widget _div() => Container(width: 1, height: 24, color: AppUi.line);

  Widget _cell({
    GameIconData? icon,
    String? emoji,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emoji != null)
              Text(emoji, style: const TextStyle(fontSize: 12))
            else if (icon != null)
              GameIcon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(value, style: AppUi.number.copyWith(fontSize: 13)),
          ],
        ),
        const SizedBox(height: 2),
        Text(label,
            style: AppUi.label.copyWith(fontSize: 7.5, letterSpacing: 0.8)),
      ],
    );
  }
}

/// "Ne pahasına" gerilim satırı — kararın özünü tek nefeste verir (gövdeyi
/// okumadan neyin tehlikede olduğunu sezdirir). İnce altın "‹ ›" işaretleri
/// arasında ortalı, ton renginde ışıyan band.
class _StakesLine extends StatelessWidget {
  final String text;
  final Color accent;
  const _StakesLine({required this.text, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          accent.withValues(alpha: 0.04),
          accent.withValues(alpha: 0.16),
          accent.withValues(alpha: 0.04),
        ]),
        borderRadius: BorderRadius.circular(AppUi.radiusSm),
        border: Border.all(color: accent.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GameIcon(GameIconData.scroll, size: 13, color: accent),
          const SizedBox(width: 9),
          Flexible(
            child: Text(text,
                textAlign: TextAlign.center,
                style: AppUi.body.copyWith(
                    fontSize: 11.5,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                    color: AppUi.textHi)),
          ),
        ],
      ),
    );
  }
}

/// Kararlar YATAY kart şeridi. Her seçenek eylemini canlandıran 2B sahneyle
/// taçlanmış bir kart (Reigns/Total War hissi). Az seçenek (2) ortalanır ve
/// panele yayılır; çok seçenek (4-5) yatay kaydırılır — kenarda soluk bir
/// gradyan "devamı var" der.
class _OptionStrip extends StatefulWidget {
  final List<PetitionOption> options;
  final Color accent;
  final void Function(PetitionOption) onChoose;
  const _OptionStrip({
    required this.options,
    required this.accent,
    required this.onChoose,
  });
  @override
  State<_OptionStrip> createState() => _OptionStripState();
}

class _OptionStripState extends State<_OptionStrip> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final opts = widget.options;
    // 3'e kadar seçenek panele sığar → yay (Expanded). Fazlası kaydırılır.
    final fits = opts.length <= 3;

    Widget card(PetitionOption o) => _OptionCard(
          option: o,
          accent: widget.accent,
          onTap: () => widget.onChoose(o),
        );

    if (fits) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int i = 0; i < opts.length; i++) ...[
              Expanded(child: card(opts[i])),
              if (i != opts.length - 1) const SizedBox(width: 9),
            ],
          ],
        ),
      );
    }

    // Kaydırmalı şerit — sabit kart genişliği + kenar "devamı var" ipucu.
    return SizedBox(
      height: 214,
      child: ShaderMask(
        shaderCallback: (rect) => const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0x00000000),
            Color(0xFFFFFFFF),
            Color(0xFFFFFFFF),
            Color(0x00000000),
          ],
          stops: [0.0, 0.035, 0.965, 1.0],
        ).createShader(rect),
        blendMode: BlendMode.dstIn,
        child: ListView.separated(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          itemCount: opts.length,
          separatorBuilder: (_, _) => const SizedBox(width: 9),
          itemBuilder: (_, i) => SizedBox(width: 156, child: card(opts[i])),
        ),
      ),
    );
  }
}

/// Tek karar kartı — üstte eylemi canlandıran 2B sahne (bağışla/cezalandır/
/// sür/idam/kürek), altında başlık + kısa flavor + SONUÇ ikon tabletleri.
/// Hover'da ton-aksanlı kenar + parıltı; dokun = kararı uygula.
class _OptionCard extends StatefulWidget {
  final PetitionOption option;
  final Color accent;
  final VoidCallback onTap;
  const _OptionCard({
    required this.option,
    required this.accent,
    required this.onTap,
  });
  @override
  State<_OptionCard> createState() => _OptionCardState();
}

class _OptionCardState extends State<_OptionCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final o = widget.option;
    final accent = widget.accent;
    final chips = o.effectChips;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: _hover
                ? Color.alphaBlend(
                    accent.withValues(alpha: 0.12), AppUi.surface2)
                : AppUi.surface1,
            borderRadius: BorderRadius.circular(AppUi.radiusSm),
            border: Border.all(
              color: _hover ? accent : AppUi.line,
              width: _hover ? 1.5 : 1,
            ),
            boxShadow: _hover
                ? [BoxShadow(color: accent.withValues(alpha: 0.28), blurRadius: 12)]
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppUi.radiusSm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Üst: eylem sahnesi (kartın başrolü).
                Stack(
                  children: [
                    OptionSceneCard(scene: optionSceneFor(o), height: 84),
                    // Alt okunaklılık zemini (başlık sahneye binmesin).
                    const Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 34,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0x00000000), Color(0xCC14171C)],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: 7,
                      child: Text(
                        o.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppUi.bodyHi.copyWith(
                          fontSize: 13.5,
                          shadows: const [
                            Shadow(color: Color(0xCC000000), blurRadius: 6)
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(11, 8, 11, 11),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        o.detail,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppUi.body.copyWith(
                            fontSize: 10, height: 1.35, color: AppUi.textLo),
                      ),
                      if (chips.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 5,
                          runSpacing: 5,
                          children: [
                            for (final d in chips) _effectTablet(d.$1, d.$2)
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
      ),
    );
  }

  /// Tek sonuç tableti — ikon + delta, sonucun rengiyle. Kararın bedeli/faydası
  /// okunmadan görülür.
  Widget _effectTablet(String icon, String label) {
    final color = _chipColor((icon, label));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 12.5)),
          const SizedBox(width: 4),
          Text(label,
              style: AppUi.number.copyWith(fontSize: 11, color: color)),
        ],
      ),
    );
  }

  // Fayda sage / bedel rust / yasa ember — sonuç renk dili.
  Color _chipColor((String, String) d) {
    if (d.$1 == '📜') return AppUi.accent; // yasa
    if (d.$2 == '▲') return AppUi.sage; // zümre sevinir
    if (d.$2 == '▼') return AppUi.rust; // zümre küser
    return d.$2.startsWith('-') ? AppUi.rust : AppUi.sage; // negatif/pozitif
  }
}

/// HUD'da bekleyen dilekçeyi gösteren rozet — koyu kompakt panel + glif +
/// tükenen MÜHLET halkası. [progress] (1→0) kalan mühleti gösterir; halka
/// boşaldıkça akar. [urgent] (son %30) → ton kızarır, nabız hızlanır, "AZ KALDI"
/// uyarısı belirir. [tone] dilekçenin duygusal rengini halka/glow'a taşır.
class PetitionSeal extends StatefulWidget {
  final VoidCallback onTap;
  final double progress; // 1.0 = tam mühlet, 0.0 = doldu
  final bool urgent;
  final PetitionTone tone;
  const PetitionSeal({
    super.key,
    required this.onTap,
    this.progress = 1.0,
    this.urgent = false,
    this.tone = PetitionTone.neutral,
  });
  @override
  State<PetitionSeal> createState() => _PetitionSealState();
}

class _PetitionSealState extends State<PetitionSeal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: _pulseDur())
    ..repeat(reverse: true);

  Duration _pulseDur() =>
      Duration(milliseconds: widget.urgent ? 620 : 1500);

  @override
  void didUpdateWidget(PetitionSeal old) {
    super.didUpdateWidget(old);
    // Sıkışmaya geçince nabız hızlanır (ve tersi) — controller süresini güncelle.
    if (old.urgent != widget.urgent) {
      _ctrl.duration = _pulseDur();
      _ctrl
        ..reset()
        ..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _toneAccent => switch (widget.tone) {
        PetitionTone.warm => AppUi.sage,
        PetitionTone.solemn => AppUi.textMid,
        PetitionTone.ominous => AppUi.rust,
        PetitionTone.neutral => AppUi.accent,
      };

  @override
  Widget build(BuildContext context) {
    // Sıkışmada her şey rust'a kayar (aciliyet rengi), değilse tonun rengi.
    final accent = widget.urgent ? AppUi.rust : _toneAccent;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final t = _ctrl.value;
            final glow =
                (widget.urgent ? 0.30 : 0.22) + t * (widget.urgent ? 0.46 : 0.34);
            final scale = 1.0 + t * (widget.urgent ? 0.06 : 0.04);
            return Transform.scale(
              scale: scale,
              // İnce altın çerçeveli koyu "dispatch" rozeti — modalın gilded
              // diliyle aynı: gold metalik kenar + ton-aksanlı glow + gradient.
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 7, 14, 7),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppUi.surface2, AppUi.surface1],
                  ),
                  borderRadius: BorderRadius.circular(AppUi.radius),
                  border: Border.all(
                      color: AppUi.gold.withValues(alpha: 0.34), width: 1.1),
                  boxShadow: [
                    ...AppUi.softShadow,
                    BoxShadow(
                        color: accent.withValues(alpha: glow),
                        blurRadius: widget.urgent ? 20 : 15,
                        spreadRadius: 1),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Mühür madalyonu + çevresinde tükenen mühlet halkası.
                    SizedBox(
                      width: 42,
                      height: 42,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: const Size(42, 42),
                            painter: _MuhletRing(
                                progress: widget.progress, accent: accent),
                          ),
                          _SealMedallion(accent: accent),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('DİLEKÇE',
                            style: AppUi.title.copyWith(
                                fontSize: 14, letterSpacing: 1.6)),
                        const SizedBox(height: 3),
                        // Durum satırı — nabız atan nokta + terse etiket.
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: accent,
                                boxShadow: [
                                  BoxShadow(
                                      color: accent.withValues(alpha: 0.5 + t * 0.4),
                                      blurRadius: 6),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                                widget.urgent
                                    ? 'AZ KALDI — yanıt bekliyor'
                                    : 'köy söz bekliyor',
                                style: AppUi.label.copyWith(
                                    color: widget.urgent
                                        ? AppUi.rust
                                        : AppUi.textLo,
                                    fontSize: 8,
                                    letterSpacing: widget.urgent ? 1.2 : 0.9)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Rozetin mühür madalyonu — dairesel koyu disk, ince altın halka + ton-aksanlı
/// iç glow, ortada balmumu-mührü glifi. Modal hero madalyonunun küçük kardeşi.
class _SealMedallion extends StatelessWidget {
  final Color accent;
  const _SealMedallion({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [
          Color.alphaBlend(accent.withValues(alpha: 0.22), AppUi.surface0),
          AppUi.surface0,
        ]),
        border: Border.all(color: AppUi.gold.withValues(alpha: 0.6), width: 1.2),
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 6),
        ],
      ),
      child: const Text('📜', style: TextStyle(fontSize: 14)),
    );
  }
}

/// Madalyonun çevresinde tükenen mühlet halkası — altın-soluk iz + kalan süreyi
/// gösteren renkli yay (tepeden saat yönünde) + yayın ucunda parlayan "saat
/// ibresi" noktası. progress 1→0 azaldıkça yay kısalır.
class _MuhletRing extends CustomPainter {
  final double progress;
  final Color accent;
  const _MuhletRing({required this.progress, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 1.8;
    final rect = Rect.fromCircle(center: c, radius: r);
    // İz — ince altın hairline (rozetin gilded diliyle uyumlu).
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..color = AppUi.gold.withValues(alpha: 0.16);
    canvas.drawCircle(c, r, track);
    final p = progress.clamp(0.0, 1.0);
    if (p <= 0) return;
    const start = -1.5707963; // -90° (tepe)
    final sweep = 6.2831853 * p;
    // Yumuşak glow alt-katmanı.
    canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.0
          ..strokeCap = StrokeCap.round
          ..color = accent.withValues(alpha: 0.30)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5));
    // Renkli yay.
    canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round
          ..color = accent);
    // Yayın ucunda parlayan ibre noktası.
    final a = start + sweep;
    final head = Offset(c.dx + r * cos(a), c.dy + r * sin(a));
    canvas.drawCircle(head, 2.4, Paint()..color = Color.lerp(accent, Colors.white, 0.5)!);
    canvas.drawCircle(
        head,
        4.5,
        Paint()
          ..color = accent.withValues(alpha: 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
  }

  @override
  bool shouldRepaint(_MuhletRing old) =>
      old.progress != progress || old.accent != accent;
}
