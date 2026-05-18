// Bina ışık noktası editörü.
// Çalıştırmak için:
//   flutter run -t lib/tools/light_editor_main.dart
//
// Nasıl kullanılır:
//   • Sol panelden bina seç.
//   • Sprite üzerine tıkla → ışık noktası ekle.
//   • Sağ tık → pencere/fener arasında geçiş yap.
//   • Sağ paneldeki çöp kutusu → noktayı sil.
//   • "Kodu Kopyala" → Dart kodunu panoya alır, building_type.dart'a yapıştır.

import 'dart:math' show min;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../buildings/building_type.dart';

void main() => runApp(const LightEditorApp());

// ─── App shell ───────────────────────────────────────────────────────────────

class LightEditorApp extends StatelessWidget {
  const LightEditorApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Light Editor',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true).copyWith(
          scaffoldBackgroundColor: const Color(0xFF1A1A2E),
          colorScheme: ColorScheme.dark(
            primary: const Color(0xFFFFCC44),
            surface: const Color(0xFF16213E),
          ),
        ),
        home: const LightEditorScreen(),
      );
}

// ─── Data ────────────────────────────────────────────────────────────────────

class _Light {
  double nx, ny;
  LightKind kind;
  _Light(this.nx, this.ny, this.kind);
  _Light copyWith({double? nx, double? ny, LightKind? kind}) =>
      _Light(nx ?? this.nx, ny ?? this.ny, kind ?? this.kind);
}

const Map<BuildingType, String> _kAssets = {
  BuildingType.woodenHouse: 'assets/buildings/minihouse.png',
  BuildingType.mill:        'assets/buildings/mill.png',
  BuildingType.stable:      'assets/buildings/stable.png',
  BuildingType.well:        'assets/buildings/well.png',
  BuildingType.market:      'assets/buildings/market.png',
  BuildingType.townhall:    'assets/buildings/townhall.png',
  BuildingType.tavern:      'assets/buildings/tavern.png',
  BuildingType.fisherCabin: 'assets/buildings/fishercabin.png',
  BuildingType.warehouse:   'assets/buildings/warehouse.png',
  BuildingType.firepit:     'assets/buildings/firepit.png',
};

// ─── Screen ──────────────────────────────────────────────────────────────────

class LightEditorScreen extends StatefulWidget {
  const LightEditorScreen({super.key});
  @override
  State<LightEditorScreen> createState() => _LightEditorScreenState();
}

class _LightEditorScreenState extends State<LightEditorScreen> {
  BuildingType _sel = BuildingType.woodenHouse;
  LightKind _nextKind = LightKind.window;

  /// Her bina için bağımsız ışık listesi
  final Map<BuildingType, List<_Light>> _data = {};

