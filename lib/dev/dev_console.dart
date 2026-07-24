import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../ui/app_ui.dart';
import 'dev_command.dart';

/// Geliştirici komut konsolu — backtick (`) ile açılan quake-style overlay.
///
/// Buton çöplüğü yerine tek arama kutusu: yaz → süz → Enter. Parametreli
/// komutlar inline form açar. Alt şerit KAYIT/OYNAT: bir DURUMU (kış+kıtlık+
/// imparatorluk gibi) bir kez kur, isimlendir, tek tıkla tekrar oynat.
///
/// Sahneden bağımsız: komut listesini + kaydediciyi + senaryoları props olarak
/// alır, sadece [onRun] / [onRunScript] geri çağırır.
class DevConsole extends StatefulWidget {
  final List<DevCommand> commands;
  final DevRecorder recorder;
  final List<DevScript> scripts;

  /// Bir komutu çözülmüş argümanlarla çalıştır (sahne kayıt da yapar).
  final void Function(DevCommand cmd, DevArgs args) onRun;

  /// Kaydedilmiş bir senaryoyu baştan sona oynat.
  final void Function(DevScript script) onRunScript;

  /// Mevcut kaydı isimlendirip kalıcı senaryoya çevir.
  final void Function(String name) onSaveScript;

  /// Kaydedilmiş bir senaryoyu sil (built-in'lerde çağrılmaz).
  final void Function(DevScript script) onDeleteScript;

  final VoidCallback onClose;

  const DevConsole({
    super.key,
    required this.commands,
    required this.recorder,
    required this.scripts,
    required this.onRun,
    required this.onRunScript,
    required this.onSaveScript,
    required this.onDeleteScript,
    required this.onClose,
  });

  @override
  State<DevConsole> createState() => _DevConsoleState();
}

// Klavye niyetleri (arama alanı odakken bile Shortcuts ile yakalanır).
class _MoveIntent extends Intent {
  final int delta;
  const _MoveIntent(this.delta);
}

class _CloseIntent extends Intent {
  const _CloseIntent();
}

class _DevConsoleState extends State<DevConsole> {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  final _scrollCtrl = ScrollController();

  String _query = '';
  int _selected = 0;

  // Parametre düzenlenen komut (null = liste modu).
  DevCommand? _paramFor;
  Map<String, Object?> _paramValues = {};

  @override
  void initState() {
    super.initState();
    widget.recorder.addListener(_onRecorderChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    widget.recorder.removeListener(_onRecorderChanged);
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onRecorderChanged() {
    if (mounted) setState(() {});
  }

  // ── Filtreleme (basit alt-dizi eşleşmesi, Türkçe-duyarsız) ────────────────
  List<DevCommand> get _filtered {
    final q = _norm(_query);
    if (q.isEmpty) return widget.commands;
    final hits = <DevCommand>[];
    for (final c in widget.commands) {
      if (_match(q, _norm('${c.label} ${c.id} ${c.category.label}'))) {
        hits.add(c);
      }
    }
    return hits;
  }

  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('ş', 's')
      .replaceAll('ç', 'c')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ö', 'o');

  // q'nun her harfi t içinde sırayla geçiyor mu (fuzzy).
  static bool _match(String q, String t) {
    var i = 0;
    for (var j = 0; j < t.length && i < q.length; j++) {
      if (t[j] == q[i]) i++;
    }
    return i == q.length;
  }

  void _move(int delta) {
    final list = _filtered;
    if (list.isEmpty) return;
    setState(() => _selected = (_selected + delta).clamp(0, list.length - 1));
    // Seçili öğeyi görünürde tut (kaba kaydırma).
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        (_selected * 52.0 - 100).clamp(0.0, _scrollCtrl.position.maxScrollExtent),
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
      );
    }
  }

  void _activateSelected() {
    final list = _filtered;
    if (list.isEmpty || _selected >= list.length) return;
    _open(list[_selected]);
  }

  void _open(DevCommand cmd) {
    if (cmd.hasParams) {
      setState(() {
        _paramFor = cmd;
        _paramValues = cmd.defaultArgs();
      });
    } else {
      widget.onRun(cmd, const DevArgs());
      // Komut çalışsa da konsol açık kalsın — arka arkaya tetiklemek için.
    }
  }

  void _runParamCommand() {
    final cmd = _paramFor;
    if (cmd == null) return;
    widget.onRun(cmd, DevArgs(Map.of(_paramValues)));
    setState(() => _paramFor = null);
    _searchFocus.requestFocus();
  }

