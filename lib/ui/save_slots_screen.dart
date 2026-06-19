import 'package:flutter/material.dart';
import '../save/save_manager.dart';
import 'app_ui.dart';

/// Kayıt slotları ekranı — "Devam Et" buradan. Slotları listeler; dokununca
/// o köyden devam edilir. Sil / yeniden adlandır eylemleri de buradadır.
class SaveSlotsScreen extends StatefulWidget {
  /// Bir slot seçildiğinde çağrılır (ekranı kapatıp oyunu başlatmak çağırana ait).
  final void Function(SaveSlotMeta) onContinue;
  const SaveSlotsScreen({super.key, required this.onContinue});

  @override
  State<SaveSlotsScreen> createState() => _SaveSlotsScreenState();
}

class _SaveSlotsScreenState extends State<SaveSlotsScreen> {
  List<SaveSlotMeta>? _slots;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final slots = await SaveManager.instance.listSlots();
    if (mounted) setState(() => _slots = slots);
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'az önce';
    if (d.inMinutes < 60) return '${d.inMinutes} dk önce';
    if (d.inHours < 24) return '${d.inHours} saat önce';
    return '${d.inDays} gün önce';
  }

  Future<void> _confirmDelete(SaveSlotMeta s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppUi.surface1,
        title: Text('Köyü sil?',
            style: AppUi.title.copyWith(color: AppUi.textHi)),
        content: Text('"${s.name}" kalıcı olarak silinecek.',
            style: AppUi.body.copyWith(color: AppUi.textMid)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Vazgeç', style: TextStyle(color: AppUi.textMid)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Sil', style: TextStyle(color: AppUi.rust)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await SaveManager.instance.deleteSlot(s.id);
      await _reload();
    }
  }

  Future<void> _rename(SaveSlotMeta s) async {
    final ctrl = TextEditingController(text: s.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppUi.surface1,
        title: Text('Köyü yeniden adlandır',
            style: AppUi.title.copyWith(color: AppUi.textHi)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(color: AppUi.textHi),
          decoration: const InputDecoration(hintText: 'Köy adı'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Vazgeç', style: TextStyle(color: AppUi.textMid)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: Text('Kaydet', style: TextStyle(color: AppUi.accent)),
          ),
        ],
      ),
    );
    final trimmed = name?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      await SaveManager.instance.renameSlot(s.id, trimmed);
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final slots = _slots;
    return Scaffold(
      backgroundColor: const Color(0xFF160C28),
      appBar: AppBar(
        backgroundColor: AppUi.surface1,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppUi.textHi),
        title: Text('Kayıtlı Köyler',
            style: AppUi.title.copyWith(color: AppUi.textHi)),
      ),
      body: SafeArea(
        child: slots == null
            ? const Center(child: CircularProgressIndicator())
            : slots.isEmpty
                ? Center(
                    child: Text('Henüz kayıtlı köy yok.',
                        style: AppUi.body.copyWith(color: AppUi.textMid)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: slots.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final s = slots[i];
                      return _SlotCard(
                        meta: s,
                        ago: _ago(s.savedAt),
                        onTap: () => widget.onContinue(s),
                        onRename: () => _rename(s),
                        onDelete: () => _confirmDelete(s),
                      );
                    },
                  ),
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  final SaveSlotMeta meta;
  final String ago;
  final VoidCallback onTap, onRename, onDelete;
  const _SlotCard({
    required this.meta,
    required this.ago,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppUi.radius),
      child: AppPanel(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(meta.name,
                      style: AppUi.bodyHi.copyWith(
                          color: AppUi.textHi, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    '${meta.identity} · ${meta.day}. gün · ${meta.population} kişi',
                    style: AppUi.label.copyWith(color: AppUi.textMid),
                  ),
                  const SizedBox(height: 2),
                  Text(ago, style: AppUi.label.copyWith(color: AppUi.textLo)),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Yeniden adlandır',
              icon: const Icon(Icons.edit_outlined, size: 20),
              color: AppUi.textMid,
              onPressed: onRename,
            ),
            IconButton(
              tooltip: 'Sil',
              icon: const Icon(Icons.delete_outline, size: 20),
              color: AppUi.rust,
              onPressed: onDelete,
            ),
            const Icon(Icons.chevron_right, color: AppUi.accent),
          ],
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
                width: _hover ? 1.5 : 1),
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
              color: lit ? AppUi.sage : AppUi.line, width: lit ? 1.5 : 1),
          boxShadow: lit
              ? [BoxShadow(color: AppUi.sage.withValues(alpha: 0.4), blurRadius: 12)]
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
