part of '../main.dart';

/// ALGI — köylüler birbirini GÖRÜR.
///
/// Faz 2 öncesi köyde hiç algı yoktu: bir suç işlendiğinde yakındaki herkes
/// `_reactNearby` ile üç saniyelik bir korku postürü alır, sonra hiçbir şey
/// olmamış gibi devam ederdi. Kimse kimseyi görmüyor, kimse hiçbir şey
/// hatırlamıyordu. "Aşağıda karikatür dönüyor" hissinin sosyal tarafı buydu.
///
/// Tasarım: algı SÜREKLİ TARAMA DEĞİL, OLAY TABANLIDIR. Her karede "kim kimi
/// görüyor" hesaplamak N² maliyetlidir ve çıktısının çoğu çöptür. Bunun yerine
/// dünyada kayda değer bir şey olduğunda ([_witnessEvent]) o noktanın çevresi
/// taranır ve GERÇEKTEN görebilenler hatırlar.
extension _ScenePerception on _VillageSceneState {
  // Görüş/duyma geometrisi [Sight] içinde (saf, testli): menzil ışığa bağlıdır,
  // arkada kalan zor görülür, gürültü yönden bağımsız duyulur.

  /// Hafıza sönme taraması (sn).
  static const double _kFadeScan = 2.0;

  void _tickPerception(double dt) {
    _perceptionScan += dt;
    if (_perceptionScan < _kFadeScan) return;
    final elapsed = _perceptionScan;
    _perceptionScan = 0;

    final days = elapsed / kGameDaySeconds;
    for (final v in _villagers) {
      v.memory.fade(days);
    }

    // ÖLÜM TANIKLIĞI — tek kapı. Ölüm köyde birçok yoldan gelir (yaşlılık,
    // cinayet, kan davası, imparatorluk); her çağrı yerine ayrı kanca takmak
    // yerine ölmekte olanı burada yakalıyoruz. Aynı ölüm için ikinci kez anı
    // oluşmaz: [VillagerMemory.remember] aynı özne+tür için taze kaydı
    // birleştirir, o yüzden ayrı bir "gördüm" bayrağına gerek yok.
    for (final v in _villagers) {
      if (!v.isDying) continue;
      _witnessEvent(Notion.death,
          x: v.gridX, y: v.gridY, subject: v, subjectName: v.name, loud: true);
    }
  }

  /// [v], (x,y) noktasındaki bir şeyi görebilir mi?
  ///
  /// Üç kapı: uyanık/dışarıda olmak, menzil, yön. Yön kapısı önemli —
  /// arkasındaki bir hırsızı görmemek suçun gizliliğini GERÇEK kılar; aksi
  /// hâlde "sinsice sokulma" evresi anlamsız bir süsten ibaret olurdu.
  bool _canSee(VillagerEntity v, double x, double y) {
    if (v.isDying || v.isSleeping || v.isInsideBuilding) return false;
    return Sight.visible(
      dx: x - v.gridX,
      dy: y - v.gridY,
      facingRight: v.effectiveFacingRight,
      range: Sight.rangeFor(
          dayLight: _cycle.dayLight, hasTorch: v.torchLevel > 0.4),
    );
  }

  /// Sesi duyabilir mi — yön aranmaz, menzil kısadır. Uyuyan duymaz.
  bool _canHear(VillagerEntity v, double x, double y) {
    if (v.isDying || v.isInsideBuilding || v.isSleeping) return false;
    return Sight.audible(dx: x - v.gridX, dy: y - v.gridY);
  }

