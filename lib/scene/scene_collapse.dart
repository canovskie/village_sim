part of '../main.dart';

/// KAYBETME EŞİĞİ — ayrılık ve dağılma.
///
/// Saf kurallar `systems/village_collapse.dart`'ta; burası onları köye bağlar.
/// İki kademe var ve ikincisi birincinin sonucudur:
///
///   1. **AYRILIK** — kopuş basamağında ([HouseStance.defiant]) yeterince gün
///      kalan hane köyü TERK EDER. İnsanlarını ve sakladığı yiyeceği alır,
///      evleri boş kalır. Geri dönüş yoktur. Siyasi ihmalin kalıcı bedeli.
///   2. **DAĞILMA** — köyü döndürecek el kalmayınca köy dağılır: koşu biter,
///      kayıt kapanır. Ayrılıkla, ölümle, göçle ya da hepsiyle gelinebilir.
///
/// KURALIN KENDİSİ: kayıp HABER VERİLMİŞ olmalı. Ayrılığın önünde beş
/// basamaklık esirgeme merdiveni + günlerce süren bir sayaç + son uyarı var;
/// dağılmanın önünde iki evre (gergin → çöküyor) + görünür geri sayım var. Bu
/// katmanın hiçbir yerinde sessiz ölüm yoktur.
///
/// MUAF: godMode / showcase / referans köy. Harness ölürse prova ölür.
extension _SceneCollapse on _VillageSceneState {
  /// Köyün ayakta kalabilirliği bu aralıkla (sn) yoklanır.
  static const double _kVitalityScan = 3.0;

  /// Köyü döndüren el sayısı — mesleği olabilen, ölmekte olmayan köylüler.
  /// Çocuk sayılmaz: dağılma ölçüsü "kim çalışabiliyor"dur.
  int get _adultCount {
    var n = 0;
    for (final v in _villagers) {
      if (!v.isDying && v.hasProfession) n++;
    }
    return n;
  }

  /// Kaybetme eşiği bu köyde işliyor mu. Prova/showcase köyleri ölümsüzdür.
  bool get _collapseEnabled =>
      kProbeCollapseArmed ||
      (!_godMode && !widget.referenceVillage && !kCaptureMode);

  void _tickCollapse(double dt) {
    // TELEMETRİ ÖNCE: aşağıdaki erken çıkışın ARDINDA kalırsa dağılma anında
    // sayaçlar donar ve prova "köy dağılmadı" der — oysa dağılmıştır. (Bu tam
    // olarak oldu: sim doğru çalışıyordu, ölçüm kördü.)
    kProbeCollapsed = _collapsed;
    if (_collapsed) return; // dağıldı, sahne donduruldu
    _vitalityScan += dt;
    _collapseAccum += dt;
    if (_vitalityScan < _kVitalityScan) return;
    final dayFrac = _collapseAccum / kGameDaySeconds;
    _vitalityScan = 0;
    _collapseAccum = 0;

    _probeCollapse();

    // Kurulmuşluk filigranı — ancak kurduğunu kaybedersin.
    final adults = _adultCount;
    if (adults > _peakAdults) _peakAdults = adults;
    if (!_collapseEnabled) return;

    final st = evaluateCollapse(
      adults: adults,
      population: _villagers.where((v) => !v.isDying).length,
      peakAdults: _peakAdults,
      countdown: _collapseCountdown,
    );
    _collapseCountdown = advanceCountdown(
      countdown: _collapseCountdown,
      vitality: st.vitality,
      dayFrac: dayFrac,
    );
    _collapse = st;

    _announceVitality(st);
    if (st.collapsed) _dissolveVillage(st.cause ?? CollapseCause.noHands);
  }

  /// Evre değişimini duyurur. Aynı evrede kalınırken sessiz — geri sayım
  /// zaten HUD'da görünür (bkz. `buildCollapseBanner`).
  void _announceVitality(CollapseState st) {
    if (st.vitality == _vitalitySeen) return;
    final worse = st.vitality.index > _vitalitySeen.index;
    _vitalitySeen = st.vitality;
    if (st.collapsed) return; // dağılma kendi ekranıyla konuşur
    final seed = _stableSeed('vitality${st.vitality.name}', _dayCount);
    switch (st.vitality) {
      case VillageVitality.strained:
        _showNotification('⚠ ${Voice.pick(worse ? _kStrainedLines : _kRecoverLines, seed)}');
        if (worse) _chronicle(Voice.pick(_kStrainedAnnal, seed), icon: '⚠');
      case VillageVitality.failing:
        _showNotification('☠ ${Voice.pick(_kFailingLines, seed)}');
        _chronicle(Voice.pick(_kFailingAnnal, seed), icon: '☠', milestone: true);
      case VillageVitality.healthy:
        if (!worse) {
          _showNotification('🌤 ${Voice.pick(_kRecoverLines, seed)}');
        }
      case VillageVitality.collapsed:
        break;
    }
  }

