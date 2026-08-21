part of '../main.dart';

/// TOPLAYICI + AŞÇI — köyün BİNASIZ ilk üretim zinciri.
///
/// Kuruluşun ilk dakikalarında ne tarla var, ne oduncu kulübesi, ne ambar.
/// Oyuncunun elinde yapacak tek şey "bir bina daha dik"ti ve odun birikene
/// kadar bekliyordu — erken oyundaki boşluk hissinin somut kaynağı buydu.
///
/// Bu dosya o boşluğa iki iş koyar:
///   • **Toplayıcı** ([JobRole.forager]) — böğürtlen çalısından yiyecek getirir.
///     Hiçbir bina gerektirmez; oyunun ilk saniyesinden itibaren verilebilir.
///   • **Aşçı** ([JobRole.cook]) — ocakta ham yiyeceği pişirir. Pişmiş yemek
///     açlık tüketiminde ham yiyeceğin YERİNE geçer, yani aynı hasat iki katı
///     ağız doyurur; sofraya oturan köy de küçük bir moral alır.
///
/// İkisi de âdet katmanının "kadın işi" tarafında ([VillageCustom]) — ama
/// engellenmez, yalnız aykırı atamada ağır ilerler.
///
/// Diğer iş döngüleri gibi köylüyü PUPPET ETMEZ: yalnız `goTo` hedefi verir,
/// hareketi köylünün kendi `update()`'i yürütür (bkz. scene_jobs başlığı).
extension _SceneForage on _VillageSceneState {
  // ── Çalıların yenilenmesi ──────────────────────────────────────────────────

  /// Toplanan çalılar zamanla yeniden meyvelenir. Kışın DURUR — mevsim erken
  /// oyunda da gerçek bir kısıt olsun (tarla zaten kışın donuyor; böğürtlen de
  /// donmazsa kış "bekleme ekranı"na döner ama bedelsiz kalırdı).
  void _tickBerryRegrow(double dt) {
    if (_berryBushes.isEmpty) return;
    final frozen = _season.isFrozen;
    for (final b in _berryBushes) {
      b.tickRegrow(dt, kBerryRegrowSeconds, frozen: frozen);
    }
  }

  // ── TOPLAYICI ──────────────────────────────────────────────────────────────
  // En yakın olgun çalıya yürü → topla (kBerryPickDuration) → yiyecek stoğa.
  // claim = BerryBush.
  void _runForager(VillagerEntity v, double dt) {
    final job = v.job!;
    var bush = job.claim is BerryBush ? job.claim as BerryBush : null;
    // Elimizdeki çalı başkası tarafından toplandıysa (ya da kış bastırıp
    // olgunluğu düştüyse) bırak, yenisini ara.
    if (bush != null && !bush.harvestable) {
      bush.isBeingPicked = false;
      job.claim = null;
      bush = null;
    }
    if (bush == null) {
      job.working = false;
      job.harvesting = false;
      BerryBush? best;
      double bestD = double.infinity;
      for (final b in _berryBushes) {
        if (!b.harvestable || b.isBeingPicked) continue;
        final dx = b.col + 0.5 - v.gridX, dy = b.row + 0.5 - v.gridY;
        final d = dx * dx + dy * dy;
        if (d < bestD) {
          bestD = d;
          best = b;
        }
      }
      if (best == null) return; // olgun çalı yok → bekle (regrow)
      best.isBeingPicked = true;
      job.claim = best;
      bush = best;
      job.phase = 0;
    }

    final tx = bush.col + 0.5, ty = bush.row + 0.5;
    if (job.phase == 0) {
      final dx = v.gridX - tx, dy = v.gridY - ty;
      if (dx * dx + dy * dy <= 1.1 * 1.1) {
        v.state = VillagerState.idle;
        v.facingRight = tx > v.gridX;
        job.phase = 1;
        job.timer = 0;
        job.phaseAnim = 0;
      } else if (!_enRouteTo(v, tx, ty)) {
        v.goTo(tx, ty, 0.2);
      }
      return;
    }

    // Toplama — eğilip sepete koyma ritmi (harvesting bayrağı çiftçi gövdesini
    // stoop pozuna sokar; ayrı sprite yok).
    job.working = true;
    job.harvesting = true;
    v.idleTimer = 0.5;
    job.timer += dt;
    job.phaseAnim = (job.phaseAnim + dt * 2 * pi * 0.85) % (2 * pi);
    job.reportCycle(job.timer, kBerryPickDuration);
    if (job.timer >= kBerryPickDuration) {
      bush.harvest();
      bush.isBeingPicked = false;
      final basket = _spawnJobBox(
        ResourceBoxType.foodBasket,
        v.gridX,
        v.gridY,
        amount: kBerryYield,
      );
      _berriesPicked++;
      job.claim = null;
      job.phase = 0;
      job.timer = 0;
      job.working = false;
      job.harvesting = false;
      job.phaseAnim = 0;
      job.finishCycle();
      _sendOwnOutput(v, basket);
      v.feel(NpcEmotion.content, 2.5, moodDelta: 0.02);
    }
  }

