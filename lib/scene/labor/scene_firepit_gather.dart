part of '../main.dart';

/// Ateş başı toplanma — akşam saatlerinde boştaki köylüler ateşe gelir,
/// anchor slot tutup oturur (warm). 3+ kişi oturduğunda yaşlı bir köylü
/// hikaye anlatmaya başlar; diğerleri dinler. Bittiğinde köye ufak moral.
///
/// Hayata geçirildiği yer: scene_firepit_gather (bu dosya).
/// Bağımlı sistemler: anchor_system.firepitSitPoints, VillagerActivity.warm/
/// storytelling/listening, _eventMorale/_eventMoraleLeft (HUD).
extension _SceneFirepitGather on _VillageSceneState {
  // ── Tetik pencereleri ──────────────────────────────────────────────────────
  /// Toplanma akşam başlar — dayLight bu eşiğin altına düştüğünde gather
  /// scan'i aktif olur. Gece (kNightThreshold) eşiğine inince zaten herkes
  /// uyumaya gider, sit otomatik cancel.
  static const double _kEveningGatherStart = 0.55;

  /// Hikaye saati tetik kontrolü periyodu.
  static const double _kStoryScanInterval = 4.0;

  /// Hikaye süresi (sn) — anlatıcı bu kadar konuşur, dinleyiciler kalır.
  static const double _kStoryDuration = 18.0;

  /// Hikaye bitince köye eklenen moral bonusu + süresi (HUD'da görünür).
  static const double _kStoryMoralBonus = 0.10;
  static const double _kStoryMoralDuration = 35.0;

  /// Bir storytelling tetiğinde minimum oturan kişi sayısı (anlatıcı dahil).
  static const int _kMinSittersForStory = 3;

  // ── Tick'ten çağrılan ana scan'ler ────────────────────────────────────────
  void _tickFirepitGather(double dt) {
    if (_buildings.every((b) => b.type != BuildingType.firepit)) return;

    // NOT: akşam toplanma taraması KALDIRILDI. Ateş başına gitme kararı artık
    // köylünün ÜŞÜME dürtüsünden doğuyor ([_bidHearth], scene_mind) — yani
    // "akşam oldu, rastgele 3 kişiyi ateşe yolla" yerine "üşüyen gider".
    // Hikâye taraması kalıyor: o bir toplanma kararı değil, oturanların
    // arasında doğan bir an.
    _storyScanTimer += dt;
    if (_storyScanTimer >= _kStoryScanInterval) {
      _storyScanTimer = 0;
      _scanStorytellers();
    }
  }

  // ── Konfor talebi (ekonomi yumuşak baskısı — pozitif sink) ─────────────────
  // Köy ara sıra elindeki SURPLUS konfor malını küçük bir şölene çevirir: bal
  // (lüks) önce, yoksa sağlıklı tampon üstündeki fazla yiyecek. Sonuç: kısa
  // moral + ateş başı keyiflenme. Mal yoksa SESSİZCE geçer — ceza yok (chill).
  // Etki: bal (yoksa dekoratifti) + kaynak fazlası sürekli anlam kazanır.
  void _tickComfort(double dt) {
    if (_villagers.length < 3) return;
    _comfortTimer -= dt;
    if (_comfortTimer > 0) return;
    _comfortTimer = (1.0 + _rng.nextDouble() * 0.8) * kGameDaySeconds; // ~1-1.8 gün

    final pop = _villagers.length;
    if (_stockpile.honey >= 3) {
      _stockpile.honey -= 3;
      _comfortFeast('🍯 Köy bal şöleni yaptı — tatlı bir keyif yayıldı.', 0.06);
    } else if (_stockpile.food > pop * 8 + 30) {
      // Yalnız BOL yiyecek varken (1 günlük tüketim + tampon üstü) — açlık riski yok.
      _stockpile.food -= 4;
      _comfortFeast('🍲 Köy küçük bir şölen verdi — karınlar tok, yüzler güleç.', 0.05);
    }
    // Hiçbir konfor malı yoksa sessizce geç — hiçbir ceza yok.
  }

  /// Küçük konfor şöleni — geçici moral + huzur gövde dili + birkaçı ateşe toplanır.
  void _comfortFeast(String msg, double morale) {
    pushPolicyMorale(morale, 1.5);
    _feelVillage(NpcEmotion.content, 8, morale * 0.5);
    if (_fireBurning) _gatherAtFire(kGameDaySeconds * 0.3, max: 5);
    _showNotification(msg);
  }

  /// Her firepit için: oturanlar sayılır, eşiği aşarsa hikaye başlat.
  void _scanStorytellers() {
    final dl = _cycle.dayLight;
    if (dl >= _kEveningGatherStart || dl < kNightThreshold) return;

    for (final b in _buildings) {
      if (b.type != BuildingType.firepit) continue;
      final cx = b.col + b.cols / 2.0;
      final cy = b.row + b.rows / 2.0;
      // Bu ateşin etrafında oturanları topla (slot pozisyonu < 1.8 tile).
      final sitters = <VillagerEntity>[];
      for (final v in _villagers) {
        if (!v.isSeatedAtFire) continue;
        final dx = v.sitArriveX - cx;
        final dy = v.sitArriveY - cy;
        if (dx * dx + dy * dy > 1.8 * 1.8) continue;
        sitters.add(v);
      }
      if (sitters.length < _kMinSittersForStory) continue;
      // Zaten anlatıcı varsa atla.
      if (sitters.any((s) => s.activity == VillagerActivity.storytelling)) {
        continue;
      }
      _startStory(sitters);
    }
  }

  /// Anlatıcıyı seç (yaşlı tercih), diğerlerini listening yap, bittiğinde
  /// moral bonusu uygula.
  void _startStory(List<VillagerEntity> sitters) {
    // Yaşlı varsa yaşlıyı seç — yoksa rastgele yetişkin.
    sitters.sort((a, b) {
      final aE = a.lifeStage == LifeStage.elder ? 0 : 1;
      final bE = b.lifeStage == LifeStage.elder ? 0 : 1;
      return aE - bE;
    });
    final storyteller = sitters.first;
    storyteller.activity = VillagerActivity.storytelling;
    // Baş üstünde 📖 YOK — anlatım elin kendisidir (bkz. CharGesture.tell).
    // `chatBubbleTime` burada baloncuk değil ANLATIM SAYACI: sıfırlanınca
    // aktivite warm'a düşer (bkz. scene_tick baloncuk decay döngüsü).
    storyteller.chatBubbleIcon = '';
    storyteller.chatBubbleTime = _kStoryDuration;
    // Anlatım süresi en az hikaye süresi kadar (kısa sürede kalkmasın).
    if (storyteller.warmthTimer < _kStoryDuration + 2) {
      storyteller.warmthTimer = _kStoryDuration + 2;
    }
    for (int i = 1; i < sitters.length; i++) {
      final l = sitters[i];
      l.activity = VillagerActivity.listening;
      // Dinleyicilerin oturma süresi anlatım kadar uzasın.
      if (l.warmthTimer < _kStoryDuration + 2) {
        l.warmthTimer = _kStoryDuration + 2;
      }
    }
    // Köye geçici moral bonusu — HUD'a yansır.
    if (_eventMoraleLeft < _kStoryMoralDuration) {
      _eventMorale     = _kStoryMoralBonus;
      _eventMoraleLeft = _kStoryMoralDuration;
      _eventLabel      = 'Ateş başı hikâye';
    }
  }
}
