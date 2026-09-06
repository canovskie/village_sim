part of '../main.dart';

/// HESAPLAŞMA — koşunun kapanışı, dağılmanın simetriği.
///
/// Saf kurallar `systems/reckoning.dart` ve `systems/village_year.dart`'ta;
/// burası onları köye bağlar. Üç an vardır ve üçü de HABER VERİLMİŞTİR:
///
///   1. **İLAN** ([kReckoningHeraldYear] yılına girince, bir kez) — komutan
///      haber salar: gelecek yıl defter kapatılacak. Bu bir tehdit değil bir
///      TAKVİM: son yılın her kararı tartılacağını bilerek verilir.
///   2. **GERİ SAYIM** — ilan yılı boyunca ekranın üstünde kalıcı bir şerit
///      durur. Bildirim geçicidir, tarih geçici olmamalı.
///   3. **HESAPLAŞMA** ([kReckoningYear] yılının ilk günü) — heyet gelir,
///      defteri okur, kararını verir. Sinematik oynar, ardından kapanış
///      ekranı açılır ve kayıt mühürlenir.
///
/// KARARIN ÖLÇÜSÜ bilinçli olarak binalar DEĞİL: hanelerin rızası, tüzüğün
/// kalınlığı, köyün ağırlığı, kararların mirası ve imparatorlukla ilişki.
/// Gerekçesi [reckoning.dart] başlığında.
///
/// MUAF: godMode / showcase / referans köy / capture. Harness'ın koşusu
/// bitmemeli — prova köyü altıncı yılda kapanırsa bütün uzun testler ölür.
extension _SceneReckoning on _VillageSceneState {
  /// Hesaplaşma bu aralıkla (sn) yoklanır. Yılda bir kez açılan bir kapı için
  /// her kare bakmak gereksiz; gün sınırını kaçırmayacak kadar sık.
  static const double _kReckoningScan = 4.0;

  /// Hesaplaşma bu köyde işliyor mu. Dağılmayla aynı muafiyet listesi:
  /// iki kapanış kapısı da aynı köylerde kapalı olmalı, yoksa biri prova
  /// köyünü öldürürken diğeri yaşatır ve hangisinin konuştuğu anlaşılmaz.
  bool get _reckoningEnabled =>
      kProbeReckoningArmed ||
      (!_godMode && !widget.referenceVillage && !kCaptureMode);

  /// Kapanış ekranı açık mı — build() bunu okur.
  bool get _reckoned => _reckoningVerdict != null && !_reckoningPlaying;

  void _tickReckoning(double dt) {
    // KAPANIŞ EKRANI KİLİTLENMESİN — bu kontrol HER KAREDE, tarama kapısının
    // ÖNÜNDE. Karar verildikten sonra ekranı açan tek şey `_reckoningPlaying`in
    // düşmesi ve onu normalde `_onCutsceneDone` düşürür. Ama sinematiği
    // kaldıran BAŞKA yollar da var (harness bastırması, scene_tick'in kProbeOn
    // bloğu). O yollardan biri işlerse bayrak sonsuza dek yukarıda kalır ve
    // koşu ne biter ne sürer — oyuncu kapanmayan bir oyunda kalır. Sahibi kim
    // olursa olsun: sinematik gittiyse ekran açılır. (Taramanın ARKASINA
    // konursa film bittikten sonra ekran dört saniye gecikir.)
    if (_reckoningPlaying && _activeCutscene == null) {
      _reckoningPlaying = false;
      setStateHere(() {});
    }
    if (!_reckoningEnabled) return;

    _reckoningScan += dt;
    if (_reckoningScan < _kReckoningScan) return;
    _reckoningScan = 0;

    // Telemetri taramanın İÇİNDE ve erken çıkışın ÖNÜNDE. İçinde, çünkü
    // `_reckoningInput()` hane listesi kurar — her karede çalışırsa yılda bir
    // kez açılan bir kapı için kare başına çöp üretir. Erken çıkışın önünde,
    // çünkü arkasında kalırsa karar verildiği an telemetri donar ve prova
    // "karar verilmedi" der (dağılmada bire bir bu olmuştu).
    _probeReckoning();
    if (_collapsed || _reckoningVerdict != null) return;

    final year = yearOf(_dayCount);

    // ── 1) İLAN — bir kez, ilan yılına girildiğinde ───────────────────────
    if (!_reckoningHeralded && year >= kReckoningHeraldYear) {
      _reckoningHeralded = true;
      _heraldReckoning();
      return; // ilan ve hesaplaşma aynı taramada konuşmasın
    }

    if (year >= 2 && year < kReckoningYear && year > _karneYear) {
      _karneYear = year;
      _deliverKarne();
      return;
    }

    // ── 2) HESAPLAŞMA — hesaplaşma yılına girildiğinde ────────────────────
    if (year >= kReckoningYear) {
      // İlan atlanmışsa (kayıt eski bir sürümden geldi, gün ileri sarıldı)
      // sessizce geçme: en azından kroniğe düşsün.
      if (!_reckoningHeralded) {
        _reckoningHeralded = true;
        _chronicle('İmparatorluk defteri kapatmaya geldi.',
            icon: '📜', milestone: true);
      }
      _holdReckoning();
    }
  }

