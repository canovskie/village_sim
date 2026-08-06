import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../buildings/craft.dart';
import '../characters/life_stage.dart';
import '../characters/villager_type.dart';
import '../entities/villager_entity.dart';
import '../entities/villager_job.dart';
import '../rendering/portrait_renderer.dart';
import '../systems/chronicle.dart';
import '../systems/village_custom.dart';
import '../systems/villager_act.dart';
import '../systems/villager_mind.dart';
import 'app_ui.dart';
import 'mobile_ui.dart';

/// Köylü kartı — modern koyu app_ui dilinde. Üstte portre + isim + meslek
/// rozeti + favori/kapat ikon butonları; altta durum rozetleri, animasyonlu
/// yaş çubuğu, hâl/ev satırları, KİŞİLİK (mizaç + sevdiği + künye), aile
/// chip'leri ve Takip butonu. Callback'ler üst sahneye bağlanır — panel kendi
/// state'i sadece rename modunda kullanır.
class VillagerInfoPanel extends StatefulWidget {
  final VillagerEntity villager;
  final String? homeLabel;
  final bool isFollowed;
  final VoidCallback onClose;
  final void Function(VillagerEntity)? onSelect;
  final VoidCallback? onToggleFollow;
  final VoidCallback? onToggleFavorite;
  final void Function(String)? onRename;

  /// Kan davası otoritesi — yalnız feud üyesinde gösterilir (sürgün / idam).
  final VoidCallback? onExile;
  final VoidCallback? onExecute;

  /// KÖYLÜNÜN İŞ YERİ — "Maden Ocağı", "Tarlalar", "Şantiye · Ambar".
  ///
  /// Bu panel artık iş VERMEZ, iş OKUR. Eskiden burada on bir rol rozeti
  /// vardı; iş verme yere taşındı (bkz. WorkCrewSection) çünkü simülasyon hep
  /// "bu maden bir el ister" diye düşünüyordu, panel ise "bu adam madenci
  /// olsun" diyordu. İki dil ayrıydı ve rozetler o ayrığın üstünü örtüyordu.
  ///
  /// null = köylünün üstlendiği bir iş yok.
  final String? workplaceLabel;

  /// İş yerine git — kamerayı oraya taşır, kadro yuvalarını açar. Oyuncu bu
  /// adamı değiştirmek isterse gideceği yer orası.
  final VoidCallback? onOpenWorkplace;

  /// Bu köylüyü işten al (yuvayı boşalt). null = alınacak iş yok.
  final VoidCallback? onReleaseJob;

  /// Açılışta seçili sekme: 0 = GENEL, 1 = KİŞİLİK, 2 = ÖYKÜ.
  final int initialTab;

  const VillagerInfoPanel({
    super.key,
    required this.villager,
    required this.onClose,
    this.homeLabel,
    this.isFollowed = false,
    this.onSelect,
    this.onToggleFollow,
    this.onToggleFavorite,
    this.onRename,
    this.onExile,
    this.onExecute,
    this.workplaceLabel,
    this.onOpenWorkplace,
    this.onReleaseJob,
    this.initialTab = 0,
  });

  @override
  State<VillagerInfoPanel> createState() => _VillagerInfoPanelState();
}

