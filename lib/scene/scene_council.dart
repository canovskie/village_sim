part of '../main.dart';

/// Meclis — oyuncunun proaktif yönetişim kanalı (AJANS). Köy dilekçeleri
/// REAKTİF getirir (bekler, kendi şartlarında, mühletli); Meclis ise oyuncunun
/// İNİSİYATİFİ: Divan'dan meclisi çağırıp mayalanan bir gerilime PATLAMADAN
/// önce, kendi zamanında müdahale eder. "Karma ajans" — meselelerin çoğu
/// köyden gelir ama dümen artık tamamen oyuncunun elinden kaçmaz.
///
/// Council oturumu yapı olarak bir [Petition]'dır (aynı bildirimsel etki
/// altyapısı) ama oyuncu-başlatımlıdır: 'MECLİS' künyesiyle açılır, ambient
/// (oyun durmaz), istenince dağıtılır, mühlet/zorunluluk yoktur. Bir seçenek
/// uygulanınca meclis kısa süre "dinlenir" ([_kCouncilCooldown]) → söylev/taviz
/// spam'lenemez; her çağrı tartılmış bir karar olur.
///
/// Cozy/politik: meclis EKONOMİK baskı kurmaz; bedeli POLİTİKTİR — birini
/// yüceltmek çoğu kez rakibini gölgede bırakır (bkz. [_estateRival]).
extension _SceneCouncil on _VillageSceneState {
  /// Meclis bir kararın ardından bu kadar süre (sn) dinlenir — ~1.5 oyun günü.
  static const double _kCouncilCooldown = 1.5 * kGameDaySeconds;

  /// Meclis şu an çağrılabilir mi — dinlenme bitmiş + açık oturum yok + köy
  /// kürsüyü dolduracak kadar kalabalık.
  bool get _councilReady =>
      _hasFire &&
      _villagers.length >= 3 &&
      _councilSession == null &&
      _time >= _councilCooldownUntil;

  /// Divan'dan bir oturum çağır (id: `address` | `feud` | `estate:<name>`).
  void _convene(String id) {
    if (!_councilReady) return;
    final session = _buildCouncilSession(id);
    if (session == null) return;
    AudioManager.instance.playSfx(Sfx.bellChime);
    setStateHere(() {
      _councilSession = session;
      _councilSpeaker = _pickCouncilSpeaker(id, session);
      _divanOpen = false; // Divan'dan oturuma geçilir
    });
    _faceCouncilSpeaker(session);
  }

  /// Oturumu kapat (uygula): etkileri bağla + meclisi dinlenmeye al.
  void _resolveCouncil(PetitionOption o) {
    final session = _councilSession;
    if (session == null) return;
    setStateHere(() {
      _applyDecisionEffects(session, o, _councilSpeaker);
      _councilCooldownUntil = _time + _kCouncilCooldown;
      _councilSession = null;
      _councilSpeaker = null;
    });
    if (o.resolution.isNotEmpty) _showNotification(o.resolution);
  }

  /// Oturumu dağıt (karar verilmeden) — bedelsiz, dinlenme tetiklenmez.
  void _dismissCouncil() => setStateHere(() {
        _councilSession = null;
        _councilSpeaker = null;
      });

  /// Meclise çağrılan sözcü — feud'da kan davasının bir tarafı, aksi halde
  /// (varsa) ilgili zümreden / genelde köyün bir yetişkini.
  VillagerEntity? _pickCouncilSpeaker(String id, Petition session) {
    if (id == 'feud') return _feudMember() ?? _pickPetitionAuthor(session);
    return _pickPetitionAuthor(session);
  }

  /// Sözcüyü diegetik olarak meclise döndür — merkeze bakar + tonuna göre
  /// gövde refleksi. Global `_petitionAuthor`'a DOKUNMAZ (council ayrı).
  void _faceCouncilSpeaker(Petition p) {
    final v = _councilSpeaker;
    if (v == null || v.isSleeping || v.isInsideBuilding) return;
    final (cc, cr) = _villageCenter();
    v.lookToward(cc.toDouble(), cr.toDouble());
    v.feel(
      switch (p.tone) {
        PetitionTone.ominous => NpcEmotion.fear,
        PetitionTone.solemn => NpcEmotion.grief,
        PetitionTone.warm => NpcEmotion.wonder,
        PetitionTone.neutral => NpcEmotion.wonder,
      },
      2.4,
    );
  }

  // ── Oturum içeriği ──────────────────────────────────────────────────────────

  Petition? _buildCouncilSession(String id) {
    if (id == 'address') return _addressSession();
    if (id == 'feud') return _feudMember() == null ? null : _feudSession();
    if (id.startsWith('estate:')) {
      final name = id.substring(7);
      for (final e in Estate.values) {
        if (e.name == name) return _estateSession(e);
      }
    }
    return null;
  }

