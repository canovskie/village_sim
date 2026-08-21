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
  sealStamp, // mühür vurulur — Kanunname'nin sesi
  birthJoy, // doğum
  funeralToll, // cenaze
  fightScuffle, // yumruklaşma / çekişme
  buildDone, // inşaat biter, gövde tamamlanır
  uiTap, // panel/düğme dokunuşu
  // ── İNSAN SESLERİ ────────────────────────────────────────────────────────
  // Köyde bugüne dek hiç insan sesi yoktu: çan, hayvan ve hava vardı, ağız
  // yoktu. Bunlar o boşluğu kapatır. Hepsi KELİMESİZ — metni `voice.dart`
  // yazıyor, ses ayrıca cümle kurarsa ikisi çelişir ve dil eklenince kadro
  // çöpe gider.
  childLaugh, // çocuk kıkırdaması — gündüz seyrek aksan (çocuk varsa)
  childrenPlay, // çocuk kalabalığı uğultusu — köyde 3+ çocuk varken
  cough, // hastalık: onset + hastalık sürerken seyrek
  throatClear, // dilekçe sahibi söze başlar ("öhöm")
  crowdApplause, // düğün alayı — köy ölçeğinde küçük grup alkışı
  buildStart, // şantiye kurulur, aletler çıkar
  workHit, // balta/kazma/çekiç temasının kısa, kuru aksanı
}

