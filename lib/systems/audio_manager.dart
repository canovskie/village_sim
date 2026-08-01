import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import '../ui/settings_model.dart';

/// Tek-atış ses efektleri — masaüstünden gelen kütüphaneden (assets/audio).
///
/// DOSYASI OLMAYAN EFEKT SESSİZDİR, ÇÖKMEZ: [playSfx] hatayı yutar. Aşağıdaki
/// "beklenen" grup bilerek önden bağlandı — MP3 `assets/audio/` içine düştüğü
/// an, tek satır kod değişmeden çalmaya başlar. Hangi dosyanın beklendiği
/// [_sfxFile] tablosunda yazılı.
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

  // ── Beklenen dosyalar (bkz. assets/audio/README.md) ─────────────────────
  // Oyunun duygusal anları bugüne dek TEK çanla karşılanıyordu: görev de,
  // mühür de, rejim değişimi de aynı sesti. Bunlar o çanı bölüyor.
  sealStamp,   // mühür vurulur — Kanunname'nin sesi
  birthJoy,    // doğum
  funeralToll, // cenaze
  weddingJoy,  // düğün alayı
  fightScuffle,// yumruklaşma / çekişme
  buildDone,   // inşaat biter, gövde tamamlanır
  uiTap,       // panel/düğme dokunuşu
}

/// Müzik parçaları — ortamdan AYRI katman (bkz. [AudioManager.playMusic]).
enum MusicTrack {
  menu,    // açılış/şafak menüsü
  village, // oyun döngüsü
}