  /// KÖY DAĞILDI — koşu biter. Sim durur, kayıt mühürlenir, mezar taşı açılır.
  void _dissolveVillage(CollapseCause cause) {
    if (_collapsed) return;
    _collapsed = true;
    _collapseCause = cause;
    _chronicle(
        cause == CollapseCause.emptied
            ? 'Son can da gitti. Ocak söndü.'
            : 'Köyü döndürecek el kalmadı. Ocak söndü.',
        icon: '☠',
        milestone: true);
    // Kaydı MÜHÜRLE — sürdürülemez olur ama SİLİNMEZ: oyuncunun köyünü oyun
    // kendi eliyle yok etmez, kapanmış bir defter olarak menüde durur (silmek
    // oyuncunun kararı). Mühür kaydın kendi meta'sındadır (bkz. scene_save).
    _sealSaveAsEnded();
    setStateHere(() {});
  }

  /// Dağılan köyün mezar taşı — koşunun özeti + kroniğin son satırları.
  Widget buildCollapseScreen() => CollapseScreen(
        village: _villageName,
        cause: _collapseCause ?? CollapseCause.noHands,
        days: _dayCount,
        peakAdults: _peakAdults,
        identity: _houses.identityName,
        // Kroniğin SON satırları (en yenisi başta) — köyün son sözleri.
        epitaph: [
          for (final e in _storyLog.reversed.take(6))
            '${e.icon} ${e.text}',
        ],
        onExit: () {
          _saveNow();
          widget.onExitToMenu?.call();
        },
      );

