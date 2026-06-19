import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../characters/life_stage.dart';
import '../characters/villager_type.dart';
import '../entities/villager_entity.dart';
import '../rendering/portrait_renderer.dart';
import 'app_ui.dart';

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
          baseOffset: 0, extentOffset: _nameCtrl.text.length);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _nameFocus.requestFocus());
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
                    _statusStrip(v),
                    const SizedBox(height: 14),
                    _ageBar(v, stage),
                    const SizedBox(height: 12),
                    _moraleBar(v),
                    const SizedBox(height: 4),
                    _moodRow(v),
                    _row('Ev', widget.homeLabel ?? 'Evsiz',
                        icon: GameIconData.home),
                    ..._personalitySection(v),
                    ..._familyTree(v),
                    const SizedBox(height: 14),
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
                      visual:        v.visual,
                      stage:         stage,
                      type:          v.type,
                      hasProfession: v.hasProfession,
                    ),
                  ),
                ),
              ),
              if (v.isFavorite)
                Positioned(
                  top: -5, right: -5,
                  child: Container(
                    width: 18, height: 18,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppUi.surface2,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: AppUi.rust, width: 1),
                      boxShadow: [
                        BoxShadow(
                            color: AppUi.rust.withValues(alpha: 0.6),
                            blurRadius: 5),
                      ],
                    ),
                    child: const GameIcon(GameIconData.heart,
                        size: 9, color: AppUi.rust),
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
                AppChip(label: profession.toUpperCase(), color: _stageColor(stage)),
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
      child: Row(
        children: [
          Flexible(
            child: Text(v.name,
                style: AppUi.title.copyWith(fontSize: 15),
                overflow: TextOverflow.ellipsis),
          ),
          if (widget.onRename != null)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: GameIcon(GameIconData.gear, size: 10, color: AppUi.textLo),
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
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                filled: true,
                fillColor: AppUi.surface0,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(AppUi.radiusSm)),
                  borderSide: BorderSide(color: AppUi.accent, width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(AppUi.radiusSm)),
                  borderSide: BorderSide(color: AppUi.line, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(AppUi.radiusSm)),
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
              onTap: _commitRename),
          const SizedBox(width: 4),
          AppIconButton(
              icon: GameIconData.close,
              size: 24,
              onTap: () => setState(() => _renaming = false)),
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
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: badges,
    );
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
          Text(label,
              style: AppUi.button.copyWith(
                  fontSize: 9.5, letterSpacing: 1.0, color: AppUi.textHi)),
        ],
      ),
    );
  }

  (String, Color, String) _stateChip(VillagerEntity v) {
    if (v.isSeatedAtFire) return ('Ateş başı', AppUi.accent, '🔥');
    if (v.isSleeping)     return ('Uyuyor',    const Color(0xFF6C7CB2), '💤');
    if (v.isCarrying)     return ('Taşıyor',   AppUi.gold, '📦');
    if (v.isWalking)      return ('Yürüyor',   AppUi.sage, '🚶');
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
            Text('${stage.label} · $ageStr',
                style: AppUi.bodyHi.copyWith(fontSize: 12)),
            const Spacer(),
            Text(_lifeStageTail(stage, v),
                style: AppUi.body.copyWith(fontSize: 10, color: AppUi.textLo)),
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
                      gradient: LinearGradient(colors: [
                        _stageColor(stage).withValues(alpha: 0.8),
                        _stageColor(stage),
                        Color.lerp(_stageColor(stage), Colors.white, 0.28)!,
                      ]),
                      boxShadow: [
                        BoxShadow(
                            color: _stageColor(stage).withValues(alpha: 0.5),
                            blurRadius: 5),
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
          child: Text('· ${v.moraleReason}',
              style: AppUi.body.copyWith(
                  fontSize: 10.5,
                  color: AppUi.textLo,
                  fontStyle: FontStyle.italic)),
        ),
      ],
    );
  }

  Widget _moodRow(VillagerEntity v) {
    final (icon, label) = _moodLabel(v.mood);
    final energyPct = (v.energy * 100).round();
    return _row('Hâli', '$icon $label · ⚡$energyPct%', icon: GameIconData.heart);
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
                child: Text(label.toUpperCase(),
                    style: AppUi.label.copyWith(letterSpacing: 0.6))),
            Flexible(
              child: Text(value, style: AppUi.bodyHi.copyWith(fontSize: 12)),
            ),
          ],
        ),
      );

  // ─── Kişilik — mizaç + sevdiği şey + tek cümlelik künye ────────────────────

  List<Widget> _personalitySection(VillagerEntity v) {
    final p = v.personality;
    return [
      const AppDivider(),
      AppSectionLabel('KİŞİLİK'),
      const SizedBox(height: 5),
      // Mizaç çipleri + sevdiği şey çipi.
      Wrap(
        spacing: 5,
        runSpacing: 5,
        children: [
          for (final t in p.traits) _traitChip('${t.icon} ${t.label}'),
          _likeChip('${p.likes.icon} sever: ${p.likes.label}'),
        ],
      ),
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
        child: Text(text,
            style: AppUi.body.copyWith(color: AppUi.textHi, fontSize: 11)),
      );

  Widget _likeChip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppUi.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppUi.accent.withValues(alpha: 0.5), width: 1),
        ),
        child: Text(text,
            style: AppUi.body.copyWith(color: AppUi.accentSoft, fontSize: 11)),
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

    return [
      const AppDivider(),
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
      child: Text('${v.lifeStage.icon} ${v.name}',
          style: AppUi.body.copyWith(color: AppUi.textMid, fontSize: 11)),
    );
    if (widget.onSelect == null) return chip;
    return GestureDetector(onTap: () => widget.onSelect!(v), child: chip);
  }

  // ─── Aksiyon butonları — cozy etkileşim ────────────────────────────────────

  Widget _actionRow(VillagerEntity v) {
    return AppButton(
      label: widget.isFollowed ? 'Takibi bırak' : 'Takip et',
      icon: GameIconData.people,
      tint: widget.isFollowed ? AppUi.rust : AppUi.info,
      kind: widget.isFollowed ? AppButtonKind.filled : AppButtonKind.tonal,
      expand: true,
      onTap: widget.onToggleFollow,
    );
  }
}
