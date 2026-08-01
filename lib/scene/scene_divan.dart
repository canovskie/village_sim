part of '../main.dart';

/// KÖY DEFTERİ — köy içi işlerin TEK kapısı (UI omurgası).
///
/// Eskiden köyün kendi hakkındaki bilgisi beş ayrı yüzeye dağılmıştı: Divan sol
/// üstte bir mühür, Nüfus Defteri HUD'ın geliştirici ikonları arasında, Hikâye
/// sol alttaki ⚙ kümesinde bir chip, Görevler sol kenarda ayrı bir pano,
/// Kanunname ise Divan'ın içinde bir sekme. Hepsi tek çerçevede toplandı; kapı
/// bir tane (defter mührü), içeride bölüm değiştirilir.
///
/// Bu katman SALT-OKUNUR: yeni simülasyon yürütmez, mevcut state'i (haneler,
/// dilekçe, hafıza, yasalar, nüfus, görevler, kronik) okuyup gösterir.
/// Mayalanan meseleler dilekçeleri kapılayan AYNI sinyallerden (küskün hane,
/// kan davası, kıtlık, zincir kuyruğu) türetilir — yani gündem köyün gerçekten
/// "birazdan ne soracağını" dürüstçe önizler.
extension _SceneDivan on _VillageSceneState {
  /// Hane morali bu eşiğin altındaysa "huzursuz" sayılır (mayalanan dilekçe).
  static const double _kDivanUneasy = 0.50;

  /// Defteri (istenen bölümden) açar. Açıkken başka bölüme geçmek de buradan.
  void _openLedger([LedgerSection s = LedgerSection.divan]) =>
      setStateHere(() => _ledgerSection = s);
  void _closeLedger() => setStateHere(() => _ledgerSection = null);

  /// Defter mühründen (ve HUD/pano kısayollarından) açılan tam panel.
  Widget buildVillageLedger() {
    return Positioned.fill(
      child: ListenableBuilder(
        listenable: _frame,
        builder: (_, _) => VillageLedger(
          initialSection: _ledgerSection ?? LedgerSection.divan,
          badges: _ledgerBadges(),
          // Metin havuzlarının tohumu: gün. Pano gün içinde aynı okunur,
          // ertesi gün başka kelimelerle konuşur (rebuild'de zıplamaz).
          seed: _dayCount,
          identity: _houses.identityName,
          morale: _stats.morale,
          population: _villagers.length,
          food: _stockpile.food,
          gold: _stockpile.gold,
          // ⚖ DİVAN
          agenda: _divanAgenda(),
          houses: _houses.snapshot(),
          seats: _divanHeads(),
          houseActionsFor: _houseActionEntries,
          massSeizure: _massSeizureEntry(),
          laws: _divanLaws(),
          marks: _divanMarks(),
          crafts: _divanCrafts(),
          legacy: _governanceLegacy,
          onOpenPetition: _pendingPetition == null
              ? null
              : () => setStateHere(() {
                    _ledgerSection = null;
                    _petitionModalOpen = true;
                  }),
          // 📜 KANUNNAME — fermana dokun → meclis toplanır (mühür ritüeli).
          sealed: _policies.sealed,
          lawContext: _lawContext,
          lawSpotlightId: _lawSpotlightId,
          inkDrySec: _inkDryRemaining(),
          inkDryTotalSec: _inkDryTotal,
          onOpenLaw: _openLawRitual,
          // ⚑ REJİM — kimliğin bedeli: yetki kuralı, köyün sabrı, yemin ve
          // fesih. Kadran bunları defterin başında gösterir.
          regimeRule: _regimeRule,
          unrest: _unrest,
          swornRegime: _oathRegime,
          regimeRot: _regimeRot,
          faithEffect: _faithEffect,
          onSwearOath: _oathAvailable ? _swearOath : null,
          onRepealLaw: _repealLaw,
          // 👥 NÜFUS
          rosterRows: _rosterRows(),
          onSelectVillager: (v) => setStateHere(() {
            _ledgerSection = null;
            _selectedVillager = v;
          }),
          // 🎯 TÜZÜK
          quests: QuestBook.activeQuests(_questContext(), _completedQuests),
          completedQuests: _completedQuests,
          charterTier: _charterTier,
          enactedPolicies: _policies.enactedCount,
          // 📖 KRONİK
          chronicle: _storyLog,
          milestoneCount: _achievedMilestones.length,
          onClose: _closeLedger,
        ),
      ),
    );
  }

