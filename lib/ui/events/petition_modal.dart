import 'dart:async';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../characters/life_stage.dart';
import '../../characters/villager_type.dart';
import '../../entities/villager_entity.dart';
import '../../rendering/portrait_renderer.dart';
import '../../systems/governance/petition_system.dart';
import '../core/app_ui.dart';
import '../core/mobile_ui.dart';
import '../core/semantic_icon.dart';
import 'event_artwork.dart';
import 'option_scene_card.dart';
import 'petition_scene_card.dart';

part 'petition_modal_divan.dart';
part 'petition_modal_hero.dart';
part 'petition_modal_options.dart';
part 'petition_modal_seal.dart';

String _divanUpper(String text) =>
    text.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();

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
  final String? Function(PetitionOption)? blockedReason;
  final VoidCallback onDismiss;
  final bool mustChoose;
  final String? decisionContext;

  /// Mühlet doldu → kapıda bekleyen huzur: bedel gün başına işliyor. Scrim
  /// koyulaşır + ipucu yerine uyarı yazılır; kapatma yine SERBEST (donma ve
  /// kilit yok — bekletmenin bedeli zaten dünyada işler).
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
    this.blockedReason,
    required this.onDismiss,
    this.mustChoose = false,
    this.decisionContext,
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
          Text(
            '✋  DİLEKÇEYİ REDDET',
            style: AppUi.label.copyWith(
              fontSize: 9.5,
              color: AppUi.rust,
              letterSpacing: 1.3,
            ),
          ),
          if (vetoNote.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              vetoNote,
              textAlign: TextAlign.center,
              style: AppUi.body.copyWith(fontSize: 9.5, color: AppUi.textLo),
            ),
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

  String get _displayKicker => kicker == 'DİLEKÇE' ? 'DİVAN İKİLEMİ' : kicker;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Arkayı karart. Boşluğa dokun = kapat (mühlet dolmuşsa da: kilit
        // yok, bedel dünyada işliyor); dolan mühlette scrim koyulaşır.
        Positioned.fill(
          child: GestureDetector(
            onTap: mustChoose ? () {} : onDismiss,
            child: ColoredBox(
              color: forced ? const Color(0xF20E0A06) : AppUi.scrim,
            ),
          ),
        ),
        if (useCompactGameUi(context))
          _compactBody(context)
        else
          _wideBody(context),
      ],
    );
  }

  /// TELEFON YATAY — iki sütun: solda anlatı, sağda kararlar.
  ///
  /// Eski hâl masaüstünden geliyordu: 516dp'lik DİKEY kolon, ortada yüzüyor.
  /// iPhone 11'de (896×414) bu iki şeyi birden bozuyordu — ekranın iki yanında
  /// ~340dp ölü alan kalıyor, buna karşılık 196dp'lik hero + gövde + şerit
  /// kararları ekranın ALTINA itiyordu: oyuncu bir KARAR panosunu açıp tek bir
  /// karar göremiyordu. Yatay telefonda kıt olan yükseklik, bol olan
  /// genişliktir; pano da o eksene açılır. Kararlar artık daima görünür.
  Widget _compactBody(BuildContext context) {
    final window = MobileUi.windowSize(context);
    return Positioned.fill(
      child: Center(
        child: SizedBox(
          width: window.width,
          height: window.height,
          child: GestureDetector(
            onTap: () {}, // pano içi dokunuş arkadaki dismiss'i tetiklemesin
            child: AppReveal(
              child: AppGildedFrame(
                accent: _toneAccent,
                child: _CompactDivanLife(
                  petition: petition,
                  author: author,
                  onChoose: onChoose,
                  builder: (context, life) => Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // SOL — anlatı: hero + gerilim + gövde + köyün hâli.
                      // Metin kaymaz; telefon bütçesine göre satır sınırlarıyla
                      // tek bakışta okunur.
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _PetitionHero(
                              petition: petition,
                              accent: _toneAccent,
                              author: author,
                              onAuthorTap: onAuthorTap,
                              kicker: _displayKicker,
                              height: 108,
                              portraitKey: life.portraitKey,
                              portraitLookOffset: life.lookOffset,
                              portraitExpression: life.expression,
                              portraitBlink: life.blink,
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(9, 7, 9, 7),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (petition.stakes != null) ...[
                                      _StakesLine(
                                        text: petition.stakes!,
                                        accent: _toneAccent,
                                        compact: true,
                                      ),
                                      const SizedBox(height: 5),
                                    ],
                                    Text(
                                      petition.body,
                                      textAlign: TextAlign.center,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppUi.body.copyWith(
                                        fontSize: 11,
                                        height: 1.35,
                                        color: AppUi.textLo,
                                      ),
                                    ),
                                    if (state != null) ...[
                                      const SizedBox(height: 6),
                                      _VillageStateStrip(
                                        state: state!,
                                        compact: true,
                                      ),
                                    ],
                                    if (decisionContext != null) ...[
                                      const SizedBox(height: 6),
                                      _DecisionContext(
                                        text: decisionContext!,
                                        compact: true,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, color: AppUi.line),
                      // SAĞ — kararların tamamı sabit ızgarada aynı anda görünür.
                      Expanded(
                        flex: 4,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 9, 10, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: _OptionStrip(
                                  options: petition.options,
                                  accent: _toneAccent,
                                  onChoose: life.choose,
                                  onPressChange: life.pressOption,
                                  blockedReason: blockedReason,
                                  vertical: true,
                                ),
                              ),
                              if (onVeto != null) ...[
                                const SizedBox(height: 8),
                                _vetoRow(),
                              ],
                              const SizedBox(height: 7),
                              mustChoose
                                  ? Text(
                                      'Bu ilk kaynak kararını sen vereceksin',
                                      textAlign: TextAlign.center,
                                      style: AppUi.label.copyWith(
                                        color: AppUi.accent,
                                        fontSize: 9,
                                        letterSpacing: 1.0,
                                      ),
                                    )
                                  : forced
                                  ? Text(
                                      'mühlet doldu; bekletmenin bedeli işliyor',
                                      textAlign: TextAlign.center,
                                      style: AppUi.label.copyWith(
                                        color: AppUi.rust,
                                        fontSize: 9,
                                        letterSpacing: 1.0,
                                      ),
                                    )
                                  : Text(
                                      dismissHint,
                                      textAlign: TextAlign.center,
                                      style: AppUi.label.copyWith(
                                        fontSize: 8.5,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
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
        ),
      ),
    );
  }

  /// MASAÜSTÜ — çizilen Divan taslağının gerçek oyun karşılığı: dilekçeyi
  /// getiren insan solda, hüküm kartları sağda. Artık dar/dikey bir modal
  /// değil; köy dünyasının ortasına kurulan geniş bir karar masası.
  Widget _wideBody(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final panelWidth = min(1180.0, constraints.maxWidth - 40);
          final panelHeight = min(680.0, constraints.maxHeight - 40);
          final dense = panelHeight < 610;
          return Center(
            child: SizedBox(
              width: panelWidth,
              height: panelHeight,
              child: GestureDetector(
                onTap: () {},
                child: AppReveal(
                  child: AppGildedFrame(
                    accent: _toneAccent,
                    child: Column(
                      children: [
                        Expanded(
                          child: _DivanDecisionArea(
                            panelWidth: panelWidth,
                            petition: petition,
                            author: author,
                            accent: _toneAccent,
                            kicker: _displayKicker,
                            decisionContext: decisionContext,
                            onAuthorTap: onAuthorTap,
                            dense: dense,
                            onChoose: onChoose,
                            blockedReason: blockedReason,
                            vetoRow: onVeto == null ? null : _vetoRow(),
                          ),
                        ),
                        _DivanFooter(
                          forced: forced,
                          mustChoose: mustChoose,
                          dismissHint: dismissHint,
                          accent: _toneAccent,
                          onDismiss: mustChoose ? null : onDismiss,
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
  }
}

PortraitExpression _previewExpressionFor(PetitionOption option) {
  // Önizleme yalnız kararın kartta zaten görülen ağırlığını yansıtır; gerçek
  // sonucu ve köylünün nihai tepkisini seçimden önce ifşa etmez.
  return switch (optionSceneFor(option)) {
    OptionScene.execute ||
    OptionScene.exile ||
    OptionScene.labor ||
    OptionScene.refuse => PortraitExpression.worried,
    _ => PortraitExpression.curious,
  };
}

PortraitExpression _decisionReactionFor(PetitionOption option) {
  return switch (optionSceneFor(option)) {
    OptionScene.pardon ||
    OptionScene.accept ||
    OptionScene.selfExpression => PortraitExpression.happy,
    OptionScene.punish ||
    OptionScene.refuse ||
    OptionScene.traditionCouncil => PortraitExpression.angry,
    OptionScene.exile ||
    OptionScene.execute ||
    OptionScene.labor ||
    OptionScene.penance ||
    OptionScene.generic => PortraitExpression.surprised,
  };
}
