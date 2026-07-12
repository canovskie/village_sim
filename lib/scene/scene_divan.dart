part of '../main.dart';

/// Divan — köyün her zaman açık yönetişim merkezi (UI omurgası).
///
/// Dilekçe sistemi artık "kıyıda bekleyen bir mühür" değil: Divan, sim'de olan
/// biteni tek yüzeyde toplar. GÜNDEM köyün senden ne istediğini (bekleyen
/// dilekçe) + neyin mayalandığını (henüz patlamamış baskılar) gösterir →
/// yönetişim "araya giren modal" olmaktan çıkıp köyün nabzına dönüşür.
///
/// Bu katman SALT-OKUNUR: yeni simülasyon yürütmez, mevcut state'i (zümreler,
/// dilekçe, hafıza, yasalar) okuyup gösterir. Mayalanan meseleler dilekçeleri
/// kapılayan AYNI sinyallerden (küskün zümre, kan davası, kıtlık, zincir
/// kuyruğu) türetilir — yani gündem köyün gerçekten "birazdan ne soracağını"
/// dürüstçe önizler.
extension _SceneDivan on _VillageSceneState {
  /// Zümre morali bu eşiğin altındaysa "huzursuz" sayılır (mayalanan dilekçe).
  static const double _kDivanUneasy = 0.50;

  void _openDivan() => setStateHere(() => _divanOpen = true);
  void _closeDivan() => setStateHere(() => _divanOpen = false);

  /// Zümre nabzı tabelasındaki "⚖ DİVAN" pilinden açılan tam panel.
  Widget buildDivanPanel() {
    return Positioned.fill(
      child: ListenableBuilder(
        listenable: _frame,
        builder: (_, _) => DivanPanel(
          identity: _houses.identityName,
          morale: _stats.morale,
          population: _villagers.length,
          food: _stockpile.food,
          gold: _stockpile.gold,
          agenda: _divanAgenda(),
          houses: _houses.snapshot(),
          laws: _divanLaws(),
          marks: _divanMarks(),
          legacy: _governanceLegacy,
          onOpenPetition: _pendingPetition == null
              ? null
              : () => setStateHere(() {
                    _divanOpen = false;
                    _petitionModalOpen = true;
                  }),
          onConvene: _convene,
          councilReady: _councilReady,
          onClose: _closeDivan,
        ),
      ),
    );
  }

  /// Zümre nabzı rozetindeki sayaç: bekleyen + mayalanan mesele toplamı.
  int _divanAgendaCount() => _divanAgenda().length;

  /// KALICI Divan mührü — yönetişimin her an görünür kapısı (sol üst, HUD
  /// şeridinin altında). Meclis eskiden üç kat gömülüydü (yan pano → pil →
  /// modal içi buton) ve bir köylü/bina seçilince o kapı ekrandan kayboluyordu;
  /// bu mühür hep durur. PERF: gündem sayımı köylü/hane/tarla tarar → 60fps
  /// `_frame` yerine ~10Hz `_hudFrame`'e bağlı.
  Widget buildDivanSeal() {
    return Positioned(
      left: 14,
      top: 92,
      child: RepaintBoundary(
        child: ListenableBuilder(
          listenable: _hudFrame,
          builder: (_, _) => DivanSeal(
            onTap: _openDivan,
            agendaCount: _divanAgendaCount(),
            pendingPetition: _pendingPetition != null,
            councilReady: _councilReady,
          ),
        ),
      ),
    );
  }

  // ── Gündem türetme ──────────────────────────────────────────────────────────

