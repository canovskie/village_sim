import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../save/save_manager.dart';
import 'app_ui.dart';
import 'mobile_ui.dart';

/// KAYITLI KÖYLER — ana menünün şafak sahnesinin ÜSTÜNDE açılan overlay pano
/// (eskiden ayrı bir Material sayfaya atlıyordu: AppBar + AlertDialog + Material
/// ikonları → atmosferi kesiyor, oyunun diline hiç benzemiyordu).
///
/// Kolaylaştırma:
///   • En son oynanan köy en üstte, BÜYÜK "kaldığın yerden devam et" kartı → tek tık.
///   • Yeniden adlandır / sil artık SATIR İÇİNDE (Material diyalog yok, ekran değişmez).
///   • Esc ya da boşluğa dokun = kapat.
class SaveSlotsPanel extends StatefulWidget {
  /// Bir slot seçildiğinde çağrılır (paneli kapatıp oyunu başlatmak çağırana ait).
  final void Function(SaveSlotMeta) onContinue;
  final VoidCallback onClose;

  /// Slot kaynağı — varsayılan gerçek [SaveManager]. Önizleme harness'i sahte
  /// liste enjekte edebilsin diye (gerçek kayıtlara dokunmadan) dışarı alındı.
  final Future<List<SaveSlotMeta>> Function()? loader;

  const SaveSlotsPanel({
    super.key,
    required this.onContinue,
    required this.onClose,
    this.loader,
  });

  @override
  State<SaveSlotsPanel> createState() => _SaveSlotsPanelState();
}

class _SaveSlotsPanelState extends State<SaveSlotsPanel> {
  List<SaveSlotMeta>? _slots;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final slots = await (widget.loader ?? SaveManager.instance.listSlots)();
    // En son kaydedilen başa — "devam et" hep en üstteki olsun.
    slots.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    if (mounted) setState(() => _slots = slots);
  }

  Future<void> _delete(SaveSlotMeta s) async {
    await SaveManager.instance.deleteSlot(s.id);
    await _reload();
  }

  Future<void> _rename(SaveSlotMeta s, String name) async {
    await SaveManager.instance.renameSlot(s.id, name);
    await _reload();
  }

  static String ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'az önce';
    if (d.inMinutes < 60) return '${d.inMinutes} dk önce';
    if (d.inHours < 24) return '${d.inHours} saat önce';
    if (d.inDays == 1) return 'dün';
    return '${d.inDays} gün önce';
  }

  @override
  Widget build(BuildContext context) {
    final compact = useCompactGameUi(context);
    final mobileWindow = compact
        ? MobileUi.windowSize(context, maxWidth: 720)
        : null;
    return Positioned.fill(
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): widget.onClose,
        },
        child: Focus(
          autofocus: true,
          child: Stack(
            children: [
              // Hafif scrim — arkadaki şafak sahnesi tamamen kaybolmasın.
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onClose,
                  child: const ColoredBox(color: Color(0xC00A0710)),
                ),
              ),
              compact
                  ? Center(
                      child: SizedBox(
                        width: mobileWindow!.width,
                        height: mobileWindow.height,
                        child: GestureDetector(
                          onTap: () {}, // panel içi dokunuş kapatmasın
                          child: AppReveal(
                            child: AppGildedFrame(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _header(),
                                  Container(height: 1, color: AppUi.line),
                                  Expanded(
                                    child: SingleChildScrollView(
                                      child: _body(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  // Masaüstünde çerçeve içeriğe göre büyür; taşarsa sayfa kayar.
                  : Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(22),
                          child: GestureDetector(
                            onTap: () {},
                            child: AppReveal(
                              child: AppGildedFrame(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _header(),
                                    Container(height: 1, color: AppUi.line),
                                    _body(),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 15, 12, 14),
      child: Row(
        children: [
          const Text('⌂', style: TextStyle(fontSize: 20, color: AppUi.gold)),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'KAYITLI KÖYLER',
                  style: AppUi.title.copyWith(letterSpacing: 1.6),
                ),
                const SizedBox(height: 2),
                Text(
                  'bıraktığın yere dön',
                  style: AppUi.label.copyWith(color: AppUi.textLo),
                ),
              ],
            ),
          ),
          AppIconButton(
            icon: GameIconData.close,
            size: 28,
            onTap: widget.onClose,
          ),
        ],
      ),
    );
  }

  Widget _body() {
    final slots = _slots;
    if (slots == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 44),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation(AppUi.accent),
            ),
          ),
        ),
      );
    }
    if (slots.isEmpty) return _empty();

    final latest = slots.first;
    final rest = slots.skip(1).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // KOLAYLIK: en son oynanan köy, büyük ve tek tıkla.
          _SlotCard(
            key: ValueKey(latest.id),
            meta: latest,
            hero: true,
            onOpen: () => widget.onContinue(latest),
            onRename: (n) => _rename(latest, n),
            onDelete: () => _delete(latest),
          ),
          if (rest.isNotEmpty) ...[
            const SizedBox(height: 18),
            const AppSectionLabel('DİĞER KÖYLER'),
            const SizedBox(height: 4),
            for (final s in rest) ...[
              _SlotCard(
                key: ValueKey(s.id),
                meta: s,
                onOpen: () => widget.onContinue(s),
                onRename: (n) => _rename(s, n),
                onDelete: () => _delete(s),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }

  Widget _empty() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 34, 24, 38),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🌱', style: TextStyle(fontSize: 34)),
          const SizedBox(height: 12),
          Text(
            'Henüz kurulmuş bir köyün yok.',
            textAlign: TextAlign.center,
            style: AppUi.bodyHi.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            'Menüden "Yeni Köy" ile başla — kurduğun köy '
            'buraya kendiliğinden yazılır.',
            textAlign: TextAlign.center,
            style: AppUi.body.copyWith(fontSize: 11.5, color: AppUi.textLo),
          ),
        ],
      ),
    );
  }
}

