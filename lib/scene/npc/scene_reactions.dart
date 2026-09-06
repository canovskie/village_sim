part of '../main.dart';

/// Sürekli reaktif "canlı köy" katmanı — olaylar ve eylemler köyde GÖRÜNÜR,
/// **gövde diliyle** (postür + dönüp bakma) yankı bulur.
///
/// KISIT (bkz. feedback_event_animation): baş üstü emoji / floating ikon YOK;
/// sayısal refleksiyon YOK. Tüm ifade [VillagerEntity.feel] → game_painter
/// postür kanalından geçer (sevinç sıçrar, yas çöker, korku titrer...).
extension _SceneReactions on _VillageSceneState {
  /// Uyanık/dışarıdaki tüm köylülere ortak bir duygu (gövde dili) yaşatır —
  /// bir olayın köy çapında kişisel yankısı. [feel]'in özünü kullanır.
  void _feelVillage(NpcEmotion e, double dur, double moodDelta) {
    for (final v in _villagers) {
      if (v.isSleeping || v.isInsideBuilding || v.isDying) continue;
      v.feel(e, dur, moodDelta: moodDelta);
    }
  }

  /// Bir noktada olan şeye YEREL tepki dalgası: yarıçaptaki uyanık köylüler o
  /// noktaya **dönüp bakar** (lookToward) + gövde refleksi (feel). Mesafeyle
  /// yumuşar — yakın olan daha güçlü/uzun tepki verir.
  /// [alarm] > 0 ise tepki geçici bir gövde refleksiyle kalmaz: yarıçaptaki
  /// köylülerin TEDİRGİNLİK dürtüsünü de sıçratır (bkz. scene_mind). Yani
  /// gördükleri şey sonraki kararlarını da etkiler — korku 3 saniyede
  /// unutulmaz.
  void _reactNearby(double x, double y, double radius, NpcEmotion e, double dur,
      {double moodDelta = 0, double alarm = 0}) {
    if (alarm > 0) _alarmVillage(x, y, radius, alarm);
    final r2 = radius * radius;
    for (final v in _villagers) {
      if (v.isSleeping || v.isInsideBuilding || v.isDying) continue;
      final dx = v.gridX - x, dy = v.gridY - y;
      final d2 = dx * dx + dy * dy;
      if (d2 > r2) continue;
      final k = 1.0 - (d2 / r2); // 0..1 yakınlık
      v.lookToward(x, y);
      v.feel(e, dur * (0.6 + 0.4 * k), moodDelta: moodDelta * k);
    }
  }

  /// Sürekli baseline canlılık — ara sıra rastgele uyanık/sakin bir köylüye
  /// kısa, düşük yoğunluklu gövde refleksi (huzur/merak). İkon yok, sadece
  /// postür → köy hiçbir an tamamen durağan kalmaz.
  void _spontaneousLife(double dt) {
    _spontaneousTimer -= dt;
    if (_spontaneousTimer > 0) return;
    _spontaneousTimer = kSpontaneousLifeMin +
        _rng.nextDouble() * (kSpontaneousLifeMax - kSpontaneousLifeMin);
    if (_villagers.length < 2) return;
    // Birkaç deneme: uyanık, dışarıda, sakin (idle, aktivitesiz) biri.
    for (int i = 0; i < 5; i++) {
      final v = _villagers[_rng.nextInt(_villagers.length)];
      if (v.isSleeping || v.isInsideBuilding || v.isDying || v.isCarrying) {
        continue;
      }
      if (v.activity != VillagerActivity.none || v.sitClaimed) continue;
      final e = _rng.nextBool() ? NpcEmotion.content : NpcEmotion.wonder;
      v.feel(e, 1.6 + _rng.nextDouble() * 1.2);
      return;
    }
  }

  /// Hava durumu geçişi → gerçek davranış. Yağmur başlayınca dış mekândaki
  /// köylüler irkilir (fear-lite) ve sığınağa/eve yönelir (errand'i kısa kes).
  /// Açınca rahatlama dalgası. Bir kez tetiklenir (_lastRainy ile).
  void _tickWeatherReaction(double dt) {
    final rainy = _cycle.rainIntensity > 0.30;
    if (rainy == _lastRainy) return;
    _lastRainy = rainy;
    if (rainy) {
      _feelVillage(NpcEmotion.fear, 2.2, 0);
      // Sığınağa koş: dışarıdaki gezginleri eve yönelt (varsa), yoksa errand iste.
      for (final v in _villagers) {
        if (v.isSleeping || v.isInsideBuilding || v.isDying) continue;
        if (v.isCarrying || v.sitClaimed) continue;
        if (v.activity != VillagerActivity.none) continue; // sohbeti/dansı bölme
        if (v.homeBuilding case final h?) {
          final hb = h as BuildingEntity;
          final cx = hb.col + hb.cols / 2.0, cy = hb.row + hb.rows / 2.0;
          final spot = _freeSpotNear(cx, cy, 1.6);
          if (spot != null) v.goTo(spot.$1, spot.$2, 4 + _rng.nextDouble() * 4);
        }
      }
    } else {
      _feelVillage(NpcEmotion.content, 3.0, 0);
    }
  }