  /// Yüklü sprite'lar
  final Map<BuildingType, ui.Image> _imgs = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // Mevcut kBuildingLights değerlerini başlangıç noktası olarak yükle
    for (final e in kBuildingLights.entries) {
      _data[e.key] =
          e.value.map((l) => _Light(l.nx, l.ny, l.kind)).toList();
    }
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    for (final e in _kAssets.entries) {
      try {
        final bytes = await rootBundle.load(e.value);
        final codec =
            await ui.instantiateImageCodec(bytes.buffer.asUint8List());
        final frame = await codec.getNextFrame();
        _imgs[e.key] = frame.image;
      } catch (_) {}
    }
    if (mounted) setState(() => _loading = false);
  }

  List<_Light> get _current => _data[_sel] ??= [];

  // ── Sprite üzerine tıklama ────────────────────────────────────────────────

  void _onTap(Offset local, Size viewSize) {
    final img = _imgs[_sel];
    if (img == null) return;
    final (nx, ny) = _toNorm(local, viewSize, img);
    setState(() => _current.add(_Light(nx, ny, _nextKind)));
  }

  /// Sağ tık / Ctrl+tık → en yakın noktanın kind'ını değiştir
  void _onSecondary(Offset local, Size viewSize) {
    final img = _imgs[_sel];
    if (img == null) return;
    final (nx, ny) = _toNorm(local, viewSize, img);
    if (_current.isEmpty) return;
    // En yakın ışığı bul
    int best = 0;
    double bestD = double.infinity;
    for (int i = 0; i < _current.length; i++) {
      final dx = _current[i].nx - nx;
      final dy = _current[i].ny - ny;
      final d  = dx * dx + dy * dy;
      if (d < bestD) { bestD = d; best = i; }
    }
    if (bestD < 0.02) {   // ~2% sprite genişliği içindeyse
      setState(() {
        final l = _current[best];
        _current[best] = l.copyWith(
            kind: l.kind == LightKind.window
                ? LightKind.lantern
                : LightKind.window);
      });
    }
  }

  /// Ekran koordinatını 0..1 normalize sprite koordinatına çevirir.
  (double, double) _toNorm(Offset local, Size viewSize, ui.Image img) {
    final imgW  = img.width.toDouble();
    final imgH  = img.height.toDouble();
    final scale = min(viewSize.width / imgW, viewSize.height / imgH);
    final dispW = imgW * scale;
    final dispH = imgH * scale;
    final ox    = (viewSize.width  - dispW) / 2;
    final oy    = (viewSize.height - dispH) / 2;
    final nx    = ((local.dx - ox) / dispW).clamp(0.0, 1.0);
    final ny    = ((local.dy - oy) / dispH).clamp(0.0, 1.0);
    return (nx, ny);
  }

  // ── Dart kodu üret ────────────────────────────────────────────────────────

  String _generateCode() {
    final buf = StringBuffer();
    buf.writeln('const Map<BuildingType, List<BuildingLight>> kBuildingLights = {');
    for (final type in BuildingType.values) {
      if (type == BuildingType.placeholder) continue;
      final list = _data[type];
      if (list == null || list.isEmpty) continue;
      buf.writeln('  BuildingType.${type.name}: [');
      for (final l in list) {
        buf.writeln(
            '    BuildingLight(${l.nx.toStringAsFixed(2)}, '
            '${l.ny.toStringAsFixed(2)}, LightKind.${l.kind.name}),');
      }
      buf.writeln('  ],');
    }
    buf.writeln('};');
    return buf.toString();
  }

  void _copyCode() {
    final code = _generateCode();
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Dart kodu panoya kopyalandı!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F3460),
        title: const Text('Building Light Editor',
            style: TextStyle(color: Color(0xFFFFCC44), fontWeight: FontWeight.bold)),
        actions: [
          // Kind seçici
          _KindToggle(
            value: _nextKind,
            onChanged: (k) => setState(() => _nextKind = k),
          ),
          const SizedBox(width: 8),
          // Tümünü temizle
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
            tooltip: 'Bu binadan tüm ışıkları sil',
            onPressed: () => setState(() => _current.clear()),
          ),
          // Kopyala
          FilledButton.icon(
            onPressed: _copyCode,
            icon: const Icon(Icons.copy),
            label: const Text('Kodu Kopyala'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFFCC44),
              foregroundColor: Colors.black,
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                // ── Sol: Bina listesi ────────────────────────────────────
                _BuildingList(
                  selected: _sel,
                  lightCounts: {
                    for (final e in _data.entries) e.key: e.value.length
                  },
                  onSelect: (t) {
                    setState(() => _sel = t);
                  },
                ),
                // ── Merkez: Sprite görüntüleyici ─────────────────────────
                Expanded(
                  child: _SpriteViewer(
                    image: _imgs[_sel],
                    lights: _current,
                    onTap: _onTap,
                    onSecondaryTap: _onSecondary,
                  ),
                ),
                // ── Sağ: Işık listesi ─────────────────────────────────────
                _LightList(
                  lights: _current,
                  onDelete: (i) => setState(() => _current.removeAt(i)),
                  onToggleKind: (i) => setState(() {
                    final l = _current[i];
                    _current[i] = l.copyWith(
                        kind: l.kind == LightKind.window
                            ? LightKind.lantern
                            : LightKind.window);
                  }),
                ),
              ],
            ),
    );
  }
}

// ─── Sol panel: bina seçici ───────────────────────────────────────────────────

class _BuildingList extends StatelessWidget {
  final BuildingType selected;
  final Map<BuildingType, int> lightCounts;
  final ValueChanged<BuildingType> onSelect;

