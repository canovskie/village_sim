import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import '../ui/settings_model.dart';

/// Tek-atış ses efektleri — masaüstünden gelen kütüphaneden (assets/audio).
enum Sfx {
  bellChime,
  chickenCluck,
  cowMoo,
  roosterCrow,
  crowdFair,
  owl,
  birds,
  thunderClap,
  imperialMarch, // İmparatorluk kolonu yaklaşırken — kalabalık ordu yürüyüşü
}

/// Oyunun ses motoru — iki katman:
///  1) ORTAM döngüleri (gündüz/gece/yağmur/fırtına/ateş) — yumuşak crossfade,
///     hedef ses seviyeleri sahne durumuna ([applyAmbient]) göre lerp'lenir.
///  2) Tek-atış EFEKTLER ([playSfx]) — havuzdan çalınır (üst üste binebilir).
///
/// SettingsModel.musicVolume → ortam, sfxVolume → efekt çarpanı. Tüm çağrılar
/// hata-dayanıklı (ses başarısızsa oyun akışı bozulmaz). update(dt) sahne
/// tick'inden (gerçek-zaman dt) çağrılır; sim duraklasa da ses akar.
class AudioManager {
  static final AudioManager instance = AudioManager._();
  AudioManager._();

  static const _dir = 'audio';
  bool _started = false;

  // Ortam döngü kanalları.
  late final AudioPlayer _day;
  late final AudioPlayer _night;
  late final AudioPlayer _rain;
  late final AudioPlayer _storm;
  late final AudioPlayer _fire;

  // Kanal başına anlık + hedef seviye (0..1, settings öncesi taban).
  final Map<AudioPlayer, double> _cur = {};
  final Map<AudioPlayer, double> _tgt = {};

  // Tek-atış efekt havuzu (üst üste binme için round-robin).
  final List<AudioPlayer> _sfxPool = [];
  int _sfxIdx = 0;

  // Efekt taban seviyeleri (kaynak yüksekliğine göre dengelenmiş — analizden).
  static const Map<Sfx, double> _sfxGain = {
    Sfx.bellChime: 0.7,
    Sfx.chickenCluck: 0.9,
    Sfx.cowMoo: 0.5,
    Sfx.roosterCrow: 0.8,
    Sfx.crowdFair: 0.7,
    Sfx.owl: 0.9,
    Sfx.birds: 0.7,
    Sfx.thunderClap: 0.65,
    Sfx.imperialMarch: 0.95, // dramatik varış anı — öne çıksın
  };
  static const Map<Sfx, String> _sfxFile = {
    Sfx.bellChime: 'bell_chime.mp3',
    Sfx.chickenCluck: 'chicken_cluck.mp3',
    Sfx.cowMoo: 'cow_moo.mp3',
    Sfx.roosterCrow: 'rooster_crow.mp3',
    Sfx.crowdFair: 'crowd_fair.mp3',
    Sfx.owl: 'owl.mp3',
    Sfx.birds: 'birds_singing.mp3',
    Sfx.thunderClap: 'thunder_clap.mp3',
    Sfx.imperialMarch: 'imperial_march.mp3',
  };

  // Ortam taban tavanları (kaynak yüksekliğine göre).
  static const double _baseDay = 0.85;
  static const double _baseNight = 0.75;
  static const double _baseRain = 0.7;
  static const double _baseStorm = 0.75;
  static const double _baseFire = 0.8;

  double _owlTimer = 22.0;  // gece baykuş aksanı sayacı (sn)
  double _birdsTimer = 18.0; // gündüz kuş cıvıltısı aksanı sayacı (sn)