class _VillagerInfoPanelState extends State<VillagerInfoPanel> {
  bool _renaming = false;
  late TextEditingController _nameCtrl;
  final FocusNode _nameFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.villager.name);
  }

  @override
  void didUpdateWidget(covariant VillagerInfoPanel old) {
    super.didUpdateWidget(old);
    // Başka NPC'ye geçildi → rename modunu kapat, controller'ı senkronla.
    if (old.villager != widget.villager) {
      _renaming = false;
      _nameCtrl.text = widget.villager.name;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _startRename() {
    setState(() {
      _renaming = true;
      _nameCtrl.text = widget.villager.name;
      _nameCtrl.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _nameCtrl.text.length,
      );
    });
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _nameFocus.requestFocus(),
    );
  }

  void _commitRename() {
    final v = _nameCtrl.text.trim();
    if (v.isNotEmpty && v != widget.villager.name) {
      widget.onRename?.call(v);
    }
    setState(() => _renaming = false);
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.villager;
    final stage = v.lifeStage;
    if (useCompactGameUi(context)) return _mobileSheet(v, stage);
    return AppReveal(
      child: SizedBox(
        width: 312,
        child: AppPanel(
          accent: _stageColor(stage),
          padding: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(v, stage),
              Container(height: 1, color: AppUi.line),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ÜST — her zaman görünen "bir bakışta" hayati bilgi.
                    _statusStrip(v),
                    const SizedBox(height: 14),
                    _ageBar(v, stage),
                    const SizedBox(height: 12),
                    _moraleBar(v),
                    const SizedBox(height: 4),
                    _moodRow(v),
                    const SizedBox(height: 14),
                    // SEKMELER — gerisi tek kaydırma duvarı yerine üç görünüm.
                    AppTabs(tabs: _tabs(v), initial: widget.initialTab),
                    const SizedBox(height: 14),
                    // AKSİYONLAR — sekmenin arkasına saklanmaz (panelin işi bu).
                    _actionRow(v),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// MOBİL — "yüzen kutu" değil, sağa yapışan TAM BOY sayfa.
  ///
  /// Telefonda eski hâl masaüstünden gelen 312px'lik kutuydu: ekranın ortasında
  /// asılı duruyor, altı komuta hattının içinde kayboluyor, üstteki rayı
  /// örtüyordu — kesilmiş bir kâğıt gibi görünmesinin sebebi buydu. Sayfa
  /// bunun yerine yuvasını DOLDURUR: başlık üstte sabit, eylemler altta sabit,
  /// yalnız ortadaki gövde kayar. Yüzey/yarıçap [MobileSheet] ile aynı dilde.
  Widget _mobileSheet(VillagerEntity v, LifeStage stage) {
    return SizedBox(
      width: MobileUi.sheetWidth(MediaQuery.sizeOf(context)),
      child: AppPanel(
        accent: _stageColor(stage),
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(MobileUi.radius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(v, stage),
            Container(height: 1, color: AppUi.line),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _statusStrip(v),
                    const SizedBox(height: 9),
                    _ageBar(v, stage),
                    const SizedBox(height: 8),
                    _moraleBar(v),
                    const SizedBox(height: 4),
                    _moodRow(v),
                    const SizedBox(height: 9),
                    AppTabs(tabs: _tabs(v), initial: widget.initialTab),
                  ],
                ),
              ),
            ),
            Container(height: 1, color: AppUi.line),
            // Eylemler kaymaz: sayfanın dibinde, parmağın doğal yerinde.
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 7, 10, 9),
              child: _actionRow(v),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Sekmeler ───────────────────────────────────────────────────────────────

  /// GENEL (ev + aile) · KİŞİLİK (mizaç/künye) · ÖYKÜ (yaşam çizelgesi).
  /// Boş kalan sekme hiç gösterilmez (öyküsü olmayan bebekte ÖYKÜ yok).
  List<(String, Widget)> _tabs(VillagerEntity v) {
    final family = _familyTree(v);
    final story = _lifeStory(v);
    return [
      (
        'GENEL',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ..._workSection(v),
            ..._mindSection(v),
            _row('Ev', widget.homeLabel ?? 'Evsiz', icon: GameIconData.home),
            if (family.isNotEmpty) ...[const SizedBox(height: 6), ...family],
          ],
        ),
      ),
      (
        'KİŞİLİK',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: _personalitySection(v),
        ),
      ),
      if (story.isNotEmpty)
        (
          'ÖYKÜ',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: story,
          ),
        ),
    ];
  }

  // ─── Header ─────────────────────────────────────────────────────────────────

  Widget _header(VillagerEntity v, LifeStage stage) {
    final genderIcon = v.isMale ? '♂' : '♀';
    final profession = v.hasProfession
        ? '$genderIcon  ${v.type.displayName}'
        : '$genderIcon  ${stage.label}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
      child: Row(
        children: [
          // Portre — favori ise üstüne ufak kalp rozet.
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppUi.surface0,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppUi.line, width: 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: CustomPaint(
                    painter: PortraitPainter(
                      visual: v.visual,
                      stage: stage,
                      type: v.type,
                      hasProfession: v.hasProfession,
                    ),
                  ),
                ),
              ),
              if (v.isFavorite)
                Positioned(
                  top: -5,
                  right: -5,
                  child: Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppUi.surface2,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: AppUi.rust, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: AppUi.rust.withValues(alpha: 0.6),
                          blurRadius: 5,
                        ),
                      ],
                    ),
                    child: const GameIcon(
                      GameIconData.heart,
                      size: 9,
                      color: AppUi.rust,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _renaming ? _renameField() : _nameLine(v),
                const SizedBox(height: 5),
                AppChip(
                  label: profession.toUpperCase(),
                  color: _stageColor(stage),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // Favori toggle (kalp) + close
          AppIconButton(
            icon: GameIconData.heart,
            size: 26,
            active: v.isFavorite,
            tint: AppUi.rust,
            onTap: widget.onToggleFavorite,
          ),
          const SizedBox(width: 5),
          AppIconButton(
            icon: GameIconData.close,
            size: 26,
            onTap: widget.onClose,
          ),
        ],
      ),
    );
  }

  Widget _nameLine(VillagerEntity v) {
    return GestureDetector(
      onTap: widget.onRename == null ? null : _startRename,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  v.name,
                  style: AppUi.title.copyWith(fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.onRename != null)
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: GameIcon(
                    GameIconData.gear,
                    size: 10,
                    color: AppUi.textLo,
                  ),
                ),
            ],
          ),
          if (v.houseLabel.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                '⌂ ${v.houseLabel}',
                style: AppUi.title.copyWith(
                  fontSize: 10,
                  color: AppUi.textLo,
                  fontWeight: FontWeight.w400,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  Widget _renameField() {
    return SizedBox(
      height: 26,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _nameCtrl,
              focusNode: _nameFocus,
              maxLength: 20,
              autofocus: true,
              onSubmitted: (_) => _commitRename(),
              inputFormatters: [
                FilteringTextInputFormatter.deny(RegExp(r'[\r\n\t]')),
              ],
              style: AppUi.title.copyWith(fontSize: 14, letterSpacing: 0.8),
              cursorColor: AppUi.accent,
              cursorWidth: 1.4,
              decoration: const InputDecoration(
                isDense: true,
                counterText: '',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                filled: true,
                fillColor: AppUi.surface0,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(
                    Radius.circular(AppUi.radiusSm),
                  ),
                  borderSide: BorderSide(color: AppUi.accent, width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(
                    Radius.circular(AppUi.radiusSm),
                  ),
                  borderSide: BorderSide(color: AppUi.line, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(
                    Radius.circular(AppUi.radiusSm),
                  ),
                  borderSide: BorderSide(color: AppUi.accent, width: 1.4),
                ),
              ),
            ),
          ),
          const SizedBox(width: 5),
          AppIconButton(
            icon: GameIconData.star,
            size: 24,
            tint: AppUi.sage,
            onTap: _commitRename,
          ),
          const SizedBox(width: 4),
          AppIconButton(
            icon: GameIconData.close,
            size: 24,
            onTap: () => setState(() => _renaming = false),
          ),
        ],
      ),
    );
  }

  // ─── Status strip — durum + aktivite + özel rozetler ────────────────────────

  Widget _statusStrip(VillagerEntity v) {
    final badges = <Widget>[];
    final (label, color, icon) = _stateChip(v);
    badges.add(_emojiChip(label, color, icon));
    final activity = _activityChip(v);
    if (activity != null) badges.add(activity);
    if (v.isSage) {
      badges.add(_emojiChip('Bilge', const Color(0xFFB079D4), '✨'));
    }
    if (widget.isFollowed) {
      badges.add(_emojiChip('Takipte', AppUi.sage, '🎥'));
    }
    return Wrap(spacing: 6, runSpacing: 6, children: badges);
  }

  /// Durum/aktivite rozetleri — etiketler emoji-veri taşıdığı için
  /// AppChip'in vektör ikonu yerine emoji + renkli kapsül kullanıyoruz.
  Widget _emojiChip(String label, Color color, String emoji) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.7), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 10, height: 1.0)),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppUi.button.copyWith(
              fontSize: 9.5,
              letterSpacing: 1.0,
              color: AppUi.textHi,
            ),
          ),
        ],
      ),
    );
  }

  (String, Color, String) _stateChip(VillagerEntity v) {
    // Durum bozucular önce — köylü neden dinliyor/yavaş, oyuncu görsün.
    if (v.sickDays > 0) return ('Hasta', const Color(0xFF7E8A5A), '🤒');
    if (v.injuryDays > 0) return ('Yaralı', AppUi.rust, '🤕');
    if (v.laborDays > 0) return ('Kürek cezası', const Color(0xFF8A8A92), '⛓️');
    if (v.isSeatedAtFire) return ('Ateş başı', AppUi.accent, '🔥');
    if (v.isSleeping) return ('Uyuyor', const Color(0xFF6C7CB2), '💤');
    if (v.isCarrying) return ('Taşıyor', AppUi.gold, '📦');
    if (v.isWalking) return ('Yürüyor', AppUi.sage, '🚶');
    return ('Boşta', AppUi.textLo, '·');
  }

  Widget? _activityChip(VillagerEntity v) {
    switch (v.activity) {
      case VillagerActivity.chat:
        return _emojiChip('Sohbet', AppUi.info, '💬');
      case VillagerActivity.music:
        return _emojiChip('Müzik', const Color(0xFFB079D4), '🎸');
      case VillagerActivity.dance:
        return _emojiChip('Dans', const Color(0xFFE07895), '💃');
      case VillagerActivity.warm:
        return _emojiChip('Isınıyor', AppUi.accent, '☕');
      case VillagerActivity.storytelling:
        return _emojiChip('Hikaye', AppUi.accentSoft, '📖');
      case VillagerActivity.listening:
        return _emojiChip('Dinliyor', AppUi.sage, '👂');
      case VillagerActivity.arguing:
        return _emojiChip('Tartışıyor', AppUi.rust, '💢');
      case VillagerActivity.brawling:
        return _emojiChip('Kavgada', AppUi.rust, '👊');
      // Suç evreleri (scene_crime) — panel de aynı dili konuşsun.
      case VillagerActivity.prowling:
        return _emojiChip('Sinsice', AppUi.rust, '🌑');
      case VillagerActivity.committing:
        return _emojiChip('Suçüstü', AppUi.rust, '🗝️');
      case VillagerActivity.fleeing:
        return _emojiChip('Kaçıyor', AppUi.rust, '💨');
      case VillagerActivity.chasing:
        return _emojiChip('Kovalıyor', AppUi.accent, '🏃');
      case VillagerActivity.abducted:
        return _emojiChip('Kaçırıldı', AppUi.rust, '⛓️');
      case VillagerActivity.playing:
        return _emojiChip('Oynuyor', AppUi.sage, '🪁');
      case VillagerActivity.none:
        return null;
    }
  }

  // ─── Yaş çubuğu + life stage chip ───────────────────────────────────────────

  Widget _ageBar(VillagerEntity v, LifeStage stage) {
    final (segLo, segHi) = _stageBounds(stage);
    final clamped = v.ageDays.clamp(segLo, segHi);
    final pct = ((clamped - segLo) / (segHi - segLo)).clamp(0.0, 1.0);
    final ageStr = '${v.ageDays.toStringAsFixed(1)} gün';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(stage.icon, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 6),
            Text(
              '${stage.label} · $ageStr',
              style: AppUi.bodyHi.copyWith(fontSize: 12),
            ),
            const Spacer(),
            Text(
              _lifeStageTail(stage, v),
              style: AppUi.body.copyWith(fontSize: 10, color: AppUi.textLo),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: AppUi.surface0,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppUi.line, width: 0.8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: pct),
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOutCubic,
                builder: (_, val, _) => FractionallySizedBox(
                  widthFactor: val,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _stageColor(stage).withValues(alpha: 0.8),
                          _stageColor(stage),
                          Color.lerp(_stageColor(stage), Colors.white, 0.28)!,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _stageColor(stage).withValues(alpha: 0.5),
                          blurRadius: 5,
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

  (double, double) _stageBounds(LifeStage s) => switch (s) {
    LifeStage.child => (0.0, kYouthStartDay),
    LifeStage.youth => (kYouthStartDay, kAdultStartDay),
    LifeStage.adult => (kAdultStartDay, kElderStartDay),
    LifeStage.elder => (kElderStartDay, kElderStartDay + kElderLifeMax),
  };

  Color _stageColor(LifeStage s) => switch (s) {
    LifeStage.child => const Color(0xFFE6B870),
    LifeStage.youth => AppUi.sage,
    LifeStage.adult => AppUi.accent,
    LifeStage.elder => const Color(0xFFB079D4),
  };

  String _lifeStageTail(LifeStage s, VillagerEntity v) {
    final (lo, hi) = _stageBounds(s);
    final left = (hi - v.ageDays).clamp(0.0, hi - lo);
    if (s == LifeStage.elder) {
      // Yaşlıya kalan ömür belirsiz, sade ifade.
      return 'huzurlu yıllar';
    }
    return '→ ${left.toStringAsFixed(1)} gün';
  }

  // ─── Rows ───────────────────────────────────────────────────────────────────

  /// Ruh hali + enerji satırı — NPC'nin iç dünyasını oyuncuya gösterir.
  /// Bireysel moral (kalıcı memnuniyet) + baskın sebep — yaş çubuğunun eşi.
  Widget _moraleBar(VillagerEntity v) {
    final m = v.morale.clamp(0.0, 1.0);
    final c = m >= 0.6
        ? AppUi.sage
        : m >= 0.35
        ? AppUi.accent
        : AppUi.rust;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppStatBar(
          label: 'MORAL',
          value: m,
          trailing: '${(m * 100).round()}%',
          color: c,
          labelWidth: 54,
        ),
        Padding(
          padding: const EdgeInsets.only(left: 54, top: 3),
          child: Text(
            '· ${v.moraleReason}',
            style: AppUi.body.copyWith(
              fontSize: 10.5,
              color: AppUi.textLo,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  Widget _moodRow(VillagerEntity v) {
    final (icon, label) = _moodLabel(v.mood);
    final energyPct = (v.energy * 100).round();
    return _row(
      'Hâli',
      '$icon $label · ⚡$energyPct%',
      icon: GameIconData.heart,
    );
  }

  (String, String) _moodLabel(double m) {
    if (m > 0.45) return ('😄', 'Neşeli');
    if (m > 0.12) return ('🙂', 'Keyifli');
    if (m < -0.45) return ('😢', 'Çökmüş');
    if (m < -0.12) return ('😕', 'Keyifsiz');
    return ('😐', 'Sakin');
  }

  Widget _row(String label, String value, {GameIconData? icon}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        if (icon != null) ...[
          GameIcon(icon, size: 13, color: AppUi.textLo),
          const SizedBox(width: 7),
        ],
        SizedBox(
          width: 48,
          child: Text(
            label.toUpperCase(),
            style: AppUi.label.copyWith(letterSpacing: 0.6),
          ),
        ),
        Flexible(
          child: Text(value, style: AppUi.bodyHi.copyWith(fontSize: 12)),
        ),
      ],
    ),
  );

  // ─── İş — nerede çalışıyor ─────────────────────────────────────────────────

  /// İŞİN OKUNUŞU.
  ///
  /// Bu bölüm bir karar yüzeyi DEĞİL, bir cevap: "bu adam nerede çalışıyor?"
  /// Karar iş yerinin kendi kartında verilir (bkz. WorkCrewSection) — orada
  /// kaç el gerektiği de görünür, burada görünmezdi. Rozet ızgarası bir köylüye
  /// on bir seçenek sunup köyün o işten kaç el istediğini hiç söylemiyordu.
  ///
  /// İki eylem bırakıldı: işyerine GİT (kararın verildiği yere götürür) ve
  /// İŞTEN AL (elindeki tek yıkıcı olmayan geri alma).
  List<Widget> _workSection(VillagerEntity v) {
    final place = widget.workplaceLabel;
    // Çocuk / hasta / sakat köylüye iş verilmez — sebebini yaz, boş bırakma.
    if (!v.canRunErrands) {
      return [
        _sectionLabel('İŞ'),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            _noWorkReason(v),
            style: AppUi.body.copyWith(color: AppUi.textLo, fontSize: 11),
          ),
        ),
      ];
    }

    final role = v.job?.role ?? JobRole.none;
    final assigned = v.assignedRole;
    final against =
        role != JobRole.none && VillageCustom.isAgainst(role, male: v.isMale);

    return [
      _sectionLabel('İŞ'),
      if (role == JobRole.none)
        Text(
          assigned == JobRole.none
              ? 'Boşta duruyor — sen böyle istedin.'
              : 'Boşta. Bir iş yerinin kadrosuna katılırsa çalışmaya başlar.',
          style: AppUi.body.copyWith(color: AppUi.textLo, fontSize: 11),
        )
      else ...[
        Row(
          children: [
            Text(role.icon, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                place == null ? role.label : '${role.label} — $place',
                style: AppUi.bodyHi.copyWith(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          // Oyuncunun mührü ile köyün kendi dağıtımı ayrı okunmalı: biri karar,
          // öbürü köyün huyu. Aynı cümleyle anlatılsaydı oyuncu neyi kendi
          // yaptığını unuturdu.
          assigned != null
              ? 'Bu işe sen verdin.'
              : 'Köyün işleri kendiliğinden dağıldı.',
          style: AppUi.body.copyWith(color: AppUi.textLo, fontSize: 11),
        ),
      ],
      if (against) ...[
        const SizedBox(height: 4),
        Text(
          '⚠ Köyün âdeti bu işi böyle bilmez — iş ağır ilerler ve köy konuşur.',
          style: AppUi.body.copyWith(color: AppUi.gold, fontSize: 11),
        ),
      ],
      if (widget.onOpenWorkplace != null || widget.onReleaseJob != null) ...[
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            if (widget.onOpenWorkplace != null)
              _workLink(
                label: 'İşyerine git',
                tint: AppUi.accent,
                onTap: widget.onOpenWorkplace!,
              ),
            if (widget.onReleaseJob != null)
              _workLink(
                label: 'İşten al',
                tint: AppUi.textLo,
                onTap: widget.onReleaseJob!,
              ),
          ],
        ),
      ],
      const SizedBox(height: 10),
    ];
  }

  String _noWorkReason(VillagerEntity v) {
    if (v.lifeStage == LifeStage.child) return 'Daha çocuk — işe koşulmaz.';
    if (v.sickDays > 0) return 'Hasta yatıyor; iyileşmeden iş tutmaz.';
    if (v.injuryDays > 0) return 'Yaralı — bir süre iş göremez.';
    return 'Şimdilik iş tutamaz.';
  }

  /// İş satırının altındaki ince eylem — buton değil bağlantı ağırlığında.
  /// Kadro kararının ağırlığı iş yeri kartında; burada yalnız oraya açılan
  /// kapı ve tek geri alma durur.
  Widget _workLink({
    required String label,
    required Color tint,
    required VoidCallback onTap,
  }) => Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: AppUi.surface0,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: tint.withValues(alpha: 0.34)),
        ),
        child: Text(
          label,
          style: AppUi.body.copyWith(fontSize: 11, color: tint),
        ),
      ),
    ),
  );

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: AppUi.label.copyWith(letterSpacing: 0.6)),
  );

  // ─── Aklı — ne yapıyor, neden, derdi ne ────────────────────────────────────

  /// NİYET + SEBEP + BASKIN DERT.
  ///
  /// Bu üç satır Faz 1'in oyuncuya bakan yüzü. Bir köylünün ne yaptığını
  /// görmek yetmez — NEDEN yaptığı görünmezse davranış rastgele, yani
  /// karikatür görünür. Sebep hakemin seçtiği teklifin kendi cümlesidir
  /// ([Bid.reason]); yani panelde yazan şey, kararın gerçek gerekçesi.
  List<Widget> _mindSection(VillagerEntity v) {
    final m = v.mind;
    if (m.intent.isIdle && m.readout.isEmpty) return const [];
    final dom = m.dominant;
    final domVal = m.drive(dom);
    return [
      _row('Hâli', intentLabel(m.intent.kind), icon: GameIconData.people),
      if (!m.intent.isIdle)
        Padding(
          padding: const EdgeInsets.only(left: 20, bottom: 2),
          child: Text(
            '“${m.intent.reason}”',
            style: AppUi.body.copyWith(
              fontSize: 11.5,
              fontStyle: FontStyle.italic,
              color: AppUi.textLo,
            ),
          ),
        ),
      // Elinde ne var — mikro-sahnenin somut kanıtı (bkz. villager_act).
      if (v.prop != PropKind.none)
        Padding(
          padding: const EdgeInsets.only(left: 20, bottom: 2),
          child: Text(
            'elinde: ${propLabel(v.prop)}',
            style: AppUi.label.copyWith(fontSize: 10.5),
          ),
        ),
      // Baskın dert yalnız gerçekten bir dert varken yazılır — her köylüde
      // sürekli "işsizlik 4" yazan bir satır gürültüdür.
      if (domVal >= 0.30)
        Padding(
          padding: const EdgeInsets.only(left: 20, bottom: 4),
          child: Text(
            'derdi: ${driveLabel(dom)}',
            style: AppUi.label.copyWith(fontSize: 10.5),
          ),
        ),
      // HATIRLADIKLARI — köylünün gördükleri. Kulaktan duyduğu açıkça
      // işaretlenir, çünkü köyde neyin bilindiği ile neyin KANITLANDIĞI
      // arasındaki fark oyunun kendisidir (yalnız gözüyle gören ihbar eder).
      ..._memorySection(v),
      const SizedBox(height: 4),
    ];
  }

  List<Widget> _memorySection(VillagerEntity v) {
    final lines = v.memory.readout();
    if (lines.isEmpty) return const [];
    return [
      const SizedBox(height: 6),
      Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Text(
          'HATIRLADIKLARI',
          style: AppUi.label.copyWith(letterSpacing: 0.6),
        ),
      ),
      for (final l in lines)
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 1),
          child: Text(
            '· $l',
            style: AppUi.body.copyWith(fontSize: 11.5, color: AppUi.textLo),
          ),
        ),
    ];
  }

  // ─── Kişilik — mizaç + sevdiği şey + tek cümlelik künye ────────────────────

  /// Birikim ustalığı satırı — köylünün en güçlü YAPI zanaatı (marangozluk/taş
  /// ustalığı). Eşiği geçen "köyün ustası", altında "eli alışıyor". Meslek
  /// zanaatları meslek rozetinden zaten belli, buraya girmez.
  String? _masteryLine(VillagerEntity v) {
    String? best;
    double bestVal = 0;
    v.mastery.forEach((c, val) {
      if (val > bestVal) {
        bestVal = val;
        best = c;
      }
    });
    if (best == null || bestVal < 3) return null;
    final name = Craft.displayName(best!);
    // 8 = usta eşiği (scene_craft _kMasteryHolderThreshold ile aynı fikir).
    return bestVal >= 8 ? '⚒ köyün $name ustası' : '⚒ eli $name işine alışıyor';
  }

  /// KİŞİLİK sekmesinin gövdesi — başlık/divider YOK (sekme adı üstleniyor).
  List<Widget> _personalitySection(VillagerEntity v) {
    final p = v.personality;
    return [
      // Mizaç çipleri + sevdiği şey çipi.
      Wrap(
        spacing: 5,
        runSpacing: 5,
        children: [
          for (final t in p.traits) _traitChip('${t.icon} ${t.label}'),
          _likeChip('${p.likes.icon} sever: ${p.likes.label}'),
        ],
      ),
      // Çağrı ipucu — henüz büyümekte olan köylüde mesleği belli değil ama
      // içindeki eğilim kişiliğinden sezilir (yetişkinlikte gerçekleşir).
      if (!v.callingFound) ...[
        const SizedBox(height: 7),
        Text(
          '✨ içinde bir ${v.calling.displayName.toLowerCase()} eğilimi seziliyor',
          style: AppUi.body.copyWith(
            color: AppUi.accentSoft,
            fontSize: 11,
            fontStyle: FontStyle.italic,
          ),
        ),
      ] else if (v.type != v.calling) ...[
        // Çağrı kırgınlığı — mesleği içindeki çağrıya uymuyor (kalıcı huzursuzluk).
        const SizedBox(height: 7),
        Text(
          '🌫️ gönlü bir ${v.calling.displayName.toLowerCase()} işinde',
          style: AppUi.body.copyWith(
            color: AppUi.rust,
            fontSize: 11,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
      // Zanaat ustalığı (birikim) — bu köylü elini bir YAPI zanaatına ne kadar
      // alıştırdı. Eşiği geçen köyün ustasıdır (bkz. scene_craft).
      if (_masteryLine(v) case final ml?) ...[
        const SizedBox(height: 7),
        Text(
          ml,
          style: AppUi.body.copyWith(
            color: AppUi.accentSoft,
            fontSize: 11,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
      // Kan davası — bu köylü bir vendetta'nın tarafı (kaç kan düşmanı var).
      if (v.inFeud) ...[
        const SizedBox(height: 7),
        Text(
          '🩸 kan davalı — ${v.bloodEnemies.length} kan düşmanı',
          style: AppUi.bodyHi.copyWith(
            color: AppUi.rust,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
      const SizedBox(height: 7),
      // Tek cümlelik künye — anlatısal renk.
      Text(
        p.backstory,
        style: AppUi.body.copyWith(
          color: AppUi.textMid,
          fontStyle: FontStyle.italic,
          fontSize: 11.5,
          height: 1.25,
        ),
      ),
    ];
  }

  Widget _traitChip(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: AppUi.surface0,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: AppUi.line, width: 1),
    ),
    child: Text(
      text,
      style: AppUi.body.copyWith(color: AppUi.textHi, fontSize: 11),
    ),
  );

  Widget _likeChip(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: AppUi.accent.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: AppUi.accent.withValues(alpha: 0.5), width: 1),
    ),
    child: Text(
      text,
      style: AppUi.body.copyWith(color: AppUi.accentSoft, fontSize: 11),
    ),
  );

  // ─── Family chips ──────────────────────────────────────────────────────────

  /// Aile ağacı — eş (ortak ebeveyn), ebeveynler, kardeşler (ortak ebeveyn),
  /// çocuklar. Hepsi yalnız [parents]/[children]'dan türetilir (global liste
  /// gerekmez). Akrabaya dokununca o köylüye geçilir (onSelect).
  List<Widget> _familyTree(VillagerEntity v) {
    final partners = <VillagerEntity>{};
    for (final c in v.children) {
      for (final p in c.parents) {
        if (!identical(p, v)) partners.add(p);
      }
    }
    final siblings = <VillagerEntity>{};
    for (final p in v.parents) {
      for (final c in p.children) {
        if (!identical(c, v)) siblings.add(c);
      }
    }

    final groups = <(String, List<VillagerEntity>)>[
      ('EŞ', partners.toList()),
      ('EBEVEYNLER', v.parents),
      ('KARDEŞLER', siblings.toList()),
      ('ÇOCUKLAR', v.children),
    ].where((g) => g.$2.isNotEmpty).toList();
    if (groups.isEmpty) return const [];

    // Başlık/divider YOK — GENEL sekmesinin içinde, ev satırının altında akar.
    return [
      for (int i = 0; i < groups.length; i++) ...[
        if (i != 0) const SizedBox(height: 9),
        _familyGroup(groups[i].$1, groups[i].$2),
      ],
    ];
  }

  Widget _familyGroup(String label, List<VillagerEntity> members) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionLabel(label),
        Wrap(
          spacing: 5,
          runSpacing: 5,
          children: members.map(_familyChip).toList(),
        ),
      ],
    );
  }

  Widget _familyChip(VillagerEntity v) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppUi.surface0,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppUi.line, width: 1),
      ),
      child: Text(
        '${v.lifeStage.icon} ${v.name}',
        style: AppUi.body.copyWith(color: AppUi.textMid, fontSize: 11),
      ),
    );
    if (widget.onSelect == null) return chip;
    return GestureDetector(onTap: () => widget.onSelect!(v), child: chip);
  }

  // ─── Yaşam öyküsü — kişisel zaman çizelgesi (bireye bağlanma) ──────────────

  /// Köylünün kendi yaşam olayları: doğum/reşit oluş/evlilik/çocuk/kayıp…
  /// Kronolojik (en eski üstte) — bir hayatın akışını okutur. Boşsa gizli.
  /// ÖYKÜ sekmesinin gövdesi — başlık/divider YOK (sekme adı üstleniyor).
  /// Kendi sekmesi olduğu için eskisinden daha çok nefes alır (132 → 240).
  List<Widget> _lifeStory(VillagerEntity v) {
    if (v.life.isEmpty) return const [];
    return [
      ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 240),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final e in v.life) _lifeRow(e)],
          ),
        ),
      ),
    ];
  }

  Widget _lifeRow(ChronicleEntry e) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(e.icon, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 8),
          SizedBox(
            width: 30,
            child: Text(
              e.day > 0 ? '${e.day}.g' : '',
              style: AppUi.label.copyWith(color: AppUi.textLo, fontSize: 9.5),
            ),
          ),
          Expanded(
            child: Text(
              e.text,
              style: e.milestone
                  ? AppUi.body.copyWith(
                      fontSize: 11,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                      color: AppUi.accentSoft,
                    )
                  : AppUi.body.copyWith(
                      fontSize: 11,
                      height: 1.3,
                      color: AppUi.textMid,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Aksiyon butonları — cozy etkileşim ────────────────────────────────────

  Widget _actionRow(VillagerEntity v) {
    final follow = AppButton(
      label: widget.isFollowed ? 'Takibi bırak' : 'Takip et',
      icon: GameIconData.people,
      tint: widget.isFollowed ? AppUi.rust : AppUi.info,
      kind: widget.isFollowed ? AppButtonKind.filled : AppButtonKind.tonal,
      expand: true,
      onTap: widget.onToggleFollow,
    );
    // Kan davası otoritesi — yalnız feud üyesinde: sürgün + idam (oyuna karışma).
    if (!v.inFeud || (widget.onExile == null && widget.onExecute == null)) {
      return follow;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        follow,
        const SizedBox(height: 10),
        const AppDivider(),
        const AppSectionLabel('KAN DAVASI — YARGI'),
        const SizedBox(height: 6),
        Row(
          children: [
            if (widget.onExile != null)
              Expanded(
                child: AppButton(
                  label: 'Sürgün',
                  icon: GameIconData.people,
                  tint: AppUi.accent,
                  kind: AppButtonKind.tonal,
                  onTap: widget.onExile,
                ),
              ),
            if (widget.onExile != null && widget.onExecute != null)
              const SizedBox(width: 10),
            if (widget.onExecute != null)
              Expanded(
                child: AppButton(
                  label: 'İdam',
                  icon: GameIconData.demolish,
                  tint: AppUi.rust,
                  kind: AppButtonKind.filled,
                  onTap: widget.onExecute,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
