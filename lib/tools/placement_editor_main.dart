// Bina YERLEŞİM / EBAT editörü.
// Çalıştırmak için:
//   flutter run -t lib/tools/placement_editor_main.dart
//
// Ne işe yarar:
//   • Her bina için spriteScale / groundY / groundXCenter değerlerini görsel
//     ayarlarsın. Ortadaki önizleme, OYUNUN GERÇEK izometrik matematiğiyle
//     footprint tile ızgarasını + diamond'ı çizer; sprite tam oyundaki gibi
//     yerleşir. Böylece "footprint'e sığıyor mu, taşıyor mu, havada mı duruyor"
//     sorusunu doğrudan görürsün.
//
// Nasıl kullanılır:
//   • Sol panelden bina seç.
//   • Sağ panelden slider'larla ayarla VEYA sprite'ı fareyle sürükle
//     (yatay → groundXCenter, dikey → groundY).
//   • Fare tekeri → yakınlaştır/uzaklaştır.
//   • Değişiklikler 500ms sonra otomatik building_type.dart'a yazılır
//     (light editor ile aynı auto-save mekanizması). "Kopyala" manuel yedek.

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../buildings/building_type.dart';
import '../core/constants.dart' show kTileW, kTileH;

// ─── Proje kökü tespiti (auto-save için) ─────────────────────────────────────
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

void main() => runApp(const PlacementEditorApp());

class PlacementEditorApp extends StatelessWidget {
  const PlacementEditorApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Placement & Size Editor',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true).copyWith(
          scaffoldBackgroundColor: const Color(0xFF1A1A2E),
          colorScheme: ColorScheme.dark(
            primary: const Color(0xFF66D9A0),
            surface: const Color(0xFF16213E),
          ),
        ),
        home: const PlacementEditorScreen(),
      );
}

// Light editor ile aynı asset tablosu.
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
  BuildingType.barn:           'assets/buildings/barn.png',
  BuildingType.church:         'assets/buildings/church.png',
  BuildingType.tent:           'assets/buildings/tent.png',
  BuildingType.fountain:       'assets/buildings/fountain.png',
  BuildingType.library:        'assets/buildings/library.png',
  BuildingType.bathhouse:      'assets/buildings/bathhouse.png',
  BuildingType.monument:       'assets/buildings/monument.png',
  BuildingType.dock:           'assets/buildings/dock.png',
  BuildingType.caravanserai:   'assets/buildings/caravanserai.png',
  BuildingType.shrine:         'assets/buildings/shrine.png',
  BuildingType.belltower:      'assets/buildings/belltower.png',
};

// Bina başına düzenlenen geometri durumu.
class _Geom {
  int cols, rows;
  double scale, groundY, groundXCenter;
  _Geom(this.cols, this.rows, this.scale, this.groundY, this.groundXCenter);
}

class PlacementEditorScreen extends StatefulWidget {
  const PlacementEditorScreen({super.key});
  @override
  State<PlacementEditorScreen> createState() => _PlacementEditorScreenState();
}

class _PlacementEditorScreenState extends State<PlacementEditorScreen> {
  BuildingType _sel = BuildingType.stoneHouseBlue;
  final Map<BuildingType, ui.Image> _imgs = {};
  final Map<BuildingType, _Geom> _geom = {};
  bool _loading = false;
  double _zoom = 1.6;

  String?  _projectRoot;
  String?  _saveError;
  DateTime? _lastSavedAt;
  bool     _saving = false;
  Timer?   _saveDebounce;

  @override
  void initState() {
    super.initState();
    _projectRoot = _detectProjectRoot();
    // Mevcut meta değerlerini başlangıç olarak al.
    for (final t in BuildingType.values) {
      final m = kBuildingMeta[t];
      if (m == null) continue;
      _geom[t] = _Geom(m.cols, m.rows, m.spriteScale, m.groundY, m.groundXCenter);
    }
    _loadAll();
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    for (final e in _kAssets.entries) {
      try {
        final bytes = await rootBundle.load(e.value);
        final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
        final frame = await codec.getNextFrame();
        _imgs[e.key] = frame.image;
      } catch (_) {}
    }
    if (mounted) setState(() => _loading = false);
  }

  _Geom get _g => _geom[_sel]!;
  ui.Image? get _img => _imgs[_sel];

  void _edit(void Function(_Geom) f) {
    setState(() => f(_g));
    _scheduleSave();
  }