  /// SESSİZ KARARIN GÖVDESİ — bespoke sahnesi (PetitionFx) OLMAYAN seçenekler.
  ///
  /// Dilekçe seçeneklerinin çoğunda özel bir sahne yok: karar veriliyor, ekranda
  /// bildirim ve sayı değişiyor, köy hiçbir şey yapmıyordu. Burası o boşluğu
  /// kapatır ve bunu UYDURMA İÇERİKLE değil, seçeneğin KENDİ beyan ettiği
  /// veriyle yapar: geçici moralin işareti kararın tonunu, büyüklüğü de
  /// tepkinin süresini/yayılımını verir.
  ///
  /// Odak noktası dilekçe SAHİBİDİR — karar onun hakkında verildi, köy ona
  /// bakar. Sahibi yoksa/uyuyorsa karar kürsüsü (belediye, yoksa ateş) odaktır.
  void _reactPlainDecision(PetitionOption o, VillagerEntity? author) {
    final tone = o.moraleAmount > 0.005
        ? NpcEmotion.content
        : o.moraleAmount < -0.005
            ? NpcEmotion.grief
            : NpcEmotion.wonder;
    // Ağırlık: geçici moralin büyüklüğü (moralsiz karar da merakla karşılanır).
    final weight = (o.moraleAmount.abs() * 8).clamp(0.35, 1.0);
    final dur = 2.5 + 3.0 * weight;
    // Bireysel moral ayrı bir kanal (köy morali zaten pushPolicyMorale ile
    // uygulandı) — burada sabit ve küçük tutulur, çifte sayım olmasın.
    final mood = tone == NpcEmotion.content
        ? 0.05
        : tone == NpcEmotion.grief
            ? -0.05
            : 0.0;

    final focus = author != null &&
            !author.isSleeping &&
            !author.isInsideBuilding &&
            !author.isDying
        ? (author.gridX, author.gridY)
        : _decisionSeat();
    if (focus == null) return;

    // Dilekçe sahibi kararın muhatabı: en uzun ve en belirgin tepkiyi o verir.
    if (author != null && !author.isDying) {
      author.feel(tone, dur * 1.4, moodDelta: mood);
    }
    // Çevresindekiler dönüp bakar (mesafeyle yumuşar).
    _reactNearby(focus.$1, focus.$2, 6.0, tone, dur);
    // Ağır karar köyün geneline de dokunur — küçük kararlar sokağı meşgul etmez.
    if (o.moraleAmount.abs() >= 0.05) _feelVillage(tone, dur * 0.5, 0);
  }

  /// Kararın okunduğu yer — belediyenin önü, yoksa köyün ateşi. İkisi de yoksa
  /// (kuruluşun ilk anları) odak yok demektir.
  (double, double)? _decisionSeat() {
    final seat =
        _buildings.where((b) => b.type == BuildingType.townhall).firstOrNull ??
            _firepitBuilding;
    if (seat == null) return null;
    return (seat.col + seat.cols / 2.0, seat.row + seat.rows / 2.0);
  }

