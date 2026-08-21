import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../characters/life_stage.dart';
import '../characters/npc_visual.dart';
import '../characters/villager_names.dart';
import '../rendering/character_renderer.dart';
import '../systems/founding_choice.dart';
import '../text/village_names.dart';
import '../text/voice.dart';
import '../ui/app_ui.dart';
import '../ui/mobile_ui.dart';
import 'cutscene.dart';

part 'cutscene_founding.dart';
part 'cutscene_painter.dart';

/// Tam ekran 2B sinematik oynatıcı — [kOpeningCutscene] gibi storyline
/// "filmlerini" oynatır. Prosedürel arka plan + mevcut karakter sprite'ları
/// (CharacterRenderer, asset gerektirmez) aktör olarak. Kendi ticker'ı var;
/// oyun simülasyonundan bağımsız akar. Tıkla = ilerle, sağ üst = Atla.
class CutscenePlayer extends StatefulWidget {
  final Cutscene cutscene;
  final VoidCallback onDone;

  /// Gerçek açılışta isim formu ateş kurulduktan sonra dünya üstünde açılır.
  /// Varsayılan true, bağımsız cutscene kullanımlarında kapı sözleşmesini
  /// korur.
  final bool showNameGate;

  /// nameVillage kapısı onaylanınca girilen adlar — köyün adı + hanenin (soy)
  /// adı. Hane adı kurucuların hepsine soyad olarak işlenir ("X Hanesi"),
  /// köyün adı kayıt slotuna geçer.
  final void Function(String village, String house)? onNameChosen;

  /// chooseCaravan kapısında seçilen yük — kurucu kadro + başlangıç stoğu.
  final void Function(FoundingChoice choice)? onFoundingChoice;

  // ── Animasyon odası kancaları (oyunda varsayılan davranış değişmez) ───────
  /// Sahne saatinin hızı (1.0 normal). Animasyon odasında yavaşlatıp pozları
  /// tek tek incelemek için.
  final double timeScale;

  /// true iken sahne saati durur — kare kare bakmak için.
  final bool paused;

  /// Her karede (çekim indeksi, çekimde geçen süre, toplam çekim) bildirir.
  final void Function(int shot, double elapsed, int shotCount)? onProgress;

  /// Sinematik bitince kendiliğinden başa sarar (oda listesinde döngü).
  final bool loop;

  /// Görsel galeri ve yakalama araçlarında karar anını beklemeden açar.
  /// Oyunda kapalıdır; gerçek sinematik akışını değiştirmez.
  final bool startAtGate;

  const CutscenePlayer({
    super.key,
    required this.cutscene,
    required this.onDone,
    this.showNameGate = true,
    this.onNameChosen,
    this.onFoundingChoice,
    this.timeScale = 1.0,
    this.paused = false,
    this.onProgress,
    this.loop = false,
    this.startAtGate = false,
  });

  @override
  State<CutscenePlayer> createState() => _CutscenePlayerState();
}

