import 'package:flutter/foundation.dart';

/// Uygulama genelindeki kullanıcı tercihleri.
/// Şu an bellekte tutulur — kalıcılık için ileride `shared_preferences` eklenebilir.
class SettingsModel extends ChangeNotifier {
  static final SettingsModel instance = SettingsModel._();
  SettingsModel._();

  double _musicVolume = 0.7;
  double _sfxVolume   = 0.8;
  bool   _muted       = false;
  bool   _showFps     = false;
  bool   _shakeOnEvents = true;
  AppLanguage _language = AppLanguage.tr;

  double get musicVolume   => _musicVolume;
  double get sfxVolume     => _sfxVolume;
  /// Sessiz modu — oyun içi hızlı kıs/aç. Slider değerlerini korur (aç =
  /// eski seviyelere döner). Ses üreten her yer "effective" getter'ları okur.
  bool   get muted         => _muted;
  /// AudioManager bunları okur: sessizken 0, değilse slider değeri.
  double get effectiveMusicVolume => _muted ? 0.0 : _musicVolume;
  double get effectiveSfxVolume   => _muted ? 0.0 : _sfxVolume;
  bool   get showFps       => _showFps;
  bool   get shakeOnEvents => _shakeOnEvents;
  AppLanguage get language => _language;

  set musicVolume(double v) {
    final c = v.clamp(0.0, 1.0);
    if (c == _musicVolume) return;
    _musicVolume = c;
    notifyListeners();
  }

  set sfxVolume(double v) {
    final c = v.clamp(0.0, 1.0);
    if (c == _sfxVolume) return;
    _sfxVolume = c;
    notifyListeners();
  }

  set muted(bool v) {
    if (v == _muted) return;
    _muted = v;
    notifyListeners();
  }

  void toggleMute() => muted = !_muted;

  set showFps(bool v) {
    if (v == _showFps) return;
    _showFps = v;
    notifyListeners();
  }

  set shakeOnEvents(bool v) {
    if (v == _shakeOnEvents) return;
    _shakeOnEvents = v;
    notifyListeners();
  }

  set language(AppLanguage v) {
    if (v == _language) return;
    _language = v;
    notifyListeners();
  }

  void resetToDefaults() {
    _musicVolume   = 0.7;
    _sfxVolume     = 0.8;
    _muted         = false;
    _showFps       = false;
    _shakeOnEvents = true;
    _language      = AppLanguage.tr;
    notifyListeners();
  }
}

enum AppLanguage {
  tr('Türkçe', 'TR'),
  en('English', 'EN');

  final String label;
  final String code;
  const AppLanguage(this.label, this.code);
}
