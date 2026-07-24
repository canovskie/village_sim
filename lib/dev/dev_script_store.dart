import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'dev_command.dart';

/// Kaydedilmiş dev senaryolarının diskteki evi.
///
/// Oyunu kapatınca kaydettiğin senaryo kaybolmasın diye: hepsi tek bir
/// `dev_scripts.json` dosyasında, uygulamanın belge dizininde durur. Yazım
/// [SaveManager] ile aynı şekilde atomik (tmp + rename) → yarım yazımda
/// senaryo listesi bozulmaz.
///
/// Built-in senaryolar kodda gömülü olduğu için buraya YAZILMAZ; burası
/// sadece kullanıcının kaydettiklerini tutar.
class DevScriptStore {
  DevScriptStore._();
  static final DevScriptStore instance = DevScriptStore._();

  static const String _fileName = 'dev_scripts.json';

  File? _cachedFile;

  Future<File> _file() async {
    if (_cachedFile != null) return _cachedFile!;
    final base = await getApplicationDocumentsDirectory();
    return _cachedFile = File('${base.path}/$_fileName');
  }

  /// Diskteki senaryoları okur. Dosya yoksa/bozuksa boş liste döner —
  /// dev aracı yüzünden oyun açılışta patlamamalı.
  Future<List<DevScript>> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return [];
      final j = jsonDecode(await f.readAsString());
      if (j is! Map) return [];
      final raw = j['scripts'];
      if (raw is! List) return [];
      return [
        for (final s in raw)
          if (s is Map) DevScript.fromJson(s.cast<String, Object?>()),
      ];
    } catch (_) {
      return [];
    }
  }

  /// Tüm listeyi diske yazar (atomik). Hata sessizce yutulur.
  Future<void> save(List<DevScript> scripts) async {
    try {
      final f = await _file();
      final data = {
        'scripts': [for (final s in scripts) s.toJson()],
      };
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(jsonEncode(data), flush: true);
      if (await f.exists()) await f.delete();
      await tmp.rename(f.path);
    } catch (_) {
      // Dev aracı — kayıt tutmazsa oyun akışı bozulmasın.
    }
  }
}