  const _BuildingList({
    required this.selected,
    required this.lightCounts,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final types = BuildingType.values
        .where((t) => t != BuildingType.placeholder)
        .toList();

    return Container(
      width: 170,
      color: const Color(0xFF0D1B2A),
      child: ListView.builder(
        itemCount: types.length,
        itemBuilder: (_, i) {
          final t = types[i];
          final count = lightCounts[t] ?? 0;
          final active = t == selected;
          return ListTile(
            selected: active,
            selectedTileColor: const Color(0xFF1B3A5C),
            onTap: () => onSelect(t),
            title: Text(
              kBuildingMeta[t]?.label ?? t.name,
              style: TextStyle(
                fontSize: 13,
                color: active ? const Color(0xFFFFCC44) : Colors.white70,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            trailing: count > 0
                ? Container(
                    width: 20, height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFCC44),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('$count',
                        style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black,
                            fontWeight: FontWeight.bold)),
                  )
                : null,
          );
        },
      ),
    );
  }
}

// ─── Merkez: Sprite + ışık overlay ───────────────────────────────────────────

class _SpriteViewer extends StatelessWidget {
  final ui.Image? image;
  final List<_Light> lights;
  final void Function(Offset, Size) onTap;
  final void Function(Offset, Size) onSecondaryTap;

  const _SpriteViewer({
    required this.image,
    required this.lights,
    required this.onTap,
    required this.onSecondaryTap,
  });

