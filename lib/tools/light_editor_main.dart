// Bina ışık + duman (baca) noktası editörü.
// Çalıştırmak için:
//   flutter run -t lib/tools/light_editor_main.dart
//
// Nasıl kullanılır:
//   • Sol panelden bina seç.
//   • Üst sekmeden "Işık" / "Duman" mode'una geç.
//   • Sprite üzerine tıkla → aktif mode'da nokta ekle.
//   • Sağ tık (ışık): pencere/fener arasında geçiş.
//   • Sağ paneldeki kontrollerle düzenle / sil.
//   • "Kodu Kopyala" → hem kBuildingLights hem kBuildingChimneys panoya alır,
//     building_type.dart'a yapıştır.

import 'dart:async';
import 'dart:io';
import 'dart:math' show min;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../buildings/building_type.dart';

// ─── Otomatik kayıt ──────────────────────────────────────────────────────────
// Editor değişiklikleri 500ms debounce ile doğrudan
// lib/buildings/building_type.dart içine yazar. Çalışması için:
//   • macOS DebugProfile.entitlements'da app-sandbox = false (zaten yapıldı)
//   • Editor binary'sinin altında yukarı doğru pubspec.yaml aranır → proje kökü
//
// Sandbox release entitlement'da hâlâ açık, sadece debug build'leri etkiler.

/// Yürütülebilirden yukarı 25 seviye gezip pubspec.yaml içeren ilk klasörü
/// proje kökü olarak döndürür. Bulamazsa null.
String? _detectProjectRoot() {
  Directory dir = File(Platform.resolvedExecutable).parent;
  for (int i = 0; i < 25; i++) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) return dir.path;
    final parent = dir.parent;
    if (parent.path == dir.path) return null;
    dir = parent;
  }
  return null;
}

void main() => runApp(const LightEditorApp());

// ─── App shell ───────────────────────────────────────────────────────────────

