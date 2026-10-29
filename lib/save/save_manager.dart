import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Bir kayıt slotunun özeti — menüdeki slot listesi bunu gösterir.
/// Asıl dünya verisi dosyanın `world` alanındadır; bu yalnız başlık bilgisi.
class SaveSlotMeta {
  final String id;
  final String name;
  final DateTime savedAt;
  final int day;
  final int population;
  final String identity;

  /// Bu köyün defteri KAPANDI mı (dağıldı). Kapanmış kayıt sürdürülemez ama
  /// SİLİNMEZ: menüde okunabilir bir mezar taşı olarak durur, silmek oyuncunun
  /// kararıdır (bkz. scene_collapse — oyun kimsenin köyünü kendi eliyle yok
  /// etmez). null/false = normal, sürdürülebilir kayıt.
  final bool ended;

  /// Dağılma nedeni (kapanmış kayıtlarda) — mezar taşı kartında yazar.
  final String? endedReason;

  const SaveSlotMeta({
    required this.id,
    required this.name,
    required this.savedAt,
    required this.day,
    required this.population,
    required this.identity,
    this.ended = false,
    this.endedReason,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'savedAt': savedAt.millisecondsSinceEpoch,
        'day': day,
        'population': population,
        'identity': identity,
        if (ended) 'ended': true,
        if (endedReason != null) 'endedReason': endedReason,
      };

  factory SaveSlotMeta.fromJson(Map<String, dynamic> j) => SaveSlotMeta(
        id: j['id'] as String,
        name: (j['name'] as String?) ?? 'Köy',
        savedAt: DateTime.fromMillisecondsSinceEpoch(
            (j['savedAt'] as num?)?.toInt() ?? 0),
        day: (j['day'] as num?)?.toInt() ?? 1,
        population: (j['population'] as num?)?.toInt() ?? 0,
        identity: (j['identity'] as String?) ?? 'Dengeli Köy',
        ended: j['ended'] == true,
        endedReason: j['endedReason'] as String?,
      );
}

/// Çoklu slot kayıt dosyalarını yöneten tek otorite. Dosyalar uygulamanın
/// kalıcı belge dizininde `saves/` altında `village_<id>.json` olarak tutulur.
/// Yazım atomiktir (geçici dosya + rename) → yarım yazımda kayıt bozulmaz.
class SaveManager {
  SaveManager._();
  static final SaveManager instance = SaveManager._();

  /// Kayıt dosyası şema sürümü. İleride alan eklenirse migration için artırılır.
  static const int schemaVersion = 1;

  static const String _subdir = 'saves';
  static const String _prefix = 'village_';
  static const String _ext = '.json';

  Directory? _cachedDir;

  Future<Directory> _dir() async {
    if (_cachedDir != null) return _cachedDir!;
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/$_subdir');
    if (!await dir.exists()) await dir.create(recursive: true);
    _cachedDir = dir;
    return dir;
  }

  File _fileFor(Directory dir, String id) =>
      File('${dir.path}/$_prefix$id$_ext');

  /// Yeni bir slot için zaman tabanlı benzersiz id üretir.
  String newSlotId() => DateTime.now().millisecondsSinceEpoch.toString();

  /// Tüm slotları kayıt zamanına göre (en yeni önce) sıralı döner.
  /// Bozuk/okunamayan dosyalar sessizce atlanır.
  Future<List<SaveSlotMeta>> listSlots() async {
    final dir = await _dir();
    await _recoverTemps(dir);
    final out = <SaveSlotMeta>[];
    await for (final ent in dir.list()) {
      if (ent is! File) continue;
      if (!ent.path.endsWith(_ext)) continue;
      try {
        final raw = await ent.readAsString();
        final j = jsonDecode(raw) as Map<String, dynamic>;
        final meta = j['meta'];
        if (meta is Map<String, dynamic>) {
          out.add(SaveSlotMeta.fromJson(meta));
        }
      } catch (_) {
        // Bozuk dosya — listede gösterme.
      }
    }
    out.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return out;
  }

  /// Slotun tam içeriğini ({version, meta, world}) döner; yoksa null.
  Future<Map<String, dynamic>?> readSlot(String id) async {
    final dir = await _dir();
    await _recoverTemps(dir);
    final f = _fileFor(dir, id);
    if (!await f.exists()) return null;
    try {
      return jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Slota tam içerik yazar (atomik). [data] = {version, meta, world}.
  Future<void> writeSlot(String id, Map<String, dynamic> data) async {
    final dir = await _dir();
    final f = _fileFor(dir, id);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(data), flush: true);
    // Eskisini SİLMEDEN üstüne yaz: rename hedefi tek adımda değiştirir. Silip
    // sonra taşımak, araya giren bir durmada köyün tek kopyasını yok ederdi.
    await tmp.rename(f.path);
  }

  /// Yazım `<dosya>.tmp`ye yapılıp taşınır. İkisi arasında bir durma, eksik ya da
  /// bozuk bir slotun yanında TAM bir tmp bırakır: onu slota çıkar. Yarım kalmış
  /// tmp çözümlenmez, yok sayılır.
  Future<void> _recoverTemps(Directory dir) async {
    final temps = await dir
        .list()
        .where((e) => e is File && e.path.endsWith('$_ext.tmp'))
        .cast<File>()
        .toList();
    for (final tmp in temps) {
      final target = File(tmp.path.substring(0, tmp.path.length - 4));
      if (await _isSave(target) || !await _isSave(tmp)) continue;
      try {
        await tmp.rename(target.path);
      } catch (_) {}
    }
  }

  Future<bool> _isSave(File f) async {
    try {
      if (!await f.exists()) return false;
      final j = jsonDecode(await f.readAsString());
      return j is Map<String, dynamic> && j['meta'] is Map && j['world'] != null;
    } catch (_) {
      return false;
    }
  }

  /// Yalnız testler için: kayıtları verilen dizine yazdırır.
  void useDirectoryForTest(Directory dir) => _cachedDir = dir;

  Future<void> deleteSlot(String id) async {
    final dir = await _dir();
    final f = _fileFor(dir, id);
    if (await f.exists()) await f.delete();
  }

  /// Slot adını değiştirir (meta.name). Dosya/içerik aynı kalır.
  Future<void> renameSlot(String id, String newName) async {
    final data = await readSlot(id);
    if (data == null) return;
    final meta = (data['meta'] as Map<String, dynamic>?) ?? {};
    meta['name'] = newName;
    data['meta'] = meta;
    await writeSlot(id, data);
  }

  Future<bool> hasAnySave() async => (await listSlots()).isNotEmpty;
}