  // ── Auto-save ──────────────────────────────────────────────────────────────
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
      setState(() => _saveError = 'building_type.dart yok: $path');
      return;
    }
    setState(() { _saving = true; _saveError = null; });
    try {
      final original = await file.readAsString();
      final updated = _patchMeta(original, _sel.name, _g);
      if (updated != original) await file.writeAsString(updated);
      if (!mounted) return;
      setState(() { _saving = false; _lastSavedAt = DateTime.now(); });
    } catch (e) {
      if (!mounted) return;
      setState(() { _saving = false; _saveError = '$e'; });
    }
  }

  /// `BuildingType.<name>: BuildingMeta( ... )` bloğunda yalnızca spriteScale /
  /// groundY / groundXCenter alanlarını günceller; varsa değiştirir, yoksa ekler.
  /// Dengeli parantez taraması iç içe `ResourceCost(...)`'u doğru atlar.
  String _patchMeta(String src, String typeName, _Geom g) {
    final header = 'BuildingType.$typeName: BuildingMeta(';
    final start = src.indexOf(header);
    if (start < 0) return src;
    int i = start + header.length;
    int depth = 1;
    while (i < src.length && depth > 0) {
      final ch = src[i];
      if (ch == '(') {
        depth++;
      } else if (ch == ')') {
        depth--;
      }
      i++;
    }
    if (depth != 0) return src; // dengesiz → dokunma
    final bodyStart = start + header.length;
    final bodyEnd = i - 1; // kapanış ')' indeksi
    String body = src.substring(bodyStart, bodyEnd);
    body = _setField(body, 'cols', '${g.cols}');
    body = _setField(body, 'rows', '${g.rows}');
    body = _setField(body, 'spriteScale', _fmt(g.scale));
    body = _setField(body, 'groundY', _fmt(g.groundY));
    body = _setField(body, 'groundXCenter', _fmt(g.groundXCenter));
    return src.replaceRange(bodyStart, bodyEnd, body);
  }

  String _setField(String body, String name, String v) {
    final re = RegExp('$name\\s*:\\s*[-\\d.]+');
    if (re.hasMatch(body)) {
      return body.replaceFirst(re, '$name: $v');
    }
    // Yoksa gövdenin başına ekle (BuildingMeta('dan hemen sonra).
    return '\n    $name: $v,$body';
  }

  String _fmt(double v) {
    var s = v.toStringAsFixed(4);
    if (s.contains('.')) {
      s = s.replaceAll(RegExp(r'0+$'), '');
      if (s.endsWith('.')) s += '0';
    }
    return s;
  }

  void _copy() {
    final g = _g;
    final code = 'cols: ${g.cols}, rows: ${g.rows}, '
        'groundY: ${_fmt(g.groundY)}, '
        'groundXCenter: ${_fmt(g.groundXCenter)}, '
        'spriteScale: ${_fmt(g.scale)},';
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Panoya: $code'), duration: const Duration(seconds: 2)),
    );
  }

  void _resetToSaved() {
    final m = kBuildingMeta[_sel]!;
    _edit((g) {
      g.cols = m.cols;
      g.rows = m.rows;
      g.scale = m.spriteScale;
      g.groundY = m.groundY;
      g.groundXCenter = m.groundXCenter;
    });
  }

  // Sürükleme: sprite'ı kaydır → groundXCenter / groundY.
  void _dragSprite(Offset delta) {
    final img = _img;
    if (img == null) return;
    final spriteW = (_g.cols + _g.rows) * (kTileW / 2) * _zoom * _g.scale;
    final spriteH = spriteW * img.height / img.width;
    if (spriteW <= 0 || spriteH <= 0) return;
    _edit((g) {
      g.groundXCenter = (g.groundXCenter - delta.dx / spriteW).clamp(-0.2, 1.2);
      g.groundY = (g.groundY - delta.dy / spriteH).clamp(0.5, 1.5);
    });
  }

  @override
  Widget build(BuildContext context) {
    final meta = kBuildingMeta[_sel];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F3460),
        title: const Text('Bina Yerleşim & Ebat Editörü',
            style: TextStyle(color: Color(0xFF66D9A0), fontWeight: FontWeight.bold)),
        actions: [
          _SaveStatus(projectRoot: _projectRoot, saving: _saving,
              error: _saveError, savedAt: _lastSavedAt),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _copy,
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Kopyala'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF66D9A0), foregroundColor: Colors.black),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                // ── Sol: bina listesi ────────────────────────────────────────
                _BuildingList(
                  selected: _sel,
                  onSelect: (t) => setState(() => _sel = t),
                ),
                // ── Merkez: önizleme ────────────────────────────────────────
                Expanded(
                  child: Listener(
                    onPointerSignal: (e) {
                      if (e is PointerScrollEvent) {
                        setState(() => _zoom =
                            (_zoom - e.scrollDelta.dy / 600).clamp(0.5, 4.0));
                      }
                    },
                    child: GestureDetector(
                      onPanUpdate: (d) => _dragSprite(d.delta),
                      child: Container(
                        color: const Color(0xFF20303A),
                        child: CustomPaint(
                          painter: _PreviewPainter(
                            image: _img,
                            cols: _g.cols,
                            rows: _g.rows,
                            scale: _g.scale,
                            groundY: _g.groundY,
                            groundXCenter: _g.groundXCenter,
                            zoom: _zoom,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  ),
                ),
                // ── Sağ: kontroller ─────────────────────────────────────────
                _Controls(
                  label: meta?.label ?? _sel.name,
                  geom: _g,
                  zoom: _zoom,
                  onCols: (v) => _edit((g) => g.cols = v),
                  onRows: (v) => _edit((g) => g.rows = v),
                  onScale: (v) => _edit((g) => g.scale = v),
                  onGroundY: (v) => _edit((g) => g.groundY = v),
                  onGroundX: (v) => _edit((g) => g.groundXCenter = v),
                  onZoom: (v) => setState(() => _zoom = v),
                  onReset: _resetToSaved,
                ),
              ],
            ),
    );
  }
}

