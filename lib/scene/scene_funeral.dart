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
    _award('first_death', 'Köy ilk kez yas tuttu', '🕯️');
    // Yaşam öyküsü — geride kalanların kaybı (dul eş + yetim çocuklar). v'nin
    // çocuk/ebeveyn listeleri tören anında hâlâ dolu (karşı taraf koparılmıştı).
    final partners = <VillagerEntity>{};
    for (final c in v.children) {
      if (!c.isDying) _lifeEvent(c, '${v.name}\'i kaybetti', icon: '🕯️');
      partners.addAll(c.parents);
    }
    for (final p in partners) {
      if (!p.isDying) _lifeEvent(p, 'Eşi ${v.name}\'i kaybetti', icon: '🕯️');
    }
    final church = _churchBuilding;

    if (church != null) {
      // Mezar kaz (görsel tavana ulaşılmadıysa).
      if (_graves.length < _kMaxGraves) _spawnGrave(v.name);
      // Anma töreni: köy ateş başında toplanır + mum töreni fx (vigil).
      final dur = kGameDaySeconds * 0.45;
      final e = EventEffect(fx: EventFx.vigil, duration: dur);
      _activeFx.add(ActiveFx(e, dur));
      _gatherAtFire(dur, max: 7);
      _feelVillage(NpcEmotion.grief, 10, -0.12);
      // Cozy: moral cezası yok — kilise teselli eder, köy onurla uğurlar.
      _showNotification(
          '⛪ ${v.name} kilisede uğurlandı — köy onu andı, mezarı huzurla kazıldı. 🕯️');
      return;
    }

    // Kilise yok — eski sade uğurlama (peacefulEnd / yetim varyantı).
    final msg = _policies.peacefulEnd
        ? '🕯️ ${v.name} huzura kavuştu.'
        : orphans > 0
            ? '🕯️ ${v.name} hayata veda etti. $orphans çocuk yetim kaldı.'
            : '🕯️ ${v.name} hayata veda etti.';
    _showNotification(msg);
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
  /// üzerinde başka mezar yok.
  bool _isGraveTileFree(int c, int r) {
    if (c < 0 || c >= kCols || r < 0 || r >= kRows) return false;
    if (_obstacles.contains((c, r))) return false;
    if (_waterTiles.contains((c, r))) return false;
    for (final g in _graves) {
      if (g.col.round() == c && g.row.round() == r) return false;
    }
    return true;
  }
}
