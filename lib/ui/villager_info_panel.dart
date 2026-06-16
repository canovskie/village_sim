import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../characters/life_stage.dart';
import '../characters/villager_type.dart';
import '../entities/villager_entity.dart';
import '../rendering/portrait_renderer.dart';
import 'cozy_theme.dart';

/// Köylü kartı — üstte ahşap başlık + portre, altta parşömen üstü kişisel
/// bilgi, yaşam evresi çubuğu, aile bağları ve cozy etkileşim butonları
/// (Selam / Hediye / Takip / Adını değiştir). Aile chip'leri ve aksiyonlar
/// üst sahnedeki callback'lere bağlanır — panel kendi state'i sadece
/// rename modunda kullanır.
class VillagerInfoPanel extends StatefulWidget {
  final VillagerEntity villager;
  final String? homeLabel;
  final bool isFollowed;
  final bool canGift;
  final VoidCallback onClose;
  final void Function(VillagerEntity)? onSelect;
  final VoidCallback? onGreet;
  final VoidCallback? onGift;
  final VoidCallback? onToggleFollow;
  final VoidCallback? onToggleFavorite;
  final void Function(String)? onRename;

  const VillagerInfoPanel({
    super.key,
    required this.villager,
    required this.onClose,
    this.homeLabel,
    this.isFollowed = false,
    this.canGift = true,
    this.onSelect,
    this.onGreet,
    this.onGift,
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
    return SizedBox(
      width: 304,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _header(v, stage),
          Transform.translate(
            offset: const Offset(0, -2),
            child: ParchmentPanel(
              pinned: false,
              padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _statusStrip(v),
                  const SizedBox(height: 10),
                  _ageBar(v, stage),
                  const SizedBox(height: 9),
                  _moodRow(v),
                  const SizedBox(height: 2),
                  _row('Ev', widget.homeLabel ?? 'Evsiz'),
                  if (v.greetCount > 0 || v.giftCount > 0) ...[
                    const SizedBox(height: 2),
                    _interactionRow(v),
                  ],
                  if (v.parents.isNotEmpty || v.children.isNotEmpty) ...[
                    const CozyDivider(wood: false),
                    if (v.parents.isNotEmpty)
                      _familyGroup('Ebeveynler', v.parents),
                    if (v.parents.isNotEmpty && v.children.isNotEmpty)
                      const SizedBox(height: 7),
                    if (v.children.isNotEmpty)
                      _familyGroup('Çocuklar', v.children),
                  ],
                  const CozyDivider(wood: false),
                  _actionRow(v),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Header ─────────────────────────────────────────────────────────────────

  Widget _header(VillagerEntity v, LifeStage stage) {
    final genderIcon = v.isMale ? '♂' : '♀';
    final profession = v.hasProfession
        ? '$genderIcon  ${v.type.displayName}'
        : '$genderIcon  ${stage.label}';
    return WoodPlankPanel(
      padding: const EdgeInsets.fromLTRB(11, 9, 9, 11),
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(4),
        topRight: Radius.circular(4),
        bottomLeft: Radius.zero,
        bottomRight: Radius.zero,
      ),
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
                  color: const Color(0xFF1A0E04),
                  border: Border.all(color: const Color(0xFF2E1A08), width: 1),
                  boxShadow: const [
                    BoxShadow(color: Color(0x88000000), blurRadius: 2, offset: Offset(0, 1)),
                  ],
                ),
                child: CustomPaint(
                  painter: PortraitPainter(
                    visual:        v.visual,
                    stage:         stage,
                    type:          v.type,
                    hasProfession: v.hasProfession,
                  ),
                ),
              ),
              if (v.isFavorite)
                Positioned(
                  top: -4, right: -4,
                  child: Container(
                    width: 16, height: 16,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A0E08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: CozyUi.rust, width: 1),
                      boxShadow: [
                        BoxShadow(color: CozyUi.rust.withValues(alpha: 0.6), blurRadius: 4),
                      ],
                    ),
                    child: const Text('❤',
                        style: TextStyle(
                            color: Color(0xFFFFB99A), fontSize: 9, height: 1.0)),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _renaming ? _renameField() : _nameLine(v),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: Color.alphaBlend(
                        CozyUi.ember.withValues(alpha: 0.30),
                        const Color(0xFF1A0E04)),
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(
                        color: CozyUi.ember.withValues(alpha: 0.7), width: 1),
                  ),
                  child: Text(profession,
                      style: TextStyle(
                        color: CozyUi.ember,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'monospace',
                        letterSpacing: 0.5,
                        shadows: const [
                          Shadow(color: Color(0xAA000000), blurRadius: 0, offset: Offset(0, 1)),
                        ],
                      )),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // Favori toggle (kalp) + close
          _iconCircle(
            icon: v.isFavorite ? '❤' : '♡',
            iconColor: v.isFavorite ? const Color(0xFFFFB99A) : const Color(0xFFD2B679),
            onTap: widget.onToggleFavorite,
          ),
          const SizedBox(width: 4),
          _iconCircle(
            icon: '✕',
            iconColor: const Color(0xFFD2B679),
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
                style: CozyUi.carvedTitle.copyWith(
                    fontSize: 13, letterSpacing: 1.6,
                    color: const Color(0xFFF1D89A)),
                overflow: TextOverflow.ellipsis),
          ),
          if (widget.onRename != null)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Text('✎',
                  style: TextStyle(
                    color: Color(0x99D2B679),
                    fontSize: 10,
                    height: 1.0,
                  )),
            ),
        ],
      ),
    );
  }

  Widget _renameField() {
    return SizedBox(
      height: 22,
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
              style: CozyUi.carvedTitle.copyWith(
                fontSize: 13, letterSpacing: 1.0,
                color: const Color(0xFFF1D89A),
              ),
              cursorColor: CozyUi.ember,
              cursorWidth: 1.2,
              decoration: const InputDecoration(
                isDense: true,
                counterText: '',
                contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                filled: true,
                fillColor: Color(0xFF1A0E04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(3)),
                  borderSide: BorderSide(color: CozyUi.ember, width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(3)),
                  borderSide: BorderSide(color: Color(0xFF3A2410), width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(3)),
                  borderSide: BorderSide(color: CozyUi.ember, width: 1.4),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          _miniBtn(label: '✓', color: CozyUi.sage, onTap: _commitRename),
          const SizedBox(width: 3),
          _miniBtn(
              label: '✕',
              color: const Color(0xFF8A5030),
              onTap: () => setState(() => _renaming = false)),
        ],
      ),
    );
  }

  Widget _miniBtn({required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 18, height: 20,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF1A0E04),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: color, width: 1),
        ),
        child: Text(label,
            style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w900,
              fontFamily: 'monospace', height: 1.0,
            )),
      ),
    );
  }

  Widget _iconCircle({
    required String icon,
    required Color iconColor,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 22, height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF1A0E04),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: const Color(0xFF3A2410), width: 1),
          boxShadow: const [
            BoxShadow(color: Color(0x88000000), blurRadius: 2, offset: Offset(0, 1)),
          ],
        ),
        child: Text(icon,
            style: TextStyle(
              color: iconColor,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              height: 1.0,
            )),
      ),
    );
  }

  // ─── Status strip — durum + aktivite + özel rozetler ────────────────────────

  Widget _statusStrip(VillagerEntity v) {
    final badges = <Widget>[];
    final (label, color, icon) = _stateChip(v);
    badges.add(WaxBadge(label: label, color: color, icon: icon));
    final activity = _activityChip(v);
    if (activity != null) badges.add(activity);
    if (v.isSage) {
      badges.add(const WaxBadge(label: 'Bilge', color: Color(0xFFB079D4), icon: '✨'));
    }
    if (widget.isFollowed) {
      badges.add(WaxBadge(label: 'Takipte', color: CozyUi.sage, icon: '🎥'));
    }
    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: badges,
    );
  }

  (String, Color, String) _stateChip(VillagerEntity v) {
    if (v.isSeatedAtFire) return ('Ateş başı', CozyUi.ember, '🔥');
    if (v.isSleeping)     return ('Uyuyor',    const Color(0xFF6C7CB2), '💤');
    if (v.isCarrying)     return ('Taşıyor',   const Color(0xFFC0A040), '📦');
    if (v.isWalking)      return ('Yürüyor',   CozyUi.sage, '🚶');
    return ('Boşta', const Color(0xFF8A6D40), '·');
  }

  Widget? _activityChip(VillagerEntity v) {
    switch (v.activity) {
      case VillagerActivity.chat:
        return const WaxBadge(label: 'Sohbet', color: Color(0xFF6FA0C8), icon: '💬');
      case VillagerActivity.music:
        return const WaxBadge(label: 'Müzik', color: Color(0xFFB079D4), icon: '🎸');
      case VillagerActivity.dance:
        return const WaxBadge(label: 'Dans', color: Color(0xFFE07895), icon: '💃');
      case VillagerActivity.warm:
        return const WaxBadge(label: 'Isınıyor', color: CozyUi.ember, icon: '☕');
      case VillagerActivity.storytelling:
        return const WaxBadge(label: 'Hikaye', color: Color(0xFFD49C5C), icon: '📖');
      case VillagerActivity.listening:
        return const WaxBadge(label: 'Dinliyor', color: Color(0xFFA8C078), icon: '👂');
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
            const SizedBox(width: 5),
            Text('${stage.label} · $ageStr',
                style: CozyUi.inkBody.copyWith(fontWeight: FontWeight.w800)),
            const Spacer(),
            Text(_lifeStageTail(stage, v),
                style: CozyUi.inkMuted.copyWith(fontSize: 9)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: Container(
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0x44000000),
              border: Border.all(color: const Color(0x55000000), width: 0.5),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: pct,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      _stageColor(stage).withValues(alpha: 0.95),
                      _stageColor(stage).withValues(alpha: 0.65),
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

  (double, double) _stageBounds(LifeStage s) => switch (s) {
        LifeStage.child => (0.0, kYouthStartDay),
        LifeStage.youth => (kYouthStartDay, kAdultStartDay),
        LifeStage.adult => (kAdultStartDay, kElderStartDay),
        LifeStage.elder => (kElderStartDay, kElderStartDay + kElderLifeMax),
      };

  Color _stageColor(LifeStage s) => switch (s) {
        LifeStage.child => const Color(0xFFE6B870),
        LifeStage.youth => CozyUi.sage,
        LifeStage.adult => CozyUi.ember,
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
  Widget _moodRow(VillagerEntity v) {
    final (icon, label) = _moodLabel(v.mood);
    final energyPct = (v.energy * 100).round();
    return _row('Hâli', '$icon $label · ⚡$energyPct%');
  }

  (String, String) _moodLabel(double m) {
    if (m > 0.45) return ('😄', 'Neşeli');
    if (m > 0.12) return ('🙂', 'Keyifli');
    if (m < -0.45) return ('😢', 'Çökmüş');
    if (m < -0.12) return ('😕', 'Keyifsiz');
    return ('😐', 'Sakin');
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(width: 56, child: Text(label, style: CozyUi.inkLabel)),
            Flexible(
              child: Text(value,
                  style: CozyUi.inkBody.copyWith(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );

  Widget _interactionRow(VillagerEntity v) {
    final parts = <String>[];
    if (v.greetCount > 0) parts.add('👋 ${v.greetCount}');
    if (v.giftCount > 0) parts.add('🎁 ${v.giftCount}');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          const SizedBox(
              width: 56,
              child: Text('Bağ', style: CozyUi.inkLabel)),
          Flexible(
            child: Text(parts.join('   '),
                style: CozyUi.inkBody.copyWith(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  // ─── Family chips ──────────────────────────────────────────────────────────

  Widget _familyGroup(String label, List<VillagerEntity> members) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: CozyUi.inkLabel),
        const SizedBox(height: 4),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: members.map(_familyChip).toList(),
        ),
      ],
    );
  }

  Widget _familyChip(VillagerEntity v) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: const Color(0x55000000),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: CozyUi.parchmentEdge, width: 0.6),
      ),
      child: Text('${v.lifeStage.icon} ${v.name}',
          style: const TextStyle(
              color: CozyUi.parchmentInk,
              fontSize: 9,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w700)),
    );
    if (widget.onSelect == null) return chip;
    return GestureDetector(onTap: () => widget.onSelect!(v), child: chip);
  }

  // ─── Aksiyon butonları — cozy etkileşim ────────────────────────────────────

  Widget _actionRow(VillagerEntity v) {
    return Row(
      children: [
        Expanded(
          child: _actionTile(
            icon: '👋',
            label: 'Selam',
            tint: CozyUi.sage,
            onTap: widget.onGreet,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _actionTile(
            icon: '🎁',
            label: 'Hediye',
            tint: CozyUi.ember,
            onTap: widget.onGift,
            disabled: !widget.canGift,
            hint: widget.canGift ? null : 'yiyecek yok',
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _actionTile(
            icon: widget.isFollowed ? '⏹' : '🎥',
            label: widget.isFollowed ? 'Bırak' : 'Takip',
            tint: widget.isFollowed ? CozyUi.rust : const Color(0xFF6FA0C8),
            onTap: widget.onToggleFollow,
            active: widget.isFollowed,
          ),
        ),
      ],
    );
  }

  Widget _actionTile({
    required String icon,
    required String label,
    required Color tint,
    VoidCallback? onTap,
    bool active = false,
    bool disabled = false,
    String? hint,
  }) {
    final effectiveTap = disabled ? null : onTap;
    final accent = tint;
    return Opacity(
      opacity: disabled ? 0.45 : 1.0,
      child: GestureDetector(
        onTap: effectiveTap,
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: active
                  ? [
                      Color.alphaBlend(accent.withValues(alpha: 0.55), CozyUi.leatherHi),
                      Color.alphaBlend(accent.withValues(alpha: 0.30), CozyUi.leather),
                    ]
                  : const [Color(0xFFB47542), CozyUi.leather],
            ),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: active ? accent : const Color(0xFF1F0E04),
              width: active ? 1.6 : 1.2,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                        color: accent.withValues(alpha: 0.55),
                        blurRadius: 8,
                        spreadRadius: 0.3),
                  ]
                : const [
                    BoxShadow(
                        color: Color(0x66000000),
                        blurRadius: 3,
                        offset: Offset(0, 2)),
                  ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(icon, style: const TextStyle(fontSize: 16, height: 1.0)),
              const SizedBox(height: 2),
              Text(
                hint ?? label,
                style: TextStyle(
                  color: const Color(0xFFFCEDC4),
                  fontSize: hint != null ? 8 : 9.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  fontFamily: 'monospace',
                  shadows: const [
                    Shadow(color: Color(0xCC1A0E04), blurRadius: 0, offset: Offset(0, 1)),
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