  /// 📢 Köye Söylev — kimliği proaktif yönlendir. Bir zümreyi yüceltmek onun
  /// nüfuzunu büyütür (köy o yöne kayar) ama rakibini biraz gölgede bırakır.
  /// Oyuncunun "politik dengeci" dümeni — dilekçeleri beklemeden köyü şekillendir.
  Petition _addressSession() {
    PetitionOption honor(Estate e, String label, String detail) => PetitionOption(
          label: label,
          detail: detail,
          resolution: '⚖ Söylev ${e.label} lehine verildi — köy o yöne kaydı.',
          moraleAmount: 0.03,
          moraleDays: 2,
          estateMood: [(e, 0.12), (_estateRival(e), -0.04)],
        );
    return Petition(
      id: 'council.address',
      petitioner: 'Meclis kürsüsü',
      icon: '📢',
      title: 'Köye Söylev',
      tone: PetitionTone.warm,
      note: '⚖ Meclisi sen topladın',
      stakes: 'Kimi yüceltirsen köy o yöne kayar — rakibi biraz gölgede kalır.',
      body: 'Meclisi topladın, köy kürsünün önünde toplandı. Bugün kimin '
          'emeğini, kimin sesini yücelteceğin köyün gidişatını belirler — '
          'birini öne çıkarmak çoğu kez rakibini gölgede bırakır.',
      options: [
        honor(Estate.laborers, 'Emeği öv',
            'Tarlanın, ocağın, madenin emekçilerini yücelt.'),
        honor(Estate.artisans, 'Zanaatı öv',
            'Tezgâhın ve örsün ustalarını yücelt.'),
        honor(Estate.faithful, 'İnancı öv',
            'Ayinin ve mananın sesini yücelt.'),
        honor(Estate.hearth, 'Ocağı öv',
            'Geleneğin ve yuvanın bekçilerini yücelt.'),
      ],
    );
  }

  /// Bir zümreyi PROAKTİF yatıştır — küskünlük dilekçeye dönüşmeden gönül al.
  /// Erken davranmak reaktif şikâyet dilekçesinden ucuzdur (ajansın ödülü).
  Petition _estateSession(Estate e) {
    final rival = _estateRival(e);
    return Petition(
      id: 'council.estate.${e.name}',
      petitioner: '${e.label} sözcüsü',
      icon: e.icon,
      title: '${e.label} ile Otur',
      tone: PetitionTone.solemn,
      estate: e,
      note: '⚖ Meclisi sen topladın',
      stakes: 'Erken davran — küskünlük büyümeden, ucuza gönül al.',
      body: '${e.label} bir süredir huzursuz. Daha dilekçe yazmadan meclisi '
          'topladın, dertlerini dinliyorsun. Şimdi atılacak küçük bir adım, '
          'sonra kabaracak bir küskünlükten çok daha ucuza gönüllerini alır.',
      options: [
        PetitionOption(
          label: 'Somut bir taviz ver',
          detail: 'Küçük bir bedel öde; ${e.label} el üstünde tutulduğunu görür.',
          resolution: '⚖ Meclis ${e.label} ile oturdu — gönüller alındı.',
          goldDelta: -4,
          moraleAmount: 0.03,
          moraleDays: 2,
          estateMood: [(e, 0.16), (rival, -0.03)],
        ),
        PetitionOption(
          label: 'Gönül al, söz ver',
          detail: 'Bedelsiz içten bir jest — küçük ama gerçek bir yakınlaşma.',
          resolution: '⚖ Meclis ${e.label} ile konuştu — hava biraz yumuşadı.',
          estateMood: [(e, 0.08)],
        ),
      ],
    );
  }

  /// 🩸 Sulh Meclisi — kan davasını PROAKTİF kapat (feudReconcile dilekçesini
  /// beklemeden). Etkileri reaktif sulhla aynı altyapıdan akar (feudPeace fx).
  Petition _feudSession() {
    return const Petition(
      id: 'council.feud',
      petitioner: 'Köyün yaşlıları',
      icon: '🩸',
      title: 'Sulh Meclisi',
      tone: PetitionTone.ominous,
      estate: Estate.hearth,
      note: '⚖ Meclisi sen topladın',
      stakes: 'Erken sulh, kan dökülmeden kapatır.',
      body: 'Kan davası köyü zehirliyor. Daha fazla mezar kazılmadan meclisi '
          'sen topladın: iki aileyi sofraya oturtabilir ya da en çok kan '
          'dökeni köyden uzaklaştırabilirsin.',
      options: [
        PetitionOption(
          label: 'Sulh dayat — barıştır',
          detail: 'Diyet öde, iki aileyi barıştır; husumet silinir, köy nefes alır.',
          resolution: '', // _reconcileFeud kendi isimli mesajını verir
          goldDelta: -5,
          moraleAmount: 0.10,
          moraleDays: 4,
          fx: PetitionFx.feudPeace,
          estateMood: [(Estate.faithful, 0.12), (Estate.hearth, 0.12)],
        ),
        PetitionOption(
          label: 'Suçluyu sürgün et',
          detail: 'En çok kan dökeni köyden kov — husumet uzaklaştırmayla diner.',
          resolution: '',
          fx: PetitionFx.feudExile,
          moraleAmount: -0.04,
          moraleDays: 2,
          estateMood: [(Estate.faithful, 0.04), (Estate.hearth, -0.06)],
        ),
      ],
    );
  }

  // ── UI build ────────────────────────────────────────────────────────────────

  /// Meclis oturumu modal'ı — dilekçe panosunu 'MECLİS' künyesiyle yeniden
  /// kullanır (oyuncu-başlatımlı çerçeve). Ambient: boşluğa dokun = dağıt.
  Widget buildCouncilModal() {
    return Positioned.fill(
      child: PetitionModal(
        petition: _councilSession!,
        author: _councilSpeaker,
        kicker: 'MECLİS',
        dismissHint: 'boşluğa dokun — meclisi dağıt',
        state: (
          morale: _stats.morale,
          population: _villagers.length,
          food: _stockpile.food,
          gold: _stockpile.gold,
        ),
        onChoose: _resolveCouncil,
        onDismiss: _dismissCouncil,
        onAuthorTap: _councilSpeaker == null
            ? null
            : () => setStateHere(() {
                  _selectedVillager = _councilSpeaker;
                  _councilSession = null; // meclis dağılır, köylü panele
                  _councilSpeaker = null;
                }),
      ),
    );
  }
}