  /// Nüfus bölümünün satırları — barınma bilgisi burada türetilir (panel bina
  /// katmanına bağımlı olmasın). Ölmekte olanlar deftere yazılmaz.
  List<VillagerStatRow> _rosterRows() => [
        for (final v in _villagers)
          if (!v.isDying)
            () {
              final (label, tier) = _housingInfo(v);
              return VillagerStatRow(v, label, tier);
            }(),
      ];

  /// Raf rozetleri — YALNIZ eyleme çağıran sayılar. Her bölümde daimî bir sayı
  /// yansa rozetler görünmez olurdu; bu yüzden ör. Kanunname rozeti sadece
  /// mürekkep kuruyken (yeni mühür basılabilirken) çıkar.
  Map<LedgerSection, int> _ledgerBadges() {
    final agenda = _divanAgendaCount();
    final homeless = _villagers.where((v) => v.homeBuilding == null).length;
    final openLaws = _inkDryRemaining() <= 0
        ? LawBook.openAgenda(_policies.sealed, _lawContext).length
        : 0;
    final openQuests =
        QuestBook.activeQuests(_questContext(), _completedQuests).length;
    return {
      if (agenda > 0) LedgerSection.divan: agenda,
      if (openLaws > 0) LedgerSection.kanun: openLaws,
      if (homeless > 0) LedgerSection.nufus: homeless,
      if (openQuests > 0) LedgerSection.tuzuk: openQuests,
    };
  }

  /// MÜHÜR RİTÜELİ — meclisin toplandığı yer. Eski "MECLİS'İ TOPLA" kartı bir
  /// düğmeydi ve düğmeye basmak bir yönetişim eylemi gibi hissettirmiyordu.
  /// Şimdi meclis, bir fermanı defterin önüne koyduğun an zaten oradadır.
  Widget buildLawRitual() {
    final l = _lawRitual!;
    return Positioned.fill(
      child: LawSealRitual(
        law: l,
        sealed: _policies.sealed,
        seed: _stableSeed('seal.${l.id}', _dayCount),
        onSeal: () => _sealLaw(l),
        onDismiss: _closeLawRitual,
      ),
    );
  }

  /// Hane nabzı rozetindeki sayaç: bekleyen + mayalanan mesele toplamı.
  int _divanAgendaCount() => _divanAgenda().length;

  // ── Meclis masası: hanelerin GERÇEK reisleri ─────────────────────────────────

  /// Her hanenin (soyun) reisini seçer — masada oturacak gerçek köylüler.
  /// Reis kuralı ve determinizmi [headOfHouse] içinde (regresyon testi var).
  /// RASTGELE DEĞİL: masada oyuncunun tanıdığı yüzler oturur. En nüfuzlu haneler
  /// önce (baskın hane masanın ortasına düşer); masa en çok 7 reis alır.
  List<DivanSeat> _divanHeads() {
    final byHouse = <String, List<VillagerEntity>>{};
    for (final v in _villagers) {
      if (v.isDying || v.surname.isEmpty) continue;
      (byHouse[v.surname] ??= []).add(v);
    }
    if (byHouse.isEmpty) return const [];

    // Nüfuz payına göre sırala (baskın hane ortada olsun); snapshot'tan oku.
    final snaps = {for (final s in _houses.snapshot()) s.surname: s};
    final entries = byHouse.entries.toList()
      ..sort((a, b) {
        final sa = snaps[a.key]?.swayShare ?? 0;
        final sb = snaps[b.key]?.swayShare ?? 0;
        return sb.compareTo(sa);
      });

    const maxSeats = 7;
    return [
      for (final e in entries.take(maxSeats))
        () {
          final head = headOfHouse(e.value)!;
          final s = snaps[e.key];
          return DivanSeat(
            visual: head.visual,
            type: head.type,
            stage: head.lifeStage,
            name: head.name,
            surname: e.key,
            mood: s?.mood ?? 0.55,
            ascendant: s?.ascendant ?? false,
            members: e.value.length,
            swayShare: s?.swayShare ?? 0,
          );
        }(),
    ];
  }

