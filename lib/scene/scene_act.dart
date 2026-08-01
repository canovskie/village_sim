part of '../main.dart';

/// EYLEM YÜRÜTÜCÜSÜ — varış noktaları gerçek iş olur.
///
/// Faz 3'ün derdi tek cümleyle: köylü bir yere varıp **hiçbir şey yapmıyordu**.
/// `idleTimer = dwell` verilip 8 saniye bekletiliyordu. Ekranda görünen şey
/// "bir yere yürüyüp orada duran adam"dı ve köyün karikatür durmasının en
/// büyük tek sebebi buydu.
///
/// Şimdi her gidişin bir SAHNESİ var: kuyuya varan eğilir, kovayı doldurur,
/// **elinde görünür bir kovayla** ve daha yavaş yürüyerek evine döner, kovayı
/// bırakır. Pazardan sepetle, meyhaneden maşrapayla dönülür.
///
/// İş bölümü: akıl NİYETİ seçer ([scene_mind]), burası o niyeti bir adım
/// dizisine çevirip yürütür.
extension _SceneAct on _VillageSceneState {
  /// Bir adımın hedefe "vardım" sayılma mesafesi (tile).
  static const double _kArrive = 0.75;

  /// Bir goTo adımının azami süresi (sn) — hedefe hiç varılamazsa eylem
  /// sonsuza kadar askıda kalmasın. (Faz 1'in "ölümsüz niyet" tuzağının
  /// eylem katmanındaki karşılığı: her adımın bir çıkışı olmalı.)
  static const double _kStepTimeout = 45.0;

  void _tickActs(double dt) {
    for (final v in _villagers) {
      final act = v.act;
      if (act == null) continue;

      // Uyku/ölüm/tören eylemi iptal eder — elindeki de düşer.
      if (v.isDying || v.isSleeping || v.isInsideBuilding) {
        _cancelAct(v);
        continue;
      }
      if (act.done) {
        _finishAct(v);
        continue;
      }

      act.timer += dt;
      final step = act.current!;
      switch (step.verb) {
        case ActVerb.goTo:
          if (_wdist(v.gridX, v.gridY, step.x, step.y) <= _kArrive) {
            v.state = VillagerState.idle;
            act.advance();
          } else if (v.state != VillagerState.moving) {
            // Henüz yola çıkmadı (ya da yolu kesildi) → emri (yeniden) ver.
            // dwell 0: varışta oyalanma YOK — oyalanmayı artık adımlar tarif
            // eder, körlemesine bir bekleme sayacı değil.
            v.goTo(step.x, step.y, 0);
          } else if (act.timer > _kStepTimeout) {
            _cancelAct(v); // ulaşılamıyor — eylemi düşür, hakem yeniden seçsin
          }

        case ActVerb.face:
          v.lookToward(step.x, step.y);
          act.advance();

        case ActVerb.work:
          // Yerinde dur — wander/rutin işi ortasında köylüyü kaçırmasın.
          v.state = VillagerState.idle;
          v.targetCol = v.gridX;
          v.targetRow = v.gridY;
          v.idleTimer = step.seconds - act.timer + 0.2;
          v.actPose = step.pose;
          if (act.timer >= step.seconds) {
            v.actPose = null;
            act.advance();
          }

        case ActVerb.take:
          v.prop = step.prop;
          act.advance();

        case ActVerb.put:
          v.prop = PropKind.none;
          act.advance();
      }
    }
  }

  /// Eylem tamamlandı — köylü boşa düşer, hakem yeniden karar verir.
  void _finishAct(VillagerEntity v) {
    v.act = null;
    v.actPose = null;
    v.prop = PropKind.none;
    if (v.mind.intent.priority <= IntentPriority.need) v.mind.clear();
  }

  /// Eylem yarıda kesildi (uyku, tören, ulaşılamayan hedef, yeni niyet).
  /// Elindeki nesne DÜŞER — yoksa köylü ömür boyu dolu kovayla dolaşırdı.
  void _cancelAct(VillagerEntity v) {
    v.act = null;
    v.actPose = null;
    v.prop = PropKind.none;
  }

