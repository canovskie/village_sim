import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Uygulama genelindeki kullanıcı tercihleri.
///
/// KALICI: belge dizininde `settings.json`. Eskiden yalnız bellekteydi ve
/// uygulama her kapanışta ses seviyelerini varsayılana döndürüyordu — sessize
/// alan oyuncu her açılışta yeniden sessize alıyordu. Kayıt dosyalarıyla aynı
/// mekanizma (path_provider + atomik yazım) kullanılır; ayrı bir bağımlılık
/// eklemeye gerek yok.
///
/// Yazım DEBOUNCE'ludur: slider sürüklenirken her karede diske inmez. Okuma
/// [load] ile bir kez, uygulama açılışında yapılır (bkz. `main()`).
class SettingsModel extends ChangeNotifier {
  static final SettingsModel instance = SettingsModel._();
  SettingsModel._();

  static const String _fileName = 'settings.json';

  /// Sürüklenen slider'ın diske inme gecikmesi.
  static const Duration _writeDelay = Duration(milliseconds: 400);

  Timer? _writeTimer;

  /// Yükleme sürerken yazma tetiklenmesin (yüklenen değerler kendini geri
  /// yazmasın; zararsız ama gereksiz bir diske-iniş).
  bool _loading = false;

  Future<File> _file() async {
    final base = await getApplicationDocumentsDirectory();
    return File('${base.path}/$_fileName');
  }

  /// Diskteki tercihleri okur. Dosya yoksa/bozuksa sessizce varsayılanlarda
  /// kalır — tercih dosyası yüzünden oyun açılmamazlık etmez.
  Future<void> load() async {
    _loading = true;
    try {
      final f = await _file();
      if (!await f.exists()) return;
      final raw = jsonDecode(await f.readAsString());
      if (raw is! Map) return;
      final m = Map<String, dynamic>.from(raw);
      double d(String k, double fallback) =>
          ((m[k] as num?)?.toDouble() ?? fallback).clamp(0.0, 1.0);
      _musicVolume = d('music', _musicVolume);
      _ambientVolume = d('ambient', _ambientVolume);
      _sfxVolume = d('sfx', _sfxVolume);
      _muted = m['muted'] as bool? ?? _muted;
      _showFps = m['showFps'] as bool? ?? _showFps;
      _shakeOnEvents = m['shake'] as bool? ?? _shakeOnEvents;
      _language = AppLanguage.values.firstWhere(
        (l) => l.name == m['language'],
        orElse: () => _language,
      );
      notifyListeners();
    } catch (_) {
      // Bozuk tercih dosyası = varsayılanlar. Sessiz geçilir.
    } finally {
      _loading = false;
    }
  }

  /// Değişikliği duyur + diske yazımı planla. Her setter bundan geçer:
  /// "kaydetmeyi unutulan alan" hatası ancak tek kapı varken imkânsızdır.
  void _changed() {
    notifyListeners();
    if (_loading) return;
    _writeTimer?.cancel();
    _writeTimer = Timer(_writeDelay, _flush);
  }

  Future<void> _flush() async {
    try {
      final f = await _file();
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(jsonEncode({
        'music': _musicVolume,
        'ambient': _ambientVolume,
        'sfx': _sfxVolume,
        'muted': _muted,
        'showFps': _showFps,
        'shake': _shakeOnEvents,
        'language': _language.name,
      }));
      await tmp.rename(f.path); // atomik: yarım yazım bozuk dosya bırakmaz
    } catch (_) {
      // Diske yazamamak oyunu durdurmaz; tercih o oturumda geçerli kalır.
    }
  }

  double _musicVolume = 0.7;
  /// ORTAM sesi (kuş/cırcır/yağmur/ateş döngüleri) — MÜZİKTEN AYRI.
  ///
  /// Eskiden ortam döngüleri `musicVolume` ile kısılıyordu ve oyunda hiç müzik
  /// olmadığı için ayarın adı yalan söylüyordu: "Müzik" slider'ı aslında kuş
  /// sesini kısıyordu. Müzik katmanı gelince ikisi ayrıldı — panelde yazan
  /// şey, motorun okuduğu şey olmalı.
  double _ambientVolume = 0.7;
  double _sfxVolume   = 0.8;
  bool   _muted       = false;
  bool   _showFps     = false;
  bool   _shakeOnEvents = true;
  AppLanguage _language = AppLanguage.tr;

  double get musicVolume   => _musicVolume;
  double get ambientVolume => _ambientVolume;
  double get sfxVolume     => _sfxVolume;
  /// Sessiz modu — oyun içi hızlı kıs/aç. Slider değerlerini korur (aç =
  /// eski seviyelere döner). Ses üreten her yer "effective" getter'ları okur.
  bool   get muted         => _muted;
  /// AudioManager bunları okur: sessizken 0, değilse slider değeri.
  double get effectiveMusicVolume => _muted ? 0.0 : _musicVolume;
  double get effectiveAmbientVolume => _muted ? 0.0 : _ambientVolume;
  double get effectiveSfxVolume   => _muted ? 0.0 : _sfxVolume;
  bool   get showFps       => _showFps;
  bool   get shakeOnEvents => _shakeOnEvents;
  AppLanguage get language => _language;

  set musicVolume(double v) {
    final c = v.clamp(0.0, 1.0);
    if (c == _musicVolume) return;
    _musicVolume = c;
    _changed();
  }

  set ambientVolume(double v) {
    final c = v.clamp(0.0, 1.0);
    if (c == _ambientVolume) return;
    _ambientVolume = c;
    _changed();
  }

  set sfxVolume(double v) {
    final c = v.clamp(0.0, 1.0);
    if (c == _sfxVolume) return;
    _sfxVolume = c;
    _changed();
  }

  set muted(bool v) {
    if (v == _muted) return;
    _muted = v;
    _changed();
  }

  void toggleMute() => muted = !_muted;

  set showFps(bool v) {
    if (v == _showFps) return;
    _showFps = v;
    _changed();
  }

  set shakeOnEvents(bool v) {
    if (v == _shakeOnEvents) return;
    _shakeOnEvents = v;
    _changed();
  }

  set language(AppLanguage v) {
    if (v == _language) return;
    _language = v;
    _changed();
  }

  void resetToDefaults() {
    _musicVolume   = 0.7;
    _ambientVolume = 0.7;
    _sfxVolume     = 0.8;
    _muted         = false;
    _showFps       = false;
    _shakeOnEvents = true;
    _language      = AppLanguage.tr;
    _changed();
  }
}

enum AppLanguage {
  tr('Türkçe', 'TR'),
  en('English', 'EN');

  final String label;
  final String code;
  const AppLanguage(this.label, this.code);
}