// ─── Merkez önizleme: gerçek iso footprint + sprite ──────────────────────────
class _PreviewPainter extends CustomPainter {
  final ui.Image? image;
  final int cols, rows;
  final double scale, groundY, groundXCenter, zoom;
  _PreviewPainter({
    required this.image,
    required this.cols,
    required this.rows,
    required this.scale,
    required this.groundY,
    required this.groundXCenter,
    required this.zoom,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final hw = kTileW / 2 * zoom; // yarı tile genişliği (ekran)
    final hh = kTileH / 2 * zoom; // yarı tile yüksekliği

    // Footprint merkezini ekranın biraz altına yerleştir (uzun sprite üste taşar).
    final centerGx = cols / 2, centerGy = rows / 2;
    final cv = Offset((centerGx - centerGy) * hw, (centerGx + centerGy) * hh);
    final origin = Offset(size.width / 2 - cv.dx, size.height * 0.64 - cv.dy);

    Offset sp(double gx, double gy) =>
        origin + Offset((gx - gy) * hw, (gx + gy) * hh);

    // 1) Zemin tile ızgarası (footprint çevresi).
    final gridPaint = Paint()
      ..color = const Color(0x22FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (int a = -4; a < cols + 4; a++) {
      for (int b = -4; b < rows + 4; b++) {
        final p = Path()
          ..moveTo(sp(a.toDouble(), b.toDouble()).dx, sp(a.toDouble(), b.toDouble()).dy)
          ..lineTo(sp((a + 1).toDouble(), b.toDouble()).dx, sp((a + 1).toDouble(), b.toDouble()).dy)
          ..lineTo(sp((a + 1).toDouble(), (b + 1).toDouble()).dx, sp((a + 1).toDouble(), (b + 1).toDouble()).dy)
          ..lineTo(sp(a.toDouble(), (b + 1).toDouble()).dx, sp(a.toDouble(), (b + 1).toDouble()).dy)
          ..close();
        canvas.drawPath(p, gridPaint);
      }
    }

    // Footprint köşeleri (oyun _corners ile aynı: col=row=0).
    final back  = sp(0, 0);
    final left  = sp(0, rows.toDouble());
    final right = sp(cols.toDouble(), 0);
    final front = sp(cols.toDouble(), rows.toDouble());

    // 2) Footprint dolgusu (sprite ALTINA).
    final fp = Path()
      ..moveTo(back.dx, back.dy)
      ..lineTo(right.dx, right.dy)
      ..lineTo(front.dx, front.dy)
      ..lineTo(left.dx, left.dy)
      ..close();
    canvas.drawPath(fp, Paint()..color = const Color(0x3366D9A0));

    // 3) Sprite — oyunun _drawSprite matematiğiyle bire bir.
    final img = image;
    if (img != null) {
      final spriteW = (right.dx - left.dx).abs() * scale;
      final spriteH = spriteW * img.height / img.width;
      final dst = Rect.fromLTWH(
        front.dx - spriteW * groundXCenter,
        front.dy - spriteH * groundY,
        spriteW,
        spriteH,
      );
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        dst,
        Paint()..filterQuality = FilterQuality.medium,
      );
    }

    // 4) Footprint kenarı (sprite ÜSTÜNE — hizayı görmek için).
    canvas.drawPath(fp, Paint()
      ..color = const Color(0xFF66D9A0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
    // Ön köşe (anchor) işareti.
    canvas.drawCircle(front, 5, Paint()..color = const Color(0xFFFFD54A));
    // Footprint merkezinden dikey kılavuz.
    final cx = (back.dx + front.dx) / 2;
    canvas.drawLine(
      Offset(cx, front.dy + 20),
      Offset(cx, front.dy - 360 * zoom),
      Paint()..color = const Color(0x33FFD54A)..strokeWidth = 1,
    );

    // 5) Bilgi yazısı.
    final tp = TextPainter(
      text: TextSpan(
        text: '$cols×$rows footprint · zoom ${zoom.toStringAsFixed(1)}×\n'
            'sürükle: sprite · tekerlek: zoom',
        style: const TextStyle(color: Colors.white38, fontSize: 12, height: 1.4),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, const Offset(16, 16));
  }

  @override
  bool shouldRepaint(_PreviewPainter old) =>
      old.image != image ||
      old.cols != cols || old.rows != rows ||
      old.scale != scale || old.groundY != groundY ||
      old.groundXCenter != groundXCenter || old.zoom != zoom;
}

// ─── Sol panel ───────────────────────────────────────────────────────────────
class _BuildingList extends StatelessWidget {
  final BuildingType selected;
  final ValueChanged<BuildingType> onSelect;
  const _BuildingList({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final types = BuildingType.values
        .where((t) => kBuildingMeta.containsKey(t))
        .toList();
    return Container(
      width: 210,
      color: const Color(0xFF0D1B2A),
      child: ListView.builder(
        itemCount: types.length,
        itemBuilder: (_, i) {
          final t = types[i];
          final m = kBuildingMeta[t]!;
          final active = t == selected;
          return ListTile(
            dense: true,
            selected: active,
            selectedTileColor: const Color(0xFF143A2C),
            onTap: () => onSelect(t),
            title: Text(m.label,
                style: TextStyle(
                    fontSize: 13,
                    color: active ? const Color(0xFF66D9A0) : Colors.white70,
                    fontWeight: active ? FontWeight.bold : FontWeight.normal)),
            subtitle: Text('${m.cols}×${m.rows} · s${m.spriteScale.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 10, color: Colors.white30)),
          );
        },
      ),
    );
  }
}

// ─── Sağ panel: slider'lar ───────────────────────────────────────────────────
class _Controls extends StatelessWidget {
  final String label;
  final _Geom geom;
  final double zoom;
  final ValueChanged<int> onCols, onRows;
  final ValueChanged<double> onScale, onGroundY, onGroundX, onZoom;
  final VoidCallback onReset;
  const _Controls({
    required this.label,
    required this.geom,
    required this.zoom,
    required this.onCols,
    required this.onRows,
    required this.onScale,
    required this.onGroundY,
    required this.onGroundX,
    required this.onZoom,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      color: const Color(0xFF0D1B2A),
      padding: const EdgeInsets.all(14),
      child: ListView(
        children: [
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF66D9A0), fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          // Footprint (kaç tile kaplar) — gameplay'i etkiler (yerleşim/yol).
          Row(
            children: [
              Expanded(child: _Stepper(label: 'cols (en)', value: geom.cols,
                  min: 1, max: 6, onChanged: onCols)),
              const SizedBox(width: 10),
              Expanded(child: _Stepper(label: 'rows (boy)', value: geom.rows,
                  min: 1, max: 6, onChanged: onRows)),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(top: 4, bottom: 12),
            child: Text('footprint = binanın kapladığı kare sayısı (yeşil diamond)',
                style: TextStyle(color: Colors.white30, fontSize: 10.5)),
          ),
          const Divider(height: 8, color: Color(0xFF1B3A5C)),
          const SizedBox(height: 10),
          _Slider(
            label: 'spriteScale',
            help: 'Büyüklük. Düşür → küçülür, footprint\'e sığar.',
            value: geom.scale, min: 0.4, max: 2.0, onChanged: onScale,
          ),
          _Slider(
            label: 'groundY',
            help: 'Dikey demir atma. 1.0 = sprite altı; küçült → bina yukarı.',
            value: geom.groundY, min: 0.6, max: 1.3, onChanged: onGroundY,
          ),
          _Slider(
            label: 'groundXCenter',
            help: 'Yatay merkez. 0.5 = orta; sola/sağa kaydırır.',
            value: geom.groundXCenter, min: 0.2, max: 0.8, onChanged: onGroundX,
          ),
          const Divider(height: 30, color: Color(0xFF1B3A5C)),
          _Slider(
            label: 'zoom (önizleme)',
            help: 'Sadece editör görünümü; koda yazılmaz.',
            value: zoom, min: 0.5, max: 4.0, onChanged: onZoom,
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.restore, size: 16),
            label: const Text('Kayıtlı değere dön'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white70),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0A1628),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '• Yeşil diamond = footprint (binanın kapladığı kare)\n'
              '• Sarı nokta = ön köşe (anchor)\n'
              '• Bina tabanı diamond\'a otursun, çatı taşabilir\n'
              '• cols/rows oyun içi yerleşim+yolu etkiler (yeni build\'de geçerli)\n'
              '• Değişiklik otomatik kaydedilir',
              style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tam sayı stepper (cols / rows) ──────────────────────────────────────────
class _Stepper extends StatelessWidget {
  final String label;
  final int value, min, max;
  final ValueChanged<int> onChanged;
  const _Stepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData ic, VoidCallback? onTap) => InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 30, height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: onTap == null ? Colors.white10 : const Color(0xFF143A2C),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(ic, size: 16,
                color: onTap == null ? Colors.white24 : const Color(0xFF66D9A0)),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Row(
          children: [
            btn(Icons.remove, value > min ? () => onChanged(value - 1) : null),
            Expanded(
              child: Text('$value',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xFF66D9A0), fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            btn(Icons.add, value < max ? () => onChanged(value + 1) : null),
          ],
        ),
      ],
    );
  }
}

class _Slider extends StatelessWidget {
  final String label, help;
  final double value, min, max;
  final ValueChanged<double> onChanged;
  const _Slider({
    required this.label,
    required this.help,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF143A2C),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(value.toStringAsFixed(3),
                  style: const TextStyle(
                      color: Color(0xFF66D9A0), fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            activeTrackColor: const Color(0xFF66D9A0),
            inactiveTrackColor: Colors.white12,
            thumbColor: const Color(0xFF66D9A0),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(help,
              style: const TextStyle(color: Colors.white30, fontSize: 10.5, height: 1.3)),
        ),
      ],
    );
  }
}

// ─── Auto-save göstergesi ────────────────────────────────────────────────────
class _SaveStatus extends StatelessWidget {
  final String? projectRoot;
  final bool saving;
  final String? error;
  final DateTime? savedAt;
  const _SaveStatus({
    required this.projectRoot,
    required this.saving,
    required this.error,
    required this.savedAt,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon; Color color; String label; String tooltip;
    if (projectRoot == null) {
      icon = Icons.cloud_off; color = Colors.orangeAccent; label = 'Manuel';
      tooltip = 'Proje kökü bulunamadı. Kopyala ile manuel yapıştır.';
    } else if (error != null) {
      icon = Icons.error_outline; color = Colors.redAccent; label = 'Hata';
      tooltip = error!;
    } else if (saving) {
      icon = Icons.cloud_upload; color = Colors.lightBlueAccent; label = 'Kaydediliyor';
      tooltip = 'building_type.dart güncelleniyor…';
    } else if (savedAt != null) {
      icon = Icons.cloud_done; color = const Color(0xFF8FE08F);
      final t = savedAt!;
      label = '${t.hour.toString().padLeft(2, '0')}:'
          '${t.minute.toString().padLeft(2, '0')}:'
          '${t.second.toString().padLeft(2, '0')}';
      tooltip = 'Son kayıt $label\n$projectRoot';
    } else {
      icon = Icons.cloud_outlined; color = Colors.white54; label = 'Hazır';
      tooltip = 'Auto-save aktif.\n$projectRoot';
    }
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.55)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}