// ─── Slot kartı ──────────────────────────────────────────────────────────────

enum _CardMode { idle, renaming, confirmDelete }

/// Bir kayıtlı köy. [hero] true → en son oynanan köy: daha büyük, altın kenarlı,
/// "kaldığın yerden devam et" çağrısıyla. Yeniden adlandır/sil SATIR İÇİNDE olur
/// (Material diyalog yok → ekran değişmez, akış kesilmez).
class _SlotCard extends StatefulWidget {
  final SaveSlotMeta meta;
  final bool hero;
  final VoidCallback onOpen;
  final void Function(String) onRename;
  final VoidCallback onDelete;

  const _SlotCard({
    super.key,
    required this.meta,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
    this.hero = false,
  });

  @override
  State<_SlotCard> createState() => _SlotCardState();
}

class _SlotCardState extends State<_SlotCard> {
  _CardMode _mode = _CardMode.idle;
  bool _hover = false;
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.meta.name,
  );
  final FocusNode _focus = FocusNode();

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startRename() {
    setState(() {
      _mode = _CardMode.renaming;
      _ctrl.text = widget.meta.name;
      _ctrl.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _ctrl.text.length,
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  void _commitRename() {
    final n = _ctrl.text.trim();
    if (n.isNotEmpty && n != widget.meta.name) widget.onRename(n);
    setState(() => _mode = _CardMode.idle);
  }

  @override
  Widget build(BuildContext context) {
    final hero = widget.hero;
    final accent = hero ? AppUi.gold : AppUi.accent;
    final active = _hover || _mode != _CardMode.idle;
    return MouseRegion(
      cursor: _mode == _CardMode.idle
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: _mode == _CardMode.idle ? widget.onOpen : null,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: EdgeInsets.fromLTRB(13, hero ? 13 : 11, 12, hero ? 13 : 11),
          decoration: BoxDecoration(
            gradient: hero
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.alphaBlend(
                        accent.withValues(alpha: active ? 0.20 : 0.13),
                        AppUi.surface2,
                      ),
                      AppUi.surface1,
                    ],
                  )
                : null,
            color: hero
                ? null
                : (active
                      ? Color.alphaBlend(
                          accent.withValues(alpha: 0.10),
                          AppUi.surface1,
                        )
                      : AppUi.surface0),
            borderRadius: BorderRadius.circular(AppUi.radiusSm),
            border: Border.all(
              color: hero
                  ? accent.withValues(alpha: active ? 0.75 : 0.55)
                  : (active ? accent.withValues(alpha: 0.55) : AppUi.line),
              width: hero ? 1.3 : 1,
            ),
            boxShadow: (hero || active)
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: hero ? 0.20 : 0.12),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          child: switch (_mode) {
            _CardMode.renaming => _renameRow(),
            _CardMode.confirmDelete => _confirmRow(),
            _CardMode.idle => _infoRow(hero, accent),
          },
        ),
      ),
    );
  }

  // ── Normal görünüm ─────────────────────────────────────────────────────────
  Widget _infoRow(bool hero, Color accent) {
    final m = widget.meta;
    return Row(
      children: [
        // Gün madalyonu — köyün kaçıncı gününde kaldığın, tek bakışta.
        Container(
          width: hero ? 50 : 42,
          height: hero ? 50 : 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Color.alphaBlend(
                  accent.withValues(alpha: 0.22),
                  AppUi.surface0,
                ),
                AppUi.surface0,
              ],
            ),
            border: Border.all(
              color: AppUi.gold.withValues(alpha: 0.5),
              width: 1.2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${m.day}',
                style: AppUi.number.copyWith(
                  fontSize: hero ? 17 : 15,
                  color: AppUi.textHi,
                ),
              ),
              Text(
                'GÜN',
                style: AppUi.label.copyWith(fontSize: 6.5, color: AppUi.textLo),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hero)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    'KALDIĞIN YERDEN DEVAM ET',
                    style: AppUi.label.copyWith(
                      fontSize: 8,
                      letterSpacing: 1.2,
                      color: accent,
                    ),
                  ),
                ),
              Text(
                m.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppUi.title.copyWith(fontSize: hero ? 17 : 14),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      m.identity,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppUi.body.copyWith(
                        fontSize: 11,
                        color: AppUi.gold,
                      ),
                    ),
                  ),
                  Text(
                    ' · ${m.population} kişi · ',
                    style: AppUi.body.copyWith(
                      fontSize: 11,
                      color: AppUi.textLo,
                    ),
                  ),
                  Text(
                    _SaveSlotsPanelState.ago(m.savedAt),
                    style: AppUi.body.copyWith(
                      fontSize: 11,
                      color: AppUi.textLo,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        // Satır içi eylemler — hover'da belirir (sade dursun).
        AnimatedOpacity(
          duration: const Duration(milliseconds: 140),
          opacity: _hover ? 1.0 : 0.32,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _iconBtn(
                Icons.edit_outlined,
                AppUi.textMid,
                'Yeniden adlandır',
                _startRename,
              ),
              const SizedBox(width: 2),
              _iconBtn(
                Icons.delete_outline,
                AppUi.rust,
                'Sil',
                () => setState(() => _mode = _CardMode.confirmDelete),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        GameIcon(
          GameIconData.chevron,
          size: hero ? 20 : 16,
          color: _hover ? accent : AppUi.textLo,
        ),
      ],
    );
  }

  Widget _iconBtn(IconData icon, Color color, String tip, VoidCallback onTap) {
    return Tooltip(
      message: tip,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: useCompactGameUi(context) ? MobileUi.tap : 27,
          height: useCompactGameUi(context) ? MobileUi.tap : 27,
          child: Center(child: Icon(icon, size: 17, color: color)),
        ),
      ),
    );
  }

  // ── Satır içi yeniden adlandırma ───────────────────────────────────────────
  Widget _renameRow() {
    return Row(
      children: [
        const GameIcon(GameIconData.scroll, size: 16, color: AppUi.accent),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: _ctrl,
            focusNode: _focus,
            style: AppUi.bodyHi.copyWith(fontSize: 14),
            cursorColor: AppUi.accent,
            maxLength: 24,
            decoration: const InputDecoration(
              isDense: true,
              counterText: '',
              border: InputBorder.none,
              hintText: 'Köy adı',
            ),
            onSubmitted: (_) => _commitRename(),
          ),
        ),
        const SizedBox(width: 8),
        _textBtn(
          'Vazgeç',
          AppUi.textLo,
          () => setState(() => _mode = _CardMode.idle),
        ),
        const SizedBox(width: 6),
        _textBtn('Kaydet', AppUi.accent, _commitRename),
      ],
    );
  }

  // ── Satır içi silme onayı ──────────────────────────────────────────────────
  Widget _confirmRow() {
    return Row(
      children: [
        const Icon(Icons.delete_outline, size: 18, color: AppUi.rust),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '"${widget.meta.name}" kalıcı olarak silinsin mi?',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppUi.body.copyWith(fontSize: 12, color: AppUi.textHi),
          ),
        ),
        const SizedBox(width: 8),
        _textBtn(
          'Vazgeç',
          AppUi.textLo,
          () => setState(() => _mode = _CardMode.idle),
        ),
        const SizedBox(width: 6),
        _textBtn('Sil', AppUi.rust, widget.onDelete),
      ],
    );
  }

  Widget _textBtn(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(
          label,
          style: AppUi.label.copyWith(fontSize: 9, color: color),
        ),
      ),
    );
  }
}