  /// DÜNYADA BİR ŞEY OLDU — kim gördüyse hatırlar.
  ///
  /// [subject] olayın öznesi (fail/kahraman); null olabilir (meçhul olay).
  /// [loud] true ise bakmayanlar da (duyma menzilinde) tanık olur.
  /// [exclude] olayın kendi tarafları (fail kendi suçuna tanık olmaz).
  ///
  /// Dönüş: gerçekten YENİ bir anı edinen köylüler — çağıran taraf bunlara
  /// tepki verdirebilir (irkilme, ihbara koşma).
  List<VillagerEntity> _witnessEvent(
    Notion kind, {
    required double x,
    required double y,
    Object? subject,
    String subjectName = '',
    bool loud = false,
    List<VillagerEntity> exclude = const [],
  }) {
    final seen = <VillagerEntity>[];
    for (final v in _villagers) {
      if (exclude.any((e) => identical(e, v))) continue;
      if (identical(v, subject)) continue; // fail kendini ihbar etmez
      final sees = _canSee(v, x, y);
      if (!sees && !(loud && _canHear(v, x, y))) continue;

      final fresh = v.memory.remember(Recollection(
        kind: kind,
        subject: subject,
        subjectName: subjectName,
        x: x,
        y: y,
        at: _time,
        firsthand: true,
        // Gözüyle gören tam güçle, yalnız duyan daha zayıf hatırlar.
        strength: sees ? 1.0 : 0.7,
      ));
      if (!fresh) continue;

      seen.add(v);
      _probeWitnessed++;
      // Gördüğü şey sonraki kararlarını da etkiler (3 sn'lik postür değil).
      final unease = notionUnease(kind);
      if (unease > 0) v.mind.pushDrive(Drive.unease, unease, 1.0);
      v.lookToward(x, y);
    }
    return seen;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DEDİKODU — anı ağızdan ağza yayılır
  // ══════════════════════════════════════════════════════════════════════════

  /// İki köylü konuşurken hafıza alışverişi yapar.
  ///
  /// Sohbet artık boş bir baloncuk dizisi değil: gerçekten bir şey ANLATILIYOR.
  /// Aktarılan anı KULAKTAN sayılır ([Recollection.firsthand] = false) — yani
  /// dinleyen ihbar edemez, yalnız kanaati etkilenir ve dedikoduyu sürdürür.
  /// Şüphenin köyde sosyal yoldan birikmesi bu zincirle olur.
  ///
  /// Dönüş: gerçekten bir haber aktarıldıysa true (baloncuk konusu değişsin).
  bool _exchangeGossip(VillagerEntity a, VillagerEntity b) {
    var told = false;
    told |= _tell(a, b);
    told |= _tell(b, a);
    return told;
  }

  /// [from] en çarpıcı anısını [to]'ya anlatır (biliyorsa anlatmaz).
  bool _tell(VillagerEntity from, VillagerEntity to) {
    final r = from.memory.strongestTellable;
    if (r == null) return false;
    if (to.memory.knows(r.kind, r.subject)) return false;
    // Kendisi hakkındaki dedikodu ona anlatılmaz.
    if (identical(r.subject, to)) return false;

    to.memory.remember(Recollection(
      kind: r.kind,
      subject: r.subject,
      subjectName: r.subjectName,
      x: r.x,
      y: r.y,
      at: _time,
      firsthand: false,
      // Anlatılan her ağızda biraz daha zayıflar — söylenti sonsuza yayılmaz.
      strength: (r.strength * 0.6).clamp(0.0, 1.0),
    ));
    _probeGossip++;
    return true;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // İHBAR — tanık muhafıza koşar
  // ══════════════════════════════════════════════════════════════════════════

  /// Tanığın koşacağı muhafız — en yakın uyanık devriye (yoksa null).
  VillagerEntity? _nearestGuardFor(VillagerEntity v) {
    VillagerEntity? best;
    var bestD = 1e9;
    for (final g in _awakeGuards()) {
      if (g.injuryDays > 0) continue;
      final d = _wdist(v.gridX, v.gridY, g.gridX, g.gridY);
      if (d < bestD) {
        bestD = d;
        best = g;
      }
    }
    return best;
  }

  /// Tanık muhafıza vardı mı — vardıysa haber geçer.
  ///
  /// Haberin sonucu: muhafız faili öğrenir ve peşine düşer. Bu, köyde suçun
  /// SOSYAL yoldan cezalandırıldığı ilk yol — daha önce muhafızın suçu
  /// görmesinden başka hiçbir kanal yoktu.
  void _tickInforming(double dt) {
    for (final v in _villagers) {
      if (!v.mind.owns(IntentKind.inform)) continue;
      final guard = _nearestGuardFor(v);
      if (guard == null) {
        v.mind.clear();
        continue;
      }
      if (_wdist(v.gridX, v.gridY, guard.gridX, guard.gridY) > 1.8) {
        // Hedef muhafız yer değiştirmiş olabilir — takibi tazele.
        v.goTo(guard.gridX, guard.gridY, 0.5);
        continue;
      }
      _deliverReport(v, guard);
    }
  }

  /// İhbar teslim edildi.
  void _deliverReport(VillagerEntity witness, VillagerEntity guard) {
    final r = witness.memory.strongestReportable;
    witness.mind.clear();
    if (r == null) return;
    _probeInformed++;

    final culprit = r.subject;
    witness.lookToward(guard.gridX, guard.gridY);
    guard.lookToward(witness.gridX, witness.gridY);
    witness.feel(NpcEmotion.fear, 3.0);
    guard.feel(NpcEmotion.anger, 4.0);

    // Muhafız artık BİLİYOR — anı ona da geçer (gözüyle görmüş sayılmaz ama
    // devriye için yeterlidir).
    guard.memory.remember(Recollection(
      kind: r.kind,
      subject: culprit,
      subjectName: r.subjectName,
      x: r.x,
      y: r.y,
      at: _time,
      firsthand: false,
      strength: r.strength,
    ));

    // Suç hâlâ sürüyorsa devriye doğrudan failin üstüne yürür.
    final active = _activeCrime;
    if (active != null && identical(active.culprit, culprit)) {
      _sendGuardAfter(guard, active);
      _showNotification(
          '🗣️ ${witness.name} devriyeye haber verdi — ${r.subjectName} tarif edildi.');
    } else {
      // Geç kalmış ihbar: fail kaçmış olabilir, ama köyün şüphesi somutlaşır.
      _showNotification('🗣️ ${witness.name} gördüğünü devriyeye anlattı.');
    }
    // İhbar eden bir daha aynı şeyi ihbar etmesin.
    r.strength = 0.30;
  }
}