  // ── Kayıt: isimle dondur ──────────────────────────────────────────────────
  Future<void> _promptSave() async {
    final ctrl = TextEditingController(text: 'Senaryo ${widget.scripts.length + 1}');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppUi.surface1,
        title: const Text('Senaryoyu Kaydet', style: AppUi.title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: AppUi.body,
          decoration: _fieldDecoration('İsim'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Vazgeç', style: TextStyle(color: AppUi.textMid)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Kaydet', style: TextStyle(color: AppUi.accent)),
          ),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      widget.onSaveScript(name.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.arrowDown): _MoveIntent(1),
          SingleActivator(LogicalKeyboardKey.arrowUp): _MoveIntent(-1),
          SingleActivator(LogicalKeyboardKey.escape): _CloseIntent(),
        },
        child: Actions(
          actions: {
            _MoveIntent: CallbackAction<_MoveIntent>(
              onInvoke: (i) {
                _move(i.delta);
                return null;
              },
            ),
            _CloseIntent: CallbackAction<_CloseIntent>(
              onInvoke: (_) {
                if (_paramFor != null) {
                  setState(() => _paramFor = null);
                } else {
                  widget.onClose();
                }
                return null;
              },
            ),
          },
          child: Stack(
            children: [
              // Arka karartma — dokununca kapat.
              Positioned.fill(
                child: GestureDetector(
                  onTap: widget.onClose,
                  child: Container(color: AppUi.scrim),
                ),
              ),
              Align(
                alignment: const Alignment(0, -0.35),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680, maxHeight: 560),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: AppPanel(
                      padding: const EdgeInsets.all(0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _header(),
                          if (_paramFor != null)
                            _paramForm(_paramFor!)
                          else
                            Flexible(child: _commandList()),
                          _recorderStrip(),
                        ],
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

  // ── Başlık + arama ────────────────────────────────────────────────────────
  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: const BoxDecoration(
        color: AppUi.surface2,
        border: Border(bottom: BorderSide(color: AppUi.line)),
      ),
      child: Row(
        children: [
          const Icon(Icons.terminal, size: 18, color: AppUi.accent),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              style: AppUi.body,
              cursorColor: AppUi.accent,
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Komut ara… (↑↓ gez, Enter çalıştır, Esc kapat)',
                hintStyle: TextStyle(color: AppUi.textLo, fontFamily: AppUi.fontText),
              ),
              onChanged: (v) => setState(() {
                _query = v;
                _selected = 0;
              }),
              onSubmitted: (_) => _activateSelected(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: AppUi.textMid),
            onPressed: widget.onClose,
          ),
        ],
      ),
    );
  }