/// Müzik parçaları — ortamdan AYRI katman (bkz. [AudioManager.playMusic]).
enum MusicTrack {
  menu, // açılış/şafak menüsü
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
  bool _suspended = false;

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
    // Mühür kaydı tepesi -2.4 dB, çandan ~5 dB sıcak (ölçüldü). Tabanı 0.8'de
    // bırakmak onu köyün en sert sesi yapardı; 0.6 mührü çandan AĞIR ama
    // çatlamayan yerde tutar (0.42 sn'lik keskin transient kulakta büyür).
    Sfx.sealStamp: 0.6,
    Sfx.birthJoy: 0.75,
    Sfx.funeralToll: 0.7,
    Sfx.fightScuffle: 0.6,
    Sfx.buildDone: 0.55,
    Sfx.uiTap: 0.25,
    // İnsan sesleri ARKA PLANDA kalır: köyün gürültüsü değil, dokusu. Ağız
    // sesi öne çıkarsa 40 kişilik köy çorbaya döner.
    Sfx.childLaugh: 0.5,
    Sfx.childrenPlay: 0.45,
    Sfx.cough: 0.55,
    Sfx.throatClear: 0.5,
    Sfx.crowdApplause: 0.7,
    Sfx.buildStart: 0.5,
    Sfx.workHit: 0.34,
  };

  /// Efekt → DOSYA(LAR). Birden çok dosya varsa her çalışta rastgele biri
  /// seçilir — aynı sesin arka arkaya aynı duyulması, sık tetiklenen
  /// efektlerde (öksürük, çocuk kahkahası) tek başına yorucudur.
  static const Map<Sfx, List<String>> _sfxFile = {
    Sfx.bellChime: ['bell_chime.mp3'],
    Sfx.chickenCluck: ['chicken_cluck.mp3'],
    Sfx.cowMoo: ['cow_moo.mp3'],
    Sfx.roosterCrow: ['rooster_crow.mp3'],
    Sfx.crowdFair: ['crowd_fair.mp3'],
    Sfx.owl: ['owl.mp3'],
    Sfx.birds: ['birds_singing.mp3'],
    Sfx.thunderClap: ['thunder_clap.mp3'],
    Sfx.imperialMarch: ['imperial_march.mp3'],
    Sfx.fightScuffle: ['fight_scuffle.mp3'],
    Sfx.buildDone: ['build_done.mp3'],
    Sfx.childLaugh: ['child_laugh_1.mp3', 'child_laugh_2.mp3'],
    Sfx.childrenPlay: ['children_play.mp3'],
    Sfx.cough: ['cough_1.mp3', 'cough_2.mp3'],
    Sfx.throatClear: ['throat_clear.mp3'],
    Sfx.crowdApplause: ['crowd_applause.mp3'],
    Sfx.buildStart: ['build_start.mp3'],
    Sfx.workHit: ['work_hit.mp3'],
    Sfx.sealStamp: ['seal_stamp.mp3'],
    Sfx.birthJoy: ['birth_joy.mp3'],
    Sfx.funeralToll: ['funeral_toll.mp3'],
    // ── Dosyası BİLEREK yok ────────────────────────────────────────────────
    // Kanca duruyor, ses istenmedi (README "İSTENMEDİ"); sessiz kalır.
    Sfx.uiTap: ['ui_tap.mp3'],
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

  double _owlTimer = 22.0; // gece baykuş aksanı sayacı (sn)
  double _birdsTimer = 18.0; // gündüz kuş cıvıltısı aksanı sayacı (sn)
  double _childTimer = 30.0; // gündüz çocuk sesi aksanı sayacı (sn)

  // Varyant seçimi — aynı efektin arka arkaya aynı dosyayla çalmaması için.
  final Random _sfxRng = Random();
  final Map<Sfx, int> _lastVariant = {};

  // ── MÜZİK ────────────────────────────────────────────────────────────────
  // Tek oynatıcı: iki parça aynı anda çalmaz, geçiş "kıs → değiştir → aç"
  // biçiminde yapılır. İki oynatıcılı gerçek crossfade denenebilirdi ama köy
  // müziği sahne değiştirmiyor (menü ↔ oyun), o geçiş zaten ekran değişimiyle
  // maskeleniyor; iki kanal boşuna bellek ve boşuna karmaşa olurdu.
  AudioPlayer? _music;
  MusicTrack? _musicTrack;
  double _musicCur = 0.0; // anlık taban seviye (ayar öncesi)
  double _musicTgt = 0.0; // hedef taban seviye
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
        // setReleaseMode Future döner; cascade içinde bırakılınca hata
        // yakalanmadan uçuyordu — dosyanın geri kalanıyla aynı _safe kapısı.
        final p = AudioPlayer();
        _safe(p.setReleaseMode(ReleaseMode.stop));
        _sfxPool.add(p);
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

  /// Her tick (gerçek-zaman dt). Ortam + müzik seviyelerini hedefe yumuşatır
  /// ve gece baykuş / gündüz kuş aksanını tetikler.
  ///
  /// [children] köydeki çocuk sayısı — gündüz çocuk sesi aksanını açar. Sıfırsa
  /// hiç duyulmaz: çocuğu olmayan köyden çocuk sesi gelmesi, sesin dünyayla
  /// bağını koparan tam olarak o "arka planda teyp çalıyor" hissini verir.
  void update(
    double dt, {
    double dayLight = 1.0,
    Random? rng,
    int children = 0,
  }) {
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
      _safe(
        _music!.setVolume(
          _musicCur * SettingsModel.instance.effectiveMusicVolume,
        ),
      );
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
    // Çocuk sesi — gündüz, köyde çocuk varken seyrek aksan. Kuş aksanından
    // AYRI sayaç: ikisi aynı dala bağlansa biri diğerini hep bastırırdı.
    // Köy kalabalıklaşınca tek kıkırdama yerine oyun uğultusu duyulur.
    if (children > 0 && dayLight > 0.5) {
      _childTimer -= dt;
      if (_childTimer <= 0) {
        _childTimer = 50.0 + (rng?.nextDouble() ?? 0.5) * 70.0;
        playSfx(children >= 3 ? Sfx.childrenPlay : Sfx.childLaugh);
      }
    }
  }

  /// Tek-atış efekt çal — havuzdan sıradaki oynatıcıyla (üst üste binebilir).
  void playSfx(Sfx s) {
    if (!_started || _suspended || _sfxPool.isEmpty) return;
    final vol =
        (_sfxGain[s] ?? 0.8) * SettingsModel.instance.effectiveSfxVolume;
    if (vol <= 0.001) return;
    final files = _sfxFile[s];
    if (files == null || files.isEmpty) return;
    String file = files.first;
    if (files.length > 1) {
      // Saf rastgelelik ikilikte %50 tekrar demek; kulak iki kez üst üste
      // duyduğu varyantı "tek ses" sanır ve varyantın anlamı kalmaz.
      final last = _lastVariant[s] ?? -1;
      int i = _sfxRng.nextInt(files.length);
      if (i == last) i = (i + 1) % files.length;
      _lastVariant[s] = i;
      file = files[i];
    }
    final p = _sfxPool[_sfxIdx];
    _sfxIdx = (_sfxIdx + 1) % _sfxPool.length;
    _safe(p.play(AssetSource('$_dir/$file'), volume: vol));
  }

  /// Olasılıklı tek atış — zarı MOTORUN kendi rastgelesi atar.
  ///
  /// Sahnenin `_rng`'siyle ses zarı atmak sim'in deterministik akışını kaydırır:
  /// aynı tohumla açılan köy, sırf bir öksürük sesi bir sayı tükettiği için
  /// başka bir yola girer (kayıt/yükleme ve tohumlu testler bunu görür).
  /// Ses simülasyonu asla bükemez.
  void playSfxChance(Sfx s, double chance) {
    if (chance <= 0) return;
    if (chance < 1.0 && _sfxRng.nextDouble() >= chance) return;
    playSfx(s);
  }

  void _safe(Future<void> f) {
    f.catchError((_) {});
  }

  /// Mobil yaşam döngüsü: uygulama arka plandayken döngüleri gerçekten durdur.
  /// Ticker'ın susması tek başına yeterli değildir; native ses oynatıcıları
  /// Flutter kare üretmese de çalmayı sürdürebilir.
  void suspend() {
    if (!_started || _suspended) return;
    _suspended = true;
    for (final p in _cur.keys) {
      _safe(p.pause());
    }
    if (_music != null) _safe(_music!.pause());
    // Kısa efektleri geri dönüşte ortasından devam ettirmek anlamsızdır.
    for (final p in _sfxPool) {
      _safe(p.stop());
    }
  }

  /// Askıya alınan ortam ve müzik döngülerini kaldıkları yerden sürdür.
  void resume() {
    if (!_started || !_suspended) return;
    _suspended = false;
    for (final p in _cur.keys) {
      _safe(p.resume());
    }
    if (_music != null && _musicTrack != null) _safe(_music!.resume());
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
    _suspended = false;
    _started = false;
  }
}