/// Oyun içi kompakt manuel kaydet butonu — sol-altta küçük yuvarlak.
/// Oyun içi "ana menüye dön" butonu — SaveButton ile aynı yuvarlak stil.
/// Basışta üst katman onay modal'ını açar (gerçek çıkış sahnede yapılır).
class MenuButton extends StatefulWidget {
  final VoidCallback onTap;
  const MenuButton({super.key, required this.onTap});

  @override
  State<MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<MenuButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _hover
                ? AppUi.accent.withValues(alpha: 0.22)
                : AppUi.surface1.withValues(alpha: 0.85),
            border: Border.all(
              color: _hover ? AppUi.accent : AppUi.line,
              width: _hover ? 1.5 : 1,
            ),
          ),
          child: Icon(
            Icons.home_outlined,
            size: 20,
            color: _hover ? AppUi.accentSoft : AppUi.textMid,
          ),
        ),
      ),
    );
  }
}

class SaveButton extends StatefulWidget {
  final VoidCallback onTap;
  const SaveButton({super.key, required this.onTap});

  @override
  State<SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends State<SaveButton> {
  bool _flash = false;

  void _tap() {
    widget.onTap();
    setState(() => _flash = true);
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _flash = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final lit = _flash;
    return GestureDetector(
      onTap: _tap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: lit
              ? AppUi.sage.withValues(alpha: 0.30)
              : AppUi.surface1.withValues(alpha: 0.85),
          border: Border.all(
            color: lit ? AppUi.sage : AppUi.line,
            width: lit ? 1.5 : 1,
          ),
          boxShadow: lit
              ? [
                  BoxShadow(
                    color: AppUi.sage.withValues(alpha: 0.4),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: Icon(
          lit ? Icons.check : Icons.save_outlined,
          size: 20,
          color: lit ? AppUi.sage : AppUi.textMid,
        ),
      ),
    );
  }
}