  /// FERMANIN GÜNLÜK YÜKÜ — vergi/öşür/kese sayıdan çıkıp SIRTA biner.
  ///
  /// Mühürlü fermanlar her gün ambardan yiyecek, keseden altın alır ya da
  /// verir ([LawBook.dailyUpkeep]). Bu şimdiye dek tamamen görünmezdi: sabah
  /// olur, sayı değişirdi. Artık köyden biri işi GÖRÜR — ambardan çuvalı
  /// sırtlayıp belediyeye (yoksa ateşe) götürür; ferman veriyorsa yön tersine
  /// döner, kese köye açılır.
  ///
  /// Hesapla İLGİSİ YOK: kaynak zaten [_applyLawUpkeep] içinde işlendi, burası
  /// yalnız o hesabın gövdesi. Uygun taşıyıcı bulunamazsa sessizce atlanır —
  /// köy zaten meşguldür, sahne zorlanmaz.
  void _stageLawUpkeep({required bool collecting}) {
    final store = _buildings
        .where((b) => b.type == BuildingType.warehouse)
        .firstOrNull;
    final seat = _decisionSeat();
    if (store == null || seat == null) return;
    final storeX = store.col + store.cols / 2.0;
    final storeY = store.row + store.rows / 2.0;

    // Tahsildar: tercihen tüccar (kese işi onun), yoksa muhafız (nizamın eli),
    // yoksa boştaki herhangi bir yetişkin. Kendi işi olan kimse çekilmez.
    VillagerEntity? pick;
    var bestRank = 99;
    for (final v in _villagers) {
      if (v.isChild || v.isSleeping || v.isInsideBuilding || v.isDying) continue;
      if (v.isCarrying || v.sitClaimed || v.hasActiveJob) continue;
      if (v.act != null || v.activity != VillagerActivity.none) continue;
      if (!v.canRunErrands) continue;
      final rank = v.type == VillagerType.merchant
          ? 0
          : v.type == VillagerType.guard
              ? 1
              : 2;
      if (rank < bestRank) {
        bestRank = rank;
        pick = v;
      }
      if (bestRank == 0) break;
    }
    if (pick == null) return;

    // Toplama: ambardan al, kürsüye götür. Dağıtım: kürsüden al, ambara indir.
    final (fromX, fromY) = collecting ? (storeX, storeY) : seat;
    final (toX, toY) = collecting ? seat : (storeX, storeY);
    pick.act = Act(
      collecting ? 'öşürü belediyeye taşıyor' : 'keseyi ambara indiriyor',
      [
        ActStep.goTo(fromX, fromY),
        ActStep.face(fromX, fromY),
        const ActStep.work(1.6, pose: ActPose.stoop),
        const ActStep.take(PropKind.sack),
        ActStep.goTo(toX, toY),
        const ActStep.work(1.4, pose: ActPose.stoop),
        const ActStep.put(),
      ],
    );
    // Hakem bu köylüyü gezintiye kaydırmasın diye niyet dayatılır — ama
    // TÖREN önceliğiyle DEĞİL: tören niyetini ne `_finishAct` temizler
    // (yalnız <= need temizlenir) ne de hakemin "hiçbir niyet çeyrek günden
    // uzun yaşamaz" güvenlik ağı toplar (ceremony'yi bilerek atlar). Sırtında
    // çuvalla kalıcı olarak düşünemez hâle gelmiş bir köylü kalırdı. `need`
    // hem işi bitince temizlenir hem de rutin gezintinin üstünde kalır.
    pick.mind.impose(
      IntentKind.errand,
      collecting ? 'fermanın payını topluyor' : 'fermanın kesesini dağıtıyor',
      priority: IntentPriority.need,
    );
  }

  /// FERMAN DUYULDU — mühür basıldığı ANIN gövde karşılığı.
  ///
  /// Eskiden mühür yalnız çan sesi + bildirim + pusula kaymasıydı: köy o anı
  /// GÖRMÜYORDU, kararın etkisi ancak basınç tablosu üzerinden saatler içinde
  /// sızıyordu. Burası o boşluğu kapatır — kanun okunduğu yerde işitilir:
  ///   • Karar noktasının (belediye, yoksa ateş) çevresindekiler dönüp bakar.
  ///   • Köy çapında kısa bir duygu dalgası geçer — ferman sert mi umutlu mu,
  ///     gövdeden okunur (tedirginlik / huzur / merak).
  ///   • AĞIR ferman ise birkaç köylü ateş başında toplanıp konuşur.
  ///
  /// Moral EKONOMİSİNE karışmaz: kalıcı moral etkisi zaten fermanın kendi
  /// [LawDef.seal] sonuçlarında: buradaki dokunuş yalnız o anın refleksidir.
  void _announceLawInVillage(LawDef l) {
    // Kanun nerede okunur — belediyenin önünde, yoksa köyün ateşi başında.
    final seat = _decisionSeat();
    if (seat == null) return;
    final (cx, cy) = seat;

    // Fermanın havası: mirası eksiyse sert (tedirginlik), artıysa umut
    // (huzur), nötrse merak. Ağır ferman aynı duyguyu daha uzun taşır.
    final emo = l.legacy < 0
        ? NpcEmotion.fear
        : l.legacy > 0
            ? NpcEmotion.content
            : NpcEmotion.wonder;
    final dur = l.isGrave ? 5.0 : 3.0;

    // Yakındakiler dönüp bakar (mesafeyle yumuşar), köyün geri kalanı kısa bir
    // an duruşuyla karşılık verir.
    _reactNearby(cx, cy, 8.0, emo, dur, moodDelta: l.legacy < 0 ? -0.02 : 0.02);
    _feelVillage(emo, dur * 0.6, 0);

    // Ağır ferman: kalabalık dağılmaz, ateş başında kısa bir toplanma olur.
    if (l.isGrave) {
      _gatherAtFire(kGameDaySeconds * 0.12, max: 5);
      addCameraShake(3.0, dur: 0.35);
    }
  }
}