  // ── Komut listesi ─────────────────────────────────────────────────────────
  Widget _commandList() {
    final list = _filtered;
    if (list.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(28),
        child: Text('Eşleşen komut yok', style: TextStyle(color: AppUi.textLo)),
      );
    }
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final c = list[i];
        final sel = i == _selected;
        return InkWell(
          onTap: () {
            setState(() => _selected = i);
            _open(c);
          },
          child: Container(
            color: sel ? AppUi.surface3 : Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 30,
                  color: sel ? AppUi.accent : Colors.transparent,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              c.label,
                              style: TextStyle(
                                fontFamily: AppUi.fontText,
                                fontSize: 14.5,
                                color: sel ? AppUi.textHi : AppUi.textMid,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (c.hasParams) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.tune, size: 13, color: AppUi.textLo),
                          ],
                        ],
                      ),
                      if (c.hint != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Text(
                            c.hint!,
                            style: const TextStyle(
                                color: AppUi.textLo, fontSize: 11.5, fontFamily: AppUi.fontText),
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  c.category.label,
                  style: const TextStyle(
                      color: AppUi.textLo, fontSize: 10.5, fontFamily: AppUi.fontText),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Parametre formu ───────────────────────────────────────────────────────
  Widget _paramForm(DevCommand cmd) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(cmd.label, style: AppUi.title),
          if (cmd.hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 4),
              child: Text(cmd.hint!,
                  style: const TextStyle(color: AppUi.textLo, fontSize: 12)),
            ),
          const SizedBox(height: 10),
          for (final p in cmd.params) _paramField(p),
          const SizedBox(height: 12),
          Row(
            children: [
              AppButton(
                label: 'Çalıştır',
                icon: GameIconData.chevron,
                onTap: _runParamCommand,
              ),
              const SizedBox(width: 8),
              AppButton(
                label: 'Geri',
                kind: AppButtonKind.ghost,
                onTap: () => setState(() => _paramFor = null),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _paramField(DevParam p) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            child: Text(p.label,
                style: const TextStyle(color: AppUi.textMid, fontSize: 13)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: p.type == DevParamType.integer
                ? _intControl(p)
                : _choiceControl(p),
          ),
        ],
      ),
    );
  }

  Widget _intControl(DevParam p) {
    final v = (_paramValues[p.key] as int?) ?? p.intDefault;
    void set(int nv) => setState(
        () => _paramValues[p.key] = nv.clamp(p.intMin, p.intMax));
    return Row(
      children: [
        _stepBtn(Icons.remove, () => set(v - 1)),
        Container(
          width: 56,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text('$v',
              style: const TextStyle(
                  color: AppUi.textHi, fontSize: 16, fontFamily: AppUi.fontText)),
        ),
        _stepBtn(Icons.add, () => set(v + 1)),
      ],
    );
  }

  Widget _stepBtn(IconData ic, VoidCallback onTap) => InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppUi.surface2,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppUi.line),
          ),
          child: Icon(ic, size: 16, color: AppUi.textMid),
        ),
      );

  Widget _choiceControl(DevParam p) {
    final cur = (_paramValues[p.key] as String?) ?? p.defaultValue().toString();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final (val, lbl) in p.choices)
          GestureDetector(
            onTap: () => setState(() => _paramValues[p.key] = val),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: val == cur ? AppUi.accent : AppUi.surface2,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: val == cur ? AppUi.accent : AppUi.line),
              ),
              child: Text(
                lbl,
                style: TextStyle(
                  color: val == cur ? AppUi.ink : AppUi.textMid,
                  fontSize: 12.5,
                  fontFamily: AppUi.fontText,
                  fontWeight: val == cur ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── Kayıt / oynatma şeridi ────────────────────────────────────────────────
  Widget _recorderStrip() {
    final rec = widget.recorder;
    return Container(
      decoration: const BoxDecoration(
        color: AppUi.surface0,
        border: Border(top: BorderSide(color: AppUi.line)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: rec.toggle,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: rec.recording ? AppUi.rust : AppUi.surface2,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: rec.recording ? AppUi.rust : AppUi.line),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fiber_manual_record,
                          size: 13,
                          color: rec.recording ? Colors.white : AppUi.textLo),
                      const SizedBox(width: 6),
                      Text(
                        rec.recording ? 'KAYIT · ${rec.steps.length}' : 'Kayda Başla',
                        style: TextStyle(
                          color: rec.recording ? Colors.white : AppUi.textMid,
                          fontSize: 12,
                          fontFamily: AppUi.fontText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (rec.steps.isNotEmpty) ...[
                AppButton(
                  label: 'Kaydet',
                  kind: AppButtonKind.tonal,
                  onTap: _promptSave,
                ),
                const SizedBox(width: 6),
                AppButton(
                  label: 'Temizle',
                  kind: AppButtonKind.ghost,
                  onTap: rec.clear,
                ),
              ],
              const Spacer(),
              Text('${widget.commands.length} komut',
                  style: const TextStyle(color: AppUi.textLo, fontSize: 11)),
            ],
          ),
          if (widget.scripts.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('SENARYOLAR',
                style: TextStyle(
                    color: AppUi.textLo,
                    fontSize: 10,
                    letterSpacing: 1.2,
                    fontFamily: AppUi.fontText,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in widget.scripts)
                  GestureDetector(
                    onTap: () => widget.onRunScript(s),
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppUi.surface2,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppUi.line),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_arrow,
                              size: 15,
                              color: s.builtin ? AppUi.gold : AppUi.sage),
                          const SizedBox(width: 4),
                          Text(s.name,
                              style: const TextStyle(
                                  color: AppUi.textMid,
                                  fontSize: 12,
                                  fontFamily: AppUi.fontText)),
                          const SizedBox(width: 4),
                          Text('${s.steps.length}',
                              style: const TextStyle(
                                  color: AppUi.textLo, fontSize: 10)),
                          // Kaydedilmişler silinebilir; built-in'ler kodda gömülü.
                          if (!s.builtin) ...[
                            const SizedBox(width: 2),
                            GestureDetector(
                              onTap: () => widget.onDeleteScript(s),
                              child: const Padding(
                                padding: EdgeInsets.only(left: 2),
                                child: Icon(Icons.close,
                                    size: 13, color: AppUi.textLo),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: const TextStyle(color: AppUi.textLo),
        enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: AppUi.line)),
        focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: AppUi.accent)),
      );
}