  /// İlk çağrıda kanalları kurar + döngüleri sessiz başlatır. Hatalar yutulur.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      _day = await _loopPlayer('morning_garden.mp3');
      _night = await _loopPlayer('crickets_night.mp3');
      _rain = await _loopPlayer('rain_light.mp3');
      _storm = await _loopPlayer('thunderstorm.mp3');
      _fire = await _loopPlayer('campfire.mp3');
      for (final p in [_day, _night, _rain, _storm, _fire]) {
        _cur[p] = 0.0;
        _tgt[p] = 0.0;
      }
      for (int i = 0; i < 4; i++) {
        _sfxPool.add(AudioPlayer()..setReleaseMode(ReleaseMode.stop));
      }
    } catch (_) {
      // Ses başlatılamadı (platform/dosya) → sessiz devam.
    }
  }

  Future<AudioPlayer> _loopPlayer(String file) async {
    final p = AudioPlayer();
    await p.setReleaseMode(ReleaseMode.loop);
    await p.setVolume(0.0);
    await p.play(AssetSource('$_dir/$file'), volume: 0.0);
    return p;
  }

  /// Sahne durumuna göre ortam hedeflerini ayarlar. [dayLight] 0(gece)..1(gündüz),
  /// [rain] 0..1 yağmur şiddeti, [hasFire] köyde yanan ateş var mı.
  void applyAmbient({
    required double dayLight,
    required double rain,
    required bool hasFire,
  }) {
    if (!_started) return;
    final storm = rain > 0.6;
    _tgt[_day] = _baseDay * dayLight.clamp(0.0, 1.0);
    _tgt[_night] = _baseNight * (1.0 - dayLight).clamp(0.0, 1.0);
    _tgt[_rain] = storm ? 0.0 : _baseRain * rain.clamp(0.0, 1.0);
    _tgt[_storm] = storm ? _baseStorm * rain.clamp(0.0, 1.0) : 0.0;
    _tgt[_fire] = hasFire ? _baseFire * (0.5 + 0.5 * (1.0 - dayLight)) : 0.0;
  }

  /// Her tick (gerçek-zaman dt). Ortam seviyelerini hedefe yumuşatır + gece
  /// baykuş aksanını tetikler.
  void update(double dt, {double dayLight = 1.0, Random? rng}) {
    if (!_started) return;
    final music = SettingsModel.instance.effectiveMusicVolume;
    final k = (dt * 1.5).clamp(0.0, 1.0); // ~0.7s crossfade
    for (final p in _cur.keys) {
      final cur = _cur[p]!;
      final tgt = _tgt[p]!;
      if ((cur - tgt).abs() < 0.005) {
        if (cur != tgt) _cur[p] = tgt;
      } else {
        _cur[p] = cur + (tgt - cur) * k;
      }
      _safe(p.setVolume(_cur[p]! * music));
    }
    // Gece baykuş — seyrek aksan (yalnız karanlıkta).
    if (dayLight < 0.25) {
      _owlTimer -= dt;
      if (_owlTimer <= 0) {
        _owlTimer = 30.0 + (rng?.nextDouble() ?? 0.5) * 40.0;
        playSfx(Sfx.owl);
      }
    } else if (dayLight > 0.7) {
      // Gündüz kuş cıvıltısı — seyrek aksan.
      _birdsTimer -= dt;
      if (_birdsTimer <= 0) {
        _birdsTimer = 25.0 + (rng?.nextDouble() ?? 0.5) * 35.0;
        playSfx(Sfx.birds);
      }
    }
  }

  /// Tek-atış efekt çal — havuzdan sıradaki oynatıcıyla (üst üste binebilir).
  void playSfx(Sfx s) {
    if (!_started || _sfxPool.isEmpty) return;
    final vol = (_sfxGain[s] ?? 0.8) * SettingsModel.instance.effectiveSfxVolume;
    if (vol <= 0.001) return;
    final p = _sfxPool[_sfxIdx];
    _sfxIdx = (_sfxIdx + 1) % _sfxPool.length;
    _safe(p.play(AssetSource('$_dir/${_sfxFile[s]}'), volume: vol));
  }

  void _safe(Future<void> f) {
    f.catchError((_) {});
  }

  Future<void> dispose() async {
    for (final p in [..._cur.keys, ..._sfxPool]) {
      _safe(p.stop());
      _safe(p.dispose());
    }
    _cur.clear();
    _tgt.clear();
    _sfxPool.clear();
    _started = false;
  }
}