  /// Bekleyen dilekçe (varsa) gündemin tepesinde + mayalanan baskılar (baskıya
  /// göre azalan). Dilekçeleri kapılayan aynı sinyallerden okunur.
  List<DivanMatter> _divanAgenda() {
    final out = <DivanMatter>[];

    // 1) Bekleyen gerçek dilekçe — gündemin tepesi, yanıt butonlu.
    final p = _pendingPetition;
    if (p != null) {
      final grace = (_petitionDeadline / _ScenePetitions._kPetitionGrace)
          .clamp(0.0, 1.0);
      out.add(DivanMatter(
        icon: p.icon,
        title: p.title,
        sub: p.stakes ?? '${p.petitioner} bir dilekçe sundu.',
        pressure: 1.0 - grace,
        tone: p.tone,
        pending: true,
        graceProgress: grace,
        urgent: grace <= _ScenePetitions._kPetitionUrgentFrac,
      ));
    }

    // 2) Mayalanan baskılar — patlamamış ama gündeme akan gerilimler.
    final brewing = <DivanMatter>[];

    // Küskün/huzursuz haneler — gönülleri alınmazsa dilekçe yazarlar.
    // (Salience sıralı gelir; en huzursuzları zaten başa düşer.)
    for (final h in _houses.snapshot()) {
      final mood = h.mood;
      if (mood >= _kDivanUneasy) continue;
      final sullen = mood < 0.40;
      brewing.add(DivanMatter(
        icon: '⌂',
        title: '${h.label} ${sullen ? 'küskün' : 'huzursuz'}',
        sub: sullen
            ? 'Gönülleri alınmazsa ısrarla gündeme gelecekler.'
            : 'Hava soğuyor — bir jest beklentisi var.',
        pressure: ((_kDivanUneasy - mood) / _kDivanUneasy).clamp(0.1, 1.0),
        tone: sullen ? PetitionTone.ominous : PetitionTone.solemn,
      ));
    }

    // Kan davası — köyü zehirler, sulh meclisi an meselesi.
    if (_feudMember() != null) {
      brewing.add(const DivanMatter(
        icon: '🩸',
        title: 'Kan davası köyü zehirliyor',
        sub: 'İki aile arasında kan dökülüyor — sulh kararı yaklaşıyor.',
        pressure: 0.9,
        tone: PetitionTone.ominous,
        conveneId: 'feud',
      ));
    }

    // Çağrısına küs köylü — meslek değiştirme dilekçesi mayalanıyor.
    if (_resentfulVillager() != null) {
      brewing.add(const DivanMatter(
        icon: '🌫️',
        title: 'Biri gönlündeki işi özlüyor',
        sub: 'Mesleğine küs bir köylü çağrısının peşinden gitmek istiyor.',
        pressure: 0.4,
        tone: PetitionTone.solemn,
      ));
    }

    // Zincir kuyruğu — geçmiş bir karardan doğan, zamanı yaklaşan takip.
    for (final f in _petitionFollowUps) {
      final fp = PetitionSystem.byId(f.id);
      if (fp == null) continue;
      final remain = (f.fireAtSim - _time).clamp(0.0, double.infinity);
      final pressure =
          (1.0 - remain / (2.0 * kGameDaySeconds)).clamp(0.15, 0.95);
      brewing.add(DivanMatter(
        icon: fp.icon,
        title: fp.title,
        sub: 'Geçmiş bir kararın yankısı — yakında gündeme gelecek.',
        pressure: pressure,
        tone: fp.tone,
      ));
    }

    // Ambar inceliyor — kıtlık baskısı (kış erzak / hasat dilekçelerinin zemini).
    final mouths = _villagers.length + _farmers.length;
    if (mouths > 0 && _stockpile.food < mouths * 2) {
      brewing.add(DivanMatter(
        icon: '🥖',
        title: 'Ambar inceliyor',
        sub: 'Erzak azalıyor — köy bölüşüm kararı istemeden tedbir al.',
        pressure: (1.0 - _stockpile.food / (mouths * 2.0)).clamp(0.2, 0.95),
        tone: PetitionTone.ominous,
      ));
    }

    // Yaz kuraklığı zemini — işlenen tarla varken güneş ekini tehdit eder.
    final hasCrops = _farmTiles.any((t) => t.isGrowing || t.readyToHarvest);
    if (_season == Season.summer && hasCrops) {
      brewing.add(const DivanMatter(
        icon: '☀️',
        title: 'Yaz güneşi ekini kavurabilir',
        sub: 'Kuyu suyu hayati — çiftçiler yakında su isteyebilir.',
        pressure: 0.35,
        tone: PetitionTone.ominous,
      ));
    }

    // Sürü aç — ahır bakımsızsa yem/hastalık dilekçesi mayalanır.
    int herd = 0;
    double hungerSum = 0;
    for (final c in _cows) {
      if (c.isDying) continue;
      herd++;
      hungerSum += c.hunger;
    }
    if (herd > 0 && hungerSum / herd > 0.5) {
      brewing.add(const DivanMatter(
        icon: '🐄',
        title: 'Sürü aç kalıyor',
        sub: 'Ahır bakımsız — yem sıkıntısı gündeme gelmek üzere.',
        pressure: 0.45,
        tone: PetitionTone.solemn,
      ));
    }

    // Baskıya göre azalan sırada, en fazla 5 mayalanan mesele (gündem dağılmasın).
    brewing.sort((a, b) => b.pressure.compareTo(a.pressure));
    out.addAll(brewing.take(5));
    return out;
  }

  // ── Köyün hâli ──────────────────────────────────────────────────────────────

  /// Yürürlükteki yasalar — kararlarının köyde kalıcı izi (proaktif fermanlar).
  List<DivanFact> _divanLaws() {
    final out = <DivanFact>[];
    if (_policies.family != FamilyPolicy.open) {
      out.add(DivanFact('👨‍👩‍👧', _policies.family.label, AppUi.info));
    }
    for (final d in kPolicyDefs) {
      if (_policies.isOn(d.id)) out.add(DivanFact(d.icon, d.label, AppUi.info));
    }
    return out;
  }

  /// Kararların kalıcı izleri — köy hafızası bayraklarının okunur karşılığı.
  /// identity.* atlanır (kimlik zaten başlıkta). Bilinmeyen bayrak gösterilmez.
  List<DivanFact> _divanMarks() {
    const sage = AppUi.sage;
    const rust = AppUi.rust;
    const accent = AppUi.accent;
    final known = <String, DivanFact>{
      'cult.active': DivanFact('⛪', 'İnanç kök saldı', accent),
      'cult.temple': DivanFact('⛪', 'Tapınak dikildi', accent),
      'cult.suppressed': DivanFact('⛪', 'İnanç bastırıldı', rust),
      'cult.united': DivanFact('🕊️', 'İnanç uzlaştı', sage),
      'fields.tended': DivanFact('🌾', 'Tarlalara iyi bakıldı', sage),
      'fields.neglected': DivanFact('🍂', 'Tarlalar ihmal edildi', rust),
      'pact.neighbor': DivanFact('🤝', 'Komşuyla anlaşma', sage),
      'migrants.welcomed': DivanFact('🧳', 'Göçmenler kabul edildi', sage),
      'holyDay.active': DivanFact('🕯️', 'Kutsal gün yürürlükte', accent),
      'council.elders': DivanFact('🏛️', 'Yaşlılar meclisi', accent),
      'council.youth': DivanFact('🌱', 'Gençler meclisi', accent),
      'road.open': DivanFact('🛤️', 'Ticaret yolu açık', sage),
      'road.closed': DivanFact('⛔', 'Yol kapatıldı', rust),
      'festival.tradition': DivanFact('🎉', 'Şenlik geleneği', sage),
    };
    final out = <DivanFact>[];
    for (final flag in _villageMemory) {
      final f = known[flag];
      if (f != null) out.add(f);
    }
    return out;
  }
}