  @override
  Widget build(BuildContext context) {
    if (image == null) {
      return const Center(
          child: Text('Sprite yüklenemedi',
              style: TextStyle(color: Colors.white38)));
    }
    return Container(
      color: const Color(0xFF222244),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: AspectRatio(
          aspectRatio: image!.width / image!.height,
          child: LayoutBuilder(builder: (ctx, constraints) {
            final viewSize = Size(constraints.maxWidth, constraints.maxHeight);
            return Listener(
              onPointerDown: (e) {
                if (e.kind == PointerDeviceKind.mouse &&
                    e.buttons == kSecondaryMouseButton) {
                  onSecondaryTap(e.localPosition, viewSize);
                }
              },
              child: GestureDetector(
                onTapDown: (d) => onTap(d.localPosition, viewSize),
                child: CustomPaint(
                  size: viewSize,
                  painter: _SpritePainter(image: image!, lights: lights),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _SpritePainter extends CustomPainter {
  final ui.Image image;
  final List<_Light> lights;
  _SpritePainter({required this.image, required this.lights});

  @override
  void paint(Canvas canvas, Size size) {
    // Sprite
    final src = Rect.fromLTWH(
        0, 0, image.width.toDouble(), image.height.toDouble());
    final scale = min(size.width / image.width, size.height / image.height);
    final dispW = image.width  * scale;
    final dispH = image.height * scale;
    final ox    = (size.width  - dispW) / 2;
    final oy    = (size.height - dispH) / 2;
    final dst   = Rect.fromLTWH(ox, oy, dispW, dispH);

    canvas.drawImageRect(image, src, dst,
        Paint()
          ..filterQuality = FilterQuality.none
          ..isAntiAlias   = false);

    // Checkerboard grid overlay (hafif)
    final gridPaint = Paint()
      ..color = const Color(0x11FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    const steps = 10;
    for (int i = 0; i <= steps; i++) {
      final x = ox + dispW * i / steps;
      final y = oy + dispH * i / steps;
      canvas.drawLine(Offset(x, oy), Offset(x, oy + dispH), gridPaint);
      canvas.drawLine(Offset(ox, y), Offset(ox + dispW, y), gridPaint);
    }

    // Işık noktaları
    for (int idx = 0; idx < lights.length; idx++) {
      final l  = lights[idx];
      final lx = ox + l.nx * dispW;
      final ly = oy + l.ny * dispH;

      final isLantern = l.kind == LightKind.lantern;
      final color     = isLantern
          ? const Color(0xFFFF8800)
          : const Color(0xFFFFEE44);

      // Hale
      canvas.drawCircle(Offset(lx, ly), 14,
          Paint()..color = color.withValues(alpha: 0.18)..isAntiAlias = true);
      // Dış çember
      canvas.drawCircle(Offset(lx, ly), 7,
          Paint()
            ..color       = color.withValues(alpha: 0.85)
            ..style       = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..isAntiAlias = true);
      // Merkez
      canvas.drawCircle(Offset(lx, ly), 3,
          Paint()..color = color..isAntiAlias = true);

      // İkon (W / L)
      final tp = TextPainter(
        text: TextSpan(
          text: isLantern ? 'L' : 'W',
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(lx - tp.width / 2, ly - tp.height / 2 - 12));

      // Numara
      final num = TextPainter(
        text: TextSpan(
          text: '${idx + 1}',
          style: const TextStyle(color: Colors.white70, fontSize: 8),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      num.paint(canvas, Offset(lx - num.width / 2, ly + 9));
    }
  }

  @override
  bool shouldRepaint(_SpritePainter old) =>
      old.image != image || old.lights != lights;
}

// ─── Sağ panel: ışık listesi ──────────────────────────────────────────────────

class _LightList extends StatelessWidget {
  final List<_Light> lights;
  final ValueChanged<int> onDelete;
  final ValueChanged<int> onToggleKind;

  const _LightList({
    required this.lights,
    required this.onDelete,
    required this.onToggleKind,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: const Color(0xFF0D1B2A),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Text('Işık Noktaları',
                style: TextStyle(
                    color: Color(0xFFFFCC44),
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ),
          const Divider(height: 1, color: Color(0xFF1B3A5C)),
          Expanded(
            child: lights.isEmpty
                ? const Center(
                    child: Text(
                      'Sprite üzerine tıklayarak\nışık noktası ekle.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    itemCount: lights.length,
                    itemBuilder: (_, i) => _LightRow(
                      index: i,
                      light: lights[i],
                      onDelete: () => onDelete(i),
                      onToggle: () => onToggleKind(i),
                    ),
                  ),
          ),
          // Yardım ipuçları
          Container(
            color: const Color(0xFF0A1628),
            padding: const EdgeInsets.all(10),
            child: const Text(
              '• Sol tık → ekle\n'
              '• Sağ tık → pencere/fener geçiş\n'
              '• "Kodu Kopyala" → panoya al',
              style: TextStyle(color: Colors.white38, fontSize: 10, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _LightRow extends StatelessWidget {
  final int index;
  final _Light light;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  const _LightRow({
    required this.index,
    required this.light,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isLantern = light.kind == LightKind.lantern;
    final color     = isLantern
        ? const Color(0xFFFF8800)
        : const Color(0xFFFFEE44);
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x221B3A5C))),
      ),
      child: ListTile(
        dense: true,
        leading: GestureDetector(
          onTap: onToggle,
          child: Tooltip(
            message: 'Tıkla: pencere/fener geçiş',
            child: Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Text(
                isLantern ? 'L' : 'W',
                style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
        title: Text(
          '#${index + 1}  ${isLantern ? "Fener" : "Pencere"}',
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
        subtitle: Text(
          'nx=${light.nx.toStringAsFixed(3)}  ny=${light.ny.toStringAsFixed(3)}',
          style: const TextStyle(fontSize: 10, color: Colors.white38),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.close, size: 16, color: Colors.redAccent),
          onPressed: onDelete,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
      ),
    );
  }
}

// ─── Kind seçici (AppBar'da) ──────────────────────────────────────────────────

class _KindToggle extends StatelessWidget {
  final LightKind value;
  final ValueChanged<LightKind> onChanged;

  const _KindToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Eklenecek: ', style: TextStyle(color: Colors.white54, fontSize: 12)),
        _Chip(
          label: 'Pencere',
          icon: Icons.window,
          active: value == LightKind.window,
          color: const Color(0xFFFFEE44),
          onTap: () => onChanged(LightKind.window),
        ),
        const SizedBox(width: 4),
        _Chip(
          label: 'Fener',
          icon: Icons.light,
          active: value == LightKind.lantern,
          color: const Color(0xFFFF8800),
          onTap: () => onChanged(LightKind.lantern),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.icon,
    required this.active,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.25) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? color : Colors.white24,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: active ? color : Colors.white38),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: active ? color : Colors.white38,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