  /// Berat yılı ilan edildi. Bir yıl var.
  void _heraldReckoning() {
    final seed = _stableSeed('berat-ilan', _dayCount);
    _showNotification('📜 ${Voice.pick(_kHeraldLines, seed)}');
    _chronicle(Voice.pick(_kHeraldAnnal, seed), icon: '📜', milestone: true);
    logDev('BERAT İLANI: yıl ${yearOf(_dayCount)}, '
        'hesaplaşmaya ${daysUntilReckoning(_dayCount)} gün');
    final advice = karneAdvice(_reckoningInput());
    _chronicle(
        'Hazırlık yılı: en hafif kefeler ${advice[0].label.toLowerCase()} ve '
        '${advice[1].label.toLowerCase()}. İlki için: '
        '${kKarneHints[advice[0].label]}.',
        icon: '📯', kind: ChronicleKind.life);
  }

  void _deliverKarne() {
    final input = _reckoningInput();
    final v = judge(input);
    final weak = karneAdvice(input).first;
    final seed = _stableSeed('karne', _dayCount);
    _showNotification('📯 ${Voice.pick(const [
      'Komutandan pusula geldi.',
      'Heyetin katibi yıllık pusulayı bıraktı.',
      'İmparatorluğun defterinden bir satır düştü.',
    ], seed)} Bugün tartılsa: ${v.name}. En hafif kefe: '
        '${weak.label.toLowerCase()}.');
    _chronicle(
        'Komutanın pusulası: bugün tartılsa ${v.name}. En hafif kefe '
        '${weak.label.toLowerCase()}.',
        icon: '📯', kind: ChronicleKind.life);
  }

  /// Köyün beş yılını 0..1 aralığına çevirir. Ham birimler (kile, nüfuz,
  /// itibar) BURADA kalır; karar veren saf dosya onları hiç görmez.
  ReckoningInput _reckoningInput() {
    // HANELERİN RIZASI — duruş merdiveninin nüfuzla ağırlıklı ortalaması.
    // Nüfuzlu bir hanenin küsmesi, kenardaki bir hanenin küsmesiyle aynı
    // şey değil: köyü büyük hane taşır, o gidince köy sallanır.
    var unity = 0.55; // hane yoksa nötr (kuruluşun ilk günleri)
    final houses = _houses.snapshot().where((h) => h.members > 0).toList();
    if (houses.isNotEmpty) {
      var sum = 0.0, weight = 0.0;
      for (final h in houses) {
        // Pay sıfıra inebilir (tek hane, tüm nüfuz onda) → taban ağırlık ver,
        // yoksa bölme boşa çıkar ve tek haneli köy hep 0.55 okunur.
        final w = 0.2 + h.swayShare;
        sum += _stanceScore(h.stance) * w;
        weight += w;
      }
      if (weight > 0) unity = (sum / weight).clamp(0.0, 1.0);
    }

    // TÜZÜĞÜN KALINLIĞI — yürürlükteki hüküm + kazanılmış kimlik. Sekiz hüküm
    // tavan sayılır (son kademenin istediği sayı); kimlik ayrı bir dilim
    // çünkü "çok mühür bastım ama hiçbir yöne yatmadım" bir duruş değildir.
    final policyPart = (_policies.enactedCount / 8.0).clamp(0.0, 1.0);
    final identityPart =
        _regimeIdentity.regime != VillageRegime.moderate ? 1.0 : 0.0;
    final charter = (policyPart * 0.72 + identityPart * 0.28).clamp(0.0, 1.0);

    // KÖYÜN AĞIRLIĞI — nüfus ve refah. Elli can, son kademenin ölçüsü.
    final popPart = (_villagers.length / 50.0).clamp(0.0, 1.0);
    final wealthPart = (_impProsperity / 240.0).clamp(0.0, 1.0);
    final grit = (popPart * 0.70 + wealthPart * 0.30).clamp(0.0, 1.0);

    // KARARLARIN MİRASI — ±0.12 bandındaki iz, 0..1'e serilir. Hiç büyük
    // karar vermemiş köy tam ortada (0.5) durur: nötr, ceza değil.
    final legacy = ((_governanceLegacy + 0.12) / 0.24).clamp(0.0, 1.0);

    return ReckoningInput(
      unity: unity,
      charter: charter,
      grit: grit,
      legacy: legacy,
      favor: _imperialFavor.clamp(0.0, 1.0),
    );
  }

  /// Hane duruşunun 0..1 karşılığı. Merdivenin kendisi zaten sıralı; buradaki
  /// aralıklar eşit DEĞİL: serzeniş hâlâ çalışan bir hanedir (uyarı), el
  /// çekmek ise köyün elini gerçekten eksiltir — arada uçurum olmalı.
  double _stanceScore(HouseStance s) => switch (s) {
        HouseStance.loyal => 1.0,
        HouseStance.content => 0.78,
        HouseStance.murmuring => 0.55,
        HouseStance.withdrawn => 0.28,
        HouseStance.hoarding => 0.14,
        HouseStance.defiant => 0.0,
      };

  /// HEYET DEFTERİ AÇTI — karar verilir, sinematik oynar, koşu kapanır.
  void _holdReckoning() {
    if (_reckoningVerdict != null) return;
    final input = _reckoningInput();
    final verdict = judge(input);
    _reckoningVerdict = verdict;
    _reckoningInputCache = input;

    _chronicle(
      switch (verdict) {
        ReckoningVerdict.sancak =>
          '$_villageName kendi sancağını dikti. İmparatorluk tanıdı.',
        ReckoningVerdict.berat =>
          '$_villageName beratını aldı. Adı deftere kalıcı yazıldı.',
        ReckoningVerdict.ilhak =>
          '$_villageName ilhak edildi. Defter imparatorluğa devredildi.',
      },
      icon: verdict.icon,
      milestone: true,
    );
    logDev('HESAPLAŞMA: ${verdict.name} '
        '(güç=${input.standing.toStringAsFixed(2)} '
        'itibar=${input.favor.toStringAsFixed(2)})');

    // Kaydı MÜHÜRLE — dağılmayla aynı sözleşme: kapanmış defter silinmez,
    // menüde okunabilir kalır (bkz. scene_save `_sealSaveAsEnded`).
    _sealSaveAsEnded();

    // Sinematik önce, ekran sonra. `_playCutscene` capture modunda hiç
    // oynatmaz → orada bayrak baştan kapalı kalmalı, yoksa ekran hiç açılmaz.
    final cs = reckoningCutscene(verdict,
        village: _villageName,
        favor: _imperialFavor,
        seed: _stableSeed('hesaplaşma', _dayCount));
    _reckoningPlaying = !kCaptureMode;
    _playCutscene(cs, logEntry: '$_villageName hesaplaştı');
    setStateHere(() {});
  }

  /// Kapanış ekranı — koşunun karnesi.
  Widget buildReckoningScreen() => ReckoningScreen(
        village: _villageName,
        verdict: _reckoningVerdict ?? ReckoningVerdict.ilhak,
        epilogue: verdictEpilogue(
            _reckoningVerdict ?? ReckoningVerdict.ilhak, _regimeIdentity.regime),
        identity: _regimeIdentity.title,
        years: yearOf(_dayCount),
        days: _dayCount,
        population: _villagers.length,
        rows: reckoningLedger(_reckoningInputCache ??
            const ReckoningInput(
                unity: 0, charter: 0, grit: 0, legacy: 0, favor: 0)),
        // Kroniğin kilometre taşları — koşunun kendi özeti.
        milestones: [
          for (final e in _storyLog.reversed.take(6)) '${e.icon} ${e.text}',
        ],
        onExit: () {
          _saveNow();
          widget.onExitToMenu?.call();
        },
      );

  /// PROVA kancası — hesaplaşma gerçek sahnede sürülebilsin diye
  /// (bkz. test/reckoning_probe_test.dart). Oyunda etkisiz.
  ///
  /// Neden gün ATLAMA: hesaplaşma altıncı yılda, yani ~81. günde. 24× hızla
  /// bile oraya gerçek zamanda pump ederek varmak on dakikayı aşar. Prova
  /// takvimi ileri sarar; ölçtüğü şey zamanın geçişi değil, tarihin GELDİĞİNDE
  /// ne olduğudur.
  void _probeReckoning() {
    if (kProbeJumpToDay > 0) {
      _dayCount = kProbeJumpToDay;
      kProbeJumpToDay = 0;
    }
    kProbeYear = yearOf(_dayCount);
    kProbeDay = _dayCount;
    kProbeGold = _stockpile.gold;
    kProbePop = _villagers.length;
    kProbeReckoningHeralded = _reckoningHeralded;
    kProbeVerdict = _reckoningVerdict?.name ?? '';
    kProbeStanding = _reckoningInput().standing;
  }

  /// BERAT GERİ SAYIMI — ilan yılı boyunca ekranın üstünde durur.
  ///
  /// Dağılma şeridiyle aynı yeri paylaşır ve ONA ÖNCELİK VERİR: köy dağılmak
  /// üzereyken gelecek yılın takvimini göstermek, yanan evin içinde takvim
  /// okumaktır. İki şerit üst üste binmesin diye tek kapıdan geçer.
  Widget buildReckoningBanner() => ListenableBuilder(
        listenable: _frame,
        builder: (_, _) {
          if (!_reckoningEnabled || _collapsed || _reckoningVerdict != null) {
            return const SizedBox.shrink();
          }
          if (_collapse.vitality.visible) return const SizedBox.shrink();
          if (!_reckoningHeralded) return const SizedBox.shrink();
          final left = daysUntilReckoning(_dayCount);
          return Positioned(
            top: 8,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xE60C0D0F),
                    borderRadius: BorderRadius.circular(AppUi.radiusSm),
                    border: Border.all(color: const Color(0x66E9C552)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('📜', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 8),
                      Text(
                        left <= 0
                            ? 'Heyet defteri açmak üzere'
                            : 'Berat yılına $left gün',
                        style: AppUi.body.copyWith(
                          fontSize: 11.5,
                          color: AppUi.gold,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
}

// ── Beratın sesi ([[lib/text/voice.dart]]) ───────────────────────────────────

const _kHeraldLines = [
  'Bir atlı geldi, inmeden konuştu: gelecek yıl defter kapatılacak.',
  'Haber yoldan geldi. İmparatorluk gelecek yıl bu köy için bir karar verecek.',
  'Komutandan pusula: önümüzdeki yıl berat günü. Ne kurduysanız o tartılacak.',
];

const _kHeraldAnnal = [
  'Berat yılı ilan edildi.',
  'İmparatorluk gelecek yıl karar verecek.',
  'Defterin kapanacağı yıl duyuruldu.',
];
