part of '../main.dart';

/// Cenaze sistemi — bir köylü ömrünü tamamlayıp hayata veda ettiğinde
/// (scene_tick doğal ölüm) köy onu uğurlar. Kilise varsa: köy ateş başında
/// toplanır (anma), mum töreni fx'i oynar ve kilise yanına bir mezar kazılır
/// (kalıcı mezarlık — köyün hafızası). Kilise yoksa eski sade davranış sürer.
///
/// Cozy sözleşme (chill-gameplay): doğal ölüm KAYNAK/MORAL CEZASI almaz —
/// kilisenin civic morali köyü zaten teselli eder. Moral salınımı yalnız
/// oyuncu kararına bağlı anma/kayıp dilekçelerinde olur.
///
/// Bağımlı: _gatherAtFire + EventFx.vigil (scene_petitions), _graves (mezarlık),
/// _obstacles/_waterTiles (yer seçimi).
extension _SceneFuneral on _VillageSceneState {
  /// Görsel mezarlık tavanı — bundan sonra tören + mesaj sürer ama yeni taş
  /// dikilmez (kilise etrafı sonsuza dek mezarla dolmasın).
  static const int _kMaxGraves = 18;

  // ── Ölümün sesi ([[lib/text/voice.dart]]) ─────────────────────────────────
  // Ölüm sessizdir: kısa cümle, somut ayrıntı, açıklama yok. Yaşam öyküsü
  // satırları (annal) daha da kuru.

  static const _kLostLifePool = ['{ad-i} kaybetti', '{ad-in} ardında kaldı'];
  static const _kWidowLifePool = [
    'Eşi {ad-i} toprağa verdi',
    'Eşi {ad-i} kaybetti',
  ];
  static const _kChurchFuneralPool = [
    '⛪ {ad-i} kilisenin yanına gömdüler. Çan bir kez çaldı.',
    '⛪ {ad} için mum yakıldı. Mezarı kilisenin gölgesinde.',
    '⛪ Köy {ad-i} uğurladı. Toprak kapandı, kimse acele etmedi.',
  ];
  static const _kPeacefulEndPool = [
    '🕯️ {ad} uykusunda gitti.',
    '🕯️ {ad-in} eli soğudu. Yüzü sakindi.',
    '🕯️ {ad} sessizce göçtü.',
  ];
  static const _kOrphanDeathPool = [
    '🕯️ {ad} öldü. Ardında {sayı} çocuk kaldı.',
    '🕯️ {ad-i} kaybettik. {sayı} çocuğunun sofrasında bir sandalye boş.',
    '🕯️ {ad} gitti. {sayı} çocuğu bu geceyi köylülerin yanında geçirecek.',
  ];
  static const _kDeathPool = [
    '🕯️ {ad} bu sabah uyanmadı.',
    '🕯️ {ad-in} kapısı bugün açılmadı. İçeri girdiklerinde geç kalmışlardı.',
    '🕯️ {ad} öldü. Ocağı söndü.',
  ];

  /// İlk (tamamlanmış) kiliseyi döner; yoksa null.
  BuildingEntity? get _churchBuilding {
    for (final b in _buildings) {
      if (b.type == BuildingType.church) return b;
    }
    return null;
  }

  /// Doğal ölümde çağrılır — köylü zaten _villagers'tan çıkarıldı.
  /// [orphans] = bu ölümle yetim kalan çocuk sayısı (kilise yoksa mesaja girer).
  void _holdFuneral(VillagerEntity v, {required int orphans}) {
    AudioManager.instance.playSfx(Sfx.funeralToll);
    _award('first_death', 'Köy ilk kez yas tuttu', '🕯️');
    // Yaşam öyküsü — geride kalanların kaybı (dul eş + yetim çocuklar). v'nin
    // çocuk/ebeveyn listeleri tören anında hâlâ dolu (karşı taraf koparılmıştı).
    final ctx = _voice(
      v,
      seed: _stableSeed('ölüm${v.name}', _dayCount),
      extra: {'sayı': '$orphans'},
    );
    final partners = <VillagerEntity>{};
    for (final c in v.children) {
      if (!c.isDying) {
        _lifeEvent(c, Voice.say(_kLostLifePool, ctx), icon: '🕯️');
      }
      partners.addAll(c.parents);
    }
    for (final p in partners) {
      if (!p.isDying) {
        _lifeEvent(p, Voice.say(_kWidowLifePool, ctx), icon: '🕯️');
      }
    }
    final church = _churchBuilding;

    if (church != null) {
      // Mezar kaz (görsel tavana ulaşılmadıysa).
      if (_graves.length < _kMaxGraves) _spawnGrave(v.name);
      // Anma töreni: köy ateş başında toplanır + mum töreni fx (vigil).
      const dur = kGameDaySeconds * 0.45;
      const e = EventEffect(fx: EventFx.vigil, duration: dur);
      _activeFx.add(ActiveFx(e, dur));
      _gatherAtFire(dur, max: 7);
      _feelVillage(NpcEmotion.grief, 10, -0.12);
      // Cozy: moral cezası yok — kilise teselli eder, köy onurla uğurlar.
      _showNotification(Voice.say(_kChurchFuneralPool, ctx));
      return;
    }

    // Kilise yok — sade uğurlama (peacefulEnd / yetim varyantı).
    _showNotification(
      Voice.say(
        _policies.peacefulEnd
            ? _kPeacefulEndPool
            : orphans > 0
            ? _kOrphanDeathPool
            : _kDeathPool,
        ctx,
      ),
    );
  }

  /// Kilise yakınında boş bir tile'a mezar yerleştirir — iç halkadan dışa
  /// doğru tarayarak mezarlığın kilisenin çevresinde derli toplu büyümesini
  /// sağlar. Yakında boş yer yoksa null (tören yine de yapılır).
  Grave? _spawnGrave(String name) {
    final church = _churchBuilding;
    if (church == null) return null;
    final baseC = church.col + church.cols ~/ 2;
    final baseR = church.row + church.rows ~/ 2;
    const maxRing = 7;
    for (int ring = 1; ring <= maxRing; ring++) {
      for (int dr = -ring; dr <= ring; dr++) {
        for (int dc = -ring; dc <= ring; dc++) {
          // Yalnız halkanın dış kenarı (iç tile'lar önceki halkalarda denendi).
          if (dc.abs() != ring && dr.abs() != ring) continue;
          final c = baseC + dc;
          final r = baseR + dr;
          if (!_isGraveTileFree(c, r)) continue;
          final jx = (_rng.nextDouble() - 0.5) * 0.4;
          final jy = (_rng.nextDouble() - 0.5) * 0.4;
          final g = Grave(
            col: c.toDouble(),
            row: r.toDouble(),
            variant: _rng.nextInt(3),
            name: name,
            jitterX: jx,
            jitterY: jy,
          );
          _graves.add(g);
          return g;
        }
      }
    }
    return null;
  }

  /// Mezar dikilebilir mi: harita içi, engelsiz (bina/su/maden/ağaç), susuz,
  /// üzerinde dekor ya da başka mezar yok.
  bool _isGraveTileFree(int c, int r) {
    if (c < 0 || c >= kCols || r < 0 || r >= kRows) return false;
    if (_obstacles.contains((c, r))) return false;
    if (_waterTiles.contains((c, r))) return false;
    if (_decor.any((d) => d.col == c && d.row == r)) return false;
    for (final g in _graves) {
      if (g.col.round() == c && g.row.round() == r) return false;
    }
    return true;
  }
}