class LightEditorApp extends StatelessWidget {
  const LightEditorApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Light & Smoke Editor',
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

enum EditorMode { lights, chimneys }

class _Light {
  double nx, ny;
  LightKind kind;
  _Light(this.nx, this.ny, this.kind);
  _Light copyWith({double? nx, double? ny, LightKind? kind}) =>
      _Light(nx ?? this.nx, ny ?? this.ny, kind ?? this.kind);
}

class _Chimney {
  double nx, ny;
  double density;
  double rate;
  _Chimney(this.nx, this.ny, {this.density = 1.0, this.rate = 1.0});
}

const Map<BuildingType, String> _kAssets = {
  BuildingType.woodenHouse:    'assets/buildings/minihouse.png',
  BuildingType.stoneHouseBlue: 'assets/buildings/stonehouse_blue.png',
  BuildingType.stoneHouseGreen:'assets/buildings/stonehouse_green.png',
  BuildingType.manor:          'assets/buildings/manor.png',
  BuildingType.mill:           'assets/buildings/mill.png',
  BuildingType.stable:         'assets/buildings/stable.png',
  BuildingType.well:           'assets/buildings/well.png',
  BuildingType.market:         'assets/buildings/market.png',
  BuildingType.townhall:       'assets/buildings/townhall.png',
  BuildingType.tavern:         'assets/buildings/tavern.png',
  BuildingType.fisherCabin:    'assets/buildings/fishercabin.png',
  BuildingType.warehouse:      'assets/buildings/warehouse.png',
  BuildingType.firepit:        'assets/buildings/firepit.png',
  BuildingType.lumberCamp:     'assets/buildings/lumberjack.png',
  BuildingType.mineBuilding:   'assets/buildings/mine.png',
  BuildingType.floristCottage: 'assets/buildings/floristcottage.png',
  BuildingType.chickenCoop:    'assets/buildings/chickencoop.png',
  BuildingType.beehive:        'assets/buildings/beehive.png',
  BuildingType.lamppost:       'assets/buildings/lamppost.png',
  BuildingType.barn:           'assets/buildings/stable.png',
  BuildingType.church:         'assets/buildings/church.png',
  BuildingType.fountain:       'assets/buildings/fountain.png',
  BuildingType.library:        'assets/buildings/library.png',
  BuildingType.bathhouse:      'assets/buildings/bathhouse.png',
  BuildingType.monument:       'assets/buildings/monument.png',
  BuildingType.caravanserai:   'assets/buildings/caravanserai.png',
  BuildingType.shrine:         'assets/buildings/shrine.png',
  BuildingType.belltower:      'assets/buildings/belltower.png',
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
  EditorMode _mode = EditorMode.lights;

  /// Her bina için bağımsız ışık + baca listeleri
  final Map<BuildingType, List<_Light>>   _lightData    = {};
  final Map<BuildingType, List<_Chimney>> _chimneyData  = {};

  /// Yüklü sprite'lar
  final Map<BuildingType, ui.Image> _imgs = {};
  bool _loading = false;

  // ── Auto-save state ──────────────────────────────────────────────────────
  String?  _projectRoot;
  String?  _saveError;
  DateTime? _lastSavedAt;
  bool     _saving = false;
  Timer?   _saveDebounce;

  @override
  void initState() {
    super.initState();
    _projectRoot = _detectProjectRoot();
    // Mevcut kBuildingLights / kBuildingChimneys değerlerini başlangıç noktası
    // olarak yükle ki üzerine çalışılabilsin.
    for (final e in kBuildingLights.entries) {
      _lightData[e.key] =
          e.value.map((l) => _Light(l.nx, l.ny, l.kind)).toList();
    }
    for (final e in kBuildingChimneys.entries) {
      _chimneyData[e.key] = e.value
          .map((c) => _Chimney(c.nx, c.ny, density: c.density, rate: c.rate))
          .toList();
    }
    _loadAll();
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    super.dispose();
  }

  // ── Auto-save ────────────────────────────────────────────────────────────

  /// Çağıran setState'in ardından debounce timer'ı resetler, 500ms'lik
  /// sessizlikten sonra building_type.dart'a yazar.
  void _scheduleSave() {
    if (_projectRoot == null) return;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), _saveNow);
  }

  Future<void> _saveNow() async {
    final root = _projectRoot;
    if (root == null) return;
    final path = '$root/lib/buildings/building_type.dart';
    final file = File(path);
    if (!file.existsSync()) {
      setState(() => _saveError = 'building_type.dart bulunamadı: $path');
      return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final original = await file.readAsString();
      final updated  = _patchSource(original);
      if (updated != original) {
        await file.writeAsString(updated);
      }
      if (!mounted) return;
      setState(() {
        _saving = false;
        _lastSavedAt = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = '$e';
      });
    }
  }

  /// `kBuildingLights` ve `kBuildingChimneys` map bloklarını üretilenle
  /// değiştirir; dosyanın diğer kısımlarına dokunmaz.
  String _patchSource(String src) {
    String out = src;
    out = _replaceBlock(out,
        'const Map<BuildingType, List<BuildingLight>> kBuildingLights = {',
        _generateLightsBlock());
    out = _replaceBlock(out,
        'const Map<BuildingType, List<BuildingChimney>> kBuildingChimneys = {',
        _generateChimneysBlock());
    return out;
  }

  /// [src] içinde [header] ile başlayan map bloğunu (dengeli `{...};`)
  /// [replacement] ile değiştirir.
  String _replaceBlock(String src, String header, String replacement) {
    final start = src.indexOf(header);
    if (start < 0) return src;
    // Açılış `{` header'ın son karakteri.
    int i = start + header.length;
    int depth = 1;
    while (i < src.length && depth > 0) {
      final ch = src[i];
      if (ch == '{') {
        depth++;
      } else if (ch == '}') {
        depth--;
      }
      i++;
    }
    if (depth != 0) return src; // dengesiz → güvenli, dokunma
    // Açılış `{`'tan sonra ilk `;` kapanış `};` için.
    if (i < src.length && src[i] == ';') i++;
    return src.replaceRange(start, i, replacement);
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

  List<_Light>   get _currentLights   => _lightData[_sel]   ??= [];
  List<_Chimney> get _currentChimneys => _chimneyData[_sel] ??= [];

  // ── Sprite üzerine tıklama ────────────────────────────────────────────────

  void _onTap(Offset local, Size viewSize) {
    final img = _imgs[_sel];
    if (img == null) return;
    final (nx, ny) = _toNorm(local, viewSize, img);
    setState(() {
      if (_mode == EditorMode.lights) {
        _currentLights.add(_Light(nx, ny, _nextKind));
      } else {
        _currentChimneys.add(_Chimney(nx, ny));
      }
    });
    _scheduleSave();
  }

  /// Sağ tık → ışık mode'unda en yakın noktanın kind'ını değiştir.
  /// Duman mode'unda etkisiz (kind yok).
  void _onSecondary(Offset local, Size viewSize) {
    if (_mode != EditorMode.lights) return;
    final img = _imgs[_sel];
    if (img == null) return;
    final (nx, ny) = _toNorm(local, viewSize, img);
    if (_currentLights.isEmpty) return;
    int best = 0;
    double bestD = double.infinity;
    for (int i = 0; i < _currentLights.length; i++) {
      final dx = _currentLights[i].nx - nx;
      final dy = _currentLights[i].ny - ny;
      final d  = dx * dx + dy * dy;
      if (d < bestD) { bestD = d; best = i; }
    }
    if (bestD < 0.02) {
      setState(() {
        final l = _currentLights[best];
        _currentLights[best] = l.copyWith(
            kind: l.kind == LightKind.window
                ? LightKind.lantern
                : LightKind.window);
      });
      _scheduleSave();
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

  String _generateLightsBlock() {
    final buf = StringBuffer();
    buf.writeln('const Map<BuildingType, List<BuildingLight>> kBuildingLights = {');
    for (final type in BuildingType.values) {
      if (type == BuildingType.placeholder) continue;
      final list = _lightData[type];
      if (list == null || list.isEmpty) continue;
      buf.writeln('  BuildingType.${type.name}: [');
      for (final l in list) {
        buf.writeln(
            '    BuildingLight(${l.nx.toStringAsFixed(2)}, '
            '${l.ny.toStringAsFixed(2)}, LightKind.${l.kind.name}),');
      }
      buf.writeln('  ],');
    }
    buf.write('};');
    return buf.toString();
  }

  String _generateChimneysBlock() {
    final buf = StringBuffer();
    buf.writeln('const Map<BuildingType, List<BuildingChimney>> kBuildingChimneys = {');
    for (final type in BuildingType.values) {
      if (type == BuildingType.placeholder) continue;
      final list = _chimneyData[type];
      if (list == null || list.isEmpty) continue;
      buf.writeln('  BuildingType.${type.name}: [');
      for (final c in list) {
        final parts = <String>[
          c.nx.toStringAsFixed(2),
          c.ny.toStringAsFixed(2),
        ];
        final extras = <String>[];
        if ((c.density - 1.0).abs() > 0.005) {
          extras.add('density: ${c.density.toStringAsFixed(2)}');
        }
        if ((c.rate - 1.0).abs() > 0.005) {
          extras.add('rate: ${c.rate.toStringAsFixed(2)}');
        }
        final tail = extras.isEmpty ? '' : ', ${extras.join(", ")}';
        buf.writeln('    BuildingChimney(${parts.join(", ")}$tail),');
      }
      buf.writeln('  ],');
    }
    buf.write('};');
    return buf.toString();
  }

  String _generateCode() =>
      '${_generateLightsBlock()}\n\n${_generateChimneysBlock()}';

  void _copyCode() {
    final code = _generateCode();
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Dart kodu panoya kopyalandı (lights + chimneys)!'),
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
        title: const Text('Building Light & Smoke Editor',
            style: TextStyle(color: Color(0xFFFFCC44), fontWeight: FontWeight.bold)),
        actions: [
          // Mode toggle
          _ModeToggle(
            value: _mode,
            onChanged: (m) => setState(() => _mode = m),
          ),
          const SizedBox(width: 12),
          // Light kind seçici (sadece lights mode'unda)
          if (_mode == EditorMode.lights)
            _KindToggle(
              value: _nextKind,
              onChanged: (k) => setState(() => _nextKind = k),
            ),
          const SizedBox(width: 8),
          // Aktif mode için tümünü temizle
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
            tooltip: _mode == EditorMode.lights
                ? 'Bu binadan tüm ışıkları sil'
                : 'Bu binadan tüm bacaları sil',
            onPressed: () {
              setState(() {
                if (_mode == EditorMode.lights) {
                  _currentLights.clear();
                } else {
                  _currentChimneys.clear();
                }
              });
              _scheduleSave();
            },
          ),
          // Auto-save status
          _SaveStatus(
            projectRoot: _projectRoot,
            saving: _saving,
            error: _saveError,
            savedAt: _lastSavedAt,
          ),
          const SizedBox(width: 8),
          // Kopyala (manuel yedek)
          FilledButton.icon(
            onPressed: _copyCode,
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Kopyala'),
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
                    for (final e in _lightData.entries) e.key: e.value.length
                  },
                  chimneyCounts: {
                    for (final e in _chimneyData.entries) e.key: e.value.length
                  },
                  onSelect: (t) {
                    setState(() => _sel = t);
                  },
                ),
                // ── Merkez: Sprite görüntüleyici ─────────────────────────
                Expanded(
                  child: _SpriteViewer(
                    image: _imgs[_sel],
                    lights: _currentLights,
                    chimneys: _currentChimneys,
                    mode: _mode,
                    onTap: _onTap,
                    onSecondaryTap: _onSecondary,
                  ),
                ),
                // ── Sağ: Düzenleme listesi ───────────────────────────────
                _mode == EditorMode.lights
                    ? _LightList(
                        lights: _currentLights,
                        onDelete: (i) {
                          setState(() => _currentLights.removeAt(i));
                          _scheduleSave();
                        },
                        onToggleKind: (i) {
                          setState(() {
                            final l = _currentLights[i];
                            _currentLights[i] = l.copyWith(
                                kind: l.kind == LightKind.window
                                    ? LightKind.lantern
                                    : LightKind.window);
                          });
                          _scheduleSave();
                        },
                      )
                    : _ChimneyList(
                        chimneys: _currentChimneys,
                        onDelete: (i) {
                          setState(() => _currentChimneys.removeAt(i));
                          _scheduleSave();
                        },
                        onDensity: (i, v) {
                          setState(() => _currentChimneys[i].density = v);
                          _scheduleSave();
                        },
                        onRate: (i, v) {
                          setState(() => _currentChimneys[i].rate = v);
                          _scheduleSave();
                        },
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
  final Map<BuildingType, int> chimneyCounts;
  final ValueChanged<BuildingType> onSelect;

  const _BuildingList({
    required this.selected,
    required this.lightCounts,
    required this.chimneyCounts,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final types = BuildingType.values
        .where((t) => t != BuildingType.placeholder)
        .toList();

    return Container(
      width: 200,
      color: const Color(0xFF0D1B2A),
      child: ListView.builder(
        itemCount: types.length,
        itemBuilder: (_, i) {
          final t = types[i];
          final lc = lightCounts[t]   ?? 0;
          final cc = chimneyCounts[t] ?? 0;
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
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (lc > 0) _CountBadge(count: lc, color: const Color(0xFFFFCC44)),
                if (lc > 0 && cc > 0) const SizedBox(width: 4),
                if (cc > 0) _CountBadge(count: cc, color: const Color(0xFFB0A898)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  final Color color;
  const _CountBadge({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20, height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text('$count',
          style: const TextStyle(
              fontSize: 11,
              color: Colors.black,
              fontWeight: FontWeight.bold)),
    );
  }
}

// ─── Merkez: Sprite + overlay ─────────────────────────────────────────────────

class _SpriteViewer extends StatelessWidget {
  final ui.Image? image;
  final List<_Light>   lights;
  final List<_Chimney> chimneys;
  final EditorMode     mode;
  final void Function(Offset, Size) onTap;
  final void Function(Offset, Size) onSecondaryTap;

  const _SpriteViewer({
    required this.image,
    required this.lights,
    required this.chimneys,
    required this.mode,
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
                  painter: _SpritePainter(
                    image: image!,
                    lights: lights,
                    chimneys: chimneys,
                    mode: mode,
                  ),
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
  final List<_Light>   lights;
  final List<_Chimney> chimneys;
  final EditorMode     mode;
  _SpritePainter({
    required this.image,
    required this.lights,
    required this.chimneys,
    required this.mode,
  });

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

    // Alpha: aktif olmayan katman %35 saydam, aktif olan tam.
    final lightAlphaScale    = mode == EditorMode.lights   ? 1.0 : 0.35;
    final chimneyAlphaScale  = mode == EditorMode.chimneys ? 1.0 : 0.35;

    // Aktif olmayan katman önce çizilir → aktif olan üstte kalır.
    if (mode == EditorMode.lights) {
      _paintChimneys(canvas, ox, oy, dispW, dispH, chimneyAlphaScale);
      _paintLights  (canvas, ox, oy, dispW, dispH, lightAlphaScale);
    } else {
      _paintLights  (canvas, ox, oy, dispW, dispH, lightAlphaScale);
      _paintChimneys(canvas, ox, oy, dispW, dispH, chimneyAlphaScale);
    }
  }

  void _paintLights(
      Canvas canvas, double ox, double oy, double dispW, double dispH, double a) {
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
          Paint()..color = color.withValues(alpha: 0.18 * a)..isAntiAlias = true);
      // Dış çember
      canvas.drawCircle(Offset(lx, ly), 7,
          Paint()
            ..color       = color.withValues(alpha: 0.85 * a)
            ..style       = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..isAntiAlias = true);
      // Merkez
      canvas.drawCircle(Offset(lx, ly), 3,
          Paint()..color = color.withValues(alpha: a)..isAntiAlias = true);

      // İkon (W / L)
      final tp = TextPainter(
        text: TextSpan(
          text: isLantern ? 'L' : 'W',
          style: TextStyle(
            color: color.withValues(alpha: a),
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
          style: TextStyle(
              color: Colors.white70.withValues(alpha: a), fontSize: 8),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      num.paint(canvas, Offset(lx - num.width / 2, ly + 9));
    }
  }

  void _paintChimneys(
      Canvas canvas, double ox, double oy, double dispW, double dispH, double a) {
    for (int idx = 0; idx < chimneys.length; idx++) {
      final c  = chimneys[idx];
      final cx = ox + c.nx * dispW;
      final cy = oy + c.ny * dispH;

      // Duman = soğuk gri-mavi.
      const color = Color(0xFFB0A898);

      // Yoğunluğa göre boyut.
      final r = 5 + c.density * 4; // 5..13

      // Hale
      canvas.drawCircle(Offset(cx, cy), r + 8,
          Paint()..color = color.withValues(alpha: 0.15 * a)..isAntiAlias = true);
      // Halka
      canvas.drawCircle(Offset(cx, cy), r,
          Paint()
            ..color       = color.withValues(alpha: 0.85 * a)
            ..style       = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..isAntiAlias = true);
      // Merkez
      canvas.drawCircle(Offset(cx, cy), 2.5,
          Paint()..color = color.withValues(alpha: a)..isAntiAlias = true);

      // Yukarı doğru "duman" hint çizgisi (rate ile orantılı uzar).
      final tail = 10 + c.rate * 8;
      canvas.drawLine(
        Offset(cx, cy - r),
        Offset(cx, cy - r - tail),
        Paint()
          ..color       = color.withValues(alpha: 0.55 * a)
          ..strokeWidth = 1.2
          ..isAntiAlias = true,
      );

      // İkon (S)
      final tp = TextPainter(
        text: TextSpan(
          text: 'S',
          style: TextStyle(
            color: color.withValues(alpha: a),
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2 + r + 4));

      // Numara
      final num = TextPainter(
        text: TextSpan(
          text: '${idx + 1}',
          style: TextStyle(
              color: Colors.white70.withValues(alpha: a), fontSize: 8),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      num.paint(canvas, Offset(cx - num.width / 2, cy + r + 14));
    }
  }

  @override
  bool shouldRepaint(_SpritePainter old) =>
      old.image    != image    ||
      old.lights   != lights   ||
      old.chimneys != chimneys ||
      old.mode     != mode;
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
      width: 240,
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

// ─── Sağ panel: baca (duman) listesi ──────────────────────────────────────────

class _ChimneyList extends StatelessWidget {
  final List<_Chimney> chimneys;
  final ValueChanged<int> onDelete;
  final void Function(int, double) onDensity;
  final void Function(int, double) onRate;

  const _ChimneyList({
    required this.chimneys,
    required this.onDelete,
    required this.onDensity,
    required this.onRate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      color: const Color(0xFF0D1B2A),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Text('Baca / Duman Noktaları',
                style: TextStyle(
                    color: Color(0xFFB0A898),
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ),
          const Divider(height: 1, color: Color(0xFF1B3A5C)),
          Expanded(
            child: chimneys.isEmpty
                ? const Center(
                    child: Text(
                      'Sprite üzerine tıklayarak\nbaca noktası ekle.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    itemCount: chimneys.length,
                    itemBuilder: (_, i) => _ChimneyRow(
                      index: i,
                      chimney: chimneys[i],
                      onDelete: () => onDelete(i),
                      onDensity: (v) => onDensity(i, v),
                      onRate: (v) => onRate(i, v),
                    ),
                  ),
          ),
          Container(
            color: const Color(0xFF0A1628),
            padding: const EdgeInsets.all(10),
            child: const Text(
              '• Sol tık → ekle\n'
              '• density: partikül yoğunluğu (0.3 ince — 2.5 yoğun)\n'
              '• rate: yayılma hızı (0.3 yavaş — 2.0 hızlı)\n'
              '• "Kodu Kopyala" → panoya al',
              style: TextStyle(color: Colors.white38, fontSize: 10, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChimneyRow extends StatelessWidget {
  final int index;
  final _Chimney chimney;
  final VoidCallback onDelete;
  final ValueChanged<double> onDensity;
  final ValueChanged<double> onRate;

  const _ChimneyRow({
    required this.index,
    required this.chimney,
    required this.onDelete,
    required this.onDensity,
    required this.onRate,
  });

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFFB0A898);
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x221B3A5C))),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color, width: 1.5),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'S',
                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#${index + 1}  Baca',
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                    Text(
                      'nx=${chimney.nx.toStringAsFixed(3)}  ny=${chimney.ny.toStringAsFixed(3)}',
                      style: const TextStyle(fontSize: 10, color: Colors.white38),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 16, color: Colors.redAccent),
                onPressed: onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _MiniSlider(
            label: 'density',
            value: chimney.density,
            min: 0.3,
            max: 2.5,
            onChanged: onDensity,
          ),
          _MiniSlider(
            label: 'rate',
            value: chimney.rate,
            min: 0.3,
            max: 2.0,
            onChanged: onRate,
          ),
        ],
      ),
    );
  }
}

class _MiniSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _MiniSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 50,
          child: Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 10)),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor:   const Color(0xFFB0A898),
              inactiveTrackColor: Colors.white12,
              thumbColor:         const Color(0xFFB0A898),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            value.toStringAsFixed(2),
            style: const TextStyle(color: Colors.white70, fontSize: 10),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

// ─── Auto-save status göstergesi ──────────────────────────────────────────────

class _SaveStatus extends StatelessWidget {
  final String?   projectRoot;
  final bool      saving;
  final String?   error;
  final DateTime? savedAt;

  const _SaveStatus({
    required this.projectRoot,
    required this.saving,
    required this.error,
    required this.savedAt,
  });

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color color;
    final String label;
    final String tooltip;

    if (projectRoot == null) {
      icon = Icons.cloud_off;
      color = Colors.orangeAccent;
      label = 'Manuel';
      tooltip = 'Proje kökü bulunamadı. Kopyala butonuyla manuel yapıştır.';
    } else if (error != null) {
      icon = Icons.error_outline;
      color = Colors.redAccent;
      label = 'Hata';
      tooltip = 'Yazılamadı: $error';
    } else if (saving) {
      icon = Icons.cloud_upload;
      color = Colors.lightBlueAccent;
      label = 'Kaydediliyor';
      tooltip = 'building_type.dart güncelleniyor…';
    } else if (savedAt != null) {
      icon = Icons.cloud_done;
      color = const Color(0xFF8FE08F);
      final s = _formatTime(savedAt!);
      label = s;
      tooltip = 'Son kayıt: ${savedAt!.toIso8601String()}\n$projectRoot';
    } else {
      icon = Icons.cloud_outlined;
      color = Colors.white54;
      label = 'Hazır';
      tooltip = 'Auto-save aktif. Değişiklik bekleniyor.\n$projectRoot';
    }

    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.55), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    final s = t.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

// ─── Mode toggle (Lights / Chimneys) ──────────────────────────────────────────

class _ModeToggle extends StatelessWidget {
  final EditorMode value;
  final ValueChanged<EditorMode> onChanged;

  const _ModeToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ModeChip(
          label: 'Işık',
          icon: Icons.lightbulb,
          active: value == EditorMode.lights,
          color: const Color(0xFFFFCC44),
          onTap: () => onChanged(EditorMode.lights),
        ),
        const SizedBox(width: 4),
        _ModeChip(
          label: 'Duman',
          icon: Icons.cloud,
          active: value == EditorMode.chimneys,
          color: const Color(0xFFB0A898),
          onTap: () => onChanged(EditorMode.chimneys),
        ),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const _ModeChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.30) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? color : Colors.white24,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: active ? color : Colors.white38),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: active ? color : Colors.white60,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Light kind seçici (AppBar'da, sadece lights mode'unda) ──────────────────

class _KindToggle extends StatelessWidget {
  final LightKind value;
  final ValueChanged<LightKind> onChanged;

  const _KindToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Tip: ', style: TextStyle(color: Colors.white54, fontSize: 12)),
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