  /// Masadaki reise dokununca açılan kartın satırları. Kural ve bedeller SAF
  /// katmandan (`house_action.dart`) gelir; burada yalnız okunur metne çevrilir.
  /// Kapalı eylem GİZLENMEZ — gerekçesiyle sönük durur.
  List<HouseActionEntry> _houseActionEntries(String surname) {
    final out = <HouseActionEntry>[];
    for (final kind in HouseActionKind.values) {
      final gate = _houseActionGate(kind, surname);
      final o = _houseActionOutcome(kind, surname);
      out.add(HouseActionEntry(
        icon: kind.icon,
        label: kind.label,
        detail: gate.open ? _houseActionBlurb(kind) : gate.reason!,
        effects: gate.open ? _houseActionEffects(kind, o) : const [],
        enabled: gate.open,
        onTap: gate.open ? () => _applyHouseAction(kind, surname) : null,
      ));
    }
    return out;
  }

  /// Eylemin bir cümlelik karşılığı — ne yaptığını oyuncu okusun.
  String _houseActionBlurb(HouseActionKind kind) => switch (kind) {
        HouseActionKind.grant =>
          'Hane borçlanır ve güçlenir; ötekiler kayırmayı görür.',
        HouseActionKind.punish =>
          'Kan dökmeden hizaya getirir; köy sessizce ürperir.',
        HouseActionKind.seize =>
          'Ambarı mühürlersin. Kese dolar, meşruiyet azalır.',
        HouseActionKind.betroth => _compassPos.authority >= 0.15
            ? 'İki haneyi zorla kanla bağlarsın; kimse hayır diyemez.'
            : 'İki haneye nikâh önerirsin; gönül rızası aranır.',
        HouseActionKind.exile =>
          'Hanenin reisini yola vurursun. Soy başsız kalır.',
        HouseActionKind.scheme =>
          'Nüfuzlarını sessizce kırarsın — ifşa olursan bedeli ağır.',
      };

  /// Sonuç rozetleri — oyuncu neyin karşılığında ne verdiğini ÖNCEDEN görsün.
  List<String> _houseActionEffects(HouseActionKind kind, HouseActionOutcome o) {
    String sign(double v) => v >= 0 ? '+' : '−';
    final out = <String>[];
    if (o.gold != 0) out.add('${o.gold > 0 ? '+' : '−'}${o.gold.abs()} altın');
    if (o.food != 0) out.add('${o.food > 0 ? '+' : '−'}${o.food.abs()} erzak');
    if (o.targetMood != 0) {
      out.add('hâl ${sign(o.targetMood)}${o.targetMood.abs().toStringAsFixed(2)}');
    }
    if (o.targetSway != 0) {
      out.add('nüfuz ${sign(o.targetSway)}${o.targetSway.abs().toStringAsFixed(1)}');
    }
    if (o.otherMood < 0) out.add('öteki haneler ${sign(o.otherMood)}');
    if (o.unrest > 0) out.add('huzursuzluk +${o.unrest.toStringAsFixed(2)}');
    if (kind == HouseActionKind.scheme) {
      final r = schemeExposureChance(
          authority: _compassPos.authority, targetSwayShare: 0.3);
      out.add('ifşa riski %${(r * 100).round()}');
    }
    return out;
  }

  // ── Gündem türetme ──────────────────────────────────────────────────────────