  // ── AŞÇI ───────────────────────────────────────────────────────────────────
  // Ocağa yürü → pişir (kCookDuration) → 1 ham yiyecek yerine 2 sıcak yemek.
  // claim yok: hedef her zaman ateş yeri.
  void _runCook(VillagerEntity v, double dt) {
    final job = v.job!;
    final fp = _firepitBuilding;
    if (fp == null) {
      job.working = false;
      job.harvesting = false;
      return;
    }
    // Pişirecek bir şey yoksa ya da sofra zaten doluysa ocağın başında bekleme
    // yapma — köylü köye karışsın (iş bırakılmaz, sadece bu tick boş geçer).
    if (_stockpile.food < kCookFoodCost || _cookedMeals >= _mealCap) {
      job.working = false;
      job.harvesting = false;
      job.phase = 0;
      job.timer = 0;
      return;
    }

    final tx = fp.col + fp.cols / 2.0, ty = fp.row + fp.rows / 2.0;
    if (job.phase == 0) {
      final dx = v.gridX - tx, dy = v.gridY - ty;
      // Ocağın dibine değil KENARINA — ateşin üstüne basmasın (firepit walkable
      // ama görsel olarak alevin içinde durmak yanlış okunur).
      if (dx * dx + dy * dy <= 1.8 * 1.8) {
        v.state = VillagerState.idle;
        v.facingRight = tx > v.gridX;
        job.phase = 1;
        job.timer = 0;
        job.phaseAnim = 0;
      } else if (!_enRouteTo(v, tx, ty)) {
        final spot = _freeSpotNear(tx, ty, 1.6);
        v.goTo(spot?.$1 ?? tx, spot?.$2 ?? ty, 0.2);
      }
      return;
    }

    job.working = true;
    job.harvesting = true; // kazanın başında eğilme/karıştırma duruşu
    v.idleTimer = 0.5;
    job.timer += dt;
    job.phaseAnim = (job.phaseAnim + dt * 2 * pi * 0.7) % (2 * pi);
    job.reportCycle(job.timer, kCookDuration);
    if (job.timer >= kCookDuration) {
      job.timer = 0;
      // Son bir kez kontrol: pişirim süresince stok tükenmiş olabilir.
      if (_stockpile.food >= kCookFoodCost && _cookedMeals < _mealCap) {
        _stockpile.food -= kCookFoodCost;
        _cookedMeals += kCookMealsPerBatch;
        job.finishCycle();
        fp.deliveryPulse = 1.0;
        fp.deliveryTally++;
        v.feel(NpcEmotion.content, 3, moodDelta: 0.03);
        // İlk sıcak yemek köyde bir andır — bir kez duyurulur.
        if (!_firstMealShown) {
          _firstMealShown = true;
          _showNotification(
            Voice.say(
              _kFirstMealPool,
              _voice(v, seed: _stableSeed('ilkyemek', _dayCount)),
            ),
          );
          _feelVillage(NpcEmotion.joy, 4, 0.05);
        }
      }
    }
  }

  /// Sofra tavanı — kişi başı [kCookMealsPerMouth]. Aşçı bunu doldurunca durur;
  /// yoksa köyün bütün yiyeceğini kazana atar ve ambar boşalırdı.
  int get _mealCap => _villagers.length * kCookMealsPerMouth;
}

// Köyün ilk sıcak yemeği — bir kereye mahsus, kuruluşun küçük törenlerinden.
const List<String> _kFirstMealPool = [
  '🍲 Ocakta ilk yemek pişti. {ad} kazanı karıştırdı, koku köye yayıldı.',
  '🍲 Köy ilk sıcak yemeğini yedi — {ad-in} elinden.',
  '🍲 {ad} ateşin başında kazanı kaynattı; bu akşam kimse kuru ekmek yemedi.',
];
