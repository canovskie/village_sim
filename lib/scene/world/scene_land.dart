part of '../main.dart';

/// Arazi / reveal — **ZOOM KISITLAMASI** modeli.
///
/// Reveal artık bir örtü (sis/orman duvarı) DEĞİL, bir KAMERA kısıtı: kamera
/// "reach" tile-kutusunun dışını gösteremez (bkz. scene_input._clampCamera), bu
/// yüzden gerçek harita kenarı asla kadraja girmez ("havada yüzen ada" yok).
/// Dünya, reach büyüdükçe açılır — hiçbir şey çizilmez/gizlenmez.
///
/// Bu dosyada kalan tek iş: reach'in zamanla büyümesi (organik; hikâye beat'leri
/// ileride buradan sıçratacak).
///
/// Eski "vahşi orman / sabah sisi" reveal'ı SÖKÜLDÜ. [_cleared] / [_wilderness] /
/// [_wildTreeTiles] setleri kalıntı olarak duruyor ama HEP BOŞ (placement gate,
/// obstacle, painter guard'ları boş-guard'la kendiliğinden devre dışı) — tam
/// alan temizliği ayrı bir refactor.
///
/// part of main.dart — State'in tüm private alanlarına erişir.
extension _SceneLand on _VillageSceneState {
  /// Açılmamış (yasak) tile mı? Zoom-reveal modelinde HEP false — harita baştan
  /// sona inşa edilebilir; ulaşamadığın yeri zaten kamera göstermez.
  bool _isWilderness(int c, int r) => _wilderness.contains((c, r));

  /// Kurulum: land setlerini boş bırakır (reveal = kamera kısıtı, örtü yok).
  void _initLand() {
    _cleared.clear();
    _wilderness.clear();
    _wildTreeTiles.clear();
  }

  /// Eski ön-hat açma kancası (scene_tick devrilen ağaç döngüsü hâlâ çağırıyor).
  /// Zoom-reveal'de ağaç kesimi arazi açmaz → no-op.
  bool _openFrontierTile(int c, int r) => false;

  // ── Reach büyümesi (dünyanın açılması) ──────────────────────────────────────

  /// Reach hedefi — **asimptotik**, `_maxSpan`'e ulaşmaz. Eğrinin matematiği
  /// ve neden lineerden vazgeçildiği: [[lib/world/land_expansion.dart]].
  ///
  /// Yan fayda PERF: geç oyunda izin verilen zoom-out eskisinden dar kalır
  /// (134 binada ~88 vs 117) → max zoom-out'ta viewport'a belirgin daha az
  /// tile/entity girer.
  ///
  /// **Karma ilerleme (faz anahtarı YOK):** ilerleme = max(hikâye, organik).
  ///  • Hikâye: tamamlanan görev başına (scene_flow beat'leri) — erken oyunda
  ///    bina az / görev çok olduğu için AÇILIMI HİKÂYE SÜRER.
  ///  • Organik: bina sayısıyla — köy büyüyünce bu baskın gelir, yani hikâye
  ///    kendiliğinden PASİFLEŞİR ve dünya sessizce açılmaya devam eder.
  double get _landExpansionTarget {
    final story = _completedQuests.length * 1.5; // hikâye beat'leri
    final organic = _buildings.length * 0.5; // köyün büyümesi
    return landExpansionTarget(
      start: _VillageSceneState._kSpanStart,
      ceil: _maxSpan - kSpanCeilMargin,
      progress: story > organic ? story : organic,
    );
  }

  /// Her frame (scene_tick). Reach span'i (hu+hv) büyüdükçe izin verilen zoom-out
  /// + pan artar → dünya açılır; gerçek kenar yine hiç görünmez. Hedef için
  /// bkz. [_landExpansionTarget].
  void _updateLandExpansion(double dt) {
    final target = _landExpansionTarget;
    if (_reachSpan < target) {
      _reachSpan = (_reachSpan + dt * 1.2).clamp(0.0, target); // ~1.2 span/sn
    }

    // "Dünya açılıyor" anı — reach genişledikçe, oyuncu ZATEN tam zoom-out'taysa
    // (min'e yapışık) kamerayı yumuşakça geriye bırak → açılan dünya gözünün
    // önünde belirir. Oyuncu içeri zoom'lamışsa DOKUNMA (elini rahatsız etme).
    final mz = _minZoomForReach(_viewSize);
    if (_zoom <= _lastMinZoom * 1.03 + 0.001 && _zoom > mz) {
      _zoom +=
          (mz - _zoom) * (dt * 1.5).clamp(0.0, 1.0); // yumuşak geri çekilme
    }
    _lastMinZoom = mz;

    _tickOreDiscovery(dt);
    _tickLandmarkDiscovery(dt);
  }