  /// Gündem satırının ağzı: havuzdan GÜNE göre bir varyant seçer. Divan bir
  /// pano değil, kulağına eğilip tek nefeste durumu söyleyen bir kâhya olsun —
  /// ama aynı gün içinde her rebuild'de kelime değiştirmesin (tohum = gün+anahtar).
  String _agendaLine(String key, List<String> pool) =>
      Voice.pick(pool, _stableSeed(key, _dayCount));

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
        sub: p.stakes ?? '${p.petitioner} kapıda bekliyor, dilekçe elinde.',
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
            ? _agendaLine('house.sullen.${h.surname}', const [
                'Selamı kesmişler. Gönülleri alınmazsa bunu bir dilekçeyle '
                    'önüne koyacaklar.',
                'Kapıları erken kapanıyor, meydana inmiyorlar. Bu suskunluk '
                    'ucuza kapanmaz.',
                'Aralarında konuştukları şey belli: sıra sende, ve bunu '
                    'biliyorlar.',
              ])
            : _agendaLine('house.uneasy.${h.surname}', const [
                'Bir jest bekliyorlar; adını koymuyorlar ama bekliyorlar.',
                'Hava soğudu. Henüz kırılmadı, kırılmadan tut.',
                'Sofrada laf az. Küskünlüğe daha var ama yol o yola çıkıyor.',
              ]),
        pressure: ((_kDivanUneasy - mood) / _kDivanUneasy).clamp(0.1, 1.0),
        tone: sullen ? PetitionTone.ominous : PetitionTone.solemn,
      ));
    }

    // Kan davası — köyü zehirler, sulh meclisi an meselesi.
    if (_feudMember() != null) {
      brewing.add(DivanMatter(
        icon: '🩸',
        title: 'Kan davası',
        sub: _agendaLine('feud', const [
          'İki hane aynı kuyudan içiyor ama birbirine bakmıyor. Bir mezar '
              'daha kazılmadan otur bu masaya.',
          'Bıçaklar kuşakta, husumet defterde. Sulh her geçen gün pahalanıyor.',
          'Kan davası köyün suyuna karıştı. Sen kapatmazsan onlar kapatacak.',
        ]),
        pressure: 0.9,
        tone: PetitionTone.ominous,
      ));
    }

    // Çağrısına küs köylü — meslek değiştirme dilekçesi mayalanıyor.
    if (_resentfulVillager() != null) {
      brewing.add(DivanMatter(
        icon: '🌫️',
        title: 'Biri yanlış tezgâhta',
        sub: _agendaLine('calling', const [
          'Eli işte, aklı başka yerde. Er geç çağrısının peşinden gitmek '
              'için izin isteyecek.',
          'Mesleğine küs bir köylü var; her sabah aynı kapıdan isteksiz '
              'çıkıyor.',
          'Gönlü başka bir işte kalmış biri, sana söylemeye cesaret '
              'topluyor.',
        ]),
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
        sub: _agendaLine('followup.${f.id}', const [
          'Verdiğin karar geri döndü. Köy hatırlıyor, hesabını soracak.',
          'Eski bir hükmün yankısı: birkaç güne kapına dayanır.',
          'Bunu bir kez konuşmuştunuz. Konu kapanmamış, sadece beklemiş.',
        ]),
        pressure: pressure,
        tone: fp.tone,
      ));
    }

    // Ambar inceliyor — kıtlık baskısı (kış erzak / hasat dilekçelerinin zemini).
    final mouths = _villagers.length;
    if (mouths > 0 && _stockpile.food < mouths * 2) {
      brewing.add(DivanMatter(
        icon: '🥖',
        title: 'Ambar inceliyor',
        sub: _agendaLine('food', const [
          'Kileyi ölçtüler, yüzleri düştü. Bölüşüm dilekçesi gelmeden tedbir al.',
          'Ambarın dibi görünmeye başladı; kadınlar ekmeği ince kesiyor.',
          'Sayım yapıldı: bu erzakla kaç sofra döner, ambarcı söylemeye '
              'çekiniyor.',
        ]),
        pressure: (1.0 - _stockpile.food / (mouths * 2.0)).clamp(0.2, 0.95),
        tone: PetitionTone.ominous,
      ));
    }

    // Yaz kuraklığı zemini — işlenen tarla varken güneş ekini tehdit eder.
    final hasCrops = _farmTiles.any((t) => t.isGrowing || t.readyToHarvest);
    if (_season == Season.summer && hasCrops) {
      brewing.add(DivanMatter(
        icon: '☀️',
        title: 'Güneş ekini yakıyor',
        sub: _agendaLine('drought', const [
          'Toprak çatladı. Kuyudan su çeken sıraya girdi; çiftçiler yakında '
              'senden su isteyecek.',
          'Başaklar öğlen vakti başını eğiyor. Bu sıcak bir hafta daha '
              'sürerse hasat yarıya iner.',
          'Tarlalar susuz. Kuyunun ipi kısaldı, çiftçilerin sabrı da.',
        ]),
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
      brewing.add(DivanMatter(
        icon: '🐄',
        title: 'Sürü aç kalıyor',
        sub: _agendaLine('herd', const [
          'Ahırdan gece boyu ses geliyor. Yemlikler boş, çoban bunu senin '
              'kapına getirecek.',
          'İnekler süt vermez oldu, kaburgaları sayılıyor. Yem meselesi '
              'gündeme düşmek üzere.',
          'Ağıl bakımsız, saman bitmiş. Aç hayvan önce zayıflar, sonra '
              'hastalanır.',
        ]),
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

  /// Deftere girmiş fermanlar — kararlarının köyde kurumuş mumu.
  List<DivanFact> _divanLaws() {
    final out = <DivanFact>[];
    for (final l in kLawBook) {
      if (!_policies.sealed.contains(l.id)) continue;
      out.add(DivanFact(l.icon, l.title, branchColor(l.branch)));
    }
    return out;
  }

  /// Kararların kalıcı izleri — köy hafızası bayraklarının okunur karşılığı.
  /// identity.* atlanır (kimlik zaten başlıkta). Bilinmeyen bayrak gösterilmez.
  /// Köyün bildiği zanaatlar → Divan çipleri (kademeli gelişmenin görünür
  /// yüzü). Kilit menüde binaları gizlerken, köyün NE öğrendiğini burası söyler.
  List<DivanFact> _divanCrafts() {
    const sage = AppUi.sage;
    const icons = <String, String>{
      Craft.carpentry: '🪵',
      Craft.masonry: '🧱',
      Craft.farming: '🌾',
      Craft.husbandry: '🐑',
      Craft.milling: '🌀',
      Craft.mining: '⛏',
      Craft.fishing: '🎣',
      Craft.trade: '🪙',
      Craft.faith: '⛪',
    };
    return [
      for (final c in Craft.all)
        if (_knownCrafts.contains(c))
          DivanFact(icons[c] ?? '⚒', Craft.displayName(c), sage),
    ];
  }

  List<DivanFact> _divanMarks() {
    const sage = AppUi.sage;
    const rust = AppUi.rust;
    const accent = AppUi.accent;
    final known = <String, DivanFact>{
      'cult.active': DivanFact('⛪', 'İnanç kök saldı', accent),
      'cult.temple': DivanFact('⛪', 'Tapınak dikildi', accent),
      'cult.suppressed': DivanFact('⛪', 'İnanç bastırıldı', rust),
      'cult.united': DivanFact('🕊️', 'İki inanç bir sofrada', sage),
      'fields.tended': DivanFact('🌾', 'Toprağın hakkı verildi', sage),
      'fields.neglected': DivanFact('🍂', 'Tarlalar öksüz kaldı', rust),
      'pact.neighbor': DivanFact('🤝', 'Komşuyla el sıkışıldı', sage),
      'migrants.welcomed': DivanFact('🧳', 'Yabancıya kapı açıldı', sage),
      'holyDay.active': DivanFact('🕯️', 'Kutsal gün tutuluyor', accent),
      'council.elders': DivanFact('🏛️', 'Söz yaşlılarda', accent),
      'council.youth': DivanFact('🌱', 'Söz gençlerde', accent),
      'road.open': DivanFact('🛤️', 'Yol tüccara açık', sage),
      'road.closed': DivanFact('⛔', 'Yol kapalı, kervan yok', rust),
      'festival.tradition': DivanFact('🎉', 'Şenlik gelenek oldu', sage),
      // Dava kolunun bıraktığı izler — köyün ne olduğunu bunlar söyler.
      'nizam.watch': DivanFact('🔥', 'Meydanda ateş sönmez', rust),
      'nizam.registry': DivanFact('📖', 'Her hane deftere yazıldı', rust),
      'nizam.labor': DivanFact('⛓', 'Suçlu taş kırıyor', rust),
      'nizam.exile': DivanFact('🚪', 'Sürgün yolu açıldı', rust),
      'nizam.bloodPrice': DivanFact('🩸', 'Kanın bedeli keseden ödeniyor', rust),
      'nizam.sole': DivanFact('⚑', 'Tek söz sende', rust),
      kMassSeizureFlag: DivanFact('⚑', 'Mülkiyet kaldırıldı', rust),
      'dergah.tithe': DivanFact('🍞', 'Öşür toplanıyor', accent),
      'dergah.penance': DivanFact('🙏', 'Günah meydanda söyleniyor', accent),
      'dergah.oneFaith': DivanFact('⚑', 'Köy bir dergâh oldu', accent),
    };
    final out = <DivanFact>[];
    for (final flag in _villageMemory) {
      final f = known[flag];
      if (f != null) out.add(f);
    }
    return out;
  }
}