  /// İŞ GÖVDE DİLİ — görev başında çalışan köylüye duruş (+ varsa alet) giydirir.
  ///
  /// Faz 3'ün errand mikro-sahneleri (bkz. [_errandAct]) köylüyü elde nesneyle
  /// canlandırıyordu ama köyün ÇOĞUNLUĞU çalışan işçilerdi ve iş sistemleri
  /// ([_SceneJobs] / [_SceneWork]) bu gövde-dili katmanına HİÇ dokunmuyordu:
  /// ekin biçen adam dimdik duruyor, ağaç kesen adam kütüğün yanında çakılı
  /// kalıyordu. "Köy karikatür dönüyor" hissinin en büyük tek kaynağı buydu.
  ///
  /// Sözleşme: yalnız act-güdümlü OLMAYAN köylüde (`v.act == null`) çalışır —
  /// errand mikro-sahnesi süren köylünün duruşunu/nesnesini scene_act yönetir,
  /// buraya karışmaz. [pose] `null` verilince duruş ve iş-aleti temizlenir
  /// (köylü yürümeye/başka işe geçti). İş villager'ları errand nesnesi taşımaz,
  /// dolayısıyla [prop] alanı tümüyle bu yardımcıya aittir.
  void _setWorkPose(VillagerEntity v, ActPose? pose, {PropKind prop = PropKind.none}) {
    if (v.act != null) return; // errand sahnesi sürüyor — dokunma
    // Suç sahnesi de sürüyor olabilir. Hırsız Act sistemini KULLANMAZ (suçun
    // kendi evre makinesi var) → `v.act` null'dır ve bu yardımcı onun çuvalını
    // her taramada silerdi: fail eve girip çıkar ama eli boş görünürdü.
    // Faz 4'ün "çuvalla çıkan adam" ânı tam da burada kayboluyordu.
    if (_activeCrime?.culprit == v) return;
    v.actPose = pose;
    v.prop = pose == null ? PropKind.none : prop;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SAHNE YAZIMI — hangi hedefte ne yapılır
  // ══════════════════════════════════════════════════════════════════════════

  /// Bir errand hedefi için mikro-sahne kurar.
  ///
  /// Hedefin türü yoksa (gezinti/komşu) sahne de yoktur: oraya yürünür ve
  /// kısa süre oyalanılır. Her gidişe zorla bir tören uydurmak, sahte bir
  /// yoğunluk üretirdi.
  Act _errandAct(VillagerEntity v, _ErrandTarget t) {
    final home = v.homeBuilding;
    // Yükü götüreceği yer: evi varsa evi, yoksa bulunduğu nokta.
    final (dx, dy) = home is BuildingEntity
        ? _centerOf(home)
        : (v.gridX, v.gridY);

    switch (t.kind) {
      // ── KUYU — köyün en okunur mikro-sahnesi: eğil, doldur, taşı, boşalt.
      case BuildingType.well:
        return Act('kuyudan su taşıyor', [
          ActStep.goTo(t.x, t.y),
          const ActStep.take(PropKind.bucketEmpty),
          ActStep.face(t.x, t.y),
          const ActStep.work(2.6, pose: ActPose.stoop),
          const ActStep.put(),
          const ActStep.take(PropKind.bucketFull),
          ActStep.goTo(dx, dy),
          const ActStep.work(1.4, pose: ActPose.stoop),
          const ActStep.put(),
        ]);

      // ── PAZAR — tezgâhta bekle, pazarlık et, sepetle dön.
      case BuildingType.market:
        return Act('pazardan alışveriş', [
          ActStep.goTo(t.x, t.y),
          ActStep.face(t.x, t.y),
          // Pazarda gezinip pazarlık eder — el işi DEĞİL: stand (idle nefes/
          // salınım). Bare work() varsayılanı labor'dı → havada çekiç sallıyordu.
          ActStep.work(3.0 + _rng.nextDouble() * 2.0, pose: ActPose.stand),
          const ActStep.take(PropKind.basket),
          ActStep.goTo(dx, dy),
          const ActStep.work(1.2, pose: ActPose.stoop),
          const ActStep.put(),
        ]);

      // ── MEYHANE — maşrapa kalkar, oturulur, içilir.
      case BuildingType.tavern:
        return Act('meyhanede oturuyor', [
          ActStep.goTo(t.x, t.y),
          const ActStep.take(PropKind.mug),
          ActStep.work(6.0 + _rng.nextDouble() * 4.0, pose: ActPose.sip),
          const ActStep.put(),
        ]);

      // ── AMBAR — çuval taşıma (köyün yükü gözle görünür olsun).
      case BuildingType.warehouse:
        return Act('ambarda iş görüyor', [
          ActStep.goTo(t.x, t.y),
          ActStep.face(t.x, t.y),
          const ActStep.work(2.0, pose: ActPose.stoop),
          const ActStep.take(PropKind.sack),
          ActStep.goTo(dx, dy),
          const ActStep.work(1.2, pose: ActPose.stoop),
          const ActStep.put(),
        ]);

      // ── ATEŞ — odun getirme (ateşin yakıtı zaten sistemde; bu onun görünür
      // gündelik hâli).
      case BuildingType.firepit:
        return Act('ateşe odun getiriyor', [
          const ActStep.take(PropKind.firewood),
          ActStep.goTo(t.x, t.y),
          ActStep.face(t.x, t.y),
          const ActStep.work(1.6, pose: ActPose.stoop),
          const ActStep.put(),
        ]);

      // ── EV — sofra: ekmek eline gelir, yenir.
      case BuildingType.woodenHouse:
      case BuildingType.stoneHouseBlue:
      case BuildingType.stoneHouseGreen:
      case BuildingType.manor:
      case BuildingType.tent:
        return Act('evinde soluklanıyor', [
          ActStep.goTo(t.x, t.y),
          const ActStep.take(PropKind.bread),
          ActStep.work(3.5 + _rng.nextDouble() * 2.5, pose: ActPose.sip),
          const ActStep.put(),
        ]);

      // ── MABET / MECLİS — durup bekleme (elde nesne yok, ama duruş var).
      case BuildingType.church:
      case BuildingType.townhall:
        return Act(
            t.kind == BuildingType.church ? 'mabette' : 'meydanda duruyor', [
          ActStep.goTo(t.x, t.y),
          ActStep.face(t.x, t.y),
          // Mabette dua / meydanda durma = stand (idle duruş). Bare work()
          // varsayılanı labor'dı → dua ederken ritmik el işi mimikliyordu.
          ActStep.work(4.0 + _rng.nextDouble() * 4.0, pose: ActPose.stand),
        ]);

      // ── SAHNESİZ GİDİŞ — gezinti, komşu ziyareti. Uydurma iş yok.
      default:
        return Act('köyde bir işi var', [
          ActStep.goTo(t.x, t.y),
          // Gezinti/komşu ziyareti = stand (idle nefes/salınım/bakınma). Bare
          // work() varsayılanı labor'dı → boş yerde havada el işi yapıyordu.
          ActStep.work(t.dwell.clamp(1.5, 12.0), pose: ActPose.stand),
        ]);
    }
  }
}