/// Oyunun ses motoru — ÜÇ katman:
///  1) ORTAM döngüleri (gündüz/gece/yağmur/fırtına/ateş) — yumuşak crossfade,
///     hedef ses seviyeleri sahne durumuna ([applyAmbient]) göre lerp'lenir.
///  2) MÜZİK ([playMusic]) — tek parça döngüde, kendi crossfade'iyle.
///  3) Tek-atış EFEKTLER ([playSfx]) — havuzdan çalınır (üst üste binebilir).
///
/// Ayar eşlemesi: `ambientVolume` → ortam, `musicVolume` → müzik, `sfxVolume` →
/// efekt. Bu ayrım sonradan düzeltildi: müzik yokken ortam döngüleri
/// `musicVolume`'a bağlıydı, yani "Müzik" slider'ı kuş sesini kısıyordu.
///
/// Tüm çağrılar hata-dayanıklı (ses başarısızsa oyun akışı bozulmaz).
/// update(dt) sahne tick'inden (gerçek-zaman dt) çağrılır; sim duraklasa da
/// ses akar.
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
    // Beklenenler: tören sesleri öne, UI dokunuşu geriye. UI sesi yüksek
    // olursa panel açıp kapayan oyuncuyu yorar — en sık duyulan ses odur.
    Sfx.sealStamp: 0.8,
    Sfx.birthJoy: 0.75,
    Sfx.funeralToll: 0.7,
    Sfx.weddingJoy: 0.75,
    Sfx.fightScuffle: 0.6,
    Sfx.buildDone: 0.55,
    Sfx.uiTap: 0.25,
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
    // ── Henüz assets/audio'da OLMAYAN dosyalar ────────────────────────────
    // Bunlar bilerek önden bağlandı; dosya düşene kadar sessizler.
    Sfx.sealStamp: 'seal_stamp.mp3',
    Sfx.birthJoy: 'birth_joy.mp3',
    Sfx.funeralToll: 'funeral_toll.mp3',
    Sfx.weddingJoy: 'wedding_joy.mp3',
    Sfx.fightScuffle: 'fight_scuffle.mp3',
    Sfx.buildDone: 'build_done.mp3',
    Sfx.uiTap: 'ui_tap.mp3',
  };

  static const Map<MusicTrack, String> _musicFile = {
    MusicTrack.menu: 'music_menu.mp3',
    MusicTrack.village: 'music_village.mp3',
  };

  // Ortam taban tavanları (kaynak yüksekliğine göre).
  static const double _baseDay = 0.85;
  static const double _baseNight = 0.75;
  static const double _baseRain = 0.7;
  static const double _baseStorm = 0.75;
  static const double _baseFire = 0.8;

  double _owlTimer = 22.0;  // gece baykuş aksanı sayacı (sn)
  double _birdsTimer = 18.0; // gündüz kuş cıvıltısı aksanı sayacı (sn)

  // ── MÜZİK ────────────────────────────────────────────────────────────────
  // Tek oynatıcı: iki parça aynı anda çalmaz, geçiş "kıs → değiştir → aç"
  // biçiminde yapılır. İki oynatıcılı gerçek crossfade denenebilirdi ama köy
  // müziği sahne değiştirmiyor (menü ↔ oyun), o geçiş zaten ekran değişimiyle
  // maskeleniyor; iki kanal boşuna bellek ve boşuna karmaşa olurdu.
  AudioPlayer? _music;
  MusicTrack? _musicTrack;
  double _musicCur = 0.0;   // anlık taban seviye (ayar öncesi)
  double _musicTgt = 0.0;   // hedef taban seviye
  static const double _baseMusic = 0.55; // müzik ortamı EZMEZ, altına serilir

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
      _music = AudioPlayer();
      _safe(_music!.setReleaseMode(ReleaseMode.loop));
      _safe(_music!.setVolume(0.0));
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

  /// MÜZİK — parçayı döngüde başlatır. Aynı parça zaten çalıyorsa hiçbir şey
  /// yapmaz (sahne yeniden kurulunca müzik baştan sarmasın).
  ///
  /// Dosya yoksa sessizce hiçbir şey olmaz: motor bunu bir hata olarak
  /// görmez, çünkü müzik dosyaları oyunun akışının şartı değil.
  void playMusic(MusicTrack t) {
    if (!_started || _music == null) return;
    if (_musicTrack == t) {
      _musicTgt = _baseMusic;
      return;
    }
    _musicTrack = t;
    _musicCur = 0.0;
    _musicTgt = _baseMusic;
    _safe(_music!.stop());
    _safe(_music!.play(AssetSource('$_dir/${_musicFile[t]}'), volume: 0.0));
  }

  /// Müziği susturur (yumuşak iner; [update] indirmeyi sürdürür).
  void stopMusic() {
    _musicTgt = 0.0;
  }

  /// Her tick (gerçek-zaman dt). Ortam + müzik seviyelerini hedefe yumuşatır
  /// ve gece baykuş / gündüz kuş aksanını tetikler.
  void update(double dt, {double dayLight = 1.0, Random? rng}) {
    if (!_started) return;
    final ambient = SettingsModel.instance.effectiveAmbientVolume;
    final k = (dt * 1.5).clamp(0.0, 1.0); // ~0.7s crossfade

    // Müzik kendi ayarıyla, kendi (daha yavaş) geçişiyle: parça değişimi
    // ortam geçişinden yumuşak olmalı, yoksa kesik gibi duyulur.
    final mk = (dt * 0.8).clamp(0.0, 1.0);
    if ((_musicCur - _musicTgt).abs() < 0.005) {
      _musicCur = _musicTgt;
    } else {
      _musicCur += (_musicTgt - _musicCur) * mk;
    }
    if (_music != null) {
      _safe(_music!.setVolume(
          _musicCur * SettingsModel.instance.effectiveMusicVolume));
    }

    for (final p in _cur.keys) {
      final cur = _cur[p]!;
      final tgt = _tgt[p]!;
      if ((cur - tgt).abs() < 0.005) {
        if (cur != tgt) _cur[p] = tgt;
      } else {
        _cur[p] = cur + (tgt - cur) * k;
      }
      _safe(p.setVolume(_cur[p]! * ambient));
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
    for (final p in [..._cur.keys, ..._sfxPool, ?_music]) {
      _safe(p.stop());
      _safe(p.dispose());
    }
    _cur.clear();
    _tgt.clear();
    _sfxPool.clear();
    _music = null;
    _musicTrack = null;
    _musicCur = 0;
    _musicTgt = 0;
    _started = false;
  }
}