  /// Geri sayım şeridi — köy gergin ya da çöküyorsa ekranın üstünde durur.
  /// Bildirim geçicidir; bu şerit KALICIDIR: oyuncu tehlikeyi kaçırdım
  /// diyemesin. Sağlıklı köyde hiç çizilmez.
  Widget buildCollapseBanner() => ListenableBuilder(
        listenable: _frame,
        builder: (_, _) {
          final st = _collapse;
          if (!st.vitality.visible || _collapsed) return const SizedBox.shrink();
          final critical = st.vitality.counting;
          return Positioned(
            top: 8,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xE60C0D0F),
                    borderRadius: BorderRadius.circular(AppUi.radiusSm),
                    border: Border.all(
                        color: critical
                            ? const Color(0xAAD9534F)
                            : const Color(0x66E9C552)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(critical ? '☠' : '⚠',
                          style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 8),
                      Text(
                        critical
                            ? 'Köy dağılmak üzere — ${st.daysLeft.ceil()} gün'
                            : 'Köyde el azaldı',
                        style: AppUi.body.copyWith(
                          fontSize: 11.5,
                          color: critical ? const Color(0xFFE8A19E) : AppUi.gold,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (critical) ...[
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 64,
                          height: 5,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: 1.0 - st.spent,
                              backgroundColor: AppUi.surface0,
                              valueColor: const AlwaysStoppedAnimation(
                                  Color(0xFFD9534F)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );

  /// PROVA kancası — kaybetme eşiği gerçek sahnede sürülebilsin diye
  /// (bkz. test/collapse_probe_test.dart). Oyunda etkisiz.
  void _probeCollapse() {
    if (kProbeForceSchism) {
      kProbeForceSchism = false;
      String? best;
      var bestShare = -1.0;
      for (final h in _houses.snapshot()) {
        if (h.members <= 0) continue;
        if (h.swayShare > bestShare) {
          bestShare = h.swayShare;
          best = h.surname;
        }
      }
      if (best != null) {
        kProbeSchismHouse = best;
        _houses.nudge(best, swayGain: 4.0);
      }
    }
    // Kopuşu TUT — yoksa oyun haneyi merdivenden indirir ve sayaç sıfırlanır.
    if (kProbeSchismHouse.isNotEmpty) {
      _houses.nudge(kProbeSchismHouse, moodDelta: -1.0);
      for (final v in _villagers) {
        if (v.surname == kProbeSchismHouse) v.morale = 0.0;
      }
      // Sayacı eşiğin hemen altına kur — ama ANCAK hane gerçekten kopuşa
      // düştükten sonra. (Önce kurmak işe yaramıyordu: `tickDefiance` kopuk
      // olmayan hanenin sayacını sıfırlar, prova hep baştan başlardı.)
      if (_houses.stanceOf(kProbeSchismHouse) == HouseStance.defiant &&
          _houses.schismOf(kProbeSchismHouse) <= 0) {
        _houses.tickDefiance(kSchismDays * 0.80);
      }
    }
    // Köyü geri sayım bandında TUT — çocuklar yetişkinliğe geçtikçe buda.
    if (kProbeDrainVillage) {
      final adults = [
        for (final v in _villagers)
          if (!v.isDying && v.hasProfession) v
      ];
      for (var i = 0; i + 1 < adults.length; i++) {
        _removeVillager(adults[i]);
      }
    }
    kProbeVitality = _collapse.vitality.name;
    kProbeCollapseDaysLeft =
        _collapse.daysLeft.isInfinite ? -1 : _collapse.daysLeft;
    kProbeCollapsed = _collapsed;
    kProbeAdults = _adultCount;
  }

  // ── AYRILIK ────────────────────────────────────────────────────────────────

  /// Kopuş sayaçlarını yürütür: son uyarıyı düşürür, süresi dolan haneyi yolcu
  /// eder. [dayFrac] bu turda geçen oyun günü kesri.
  void _tickSchism(double dayFrac) {
    if (dayFrac <= 0 || !_collapseEnabled) return;

    // Son uyarı — "arabalar yüklendi". Hane başına BİR kez.
    for (final s in _houses.surnames.toList()) {
      if (_houses.stanceOf(s) != HouseStance.defiant) {
        _schismWarned.remove(s);
        continue;
      }
      if (_houses.schismOf(s) < kSchismFinalWarn) continue;
      if (!_schismWarned.add(s)) continue;
      final ctx = _voice(_headOfSurname(s),
          seed: _stableSeed('ayrılık$s', _dayCount), extra: {'hane': s});
      _showNotification('🚪 ${Voice.say(_kSchismWarn, ctx)}');
      _chronicle(Voice.say(_kSchismWarnAnnal, ctx), icon: '🚪');
    }

    for (final s in _houses.tickDefiance(dayFrac)) {
      _houseLeavesVillage(s);
    }
  }

  /// Hane köyü terk etti — insanları, sakladığı yiyecek ve nüfuzu onlarla gider.
  /// GERİ DÖNÜŞÜ YOK: bu, esirgeme merdivenini sonuna kadar götürmenin bedeli.
  void _houseLeavesVillage(String surname) {
    final members = [
      for (final v in _villagers)
        if (!v.isDying && v.surname == surname) v
    ];
    final hidden = _houses.stashOf(surname);
    final ctx = _voice(_headOfSurname(surname),
        seed: _stableSeed('göç$surname', _dayCount), extra: {'hane': surname});

    _showNotification('💔 ${Voice.say(_kSchismLeave, ctx)}');
    _chronicle(
        '$surname Hanesi ${_villageWith(Suffix.ablative)} ayrıldı: '
        '${members.length} can, $hidden kile.',
        icon: '💔',
        milestone: true);
    logDev('AYRILIK: $surname (${members.length} kişi, $hidden kile)');

    for (final v in members) {
      _removeVillager(v);
    }
    // Nüfuz ve ambar da onlarla gider — geride hayalet hane kalmasın.
    _houses.removeHouse(surname);
    kProbeHousesLeft++;
    _houseStanceSeen.remove(surname);
    _schismWarned.remove(surname);
    // Kalan köy sarsılır: gidenler komşuydu.
    pushPolicyMorale(-0.08, 4.0);
    _unrest = (_unrest + 0.08).clamp(0.0, 1.0);
  }
}

// ── Dağılmanın sesi ([[lib/text/voice.dart]]) ────────────────────────────────

const _kStrainedLines = [
  'Köyde el azaldı. İşler yetişmiyor, herkes bunu görüyor.',
  'Meydan seyrek. Aynı işi aynı birkaç kişi çeviriyor.',
  'Köy inceldi. Bir sıkıntı daha kaldıramaz gibi duruyor.',
];
const _kStrainedAnnal = [
  'Köyde el azaldı.',
  'Nüfus inceldi, işler aksadı.',
  'Köy seyreldi.',
];

const _kFailingLines = [
  'Köy kendini döndüremiyor artık. Bir şey yapılmazsa dağılacak.',
  'Ocakta iki el kaldı. Bu köy bu hâlde kışı çıkaramaz.',
  'Köy son demlerinde. Ya insan gelecek ya kapı kapanacak.',
];
const _kFailingAnnal = [
  'Köy dağılmanın eşiğine geldi.',
  'Köyü döndürecek el kalmadı sayılır.',
  'Son eşik: köy tükenmek üzere.',
];

const _kRecoverLines = [
  'Köy toparlanıyor. Meydan yeniden kalabalık.',
  'Eller çoğaldı, iş yürüyor. Tehlike geçti.',
  'Köy nefes aldı. Kapı kapanmadı.',
];

const _kSchismWarn = [
  '{hane} Hanesi arabalarını yükledi. Yarın öbür gün yola çıkarlar.',
  '{ad} eşyalarını çıkarttı. {hane} Hanesi gitmeye hazırlanıyor.',
  '{hane} Hanesi\'nin kapısında denk var. Bu son fırsat.',
];
const _kSchismWarnAnnal = [
  '{hane} Hanesi gitmeye hazırlanıyor.',
  '{hane} Hanesi yol hazırlığında.',
  '{hane} Hanesi ayrılmak üzere.',
];

const _kSchismLeave = [
  '{hane} Hanesi çekip gitti. Bir daha dönmeyecekler.',
  '{ad} arkasına bakmadan yürüdü. {hane} Hanesi artık bu köyün değil.',
  '{hane} Hanesi ocağını söndürdü ve yola çıktı. Evleri boş kaldı.',
];