  // ── Kaynak keşfi ────────────────────────────────────────────────────────────
  //
  // Madenler world_generator'da reach MESAFE bandlarına konur (yakın=taş,
  // orta=kömür, derin=demir) → ilk yerleşimde maden yok. Reach bir cevher
  // türünü İLK kez kadraja alınca burada tek seferlik keşif anı yaşanır:
  // bildirim + kronik (kâtip üslubu). [[lib/text/voice.dart]] havuzları.

  static const Map<OreType, List<String>> _kOreFoundPool = {
    OreType.stone: [
      'Otlağın ötesinde taş damarı bulundu. Kazmalar bileniyor.',
      'Tepede kaya çıktı. Taş artık uzak değil.',
      'Taş damarı görüldü. Duvar sözü ağızlarda dolaşıyor.',
    ],
    OreType.coal: [
      'Toprağın altından kara damar çıktı. Kömür ocakları bekliyor.',
      'Kömür damarı bulundu. Kış bir parça küçüldü.',
      'Derinlerde kömür görüldü. İs kokusu şimdiden burunlarda.',
    ],
    OreType.iron: [
      'Demir damarı bulundu. Örs için gün sayılıyor.',
      'Kızıl toprak demir verdi. Aletler yenilenecek.',
      'En derinde demir görüldü. Kazma ona uzanacak.',
    ],
  };

  /// Her saniye: keşfedilmemiş cevher türlerinden biri reach kutusuna girdiyse
  /// duyur. Gerçek viewport oranıyla bakar (band eşiği worst-case olduğundan
  /// keşif hiçbir zaman banddan ÖNCE gelmez).
  void _tickOreDiscovery(double dt) {
    _oreScanTimer -= dt;
    if (_oreScanTimer > 0) return;
    _oreScanTimer = 1.0;
    if (_oreDiscovered.length >= OreType.values.length) return;
    final size = _viewSize;
    if (size.width <= 0 || size.height <= 0) return;
    final (hu, hv) = _reachHalfExtents(size);
    for (final n in _mineNodes) {
      if (_oreDiscovered.contains(n.type.name)) continue;
      if (((n.col - n.row) - _centerU).abs() > hu) continue;
      if (((n.col + n.row) - _centerV).abs() > hv) continue;
      _oreDiscovered.add(n.type.name);
      final line = Voice.say(
        _kOreFoundPool[n.type]!,
        _voice(null, seed: _stableSeed('ore_${n.type.name}', _dayCount)),
      );
      _showNotification('⛏️ $line');
      _chronicle(line, icon: '⛏️', milestone: true);
    }
  }

  /// Harabe/özel yer ilk kez erişim kutusuna girdiğinde sonucunu uygular.
  /// Aynı taramada yalnız bir keşif çözülür; hızlı bir açılım bile bildirimleri
  /// üst üste bindirmez, sonraki saniyelerde sırayla gelir.
  void _tickLandmarkDiscovery(double dt) {
    _landmarkScanTimer -= dt;
    if (_landmarkScanTimer > 0) return;
    _landmarkScanTimer = 1.0;
    if (_landmarks.every((s) => s.discovered)) return;
    final size = _viewSize;
    if (size.width <= 0 || size.height <= 0) return;
    final (hu, hv) = _reachHalfExtents(size);
    for (final site in _landmarks) {
      if (site.discovered) continue;
      if (((site.col - site.row) - _centerU).abs() > hu) continue;
      if (((site.col + site.row) - _centerV).abs() > hv) continue;
      _discoverLandmark(site);
      return;
    }
  }

  void _discoverLandmark(WorldLandmark site) {
    site.discovered =
        true; // önce mühürle: aşağıdaki hiçbir yan etki tekrarlanmaz
    final effect = landmarkEffect(site.outcome);
    final resource = effect.resource;
    if (resource != null && effect.resourceDelta != 0) {
      final before = _stockpile.get(resource);
      final after = max(0, before + effect.resourceDelta);
      _stockpile.add(resource, after - before);
    }
    if (effect.moraleDelta != 0 && effect.moraleDays > 0) {
      pushPolicyMorale(effect.moraleDelta, effect.moraleDays);
      nudgeMorale(effect.moraleDelta);
    }

    final title = site.kind.title;
    final icon = site.kind.icon;
    _showNotification('$icon $title keşfedildi — ${effect.text}');
    _chronicle(
      '$title bulundu. ${effect.text}',
      icon: icon,
      kind: effect.isBoon ? ChronicleKind.life : ChronicleKind.crisis,
    );
  }
}