class _CutscenePlayerState extends State<CutscenePlayer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _time = 0; // genel animasyon saati (yürüyüş/titreşim)
  double _shotElapsed = 0; // mevcut çekimde geçen süre
  int _shotIndex = 0;
  bool _done = false;

  // Mini-aksiyon (gate) durumu.
  bool _gateSatisfied = false; // mevcut çekimin kapısı geçildi mi
  double _gateSatisfiedAt = 0; // ignite flash için zaman damgası
  final _nameCtrl = TextEditingController();
  final _houseCtrl = TextEditingController();
  final _nameFocus = FocusNode();
  final _houseFocus = FocusNode();

  /// Ad önerileri — tek düğme her dokunuşta sıradaki adı verir.
  late final List<VillageNameIdea> _ideaPool = shuffledVillageNameIdeas();
  int _ideaOffset = 0;

  /// Diyalog kutusunun ÖLÇÜLEN yüksekliği (px). Kamera özneyi kutunun üstünde
  /// tutabilmek için ekranın altında ne kadar yer kaldığını bilmek zorunda;
  /// kutu 1-3 satır arasında değiştiği için sabit oran yeterli değil. Bir kare
  /// gecikmeli okunur (60 fps'te görünmez).
  final _boxKey = GlobalKey();
  double _boxHeight = 0;

  // Tempo sabitleri — sakin, sinematik (aceleci kayma yok).
  static const double _charTime = 0.032; // sn/harf (daktilo)
  static const double _lineHold = 2.1; // satır tam okununca bekleme
  static const double _shotTail = 1.0; // çekim sonu boşluk
  static const double _actorMove = 6.5; // en uzak aktörün yürüyüş süresi

  CutsceneShot get _shot => widget.cutscene.shots[_shotIndex];

  /// Bu çekim MEKÂN değiştiriyor mu (önceki çekimden farklı arka plan).
  bool get _bgChanged =>
      _shotIndex == 0 || widget.cutscene.shots[_shotIndex - 1].bg != _shot.bg;

  /// Çekim başı karartma. Aynı mekânda kalan çekimler her seferinde TAM siyaha
  /// düşerse film kesik kesik olur (açılışta 6 kararma üst üste) — mekân
  /// değişince gerçek kesme, değişmeyince kısa ve yarı saydam bir dalgalanma.
  double get _fadeIn => _bgChanged ? 0.7 : 0.34;
  double get _fadeDepth => _bgChanged ? 1.0 : 0.55;

  @override
  void initState() {
    super.initState();
    if (widget.startAtGate) _shotElapsed = _gateReadyAt();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _nameCtrl.dispose();
    _houseCtrl.dispose();
    _nameFocus.dispose();
    _houseFocus.dispose();
    super.dispose();
  }

  bool get _gated =>
      _shot.gate != CutsceneGate.none &&
      !(widget.cutscene == kOpeningCutscene &&
          _shot.gate == CutsceneGate.nameVillage &&
          !widget.showNameGate) &&
      !_gateSatisfied;

  void _onTick(Duration elapsed) {
    var dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    if (widget.paused) {
      // Duraklıyken bile kare akmalı (setState çağrılır) ki oda kontrolleri
      // anında yansısın; yalnız sahne saati ilerlemez.
      setState(() {});
      return;
    }
    dt *= widget.timeScale;
    _time += dt;
    if (_gated) {
      // Kapı: replikler oynasın (Maple konuşsun) ama satırlar bitince DURSUN;
      // sonra kapı UI'ı (ad kutusu / ateş ipucu) belirir.
      _shotElapsed = min(_shotElapsed + dt, _gateReadyAt());
    } else {
      _shotElapsed += dt;
      if (_shotElapsed >= _shotEnd()) _advanceShot();
    }
    widget.onProgress?.call(
      _shotIndex,
      _shotElapsed,
      widget.cutscene.shots.length,
    );
    setState(() {});
  }

  /// Kapılı çekimde repliklerin tam yazıldığı an — kapı UI'ı bundan sonra çıkar.
  double _gateReadyAt() {
    if (_shot.lines.isEmpty) return _fadeIn;
    final starts = _lineStarts();
    final last = _shot.lines.length - 1;
    return starts[last] + _reveal(last);
  }

  bool get _gateReady =>
      _gated && (widget.startAtGate || _shotElapsed >= _gateReadyAt() - 0.001);

  void _satisfyGate() {
    if (_gateSatisfied) return;
    setState(() {
      _gateSatisfied = true;
      _gateSatisfiedAt = _time;
    });
  }

  void _submitName() {
    final village = _nameCtrl.text.trim();
    final house = _houseCtrl.text.trim();
    FocusManager.instance.primaryFocus?.unfocus();
    // Boş bırakmak serbest — kapı bir formu doldurtmak için değil, kimliği
    // oyuncuya AÇMAK için var. Boşsa host kendi varsayılanını (rastgele soyad)
    // korur; '' göndermek onu ezmez.
    widget.onNameChosen?.call(village.isEmpty ? 'Köy' : village, house);
    _satisfyGate();
  }

  /// Öneriye dokunuldu — ad kutuya YAZILIR (kilitlenmez). Oyuncu üstüne
  /// yazabilsin diye imleç sona alınır.
  void _applyIdea(VillageNameIdea idea) {
    setState(() {
      _nameCtrl.text = idea.name;
      _nameCtrl.selection = TextSelection.collapsed(offset: idea.name.length);
    });
  }

  /// TELEFON öneri düğmesi: havuzdan SIRADAKİ adı kutuya yazar, hane kutusu
  /// boşsa ona da bir soyad koyar. Yatay telefonda çip galerisine yer yok
  /// (ray sahneyi eziyordu) — öneri tek dokunuşa iner, gerekçesi başlıkta
  /// belirir. Dolu hane kutusuna DOKUNMAZ: oyuncunun yazdığı ad ezilmez.
  void _suggestForMobile() {
    _applyIdea(_ideaPool[_ideaOffset % _ideaPool.length]);
    // Tek adım ilerle: her dokunuş SIRADAKİ adı verir, havuzda ad atlanmaz.
    setState(() => _ideaOffset = (_ideaOffset + 1) % _ideaPool.length);
    if (_houseCtrl.text.trim().isEmpty) _rollHouseName();
  }

  /// Soy adı kutusuna havuzdan bir ad — köy adının aksine burada anlam kartı
  /// yok, çünkü soyadı yerin değil ailenin işidir (havuz: villager_names).
  void _rollHouseName() {
    final name = randomVillagerSurname(Random());
    setState(() {
      _houseCtrl.text = name;
      _houseCtrl.selection = TextSelection.collapsed(offset: name.length);
    });
  }

  void _chooseCaravan(FoundingChoice c) {
    if (_gateSatisfied) return;
    widget.onFoundingChoice?.call(c);
    _satisfyGate();
  }

  // ── Satır zamanlaması ──────────────────────────────────────────────────────
  double _reveal(int i) => _shot.lines[i].text.length * _charTime;
  double _lineDur(int i) => _reveal(i) + _lineHold;

  List<double> _lineStarts() {
    final starts = <double>[];
    double t = _fadeIn;
    for (int i = 0; i < _shot.lines.length; i++) {
      starts.add(t);
      t += _lineDur(i);
    }
    return starts;
  }

  double _contentEnd() {
    final lines = _shot.lines;
    if (lines.isEmpty) return _shot.actors.isNotEmpty ? _actorMove : 2.0;
    final starts = _lineStarts();
    return starts.last + _lineDur(lines.length - 1);
  }

  double _shotEnd() =>
      max(_contentEnd(), _shot.actors.isNotEmpty ? _actorMove : 0.0) +
      _shotTail;

  int _currentLine() {
    if (_shot.lines.isEmpty) return -1;
    final starts = _lineStarts();
    int idx = 0;
    for (int i = 0; i < starts.length; i++) {
      if (_shotElapsed >= starts[i]) idx = i;
    }
    return idx;
  }

  void _advanceShot() {
    if (_shotIndex >= widget.cutscene.shots.length - 1) {
      if (widget.loop) {
        // Odada döngü: baştan oynat (yeni widget kurmadan).
        _shotIndex = 0;
        _shotElapsed = 0;
        _gateSatisfied = false;
        return;
      }
      _finish();
      return;
    }
    _shotIndex++;
    _shotElapsed = 0;
    _gateSatisfied = false; // yeni çekimin kapısı tazelenir
  }

  void _finish() {
    if (_done) return;
    _done = true;
    widget.onDone();
  }

  void _onTap() {
    // Kapı bekliyorsa: önce daktiloyu bitir; sonra ateş→dokun yakar,
    // ad→giriş alanı yönetir (base no-op).
    if (_gated) {
      if (_shotElapsed < _gateReadyAt()) {
        _shotElapsed = _gateReadyAt();
        return;
      }
      if (_shot.gate == CutsceneGate.tapToIgnite) _satisfyGate();
      return;
    }
    final lines = _shot.lines;
    if (lines.isEmpty) {
      _shotElapsed = _shotEnd();
      return;
    }
    final idx = _currentLine();
    final starts = _lineStarts();
    final revealEnd = starts[idx] + _reveal(idx);
    if (_shotElapsed < revealEnd) {
      _shotElapsed = revealEnd; // önce daktiloyu bitir
    } else if (idx < lines.length - 1) {
      _shotElapsed = starts[idx + 1]; // sonraki satır
    } else {
      _shotElapsed = _shotEnd(); // çekimi kapat
    }
  }

  @override
  Widget build(BuildContext context) {
    final idx = _currentLine();
    final CutsceneLine? line = idx >= 0 ? _shot.lines[idx] : null;
    String shown = '';
    if (line != null) {
      final starts = _lineStarts();
      final le = _shotElapsed - starts[idx];
      // +1e-6: daktilonun bitişi tam olarak len*_charTime'dır ve KAPILI
      // çekimde saat oraya KIRPILIR (_gateReadyAt). Kayan nokta bir tık aşağı
      // düşünce floor() son harfi yutuyordu — kapı açıldığında Maple'ın sorusu
      // soru işaretsiz kalıyordu ("…biz neyi yükledik"). Kapı olmayan
      // çekimlerde saat akmaya devam ettiği için hiç görülmemişti.
      final n = (le / _charTime + 1e-6).floor().clamp(0, line.text.length);
      shown = line.text.substring(0, n);
    }
    // Çekim başı karadan açılma katsayısı.
    final fade = (_shotElapsed / _fadeIn).clamp(0.0, 1.0);

    // Kutunun bir önceki karedeki yüksekliği — kameranın kadraj payı.
    final box = _boxKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) _boxHeight = box.size.height;
    // Replik yokken yalnız letterbox yer kaplar (kutu ölçüsü taşınmaz).
    final reservedBottom = shown.isEmpty ? 0.0 : _boxHeight + _kBoxMargin;

    final igniteShot = _shot.gate == CutsceneGate.tapToIgnite;
    final nameShot =
        _shot.gate == CutsceneGate.nameVillage && widget.showNameGate;
    final caravanShot = _shot.gate == CutsceneGate.chooseCaravan;
    final ignited = !igniteShot || _gateSatisfied;
    final igniteElapsed = _gateSatisfied ? (_time - _gateSatisfiedAt) : -1.0;

    // Material sarmalayıcı: ad kapısının TextField'ı Material atası ister.
    // Oyunda sinematik Scaffold'un içinde durduğu için görünmüyordu, ama
    // oynatıcıyı Scaffold'suz mount eden her yer (galeri yakalaması, animasyon
    // odası) o kapıda kırmızı hata ekranına düşüyordu. Bağımlılığı içeride
    // kapatmak, çağıranın doğru ağacı kurmasını ummaktan ucuz.
    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _onTap,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _CutscenePainter(
                  shot: _shot,
                  time: _time,
                  shotElapsed: _shotElapsed,
                  fade: fade,
                  fadeDepth: _fadeDepth,
                  // Aktör hareketi fadeIn sonrası başlar; SÜREYİ aktör başına
                  // painter hesaplar (herkes aynı hızda yürür, aynı anda varmaz).
                  moveElapsed: _shotElapsed - _fadeIn,
                  moveDur: _actorMove,
                  // Kamera: çekim boyunca yayılır, sonunda oturur (drift yok).
                  camT: (_shotElapsed / _shotEnd()).clamp(0.0, 1.0),
                  // O an konuşan aktör — ışık onda kalır, diğerleri kısılır.
                  speaker: line?.speaker,
                  // Letterbox bantları sinematiğin başında iner (sert kesme yok).
                  introT: (_time / 0.6).clamp(0.0, 1.0),
                  // Kadraj payı: kamera özneyi bu bandın üstünde tutar.
                  reservedBottom: reservedBottom,
                  ignited: ignited,
                  igniteElapsed: igniteElapsed,
                ),
              ),
            ),
            // Diyalog kutusu.
            // Ad verme kapısı açıldığında diyalog kutusu yerini bütünüyle
            // kuruluş ekranına bırakır. İki ayrı koyu panel üst üste binmez.
            if (shown.isNotEmpty && !((nameShot || caravanShot) && _gateReady))
              _dialogueBox(line!, shown),
            // "▸ Devam" göstergesi — satır tam yazıldığında, kapı yokken belirir.
            // Böylece ilerlemenin ekrana dokunmakla olduğu NET (rastgele değil).
            if (_showContinueHint(line, shown)) _continueHint(),
            // Ateşi yak ipucu (replikler bitti, kapı bekliyor).
            if (igniteShot && _gateReady) _igniteHint(),
            // Köye ad ver girişi (replikler bitti, kapı bekliyor).
            if (nameShot && _gateReady) _nameInput(),
            // Kafilenin yükü — üç kart (replikler bitti, kapı bekliyor).
            if (caravanShot && _gateReady) _caravanChoice(),
            // Atla.
            if (!(nameShot && _gateReady && useTouchUi(context)))
              Positioned(
                top: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: TextButton(
                      key: const ValueKey('cutscene_skip'),
                      onPressed: _finish,
                      style: TextButton.styleFrom(
                        foregroundColor: AppUi.accentSoft,
                        backgroundColor: const Color(0xB8141519),
                        side: BorderSide(
                          color: AppUi.accent.withValues(alpha: 0.45),
                        ),
                        // Sinematiği atlamak telefondaki en kritik kaçış kapısı;
                        // 66×32dp'de kalıyordu. HIG tabanı 44dp. minimumSize tek
                        // başına yetmiyor (VisualDensity kutuyu geri kısıyor) —
                        // dikey payı da 44'ü verecek kadar aç.
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        minimumSize: const Size(MobileUi.tap, MobileUi.tap),
                        visualDensity: VisualDensity.standard,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppUi.radiusSm),
                        ),
                      ),
                      child: Text(
                        identical(widget.cutscene, kOpeningCutscene)
                            ? 'İntroyu geç ▸'
                            : 'Atla ▸',
                        style: AppUi.button.copyWith(color: AppUi.accentSoft),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Diyalog kutusunun alt kenar payı (padding + nefes) — kadraj hesabı bunu
  /// kutunun ölçülen yüksekliğine ekler.
  static const double _kBoxMargin = 34.0;

  Widget _dialogueBox(CutsceneLine line, String shown) {
    final isNarration = line.speaker == null;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Container(
                key: _boxKey,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xF21A130B),
                  borderRadius: BorderRadius.circular(AppUi.radiusSm),
                  border: Border.all(color: AppUi.line, width: 1),
                  boxShadow: AppUi.softShadow,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isNarration) ...[
                      Text(
                        line.speaker!.toUpperCase(),
                        style: AppUi.label.copyWith(color: AppUi.accent),
                      ),
                      const SizedBox(height: 6),
                    ],
                    Text(
                      shown,
                      style: TextStyle(
                        fontFamily: AppUi.fontText,
                        fontStyle: isNarration
                            ? FontStyle.italic
                            : FontStyle.normal,
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                        height: 1.4,
                        color: AppUi.textHi,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Satır tam yazıldı + kapı yok → "devam" ipucu gösterilebilir.
  bool _showContinueHint(CutsceneLine? line, String shown) =>
      line != null && !_gated && shown == line.text;

  /// "▸ Devam" — sağ altta nabız atan ipucu; ilerlemenin dokunmakla
  /// olduğunu netleştirir (rastgele tıklama hissini giderir).
  Widget _continueHint() {
    final pulse = 0.45 + 0.35 * sin(_time * 3.2);
    return Positioned(
      right: 22,
      bottom: 30,
      child: IgnorePointer(
        child: Opacity(
          opacity: pulse,
          child: Text(
            'dokun ▸',
            style: AppUi.button.copyWith(color: AppUi.textHi),
          ),
        ),
      ),
    );
  }

  /// "Ateşi yakmak için dokun" ipucu — nabız atan, ateşin üstünde.
  Widget _igniteHint() {
    final pulse = 0.55 + 0.45 * sin(_time * 3.0);
    return Align(
      alignment: const Alignment(0, 0.30),
      child: IgnorePointer(
        child: Opacity(
          opacity: pulse,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0x66000000),
              borderRadius: BorderRadius.circular(AppUi.radiusSm),
              border: Border.all(color: AppUi.accent.withValues(alpha: 0.7)),
            ),
            child: Text(
              '✦  Ateşi yakmak için dokun',
              style: AppUi.button.copyWith(color: AppUi.accentSoft),
            ),
          ),
        ),
      ),
    );
  }

  /// Kafilenin yükü — üç kart. Oyuncunun oyundaki İLK kararı; kurucu kadroyu,
  /// nüfusu ve başlangıç stoğunu değiştirir.
  ///
  /// Kartlar ekranın ÜST yarısına oturur: alttaki diyalog kutusu (Maple'ın
  /// sorusu) ekranda kalmalı — soru görünmeden seçenek okunmaz.
  Widget _caravanChoice() {
    final touch = useTouchUi(context);
    final screen = MediaQuery.sizeOf(context);
    return Positioned.fill(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 760,
                maxHeight: touch ? screen.height - 24 : 520,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xD914151A),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: AppUi.accent.withValues(alpha: 0.42),
                      ),
                      boxShadow: AppUi.softShadow,
                    ),
                    child: Text(
                      'ARABAYA NE ALDIK?',
                      style: AppUi.label.copyWith(
                        color: AppUi.accentSoft,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ),
                  SizedBox(height: touch ? 8 : 12),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final c in FoundingChoice.all) ...[
                          Expanded(child: _caravanCard(c)),
                          if (c != FoundingChoice.all.last)
                            const SizedBox(width: 10),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _caravanCard(FoundingChoice c) {
    return _FoundingLoadCard(
      key: ValueKey('founding_choice_${c.id}'),
      choice: c,
      onTap: () => _chooseCaravan(c),
    );
  }

  /// Köye ad ver girişi — metin alanı + onay. Onaylanınca kapı geçilir.
  Widget _nameInput() {
    if (useTouchUi(context)) return _mobileNameInput();
    return _desktopNameInput();
  }

  /// Telefonda form bir "modal pencere" değil, sahnenin alt kenarına oturan
  /// ince bir kimlik rayıdır. Klavye açılınca başlık geri çekilir; yalnız
  /// iki alan ile onay kalır ve ray klavyenin hemen üstüne taşınır.
  Widget _mobileNameInput() {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final keyboardOpen = keyboardInset > 0;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      left: MobileUi.left(context),
      right: MobileUi.right(context),
      bottom: keyboardOpen
          ? keyboardInset + MobileUi.gap
          : MobileUi.bottom(context),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: MobileUi.windowMaxW),
          child: KeyedSubtree(
            key: const ValueKey('mobile_name_dock'),
            child: MobileSurface(
              padding: EdgeInsets.fromLTRB(
                12,
                keyboardOpen ? 8 : 10,
                12,
                keyboardOpen ? 8 : 10,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!keyboardOpen) ...[
                    KeyedSubtree(
                      key: const ValueKey('mobile_name_header'),
                      child: Row(
                        children: [
                          const GameLogo(size: 24),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'KÖYÜNÜ ADLANDIR',
                              style: AppUi.title.copyWith(
                                fontSize: 14,
                                letterSpacing: 1.3,
                              ),
                            ),
                          ),
                          TextButton(
                            key: const ValueKey('mobile_name_idea_button'),
                            onPressed: _suggestForMobile,
                            style: TextButton.styleFrom(
                              foregroundColor: AppUi.accentSoft,
                              minimumSize: const Size(
                                MobileUi.tap,
                                MobileUi.tap,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                            ),
                            child: const Text('🎲 ÖNER', style: AppUi.button),
                          ),
                          TextButton(
                            onPressed: _finish,
                            style: TextButton.styleFrom(
                              foregroundColor: AppUi.textLo,
                              minimumSize: const Size(
                                MobileUi.tap,
                                MobileUi.tap,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                            ),
                            child: const Text('ATLA', style: AppUi.button),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  KeyedSubtree(
                    key: const ValueKey('mobile_name_fields'),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: _mobileNameField(
                            fieldKey: const ValueKey('village_name_field'),
                            label: 'KÖYÜN ADI',
                            controller: _nameCtrl,
                            hint: 'Pınarköy',
                            focusNode: _nameFocus,
                            action: TextInputAction.next,
                            onSubmitted: (_) => _houseFocus.requestFocus(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _mobileNameField(
                            fieldKey: const ValueKey('house_name_field'),
                            label: 'KURUCU SOYU',
                            controller: _houseCtrl,
                            hint: 'Yılmaz',
                            focusNode: _houseFocus,
                            action: TextInputAction.done,
                            onSubmitted: (_) => _submitName(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          key: const ValueKey('founding_name_submit'),
                          width: 116,
                          child: AppButton(
                            label: 'TAMAM',
                            icon: GameIconData.flame,
                            kind: AppButtonKind.filled,
                            expand: true,
                            height: 48,
                            onTap: _submitName,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _mobileNameField({
    required Key fieldKey,
    required String label,
    required TextEditingController controller,
    required String hint,
    required FocusNode focusNode,
    bool autofocus = false,
    required TextInputAction action,
    required ValueChanged<String> onSubmitted,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppUi.label.copyWith(
            color: AppUi.textMid,
            fontSize: 10,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          key: fieldKey,
          controller: controller,
          autofocus: autofocus,
          focusNode: focusNode,
          textCapitalization: TextCapitalization.words,
          textInputAction: action,
          maxLength: 22,
          maxLines: 1,
          scrollPadding: EdgeInsets.zero,
          onChanged: (_) => setState(() {}),
          onSubmitted: onSubmitted,
          style: AppUi.bodyHi.copyWith(fontSize: 15),
          cursorColor: AppUi.accent,
          decoration: InputDecoration(
            counterText: '',
            hintText: hint,
            hintStyle: AppUi.body.copyWith(color: AppUi.textLo),
            isDense: true,
            filled: true,
            fillColor: AppUi.surface0.withValues(alpha: 0.76),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppUi.radiusSm),
              borderSide: const BorderSide(color: AppUi.glassEdge),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppUi.radiusSm),
              borderSide: const BorderSide(color: AppUi.accent, width: 1.2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _desktopNameInput() {
    return Positioned.fill(
      child: SafeArea(
        child: Stack(
          children: [
            Align(
              alignment: const Alignment(0, -0.08),
              child: _FoundingIdentity(
                village: _nameCtrl.text.trim(),
                house: _houseCtrl.text.trim(),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 18,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xEB211E22), Color(0xF20D0E0F)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0x4CF1C588)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0xA6000000),
                          blurRadius: 28,
                          offset: Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: _mobileNameField(
                            fieldKey: const ValueKey('village_name_field'),
                            label: 'KÖYÜN ADI',
                            controller: _nameCtrl,
                            hint: 'Pınarköy',
                            focusNode: _nameFocus,
                            autofocus: true,
                            action: TextInputAction.next,
                            onSubmitted: (_) => _houseFocus.requestFocus(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _mobileNameField(
                            fieldKey: const ValueKey('house_name_field'),
                            label: 'KURUCU SOYU',
                            controller: _houseCtrl,
                            hint: 'Yılmaz',
                            focusNode: _houseFocus,
                            action: TextInputAction.done,
                            onSubmitted: (_) => _submitName(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _IdeaChip(label: '🎲 ÖNER', onTap: _suggestForMobile),
                        const SizedBox(width: 10),
                        SizedBox(
                          key: const ValueKey('founding_name_submit'),
                          width: 180,
                          child: _FoundingSubmitButton(onTap: _submitName),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tek dokunuşluk ad önerisi. Seçiliyken ember dolgu — hangi adın kutuda
/// olduğu tek bakışta okunsun. Dokunma alanı 44dp (telefonda da aynı çip).
